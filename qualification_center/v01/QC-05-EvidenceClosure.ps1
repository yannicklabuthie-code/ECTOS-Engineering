[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qc02ContractPath,
    [Parameter(Mandatory = $true)][string]$Qc03RoutesPath,
    [Parameter(Mandatory = $true)][string]$Qc04ExecutionPath,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$Qc02 = Import-QcJson -LiteralPath $Qc02ContractPath
$Qc03 = Import-QcJson -LiteralPath $Qc03RoutesPath
$Qc04 = Import-QcJson -LiteralPath $Qc04ExecutionPath
if ([string]$Qc02.status -ne 'PASS' -or [string]$Qc03.status -ne 'PASS' -or [string]$Qc04.status -ne 'PASS') {
    throw 'QC05_UPSTREAM_STAGE_NOT_CLOSED'
}
if (-not (Test-Path -LiteralPath $EvidenceDirectory -PathType Container)) {
    [System.IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
}

$QcRoutes = @(ConvertTo-QcArray -Value $Qc03.routes)
$QcExecutions = @(ConvertTo-QcArray -Value $Qc04.execution_results)
$QcContracts = @(ConvertTo-QcArray -Value $Qc02.property_contracts)
$QcEvidenceRows = @()
$QcDefects = @()
$QcEscapes = @()
$QcUnmapped = @()
$QcUntested = @()
$QcUnevidenced = @()
$QcStageOrder = @{
    'QC-01' = 1
    'QC-02' = 2
    'QC-03' = 3
    'QC-04' = 4
    'QC-05' = 5
    'QC-06' = 6
}

foreach ($QcContract in $QcContracts) {
    $QcControls = @([string]$QcContract.positive_control_id)
    $QcControls += @(ConvertTo-QcArray -Value $QcContract.negative_control_ids | ForEach-Object { [string]$_ })
    foreach ($QcControlId in $QcControls) {
        $QcRouteMatches = @($QcRoutes | Where-Object { [string]$_.property_id -eq [string]$QcContract.property_id -and [string]$_.control_id -eq $QcControlId })
        if ($QcRouteMatches.Count -ne 1) {
            $QcUnmapped += "$([string]$QcContract.property_id)|$QcControlId|ROUTE_COUNT=$($QcRouteMatches.Count)"
            continue
        }
        $QcExecutionMatches = @($QcExecutions | Where-Object { [string]$_.property_id -eq [string]$QcContract.property_id -and [string]$_.control_id -eq $QcControlId })
        if ($QcExecutionMatches.Count -ne 1) {
            $QcUntested += "$([string]$QcContract.property_id)|$QcControlId|EXECUTION_COUNT=$($QcExecutionMatches.Count)"
            continue
        }
        $QcRoute = $QcRouteMatches[0]
        $QcExecution = $QcExecutionMatches[0]
        if (-not (Test-Path -LiteralPath ([string]$QcExecution.raw_stdout_ref) -PathType Leaf) -or -not (Test-Path -LiteralPath ([string]$QcExecution.raw_stderr_ref) -PathType Leaf)) {
            $QcUnevidenced += "$([string]$QcContract.property_id)|$QcControlId|RAW_EVIDENCE_MISSING"
            continue
        }
        $QcStdoutSha = Get-QcSha256 -LiteralPath ([string]$QcExecution.raw_stdout_ref)
        $QcStderrSha = Get-QcSha256 -LiteralPath ([string]$QcExecution.raw_stderr_ref)
        if ($QcStdoutSha -ne [string]$QcExecution.stdout_sha256 -or $QcStderrSha -ne [string]$QcExecution.stderr_sha256) {
            $QcUnevidenced += "$([string]$QcContract.property_id)|$QcControlId|RAW_EVIDENCE_SHA_MISMATCH"
            continue
        }
        $QcScriptSha = [string]$QcExecution.tool_sha256
        $QcScriptId = [string]$QcExecution.tool_id
        foreach ($QcArgument in @(ConvertTo-QcArray -Value $QcExecution.arguments)) {
            $QcArgumentText = [string]$QcArgument
            if ($QcArgumentText.ToLowerInvariant().EndsWith('.ps1') -and (Test-Path -LiteralPath $QcArgumentText -PathType Leaf)) {
                $QcScriptSha = Get-QcSha256 -LiteralPath $QcArgumentText
                $QcScriptId = [System.IO.Path]::GetFileName($QcArgumentText)
                break
            }
        }
        $QcEvidencePayload = [pscustomobject][ordered]@{
            property_id = [string]$QcContract.property_id
            control_id = $QcControlId
            execution_id = [string]$QcExecution.execution_id
            target_sha256 = [string]$Qc02.target_package_sha256
            tool_sha256 = [string]$QcExecution.tool_sha256
            script_sha256 = $QcScriptSha
            host_id = [string]$QcRoute.host_id
            runtime_id = [string]$QcRoute.runtime_profile
            run_id = [string]$QcExecution.run_id
            test_id = $QcControlId
            fixture_id = $null
            mutation_id = $null
            issuer_id = 'QC-05'
            authority_id = 'TECHNICAL_EVIDENCE_ONLY'
            start_time = [string]$QcExecution.start_time
            end_time = [string]$QcExecution.end_time
            exit_code = $QcExecution.exit_code
            expected_property = [string]$QcContract.expected_property
            observed_property = [string]$QcExecution.observed_property
            stdout_sha256 = $QcStdoutSha
            stderr_sha256 = $QcStderrSha
            oracle_id = [string]$QcContract.oracle_id
            oracle_result = [string]$QcExecution.preliminary_result
            currentness_state = 'CURRENT'
            cross_receipt_id = [string]$QcExecution.execution_id
            script_id = $QcScriptId
        }
        $QcEvidencePath = Join-Path $EvidenceDirectory (([string]$QcExecution.execution_id) + '.evidence.json')
        Export-QcJson -Value $QcEvidencePayload -LiteralPath $QcEvidencePath
        $QcRawEvidenceSha = Get-QcSha256 -LiteralPath $QcEvidencePath
        $QcEvidenceRows += [pscustomobject][ordered]@{
            property_id = [string]$QcContract.property_id
            control_id = $QcControlId
            execution_id = [string]$QcExecution.execution_id
            evidence_path = $QcEvidencePath
            raw_evidence_sha256 = $QcRawEvidenceSha
            oracle_result = [string]$QcExecution.preliminary_result
            target_sha256 = [string]$Qc02.target_package_sha256
            tool_sha256 = [string]$QcExecution.tool_sha256
            script_sha256 = $QcScriptSha
            run_id = [string]$QcExecution.run_id
        }
        if ([string]$QcExecution.preliminary_result -eq 'FAIL') {
            $QcDefectId = 'DEFECT-' + ([guid]::NewGuid().ToString('N').Substring(0, 12))
            $QcDefects += [pscustomobject][ordered]@{
                defect_id = $QcDefectId
                property_id = [string]$QcContract.property_id
                property_scope_class = [string]$QcContract.property_scope_class
                defect_family_id = 'CONTROL_FAILURE'
                description = "Control failed: $QcControlId"
                earliest_detectable_stage = [string]$QcContract.earliest_detectable_stage
                latest_permitted_stage = [string]$QcContract.latest_permitted_detection_stage
                actual_detection_stage = 'QC-04'
                product_defect = $true
                process_defect = $false
                severity = 'BLOCKER'
                status = 'OPEN'
                evidence_ids = @($QcRawEvidenceSha)
            }
            $QcEscapeOccurred = $false
            if ($QcStageOrder.ContainsKey([string]$QcContract.latest_permitted_detection_stage)) {
                if ($QcStageOrder['QC-04'] -gt $QcStageOrder[[string]$QcContract.latest_permitted_detection_stage]) {
                    $QcEscapeOccurred = $true
                }
            }
            if ($QcEscapeOccurred) {
                $QcEscapes += [pscustomobject][ordered]@{
                    defect_id = $QcDefectId
                    property_id = [string]$QcContract.property_id
                    property_scope_class = [string]$QcContract.property_scope_class
                    earliest_detectable_stage = [string]$QcContract.earliest_detectable_stage
                    latest_permitted_stage = [string]$QcContract.latest_permitted_detection_stage
                    actual_detection_stage = 'QC-04'
                    escape_occurred = $true
                    escaped_control_id = $QcControlId
                    escape_reason = 'DETECTED_AFTER_LATEST_PERMITTED_STAGE'
                    product_defect = $true
                    process_defect = $true
                    anti_recurrence_control_id = 'REQUIRED'
                    regression_fixture_id = 'REQUIRED'
                }
            }
        }
    }
}

$QcRequiredControlCount = 0
foreach ($QcContract in $QcContracts) {
    $QcRequiredControlCount += 1 + @(ConvertTo-QcArray -Value $QcContract.negative_control_ids).Count
}
$QcCoverageClosure = 'PASS'
if ($QcUnmapped.Count -gt 0 -or $QcUntested.Count -gt 0 -or $QcUnevidenced.Count -gt 0 -or $QcEvidenceRows.Count -ne $QcRequiredControlCount) {
    $QcCoverageClosure = 'FAIL'
}
$QcPreQfState = 'PASS'
if ($QcCoverageClosure -ne 'PASS') {
    $QcPreQfState = 'BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE'
}
elseif ($QcDefects.Count -gt 0) {
    $QcPreQfState = 'FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET'
}
$QcStatus = 'PASS'
if ($QcCoverageClosure -ne 'PASS') { $QcStatus = 'BLOCKED' }

$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC05_PRE_QF_CLOSURE_RETURN_V01'
    component_id = 'QC-05'
    status = $QcStatus
    target_package_id = [string]$Qc02.target_package_id
    target_package_sha256 = [string]$Qc02.target_package_sha256
    required_property_count = $QcContracts.Count
    required_control_count = $QcRequiredControlCount
    evidenced_control_count = $QcEvidenceRows.Count
    unmapped_property_count = $QcUnmapped.Count
    untested_control_count = $QcUntested.Count
    unevidenced_control_count = $QcUnevidenced.Count
    coverage_closure = $QcCoverageClosure
    pre_qf_state = $QcPreQfState
    causal_evidence_ledger = $QcEvidenceRows
    consolidated_defect_register = $QcDefects
    systemic_review_escape_register = $QcEscapes
    unmapped_register = $QcUnmapped
    untested_register = $QcUntested
    unevidenced_register = $QcUnevidenced
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
