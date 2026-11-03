[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$WorkRoot)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'NATIVE_PS51_REQUIRED'}
$root=Split-Path -Parent $PSScriptRoot
$qc=Join-Path $root 'source\qualification_center\v01'
$files=@(Get-ChildItem -LiteralPath $qc -Recurse -File -Filter '*.ps1')
if($files.Count -ne 14){throw 'V80_SCRIPT_COUNT_MISMATCH'}
$parseIssues=@()
foreach($f in $files){
 $tok=$null;$errs=$null
 [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tok,[ref]$errs)|Out-Null
 foreach($e in @($errs)){$parseIssues+=($f.Name+':'+$e.Message)}
}
if($parseIssues.Count -gt 0){throw ('V80_PS51_PARSE_FAILED|'+($parseIssues -join '|'))}
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$test=Join-Path $qc 'tests\Run-QC-V01-SelfTest.ps1'
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $test -WorkRoot $WorkRoot
if($LASTEXITCODE -ne 0){throw 'V80_NATIVE_SELFTEST_FAILED'}
$r=Get-Content -LiteralPath (Join-Path $WorkRoot 'SELFTEST_RETURN.json') -Raw|ConvertFrom-Json
if($r.final_state -ne 'PRODUCER_SELFTEST_PASS_FAIL_CLOSED'){throw 'V80_NATIVE_SELFTEST_STATE_INVALID'}
Write-Output 'V80_NATIVE_PS51_14_OF_14_PARSE_AND_BOUNDARY_SELFTEST_PASS'
exit 0
