[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$RequirementRegisterPath,
 [Parameter(Mandatory=$true)][string]$StageDirectory,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$MissionId
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'QC.Common.psm1') -Force
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$QcRequirements = @(ConvertTo-QcArray -Value (Import-QcJson -LiteralPath $RequirementRegisterPath).requirements)
$QcRecords=@()
foreach($QcReq in $QcRequirements) {
 $QcRecords += [pscustomobject][ordered]@{
  property_id=[string]$QcReq.property_id; property_family=[string]$QcReq.property_family
  property_scope_class=[string]$QcReq.property_scope_class
  source_of_discovery='PRODUCER_REQUIREMENTS_NOT_INDEPENDENTLY_VERIFIED'
  target_object_ids=@(ConvertTo-QcArray -Value $QcReq.target_member_ids)
  interface_ids=@(ConvertTo-QcArray -Value $QcReq.target_interface_ids)
  dependency_ids=@()
  requirement_ids=@([string]$QcReq.requirement_id)
  owner_objective_ids=@([string]$QcReq.owner_objective_id)
  invariant_ids=@(ConvertTo-QcArray -Value $QcReq.invariant_ids)
  earliest_detectable_stage=[string]$QcReq.earliest_detectable_stage
  latest_permitted_stage=[string]$QcReq.latest_permitted_detection_stage
  positive_control_id=[string]$QcReq.positive_control_id
  negative_control_ids=@(ConvertTo-QcArray -Value $QcReq.negative_control_ids)
  oracle_id=[string]$QcReq.oracle_id
  required_evidence=@(ConvertTo-QcArray -Value $QcReq.required_evidence_fields)
  authority_boundary_ids=@()
  trust_assumption_ids=@('PRODUCER_INPUT_UNVERIFIED')
  status='NOT_PROVEN'
 }
}
$QcPropertyOut=Join-Path $OutputDirectory 'property-records.json'
Export-QcJson -Value ([pscustomobject]@{records=$QcRecords;qualification='NOT_PROVEN'}) -LiteralPath $QcPropertyOut
$QcNames=@('qc01','qc02','qc03','qc04','qc05')
$QcEnvelopes=@()
foreach($QcIndex in 0..($QcNames.Count-1)) {
 $QcName=$QcNames[$QcIndex]
 $QcPath=Join-Path $StageDirectory ($QcName+'.json')
 if(-not (Test-Path -LiteralPath $QcPath -PathType Leaf)){throw "QC_CT_STAGE_MISSING|$QcName"}
 $QcStage=Import-QcJson -LiteralPath $QcPath
 $QcTargets=@('QC-02','QC-03','QC-04','QC-05','QC-CT')
 $QcEnvelopes += [pscustomobject][ordered]@{
  schema_id='ECTOS_QC_ENVELOPE_V01';schema_version='V01'
  message_id=([guid]::NewGuid().ToString('N'));mission_id=$MissionId
  source_component_id=(@('QC-01','QC-02','QC-03','QC-04','QC-05','QH-01','QC-06')[$QcIndex]);target_component_id=$QcTargets[$QcIndex]
  source_run_id=([System.IO.Path]::GetFileName($StageDirectory))
  source_authority_id='PRODUCER_NOT_INDEPENDENT'
  target_package_id=([string](Get-QcLogicalTargetId -Stage $QcStage))
  target_package_sha256=([string]$QcStage.target_package_sha256)
  payload_type=(@('ECTOS_QC01_PACKAGE_DEPTH_RETURN_V01','ECTOS_QC02_QUALIFICATION_CONTRACT_V01','ECTOS_QC03_TOOL_FIT_RETURN_V01','ECTOS_QC04_EXECUTION_RETURN_V01','ECTOS_QC05_PRE_QF_CLOSURE_RETURN_V01','ECTOS_QH01_HANDOFF_V01','ECTOS_QC06_RETURN_V01')[$QcIndex]);payload_sha256=(Get-QcSha256 -LiteralPath $QcPath)
  currentness_state='NOT_PROVEN';trust_state='NOT_PROVEN'
  created_at=([DateTime]::UtcNow.ToString('o'));issuer_id='QC_CT_PRODUCER'
  mutation_allowed=$false;mutation_scope=@();status='NOT_PROVEN'
  evidence_references=@($QcPath);errors=@()
  not_proven_items=@('SOURCE_AUTHORITY','EXTERNAL_INDEPENDENCE')
  blockers=@('NOT_ADMISSIBLE')
 }
}
$QcEnvelopeOut=Join-Path $OutputDirectory 'qc-envelopes.json'
Export-QcJson -Value ([pscustomobject]@{envelopes=$QcEnvelopes;qualification='NOT_PROVEN'}) -LiteralPath $QcEnvelopeOut
Write-Output ('PROPERTY_RECORDS='+$QcRecords.Count)
Write-Output ('QC_ENVELOPES='+$QcEnvelopes.Count)
