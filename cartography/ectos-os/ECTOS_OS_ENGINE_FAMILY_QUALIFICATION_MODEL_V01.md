# ECTOS OS — Engine Family Qualification Model V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_MODEL
MODE=EVIDENCE_FIRST_DOCUMENTARY_MODEL
STATE=PARTIAL_NOT_PROVEN

## Objective

ECTOS OS is the working model for ECTOS DEV assembly methodology. The cartography must not only show packages, engines, contracts and routes; it must also make it possible to derive qualification requirements by engine family and, later, to create or select qualification tools from those family requirements.

This file defines the qualification-family model only. It does not qualify any tool, admit any Factory tool, or claim that a current trusted qualifier exists.

## Core invariant

ENGINE_FAMILY_CARTOGRAPHY
-> FAMILY_QUALIFICATION_PROFILE
-> REQUIRED_CHALLENGE_SET
-> QUALIFICATION_TOOL_REQUIREMENTS
-> TOOL_CANDIDATE
-> INDEPENDENT_TOOL_QUALIFICATION
-> FACTORY_ADMISSION
-> PACKAGE_OR_ENGINE_QUALIFICATION

A qualification tool MUST NOT be generated or selected only from a filename or package name. It must be derived from the physically mapped role, interfaces, runtime, failure modes, authority boundaries and assembly position of the target family.

## Recovered engine/object families

The currently recovered 13-object runtime/semantic set supports the following family classes as evidence-backed starting points:

1. ROUTING_CONTROL_MODULE
   - Examples: ECTOS.G00.DownstreamDispatcher.Candidate.V06; ECTOS.G00.psm1.
   - Qualification concerns: route selection, deny/fail-closed behavior, cardinality, unknown target handling, route currentness, authorization, cross-layer handoff, recursion/loop prevention, deterministic destination resolution.

2. ORCHESTRATION_CONTROL
   - Example: ECTOS.COMPLETE_SIX_LAYER_CORE.FINAL_OPERATOR.OPTION_B_ORCHESTRATION.V04.
   - Qualification concerns: chain ordering, dependency closure, state transitions, partial failure behavior, retry policy, timeout propagation, evidence capture, rollback, no unauthorized mutation, whole-chain completion.

3. RUNTIME_FACADE_MODULE
   - Examples: L01 Structuration, L02 Intelligence, L03 Construction, L04 Business, L05 Continuity facades.
   - Qualification concerns: inbound contract, outbound contract, payload/schema conformance, interface stability, layer-entry/layer-exit semantics, downstream call contract, negative controls, cross-layer compatibility.

4. CORE_COMPONENT_ENGINE
   - Examples: TaxonomyClassifier, ClassificationEngine, WpdfArtifactGenerator, BusinessRequestHandler, IDBankService.
   - Qualification concerns: engine-specific functional contract, input/output determinism, runtime behavior, dependency identity, null/empty/single/many, malformed input, error/timeout handling, state mutation boundaries, side effects, idempotence where applicable.

5. CROSS_LAYER_HANDOFF
   - Derived from the assembly requirement even when represented by routing/facade objects rather than a standalone object.
   - Qualification concerns: exact producer exit contract, route resolution, exact consumer entry contract, payload compatibility, authority transfer, correlation/evidence continuity, timeout/error propagation, version/currentness compatibility.

6. RUNTIME_CARRIER_AND_MATERIALIZATION
   - Example evidence domain: ECTOS_V1_CLOUD_RUN_REAL_REQUEST_BINDING_SUCCESSOR_V03.zip as runtime carrier; source-parent identity remains distinct.
   - Qualification concerns: source identity, package identity, materialized bytes, runtime/host binding, configuration, environment, loaded component set, startup, health, rollback and evidence integrity.

These six family classes are a V01 qualification taxonomy candidate. They are not yet claimed as the complete current ECTOS OS family set.

## Mandatory family qualification profile

Every engine family must eventually have a machine-readable qualification profile with at least:

- FAMILY_ID
- FAMILY_VERSION
- TARGET_OBJECT_CLASSES
- TARGET_RUNTIME_CLASSES
- SUPPORTED_OS
- REQUIRED_INPUT_CONTRACT_FIELDS
- REQUIRED_OUTPUT_CONTRACT_FIELDS
- REQUIRED_INTERFACE_FIELDS
- REQUIRED_DEPENDENCY_PROOFS
- REQUIRED_CURRENTNESS_PROOFS
- REQUIRED_AUTHORITY_PROOFS
- REQUIRED_POSITIVE_TEST_CLASSES
- REQUIRED_NEGATIVE_TEST_CLASSES
- REQUIRED_CARDINALITY_CASES
- REQUIRED_ERROR_PATHS
- REQUIRED_TIMEOUT_PATHS
- REQUIRED_CONCURRENCY_CASES where applicable
- REQUIRED_ROLLBACK_CASES where applicable
- REQUIRED_ASSEMBLY_BOUNDARY_TESTS
- REQUIRED_EVIDENCE_OUTPUTS
- PASS_CRITERIA
- FAIL_CLOSED_CRITERIA
- QUALIFIER_INDEPENDENCE_REQUIREMENT

## Tool creation rule by family

A new qualification tool may be created only when the cartography proves enough of the target family contract to derive an unambiguous challenge set.

Required derivation chain:

1. Locate target engine/package in the current cartography.
2. Resolve its FAMILY_ID.
3. Resolve PREVIOUS_NODE / NEXT_NODE and layer position.
4. Resolve INPUT_CONTRACT / OUTPUT_CONTRACT.
5. Resolve runtime, host and materialization requirements.
6. Resolve dependencies and authority boundary.
7. Resolve historical defect families and negative controls.
8. Build the qualification challenge manifest from the family profile plus target-specific deltas.
9. Search existing qualification-tool catalog before building a new tool.
10. If no suitable admitted tool exists, create a candidate tool from the family profile.
11. Independently qualify the tool itself.
12. Admit the tool only through the governed Factory / authority path.
13. Use the tool against the target only after tool admission and target currentness proof.

## Search-before-build invariant

EXISTING_TOOL_SEARCH=MANDATORY

NEW_TOOL_BUILD_ALLOWED only when:
- no current admitted tool satisfies the family profile; or
- existing tool coverage is partial and cannot be safely extended under current governance; or
- runtime/OS/interface differences require a distinct tool family.

Historical PASS, filename similarity or prior use do not prove current tool eligibility.

## Family tool architecture rule

Qualification logic should be generic at family level and target-specific data should live in profiles/contracts.

Preferred model:

GENERIC_FAMILY_QUALIFIER_ENGINE
+ FAMILY_PROFILE
+ TARGET_CONTRACT
+ TEST_MANIFEST
+ NEGATIVE_CONTROL_MANIFEST
+ RUNTIME_ADAPTER
= TARGET_QUALIFICATION_EXECUTION

Adding a new package/engine in an already-supported family should not require modifying generic qualification engine logic unless the family contract itself changes.

## Assembly qualification layering

Qualification must cover both object quality and assembly quality:

L1_COMPONENT_QUALIFICATION
- exact package/object behavior

L2_INTERFACE_DEPENDENCY_QUALIFICATION
- package-to-package and engine-to-engine contracts

L3_LAYER_ASSEMBLY_QUALIFICATION
- complete intra-layer chain

L4_CROSS_LAYER_BOUNDARY_QUALIFICATION
- G00->L01, L01->L02, L02->L03, L03->L04, L04->L05 and any proven alternative routed edges

L5_FULL_SYSTEM_END_TO_END
- whole current assembly

TESTS_PASS != QUALIFIED
PACKAGE_QUALIFIED != ASSEMBLY_READY
ASSEMBLY_READY != FULL_SYSTEM_PASS

## Current evidence relationship

Recovered tooling work reports:
- REACHABLE_TOOL_RECORD_COUNT=54
- QUALIFICATION_PROFILE_COUNT=6
- CURRENT_TRUSTED_QUALIFIER_COUNT=0
- CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0
- SELECTED_DEV_QUALIFICATION_TOOL_COUNT=4
- CURRENT_FACTORY_ADMITTED_SELECTED_TOOLS=0

These figures are documentary/read-only evidence and do not prove current tool trust or execution eligibility.

The six qualification profiles reported historically MUST NOT be silently equated to the six family classes in this file unless exact profile identities and contracts are physically reconciled.

## Required cartography extensions

For every engine/package node, add:

- ENGINE_FAMILY_ID
- QUALIFICATION_PROFILE_ID
- REQUIRED_QUALIFICATION_CAPABILITIES
- EXISTING_TOOL_CANDIDATES
- CURRENT_ADMITTED_TOOL
- TOOL_CURRENTNESS
- TOOL_QUALIFICATION_STATE
- ASSEMBLY_TEST_REQUIREMENTS
- CROSS_LAYER_TEST_REQUIREMENTS

For every edge, add:

- EDGE_TYPE: INTRA_LAYER | CROSS_LAYER | ROUTE | MATERIALIZES | BINDS | EXECUTES_ON | READS_STATE | WRITES_STATE | HANDS_OFF_TO
- CONTRACT_ID
- PRODUCER_NODE
- CONSUMER_NODE
- PAYLOAD_OR_CONTROL_SCHEMA
- AUTHORITY_TRANSFER_RULE
- ERROR_PROPAGATION_RULE
- TIMEOUT_PROPAGATION_RULE
- REQUIRED_EDGE_QUALIFICATION_PROFILE
- QUALIFICATION_EVIDENCE
- CURRENTNESS

## Current status

ENGINE_FAMILY_MODEL=PARTIAL
FAMILY_COUNT_CANDIDATE=6
COMPLETE_ENGINE_FAMILY_SET=NOT_PROVEN
PROFILE_TO_FAMILY_BINDING=NOT_PROVEN
CURRENT_TRUSTED_QUALIFIER_COUNT=0
CURRENT_EXECUTION_ELIGIBLE_ROUTE_COUNT=0
TOOL_GENERATION_IMPLEMENTATION=NOT_AUTHORIZED
TOOL_QUALIFICATION_EXECUTION=NOT_AUTHORIZED

## Closure rule

This model can be promoted from PARTIAL only after:
- the current ECTOS OS engine/package graph is closed to PROVEN/explicit NOT_PROVEN edges;
- every current engine/object is assigned to a proven family;
- family qualification profiles are physically versioned;
- existing qualification tools are reconciled to those profiles;
- gaps requiring new tool creation are explicit;
- generic-vs-target-specific boundaries are verified;
- tool creation and tool qualification remain separate authorities.
