from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parents[1]


def _load(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def bypass_scan(root: Path = ROOT) -> Dict[str, Any]:
    registry = _load(root / "uac" / "config" / "registry.json")
    findings: List[str] = []

    if registry.get("default_policy") != "DENY":
        findings.append("DEFAULT_POLICY_NOT_DENY")

    actors = registry.get("actors", {})
    for actor, cfg in actors.items():
        if cfg.get("can_self_admit", False):
            findings.append(f"SELF_ADMISSION_ENABLED:{actor}")

    repos = registry.get("source_repositories", {})
    for repo, cfg in repos.items():
        if not cfg.get("enabled"):
            continue
        for actor in cfg.get("actors", []):
            if actor not in actors or not actors[actor].get("enabled"):
                findings.append(f"REPOSITORY_BINDS_UNKNOWN_ACTOR:{repo}:{actor}")

    forbidden_actions = {"DEPLOY", "DEPLOY_CLOUD", "DEPLOY_FIREBASE", "DEPLOY_GCP", "DEPLOY_AWS", "DEPLOY_AZURE"}
    for route in registry.get("routes", []):
        actions = set(route.get("actions", []))
        bad = sorted(actions & forbidden_actions)
        if bad:
            findings.append(f"EXTERNAL_RUNTIME_ACTION_REGISTERED:{route.get('actor')}:{','.join(bad)}")

    workflows = root / ".github" / "workflows"
    signing_key_users = []
    for wf in workflows.glob("*.yml"):
        text = wf.read_text(encoding="utf-8")
        if "ECTOS_UAC_SIGNING_KEY" in text:
            signing_key_users.append(wf.name)
    if signing_key_users != ["ectos-canonical-handoff.yml"]:
        findings.append("SIGNING_KEY_USAGE_NOT_CENTRAL_ONLY:" + ",".join(sorted(signing_key_users)))

    handoff = (workflows / "ectos-canonical-handoff.yml").read_text(encoding="utf-8")
    required_tokens = [
        "github.repository == 'yannicklabuthie-code/ECTOS-Engineering'",
        "github_governance",
        "GOVERNANCE_ATTESTATION",
        "ECTOS_UAC_SIGNING_KEY",
    ]
    for token in required_tokens:
        if token not in handoff:
            findings.append(f"CANONICAL_HANDOFF_MISSING_CONTROL:{token}")

    return {
        "schema_id": "ECTOS_UAC_BYPASS_SCAN_V01",
        "decision": "PASS" if not findings else "FAIL",
        "bypass_path_count": len(findings),
        "findings": findings,
    }


def final_readiness(root: Path = ROOT) -> Dict[str, Any]:
    scan = bypass_scan(root)
    replay = _load(root / "uac" / "fixtures" / "metamorphose_historical_replay_v01.json")
    required_replay_fields = ["failure_family_id", "historical_defects", "candidate_aliases", "expected_result"]
    replay_complete = all(replay.get(k) for k in required_replay_fields) and len(replay["historical_defects"]) >= 4
    decision = "PASS" if scan["decision"] == "PASS" and replay_complete else "FAIL"
    return {
        "schema_id": "ECTOS_UAC_FINAL_SYSTEMIC_READINESS_V01",
        "decision": decision,
        "bypass_scan": scan,
        "metamorphose_historical_replay_fixture": "PASS" if replay_complete else "FAIL",
        "metamorphose_failure_family_id": replay.get("failure_family_id"),
        "terminal_boundary": "PACKAGE_READY_FOR_HANDOFF",
        "external_runtime_qualification": "OUT_OF_SCOPE",
    }


if __name__ == "__main__":
    result = final_readiness()
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["decision"] == "PASS" else 40)
