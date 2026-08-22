Describe 'ECTOS package contract baseline' {
  It 'requires a package manifest' { Test-Path -LiteralPath (Join-Path $env:ECTOS_TEST_TARGET 'ectos-package-manifest.json') | Should -BeTrue }
  It 'requires exactly one manifest at package root' { @(Get-ChildItem -LiteralPath $env:ECTOS_TEST_TARGET -File -Filter 'ectos-package-manifest.json').Count | Should -Be 1 }
}
