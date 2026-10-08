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
   - search-before-build tool rule

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
   - 54-tool / 6-profile corpus reconciliation boundary
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
   - 4 of the announced 6 historical profile identities remain NOT_PROVEN
   - no silent equivalence between qualification profile, engine family, engineering profile, tool, qualifier, or Factory admission

## Current evidence state

HISTORICAL_DOCUMENTARY_ROOT_PACKAGE_BASELINE=62
REPOSITORY_SERVICE_ENGINE_INVENTORY=28
RUNTIME_SEMANTIC_OBJECT_SET=13
ALL_13_OBJECTS_HAVE_TOOL_OR_CONTROL_RELATION=YES
DIRECT_STRONG_HISTORICAL_RELATION_COUNT=6
PARTIAL_TARGET_BOUND_RELATION_COUNT=7
NO_RELATION_COUNT=0
REACHABLE_TOOL_RECORD_COUNT=54
QUALIFICATION_PROFILE_COUNT=6
EXACT_NAMED_QUALIFICATION_PROFILE_COUNT=2
EXACT_NAMED_PROFILES=QP-001|QP-WPS51-V01
EXACT_PROFILE_IDENTITIES_REMAINING_NOT_PROVEN=4
CURRENT_TRUSTED_QUALIFIER_COUNT=0
CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0

## Current major unresolved bindings

- complete 62-package historical baseline -> current/running OS relation
- complete package -> engine causal binding
- complete current intra-layer package graph
- complete current cross-layer handoff graph
- exact current input/output contracts for every edge
- four remaining historical qualification-profile identities
- complete exact contracts for all six historical qualification profiles
- complete 54-tool -> profile -> family -> OS target/edge mapping
- current Factory admission by family
- current execution-eligible qualifier by family
- governed qualification-date lineage for full chain
- current active runtime consumption of each recovered object

## Closure condition

ECTOS OS cartography is complete only when every current node and edge is either physically PROVEN or explicitly NOT_PROVEN with exact unreachable scope, and the graph is sufficient to derive assembly qualification and qualification-tool requirements by family without package-name-specific reconstruction.
