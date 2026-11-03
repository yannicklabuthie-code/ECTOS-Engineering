[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ControlId)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'QC.Common.psm1') -Force
if (-not (Test-QcNativeExecutionHost)) { throw 'NATIVE_PS51_ORCHESTRATOR_REQUIRED' }
$lockPath=Join-Path $PSScriptRoot '../../inputs-v48/EXECUTION_DEPENDENCY_LOCK_V48.json'
Assert-QcSha256 $lockPath '519a6f403aba1290f766eedd1081f53c66336445e7a068c99498ff5e1695cfce' | Out-Null
$lock=Import-QcJson $lockPath
if (@($lock.control_ids) -cnotcontains $ControlId) { throw 'UNKNOWN_CONTROL_DENIED' }
foreach($member in @($lock.members)) { Assert-QcSha256 ([string]$member.path) ([string]$member.sha256) | Out-Null }
Assert-QcSha256 ([string]$lock.target_path) ([string]$lock.target_sha256) | Out-Null
$oldPythonPath=$env:PYTHONPATH
$oldNoUser=$env:PYTHONNOUSERSITE
$oldNoBytecode=$env:PYTHONDONTWRITEBYTECODE
try {
 $env:PYTHONPATH=(@($lock.pythonpath) -join ';')
 $env:PYTHONNOUSERSITE='1'
 $env:PYTHONDONTWRITEBYTECODE='1'
 # sitecustomize from the pinned socket_guard disables network connect.
 # A derived V41 runner writes receipts only inside this isolated V48 tree.
 & ([string]$lock.python_path) -u ([string]$lock.runner_path) $ControlId
 $childExit=$LASTEXITCODE
 Assert-QcSha256 ([string]$lock.target_path) ([string]$lock.target_sha256) | Out-Null
 foreach($member in @($lock.members)) { Assert-QcSha256 ([string]$member.path) ([string]$member.sha256) | Out-Null }
} finally {
 $env:PYTHONPATH=$oldPythonPath
 $env:PYTHONNOUSERSITE=$oldNoUser
 $env:PYTHONDONTWRITEBYTECODE=$oldNoBytecode
}
exit $childExit
