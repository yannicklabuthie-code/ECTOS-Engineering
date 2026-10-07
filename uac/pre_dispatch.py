from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from byte_contract import validate_canonical_json_file
from uac_core import UACDenied


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _safe_repo_path(root: Path, declared: str) -> Path:
    if not isinstance(declared, str) or not declared.strip():
        raise UACDenied("DECLARED_ARTIFACT_PATH_INVALID")
    root = root.resolve()
    candidate = (root / declared).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise UACDenied(f"DECLARED_ARTIFACT_PATH_ESCAPES_ROOT:{declared}") from exc
    if not candidate.is_file():
        raise UACDenied(f"DECLARED_ARTIFACT_NOT_FOUND:{declared}")
    return candidate


def _git(*args: str, cwd: Path, binary: bool = False):
    result = subprocess.run(
        ["git", *args], cwd=str(cwd), capture_output=True,
        text=not binary, check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace") if binary else result.stderr
        raise UACDenied("GIT_IDENTITY_CHECK_FAILED:" + stderr.strip())
    return result.stdout


def verify_pre_dispatch(
    repo_root: Path,
    source_commit: str,
    package_path: str,
    manifest_path: str,
    dependency_graph_path: str,
    request_path: str,
) -> dict:
    repo_root = repo_root.resolve()
    staging_commit = str(_git("rev-parse", "HEAD", cwd=repo_root)).strip().lower()
    if not isinstance(source_commit, str) or len(source_commit) != 40:
        raise UACDenied("SOURCE_COMMIT_INVALID")
    try:
        int(source_commit, 16)
    except ValueError as exc:
        raise UACDenied("SOURCE_COMMIT_INVALID") from exc

    declared = {
        "package": package_path,
        "manifest": manifest_path,
        "dependency_graph": dependency_graph_path,
        "request": request_path,
    }
    receipts = {}
    for role, relative in declared.items():
        path = _safe_repo_path(repo_root, relative)
        git_path = relative.replace("\\", "/")
        blob = _git("cat-file", "blob", f"{staging_commit}:{git_path}", cwd=repo_root, binary=True)
        worktree = path.read_bytes()
        if blob != worktree:
            raise UACDenied(f"WORKTREE_GIT_BLOB_BYTE_MISMATCH:{role}:{relative}")
        receipts[role] = {
            "declared_path": git_path,
            "size_bytes": len(worktree),
            "sha256": _sha256(worktree),
        }

    validate_canonical_json_file(_safe_repo_path(repo_root, manifest_path))
    validate_canonical_json_file(_safe_repo_path(repo_root, dependency_graph_path))
    request = validate_canonical_json_file(_safe_repo_path(repo_root, request_path))
    if request.get("source_commit", "").lower() != source_commit.lower():
        raise UACDenied("REQUEST_SOURCE_COMMIT_MISMATCH")
    if request.get("package_sha256", "").lower() != receipts["package"]["sha256"]:
        raise UACDenied("REQUEST_PACKAGE_SHA256_MISMATCH")
    if request.get("manifest_sha256", "").lower() != receipts["manifest"]["sha256"]:
        raise UACDenied("REQUEST_MANIFEST_SHA256_MISMATCH")
    if request.get("dependency_graph_sha256", "").lower() != receipts["dependency_graph"]["sha256"]:
        raise UACDenied("REQUEST_DEPENDENCY_GRAPH_SHA256_MISMATCH")
    return {
        "schema_id": "ECTOS_UAC_PRE_DISPATCH_RECEIPT_V02",
        "decision": "PASS",
        "source_commit": source_commit.lower(),
        "staging_commit": staging_commit,
        "files": receipts,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--package-path", required=True)
    parser.add_argument("--manifest-path", required=True)
    parser.add_argument("--dependency-graph-path", required=True)
    parser.add_argument("--request-path", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        receipt = verify_pre_dispatch(
            Path(args.repo_root), args.source_commit, args.package_path, args.manifest_path,
            args.dependency_graph_path, args.request_path,
        )
        Path(args.output).write_bytes((json.dumps(receipt, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8"))
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except UACDenied as exc:
        print(json.dumps({"decision":"DENY","reason":str(exc)}, sort_keys=True))
        return 40


if __name__ == "__main__":
    raise SystemExit(main())
