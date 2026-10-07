# ECTOS Universal Admission Control (UAC)

This directory materializes the ECTOS UAC control-plane implementation.

## Invariant

No ECTOS-produced candidate may be promoted to handoff eligibility unless a current UAC decision is `ADMIT` and a machine-verifiable receipt is issued for the exact actor, mission, package, manifest, dependency graph, source repository, source commit, authority evidence and handoff transaction.

Default state is `DENY`.

## Qualification boundary

UAC qualifies only what ECTOS creates and controls: source identity, package contents and structure, manifest and hashes, declared dependencies, interfaces and package contracts, fixtures and regression tests, documented compatibility claims, admission authority, pre-dispatch provenance and exact candidate identity.

UAC does **not** qualify the consumer environment itself. Cloud/GCP, Firebase, Cloud Run, AWS, Azure, Flutter consumer runtime and any other downstream environment are outside ECTOS package qualification scope.

The terminal UAC boundary is `PACKAGE_READY_FOR_HANDOFF`, not `TARGET_ENVIRONMENT_READY`.

The machine-readable scope is frozen in `uac/config/scope_contract.json` and regression-tested.

## Trust and byte-identity model

The control plane is fail-closed and requires:

- exact Git source-commit existence and ancestry;
- raw worktree bytes equal to the source-commit blobs for the complete source tree, excluding only the explicitly bound admission-request metadata path;
- no staging delta outside that request metadata path;
- canonical UTF-8 JSON where canonical JSON is required;
- exact package, manifest and dependency-graph SHA-256 binding;
- a time-bounded `PRE_DISPATCH_RECEIPT` bound to source repository, source commit, staging commit, source-tree identity, mission, package and exact staged path set;
- a registered, enabled, role-bound and receipt-key-bound admission authority;
- independent authority evidence verified with RSA PKCS#1 v1.5 SHA-256 **public keys only**;
- distinct public-key fingerprints for distinct independent authority identities;
- governance currentness from signed authority evidence rather than caller assertion;
- atomic, durable, concurrency-safe nonce and receipt consumption;
- final handoff receipt and descriptor binding to the exact pre-dispatch receipt and staged-path identity.

The admission verifier must never receive independent-authority private signing material. `ECTOS_UAC_EVIDENCE_PUBLIC_KEYS` is a JSON public-key ring and every entry must declare `key_use: VERIFY_ONLY`. Independent authority private keys remain outside the verifier and outside this repository.

The central UAC admission receipt remains separately signed with `ECTOS_UAC_SIGNING_KEY`. This key is not an independent qualifier/systemic/Main authority key and must not be reused for those identities.

## Commands

Run tests:

```bash
python -m unittest discover -s uac/tests -v
```

Evaluate an admission request:

```bash
python uac/uac_cli.py admit --request request.json --signing-key-env ECTOS_UAC_SIGNING_KEY --authority-public-keyring-env ECTOS_UAC_EVIDENCE_PUBLIC_KEYS
```

Verify and consume an admission receipt:

```bash
python uac/uac_cli.py verify --receipt receipt.json --target <target> --action <action> --signing-key-env ECTOS_UAC_SIGNING_KEY --consume
```

## Operational boundary

The signing key and all independent-authority private keys MUST be supplied out-of-band to their authorized issuers and MUST NOT be committed to this repository. Missing keys, missing public trust anchors, stale evidence, byte drift, unknown authority identity, non-atomic replay state, or pre-dispatch mismatch cause `DENY`.
