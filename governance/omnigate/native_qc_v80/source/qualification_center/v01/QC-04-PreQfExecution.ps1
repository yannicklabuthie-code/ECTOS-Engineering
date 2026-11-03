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
    param($ArgumentValues)
    $rendered = @()
    foreach ($value in @(ConvertTo-QcArray -Value $ArgumentValues)) {
        $arg = [string]$value
        # Windows CommandLineToArgvW / C-runtime escaping, including empty args.
        if ($arg.Length -gt 0 -and $arg -notmatch '[\s"]') { $rendered += $arg; continue }
        $builder = New-Object System.Text.StringBuilder
        [void]$builder.Append('"')
        $slashes = 0
        foreach ($ch in $arg.ToCharArray()) {
            if ($ch -eq '\') { $slashes++; continue }
            if ($ch -eq '"') {
                [void]$builder.Append(('\' * (2 * $slashes + 1)))
                [void]$builder.Append('"')
            } else {
                [void]$builder.Append(('\' * $slashes))
                [void]$builder.Append($ch)
            }
            $slashes = 0
        }
        [void]$builder.Append(('\' * (2 * $slashes)))
        [void]$builder.Append('"')
        $rendered += $builder.ToString()
    }
    return ($rendered -join ' ')
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
$QcExecutionRequests = @()
$QcUnaccounted = @()
$QcExecutionIndex = 0
$QcRouteKeys = @($(foreach ($QcRouteItem in @(ConvertTo-QcArray -Value $Qc03.routes)) { [string]$QcRouteItem.property_id + '|' + [string]$QcRouteItem.control_id }))
foreach ($QcPlanItem in $QcPlanEntries) {
    $QcPlanKey = [string]$QcPlanItem.property_id + '|' + [string]$QcPlanItem.control_id
    if ($QcRouteKeys -notcontains $QcPlanKey) { $QcUnaccounted += ('UNROUTED_PLAN_ENTRY|' + $QcPlanKey) }
}
foreach ($QcRoute in @(ConvertTo-QcArray -Value $Qc03.routes)) {
    $QcMatches = @($QcPlanEntries | Where-Object { [string]$_.control_id -eq [string]$QcRoute.control_id -and [string]$_.property_id -eq [string]$QcRoute.property_id })
    if ($QcMatches.Count -ne 1) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|PLAN_MATCH_COUNT=$($QcMatches.Count)"
        continue
    }
    $QcEntry = $QcMatches[0]
    try { $QcExecutionProfile = Get-QcExecutionProfile $QcRoute }
    catch { $QcUnaccounted += ('EXECUTION_PROFILE_INVALID|' + $_.Exception.Message); continue }
    if (-not (Test-QcNativeExecutionHost)) { $QcUnaccounted += 'NATIVE_EXECUTION_HOST_REQUIRED'; continue }
    if ($QcEntry.PSObject.Properties['execution_profile']) {
        try { $QcPlanProfile = Get-QcExecutionProfile $QcEntry }
        catch { $QcUnaccounted += 'PLAN_EXECUTION_PROFILE_INVALID'; continue }
        if (($QcPlanProfile | ConvertTo-Json -Compress) -cne ($QcExecutionProfile | ConvertTo-Json -Compress)) { $QcUnaccounted += 'PLAN_EXECUTION_PROFILE_OVERRIDE'; continue }
    }
    if (-not $QcRoute.PSObject.Properties['oracle_specification'] -or -not $QcRoute.PSObject.Properties['script_path'] -or -not $QcRoute.PSObject.Properties['script_sha256']) { $QcUnaccounted += ('ROUTE_ORACLE_OR_SCRIPT_MISSING|' + $QcPlanKey); continue }
    $QcOracle = $QcRoute.oracle_specification
    if ([string]$QcOracle.control_id -ne [string]$QcRoute.control_id -or [string]$QcOracle.oracle_id -ne [string]$QcRoute.oracle_id -or @(ConvertTo-QcArray -Value $QcOracle.expected_exit).Count -eq 0) { $QcUnaccounted += 'ORACLE_BINDING_INVALID'; continue }
    $override = $false
    foreach ($field in @('expected_exit','expected_stdout_contains','expected_stderr_contains')) {
        if ($QcEntry.PSObject.Properties[$field]) {
            if (($QcEntry.$field | ConvertTo-Json -Compress) -cne ($QcOracle.$field | ConvertTo-Json -Compress)) { $override = $true }
        }
    }
    if ($override) { $QcUnaccounted += 'PLAN_ORACLE_OVERRIDE_DIVERGENCE'; continue }
    $QcScriptPath = [string]$QcRoute.script_path
    if (-not (Test-Path -LiteralPath $QcScriptPath -PathType Leaf) -or (Get-QcSha256 -LiteralPath $QcScriptPath) -ne [string]$QcRoute.script_sha256) { $QcUnaccounted += 'SCRIPT_IDENTITY_MISMATCH'; continue }
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
    if ($QcTimeoutSeconds -lt 1 -or $QcTimeoutSeconds -gt 86400) {
        $QcUnaccounted += "$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|INVALID_TIMEOUT"
        continue
    }

    $QcScriptId = [System.IO.Path]::GetFileName($QcScriptPath)
    $QcScriptSha = Get-QcSha256 -LiteralPath $QcScriptPath
    if (-not (Test-QcPinnedInvocation -CommandPath $QcCommandPath -ScriptPath $QcScriptPath -FixedArguments $QcFixedArguments -DynamicArguments $QcDynamicArguments)) { $QcUnaccounted += 'PINNED_INVOCATION_CONTRACT_REJECTED'; continue }
    $QcExecutionRequests += [pscustomobject][ordered]@{
        execution_id = $QcExecutionId
        property_id = [string]$QcRoute.property_id
        control_id = [string]$QcRoute.control_id
        test_id = [string]$QcRoute.control_id
        target_id = [string]$Qc03.target_package_id
        target_sha256 = [string]$Qc03.target_package_sha256
        tool_id = [string]$QcRoute.tool_id
        tool_sha256 = $QcCommandSha
        script_id = $QcScriptId
        script_sha256 = $QcScriptSha
        fixture_id = $null
        mutation_id = $null
        oracle_id = [string]$QcRoute.oracle_id
        host_id = [string]$QcRoute.host_id
        runtime_id = [string]$QcRoute.runtime_profile
        execution_profile = $QcExecutionProfile
        command = $QcCommandPath
        arguments = $QcAllArguments
        working_directory = $QcWorkingDirectory
        timeout_seconds = $QcTimeoutSeconds
        expected_exit = @(ConvertTo-QcArray -Value $QcOracle.expected_exit | ForEach-Object { [int]$_ })
        expected_output_contract = [string]$QcRoute.expected_property
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
    try { $QcStarted = $QcProcess.Start() } catch { $QcUnaccounted += ('PROCESS_START_EXCEPTION|' + $_.Exception.GetType().Name); $QcProcess.Dispose(); continue }
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
            $taskkill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
            $killInfo = New-Object System.Diagnostics.ProcessStartInfo
            $killInfo.FileName = $taskkill
            $killInfo.Arguments = '/PID ' + $QcProcess.Id + ' /T /F'
            $killInfo.UseShellExecute = $false
            $killInfo.CreateNoWindow = $true
            $killProcess = [System.Diagnostics.Process]::Start($killInfo)
            if (-not $killProcess.WaitForExit(5000)) { $killProcess.Kill(); $QcUnaccounted += 'PROCESS_TREE_TERMINATION_NOT_PROVEN' }
            $killProcess.Dispose()
            if (-not $QcProcess.HasExited) { $QcProcess.Kill() }
        }
        catch {
            $QcProcess.Dispose()
            $QcUnaccounted += "QC04_PROCESS_KILL_FAILED|$([string]$QcRoute.property_id)|$([string]$QcRoute.control_id)|$($_.Exception.GetType().Name)"
            continue
        }
        [void]$QcProcess.WaitForExit(5000)
    }
    $drained = $QcStdoutTask.Wait(5000) -and $QcStderrTask.Wait(5000)
    if (-not $drained) {
        $QcTimedOut = $true
        $QcUnaccounted += 'STREAM_DRAIN_TIMEOUT'
        if ($QcStdoutTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
            $partialPath = Join-Path $EvidenceDirectory ($QcExecutionId + '.partial.stdout.txt')
            Write-QcTextEvidence -LiteralPath $partialPath -Text $QcStdoutTask.Result
            $QcUnaccounted += ('PARTIAL_STDOUT|' + $partialPath + '|SHA256=' + (Get-QcSha256 -LiteralPath $partialPath))
        }
        if ($QcStderrTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
            $partialPath = Join-Path $EvidenceDirectory ($QcExecutionId + '.partial.stderr.txt')
            Write-QcTextEvidence -LiteralPath $partialPath -Text $QcStderrTask.Result
            $QcUnaccounted += ('PARTIAL_STDERR|' + $partialPath + '|SHA256=' + (Get-QcSha256 -LiteralPath $partialPath))
        }
        $QcProcess.Dispose()
        continue
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

    $QcExpectedExit = @(ConvertTo-QcArray -Value $QcOracle.expected_exit | ForEach-Object { [int]$_ })
    $QcExitMatches = $false
    if (-not $QcTimedOut -and $QcExpectedExit -contains $QcExitCode) {
        $QcExitMatches = $true
    }
    $QcStdoutMatches = $true
    if ($QcOracle.PSObject.Properties['expected_stdout_contains']) {
        $QcExpectedStdoutText = [string]$QcOracle.expected_stdout_contains
        if (-not [string]::IsNullOrEmpty($QcExpectedStdoutText) -and -not $QcStdout.Contains($QcExpectedStdoutText)) {
            $QcStdoutMatches = $false
        }
    }
    $QcStderrMatches = $true
    if ($QcOracle.PSObject.Properties['expected_stderr_contains']) {
        $QcExpectedStderrText = [string]$QcOracle.expected_stderr_contains
        if (-not [string]::IsNullOrEmpty($QcExpectedStderrText) -and -not $QcStderr.Contains($QcExpectedStderrText)) {
            $QcStderrMatches = $false
        }
    }
    $QcScriptUnchanged = $false
    if (Test-Path -LiteralPath $QcScriptPath -PathType Leaf) { $QcScriptUnchanged = (Get-QcSha256 -LiteralPath $QcScriptPath) -eq $QcScriptSha }
    $QcPreliminaryResult = 'PASS'
    if (-not $QcScriptUnchanged -or $QcTimedOut -or -not $QcExitMatches -or -not $QcStdoutMatches -or -not $QcStderrMatches) {
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
        script_path = $QcScriptPath
        script_sha256 = $QcScriptSha
        script_unchanged = $QcScriptUnchanged
        execution_profile = $QcExecutionProfile
        command_path = $QcCommandPath
        arguments = $QcAllArguments
        working_directory = $QcWorkingDirectory
        observed_property = ('EXIT=' + $QcExitCode + ';STDOUT_SHA256=' + $QcStdoutSha + ';STDERR_SHA256=' + $QcStderrSha)
        preliminary_result = $QcPreliminaryResult
        created_outputs = @([pscustomobject]@{ path = $QcStdoutPath; sha256 = $QcStdoutSha }, [pscustomobject]@{ path = $QcStderrPath; sha256 = $QcStderrSha })
    }
}

foreach ($request in $QcExecutionRequests) {
 try { Assert-QcSchema -Value $request -SchemaName 'execution-request-v01.schema.json' } catch { $QcUnaccounted += ('REQUEST_SCHEMA_INVALID|' + $_.Exception.Message) }
}
foreach ($result in $QcResults) {
 try { Assert-QcSchema -Value $result -SchemaName 'execution-result-v01.schema.json' } catch { $QcUnaccounted += ('RESULT_SCHEMA_INVALID|' + $_.Exception.Message) }
}
$QcStatus = 'PASS'
if (@(ConvertTo-QcArray -Value $Qc03.routes).Count -eq 0 -or $QcUnaccounted.Count -gt 0 -or $QcResults.Count -ne @(ConvertTo-QcArray -Value $Qc03.routes).Count) {
    $QcStatus = 'BLOCKED'
}
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC04_EXECUTION_RETURN_V01'
    component_id = 'QC-04'
    status = $QcStatus
    target_package_id = [string]$Qc03.target_package_id
    target_package_sha256 = [string]$Qc03.target_package_sha256
    result_scope = 'EXECUTION_ACCOUNTING_ONLY_CONTROL_VERDICTS_IN_QC05'
    required_execution_count = @(ConvertTo-QcArray -Value $Qc03.routes).Count
    executed_count = $QcResults.Count
    execution_results = $QcResults
    execution_requests = $QcExecutionRequests
    unaccounted_execution_register = $QcUnaccounted
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
