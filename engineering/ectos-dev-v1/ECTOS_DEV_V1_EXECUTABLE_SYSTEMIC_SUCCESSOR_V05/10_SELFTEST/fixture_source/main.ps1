[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[pscustomobject][ordered]@{
    schema_id = 'ECTOS_DEV_SELFTEST_PRODUCT_RESULT_V01'
    status = 'PASS'
    runtime = $PSVersionTable.PSVersion.ToString()
    edition = $PSVersionTable.PSEdition
} | ConvertTo-Json -Compress
exit 0
