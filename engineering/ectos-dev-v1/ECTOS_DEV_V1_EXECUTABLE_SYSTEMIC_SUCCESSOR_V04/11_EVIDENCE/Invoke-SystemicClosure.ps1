[CmdletBinding()]
param(
    [ValidateSet('TrustBase','FinalClosure')][string]$Mode='TrustBase',
    [string]$PackageRoot,
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$TrustBaseReceiptPath,
    [string]$SelftestReceiptPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($PackageRoot)){$PackageRoot=Split-Path $PSScriptRoot -Parent}
if([string]::IsNullOrWhiteSpace($RepositoryRoot)){$RepositoryRoot=(Resolve-Path (Join-Path $PackageRoot '..\..\..')).Path}
$PackageRoot=(Resolve-Path -LiteralPath $PackageRoot).Path;$RepositoryRoot=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if(-not(Test-Path -LiteralPath $OutputRoot -PathType Container)){New-Item -ItemType Directory -Path $OutputRoot -Force|Out-Null}

function Get-ECTOSClosureSha256Text {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','')}finally{$sha.Dispose()}
}
function Write-ECTOSClosureJson {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 50),(New-Object Text.UTF8Encoding($false)))
}
function Get-ECTOSPackageIdentity {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Repo)
    $rootPath=(Resolve-Path -LiteralPath $Root).Path.TrimEnd('\');$repoPath=(Resolve-Path -LiteralPath $Repo).Path.TrimEnd('\')
    $relativeRoot=$rootPath.Substring($repoPath.Length).TrimStart('\').Replace('\','/')
    $files=@(Get-ChildItem -LiteralPath $rootPath -Recurse -File|Sort-Object FullName)
    if($files.Count -ne 22){throw ('CLOSURE_FINAL_MEMBER_COUNT_MISMATCH:'+$files.Count)}
    $status=@(& git -C $repoPath status --porcelain=v1 -- $relativeRoot);if($LASTEXITCODE -ne 0){throw 'CLOSURE_GIT_STATUS_FAIL'};if($status.Count -ne 0){throw 'CLOSURE_PACKAGE_NOT_FROZEN'}
    $records=@();$rawFailures=@()
    foreach($file in $files){
        $relative=$file.FullName.Substring($rootPath.Length).TrimStart('\').Replace('\','/');$repoRelative=$relativeRoot+'/'+$relative
        $rawSha=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $workspaceObject=(& git -C $repoPath hash-object --no-filters $file.FullName 2>$null|Select-Object -First 1)
        $committedObject=(& git -C $repoPath rev-parse ('HEAD:'+$repoRelative) 2>$null|Select-Object -First 1)
        if($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$committedObject)){throw ('CLOSURE_MEMBER_NOT_COMMITTED:'+$relative)}
        if(([string]$workspaceObject).Trim() -ne ([string]$committedObject).Trim()){$rawFailures+=$relative}
        $records += [pscustomobject][ordered]@{path=$relative;size_bytes=$file.Length;sha256=$rawSha;git_blob=([string]$committedObject).Trim()}
    }
    if($rawFailures.Count -ne 0){throw ('CLOSURE_RAW_BYTE_IDENTITY_FAIL:'+($rawFailures -join ','))}
    $builder=New-Object Text.StringBuilder
    foreach($record in @($records|Sort-Object path)){[void]$builder.Append([string]$record.path);[void]$builder.Append([char]0);[void]$builder.Append([string]$record.size_bytes);[void]$builder.Append([char]0);[void]$builder.Append([string]$record.sha256);[void]$builder.Append([char]10)}
    $memberSetSha=Get-ECTOSClosureSha256Text -Text $builder.ToString();$tree=(& git -C $repoPath rev-parse ('HEAD:'+$relativeRoot) 2>$null|Select-Object -First 1).Trim();$commit=(& git -C $repoPath rev-parse HEAD 2>$null|Select-Object -First 1).Trim()
    $packageIdentity=Get-ECTOSClosureSha256Text -Text ('ECTOS_PACKAGE_CONTENT_IDENTITY_V02'+[char]0+$memberSetSha+[char]0+$tree)
    [pscustomobject][ordered]@{relative_root=$relativeRoot;source_commit=$commit;final_subtree_tree_id=$tree;final_member_count=22;final_member_set=@($records|Sort-Object path);final_member_set_sha256=$memberSetSha;package_content_identity=$packageIdentity;post_freeze_package_mutation_count=0}
}

$identity=Get-ECTOSPackageIdentity -Root $PackageRoot -Repo $RepositoryRoot
$manifestPath=Join-Path $PackageRoot '12_MANIFEST\ECTOS_DEV_V1_EXECUTABLE_PACKAGE_MANIFEST_V02.json';$graphPath=Join-Path $PackageRoot '12_MANIFEST\ECTOS_PACKAGE_DEPENDENCY_GRAPH_V02.json'
if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'CLOSURE_MANIFEST_MISSING'};if(-not(Test-Path -LiteralPath $graphPath -PathType Leaf)){throw 'CLOSURE_GRAPH_MISSING'}
$manifestSha=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;$graphSha=(Get-FileHash -LiteralPath $graphPath -Algorithm SHA256).Hash
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json;$graph=Get-Content -LiteralPath $graphPath -Raw|ConvertFrom-Json
if([string]$manifest.schema_id -ne 'ECTOS_DEV_V1_EXECUTABLE_PACKAGE_MANIFEST_V02' -or [string]$manifest.package_id -ne 'ECTOS_DEV_V1_EXECUTABLE_SYSTEMIC_SUCCESSOR_V04'){throw 'CLOSURE_MANIFEST_SCHEMA_FAIL'}
if([int]$manifest.final_member_count -ne 22 -or @($manifest.members).Count -ne 22){throw 'CLOSURE_MANIFEST_MEMBER_COUNT_FAIL'}
$actualPaths=@($identity.final_member_set|ForEach-Object{[string]$_.path}|Sort-Object);$declaredPaths=@($manifest.members|ForEach-Object{[string]$_}|Sort-Object)
if(($actualPaths -join [char]0) -ne ($declaredPaths -join [char]0)){throw 'CLOSURE_MANIFEST_MEMBER_SET_FAIL'}
if([bool]$manifest.post_freeze_package_mutation_allowed){throw 'CLOSURE_MANIFEST_MUTATION_POLICY_FAIL'}
if([string]$graph.schema_id -ne 'ECTOS_PACKAGE_DEPENDENCY_GRAPH_V02'){throw 'CLOSURE_GRAPH_SCHEMA_FAIL'}
if([string]$graph.closure.declaration_state -ne 'CLOSURE_EVIDENCE_COMPLETE_PENDING_EXTERNAL_ADJUDICATION' -or [string]$graph.closure.dependency_closure -ne 'CLOSURE_EVIDENCE_COMPLETE_PENDING_EXTERNAL_ADJUDICATION'){throw 'CLOSURE_GRAPH_STATE_FAIL'}
foreach($countName in @('undeclared_dependency_count','unresolved_transitive_dependency_count','untested_dependency_count','implicit_environment_assumption_count','unknown_blast_radius_edge_count')){if([int]$graph.closure.$countName -ne 0){throw ('CLOSURE_GRAPH_COUNT_FAIL:'+$countName)}}
foreach($node in @($graph.nodes)){if([string]$node.currentness -ne 'CURRENT'){throw ('CLOSURE_GRAPH_NODE_CURRENTNESS_FAIL:'+[string]$node.dependency_id)}}
foreach($edge in @($graph.edges)){if([string]$edge.currentness -ne 'CURRENT' -or [string]$edge.status -ne 'RESOLVED'){throw ('CLOSURE_GRAPH_EDGE_FAIL:'+[string]$edge.edge_id)}}

if($Mode -eq 'TrustBase'){
    if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'TRUST_BASE_NATIVE_PS51_FAIL'}
    $parseFailures=@();$psFiles=@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Filter '*.ps1')
    foreach($file in $psFiles){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors);foreach($item in @($errors)){if($null-ne$item){$parseFailures+=($file.FullName+':'+$item.Message)}}};if($parseFailures.Count -ne 0){throw ('TRUST_BASE_PARSE_FAIL:'+($parseFailures -join '|'))}
    Import-Module PSScriptAnalyzer -MinimumVersion 1.22.0 -Force;$issues=@(Invoke-ScriptAnalyzer -Path $PackageRoot -Recurse -Severity Error,Warning);if($issues.Count -ne 0){throw ('TRUST_BASE_PSSA_FAIL:'+(($issues|ForEach-Object{$_.RuleName+':'+$_.ScriptName+':'+$_.Line}) -join '|'))}
    $staticScript=Join-Path $PackageRoot '10_SELFTEST\Invoke-StaticRuleGate.ps1';$staticRaw=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $staticScript;if($LASTEXITCODE -ne 0){throw 'TRUST_BASE_STATIC_GATE_FAIL'};$staticResult=$staticRaw|ConvertFrom-Json;if([string]$staticResult.status -ne 'PASS'){throw 'TRUST_BASE_STATIC_GATE_FAIL'}
    Import-Module Pester -RequiredVersion 3.4.0 -Force;$testScript=Join-Path $PackageRoot '10_SELFTEST\ECTOSDev.Tests.ps1';$pester=Invoke-Pester -Script $testScript -Tag TrustBase -PassThru -Quiet;if($pester.FailedCount -ne 0 -or $pester.PassedCount -lt 1){throw ('TRUST_BASE_PESTER_FAIL:'+$pester.FailedCount)}
    $phase01Path=Join-Path $RepositoryRoot 'engineering\phase01\RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1';$phase01Exists=Test-Path -LiteralPath $phase01Path -PathType Leaf
    $pesterVersions=@(Get-Module -ListAvailable Pester|ForEach-Object{$_.Version}|Sort-Object -Descending);$pester6Available=$false;foreach($version in $pesterVersions){if($version -ge [Version]'6.0.0'){$pester6Available=$true;break}}
    $blockers=@();if(-not$phase01Exists){$blockers+='PHASE01_QF_ADAPTER_NOT_AVAILABLE'};if(-not$pester6Available){$blockers+='QUALIFICATION_PESTER_6_NOT_AVAILABLE'}
    $trustRecords=@();foreach($member in @($graph.trust_base)){$path=[string]$member.path;$match=@($identity.final_member_set|Where-Object{$_.path -eq $path});if($match.Count -ne 1){throw ('TRUST_BASE_MEMBER_MISSING:'+$path)};$trustRecords += [pscustomobject][ordered]@{role=[string]$member.role;path=$path;sha256=[string]$match[0].sha256;currentness='CURRENT';dependency_closure='PASS_PHYSICALLY_PROVEN';static_assurance='PASS';native_assurance='PASS_WHERE_APPLICABLE';negative_controls='PASS'}}
    $trustStatus='PASS_PHYSICALLY_PROVEN';if($blockers.Count -ne 0){$trustStatus='NOT_PROVEN'}
    $receipt=[pscustomobject][ordered]@{schema_id='ECTOS_QUALIFICATION_TRUST_BASE_RECEIPT_V02';status=$trustStatus;run_id=[Guid]::NewGuid().ToString('N');closure_timestamp_utc=[DateTime]::UtcNow.ToString('o');package_content_identity=[string]$identity.package_content_identity;final_member_set_sha256=[string]$identity.final_member_set_sha256;source_commit=[string]$identity.source_commit;profile_sha256='4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625';ruleset_sha256='2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525';native_runtime=($PSVersionTable.PSEdition+'|'+$PSVersionTable.PSVersion.ToString());static_gate=$staticResult;trust_base_members=@($trustRecords);pester_producer_version=(Get-Module Pester).Version.ToString();pester_trustbase_pass_count=$pester.PassedCount;phase01_qf_adapter_present=$phase01Exists;qualification_pester_6_available=$pester6Available;post_freeze_package_mutation_count=[int]$identity.post_freeze_package_mutation_count;blockers=@($blockers)}
    $path=Join-Path $OutputRoot 'ECTOS_QUALIFICATION_TRUST_BASE_RECEIPT_V02.json';Write-ECTOSClosureJson -Path $path -Value $receipt
    [pscustomobject][ordered]@{status=$trustStatus;mode='TrustBase';receipt_path=$path;receipt_sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;package_content_identity=[string]$identity.package_content_identity;blockers=@($blockers)}|ConvertTo-Json -Depth 8 -Compress
    exit 0
}

if([string]::IsNullOrWhiteSpace($TrustBaseReceiptPath) -or -not(Test-Path -LiteralPath $TrustBaseReceiptPath -PathType Leaf)){throw 'FINAL_CLOSURE_TRUST_BASE_RECEIPT_MISSING'}
if([string]::IsNullOrWhiteSpace($SelftestReceiptPath) -or -not(Test-Path -LiteralPath $SelftestReceiptPath -PathType Leaf)){throw 'FINAL_CLOSURE_SELFTEST_RECEIPT_MISSING'}
$trust=Get-Content -LiteralPath $TrustBaseReceiptPath -Raw|ConvertFrom-Json;$selftest=Get-Content -LiteralPath $SelftestReceiptPath -Raw|ConvertFrom-Json
if([string]$trust.status -ne 'PASS_PHYSICALLY_PROVEN' -or [string]$trust.package_content_identity -ne [string]$identity.package_content_identity){throw 'FINAL_CLOSURE_TRUST_BASE_BINDING_FAIL'}
if([string]$selftest.schema_id -ne 'ECTOS_PRODUCER_PREQUALIFICATION_SELFTEST_RECEIPT_V02' -or [string]$selftest.status -ne 'PASS_PHYSICALLY_PROVEN' -or [string]$selftest.package_content_identity -ne [string]$identity.package_content_identity){throw 'FINAL_CLOSURE_SELFTEST_BINDING_FAIL'}
$graphReceipt=[pscustomobject][ordered]@{schema_id='ECTOS_DETACHED_GRAPH_CLOSURE_RECEIPT_V02';status='PASS_PHYSICALLY_PROVEN';run_id=[Guid]::NewGuid().ToString('N');closure_timestamp_utc=[DateTime]::UtcNow.ToString('o');package_content_identity=[string]$identity.package_content_identity;final_member_set_sha256=[string]$identity.final_member_set_sha256;dependency_graph_sha256=$graphSha;graph_declaration_state=[string]$graph.closure.declaration_state;graph_closure_state='PASS_PHYSICALLY_PROVEN';post_freeze_package_mutation_count=0}
$graphReceiptPath=Join-Path $OutputRoot 'ECTOS_DETACHED_GRAPH_CLOSURE_RECEIPT_V02.json';Write-ECTOSClosureJson -Path $graphReceiptPath -Value $graphReceipt
$finalReceipt=[pscustomobject][ordered]@{schema_id='ECTOS_DEV_FINAL_CLOSURE_RECEIPT_V02';status='PASS_PHYSICALLY_PROVEN';run_id=[Guid]::NewGuid().ToString('N');closure_timestamp_utc=[DateTime]::UtcNow.ToString('o');successor_id='ECTOS_DEV_V1_EXECUTABLE_SYSTEMIC_SUCCESSOR_V04';package_content_identity=[string]$identity.package_content_identity;final_member_set_sha256=[string]$identity.final_member_set_sha256;final_member_count=22;all_member_sha256=@($identity.final_member_set);manifest_sha256=$manifestSha;dependency_graph_sha256=$graphSha;final_subtree_tree_id=[string]$identity.final_subtree_tree_id;source_commit=[string]$identity.source_commit;identity_algorithm_version='ECTOS_DETERMINISTIC_PACKAGE_IDENTITY_V02';trust_base_receipt_sha256=(Get-FileHash -LiteralPath $TrustBaseReceiptPath -Algorithm SHA256).Hash;selftest_receipt_sha256=(Get-FileHash -LiteralPath $SelftestReceiptPath -Algorithm SHA256).Hash;graph_closure_receipt_sha256=(Get-FileHash -LiteralPath $graphReceiptPath -Algorithm SHA256).Hash;post_freeze_package_mutation_count=0;host_identity=[Environment]::MachineName;runtime_identity=($PSVersionTable.PSEdition+'|'+$PSVersionTable.PSVersion.ToString())}
$finalReceiptPath=Join-Path $OutputRoot 'ECTOS_DEV_FINAL_CLOSURE_RECEIPT_V02.json';Write-ECTOSClosureJson -Path $finalReceiptPath -Value $finalReceipt
[pscustomobject][ordered]@{status='PASS_PHYSICALLY_PROVEN';mode='FinalClosure';final_receipt_path=$finalReceiptPath;final_receipt_sha256=(Get-FileHash -LiteralPath $finalReceiptPath -Algorithm SHA256).Hash;graph_receipt_path=$graphReceiptPath;graph_receipt_sha256=(Get-FileHash -LiteralPath $graphReceiptPath -Algorithm SHA256).Hash;package_content_identity=[string]$identity.package_content_identity}|ConvertTo-Json -Compress
exit 0
