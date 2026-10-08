# ECTOS OS — Qualification Profile / Tool Reconciliation V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_CURRENT_CARTOGRAPHY_QUALIFICATION_PROFILE_TOOL_RECONCILIATION
MODE=EVIDENCE_FIRST_READ_ONLY_RECONCILIATION
STATE=PARTIAL_NOT_PROVEN

## Purpose

Bind the current ECTOS OS cartography to qualification-profile and qualification-tool evidence without silently equating historical profile counts, package classes, engine families, or tool names.

This register is documentary only. It does not qualify a tool, admit a tool to Factory, authorize execution, or close any currentness gap.

## Governing distinction

ENGINE_FAMILY != QUALIFICATION_PROFILE != QUALIFICATION_TOOL != QUALIFIER != FACTORY_ADMISSION

A historical PASS, filename, prior use, or profile count does not prove current tool eligibility.

## Current evidence facts

- Recovered tooling corpus reports REACHABLE_TOOL_RECORD_COUNT=54.
- Recovered tooling corpus reports QUALIFICATION_PROFILE_COUNT=6.
- CURRENT_TRUSTED_QUALIFIER_COUNT=0.
- CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0.
- SELECTED_DEV_QUALIFICATION_TOOL_COUNT=4.
- CURRENT_FACTORY_ADMITTED_SELECTED_TOOLS=0.
- A separate supporting DEV package-class coverage return reports PACKAGE_CLASS_COUNT=8 and RUNTIME_PROFILE_COUNT=6.
- That supporting return reports FULLY_COVERED_QUALIFICATION_PROFILE_COUNT=0, PARTIALLY_COVERED_QUALIFICATION_PROFILE_COUNT=2, NO_KNOWN_OR_EXACTLY_BOUND_TOOL_PROFILE_COUNT=4, CURRENT_TRUSTED_PROFILE_COUNT=0, CURRENT_EXECUTION_ELIGIBLE_PROFILE_COUNT=0.

These counts MUST NOT be silently treated as one-to-one with the six candidate engine-family classes defined in ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_MODEL_V01.md.

## Physically named profile identities recovered so far

### QP-WPS51-V01

- Exact name physically recovered from qualification-tool assurance records.
- Scope evidence: Windows PowerShell 5.1 qualification profile / qualifier-precondition rail.
- Current profile trust: NOT_PROVEN for current OS family use.
- Direct mapping to an ECTOS OS engine family: NOT_PROVEN.
- Candidate relationship: relevant to PowerShell-hosted engine families and Windows-native execution, but no family admission is inferred.

### QP-001

- Historical records describe QP-001 as a general qualification profile used across broad Factory / Repository / GitHub assurance / Flutter / Firebase / G00 and L01-L05 qualification contexts.
- Exact current machine-readable profile identity, currentness, and complete contract: NOT_PROVEN in the currently recovered cartography corpus.
- Direct family mapping: NOT_PROVEN.

### ECTOS_POWERSHELL_PS51_PROFILE V01

- Current code-rule / engineering profile physically exists in ECTOS-Engineering and is distinct from a qualification profile unless exact equivalence is proven.
- It MUST NOT be silently substituted for QP-WPS51-V01.

## Candidate engine-family reconciliation matrix

| Engine family | Current family evidence | Qualification profile binding | Existing tool binding | Current admitted tool | State |
|---|---|---|---|---|---|
| QFAM-ROUTING-CONTROL-V01 | G00 DownstreamDispatcher V06; ECTOS.G00.psm1 | Historical targeted G00 QF controls exist; exact reusable profile binding NOT_PROVEN | Historical G00 QF tooling lineage exists | NONE_PROVEN | PARTIAL |
| QFAM-ORCHESTRATION-CONTROL-V01 | Six-layer final operator V04 | Exact family profile NOT_PROVEN | Historical orchestration qualification controls exist; exact reusable tool identity/currentness NOT_PROVEN | NONE_PROVEN | PARTIAL |
| QFAM-RUNTIME-FACADE-V01 | L01-L05 facades | Shared QF / Pre-QF evidence exists; exact family profile ID NOT_PROVEN | Historical layer controls exist; reusable generic tool binding NOT_PROVEN | NONE_PROVEN | PARTIAL |
| QFAM-CORE-COMPONENT-ENGINE-V01 | Taxonomy, Classification, WPDF, BusinessRequestHandler, IDBank | Exact family profile NOT_PROVEN | Tool-to-object lineage remains partial for several engines | NONE_PROVEN | PARTIAL |
| QFAM-CROSS-LAYER-HANDOFF-V01 | Derived from G00→L01→L02→L03→L04→L05 assembly boundaries | No exact current profile identity recovered | No current admitted generic handoff qualifier proven | NONE_PROVEN | NOT_PROVEN |
| QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01 | Cloud Run/runtime carrier evidence | Windows/host/materialization qualification evidence exists in other rails; exact OS-family profile binding NOT_PROVEN | No current admitted generic materialization qualifier proven for this family | NONE_PROVEN | PARTIAL |

## Search-before-build decision rule

For every mapped family:

1. Recover exact historical profile IDs and contracts.
2. Recover exact tool IDs, versions, SHA256, source path, target object, result, qualifier, qualification evidence, and currentness.
3. Compare capability coverage against the family challenge set.
4. Classify each tool as REUSE_CANDIDATE, EXTEND_CANDIDATE, BUILD_NEW_REQUIRED, or NOT_PROVEN.
5. Do not promote any tool from candidate to admitted without independent tool qualification and governed Factory admission.

## Reuse classification schema

REUSE_CANDIDATE requires:
- exact tool identity;
- exact current source;
- current runtime compatibility;
- family-profile coverage;
- negative controls;
- independent tool qualification evidence;
- Factory admission evidence.

EXTEND_CANDIDATE requires:
- proven base tool identity and coverage;
- explicit missing capability set;
- systemic change-impact analysis;
- new independent tool qualification after extension.

BUILD_NEW_REQUIRED requires:
- family contract sufficiently proven;
- no admitted current tool satisfies it;
- challenge set and negative controls derivable without guesswork.

NOT_PROVEN applies whenever any required identity/currentness/profile/tool binding remains unresolved.

## Current reconciliation outcome

ENGINE_FAMILY_COUNT_CANDIDATE=6
HISTORICAL_QUALIFICATION_PROFILE_COUNT_REPORTED=6
EXACT_PROFILE_IDENTITIES_FULLY_RECOVERED=NO
ONE_TO_ONE_FAMILY_PROFILE_MAPPING=NOT_PROVEN
REACHABLE_TOOL_RECORD_COUNT_REPORTED=54
CURRENT_TRUSTED_QUALIFIER_COUNT=0
CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0
CURRENT_FACTORY_ADMITTED_TOOL_BY_FAMILY=0_PROVEN

## Next recovery scope

- recover the exact six historical qualification-profile identities and their contracts;
- reconcile the 54-tool corpus to those profile identities;
- bind tools to OS engine/object targets and assembly edges;
- identify the exact capability delta for each of the six candidate engine families;
- preserve unresolved mappings as NOT_PROVEN;
- use the resulting family/tool matrix as input to ECTOS DEV qualification-tool planning.

## Closure rule

This reconciliation remains PARTIAL until exact profile identities, tool identities, profile-to-family bindings, tool-to-target bindings, currentness, independent tool qualification, and Factory admission are either physically proven or explicitly closed as NOT_PROVEN with exact unreachable scope.
