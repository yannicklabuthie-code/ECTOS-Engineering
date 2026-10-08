from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from validators.workspace_identity.validate_workspace_identity import (
    WorkspaceIdentityPolicyError,
    build_physical_evidence,
    inspect_cleanliness,
    inspect_workspace_member,
    load_json,
    path_matches,
    selected_family,
    validate_classification_baseline,
    validate_gitattributes,
    validate_json_with_schema,
    validate_materialization_evidence,
    validate_member_model,
    validate_policy_selection_closure,
)

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "governance" / "workspace-identity"
MODEL = load_json(BASE / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.json")
GENERIC = load_json(BASE / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V02.json")
MATERIALIZATION = load_json(BASE / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V02.json")
BASELINE = load_json(BASE / "ECTOS_WORKSPACE_IDENTITY_CLASSIFICATION_BASELINE_V01.json")
ATTR = (ROOT / ".gitattributes").read_text(encoding="utf-8")


def git(repo: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(["git", "-C", str(repo), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check and result.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {result.stderr}")
    return result.stdout.strip()


def make_repo(root: Path, *, autocrlf: str = "false", attributes: str = "*.py text eol=lf\n", ignored: str | None = None) -> Path:
    repo = root / "repo"; repo.mkdir()
    git(repo, "init"); git(repo, "config", "user.email", "ectos@example.invalid"); git(repo, "config", "user.name", "ECTOS Test"); git(repo, "config", "core.autocrlf", autocrlf)
    (repo / ".gitattributes").write_text(attributes, encoding="utf-8", newline="\n")
    if ignored is not None: (repo / ".gitignore").write_text(ignored, encoding="utf-8", newline="\n")
    (repo / "sample.py").write_text("print('ectos')\n", encoding="utf-8", newline="\n")
    git(repo, "add", "."); git(repo, "commit", "-m", "fixture")
    return repo


def mini_model() -> dict:
    return {"families": [{
        "family_id": "TEST_PYTHON", "path_pattern_or_member_set": ["sample.py"], "priority": 100,
        "byte_identity_required": "YES", "eol_policy": "LF", "binary_or_text": "TEXT",
        "qualification_required": "YES", "currentness_source": "EXACT_SOURCE_COMMIT", "exceptions": [], "rationale": "test"
    }]}


class WorkspaceIdentityPolicyV02Tests(unittest.TestCase):
    def test_01_v02_contracts_and_model_validate(self):
        validate_json_with_schema(ROOT, GENERIC, GENERIC["schema_path"])
        validate_json_with_schema(ROOT, MATERIALIZATION, MATERIALIZATION["schema_path"])
        validate_json_with_schema(ROOT, MODEL, "schemas/workspace_identity/ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V02.schema.json")
        validate_member_model(MODEL)

    def test_02_truncated_contract_fails_schema(self):
        value = copy.deepcopy(GENERIC); value.pop("qualification_binding")
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "SCHEMA_FIELD_MISSING"):
            validate_json_with_schema(ROOT, value, GENERIC["schema_path"])

    def test_03_stale_contract_currentness_fails(self):
        value = copy.deepcopy(GENERIC); value["status"] = "SUPERSEDED"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "SCHEMA_CONST_INVALID"):
            validate_json_with_schema(ROOT, value, GENERIC["schema_path"])

    def test_04_zero_families_fails(self):
        value = copy.deepcopy(MODEL); value["families"] = []
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_member_model(value)

    def test_05_one_family_fails_required_set(self):
        value = copy.deepcopy(MODEL); value["families"] = value["families"][:1]
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "REQUIRED_FAMILY_MISSING"):
            validate_member_model(value)

    def test_06_duplicate_family_fails(self):
        value = copy.deepcopy(MODEL); value["families"].append(copy.deepcopy(value["families"][0]))
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "DUPLICATE_FAMILY_ID"):
            validate_member_model(value)

    def test_07_selection_rules_are_executable_contract(self):
        for key in ["most_specific_semantic_family_wins", "binary_exclusion_is_absolute"]:
            value = copy.deepcopy(MODEL); value["selection_rules"][key] = False
            with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "SELECTION_RULE_INVALID"):
                validate_member_model(value)

    def test_08_byte_identity_and_qualification_cannot_be_disabled(self):
        value = copy.deepcopy(MODEL); value["families"][0]["byte_identity_required"] = "NO"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BYTE_IDENTITY_MUST_BE_ENFORCED"):
            validate_member_model(value)
        value = copy.deepcopy(MODEL); value["families"][0]["qualification_required"] = "NO"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "QUALIFICATION_MUST_BE_ENFORCED"):
            validate_member_model(value)

    def test_09_exceptions_are_executed(self):
        value = copy.deepcopy(MODEL); py = next(x for x in value["families"] if x["family_id"] == "PYTHON_EXECUTABLE_SOURCES"); py["exceptions"] = ["engineering/skip.py"]
        self.assertIsNone(selected_family("engineering/skip.py", {"families": [py]}))

    def test_10_equal_specificity_collision_fails_closed(self):
        value = copy.deepcopy(MODEL)
        base = next(x for x in value["families"] if x["family_id"] == "MISSION_REGISTRY_MEMBERS")
        collision = copy.deepcopy(base); collision["family_id"] = "ZZZ_COLLIDER"
        value["families"].append(collision)
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "SEMANTIC_FAMILY_COLLISION"):
            selected_family("engineering/mission_registry.py", value)

    def test_11_lexical_order_perturbation_does_not_choose_winner(self):
        value = copy.deepcopy(MODEL)
        base = next(x for x in value["families"] if x["family_id"] == "MISSION_REGISTRY_MEMBERS")
        collision = copy.deepcopy(base); collision["family_id"] = "AAA_COLLIDER"; value["families"].insert(0, collision)
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "SEMANTIC_FAMILY_COLLISION"):
            selected_family("engineering/mission_registry.py", value)

    def test_12_new_family_cannot_silently_reclassify_baseline(self):
        value = copy.deepcopy(MODEL)
        value["families"].append({"family_id":"NEW_OVERRIDE","path_pattern_or_member_set":["engineering/dependency_graph.py"],"priority":999,"byte_identity_required":"YES","eol_policy":"LF","binary_or_text":"TEXT","qualification_required":"YES","currentness_source":"EXACT_SOURCE_COMMIT","exceptions":[],"rationale":"negative"})
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "UNAUTHORIZED_CLASSIFICATION_CHANGE"):
            validate_classification_baseline(ROOT, value, BASELINE)

    def test_13_current_baseline_is_preserved(self):
        validate_classification_baseline(ROOT, MODEL, BASELINE)

    def test_14_unknown_family_fails_member_inspection(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp))
            with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "UNREGISTERED_GOVERNED_FAMILY"):
                inspect_workspace_member(repo, "sample.py", {"families": []})

    def test_15_gitattributes_policy_is_valid(self):
        rules = validate_gitattributes(ATTR)
        validate_policy_selection_closure(ROOT, MODEL, rules)

    def test_16_blind_text_policy_fails(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLIND_TEXT_POLICY_FORBIDDEN"):
            validate_gitattributes("* text eol=lf\n" + ATTR)

    def test_17_autocrlf_true_explicit_lf(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="true"); (repo / "sample.py").unlink(); git(repo, "checkout", "--", "sample.py")
            self.assertIn("w/lf", git(repo, "ls-files", "--eol", "--", "sample.py"))

    def test_18_autocrlf_false_explicit_lf(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="false"); (repo / "sample.py").unlink(); git(repo, "checkout", "--", "sample.py")
            self.assertIn("w/lf", git(repo, "ls-files", "--eol", "--", "sample.py"))

    def test_19_eol_conversion_raw_mismatch_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), autocrlf="false", attributes="# none\n"); (repo / "sample.py").write_bytes(b"print('ectos')\r\n")
            with self.assertRaises(WorkspaceIdentityPolicyError): inspect_workspace_member(repo, "sample.py", mini_model())

    def test_20_dirty_tracked_worktree_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp)); (repo / "sample.py").write_text("changed\n")
            with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "WORKTREE_TRACKED_DIRTY"): inspect_cleanliness(repo, MATERIALIZATION)

    def test_21_dirty_index_fails_even_if_worktree_matches_index(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp)); (repo / "sample.py").write_text("index\n"); git(repo, "add", "sample.py")
            with self.assertRaises(WorkspaceIdentityPolicyError): inspect_cleanliness(repo, MATERIALIZATION)

    def test_22_untracked_object_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp)); (repo / "extra.bin").write_bytes(b"x")
            with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "UNTRACKED_OBJECTS"): inspect_cleanliness(repo, MATERIALIZATION)

    def test_23_ignored_execution_relevant_object_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), ignored="*.cache\n"); (repo / "side.cache").write_text("x")
            with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "IGNORED_EXECUTION_RELEVANT_OBJECTS"): inspect_cleanliness(repo, MATERIALIZATION)

    def test_24_governed_safe_ignored_object_is_allowed(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = make_repo(Path(temp), ignored="*.tmp\n"); (repo / "safe.tmp").write_text("x")
            result = inspect_cleanliness(repo, MATERIALIZATION); self.assertTrue(result["worktree_clean"])

    def test_25_missing_evidence_fields_fail(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "MATERIALIZATION_EVIDENCE_MISSING"):
            validate_materialization_evidence(ROOT, {}, GENERIC, MODEL, MATERIALIZATION)

    def test_26_malformed_equal_commit_identities_fail_schema(self):
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, "yannicklabuthie-code/ECTOS-Engineering", git(ROOT, "rev-parse", "HEAD"))
        evidence["remote_commit"] = evidence["local_head"] = "NOT_A_SHA"
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_materialization_evidence(ROOT, evidence, GENERIC, MODEL, MATERIALIZATION)

    def test_27_remote_local_mismatch_fails(self):
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, "yannicklabuthie-code/ECTOS-Engineering", git(ROOT, "rev-parse", "HEAD"))
        evidence["remote_commit"] = "a" * 40
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_materialization_evidence(ROOT, evidence, GENERIC, MODEL, MATERIALIZATION)

    def test_28_normalized_hash_substitution_fails(self):
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, "yannicklabuthie-code/ECTOS-Engineering", git(ROOT, "rev-parse", "HEAD"))
        evidence["workspace_evidence_source"] = "NORMALIZED_HASH"
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_materialization_evidence(ROOT, evidence, GENERIC, MODEL, MATERIALIZATION)

    def test_29_blob_workspace_substitution_fails(self):
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, "yannicklabuthie-code/ECTOS-Engineering", git(ROOT, "rev-parse", "HEAD"))
        evidence["workspace_evidence_source"] = "GIT_BLOB"
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_materialization_evidence(ROOT, evidence, GENERIC, MODEL, MATERIALIZATION)

    def test_30_stale_evidence_fails(self):
        evidence = build_physical_evidence(ROOT, MODEL, MATERIALIZATION, "yannicklabuthie-code/ECTOS-Engineering", git(ROOT, "rev-parse", "HEAD"))
        evidence["materialization_evidence_current"] = False
        with self.assertRaises(WorkspaceIdentityPolicyError): validate_materialization_evidence(ROOT, evidence, GENERIC, MODEL, MATERIALIZATION)

    def test_31_cli_has_no_weak_default_path(self):
        result = subprocess.run([os.fspath(Path(os.sys.executable)), os.fspath(ROOT / "validators/workspace_identity/validate_workspace_identity.py"), "--root", os.fspath(ROOT)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--evidence", result.stderr)

    def test_32_package_graph_absence_is_not_a_pass(self):
        result = subprocess.run([os.fspath(Path(os.sys.executable)), os.fspath(ROOT / "validators/workspace_identity/validate_workspace_identity.py"), "--root", os.fspath(ROOT), "--evidence", "missing.json", "--manifest", "missing.json", "--dependency-graph", "missing.json"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(result.returncode, 0)

    def test_33_double_star_matching(self):
        self.assertTrue(path_matches("a/b/tool.py", "**/*.py")); self.assertTrue(path_matches("tool.py", "**/*.py"))


if __name__ == "__main__":
    unittest.main()
