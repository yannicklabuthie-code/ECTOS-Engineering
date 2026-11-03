from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parent
m=json.loads((root/'V80_MANIFEST.json').read_text())
prev=json.loads((root.parent/'native_qc_v77/V77_PRODUCER_MANIFEST.json').read_text())
prior={x['path']:x['sha256'] for x in prev['members']}
actual={x.relative_to(root).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in (root/'source').rglob('*') if x.is_file()}
expected={x['path']:x['sha256'] for x in m['members']}
assert len(expected)==30 and m['source_member_count']==30
assert expected==actual,{'missing':list(expected.keys()-actual.keys()),'extra':list(actual.keys()-expected.keys()),'changed':[k for k in expected.keys()&actual.keys() if expected[k]!=actual[k]]}
changed={k for k in actual if prior.get(k)!=actual[k]}
assert changed=={'source/qualification_center/v01/QC-04-PreQfExecution.ps1','source/qualification_center/v01/QC-06-IndependentQualifier.ps1'},changed
print('V80_EXACT_30_OF_30_AND_TWO_CHANGES_PASS')
