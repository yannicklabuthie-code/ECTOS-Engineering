[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [Parameter(Mandatory=$true)][string]$ExpectedFixtureSha256,
    [Parameter(Mandatory=$true)][string]$ControlPath,
    [Parameter(Mandatory=$true)][string]$ExpectedControlSha256,
    [Parameter(Mandatory=$true)][string]$WorkingDirectory,
    [Parameter(Mandatory=$true)][string]$EvidenceRoot,
    [Parameter(Mandatory=$true)][string]$InvocationId,
    [Parameter(Mandatory=$true)][string]$ExpectedHarnessSha256,
    [int]$TimeoutSeconds=15,
    [string]$NativePowerShellPath='',
    [switch]$LegacyEncodedCommandMode,
    [AllowEmptyString()][string]$LegacyEncodedCommandToken=''
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

function Quote-WindowsArgument {
    param([AllowEmptyString()][string]$Value)
    if($Value.Length -eq 0){ return '""' }
    if($Value -notmatch '[\s"]'){ return $Value }
    $builder=New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $slashCount=0
    foreach($character in $Value.ToCharArray()){
        if($character -eq '\'){
            $slashCount++
            continue
        }
        if($character -eq '"'){
            if($slashCount -gt 0){ [void]$builder.Append(('\' * ($slashCount * 2))) }
            [void]$builder.Append('"')
            $slashCount=0
            continue
        }
        if($slashCount -gt 0){
            [void]$builder.Append(('\' * $slashCount))
            $slashCount=0
        }
        [void]$builder.Append($character)
    }
    if($slashCount -gt 0){ [void]$builder.Append(('\' * ($slashCount * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Get-LegacyEncodedCommandClassification {
    param([AllowEmptyString()][string]$Token)
    if([string]::IsNullOrEmpty($Token)){ return 'EMPTY_PAYLOAD' }
    if($Token -notmatch '^[A-Za-z0-9+/=]+$'){ return 'INVALID_BASE64_CHARACTER' }
    if(($Token.Length % 4) -ne 0){ return ('INVALID_BASE64_LENGTH_MOD4_'+($Token.Length % 4)) }
    try {
        $decoded=[Convert]::FromBase64String($Token)
    } catch {
        return 'INVALID_BASE64_DECODE'
    }
    if(($decoded.Length % 2) -ne 0){ return 'NON_UTF16LE_BYTE_LENGTH' }
    $text=[Text.Encoding]::Unicode.GetString($decoded)
    $roundTrip=[Text.Encoding]::Unicode.GetBytes($text)
    if($roundTrip.Length -ne $decoded.Length){ return 'UTF16LE_ROUNDTRIP_LENGTH_MISMATCH' }
    for($index=0;$index -lt $decoded.Length;$index++){
        if($decoded[$index] -ne $roundTrip[$index]){ return 'UTF16LE_ROUNDTRIP_BYTE_MISMATCH' }
    }
    return 'STRUCTURALLY_VALID_BUT_PROHIBITED'
}

if($LegacyEncodedCommandMode){
    $legacyClass=Get-LegacyEncodedCommandClassification -Token $LegacyEncodedCommandToken
    throw ('ENCODEDCOMMAND_TRANSPORT_PROHIBITED_'+$legacyClass)
}

$resolvedHarness=[IO.Path]::GetFullPath($PSCommandPath)
$actualHarnessSha=Get-Sha256 -Path $resolvedHarness
if($actualHarnessSha -cne $ExpectedHarnessSha256.ToUpperInvariant()){
    throw ('HARNESS_SHA_MISMATCH_EXPECTED_'+$ExpectedHarnessSha256+'_ACTUAL_'+$actualHarnessSha)
}

if(-not(Test-Path -LiteralPath $FixturePath -PathType Leaf)){ throw 'FIXTURE_NOT_FOUND' }
if(-not(Test-Path -LiteralPath $ControlPath -PathType Leaf)){ throw 'CONTROL_NOT_FOUND' }
if(-not(Test-Path -LiteralPath $WorkingDirectory -PathType Container)){ throw 'WORKING_DIRECTORY_NOT_FOUND' }
if(Test-Path -LiteralPath $EvidenceRoot){ throw 'DUPLICATE_INVOCATION_EVIDENCE_ROOT_PREEXISTS' }

$resolvedFixture=[IO.Path]::GetFullPath($FixturePath)
$resolvedControl=[IO.Path]::GetFullPath($ControlPath)
$resolvedWorkingDirectory=[IO.Path]::GetFullPath($WorkingDirectory)
$fixtureLeaf=[IO.Path]::GetFileName($resolvedFixture)
if($fixtureLeaf -ceq 'RUN_ECTOS_DEV_V04_PRODUCT_QUALIFICATION_FACTORY_NATIVE_PS51_V04.ps1'){
    throw 'REAL_V04_OPERATOR_INVOCATION_REJECTED'
}
if($fixtureLeaf -ceq 'ECTOS_V1_ASSEMBLY_DATASET_CAPTURE_V04.ps1'){
    throw 'REAL_V04_PRODUCT_INVOCATION_REJECTED'
}
if($fixtureLeaf -cne 'ECTOS_SYNTHETIC_PS51_CHILD_V01.ps1'){
    throw ('UNAUTHORIZED_FIXTURE_FILENAME_'+$fixtureLeaf)
}

$fixtureSha=Get-Sha256 -Path $resolvedFixture
if($fixtureSha -cne $ExpectedFixtureSha256.ToUpperInvariant()){ throw 'FIXTURE_SHA_MISMATCH' }
$controlSha=Get-Sha256 -Path $resolvedControl
if($controlSha -cne $ExpectedControlSha256.ToUpperInvariant()){ throw 'CONTROL_SHA_MISMATCH' }

$control=Get-Content -LiteralPath $resolvedControl -Raw -ErrorAction Stop|ConvertFrom-Json
if($null -eq $control.expected_working_directory){ throw 'CONTROL_EXPECTED_WORKING_DIRECTORY_MISSING' }
$controlExpectedWorkingDirectory=[IO.Path]::GetFullPath([string]$control.expected_working_directory)
if($resolvedWorkingDirectory -cne $controlExpectedWorkingDirectory){ throw 'WORKING_DIRECTORY_MISMATCH' }

$systemRoot=[Environment]::GetEnvironmentVariable('SystemRoot')
$expectedNativePath=Join-Path $systemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if([string]::IsNullOrEmpty($NativePowerShellPath)){ $NativePowerShellPath=$expectedNativePath }
$resolvedNative=[IO.Path]::GetFullPath($NativePowerShellPath)
if($resolvedNative -cne [IO.Path]::GetFullPath($expectedNativePath)){ throw 'WRONG_NATIVE_PS51_PATH_REJECTED' }
if(-not(Test-Path -LiteralPath $resolvedNative -PathType Leaf)){ throw 'NATIVE_PS51_NOT_FOUND' }

New-Item -ItemType Directory -Path $EvidenceRoot -ErrorAction Stop|Out-Null
$childOutputRoot=Join-Path $EvidenceRoot 'child-output'
New-Item -ItemType Directory -Path $childOutputRoot -ErrorAction Stop|Out-Null
$stdoutPath=Join-Path $EvidenceRoot 'stdout.txt'
$stderrPath=Join-Path $EvidenceRoot 'stderr.txt'
$invocationPath=Join-Path $EvidenceRoot 'invocation.json'
$resultPath=Join-Path $EvidenceRoot 'result.json'
$outputManifestPath=Join-Path $EvidenceRoot 'output-manifest.json'

$argumentVector=@(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $resolvedFixture,
    '-ControlPath',
    $resolvedControl,
    '-OutputDirectory',
    $childOutputRoot
)
$renderedArguments=@($argumentVector|ForEach-Object{Quote-WindowsArgument -Value ([string]$_)}) -join ' '

$startTime=[DateTime]::UtcNow
$nativeSha=Get-Sha256 -Path $resolvedNative
$invocation=[pscustomobject][ordered]@{
    schema='ECTOS_V04_HARNESS_TRANSPORT_INVOCATION_V01'
    invocation_id=$InvocationId
    harness_path=$resolvedHarness
    harness_sha256=$actualHarnessSha
    fixture_path=$resolvedFixture
    fixture_sha256=$fixtureSha
    control_path=$resolvedControl
    control_sha256=$controlSha
    executable=$resolvedNative
    executable_sha256=$nativeSha
    argument_vector=@($argumentVector)
    rendered_arguments=$renderedArguments
    working_directory=$resolvedWorkingDirectory
    timeout_seconds=$TimeoutSeconds
    transport_type='NATIVE_PS51_FILE_ARGUMENT_VECTOR'
    encoded_command_retained=$false
    automatic_retry=$false
    start_time_utc=$startTime.ToString('o')
}
Write-Utf8NoBom -Path $invocationPath -Text (($invocation|ConvertTo-Json -Depth 8)+"`r`n")

$startInfo=New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName=$resolvedNative
$startInfo.Arguments=$renderedArguments
$startInfo.WorkingDirectory=$resolvedWorkingDirectory
$startInfo.UseShellExecute=$false
$startInfo.CreateNoWindow=$true
$startInfo.RedirectStandardOutput=$true
$startInfo.RedirectStandardError=$true

$process=New-Object System.Diagnostics.Process
$process.StartInfo=$startInfo
if(-not $process.Start()){ throw 'NATIVE_CHILD_START_FAILED' }
$stdoutTask=$process.StandardOutput.ReadToEndAsync()
$stderrTask=$process.StandardError.ReadToEndAsync()
$completed=$process.WaitForExit($TimeoutSeconds * 1000)
$terminationState='EXITED'
$exitCode=$null
if(-not $completed){
    $terminationState='TIMEOUT_TERMINATED'
    try { $process.Kill() } catch { }
    [void]$process.WaitForExit(5000)
} else {
    $process.WaitForExit()
    $exitCode=[int]$process.ExitCode
}
$stdout=[string]$stdoutTask.Result
$stderr=[string]$stderrTask.Result
$endTime=[DateTime]::UtcNow
Write-Utf8NoBom -Path $stdoutPath -Text $stdout
Write-Utf8NoBom -Path $stderrPath -Text $stderr

$outputMembers=New-Object System.Collections.ArrayList
foreach($outputFile in @(Get-ChildItem -LiteralPath $childOutputRoot -Recurse -File -ErrorAction Stop|Sort-Object FullName)){
    $relative=$outputFile.FullName.Substring($childOutputRoot.Length).TrimStart('\')
    [void]$outputMembers.Add([pscustomobject][ordered]@{
        relative_path=$relative
        size_bytes=[int64]$outputFile.Length
        sha256=Get-Sha256 -Path $outputFile.FullName
    })
}
$outputManifest=[pscustomobject][ordered]@{
    schema='ECTOS_V04_HARNESS_OUTPUT_MANIFEST_V01'
    member_count=$outputMembers.Count
    members=@($outputMembers)
}
Write-Utf8NoBom -Path $outputManifestPath -Text (($outputManifest|ConvertTo-Json -Depth 8)+"`r`n")

if(-not(Test-Path -LiteralPath $stdoutPath -PathType Leaf)){ throw 'MISSING_STDOUT_EVIDENCE' }
if(-not(Test-Path -LiteralPath $stderrPath -PathType Leaf)){ throw 'MISSING_STDERR_EVIDENCE' }
if(-not(Test-Path -LiteralPath $outputManifestPath -PathType Leaf)){ throw 'MISSING_OUTPUT_MANIFEST_EVIDENCE' }

$result=[pscustomobject][ordered]@{
    schema='ECTOS_V04_HARNESS_TRANSPORT_RESULT_V01'
    invocation_id=$InvocationId
    termination_state=$terminationState
    exit_code=$exitCode
    start_time_utc=$startTime.ToString('o')
    end_time_utc=$endTime.ToString('o')
    stdout_path=$stdoutPath
    stdout_sha256=Get-Sha256 -Path $stdoutPath
    stderr_path=$stderrPath
    stderr_sha256=Get-Sha256 -Path $stderrPath
    output_manifest_path=$outputManifestPath
    output_manifest_sha256=Get-Sha256 -Path $outputManifestPath
    invocation_path=$invocationPath
    invocation_sha256=Get-Sha256 -Path $invocationPath
    harness_sha256=$actualHarnessSha
    fixture_sha256=$fixtureSha
    control_sha256=$controlSha
    native_executable_sha256=$nativeSha
    working_directory=$resolvedWorkingDirectory
    timeout_seconds=$TimeoutSeconds
    encoded_command_retained=$false
    automatic_retry=$false
}
Write-Utf8NoBom -Path $resultPath -Text (($result|ConvertTo-Json -Depth 8)+"`r`n")

if($terminationState -ceq 'TIMEOUT_TERMINATED'){ throw 'CHILD_TIMEOUT_FAIL_CLOSED' }
if($exitCode -ne 0){ throw ('CHILD_NONZERO_EXIT_FAIL_CLOSED_'+$exitCode) }

Write-Output ('ECTOS_HARNESS_RESULT='+$resultPath)
Write-Output 'ECTOS_HARNESS_STATUS=PASS'
