# ADR-0004: How the perf harness stages and reports the horde

- **Status:** accepted
- **Date:** 2026-10-24
- **Context:** The first harness filled the horde at the three village spawn
  edges and sampled after a few seconds. Most zombies were still on the
  perimeter, outside the camera frustum. The report claimed 200 alive zombies
  while drawing roughly half that, so a bad camera angle could make the build
  look fast. Frame time was also measured in a tiled window whose size the
  window manager controlled.

## Decision

1. **Stage, do not wait.** After filling to the cap, place all 200 zombies in a
   forward cone (`±0.9 rad`, radius 5–40 m) around the player, with a
   low-discrepancy scattering. Warm up for three seconds so collision and
   separation settle, then sample.
2. **Guard the measurement.** `tools/ci/check_perf.py` rejects a report unless
   `zombies_end == zombies_target`, there are at least 10 samples, and the
   triangle p50 is at least 100k. This catches an empty or occluded horde before
   a fast number can be reported.
3. **Record the environment.** `perf.json` stores engine version, GPU, CPU,
   window size, sample count, and whether the window was real or headless.
4. **Report hardware separately.** The only available GPU during development is
   an Intel HD 4400. It cannot meet the 16.6 ms budget at any resolution. The
   strict check fails there; CI runs schema validation only because GitHub
   runners have no GPU. A pass on reference hardware (GTX 1660 / Steam Deck
   class) is still required for the Phase 1 gate.
5. **Fixed screenshot size.** The harness asks for 1280×720. A tiling Wayland
   compositor may ignore the request; when that happened, the window size in the
   report was used as the honest number rather than pretending it was 1080p.

## Consequences

- The harness measures a worst-case visible horde, which is the point of the
  budget, but it is not a gameplay-average measurement.
- Staged zombies overlap houses and each other at t=0; steering separates them
  during warmup. This affects pathing cost slightly, not render cost.
- The report can fail on a slow machine without the build being wrong. That is
  visible and intentional; it is not grounds for lowering the budget.

## Alternatives rejected

- Spawn at the edges and sample after 30 s: closer to real play, but the camera
  angle dominates the result and it wastes half the run waiting.
- Benchmark only the simulation headless: no draw calls, no VRAM, useless for
  the render budget.
- Trust `within_budget` in the JSON: the harness computes it, but the checker
  recomputes every metric from the raw fields.
