# ECTOS Linux / PowerShell Core Approved Patterns V01

Target: Linux + PowerShell Core (`pwsh`, `PSEdition=Core`).

## PWSH-R001 — Ambiguous variable reference before colon
Use braced variable interpolation before a literal colon, e.g. "${Name}:".

## PWSH-R002 — Unsafe context-sensitive default parameter/path initialization
Resolve context-sensitive paths inside the executable body after parameter binding.

## PWSH-R003 — Incomplete required filesystem enumeration
Use explicit error handling, record unreachable paths, and fail closed when complete traversal is required.

## PWSH-R004 — Self-referential static scan false positive
Scan only declared product-source roots and exclude rule definitions, detector source, and fixtures unless explicitly testing them.

## PWSH-R005 — Automatic/reserved variable collision
Rename user-defined symbols to non-reserved names and validate with AST/static analysis.

## PWSH-R006 — Null/empty/single/many collection boundary defect
Normalize collection inputs explicitly and test null, empty, single, and many cardinalities.

## PWSH-R007 — Generic list binding defect
Normalize to an explicitly supported collection shape at interface boundaries.

## PWSH-R008 — Enum argument binding defect
Use explicit enum types/values and validate accepted and rejected values.

## PWSH-R009 — String interpolation / regex boundary defect
Use explicit escaping and construct regex fragments with deliberate boundaries.

## PWSH-R010 — Windows PowerShell executable dependency in Linux/PWSH product code
Invoke the governed PowerShell Core executable/runtime abstraction; keep Windows execution behind an explicit separate Windows contract.

## PWSH-R011 — Windows taskkill process termination dependency
Use a governed Linux process-group/cgroup/container termination mechanism and prove descendant termination.

## PWSH-R012 — Desktop edition requirement in Linux/PWSH product code
Require PSEdition=Core for the Linux/PWSH route where an edition check is needed.

## PWSH-R013 — Exact Windows PowerShell 5.1 requirement in Linux/PWSH product code
Bind the product to the Linux/PWSH runtime family and separately pin the exact product/container pwsh version.

## PWSH-R014 — Windows-only production path semantics
Use platform-neutral path APIs and prove Linux path behavior in the native target environment.

## PWSH-R015 — Windows-only process-tree termination semantics
Use a governed Linux termination domain and prove that no descendants survive timeout termination.

## PWSH-R016 — Silent substitution of PS5.1 proof with pwsh proof
Keep runtime-family evidence separate and bind every proof to the exact target OS, edition, executable, and version.
