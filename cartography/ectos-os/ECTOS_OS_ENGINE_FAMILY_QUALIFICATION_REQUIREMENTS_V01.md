# ECTOS OS — Engine Family Qualification Requirements V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_REQUIREMENTS
MODE=EVIDENCE_FIRST_DERIVED_CARTOGRAPHY_MODEL
STATE=CANDIDATE_PARTIAL_NOT_PROVEN

## Purpose

Derive a reusable qualification requirement model from the current ECTOS OS cartography so that qualification tooling can be created, selected, extended or reused by ENGINE FAMILY rather than by package name.

This is a derived current methodology model. It is NOT presented as a recovered historical Factory profile registry.

## Governing invariants

PACKAGE_QUALIFIED != PACKAGE_ASSEMBLY_READY
LAYER_COMPONENTS_QUALIFIED != LAYER_ASSEMBLED
LAYER_ASSEMBLED != NEXT_LAYER_COMPATIBLE
REMOTE_SOURCE_EXISTS != LOCAL_MATERIALIZATION_PROVEN
STATIC_REVIEW != NATIVE_EXECUTION
TOOL_PRESENT != TOOL_QUALIFIED
TOOL_QUALIFIED != TOOL_ADMITTED
HISTORICAL_PASS != CURRENT_TRUST

Every family profile must define:

- target member identity
- package / manifest identity
- source / commit / SHA binding where applicable
- runtime and OS constraints
- dependency closure
- entrypoint and startability
- input contract
- output contract
- route / handoff contract
- error path
- timeout path
- authority / trust boundary
- required evidence
- negative controls
- final result gate
- downstream assembly requirements

## Family 1 — QFAM-ROUTING-CONTROL-V01

RECOVERED_OS_OBJECTS_INCLUDE:
- ECTOS.G00.DownstreamDispatcher.Candidate.V06
- ECTOS.G00.psm1

QUALIFICATION_OBJECTIVE:
Prove deterministic route selection, target resolution and controlled dispatch without hidden target-specific coupling.

REQUIRED_GATES:
- exact source/package identity
- route table / route contract identity
- declared target-layer set
- input schema validation
- output / dispatch schema validation
- deterministic route resolution
- unknown route fail-closed
- ambiguous route fail-closed
- unavailable downstream target handling
- dependency declaration
- timeout handling
- retry policy validation
- authority context propagation
- no unauthorized target substitution
- no package-name-specific hardcoding where generic routing is required

REQUIRED_NEGATIVE_CONTROLS:
- unknown target
- duplicate/ambiguous target
- malformed route request
- missing downstream contract
- stale route definition
- unauthorized route injection
- downstream timeout
- downstream non-zero failure
- route loop / self-route

ASSEMBLY_REQUIREMENT:
Must qualify both intra-G00 routing and the outbound G00 -> L01 boundary contract.

## Family 2 — QFAM-ORCHESTRATION-CONTROL-V01

RECOVERED_OS_OBJECTS_INCLUDE:
- ECTOS.COMPLETE_SIX_LAYER_CORE.FINAL_OPERATOR.OPTION_B_ORCHESTRATION.V04

QUALIFICATION_OBJECTIVE:
Prove complete ordered execution-chain control, state propagation, stop conditions, evidence closure and authority boundaries.

REQUIRED_GATES:
- exact orchestrator identity
- complete declared stage/member set
- ordered execution contract
- dependency graph closure
- stage entry/exit contract checks
- process exit semantics
- stdout/stderr capture where process boundaries exist
- timeout / cancellation handling
- downstream error propagation
- no silent skip
- no silent retry
- evidence completeness
- final result aggregation
- authority consumption / replay boundary

REQUIRED_NEGATIVE_CONTROLS:
- missing stage
- reordered stage
- duplicate stage
- failed stage followed by unauthorized continuation
- missing evidence
- stale member identity
- timeout
- partial result falsely promoted to PASS
- repeated authority consumption

ASSEMBLY_REQUIREMENT:
Must prove full declared layer chain and fail-closed behavior if any required edge is not qualified.

## Family 3 — QFAM-RUNTIME-FACADE-V01

RECOVERED_OS_OBJECTS_INCLUDE:
- ECTOS.L01.STRUCTURATION_FACADE.V03
- ECTOS.L02.INTELLIGENCE_FACADE.V01
- ECTOS.L03.CONSTRUCTION_FACADE.V01
- ECTOS.L04.BUSINESS_FACADE.V02
- ECTOS.L05.CONTINUITY_FACADE.V01

QUALIFICATION_OBJECTIVE:
Prove each layer façade as a stable contract boundary between upstream callers, internal component engines and downstream layer handoff.

REQUIRED_GATES:
- exact façade identity
- layer identity
- inbound contract
- outbound contract
- internal engine binding
- input normalization rules
- output normalization rules
- dependency declaration
- downstream target abstraction
- error translation / propagation
- timeout behavior
- no hidden direct coupling to non-declared downstream implementation
- layer-entry and layer-exit evidence

REQUIRED_NEGATIVE_CONTROLS:
- malformed inbound payload
- missing internal engine
- incompatible internal engine output
- missing outbound route
- downstream unavailable
- stale interface version
- undeclared field / contract mismatch
- forbidden cross-layer bypass

ASSEMBLY_REQUIREMENT:
Each façade must pass component qualification, internal engine seam qualification and cross-layer boundary qualification.

## Family 4 — QFAM-CORE-COMPONENT-ENGINE-V01

RECOVERED_OS_OBJECTS_INCLUDE:
- TaxonomyClassifier.psm1
- ClassificationEngine.psm1
- WpdfArtifactGenerator.psm1
- ECTOS.L04.BusinessRequestHandler.V01.psm1
- IDBankService.psm1

QUALIFICATION_OBJECTIVE:
Prove the functional component engine independently from the façade while preserving exact runtime, input/output contract and deterministic failure semantics.

REQUIRED_GATES:
- exact source/package identity
- runtime/profile fit
- parser / import / load as applicable
- entrypoint invocation
- declared dependency closure
- input contract
- output contract
- deterministic success/failure semantics
- process/function exit semantics
- required artifact/evidence identity
- null / empty / single / many behavior where applicable
- negative input validation
- timeout handling

REQUIRED_NEGATIVE_CONTROLS:
- invalid input
- missing dependency
- wrong runtime
- stale dependency
- empty input
- malformed input
- dependency failure
- timeout
- incomplete output
- wrong output schema

ASSEMBLY_REQUIREMENT:
Must separately qualify COMPONENT -> FACADE seam; standalone component PASS is insufficient for layer readiness.

## Family 5 — QFAM-CROSS-LAYER-HANDOFF-V01

TARGET_EDGES_INCLUDE:
- G00 -> L01
- L01 -> L02
- L02 -> L03
- L03 -> L04
- L04 -> L05

QUALIFICATION_OBJECTIVE:
Prove that the terminal outbound contract of one layer is compatible with the inbound contract of the next layer and that the routing/handoff mechanism preserves identity, authority, evidence and failure semantics.

REQUIRED_GATES:
- exact source node identity
- exact destination layer / interface identity
- outbound schema
- inbound schema
- schema compatibility
- route identity
- payload transformation contract if any
- authority context continuity
- correlation / trace identity where applicable
- timeout
- downstream error propagation
- replay / duplicate handoff behavior where applicable
- evidence linking both sides of the boundary

REQUIRED_NEGATIVE_CONTROLS:
- wrong destination layer
- wrong interface version
- incompatible schema
- missing required field
- unauthorized transformation
- duplicate/replay handoff
- downstream timeout
- downstream rejection
- partial handoff evidence
- hidden direct implementation coupling

ASSEMBLY_REQUIREMENT:
BOUNDARY_READY only after outbound contract + handoff contract + inbound contract + negative controls all PASS for exact identities.

## Family 6 — QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01

RECOVERED_CONTEXT_INCLUDES:
- Golden accepted core package
- last-proven production runtime carrier
- Windows materialization / workspace identity lessons

QUALIFICATION_OBJECTIVE:
Prove that exact canonical source/package identities are materialized into the intended runtime/host without silent byte, path, configuration or version substitution.

REQUIRED_GATES:
- remote source/package identity
- manifest and SHA closure
- local materialization identity
- worktree/package byte identity where required
- host binding
- target OS/runtime binding
- path validity
- configuration identity
- entrypoint availability
- permissions / authorization prerequisites
- process command contract
- stdout/stderr/exit/timeout evidence
- created output identities
- rollback / forensic preservation

REQUIRED_NEGATIVE_CONTROLS:
- wrong commit/package
- missing member
- stale materialization
- clean status with raw-byte mismatch
- normalized hash substitution
- wrong host/runtime
- missing path
- invalid configuration
- missing permission
- unauthorized global-host mutation

ASSEMBLY_REQUIREMENT:
Execution eligibility requires canonical identity -> local materialization -> host/runtime binding -> entrypoint proof. Remote existence alone is insufficient.

## Runtime-specific overlay — QP-WPS51-V01

Where a target family member is a Windows PowerShell 5.1 tool/package, the source-backed QP-WPS51-V01 requirements are an overlay, not a replacement for family requirements.

SOURCE_BACKED_STATIC_GATES:
- package identity
- manifest
- SHA256
- schema
- dependency declaration
- currentness declaration

SOURCE_BACKED_NATIVE_GATES:
- Windows PowerShell Desktop 5.1 parse
- import/load
- native execution
- exit semantics
- stdout/stderr capture

SOURCE_BACKED_NEGATIVE_FAMILIES:
- wrong/unknown platform
- wrong/unknown runtime
- untrusted qualifier
- missing native gate/evidence/dependency
- stale/superseded profile or qualifier
- unauthorized substitution

## Generic qualifier architecture

TARGET_MODEL:

GENERIC_FAMILY_QUALIFIER_ENGINE
+
FAMILY_REQUIREMENT_PROFILE
+
RUNTIME_OVERLAY_PROFILE
+
TARGET_CONTRACT
+
NEGATIVE_CONTROL_MANIFEST
+
RUNTIME_ADAPTER
+
EVIDENCE_COLLECTOR

A new package in an existing family SHOULD require only a new target contract/profile when family semantics are unchanged.

NEW_QUALIFIER_CODE_REQUIRED only if:
- a required gate cannot be expressed by the current generic engine,
- a new runtime boundary requires a new adapter,
- or the engine-family contract itself materially changes.

## Owner-corrected tool selection policy

The 54-record tooling corpus is ARCHIVAL / DISCOVERY EVIDENCE ONLY.

It is NOT a backlog of 54 candidates to re-check, requalify, classify or adapt.

The active selection order is:

1. start from qualification/control assets that are physically proven to have successfully contributed to ECTOS OS qualification or assembly closure;
2. bind those successful assets to the engine-family requirements in this document;
3. reuse or adapt only a proven successful asset when its capability contract fits the target family;
4. if no proven successful asset fits, prefer a small governed family-specific qualifier built from current canonical engineering primitives / native runtime capabilities;
5. independently qualify that new/adapted qualifier before Factory admission;
6. never revive an unused, failed, superseded or merely discovered historical tool solely because it appears in the 54-record corpus.

ARCHIVAL_54_TOOL_RECHECK_REQUIRED=NO
ARCHIVAL_54_TOOL_REQUALIFICATION_REQUIRED=NO
ARCHIVAL_54_TOOL_MAPPING_REQUIRED_FOR_FAMILY_DESIGN=NO

## Distinguish actors from qualification instruments

Operational actors/sessions and executable qualification instruments are different objects.

Examples of source-backed operational qualification/engineering actors include:
- ECTOS DEV Tooling Registry & Qualification Mapping Agent
- Yanick ECTOS/ENGINEERING ASSURANCE PRÊT
- Yanick ECTOS Assurance Layer

These actors may produce, review, route or qualify evidence. They are not automatically executable qualification tools.

Conversely, a qualification control/script/package is not an independent qualifier merely because it can execute checks.

ACTOR != TOOL
TOOL != QUALIFIER
QUALIFIER != ADMISSION_AUTHORITY

## Current successful qualification/control anchors

Current cartography work SHALL prioritize the successful source-backed OS qualification/control lineage already recovered, including:

- ECTOS.G00.V06.QF.TRANSITIVE_DEPENDENCY_CLOSURE.SUCCESSOR.V02 for G00 targeted qualification lineage;
- ECTOS.COMPLETE_SIX_LAYER_CORE.FORMAL_FINAL_CORE_QF.V01 for the six-layer/final façade qualification lineage;
- ECTOS.G00.L01.FORMAL_QF_CONTROL.V06 for recovered G00/L01 bound-component qualification lineage;
- exact additional successful controls only when their result and target binding are physically/source-backed.

The shortlist is intentionally small. Failed/unused/discovery-only artifacts remain historical evidence, not active qualification candidates.

## Currentness / evidence boundary

CURRENT_ADMITTED_TOOL_BY_FAMILY=NOT_PROVEN
CURRENT_TRUSTED_QUALIFIER_COUNT=0
CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0
FOUR_OF_SIX_HISTORICAL_QUALIFICATION_PROFILE_IDENTITIES=NOT_PROVEN

Therefore this document defines qualification requirements, not current tool admission.

## Next required mapping

NEXT_REGISTER=
ECTOS_OS_PROVEN_QUALIFICATION_ASSET_TO_FAMILY_MATRIX_V01

Required columns:
- ASSET_ID
- ASSET_TYPE=ACTOR|QUALIFICATION_CONTROL|RUNNER|HARNESS|VALIDATOR|OTHER
- EXACT_IDENTITY
- SHA256_IF_APPLICABLE
- HISTORICAL_SUCCESS_RESULT
- TARGET_BINDING
- ENGINE_FAMILY
- REQUIREMENT_COVERAGE
- MISSING_GATES
- RUNTIME
- CURRENTNESS
- REUSE_CLASSIFICATION=REUSE|ADAPT|BUILD_NEW|NOT_PROVEN
- EVIDENCE_SOURCE

Only successful/proven assets enter this active matrix. The 54-record discovery corpus remains outside the active matrix unless a specific member is promoted into the shortlist by exact evidence.

## Closure condition

This candidate requirement model becomes eligible for governed qualification-profile freeze only after:

- complete OS node/edge cartography or exact NOT_PROVEN boundaries;
- successful/proven qualification assets are mapped to family requirements;
- exact family/profile runtime overlays;
- independent review of family completeness and prohibited-behavior absence;
- Main adjudication.