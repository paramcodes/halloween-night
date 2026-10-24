# Evidence

Artefacts in this directory are measured, not illustrative. Each one names the
command and machine that produced it.

| File | What it is | How to reproduce |
|---|---|---|
| `perf_frame.png` | 200-zombie stress run, 1280×720, night lighting, horde staged in front of the player, flamethrower firing | `tools/perf.sh 60 5` |
| `perf.json` | Frame time, draw calls, triangles, VRAM, engine/GPU/window for the same 60 s run | `tools/perf.sh 60 5` |
| `flame_feel.mp4` | 8 s staged take at 30 fps: flame stream crossing three burning shamblers, HUD fuel drain, 3 kills | `DRIVER=x11 tools/capture.sh 8 30` |
| `capture.json` | Provenance for that take: engine, GPU, frames, kills, `staged: true`, `player_invulnerable: true` | written by the same command |
| `capture_failure.log` | Same proof for the capture suite: one assertion broken, runner exits 1, then reverted | see the log header |
| `smoke.json` | Seven-night headless smoke run: victory, phases, spawn and kill counts | `godot --headless --path . -- --smoke --fresh` |
| `ci_failure.log` | Test run with a deliberately broken assertion, proving the gate fails | see the log header |
| `polish_failure.log` | Same proof for the Phase 5 feel suite: one assertion inverted, runner exits 1, then reverted | see the log header |
| `ci_pass.log` | Full `tools/ci/check.sh` pass on the development machine | `tools/ci/check.sh` |
| `fresh_clone.log` | Clone, headless import, and test pass from the committed tree only | `git clone` then the import and test commands |

## Reading the perf numbers

The development machine is an i3-4005U with an Intel HD 4400. It is far below
the GTX 1660 / Steam Deck class the budget targets, and Mesa reports incomplete
Haswell Vulkan support. Frame time p95 is 144.5 ms against a 16.6 ms budget, and
the main-thread process median is 52.2 ms against an 8 ms budget. Both fail. This
is a hardware result, not hidden and not excused. The process median includes the
flamethrower VFX; the GPU stalls before the main thread can finish the frame.

The measurement is still useful: it proves the horde path renders 200 rigged
skeletons (344.7k triangles after LOD) and that draw calls stay far under 800
(p95 496). A pass on reference hardware remains a required Phase 1 gate.

The staged horde is made fireproof for the run. The flamethrower still fires and
its particles and light still cost frame time, but kills would otherwise burn
down the visible crowd and turn the sample into a spawn-rate test. This is
called out here because it is a deliberate benchmark shortcut, not gameplay.

Window size matters. A tiling Wayland compositor can ignore the requested
1280×720 and shrink the window. `perf.json` records the actual size; do not
compare runs at different sizes.

## Reading the capture clip

`flame_feel.mp4` is a composed take, not a playthrough. A fixed seed stages 40
skeletons, the crowd is held in place, and the player cannot die, so the clip can
show first contact without a mob ending it. The camera sits on the player's right
flank: the in-game over-the-shoulder lens looks straight down the plume and
foreshortens it into a blob.

The take is 8 s at 30 fps, rendered offline by Movie Maker mode. Movie Maker
writes the project's 1600×900 viewport; the encoder downscales to 1280×720, so
the clip is not a resolution claim. `capture.json` records what happened: 241
frames, 3 kills, GPU and engine version.

The clip shows the flame reading as a stream with a bright core, embers on the
burning bodies, and the fuel gauge draining. Whether that reads as *dangerous* is
a human judgement and is not claimed here. Frame time is unrelated to the clip:
the perf numbers above still fail on this machine.
