# Phase status

Plan: `PLAN.md`. This file is the honest plan-versus-built matrix. A phase is
done only when its gate is measured, not when the code exists.

Last updated: 2026-10-25.

## Summary

| Phase | Planned | Built | Gate met? | Status |
|---|---|---|---|---|
| 0 Foundation | Repo, engine, inputs, autoloads, harness, CI, tests | All of it | Partly: harness and local gate exist; no GitHub run yet | **Mostly done** |
| 1 Vertical slice | Flame feel, 200 zombies at 60 fps | Flame, horde, camera, village, rigged characters | No: no recorded feel clip; perf fails on dev GPU | **Partial** |
| 2 Core loop | Full night loop, villagers, houses | All systems plus save/load | Partly: headless smoke run completes; no unassisted human run | **Mostly done** |
| 3 Asset pipeline and art | Real assets, lighting, animation | Rigged character slice, pipeline, provenance, animation | No: environment and lighting still greybox | **Partial** |
| 4 Depth and balance | Archetypes, escalation, permadeath | Archetypes, bell, save, stats, seven-night pacing | No: no balance telemetry or playtests | **Partial** |
| 5 Polish | VFX, audio, animation, UI, post | Camera and animation feedback | No | **Partial** |
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
  headless import, and the full assertion count at the time of the clone. The
  current suite is 170/170.
- Not met: the workflow has not run on GitHub (no remote configured), so its
  Godot install step is unproven.

## Phase 1

Built: player movement, sprint stamina, coyote time, over-shoulder camera, aim
mode; flamethrower with an 8 m / 45° / 12-ray fan, 18 direct dps, 12 dps burn
DoT for 3 s, 100 fuel at 6/s; 200-zombie cap; flow-field pathing; distance LOD;
burn deaths; night lighting; perf harness that stages the horde in view.

Gate evidence:
- Horde renders: 200 rigged skeletons, 344.7k triangles (p50) after LOD, and
  200 alive at the end of the run.
- Draw calls p95 496, under the 800 budget.
- Frame time p95 144.5 ms at 1280×720 on an Intel HD 4400. Budget is 16.6 ms
  on GTX 1660 / Steam Deck class hardware. **Gate not met on this machine.**
- CPU process p50 52.2 ms during the same run, including flamethrower VFX.
  **Gate not met on this machine.**
- No 60 s recording of the flame feel exists. An 8 s staged take exists
  (`docs/evidence/flame_feel.mp4`, `tools/capture.sh`), but nobody has judged it
  as reading "dangerous", and it is shorter than the gate asks. **Gate not met.**

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

Character slice complete; environment not started. Eight rigged KayKit models
(Knight, four adventurer villagers, three skeleton archetypes) are imported with
76/95-clip animation libraries. `tools/pipeline/blender_character.py` merges the
skinned meshes, strips weapons and accessories, and puts each skeleton on one
surface. `CharacterVisual` drives clip mapping, manual animation LOD, tints,
burn material, and the hand bone used by the flamethrower.

Evidence:
- `assets/manifest.json` and `docs/provenance.csv` cover all 16 binary files
  (eight GLBs and eight extracted textures), all CC0-1.0.
- `tools/ci/check_assets.py` passes: every character is under the 20k triangle
  class budget. Zombie meshes are one surface and at most 5,288 triangles.
- `tests/unit/character_test.gd` locks 35 assertions: clip mapping, LOD freeze,
  triangle budget, one-surface zombies, and hand attachment.
- `docs/decisions/0006-rigged-characters.md` records the pipeline and the
  deliberate deviation from one shared animation library.

Not done: 25 hero props, 25 filler props, modular village kit, terrain, lighting,
and the final art pass. The village is still the procedural greybox.

## Phase 4

Built: shambler/runner/brute archetypes with per-night gating, raider objective,
lunge, bell scaling, save schema v1 with migration, run stats, seven-night
escalation.

Not done: balance telemetry, difficulty curves from real runs, multiple save
slots, accessibility options. No evidence that seven nights feel different to a
player.

## Phase 5

Built: part of the VFX workstream, plus the animation and camera feel layer.

- Camera: fire recoil rises to 1.6° and recovers when the trigger is released;
  damage shake scales with the hit, is capped at 1.4°, and never goes negative.
- Animation: per-spawn gait variation seeded from the director RNG, a walk-cycle
  phase offset so identical rigs are not in lockstep, idle breathing, a distinct
  door-attack clip per archetype, and a panic gait for villagers sprinting home
  at dusk.
- VFX: the plume is a soft-puff particle stream with a bright core, turbulence and
  a one-emitter smoke tail; burning bodies get their own ember emitter (created on
  ignition, freed with the burn) and a charred material instead of body-wide
  emission. See `docs/decisions/0007-capture-harness.md` for why the old look was
  replaced.
- Capture: `--capture` plus `tools/capture.sh` render a staged take offline through
  Movie Maker mode. The committed take is 8 s at 30 fps, 3 kills, side camera.
- `tests/unit/polish_test.gd` locks 51 assertions and `tests/unit/capture_test.gd`
  locks 10. `docs/evidence/polish_failure.log` and
  `docs/evidence/capture_failure.log` prove those suites fail when an assertion is
  broken.

Not done: flame edge/dissipate layer split, burning props, door splinters, impact
language, audio, settings and remap, aim shoulder swap, death framing, onboarding,
accessibility, optimization pass, the 90 s trailer.

Gate not met: no trailer cut exists and no stranger has played the build.

## Phase 6

Not started. No controller support, export presets, Steam integration, demo, or
store assets.

## Measured evidence

| Metric | Value | Where |
|---|---|---|
| Test assertions | 183/183, 0 failures | `tools/ci/check.sh` |
| Smoke run | 7/7 nights, victory, 64 spawned, 440 kills | `smoke.json` |
| Capture take | 8 s, 30 fps, 241 frames, 3 kills, staged | `docs/evidence/capture.json` |
| Perf window | 1280×720, VSync disabled | `docs/evidence/perf.json` |
| Frame p95 | 144.5 ms (fail, hardware-bound) | `docs/evidence/perf.json` |
| CPU process p50 | 52.2 ms (fail vs 8 ms) | `docs/evidence/perf.json` |
| Draw calls p95 | 496 (pass) | `docs/evidence/perf.json` |
| Triangles p50 | 344,699 (pass) | `docs/evidence/perf.json` |
| VRAM | 206 MB (pass) | `docs/evidence/perf.json` |
| Screenshot | staged skeleton horde and flame at night | `docs/evidence/perf_frame.png` |

## What blocks the next gate

1. A GPU in the target class is needed to measure 16.6 ms p95 honestly.
2. A human judgement of the flame-feel clip is needed for Phase 1, and a 90 s
   trailer for Phase 5. The 8 s take exists; the judgement does not.
3. Environment art, props, terrain, and lighting are needed to finish Phase 3.
4. A human playtest is needed for Phases 2, 4, 5, and 6.

None of these can be replaced by more code, and none should be reported as done.
