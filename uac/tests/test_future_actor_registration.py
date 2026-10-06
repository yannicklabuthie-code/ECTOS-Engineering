import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / "config" / "future_actor_registration_contract.json").read_text(encoding="utf-8"))
REGISTRY = json.loads((ROOT / "config" / "registry.json").read_text(encoding="utf-8"))

class TestFutureActorRegistration(unittest.TestCase):
    def test_default_new_actor_is_denied(self):
        self.assertEqual(CONTRACT["default_new_actor_state"], "DENY")

    def test_default_new_repository_is_denied(self):
        self.assertEqual(CONTRACT["default_new_repository_state"], "DENY")

    def test_self_registration_is_prohibited(self):
        self.assertFalse(CONTRACT["self_registration_allowed"])
        self.assertFalse(CONTRACT["self_admission_allowed"])

    def test_signing_key_is_central_only(self):
        self.assertEqual(CONTRACT["signing_key_distribution"], "CENTRAL_ONLY_DO_NOT_COPY_TO_PRODUCER_REPOSITORIES")

    def test_direct_producer_handoff_is_prohibited(self):
        self.assertFalse(CONTRACT["direct_producer_handoff_allowed"])
        self.assertEqual(CONTRACT["canonical_signing_execution_repository"], "yannicklabuthie-code/ECTOS-Engineering")

    def test_registration_changes_require_protected_central_pr(self):
        self.assertEqual(CONTRACT["new_repository_activation"], "CENTRAL_REGISTRY_CHANGE_VIA_PROTECTED_PR_REQUIRED")
        self.assertEqual(CONTRACT["new_actor_activation"], "CENTRAL_REGISTRY_CHANGE_VIA_PROTECTED_PR_REQUIRED")

    def test_handoff_workflow_is_central_only(self):
        workflow = (ROOT.parent / ".github" / "workflows" / "ectos-canonical-handoff.yml").read_text(encoding="utf-8")
        self.assertIn("if: github.repository == 'yannicklabuthie-code/ECTOS-Engineering'", workflow)

    def test_registry_has_explicit_source_repository_allowlist(self):
        self.assertIn("source_repositories", REGISTRY)
        self.assertTrue(REGISTRY["source_repositories"])

if __name__ == "__main__":
    unittest.main()
