# ECTOS Engineering Agent Rule Bootstrap

This repository is the canonical source of ECTOS engineering code rules.

## Mandatory PowerShell bootstrap

Any agent, coding assistant, automation, or engineering workflow that creates, edits, reviews, packages, or hands off PowerShell for ECTOS MUST, before code generation:

1. Identify the target OS and PowerShell runtime.
2. For Windows PowerShell Desktop 5.1, load `profiles/powershell/ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json`.
3. Load and verify the current profile `profiles/powershell/ECTOS_POWERSHELL_PS51_PROFILE.json`.
4. Load the complete active ruleset declared by that profile.
5. Load forbidden patterns, approved patterns, historical defect families, and regression fixtures referenced by the contract.
6. Treat agent memory and chat instructions alone as insufficient substitutes for the repository rules.

## Mandatory post-generation gate

Reading the rules is not qualification. PowerShell intended for execution or owner handoff must pass the post-generation gates required by the current profile, including native Windows PowerShell 5.1 proof where applicable, regression checks, startability, and exact-byte handoff assurance where applicable.

`OWNER_FIRST_PARSE`, `OWNER_FIRST_STARTABILITY_TEST`, and `OWNER_FIRST_BASIC_DEFECT_DISCOVERY` are prohibited.

## Source authority boundary

This repository is a code-rule and engineering-assurance source. It is not Factory runtime, project governance authority, Main Authority, Cloud configuration, or product runtime.

Future Factory may consume and enforce this source. It does not replace this source.

## Fail-closed rule

If the required profile, ruleset identity, currentness, or referenced rule objects cannot be loaded and verified, the agent MUST NOT claim rule compliance or owner-handoff readiness. Return the exact unavailable scope instead of inventing or reconstructing rules.
