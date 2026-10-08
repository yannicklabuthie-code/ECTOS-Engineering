from __future__ import annotations

import copy
import subprocess
import tempfile
import unittest
from pathlib import Path

from validators.workspace_identity.validate_workspace_identity import (
    WorkspaceIdentityPolicyError,
    inspect_workspace_member,
    load_json,
    path_matches,
    selected_family,
    validate_all,
    validate_generic_contract,
    validate_gitattributes,
    validate_materialization_contract,
    validate_materialization_evidence,
    validate_member_model,
)

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "governance" / "workspace-identity"
MODEL = load_json(BASE / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V01.json")
GENERIC = load_json(BASE / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V01.json")
MATERIALIZATION = load_json(BASE / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V01.json")
ATTR = (ROOT / ".gitattributes").read_text(encoding="utf-8")


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {result.stderr}")
    return result.stdout.strip()


def make_repo(root: Path, *, autocrlf: str, attributes: str | None) -> Path:
    repo = root / "repo"
    repo.mkdir()
    git(repo, "init")
    git(repo, "config", "user.email", "ectos@example.invalid")
    git(repo, "config", "user.name", "ECTOS Test")
    git(repo, "config", "core.autocrlf", autocrlf)
    if attributes is not None:
        (repo / ".gitattributes").write_bytes(attributes.encode("utf-8"))
    (repo / "sample.py").write_bytes(b"print('ectos')\n")
    git(repo, "add", ".")
    git(repo, "commit", "-m", "fixture")
    return repo


def sample_evidence() -> dict:
    return {
        "source_repository": "yannicklabuthie-code/ECTOS-Engineering",
        "remote_commit": "a" * 40,
        "local_head": "a" * 40,
        "worktree_path": "C:/dev/example",
        "host_identity": "SUCCEESMINDSET",
        "materialization_evidence_current": True,
        "workspace_evidence_source": "RAW_WORKSPACE_BYTES",
        "raw_byte_identity_result": "PASS",
        "runtime_identity": "Python 3.14.3",
    }


class WorkspaceIdentityPolicyTests(unittest.TestCase):
    def test_01_complete_policy_validates(self):
        validate_all(ROOT)

    def test_02_all_required_semantic_families_are_registered(self):
        validate_member_model(MODEL)
        ids = {x["family_id"] for x in MODEL["families"]}
        expected = {
            "PYTHON_EXECUTABLE_SOURCES", "JSON_CONTRACTS", "JSON_DURABLE_RUNTIME_STATE",
            "GOVERNED_MARKDOWN", "YAML_WORKFLOWS", "MANIFESTS", "SHA_SIDECARS",
            "RECEIPTS", "POINTERS", "MISSION_REGISTRY_MEMBERS", "DEPENDENCY_GRAPH_MEMBERS",
            "VERSIONED_GOVERNANCE_SOURCES", "PACKAGE_HANDOFF_IDENTITY_INPUTS", "BINARY_ARTIFACTS",
        }
        self.assertEqual(expected, ids)

    def test_03_unregistered_governed_family_fails_closed(self):
        model = copy.deepcopy(MODEL)
        model["families"] = [x for x in model["families"] if x["family_id"] != "RECEIPTS"]
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "REQUIRED_FAMILY_MISSING"):
            validate_member_model(model)

    def test_04_binary_family_cannot_use_text_eol(self):
        model = copy.deepcopy(MODEL)
        binary = next(x for x in model["families"] if x["family_id"] == "BINARY_ARTIFACTS")
        binary["eol_policy"] = "LF"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BINARY_EOL_INVALID"):
            validate_member_model(model)

    def test_05_blind_star_text_policy_rejected(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLIND_TEXT_POLICY_FORBIDDEN"):
            validate_gitattributes("* text eol=lf\n" + ATTR)

    def test_06_unspecified_python_attribute_policy_fails_closed(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "TEXT_EOL_POLICY_MISSING"):
            validate_gitattributes(ATTR.replace("*.py text eol=lf\n", ""))

    def test_07_binary_exclusion_required(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BINARY_EXCLUSION_MISSING"):
            validate_gitattributes(ATTR.replace("*.zip -text\n", ""))

    def test_08_normalized_hash_substitution_prohibited(self):
        contract = copy.deepcopy(GENERIC)
        contract["normalization_during_hash"] = "ALLOWED"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "NORMALIZATION_MUST_BE_PROHIBITED"):
            validate_generic_contract(contract)

    def test_09_blob_workspace_substitution_prohibited(self):
        contract = copy.deepcopy(GENERIC)
        contract["blob_substitution_as_workspace_evidence"] = "ALLOWED"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLOB_SUBSTITUTION_MUST_BE_PROHIBITED"):
            validate_generic_contract(contract)

    def test_10_remote_commit_cannot_imply_execution_ready(self):
        contract = copy.deepcopy(GENERIC)
        contract["qualification_binding"]["remote_commit_exists_implies_execution_ready"] = True
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "REMOTE_COMMIT_CANNOT_IMPLY_EXECUTION_READY"):
            validate_generic_contract(contract)

    def test_11_host_global_config_not_required(self):
        contract = copy.deepcopy(MATERIALIZATION)
        contract["host_global_config_required"] = True
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "HOST_GLOBAL_CONFIG_REQUIRED_FORBIDDEN"):
            validate_materialization_contract(contract)

    def test_12_autocrlf_false_explicit_lf_materializes_lf(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="false", attributes="*.py text eol=lf\n")
            (repo / "sample.py").unlink()
            git(repo, "checkout", "--", "sample.py")
            self.assertIn("w/lf", git(repo, "ls-files", "--eol", "--", "sample.py"))

    def test_13_autocrlf_true_explicit_lf_materializes_lf(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="true", attributes="*.py text eol=lf\n")
            (repo / "sample.py").unlink()
            git(repo, "checkout", "--", "sample.py")
            self.assertIn("w/lf", git(repo, "ls-files", "--eol", "--", "sample.py"))

    def test_14_autocrlf_true_unspecified_attribute_can_materialize_crlf(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="false", attributes=None)
            git(repo, "config", "core.autocrlf", "true")
            (repo / "sample.py").write_bytes(b"print('ectos')\r\n")
            self.assertIn("w/crlf", git(repo, "ls-files", "--eol", "--", "sample.py"))

    def test_15_clean_git_status_can_hide_raw_byte_mismatch(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="false", attributes=None)
            blob = git(repo, "rev-parse", "HEAD:sample.py")
            git(repo, "config", "core.autocrlf", "true")
            (repo / "sample.py").write_bytes(b"print('ectos')\r\n")
            self.assertEqual(git(repo, "status", "--porcelain"), "")
            raw = git(repo, "hash-object", "--no-filters", "--", "sample.py")
            self.assertNotEqual(raw, blob)

    def test_16_explicit_lf_member_passes_physical_inspection(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="true", attributes="*.py text eol=lf\n")
            model = {"families": [{
                "family_id": "TEST_PYTHON", "path_pattern_or_member_set": ["sample.py"],
                "byte_identity_required": "YES", "eol_policy": "LF", "binary_or_text": "TEXT",
                "qualification_required": "YES", "currentness_source": "EXACT_COMMIT",
                "exceptions": [], "rationale": "test",
            }]}
            result = inspect_workspace_member(repo, "sample.py", model)
            self.assertEqual(result["byte_identity"], "PASS")
            self.assertEqual(result["workspace_eol"], "w/lf")

    def test_17_wrong_materialized_commit_fails(self):
        evidence = sample_evidence()
        evidence["local_head"] = "b" * 40
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "WRONG_MATERIALIZED_COMMIT"):
            validate_materialization_evidence(evidence)

    def test_18_remote_present_local_materialization_absent_fails(self):
        evidence = sample_evidence()
        evidence["local_head"] = ""
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "MATERIALIZATION_EVIDENCE_MISSING"):
            validate_materialization_evidence(evidence)

    def test_19_stale_materialization_evidence_fails(self):
        evidence = sample_evidence()
        evidence["materialization_evidence_current"] = False
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "STALE_MATERIALIZATION_EVIDENCE"):
            validate_materialization_evidence(evidence)

    def test_20_normalized_hash_substitution_attempt_fails(self):
        evidence = sample_evidence()
        evidence["workspace_evidence_source"] = "NORMALIZED_HASH"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLOB_OR_NORMALIZED_WORKSPACE_SUBSTITUTION"):
            validate_materialization_evidence(evidence)

    def test_21_blob_bytes_as_workspace_evidence_fails(self):
        evidence = sample_evidence()
        evidence["workspace_evidence_source"] = "GIT_BLOB"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLOB_OR_NORMALIZED_WORKSPACE_SUBSTITUTION"):
            validate_materialization_evidence(evidence)

    def test_22_mission_registry_specific_family_wins(self):
        family = selected_family("engineering/mission_registry.py", MODEL)
        self.assertIsNotNone(family)
        self.assertEqual(family["family_id"], "MISSION_REGISTRY_MEMBERS")

    def test_23_dependency_graph_specific_family_wins(self):
        family = selected_family("engineering/dependency_graph.py", MODEL)
        self.assertIsNotNone(family)
        self.assertEqual(family["family_id"], "DEPENDENCY_GRAPH_MEMBERS")

    def test_24_binary_family_is_selected_for_binary_artifact(self):
        family = selected_family("fixtures/example.zip", MODEL)
        self.assertIsNotNone(family)
        self.assertEqual(family["family_id"], "BINARY_ARTIFACTS")

    def test_25_double_star_matches_direct_and_nested_members(self):
        self.assertTrue(path_matches("engineering/tool.py", "**/*.py"))
        self.assertTrue(path_matches("engineering/sub/tool.py", "**/*.py"))

    def test_26_new_family_requires_no_generic_engine_change(self):
        model = copy.deepcopy(MODEL)
        model["families"].append({
            "family_id": "NEW_FAMILY",
            "path_pattern_or_member_set": ["new-family/**/*.txt"],
            "byte_identity_required": "YES", "eol_policy": "LF", "binary_or_text": "TEXT",
            "qualification_required": "YES", "currentness_source": "EXACT_SOURCE_COMMIT",
            "exceptions": [], "rationale": "extensibility test",
        })
        family = selected_family("new-family/x.txt", model)
        self.assertIsNotNone(family)
        self.assertEqual(family["family_id"], "NEW_FAMILY")

    def test_27_forensic_preservation_is_required(self):
        self.assertEqual(
            GENERIC["rollback_boundary"]["forensic_preservation"],
            "PRESERVE_FAILED_WORKTREE_UNTIL_EXPLICIT_REMOVAL_AUTHORITY",
        )

    def test_28_mission_registry_does_not_duplicate_graph_topology(self):
        self.assertFalse(
            MATERIALIZATION["dependency_graph_binding"]["duplicate_graph_topology_in_mission_registry"]
        )

    def test_29_empty_family_set_fails_closed(self):
        model = copy.deepcopy(MODEL)
        model["families"] = []
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "MODEL_FAMILIES_REQUIRED"):
            validate_member_model(model)

    def test_30_raw_byte_identity_result_must_pass(self):
        evidence = sample_evidence()
        evidence["raw_byte_identity_result"] = "FAIL"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "RAW_BYTE_IDENTITY_NOT_PROVEN"):
            validate_materialization_evidence(evidence)


if __name__ == "__main__":
    unittest.main()
