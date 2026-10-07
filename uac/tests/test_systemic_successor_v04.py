from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import authority_evidence
from byte_contract import write_canonical_json
from pre_dispatch import verify_pre_dispatch
from uac_core import UACDenied, evaluate_admission
from tests.support import KEYRING, attach_evidence
from tests.test_uac import valid_request
from tests import test_handoff as th


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=str(root), capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


def _build_two_commit_candidate(root: Path):
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "test@example.invalid")
    _git(root, "config", "user.name", "ECTOS Test")
    (root / "source.txt").write_bytes(b"line-one\nline-two\n")
    package = root / "candidate.zip"; package.write_bytes(b"package-source-v04")
    manifest = root / "manifest.json"; write_canonical_json(manifest, {"schema": "manifest"})
    graph = root / "graph.json"; write_canonical_json(graph, {"schema": "graph"})
    _git(root, "add", "source.txt", "candidate.zip", "manifest.json", "graph.json")
    _git(root, "commit", "-q", "-m", "source")
    source_commit = _git(root, "rev-parse", "HEAD")
    request = root / "request.json"
    write_canonical_json(request, {
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "source_commit": source_commit,
        "package_id": "candidate.zip",
        "mission_id": "V04-PRE-DISPATCH",
        "package_sha256": __import__("hashlib").sha256(package.read_bytes()).hexdigest(),
        "manifest_sha256": __import__("hashlib").sha256(manifest.read_bytes()).hexdigest(),
        "dependency_graph_sha256": __import__("hashlib").sha256(graph.read_bytes()).hexdigest(),
    })
    _git(root, "add", "request.json")
    _git(root, "commit", "-q", "-m", "transaction metadata")
    return source_commit, package, manifest, graph, request


def _pre(root: Path, source_commit: str, package: Path, manifest: Path, graph: Path, request: Path):
    return verify_pre_dispatch(root, source_commit, package.name, manifest.name, graph.name, request.name)


def _rewrite(path: Path, mutator):
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    write_canonical_json(path, data)


class TestSystemicSuccessorV04(unittest.TestCase):
    def test_positive_complete_control(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = case.setup_case(Path(td)); package, manifest, graph, request, pre, staged, output, governance = args
            descriptor = case.materialize(*args)
            result = case.verify(package, manifest, graph, output)
            self.assertEqual(descriptor["state"], "PACKAGE_READY_FOR_HANDOFF")
            self.assertEqual(result["decision"], "ADMIT")

    def test_crlf_lf_source_byte_drift_denied(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); source_commit, package, manifest, graph, request = _build_two_commit_candidate(root)
            (root / "source.txt").write_bytes(b"line-one\r\nline-two\r\n")
            with self.assertRaises(UACDenied) as ctx: _pre(root, source_commit, package, manifest, graph, request)
            self.assertIn("SOURCE_WORKTREE_GIT_BYTE_MISMATCH", str(ctx.exception))

    def test_wrong_source_commit_denied(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); source_commit, package, manifest, graph, request = _build_two_commit_candidate(root)
            wrong = _git(root, "rev-parse", "HEAD")
            with self.assertRaises(UACDenied) as ctx: _pre(root, wrong, package, manifest, graph, request)
            self.assertIn("REQUEST_SOURCE_COMMIT_MISMATCH", str(ctx.exception))

    def test_nonexistent_source_commit_denied(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); source_commit, package, manifest, graph, request = _build_two_commit_candidate(root)
            with self.assertRaises(UACDenied) as ctx: _pre(root, "f" * 40, package, manifest, graph, request)
            self.assertIn("SOURCE_COMMIT_NOT_FOUND", str(ctx.exception))

    def test_unregistered_admission_authority_denied(self):
        r = valid_request(); r["admission_authority"] = "UNKNOWN_ADMISSION_AUTHORITY"
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(UACDenied) as ctx: evaluate_admission(r, authority_keyring=KEYRING, evidence_ledger_path=Path(td) / "ledger.json")
        self.assertIn("ADMISSION_AUTHORITY_NOT_REGISTERED", str(ctx.exception))

    def test_wrong_admission_authority_role_denied(self):
        r = valid_request()
        registry = json.loads((ROOT / "config" / "registry.json").read_text(encoding="utf-8"))
        registry["admission_authorities"]["ECTOS_UAC_CONTROL_PLANE_V02"]["role"] = "PRODUCER"
        with tempfile.TemporaryDirectory() as td:
            rp = Path(td) / "registry.json"; rp.write_text(json.dumps(registry), encoding="utf-8")
            with self.assertRaises(UACDenied) as ctx: evaluate_admission(r, registry_path=rp, authority_keyring=KEYRING, evidence_ledger_path=Path(td) / "ledger.json")
        self.assertIn("ADMISSION_AUTHORITY_ROLE_INVALID", str(ctx.exception))

    def test_caller_only_governance_currentness_denied(self):
        r = valid_request(); r["authority_evidence"].pop("governance_currentness")
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(UACDenied) as ctx: evaluate_admission(r, authority_keyring=KEYRING, evidence_ledger_path=Path(td) / "ledger.json")
        self.assertIn("AUTHORITY_EVIDENCE_MISSING:governance_currentness", str(ctx.exception))

    def test_verifier_cannot_sign_independent_authority_evidence(self):
        self.assertFalse(hasattr(authority_evidence, "sign_evidence"))
        for public_key in KEYRING.values():
            self.assertEqual(public_key.get("key_use"), "VERIFY_ONLY")
            self.assertFalse(any(name in public_key for name in ("d", "private_exponent", "private_key", "secret")))

    def test_shared_public_key_across_independent_roles_denied(self):
        r = valid_request(); bad = copy.deepcopy(KEYRING)
        bad["SYSTEMIC_ASSURANCE_KEY_V01"] = dict(bad["QUALIFIER_KEY_V01"])
        bad["SYSTEMIC_ASSURANCE_KEY_V01"]["issuer_id"] = "ECTOS_SYSTEMIC_ASSURANCE"
        bad["SYSTEMIC_ASSURANCE_KEY_V01"]["issuer_role"] = "SYSTEMIC_ASSURANCE"
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(UACDenied) as ctx: evaluate_admission(r, authority_keyring=bad, evidence_ledger_path=Path(td) / "ledger.json")
        self.assertIn("CRYPTOGRAPHIC_AUTHORITY_KEY_SEPARATION_VIOLATION", str(ctx.exception))

    def test_concurrent_reuse_one_evidence_instance_max_one_admit(self):
        r = valid_request()
        with tempfile.TemporaryDirectory() as td:
            ledger = Path(td) / "ledger.json"
            def attempt(_):
                try:
                    evaluate_admission(r, authority_keyring=KEYRING, evidence_ledger_path=ledger, consume_authority_evidence=True)
                    return "ADMIT"
                except UACDenied:
                    return "DENY"
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(attempt, range(8)))
            self.assertEqual(results.count("ADMIT"), 1, results)
            self.assertEqual(results.count("DENY"), 7, results)

    def test_altered_pre_dispatch_receipt_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d["files"]["package"].update({"sha256": "0" * 64}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_PACKAGE_BINDING_MISMATCH", str(ctx.exception))

    def test_foreign_pre_dispatch_receipt_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d.update({"source_repository": "foreign/repo"}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_SOURCE_REPOSITORY_MISMATCH", str(ctx.exception))

    def test_stale_pre_dispatch_receipt_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d.update({"expires_at": (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_STALE", str(ctx.exception))

    def test_pre_dispatch_deny_decision_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d.update({"decision": "DENY"}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_DECISION_NOT_PASS", str(ctx.exception))

    def test_mismatched_source_commit_receipt_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d.update({"source_commit": "f" * 40}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_SOURCE_COMMIT_MISMATCH", str(ctx.exception))

    def test_mismatched_staged_path_receipt_denied(self):
        with tempfile.TemporaryDirectory() as td:
            case = th.TestCanonicalHandoff(); args = list(case.setup_case(Path(td)))
            _rewrite(args[4], lambda d: d["staged_path_set"].update({"package": "source/foreign.zip"}))
            with self.assertRaises(UACDenied) as ctx: case.materialize(*args)
            self.assertIn("PRE_DISPATCH_STAGED_PATH_SET_MISMATCH", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
