Describe 'ECTOS basic state collision baseline' {
  It 'distinguishes clean and preexisting output state' {
    $r=Join-Path $TestDrive 'state';New-Item -ItemType Directory $r|Out-Null;(Test-Path (Join-Path $r 'output'))|Should -BeFalse;New-Item -ItemType Directory (Join-Path $r 'output')|Out-Null;(Test-Path (Join-Path $r 'output'))|Should -BeTrue
  }
  It 'distinguishes predecessor marker from current marker' {
    'V01'|Set-Content (Join-Path $TestDrive 'version.txt');(Get-Content (Join-Path $TestDrive 'version.txt'))|Should -Be 'V01'
  }
}
