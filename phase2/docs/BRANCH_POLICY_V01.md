# ECTOS GitHub branch policy V01

Authoritative branch: `main`

Required model:

`work branch -> pull request -> required automated checks -> review where required -> merge`

Direct uncontrolled push to `main`: prohibited.

Required check contract is machine-readable in `ci/policies/required-checks-v01.json`.

Phase 2 does not alter Factory V08, current V03, Core, G00/L01-L05, or any already-qualified package.
