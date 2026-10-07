[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$WorkRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcRoot = Split-Path -Parent $PSScriptRoot
$QcModulePath = Join-Path $QcRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$QcPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $QcPowerShellPath -PathType Leaf)) {
    throw 'SELFTEST_PS51_HOST_NOT_FOUND'
}
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not $PSVersionTable.PSVersion.ToString().StartsWith('5.1')) {
    throw 'SELFTEST_MUST_RUN_UNDER_WINDOWS_POWERSHELL_5_1'
}
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
    $WorkRoot = Join-Path 'C:\dev\ECTOS_QC_V01_SELFTEST' ([guid]::NewGuid().ToString('N'))
}
[System.IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
$QcEvidenceRoot = Join-Path $WorkRoot 'evidence'
[System.IO.Directory]::CreateDirectory($QcEvidenceRoot) | Out-Null
$QcSampleTarget = Join-Path $QcRoot 'fixtures\sample-target'
$QcSampleScript = Join-Path $QcSampleTarget 'sample-check.ps1'

function Invoke-QcExternal {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $false)][string[]]$ScriptArguments,
        [Parameter(Mandatory = $true)][int]$ExpectedExitCode
    )
    $QcInvocationArguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$ScriptPath)
    if ($null -ne $ScriptArguments) {
        $QcInvocationArguments += @($ScriptArguments)
    }
    & $QcPowerShellPath $QcInvocationArguments
    $QcActualExitCode = $LASTEXITCODE
    if ($QcActualExitCode -ne $ExpectedExitCode) {
        throw "SELFTEST_STAGE_EXIT_MISMATCH|$ScriptPath|EXPECTED=$ExpectedExitCode|ACTUAL=$QcActualExitCode"
    }
}

function Assert-QcController {
    param(
        [Parameter(Mandatory = $true)][string]$StageResultPath,
        [Parameter(Mandatory = $false)][AllowNull()][string]$ExpectedNext,
        [Parameter(Mandatory = $true)][string]$ExpectedDecision,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $QcControllerOutput = Join-Path $WorkRoot ($Label + '-controller.json')
    $QcControllerScript = Join-Path $QcRoot 'QC-C0-PipelineController.ps1'
    Invoke-QcExternal -ScriptPath $QcControllerScript -ScriptArguments @('-StageResultPath',$StageResultPath,'-OutputPath',$QcControllerOutput) -ExpectedExitCode 0
    $QcDecision = Import-QcJson -LiteralPath $QcControllerOutput
    if ([string]$QcDecision.transition_decision -ne $ExpectedDecision) {
        throw "SELFTEST_CONTROLLER_DECISION_MISMATCH|$Label"
    }
    $QcActualNext = $null
    if ($QcDecision.PSObject.Properties['next_component_id']) {
        $QcActualNext = $QcDecision.next_component_id
    }
    $QcExpectedNextNormalized = ''
    if ($null -ne $ExpectedNext) { $QcExpectedNextNormalized = [string]$ExpectedNext }
    $QcActualNextNormalized = ''
    if ($null -ne $QcActualNext) { $QcActualNextNormalized = [string]$QcActualNext }
    if ($QcExpectedNextNormalized -ne $QcActualNextNormalized) {
        throw "SELFTEST_CONTROLLER_NEXT_MISMATCH|$Label|EXPECTED=$QcExpectedNextNormalized|ACTUAL=$QcActualNextNormalized"
    }
}

# Collection cardinality regression controls for PS51-R007/R008 boundaries.
if (@(ConvertTo-QcArray -Value $null).Count -ne 0) { throw 'SELFTEST_ARRAY_NULL_FAILED' }
if (@(ConvertTo-QcArray -Value 'one').Count -ne 1) { throw 'SELFTEST_ARRAY_SINGLE_FAILED' }
if (@(ConvertTo-QcArray -Value @('one','two')).Count -ne 2) { throw 'SELFTEST_ARRAY_MANY_FAILED' }

$QcBasisPath = Join-Path $WorkRoot 'basis.json'
Export-QcJson -Value ([pscustomobject][ordered]@{
    expected_members = @('sample-check.ps1')
    required_domains = @('PACKAGE_MEMBER_DOMAIN','ENTRYPOINT_DOMAIN','RUNTIME_DOMAIN')
}) -LiteralPath $QcBasisPath

$QcRequirementPath = Join-Path $WorkRoot 'requirements.json'
$QcRequirement = [pscustomobject][ordered]@{
    property_id = 'PROP-SYS-001'
    property_family = 'P21'
    property_scope_class = 'SYSTEM'
    requirement_id = 'REQ-SYS-001'
    owner_objective_id = 'OBJ-QC-SELFTEST'
    invariant_ids = @('INV-NEGATIVE-REJECTION')
    target_member_ids = @('sample-check.ps1')
    target_interface_ids = @('PS51_ENTRYPOINT')
    earliest_detectable_stage = 'QC-02'
    latest_permitted_detection_stage = 'QC-04'
    positive_control_id = 'CTRL-POSITIVE'
    negative_control_ids = @('CTRL-NEGATIVE')
    expected_property = 'Positive path succeeds and explicit negative input is rejected.'
    oracle_id = 'ORACLE-EXIT-STDOUT-V01'
    oracle_type = 'PROCESS_CONTRACT'
    required_evidence_fields = @('exit_code','stdout_sha256','stderr_sha256','tool_sha256','target_sha256')
    qualification_profile = 'QP03_NATIVE_RUNTIME'
    fail_effect = 'FAIL_PRODUCT'
    block_effect = 'BLOCK_HANDOFF'
    downstream_admission_effect = 'DENY'
}
Export-QcJson -Value ([pscustomobject][ordered]@{ requirements = @($QcRequirement) }) -LiteralPath $QcRequirementPath

$QcToolSha = Get-QcSha256 -LiteralPath $QcPowerShellPath
$QcToolBase = [ordered]@{
    tool_version = $PSVersionTable.PSVersion.ToString()
    tool_sha256 = $QcToolSha
    tool_trust_state = 'TRUSTED'
    tool_currentness_state = 'CURRENT'
    platform_profile = 'WINDOWS'
    runtime_profile = 'WINDOWS_POWERSHELL_DESKTOP_5_1'
    host_id = 'SELFTEST_NATIVE_WINDOWS_PS51'
    host_trust_state = 'TRUSTED'
    tool_target_fit = 'PASS'
    expected_evidence_schema_id = 'ECTOS_QC_EXECUTION_RESULT_V01'
    execution_authority_required = 'SELFTEST_ONLY'
    command_path = $QcPowerShellPath
    fixed_arguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass')
}
$QcToolPositive = [pscustomobject][ordered]@{}
foreach ($QcKey in $QcToolBase.Keys) { $QcToolPositive | Add-Member -NotePropertyName $QcKey -NotePropertyValue $QcToolBase[$QcKey] }
$QcToolPositive | Add-Member -NotePropertyName control_id -NotePropertyValue 'CTRL-POSITIVE'
$QcToolPositive | Add-Member -NotePropertyName tool_id -NotePropertyValue 'PS51-SELFTEST-POSITIVE'
$QcToolNegative = [pscustomobject][ordered]@{}
foreach ($QcKey in $QcToolBase.Keys) { $QcToolNegative | Add-Member -NotePropertyName $QcKey -NotePropertyValue $QcToolBase[$QcKey] }
$QcToolNegative | Add-Member -NotePropertyName control_id -NotePropertyValue 'CTRL-NEGATIVE'
$QcToolNegative | Add-Member -NotePropertyName tool_id -NotePropertyValue 'PS51-SELFTEST-NEGATIVE'
$QcToolRegistryPath = Join-Path $WorkRoot 'tool-registry.json'
Export-QcJson -Value ([pscustomobject][ordered]@{ tools = @($QcToolPositive,$QcToolNegative) }) -LiteralPath $QcToolRegistryPath

$QcExecutionPlanPath = Join-Path $WorkRoot 'execution-plan.json'
$QcExecutionPlan = [pscustomobject][ordered]@{
    executions = @(
        [pscustomobject][ordered]@{
            property_id = 'PROP-SYS-001'; control_id = 'CTRL-POSITIVE'
            arguments = @('-File',$QcSampleScript,'-Mode','Positive')
            working_directory = $QcSampleTarget; timeout_seconds = 15
            expected_exit = @(0); expected_stdout_contains = 'PROPERTY_OK'; expected_stderr_contains = ''
            observed_property_label = 'POSITIVE_PATH_OK'
        },
        [pscustomobject][ordered]@{
            property_id = 'PROP-SYS-001'; control_id = 'CTRL-NEGATIVE'
            arguments = @('-File',$QcSampleScript,'-Mode','Negative')
            working_directory = $QcSampleTarget; timeout_seconds = 15
            expected_exit = @(10); expected_stdout_contains = 'NEGATIVE_REJECTED'; expected_stderr_contains = ''
            observed_property_label = 'NEGATIVE_PATH_REJECTED'
        }
    )
}
Export-QcJson -Value $QcExecutionPlan -LiteralPath $QcExecutionPlanPath

$Qc01Out = Join-Path $WorkRoot 'qc01.json'
$Qc02Out = Join-Path $WorkRoot 'qc02.json'
$Qc03Out = Join-Path $WorkRoot 'qc03.json'
$Qc04Out = Join-Path $WorkRoot 'qc04.json'
$Qc05Out = Join-Path $WorkRoot 'qc05.json'
$QcHandoffOut = Join-Path $WorkRoot 'qh01.json'
$Qc06Out = Join-Path $WorkRoot 'qc06.json'

Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-01-PackageDepthDiscovery.ps1') -ScriptArguments @('-TargetPath',$QcSampleTarget,'-CompletenessBasisPath',$QcBasisPath,'-OutputPath',$Qc01Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc01Out -ExpectedNext 'QC-02' -ExpectedDecision 'ALLOW' -Label 'qc01'

Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-02-QualificationContractCompiler.ps1') -ScriptArguments @('-Qc01ReturnPath',$Qc01Out,'-RequirementRegisterPath',$QcRequirementPath,'-OutputPath',$Qc02Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc02Out -ExpectedNext 'QC-03' -ExpectedDecision 'ALLOW' -Label 'qc02'

Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-03-ToolFitRouting.ps1') -ScriptArguments @('-Qc02ContractPath',$Qc02Out,'-ToolRegistryPath',$QcToolRegistryPath,'-OutputPath',$Qc03Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc03Out -ExpectedNext 'QC-04' -ExpectedDecision 'ALLOW' -Label 'qc03'

Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-04-PreQfExecution.ps1') -ScriptArguments @('-Qc03RoutesPath',$Qc03Out,'-ExecutionPlanPath',$QcExecutionPlanPath,'-EvidenceDirectory',(Join-Path $QcEvidenceRoot 'raw'),'-OutputPath',$Qc04Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc04Out -ExpectedNext 'QC-05' -ExpectedDecision 'ALLOW' -Label 'qc04'

Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-05-EvidenceClosure.ps1') -ScriptArguments @('-Qc02ContractPath',$Qc02Out,'-Qc03RoutesPath',$Qc03Out,'-Qc04ExecutionPath',$Qc04Out,'-EvidenceDirectory',(Join-Path $QcEvidenceRoot 'causal'),'-OutputPath',$Qc05Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc05Out -ExpectedNext 'QH-01' -ExpectedDecision 'ALLOW' -Label 'qc05'

$QcQualifierScript = Join-Path $QcRoot 'QC-06-IndependentQualifier.ps1'
Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QH-01-FreezeHandoff.ps1') -ScriptArguments @('-Qc02ContractPath',$Qc02Out,'-Qc03RoutesPath',$Qc03Out,'-Qc04ExecutionPath',$Qc04Out,'-Qc05ClosurePath',$Qc05Out,'-QualifierScriptPath',$QcQualifierScript,'-OutputPath',$QcHandoffOut) -ExpectedExitCode 0
Assert-QcController -StageResultPath $QcHandoffOut -ExpectedNext 'QC-06' -ExpectedDecision 'ALLOW' -Label 'qh01'

Invoke-QcExternal -ScriptPath $QcQualifierScript -ScriptArguments @('-Qh01HandoffPath',$QcHandoffOut,'-Qc02ContractPath',$Qc02Out,'-Qc03RoutesPath',$Qc03Out,'-Qc04ExecutionPath',$Qc04Out,'-Qc05ClosurePath',$Qc05Out,'-OutputPath',$Qc06Out) -ExpectedExitCode 0
Assert-QcController -StageResultPath $Qc06Out -ExpectedNext $null -ExpectedDecision 'TERMINAL' -Label 'qc06'

$QcFinal = Import-QcJson -LiteralPath $Qc06Out
if ([string]$QcFinal.final_state -ne 'PASS') { throw 'SELFTEST_FINAL_STATE_NOT_PASS' }
if ([string]$QcFinal.objective_match -ne 'PASS' -or [string]$QcFinal.architectural_intent_match -ne 'PASS' -or [string]$QcFinal.invariant_match -ne 'PASS') {
    throw 'SELFTEST_OBJECTIVE_OR_INTENT_NOT_PASS'
}
if ([string]$QcFinal.prohibited_behavior_absence -ne 'PASS' -or [string]$QcFinal.constraint_relocation -ne 'NO' -or [string]$QcFinal.architectural_substitution -ne 'NO') {
    throw 'SELFTEST_NEGATIVE_OR_ARCHITECTURE_GATES_NOT_PASS'
}

# Controller negative control: a failed stage may not advance.
$QcControllerNegativeInput = Join-Path $WorkRoot 'controller-negative.json'
$QcControllerNegativeOutput = Join-Path $WorkRoot 'controller-negative-out.json'
Export-QcJson -Value ([pscustomobject][ordered]@{ schema_id='TEST'; component_id='QC-02'; status='FAIL' }) -LiteralPath $QcControllerNegativeInput
Invoke-QcExternal -ScriptPath (Join-Path $QcRoot 'QC-C0-PipelineController.ps1') -ScriptArguments @('-StageResultPath',$QcControllerNegativeInput,'-OutputPath',$QcControllerNegativeOutput) -ExpectedExitCode 40
$QcNegativeDecision = Import-QcJson -LiteralPath $QcControllerNegativeOutput
if ([string]$QcNegativeDecision.transition_decision -ne 'DENY') { throw 'SELFTEST_CONTROLLER_NEGATIVE_FAILED' }

$QcSummaryPath = Join-Path $WorkRoot 'SELFTEST_RETURN.json'
$QcSummary = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC_V01_SELFTEST_RETURN'
    final_state = 'PASS'
    host_psedition = $PSVersionTable.PSEdition
    host_psversion = $PSVersionTable.PSVersion.ToString()
    target_sha256 = [string]$QcFinal.target_package_sha256
    qc06_sha256 = Get-QcSha256 -LiteralPath $QcQualifierScript
    cardinality_controls = 'PASS'
    controller_positive_transitions = 6
    controller_negative_controls = 1
    qc06_independent_challenges = 2
    output_root = $WorkRoot
}
Export-QcJson -Value $QcSummary -LiteralPath $QcSummaryPath
Write-Output ('SELFTEST_RETURN=' + $QcSummaryPath)
Write-Output 'ECTOS_QC_V01_SELFTEST=PASS'
exit 0
