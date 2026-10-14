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
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }
    $safeArguments = @()
    foreach ($argument in @($ArgumentList)) { $safeArguments += (ConvertTo-ECTOSProcessArgument -Value ([string]$argument)) }
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = [string]::Join(' ',$safeArguments)
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) { throw 'ECTOS_PROCESS_START_RETURNED_FALSE' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutMilliseconds)
        if (-not $completed) {
            try { & taskkill.exe /PID $process.Id /T /F 1>$null 2>$null } catch { Write-Verbose $_.Exception.Message }
            try { $process.WaitForExit() } catch { Write-Verbose $_.Exception.Message }
            $stdoutText = $stdoutTask.Result
            $stderrText = $stderrTask.Result
            [IO.File]::WriteAllText($StdoutPath,$stdoutText,(New-Object Text.UTF8Encoding($false)))
            [IO.File]::WriteAllText($StderrPath,$stderrText,(New-Object Text.UTF8Encoding($false)))
            $stopwatch.Stop()
            [pscustomobject][ordered]@{schema_id='ECTOS_PS51_PROCESS_RECEIPT_V02';status='TIMEOUT';failure_id='ECTOS_PROCESS_STAGE_TIMEOUT';process_id=$process.Id;exit_code=$null;elapsed_ms=$stopwatch.ElapsedMilliseconds;timeout_ms=$TimeoutMilliseconds;working_directory=$WorkingDirectory;stdout_path=$StdoutPath;stderr_path=$StderrPath;stdout_sha256=(Get-FileHash -LiteralPath $StdoutPath -Algorithm SHA256).Hash;stderr_sha256=(Get-FileHash -LiteralPath $StderrPath -Algorithm SHA256).Hash}
            return
        }
        $process.WaitForExit()
        $stdoutText = $stdoutTask.Result
        $stderrText = $stderrTask.Result
        [IO.File]::WriteAllText($StdoutPath,$stdoutText,(New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($StderrPath,$stderrText,(New-Object Text.UTF8Encoding($false)))
        $exitCode = $process.ExitCode
        $stopwatch.Stop()
        [pscustomobject][ordered]@{schema_id='ECTOS_PS51_PROCESS_RECEIPT_V02';status='COMPLETED';failure_id=$null;process_id=$process.Id;exit_code=[int]$exitCode;elapsed_ms=$stopwatch.ElapsedMilliseconds;timeout_ms=$TimeoutMilliseconds;working_directory=$WorkingDirectory;stdout_path=$StdoutPath;stderr_path=$StderrPath;stdout_sha256=(Get-FileHash -LiteralPath $StdoutPath -Algorithm SHA256).Hash;stderr_sha256=(Get-FileHash -LiteralPath $StderrPath -Algorithm SHA256).Hash}
    } catch {
        if ($stopwatch.IsRunning) { $stopwatch.Stop() }
        throw ('ECTOS_PROCESS_START_OR_CAPTURE_FAIL:' + $_.Exception.Message)
    } finally {
        $process.Dispose()
    }
}
