from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import subprocess
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

REQUIRED_FAMILY_IDS = {
    "PYTHON_EXECUTABLE_SOURCES",
    "JSON_CONTRACTS",
    "JSON_DURABLE_RUNTIME_STATE",
    "GOVERNED_MARKDOWN",
    "YAML_WORKFLOWS",
    "MANIFESTS",
    "SHA_SIDECARS",
    "RECEIPTS",
    "POINTERS",
    "MISSION_REGISTRY_MEMBERS",
    "DEPENDENCY_GRAPH_MEMBERS",
    "VERSIONED_GOVERNANCE_SOURCES",
    "PACKAGE_HANDOFF_IDENTITY_INPUTS",
    "BINARY_ARTIFACTS",
}

TEXT_PATTERNS = {"*.py", "*.json", "*.md", "*.yml", "*.yaml", "*.sha256"}
BINARY_PATTERNS = {"*.zip", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.pdf", "*.pfx", "*.der", "*.dll", "*.exe"}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise WorkspaceIdentityPolicyError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def _expand_double_star(pattern: str) -> set[str]:
    values = {pattern.lstrip("/")}
    pending = list(values)
    while pending:
        current = pending.pop()
        index = current.find("**/")
        if index >= 0:
            reduced = current[:index] + current[index + 3 :]
            if reduced not in values:
                values.add(reduced)
                pending.append(reduced)
    return values


def path_matches(path: str, pattern: str) -> bool:
    normalized = path.replace("\\", "/").lstrip("/")
    return any(fnmatch.fnmatchcase(normalized, candidate) for candidate in _expand_double_star(pattern))


def _pattern_specificity(pattern: str) -> tuple[int, int]:
    literal = pattern.replace("**", "").replace("*", "").replace("?", "")
    wildcard_count = pattern.count("*") + pattern.count("?")
    return (len(literal), -wildcard_count)


def matching_families(path: str, model: dict[str, Any]) -> list[dict[str, Any]]:
    ranked: list[tuple[tuple[int, int], str, dict[str, Any]]] = []
    for family in model["families"]:
        matches = [
            pattern
            for pattern in family["path_pattern_or_member_set"]
            if path_matches(path, pattern)
        ]
        if matches:
            score = max(_pattern_specificity(pattern) for pattern in matches)
            ranked.append((score, family["family_id"], family))
    ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in ranked]


def selected_family(path: str, model: dict[str, Any]) -> dict[str, Any] | None:
    matches = matching_families(path, model)
    return matches[0] if matches else None


def validate_member_model(model: dict[str, Any]) -> None:
    for field in ("model_id", "version", "status", "scope", "currentness_source", "selection_rules", "families"):
        if field not in model:
            raise WorkspaceIdentityPolicyError(f"MODEL_FIELD_MISSING:{field}")
    families = model["families"]
    if not isinstance(families, list) or not families:
        raise WorkspaceIdentityPolicyError("MODEL_FAMILIES_REQUIRED")
    ids: set[str] = set()
    for family in families:
        if not isinstance(family, dict):
            raise WorkspaceIdentityPolicyError("FAMILY_OBJECT_REQUIRED")
        missing = REQUIRED_FAMILY_FIELDS.difference(family)
        if missing:
            raise WorkspaceIdentityPolicyError(f"FAMILY_FIELDS_MISSING:{','.join(sorted(missing))}")
        family_id = family["family_id"]
        if not isinstance(family_id, str) or not family_id:
            raise WorkspaceIdentityPolicyError("FAMILY_ID_REQUIRED")
        if family_id in ids:
            raise WorkspaceIdentityPolicyError(f"DUPLICATE_FAMILY_ID:{family_id}")
        ids.add(family_id)
        patterns = family["path_pattern_or_member_set"]
        if not isinstance(patterns, list) or not patterns or not all(isinstance(x, str) and x for x in patterns):
            raise WorkspaceIdentityPolicyError(f"FAMILY_PATTERNS_REQUIRED:{family_id}")
        if family["byte_identity_required"] not in {"YES", "NO", "CONDITIONAL"}:
            raise WorkspaceIdentityPolicyError(f"BYTE_IDENTITY_INVALID:{family_id}")
        if family["eol_policy"] not in {"LF", "BINARY_PRESERVE"}:
            raise WorkspaceIdentityPolicyError(f"EOL_POLICY_INVALID:{family_id}")
        if family["binary_or_text"] not in {"TEXT", "BINARY"}:
            raise WorkspaceIdentityPolicyError(f"BINARY_TEXT_INVALID:{family_id}")
        if family["binary_or_text"] == "BINARY" and family["eol_policy"] != "BINARY_PRESERVE":
            raise WorkspaceIdentityPolicyError(f"BINARY_EOL_INVALID:{family_id}")
        if family["binary_or_text"] == "TEXT" and family["eol_policy"] != "LF":
            raise WorkspaceIdentityPolicyError(f"TEXT_EOL_INVALID:{family_id}")
    missing_required = REQUIRED_FAMILY_IDS.difference(ids)
    if missing_required:
        raise WorkspaceIdentityPolicyError(f"REQUIRED_FAMILY_MISSING:{','.join(sorted(missing_required))}")
    if model.get("selection_rules", {}).get("generic_engine_changes_required_for_new_family") is not False:
        raise WorkspaceIdentityPolicyError("GENERIC_ENGINE_MUST_BE_EXTENSIBLE")


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
    if binding.get("remote_commit_exists_implies_local_byte_identity") is not False:
        raise WorkspaceIdentityPolicyError("REMOTE_COMMIT_CANNOT_IMPLY_LOCAL_IDENTITY")


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
        if len(parts) < 2:
            raise WorkspaceIdentityPolicyError(f"GITATTRIBUTES_RULE_INVALID:{line}")
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


def _git(root: Path, *args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=text,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() if text else result.stderr.decode(errors="replace").strip()
        raise WorkspaceIdentityPolicyError(f"GIT_COMMAND_FAILED:{' '.join(args)}:{stderr}")
    return result.stdout


def _attr_value(root: Path, path: str, name: str) -> str:
    output = str(_git(root, "check-attr", name, "--", path)).strip()
    marker = f"{path}: {name}: "
    if not output.startswith(marker):
        raise WorkspaceIdentityPolicyError(f"ATTRIBUTE_OUTPUT_INVALID:{path}:{name}:{output}")
    return output[len(marker):]


def _workspace_eol(root: Path, path: str) -> str:
    output = str(_git(root, "ls-files", "--eol", "--", path)).strip()
    if not output:
        raise WorkspaceIdentityPolicyError(f"TRACKED_MEMBER_REQUIRED:{path}")
    parts = output.split()
    if len(parts) < 2:
        raise WorkspaceIdentityPolicyError(f"EOL_OUTPUT_INVALID:{path}:{output}")
    return parts[1]


def inspect_workspace_member(root: Path, path: str, model: dict[str, Any]) -> dict[str, Any]:
    family = selected_family(path, model)
    if family is None:
        raise WorkspaceIdentityPolicyError(f"UNREGISTERED_GOVERNED_FAMILY:{path}")
    full_path = root / Path(path)
    if not full_path.is_file():
        raise WorkspaceIdentityPolicyError(f"MEMBER_MISSING:{path}")
    blob_sha = str(_git(root, "rev-parse", f"HEAD:{path}")).strip()
    workspace_object = str(_git(root, "hash-object", "--no-filters", "--", path)).strip()
    blob_bytes = bytes(_git(root, "cat-file", "blob", blob_sha, text=False))
    workspace_bytes = full_path.read_bytes()
    result = {
        "path": path,
        "family_id": family["family_id"],
        "blob_sha": blob_sha,
        "workspace_object_sha": workspace_object,
        "workspace_sha256": hashlib.sha256(workspace_bytes).hexdigest().upper(),
        "blob_sha256": hashlib.sha256(blob_bytes).hexdigest().upper(),
        "byte_identity": "PASS" if workspace_bytes == blob_bytes and workspace_object == blob_sha else "FAIL",
    }
    if family["binary_or_text"] == "TEXT":
        text_attr = _attr_value(root, path, "text")
        eol_attr = _attr_value(root, path, "eol")
        workspace_eol = _workspace_eol(root, path)
        result.update({"text_attr": text_attr, "eol_attr": eol_attr, "workspace_eol": workspace_eol})
        if text_attr != "set" or eol_attr != "lf":
            raise WorkspaceIdentityPolicyError(f"TEXT_ATTRIBUTE_NOT_EXPLICIT_LF:{path}")
        if workspace_eol != "w/lf":
            raise WorkspaceIdentityPolicyError(f"WORKSPACE_EOL_MISMATCH:{path}:{workspace_eol}")
    else:
        text_attr = _attr_value(root, path, "text")
        result["text_attr"] = text_attr
        if text_attr != "unset":
            raise WorkspaceIdentityPolicyError(f"BINARY_TEXT_EXCLUSION_MISSING:{path}:{text_attr}")
    if result["byte_identity"] != "PASS":
        raise WorkspaceIdentityPolicyError(f"RAW_BYTE_IDENTITY_MISMATCH:{path}")
    return result


def tracked_governed_members(root: Path, model: dict[str, Any]) -> list[str]:
    raw = bytes(_git(root, "ls-files", "-z", text=False))
    paths = [item.decode("utf-8") for item in raw.split(b"\0") if item]
    return [path for path in paths if selected_family(path, model) is not None]


def inspect_workspace(root: Path, model: dict[str, Any]) -> list[dict[str, Any]]:
    return [inspect_workspace_member(root, path, model) for path in tracked_governed_members(root, model)]


def validate_materialization_evidence(evidence: dict[str, Any]) -> None:
    required = {
        "source_repository",
        "remote_commit",
        "local_head",
        "worktree_path",
        "host_identity",
        "materialization_evidence_current",
        "workspace_evidence_source",
        "raw_byte_identity_result",
        "runtime_identity",
    }
    missing = [field for field in sorted(required) if field not in evidence or evidence[field] in (None, "")]
    if missing:
        raise WorkspaceIdentityPolicyError(f"MATERIALIZATION_EVIDENCE_MISSING:{','.join(missing)}")
    if evidence["remote_commit"] != evidence["local_head"]:
        raise WorkspaceIdentityPolicyError("WRONG_MATERIALIZED_COMMIT")
    if evidence["materialization_evidence_current"] is not True:
        raise WorkspaceIdentityPolicyError("STALE_MATERIALIZATION_EVIDENCE")
    if evidence["workspace_evidence_source"] != "RAW_WORKSPACE_BYTES":
        raise WorkspaceIdentityPolicyError("BLOB_OR_NORMALIZED_WORKSPACE_SUBSTITUTION")
    if evidence["raw_byte_identity_result"] != "PASS":
        raise WorkspaceIdentityPolicyError("RAW_BYTE_IDENTITY_NOT_PROVEN")


def validate_all(root: Path, check_worktree: bool = False) -> list[dict[str, Any]]:
    base = root / "governance" / "workspace-identity"
    model = load_json(base / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V01.json")
    generic = load_json(base / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V01.json")
    materialization = load_json(base / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V01.json")
    validate_member_model(model)
    validate_generic_contract(generic)
    validate_materialization_contract(materialization)
    validate_gitattributes((root / ".gitattributes").read_text(encoding="utf-8"))
    return inspect_workspace(root, model) if check_worktree else []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--check-worktree", action="store_true")
    args = parser.parse_args()
    try:
        results = validate_all(args.root.resolve(), check_worktree=args.check_worktree)
    except (OSError, json.JSONDecodeError, WorkspaceIdentityPolicyError) as exc:
        print(f"FAIL:{exc}")
        return 40
    if args.check_worktree:
        print(json.dumps({"result": "PASS", "member_count": len(results), "members": results}, indent=2))
    else:
        print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
