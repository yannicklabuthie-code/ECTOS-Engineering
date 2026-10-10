Set-StrictMode -Version Latest
function Invoke-ECTOSLDEV02 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if (-not ($Target.PSObject.Properties.Name -contains 'rule_profile_path')) { throw 'LDEV02_RULE_PROFILE_PATH_MISSING' }
    $relative = [string]$Target.rule_profile_path
    if ([string]::IsNullOrWhiteSpace($relative)) { throw 'LDEV02_RULE_PROFILE_PATH_EMPTY' }
    $path = Join-Path $RepositoryRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('LDEV02_RULE_PROFILE_NOT_FOUND:' + $relative) }
    try { $ruleProfile = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { throw ('LDEV02_RULE_PROFILE_INVALID:' + $_.Exception.Message) }
    if (-not ($ruleProfile.PSObject.Properties.Name -contains 'profile_id')) { throw 'LDEV02_PROFILE_ID_MISSING' }
    if (-not ($ruleProfile.PSObject.Properties.Name -contains 'rules')) { throw 'LDEV02_RULES_MISSING' }
    if (@($ruleProfile.rules).Count -eq 0) { throw 'LDEV02_RULES_EMPTY' }
    [pscustomobject][ordered]@{
        schema_id='ECTOS_LDEV02_POLICY_RESULT_V01'; status='PASS'; profile_id=[string]$ruleProfile.profile_id
        rule_count=@($ruleProfile.rules).Count; rules=@($ruleProfile.rules); profile_path=$path
    }
}
