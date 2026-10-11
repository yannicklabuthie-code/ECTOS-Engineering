# ECTOS PS5.1 Systemic Assurance Route Contract V02

## 0. Authority and status

PROJECT=ECTOS
PROJECT_CONTAINER=ECTOS-POC
SOURCE_AUTHORITY=ECTOS_MAIN_AUTHORITY
SUPERIOR_AUTHORITY=PROJECT_OWNER_YANICK
CONTRACT_ID=ECTOS_PS51_SYSTEMIC_ASSURANCE_ROUTE_CONTRACT_V02
CONTRACT_VERSION=V02
CONTRACT_TYPE=NEW_AUTHORITATIVE_DEFINITION
PREDECESSOR_RELATION=NOT_A_RECONSTRUCTION_OF_LOST_V01_SESSION_CONTRACT
OWNER_AUTHORIZATION=GRANTED_2026-10-11
IMPLEMENTATION_CODE_INCLUDED=NO
EXECUTION_AUTHORITY_INCLUDED=NO
QUALIFICATION_AUTHORITY_INCLUDED=NO
PROMOTION_AUTHORITY_INCLUDED=NO
RELEASE_AUTHORITY_INCLUDED=NO

This contract is a new authoritative definition derived from currently proven ECTOS governance, current PowerShell rule sources, the accepted HH-01 through HH-09 systemic defect set, the named NC01 through NC28 control taxonomy, and the owner-authorized NC29 through NC32 extension. It MUST NOT be represented as a recovered copy of the lost V01 session contract.

## 1. Objective and architectural invariants

OBJECTIVE=Provide one generic, versioned, fail-closed systemic assurance route for Windows PowerShell Desktop 5.1 targets.

Mandatory invariants:

1. GENERIC_TO_TARGET=YES.
2. CURRENT_RULE_SOURCE_BOUND=YES.
3. CURRENT_RULESET_IDENTITY_BOUND=YES.
4. CONTRACT_DRIVEN=YES.
5. NATIVE_WINDOWS_POWERSHELL_DESKTOP_5_1=MANDATORY_FOR_NATIVE_GATES.
6. FAIL_CLOSED=YES.
7. FULL_PROCESS_EVIDENCE_CAPABLE=YES.
8. REGRESSION_AND_NEGATIVE_CONTROL_CAPABLE=YES.
9. EXACT_BYTE_BOUND=YES.
10. INDEPENDENT_HANDOFF_CAPABLE=YES.
11. TARGET_SPECIFIC_BRANCHING_IN_GENERIC_ROUTE=PROHIBITED.
12. TARGET_SPECIFIC_HARDCODED_PATHS_IN_GENERIC_ROUTE=PROHIBITED.
13. TARGET_SPECIFIC_HASHES_IN_GENERIC_ROUTE=PROHIBITED.
14. ADDING_A_REGISTERED_TARGET_MUST_NOT_REQUIRE_GENERIC_ROUTE_SOURCE_CHANGES=YES.
15. ENCODEDCOMMAND_TRANSPORT=PROHIBITED.
16. ENCODEDCOMMAND_CLASSIFIER_OR_SYNTHETIC_RECONSTRUCTION=PROHIBITED.
17. NESTED_POWERSHELL_COMMAND_TRANSPORT=PROHIBITED.
18. SILENT_RETRY=PROHIBITED.
19. SILENT_PATCH=PROHIBITED.
20. FAILED_ATTEMPT_REUSE=PROHIBITED.
21. FAILED_ATTEMPT_OVERWRITE=PROHIBITED.
22. FAILED_ATTEMPT_QUARANTINE=MANDATORY.
23. MANUAL_STATE_PROMOTION=PROHIBITED.
24. SKIPPING_REQUIRED_GATE=PROHIBITED.
25. WRONG_FAILURE_REASON_ACCEPTANCE=PROHIBITED.
26. GENERIC_EXCEPTION_ACCEPTANCE=PROHIBITED.
27. TESTED_BYTES_MUST_EQUAL_HANDED_OFF_BYTES=YES.
28. POST_ASSURANCE_MUTATION_COUNT_MUST_EQUAL_0=YES.

## 2. Current governed rule-source binding

The route MUST resolve currentness dynamically at execution time and MUST NOT hard-code a commit as permanent truth.

CANONICAL_REPOSITORY=yannicklabuthie-code/ECTOS-Engineering
CANONICAL_BRANCH=main
STABLE_SELECTOR=ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json
CURRENT_POINTER_EXPECTED_BY_CURRENT_SOURCE=ECTOS_AGENT_CODE_RULE_SOURCE_POINTER_V02.json
CURRENT_POINTER_STATUS_REQUIRED=CURRENT
TARGET_LANGUAGE=POWERSHELL
TARGET_OS=WINDOWS
TARGET_RUNTIME=WINDOWS_POWERSHELL_DESKTOP_5_1

Mandatory source chain:

- AGENTS.md
- ECTOS_AGENT_CODE_RULE_SOURCE_POINTER.json
- selector-resolved CURRENT versioned pointer
- routing method from the CURRENT pointer
- PowerShell profile from the CURRENT pointer
- profile SHA sidecar
- consumption contract
- ruleset manifest
- ruleset SHA sidecar
- workspace identity contract
- .gitattributes
- complete active ruleset
- coding standard
- forbidden patterns
- approved patterns
- error catalog
- runtime compatibility specification
- static detector contract
- native PS5.1 validation contract
- regression contract
- positive and negative fixtures

Current proof anchor at contract creation time:

CURRENT_MAIN_SHA_AT_CREATION=f674622f88aa36476dbf2b77b2182896df064a55
CURRENT_PROFILE_ID=ECTOS_POWERSHELL_PS51_PROFILE
CURRENT_PROFILE_CANONICAL_SHA256=4B9A8830292CC811B141B4DAE91F2B816A3448921EE3B3ED25DA412C17A78625
CURRENT_RULESET_SHA256=2FD86D22587B2E694FC62C3B734DED1A7430831BFC0E34B5C176327012907525

These values are creation-time evidence only. Runtime currentness MUST be re-resolved from the stable selector.

## 3. Generic target input contract

A target is admitted only through a versioned declarative target binding. The generic route MUST consume the binding and MUST NOT special-case the target in source code.

Required target binding fields:

- binding_schema_id
- binding_version
- target_id
- target_role
- target_path
- target_sha256
- target_size_bytes
- target_language
- target_os
- target_runtime
- entrypoint_type
- expected_working_directory
- expected_output_contract_id
- static_contract_id
- native_contract_id
- regression_contract_id
- negative_control_profile_id
- evidence_contract_id
- package_manifest_contract_id
- handoff_contract_id
- binding_created_utc
- binding_authority

Binding requirements:

- target_sha256 MUST be 64 uppercase hexadecimal characters.
- target_size_bytes MUST be a non-negative integer.
- target_path MUST resolve to one exact leaf file at bind time.
- target bytes MUST be re-hashed immediately before any consuming gate.
- stale or mutated binding/target relationships MUST fail closed.
- the binding itself MUST have a stable physical identity: path, size, SHA256, schema and version.

## 4. Route self-identity contract

The route implementation MUST have a versioned route identity object containing:

- route_id
- route_version
- route_member_manifest
- route_member_count
- per-member relative path
- per-member size
- per-member SHA256
- aggregate manifest SHA256
- producing commit SHA
- source branch/ref
- build timestamp if a build exists
- post-assurance mutation count

The route MUST verify its own exact member identity before consuming a target.

## 5. Process execution contract

### 5.1 Executable identity

The only native runtime accepted for native PS5.1 gates is:

`%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`

Required proof:

- resolved executable path
- executable existence
- executable size
- executable SHA256 where required by the current native contract
- PSEdition=Desktop
- PSVersion major=5 and minor=1

PowerShell 7 is not equivalent proof.

### 5.2 Child transport

PROCESS_TRANSPORT=NATIVE_PS51_FILE_ARGUMENT_VECTOR

Mandatory rules:

- Child script execution MUST use `-File`.
- `-Command` transport for governed child execution is prohibited.
- `-EncodedCommand` is prohibited.
- Base64/UTF-16LE EncodedCommand classification, repair, mutation or synthetic reconstruction is prohibited.
- An outer PowerShell command string MUST NOT wrap another PowerShell command string.
- No ephemeral Remote Desktop Commander shell quoting may be part of the governed execution contract.
- The implementation MUST use one documented Windows argument-rendering algorithm appropriate to `System.Diagnostics.ProcessStartInfo` on Windows PowerShell 5.1 and MUST regression-test that algorithm against empty, space-containing, quote-containing and backslash-ending arguments.
- The exact logical argument vector and the exact rendered argument string MUST both be captured as evidence when `ProcessStartInfo.Arguments` is used.

### 5.3 Standard streams and process state

STDIN_CONTRACT=NO_INTERACTIVE_INPUT_UNLESS_DECLARED_BY_TARGET_BINDING
STDOUT_CONTRACT=CAPTURE_COMPLETE_SEPARATELY
STDERR_CONTRACT=CAPTURE_COMPLETE_SEPARATELY
EXIT_CODE_CONTRACT=CAPTURE_EXACT_INTEGER
TIMEOUT_CONTRACT=EXPLICIT_POSITIVE_TIMEOUT_REQUIRED
WORKING_DIRECTORY_CONTRACT=EXACT_BOUND_DIRECTORY_REQUIRED
ENVIRONMENT_CONTRACT=CAPTURE_EFFECTIVE_GOVERNED_OVERRIDES
PROCESS_TERMINATION_CONTRACT=CAPTURE_EXITED_OR_TIMEOUT_TERMINATED_OR_START_FAILURE
AUTOMATIC_RETRY=PROHIBITED

A timeout MUST terminate the governed child, preserve evidence, classify the attempt as failed, quarantine its evidence directory, and consume execution authority when execution authority had already been consumed.

### 5.4 Created outputs

Every created output MUST be enumerated after child termination with:

- relative path
- size_bytes
- SHA256
- creation/existence status

Unexpected outputs MUST be either explicitly allowed by the target output contract or fail closed.

## 6. Trust boundaries

TB01_CANONICAL_GITHUB_RULE_SOURCE
- Trust condition: current stable selector and resolved CURRENT pointer are fetched from canonical GitHub repository main.
- Failure: source cannot be reached, selector/pointer mismatch, or pointer not CURRENT => BLOCKED_NOT_PROVEN.

TB02_LOCAL_GOVERNED_WORKTREE
- Trust condition: workspace rule bytes equal committed blob bytes for the resolved source commit under the workspace identity contract.
- Failure: any member differs => FAIL_CLOSED.

TB03_RULESET_IDENTITY
- Trust condition: exact member set, count, per-member identity and composite ruleset SHA match current profile/manifest/sidecar.
- Failure: any mismatch => FAIL_CLOSED.

TB04_TARGET_BYTES
- Trust condition: bound target path, size and SHA match immediately before every consuming gate.
- Failure: mismatch => FAIL_CLOSED.

TB05_TARGET_BINDING
- Trust condition: binding schema/version/identity is current, internally consistent and physically hashed.
- Failure: stale or malformed binding => FAIL_CLOSED.

TB06_ASSURANCE_ROUTE_BYTES
- Trust condition: route manifest closes every executable/config/evidence-contract member and route self-identity passes.
- Failure: mismatch or unknown member => FAIL_CLOSED.

TB07_NATIVE_PS51_EXECUTABLE
- Trust condition: exact native Windows PowerShell Desktop 5.1 path and runtime identity proven.
- Failure: PowerShell 7, ISE, wrapper or wrong executable => FAIL_CLOSED.

TB08_PSSCRIPTANALYZER
- Trust condition: required version/module identity from current governed profile or tooling contract is loaded exactly.
- Failure: unavailable or wrong version => BLOCKED_NOT_PROVEN or FAIL_CLOSED according to whether execution began.

TB09_FIXTURES
- Trust condition: positive and negative fixtures are versioned, hashed, mapped to declared rules/contracts and immutable during campaign.
- Failure: missing/mutated/ambiguous fixture => FAIL_CLOSED.

TB10_OUTPUT_EVIDENCE
- Trust condition: evidence is complete, durable, uniquely bound to one invocation and hash-closed.
- Failure: missing or inconsistent member => FAIL_CLOSED.

TB11_PACKAGE_MANIFEST
- Trust condition: complete final handoff member set, size and SHA closure.
- Failure: missing/extra/mismatched member => FAIL_CLOSED.

TB12_INDEPENDENT_ASSURANCE
- Trust condition: qualifier consumes the exact producer-handoff bytes and identities without mutation.
- Failure: producer/qualifier identity mismatch => FAIL_CLOSED.

TB13_MAIN_ADJUDICATION
- Trust condition: MAIN receives immutable producer and independent-assurance evidence and adjudicates without substituting missing evidence.
- Failure: missing evidence => NOT_PROVEN; no promotion.

## 7. State machine

States:

1. UNINITIALIZED
2. SOURCE_BOUND
3. RULESET_BOUND
4. TARGET_BOUND
5. ROUTE_SELF_ASSURANCE_COMPLETE
6. STATIC_ASSURANCE_COMPLETE
7. NATIVE_ASSURANCE_COMPLETE
8. REGRESSION_COMPLETE
9. NEGATIVE_CONTROLS_COMPLETE
10. EVIDENCE_CLOSED
11. READY_FOR_INDEPENDENT_HANDOFF
12. FAIL_CLOSED
13. BLOCKED_NOT_PROVEN

Permitted forward transitions:

UNINITIALIZED -> SOURCE_BOUND
SOURCE_BOUND -> RULESET_BOUND
RULESET_BOUND -> TARGET_BOUND
TARGET_BOUND -> ROUTE_SELF_ASSURANCE_COMPLETE
ROUTE_SELF_ASSURANCE_COMPLETE -> STATIC_ASSURANCE_COMPLETE
STATIC_ASSURANCE_COMPLETE -> NATIVE_ASSURANCE_COMPLETE
NATIVE_ASSURANCE_COMPLETE -> REGRESSION_COMPLETE
REGRESSION_COMPLETE -> NEGATIVE_CONTROLS_COMPLETE
NEGATIVE_CONTROLS_COMPLETE -> EVIDENCE_CLOSED
EVIDENCE_CLOSED -> READY_FOR_INDEPENDENT_HANDOFF

Any required-gate failure after authority consumption -> FAIL_CLOSED.
Any unavailable mandatory dependency before authority consumption -> BLOCKED_NOT_PROVEN.
Any attempted skipped gate, out-of-order gate, manual state promotion or fabricated state evidence -> FAIL_CLOSED.
No transition may bypass a required state.

A durable state ledger MUST record for every transition:

- prior_state
- requested_next_state
- actual_next_state
- gate_id
- gate_result
- timestamp_utc
- controlling artifact identities
- invocation_id
- failure_id if any

## 8. Failure, retry, authority and quarantine policy

AUTHORITY_CONSUMPTION_POINT=IMMEDIATELY_BEFORE_FIRST_GOVERNED_CHILD_PROCESS_START_OR_ANY_TARGET_MUTATING_ACTION

Read-only source/currentness/binding/workspace checks before that point do not consume execution authority.

After authority consumption:

- Any start failure, timeout, nonzero exit, contract failure or evidence failure consumes the attempt.
- No automatic retry is permitted.
- A failed attempt MUST be quarantined under a unique immutable invocation ID.
- Failed evidence MUST NOT be overwritten or reused as evidence for another attempt.
- A new attempt requires explicit eligibility under current circuit-breaker governance.
- After two failures in the same package/family/campaign or repeated related root failure, ordinary iteration stops and full systemic review is mandatory.
- No micro-remediation loop may bypass the circuit breaker.

## 9. Required durable evidence set

One invocation evidence root MUST include, at minimum:

- invocation_id
- route_id
- route_version
- route_manifest identity and SHA256
- route member identities
- canonical repository identity
- canonical main/ref identity
- stable selector identity
- resolved pointer identity
- profile identity and canonical SHA256
- ruleset manifest identity
- ruleset composite SHA256
- per-rule workspace/blob identity proof
- target binding identity, size and SHA256
- target identity, size and SHA256
- native PS51 executable path and SHA256 where required
- PSEdition
- PSVersion
- parser result
- static detector result
- PSScriptAnalyzer result
- regression result
- all negative-control results
- process contract ID
- logical argument vector
- rendered arguments when applicable
- exact working directory
- governed environment overrides
- start time UTC
- end time UTC
- termination state
- exit code
- complete stdout
- stdout SHA256
- complete stderr
- stderr SHA256
- timeout state
- created outputs manifest
- per-output size and SHA256
- evidence manifest
- evidence manifest SHA256
- tested byte identity
- handed-off byte identity
- post-assurance mutation count
- final assurance state

Evidence roots MUST be unique and immutable once closed.

## 10. Package manifest and exact-byte handoff contract

The producer handoff MUST contain one manifest that closes every handed-off member.

For every member:

- relative_path
- role
- size_bytes
- sha256
- source_commit_or_origin

The manifest MUST additionally record:

- member_count
- manifest_schema
- package_id
- package_version
- target_binding_id
- route_id
- route_version
- tested_target_sha256
- tested_route_manifest_sha256
- creation timestamp UTC
- producer identity

Required invariant:

TESTED_BYTES = HANDED_OFF_BYTES

This equality MUST hold independently for:

- target bytes
- route bytes
- target binding bytes
- package manifest bytes as consumed by the qualifier

POST_ASSURANCE_MUTATION_COUNT=0 is mandatory.

The independent qualifier MUST recompute all identities from the received bytes before relying on producer claims.

## 11. Negative control contract

Every negative control MUST fail only for its declared reason. A different exception or earlier unrelated failure does not satisfy the control.

Common requirements for NC01-NC32:

EXPECTED_EXIT_STATE=FAIL_CLOSED unless explicitly marked BLOCKED_NOT_PROVEN.
PROHIBITED_FALSE_PASS=MANDATORY.
EXPECTED_ERROR_ID_MATCH=MANDATORY.
EXPECTED_FAILURE_STAGE_MATCH=MANDATORY.
WRONG_FAILURE_REASON_ACCEPTANCE=PROHIBITED.
GENERIC_EXCEPTION_ACCEPTANCE=PROHIBITED.

### NC01 WRONG_TARGET_SHA
TRIGGER=Target bytes SHA256 differs from bound target_sha256.
EXPECTED_FAILURE_STAGE=TARGET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC01-WRONG-TARGET-SHA
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected target SHA, actual target SHA, target path, target size, binding identity
PROHIBITED_FALSE_PASS=Target mismatch must never progress to route self-assurance.

### NC02 WRONG_TARGET_SIZE
TRIGGER=Target size differs from bound target_size_bytes while path remains the same.
EXPECTED_FAILURE_STAGE=TARGET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC02-WRONG-TARGET-SIZE
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected size, actual size, target SHA, binding identity
PROHIBITED_FALSE_PASS=Matching SHA claim or filename must not override size mismatch.

### NC03 WRONG_TARGET_ID
TRIGGER=Target identity or role does not match the binding identity expected by the invocation.
EXPECTED_FAILURE_STAGE=TARGET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC03-WRONG-TARGET-ID
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected target ID/role and actual invocation target ID/role
PROHIBITED_FALSE_PASS=Path or hash equality alone must not satisfy identity mismatch.

### NC04 NON_CURRENT_RULE_SOURCE
TRIGGER=Stable selector cannot resolve a CURRENT pointer on canonical main, or resolved pointer is not CURRENT.
EXPECTED_FAILURE_STAGE=SOURCE_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC04-NON-CURRENT-RULE-SOURCE
EXPECTED_EXIT_STATE=BLOCKED_NOT_PROVEN
EXPECTED_EVIDENCE=repository/ref, selector identity, resolved pointer identity/status, fetch result
PROHIBITED_FALSE_PASS=Cached/local/chat-memory rules must not substitute for current source.

### NC05 RULESET_WORKSPACE_BYTES_MISMATCH
TRIGGER=Any governed rule workspace bytes differ from committed blob bytes or governed EOL identity.
EXPECTED_FAILURE_STAGE=RULESET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC05-RULESET-WORKSPACE-BYTES-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=member path, workspace raw object/hash, committed blob hash, EOL proof, mismatch set
PROHIBITED_FALSE_PASS=Aggregate count or filename presence must not substitute for byte identity.

### NC06 NON_DESKTOP_POWERSHELL
TRIGGER=Native runtime PSEdition is not Desktop.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC06-NON-DESKTOP-POWERSHELL
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=executable path/SHA, PSEdition, PSVersion
PROHIBITED_FALSE_PASS=PowerShell Core must never satisfy Desktop 5.1 proof.

### NC07 NON_5_1_POWERSHELL
TRIGGER=Runtime major/minor is not exactly 5.1.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC07-NON-5-1-POWERSHELL
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=executable identity and exact version
PROHIBITED_FALSE_PASS=Compatible behavior or later PowerShell version is not proof.

### NC08 NATIVE_PARSE_ERROR
TRIGGER=Native Windows PowerShell 5.1 parser returns one or more errors for any governed PowerShell member.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC08-NATIVE-PARSE-ERROR
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=file identity, parse error count, exact parse diagnostics and locations
PROHIBITED_FALSE_PASS=Static review or PS7 parsing must not substitute.

### NC09 STATIC_BUILD_BLOCKING_RULE_MATCH
TRIGGER=Current static detector reports any build-blocking rule violation.
EXPECTED_FAILURE_STAGE=STATIC_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC09-STATIC-BUILD-BLOCKING-RULE-MATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=rule ID, file identity, exact finding location and detector contract identity
PROHIBITED_FALSE_PASS=Warnings/errors from unrelated rules must not satisfy declared violation.

### NC10 PSSCRIPTANALYZER_ERROR_FINDING
TRIGGER=Governed PSScriptAnalyzer run produces one or more error-severity findings.
EXPECTED_FAILURE_STAGE=STATIC_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC10-PSSCRIPTANALYZER-ERROR-FINDING
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=module/version identity and exact findings
PROHIBITED_FALSE_PASS=Missing analyzer, wrong version or suppressed execution must not be treated as zero findings.

### NC11 NEGATIVE_FIXTURE_FALSE_PASS
TRIGGER=A declared negative fixture does not fail at its declared rule/stage/error ID.
EXPECTED_FAILURE_STAGE=REGRESSION_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC11-NEGATIVE-FIXTURE-FALSE-PASS
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=fixture identity, declared expected rule/stage/error, actual outcome
PROHIBITED_FALSE_PASS=Any unrelated exception must not satisfy a negative fixture.

### NC12 POSITIVE_FIXTURE_FALSE_FAIL
TRIGGER=A declared positive fixture triggers the rule it is declared not to trigger or otherwise fails its positive contract.
EXPECTED_FAILURE_STAGE=REGRESSION_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC12-POSITIVE-FIXTURE-FALSE-FAIL
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=fixture identity, declared allowed result, actual rule/error outcome
PROHIBITED_FALSE_PASS=Skipping the fixture or suppressing findings is prohibited.

### NC13 CHILD_EXIT_CODE_NONZERO
TRIGGER=Governed child exits with nonzero exit code when zero is required by the target contract.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC13-CHILD-EXIT-CODE-NONZERO
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=process identity, exit code, stdout, stderr, timestamps
PROHIBITED_FALSE_PASS=Expected output presence must not override nonzero exit.

### NC14 STDERR_UNEXPECTED
TRIGGER=Captured stderr violates the target stderr contract even when child exit code is zero.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC14-STDERR-UNEXPECTED
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=complete stderr, stderr SHA256, target stderr policy and exit code
PROHIBITED_FALSE_PASS=Zero exit code alone must not imply success.

### NC15 TIMEOUT
TRIGGER=Child does not terminate within declared timeout.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC15-TIMEOUT
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=timeout value, start/end, termination action/state, stdout/stderr captured to termination
PROHIBITED_FALSE_PASS=Partial output or eventual late completion must not promote the timed-out attempt.

### NC16 WRONG_WORKING_DIRECTORY
TRIGGER=Effective child working directory differs from the binding contract.
EXPECTED_FAILURE_STAGE=TARGET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC16-WRONG-WORKING-DIRECTORY
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected and actual resolved working directory
PROHIBITED_FALSE_PASS=Equivalent relative-path behavior must not substitute for exact binding.

### NC17 MISSING_EXPECTED_OUTPUT
TRIGGER=One or more mandatory target outputs are absent after child termination.
EXPECTED_FAILURE_STAGE=NATIVE_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC17-MISSING-EXPECTED-OUTPUT
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected output set and actual enumerated output set
PROHIBITED_FALSE_PASS=Exit code zero must not override missing output.

### NC18 OUTPUT_SHA_MISMATCH
TRIGGER=An expected output exists but its SHA256 differs from the output contract or producer-declared identity.
EXPECTED_FAILURE_STAGE=EVIDENCE_CLOSED
EXPECTED_ERROR_ID=ECTOS-V02-NC18-OUTPUT-SHA-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=output path, expected SHA, actual SHA and size
PROHIBITED_FALSE_PASS=Filename/size equality alone is insufficient.

### NC19 MANIFEST_MEMBER_MISSING
TRIGGER=A mandatory package or route manifest member is absent.
EXPECTED_FAILURE_STAGE=EVIDENCE_CLOSED
EXPECTED_ERROR_ID=ECTOS-V02-NC19-MANIFEST-MEMBER-MISSING
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=manifest expected set and actual set with exact missing members
PROHIBITED_FALSE_PASS=Reduced manifest/member count must never be silently accepted.

### NC20 MANIFEST_MEMBER_SHA_MISMATCH
TRIGGER=A manifest member exists but size or SHA256 differs from the manifest.
EXPECTED_FAILURE_STAGE=EVIDENCE_CLOSED
EXPECTED_ERROR_ID=ECTOS-V02-NC20-MANIFEST-MEMBER-SHA-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=member path, expected/actual size and SHA
PROHIBITED_FALSE_PASS=Matching member name is insufficient.

### NC21 TESTED_BYTES_DIFFER_FROM_HANDED_OFF_BYTES
TRIGGER=Any target, route, binding or manifest bytes handed to independent assurance differ from the bytes previously assured.
EXPECTED_FAILURE_STAGE=READY_FOR_INDEPENDENT_HANDOFF
EXPECTED_ERROR_ID=ECTOS-V02-NC21-TESTED-HANDOFF-BYTES-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=tested identities and handed-off recomputed identities
PROHIBITED_FALSE_PASS=Producer declarations must not override qualifier recomputation.

### NC22 STALE_TARGET_BINDING
TRIGGER=Binding no longer matches target bytes/current target registration or is superseded by a newer binding.
EXPECTED_FAILURE_STAGE=TARGET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC22-STALE-TARGET-BINDING
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=binding version/currentness, target identity and supersession evidence
PROHIBITED_FALSE_PASS=Historical validity is not current validity.

### NC23 NESTED_SHELL_INTERPOLATION
TRIGGER=Process construction attempts to place governed child PowerShell inside an outer shell/PowerShell command string or uses `-Command` transport.
EXPECTED_FAILURE_STAGE=ROUTE_SELF_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC23-NESTED-SHELL-INTERPOLATION
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=route source finding, process transport declaration and exact prohibited construct
PROHIBITED_FALSE_PASS=Escaping/backslash tricks must not make nested shell transport acceptable.

### NC24 MALFORMED_PROCESS_ARGUMENT_TRANSPORT
TRIGGER=Argument rendering is lossy, malformed, cannot round-trip declared logical argv, or uses prohibited EncodedCommand/base64 transport.
EXPECTED_FAILURE_STAGE=ROUTE_SELF_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC24-MALFORMED-PROCESS-ARGUMENT-TRANSPORT
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=logical argv, rendered arguments, transport algorithm fixture result and prohibited transport detection if applicable
PROHIBITED_FALSE_PASS=A different early parsing failure must not satisfy this control.

### NC25 UNAUTHORIZED_TARGET_SPECIFIC_LOGIC
TRIGGER=Generic route source contains target-specific names, paths, hashes, branches or conditionals not supplied through declarative binding.
EXPECTED_FAILURE_STAGE=ROUTE_SELF_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC25-UNAUTHORIZED-TARGET-SPECIFIC-LOGIC
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=source file identity and exact target-specific occurrence
PROHIBITED_FALSE_PASS=Renaming or relocating the same specialization to another generic layer is prohibited.

### NC26 UNAUTHORIZED_MUTATION
TRIGGER=Assurance route, target, binding or package member is modified outside an explicitly authorized producer/build step or after assurance closure.
EXPECTED_FAILURE_STAGE=EVIDENCE_CLOSED
EXPECTED_ERROR_ID=ECTOS-V02-NC26-UNAUTHORIZED-MUTATION
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=pre/post identities, mutation set, responsible phase if known
PROHIBITED_FALSE_PASS=Re-hashing mutated bytes does not restore continuity.

### NC27 INCOMPLETE_EVIDENCE_SET
TRIGGER=Any mandatory evidence member/field is missing, unreadable or not hash-closed.
EXPECTED_FAILURE_STAGE=EVIDENCE_CLOSED
EXPECTED_ERROR_ID=ECTOS-V02-NC27-INCOMPLETE-EVIDENCE-SET
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=required evidence schema and exact missing/invalid set
PROHIBITED_FALSE_PASS=Summary claims must not substitute for physical evidence.

### NC28 ASSURANCE_ROUTE_SELF_IDENTITY_MISMATCH
TRIGGER=Route member set, member size/SHA, aggregate manifest, producing commit or route version differs from the expected route self-identity.
EXPECTED_FAILURE_STAGE=ROUTE_SELF_ASSURANCE_COMPLETE
EXPECTED_ERROR_ID=ECTOS-V02-NC28-ASSURANCE-ROUTE-SELF-IDENTITY-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected and actual route manifest/member identities
PROHIBITED_FALSE_PASS=A partially matching route may not execute.

### NC29 PROFILE_SHA_OR_IDENTITY_MISMATCH
TRIGGER=Governed profile canonical SHA, profile ID/version or profile source identity differs from the selector-resolved expected profile.
EXPECTED_FAILURE_STAGE=RULESET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC29-PROFILE-IDENTITY-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=profile source identity, expected canonical SHA, computed canonical SHA, profile ID/version
PROHIBITED_FALSE_PASS=Filename or embedded CURRENT status alone is insufficient.

### NC30 RULESET_MEMBER_COUNT_OR_SET_DIFFERS
TRIGGER=Actual current ruleset member count or exact path set differs from the profile/manifest-declared set.
EXPECTED_FAILURE_STAGE=RULESET_BOUND
EXPECTED_ERROR_ID=ECTOS-V02-NC30-RULESET-MEMBER-SET-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=expected member set, actual member set, missing and unexpected members
PROHIBITED_FALSE_PASS=Composite SHA or partial member checks must not override set mismatch.

### NC31 REQUIRED_GATE_OMITTED_OR_BYPASSED
TRIGGER=A required state-machine gate is omitted, marked complete without evidence, executed out of order, or manually promoted.
EXPECTED_FAILURE_STAGE=STATE_MACHINE
EXPECTED_ERROR_ID=ECTOS-V02-NC31-REQUIRED-GATE-BYPASS
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=transition ledger, required gate sequence, actual gate sequence and missing/out-of-order gate
PROHIBITED_FALSE_PASS=Downstream success cannot compensate for a skipped gate.

### NC32 INDEPENDENT_HANDOFF_IDENTITY_DIFFERS_FROM_PRODUCER_CLOSURE
TRIGGER=Independent qualifier receives or computes target/route/binding/manifest identities different from producer evidence closure.
EXPECTED_FAILURE_STAGE=HANDOFF
EXPECTED_ERROR_ID=ECTOS-V02-NC32-INDEPENDENT-HANDOFF-MISMATCH
EXPECTED_EXIT_STATE=FAIL_CLOSED
EXPECTED_EVIDENCE=producer closure identities and qualifier recomputed identities
PROHIBITED_FALSE_PASS=Producer-provided hashes alone may not be trusted without recomputation.

## 12. HH-01 through HH-09 mandatory closure mapping

HH-01 H02_FORBIDDEN_BEHAVIOR_REMAINS_IMPLEMENTED
- V02 requirement: no LegacyEncodedCommandMode, LegacyEncodedCommandToken, EncodedCommand classifier, Convert::FromBase64String-based transport validation, UTF16LE/base64 EncodedCommand support or equivalent retained interface.

HH-02 H02_SYNTHETIC_RECONSTRUCTION_EXISTS_IN_TESTS
- V02 requirement: no H02 payload reconstruction, no synthetic malformed EncodedCommand/base64 payload family derived from H02. Prove absence structurally; use generic transport integrity fixtures unrelated to H02.

HH-03 NEGATIVE_CONTROL_SET_INCOMPLETE_AND_SEMANTICALLY_DIFFERENT
- V02 requirement: implement exactly NC01-NC32 from this contract. Additional controls are permitted only as additive versioned controls and MUST NOT renumber/redefine NC01-NC32.

HH-04 NEGATIVE_CONTROL_ORACLES_NOT_EXACT_ENOUGH
- V02 requirement: each control requires exact ERROR_ID and stage match. Substring-only exception matching is insufficient.

HH-05 GENERIC_ROUTE_CONTAINS_TARGET_SPECIFIC_LOGIC
- V02 requirement: generic engine receives all target-specific values from binding/manifest only.

HH-06 CURRENT_RULE_IDENTITY_CLOSURE_INCOMPLETE_INSIDE_V01_ROUTE
- V02 requirement: close canonical remote main, selector, resolved pointer, profile canonical SHA, ruleset composite SHA, exact member set, workspace/blob identity.

HH-07 REQUIRED_STATE_MACHINE_NOT_MATERIALIZED
- V02 requirement: durable state machine ledger defined in section 7 is mandatory.

HH-08 FAILED_ATTEMPT_QUARANTINE_AND_CIRCUIT_BREAKER_INTEGRATION_ABSENT
- V02 requirement: immutable per-attempt quarantine plus explicit circuit-breaker state and retry eligibility are mandatory.

HH-09 PACKAGE_AND_EXACT_BYTE_HANDOFF_CONTRACT_NOT_CLOSED
- V02 requirement: package manifest, tested=handed-off byte identity for route/target/binding/manifest, qualifier recomputation and post-assurance mutation count zero are mandatory.

## 13. Historical OS V1 methodology alignment

Reused principles:

- global tooling closure before product execution
- full diagnostic sweep before remediation
- one consolidated defect set
- one versioned systemic successor
- tooling self-assurance
- regression closure
- pre-build/pre-execution acceptance
- runtime identity freeze where applicable
- one-run authority
- one true final E2E
- final E2E is confirmation, not debugging

Non-reusable historical implementation details:

- OS-specific filenames, hashes, paths and package layouts
- historical operator implementations
- historical runtime IDs not applicable to current DEV route

DEV-specific requirements:

- generic target bindings
- current code-rule source resolution
- Windows PowerShell Desktop 5.1 native gates
- NC01-NC32 exact negative-control contract
- independent producer/qualifier byte handoff

NO_ARCHITECTURAL_SUBSTITUTION=YES
CONSTRAINT_RELOCATION=PROHIBITED

## 14. Implementation acceptance gate

A future engineering producer MAY be authorized to build a V02 route successor only when MAIN has physically verified this contract artifact identity and current rule-source currentness.

Build implementation acceptance requires all of the following before any execution authority:

- OBJECTIVE_MATCH=PASS
- ARCHITECTURAL_INTENT_MATCH=PASS
- INVARIANT_MATCH=PASS
- PROHIBITED_BEHAVIOR_ABSENCE=PASS
- NEGATIVE_CONTROLS_IMPLEMENTED_COUNT=32
- NEGATIVE_CONTROLS_EXACT_ORACLE_COUNT=32
- CONSTRAINT_RELOCATION=NO
- ARCHITECTURAL_SUBSTITUTION=NO
- TARGET_SPECIFIC_LOGIC_IN_GENERIC_ROUTE=0
- H02_RECONSTRUCTION=0
- UNKNOWN_ARCHITECTURAL_ASSUMPTION_COUNT=0
- CURRENT_RULE_SOURCE_BOUND=PASS
- CURRENT_RULESET_IDENTITY_BOUND=PASS
- NATIVE_PS51_PARSE=PASS
- STATIC_RULE_GATE=PASS
- PSSCRIPTANALYZER=PASS_WHERE_REQUIRED
- REGRESSION=PASS
- STATE_MACHINE=PASS
- EVIDENCE_CONTRACT=PASS
- FAILED_ATTEMPT_QUARANTINE=PASS
- PACKAGE_MANIFEST=PASS
- TESTED_BYTES_EQUAL_HANDED_OFF_BYTES=PASS
- POST_ASSURANCE_MUTATION_COUNT=0

BUILD != QUALIFICATION.
QUALIFICATION != RELEASE.

## 15. Contract closure declaration

ROUTE_ARCHITECTURE_ID=ECTOS_PS51_SYSTEMIC_ASSURANCE_ROUTE_V02
GENERICITY_CONTRACT=COMPLETE
PROCESS_CONTRACT=COMPLETE
TRUST_BOUNDARY_CONTRACT=COMPLETE
TRUST_BOUNDARY_COUNT=13
NEGATIVE_CONTROL_COUNT=32
NEGATIVE_CONTROL_SET=COMPLETE
EVIDENCE_CONTRACT=COMPLETE
STATE_MACHINE=COMPLETE
FAILURE_POLICY=COMPLETE
PACKAGE_MANIFEST_CONTRACT=COMPLETE
EXACT_BYTE_HANDOFF_CONTRACT=COMPLETE
INDEPENDENT_ASSURANCE_HANDOFF_CONTRACT=COMPLETE
HH_DEFECT_MAPPING_COUNT=9
HISTORICAL_OS_V1_ALIGNMENT=COMPLETE
UNKNOWN_ARCHITECTURAL_ASSUMPTION_COUNT=0
IMPLEMENTATION_CONTRACT_STATE=CLOSED_FOR_NEW_V02_DOCUMENTARY_ARCHITECTURAL_SCOPE
NEXT_EXECUTION_AUTHORITY_ELIGIBLE=NO
NEXT_QUALIFICATION_AUTHORITY_ELIGIBLE=NO

END_OF_CONTRACT
