# ECTOS Snapshots

Purpose: preserve recoverable project snapshots independently of the active workstation.

Snapshot policy:
- Snapshot identity must include timestamp, source root, manifest, file count, byte count, and SHA-256 inventory.
- Snapshot must be immutable once declared complete.
- Secrets, credentials, tokens, private keys, caches, temporary files, and machine-specific disposable artifacts must not be committed.
- Large binary package archives should be referenced by manifest and stored using an approved artifact mechanism when normal Git storage is inappropriate.

Immediate priority: create a first governed snapshot of the current ECTOS working tree before further industrialization.
