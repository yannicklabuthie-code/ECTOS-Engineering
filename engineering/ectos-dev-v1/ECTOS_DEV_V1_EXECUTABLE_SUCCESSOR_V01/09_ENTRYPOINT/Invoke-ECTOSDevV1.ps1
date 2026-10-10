[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$TargetId,
    [string]$ConfigRoot,
    [string]$WorkspaceRoot,
    [string]$EvidenceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path $PSScriptRoot -Parent
$repositoryRoot = (Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
if ([string]::IsNullOrWhiteSpace($ConfigRoot)) { $ConfigRoot = Join-Path $packageRoot '08_CONFIG' }
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V1_WORK_' + [Guid]::NewGuid().ToString('N')) }
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) { $EvidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V1_EVIDENCE_' + [Guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$evidencePath = Join-Path $EvidenceRoot 'ECTOS_DEV_V1_EXECUTION_RESULT.json'
try {
    if ([string]::IsNullOrWhiteSpace($TargetId)) { throw 'ENTRYPOINT_TARGET_ID_EMPTY' }
    $registryPath = Join-Path $ConfigRoot 'targets.json'
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw 'ENTRYPOINT_TARGET_REGISTRY_MISSING' }
    $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
    $targetMatches = @($registry.targets | Where-Object { [string]$_.target_id -eq $TargetId })
    if ($targetMatches.Count -eq 0) { throw ('ENTRYPOINT_TARGET_NOT_REGISTERED:' + $TargetId) }
    if ($targetMatches.Count -ne 1) { throw ('ENTRYPOINT_TARGET_NOT_UNIQUE:' + $TargetId) }
    $target = $targetMatches[0]
    . (Join-Path $packageRoot '01_LDEV01_ENGINEERING_STATE\Invoke-LDEV01.ps1')
    . (Join-Path $packageRoot '02_LDEV02_POLICY_AND_LEARNING\Invoke-LDEV02.ps1')
    . (Join-Path $packageRoot '03_LDEV03_BUILD_DEFINITION\Invoke-LDEV03.ps1')
    . (Join-Path $packageRoot '04_ECTOS_BUILDER\Invoke-ECTOSBuilder.ps1')
    . (Join-Path $packageRoot '05_BUILD_PACKAGE_FACTORY\Invoke-BPF.ps1')
    . (Join-Path $packageRoot '06_QUALIFICATION_FACTORY\Invoke-QF.ps1')
    $l1 = Invoke-ECTOSLDEV01 -Target $target -RepositoryRoot $repositoryRoot
    $l2 = Invoke-ECTOSLDEV02 -Target $target -RepositoryRoot $repositoryRoot
    $l3 = Invoke-ECTOSLDEV03 -Target $target -RepositoryRoot $repositoryRoot
    $plan = Invoke-ECTOSBuilder -LDEV01 $l1 -LDEV02 $l2 -LDEV03 $l3
    $bpf = Invoke-ECTOSBPF -BuildPlan $plan -WorkspaceRoot $WorkspaceRoot
    $qf = Invoke-ECTOSQFHandoff -BPFResult $bpf -Target $target -RepositoryRoot $repositoryRoot
    $result = [pscustomobject][ordered]@{schema_id='ECTOS_DEV_V1_EXECUTION_RESULT_V01';status='PASS';target_id=$TargetId;ldev01=$l1;ldev02=$l2;ldev03=$l3;builder=$plan;bpf=$bpf;qf_handoff=$qf;independent_qualification_executed=$false}
    $result | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    $result | ConvertTo-Json -Depth 16 -Compress
    exit 0
} catch {
    $failure = [pscustomobject][ordered]@{schema_id='ECTOS_DEV_V1_EXECUTION_RESULT_V01';status='FAIL';target_id=$TargetId;error=$_.Exception.Message;independent_qualification_executed=$false}
    $failure | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    [Console]::Error.WriteLine(($failure | ConvertTo-Json -Depth 8 -Compress))
    exit 40
}
