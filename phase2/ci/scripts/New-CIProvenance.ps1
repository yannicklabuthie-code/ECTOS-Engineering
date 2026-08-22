[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$files=Get-ChildItem -LiteralPath $PackageRoot -File -Recurse | Sort-Object FullName
$items=@()
foreach($f in $files){
  $rel=$f.FullName.Substring($PackageRoot.Length).TrimStart('\','/')
  $items += [ordered]@{path=$rel;sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash;length=$f.Length}
}
$manifest=[ordered]@{
 schema_id='ECTOS_CI_PROVENANCE_V01'
 timestamp_utc=[DateTime]::UtcNow.ToString('o')
 package_root=$PackageRoot
 commit_sha=$env:GITHUB_SHA
 build_id=$env:GITHUB_RUN_ID
 run_attempt=$env:GITHUB_RUN_ATTEMPT
 files=$items
}
$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $OutputPath -Encoding UTF8
