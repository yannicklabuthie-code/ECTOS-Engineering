# QP-001 Route B Change Impact V01

Scope: read-only exact QP-001 Windows evidence capture only.

Changed/added surfaces:
- existing governed `.github/workflows/ectos-engineering-assurance.yml`: one additive Route B job only; existing sample-package jobs preserved;
- `phase2/ci/scripts/Rehydrate-ECTOSQP001RouteBTargets.py`: deterministic exact-byte reconstruction with SHA fail-closed;
- `phase2/ci/scripts/Capture-ECTOSQP001WindowsEvidence.py`: Windows read-only evidence capture;
- `phase2/ci/scripts/Test-ECTOSExactTargetWindowsAssurance.py`: exact-target assurance helper;
- `phase2/ci/targets/*`: deterministic source material and target identity metadata.

Explicit non-impact:
- no QP-001 runner V02 mutation;
- no Validator V03 mutation;
- no Product V04 mutation;
- no V06 mutation;
- no key generation;
- no trust anchor materialization;
- no Cloud/product execution;
- no deployment;
- no `main` merge.

Route B job uses the existing `[self-hosted, Windows, X64, ectos-ps51]` governed lane. New Route B commands are `cmd` + Python; no new PowerShell source/script is introduced by Route B.

Fail-closed rules:
- rehydrated runner SHA mismatch => stop;
- rehydrated validator SHA mismatch => stop;
- exact entrypoint SHA mismatch => stop;
- wrong-hash negative tests must return nonzero;
- absent physical Windows evidence remains NOT_PROVEN.
