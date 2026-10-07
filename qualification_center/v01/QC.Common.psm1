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
