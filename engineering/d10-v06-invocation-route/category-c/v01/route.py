from __future__ import annotations
import argparse, base64, hashlib, json, os, subprocess, sys, time
from pathlib import Path
from typing import Any

SUCCESSOR_ID='ECTOS_D10_V06_INVOCATION_ROUTE_CATEGORY_C_V01'
EXPECTED_REPOSITORY='yannicklabuthie-code/ECTOS-Engineering'
EXPECTED_WORKFLOW_PATH='.github/workflows/ectos-d10-v06-invocation-route-category-c-v01.yml'
EXPECTED_RUNNER_NAME='SUCCEESMINDSET-ECTOS-PS51'
EXPECTED_MACHINE_NAME='SUCCEESMINDSET'
EXPECTED_PYTHON=r'C:\Python314\python.exe'
EXPECTED_V06_PACKAGE=r'C:\dev\ECTOS_EXTERNAL_DURABLE_EXECUTION_MVP_V06\ECTOS_EXTERNAL_DURABLE_EXECUTION_MVP_V06.zip'
EXPECTED_V06_SHA256='FC17DA9201994A7544263804DF4892DCFB826BBB21F37FBF8D5BDB6D38F84C23'
EXPECTED_V06_ENTRYPOINT=r'C:\dev\ECTOS_EXTERNAL_DURABLE_EXECUTION_MVP_V06\ectos_run.py'
DEFAULT_STATE_ROOT=r'C:\dev\ECTOS_V06_CATEGORY_C_STATE'
DEFAULT_RUN_ROOT=r'C:\dev\ECTOS_V06_CATEGORY_C_RUNS'
TERMINAL={'COMPLETED_PASS','COMPLETED_FAIL','FAILED','CANCELED','BLOCKED','FAILED_SYSTEMIC'}

class RouteError(RuntimeError): pass

def sha256_bytes(b:bytes)->str: return hashlib.sha256(b).hexdigest().upper()
def sha256_file(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest().upper()
def canonical(v:Any)->bytes: return (json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False)+'\n').encode()
def load_obj(b:bytes,label:str)->dict[str,Any]:
    try: v=json.loads(b.decode('utf-8'))
    except Exception as e: raise RouteError(label+'_JSON_INVALID') from e
    if not isinstance(v,dict): raise RouteError(label+'_OBJECT_REQUIRED')
    return v
def req(v:Any,code:str)->Any:
    if v is None or v=='' or v==[]: raise RouteError(code)
    return v

def validate_mission(mb:bytes,expected:str)->dict[str,Any]:
    if sha256_bytes(mb)!=expected.upper(): raise RouteError('MISSION_SHA_MISMATCH')
    m=load_obj(mb,'MISSION')
    for k in ('mission_id','successor_id','phases'): req(m.get(k),'MISSION_FIELD_MISSING:'+k)
    if not isinstance(m['phases'],list) or not m['phases']: raise RouteError('MISSION_PHASES_INVALID')
    for i,p in enumerate(m['phases']):
        if not isinstance(p,dict): raise RouteError(f'MISSION_PHASE_INVALID:{i}')
        for k in ('command','working_directory','timeout_seconds'): req(p.get(k),f'MISSION_PHASE_FIELD_MISSING:{i}:{k}')
        if not isinstance(p['command'],list) or not p['command']: raise RouteError(f'MISSION_COMMAND_NOT_STRUCTURED:{i}')
        if not isinstance(p['timeout_seconds'],int) or p['timeout_seconds']<=0: raise RouteError(f'MISSION_TIMEOUT_INVALID:{i}')
    return m

def validate_invocation(inv:dict[str,Any],env:dict[str,str],fixture=False)->bytes:
    if inv.get('schema_id')!='ECTOS_D10_V06_CATEGORY_C_INVOCATION_V01': raise RouteError('INVOCATION_SCHEMA_INVALID')
    if inv.get('successor_id')!=SUCCESSOR_ID: raise RouteError('SUCCESSOR_ID_MISMATCH')
    if inv.get('repository')!=EXPECTED_REPOSITORY: raise RouteError('WRONG_REPOSITORY_REJECTED')
    if inv.get('workflow_path')!=EXPECTED_WORKFLOW_PATH: raise RouteError('WRONG_WORKFLOW_REF_REJECTED')
    if inv.get('runner_name')!=EXPECTED_RUNNER_NAME: raise RouteError('WRONG_RUNNER_REJECTED')
    if inv.get('machine_name')!=EXPECTED_MACHINE_NAME: raise RouteError('WRONG_MACHINE_REJECTED')
    if env.get('GITHUB_REPOSITORY') and env['GITHUB_REPOSITORY']!=EXPECTED_REPOSITORY: raise RouteError('GITHUB_REPOSITORY_CONTEXT_MISMATCH')
    if env.get('GITHUB_WORKFLOW_REF') and EXPECTED_WORKFLOW_PATH not in env['GITHUB_WORKFLOW_REF']: raise RouteError('GITHUB_WORKFLOW_REF_CONTEXT_MISMATCH')
    if env.get('RUNNER_NAME') and env['RUNNER_NAME']!=EXPECTED_RUNNER_NAME: raise RouteError('RUNNER_CONTEXT_MISMATCH')
    if env.get('COMPUTERNAME') and env['COMPUTERNAME']!=EXPECTED_MACHINE_NAME: raise RouteError('MACHINE_CONTEXT_MISMATCH')
    tooling_parent=str(req(inv.get('tooling_parent_commit'),'TOOLING_PARENT_COMMIT_MISSING'))
    if len(tooling_parent)!=40 or any(c not in '0123456789abcdefABCDEF' for c in tooling_parent): raise RouteError('TOOLING_PARENT_COMMIT_INVALID')
    package=str(req(inv.get('v06_package_path'),'V06_PACKAGE_PATH_MISSING'))
    psha=str(req(inv.get('v06_package_sha256'),'V06_PACKAGE_SHA_MISSING')).upper()
    py=str(req(inv.get('python_path'),'PYTHON_PATH_MISSING'))
    ep=str(req(inv.get('v06_entrypoint_path'),'V06_ENTRYPOINT_MISSING'))
    if not fixture:
        repo_root=Path(__file__).resolve().parents[4]
        if env.get('GITHUB_ACTIONS','').lower()=='true':
            cp=subprocess.run(['git','-C',str(repo_root),'rev-parse','HEAD^'],capture_output=True,text=True,timeout=15,shell=False)
            if cp.returncode!=0 or cp.stdout.strip().lower()!=tooling_parent.lower(): raise RouteError('TOOLING_PARENT_COMMIT_MISMATCH')
        if package.lower()!=EXPECTED_V06_PACKAGE.lower(): raise RouteError('V06_PACKAGE_PATH_MISMATCH')
        if psha!=EXPECTED_V06_SHA256: raise RouteError('WRONG_V06_SHA_REJECTED')
        if py.lower()!=EXPECTED_PYTHON.lower(): raise RouteError('WRONG_PYTHON_REJECTED')
        if ep.lower()!=EXPECTED_V06_ENTRYPOINT.lower(): raise RouteError('V06_ENTRYPOINT_PATH_MISMATCH')
    raw_mission=str(req(inv.get('mission_b64'),'MISSION_BYTES_MISSING'))
    try: mb=base64.b64decode(raw_mission,validate=True)
    except Exception as e: raise RouteError('MISSION_BASE64_INVALID') from e
    validate_mission(mb,str(req(inv.get('mission_sha256'),'MISSION_SHA_MISSING')).upper())
    return mb

def runproc(args:list[str],cwd:Path,timeout:int)->dict[str,Any]:
    started=time.time()
    try: cp=subprocess.run(args,cwd=str(cwd),stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=timeout,shell=False)
    except subprocess.TimeoutExpired as e: raise RouteError('TIMEOUT_REJECTED') from e
    rec={'args':args,'working_directory':str(cwd),'started_epoch':started,'ended_epoch':time.time(),'exit_code':cp.returncode,'stdout':cp.stdout,'stderr':cp.stderr}
    if cp.returncode!=0: raise RouteError('NONZERO_EXIT_REJECTED:'+json.dumps(rec,sort_keys=True))
    return rec

def parse_json_stdout(s:str,label:str)->dict[str,Any]:
    for line in reversed([x.strip() for x in s.splitlines() if x.strip()]):
        try:
            v=json.loads(line)
            if isinstance(v,dict): return v
        except Exception: pass
    try:
        v=json.loads(s)
        if isinstance(v,dict): return v
    except Exception: pass
    raise RouteError(label+'_JSON_NOT_FOUND')

def guard_create(p:Path,payload:dict[str,Any])->None:
    p.parent.mkdir(parents=True,exist_ok=True)
    try: fd=os.open(str(p),os.O_WRONLY|os.O_CREAT|os.O_EXCL)
    except FileExistsError as e: raise RouteError('DUPLICATE_SUBMISSION_REJECTED') from e
    with os.fdopen(fd,'wb') as f: f.write(canonical(payload)); f.flush(); os.fsync(f.fileno())
def guard_update(p:Path,payload:dict[str,Any])->None:
    t=p.with_suffix(p.suffix+'.tmp'); t.write_bytes(canonical(payload)); os.replace(str(t),str(p))
def hash_tree(root:Path)->list[dict[str,Any]]:
    if not root.exists(): raise RouteError('MISSING_ARTIFACT_REJECTED')
    rows=[{'path':p.relative_to(root).as_posix(),'size':p.stat().st_size,'sha256':sha256_file(p)} for p in sorted(x for x in root.rglob('*') if x.is_file())]
    if not rows: raise RouteError('MISSING_ARTIFACT_REJECTED')
    return rows

def execute(invocation_path:Path,output:Path,env:dict[str,str]|None=None,fixture=False)->dict[str,Any]:
    env=dict(os.environ if env is None else env); ib=invocation_path.read_bytes(); inv=load_obj(ib,'INVOCATION'); mb=validate_invocation(inv,env,fixture)
    package=Path(inv['v06_package_path']); ep=Path(inv['v06_entrypoint_path']); py=Path(inv['python_path'])
    if not package.is_file(): raise RouteError('MISSING_V06_REJECTED')
    if sha256_file(package)!=inv['v06_package_sha256'].upper(): raise RouteError('WRONG_V06_SHA_REJECTED')
    if not ep.is_file(): raise RouteError('V06_ENTRYPOINT_MISSING')
    if not py.is_file(): raise RouteError('WRONG_PYTHON_REJECTED')
    iid=str(req(inv.get('invocation_id'),'INVOCATION_ID_MISSING')); sid=''.join(c if c.isalnum() or c in '-_.' else '_' for c in iid)
    state=Path(inv.get('state_root') or DEFAULT_STATE_ROOT); runroot=Path(inv.get('run_root') or DEFAULT_RUN_ROOT); work=Path(inv.get('work_root') or (Path(env.get('RUNNER_TEMP') or output)/('ectos-category-c-'+sid)))
    work.mkdir(parents=True,exist_ok=True); output.mkdir(parents=True,exist_ok=True); mp=work/'mission.json'; mp.write_bytes(mb)
    if sha256_file(mp)!=inv['mission_sha256'].upper(): raise RouteError('MUTATED_MISSION_REJECTED')
    gp=state/(sid+'.json'); g={'schema_id':'ECTOS_D10_V06_CATEGORY_C_SUBMISSION_GUARD_V01','invocation_id':iid,'invocation_sha256':sha256_bytes(ib),'mission_sha256':inv['mission_sha256'].upper(),'github_sha':env.get('GITHUB_SHA'),'github_run_id':env.get('GITHUB_RUN_ID'),'tooling_parent_commit':inv['tooling_parent_commit'],'state':'PRE_SUBMIT_LOCKED','run_id':None}
    guard_create(gp,g); recs=[]
    try:
        r=runproc([str(py),str(ep),'submit',str(mp),'--root',str(runroot)],ep.parent,int(inv.get('submit_timeout_seconds',60))); recs.append({'operation':'submit',**r}); sj=parse_json_stdout(r['stdout'],'SUBMIT'); rid=str(req(sj.get('run_id'),'MISSING_RUN_ID_REJECTED'))
        if str(req(sj.get('mission_sha256'),'SUBMIT_MISSION_SHA_MISSING')).upper()!=inv['mission_sha256'].upper(): raise RouteError('MISSION_SHA_MISMATCH_REJECTED')
        g['state']='SUBMITTED'; g['run_id']=rid; guard_update(gp,g)
        deadline=time.time()+int(inv.get('overall_timeout_seconds',900)); status=None
        while True:
            if time.time()>deadline: raise RouteError('TIMEOUT_REJECTED:OVERALL')
            rr=runproc([str(py),str(ep),'status',rid,'--root',str(runroot)],ep.parent,int(inv.get('status_timeout_seconds',30))); recs.append({'operation':'status',**rr}); status=parse_json_stdout(rr['stdout'],'STATUS')
            if status.get('run_id') not in (None,rid): raise RouteError('WRONG_RUN_ID_STATUS_REJECTED')
            if status.get('final_state') or str(status.get('state') or '') in TERMINAL: break
            time.sleep(float(inv.get('poll_interval_seconds',2)))
        rr=runproc([str(py),str(ep),'result',rid,'--root',str(runroot)],ep.parent,int(inv.get('result_timeout_seconds',30))); recs.append({'operation':'result',**rr}); result=parse_json_stdout(rr['stdout'],'RESULT')
        if result.get('run_id') not in (None,rid): raise RouteError('WRONG_RUN_ID_RESULT_REJECTED')
        if status.get('final_state') and result.get('final_state') and status['final_state']!=result['final_state']: raise RouteError('STATUS_RESULT_MISMATCH_REJECTED')
        dl=work/'download'; rr=runproc([str(py),str(ep),'download',rid,str(dl),'--root',str(runroot)],ep.parent,int(inv.get('download_timeout_seconds',60))); recs.append({'operation':'download',**rr}); rows=hash_tree(dl)
        am={'schema_id':'ECTOS_D10_V06_CATEGORY_C_ARTIFACT_MANIFEST_V01','run_id':rid,'files':rows}; amb=canonical(am); (output/'artifact_manifest.json').write_bytes(amb)
        ev={'schema_id':'ECTOS_D10_V06_CATEGORY_C_RESULT_V01','successor_id':SUCCESSOR_ID,'invocation_id':iid,'invocation_sha256':sha256_bytes(ib),'repository':env.get('GITHUB_REPOSITORY'),'github_sha':env.get('GITHUB_SHA'),'github_ref':env.get('GITHUB_REF'),'github_run_id':env.get('GITHUB_RUN_ID'),'github_run_attempt':env.get('GITHUB_RUN_ATTEMPT'),'tooling_parent_commit':inv['tooling_parent_commit'],'runner_name':env.get('RUNNER_NAME'),'machine_name':env.get('COMPUTERNAME'),'v06_package_sha256':sha256_file(package),'mission_sha256':sha256_file(mp),'run_id':rid,'status':status,'result':result,'process_records':recs,'artifact_manifest_sha256':sha256_bytes(amb),'desktop_commander_dependency_count':0,'submit_count':1}
        eb=canonical(ev); (output/'governed_return.json').write_bytes(eb); g['state']='COLLECTED'; g['result_sha256']=sha256_bytes(eb); guard_update(gp,g); return ev
    except Exception:
        g['state']='FAILED'
        try: guard_update(gp,g)
        except Exception: pass
        raise

def main()->int:
    p=argparse.ArgumentParser(); s=p.add_subparsers(dest='cmd',required=True); v=s.add_parser('validate'); v.add_argument('--invocation',required=True); v.add_argument('--allow-fixture',action='store_true'); v.add_argument('--expected-invocation-sha256'); e=s.add_parser('execute'); e.add_argument('--invocation',required=True); e.add_argument('--output',required=True); e.add_argument('--allow-fixture',action='store_true'); a=p.parse_args()
    try:
        if a.cmd=='validate':
            b=Path(a.invocation).read_bytes(); actual=sha256_bytes(b);
            if a.expected_invocation_sha256 and actual!=a.expected_invocation_sha256.upper(): raise RouteError('INVOCATION_SHA_MISMATCH')
            validate_invocation(load_obj(b,'INVOCATION'),dict(os.environ),a.allow_fixture); print(json.dumps({'status':'PASS','invocation_sha256':actual},sort_keys=True)); return 0
        r=execute(Path(a.invocation),Path(a.output),fixture=a.allow_fixture); print(json.dumps({'status':'PASS','run_id':r['run_id']},sort_keys=True)); return 0
    except RouteError as ex: print(json.dumps({'status':'FAIL','error':str(ex)},sort_keys=True),file=sys.stderr); return 40
if __name__=='__main__': raise SystemExit(main())
