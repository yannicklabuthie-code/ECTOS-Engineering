[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qh01HandoffPath,
    [Parameter(Mandatory = $true)][string]$Qc02ContractPath,
    [Parameter(Mandatory = $true)][string]$Qc03RoutesPath,
    [Parameter(Mandatory = $true)][string]$Qc04ExecutionPath,
    [Parameter(Mandatory = $true)][string]$Qc05ClosurePath,
    [Parameter(Mandatory = $false)][string]$TargetPath,
    [Parameter(Mandatory = $false)][string]$IndependentReportPath,
    [Parameter(Mandatory = $false)][string]$IndependentEnvelopePath,
    [Parameter(Mandatory = $false)][string]$IndependentEvidenceDirectory,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

function Get-QcControlSet {
    param([Parameter(Mandatory = $true)]$Contract)
    $QcControlSet = @([string]$Contract.positive_control_id)
    $QcControlSet += @(ConvertTo-QcArray -Value $Contract.negative_control_ids | ForEach-Object { [string]$_ })
    return @($QcControlSet)
}

function Test-QcIndependentCompleteness {
    param(
        [Parameter(Mandatory = $true)]$Contracts,
        [Parameter(Mandatory = $true)]$Routes,
        [Parameter(Mandatory = $true)]$Executions,
        [Parameter(Mandatory = $true)]$EvidenceRows
    )
    $expectedKeys = @()
    foreach ($QcContractItem in @(ConvertTo-QcArray -Value $Contracts)) {
        foreach ($QcControlId in @(Get-QcControlSet -Contract $QcContractItem)) {
            $expectedKeys += ([string]$QcContractItem.property_id + '|' + $QcControlId)
            $QcRouteCount = @($Routes | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            $QcExecutionCount = @($Executions | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            $QcEvidenceCount = @($EvidenceRows | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            if ($QcRouteCount -ne 1 -or $QcExecutionCount -ne 1 -or $QcEvidenceCount -ne 1) {
                return $false
            }
        }
    }
    if ($expectedKeys.Count -eq 0 -or @($expectedKeys | Sort-Object -Unique).Count -ne $expectedKeys.Count) { return $false }
    foreach ($rows in @(@{value=$Routes},@{value=$Executions},@{value=$EvidenceRows})) {
        $keys = @($rows.value | ForEach-Object { [string]$_.property_id + '|' + [string]$_.control_id })
        if ($keys.Count -ne $expectedKeys.Count -or (($keys | Sort-Object) -join "`n") -cne (($expectedKeys | Sort-Object) -join "`n")) { return $false }
    }
    return $true
}

$QcHandoff = Import-QcJson -LiteralPath $Qh01HandoffPath
$Qc02 = Import-QcJson -LiteralPath $Qc02ContractPath
$Qc03 = Import-QcJson -LiteralPath $Qc03RoutesPath
$Qc04 = Import-QcJson -LiteralPath $Qc04ExecutionPath
$Qc05 = Import-QcJson -LiteralPath $Qc05ClosurePath
$QcSelfPath = $MyInvocation.MyCommand.Path
$QcProcessDefects = @()
$QcNewDefects = @()
$QcConfirmedDefects = @()
$QcRuns = @()
if ([string]::IsNullOrWhiteSpace($TargetPath) -or -not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    $QcProcessDefects += 'PHYSICAL_TARGET_PACKAGE_MISSING'
}
else {
    $targetBefore = Get-QcSha256 -LiteralPath $TargetPath
    if ($targetBefore -ne [string]$QcHandoff.target_package_sha256 -or [System.IO.Path]::GetFileNameWithoutExtension($TargetPath) -cne [string]$QcHandoff.target_package_id) { $QcProcessDefects += 'PHYSICAL_TARGET_IDENTITY_MISMATCH' }
}

$QcPropertyPath = $null
$QcPropertyHash = ''
if ($QcHandoff.PSObject.Properties['qcct_records_directory'] -and -not [string]::IsNullOrWhiteSpace([string]$QcHandoff.qcct_records_directory)) {
    $QcPropertyPath = Join-Path ([string]$QcHandoff.qcct_records_directory) 'property-records.json'
    if (Test-Path -LiteralPath $QcPropertyPath -PathType Leaf) { $QcPropertyHash = Get-QcSha256 -LiteralPath $QcPropertyPath }
    else { $QcProcessDefects += 'PHYSICAL_PROPERTY_REGISTER_MISSING' }
}
else { $QcProcessDefects += 'QCCT_RECORDS_DIRECTORY_MISSING' }
$QcFreezeRows = @()
if (-not $QcHandoff.PSObject.Properties['frozen_ledger_path'] -or -not $QcHandoff.PSObject.Properties['frozen_ledger_sha256']) { $QcProcessDefects += 'FROZEN_LEDGER_BINDING_MISSING' }
elseif (-not (Test-Path -LiteralPath ([string]$QcHandoff.frozen_ledger_path) -PathType Leaf)) { $QcProcessDefects += 'FROZEN_LEDGER_MISSING' }
elseif ((Get-QcSha256 -LiteralPath ([string]$QcHandoff.frozen_ledger_path)) -ne [string]$QcHandoff.frozen_ledger_sha256) { $QcProcessDefects += 'FROZEN_LEDGER_HASH_MISMATCH' }
else {
    $QcFreeze = Import-QcJson -LiteralPath ([string]$QcHandoff.frozen_ledger_path)
    if ([string]$QcFreeze.target_package_id -cne [string]$QcHandoff.target_package_id -or [string]$QcFreeze.target_package_sha256 -ne [string]$QcHandoff.target_package_sha256) { $QcProcessDefects += 'FROZEN_LEDGER_TARGET_MISMATCH' }
    $QcFreezeRows = @(ConvertTo-QcArray -Value $QcFreeze.members)
    $seenFreeze = @{}
    foreach ($row in $QcFreezeRows) {
        $key = ([string]$row.path).ToLowerInvariant()
        if ($seenFreeze.ContainsKey($key)) { $QcProcessDefects += ('FROZEN_LEDGER_DUPLICATE_PATH|' + [string]$row.path) }
        $seenFreeze[$key] = $true
        if (-not (Test-Path -LiteralPath ([string]$row.path) -PathType Leaf)) { $QcProcessDefects += ('FROZEN_MEMBER_MISSING|' + [string]$row.path); continue }
        if ((Get-QcSha256 -LiteralPath ([string]$row.path)) -ne [string]$row.sha256 -or (Get-Item -LiteralPath ([string]$row.path)).Length -ne [int64]$row.size_bytes) { $QcProcessDefects += ('FROZEN_MEMBER_BYTES_MISMATCH|' + [string]$row.path) }
    }
    $QcRequiredFrozen = @($Qc02ContractPath,$Qc03RoutesPath,$Qc04ExecutionPath,$Qc05ClosurePath,$QcSelfPath,$QcModulePath,(Join-Path $PSScriptRoot 'QC-CT-VerifyContractRecords.ps1'))
    $QcRequiredFrozen += @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.py' | ForEach-Object { $_.FullName })
    $QcRequiredFrozen += @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../../schemas/qualification_center/v01') -Filter '*.schema.json' | ForEach-Object { $_.FullName })
    if ($null -ne $QcPropertyPath) { $QcRequiredFrozen += @($QcPropertyPath,(Join-Path ([string]$QcHandoff.qcct_records_directory) 'qc-envelopes.json')) }
    foreach ($execution in @(ConvertTo-QcArray -Value $Qc04.execution_results)) { $QcRequiredFrozen += @([string]$execution.raw_stdout_ref,[string]$execution.raw_stderr_ref,[string]$execution.script_path,[string]$execution.command_path) }
    foreach ($row in @(ConvertTo-QcArray -Value $Qc05.causal_evidence_ledger)) { $QcRequiredFrozen += [string]$row.evidence_path }
    foreach ($path in @($QcRequiredFrozen | Sort-Object -Unique)) {
        if (@($QcFreezeRows | Where-Object { [string]$_.path -ceq $path }).Count -ne 1) { $QcProcessDefects += ('REQUIRED_FROZEN_MEMBER_NOT_BOUND|' + $path) }
    }
}
$QcBindingChecks = [ordered]@{
    qualification_contract_sha256 = Get-QcSha256 -LiteralPath $Qc02ContractPath
    property_register_sha256 = $QcPropertyHash
    route_register_sha256 = Get-QcSha256 -LiteralPath $Qc03RoutesPath
    execution_return_sha256 = Get-QcSha256 -LiteralPath $Qc04ExecutionPath
    evidence_bundle_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    defect_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    not_proven_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    qualifier_sha256 = Get-QcSha256 -LiteralPath $QcSelfPath
}
foreach ($QcBindingName in $QcBindingChecks.Keys) {
    if (-not $QcHandoff.PSObject.Properties[$QcBindingName] -or [string]$QcHandoff.$QcBindingName -ne [string]$QcBindingChecks[$QcBindingName]) {
        $QcProcessDefects += "HANDOFF_BINDING_MISMATCH|$QcBindingName"
    }
}
function Test-QcTargetIdentityBinding {
    param($Handoff, $Contract, $Routes, $Execution, $Closure)
    $expected = [string]$Handoff.target_package_sha256
    if ($expected -notmatch '^[a-fA-F0-9]{64}$') { return $false }
    foreach ($actual in @($Contract, $Routes, $Execution, $Closure)) {
        if ([string]$actual.target_package_sha256 -ne $expected -or [string]$actual.target_package_id -cne [string]$Handoff.target_package_id) { return $false }
    }
    return $true
}
if (-not (Test-QcTargetIdentityBinding -Handoff $QcHandoff -Contract $Qc02 -Routes $Qc03 -Execution $Qc04 -Closure $Qc05)) {
    $QcProcessDefects += 'TARGET_IDENTITY_MISMATCH'
}
if ([string]$QcHandoff.qualifier_id -ne 'ECTOS_QC06_INDEPENDENT_QUALIFIER') {
    $QcProcessDefects += 'QUALIFIER_IDENTITY_MISMATCH'
}
if ($QcHandoff.no_mutation_after_freeze -isnot [bool] -or $QcHandoff.no_mutation_after_freeze -ne $true) {
    $QcProcessDefects += 'HANDOFF_MUTATION_NOT_PROHIBITED'
}

$QcContracts = @(ConvertTo-QcArray -Value $Qc02.property_contracts)
$QcRoutes = @(ConvertTo-QcArray -Value $Qc03.routes)
$QcExecutions = @(ConvertTo-QcArray -Value $Qc04.execution_results)
$QcEvidenceRows = @(ConvertTo-QcArray -Value $Qc05.causal_evidence_ledger)
$QcIndependentComplete = Test-QcIndependentCompleteness -Contracts $QcContracts -Routes $QcRoutes -Executions $QcExecutions -EvidenceRows $QcEvidenceRows
if (-not $QcIndependentComplete) {
    $QcProcessDefects += 'INDEPENDENT_COMPLETENESS_CHECK_FAILED'
}
$QcRuns += 'INDEPENDENT_COMPLETENESS_RECOMPUTE'
if ([string]$Qc02.status -ne 'PASS' -or [string]$Qc03.status -ne 'PASS' -or [string]$Qc04.status -ne 'PASS' -or [string]$Qc05.pre_qf_state -ne 'PASS') { $QcProcessDefects += 'UPSTREAM_NOT_CLOSED' }

# Negative control 1: a foreign target identity must be rejected by the independent binding logic.
$QcTamperedHandoff = $QcHandoff | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$QcTamperedHandoff.target_package_sha256 = ('0' * 64)
$QcMutatedTargetRejected = -not (Test-QcTargetIdentityBinding -Handoff $QcTamperedHandoff -Contract $Qc02 -Routes $Qc03 -Execution $Qc04 -Closure $Qc05)
if (-not $QcMutatedTargetRejected) {
    $QcProcessDefects += 'NEGATIVE_TARGET_BINDING_CONTROL_FAILED'
}
$QcRuns += 'NEGATIVE_TARGET_BINDING_CHALLENGE'

# Negative control 2: removing one evidence row must make completeness fail.
$QcDroppedEvidenceRejected = $true
if ($QcEvidenceRows.Count -gt 0) {
    $QcReducedEvidence = @()
    if ($QcEvidenceRows.Count -gt 1) {
        $QcReducedEvidence = @($QcEvidenceRows[1..($QcEvidenceRows.Count - 1)])
    }
    $QcReducedComplete = Test-QcIndependentCompleteness -Contracts $QcContracts -Routes $QcRoutes -Executions $QcExecutions -EvidenceRows $QcReducedEvidence
    if ($QcReducedComplete) {
        $QcDroppedEvidenceRejected = $false
    }
}
else {
    $QcDroppedEvidenceRejected = $false
}
if (-not $QcDroppedEvidenceRejected) {
    $QcProcessDefects += 'NEGATIVE_MISSING_EVIDENCE_CONTROL_FAILED'
}
$QcRuns += 'NEGATIVE_MISSING_EVIDENCE_CHALLENGE'

$QcPropertyResults = @()
$QcAllPropertyPass = $true
$QcAllNegativeControlsPass = $true
$QcArchitecturePropertyCount = 0
$QcArchitecturePropertiesPass = $true
foreach ($QcContract in $QcContracts) {
    $QcControls = @(Get-QcControlSet -Contract $QcContract)
    $QcControlResults = @()
    $QcPropertyPass = $true
    foreach ($QcControlId in $QcControls) {
        $QcExecutionMatches = @($QcExecutions | Where-Object { [string]$_.property_id -eq [string]$QcContract.property_id -and [string]$_.control_id -eq $QcControlId })
        $QcControlPass = $false
        if ($QcExecutionMatches.Count -eq 1 -and [string]$QcExecutionMatches[0].preliminary_result -eq 'PASS') {
            $QcControlPass = $true
        }
        if (-not $QcControlPass) {
            $QcPropertyPass = $false
            if ($QcControlId -ne [string]$QcContract.positive_control_id) {
                $QcAllNegativeControlsPass = $false
            }
        }
        $QcControlResults += [pscustomobject][ordered]@{ control_id = $QcControlId; pass = $QcControlPass }
    }
    if (-not $QcPropertyPass) { $QcAllPropertyPass = $false }
    if (@('INTERFACE','COMPOSITIONAL','SYSTEM','AUTHORITY') -contains [string]$QcContract.property_scope_class) {
        $QcArchitecturePropertyCount++
        if (-not $QcPropertyPass) { $QcArchitecturePropertiesPass = $false }
    }
    $QcPropertyResultText = 'FAIL'
    if ($QcPropertyPass) { $QcPropertyResultText = 'PASS' }
    $QcPropertyResults += [pscustomobject][ordered]@{
        property_id = [string]$QcContract.property_id
        property_scope_class = [string]$QcContract.property_scope_class
        result = $QcPropertyResultText
        controls = $QcControlResults
    }
}

$QcObjectiveMatch = 'FAIL'
if ($QcAllPropertyPass -and $QcContracts.Count -gt 0) { $QcObjectiveMatch = 'PASS' }
$QcInvariantMatch = $QcObjectiveMatch
$QcProhibitedAbsence = 'FAIL'
if ($QcAllNegativeControlsPass -and $QcContracts.Count -gt 0) { $QcProhibitedAbsence = 'PASS' }
$QcArchitecturalIntent = 'NOT_PROVEN'
if ($QcArchitecturePropertyCount -gt 0) {
    if ($QcArchitecturePropertiesPass) { $QcArchitecturalIntent = 'PASS' } else { $QcArchitecturalIntent = 'FAIL' }
}
$QcConstraintRelocation = 'NOT_PROVEN'
$QcArchitecturalSubstitution = 'NOT_PROVEN'
if ($QcArchitecturalIntent -eq 'PASS' -and $QcProhibitedAbsence -eq 'PASS') {
    $QcConstraintRelocation = 'NO'
    $QcArchitecturalSubstitution = 'NO'
}

foreach ($QcDefect in @(ConvertTo-QcArray -Value $Qc05.consolidated_defect_register)) {
    $QcConfirmedDefects += [string]$QcDefect.defect_id
}
$QcExternalTrustScope = [string]$QcHandoff.qualifier_trust_scope_id
$QcOrganizationalIndependence = 'NOT_PROVEN'
$QcLogicIndependence = 'NOT_PROVEN'
$QcDataIndependence = 'NOT_PROVEN'
$QcOracleIndependence = 'NOT_PROVEN'
$QcProcessDefects += 'EXTERNAL_INDEPENDENCE_PROVENANCE_MISSING'
$QcProcessDefects += 'EXTERNAL_ORACLE_EVIDENCE_MISSING'
if ($QcProcessDefects.Count -gt 0) {
    $QcLogicIndependence = 'NOT_PROVEN'
    $QcOracleIndependence = 'NOT_PROVEN'
}

$QcFinalState = 'PASS'
if ($QcProcessDefects.Count -gt 0 -or -not $QcIndependentComplete -or $QcArchitecturalIntent -eq 'NOT_PROVEN') {
    $QcFinalState = 'BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE'
}
elseif (-not $QcAllPropertyPass -or $QcConfirmedDefects.Count -gt 0) {
    $QcFinalState = 'FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET'
}
elseif ($QcObjectiveMatch -ne 'PASS' -or $QcInvariantMatch -ne 'PASS' -or $QcProhibitedAbsence -ne 'PASS' -or $QcConstraintRelocation -ne 'NO' -or $QcArchitecturalSubstitution -ne 'NO') {
    $QcFinalState = 'FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET'
}

# Producer declarations are observations only; no independent oracle receipt exists.
$QcProducerProjection = $QcPropertyResults
$QcPropertyResults = @()
$QcObjectiveMatch = 'NOT_PROVEN'
$QcInvariantMatch = 'NOT_PROVEN'
$QcProhibitedAbsence = 'NOT_PROVEN'
$QcArchitecturalIntent = 'NOT_PROVEN'
$QcConstraintRelocation = 'NOT_PROVEN'
$QcArchitecturalSubstitution = 'NOT_PROVEN'
if (-not [string]::IsNullOrWhiteSpace($TargetPath) -and (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    if ((Get-QcSha256 -LiteralPath $TargetPath) -ne $targetBefore) { $QcProcessDefects += 'PHYSICAL_TARGET_MUTATED_DURING_REVIEW' }
}
$QcFinalState = 'BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE'
# V47: optional authenticated external report. Production never accepts a caller-supplied root.
# Missing input retains the historical fail-closed state; producer projection is never promoted.
if (-not [string]::IsNullOrWhiteSpace($IndependentReportPath)) {
    try {
        $QcExternal = Import-QcJson -LiteralPath $IndependentReportPath
        Assert-QcSchema -Value $QcExternal -SchemaName 'qc06-return-v01.schema.json'
        $QcExpectedKeys = @()
        foreach ($contract in $QcContracts) { foreach ($control in @(Get-QcControlSet -Contract $contract)) { $QcExpectedKeys += ,@([string]$contract.property_id,[string]$control) } }
        $QcExpected = [pscustomobject]@{
            bindings = [pscustomobject]@{target_sha256=[string]$QcHandoff.target_package_sha256;qc02_sha256=(Get-QcSha256 $Qc02ContractPath);qc03_sha256=(Get-QcSha256 $Qc03RoutesPath);qc04_sha256=(Get-QcSha256 $Qc04ExecutionPath);qc05_sha256=(Get-QcSha256 $Qc05ClosurePath);qh01_sha256=(Get-QcSha256 $Qh01HandoffPath)}
            report_bindings = [pscustomobject]@{target_package_id=[string]$QcHandoff.target_package_id;target_package_sha256=[string]$QcHandoff.target_package_sha256;qualifier_sha256=[string]$QcBindingChecks.qualifier_sha256;qualification_contract_id=('SHA256:'+[string]$QcBindingChecks.qualification_contract_sha256)}
            control_keys = $QcExpectedKeys
            producer_receipt_sha256 = @($QcExecutions | ForEach-Object { [string]$_.stdout_sha256; [string]$_.stderr_sha256 }) + @($QcEvidenceRows | ForEach-Object { [string]$_.raw_evidence_sha256 })
        }
        $QcExpectedPath = $OutputPath + '.independent-expected.json'
        $QcExternalGatePath = $OutputPath + '.independent-authentication.json'
        Export-QcJson $QcExpected $QcExpectedPath
        $QcPython = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
        & $QcPython.Source (Join-Path $PSScriptRoot 'independent_bridge_v47.py') --report $IndependentReportPath --envelope $IndependentEnvelopePath --expected $QcExpectedPath --evidence-directory $IndependentEvidenceDirectory --output $QcExternalGatePath | Out-Null
        if ($LASTEXITCODE -ne 0 -or [string](Import-QcJson $QcExternalGatePath).status -ne 'VERIFIED_EXTERNAL_REPORT_ONLY') { throw 'EXTERNAL_REPORT_AUTHENTICATION_FAILED' }
        $QcProcessDefects = @($QcProcessDefects | Where-Object { $_ -notin @('EXTERNAL_INDEPENDENCE_PROVENANCE_MISSING','EXTERNAL_ORACLE_EVIDENCE_MISSING') })
        if ($QcProcessDefects.Count -eq 0) {
            $QcExternalTrustScope=[string]$QcExternal.qualifier_trust_scope_id
            $QcOrganizationalIndependence=[string]$QcExternal.organizational_independence
            $QcLogicIndependence=[string]$QcExternal.logic_independence
            $QcDataIndependence=[string]$QcExternal.data_independence
            $QcOracleIndependence=[string]$QcExternal.oracle_independence
            $QcPropertyResults=@(ConvertTo-QcArray $QcExternal.independent_property_results)
            $QcRuns=@(ConvertTo-QcArray $QcExternal.independent_run_ledger)
            $QcObjectiveMatch=[string]$QcExternal.objective_match
            $QcInvariantMatch=[string]$QcExternal.invariant_match
            $QcProhibitedAbsence=[string]$QcExternal.prohibited_behavior_absence
            $QcArchitecturalIntent=[string]$QcExternal.architectural_intent_match
            $QcConstraintRelocation=[string]$QcExternal.constraint_relocation
            $QcArchitecturalSubstitution=[string]$QcExternal.architectural_substitution
            $QcNewDefects=@(ConvertTo-QcArray $QcExternal.new_defects)
            $QcConfirmedDefects=@($QcConfirmedDefects + @(ConvertTo-QcArray $QcExternal.confirmed_defects) | Sort-Object -Unique)
            $QcFinalState=[string]$QcExternal.final_state
            if ($QcConfirmedDefects.Count -gt 0 -and $QcFinalState -eq 'PASS') { $QcFinalState='FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET' }
        }
    } catch { $QcProcessDefects += ('EXTERNAL_INDEPENDENT_REPORT_DENIED|' + $_.Exception.Message); $QcFinalState='BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE' }
}
$QcReturn = [pscustomobject][ordered]@{
    target_package_id = [string]$QcHandoff.target_package_id
    target_package_sha256 = [string]$QcHandoff.target_package_sha256
    qualifier_id = [string]$QcHandoff.qualifier_id
    qualifier_sha256 = [string]$QcBindingChecks.qualifier_sha256
    qualifier_trust_scope_id = $QcExternalTrustScope
    qualification_contract_id = ('SHA256:' + [string]$QcBindingChecks.qualification_contract_sha256)
    organizational_independence = $QcOrganizationalIndependence
    logic_independence = $QcLogicIndependence
    data_independence = $QcDataIndependence
    oracle_independence = $QcOracleIndependence
    shared_code_set = @('QC.Common.psm1')
    shared_test_logic_set = @()
    shared_fixture_set = @()
    shared_oracle_set = @()
    shared_data_source_set = @('FROZEN_QH01_INPUTS')
    independence_risk_register = $QcProcessDefects
    independent_run_ledger = $QcRuns
    independent_property_results = $QcPropertyResults
    producer_property_projection_not_independent = $QcProducerProjection
    new_defects = $QcNewDefects
    confirmed_defects = $QcConfirmedDefects
    qualification_process_defects = $QcProcessDefects
    objective_match = $QcObjectiveMatch
    architectural_intent_match = $QcArchitecturalIntent
    invariant_match = $QcInvariantMatch
    prohibited_behavior_absence = $QcProhibitedAbsence
    constraint_relocation = $QcConstraintRelocation
    architectural_substitution = $QcArchitecturalSubstitution
    final_state = $QcFinalState
}
Assert-QcSchema -Value $QcReturn -SchemaName 'qc06-return-v01.schema.json'
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcFinalState -eq 'PASS') { exit 0 }
if ($QcFinalState -eq 'FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET') { exit 40 }
exit 50
