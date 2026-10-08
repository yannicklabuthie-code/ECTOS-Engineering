# ECTOS OS — Engine Family Qualification Decision Register V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_DECISION_REGISTER
MODE=EVIDENCE_FIRST_PROVEN_SHORTLIST_ONLY
STATE=PARTIAL_NOT_PROVEN

## Purpose

Decide the current qualification-tool route for each ECTOS OS engine family using only source-backed successful ECTOS OS qualification/control assets. The historical 54-record tooling corpus is archival discovery evidence only and is not an active requalification backlog.

## Governing rules

- ACTOR != EXECUTABLE_TOOL
- TOOL_PRESENT != TOOL_QUALIFIED
- TOOL_QUALIFIED != TOOL_ADMITTED
- HISTORICAL_PASS != CURRENT_TRUST
- PACKAGE_QUALIFIED != PACKAGE_ASSEMBLY_READY
- EXISTING_SUCCESSFUL_ASSET_FIRST=YES
- FAILED_UNUSED_DISCOVERY_ASSET_REVIVAL=NO
- BUILD_NEW only when proven successful assets do not cover the family requirement envelope.

## Proven-success asset shortlist

B01=ECTOS.G00.V06.QF.TRANSITIVE_DEPENDENCY_CLOSURE.SUCCESSOR.V02
HISTORICAL_RESULT=TARGETED_QF_PASS_ACCEPTED
PRIMARY_TARGET=G00 V06 routing/dependency closure

B02=ECTOS.COMPLETE_SIX_LAYER_CORE.FORMAL_FINAL_CORE_QF.V01
HISTORICAL_RESULT=25_OF_25_CLOSED_PASS
PRIMARY_TARGET=L01-L05 / final six-layer core

B03=ECTOS.G00.L01.FORMAL_QF_CONTROL.V06
HISTORICAL_RESULT=24_OF_24_PASS
PRIMARY_TARGET=G00 + L01 bound qualification/control

Additional historical materialization evidence exists, but the currently recovered materializer lineage includes remediation/failure history. It is not promoted here as a clean proven reusable family qualifier.

## Family decisions

### QFAM-ROUTING-CONTROL-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=B01 + B03
COVERAGE_STATE=STRONG_PARTIAL
DECISION=ADAPT

Reason:
- B01 proves targeted G00 routing/dependency qualification value.
- B03 proves G00/L01 bound qualification/control value.
- The current family requirement additionally requires generic route abstraction, unknown/ambiguous target fail-closed behavior, route-loop protection, authority continuity and cross-layer outbound compatibility.

REQUIRED_ADAPTATION_DELTA:
- generalize package-specific checks into family requirement inputs;
- explicit route-contract identity;
- generic target-layer resolution;
- negative controls for unknown/ambiguous/stale/loop routes;
- exact G00 outbound -> L01 inbound contract binding.

### QFAM-ORCHESTRATION-CONTROL-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=B02
COVERAGE_STATE=STRONG_PARTIAL
DECISION=ADAPT

Reason:
- B02 physically/source-backed the accepted final six-layer qualification chain at 25/25 CLOSED_PASS.
- The current family model requires reusable orchestration qualification independent of one frozen six-layer package identity.

REQUIRED_ADAPTATION_DELTA:
- parameterized stage/member set;
- ordered execution contract checks;
- no-silent-skip / no-silent-retry controls;
- generic stage evidence aggregation;
- authority consumption/replay checks;
- fail-closed on any unqualified required edge.

### QFAM-RUNTIME-FACADE-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=B02 + B03
COVERAGE_STATE=PARTIAL
DECISION=ADAPT

Reason:
- B02 covers final six-layer accepted qualification lineage.
- B03 gives bound G00/L01 evidence.
- No recovered successful asset is proven as a generic standalone façade-family qualifier for all L01-L05 façades.

REQUIRED_ADAPTATION_DELTA:
- generic façade inbound/outbound contract checks;
- internal engine binding validation;
- input/output normalization checks;
- downstream abstraction validation;
- forbidden cross-layer bypass negative controls;
- component -> façade seam qualification.

### QFAM-CORE-COMPONENT-ENGINE-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=PARTIAL_TARGET_BOUND_ONLY
COVERAGE_STATE=INSUFFICIENT_FOR_GENERIC_STANDALONE_FAMILY_QUALIFIER
DECISION=BUILD_NEW

Reason:
- native component engines have historical target-bound evidence, but current reachable evidence does not prove one successful reusable standalone generic component-engine qualifier.
- reviving random historical scripts is prohibited by current scope.

BUILD_NEW_REQUIREMENTS:
- family requirement profile as input;
- runtime adapter, including native PS5.1 where applicable;
- parser/import/load/startability gates;
- dependency closure;
- input/output schema validation;
- null/empty/single/many cases where applicable;
- deterministic exit/error/timeout semantics;
- artifact/evidence identity;
- negative controls for malformed input, wrong runtime, missing/stale dependency and incomplete output.

### QFAM-CROSS-LAYER-HANDOFF-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=B03 + B02
COVERAGE_STATE=PARTIAL
DECISION=BUILD_NEW

Reason:
- B03 proves useful G00/L01 bound qualification evidence and B02 proves the accepted final six-layer chain.
- Neither is currently proven as a reusable generic boundary qualifier for every edge G00->L01, L01->L02, L02->L03, L03->L04 and L04->L05.
- This family is the critical anti-recurrence control for the historical assembly problem.

BUILD_NEW_REQUIREMENTS:
- exact source-node and destination-interface identity;
- outbound/inbound schema compatibility;
- route/handoff identity;
- transformation contract where applicable;
- authority/correlation/evidence continuity;
- timeout/downstream failure propagation;
- replay/duplicate behavior;
- negative controls for wrong destination, wrong interface version, incompatible schema, missing field, unauthorized transformation, bypass and partial handoff evidence.

### QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01

PROVEN_SUCCESSFUL_ASSET_MATCH=NO_CLEAN_REUSABLE_FAMILY_QUALIFIER_PROVEN
COVERAGE_STATE=NOT_PROVEN_FOR_REUSE
DECISION=BUILD_NEW

Reason:
- current source search recovered materializer and runtime-carrier history, including physically verified packages and later remediation/failure history.
- that history is valuable negative knowledge but does not prove a clean generic reusable family qualifier under current governance.

BUILD_NEW_REQUIREMENTS:
- canonical source/package identity;
- manifest/SHA closure;
- local materialization byte identity;
- host/runtime/path/config binding;
- entrypoint/process contract;
- permission prerequisites;
- stdout/stderr/exit/timeout evidence;
- created-output identities;
- rollback/forensic preservation;
- negative controls for stale/wrong package, missing member, byte mismatch, wrong host/runtime/path/config and unauthorized host mutation.

## Current decision summary

QFAM-ROUTING-CONTROL-V01=ADAPT
QFAM-ORCHESTRATION-CONTROL-V01=ADAPT
QFAM-RUNTIME-FACADE-V01=ADAPT
QFAM-CORE-COMPONENT-ENGINE-V01=BUILD_NEW
QFAM-CROSS-LAYER-HANDOFF-V01=BUILD_NEW
QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01=BUILD_NEW

REUSE_AS_IS_COUNT=0
ADAPT_COUNT=3
BUILD_NEW_COUNT=3
NOT_PROVEN_DECISION_COUNT=0

Important: BUILD_NEW here means 'new governed family-specific qualifier required by the current methodology'. It is not authorization to generate code, execute qualification, or admit a tool.

## Qualification architecture target

For adapted or new family qualifiers:

GENERIC_FAMILY_QUALIFIER_ENGINE
+
FAMILY_REQUIREMENT_PROFILE
+
RUNTIME_OVERLAY
+
TARGET_CONTRACT
+
NEGATIVE_CONTROL_MANIFEST
+
EVIDENCE_COLLECTOR
+
RUNTIME_ADAPTER

This allows future DEV packages in the same family to reuse the qualification engine while supplying a target-specific contract/profile instead of creating package-specific qualifier code.

## Next safe action

NEXT_ACTION=
FREEZE_PER_FAMILY_QUALIFIER_CONTRACTS_AND_MAP_THEM_TO_CURRENT_ECTOS_OS_NODES_AND_EDGES

Required outputs per family:
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

## Authority boundary

CODE_GENERATION=NO
TOOL_BUILD=NO
QUALIFICATION_EXECUTION=NO
FACTORY_ADMISSION=NO
ROUTE_PROMOTION=NO

This register is documentary cartography/methodology only.