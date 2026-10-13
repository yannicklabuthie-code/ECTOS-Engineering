# ECTOS Git-Native Candidate Tree Materialization Contract V04

STATUS=CURRENT_CANDIDATE
PROJECT=ECTOS
SCOPE=ENGINEERING_CANDIDATE_MATERIALIZATION
PREDECESSOR=ECTOS_GIT_NATIVE_CANDIDATE_TREE_MATERIALIZATION_CONTRACT_V03

## 1. Purpose

This contract supersedes V03 for future candidate-materialization authorities. It preserves path-first predecessor resolution and structured Git-object construction, and removes pre-tree logical-metadata validation as a required gate when that validation would require a new shell/interpreter orchestration layer.

This contract does not qualify, promote, release, or admit a candidate.

## 2. Inherited invariants

All V03 invariants remain binding, including evidence-first operation, no failed-predecessor source authority, path-first predecessor OID resolution, no direct local source write, no generated helper transport/orchestration, no silent retry, no silent cleanup, no implied rollback, and no ref exposure before candidate object closure.

## 3. V08 anti-recurrence lesson

The failed V08 campaign physically completed the predecessor-object register, created eight unreferenced candidate blobs, achieved blob readback, Python parse for the Python blobs, JSON readback, and byte-format checks, but then attempted an additional PowerShell-mediated pre-tree logical validation of manifest/dependency-graph metadata. PowerShell parsing failed before Python execution.

No product defect was proven. The proven defect was an unnecessary orchestration/parser dependency in a gate that did not need to precede candidate tree creation.

## 4. Separation of metadata validation layers

Metadata validation is split into two layers.

### Layer A — pre-tree physical/syntactic validation

Before tree creation, metadata members must prove only the properties required to make them safe candidate-tree inputs:

- blob creation succeeded;
- blob readback equals intended content;
- UTF-8 decode passes where required;
- BOM policy passes;
- newline/CR policy passes where required;
- JSON syntax is physically parseable by an already-authorized or structured validation path;
- metadata identity/path/version fields are internally self-consistent enough to prevent accidental cross-version substitution.

Layer A MUST NOT introduce a generated PowerShell/Python helper or nested shell quoting path solely to prove logical closure.

### Layer B — post-worktree logical/static closure

Manifest logical closure, dependency-graph logical closure, full package-member binding, dependency binding, reconstructibility, schema/contract closure, and cross-member semantic checks are performed after the immutable candidate commit/ref has been created and the exact candidate has been fetched/materialized into a clean worktree.

Layer B remains mandatory before `STATICALLY_CLOSED_CANDIDATE` and before qualification.

Candidate commit/ref visibility is not qualification, Main acceptance, promotion, or release.

## 5. Why tree/commit creation may precede logical metadata closure

The isolated candidate ref is a non-admitted engineering identity. Its purpose is to freeze exact bytes for subsequent static review and independent qualification.

Therefore a candidate tree/commit/ref may be created after:

- predecessor register PASS;
- changed/new blob readback PASS;
- required encoding/newline checks PASS;
- Python syntax/static parse PASS where applicable;
- JSON syntax/readback PASS for metadata;
- exact authorized path/mode/blob register verification PASS.

Logical metadata closure remains a mandatory later gate before static closure.

## 6. Pre-tree gate

The pre-tree gate must return PASS only if all of the following are physically proven:

1. complete predecessor-object register PASS;
2. all required changed/new blobs created;
3. all blob OIDs recorded;
4. all blob readbacks equal intended content;
5. Python candidate blobs pass safe parse/compile-only validation;
6. JSON candidate blobs pass syntax validation;
7. UTF-8/BOM/LF/CR policies pass where required;
8. expected path/mode/blob register is complete;
9. no unmapped addition/deletion/collision is known;
10. failed predecessor candidate bytes were not used as source authority.

No manifest/dependency-graph logical-closure claim is permitted at this stage unless physically proven without adding an unapproved orchestration layer.

## 7. Tree, commit, and isolated ref

After pre-tree PASS:

- create one tree from the authoritative base tree plus only authorized changed/new entries;
- verify exact path/mode/blob identities;
- create one candidate commit with the exact authoritative base commit as parent;
- verify commit/tree/parent identities;
- expose one new isolated candidate ref only after commit verification;
- verify exact ref OID.

No failed candidate ref/version may be reused.

## 8. Windows materialization

On the authorized Windows host, fetch the exact immutable candidate identity. Do not rebuild candidate source bytes locally.

Verify commit, tree, parent, member set, changed/new set, target local branch/path availability, then materialize one clean worktree.

## 9. Post-worktree metadata logical closure

After the clean worktree exists, perform metadata logical closure using pre-existing, simple, separately attributable validation primitives.

Preference order:

1. existing qualified/reused ECTOS validator primitive;
2. direct fixed parser/validator invocation against exact candidate files with no generated helper, no nested quoting, and no source mutation;
3. structured/static inspection if it provides equivalent physical proof.

Do not build a new ad-hoc validation script inside the candidate campaign merely to validate the metadata.

Historical reusable evidence includes the UAC canonical JSON primitive `uac/byte_contract.py`, whose `validate_canonical_json_file` performs raw-byte read, BOM rejection, strict UTF-8 decode, `json.loads`, canonical byte reconstruction, and fail-closed mismatch handling. Reuse by role requires exact applicability review; it is not automatically qualification evidence for SWBI metadata semantics.

## 10. Logical metadata closure requirements

Before `STATICALLY_CLOSED_CANDIDATE`, prove at minimum:

- manifest package ID/version correct;
- manifest member set/count exact;
- manifest member identities bind the frozen candidate source set;
- package SHA/aggregate identity logic is internally consistent where defined;
- dependency graph package ID/version correct;
- dependency nodes/edges match the exact candidate dependencies;
- no stale V04/V05/V06/V07 identity remains where V08/V09 successor identity is required;
- schema/contract references resolve to the candidate member set;
- reconstructibility closes from the exact candidate identity;
- no unmapped member exists.

Failure here terminates the candidate as `FAILED_PRESERVED` or `FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET` according to the exact failure semantics. The isolated ref remains forensic candidate evidence and is not reused.

## 11. Anti-ping-pong rule

Do not move a gate earlier merely because later validation previously failed. Gate placement must follow the earliest stage at which the evidence is actually required for safety or identity correctness.

Do not introduce a new interpreter/shell transport layer to validate data that can safely be frozen first and validated against the immutable candidate later.

## 12. Candidate terminal states

Valid terminal states remain:

- STATICALLY_CLOSED_CANDIDATE
- FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET
- BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE
- FAILED_PRESERVED

Any failed candidate version/ref is terminal and is not reused.

## 13. ECTOS DEV applicability

This contract is generic. For ECTOS DEV, candidate blocks must additionally bind exact package identity, dependencies, interfaces, target environment, runtime, qualification surface, and downstream handoff before admission into the end-to-end line.
