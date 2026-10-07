[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qc01ReturnPath,
    [Parameter(Mandatory = $true)][string]$RequirementRegisterPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$Qc01 = Import-QcJson -LiteralPath $Qc01ReturnPath
if ([string]$Qc01.status -ne 'PASS') {
    throw 'QC02_UPSTREAM_QC01_NOT_PASS'
}
$QcRegister = Import-QcJson -LiteralPath $RequirementRegisterPath
$QcRequirements = @(ConvertTo-QcArray -Value $QcRegister.requirements)
if ($QcRequirements.Count -eq 0) {
    throw 'QC02_REQUIREMENT_REGISTER_EMPTY'
}

$QcAllowedFamilies = @()
for ($QcIndex = 1; $QcIndex -le 25; $QcIndex++) {
    $QcAllowedFamilies += ('P{0:D2}' -f $QcIndex)
}
$QcAllowedScopes = @('LOCAL', 'INTERFACE', 'COMPOSITIONAL', 'SYSTEM', 'AUTHORITY', 'EVIDENCE', 'RUNTIME', 'ENVIRONMENTAL')
$QcContracts = @()
$QcDefects = @()
$QcPropertyIds = @{}

foreach ($QcRequirement in $QcRequirements) {
    $QcRequiredFields = @(
        'property_id','property_family','property_scope_class','requirement_id','owner_objective_id',
        'earliest_detectable_stage','latest_permitted_detection_stage','positive_control_id','expected_property',
        'oracle_id','oracle_type','qualification_profile','fail_effect','block_effect','downstream_admission_effect'
    )
    foreach ($QcField in $QcRequiredFields) {
        $QcValue = $QcRequirement.PSObject.Properties[$QcField]
        if ($null -eq $QcValue -or [string]::IsNullOrWhiteSpace([string]$QcValue.Value)) {
            $QcDefects += "MISSING_FIELD|$([string]$QcRequirement.property_id)|$QcField"
        }
    }
    $QcPropertyId = [string]$QcRequirement.property_id
    if ($QcPropertyIds.ContainsKey($QcPropertyId)) {
        $QcDefects += "DUPLICATE_PROPERTY_ID|$QcPropertyId"
    }
    else {
        $QcPropertyIds[$QcPropertyId] = $true
    }
    if ($QcAllowedFamilies -notcontains [string]$QcRequirement.property_family) {
        $QcDefects += "INVALID_PROPERTY_FAMILY|$QcPropertyId"
    }
    if ($QcAllowedScopes -notcontains [string]$QcRequirement.property_scope_class) {
        $QcDefects += "INVALID_SCOPE_CLASS|$QcPropertyId"
    }
    $QcNegativeControls = @(ConvertTo-QcArray -Value $QcRequirement.negative_control_ids)
    $QcEvidenceFields = @(ConvertTo-QcArray -Value $QcRequirement.required_evidence_fields)
    if ($QcNegativeControls.Count -eq 0) {
        $QcDefects += "NEGATIVE_CONTROL_MISSING|$QcPropertyId"
    }
    if ($QcEvidenceFields.Count -eq 0) {
        $QcDefects += "EVIDENCE_FIELDS_MISSING|$QcPropertyId"
    }
    $QcContracts += [pscustomobject][ordered]@{
        property_id = $QcPropertyId
        property_family = [string]$QcRequirement.property_family
        property_scope_class = [string]$QcRequirement.property_scope_class
        requirement_id = [string]$QcRequirement.requirement_id
        owner_objective_id = [string]$QcRequirement.owner_objective_id
        invariant_ids = @(ConvertTo-QcArray -Value $QcRequirement.invariant_ids)
        target_member_ids = @(ConvertTo-QcArray -Value $QcRequirement.target_member_ids)
        target_interface_ids = @(ConvertTo-QcArray -Value $QcRequirement.target_interface_ids)
        earliest_detectable_stage = [string]$QcRequirement.earliest_detectable_stage
        latest_permitted_detection_stage = [string]$QcRequirement.latest_permitted_detection_stage
        positive_control_id = [string]$QcRequirement.positive_control_id
        negative_control_ids = $QcNegativeControls
        expected_property = [string]$QcRequirement.expected_property
        oracle_id = [string]$QcRequirement.oracle_id
        oracle_type = [string]$QcRequirement.oracle_type
        required_evidence_fields = $QcEvidenceFields
        qualification_profile = [string]$QcRequirement.qualification_profile
        fail_effect = [string]$QcRequirement.fail_effect
        block_effect = [string]$QcRequirement.block_effect
        downstream_admission_effect = [string]$QcRequirement.downstream_admission_effect
    }
}

$QcStatus = 'PASS'
if ($QcDefects.Count -gt 0) {
    $QcStatus = 'BLOCKED'
}
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC02_QUALIFICATION_CONTRACT_V01'
    component_id = 'QC-02'
    status = $QcStatus
    target_package_id = [string]$Qc01.target_package_id
    target_package_sha256 = [string]$Qc01.target_package_sha256
    required_property_count = $QcContracts.Count
    property_contracts = $QcContracts
    compiler_defects = $QcDefects
    unmapped_required_property_count = $QcDefects.Count
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
