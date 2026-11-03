Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Import-QcJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "QC_FILE_NOT_FOUND|$LiteralPath"
    }
    $QcRaw = [System.IO.File]::ReadAllText($LiteralPath)
    try {
        return ($QcRaw | ConvertFrom-Json)
    }
    catch {
        throw "QC_JSON_INVALID|$LiteralPath|$($_.Exception.GetType().Name)"
    }
}

function Export-QcJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    $QcParent = Split-Path -Parent $LiteralPath
    if ($QcParent -and -not (Test-Path -LiteralPath $QcParent -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($QcParent) | Out-Null
    }
    $QcText = $Value | ConvertTo-Json -Depth 100
    $QcText = ($QcText -replace "`r`n", "`n") + "`n"
    $QcUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($LiteralPath, $QcText, $QcUtf8NoBom)
}

function Get-QcSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "QC_HASH_TARGET_NOT_FOUND|$LiteralPath"
    }
    $QcStream = [System.IO.File]::OpenRead($LiteralPath)
    try {
        $QcHasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            $QcBytes = $QcHasher.ComputeHash($QcStream)
        }
        finally {
            $QcHasher.Dispose()
        }
    }
    finally {
        $QcStream.Dispose()
    }
    return ([System.BitConverter]::ToString($QcBytes).Replace('-', '').ToLowerInvariant())
}

function ConvertTo-QcArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]$Value
    )
    if ($null -eq $Value) {
        return @()
    }
    return @($Value)
}

function Assert-QcSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    $QcActual = Get-QcSha256 -LiteralPath $LiteralPath
    if ($QcActual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "QC_SHA256_MISMATCH|$LiteralPath|EXPECTED=$ExpectedSha256|ACTUAL=$QcActual"
    }
    return $QcActual
}

Export-ModuleMember -Function Import-QcJson, Export-QcJson, Get-QcSha256, ConvertTo-QcArray, Assert-QcSha256

# Structural validation uses the recovered jsonschema distribution, not a new schema engine.
# The execution environment must supply its approved Python/jsonschema runtime.
function Assert-QcSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$SchemaName
    )
    if ($SchemaName -notmatch '^[a-z0-9-]+\.schema\.json$') { throw 'QC_SCHEMA_NAME_INVALID' }
    $QcSchemaRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../schemas/qualification_center/v01'))
    $QcSchemaPath = Join-Path $QcSchemaRoot $SchemaName
    if (-not (Test-Path -LiteralPath $QcSchemaPath -PathType Leaf)) { throw 'QC_SCHEMA_NOT_FOUND' }
    $QcPython = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $QcTemporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ('qc-schema-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        Export-QcJson -Value $Value -LiteralPath $QcTemporaryPath
        $QcValidationText = & $QcPython.Source -W ignore -m jsonschema -i $QcTemporaryPath $QcSchemaPath 2>&1
        $QcValidationExit = $LASTEXITCODE
        if ($QcValidationExit -ne 0) { throw ('QC_SCHEMA_INVALID_OR_RUNTIME_UNAVAILABLE|' + $SchemaName + '|' + ($QcValidationText -join ' ')) }
    }
    finally {
        if (Test-Path -LiteralPath $QcTemporaryPath -PathType Leaf) { Remove-Item -LiteralPath $QcTemporaryPath -Force }
    }
}
Export-ModuleMember -Function Assert-QcSchema

function Test-QcPinnedInvocation {
    [CmdletBinding()]
    param([string]$CommandPath, [string]$ScriptPath, $FixedArguments, $DynamicArguments)
    $fixed = @(ConvertTo-QcArray -Value $FixedArguments)
    if (@(ConvertTo-QcArray -Value $DynamicArguments).Count -ne 0) { return $false }
    $exe = [System.IO.Path]::GetFileName($CommandPath).ToLowerInvariant()
    if ($exe -eq 'powershell.exe') {
        if ($fixed.Count -lt 6) { return $false }
        $prefix = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File')
        for ($i=0; $i -lt 5; $i++) { if ([string]$fixed[$i] -cne $prefix[$i]) { return $false } }
        return ([string]$fixed[5] -ceq $ScriptPath)
    }
    if ($exe -match '^python(?:[0-9.]+)?(?:\.exe)?$') {
        if ($fixed.Count -eq 0) { return $false }
        $index = 0
        if ([string]$fixed[0] -ceq '-u') { $index = 1 }
        return ($fixed.Count -gt $index -and [string]$fixed[$index] -ceq $ScriptPath -and -not $ScriptPath.StartsWith('-'))
    }
    return ($CommandPath -ceq $ScriptPath)
}
Export-ModuleMember -Function Test-QcPinnedInvocation

function Get-QcLogicalTargetId {
    param($Stage)
    $id = [string]$Stage.target_package_id
    if ($Stage.PSObject.Properties['target_identity_kind'] -and [string]$Stage.target_identity_kind -eq 'ZIP_RAW_BYTES_SHA256' -and $id.EndsWith('.zip',[System.StringComparison]::OrdinalIgnoreCase)) { return $id.Substring(0,$id.Length-4) }
    return $id
}
Export-ModuleMember -Function Get-QcLogicalTargetId

# V48: platform/runtime above describe the FUNCTIONAL control. execution_profile
# describes its PowerShell orchestrator. Only the legacy Windows/PS51 pair may
# default; Python controls must carry an explicit, externally approved envelope.
function Get-QcExecutionProfile {
    param($Value)
    if ($null -ne $Value -and $Value.PSObject.Properties['execution_profile']) {
        $p = $Value.execution_profile
        if ($null -eq $p -or $null -eq $p.PSObject.Properties['platform_profile'] -or $null -eq $p.PSObject.Properties['runtime_profile'] -or @($p.PSObject.Properties).Count -ne 2) { throw 'EXECUTION_PROFILE_INVALID' }
        if ([string]$p.platform_profile -cne 'WINDOWS' -or [string]$p.runtime_profile -cne 'WINDOWS_POWERSHELL_DESKTOP_5_1') { throw 'EXECUTION_PROFILE_UNSUPPORTED' }
        return [pscustomobject][ordered]@{platform_profile='WINDOWS';runtime_profile='WINDOWS_POWERSHELL_DESKTOP_5_1'}
    }
    if ($null -ne $Value -and $Value.PSObject.Properties['platform_profile'] -and $Value.PSObject.Properties['runtime_profile'] -and [string]$Value.platform_profile -ceq 'WINDOWS' -and [string]$Value.runtime_profile -ceq 'WINDOWS_POWERSHELL_DESKTOP_5_1') {
        return [pscustomobject][ordered]@{platform_profile='WINDOWS';runtime_profile='WINDOWS_POWERSHELL_DESKTOP_5_1'}
    }
    throw 'EXPLICIT_EXECUTION_PROFILE_REQUIRED'
}
function Test-QcNativeExecutionHost {
    return ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1 -and $PSVersionTable.PSEdition -eq 'Desktop' -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT)
}
Export-ModuleMember -Function Get-QcExecutionProfile, Test-QcNativeExecutionHost
