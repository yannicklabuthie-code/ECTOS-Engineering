# ECTOS PowerShell Approved Patterns V01

## PS51-R001 — Ambiguous variable reference before colon
Use braced variable interpolation before a literal colon, e.g. `"${Name}:"`.

## PS51-R002 — PowerShell 5.1 inline if used as expression
Assign the conditional result using a statement block before consuming the value.

## PS51-R003 — Unsafe context-sensitive default parameter/path initialization
Resolve context-sensitive paths inside the executable body after parameter binding.

## PS51-R004 — Long path / protected tree path resolution failure
Use explicit error handling, record unreachable paths, and fail closed when complete traversal is required.

## PS51-R005 — Self-referential static scan false positive
Scan only declared product-source roots and exclude rule definitions, detector source, and fixtures unless explicitly testing them.

## PS51-R006 — Automatic/reserved variable collision
Rename user-defined symbols to non-reserved names and validate with AST/static analysis.

## PS51-R007 — Empty collection binding defect
Normalize collection inputs explicitly and test null, empty, single, and many cardinalities.

## PS51-R008 — Generic list binding defect
Normalize to an explicitly supported collection shape at interface boundaries.

## PS51-R009 — Enum argument binding defect
Use explicit enum types/values and validate accepted and rejected values.

## PS51-R010 — String interpolation / regex boundary defect
Use explicit escaping and construct regex fragments with deliberate boundaries.
