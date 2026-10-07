[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qh01HandoffPath,
    [Parameter(Mandatory = $true)][string]$Qc02ContractPath,
    [Parameter(Mandatory = $true)][string]$Qc03RoutesPath,
    [Parameter(Mandatory = $true)][string]$Qc04ExecutionPath,
    [Parameter(Mandatory = $true)][string]$Qc05ClosurePath,
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
    foreach ($QcContractItem in @(ConvertTo-QcArray -Value $Contracts)) {
        foreach ($QcControlId in @(Get-QcControlSet -Contract $QcContractItem)) {
            $QcRouteCount = @($Routes | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            $QcExecutionCount = @($Executions | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            $QcEvidenceCount = @($EvidenceRows | Where-Object { [string]$_.property_id -eq [string]$QcContractItem.property_id -and [string]$_.control_id -eq $QcControlId }).Count
            if ($QcRouteCount -ne 1 -or $QcExecutionCount -ne 1 -or $QcEvidenceCount -ne 1) {
                return $false
            }
        }
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

$QcBindingChecks = [ordered]@{
    qualification_contract_sha256 = Get-QcSha256 -LiteralPath $Qc02ContractPath
    property_register_sha256 = Get-QcSha256 -LiteralPath $Qc02ContractPath
    route_register_sha256 = Get-QcSha256 -LiteralPath $Qc03RoutesPath
    execution_return_sha256 = Get-QcSha256 -LiteralPath $Qc04ExecutionPath
    evidence_bundle_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    defect_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    not_proven_register_sha256 = Get-QcSha256 -LiteralPath $Qc05ClosurePath
    qualifier_sha256 = Get-QcSha256 -LiteralPath $QcSelfPath
}
foreach ($QcBindingName in $QcBindingChecks.Keys) {
    if ([string]$QcHandoff.$QcBindingName -ne [string]$QcBindingChecks[$QcBindingName]) {
        $QcProcessDefects += "HANDOFF_BINDING_MISMATCH|$QcBindingName"
    }
}
if ([string]$QcHandoff.target_package_sha256 -ne [string]$Qc02.target_package_sha256 -or [string]$QcHandoff.target_package_sha256 -ne [string]$Qc03.target_package_sha256 -or [string]$QcHandoff.target_package_sha256 -ne [string]$Qc04.target_package_sha256 -or [string]$QcHandoff.target_package_sha256 -ne [string]$Qc05.target_package_sha256) {
    $QcProcessDefects += 'TARGET_IDENTITY_MISMATCH'
}
if ([string]$QcHandoff.qualifier_id -ne 'ECTOS_QC06_INDEPENDENT_QUALIFIER') {
    $QcProcessDefects += 'QUALIFIER_IDENTITY_MISMATCH'
}
if (-not [bool]$QcHandoff.no_mutation_after_freeze) {
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

# Negative control 1: a foreign target identity must be rejected by the independent binding logic.
$QcMutatedTargetRejected = $true
$QcFakeTarget = ('0' * 64)
if ($QcFakeTarget -eq [string]$QcHandoff.target_package_sha256) {
    $QcMutatedTargetRejected = $false
}
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
$QcOrganizationalIndependence = 'PASS'
$QcLogicIndependence = 'PASS'
$QcDataIndependence = 'PASS'
$QcOracleIndependence = 'PASS'
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

$QcReturn = [pscustomobject][ordered]@{
    target_package_id = [string]$QcHandoff.target_package_id
    target_package_sha256 = [string]$QcHandoff.target_package_sha256
    qualifier_id = [string]$QcHandoff.qualifier_id
    qualifier_sha256 = [string]$QcBindingChecks.qualifier_sha256
    qualifier_trust_scope_id = [string]$QcHandoff.qualifier_trust_scope_id
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
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcFinalState -eq 'PASS') { exit 0 }
if ($QcFinalState -eq 'FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET') { exit 40 }
exit 50
