# ECTOS Universal Admission Control (UAC)

This directory materializes the first physical ECTOS UAC control-plane implementation.

## Invariant

No ECTOS-produced candidate may be promoted to handoff eligibility unless a current UAC decision is `ADMIT` and a machine-verifiable receipt is issued for the exact actor, mission, package, manifest, target and action.

Default state is `DENY`.

## Qualification boundary

UAC qualifies only what ECTOS creates and controls:

- source code produced by ECTOS;
- package contents and structure;
- package manifest and hashes;
- declared dependencies;
- declared interfaces and package contracts;
- fixtures and regression tests;
- documented compatibility claims;
- handoff contract and exact candidate identity.

UAC does **not** qualify the consumer environment itself. Cloud/GCP, Firebase, Cloud Run, AWS, Azure, Flutter consumer runtime and any other downstream environment are outside ECTOS package qualification scope.

ECTOS may and must validate an external contract when the package declares that it supports that contract. This validates **our emitted interface/contract behavior**, not the provider environment.

The terminal UAC boundary is:

`PACKAGE_READY_FOR_HANDOFF`

It is not:

`TARGET_ENVIRONMENT_READY`

The machine-readable scope is frozen in `uac/config/scope_contract.json` and regression-tested.

## Scope of this implementation

This implementation provides:

- actor / target / route registries;
- default-deny admission evaluation;
- package and manifest identity binding;
- qualification + systemic-assurance gates;
- governance/rule currentness gates;
- circuit-breaker enforcement;
- HMAC-SHA256 signed receipts;
- expiry and nonce binding;
- replay prevention ledger;
- receipt verification CLI;
- package-scope and negative regression tests.

## Important boundary

This repository remains the engineering rule source. Repository promotion and package-handoff admission must be physically enforced before UAC closure can be claimed for ECTOS-produced artifacts.

External runtime adaptation, deployment and runtime qualification remain the responsibility of the consuming environment and are not UAC qualification criteria.

## Commands

Run tests:

```bash
python -m unittest discover -s uac/tests -v
```

Evaluate an admission request:

```bash
python uac/uac_cli.py admit --request request.json --signing-key-env ECTOS_UAC_SIGNING_KEY
```

Verify and consume a receipt:

```bash
python uac/uac_cli.py verify --receipt receipt.json --target <target> --action <action> --signing-key-env ECTOS_UAC_SIGNING_KEY --consume
```

The signing key MUST be supplied out-of-band through the execution environment and MUST NOT be committed to the repository.
