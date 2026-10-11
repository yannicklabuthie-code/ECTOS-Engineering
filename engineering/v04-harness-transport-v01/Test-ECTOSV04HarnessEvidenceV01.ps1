[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EvidenceRoot
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

function Get-Sha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

if(-not(Test-Path -LiteralPath $EvidenceRoot -PathType Container)){ throw 'EVIDENCE_ROOT_NOT_FOUND' }
$resultPath=Join-Path $EvidenceRoot 'result.json'
$invocationPath=Join-Path $EvidenceRoot 'invocation.json'
$stdoutPath=Join-Path $EvidenceRoot 'stdout.txt'
$stderrPath=Join-Path $EvidenceRoot 'stderr.txt'
$outputManifestPath=Join-Path $EvidenceRoot 'output-manifest.json'

foreach($requiredPath in @($resultPath,$invocationPath,$stdoutPath,$stderrPath,$outputManifestPath)){
    if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){
        throw ('REQUIRED_EVIDENCE_MEMBER_MISSING_'+[IO.Path]::GetFileName($requiredPath))
    }
}

$result=Get-Content -LiteralPath $resultPath -Raw -ErrorAction Stop|ConvertFrom-Json
if([string]$result.schema -cne 'ECTOS_V04_HARNESS_TRANSPORT_RESULT_V01'){ throw 'RESULT_SCHEMA_MISMATCH' }
if((Get-Sha256 -Path $invocationPath) -cne [string]$result.invocation_sha256){ throw 'INVOCATION_HASH_MISMATCH' }
if((Get-Sha256 -Path $stdoutPath) -cne [string]$result.stdout_sha256){ throw 'STDOUT_HASH_MISMATCH' }
if((Get-Sha256 -Path $stderrPath) -cne [string]$result.stderr_sha256){ throw 'STDERR_HASH_MISMATCH' }
if((Get-Sha256 -Path $outputManifestPath) -cne [string]$result.output_manifest_sha256){ throw 'OUTPUT_MANIFEST_HASH_MISMATCH' }

$invocation=Get-Content -LiteralPath $invocationPath -Raw -ErrorAction Stop|ConvertFrom-Json
if([string]$invocation.transport_type -cne 'NATIVE_PS51_FILE_ARGUMENT_VECTOR'){ throw 'TRANSPORT_TYPE_MISMATCH' }
if([bool]$invocation.encoded_command_retained){ throw 'ENCODEDCOMMAND_MUST_NOT_BE_RETAINED' }
if([bool]$invocation.automatic_retry){ throw 'AUTOMATIC_RETRY_MUST_BE_FALSE' }
if(@($invocation.argument_vector).Count -ne 11){ throw 'ARGUMENT_VECTOR_CARDINALITY_MISMATCH' }
if([string]$invocation.argument_vector[0] -cne '-NoLogo'){ throw 'ARGUMENT_VECTOR_NOLOGO_MISMATCH' }
if([string]$invocation.argument_vector[5] -cne '-File'){ throw 'ARGUMENT_VECTOR_FILE_TRANSPORT_MISSING' }

$outputManifest=Get-Content -LiteralPath $outputManifestPath -Raw -ErrorAction Stop|ConvertFrom-Json
$outputRoot=Join-Path $EvidenceRoot 'child-output'
$members=@($outputManifest.members)
if([int]$outputManifest.member_count -ne $members.Count){ throw 'OUTPUT_MANIFEST_MEMBER_COUNT_MISMATCH' }
foreach($member in $members){
    $memberPath=Join-Path $outputRoot ([string]$member.relative_path)
    if(-not(Test-Path -LiteralPath $memberPath -PathType Leaf)){ throw ('OUTPUT_MEMBER_MISSING_'+[string]$member.relative_path) }
    $item=Get-Item -LiteralPath $memberPath -ErrorAction Stop
    if([int64]$item.Length -ne [int64]$member.size_bytes){ throw ('OUTPUT_MEMBER_SIZE_MISMATCH_'+[string]$member.relative_path) }
    if((Get-Sha256 -Path $memberPath) -cne [string]$member.sha256){ throw ('OUTPUT_HASH_MISMATCH_'+[string]$member.relative_path) }
}

Write-Output 'ECTOS_HARNESS_EVIDENCE_VERIFY=PASS'
