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
if ($QcTools.Count -eq 0) {
    throw 'QC03_TOOL_REGISTRY_EMPTY'
}

$QcRoutes = @()
$QcMissing = @()
$QcUntrusted = @()
$QcUnsupported = @()
$QcRouteIndex = 0

foreach ($QcContract in @(ConvertTo-QcArray -Value $Qc02.property_contracts)) {
    $QcControls = @([string]$QcContract.positive_control_id)
    $QcControls += @(ConvertTo-QcArray -Value $QcContract.negative_control_ids | ForEach-Object { [string]$_ })
    foreach ($QcControlId in $QcControls) {
        $QcMatches = @($QcTools | Where-Object { [string]$_.control_id -eq $QcControlId })
        if ($QcMatches.Count -eq 0) {
            $QcMissing += "$([string]$QcContract.property_id)|$QcControlId"
            continue
        }
        if ($QcMatches.Count -gt 1) {
            $QcUnsupported += "AMBIGUOUS_TOOL_ROUTE|$([string]$QcContract.property_id)|$QcControlId"
            continue
        }
        $QcTool = $QcMatches[0]
        $QcTrustOk = ([string]$QcTool.tool_trust_state -eq 'TRUSTED')
        $QcCurrentOk = ([string]$QcTool.tool_currentness_state -eq 'CURRENT')
        $QcFitOk = ([string]$QcTool.tool_target_fit -eq 'PASS')
        if (-not $QcTrustOk -or -not $QcCurrentOk -or -not $QcFitOk) {
            $QcUntrusted += "$([string]$QcContract.property_id)|$QcControlId|TRUST=$([string]$QcTool.tool_trust_state)|CURRENT=$([string]$QcTool.tool_currentness_state)|FIT=$([string]$QcTool.tool_target_fit)"
            continue
        }
        $QcRouteIndex++
        $QcRoutes += [pscustomobject][ordered]@{
            route_id = ('ROUTE-{0:D4}' -f $QcRouteIndex)
            property_id = [string]$QcContract.property_id
            control_id = $QcControlId
            tool_id = [string]$QcTool.tool_id
            tool_version = [string]$QcTool.tool_version
            tool_sha256 = [string]$QcTool.tool_sha256
            tool_trust_state = [string]$QcTool.tool_trust_state
            tool_currentness_state = [string]$QcTool.tool_currentness_state
            platform_profile = [string]$QcTool.platform_profile
            runtime_profile = [string]$QcTool.runtime_profile
            qualification_profile = [string]$QcContract.qualification_profile
            host_id = [string]$QcTool.host_id
            host_trust_state = [string]$QcTool.host_trust_state
            tool_target_fit = [string]$QcTool.tool_target_fit
            expected_evidence_schema_id = [string]$QcTool.expected_evidence_schema_id
            execution_authority_required = [string]$QcTool.execution_authority_required
            command_path = [string]$QcTool.command_path
            fixed_arguments = @(ConvertTo-QcArray -Value $QcTool.fixed_arguments)
            route_status = 'PASS'
        }
    }
}

$QcRequiredControlCount = 0
foreach ($QcContract in @(ConvertTo-QcArray -Value $Qc02.property_contracts)) {
    $QcRequiredControlCount += 1
    $QcRequiredControlCount += @(ConvertTo-QcArray -Value $QcContract.negative_control_ids).Count
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
