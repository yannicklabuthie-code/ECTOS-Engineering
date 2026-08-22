[CmdletBinding()]
param([Parameter(Mandatory)][string]$TargetPackageRoot,[string]$ResultsRoot,[switch]$ClaimPS7Compatibility)
$ErrorActionPreference='Continue'
$localModules=Join-Path $PSScriptRoot 'tools/modules'
if(Test-Path -LiteralPath $localModules){$env:PSModulePath=$localModules+[IO.Path]::PathSeparator+$env:PSModulePath}
if(-not $ResultsRoot){$ResultsRoot=Join-Path $PSScriptRoot ('results/run_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss'))}
New-Item -ItemType Directory -Force -Path $ResultsRoot|Out-Null
$g=Join-Path $PSScriptRoot 'gates'

# Execute each gate in an isolated child process using the SAME PowerShell edition as the parent.
# This contains per-gate exit codes, preserves full-line/batch qualification, and prevents one gate
# from terminating the orchestrator before the remaining defect classes are evaluated.
if($PSVersionTable.PSEdition -eq 'Desktop'){
  $hostExe=(Get-Command powershell.exe -ErrorAction Stop).Source
}else{
  $hostExe=(Get-Process -Id $PID).Path
}

$steps=@(
 @{Gate='PARSE';File='Invoke-ParseGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot)},
 @{Gate='PSSCRIPTANALYZER';File='Invoke-PSScriptAnalyzerGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot)},
 @{Gate='PESTER_UNIT';File='Invoke-PesterGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot,'-Kind','Unit')},
 @{Gate='PESTER_CONTRACT';File='Invoke-PesterGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot,'-Kind','Contract')},
 @{Gate='FIXTURE_REGRESSION';File='Invoke-PesterGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot,'-Kind','Fixture')},
 @{Gate='STATE_COLLISION';File='Invoke-PesterGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot,'-Kind','State')},
 @{Gate='PACKAGE_MANIFEST';File='Invoke-PackageManifestGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot)},
 @{Gate='PACKAGE_INSTALL_LOAD';File='Invoke-PackageInstallLoadGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot)},
 @{Gate='HASH_IDENTITY';File='Invoke-HashIdentityGate.ps1';Args=@('-TargetPackageRoot',$TargetPackageRoot,'-ResultsRoot',$ResultsRoot)}
)
$gateProcessStatus=[ordered]@{}
$gateLogRoot=Join-Path $ResultsRoot '_gate_logs'
New-Item -ItemType Directory -Force -Path $gateLogRoot | Out-Null
. (Join-Path $g 'Common.ps1')
foreach($s in $steps){
  $scriptPath=Join-Path $g $s.File
  $processArgs=@('-NoProfile')
  if($PSVersionTable.PSEdition -eq 'Desktop'){$processArgs += @('-ExecutionPolicy','Bypass')}
  $processArgs += @('-File',$scriptPath)
  $processArgs += $s.Args
  $logPath=Join-Path $gateLogRoot ($s.Gate + '.log')
  $nativeOutput = @(& $hostExe @processArgs 2>&1)
  $exitCode=$LASTEXITCODE
  $nativeOutput | Out-File -LiteralPath $logPath -Encoding utf8
  $gateProcessStatus[$s.Gate]=$exitCode

  $expectedResult=Join-Path $ResultsRoot ($s.Gate + '.json')
  if(-not (Test-Path -LiteralPath $expectedResult)){
    $synthetic=New-EctosGateResult $s.Gate 'FAIL' $TargetPackageRoot @{
      failure_class='GATE_RESULT_NOT_PRODUCED'
      child_exit_code=$exitCode
      child_script=$scriptPath
      log_path=$logPath
      log_tail=@($nativeOutput | Select-Object -Last 20 | ForEach-Object { $_.ToString() })
    } @($logPath)
    Write-EctosGateResult $synthetic $ResultsRoot | Out-Null
  }
}

# Native runtime evidence is host-specific and never overwrites the other runtime's evidence.
if($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1 -and $PSVersionTable.PSEdition -eq 'Desktop'){
  & (Join-Path $g 'Invoke-NativeRuntimeGate.ps1') -TargetPackageRoot $TargetPackageRoot -ResultsRoot $ResultsRoot -Runtime PS51
} elseif($PSVersionTable.PSVersion.Major -ge 7) {
  & (Join-Path $g 'Invoke-NativeRuntimeGate.ps1') -TargetPackageRoot $TargetPackageRoot -ResultsRoot $ResultsRoot -Runtime PS7
}

# Regression umbrella is derived from the executable regression families.
$deps=@('PESTER_UNIT','PESTER_CONTRACT','FIXTURE_REGRESSION','STATE_COLLISION')
$dependencyStatus=[ordered]@{}
$ok=$true
foreach($d in $deps){
  $rp=Join-Path $ResultsRoot ($d+'.json')
  if(Test-Path -LiteralPath $rp){
    try{$st=(Get-Content -LiteralPath $rp -Raw|ConvertFrom-Json).status}catch{$st='UNREADABLE'}
  } else {$st='MISSING'}
  $dependencyStatus[$d]=$st
  if($st -ne 'PASS'){$ok=$false}
}
. (Join-Path $g 'Common.ps1')
$rr=New-EctosGateResult 'REGRESSION' $(if($ok){'PASS'}else{'FAIL'}) $TargetPackageRoot @{dependency_gates=$dependencyStatus;gate_process_exit_codes=$gateProcessStatus}
Write-EctosGateResult $rr $ResultsRoot|Out-Null

& (Join-Path $g 'Get-ECTOSReadiness.ps1') -TargetPackageRoot $TargetPackageRoot -ResultsRoot $ResultsRoot -RequirePS7:$ClaimPS7Compatibility
