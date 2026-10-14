Set-StrictMode -Version Latest

function Get-ECTOSBuildDefinitionSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Invoke-ECTOSLDEV03 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][AllowNull()]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if ($null -eq $Target) { throw 'LDEV03_TARGET_NULL' }
    if (-not ($Target.PSObject.Properties.Name -contains 'build_recipe_path')) { throw 'LDEV03_BUILD_RECIPE_PATH_MISSING' }
    $relative = [string]$Target.build_recipe_path
    if ([string]::IsNullOrWhiteSpace($relative)) { throw 'LDEV03_BUILD_RECIPE_PATH_EMPTY' }
    $path = Join-Path $RepositoryRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'LDEV03_BUILD_RECIPE_NOT_FOUND' }
    try { $recipe = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { throw ('LDEV03_BUILD_RECIPE_INVALID:' + $_.Exception.Message) }
    foreach ($name in @('schema_id','recipe_id','target_id','package_family','package_id','package_version','source_files','toolchain_identity','dependency_lock','workspace_definition','build_parameters','expected_output_contract','replay_definition','rollback_profile','qualification_profile_path')) {
        if (-not ($recipe.PSObject.Properties.Name -contains $name)) { throw ('LDEV03_RECIPE_FIELD_MISSING:' + $name) }
    }
    if ([string]$recipe.schema_id -ne 'ECTOS_DEV_BUILD_RECIPE_V02') { throw 'LDEV03_RECIPE_SCHEMA_MISMATCH' }
    if ([string]$recipe.target_id -ne [string]$Target.target_id) { throw 'LDEV03_RECIPE_TARGET_MISMATCH' }
    $sourceFiles = @($recipe.source_files)
    if ($sourceFiles.Count -eq 0) { throw 'LDEV03_SOURCE_FILES_EMPTY' }
    foreach ($file in $sourceFiles) {
        if ([string]::IsNullOrWhiteSpace([string]$file.path) -or [string]$file.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'LDEV03_SOURCE_HASH_SET_INVALID' }
    }
    if ([string]$recipe.toolchain_identity.target_os -ne 'WINDOWS' -or [string]$recipe.toolchain_identity.target_runtime -ne 'WINDOWS_POWERSHELL_DESKTOP_5_1') { throw 'LDEV03_TOOLCHAIN_NOT_PROVEN' }
    if ([string]$recipe.toolchain_identity.profile_sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or [string]$recipe.toolchain_identity.ruleset_sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'LDEV03_TOOLCHAIN_IDENTITY_INVALID' }
    if (@($recipe.dependency_lock).Count -eq 0) { throw 'LDEV03_DEPENDENCY_LOCK_NOT_PROVEN' }
    foreach ($dependency in @($recipe.dependency_lock)) {
        if ([string]::IsNullOrWhiteSpace([string]$dependency.path) -or [string]$dependency.git_blob -notmatch '^[A-Fa-f0-9]{40}$') { throw 'LDEV03_DEPENDENCY_LOCK_INVALID' }
    }
    if ([string]$recipe.workspace_definition.build_workspace -ne 'EPHEMERAL_EXTERNAL_TO_SOURCE_TREE' -or [string]$recipe.workspace_definition.path_escape_policy -ne 'PROHIBITED') { throw 'LDEV03_WORKSPACE_NOT_PROVEN' }
    if (-not [bool]$recipe.replay_definition.same_authorized_source_bytes_same_materialization_profile_same_package_identity) { throw 'LDEV03_REPLAY_INCOMPLETE' }
    if ([int]$recipe.replay_definition.required_replay_count -lt 2) { throw 'LDEV03_REPLAY_INCOMPLETE' }
    $qualificationProfilePath = Join-Path $RepositoryRoot ([string]$recipe.qualification_profile_path)
    if (-not (Test-Path -LiteralPath $qualificationProfilePath -PathType Leaf)) { throw 'LDEV03_QUALIFICATION_PROFILE_MISSING' }
    $receipt = [pscustomobject][ordered]@{
        schema_id='ECTOS_RECONSTRUCTIBLE_BUILD_DEFINITION_V02';contract_id='ECTOS_BUILD_DEFINITION_CONTRACT_V02';closure_state='PASS_PHYSICALLY_PROVEN'
        target_id=[string]$Target.target_id;recipe_id=[string]$recipe.recipe_id;recipe_sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        package_family=[string]$recipe.package_family;package_id=[string]$recipe.package_id;package_version=[string]$recipe.package_version
        exact_source_hash_set=@($sourceFiles);toolchain_identity=$recipe.toolchain_identity;dependency_lock=@($recipe.dependency_lock)
        workspace_definition=$recipe.workspace_definition;build_parameters=$recipe.build_parameters;expected_output_contract=@($recipe.expected_output_contract)
        replay_definition=$recipe.replay_definition;rollback_profile=[string]$recipe.rollback_profile;qualification_profile_path=[string]$recipe.qualification_profile_path
        qualification_profile_sha256=(Get-FileHash -LiteralPath $qualificationProfilePath -Algorithm SHA256).Hash;build_definition_identity=$null
    }
    $receipt.build_definition_identity = Get-ECTOSBuildDefinitionSha256 -Text ($receipt | ConvertTo-Json -Depth 20 -Compress)
    return $receipt
}
