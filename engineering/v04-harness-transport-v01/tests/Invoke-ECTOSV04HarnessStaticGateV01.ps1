[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$EngineeringRoot,
    [Parameter(Mandatory=$true)][string]$ResultsRoot
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [AllowEmptyString()][string]$Text
    )
    $encoding=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$Text,$encoding)
}

$contractPath=Join-Path $RepoRoot 'profiles\powershell\ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json'
$contract=Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop|ConvertFrom-Json
$rulePaths=@($contract.retrieve.rule_set)
if($rulePaths.Count -ne 10){ throw ('RULESET_MEMBER_COUNT_'+$rulePaths.Count) }
foreach($ruleRelativePath in $rulePaths){
    $rulePath=Join-Path $RepoRoot ([string]$ruleRelativePath -replace '/','\')
    $rule=Get-Content -LiteralPath $rulePath -Raw -ErrorAction Stop|ConvertFrom-Json
    if([string]$rule.currentness -cne 'CURRENT' -or [string]$rule.status -cne 'ACTIVE'){
        throw ('RULE_NOT_CURRENT_ACTIVE_'+[string]$rule.rule_id)
    }
}

$sourceFiles=@(Get-ChildItem -LiteralPath $EngineeringRoot -Recurse -File -Filter '*.ps1' -ErrorAction Stop|Sort-Object FullName)
if($sourceFiles.Count -lt 4){ throw ('SUCCESSOR_PS1_MEMBER_COUNT_TOO_LOW_'+$sourceFiles.Count) }

$ruleFindings=[ordered]@{
    'PS51-R001'=New-Object System.Collections.ArrayList
    'PS51-R002'=New-Object System.Collections.ArrayList
    'PS51-R003'=New-Object System.Collections.ArrayList
    'PS51-R004'=New-Object System.Collections.ArrayList
    'PS51-R005'=New-Object System.Collections.ArrayList
    'PS51-R006'=New-Object System.Collections.ArrayList
    'PS51-R007'=New-Object System.Collections.ArrayList
    'PS51-R008'=New-Object System.Collections.ArrayList
    'PS51-R009'=New-Object System.Collections.ArrayList
    'PS51-R010'=New-Object System.Collections.ArrayList
}
$parseErrorCount=0
$automaticNames=@('args','input','matches','error','foreach','home','host','lastexitcode','myinvocation','nestedpromptlevel','null','pid','profile','psboundparameters','pscmdlet','pscommandpath','psculture','psdebugcontext','pshome','psitem','psscriptroot','psuiculture','psversiontable','pwd','sender','this','true','false')

foreach($sourceFile in $sourceFiles){
    $tokens=$null
    $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($sourceFile.FullName,[ref]$tokens,[ref]$errors)
    $parseErrorCount+=@($errors).Count
    foreach($parseError in @($errors)){
        [void]$ruleFindings['PS51-R001'].Add(('PARSE_ERROR|'+$sourceFile.FullName+'|'+$parseError.Message))
    }

    $text=Get-Content -LiteralPath $sourceFile.FullName -Raw -ErrorAction Stop
    $r001Matches=[regex]::Matches($text,'\$[A-Za-z_][A-Za-z0-9_]*:')
    foreach($match in $r001Matches){
        $scopeQualifier=$match.Value.ToLowerInvariant()
        if($scopeQualifier -notin @('$env:','$script:','$global:','$local:','$private:')){
            [void]$ruleFindings['PS51-R001'].Add(($sourceFile.Name+'|'+$match.Value))
        }
    }

    $inlineIf=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]},$true))
    foreach($item in $inlineIf){ [void]$ruleFindings['PS51-R002'].Add(($sourceFile.Name+'|'+$item.Extent.StartLineNumber)) }

    $parameters=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.ParameterAst]},$true))
    foreach($parameter in $parameters){
        if($null -ne $parameter.DefaultValue -and $parameter.DefaultValue.Extent.Text -match '\$PSScriptRoot'){
            [void]$ruleFindings['PS51-R003'].Add(($sourceFile.Name+'|'+$parameter.Extent.StartLineNumber))
        }
        $parameterName=$parameter.Name.VariablePath.UserPath.ToLowerInvariant()
        if($automaticNames -contains $parameterName){
            [void]$ruleFindings['PS51-R006'].Add(($sourceFile.Name+'|PARAM|'+$parameterName))
        }
    }

    $gciLines=@($text -split "`r?`n"|Where-Object{$_ -match '\bGet-ChildItem\b'})
    foreach($gciLine in $gciLines){
        if($gciLine -notmatch '-ErrorAction\s+Stop'){
            [void]$ruleFindings['PS51-R004'].Add(($sourceFile.Name+'|'+$gciLine.Trim()))
        }
    }

    if($text -match '(?i)Invoke-ScriptAnalyzer[^\r\n]*rules\\powershell|Invoke-ScriptAnalyzer[^\r\n]*fixtures\\powershell'){
        [void]$ruleFindings['PS51-R005'].Add(($sourceFile.Name+'|SELF_REFERENTIAL_SCAN_SCOPE'))
    }

    if($text -match '(?i)\[System\.Collections\.Generic\.List\['){
        [void]$ruleFindings['PS51-R008'].Add(($sourceFile.Name+'|GENERIC_LIST_DECLARATION'))
    }

    if($text -match '(?i)\[System\.IO\.Compression\.CompressionLevel\]\s*\$'){
        [void]$ruleFindings['PS51-R009'].Add(($sourceFile.Name+'|AMBIGUOUS_ENUM_PARAMETER'))
    }

    $expandableRegex=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.BinaryExpressionAst] -and ($node.Operator.ToString() -match 'Match|NotMatch') -and $node.Right -is [System.Management.Automation.Language.ExpandableStringExpressionAst]},$true))
    foreach($item in $expandableRegex){ [void]$ruleFindings['PS51-R010'].Add(($sourceFile.Name+'|'+$item.Extent.StartLineNumber)) }
}

$results=New-Object System.Collections.ArrayList
foreach($ruleId in $ruleFindings.Keys){
    $findingCount=$ruleFindings[$ruleId].Count
    $state='PASS'
    $detail='NO_BLOCKING_OCCURRENCES'
    if($findingCount -ne 0){
        $state='FAIL'
        $detail=[string]::Join(';',@($ruleFindings[$ruleId]))
    }
    if($ruleId -ceq 'PS51-R007' -and $findingCount -eq 0){ $detail='NO_PUBLIC_COLLECTION_BINDING_BOUNDARY;CARDINALITY_TESTS_IN_ENGINEERING_CAMPAIGN' }
    if($ruleId -ceq 'PS51-R008' -and $findingCount -eq 0){ $detail='NO_GENERIC_LIST_INTERFACE_BOUNDARY' }
    if($ruleId -ceq 'PS51-R009' -and $findingCount -eq 0){ $detail='NO_AMBIGUOUS_ENUM_ARGUMENT_BOUNDARY' }
    [void]$results.Add([pscustomobject][ordered]@{rule_id=$ruleId;result=$state;finding_count=$findingCount;detail=$detail})
}

$failCount=@($results|Where-Object{$_.result -cne 'PASS'}).Count
$report=[pscustomobject][ordered]@{
    report_id='ECTOS_DEV_V04_HARNESS_TRANSPORT_STATIC_RULE_REVIEW_V01'
    target_runtime='WINDOWS_POWERSHELL_DESKTOP_5_1'
    source_file_count=$sourceFiles.Count
    parse_error_count=$parseErrorCount
    rule_count=$results.Count
    rule_pass_count=$results.Count-$failCount
    rule_fail_count=$failCount
    results=@($results)
}
if(-not(Test-Path -LiteralPath $ResultsRoot)){ New-Item -ItemType Directory -Path $ResultsRoot -Force|Out-Null }
$reportPath=Join-Path $ResultsRoot 'STATIC_RULE_REVIEW.json'
Write-Utf8NoBom -Path $reportPath -Text (($report|ConvertTo-Json -Depth 10)+"`r`n")
Write-Output ('STATIC_RULE_REVIEW='+$reportPath)
Write-Output ('STATIC_RULE_PASS_COUNT='+$report.rule_pass_count)
Write-Output ('STATIC_RULE_FAIL_COUNT='+$report.rule_fail_count)
Write-Output ('NATIVE_PARSE_ERROR_COUNT='+$parseErrorCount)
if($parseErrorCount -ne 0 -or $failCount -ne 0){ throw 'STATIC_RULE_REVIEW_FAIL_CLOSED' }
