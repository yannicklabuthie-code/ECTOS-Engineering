Set-StrictMode -Version Latest
function Invoke-ECTOSBPF {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$BuildPlan,[Parameter(Mandatory=$true)][string]$WorkspaceRoot)
    if ([string]$BuildPlan.status -ne 'PASS') { throw 'BPF_BUILD_PLAN_NOT_PASS' }
    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw 'BPF_WORKSPACE_ROOT_EMPTY' }
    $packageRoot = Join-Path $WorkspaceRoot ([string]$BuildPlan.package_id)
    if (Test-Path -LiteralPath $packageRoot) { throw ('BPF_OUTPUT_ALREADY_EXISTS:' + $packageRoot) }
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $sourceRootFull = [IO.Path]::GetFullPath([string]$BuildPlan.source_root).TrimEnd('\')
    $records = @()
    foreach ($relative in @($BuildPlan.source_files)) {
        $source = [IO.Path]::GetFullPath((Join-Path $sourceRootFull ([string]$relative)))
        if (-not $source.StartsWith($sourceRootFull,[StringComparison]::OrdinalIgnoreCase)) { throw ('BPF_SOURCE_PATH_ESCAPE:' + $relative) }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw ('BPF_SOURCE_FILE_NOT_FOUND:' + $relative) }
        $destination = Join-Path $packageRoot ([string]$relative)
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $source -Destination $destination -Force
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        $records += [pscustomobject][ordered]@{path=[string]$relative;sha256=$hash;size_bytes=(Get-Item -LiteralPath $destination).Length}
    }
    $manifestPath = Join-Path $packageRoot 'ECTOS_BUILD_OUTPUT_MANIFEST.json'
    [pscustomobject][ordered]@{schema_id='ECTOS_BUILD_OUTPUT_MANIFEST_V01';package_id=[string]$BuildPlan.package_id;version=[string]$BuildPlan.package_version;files=@($records)} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $zipPath = $packageRoot + '.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($packageRoot,$zipPath,[IO.Compression.CompressionLevel]::Optimal,$false)
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    [pscustomobject][ordered]@{
        schema_id='ECTOS_BPF_RESULT_V01';status='PASS';package_id=[string]$BuildPlan.package_id;package_root=$packageRoot
        package_zip=$zipPath;package_sha256=$zipHash;file_count=@($records).Count;manifest=$manifestPath
    }
}
