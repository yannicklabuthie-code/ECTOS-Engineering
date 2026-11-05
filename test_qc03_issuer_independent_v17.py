import unittest,importlib.util,os,datetime,base64,json,copy,hashlib
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
TARGET='27e816c70d428fd2feec2e1fc71cd77d9cb1731b4a454fb9abd4f0a3b45c57cf'
os.environ['GOVERNANCE_APPROVED_TARGET_SHA256']=TARGET
P=Path(__file__).parent/'governance/omnigate/issue_authority_universal_candidate.py'
spec=importlib.util.spec_from_file_location('issuer',P)
issuer=importlib.util.module_from_spec(spec);spec.loader.exec_module(issuer)
class QC03SignedProvenanceTest(unittest.TestCase):
 def setUp(self):
  self.private=Ed25519PrivateKey.generate()
  self.public=self.private.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw)
  self.public_hex=self.public.hex();self.pin=hashlib.sha256(self.public).hexdigest()
  self.supplier=[{'control_id':f'C{i}','tool_sha256':'a'*64,'script_sha256':'b'*64,
   'tool_provenance_sha256':'c'*64,'tool_provenance_ref':f'C:/receipt/{i}.json','host_id':'SUCCEESMINDSET'}
   for i in range(22)]
  self.reg={'target_package_sha256':TARGET,'tools':self.supplier}
  now=datetime.datetime.now(datetime.timezone.utc)
  self.att={'schema':'ECTOS_QC03_INDEPENDENT_PROVENANCE_V01','target_sha256':TARGET,
   'issuer_id':'INDEPENDENT_QC03_SIGNER','issuer_role':'QC03_INDEPENDENT_PROVENANCE_AUTHORITY',
   'approval_id':'APPROVAL-TEST-EPHEMERAL-01','not_before':(now-datetime.timedelta(minutes=1)).isoformat(),
   'expires_at':(now+datetime.timedelta(minutes=5)).isoformat(),'decision':'APPROVED',
   'tools':[{**x,'decision':'APPROVED'} for x in self.supplier]}
  self.sign()
 def sign(self):
  b=issuer.QC03_DOMAIN+issuer.canonical(self.att)
  self.att['signature_b64']=base64.b64encode(self.private.sign(b)).decode()
 def validate(self,att=None,**opts):
  kw={'key_hex':self.public_hex,'key_sha256':self.pin,
   'issuer_id':'INDEPENDENT_QC03_SIGNER','revoked_approval_ids':[],
   'governance_key_sha256':'d'*64}
  kw.update(opts)
  return issuer.verify_independent_qc03_attestations(self.reg,att or self.att,**kw)
 def assertDenied(self,reason,mutate=None,**opts):
  att=copy.deepcopy(self.att)
  if mutate:mutate(att)
  with self.assertRaisesRegex(ValueError,reason):self.validate(att,**opts)
 def test_valid_22_independent_signatures_accepted_in_test_only(self):
  self.assertTrue(self.validate())
 def test_signature_tampering_denied(self):
  self.assertDenied('SIGNATURE_INVALID',lambda x:x.update(approval_id='TAMPERED'))
 def test_wrong_tool_binding_denied_even_when_resigned(self):
  self.att['tools'][0]['tool_provenance_sha256']='f'*64;self.sign()
  with self.assertRaisesRegex(ValueError,'BINDING_MISMATCH'):self.validate()
 def test_missing_control_denied(self):
  self.assertDenied('COUNT',lambda x:x['tools'].pop())
 def test_duplicate_control_denied(self):
  self.assertDenied('DUPLICATE',lambda x:x['tools'][1].update(control_id='C0'))
 def test_revoked_approval_denied(self):
  self.assertDenied('REVOKED',None,revoked_approval_ids=['APPROVAL-TEST-EPHEMERAL-01'])
 def test_colliding_public_key_denied(self):
  self.assertDenied('PIN_INVALID_OR_COLLIDING',None,governance_key_sha256=self.pin)
 def test_wrong_issuer_denied(self):
  self.assertDenied('ISSUER_NOT_DISTINCT',None,issuer_id='GOVERNANCE_ISSUER')
 def test_outside_time_denied(self):
  self.att['expires_at']=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=1)).isoformat();self.sign()
  with self.assertRaisesRegex(ValueError,'OUT_OF_TIME_WINDOW'):self.validate()
 def test_global_decision_denied(self):
  self.att['decision']='DENIED';self.sign()
  with self.assertRaisesRegex(ValueError,'DECISION_NOT_APPROVED'):self.validate()
 def test_bad_role_denied(self):
  self.att['issuer_role']='ENGINEERING_PRODUCER';self.sign()
  with self.assertRaisesRegex(ValueError,'ISSUER_ROLE_INVALID'):self.validate()
 def test_wrong_target_denied(self):
  self.att['target_sha256']='f'*64;self.sign()
  with self.assertRaisesRegex(ValueError,'TARGET_MISMATCH'):self.validate()
 def test_malformed_signature_denied(self):
  self.assertDenied('SIGNATURE_INVALID',lambda x:x.update(signature_b64='invalid!'))
if __name__=='__main__':unittest.main(verbosity=2)
