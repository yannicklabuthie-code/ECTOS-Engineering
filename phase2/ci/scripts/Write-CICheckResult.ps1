[CmdletBinding()]
param([Parameter(Mandatory)][string]$CheckName,[Parameter(Mandatory)][ValidateSet('PASS','FAIL')][string]$Status,[Parameter(Mandatory)][string]$OutputRoot)
New-Item -ItemType Directory -Force -Path $OutputRoot|Out-Null
$safe=$CheckName -replace '[^A-Za-z0-9_.-]','_'
$o=[ordered]@{schema_id='ECTOS_CI_CHECK_RESULT_V01';check=$CheckName;status=$Status;timestamp_utc=[DateTime]::UtcNow.ToString('o');run_id=$env:GITHUB_RUN_ID;run_attempt=$env:GITHUB_RUN_ATTEMPT;sha=$env:GITHUB_SHA}
$o|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $OutputRoot ($safe+'.json')) -Encoding UTF8
