import json
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from github_governance import validate_ruleset
from uac_core import UACDenied

CONTRACT=json.loads((ROOT/'config/github_governance_contract.json').read_text(encoding='utf-8'))

def good_ruleset():
    return {
      'id':22774725,'name':'Main','target':'branch','enforcement':'active',
      'conditions':{'ref_name':{'include':['~DEFAULT_BRANCH'],'exclude':[]}},
      'bypass_actors':[],'current_user_can_bypass':'never',
      'rules':[
        {'type':'pull_request','parameters':{}},
        {'type':'required_status_checks','parameters':{'strict_required_status_checks_policy':True,'required_status_checks':[{'context':'ectos/ci-required-checks','integration_id':15368}]}},
        {'type':'non_fast_forward'}, {'type':'deletion'}
      ]
    }

class TestGithubGovernance(unittest.TestCase):
    def test_expected_ruleset_passes(self):
        a=validate_ruleset(good_ruleset(), CONTRACT)
        self.assertEqual(a['decision'],'PASS')
        self.assertEqual(len(a['attestation_sha256']),64)
    def test_bypass_actor_rejected(self):
        r=good_ruleset(); r['bypass_actors']=[{'actor_id':1}]
        with self.assertRaises(UACDenied): validate_ruleset(r, CONTRACT)
    def test_required_check_missing_rejected(self):
        r=good_ruleset(); r['rules'][1]['parameters']['required_status_checks']=[]
        with self.assertRaises(UACDenied): validate_ruleset(r, CONTRACT)
    def test_non_strict_rejected(self):
        r=good_ruleset(); r['rules'][1]['parameters']['strict_required_status_checks_policy']=False
        with self.assertRaises(UACDenied): validate_ruleset(r, CONTRACT)

    def test_missing_user_specific_bypass_field_is_allowed(self):
        r=good_ruleset(); r.pop('current_user_can_bypass',None)
        self.assertEqual(validate_ruleset(r, CONTRACT)['decision'],'PASS')
    def test_explicit_user_bypass_is_rejected(self):
        r=good_ruleset(); r['current_user_can_bypass']='always'
        with self.assertRaises(UACDenied): validate_ruleset(r, CONTRACT)

    def test_inactive_ruleset_rejected(self):
        r=good_ruleset(); r['enforcement']='disabled'
        with self.assertRaises(UACDenied): validate_ruleset(r, CONTRACT)

if __name__=='__main__': unittest.main()
