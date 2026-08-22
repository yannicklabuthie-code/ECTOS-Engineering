param([Parameter(Mandatory)][string]$TargetPackageRoot,[Parameter(Mandatory)][string]$ResultsRoot,[ValidateSet('PS51','PS7')][string]$Runtime)
. (Join-Path $PSScriptRoot 'Common.ps1')
$current=$PSVersionTable.PSVersion
$edition=$PSVersionTable.PSEdition
$ok=if($Runtime -eq 'PS51'){($current.Major -eq 5 -and $current.Minor -eq 1 -and $edition -eq 'Desktop')}else{($current.Major -ge 7)}
$gate=if($Runtime -eq 'PS51'){'NATIVE_PS51'}else{'PS7'}
$status=if($ok){'PASS'}else{'FAIL'}
$r=New-EctosGateResult $gate $status $TargetPackageRoot @{requested=$Runtime;actual_version=$current.ToString();edition=$edition;reason=if($ok){'Native runtime identity confirmed'}else{'Wrong runtime host; gate must execute under requested runtime'}}
Write-EctosGateResult $r $ResultsRoot
if(-not $ok){exit 7}
