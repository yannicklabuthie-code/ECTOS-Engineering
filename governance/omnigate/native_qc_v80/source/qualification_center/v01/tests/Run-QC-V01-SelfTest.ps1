[CmdletBinding()]
param([Parameter(Mandatory=$false)][string]$WorkRoot)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $QcRoot 'QC.Common.psm1') -Force
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not $PSVersionTable.PSVersion.ToString().StartsWith('5.1')) { throw 'SELFTEST_MUST_RUN_UNDER_WINDOWS_POWERSHELL_5_1' }
$QcPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $QcPowerShellPath -PathType Leaf)) { throw 'SELFTEST_PS51_HOST_NOT_FOUND' }
if ([string]::IsNullOrWhiteSpace($WorkRoot)) { $WorkRoot = Join-Path 'C:\dev\ECTOS_QC_PRODUCER_BOUNDARY_SELFTEST' ([guid]::NewGuid().ToString('N')) }
[System.IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
$QcStarted = [DateTime]::UtcNow.ToString('o')
$QcRuns = @()
function Invoke-QcBoundaryChild {
    param([string]$ScriptPath,[string[]]$ScriptArguments,[int]$ExpectedExitCode,[string]$Label)
    $QcArguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$ScriptPath) + @($ScriptArguments)
    $QcBegin = [DateTime]::UtcNow.ToString('o')
    $QcStderrPath = Join-Path $WorkRoot ($Label + '.stderr.txt')
    $QcStdout = @(& $QcPowerShellPath $QcArguments 2> $QcStderrPath)
    $QcExit = $LASTEXITCODE
    $QcStdoutPath = Join-Path $WorkRoot ($Label + '.stdout.txt')
    [System.IO.File]::WriteAllText($QcStdoutPath,($QcStdout -join "`n"),(New-Object System.Text.UTF8Encoding($false)))
    if ($QcExit -ne $ExpectedExitCode) { throw "SELFTEST_STAGE_EXIT_MISMATCH|$Label|EXPECTED=$ExpectedExitCode|ACTUAL=$QcExit" }
    return [pscustomobject][ordered]@{ label=$Label; executable=$QcPowerShellPath; arguments=$QcArguments; working_directory=(Get-Location).Path; started_at=$QcBegin; completed_at=[DateTime]::UtcNow.ToString('o'); exit_code=$QcExit; stdout=($QcStdout -join "`n"); stdout_path=$QcStdoutPath; stderr_path=$QcStderrPath; stdout_sha256=(Get-QcSha256 -LiteralPath $QcStdoutPath); stderr_sha256=(Get-QcSha256 -LiteralPath $QcStderrPath); scope='SAMPLE_PRODUCER_BOUNDARY_ONLY' }
}
if (@(ConvertTo-QcArray -Value $null).Count -ne 0) { throw 'SELFTEST_ARRAY_NULL_FAILED' }
if (@(ConvertTo-QcArray -Value @()).Count -ne 0) { throw 'SELFTEST_ARRAY_EMPTY_FAILED' }
if (@(ConvertTo-QcArray -Value 'one').Count -ne 1) { throw 'SELFTEST_ARRAY_SINGLE_FAILED' }
if (@(ConvertTo-QcArray -Value @('one','two')).Count -ne 2) { throw 'SELFTEST_ARRAY_MANY_FAILED' }
$QcSampleTarget = Join-Path $QcRoot 'fixtures\sample-target'
$QcSampleScript = Join-Path $QcSampleTarget 'sample-check.ps1'
$QcPositive = Invoke-QcBoundaryChild -ScriptPath $QcSampleScript -ScriptArguments @('-Mode','Positive') -ExpectedExitCode 0 -Label 'sample-positive'
if ($QcPositive.stdout -notmatch 'PROPERTY_OK') { throw 'SELFTEST_POSITIVE_OUTPUT_MISSING' }
$QcRuns += $QcPositive
$QcNegative = Invoke-QcBoundaryChild -ScriptPath $QcSampleScript -ScriptArguments @('-Mode','Negative') -ExpectedExitCode 10 -Label 'sample-negative'
if ($QcNegative.stdout -notmatch 'NEGATIVE_REJECTED') { throw 'SELFTEST_NEGATIVE_OUTPUT_MISSING' }
$QcRuns += $QcNegative
$QcBasisPath = Join-Path $WorkRoot 'basis.json'
Export-QcJson -Value ([pscustomobject][ordered]@{ expected_members=@('sample-check.ps1'); required_domains=@('PACKAGE_MEMBER_DOMAIN','ENTRYPOINT_DOMAIN','RUNTIME_DOMAIN'); expected_member_ledger=@([pscustomobject]@{path='sample-check.ps1';size_bytes=(Get-Item -LiteralPath $QcSampleScript).Length;sha256=(Get-QcSha256 -LiteralPath $QcSampleScript)}) }) -LiteralPath $QcBasisPath
$Qc01Out = Join-Path $WorkRoot 'qc01.json'
$QcRuns += Invoke-QcBoundaryChild -ScriptPath (Join-Path $QcRoot 'QC-01-PackageDepthDiscovery.ps1') -ScriptArguments @('-TargetPath',$QcSampleTarget,'-CompletenessBasisPath',$QcBasisPath,'-OutputPath',$Qc01Out) -ExpectedExitCode 0 -Label 'qc01-byte-pinned'
$Qc01 = Import-QcJson -LiteralPath $Qc01Out
if ([string]$Qc01.status -ne 'PASS' -or $Qc01.byte_identity_proven -ne $true) { throw 'SELFTEST_QC01_BYTE_IDENTITY_NOT_PROVEN' }
# This deliberately unapproved requirement record challenges the production authority boundary.
$QcRequirement = [pscustomobject][ordered]@{
    property_id='PROP-SYS-001'; property_family='P21'; property_scope_class='SYSTEM'; requirement_id='REQ-SYS-001'; owner_objective_id='OBJ-QC-SELFTEST'
    invariant_ids=@('INV-NEGATIVE-REJECTION'); target_member_ids=@('sample-check.ps1'); target_interface_ids=@('PS51_ENTRYPOINT')
    earliest_detectable_stage='QC-02'; latest_permitted_detection_stage='QC-04'; positive_control_id='CTRL-POSITIVE'; negative_control_ids=@('CTRL-NEGATIVE')
    expected_property='Sample positive and negative primitive behavior'; oracle_id='ORACLE-EXIT-STDOUT-V01'; oracle_type='PROCESS_CONTRACT'
    required_evidence_fields=@('exit_code','stdout_sha256','stderr_sha256','tool_sha256','target_sha256'); qualification_profile='QP03_NATIVE_RUNTIME'
    platform_profile='WINDOWS'; runtime_profile='WINDOWS_POWERSHELL_DESKTOP_5_1'; fail_effect='FAIL_PRODUCT'; block_effect='BLOCK_HANDOFF'; downstream_admission_effect='DENY'
    oracle_specifications=@([pscustomobject]@{control_id='CTRL-POSITIVE';oracle_id='ORACLE-EXIT-STDOUT-V01';expected_exit=@(0);expected_stdout_contains='PROPERTY_OK';expected_stderr_contains=''},[pscustomobject]@{control_id='CTRL-NEGATIVE';oracle_id='ORACLE-EXIT-STDOUT-V01';expected_exit=@(10);expected_stdout_contains='NEGATIVE_REJECTED';expected_stderr_contains=''})
}
$QcRequirementsPath = Join-Path $WorkRoot 'unapproved-requirements.json'
Export-QcJson -Value ([pscustomobject][ordered]@{ contract_state='UNAPPROVED_TEST_FIXTURE'; currentness_state='NOT_PROVEN'; target_package_id=$Qc01.target_package_id; target_package_sha256=$Qc01.target_package_sha256; mandatory_property_ids=@('PROP-SYS-001'); requirements=@($QcRequirement) }) -LiteralPath $QcRequirementsPath
$Qc02Out = Join-Path $WorkRoot 'qc02.json'
$QcRuns += Invoke-QcBoundaryChild -ScriptPath (Join-Path $QcRoot 'QC-02-QualificationContractCompiler.ps1') -ScriptArguments @('-Qc01ReturnPath',$Qc01Out,'-RequirementRegisterPath',$QcRequirementsPath,'-OutputPath',$Qc02Out) -ExpectedExitCode 40 -Label 'qc02-unapproved-contract-denied'
$Qc02 = Import-QcJson -LiteralPath $Qc02Out
if ([string]$Qc02.status -ne 'BLOCKED' -or @($Qc02.compiler_defects) -notcontains 'EXTERNAL_CONTRACT_AUTHORITY_ROOT_NOT_PROVEN') { throw 'SELFTEST_UNAPPROVED_CONTRACT_BOUNDARY_FAILED' }
$QcControllerOut = Join-Path $WorkRoot 'controller-denied.json'
$QcRuns += Invoke-QcBoundaryChild -ScriptPath (Join-Path $QcRoot 'QC-C0-PipelineController.ps1') -ScriptArguments @('-StageResultPath',$Qc02Out,'-OutputPath',$QcControllerOut) -ExpectedExitCode 40 -Label 'controller-denies-blocked-contract'
$QcDecision = Import-QcJson -LiteralPath $QcControllerOut
if ([string]$QcDecision.transition_decision -ne 'DENY' -or [string]$QcDecision.execution_authority -ne 'NONE') { throw 'SELFTEST_CONTROLLER_BOUNDARY_FAILED' }
$QcSummaryPath = Join-Path $WorkRoot 'SELFTEST_RETURN.json'
Export-QcJson -Value ([pscustomobject][ordered]@{schema_id='ECTOS_QC_V02_PRODUCER_BOUNDARY_SELFTEST_RETURN';scope='SAMPLE_FIXTURE_PRODUCER_BOUNDARY_REGRESSION_ONLY_NOT_EXACT_SUCCESSOR_QUALIFICATION';final_state='PRODUCER_SELFTEST_PASS_FAIL_CLOSED';qualification_state='NOT_PROVEN';admission_state='NOT_GRANTED';host_psedition=$PSVersionTable.PSEdition;host_psversion=$PSVersionTable.PSVersion.ToString();started_at=$QcStarted;completed_at=[DateTime]::UtcNow.ToString('o');cardinality_controls='PASS_NULL_EMPTY_SINGLE_MANY';sample_positive='PASS';sample_negative='PASS';qc01_byte_identity='PASS';unapproved_qc02_contract='BLOCKED_AS_EXPECTED';controller='DENY_AS_EXPECTED';independent_challenges=0;executions=$QcRuns;output_root=$WorkRoot}) -LiteralPath $QcSummaryPath
Write-Output ('SELFTEST_RETURN=' + $QcSummaryPath)
Write-Output 'ECTOS_QC_V02_PRODUCER_FAIL_CLOSED_SELFTEST=PASS'
exit 0
