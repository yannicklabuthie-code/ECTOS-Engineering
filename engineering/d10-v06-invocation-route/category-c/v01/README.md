# ECTOS D10 V06 Invocation Route — Category C V01

Versioned engineering tooling successor for the governed transport family:

`MAIN/AGENT -> GitHub -> GitHub Actions -> self-hosted Windows -> SUCCEESMINDSET -> exact V06 -> mission -> submit -> RUN_ID -> status -> result -> artifacts -> hashed return`.

The successor does not modify V06 and has no Remote Desktop Commander execution dependency. It accepts exact mission bytes embedded as base64 inside a governed invocation object, verifies the declared mission SHA256, verifies the exact V06 package path and SHA256, binds runner and machine identity, writes the exact mission bytes on the authorized Windows runner, performs exactly one V06 submit, reuses the returned RUN_ID for status/result/download, captures process stdout/stderr/exit codes/time bounds, hashes recovered artifacts, and emits a governed return.

## Governed invocation

Create one invocation commit whose parent is the admitted tooling-successor commit, then dispatch this workflow with the exact invocation commit SHA, repository-relative invocation path, and invocation-object SHA256. The workflow checks out that exact commit with its parent, the route verifies the invocation declares the physical parent tooling commit, and execution proceeds without owner process launch or owner mission-file creation on Windows.

A persistent invocation-ID guard under `C:\dev\ECTOS_V06_CATEGORY_C_STATE` prevents a workflow rerun from silently submitting the same governed invocation twice.

## Engineering assurance

Pushes to `methodology/d10-v06-invocation-route-category-c-v01` run only non-D10 engineering assurance on the self-hosted Windows runner. Real D10 Phase A/B are not part of this producer mission.
