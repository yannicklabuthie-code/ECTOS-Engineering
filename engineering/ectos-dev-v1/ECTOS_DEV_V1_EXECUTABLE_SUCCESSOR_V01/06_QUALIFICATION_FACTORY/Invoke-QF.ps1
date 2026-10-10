Set-StrictMode -Version Latest
function Invoke-ECTOSQFHandoff {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$BPFResult,[Parameter(Mandatory=$true)]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if ([string]$BPFResult.status -ne 'PASS') { throw 'QF_HANDOFF_BUILD_NOT_PASS' }
    if (-not ($Target.PSObject.Properties.Name -contains 'qualification_profile_path')) { throw 'QF_PROFILE_PATH_MISSING' }
    $profilePath = Join-Path $RepositoryRoot ([string]$Target.qualification_profile_path)
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) { throw ('QF_PROFILE_NOT_FOUND:' + $profilePath) }
    try { $qfProfile = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { throw ('QF_PROFILE_INVALID:' + $_.Exception.Message) }
    $manifestPath = Join-Path ([string]$BPFResult.package_root) 'ectos-package-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'QF_PACKAGE_MANIFEST_MISSING' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $graphPath = Join-Path ([string]$BPFResult.package_root) ([string]$manifest.dependency_graph)
    if (-not (Test-Path -LiteralPath $graphPath -PathType Leaf)) { throw 'QF_DEPENDENCY_GRAPH_MISSING' }
    $entryPath = Join-Path ([string]$BPFResult.package_root) ([string]$manifest.entrypoint)
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) { throw 'QF_ENTRYPOINT_MISSING' }
    $actualZipHash = (Get-FileHash -LiteralPath ([string]$BPFResult.package_zip) -Algorithm SHA256).Hash
    if ($actualZipHash -ne [string]$BPFResult.package_sha256) { throw 'QF_PACKAGE_SHA256_MISMATCH' }
    [pscustomobject][ordered]@{
        schema_id='ECTOS_QF_HANDOFF_V01';status='HANDOFF_READY_FOR_INDEPENDENT_QUALIFICATION'
        package_id=[string]$BPFResult.package_id;package_sha256=$actualZipHash
        qualification_profile_id=[string]$qfProfile.profile_id;manifest=$manifestPath;dependency_graph=$graphPath;entrypoint=$entryPath
        independent_qualification_executed=$false;producer_is_qualifier=$false
    }
}
