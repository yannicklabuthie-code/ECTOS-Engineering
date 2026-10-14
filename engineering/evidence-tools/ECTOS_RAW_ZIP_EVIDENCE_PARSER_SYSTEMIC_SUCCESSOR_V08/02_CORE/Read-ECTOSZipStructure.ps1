Set-StrictMode -Version Latest

function Add-ECTOSRawZipFailure {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.ArrayList]$FailureList,
        [Parameter(Mandatory=$true)][string]$FailureId,
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][string]$Message,
        [uint64]$SourceOffset = 0,
        [bool]$ContinueAnalysisAllowed = $true
    )
    $record = [pscustomobject][ordered]@{
        error_id = $FailureId
        detection_condition = $Message
        failure_stage = (Get-ECTOSRawZipCanonicalFailureStage -FailureId $FailureId)
        operation_stage = $Stage
        output_state = 'FAIL'
        continue_analysis_allowed = $ContinueAnalysisAllowed
        source_offset = ([string]$SourceOffset)
    }
    [void]$FailureList.Add($record)
}

function Read-ECTOSRawZipExtraFieldSet {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes,
        [Parameter(Mandatory=$true)][uint64]$AbsoluteOffset,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $records = New-Object System.Collections.ArrayList
    $cursor = 0
    while($cursor -lt $Bytes.Length) {
        if(($Bytes.Length - $cursor) -lt 4) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_MALFORMED_EXTRA_FIELD' -Stage $Stage -Message 'Extra field terminates inside the four-byte TLV header.'
        }
        $headerId = Read-ECTOSRawZipBufferUInt16LE -Bytes $Bytes -Offset $cursor -Stage $Stage
        $dataSize = Read-ECTOSRawZipBufferUInt16LE -Bytes $Bytes -Offset ($cursor+2) -Stage $Stage
        $dataOffset = $cursor + 4
        if([int]$dataSize -gt ($Bytes.Length - $dataOffset)) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_MALFORMED_EXTRA_FIELD' -Stage $Stage -Message 'Extra field declared data exceeds the bounded extra-field region.'
        }
        $dataBytes = New-Object byte[] ([int]$dataSize)
        if($dataSize -gt 0) {
            [Array]::Copy($Bytes,$dataOffset,$dataBytes,0,[int]$dataSize)
        }
        [int]$fieldLength = 4 + [int]$dataSize
        $fieldBytes = New-Object byte[] $fieldLength
        [Array]::Copy($Bytes,$cursor,$fieldBytes,0,$fieldLength)
        $record = [pscustomobject][ordered]@{
            header_id = [int]$headerId
            data_size = [int]$dataSize
            source_offset = ([string]($AbsoluteOffset + [uint64]$cursor))
            source_length = ([string]([uint64]$fieldLength))
            raw_value = (ConvertTo-ECTOSRawZipHex -Bytes $fieldBytes)
            data_raw_value = (ConvertTo-ECTOSRawZipHex -Bytes $dataBytes)
            data_bytes = $dataBytes
        }
        [void]$records.Add($record)
        $cursor = $dataOffset + [int]$dataSize
    }
    return ,@($records)
}

function Find-ECTOSRawZipEocd {
    param([Parameter(Mandatory=$true)][System.IO.Stream]$Stream)
    [uint64]$streamLength = [uint64]$Stream.Length
    if($streamLength -lt 22) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_EOCD' -Stage 'EOCD' -Message 'Input is shorter than the minimum EOCD record.'
    }
    [uint64]$windowLength = 65557
    if($streamLength -lt $windowLength) { $windowLength = $streamLength }
    [uint64]$windowOffset = $streamLength - $windowLength
    $tail = Read-ECTOSRawZipByteRange -Stream $Stream -Offset $windowOffset -Length $windowLength -Stage 'EOCD_SEARCH'
    $candidates = New-Object System.Collections.ArrayList
    $truncatedEocdFound = $false
    $truncatedScanStart = $tail.Length - 4
    $truncatedScanStop = [Math]::Max(0,$tail.Length - 21)
    for($scanIndex=$truncatedScanStart; $scanIndex -ge $truncatedScanStop; $scanIndex--) {
        if($tail[$scanIndex] -eq 0x50 -and $tail[$scanIndex+1] -eq 0x4B -and $tail[$scanIndex+2] -eq 0x05 -and $tail[$scanIndex+3] -eq 0x06) {
            $truncatedEocdFound = $true
            break
        }
    }
    for($index=$tail.Length-22; $index -ge 0; $index--) {
        if($tail[$index] -eq 0x50 -and $tail[$index+1] -eq 0x4B -and $tail[$index+2] -eq 0x05 -and $tail[$index+3] -eq 0x06) {
            $commentLength = Read-ECTOSRawZipBufferUInt16LE -Bytes $tail -Offset ($index+20) -Stage 'EOCD_SEARCH'
            [uint64]$candidateOffset = $windowOffset + [uint64]$index
            [uint64]$candidateLength = 22 + [uint64]$commentLength
            if($candidateLength -le ($streamLength - $candidateOffset)) {
                $entriesThisDisk = Read-ECTOSRawZipBufferUInt16LE -Bytes $tail -Offset ($index+8) -Stage 'EOCD_SEARCH'
                $entryCount = Read-ECTOSRawZipBufferUInt16LE -Bytes $tail -Offset ($index+10) -Stage 'EOCD_SEARCH'
                $centralSize = Read-ECTOSRawZipBufferUInt32LE -Bytes $tail -Offset ($index+12) -Stage 'EOCD_SEARCH'
                $centralOffset = Read-ECTOSRawZipBufferUInt32LE -Bytes $tail -Offset ($index+16) -Stage 'EOCD_SEARCH'
                $sentinel = ($entryCount -eq [uint16]0xFFFF -or $centralSize -eq [uint32]4294967295 -or $centralOffset -eq [uint32]4294967295)
                $plausible = $sentinel
                if(-not $sentinel) {
                    [uint64]$centralOffset64 = [uint64]$centralOffset
                    [uint64]$centralSize64 = [uint64]$centralSize
                    if($centralOffset64 -le $candidateOffset -and $centralSize64 -le ($candidateOffset - $centralOffset64) -and $entriesThisDisk -le $entryCount) {
                        $plausible = $true
                    }
                }
                if($plausible) {
                    [void]$candidates.Add([pscustomobject][ordered]@{offset=$candidateOffset;comment_length=[uint16]$commentLength;record_length=$candidateLength})
                }
            }
        }
    }
    if($candidates.Count -eq 0) {
        if($truncatedEocdFound) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_EOCD' -Stage 'EOCD' -Message 'An EOCD signature exists too close to EOF to contain the fixed EOCD record.'
        }
        Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_EOCD' -Stage 'EOCD' -Message 'No structurally plausible EOCD record was found in the maximum EOCD search window.'
    }
    if($candidates.Count -gt 1) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_AMBIGUOUS_STRUCTURE' -Stage 'EOCD' -Message 'Multiple structurally plausible EOCD records were found.'
    }
    return $candidates[0]
}
function Get-ECTOSRawZip64OverrideSet {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$ExtraFields,
        [Parameter(Mandatory=$true)][bool]$NeedUncompressed,
        [Parameter(Mandatory=$true)][bool]$NeedCompressed,
        [Parameter(Mandatory=$true)][bool]$NeedLocalOffset,
        [Parameter(Mandatory=$true)][bool]$NeedDiskStart,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $zip64 = $null
    foreach($field in $ExtraFields) {
        if([int]$field.header_id -eq 1) {
            if($null -ne $zip64) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_DUPLICATE_RECORD' -Stage $Stage -Message 'Multiple ZIP64 extra fields exist in one record.'
            }
            $zip64 = $field
        }
    }
    $required = $NeedUncompressed -or $NeedCompressed -or $NeedLocalOffset -or $NeedDiskStart
    if(-not $required -and $null -ne $zip64) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_UNEXPECTED_ZIP64' -Stage $Stage -Message 'ZIP64 extra field is present without a corresponding ZIP64 sentinel.'
    }
    if($required -and $null -eq $zip64) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage $Stage -Message 'ZIP64 sentinel is present without a ZIP64 extra field.'
    }
    if($null -eq $zip64) { return $null }
    $cursor = 0
    $bytes = [byte[]]$zip64.data_bytes
    $result = [ordered]@{}
    if($NeedUncompressed) {
        if(($bytes.Length-$cursor) -lt 8) { Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage $Stage -Message 'ZIP64 uncompressed-size override is truncated.' }
        $result.uncompressed_size = Read-ECTOSRawZipBufferUInt64LE -Bytes $bytes -Offset $cursor -Stage $Stage
        $cursor += 8
    }
    if($NeedCompressed) {
        if(($bytes.Length-$cursor) -lt 8) { Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage $Stage -Message 'ZIP64 compressed-size override is truncated.' }
        $result.compressed_size = Read-ECTOSRawZipBufferUInt64LE -Bytes $bytes -Offset $cursor -Stage $Stage
        $cursor += 8
    }
    if($NeedLocalOffset) {
        if(($bytes.Length-$cursor) -lt 8) { Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage $Stage -Message 'ZIP64 local-header-offset override is truncated.' }
        $result.local_header_offset = Read-ECTOSRawZipBufferUInt64LE -Bytes $bytes -Offset $cursor -Stage $Stage
        $cursor += 8
    }
    if($NeedDiskStart) {
        if(($bytes.Length-$cursor) -lt 4) { Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage $Stage -Message 'ZIP64 disk-start override is truncated.' }
        $result.disk_start = [uint64](Read-ECTOSRawZipBufferUInt32LE -Bytes $bytes -Offset $cursor -Stage $Stage)
        $cursor += 4
    }
    return [pscustomobject]$result
}

function Read-ECTOSRawZipDataDescriptorCandidate {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][bool]$Zip64,
        [Parameter(Mandatory=$true)][bool]$SignaturePresent
    )
    [uint64]$cursor = $Offset
    if($SignaturePresent) {
        $signature = Read-ECTOSRawZipUInt32LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'
        if($signature -ne [uint32]0x08074B50) { return $null }
        $cursor += 4
    }
    $crc = Read-ECTOSRawZipUInt32LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'
    $cursor += 4
    if($Zip64) {
        $compressed = Read-ECTOSRawZipUInt64LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'; $cursor += 8
        $uncompressed = Read-ECTOSRawZipUInt64LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'; $cursor += 8
    }
    else {
        $compressed = [uint64](Read-ECTOSRawZipUInt32LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'); $cursor += 4
        $uncompressed = [uint64](Read-ECTOSRawZipUInt32LE -Stream $Stream -Offset $cursor -Stage 'DATA_DESCRIPTOR'); $cursor += 4
    }
    return [pscustomobject][ordered]@{
        offset = $Offset
        length = ($cursor - $Offset)
        signature_present = $SignaturePresent
        crc32 = [uint32]$crc
        compressed_size = [uint64]$compressed
        uncompressed_size = [uint64]$uncompressed
    }
}

function Read-ECTOSRawZipDataDescriptor {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][bool]$Zip64,
        [Parameter(Mandatory=$true)][uint32]$ExpectedCrc32,
        [Parameter(Mandatory=$true)][uint64]$ExpectedCompressedSize,
        [Parameter(Mandatory=$true)][uint64]$ExpectedUncompressedSize,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.ArrayList]$FailureList
    )
    $candidateWithoutSignature = $null
    $candidateWithSignature = $null
    try { $candidateWithoutSignature = Read-ECTOSRawZipDataDescriptorCandidate -Stream $Stream -Offset $Offset -Zip64 $Zip64 -SignaturePresent $false } catch { $candidateWithoutSignature = $null }
    try { $candidateWithSignature = Read-ECTOSRawZipDataDescriptorCandidate -Stream $Stream -Offset $Offset -Zip64 $Zip64 -SignaturePresent $true } catch { $candidateWithSignature = $null }

    $withoutMatches = ($null -ne $candidateWithoutSignature -and [uint32]$candidateWithoutSignature.crc32 -eq $ExpectedCrc32 -and [uint64]$candidateWithoutSignature.compressed_size -eq $ExpectedCompressedSize -and [uint64]$candidateWithoutSignature.uncompressed_size -eq $ExpectedUncompressedSize)
    $withMatches = ($null -ne $candidateWithSignature -and [uint32]$candidateWithSignature.crc32 -eq $ExpectedCrc32 -and [uint64]$candidateWithSignature.compressed_size -eq $ExpectedCompressedSize -and [uint64]$candidateWithSignature.uncompressed_size -eq $ExpectedUncompressedSize)

    if($withoutMatches -and $withMatches) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_AMBIGUOUS_STRUCTURE' -Stage 'DATA_DESCRIPTOR' -Message 'Both signed and unsigned data-descriptor interpretations satisfy the expected CRC and sizes.'
    }
    if($withMatches) { return $candidateWithSignature }
    if($withoutMatches) { return $candidateWithoutSignature }

    Add-ECTOSRawZipFailure -FailureList $FailureList -FailureId 'RZP_MALFORMED_DATA_DESCRIPTOR' -Stage 'DATA_DESCRIPTOR' -Message 'No supported data-descriptor interpretation matches the central-directory CRC and sizes.' -SourceOffset $Offset -ContinueAnalysisAllowed $false
    return $null
}
function Read-ECTOSRawZipStructure {
    param([Parameter(Mandatory=$true)][string]$Path)

    if([string]::IsNullOrWhiteSpace($Path)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_NOT_FOUND' -Stage 'INPUT' -Message 'Input path is null, empty, or whitespace.'
    }
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_NOT_FOUND' -Stage 'INPUT' -Message 'Input path does not identify an existing leaf file.'
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $preInfo = Get-Item -LiteralPath $resolvedPath
    [uint64]$preSize = [uint64]$preInfo.Length
    $preHash = Get-ECTOSRawZipSha256ForPath -Path $resolvedPath
    $failures = New-Object System.Collections.ArrayList
    $entries = New-Object System.Collections.ArrayList
    $intervals = New-Object System.Collections.ArrayList
    $localOffsets = @{}
    $stream = $null

    try {
        $stream = [System.IO.File]::Open($resolvedPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
        [uint64]$streamLength = [uint64]$stream.Length
        if($streamLength -ne $preSize) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_CHANGED_DURING_PARSE' -Stage 'INPUT_IDENTITY' -Message 'Input size changed between identity capture and parser open.'
        }

        $eocdLocation = Find-ECTOSRawZipEocd -Stream $stream
        [uint64]$eocdOffset = [uint64]$eocdLocation.offset
        $eocdSignature = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset $eocdOffset -Stage 'EOCD'
        if($eocdSignature -ne [uint32]0x06054B50) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_SIGNATURE' -Stage 'EOCD' -Message 'EOCD signature mismatch.'
        }
        $diskNumber = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+4) -Stage 'EOCD'
        $centralDisk = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+6) -Stage 'EOCD'
        $entriesThisDisk16 = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+8) -Stage 'EOCD'
        $entryCount16 = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+10) -Stage 'EOCD'
        $centralSize32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($eocdOffset+12) -Stage 'EOCD'
        $centralOffset32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($eocdOffset+16) -Stage 'EOCD'
        $commentLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($eocdOffset+20) -Stage 'EOCD'
        $commentBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset ($eocdOffset+22) -Length ([uint64]$commentLength) -Stage 'EOCD_COMMENT'
        [uint64]$eocdLength = 22 + [uint64]$commentLength
        [uint64]$eocdEnd = $eocdOffset + $eocdLength
        [uint64]$trailingByteCount = $streamLength - $eocdEnd
        if($trailingByteCount -gt 0) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_UNCLASSIFIED_TRAILING_BYTES' -Stage 'ARCHIVE_FINALIZATION' -Message 'Bytes remain after EOCD and its declared archive comment.' -SourceOffset $eocdEnd
        }
        if($diskNumber -ne 0 -or $centralDisk -ne 0 -or $entriesThisDisk16 -ne $entryCount16) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_MULTI_DISK_UNSUPPORTED' -Stage 'EOCD' -Message 'Multi-disk ZIP semantics are not supported by V01.' -SourceOffset $eocdOffset
        }

        [uint64]$entryCount = [uint64]$entryCount16
        [uint64]$centralSize = [uint64]$centralSize32
        [uint64]$centralOffset = [uint64]$centralOffset32
        $zip64Archive = $null
        $zip64Sentinel = ($entryCount16 -eq [uint16]0xFFFF -or $centralSize32 -eq [uint32]4294967295 -or $centralOffset32 -eq [uint32]4294967295)
        if($zip64Sentinel) {
            if($eocdOffset -lt 20) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage 'ZIP64' -Message 'ZIP64 sentinel is present but no room exists for the ZIP64 locator.'
            }
            [uint64]$locatorOffset = $eocdOffset - 20
            $locatorSignature = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset $locatorOffset -Stage 'ZIP64_LOCATOR'
            if($locatorSignature -ne [uint32]0x07064B50) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage 'ZIP64_LOCATOR' -Message 'ZIP64 locator signature is missing.'
            }
            $locatorDisk = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($locatorOffset+4) -Stage 'ZIP64_LOCATOR'
            $zip64EocdOffset = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($locatorOffset+8) -Stage 'ZIP64_LOCATOR'
            $locatorDiskCount = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($locatorOffset+16) -Stage 'ZIP64_LOCATOR'
            if($locatorDisk -ne 0 -or $locatorDiskCount -ne 1) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_MULTI_DISK_UNSUPPORTED' -Stage 'ZIP64_LOCATOR' -Message 'ZIP64 locator declares multi-disk semantics.' -SourceOffset $locatorOffset
            }
            $zip64Signature = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset $zip64EocdOffset -Stage 'ZIP64_EOCD'
            if($zip64Signature -ne [uint32]0x06064B50) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage 'ZIP64_EOCD' -Message 'ZIP64 EOCD signature mismatch.'
            }
            $zip64RecordPayloadSize = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($zip64EocdOffset+4) -Stage 'ZIP64_EOCD'
            if($zip64RecordPayloadSize -lt 44) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_ZIP64' -Stage 'ZIP64_EOCD' -Message 'ZIP64 EOCD payload is shorter than the fixed required fields.'
            }
            if($zip64RecordPayloadSize -gt ([uint64]::MaxValue - 12)) { Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage 'ZIP64_EOCD' -Message 'ZIP64 EOCD record-length addition overflow.' }
            [uint64]$zip64RecordLength = 12 + $zip64RecordPayloadSize
            Test-ECTOSRawZipRange -Offset $zip64EocdOffset -Length $zip64RecordLength -StreamLength $streamLength -Stage 'ZIP64_EOCD'
            $zip64Disk = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($zip64EocdOffset+16) -Stage 'ZIP64_EOCD'
            $zip64CentralDisk = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($zip64EocdOffset+20) -Stage 'ZIP64_EOCD'
            $zip64EntriesDisk = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($zip64EocdOffset+24) -Stage 'ZIP64_EOCD'
            $zip64EntryCount = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($zip64EocdOffset+32) -Stage 'ZIP64_EOCD'
            $zip64CentralSize = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($zip64EocdOffset+40) -Stage 'ZIP64_EOCD'
            $zip64CentralOffset = Read-ECTOSRawZipUInt64LE -Stream $stream -Offset ($zip64EocdOffset+48) -Stage 'ZIP64_EOCD'
            if($zip64Disk -ne 0 -or $zip64CentralDisk -ne 0 -or $zip64EntriesDisk -ne $zip64EntryCount) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_MULTI_DISK_UNSUPPORTED' -Stage 'ZIP64_EOCD' -Message 'ZIP64 EOCD declares multi-disk semantics.' -SourceOffset $zip64EocdOffset
            }
            $entryCount = $zip64EntryCount
            $centralSize = $zip64CentralSize
            $centralOffset = $zip64CentralOffset
            $zip64Archive = [pscustomobject][ordered]@{
                locator_offset = $locatorOffset
                eocd_offset = $zip64EocdOffset
                eocd_length = $zip64RecordLength
                entry_count = $zip64EntryCount
                central_directory_size = $zip64CentralSize
                central_directory_offset = $zip64CentralOffset
            }
            [void]$intervals.Add([pscustomobject][ordered]@{start=$locatorOffset;end=($locatorOffset+20);owner='ZIP64_LOCATOR'})
            [void]$intervals.Add([pscustomobject][ordered]@{start=$zip64EocdOffset;end=($zip64EocdOffset+$zip64RecordLength);owner='ZIP64_EOCD'})
        }

        Test-ECTOSRawZipRange -Offset $centralOffset -Length $centralSize -StreamLength $streamLength -Stage 'CENTRAL_DIRECTORY'
        [uint64]$centralEnd = $centralOffset + $centralSize
        if($entryCount -gt 0) {
            if($entryCount -gt ([uint64]::MaxValue / 46)) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage 'CENTRAL_DIRECTORY' -Message 'Central-directory minimum-size multiplication overflow.'
            }
            [uint64]$minimumPossible = $entryCount * 46
            if($minimumPossible -gt $centralSize) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_CENTRAL_HEADER' -Stage 'CENTRAL_DIRECTORY' -Message 'Declared entry count cannot fit inside the declared central-directory size.'
            }
        }

        [uint64]$centralCursor = $centralOffset
        for([uint64]$entryIndex=0; $entryIndex -lt $entryCount; $entryIndex++) {
            if($centralCursor -gt $streamLength) { Write-ECTOSRawZipFailure -FailureId 'RZP_OFFSET_OUT_OF_RANGE' -Stage 'CENTRAL_DIRECTORY' -Message 'Central-directory cursor exceeds the input length.' }
            if([uint64]46 -gt ($streamLength - $centralCursor)) { Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_CENTRAL_HEADER' -Stage 'CENTRAL_DIRECTORY' -Message 'Central-directory fixed header is truncated.' }
            $centralSignature = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset $centralCursor -Stage 'CENTRAL_DIRECTORY'
            if($centralSignature -ne [uint32]0x02014B50) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_SIGNATURE' -Stage 'CENTRAL_DIRECTORY' -Message ('Central-directory signature mismatch at entry index '+[string]$entryIndex+'.')
            }
            $versionMadeBy = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+4) -Stage 'CENTRAL_DIRECTORY'
            $versionNeeded = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+6) -Stage 'CENTRAL_DIRECTORY'
            $flags = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+8) -Stage 'CENTRAL_DIRECTORY'
            if(($flags -band [uint16]1) -ne 0) { Write-ECTOSRawZipFailure -FailureId 'RZP_UNSUPPORTED_STRUCTURE' -Stage 'CENTRAL_DIRECTORY' -Message 'Encrypted ZIP entries are unsupported.' }
            $method = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+10) -Stage 'CENTRAL_DIRECTORY'
            if($method -ne [uint16]0 -and $method -ne [uint16]8) { Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_UNSUPPORTED_STRUCTURE' -Stage 'CENTRAL_DIRECTORY' -Message ('Compression method '+[string]$method+' is outside the V01 supported method set {0,8}.') -SourceOffset ($centralCursor+10) }
            $modTime = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+12) -Stage 'CENTRAL_DIRECTORY'
            $modDate = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+14) -Stage 'CENTRAL_DIRECTORY'
            $crc32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralCursor+16) -Stage 'CENTRAL_DIRECTORY'
            $compressed32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralCursor+20) -Stage 'CENTRAL_DIRECTORY'
            $uncompressed32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralCursor+24) -Stage 'CENTRAL_DIRECTORY'
            $nameLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+28) -Stage 'CENTRAL_DIRECTORY'
            $extraLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+30) -Stage 'CENTRAL_DIRECTORY'
            $entryCommentLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+32) -Stage 'CENTRAL_DIRECTORY'
            $diskStart16 = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+34) -Stage 'CENTRAL_DIRECTORY'
            $internalAttributes = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($centralCursor+36) -Stage 'CENTRAL_DIRECTORY'
            $externalAttributes = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralCursor+38) -Stage 'CENTRAL_DIRECTORY'
            $localOffset32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($centralCursor+42) -Stage 'CENTRAL_DIRECTORY'
            [uint64]$centralRecordLength = 46 + [uint64]$nameLength + [uint64]$extraLength + [uint64]$entryCommentLength
            if($centralRecordLength -gt ($streamLength - $centralCursor)) { Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_CENTRAL_HEADER' -Stage 'CENTRAL_DIRECTORY' -Message 'Central-directory variable-length record is truncated.' }
            Test-ECTOSRawZipRange -Offset $centralCursor -Length $centralRecordLength -StreamLength $streamLength -Stage 'CENTRAL_DIRECTORY'
            $centralNameBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset ($centralCursor+46) -Length ([uint64]$nameLength) -Stage 'CENTRAL_FILENAME'
            [uint64]$centralExtraOffset = $centralCursor + 46 + [uint64]$nameLength
            $centralExtraBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset $centralExtraOffset -Length ([uint64]$extraLength) -Stage 'CENTRAL_EXTRA'
            $centralExtraFields = Read-ECTOSRawZipExtraFieldSet -Bytes $centralExtraBytes -AbsoluteOffset $centralExtraOffset -Stage 'CENTRAL_EXTRA'
            [uint64]$centralCommentOffset = $centralExtraOffset + [uint64]$extraLength
            $entryCommentBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset $centralCommentOffset -Length ([uint64]$entryCommentLength) -Stage 'CENTRAL_COMMENT'
            $utf8Flag = (($flags -band [uint16]0x0800) -ne 0)
            $decodedName = ConvertFrom-ECTOSRawZipNameByteSequence -Bytes $centralNameBytes -Utf8Flag $utf8Flag -Stage 'CENTRAL_FILENAME'
            $decodedComment = ConvertFrom-ECTOSRawZipNameByteSequence -Bytes $entryCommentBytes -Utf8Flag $utf8Flag -Stage 'CENTRAL_COMMENT'

            $needUncompressed = ($uncompressed32 -eq [uint32]4294967295)
            $needCompressed = ($compressed32 -eq [uint32]4294967295)
            $needLocalOffset = ($localOffset32 -eq [uint32]4294967295)
            $needDiskStart = ($diskStart16 -eq [uint16]0xFFFF)
            $zip64Values = Get-ECTOSRawZip64OverrideSet -ExtraFields $centralExtraFields -NeedUncompressed $needUncompressed -NeedCompressed $needCompressed -NeedLocalOffset $needLocalOffset -NeedDiskStart $needDiskStart -Stage 'CENTRAL_ZIP64_EXTRA'
            [uint64]$compressedSize = [uint64]$compressed32
            [uint64]$uncompressedSize = [uint64]$uncompressed32
            [uint64]$localHeaderOffset = [uint64]$localOffset32
            [uint64]$diskStart = [uint64]$diskStart16
            if($needUncompressed) { $uncompressedSize = [uint64]$zip64Values.uncompressed_size }
            if($needCompressed) { $compressedSize = [uint64]$zip64Values.compressed_size }
            if($needLocalOffset) { $localHeaderOffset = [uint64]$zip64Values.local_header_offset }
            if($needDiskStart) { $diskStart = [uint64]$zip64Values.disk_start }
            if($diskStart -ne 0) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_MULTI_DISK_UNSUPPORTED' -Stage 'CENTRAL_DIRECTORY' -Message 'Central entry resolves to a nonzero disk number.' -SourceOffset $centralCursor
            }

            $offsetKey = [string]$localHeaderOffset
            if($localOffsets.ContainsKey($offsetKey)) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_DUPLICATE_RECORD' -Stage 'CENTRAL_DIRECTORY' -Message 'More than one central entry claims the same local-header offset.'
            }
            $localOffsets[$offsetKey] = [string]$entryIndex

            if($localHeaderOffset -gt [uint64][long]::MaxValue) { Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage 'LOCAL_HEADER' -Message 'Local-header offset cannot be represented as an Int64 stream position.' }
            if($localHeaderOffset -ge $centralOffset -and $localHeaderOffset -lt $centralEnd) { Write-ECTOSRawZipFailure -FailureId 'RZP_OVERLAPPING_RECORDS' -Stage 'STRUCTURAL_CLOSURE' -Message 'Local-header offset points inside the central-directory interval.' }
            if($localHeaderOffset -gt $streamLength) { Write-ECTOSRawZipFailure -FailureId 'RZP_OFFSET_OUT_OF_RANGE' -Stage 'LOCAL_HEADER' -Message 'Local-header offset exceeds the input length.' }
            if([uint64]30 -gt ($streamLength - $localHeaderOffset)) { Write-ECTOSRawZipFailure -FailureId 'RZP_TRUNCATED_LOCAL_HEADER' -Stage 'LOCAL_HEADER' -Message 'Local fixed header is truncated.' }
            $localSignature = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset $localHeaderOffset -Stage 'LOCAL_HEADER'
            if($localSignature -ne [uint32]0x04034B50) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INVALID_SIGNATURE' -Stage 'LOCAL_HEADER' -Message ('Local-header signature mismatch for entry index '+[string]$entryIndex+'.')
            }
            $localVersionNeeded = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+4) -Stage 'LOCAL_HEADER'
            $localFlags = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+6) -Stage 'LOCAL_HEADER'
            $localMethod = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+8) -Stage 'LOCAL_HEADER'
            $localModTime = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+10) -Stage 'LOCAL_HEADER'
            $localModDate = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+12) -Stage 'LOCAL_HEADER'
            $localCrc32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localHeaderOffset+14) -Stage 'LOCAL_HEADER'
            $localCompressed32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localHeaderOffset+18) -Stage 'LOCAL_HEADER'
            $localUncompressed32 = Read-ECTOSRawZipUInt32LE -Stream $stream -Offset ($localHeaderOffset+22) -Stage 'LOCAL_HEADER'
            $localNameLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+26) -Stage 'LOCAL_HEADER'
            $localExtraLength = Read-ECTOSRawZipUInt16LE -Stream $stream -Offset ($localHeaderOffset+28) -Stage 'LOCAL_HEADER'
            [uint64]$localHeaderLength = 30 + [uint64]$localNameLength + [uint64]$localExtraLength
            if($localHeaderLength -gt ($streamLength - $localHeaderOffset)) { Write-ECTOSRawZipFailure -FailureId 'RZP_SIZE_OUT_OF_RANGE' -Stage 'LOCAL_HEADER' -Message 'Local variable-length header exceeds the bounded input range.' }
            Test-ECTOSRawZipRange -Offset $localHeaderOffset -Length $localHeaderLength -StreamLength $streamLength -Stage 'LOCAL_HEADER'
            $localNameBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset ($localHeaderOffset+30) -Length ([uint64]$localNameLength) -Stage 'LOCAL_FILENAME'
            [uint64]$localExtraOffset = $localHeaderOffset + 30 + [uint64]$localNameLength
            $localExtraBytes = Read-ECTOSRawZipByteRange -Stream $stream -Offset $localExtraOffset -Length ([uint64]$localExtraLength) -Stage 'LOCAL_EXTRA'
            $localExtraFields = Read-ECTOSRawZipExtraFieldSet -Bytes $localExtraBytes -AbsoluteOffset $localExtraOffset -Stage 'LOCAL_EXTRA'
            $localNeedUncompressed = ($localUncompressed32 -eq [uint32]4294967295)
            $localNeedCompressed = ($localCompressed32 -eq [uint32]4294967295)
            $localZip64Values = Get-ECTOSRawZip64OverrideSet -ExtraFields $localExtraFields -NeedUncompressed $localNeedUncompressed -NeedCompressed $localNeedCompressed -NeedLocalOffset $false -NeedDiskStart $false -Stage 'LOCAL_ZIP64_EXTRA'
            [uint64]$localCompressedSize = [uint64]$localCompressed32
            [uint64]$localUncompressedSize = [uint64]$localUncompressed32
            if($localNeedCompressed) { $localCompressedSize = [uint64]$localZip64Values.compressed_size }
            if($localNeedUncompressed) { $localUncompressedSize = [uint64]$localZip64Values.uncompressed_size }
            if((ConvertTo-ECTOSRawZipHex -Bytes $localNameBytes) -ne (ConvertTo-ECTOSRawZipHex -Bytes $centralNameBytes)) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_LOCAL_CENTRAL_NAME_MISMATCH' -Stage 'CROSS_CHECK' -Message 'Local and central raw filename bytes differ.' -SourceOffset $localHeaderOffset
            }
            if($localMethod -ne $method) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_LOCAL_CENTRAL_METHOD_MISMATCH' -Stage 'CROSS_CHECK' -Message 'Local and central compression methods differ.' -SourceOffset $localHeaderOffset
            }
            if($localFlags -ne $flags) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_LOCAL_CENTRAL_FLAG_MISMATCH' -Stage 'CROSS_CHECK' -Message 'Local and central general-purpose flags differ.' -SourceOffset $localHeaderOffset
            }
            $descriptorPresent = (($flags -band [uint16]0x0008) -ne 0)
            if(-not $descriptorPresent) {
                if($localCrc32 -ne $crc32) { Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_CRC_CONTRACT_MISMATCH' -Stage 'CROSS_CHECK' -Message 'Local and central CRC32 values differ.' -SourceOffset $localHeaderOffset }
                if($localCompressedSize -ne $compressedSize -or $localUncompressedSize -ne $uncompressedSize) { Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_SIZE_CONTRACT_MISMATCH' -Stage 'CROSS_CHECK' -Message 'Local and central resolved sizes differ.' -SourceOffset $localHeaderOffset }
            }
            [uint64]$rawDataOffset = $localHeaderOffset + $localHeaderLength
            Test-ECTOSRawZipRange -Offset $rawDataOffset -Length $compressedSize -StreamLength $streamLength -Stage 'COMPRESSED_DATA'
            $compressedDataSha256 = Get-ECTOSRawZipSha256ForRange -Stream $stream -Offset $rawDataOffset -Length $compressedSize -Stage 'COMPRESSED_DATA'
            $descriptor = $null
            [uint64]$descriptorLength = 0
            if($descriptorPresent) {
                [uint64]$descriptorOffset = $rawDataOffset + $compressedSize
                $entryUsesZip64 = ($needCompressed -or $needUncompressed -or $localNeedCompressed -or $localNeedUncompressed -or $compressedSize -gt [uint64]4294967295 -or $uncompressedSize -gt [uint64]4294967295)
                try {
                    $descriptor = Read-ECTOSRawZipDataDescriptor -Stream $stream -Offset $descriptorOffset -Zip64 $entryUsesZip64 -ExpectedCrc32 $crc32 -ExpectedCompressedSize $compressedSize -ExpectedUncompressedSize $uncompressedSize -FailureList $failures
                    if($null -ne $descriptor) { $descriptorLength = [uint64]$descriptor.length }
                }
                catch {
                    Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_MALFORMED_DATA_DESCRIPTOR' -Stage 'DATA_DESCRIPTOR' -Message $_.Exception.Message -SourceOffset $descriptorOffset -ContinueAnalysisAllowed $false
                }
            }

            $entryRecord = [pscustomobject][ordered]@{
                entry_index = $entryIndex
                central_directory_offset = $centralCursor
                central_directory_length = $centralRecordLength
                local_header_offset = $localHeaderOffset
                local_header_length = $localHeaderLength
                raw_filename_bytes = (ConvertTo-ECTOSRawZipHex -Bytes $centralNameBytes)
                decoded_filename = $decodedName
                general_purpose_flags = [uint16]$flags
                utf8_flag = $utf8Flag
                compression_method = [uint16]$method
                version_needed = [uint16]$versionNeeded
                local_version_needed = [uint16]$localVersionNeeded
                version_made_by = [uint16]$versionMadeBy
                creator_system = [int](($versionMadeBy -band [uint16]0xFF00) / 256)
                last_mod_time_raw = [uint16]$modTime
                last_mod_date_raw = [uint16]$modDate
                local_last_mod_time_raw = [uint16]$localModTime
                local_last_mod_date_raw = [uint16]$localModDate
                crc32 = [uint32]$crc32
                compressed_size = $compressedSize
                uncompressed_size = $uncompressedSize
                local_compressed_size = $localCompressedSize
                local_uncompressed_size = $localUncompressedSize
                local_extra_fields = @($localExtraFields)
                central_extra_fields = @($centralExtraFields)
                internal_attributes = [uint16]$internalAttributes
                external_attributes = [uint32]$externalAttributes
                raw_comment_bytes = (ConvertTo-ECTOSRawZipHex -Bytes $entryCommentBytes)
                comment = $decodedComment
                data_descriptor_present = $descriptorPresent
                data_descriptor = $descriptor
                zip64_usage = ($needUncompressed -or $needCompressed -or $needLocalOffset -or $needDiskStart -or $localNeedUncompressed -or $localNeedCompressed)
                raw_data_offset = $rawDataOffset
                raw_compressed_data_length = $compressedSize
                raw_compressed_data_sha256 = $compressedDataSha256
            }
            [void]$entries.Add($entryRecord)
            [void]$intervals.Add([pscustomobject][ordered]@{start=$localHeaderOffset;end=($localHeaderOffset+$localHeaderLength);owner=('LOCAL_'+[string]$entryIndex)})
            [void]$intervals.Add([pscustomobject][ordered]@{start=$rawDataOffset;end=($rawDataOffset+$compressedSize);owner=('DATA_'+[string]$entryIndex)})
            if($descriptorLength -gt 0) {
                [void]$intervals.Add([pscustomobject][ordered]@{start=($rawDataOffset+$compressedSize);end=($rawDataOffset+$compressedSize+$descriptorLength);owner=('DESCRIPTOR_'+[string]$entryIndex)})
            }
            [void]$intervals.Add([pscustomobject][ordered]@{start=$centralCursor;end=($centralCursor+$centralRecordLength);owner=('CENTRAL_'+[string]$entryIndex)})
            $centralCursor += $centralRecordLength
        }

        if($centralCursor -ne $centralEnd) {
            Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_SIZE_CONTRACT_MISMATCH' -Stage 'CENTRAL_DIRECTORY' -Message 'Parsed central-directory extent differs from EOCD-declared central-directory size.' -SourceOffset $centralCursor
        }
        [void]$intervals.Add([pscustomobject][ordered]@{start=$eocdOffset;end=$eocdEnd;owner='EOCD'})

        $orderedIntervals = @($intervals | Sort-Object @{Expression={$_.start};Ascending=$true},@{Expression={$_.end};Ascending=$true})
        $previous = $null
        foreach($current in $orderedIntervals) {
            if([uint64]$current.end -lt [uint64]$current.start) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_INTEGER_OVERFLOW' -Stage 'STRUCTURAL_CLOSURE' -Message 'Interval end precedes interval start.' -SourceOffset ([uint64]$current.start) -ContinueAnalysisAllowed $false
            }
            if($null -ne $previous -and [uint64]$current.start -lt [uint64]$previous.end) {
                Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_OVERLAPPING_RECORDS' -Stage 'STRUCTURAL_CLOSURE' -Message ('Unexpected overlap between '+[string]$previous.owner+' and '+[string]$current.owner+'.') -SourceOffset ([uint64]$current.start)
            }
            if($null -eq $previous -or [uint64]$current.end -gt [uint64]$previous.end) { $previous = $current }
        }

        $archiveCommentUtf8 = $false
        $archiveComment = ''
        if($commentBytes.Length -gt 0) {
            try { $archiveComment = ConvertFrom-ECTOSRawZipNameByteSequence -Bytes $commentBytes -Utf8Flag $archiveCommentUtf8 -Stage 'ARCHIVE_COMMENT' }
            catch { Add-ECTOSRawZipFailure -FailureList $failures -FailureId 'RZP_ENCODING_ERROR' -Stage 'ARCHIVE_COMMENT' -Message $_.Exception.Message -SourceOffset ($eocdOffset+22); $archiveComment = $null }
        }

        $structure = [pscustomobject][ordered]@{
            input_path = $resolvedPath
            input_size = $streamLength
            input_sha256 = $preHash
            archive = [pscustomobject][ordered]@{
                archive_size = $streamLength
                archive_sha256 = $preHash
                entry_count = $entryCount
                eocd_offset = $eocdOffset
                eocd_size = $eocdLength
                central_directory_offset = $centralOffset
                central_directory_size = $centralSize
                archive_comment_raw = (ConvertTo-ECTOSRawZipHex -Bytes $commentBytes)
                archive_comment = $archiveComment
                trailing_byte_count = $trailingByteCount
                unclassified_byte_count = $trailingByteCount
                zip64 = $zip64Archive
            }
            entries = @($entries)
            failures = @($failures)
            intervals = @($orderedIntervals)
        }
    }
    finally {
        if($null -ne $stream) { $stream.Dispose() }
    }

    $postInfo = Get-Item -LiteralPath $resolvedPath
    $postHash = Get-ECTOSRawZipSha256ForPath -Path $resolvedPath
    [void](Test-ECTOSRawZipInputIdentity -PreSize $preSize -PreSha256 $preHash -PostSize ([uint64]$postInfo.Length) -PostSha256 $postHash)
    return $structure
}
