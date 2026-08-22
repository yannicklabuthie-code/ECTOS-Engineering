[CmdletBinding()]
param(
 [string]$RepoName='ECTOS-Engineering',
 [string]$Owner='yannicklabuthie-code',
 [string]$LocalRepoRoot='C:\ECTOS_ENGINEERING_REPO',
 [Parameter(Mandatory)][string]$Phase01PackageRoot,
 [Parameter(Mandatory)][string]$Phase2PackageRoot
)
$ErrorActionPreference='Stop'
if(-not(Get-Command gh.exe -ErrorAction SilentlyContinue)){throw 'GH_CLI_NOT_FOUND'}
if(-not(Get-Command git.exe -ErrorAction SilentlyContinue)){throw 'GIT_NOT_FOUND'}
gh auth status
if($LASTEXITCODE -ne 0){throw 'GH_AUTH_NOT_READY'}
$full="$Owner/$RepoName"
$exists=$true
gh repo view $full --json nameWithOwner 1>$null 2>$null
if($LASTEXITCODE -ne 0){$exists=$false}
if(-not $exists){
  gh repo create $full --private --description "ECTOS engineering control repository" --disable-issues --disable-wiki
  if($LASTEXITCODE -ne 0){throw 'REPOSITORY_CREATE_FAILED'}
}
if(Test-Path $LocalRepoRoot){throw "LOCAL_REPO_ROOT_ALREADY_EXISTS=$LocalRepoRoot"}
git clone "https://github.com/$full.git" $LocalRepoRoot
if($LASTEXITCODE -ne 0){throw 'REPOSITORY_CLONE_FAILED'}
New-Item -ItemType Directory -Force -Path (Join-Path $LocalRepoRoot 'engineering\phase01')|Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LocalRepoRoot 'phase2')|Out-Null
Copy-Item -Path (Join-Path $Phase01PackageRoot '*') -Destination (Join-Path $LocalRepoRoot 'engineering\phase01') -Recurse -Force
Copy-Item -Path (Join-Path $Phase2PackageRoot '*') -Destination (Join-Path $LocalRepoRoot 'phase2') -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $LocalRepoRoot '.github\workflows')|Out-Null
Copy-Item -LiteralPath (Join-Path $Phase2PackageRoot 'ci\workflows\ectos-engineering-assurance.yml') -Destination (Join-Path $LocalRepoRoot '.github\workflows\ectos-engineering-assurance.yml') -Force
Push-Location $LocalRepoRoot
try{
  git checkout -b phase2/github-ci-v01
  git add .
  git commit -m "ECTOS Phase 2 GitHub CI automation V01"
  git push -u origin phase2/github-ci-v01
} finally {Pop-Location}
Write-Host "REPOSITORY_BINDING_PREPARED=PASS"
Write-Host "REPOSITORY=$full"
Write-Host "BRANCH=phase2/github-ci-v01"
Write-Host "NEXT=OPEN_PULL_REQUEST_AFTER_RUNNER_REGISTRATION"
