from __future__ import annotations

import copy
import unittest
from pathlib import Path

from validators.workspace_identity.validate_workspace_identity import (
    WorkspaceIdentityPolicyError,
    load_json,
    matching_families,
    validate_all,
    validate_generic_contract,
    validate_gitattributes,
    validate_materialization_contract,
    validate_member_model,
)

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "governance" / "workspace-identity"
MODEL = load_json(BASE / "ECTOS_WORKSPACE_IDENTITY_MEMBER_SELECTION_V01.json")
GENERIC = load_json(BASE / "ECTOS_GENERIC_WORKSPACE_IDENTITY_CONTRACT_V01.json")
MATERIALIZATION = load_json(BASE / "ECTOS_WINDOWS_MATERIALIZATION_CONTRACT_V01.json")
ATTR = (ROOT / ".gitattributes").read_text(encoding="utf-8")


class WorkspaceIdentityPolicyTests(unittest.TestCase):
    def test_complete_policy_validates(self):
        validate_all(ROOT)

    def test_autocrlf_true_supported_without_host_global_mutation(self):
        self.assertTrue(MATERIALIZATION["system_core_autocrlf_true_supported"])
        self.assertFalse(MATERIALIZATION["host_global_config_required"])

    def test_unspecified_attribute_fails_closed(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "TEXT_EOL_POLICY_MISSING"):
            validate_gitattributes(ATTR.replace("*.py text eol=lf\n", ""))

    def test_explicit_lf_attribute_present(self):
        validate_gitattributes(ATTR)
        self.assertIn("*.json text eol=lf", ATTR)

    def test_crlf_against_lf_blob_is_not_accepted(self):
        self.assertEqual(GENERIC["worktree_byte_identity_rule"]["selected_text_required_workspace_eol"], "w/lf")
        self.assertEqual(GENERIC["worktree_byte_identity_rule"]["required_comparison"], "EQUAL")

    def test_clean_git_status_is_not_raw_byte_identity(self):
        self.assertFalse(GENERIC["worktree_byte_identity_rule"]["clean_git_status_is_sufficient"])

    def test_missing_member_policy_fails_closed(self):
        model = copy.deepcopy(MODEL)
        model["families"] = [x for x in model["families"] if x["family_id"] != "MISSION_REGISTRY_MEMBERS"]
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "REQUIRED_FAMILY_MISSING"):
            validate_member_model(model)

    def test_binary_file_exclusion(self):
        self.assertIn("*.zip -text", ATTR)
        self.assertIn("*.png -text", ATTR)

    def test_remote_commit_does_not_imply_execution_ready(self):
        binding = GENERIC["qualification_binding"]
        self.assertFalse(binding["remote_commit_exists_implies_execution_ready"])
        self.assertFalse(binding["remote_commit_exists_implies_local_byte_identity"])

    def test_wrong_materialized_commit_requires_remote_and_local_heads(self):
        evidence = GENERIC["materialization_evidence_requirements"]
        self.assertIn("remote_commit", evidence)
        self.assertIn("local_head", evidence)

    def test_stale_materialization_evidence_fails_closed(self):
        self.assertIn("STALE_MATERIALIZATION_EVIDENCE", GENERIC["fail_closed_rule"]["conditions"])

    def test_normalized_hash_substitution_prohibited(self):
        self.assertEqual(GENERIC["normalization_during_hash"], "PROHIBITED")
        self.assertEqual(MATERIALIZATION["normalized_hash_substitution"], "PROHIBITED")

    def test_blob_bytes_cannot_substitute_for_workspace_bytes(self):
        self.assertEqual(GENERIC["blob_substitution_as_workspace_evidence"], "PROHIBITED")
        self.assertEqual(MATERIALIZATION["blob_bytes_as_workspace_evidence"], "PROHIBITED")

    def test_mission_registry_family_registered(self):
        self.assertIn("MISSION_REGISTRY_MEMBERS", matching_families("engineering/mission_registry.py", MODEL))

    def test_dependency_graph_family_registered(self):
        self.assertIn("DEPENDENCY_GRAPH_MEMBERS", matching_families("engineering/dependency_graph.py", MODEL))

    def test_qualification_chain(self):
        validate_generic_contract(GENERIC)
        self.assertEqual(GENERIC["qualification_binding"]["required_chain"][-1], "RESULT_EVIDENCE")

    def test_silent_existing_worktree_migration_prohibited(self):
        self.assertEqual(MATERIALIZATION["existing_worktree_migration_rule"]["silent_migration"], "PROHIBITED")

    def test_forensic_preservation(self):
        self.assertEqual(GENERIC["rollback_boundary"]["forensic_preservation"], "PRESERVE_FAILED_WORKTREE_UNTIL_EXPLICIT_REMOVAL_AUTHORITY")

    def test_graph_topology_not_duplicated_in_mission_registry(self):
        self.assertFalse(MATERIALIZATION["dependency_graph_binding"]["duplicate_graph_topology_in_mission_registry"])

    def test_blind_star_text_policy_rejected(self):
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BLIND_TEXT_POLICY_FORBIDDEN"):
            validate_gitattributes("* text eol=lf\n" + ATTR)

    def test_binary_family_cannot_be_text_eol(self):
        model = copy.deepcopy(MODEL)
        binary = next(x for x in model["families"] if x["family_id"] == "BINARY_ARTIFACTS")
        binary["eol_policy"] = "LF"
        with self.assertRaisesRegex(WorkspaceIdentityPolicyError, "BINARY_EOL_INVALID"):
            validate_member_model(model)

    def test_materialization_contract_fails_closed(self):
        validate_materialization_contract(MATERIALIZATION)
        self.assertFalse(MATERIALIZATION["fresh_materialization_rule"]["execution_eligible_before_all_proofs"])


if __name__ == "__main__":
    unittest.main()
