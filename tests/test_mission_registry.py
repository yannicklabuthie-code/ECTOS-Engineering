from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from engineering.mission_registry import (
    create_mission,
    get_mission,
    resume_context,
    transition_mission,
    validate_mission,
)
from validators.workspace_identity.validate_workspace_identity import build_physical_evidence, load_json

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "governance" / "workspace-identity"
MODEL = load_json(BASE / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.json")
GENERIC = load_json(BASE / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V02.json")
MATERIALIZATION = load_json(BASE / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V02.json")
SOURCE_REPOSITORY = "yannicklabuthie-code/ECTOS-Engineering"


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {result.stderr}")
    return result.stdout.strip()


def make_evidence_repo(root: Path, evidence: dict) -> tuple[Path, dict]:
    repo = root / "evidence-repo"; repo.mkdir()
    git(repo, "init"); git(repo, "config", "user.email", "ectos@example.invalid"); git(repo, "config", "user.name", "ECTOS Test")
    path = repo / "materialization-evidence.json"
    path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    git(repo, "add", "."); git(repo, "commit", "-m", "evidence")
    commit = git(repo, "rev-parse", "HEAD")
    data = path.read_bytes()
    pointer = {
        "pointer_id": "ECTOS_MATERIALIZATION_EVIDENCE_TEST",
        "repository": "local/evidence-repo",
        "commit": commit,
        "path": "materialization-evidence.json",
        "sha256": hashlib.sha256(data).hexdigest().upper(),
    }
    return repo, pointer


def mission(pointer: dict | None, *, state: str = "RUNNING", currentness: str = "CURRENT", eligible: bool = True, source_commit: str | None = None) -> dict:
    return {
        "schema_id": "ECTOS_MISSION_REGISTRY_SCHEMA_V03",
        "mission_id": "ECTOS-METHODOLOGY-03.2-V03-TEST",
        "project": "ECTOS",
        "project_container": "ECTOS-POC",
        "mission_type": "METHODOLOGY_MVP",
        "target_node": "METHODOLOGY_MVP_MISSION_REGISTRY",
        "objective": "Recover exact governed context without chat state.",
        "producer_actor": "SPECIALIST_ENGINEERING_PRODUCER",
        "qualifier_actor": None,
        "admission_authority": None,
        "main_authority": "ECTOS_MAIN_AUTHORITY",
        "superior_authority": "PROJECT_OWNER_YANICK",
        "state": state,
        "authority_state": "MAIN_AUTHORIZED",
        "currentness_state": currentness,
        "blocker_state": "BLOCKED" if state == "BLOCKED" else "CLEAR",
        "blocker_reason": "TEST_BLOCK" if state == "BLOCKED" else "",
        "circuit_breaker_state": "NOT_TRIGGERED",
        "systemic_review_required": False,
        "systemic_review_state": "NOT_REQUIRED",
        "known_failure_count": 0,
        "related_failure_count": 0,
        "repeated_root_failure": False,
        "known_defect_set_state": "EMPTY",
        "known_defect_ids": [],
        "unreachable_scope": [],
        "source_repository": SOURCE_REPOSITORY,
        "source_commit": source_commit or git(ROOT, "rev-parse", "HEAD"),
        "input_pointers": [],
        "output_pointers": [],
        "return_pointer": None,
        "result_state": "NOT_YET_RETURNED",
        "evidence_pointers": [],
        "materialization_evidence_pointer": pointer,
        "next_authority": "ECTOS_MAIN_AUTHORITY",
        "next_target": "ECTOS-METHODOLOGY-03.2",
        "next_action_class": "CONTINUE",
        "next_execution_authority_eligible": eligible,
        "created_at": "2026-10-08T00:00:00Z",
        "updated_at": "2026-10-08T00:00:00Z",
        "created_by": "ECTOS_MAIN_AUTHORITY",
        "last_transition_authority": "ECTOS_MAIN_AUTHORITY",
        "last_transition_evidence": "TEST",
    }


class MissionRegistryV03Tests(unittest.TestCase):
    def evidence_fixture(self, temp: Path) -> tuple[dict, Path, dict]:
        head = git(ROOT, "rev-parse", "HEAD")
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, SOURCE_REPOSITORY, head)
        evidence_repo, pointer = make_evidence_repo(temp, evidence)
        return evidence, evidence_repo, pointer

    def test_01_v03_mission_validates_and_persists(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, _, pointer = self.evidence_fixture(temp); payload = mission(pointer)
            self.assertEqual(validate_mission(payload)["status"], "PASS")
            root = temp / "registry"; create_mission(root, payload); self.assertEqual(get_mission(root, payload["mission_id"])["schema_id"], "ECTOS_MISSION_REGISTRY_SCHEMA_V03")

    def test_02_transition_behavior_is_preserved(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, _, pointer = self.evidence_fixture(temp); payload = mission(pointer, state="QUEUED")
            root = temp / "registry"; create_mission(root, payload)
            transition_mission(root, payload["mission_id"], "AUTHORIZED", "ECTOS_MAIN_AUTHORITY", "AUTH")
            transition_mission(root, payload["mission_id"], "RUNNING", "ECTOS_MAIN_AUTHORITY", "RUN")
            self.assertEqual(get_mission(root, payload["mission_id"])["state"], "RUNNING")

    def test_03_resume_requires_materialization_pointer(self):
        payload = mission(None)
        self.assertEqual(validate_mission(payload)["status"], "FAIL")

    def test_04_resume_passes_with_physical_current_evidence(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer)
            root = temp / "registry"; create_mission(root, payload)
            result = resume_context(root, payload["mission_id"], ROOT, evidence_repo)
            self.assertEqual(result["source_commit"], git(ROOT, "rev-parse", "HEAD"))

    def test_05_stale_currentness_fails_resume(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer, currentness="NOT_PROVEN")
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_CURRENTNESS_NOT_CURRENT"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_06_blocked_state_fails_resume(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer, state="BLOCKED", eligible=False)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_NOT_RESUMABLE:BLOCKED"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_07_failed_systemic_state_fails_resume(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer, state="FAILED_SYSTEMIC", eligible=False)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_NOT_RESUMABLE:FAILED_SYSTEMIC"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_08_execution_ineligible_fails_resume(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer, eligible=False)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_EXECUTION_AUTHORITY_NOT_ELIGIBLE"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_09_stale_pointer_commit_fails(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); pointer = dict(pointer); pointer["commit"] = "f" * 40; payload = mission(pointer)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaises(ValueError): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_10_pointer_sha_mismatch_fails(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); pointer = dict(pointer); pointer["sha256"] = "0" * 64; payload = mission(pointer)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "POINTER_SHA256_MISMATCH"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_11_evidence_source_commit_mismatch_fails(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer, source_commit="b" * 40)
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_SOURCE_MATERIALIZATION_BINDING_MISMATCH"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)

    def test_12_triggered_circuit_breaker_fails(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td); _, evidence_repo, pointer = self.evidence_fixture(temp); payload = mission(pointer); payload["circuit_breaker_state"] = "TRIGGERED"
            root = temp / "registry"; create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_CIRCUIT_BREAKER_TRIGGERED"): resume_context(root, payload["mission_id"], ROOT, evidence_repo)


if __name__ == "__main__":
    unittest.main()
