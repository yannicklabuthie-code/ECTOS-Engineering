[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$repositoryRoot=(Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
$governedProfile=Get-Content -LiteralPath (Join-Path $repositoryRoot 'profiles\powershell\ECTOS_POWERSHELL_PS51_PROFILE.json') -Raw|ConvertFrom-Json
if([string]$governedProfile.currentness_state -ne 'CURRENT'){throw 'STATIC_GATE_PROFILE_NOT_CURRENT'}
if([string]$governedProfile.profile_sha256 -ne '4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625'){throw 'STATIC_GATE_PROFILE_IDENTITY_MISMATCH'}
if([string]$governedProfile.ruleset_sha256 -ne '2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525'){throw 'STATIC_GATE_RULESET_IDENTITY_MISMATCH'}
$rule01=Get-Content -LiteralPath (Join-Path $repositoryRoot 'rules\powershell\PS51-R001-ambiguous-variable-reference-before-colon.json') -Raw|ConvertFrom-Json
$rule01Pattern=[string]$rule01.detection_method.pattern
$files=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter '*.ps1' -ErrorAction Stop)
$violations=@()
foreach($file in $files){
    $text=[IO.File]::ReadAllText($file.FullName)
    if([regex]::IsMatch($text,$rule01Pattern)){$violations+=('PS51-R001:'+$file.FullName)}
    if([regex]::IsMatch($text,'(?im)=\s*if\s*\(')){$violations+=('PS51-R002:'+$file.FullName)}
    $tokens=$null;$parseErrors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    foreach($parseError in @($parseErrors)){if($null-ne$parseError){$violations+=('PARSE:'+$file.FullName+':'+$parseError.Message)}}
    foreach($parameter in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.ParameterAst]},$true))){
        if($null-ne$parameter.DefaultValue -and $parameter.DefaultValue.Extent.Text -match '\$PSScriptRoot'){$violations+=('PS51-R003:'+$file.FullName+':'+$parameter.Name.VariablePath.UserPath)}
    }
}
Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -Force
$issues=@(Invoke-ScriptAnalyzer -Path $packageRoot -Recurse -Severity Error,Warning)
foreach($issue in $issues){$violations+=('PSSA:'+$issue.RuleName+':'+$issue.ScriptName+':'+$issue.Line)}
$positive=Get-Content -LiteralPath (Join-Path $repositoryRoot 'fixtures\powershell\positive\PS51_POSITIVE_FIXTURES_V01.json') -Raw|ConvertFrom-Json
$negative=Get-Content -LiteralPath (Join-Path $repositoryRoot 'fixtures\powershell\negative\PS51_NEGATIVE_FIXTURES_V01.json') -Raw|ConvertFrom-Json
$fixtureBindings=@()
foreach($ruleId in @('PS51-R001','PS51-R002','PS51-R003','PS51-R004','PS51-R005','PS51-R006','PS51-R007','PS51-R008','PS51-R009','PS51-R010')){
    $p=@($positive.cases|Where-Object{[string]$_.rule_id -eq $ruleId});$n=@($negative.cases|Where-Object{[string]$_.rule_id -eq $ruleId})
    if($p.Count -ne 1 -or $n.Count -ne 1){$violations+=('REGRESSION_FIXTURE_BINDING:'+$ruleId)}
    if($p.Count -eq 1 -and ([string]$p[0].expected -ne 'PASS' -or [string]::IsNullOrWhiteSpace([string]$p[0].sample))){$violations+=('REGRESSION_POSITIVE_INVALID:'+$ruleId)}
    if($n.Count -eq 1 -and ([string]$n[0].expected -ne 'FAIL' -or [string]::IsNullOrWhiteSpace([string]$n[0].sample))){$violations+=('REGRESSION_NEGATIVE_INVALID:'+$ruleId)}
    if($p.Count -eq 1 -and $n.Count -eq 1){$fixtureBindings += [pscustomobject][ordered]@{rule_id=$ruleId;positive_fixture_id=[string]$p[0].fixture_id;negative_fixture_id=[string]$n[0].fixture_id}}
}
$status='PASS';if($violations.Count -gt 0){$status='FAIL'}
$result=[pscustomobject][ordered]@{
    schema_id='ECTOS_PS51_STATIC_RULE_GATE_RESULT_V02';status=$status;file_count=$files.Count
    profile_sha256='4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625';active_rule_set_sha256='2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525'
    directly_scanned_rules=@('PS51-R001','PS51-R002','PS51-R003','PS51-R006');contract_runtime_rules=@('PS51-R004','PS51-R005','PS51-R007','PS51-R008','PS51-R009','PS51-R010')
    regression_fixture_bindings=@($fixtureBindings);violations=@($violations);repository_root=$repositoryRoot
}
$result|ConvertTo-Json -Depth 8 -Compress
if($status -ne 'PASS'){exit 61}
exit 0
