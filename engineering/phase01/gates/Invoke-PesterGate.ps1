param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot,[ValidateSet('Unit','Contract','Fixture','State')][string]$Kind)
. (Join-Path $PSScriptRoot 'Common.ps1')
$mod=Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
$gate=@{Unit='PESTER_UNIT';Contract='PESTER_CONTRACT';Fixture='FIXTURE_REGRESSION';State='STATE_COLLISION'}[$Kind]
if(-not $mod -or $mod.Version -lt [version]'6.0.0'){$r=New-EctosGateResult $gate 'FAIL' $TargetPackageRoot @{reason='Pester 6.0.0+ not installed';found=if($mod){$mod.Version.ToString()}else{$null}};Write-EctosGateResult $r $ResultsRoot;exit 5}
Import-Module Pester -MinimumVersion 6.0.0 -Force
$folder=@{Unit='unit';Contract='contracts';Fixture='fixtures';State='state'}[$Kind]
$testPath=Join-Path (Split-Path $PSScriptRoot -Parent) ('tests/' + $folder)
$config=New-PesterConfiguration
$config.Run.Path=$testPath
$config.Run.PassThru=$true
$config.Output.Verbosity='Detailed'
$config.TestResult.Enabled=$true
$config.TestResult.OutputPath=(Join-Path $ResultsRoot ($gate + '.xml'))
$config.TestResult.OutputFormat='NUnitXml'
$env:ECTOS_TEST_TARGET=$TargetPackageRoot
$res=Invoke-Pester -Configuration $config
$r=New-EctosGateResult $gate $(if($res.FailedCount -eq 0 -and $res.PassedCount -gt 0){'PASS'}else{'FAIL'}) $TargetPackageRoot @{pester_version=$mod.Version.ToString();passed=$res.PassedCount;failed=$res.FailedCount;skipped=$res.SkippedCount}
Write-EctosGateResult $r $ResultsRoot
if($r.status -eq 'FAIL'){exit 6}
