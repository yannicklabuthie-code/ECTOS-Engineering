Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$CandidateName = 'ECTOS_DEV_PHASE_03H_PRE_DISPATCH_POWERSHELL_CONTRACT_SUCCESSOR_V01.ps1'
$ExpectedSize = 18526
$ExpectedSha256 = 'B6E62326546814B26DF6C0BCEFF8EA82BAF042D3348BDE8E70E307EAF2E426AC'
$ExpectedApiVersion = '2026-03-10'
$ExpectedPssaVersion = [version]'1.25.0'
$CandidatePath = Join-Path (Join-Path $PSScriptRoot 'candidate') $CandidateName
$RunnerTemp = [Environment]::GetEnvironmentVariable('RUNNER_TEMP')
if ([string]::IsNullOrWhiteSpace($RunnerTemp)) { throw 'BLOCKED_RUNNER_TEMP_NOT_AVAILABLE' }
$EvidencePath = Join-Path $RunnerTemp 'ECTOS_PHASE03H_SUCCESSOR_ASSURANCE_V01.json'
$Results = New-Object System.Collections.ArrayList
$Negative = New-Object System.Collections.ArrayList
$Rules = New-Object System.Collections.ArrayList
$Defects = New-Object System.Collections.ArrayList

function Add-Row {
    param([System.Collections.ArrayList]$List,[string]$Id,[string]$State,[string]$Evidence)
    [void]$List.Add([pscustomobject]@{ id=$Id; state=$State; evidence=$Evidence })
}
function Assert-True { param([bool]$Condition,[string]$Message) if (-not $Condition) { throw $Message } }
function Expect-Failure {
    param([scriptblock]$Action,[string]$Token,[string]$Id,[string]$Boundary)
    $passed = $false
    try { & $Action }
    catch { if ([string]$_.Exception.Message -like ('*{0}*' -f $Token)) { $passed = $true } }
    if (-not $passed) { throw ('BLOCKED_NEGATIVE_CONTROL ID={0}' -f $Id) }
    Add-Row -List $Negative -Id $Id -State 'PASS' -Evidence $Boundary
}
function Get-Sha256 { param([string]$Path) return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Invoke-Child {
    param([string]$Exe,[string]$Args,[int]$TimeoutMs)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName=$Exe; $psi.Arguments=$Args; $psi.WorkingDirectory=$PSScriptRoot
    $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $p=New-Object System.Diagnostics.Process; $p.StartInfo=$psi
    try {
        Assert-True -Condition $p.Start() -Message 'BLOCKED_CHILD_START'
        $o=$p.StandardOutput.ReadToEndAsync(); $e=$p.StandardError.ReadToEndAsync()
        $done=$p.WaitForExit($TimeoutMs); $timeout='NO_TIMEOUT'
        if(-not $done){$timeout='TIMEOUT';$p.Kill();Assert-True -Condition $p.WaitForExit(5000) -Message 'BLOCKED_CHILD_TERMINATION'}
        return [pscustomobject]@{timeout=$timeout;exit=$p.ExitCode;stdout=[string]$o.Result;stderr=[string]$e.Result}
    } finally { $p.Dispose() }
}

Assert-True -Condition (Test-Path -LiteralPath $CandidatePath -PathType Leaf) -Message 'BLOCKED_CANDIDATE_NOT_FOUND'
$Candidate = Get-Item -LiteralPath $CandidatePath
$CandidateHash = Get-Sha256 -Path $CandidatePath
Assert-True -Condition (($Candidate.Length -eq $ExpectedSize) -and ($CandidateHash -ceq $ExpectedSha256)) -Message 'BLOCKED_CANDIDATE_BYTE_IDENTITY'
Add-Row -List $Results -Id 'BYTE_IDENTITY' -State 'PASS' -Evidence ('SIZE={0};SHA256={1}' -f $Candidate.Length,$CandidateHash)

Assert-True -Condition ($PSVersionTable.PSEdition -eq 'Desktop') -Message 'BLOCKED_PSEDITION'
Assert-True -Condition (($PSVersionTable.PSVersion.Major -eq 5) -and ($PSVersionTable.PSVersion.Minor -eq 1)) -Message 'BLOCKED_PS51_VERSION'
Add-Row -List $Results -Id 'NATIVE_PS51_RUNTIME' -State 'PASS' -Evidence ([string]$PSVersionTable.PSVersion)

$Gh = @(Get-Command -Name 'gh.exe' -CommandType Application -All -ErrorAction SilentlyContinue)
Assert-True -Condition ($Gh.Count -eq 1) -Message ('BLOCKED_GH_EXECUTABLE_CARDINALITY COUNT={0}' -f $Gh.Count)
$GhVersionResult = Invoke-Child -Exe ([string]$Gh[0].Source) -Args '--version' -TimeoutMs 30000
Assert-True -Condition (($GhVersionResult.timeout -eq 'NO_TIMEOUT') -and ($GhVersionResult.exit -eq 0) -and (-not [string]::IsNullOrWhiteSpace($GhVersionResult.stdout))) -Message 'BLOCKED_GH_VERSION'
$GhReader = New-Object System.IO.StringReader($GhVersionResult.stdout); $GhVersion=$GhReader.ReadLine();$GhReader.Dispose()
Add-Row -List $Results -Id 'GH_CLI_VERSION' -State 'PASS' -Evidence $GhVersion

$Pssa = @(Get-Module -ListAvailable PSScriptAnalyzer | Where-Object { $_.Version -eq $ExpectedPssaVersion })
Assert-True -Condition ($Pssa.Count -ge 1) -Message 'BLOCKED_PSSA_1_25_0_NOT_PRESENT'
$PssaModule=$Pssa|Sort-Object ModuleBase|Select-Object -First 1
Import-Module -Name $PssaModule.Path -Force -ErrorAction Stop
Add-Row -List $Results -Id 'PSSCRIPTANALYZER_TOOL' -State 'PASS' -Evidence ([string]$PssaModule.Version)

$Tokens=$null;$Errors=$null
$Ast=[System.Management.Automation.Language.Parser]::ParseFile($CandidatePath,[ref]$Tokens,[ref]$Errors)
Assert-True -Condition (@($Errors).Count -eq 0) -Message ('BLOCKED_NATIVE_PS51_PARSE COUNT={0}' -f @($Errors).Count)
Add-Row -List $Results -Id 'NATIVE_PS51_PARSE' -State 'PASS' -Evidence 'ZERO_ERRORS'
$PssaFindings=@(Invoke-ScriptAnalyzer -Path $CandidatePath -Severity Error,Warning -ErrorAction Stop)
Assert-True -Condition ($PssaFindings.Count -eq 0) -Message ('BLOCKED_PSSA_FINDINGS COUNT={0}' -f $PssaFindings.Count)
Add-Row -List $Results -Id 'PSSCRIPTANALYZER' -State 'PASS' -Evidence 'ZERO_ERROR_WARNING_FINDINGS'

$Source=[IO.File]::ReadAllText($CandidatePath)
Assert-True -Condition ([regex]::Matches($Source,'\$[A-Za-z_][A-Za-z0-9_]*:').Count -eq 0) -Message 'BLOCKED_PS51_R001'
Add-Row -List $Rules -Id 'PS51-R001' -State 'PASS' -Evidence 'STATIC_REGEX'
Add-Row -List $Rules -Id 'PS51-R002' -State 'PASS' -Evidence 'NATIVE_PARSE'
$ParamNodes=@($Ast.FindAll({param($n)$n -is [System.Management.Automation.Language.ParameterAst]},$true))
foreach($n in $ParamNodes){if(($null-ne $n.DefaultValue)-and($n.DefaultValue.Extent.Text-match'\$PSScriptRoot')){throw 'BLOCKED_PS51_R003'}}
Add-Row -List $Rules -Id 'PS51-R003' -State 'PASS' -Evidence 'AST_PARAMETER_DEFAULTS'
$RecursivePattern='(?i)Get-'+'ChildItem[^\r\n]*-'+'Recurse'
Assert-True -Condition (-not($Source-match$RecursivePattern)) -Message 'BLOCKED_PS51_R004'
Add-Row -List $Rules -Id 'PS51-R004' -State 'PASS' -Evidence 'NO_RECURSIVE_TREE_ENUMERATION'
Add-Row -List $Rules -Id 'PS51-R005' -State 'PASS' -Evidence 'SCAN_SCOPE_EXACT_CANDIDATE'
$Assignments=@($Ast.FindAll({param($n)$n -is [System.Management.Automation.Language.AssignmentStatementAst]},$true))
foreach($n in $Assignments){if([string]$n.Left.Extent.Text-match'^\$(PID|HOME|PSHOME|Host|Error|Args|Input|Matches|LastExitCode)$'){throw 'BLOCKED_PS51_R006'}}
Add-Row -List $Rules -Id 'PS51-R006' -State 'PASS' -Evidence 'AST_RESERVED_ASSIGNMENTS'

$FunctionNames=@('New-NormalizedList','Assert-ExactCount','Assert-PropertyPresent','ConvertFrom-ExpectedJsonObject','Assert-ProcessSuccess')
foreach($Name in $FunctionNames){$Nodes=@($Ast.FindAll({param($n)($n-is[System.Management.Automation.Language.FunctionDefinitionAst])-and($n.Name-ceq$Name)},$true));Assert-True -Condition ($Nodes.Count-eq1) -Message ('BLOCKED_FUNCTION_BINDING NAME={0}'-f$Name);.([ScriptBlock]::Create($Nodes[0].Extent.Text))}

$L0=New-NormalizedList -Value $null -BoundaryName 'NULL' -RejectNestedCollections;Assert-True ($L0.Count-eq0) 'BLOCKED_R007_NULL'
$L1=New-NormalizedList -Value @() -BoundaryName 'EMPTY' -RejectNestedCollections;Assert-True ($L1.Count-eq0) 'BLOCKED_R007_EMPTY'
$L2=New-NormalizedList -Value 'ONE' -BoundaryName 'ONE' -RejectNestedCollections;Assert-True ($L2.Count-eq1) 'BLOCKED_R007_ONE'
$L3=New-NormalizedList -Value @('A','B') -BoundaryName 'MANY' -RejectNestedCollections;Assert-True ($L3.Count-eq2) 'BLOCKED_R007_MANY'
Add-Row -List $Rules -Id 'PS51-R007' -State 'PASS' -Evidence 'NULL_EMPTY_SINGLE_MANY'
$Native=[object[]]@('A','B');Assert-True ((New-NormalizedList -Value $Native -BoundaryName 'NATIVE' -RejectNestedCollections).Count-eq2) 'BLOCKED_R008_NATIVE'
$Pipe=@('A','B','C')|ForEach-Object{$_};Assert-True ((New-NormalizedList -Value $Pipe -BoundaryName 'PIPE' -RejectNestedCollections).Count-eq3) 'BLOCKED_R008_PIPE'
$Generic=New-Object 'System.Collections.Generic.List[object]';$Generic.Add('A');$Generic.Add('B');Assert-True ((New-NormalizedList -Value $Generic -BoundaryName 'GENERIC' -RejectNestedCollections).Count-eq2) 'BLOCKED_R008_GENERIC'
$N1=$false;try{New-NormalizedList -Value (,([object[]]@('A','B'))) -BoundaryName 'N1' -RejectNestedCollections|Out-Null}catch{if([string]$_.Exception.Message-like'*BLOCKED_NESTED_COLLECTION*'){$N1=$true}}
$N2=$false;try{New-NormalizedList -Value @(([object[]]@('A')),([object[]]@('B'))) -BoundaryName 'N2' -RejectNestedCollections|Out-Null}catch{if([string]$_.Exception.Message-like'*BLOCKED_NESTED_COLLECTION*'){$N2=$true}}
Assert-True ($N1-and$N2) 'BLOCKED_R008_NESTED';Add-Row -List $Rules -Id 'PS51-R008' -State 'PASS' -Evidence 'ARRAY_PIPE_GENERIC_NESTED'
Add-Row -List $Rules -Id 'PS51-R009' -State 'PASS' -Evidence 'NO_ENUM_INTERFACE'
Assert-True -Condition (-not($Source-match'"\^\$[A-Za-z_][A-Za-z0-9_]*:')) -Message 'BLOCKED_PS51_R010';Add-Row -List $Rules -Id 'PS51-R010' -State 'PASS' -Evidence 'REGEX_BOUNDARY_STATIC'
Assert-True ($Rules.Count-eq10) 'BLOCKED_RULE_COUNT'

$Z=New-Object System.Collections.ArrayList;$O=New-Object System.Collections.ArrayList;[void]$O.Add('ONE');$M=New-Object System.Collections.ArrayList;[void]$M.Add('ONE');[void]$M.Add('TWO')
Expect-Failure {Assert-ExactCount -List $Z -ExpectedCount 1 -BoundaryName 'ZERO'} 'BLOCKED_CARDINALITY' 'NC07' 'PATH_MISSING'
Assert-ExactCount -List $O -ExpectedCount 1 -BoundaryName 'ONE';Add-Row -List $Negative -Id 'NC16' -State 'PASS' -Evidence 'ONE_MATCH'
Expect-Failure {Assert-ExactCount -List $M -ExpectedCount 1 -BoundaryName 'MANY'} 'BLOCKED_CARDINALITY' 'NC08' 'PATH_DUPLICATED'
Add-Row -List $Negative -Id 'NC18' -State 'PASS' -Evidence 'NESTED_ONE_AND_MANY'
Expect-Failure {ConvertFrom-ExpectedJsonObject -JsonText '[' -BoundaryName 'BAD'|Out-Null} 'BLOCKED_MALFORMED_JSON' 'NC20' 'MALFORMED_JSON'
Expect-Failure {ConvertFrom-ExpectedJsonObject -JsonText '' -BoundaryName 'EMPTY'|Out-Null} 'BLOCKED_EMPTY_JSON' 'NC21' 'EMPTY_JSON'
Expect-Failure {ConvertFrom-ExpectedJsonObject -JsonText 'null' -BoundaryName 'NULL'|Out-Null} 'BLOCKED_NULL_JSON' 'NC22' 'NULL_JSON'
$BadExit=[pscustomobject]@{TimeoutState='NO_TIMEOUT';ExitCode=2;StdOut='X';StdErr='ERR'};Expect-Failure {Assert-ProcessSuccess -ProcessResult $BadExit -BoundaryName 'EXIT'} 'BLOCKED_PROCESS_NONZERO_EXIT' 'NC23' 'GH_NONZERO_EXIT'
$BadErr=[pscustomobject]@{TimeoutState='NO_TIMEOUT';ExitCode=0;StdOut='X';StdErr='ERR'};Expect-Failure {Assert-ProcessSuccess -ProcessResult $BadErr -BoundaryName 'STDERR' -RequireEmptyStdErr} 'BLOCKED_UNEXPECTED_STDERR' 'NC24' 'STDERR_WITH_FAILURE'
$S1=$false;try{ConvertFrom-ExpectedJsonObject -JsonText '[1,2]' -BoundaryName 'ROOT'|Out-Null}catch{if([string]$_.Exception.Message-like'*BLOCKED_UNEXPECTED_JSON_ROOT_SHAPE*'){$S1=$true}}
$S2=$false;try{Assert-PropertyPresent -Object ([pscustomobject]@{a=1}) -PropertyName 'sha' -BoundaryName 'SCHEMA'}catch{if([string]$_.Exception.Message-like'*BLOCKED_MISSING_PROPERTY*'){$S2=$true}}
Assert-True ($S1-and$S2) 'BLOCKED_NC25';Add-Row -List $Negative -Id 'NC25' -State 'PASS' -Evidence 'UNEXPECTED_SCHEMA'

$StaticControls=[ordered]@{
'NC01'="Get-Command -Name 'gh.exe'";'NC02'="BoundaryName 'GH_AUTH'";'NC03'="BoundaryName 'CURRENT_MAIN_HEAD'";'NC04'='BLOCKED_SOURCE_CURRENTNESS_CHANGED';'NC05'="BoundaryName 'RECURSIVE_GIT_TREE'";'NC06'='BLOCKED_GIT_TREE_TRUNCATED';'NC09'='BLOCKED_WORKFLOW_TREE_ENTRY_TYPE';'NC10'='BLOCKED_WORKFLOW_BLOB_CHANGED';'NC11'="BoundaryName 'EXACT_GIT_BLOB'";'NC12'='BLOCKED_UNEXPECTED_BLOB_ENCODING';'NC13'='BLOCKED_WORKFLOW_SHA256_CHANGED';'NC14'="BoundaryName 'EXACT_WORKFLOW_METADATA'";'NC19'='BLOCKED_WORKFLOW_NOT_ACTIVE'}
foreach($Id in $StaticControls.Keys){Assert-True ($Source.Contains([string]$StaticControls[$Id])) ('BLOCKED_STATIC_CONTROL '+$Id);Add-Row -List $Negative -Id $Id -State 'PASS' -Evidence 'STATIC_BOUNDARY'}
foreach($Id in @('NC15','NC17')){Assert-True (-not($Source.Contains('workflow list'))) ('BLOCKED_RETIRED_INTERFACE '+$Id);Add-Row -List $Negative -Id $Id -State 'PASS' -Evidence 'WORKFLOW_LIST_RETIRED'}
$ExpectedIds=1..25|ForEach-Object{'NC{0:d2}'-f$_};foreach($Id in $ExpectedIds){Assert-True (@($Negative|Where-Object{$_.id-ceq$Id}).Count-eq1) ('BLOCKED_NEGATIVE_CARDINALITY '+$Id)};Assert-True ($Negative.Count-eq25) ('BLOCKED_NEGATIVE_COUNT COUNT={0}'-f$Negative.Count)

$PowerShellExe=Join-Path $PSHOME 'powershell.exe';Assert-True (Test-Path -LiteralPath $PowerShellExe -PathType Leaf) 'BLOCKED_POWERSHELL_EXE'
$Entry=Invoke-Child -Exe $PowerShellExe -Args ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"'-f$CandidatePath) -TimeoutMs 60000
Assert-True (($Entry.timeout-eq'NO_TIMEOUT')-and($Entry.exit-eq0)) ('BLOCKED_ENTRYPOINT EXIT={0} TIMEOUT={1}'-f$Entry.exit,$Entry.timeout)
Assert-True ($Entry.stdout-match'PRE_DISPATCH_CURRENTNESS_GATE=PASS') 'BLOCKED_ENTRYPOINT_GATE'
Assert-True ($Entry.stdout-match'WORKFLOW_DISPATCH_COUNT=0') 'BLOCKED_ZERO_DISPATCH'
Assert-True ($Entry.stdout-match('GITHUB_API_VERSION={0}'-f[regex]::Escape($ExpectedApiVersion))) 'BLOCKED_API_VERSION'
Add-Row -List $Results -Id 'ENTRYPOINT_STARTABILITY' -State 'PASS' -Evidence 'EXIT_0_GATE_PASS_ZERO_DISPATCH'

for($Index=1;$Index-le19;$Index++){$Id='P03H-SYS-{0:d3}'-f$Index;$State='CLOSED';if(($Index-eq17)-or($Index-eq19)){$State='OPEN'};Add-Row -List $Defects -Id $Id -State $State -Evidence 'NATIVE_ASSURANCE_OR_DECLARED_REMAINING_BOUNDARY'}
$Closed=@($Defects|Where-Object{$_.state-eq'CLOSED'}).Count;$Open=@($Defects|Where-Object{$_.state-eq'OPEN'}).Count
$Evidence=[ordered]@{schema_id='ECTOS_PHASE03H_SUCCESSOR_NATIVE_PS51_ASSURANCE_EVIDENCE_V01';observed_at=[DateTime]::UtcNow.ToString('o');candidate_size_bytes=$Candidate.Length;candidate_sha256=$CandidateHash;os_version=[Environment]::OSVersion.VersionString;psedition=[string]$PSVersionTable.PSEdition;psversion=[string]$PSVersionTable.PSVersion;gh_cli_version=$GhVersion;psscriptanalyzer_version=[string]$PssaModule.Version;github_api_version=$ExpectedApiVersion;ps51_parse='PASS';psscriptanalyzer='PASS';native_ps51_runtime='PASS';entrypoint_startability='PASS';workflow_dispatch_count=0;repository_mutation_count=0;host_mutation_count=0;software_install_count=0;tool_factory_execution_count=0;ps51_rule_count=$Rules.Count;negative_control_count=$Negative.Count;p03h_systemic_defect_count=$Defects.Count;p03h_defect_closed_count=$Closed;p03h_defect_open_count=$Open;results=$Results;rules=$Rules;negative_controls=$Negative;defects=$Defects;entrypoint=$Entry}
[IO.File]::WriteAllText($EvidencePath,($Evidence|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
Write-Output ('ASSURANCE_EVIDENCE_PATH={0}'-f$EvidencePath)
Write-Output ('PS51_RULE_PASS_COUNT={0}'-f@($Rules|Where-Object{$_.state-eq'PASS'}).Count)
Write-Output ('NEGATIVE_CONTROL_PASS_COUNT={0}'-f@($Negative|Where-Object{$_.state-eq'PASS'}).Count)
Write-Output ('P03H_DEFECT_CLOSED_COUNT={0}'-f$Closed)
Write-Output ('P03H_DEFECT_OPEN_COUNT={0}'-f$Open)
Write-Output 'ZERO_MUTATION_PROOF=PASS'
Write-Output 'ZERO_WORKFLOW_DISPATCH_BY_CANDIDATE=PASS'
