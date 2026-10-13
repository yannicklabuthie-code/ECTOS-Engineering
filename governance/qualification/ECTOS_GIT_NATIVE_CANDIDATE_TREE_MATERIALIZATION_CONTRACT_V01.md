# ECTOS Git-Native Candidate Tree Materialization Contract V01

STATUS=CURRENT_CANDIDATE
PROJECT=ECTOS
SCOPE=ENGINEERING_CANDIDATE_MATERIALIZATION

## 1. Purpose

This contract defines a governed materialization path for ECTOS engineering candidates when direct local file-write transport is unavailable, rejected, unreliable, or would require unsafe transport workarounds.

The candidate package is materialized as immutable Git objects first. A worktree is only created or updated after the complete candidate identity has been closed.

This contract does not qualify, promote, release, or admit the candidate.

## 2. Governing invariants

- EVIDENCE_FIRST=YES
- BUILD != QUALIFICATION
- CANDIDATE_COMMIT != MAIN_ACCEPTANCE
- CANDIDATE_COMMIT != RELEASE
- PRODUCER != QUALIFIER != ADMISSION_AUTHORITY
- FAILED_PREDECESSOR_BYTES_ARE_NOT_SOURCE_AUTHORITY
- NO_DIRECT_LOCAL_WRITE_WORKAROUND
- NO_BASE64_OR_SHELL_QUOTING_BYPASS
- NO_NESTED_SHELL_SOURCE_PATCH
- NO_SILENT_RETRY
- NO_SILENT_CLEANUP
- NO_IMPLIED_ROLLBACK
- NO_REF_UPDATE_BEFORE_COMPLETE_CANDIDATE_OBJECT_CLOSURE

## 3. Required currentness preflight

Before candidate construction, resolve and physically verify the current ECTOS engineering rule bootstrap and current selector from the canonical repository.

For code missions, determine language, target OS, and exact runtime. Do not substitute a PowerShell-specific profile for non-PowerShell code.

## 4. Authoritative source base

A candidate must bind one exact source-base commit SHA.

Required evidence:

1. canonical repository identity;
2. expected base commit SHA;
3. base commit physically resolvable;
4. source branch/ref physically resolves to the expected base where required;
5. predecessor package member set identified;
6. failed predecessor campaigns classified as forensic/reference-only where applicable.

If any required base identity is not proven, candidate construction is blocked.

## 5. Search-before-build rule

Before designing a new materialization mechanism, search ECTOS history for reusable proven primitives and authoritative platform behavior.

Reuse proven primitives by role where possible. Do not recreate a capability already physically present and applicable.

## 6. Git object construction model

The governed construction sequence is:

SOURCE_BASE_VERIFIED
→ CONTENTS_DERIVED
→ BLOBS_CREATED
→ TREE_CREATED
→ TREE_VERIFIED
→ CANDIDATE_COMMIT_CREATED
→ CANDIDATE_COMMIT_VERIFIED
→ ISOLATED_REF_CREATED_OR_UPDATED
→ REMOTE_VISIBLE_CANDIDATE_VERIFIED
→ LOCAL_FETCH_VERIFIED
→ CLEAN_WORKTREE_MATERIALIZED
→ STATICALLY_CLOSED
→ STOP_BEFORE_QUALIFICATION

Any failure before STATICALLY_CLOSED transitions the campaign to FAILED_PRESERVED unless Main explicitly authorizes a separate successor campaign.

## 7. Blob contract

Each changed or new candidate member must have complete final bytes determined before ref exposure.

For each member record:

- repository-relative path;
- file mode;
- source role;
- byte length;
- SHA256 of intended raw bytes;
- Git blob object ID;
- encoding/newline contract where textual;
- predecessor blob ID where modified;
- NEW / MODIFIED / REUSED classification.

Textual source intended as UTF-8_NO_BOM_LF must be validated before candidate tree creation.

Git blob creation does not by itself prove product correctness or qualification.

## 8. Tree contract

The candidate tree must be a complete tree derived from the exact authoritative base plus only the authorized changed/new member set.

Tree creation must fail closed if a referenced object is missing.

Before commit creation prove:

- exact expected path set;
- exact file modes;
- exact blob IDs;
- no unmapped additions;
- no unmapped deletions;
- no path collision;
- no forbidden failed-predecessor byte source;
- package cardinality matches the current candidate contract.

TREE_VERIFIED requires a deterministic comparison between expected member register and the physical Git tree.

## 9. Commit contract

Create one candidate commit whose tree is the verified candidate tree and whose parent is the exact authoritative source-base commit.

Record:

- candidate commit SHA;
- candidate tree SHA;
- parent SHA;
- commit message;
- author/committer identity available from Git;
- package/member register binding.

The commit is an immutable candidate identity only. It is not qualification evidence.

## 10. Ref exposure contract

No branch/ref may point to the candidate until the complete candidate commit has been created and verified.

The ref must be isolated from `main` and any current release/admission branch.

Ref creation/update must use compare-and-swap semantics:

- when creating a new candidate ref, require that the ref does not already exist;
- when updating an existing explicitly authorized candidate ref, require the exact expected old OID;
- a mismatch blocks the update;
- no force update unless separately authorized by Main for the exact ref and expected old OID.

After ref mutation, re-read the ref and require exact equality with the candidate commit SHA.

## 11. Ref transaction truth boundary

Do not overclaim transaction semantics.

A single ref compare-and-swap update may be treated as one guarded ref mutation.

Multi-ref atomic visibility is not assumed unless separately proven for the exact operation and platform path.

For the current candidate-materialization method, prefer one isolated candidate ref only.

## 12. Remote visibility contract

After the isolated ref exists remotely, physically verify:

- remote repository identity;
- remote candidate ref;
- exact candidate commit SHA;
- exact candidate tree SHA where retrievable;
- candidate parent equals authoritative base;
- candidate member register can be reconstructed from the remote Git object graph.

Presence on remote does not equal Main acceptance.

## 13. Local fetch and worktree contract

The authorized Windows host must not rebuild candidate source bytes manually.

It must fetch the exact candidate ref/commit and verify:

1. local object presence;
2. candidate commit SHA;
3. candidate parent SHA;
4. candidate tree SHA;
5. expected member set;
6. expected changed/new path set;
7. no local preexisting target branch/path conflict.

Only then may a clean worktree be materialized from the exact candidate commit.

After worktree creation verify HEAD, branch/ref binding where applicable, clean status, required raw byte identity, and applicable EOL/encoding contracts.

## 14. Static closure before qualification

Before routing to an independent qualifier:

- enumerate complete candidate member set;
- verify manifest closure;
- verify dependency graph closure;
- verify schemas/contracts;
- verify reconstructibility;
- verify expected source/test cardinality;
- run applicable safe static parsing and structural checks;
- verify negative-control surface exists;
- produce one candidate identity receipt.

Static review must inspect the complete package, not stop at the first defect if further safe analysis is possible.

## 15. Candidate identity receipt

The minimum receipt must bind:

- PACKAGE_ID;
- VERSION;
- AUTHORITATIVE_BASE_COMMIT;
- CANDIDATE_COMMIT_SHA;
- CANDIDATE_TREE_SHA;
- CANDIDATE_REF;
- ACTIVE_SOURCE_MEMBER_COUNT;
- METADATA_MEMBER_COUNT;
- PACKAGE_MEMBER_COUNT;
- MEMBER_REGISTER;
- CHANGED_MEMBER_REGISTER;
- NEW_MEMBER_REGISTER;
- REMOVED_MEMBER_REGISTER;
- UNMAPPED_CHANGE_COUNT;
- MANIFEST_IDENTITY;
- DEPENDENCY_GRAPH_IDENTITY;
- STATIC_REVIEW_STATE;
- STATIC_DEFECT_COUNT;
- UNKNOWN_ASSUMPTION_COUNT;
- FAILED_PREDECESSOR_ROLE;
- QUALIFICATION_EXECUTED=NO;
- MAIN_ACCEPTED=NO.

## 16. Qualification boundary

Only after the exact candidate commit/tree/member set is frozen and statically closed may Main route that exact identity to an independent qualifier.

The qualifier must qualify the exact commit and package identity. A later changed commit is a different candidate and requires separate adjudication.

## 17. Failure states

Valid materialization end states are:

- STATICALLY_CLOSED_CANDIDATE
- FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET
- BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE
- FAILED_PRESERVED

No failure state may be silently converted back into an active build state.

## 18. Anti-ping-pong rule

After repeated or familiar failures, Main must search current project history and authoritative platform documentation before routing another engineering successor.

The decision must be one of:

- REUSE_AS_IS
- ADAPT_EXISTING_ASSET
- BUILD_NEW
- BLOCKED_NOT_PROVEN

BUILD_NEW requires evidence that no adequate reusable method closes the requirement.

## 19. Platform facts relied upon by this contract

This contract intentionally uses only platform semantics that can be physically verified:

- Git blob objects are content-addressed objects;
- `git hash-object -w` writes an object and returns its object ID;
- `git mktree` creates a tree from entries and, by default, verifies referenced objects exist;
- `git commit-tree` creates a commit object from a tree and explicit parent(s);
- guarded ref mutation must verify expected old state before changing the ref;
- a zero/absent old OID can be used to require that a new ref does not already exist;
- ref mutation does not constitute qualification.

## 20. ECTOS DEV applicability

This contract is generic. For ECTOS DEV, each candidate block must bind its exact package identity, dependencies, interfaces, target environment, runtime, qualification surface, and downstream handoff before it can be admitted into the ECTOS DEV end-to-end line.

The method exists to eliminate ad-hoc local materialization loops and to make the candidate itself an immutable, independently qualifiable object.
