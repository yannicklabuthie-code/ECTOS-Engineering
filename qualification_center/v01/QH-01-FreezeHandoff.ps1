[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qc02ContractPath,
    [Parameter(Mandatory = $true)][string]$Qc03RoutesPath,
    [Parameter(Mandatory = $true)][string]$Qc04ExecutionPath,
    [Parameter(Mandatory = $true)][string]$Qc05ClosurePath,
    [Parameter(Mandatory = $true)][string]$QualifierScriptPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$Qc02 = Import-QcJson -LiteralPath $Qc02ContractPath
$Qc03 = Import-QcJson -LiteralPath $Qc03RoutesPath
$Qc04 = Import-QcJson -LiteralPath $Qc04ExecutionPath
$Qc05 = Import-QcJson -LiteralPath $Qc05ClosurePath
if ([string]$Qc02.status -ne 'PASS' -or [string]$Qc03.status -ne 'PASS' -or [string]$Qc04.status -ne 'PASS') {
    throw 'QH01_UPSTREAM_NOT_CLOSED'
}
if ([string]$Qc05.coverage_closure -ne 'PASS') {
    throw 'QH01_COVERAGE_NOT_CLOSED'
}
if (-not (Test-Path -LiteralPath $QualifierScriptPath -PathType Leaf)) {
    throw 'QH01_QUALIFIER_SCRIPT_NOT_FOUND'
}
if ([string]$Qc02.target_package_sha256 -ne [string]$Qc03.target_package_sha256 -or [string]$Qc02.target_package_sha256 -ne [string]$Qc04.target_package_sha256 -or [string]$Qc02.target_package_sha256 -ne [string]$Qc05.target_package_sha256) {
    throw 'QH01_TARGET_IDENTITY_DIVERGENCE'
}
$QcQualificationProfile = 'NOT_PROVEN'
if (@(ConvertTo-QcArray -Value $Qc02.property_contracts).Count -gt 0) {
    $QcProfiles = @(ConvertTo-QcArray -Value $Qc02.property_contracts | ForEach-Object { [string]$_.qualification_profile } | Sort-Object -Unique)
    if ($QcProfiles.Count -eq 1) { $QcQualificationProfile = $QcProfiles[0] }
}
$QcPlatformProfile = 'NOT_PROVEN'
if (@(ConvertTo-QcArray -Value $Qc03.routes).Count -gt 0) {
    $QcPlatforms = @(ConvertTo-QcArray -Value $Qc03.routes | ForEach-Object { [string]$_.platform_profile } | Sort-Object -Unique)
    if ($QcPlatforms.Count -eq 1) { $QcPlatformProfile = $QcPlatforms[0] }
}
if ($QcQualificationProfile -eq 'NOT_PROVEN' -or $QcPlatformProfile -eq 'NOT_PROVEN') {
    throw 'QH01_PROFILE_NOT_CLOSED'
}

$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QH01_HANDOFF_V01'
    handoff_id = ('QH01-' + [guid]::NewGuid().ToString('N'))
    target_package_id = [string]$Qc02.target_package_id
    target_package_sha256 = [string]$Qc02.target_package_sha256
    qualification_contract_sha256 = Get-QcSha256 -LiteralPath $Qc02ContractPath
    property_register_sha256 = Get-QcSha256 -LiteralPath $Qc02ContractPath
    route_register_sha256 = Get-QcSha256 -LiteralPath $Qc03RoutesPath
    execution_return_sha256 = Get-QcSha256 -LiteralPath $Qc04ExecutionPath
    evidence_bundle_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    defect_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    not_proven_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    qualifier_id = 'ECTOS_QC06_INDEPENDENT_QUALIFIER'
    qualifier_version = 'V01'
    qualifier_sha256 = Get-QcSha256 -LiteralPath $QualifierScriptPath
    qualifier_trust_scope_id = 'QC06_V01_EXACT_SCRIPT_AND_CONTRACT_SCOPE'
    platform_profile = $QcPlatformProfile
    qualification_profile = $QcQualificationProfile
    no_mutation_after_freeze = $true
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
exit 0
