from __future__ import annotations

import argparse
import json
from pathlib import Path

from uac_core import UACDenied


def resolve_staged_path(root: Path, declared_path: str) -> Path:
    if not isinstance(declared_path, str) or not declared_path.strip():
        raise UACDenied("DECLARED_ARTIFACT_PATH_INVALID")
    normalized = declared_path.replace("\\", "/").lstrip("./")
    direct = root / Path(normalized)
    if direct.is_file():
        return direct
    basename = Path(normalized).name
    matches = sorted(p for p in root.rglob(basename) if p.is_file())
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise UACDenied(f"STAGED_ARTIFACT_NOT_FOUND:{normalized}")
    raise UACDenied(f"STAGED_ARTIFACT_PATH_AMBIGUOUS:{normalized}")


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
    mapping = {
        "package_path": resolve_staged_path(root, args.package_path).as_posix(),
        "manifest_path": resolve_staged_path(root, args.manifest_path).as_posix(),
        "dependency_graph_path": resolve_staged_path(root, args.dependency_graph_path).as_posix(),
        "request_path": resolve_staged_path(root, args.request_path).as_posix(),
    }
    Path(args.output).write_text(json.dumps(mapping, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(mapping, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
