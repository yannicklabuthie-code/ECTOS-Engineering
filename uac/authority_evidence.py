from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

from atomic_state import AtomicStateError, atomic_consume
from authority_crypto import AuthorityCryptoError, public_key_fingerprint, verify_rsa_pkcs1_v1_5_sha256
from uac_errors import UACDenied

EVIDENCE_KINDS = {
    "independent_qualification": ("INDEPENDENT_QUALIFIER", "PASS"),
    "systemic_assurance": ("SYSTEMIC_ASSURANCE", "PASS"),
    "consolidated_defect_closure": ("CONSOLIDATED_DEFECT_CLOSURE_AUTHORITY", "CLOSED"),
    "circuit_breaker": ("ECTOS_MAIN_AUTHORITY", "CLEAR"),
    "governance_currentness": ("GOVERNANCE_CURRENTNESS_AUTHORITY", "PROVEN_CURRENT"),
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


def _validate_public_keyring_separation(registry: Dict[str, Any], keyring: Dict[str, Dict[str, Any]]) -> None:
    if not isinstance(keyring, dict) or not keyring:
        raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_UNAVAILABLE")
    policies = registry.get("authority_evidence_policies", {})
    fingerprint_owner: dict[str, tuple[str, str]] = {}
    for kind, policy in policies.items():
        issuer_role = policy.get("issuer_role")
        trusted_issuers = policy.get("trusted_issuer_ids", [])
        trusted_keys = policy.get("trusted_key_ids", [])
        for key_id in trusted_keys:
            public_key = keyring.get(str(key_id))
            if not public_key:
                raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEY_UNAVAILABLE:{kind}")
            if public_key.get("issuer_role") != issuer_role:
                raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEY_ROLE_MISMATCH:{kind}")
            if public_key.get("issuer_id") not in trusted_issuers:
                raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEY_ISSUER_MISMATCH:{kind}")
            try:
                fingerprint = public_key_fingerprint(public_key)
            except AuthorityCryptoError as exc:
                raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEY_INVALID:{kind}:{exc}") from exc
            owner = (str(public_key.get("issuer_id")), str(public_key.get("issuer_role")))
            previous = fingerprint_owner.get(fingerprint)
            if previous is not None and previous != owner:
                raise UACDenied("CRYPTOGRAPHIC_AUTHORITY_KEY_SEPARATION_VIOLATION")
            fingerprint_owner[fingerprint] = owner


def _verify_signature(evidence: Dict[str, Any], public_key: Dict[str, Any]) -> None:
    supplied = evidence.get("signature")
    if not isinstance(supplied, str) or not supplied:
        raise UACDenied("AUTHORITY_EVIDENCE_SIGNATURE_MISSING")
    digest = evidence.get("evidence_sha256")
    if digest != evidence_digest(evidence):
        raise UACDenied("AUTHORITY_EVIDENCE_DIGEST_MISMATCH")
    try:
        verify_rsa_pkcs1_v1_5_sha256(_canon(_signable(evidence)), supplied, public_key)
    except AuthorityCryptoError as exc:
        raise UACDenied(f"AUTHORITY_EVIDENCE_SIGNATURE_INVALID:{exc}") from exc


def verify_authority_evidence_bundle(
    request: Dict[str, Any],
    registry: Dict[str, Any],
    keyring: Dict[str, Dict[str, Any]],
    ledger_path: Path,
    consume: bool = False,
) -> Dict[str, str]:
    bundle = request.get("authority_evidence")
    if not isinstance(bundle, dict):
        raise UACDenied("AUTHORITY_EVIDENCE_BUNDLE_MISSING")

    _validate_public_keyring_separation(registry, keyring)
    policies = registry.get("authority_evidence_policies", {})
    derived: Dict[str, str] = {}
    nonces: list[str] = []
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
        public_key = keyring.get(str(key_id))
        if not public_key:
            raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEY_UNAVAILABLE:{kind}")
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
        if public_key.get("issuer_id") != evidence.get("issuer_id") or public_key.get("issuer_role") != evidence.get("issuer_role"):
            raise UACDenied(f"AUTHORITY_EVIDENCE_KEY_IDENTITY_MISMATCH:{kind}")
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
        if nonce in nonces:
            raise UACDenied(f"AUTHORITY_EVIDENCE_REPLAY:{kind}")
        _verify_signature(evidence, public_key)
        nonces.append(nonce)
        derived[kind] = str(evidence["decision"])

    if consume:
        try:
            duplicate = atomic_consume(ledger_path, "consumed_authority_evidence_nonces", nonces)
        except AtomicStateError as exc:
            raise UACDenied(f"AUTHORITY_EVIDENCE_REPLAY_LEDGER_FAILURE:{exc}") from exc
        if duplicate is not None:
            raise UACDenied("AUTHORITY_EVIDENCE_REPLAY")
    return derived
