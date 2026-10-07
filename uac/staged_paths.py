from __future__ import annotations

import argparse
import json
from pathlib import Path

from byte_contract import canonical_json_bytes
from uac_core import UACDenied


def _normalize_declared(declared_path: str) -> str:
    if not isinstance(declared_path, str) or not declared_path.strip():
        raise UACDenied("DECLARED_ARTIFACT_PATH_INVALID")
    normalized = declared_path.replace("\\", "/")
    if normalized.startswith("/") or normalized.startswith("../") or "/../" in f"/{normalized}/":
        raise UACDenied(f"DECLARED_ARTIFACT_PATH_INVALID:{declared_path}")
    return normalized


def resolve_staged_path(root: Path, declared_path: str) -> Path:
    normalized = _normalize_declared(declared_path)
    root = root.resolve()
    candidate = (root / "source" / Path(normalized)).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise UACDenied(f"STAGED_ARTIFACT_PATH_ESCAPES_ROOT:{normalized}") from exc
    if not candidate.is_file():
        raise UACDenied(f"STAGED_ARTIFACT_NOT_FOUND_EXACT:{normalized}")
    return candidate


def staged_mapping(root: Path, declared: dict[str, str]) -> dict[str, str]:
    root = root.resolve()
    mapping: dict[str, str] = {}
    for role, declared_path in declared.items():
        resolved = resolve_staged_path(root, declared_path)
        mapping[role] = resolved.relative_to(root).as_posix()
    return mapping


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package-path", required=True)
    parser.add_argument("--manifest-path", required=True)
    parser.add_argument("--dependency-graph-path", required=True)
    parser.add_argument("--request-path", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(args.root)
    mapping = staged_mapping(root, {
        "package": args.package_path,
        "manifest": args.manifest_path,
        "dependency_graph": args.dependency_graph_path,
        "request": args.request_path,
    })
    Path(args.output).write_bytes(canonical_json_bytes(mapping))
    print(json.dumps(mapping, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
