# ECTOS Agent Code Rule Consumption and Routing Method V01

## Purpose

Persist the mandatory Main routing method for ECTOS agents that generate, modify, review, package, or hand off PowerShell code. This file is a governed engineering-method source. It is not Factory runtime and does not replace project governance authority.

## Canonical source

- Repository: `yannicklabuthie-code/ECTOS-Engineering`
- Branch: `main`
- Bootstrap: `AGENTS.md`
- Rule pointer: `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V01.json`
- PS5.1 consumption contract: `profiles/powershell/ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json`
- PS5.1 profile: `profiles/powershell/ECTOS_POWERSHELL_PS51_PROFILE.json`

## Main routing trigger

Before Main routes any mission, determine whether the mission may generate, modify, review, package, or hand off code.

If `MISSION_MAY_PRODUCE_CODE=YES`, a code-rule-source gate is mandatory.

If `LANGUAGE=POWERSHELL`, the PowerShell engineering profile load is mandatory before generation.

## Pre-generation sequence

1. Identify language.
2. Identify target operating system.
3. Identify target runtime and exact PowerShell edition/version.
4. Load `AGENTS.md` from `main`.
5. Load `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V01.json`.
6. For Windows PowerShell Desktop 5.1, load `profiles/powershell/ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json`.
7. Load the current PS5.1 profile and verify profile version/SHA256 and ruleset version/SHA256.
8. Load all active rules, forbidden patterns, approved patterns, historical defect families, and required regression fixtures referenced by the current contract/profile.
9. If any required object is absent, stale, contradictory, or not verifiable, block code generation and return the exact unavailable scope.
10. Only after successful rule consumption may the agent generate or modify code.

## Required pre-code return fields

- `RULE_SOURCE_FOUND`
- `CANONICAL_BRANCH`
- `PROFILE_VERSION`
- `PROFILE_SHA256`
- `RULESET_VERSION`
- `RULESET_SHA256`
- `FORBIDDEN_PATTERN_CATALOG_LOADED`
- `APPROVED_PATTERN_CATALOG_LOADED`
- `DEFECT_FAMILY_CATALOG_LOADED`
- `CURRENTNESS_STATE`

`AGENT_MEMORY_ONLY=INSUFFICIENT`

`CHAT_MEMORY_ONLY=INSUFFICIENT`

## Post-generation sequence

Reading the rules is not qualification. After generation/modification, applicable code must pass the governed engineering assurance path before owner handoff:

1. Static rule/detector checks.
2. Native parse for the declared target runtime.
3. PSScriptAnalyzer where applicable.
4. Pester unit/contract checks where applicable.
5. Regression fixtures.
6. Package/load checks where applicable.
7. Entrypoint startability.
8. Exact-byte identity binding where applicable.
9. Native target evidence and CI provenance where required.
10. Main review/admission before owner handoff.

## Permanent owner-protection rules

- `OWNER_FIRST_PARSE=PROHIBITED`
- `OWNER_FIRST_STARTABILITY_TEST=PROHIBITED`
- `OWNER_FIRST_BASIC_DEFECT_DISCOVERY=PROHIBITED`
- `TESTED_BYTES_MUST_EQUAL_HANDED_OFF_BYTES=YES_WHERE_APPLICABLE`
- `NATIVE_RUNTIME_NOT_PROVEN=BLOCK_HANDOFF`
- `STARTABILITY_NOT_PROVEN=BLOCK_HANDOFF`
- `KNOWN_BLOCKING_DEFECT_COUNT_GT_0=BLOCK_HANDOFF`

## Existing-agent application rule

Do not interrupt an existing agent that is performing a non-code mission.

For an existing agent already engaged in code work, bind this method at the first safe continuation point before any new code generation, modification, review, packaging, or handoff.

For every new code-producing mission routed by Main, inject this requirement at mission entry before build authorization.

## Future Factory relationship

Current enforcement: `ECTOS_MAIN_AUTHORITY` injects and checks the rule-source gate during routing.

Future Factory role: automatically detect language/runtime, resolve the governed code profile, enforce currentness, and route the correct engineering assurance path.

Factory is a future consumer/enforcer. GitHub remains the code-rule source.

## Scope

Current implemented ruleset scope: PowerShell, with Windows PowerShell Desktop 5.1 as the first canonical profile.

Other language profiles may be added later through separately governed, versioned rule sources.
