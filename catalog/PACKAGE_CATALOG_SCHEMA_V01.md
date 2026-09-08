# ECTOS Package Catalog Schema V01

Each governed package entry must record:

- PACKAGE_ID
- PACKAGE_FILENAME
- VERSION
- SIZE_BYTES
- SHA256
- PACKAGE_TYPE
- WORKSTREAM
- INSTALLATION_ROLE
- SOURCE_AUTHORITY
- SUPERIOR_AUTHORITY
- SOURCE_SESSION
- BUILD_STATE
- QUALIFICATION_STATE
- PROMOTION_STATE
- CURRENTNESS_STATE
- DEPENDENCIES
- SUPERSEDES
- SUPERSEDED_BY
- EVIDENCE_PACKAGE
- EVIDENCE_SHA256
- INSTALL_SEQUENCE_POSITION
- TARGET_RUNTIME
- TARGET_OS
- RECONSTRUCTIBLE
- NOTES

Canonical qualification values should preserve ECTOS semantics, including PASS, FAIL, NOT_PROVEN, NOT_REACHABLE, BLOCKED, and CLOSED_PASS where applicable.

No package is an install source merely because it exists in Git. Installation eligibility requires explicit governed qualification/promotion evidence.
