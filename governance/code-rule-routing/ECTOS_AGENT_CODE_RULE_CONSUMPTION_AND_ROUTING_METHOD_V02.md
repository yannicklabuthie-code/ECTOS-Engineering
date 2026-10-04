# ECTOS Agent Code Rule Consumption and Routing Method V02

## Purpose

Persist the governed Main routing method for ECTOS code-producing missions. This source governs rule-source selection, identity closure, workspace-byte verification, circuit-breaker handoff, and repository integration sequencing. It does not replace project governance authority.

## Canonical source

- Repository: `yannicklabuthie-code/ECTOS-Engineering`
- Branch: `main`
- Bootstrap: `AGENTS.md`
- Stable current selector: `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json`
- Current versioned pointer: `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V02.json`
- PS5.1 consumption contract: `profiles/powershell/ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json`
- PS5.1 profile: `profiles/powershell/ECTOS_POWERSHELL_PS51_PROFILE.json`
- Profile SHA sidecar: `profiles/powershell/ECTOS_POWERSHELL_PS51_PROFILE.sha256`
- Ruleset manifest: `profiles/powershell/ECTOS_POWERSHELL_PS51_RULESET_MANIFEST_V01.json`
- Ruleset SHA sidecar: `rules/powershell/RULESET_V01.sha256`
- Workspace identity contract: `validators/powershell/identity/ECTOS_RULESET_WORKSPACE_IDENTITY_CONTRACT_V01.json`

## Currentness resolution

Currentness is resolved by the stable current selector. The predecessor V01 pointer remains preserved as historical evidence. Its embedded status reflects the state at the time it was issued and does not override the stable selector.

## Main routing trigger

Before Main routes any mission, determine whether the mission may generate, modify, review, package, or hand off code.

If `MISSION_MAY_PRODUCE_CODE=YES`, the code-rule-source gate is mandatory.

If `LANGUAGE=POWERSHELL`, the PowerShell engineering profile load is mandatory before generation or modification.

## Pre-generation sequence

1. Identify language.
2. Identify target operating system.
3. Identify target runtime and exact PowerShell edition/version.
4. Load `AGENTS.md` from the current branch under review.
5. Load `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json`.
6. Resolve the selected versioned pointer and verify repository, branch, scope, and currentness.
7. Load every `required_identity_sources` entry from the selected pointer.
8. For Windows PowerShell Desktop 5.1, verify the profile payload and profile SHA sidecar, consumption contract, ruleset manifest, ruleset SHA sidecar, exact ruleset member set, and workspace identity contract.
9. Load all active rules, forbidden patterns, approved patterns, historical defect families, validation contracts, and regression fixtures referenced by the selected sources.
10. If any required object is absent, stale, contradictory, or not verifiable, block code generation and return the exact unavailable scope.
11. Only after successful rule consumption and identity closure may the agent generate or modify code.

## Workspace byte identity

Fresh checkout and existing-worktree migration are separate cases.

### Fresh checkout

`.gitattributes` defines the LF checkout policy for governed rule members and identity sources.

### Existing worktree

If a governed rule member does not report `w/lf`, or its raw workspace object differs from `HEAD:<path>`, follow the workspace identity contract.

The exact HEAD blob bytes for the same repository-relative path may be used only as a deterministic repair source. They may not be presented as workspace evidence. After repair, independently prove:

- `git ls-files --eol` reports `w/lf` for every rule member.
- `git hash-object --no-filters <workspace-file>` equals `git rev-parse HEAD:<repository-relative-path>` for every member.
- The exact ten-member set still matches `retrieve.rule_set`.
- The declared ruleset SHA remains unchanged.

## Circuit breaker handoff

If two failures occur in the same package, family, or campaign, the same related root failure repeats, or the project time-based circuit breaker triggers, ordinary micro-remediation stops.

Main must defer to project governance for full forensic systemic review, complete dependency and interface analysis, and one consolidated defect set. No new code-generation, execution, qualification, deployment, or commit attempt is authorized until that review closes and Main issues a new exact authority.

## Post-generation sequence

Reading the rules is not qualification. Applicable code must pass the governed engineering assurance path before owner handoff:

1. Static rule and detector checks.
2. Native parse for the declared target runtime.
3. PSScriptAnalyzer where applicable.
4. Pester unit or contract checks where applicable.
5. Regression fixtures.
6. Package and load checks where applicable.
7. Entrypoint startability.
8. Exact-byte identity binding where applicable.
9. Native target evidence and CI provenance where required.
10. Main review and admission before owner handoff.

## Successor construction and repository integration

A systemic correction must be built as one versioned successor on a non-main branch or isolated worktree from a physically proven base commit.

Before commit authority:

1. Prove the complete affected member set and dependencies.
2. Prove protected predecessors remain unchanged unless current governance explicitly requires a versioned successor instead.
3. Run source-quality checks over the complete changed set before the first commit attempt.
4. Validate structured files and routing closure.
5. Prove no governed rule semantic change unless explicitly authorized.
6. Prove workspace-byte identity for all governed rules.
7. Prove objective, architectural intent, invariant preservation, prohibited-behavior absence, and no constraint relocation.

Integration sequence:

1. Create the exact successor commit on the non-main branch.
2. Compare the successor commit with the proven base and verify the exact authorized changed-path set.
3. Run applicable repository or CI qualification on that exact commit.
4. Only after Main acceptance may the successor be integrated to `main`.
5. After integration, re-fetch `main` and independently verify the stable current selector, selected pointer, routing method, profile and sidecar, consumption contract, manifest, ruleset sidecar, identity contract, attributes, and ruleset member identities.
6. Publication to `main` is not itself qualification or release.

## Required pre-code return fields

- `RULE_SOURCE_FOUND`
- `CANONICAL_BRANCH`
- `CURRENT_SELECTOR`
- `CURRENT_VERSIONED_POINTER`
- `PROFILE_VERSION`
- `PROFILE_SHA256`
- `RULESET_VERSION`
- `RULESET_SHA256`
- `RULESET_MEMBER_COUNT`
- `WORKSPACE_IDENTITY_STATE`
- `FORBIDDEN_PATTERN_CATALOG_LOADED`
- `APPROVED_PATTERN_CATALOG_LOADED`
- `DEFECT_FAMILY_CATALOG_LOADED`
- `CURRENTNESS_STATE`

`AGENT_MEMORY_ONLY=INSUFFICIENT`

`CHAT_MEMORY_ONLY=INSUFFICIENT`

## Permanent owner-protection rules

- `OWNER_FIRST_PARSE=PROHIBITED`
- `OWNER_FIRST_STARTABILITY_TEST=PROHIBITED`
- `OWNER_FIRST_BASIC_DEFECT_DISCOVERY=PROHIBITED`
- `TESTED_BYTES_MUST_EQUAL_HANDED_OFF_BYTES=YES_WHERE_APPLICABLE`
- `NATIVE_RUNTIME_NOT_PROVEN=BLOCK_HANDOFF`
- `STARTABILITY_NOT_PROVEN=BLOCK_HANDOFF`
- `KNOWN_BLOCKING_DEFECT_COUNT_GT_0=BLOCK_HANDOFF`

## Future Factory relationship

Current enforcement: `ECTOS_MAIN_AUTHORITY` injects and checks the rule-source gate during routing.

Future Factory role: automatically detect language and runtime, resolve the governed code profile, enforce currentness, and route the correct engineering assurance path.

Factory is a future consumer and enforcer. GitHub remains the code-rule source.

## Scope

Current implemented ruleset scope: PowerShell, with Windows PowerShell Desktop 5.1 as the first canonical profile. Other language profiles may be added later through separately governed, versioned rule sources.
