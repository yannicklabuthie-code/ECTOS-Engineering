# ECTOS Mission Registry MVP

Mission Registry is the durable operational truth for missions. It does not replace the Dependency Graph and must not duplicate technical topology.

## Runtime

- Language: Python
- Target runtime: Python 3.12+
- Target OS: cross-platform
- PowerShell: not used by this MVP

## Physical layout

A registry root contains:

- `index.json` — mission IDs only;
- `missions/<MISSION_ID>.json` — one durable mission record per mission.

Mission records bind to an exact source repository and 40-character Git commit. Durable pointers bind to repository, commit, path and SHA-256.

## Commands

```text
python engineering/mission_registry.py --root <registry-root> init
python engineering/mission_registry.py --root <registry-root> create <mission.json>
python engineering/mission_registry.py --root <registry-root> get <MISSION_ID>
python engineering/mission_registry.py --root <registry-root> transition <MISSION_ID> --to RUNNING --authority <actor> --evidence <evidence>
python engineering/mission_registry.py --root <registry-root> list
python engineering/mission_registry.py --root <registry-root> resume <MISSION_ID>
```

## Resume invariant

A mission is resumable only when:

1. its record validates;
2. it is not terminal (`CLOSED` or `CANCELED`);
3. exact `source_repository` and `source_commit` are present;
4. at least one durable pointer exists;
5. every pointer contains `pointer_id`, `repository`, `commit`, `path`, and `sha256`.

Chat history is not an input to `resume`.

## V02 schema note

`ECTOS_MISSION_REGISTRY_SCHEMA_V02` is an explicit successor to the design-time V01. V02 adds `WAITING`, because Methodology step 03.2 explicitly requires a waiting transition. V01 remains historical and is not silently rewritten.
