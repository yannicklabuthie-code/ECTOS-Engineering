import argparse
import json
import os
import sys
from pathlib import Path

from uac_core import UACDenied, issue_receipt, verify_receipt


def load_json(path: str):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(data):
    json.dump(data, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def get_key(env_name: str) -> bytes:
    value = os.environ.get(env_name)
    if not value:
        raise UACDenied(f"SIGNING_KEY_ENV_MISSING:{env_name}")
    return value.encode("utf-8")


def get_public_keyring(env_name: str) -> dict[str, dict]:
    value = os.environ.get(env_name, "")
    if not value:
        raise UACDenied(f"AUTHORITY_EVIDENCE_PUBLIC_KEYRING_MISSING:{env_name}")
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
    parser = argparse.ArgumentParser(prog="ectos-uac")
    sub = parser.add_subparsers(dest="cmd", required=True)

    admit = sub.add_parser("admit")
    admit.add_argument("--request", required=True)
    admit.add_argument("--signing-key-env", default="ECTOS_UAC_SIGNING_KEY")
    admit.add_argument("--authority-public-keyring-env", default="ECTOS_UAC_EVIDENCE_PUBLIC_KEYS")
    admit.add_argument("--ttl-seconds", type=int, default=900)

    verify = sub.add_parser("verify")
    verify.add_argument("--receipt", required=True)
    verify.add_argument("--target", required=True)
    verify.add_argument("--action", required=True)
    verify.add_argument("--signing-key-env", default="ECTOS_UAC_SIGNING_KEY")
    verify.add_argument("--consume", action="store_true")
    verify.add_argument("--ledger", default=str(Path(__file__).resolve().parent / "state" / "replay_ledger.json"))

    args = parser.parse_args()
    try:
        key = get_key(args.signing_key_env)
        if args.cmd == "admit":
            req = load_json(args.request)
            write_json(issue_receipt(
                req,
                key,
                ttl_seconds=args.ttl_seconds,
                authority_keyring=get_public_keyring(args.authority_public_keyring_env),
            ))
        else:
            receipt = load_json(args.receipt)
            write_json(verify_receipt(receipt, key, args.target, args.action,
                                      consume=args.consume, ledger_path=Path(args.ledger)))
        return 0
    except UACDenied as exc:
        write_json({"decision": "DENY", "reason": str(exc)})
        return 40
    except Exception as exc:
        write_json({"decision": "DENY", "reason": "UAC_INTERNAL_FAILURE", "type": type(exc).__name__})
        return 50


if __name__ == "__main__":
    raise SystemExit(main())
