#!/usr/bin/env python3
"""ECTOS OMNIGATE V45 — isolated, fail-closed external authority preflight.

Never accepts the trust anchor or its fingerprint from the subject's signature
bundle. An independently provisioned governance anchor is REQUIRED. This is a
producer engineering component, not an independent qualifier or admission gate.
"""
from __future__ import annotations
import base64, hashlib, json, pathlib, sys

DOMAIN = b"ECTOS-OMNIGATE-EXTERNAL-AUTHORITY-V37\n"


def digest(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def canonical(d: dict) -> bytes:
    return json.dumps(d, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')


def verify_authority(*, envelope: dict, subject: bytes, subject_object: dict,
                     target_digest: str, expected_scope: str,
                     public_key: bytes | None,
                     independently_pinned_public_key_digest: str | None,
                     approved_source: bytes | None,
                     source_digest: str | None) -> list[str]:
    failures: list[str] = []
    # Nothing in the candidate's own package can supply or override the root pin.
    if not independently_pinned_public_key_digest:
        failures.append('INDEPENDENTLY_PROVISIONED_TRUST_ROOT_REQUIRED')
    if not public_key or len(public_key) != 32:
        failures.append('TRUST_ROOT_PUBLIC_KEY_MISSING_OR_INVALID')
    elif independently_pinned_public_key_digest and digest(public_key) != independently_pinned_public_key_digest:
        failures.append('TRUST_ROOT_NOT_PINNED_BY_EXTERNAL_GOVERNANCE')
    if envelope.get('scope') != expected_scope:
        failures.append('SCOPE_MISMATCH')
    if envelope.get('subject_sha256') != digest(subject):
        failures.append('SUBJECT_BYTES_MISMATCH')
    if envelope.get('target_sha256') != target_digest:
        failures.append('TARGET_SHA_MISMATCH')
    if envelope.get('decision') != 'APPROVED' or envelope.get('currentness') != 'CURRENT':
        failures.append('OWNER_APPROVAL_OR_CURRENTNESS_NOT_PROVEN')
    if expected_scope == 'QC02_REQUIREMENT_CONTRACT_APPROVAL':
        if subject_object.get('contract_state') != 'APPROVED' or subject_object.get('currentness_state') != 'CURRENT':
            failures.append('CONTRACT_NOT_APPROVED_CURRENT')
        if not approved_source or digest(approved_source) != source_digest:
            failures.append('SOURCE_BYTES_OR_SHA_NOT_PROVEN')
        if subject_object.get('requirement_source_sha256') != source_digest:
            failures.append('CONTRACT_TO_SOURCE_BINDING_INVALID')
    if not failures:
        try:
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
            signature = base64.b64decode(envelope['signature_b64'], validate=True)
            Ed25519PublicKey.from_public_bytes(public_key).verify(signature, DOMAIN + canonical({k: v for k,v in envelope.items() if k != 'signature_b64'}))
        except Exception:
            failures.append('SIGNATURE_INVALID')
    return failures


def main() -> int:
    import argparse
    a=argparse.ArgumentParser()
    for n in ('contract','source','envelope','root','output'):
        a.add_argument('--'+n, required=False)
    args=a.parse_args()
    if not args.contract or not args.output:
        a.error('--contract and --output are required')
    b=pathlib.Path(args.contract).read_bytes(); contract=json.loads(b)
    source=pathlib.Path(args.source).read_bytes() if args.source and pathlib.Path(args.source).is_file() else None
    env=json.loads(pathlib.Path(args.envelope).read_bytes()) if args.envelope and pathlib.Path(args.envelope).is_file() else {}
    root=pathlib.Path(args.root).read_bytes() if args.root and pathlib.Path(args.root).is_file() else None
    # The ECTOS governance trust pin is NOT available as independently confirmed
    # evidence. Never infer it from the local candidate or caller arguments.
    independent_governance_pin = None
    failures=verify_authority(envelope=env, subject=canonical(contract), subject_object=contract,
        target_digest=contract.get('target_package_sha256',''), expected_scope='QC02_REQUIREMENT_CONTRACT_APPROVAL',
        public_key=root, independently_pinned_public_key_digest=independent_governance_pin,
        approved_source=source,source_digest=contract.get('requirement_source_sha256'))
    report={'schema':'OMNIGATE_V45_F01_F05_EXTERNAL_ROOT_PREFLIGHT','status':'BLOCKED' if failures else 'ELIGIBLE_ONLY',
            'defects':failures,'qc02_native_pass':'NOT_GRANTED','qc03_tool_trust':'NOT_PROVEN',
            'main_admission':'NOT_GRANTED','independent_qualification':'NOT_PERFORMED'}
    pathlib.Path(args.output).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(report['status'],len(failures))
    return 40 if failures else 0

if __name__=='__main__': sys.exit(main())
