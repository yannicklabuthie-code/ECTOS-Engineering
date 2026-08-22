param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot,[switch]$RequirePS7)
$statuses=@{};Get-ChildItem -LiteralPath $ResultsRoot -File -Filter *.json -ErrorAction SilentlyContinue|ForEach-Object{try{$o=Get-Content $_.FullName -Raw|ConvertFrom-Json;if($o.schema_id -eq 'ECTOS_DEV_GATE_RESULT_V01'){$statuses[$o.gate_id]=$o.status}}catch{}}
function AllPass([string[]]$names){foreach($n in $names){if(-not $statuses.ContainsKey($n) -or $statuses[$n] -ne 'PASS'){return $false}};return $true}
$dev=AllPass @('PARSE','PSSCRIPTANALYZER','PESTER_UNIT','PESTER_CONTRACT','REGRESSION')
$pkg=$dev -and (AllPass @('PACKAGE_MANIFEST','PACKAGE_INSTALL_LOAD','HASH_IDENTITY'))
$qualRequired=@('NATIVE_PS51','FIXTURE_REGRESSION','STATE_COLLISION')
if($RequirePS7){$qualRequired += 'PS7'}
$qual=$pkg -and (AllPass $qualRequired)
$o=[ordered]@{schema_id='ECTOS_DEV_READINESS_V01';timestamp_utc=[DateTime]::UtcNow.ToString('o');target=$TargetPackageRoot;ps7_required=[bool]$RequirePS7;dev_ready=$dev;package_ready=$pkg;qualification_ready=$qual;gate_status=$statuses}
$o|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $ResultsRoot 'READINESS.json') -Encoding UTF8
$o
