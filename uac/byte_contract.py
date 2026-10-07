from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from uac_core import UACDenied

UTF8_BOM = b"\xef\xbb\xbf"


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def validate_canonical_json_file(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if raw.startswith(UTF8_BOM):
        raise UACDenied(f"UTF8_BOM_PROHIBITED:{path.name}")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise UACDenied(f"UTF8_DECODE_FAILED:{path.name}") from exc
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise UACDenied(f"JSON_PARSE_FAILED:{path.name}") from exc
    expected = canonical_json_bytes(value)
    if raw != expected:
        raise UACDenied(f"NON_CANONICAL_JSON_BYTES:{path.name}")
    return value


def write_canonical_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(value))
