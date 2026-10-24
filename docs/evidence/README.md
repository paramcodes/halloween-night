# Evidence

Artefacts in this directory are measured, not illustrative. Each one names the
command and machine that produced it.

| File | What it is | How to reproduce |
|---|---|---|
| `perf_frame.png` | 200-zombie stress run, 1280×720, night lighting, horde staged in front of the player, flamethrower firing | `tools/perf.sh 60 5` |
| `perf.json` | Frame time, draw calls, triangles, VRAM, engine/GPU/window for the same 60 s run | `tools/perf.sh 60 5` |
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
