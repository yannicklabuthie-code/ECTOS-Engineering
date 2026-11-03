#!/usr/bin/env python3
"""QC02/QC03 native trust bridge. No self-pinning. No release authority.

A trust policy MUST be provisioned independently at the fixed host policy path.
This executable does not create, write or enroll an authority policy.
"""
import argparse,hashlib,json,pathlib,sys,re
from datetime import datetime,timezone
from strict_authority_gate import verify_authority,canonical,digest
HOST_POLICY=pathlib.Path(r'C:\ProgramData\ECTOS\governance\omni_trust_policy.json') if sys.platform=='win32' else pathlib.Path('/etc/ectos/governance/omni_trust_policy.json')

def strict_json(data):
    def unique(pairs):
        out={}
        for k,v in pairs:
            if k in out: raise ValueError('duplicate JSON key')
            out[k]=v
        return out
    result=json.loads(data,object_pairs_hook=unique,parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
    if not isinstance(result,dict): raise ValueError('JSON object required')
    return result

def current_window(obj,now):
    try:
        start=datetime.fromisoformat(obj['not_before'].replace('Z','+00:00'))
        end=datetime.fromisoformat(obj['expires_at'].replace('Z','+00:00'))
        return start.tzinfo is not None and end.tzinfo is not None and start <= now < end
    except (ValueError,TypeError,KeyError,AttributeError): return False

def _verify(mode,subject_path,envelope_path,source_path=None,policy_path=None):
    defects=[]
    # Policy path is fixed in production; override exists only for injected unit tests.
    policy_path=policy_path if policy_path is not None else HOST_POLICY
    try:
        subject=pathlib.Path(subject_path).read_bytes(); obj=strict_json(subject)
    except Exception: return ['SUBJECT_UNAVAILABLE_OR_INVALID']
    try: envelope=strict_json(pathlib.Path(envelope_path).read_bytes()) if envelope_path else {}
    except Exception: envelope={};defects.append('SIGNATURE_ENVELOPE_UNREADABLE')
    try: policy=strict_json(pathlib.Path(policy_path).read_bytes())
    except Exception: policy={};defects.append('INDEPENDENT_HOST_TRUST_POLICY_UNAVAILABLE')
    # Host policy must be provisioned by governance. No candidate-provided pin is accepted.
    keyhex=policy.get('public_key_hex','')
    try:key=bytes.fromhex(keyhex)
    except Exception:key=None
    pin=policy.get('independently_approved_public_key_sha256')
    if policy.get('governance_state')!='OWNER_PROVISIONED' or policy.get('policy_scope')!='ECTOS_OMNIGATE_QC02_QC03':
        defects.append('HOST_POLICY_NOT_OWNER_PROVISIONED')
    try:source=pathlib.Path(source_path).read_bytes() if source_path else None
    except Exception:source=None
    scope='QC02_REQUIREMENT_CONTRACT_APPROVAL' if mode=='qc02' else 'QC03_TOOL_REGISTRY_APPROVAL'
    now=datetime.now(timezone.utc)
    if not current_window(policy,now): defects.append('HOST_POLICY_TIME_WINDOW_NOT_PROVEN')
    if not current_window(envelope,now): defects.append('APPROVAL_TIME_WINDOW_NOT_PROVEN')
    revoked=policy.get('revoked_approval_ids')
    approval=envelope.get('approval_id')
    if not isinstance(revoked,list) or not all(isinstance(x,str) and x for x in revoked): defects.append('REVOCATION_POLICY_NOT_PROVEN')
    elif not isinstance(approval,str) or not approval or approval in revoked: defects.append('APPROVAL_MISSING_OR_REVOKED')
    target=obj.get('target_package_sha256','')
    if not isinstance(target,str) or not re.fullmatch('[a-f0-9]{64}',target): defects.append('TARGET_DIGEST_INVALID')
    if mode=='qc03':
        # tool registry must have distinct nonempty controls; signed digest and native QC03 bind them
        tools=obj.get('tools',[])
        if not isinstance(tools,list) or len(tools)<1 or any(not isinstance(x,dict) or not x.get('control_id') for x in tools) or len({x.get('control_id') for x in tools})!=len(tools): defects.append('QC03_CONTROL_UNIVERSE_INVALID')
        # Strict tool provenance and byte checks remain mandatory in native QC03.
    defects+=verify_authority(envelope=envelope,subject=canonical(obj),subject_object=obj,
        target_digest=target,expected_scope=scope,public_key=key,
        independently_pinned_public_key_digest=pin,approved_source=source,
        source_digest=obj.get('requirement_source_sha256'))
    return sorted(set(defects))

def verify(mode,subject_path,envelope_path,source_path=None,policy_path=None):
    try:
        if mode not in ('qc02','qc03'):
            return ['UNSUPPORTED_AUTHORITY_SCOPE']
        return _verify(mode,subject_path,envelope_path,source_path,policy_path)
    except (ValueError,TypeError,AttributeError,KeyError,OSError):
        return ['MALFORMED_AUTHORITY_INPUT_DENIED']

def main():
    p=argparse.ArgumentParser();p.add_argument('--mode',choices=['qc02','qc03'],required=True)
    p.add_argument('--subject',required=True);p.add_argument('--envelope');p.add_argument('--source');p.add_argument('--output',required=True)
    a=p.parse_args();failures=verify(a.mode,a.subject,a.envelope,a.source)
    out={'schema':'OMNIGATE_V46_EXTERNAL_AUTHORITY_NATIVE_PREFLIGHT','mode':a.mode,
       'status':'BLOCKED' if failures else 'VERIFIED_FOR_NATIVE_STAGE_ONLY',
       'defects':failures,'independent_qualification':'NOT_PERFORMED','main_admission':'NOT_GRANTED'}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2),encoding='utf-8')
    print(out['status'],';'.join(failures))
    return 40 if failures else 0
if __name__=='__main__':sys.exit(main())
