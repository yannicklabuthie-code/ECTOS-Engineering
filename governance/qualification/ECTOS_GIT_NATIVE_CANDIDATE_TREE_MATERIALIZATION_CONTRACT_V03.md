# ECTOS Git-Native Candidate Tree Materialization Contract V03

STATUS=CURRENT_CANDIDATE
PROJECT=ECTOS
SCOPE=ENGINEERING_CANDIDATE_MATERIALIZATION
PREDECESSOR=ECTOS_GIT_NATIVE_CANDIDATE_TREE_MATERIALIZATION_CONTRACT_V02

## 1. Purpose

This contract supersedes V02 for future candidate-materialization authorities. It preserves the structured Git-object construction model and adds a mandatory path-first predecessor-object resolution gate before any `fetch_blob` operation.

This contract does not qualify, promote, release, or admit a candidate.

## 2. Inherited invariants

All V02 invariants remain binding, including evidence-first operation, no direct local source write, no generated helper transport/orchestration, no silent retry, no silent cleanup, no implied rollback, no failed-predecessor source authority, and no ref exposure before complete candidate-object closure.

## 3. Currentness preflight

Before candidate construction, physically resolve the current ECTOS engineering bootstrap and selector from the canonical repository. Identify language, target OS, and exact runtime. Do not substitute a PowerShell-specific profile for non-PowerShell code.

## 4. Authoritative source base

Bind exactly one authoritative source-base commit and base tree. Verify repository identity, source branch/ref, base commit, base tree, predecessor package/member register, and failed-predecessor role.

Missing base evidence blocks construction.

## 5. Search-before-build

Before designing or changing materialization behavior, inspect ECTOS history and available platform/tool capabilities. Prefer existing structured repository-path and Git-object reads over inferred identifiers or helper scripts.

## 6. Mandatory path-first predecessor resolution

A predecessor blob OID must never be guessed, reconstructed, inferred from unrelated evidence, or passed to `fetch_blob` before it is physically established.

For every REUSED or MODIFIED predecessor member required by the candidate:

1. start from the verified authoritative base commit SHA and an exact repository-relative path from the accepted predecessor member register;
2. resolve the member through a structured repository path read at the exact base commit/ref, or through a physically verified base-tree/path lookup;
3. record the returned path identity and physical blob SHA/OID;
4. require that the resolved path exactly equals the expected repository-relative path;
5. require that the object belongs to the authoritative base commit/tree being used;
6. only after the blob OID has been physically established may `fetch_blob` be called for that OID;
7. if path resolution returns missing, ambiguous, mismatched, or unbound evidence, transition to `FAILED_PRESERVED` or `BLOCKED_NOT_PROVEN` according to the exact condition before any candidate blob/tree/ref creation.

`fetch_blob` is a blob-content read, not an identifier-discovery mechanism.

## 7. Predecessor object register gate

Before creating the first candidate blob, produce one complete predecessor-object register for every base member that will be reused or modified.

Each register row must contain at minimum:

- repository-relative path;
- classification: REUSED or MODIFIED;
- authoritative base commit SHA;
- authoritative base tree SHA;
- physically established predecessor blob OID;
- file mode where available;
- structured resolution source/action;
- resolution state PASS / FAIL / NOT_PROVEN.

The gate passes only when all required predecessor rows are PASS.

No candidate `create_blob` action is authorized before this register is complete for the exact candidate scope.

## 8. Structured-action priority

When structured Git actions exist for file/path fetch, blob read/create, tree create, commit create, or ref mutation, use them directly. Do not generate a Python, PowerShell, or shell helper to reproduce those operations.

A structured-action failure is evidence. Do not retry silently or switch transport within the same candidate campaign.

## 9. Content construction

For each MODIFIED or NEW member, derive complete intended final content directly from the clean authoritative source base and accepted change contract. Do not copy bytes from failed predecessor candidates as source authority.

Record complete intended content/bytes identity, path, role, mode, predecessor blob OID when modified, encoding/newline policy, and expected SHA256 where available.

## 10. Blob phase

For each changed/new member:

1. call structured `create_blob` with the complete intended content;
2. record returned blob OID;
3. read back that exact OID with structured `fetch_blob`;
4. prove readback equals intended complete content;
5. validate required encoding/newline rules;
6. perform safe syntax/static validation before tree creation.

Unreferenced candidate blobs are not candidate exposure.

Any failure before tree creation ends the candidate campaign as `FAILED_PRESERVED` with no retry and no ref reuse.

## 11. Tree phase

Create one complete candidate tree from the exact authoritative base tree plus only the authorized changed/new entries. Before commit creation prove exact paths, modes, blob OIDs, no unmapped additions/deletions, no collisions, no failed-predecessor source authority, and exact package cardinality.

## 12. Commit and isolated ref

Create exactly one candidate commit from the verified tree with the exact authoritative base commit as parent. Do not expose any candidate ref before commit verification. Use one isolated candidate ref and verify exact post-mutation OID equality.

Candidate commit != qualification.

## 13. Remote and local verification

Verify remote repository/ref/commit/tree/member identity. On the authorized Windows host, fetch the exact candidate identity, verify commit/tree/member set, then materialize one clean worktree without rebuilding source bytes locally.

## 14. Static closure

Before qualification, complete manifest, dependency graph, schema/contract, reconstructibility, source/test cardinality, safe static parse, negative-control-surface, and full-package static review. Continue safe analysis after first defect to produce one consolidated defect set.

## 15. Candidate identity receipt

Bind at minimum PACKAGE_ID, VERSION, AUTHORITATIVE_BASE_COMMIT, AUTHORITATIVE_BASE_TREE, PREDECESSOR_OBJECT_REGISTER, CANDIDATE_COMMIT_SHA, CANDIDATE_TREE_SHA, CANDIDATE_REF, member registers/counts, changed/new/removed registers, unmapped change count, manifest identity, dependency graph identity, static review state, defect count, unknown assumption count, failed predecessor role, QUALIFICATION_EXECUTED=NO, MAIN_ACCEPTED=NO.

## 16. Failure semantics

Valid terminal states:

- STATICALLY_CLOSED_CANDIDATE
- FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET
- BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE
- FAILED_PRESERVED

Any pre-static-closure failure terminates that candidate campaign. A failed candidate version/ref is not reused.

## 17. V07 anti-recurrence lesson

The failed V07 campaign attempted structured `fetch_blob` before the predecessor blob OID had been physically established. The operation returned 404 and correctly terminated the candidate campaign before any candidate object was created.

The systemic correction is path-first predecessor resolution: exact base commit + exact package path -> physically established blob OID -> optional blob fetch. `fetch_blob` must never be used to discover an unknown blob identifier.

## 18. ECTOS DEV applicability

This contract is generic. For ECTOS DEV, each block must additionally bind exact package identity, dependencies, interfaces, target environment, runtime, qualification surface, and downstream handoff before admission into the end-to-end line.
