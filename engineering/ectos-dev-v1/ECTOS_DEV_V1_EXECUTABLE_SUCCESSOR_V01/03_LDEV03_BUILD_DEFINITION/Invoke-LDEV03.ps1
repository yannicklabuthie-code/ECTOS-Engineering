Set-StrictMode -Version Latest
function Invoke-ECTOSLDEV03 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if (-not ($Target.PSObject.Properties.Name -contains 'build_recipe_path')) { throw 'LDEV03_BUILD_RECIPE_PATH_MISSING' }
    $relative = [string]$Target.build_recipe_path
    if ([string]::IsNullOrWhiteSpace($relative)) { throw 'LDEV03_BUILD_RECIPE_PATH_EMPTY' }
    $path = Join-Path $RepositoryRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('LDEV03_BUILD_RECIPE_NOT_FOUND:' + $relative) }
    try { $recipe = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { throw ('LDEV03_BUILD_RECIPE_INVALID:' + $_.Exception.Message) }
    if ([string]$recipe.target_id -ne [string]$Target.target_id) { throw 'LDEV03_RECIPE_TARGET_MISMATCH' }
    $sourceFiles = @($recipe.source_files)
    if ($sourceFiles.Count -eq 0) { throw 'LDEV03_SOURCE_FILES_EMPTY' }
    foreach ($file in $sourceFiles) { if ([string]::IsNullOrWhiteSpace([string]$file)) { throw 'LDEV03_SOURCE_FILE_EMPTY' } }
    [pscustomobject][ordered]@{
        schema_id='ECTOS_LDEV03_BUILD_DEFINITION_RESULT_V01'; status='PASS'; target_id=[string]$Target.target_id
        recipe_id=[string]$recipe.recipe_id; source_files=$sourceFiles; expected_outputs=@($recipe.expected_outputs)
        package_id=[string]$recipe.package_id; package_version=[string]$recipe.package_version; recipe_path=$path
    }
}
