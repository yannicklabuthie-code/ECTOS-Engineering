# ECTOS — QC02/QC03 reusable authority activation V74 (governed candidate)

Status: ENGINEERING_CANDIDATE_NOT_MAIN_ADMITTED. No change to live G00, V48 or cloud.

## Fundamental correction

There is NO single globally APPROVED product contract for QC02 and no globally TRUSTED tool registry for QC03. The service components can be available even while a particular qualification campaign's *inputs* remain DRAFT. The V48 samples are producer test dossiers, not the permanent authority of the two components.

V48 issue: the authority bridge rejects any registry with !=22 tools. The old GitHub issuer pins one product SHA and exactly 11/22 test records. These are sample campaign values, not universal service invariants.

The isolated successor candidates:
- `authority_bridge_universal_candidate.py`: accepts any **nonempty** registry with unique control IDs, but still needs signed exact registry, native QC03 byte/provenance checks, and externally pinned public key.
- `issue_authority_universal_candidate.py`: requires `GOVERNANCE_APPROVED_TARGET_SHA256` from protected governance variables, consistent QC02/QC03 target, their independent SHA pins, exact positive/negative control sets and all original signature gates. No hardcoded product SHA.
- `strict_authority_gate.py`: unchanged trust and signature verifier dependency.

## Exact answer: who can move DRAFT to APPROVED?

1. **PROJECT_OWNER / authorized requirements authority**: approves the **exact final source and QC02 oracle/specification bytes**, with verified SHA-256. Source observations from producer cannot stand in for the business decision. The authorized final source register uses `contract_state=APPROVED` and `currentness_state=CURRENT` only after that event.
2. **ECTOS tool-provenance/governance authority**: validates each exact tool command, script, execution host, platform and runtime, receipt contents, provenance integrity, and signs or attests each current approval. Registry fields become `tool_trust_state=TRUSTED`, `tool_currentness_state=CURRENT`, `host_trust_state=TRUSTED`, `tool_target_fit=PASS` only with matching independently reviewed evidence. Producer SHA measurements are necessary but not sufficient.
3. **Governed issuer** (not the producer): protected GitHub Actions workflow signs exact QC02 and QC03 subjects with Ed25519, bound to the preapproved digest variables, repository, branch and commit. A second GitHub collaborator is optional and not part of historical UAC required roles.
4. **Windows verifier**: independently provisioned trust policy checks key SHA, revocation, validity and both signatures; native QC02 compiles; native QC03 cross-checks QC02 property-to-control mapping and the actual tool receipts.
5. **Independent QC06 qualifier** separately assesses a package; **ECTOS MAIN** makes the admission decision. Neither is created by signing the two QC02/QC03 input registers.

## Exact acceptance evidence for a target-specific QC02/QC03 pass

- Immutable target package SHA-256.
- Canonical owner-approved requirements source and valid file hash.
- QC02 contract state APPROVED/CURRENT and **complete** non-producer-only oracles bound to source.
- QC03 registry of 1/N tools (nonempty unique IDs), fully mapped to QC02 positive and negative controls.
- Per-tool provenance approval receipts with verified bytes, host, signatures/authority, currentness.
- Two exact Ed25519 signed envelopes from authorized issuer.
- Windows public-key trust root, current validity, revocation controls.
- Native QC02 and QC03 both PASS under their applicable target scopes.

## Proof from engineering campaign

V73 service preflight: PASS_PRODUCER_ONLY. Windows native fail-closed selftest PASS.
V74 candidate cryptographic interoperability: 8/8 with 2 tools, and 8/8 with 22 tools, using synthetic ephemeral test keys. No admission or independent qualification.
The signer's Ed25519 private secret is in owner GitHub environment; host public root installed and pinned. Neither fact authorizes self-signing draft product content.

## Prohibited shortcuts

No replacing DRAFT with APPROVED without exact source authority decision; no generated tool receipts relabeled independent; no producer self-signature presented as independent qualification; no changing ECTOS historical precedence silently; no main merge or cloud deployment implied.
