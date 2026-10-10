Set-StrictMode -Version Latest

function Get-ECTOSBuilderSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Invoke-ECTOSBuilder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$LDEV01,
        [Parameter(Mandatory=$true)]$LDEV02,
        [Parameter(Mandatory=$true)]$LDEV03,
        [Parameter(Mandatory=$true)][string]$RepositoryRoot
    )
    foreach ($item in @($LDEV01,$LDEV02,$LDEV03)) {
        if ($null -eq $item -or [string]$item.closure_state -ne 'PASS_PHYSICALLY_PROVEN') { throw 'BUILDER_UPSTREAM_IDENTITY_NOT_CLOSED' }
    }
    if ([string]$LDEV01.target_id -ne [string]$LDEV02.target_id -or [string]$LDEV01.target_id -ne [string]$LDEV03.target_id) { throw 'BUILDER_TARGET_MISMATCH' }
    if ([string]$LDEV02.profile_sha256 -ne [string]$LDEV03.toolchain_identity.profile_sha256) { throw 'BUILDER_POLICY_PROFILE_MISMATCH' }
    if ([string]$LDEV02.ruleset_sha256 -ne [string]$LDEV03.toolchain_identity.ruleset_sha256) { throw 'BUILDER_POLICY_RULESET_MISMATCH' }

    $actualSource = @{}
    foreach ($record in @($LDEV01.source_member_hash_set)) { $actualSource[[string]$record.path] = [string]$record.sha256 }
    foreach ($expected in @($LDEV03.exact_source_hash_set)) {
        $path = [string]$expected.path
        if (-not $actualSource.ContainsKey($path)) { throw ('BUILDER_SOURCE_MEMBER_MISSING:' + $path) }
        if ([string]$actualSource[$path] -ne [string]$expected.sha256) { throw ('BUILDER_SOURCE_BINDING_MISMATCH:' + $path) }
    }
    if ($actualSource.Count -ne @($LDEV03.exact_source_hash_set).Count) { throw 'BUILDER_SOURCE_MEMBER_SET_MISMATCH' }

    foreach ($dependency in @($LDEV03.dependency_lock)) {
        $path = [string]$dependency.path
        $actualBlob = (& git -C $RepositoryRoot rev-parse ('HEAD:' + $path.Replace('\','/')) 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$actualBlob)) { throw ('BUILDER_DEPENDENCY_NOT_RESOLVED:' + $path) }
        if ([string]$actualBlob.Trim() -ne [string]$dependency.git_blob) { throw ('BUILDER_DEPENDENCY_LOCK_MISMATCH:' + $path) }
    }

    $plan = [pscustomobject][ordered]@{
        schema_id='ECTOS_BUILDER_PLAN_V02';contract_id='ECTOS_BUILDER_PLAN_CONTRACT_V02';closure_state='PASS_PHYSICALLY_PROVEN'
        target_id=[string]$LDEV01.target_id;source_repository_identity=[string]$LDEV01.source_repository_identity;source_commit=[string]$LDEV01.source_commit
        source_tree=[string]$LDEV01.source_tree;source_subtree=[string]$LDEV01.source_subtree;source_root=[string]$LDEV01.source_root
        source_identity_receipt=[string]$LDEV01.audit_evidence_identity;exact_source_hash_set=@($LDEV03.exact_source_hash_set)
        policy_identity_receipt=[string]$LDEV02.audit_evidence_identity;profile_sha256=[string]$LDEV02.profile_sha256;ruleset_sha256=[string]$LDEV02.ruleset_sha256
        build_definition_identity=[string]$LDEV03.build_definition_identity;recipe_id=[string]$LDEV03.recipe_id;package_family=[string]$LDEV03.package_family
        package_id=[string]$LDEV03.package_id;package_version=[string]$LDEV03.package_version;toolchain_identity=$LDEV03.toolchain_identity
        dependency_lock=@($LDEV03.dependency_lock);workspace_contract=$LDEV03.workspace_definition;build_parameters=$LDEV03.build_parameters
        expected_output_contract=@($LDEV03.expected_output_contract);replay_definition=$LDEV03.replay_definition;rollback_profile=[string]$LDEV03.rollback_profile
        qualification_profile_path=[string]$LDEV03.qualification_profile_path;qualification_profile_sha256=[string]$LDEV03.qualification_profile_sha256;build_plan_identity=$null
    }
    $plan.build_plan_identity = Get-ECTOSBuilderSha256 -Text ($plan | ConvertTo-Json -Depth 24 -Compress)
    return $plan
}
