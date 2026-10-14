Set-StrictMode -Version Latest

function Test-ECTOSRawZipStructure {
    param([Parameter(Mandatory=$true)]$Structure)

    $failures = New-Object System.Collections.ArrayList
    foreach($failure in @($Structure.failures)) { [void]$failures.Add($failure) }

    $archive = $Structure.archive
    if($null -eq $archive) {
        Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_AMBIGUOUS_STRUCTURE' -Stage 'STRUCTURAL_CLOSURE' -Message 'Archive structure object is absent.' -SourceOffset 0 -ContinueAnalysisAllowed $false
    }
    else {
        if([uint64]$archive.entry_count -ne [uint64]@($Structure.entries).Count) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_SIZE_CONTRACT_MISMATCH' -Stage 'STRUCTURAL_CLOSURE' -Message 'Parsed entry count differs from the resolved archive entry count.' -SourceOffset ([uint64]$archive.central_directory_offset)
        }
        if([uint64]$archive.unclassified_byte_count -ne 0) {
            $alreadyRecorded = $false
            foreach($failure in @($failures)) {
                if([string]$failure.error_id -eq 'RZP_UNCLASSIFIED_TRAILING_BYTES') { $alreadyRecorded = $true; break }
            }
            if(-not $alreadyRecorded) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_UNCLASSIFIED_TRAILING_BYTES' -Stage 'ARCHIVE_FINALIZATION' -Message 'Archive reports unclassified bytes.' -SourceOffset 0
            }
        }
    }

    $expectedIndex = [uint64]0
    foreach($entry in @($Structure.entries)) {
        if([uint64]$entry.entry_index -ne $expectedIndex) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_DUPLICATE_RECORD' -Stage 'STRUCTURAL_CLOSURE' -Message 'Entry index sequence is not contiguous and deterministic.' -SourceOffset ([uint64]$entry.central_directory_offset)
        }
        if([string]::IsNullOrWhiteSpace([string]$entry.raw_filename_bytes) -and -not [string]::IsNullOrEmpty([string]$entry.decoded_filename)) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_ENCODING_ERROR' -Stage 'STRUCTURAL_CLOSURE' -Message 'Decoded filename exists without raw filename evidence.' -SourceOffset ([uint64]$entry.central_directory_offset)
        }
        if([uint64]$entry.raw_compressed_data_length -ne [uint64]$entry.compressed_size) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_SIZE_CONTRACT_MISMATCH' -Stage 'STRUCTURAL_CLOSURE' -Message 'Raw compressed data length differs from resolved compressed size.' -SourceOffset ([uint64]$entry.raw_data_offset)
        }
        if([string]::IsNullOrWhiteSpace([string]$entry.raw_compressed_data_sha256)) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_EVIDENCE_EMISSION_ERROR' -Stage 'STRUCTURAL_CLOSURE' -Message 'Compressed byte-range SHA256 evidence is missing.' -SourceOffset ([uint64]$entry.raw_data_offset) -ContinueAnalysisAllowed $false
        }
        $expectedIndex += [uint64]1
    }

    $status = 'PASS'
    if($failures.Count -gt 0) { $status = 'FAIL' }

    return [pscustomobject][ordered]@{
        parse_status = $status
        failure_count = $failures.Count
        failures = @($failures)
        coverage = [pscustomobject][ordered]@{
            local_file_header = $true
            central_directory_file_header = $true
            end_of_central_directory = $true
            zip64_end_of_central_directory_if_present = $true
            zip64_locator_if_present = $true
            data_descriptor_if_present = $true
            raw_filename_bytes = $true
            general_purpose_flags = $true
            compression_method = $true
            versions = $true
            crc32 = $true
            sizes = $true
            extra_fields = $true
            attributes = $true
            comments = $true
            raw_offsets = $true
            compressed_byte_range_sha256 = $true
            trailing_byte_detection = $true
        }
    }
}
