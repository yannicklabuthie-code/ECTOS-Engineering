Set-StrictMode -Version Latest

function Get-ECTOSRawZipCanonicalFailureStage {
    param([Parameter(Mandatory=$true)][string]$FailureId)
    switch($FailureId) {
        'RZP_INVALID_SIGNATURE' { return 'STRUCTURE' }
        'RZP_TRUNCATED_LOCAL_HEADER' { return 'LOCAL_HEADER' }
        'RZP_TRUNCATED_CENTRAL_HEADER' { return 'CENTRAL_DIRECTORY' }
        'RZP_TRUNCATED_EOCD' { return 'EOCD' }
        'RZP_INVALID_EOCD' { return 'EOCD' }
        'RZP_OFFSET_OUT_OF_RANGE' { return 'BOUNDS' }
        'RZP_SIZE_OUT_OF_RANGE' { return 'BOUNDS' }
        'RZP_INTEGER_OVERFLOW' { return 'INTEGER' }
        'RZP_OVERLAPPING_RECORDS' { return 'STRUCTURAL_CLOSURE' }
        'RZP_DUPLICATE_RECORD' { return 'STRUCTURAL_CLOSURE' }
        'RZP_LOCAL_CENTRAL_NAME_MISMATCH' { return 'CROSS_CHECK' }
        'RZP_LOCAL_CENTRAL_METHOD_MISMATCH' { return 'CROSS_CHECK' }
        'RZP_LOCAL_CENTRAL_FLAG_MISMATCH' { return 'CROSS_CHECK' }
        'RZP_CRC_CONTRACT_MISMATCH' { return 'CROSS_CHECK' }
        'RZP_SIZE_CONTRACT_MISMATCH' { return 'CROSS_CHECK' }
        'RZP_MALFORMED_EXTRA_FIELD' { return 'EXTRA_FIELD' }
        'RZP_INVALID_ZIP64' { return 'ZIP64' }
        'RZP_UNEXPECTED_ZIP64' { return 'ZIP64' }
        'RZP_MALFORMED_DATA_DESCRIPTOR' { return 'DATA_DESCRIPTOR' }
        'RZP_UNCLASSIFIED_TRAILING_BYTES' { return 'ARCHIVE_FINALIZATION' }
        'RZP_UNSUPPORTED_STRUCTURE' { return 'STRUCTURE' }
        'RZP_ENCODING_ERROR' { return 'DECODE' }
        'RZP_MULTI_DISK_UNSUPPORTED' { return 'EOCD' }
        'RZP_AMBIGUOUS_STRUCTURE' { return 'STRUCTURAL_RESOLUTION' }
        'RZP_INPUT_NOT_FOUND' { return 'INPUT' }
        'RZP_INPUT_READ_ERROR' { return 'INPUT' }
        'RZP_INPUT_CHANGED_DURING_PARSE' { return 'INPUT_IDENTITY' }
        'RZP_EVIDENCE_EMISSION_ERROR' { return 'OUTPUT' }
        default { throw ('ECTOS_RAW_ZIP_UNKNOWN_FAILURE_ID:' + $FailureId) }
    }
}

function Write-ECTOSRawZipFailure {
    param(
        [Parameter(Mandatory=$true)][string]$FailureId,
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][string]$Message
    )
    $exception = New-Object System.IO.InvalidDataException($Message)
    $exception.Data['ECTOSFailureId'] = $FailureId
    $exception.Data['ECTOSFailureStage'] = Get-ECTOSRawZipCanonicalFailureStage -FailureId $FailureId
    $exception.Data['ECTOSFailureOperationStage'] = $Stage
    throw $exception
}

function Test-ECTOSRawZipRange {
    param(
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][uint64]$Length,
        [Parameter(Mandatory=$true)][uint64]$StreamLength,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    if($Offset -gt [uint64][long]::MaxValue) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage $Stage -Message 'Offset cannot be represented as Int64 stream position.'
    }
    if($Length -gt [uint64][int]::MaxValue) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_SIZE_OUT_OF_RANGE' -Stage $Stage -Message 'Single read exceeds supported bounded buffer size.'
    }
    if($Offset -gt $StreamLength) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_OFFSET_OUT_OF_RANGE' -Stage $Stage -Message 'Offset exceeds input length.'
    }
    $remaining = $StreamLength - $Offset
    if($Length -gt $remaining) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_SIZE_OUT_OF_RANGE' -Stage $Stage -Message 'Requested range exceeds input length.'
    }
}

function Read-ECTOSRawZipByteRange {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][uint64]$Length,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $streamLength = [uint64]$Stream.Length
    Test-ECTOSRawZipRange -Offset $Offset -Length $Length -StreamLength $streamLength -Stage $Stage
    [void]$Stream.Seek([long]$Offset,[System.IO.SeekOrigin]::Begin)
    $buffer = New-Object byte[] ([int]$Length)
    $readTotal = 0
    while($readTotal -lt $buffer.Length) {
        $readNow = $Stream.Read($buffer,$readTotal,$buffer.Length-$readTotal)
        if($readNow -le 0) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_READ_ERROR' -Stage $Stage -Message 'Input stream ended before the requested bounded read completed.'
        }
        $readTotal += $readNow
    }
    return ,$buffer
}

function Read-ECTOSRawZipUInt16LE {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $bytes = Read-ECTOSRawZipByteRange -Stream $Stream -Offset $Offset -Length 2 -Stage $Stage
    return [uint16]([uint64]$bytes[0] + ([uint64]$bytes[1] * 256))
}

function Read-ECTOSRawZipUInt32LE {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $bytes = Read-ECTOSRawZipByteRange -Stream $Stream -Offset $Offset -Length 4 -Stage $Stage
    $value = [uint64]$bytes[0]
    $value += ([uint64]$bytes[1] * 256)
    $value += ([uint64]$bytes[2] * 65536)
    $value += ([uint64]$bytes[3] * 16777216)
    return [uint32]$value
}

function Read-ECTOSRawZipUInt64LE {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $bytes = Read-ECTOSRawZipByteRange -Stream $Stream -Offset $Offset -Length 8 -Stage $Stage
    [uint64]$value = 0
    [uint64]$factor = 1
    for($index=0; $index -lt 8; $index++) {
        $part = [uint64]$bytes[$index] * $factor
        if([uint64]::MaxValue - $value -lt $part) {
            Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage $Stage -Message 'UInt64 assembly overflow.'
        }
        $value += $part
        if($index -lt 7) {
            if($factor -gt ([uint64]::MaxValue / 256)) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INTEGER_OVERFLOW' -Stage $Stage -Message 'UInt64 factor overflow.'
            }
            $factor *= 256
        }
    }
    return $value
}

function ConvertTo-ECTOSRawZipHex {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes)
    if($Bytes.Length -eq 0) { return '' }
    return ([BitConverter]::ToString($Bytes)).Replace('-','')
}

function Get-ECTOSRawZipSha256ForPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_NOT_FOUND' -Stage 'INPUT' -Message 'Input path does not identify a leaf file.'
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
        $hash = $sha.ComputeHash($stream)
        return (ConvertTo-ECTOSRawZipHex -Bytes $hash)
    }
    catch {
        if($_.Exception.Data.Contains('ECTOSFailureId')) { throw }
        Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_READ_ERROR' -Stage 'INPUT' -Message $_.Exception.Message
    }
    finally {
        if($null -ne $stream) { $stream.Dispose() }
        $sha.Dispose()
    }
}

function Get-ECTOSRawZipSha256ForRange {
    param(
        [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)][uint64]$Offset,
        [Parameter(Mandatory=$true)][uint64]$Length,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    $streamLength = [uint64]$Stream.Length
    Test-ECTOSRawZipRange -Offset $Offset -Length $Length -StreamLength $streamLength -Stage $Stage
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        [void]$Stream.Seek([long]$Offset,[System.IO.SeekOrigin]::Begin)
        [uint64]$remaining = $Length
        $buffer = New-Object byte[] 65536
        while($remaining -gt 0) {
            [int]$take = $buffer.Length
            if($remaining -lt [uint64]$take) { $take = [int]$remaining }
            $readNow = $Stream.Read($buffer,0,$take)
            if($readNow -le 0) {
                Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_READ_ERROR' -Stage $Stage -Message 'Stream ended during range hashing.'
            }
            [void]$sha.TransformBlock($buffer,0,$readNow,$null,0)
            $remaining -= [uint64]$readNow
        }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0),0,0)
        return (ConvertTo-ECTOSRawZipHex -Bytes $sha.Hash)
    }
    finally {
        $sha.Dispose()
    }
}

function ConvertFrom-ECTOSRawZipNameByteSequence {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes,
        [Parameter(Mandatory=$true)][bool]$Utf8Flag,
        [Parameter(Mandatory=$true)][string]$Stage
    )
    try {
        if($Utf8Flag) {
            $encoding = New-Object System.Text.UTF8Encoding($false,$true)
        }
        else {
            $encoderFallback = New-Object System.Text.EncoderExceptionFallback
            $decoderFallback = New-Object System.Text.DecoderExceptionFallback
            $encoding = [System.Text.Encoding]::GetEncoding(437,$encoderFallback,$decoderFallback)
        }
        return $encoding.GetString($Bytes)
    }
    catch {
        Write-ECTOSRawZipFailure -FailureId 'RZP_ENCODING_ERROR' -Stage $Stage -Message $_.Exception.Message
    }
}

function Read-ECTOSRawZipBufferUInt16LE {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes,[Parameter(Mandatory=$true)][int]$Offset,[Parameter(Mandatory=$true)][string]$Stage)
    if($Offset -lt 0 -or $Offset -gt ($Bytes.Length-2)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_MALFORMED_EXTRA_FIELD' -Stage $Stage -Message 'UInt16 read exceeds bounded buffer.'
    }
    return [uint16]([uint64]$Bytes[$Offset] + ([uint64]$Bytes[$Offset+1] * 256))
}

function Read-ECTOSRawZipBufferUInt32LE {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes,[Parameter(Mandatory=$true)][int]$Offset,[Parameter(Mandatory=$true)][string]$Stage)
    if($Offset -lt 0 -or $Offset -gt ($Bytes.Length-4)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_MALFORMED_EXTRA_FIELD' -Stage $Stage -Message 'UInt32 read exceeds bounded buffer.'
    }
    [uint64]$value = [uint64]$Bytes[$Offset]
    $value += ([uint64]$Bytes[$Offset+1] * 256)
    $value += ([uint64]$Bytes[$Offset+2] * 65536)
    $value += ([uint64]$Bytes[$Offset+3] * 16777216)
    return [uint32]$value
}

function Read-ECTOSRawZipBufferUInt64LE {
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][byte[]]$Bytes,[Parameter(Mandatory=$true)][int]$Offset,[Parameter(Mandatory=$true)][string]$Stage)
    if($Offset -lt 0 -or $Offset -gt ($Bytes.Length-8)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_MALFORMED_EXTRA_FIELD' -Stage $Stage -Message 'UInt64 read exceeds bounded buffer.'
    }
    [uint64]$value = 0
    [uint64]$factor = 1
    for($index=0; $index -lt 8; $index++) {
        $value += ([uint64]$Bytes[$Offset+$index] * $factor)
        if($index -lt 7) { $factor *= 256 }
    }
    return $value
}

function Test-ECTOSRawZipInputIdentity {
    param(
        [Parameter(Mandatory=$true)][uint64]$PreSize,
        [Parameter(Mandatory=$true)][string]$PreSha256,
        [Parameter(Mandatory=$true)][uint64]$PostSize,
        [Parameter(Mandatory=$true)][string]$PostSha256
    )
    if($PreSize -ne $PostSize -or -not [string]::Equals($PreSha256,$PostSha256,[System.StringComparison]::OrdinalIgnoreCase)) {
        Write-ECTOSRawZipFailure -FailureId 'RZP_INPUT_CHANGED_DURING_PARSE' -Stage 'INPUT_IDENTITY' -Message 'Input identity differs between pre-parse and post-parse observations.'
    }
    return $true
}
