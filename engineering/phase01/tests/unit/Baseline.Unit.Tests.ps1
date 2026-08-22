Describe 'ECTOS minimum unit baseline' {
  It 'exposes a valid target directory' { Test-Path -LiteralPath $env:ECTOS_TEST_TARGET -PathType Container | Should -BeTrue }
  It 'materializes empty collections without scalar collapse' { $a=@(); @($a).Count | Should -Be 0 }
  It 'materializes generic lists as collections' { $l=[Collections.Generic.List[string]]::new();$l.Add('x');@($l).Count | Should -Be 1 }
}
