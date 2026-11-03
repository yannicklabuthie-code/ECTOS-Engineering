[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$RecordsDirectory,
 [Parameter(Mandatory=$true)][string]$StageDirectory,
 [Parameter(Mandatory=$true)][string]$OutputPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'QC.Common.psm1') -Force
$QcIssues=@()
$QcEnvelopeFile=Join-Path $RecordsDirectory 'qc-envelopes.json'
$QcPropertyFile=Join-Path $RecordsDirectory 'property-records.json'
if(-not (Test-Path -LiteralPath $QcEnvelopeFile -PathType Leaf)){throw 'QC_CT_ENVELOPE_FILE_MISSING'}
if(-not (Test-Path -LiteralPath $QcPropertyFile -PathType Leaf)){throw 'QC_CT_PROPERTY_FILE_MISSING'}
$QcEnvelopes=@(ConvertTo-QcArray -Value (Import-QcJson -LiteralPath $QcEnvelopeFile).envelopes)
$QcProperties=@(ConvertTo-QcArray -Value (Import-QcJson -LiteralPath $QcPropertyFile).records)
$QcStageNames=@('qc01','qc02','qc03','qc04','qc05')
if($QcEnvelopes.Count -ne $QcStageNames.Count){$QcIssues+=('ENVELOPE_COUNT_MISMATCH|'+$QcEnvelopes.Count)}
if($QcProperties.Count -eq 0){$QcIssues+='PROPERTY_RECORDS_MISSING'}
for($QcIndex=0;$QcIndex -lt $QcStageNames.Count;$QcIndex++){
 $QcExpectedPath=Join-Path $StageDirectory ($QcStageNames[$QcIndex]+'.json')
 if($QcIndex -ge $QcEnvelopes.Count){$QcIssues+='ENVELOPE_MISSING';continue}
 $QcEnv=$QcEnvelopes[$QcIndex]
 if(-not (Test-Path -LiteralPath $QcExpectedPath -PathType Leaf)){$QcIssues+='STAGE_MISSING';continue}
 if([string]$QcEnv.evidence_references[0] -ne $QcExpectedPath){$QcIssues+=('STAGE_REFERENCE_MISMATCH|'+$QcIndex)}
 if([string]$QcEnv.payload_sha256 -ne (Get-QcSha256 -LiteralPath $QcExpectedPath)){$QcIssues+=('PAYLOAD_HASH_MISMATCH|'+$QcIndex)}
 if([string]$QcEnv.status -ne 'NOT_PROVEN' -or [string]$QcEnv.trust_state -ne 'NOT_PROVEN'){$QcIssues+=('UNSUPPORTED_TRUST_ASSERTION|'+$QcIndex)}
}
$QcContract=Import-QcJson -LiteralPath (Join-Path $StageDirectory 'qc02.json')
$QcContracts=@(ConvertTo-QcArray -Value $QcContract.property_contracts)
if($QcProperties.Count -ne $QcContracts.Count){$QcIssues+='PROPERTY_COUNT_MISMATCH'}
$seen=@{}
foreach($record in $QcProperties){
 try { Assert-QcSchema -Value $record -SchemaName 'property-record-v01.schema.json' } catch { $QcIssues+=('PROPERTY_SCHEMA_INVALID|' + $_.Exception.Message); continue }
 $id=[string]$record.property_id
 if($seen.ContainsKey($id)){$QcIssues+='DUPLICATE_PROPERTY_RECORD'}else{$seen[$id]=$true}
 $QcContractMatches=@($QcContracts | Where-Object {[string]$_.property_id -eq $id})
 if($QcContractMatches.Count -ne 1){$QcIssues+='UNKNOWN_PROPERTY_RECORD';continue}
 $contract=$QcContractMatches[0]
 if([string]$record.status -ne 'NOT_PROVEN' -or [string]$record.source_of_discovery -ne 'PRODUCER_REQUIREMENTS_NOT_INDEPENDENTLY_VERIFIED' -or @($record.trust_assumption_ids) -notcontains 'PRODUCER_INPUT_UNVERIFIED'){$QcIssues+='PROPERTY_UNSUPPORTED_PROVENANCE'}
 foreach($pair in @(@('property_family','property_family'),@('property_scope_class','property_scope_class'),@('positive_control_id','positive_control_id'),@('negative_control_ids','negative_control_ids'),@('oracle_id','oracle_id'),@('earliest_detectable_stage','earliest_detectable_stage'),@('latest_permitted_stage','latest_permitted_detection_stage'),@('target_object_ids','target_member_ids'),@('interface_ids','target_interface_ids'),@('required_evidence','required_evidence_fields'),@('invariant_ids','invariant_ids'))){
  if(($record.($pair[0]) | ConvertTo-Json -Compress) -cne ($contract.($pair[1]) | ConvertTo-Json -Compress)){$QcIssues+=('PROPERTY_BINDING_MISMATCH|'+$id+'|'+$pair[0])}
 }
 if(@($record.requirement_ids).Count -ne 1 -or [string]$record.requirement_ids[0] -ne [string]$contract.requirement_id -or @($record.owner_objective_ids).Count -ne 1 -or [string]$record.owner_objective_ids[0] -ne [string]$contract.owner_objective_id){$QcIssues+='PROPERTY_REQUIREMENT_BINDING_MISMATCH'}
}
for($i=0;$i -lt $QcEnvelopes.Count;$i++){
 $envRecord=$QcEnvelopes[$i]
 try { Assert-QcSchema -Value $envRecord -SchemaName 'qc-envelope-v01.schema.json' } catch { $QcIssues+=('ENVELOPE_SCHEMA_INVALID|' + $_.Exception.Message); continue }
 if($i -ge $QcStageNames.Count){$QcIssues+='UNEXPECTED_ENVELOPE';continue}
 $stage=Import-QcJson -LiteralPath (Join-Path $StageDirectory ($QcStageNames[$i]+'.json'))
 if([string]$envRecord.target_package_id -ne [string]$QcContract.target_package_id -or [string]$envRecord.target_package_sha256 -ne [string]$QcContract.target_package_sha256 -or [string](Get-QcLogicalTargetId -Stage $stage) -cne [string]$QcContract.target_package_id -or [string]$stage.target_package_sha256 -ne [string]$QcContract.target_package_sha256){$QcIssues+='ENVELOPE_TARGET_DIVERGENCE'}
 if([string]$envRecord.payload_type -ne [string]$stage.schema_id -or [string]$envRecord.source_component_id -ne ('QC-0'+($i+1)) -or [string]$envRecord.target_component_id -ne @('QC-02','QC-03','QC-04','QC-05','QC-CT')[$i]){$QcIssues+='ENVELOPE_TYPE_OR_INTERFACE_MISMATCH'}
 if($envRecord.mutation_allowed -isnot [bool] -or $envRecord.mutation_allowed -or @($envRecord.mutation_scope).Count -ne 0){$QcIssues+='ENVELOPE_MUTATION_POLICY_INVALID'}
 if([string]$envRecord.currentness_state -ne 'NOT_PROVEN' -or [string]$envRecord.source_authority_id -ne 'PRODUCER_NOT_INDEPENDENT' -or [string]$envRecord.issuer_id -ne 'QC_CT_PRODUCER'){$QcIssues+='ENVELOPE_UNSUPPORTED_PROVENANCE'}
}
$QcState='PASS_INTEGRITY_ONLY' 
if($QcIssues.Count -gt 0){$QcState='FAIL_INTEGRITY'}
Export-QcJson -Value ([pscustomobject]@{schema_id='ECTOS_QC_CT_INTEGRITY_RETURN_V01';component_id='QC-CT';status=$QcState;state=$QcState;issues=@($QcIssues);envelopes=$QcEnvelopes.Count;properties=$QcProperties.Count;independent_qualification='NOT_EXECUTED';admission='NOT_GRANTED'}) -LiteralPath $OutputPath
if($QcIssues.Count -gt 0){exit 40}
exit 0
