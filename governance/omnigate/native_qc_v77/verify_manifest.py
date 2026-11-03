#!/usr/bin/env python3
"""Read-only source identity check; engineering CI, not ECTOS independent qualifier."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parent
manifest=json.loads((root/'V77_PRODUCER_MANIFEST.json').read_text(encoding='utf-8'))
members=manifest['members']
assert len(members)==manifest['native_source_members']==30, 'MEMBER_CARDINALITY_INVALID'
observed={}
for entry in members:
 name=entry['path']
 assert name.startswith('source/') and '..' not in Path(name).parts, 'UNSAFE_MEMBER_PATH'
 assert name not in observed, 'DUPLICATE_MEMBER'
 f=root/name
 assert f.is_file(), 'MISSING_MEMBER:'+name
 digest=hashlib.sha256(f.read_bytes()).hexdigest()
 assert digest==entry['sha256'], 'SOURCE_HASH_MISMATCH:'+name
 observed[name]=digest
actual={str(p.relative_to(root)).replace('\\','/') for p in (root/'source').rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
assert actual==set(observed), 'UNDECLARED_OR_MISSING_MEMBER'
bridge='source/qualification_center/v01/authority_bridge_v46.py'
assert observed[bridge]==manifest['successor_bridge_sha256'],'BRIDGE_IDENTITY_MISMATCH'
text=(root/bridge).read_text(encoding='utf-8')
assert 'HOST_POLICY=pathlib.Path(r\'C:\\ProgramData\\ECTOS\\governance\\omni_trust_policy.json\')' in text, 'PRODUCTION_TRUST_ROOT_PATH_REPLACED'
assert 'SYNTHETIC_TEST_ONLY' not in text, 'TEST_AUTHORITY_INCLUDED'
print(json.dumps({'result':'PASS_ENGINEERING_SOURCE_IDENTITY_ONLY','members':len(observed),'bridge_sha256':observed[bridge]}))
