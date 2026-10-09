from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

COMMIT_RE = re.compile(r"^[A-Fa-f0-9]{40}$")
PACKAGE_MANIFEST_REL = "governance/workspace-identity/ECTOS_WORKSPACE_BYTE_IDENTITY_PACKAGE_MANIFEST_V02.json"
DEPENDENCY_GRAPH_REL = "governance/workspace-identity/ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01.json"
METADATA_PATHS = {PACKAGE_MANIFEST_REL, DEPENDENCY_GRAPH_REL}


class D10CurrentnessError(ValueError):
    pass


def _git(root: Path, *args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=text,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() if text else result.stderr.decode(errors="replace").strip()
        raise D10CurrentnessError(f"GIT_COMMAND_FAILED:{' '.join(args)}:{stderr}")
    return result.stdout


def _normalize_repository(value: str) -> str:
    normalized = value.strip().replace("\\", "/")
    if normalized.endswith(".git"):
        normalized = normalized[:-4]
    if normalized.startswith("https://github.com/"):
        normalized = normalized[len("https://github.com/"):]
    if normalized.startswith("git@github.com:"):
        normalized = normalized[len("git@github.com:"):]
    return normalized.strip("/")


def _branch_ref(branch: str) -> str:
    value = branch.strip()
    if not value:
        raise D10CurrentnessError("GOVERNED_BRANCH_REQUIRED")
    if value.startswith("refs/heads/"):
        return value
    if value.startswith("refs/"):
        raise D10CurrentnessError("GOVERNED_BRANCH_REF_INVALID")
    return f"refs/heads/{value}"


def _live_remote_head(root: Path, branch: str) -> str:
    ref = _branch_ref(branch)
    output = str(_git(root, "ls-remote", "origin", ref)).strip()
    rows = [line for line in output.splitlines() if line.strip()]
    if len(rows) != 1:
        raise D10CurrentnessError("LIVE_REMOTE_BRANCH_HEAD_NOT_EXACTLY_ONE")
    sha, returned_ref = rows[0].split("\t", 1)
    if returned_ref != ref or not COMMIT_RE.fullmatch(sha):
        raise D10CurrentnessError("LIVE_REMOTE_BRANCH_HEAD_INVALID")
    return sha.lower()


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _compute_package_sha256(members: list[dict[str, Any]]) -> str:
    payload = "".join(
        f"{m['path']}\0{m['size_bytes']}\0{str(m['sha256']).upper()}\n"
        for m in sorted(members, key=lambda item: item["path"])
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest().upper()


def _require_commit(name: str, value: Any) -> str:
    if not isinstance(value, str) or not COMMIT_RE.fullmatch(value):
        raise D10CurrentnessError(f"{name}_INVALID")
    return value.lower()


def _find_exact_sha_value(value: Any, sha: str) -> bool:
    if isinstance(value, dict):
        return any(_find_exact_sha_value(item, sha) for item in value.values())
    if isinstance(value, list):
        return any(_find_exact_sha_value(item, sha) for item in value)
    return isinstance(value, str) and value.lower() == sha.lower()


def validate_dual_identity_currentness(
    root: Path,
    expected_repository: str,
    expected_branch: str,
    mission: dict[str, Any],
    materialization: dict[str, Any],
    manifest: dict[str, Any],
    graph: dict[str, Any],
) -> dict[str, Any]:
    root = root.resolve()
    origin = _normalize_repository(str(_git(root, "remote", "get-url", "origin")).strip())
    if origin != _normalize_repository(expected_repository):
        raise D10CurrentnessError("ORIGIN_REPOSITORY_MISMATCH")
    current_branch = str(_git(root, "branch", "--show-current")).strip()
    if current_branch != expected_branch:
        raise D10CurrentnessError("LOCAL_GOVERNED_BRANCH_MISMATCH")

    metadata_head = _require_commit("LOCAL_HEAD", str(_git(root, "rev-parse", "HEAD")).strip())
    live_remote_head = _live_remote_head(root, expected_branch)
    if live_remote_head != metadata_head:
        raise D10CurrentnessError("REMOTE_LOCAL_METADATA_HEAD_MISMATCH")
    parent = _require_commit("SOURCE_FREEZE_COMMIT", str(_git(root, "rev-parse", "HEAD^")).strip())
    if parent == metadata_head:
        raise D10CurrentnessError("SOURCE_AND_METADATA_COMMIT_MUST_BE_DISTINCT")
    parents = str(_git(root, "rev-list", "--parents", "-n", "1", metadata_head)).strip().split()
    if len(parents) != 2 or parents[1].lower() != parent:
        raise D10CurrentnessError("PACKAGE_METADATA_COMMIT_NOT_DIRECT_CHILD_OF_SOURCE_FREEZE")

    if mission.get("source_repository") != expected_repository:
        raise D10CurrentnessError("MISSION_SOURCE_REPOSITORY_MISMATCH")
    if mission.get("governed_branch_or_ref") != expected_branch:
        raise D10CurrentnessError("MISSION_GOVERNED_BRANCH_MISMATCH")
    if materialization.get("source_repository") != expected_repository:
        raise D10CurrentnessError("MATERIALIZATION_SOURCE_REPOSITORY_MISMATCH")
    if materialization.get("governed_branch_or_ref") != expected_branch:
        raise D10CurrentnessError("MATERIALIZATION_GOVERNED_BRANCH_MISMATCH")

    source_values = {
        "MISSION_SOURCE_COMMIT": mission.get("source_commit"),
        "MATERIALIZATION_SOURCE_COMMIT": materialization.get("materialization_source_commit"),
        "MANIFEST_SOURCE_COMMIT": manifest.get("source_commit"),
        "DEPENDENCY_GRAPH_SOURCE_COMMIT": graph.get("package", {}).get("source_commit") if isinstance(graph.get("package"), dict) else None,
    }
    for name, value in source_values.items():
        if _require_commit(name, value) != parent:
            raise D10CurrentnessError(f"{name}_NOT_SOURCE_FREEZE")

    metadata_values = {
        "MISSION_METADATA_HEAD": mission.get("mission_metadata_head"),
        "MATERIALIZATION_METADATA_HEAD": materialization.get("materialization_metadata_head"),
        "MATERIALIZATION_LIVE_REMOTE_HEAD": materialization.get("live_remote_head"),
        "MATERIALIZATION_LOCAL_HEAD": materialization.get("local_head"),
        "MATERIALIZATION_REMOTE_COMMIT": materialization.get("remote_commit"),
    }
    for name, value in metadata_values.items():
        if _require_commit(name, value) != metadata_head:
            raise D10CurrentnessError(f"{name}_NOT_PACKAGE_METADATA_HEAD")

    if _find_exact_sha_value(manifest, metadata_head) or _find_exact_sha_value(graph, metadata_head):
        raise D10CurrentnessError("SELF_REFERENTIAL_METADATA_COMMIT_SHA_FIELD")

    members = manifest.get("members")
    if not isinstance(members, list) or not members:
        raise D10CurrentnessError("PACKAGE_MEMBERS_REQUIRED")
    seen: set[str] = set()
    for member in members:
        if not isinstance(member, dict):
            raise D10CurrentnessError("PACKAGE_MEMBER_INVALID")
        rel = member.get("path")
        if not isinstance(rel, str) or not rel or rel in seen:
            raise D10CurrentnessError("PACKAGE_MEMBER_DUPLICATE_OR_EMPTY")
        seen.add(rel)
        if rel in METADATA_PATHS:
            raise D10CurrentnessError("TRACKED_MANIFEST_SELF_HASH_REQUIREMENT_REJECTED")
        path = root / rel
        if not path.is_file():
            raise D10CurrentnessError(f"PACKAGE_MEMBER_MISSING:{rel}")
        workspace_bytes = path.read_bytes()
        source_bytes = bytes(_git(root, "show", f"{parent}:{rel}", text=False))
        metadata_bytes = bytes(_git(root, "show", f"{metadata_head}:{rel}", text=False))
        expected_sha = str(member.get("sha256", "")).upper()
        if len(workspace_bytes) != member.get("size_bytes") or _sha256_bytes(workspace_bytes) != expected_sha:
            raise D10CurrentnessError(f"PACKAGE_MEMBER_WORKSPACE_IDENTITY_MISMATCH:{rel}")
        if workspace_bytes != source_bytes:
            raise D10CurrentnessError(f"SOURCE_MEMBER_NOT_BOUND_TO_SOURCE_FREEZE:{rel}")
        if source_bytes != metadata_bytes:
            raise D10CurrentnessError(f"UNAUTHORIZED_SOURCE_CHANGE_BETWEEN_S_AND_M:{rel}")

    calculated_package = _compute_package_sha256(members)
    declared_package = str(manifest.get("package_sha256", "")).upper()
    if calculated_package != declared_package:
        raise D10CurrentnessError("PACKAGE_SHA256_MISMATCH")
    graph_package = graph.get("package") if isinstance(graph.get("package"), dict) else {}
    if str(graph_package.get("package_sha256", "")).upper() != declared_package:
        raise D10CurrentnessError("DEPENDENCY_GRAPH_PACKAGE_SHA_MISMATCH")

    delta = [line.strip().replace("\\", "/") for line in str(_git(root, "diff", "--name-only", parent, metadata_head)).splitlines() if line.strip()]
    unauthorized = sorted(set(delta) - METADATA_PATHS)
    if unauthorized:
        raise D10CurrentnessError("S_TO_M_UNAUTHORIZED_SOURCE_CHANGE:" + ",".join(unauthorized))
    if not set(delta).issubset(METADATA_PATHS):
        raise D10CurrentnessError("S_TO_M_METADATA_DELTA_INVALID")

    return {
        "status": "PASS",
        "source_freeze_commit": parent,
        "package_metadata_commit": metadata_head,
        "live_remote_head": live_remote_head,
        "source_domain_exact_equality": "PASS",
        "metadata_domain_exact_equality": "PASS",
        "s_to_m_binding": "PASS",
        "s_to_m_unauthorized_source_change_count": 0,
        "package_sha256": declared_package,
        "source_member_count": len(members),
    }


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise D10CurrentnessError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="ECTOS D10 dual-identity currentness oracle")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--expected-branch", required=True)
    parser.add_argument("--mission", type=Path, required=True)
    parser.add_argument("--materialization", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--dependency-graph", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = validate_dual_identity_currentness(
            args.root,
            args.expected_repository,
            args.expected_branch,
            _load(args.mission),
            _load(args.materialization),
            _load(args.manifest),
            _load(args.dependency_graph),
        )
    except (OSError, json.JSONDecodeError, D10CurrentnessError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, indent=2, sort_keys=True))
        return 40
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
