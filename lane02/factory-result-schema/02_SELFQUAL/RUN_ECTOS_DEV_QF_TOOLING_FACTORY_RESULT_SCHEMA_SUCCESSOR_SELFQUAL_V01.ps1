[CmdletBinding()]
param(
    [string]$ReaderPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ReaderPath)) {
    $ReaderPath = Join-Path $PSScriptRoot '..\01_SUCCESSOR\ECTOS_DEV_QF_TOOLING_FACTORY_DIAGNOSTIC_RESULT_SCHEMA_READER_V02.ps1'
}

$ReaderPath = [System.IO.Path]::GetFullPath($ReaderPath)

function Assert-ECTOS {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$FailureId
    )
    if (-not $Condition) {
        throw $FailureId
    }
}

$parseErrorsReader = $null
$tokensReader = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $ReaderPath,
    [ref]$tokensReader,
    [ref]$parseErrorsReader
)
Assert-ECTOS -Condition (@($parseErrorsReader).Count -eq 0) -FailureId 'READER_PARSE_FAIL'

$parseErrorsSelf = $null
$tokensSelf = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $PSCommandPath,
    [ref]$tokensSelf,
    [ref]$parseErrorsSelf
)
Assert-ECTOS -Condition (@($parseErrorsSelf).Count -eq 0) -FailureId 'SELFQUAL_PARSE_FAIL'

. $ReaderPath

# ----------------------------------------------------------------------
# EARLY FAIL FIXTURE
# Success-only field ACTUAL_LOADED_PSSA_VERSION is intentionally absent.
# ----------------------------------------------------------------------
$earlyFail = [pscustomobject][ordered]@{
    DIAGNOSTIC_STATUS = 'FAIL_CLOSED'
    CURRENT_DIAGNOSTIC_ENVIRONMENT_BLOCKER = 'PSSCRIPTANALYZER_NOT_INSTALLED'
    ROOT_CAUSE_CLASS = 'NOT_ESTABLISHED'
    ROOT_CAUSE_PROVEN = 'NO'
    PRODUCT_DEFECT_PROVEN = 'NO'
}

$earlyBeforeNames = @($earlyFail.PSObject.Properties | Select-Object -ExpandProperty Name)
$earlyBeforeRootCause = [string](($earlyFail.PSObject.Properties | Where-Object { $_.Name -ceq 'ROOT_CAUSE_CLASS' })[0].Value)

$earlyException = $null
$earlyRead = $null
try {
    $earlyRead = Read-ECTOSFactoryDiagnosticResult -ResultObject $earlyFail
}
catch {
    $earlyException = $_
}

Assert-ECTOS -Condition ($null -eq $earlyException) -FailureId 'EARLY_FAIL_READER_EXCEPTION'
Assert-ECTOS -Condition ($earlyRead.READ_RESULT -ceq 'PASS') -FailureId 'EARLY_FAIL_READ_RESULT'
Assert-ECTOS -Condition ($earlyRead.SUCCESS_ONLY_FIELD_PRESENT -ceq 'NO') -FailureId 'EARLY_FAIL_OPTIONAL_FIELD_PRESENT'
Assert-ECTOS -Condition ($earlyRead.OPTIONAL_FIELD_HANDLING_RESULT -ceq 'ABSENT_SUCCESS_ONLY_FIELD_ACCEPTED_WITHOUT_SYNTHESIS') -FailureId 'EARLY_FAIL_OPTIONAL_HANDLING'
Assert-ECTOS -Condition ([int]$earlyRead.VALUE_SYNTHESIS_COUNT -eq 0) -FailureId 'EARLY_FAIL_VALUE_SYNTHESIS'
Assert-ECTOS -Condition ([int]$earlyRead.ROOT_CAUSE_FABRICATION_COUNT -eq 0) -FailureId 'EARLY_FAIL_ROOT_CAUSE_FABRICATION'
Assert-ECTOS -Condition (-not (@($earlyFail.PSObject.Properties | Select-Object -ExpandProperty Name) -contains 'ACTUAL_LOADED_PSSA_VERSION')) -FailureId 'EARLY_FAIL_FIELD_SYNTHESIZED'
Assert-ECTOS -Condition ([string](($earlyFail.PSObject.Properties | Where-Object { $_.Name -ceq 'ROOT_CAUSE_CLASS' })[0].Value) -ceq $earlyBeforeRootCause) -FailureId 'EARLY_FAIL_ROOT_CAUSE_CHANGED'
Assert-ECTOS -Condition ([string]::Join('|',@($earlyFail.PSObject.Properties | Select-Object -ExpandProperty Name)) -ceq [string]::Join('|',$earlyBeforeNames)) -FailureId 'EARLY_FAIL_SCHEMA_MUTATED'

# ----------------------------------------------------------------------
# SUCCESS FIXTURE
# Success-only field is present and must be preserved exactly.
# ----------------------------------------------------------------------
$success = [pscustomobject][ordered]@{
    DIAGNOSTIC_STATUS = 'PASS'
    ACTUAL_LOADED_PSSA_VERSION = '1.25.0'
    ROOT_CAUSE_CLASS = 'NOT_ESTABLISHED'
    ROOT_CAUSE_PROVEN = 'NO'
    PRODUCT_DEFECT_PROVEN = 'NO'
}

$successBeforeNames = @($success.PSObject.Properties | Select-Object -ExpandProperty Name)
$successBeforePssa = [string](($success.PSObject.Properties | Where-Object { $_.Name -ceq 'ACTUAL_LOADED_PSSA_VERSION' })[0].Value)

$successException = $null
$successRead = $null
try {
    $successRead = Read-ECTOSFactoryDiagnosticResult -ResultObject $success
}
catch {
    $successException = $_
}

Assert-ECTOS -Condition ($null -eq $successException) -FailureId 'SUCCESS_READER_EXCEPTION'
Assert-ECTOS -Condition ($successRead.READ_RESULT -ceq 'PASS') -FailureId 'SUCCESS_READ_RESULT'
Assert-ECTOS -Condition ($successRead.SUCCESS_ONLY_FIELD_PRESENT -ceq 'YES') -FailureId 'SUCCESS_OPTIONAL_FIELD_NOT_PRESENT'
Assert-ECTOS -Condition ($successRead.OPTIONAL_FIELD_HANDLING_RESULT -ceq 'PRESENT_SUCCESS_ONLY_FIELD_PRESERVED_EXACTLY') -FailureId 'SUCCESS_OPTIONAL_HANDLING'
Assert-ECTOS -Condition ([int]$successRead.VALUE_SYNTHESIS_COUNT -eq 0) -FailureId 'SUCCESS_VALUE_SYNTHESIS'
Assert-ECTOS -Condition ([int]$successRead.ROOT_CAUSE_FABRICATION_COUNT -eq 0) -FailureId 'SUCCESS_ROOT_CAUSE_FABRICATION'
Assert-ECTOS -Condition ([string](($success.PSObject.Properties | Where-Object { $_.Name -ceq 'ACTUAL_LOADED_PSSA_VERSION' })[0].Value) -ceq $successBeforePssa) -FailureId 'SUCCESS_OPTIONAL_VALUE_CHANGED'
Assert-ECTOS -Condition ([string]::Join('|',@($success.PSObject.Properties | Select-Object -ExpandProperty Name)) -ceq [string]::Join('|',$successBeforeNames)) -FailureId 'SUCCESS_SCHEMA_MUTATED'

$mandatoryRegression = (
    $null -eq $earlyException -and
    $earlyRead.SUCCESS_ONLY_FIELD_PRESENT -ceq 'NO' -and
    [int]$earlyRead.VALUE_SYNTHESIS_COUNT -eq 0 -and
    [int]$earlyRead.ROOT_CAUSE_FABRICATION_COUNT -eq 0 -and
    $earlyRead.OPTIONAL_FIELD_HANDLING_RESULT -ceq 'ABSENT_SUCCESS_ONLY_FIELD_ACCEPTED_WITHOUT_SYNTHESIS'
)
Assert-ECTOS -Condition $mandatoryRegression -FailureId 'MANDATORY_REGRESSION_FAIL'

$result = [pscustomobject][ordered]@{
    SUCCESSOR_ID = 'ECTOS_DEV_QF_TOOLING_FACTORY_DIAGNOSTIC_RESULT_SCHEMA_READER_V02'
    SUCCESSOR_VERSION = 'V02'
    PS51_HOST_RESULT = $(if ($PSVersionTable.PSEdition -ceq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) { 'PASS' } else { 'FAIL' })
    PS51_VERSION = [string]$PSVersionTable.PSVersion
    PS51_PARSE_RESULT = 'PASS'
    EARLY_FAIL_FIXTURE_RESULT = 'PASS'
    SUCCESS_FIXTURE_RESULT = 'PASS'
    STRICTMODE_RESULT = 'PASS'
    OPTIONAL_FIELD_HANDLING_RESULT = 'PASS'
    VALUE_SYNTHESIS_COUNT = 0
    ROOT_CAUSE_FABRICATION_COUNT = 0
    MANDATORY_REGRESSION = 'PASS'
    SUCCESS_ONLY_FIELD_ASSUMPTION_DEFECT = 'CLOSED'
    ROOT_CAUSE_OF_ATTEMPT01_EXTENT = 'NOT_ESTABLISHED'
    REAL_PRODUCT_EXECUTION_COUNT = 0
    REAL_V03_EXECUTION_COUNT = 0
    V03_MUTATION_COUNT = 0
    PROTECTED_ARTIFACT_MUTATION_COUNT = 0
    GLOBAL_PROJECT_HOLD = 'NO'
}

$result | ConvertTo-Json -Depth 8
