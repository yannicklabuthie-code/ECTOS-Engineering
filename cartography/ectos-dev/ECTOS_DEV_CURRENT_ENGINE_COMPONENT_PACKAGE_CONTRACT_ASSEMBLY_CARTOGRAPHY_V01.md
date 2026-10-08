# ECTOS DEV — Current Engine / Component / Package / Contract / Assembly Cartography V01

PROJECT=ECTOS
PROJECT_CONTAINER=ECTOS-POC
AUTHORITY=ECTOS_MAIN_AUTHORITY
SUPERIOR_AUTHORITY=PROJECT_OWNER_YANICK
MODE=EVIDENCE_FIRST_READ_ONLY_CARTOGRAPHY
STATE=PARTIAL_PHYSICAL_CARTOGRAPHY_WITH_EXACT_NOT_PROVEN_BOUNDARIES

## 0. Scope

This document freezes the current evidence-backed ECTOS DEV architecture before physical build/assembly.

It distinguishes:

- logical/cognitive architecture already frozen or stabilized;
- service-extension contracts already defined;
- implementation/assembly sequence already defined;
- physical packages, source commits, SHA256 and runtime bindings that are not yet proven because ECTOS DEV physical build remains not authorized/not completed.

No missing physical identity is reconstructed.

## 1. Top-level architecture

TOP_LEVEL_PLANES=
- ECTOS_FACTORY
- ECTOS_DEV
- ECTOS_OS
- ECTOS_MONITORING

ECTOS_BUILDER=INTERNAL_ECTOS_DEV_FUNCTION
TOOL_FACTORY=INTERNAL_ECTOS_DEV_QUALIFICATION_TOOLING_FUNCTION
BUILDER_AI_NEW_TOP_LEVEL_PLANE=NO

Canonical control flow:

```text
ECTOS MAIN / GOVERNANCE
        |
        v
DEV-K000 — MASTER BRAIN
        <-> SERVICE KNOWLEDGE LAYER
        |
        v
BUILDER API
        |
        v
BUILDER AI
        |
        v
EE-01 CONTROLLED WORKSPACE BUILD
        |
        v
PA-01 PACKAGE ASSEMBLY
        |
        v
PA-02 MANIFEST / IDENTITY / SHA256 CONTROL
        |
        v
EE-02 VALIDATION / REGRESSION / FAIL-CLOSED TESTING
        |
        v
TOOL FACTORY / EPT
        |
        v
EV-01 EVIDENCE / CAUSAL ATTRIBUTION
EV-02 RECONSTRUCTIBILITY / RECOVERY / REPLAY / ROLLBACK
EV-03 MONITORING SUPPORT HANDOFF
        |
        v
QH-01 INDEPENDENT QUALIFICATION HANDOFF
        |
        v
INDEPENDENT QUALIFICATION
        |
        v
QH-02 RELEASE CANDIDATE GOVERNANCE HANDOFF
        |
        v
ECTOS MAIN / GOVERNANCE
```

## 2. DEV-K000 Master Brain

ID=DEV-K000
ROLE=MASTER_BRAIN
FUNCTION=Development intelligence / architecture / reasoning / orchestration
CURRENT_DOCUMENTARY_STATE=STABILIZED_FOR_CURRENT_QUALIFIED_COGNITIVE_SCOPE
PHYSICAL_RUNTIME_PACKAGE=NOT_PROVEN
PHYSICAL_PACKAGE_SHA256=NOT_PROVEN
PHYSICAL_SOURCE_COMMIT=NOT_PROVEN
PHYSICAL_ENTRYPOINT=NOT_PROVEN
PHYSICAL_RUNTIME_HOST=NOT_PROVEN

Responsibilities:

1. understand/challenge the need;
2. define architecture and components;
3. search-before-build / reuse analysis;
4. dependency and impact cartography;
5. produce the DEV design/build/package/evidence contract;
6. hand the governed contract to Builder AI through Builder API;
7. maintain currentness/successor context;
8. use Repository/Evidence/Learning without silently absorbing service-local knowledge.

## 3. Service Knowledge Layer

ROLE=BOUNDED_SPECIALIZATION
EXTENSION_MODEL=GOVERNED_SERVICE_NOTEBOOK

Known service slots:

- SERVICE_TPR
- SERVICE_WEBMETHODS
- SERVICE_AGENT
- SERVICE_ENGINE
- SERVICE_TOOL
- GENERIC_APP_OR_SERVICE
- FUTURE_SERVICE

Standardized service-notebook template state:

DEV_NLM_05_AGENT_REPORTED_STATE=PASS_DEV_NLM_05_STANDARDIZED_SERVICE_NOTEBOOK_TEMPLATE_READY

Architectural invariant:

```text
NEW_SPECIALIZED_SERVICE
!= NEW_TOP_LEVEL_DEV_LAYER
```

Adding a service must not require hard-coded routing changes in DEV-K000 or Builder AI when the generic service registration/contract is sufficient.

Service-local knowledge remains local by default. Promotion into DEV-K000 requires explicit governed review/currentness/admission.

## 4. Internal lifecycle blocks — 15 logical blocks

### CF family — cognitive / control foundation

CF-01 — KNOWLEDGE_CURRENTNESS_RECONCILIATION
ROLE=Reconcile current sources, knowledge and states before change
PHYSICAL_PACKAGE=NOT_PROVEN

CF-02 — DESIGN_CONTRACT_RUNTIME_ADAPTATION
ROLE=Transform target into architecture/design contract adapted to host/runtime
PHYSICAL_PACKAGE=NOT_PROVEN

CF-03 — CARTOGRAPHY_DEPENDENCY_INTELLIGENCE
ROLE=Resolve dependencies, relations, graph and open edges
PHYSICAL_PACKAGE=NOT_PROVEN

CF-04 — CHANGE_IMPACT_ENGINEERING_GATE
ROLE=Evaluate transitive impact and block uncontrolled local remediation
PHYSICAL_PACKAGE=NOT_PROVEN

CF-05 — TOOLCHAIN_HOST_RUNTIME_CONTROL
ROLE=Bind work to exact toolchain, host, runtime and technical prerequisites
PHYSICAL_PACKAGE=NOT_PROVEN

CF-06 — CURRENTIZATION_VERSION_SUCCESSOR_CONTROL
ROLE=Manage lineage, successor, supersession and currentness
PHYSICAL_PACKAGE=NOT_PROVEN

### EE family — engineering execution

EE-01 — CONTROLLED_WORKSPACE_BUILD
ROLE=Build from exact sources in governed workspace
PHYSICAL_PACKAGE=NOT_PROVEN

EE-02 — VALIDATION_REGRESSION_FAIL_CLOSED_TESTING
ROLE=Technical pre-QF validation and regression
PHYSICAL_PACKAGE=NOT_PROVEN

### PA family — package assembly

PA-01 — PACKAGE_ASSEMBLY
ROLE=Deterministic package materialization from build outputs
PHYSICAL_PACKAGE=NOT_PROVEN

PA-02 — MANIFEST_IDENTITY_SHA256_CONTROL
ROLE=Manifest, member inventory, hashes and package identity closure
PHYSICAL_PACKAGE=NOT_PROVEN

### EV family — evidence / reconstructibility

EV-01 — EVIDENCE_CAUSAL_ATTRIBUTION
ROLE=Produce evidence and causal attribution
PHYSICAL_PACKAGE=NOT_PROVEN

EV-02 — RECONSTRUCTIBILITY_RECOVERY_REPLAY_ROLLBACK
ROLE=Produce recipes/evidence for replay, recovery and rollback
PHYSICAL_PACKAGE=NOT_PROVEN

EV-03 — MONITORING_SUPPORT_HANDOFF
ROLE=Transfer telemetry/correlation/incident context to Monitoring
PHYSICAL_PACKAGE=NOT_PROVEN

### QH family — qualification / governance handoff

QH-01 — INDEPENDENT_QUALIFICATION_HANDOFF
ROLE=Freeze target and prepare transfer to independent qualification
PHYSICAL_PACKAGE=NOT_PROVEN

QH-02 — RELEASE_CANDIDATE_GOVERNANCE_HANDOFF
ROLE=Assemble candidate dossier for sovereign Main/Governance decision
PHYSICAL_PACKAGE=NOT_PROVEN

## 5. Builder AI and Builder API

### Builder API

ROLE=GOVERNED_MACHINE_INTERFACE
FUNCTION=Transport DEV design contracts, build recipes, toolchain contracts and package contracts to Builder AI
AUTHORITY=NO_ARCHITECTURAL_SOVEREIGNTY
PHYSICAL_API_PACKAGE=NOT_PROVEN
PHYSICAL_ENDPOINT=NOT_PROVEN
CURRENT_LITERAL_SCHEMA=NOT_PROVEN

### Builder AI

ROLE=GENERIC_CONSTRUCTION_ORCHESTRATOR_INSIDE_ECTOS_DEV
FUNCTION=Execute the architecture/contract decided by DEV-K000; construct and assemble candidate components/packages
ARCHITECTURE_REDECISION=PROHIBITED_BY_INTENT
NEW_TOP_LEVEL_PLANE=NO
PHYSICAL_BUILDER_PACKAGE=NOT_PROVEN
PHYSICAL_RUNTIME=NOT_PROVEN

Documentary phase binding:

BUILDER_PHASE_COUNT=25
BUILDER_PHASE_CROSSWALK=25_OF_25
DIRECT_BINDINGS=18
DERIVED_BINDINGS=7
UNBOUND=0

This proves documentary phase mapping, not physical runtime deployment.

## 6. Tool Factory / EPT

ROLE=TECHNICAL_VALIDATION_TOOLING
FUNCTION=Harnesses, fixtures, pre-QF validation, regression, evidence capture
QUALIFICATION_AUTHORITY=NO
RELEASE_AUTHORITY=NO

Known qualification-tooling work includes candidates such as:

- CANONICAL_55_MATRIX_RUNNER_V02
- ECTOS_POWERSHELL_RESULT_CAPTURE_HARNESS_V01
- ECTOS_DEV_QF_CANONICAL_FACTORY_V02_PREBUILD_WORKBENCH_B_V02

These names do not prove current admission or execution eligibility.

CURRENT_TRUSTED_TOOL_BINDING=NOT_PROVEN
PHYSICAL_DEV_TOOLSET_CLOSURE=NOT_PROVEN

## 7. Repository / Registry / Evidence

ROLE=LOGICAL_REFERENCE_AND_OPERATIONAL_MEMORY

Canonical chain:

```text
PHYSICAL_ARTIFACT
-> IDENTITY
-> REGISTRY
-> PROVENANCE
-> LINEAGE
-> RECONSTRUCTIBILITY
```

Git/Supabase physical repository materialization was intentionally deferred in the recovered DEV architecture rail.

Therefore:

DEV_REPOSITORY_ARCHITECTURE=DEFINED/FROZEN
DEV_PHYSICAL_REPOSITORY_MATERIALIZATION=NOT_PROVEN

## 8. Engineering Learning and Currentness

ENGINEERING_LEARNING_ROLE=Controlled findings/deltas/promotion candidates
CURRENTNESS_STATES=
- CURRENT
- HISTORICAL
- SUPERSEDED
- PARTIAL
- NOT_PROVEN

Service-local learning must not silently mutate DEV-K000.

## 9. Canonical logical assembly sequence

### 9.1 Need -> architecture

```text
INPUT / BUSINESS OR SYSTEM NEED
-> DEV-K000
-> CF-01
-> CF-02
-> CF-03
-> CF-04
-> CF-05
```

### 9.2 Architecture -> construction

```text
DEV-K000
-> Builder API
-> Builder AI
-> EE-01
-> PA-01
-> PA-02
```

### 9.3 Construction -> technical validation

```text
PA-01 / PA-02
-> EE-02
-> Tool Factory / EPT
-> EV-01 / EV-02
```

### 9.4 Validation -> independent qualification -> governance

```text
Package + Evidence
-> QH-01
-> Independent Qualification
-> QH-02
-> ECTOS MAIN / Governance
```

### 9.5 Runtime findings -> learning/currentness

```text
Service / Runtime / Monitoring findings
-> Repository / Evidence
-> Engineering Learning
-> Currentness Review
-> optional Generic Promotion Review
```

## 10. Required seams / contracts

The following seams are architecturally identified but their physical literal contracts are not yet all materialized/proven.

### S01 — Governance -> DEV-K000

AUTHORITY_CONTRACT=ARCHITECTURALLY_DEFINED
LITERAL_RUNTIME_INTERFACE=NOT_PROVEN

### S02 — DEV-K000 <-> Service Knowledge Layer

GENERIC_EXTENSION_INTENT=PROVEN_DOCUMENTARY
STANDARDIZED_SERVICE_NOTEBOOK_TEMPLATE=READY_BY_AGENT_REPORTED_ACCEPTED_RAIL
LITERAL_REGISTRATION_SCHEMA=NOT_PROVEN_PHYSICALLY

### S03 — DEV-K000 -> Builder API

DESIGN_CONTRACT_HANDOFF=ARCHITECTURALLY_DEFINED
LITERAL_PAYLOAD_SCHEMA=NOT_PROVEN_PHYSICALLY

### S04 — Builder API -> Builder AI

GOVERNED_MACHINE_INTERFACE=ARCHITECTURALLY_DEFINED
PHYSICAL_ENDPOINT=NOT_PROVEN
AUTHENTICATION/AUTHORIZATION_BINDING=NOT_PROVEN

### S05 — Builder AI -> EE-01

BUILD_RECIPE_HANDOFF=ARCHITECTURALLY_DEFINED
PHYSICAL_ENTRYPOINT=NOT_PROVEN

### S06 — EE-01 -> PA-01

BUILD_OUTPUT_TO_PACKAGE_ASSEMBLY=ARCHITECTURALLY_DEFINED
LITERAL_OUTPUT_CONTRACT=NOT_PROVEN

### S07 — PA-01 -> PA-02

PACKAGE_TO_MANIFEST_IDENTITY_CONTROL=ARCHITECTURALLY_DEFINED
LITERAL_MANIFEST_SCHEMA=NOT_PROVEN_FOR_FINAL_DEV_RUNTIME

### S08 — PA-02 -> EE-02 / Tool Factory

CANDIDATE_TO_TECHNICAL_VALIDATION=ARCHITECTURALLY_DEFINED
PHYSICAL_TOOL_BINDING=NOT_PROVEN_CURRENT

### S09 — Tool Factory -> EV-01 / EV-02

TECHNICAL_RESULT_TO_EVIDENCE=ARCHITECTURALLY_DEFINED
LITERAL_EVIDENCE_SCHEMA=PARTIAL_NOT_PROVEN

### S10 — EV -> QH-01

QUALIFICATION_HANDOFF=ARCHITECTURALLY_DEFINED
PHYSICAL_HANDOFF_PACKAGE=NOT_PROVEN

### S11 — QH-01 -> Independent Qualification

ROLE_SEPARATION=MANDATORY
CURRENT_EXACT_QUALIFIER_BINDING=NOT_PROVEN

### S12 — Independent Qualification -> QH-02 -> Main

VERDICT_TO_GOVERNANCE=ARCHITECTURALLY_DEFINED
LITERAL_CURRENT_RECEIPT_CONTRACT=NOT_PROVEN

### S13 — Repository <-> Brain / Service / Builder / Tool Factory

IDENTITY_POINTER_RELATION_MODEL=DEFINED
PHYSICAL_BACKEND=DEFERRED/NOT_PROVEN

### S14 — Repository -> Monitoring

OBSERVABILITY_HANDOFF=ARCHITECTURALLY_DEFINED
PHYSICAL_CONTRACT=NOT_PROVEN

## 11. Historical DEV layer naming correction

Historical DEV_LAYER_01..05 labels must be treated as lifecycle stages/controls, not as new ECTOS top-level architectural layers.

No new top-level layer is inferred from historical lifecycle naming.

## 12. Service-extension assembly model

Canonical future extension pattern:

```text
NEW SERVICE / PRODUCT
-> GOVERNED SERVICE NOTEBOOK / PROFILE
-> DEV-K000 generic service interface
-> DEV design contract
-> Builder API
-> Builder AI
-> generic build/package/evidence capabilities
-> specialized components only where required
-> technical validation
-> independent qualification
-> governance
```

Known intended pilots:

TPR=FIRST_SERVICE_PILOT
WEBMETHODS=SECOND_MAJOR_SPECIALIZED_CELL / PACKAGE-BUILDING SERVICE CONTEXT
FUTURE_SERVICES=EXTENSIBLE

Adding a specialized service must not require a new ECTOS DEV top-level plane.

## 13. Current physical evidence status

### Proven / source-backed documentary state

- DEV-K000 stabilized for current qualified cognitive scope.
- Development Center architecture defined.
- DEV-K000 + DEV-10 through DEV-80 mapped to current documentary baseline.
- DEV -> Builder AI contract documentary gate reported PASS.
- Builder 25-phase crosswalk 25/25, 18 direct, 7 derived, 0 unbound.
- Standardized service notebook template reported ready.
- Repository architecture/procedure frozen/defined.
- Builder AI is internal to ECTOS DEV.
- Tool Factory is internal ECTOS DEV qualification-tooling function.

### Not physically proven as built runtime/package set

- DEV-K000 executable package identity/SHA/source commit.
- exact package identity for CF-01..CF-06.
- exact package identity for EE-01..EE-02.
- exact package identity for PA-01..PA-02.
- exact package identity for EV-01..EV-03.
- exact package identity for QH-01..QH-02.
- Builder API executable package / endpoint.
- Builder AI executable package/runtime identity.
- final DEV runtime host/environment binding.
- current exact Tool Factory admitted tool set.
- current independent qualifier binding.
- physical Git/Supabase repository implementation.
- current literal schemas for all S01..S14 seams.

Reason: the recovered program state explicitly kept ECTOS DEV physical build behind readiness/tooling/governance gates. Documentary architecture closure is not physical build proof.

## 14. Pre-build cartography verdict

DEV_LOGICAL_ARCHITECTURE=CLOSED_FOR_CURRENT_DOCUMENTARY_SCOPE
DEV_COGNITIVE_ARCHITECTURE=CLOSED_FOR_CURRENT_QUALIFIED_SCOPE
DEV_SERVICE_EXTENSION_MODEL=DEFINED
DEV_ASSEMBLY_SEQUENCE=DEFINED
DEV_BUILDER_PHASE_CROSSWALK=25_OF_25
DEV_PHYSICAL_PACKAGE_CARTOGRAPHY=NOT_COMPLETE_BECAUSE_TARGET_PACKAGES_NOT_YET_BUILT/PROVEN
DEV_LITERAL_SEAM_CONTRACT_CARTOGRAPHY=PARTIAL_NOT_PROVEN
DEV_BUILD_READY=NO
DEV_ASSEMBLY_READY=NO
DEV_GUI_INTEGRATION_READY=NO

## 15. Required next closure before physical build authority

The next pre-build closure must freeze the complete DEV construction matrix with one row per target block/component containing:

- TARGET_ID
- FAMILY
- REUSE_ADAPT_BUILD_NEW
- BASE_OS_OR_DEV_ASSET
- REQUIRED_INPUT_CONTRACT
- REQUIRED_OUTPUT_CONTRACT
- UPSTREAM_NODE
- DOWNSTREAM_NODE
- RUNTIME_OVERLAY
- TOOLCHAIN
- QUALIFICATION_PROFILE
- NEGATIVE_CONTROL_SET
- EXPECTED_PACKAGE_ID
- EXPECTED_MANIFEST
- EXPECTED_EVIDENCE_RECEIPT
- CURRENTNESS_REQUIREMENT

Then physical construction can produce the missing package/SHA/source identities without discovering basic integration contracts during assembly.

FINAL_STATE=PARTIAL_PHYSICAL_CARTOGRAPHY_WITH_EXACT_UNREACHABLE_SCOPE
