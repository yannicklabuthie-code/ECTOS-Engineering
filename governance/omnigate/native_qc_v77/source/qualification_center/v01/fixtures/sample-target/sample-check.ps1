[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Positive','Negative')][string]$Mode
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Positive') {
    Write-Output 'PROPERTY_OK'
    exit 0
}

Write-Output 'NEGATIVE_REJECTED'
exit 10
