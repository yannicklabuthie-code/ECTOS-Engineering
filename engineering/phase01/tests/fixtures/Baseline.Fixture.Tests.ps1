Describe 'ECTOS negative fixture reachability baseline' {
  It 'detects zero-row CSV separately from header presence' {
    $p=Join-Path $TestDrive 'header.csv';'A,B'|Set-Content $p; $rows=@(Import-Csv $p); $rows.Count | Should -Be 0
  }
  It 'detects duplicate logical ZIP member names in a modeled member list' {
    $m=@('a/b.txt','a/b.txt');(@($m|Group-Object|Where-Object Count -gt 1)).Count | Should -Be 1
  }
}
