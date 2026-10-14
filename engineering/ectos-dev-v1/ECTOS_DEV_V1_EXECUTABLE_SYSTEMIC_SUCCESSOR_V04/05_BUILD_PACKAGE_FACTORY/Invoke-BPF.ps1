Set-StrictMode -Version Latest

function Get-ECTOSBpfSha256Text {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Get-ECTOSBpfMemberSet {
    param([Parameter(Mandatory=$true)][string]$Root)
    $rootPath=(Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $records=@()
    foreach($file in @(Get-ChildItem -LiteralPath $rootPath -Recurse -File | Sort-Object FullName)) {
        $relative=$file.FullName.Substring($rootPath.Length).TrimStart('\').Replace('\','/')
        $records += [pscustomobject][ordered]@{path=$relative;size_bytes=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    }
    $builder=New-Object Text.StringBuilder
    foreach($record in @($records | Sort-Object path)) {
        [void]$builder.Append([string]$record.path);[void]$builder.Append([char]0);[void]$builder.Append([string]$record.size_bytes);[void]$builder.Append([char]0);[void]$builder.Append([string]$record.sha256);[void]$builder.Append([char]10)
    }
    [pscustomobject][ordered]@{records=@($records | Sort-Object path);member_set_sha256=(Get-ECTOSBpfSha256Text -Text $builder.ToString())}
}

function Write-ECTOSDeterministicZip {
    param([Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string]$ZipPath)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if(Test-Path -LiteralPath $ZipPath){throw 'BPF_ARCHIVE_ALREADY_EXISTS'}
    $root=(Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\')
    $stream=[IO.File]::Open($ZipPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $archive=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
        foreach($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName)) {
            $relative=$file.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
            $entry=$archive.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime=[DateTimeOffset]::Parse('2000-01-01T00:00:00Z')
            try { $entry.ExternalAttributes=0 } catch { Write-Verbose $_.Exception.Message }
            $inputStream=[IO.File]::OpenRead($file.FullName);$output=$entry.Open()
            try { $inputStream.CopyTo($output) } finally { $output.Dispose();$inputStream.Dispose() }
        }
    } finally { $archive.Dispose();$stream.Dispose() }
}

function Invoke-ECTOSBPF {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$BuildPlan,
        [Parameter(Mandatory=$true)][string]$WorkspaceRoot,
        [Parameter(Mandatory=$true)][string]$RepositoryRoot
    )
    if([string]$BuildPlan.closure_state -ne 'PASS_PHYSICALLY_PROVEN'){throw 'BPF_BUILD_PLAN_NOT_CLOSED'}
    if([string]::IsNullOrWhiteSpace($WorkspaceRoot)){throw 'BPF_WORKSPACE_ROOT_EMPTY'}
    if(-not(Test-Path -LiteralPath $WorkspaceRoot -PathType Container)){New-Item -ItemType Directory -Path $WorkspaceRoot -Force|Out-Null}
    $packageRoot=Join-Path $WorkspaceRoot ([string]$BuildPlan.package_id)
    $zipPath=$packageRoot+'.zip'
    if(Test-Path -LiteralPath $packageRoot -or Test-Path -LiteralPath $zipPath){throw 'BPF_OUTPUT_ALREADY_EXISTS'}
    New-Item -ItemType Directory -Path $packageRoot -Force|Out-Null
    $sourceRootFull=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot ([string]$BuildPlan.source_root))).TrimEnd('\')
    $sourceRootBoundary=$sourceRootFull+'\'
    $verification=@()
    foreach($expected in @($BuildPlan.exact_source_hash_set | Sort-Object path)) {
        $relative=[string]$expected.path
        $source=[IO.Path]::GetFullPath((Join-Path $sourceRootFull $relative))
        if(-not $source.StartsWith($sourceRootBoundary,[StringComparison]::OrdinalIgnoreCase)){throw ('BPF_SOURCE_PATH_ESCAPE:'+$relative)}
        if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw ('BPF_SOURCE_FILE_NOT_FOUND:'+$relative)}
        $preHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if($preHash -ne [string]$expected.sha256){throw ('BPF_SOURCE_PRECOPY_HASH_MISMATCH:'+$relative)}
        $destination=Join-Path $packageRoot $relative;$parent=Split-Path -Parent $destination
        if(-not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
        [IO.File]::WriteAllBytes($destination,[IO.File]::ReadAllBytes($source))
        $postHash=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if($postHash -ne $preHash){throw ('BPF_POSTCOPY_HASH_MISMATCH:'+$relative)}
        $verification += [pscustomobject][ordered]@{path=$relative;authorized_sha256=[string]$expected.sha256;precopy_sha256=$preHash;postcopy_sha256=$postHash;match=$true}
    }
    $outputManifestPath=Join-Path $packageRoot 'ECTOS_BUILD_OUTPUT_MANIFEST.json'
    $outputManifest=[pscustomobject][ordered]@{schema_id='ECTOS_BUILD_OUTPUT_MANIFEST_V02';package_id=[string]$BuildPlan.package_id;version=[string]$BuildPlan.package_version;build_plan_identity=[string]$BuildPlan.build_plan_identity;source_verification=@($verification)}
    [IO.File]::WriteAllText($outputManifestPath,($outputManifest|ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    $memberSet=Get-ECTOSBpfMemberSet -Root $packageRoot
    Write-ECTOSDeterministicZip -SourceRoot $packageRoot -ZipPath $zipPath
    $zipHash=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    $contentIdentity=Get-ECTOSBpfSha256Text -Text ('ECTOS_BPF_PACKAGE_CONTENT_V03'+[char]0+$memberSet.member_set_sha256+[char]0+$zipHash)
    [pscustomobject][ordered]@{
        schema_id='ECTOS_BPF_RESULT_V03';contract_id='ECTOS_BPF_DETERMINISTIC_MATERIALIZATION_V03';closure_state='PASS_PHYSICALLY_PROVEN'
        package_id=[string]$BuildPlan.package_id;package_root=$packageRoot;package_zip=$zipPath;package_sha256=$zipHash
        package_member_set_sha256=[string]$memberSet.member_set_sha256;package_member_count=@($memberSet.records).Count;package_members=@($memberSet.records)
        package_content_identity=$contentIdentity;build_output_manifest=$outputManifestPath;source_verification=@($verification)
        fixed_archive_timestamp_utc='2000-01-01T00:00:00Z';archive_member_order='CANONICAL_RELATIVE_PATH_ASCENDING'
    }
}
