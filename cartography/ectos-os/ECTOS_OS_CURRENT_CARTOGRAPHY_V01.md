# ECTOS OS — Current Cartography V01

PROJECT=ECTOS
SCOPE=ECTOS_OS_CURRENT_CARTOGRAPHY
MODE=EVIDENCE_FIRST_READ_ONLY_RECOVERY
STATE=PARTIAL_NOT_PROVEN

## Purpose

This file is the canonical Git working register for the current ECTOS OS cartography recovery. It records only physically/source-backed identities and explicit gaps. It does not infer current runtime membership from historical package presence.

## Accounting domains

The following populations are distinct and MUST NOT be conflated:

- HISTORICAL_DOCUMENTARY_ROOT_PACKAGE_BASELINE: 62 packages recovered from the DOC-F02/WILOW historical baseline.
- REPOSITORY_SERVICE_ENGINE_INVENTORY: 28 service-engine entries recovered as a distinct Repository accounting domain.
- RUNTIME_SEMANTIC_OBJECT_SET: 13 recovered ECTOS OS runtime/semantic objects with exact SHA256 identities.
- GOLDEN_ACCEPTED_CORE_REFERENCE: ECTOS_OS_V1_GOLDEN_BASELINE_01_PACKAGE_V01.zip, SHA256 E0B83E67866C3ACAE57E5C2B9856C67EC96F44EA145F0BA3B9F6DC6AD9BB938F.
- LAST_PROVEN_PRODUCTION_RUNTIME: ECTOS_V1_G00_TARGET_AGNOSTIC_SUCCESSOR_V02, source package ECTOS_G00_TARGET_AGNOSTIC_SUCCESSOR_V02.tar.gz, SHA256 1465c97d15d687b46732bfcd2229b8451dbc470d5255098477bc15f4b4c9ab65, Cloud Run service ectos-intake-api, revision ectos-intake-api-00029-hoj, image digest sha256:18b5d8c39b7a7283b429f29b819267ebc85307737a80c46a7c35293b92551281.
- QUALIFIED_SUCCESSOR_NOT_PROVEN_PRODUCTION: ECTOS_G00_GOVERNED_CONTEXT_SUCCESSOR_V10.zip, SHA256 0ABD3E0264DF930B9A5001F3E3C543D97740EF348EDF8F96A7C5E31C5ACE1BFE.

## Recovered runtime / semantic assembly objects

| # | Object | Class | SHA256 | Currentness |
|---|---|---|---|---|
| 01 | ECTOS.G00.DownstreamDispatcher.Candidate.V06 | ROUTING_CONTROL_MODULE | EF9B4A20583E5C6CBC6FE47FC38E5450790AD266ACFCD7693EA056606838E63B | PARTIAL_CURRENTNESS |
| 02 | ECTOS.COMPLETE_SIX_LAYER_CORE.FINAL_OPERATOR.OPTION_B_ORCHESTRATION.V04 | ORCHESTRATION_CONTROL | 427117829510BDB541040F1F4BC60AF282FC596F7FA3BB88BC6566CCDE75A17B | PARTIAL_CURRENTNESS |
| 03 | ECTOS.G00.psm1 | ROUTING_CONTROL_MODULE | 578FC878156EB7FC3ACD608781954EFD1A6DF98F23046B60180BE57D2086F37E | PARTIAL |
| 04 | ECTOS.L01.STRUCTURATION_FACADE.V03 | RUNTIME_FACADE_MODULE | E33D73C2FCB2FD80C773B778C34EE5224F06451AE611C6441FA2C6F0F12F66B0 | PARTIAL |
| 05 | ECTOS.L02.INTELLIGENCE_FACADE.V01 | RUNTIME_FACADE_MODULE | D2DD145F8893B4E4D8FBD73B7FA08024B3F3AF771A3718FA28888FF1EFC60C88 | PARTIAL |
| 06 | ECTOS.L03.CONSTRUCTION_FACADE.V01 | RUNTIME_FACADE_MODULE | 072494B78BD47E6676824ECD6B6B78ACE9956A483B2B636ECF7B7A02A73041D9 | PARTIAL |
| 07 | ECTOS.L04.BUSINESS_FACADE.V02 | RUNTIME_FACADE_MODULE | 94F5E93A5CDF1EC463EAE32021DA74DC3DCF780B15D0F1945535C6062ABD99B8 | PARTIAL |
| 08 | ECTOS.L05.CONTINUITY_FACADE.V01 | RUNTIME_FACADE_MODULE | 57B0C9BD74755A5F0CC1218DBA69CC39FC1E3C58FFE2C26509289EB7A0C689C4 | PARTIAL |
| 09 | TaxonomyClassifier.psm1 | CORE_COMPONENT_ENGINE | FA9D0C3261A61D298B738B21CC9D9C9531B7E4CC8687A14D37FFA465F5683987 | PARTIAL |
| 10 | ClassificationEngine.psm1 | CORE_COMPONENT_ENGINE | 8202A6D7A636F1B4D967388734CB5487CFF4C439E256829A40CB4B5F95262D0E | PARTIAL |
| 11 | WpdfArtifactGenerator.psm1 | CORE_COMPONENT_ENGINE | 8621A148C721A83BD171EC4569A312F78196319276492E78F67520DC54DB4A5E | PARTIAL |
| 12 | ECTOS.L04.BusinessRequestHandler.V01.psm1 | CORE_COMPONENT_ENGINE | 59A543EEA46FE8CD26154D51F6003037211519636A44FCFE6ADA0D9A9C2C5C90 | PARTIAL |
| 13 | IDBankService.psm1 | CORE_COMPONENT_ENGINE | 901D4683DE2A5E79A240563CDE75682425C188484675FD4E5DE4A9FFE4BA73F0 | PARTIAL |

## Proven package anchors

- ECTOS_CORE_ASSEMBLY_PACKAGE_V02.zip — 35108 bytes — SHA256 1F735B320B69F141EDF6D817F31EE82D71F99B33F63B02445A53DA8E127B9B2A.
- ECTOS_DOC_F02_MASTER_PACKAGE_REGISTER_NORMALIZATION_AND_FREEZE_V01.zip — 131761 bytes — SHA256 4766CF0C5FE9051398575240C8D5F0CB46A0DF3A44C07EB2CECEF672FF0D3045.
- ECTOS_G00_V06_SHARED_SUCCESSOR_QUALIFIED_PACKAGE_V01.zip — SHA256 91943043BF994230024DF2F81F88CA9C902F695E7A7CE094FD3A2B955BB79892.
- ECTOS_DEV_G00_GENERIC_DISPATCH_L01_PREPARED_SOURCE_PACKAGE_V03.zip — SHA256 FE907174AB77EA3E4629271A590D7AB782A7A524AC358237E6E2534BD4827C1A.
- ECTOS_V1_CLOUD_RUN_REAL_REQUEST_BINDING_SUCCESSOR_V03.zip — 121727 bytes — SHA256 DF45CDD50055FBDA72441236743B4FA994D1C014F581DE16AE5285EEE2AAF31C — 81 members — internal hash closure 53/53.

## Assembly model to recover and freeze

The cartography MUST identify, for every package/object:

- PREVIOUS_PACKAGE_OR_CALLER
- NEXT_PACKAGE_OR_CALLEE
- INPUT_CONTRACT
- OUTPUT_CONTRACT
- ENTRYPOINT
- EXITPOINT
- ROUTE
- LAYER
- LAYER_ENTRY
- LAYER_EXIT
- CROSS_LAYER_HANDOFF
- DEPENDENCIES
- AUTHORITY_BOUNDARY
- ERROR_PATH
- TIMEOUT_PATH
- QUALIFICATION_EVIDENCE
- CURRENTNESS
- ENGINE_FAMILY_ID
- QUALIFICATION_PROFILE_ID
- REQUIRED_QUALIFICATION_CAPABILITIES
- EXISTING_TOOL_CANDIDATES
- CURRENT_ADMITTED_TOOL
- TOOL_CURRENTNESS
- TOOL_QUALIFICATION_STATE
- ASSEMBLY_TEST_REQUIREMENTS
- CROSS_LAYER_TEST_REQUIREMENTS

The expected architectural chain is recovered at semantic layer level as:

G00 routing/dispatch -> L01 structuration -> L02 intelligence -> L03 construction -> L04 business -> L05 continuity

This chain is NOT yet accepted as a complete package-by-package current runtime graph. Each edge must be backed by exact source/runtime/qualification evidence.

## Assembly invariant

PACKAGE_QUALIFIED != PACKAGE_ASSEMBLY_READY

LAYER_COMPONENTS_QUALIFIED != LAYER_ASSEMBLED

LAYER_ASSEMBLED != NEXT_LAYER_COMPATIBLE

A cross-layer boundary is READY only when its outbound contract, routing/handoff contract, inbound contract and negative controls are physically proven.

## Engine-family qualification invariant

ECTOS OS cartography is also the source model for qualification capability derivation.

ENGINE_FAMILY_CARTOGRAPHY
-> FAMILY_QUALIFICATION_PROFILE
-> REQUIRED_CHALLENGE_SET
-> QUALIFICATION_TOOL_REQUIREMENTS
-> TOOL_CANDIDATE
-> INDEPENDENT_TOOL_QUALIFICATION
-> FACTORY_ADMISSION
-> TARGET_QUALIFICATION

The current family-model candidate is versioned separately in:

cartography/ectos-os/ECTOS_OS_ENGINE_FAMILY_QUALIFICATION_MODEL_V01.md

A new engine/package in a known family SHOULD be qualifiable by family-level generic qualification logic plus a target-specific profile/contract. New package identities MUST NOT force package-name-specific qualifier logic when the family contract has not changed.

Current family-model candidate classes:
- ROUTING_CONTROL_MODULE
- ORCHESTRATION_CONTROL
- RUNTIME_FACADE_MODULE
- CORE_COMPONENT_ENGINE
- CROSS_LAYER_HANDOFF
- RUNTIME_CARRIER_AND_MATERIALIZATION

The six historical qualification profiles recovered in Tooling forensics MUST NOT be silently equated to these six family classes until exact profile identities/contracts are reconciled.

## Current exact gaps

- F07-GAP-001: current active runtime consumption of the 13 recovered objects is NOT_PROVEN per object.
- F07-GAP-002: current Factory implementation/admission is NOT_PROVEN.
- F07-GAP-003: complete governed qualification-date lineage is NOT_PROVEN.
- F07-GAP-004: standalone qualification is only PARTIAL_TARGET_BOUND for 7 objects.
- F07-GAP-005: exact source ZIP parent is NOT_PROVEN for selected objects.
- F07-GAP-006: Repository engine identity conflicts remain for IdentityResolutionEngine.psm1 and MetadataExtractionEngine.psm1.
- F07-GAP-007: the 62-package historical baseline -> current/running relation is NOT_PROVEN.
- F07-GAP-008: complete package -> engine causal binding is PARTIAL.
- F07-GAP-009: current trusted qualification toolset is NOT_PROVEN.
- CARTOGRAPHY-GAP-QF-001: complete ENGINE_FAMILY_ID assignment for the current OS graph is NOT_PROVEN.
- CARTOGRAPHY-GAP-QF-002: historical qualification profile -> engine-family binding is NOT_PROVEN.
- CARTOGRAPHY-GAP-QF-003: current admitted qualification tool by family is NOT_PROVEN.

## Closure rule

This cartography MUST NOT be marked complete until the current package set, package->engine bindings, intra-layer edges, cross-layer edges, contracts, routes, qualification lineage, engine-family qualification requirements and present runtime/currentness are either physically proven or explicitly marked NOT_PROVEN with exact unreachable scope.
