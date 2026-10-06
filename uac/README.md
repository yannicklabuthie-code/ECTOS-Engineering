# ECTOS Universal Admission Control (UAC)

This directory materializes the first physical ECTOS UAC control-plane implementation.

## Invariant

No execution-relevant promotion is eligible unless a current UAC decision is `ADMIT` and a machine-verifiable receipt is issued for the exact actor, mission, package, manifest, target and action.

Default state is `DENY`.

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
- negative regression tests.

## Important boundary

This repository remains the engineering rule source. UAC does not become universally non-bypassable until every external execution surface (Windows, Cloud/GCP, Firebase, GitHub mutation, Flutter deployment, Work and future execution targets) is routed through a UAC-enforcing broker or target-side verifier and direct credentials/routes are removed.

Therefore repository implementation alone MUST NOT be reported as global UAC closure.

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
