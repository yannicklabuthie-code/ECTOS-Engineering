# ECTOS PowerShell Runtime Compatibility V01

`ECTOS_POWERSHELL_PS51_PROFILE` targets Windows PowerShell Desktop 5.1 only.

- PowerShell 7 is not substitute evidence for PS5.1.
- Non-Windows PowerShell is not substitute evidence for native Windows proof.
- Native proof should capture executable, arguments, working directory, start/end, stdout, stderr, exit code, timeout/termination state, created outputs, and SHA256 where applicable.
- A generated artifact that requires native proof is blocked from exact-byte handoff when native PS5.1 proof is absent.
