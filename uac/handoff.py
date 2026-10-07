from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

from byte_contract import canonical_json_bytes, validate_canonical_json_file, write_canonical_json
from uac_core import DEFAULT_EVIDENCE_LEDGER, DEFAULT_REGISTRY, UACDenied, issue_receipt, verify_receipt

HANDOFF_SCHEMA = "ECTOS_CANONICAL_HANDOFF_V03"
HANDOFF_STATE = "PACKAGE_READY_FOR_HANDOFF"
HANDOFF_TARGET = "ECTOS_PACKAGE_HANDOFF"
HANDOFF_ACTION = "ISSUE_HANDOFF"


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _require_sha256(name: str, value: Any) -> str:
    if not isinstance(value, str) or len(value) != 64:
        raise UACDenied(f"{name}_INVALID")
    try:
        int(value, 16)
    except ValueError as exc:
        raise UACDenied(f"{name}_INVALID") from exc
    return value.lower()


def _require_commit(name: str, value: Any) -> str:
    if not isinstance(value, str) or len(value) != 40:
        raise UACDenied(f"{name}_INVALID")
    try:
        int(value, 16)
    except ValueError as exc:
        raise UACDenied(f"{name}_INVALID") from exc
    return value.lower()


def _parse_time(name: str, value: Any) -> datetime:
    if not isinstance(value, str) or not value:
        raise UACDenied(f"PRE_DISPATCH_{name.upper()}_MISSING")
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError as exc:
        raise UACDenied(f"PRE_DISPATCH_{name.upper()}_INVALID") from exc
    if parsed.tzinfo is None:
        raise UACDenied(f"PRE_DISPATCH_{name.upper()}_NAIVE")
    return parsed.astimezone(timezone.utc)


def _validate_source_repository(request: Dict[str, Any], registry_path: Path) -> str:
    registry = validate_canonical_json_file(registry_path)
    source_repository = request.get("source_repository")
    if not isinstance(source_repository, str) or not source_repository:
        raise UACDenied("SOURCE_REPOSITORY_MISSING")
    repo_cfg = registry.get("source_repositories", {}).get(source_repository)
    if not repo_cfg or not repo_cfg.get("enabled"):
        raise UACDenied("SOURCE_REPOSITORY_NOT_REGISTERED")
    actor = request.get("actor")
    if actor not in repo_cfg.get("actors", []):
        raise UACDenied("SOURCE_REPOSITORY_ACTOR_NOT_REGISTERED")
    return source_repository


def _validate_pre_dispatch(
    pre_dispatch_receipt_path: Path,
    staged_paths_path: Path,
    package_path: Path,
    manifest_path: Path,
    dependency_graph_path: Path,
    request_path: Path,
    request: Dict[str, Any],
    source_commit_sha: str,
) -> Dict[str, Any]:
    receipt = validate_canonical_json_file(pre_dispatch_receipt_path)
    staged_paths = validate_canonical_json_file(staged_paths_path)
    if receipt.get("schema_id") != "ECTOS_UAC_PRE_DISPATCH_RECEIPT_V03":
        raise UACDenied("PRE_DISPATCH_SCHEMA_INVALID")
    if receipt.get("decision") != "PASS":
        raise UACDenied("PRE_DISPATCH_DECISION_NOT_PASS")
    issued_at = _parse_time("issued_at", receipt.get("issued_at"))
    expires_at = _parse_time("expires_at", receipt.get("expires_at"))
    now = datetime.now(timezone.utc)
    if issued_at > now:
        raise UACDenied("PRE_DISPATCH_NOT_YET_VALID")
    if now >= expires_at:
        raise UACDenied("PRE_DISPATCH_STALE")
    if receipt.get("package_id") != request.get("package_id"):
        raise UACDenied("PRE_DISPATCH_PACKAGE_ID_MISMATCH")
    if receipt.get("mission_id") != request.get("mission_id"):
        raise UACDenied("PRE_DISPATCH_MISSION_MISMATCH")
    if receipt.get("source_repository") != request.get("source_repository"):
        raise UACDenied("PRE_DISPATCH_SOURCE_REPOSITORY_MISMATCH")
    expected_source_commit = _require_commit("SOURCE_COMMIT", source_commit_sha)
    if _require_commit("PRE_DISPATCH_SOURCE_COMMIT", receipt.get("source_commit")) != expected_source_commit:
        raise UACDenied("PRE_DISPATCH_SOURCE_COMMIT_MISMATCH")
    staging_commit = _require_commit("PRE_DISPATCH_STAGING_COMMIT", receipt.get("staging_commit"))

    expected_hashes = {
        "package": _sha256_file(package_path),
        "manifest": _sha256_file(manifest_path),
        "dependency_graph": _sha256_file(dependency_graph_path),
        "request": _sha256_file(request_path),
    }
    files = receipt.get("files")
    if not isinstance(files, dict):
        raise UACDenied("PRE_DISPATCH_FILES_MISSING")
    for role, expected_hash in expected_hashes.items():
        entry = files.get(role)
        if not isinstance(entry, dict) or entry.get("sha256") != expected_hash:
            raise UACDenied(f"PRE_DISPATCH_{role.upper()}_BINDING_MISMATCH")
    if receipt.get("staged_path_set") != staged_paths:
        raise UACDenied("PRE_DISPATCH_STAGED_PATH_SET_MISMATCH")
    staged_hash = hashlib.sha256(canonical_json_bytes(staged_paths)).hexdigest()
    if receipt.get("staged_path_set_sha256") != staged_hash:
        raise UACDenied("PRE_DISPATCH_STAGED_PATH_SET_SHA256_MISMATCH")
    source_tree_sha = _require_sha256("PRE_DISPATCH_SOURCE_TREE_SHA256", receipt.get("source_tree_sha256"))
    return {
        "receipt_sha256": _sha256_file(pre_dispatch_receipt_path),
        "staged_path_set_sha256": staged_hash,
        "source_tree_sha256": source_tree_sha,
        "staging_commit": staging_commit,
        "receipt": receipt,
        "staged_paths": staged_paths,
    }


def materialize_handoff(
    package_path: Path,
    manifest_path: Path,
    dependency_graph_path: Path,
    request_path: Path,
    pre_dispatch_receipt_path: Path,
    staged_paths_path: Path,
    output_dir: Path,
    signing_key: bytes,
    commit_sha: str,
    governance_attestation_path: Path,
    authority_keyring: Dict[str, Dict[str, Any]],
    registry_path: Path = DEFAULT_REGISTRY,
    evidence_ledger_path: Path = DEFAULT_EVIDENCE_LEDGER,
) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")
    for name, path in {
        "PACKAGE": package_path,
        "MANIFEST": manifest_path,
        "DEPENDENCY_GRAPH": dependency_graph_path,
        "ADMISSION_REQUEST": request_path,
        "PRE_DISPATCH_RECEIPT": pre_dispatch_receipt_path,
        "STAGED_PATHS": staged_paths_path,
        "GOVERNANCE_ATTESTATION": governance_attestation_path,
    }.items():
        if not path.is_file():
            raise UACDenied(f"{name}_NOT_FOUND")
    source_commit = _require_commit("COMMIT_SHA", commit_sha)

    validate_canonical_json_file(manifest_path)
    validate_canonical_json_file(dependency_graph_path)
    request = validate_canonical_json_file(request_path)
    governance_attestation = validate_canonical_json_file(governance_attestation_path)

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    dependency_graph_sha = _sha256_file(dependency_graph_path)
    source_repository = _validate_source_repository(request, registry_path)
    if governance_attestation.get("decision") != "PASS":
        raise UACDenied("GOVERNANCE_ATTESTATION_NOT_PASS")
    governance_attestation_sha = _sha256_file(governance_attestation_path)

    if request.get("package_sha256", "").lower() != package_sha:
        raise UACDenied("PACKAGE_SHA256_BINDING_MISMATCH")
    if request.get("manifest_sha256", "").lower() != manifest_sha:
        raise UACDenied("MANIFEST_SHA256_BINDING_MISMATCH")
    if request.get("dependency_graph_sha256", "").lower() != dependency_graph_sha:
        raise UACDenied("DEPENDENCY_GRAPH_SHA256_BINDING_MISMATCH")
    if request.get("source_commit", "").lower() != source_commit:
        raise UACDenied("SOURCE_COMMIT_BINDING_MISMATCH")
    if request.get("target") != HANDOFF_TARGET:
        raise UACDenied("HANDOFF_TARGET_INVALID")
    if request.get("action") != HANDOFF_ACTION:
        raise UACDenied("HANDOFF_ACTION_INVALID")

    pre_dispatch = _validate_pre_dispatch(
        pre_dispatch_receipt_path, staged_paths_path, package_path, manifest_path,
        dependency_graph_path, request_path, request, source_commit,
    )
    request = dict(request)
    request["governance_attestation_sha256"] = governance_attestation_sha
    request["pre_dispatch_receipt_sha256"] = pre_dispatch["receipt_sha256"]
    request["staged_path_set_sha256"] = pre_dispatch["staged_path_set_sha256"]
    request["source_tree_sha256"] = pre_dispatch["source_tree_sha256"]

    receipt = issue_receipt(
        request,
        signing_key,
        registry_path=registry_path,
        authority_keyring=authority_keyring,
        evidence_ledger_path=evidence_ledger_path,
    )
    verify_receipt(receipt, signing_key, HANDOFF_TARGET, HANDOFF_ACTION)

    payload = receipt["payload"]
    descriptor = {
        "schema_id": HANDOFF_SCHEMA,
        "state": HANDOFF_STATE,
        "package_name": package_path.name,
        "package_sha256": package_sha,
        "manifest_name": manifest_path.name,
        "manifest_sha256": manifest_sha,
        "dependency_graph_name": dependency_graph_path.name,
        "dependency_graph_sha256": dependency_graph_sha,
        "source_commit_sha": source_commit,
        "staging_commit_sha": pre_dispatch["staging_commit"],
        "source_repository": source_repository,
        "source_tree_sha256": pre_dispatch["source_tree_sha256"],
        "pre_dispatch_receipt_sha256": pre_dispatch["receipt_sha256"],
        "staged_path_set_sha256": pre_dispatch["staged_path_set_sha256"],
        "governance_attestation_sha256": governance_attestation_sha,
        "governance_attestation_file": "GOVERNANCE_ATTESTATION.json",
        "authority_evidence_sha256": payload["authority_evidence_sha256"],
        "receipt_id": payload["receipt_id"],
        "receipt_version": payload["receipt_version"],
        "receipt_issuer_id": payload["issuer_id"],
        "receipt_file": "UAC_RECEIPT.json",
        "pre_dispatch_receipt_file": "PRE_DISPATCH_RECEIPT.json",
        "staged_paths_file": "STAGED_PATHS.json",
        "admission_target": payload["target"],
        "admission_action": payload["action"],
        "failure_family_id": payload["failure_family_id"],
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    write_canonical_json(output_dir / "UAC_RECEIPT.json", receipt)
    write_canonical_json(output_dir / "HANDOFF_DESCRIPTOR.json", descriptor)
    (output_dir / "GOVERNANCE_ATTESTATION.json").write_bytes(governance_attestation_path.read_bytes())
    (output_dir / "PRE_DISPATCH_RECEIPT.json").write_bytes(pre_dispatch_receipt_path.read_bytes())
    (output_dir / "STAGED_PATHS.json").write_bytes(staged_paths_path.read_bytes())
    return descriptor


def verify_handoff(
    package_path: Path,
    manifest_path: Path,
    dependency_graph_path: Path,
    descriptor_path: Path,
    receipt_path: Path,
    pre_dispatch_receipt_path: Path,
    staged_paths_path: Path,
    governance_attestation_path: Path,
    signing_key: bytes,
    expected_commit_sha: str | None = None,
) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")
    descriptor = validate_canonical_json_file(descriptor_path)
    receipt = validate_canonical_json_file(receipt_path)
    pre = validate_canonical_json_file(pre_dispatch_receipt_path)
    staged_paths = validate_canonical_json_file(staged_paths_path)
    governance_attestation = validate_canonical_json_file(governance_attestation_path)
    if governance_attestation.get("decision") != "PASS":
        raise UACDenied("GOVERNANCE_ATTESTATION_NOT_PASS")
    if descriptor.get("schema_id") != HANDOFF_SCHEMA:
        raise UACDenied("HANDOFF_SCHEMA_INVALID")
    if descriptor.get("state") != HANDOFF_STATE:
        raise UACDenied("HANDOFF_STATE_INVALID")
    if pre.get("schema_id") != "ECTOS_UAC_PRE_DISPATCH_RECEIPT_V03":
        raise UACDenied("PRE_DISPATCH_SCHEMA_INVALID")
    if pre.get("decision") != "PASS":
        raise UACDenied("PRE_DISPATCH_DECISION_NOT_PASS")
    if datetime.now(timezone.utc) >= _parse_time("expires_at", pre.get("expires_at")):
        raise UACDenied("PRE_DISPATCH_STALE")

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    dependency_graph_sha = _sha256_file(dependency_graph_path)
    governance_sha = _sha256_file(governance_attestation_path)
    pre_sha = _sha256_file(pre_dispatch_receipt_path)
    staged_hash = hashlib.sha256(canonical_json_bytes(staged_paths)).hexdigest()
    source_tree_sha = _require_sha256("PRE_DISPATCH_SOURCE_TREE_SHA256", pre.get("source_tree_sha256"))
    pre_source_commit = _require_commit("PRE_DISPATCH_SOURCE_COMMIT", pre.get("source_commit"))
    pre_staging_commit = _require_commit("PRE_DISPATCH_STAGING_COMMIT", pre.get("staging_commit"))

    if descriptor.get("package_sha256") != package_sha:
        raise UACDenied("HANDOFF_PACKAGE_TAMPERED")
    if descriptor.get("manifest_sha256") != manifest_sha:
        raise UACDenied("HANDOFF_MANIFEST_TAMPERED")
    if descriptor.get("dependency_graph_sha256") != dependency_graph_sha:
        raise UACDenied("HANDOFF_DEPENDENCY_GRAPH_TAMPERED")
    if descriptor.get("pre_dispatch_receipt_sha256") != pre_sha:
        raise UACDenied("HANDOFF_PRE_DISPATCH_RECEIPT_TAMPERED")
    if descriptor.get("staged_path_set_sha256") != staged_hash:
        raise UACDenied("HANDOFF_STAGED_PATH_SET_MISMATCH")
    if descriptor.get("source_tree_sha256") != source_tree_sha:
        raise UACDenied("HANDOFF_SOURCE_TREE_BINDING_MISMATCH")
    if descriptor.get("staging_commit_sha") != pre_staging_commit:
        raise UACDenied("HANDOFF_STAGING_COMMIT_BINDING_MISMATCH")
    if pre.get("staged_path_set") != staged_paths or pre.get("staged_path_set_sha256") != staged_hash:
        raise UACDenied("PRE_DISPATCH_STAGED_PATH_SET_MISMATCH")
    pre_files = pre.get("files", {})
    for role, expected_hash in {"package": package_sha, "manifest": manifest_sha, "dependency_graph": dependency_graph_sha}.items():
        if not isinstance(pre_files.get(role), dict) or pre_files[role].get("sha256") != expected_hash:
            raise UACDenied(f"PRE_DISPATCH_{role.upper()}_BINDING_MISMATCH")
    if expected_commit_sha is not None and pre_source_commit != _require_commit("EXPECTED_COMMIT_SHA", expected_commit_sha):
        raise UACDenied("HANDOFF_COMMIT_MISMATCH")

    verified = verify_receipt(receipt, signing_key, HANDOFF_TARGET, HANDOFF_ACTION)
    payload = receipt["payload"]
    binding_checks = {
        "package_sha256": package_sha,
        "manifest_sha256": manifest_sha,
        "dependency_graph_sha256": dependency_graph_sha,
        "pre_dispatch_receipt_sha256": pre_sha,
        "staged_path_set_sha256": staged_hash,
        "source_tree_sha256": source_tree_sha,
    }
    for field, expected in binding_checks.items():
        if payload.get(field) != expected:
            raise UACDenied(f"RECEIPT_{field.upper()}_BINDING_MISMATCH")
    if descriptor.get("receipt_id") != payload.get("receipt_id"):
        raise UACDenied("HANDOFF_RECEIPT_ID_MISMATCH")
    if descriptor.get("source_repository") != payload.get("source_repository") or pre.get("source_repository") != payload.get("source_repository"):
        raise UACDenied("HANDOFF_SOURCE_REPOSITORY_BINDING_MISMATCH")
    if descriptor.get("source_commit_sha") != payload.get("source_commit") or pre_source_commit != payload.get("source_commit"):
        raise UACDenied("HANDOFF_SOURCE_COMMIT_BINDING_MISMATCH")
    if pre.get("mission_id") != payload.get("mission_id") or pre.get("package_id") != payload.get("package_id"):
        raise UACDenied("HANDOFF_PRE_DISPATCH_CONTEXT_MISMATCH")
    if descriptor.get("authority_evidence_sha256") != payload.get("authority_evidence_sha256"):
        raise UACDenied("HANDOFF_AUTHORITY_EVIDENCE_BINDING_MISMATCH")
    if descriptor.get("governance_attestation_sha256") != governance_sha:
        raise UACDenied("HANDOFF_GOVERNANCE_ATTESTATION_TAMPERED")
    if payload.get("governance_attestation_sha256") != governance_sha:
        raise UACDenied("RECEIPT_GOVERNANCE_ATTESTATION_BINDING_MISMATCH")
    return {
        "decision": "ADMIT",
        "state": HANDOFF_STATE,
        "receipt_id": verified["receipt_id"],
        "package_sha256": package_sha,
        "manifest_sha256": manifest_sha,
        "dependency_graph_sha256": dependency_graph_sha,
        "pre_dispatch_receipt_sha256": pre_sha,
        "staged_path_set_sha256": staged_hash,
        "source_tree_sha256": source_tree_sha,
    }
