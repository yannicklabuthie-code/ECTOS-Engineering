[CmdletBinding()]
param(
 [string]$EngineeringRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\engineering\phase01')).Path,
 [string]$TargetPackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\engineering\phase01\fixtures\sample-package')).Path,
 [string]$ResultsRoot = (Join-Path $env:RUNNER_TEMP 'ectos-results')
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $ResultsRoot|Out-Null
$runner=Join-Path $EngineeringRoot 'RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1'
if(-not(Test-Path -LiteralPath $runner)){throw "PHASE01_RUNNER_NOT_FOUND=$runner"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TargetPackageRoot $TargetPackageRoot -ResultsRoot $ResultsRoot
$rc=$LASTEXITCODE
if($rc -ne 0){throw "PHASE01_RUNNER_EXIT=$rc"}
$readiness=Join-Path $ResultsRoot 'READINESS.json'
if(-not(Test-Path -LiteralPath $readiness)){throw 'PHASE01_READINESS_NOT_PRODUCED'}
$o=Get-Content $readiness -Raw|ConvertFrom-Json
if(-not $o.dev_ready -or -not $o.package_ready){throw 'PHASE01_DEV_OR_PACKAGE_NOT_READY'}
Write-Host "PHASE01_PRE_CI_ASSURANCE=PASS"
