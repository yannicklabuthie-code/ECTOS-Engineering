[CmdletBinding()]
param([switch]$SkipInstall,[switch]$RequirePS7)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$sample=Join-Path $root 'fixtures/sample-package'
$results=Join-Path $root 'results/native_windows_selfqual'
if(Test-Path -LiteralPath $results){Remove-Item -LiteralPath $results -Recurse -Force}
New-Item -ItemType Directory -Force -Path $results|Out-Null
if(-not $SkipInstall){
  & (Join-Path $root 'tools/Initialize-ECTOSEngineeringTools.ps1') -InstallMissing | Tee-Object -FilePath (Join-Path $results 'TOOL_BOOTSTRAP.txt')
}
$localModules=Join-Path $root 'tools/modules'
if(Test-Path -LiteralPath $localModules){$env:PSModulePath=$localModules+[IO.Path]::PathSeparator+$env:PSModulePath}
$runner=Join-Path $root 'RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1'
$manifestPath=Join-Path $sample 'ectos-package-manifest.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$runtimeClaims=@($manifest.target_runtime)+@($manifest.supported_powershell_version)
$manifestClaimsPS7=[bool]($runtimeClaims | Where-Object { $_ -match '(^|[^0-9])7([\.+]|$)|PowerShell7|pwsh' })
# Main rule: PS7 is mandatory only where compatibility is claimed by the target package.
# -RequirePS7 may request an additional environment proof, but it must not alter the sample package's declared compatibility contract.
$ps7RequiredForTarget=$manifestClaimsPS7
Write-Host ('TARGET_MANIFEST_PS7_CLAIM=' + $(if($manifestClaimsPS7){'YES'}else{'NO'}))
Write-Host ('PS7_REQUIRED_FOR_TARGET=' + $(if($ps7RequiredForTarget){'YES'}else{'NO'}))
Write-Host ('PS7_ADDITIONAL_ENVIRONMENT_PROOF_REQUESTED=' + $(if($RequirePS7){'YES'}else{'NO'}))

# Always prove Windows PowerShell 5.1 using its native executable.
$ps51Args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-TargetPackageRoot',$sample,'-ResultsRoot',$results)
if($ps7RequiredForTarget){$ps51Args += '-ClaimPS7Compatibility'}
& powershell.exe @ps51Args
$ps51Exit=$LASTEXITCODE
if($ps51Exit -ne 0){throw ('PS51_SELFQUAL_PROCESS_FAILED_EXIT_' + $ps51Exit)}

$pwsh=Get-Command pwsh.exe -ErrorAction SilentlyContinue
$ps7Exit=$null
if($pwsh){
  $ps7Args=@('-NoProfile','-File',$runner,'-TargetPackageRoot',$sample,'-ResultsRoot',$results)
  if($ps7RequiredForTarget){$ps7Args += '-ClaimPS7Compatibility'}
  & $pwsh.Source @ps7Args
  $ps7Exit=$LASTEXITCODE
  if($ps7RequiredForTarget -and $ps7Exit -ne 0){throw ('PS7_TARGET_SELFQUAL_PROCESS_FAILED_EXIT_' + $ps7Exit)}
} elseif($ps7RequiredForTarget) {
  throw 'PS7_REQUIRED_BY_TARGET_MANIFEST_BUT_PWSH_NOT_FOUND'
}

# Recompute readiness on PS5.1 after optional PS7 evidence has been added.
$readinessScript=Join-Path $root 'gates/Get-ECTOSReadiness.ps1'
$readinessArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$readinessScript,'-TargetPackageRoot',$sample,'-ResultsRoot',$results)
if($ps7RequiredForTarget){$readinessArgs += '-RequirePS7'}
& powershell.exe @readinessArgs | Out-Host
if($LASTEXITCODE -ne 0){throw ('READINESS_RECOMPUTE_FAILED_EXIT_' + $LASTEXITCODE)}

$readinessPath=Join-Path $results 'READINESS.json'
if(-not(Test-Path -LiteralPath $readinessPath)){throw 'READINESS_NOT_PRODUCED'}
$readiness=Get-Content -LiteralPath $readinessPath -Raw | ConvertFrom-Json
[pscustomobject]@{
  SELFQUAL='ECTOS_DEV_PHASE_0_PHASE_1_NATIVE_WINDOWS_SELFQUAL_V03'
  PS51_PROCESS_EXIT=$ps51Exit
  PS7_PROCESS_EXIT=$ps7Exit
  PS7_PRESENT=[bool]$pwsh
  PS7_REQUIRED_BY_TARGET=$ps7RequiredForTarget
  PS7_ADDITIONAL_ENVIRONMENT_PROOF_REQUESTED=[bool]$RequirePS7
  DEV_READY=$readiness.dev_ready
  PACKAGE_READY=$readiness.package_ready
  QUALIFICATION_READY=$readiness.qualification_ready
  RESULT_ROOT=$results
}
