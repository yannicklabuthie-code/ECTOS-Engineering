# ECTOS OS — Cartography Index V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_CURRENT_CARTOGRAPHY_INDEX
STATE=PARTIAL_NOT_PROVEN

## Canonical working branch

BRANCH=cartography/ectos-os-current-assembly-v01

This index points to the current evidence-first cartography working set. Presence in this index does not promote any PARTIAL or NOT_PROVEN state.

## Current working registers

1. `ECTOS_OS_CURRENT_CARTOGRAPHY_V01.md`
   - top-level current cartography register
   - recovered package/runtime populations
   - 13 runtime/semantic objects
   - proven package anchors
   - assembly and qualification invariants
   - exact open gaps

2. `ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_MODEL_V01.md`
   - candidate engine-family qualification taxonomy
   - family-level qualification challenge model
   - search-before-build rule constrained to proven successful assets

3. `ECTOS_OS_ENGINE_FAMILY_ASSIGNMENT_REGISTER_V01.md`
   - assignment of recovered OS objects to candidate qualification families

4. `ECTOS_OS_ASSEMBLY_QUALIFICATION_MATRIX_V01.md`
   - L1 component qualification
   - L2 interface/dependency qualification
   - L3 layer assembly qualification
   - L4 cross-layer boundary qualification
   - L5 full-system end-to-end qualification

5. `ECTOS_OS_QUALIFICATION_PROFILE_TOOL_RECONCILIATION_V01.md`
   - historical qualification-profile identities recovered so far
   - 54-record corpus retained as archival/discovery evidence only
   - profile-vs-family anti-conflation rules

6. `ECTOS_OS_TOOL_TO_ENGINE_FAMILY_BINDING_V01.md`
   - all 13 recovered runtime/semantic objects linked to at least one historical qualification/control relation
   - 6 DIRECT_STRONG_HISTORICAL relations
   - 7 PARTIAL_TARGET_BOUND relations
   - 0 NO_RELATION
   - current Factory admission / trust / execution eligibility remains NOT_PROVEN

7. `ECTOS_OS_QUALIFICATION_PROFILE_IDENTITY_RECOVERY_V01.md`
   - exact profile-name recovery state
   - QP-001 source-backed as a broad historical cross-domain profile
   - QP-WPS51-V01 source-backed as a Windows PowerShell 5.1 qualification profile
   - QP-WPS51 source-backed static/native/negative gate classes recorded
   - 4 of the announced 6 historical profile identities remain exact unreachable scope from the current reachable source graph
   - profile identity recovery ends BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE rather than inventing names
   - complete 54-tool re-check/requalification is explicitly NOT required

8. `ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_REQUIREMENTS_V01.md`
   - candidate family-level qualification requirements for routing, orchestration, runtime façades, core component engines, cross-layer handoffs and runtime/materialization
   - separates generic family gates from runtime-specific overlays such as QP-WPS51-V01
   - defines required negative-control families and assembly requirements
   - active tool-selection policy starts from proven successful qualification/control assets only
   - new/adapted family qualifier is built only when proven successful assets do not cover the family requirement

9. `ECTOS_OS_PROVEN_QUALIFICATION_ASSET_TO_FAMILY_MATRIX_V01.md`
   - active SMALL shortlist, not the 54-record discovery corpus
   - separates operational actors from executable qualification instruments
   - source-backed operational actors include Tooling Registry & Qualification Mapping Agent, Engineering Assurance PRÊT and Assurance Layer
   - successful recovered qualification controls include G00 V06 targeted QF, Complete Six Layer Core Formal Final Core QF V01 and G00/L01 Formal QF Control V06
   - family outcome is REUSE / ADAPT / BUILD_NEW / NOT_PROVEN
   - DevCal remains owner-designated possible use but successful OS qualification role is NOT_PROVEN from current reachable evidence

10. `ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_DECISION_REGISTER_V01.md`
   - freezes the current per-family qualification-tool route from proven successful OS assets only
   - QFAM-ROUTING-CONTROL-V01=ADAPT
   - QFAM-ORCHESTRATION-CONTROL-V01=ADAPT
   - QFAM-RUNTIME-FACADE-V01=ADAPT
   - QFAM-CORE-COMPONENT-ENGINE-V01=BUILD_NEW
   - QFAM-CROSS-LAYER-HANDOFF-V01=BUILD_NEW
   - QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01=BUILD_NEW
   - REUSE_AS_IS_COUNT=0, ADAPT_COUNT=3, BUILD_NEW_COUNT=3
   - BUILD_NEW is documentary requirement only; no code/tool execution authority is granted

## Current evidence state

HISTORICAL_DOCUMENTARY_ROOT_PACKAGE_BASELINE=62
REPOSITORY_SERVICE_ENGINE_INVENTORY=28
RUNTIME_SEMANTIC_OBJECT_SET=13
ALL_13_OBJECTS_HAVE_TOOL_OR_CONTROL_RELATION=YES
DIRECT_STRONG_HISTORICAL_RELATION_COUNT=6
PARTIAL_TARGET_BOUND_RELATION_COUNT=7
NO_RELATION_COUNT=0
REACHABLE_TOOL_RECORD_COUNT=54
REACHABLE_TOOL_RECORD_COUNT_ROLE=ARCHIVAL_DISCOVERY_ONLY
ACTIVE_54_TOOL_RECHECK_REQUIRED=NO
ACTIVE_54_TOOL_REQUALIFICATION_REQUIRED=NO
QUALIFICATION_PROFILE_COUNT=6
EXACT_NAMED_QUALIFICATION_PROFILE_COUNT=2
EXACT_NAMED_PROFILES=QP-001|QP-WPS51-V01
EXACT_PROFILE_IDENTITIES_REMAINING_NOT_PROVEN=4
PROFILE_IDENTITY_SAFE_READ_ONLY_SEARCH_EXHAUSTED=YES
CURRENT_TRUSTED_QUALIFIER_COUNT=0
CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0
ENGINE_FAMILY_QUALIFICATION_REQUIREMENTS_CANDIDATE=CREATED
PROVEN_SUCCESSFUL_QUALIFICATION_ASSET_SHORTLIST=CREATED
ENGINE_FAMILY_QUALIFICATION_DECISION_REGISTER=CREATED
ENGINE_FAMILY_DECISION_ADAPT_COUNT=3
ENGINE_FAMILY_DECISION_BUILD_NEW_COUNT=3
ENGINE_FAMILY_DECISION_REUSE_AS_IS_COUNT=0

## Current major unresolved bindings

- complete 62-package historical baseline -> current/running OS relation
- complete package -> engine causal binding
- complete current intra-layer package graph
- complete current cross-layer handoff graph
- exact current input/output contracts for every edge
- four remaining historical qualification-profile identities: exact unreachable scope from current reachable sources
- complete exact contracts for all six historical qualification profiles
- exact adapted/new qualifier contracts for each engine family
- current Factory admission by family
- current execution-eligible qualifier by family
- governed qualification-date lineage for full chain
- current active runtime consumption of each recovered object

## Immediate next cartography target

NEXT_TARGET=FREEZE_PER_FAMILY_QUALIFIER_CONTRACTS_AND_BIND_TO_CURRENT_OS_NODES_AND_EDGES

For each family, freeze:

- FAMILY_ID
- QUALIFIER_MODE=ADAPT|BUILD_NEW
- BASE_PROVEN_ASSET if any
- REQUIRED_GATES
- REQUIRED_NEGATIVE_CONTROLS
- RUNTIME_OVERLAY
- TARGET_NODE_OR_EDGE_SET
- INPUT_EVIDENCE_CONTRACT
- OUTPUT_QUALIFICATION_RECEIPT_CONTRACT
- INDEPENDENT_QUALIFIER_ROUTE
- FACTORY_ADMISSION_REQUIRED=YES

The four unrecovered historical profile IDs and archival 54-record corpus remain preserved evidence/history and do not create an active requalification workload.

## Closure condition

ECTOS OS cartography is complete only when every current node and edge is either physically PROVEN or explicitly NOT_PROVEN with exact unreachable scope, and the graph is sufficient to derive assembly qualification and qualification-tool requirements by family without package-name-specific reconstruction.