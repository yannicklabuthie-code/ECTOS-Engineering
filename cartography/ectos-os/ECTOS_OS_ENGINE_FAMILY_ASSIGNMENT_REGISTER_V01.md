# ECTOS OS — Engine Family Assignment Register V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_CURRENT_CARTOGRAPHY
MODE=EVIDENCE_FIRST_DOCUMENTARY_BINDING
STATE=PARTIAL_NOT_PROVEN

## Purpose

Bind each currently recovered ECTOS OS runtime/semantic object to an evidence-backed qualification family candidate without silently promoting historical qualification into current qualification.

This register is derived from the recovered 13-object runtime lineage and the Engine Family Qualification Model V01.

## Family IDs

| Family ID | Object role | Profile state |
|---|---|---|
| QFAM-ROUTING-CONTROL-V01 | route selection / dispatch / control routing | PROFILE_CANDIDATE_NOT_YET_VERSIONED_AS_EXECUTABLE_PROFILE |
| QFAM-ORCHESTRATION-CONTROL-V01 | ordered whole-chain orchestration / completion | PROFILE_CANDIDATE_NOT_YET_VERSIONED_AS_EXECUTABLE_PROFILE |
| QFAM-RUNTIME-FACADE-V01 | layer facade / inbound-outbound boundary | PROFILE_CANDIDATE_NOT_YET_VERSIONED_AS_EXECUTABLE_PROFILE |
| QFAM-CORE-COMPONENT-ENGINE-V01 | functional component engine behind a facade | PROFILE_CANDIDATE_NOT_YET_VERSIONED_AS_EXECUTABLE_PROFILE |
| QFAM-CROSS-LAYER-HANDOFF-V01 | edge family for layer-to-layer handoff | EDGE_PROFILE_CANDIDATE |
| QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01 | carrier/materialization/host/runtime binding | SYSTEM_PROFILE_CANDIDATE |

## Recovered object assignments

| # | Object | Recovered class | Family assignment | Historical layer/binding evidence | Current family binding state |
|---|---|---|---|---|---|
| 01 | ECTOS.G00.DownstreamDispatcher.Candidate.V06 | ROUTING_CONTROL_MODULE | QFAM-ROUTING-CONTROL-V01 | strongest direct G00 V06 targeted qualification lineage recovered; final six-layer chain records G00 PASS | EVIDENCE_BACKED_CANDIDATE |
| 02 | ECTOS.COMPLETE_SIX_LAYER_CORE.FINAL_OPERATOR.OPTION_B_ORCHESTRATION.V04 | ORCHESTRATION_CONTROL | QFAM-ORCHESTRATION-CONTROL-V01 | final accepted six-layer execution; V04 selfqual historical PASS | EVIDENCE_BACKED_CANDIDATE |
| 03 | ECTOS.G00.psm1 | ROUTING_CONTROL_MODULE | QFAM-ROUTING-CONTROL-V01 | governed G00 source/baseline dependency; prepared source package membership proven | EVIDENCE_BACKED_CANDIDATE |
| 04 | ECTOS.L01.STRUCTURATION_FACADE.V03 | RUNTIME_FACADE_MODULE | QFAM-RUNTIME-FACADE-V01 | L01 prebuild/selfqual/pre-QF historical PASS; final E2E L01 PASS | EVIDENCE_BACKED_CANDIDATE |
| 05 | ECTOS.L02.INTELLIGENCE_FACADE.V01 | RUNTIME_FACADE_MODULE | QFAM-RUNTIME-FACADE-V01 | L02 DEV Pre-QF/shared QF/final E2E historical PASS | EVIDENCE_BACKED_CANDIDATE |
| 06 | ECTOS.L03.CONSTRUCTION_FACADE.V01 | RUNTIME_FACADE_MODULE | QFAM-RUNTIME-FACADE-V01 | L03 DEV Pre-QF/shared QF/final E2E historical PASS | EVIDENCE_BACKED_CANDIDATE |
| 07 | ECTOS.L04.BUSINESS_FACADE.V02 | RUNTIME_FACADE_MODULE | QFAM-RUNTIME-FACADE-V01 | L04 prebuild/selfqual/pre-QF historical PASS; final E2E L04 PASS | EVIDENCE_BACKED_CANDIDATE |
| 08 | ECTOS.L05.CONTINUITY_FACADE.V01 | RUNTIME_FACADE_MODULE | QFAM-RUNTIME-FACADE-V01 | L05 DEV Pre-QF/shared QF/final E2E historical PASS | EVIDENCE_BACKED_CANDIDATE |
| 09 | TaxonomyClassifier.psm1 | CORE_COMPONENT_ENGINE | QFAM-CORE-COMPONENT-ENGINE-V01 | selected by L01; prepared-package membership physically recovered | EVIDENCE_BACKED_CANDIDATE |
| 10 | ClassificationEngine.psm1 | CORE_COMPONENT_ENGINE | QFAM-CORE-COMPONENT-ENGINE-V01 | selected by L02; exact Repository overlap/SHA recovered | EVIDENCE_BACKED_CANDIDATE |
| 11 | WpdfArtifactGenerator.psm1 | CORE_COMPONENT_ENGINE | QFAM-CORE-COMPONENT-ENGINE-V01 | selected by L03; repository source physically identified | EVIDENCE_BACKED_CANDIDATE |
| 12 | ECTOS.L04.BusinessRequestHandler.V01.psm1 | CORE_COMPONENT_ENGINE | QFAM-CORE-COMPONENT-ENGINE-V01 | bound by L04 V02; historical L04 pre-QF/selfqual/final E2E | EVIDENCE_BACKED_CANDIDATE |
| 13 | IDBankService.psm1 | CORE_COMPONENT_ENGINE | QFAM-CORE-COMPONENT-ENGINE-V01 | selected by L05; canonical repository source proven; selected collision-preflight scope historically qualified | EVIDENCE_BACKED_CANDIDATE |

## Recovered facade-to-engine bindings

These bindings are supported by the F07 lineage corpus, but current runtime consumption remains NOT_PROVEN unless separately closed.

| Layer | Facade | Selected engine | Binding state |
|---|---|---|---|
| L01 | ECTOS.L01.STRUCTURATION_FACADE.V03 | TaxonomyClassifier.psm1 | HISTORICAL_BINDING_PROVEN_CURRENT_RUNTIME_NOT_PROVEN |
| L02 | ECTOS.L02.INTELLIGENCE_FACADE.V01 | ClassificationEngine.psm1 | HISTORICAL_BINDING_PROVEN_CURRENT_RUNTIME_NOT_PROVEN |
| L03 | ECTOS.L03.CONSTRUCTION_FACADE.V01 | WpdfArtifactGenerator.psm1 | HISTORICAL_BINDING_PROVEN_CURRENT_RUNTIME_NOT_PROVEN |
| L04 | ECTOS.L04.BUSINESS_FACADE.V02 | ECTOS.L04.BusinessRequestHandler.V01.psm1 | HISTORICAL_BINDING_PROVEN_CURRENT_RUNTIME_NOT_PROVEN |
| L05 | ECTOS.L05.CONTINUITY_FACADE.V01 | IDBankService.psm1 | HISTORICAL_BINDING_PROVEN_CURRENT_RUNTIME_NOT_PROVEN |

## Qualification capability derivation

### QFAM-ROUTING-CONTROL-V01
Mandatory challenge classes derived from recovered G00 V06 qualification evidence and routing role:
- parser/runtime startability where applicable
- StrictMode / equivalent strict execution mode
- cardinality 0 / 1 / many
- fail-path microprobe
- success-path microprobe
- unknown target / unresolved route fail-closed
- deterministic destination resolution
- authorization / authority boundary
- cross-layer handoff compatibility
- recursion / loop prevention
- route currentness / stale target rejection
- runtime compatibility

### QFAM-ORCHESTRATION-CONTROL-V01
Mandatory challenge classes:
- dependency closure
- chain ordering
- partial failure propagation
- timeout propagation
- retry policy
- rollback / abort behavior
- evidence capture completeness
- no unauthorized mutation
- exact completion criteria
- whole-chain negative control

### QFAM-RUNTIME-FACADE-V01
Mandatory challenge classes:
- inbound payload contract
- outbound payload contract
- schema and cardinality
- layer entry semantics
- layer exit semantics
- exact selected-engine binding
- downstream failure translation
- timeout propagation
- version/currentness compatibility
- cross-layer boundary compatibility
- negative controls for malformed/missing fields

### QFAM-CORE-COMPONENT-ENGINE-V01
Mandatory challenge classes:
- exact functional contract
- null / empty / single / many
- malformed input
- deterministic output where required
- declared side effects only
- state mutation boundary
- dependency identity
- runtime compatibility
- error/timeout handling
- idempotence where applicable
- engine-specific negative controls

## Generic tool rule

For ECTOS DEV, a new target in an already-proven family should be qualified through:

GENERIC_FAMILY_QUALIFIER_ENGINE
+ FAMILY_PROFILE
+ TARGET_CONTRACT
+ TARGET_TEST_MANIFEST
+ TARGET_NEGATIVE_CONTROL_MANIFEST
+ RUNTIME_ADAPTER

A new target MUST NOT require modification of generic qualifier logic unless the family contract itself changes.

## Search-before-build status

Historical tooling recovery reports a reachable corpus of 54 tools and six historical qualification profiles. Exact profile-to-family equivalence is NOT_PROVEN and must be reconciled before building any new tool.

Therefore for every family:

EXISTING_TOOL_SEARCH=MANDATORY
CURRENT_ADMITTED_TOOL=NOT_PROVEN
TOOL_EXECUTION_ELIGIBILITY=NO
NEW_TOOL_BUILD_AUTHORITY=NO

## Current gaps

- Complete ECTOS OS engine family set is NOT_PROVEN.
- Exact historical six qualification profile identities/contracts are not yet reconciled to these family IDs.
- Current admitted/trusted tool per family is NOT_PROVEN.
- Current runtime consumption of the 13-object set is NOT_PROVEN.
- Cross-layer edge contracts remain incomplete.
- Runtime carrier/materialization family still requires exact present-runtime binding.

## Closure rule

This register may become CURRENT only when each current OS object is bound to a proven family and each family is bound to a versioned qualification profile with reconciled tool coverage, currentness, trust and execution eligibility.