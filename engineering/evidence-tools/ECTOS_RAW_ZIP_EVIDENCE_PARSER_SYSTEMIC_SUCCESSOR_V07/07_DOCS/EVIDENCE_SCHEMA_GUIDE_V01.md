# ECTOS Raw ZIP Evidence Schema Guide V01

SCHEMA_ID=ECTOS_RAW_ZIP_EVIDENCE_V01
SCHEMA_VERSION=1.0.0

Every evidence object preserves tool/runtime identity, input identity, parse state, failures, archive structure, entries, coverage, currentness and a semantic evidence identity.

Each relevant parsed field preserves:
- logical type;
- required/nullability state;
- source offset;
- source length;
- raw bytes as uppercase hexadecimal;
- normalized value;
- proof state.

Unsigned 64-bit values are emitted as decimal strings where JSON number precision could be ambiguous downstream.

`evidence_content_identity_sha256` excludes volatile `timestamp_utc`, absolute `input_path`, and the identity field itself. It includes input SHA/size, raw parsed values, normalized values, failures, coverage and tool identity.

`parse_status=PASS` requires zero failures. Safe continued evidence collection after a detected failure must never convert FAIL into PASS.
