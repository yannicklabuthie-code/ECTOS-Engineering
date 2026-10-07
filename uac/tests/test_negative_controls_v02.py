from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(TESTS))

from byte_contract import validate_canonical_json_file
from staged_paths import resolve_staged_path
from uac_core import UACDenied, evaluate_admission
from support import KEYRING, attach_evidence, sign_evidence
import test_handoff as th


def base_request() -> dict:
    return {
        "project": "ECTOS",
        "mission_id": "UAC-SYSTEMIC-REMEDIATION-V03",
        "failure_family_id": "UAC-CANONICAL-HANDOFF-CONTROL-PLANE",
        "actor": "ECTOS_REPOSITORY_AGENT",
        "qualifier": "ECTOS_INDEPENDENT_QUALIFIER",
        "systemic_assurance_id": "ECTOS_SYSTEMIC_ASSURANCE",
        "admission_authority": "ECTOS_UAC_CONTROL_PLANE_V02",
        "package_id": "PKG-V03",
        "package_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
        "dependency_graph_sha256": "c" * 64,
        "dependency_closure": "PASS",
        "undeclared_dependency_count": 0,
        "unresolved_transitive_dependency_count": 0,
        "untested_dependency_count": 0,
        "implicit_environment_assumption_count": 0,
        "unknown_blast_radius_edge_count": 0,
        "target": "ECTOS_PACKAGE_HANDOFF",
        "action": "ISSUE_HANDOFF",
        "qualification_result": "PASS",
        "systemic_review_state": "PASS",
        "consolidated_defect_set_state": "CLOSED",
        "governance_currentness": "PROVEN_CURRENT",
        "rule_source_currentness": "PROVEN_CURRENT",
        "negative_controls": "PASS",
        "circuit_breaker_state": "CLEAR",
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "source_commit": "d" * 40,
    }


class TestNegativeControlsV02(unittest.TestCase):
    def deny(self, request: dict, contains: str) -> None:
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(UACDenied) as ctx:
                evaluate_admission(request, authority_keyring=KEYRING, evidence_ledger_path=Path(td) / "ledger.json")
        self.assertIn(contains, str(ctx.exception))

    def valid(self) -> dict:
        return attach_evidence(base_request(), "nc")

    def test_nc01_caller_clear_without_breaker_evidence_denied(self):
        r = self.valid(); r["authority_evidence"].pop("circuit_breaker")
        self.deny(r, "AUTHORITY_EVIDENCE_MISSING:circuit_breaker")

    def test_nc02_qualification_pass_without_qualifier_evidence_denied(self):
        r = self.valid(); r["authority_evidence"].pop("independent_qualification")
        self.deny(r, "AUTHORITY_EVIDENCE_MISSING:independent_qualification")

    def test_nc03_systemic_pass_without_systemic_evidence_denied(self):
        r = self.valid(); r["authority_evidence"].pop("systemic_assurance")
        self.deny(r, "AUTHORITY_EVIDENCE_MISSING:systemic_assurance")

    def test_nc04_defect_closed_without_closure_evidence_denied(self):
        r = self.valid(); r["authority_evidence"].pop("consolidated_defect_closure")
        self.deny(r, "AUTHORITY_EVIDENCE_MISSING:consolidated_defect_closure")

    def test_nc05_stale_rule_currentness_denied(self):
        r = self.valid(); r["rule_source_currentness"] = "STALE"
        self.deny(r, "CALLER_STATE_NOT_BOUND_TO_AUTHORITY_EVIDENCE:rule_source_currentness")

    def test_nc06_wrong_package_denied(self):
        r = self.valid(); r["package_id"] = "WRONG-PACKAGE"
        self.deny(r, "AUTHORITY_EVIDENCE_BINDING_MISMATCH")

    def test_nc07_wrong_package_sha_denied(self):
        r = self.valid(); r["package_sha256"] = "f" * 64
        self.deny(r, "AUTHORITY_EVIDENCE_BINDING_MISMATCH")

    def test_nc08_wrong_mission_denied(self):
        r = self.valid(); r["mission_id"] = "WRONG-MISSION"
        self.deny(r, "AUTHORITY_EVIDENCE_BINDING_MISMATCH")

    def test_nc09_wrong_issuer_denied(self):
        r = self.valid(); r["authority_evidence"]["independent_qualification"]["issuer_id"] = "ECTOS_REPOSITORY_AGENT"
        self.deny(r, "AUTHORITY_EVIDENCE_ISSUER_ID_INVALID")

    def test_nc10_expired_evidence_denied(self):
        r = self.valid(); e = dict(r["authority_evidence"]["independent_qualification"])
        now = datetime.now(timezone.utc)
        e["issued_at"] = (now - timedelta(minutes=20)).isoformat()
        e["expires_at"] = (now - timedelta(minutes=10)).isoformat()
        r["authority_evidence"]["independent_qualification"] = sign_evidence(e, "QUALIFIER_KEY_V01")
        self.deny(r, "AUTHORITY_EVIDENCE_EXPIRED")

    def test_nc11_replayed_evidence_denied(self):
        r = self.valid()
        with tempfile.TemporaryDirectory() as td:
            ledger = Path(td) / "ledger.json"
            evaluate_admission(r, authority_keyring=KEYRING, evidence_ledger_path=ledger, consume_authority_evidence=True)
            with self.assertRaises(UACDenied) as ctx:
                evaluate_admission(r, authority_keyring=KEYRING, evidence_ledger_path=ledger, consume_authority_evidence=True)
        self.assertIn("AUTHORITY_EVIDENCE_REPLAY", str(ctx.exception))

    def test_nc12_package_modified_after_evidence_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = case.setup_case(Path(td)); case.materialize(*args)
            package, manifest, graph, request, pre, staged, output, governance = args
            package.write_bytes(b"tampered")
            with self.assertRaises(UACDenied) as ctx: case.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_PACKAGE_TAMPERED", str(ctx.exception))

    def test_nc13_manifest_modified_after_evidence_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = case.setup_case(Path(td)); case.materialize(*args)
            package, manifest, graph, request, pre, staged, output, governance = args
            manifest.write_bytes(b'{"tampered":true}\n')
            with self.assertRaises(UACDenied) as ctx: case.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_MANIFEST_TAMPERED", str(ctx.exception))

    def test_nc14_dependency_graph_modified_after_evidence_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = case.setup_case(Path(td)); case.materialize(*args)
            package, manifest, graph, request, pre, staged, output, governance = args
            graph.write_bytes(b'{"tampered":true}\n')
            with self.assertRaises(UACDenied) as ctx: case.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_DEPENDENCY_GRAPH_TAMPERED", str(ctx.exception))

    def test_nc15_utf8_bom_request_fails_pre_handoff(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "request.json"; p.write_bytes(b"\xef\xbb\xbf{}\n")
            with self.assertRaises(UACDenied) as ctx: validate_canonical_json_file(p)
        self.assertIn("UTF8_BOM_PROHIBITED", str(ctx.exception))

    def test_nc16_crlf_drift_fails_pre_handoff(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "request.json"; p.write_bytes(b'{"a":1}\r\n')
            with self.assertRaises(UACDenied) as ctx: validate_canonical_json_file(p)
        self.assertIn("NON_CANONICAL_JSON_BYTES", str(ctx.exception))

    def test_nc17_exact_nested_candidate_path_works(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); p = root / "source" / "pkg" / "candidate.zip"
            p.parent.mkdir(parents=True); p.write_bytes(b"x")
            self.assertEqual(resolve_staged_path(root, "pkg/candidate.zip"), p.resolve())

    def test_nc18_producer_self_generated_independent_qualification_denied(self):
        r = self.valid(); e = dict(r["authority_evidence"]["independent_qualification"])
        e["issuer_id"] = r["actor"]
        r["authority_evidence"]["independent_qualification"] = sign_evidence(e, "QUALIFIER_KEY_V01")
        self.deny(r, "AUTHORITY_EVIDENCE_ISSUER_ID_INVALID")

    def test_nc19_qualifier_equals_producer_denied(self):
        r = base_request(); r["qualifier"] = r["actor"]; attach_evidence(r, "nc19")
        self.deny(r, "CANNOT_BE_ITS_OWN_QUALIFIER")

    def test_nc20_invalid_authority_separation_denied(self):
        r = base_request(); r["systemic_assurance_id"] = r["qualifier"]; attach_evidence(r, "nc20")
        self.deny(r, "SYSTEMIC_ASSURANCE_SEPARATION_VIOLATION")


if __name__ == "__main__":
    unittest.main()
