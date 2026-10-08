# ECTOS DEV — Builder / Package / Validation Contract Closure V01

PROJECT=ECTOS
PROJECT_CONTAINER=ECTOS-POC
AUTHORITY=ECTOS_MAIN_AUTHORITY
SUPERIOR_AUTHORITY=PROJECT_OWNER_YANICK
MODE=EVIDENCE_FIRST_DOCUMENTARY_CONTRACT_CLOSURE
PHYSICAL_BUILD_AUTHORITY=NO
QUALIFICATION_EXECUTION_AUTHORITY=NO

## 0. Scope

This document closes the second pre-build contract segment of ECTOS DEV.

SCOPE_CHAIN=
Builder API -> Builder AI -> EE-01 -> PA-01 -> PA-02 -> EE-02 -> Tool Factory / EPT

This is a documentary architecture/contract closure only. Literal runtime schemas, final physical entrypoints, final package identities and final source commits remain NOT_PROVEN until the corresponding build authority exists.

## 1. Builder API

TARGET_ID=BUILDER_API
CLASS=GOVERNED_MACHINE_INTERFACE
PURPOSE=transmit governed DEV design contracts, build recipes, toolchain contracts and package contracts to Builder AI.

UPSTREAM=CF-06
DOWNSTREAM=BUILDER_AI
UI_REQUIRED=NO
INTERFACE_MODE=MACHINE_TO_MACHINE

INPUT_CONTRACT_SEMANTIC=VERSIONED_BUILD_AUTHORIZATION_CANDIDATE_CONTRACT

REQUIRED_INPUT_FIELDS=
- target/product profile;
- design contract;
- build recipe;
- dependency/assembly graph reference;
- reuse/adapt/build-new decisions;
- toolchain/host/runtime contract;
- package contract;
- version/successor context;
- evidence/authority/correlation context;
- explicit NOT_PROVEN blockers.

OUTPUT_CONTRACT_SEMANTIC=BUILDER_AI_GOVERNED_BUILD_REQUEST

LITERAL_INPUT_SCHEMA=NOT_PROVEN
LITERAL_OUTPUT_SCHEMA=NOT_PROVEN
PHYSICAL_ENTRYPOINT=NOT_PROVEN_FOR_FINAL_DEV_RUNTIME
TARGET_PACKAGE=NOT_YET_BUILT

NEGATIVE_CONTROLS_REQUIRED=
- missing design contract;
- missing package contract;
- unknown product/profile;
- stale build recipe;
- missing authority/evidence context;
- unresolved mandatory blocker silently ignored;
- service-specific logic hard-coded into generic API.

MAIN_GATE=NO_BUILDER_AI_REQUEST_WITHOUT_COMPLETE_GOVERNED_MACHINE_CONTRACT

## 2. Builder AI

TARGET_ID=BUILDER_AI
CLASS=GENERIC_CONSTRUCTION_ORCHESTRATOR_INTERNAL_TO_ECTOS_DEV
PURPOSE=turn the governed ECTOS DEV solution model into deterministic build/package candidates.

UPSTREAM=BUILDER_API
DOWNSTREAM=EE-01
TOP_LEVEL_PLANE=NO
GENERIC_PROFILE_DRIVEN=YES

KNOWN_PROFILE_SET=
- TPR
- WEBMETHODS
- AGENT
- ENGINE
- TOOL
- GENERIC_APP_SERVICE
- FUTURE_REGISTERED_SERVICE

INPUT_CONTRACT_SEMANTIC=BUILDER_AI_GOVERNED_BUILD_REQUEST

REQUIRED_INPUT_FIELDS=
- registered profile identity or generic target class;
- complete design/build/package/toolchain contract set;
- source/reuse inputs;
- dependency graph;
- authorized version/delta scope;
- qualification/evidence expectations.

OUTPUT_CONTRACT_SEMANTIC=CONTROLLED_BUILD_PLAN

REQUIRED_OUTPUT_FIELDS=
- exact source/reuse plan;
- ordered build steps;
- workspace requirements;
- expected build outputs;
- package assembly inputs;
- deterministic identity requirements;
- evidence hooks;
- unresolved blockers.

LITERAL_INPUT_SCHEMA=NOT_PROVEN
LITERAL_OUTPUT_SCHEMA=NOT_PROVEN
PHYSICAL_ENTRYPOINT=NOT_PROVEN_FOR_FINAL_DEV_RUNTIME
TARGET_PACKAGE=NOT_YET_BUILT

ARCHITECTURAL_INVARIANTS=
- search-before-build;
- reuse-before-build-new;
- generic core remains generic;
- adding a registered profile must not require generic Builder core changes unless Governance authorizes a versioned architectural change;
- DEV self-qualification prohibited;
- BUILD != QUALIFICATION != RELEASE.

NEGATIVE_CONTROLS_REQUIRED=
- unknown profile silently mapped;
- profile-name hard-coding in generic core;
- direct build without search/reuse decision;
- unauthorized source substitution;
- hidden downstream package composition;
- Builder self-qualifies its output.

MAIN_GATE=BUILDER_PLAN_COMPLETE_BEFORE_CONTROLLED_WORKSPACE_BUILD

## 3. EE-01 — Controlled Workspace Build

TARGET_ID=EE-01
CANONICAL_NAME=CONTROLLED_WORKSPACE_BUILD
PURPOSE=execute construction from exact sources inside a governed workspace.

UPSTREAM=BUILDER_AI
DOWNSTREAM=PA-01

INPUT_CONTRACT_SEMANTIC=CONTROLLED_BUILD_PLAN

REQUIRED_INPUT_FIELDS=
- exact source identities;
- target workspace identity;
- toolchain/host/runtime binding;
- working directory;
- build commands/process contract;
- timeout/exit/stdout/stderr requirements;
- expected outputs;
- evidence collection requirements.

OUTPUT_CONTRACT_SEMANTIC=CONTROLLED_BUILD_OUTPUT_SET

REQUIRED_OUTPUT_FIELDS=
- build output inventory;
- source-to-output traceability;
- process exit status;
- stdout/stderr capture references;
- timeout state;
- created file identities;
- workspace state evidence;
- failure state if any.

LITERAL_INPUT_SCHEMA=NOT_PROVEN
LITERAL_OUTPUT_SCHEMA=NOT_PROVEN
TARGET_PACKAGE=NOT_YET_BUILT

NEGATIVE_CONTROLS_REQUIRED=
- source mismatch;
- dirty/unbound workspace where cleanliness is required;
- wrong runtime/host;
- missing dependency/path;
- timeout;
- non-zero process exit;
- unexpected output;
- unauthorized global mutation;
- output generated from substituted source.

QUALIFICATION_FAMILY=DEV_QFAM_CONTROLLED_BUILD_V01
MAIN_GATE=BUILD_OUTPUT_SET_REQUIRED_BEFORE_PACKAGE_ASSEMBLY

## 4. PA-01 — Package Assembly

TARGET_ID=PA-01
CANONICAL_NAME=PACKAGE_ASSEMBLY
PURPOSE=materialize the deterministic package from controlled build outputs.

UPSTREAM=EE-01
DOWNSTREAM=PA-02

INPUT_CONTRACT_SEMANTIC=CONTROLLED_BUILD_OUTPUT_SET + PACKAGE_CONTRACT

REQUIRED_INPUT_FIELDS=
- approved member set;
- member source/output identities;
- package layout/path model;
- inclusion/exclusion rules;
- package version identity model;
- expected entrypoint(s);
- required documentation/manifest placeholders where applicable.

OUTPUT_CONTRACT_SEMANTIC=ASSEMBLED_PACKAGE_CANDIDATE

REQUIRED_OUTPUT_FIELDS=
- package artifact;
- deterministic member inventory;
- member paths;
- size/state metadata;
- package construction evidence;
- no hidden/undeclared members.

LITERAL_INPUT_SCHEMA=NOT_PROVEN
LITERAL_OUTPUT_SCHEMA=NOT_PROVEN
PACKAGE_FORMAT=TARGET_SPECIFIC_NOT_PROVEN_UNTIL_BUILD_CONTRACT

NEGATIVE_CONTROLS_REQUIRED=
- missing member;
- extra member;
- duplicate member;
- wrong path;
- wrong version identity;
- stale build output included;
- hidden generated content;
- package order/metadata affecting determinism without governed normalization.

QUALIFICATION_FAMILY=DEV_QFAM_PACKAGE_ASSEMBLY_V01
MAIN_GATE=PACKAGE_MEMBER_SET_CLOSED_BEFORE_IDENTITY_SHA_CONTROL

## 5. PA-02 — Manifest, Identity & SHA256 Control

TARGET_ID=PA-02
CANONICAL_NAME=MANIFEST_IDENTITY_SHA_CONTROL
PURPOSE=produce the package manifest/member inventory/hashes and bind exact package identity.

UPSTREAM=PA-01
DOWNSTREAM=EE-02

INPUT_CONTRACT_SEMANTIC=ASSEMBLED_PACKAGE_CANDIDATE

REQUIRED_INPUT_FIELDS=
- package artifact;
- declared package identity/version;
- member inventory;
- expected member identities;
- manifest schema/profile.

OUTPUT_CONTRACT_SEMANTIC=IDENTITY_BOUND_PACKAGE_CANDIDATE

REQUIRED_OUTPUT_FIELDS=
- package SHA256;
- manifest;
- member inventory;
- member SHA256 set where required;
- size/member-count evidence;
- manifest/package closure result;
- exact identity mismatch result if any.

LITERAL_MANIFEST_SCHEMA=NOT_PROVEN_FOR_FINAL_DEV_PACKAGE_FAMILY
TARGET_PACKAGE=THE_BUILD_TARGET_PACKAGE_CANDIDATE

NEGATIVE_CONTROLS_REQUIRED=
- manifest missing member;
- manifest extra member;
- hash mismatch;
- package name/version mismatch;
- normalized/reconstructed hash substituted for physical bytes;
- member path collision;
- duplicate identity;
- stale manifest reused.

QUALIFICATION_FAMILY=DEV_QFAM_PACKAGE_IDENTITY_V01
MAIN_GATE=IDENTITY_SHA_CLOSURE_REQUIRED_BEFORE_PREQUALIFICATION_VALIDATION

## 6. EE-02 — Validation, Regression & Fail-Closed Testing

TARGET_ID=EE-02
CANONICAL_NAME=VALIDATION_REGRESSION_FAIL_CLOSED
PURPOSE=execute validation and regression controls in fail-closed mode before independent qualification.

UPSTREAM=PA-02
DOWNSTREAM=TOOL_FACTORY_EPT

INPUT_CONTRACT_SEMANTIC=IDENTITY_BOUND_PACKAGE_CANDIDATE + VALIDATION_PROFILE

REQUIRED_INPUT_FIELDS=
- exact package identity/SHA;
- qualification/validation family profile;
- runtime/host/toolchain requirements;
- dependency/interface contracts;
- negative-control manifest;
- expected evidence set.

OUTPUT_CONTRACT_SEMANTIC=PREQUALIFICATION_VALIDATION_EVIDENCE_SET

REQUIRED_OUTPUT_FIELDS=
- positive control results;
- negative control results;
- parser/load/import/startability where applicable;
- runtime/process results;
- interface/seam results;
- regression results;
- fail-closed result;
- complete known defect set if failing;
- exact evidence references.

LITERAL_INPUT_SCHEMA=NOT_PROVEN
LITERAL_OUTPUT_SCHEMA=NOT_PROVEN

NEGATIVE_CONTROLS_REQUIRED=
- positive-path-only PASS;
- missing mandatory negative test;
- failure treated as warning;
- partial evidence promoted to PASS;
- stale profile;
- wrong runtime;
- package identity drift;
- seam/contract bypass.

QUALIFICATION_FAMILY=DEV_QFAM_PREQUAL_VALIDATION_V01
MAIN_GATE=NO_INDEPENDENT_QUALIFICATION_HANDOFF_WITHOUT_FAIL_CLOSED_PREVALIDATION

## 7. EE-02 -> Tool Factory / EPT seam

EDGE_ID=DEV_EDGE_EE02_TOOL_FACTORY_EPT_V01
SOURCE=EE-02
DESTINATION=TOOL_FACTORY_EPT

OUTBOUND_CONTRACT=PREQUALIFICATION_VALIDATION_EVIDENCE_SET
INBOUND_CONTRACT=GOVERNED_QUALIFICATION_TOOLING_REQUEST

REQUIRED_SEMANTIC_PAYLOAD=
- exact target/package identity;
- requested qualification family/profile;
- required runtime/host;
- declared contracts/interfaces;
- negative-control manifest;
- prevalidation evidence;
- authority context;
- explicit NOT_PROVEN blockers.

LITERAL_SERIALIZED_SCHEMA=NOT_PROVEN
PHYSICAL_ROUTE=NOT_PROVEN_FOR_FINAL_DEV_RUNTIME
PHYSICAL_ENTRYPOINT=NOT_PROVEN_FOR_FINAL_TOOL_FACTORY_RUNTIME

BOUNDARY_QUALIFICATION_REQUIRED=YES

MANDATORY_NEGATIVES=
- untrusted qualifier/tool selected;
- no execution-eligible route;
- stale profile;
- package SHA mismatch;
- qualification tool self-admits target;
- missing evidence;
- DEV/Builder treated as independent qualifier.

## 8. Closure state

DOCUMENTARY_NODE_ORDER=PROVEN
BUILDER_API_MACHINE_INTERFACE_ROLE=SOURCE_BACKED
BUILDER_AI_GENERIC_PROFILE_DRIVEN_ROLE=SOURCE_BACKED
EE01_ROLE=SOURCE_BACKED
PA01_ROLE=SOURCE_BACKED
PA02_ROLE=SOURCE_BACKED
EE02_ROLE=SOURCE_BACKED

SEMANTIC_INPUT_OUTPUT_OBLIGATIONS=FROZEN_BY_MAIN_FROM_SOURCE_BACKED_RESPONSIBILITIES
LITERAL_MACHINE_SCHEMAS=NOT_PROVEN
FINAL_RUNTIME_ENTRYPOINTS=NOT_PROVEN
FINAL_TARGET_PACKAGE_IDENTITIES=NOT_YET_BUILT

CONTRACT_CLOSURE_STATE=PARTIAL_WITH_EXACT_PHYSICAL_BOUNDARIES

NEXT_REQUIRED_CONTRACT_SEGMENT=
TOOL_FACTORY_EPT -> EV-01/EV-02/EV-03 -> QH-01 -> INDEPENDENT_QUALIFICATION -> QH-02 -> MAIN/GOVERNANCE

DEV_PHYSICAL_BUILD_AUTHORITY=NO
DEV_ASSEMBLY_AUTHORITY=NO
NEXT_EXECUTION_AUTHORITY_ELIGIBLE=NO
