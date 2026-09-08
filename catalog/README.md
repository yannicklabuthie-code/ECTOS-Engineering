# ECTOS Versioned Package Catalog

Purpose: governed catalog of versioned ECTOS packages, installation artifacts, manifests, hashes, qualification state, provenance, and promotion status.

Rules:
- Never replace a released package in place.
- Every package entry records exact filename, version, size, SHA-256, source authority, qualification state, dependencies, installation role, and evidence pointer.
- Build != qualification.
- Unknown / missing evidence remains NOT_PROVEN.
- Superseded packages remain traceable.

Initial target: reconstruct the exact package set used to install and validate ECTOS OS V1, then freeze the canonical install set before future deployment automation.
