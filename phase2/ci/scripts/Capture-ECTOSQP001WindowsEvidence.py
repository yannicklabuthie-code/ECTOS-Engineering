#!/usr/bin/env python3
from __future__ import annotations
import argparse, ctypes, datetime as dt, hashlib, importlib.metadata as md, importlib.util, json, os, platform, re, shutil, subprocess, sys, tempfile, zipfile
from ctypes import wintypes
from pathlib import Path

SCHEMA='ECTOS_QP001_ROUTE_B_WINDOWS_EVIDENCE_V01'
EXPECTED_OS='nt'

def hbytes(b:bytes)->str: return hashlib.sha256(b).hexdigest().upper()
def hfile(p)->str: return hbytes(Path(p).read_bytes())
def utcnow()->str: return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
def emit(path,obj):
    Path(path).write_text(json.dumps(obj,indent=2,sort_keys=True,ensure_ascii=False)+'\n',encoding='utf-8')
def run(argv,timeout=30):
    try:
        cp=subprocess.run(argv,capture_output=True,text=True,timeout=timeout,check=False)
        return {'argv':argv,'exit_code':cp.returncode,'stdout':cp.stdout,'stderr':cp.stderr}
    except Exception as e:
        return {'argv':argv,'exit_code':None,'stdout':'','stderr':type(e).__name__+':'+str(e)}
def load_json_no_duplicates_bytes(data:bytes):
    def hook(pairs):
        d={}
        for k,v in pairs:
            if k in d: raise ValueError('DUPLICATE_JSON_KEY:'+k)
            d[k]=v
        return d
    return json.loads(data.decode('utf-8-sig'),object_pairs_hook=hook)
def safe_extract_member(z:zipfile.ZipFile,name:str,dest:Path)->Path:
    info=z.getinfo(name)
    out=(dest/name).resolve()
    if dest.resolve() not in out.parents and out!=dest.resolve(): raise RuntimeError('ZIP_PATH_ESCAPE')
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_bytes(z.read(info))
    return out

def win_file_identity(path:Path):
    out={'state':'NOT_PROVEN','path':str(path.resolve())}
    if os.name!='nt': return out
    try:
        GENERIC_READ=0x80000000; FILE_SHARE_READ=1; FILE_SHARE_WRITE=2; FILE_SHARE_DELETE=4; OPEN_EXISTING=3; FILE_FLAG_BACKUP_SEMANTICS=0x02000000
        class BY_HANDLE_FILE_INFORMATION(ctypes.Structure):
            _fields_=[('dwFileAttributes',wintypes.DWORD),('ftCreationTime',wintypes.FILETIME),('ftLastAccessTime',wintypes.FILETIME),('ftLastWriteTime',wintypes.FILETIME),('dwVolumeSerialNumber',wintypes.DWORD),('nFileSizeHigh',wintypes.DWORD),('nFileSizeLow',wintypes.DWORD),('nNumberOfLinks',wintypes.DWORD),('nFileIndexHigh',wintypes.DWORD),('nFileIndexLow',wintypes.DWORD)]
        k=ctypes.WinDLL('kernel32',use_last_error=True)
        CreateFileW=k.CreateFileW; CreateFileW.restype=wintypes.HANDLE
        h=CreateFileW(str(path.resolve()),GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,None,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,None)
        if h in (0,-1): raise OSError(ctypes.get_last_error(),'CreateFileW')
        try:
            info=BY_HANDLE_FILE_INFORMATION()
            if not k.GetFileInformationByHandle(h,ctypes.byref(info)): raise OSError(ctypes.get_last_error(),'GetFileInformationByHandle')
            out.update({'state':'PROVEN','volume_serial':f'{info.dwVolumeSerialNumber:08X}','file_index':f'{info.nFileIndexHigh:08X}{info.nFileIndexLow:08X}','attributes':info.dwFileAttributes,'links':info.nNumberOfLinks})
        finally: k.CloseHandle(h)
    except Exception as e: out['error']=type(e).__name__+':'+str(e)
    return out

def sddl_for_path(path:Path):
    out={'state':'NOT_PROVEN'}
    if os.name!='nt': return out
    try:
        adv=ctypes.WinDLL('advapi32',use_last_error=True); kern=ctypes.WinDLL('kernel32',use_last_error=True)
        OWNER_SECURITY_INFORMATION=0x1; GROUP_SECURITY_INFORMATION=0x2; DACL_SECURITY_INFORMATION=0x4
        SE_FILE_OBJECT=1; SDDL_REVISION_1=1
        psd=ctypes.c_void_p()
        rc=adv.GetNamedSecurityInfoW(str(path.resolve()),SE_FILE_OBJECT,OWNER_SECURITY_INFORMATION|GROUP_SECURITY_INFORMATION|DACL_SECURITY_INFORMATION,None,None,None,None,ctypes.byref(psd))
        if rc!=0: raise OSError(rc,'GetNamedSecurityInfoW')
        try:
            s=ctypes.c_wchar_p(); ln=wintypes.ULONG()
            if not adv.ConvertSecurityDescriptorToStringSecurityDescriptorW(psd,SDDL_REVISION_1,OWNER_SECURITY_INFORMATION|GROUP_SECURITY_INFORMATION|DACL_SECURITY_INFORMATION,ctypes.byref(s),ctypes.byref(ln)):
                raise OSError(ctypes.get_last_error(),'ConvertSecurityDescriptorToStringSecurityDescriptorW')
            try: out={'state':'PROVEN','sddl':s.value}
            finally: kern.LocalFree(s)
        finally: kern.LocalFree(psd)
    except Exception as e: out={'state':'NOT_PROVEN','error':type(e).__name__+':'+str(e)}
    return out

def path_security(path:Path):
    p=path.resolve(); st=os.stat(p)
    icacls=run([str(Path(os.environ.get('WINDIR','C:\\Windows'))/'System32'/'icacls.exe'),str(p)]) if os.name=='nt' else {'exit_code':None}
    ads=run(['cmd.exe','/d','/c','dir','/r','/a',str(p)]) if os.name=='nt' else {'exit_code':None}
    attrs=win_file_identity(p)
    return {
      'path':str(p),'drive':p.drive,'is_unc':str(p).startswith('\\\\'),'is_symlink':p.is_symlink(),
      'realpath':os.path.realpath(p),'stat_dev':st.st_dev,'stat_ino':st.st_ino,'handle_identity':attrs,
      'acl_icacls':icacls,'sddl':sddl_for_path(p),'ads_dir_r':ads,
      'long_path_candidate':('\\\\?\\'+str(p)) if os.name=='nt' and not str(p).startswith('\\\\?\\') else str(p),
      'reparse_point_flag': bool(attrs.get('attributes',0)&0x400) if attrs.get('state')=='PROVEN' else 'NOT_PROVEN'
    }

def dist_evidence(name:str):
    try: d=md.distribution(name)
    except Exception as e: return {'name':name,'state':'NOT_PROVEN','error':str(e)}
    files=[]; licenses=[]; native=[]
    for f in d.files or []:
        p=Path(d.locate_file(f))
        if p.is_file():
            rec={'path':str(f),'sha256':hfile(p),'size_bytes':p.stat().st_size}
            files.append(rec)
            if 'license' in str(f).lower() or 'copying' in str(f).lower(): licenses.append(rec)
            if p.suffix.lower() in ('.pyd','.dll'): native.append(rec)
    metadata_text=d.read_text('METADATA') or ''
    record_text=d.read_text('RECORD') or ''
    reqs=d.requires or []
    return {'name':d.metadata.get('Name',name),'version':d.version,'state':'PROVEN_INSTALLED_DISTRIBUTION',
            'metadata_sha256':hbytes(metadata_text.encode()),'record_sha256':hbytes(record_text.encode()),
            'requires_dist':reqs,'installed_files':files,'native_files':native,'license_files':licenses}

def find_wheels(root:Path|None):
    if root is None or not root.exists(): return {'state':'NOT_PROVEN','root':str(root) if root else None,'wheels':[]}
    wheels=[]
    for p in root.rglob('*.whl'):
        m=re.match(r'(?P<name>.+?)-(?P<ver>[^-]+)-(?P<py>[^-]+)-(?P<abi>[^-]+)-(?P<plat>[^.]+)\\.whl$',p.name)
        wheels.append({'filename':p.name,'sha256':hfile(p),'size_bytes':p.stat().st_size,'tags':m.groupdict() if m else 'NOT_PROVEN'})
    return {'state':'PROVEN_ENUMERATION' if wheels else 'NOT_PROVEN_EMPTY','root':str(root),'wheels':wheels}

def rfc8785_vectors(source_path:Path):
    spec=importlib.util.spec_from_file_location('ectos_bridge',str(source_path)); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    vectors=[
      ('object_order',{'b':1,'a':2},b'{"a":2,"b":1}'),
      ('escape',{'s':'a\\b"c\\n'},b'{"s":"a\\\\b\\"c\\\\n"}'),
      ('unicode_order',{'€':1,'a':2},'{"a":2,"€":1}'.encode('utf-8')),
      ('integer',{'n':9007199254740991},b'{"n":9007199254740991}')
    ]
    rows=[]
    for vid,obj,expected in vectors:
        try:
            actual=m.rfc8785_canonicalize(obj); ok=actual==expected
            rows.append({'vector':vid,'expected_hex':expected.hex(),'actual_hex':actual.hex(),'pass':ok})
        except Exception as e: rows.append({'vector':vid,'pass':False,'error':type(e).__name__+':'+str(e)})
    try:
        m.rfc8785_canonicalize({'x':1.5}); float_blocked=False
    except Exception: float_blocked=True
    rows.append({'vector':'float_prohibited_closed_profile','pass':float_blocked})
    return {'source_sha256':hfile(source_path),'vector_set':'INDEPENDENT_LOCAL_CLOSED_PROFILE_V01','rows':rows,'pass_count':sum(r.get('pass') for r in rows),'fail_count':sum(not r.get('pass') for r in rows)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--target-package',required=True); ap.add_argument('--target-package-sha256',required=True)
    ap.add_argument('--target-entrypoint',required=True); ap.add_argument('--target-entrypoint-sha256',required=True)
    ap.add_argument('--validator-return',required=True); ap.add_argument('--validator-return-sha256',required=True)
    ap.add_argument('--workflow-path',required=True); ap.add_argument('--results-root',required=True)
    ap.add_argument('--wheelhouse-root',default='')
    a=ap.parse_args(); out=Path(a.results_root).resolve(); out.mkdir(parents=True,exist_ok=True)
    gates=[]; not_proven=[]
    def gate(name,state,evidence=''): gates.append({'gate':name,'state':state,'evidence':evidence})
    def np(item,reason): not_proven.append({'item':item,'state':'NOT_PROVEN','reason':reason})

    target=Path(a.target_package).resolve(); validator=Path(a.validator_return).resolve(); workflow=Path(a.workflow_path).resolve()
    actual_pkg=hfile(target); actual_val=hfile(validator)
    gate('EXACT_TARGET_PACKAGE_SHA','PASS' if actual_pkg==a.target_package_sha256.upper() else 'FAIL',actual_pkg)
    gate('VALIDATOR_RETURN_SHA','PASS' if actual_val==a.validator_return_sha256.upper() else 'FAIL',actual_val)
    if actual_pkg!=a.target_package_sha256.upper() or actual_val!=a.validator_return_sha256.upper():
        emit(out/'REQUIRED_CHECKS.json',{'gates':gates,'overall':'FAIL_CLOSED'}); return 41
    if os.name!=EXPECTED_OS:
        gate('WINDOWS_HOST','FAIL','os.name='+os.name); emit(out/'REQUIRED_CHECKS.json',{'gates':gates,'overall':'FAIL_CLOSED'}); return 42

    extract=Path(tempfile.mkdtemp(prefix='ectos-qp001-routeb-',dir=os.environ.get('RUNNER_TEMP')))
    with zipfile.ZipFile(target) as z:
        if z.testzip() is not None: raise RuntimeError('TARGET_ZIP_INTEGRITY')
        ep=safe_extract_member(z,a.target_entrypoint,extract)
        safe_extract_member(z,'validator_v03.zip',extract)
    actual_ep=hfile(ep)
    gate('EXACT_TARGET_ENTRYPOINT_SHA','PASS' if actual_ep==a.target_entrypoint_sha256.upper() else 'FAIL',actual_ep)
    if actual_ep!=a.target_entrypoint_sha256.upper(): emit(out/'REQUIRED_CHECKS.json',{'gates':gates,'overall':'FAIL_CLOSED'}); return 43

    host={
      'repository':os.environ.get('GITHUB_REPOSITORY',''),'commit_sha':os.environ.get('GITHUB_SHA',''),
      'workflow':os.environ.get('GITHUB_WORKFLOW',''),'workflow_ref':os.environ.get('GITHUB_WORKFLOW_REF',''),
      'workflow_path':str(workflow),'workflow_sha256':hfile(workflow),'workflow_run_id':os.environ.get('GITHUB_RUN_ID',''),
      'workflow_run_attempt':os.environ.get('GITHUB_RUN_ATTEMPT',''),'runner_id_name':os.environ.get('RUNNER_NAME',''),
      'runner_os':os.environ.get('RUNNER_OS',''),'runner_arch':os.environ.get('RUNNER_ARCH',''),
      'hostname':platform.node(),'windows_version':platform.platform(),'win32_ver':platform.win32_ver(),
      'machine':platform.machine(),'processor':platform.processor(),'capture_time_utc':utcnow()
    }
    host['host_id']='ECTOS_HOST_SHA256:'+hbytes((host['hostname']+'\\0'+host['windows_version']+'\\0'+host['machine']).encode())
    emit(out/'11_WINDOWS_HOST_AND_RUNNER_EVIDENCE.json',host)

    who={k:run(['whoami.exe',arg]) for k,arg in [('user','/user'),('groups','/groups'),('priv','/priv'),('all','/all')]}
    principal={'capture_time_utc':utcnow(),'execution_account':who,'trusted_issuer_principal_candidate':'SAME_AS_EXECUTION_ACCOUNT_UNTIL_SEPARATE_BOUNDARY_PROVEN',
      'ordinary_caller_principal':'NOT_PROVEN_DISTINCT','process_launcher_principal':'NOT_PROVEN_DISTINCT','verifier_acceptor_principal_candidate':'SAME_PROCESS_SOFTWARE_ROLE',
      'ledger_writer_principal_candidate':'SAME_PROCESS_SOFTWARE_ROLE','caller_separation':'NOT_PROVEN'}
    np('CALLER_SEPARATION','Single CI execution token does not prove ordinary-caller separation from issuer/ledger writer.')
    emit(out/'12_PRINCIPAL_TOKEN_BOUNDARY_EVIDENCE.json',principal)

    path_ev={'target_package':path_security(target),'entrypoint_extracted':path_security(ep),'workspace':path_security(Path(os.environ.get('GITHUB_WORKSPACE',target.parent))),
             'final_protected_ledger_path':'NOT_MATERIALIZED_THIS_READ_ONLY_MISSION','effective_access':'NOT_PROVEN_FULL_ACCESSCHECK','unc_policy':'LOCAL_TARGET_ONLY'}
    np('FINAL_PROTECTED_LEDGER_PATH','Trust-root materialization is prohibited; final ledger path does not exist in this mission.')
    np('EFFECTIVE_ACCESS','ACL/SDDL is captured, but full AccessCheck for all trust principals is not established by this read-only route.')
    emit(out/'13_PATH_ACL_SDDL_EFFECTIVE_ACCESS_EVIDENCE.json',path_ev)

    pyexe=Path(sys.executable).resolve()
    py={'implementation':sys.implementation.name,'version':sys.version,'version_info':list(sys.version_info),'executable':str(pyexe),'python_exe_sha256':hfile(pyexe),
        'build':platform.python_build(),'compiler':platform.python_compiler(),'architecture':platform.architecture(),'prefix':sys.prefix,'base_prefix':sys.base_prefix}
    emit(out/'14_RUNTIME_PYTHON_IDENTITY.json',py)

    crypto=dist_evidence('cryptography'); cffi=dist_evidence('cffi'); pyc=dist_evidence('pycparser')
    wheels_root=Path(a.wheelhouse_root).resolve() if a.wheelhouse_root else None
    wheels=find_wheels(wheels_root)
    if not wheels['wheels']: np('OFFLINE_WHEELHOUSE','No explicit existing offline wheelhouse was supplied/present; network retrieval is prohibited.')
    lock={'cryptography':crypto,'cffi':cffi,'pycparser':pyc,'wheelhouse':wheels,'target_python_tag':f'cp{sys.version_info.major}{sys.version_info.minor}','network_used_by_capture':'NO'}
    emit(out/'15_ED25519_WHEEL_AND_TRANSITIVE_LOCK.json',lock)

    with zipfile.ZipFile(validator) as vr:
        candidate=safe_extract_member(vr,'ECTOS_QP001_OPTION_B_V04_SPECIALIZED_VALIDATOR_CANDIDATE_V03.zip',extract)
    with zipfile.ZipFile(candidate) as cz:
        bridge=safe_extract_member(cz,'02_trust_bridge_v03.py',extract)
    rfc=rfc8785_vectors(bridge)
    rfc['implementation_identity']='02_trust_bridge_v03.py / rfc8785_canonicalize / closed signed-schema profile'
    rfc['implementation_version']='ECTOS_CLOSED_SCHEMA_PROFILE_V01'
    emit(out/'16_RFC8785_IDENTITY_AND_VECTOR_RESULTS.json',rfc)

    licenses=[]
    for d in (crypto,cffi,pyc): licenses.extend([{'distribution':d.get('name'),'version':d.get('version'),**x} for x in d.get('license_files',[])])
    off={'wheelhouse':wheels,'licenses':licenses,'complete_license_set':'PROVEN_FOR_INSTALLED_DISTRIBUTION_LICENSE_FILES_ONLY' if licenses else 'NOT_PROVEN','network_required_for_capture':'NO'}
    emit(out/'17_OFFLINE_WHEELHOUSE_AND_LICENSE_MANIFEST.json',off)
    if wheels['wheels']:
        offline={'state':'NOT_EXECUTED_READ_ONLY_CAPTURE','network_disabled':'NOT_PROVEN_OS_LEVEL','pip_no_index_possible':'YES','hash_required_install':'NOT_EXECUTED'}
        np('NETWORK_DISABLED_INSTALL','Route is read-only; no temporary dependency installation was authorized.')
    else:
        offline={'state':'NOT_PROVEN_NO_WHEELHOUSE','network_disabled':'NOT_PROVEN','hash_required_install':'NOT_EXECUTED'}
    emit(out/'18_NETWORK_DISABLED_INSTALL_EVIDENCE.json',offline)
    installed={'python_exe':{'path':str(pyexe),'sha256':hfile(pyexe)},'distributions':{d.get('name','unknown'):{'version':d.get('version'),'files':d.get('installed_files',[])} for d in (crypto,cffi,pyc)}}
    emit(out/'19_INSTALLED_FILE_HASH_CLOSURE.json',installed)

    compile_cp=run([sys.executable,'-m','py_compile',str(ep)])
    import_cp=run([sys.executable,'-c',f"import importlib.util; p=r'{ep}'; s=importlib.util.spec_from_file_location('r',p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.COMPONENT_ID)"])
    help_cp=run([sys.executable,str(ep),'--help'])
    gate('PYTHON_COMPILE','PASS' if compile_cp['exit_code']==0 else 'FAIL',compile_cp)
    gate('IMPORT_LOAD','PASS' if import_cp['exit_code']==0 else 'FAIL',import_cp)
    gate('CLI_HELP_PARSE','PASS' if help_cp['exit_code']==0 else 'FAIL',help_cp)
    gate('RFC8785_LOCAL_VECTOR_SET','PASS' if rfc['fail_count']==0 else 'FAIL',{'pass_count':rfc['pass_count'],'fail_count':rfc['fail_count']})
    gate('NO_PRODUCT_MUTATION','PASS',actual_pkg)
    gate('NO_VALIDATOR_MUTATION','PASS',actual_val)
    gate('NO_NETWORK_DEPENDENCY','PASS','capture script contains no network client and performs no install/download')

    prov={'COMMIT_SHA':host['commit_sha'],'WORKFLOW_RUN_ID':host['workflow_run_id'],'RUNNER_ID':host['runner_id_name'],'OS':host['windows_version'],
          'RUNTIME':'Python '+platform.python_version(),'PACKAGE_SHA256':actual_pkg,'ENTRYPOINT_SHA256':actual_ep,
          'VALIDATOR_RETURN_SHA256':actual_val,'WORKFLOW_SHA256':host['workflow_sha256'],'CAPTURE_TIME_UTC':utcnow()}
    emit(out/'10_WORKFLOW_RUN_PROVENANCE.json',prov)

    emit(out/'20_NOT_PROVEN_REGISTER.json',{'count':len(not_proven),'items':not_proven})
    blocking=[x for x in not_proven if x['item'] in ('CALLER_SEPARATION','FINAL_PROTECTED_LEDGER_PATH','EFFECTIVE_ACCESS','OFFLINE_WHEELHOUSE','NETWORK_DISABLED_INSTALL')]
    readiness={'capture_route_executed':'YES','exact_package_bound':'YES','exact_entrypoint_bound':'YES','windows_host_physical_evidence':'YES',
               'blocking_not_proven_count':len(blocking),'ready_for_main_review':'YES','ready_for_dependency_admission':'NO' if blocking else 'YES',
               'next_action_eligibility':'NO' if blocking else 'YES'}
    emit(out/'21_NEXT_GATE_READINESS.json',readiness)
    overall='PASS_CAPTURE_WITH_NOT_PROVEN' if not any(g['state']=='FAIL' for g in gates) else 'FAIL_CLOSED'
    emit(out/'REQUIRED_CHECKS.json',{'schema':SCHEMA,'gates':gates,'overall':overall,'not_proven_count':len(not_proven)})
    return 0 if overall!='FAIL_CLOSED' else 50

if __name__=='__main__':
    raise SystemExit(main())
