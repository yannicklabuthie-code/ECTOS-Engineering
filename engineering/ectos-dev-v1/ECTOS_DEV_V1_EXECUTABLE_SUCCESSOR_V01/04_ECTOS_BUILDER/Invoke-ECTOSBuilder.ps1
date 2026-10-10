Set-StrictMode -Version Latest
function Invoke-ECTOSBuilder {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$LDEV01,[Parameter(Mandatory=$true)]$LDEV02,[Parameter(Mandatory=$true)]$LDEV03)
    foreach ($item in @($LDEV01,$LDEV02,$LDEV03)) { if ($null -eq $item -or [string]$item.status -ne 'PASS') { throw 'BUILDER_UPSTREAM_NOT_PASS' } }
    if ([string]$LDEV01.target_id -ne [string]$LDEV03.target_id) { throw 'BUILDER_TARGET_MISMATCH' }
    [pscustomobject][ordered]@{
        schema_id='ECTOS_BUILDER_PLAN_V01'; status='PASS'; target_id=[string]$LDEV01.target_id
        source_root=[string]$LDEV01.source_root; dependencies=@($LDEV01.dependencies)
        rule_profile_id=[string]$LDEV02.profile_id; rules=@($LDEV02.rules)
        recipe_id=[string]$LDEV03.recipe_id; source_files=@($LDEV03.source_files)
        expected_outputs=@($LDEV03.expected_outputs); package_id=[string]$LDEV03.package_id
        package_version=[string]$LDEV03.package_version
    }
}
