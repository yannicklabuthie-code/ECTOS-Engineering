# ECTOS Linux / PowerShell Core Runtime Compatibility V01

This governed profile targets the runtime family `LINUX + POWERSHELL_CORE_PWSH` with executable `pwsh` and `PSEdition=Core`.

## Exact version policy
The code-rule profile does not pin a specific product/container PowerShell version.
Every product/container MUST pin and record:
- exact `pwsh` semantic version;
- `PSEdition`;
- OS/platform identity;
- executable identity;
- immutable container/runtime image identity and digest where containerized.

A product is not qualified merely because it uses the same runtime family.

## Cross-runtime evidence boundary
- PowerShell Core proof is not native Windows PowerShell 5.1 proof.
- Windows PowerShell 5.1 proof is not Linux/PWSH proof.
- Silent cross-runtime proof substitution is prohibited.

## PS51-R002 classification evidence
Main physically observed on `mcr.microsoft.com/powershell:7.4-ubuntu-22.04`:
`INLINE_IF_RESULT=A`, `PS_VERSION=7.4.6`, `PS_EDITION=Core`, `PLATFORM=Unix`.
This evidence establishes only that PS51-R002 is not applicable to this PWSH classification path; it does not pin 7.4.6 as the governed product runtime version.
