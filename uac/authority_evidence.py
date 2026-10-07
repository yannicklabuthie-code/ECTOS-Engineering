from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

from uac_errors import UACDenied

EVIDENCE_KINDS = {
    "independent_qualification": ("INDEPENDENT_QUALIFIER", "PASS"),
    "systemic_assurance": ("SYSTEMIC_ASSURANCE", "PASS"),
    "consolidated_defect_closure": ("CONSOLIDATED_DEFECT_CLOSURE_AUTHORITY", "CLOSED"),
    "circuit_breaker": ("ECTOS_MAIN_AUTHORITY", "CLEAR"),
    "rule_source_currentness": ("ECTOS_RULE_SOURCE_AUTHORITY", "PROVEN_CURRENT"),
    "negative_controls": ("INDEPENDENT_QUALIFIER", "PASS"),
}

BINDING_FIELDS = (
    "package_id", "package_sha256", "manifest_sha256", "dependency_graph_sha256",
    "source_repository", "source_commit", "mission_id", "failure_family_id",
    "actor", "qualifier", "systemic_assurance_id", "admission_authority",
    "target", "action",
)


def _canon(value: Dict[str, Any]) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _signable(evidence: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in evidence.items() if k not in {"signature", "evidence_sha256"}}


def evidence_digest(evidence: Dict[str, Any]) -> str:
    return hashlib.sha256(_canon(_signable(evidence))).hexdigest()


def sign_evidence(evidence: Dict[str, Any], key: bytes) -> Dict[str, Any]:
    result = dict(evidence)
    result["evidence_sha256"] = evidence_digest(result)
    mac = hmac.new(key, _canon(_signable(result)), hashlib.sha256).digest()
    result["signature"] = base64.urlsafe_b64encode(mac).decode("ascii").rstrip("=")
    return result


def _verify_signature(evidence: Dict[str, Any], key: bytes) -> None:
    supplied = evidence.get("signature")
    if not isinstance(supplied, str) or not supplied:
        raise UACDenied("AUTHORITY_EVIDENCE_SIGNATURE_MISSING")
    digest = evidence.get("evidence_sha256")
    if digest != evidence_digest(evidence):
        raise UACDenied("AUTHORITY_EVIDENCE_DIGEST_MISMATCH")
    mac = hmac.new(key, _canon(_signable(evidence)), hashlib.sha256).digest()
    expected = base64.urlsafe_b64encode(mac).decode("ascii").rstrip("=")
    if not hmac.compare_digest(supplied, expected):
        raise UACDenied("AUTHORITY_EVIDENCE_SIGNATURE_INVALID")


def _parse_time(name: str, value: Any) -> datetime:
    if not isinstance(value, str) or not value:
        raise UACDenied(f"AUTHORITY_EVIDENCE_{name.upper()}_MISSING")
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError as exc:
        raise UACDenied(f"AUTHORITY_EVIDENCE_{name.upper()}_INVALID") from exc
    if parsed.tzinfo is None:
        raise UACDenied(f"AUTHORITY_EVIDENCE_{name.upper()}_NAIVE")
    return parsed.astimezone(timezone.utc)


def verify_authority_evidence_bundle(
    request: Dict[str, Any],
    registry: Dict[str, Any],
    keyring: Dict[str, bytes],
    ledger_path: Path,
    consume: bool = False,
) -> Dict[str, str]:
    bundle = request.get("authority_evidence")
    if not isinstance(bundle, dict):
        raise UACDenied("AUTHORITY_EVIDENCE_BUNDLE_MISSING")

    policies = registry.get("authority_evidence_policies", {})
    ledger = {"consumed_authority_evidence_nonces": []}
    if ledger_path.exists():
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    consumed = set(ledger.get("consumed_authority_evidence_nonces", []))
    newly_consumed: list[str] = []
    derived: Dict[str, str] = {}
    now = datetime.now(timezone.utc)

    for kind, (default_role, default_decision) in EVIDENCE_KINDS.items():
        evidence = bundle.get(kind)
        if not isinstance(evidence, dict):
            raise UACDenied(f"AUTHORITY_EVIDENCE_MISSING:{kind}")
        policy = policies.get(kind, {})
        expected_role = policy.get("issuer_role", default_role)
        expected_decision = policy.get("decision", default_decision)
        key_id = evidence.get("key_id")
        if key_id not in policy.get("trusted_key_ids", []):
            raise UACDenied(f"AUTHORITY_EVIDENCE_UNTRUSTED_KEY:{kind}")
        key = keyring.get(str(key_id))
        if not key:
            raise UACDenied(f"AUTHORITY_EVIDENCE_KEY_UNAVAILABLE:{kind}")
        if evidence.get("issuer_role") != expected_role:
            raise UACDenied(f"AUTHORITY_EVIDENCE_ISSUER_ROLE_INVALID:{kind}")
        trusted_issuer_ids = policy.get("trusted_issuer_ids", [])
        if evidence.get("issuer_id") not in trusted_issuer_ids:
            raise UACDenied(f"AUTHORITY_EVIDENCE_ISSUER_ID_INVALID:{kind}")
        dynamic_issuer = None
        if kind in {"independent_qualification", "negative_controls"}:
            dynamic_issuer = request.get("qualifier")
        elif kind == "systemic_assurance":
            dynamic_issuer = request.get("systemic_assurance_id")
        if dynamic_issuer is not None and evidence.get("issuer_id") != dynamic_issuer:
            raise UACDenied(f"AUTHORITY_EVIDENCE_ISSUER_TARGET_MISMATCH:{kind}")
        if evidence.get("decision") != expected_decision:
            raise UACDenied(f"AUTHORITY_EVIDENCE_DECISION_INVALID:{kind}")
        for field in BINDING_FIELDS:
            if evidence.get(field) != request.get(field):
                raise UACDenied(f"AUTHORITY_EVIDENCE_BINDING_MISMATCH:{kind}:{field}")
        issued_at = _parse_time("issued_at", evidence.get("issued_at"))
        expires_at = _parse_time("expires_at", evidence.get("expires_at"))
        if issued_at > now:
            raise UACDenied(f"AUTHORITY_EVIDENCE_NOT_YET_VALID:{kind}")
        if now >= expires_at:
            raise UACDenied(f"AUTHORITY_EVIDENCE_EXPIRED:{kind}")
        nonce = evidence.get("nonce")
        if not isinstance(nonce, str) or not nonce:
            raise UACDenied(f"AUTHORITY_EVIDENCE_NONCE_MISSING:{kind}")
        if nonce in consumed or nonce in newly_consumed:
            raise UACDenied(f"AUTHORITY_EVIDENCE_REPLAY:{kind}")
        _verify_signature(evidence, key)
        newly_consumed.append(nonce)
        derived[kind] = str(evidence["decision"])

    if consume:
        consumed.update(newly_consumed)
        ledger["consumed_authority_evidence_nonces"] = sorted(consumed)
        ledger_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = ledger_path.with_suffix(ledger_path.suffix + ".tmp")
        tmp.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
        tmp.replace(ledger_path)
    return derived
