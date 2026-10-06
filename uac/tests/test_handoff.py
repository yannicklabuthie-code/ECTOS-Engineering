import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from handoff import materialize_handoff, verify_handoff
from uac_core import UACDenied

KEY = b"test-only-handoff-key"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def request_for(package: Path, manifest: Path):
    return {
        "project": "ECTOS",
        "mission_id": "HANDOFF-TEST",
        "failure_family_id": "HANDOFF-TEST-FAMILY",
        "actor": "ECTOS_REPOSITORY_AGENT",
        "qualifier": "ECTOS_INDEPENDENT_QUALIFIER",
        "systemic_assurance_id": "ECTOS_SYSTEMIC_ASSURANCE",
        "admission_authority": "ECTOS_UAC_CONTROL_PLANE_V01",
        "package_id": package.name,
        "package_sha256": sha256(package),
        "manifest_sha256": sha256(manifest),
        "target": "ECTOS_PACKAGE_HANDOFF",
        "action": "ISSUE_HANDOFF",
        "qualification_result": "PASS",
        "systemic_review_state": "PASS",
        "consolidated_defect_set_state": "CLOSED",
        "governance_currentness": "PROVEN_CURRENT",
        "rule_source_currentness": "PROVEN_CURRENT",
        "negative_controls": "PASS",
        "circuit_breaker_state": "CLEAR"
    }


class TestCanonicalHandoff(unittest.TestCase):
    def setup_case(self, root: Path):
        package = root / "candidate.zip"
        manifest = root / "manifest.json"
        request = root / "request.json"
        output = root / "handoff"
        package.write_bytes(b"canonical-package-v01")
        manifest.write_text('{"schema":"test"}\n', encoding="utf-8")
        request.write_text(json.dumps(request_for(package, manifest)), encoding="utf-8")
        return package, manifest, request, output

    def test_positive_handoff(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            descriptor = materialize_handoff(package, manifest, request, output, KEY, "a" * 40)
            self.assertEqual(descriptor["state"], "PACKAGE_READY_FOR_HANDOFF")
            result = verify_handoff(
                package, manifest, output / "HANDOFF_DESCRIPTOR.json",
                output / "UAC_RECEIPT.json", KEY, "a" * 40,
            )
            self.assertEqual(result["decision"], "ADMIT")

    def test_modified_package_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            materialize_handoff(package, manifest, request, output, KEY, "b" * 40)
            package.write_bytes(b"tampered")
            with self.assertRaises(UACDenied) as ctx:
                verify_handoff(package, manifest, output / "HANDOFF_DESCRIPTOR.json",
                               output / "UAC_RECEIPT.json", KEY)
            self.assertIn("HANDOFF_PACKAGE_TAMPERED", str(ctx.exception))

    def test_modified_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            materialize_handoff(package, manifest, request, output, KEY, "c" * 40)
            manifest.write_text('{"schema":"tampered"}\n', encoding="utf-8")
            with self.assertRaises(UACDenied) as ctx:
                verify_handoff(package, manifest, output / "HANDOFF_DESCRIPTOR.json",
                               output / "UAC_RECEIPT.json", KEY)
            self.assertIn("HANDOFF_MANIFEST_TAMPERED", str(ctx.exception))

    def test_request_hash_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            data = json.loads(request.read_text(encoding="utf-8"))
            data["package_sha256"] = "0" * 64
            request.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaises(UACDenied) as ctx:
                materialize_handoff(package, manifest, request, output, KEY, "d" * 40)
            self.assertIn("PACKAGE_SHA256_BINDING_MISMATCH", str(ctx.exception))

    def test_missing_signing_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            with self.assertRaises(UACDenied) as ctx:
                materialize_handoff(package, manifest, request, output, b"", "e" * 40)
            self.assertIn("PRODUCTION_SIGNING_KEY_MISSING", str(ctx.exception))

    def test_wrong_commit_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            package, manifest, request, output = self.setup_case(Path(td))
            materialize_handoff(package, manifest, request, output, KEY, "f" * 40)
            with self.assertRaises(UACDenied) as ctx:
                verify_handoff(package, manifest, output / "HANDOFF_DESCRIPTOR.json",
                               output / "UAC_RECEIPT.json", KEY, "1" * 40)
            self.assertIn("HANDOFF_COMMIT_MISMATCH", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
