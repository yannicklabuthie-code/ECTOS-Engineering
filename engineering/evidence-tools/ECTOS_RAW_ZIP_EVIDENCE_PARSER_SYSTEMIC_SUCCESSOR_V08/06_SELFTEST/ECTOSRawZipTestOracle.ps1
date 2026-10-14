Set-StrictMode -Version Latest

function Test-ECTOSRawZipExactFailureOracle {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedFailureId,
        [Parameter(Mandatory=$true)][string]$ExpectedStage,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$ActualFailures
    )
    $actual = @($ActualFailures)
    if($actual.Count -ne 1) { return $false }
    if(-not [string]::Equals([string]$actual[0].error_id,$ExpectedFailureId,[System.StringComparison]::Ordinal)) { return $false }
    if(-not [string]::Equals([string]$actual[0].failure_stage,$ExpectedStage,[System.StringComparison]::Ordinal)) { return $false }
    return $true
}
