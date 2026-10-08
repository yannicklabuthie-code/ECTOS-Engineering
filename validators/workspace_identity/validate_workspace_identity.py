from __future__ import annotations

import argparse
import fnmatch
import json
from pathlib import Path
from typing import Any


class WorkspaceIdentityPolicyError(ValueError):
    pass


REQUIRED_FAMILY_FIELDS = {
    "family_id",
    "path_pattern_or_member_set",
    "byte_identity_required",
    "eol_policy",
    "binary_or_text",
    "qualification_required",
    "currentness_source",
    "exceptions",
    "rationale",
}

TEXT_PATTERNS = {"*.py", "*.json", "*.md", "*.yml", "*.yaml", "*.sha256"}
BINARY_PATTERNS = {"*.zip", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.pdf", "*.pfx", "*.der", "*.dll", "*.exe"}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise WorkspaceIdentityPolicyError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def validate_member_model(model: dict[str, Any]) -> None:
    for field in ("model_id", "version", "status", "scope", "currentness_source", "selection_rules", "families"):
        if field not in model:
            raise WorkspaceIdentityPolicyError(f"MODEL_FIELD_MISSING:{field}")
    families = model["families"]
    if not isinstance(families, list) or not families:
        raise WorkspaceIdentityPolicyError("MODEL_FAMILIES_REQUIRED")
    ids: set[str] = set()
    for family in families:
        missing = REQUIRED_FAMILY_FIELDS.difference(family)
        if missing:
            raise WorkspaceIdentityPolicyError(f"FAMILY_FIELDS_MISSING:{','.join(sorted(missing))}")
        family_id = family["family_id"]
        if family_id in ids:
            raise WorkspaceIdentityPolicyError(f"DUPLICATE_FAMILY_ID:{family_id}")
        ids.add(family_id)
        if not family["path_pattern_or_member_set"]:
            raise WorkspaceIdentityPolicyError(f"FAMILY_PATTERNS_REQUIRED:{family_id}")
        if family["byte_identity_required"] not in {"YES", "NO", "CONDITIONAL"}:
            raise WorkspaceIdentityPolicyError(f"BYTE_IDENTITY_INVALID:{family_id}")
        if family["eol_policy"] not in {"LF", "BINARY_PRESERVE"}:
            raise WorkspaceIdentityPolicyError(f"EOL_POLICY_INVALID:{family_id}")
        if family["binary_or_text"] == "BINARY" and family["eol_policy"] != "BINARY_PRESERVE":
            raise WorkspaceIdentityPolicyError(f"BINARY_EOL_INVALID:{family_id}")
    for required in ("MISSION_REGISTRY_MEMBERS", "DEPENDENCY_GRAPH_MEMBERS", "BINARY_ARTIFACTS"):
        if required not in ids:
            raise WorkspaceIdentityPolicyError(f"REQUIRED_FAMILY_MISSING:{required}")


def validate_generic_contract(contract: dict[str, Any]) -> None:
    if contract.get("normalization_during_hash") != "PROHIBITED":
        raise WorkspaceIdentityPolicyError("NORMALIZATION_MUST_BE_PROHIBITED")
    if contract.get("blob_substitution_as_workspace_evidence") != "PROHIBITED":
        raise WorkspaceIdentityPolicyError("BLOB_SUBSTITUTION_MUST_BE_PROHIBITED")
    if contract.get("rollback_boundary", {}).get("host_global_config_mutation_required") is not False:
        raise WorkspaceIdentityPolicyError("HOST_GLOBAL_CONFIG_MUST_NOT_BE_REQUIRED")
    rule = contract.get("worktree_byte_identity_rule", {})
    if rule.get("required_comparison") != "EQUAL":
        raise WorkspaceIdentityPolicyError("RAW_BYTE_COMPARISON_MUST_BE_EQUAL")
    if rule.get("clean_git_status_is_sufficient") is not False:
        raise WorkspaceIdentityPolicyError("CLEAN_STATUS_CANNOT_BE_BYTE_EVIDENCE")
    expected = [
        "REMOTE_CANDIDATE_IDENTITY",
        "LOCAL_MATERIALIZATION_IDENTITY",
        "WORKTREE_HOST_BINDING",
        "RAW_BYTE_IDENTITY",
        "RUNTIME_IDENTITY",
        "TEST_EXECUTION",
        "RESULT_EVIDENCE",
    ]
    binding = contract.get("qualification_binding", {})
    if binding.get("required_chain") != expected:
        raise WorkspaceIdentityPolicyError("QUALIFICATION_CHAIN_INVALID")
    if binding.get("remote_commit_exists_implies_execution_ready") is not False:
        raise WorkspaceIdentityPolicyError("REMOTE_COMMIT_CANNOT_IMPLY_EXECUTION_READY")


def validate_materialization_contract(contract: dict[str, Any]) -> None:
    if contract.get("host_global_config_required") is not False:
        raise WorkspaceIdentityPolicyError("HOST_GLOBAL_CONFIG_REQUIRED_FORBIDDEN")
    if contract.get("system_core_autocrlf_true_supported") is not True:
        raise WorkspaceIdentityPolicyError("AUTOCRLF_TRUE_CONTROL_REQUIRED")
    if contract.get("normalized_hash_substitution") != "PROHIBITED":
        raise WorkspaceIdentityPolicyError("NORMALIZED_HASH_SUBSTITUTION_FORBIDDEN")
    if contract.get("blob_bytes_as_workspace_evidence") != "PROHIBITED":
        raise WorkspaceIdentityPolicyError("BLOB_WORKSPACE_SUBSTITUTION_FORBIDDEN")
    if contract.get("fresh_materialization_rule", {}).get("execution_eligible_before_all_proofs") is not False:
        raise WorkspaceIdentityPolicyError("EXECUTION_MUST_FAIL_CLOSED")
    if contract.get("existing_worktree_migration_rule", {}).get("silent_migration") != "PROHIBITED":
        raise WorkspaceIdentityPolicyError("SILENT_MIGRATION_FORBIDDEN")
    if contract.get("dependency_graph_binding", {}).get("duplicate_graph_topology_in_mission_registry") is not False:
        raise WorkspaceIdentityPolicyError("MISSION_REGISTRY_GRAPH_DUPLICATION_FORBIDDEN")


def parse_gitattributes(text: str) -> list[tuple[str, tuple[str, ...]]]:
    result = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        result.append((parts[0], tuple(parts[1:])))
    return result


def validate_gitattributes(text: str) -> None:
    rules = parse_gitattributes(text)
    if any(pattern == "*" and "text" in attrs for pattern, attrs in rules):
        raise WorkspaceIdentityPolicyError("BLIND_TEXT_POLICY_FORBIDDEN")
    lf_patterns = {pattern for pattern, attrs in rules if "text" in attrs and "eol=lf" in attrs}
    missing_text = TEXT_PATTERNS.difference(lf_patterns)
    if missing_text:
        raise WorkspaceIdentityPolicyError(f"TEXT_EOL_POLICY_MISSING:{','.join(sorted(missing_text))}")
    binary = {pattern for pattern, attrs in rules if "-text" in attrs}
    missing_binary = BINARY_PATTERNS.difference(binary)
    if missing_binary:
        raise WorkspaceIdentityPolicyError(f"BINARY_EXCLUSION_MISSING:{','.join(sorted(missing_binary))}")


def matching_families(path: str, model: dict[str, Any]) -> list[str]:
    normalized = path.replace("\\", "/")
    return [
        family["family_id"]
        for family in model["families"]
        if any(fnmatch.fnmatch(normalized, pattern) for pattern in family["path_pattern_or_member_set"])
    ]


def validate_all(root: Path) -> None:
    base = root / "governance" / "workspace-identity"
    model = load_json(base / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V01.json")
    generic = load_json(base / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V01.json")
    materialization = load_json(base / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V01.json")
    validate_member_model(model)
    validate_generic_contract(generic)
    validate_materialization_contract(materialization)
    validate_gitattributes((root / ".gitattributes").read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    try:
        validate_all(args.root.resolve())
    except (OSError, json.JSONDecodeError, WorkspaceIdentityPolicyError) as exc:
        print(f"FAIL:{exc}")
        return 40
    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
