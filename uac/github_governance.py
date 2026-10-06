from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.request
from pathlib import Path
from typing import Any, Dict

from uac_core import UACDenied

HERE = Path(__file__).resolve().parent
DEFAULT_CONTRACT = HERE / "config" / "github_governance_contract.json"


def _canon(obj: Dict[str, Any]) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _load(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _required_status_rule(rules: list[dict]) -> dict:
    for rule in rules:
        if rule.get("type") == "required_status_checks":
            return rule
    raise UACDenied("GOVERNANCE_REQUIRED_STATUS_RULE_MISSING")


def validate_ruleset(ruleset: Dict[str, Any], contract: Dict[str, Any]) -> Dict[str, Any]:
    checks = {
        "ruleset_id": ruleset.get("id") == contract["ruleset_id"],
        "ruleset_name": ruleset.get("name") == contract["ruleset_name"],
        "target": ruleset.get("target") == contract["target"],
        "enforcement": ruleset.get("enforcement") == contract["enforcement"],
        "ref_include": ruleset.get("conditions", {}).get("ref_name", {}).get("include") == contract["required_ref_include"],
        "bypass_actor_count": len(ruleset.get("bypass_actors", [])) == contract["required_bypass_actor_count"],
    }
    if "current_user_can_bypass" in ruleset:
        checks["current_user_can_bypass"] = ruleset.get("current_user_can_bypass") == contract["current_user_can_bypass_if_present"]
    rules = ruleset.get("rules", [])
    rule_types = {r.get("type") for r in rules}
    checks["required_rule_types"] = set(contract["required_rule_types"]).issubset(rule_types)
    status_rule = _required_status_rule(rules)
    params = status_rule.get("parameters", {})
    contexts = {x.get("context") for x in params.get("required_status_checks", [])}
    checks["required_status_check"] = contract["required_status_check"] in contexts
    checks["strict_required_status_checks_policy"] = params.get("strict_required_status_checks_policy") is contract["strict_required_status_checks_policy"]
    failed = sorted(k for k, ok in checks.items() if not ok)
    if failed:
        raise UACDenied("GOVERNANCE_ATTESTATION_FAIL:" + ",".join(failed))
    observed = {
        "schema_id": "ECTOS_GITHUB_GOVERNANCE_ATTESTATION_V01",
        "repository": contract["repository"],
        "ruleset_id": ruleset.get("id"),
        "ruleset_name": ruleset.get("name"),
        "target": ruleset.get("target"),
        "enforcement": ruleset.get("enforcement"),
        "ref_include": ruleset.get("conditions", {}).get("ref_name", {}).get("include"),
        "bypass_actor_count": len(ruleset.get("bypass_actors", [])),
        "current_user_can_bypass": ruleset.get("current_user_can_bypass"),
        "required_status_check": contract["required_status_check"],
        "strict_required_status_checks_policy": params.get("strict_required_status_checks_policy"),
        "rule_types": sorted(rule_types),
        "decision": "PASS",
    }
    observed["attestation_sha256"] = hashlib.sha256(_canon(observed)).hexdigest()
    return observed


def fetch_ruleset(repository: str, ruleset_id: int, token: str) -> Dict[str, Any]:
    if not token:
        raise UACDenied("GITHUB_GOVERNANCE_TOKEN_MISSING")
    url = f"https://api.github.com/repos/{repository}/rulesets/{ruleset_id}"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "ECTOS-UAC-Governance-Attestor",
    })
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.load(resp)
    except Exception as exc:
        raise UACDenied("GITHUB_GOVERNANCE_FETCH_FAILED") from exc


def attest_live(output: Path, token: str, contract_path: Path = DEFAULT_CONTRACT) -> Dict[str, Any]:
    contract = _load(contract_path)
    ruleset = fetch_ruleset(contract["repository"], int(contract["ruleset_id"]), token)
    attestation = validate_ruleset(ruleset, contract)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(attestation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return attestation


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--output", required=True)
    p.add_argument("--token-env", default="GITHUB_TOKEN")
    p.add_argument("--contract", default=str(DEFAULT_CONTRACT))
    args = p.parse_args()
    try:
        result = attest_live(Path(args.output), os.environ.get(args.token_env, ""), Path(args.contract))
        print(json.dumps(result, sort_keys=True))
        return 0
    except UACDenied as exc:
        print(json.dumps({"decision":"DENY","reason":str(exc)}, sort_keys=True), file=sys.stderr)
        return 40

if __name__ == "__main__":
    raise SystemExit(main())
