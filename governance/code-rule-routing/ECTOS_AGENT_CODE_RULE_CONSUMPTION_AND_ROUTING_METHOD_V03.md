# ECTOS Agent Code Rule Consumption and Routing Method V03

## Purpose
Versioned successor to V02 adding a separately governed Linux / PowerShell Core (`pwsh`) route without weakening or superseding the Windows PowerShell Desktop 5.1 route.

## Canonical source
- Repository: `yannicklabuthie-code/ECTOS-Engineering`
- Authorized engineering branch for this successor: `ectos/pwsh-linux-profile-v01`
- Bootstrap: `AGENTS.md`
- Stable selector: `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json`
- Current versioned pointer: `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V03.json`

## Runtime routing
Route by language + OS + runtime family.

### Windows PowerShell Desktop 5.1
Use the existing unchanged PS51 profile, V01 consumption contract, V01 ruleset manifest, V01 ruleset SHA and V01 workspace identity contract.

### Linux + PowerShell Core / PWSH
Use the new PWSH profile, sidecar, consumption contract, ruleset manifest, ruleset SHA and workspace identity contract referenced by V03.

## Exact-version policy
The PWSH governance profile identifies a runtime family, not one product runtime version. Every product/container must separately pin and physically prove its exact `pwsh` version plus immutable runtime/image identity before qualification. The 7.4.6 evidence used to classify PS51-R002 does not create a 7.4.6 product pin.

## PS51-R002 boundary
PS51-R002 remains a PS5.1-specific rule. Main physically established that PowerShell Core 7.4.6 on Linux accepts an `if` statement as a value-producing expression. No PWSH successor rule is created for PS51-R002 absent separately proven PWSH defect evidence.

## Pre-generation sequence
1. Identify language, target OS, runtime family and exact product-version policy.
2. Resolve the stable selector and V03 pointer.
3. Select exactly one runtime route.
4. Load every identity source for that route.
5. Load the complete active ruleset, catalogs, validators and fixtures.
6. Verify profile SHA, ruleset SHA, exact member set and workspace byte identity.
7. Fail closed if any required identity or reference is unavailable.
8. Only then may generation/modification proceed.

## Post-generation sequence
Applicable code must pass the route-specific static, native runtime, PSScriptAnalyzer, regression, startability, process/evidence and exact-byte gates. Cross-runtime proof substitution is prohibited.

## Invariants
- PS51 governance remains unchanged and independently routable.
- PWSH proof is not PS5.1 proof.
- PS5.1 proof is not PWSH proof.
- Owner-first parse/startability/basic defect discovery remain prohibited.
- Factory is a consumer/enforcer; GitHub remains the rule source.
