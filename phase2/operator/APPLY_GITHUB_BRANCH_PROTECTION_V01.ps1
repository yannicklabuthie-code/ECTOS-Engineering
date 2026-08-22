[CmdletBinding()]
param([Parameter(Mandatory)][string]$RepoFullName,[string]$Branch='main')
$ErrorActionPreference='Stop'
if(-not(Get-Command gh.exe -ErrorAction SilentlyContinue)){throw 'GH_CLI_NOT_FOUND'}
$checks=(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\ci\policies\required-checks-v01.json') -Raw|ConvertFrom-Json).checks
$contexts=@($checks | ForEach-Object {@{context=$_}})
$body=[ordered]@{
 required_status_checks=@{strict=$true;contexts=$checks}
 enforce_admins=$true
 required_pull_request_reviews=@{dismiss_stale_reviews=$true;require_code_owner_reviews=$false;required_approving_review_count=0}
 restrictions=$null
 allow_force_pushes=$false
 allow_deletions=$false
 required_conversation_resolution=$false
}|ConvertTo-Json -Depth 10
$tmp=Join-Path $env:TEMP ('ectos-branch-protection-'+[guid]::NewGuid().ToString('N')+'.json')
$body|Set-Content -LiteralPath $tmp -Encoding UTF8
gh api -X PUT "repos/$RepoFullName/branches/$Branch/protection" --input $tmp
if($LASTEXITCODE -ne 0){throw 'BRANCH_PROTECTION_UPDATE_FAILED'}
Write-Host 'BRANCH_POLICY_RESULT=PASS'
Write-Host "AUTHORITATIVE_BRANCH=$Branch"
Write-Host 'DIRECT_UNCONTROLLED_AUTHORITATIVE_PUSH=NO'
