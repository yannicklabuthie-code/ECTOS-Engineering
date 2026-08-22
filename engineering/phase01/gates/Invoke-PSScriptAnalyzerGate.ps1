param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$mod=Get-Module -ListAvailable PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
if(-not $mod){$r=New-EctosGateResult 'PSSCRIPTANALYZER' 'FAIL' $TargetPackageRoot @{reason='PSScriptAnalyzer not installed'};Write-EctosGateResult $r $ResultsRoot;exit 3}
Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -ErrorAction Stop
$issues=@(Invoke-ScriptAnalyzer -Path $TargetPackageRoot -Recurse -Severity Error,Warning)
$blocking=@($issues | Where-Object Severity -eq 'Error')
$r=New-EctosGateResult 'PSSCRIPTANALYZER' $(if($blocking.Count -eq 0){'PASS'}else{'FAIL'}) $TargetPackageRoot @{version=$mod.Version.ToString();issue_count=$issues.Count;blocking_count=$blocking.Count;issues=@($issues|ForEach-Object{"$($_.Severity):$($_.RuleName):$($_.ScriptName):$($_.Line):$($_.Message)"})}
Write-EctosGateResult $r $ResultsRoot
if($r.status -eq 'FAIL'){exit 4}
