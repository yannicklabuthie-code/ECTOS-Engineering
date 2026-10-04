# ECTOS Engineering Agent Rule Bootstrap

This repository is the canonical source of ECTOS engineering code rules.

## Mandatory PowerShell bootstrap

Any agent, coding assistant, automation, or engineering workflow that creates, edits, reviews, packages, or hands off PowerShell for ECTOS MUST, before code generation:

1. Load `ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json` first and resolve its `current_pointer` to the CURRENT versioned pointer.
2. Treat currentness as resolved by that stable selector. Embedded status in predecessor files is historical metadata and does not override the selector.
3. Identify target OS and exact PowerShell runtime.
4. For Windows PowerShell Desktop 5.1, load the selected routing method, consumption contract, governed profile, profile SHA sidecar, ruleset manifest, ruleset SHA sidecar, workspace identity contract, and `.gitattributes` referenced by the CURRENT pointer.
5. Load the complete active ruleset and all forbidden patterns, approved patterns, historical defect families, regression fixtures, and validation contracts referenced by the selected sources.
6. Verify profile identity, ruleset identity, exact member set, and governed workspace byte identity before claiming rule compliance.
7. Treat memory and chat instructions alone as insufficient substitutes for repository evidence.

## Workspace identity invariant

Required invariant: `GOVERNED_WORKSPACE_RULE_BYTES = COMMITTED_RULE_BLOB_BYTES`.

Fresh checkout policy and existing-worktree migration are distinct. `.gitattributes` defines checkout policy. If an existing Windows worktree does not satisfy LF byte identity, use only the governed migration procedure from the workspace identity contract. A committed blob may be used as the deterministic repair source for the same path, but never as a substitute for post-repair workspace evidence. After any repair, independently verify workspace LF and raw workspace object identity against HEAD for every rule member.

## Circuit breaker

If two failures occur in the same package, family, or campaign, or the same related root failure repeats, ordinary micro-remediation stops. Defer to project governance for full systemic review and one consolidated defect set before any further execution authority.

## Mandatory post-generation gate

Reading the rules is not qualification. PowerShell intended for execution or owner handoff must pass the post-generation gates required by the current profile, including native Windows PowerShell 5.1 proof where applicable, regression checks, startability, package/load checks where applicable, and exact-byte handoff assurance where applicable.

`OWNER_FIRST_PARSE`, `OWNER_FIRST_STARTABILITY_TEST`, and `OWNER_FIRST_BASIC_DEFECT_DISCOVERY` are prohibited.

## Source authority boundary

This repository is a code-rule and engineering-assurance source. It is not Factory runtime, project governance authority, Main Authority, Cloud configuration, or product runtime.

Future Factory may consume and enforce this source. It does not replace this source.

## Fail-closed rule

If current routing, required identity sources, currentness, profile, ruleset identity, referenced rule objects, or workspace-byte evidence cannot be loaded and verified, the agent MUST NOT claim rule compliance or owner-handoff readiness. Return the exact unavailable scope instead of inventing, reconstructing, or silently substituting evidence.
