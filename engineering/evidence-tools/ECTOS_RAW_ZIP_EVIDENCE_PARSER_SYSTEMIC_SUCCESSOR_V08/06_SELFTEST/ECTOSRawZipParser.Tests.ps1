Set-StrictMode -Version Latest

$toolRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $toolRoot '02_CORE'
. (Join-Path $coreRoot 'Read-ECTOSZipPrimitive.ps1')
. (Join-Path $coreRoot 'ConvertTo-ECTOSZipEvidence.ps1')
. (Join-Path $PSScriptRoot 'ECTOSRawZipTestOracle.ps1')

$errorCatalog = Get-Content -LiteralPath (Join-Path $toolRoot '04_ERRORS\ECTOS_RAW_ZIP_ERROR_CATALOG_V01.json') -Raw | ConvertFrom-Json
$positiveManifest = Get-Content -LiteralPath (Join-Path $toolRoot '05_FIXTURES\POSITIVE_FIXTURE_MANIFEST_V01.json') -Raw | ConvertFrom-Json
$negativeManifest = Get-Content -LiteralPath (Join-Path $toolRoot '05_FIXTURES\NEGATIVE_FIXTURE_MANIFEST_V01.json') -Raw | ConvertFrom-Json
$falsePassManifest = Get-Content -LiteralPath (Join-Path $toolRoot '05_FIXTURES\FALSE_PASS_FIXTURE_MANIFEST_V01.json') -Raw | ConvertFrom-Json
$falsePassRoot = Join-Path $toolRoot '05_FIXTURES\FALSE_PASS'

function Invoke-ECTOSRawZipCaptureFailure {
    param([Parameter(Mandatory=$true)][scriptblock]$Action)
    try {
        & $Action
        return $null
    }
    catch {
        $failureId = $null
        $failureStage = $null
        if($_.Exception.Data.Contains('ECTOSFailureId')) { $failureId = [string]$_.Exception.Data['ECTOSFailureId'] }
        if($_.Exception.Data.Contains('ECTOSFailureStage')) { $failureStage = [string]$_.Exception.Data['ECTOSFailureStage'] }
        return [pscustomobject][ordered]@{error_id=$failureId;failure_stage=$failureStage;message=$_.Exception.Message}
    }
}

Describe 'ECTOS_RAW_ZIP_EVIDENCE_PARSER_V02 contracts' {
    It 'declares exactly 28 stable error IDs' {
        @($errorCatalog.errors).Count | Should Be 28
        @($errorCatalog.errors.error_id | Select-Object -Unique).Count | Should Be 28
    }

    It 'declares exactly 15 positive fixtures' {
        @($positiveManifest.fixtures).Count | Should Be 15
    }

    It 'declares exactly 28 negative fixtures' {
        @($negativeManifest.fixtures).Count | Should Be 28
    }

    It 'declares exactly 6 false-pass challenges' {
        @($falsePassManifest.fixtures).Count | Should Be 6
    }

    It 'binds every negative fixture to a declared error ID' {
        $declared = @($errorCatalog.errors.error_id)
        foreach($fixture in @($negativeManifest.fixtures)) {
            ($declared -contains [string]$fixture.expected_failure_id) | Should Be $true
        }
    }

    It 'maps every declared error ID to the exact canonical catalog stage' {
        foreach($row in @($errorCatalog.errors)) {
            (Get-ECTOSRawZipCanonicalFailureStage -FailureId ([string]$row.error_id)) | Should Be ([string]$row.failure_stage)
        }
    }

    It 'maps N25 to RZP_INPUT_NOT_FOUND' {
        $missingPath = Join-Path $TestDrive 'missing.zip'
        $failure = Invoke-ECTOSRawZipCaptureFailure -Action { [void](Get-ECTOSRawZipSha256ForPath -Path $missingPath) }
        $failure.error_id | Should Be 'RZP_INPUT_NOT_FOUND'
        $failure.failure_stage | Should Be 'INPUT'
    }

    It 'maps N26 to RZP_INPUT_READ_ERROR under an exclusive file lock' {
        $lockedPath = Join-Path $TestDrive 'locked.zip'
        [System.IO.File]::WriteAllBytes($lockedPath,[byte[]](1,2,3,4))
        $lockHandle = [System.IO.File]::Open($lockedPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
        try {
            $failure = Invoke-ECTOSRawZipCaptureFailure -Action { [void](Get-ECTOSRawZipSha256ForPath -Path $lockedPath) }
        }
        finally {
            $lockHandle.Dispose()
        }
        $failure.error_id | Should Be 'RZP_INPUT_READ_ERROR'
        $failure.failure_stage | Should Be 'INPUT'
    }

    It 'maps N27 to RZP_INPUT_CHANGED_DURING_PARSE through the production identity helper' {
        $failure = Invoke-ECTOSRawZipCaptureFailure -Action { [void](Test-ECTOSRawZipInputIdentity -PreSize 4 -PreSha256 'AAAA' -PostSize 4 -PostSha256 'BBBB') }
        $failure.error_id | Should Be 'RZP_INPUT_CHANGED_DURING_PARSE'
        $failure.failure_stage | Should Be 'INPUT_IDENTITY'
    }

    It 'maps N28 to RZP_EVIDENCE_EMISSION_ERROR when output already exists' {
        $outputPath = Join-Path $TestDrive 'existing-evidence.json'
        [System.IO.File]::WriteAllText($outputPath,'{}',(New-Object System.Text.UTF8Encoding($false)))
        $failure = Invoke-ECTOSRawZipCaptureFailure -Action { Write-ECTOSRawZipEvidenceFile -Evidence ([pscustomobject]@{value='x'}) -Path $outputPath }
        $failure.error_id | Should Be 'RZP_EVIDENCE_EMISSION_ERROR'
        $failure.failure_stage | Should Be 'OUTPUT'
    }

    It 'rejects all six false-pass challenges through the exact oracle' {
        foreach($fixtureDescriptor in @($falsePassManifest.fixtures)) {
            $fixturePath = Join-Path $falsePassRoot ([string]$fixtureDescriptor.file)
            $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
            $expectedCatalogRow = @($errorCatalog.errors | Where-Object { [string]$_.error_id -eq [string]$fixture.expected_failure_id })
            $expectedCatalogRow.Count | Should Be 1
            $actualFailures = @()
            if([string]$fixture.simulated_actual_failure_id -ne 'NONE') {
                $actualFailures = @([pscustomobject][ordered]@{error_id=[string]$fixture.simulated_actual_failure_id;failure_stage=[string]$expectedCatalogRow[0].failure_stage})
            }
            $oracleResult = Test-ECTOSRawZipExactFailureOracle -ExpectedFailureId ([string]$fixture.expected_failure_id) -ExpectedStage ([string]$expectedCatalogRow[0].failure_stage) -ActualFailures $actualFailures
            $oracleResult | Should Be $false
        }
    }
}
