# ECTOS Raw ZIP Error Catalog Guide V01

CATALOG_ID=ECTOS_RAW_ZIP_ERROR_CATALOG_V01
ERROR_COUNT=28

The catalog defines stable `RZP_*` failure IDs. A negative fixture passes only when its actual failure ID and failure stage equal the declared expected values.

An unrelated exception, generic error, missing failure, partial parse, or different catalogued failure cannot satisfy a negative fixture.

Any catalogued parser failure produces `parse_status=FAIL`. Some failures permit further bounded evidence collection, but none permit recovery to PASS.

Input/harness failures occupy the same catalog so the entrypoint can fail closed before or after structural parsing without inventing ad-hoc error identities.
