param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$files=Get-ChildItem -LiteralPath $TargetPackageRoot -Recurse -File | Where-Object { $_.FullName -notlike (Join-Path $ResultsRoot '*') } | Sort-Object FullName
$records=@();foreach($f in $files){$h=Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256;$rel=$f.FullName.Substring($TargetPackageRoot.TrimEnd('\\').Length).TrimStart('\\');$records += [ordered]@{path=$rel;sha256=$h.Hash;size=$f.Length}}
$payload=($records|ConvertTo-Json -Depth 5 -Compress);$sha=[Security.Cryptography.SHA256]::Create();$aggregate=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)))).Replace('-','')
$r=New-EctosGateResult 'HASH_IDENTITY' 'PASS' $TargetPackageRoot @{file_count=$records.Count;aggregate_sha256=$aggregate;files=$records};Write-EctosGateResult $r $ResultsRoot
