[CmdletBinding()]
param([switch]$InstallMissing)
$ErrorActionPreference = 'Stop'
$moduleRoot = Join-Path $PSScriptRoot 'modules'
New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
$required = @(
  @{ Name='PSScriptAnalyzer'; MinimumVersion='1.22.0' },
  @{ Name='Pester'; MinimumVersion='6.0.0' }
)
foreach ($m in $required) {
  $found = Get-Module -ListAvailable -Name $m.Name | Where-Object { $_.Version -ge [version]$m.MinimumVersion } | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $found -and $InstallMissing) {
    Save-Module -Name $m.Name -MinimumVersion $m.MinimumVersion -Path $moduleRoot -Repository PSGallery -Force
    $env:PSModulePath = $moduleRoot + [IO.Path]::PathSeparator + $env:PSModulePath
    $found = Get-Module -ListAvailable -Name $m.Name | Sort-Object Version -Descending | Select-Object -First 1
  }
  [pscustomobject]@{ Tool=$m.Name; RequiredMinimum=$m.MinimumVersion; Found=([bool]$found); Version=if($found){$found.Version.ToString()}else{$null} }
}
