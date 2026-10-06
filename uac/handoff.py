from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Dict

from uac_core import UACDenied, issue_receipt, verify_receipt

HANDOFF_SCHEMA = "ECTOS_CANONICAL_HANDOFF_V01"
HANDOFF_STATE = "PACKAGE_READY_FOR_HANDOFF"
HANDOFF_TARGET = "ECTOS_PACKAGE_HANDOFF"
HANDOFF_ACTION = "ISSUE_HANDOFF"


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _read_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _write_json(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")
    tmp.replace(path)


def materialize_handoff(package_path: Path, manifest_path: Path, request_path: Path,
                        output_dir: Path, signing_key: bytes, commit_sha: str) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")
    if not package_path.is_file():
        raise UACDenied("PACKAGE_NOT_FOUND")
    if not manifest_path.is_file():
        raise UACDenied("MANIFEST_NOT_FOUND")
    if not request_path.is_file():
        raise UACDenied("ADMISSION_REQUEST_NOT_FOUND")
    if not isinstance(commit_sha, str) or len(commit_sha) < 7:
        raise UACDenied("COMMIT_SHA_INVALID")

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    request = _read_json(request_path)

    if request.get("package_sha256", "").lower() != package_sha:
        raise UACDenied("PACKAGE_SHA256_BINDING_MISMATCH")
    if request.get("manifest_sha256", "").lower() != manifest_sha:
        raise UACDenied("MANIFEST_SHA256_BINDING_MISMATCH")
    if request.get("target") != HANDOFF_TARGET:
        raise UACDenied("HANDOFF_TARGET_INVALID")
    if request.get("action") != HANDOFF_ACTION:
        raise UACDenied("HANDOFF_ACTION_INVALID")

    receipt = issue_receipt(request, signing_key)
    verify_receipt(receipt, signing_key, HANDOFF_TARGET, HANDOFF_ACTION)

    payload = receipt["payload"]
    descriptor = {
        "schema_id": HANDOFF_SCHEMA,
        "state": HANDOFF_STATE,
        "package_name": package_path.name,
        "package_sha256": package_sha,
        "manifest_name": manifest_path.name,
        "manifest_sha256": manifest_sha,
        "source_commit_sha": commit_sha,
        "receipt_id": payload["receipt_id"],
        "receipt_version": payload["receipt_version"],
        "receipt_issuer_id": payload["issuer_id"],
        "receipt_file": "UAC_RECEIPT.json",
        "admission_target": payload["target"],
        "admission_action": payload["action"],
        "failure_family_id": payload["failure_family_id"],
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    receipt_path = output_dir / "UAC_RECEIPT.json"
    descriptor_path = output_dir / "HANDOFF_DESCRIPTOR.json"
    _write_json(receipt_path, receipt)
    _write_json(descriptor_path, descriptor)

    return descriptor


def verify_handoff(package_path: Path, manifest_path: Path, descriptor_path: Path,
                   receipt_path: Path, signing_key: bytes,
                   expected_commit_sha: str | None = None) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")

    descriptor = _read_json(descriptor_path)
    receipt = _read_json(receipt_path)

    if descriptor.get("schema_id") != HANDOFF_SCHEMA:
        raise UACDenied("HANDOFF_SCHEMA_INVALID")
    if descriptor.get("state") != HANDOFF_STATE:
        raise UACDenied("HANDOFF_STATE_INVALID")

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    if descriptor.get("package_sha256") != package_sha:
        raise UACDenied("HANDOFF_PACKAGE_TAMPERED")
    if descriptor.get("manifest_sha256") != manifest_sha:
        raise UACDenied("HANDOFF_MANIFEST_TAMPERED")
    if expected_commit_sha is not None and descriptor.get("source_commit_sha") != expected_commit_sha:
        raise UACDenied("HANDOFF_COMMIT_MISMATCH")

    verified = verify_receipt(receipt, signing_key, HANDOFF_TARGET, HANDOFF_ACTION)
    payload = receipt["payload"]
    if payload.get("package_sha256") != package_sha:
        raise UACDenied("RECEIPT_PACKAGE_BINDING_MISMATCH")
    if payload.get("manifest_sha256") != manifest_sha:
        raise UACDenied("RECEIPT_MANIFEST_BINDING_MISMATCH")
    if descriptor.get("receipt_id") != payload.get("receipt_id"):
        raise UACDenied("HANDOFF_RECEIPT_ID_MISMATCH")

    return {
        "decision": "ADMIT",
        "state": HANDOFF_STATE,
        "receipt_id": verified["receipt_id"],
        "package_sha256": package_sha,
        "manifest_sha256": manifest_sha,
    }
