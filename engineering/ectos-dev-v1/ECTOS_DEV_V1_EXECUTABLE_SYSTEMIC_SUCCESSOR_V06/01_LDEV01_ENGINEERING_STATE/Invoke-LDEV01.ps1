Set-StrictMode -Version Latest

function Get-ECTOSSha256Text {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Invoke-ECTOSGitText {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string[]]$Arguments)
    $output = & git -C $RepositoryRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw ('LDEV01_GIT_COMMAND_FAIL:' + ($Arguments -join ' ')) }
    return ([string]($output -join "`n")).Trim()
}

function Invoke-ECTOSLDEV01 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][AllowNull()]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if ($null -eq $Target) { throw 'LDEV01_TARGET_NULL' }
    foreach ($name in @('target_id','source_repository_identity','source_ref_policy','predecessor_commit','source_root','source_members','dependencies')) {
        if (-not ($Target.PSObject.Properties.Name -contains $name)) { throw ('LDEV01_TARGET_FIELD_MISSING:' + $name) }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Target.target_id)) { throw 'LDEV01_TARGET_ID_EMPTY' }
    if ([string]$Target.source_ref_policy -ne 'CURRENT_HEAD') { throw 'LDEV01_SOURCE_REF_POLICY_UNSUPPORTED' }
    $repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path
    $remoteUrl = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('config','--get','remote.origin.url')
    if ($remoteUrl -notmatch [regex]::Escape([string]$Target.source_repository_identity)) { throw 'LDEV01_SOURCE_REPOSITORY_MISMATCH' }
    $commit = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('rev-parse','HEAD')
    $tree = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('show','-s','--format=%T','HEAD')
    & git -C $repositoryPath merge-base --is-ancestor ([string]$Target.predecessor_commit) HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'LDEV01_LINEAGE_NOT_PROVEN' }
    $sourceRootRelative = ([string]$Target.source_root).Replace('\','/')
    $sourceRoot = Join-Path $repositoryPath $sourceRootRelative
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw 'LDEV01_SOURCE_ROOT_NOT_FOUND' }
    $sourceTree = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('rev-parse',('HEAD:' + $sourceRootRelative))
    $memberRecords = @()
    foreach ($member in @($Target.source_members)) {
        $relativeName = [string]$member
        if ([string]::IsNullOrWhiteSpace($relativeName)) { throw 'LDEV01_SOURCE_MEMBER_EMPTY' }
        $repoRelative = ($sourceRootRelative.TrimEnd('/') + '/' + $relativeName.Replace('\','/'))
        $fullPath = Join-Path $repositoryPath $repoRelative
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw ('LDEV01_SOURCE_MEMBER_MISSING:' + $relativeName) }
        $rawSha = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        $workspaceObject = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('hash-object','--no-filters',$fullPath)
        $committedObject = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('rev-parse',('HEAD:' + $repoRelative))
        if ($workspaceObject -ne $committedObject) { throw ('LDEV01_WORKSPACE_BYTE_IDENTITY_FAIL:' + $relativeName) }
        $memberRecords += [pscustomobject][ordered]@{path=$relativeName;sha256=$rawSha;git_blob=$committedObject;workspace_object=$workspaceObject;currentness='CURRENT'}
    }
    $dependencyRecords = @()
    foreach ($dependency in @($Target.dependencies)) {
        $path = [string]$dependency.path
        $expectedBlob = [string]$dependency.git_blob
        if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($expectedBlob)) { throw 'LDEV01_DEPENDENCY_IDENTITY_INCOMPLETE' }
        $actualBlob = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('rev-parse',('HEAD:' + $path.Replace('\','/')))
        if ($actualBlob -ne $expectedBlob) { throw ('LDEV01_DEPENDENCY_BLOB_MISMATCH:' + $path) }
        $dependencyRecords += [pscustomobject][ordered]@{path=$path;git_blob=$actualBlob;currentness='CURRENT'}
    }
    $historyCount = Invoke-ECTOSGitText -RepositoryRoot $repositoryPath -Arguments @('rev-list','--count',(([string]$Target.predecessor_commit) + '..HEAD'))
    $receipt = [pscustomobject][ordered]@{
        schema_id='ECTOS_LDEV01_ENGINEERING_STATE_RECEIPT_V02';contract_id='ECTOS_LDEV01_ENGINEERING_STATE_CONTRACT_V02'
        closure_state='PASS_PHYSICALLY_PROVEN';target_id=[string]$Target.target_id;source_repository_identity=[string]$Target.source_repository_identity
        source_commit=$commit;source_tree=$tree;source_subtree=$sourceTree;source_root=$sourceRootRelative;source_member_hash_set=@($memberRecords)
        currentness='CURRENT';predecessor_commit=[string]$Target.predecessor_commit;lineage='DESCENDANT_OF_PREDECESSOR';engineering_state_history_count=[int]$historyCount
        dependencies=@($dependencyRecords);audit_evidence_identity=$null
    }
    $identityPayload = $receipt | ConvertTo-Json -Depth 12 -Compress
    $receipt.audit_evidence_identity = Get-ECTOSSha256Text -Text $identityPayload
    return $receipt
}
