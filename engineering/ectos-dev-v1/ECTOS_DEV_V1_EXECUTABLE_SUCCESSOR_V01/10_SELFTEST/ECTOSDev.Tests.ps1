$packageRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = (Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
$ErrorActionPreference = 'Continue'
. (Join-Path $packageRoot '01_LDEV01_ENGINEERING_STATE\Invoke-LDEV01.ps1')
. (Join-Path $packageRoot '02_LDEV02_POLICY_AND_LEARNING\Invoke-LDEV02.ps1')
. (Join-Path $packageRoot '03_LDEV03_BUILD_DEFINITION\Invoke-LDEV03.ps1')
. (Join-Path $packageRoot '04_ECTOS_BUILDER\Invoke-ECTOSBuilder.ps1')

Describe 'ECTOS DEV V1 generic component contracts' {
    It 'LDEV01 accepts single dependency' {
        $t=[pscustomobject]@{target_id='T';source_root='engineering/ectos-dev-v1/ECTOS_DEV_V1_EXECUTABLE_SUCCESSOR_V01/10_SELFTEST/fixture_source';dependencies=@('AGENTS.md')}
        (Invoke-ECTOSLDEV01 -Target $t -RepositoryRoot $repoRoot).dependency_count | Should Be 1
    }
    It 'LDEV01 accepts many dependencies' {
        $t=[pscustomobject]@{target_id='T';source_root='engineering/ectos-dev-v1/ECTOS_DEV_V1_EXECUTABLE_SUCCESSOR_V01/10_SELFTEST/fixture_source';dependencies=@('AGENTS.md','ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json')}
        (Invoke-ECTOSLDEV01 -Target $t -RepositoryRoot $repoRoot).dependency_count | Should Be 2
    }
    It 'LDEV01 rejects missing dependency' {
        $t=[pscustomobject]@{target_id='T';source_root='engineering/ectos-dev-v1/ECTOS_DEV_V1_EXECUTABLE_SUCCESSOR_V01/10_SELFTEST/fixture_source';dependencies=@('NOT_PRESENT.file')}
        { Invoke-ECTOSLDEV01 -Target $t -RepositoryRoot $repoRoot } | Should Throw
    }
    It 'LDEV01 rejects empty target id' {
        $t=[pscustomobject]@{target_id='';source_root='engineering/ectos-dev-v1/ECTOS_DEV_V1_EXECUTABLE_SUCCESSOR_V01/10_SELFTEST/fixture_source';dependencies=@()}
        { Invoke-ECTOSLDEV01 -Target $t -RepositoryRoot $repoRoot } | Should Throw
    }
    It 'Builder rejects failed upstream' {
        $good=[pscustomobject]@{status='PASS';target_id='T';source_root='x';dependencies=@();profile_id='P';rules=@();recipe_id='R';source_files=@('x');expected_outputs=@();package_id='P';package_version='1'}
        $bad=[pscustomobject]@{status='FAIL';target_id='T'}
        { Invoke-ECTOSBuilder -LDEV01 $bad -LDEV02 $good -LDEV03 $good } | Should Throw
    }
}

Describe 'ECTOS DEV V1 top-level entrypoint' {
    $entry = Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1'
    It 'rejects an invalid target with deterministic exit 40' {
        $e=Join-Path $TestDrive 'e1';$w=Join-Path $TestDrive 'w1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -TargetId 'NO_SUCH_TARGET' -WorkspaceRoot $w -EvidenceRoot $e 2>$null | Out-Null
        $LASTEXITCODE | Should Be 40
    }
    It 'rejects empty target with deterministic exit 40' {
        $e=Join-Path $TestDrive 'e2';$w=Join-Path $TestDrive 'w2'
        $command="& '$entry' -TargetId ([string]::Empty) -WorkspaceRoot '$w' -EvidenceRoot '$e'"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded 2>$null | Out-Null
        $LASTEXITCODE | Should Be 40
    }
    It 'executes registered selftest target end-to-end' {
        $e=Join-Path $TestDrive 'e3';$w=Join-Path $TestDrive 'w3'
        $raw=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -TargetId 'ECTOS_DEV_SELFTEST_PS51' -WorkspaceRoot $w -EvidenceRoot $e
        $LASTEXITCODE | Should Be 0
        $o=$raw | ConvertFrom-Json
        $o.status | Should Be 'PASS'
        $o.qf_handoff.status | Should Be 'HANDOFF_READY_FOR_INDEPENDENT_QUALIFICATION'
        $o.independent_qualification_executed | Should Be $false
    }
}

Describe 'ECTOS DEV V1 failure handoff controls' {
    . (Join-Path $packageRoot '05_BUILD_PACKAGE_FACTORY\Invoke-BPF.ps1')
    . (Join-Path $packageRoot '06_QUALIFICATION_FACTORY\Invoke-QF.ps1')
    It 'BPF rejects a failed build plan' {
        { Invoke-ECTOSBPF -BuildPlan ([pscustomobject]@{status='FAIL'}) -WorkspaceRoot (Join-Path $TestDrive 'wf') } | Should Throw
    }
    It 'QF rejects a failed package result' {
        { Invoke-ECTOSQFHandoff -BPFResult ([pscustomobject]@{status='FAIL'}) -Target ([pscustomobject]@{}) -RepositoryRoot $repoRoot } | Should Throw
    }
    It 'entrypoint rejects missing config registry' {
        $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$c=Join-Path $TestDrive 'missing-config';New-Item -ItemType Directory -Path $c|Out-Null
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -TargetId 'ECTOS_DEV_SELFTEST_PS51' -ConfigRoot $c -WorkspaceRoot (Join-Path $TestDrive 'w4') -EvidenceRoot (Join-Path $TestDrive 'e4') 2>$null|Out-Null
        $LASTEXITCODE | Should Be 40
    }
    It 'entrypoint rejects invalid config JSON' {
        $entry=Join-Path $packageRoot '09_ENTRYPOINT\Invoke-ECTOSDevV1.ps1';$c=Join-Path $TestDrive 'bad-config';New-Item -ItemType Directory -Path $c|Out-Null;'{'|Set-Content -LiteralPath (Join-Path $c 'targets.json')
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -TargetId 'ECTOS_DEV_SELFTEST_PS51' -ConfigRoot $c -WorkspaceRoot (Join-Path $TestDrive 'w5') -EvidenceRoot (Join-Path $TestDrive 'e5') 2>$null|Out-Null
        $LASTEXITCODE | Should Be 40
    }
}
