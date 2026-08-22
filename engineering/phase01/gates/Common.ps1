Set-StrictMode -Version Latest
function New-EctosGateResult {
  param([string]$GateId,[string]$Status,[string]$Target,[hashtable]$Details=@{},[string[]]$Evidence=@())
  [ordered]@{schema_id='ECTOS_DEV_GATE_RESULT_V01';gate_id=$GateId;status=$Status;timestamp_utc=[DateTime]::UtcNow.ToString('o');target=$Target;details=$Details;evidence=$Evidence}
}
function Write-EctosGateResult {
  param($Result,[string]$ResultsRoot)
  New-Item -ItemType Directory -Force -Path $ResultsRoot | Out-Null
  $path=Join-Path $ResultsRoot ($Result.gate_id + '.json')
  $Result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
  return $path
}
