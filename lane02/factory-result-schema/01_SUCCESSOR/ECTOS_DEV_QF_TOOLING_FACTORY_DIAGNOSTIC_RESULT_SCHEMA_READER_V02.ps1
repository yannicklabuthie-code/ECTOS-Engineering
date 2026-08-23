Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ECTOS_FACTORY_RESULT_SCHEMA_READER_ID = 'ECTOS_DEV_QF_TOOLING_FACTORY_DIAGNOSTIC_RESULT_SCHEMA_READER_V02'
$script:ECTOS_FACTORY_RESULT_SCHEMA_READER_VERSION = 'V02'

function Get-ECTOSExactProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $matches = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.Name -ceq $Name }
    )

    if ($matches.Count -eq 0) {
        return $null
    }

    if ($matches.Count -ne 1) {
        throw ('FACTORY_RESULT_SCHEMA_DUPLICATE_PROPERTY=' + $Name)
    }

    return $matches[0]
}

function Read-ECTOSFactoryDiagnosticResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$ResultObject
    )

    if ($null -eq $ResultObject) {
        throw 'FACTORY_DIAGNOSTIC_RESULT_OBJECT_NULL'
    }

    $successOnlyFieldName = 'ACTUAL_LOADED_PSSA_VERSION'
    $successOnlyProperty = Get-ECTOSExactProperty -InputObject $ResultObject -Name $successOnlyFieldName

    $optionalFieldHandling = if ($null -eq $successOnlyProperty) {
        'ABSENT_SUCCESS_ONLY_FIELD_ACCEPTED_WITHOUT_SYNTHESIS'
    }
    else {
        'PRESENT_SUCCESS_ONLY_FIELD_PRESERVED_EXACTLY'
    }

    # The original result object is returned unchanged.  No missing success-only
    # property is created, and no root-cause field is inferred or fabricated.
    return [pscustomobject][ordered]@{
        READER_ID = $script:ECTOS_FACTORY_RESULT_SCHEMA_READER_ID
        READER_VERSION = $script:ECTOS_FACTORY_RESULT_SCHEMA_READER_VERSION
        READ_RESULT = 'PASS'
        SUCCESS_ONLY_FIELD_NAME = $successOnlyFieldName
        SUCCESS_ONLY_FIELD_PRESENT = $(if ($null -eq $successOnlyProperty) { 'NO' } else { 'YES' })
        OPTIONAL_FIELD_HANDLING_RESULT = $optionalFieldHandling
        VALUE_SYNTHESIS_COUNT = 0
        ROOT_CAUSE_FABRICATION_COUNT = 0
        ORIGINAL_RESULT = $ResultObject
    }
}
