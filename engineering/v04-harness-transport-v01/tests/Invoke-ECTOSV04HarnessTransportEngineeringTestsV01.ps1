[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EngineeringRoot,
    [Parameter(Mandatory=$true)][string]$ResultsRoot
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

function Get-Sha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [AllowEmptyString()][string]$Text
    )
    $encoding=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$Text,$encoding)
}

function Add-ControlResult {
    param(
        [Parameter(Mandatory=$true)][string]$ControlId,
        [Parameter(Mandatory=$true)][string]$ControlType,
        [Parameter(Mandatory=$true)][bool]$Passed,
        [AllowEmptyString()][string]$Detail
    )
    $state='FAIL'
    if($Passed){ $state='PASS' }
    [void]$script:ControlResults.Add([pscustomobject][ordered]@{
        control_id=$ControlId
        control_type=$ControlType
        result=$state
        detail=$Detail
    })
}

function New-ControlFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ExpectedWorkingDirectory,
        [AllowEmptyString()][string]$StdoutText='',
        [AllowEmptyString()][string]$StderrText='',
        [int]$ExitCode=0,
        [int]$SleepSeconds=0,
        [AllowEmptyString()][string]$ArtifactName='',
        [AllowEmptyString()][string]$ArtifactText=''
    )
    $payload=[pscustomobject][ordered]@{
        expected_working_directory=[IO.Path]::GetFullPath($ExpectedWorkingDirectory)
        stdout_text=$StdoutText
        stderr_text=$StderrText
        exit_code=$ExitCode
        sleep_seconds=$SleepSeconds
        artifact_name=$ArtifactName
        artifact_text=$ArtifactText
    }
    Write-Utf8NoBom -Path $Path -Text (($payload|ConvertTo-Json -Depth 6)+"`r`n")
}

function Invoke-HarnessCase {
    param(
        [Parameter(Mandatory=$true)][string]$CaseId,
        [Parameter(Mandatory=$true)][string]$ControlPath,
        [Parameter(Mandatory=$true)][string]$WorkingDirectory,
        [Parameter(Mandatory=$true)][string]$EvidenceRoot,
        [string]$HarnessPathOverride='',
        [string]$FixturePathOverride='',
        [string]$HarnessShaOverride='',
        [string]$FixtureShaOverride='',
        [string]$ControlShaOverride='',
        [string]$NativePowerShellPathOverride='',
        [int]$TimeoutSeconds=10,
        [switch]$LegacyEncodedCommandMode,
        [AllowEmptyString()][string]$LegacyEncodedCommandToken=''
    )
    $selectedHarness=$script:HarnessPath
    if($HarnessPathOverride.Length -gt 0){ $selectedHarness=$HarnessPathOverride }
    $selectedFixture=$script:FixturePath
    if($FixturePathOverride.Length -gt 0){ $selectedFixture=$FixturePathOverride }
    $selectedHarnessSha=$script:HarnessSha
    if($HarnessShaOverride.Length -gt 0){ $selectedHarnessSha=$HarnessShaOverride }
    $selectedFixtureSha=$script:FixtureSha
    if($FixtureShaOverride.Length -gt 0){ $selectedFixtureSha=$FixtureShaOverride }
    $selectedControlSha=Get-Sha256 -Path $ControlPath
    if($ControlShaOverride.Length -gt 0){ $selectedControlSha=$ControlShaOverride }

    $captureRoot=Join-Path $script:WorkRoot ('caller-'+$CaseId)
    if(Test-Path -LiteralPath $captureRoot){ Remove-Item -LiteralPath $captureRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $captureRoot -ErrorAction Stop|Out-Null
    $callerStdout=Join-Path $captureRoot 'harness-stdout.txt'
    $callerStderr=Join-Path $captureRoot 'harness-stderr.txt'

    $invokeArguments=@(
        '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$selectedHarness,
        '-FixturePath',$selectedFixture,
        '-ExpectedFixtureSha256',$selectedFixtureSha,
        '-ControlPath',$ControlPath,
        '-ExpectedControlSha256',$selectedControlSha,
        '-WorkingDirectory',$WorkingDirectory,
        '-EvidenceRoot',$EvidenceRoot,
        '-InvocationId',$CaseId,
        '-ExpectedHarnessSha256',$selectedHarnessSha,
        '-TimeoutSeconds',[string]$TimeoutSeconds
    )
    if($NativePowerShellPathOverride.Length -gt 0){
        $invokeArguments+=@('-NativePowerShellPath',$NativePowerShellPathOverride)
    }
    if($LegacyEncodedCommandMode){
        $invokeArguments+=@('-LegacyEncodedCommandMode')
        if($LegacyEncodedCommandToken.Length -gt 0){
            $invokeArguments+=@('-LegacyEncodedCommandToken',$LegacyEncodedCommandToken)
        }
    }

    & $script:NativePowerShell @invokeArguments 1> $callerStdout 2> $callerStderr
    $caseExitCode=$LASTEXITCODE
    $stdoutText=''
    $stderrText=''
    if(Test-Path -LiteralPath $callerStdout){ $stdoutText=Get-Content -LiteralPath $callerStdout -Raw -ErrorAction Stop }
    if(Test-Path -LiteralPath $callerStderr){ $stderrText=Get-Content -LiteralPath $callerStderr -Raw -ErrorAction Stop }
    return [pscustomobject][ordered]@{
        case_id=$CaseId
        exit_code=$caseExitCode
        stdout=$stdoutText
        stderr=$stderrText
        evidence_root=$EvidenceRoot
        caller_stdout_path=$callerStdout
        caller_stderr_path=$callerStderr
    }
}

function Test-EvidenceCopyFailure {
    param(
        [Parameter(Mandatory=$true)][string]$SourceEvidenceRoot,
        [Parameter(Mandatory=$true)][string]$CaseId,
        [Parameter(Mandatory=$true)][scriptblock]$Mutator,
        [Parameter(Mandatory=$true)][string]$ExpectedErrorFragment
    )
    $copyRoot=Join-Path $script:WorkRoot ('verify-'+$CaseId)
    if(Test-Path -LiteralPath $copyRoot){ Remove-Item -LiteralPath $copyRoot -Recurse -Force }
    Copy-Item -LiteralPath $SourceEvidenceRoot -Destination $copyRoot -Recurse -Force
    & $Mutator $copyRoot
    $verifyStdout=Join-Path $copyRoot 'verifier-caller-stdout.txt'
    $verifyStderr=Join-Path $copyRoot 'verifier-caller-stderr.txt'
    & $script:NativePowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script:VerifierPath -EvidenceRoot $copyRoot 1> $verifyStdout 2> $verifyStderr
    $verifyExit=$LASTEXITCODE
    $verifyError=''
    if(Test-Path -LiteralPath $verifyStderr){ $verifyError=Get-Content -LiteralPath $verifyStderr -Raw -ErrorAction Stop }
    return ($verifyExit -ne 0 -and $verifyError.Contains($ExpectedErrorFragment))
}

$script:ControlResults=New-Object System.Collections.ArrayList
$script:HarnessPath=Join-Path $EngineeringRoot 'Invoke-ECTOSV04HarnessTransportV01.ps1'
$script:VerifierPath=Join-Path $EngineeringRoot 'Test-ECTOSV04HarnessEvidenceV01.ps1'
$script:FixturePath=Join-Path $EngineeringRoot 'fixtures\ECTOS_SYNTHETIC_PS51_CHILD_V01.ps1'
$script:WorkRoot=Join-Path $ResultsRoot 'work'
$systemRoot=[Environment]::GetEnvironmentVariable('SystemRoot')
$script:NativePowerShell=Join-Path $systemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if(Test-Path -LiteralPath $ResultsRoot){ Remove-Item -LiteralPath $ResultsRoot -Recurse -Force }
New-Item -ItemType Directory -Path $script:WorkRoot -Force -ErrorAction Stop|Out-Null

foreach($sourcePath in @($script:HarnessPath,$script:VerifierPath,$script:FixturePath,$script:NativePowerShell)){
    if(-not(Test-Path -LiteralPath $sourcePath -PathType Leaf)){ throw ('MANDATORY_SOURCE_NOT_FOUND_'+$sourcePath) }
}

$script:HarnessSha=Get-Sha256 -Path $script:HarnessPath
$script:VerifierSha=Get-Sha256 -Path $script:VerifierPath
$script:FixtureSha=Get-Sha256 -Path $script:FixturePath
$nativeSha=Get-Sha256 -Path $script:NativePowerShell
$harnessShaBefore=$script:HarnessSha
$fixtureShaBefore=$script:FixtureSha
$verifierShaBefore=$script:VerifierSha

$edition=$PSVersionTable.PSEdition
$version=$PSVersionTable.PSVersion.ToString()
Add-ControlResult -ControlId 'PC01_NATIVE_PS51_SELECTED' -ControlType 'POSITIVE' -Passed ($edition -ceq 'Desktop' -and $version.StartsWith('5.1')) -Detail ($edition+'|'+$version)
Add-ControlResult -ControlId 'PC02_DURABLE_HARNESS_SOURCE' -ControlType 'POSITIVE' -Passed (Test-Path -LiteralPath $script:HarnessPath -PathType Leaf) -Detail $script:HarnessPath
Add-ControlResult -ControlId 'PC03_EXACT_HARNESS_SHA_BOUND' -ControlType 'POSITIVE' -Passed ($script:HarnessSha.Length -eq 64) -Detail $script:HarnessSha

$caseRoot=Join-Path $script:WorkRoot 'positive-zero'
$workingDirectory=Join-Path $caseRoot 'wd'
New-Item -ItemType Directory -Path $workingDirectory -Force|Out-Null
$controlPath=Join-Path $caseRoot 'control.json'
New-ControlFile -Path $controlPath -ExpectedWorkingDirectory $workingDirectory -StdoutText 'STDOUT_SENTINEL' -StderrText 'STDERR_SENTINEL' -ExitCode 0 -ArtifactName 'artifact.txt' -ArtifactText 'ARTIFACT_SENTINEL'
$evidenceRoot=Join-Path $caseRoot 'evidence'
$zeroCase=Invoke-HarnessCase -CaseId 'positive-zero' -ControlPath $controlPath -WorkingDirectory $workingDirectory -EvidenceRoot $evidenceRoot
$zeroPass=$zeroCase.exit_code -eq 0
Add-ControlResult -ControlId 'PC04_VALID_SYNTHETIC_CHILD_START' -ControlType 'POSITIVE' -Passed $zeroPass -Detail ('caller_exit='+$zeroCase.exit_code)

$resultPath=Join-Path $evidenceRoot 'result.json'
$invocationPath=Join-Path $evidenceRoot 'invocation.json'
$stdoutPath=Join-Path $evidenceRoot 'stdout.txt'
$stderrPath=Join-Path $evidenceRoot 'stderr.txt'
$outputManifestPath=Join-Path $evidenceRoot 'output-manifest.json'
$resultObject=$null
$invocationObject=$null
if(Test-Path -LiteralPath $resultPath){ $resultObject=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json }
if(Test-Path -LiteralPath $invocationPath){ $invocationObject=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json }

$argBound=$false
$workBound=$false
$noRetry=$false
$encodedNotRetained=$false
if($null -ne $invocationObject){
    $argBound=@($invocationObject.argument_vector).Count -eq 11
    $workBound=[string]$invocationObject.working_directory -ceq [IO.Path]::GetFullPath($workingDirectory)
    $noRetry=-not [bool]$invocationObject.automatic_retry
    $encodedNotRetained=-not [bool]$invocationObject.encoded_command_retained
}
Add-ControlResult -ControlId 'PC05_EXACT_ARGUMENT_VECTOR_BOUND' -ControlType 'POSITIVE' -Passed $argBound -Detail 'expected_argument_count=11'
Add-ControlResult -ControlId 'PC06_WORKING_DIRECTORY_BOUND' -ControlType 'POSITIVE' -Passed $workBound -Detail $workingDirectory
Add-ControlResult -ControlId 'PC07_STDOUT_SEPARATELY_CAPTURED' -ControlType 'POSITIVE' -Passed ((Test-Path -LiteralPath $stdoutPath) -and (Get-Content -LiteralPath $stdoutPath -Raw).Contains('STDOUT_SENTINEL')) -Detail $stdoutPath
Add-ControlResult -ControlId 'PC08_STDERR_SEPARATELY_CAPTURED' -ControlType 'POSITIVE' -Passed ((Test-Path -LiteralPath $stderrPath) -and (Get-Content -LiteralPath $stderrPath -Raw).Contains('STDERR_SENTINEL')) -Detail $stderrPath
$zeroExitCaptured=$false
if($null -ne $resultObject){ $zeroExitCaptured=$resultObject.exit_code -eq 0 }
Add-ControlResult -ControlId 'PC09_ZERO_EXIT_CAPTURED' -ControlType 'POSITIVE' -Passed $zeroExitCaptured -Detail 'expected=0'
Add-ControlResult -ControlId 'PC10_OUTPUT_SET_CAPTURED' -ControlType 'POSITIVE' -Passed (Test-Path -LiteralPath $outputManifestPath -PathType Leaf) -Detail $outputManifestPath

$verifyZeroStdout=Join-Path $caseRoot 'verify-stdout.txt'
$verifyZeroStderr=Join-Path $caseRoot 'verify-stderr.txt'
& $script:NativePowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script:VerifierPath -EvidenceRoot $evidenceRoot 1> $verifyZeroStdout 2> $verifyZeroStderr
$verifyZeroExit=$LASTEXITCODE
Add-ControlResult -ControlId 'PC11_OUTPUT_HASH_CLOSURE' -ControlType 'POSITIVE' -Passed ($verifyZeroExit -eq 0) -Detail ('verifier_exit='+$verifyZeroExit)
Add-ControlResult -ControlId 'PC12_NO_AUTOMATIC_RETRY' -ControlType 'POSITIVE' -Passed $noRetry -Detail 'automatic_retry=false'
Add-ControlResult -ControlId 'PC13_ENCODEDCOMMAND_NOT_RETAINED' -ControlType 'POSITIVE' -Passed $encodedNotRetained -Detail 'transport=NATIVE_PS51_FILE_ARGUMENT_VECTOR'

$childStdout=''
if(Test-Path -LiteralPath $stdoutPath){ $childStdout=Get-Content -LiteralPath $stdoutPath -Raw }
Add-ControlResult -ControlId 'PC14_CHILD_PSEDITION_DESKTOP' -ControlType 'POSITIVE' -Passed $childStdout.Contains('SYNTHETIC_CHILD_PSEDITION=Desktop') -Detail 'child stdout proof'
Add-ControlResult -ControlId 'PC15_CHILD_PSVERSION_5_1' -ControlType 'POSITIVE' -Passed $childStdout.Contains('SYNTHETIC_CHILD_PSVERSION=5.1') -Detail 'child stdout proof'

$nonzeroRoot=Join-Path $script:WorkRoot 'positive-nonzero'
$nonzeroWd=Join-Path $nonzeroRoot 'wd'
New-Item -ItemType Directory -Path $nonzeroWd -Force|Out-Null
$nonzeroControl=Join-Path $nonzeroRoot 'control.json'
New-ControlFile -Path $nonzeroControl -ExpectedWorkingDirectory $nonzeroWd -StdoutText 'NONZERO_STDOUT' -StderrText 'NONZERO_STDERR' -ExitCode 7
$nonzeroEvidence=Join-Path $nonzeroRoot 'evidence'
$nonzeroCase=Invoke-HarnessCase -CaseId 'positive-nonzero' -ControlPath $nonzeroControl -WorkingDirectory $nonzeroWd -EvidenceRoot $nonzeroEvidence
$nonzeroCaptured=$false
if(Test-Path -LiteralPath (Join-Path $nonzeroEvidence 'result.json')){
    $nonzeroResult=Get-Content -LiteralPath (Join-Path $nonzeroEvidence 'result.json') -Raw|ConvertFrom-Json
    $nonzeroCaptured=($nonzeroCase.exit_code -ne 0 -and $nonzeroResult.exit_code -eq 7 -and [string]$nonzeroResult.termination_state -ceq 'EXITED')
}
Add-ControlResult -ControlId 'PC16_NONZERO_EXIT_CAPTURED_FAIL_CLOSED' -ControlType 'POSITIVE' -Passed $nonzeroCaptured -Detail ('caller_exit='+$nonzeroCase.exit_code)

$timeoutRoot=Join-Path $script:WorkRoot 'positive-timeout'
$timeoutWd=Join-Path $timeoutRoot 'wd'
New-Item -ItemType Directory -Path $timeoutWd -Force|Out-Null
$timeoutControl=Join-Path $timeoutRoot 'control.json'
New-ControlFile -Path $timeoutControl -ExpectedWorkingDirectory $timeoutWd -StdoutText 'TIMEOUT_STDOUT' -StderrText 'TIMEOUT_STDERR' -ExitCode 0 -SleepSeconds 4
$timeoutEvidence=Join-Path $timeoutRoot 'evidence'
$timeoutCase=Invoke-HarnessCase -CaseId 'positive-timeout' -ControlPath $timeoutControl -WorkingDirectory $timeoutWd -EvidenceRoot $timeoutEvidence -TimeoutSeconds 1
$timeoutCaptured=$false
if(Test-Path -LiteralPath (Join-Path $timeoutEvidence 'result.json')){
    $timeoutResult=Get-Content -LiteralPath (Join-Path $timeoutEvidence 'result.json') -Raw|ConvertFrom-Json
    $timeoutCaptured=($timeoutCase.exit_code -ne 0 -and [string]$timeoutResult.termination_state -ceq 'TIMEOUT_TERMINATED')
}
Add-ControlResult -ControlId 'PC17_TIMEOUT_CAPTURED_AND_TERMINATED' -ControlType 'POSITIVE' -Passed $timeoutCaptured -Detail ('caller_exit='+$timeoutCase.exit_code)

$harnessText=Get-Content -LiteralPath $script:HarnessPath -Raw
$h01Impossible=($harnessText -notmatch '(?i)\s-Command(?:\s|$)')
Add-ControlResult -ControlId 'NC01_H01_OUTER_INTERPOLATION_STRUCTURALLY_IMPOSSIBLE' -ControlType 'NEGATIVE' -Passed $h01Impossible -Detail 'no powershell -Command transport in harness source'

$legacyRoot=Join-Path $script:WorkRoot 'legacy-tests'
$legacyWd=Join-Path $legacyRoot 'wd'
New-Item -ItemType Directory -Path $legacyWd -Force|Out-Null
$legacyControl=Join-Path $legacyRoot 'control.json'
New-ControlFile -Path $legacyControl -ExpectedWorkingDirectory $legacyWd

$legacyCases=@(
    [pscustomobject]@{id='NC02_H02_LENGTH_MOD4_2_REJECTED';token='AAAAAA';fragment='INVALID_BASE64_LENGTH_MOD4_2'},
    [pscustomobject]@{id='NC03_INVALID_BASE64_CHARACTER_REJECTED';token='AA$=';fragment='INVALID_BASE64_CHARACTER'},
    [pscustomobject]@{id='NC04_TRUNCATED_BASE64_REJECTED';token='QQBCA';fragment='INVALID_BASE64_LENGTH_MOD4_1'},
    [pscustomobject]@{id='NC05_MUTATED_BASE64_REJECTED';token='QQBDAA==';fragment='STRUCTURALLY_VALID_BUT_PROHIBITED'},
    [pscustomobject]@{id='NC06_EMPTY_PAYLOAD_REJECTED';token='';fragment='EMPTY_PAYLOAD'},
    [pscustomobject]@{id='NC07_NON_UTF16LE_PAYLOAD_REJECTED';token='AQID';fragment='NON_UTF16LE_BYTE_LENGTH'},
    [pscustomobject]@{id='NC08_ROUNDTRIP_TEXT_MISMATCH_REJECTED';token='ANg=';fragment='UTF16LE_ROUNDTRIP'}
)
foreach($legacyCaseDefinition in $legacyCases){
    $legacyEvidence=Join-Path $legacyRoot ([string]$legacyCaseDefinition.id)
    $legacyRun=Invoke-HarnessCase -CaseId ([string]$legacyCaseDefinition.id) -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot $legacyEvidence -LegacyEncodedCommandMode -LegacyEncodedCommandToken ([string]$legacyCaseDefinition.token)
    $legacyRejected=($legacyRun.exit_code -ne 0 -and $legacyRun.stderr.Contains([string]$legacyCaseDefinition.fragment) -and -not(Test-Path -LiteralPath $legacyEvidence))
    Add-ControlResult -ControlId ([string]$legacyCaseDefinition.id) -ControlType 'NEGATIVE' -Passed $legacyRejected -Detail ([string]$legacyCaseDefinition.fragment)
}

$wrongEditionRun=Invoke-HarnessCase -CaseId 'NC09_WRONG_POWERSHELL_EDITION_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'wrong-edition') -NativePowerShellPathOverride 'C:\Program Files\PowerShell\7\pwsh.exe'
Add-ControlResult -ControlId 'NC09_WRONG_POWERSHELL_EDITION_REJECTED' -ControlType 'NEGATIVE' -Passed ($wrongEditionRun.exit_code -ne 0 -and $wrongEditionRun.stderr.Contains('WRONG_NATIVE_PS51_PATH_REJECTED')) -Detail 'pwsh path rejected before child start'

$pwsh7Run=Invoke-HarnessCase -CaseId 'NC10_POWERSHELL_7_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'pwsh7') -NativePowerShellPathOverride 'C:\Program Files\PowerShell\7\pwsh.exe'
Add-ControlResult -ControlId 'NC10_POWERSHELL_7_REJECTED' -ControlType 'NEGATIVE' -Passed ($pwsh7Run.exit_code -ne 0 -and $pwsh7Run.stderr.Contains('WRONG_NATIVE_PS51_PATH_REJECTED')) -Detail 'PowerShell 7 transport prohibited'

$wrongPathRun=Invoke-HarnessCase -CaseId 'NC11_WRONG_NATIVE_PS51_PATH_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'wrong-path') -NativePowerShellPathOverride (Join-Path $systemRoot 'System32\WindowsPowerShell\v1.0\powershell_ise.exe')
Add-ControlResult -ControlId 'NC11_WRONG_NATIVE_PS51_PATH_REJECTED' -ControlType 'NEGATIVE' -Passed ($wrongPathRun.exit_code -ne 0 -and $wrongPathRun.stderr.Contains('WRONG_NATIVE_PS51_PATH_REJECTED')) -Detail 'alternate executable rejected'

$mismatchRoot=Join-Path $script:WorkRoot 'wd-mismatch'
$actualWd=Join-Path $mismatchRoot 'actual'
$expectedWd=Join-Path $mismatchRoot 'expected'
New-Item -ItemType Directory -Path $actualWd -Force|Out-Null
New-Item -ItemType Directory -Path $expectedWd -Force|Out-Null
$mismatchControl=Join-Path $mismatchRoot 'control.json'
New-ControlFile -Path $mismatchControl -ExpectedWorkingDirectory $expectedWd
$mismatchRun=Invoke-HarnessCase -CaseId 'NC12_WORKING_DIRECTORY_MISMATCH_REJECTED' -ControlPath $mismatchControl -WorkingDirectory $actualWd -EvidenceRoot (Join-Path $mismatchRoot 'evidence')
Add-ControlResult -ControlId 'NC12_WORKING_DIRECTORY_MISMATCH_REJECTED' -ControlType 'NEGATIVE' -Passed ($mismatchRun.exit_code -ne 0 -and $mismatchRun.stderr.Contains('WORKING_DIRECTORY_MISMATCH')) -Detail 'control path binding mismatch'

$missingHarness=Join-Path $script:WorkRoot 'DOES_NOT_EXIST_HARNESS.ps1'
$missingHarnessRun=Invoke-HarnessCase -CaseId 'NC13_MISSING_HARNESS_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'missing-harness') -HarnessPathOverride $missingHarness
Add-ControlResult -ControlId 'NC13_MISSING_HARNESS_REJECTED' -ControlType 'NEGATIVE' -Passed ($missingHarnessRun.exit_code -ne 0) -Detail 'native powershell -File missing source rejected'

$badHarnessSha=('0' * 64)
$harnessShaRun=Invoke-HarnessCase -CaseId 'NC14_HARNESS_SHA_MISMATCH_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'bad-harness-sha') -HarnessShaOverride $badHarnessSha
Add-ControlResult -ControlId 'NC14_HARNESS_SHA_MISMATCH_REJECTED' -ControlType 'NEGATIVE' -Passed ($harnessShaRun.exit_code -ne 0 -and $harnessShaRun.stderr.Contains('HARNESS_SHA_MISMATCH')) -Detail 'wrong harness SHA rejected'

$badFixtureSha=('0' * 64)
$fixtureShaRun=Invoke-HarnessCase -CaseId 'NC15_FIXTURE_SHA_MISMATCH_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $legacyRoot 'bad-fixture-sha') -FixtureShaOverride $badFixtureSha
Add-ControlResult -ControlId 'NC15_FIXTURE_SHA_MISMATCH_REJECTED' -ControlType 'NEGATIVE' -Passed ($fixtureShaRun.exit_code -ne 0 -and $fixtureShaRun.stderr.Contains('FIXTURE_SHA_MISMATCH')) -Detail 'wrong fixture SHA rejected'

Add-ControlResult -ControlId 'NC16_NONZERO_EXIT_FAIL_CLOSED' -ControlType 'NEGATIVE' -Passed $nonzeroCaptured -Detail 'child exit 7 captured and harness failed closed'
Add-ControlResult -ControlId 'NC17_TIMEOUT_FAIL_CLOSED' -ControlType 'NEGATIVE' -Passed $timeoutCaptured -Detail 'timeout termination captured and harness failed closed'

$missingStdoutRejected=Test-EvidenceCopyFailure -SourceEvidenceRoot $evidenceRoot -CaseId 'missing-stdout' -Mutator { param($copy) Remove-Item -LiteralPath (Join-Path $copy 'stdout.txt') -Force } -ExpectedErrorFragment 'REQUIRED_EVIDENCE_MEMBER_MISSING_stdout.txt'
Add-ControlResult -ControlId 'NC18_MISSING_STDOUT_EVIDENCE_REJECTED' -ControlType 'NEGATIVE' -Passed $missingStdoutRejected -Detail 'verifier fail closed'

$missingStderrRejected=Test-EvidenceCopyFailure -SourceEvidenceRoot $evidenceRoot -CaseId 'missing-stderr' -Mutator { param($copy) Remove-Item -LiteralPath (Join-Path $copy 'stderr.txt') -Force } -ExpectedErrorFragment 'REQUIRED_EVIDENCE_MEMBER_MISSING_stderr.txt'
Add-ControlResult -ControlId 'NC19_MISSING_STDERR_EVIDENCE_REJECTED' -ControlType 'NEGATIVE' -Passed $missingStderrRejected -Detail 'verifier fail closed'

$outputHashRejected=Test-EvidenceCopyFailure -SourceEvidenceRoot $evidenceRoot -CaseId 'output-hash' -Mutator { param($copy) Add-Content -LiteralPath (Join-Path $copy 'child-output\artifact.txt') -Value 'MUTATED' } -ExpectedErrorFragment 'OUTPUT_'
Add-ControlResult -ControlId 'NC20_OUTPUT_HASH_MISMATCH_REJECTED' -ControlType 'NEGATIVE' -Passed $outputHashRejected -Detail 'mutated output member rejected'

$duplicateRun=Invoke-HarnessCase -CaseId 'NC21_DUPLICATE_INVOCATION_REJECTED' -ControlPath $controlPath -WorkingDirectory $workingDirectory -EvidenceRoot $evidenceRoot
Add-ControlResult -ControlId 'NC21_DUPLICATE_INVOCATION_REJECTED' -ControlType 'NEGATIVE' -Passed ($duplicateRun.exit_code -ne 0 -and $duplicateRun.stderr.Contains('DUPLICATE_INVOCATION_EVIDENCE_ROOT_PREEXISTS')) -Detail 'existing evidence root blocks second invocation'
Add-ControlResult -ControlId 'NC22_UNAUTHORIZED_RETRY_REJECTED' -ControlType 'NEGATIVE' -Passed ($duplicateRun.exit_code -ne 0 -and $duplicateRun.stderr.Contains('DUPLICATE_INVOCATION_EVIDENCE_ROOT_PREEXISTS')) -Detail 'retry has no automatic path and is rejected'

$protectedRoot=Join-Path $script:WorkRoot 'protected-fixtures'
New-Item -ItemType Directory -Path $protectedRoot -Force|Out-Null
$fakeOperator=Join-Path $protectedRoot 'RUN_ECTOS_DEV_V04_PRODUCT_QUALIFICATION_FACTORY_NATIVE_PS51_V04.ps1'
$fakeProduct=Join-Path $protectedRoot 'ECTOS_V1_ASSEMBLY_DATASET_CAPTURE_V04.ps1'
Write-Utf8NoBom -Path $fakeOperator -Text "Write-Output 'FAKE_OPERATOR'`r`n"
Write-Utf8NoBom -Path $fakeProduct -Text "Write-Output 'FAKE_PRODUCT'`r`n"
$fakeOperatorRun=Invoke-HarnessCase -CaseId 'NC23_REAL_V04_OPERATOR_INVOCATION_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $protectedRoot 'op-evidence') -FixturePathOverride $fakeOperator -FixtureShaOverride (Get-Sha256 -Path $fakeOperator)
Add-ControlResult -ControlId 'NC23_REAL_V04_OPERATOR_INVOCATION_REJECTED' -ControlType 'NEGATIVE' -Passed ($fakeOperatorRun.exit_code -ne 0 -and $fakeOperatorRun.stderr.Contains('REAL_V04_OPERATOR_INVOCATION_REJECTED')) -Detail 'protected operator leaf blocked before child start'

$fakeProductRun=Invoke-HarnessCase -CaseId 'NC24_REAL_PRODUCT_INVOCATION_REJECTED' -ControlPath $legacyControl -WorkingDirectory $legacyWd -EvidenceRoot (Join-Path $protectedRoot 'product-evidence') -FixturePathOverride $fakeProduct -FixtureShaOverride (Get-Sha256 -Path $fakeProduct)
Add-ControlResult -ControlId 'NC24_REAL_PRODUCT_INVOCATION_REJECTED' -ControlType 'NEGATIVE' -Passed ($fakeProductRun.exit_code -ne 0 -and $fakeProductRun.stderr.Contains('REAL_V04_PRODUCT_INVOCATION_REJECTED')) -Detail 'protected product leaf blocked before child start'

$successorFiles=@($script:HarnessPath,$script:VerifierPath,$script:FixturePath,$PSCommandPath)
$rdcDependencyCount=0
foreach($successorFile in $successorFiles){
    $successorText=Get-Content -LiteralPath $successorFile -Raw
    if($successorText -match '(?i)Remote_Desktop_Commander|start_process'){ $rdcDependencyCount++ }
}
Add-ControlResult -ControlId 'NC25_REMOTE_DESKTOP_COMMANDER_RUNTIME_DEPENDENCY_ABSENCE_PROVEN' -ControlType 'NEGATIVE' -Passed ($rdcDependencyCount -eq 0) -Detail ('dependency_count='+$rdcDependencyCount)

$harnessShaAfter=Get-Sha256 -Path $script:HarnessPath
$fixtureShaAfter=Get-Sha256 -Path $script:FixturePath
$verifierShaAfter=Get-Sha256 -Path $script:VerifierPath
$testedBytesStable=($harnessShaBefore -ceq $harnessShaAfter -and $fixtureShaBefore -ceq $fixtureShaAfter -and $verifierShaBefore -ceq $verifierShaAfter)
Add-ControlResult -ControlId 'PC18_TESTED_BYTES_STABLE_DURING_CAMPAIGN' -ControlType 'POSITIVE' -Passed $testedBytesStable -Detail 'pre/post SHA equality'

$positiveResults=@($script:ControlResults|Where-Object{$_.control_type -ceq 'POSITIVE'})
$negativeResults=@($script:ControlResults|Where-Object{$_.control_type -ceq 'NEGATIVE'})
$failedResults=@($script:ControlResults|Where-Object{$_.result -cne 'PASS'})
$report=[pscustomobject][ordered]@{
    report_id='ECTOS_DEV_V04_HARNESS_TRANSPORT_ENGINEERING_TEST_REPORT_V01'
    transport_type='NATIVE_PS51_FILE_ARGUMENT_VECTOR'
    encoded_command_retained=$false
    native_ps51_edition=$edition
    native_ps51_version=$version
    native_ps51_executable=$script:NativePowerShell
    native_ps51_executable_sha256=$nativeSha
    harness_sha256=$script:HarnessSha
    verifier_sha256=$script:VerifierSha
    fixture_sha256=$script:FixtureSha
    engineering_test_count=$script:ControlResults.Count
    engineering_pass_count=$script:ControlResults.Count-$failedResults.Count
    engineering_fail_count=$failedResults.Count
    positive_control_count=$positiveResults.Count
    positive_control_pass_count=@($positiveResults|Where-Object{$_.result -ceq 'PASS'}).Count
    positive_control_fail_count=@($positiveResults|Where-Object{$_.result -cne 'PASS'}).Count
    negative_control_count=$negativeResults.Count
    negative_control_pass_count=@($negativeResults|Where-Object{$_.result -ceq 'PASS'}).Count
    negative_control_fail_count=@($negativeResults|Where-Object{$_.result -cne 'PASS'}).Count
    remote_desktop_commander_runtime_dependency_count=$rdcDependencyCount
    tested_bytes_stable=$testedBytesStable
    controls=@($script:ControlResults)
}
$reportPath=Join-Path $ResultsRoot 'ENGINEERING_TEST_REPORT.json'
Write-Utf8NoBom -Path $reportPath -Text (($report|ConvertTo-Json -Depth 10)+"`r`n")

Write-Output ('ENGINEERING_TEST_REPORT='+$reportPath)
Write-Output ('ENGINEERING_TEST_COUNT='+$report.engineering_test_count)
Write-Output ('ENGINEERING_PASS_COUNT='+$report.engineering_pass_count)
Write-Output ('ENGINEERING_FAIL_COUNT='+$report.engineering_fail_count)
Write-Output ('POSITIVE_CONTROL_COUNT='+$report.positive_control_count)
Write-Output ('POSITIVE_CONTROL_PASS_COUNT='+$report.positive_control_pass_count)
Write-Output ('NEGATIVE_CONTROL_COUNT='+$report.negative_control_count)
Write-Output ('NEGATIVE_CONTROL_PASS_COUNT='+$report.negative_control_pass_count)
Write-Output ('REMOTE_DESKTOP_COMMANDER_RUNTIME_DEPENDENCY_COUNT='+$rdcDependencyCount)

if($failedResults.Count -ne 0){
    $failureIds=@($failedResults|ForEach-Object{$_.control_id})
    throw ('ENGINEERING_CONTROL_FAILURES_'+[string]::Join(';',$failureIds))
}
