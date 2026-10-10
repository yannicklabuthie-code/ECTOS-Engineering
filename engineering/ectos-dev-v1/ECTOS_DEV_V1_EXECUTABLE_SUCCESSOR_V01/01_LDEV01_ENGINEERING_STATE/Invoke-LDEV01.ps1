Set-StrictMode -Version Latest
function Invoke-ECTOSLDEV01 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if ($null -eq $Target) { throw 'LDEV01_TARGET_NULL' }
    foreach ($name in @('target_id','source_root','dependencies')) {
        if (-not ($Target.PSObject.Properties.Name -contains $name)) { throw ('LDEV01_TARGET_FIELD_MISSING:' + $name) }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Target.target_id)) { throw 'LDEV01_TARGET_ID_EMPTY' }
    if ([string]::IsNullOrWhiteSpace([string]$Target.source_root)) { throw 'LDEV01_SOURCE_ROOT_EMPTY' }
    $sourceRoot = Join-Path $RepositoryRoot ([string]$Target.source_root)
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw ('LDEV01_SOURCE_ROOT_NOT_FOUND:' + $sourceRoot) }
    $resolvedDependencies = @()
    foreach ($dependency in @($Target.dependencies)) {
        if ([string]::IsNullOrWhiteSpace([string]$dependency)) { throw 'LDEV01_DEPENDENCY_EMPTY' }
        $dependencyPath = Join-Path $RepositoryRoot ([string]$dependency)
        if (-not (Test-Path -LiteralPath $dependencyPath)) { throw ('LDEV01_DEPENDENCY_NOT_FOUND:' + $dependency) }
        $resolvedDependencies += [string]$dependency
    }
    [pscustomobject][ordered]@{
        schema_id='ECTOS_LDEV01_ENGINEERING_STATE_RESULT_V01'; status='PASS'; target_id=[string]$Target.target_id
        source_root=$sourceRoot; dependency_count=@($resolvedDependencies).Count; dependencies=@($resolvedDependencies)
    }
}
