[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qc03RoutesPath,
    [Parameter(Mandatory = $true)][string]$ExecutionPlanPath,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

function Write-QcTextEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Text
    )
    $QcParent = Split-Path -Parent $LiteralPath
    if (-not (Test-Path -LiteralPath $QcParent -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($QcParent) | Out-Null
    }
    $QcUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($LiteralPath, $Text, $QcUtf8NoBom)
}

function ConvertTo-QcArgumentString {
    param([Parameter(Mandatory = $false)]$ArgumentValues)
    $QcRendered = @()
    foreach ($QcArgumentValue in @(ConvertTo-QcArray -Value $ArgumentValues)) {
        $QcArgumentText = [string]$QcArgumentValue
        if ($QcArgumentText -match '[\s"]') {
            $QcEscaped = $QcArgumentText.Replace('"', '\"')
            $QcRendered += ('"' + $QcEscaped + '"')
        }
        else {
            $QcRendered += $QcArgumentText
        }
    }
    return ($QcRendered -join ' ')
}

$Qc03 = Import-QcJson -LiteralPath $Qc03RoutesPath
if ([string]$Qc03.status -ne 'PASS') {
    throw 'QC04_UPSTREAM_QC03_NOT_PASS'
}
$QcPlan = Import-QcJson -LiteralPath $ExecutionPlanPath
$QcPlanEntries = @(ConvertTo-QcArray -Value $QcPlan.executions)
if ($QcPlanEntries.Count -eq 0) {
    throw 'QC04_EXECUTION_PLAN_EMPTY'
}
if (-not (Test-Path -LiteralPath $EvidenceDirectory -PathType Container)) {
    [System.IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
}

$QcResults = @()
$QcUnaccounted = @()
$QcExecutionIndex = 0
foreach ($QcRoute in @(ConvertTo-QcArray -Value $Qc03.routes)) {
    $QcMatches = @($QcPlanEntries | Where-Object { [string]$_.control_id -eq [string]$QcRoute.control_id -and [string]$_.property_id -eq [string]$QcRoute.property_id })
    if ($QcMatches.Count -ne 1) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|PLAN_MATCH_COUNT=$($QcMatches.Count)"
        continue
    }
    $QcEntry = $QcMatches[0]
    $QcCommandPath = [string]$QcRoute.command_path
    if (-not (Test-Path -LiteralPath $QcCommandPath -PathType Leaf)) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|COMMAND_NOT_FOUND"
        continue
    }
    $QcCommandSha = Get-QcSha256 -LiteralPath $QcCommandPath
    if ($QcCommandSha -ne ([string]$QcRoute.tool_sha256).ToLowerInvariant()) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|TOOL_SHA_MISMATCH"
        continue
    }
    $QcExecutionIndex++
    $QcExecutionId = ('EXEC-{0:D4}' -f $QcExecutionIndex)
    $QcFixedArguments = @(ConvertTo-QcArray -Value $QcRoute.fixed_arguments | ForEach-Object { [string]$_ })
    $QcDynamicArguments = @(ConvertTo-QcArray -Value $QcEntry.arguments | ForEach-Object { [string]$_ })
    $QcAllArguments = @($QcFixedArguments + $QcDynamicArguments)
    $QcArgumentString = ConvertTo-QcArgumentString -ArgumentValues $QcAllArguments
    $QcWorkingDirectory = [string]$QcEntry.working_directory
    if (-not (Test-Path -LiteralPath $QcWorkingDirectory -PathType Container)) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|WORKDIR_NOT_FOUND"
        continue
    }
    $QcTimeoutSeconds = [int]$QcEntry.timeout_seconds
    if ($QcTimeoutSeconds -lt 1) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|INVALID_TIMEOUT"
        continue
    }

    $QcStart = [DateTime]::UtcNow
    $QcProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $QcProcessInfo.FileName = $QcCommandPath
    $QcProcessInfo.Arguments = $QcArgumentString
    $QcProcessInfo.WorkingDirectory = $QcWorkingDirectory
    $QcProcessInfo.UseShellExecute = $false
    $QcProcessInfo.CreateNoWindow = $true
    $QcProcessInfo.RedirectStandardOutput = $true
    $QcProcessInfo.RedirectStandardError = $true
    $QcProcess = New-Object System.Diagnostics.Process
    $QcProcess.StartInfo = $QcProcessInfo
    $QcStarted = $QcProcess.Start()
    if (-not $QcStarted) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|PROCESS_START_FAILED"
        $QcProcess.Dispose()
        continue
    }
    $QcStdoutTask = $QcProcess.StandardOutput.ReadToEndAsync()
    $QcStderrTask = $QcProcess.StandardError.ReadToEndAsync()
    $QcExited = $QcProcess.WaitForExit($QcTimeoutSeconds * 1000)
    $QcTimedOut = $false
    if (-not $QcExited) {
        $QcTimedOut = $true
        try {
            $QcProcess.Kill()
        }
        catch {
            $QcProcess.Dispose()
            throw "QC04_PROCESS_KILL_FAILED|$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|$($_.Exception.GetType().Name)"
        }
        $QcProcess.WaitForExit()
    }
    $QcStdout = $QcStdoutTask.Result
    $QcStderr = $QcStderrTask.Result
    $QcEnd = [DateTime]::UtcNow
    $QcExitCode = $null
    if (-not $QcTimedOut) {
        $QcExitCode = [int]$QcProcess.ExitCode
    }
    $QcProcessId = [int]$QcProcess.Id
    $QcProcess.Dispose()

    $QcStdoutPath = Join-Path $EvidenceDirectory ($QcExecutionId + '.stdout.txt')
    $QcStderrPath = Join-Path $EvidenceDirectory ($QcExecutionId + '.stderr.txt')
    Write-QcTextEvidence -LiteralPath $QcStdoutPath -Text $QcStdout
    Write-QcTextEvidence -LiteralPath $QcStderrPath -Text $QcStderr
    $QcStdoutSha = Get-QcSha256 -LiteralPath $QcStdoutPath
    $QcStderrSha = Get-QcSha256 -LiteralPath $QcStderrPath

    $QcExpectedExit = @(ConvertTo-QcArray -Value $QcEntry.expected_exit | ForEach-Object { [int]$_ })
    $QcExitMatches = $false
    if (-not $QcTimedOut -and $QcExpectedExit -contains $QcExitCode) {
        $QcExitMatches = $true
    }
    $QcStdoutMatches = $true
    if ($QcEntry.PSObject.Properties['expected_stdout_contains']) {
        $QcExpectedStdoutText = [string]$QcEntry.expected_stdout_contains
        if (-not [string]::IsNullOrEmpty($QcExpectedStdoutText) -and $QcStdout -notlike ('*' + $QcExpectedStdoutText + '*')) {
            $QcStdoutMatches = $false
        }
    }
    $QcStderrMatches = $true
    if ($QcEntry.PSObject.Properties['expected_stderr_contains']) {
        $QcExpectedStderrText = [string]$QcEntry.expected_stderr_contains
        if (-not [string]::IsNullOrEmpty($QcExpectedStderrText) -and $QcStderr -notlike ('*' + $QcExpectedStderrText + '*')) {
            $QcStderrMatches = $false
        }
    }
    $QcPreliminaryResult = 'PASS'
    if ($QcTimedOut -or -not $QcExitMatches -or -not $QcStdoutMatches -or -not $QcStderrMatches) {
        $QcPreliminaryResult = 'FAIL'
    }
    $QcTimeoutState = 'NOT_TIMED_OUT'
    if ($QcTimedOut) { $QcTimeoutState = 'TIMED_OUT' }
    $QcTerminationState = 'EXITED'
    if ($QcTimedOut) { $QcTerminationState = 'KILLED_AFTER_TIMEOUT' }

    $QcResults += [pscustomobject][ordered]@{
        execution_id = $QcExecutionId
        route_id = [string]$QcRoute.route_id
        property_id = [string]$QcRoute.property_id
        control_id = [string]$QcRoute.control_id
        run_id = [guid]::NewGuid().ToString('N')
        start_time = $QcStart.ToString('o')
        end_time = $QcEnd.ToString('o')
        process_id = $QcProcessId
        exit_code = $QcExitCode
        timeout_state = $QcTimeoutState
        termination_state = $QcTerminationState
        stdout_sha256 = $QcStdoutSha
        stderr_sha256 = $QcStderrSha
        raw_stdout_ref = $QcStdoutPath
        raw_stderr_ref = $QcStderrPath
        tool_id = [string]$QcRoute.tool_id
        tool_sha256 = $QcCommandSha
        command_path = $QcCommandPath
        arguments = $QcAllArguments
        working_directory = $QcWorkingDirectory
        observed_property = [string]$QcEntry.observed_property_label
        preliminary_result = $QcPreliminaryResult
    }
}

$QcStatus = 'PASS'
if ($QcUnaccounted.Count -gt 0 -or $QcResults.Count -ne @(ConvertTo-QcArray -Value $Qc03.routes).Count) {
    $QcStatus = 'BLOCKED'
}
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC04_EXECUTION_RETURN_V01'
    component_id = 'QC-04'
    status = $QcStatus
    target_package_id = [string]$Qc03.target_package_id
    target_package_sha256 = [string]$Qc03.target_package_sha256
    required_execution_count = @(ConvertTo-QcArray -Value $Qc03.routes).Count
    executed_count = $QcResults.Count
    execution_results = $QcResults
    unaccounted_execution_register = $QcUnaccounted
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
