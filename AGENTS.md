# ECTOS Engineering Agent Rule Bootstrap

This repository is the canonical source of ECTOS engineering code rules.

## Mandatory PowerShell bootstrap

Any agent, coding assistant, automation, or engineering workflow that creates, edits, reviews, packages, or hands off PowerShell for ECTOS MUST, before code generation:

1. Load `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json` first and resolve its `current_pointer` to the CURRENT versioned pointer.
2. Treat currentness as resolved by that stable selector. Embedded status in predecessor files is historical metadata and does not override the selector.
3. Identify language, target OS, PowerShell edition/runtime family, and the product/container exact-version policy.
4. Select exactly one route from the CURRENT versioned pointer:
   - Windows + Windows PowerShell Desktop 5.1 -> existing PS51 governance.
   - Linux + PowerShell Core/PWSH -> Linux/PWSH governance.
5. Load the selected routing method, consumption contract, governed profile, profile SHA sidecar, ruleset manifest, ruleset SHA sidecar, workspace identity contract, and `.gitattributes`.
6. Load the complete active ruleset and all forbidden patterns, approved patterns, defect families, regression fixtures, runtime compatibility sources, and validation contracts referenced by the selected route.
7. Verify profile identity, ruleset identity, exact member set, and governed workspace byte identity before claiming rule compliance.
8. Never substitute PowerShell Core proof for native Windows PowerShell 5.1 proof, or PS5.1 proof for Linux/PWSH proof.
9. Treat memory and chat instructions alone as insufficient substitutes for repository evidence.

## Linux/PWSH exact-version invariant
The governed Linux/PWSH profile identifies the runtime family. It does not silently pin one product version. Each product/container must separately declare and physically prove its exact `pwsh` version and immutable runtime/image identity before qualification.

## Workspace identity invariant
Required invariant: `GOVERNED_WORKSPACE_RULE_BYTES = COMMITTED_RULE_BLOB_BYTES`.

Fresh checkout policy and existing-worktree migration are distinct. `.gitattributes` defines checkout policy. Governed workspace identity contracts define route-specific exact member sets and hashing.

## Circuit breaker
If two failures occur in the same package, family, or campaign, or the same related root failure repeats, ordinary micro-remediation stops. Defer to project governance for full systemic review and one consolidated defect set before any further execution authority.

## Mandatory post-generation gate
Reading the rules is not qualification. PowerShell intended for execution or owner handoff must pass the post-generation gates required by the selected profile, including native target-runtime proof, regression checks, startability, process/evidence controls and exact-byte handoff assurance where applicable.

`OWNER_FIRST_PARSE`, `OWNER_FIRST_STARTABILITY_TEST`, and `OWNER_FIRST_BASIC_DEFECT_DISCOVERY` are prohibited.

## Source authority boundary
This repository is a code-rule and engineering-assurance source. It is not Factory runtime, project governance authority, Main Authority, Cloud configuration, or product runtime.

## Fail-closed rule
If current routing, required identity sources, currentness, profile, ruleset identity, referenced rule objects, workspace-byte evidence, or route-specific native evidence cannot be loaded and verified, the agent MUST NOT claim rule compliance or owner-handoff readiness.
