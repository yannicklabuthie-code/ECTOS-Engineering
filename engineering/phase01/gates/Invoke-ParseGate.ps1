[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$TargetPackageRoot,
  [Parameter(Mandatory=$true)][string]$ResultsRoot
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$parseErrorList = @()
$files = @(Get-ChildItem -LiteralPath $TargetPackageRoot -Recurse -File -Filter '*.ps1' -ErrorAction Stop)
foreach($f in $files){
  $tokens = $null
  $fileParseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $f.FullName,
    [ref]$tokens,
    [ref]$fileParseErrors
  )
  foreach($pe in @($fileParseErrors)){
    if($null -ne $pe){
      $parseErrorList += ('{0}:{1}:{2}' -f $f.FullName,$pe.Extent.StartLineNumber,$pe.Message)
    }
  }
}
$status = if(@($parseErrorList).Count -eq 0){'PASS'}else{'FAIL'}
$r = New-EctosGateResult 'PARSE' $status $TargetPackageRoot @{
  file_count=@($files).Count
  error_count=@($parseErrorList).Count
  errors=@($parseErrorList)
  powershell_version=$PSVersionTable.PSVersion.ToString()
  ps_edition=$PSVersionTable.PSEdition
}
Write-EctosGateResult $r $ResultsRoot | Out-Null
if($status -eq 'FAIL'){exit 2}
exit 0
