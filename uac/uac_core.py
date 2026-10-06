from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict

HERE = Path(__file__).resolve().parent
DEFAULT_REGISTRY = HERE / "config" / "registry.json"
DEFAULT_LEDGER = HERE / "state" / "replay_ledger.json"
RECEIPT_VERSION = "ECTOS_UAC_RECEIPT_V01"


class UACDenied(RuntimeError):
    pass


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _canon(obj: Dict[str, Any]) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _write_json_atomic(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, path)


def _require_hex_sha256(name: str, value: Any) -> str:
    if not isinstance(value, str) or len(value) != 64:
        raise UACDenied(f"{name}_INVALID")
    try:
        int(value, 16)
    except ValueError as exc:
        raise UACDenied(f"{name}_INVALID") from exc
    return value.lower()


def _route_allowed(registry: Dict[str, Any], actor: str, target: str, action: str) -> bool:
    actor_cfg = registry.get("actors", {}).get(actor)
    target_cfg = registry.get("targets", {}).get(target)
    if not actor_cfg or not actor_cfg.get("enabled"):
        return False
    if not target_cfg or not target_cfg.get("enabled"):
        return False
    for route in registry.get("routes", []):
        if not route.get("enabled"):
            continue
        if route.get("actor") == actor and route.get("target") == target and action in route.get("actions", []):
            return True
    return False


def evaluate_admission(request: Dict[str, Any], registry_path: Path = DEFAULT_REGISTRY) -> Dict[str, Any]:
    registry = _load_json(registry_path)
    required_fields = [
        "project", "mission_id", "failure_family_id", "actor", "qualifier",
        "systemic_assurance_id", "package_id", "package_sha256", "manifest_sha256",
        "target", "action", "qualification_result", "systemic_review_state",
        "consolidated_defect_set_state", "governance_currentness",
        "rule_source_currentness", "negative_controls", "circuit_breaker_state"
    ]
    missing = [k for k in required_fields if not request.get(k)]
    if missing:
        raise UACDenied("MISSING_FIELDS:" + ",".join(sorted(missing)))

    actor = request["actor"]
    target = request["target"]
    action = request["action"]
    if not _route_allowed(registry, actor, target, action):
        raise UACDenied("ROUTE_NOT_REGISTERED_OR_DISABLED")

    actor_cfg = registry["actors"][actor]
    if request.get("admission_authority") == actor and not actor_cfg.get("can_self_admit", False):
        raise UACDenied("SELF_ADMISSION_PROHIBITED")

    _require_hex_sha256("PACKAGE_SHA256", request["package_sha256"])
    _require_hex_sha256("MANIFEST_SHA256", request["manifest_sha256"])

    for field, expected in registry.get("required_states", {}).items():
        if request.get(field) != expected:
            raise UACDenied(f"{field.upper()}_NOT_ACCEPTED")

    if request.get("qualifier") == actor:
        raise UACDenied("PRODUCER_OR_ACTOR_CANNOT_BE_ITS_OWN_QUALIFIER")

    if request.get("systemic_assurance_id") in {actor, request.get("qualifier")}:
        raise UACDenied("SYSTEMIC_ASSURANCE_SEPARATION_VIOLATION")

    return {"decision": "ADMIT", "reason": "ALL_REQUIRED_GATES_PASS"}


def _sign_payload(payload: Dict[str, Any], signing_key: bytes) -> str:
    digest = hmac.new(signing_key, _canon(payload), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def issue_receipt(request: Dict[str, Any], signing_key: bytes, ttl_seconds: int = 900,
                  registry_path: Path = DEFAULT_REGISTRY) -> Dict[str, Any]:
    evaluate_admission(request, registry_path)
    now = _utcnow()
    payload = {
        "receipt_version": RECEIPT_VERSION,
        "project": request["project"],
        "mission_id": request["mission_id"],
        "failure_family_id": request["failure_family_id"],
        "package_id": request["package_id"],
        "package_sha256": request["package_sha256"].lower(),
        "manifest_sha256": request["manifest_sha256"].lower(),
        "actor": request["actor"],
        "qualifier": request["qualifier"],
        "systemic_assurance_id": request["systemic_assurance_id"],
        "target": request["target"],
        "action": request["action"],
        "source_repository": request.get("source_repository"),
        "governance_currentness": request["governance_currentness"],
        "rule_source_currentness": request["rule_source_currentness"],
        "circuit_breaker_state": request["circuit_breaker_state"],
        "negative_controls": request["negative_controls"],
        "issued_at": now.isoformat(),
        "expires_at": (now + timedelta(seconds=ttl_seconds)).isoformat(),
        "nonce": secrets.token_urlsafe(24),
        "receipt_id": secrets.token_hex(16),
        "issuer_id": "ECTOS_UAC_CONTROL_PLANE_V01"
    }
    return {"payload": payload, "signature": _sign_payload(payload, signing_key)}


def verify_receipt(receipt: Dict[str, Any], signing_key: bytes, expected_target: str,
                   expected_action: str, consume: bool = False,
                   ledger_path: Path = DEFAULT_LEDGER) -> Dict[str, Any]:
    payload = receipt.get("payload")
    signature = receipt.get("signature")
    if not isinstance(payload, dict) or not isinstance(signature, str):
        raise UACDenied("RECEIPT_FORMAT_INVALID")
    expected = _sign_payload(payload, signing_key)
    if not hmac.compare_digest(signature, expected):
        raise UACDenied("RECEIPT_SIGNATURE_INVALID")
    if payload.get("receipt_version") != RECEIPT_VERSION:
        raise UACDenied("RECEIPT_VERSION_INVALID")
    if payload.get("target") != expected_target:
        raise UACDenied("RECEIPT_TARGET_MISMATCH")
    if payload.get("action") != expected_action:
        raise UACDenied("RECEIPT_ACTION_MISMATCH")

    try:
        expires_at = datetime.fromisoformat(payload["expires_at"])
    except Exception as exc:
        raise UACDenied("RECEIPT_EXPIRY_INVALID") from exc
    if expires_at.tzinfo is None or _utcnow() >= expires_at.astimezone(timezone.utc):
        raise UACDenied("RECEIPT_EXPIRED")

    ledger = {"consumed_receipt_ids": []}
    if ledger_path.exists():
        ledger = _load_json(ledger_path)
    consumed = set(ledger.get("consumed_receipt_ids", []))
    receipt_id = payload.get("receipt_id")
    if not receipt_id:
        raise UACDenied("RECEIPT_ID_MISSING")
    if receipt_id in consumed:
        raise UACDenied("RECEIPT_REPLAY_DETECTED")
    if consume:
        consumed.add(receipt_id)
        ledger["consumed_receipt_ids"] = sorted(consumed)
        _write_json_atomic(ledger_path, ledger)

    return {"decision": "ADMIT", "receipt_id": receipt_id, "consumed": consume}
