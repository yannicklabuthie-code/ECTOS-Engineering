#!/usr/bin/env python3
from pathlib import Path
import base64, copy, csv, datetime as dt, hashlib, importlib.util, json, os, sys, tempfile
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

root=Path(__file__).resolve().parent
sys.path.insert(0,str(root))

# Exact-target native assurance helper. It is intentionally separate from the
# Phase01 sample-package assurance path. The caller must provide exact package
# and entrypoint identities and a results root.

def hbytes(b): return hashlib.sha256(b).hexdigest().upper()
def hfile(p): return hbytes(Path(p).read_bytes())
def load_module(path):
    spec=importlib.util.spec_from_file_location('ectos_exact_target',str(path))
    m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def safe_extract(z,dest):
    dest=Path(dest).resolve()
    for info in z.infolist():
        out=(dest/info.filename).resolve()
        if out!=dest and dest not in out.parents: raise RuntimeError('ZIP_PATH_TRAVERSAL')
    z.extractall(dest)

def write_json(path,obj): Path(path).write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n',encoding='utf-8')

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument('--target-package-path',required=True)
    ap.add_argument('--target-package-sha256',required=True)
    ap.add_argument('--target-entrypoint-path',required=True)
    ap.add_argument('--target-entrypoint-sha256',required=True)
    ap.add_argument('--target-artifact-id',required=True)
    ap.add_argument('--target-test-profile',required=True)
    ap.add_argument('--results-root',required=True)
    x=ap.parse_args()
    results=Path(x.results_root).resolve(); results.mkdir(parents=True,exist_ok=True)
    checks=[]
    def gate(gid,name,state,detail=''): checks.append({'gate_id':gid,'name':name,'state':state,'detail':detail})
    pkg=Path(x.target_package_path).resolve()
    if not pkg.is_file(): raise SystemExit('TARGET_PACKAGE_NOT_FOUND')
    actual_pkg=hfile(pkg)
    gate('N01','EXACT_PACKAGE_SHA256_IDENTITY','PASS' if actual_pkg==x.target_package_sha256.upper() else 'FAIL',actual_pkg)
    if actual_pkg!=x.target_package_sha256.upper():
        write_json(results/'REQUIRED_CHECKS.json',{'checks':checks,'overall':'FAIL_CLOSED'}); return 41
    if os.name!='nt':
        gate('N03','WINDOWS_HOST_IDENTITY','FAIL','NATIVE_WINDOWS_REQUIRED')
        write_json(results/'REQUIRED_CHECKS.json',{'checks':checks,'overall':'FAIL_CLOSED'}); return 42
    extract=Path(tempfile.mkdtemp(prefix='ectos-exact-target-',dir=os.environ.get('RUNNER_TEMP')))
    import zipfile
    with zipfile.ZipFile(pkg) as z:
        if z.testzip() is not None: raise RuntimeError('ZIP_INTEGRITY_FAIL')
        safe_extract(z,extract)
    ep=(extract/x.target_entrypoint_path).resolve()
    if extract.resolve() not in ep.parents or not ep.is_file(): raise SystemExit('ENTRYPOINT_NOT_FOUND_OR_ESCAPES_PACKAGE')
    actual_ep=hfile(ep)
    gate('N02','EXACT_ENTRYPOINT_SHA256_IDENTITY','PASS' if actual_ep==x.target_entrypoint_sha256.upper() else 'FAIL',actual_ep)
    if actual_ep!=x.target_entrypoint_sha256.upper():
        write_json(results/'REQUIRED_CHECKS.json',{'checks':checks,'overall':'FAIL_CLOSED'}); return 43
    import platform, subprocess
    runtime={'os':platform.platform(),'runner_name':os.environ.get('RUNNER_NAME',''),'python':platform.python_version(),'python_executable':sys.executable}
    gate('N03','WINDOWS_HOST_IDENTITY','PASS',runtime['os'])
    try:
        import cryptography
        runtime['cryptography_version']=cryptography.__version__
        runtime['cryptography_module_sha256']=hfile(cryptography.__file__)
        gate('N05','CRYPTOGRAPHY_DEPENDENCY_IMPORT','PASS',cryptography.__version__)
    except Exception as e:
        gate('N05','CRYPTOGRAPHY_DEPENDENCY_IMPORT','FAIL',str(e)); raise
    gate('N04','PYTHON_RUNTIME_IDENTITY','PASS',platform.python_version())
    write_json(results/'NATIVE_RUNTIME_EVIDENCE.json',runtime)
    cp=subprocess.run([sys.executable,'-m','py_compile',str(ep)],capture_output=True,text=True)
    gate('N06','PYTHON_COMPILE','PASS' if cp.returncode==0 else 'FAIL',cp.stderr)
    m=load_module(ep); gate('N07','IMPORT_LOAD','PASS',getattr(m,'COMPONENT_ID',''))
    hp=subprocess.run([sys.executable,str(ep),'--help'],capture_output=True,text=True)
    gate('N08','CLI_HELP_ARGUMENT_PARSE','PASS' if hp.returncode==0 else 'FAIL',hp.stderr)
    # Exact-bytes provenance seal for the deterministic/native checks performed by this helper.
    prov={'schema_id':'ECTOS_EXACT_TARGET_CI_PROVENANCE_V01','COMMIT_SHA':os.environ.get('GITHUB_SHA',''),
          'WORKFLOW_RUN_ID':os.environ.get('GITHUB_RUN_ID',''),'RUNNER_ID':os.environ.get('RUNNER_NAME',''),
          'OS':platform.platform(),'RUNTIME':'Python '+platform.python_version(),'PACKAGE_SHA256':actual_pkg,
          'ENTRYPOINT_SHA256':actual_ep,'TARGET_ARTIFACT_ID':x.target_artifact_id,'TARGET_TEST_PROFILE':x.target_test_profile}
    write_json(results/'EXACT_PACKAGE_IDENTITY.json',{'TARGET_ARTIFACT_ID':x.target_artifact_id,'PACKAGE_PATH':str(pkg),
      'PACKAGE_SHA256':actual_pkg,'ENTRYPOINT_PATH':x.target_entrypoint_path,'ENTRYPOINT_SHA256':actual_ep,
      'TESTED_BYTES_EQUAL_DECLARED_BYTES':True})
    overall='PASS' if all(c['state']=='PASS' for c in checks) else 'FAIL_CLOSED'
    req={'schema_id':'ECTOS_EXACT_TARGET_REQUIRED_CHECKS_V01','target_artifact_id':x.target_artifact_id,
         'target_package_sha256':actual_pkg,'target_entrypoint_sha256':actual_ep,'target_test_profile':x.target_test_profile,
         'checks':checks,'overall':overall}
    write_json(results/'REQUIRED_CHECKS.json',req)
    prov['TEST_RESULT_SET_SHA256']=hfile(results/'REQUIRED_CHECKS.json')
    write_json(results/'CI_PROVENANCE.json',prov)
    write_json(results/'STARTABILITY_EVIDENCE.json',{'CLI_HELP_ARGUMENT_PARSE':next(c for c in checks if c['gate_id']=='N08')})
    write_json(results/'DEFECT_REGRESSION_RESULT.json',{'known_blocking_defect_count':sum(1 for c in checks if c['state']=='FAIL')})
    return 0 if overall=='PASS' else 50

if __name__=='__main__': raise SystemExit(main())
