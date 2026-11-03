[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Qc02ContractPath,
    [Parameter(Mandatory = $true)][string]$ToolRegistryPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$QcModulePath = Join-Path $PSScriptRoot 'QC.Common.psm1'
Import-Module -Name $QcModulePath -Force

$Qc02 = Import-QcJson -LiteralPath $Qc02ContractPath
if ([string]$Qc02.status -ne 'PASS') {
    throw 'QC03_UPSTREAM_QC02_NOT_PASS'
}
$QcRegistry = Import-QcJson -LiteralPath $ToolRegistryPath
$QcTools = @(ConvertTo-QcArray -Value $QcRegistry.tools)
# F04/F05 V46: validate complete signed registry at independently provisioned host root.
$QcBridge = Join-Path $PSScriptRoot 'authority_bridge_v46.py'
$QcPython = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetFullPath((Split-Path -Parent $OutputPath))) | Out-Null
$QcGateEvidence = Join-Path (Split-Path -Parent $OutputPath) 'QC03_V46_AUTHORITY.json'
$QcEnvelopeProperty = $QcRegistry.PSObject.Properties['authority_envelope_ref']
$QcEnvelope = if ($null -eq $QcEnvelopeProperty) { '' } else { [string]$QcEnvelopeProperty.Value }
$QcGateArgs = @($QcBridge,'--mode','qc03','--subject',$ToolRegistryPath,'--output',$QcGateEvidence)
if (-not [string]::IsNullOrWhiteSpace($QcEnvelope)) { $QcGateArgs += @('--envelope',$QcEnvelope) }
$QcGateText = & $QcPython.Source @QcGateArgs 2>&1
$QcGateExit = $LASTEXITCODE
$QcExternalToolRootVerified = ($QcGateExit -eq 0 -and (Test-Path -LiteralPath $QcGateEvidence -PathType Leaf) -and [string](Import-QcJson -LiteralPath $QcGateEvidence).status -eq 'VERIFIED_FOR_NATIVE_STAGE_ONLY')

if ($QcTools.Count -eq 0) {
    throw 'QC03_TOOL_REGISTRY_EMPTY'
}

function Read-QcField($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $QcFieldProperty = $Object.PSObject.Properties[$Name]
    if ($null -ne $QcFieldProperty) { return $QcFieldProperty.Value }
    return $null
}
$QcContracts = @(ConvertTo-QcArray -Value (Read-QcField $Qc02 'property_contracts'))
$QcContractIds = @($QcContracts | ForEach-Object { [string](Read-QcField $_ 'property_id') })
$QcInputDefects = @()
if ([string](Read-QcField $QcRegistry 'target_package_id') -cne [string]$Qc02.target_package_id -or [string](Read-QcField $QcRegistry 'target_package_sha256') -ne [string]$Qc02.target_package_sha256) { $QcInputDefects += 'SIGNED_REGISTRY_TARGET_MISMATCH' }
$QcExpectedControlIds = @()
foreach ($contract in $QcContracts) { $QcExpectedControlIds += [string]$contract.positive_control_id; $QcExpectedControlIds += @(ConvertTo-QcArray -Value $contract.negative_control_ids) }
$QcRegistryControlIds = @($QcTools | ForEach-Object { [string](Read-QcField $_ 'control_id') })
if (@($QcRegistryControlIds | Sort-Object -Unique).Count -ne $QcRegistryControlIds.Count -or (($QcExpectedControlIds | Sort-Object -Unique) -join '|') -cne (($QcRegistryControlIds | Sort-Object) -join '|')) { $QcInputDefects += 'SIGNED_REGISTRY_CONTROL_SET_MISMATCH' }
if ($QcContracts.Count -eq 0 -or @($QcContractIds | Sort-Object -Unique).Count -ne $QcContractIds.Count -or [int](Read-QcField $Qc02 'required_property_count') -ne $QcContracts.Count) { $QcInputDefects += 'CONTRACT_UNIVERSE_INVALID' }
$QcRoutes = @()
$QcMissing = @()
$QcUntrusted = @()
$QcUnsupported = @($QcInputDefects)
$QcRouteIndex = 0

foreach ($QcContract in @(ConvertTo-QcArray -Value $Qc02.property_contracts)) {
    $QcControls = @([string](Read-QcField $QcContract 'positive_control_id'))
    $QcControls += @(ConvertTo-QcArray -Value (Read-QcField $QcContract 'negative_control_ids') | ForEach-Object { [string]$_ })
    foreach ($QcControlId in $QcControls) {
        $QcMatches = @($QcTools | Where-Object { [string]$_.control_id -eq $QcControlId })
        if ($QcMatches.Count -eq 0) {
            $QcMissing += "$([string](Read-QcField $QcContract 'property_id'))|$QcControlId"
            continue
        }
        if ($QcMatches.Count -gt 1) {
            $QcUnsupported += "AMBIGUOUS_TOOL_ROUTE|$([string](Read-QcField $QcContract 'property_id'))|$QcControlId"
            continue
        }
        $QcTool = $QcMatches[0]
        $QcTrustOk = ([string](Read-QcField $QcTool 'tool_trust_state') -eq 'TRUSTED')
        $QcCurrentOk = ([string](Read-QcField $QcTool 'tool_currentness_state') -eq 'CURRENT')
        $QcFitOk = ([string](Read-QcField $QcTool 'tool_target_fit') -eq 'PASS')
        if (-not $QcTrustOk -or -not $QcCurrentOk -or -not $QcFitOk) {
            $QcUntrusted += "$([string](Read-QcField $QcContract 'property_id'))|$QcControlId|TRUST=$([string](Read-QcField $QcTool 'tool_trust_state'))|CURRENT=$([string](Read-QcField $QcTool 'tool_currentness_state'))|FIT=$([string](Read-QcField $QcTool 'tool_target_fit'))"
            continue
        }
        $QcCommand = [string](Read-QcField $QcTool 'command_path')
        $QcScript = [string](Read-QcField $QcTool 'script_path')
        $QcScriptSha = [string](Read-QcField $QcTool 'script_sha256')
        $QcCommandSha = [string](Read-QcField $QcTool 'tool_sha256')
        $QcByteBindingOk = $true
        foreach ($QcBinding in @(@{ path=$QcCommand; sha=$QcCommandSha }, @{ path=$QcScript; sha=$QcScriptSha })) {
            if ([string]$QcBinding.sha -notmatch '^[A-Fa-f0-9]{64}$' -or -not (Test-Path -LiteralPath ([string]$QcBinding.path) -PathType Leaf)) { $QcByteBindingOk = $false }
            elseif ((Get-QcSha256 -LiteralPath ([string]$QcBinding.path)) -ne ([string]$QcBinding.sha).ToLowerInvariant()) { $QcByteBindingOk = $false }
        }
        if (-not $QcByteBindingOk) { $QcUnsupported += "TOOL_OR_SCRIPT_BYTE_BINDING_INVALID|$QcControlId"; continue }
        if ([string](Read-QcField $QcTool 'platform_profile') -ne [string](Read-QcField $QcContract 'platform_profile') -or [string](Read-QcField $QcTool 'runtime_profile') -ne [string](Read-QcField $QcContract 'runtime_profile') -or [string](Read-QcField $QcTool 'qualification_profile') -ne [string](Read-QcField $QcContract 'qualification_profile') -or [string](Read-QcField $QcTool 'host_trust_state') -ne 'TRUSTED' -or [string]::IsNullOrWhiteSpace([string](Read-QcField $QcTool 'execution_authority_required'))) { $QcUnsupported += "PROFILE_OR_HOST_AUTHORITY_MISMATCH|$QcControlId"; continue }
        $QcRuntime = [string](Read-QcField $QcTool 'runtime_profile')
        try {
            $QcExecutionProfile = Get-QcExecutionProfile $QcContract
            $QcToolExecutionProfile = Get-QcExecutionProfile $QcTool
            if (($QcExecutionProfile | ConvertTo-Json -Compress) -cne ($QcToolExecutionProfile | ConvertTo-Json -Compress)) { throw 'EXECUTION_PROFILE_MISMATCH' }
        } catch { $QcUnsupported += ("EXECUTION_PROFILE_INVALID|$QcControlId|" + $_.Exception.Message); continue }
        if (-not (Test-QcNativeExecutionHost)) { $QcUnsupported += "NATIVE_RUNTIME_NOT_PROVEN|$QcControlId"; continue }
        if (-not (Test-QcPinnedInvocation -CommandPath $QcCommand -ScriptPath $QcScript -FixedArguments (Read-QcField $QcTool 'fixed_arguments') -DynamicArguments @())) { $QcUnsupported += "PINNED_INVOCATION_CONTRACT_REJECTED|$QcControlId"; continue }
        $QcSpecs = @(ConvertTo-QcArray -Value (Read-QcField $QcContract 'oracle_specifications') | Where-Object { [string](Read-QcField $_ 'control_id') -eq $QcControlId })
        if ($QcSpecs.Count -ne 1) { $QcUnsupported += "ORACLE_SPECIFICATION_NOT_UNIQUE|$QcControlId"; continue }
        $QcProvenanceRef = [string](Read-QcField $QcTool 'tool_provenance_ref')
        $QcProvenanceSha = [string](Read-QcField $QcTool 'tool_provenance_sha256')
        if ([string]::IsNullOrWhiteSpace($QcProvenanceRef) -or $QcProvenanceSha -notmatch '^[A-Fa-f0-9]{64}$' -or -not (Test-Path -LiteralPath $QcProvenanceRef -PathType Leaf)) { $QcUntrusted += "PROVENANCE_BYTES_UNAVAILABLE|$QcControlId"; continue }
        if ((Get-QcSha256 -LiteralPath $QcProvenanceRef) -ne $QcProvenanceSha.ToLowerInvariant()) { $QcUntrusted += "PROVENANCE_SHA_MISMATCH|$QcControlId"; continue }
        try { $QcReceipt = Import-QcJson -LiteralPath $QcProvenanceRef }
        catch { $QcUntrusted += "PROVENANCE_INVALID_JSON|$QcControlId"; continue }
        $QcReceiptOk = $true
        foreach ($QcPair in @(@{name='target_package_id'; expected=[string]$Qc02.target_package_id}, @{name='target_package_sha256'; expected=[string]$Qc02.target_package_sha256}, @{name='tool_id'; expected=[string](Read-QcField $QcTool 'tool_id')}, @{name='tool_sha256'; expected=$QcCommandSha}, @{name='script_sha256'; expected=$QcScriptSha}, @{name='runtime_profile'; expected=$QcRuntime}, @{name='platform_profile'; expected=[string](Read-QcField $QcContract 'platform_profile')}, @{name='host_id'; expected=[string](Read-QcField $QcTool 'host_id')}, @{name='qualification_profile'; expected=[string](Read-QcField $QcContract 'qualification_profile')}, @{name='approval_state'; expected='APPROVED'}, @{name='currentness_state'; expected='CURRENT'})) {
            if ([string](Read-QcField $QcReceipt ([string]$QcPair.name)) -ne [string]$QcPair.expected) { $QcReceiptOk = $false }
        }
        try {
            $QcReceiptExecutionProfile = Get-QcExecutionProfile $QcReceipt
            if (($QcReceiptExecutionProfile | ConvertTo-Json -Compress) -cne ($QcExecutionProfile | ConvertTo-Json -Compress)) { $QcReceiptOk = $false }
        } catch { $QcReceiptOk = $false }
        if (-not $QcReceiptOk) { $QcUntrusted += "PROVENANCE_BINDING_INVALID|$QcControlId"; continue }
        if (-not $QcExternalToolRootVerified) { $QcUntrusted += "EXTERNAL_TRUST_ROOT_NOT_PROVEN|$QcControlId" }
        $QcRouteIndex++
        $QcRoutes += [pscustomobject][ordered]@{
            route_id = ('ROUTE-{0:D4}' -f $QcRouteIndex)
            property_id = [string](Read-QcField $QcContract 'property_id')
            control_id = $QcControlId
            tool_id = [string](Read-QcField $QcTool 'tool_id')
            tool_version = [string](Read-QcField $QcTool 'tool_version')
            tool_sha256 = [string](Read-QcField $QcTool 'tool_sha256')
            tool_trust_state = [string](Read-QcField $QcTool 'tool_trust_state')
            tool_currentness_state = [string](Read-QcField $QcTool 'tool_currentness_state')
            platform_profile = [string](Read-QcField $QcTool 'platform_profile')
            runtime_profile = [string](Read-QcField $QcTool 'runtime_profile')
            execution_profile = $QcExecutionProfile
            qualification_profile = [string](Read-QcField $QcContract 'qualification_profile')
            oracle_id = [string](Read-QcField $QcContract 'oracle_id')
            oracle_type = [string](Read-QcField $QcContract 'oracle_type')
            oracle_specification = $QcSpecs[0]
            script_path = $QcScript
            script_sha256 = $QcScriptSha
            tool_provenance_ref = $QcProvenanceRef
            tool_provenance_sha256 = $QcProvenanceSha
            trust_root_state = $(if ($QcExternalToolRootVerified) { 'EXTERNAL_ROOT_VERIFIED_FOR_STAGE' } else { 'NOT_PROVEN' })
            expected_property = [string](Read-QcField $QcContract 'expected_property')
            host_id = [string](Read-QcField $QcTool 'host_id')
            host_trust_state = [string](Read-QcField $QcTool 'host_trust_state')
            tool_target_fit = [string](Read-QcField $QcTool 'tool_target_fit')
            expected_evidence_schema_id = [string](Read-QcField $QcTool 'expected_evidence_schema_id')
            execution_authority_required = [string](Read-QcField $QcTool 'execution_authority_required')
            command_path = [string](Read-QcField $QcTool 'command_path')
            fixed_arguments = @(ConvertTo-QcArray -Value (Read-QcField $QcTool 'fixed_arguments'))
            route_status = $(if ($QcExternalToolRootVerified) { 'PASS' } else { 'NOT_PROVEN' })
        }
    }
}

$QcRequiredControlCount = 0
foreach ($QcContract in @(ConvertTo-QcArray -Value $Qc02.property_contracts)) {
    $QcRequiredControlCount += 1
    $QcRequiredControlCount += @(ConvertTo-QcArray -Value (Read-QcField $QcContract 'negative_control_ids')).Count
}
foreach ($QcSchemaRoute in $QcRoutes) {
    try { $null = Assert-QcSchema -Value $QcSchemaRoute -SchemaName 'tool-route-v01.schema.json' }
    catch { $QcUnsupported += ('ROUTE_SCHEMA_INVALID|' + $_.Exception.Message) }
}
$QcStatus = 'PASS'
if ($QcRoutes.Count -ne $QcRequiredControlCount -or $QcMissing.Count -gt 0 -or $QcUntrusted.Count -gt 0 -or $QcUnsupported.Count -gt 0) {
    $QcStatus = 'BLOCKED'
}
$QcReturn = [pscustomobject][ordered]@{
    schema_id = 'ECTOS_QC03_TOOL_FIT_RETURN_V01'
    component_id = 'QC-03'
    status = $QcStatus
    target_package_id = [string]$Qc02.target_package_id
    target_package_sha256 = [string]$Qc02.target_package_sha256
    contract_source_provenance = Read-QcField $Qc02 'contract_source_provenance'
    independent_tool_trust = $(if ($QcExternalToolRootVerified -and $QcUntrusted.Count -eq 0 -and $QcUnsupported.Count -eq 0) { 'EXTERNAL_ROOT_AND_TOOL_BYTES_VERIFIED' } else { 'NOT_PROVEN' })
    required_control_count = $QcRequiredControlCount
    route_count = $QcRoutes.Count
    routes = $QcRoutes
    missing_tool_register = $QcMissing
    untrusted_tool_register = $QcUntrusted
    unsupported_profile_register = $QcUnsupported
    tool_target_fit = $QcStatus
}
Export-QcJson -Value $QcReturn -LiteralPath $OutputPath
if ($QcStatus -eq 'PASS') { exit 0 }
exit 40
