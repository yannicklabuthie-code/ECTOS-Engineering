# ECTOS Package Dependency Graph Contract V01

## Purpose
Every ECTOS package MUST carry a machine-readable dependency graph that makes its complete technical, runtime, governance, qualification, state and handoff dependency surface explicit before build, qualification, promotion, migration, or handoff.

The package-level graph is the atomic unit. Environment-level maps are produced by aggregating package graphs. The objective is to make blast radius, migration impact, engine ownership, runtime assumptions, cross-package coupling, qualification coverage and unresolved dependencies observable before change.

## Mandatory package artifact
Each package MUST contain `ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01.json`.

The graph MUST describe the exact package bytes/version it accompanies. It MUST NOT be copied forward unchanged when package identity or dependency topology changes.

## Mandatory node classes
PACKAGE, ENGINE, SOURCE_FILE, MODULE, CALL_IMPORT, WORKFLOW, TEST, FIXTURE, CONFIGURATION, ENVIRONMENT, OS_RUNTIME, PROCESS, STATE, REGISTRY, AUTHORITY, UAC, HANDOFF, OUTPUT_ARTIFACT, EXTERNAL_SERVICE, REPOSITORY, OTHER.

## Mandatory edge classes
DEPENDS_ON, CALLS, IMPORTS, LOADS, REQUIRES, GENERATES, VALIDATES, ROUTES_TO, CONSUMES, PRODUCES, BINDS, EXECUTES_ON, READS_STATE, WRITES_STATE, GUARDED_BY, QUALIFIED_BY, HANDS_OFF_TO, AGGREGATES, OTHER.

## Mandatory node fields
Every node MUST include dependency_id, type, name, currentness, physical_evidence, test_coverage, fail_closed_behavior, and impact_if_changed.

Runtime/environment assumptions MUST be modeled as first-class nodes. They MUST NOT remain implicit in code.

## Mandatory closure counters
A package is dependency-closed only when all are zero:
- undeclared_dependency_count
- unresolved_transitive_dependency_count
- untested_dependency_count
- implicit_environment_assumption_count
- unknown_blast_radius_edge_count

`dependency_closure = PASS` is prohibited unless all five counters are zero.

## Change-impact rule
Before mutation of an existing package, the producer MUST freeze the exact predecessor identity, load its dependency graph, identify directly changed nodes, compute reachable upstream/downstream blast radius, identify affected contracts/tests/fixtures/runtimes/authorities/UAC/handoff/output artifacts, and produce one consolidated impact set before successor bytes are generated.

FIRST_DEFECT_ONLY remediation is not a substitute for this analysis.

## Transitive closure rule
Direct file inclusion is insufficient. Dependency closure includes source/import/call dependencies; repository/workflow dependencies; runtime/OS/process assumptions; environment variables; state/registry/ledger dependencies; authority/governance dependencies; test/fixture dependencies; UAC and canonical handoff dependencies; generated outputs/downstream consumers; and cross-package dependencies.

## Environment aggregation
An environment inventory MUST aggregate all package graphs into one environment graph. Each package must be addressable by exact package ID/version/hash. Cross-package edges must be preserved.

Target future environment views include ECTOS_DEV, ECTOS_OS, DEV_OS, and product/project environments such as METAMORPHOSE.

## Admission rule
A package MUST NOT become `PACKAGE_READY_FOR_HANDOFF` when dependency closure is not PASS.

Required UAC request state includes dependency_graph_sha256, dependency_closure=PASS, undeclared_dependency_count=0, unresolved_transitive_dependency_count=0, untested_dependency_count=0, implicit_environment_assumption_count=0, and unknown_blast_radius_edge_count=0.

## Migration rule
Migration planning MUST be derived from the aggregated environment dependency graph, not from package names or manual memory.

## Fail-closed rule
UNKNOWN, NOT_PROVEN, missing graph, graph/package identity mismatch, missing node evidence, dangling edge, unresolved external reference, or non-zero closure counter MUST block dependency closure.
