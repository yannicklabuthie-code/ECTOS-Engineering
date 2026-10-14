[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InputPath,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$EvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $toolRoot '02_CORE'
. (Join-Path $coreRoot 'Read-ECTOSZipPrimitive.ps1')
. (Join-Path $coreRoot 'Read-ECTOSZipStructure.ps1')
. (Join-Path $coreRoot 'Test-ECTOSZipStructure.ps1')
. (Join-Path $coreRoot 'ConvertTo-ECTOSZipEvidence.ps1')

function Get-ECTOSRawZipToolSourceIdentity {
    param([Parameter(Mandatory=$true)][string]$Root)
    $relativePaths = @(
        '01_TOOL/Invoke-ECTOSRawZipEvidenceParser.ps1',
        '02_CORE/ConvertTo-ECTOSZipEvidence.ps1',
        '02_CORE/Read-ECTOSZipPrimitive.ps1',
        '02_CORE/Read-ECTOSZipStructure.ps1',
        '02_CORE/Test-ECTOSZipStructure.ps1'
    ) | Sort-Object
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $memory = New-Object System.IO.MemoryStream
    try {
        foreach($relativePath in $relativePaths) {
            $fullPath = Join-Path $Root ($relativePath.Replace('/','\'))
            if(-not(Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                throw ('ECTOS_RAW_ZIP_TOOL_SOURCE_MISSING:' + $relativePath)
            }
            $pathBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($relativePath)
            $memory.Write($pathBytes,0,$pathBytes.Length)
            $memory.WriteByte(0)
            $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
            $memory.Write($fileBytes,0,$fileBytes.Length)
            $memory.WriteByte(0)
        }
        $memory.Position = 0
        return (ConvertTo-ECTOSRawZipHex -Bytes $sha.ComputeHash($memory))
    }
    finally {
        $memory.Dispose()
        $sha.Dispose()
    }
}

if([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'ECTOS_RAW_ZIP_RUNTIME_NOT_WINDOWS_POWERSHELL_DESKTOP_5_1'
}

$toolSha256 = Get-ECTOSRawZipToolSourceIdentity -Root $toolRoot
$runtimeIdentity = [pscustomobject][ordered]@{
    psedition = [string]$PSVersionTable.PSEdition
    powershell_version = [string]$PSVersionTable.PSVersion
    clr_version = [string]$PSVersionTable.CLRVersion
    os_version = [Environment]::OSVersion.VersionString
    process_architecture = [string][IntPtr]::Size
}
$currentness = [pscustomobject][ordered]@{
    code_rule_selector = 'ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json'
    code_rule_pointer = 'ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V02.json'
    powershell_profile = 'ECTOS_POWERSHELL_PS51_PROFILE'
    powershell_profile_version = 'V01'
    ruleset_version = 'V01'
    qualification_state = 'NOT_QUALIFIED_BY_PRODUCER_EXECUTION'
}

try {
    $structure = Read-ECTOSRawZipStructure -Path $InputPath
    $validation = Test-ECTOSRawZipStructure -Structure $structure
    $evidence = ConvertTo-ECTOSRawZipEvidence -Structure $structure -Validation $validation -ToolSha256 $toolSha256 -RuntimeIdentity $runtimeIdentity -Currentness $currentness
    Write-ECTOSRawZipEvidenceFile -Evidence $evidence -Path $EvidencePath
    if([string]$evidence.parse_status -eq 'PASS') { exit 0 }
    exit 40
}
catch {
    $failureId = 'RZP_EVIDENCE_EMISSION_ERROR'
    $failureStage = 'ENTRYPOINT'
    if($_.Exception.Data.Contains('ECTOSFailureId')) {
        $failureId = [string]$_.Exception.Data['ECTOSFailureId']
        $failureStage = [string]$_.Exception.Data['ECTOSFailureStage']
    }
    $failure = [pscustomobject][ordered]@{
        error_id = $failureId
        detection_condition = $_.Exception.Message
        failure_stage = $failureStage
        output_state = 'FAIL'
        continue_analysis_allowed = $false
        source_offset = '0'
    }
    $timestamp = [DateTime]::UtcNow.ToString('o')
    $failureEvidence = [pscustomobject][ordered]@{
        schema_id = 'ECTOS_RAW_ZIP_EVIDENCE_V01'
        schema_version = '1.0.0'
        tool_id = 'ECTOS_RAW_ZIP_EVIDENCE_PARSER'
        tool_version = '2.1.0'
        tool_sha256 = $toolSha256
        runtime_identity = $runtimeIdentity
        input_path = $InputPath
        input_size = $null
        input_sha256 = $null
        parse_status = 'FAIL'
        failure_count = 1
        failures = @($failure)
        archive = $null
        entries = @()
        coverage = [pscustomobject][ordered]@{complete=$false}
        currentness = $currentness
        evidence_content_identity_sha256 = $null
        timestamp_utc = $timestamp
    }
    try {
        $identityObject = [ordered]@{}
        foreach($property in $failureEvidence.PSObject.Properties) {
            if($property.Name -ne 'timestamp_utc' -and $property.Name -ne 'input_path' -and $property.Name -ne 'evidence_content_identity_sha256') {
                $identityObject[$property.Name] = $property.Value
            }
        }
        $canonical = ConvertTo-ECTOSRawZipCanonicalObject -Value $identityObject
        $canonicalJson = $canonical | ConvertTo-Json -Depth 64 -Compress
        $failureEvidence.evidence_content_identity_sha256 = Get-ECTOSRawZipTextSha256 -Text $canonicalJson
        Write-ECTOSRawZipEvidenceFile -Evidence $failureEvidence -Path $EvidencePath
    }
    catch {
        $fallbackJson = $failureEvidence | ConvertTo-Json -Depth 64 -Compress
        [Console]::Error.WriteLine($fallbackJson)
    }
    exit 40
}
