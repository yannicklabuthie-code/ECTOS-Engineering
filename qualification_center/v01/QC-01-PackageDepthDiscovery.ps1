[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$CompletenessBasisPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

function Get-QcBytesSha256 {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $QcHasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $QcDigest = $QcHasher.ComputeHash($Bytes)
    }
    finally {
        $QcHasher.Dispose()
    }
    return ([System.BitConverter]::ToString($QcDigest).Replace('-', '').ToLowerInvariant())
}

$QcBasis = Import-QcJson -LiteralPath $CompletenessBasisPath
$QcExpectedMembers = @(ConvertTo-QcArray -Value $QcBasis.expected_members | ForEach-Object { [string]$_ } | Sort-Object)
$QcRequiredDomains = @(ConvertTo-QcArray -Value $QcBasis.required_domains | ForEach-Object { [string]$_ } | Sort-Object)
$QcSupportedDomains = @('PACKAGE_MEMBER_DOMAIN', 'ENTRYPOINT_DOMAIN', 'RUNTIME_DOMAIN')
$QcMembers = @()
$QcUnreachable = @()
$QcTargetItem = Get-Item -LiteralPath $TargetPath -ErrorAction Stop

if ($QcTargetItem.PSIsContainer) {
    $QcRoot = $QcTargetItem.FullName.TrimEnd('\')
    try {
        $QcFiles = @(Get-ChildItem -LiteralPath $QcRoot -Recurse -File -Force -ErrorAction Stop)
    }
    catch {
        $QcUnreachable += $_.Exception.Message
        $QcFiles = @()
    }
    foreach ($QcFile in $QcFiles) {
        $QcRelative = $QcFile.FullName.Substring($QcRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        $QcMembers += [pscustomobject][ordered]@{
            path = $QcRelative
            size_bytes = [int64]$QcFile.Length
            sha256 = Get-QcSha256 -LiteralPath $QcFile.FullName
            extension = $QcFile.Extension.ToLowerInvariant()
        }
    }
}
else {
    if ($QcTargetItem.Extension.ToLowerInvariant() -ne '.zip') {
        throw "QC01_UNSUPPORTED_TARGET_FILE|$TargetPath"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $QcArchive = [System.IO.Compression.ZipFile]::OpenRead($QcTargetItem.FullName)
    try {
        foreach ($QcEntry in $QcArchive.Entries) {
            if ([string]::IsNullOrWhiteSpace($QcEntry.Name)) {
                continue
            }
            $QcStream = $QcEntry.Open()
            try {
                $QcMemory = New-Object System.IO.MemoryStream
                try {
                    $QcStream.CopyTo($QcMemory)
                    $QcRaw = $QcMemory.ToArray()
                }
                finally {
                    $QcMemory.Dispose()
                }
            }
            finally {
                $QcStream.Dispose()
            }
            $QcMembers += [pscustomobject][ordered]@{
                path = ($QcEntry.FullName -replace '\\', '/')
                size_bytes = [int64]$QcRaw.Length
                sha256 = Get-QcBytesSha256 -Bytes $QcRaw
                extension = [System.IO.Path]::GetExtension($QcEntry.Name).ToLowerInvariant()
            }
        }
    }
    finally {
        $QcArchive.Dispose()
    }
}

$QcMembers = @($QcMembers | Sort-Object path)
$QcActualMembers = @($QcMembers | ForEach-Object { $_.path } | Sort-Object)
$QcMemberMatch = (($QcExpectedMembers -join "`n") -eq ($QcActualMembers -join "`n"))
$QcUnsupportedDomains = @($QcRequiredDomains | Where-Object { $QcSupportedDomains -notcontains $_ })
$QcEntrypoints = @($QcMembers | Where-Object { $_.extension -in @('.ps1', '.cmd', '.bat', '.exe', '.py') } | ForEach-Object { $_.path })
$QcRuntimeHints = @()
if (@($QcMembers | Where-Object { $_.extension -eq '.ps1' }).Count -gt 0) { $QcRuntimeHints += 'POWERSHELL' }
if (@($QcMembers | Where-Object { $_.extension -eq '.py' }).Count -gt 0) { $QcRuntimeHints += 'PYTHON' }

$QcLedgerText = ($QcMembers | ForEach-Object { $_.path + '|' + $_.sha256 + '|' + $_.size_bytes }) -join "`n"
$QcLedgerBytes = [System.Text.Encoding]::UTF8.GetBytes($QcLedgerText)
$QcPackageSha = Get-QcBytesSha256 -Bytes $QcLedgerBytes
$QcStatus = 'PASS'
if (-not $QcMemberMatch -or $QcUnreachable.Count -gt 0 -or $QcUnsupportedDomains.Count -gt 0) {
    $QcStatus = 'BLOCKED'
}

$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC01_PACKAGE_DEPTH_RETURN_V01'
    component_id = 'QC-01'
    status = $QcStatus
    target_package_id = $QcTargetItem.Name
    target_package_sha256 = $QcPackageSha
    member_count = $QcMembers.Count
    member_inventory = $QcMembers
    entrypoint_register = $QcEntrypoints
    runtime_register = @($QcRuntimeHints | Sort-Object -Unique)
    required_domains = $QcRequiredDomains
    supported_domains = $QcSupportedDomains
    unsupported_required_domains = $QcUnsupportedDomains
    expected_member_count = $QcExpectedMembers.Count
    member_set_match = $QcMemberMatch
    unreachable_register = $QcUnreachable
    completeness_state = $QcStatus
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
