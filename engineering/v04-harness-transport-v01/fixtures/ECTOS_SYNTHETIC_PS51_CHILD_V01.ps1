[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ControlPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [AllowEmptyString()][string]$Text
    )
    $encoding=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$Text,$encoding)
}

if($PSVersionTable.PSEdition -cne 'Desktop'){ throw 'SYNTHETIC_CHILD_NATIVE_EDITION_NOT_DESKTOP' }
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){ throw 'SYNTHETIC_CHILD_NATIVE_VERSION_NOT_5_1' }
if(-not(Test-Path -LiteralPath $ControlPath -PathType Leaf)){ throw 'SYNTHETIC_CONTROL_NOT_FOUND' }
if(-not(Test-Path -LiteralPath $OutputDirectory -PathType Container)){ throw 'SYNTHETIC_OUTPUT_DIRECTORY_NOT_FOUND' }

$control=Get-Content -LiteralPath $ControlPath -Raw -ErrorAction Stop|ConvertFrom-Json
$stdoutText=''
$stderrText=''
$exitCode=0
$sleepSeconds=0
$artifactName=''
$artifactText=''

if($null -ne $control.stdout_text){ $stdoutText=[string]$control.stdout_text }
if($null -ne $control.stderr_text){ $stderrText=[string]$control.stderr_text }
if($null -ne $control.exit_code){ $exitCode=[int]$control.exit_code }
if($null -ne $control.sleep_seconds){ $sleepSeconds=[int]$control.sleep_seconds }
if($null -ne $control.artifact_name){ $artifactName=[string]$control.artifact_name }
if($null -ne $control.artifact_text){ $artifactText=[string]$control.artifact_text }

[Console]::Out.WriteLine('SYNTHETIC_CHILD_PSEDITION='+$PSVersionTable.PSEdition)
[Console]::Out.WriteLine('SYNTHETIC_CHILD_PSVERSION='+$PSVersionTable.PSVersion.ToString())
if($stdoutText.Length -gt 0){ [Console]::Out.WriteLine($stdoutText) }
if($stderrText.Length -gt 0){ [Console]::Error.WriteLine($stderrText) }

if($sleepSeconds -gt 0){ Start-Sleep -Seconds $sleepSeconds }

if($artifactName.Length -gt 0){
    if([IO.Path]::GetFileName($artifactName) -cne $artifactName){ throw 'SYNTHETIC_ARTIFACT_NAME_MUST_BE_LEAF' }
    $artifactPath=Join-Path $OutputDirectory $artifactName
    Write-Utf8NoBom -Path $artifactPath -Text $artifactText
}

exit $exitCode
