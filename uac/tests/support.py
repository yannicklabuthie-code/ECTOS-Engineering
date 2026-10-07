from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from authority_evidence import sign_evidence

KEYRING = {
    "QUALIFIER_KEY_V01": b"qualifier-test-key",
    "SYSTEMIC_ASSURANCE_KEY_V01": b"systemic-test-key",
    "DEFECT_CLOSURE_KEY_V01": b"defect-test-key",
    "MAIN_AUTHORITY_KEY_V01": b"main-test-key",
    "RULE_SOURCE_KEY_V01": b"rules-test-key",
}

KIND_CONFIG = {
    "independent_qualification": ("ECTOS_INDEPENDENT_QUALIFIER", "INDEPENDENT_QUALIFIER", "PASS", "QUALIFIER_KEY_V01"),
    "systemic_assurance": ("ECTOS_SYSTEMIC_ASSURANCE", "SYSTEMIC_ASSURANCE", "PASS", "SYSTEMIC_ASSURANCE_KEY_V01"),
    "consolidated_defect_closure": ("ECTOS_MAIN_DEFECT_CLOSURE", "CONSOLIDATED_DEFECT_CLOSURE_AUTHORITY", "CLOSED", "DEFECT_CLOSURE_KEY_V01"),
    "circuit_breaker": ("ECTOS_MAIN_AUTHORITY", "ECTOS_MAIN_AUTHORITY", "CLEAR", "MAIN_AUTHORITY_KEY_V01"),
    "rule_source_currentness": ("ECTOS_RULE_SOURCE_AUTHORITY", "ECTOS_RULE_SOURCE_AUTHORITY", "PROVEN_CURRENT", "RULE_SOURCE_KEY_V01"),
    "negative_controls": ("ECTOS_INDEPENDENT_QUALIFIER", "INDEPENDENT_QUALIFIER", "PASS", "QUALIFIER_KEY_V01"),
}

BINDING_FIELDS = (
    "package_id", "package_sha256", "manifest_sha256", "dependency_graph_sha256",
    "source_repository", "source_commit", "mission_id", "failure_family_id",
    "actor", "qualifier", "systemic_assurance_id", "admission_authority", "target", "action",
)


def attach_evidence(request: dict, nonce_prefix: str = "test") -> dict:
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
        bundle[kind] = sign_evidence(evidence, KEYRING[key_id])
    request["authority_evidence"] = bundle
    return request
