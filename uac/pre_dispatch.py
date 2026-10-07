from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

from byte_contract import canonical_json_bytes, validate_canonical_json_file
from uac_core import UACDenied


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _safe_repo_path(root: Path, declared: str) -> Path:
    if not isinstance(declared, str) or not declared.strip():
        raise UACDenied("DECLARED_ARTIFACT_PATH_INVALID")
    normalized = declared.replace("\\", "/")
    if normalized.startswith("/") or normalized.startswith("../") or "/../" in f"/{normalized}/":
        raise UACDenied(f"DECLARED_ARTIFACT_PATH_ESCAPES_ROOT:{declared}")
    root = root.resolve()
    candidate = (root / normalized).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise UACDenied(f"DECLARED_ARTIFACT_PATH_ESCAPES_ROOT:{declared}") from exc
    if not candidate.is_file():
        raise UACDenied(f"DECLARED_ARTIFACT_NOT_FOUND:{declared}")
    return candidate


def _git(*args: str, cwd: Path, binary: bool = False):
    result = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, text=not binary, check=False)
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace") if binary else result.stderr
        raise UACDenied("GIT_IDENTITY_CHECK_FAILED:" + stderr.strip())
    return result.stdout


def _validate_commit(repo_root: Path, source_commit: str) -> tuple[str, str]:
    if not isinstance(source_commit, str) or len(source_commit) != 40:
        raise UACDenied("SOURCE_COMMIT_INVALID")
    try:
        int(source_commit, 16)
    except ValueError as exc:
        raise UACDenied("SOURCE_COMMIT_INVALID") from exc
    probe = subprocess.run(["git", "cat-file", "-e", f"{source_commit}^{{commit}}"], cwd=str(repo_root), capture_output=True, check=False)
    if probe.returncode != 0:
        raise UACDenied("SOURCE_COMMIT_NOT_FOUND")
    staging_commit = str(_git("rev-parse", "HEAD", cwd=repo_root)).strip().lower()
    ancestor = subprocess.run(["git", "merge-base", "--is-ancestor", source_commit, staging_commit], cwd=str(repo_root), capture_output=True, check=False)
    if ancestor.returncode != 0:
        raise UACDenied("SOURCE_COMMIT_NOT_ANCESTOR_OF_STAGING_COMMIT")
    return source_commit.lower(), staging_commit


def _tracked_blob_paths(repo_root: Path, commit: str) -> list[str]:
    raw = _git("ls-tree", "-r", "-z", "--name-only", commit, cwd=repo_root, binary=True)
    paths = [p.decode("utf-8", errors="strict") for p in raw.split(b"\0") if p]
    if not paths:
        raise UACDenied("SOURCE_COMMIT_TREE_EMPTY")
    return sorted(paths, key=lambda p: p.encode("utf-8"))


def _workspace_bytes(path: Path) -> bytes:
    if path.is_symlink():
        return os.readlink(path).encode("utf-8")
    if not path.exists() or not path.is_file():
        raise UACDenied(f"SOURCE_WORKTREE_MEMBER_MISSING:{path.as_posix()}")
    return path.read_bytes()


def _verify_source_tree(repo_root: Path, source_commit: str, excluded_metadata_path: str) -> tuple[str, int]:
    digest = hashlib.sha256()
    count = 0
    for relative in _tracked_blob_paths(repo_root, source_commit):
        if relative == excluded_metadata_path:
            continue
        path = repo_root / Path(relative)
        workspace = _workspace_bytes(path)
        blob = _git("cat-file", "blob", f"{source_commit}:{relative}", cwd=repo_root, binary=True)
        if workspace != blob:
            raise UACDenied(f"SOURCE_WORKTREE_GIT_BYTE_MISMATCH:{relative}")
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(workspace)
        digest.update(b"\0")
        count += 1
    if count == 0:
        raise UACDenied("SOURCE_TREE_EMPTY_AFTER_METADATA_EXCLUSION")
    return digest.hexdigest(), count


def _verify_staging_delta(repo_root: Path, source_commit: str, staging_commit: str, request_path: str) -> None:
    raw = _git("diff", "--name-only", "-z", source_commit, staging_commit, cwd=repo_root, binary=True)
    changed = {p.decode("utf-8", errors="strict") for p in raw.split(b"\0") if p}
    unexpected = sorted(changed - {request_path})
    if unexpected:
        raise UACDenied("STAGING_COMMIT_UNAUTHORIZED_SOURCE_DELTA:" + ",".join(unexpected))


def verify_pre_dispatch(
    repo_root: Path,
    source_commit: str,
    package_path: str,
    manifest_path: str,
    dependency_graph_path: str,
    request_path: str,
    ttl_seconds: int = 900,
) -> dict:
    repo_root = repo_root.resolve()
    request_git_path = request_path.replace("\\", "/")
    source_commit, staging_commit = _validate_commit(repo_root, source_commit)
    _verify_staging_delta(repo_root, source_commit, staging_commit, request_git_path)
    source_tree_sha256, source_file_count = _verify_source_tree(repo_root, source_commit, request_git_path)

    declared = {"package": package_path, "manifest": manifest_path, "dependency_graph": dependency_graph_path, "request": request_path}
    receipts = {}
    staged_path_set = {}
    for role, relative in declared.items():
        path = _safe_repo_path(repo_root, relative)
        git_path = relative.replace("\\", "/")
        binding_commit = staging_commit if role == "request" else source_commit
        blob = _git("cat-file", "blob", f"{binding_commit}:{git_path}", cwd=repo_root, binary=True)
        worktree = _workspace_bytes(path)
        if blob != worktree:
            raise UACDenied(f"WORKTREE_GIT_BLOB_BYTE_MISMATCH:{role}:{relative}")
        receipts[role] = {"declared_path": git_path, "binding_commit": binding_commit, "size_bytes": len(worktree), "sha256": _sha256(worktree)}
        staged_path_set[role] = "source/" + git_path

    validate_canonical_json_file(_safe_repo_path(repo_root, manifest_path))
    validate_canonical_json_file(_safe_repo_path(repo_root, dependency_graph_path))
    request = validate_canonical_json_file(_safe_repo_path(repo_root, request_path))
    if request.get("source_commit", "").lower() != source_commit:
        raise UACDenied("REQUEST_SOURCE_COMMIT_MISMATCH")
    if not isinstance(request.get("source_repository"), str) or not request.get("source_repository"):
        raise UACDenied("REQUEST_SOURCE_REPOSITORY_MISSING")
    if request.get("package_sha256", "").lower() != receipts["package"]["sha256"]:
        raise UACDenied("REQUEST_PACKAGE_SHA256_MISMATCH")
    if request.get("manifest_sha256", "").lower() != receipts["manifest"]["sha256"]:
        raise UACDenied("REQUEST_MANIFEST_SHA256_MISMATCH")
    if request.get("dependency_graph_sha256", "").lower() != receipts["dependency_graph"]["sha256"]:
        raise UACDenied("REQUEST_DEPENDENCY_GRAPH_SHA256_MISMATCH")

    now = datetime.now(timezone.utc)
    staged_path_set_sha256 = _sha256(canonical_json_bytes(staged_path_set))
    return {
        "schema_id": "ECTOS_UAC_PRE_DISPATCH_RECEIPT_V03",
        "decision": "PASS",
        "issued_at": now.isoformat(),
        "expires_at": (now + timedelta(seconds=ttl_seconds)).isoformat(),
        "package_id": request.get("package_id"),
        "mission_id": request.get("mission_id"),
        "source_repository": request.get("source_repository"),
        "source_commit": source_commit,
        "staging_commit": staging_commit,
        "source_tree_sha256": source_tree_sha256,
        "source_file_count": source_file_count,
        "metadata_exclusion": request_git_path,
        "staged_path_set": staged_path_set,
        "staged_path_set_sha256": staged_path_set_sha256,
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
        receipt = verify_pre_dispatch(Path(args.repo_root), args.source_commit, args.package_path, args.manifest_path, args.dependency_graph_path, args.request_path)
        Path(args.output).write_bytes(canonical_json_bytes(receipt))
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except UACDenied as exc:
        print(json.dumps({"decision": "DENY", "reason": str(exc)}, sort_keys=True))
        return 40


if __name__ == "__main__":
    raise SystemExit(main())
