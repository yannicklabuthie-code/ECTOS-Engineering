[CmdletBinding()]
param([int]$TimeoutSeconds=120)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$resultRoot=Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V1_PRODUCER_SELFTEST_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $resultRoot -Force|Out-Null
$checks=[ordered]@{}
try {
    if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'SELFTEST_NOT_NATIVE_PS51'}
    $checks.NATIVE_PS51='PASS'
    $parseErrors=@();$psFiles=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter '*.ps1')
    foreach($file in $psFiles){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors);foreach($item in @($errors)){if($null -ne $item){$parseErrors+=($file.FullName+':'+$item.Message)}}}
    if($parseErrors.Count -gt 0){throw ('SELFTEST_PARSE_FAIL:' + ($parseErrors -join '|'))};$checks.PARSE='PASS'
    Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -Force
    $issues=@(Invoke-ScriptAnalyzer -Path $packageRoot -Recurse -Severity Error,Warning);$errorsOnly=@($issues|Where-Object {$_.Severity -eq 'Error'})
    if($errorsOnly.Count -gt 0){throw ('SELFTEST_PSSCRIPTANALYZER_FAIL:' + (($errorsOnly|ForEach-Object {$_.RuleName+':'+$_.ScriptName+':'+$_.Line}) -join '|'))};$checks.PSSCRIPTANALYZER='PASS'
    Import-Module Pester -Force
    $pester=Invoke-Pester -Script (Join-Path $PSScriptRoot 'ECTOSDev.Tests.ps1') -PassThru -Quiet
    if($pester.FailedCount -ne 0 -or $pester.PassedCount -lt 1){throw ('SELFTEST_PESTER_FAIL:'+$pester.FailedCount)};$checks.PESTER='PASS';$checks.PESTER_PASS_COUNT=$pester.PassedCount
    $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$workspace=Join-Path $resultRoot 'workspace';$evidence=Join-Path $resultRoot 'evidence';$stdout=Join-Path $resultRoot 'stdout.txt';$stderr=Join-Path $resultRoot 'stderr.txt'
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-TargetId','ECTOS_DEV_SELFTEST_PS51','-WorkspaceRoot',$workspace,'-EvidenceRoot',$evidence)
    $process=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if(-not $process.WaitForExit($TimeoutSeconds*1000)){try{$process.Kill()}catch{Write-Verbose $_.Exception.Message};throw 'SELFTEST_ENTRYPOINT_TIMEOUT'}
    if($process.ExitCode -ne 0){throw ('SELFTEST_ENTRYPOINT_EXIT_'+$process.ExitCode)}
    $execution=Get-Content -LiteralPath (Join-Path $evidence 'ECTOS_DEV_V1_EXECUTION_RESULT.json') -Raw|ConvertFrom-Json
    if($execution.status -ne 'PASS'){throw 'SELFTEST_EXECUTION_NOT_PASS'}
    if($execution.qf_handoff.status -ne 'HANDOFF_READY_FOR_INDEPENDENT_QUALIFICATION'){throw 'SELFTEST_QF_HANDOFF_NOT_READY'}
    if([bool]$execution.independent_qualification_executed){throw 'SELFTEST_AUTHORITY_BOUNDARY_VIOLATION'}
    $checks.STARTABILITY='PASS';$checks.E2E='PASS';$checks.QF_HANDOFF='PASS';$checks.TIMEOUT_CONTROL='PASS'
    $result=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V1_PRODUCER_SELFTEST_RESULT_V01';status='PASS';checks=$checks;result_root=$resultRoot;independent_qualification_executed=$false}
    $result|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $resultRoot 'SELFTEST_RESULT.json') -Encoding UTF8
    $result|ConvertTo-Json -Depth 12 -Compress
    exit 0
} catch {
    $result=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V1_PRODUCER_SELFTEST_RESULT_V01';status='FAIL';checks=$checks;error=$_.Exception.Message;result_root=$resultRoot;independent_qualification_executed=$false}
    $result|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $resultRoot 'SELFTEST_RESULT.json') -Encoding UTF8
    [Console]::Error.WriteLine(($result|ConvertTo-Json -Depth 12 -Compress));exit 50
}
