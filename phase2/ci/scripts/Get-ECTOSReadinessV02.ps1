[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$TargetPackageRoot,
  [Parameter(Mandatory)][string]$ResultsRoot,
  [Parameter(Mandatory)][string]$CIStatusRoot,
  [switch]$RequirePS7
)
$ErrorActionPreference='Stop'
$statuses=@{}
Get-ChildItem -LiteralPath $ResultsRoot -File -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $o=Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    if($o.schema_id -eq 'ECTOS_DEV_GATE_RESULT_V01'){$statuses[$o.gate_id]=$o.status}
  } catch {}
}
function AllPass([string[]]$names){
  foreach($n in $names){if(-not $statuses.ContainsKey($n) -or $statuses[$n] -ne 'PASS'){return $false}}
  return $true
}
$dev=AllPass @('PARSE','PSSCRIPTANALYZER','PESTER_UNIT','PESTER_CONTRACT','REGRESSION')
$pkg=$dev -and (AllPass @('PACKAGE_MANIFEST','PACKAGE_INSTALL_LOAD','HASH_IDENTITY'))
$localQual=@('NATIVE_PS51','FIXTURE_REGRESSION','STATE_COLLISION')
if($RequirePS7){$localQual += 'PS7'}
$preCi=$pkg -and (AllPass $localQual)

$required=(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\policies\required-checks-v01.json') -Raw | ConvertFrom-Json).checks
$ciStatuses=@{}
foreach($check in $required){
  $safe=$check -replace '[^A-Za-z0-9_.-]','_'
  $p=Join-Path $CIStatusRoot ($safe+'.json')
  if(Test-Path -LiteralPath $p){
    try{$c=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;$ciStatuses[$check]=$c.status}catch{$ciStatuses[$check]='UNREADABLE'}
  }else{$ciStatuses[$check]='MISSING'}
}
$ciPass=$true
foreach($check in $required){if($ciStatuses[$check] -ne 'PASS'){$ciPass=$false}}
$global=$preCi -and $ciPass
$o=[ordered]@{
  schema_id='ECTOS_DEV_READINESS_V02'
  timestamp_utc=[DateTime]::UtcNow.ToString('o')
  target=$TargetPackageRoot
  ps7_required=[bool]$RequirePS7
  dev_ready=$dev
  package_ready=$pkg
  pre_ci_local_assurance_ready=$preCi
  ci_required_checks_pass=$ciPass
  qualification_ready_global=$global
  gate_status=$statuses
  ci_required_check_status=$ciStatuses
}
$out=Join-Path $ResultsRoot 'READINESS_V02.json'
$o|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $out -Encoding UTF8
$o
if(-not $global){exit 1}
