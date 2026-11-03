Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Describe 'ECTOS producer fail-closed boundary regression' {
    It 'preserves fixture behavior and denies unapproved authority' {
        $QcPowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $QcSelfTestPath = Join-Path $PSScriptRoot 'Run-QC-V01-SelfTest.ps1'
        $QcOutput = @(& $QcPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $QcSelfTestPath 2>&1)
        $QcExitCode = $LASTEXITCODE
        $QcExitCode | Should -Be 0
        ($QcOutput -join "`n") | Should -Match 'ECTOS_QC_V02_PRODUCER_FAIL_CLOSED_SELFTEST=PASS'
    }
}
