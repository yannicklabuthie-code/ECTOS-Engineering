# ECTOS Block End-to-End Qualification Method V01

## Status

- Method ID: `ECTOS_BLOCK_END_TO_END_QUALIFICATION_METHOD_V01`
- Status: `CURRENT_CANDIDATE`
- Scope: generic qualification method for ECTOS engineering blocks and their dependency lines.
- Purpose: prevent serial ping-pong remediation, rediscovery of already-solved failure families, and qualification of only the visible component while its delivery, evidence, currentness, tooling, or integration chain remains unproven.
- Authority boundary: this method does not replace Project Governance, Main Authority, code-rule sources, independent qualification, or release authority.

## 1. Core principle

Qualification is not a last-step test of the produced block. Qualification is closure of the complete line required to trust that block.

Required operating sequence:

`GOVERNANCE -> CURRENTNESS -> TARGET CHAIN -> SEARCH-BEFORE-BUILD -> EXISTING ASSET RECOVERY -> AUTHORITATIVE EXTERNAL GUIDANCE -> SYSTEMIC DEFECT FAMILY REVIEW -> ONE CONSOLIDATED DEFECT SET -> ONE VERSIONED ADAPTATION/REMEDIATION -> INDEPENDENT QUALIFICATION -> MAIN ACCEPTANCE -> DOWNSTREAM INTEGRATION`

No block may be declared `PASS`, `QUALIFIED`, `READY`, `PROMOTED`, or `RELEASED` from source existence, producer self-test, static review, branch name, filename, timestamp, or historical memory alone.

## 2. Mandatory Main pre-check

Before any new engineering, execution, qualification, retry, successor, or deployment authority, Main MUST determine at minimum:

- current mission and target;
- current agent/role;
- return count;
- known failure count;
- related failure count;
- repeated root-failure family;
- circuit-breaker state;
- currentness state;
- dependency-closure state;
- integration-readiness state;
- systemic-review state;
- consolidated-defect-set state;
- next-execution-authority eligibility.

If evidence is absent, state is `NOT_PROVEN`.

## 3. Circuit-breaker rule

Trigger systemic stop when any of the following occurs:

- two failures in the same package/family/campaign;
- repeated same or related root failure;
- non-convergent qualify/fix/requalify loop.

When triggered:

- ordinary iteration stops;
- no micro-remediation;
- no renamed helper as bypass;
- no new successor merely to retry the same unknown;
- no blind rerun;
- one systemic review is mandatory;
- one consolidated defect register is mandatory;
- next execution authority remains `NO` until the blocker family is closed enough to justify a new controlled campaign.

## 4. Search-before-build gate

Before building a new validator, collector, materializer, migration script, currentness probe, qualification helper, or transport mechanism, Main MUST search for prior ECTOS assets that already solve all or part of the failure family.

Search scope MUST include, where applicable:

1. current canonical repository sources;
2. historical branches and commits;
3. prior worktrees/packages;
4. package manifests and dependency graphs;
5. validators, schemas, tests, fixtures, negative controls and receipts;
6. pull requests and review findings;
7. historical defect catalogs and routing/currentness contracts;
8. previous qualification evidence and Main acceptance evidence.

The output MUST classify the existing asset as one of:

- `REUSE_AS_IS`;
- `ADAPT_EXISTING_ASSET`;
- `BUILD_NEW`;
- `BLOCKED_NOT_PROVEN`.

Names are not evidence. Physical source identity and scope are required.

## 5. Reuse-before-recreate rule

When an historical ECTOS component already solves a meaningful part of the current failure family:

- preserve the proven primitives;
- preserve applicable tests and negative controls;
- identify only the current capability gaps;
- adapt the existing asset rather than create a parallel ad-hoc tool;
- do not inherit historical qualification unless exact qualification and Main-acceptance evidence is physically recovered;
- if historical qualification is not proven, the adapted successor must be independently qualified as a new complete candidate.

Producer self-assurance is not independent qualification.

## 6. External authoritative guidance gate

For failures involving a platform, runtime, operating system, file system, Git, PowerShell, Python, cloud service, protocol, or vendor API, Main MUST review authoritative platform guidance before issuing a remediation design.

Examples include:

- Microsoft documentation for Windows PowerShell/.NET behavior;
- official Git documentation for checkout, attributes, hashes, line endings, refs and worktree semantics;
- official runtime or SDK documentation.

External guidance is used to constrain the engineering method; it does not override ECTOS governance.

## 7. Complete target-chain review

Before qualification of a block, map the whole target chain, including where applicable:

- source identity;
- currentness selector/pointer;
- target environment;
- runtime/OS;
- dependencies;
- interfaces;
- paths;
- authentication/authorization;
- configuration;
- build/package process;
- delivery/materialization mechanism;
- transaction/atomicity semantics;
- entrypoints;
- parser/load/startability behavior;
- negative controls;
- post-install/post-build verification;
- rollback/safe-stop semantics;
- evidence collection;
- downstream consumers;
- known historical failure families.

A block is not integration-ready while a required upstream mechanism is `NOT_PROVEN`.

## 8. Systemic defect-family review

Do not patch only the last error line.

For the complete relevant source and execution chain:

1. read the full relevant implementation;
2. trace upstream and downstream dependencies;
3. identify all defects of the same family;
4. perform change-impact analysis;
5. classify local vs systemic;
6. continue safe analysis beyond the first defect;
7. return one consolidated known-defect set.

Valid systemic end states:

- `PASS`;
- `FAIL_WITH_COMPLETE_KNOWN_DEFECT_SET`;
- `BLOCKED_NOT_PROVEN_WITH_EXACT_UNREACHABLE_SCOPE`.

## 9. Qualification-line decomposition

Each engineering block MUST distinguish at least:

1. **Producer scope** — creates or adapts the candidate.
2. **Static/systemic review scope** — verifies complete source/package/member/dependency closure without promoting runtime claims.
3. **Independent qualifier scope** — executes the frozen candidate and its negative controls.
4. **Main acceptance scope** — adjudicates evidence and authorizes downstream progression.
5. **Release/admission scope** — separate where applicable.

`PRODUCER != QUALIFIER != ADMISSION_AUTHORITY`.

## 10. Qualification campaign design

Before execution, define the complete qualification campaign in advance.

It MUST include:

- positive controls;
- negative controls;
- false-pass challenges;
- missing-evidence behavior;
- wrong-input behavior;
- partial/unreachable behavior;
- one-component-fails/others-continue behavior where systemic enumeration is required;
- exact stdout/stderr/exit-code requirements where applicable;
- runtime and working-directory binding;
- start/end timestamps;
- package/member/SHA binding;
- no protected-object mutation proof;
- deterministic evidence receipt.

Do not discover basic pre-detectable defects through owner-first or qualification-first execution.

## 11. Evidence-source hierarchy

Use the strongest available source first:

1. current canonical governing source;
2. exact current physical repository/workspace evidence;
3. frozen candidate/package identity;
4. independent qualification receipt;
5. Main acceptance receipt;
6. historical source for provenance only;
7. chat/model memory only as non-authoritative context.

Historical evidence may explain a design, but may not be promoted to current qualification without currentness proof.

## 12. Currentness rule

Filename, version label, branch name, timestamp, and file presence do not prove currentness.

Allowed states:

- `CURRENT`;
- `HISTORICAL`;
- `SUPERSEDED`;
- `PARTIAL`;
- `NOT_PROVEN`.

Current selector/pointer/governance overrides historical embedded status.

## 13. Tool-selection method

When the visible failure may be caused by the inspection tool itself, stop using the failing inspection path after circuit-breaker trigger.

Then:

1. inspect prior ECTOS tooling for the same evidence family;
2. inspect authoritative platform-native primitives;
3. compare capabilities against the current requirement matrix;
4. reuse existing low-level primitives that already solve the problem;
5. add only missing orchestration/contract/receipt behavior;
6. independently qualify the adapted tool before using it to qualify downstream blocks.

This prevents the anti-pattern:

`collector -> collector fix -> collector successor -> another collector`.

## 14. Current case pattern captured for future reuse

The Workspace Byte Identity investigation established a reusable pattern:

- an ad-hoc PowerShell collector failed repeatedly;
- Main stopped ordinary iteration;
- Git history was searched for existing ECTOS capability;
- historical `ECTOS_SYSTEMIC_WORKSPACE_BYTE_IDENTITY` assets were recovered;
- official Git/Microsoft behavior was reviewed;
- existing raw-byte, Git-object, EOL and currentness primitives were retained;
- the current requirements were compared against historical capabilities;
- only the missing systemic gaps were retained for adaptation;
- historical qualification remained `NOT_PROVEN` where receipts were unavailable;
- the future adapted candidate was required to undergo complete independent qualification instead of inheriting a historical PASS.

This pattern is normative for future ECTOS block qualification when an equivalent historical capability exists.

## 15. Reuse/adapt/build decision contract

### REUSE_AS_IS

Allowed only when current scope, currentness, dependencies, qualification evidence, interfaces and negative controls all match the new target.

### ADAPT_EXISTING_ASSET

Preferred when the historical/current asset contains proven primitives but lacks current orchestration, scope, evidence fields, contracts, schemas, negative controls, or integration requirements.

Adaptation MUST produce one consolidated gap register before code change.

### BUILD_NEW

Allowed only when search-before-build proves no adequate existing asset can be reused or safely adapted.

### BLOCKED_NOT_PROVEN

Required when the evidence needed to make the decision is physically unavailable and cannot safely be recovered.

## 16. One-versioned-successor rule

After systemic review and exact gap closure:

- create at most one versioned successor for the consolidated family;
- do not mutate failed/historical evidence packages in place;
- bind exact base commit;
- bind exact changed/new/removed members;
- close manifest and dependency graph after source freeze;
- run complete static review;
- freeze exact candidate identity;
- route to independent qualification.

If new systemic evidence invalidates the closed gap set, stop and return to Main rather than serially patching.

## 17. End-to-end block closure criteria

A block may progress downstream only when all applicable gates are physically proven:

- governance/currentness closed;
- source identity closed;
- complete dependency chain closed;
- delivery/materialization mechanism closed;
- package/member/SHA closure complete;
- objective match `PASS`;
- architectural intent match `PASS`;
- invariant match `PASS`;
- prohibited behavior absence `PASS`;
- negative controls `PASS`;
- no constraint relocation;
- no architectural substitution;
- independent qualification `PASS` for the exact frozen candidate;
- Main acceptance recorded;
- downstream integration prerequisites closed.

Build success alone is insufficient.

## 18. Relation to ECTOS DEV

This method is intended to become the generic qualification path used by ECTOS DEV blocks, but this V01 does not itself declare ECTOS DEV end-to-end qualified.

For ECTOS DEV, Main must map each actual block onto this method, including at minimum the rule-source/currentness layer, engineering/delivery mechanisms, package construction, independent qualification, UA01/admission controls, cloud/integration handoff where applicable, and final product evidence.

That mapping must be a separate physically reviewed ECTOS DEV qualification-chain contract.

## 19. Mandatory anti-ping-pong rule

When Main recognizes a repeated scenario from project history, Main MUST search the project history and authoritative external platform guidance before issuing another producer/qualifier prompt.

The user/owner must not be required to rediscover or point Main manually to an already-existing ECTOS mechanism before Main performs this search.

`SEARCH_BEFORE_ROUTE = MANDATORY_AFTER_REPEATED_OR_FAMILIAR_FAILURE`.

## 20. Required future return fields

Any qualification-line mission based on this method should return at least:

- mission ID;
- target block;
- currentness state;
- failure/related-failure counters;
- circuit-breaker state;
- existing-asset search result;
- reuse/adapt/build decision;
- authoritative external guidance reviewed;
- complete target-chain state;
- consolidated defect/gap set;
- unknown assumption count;
- unreachable scope;
- candidate identity;
- independent qualification state;
- Main acceptance state;
- downstream eligibility;
- final state.

---

`END OF ECTOS BLOCK END-TO-END QUALIFICATION METHOD V01`
