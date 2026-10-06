import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from systemic_closure import bypass_scan, final_readiness
from uac_core import UACDenied, evaluate_admission


def base_request(package_id: str):
    return {
        "project": "METAMORPHOSE",
        "mission_id": "HISTORICAL-REPLAY",
        "failure_family_id": "METAMORPHOSE_GOOGLE_FILE_SEARCH_PROVIDER_CONTRACT",
        "actor": "ECTOS_REPOSITORY_AGENT",
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "qualifier": "ECTOS_INDEPENDENT_QUALIFIER",
        "systemic_assurance_id": "ECTOS_SYSTEMIC_ASSURANCE",
        "admission_authority": "ECTOS_UAC_CONTROL_PLANE_V01",
        "package_id": package_id,
        "package_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
        "target": "ECTOS_PACKAGE_HANDOFF",
        "action": "ISSUE_HANDOFF",
        "qualification_result": "PASS",
        "systemic_review_state": "PASS",
        "consolidated_defect_set_state": "CLOSED",
        "governance_currentness": "PROVEN_CURRENT",
        "rule_source_currentness": "PROVEN_CURRENT",
        "negative_controls": "PASS",
        "circuit_breaker_state": "TRIGGERED"
    }


class TestFinalSystemicClosure(unittest.TestCase):
    def test_repository_bypass_scan_is_zero(self):
        result = bypass_scan()
        self.assertEqual(result["decision"], "PASS", result)
        self.assertEqual(result["bypass_path_count"], 0, result)

    def test_final_readiness_passes(self):
        result = final_readiness()
        self.assertEqual(result["decision"], "PASS", result)
        self.assertEqual(result["metamorphose_historical_replay_fixture"], "PASS")

    def test_historical_v02_is_blocked_by_failure_family_breaker(self):
        with self.assertRaises(UACDenied) as ctx:
            evaluate_admission(base_request("METAMORPHOSE_CANONICAL_STORE_MIGRATION_EXEC_V02.zip"))
        self.assertIn("CIRCUIT_BREAKER_STATE_NOT_ACCEPTED", str(ctx.exception))

    def test_renamed_v03_is_still_blocked_by_same_failure_family(self):
        with self.assertRaises(UACDenied) as ctx:
            evaluate_admission(base_request("METAMORPHOSE_CANONICAL_STORE_MIGRATION_EXEC_V03.zip"))
        self.assertIn("CIRCUIT_BREAKER_STATE_NOT_ACCEPTED", str(ctx.exception))

    def test_renamed_candidate_cannot_escape_breaker(self):
        with self.assertRaises(UACDenied) as ctx:
            evaluate_admission(base_request("METAMORPHOSE_RENAMED_CANDIDATE.zip"))
        self.assertIn("CIRCUIT_BREAKER_STATE_NOT_ACCEPTED", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
