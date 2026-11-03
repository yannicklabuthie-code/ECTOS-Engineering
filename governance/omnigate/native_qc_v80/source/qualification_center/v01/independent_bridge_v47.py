"""Candidate QC06 receipt authentication protocol; never creates a trust root or runs tests.
Deployment of its external policy is a separate governance decision. A producer
fixture is never evidence of organizational independence or actual qualification.
"""
import argparse,json,pathlib,sys,re
from datetime import datetime,timezone
from authority_bridge_v46 import strict_json,current_window
from strict_authority_gate import canonical,digest
DOMAIN=b'ECTOS-OMNIGATE-QC06-INDEPENDENT-REPORT-V47\n'
HOST_POLICY=pathlib.Path(r'C:\ProgramData\ECTOS\governance\omni_independent_policy.json') if sys.platform=='win32' else pathlib.Path('/etc/ectos/governance/omni_independent_policy.json')

def verify(report_path,envelope_path,expected_path,evidence_directory,policy_path=None):
    errors=[]
    try:
        report=strict_json(pathlib.Path(report_path).read_bytes());env=strict_json(pathlib.Path(envelope_path).read_bytes())
        expected=strict_json(pathlib.Path(expected_path).read_bytes())
        policy=strict_json(pathlib.Path(policy_path or HOST_POLICY).read_bytes())
        if policy.get('policy_scope')!='ECTOS_OMNIGATE_QC06_REPORT_V47' or policy.get('governance_state')!='OWNER_PROVISIONED':errors.append('INDEPENDENT_POLICY_NOT_APPROVED')
        pub=bytes.fromhex(policy.get('public_key_hex',''))
        if len(pub)!=32 or digest(pub)!=policy.get('independently_approved_public_key_sha256'):errors.append('INDEPENDENT_KEY_NOT_PINNED')
        now=datetime.now(timezone.utc)
        if not current_window(policy,now) or not current_window(env,now):errors.append('INDEPENDENT_APPROVAL_NOT_CURRENT')
        revoked=policy.get('revoked_approval_ids');approval=env.get('approval_id')
        if not isinstance(revoked,list) or not isinstance(approval,str) or not approval or approval in revoked:errors.append('REVOCATION_NOT_CLOSED')
        if env.get('scope')!='QC06_INDEPENDENT_REPORT_APPROVAL' or env.get('decision')!='APPROVED' or env.get('currentness')!='CURRENT':errors.append('INDEPENDENT_APPROVAL_SCOPE_INVALID')
        if env.get('subject_sha256')!=digest(canonical(report)):errors.append('INDEPENDENT_REPORT_BYTES_MISMATCH')
        if env.get('bindings')!=expected['bindings']:errors.append('INDEPENDENT_CHAIN_BINDING_MISMATCH')
        producer=policy.get('producer_identity');qualifier=policy.get('qualifier_identity')
        if not isinstance(producer,str) or not producer or not isinstance(qualifier,str) or not qualifier or producer==qualifier or report.get('qualifier_id')!=qualifier or env.get('producer_identity')!=producer:errors.append('INDEPENDENT_ACTOR_NOT_DISTINCT')
        for field in ('target_package_id','target_package_sha256','qualifier_sha256','qualification_contract_id'):
            if report.get(field)!=expected['report_bindings'].get(field):errors.append('INDEPENDENT_REPORT_BINDING_MISMATCH|'+field)
        for field in ('organizational_independence','logic_independence','data_independence','oracle_independence'):
            if report.get(field)!='PASS':errors.append('INDEPENDENCE_NOT_PROVEN|'+field)
        # Exact property/control coverage and signed references to separate raw evidence.
        if not policy.get('qualifier_trust_scope_id') or report.get('qualifier_trust_scope_id')!=policy.get('qualifier_trust_scope_id'):errors.append('INDEPENDENT_TRUST_SCOPE_MISMATCH')
        observed=[];all_pass=True;properties=[]
        for prop in report.get('independent_property_results',[]):
            properties.append(prop['property_id'])
            if prop.get('result') not in ('PASS','FAIL'):errors.append('PROPERTY_RESULT_INVALID')
            if report.get('final_state')=='PASS' and prop.get('result')!='PASS':errors.append('PROPERTY_PASS_CONTRADICTION')
            for row in prop.get('controls',[]):
                observed.append([prop['property_id'],row['control_id']])
                if type(row.get('pass')) is not bool:errors.append('CONTROL_RESULT_INVALID')
                all_pass=all_pass and row.get('pass') is True
        if len(set(properties))!=len(properties):errors.append('DUPLICATE_INDEPENDENT_PROPERTY')
        if sorted(observed)!=sorted(expected['control_keys']) or len({tuple(x) for x in observed})!=len(observed):errors.append('INDEPENDENT_CONTROL_SET_MISMATCH')
        rows=env.get('evidence',[]);keys=[]
        for row in rows:
            key=[row['property_id'],row['control_id']];keys.append(key)
            name=row.get('file_name','')
            if not isinstance(name,str) or not re.fullmatch(r'[A-Za-z0-9_-]+\.json',name):errors.append('UNSAFE_INDEPENDENT_EVIDENCE_PATH');continue
            raw=(pathlib.Path(evidence_directory)/name).read_bytes()
            if digest(raw)!=row.get('sha256'):errors.append('INDEPENDENT_RAW_EVIDENCE_MISMATCH')
            if row.get('origin')!='INDEPENDENT_QUALIFIER' or row.get('producer_receipt_reused') is not False:errors.append('PRODUCER_EVIDENCE_REUSE')
            if row.get('sha256') in expected['producer_receipt_sha256']:errors.append('PRODUCER_EVIDENCE_BYTES_REUSED')
        if sorted(keys)!=sorted(expected['control_keys']) or len({tuple(x) for x in keys})!=len(keys):errors.append('INDEPENDENT_EVIDENCE_SET_MISMATCH')
        if not report.get('independent_run_ledger'):errors.append('INDEPENDENT_RUN_LEDGER_MISSING')
        if report.get('final_state')=='PASS':
            if not all_pass or report.get('new_defects') or report.get('confirmed_defects') or report.get('qualification_process_defects') or report.get('independence_risk_register'):errors.append('INDEPENDENT_PASS_CONTRADICTS_DEFECTS')
            for f in ('objective_match','architectural_intent_match','invariant_match','prohibited_behavior_absence'):
                if report.get(f)!='PASS':errors.append('INDEPENDENT_PASS_CLAIM_INCOMPLETE')
            for f in ('constraint_relocation','architectural_substitution'):
                if report.get(f)!='NO':errors.append('INDEPENDENT_PASS_ARCHITECTURE_UNPROVEN')
        if not errors:
            import base64
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
            Ed25519PublicKey.from_public_bytes(pub).verify(base64.b64decode(env['signature_b64'],validate=True),DOMAIN+canonical({k:v for k,v in env.items() if k!='signature_b64'}))
    except ImportError:errors.append('INDEPENDENT_CRYPTO_RUNTIME_UNAVAILABLE')
    except Exception:errors.append('INDEPENDENT_RECEIPT_INVALID_OR_UNAVAILABLE')
    return {'status':'VERIFIED_EXTERNAL_REPORT_ONLY' if not errors else 'BLOCKED','defects':sorted(set(errors)),'main_admission':'NOT_GRANTED'}

def main():
    p=argparse.ArgumentParser()
    for x in ('report','envelope','expected','evidence_directory','output'):p.add_argument('--'+x.replace('_','-'),required=True)
    a=p.parse_args();r=verify(a.report,a.envelope,a.expected,a.evidence_directory);pathlib.Path(a.output).write_text(json.dumps(r,indent=2)+'\n');return 0 if not r['defects'] else 50
if __name__=='__main__':sys.exit(main())
