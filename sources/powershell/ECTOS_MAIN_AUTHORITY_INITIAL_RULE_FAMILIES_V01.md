# ECTOS Main Authority — Initial PowerShell Rule Families V01

Authority source materialized from the mission:
`GITHUB POWERSHELL RULES & CODE STANDARDS — CANONICAL ENGINEERING RULE SOURCE — BOOTSTRAP / IMPLEMENTATION AUTHORITY V01`.

Project: ECTOS  
Project container: ECTOS-POC  
Source authority: ECTOS_MAIN_AUTHORITY  
Superior authority: PROJECT_OWNER_YANICK

This source establishes five initial defect families for the canonical PowerShell ruleset:

1. `AMBIGUOUS_VARIABLE_REFERENCE_BEFORE_COLON` — bad example `"$Name:"`; approved form `"${Name}:"`.
2. `PS51_INLINE_IF_AS_EXPRESSION` — Windows PowerShell 5.1 must not use `if` as an inline expression.
3. `PS51_CONTEXT_SENSITIVE_DEFAULT_PARAMETER_PATH` — unsafe default-parameter/path initialization involving context-sensitive variables such as `$PSScriptRoot`.
4. `LONG_PATH_PROTECTED_TREE_RESOLUTION_FAILURE` — long-path/protected-tree enumeration and Win32 path resolution failures require fail-closed handling.
5. `SELF_REFERENTIAL_STATIC_SCAN_FALSE_POSITIVE` — scanners must isolate their own rule/pattern definitions from scanned product source to prevent self-match false positives.

This file preserves the authoritative bootstrap source inside the canonical repository so future agents do not depend on chat memory.
