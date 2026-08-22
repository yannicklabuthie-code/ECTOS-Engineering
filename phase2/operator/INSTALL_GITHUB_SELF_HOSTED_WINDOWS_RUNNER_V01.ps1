[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoFullName,
  [string]$RunnerName = $env:COMPUTERNAME + '-ECTOS-PS51',
  [string]$RunnerRoot = 'C:\ECTOS_GHA_RUNNER',
  [string]$Labels = 'ectos-ps51'
)
$ErrorActionPreference='Stop'
Write-Host '======================================================================'
Write-Host 'ECTOS PHASE 2 - GITHUB SELF-HOSTED WINDOWS RUNNER BOOTSTRAP V01'
Write-Host '======================================================================'
if(-not(Get-Command gh.exe -ErrorAction SilentlyContinue)){throw 'GH_CLI_NOT_FOUND'}
gh auth status
if($LASTEXITCODE -ne 0){throw 'GH_AUTH_NOT_READY'}
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){
  throw 'BOOTSTRAP_MUST_BE_LAUNCHED_FROM_WINDOWS_POWERSHELL_5_1'
}
$repo=gh api "repos/$RepoFullName" | ConvertFrom-Json
if(-not $repo.full_name){throw 'REPOSITORY_NOT_ACCESSIBLE'}
$token=(gh api -X POST "repos/$RepoFullName/actions/runners/registration-token" | ConvertFrom-Json).token
if(-not $token){throw 'RUNNER_REGISTRATION_TOKEN_NOT_PRODUCED'}
$release=Invoke-RestMethod -Uri 'https://api.github.com/repos/actions/runner/releases/latest' -Headers @{'User-Agent'='ECTOS'}
$asset=$release.assets | Where-Object {$_.name -match '^actions-runner-win-x64-.*\.zip$'} | Select-Object -First 1
if(-not $asset){throw 'RUNNER_WINDOWS_X64_ASSET_NOT_FOUND'}
New-Item -ItemType Directory -Force -Path $RunnerRoot|Out-Null
$zip=Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
Expand-Archive -LiteralPath $zip -DestinationPath $RunnerRoot -Force
Push-Location $RunnerRoot
try{
  & .\config.cmd --unattended --url "https://github.com/$RepoFullName" --token $token --name $RunnerName --labels $Labels --work _work --replace
  if($LASTEXITCODE -ne 0){throw "RUNNER_CONFIG_EXIT=$LASTEXITCODE"}
  & .\svc.cmd install
  if($LASTEXITCODE -ne 0){throw "RUNNER_SERVICE_INSTALL_EXIT=$LASTEXITCODE"}
  & .\svc.cmd start
  if($LASTEXITCODE -ne 0){throw "RUNNER_SERVICE_START_EXIT=$LASTEXITCODE"}
} finally {Pop-Location}
Write-Host "RUNNER_BOOTSTRAP=PASS"
Write-Host "REPOSITORY=$RepoFullName"
Write-Host "RUNNER_NAME=$RunnerName"
Write-Host "RUNNER_ROOT=$RunnerRoot"
Write-Host "PS51_VERSION=$($PSVersionTable.PSVersion)"
