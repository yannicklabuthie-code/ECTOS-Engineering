from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA_ID = "ECTOS_MISSION_REGISTRY_SCHEMA_V02"
PREDECESSOR_SCHEMA_ID = "ECTOS_MISSION_REGISTRY_SCHEMA_V01"
MISSION_ID_RE = re.compile(r"^[A-Z0-9][A-Z0-9._-]{2,127}$")
SHA256_RE = re.compile(r"^[A-Fa-f0-9]{64}$")
COMMIT_RE = re.compile(r"^[A-Fa-f0-9]{40}$")

ALLOWED_STATES = {
    "DRAFT",
    "QUEUED",
    "AUTHORIZED",
    "RUNNING",
    "WAITING",
    "RETURN_RECEIVED",
    "PENDING_MAIN_REVIEW",
    "MAIN_ADJUDICATED",
    "CLOSED",
    "BLOCKED",
    "FAILED_SYSTEMIC",
    "CANCELED",
}

TERMINAL_STATES = {"CLOSED", "CANCELED"}

ALLOWED_TRANSITIONS = {
    "DRAFT": {"QUEUED", "CANCELED"},
    "QUEUED": {"AUTHORIZED", "BLOCKED", "CANCELED"},
    "AUTHORIZED": {"RUNNING", "BLOCKED", "CANCELED"},
    "RUNNING": {"WAITING", "RETURN_RECEIVED", "BLOCKED", "FAILED_SYSTEMIC", "CANCELED"},
    "WAITING": {"RUNNING", "RETURN_RECEIVED", "BLOCKED", "CANCELED"},
    "RETURN_RECEIVED": {"PENDING_MAIN_REVIEW", "BLOCKED"},
    "PENDING_MAIN_REVIEW": {"MAIN_ADJUDICATED", "BLOCKED"},
    "MAIN_ADJUDICATED": {"CLOSED", "BLOCKED"},
    "BLOCKED": {"AUTHORIZED", "RUNNING", "WAITING", "CANCELED"},
    "FAILED_SYSTEMIC": {"MAIN_ADJUDICATED", "CANCELED"},
    "CLOSED": set(),
    "CANCELED": set(),
}

ALLOWED_CURRENTNESS = {"CURRENT", "HISTORICAL", "SUPERSEDED", "PARTIAL", "NOT_PROVEN"}
ALLOWED_BOOLEAN = {True, False}

REQUIRED_FIELDS = (
    "schema_id",
    "mission_id",
    "project",
    "project_container",
    "mission_type",
    "target_node",
    "objective",
    "producer_actor",
    "qualifier_actor",
    "admission_authority",
    "main_authority",
    "superior_authority",
    "state",
    "authority_state",
    "currentness_state",
    "blocker_state",
    "blocker_reason",
    "circuit_breaker_state",
    "systemic_review_required",
    "systemic_review_state",
    "known_failure_count",
    "related_failure_count",
    "repeated_root_failure",
    "known_defect_set_state",
    "known_defect_ids",
    "unreachable_scope",
    "source_repository",
    "source_commit",
    "input_pointers",
    "output_pointers",
    "return_pointer",
    "result_state",
    "evidence_pointers",
    "next_authority",
    "next_target",
    "next_action_class",
    "next_execution_authority_eligible",
    "created_at",
    "updated_at",
    "created_by",
    "last_transition_authority",
    "last_transition_evidence",
)

POINTER_FIELDS = ("pointer_id", "repository", "commit", "path", "sha256")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def canonical_json(data: Any) -> str:
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def atomic_write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(canonical_json(data))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def registry_paths(root: Path) -> tuple[Path, Path]:
    return root / "missions", root / "index.json"


def mission_path(root: Path, mission_id: str) -> Path:
    if not MISSION_ID_RE.fullmatch(mission_id):
        raise ValueError("MISSION_ID_INVALID")
    missions_dir, _ = registry_paths(root)
    return missions_dir / f"{mission_id}.json"


def validate_pointer(pointer: Any, label: str) -> list[str]:
    errors: list[str] = []
    if pointer is None:
        return errors
    if not isinstance(pointer, dict):
        return [f"{label}_NOT_OBJECT"]
    for field in POINTER_FIELDS:
        value = pointer.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{label}_FIELD_MISSING:{field}")
    commit = pointer.get("commit")
    if isinstance(commit, str) and commit and not COMMIT_RE.fullmatch(commit):
        errors.append(f"{label}_COMMIT_INVALID")
    sha = pointer.get("sha256")
    if isinstance(sha, str) and sha and not SHA256_RE.fullmatch(sha):
        errors.append(f"{label}_SHA256_INVALID")
    return errors


def validate_mission(mission: Any) -> dict[str, Any]:
    errors: list[str] = []
    if not isinstance(mission, dict):
        return {"schema_id": "ECTOS_MISSION_REGISTRY_VALIDATION_RESULT_V01", "status": "FAIL", "error_count": 1, "errors": ["MISSION_NOT_OBJECT"]}

    for field in REQUIRED_FIELDS:
        if field not in mission:
            errors.append(f"FIELD_MISSING:{field}")

    if mission.get("schema_id") != SCHEMA_ID:
        errors.append("SCHEMA_ID_INVALID")

    mission_id = mission.get("mission_id")
    if not isinstance(mission_id, str) or not MISSION_ID_RE.fullmatch(mission_id):
        errors.append("MISSION_ID_INVALID")

    for field in ("project", "project_container", "mission_type", "target_node", "objective", "main_authority", "superior_authority", "source_repository", "created_by"):
        value = mission.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"FIELD_EMPTY:{field}")

    state = mission.get("state")
    if state not in ALLOWED_STATES:
        errors.append(f"STATE_INVALID:{state}")

    currentness = mission.get("currentness_state")
    if currentness not in ALLOWED_CURRENTNESS:
        errors.append(f"CURRENTNESS_INVALID:{currentness}")

    source_commit = mission.get("source_commit")
    if not isinstance(source_commit, str) or not COMMIT_RE.fullmatch(source_commit):
        errors.append("SOURCE_COMMIT_INVALID")

    for field in ("systemic_review_required", "repeated_root_failure", "next_execution_authority_eligible"):
        if mission.get(field) not in ALLOWED_BOOLEAN:
            errors.append(f"BOOLEAN_INVALID:{field}")

    for field in ("known_failure_count", "related_failure_count"):
        value = mission.get(field)
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            errors.append(f"COUNTER_INVALID:{field}")

    for field in ("known_defect_ids", "unreachable_scope", "input_pointers", "output_pointers", "evidence_pointers"):
        if not isinstance(mission.get(field), list):
            errors.append(f"LIST_INVALID:{field}")

    for field in ("input_pointers", "output_pointers", "evidence_pointers"):
        values = mission.get(field)
        if isinstance(values, list):
            for index, pointer in enumerate(values):
                errors.extend(validate_pointer(pointer, f"{field}[{index}]"))

    errors.extend(validate_pointer(mission.get("return_pointer"), "return_pointer"))

    if state == "BLOCKED":
        if mission.get("blocker_state") != "BLOCKED":
            errors.append("BLOCKED_STATE_REQUIRES_BLOCKER_STATE_BLOCKED")
        if not isinstance(mission.get("blocker_reason"), str) or not mission.get("blocker_reason", "").strip():
            errors.append("BLOCKED_STATE_REQUIRES_BLOCKER_REASON")

    if state in TERMINAL_STATES and mission.get("next_execution_authority_eligible") is True:
        errors.append("TERMINAL_STATE_CANNOT_BE_EXECUTION_ELIGIBLE")

    for field in ("created_at", "updated_at"):
        value = mission.get(field)
        if not isinstance(value, str) or not value.endswith("Z"):
            errors.append(f"TIMESTAMP_INVALID:{field}")

    return {
        "schema_id": "ECTOS_MISSION_REGISTRY_VALIDATION_RESULT_V01",
        "mission_id": mission_id,
        "status": "PASS" if not errors else "FAIL",
        "error_count": len(errors),
        "errors": errors,
    }


def ensure_valid(mission: dict[str, Any]) -> None:
    result = validate_mission(mission)
    if result["status"] != "PASS":
        raise ValueError("MISSION_VALIDATION_FAILED:" + ";".join(result["errors"]))


def init_registry(root: Path) -> dict[str, Any]:
    missions_dir, index_path = registry_paths(root)
    missions_dir.mkdir(parents=True, exist_ok=True)
    if not index_path.exists():
        atomic_write_json(index_path, {"schema_id": "ECTOS_MISSION_REGISTRY_INDEX_V01", "mission_ids": []})
    return {"status": "PASS", "root": str(root), "index": str(index_path)}


def read_index(root: Path) -> dict[str, Any]:
    _, index_path = registry_paths(root)
    if not index_path.exists():
        init_registry(root)
    data = load_json(index_path)
    if data.get("schema_id") != "ECTOS_MISSION_REGISTRY_INDEX_V01" or not isinstance(data.get("mission_ids"), list):
        raise ValueError("REGISTRY_INDEX_INVALID")
    return data


def write_index(root: Path, mission_ids: list[str]) -> None:
    _, index_path = registry_paths(root)
    atomic_write_json(index_path, {"schema_id": "ECTOS_MISSION_REGISTRY_INDEX_V01", "mission_ids": sorted(set(mission_ids))})


def create_mission(root: Path, mission: dict[str, Any]) -> dict[str, Any]:
    init_registry(root)
    ensure_valid(mission)
    path = mission_path(root, mission["mission_id"])
    if path.exists():
        raise FileExistsError("MISSION_ALREADY_EXISTS")
    atomic_write_json(path, mission)
    index = read_index(root)
    write_index(root, list(index["mission_ids"]) + [mission["mission_id"]])
    return {"status": "PASS", "mission_id": mission["mission_id"], "path": str(path)}


def get_mission(root: Path, mission_id: str) -> dict[str, Any]:
    path = mission_path(root, mission_id)
    if not path.exists():
        raise FileNotFoundError("MISSION_NOT_FOUND")
    mission = load_json(path)
    ensure_valid(mission)
    return mission


def transition_mission(root: Path, mission_id: str, to_state: str, authority: str, evidence: str, blocker_reason: str | None = None) -> dict[str, Any]:
    mission = get_mission(root, mission_id)
    from_state = mission["state"]
    if to_state not in ALLOWED_STATES:
        raise ValueError(f"TARGET_STATE_INVALID:{to_state}")
    if to_state not in ALLOWED_TRANSITIONS[from_state]:
        raise ValueError(f"TRANSITION_NOT_ALLOWED:{from_state}->{to_state}")
    if not authority.strip():
        raise ValueError("TRANSITION_AUTHORITY_REQUIRED")
    if not evidence.strip():
        raise ValueError("TRANSITION_EVIDENCE_REQUIRED")

    mission["state"] = to_state
    mission["updated_at"] = utc_now()
    mission["last_transition_authority"] = authority
    mission["last_transition_evidence"] = evidence

    if to_state == "BLOCKED":
        if not blocker_reason or not blocker_reason.strip():
            raise ValueError("BLOCKER_REASON_REQUIRED")
        mission["blocker_state"] = "BLOCKED"
        mission["blocker_reason"] = blocker_reason.strip()
        mission["next_execution_authority_eligible"] = False
    elif from_state == "BLOCKED":
        mission["blocker_state"] = "CLEAR"
        mission["blocker_reason"] = ""

    if to_state in TERMINAL_STATES:
        mission["next_execution_authority_eligible"] = False

    ensure_valid(mission)
    atomic_write_json(mission_path(root, mission_id), mission)
    return {"status": "PASS", "mission_id": mission_id, "from": from_state, "to": to_state}


def list_missions(root: Path) -> list[dict[str, Any]]:
    index = read_index(root)
    result: list[dict[str, Any]] = []
    for mission_id in index["mission_ids"]:
        mission = get_mission(root, mission_id)
        result.append({"mission_id": mission_id, "state": mission["state"], "target_node": mission["target_node"], "updated_at": mission["updated_at"]})
    return result


def resume_context(root: Path, mission_id: str) -> dict[str, Any]:
    mission = get_mission(root, mission_id)
    if mission["state"] in TERMINAL_STATES:
        raise ValueError(f"MISSION_NOT_RESUMABLE:{mission['state']}")

    pointer_sets = mission["input_pointers"] + mission["output_pointers"] + mission["evidence_pointers"]
    if mission.get("return_pointer"):
        pointer_sets.append(mission["return_pointer"])

    if not pointer_sets:
        raise ValueError("MISSION_RESUME_REQUIRES_DURABLE_POINTER")

    for index, pointer in enumerate(pointer_sets):
        errors = validate_pointer(pointer, f"resume_pointer[{index}]")
        if errors:
            raise ValueError("MISSION_RESUME_POINTER_INVALID:" + ";".join(errors))

    return {
        "schema_id": "ECTOS_MISSION_RESUME_CONTEXT_V01",
        "mission_id": mission["mission_id"],
        "state": mission["state"],
        "target_node": mission["target_node"],
        "objective": mission["objective"],
        "source_repository": mission["source_repository"],
        "source_commit": mission["source_commit"],
        "input_pointers": mission["input_pointers"],
        "output_pointers": mission["output_pointers"],
        "evidence_pointers": mission["evidence_pointers"],
        "return_pointer": mission["return_pointer"],
        "blocker_state": mission["blocker_state"],
        "blocker_reason": mission["blocker_reason"],
        "circuit_breaker_state": mission["circuit_breaker_state"],
        "next_authority": mission["next_authority"],
        "next_target": mission["next_target"],
        "next_action_class": mission["next_action_class"],
        "next_execution_authority_eligible": mission["next_execution_authority_eligible"],
        "last_transition_authority": mission["last_transition_authority"],
        "last_transition_evidence": mission["last_transition_evidence"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="ECTOS Mission Registry MVP")
    parser.add_argument("--root", default="ectos/mission-registry/runtime", help="Registry root directory")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init")

    create = sub.add_parser("create")
    create.add_argument("mission_file")

    get = sub.add_parser("get")
    get.add_argument("mission_id")

    validate = sub.add_parser("validate")
    validate.add_argument("mission_file")

    transition = sub.add_parser("transition")
    transition.add_argument("mission_id")
    transition.add_argument("--to", required=True)
    transition.add_argument("--authority", required=True)
    transition.add_argument("--evidence", required=True)
    transition.add_argument("--blocker-reason")

    sub.add_parser("list")

    resume = sub.add_parser("resume")
    resume.add_argument("mission_id")

    args = parser.parse_args()
    root = Path(args.root)

    try:
        if args.command == "init":
            result = init_registry(root)
        elif args.command == "create":
            result = create_mission(root, load_json(Path(args.mission_file)))
        elif args.command == "get":
            result = get_mission(root, args.mission_id)
        elif args.command == "validate":
            result = validate_mission(load_json(Path(args.mission_file)))
        elif args.command == "transition":
            result = transition_mission(root, args.mission_id, args.to, args.authority, args.evidence, args.blocker_reason)
        elif args.command == "list":
            result = {"schema_id": "ECTOS_MISSION_REGISTRY_LIST_V01", "missions": list_missions(root)}
        else:
            result = resume_context(root, args.mission_id)
    except (ValueError, FileNotFoundError, FileExistsError, json.JSONDecodeError) as exc:
        print(canonical_json({"status": "FAIL", "error": str(exc)}), end="")
        return 40

    print(canonical_json(result), end="")
    if isinstance(result, dict) and result.get("status") == "FAIL":
        return 40
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
