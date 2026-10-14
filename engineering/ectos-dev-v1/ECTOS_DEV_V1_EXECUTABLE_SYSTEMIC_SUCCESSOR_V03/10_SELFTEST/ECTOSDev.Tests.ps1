$packageRoot=Split-Path $PSScriptRoot -Parent
$repoRoot=(Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
$ErrorActionPreference='Stop'
. (Join-Path $packageRoot '01_LDEV01_ENGINEERING_STATE\Invoke-LDEV01.ps1')
. (Join-Path $packageRoot '02_LDEV02_POLICY_AND_LEARNING\Invoke-LDEV02.ps1')
. (Join-Path $packageRoot '03_LDEV03_BUILD_DEFINITION\Invoke-LDEV03.ps1')
. (Join-Path $packageRoot '04_ECTOS_BUILDER\Invoke-ECTOSBuilder.ps1')
. (Join-Path $packageRoot '05_BUILD_PACKAGE_FACTORY\Invoke-BPF.ps1')
. (Join-Path $packageRoot '06_QUALIFICATION_FACTORY\Invoke-QF.ps1')
. (Join-Path $packageRoot '07_CONTRACTS\Invoke-ECTOSProcess.ps1')
$registry=Get-Content -LiteralPath (Join-Path $packageRoot '08_CONFIG\targets.json') -Raw|ConvertFrom-Json
$target=$registry.targets[0]

function Get-ECTOSTestFailureId {
    param([AllowEmptyString()][string]$Message)
    if([string]::IsNullOrWhiteSpace($Message)){return 'NO_FAILURE'}
    return ($Message -split ':',2)[0]
}
function Invoke-ECTOSFailureOracle {
    param([Parameter(Mandatory=$true)][string]$ExpectedFailureId,[Parameter(Mandatory=$true)][scriptblock]$Action)
    $actual='NO_FAILURE'
    try{& $Action|Out-Null}catch{$actual=Get-ECTOSTestFailureId -Message $_.Exception.Message}
    [pscustomobject][ordered]@{expected_failure_id=$ExpectedFailureId;actual_failure_id=$actual;match=($actual -eq $ExpectedFailureId)}
}
function Assert-ECTOSOracleMatch {
    param([Parameter(Mandatory=$true)]$Oracle)
    $Oracle.expected_failure_id | Should Be $Oracle.actual_failure_id
    $Oracle.match | Should Be $true
}

Describe 'ECTOS DEV V02 exact negative oracle meta-controls' -Tag TrustBase {
    It 'wrong failure cannot satisfy an oracle' {
        $oracle=Invoke-ECTOSFailureOracle -ExpectedFailureId 'EXPECTED_X' -Action {throw 'ACTUAL_Y'}
        $oracle.expected_failure_id|Should Be 'EXPECTED_X';$oracle.actual_failure_id|Should Be 'ACTUAL_Y';$oracle.match|Should Be $false
    }
    It 'no failure cannot satisfy an oracle' {
        $oracle=Invoke-ECTOSFailureOracle -ExpectedFailureId 'EXPECTED_X' -Action {'no failure'}
        $oracle.expected_failure_id|Should Be 'EXPECTED_X';$oracle.actual_failure_id|Should Be 'NO_FAILURE';$oracle.match|Should Be $false
    }
}

Describe 'ECTOS DEV V02 identity chain controls' -Tag TrustBase {
    It 'LDEV01 rejects null target with exact oracle' {
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'LDEV01_TARGET_NULL' -Action {Invoke-ECTOSLDEV01 -Target $null -RepositoryRoot $repoRoot})
    }
    It 'LDEV01 rejects empty target id with exact oracle' {
        $bad=[pscustomobject]@{target_id='';source_repository_identity=$target.source_repository_identity;source_ref_policy='CURRENT_HEAD';predecessor_commit=$target.predecessor_commit;source_root=$target.source_root;source_members=$target.source_members;dependencies=$target.dependencies}
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'LDEV01_TARGET_ID_EMPTY' -Action {Invoke-ECTOSLDEV01 -Target $bad -RepositoryRoot $repoRoot})
    }
    It 'LDEV01 accepts a single dependency and exact source identity' {
        $single=[pscustomobject]@{target_id=$target.target_id;source_repository_identity=$target.source_repository_identity;source_ref_policy='CURRENT_HEAD';predecessor_commit=$target.predecessor_commit;source_root=$target.source_root;source_members=$target.source_members;dependencies=@($target.dependencies[0])}
        $r=Invoke-ECTOSLDEV01 -Target $single -RepositoryRoot $repoRoot
        $r.closure_state|Should Be 'PASS_PHYSICALLY_PROVEN';@($r.dependencies).Count|Should Be 1;@($r.source_member_hash_set).Count|Should Be 3
    }
    It 'LDEV01 accepts many dependencies' {
        $r=Invoke-ECTOSLDEV01 -Target $target -RepositoryRoot $repoRoot
        @($r.dependencies).Count|Should Be 2;@($r.source_member_hash_set).Count|Should Be 3
    }
    It 'LDEV02 resolves selector profile rules and fixtures physically' {
        $r=Invoke-ECTOSLDEV02 -Target $target -RepositoryRoot $repoRoot
        $r.closure_state|Should Be 'PASS_PHYSICALLY_PROVEN';@($r.active_rule_member_set).Count|Should Be 10;@($r.fixture_bindings).Count|Should Be 2
    }
    It 'LDEV03 emits complete reconstructible build definition' {
        $r=Invoke-ECTOSLDEV03 -Target $target -RepositoryRoot $repoRoot
        $r.closure_state|Should Be 'PASS_PHYSICALLY_PROVEN';@($r.exact_source_hash_set).Count|Should Be 3;[int]$r.replay_definition.required_replay_count|Should Be 2
    }
    It 'Builder rejects wrong policy identity with exact oracle' {
        $l1=Invoke-ECTOSLDEV01 -Target $target -RepositoryRoot $repoRoot;$l2=Invoke-ECTOSLDEV02 -Target $target -RepositoryRoot $repoRoot;$l3=Invoke-ECTOSLDEV03 -Target $target -RepositoryRoot $repoRoot
        $l2.ruleset_sha256='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'BUILDER_POLICY_RULESET_MISMATCH' -Action {Invoke-ECTOSBuilder -LDEV01 $l1 -LDEV02 $l2 -LDEV03 $l3 -RepositoryRoot $repoRoot})
    }
    It 'BPF rejects unclosed plan with exact oracle' {
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'BPF_BUILD_PLAN_NOT_CLOSED' -Action {Invoke-ECTOSBPF -BuildPlan ([pscustomobject]@{closure_state='NOT_PROVEN'}) -WorkspaceRoot $TestDrive -RepositoryRoot $repoRoot})
    }
    It 'BPF rejects unauthorized source bytes before copy' {
        $l1=Invoke-ECTOSLDEV01 -Target $target -RepositoryRoot $repoRoot;$l2=Invoke-ECTOSLDEV02 -Target $target -RepositoryRoot $repoRoot;$l3=Invoke-ECTOSLDEV03 -Target $target -RepositoryRoot $repoRoot
        $plan=Invoke-ECTOSBuilder -LDEV01 $l1 -LDEV02 $l2 -LDEV03 $l3 -RepositoryRoot $repoRoot
        $plan.exact_source_hash_set[0].sha256='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'BPF_SOURCE_PRECOPY_HASH_MISMATCH' -Action {Invoke-ECTOSBPF -BuildPlan $plan -WorkspaceRoot (Join-Path $TestDrive 'bad-hash') -RepositoryRoot $repoRoot})
    }
    It 'QF rejects unclosed package with exact oracle' {
        Assert-ECTOSOracleMatch (Invoke-ECTOSFailureOracle -ExpectedFailureId 'QF_HANDOFF_BUILD_NOT_CLOSED' -Action {Invoke-ECTOSQFHandoff -BPFResult ([pscustomobject]@{closure_state='NOT_PROVEN'}) -Target $target -RepositoryRoot $repoRoot -TrustBaseReceiptPath 'x' -SelftestReceiptPath 'x' -GraphClosureReceiptPath 'x' -FinalClosureReceiptPath 'x'})
    }
}

Describe 'ECTOS DEV V02 PS51 process contract' -Tag TrustBase {
    It 'materializes nonzero exit and separate stdout stderr' {
        $script=Join-Path $TestDrive 'process-output.ps1';[IO.File]::WriteAllText($script,"Write-Output 'OUT'`n[Console]::Error.WriteLine('ERR')`nexit 7",(New-Object Text.UTF8Encoding($false)))
        $out=Join-Path $TestDrive 'out.txt';$err=Join-Path $TestDrive 'err.txt';$ps=(Get-Command powershell.exe).Source
        $r=Invoke-ECTOSProcess -FilePath $ps -ArgumentList @('-NoProfile','-File',$script) -WorkingDirectory $TestDrive -TimeoutMilliseconds 10000 -StdoutPath $out -StderrPath $err
        $r.status|Should Be 'COMPLETED';$r.exit_code|Should Be 7;(Get-Content -LiteralPath $out -Raw).Trim()|Should Be 'OUT';(Get-Content -LiteralPath $err -Raw).Trim()|Should Be 'ERR'
    }
    It 'terminates timed out child with exact timeout id' {
        $script=Join-Path $TestDrive 'process-timeout.ps1';[IO.File]::WriteAllText($script,"Start-Sleep -Seconds 5`nexit 0",(New-Object Text.UTF8Encoding($false)))
        $out=Join-Path $TestDrive 'timeout.out';$err=Join-Path $TestDrive 'timeout.err';$ps=(Get-Command powershell.exe).Source
        $r=Invoke-ECTOSProcess -FilePath $ps -ArgumentList @('-NoProfile','-File',$script) -WorkingDirectory $TestDrive -TimeoutMilliseconds 300 -StdoutPath $out -StderrPath $err
        $r.status|Should Be 'TIMEOUT';$r.failure_id|Should Be 'ECTOS_PROCESS_STAGE_TIMEOUT';$r.exit_code|Should Be $null
    }
}

Describe 'ECTOS DEV V02 finalization declarations' -Tag TrustBase {
    It 'manifest declares exact 22 member set and detached closure binding' {
        $m=Get-Content -LiteralPath (Join-Path $packageRoot '12_MANIFEST\ECTOS_DEV_V1_EXECUTABLE_PACKAGE_MANIFEST_V02.json') -Raw|ConvertFrom-Json
        [int]$m.final_member_count|Should Be 22;@($m.members).Count|Should Be 22;[bool]$m.post_freeze_package_mutation_allowed|Should Be $false;$m.source_binding_mode|Should Be 'DETACHED_FINAL_CLOSURE_RECEIPT'
    }
    It 'graph cannot claim in-package physical pass' {
        $g=Get-Content -LiteralPath (Join-Path $packageRoot '12_MANIFEST\ECTOS_PACKAGE_DEPENDENCY_GRAPH_V02.json') -Raw|ConvertFrom-Json
        $g.closure.declaration_state|Should Be 'CLOSURE_EVIDENCE_COMPLETE_PENDING_EXTERNAL_ADJUDICATION';$g.closure.dependency_closure|Should Be 'CLOSURE_EVIDENCE_COMPLETE_PENDING_EXTERNAL_ADJUDICATION';[bool]$g.closure.post_freeze_physical_pass_must_be_external|Should Be $true
    }
}

Describe 'ECTOS DEV V02 top-level exact failures' -Tag TrustBase {
    It 'invalid target returns exact failure id exit code stderr and evidence state' {
        $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$e=Join-Path $TestDrive 'invalid-target-evidence';$w=Join-Path $TestDrive 'invalid-target-work';$stdout=Join-Path $TestDrive 'invalid-target.out';$stderr=Join-Path $TestDrive 'invalid-target.err';$ps=(Get-Command powershell.exe).Source
        $r=Invoke-ECTOSProcess -FilePath $ps -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-TargetId','NO_SUCH_TARGET','-WorkspaceRoot',$w,'-EvidenceRoot',$e) -WorkingDirectory $repoRoot -TimeoutMilliseconds 10000 -StdoutPath $stdout -StderrPath $stderr
        $r.exit_code|Should Be 40;$failure=Get-Content -LiteralPath (Join-Path $e 'ECTOS_DEV_V02_EXECUTION_RESULT.json') -Raw|ConvertFrom-Json;$failure.failure_id|Should Be 'ENTRYPOINT_TARGET_NOT_REGISTERED';$failure.status|Should Be 'FAIL';(Get-Content -LiteralPath $stderr -Raw)|Should Match 'ENTRYPOINT_TARGET_NOT_REGISTERED'
    }
    It 'valid target without trust receipt fails before build with exact id' {
        $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$e=Join-Path $TestDrive 'missing-trust-evidence';$w=Join-Path $TestDrive 'missing-trust-work';$stdout=Join-Path $TestDrive 'missing-trust.out';$stderr=Join-Path $TestDrive 'missing-trust.err';$ps=(Get-Command powershell.exe).Source
        $r=Invoke-ECTOSProcess -FilePath $ps -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-TargetId','ECTOS_DEV_SELFTEST_PS51','-WorkspaceRoot',$w,'-EvidenceRoot',$e) -WorkingDirectory $repoRoot -TimeoutMilliseconds 10000 -StdoutPath $stdout -StderrPath $stderr
        $r.exit_code|Should Be 40;$failure=Get-Content -LiteralPath (Join-Path $e 'ECTOS_DEV_V02_EXECUTION_RESULT.json') -Raw|ConvertFrom-Json;$failure.failure_id|Should Be 'ENTRYPOINT_TRUST_BASE_RECEIPT_MISSING'
    }
}
