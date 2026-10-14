Set-StrictMode -Version Latest

function ConvertTo-ECTOSProcessArgument {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)
    $text = $Value
    if ($text -match '[\s"]') {
        $text = '"' + $text.Replace('"','\"') + '"'
    }
    return $text
}

function Invoke-ECTOSProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory=$true)][string]$WorkingDirectory,
        [Parameter(Mandatory=$true)][int]$TimeoutMilliseconds,
        [Parameter(Mandatory=$true)][string]$StdoutPath,
        [Parameter(Mandatory=$true)][string]$StderrPath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) { throw 'ECTOS_PROCESS_FILE_PATH_EMPTY' }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw ('ECTOS_PROCESS_FILE_NOT_FOUND:' + $FilePath) }
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) { throw 'ECTOS_PROCESS_WORKING_DIRECTORY_EMPTY' }
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) { throw ('ECTOS_PROCESS_WORKING_DIRECTORY_NOT_FOUND:' + $WorkingDirectory) }
    if ($TimeoutMilliseconds -le 0) { throw 'ECTOS_PROCESS_TIMEOUT_INVALID' }
    if ([string]::IsNullOrWhiteSpace($StdoutPath)) { throw 'ECTOS_PROCESS_STDOUT_PATH_EMPTY' }
    if ([string]::IsNullOrWhiteSpace($StderrPath)) { throw 'ECTOS_PROCESS_STDERR_PATH_EMPTY' }
    if ([string]::Equals($StdoutPath,$StderrPath,[StringComparison]::OrdinalIgnoreCase)) { throw 'ECTOS_PROCESS_STREAM_PATH_COLLISION' }

    foreach ($streamPath in @($StdoutPath,$StderrPath)) {
        $parent = Split-Path -Parent $streamPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
    }

    $safeArguments = @()
    foreach ($argument in @($ArgumentList)) {
        $safeArguments += (ConvertTo-ECTOSProcessArgument -Value ([string]$argument))
    }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $safeArguments -WorkingDirectory $WorkingDirectory -PassThru -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -ErrorAction Stop
    } catch {
        throw ('ECTOS_PROCESS_START_FAIL:' + $_.Exception.Message)
    }

    $completed = $process.WaitForExit($TimeoutMilliseconds)
    if (-not $completed) {
        try {
            & taskkill.exe /PID $process.Id /T /F 1>$null 2>$null
        } catch {
            Write-Verbose $_.Exception.Message
        }
        try { $process.WaitForExit() } catch { Write-Verbose $_.Exception.Message }
        try { $process.Refresh() } catch { Write-Verbose $_.Exception.Message }
        $stopwatch.Stop()
        [pscustomobject][ordered]@{
            schema_id='ECTOS_PS51_PROCESS_RECEIPT_V02'
            status='TIMEOUT'
            failure_id='ECTOS_PROCESS_STAGE_TIMEOUT'
            process_id=$process.Id
            exit_code=$null
            elapsed_ms=$stopwatch.ElapsedMilliseconds
            timeout_ms=$TimeoutMilliseconds
            working_directory=$WorkingDirectory
            stdout_path=$StdoutPath
            stderr_path=$StderrPath
            stdout_sha256=$null
            stderr_sha256=$null
        }
        return
    }

    try { $process.WaitForExit() } catch { throw ('ECTOS_PROCESS_STREAM_DRAIN_FAIL:' + $_.Exception.Message) }
    try { $process.Refresh() } catch { throw ('ECTOS_PROCESS_REFRESH_FAIL:' + $_.Exception.Message) }

    $exitCode = $null
    try { $exitCode = [int]$process.ExitCode } catch { throw 'ECTOS_PROCESS_EXITCODE_NOT_MATERIALIZED' }
    if ($null -eq $exitCode) { throw 'ECTOS_PROCESS_EXITCODE_NOT_MATERIALIZED' }

    $stopwatch.Stop()
    $stdoutSha = $null
    $stderrSha = $null
    if (Test-Path -LiteralPath $StdoutPath -PathType Leaf) { $stdoutSha = (Get-FileHash -LiteralPath $StdoutPath -Algorithm SHA256).Hash }
    if (Test-Path -LiteralPath $StderrPath -PathType Leaf) { $stderrSha = (Get-FileHash -LiteralPath $StderrPath -Algorithm SHA256).Hash }

    [pscustomobject][ordered]@{
        schema_id='ECTOS_PS51_PROCESS_RECEIPT_V02'
        status='COMPLETED'
        failure_id=$null
        process_id=$process.Id
        exit_code=$exitCode
        elapsed_ms=$stopwatch.ElapsedMilliseconds
        timeout_ms=$TimeoutMilliseconds
        working_directory=$WorkingDirectory
        stdout_path=$StdoutPath
        stderr_path=$StderrPath
        stdout_sha256=$stdoutSha
        stderr_sha256=$stderrSha
    }
}
