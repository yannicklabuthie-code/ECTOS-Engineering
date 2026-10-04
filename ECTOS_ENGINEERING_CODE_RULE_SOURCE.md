# ECTOS Engineering Code Rule Source

Repository role: **canonical code-rule source**. It is not Factory runtime, project governance authority, Main Authority, cloud configuration, or product runtime.

## Current scope

PowerShell only. First canonical profile: `ECTOS_POWERSHELL_PS51_PROFILE`, targeting native Windows PowerShell Desktop 5.1.

## Current routing

CURRENT_POINTER=`ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json`

CURRENT_VERSIONED_POINTER=`ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V02.json`

CURRENT_ROUTING_METHOD=`governance/code-rule-routing/ECTOS_AGENT_CODE_RULE_CONSUMPTION_AND_ROUTING_METHOD_V02.md`

The stable current selector resolves currentness. Historical predecessor files remain preserved; their embedded status is historical metadata and does not override the stable selector.

## Agent consumption

Agents load the stable current selector first, then the selected versioned pointer. The selected pointer routes the governed profile, profile SHA sidecar, consumption contract, ruleset manifest, ruleset SHA sidecar, workspace identity contract, checkout attributes, and routing method. Profile and ruleset identities are versioned and SHA-bound.

RULESET_VERSION=`V01`

RULESET_SHA256=`2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525`

RULESET_MEMBER_SEMANTICS_CHANGED=`NO`

V01_POINTER_PRESERVED=`YES`

V02 closes routing currentness, identity-source closure, Windows workspace-byte determinism, and integration sequencing without changing the ten active PS51 rule semantics.

## Workspace byte determinism

`.gitattributes` defines fresh-checkout LF policy for the governed rule files and identity sources. Existing-worktree migration is separately governed by `validators/powershell/identity/ECTOS_RULESET_WORKSPACE_IDENTITY_CONTRACT_V01.json`.

A committed blob may be used only as the deterministic repair source for the same path during governed migration. It may not substitute for post-repair workspace evidence. After migration, the workspace bytes themselves must be independently verified against HEAD and must report LF.

## Adding a rule

A defect becomes a rule only when supported by a physical historical source or explicit current governing authority. Add a versioned `PS51-Rxxx` rule, positive/negative fixtures, detection contract, historical source, and regression requirement. Silent mutation or removal is prohibited.

## Versioning and currentness

Rules use explicit versions and `CURRENT|HISTORICAL|SUPERSEDED|PARTIAL|NOT_PROVEN`. Successor selection is governed by the stable current selector. History is preserved.

## Profile identity

Profile `V01` uses canonical-payload SHA256 `4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625`. Its sidecar is `profiles/powershell/ECTOS_POWERSHELL_PS51_PROFILE.sha256`.

## CI and integration

Existing `.github/workflows/ectos-engineering-assurance.yml` provides native PS5.1, PSScriptAnalyzer, Pester, regression, package, hash/provenance, and readiness capabilities. Rule-source successor integration must follow the governed routing method V02: build on a non-main successor branch, qualify the exact changed set, integrate only after gates pass, then re-fetch and verify the current selector and all identity sources from `main`.

## Exact-byte handoff

Rules are constraints; rule reading is not qualification. Generated executable code must be tested physically, and tested bytes must equal handed-off bytes where exact-byte assurance applies.

## Future Factory

Factory may later consume and enforce this repository source. Factory does not become the source of these rules merely by consuming them.
