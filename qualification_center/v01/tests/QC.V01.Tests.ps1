Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcTestRoot = $PSScriptRoot

Describe 'ECTOS Qualification Center V01' {
    It 'passes the native end-to-end self-test' {
        $QcPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $QcSelfTestPath = Join-Path $QcTestRoot 'Run-QC-V01-SelfTest.ps1'
        $QcOutput = @(& $QcPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $QcSelfTestPath 2>&1)
        $QcExitCode = $LASTEXITCODE
        $QcExitCode | Should Be 0
        ($QcOutput -join "`n") | Should Match 'ECTOS_QC_V01_SELFTEST=PASS'
    }
}
