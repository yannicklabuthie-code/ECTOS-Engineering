# ECTOS Engineering Code Rule Source

Repository role: **canonical code-rule source**. It is not Factory runtime, project governance authority, Main Authority, cloud configuration, or product runtime.

## Current scope
PowerShell only. First canonical profile: `ECTOS_POWERSHELL_PS51_PROFILE`, targeting native Windows PowerShell Desktop 5.1.

## Agent consumption
Agents select language, target runtime, and engineering profile, then load `profiles/powershell/ECTOS_AGENT_CONSUMPTION_CONTRACT_V01.json`. Profile and ruleset identities are versioned and SHA-bound.

## Adding a rule
A defect becomes a rule only when supported by a physical historical source or explicit current governing authority. Add a versioned `PS51-Rxxx` rule, positive/negative fixtures, detection contract, historical source, and regression requirement. Silent mutation/removal is prohibited.

## Versioning and currentness
Rules use explicit versions and `CURRENT|HISTORICAL|SUPERSEDED|PARTIAL|NOT_PROVEN`. Supersession requires an explicit successor/pointer; history is preserved. The active ruleset version is `V01`, SHA256 `2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525`.

## Profile identity
Profile `V01` uses canonical-payload SHA256 `4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625`. The hash scope is declared in the profile to avoid self-referential hashing.

## CI integration
Existing `.github/workflows/ectos-engineering-assurance.yml` already provides native PS5.1, PSScriptAnalyzer, Pester, regression, package, hash/provenance and readiness capabilities. This V01 rule-source change does not modify that workflow. Future integration should add a pre-generation/static rule-consumption gate without racing QP-001 exact-byte work.

## Exact-byte handoff
Rules are constraints; rule reading is not qualification. Generated executable code must be tested physically, and tested bytes must equal handed-off bytes where exact-byte assurance applies.

## Future Factory
Factory may later consume and enforce this repository source. Factory does not become the source of these rules merely by consuming them.
