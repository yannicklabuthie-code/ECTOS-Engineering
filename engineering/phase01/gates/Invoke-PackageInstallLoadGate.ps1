param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$m=Join-Path $TargetPackageRoot 'ectos-package-manifest.json';$errors=@();$entry=$null
if(Test-Path $m){try{$o=Get-Content $m -Raw|ConvertFrom-Json;$entry=Join-Path $TargetPackageRoot $o.entrypoint}catch{$errors+='manifest_unreadable'}}else{$errors+='manifest_missing'}
if($entry -and -not(Test-Path -LiteralPath $entry)){$errors+='entrypoint_missing'}
if($entry -and (Test-Path $entry) -and [IO.Path]::GetExtension($entry) -eq '.ps1'){$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$t,[ref]$e)|Out-Null;if($e){$errors+='entrypoint_parse_failure'}}
$r=New-EctosGateResult 'PACKAGE_INSTALL_LOAD' $(if($errors.Count -eq 0){'PASS'}else{'FAIL'}) $TargetPackageRoot @{entrypoint=$entry;errors=$errors};Write-EctosGateResult $r $ResultsRoot;if($r.status -eq 'FAIL'){exit 9}
