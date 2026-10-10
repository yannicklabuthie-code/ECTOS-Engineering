from __future__ import annotations
import base64, hashlib, importlib.util, json, os
from pathlib import Path
import tempfile, unittest, zipfile

ROUTE_PATH=Path(__file__).resolve().parents[1]/'route.py'
spec=importlib.util.spec_from_file_location('route',ROUTE_PATH); route=importlib.util.module_from_spec(spec); spec.loader.exec_module(route)

class Tests(unittest.TestCase):
    def setUp(self):
        self.td=tempfile.TemporaryDirectory(); self.r=Path(self.td.name)
        self.py=Path(os.sys.executable)
        self.ep=self.r/'ectos_run.py'; self.write_fake('ok')
        self.pkg=self.r/'V06.zip'
        with zipfile.ZipFile(self.pkg,'w') as z:z.writestr('fixture.txt','v06')
        self.m={'mission_id':'FIXTURE','successor_id':'FIXTURE','phases':[{'command':['python','-c','print(1)'],'working_directory':str(self.r),'env':{},'timeout_seconds':5,'required_artifacts':[]}]}
        self.mb=(json.dumps(self.m,sort_keys=True,separators=(',',':'))+'\n').encode()
        self.inv={'schema_id':'ECTOS_D10_V06_CATEGORY_C_INVOCATION_V01','successor_id':route.SUCCESSOR_ID,'invocation_id':'FIXTURE-001','repository':route.EXPECTED_REPOSITORY,'workflow_path':route.EXPECTED_WORKFLOW_PATH,'tooling_parent_commit':'a'*40,'runner_name':route.EXPECTED_RUNNER_NAME,'machine_name':route.EXPECTED_MACHINE_NAME,'python_path':str(self.py),'v06_package_path':str(self.pkg),'v06_package_sha256':route.sha256_file(self.pkg),'v06_entrypoint_path':str(self.ep),'mission_b64':base64.b64encode(self.mb).decode(),'mission_sha256':route.sha256_bytes(self.mb),'state_root':str(self.r/'state'),'run_root':str(self.r/'runs'),'work_root':str(self.r/'work'),'poll_interval_seconds':0.01,'overall_timeout_seconds':5}
        self.env={'GITHUB_REPOSITORY':route.EXPECTED_REPOSITORY,'RUNNER_NAME':route.EXPECTED_RUNNER_NAME,'COMPUTERNAME':route.EXPECTED_MACHINE_NAME}

    def write_fake(self,mode):
        code=f"""import hashlib,json,sys
from pathlib import Path
mode={mode!r}
a=sys.argv[1:]
cmd=a[0]
if cmd=='submit':
    mb=Path(a[1]).read_bytes(); rid='FIXTURE_RUN_001'
    if mode=='missing_run_id': print(json.dumps({{'mission_sha256':hashlib.sha256(mb).hexdigest().upper()}}))
    else: print(json.dumps({{'run_id':rid,'mission_sha256':hashlib.sha256(mb).hexdigest().upper(),'state':'SUBMITTED'}}))
elif cmd=='status':
    rid=a[1]; out={{'run_id':('STALE' if mode=='wrong_status' else rid),'state':'COMPLETED_PASS','final_state':('COMPLETED_FAIL' if mode=='status_mismatch' else 'COMPLETED_PASS')}}; print(json.dumps(out))
elif cmd=='result':
    rid=a[1]; out={{'run_id':('STALE' if mode=='wrong_result' else rid),'final_state':'COMPLETED_PASS'}}; print(json.dumps(out))
elif cmd=='download':
    rid=a[1]; d=Path(a[2]); d.mkdir(parents=True,exist_ok=True)
    if mode!='missing_artifact': (d/'artifact.txt').write_text('fixture',encoding='utf-8')
    print(json.dumps({{'run_id':rid,'downloaded':True}}))
else: sys.exit(9)
"""
        self.ep.write_text(code,encoding='utf-8')
    def tearDown(self): self.td.cleanup()
    def reject(self,fn,code):
        x=json.loads(json.dumps(self.inv)); fn(x)
        with self.assertRaises(route.RouteError) as cm: route.validate_invocation(x,self.env,True)
        self.assertIn(code,str(cm.exception))
    def test_01_valid(self): self.assertEqual(route.validate_invocation(self.inv,self.env,True),self.mb)
    def test_02_wrong_repo(self): self.reject(lambda x:x.__setitem__('repository','wrong/repo'),'WRONG_REPOSITORY_REJECTED')
    def test_03_wrong_workflow(self): self.reject(lambda x:x.__setitem__('workflow_path','wrong.yml'),'WRONG_WORKFLOW_REF_REJECTED')
    def test_04_wrong_runner(self): self.reject(lambda x:x.__setitem__('runner_name','BAD'),'WRONG_RUNNER_REJECTED')
    def test_05_wrong_machine(self): self.reject(lambda x:x.__setitem__('machine_name','BAD'),'WRONG_MACHINE_REJECTED')
    def test_05b_bad_parent_commit(self): self.reject(lambda x:x.__setitem__('tooling_parent_commit','BAD'),'TOOLING_PARENT_COMMIT_INVALID')
    def test_06_missing_pkg(self): self.reject(lambda x:x.pop('v06_package_path'),'V06_PACKAGE_PATH_MISSING')
    def test_07_missing_pkg_sha(self): self.reject(lambda x:x.pop('v06_package_sha256'),'V06_PACKAGE_SHA_MISSING')
    def test_08_missing_python(self): self.reject(lambda x:x.pop('python_path'),'PYTHON_PATH_MISSING')
    def test_09_missing_mission(self): self.reject(lambda x:x.pop('mission_b64'),'MISSION_BYTES_MISSING')
    def test_10_mission_sha(self): self.reject(lambda x:x.__setitem__('mission_sha256','0'*64),'MISSION_SHA_MISMATCH')
    def test_11_env_repo(self):
        with self.assertRaises(route.RouteError): route.validate_invocation(self.inv,dict(self.env,GITHUB_REPOSITORY='bad'),True)
    def test_12_env_runner(self):
        with self.assertRaises(route.RouteError): route.validate_invocation(self.inv,dict(self.env,RUNNER_NAME='bad'),True)
    def test_13_env_machine(self):
        with self.assertRaises(route.RouteError): route.validate_invocation(self.inv,dict(self.env,COMPUTERNAME='bad'),True)
    def test_13b_env_workflow(self):
        with self.assertRaises(route.RouteError): route.validate_invocation(self.inv,dict(self.env,GITHUB_WORKFLOW_REF='wrong.yml@refs/heads/x'),True)
    def test_14_unstructured_command(self):
        m=json.loads(json.dumps(self.m)); m['phases'][0]['command']='bad'; mb=(json.dumps(m,sort_keys=True,separators=(',',':'))+'\n').encode(); x=dict(self.inv,mission_b64=base64.b64encode(mb).decode(),mission_sha256=route.sha256_bytes(mb))
        with self.assertRaises(route.RouteError): route.validate_invocation(x,self.env,True)
    def test_15_bad_timeout(self):
        m=json.loads(json.dumps(self.m)); m['phases'][0]['timeout_seconds']=0; mb=(json.dumps(m,sort_keys=True,separators=(',',':'))+'\n').encode(); x=dict(self.inv,mission_b64=base64.b64encode(mb).decode(),mission_sha256=route.sha256_bytes(mb))
        with self.assertRaises(route.RouteError): route.validate_invocation(x,self.env,True)
    def test_16_duplicate_guard(self):
        p=self.r/'g.json'; route.guard_create(p,{'a':1})
        with self.assertRaises(route.RouteError) as cm: route.guard_create(p,{'a':2})
        self.assertIn('DUPLICATE_SUBMISSION_REJECTED',str(cm.exception))
    def test_17_missing_artifact(self):
        with self.assertRaises(route.RouteError): route.hash_tree(self.r/'none')
    def test_18_artifact_hash(self):
        d=self.r/'a'; d.mkdir(); (d/'x').write_bytes(b'abc'); rows=route.hash_tree(d); self.assertEqual(rows[0]['sha256'],hashlib.sha256(b'abc').hexdigest().upper())
    def test_19_json_stdout(self): self.assertEqual(route.parse_json_stdout('{"run_id":"R"}\n','X')['run_id'],'R')
    def test_20_non_json(self):
        with self.assertRaises(route.RouteError): route.parse_json_stdout('no','X')
    def test_21_timeout(self):
        with self.assertRaises(route.RouteError): route.runproc([os.sys.executable,'-c','import time;time.sleep(2)'],self.r,1)
    def test_22_nonzero(self):
        with self.assertRaises(route.RouteError): route.runproc([os.sys.executable,'-c','import sys;sys.exit(2)'],self.r,2)
    def test_23_no_dc_dependency(self):
        s=ROUTE_PATH.read_text(encoding='utf-8').lower(); self.assertNotIn('remote_desktop_commander',s); self.assertNotIn('desktop-commander',s)


    def execute_fixture(self,mode='ok',iid='FIXTURE-001'):
        self.write_fake(mode); x=dict(self.inv,invocation_id=iid); ip=self.r/(iid+'.json'); ip.write_text(json.dumps(x),encoding='utf-8'); return route.execute(ip,self.r/(iid+'-out'),env=dict(self.env,GITHUB_SHA='abc',GITHUB_RUN_ID='1',GITHUB_RUN_ATTEMPT='1',GITHUB_REF='refs/heads/test'),fixture=True)
    def test_24_e2e_fixture_success(self):
        ev=self.execute_fixture(); self.assertEqual(ev['run_id'],'FIXTURE_RUN_001'); self.assertEqual(ev['submit_count'],1); self.assertEqual(ev['desktop_commander_dependency_count'],0)
    def test_25_missing_v06_file(self):
        x=dict(self.inv,v06_package_path=str(self.r/'none.zip'),invocation_id='MISS-PKG'); ip=self.r/'miss.json'; ip.write_text(json.dumps(x),encoding='utf-8')
        with self.assertRaises(route.RouteError) as cm: route.execute(ip,self.r/'o',env=self.env,fixture=True)
        self.assertIn('MISSING_V06_REJECTED',str(cm.exception))
    def test_26_wrong_v06_sha(self):
        x=dict(self.inv,v06_package_sha256='0'*64,invocation_id='BAD-SHA'); ip=self.r/'badsha.json'; ip.write_text(json.dumps(x),encoding='utf-8')
        with self.assertRaises(route.RouteError) as cm: route.execute(ip,self.r/'o2',env=self.env,fixture=True)
        self.assertIn('WRONG_V06_SHA_REJECTED',str(cm.exception))
    def test_27_missing_run_id(self):
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('missing_run_id','MISS-RUN')
        self.assertIn('MISSING_RUN_ID_REJECTED',str(cm.exception))
    def test_28_wrong_status_run_id(self):
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('wrong_status','BAD-STATUS')
        self.assertIn('WRONG_RUN_ID_STATUS_REJECTED',str(cm.exception))
    def test_29_wrong_result_run_id(self):
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('wrong_result','BAD-RESULT')
        self.assertIn('WRONG_RUN_ID_RESULT_REJECTED',str(cm.exception))
    def test_30_status_result_mismatch(self):
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('status_mismatch','MISMATCH')
        self.assertIn('STATUS_RESULT_MISMATCH_REJECTED',str(cm.exception))
    def test_31_missing_artifact(self):
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('missing_artifact','NO-ART')
        self.assertIn('MISSING_ARTIFACT_REJECTED',str(cm.exception))
    def test_32_duplicate_execution_rejected(self):
        self.execute_fixture('ok','DUP')
        with self.assertRaises(route.RouteError) as cm: self.execute_fixture('ok','DUP')
        self.assertIn('DUPLICATE_SUBMISSION_REJECTED',str(cm.exception))

if __name__=='__main__':unittest.main()
