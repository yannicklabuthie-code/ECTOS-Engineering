import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCOPE = json.loads((ROOT / "config" / "scope_contract.json").read_text(encoding="utf-8"))
REGISTRY = json.loads((ROOT / "config" / "registry.json").read_text(encoding="utf-8"))


class TestUACScopeContract(unittest.TestCase):
    def test_handoff_is_terminal_uac_boundary(self):
        self.assertEqual(SCOPE["handoff_boundary"], "PACKAGE_READY_FOR_HANDOFF")
        self.assertFalse(SCOPE["target_environment_ready_is_uac_criterion"])

    def test_external_runtime_qualification_is_empty(self):
        self.assertEqual(SCOPE["external_environment_qualification_scope"], [])

    def test_external_runtime_families_are_explicitly_out_of_scope(self):
        required = {
            "CLOUD_RUNTIME", "GCP_RUNTIME", "FIREBASE_RUNTIME", "CLOUD_RUN_RUNTIME",
            "AWS_RUNTIME", "AZURE_RUNTIME", "FLUTTER_CONSUMER_RUNTIME"
        }
        self.assertTrue(required.issubset(set(SCOPE["external_environments_explicitly_out_of_scope"])))

    def test_only_ectos_owned_promotion_target_is_registered(self):
        targets = set(REGISTRY.get("targets", {}))
        self.assertEqual(targets, {"ECTOS_ENGINEERING_REPOSITORY_PROMOTION"})

    def test_no_external_deploy_action_is_registered(self):
        actions = {a for route in REGISTRY.get("routes", []) for a in route.get("actions", [])}
        forbidden = {"DEPLOY", "DEPLOY_CLOUD", "DEPLOY_FIREBASE", "DEPLOY_CLOUD_RUN", "DEPLOY_AWS", "DEPLOY_AZURE"}
        self.assertTrue(actions.isdisjoint(forbidden))

    def test_contract_validation_remains_in_scope(self):
        self.assertIn("DECLARED_INTERFACES", SCOPE["qualification_scope"])
        self.assertIn("PACKAGE_CONTRACTS", SCOPE["qualification_scope"])


if __name__ == "__main__":
    unittest.main()
