[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$StageResultPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$QcStage = Import-QcJson -LiteralPath $StageResultPath
$QcComponentId = ''
if ($QcStage.PSObject.Properties['component_id']) {
    $QcComponentId = [string]$QcStage.component_id
}
elseif ($QcStage.PSObject.Properties['final_state']) {
    $QcComponentId = 'QC-06'
}
elseif ($QcStage.PSObject.Properties['schema_id']) {
    if ([string]$QcStage.schema_id -eq 'ECTOS_QH01_HANDOFF_V01') {
        $QcComponentId = 'QH-01'
    }
}
if ([string]::IsNullOrWhiteSpace($QcComponentId)) {
    throw 'QCC0_COMPONENT_ID_NOT_RESOLVED'
}

$QcDecision = 'DENY'
$QcNext = $null
$QcReason = 'STAGE_NOT_ELIGIBLE'
$QcStageStatus = 'NOT_PROVEN'
if ($QcStage.PSObject.Properties['status']) {
    $QcStageStatus = [string]$QcStage.status
}

switch ($QcComponentId) {
    'QC-01' {
        if ($QcStageStatus -eq 'PASS') { $QcDecision = 'ALLOW'; $QcNext = 'QC-02'; $QcReason = 'QC01_PASS' }
    }
    'QC-02' {
        if ($QcStageStatus -eq 'PASS') { $QcDecision = 'ALLOW'; $QcNext = 'QC-03'; $QcReason = 'QC02_PASS' }
    }
    'QC-03' {
        if ($QcStageStatus -eq 'PASS') { $QcDecision = 'ALLOW'; $QcNext = 'QC-04'; $QcReason = 'QC03_PASS' }
    }
    'QC-04' {
        if ($QcStageStatus -eq 'PASS') { $QcDecision = 'ALLOW'; $QcNext = 'QC-05'; $QcReason = 'QC04_ACCOUNTED' }
    }
    'QC-05' {
        if ([string]$QcStage.coverage_closure -eq 'PASS' -and [string]$QcStage.pre_qf_state -eq 'PASS' -and @(ConvertTo-QcArray -Value $QcStage.consolidated_defect_register).Count -eq 0 -and @(ConvertTo-QcArray -Value $QcStage.systemic_review_escape_register).Count -eq 0) { $QcDecision = 'ALLOW'; $QcNext = 'QC-CT'; $QcReason = 'QC05_NO_KNOWN_DEFECTS' }
    }
    'QH-01' {
        if ($QcStage.no_mutation_after_freeze -is [bool] -and $QcStage.no_mutation_after_freeze -eq $true) { $QcDecision = 'ALLOW'; $QcNext = 'QC-06'; $QcReason = 'QH01_FROZEN' }
    }
    'QC-CT' {
        if ($QcStageStatus -eq 'PASS_INTEGRITY_ONLY' -and [string]$QcStage.independent_qualification -eq 'NOT_EXECUTED' -and [string]$QcStage.admission -eq 'NOT_GRANTED') { $QcDecision = 'ALLOW'; $QcNext = 'QH-01'; $QcReason = 'CONTRACT_INTEGRITY_GATE_ONLY_NOT_ADMISSION' }
    }
    'QC-06' {
        $QcDecision = 'TERMINAL'
        $QcNext = $null
        $QcReason = 'VERDICT_TERMINAL_NOT_ADMISSION'
        $QcStageStatus = [string]$QcStage.final_state
    }
    default {
        $QcDecision = 'DENY'
        $QcReason = 'UNKNOWN_COMPONENT'
    }
}

# This controller only checks structural routing eligibility; it grants no execution authority.
$QcStructuralDefects = @()
if ($QcComponentId -in @('QC-01','QC-02','QC-03','QC-04','QC-05','QH-01','QC-06')) {
    if (-not $QcStage.PSObject.Properties['target_package_id'] -or [string]::IsNullOrWhiteSpace([string]$QcStage.target_package_id)) { $QcStructuralDefects += 'TARGET_ID_MISSING' }
    if (-not $QcStage.PSObject.Properties['target_package_sha256'] -or [string]$QcStage.target_package_sha256 -notmatch '^[a-fA-F0-9]{64}$') { $QcStructuralDefects += 'TARGET_SHA256_MISSING_OR_INVALID' }
}
$QcRequiredCollection = @{ 'QC-01'='member_inventory'; 'QC-02'='property_contracts'; 'QC-03'='routes'; 'QC-04'='execution_results'; 'QC-05'='causal_evidence_ledger' }
if ($QcRequiredCollection.ContainsKey($QcComponentId)) {
    $field = $QcRequiredCollection[$QcComponentId]
    if (-not $QcStage.PSObject.Properties[$field] -or @(ConvertTo-QcArray -Value $QcStage.$field).Count -eq 0) { $QcStructuralDefects += ('REQUIRED_NONEMPTY_COLLECTION_MISSING|' + $field) }
}
if ($QcStructuralDefects.Count -gt 0) { $QcDecision='DENY'; $QcNext=$null; $QcReason='STRUCTURAL_CONTEXT_INVALID' }

$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QCC0_TRANSITION_DECISION_V01'
    component_id = 'QC-C0'
    source_component_id = $QcComponentId
    source_status = $QcStageStatus
    transition_decision = $QcDecision
    next_component_id = $QcNext
    reason = $QcReason
    decision_scope = 'STRUCTURAL_ROUTING_ONLY_NOT_EXECUTION_AUTHORIZATION'
    trusted_history = 'NOT_PROVEN'
    execution_authority = 'NONE'
    structural_defects = $QcStructuralDefects
    admission_authority = 'NONE'
    release_authority = 'NONE'
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcDecision -eq 'ALLOW' -or $QcDecision -eq 'TERMINAL') { exit 0 }
exit 40
