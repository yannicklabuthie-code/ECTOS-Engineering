from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(REPOSITORY_ROOT))

from engineering.dependency_graph import load_graph, validate_graph


class WorkspaceIdentityPolicyError(ValueError):
    pass


COMMIT_RE = re.compile(r"^[A-Fa-f0-9]{40}$")
SHA256_RE = re.compile(r"^[A-Fa-f0-9]{64}$")
REQUIRED_FAMILY_IDS = {
    "PYTHON_EXECUTABLE_SOURCES", "JSON_CONTRACTS", "JSON_DURABLE_RUNTIME_STATE",
    "GOVERNED_MARKDOWN", "YAML_WORKFLOWS", "MANIFESTS", "SHA_SIDECARS",
    "RECEIPTS", "POINTERS", "MISSION_REGISTRY_MEMBERS", "DEPENDENCY_GRAPH_MEMBERS",
    "VERSIONED_GOVERNANCE_SOURCES", "PACKAGE_HANDOFF_IDENTITY_INPUTS", "BINARY_ARTIFACTS",
}
REQUIRED_FAMILY_FIELDS = {
    "family_id", "path_pattern_or_member_set", "priority", "byte_identity_required",
    "eol_policy", "binary_or_text", "qualification_required", "currentness_source",
    "exceptions", "rationale",
}
TEXT_PATTERNS = {"*.py", "*.json", "*.md", "*.yml", "*.yaml", "*.sha256"}
BINARY_PATTERNS = {"*.zip", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.pdf", "*.pfx", "*.der", "*.dll", "*.exe"}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise WorkspaceIdentityPolicyError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _git(root: Path, *args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=text, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() if text else result.stderr.decode(errors="replace").strip()
        raise WorkspaceIdentityPolicyError(f"GIT_COMMAND_FAILED:{' '.join(args)}:{stderr}")
    return result.stdout


def _git_optional(root: Path, *args: str) -> tuple[int, str, str]:
    result = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    return result.returncode, result.stdout, result.stderr


def _expand_double_star(pattern: str) -> set[str]:
    values = {pattern.replace("\\", "/").lstrip("/")}
    pending = list(values)
    while pending:
        current = pending.pop()
        index = current.find("**/")
        if index >= 0:
            reduced = current[:index] + current[index + 3:]
            if reduced not in values:
                values.add(reduced)
                pending.append(reduced)
    return values


def path_matches(path: str, pattern: str) -> bool:
    normalized = path.replace("\\", "/").lstrip("/")
    return any(fnmatch.fnmatchcase(normalized, candidate) for candidate in _expand_double_star(pattern))


def _pattern_specificity(pattern: str) -> tuple[int, int]:
    literal = pattern.replace("**", "").replace("*", "").replace("?", "")
    return len(literal), -(pattern.count("*") + pattern.count("?"))


def _family_match_score(path: str, family: dict[str, Any]) -> tuple[int, tuple[int, int]] | None:
    if any(path_matches(path, pattern) for pattern in family.get("exceptions", [])):
        return None
    matches = [pattern for pattern in family["path_pattern_or_member_set"] if path_matches(path, pattern)]
    if not matches:
        return None
    return int(family["priority"]), max(_pattern_specificity(pattern) for pattern in matches)


def matching_families(path: str, model: dict[str, Any]) -> list[tuple[tuple[int, tuple[int, int]], dict[str, Any]]]:
    matches: list[tuple[tuple[int, tuple[int, int]], dict[str, Any]]] = []
    for family in model["families"]:
        score = _family_match_score(path, family)
        if score is not None:
            matches.append((score, family))
    matches.sort(key=lambda item: item[0], reverse=True)
    return matches


def selected_family(path: str, model: dict[str, Any]) -> dict[str, Any] | None:
    matches = matching_families(path, model)
    if not matches:
        return None
    if len(matches) > 1 and matches[0][0] == matches[1][0]:
        ids = sorted([matches[0][1]["family_id"], matches[1][1]["family_id"]])
        raise WorkspaceIdentityPolicyError(f"SEMANTIC_FAMILY_COLLISION:{path}:{','.join(ids)}")
    return matches[0][1]


def validate_schema_instance(value: Any, schema: dict[str, Any], label: str = "$") -> None:
    expected_type = schema.get("type")
    if expected_type:
        type_map = {"object": dict, "array": list, "string": str, "integer": int, "boolean": bool, "null": type(None)}
        expected = expected_type if isinstance(expected_type, list) else [expected_type]
        valid = False
        for item in expected:
            py = type_map[item]
            if item == "integer":
                valid = valid or (isinstance(value, int) and not isinstance(value, bool))
            else:
                valid = valid or isinstance(value, py)
        if not valid:
            raise WorkspaceIdentityPolicyError(f"SCHEMA_TYPE_INVALID:{label}:{expected_type}")
    if "const" in schema and value != schema["const"]:
        raise WorkspaceIdentityPolicyError(f"SCHEMA_CONST_INVALID:{label}")
    if "enum" in schema and value not in schema["enum"]:
        raise WorkspaceIdentityPolicyError(f"SCHEMA_ENUM_INVALID:{label}")
    if isinstance(value, str):
        if len(value) < int(schema.get("minLength", 0)):
            raise WorkspaceIdentityPolicyError(f"SCHEMA_MIN_LENGTH:{label}")
        if schema.get("pattern") and not re.fullmatch(schema["pattern"], value):
            raise WorkspaceIdentityPolicyError(f"SCHEMA_PATTERN_INVALID:{label}")
    if isinstance(value, list):
        if len(value) < int(schema.get("minItems", 0)):
            raise WorkspaceIdentityPolicyError(f"SCHEMA_MIN_ITEMS:{label}")
        if "maxItems" in schema and len(value) > int(schema["maxItems"]):
            raise WorkspaceIdentityPolicyError(f"SCHEMA_MAX_ITEMS:{label}")
        if isinstance(schema.get("items"), dict):
            for index, item in enumerate(value):
                validate_schema_instance(item, schema["items"], f"{label}[{index}]")
    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise WorkspaceIdentityPolicyError(f"SCHEMA_FIELD_MISSING:{label}.{key}")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extras = sorted(set(value) - set(properties))
            if extras:
                raise WorkspaceIdentityPolicyError(f"SCHEMA_ADDITIONAL_PROPERTIES:{label}:{','.join(extras)}")
        for key, subschema in properties.items():
            if key in value:
                validate_schema_instance(value[key], subschema, f"{label}.{key}")


def validate_json_with_schema(root: Path, value: dict[str, Any], schema_path: str) -> None:
    schema = load_json(root / schema_path)
    validate_schema_instance(value, schema)


def validate_member_model(model: dict[str, Any]) -> None:
    rules = model.get("selection_rules")
    if not isinstance(rules, dict):
        raise WorkspaceIdentityPolicyError("SELECTION_RULES_REQUIRED")
    expected_rules = {
        "binary_exclusion_is_absolute": True,
        "most_specific_semantic_family_wins": True,
        "unregistered_governed_family": "FAIL_CLOSED",
        "generic_engine_changes_required_for_new_family": False,
        "same_priority_and_specificity_collision": "FAIL_CLOSED",
    }
    for key, expected in expected_rules.items():
        if rules.get(key) != expected:
            raise WorkspaceIdentityPolicyError(f"SELECTION_RULE_INVALID:{key}")
    if not isinstance(rules.get("classification_baseline"), str) or not rules["classification_baseline"]:
        raise WorkspaceIdentityPolicyError("CLASSIFICATION_BASELINE_REQUIRED")
    families = model.get("families")
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
        if not isinstance(family["priority"], int) or isinstance(family["priority"], bool):
            raise WorkspaceIdentityPolicyError(f"FAMILY_PRIORITY_INVALID:{family_id}")
        patterns = family["path_pattern_or_member_set"]
        if not isinstance(patterns, list) or not patterns or not all(isinstance(x, str) and x for x in patterns):
            raise WorkspaceIdentityPolicyError(f"FAMILY_PATTERNS_REQUIRED:{family_id}")
        if family["byte_identity_required"] != "YES":
            raise WorkspaceIdentityPolicyError(f"BYTE_IDENTITY_MUST_BE_ENFORCED:{family_id}")
        if family["qualification_required"] != "YES":
            raise WorkspaceIdentityPolicyError(f"QUALIFICATION_MUST_BE_ENFORCED:{family_id}")
        if not isinstance(family["exceptions"], list) or not all(isinstance(x, str) for x in family["exceptions"]):
            raise WorkspaceIdentityPolicyError(f"FAMILY_EXCEPTIONS_INVALID:{family_id}")
        if family["binary_or_text"] == "BINARY" and family["eol_policy"] != "BINARY_PRESERVE":
            raise WorkspaceIdentityPolicyError(f"BINARY_EOL_INVALID:{family_id}")
        if family["binary_or_text"] == "TEXT" and family["eol_policy"] != "LF":
            raise WorkspaceIdentityPolicyError(f"TEXT_EOL_INVALID:{family_id}")
        if family["binary_or_text"] not in {"TEXT", "BINARY"}:
            raise WorkspaceIdentityPolicyError(f"BINARY_TEXT_INVALID:{family_id}")
    missing = REQUIRED_FAMILY_IDS - ids
    if missing:
        raise WorkspaceIdentityPolicyError(f"REQUIRED_FAMILY_MISSING:{','.join(sorted(missing))}")


def validate_classification_baseline(root: Path, model: dict[str, Any], baseline: dict[str, Any]) -> None:
    if baseline.get("predecessor_commit") != model.get("selection_rules", {}).get("classification_change_policy", {}).get("predecessor_commit"):
        raise WorkspaceIdentityPolicyError("CLASSIFICATION_BASELINE_PREDECESSOR_MISMATCH")
    policy = model["selection_rules"]["classification_change_policy"]
    allowed = {item["path"]: item["to_family"] for item in policy.get("authorized_reclassifications", []) if isinstance(item, dict) and "path" in item and "to_family" in item}
    for path, predecessor_family in baseline.get("classifications", {}).items():
        current = selected_family(path, model)
        current_id = current["family_id"] if current else None
        if predecessor_family is None and policy.get("allow_previously_unclassified_to_be_classified") is True:
            continue
        if current_id != predecessor_family and allowed.get(path) != current_id:
            raise WorkspaceIdentityPolicyError(f"UNAUTHORIZED_CLASSIFICATION_CHANGE:{path}:{predecessor_family}->{current_id}")


def parse_gitattributes(text: str) -> list[tuple[str, tuple[str, ...]]]:
    result: list[tuple[str, tuple[str, ...]]] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            raise WorkspaceIdentityPolicyError(f"GITATTRIBUTES_RULE_INVALID:{line}")
        result.append((parts[0], tuple(parts[1:])))
    return result


def validate_gitattributes(text: str) -> list[tuple[str, tuple[str, ...]]]:
    rules = parse_gitattributes(text)
    if any(pattern == "*" and "text" in attrs for pattern, attrs in rules):
        raise WorkspaceIdentityPolicyError("BLIND_TEXT_POLICY_FORBIDDEN")
    lf = {pattern for pattern, attrs in rules if "text" in attrs and "eol=lf" in attrs}
    missing = TEXT_PATTERNS - lf
    if missing:
        raise WorkspaceIdentityPolicyError(f"TEXT_EOL_POLICY_MISSING:{','.join(sorted(missing))}")
    binary = {pattern for pattern, attrs in rules if "-text" in attrs}
    missing_binary = BINARY_PATTERNS - binary
    if missing_binary:
        raise WorkspaceIdentityPolicyError(f"BINARY_EXCLUSION_MISSING:{','.join(sorted(missing_binary))}")
    return rules


def _policy_covers(path: str, rules: list[tuple[str, tuple[str, ...]]]) -> bool:
    return any(path_matches(path, pattern) for pattern, _ in rules)


def tracked_paths(root: Path) -> list[str]:
    raw = bytes(_git(root, "ls-files", "-z", text=False))
    return [item.decode("utf-8") for item in raw.split(b"\0") if item]


def validate_policy_selection_closure(root: Path, model: dict[str, Any], rules: list[tuple[str, tuple[str, ...]]]) -> None:
    for path in tracked_paths(root):
        if _policy_covers(path, rules) and selected_family(path, model) is None:
            raise WorkspaceIdentityPolicyError(f"POLICY_COVERED_MEMBER_UNCLASSIFIED:{path}")


def _attr_value(root: Path, path: str, name: str) -> str:
    output = str(_git(root, "check-attr", name, "--", path)).strip()
    marker = f"{path}: {name}: "
    if not output.startswith(marker):
        raise WorkspaceIdentityPolicyError(f"ATTRIBUTE_OUTPUT_INVALID:{path}:{name}:{output}")
    return output[len(marker):]


def _workspace_eol_line(root: Path, path: str) -> str:
    output = str(_git(root, "ls-files", "--eol", "--", path)).strip()
    if not output:
        raise WorkspaceIdentityPolicyError(f"TRACKED_MEMBER_REQUIRED:{path}")
    return output


def inspect_workspace_member(root: Path, path: str, model: dict[str, Any]) -> dict[str, Any]:
    family = selected_family(path, model)
    if family is None:
        raise WorkspaceIdentityPolicyError(f"UNREGISTERED_GOVERNED_FAMILY:{path}")
    full = root / Path(path)
    if not full.is_file():
        raise WorkspaceIdentityPolicyError(f"MEMBER_MISSING:{path}")
    blob_sha = str(_git(root, "rev-parse", f"HEAD:{path}")).strip()
    workspace_object = str(_git(root, "hash-object", "--no-filters", "--", path)).strip()
    blob_bytes = bytes(_git(root, "cat-file", "blob", blob_sha, text=False))
    workspace_bytes = full.read_bytes()
    result = {
        "path": path, "family_id": family["family_id"], "blob_sha": blob_sha,
        "workspace_object_sha": workspace_object,
        "workspace_sha256": hashlib.sha256(workspace_bytes).hexdigest().upper(),
        "blob_sha256": hashlib.sha256(blob_bytes).hexdigest().upper(),
        "git_ls_files_eol": _workspace_eol_line(root, path),
        "byte_identity": "PASS" if workspace_bytes == blob_bytes and workspace_object == blob_sha else "FAIL",
    }
    if family["binary_or_text"] == "TEXT":
        if _attr_value(root, path, "text") != "set" or _attr_value(root, path, "eol") != "lf":
            raise WorkspaceIdentityPolicyError(f"TEXT_ATTRIBUTE_NOT_EXPLICIT_LF:{path}")
        if "w/lf" not in result["git_ls_files_eol"].split()[:2]:
            raise WorkspaceIdentityPolicyError(f"WORKSPACE_EOL_MISMATCH:{path}:{result['git_ls_files_eol']}")
    elif _attr_value(root, path, "text") != "unset":
        raise WorkspaceIdentityPolicyError(f"BINARY_TEXT_EXCLUSION_MISSING:{path}")
    if result["byte_identity"] != "PASS":
        raise WorkspaceIdentityPolicyError(f"RAW_BYTE_IDENTITY_MISMATCH:{path}")
    return result


def tracked_governed_members(root: Path, model: dict[str, Any]) -> list[str]:
    return [path for path in tracked_paths(root) if selected_family(path, model) is not None]


def inspect_workspace(root: Path, model: dict[str, Any]) -> list[dict[str, Any]]:
    return [inspect_workspace_member(root, path, model) for path in tracked_governed_members(root, model)]


def _allowed(path: str, patterns: list[str]) -> bool:
    return any(path_matches(path, pattern) for pattern in patterns)


def inspect_cleanliness(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    policy = contract["cleanliness_policy"]
    tracked = [x for x in str(_git(root, "diff", "--name-only")).splitlines() if x]
    staged = [x for x in str(_git(root, "diff", "--cached", "--name-only")).splitlines() if x]
    untracked = [x for x in str(_git(root, "ls-files", "--others", "--exclude-standard")).splitlines() if x and not _allowed(x, policy["safe_untracked_patterns"])]
    ignored_all = [x for x in str(_git(root, "ls-files", "--others", "--ignored", "--exclude-standard")).splitlines() if x]
    ignored_relevant = [x for x in ignored_all if not _allowed(x, policy["safe_ignored_patterns"])]
    if tracked:
        raise WorkspaceIdentityPolicyError("WORKTREE_TRACKED_DIRTY:" + ",".join(tracked))
    if staged:
        raise WorkspaceIdentityPolicyError("INDEX_DIRTY:" + ",".join(staged))
    if untracked:
        raise WorkspaceIdentityPolicyError("UNTRACKED_OBJECTS:" + ",".join(untracked))
    if ignored_relevant:
        raise WorkspaceIdentityPolicyError("IGNORED_EXECUTION_RELEVANT_OBJECTS:" + ",".join(ignored_relevant))
    return {"worktree_clean": True, "index_clean": True, "untracked_objects": [], "ignored_execution_relevant_objects": []}


def _normalize_remote(url: str) -> str:
    value = url.strip().replace("\\", "/")
    if value.endswith(".git"):
        value = value[:-4]
    if value.startswith("https://github.com/"):
        return value[len("https://github.com/"):]
    return value


def _identity_sha(path: Path) -> dict[str, str]:
    return {"path": path.as_posix(), "sha256": sha256_file(path)}


def build_physical_evidence(root: Path, model: dict[str, Any], materialization: dict[str, Any], source_repository: str, remote_commit: str) -> dict[str, Any]:
    members = inspect_workspace(root, model)
    clean = inspect_cleanliness(root, materialization)
    config = str(_git(root, "config", "--show-origin", "--get-all", "core.autocrlf")).strip().splitlines()
    return {
        "source_repository": source_repository,
        "remote_commit": remote_commit,
        "local_head": str(_git(root, "rev-parse", "HEAD")).strip(),
        "worktree_path": str(root.resolve()),
        "host_identity": os.environ.get("COMPUTERNAME", ""),
        "runtime_identity": f"Python {sys.version.split()[0]}",
        "member_selection_model_identity": _identity_sha(root / "governance/workspace-identity/ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.json"),
        "gitattributes_identity": _identity_sha(root / ".gitattributes"),
        "git_config_origin_evidence": {"core.autocrlf": config},
        "git_ls_files_eol": {x["path"]: x["git_ls_files_eol"] for x in members},
        "workspace_raw_object_sha": {x["path"]: x["workspace_object_sha"] for x in members},
        "committed_blob_sha": {x["path"]: x["blob_sha"] for x in members},
        "workspace_sha256": {x["path"]: x["workspace_sha256"] for x in members},
        "blob_sha256": {x["path"]: x["blob_sha256"] for x in members},
        **clean,
        "workspace_evidence_source": "RAW_WORKSPACE_BYTES",
        "raw_byte_identity_result": "PASS",
        "materialization_evidence_current": True,
    }


def validate_materialization_evidence(root: Path, evidence: dict[str, Any], contract: dict[str, Any], model: dict[str, Any], materialization: dict[str, Any]) -> None:
    required = contract["materialization_evidence_required_fields"]
    missing = [field for field in required if field not in evidence]
    if missing:
        raise WorkspaceIdentityPolicyError("MATERIALIZATION_EVIDENCE_MISSING:" + ",".join(missing))
    validate_json_with_schema(root, evidence, contract["materialization_evidence_schema"])
    if not COMMIT_RE.fullmatch(evidence["remote_commit"]) or not COMMIT_RE.fullmatch(evidence["local_head"]):
        raise WorkspaceIdentityPolicyError("COMMIT_IDENTITY_INVALID")
    if evidence["remote_commit"] != evidence["local_head"]:
        raise WorkspaceIdentityPolicyError("WRONG_MATERIALIZED_COMMIT")
    if str(_git(root, "rev-parse", "HEAD")).strip().lower() != evidence["local_head"].lower():
        raise WorkspaceIdentityPolicyError("LOCAL_HEAD_PHYSICAL_MISMATCH")
    code, _, _ = _git_optional(root, "cat-file", "-e", f"{evidence['remote_commit']}^{{commit}}")
    if code != 0:
        raise WorkspaceIdentityPolicyError("COMMIT_NOT_PHYSICALLY_RESOLVABLE")
    if Path(evidence["worktree_path"]).resolve() != root.resolve():
        raise WorkspaceIdentityPolicyError("WORKTREE_PATH_PHYSICAL_MISMATCH")
    if evidence["host_identity"].upper() != os.environ.get("COMPUTERNAME", "").upper():
        raise WorkspaceIdentityPolicyError("HOST_IDENTITY_PHYSICAL_MISMATCH")
    if evidence["runtime_identity"] != f"Python {sys.version.split()[0]}":
        raise WorkspaceIdentityPolicyError("RUNTIME_IDENTITY_PHYSICAL_MISMATCH")
    origin = _normalize_remote(str(_git(root, "remote", "get-url", "origin")))
    if _normalize_remote(evidence["source_repository"]) != origin:
        raise WorkspaceIdentityPolicyError("SOURCE_REPOSITORY_PHYSICAL_MISMATCH")
    physical = build_physical_evidence(root, model, materialization, evidence["source_repository"], evidence["remote_commit"])
    for field in required:
        if evidence[field] != physical[field]:
            raise WorkspaceIdentityPolicyError(f"MATERIALIZATION_EVIDENCE_PHYSICAL_MISMATCH:{field}")


def compute_package_sha256(members: list[dict[str, Any]]) -> str:
    payload = "".join(f"{m['path']}\0{m['size_bytes']}\0{m['sha256'].upper()}\n" for m in sorted(members, key=lambda x: x["path"]))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest().upper()


def validate_package_manifest(root: Path, manifest: dict[str, Any]) -> None:
    required = {
        "schema_id", "package_id", "package_version", "source_repository", "source_commit", "predecessor_head",
        "members", "package_sha256", "dependency_graph", "runtime_requirements", "host_requirements", "entrypoints",
        "evidence_pointers", "rollback_reference", "upstream_dependencies", "downstream_dependencies",
    }
    missing = sorted(required - set(manifest))
    if missing:
        raise WorkspaceIdentityPolicyError("PACKAGE_MANIFEST_FIELDS_MISSING:" + ",".join(missing))
    if manifest["schema_id"] != "ECTOS_WORKSPACE_BYTE_IDENTITY_PACKAGE_MANIFEST_V02":
        raise WorkspaceIdentityPolicyError("PACKAGE_MANIFEST_SCHEMA_INVALID")
    if not COMMIT_RE.fullmatch(manifest["source_commit"]):
        raise WorkspaceIdentityPolicyError("PACKAGE_SOURCE_COMMIT_INVALID")
    seen: set[str] = set()
    for member in manifest["members"]:
        path = member.get("path")
        if not path or path in seen:
            raise WorkspaceIdentityPolicyError("PACKAGE_MEMBER_DUPLICATE_OR_EMPTY")
        seen.add(path)
        full = root / path
        if not full.is_file():
            raise WorkspaceIdentityPolicyError(f"PACKAGE_MEMBER_MISSING:{path}")
        if full.stat().st_size != member.get("size_bytes") or sha256_file(full) != str(member.get("sha256", "")).upper():
            raise WorkspaceIdentityPolicyError(f"PACKAGE_MEMBER_IDENTITY_MISMATCH:{path}")
        code, blob, _ = _git_optional(root, "show", f"{manifest['source_commit']}:{path}")
        if code != 0:
            raise WorkspaceIdentityPolicyError(f"PACKAGE_MEMBER_NOT_IN_SOURCE_COMMIT:{path}")
        blob_bytes = bytes(_git(root, "show", f"{manifest['source_commit']}:{path}", text=False))
        if hashlib.sha256(blob_bytes).hexdigest().upper() != member["sha256"].upper():
            raise WorkspaceIdentityPolicyError(f"PACKAGE_SOURCE_COMMIT_MEMBER_MISMATCH:{path}")
    if compute_package_sha256(manifest["members"]) != manifest["package_sha256"].upper():
        raise WorkspaceIdentityPolicyError("PACKAGE_SHA256_MISMATCH")


def validate_package_graph(root: Path, manifest: dict[str, Any], graph_path: Path) -> None:
    graph = load_graph(graph_path)
    result = validate_graph(graph)
    if result["status"] != "PASS":
        raise WorkspaceIdentityPolicyError("DEPENDENCY_GRAPH_INVALID:" + ";".join(result["errors"]))
    package = graph["package"]
    if package.get("package_id") != manifest["package_id"] or package.get("version") != manifest["package_version"]:
        raise WorkspaceIdentityPolicyError("DEPENDENCY_GRAPH_PACKAGE_IDENTITY_MISMATCH")
    if package.get("package_sha256") != manifest["package_sha256"] or package.get("source_commit") != manifest["source_commit"]:
        raise WorkspaceIdentityPolicyError("DEPENDENCY_GRAPH_SOURCE_IDENTITY_MISMATCH")
    locators = {node.get("locator") for node in graph.get("nodes", []) if isinstance(node, dict)}
    missing = [member["path"] for member in manifest["members"] if member["path"] not in locators]
    if missing:
        raise WorkspaceIdentityPolicyError("DEPENDENCY_GRAPH_MEMBER_SET_INCOMPLETE:" + ",".join(missing))


def validate_all(root: Path, evidence_path: Path, manifest_path: Path, graph_path: Path) -> dict[str, Any]:
    base = root / "governance/workspace-identity"
    model = load_json(base / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.json")
    generic = load_json(base / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V02.json")
    materialization = load_json(base / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V02.json")
    baseline = load_json(base / "ECTOS_WORKSPACE_IDENTITY_CLASSIFICATION_BASELINE_V01.json")
    validate_json_with_schema(root, generic, generic["schema_path"])
    validate_json_with_schema(root, materialization, materialization["schema_path"])
    validate_json_with_schema(root, model, "schemas/workspace_identity/ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.schema.json")
    validate_member_model(model)
    validate_classification_baseline(root, model, baseline)
    rules = validate_gitattributes((root / ".gitattributes").read_text(encoding="utf-8"))
    validate_policy_selection_closure(root, model, rules)
    evidence = load_json(evidence_path)
    validate_materialization_evidence(root, evidence, generic, model, materialization)
    manifest = load_json(manifest_path)
    validate_package_manifest(root, manifest)
    validate_package_graph(root, manifest, graph_path)
    return {"result": "PASS", "member_count": len(inspect_workspace(root, model)), "package_sha256": manifest["package_sha256"]}


def main() -> int:
    parser = argparse.ArgumentParser(description="ECTOS governed workspace identity validator V02")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--dependency-graph", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        result = validate_all(root, args.evidence.resolve(), args.manifest.resolve(), args.dependency_graph.resolve())
    except (OSError, json.JSONDecodeError, WorkspaceIdentityPolicyError) as exc:
        print(f"FAIL:{exc}")
        return 40
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
