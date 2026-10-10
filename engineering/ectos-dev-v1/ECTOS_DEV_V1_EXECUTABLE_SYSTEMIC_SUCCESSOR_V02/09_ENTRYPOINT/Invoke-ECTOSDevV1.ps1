[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$TargetId,
    [string]$ConfigRoot,
    [string]$WorkspaceRoot,
    [string]$EvidenceRoot,
    [int]$TotalDeadlineSeconds=120,
    [int]$StageTimeoutSeconds=30,
    [string]$TrustBaseReceiptPath,
    [string]$SelftestReceiptPath,
    [string]$GraphClosureReceiptPath,
    [string]$FinalClosureReceiptPath,
    [ValidateSet('','LDEV01','LDEV02','LDEV03','BUILDER','BPF','QF')][string]$InternalStage='',
    [string]$InternalInputPath,
    [string]$InternalOutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$repositoryRoot=(Resolve-Path (Join-Path $packageRoot '..\..\..')).Path

function Write-ECTOSJsonFile {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 32),(New-Object Text.UTF8Encoding($false)))
}
function Get-ECTOSFailureId {
    param([Parameter(Mandatory=$true)][string]$Message)
    if([string]::IsNullOrWhiteSpace($Message)){return 'ECTOS_UNKNOWN_FAILURE'}
    return ($Message -split ':',2)[0]
}

if(-not [string]::IsNullOrWhiteSpace($InternalStage)){
    try {
        if([string]::IsNullOrWhiteSpace($InternalInputPath) -or -not(Test-Path -LiteralPath $InternalInputPath -PathType Leaf)){throw 'ENTRYPOINT_INTERNAL_INPUT_MISSING'}
        if([string]::IsNullOrWhiteSpace($InternalOutputPath)){throw 'ENTRYPOINT_INTERNAL_OUTPUT_MISSING'}
        $stageInput=Get-Content -LiteralPath $InternalInputPath -Raw|ConvertFrom-Json
        $result=$null
        switch($InternalStage){
            'LDEV01' { . (Join-Path $packageRoot '01_LDEV01_ENGINEERING_STATE\Invoke-LDEV01.ps1');$result=Invoke-ECTOSLDEV01 -Target $stageInput.target -RepositoryRoot ([string]$stageInput.repository_root) }
            'LDEV02' { . (Join-Path $packageRoot '02_LDEV02_POLICY_AND_LEARNING\Invoke-LDEV02.ps1');$result=Invoke-ECTOSLDEV02 -Target $stageInput.target -RepositoryRoot ([string]$stageInput.repository_root) }
            'LDEV03' { . (Join-Path $packageRoot '03_LDEV03_BUILD_DEFINITION\Invoke-LDEV03.ps1');$result=Invoke-ECTOSLDEV03 -Target $stageInput.target -RepositoryRoot ([string]$stageInput.repository_root) }
            'BUILDER' { . (Join-Path $packageRoot '04_ECTOS_BUILDER\Invoke-ECTOSBuilder.ps1');$result=Invoke-ECTOSBuilder -LDEV01 $stageInput.ldev01 -LDEV02 $stageInput.ldev02 -LDEV03 $stageInput.ldev03 -RepositoryRoot ([string]$stageInput.repository_root) }
            'BPF' { . (Join-Path $packageRoot '05_BUILD_PACKAGE_FACTORY\Invoke-BPF.ps1');$result=Invoke-ECTOSBPF -BuildPlan $stageInput.build_plan -WorkspaceRoot ([string]$stageInput.workspace_root) -RepositoryRoot ([string]$stageInput.repository_root) }
            'QF' {
                . (Join-Path $packageRoot '06_QUALIFICATION_FACTORY\Invoke-QF.ps1')
                $result=Invoke-ECTOSQFHandoff -BPFResult $stageInput.bpf_result -Target $stageInput.target -RepositoryRoot ([string]$stageInput.repository_root) -TrustBaseReceiptPath ([string]$stageInput.trust_base_receipt_path) -SelftestReceiptPath ([string]$stageInput.selftest_receipt_path) -GraphClosureReceiptPath ([string]$stageInput.graph_closure_receipt_path) -FinalClosureReceiptPath ([string]$stageInput.final_closure_receipt_path)
            }
        }
        Write-ECTOSJsonFile -Path $InternalOutputPath -Value $result
        $result|ConvertTo-Json -Depth 32 -Compress
        exit 0
    } catch {
        $message=$_.Exception.Message;$failureId=Get-ECTOSFailureId -Message $message
        $failure=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V02_STAGE_FAILURE';status='FAIL';stage=$InternalStage;failure_id=$failureId;detail=$message}
        if(-not[string]::IsNullOrWhiteSpace($InternalOutputPath)){Write-ECTOSJsonFile -Path $InternalOutputPath -Value $failure}
        [Console]::Error.WriteLine(($failure|ConvertTo-Json -Compress));exit 40
    }
}

if([string]::IsNullOrWhiteSpace($ConfigRoot)){$ConfigRoot=Join-Path $packageRoot '08_CONFIG'}
if([string]::IsNullOrWhiteSpace($WorkspaceRoot)){$WorkspaceRoot=Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V02_WORK_'+[Guid]::NewGuid().ToString('N'))}
if([string]::IsNullOrWhiteSpace($EvidenceRoot)){$EvidenceRoot=Join-Path ([IO.Path]::GetTempPath()) ('ECTOS_DEV_V02_EVIDENCE_'+[Guid]::NewGuid().ToString('N'))}
New-Item -ItemType Directory -Path $EvidenceRoot -Force|Out-Null
$evidencePath=Join-Path $EvidenceRoot 'ECTOS_DEV_V02_EXECUTION_RESULT.json'

try {
    if([string]::IsNullOrWhiteSpace($TargetId)){throw 'ENTRYPOINT_TARGET_ID_EMPTY'}
    if($TotalDeadlineSeconds -le 0){throw 'ENTRYPOINT_TOTAL_DEADLINE_INVALID'}
    if($StageTimeoutSeconds -le 0){throw 'ENTRYPOINT_STAGE_TIMEOUT_INVALID'}
    $registryPath=Join-Path $ConfigRoot 'targets.json'
    if(-not(Test-Path -LiteralPath $registryPath -PathType Leaf)){throw 'ENTRYPOINT_TARGET_REGISTRY_MISSING'}
    try{$registry=Get-Content -LiteralPath $registryPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{throw 'ENTRYPOINT_TARGET_REGISTRY_INVALID'}
    $targetMatches=@($registry.targets|Where-Object{[string]$_.target_id -eq $TargetId})
    if($targetMatches.Count -eq 0){throw ('ENTRYPOINT_TARGET_NOT_REGISTERED:'+$TargetId)}
    if($targetMatches.Count -ne 1){throw ('ENTRYPOINT_TARGET_NOT_UNIQUE:'+$TargetId)}
    $target=$targetMatches[0]
    foreach($receiptSpec in @(
        @('ENTRYPOINT_TRUST_BASE_RECEIPT_MISSING',$TrustBaseReceiptPath),
        @('ENTRYPOINT_SELFTEST_RECEIPT_MISSING',$SelftestReceiptPath),
        @('ENTRYPOINT_GRAPH_CLOSURE_RECEIPT_MISSING',$GraphClosureReceiptPath),
        @('ENTRYPOINT_FINAL_CLOSURE_RECEIPT_MISSING',$FinalClosureReceiptPath)
    )){if([string]::IsNullOrWhiteSpace([string]$receiptSpec[1]) -or -not(Test-Path -LiteralPath ([string]$receiptSpec[1]) -PathType Leaf)){throw ([string]$receiptSpec[0])}}
    . (Join-Path $packageRoot '07_CONTRACTS\Invoke-ECTOSProcess.ps1')
    $powershellPath=(Get-Command powershell.exe -ErrorAction Stop).Source
    $deadline=[DateTime]::UtcNow.AddSeconds($TotalDeadlineSeconds)
    $processReceipts=@();$stageResults=@{}
    foreach($stage in @('LDEV01','LDEV02','LDEV03','BUILDER','BPF','QF')){
        $remaining=[int][Math]::Floor(($deadline-[DateTime]::UtcNow).TotalMilliseconds)
        if($remaining -le 0){throw 'ECTOS_PROCESS_TOTAL_TIMEOUT'}
        $stageTimeout=[Math]::Min(($StageTimeoutSeconds*1000),$remaining)
        switch($stage){
            'LDEV01' {$stageInput=[pscustomobject][ordered]@{target=$target;repository_root=$repositoryRoot}}
            'LDEV02' {$stageInput=[pscustomobject][ordered]@{target=$target;repository_root=$repositoryRoot}}
            'LDEV03' {$stageInput=[pscustomobject][ordered]@{target=$target;repository_root=$repositoryRoot}}
            'BUILDER' {$stageInput=[pscustomobject][ordered]@{ldev01=$stageResults.LDEV01;ldev02=$stageResults.LDEV02;ldev03=$stageResults.LDEV03;repository_root=$repositoryRoot}}
            'BPF' {$stageInput=[pscustomobject][ordered]@{build_plan=$stageResults.BUILDER;workspace_root=$WorkspaceRoot;repository_root=$repositoryRoot}}
            'QF' {$stageInput=[pscustomobject][ordered]@{bpf_result=$stageResults.BPF;target=$target;repository_root=$repositoryRoot;trust_base_receipt_path=$TrustBaseReceiptPath;selftest_receipt_path=$SelftestReceiptPath;graph_closure_receipt_path=$GraphClosureReceiptPath;final_closure_receipt_path=$FinalClosureReceiptPath}}
        }
        $prefix=Join-Path $EvidenceRoot $stage.ToLowerInvariant();$inputPath=$prefix+'.input.json';$outputPath=$prefix+'.output.json';$stdoutPath=$prefix+'.stdout.txt';$stderrPath=$prefix+'.stderr.txt'
        Write-ECTOSJsonFile -Path $inputPath -Value $stageInput
        $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-TargetId',$TargetId,'-InternalStage',$stage,'-InternalInputPath',$inputPath,'-InternalOutputPath',$outputPath)
        $processReceipt=Invoke-ECTOSProcess -FilePath $powershellPath -ArgumentList $arguments -WorkingDirectory $repositoryRoot -TimeoutMilliseconds $stageTimeout -StdoutPath $stdoutPath -StderrPath $stderrPath
        $processReceipts += $processReceipt
        if([string]$processReceipt.status -eq 'TIMEOUT'){throw ('ENTRYPOINT_STAGE_TIMEOUT:'+$stage)}
        if($null -eq $processReceipt.exit_code){throw ('ENTRYPOINT_STAGE_EXITCODE_NOT_MATERIALIZED:'+$stage)}
        if([int]$processReceipt.exit_code -ne 0){$stageFailure='UNKNOWN';if(Test-Path -LiteralPath $outputPath){try{$stageFailure=[string](Get-Content -LiteralPath $outputPath -Raw|ConvertFrom-Json).failure_id}catch{Write-Verbose $_.Exception.Message}};throw ('ENTRYPOINT_STAGE_FAIL:'+$stage+':'+$stageFailure)}
        if(-not(Test-Path -LiteralPath $outputPath -PathType Leaf)){throw ('ENTRYPOINT_STAGE_OUTPUT_MISSING:'+$stage)}
        $stageResults[$stage]=Get-Content -LiteralPath $outputPath -Raw|ConvertFrom-Json
    }
    if([DateTime]::UtcNow -gt $deadline){throw 'ECTOS_PROCESS_TOTAL_TIMEOUT'}
    $result=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V02_EXECUTION_RESULT';status='PASS';target_id=$TargetId;total_deadline_seconds=$TotalDeadlineSeconds;stage_timeout_seconds=$StageTimeoutSeconds;ldev01=$stageResults.LDEV01;ldev02=$stageResults.LDEV02;ldev03=$stageResults.LDEV03;builder=$stageResults.BUILDER;bpf=$stageResults.BPF;qf_handoff=$stageResults.QF;process_receipts=@($processReceipts);independent_qualification_executed=$false}
    Write-ECTOSJsonFile -Path $evidencePath -Value $result
    $result|ConvertTo-Json -Depth 32 -Compress
    exit 0
} catch {
    $message=$_.Exception.Message;$failureId=Get-ECTOSFailureId -Message $message
    $failure=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_V02_EXECUTION_RESULT';status='FAIL';target_id=$TargetId;failure_id=$failureId;detail=$message;independent_qualification_executed=$false}
    Write-ECTOSJsonFile -Path $evidencePath -Value $failure
    [Console]::Error.WriteLine(($failure|ConvertTo-Json -Depth 8 -Compress));exit 40
}
