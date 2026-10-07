from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from engineering.mission_registry import (
    create_mission,
    get_mission,
    list_missions,
    resume_context,
    transition_mission,
    validate_mission,
)

SOURCE_COMMIT = "57ffec2cdda7172b9db967b852ff588215108f67"
ARTIFACT_COMMIT = "9fa93d1c0836f3dc257bec659a228508ac07b029"
ARTIFACT_SHA = "1B4D600C4C6539EE74E43B01B64A08CDC4577D9507035DC83B353F499B027A57"


def mission(state: str = "QUEUED", with_pointer: bool = True) -> dict:
    pointers = []
    if with_pointer:
        pointers = [
            {
                "pointer_id": "ECTOS_ARTIFACT_POINTER_METHODOLOGY_ARTIFACT_PERSISTENCE_MVP_V01",
                "repository": "yannicklabuthie-code/ECTOS-Engineering",
                "commit": ARTIFACT_COMMIT,
                "path": "ectos/artifacts/METHODOLOGY_ARTIFACT_PERSISTENCE_MVP/V01/ARTIFACT.txt",
                "sha256": ARTIFACT_SHA,
            }
        ]
    return {
        "schema_id": "ECTOS_MISSION_REGISTRY_SCHEMA_V02",
        "mission_id": "ECTOS-METHODOLOGY-03.2-DEMO",
        "project": "ECTOS",
        "project_container": "ECTOS-POC",
        "mission_type": "METHODOLOGY_MVP",
        "target_node": "METHODOLOGY_MVP_MISSION_REGISTRY",
        "objective": "Prove durable mission create/read/update/resume behavior.",
        "producer_actor": "ECTOS_MAIN_AUTHORITY",
        "qualifier_actor": None,
        "admission_authority": None,
        "main_authority": "ECTOS_MAIN_AUTHORITY",
        "superior_authority": "PROJECT_OWNER_YANICK",
        "state": state,
        "authority_state": "MAIN_AUTHORIZED",
        "currentness_state": "CURRENT",
        "blocker_state": "CLEAR",
        "blocker_reason": "",
        "circuit_breaker_state": "NOT_TRIGGERED",
        "systemic_review_required": False,
        "systemic_review_state": "NOT_REQUIRED",
        "known_failure_count": 0,
        "related_failure_count": 0,
        "repeated_root_failure": False,
        "known_defect_set_state": "EMPTY",
        "known_defect_ids": [],
        "unreachable_scope": [],
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "source_commit": SOURCE_COMMIT,
        "input_pointers": pointers,
        "output_pointers": [],
        "return_pointer": None,
        "result_state": "NOT_YET_RETURNED",
        "evidence_pointers": [],
        "next_authority": "ECTOS_MAIN_AUTHORITY",
        "next_target": "ECTOS-METHODOLOGY-03.2-DEMO",
        "next_action_class": "IMPLEMENTATION",
        "next_execution_authority_eligible": True,
        "created_at": "2026-10-08T00:00:00Z",
        "updated_at": "2026-10-08T00:00:00Z",
        "created_by": "ECTOS_MAIN_AUTHORITY",
        "last_transition_authority": "ECTOS_MAIN_AUTHORITY",
        "last_transition_evidence": "MISSION_CREATED_FOR_TEST",
    }


class MissionRegistryTests(unittest.TestCase):
    def test_validate_create_read_and_list(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission()
            self.assertEqual(validate_mission(payload)["status"], "PASS")
            created = create_mission(root, payload)
            self.assertEqual(created["status"], "PASS")
            loaded = get_mission(root, payload["mission_id"])
            self.assertEqual(loaded["mission_id"], payload["mission_id"])
            rows = list_missions(root)
            self.assertEqual(rows[0]["state"], "QUEUED")

    def test_full_minimum_transition_chain(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission()
            create_mission(root, payload)
            chain = [
                "AUTHORIZED",
                "RUNNING",
                "WAITING",
                "RUNNING",
                "RETURN_RECEIVED",
                "PENDING_MAIN_REVIEW",
                "MAIN_ADJUDICATED",
                "CLOSED",
            ]
            for state in chain:
                transition_mission(root, payload["mission_id"], state, "ECTOS_MAIN_AUTHORITY", f"EVIDENCE_{state}")
            loaded = get_mission(root, payload["mission_id"])
            self.assertEqual(loaded["state"], "CLOSED")
            self.assertFalse(loaded["next_execution_authority_eligible"])

    def test_block_requires_reason_and_can_resume(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission()
            create_mission(root, payload)
            transition_mission(root, payload["mission_id"], "BLOCKED", "ECTOS_MAIN_AUTHORITY", "BLOCK_EVIDENCE", "DEPENDENCY_NOT_PROVEN")
            blocked = get_mission(root, payload["mission_id"])
            self.assertEqual(blocked["blocker_state"], "BLOCKED")
            self.assertFalse(blocked["next_execution_authority_eligible"])
            transition_mission(root, payload["mission_id"], "AUTHORIZED", "ECTOS_MAIN_AUTHORITY", "REAUTH_EVIDENCE")
            unblocked = get_mission(root, payload["mission_id"])
            self.assertEqual(unblocked["blocker_state"], "CLEAR")

    def test_invalid_transition_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission()
            create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "TRANSITION_NOT_ALLOWED"):
                transition_mission(root, payload["mission_id"], "CLOSED", "ECTOS_MAIN_AUTHORITY", "BAD_SKIP")

    def test_resume_uses_registry_and_durable_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission(state="RUNNING", with_pointer=True)
            create_mission(root, payload)
            resumed = resume_context(root, payload["mission_id"])
            self.assertEqual(resumed["source_commit"], SOURCE_COMMIT)
            self.assertEqual(resumed["input_pointers"][0]["sha256"], ARTIFACT_SHA)
            self.assertNotIn("chat_history", resumed)

    def test_resume_without_pointer_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission(state="RUNNING", with_pointer=False)
            create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_RESUME_REQUIRES_DURABLE_POINTER"):
                resume_context(root, payload["mission_id"])

    def test_terminal_mission_cannot_resume(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission(state="CLOSED", with_pointer=True)
            payload["next_execution_authority_eligible"] = False
            create_mission(root, payload)
            with self.assertRaisesRegex(ValueError, "MISSION_NOT_RESUMABLE:CLOSED"):
                resume_context(root, payload["mission_id"])

    def test_index_is_physical_json(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            payload = mission()
            create_mission(root, payload)
            index = json.loads((root / "index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["mission_ids"], [payload["mission_id"]])


if __name__ == "__main__":
    unittest.main()
