from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from handoff import materialize_handoff, verify_handoff
from uac_core import UACDenied


def _key_from_env(name: str) -> bytes:
    value = os.environ.get(name, "")
    if not value:
        raise UACDenied("PRODUCTION_SIGNING_KEY_MISSING")
    return value.encode("utf-8")


def _public_keyring_from_env(name: str) -> dict[str, dict]:
    value = os.environ.get(name, "")
    if not value:
        raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_UNAVAILABLE")
    try:
        raw = json.loads(value)
    except json.JSONDecodeError as exc:
        raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_INVALID_JSON") from exc
    if not isinstance(raw, dict) or not raw:
        raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_INVALID")
    for key_id, public_key in raw.items():
        if not isinstance(key_id, str) or not isinstance(public_key, dict):
            raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_INVALID")
        if public_key.get("key_use") != "VERIFY_ONLY":
            raise UACDenied("AUTHORITY_EVIDENCE_PUBLIC_KEYRING_NOT_VERIFY_ONLY")
    return raw


def main() -> int:
    parser = argparse.ArgumentParser(description="ECTOS canonical UAC handoff")
    sub = parser.add_subparsers(dest="command", required=True)

    issue = sub.add_parser("issue")
    issue.add_argument("--package", required=True)
    issue.add_argument("--manifest", required=True)
    issue.add_argument("--dependency-graph", required=True)
    issue.add_argument("--request", required=True)
    issue.add_argument("--pre-dispatch-receipt", required=True)
    issue.add_argument("--staged-paths", required=True)
    issue.add_argument("--output-dir", required=True)
    issue.add_argument("--commit-sha", required=True)
    issue.add_argument("--governance-attestation", required=True)
    issue.add_argument("--signing-key-env", default="ECTOS_UAC_SIGNING_KEY")
    issue.add_argument("--authority-public-keyring-env", default="ECTOS_UAC_EVIDENCE_PUBLIC_KEYS")

    verify = sub.add_parser("verify")
    verify.add_argument("--package", required=True)
    verify.add_argument("--manifest", required=True)
    verify.add_argument("--dependency-graph", required=True)
    verify.add_argument("--descriptor", required=True)
    verify.add_argument("--receipt", required=True)
    verify.add_argument("--pre-dispatch-receipt", required=True)
    verify.add_argument("--staged-paths", required=True)
    verify.add_argument("--governance-attestation", required=True)
    verify.add_argument("--expected-commit-sha")
    verify.add_argument("--signing-key-env", default="ECTOS_UAC_SIGNING_KEY")

    args = parser.parse_args()
    try:
        key = _key_from_env(args.signing_key_env)
        if args.command == "issue":
            result = materialize_handoff(
                Path(args.package), Path(args.manifest), Path(args.dependency_graph), Path(args.request),
                Path(args.pre_dispatch_receipt), Path(args.staged_paths), Path(args.output_dir), key,
                args.commit_sha, Path(args.governance_attestation),
                _public_keyring_from_env(args.authority_public_keyring_env),
            )
        else:
            result = verify_handoff(
                Path(args.package), Path(args.manifest), Path(args.dependency_graph), Path(args.descriptor),
                Path(args.receipt), Path(args.pre_dispatch_receipt), Path(args.staged_paths),
                Path(args.governance_attestation), key, args.expected_commit_sha,
            )
        print(json.dumps(result, sort_keys=True))
        return 0
    except UACDenied as exc:
        print(json.dumps({"decision": "DENY", "reason": str(exc)}, sort_keys=True), file=sys.stderr)
        return 40


if __name__ == "__main__":
    raise SystemExit(main())
