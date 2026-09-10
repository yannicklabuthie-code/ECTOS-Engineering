#!/usr/bin/env python3
from pathlib import Path
import argparse, base64, hashlib, sys

def h(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def rebuild(parts_glob,out,expected):
    parts=sorted(Path('.').glob(parts_glob))
    if not parts: raise SystemExit('NO_BASE64_PARTS:'+parts_glob)
    text=''.join(p.read_text(encoding='ascii') for p in parts)
    data=base64.b64decode(text,validate=True)
    Path(out).parent.mkdir(parents=True,exist_ok=True); Path(out).write_bytes(data)
    actual=h(out)
    if actual!=expected.upper(): raise SystemExit('REHYDRATED_SHA_MISMATCH:'+actual)
    print(f'REHYDRATED={out}|SHA256={actual}|PARTS={len(parts)}')
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--output-root',required=True); a=ap.parse_args()
    root=Path(a.output_root).resolve(); root.mkdir(parents=True,exist_ok=True)
    rebuild('phase2/ci/targets/runner_v02.zip.b64.part*',root/'ECTOS_QP001_TRUST_ROOT_RUNNER_V02_FULL_SYSTEMIC_CLOSURE_RETURN_V01R1.zip','7E68F411D5D1B97B6236F894D8701083CE6F26987353E147DD1F1DF9E70652AD')
    rebuild('phase2/ci/targets/validator_v03_return.zip.b64.part*',root/'ECTOS_QP001_OPTION_B_V04_SPECIALIZED_VALIDATOR_CANDIDATE_V03_ENGINEERING_RETURN_V01.zip','A296315798FDB6FDF3A76887C27D547BD5D1BF49F8DF5E2E3D07687A33A673F5')
if __name__=='__main__': main()
