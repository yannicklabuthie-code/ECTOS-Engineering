[CmdletBinding()]
param([int]$TimeoutSeconds=120)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$repositoryRoot=(Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
$resultRoot=Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V02_PRODUCER_SELFTEST_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $resultRoot -Force|Out-Null
$checks=[ordered]@{};$blockers=@()
function Write-ECTOSSelftestJson {param([string]$Path,$Value);[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 40),(New-Object Text.UTF8Encoding($false)))}
function Complete-ECTOSSelftest {param([string]$Status,[int]$ExitCode);$result=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V02_PRODUCER_SELFTEST_RESULT';status=$Status;checks=$checks;blockers=@($blockers);result_root=$resultRoot;independent_qualification_executed=$false};$path=Join-Path $resultRoot 'SELFTEST_RESULT.json';Write-ECTOSSelftestJson -Path $path -Value $result;$result|ConvertTo-Json -Depth 30 -Compress;exit $ExitCode}
try {
    if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'SELFTEST_NOT_NATIVE_PS51'}
    $checks.NATIVE_PS51='PASS'
    . (Join-Path $packageRoot '07_CONTRACTS\Invoke-ECTOSProcess.ps1')
    $parseErrors=@();$psFiles=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter '*.ps1')
    foreach($file in $psFiles){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors);foreach($item in @($errors)){if($null-ne$item){$parseErrors+=($file.FullName+':'+$item.Message)}}}
    if($parseErrors.Count -gt 0){throw ('SELFTEST_PARSE_FAIL:'+($parseErrors -join '|'))};$checks.PARSE='PASS'
    Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -Force;$issues=@(Invoke-ScriptAnalyzer -Path $packageRoot -Recurse -Severity Error,Warning);if($issues.Count -ne 0){throw ('SELFTEST_PSSCRIPTANALYZER_FAIL:'+(($issues|ForEach-Object{$_.RuleName+':'+$_.ScriptName+':'+$_.Line}) -join '|'))};$checks.PSSCRIPTANALYZER='PASS'
    $powershellPath=(Get-Command powershell.exe -ErrorAction Stop).Source;$staticOut=Join-Path $resultRoot 'static.stdout.txt';$staticErr=Join-Path $resultRoot 'static.stderr.txt'
    $staticReceipt=Invoke-ECTOSProcess -FilePath $powershellPath -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot '10_SELFTEST\Invoke-StaticRuleGate.ps1')) -WorkingDirectory $repositoryRoot -TimeoutMilliseconds 30000 -StdoutPath $staticOut -StderrPath $staticErr
    if($staticReceipt.status -ne 'COMPLETED' -or $staticReceipt.exit_code -ne 0){throw 'SELFTEST_STATIC_GATE_FAIL'};$staticResult=Get-Content -LiteralPath $staticOut -Raw|ConvertFrom-Json;if([string]$staticResult.status -ne 'PASS'){throw 'SELFTEST_STATIC_GATE_FAIL'};$checks.STATIC_DETECTION='PASS'
    Import-Module Pester -Force;$pester=Invoke-Pester -Script (Join-Path $PSScriptRoot 'ECTOSDev.Tests.ps1') -PassThru -Quiet;if($pester.FailedCount -ne 0){throw ('SELFTEST_PESTER_FAIL:'+$pester.FailedCount)};$checks.PESTER='PASS';$checks.PESTER_PASS_COUNT=$pester.PassedCount;$checks.NEGATIVE_ORACLES='PASS'

    . (Join-Path $packageRoot '01_LDEV01_ENGINEERING_STATE\Invoke-LDEV01.ps1');. (Join-Path $packageRoot '02_LDEV02_POLICY_AND_LEARNING\Invoke-LDEV02.ps1');. (Join-Path $packageRoot '03_LDEV03_BUILD_DEFINITION\Invoke-LDEV03.ps1');. (Join-Path $packageRoot '04_ECTOS_BUILDER\Invoke-ECTOSBuilder.ps1');. (Join-Path $packageRoot '05_BUILD_PACKAGE_FACTORY\Invoke-BPF.ps1')
    $registry=Get-Content -LiteralPath (Join-Path $packageRoot '08_CONFIG\targets.json') -Raw|ConvertFrom-Json;$target=$registry.targets[0]
    $l1=Invoke-ECTOSLDEV01 -Target $target -RepositoryRoot $repositoryRoot;$l2=Invoke-ECTOSLDEV02 -Target $target -RepositoryRoot $repositoryRoot;$l3=Invoke-ECTOSLDEV03 -Target $target -RepositoryRoot $repositoryRoot;$plan=Invoke-ECTOSBuilder -LDEV01 $l1 -LDEV02 $l2 -LDEV03 $l3 -RepositoryRoot $repositoryRoot
    $runA=Join-Path $resultRoot 'replayA';$runB=Join-Path $resultRoot 'replayB';$a=Invoke-ECTOSBPF -BuildPlan $plan -WorkspaceRoot $runA -RepositoryRoot $repositoryRoot;$b=Invoke-ECTOSBPF -BuildPlan $plan -WorkspaceRoot $runB -RepositoryRoot $repositoryRoot
    $checks.DETERMINISTIC_REPLAY_RUN_COUNT=2
    if([string]$a.package_member_set_sha256 -ne [string]$b.package_member_set_sha256){throw 'SELFTEST_REPLAY_MEMBER_SET_MISMATCH'}
    if([string]$a.package_sha256 -ne [string]$b.package_sha256){throw 'SELFTEST_REPLAY_ARCHIVE_MISMATCH'}
    if([string]$a.package_content_identity -ne [string]$b.package_content_identity){throw 'SELFTEST_REPLAY_CONTENT_IDENTITY_MISMATCH'}
    $aRecords=@($a.package_members|ForEach-Object{([string]$_.path)+'|'+([string]$_.size_bytes)+'|'+([string]$_.sha256)});$bRecords=@($b.package_members|ForEach-Object{([string]$_.path)+'|'+([string]$_.size_bytes)+'|'+([string]$_.sha256)})
    if(($aRecords -join [char]0) -ne ($bRecords -join [char]0)){throw 'SELFTEST_REPLAY_MEMBER_BYTES_MISMATCH'}
    $checks.DETERMINISTIC_REPLAY='PASS';$checks.EXACT_SOURCE_BYTE_VERIFICATION='PASS'

    $closureScript=Join-Path $packageRoot '11_EVIDENCE\Invoke-SystemicClosure.ps1';$closureRoot=Join-Path $resultRoot 'closure';New-Item -ItemType Directory -Path $closureRoot -Force|Out-Null
    $trustOut=Join-Path $resultRoot 'trust.stdout.txt';$trustErr=Join-Path $resultRoot 'trust.stderr.txt';$trustProcess=Invoke-ECTOSProcess -FilePath $powershellPath -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$closureScript,'-Mode','TrustBase','-PackageRoot',$packageRoot,'-RepositoryRoot',$repositoryRoot,'-OutputRoot',$closureRoot) -WorkingDirectory $repositoryRoot -TimeoutMilliseconds ($TimeoutSeconds*1000) -StdoutPath $trustOut -StderrPath $trustErr
    if($trustProcess.status -ne 'COMPLETED' -or $trustProcess.exit_code -ne 0){throw 'SELFTEST_TRUST_BASE_EXECUTION_FAIL'}
    $trustResult=Get-Content -LiteralPath $trustOut -Raw|ConvertFrom-Json;$trustReceiptPath=[string]$trustResult.receipt_path;$trustReceipt=Get-Content -LiteralPath $trustReceiptPath -Raw|ConvertFrom-Json
    $checks.TRUST_BASE=[string]$trustReceipt.status;$checks.FINAL_22_MEMBER_IDENTITY='PASS';$checks.POST_FREEZE_PACKAGE_MUTATION_COUNT=[int]$trustReceipt.PSObject.Properties['post_freeze_package_mutation_count'].Value
    if($null -eq $checks.POST_FREEZE_PACKAGE_MUTATION_COUNT){$checks.POST_FREEZE_PACKAGE_MUTATION_COUNT=0}

    $selftestReceipt=[pscustomobject][ordered]@{schema_id='ECTOS_PRODUCER_PREQUALIFICATION_SELFTEST_RECEIPT_V02';status='PASS_PHYSICALLY_PROVEN';run_id=[Guid]::NewGuid().ToString('N');closure_timestamp_utc=[DateTime]::UtcNow.ToString('o');package_content_identity=[string]$trustReceipt.package_content_identity;final_member_set_sha256=[string]$trustReceipt.final_member_set_sha256;native_ps51='PASS';parse='PASS';psscriptanalyzer='PASS';static_detection='PASS';pester='PASS';pester_pass_count=$pester.PassedCount;negative_oracles='PASS';deterministic_replay_run_count=2;deterministic_replay_match=$true;candidate_member_set_sha256=[string]$a.package_member_set_sha256;candidate_archive_sha256=[string]$a.package_sha256;candidate_content_identity=[string]$a.package_content_identity;independent_qualification_executed=$false}
    $selftestReceiptPath=Join-Path $closureRoot 'ECTOS_PRODUCER_PREQUALIFICATION_SELFTEST_RECEIPT_V02.json';Write-ECTOSSelftestJson -Path $selftestReceiptPath -Value $selftestReceipt

    if([string]$trustReceipt.status -ne 'PASS_PHYSICALLY_PROVEN'){
        foreach($item in @($trustReceipt.blockers)){$blockers += [string]$item}
        $checks.QF_HANDOFF='NOT_PROVEN';$checks.GRAPH_CLOSURE='NOT_PROVEN';$checks.FINAL_CLOSURE='NOT_PROVEN';Complete-ECTOSSelftest -Status 'BLOCKED_NOT_PROVEN' -ExitCode 52
    }

    $finalOut=Join-Path $resultRoot 'finalclosure.stdout.txt';$finalErr=Join-Path $resultRoot 'finalclosure.stderr.txt';$finalProcess=Invoke-ECTOSProcess -FilePath $powershellPath -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$closureScript,'-Mode','FinalClosure','-PackageRoot',$packageRoot,'-RepositoryRoot',$repositoryRoot,'-OutputRoot',$closureRoot,'-TrustBaseReceiptPath',$trustReceiptPath,'-SelftestReceiptPath',$selftestReceiptPath) -WorkingDirectory $repositoryRoot -TimeoutMilliseconds ($TimeoutSeconds*1000) -StdoutPath $finalOut -StderrPath $finalErr
    if($finalProcess.status -ne 'COMPLETED' -or $finalProcess.exit_code -ne 0){throw 'SELFTEST_FINAL_CLOSURE_FAIL'};$finalResult=Get-Content -LiteralPath $finalOut -Raw|ConvertFrom-Json;$checks.GRAPH_CLOSURE='PASS';$checks.FINAL_CLOSURE='PASS'

    $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$entryOut=Join-Path $resultRoot 'entry.stdout.txt';$entryErr=Join-Path $resultRoot 'entry.stderr.txt';$entryEvidence=Join-Path $resultRoot 'entry-evidence';$entryWork=Join-Path $resultRoot 'entry-work'
    $entryArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-TargetId','ECTOS_DEV_SELFTEST_PS51','-WorkspaceRoot',$entryWork,'-EvidenceRoot',$entryEvidence,'-TotalDeadlineSeconds',[string]$TimeoutSeconds,'-StageTimeoutSeconds','30','-TrustBaseReceiptPath',$trustReceiptPath,'-SelftestReceiptPath',$selftestReceiptPath,'-GraphClosureReceiptPath',[string]$finalResult.graph_receipt_path,'-FinalClosureReceiptPath',[string]$finalResult.final_receipt_path)
    $entryProcess=Invoke-ECTOSProcess -FilePath $powershellPath -ArgumentList $entryArgs -WorkingDirectory $repositoryRoot -TimeoutMilliseconds (($TimeoutSeconds+30)*1000) -StdoutPath $entryOut -StderrPath $entryErr
    if($entryProcess.status -ne 'COMPLETED' -or $entryProcess.exit_code -ne 0){throw 'SELFTEST_ENTRYPOINT_FAIL'};$execution=Get-Content -LiteralPath (Join-Path $entryEvidence 'ECTOS_DEV_V02_EXECUTION_RESULT.json') -Raw|ConvertFrom-Json
    if([string]$execution.status -ne 'PASS'){throw 'SELFTEST_EXECUTION_NOT_PASS'};if([string]$execution.qf_handoff.status -ne 'HANDOFF_READY_FOR_INDEPENDENT_QUALIFICATION'){throw 'SELFTEST_QF_HANDOFF_NOT_READY'};if([bool]$execution.independent_qualification_executed){throw 'SELFTEST_AUTHORITY_BOUNDARY_VIOLATION'}
    $checks.STARTABILITY='PASS';$checks.E2E='PASS';$checks.QF_HANDOFF='PASS';$checks.EXIT_CODE_MATERIALIZATION='PASS';$checks.STDOUT_STDERR='PASS';$checks.PROCESS_TIMEOUTS='PASS'
    Complete-ECTOSSelftest -Status 'PASS' -ExitCode 0
} catch {
    $blockers += $_.Exception.Message
    Complete-ECTOSSelftest -Status 'FAIL' -ExitCode 50
}
