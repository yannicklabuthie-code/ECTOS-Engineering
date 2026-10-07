from __future__ import annotations

import base64
import hashlib
import json
import math
import random
from datetime import datetime, timedelta, timezone
from uuid import uuid4

KEY_CONFIG = {
    "QUALIFIER_KEY_V01": (101, "ECTOS_INDEPENDENT_QUALIFIER", "INDEPENDENT_QUALIFIER"),
    "SYSTEMIC_ASSURANCE_KEY_V01": (202, "ECTOS_SYSTEMIC_ASSURANCE", "SYSTEMIC_ASSURANCE"),
    "DEFECT_CLOSURE_KEY_V01": (303, "ECTOS_MAIN_DEFECT_CLOSURE", "CONSOLIDATED_DEFECT_CLOSURE_AUTHORITY"),
    "MAIN_AUTHORITY_KEY_V01": (404, "ECTOS_MAIN_AUTHORITY", "ECTOS_MAIN_AUTHORITY"),
    "GOVERNANCE_CURRENTNESS_KEY_V01": (505, "ECTOS_GOVERNANCE_CURRENTNESS_AUTHORITY", "GOVERNANCE_CURRENTNESS_AUTHORITY"),
    "RULE_SOURCE_KEY_V01": (606, "ECTOS_RULE_SOURCE_AUTHORITY", "ECTOS_RULE_SOURCE_AUTHORITY"),
}

KIND_CONFIG = {
    "independent_qualification": ("ECTOS_INDEPENDENT_QUALIFIER", "INDEPENDENT_QUALIFIER", "PASS", "QUALIFIER_KEY_V01"),
    "systemic_assurance": ("ECTOS_SYSTEMIC_ASSURANCE", "SYSTEMIC_ASSURANCE", "PASS", "SYSTEMIC_ASSURANCE_KEY_V01"),
    "consolidated_defect_closure": ("ECTOS_MAIN_DEFECT_CLOSURE", "CONSOLIDATED_DEFECT_CLOSURE_AUTHORITY", "CLOSED", "DEFECT_CLOSURE_KEY_V01"),
    "circuit_breaker": ("ECTOS_MAIN_AUTHORITY", "ECTOS_MAIN_AUTHORITY", "CLEAR", "MAIN_AUTHORITY_KEY_V01"),
    "governance_currentness": ("ECTOS_GOVERNANCE_CURRENTNESS_AUTHORITY", "GOVERNANCE_CURRENTNESS_AUTHORITY", "PROVEN_CURRENT", "GOVERNANCE_CURRENTNESS_KEY_V01"),
    "rule_source_currentness": ("ECTOS_RULE_SOURCE_AUTHORITY", "ECTOS_RULE_SOURCE_AUTHORITY", "PROVEN_CURRENT", "RULE_SOURCE_KEY_V01"),
    "negative_controls": ("ECTOS_INDEPENDENT_QUALIFIER", "INDEPENDENT_QUALIFIER", "PASS", "QUALIFIER_KEY_V01"),
}

BINDING_FIELDS = (
    "package_id", "package_sha256", "manifest_sha256", "dependency_graph_sha256",
    "source_repository", "source_commit", "mission_id", "failure_family_id",
    "actor", "qualifier", "systemic_assurance_id", "admission_authority", "target", "action",
)

_SHA256_DIGESTINFO_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")
_PRIVATE_KEYS: dict[str, tuple[int, int, int]] = {}
PUBLIC_KEYRING: dict[str, dict] = {}


def _is_probable_prime(n: int) -> bool:
    if n < 2:
        return False
    small = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    for p in small:
        if n % p == 0:
            return n == p
    d = n - 1
    s = 0
    while d % 2 == 0:
        s += 1
        d //= 2
    for a in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53):
        if a >= n:
            continue
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def _prime(rng: random.Random) -> int:
    while True:
        candidate = rng.getrandbits(1024) | (1 << 1023) | 1
        if _is_probable_prime(candidate):
            return candidate


def _keypair(seed: int) -> tuple[int, int, int]:
    rng = random.Random(seed)
    e = 65537
    while True:
        p = _prime(rng)
        q = _prime(rng)
        phi = (p - 1) * (q - 1)
        if p != q and math.gcd(e, phi) == 1:
            n = p * q
            if n.bit_length() >= 2048:
                return n, e, pow(e, -1, phi)


def _ensure_keys() -> None:
    if PUBLIC_KEYRING:
        return
    for key_id, (seed, issuer_id, issuer_role) in KEY_CONFIG.items():
        n, e, d = _keypair(seed)
        _PRIVATE_KEYS[key_id] = (n, e, d)
        PUBLIC_KEYRING[key_id] = {
            "algorithm": "RSA-PKCS1-v1_5-SHA256",
            "key_use": "VERIFY_ONLY",
            "n_hex": f"{n:x}",
            "e": e,
            "issuer_id": issuer_id,
            "issuer_role": issuer_role,
        }


def _canon(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _signable(evidence: dict) -> dict:
    return {k: v for k, v in evidence.items() if k not in {"signature", "evidence_sha256"}}


def sign_bytes(message: bytes, key_id: str) -> str:
    _ensure_keys()
    n, _e, d = _PRIVATE_KEYS[key_id]
    k = (n.bit_length() + 7) // 8
    digest_info = _SHA256_DIGESTINFO_PREFIX + hashlib.sha256(message).digest()
    padding = b"\xff" * (k - len(digest_info) - 3)
    encoded = b"\x00\x01" + padding + b"\x00" + digest_info
    signature = pow(int.from_bytes(encoded, "big"), d, n).to_bytes(k, "big")
    return base64.urlsafe_b64encode(signature).decode("ascii").rstrip("=")


def sign_evidence(evidence: dict, key_id: str) -> dict:
    result = dict(evidence)
    result["evidence_sha256"] = hashlib.sha256(_canon(_signable(result))).hexdigest()
    result["signature"] = sign_bytes(_canon(_signable(result)), key_id)
    return result


def attach_evidence(request: dict, nonce_prefix: str = "test") -> dict:
    _ensure_keys()
    now = datetime.now(timezone.utc)
    token = uuid4().hex
    bundle = {}
    for index, (kind, (issuer_id, role, decision, key_id)) in enumerate(KIND_CONFIG.items(), start=1):
        evidence = {field: request[field] for field in BINDING_FIELDS}
        evidence.update({
            "issuer_id": issuer_id,
            "issuer_role": role,
            "decision": decision,
            "issued_at": (now - timedelta(seconds=5)).isoformat(),
            "expires_at": (now + timedelta(minutes=10)).isoformat(),
            "nonce": f"{nonce_prefix}-{token}-{kind}-{index}",
            "key_id": key_id,
        })
        bundle[kind] = sign_evidence(evidence, key_id)
    request["authority_evidence"] = bundle
    return request


_ensure_keys()
KEYRING = PUBLIC_KEYRING
