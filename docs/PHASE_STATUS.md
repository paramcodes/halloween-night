# Phase status

Plan: `PLAN.md`. This file is the honest plan-versus-built matrix. A phase is
done only when its gate is measured, not when the code exists.

Last updated: 2026-10-24.

## Summary

| Phase | Planned | Built | Gate met? | Status |
|---|---|---|---|---|
| 0 Foundation | Repo, engine, inputs, autoloads, harness, CI, tests | All of it | Partly: harness and local gate exist; no GitHub run yet | **Mostly done** |
| 1 Vertical slice | Flame feel, 200 zombies at 60 fps | Flame, horde, camera, village | No: no recorded feel clip; perf fails on dev GPU | **Partial** |
| 2 Core loop | Full night loop, villagers, houses | All systems plus save/load | Partly: headless smoke run completes; no unassisted human run | **Mostly done** |
| 3 Asset pipeline and art | Real assets, lighting, animation | Pipeline scripts and provenance ledger only | No | **Not started** |
| 4 Depth and balance | Archetypes, escalation, permadeath | Archetypes, bell, save, stats, seven-night pacing | No: no balance telemetry or playtests | **Partial** |
| 5 Polish | VFX, audio, animation, UI, post | HUD and some flame VFX | No | **Not started** |
| 6 Ship | Cert, Steam, demo | None | No | **Not started** |

## Phase 0

Built: repository, Godot 4.7.2 project (Forward+, Jolt), input map, `.gitignore`,
`EventBus` / `Game` / `GameClock` / `SaveGame` autoloads, tuning resource,
procedural world, test harness, perf harness, CI workflow, asset and perf
checkers, `AGENTS.md`.

Gate evidence:
- `perf.json` exists and is written by the harness.
- `tools/ci/check.sh` passes locally (import, tests, asset rules, perf schema).
- The test gate was proven to fail: `docs/evidence/ci_failure.log` records a
  deliberately broken assertion and a non-zero exit.
- Fresh clone verified: `docs/evidence/fresh_clone.log` records a clean clone,
  headless import, and 84/84 assertions with no manual steps.
- Not met: the workflow has not run on GitHub (no remote configured), so its
  Godot install step is unproven.

## Phase 1

Built: player movement, sprint stamina, coyote time, over-shoulder camera, aim
mode; flamethrower with an 8 m / 45° / 12-ray fan, 18 direct dps, 12 dps burn
DoT for 3 s, 100 fuel at 6/s; 200-zombie cap; flow-field pathing; distance LOD;
burn deaths; night lighting; perf harness that stages the horde in view.

Gate evidence:
- Horde renders: about 172k triangles (p50) and 200 alive at the end of the run.
- Draw calls p95 about 103, far under the 800 budget.
- Frame time p95 146.5 ms at 1280×720 on an Intel HD 4400. Budget is 16.6 ms
  on GTX 1660 / Steam Deck class hardware. **Gate not met on this machine.**
- No 60 s recording of the flame feel exists. **Gate not met.**

## Phase 2

Built: dusk/night/dawn/day state machine, wave plan `8 + 6N` capped at 200,
three edge spawners, dusk cache choice (fuel / planks / repair), door HP and
boarding, house occupancy, 15 villagers with utility jobs and sheltering, bell,
dawn tally, pause, run-over and victory screens, autosave, permadeath.

Gate evidence:
- `godot --headless --path . -- --smoke --fresh` completes all seven nights,
  reaches victory, and records phases `Dusk, Night, Dawn, Day` in `smoke.json`.
- The smoke run uses god mode and 6× time scale, so it proves the loop advances
  and saves, not that the game is fair or playable unassisted.
- No full-speed human run start to finish. **Gate not met.**

## Phase 3

Not started. `assets/` is empty; `docs/provenance.csv` has a header and no rows.
`tools/pipeline/` contains a Blender cleaner, a gltf-transform wrapper, and a
manifest builder, none exercised against real files. The lighting and greybox
palette are deliberate placeholders, not an art pass.

## Phase 4

Built: shambler/runner/brute archetypes with per-night gating, raider objective,
lunge, bell scaling, save schema v1 with migration, run stats, seven-night
escalation.

Not done: balance telemetry, difficulty curves from real runs, multiple save
slots, accessibility options. No evidence that seven nights feel different to a
player.

## Phases 5 and 6

Not started. No audio, animation clips, controller support, export presets,
Steam integration, demo, or store assets.

## Measured evidence

| Metric | Value | Where |
|---|---|---|
| Test assertions | see latest `docs/evidence/ci_pass.log` | test runner |
| Smoke run | 7/7 nights, victory, 64 spawned, 706 kills | `smoke.json` |
| Perf window | 1280×720, VSync disabled | `docs/evidence/perf.json` |
| Frame p95 | 146.5 ms (fail, hardware-bound) | `docs/evidence/perf.json` |
| CPU process p50 | 35.2 ms (fail vs 8 ms) | `docs/evidence/perf.json` |
| Draw calls p95 | 103 (pass) | `docs/evidence/perf.json` |
| Triangles p50 | 172,642 (pass) | `docs/evidence/perf.json` |
| VRAM | 153 MB (pass) | `docs/evidence/perf.json` |
| Screenshot | staged horde at night | `docs/evidence/perf_frame.png` |

## What blocks the next gate

1. A GPU in the target class is needed to measure 16.6 ms p95 honestly.
2. A recorded flame-feel clip is needed for Phase 1.
3. Art direction and imported assets are needed for Phase 3.
4. A human playtest is needed for Phases 2, 4, and 5.

None of these can be replaced by more code, and none should be reported as done.
