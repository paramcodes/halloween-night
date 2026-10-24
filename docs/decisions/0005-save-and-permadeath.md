# ADR-0005: Save schema v1 and permadeath

- **Status:** accepted
- **Date:** 2026-10-24
- **Context:** A run is seven nights and about 55 minutes. Losing progress to a
  crash is unacceptable; losing the run to a death must stay meaningful. Save
  corruption must never crash the game or resurrect a dead run.

## Decision

- Save one JSON object in `user://godor_save.json` with `schema_version: 1`.
- Persist at dusk and at dawn: night number, fuel, planks, bell charges, door HP
  by house id, living villagers with home id, and run stats.
- `SaveData` is pure: `wrap_run`, `parse`, `migrate`, `validate`, `to_text`.
  File I/O lives in `SaveGame`, which writes a temp file and renames it over the
  old one.
- Version 0 (no version field) migrates to v1 by filling defaults. A save from a
  future version is parsed but not rewritten.
- Validation rejects a save without a night in 1–7, fuel outside 0–100, or a
  missing stats dictionary. A rejected save is ignored, not repaired silently.
- Defeat deletes the save. Victory keeps the save until the next run starts, so
  the results screen survives a restart.
- Tests may redirect the path through `SaveGame.path_override`; production code
  never writes outside `user://`.

## Consequences

- Corrupt or future saves cost the current run, never a crash.
- Adding a field means bumping `SCHEMA_VERSION`, adding a migration, and adding a
  round-trip test. Do not extend v1 in place.
- Door HP and villager state are restored by id; changing house ids breaks old
  saves. The village grid is fixed, so ids are stable.
- There is one save slot. Multiple slots are a Phase 5/6 concern.

## Alternatives rejected

- Godot `ConfigFile` or binary `ResourceSaver`: harder to diff, inspect, and
  migrate.
- Autosave every minute: writes during the night, more corruption surface, and
  it weakens the dusk choice as a commitment point.
- Keep the save after defeat: removes the permadeath rule that the game is built
  around.
