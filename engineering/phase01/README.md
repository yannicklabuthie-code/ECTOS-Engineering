# ECTOS DEV Engineering Environment — Minimum Control Implementation V01

Scope: Phase 0 + Phase 1 only. This package is isolated from Factory V08, Core, G00/L01-L05, and all currently qualified packages.

## Primary entry point

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1 -TargetPackageRoot C:\path\to\candidate
```

For a component claiming PowerShell 7 compatibility, run once under Windows PowerShell 5.1 and once under `pwsh`.

The runner is fail-closed. Missing mandatory tools, missing/invalid manifest, failed tests, failed install/load, or hash failure produce non-ready machine states.

## Optional local tool bootstrap

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Initialize-ECTOSEngineeringTools.ps1 -InstallMissing
```

This saves PSScriptAnalyzer and Pester into this engineering environment's local `tools/modules` directory. It does not modify ECTOS runtime packages.

## Readiness

`DEV_READY` and `PACKAGE_READY` are derived only by `gates/Get-ECTOSReadiness.ps1` from normalized result files.

## Native matrix example

Use the same `ResultsRoot` for both native hosts so evidence accumulates without overwriting the other runtime:

```powershell
$R = Join-Path $PWD 'results\candidate_001'
powershell.exe -NoProfile -File .\RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1 -TargetPackageRoot C:\candidate -ResultsRoot $R -ClaimPS7Compatibility
pwsh.exe       -NoProfile -File .\RUN_ECTOS_DEV_MINIMUM_CONTROL.ps1 -TargetPackageRoot C:\candidate -ResultsRoot $R -ClaimPS7Compatibility
```


## V04 successor note
V04 corrects native selfqual argument binding and derives PS7 blocking requirements from the target package manifest. V01 bytes remain immutable.


V04 fixes orchestration argument binding and contains per-gate process exits so the full gate line executes before readiness derivation.


## V04 successor correction

- Hardened PARSE gate for Windows PowerShell 5.1.
- Every launched gate now yields a machine result; missing child output is synthesized as fail-closed `GATE_RESULT_NOT_PRODUCED` with log evidence.
- Existing passed gate logic is otherwise unchanged.
