[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EvidenceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$entrypoint = Join-Path $toolRoot '01_TOOL\Invoke-ECTOSRawZipEvidenceParser.ps1'
$fixtureRoot = Join-Path $toolRoot '05_FIXTURES'
$testsPath = Join-Path $PSScriptRoot 'ECTOSRawZipParser.Tests.ps1'
. (Join-Path $PSScriptRoot 'ECTOSRawZipTestOracle.ps1')

$positiveManifest = Get-Content -LiteralPath (Join-Path $fixtureRoot 'POSITIVE_FIXTURE_MANIFEST_V01.json') -Raw | ConvertFrom-Json
$negativeManifest = Get-Content -LiteralPath (Join-Path $fixtureRoot 'NEGATIVE_FIXTURE_MANIFEST_V01.json') -Raw | ConvertFrom-Json
$errorCatalog = Get-Content -LiteralPath (Join-Path $toolRoot '04_ERRORS\ECTOS_RAW_ZIP_ERROR_CATALOG_V01.json') -Raw | ConvertFrom-Json
$powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$pesterModule = Get-Module -ListAvailable Pester | Where-Object { $_.Version -eq [version]'3.4.0' } | Select-Object -First 1

if([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'RZP_SELFTEST_RUNTIME_NOT_PS51'
}
if($null -eq $pesterModule) {
    throw 'RZP_SELFTEST_PESTER_3_4_0_REQUIRED'
}
if(Test-Path -LiteralPath $EvidenceRoot) { throw 'RZP_SELFTEST_EVIDENCE_ROOT_ALREADY_EXISTS' }
[void][IO.Directory]::CreateDirectory($EvidenceRoot)

function ConvertTo-ECTOSRawZipQuotedProcessArgument {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)
    return ('"' + $Value.Replace('"','\"') + '"')
}

function Invoke-ECTOSRawZipSelftestFixture {
    param(
        [Parameter(Mandatory=$true)][string]$FixtureId,
        [Parameter(Mandatory=$true)][string]$FixturePath,
        [Parameter(Mandatory=$true)][string]$EvidencePath,
        [int]$TimeoutMs = 30000
    )
    $stdoutPath = Join-Path $EvidenceRoot ($FixtureId + '.stdout.txt')
    $stderrPath = Join-Path $EvidenceRoot ($FixtureId + '.stderr.txt')
    $arguments = @(
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        (ConvertTo-ECTOSRawZipQuotedProcessArgument -Value $entrypoint),
        '-InputPath',
        (ConvertTo-ECTOSRawZipQuotedProcessArgument -Value $FixturePath),
        '-EvidencePath',
        (ConvertTo-ECTOSRawZipQuotedProcessArgument -Value $EvidencePath)
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $powerShellExe
    $startInfo.Arguments = ($arguments -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $completed = $process.WaitForExit($TimeoutMs)
    if(-not $completed) {
        try { $process.Kill() } catch { throw ('RZP_SELFTEST_TIMEOUT_TERMINATION_FAILED:' + $_.Exception.Message) }
        return [pscustomobject][ordered]@{exit_code=$null;timed_out=$true;stdout_path=$stdoutPath;stderr_path=$stderrPath}
    }
    $process.WaitForExit()
    $stdoutText = $process.StandardOutput.ReadToEnd()
    $stderrText = $process.StandardError.ReadToEnd()
    [System.IO.File]::WriteAllText($stdoutPath,$stdoutText,(New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($stderrPath,$stderrText,(New-Object System.Text.UTF8Encoding($false)))
    if(-not $process.HasExited) { throw 'RZP_SELFTEST_PROCESS_EXIT_NOT_OBSERVABLE' }
    [int]$observedExitCode = [int]$process.ExitCode
    $process.Dispose()
    return [pscustomobject][ordered]@{exit_code=$observedExitCode;timed_out=$false;stdout_path=$stdoutPath;stderr_path=$stderrPath}
}

$results = @()
foreach($fixture in @($positiveManifest.fixtures)) {
    $fixtureId = [string]$fixture.fixture_id
    $fixturePath = Join-Path (Join-Path $fixtureRoot 'POSITIVE') ([string]$fixture.file)
    $evidencePath = Join-Path $EvidenceRoot ($fixtureId+'.evidence.json')
    $processResult = Invoke-ECTOSRawZipSelftestFixture -FixtureId $fixtureId -FixturePath $fixturePath -EvidencePath $evidencePath
    $evidence = $null
    if(Test-Path -LiteralPath $evidencePath -PathType Leaf) { $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json }
    $actualStatus = 'NO_EVIDENCE'
    if($null -ne $evidence) { $actualStatus = [string]$evidence.parse_status }
    $pass = (-not $processResult.timed_out -and $processResult.exit_code -eq 0 -and $null -ne $evidence -and [string]$evidence.parse_status -eq 'PASS' -and [int]$evidence.failure_count -eq 0)
    $results += [pscustomobject][ordered]@{fixture_id=$fixtureId;expected='PASS';actual=$actualStatus;exit_code=$processResult.exit_code;timed_out=$processResult.timed_out;pass=$pass}
}

foreach($fixture in @($negativeManifest.fixtures)) {
    if(([string]$fixture.file).EndsWith('.json',[StringComparison]::OrdinalIgnoreCase)) { continue }
    $fixtureId = [string]$fixture.fixture_id
    $fixturePath = Join-Path (Join-Path $fixtureRoot 'NEGATIVE') ([string]$fixture.file)
    $evidencePath = Join-Path $EvidenceRoot ($fixtureId+'.evidence.json')
    $processResult = Invoke-ECTOSRawZipSelftestFixture -FixtureId $fixtureId -FixturePath $fixturePath -EvidencePath $evidencePath
    $evidence = $null
    if(Test-Path -LiteralPath $evidencePath -PathType Leaf) { $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json }
    $expectedRows = @($errorCatalog.errors | Where-Object { [string]$_.error_id -eq [string]$fixture.expected_failure_id })
    $expectedStage = $null
    if($expectedRows.Count -eq 1) { $expectedStage = [string]$expectedRows[0].failure_stage }
    $oraclePass = $false
    if($null -ne $evidence -and $null -ne $expectedStage) {
        $oraclePass = Test-ECTOSRawZipExactFailureOracle -ExpectedFailureId ([string]$fixture.expected_failure_id) -ExpectedStage $expectedStage -ActualFailures @($evidence.failures)
    }
    $pass = (-not $processResult.timed_out -and $processResult.exit_code -ne 0 -and $null -ne $evidence -and [string]$evidence.parse_status -eq 'FAIL' -and $oraclePass)
    $actualFailuresForReceipt = @()
    if($null -ne $evidence) { $actualFailuresForReceipt = @($evidence.failures) }
    $results += [pscustomobject][ordered]@{fixture_id=$fixtureId;expected_failure_id=[string]$fixture.expected_failure_id;expected_stage=$expectedStage;actual_failures=$actualFailuresForReceipt;exit_code=$processResult.exit_code;timed_out=$processResult.timed_out;pass=$pass}
}

Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
$pesterResult = Invoke-Pester -Script $testsPath -PassThru -Quiet
$pesterPass = ([int]$pesterResult.FailedCount -eq 0)

$failed = @($results | Where-Object { -not $_.pass })
$receiptStatus = 'PASS'
if($failed.Count -gt 0 -or -not $pesterPass) { $receiptStatus = 'FAIL' }
$receipt = [pscustomobject][ordered]@{
    schema_id='ECTOS_RAW_ZIP_PARSER_SELFTEST_RECEIPT_V01'
    direct_fixture_result_count=$results.Count
    direct_fixture_failure_count=$failed.Count
    pester_version=[string]$pesterModule.Version
    pester_total_count=[int]$pesterResult.TotalCount
    pester_passed_count=[int]$pesterResult.PassedCount
    pester_failed_count=[int]$pesterResult.FailedCount
    status=$receiptStatus
    results=$results
}
$receiptPath = Join-Path $EvidenceRoot 'ECTOS_RAW_ZIP_PARSER_SELFTEST_RECEIPT_V01.json'
[IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 32),(New-Object Text.UTF8Encoding($false)))
if($receiptStatus -ne 'PASS') { exit 40 }
exit 0
