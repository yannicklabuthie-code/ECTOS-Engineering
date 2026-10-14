Set-StrictMode -Version Latest

function ConvertTo-ECTOSRawZipCanonicalObject {
    param($Value)
    if($null -eq $Value) { return $null }
    if($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        [string[]]$names = @($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($names,[System.StringComparer]::Ordinal)
        foreach($name in $names) { $result[$name] = ConvertTo-ECTOSRawZipCanonicalObject -Value $Value[$name] }
        return $result
    }
    if($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        [string[]]$names = @($Value.PSObject.Properties.Name)
        [Array]::Sort($names,[System.StringComparer]::Ordinal)
        foreach($name in $names) { $result[$name] = ConvertTo-ECTOSRawZipCanonicalObject -Value $Value.$name }
        return $result
    }
    if($Value -is [System.Array] -or $Value -is [System.Collections.ArrayList]) {
        $items = @()
        foreach($item in @($Value)) { $items += ,(ConvertTo-ECTOSRawZipCanonicalObject -Value $item) }
        return ,$items
    }
    return $Value
}

function Get-ECTOSRawZipTextSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($Text)
        return (ConvertTo-ECTOSRawZipHex -Bytes $sha.ComputeHash($bytes))
    }
    finally { $sha.Dispose() }
}

function ConvertTo-ECTOSRawZipFieldEvidence {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][string]$Type,
        [Parameter(Mandatory=$true)][bool]$Required,
        [Parameter(Mandatory=$true)][bool]$Nullable,
        [Parameter(Mandatory=$true)][uint64]$SourceOffset,
        [Parameter(Mandatory=$true)][uint64]$SourceLength,
        $NormalizedValue,
        [string]$ProofState = 'PHYSICALLY_PARSED'
    )
    $bytes = Read-ECTOSRawZipByteRange -Stream $Stream -Offset $SourceOffset -Length $SourceLength -Stage 'EVIDENCE_EMISSION'
    return [pscustomobject][ordered]@{
        type = $Type
        required = $Required
        nullable = $Nullable
        source_offset = [string]$SourceOffset
        source_length = [string]$SourceLength
        raw_value = (ConvertTo-ECTOSRawZipHex -Bytes $bytes)
        normalized_value = $NormalizedValue
        proof_state = $ProofState
    }
}

function ConvertTo-ECTOSRawZipExtraFieldEvidence {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Fields)
    $output = @()
    foreach($field in $Fields) {
        $output += ,[pscustomobject][ordered]@{
            header_id = [int]$field.header_id
            data_size = [int]$field.data_size
            source_offset = [string]$field.source_offset
            source_length = [string]$field.source_length
            raw_value = [string]$field.raw_value
            data_raw_value = [string]$field.data_raw_value
            normalized_value = $null
            proof_state = 'PHYSICALLY_PARSED'
        }
    }
    return ,$output
}

function ConvertTo-ECTOSRawZipEvidence {
    param(
        [Parameter(Mandatory=$true)]$Structure,
        [Parameter(Mandatory=$true)]$Validation,
        [Parameter(Mandatory=$true)][string]$ToolSha256,
        [Parameter(Mandatory=$true)]$RuntimeIdentity,
        [Parameter(Mandatory=$true)]$Currentness
    )
    $stream = $null
    try {
        $stream = [System.IO.File]::Open([string]$Structure.input_path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
        $archive = $Structure.archive
        [uint64]$eocdOffset = [uint64]$archive.eocd_offset
        $archiveFields = [pscustomobject][ordered]@{
            signature = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset $eocdOffset -SourceLength 4 -NormalizedValue '0x06054B50'
            disk_number = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+4) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+4) -Stage 'EVIDENCE_EMISSION'))
            central_disk = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+6) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+6) -Stage 'EVIDENCE_EMISSION'))
            entries_this_disk = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+8) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+8) -Stage 'EVIDENCE_EMISSION'))
            entry_count_16 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+10) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+10) -Stage 'EVIDENCE_EMISSION'))
            central_directory_size_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+12) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($eocdOffset+12) -Stage 'EVIDENCE_EMISSION'))
            central_directory_offset_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+16) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($eocdOffset+16) -Stage 'EVIDENCE_EMISSION'))
            archive_comment_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($eocdOffset+20) -SourceLength 2 -NormalizedValue ([string](([string]$archive.archive_comment_raw).Length/2))
        }

        $zip64Evidence = $null
        if($null -ne $archive.zip64) {
            [uint64]$zip64LocatorOffset = [uint64]$archive.zip64.locator_offset
            [uint64]$zip64EocdOffset = [uint64]$archive.zip64.eocd_offset
            [uint64]$zip64EocdLength = [uint64]$archive.zip64.eocd_length
            $zip64Evidence = [pscustomobject][ordered]@{
                locator_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'ZIP64_LOCATOR_RAW' -Required $true -Nullable $false -SourceOffset $zip64LocatorOffset -SourceLength 20 -NormalizedValue ([pscustomobject][ordered]@{offset=[string]$zip64LocatorOffset})
                zip64_eocd_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'ZIP64_EOCD_RAW' -Required $true -Nullable $false -SourceOffset $zip64EocdOffset -SourceLength $zip64EocdLength -NormalizedValue ([pscustomobject][ordered]@{offset=[string]$zip64EocdOffset;length=[string]$zip64EocdLength;entry_count=[string]$archive.zip64.entry_count;central_directory_size=[string]$archive.zip64.central_directory_size;central_directory_offset=[string]$archive.zip64.central_directory_offset})
            }
        }

        $entryEvidence = @()
        foreach($entry in @($Structure.entries)) {
            [uint64]$centralOffset = [uint64]$entry.central_directory_offset
            [uint64]$localOffset = [uint64]$entry.local_header_offset
            $normalizedPath = ([string]$entry.decoded_filename).Replace('\','/')

            $centralNameLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralOffset+28) -Stage 'EVIDENCE_EMISSION'
            $centralExtraLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralOffset+30) -Stage 'EVIDENCE_EMISSION'
            $centralCommentLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralOffset+32) -Stage 'EVIDENCE_EMISSION'
            [uint64]$centralNameOffset = $centralOffset + 46
            [uint64]$centralExtraOffset = $centralNameOffset + [uint64]$centralNameLength
            [uint64]$centralCommentOffset = $centralExtraOffset + [uint64]$centralExtraLength

            $localNameLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localOffset+26) -Stage 'EVIDENCE_EMISSION'
            $localExtraLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localOffset+28) -Stage 'EVIDENCE_EMISSION'
            [uint64]$localNameOffset = $localOffset + 30

            $centralFields = [pscustomobject][ordered]@{
                signature = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset $centralOffset -SourceLength 4 -NormalizedValue '0x02014B50'
                version_made_by = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+4) -SourceLength 2 -NormalizedValue ([string]$entry.version_made_by)
                version_needed = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+6) -SourceLength 2 -NormalizedValue ([string]$entry.version_needed)
                general_purpose_flags = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+8) -SourceLength 2 -NormalizedValue ([string]$entry.general_purpose_flags)
                compression_method = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+10) -SourceLength 2 -NormalizedValue ([string]$entry.compression_method)
                last_mod_time_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+12) -SourceLength 2 -NormalizedValue ([string]$entry.last_mod_time_raw)
                last_mod_date_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+14) -SourceLength 2 -NormalizedValue ([string]$entry.last_mod_date_raw)
                crc32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+16) -SourceLength 4 -NormalizedValue ([string]$entry.crc32)
                compressed_size_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+20) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralOffset+20) -Stage 'EVIDENCE_EMISSION'))
                uncompressed_size_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+24) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralOffset+24) -Stage 'EVIDENCE_EMISSION'))
                filename_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+28) -SourceLength 2 -NormalizedValue ([string]$centralNameLength)
                extra_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+30) -SourceLength 2 -NormalizedValue ([string]$centralExtraLength)
                comment_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+32) -SourceLength 2 -NormalizedValue ([string]$centralCommentLength)
                disk_start = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+34) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralOffset+34) -Stage 'EVIDENCE_EMISSION'))
                internal_attributes = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+36) -SourceLength 2 -NormalizedValue ([string]$entry.internal_attributes)
                external_attributes = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+38) -SourceLength 4 -NormalizedValue ([string]$entry.external_attributes)
                local_header_offset_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($centralOffset+42) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralOffset+42) -Stage 'EVIDENCE_EMISSION'))
            }

            $localFields = [pscustomobject][ordered]@{
                signature = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset $localOffset -SourceLength 4 -NormalizedValue '0x04034B50'
                version_needed = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+4) -SourceLength 2 -NormalizedValue ([string]$entry.local_version_needed)
                general_purpose_flags = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+6) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localOffset+6) -Stage 'EVIDENCE_EMISSION'))
                compression_method = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+8) -SourceLength 2 -NormalizedValue ([string](Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localOffset+8) -Stage 'EVIDENCE_EMISSION'))
                last_mod_time_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+10) -SourceLength 2 -NormalizedValue ([string]$entry.local_last_mod_time_raw)
                last_mod_date_raw = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+12) -SourceLength 2 -NormalizedValue ([string]$entry.local_last_mod_date_raw)
                crc32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+14) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localOffset+14) -Stage 'EVIDENCE_EMISSION'))
                compressed_size_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+18) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localOffset+18) -Stage 'EVIDENCE_EMISSION'))
                uncompressed_size_32 = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT32_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+22) -SourceLength 4 -NormalizedValue ([string](Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localOffset+22) -Stage 'EVIDENCE_EMISSION'))
                filename_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+26) -SourceLength 2 -NormalizedValue ([string]$localNameLength)
                extra_length = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'UINT16_LE' -Required $true -Nullable $false -SourceOffset ($localOffset+28) -SourceLength 2 -NormalizedValue ([string]$localExtraLength)
            }

            $descriptorEvidence = $null
            if([bool]$entry.data_descriptor_present -and $null -ne $entry.data_descriptor) {
                [uint64]$descriptorOffset = [uint64]$entry.data_descriptor.offset
                [uint64]$descriptorLength = [uint64]$entry.data_descriptor.length
                $descriptorEvidence = [pscustomobject][ordered]@{
                    raw_record = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'DATA_DESCRIPTOR_RAW' -Required $true -Nullable $false -SourceOffset $descriptorOffset -SourceLength $descriptorLength -NormalizedValue ([pscustomobject][ordered]@{signature_present=[bool]$entry.data_descriptor.signature_present;crc32=[string]$entry.data_descriptor.crc32;compressed_size=[string]$entry.data_descriptor.compressed_size;uncompressed_size=[string]$entry.data_descriptor.uncompressed_size})
                }
            }

            $entryEvidence += ,[pscustomobject][ordered]@{
                entry_index = [string]$entry.entry_index
                local_header_offset = [string]$entry.local_header_offset
                local_header_length = [string]$entry.local_header_length
                central_directory_offset = [string]$entry.central_directory_offset
                central_directory_length = [string]$entry.central_directory_length
                central_filename = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'BYTE_SEQUENCE' -Required $true -Nullable $false -SourceOffset $centralNameOffset -SourceLength ([uint64]$centralNameLength) -NormalizedValue ([string]$entry.decoded_filename)
                local_filename = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'BYTE_SEQUENCE' -Required $true -Nullable $false -SourceOffset $localNameOffset -SourceLength ([uint64]$localNameLength) -NormalizedValue $null
                central_comment = ConvertTo-ECTOSRawZipFieldEvidence -Stream $stream -Type 'BYTE_SEQUENCE' -Required $true -Nullable $true -SourceOffset $centralCommentOffset -SourceLength ([uint64]$centralCommentLength) -NormalizedValue $entry.comment
                raw_filename_bytes = [string]$entry.raw_filename_bytes
                decoded_filename = [string]$entry.decoded_filename
                normalized_path = $normalizedPath
                utf8_flag = [bool]$entry.utf8_flag
                creator_system = [int]$entry.creator_system
                crc32 = [string]$entry.crc32
                compressed_size = [string]$entry.compressed_size
                uncompressed_size = [string]$entry.uncompressed_size
                local_compressed_size = [string]$entry.local_compressed_size
                local_uncompressed_size = [string]$entry.local_uncompressed_size
                local_extra_fields = @(ConvertTo-ECTOSRawZipExtraFieldEvidence -Fields @($entry.local_extra_fields))
                central_extra_fields = @(ConvertTo-ECTOSRawZipExtraFieldEvidence -Fields @($entry.central_extra_fields))
                internal_attributes = [string]$entry.internal_attributes
                external_attributes = [string]$entry.external_attributes
                raw_comment_bytes = [string]$entry.raw_comment_bytes
                comment = $entry.comment
                data_descriptor_present = [bool]$entry.data_descriptor_present
                data_descriptor = $descriptorEvidence
                zip64_usage = [bool]$entry.zip64_usage
                raw_data_offset = [string]$entry.raw_data_offset
                raw_compressed_data_length = [string]$entry.raw_compressed_data_length
                raw_compressed_data_sha256 = [string]$entry.raw_compressed_data_sha256
                central_fields = $centralFields
                local_fields = $localFields
                proof_state = 'PHYSICALLY_PARSED'
            }
        }

        $timestamp = [DateTime]::UtcNow.ToString('o')
        $evidence = [pscustomobject][ordered]@{
            schema_id = 'ECTOS_RAW_ZIP_EVIDENCE_V01'
            schema_version = '1.0.0'
            tool_id = 'ECTOS_RAW_ZIP_EVIDENCE_PARSER'
            tool_version = '2.1.0'
            tool_sha256 = $ToolSha256
            runtime_identity = $RuntimeIdentity
            input_path = [string]$Structure.input_path
            input_size = [string]$Structure.input_size
            input_sha256 = [string]$Structure.input_sha256
            parse_status = [string]$Validation.parse_status
            failure_count = [int]$Validation.failure_count
            failures = @($Validation.failures)
            archive = [pscustomobject][ordered]@{
                archive_size = [string]$archive.archive_size
                archive_sha256 = [string]$archive.archive_sha256
                entry_count = [string]$archive.entry_count
                eocd_offset = [string]$archive.eocd_offset
                eocd_size = [string]$archive.eocd_size
                central_directory_offset = [string]$archive.central_directory_offset
                central_directory_size = [string]$archive.central_directory_size
                archive_comment_raw = [string]$archive.archive_comment_raw
                archive_comment = $archive.archive_comment
                trailing_byte_count = [string]$archive.trailing_byte_count
                unclassified_byte_count = [string]$archive.unclassified_byte_count
                zip64 = $zip64Evidence
                eocd_fields = $archiveFields
            }
            entries = @($entryEvidence)
            coverage = $Validation.coverage
            currentness = $Currentness
            evidence_content_identity_sha256 = $null
            timestamp_utc = $timestamp
        }

        $identityObject = [ordered]@{}
        foreach($property in $evidence.PSObject.Properties) {
            if($property.Name -ne 'timestamp_utc' -and $property.Name -ne 'input_path' -and $property.Name -ne 'evidence_content_identity_sha256') {
                $identityObject[$property.Name] = $property.Value
            }
        }
        $canonical = ConvertTo-ECTOSRawZipCanonicalObject -Value $identityObject
        $canonicalJson = $canonical | ConvertTo-Json -Depth 64 -Compress
        $evidence.evidence_content_identity_sha256 = Get-ECTOSRawZipTextSha256 -Text $canonicalJson
        return $evidence
    }
    finally {
        if($null -ne $stream) { $stream.Dispose() }
    }
}

function Write-ECTOSRawZipEvidenceFile {
    param(
        [Parameter(Mandatory=$true)]$Evidence,
        [Parameter(Mandatory=$true)][string]$Path
    )
    try {
        if(Test-Path -LiteralPath $Path) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_EVIDENCE_EMISSION_ERROR' -Stage 'OUTPUT' -Message 'Evidence output path already exists.'
        }
        $parent = Split-Path -Parent $Path
        if([string]::IsNullOrWhiteSpace($parent)) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_EVIDENCE_EMISSION_ERROR' -Stage 'OUTPUT' -Message 'Evidence output parent path is empty.'
        }
        if(-not(Test-Path -LiteralPath $parent -PathType Container)) {
            [void][System.IO.Directory]::CreateDirectory($parent)
        }
        $json = $Evidence | ConvertTo-Json -Depth 64
        [System.IO.File]::WriteAllText($Path,$json,(New-Object System.Text.UTF8Encoding($false)))
    }
    catch {
        if($_.Exception.Data.Contains('ECTOSFailureId')) { throw }
        Write-ECTOSRawZipFailure -FailureId 'RZP_EVIDENCE_EMISSION_ERROR' -Stage 'OUTPUT' -Message $_.Exception.Message
    }
}
