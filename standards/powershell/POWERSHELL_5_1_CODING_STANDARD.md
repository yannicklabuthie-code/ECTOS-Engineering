# ECTOS Windows PowerShell 5.1 Coding Standard V01

Target runtime: Windows PowerShell, `PSEdition=Desktop`, version `5.1`.

## Mandatory pre-generation contract
Before generating PowerShell code, identify target PowerShell version and OS, load the current governed profile, active rule set, forbidden patterns, approved patterns, and physically supported historical defect families. Agent memory and chat prompt alone are insufficient.

## Coding requirements
- Prefer explicit, PS5.1-compatible syntax and APIs.
- Treat null, empty, single-item, and many-item collection behavior as separate test cases at interfaces.
- Avoid collisions with automatic/reserved PowerShell variables.
- Isolate path initialization from context-sensitive parameter defaults.
- Fail closed on incomplete required filesystem enumeration.
- Keep static scanning scope separate from detector/rule/fixture sources.
- Preserve deterministic entrypoints, working directories, exit codes, stdout/stderr, timeout behavior, and output identities where applicable.

## Post-generation requirements
Reading the rules does not qualify code. Require static detection, native Windows PowerShell Desktop 5.1 parse, PSScriptAnalyzer, Pester where applicable, regression fixtures, entrypoint startability, package/load checks where applicable, and exact-byte handoff assurance where applicable.

## Exact-byte principle
Owner-first parsing, owner-first startability, and owner-first basic defect discovery are prohibited. Tested bytes must equal handed-off bytes.
