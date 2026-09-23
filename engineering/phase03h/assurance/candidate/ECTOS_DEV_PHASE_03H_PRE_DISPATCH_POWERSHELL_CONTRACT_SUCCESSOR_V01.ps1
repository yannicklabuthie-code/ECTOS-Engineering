Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Repository = 'yannicklabuthie-code/ECTOS-Engineering'
$Branch = 'main'
$ExpectedMainHead = '224b097ef3207f3725565bb23f2aa13beb3d3352'
$WorkflowPath = '.github/workflows/ectos-phase03f-host-currentness-probe-v01.yml'
$WorkflowFileName = 'ectos-phase03f-host-currentness-probe-v01.yml'
$WorkflowName = 'ECTOS Phase 03F Host Currentness Probe V01'
$ExpectedWorkflowBlobSha = '356b3b6406fc77e25700ca251ee87e1a3f62e0cb'
$ExpectedWorkflowSizeBytes = 10360
$ExpectedWorkflowSha256 = 'F6705A09EAEBC45925575D91FF615CBB5FB4B0697E899742AACEDE4E10CD6B8C'
$ExpectedWorkflowState = 'active'
$GitHubApiVersion = '2026-03-10'
$ProcessTimeoutMilliseconds = 30000

function New-NormalizedList {
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName,

        [switch]$RejectNestedCollections
    )

    $normalizedList = New-Object System.Collections.ArrayList

    if ($null -eq $Value) {
        Write-Output -NoEnumerate $normalizedList
        return
    }

    $isString = $Value -is [string]
    $isDictionary = $Value -is [System.Collections.IDictionary]
    $isEnumerable = $Value -is [System.Collections.IEnumerable]

    if ($isString -or $isDictionary -or (-not $isEnumerable)) {
        [void]$normalizedList.Add($Value)
        Write-Output -NoEnumerate $normalizedList
        return
    }

    foreach ($normalizedItem in $Value) {
        if ($RejectNestedCollections) {
            $itemIsString = $normalizedItem -is [string]
            $itemIsDictionary = $normalizedItem -is [System.Collections.IDictionary]
            $itemIsEnumerable = $normalizedItem -is [System.Collections.IEnumerable]
            $itemIsPsCustomObject = $normalizedItem -is [System.Management.Automation.PSCustomObject]

            if ($itemIsEnumerable -and (-not $itemIsString) -and (-not $itemIsDictionary) -and (-not $itemIsPsCustomObject)) {
                throw ('BLOCKED_NESTED_COLLECTION BOUNDARY={0}' -f $BoundaryName)
            }
        }

        [void]$normalizedList.Add($normalizedItem)
    }

    Write-Output -NoEnumerate $normalizedList
}

function Assert-ExactCount {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$List,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedCount,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName
    )

    if ($List.Count -ne $ExpectedCount) {
        throw ('BLOCKED_CARDINALITY BOUNDARY={0} EXPECTED={1} OBSERVED={2}' -f $BoundaryName, $ExpectedCount, $List.Count)
    }
}

function Assert-PropertyPresent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName
    )

    $propertyObject = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $propertyObject) {
        throw ('BLOCKED_MISSING_PROPERTY BOUNDARY={0} PROPERTY={1}' -f $BoundaryName, $PropertyName)
    }
}

function ConvertFrom-ExpectedJsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonText,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        throw ('BLOCKED_EMPTY_JSON BOUNDARY={0}' -f $BoundaryName)
    }

    try {
        $parsedObject = $JsonText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw ('BLOCKED_MALFORMED_JSON BOUNDARY={0}' -f $BoundaryName)
    }

    if ($null -eq $parsedObject) {
        throw ('BLOCKED_NULL_JSON BOUNDARY={0}' -f $BoundaryName)
    }

    if (-not ($parsedObject -is [System.Management.Automation.PSCustomObject])) {
        throw ('BLOCKED_UNEXPECTED_JSON_ROOT_SHAPE BOUNDARY={0}' -f $BoundaryName)
    }

    return $parsedObject
}

function ConvertTo-SafeNativeArgumentString {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$Arguments
    )

    $safeArguments = New-Object System.Collections.ArrayList

    foreach ($argumentValue in $Arguments) {
        if ($null -eq $argumentValue) {
            throw 'BLOCKED_NULL_NATIVE_ARGUMENT'
        }

        $argumentText = [string]$argumentValue
        if ([string]::IsNullOrEmpty($argumentText)) {
            throw 'BLOCKED_EMPTY_NATIVE_ARGUMENT'
        }

        if ($argumentText -match '[\s"]') {
            throw ('BLOCKED_UNSAFE_NATIVE_ARGUMENT VALUE={0}' -f $argumentText)
        }

        [void]$safeArguments.Add($argumentText)
    }

    return ($safeArguments -join ' ')
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMilliseconds
    )

    $argumentString = ConvertTo-SafeNativeArgumentString -Arguments $Arguments
    $startedAt = [DateTime]::UtcNow.ToString('o')

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $Executable
    $processInfo.Arguments = $argumentString
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true

    $processObject = New-Object System.Diagnostics.Process
    $processObject.StartInfo = $processInfo

    try {
        $started = $processObject.Start()
        if (-not $started) {
            throw 'BLOCKED_NATIVE_PROCESS_DID_NOT_START'
        }

        $stdoutTask = $processObject.StandardOutput.ReadToEndAsync()
        $stderrTask = $processObject.StandardError.ReadToEndAsync()
        $exited = $processObject.WaitForExit($TimeoutMilliseconds)

        $timeoutState = 'NO_TIMEOUT'
        if (-not $exited) {
            $timeoutState = 'TIMEOUT'
            try {
                $processObject.Kill()
            }
            catch {
                throw 'BLOCKED_PROCESS_TIMEOUT_TERMINATION_FAILED'
            }

            $terminatedAfterKill = $processObject.WaitForExit(5000)
            if (-not $terminatedAfterKill) {
                throw 'BLOCKED_PROCESS_TIMEOUT_TERMINATION_NOT_CONFIRMED'
            }
        }

        $stdoutText = $stdoutTask.Result
        $stderrText = $stderrTask.Result
        $exitCodeValue = $processObject.ExitCode
        $completedAt = [DateTime]::UtcNow.ToString('o')

        $resultObject = [pscustomobject]@{
            Executable = $Executable
            Arguments = $argumentString
            WorkingDirectory = $WorkingDirectory
            StartedAt = $startedAt
            CompletedAt = $completedAt
            TimeoutState = $timeoutState
            ExitCode = $exitCodeValue
            StdOut = [string]$stdoutText
            StdErr = [string]$stderrText
        }

        return $resultObject
    }
    finally {
        $processObject.Dispose()
    }
}

function Assert-ProcessSuccess {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ProcessResult,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName,

        [switch]$RequireStdOut,

        [switch]$RequireEmptyStdErr
    )

    if ([string]$ProcessResult.TimeoutState -ne 'NO_TIMEOUT') {
        throw ('BLOCKED_PROCESS_TIMEOUT BOUNDARY={0}' -f $BoundaryName)
    }

    if ([int]$ProcessResult.ExitCode -ne 0) {
        throw ('BLOCKED_PROCESS_NONZERO_EXIT BOUNDARY={0} EXIT_CODE={1}' -f $BoundaryName, $ProcessResult.ExitCode)
    }

    if ($RequireStdOut -and [string]::IsNullOrWhiteSpace([string]$ProcessResult.StdOut)) {
        throw ('BLOCKED_EMPTY_STDOUT BOUNDARY={0}' -f $BoundaryName)
    }

    if ($RequireEmptyStdErr -and (-not [string]::IsNullOrWhiteSpace([string]$ProcessResult.StdErr))) {
        throw ('BLOCKED_UNEXPECTED_STDERR BOUNDARY={0}' -f $BoundaryName)
    }
}

function Invoke-GhReadOnly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GhExecutable,

        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMilliseconds,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName,

        [switch]$RequireStdOut,

        [switch]$RequireEmptyStdErr
    )

    $resultObject = Invoke-BoundedProcess -Executable $GhExecutable -Arguments $Arguments -WorkingDirectory $WorkingDirectory -TimeoutMilliseconds $TimeoutMilliseconds
    Assert-ProcessSuccess -ProcessResult $resultObject -BoundaryName $BoundaryName -RequireStdOut:$RequireStdOut -RequireEmptyStdErr:$RequireEmptyStdErr
    return $resultObject
}

function New-GhApiArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion
    )

    $argumentList = New-Object System.Collections.ArrayList
    [void]$argumentList.Add('api')
    [void]$argumentList.Add($Endpoint)
    [void]$argumentList.Add('--method')
    [void]$argumentList.Add('GET')
    [void]$argumentList.Add('--header')
    [void]$argumentList.Add('Accept:application/vnd.github+json')
    [void]$argumentList.Add('--header')
    [void]$argumentList.Add(('X-GitHub-Api-Version:{0}' -f $ApiVersion))
    Write-Output -NoEnumerate $argumentList
}

$workingDirectory = (Get-Location).ProviderPath

$ghCommandRaw = Get-Command -Name 'gh.exe' -CommandType Application -All -ErrorAction SilentlyContinue
$ghCommandList = New-NormalizedList -Value $ghCommandRaw -BoundaryName 'GH_EXECUTABLE_BINDING' -RejectNestedCollections
Assert-ExactCount -List $ghCommandList -ExpectedCount 1 -BoundaryName 'GH_EXECUTABLE_BINDING'
$ghExecutable = [string]$ghCommandList[0].Source

if ([string]::IsNullOrWhiteSpace($ghExecutable)) {
    throw 'BLOCKED_GH_EXECUTABLE_PATH_EMPTY'
}

$versionArguments = New-Object System.Collections.ArrayList
[void]$versionArguments.Add('--version')
$versionResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $versionArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'GH_VERSION' -RequireStdOut -RequireEmptyStdErr
$versionReader = New-Object System.IO.StringReader([string]$versionResult.StdOut)
$ghVersionLine = $versionReader.ReadLine()
$versionReader.Dispose()

if ([string]::IsNullOrWhiteSpace($ghVersionLine)) {
    throw 'BLOCKED_GH_VERSION_UNPARSEABLE'
}

$authArguments = New-Object System.Collections.ArrayList
[void]$authArguments.Add('auth')
[void]$authArguments.Add('status')
[void]$authArguments.Add('--hostname')
[void]$authArguments.Add('github.com')
$authResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $authArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'GH_AUTH'

$headEndpoint = 'repos/{0}/commits/{1}' -f $Repository, $Branch
$headArguments = New-GhApiArguments -Endpoint $headEndpoint -ApiVersion $GitHubApiVersion
$headResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $headArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'CURRENT_MAIN_HEAD' -RequireStdOut -RequireEmptyStdErr
$headObject = ConvertFrom-ExpectedJsonObject -JsonText ([string]$headResult.StdOut) -BoundaryName 'CURRENT_MAIN_HEAD_JSON'
Assert-PropertyPresent -Object $headObject -PropertyName 'sha' -BoundaryName 'CURRENT_MAIN_HEAD_SCHEMA'
$currentMainHead = [string]$headObject.sha

if ($currentMainHead -notmatch '^[0-9a-f]{40}$') {
    throw 'BLOCKED_MAIN_HEAD_SCHEMA_INVALID'
}

if ($currentMainHead -cne $ExpectedMainHead) {
    throw ('BLOCKED_SOURCE_CURRENTNESS_CHANGED HEAD={0}' -f $currentMainHead)
}

$treeEndpoint = 'repos/{0}/git/trees/{1}?recursive=1' -f $Repository, $currentMainHead
$treeArguments = New-GhApiArguments -Endpoint $treeEndpoint -ApiVersion $GitHubApiVersion
$treeResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $treeArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'RECURSIVE_GIT_TREE' -RequireStdOut -RequireEmptyStdErr
$treeObject = ConvertFrom-ExpectedJsonObject -JsonText ([string]$treeResult.StdOut) -BoundaryName 'RECURSIVE_GIT_TREE_JSON'
Assert-PropertyPresent -Object $treeObject -PropertyName 'truncated' -BoundaryName 'RECURSIVE_GIT_TREE_SCHEMA'
Assert-PropertyPresent -Object $treeObject -PropertyName 'tree' -BoundaryName 'RECURSIVE_GIT_TREE_SCHEMA'

if ($treeObject.truncated -isnot [bool]) {
    throw 'BLOCKED_GIT_TREE_TRUNCATED_PROPERTY_TYPE'
}

if ([bool]$treeObject.truncated) {
    throw 'BLOCKED_GIT_TREE_TRUNCATED'
}

$treeItems = New-NormalizedList -Value $treeObject.tree -BoundaryName 'GIT_TREE_ITEMS' -RejectNestedCollections
$matchingTreeEntries = New-Object System.Collections.ArrayList

foreach ($treeEntry in $treeItems) {
    if (-not ($treeEntry -is [System.Management.Automation.PSCustomObject])) {
        throw 'BLOCKED_GIT_TREE_ITEM_SCHEMA'
    }

    Assert-PropertyPresent -Object $treeEntry -PropertyName 'path' -BoundaryName 'GIT_TREE_ITEM_SCHEMA'
    if ([string]$treeEntry.path -ceq $WorkflowPath) {
        [void]$matchingTreeEntries.Add($treeEntry)
    }
}

Assert-ExactCount -List $matchingTreeEntries -ExpectedCount 1 -BoundaryName 'WORKFLOW_PATH_BINDING'
$workflowTreeEntry = $matchingTreeEntries[0]
Assert-PropertyPresent -Object $workflowTreeEntry -PropertyName 'type' -BoundaryName 'WORKFLOW_TREE_ENTRY_SCHEMA'
Assert-PropertyPresent -Object $workflowTreeEntry -PropertyName 'sha' -BoundaryName 'WORKFLOW_TREE_ENTRY_SCHEMA'

if ([string]$workflowTreeEntry.type -cne 'blob') {
    throw ('BLOCKED_WORKFLOW_TREE_ENTRY_TYPE TYPE={0}' -f $workflowTreeEntry.type)
}

$observedWorkflowBlobSha = [string]$workflowTreeEntry.sha
if ($observedWorkflowBlobSha -cne $ExpectedWorkflowBlobSha) {
    throw ('BLOCKED_WORKFLOW_BLOB_CHANGED SHA={0}' -f $observedWorkflowBlobSha)
}

$blobEndpoint = 'repos/{0}/git/blobs/{1}' -f $Repository, $observedWorkflowBlobSha
$blobArguments = New-GhApiArguments -Endpoint $blobEndpoint -ApiVersion $GitHubApiVersion
$blobResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $blobArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'EXACT_GIT_BLOB' -RequireStdOut -RequireEmptyStdErr
$blobObject = ConvertFrom-ExpectedJsonObject -JsonText ([string]$blobResult.StdOut) -BoundaryName 'EXACT_GIT_BLOB_JSON'
Assert-PropertyPresent -Object $blobObject -PropertyName 'sha' -BoundaryName 'EXACT_GIT_BLOB_SCHEMA'
Assert-PropertyPresent -Object $blobObject -PropertyName 'encoding' -BoundaryName 'EXACT_GIT_BLOB_SCHEMA'
Assert-PropertyPresent -Object $blobObject -PropertyName 'content' -BoundaryName 'EXACT_GIT_BLOB_SCHEMA'

if ([string]$blobObject.sha -cne $ExpectedWorkflowBlobSha) {
    throw ('BLOCKED_BLOB_RESPONSE_IDENTITY_CHANGED SHA={0}' -f $blobObject.sha)
}

if ([string]$blobObject.encoding -cne 'base64') {
    throw ('BLOCKED_UNEXPECTED_BLOB_ENCODING ENCODING={0}' -f $blobObject.encoding)
}

if ([string]::IsNullOrWhiteSpace([string]$blobObject.content)) {
    throw 'BLOCKED_EMPTY_BLOB_CONTENT'
}

try {
    $workflowBytes = [Convert]::FromBase64String(([string]$blobObject.content -replace '\s', ''))
}
catch {
    throw 'BLOCKED_BLOB_BASE64_DECODE_FAILED'
}

if ($workflowBytes.Length -ne $ExpectedWorkflowSizeBytes) {
    throw ('BLOCKED_WORKFLOW_SIZE_CHANGED SIZE={0}' -f $workflowBytes.Length)
}

$shaHasher = [Security.Cryptography.SHA256]::Create()
try {
    $observedWorkflowSha256 = [BitConverter]::ToString($shaHasher.ComputeHash($workflowBytes)).Replace('-', '')
}
finally {
    $shaHasher.Dispose()
}

if ($observedWorkflowSha256 -cne $ExpectedWorkflowSha256) {
    throw ('BLOCKED_WORKFLOW_SHA256_CHANGED SHA256={0}' -f $observedWorkflowSha256)
}

$workflowEndpoint = 'repos/{0}/actions/workflows/{1}' -f $Repository, $WorkflowFileName
$workflowArguments = New-GhApiArguments -Endpoint $workflowEndpoint -ApiVersion $GitHubApiVersion
$workflowResult = Invoke-GhReadOnly -GhExecutable $ghExecutable -Arguments $workflowArguments -WorkingDirectory $workingDirectory -TimeoutMilliseconds $ProcessTimeoutMilliseconds -BoundaryName 'EXACT_WORKFLOW_METADATA' -RequireStdOut -RequireEmptyStdErr
$workflowObject = ConvertFrom-ExpectedJsonObject -JsonText ([string]$workflowResult.StdOut) -BoundaryName 'EXACT_WORKFLOW_METADATA_JSON'
Assert-PropertyPresent -Object $workflowObject -PropertyName 'path' -BoundaryName 'EXACT_WORKFLOW_METADATA_SCHEMA'
Assert-PropertyPresent -Object $workflowObject -PropertyName 'name' -BoundaryName 'EXACT_WORKFLOW_METADATA_SCHEMA'
Assert-PropertyPresent -Object $workflowObject -PropertyName 'state' -BoundaryName 'EXACT_WORKFLOW_METADATA_SCHEMA'
Assert-PropertyPresent -Object $workflowObject -PropertyName 'id' -BoundaryName 'EXACT_WORKFLOW_METADATA_SCHEMA'

if ([string]$workflowObject.path -cne $WorkflowPath) {
    throw ('BLOCKED_WORKFLOW_PATH_CHANGED PATH={0}' -f $workflowObject.path)
}

if ([string]$workflowObject.name -cne $WorkflowName) {
    throw ('BLOCKED_WORKFLOW_NAME_CHANGED NAME={0}' -f $workflowObject.name)
}

if ([string]$workflowObject.state -cne $ExpectedWorkflowState) {
    throw ('BLOCKED_WORKFLOW_NOT_ACTIVE STATE={0}' -f $workflowObject.state)
}

Write-Output ('GH_CLI_VERSION={0}' -f $ghVersionLine)
Write-Output ('GITHUB_API_VERSION={0}' -f $GitHubApiVersion)
Write-Output ('CURRENT_MAIN_HEAD={0}' -f $currentMainHead)
Write-Output 'HEAD_MATCH=YES'
Write-Output 'WORKFLOW_PATH_BINDING=PASS'
Write-Output ('WORKFLOW_GIT_BLOB_SHA={0}' -f $observedWorkflowBlobSha)
Write-Output ('WORKFLOW_SIZE_BYTES={0}' -f $workflowBytes.Length)
Write-Output ('WORKFLOW_SHA256={0}' -f $observedWorkflowSha256)
Write-Output ('WORKFLOW_ID={0}' -f $workflowObject.id)
Write-Output ('WORKFLOW_NAME={0}' -f $workflowObject.name)
Write-Output ('WORKFLOW_PATH={0}' -f $workflowObject.path)
Write-Output ('WORKFLOW_STATE={0}' -f $workflowObject.state)
Write-Output 'WORKFLOW_METADATA_IDENTITY=PASS'
Write-Output 'PRE_DISPATCH_CURRENTNESS_GATE=PASS'
Write-Output 'PHASE_03H_DISPATCH_READY=YES_FOR_MAIN_ADJUDICATION_ONLY'
Write-Output 'WORKFLOW_DISPATCH_COUNT=0'
Write-Output 'HOST_PROBE_RUN_COUNT=0'
Write-Output 'ZERO_MUTATION=PASS'
Write-Output 'STOP_BEFORE_DISPATCH=YES'
