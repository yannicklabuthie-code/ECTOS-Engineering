# ECTOS Git-Native Candidate Tree Materialization Contract V02

STATUS=CURRENT_CANDIDATE
PROJECT=ECTOS
SCOPE=ENGINEERING_CANDIDATE_MATERIALIZATION
PREDECESSOR=ECTOS_GIT_NATIVE_CANDIDATE_TREE_MATERIALIZATION_CONTRACT_V01

## 1. Purpose

This contract supersedes V01 for future candidate-materialization authorities. It preserves the immutable Git-object candidate model and adds an explicit structured-action boundary so candidate construction does not depend on generated shell/Python helper scripts.

This contract does not qualify, promote, release, or admit a candidate.

## 2. Core invariants

- EVIDENCE_FIRST=YES
- BUILD != QUALIFICATION
- CANDIDATE_COMMIT != MAIN_ACCEPTANCE
- CANDIDATE_COMMIT != RELEASE
- PRODUCER != QUALIFIER != ADMISSION_AUTHORITY
- FAILED_PREDECESSOR_BYTES_ARE_NOT_SOURCE_AUTHORITY
- NO_DIRECT_LOCAL_SOURCE_WRITE
- NO_BASE64_OR_SHELL_QUOTING_BYPASS
- NO_NESTED_SHELL_SOURCE_PATCH
- NO_GENERATED_HELPER_AS_CONTENT_TRANSPORT
- NO_SCRIPT_MEDIATED_GIT_OBJECT_ORCHESTRATION_WHEN_STRUCTURED_GIT_ACTION_EXISTS
- NO_SILENT_RETRY
- NO_SILENT_CLEANUP
- NO_IMPLIED_ROLLBACK
- NO_REF_UPDATE_BEFORE_COMPLETE_CANDIDATE_OBJECT_CLOSURE

## 3. Currentness preflight

Before candidate construction, physically resolve the current ECTOS engineering bootstrap and selector from the canonical repository. Identify language, target OS, and exact runtime. Do not substitute a PowerShell-specific profile for non-PowerShell code.

## 4. Authoritative source base

Bind exactly one authoritative source-base commit. Verify repository identity, source branch/ref, base commit, base tree, predecessor member set, and failed-predecessor role. Missing base evidence blocks construction.

## 5. Search-before-build

Before designing a new materialization mechanism, search ECTOS history and available platform/tool capabilities for reusable primitives. Prefer REUSE or ADAPT over BUILD_NEW.

## 6. Structured-action priority

When the active Git integration exposes structured operations for blob, tree, commit, ref, fetch, or readback, those operations are the governed orchestration boundary.

Do not generate a Python helper, PowerShell helper, shell script, here-string, or nested command solely to reproduce an already-available structured Git operation.

For Git-object construction, use direct structured actions equivalent to:

- create blob from complete content;
- create tree from explicit entries plus an exact base tree;
- create commit from exact tree plus exact parent;
- create/update one isolated ref with expected-state protection;
- re-read/fetch the resulting object graph.

A structured action failure is evidence. Do not retry silently or switch transport methods inside the same campaign.

## 7. Content-construction boundary

Product content must be derived as complete final member content, not as a shell patch program.

The producer may reason over and assemble the complete intended file content, but must not introduce a generated intermediary program whose successful parsing/execution becomes an extra hidden dependency between intended content and Git blob creation.

For each MODIFIED or NEW member, record:

- path;
- role;
- file mode;
- complete intended content/bytes identity;
- SHA256 when available before blob exposure;
- predecessor blob ID if modified;
- text encoding/newline policy when textual.

## 8. Blob phase

Blob creation itself is permitted before syntax/static validation because an unreferenced blob is not an exposed candidate.

For each changed/new member:

1. create the blob through the structured Git blob action;
2. record returned blob OID;
3. read back the blob;
4. prove readback equals intended complete content;
5. validate required encoding/newline rules;
6. perform safe syntax/static validation before tree creation.

If any blob or validation step fails, state=FAILED_PRESERVED and no candidate tree/ref may be created.

## 9. Tree phase

Construct one complete candidate tree from the exact authoritative base tree plus only the authorized changed/new entries.

Before commit creation prove exact paths, modes, blob IDs, no unmapped additions/deletions, no path collisions, no failed-predecessor source authority, and exact package cardinality.

## 10. Commit phase

Create exactly one candidate commit whose tree is the verified candidate tree and whose parent is the exact authoritative base commit. Record commit SHA, tree SHA, parent SHA, message, and member-register binding.

Candidate commit != qualification.

## 11. Isolated ref phase

Do not expose a ref before commit verification. Use one isolated candidate ref only. For a new ref, prove it does not already exist. For any authorized update, require exact expected old OID. No force update unless separately authorized.

After mutation, re-read the ref and require exact equality with the candidate commit SHA.

## 12. Remote verification

Verify repository identity, isolated ref, candidate commit SHA, candidate tree SHA, parent SHA, complete member register, and reconstructibility from the remote object graph.

Remote visibility != Main acceptance.

## 13. Windows fetch/worktree

The Windows host must not rebuild candidate source bytes. It fetches the exact candidate commit/ref, verifies object identity and member set, then materializes a clean worktree from that exact commit.

Post-create verify HEAD, branch/ref binding where applicable, clean status, raw byte identity where governed, and EOL/encoding contracts.

## 14. Static closure

Before qualification, perform complete-package static review, manifest closure, dependency-graph closure, schema/contract closure, reconstructibility review, source/test cardinality checks, safe parser/static checks, and negative-control-surface verification.

Do not stop at the first defect while further safe read-only analysis is possible.

## 15. Candidate identity receipt

Bind at minimum PACKAGE_ID, VERSION, AUTHORITATIVE_BASE_COMMIT, CANDIDATE_COMMIT_SHA, CANDIDATE_TREE_SHA, CANDIDATE_REF, member counts/registers, changed/new/removed registers, unmapped change count, manifest identity, dependency graph identity, static review state, static defect count, unknown assumption count, failed predecessor role, QUALIFICATION_EXECUTED=NO, MAIN_ACCEPTED=NO.

## 16. Failure semantics

Valid materialization terminal states:

- STATICALLY_CLOSED_CANDIDATE
- FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET
- BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE
- FAILED_PRESERVED

Any pre-static-closure failure terminates that candidate campaign. A failed candidate ref/version is not reused for a new attempt.

## 17. Anti-ping-pong rule

After repeated or familiar failures, Main must inspect project history, current governance, and authoritative platform/tool capabilities before routing another engineering successor.

The decision must be REUSE_AS_IS, ADAPT_EXISTING_ASSET, BUILD_NEW, or BLOCKED_NOT_PROVEN.

## 18. V06 anti-recurrence lesson

The failed V06 campaign proved that a generated in-memory Python helper can become an unnecessary hidden dependency and fail before any Git object is created. A later PowerShell read-only closure command also proved that shell parsing can fail independently of product logic.

Therefore future Git-native candidate construction must not use generated Python/PowerShell helper programs as transport/orchestration when structured Git actions already exist.

Content generation and content validation remain required; helper-script execution is not part of the governed transport path.

## 19. ECTOS DEV applicability

This contract is generic. ECTOS DEV blocks must additionally bind exact package identity, dependencies, interfaces, target environment, runtime, qualification surface, and downstream handoff before admission into the ECTOS DEV end-to-end line.
