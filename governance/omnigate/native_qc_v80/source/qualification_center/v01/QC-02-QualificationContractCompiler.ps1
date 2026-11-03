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
$QcAuthorityDefects = @()
function Read-QcField($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $QcFieldProperty = $Object.PSObject.Properties[$Name]
    if ($null -ne $QcFieldProperty) { return $QcFieldProperty.Value }
    return $null
}
foreach ($QcField in @('source_authority','requirement_source_ref','requirement_source_sha256')) {
    if ([string]::IsNullOrWhiteSpace([string](Read-QcField $QcRegister $QcField))) { $QcAuthorityDefects += "SOURCE_FIELD_MISSING|$QcField" }
}
if ([string](Read-QcField $QcRegister 'contract_state') -ne 'APPROVED' -or [string](Read-QcField $QcRegister 'currentness_state') -ne 'CURRENT') { $QcAuthorityDefects += 'SOURCE_AUTHORITY_OR_CURRENTNESS_NOT_PROVEN' }
# Normalize only the declared physical ZIP filename to its logical package ID.
# The physical byte identity and QC01 PASS are still mandatory; no hash relaxation.
$QcPhysicalId = [string]$Qc01.target_package_id
$QcLogicalId = $QcPhysicalId
if ([string]$Qc01.target_identity_kind -eq 'ZIP_RAW_BYTES_SHA256' -and $QcPhysicalId.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
    $QcLogicalId = $QcPhysicalId.Substring(0, $QcPhysicalId.Length - 4)
}
if ([string](Read-QcField $QcRegister 'target_package_id') -cne $QcLogicalId -or [string](Read-QcField $QcRegister 'target_package_sha256') -ne [string]$Qc01.target_package_sha256) { $QcAuthorityDefects += 'REQUIREMENT_TARGET_MISMATCH' }
$QcSourceRef = [string](Read-QcField $QcRegister 'requirement_source_ref')
$QcSourceSha = [string](Read-QcField $QcRegister 'requirement_source_sha256')
if ([string]::IsNullOrWhiteSpace($QcSourceRef) -or $QcSourceSha -notmatch '^[a-fA-F0-9]{64}$' -or -not (Test-Path -LiteralPath $QcSourceRef -PathType Leaf)) { $QcAuthorityDefects += 'REQUIREMENT_SOURCE_BYTES_UNAVAILABLE' }
elseif ((Get-QcSha256 -LiteralPath $QcSourceRef) -ne $QcSourceSha.ToLowerInvariant()) { $QcAuthorityDefects += 'REQUIREMENT_SOURCE_HASH_MISMATCH' }
$QcMandatoryIds = @(ConvertTo-QcArray -Value (Read-QcField $QcRegister 'mandatory_property_ids'))
$QcActualIds = @($QcRequirements | ForEach-Object { [string](Read-QcField $_ 'property_id') })
if ($QcMandatoryIds.Count -eq 0 -or @($QcMandatoryIds | Sort-Object -Unique).Count -ne $QcMandatoryIds.Count -or (($QcMandatoryIds | Sort-Object) -join '|') -ne (($QcActualIds | Sort-Object) -join '|')) { $QcAuthorityDefects += 'MANDATORY_PROPERTY_SET_MISMATCH' }
$QcContracts = @()
$QcDefects = @($QcAuthorityDefects)
$QcPropertyIds = @{}

foreach ($QcRequirement in $QcRequirements) {
    $QcRequiredFields = @(
        'property_id','property_family','property_scope_class','requirement_id','owner_objective_id',
        'earliest_detectable_stage','latest_permitted_detection_stage','positive_control_id','expected_property',
        'oracle_id','oracle_type','qualification_profile','platform_profile','runtime_profile','fail_effect','block_effect','downstream_admission_effect'
    )
    foreach ($QcField in $QcRequiredFields) {
        $QcValue = $QcRequirement.PSObject.Properties[$QcField]
        if ($null -eq $QcValue -or [string]::IsNullOrWhiteSpace([string]$QcValue.Value)) {
            $QcDefects += "MISSING_FIELD|$([string](Read-QcField $QcRequirement 'property_id'))|$QcField"
        }
    }
    if (@(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'target_member_ids')).Count -eq 0) { $QcDefects += 'TARGET_MEMBER_SET_EMPTY' }
    $QcPropertyId = [string](Read-QcField $QcRequirement 'property_id')
    if ($QcPropertyIds.ContainsKey($QcPropertyId)) {
        $QcDefects += "DUPLICATE_PROPERTY_ID|$QcPropertyId"
    }
    else {
        $QcPropertyIds[$QcPropertyId] = $true
    }
    if ($QcAllowedFamilies -notcontains [string](Read-QcField $QcRequirement 'property_family')) {
        $QcDefects += "INVALID_PROPERTY_FAMILY|$QcPropertyId"
    }
    if ($QcAllowedScopes -notcontains [string](Read-QcField $QcRequirement 'property_scope_class')) {
        $QcDefects += "INVALID_SCOPE_CLASS|$QcPropertyId"
    }
    $QcStages = @('QC-01','QC-02','QC-03','QC-04','QC-05','QC-06')
    $QcEarliest = [string](Read-QcField $QcRequirement 'earliest_detectable_stage')
    $QcLatest = [string](Read-QcField $QcRequirement 'latest_permitted_detection_stage')
    if ($QcStages -cnotcontains $QcEarliest -or $QcStages -cnotcontains $QcLatest -or [array]::IndexOf($QcStages,$QcEarliest) -gt [array]::IndexOf($QcStages,$QcLatest)) { $QcDefects += ("INVALID_DETECTION_STAGE_ORDER|$QcPropertyId") }
    $QcNegativeControls = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'negative_control_ids'))
    $QcEvidenceFields = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'required_evidence_fields'))
    if (@($QcNegativeControls | Sort-Object -Unique).Count -ne $QcNegativeControls.Count -or $QcNegativeControls -contains [string](Read-QcField $QcRequirement 'positive_control_id')) { $QcDefects += "DUPLICATE_OR_OVERLAPPING_CONTROL|$QcPropertyId" }
    if ($QcNegativeControls.Count -eq 0) {
        $QcDefects += "NEGATIVE_CONTROL_MISSING|$QcPropertyId"
    }
    if ($QcEvidenceFields.Count -eq 0) {
        $QcDefects += "EVIDENCE_FIELDS_MISSING|$QcPropertyId"
    }
    foreach ($QcArrayField in @('invariant_ids','target_member_ids','target_interface_ids','required_evidence_fields','negative_control_ids')) {
        $QcValues = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement $QcArrayField))
        if (@($QcValues | Sort-Object -Unique).Count -ne $QcValues.Count -or @($QcValues | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) { $QcDefects += "INVALID_ARRAY|$QcPropertyId|$QcArrayField" }
    }
    $QcOracleSpecs = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'oracle_specifications'))
    $QcControls = @([string](Read-QcField $QcRequirement 'positive_control_id')) + $QcNegativeControls
    $QcOracleControls = @($QcOracleSpecs | ForEach-Object { [string](Read-QcField $_ 'control_id') })
    if (@($QcOracleControls | Sort-Object -Unique).Count -ne $QcOracleControls.Count -or (($QcOracleControls | Sort-Object) -join '|') -ne (($QcControls | Sort-Object) -join '|')) { $QcDefects += "ORACLE_CONTROL_SET_MISMATCH|$QcPropertyId" }
    foreach ($QcSpec in $QcOracleSpecs) {
        $QcExitValues = @(ConvertTo-QcArray -Value (Read-QcField $QcSpec 'expected_exit'))
        if ($QcExitValues.Count -eq 0 -or @($QcExitValues | Where-Object { $_ -isnot [int] -and $_ -isnot [long] }).Count -gt 0 -or [string](Read-QcField $QcSpec 'oracle_id') -ne [string](Read-QcField $QcRequirement 'oracle_id') -or (Read-QcField $QcSpec 'expected_stdout_contains') -isnot [string] -or (Read-QcField $QcSpec 'expected_stderr_contains') -isnot [string]) { $QcDefects += "INVALID_ORACLE_SPECIFICATION|$QcPropertyId" }
    }
    $QcExecutionProfile = $null
    try { $QcExecutionProfile = Get-QcExecutionProfile $QcRequirement }
    catch { $QcDefects += ('EXECUTION_PROFILE_INVALID|' + $QcPropertyId + '|' + $_.Exception.Message) }
    $QcContracts += [pscustomobject][ordered]@{
        property_id = $QcPropertyId
        property_family = [string](Read-QcField $QcRequirement 'property_family')
        property_scope_class = [string](Read-QcField $QcRequirement 'property_scope_class')
        requirement_id = [string](Read-QcField $QcRequirement 'requirement_id')
        owner_objective_id = [string](Read-QcField $QcRequirement 'owner_objective_id')
        invariant_ids = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'invariant_ids'))
        target_member_ids = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'target_member_ids'))
        target_interface_ids = @(ConvertTo-QcArray -Value (Read-QcField $QcRequirement 'target_interface_ids'))
        earliest_detectable_stage = [string](Read-QcField $QcRequirement 'earliest_detectable_stage')
        latest_permitted_detection_stage = [string](Read-QcField $QcRequirement 'latest_permitted_detection_stage')
        positive_control_id = [string](Read-QcField $QcRequirement 'positive_control_id')
        negative_control_ids = $QcNegativeControls
        expected_property = [string](Read-QcField $QcRequirement 'expected_property')
        oracle_id = [string](Read-QcField $QcRequirement 'oracle_id')
        oracle_type = [string](Read-QcField $QcRequirement 'oracle_type')
        required_evidence_fields = $QcEvidenceFields
        qualification_profile = [string](Read-QcField $QcRequirement 'qualification_profile')
        platform_profile = [string](Read-QcField $QcRequirement 'platform_profile')
        runtime_profile = [string](Read-QcField $QcRequirement 'runtime_profile')
        execution_profile = $QcExecutionProfile
        oracle_specifications = $QcOracleSpecs
        fail_effect = [string](Read-QcField $QcRequirement 'fail_effect')
        block_effect = [string](Read-QcField $QcRequirement 'block_effect')
        downstream_admission_effect = [string](Read-QcField $QcRequirement 'downstream_admission_effect')
    }
}

$QcCompilationStatus = 'PASS'
if ($QcDefects.Count -gt 0) { $QcCompilationStatus = 'BLOCKED' }
# F01/F05 V46: external immutable host trust policy + signed exact requirement register.
# No producer-supplied trust pin, no synthetic approval, no automatic admission.
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetFullPath((Split-Path -Parent $OutputPath))) | Out-Null
$QcAuthorityEvidence = Join-Path (Split-Path -Parent $OutputPath) 'QC02_V46_AUTHORITY.json'
$QcEnvelopePath = [string](Read-QcField $QcRegister 'authority_envelope_ref')
$QcBridge = Join-Path $PSScriptRoot 'authority_bridge_v46.py'
$QcPython = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
$QcGateArgs = @($QcBridge,'--mode','qc02','--subject',$RequirementRegisterPath,'--output',$QcAuthorityEvidence)
if (-not [string]::IsNullOrWhiteSpace($QcSourceRef)) { $QcGateArgs += @('--source',$QcSourceRef) }
if (-not [string]::IsNullOrWhiteSpace($QcEnvelopePath)) { $QcGateArgs += @('--envelope',$QcEnvelopePath) }
$QcGateText = & $QcPython.Source @QcGateArgs 2>&1
$QcGateExit = $LASTEXITCODE
$QcAuthorityVerified = ($QcGateExit -eq 0 -and (Test-Path -LiteralPath $QcAuthorityEvidence -PathType Leaf) -and [string](Import-QcJson -LiteralPath $QcAuthorityEvidence).status -eq 'VERIFIED_FOR_NATIVE_STAGE_ONLY')
if (-not $QcAuthorityVerified) { $QcDefects += 'EXTERNAL_CONTRACT_AUTHORITY_ROOT_NOT_PROVEN' }
$QcAuthorityState = if ($QcAuthorityVerified) { 'EXTERNAL_ROOT_VERIFIED_FOR_STAGE' } else { 'EXTERNAL_ROOT_NOT_PROVEN' }
$QcStatus = if ($QcDefects.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
foreach ($QcCompiledContract in $QcContracts) {
    try { $null = Assert-QcSchema -Value $QcCompiledContract -SchemaName 'property-contract-v01.schema.json' }
    catch { $QcDefects += ('CONTRACT_SCHEMA_INVALID|' + $_.Exception.Message); $QcCompilationStatus = 'BLOCKED' }
}
$QcStatus = if ($QcDefects.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC02_QUALIFICATION_CONTRACT_V01'
    component_id = 'QC-02'
    status = $QcStatus
    compilation_status = $QcCompilationStatus
    authority_authentication = $QcAuthorityState
    target_package_id = $QcLogicalId
    target_package_sha256 = [string]$Qc01.target_package_sha256
    contract_source_provenance = [pscustomobject]@{ source_authority = [string](Read-QcField $QcRegister 'source_authority'); source_ref = $QcSourceRef; source_sha256 = $QcSourceSha; contract_state = [string](Read-QcField $QcRegister 'contract_state'); currentness_state = [string](Read-QcField $QcRegister 'currentness_state'); authority_authentication = $QcAuthorityState }
    mandatory_property_ids = $QcMandatoryIds
    required_property_count = $QcContracts.Count
    property_contracts = $QcContracts
    compiler_defects = $QcDefects
    unmapped_required_property_count = $QcDefects.Count
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
