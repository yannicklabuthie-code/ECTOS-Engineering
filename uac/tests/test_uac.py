import copy
import tempfile
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from uac_core import UACDenied, issue_receipt, verify_receipt

KEY = b"test-only-uac-key"
SHA_A = "a" * 64
SHA_B = "b" * 64


def valid_request():
    return {
        "project": "ECTOS",
        "mission_id": "TEST-MISSION",
        "failure_family_id": "TEST-FAMILY",
        "actor": "ECTOS_MAIN_AUTHORITY",
        "qualifier": "ECTOS_INDEPENDENT_QUALIFIER",
        "systemic_assurance_id": "ECTOS_SYSTEMIC_ASSURANCE",
        "admission_authority": "ECTOS_UAC_CONTROL_PLANE_V01",
        "package_id": "PKG-V01",
        "package_sha256": SHA_A,
        "manifest_sha256": SHA_B,
        "target": "ECTOS_ENGINEERING_REPOSITORY_PROMOTION",
        "action": "PROMOTE_CANDIDATE",
        "qualification_result": "PASS",
        "systemic_review_state": "PASS",
        "consolidated_defect_set_state": "CLOSED",
        "governance_currentness": "PROVEN_CURRENT",
        "rule_source_currentness": "PROVEN_CURRENT",
        "negative_controls": "PASS",
        "circuit_breaker_state": "CLEAR"
    }


class TestUAC(unittest.TestCase):
    def test_positive_receipt(self):
        receipt = issue_receipt(valid_request(), KEY)
        with tempfile.TemporaryDirectory() as td:
            result = verify_receipt(receipt, KEY,
                                    "ECTOS_ENGINEERING_REPOSITORY_PROMOTION",
                                    "PROMOTE_CANDIDATE",
                                    consume=True,
                                    ledger_path=Path(td) / "ledger.json")
        self.assertEqual(result["decision"], "ADMIT")

    def assert_denied(self, request, contains):
        with self.assertRaises(UACDenied) as ctx:
            issue_receipt(request, KEY)
        self.assertIn(contains, str(ctx.exception))

    def test_unknown_actor_denied(self):
        r = valid_request(); r["actor"] = "UNKNOWN_AGENT"
        self.assert_denied(r, "ROUTE_NOT_REGISTERED")

    def test_unknown_target_denied(self):
        r = valid_request(); r["target"] = "UNKNOWN_TARGET"
        self.assert_denied(r, "ROUTE_NOT_REGISTERED")

    def test_unknown_action_denied(self):
        r = valid_request(); r["action"] = "DEPLOY_ANYTHING"
        self.assert_denied(r, "ROUTE_NOT_REGISTERED")

    def test_self_admission_denied(self):
        r = valid_request(); r["admission_authority"] = r["actor"]
        self.assert_denied(r, "SELF_ADMISSION_PROHIBITED")

    def test_self_qualification_denied(self):
        r = valid_request(); r["qualifier"] = r["actor"]
        self.assert_denied(r, "OWN_QUALIFIER")

    def test_systemic_assurance_separation_denied(self):
        r = valid_request(); r["systemic_assurance_id"] = r["qualifier"]
        self.assert_denied(r, "SYSTEMIC_ASSURANCE_SEPARATION")

    def test_breaker_denied(self):
        r = valid_request(); r["circuit_breaker_state"] = "TRIGGERED"
        self.assert_denied(r, "CIRCUIT_BREAKER_STATE_NOT_ACCEPTED")

    def test_stale_governance_denied(self):
        r = valid_request(); r["governance_currentness"] = "STALE"
        self.assert_denied(r, "GOVERNANCE_CURRENTNESS_NOT_ACCEPTED")

    def test_stale_rule_source_denied(self):
        r = valid_request(); r["rule_source_currentness"] = "NOT_PROVEN"
        self.assert_denied(r, "RULE_SOURCE_CURRENTNESS_NOT_ACCEPTED")

    def test_negative_controls_required(self):
        r = valid_request(); r["negative_controls"] = "NOT_PROVEN"
        self.assert_denied(r, "NEGATIVE_CONTROLS_NOT_ACCEPTED")

    def test_bad_package_sha_denied(self):
        r = valid_request(); r["package_sha256"] = "abc"
        self.assert_denied(r, "PACKAGE_SHA256_INVALID")

    def test_bad_manifest_sha_denied(self):
        r = valid_request(); r["manifest_sha256"] = "xyz"
        self.assert_denied(r, "MANIFEST_SHA256_INVALID")

    def test_wrong_target_receipt_denied(self):
        receipt = issue_receipt(valid_request(), KEY)
        with self.assertRaises(UACDenied):
            verify_receipt(receipt, KEY, "OTHER_TARGET", "PROMOTE_CANDIDATE")

    def test_wrong_action_receipt_denied(self):
        receipt = issue_receipt(valid_request(), KEY)
        with self.assertRaises(UACDenied):
            verify_receipt(receipt, KEY,
                           "ECTOS_ENGINEERING_REPOSITORY_PROMOTION", "OTHER_ACTION")

    def test_signature_tamper_denied(self):
        receipt = issue_receipt(valid_request(), KEY)
        receipt["payload"]["package_id"] = "TAMPERED"
        with self.assertRaises(UACDenied):
            verify_receipt(receipt, KEY,
                           "ECTOS_ENGINEERING_REPOSITORY_PROMOTION", "PROMOTE_CANDIDATE")

    def test_replay_denied_after_consume(self):
        receipt = issue_receipt(valid_request(), KEY)
        with tempfile.TemporaryDirectory() as td:
            ledger = Path(td) / "ledger.json"
            verify_receipt(receipt, KEY,
                           "ECTOS_ENGINEERING_REPOSITORY_PROMOTION", "PROMOTE_CANDIDATE",
                           consume=True, ledger_path=ledger)
            with self.assertRaises(UACDenied) as ctx:
                verify_receipt(receipt, KEY,
                               "ECTOS_ENGINEERING_REPOSITORY_PROMOTION", "PROMOTE_CANDIDATE",
                               consume=True, ledger_path=ledger)
            self.assertIn("REPLAY", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
