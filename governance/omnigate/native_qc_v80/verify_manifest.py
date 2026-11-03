#!/usr/bin/env python3
"""Exact 30-member source and V80 archive check. Producer CI, never qualification."""
from pathlib import Path,PurePosixPath
import json,hashlib,zipfile
root=Path(__file__).resolve().parent
manifest=json.loads((root/'V80_PRODUCER_MANIFEST.json').read_text(encoding='utf8'))
rows=manifest['members']
assert len(rows)==manifest['native_member_count']==30
seen=set()
for row in rows:
 path=row['path']
 assert path.startswith('source/') and path not in seen and '..' not in PurePosixPath(path).parts
 seen.add(path)
 file=root/path
 assert file.is_file() and file.stat().st_size==row['size_bytes']
 assert hashlib.sha256(file.read_bytes()).hexdigest()==row['sha256'],path
actual={str(f.relative_to(root)).replace('\\','/') for f in (root/'source').rglob('*') if f.is_file() and '__pycache__' not in f.parts}
assert seen==actual,'SOURCE_MEMBER_SET_DRIFT'
archive=root/'ECTOS_QC_V80_SYSTEMIC_NATIVE_SUCCESSOR.zip'
proof=json.loads((root/'V80_DELIVERY_PROOF.json').read_text(encoding='utf8'))
assert hashlib.sha256(archive.read_bytes()).hexdigest()==proof['sha256'],'PACKAGE_BYTES_MISMATCH'
with zipfile.ZipFile(archive) as z:
 names=z.namelist()
 expected=seen|{'V80_PRODUCER_MANIFEST.json','README_OWNER_HANDOFF.md'}
 assert len(names)==len(expected)==32
 assert len(set(names))==len(names)
 assert set(names)==expected
 for row in rows:
  assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256']
 assert z.read('V80_PRODUCER_MANIFEST.json')==(root/'V80_PRODUCER_MANIFEST.json').read_bytes()
 bridge='source/qualification_center/v01/authority_bridge_v46.py'
 source=z.read(bridge).decode('utf8')
 assert "HOST_POLICY=pathlib.Path(r'C:\\ProgramData\\ECTOS\\governance\\omni_trust_policy.json')" in source
 assert 'INDEPENDENT_QUALIFIER_EPHEMERAL_TEST' not in source
assert manifest['changed_source_members']==['qualification_center/v01/QC-06-IndependentQualifier.ps1']
print(json.dumps({'status':'PRODUCER_SOURCE_ARCHIVE_BYTES_PASS','native_members':30,'archive_members':32,'archive_sha256':proof['sha256'],'qualified':False}))
