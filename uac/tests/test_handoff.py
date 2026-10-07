import hashlib
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from byte_contract import canonical_json_bytes, write_canonical_json
from handoff import materialize_handoff, verify_handoff
from uac_core import UACDenied
from tests.support import KEYRING, attach_evidence

KEY = b"test-only-handoff-key"
SOURCE_COMMIT = "a" * 40
SOURCE_TREE_SHA = "9" * 64


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def request_for(package: Path, manifest: Path, graph: Path):
    request = {
        "project": "ECTOS",
        "mission_id": "HANDOFF-TEST",
        "failure_family_id": "HANDOFF-TEST-FAMILY",
        "actor": "ECTOS_REPOSITORY_AGENT",
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "source_commit": SOURCE_COMMIT,
        "qualifier": "ECTOS_INDEPENDENT_QUALIFIER",
        "systemic_assurance_id": "ECTOS_SYSTEMIC_ASSURANCE",
        "admission_authority": "ECTOS_UAC_CONTROL_PLANE_V02",
        "package_id": package.name,
        "package_sha256": sha256(package),
        "manifest_sha256": sha256(manifest),
        "dependency_graph_sha256": sha256(graph),
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
    }
    return attach_evidence(request, "handoff")


def write_pre_dispatch(root: Path, package: Path, manifest: Path, graph: Path, request: Path):
    req = json.loads(request.read_text(encoding="utf-8"))
    staged = {
        "package": "source/candidate.zip",
        "manifest": "source/manifest.json",
        "dependency_graph": "source/ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01.json",
        "request": "source/request.json",
    }
    staged_path = root / "staged-paths.json"
    write_canonical_json(staged_path, staged)
    now = datetime.now(timezone.utc)
    receipt = {
        "schema_id": "ECTOS_UAC_PRE_DISPATCH_RECEIPT_V03",
        "decision": "PASS",
        "issued_at": (now - timedelta(seconds=5)).isoformat(),
        "expires_at": (now + timedelta(minutes=10)).isoformat(),
        "package_id": req["package_id"],
        "mission_id": req["mission_id"],
        "source_repository": req["source_repository"],
        "source_commit": req["source_commit"],
        "staging_commit": req["source_commit"],
        "source_tree_sha256": SOURCE_TREE_SHA,
        "source_file_count": 4,
        "staged_path_set": staged,
        "staged_path_set_sha256": hashlib.sha256(canonical_json_bytes(staged)).hexdigest(),
        "files": {
            "package": {"declared_path": "candidate.zip", "size_bytes": package.stat().st_size, "sha256": sha256(package)},
            "manifest": {"declared_path": "manifest.json", "size_bytes": manifest.stat().st_size, "sha256": sha256(manifest)},
            "dependency_graph": {"declared_path": "ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01.json", "size_bytes": graph.stat().st_size, "sha256": sha256(graph)},
            "request": {"declared_path": "request.json", "size_bytes": request.stat().st_size, "sha256": sha256(request)},
        },
    }
    pre = root / "PRE_DISPATCH_RECEIPT.json"
    write_canonical_json(pre, receipt)
    return pre, staged_path


class TestCanonicalHandoff(unittest.TestCase):
    def setup_case(self, root: Path):
        package = root / "candidate.zip"
        manifest = root / "manifest.json"
        graph = root / "ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01.json"
        request = root / "request.json"
        output = root / "handoff"
        governance = root / "governance.json"
        package.write_bytes(b"canonical-package-v03")
        write_canonical_json(manifest, {"schema": "test"})
        write_canonical_json(graph, {
            "schema_id": "ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01",
            "package_id": "candidate.zip", "package_version": "test", "nodes": [], "edges": [],
            "closure": {"dependency_closure": "PASS", "undeclared_dependency_count": 0,
                        "unresolved_transitive_dependency_count": 0, "untested_dependency_count": 0,
                        "implicit_environment_assumption_count": 0, "unknown_blast_radius_edge_count": 0},
        })
        write_canonical_json(request, request_for(package, manifest, graph))
        write_canonical_json(governance, {"schema_id": "ECTOS_GITHUB_GOVERNANCE_ATTESTATION_V01", "decision": "PASS"})
        pre, staged = write_pre_dispatch(root, package, manifest, graph, request)
        return package, manifest, graph, request, pre, staged, output, governance

    def materialize(self, package, manifest, graph, request, pre, staged, output, governance):
        return materialize_handoff(
            package, manifest, graph, request, pre, staged, output, KEY, SOURCE_COMMIT, governance,
            KEYRING, evidence_ledger_path=output.parent / "evidence-ledger.json",
        )

    def verify(self, package, manifest, graph, output):
        return verify_handoff(
            package, manifest, graph, output / "HANDOFF_DESCRIPTOR.json", output / "UAC_RECEIPT.json",
            output / "PRE_DISPATCH_RECEIPT.json", output / "STAGED_PATHS.json",
            output / "GOVERNANCE_ATTESTATION.json", KEY, SOURCE_COMMIT,
        )

    def test_positive_handoff(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            descriptor = self.materialize(*args)
            self.assertEqual(descriptor["state"], "PACKAGE_READY_FOR_HANDOFF")
            self.assertEqual(self.verify(package, manifest, graph, output)["decision"], "ADMIT")

    def test_modified_package_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            self.materialize(*args); package.write_bytes(b"tampered")
            with self.assertRaises(UACDenied) as ctx: self.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_PACKAGE_TAMPERED", str(ctx.exception))

    def test_modified_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            self.materialize(*args); write_canonical_json(manifest, {"schema": "tampered"})
            with self.assertRaises(UACDenied) as ctx: self.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_MANIFEST_TAMPERED", str(ctx.exception))

    def test_request_hash_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = list(self.setup_case(Path(td))); data = json.loads(args[3].read_text(encoding="utf-8"))
            data["package_sha256"] = "0" * 64; write_canonical_json(args[3], data)
            with self.assertRaises(UACDenied) as ctx: self.materialize(*args)
            self.assertIn("PACKAGE_SHA256_BINDING_MISMATCH", str(ctx.exception))

    def test_missing_signing_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            with self.assertRaises(UACDenied) as ctx:
                materialize_handoff(package, manifest, graph, request, pre, staged, output, b"", SOURCE_COMMIT, governance, KEYRING)
            self.assertIn("PRODUCTION_SIGNING_KEY_MISSING", str(ctx.exception))

    def test_unregistered_source_repository_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = list(self.setup_case(Path(td))); data = json.loads(args[3].read_text(encoding="utf-8"))
            data["source_repository"] = "unknown/rogue-repository"; write_canonical_json(args[3], data)
            with self.assertRaises(UACDenied) as ctx: self.materialize(*args)
            self.assertIn("SOURCE_REPOSITORY_NOT_REGISTERED", str(ctx.exception))

    def test_repository_actor_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = list(self.setup_case(Path(td))); data = json.loads(args[3].read_text(encoding="utf-8"))
            data["actor"] = "ECTOS_MAIN_AUTHORITY"; write_canonical_json(args[3], data)
            with self.assertRaises(UACDenied) as ctx: self.materialize(*args)
            self.assertIn("SOURCE_REPOSITORY_ACTOR_NOT_REGISTERED", str(ctx.exception))

    def test_wrong_commit_binding_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            with self.assertRaises(UACDenied) as ctx:
                materialize_handoff(package, manifest, graph, request, pre, staged, output, KEY, "f" * 40, governance, KEYRING)
            self.assertIn("SOURCE_COMMIT_BINDING_MISMATCH", str(ctx.exception))

    def test_governance_attestation_tamper_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            self.materialize(*args); write_canonical_json(output / "GOVERNANCE_ATTESTATION.json", {"decision": "PASS", "tampered": True})
            with self.assertRaises(UACDenied) as ctx: self.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_GOVERNANCE_ATTESTATION_TAMPERED", str(ctx.exception))

    def test_dependency_graph_tamper_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            args = self.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            self.materialize(*args); write_canonical_json(graph, {"tampered": True})
            with self.assertRaises(UACDenied) as ctx: self.verify(package, manifest, graph, output)
            self.assertIn("HANDOFF_DEPENDENCY_GRAPH_TAMPERED", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
