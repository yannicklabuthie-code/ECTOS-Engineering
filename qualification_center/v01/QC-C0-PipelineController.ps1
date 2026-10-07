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
        if ([string]$QcStage.coverage_closure -eq 'PASS') { $QcDecision = 'ALLOW'; $QcNext = 'QH-01'; $QcReason = 'QC05_COVERAGE_CLOSED' }
    }
    'QH-01' {
        if ([bool]$QcStage.no_mutation_after_freeze) { $QcDecision = 'ALLOW'; $QcNext = 'QC-06'; $QcReason = 'QH01_FROZEN' }
    }
    'QC-06' {
        $QcDecision = 'TERMINAL'
        $QcNext = $null
        $QcReason = 'INDEPENDENT_VERDICT_AVAILABLE'
        $QcStageStatus = [string]$QcStage.final_state
    }
    default {
        $QcDecision = 'DENY'
        $QcReason = 'UNKNOWN_COMPONENT'
    }
}

$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QCC0_TRANSITION_DECISION_V01'
    component_id = 'QC-C0'
    source_component_id = $QcComponentId
    source_status = $QcStageStatus
    transition_decision = $QcDecision
    next_component_id = $QcNext
    reason = $QcReason
    admission_authority = 'NONE'
    release_authority = 'NONE'
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcDecision -eq 'ALLOW' -or $QcDecision -eq 'TERMINAL') { exit 0 }
exit 40
