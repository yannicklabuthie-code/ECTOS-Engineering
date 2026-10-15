# ECTOS Linux / PowerShell Core Coding Standard V01

Target runtime family: Linux + PowerShell Core, executable `pwsh`, `PSEdition=Core`.

## Runtime-family versus product-version rule
This profile governs the PowerShell Core runtime family. It does not pin one product/container `pwsh` version.
Every product or container MUST separately declare and physically prove its exact `pwsh` version and immutable runtime/image identity before qualification.

## Mandatory pre-generation contract
Before generating PowerShell code:
1. identify target OS and runtime family;
2. resolve the stable selector and runtime route;
3. load the Linux/PWSH profile, profile SHA, consumption contract, ruleset manifest, ruleset SHA, workspace identity contract, catalogs, validators and fixtures;
4. prove exact ruleset member identity and currentness.

## Coding requirements
- Do not require `powershell.exe`, `taskkill.exe`, `PSEdition=Desktop`, or Windows PowerShell 5.1 on the Linux/PWSH route.
- Do not use Windows-only production path or process-tree semantics without a separately governed Windows contract.
- Never substitute PWSH proof for PS5.1 proof or PS5.1 proof for PWSH proof.
- Preserve explicit null/empty/single/many collection handling, enum and list binding contracts, regex/interpolation boundaries, context-safe path initialization, complete filesystem enumeration, isolated scan scopes, and automatic-variable safety.
- Preserve deterministic working-directory, stdout, stderr, exit-code, timeout, process-termination, created-output and SHA evidence where applicable.

## Post-generation requirements
Reading the profile is not qualification. Applicable code requires:
NATIVE_LINUX_PWSH_PARSE, PSSCRIPTANALYZER, PSSCRIPTANALYZER_COMPATIBILITY_RULES_WHERE_APPLICABLE, PESTER_WHERE_APPLICABLE, POSITIVE_REGRESSION_FIXTURES, NEGATIVE_REGRESSION_FIXTURES, ENTRYPOINT_STARTABILITY_WHERE_APPLICABLE, STDOUT, STDERR, EXIT_CODE, TIMEOUT, WORKING_DIRECTORY, CREATED_OUTPUT_IDENTITY, and EXACT_BYTE_HANDOFF_WHERE_APPLICABLE.

## Exact-byte principle
Owner-first parsing, owner-first startability and owner-first basic defect discovery are prohibited. Tested bytes must equal handed-off bytes where applicable.
