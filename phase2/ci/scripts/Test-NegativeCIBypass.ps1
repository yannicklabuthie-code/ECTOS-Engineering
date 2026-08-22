[CmdletBinding()]
param([Parameter(Mandatory)][string]$Phase2Root,[Parameter(Mandatory)][string]$Phase01Results,[Parameter(Mandatory)][string]$TargetPackageRoot)
$ErrorActionPreference='Stop'
$tmp=Join-Path $env:TEMP ('ectos_ci_bypass_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp|Out-Null
$compiler=Join-Path $Phase2Root 'ci\scripts\Get-ECTOSReadinessV02.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compiler -TargetPackageRoot $TargetPackageRoot -ResultsRoot $Phase01Results -CIStatusRoot $tmp
$exit=$LASTEXITCODE
$r=Get-Content (Join-Path $Phase01Results 'READINESS_V02.json') -Raw|ConvertFrom-Json
if($r.qualification_ready_global -eq $true){throw 'NEGATIVE_CI_BYPASS_TEST_FAIL_GLOBAL_TRUE_WITHOUT_CI'}
if($exit -eq 0){throw 'NEGATIVE_CI_BYPASS_TEST_FAIL_EXIT_ZERO'}
Write-Host 'NEGATIVE_CI_BYPASS_TEST=PASS'
Remove-Item -LiteralPath $tmp -Recurse -Force
