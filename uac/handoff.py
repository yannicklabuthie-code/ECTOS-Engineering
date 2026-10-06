from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Dict

from uac_core import DEFAULT_REGISTRY, UACDenied, issue_receipt, verify_receipt

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


def _validate_source_repository(request: Dict[str, Any], registry_path: Path) -> str:
    source_repository = request.get("source_repository")
    if not isinstance(source_repository, str) or not source_repository:
        raise UACDenied("SOURCE_REPOSITORY_MISSING")
    registry = _read_json(registry_path)
    repo_cfg = registry.get("source_repositories", {}).get(source_repository)
    if not repo_cfg or not repo_cfg.get("enabled"):
        raise UACDenied("SOURCE_REPOSITORY_NOT_REGISTERED")
    actor = request.get("actor")
    if actor not in repo_cfg.get("actors", []):
        raise UACDenied("SOURCE_REPOSITORY_ACTOR_NOT_REGISTERED")
    return source_repository


def materialize_handoff(package_path: Path, manifest_path: Path, dependency_graph_path: Path, request_path: Path,
                        output_dir: Path, signing_key: bytes, commit_sha: str,
                        governance_attestation_path: Path,
                        registry_path: Path = DEFAULT_REGISTRY) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")
    if not package_path.is_file():
        raise UACDenied("PACKAGE_NOT_FOUND")
    if not manifest_path.is_file():
        raise UACDenied("MANIFEST_NOT_FOUND")
    if not dependency_graph_path.is_file():
        raise UACDenied("DEPENDENCY_GRAPH_NOT_FOUND")
    if not request_path.is_file():
        raise UACDenied("ADMISSION_REQUEST_NOT_FOUND")
    if not governance_attestation_path.is_file():
        raise UACDenied("GOVERNANCE_ATTESTATION_MISSING")
    if not isinstance(commit_sha, str) or len(commit_sha) < 7:
        raise UACDenied("COMMIT_SHA_INVALID")

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    dependency_graph_sha = _sha256_file(dependency_graph_path)
    request = _read_json(request_path)
    source_repository = _validate_source_repository(request, registry_path)
    governance_attestation = _read_json(governance_attestation_path)
    if governance_attestation.get("decision") != "PASS":
        raise UACDenied("GOVERNANCE_ATTESTATION_NOT_PASS")
    governance_attestation_sha = _sha256_file(governance_attestation_path)
    request["governance_attestation_sha256"] = governance_attestation_sha

    if request.get("package_sha256", "").lower() != package_sha:
        raise UACDenied("PACKAGE_SHA256_BINDING_MISMATCH")
    if request.get("manifest_sha256", "").lower() != manifest_sha:
        raise UACDenied("MANIFEST_SHA256_BINDING_MISMATCH")
    if request.get("dependency_graph_sha256", "").lower() != dependency_graph_sha:
        raise UACDenied("DEPENDENCY_GRAPH_SHA256_BINDING_MISMATCH")
    if request.get("target") != HANDOFF_TARGET:
        raise UACDenied("HANDOFF_TARGET_INVALID")
    if request.get("action") != HANDOFF_ACTION:
        raise UACDenied("HANDOFF_ACTION_INVALID")

    receipt = issue_receipt(request, signing_key, registry_path=registry_path)
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
        "source_commit_sha": commit_sha,
        "source_repository": source_repository,
        "governance_attestation_sha256": governance_attestation_sha,
        "governance_attestation_file": "GOVERNANCE_ATTESTATION.json",
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
    governance_output_path = output_dir / "GOVERNANCE_ATTESTATION.json"
    _write_json(receipt_path, receipt)
    _write_json(descriptor_path, descriptor)
    governance_output_path.write_bytes(governance_attestation_path.read_bytes())

    return descriptor


def verify_handoff(package_path: Path, manifest_path: Path, dependency_graph_path: Path, descriptor_path: Path,
                   receipt_path: Path, governance_attestation_path: Path, signing_key: bytes,
                   expected_commit_sha: str | None = None) -> Dict[str, Any]:
    if not signing_key:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")

    descriptor = _read_json(descriptor_path)
    receipt = _read_json(receipt_path)
    if not governance_attestation_path.is_file():
        raise UACDenied("GOVERNANCE_ATTESTATION_MISSING")
    governance_attestation = _read_json(governance_attestation_path)
    if governance_attestation.get("decision") != "PASS":
        raise UACDenied("GOVERNANCE_ATTESTATION_NOT_PASS")
    governance_attestation_sha = _sha256_file(governance_attestation_path)

    if descriptor.get("schema_id") != HANDOFF_SCHEMA:
        raise UACDenied("HANDOFF_SCHEMA_INVALID")
    if descriptor.get("state") != HANDOFF_STATE:
        raise UACDenied("HANDOFF_STATE_INVALID")

    package_sha = _sha256_file(package_path)
    manifest_sha = _sha256_file(manifest_path)
    dependency_graph_sha = _sha256_file(dependency_graph_path)
    if descriptor.get("package_sha256") != package_sha:
        raise UACDenied("HANDOFF_PACKAGE_TAMPERED")
    if descriptor.get("manifest_sha256") != manifest_sha:
        raise UACDenied("HANDOFF_MANIFEST_TAMPERED")
    if descriptor.get("dependency_graph_sha256") != dependency_graph_sha:
        raise UACDenied("HANDOFF_DEPENDENCY_GRAPH_TAMPERED")
    if expected_commit_sha is not None and descriptor.get("source_commit_sha") != expected_commit_sha:
        raise UACDenied("HANDOFF_COMMIT_MISMATCH")

    verified = verify_receipt(receipt, signing_key, HANDOFF_TARGET, HANDOFF_ACTION)
    payload = receipt["payload"]
    if payload.get("package_sha256") != package_sha:
        raise UACDenied("RECEIPT_PACKAGE_BINDING_MISMATCH")
    if payload.get("manifest_sha256") != manifest_sha:
        raise UACDenied("RECEIPT_MANIFEST_BINDING_MISMATCH")
    if payload.get("dependency_graph_sha256") != dependency_graph_sha:
        raise UACDenied("RECEIPT_DEPENDENCY_GRAPH_BINDING_MISMATCH")
    if descriptor.get("receipt_id") != payload.get("receipt_id"):
        raise UACDenied("HANDOFF_RECEIPT_ID_MISMATCH")
    if descriptor.get("source_repository") != payload.get("source_repository"):
        raise UACDenied("HANDOFF_SOURCE_REPOSITORY_BINDING_MISMATCH")
    if descriptor.get("governance_attestation_sha256") != governance_attestation_sha:
        raise UACDenied("HANDOFF_GOVERNANCE_ATTESTATION_TAMPERED")
    if payload.get("governance_attestation_sha256") != governance_attestation_sha:
        raise UACDenied("RECEIPT_GOVERNANCE_ATTESTATION_BINDING_MISMATCH")

    return {
        "decision": "ADMIT",
        "state": HANDOFF_STATE,
        "receipt_id": verified["receipt_id"],
        "package_sha256": package_sha,
        "manifest_sha256": manifest_sha,
        "dependency_graph_sha256": dependency_graph_sha,
    }
