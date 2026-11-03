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
$QcPathDefects = @()
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
            $rawName = [string]$QcEntry.FullName
            $parts = @($rawName.TrimEnd('/') -split '/')
            if ($rawName -match '^[\\/]|\\|:|[\x00-\x1f]' -or @($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' -or $_ -match '[. ]$|[<>"|?*]|^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' }).Count -gt 0) { $QcPathDefects += ('UNSAFE_ARCHIVE_ENTRY|' + $rawName) }
            $unixType = (([int64]$QcEntry.ExternalAttributes -shr 16) -band 61440)
            if ($unixType -eq 40960) { $QcPathDefects += ('SYMLINK_ARCHIVE_ENTRY|' + $rawName) }
            if ([string]::IsNullOrWhiteSpace($QcEntry.Name)) { continue }
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

# Canonical path safety applies independently of the caller-supplied basis.
function Test-QcSafeMemberName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match '^[\\/]' -or $Name -match '\\' -or $Name -match ':' -or $Name -match '[\x00-\x1f]') { return $false }
    foreach ($part in @($Name -split '/')) {
        if ([string]::IsNullOrWhiteSpace($part) -or $part -eq '.' -or $part -eq '..' -or $part -match '[. ]$' -or $part -match '[<>"|?*]' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { return $false }
    }
    return $true
}
foreach ($set in @(@{ label='BASIS'; names=$QcExpectedMembers }, @{ label='ACTUAL'; names=@($QcMembers | ForEach-Object { $_.path }) })) {
    $seen = @{}
    foreach ($name in @($set.names)) {
        if (-not (Test-QcSafeMemberName -Name $name)) { $QcPathDefects += ('UNSAFE_PATH|' + $set.label + '|' + $name) }
        $key = ([string]$name).ToLowerInvariant()
        if ($seen.ContainsKey($key)) { $QcPathDefects += ('DUPLICATE_OR_COLLIDING_PATH|' + $set.label + '|' + $name) }
        $seen[$key] = $true
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
$QcLedgerSha = Get-QcBytesSha256 -Bytes $QcLedgerBytes
$QcPackageSha = $QcLedgerSha
if (-not $QcTargetItem.PSIsContainer) { $QcPackageSha = Get-QcSha256 -LiteralPath $QcTargetItem.FullName }
$QcIdentityProven = $false
$QcIdentityDefects = @()
if ($QcTargetItem.PSIsContainer) {
    if ($QcBasis.PSObject.Properties['expected_member_ledger']) {
        $expectedLedger = @($QcBasis.expected_member_ledger)
        if ($expectedLedger.Count -ne $QcMembers.Count -or $expectedLedger.Count -eq 0) { $QcIdentityDefects += 'EXPECTED_MEMBER_LEDGER_CARDINALITY_MISMATCH' }
        $seenLedger = @{}
        foreach ($row in $expectedLedger) {
            $name = [string]$row.path
            $key = $name.ToLowerInvariant()
            if ($seenLedger.ContainsKey($key)) { $QcIdentityDefects += ('DUPLICATE_EXPECTED_LEDGER_PATH|' + $name) }
            $seenLedger[$key] = $true
            $actual = @($QcMembers | Where-Object { $_.path -ceq $name })
            if ($actual.Count -ne 1 -or [string]$row.sha256 -notmatch '^[a-fA-F0-9]{64}$') { $QcIdentityDefects += ('EXPECTED_MEMBER_LEDGER_INVALID|' + $name); continue }
            if ([string]$actual[0].sha256 -ne [string]$row.sha256 -or [int64]$actual[0].size_bytes -ne [int64]$row.size_bytes) { $QcIdentityDefects += ('EXPECTED_MEMBER_BYTES_MISMATCH|' + $name) }
        }
        $QcIdentityProven = ($QcIdentityDefects.Count -eq 0)
    }
    else { $QcIdentityDefects += 'EXPECTED_MEMBER_LEDGER_MISSING' }
}
else {
    if ($QcBasis.PSObject.Properties['expected_package_sha256']) {
        $expectedHash = [string]$QcBasis.expected_package_sha256
        if ($expectedHash -match '^[a-fA-F0-9]{64}$' -and $expectedHash -eq $QcPackageSha) { $QcIdentityProven = $true }
        else { $QcIdentityDefects += 'EXPECTED_PACKAGE_SHA256_MISMATCH_OR_INVALID' }
    }
    else { $QcIdentityDefects += 'EXPECTED_PACKAGE_SHA256_MISSING' }
}
$QcStatus = 'PASS' 
if ($QcMembers.Count -eq 0 -or $QcExpectedMembers.Count -eq 0 -or -not $QcMemberMatch -or $QcUnreachable.Count -gt 0 -or $QcUnsupportedDomains.Count -gt 0 -or $QcPathDefects.Count -gt 0 -or -not $QcIdentityProven) {
    $QcStatus = 'BLOCKED'
}

$QcIdentityKind = 'DIRECTORY_LEDGER_SHA256'
if (-not $QcTargetItem.PSIsContainer) { $QcIdentityKind = 'ZIP_RAW_BYTES_SHA256' }
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC01_PACKAGE_DEPTH_RETURN_V01'
    component_id = 'QC-01'
    status = $QcStatus
    target_package_id = $QcTargetItem.Name
    target_package_sha256 = $QcPackageSha
    target_member_ledger_sha256 = $QcLedgerSha
    target_identity_kind = $QcIdentityKind
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
    inventory_match = $QcMemberMatch
    byte_identity_proven = $QcIdentityProven
    identity_defects = $QcIdentityDefects
    path_defects = $QcPathDefects
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
