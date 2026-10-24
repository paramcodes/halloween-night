# AGENTS.md

Godor is a Godot 4.7.2 third-person survival greybox: one defender, one
flamethrower, seven nights, a 200-zombie horde. `PLAN.md` is the source of
truth for scope, constants, and gates. This file covers how to change the
repository without breaking it.

## Commands

| Task | Command |
|---|---|
| Import scripts and resources (run after every new script or `class_name`) | `godot --headless --path . --import` |
| Tests | `godot --headless --path . res://tests/test_runner.tscn` |
| Full gate | `tools/ci/check.sh` |
| Full gate with lint required | `tools/ci/check.sh --require-lint` |
| Attended smoke run, all seven nights | `godot --headless --path . -- --smoke --fresh` |
| Perf harness, windowed | `tools/perf.sh 20 4` |
| Feel clip, 8 s at 30 fps | `DRIVER=x11 tools/capture.sh 8 30` |
| Perf schema check only | `python3 tools/ci/check_perf.py --mode schema` |

`godot --headless` skips rendering. Never report a headless frame time as a
render measurement.

## Layout

- `src/core/` — autoloads (`EventBus`, `Game`, `GameClock`, `SaveGame`),
  composition root (`main.gd`), horde director, perf harness, mesh/palette
  factories, save schema.
- `src/actors/` — player, zombie, villager.
- `src/ai/` — flow field, utility scoring.
- `src/combat/` — flamethrower.
- `src/village/` — procedural village, house, door.
- `src/ui/` — HUD built in code.
- `resources/tuning.tres` — every gameplay number.
- `tests/` — custom headless harness (`tests/support/test_case.gd`).
- `tools/` — CI, asset pipeline, input-map setup.

Scenes are deliberately small `.tscn` roots with scripts attached. The village,
HUD, and all meshes are built at runtime. Do not hand-author a large scene file
that duplicates procedural content.

## Non-negotiable rules

1. **Tuning lives in `resources/tuning.tres`.** Read it through `Game.tuning`.
   No gameplay magic numbers in actors, directors, or UI. Locked constants from
   `PLAN.md` §1 must keep their planned values unless the plan changes.
2. **`EventBus` is signals only.** It holds no state and no game logic.
3. **Autoloads:** `Game` owns run state, `GameClock` owns the phase machine,
   `SaveGame` owns persistence. Do not add a fourth autoload without an ADR.
4. **Typed GDScript.** Annotate function parameters, returns, and member
   variables. Prefer `class_name` over string preloads for project types.
5. **No `await` inside physics or per-frame hot paths.** Zombies, villagers, and
   the flamethrower run every physics frame.
6. **Procedural construction stays deterministic.** Village layout uses a fixed
   seed. Per-run randomness goes through the director's RNG.
7. **One shared mesh and material per zombie archetype.** A merged humanoid is
   one draw call. Do not add child meshes per zombie without a perf run.
8. **Test behavior, not private fields.** Use the public API; assert literal
   values a player could observe.
9. **Every bug fix gets a test** that fails on the old code. If the bug cannot
   be tested cheaply, write down why in the commit message.
10. **No asset lands without provenance.** Add a row to `docs/provenance.csv`
    and an entry to `assets/manifest.json`; `tools/ci/check_assets.py` enforces
    the header and triangle budgets. The greybox has no binary assets.

## Save data

`SaveData` wraps a JSON object with `schema_version`. Any field change bumps the
version and adds a migration in `SaveData.parse`. Saves are written atomically
(temp file + rename). Defeat clears the save; victory keeps stats. Never write
save files outside `user://` except in tests, where `SaveGame.path_override`
exists for that purpose.

## Tests

The harness is custom on purpose (ADR-0002): no GUT, no gdUnit4, no network
dependency. Add tests under `tests/unit/` or `tests/integration/` and register
them in `tests/test_runner.gd`. The runner exits non-zero on failure.

Before claiming a test gate, break one assertion on purpose, confirm the runner
exits non-zero, and revert. A suite that cannot fail is not a gate.

## Performance

Budgets (1080p, GTX 1660 / Steam Deck class) live in `PLAN.md` §2 and in
`tools/ci/check_perf.py`. The perf harness stages 200 zombies in a forward cone
so draw calls and triangles reflect a visible horde; a report with fewer than
100k triangles or fewer than 200 zombies is rejected as a measurement error.

Rules:
- Measure on a real window. Record GPU, CPU, window size, and sample count.
- Report failures. The current development machine is an Intel HD 4400 and will
  not meet 16.6 ms; that is a hardware limitation, not a result to hide.
- Do not lower a budget to make a run pass. Change the budget only by editing
  `PLAN.md` and the checker together.
- No new per-frame allocation in `_process`/`_physics_process`.

## Godot conventions

- Signals: past tense (`zombie_died`), emitted through `EventBus` for
  cross-system events, local signals for parent/child wiring.
- Nodes: `PascalCase` names, `snake_case` files and variables.
- Physics layers are named in `project.godot`; do not hard-code masks without
  reading that file.
- `Engine.time_scale` is used only by smoke mode.
- Smoke mode (`--smoke`) shortens phases and enables god mode. Keep normal
  gameplay paths untouched by smoke-only branches.

## CI

`.github/workflows/ci.yml` runs `tools/ci/check.sh --require-lint` on Godot
4.7.2: headless import, `gdformat --check`, `gdlint`, tests, asset rules, and a
perf-report schema check. CI has no GPU, so it validates structure, not frame
time. Strict budgets run through `tools/perf.sh` on reference hardware.

## Known deviations

See `docs/decisions/`:

- ADR-0001 — flow field at 2 m cells / 4 Hz, no navmesh leaders.
- ADR-0002 — custom test harness instead of GUT.
- ADR-0003 — procedural greybox, no downloaded dataset, no volumetric fog.
- ADR-0004 — perf harness stages the horde and reports hardware honestly.
- ADR-0005 — save schema v1 and permadeath behavior.
- ADR-0006 — KayKit rigged characters, one-surface zombies, manual animation LOD.
- ADR-0007 — offline capture harness; staged takes are evidence, not gate passes.
