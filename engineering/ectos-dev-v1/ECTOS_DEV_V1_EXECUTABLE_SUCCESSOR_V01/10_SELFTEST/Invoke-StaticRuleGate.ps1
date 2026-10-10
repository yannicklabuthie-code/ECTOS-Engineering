[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$repositoryRoot=(Resolve-Path (Join-Path $packageRoot '..\..\..')).Path
$rule01Path=Join-Path $repositoryRoot 'rules\powershell\PS51-R001-ambiguous-variable-reference-before-colon.json'
$rule01=Get-Content -LiteralPath $rule01Path -Raw|ConvertFrom-Json
$rule01Pattern=[string]$rule01.detection_method.pattern
$files=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter '*.ps1' -ErrorAction Stop)
$violations=@()
foreach($file in $files){
    $text=[IO.File]::ReadAllText($file.FullName)
    if([regex]::IsMatch($text,$rule01Pattern)){$violations+=('PS51-R001:'+ $file.FullName)}
    if([regex]::IsMatch($text,'(?im)=\s*if\s*\(')){$violations+=('PS51-R002:'+ $file.FullName)}
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach($item in @($errors)){if($null-ne$item){$violations+=('PARSE:'+ $file.FullName+':'+$item.Message)}}
    foreach($parameter in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.ParameterAst]},$true))){
        if($null-ne$parameter.DefaultValue -and $parameter.DefaultValue.Extent.Text -match '\$PSScriptRoot'){$violations+=('PS51-R003:'+ $file.FullName+':'+$parameter.Name.VariablePath.UserPath)}
    }
}
Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -Force
$issues=@(Invoke-ScriptAnalyzer -Path $packageRoot -Recurse -Severity Error,Warning)
foreach($issue in $issues){$violations+=('PSSA:'+ $issue.RuleName+':'+$issue.ScriptName+':'+$issue.Line)}
$status='PASS';if($violations.Count -gt 0){$status='FAIL'}
$result=[pscustomobject][ordered]@{
    schema_id='ECTOS_PS51_STATIC_RULE_GATE_RESULT_V01';status=$status;file_count=$files.Count
    active_rule_set_sha256='2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525'
    directly_scanned_rules=@('PS51-R001','PS51-R002','PS51-R003','PS51-R006')
    contract_runtime_rules=@('PS51-R004','PS51-R005','PS51-R007','PS51-R008','PS51-R009','PS51-R010')
    violations=@($violations);repository_root=$repositoryRoot
}
$result|ConvertTo-Json -Depth 8 -Compress
if($status -ne 'PASS'){exit 61}
exit 0
