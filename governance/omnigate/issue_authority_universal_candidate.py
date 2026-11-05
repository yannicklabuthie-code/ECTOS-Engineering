#!/usr/bin/env python3
"""Governance-controlled OMNIGATE authorization issuer.
Only execute inside a protected, independently reviewed GitHub environment.
This code does not create a trust root or alter target artifacts.
"""
import base64
import datetime
import hashlib
import json
import os
import pathlib
import sys
import uuid

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

TARGET = os.environ.get('GOVERNANCE_APPROVED_TARGET_SHA256', '').lower()
DOMAIN = b'ECTOS-OMNIGATE-EXTERNAL-AUTHORITY-V37\n'


def canonical(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_strict(path):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError('DUPLICATE_JSON_KEY')
            value[key] = item
        return value
    return json.loads(path.read_bytes(), object_pairs_hook=unique)


def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError('MISSING_PROTECTED_ENV:' + name)
    return value


QC03_DOMAIN = b'ECTOS-OMNIGATE-QC03-INDEPENDENT-PROVENANCE-V01\n'

def verify_independent_qc03_attestations(registry, attestation, *, key_hex, key_sha256,
                                        issuer_id, revoked_approval_ids, governance_key_sha256):
    """Fail-closed: independently signed whole-register provenance proof (not a producer claim)."""
    from datetime import datetime, timezone
    if not isinstance(attestation, dict) or set(attestation) != {
        'schema', 'target_sha256', 'issuer_id', 'issuer_role', 'approval_id',
        'not_before', 'expires_at', 'decision', 'tools', 'signature_b64'
    }:
        raise ValueError('QC03_INDEPENDENT_ATTESTATION_SCHEMA_INVALID')
    if attestation['schema'] != 'ECTOS_QC03_INDEPENDENT_PROVENANCE_V01':
        raise ValueError('QC03_INDEPENDENT_ATTESTATION_WRONG_SCHEMA')
    if attestation['decision'] != 'APPROVED':
        raise ValueError('QC03_INDEPENDENT_DECISION_NOT_APPROVED')
    if attestation['issuer_role'] != 'QC03_INDEPENDENT_PROVENANCE_AUTHORITY':
        raise ValueError('QC03_INDEPENDENT_ISSUER_ROLE_INVALID')
    if attestation['issuer_id'] != issuer_id or issuer_id == os.environ.get('GOVERNANCE_APPROVED_ISSUER_ID'):
        raise ValueError('QC03_INDEPENDENT_ISSUER_NOT_DISTINCT')
    if not isinstance(revoked_approval_ids, list) or not all(isinstance(x, str) for x in revoked_approval_ids):
        raise ValueError('QC03_REVOCATION_LIST_INVALID')
    if not isinstance(attestation['approval_id'], str) or not attestation['approval_id'] or attestation['approval_id'] in revoked_approval_ids:
        raise ValueError('QC03_APPROVAL_REVOKED_OR_MISSING')
    try:
        start = datetime.fromisoformat(attestation['not_before'].replace('Z','+00:00'))
        end = datetime.fromisoformat(attestation['expires_at'].replace('Z','+00:00'))
        now = datetime.now(timezone.utc)
        if start.tzinfo is None or end.tzinfo is None or not start <= now < end:
            raise ValueError('QC03_ATTESTATION_OUT_OF_TIME_WINDOW')
    except (KeyError, TypeError, AttributeError):
        raise ValueError('QC03_ATTESTATION_TIME_INVALID')
    if attestation['target_sha256'] != TARGET or registry.get('target_package_sha256') != TARGET:
        raise ValueError('QC03_INDEPENDENT_TARGET_MISMATCH')
    observed = attestation['tools']
    if not isinstance(observed, list) or len(observed) != len(registry.get('tools', [])):
        raise ValueError('QC03_ATTESTATION_CONTROL_COUNT')
    registered = {}
    for tool in registry['tools']:
        cid = tool['control_id']
        registered[cid] = {k:tool.get(k) for k in (
            'control_id', 'tool_sha256', 'script_sha256',
            'tool_provenance_sha256', 'tool_provenance_ref', 'host_id')}
    seen = set()
    for item in observed:
        if not isinstance(item, dict) or set(item) != set(next(iter(registered.values()))) | {'decision'}:
            raise ValueError('QC03_ATTESTATION_TOOL_SCHEMA_INVALID')
        cid = item['control_id']
        if not isinstance(cid,str) or cid in seen or cid not in registered:
            raise ValueError('QC03_ATTESTATION_CONTROL_DUPLICATE_OR_UNKNOWN')
        seen.add(cid)
        if item['decision'] != 'APPROVED':
            raise ValueError('QC03_ATTESTATION_NON_APPROVAL')
        if {k:item.get(k) for k in registered[cid]} != registered[cid]:
            raise ValueError('QC03_ATTESTATION_TOOL_BINDING_MISMATCH:' + cid)
    if seen != set(registered):
        raise ValueError('QC03_ATTESTATION_CONTROL_SET_MISMATCH')
    try:
        key = bytes.fromhex(key_hex)
    except (TypeError, ValueError):
        raise ValueError('QC03_INDEPENDENT_PUBLIC_KEY_INVALID')
    if len(key) != 32 or sha(key) != key_sha256.lower() or sha(key) == governance_key_sha256.lower():
        raise ValueError('QC03_INDEPENDENT_PIN_INVALID_OR_COLLIDING')
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
    unsigned = {k:v for k,v in attestation.items() if k != 'signature_b64'}
    try:
        sig = base64.b64decode(attestation['signature_b64'], validate=True)
        Ed25519PublicKey.from_public_bytes(key).verify(sig, QC03_DOMAIN + canonical(unsigned))
    except Exception as exc:
        from cryptography.exceptions import InvalidSignature
        if isinstance(exc, (ValueError, TypeError, InvalidSignature)):
            raise ValueError('QC03_INDEPENDENT_SIGNATURE_INVALID') from exc
        raise
    return True


def main():
    if len(TARGET) != 64 or any(c not in '0123456789abcdef' for c in TARGET):
        raise ValueError('GOVERNANCE_TARGET_DIGEST_NOT_PINNED')
    if os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('PROTECTED_MAIN_BRANCH_REQUIRED')
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('GITHUB_PROTECTED_WORKFLOW_REQUIRED')
    source = pathlib.Path('authority_inputs/canonical_requirements.json')
    qc02 = pathlib.Path('authority_inputs/QC02_APPROVED_REQUIREMENTS.json')
    qc03 = pathlib.Path('authority_inputs/QC03_APPROVED_TOOL_REGISTRY.json')
    output = pathlib.Path('signed_authority')
    content = source.read_bytes()
    contract = read_strict(qc02)
    registry = read_strict(qc03)
    expected = {
        'SOURCE': (sha(content), required_env('APPROVED_SOURCE_SHA256')),
        'QC02': (sha(canonical(contract)), required_env('APPROVED_QC02_CANONICAL_SHA256')),
        'QC03': (sha(canonical(registry)), required_env('APPROVED_QC03_CANONICAL_SHA256')),
    }
    for label, (actual, pin) in expected.items():
        if actual != pin.lower():
            raise ValueError('GOVERNANCE_APPROVED_BYTE_PIN_MISMATCH:' + label)
    if contract.get('target_package_sha256') != TARGET or registry.get('target_package_sha256') != TARGET:
        raise ValueError('EXACT_TARGET_BINDING_MISMATCH')
    if contract.get('contract_state') != 'APPROVED' or contract.get('currentness_state') != 'CURRENT':
        raise ValueError('REQUIREMENT_CONTRACT_NOT_OWNER_APPROVED_CURRENT')
    if contract.get('requirement_source_sha256', '').lower() != sha(content):
        raise ValueError('APPROVED_SOURCE_TO_QC02_BINDING_INVALID')
    required_host_paths = {
        'source': r'C:\ProgramData\ECTOS\governance\omni_current_authorized_inputs\canonical_requirements.json',
        'qc02_envelope': r'C:\ProgramData\ECTOS\governance\omni_current_authorized_inputs\QC02_APPROVAL_ENVELOPE.json',
        'qc03_envelope': r'C:\ProgramData\ECTOS\governance\omni_current_authorized_inputs\QC03_APPROVAL_ENVELOPE.json',
    }
    if contract.get('requirement_source_ref') != required_host_paths['source']:
        raise ValueError('GOVERNED_SOURCE_HOST_PATH_NOT_BOUND')
    if contract.get('authority_envelope_ref') != required_host_paths['qc02_envelope']:
        raise ValueError('QC02_AUTHORITY_ENVELOPE_HOST_PATH_NOT_BOUND')
    if registry.get('authority_envelope_ref') != required_host_paths['qc03_envelope']:
        raise ValueError('QC03_AUTHORITY_ENVELOPE_HOST_PATH_NOT_BOUND')
    if not contract.get('requirements') or not registry.get('tools'):
        raise ValueError('EMPTY_CONTRACT_OR_TOOL_UNIVERSE_INVALID')
    if len({x.get('control_id') for x in registry['tools']}) != len(registry['tools']):
        raise ValueError('TOOL_ID_DUPLICATE')
    if len({x.get('property_id') for x in contract['requirements']}) != len(contract['requirements']):
        raise ValueError('DUPLICATE_REQUIREMENTS')
    ids = {t['control_id'] for t in registry['tools']}
    req_ids = {id for p in contract['requirements'] for id in [p['positive_control_id'], *p['negative_control_ids']]}
    if ids != req_ids:
        raise ValueError('QC02_QC03_CONTROL_SET_DISAGREEMENT')
    if os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
        raise ValueError('GOVERNANCE_WORKFLOW_EVENT_REQUIRED')
    if os.environ.get('GITHUB_REPOSITORY') != 'yannicklabuthie-code/ECTOS-Engineering':
        raise ValueError('WRONG_GOVERNANCE_REPOSITORY')
    if os.environ.get('GITHUB_REF_PROTECTED') != 'true':
        raise ValueError('GITHUB_REF_PROTECTION_NOT_PROVEN')
    # Declared confidence inside the candidate is necessary but never sufficient:
    # the independent host pin and every native tool-provenance receipt remain required.
    required_states = {
        'tool_trust_state': 'TRUSTED',
        'tool_currentness_state': 'CURRENT',
        'host_trust_state': 'TRUSTED',
        'tool_target_fit': 'PASS',
    }
    for tool in registry['tools']:
        control_id = tool['control_id']
        for field, expected in required_states.items():
            if tool.get(field) != expected:
                raise ValueError('QC03_TOOL_NOT_ATTESTED:' + control_id + ':' + field)
        for field in ('tool_sha256', 'script_sha256', 'tool_provenance_sha256'):
            value = tool.get(field)
            if not isinstance(value, str) or len(value) != 64 or any(c not in '0123456789abcdefABCDEF' for c in value):
                raise ValueError('QC03_TOOL_DIGEST_INVALID:' + control_id + ':' + field)
        if not tool.get('tool_provenance_ref') or not tool.get('host_id'):
            raise ValueError('QC03_TOOL_PROVENANCE_UNBOUND:' + control_id)
    # Validate the functional vs native-host execution profiles without conflating them.
    by_control = {t['control_id']: t for t in registry['tools']}
    for prop in contract['requirements']:
        for control_id in [prop['positive_control_id'], *prop['negative_control_ids']]:
            tool = by_control[control_id]
            for field in ('platform_profile', 'runtime_profile', 'qualification_profile', 'execution_profile'):
                if prop.get(field) != tool.get(field):
                    raise ValueError('QC02_QC03_PROFILE_MISMATCH:' + control_id + ':' + field)
    independent_path = pathlib.Path('authority_inputs/QC03_INDEPENDENT_PROVENANCE_ATTESTATIONS.json')
    independent_bytes = independent_path.read_bytes()
    if sha(independent_bytes) != required_env('APPROVED_QC03_ATTESTATION_SHA256').lower():
        raise ValueError('QC03_INDEPENDENT_ATTESTATION_BYTES_NOT_APPROVED')
    attest = read_strict(independent_path)
    revoked = json.loads(required_env('QC03_REVOKED_APPROVAL_IDS_JSON'))
    verify_independent_qc03_attestations(
        registry, attest,
        key_hex=required_env('QC03_INDEPENDENT_PUBLIC_KEY_HEX'),
        key_sha256=required_env('QC03_INDEPENDENT_PUBLIC_KEY_SHA256'),
        issuer_id=required_env('QC03_APPROVED_ISSUER_ID'),
        revoked_approval_ids=revoked,
        governance_key_sha256=required_env('APPROVED_PUBLIC_KEY_SHA256'))
    # The signature is produced only with a preexisting governance key held in a
    # protected GitHub environment. Never create keys or enroll trust here.
    key = Ed25519PrivateKey.from_private_bytes(base64.b64decode(required_env('OMNI_ED25519_KEY_SEED_B64'), validate=True))
    pub = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    if sha(pub) != required_env('APPROVED_PUBLIC_KEY_SHA256').lower():
        raise ValueError('GOVERNANCE_PUBLIC_PIN_NOT_MATCHED')
    now = datetime.datetime.now(datetime.timezone.utc)
    end = now + datetime.timedelta(days=3)
    issuer = required_env('GOVERNANCE_APPROVED_ISSUER_ID')
    actor = required_env('GITHUB_ACTOR')
    output.mkdir(exist_ok=False)
    for scope, subject in [('QC02_REQUIREMENT_CONTRACT_APPROVAL', contract), ('QC03_TOOL_REGISTRY_APPROVAL', registry)]:
        envelope = {
            'scope': scope,
            'subject_sha256': sha(canonical(subject)),
            'target_sha256': TARGET,
            'decision': 'APPROVED',
            'currentness': 'CURRENT',
            'approval_id': str(uuid.uuid4()),
            'not_before': now.isoformat(),
            'expires_at': end.isoformat(),
            'issuer_id': issuer,
            'workflow_actor': actor,
            'source_commit': required_env('GITHUB_SHA'),
        }
        signature = key.sign(DOMAIN + canonical(envelope))
        envelope['signature_b64'] = base64.b64encode(signature).decode('ascii')
        name = 'QC02_APPROVAL_ENVELOPE.json' if scope.startswith('QC02') else 'QC03_APPROVAL_ENVELOPE.json'
        (output / name).write_text(json.dumps(envelope, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    result = {
        'target_sha256': TARGET,
        'approved_source_sha256': sha(content),
        'approved_public_key_sha256': sha(pub),
        'issuer_id': issuer,
        'source_commit': required_env('GITHUB_SHA'),
        'workflow_actor': actor,
        'scope': 'EXTERNAL_GOVERNANCE_ISSUANCE_ONLY',
        'independent_qualification': 'NOT_PERFORMED',
        'native_qc02_qc03': 'NOT_PERFORMED',
        'admission': 'NOT_GRANTED',
        'cloud_mutation': 'NONE',
    }
    (output / 'ISSUANCE_RECEIPT.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    # Never print a key or signing secret.
    print(json.dumps({'issued_envelopes': 2, 'target_sha256': TARGET, 'status': 'SIGNED_BY_GOVERNANCE_WORKFLOW_NOT_NATIVE_QUALIFIED'}))

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(json.dumps({'status': 'DENIED', 'error': str(exc)}), file=sys.stderr)
        raise SystemExit(40)
