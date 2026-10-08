# ECTOS DEV — OS Reuse / Adapt / Build-New Matrix + Pre-Build Contract Freeze V01

PROJECT=ECTOS
PROJECT_CONTAINER=ECTOS-POC
AUTHORITY=ECTOS_MAIN_AUTHORITY
SUPERIOR_AUTHORITY=PROJECT_OWNER_YANICK
MODE=EVIDENCE_FIRST_DOCUMENTARY_DECISION_FREEZE
PHYSICAL_BUILD_AUTHORITY=NO
QUALIFICATION_EXECUTION_AUTHORITY=NO

## 0. Decision basis

This document closes the documentary decision requested by 04.OS.4 and freezes the pre-build contract position for ECTOS DEV.

Rules:

- no OS object is reusable merely because its function appears similar;
- CURRENTNESS, source identity, target contract compatibility, dependencies and qualification requirements remain binding;
- REUSE_AS_IS requires exact target compatibility and current trust evidence;
- ADAPT_VERSIONED_SUCCESSOR means the existing object/family is a valid engineering ancestor, but direct byte reuse is not authorized;
- DOCUMENTARY_ONLY means patterns, qualification lessons or architecture may be reused, but not the runtime object as a DEV implementation;
- BLOCKED_NOT_PROVEN means no direct DEV reuse decision can be promoted from the available evidence;
- BUILD_NEW means the DEV target must be implemented as a new generic DEV capability under the frozen architecture.

Owner objective preserved:

ECTOS DEV is the governed Development Brain / Development Center. Builder AI is internal to DEV and generic/profile-driven. TPR, WebMethods, Agent, Engine, Tool, Generic App/Service and future services extend DEV through governed service contracts rather than by modifying the generic core for each service.

## 1. Exact OS object reuse/adapt matrix

| # | OS object | SHA256 | Proven OS role | DEV candidate use | Governance decision | Direct byte reuse | Required proof before any implementation use |
|---|---|---|---|---|---|---|---|
| 1 | ECTOS.G00.DownstreamDispatcher.Candidate.V06 | EF9B4A20583E5C6CBC6FE47FC38E5450790AD266ACFCD7693EA056606838E63B | target-agnostic downstream routing/control | generic DEV request/profile routing and dispatch pattern | ADAPT_VERSIONED_SUCCESSOR | NO | current source/package identity; DEV route contract; profile registry contract; unknown/ambiguous target fail-closed; no hard-coded service routing; independent qualification |
| 2 | ECTOS.G00.psm1 | 578FC878156EB7FC3ACD608781954EFD1A6DF98F23046B60180BE57D2086F37E | governed G00 routing baseline | historical routing implementation reference | DOCUMENTARY_ONLY | NO | authoritative current source-parent arbitration would be required before any byte reuse; no independent DEV need justifies parallel G00 baseline implementation |
| 3 | ECTOS.COMPLETE_SIX_LAYER_CORE.FINAL_OPERATOR.OPTION_B_ORCHESTRATION.V04 | 427117829510BDB541040F1F4BC60AF282FC596F7FA3BB88BC6566CCDE75A17B | ordered six-layer runtime orchestration | orchestration/fail-closed/evidence pattern for DEV lifecycle | DOCUMENTARY_ONLY | NO | DEV lifecycle semantics differ from OS six-layer runtime semantics; use only orchestration invariants/negative-control lessons unless a separate adaptation contract is approved |
| 4 | ECTOS.L01.STRUCTURATION_FACADE.V03 | E33D73C2FCB2FD80C773B778C34EE5224F06451AE611C6441FA2C6F0F12F66B0 | stable structuration boundary | stable facade/interface pattern | DOCUMENTARY_ONLY | NO | DEV interface contract must be defined independently; OS business semantics must not be relocated into DEV core |
| 5 | TaxonomyClassifier.psm1 | FA9D0C3261A61D298B738B21CC9D9C9531B7E4CC8687A14D37FFA465F5683987 | taxonomy/structuration component | possible specialized classification capability | BLOCKED_NOT_PROVEN | NO | exact DEV target requirement, service boundary, I/O contract, currentness, standalone qualification and no core contamination |
| 6 | ECTOS.L02.INTELLIGENCE_FACADE.V01 | D2DD145F8893B4E4D8FBD73B7FA08024B3F3AF771A3718FA28888FF1EFC60C88 | stable intelligence boundary | stable facade/interface pattern | DOCUMENTARY_ONLY | NO | DEV Master Brain/service boundaries are separate architecture; only facade pattern may be reused |
| 7 | ClassificationEngine.psm1 | 8202A6D7A636F1B4D967388734CB5487CFF4C439E256829A40CB4B5F95262D0E | classification engine | possible specialized DEV service capability | BLOCKED_NOT_PROVEN | NO | exact DEV use case, input/output schema, runtime/dependencies, currentness, standalone qualification, service-local containment |
| 8 | ECTOS.L03.CONSTRUCTION_FACADE.V01 | 072494B78BD47E6676824ECD6B6B78ACE9956A483B2B636ECF7B7A02A73041D9 | stable construction boundary | construction facade/interface pattern | DOCUMENTARY_ONLY | NO | Builder API/Builder AI contract is a new DEV contract; OS facade bytes are not a substitute |
| 9 | WpdfArtifactGenerator.psm1 | 8621A148C721A83BD171EC4569A312F78196319276492E78F67520DC54DB4A5E | artifact generator | possible specialized artifact-generation capability | BLOCKED_NOT_PROVEN | NO | generic-vs-WPDF scope, target artifact contract, currentness, dependencies and standalone qualification must be proven |
| 10 | ECTOS.L04.BUSINESS_FACADE.V02 | 94F5E93A5CDF1EC463EAE32021DA74DC3DCF780B15D0F1945535C6062ABD99B8 | stable business boundary | facade/interface architecture pattern | DOCUMENTARY_ONLY | NO | DEV service interface must remain generic/profile-driven; no OS business-specific contract may enter DEV core implicitly |
| 11 | ECTOS.L04.BusinessRequestHandler.V01.psm1 | 59A543EEA46FE8CD26154D51F6003037211519636A44FCFE6ADA0D9A9C2C5C90 | OS business request handling | possible product/service-local handling only | BLOCKED_NOT_PROVEN | NO | no generic DEV-core use proven; service-specific reuse would require explicit service notebook/profile contract and independent qualification |
| 12 | ECTOS.L05.CONTINUITY_FACADE.V01 | 57B0C9BD74755A5F0CC1218DBA69CC39FC1E3C58FFE2C26509289EB7A0C689C4 | stable continuity boundary | facade/interface architecture pattern | DOCUMENTARY_ONLY | NO | DEV currentness/repository contracts are separate; reuse only boundary pattern unless target compatibility is proven |
| 13 | IDBankService.psm1 | 901D4683DE2A5E79A240563CDE75682425C188484675FD4E5DE4A9FFE4BA73F0 | identity-bank collision/preflight service | Repository/identity collision-preflight capability | ADAPT_VERSIONED_SUCCESSOR | NO | canonical source/currentness, generic DEV identity contract, repository/RIM binding, null/empty/single/many, collision negatives, independent qualification |

### Matrix closure

REUSE_AS_IS_COUNT=0
ADAPT_VERSIONED_SUCCESSOR_COUNT=2
DOCUMENTARY_ONLY_COUNT=6
BLOCKED_NOT_PROVEN_COUNT=5

DIRECT_OS_RUNTIME_BYTE_REUSE_AUTHORIZED=0

This is intentional. ECTOS DEV is not an OS clone.

## 2. OS family-level lessons admitted into DEV planning

The reusable unit is often the proven engineering family/pattern, not the exact OS runtime module.

### 2.1 Routing/control

OS_REFERENCE=QFAM-ROUTING-CONTROL-V01
DEV_DECISION=ADAPT
DEV_TARGET=generic profile-driven request/target routing
MANDATORY_INVARIANTS=
- deterministic target resolution;
- unknown/ambiguous target fail-closed;
- no target/package hard-coding in generic routing core;
- authority/evidence propagation;
- timeout and downstream-unavailable semantics;
- adding a registered service/profile must not require generic engine changes.

### 2.2 Orchestration/control

OS_REFERENCE=QFAM-ORCHESTRATION-CONTROL-V01
DEV_DECISION=ADAPT_PATTERN_NOT_BYTES
DEV_TARGET=generic DEV lifecycle orchestration
MANDATORY_INVARIANTS=
- declared stage graph;
- stop-on-failure;
- no silent skip/retry;
- timeout/cancel behavior;
- evidence aggregation;
- authority replay protection;
- partial execution must never produce false PASS.

### 2.3 Runtime facade pattern

OS_REFERENCE=QFAM-RUNTIME-FACADE-V01
DEV_DECISION=ADAPT_PATTERN
DEV_TARGET=stable boundaries between Brain, Service Knowledge, Builder API, Builder AI, Tool Factory, Evidence, Qualification and Governance
DIRECT_OS_FACADE_BYTE_REUSE=NO

### 2.4 Core component qualification

OS_REFERENCE=QFAM-CORE-COMPONENT-ENGINE-V01
DEV_DECISION=BUILD_NEW_GENERIC_QUALIFICATION_CONTRACT
REASON=standalone generic component qualification was not proven as a reusable current instrument.

### 2.5 Cross-boundary handoff qualification

OS_REFERENCE=QFAM-CROSS-LAYER-HANDOFF-V01
DEV_DECISION=BUILD_NEW_GENERIC_EDGE_QUALIFIER
REASON=historical OS 5/5 integrated handoffs prove the need for explicit seam qualification but do not provide a current generic DEV edge qualifier.

### 2.6 Runtime carrier/materialization

OS_REFERENCE=QFAM-RUNTIME-CARRIER-MATERIALIZATION-V01
DEV_DECISION=BUILD_NEW_GENERIC_CURRENT_QUALIFIER_WITH_REUSED_LESSONS
REASON=historical materialization evidence exists, but current generic family qualification trust is not proven.

## 3. DEV pre-build node decision matrix

The following decisions freeze what DEV must do before physical implementation.

| DEV node | Required role | Reuse decision | Primary evidence/input | Pre-build state |
|---|---|---|---|---|
| DEV-K000 Master Brain | architecture/engineering intelligence | INTEGRATE_EXISTING_CAPABILITY | stabilized cognitive baseline; current DEV architecture | COGNITIVE_SCOPE_AVAILABLE; physical runtime package NOT_PROVEN |
| Service Knowledge Layer | bounded specialization | INTEGRATE_EXISTING_CAPABILITY | standardized service-notebook model; TPR/WebMethods/deferred service work | TEMPLATE/CONTRACT MODEL AVAILABLE; operationalization later |
| CF-01 Knowledge & Currentness Reconciliation | reconcile knowledge/currentness before change | BUILD_NEW around existing Repository/currentness contracts | Repository/currentness architecture + OS lessons | CONTRACT_FREEZE_REQUIRED |
| CF-02 Design Contract & Runtime Adaptation | transform target into design contract | BUILD_NEW | DEV architecture | CONTRACT_FREEZE_REQUIRED |
| CF-03 Cartography & Dependency Intelligence | resolve dependency graph and open edges | BUILD_NEW using current cartography methodology | OS/DEV cartography + Dependency Graph methodology | DOCUMENTARY MODEL AVAILABLE; executable component NOT_PROVEN |
| CF-04 Change Impact Engineering Gate | transitive impact/systemic-local classification | BUILD_NEW using governed failure-learning rules | engineering learning/systemic review rules | CONTRACT_FREEZE_REQUIRED |
| CF-05 Toolchain, Host & Runtime Control | bind exact toolchain/runtime/host | ADAPT existing engineering/materialization controls | PS5.1/code-rule/tooling evidence | CURRENT QUALIFIER/TRUST BINDING STILL GATED |
| CF-06 Currentization & Version Successor Control | lineage/currentness/successor | BUILD_NEW/INTEGRATE Repository currentness capability | currentness model + Repository/RIM design | PHYSICAL RIM/BINDING PARTIAL |
| Builder API | governed machine interface | BUILD_NEW | accepted documentary Builder contract | LITERAL MACHINE SCHEMA NOT_YET_PHYSICALLY_PROVEN |
| Builder AI | generic profile-driven construction orchestrator | BUILD_NEW | 25-phase Builder crosswalk; profile model | PHYSICAL IMPLEMENTATION NOT_PROVEN |
| EE-01 Controlled Workspace Build | deterministic governed build | ADAPT engineering workspace/materialization lessons | current SWBI/materialization family after systemic closure | BLOCKED_BY_CURRENT_SYSTEMIC_03_2_FOR_RELEVANT_BYTE_IDENTITY_COMPONENTS |
| EE-02 Validation, Regression & Fail-Closed Testing | pre-QF technical validation | ADAPT proven qualification patterns/tooling | Factory/tooling catalog and family requirements | TRUSTED_CURRENT_TOOLSET PARTIAL/OPEN |
| PA-01 Package Assembly | deterministic package assembly | BUILD_NEW generic DEV packaging function | package lifecycle architecture | TARGET PACKAGE CONTRACT REQUIRED |
| PA-02 Manifest, Identity & SHA256 Control | exact member/hash identity | ADAPT existing package/hash controls | OS/package qualification lessons + SWBI family | CURRENT MATERIALIZATION/IDENTITY CLOSURE REQUIRED |
| EV-01 Evidence & Causal Attribution | evidence + causal attribution | BUILD_NEW/INTEGRATE existing evidence patterns | evidence architecture + historical controls | EXACT STORAGE/HANDOFF INTERFACE PARTIAL |
| EV-02 Reconstructibility, Recovery, Replay & Rollback | reconstruct/replay/rollback | BUILD_NEW using historical lessons | materialization/package lifecycle | CONTRACT REQUIRED BEFORE BUILD |
| EV-03 Monitoring Support Handoff | telemetry/correlation handoff | BUILD_NEW | Monitoring interface architecture | LITERAL CONTRACT NOT_PROVEN |
| QH-01 Independent Qualification Handoff | freeze candidate + qualification handoff | ADAPT control-plane/handoff lessons | UAC/canonical-handoff family | BLOCKED_BY_CURRENT_SYSTEMIC_CONTROL_PLANE/QUALIFIER_STATE WHERE APPLICABLE |
| QH-02 Release Candidate Governance Handoff | Main admission/release dossier | BUILD_NEW/ADAPT governance handoff pattern | Governance + evidence model | RELEASE CONTRACT MUST REMAIN SEPARATE FROM QF |

## 4. Pre-build contract freeze

No DEV implementation node becomes build-eligible until the following contract fields are explicit for that node.

MANDATORY_NODE_CONTRACT=
- TARGET_ID
- ROLE
- PREVIOUS_NODE
- NEXT_NODE
- ENTRYPOINT
- EXITPOINT
- INPUT_CONTRACT
- OUTPUT_CONTRACT
- ERROR_CONTRACT
- TIMEOUT_CONTRACT
- AUTHORITY_CONTEXT
- EVIDENCE_CONTEXT
- UPSTREAM_DEPENDENCIES
- DOWNSTREAM_CONSUMERS
- RUNTIME
- HOST_OS
- TOOLCHAIN
- REUSE_CLASS
- SOURCE_OR_ANCESTOR_ASSET
- PHYSICAL_TARGET_PACKAGE
- QUALIFICATION_FAMILY
- NEGATIVE_CONTROL_SET
- ROLLBACK_RECOVERY_REPLAY
- CURRENTNESS_REQUIREMENT
- MAIN_ACCEPTANCE_GATE

A field that is not physically/source-backed must remain NOT_PROVEN; it must not be filled from analogy with ECTOS OS.

## 5. Frozen cross-component seams

The following seams are mandatory assembly objects, not implicit implementation details.

### S01 Governance -> DEV-K000

PURPOSE=authorized development request / policy / constraints
SOURCE=ECTOS MAIN/Governance
DESTINATION=DEV-K000
LITERAL_PAYLOAD_SCHEMA=NOT_PROVEN
BUILD_RULE=must be explicit before DEV runtime implementation

### S02 DEV-K000 <-> Service Knowledge Layer

PURPOSE=bounded specialization lookup/response
EXTENSION_INVARIANT=adding a registered service/notebook must not require hard-coded service routing in DEV-K000
KNOWN_PROFILES=TPR|WEBMETHODS|AGENT|ENGINE|TOOL|GENERIC_APP_SERVICE|FUTURE
LITERAL_PAYLOAD_SCHEMA=PARTIAL/NOT_PROVEN

### S03 DEV-K000 -> Builder API

PURPOSE=design/build/package/evidence contract handoff
ARCHITECTURE_STATE=ACCEPTED_DOCUMENTARY
LITERAL_MACHINE_SCHEMA=NOT_PROVEN
BUILDER_ARCHITECTURE_AUTHORITY=NO; Builder executes, does not redefine architecture

### S04 Builder API -> Builder AI

PURPOSE=governed machine-to-machine construction command
PROFILE_DRIVEN=YES
GENERIC_CORE_HARDCODED_SERVICE_ROUTING=PROHIBITED
LITERAL_MACHINE_SCHEMA=NOT_PROVEN

### S05 Builder AI -> EE-01

PURPOSE=controlled workspace build recipe/materialization
REQUIRES=exact source identity + runtime/host/toolchain + byte-identity contract
CURRENT_RELEVANT_SYSTEMIC_GAP=SWBI/materialization family under circuit-breaker review

### S06 EE-01 -> PA-01

PURPOSE=build outputs to deterministic package assembly
OUTPUT_MEMBER_SET_MUST_BE_DECLARED=YES
SILENT_MEMBER_SUBSTITUTION=PROHIBITED

### S07 PA-01 -> PA-02

PURPOSE=package bytes to manifest/member/SHA closure
PACKAGE_PRESENT_NE_PACKAGE_QUALIFIED=YES

### S08 PA-02 -> EE-02 / Tool Factory

PURPOSE=exact candidate identity into technical validation
QUALIFICATION_INDEPENDENCE=Tool Factory result is not independent qualification

### S09 Tool Factory -> EV-01

PURPOSE=technical results/fixtures/traces to evidence record
CAUSAL_ATTRIBUTION_REQUIRED=YES

### S10 EV-01 -> EV-02

PURPOSE=evidence into reconstructibility/recovery/replay/rollback record
REPLAY_MUST_BIND_TO_EXACT_IDENTITY=YES

### S11 EV-01/EV-02 -> QH-01

PURPOSE=freeze qualification target and evidence dossier
QUALIFIER_ROLE_MUST_BE_INDEPENDENT=YES

### S12 QH-01 -> Independent Qualification

PURPOSE=independent PASS/FAIL execution
PRODUCER_NE_QUALIFIER=YES
SELF_QUALIFICATION=PROHIBITED

### S13 Independent Qualification -> QH-02

PURPOSE=qualification verdict + evidence to release-candidate governance dossier
QUALIFICATION_NE_RELEASE=YES

### S14 QH-02 -> MAIN/Governance

PURPOSE=admission/promotion/release decision request
MAIN_DECISION_REQUIRED=YES
AGENT_RETURN_NE_MAIN_ACCEPTANCE=YES

## 6. Build-order freeze

The architecture defines the dependency order. Physical implementation may be grouped into versioned increments, but must preserve this dependency graph.

```text
CONTROL FOUNDATION
DEV-K000 + currentness/repository bindings
        |
        v
CF-01 -> CF-02 -> CF-03 -> CF-04 -> CF-05 -> CF-06
        |
        v
SERVICE CONTRACT / PROFILE REGISTRY
        |
        v
BUILDER API
        |
        v
BUILDER AI
        |
        v
EE-01
        |
        v
PA-01 -> PA-02
        |
        v
EE-02 / TOOL FACTORY
        |
        v
EV-01 -> EV-02 -> EV-03
        |
        v
QH-01 -> INDEPENDENT QUALIFICATION -> QH-02
        |
        v
MAIN / GOVERNANCE
```

The 25-phase Builder crosswalk is accepted as documentary architecture with 25/25 phases bound; it does not itself prove physical Builder implementation.

## 7. Current blockers carried forward

BLOCKER_01=ECTOS-METHODOLOGY-03.2 systemic workspace-byte-identity family remains under triggered circuit breaker; EE-01/PA-02 implementations that depend on this family cannot be promoted from unresolved tooling.

BLOCKER_02=current trusted DEV qualification toolset currentness/trust/lineage remains partial/open; EE-02/QH-01 cannot claim execution readiness from historical tooling presence alone.

BLOCKER_03=physical Repository/RIM/current-pointer/evidence-store bindings remain partial/not fully proven for DEV runtime implementation.

BLOCKER_04=Builder API literal machine schema and physical Builder AI package/entrypoint are not yet proven because physical DEV build has not occurred.

BLOCKER_05=UAC/canonical-handoff systemic control-plane lineage must be current and independently qualified before QH-01/QH-02 use is promoted.

## 8. Decision end state

OS_OBJECT_ROWS_DECIDED=13_OF_13
REUSE_AS_IS_COUNT=0
ADAPT_VERSIONED_SUCCESSOR_COUNT=2
DOCUMENTARY_ONLY_COUNT=6
BLOCKED_NOT_PROVEN_COUNT=5

DEV_NODE_DECISION_MATRIX=COMPLETE_FOR_CURRENT_DOCUMENTARY_SCOPE
PREBUILD_CONTRACT_FIELD_SET=FROZEN
CROSS_COMPONENT_SEAM_SET=14
BUILD_ORDER=FROZEN_FOR_DOCUMENTARY_DEPENDENCY_SCOPE

OBJECTIVE_MATCH=PASS_FOR_DOCUMENTARY_ARCHITECTURE_SCOPE
ARCHITECTURAL_INTENT_MATCH=PASS_FOR_DOCUMENTARY_ARCHITECTURE_SCOPE
INVARIANT_MATCH=PASS_FOR_DOCUMENTARY_ARCHITECTURE_SCOPE
CONSTRAINT_RELOCATION=NO_KNOWN_FOR_DOCUMENTARY_DECISION_SCOPE
ARCHITECTURAL_SUBSTITUTION=NO_KNOWN_FOR_DOCUMENTARY_DECISION_SCOPE

PHYSICAL_DEV_BUILD_AUTHORITY=NO
NEXT_EXECUTION_AUTHORITY_ELIGIBLE=NO

FINAL_STATE=DECISION_MATRIX_CLOSED_WITH_EXPLICIT_BUILD_BLOCKERS
