# Godor — Multi-Phase Build Plan

> You are the only person in a small village who can hold a line. Each night, the dead
> come from three directions. Your flamethrower has 16 seconds of fuel. You cannot cover
> two streets. Choose which one you lose.

Any feature that does not serve that sentence is cut.

---

## 1. Locked decisions

| Decision | Value | Rationale |
|---|---|---|
| Engine | Godot 4.7.2, Forward+, Vulkan | Text scenes, agent-editable, built-in fog/GI/nav/particles |
| Platform | Desktop, Steam first | No web constraints, full Vulkan feature set |
| Camera | Third-person over-shoulder | Flamethrower fantasy plus horde readability |
| Role | Lone defender hero | Villagers stay autonomous; no command layer |
| Scope | 7 nights, one village, one weapon, one run | Solo-shippable |
| Assets | `scenario-labs/3d-collection` for set dressing only | It is not a village kit; see §5 |
| Village shell | Modular kit (KayKit Village, CC0) or generated with a locked style | Needs walls, roofs, doors that tile |
| Characters | One shared skeleton, N meshes | One animation library for every humanoid |
| Language | GDScript for gameplay, C# only if profiling demands | Faster iteration; C# costs export friction |

### Design constants

| Constant | Value |
|---|---|
| Village footprint | 120 × 120 m |
| Houses | 9 (8 dwellings + 1 gatehouse) |
| Villagers | 15–20 |
| Zombies alive (cap) | 200 |
| Night length | 5 min real time |
| Day length | 3–5 min real time |
| Run length | 7 nights, ~55 min |
| Spawn formula | `8 + 6N`, hard cap 200 alive, 3 edge spawners |
| Fuel capacity | 100 |
| Burn rate | 6/s → 16.6 s continuous |
| Refill | 1 canister per night, chosen at dusk |
| Flame range / cone | 8 m / 45° |
| Flame damage | 18 dps direct + 12 dps burn, 3 s |
| Zombie HP | 100 (dies in ~2.5 s of contact) |
| Player speed | 2.6 walk / 5.2 sprint / 1.6 aim |
| Zombie speed | 1.4 shamble / 4.5 lunge (2 s burst) |
| Door HP | 200; zombie DPS 15 → 13 s to break |
| Boarding | +150 HP, 4 s action, 1 plank |
| Bell | 3 charges per run, draws +20% zombies that night |

---

## 2. Budgets

### Performance (1080p60, GTX 1660 / Steam Deck class)

| Metric | Budget | Hard fail |
|---|---|---|
| Frame time p95 | ≤ 16.6 ms | > 20 ms |
| Draw calls | ≤ 800 | > 1200 |
| Visible triangles | ≤ 1.5 M | > 2.5 M |
| VRAM | ≤ 2.5 GB | > 3.5 GB |
| CPU main thread | ≤ 8 ms | > 11 ms |
| Load time, cold | ≤ 12 s | > 20 s |

### Content

| Asset class | Count | Budget each |
|---|---|---|
| Hero props (from dataset) | 25 | ≤ 15k tris, 1K albedo |
| Filler props (from dataset) | 25 | ≤ 1k tris, 512 albedo |
| Modular kit pieces | 40–60 | ≤ 2k tris |
| Character meshes | 8 (player, 4 villager, 3 zombie) | ≤ 20k tris, 2K |
| Animation clips | ~40 | shared skeleton |
| SFX | 60 | mono, 48 kHz |
| Music/ambience beds | 4 | looped, ≤ 3 MB each |

### Schedule

20 h/week part-time. Full-time is roughly half the wall clock.

| Phase | Weeks | Cumulative |
|---|---|---|
| 0 Foundation | 1 | 1 |
| 1 Vertical slice | 2 | 3 |
| 2 Core loop | 3 | 6 |
| 3 Asset pipeline + art pass | 3 | 9 |
| 4 Depth and balance | 3 | 12 |
| 5 Polish | 4 | 16 |
| 6 Ship | 3 | 19 |

---

## 3. Phase overview

| Phase | Goal | Gate |
|---|---|---|
| 0 | Repo, engine, conventions, perf harness, CI | Boots, moves, CI green, harness reports |
| 1 | Prove the feel: flame + 200 zombies at 60 fps | Flame is scary on video; p95 ≤ 16.6 ms |
| 2 | Complete night loop with villagers and houses | One full run start to finish, no cheats |
| 3 | Replace greybox with real assets and lighting | Looks shippable in a screenshot |
| 4 | Depth: archetypes, escalation, permadeath, save | 7 nights feel different; runs are lost fairly |
| 5 | Polish: VFX, audio, animation, UI, post | A stranger plays 20 min unaided |
| 6 | Ship: cert, Steam, demo, launch | Store page live, demo stable on 3 machines |

Rule: **a phase does not start until the previous gate is measured, not assumed.**

---

## Phase 0 — Foundation

**Duration** 1 week · **Goal** A project that boots, moves, measures, and fails CI when it drifts.

### Workstreams

- [ ] Repository: git init, `.gitignore` (`.godot/`, `*.import`, `build/`), `main` + short-lived branches
- [ ] Godot 4.7.2 pinned; `project.godot` committed with Forward+ and Jolt
- [ ] Directory structure per §7
- [ ] Input map: move, look, sprint, aim, fire, interact, bell, pause
- [ ] `EventBus` autoload (signals only, no state)
- [ ] `GameClock` autoload: day/dusk/night/dawn state machine, emits `phase_changed`
- [ ] `SaveGame`: versioned JSON, `schema_version` field, round-trip test
- [ ] Conventions doc in `AGENTS.md`: naming, node layout, tuning-in-resources rule
- [ ] Perf harness scene: 200 instanced zombies + LOD set + flame VFX, 60 s run, writes `perf.json`
- [ ] CI: headless import, `gdlint`/`gdformat`, unit tests, asset budget check
- [ ] Test framework (GUT or gdUnit4) with 3 passing tests to prove the harness

### Acceptance

- Project opens on a clean machine and boots to an empty grey scene.
- Controller walks, sprints, and stops with no camera jitter.
- CI fails when a test is deliberately broken (verify this once, then revert).
- Perf harness prints p50/p95 frame time and draw calls.

### Gate

`perf.json` exists, CI is green, and a fresh clone builds without manual steps.

---

## Phase 1 — Vertical slice

**Duration** 2 weeks · **Goal** Answer the only question that matters: does the night feel dangerous?

### Workstreams

- [ ] Third-person controller: `CharacterBody3D`, ground snap, coyote time, sprint stamina
- [ ] Camera rig: `SpringArm3D` (3.5 m, shoulder offset 0.55, pivot y 1.55), 0.15 s pos smoothing, 0.08 s rot smoothing, FOV 65/72
- [ ] Greybox village: 9 boxes, 3 spawn points, 4 street chokepoints, blockout only
- [ ] Day/night director: light angle/energy/color curve, fog density curve, dusk audio cue
- [ ] Flamethrower: fuel resource, 12-ray fan at 10 Hz, cone damage, `GPUParticles3D` + `CurveTexture`, flickering `OmniLight3D`, heat-distortion quad
- [ ] Zombie: flow field (1 m grid, 4 Hz), 6 navmesh leaders at 5 Hz, follower steering + separation from one spatial hash
- [ ] Zombie animation LOD: full under 15 m, half under 35 m, frozen pose + `MultiMesh` beyond
- [ ] Damage and death, hit feedback (flinch, ragdoll-lite or dissolve)
- [ ] 200-zombie stress scene wired to the perf harness

### Feel checkpoints

1. **Day 4**: recording of the flame in first contact. If it does not read as dangerous in a 5 s clip, iterate on particles, light, and audio before anything else.
2. **Day 7**: 200 zombies hold p95 ≤ 16.6 ms. If not, fix before Phase 2. Networks, navigation, and animation are the likely causes, in that order.

### Gate

- One night loop from dusk to dawn with the greybox village.
- p95 ≤ 16.6 ms with 200 alive at 60% animated.
- Flame kill time 2.5 s ± 0.3 s measured, not eyeballed.

**If this gate fails, do not proceed.** Every later phase multiplies the cost of fixing it.

---

## Phase 2 — Core loop

**Duration** 3 weeks · **Goal** A complete, fair, replayable night.

### Workstreams

- [ ] `House`: occupancy, interior volume, door node, light state
- [ ] `Door`: HP, boarding action (4 s, consumes plank), break VFX, breach event
- [ ] Villager utility AI: `score = w_safety·threat⁻¹ + w_home·is_dusk·10 + w_work·urgency − dist/60`
- [ ] Villager day behavior: 4 jobs (wood, water, watch, repair), wander fallback
- [ ] Dusk migration: `w_home` flips hard; villagers sprint home; failure is visible and legible
- [ ] `NightDirector`: wave budget, 3 spawners, spawn pacing curve, alive cap enforcement
- [ ] Fuel economy: 1 canister per night, dusk choice UI (cache A/B/C)
- [ ] Plank economy: boarding resources, repair during day
- [ ] Win/lose: dawn tally, villager permanent death, run end at night 7 or all-dead
- [ ] Minimal HUD: fuel, door health of nearby houses, alive count, night number
- [ ] Pause and restart

### Acceptance

- A player can complete all 7 nights without console commands.
- Losing a street is a choice the player recognizes as their own.
- No villager gets stuck on geometry for > 5 s (instrument it, assert it).

### Gate

Three consecutive full runs at 60 fps. Two losses, one win, all explainable in one sentence each.

---

## Phase 3 — Asset pipeline and art pass

**Duration** 3 weeks · **Goal** Turn the greybox into something you would screenshot.

### Workstreams

**Pipeline (week 1)**

- [ ] Harvest one generator family only from `scenario-labs/3d-collection`; never mix vendors
- [ ] Blender headless pass: auto-scale from bbox, pivot to base center, strip sub-floor geometry, decimate to class budget
- [ ] Bake pass: high → low normal + AO (Cycles), 1K/512 targets
- [ ] `gltf-transform optimize --compress meshopt --texture-compress ktx2`
- [ ] `manifest.json` emit: `{id, category, dims, tris, materials, textures, sha256, license}`
- [ ] CI budget check: reject any asset over class budget
- [ ] Provenance ledger: source URL, generator, license, hash, per asset

**Content (week 2)**

- [ ] Import 25 hero + 25 filler props; hand-place into 9 house plots and 4 street scenes
- [ ] Modular village kit imported, material variants unified
- [ ] Characters: one skeleton, retarget all clips, 8 meshes
- [ ] Terrain: heightmap + splatmap, 3 materials, no tiling artifacts at 8 m

**Art (week 3)**

- [ ] `LightmapGI` bake on static village; verify no light bleed at doors
- [ ] `WorldEnvironment`: ACES, exposure 0.9, TAA 8, SSAO medium r0.8, SSIL/SSR off, glow threshold 1.0, volumetric fog 0.02 @ 64 steps half-res
- [ ] Moon directional: energy 0.15, `#6E8BC4`, 2 shadow splits 4096
- [ ] Emissive windows as the only warm source; palette locked to 3 hues
- [ ] Global desaturation pass on import (not by hand)

### Acceptance

- Every asset in the game is under budget and has a provenance row.
- A 1080p screenshot of night reads as intentional art direction.
- Bake time under 10 min; rebake is a single command.

### Gate

Blind test: show 3 screenshots to someone who has not seen the project. They must identify "small village at night" in under 3 seconds.

---

## Phase 4 — Depth and balance

**Duration** 3 weeks · **Goal** Seven nights that feel different, losses that feel fair.

### Workstreams

- [ ] Zombie archetypes: shambler, runner (night 4+, 6 m/s, 40 HP), brute (night 6+, 400 HP, 3× door damage)
- [ ] Escalation curve: spawn count, archetype mix, spawner count per night
- [ ] Bell: 3 charges, +20% spawns that night, visible villager response
- [ ] Fire spread on wooden props (2-day stretch, high visual payoff)
- [ ] Difficulty options: one axis only (fuel generosity)
- [ ] Save/load mid-run, versioned and migration-tested
- [ ] Stats screen at dawn: zombies killed, fuel spent, doors lost, villagers lost
- [ ] Telemetry (local only): night reached, cause of death, fuel curve

### Acceptance

- Night 1 and night 7 are visually and mechanically distinct within 10 s.
- A loss is explainable by one decision the player made.
- Save from night 3 loads into night 4 with identical state.

### Gate

Five playtesters, 20 min each, no guidance. Every one reaches night 3. At least two reach night 5.

---

## Phase 5 — Polish

**Duration** 4 weeks · **Goal** Remove every "this is a prototype" tell.

### Workstreams

- [ ] **Animation** (highest leverage): zombie gait variation, flinch, door attack, villager panic run, player fire recoil, idle breathing
- [ ] **VFX**: flame core/edge/dissipate layers, embers, smoke, burning props, door splinters, blood-free impact language
- [ ] **Audio**: 3 ambience beds with crossfaded dusk transition, distance-filtered moans (max 8 voices), flame loop with intensity parameter, bell, door stress creaks
- [ ] **UI/UX**: fuel as a diegetic gauge plus HUD fallback, door health readability, night counter, dawn tally, settings, remap
- [ ] **Camera polish**: aim shoulder swap, damage shake budget, death framing
- [ ] **Onboarding**: first 30 s teaches fuel scarcity without a tutorial box
- [ ] **Accessibility**: subtitles for cues, FOV slider, motion reduction, colorblind-safe fuel state
- [ ] **Optimization pass**: occlusion bake, visibility ranges, draw call audit, shader variant prune

### Acceptance

- First-time player understands fuel scarcity within 30 s, without text.
- No visible LOD pop within 40 m at walking speed.
- Zero audio dropouts during a 200-zombie night.

### Gate

Record a 90 s trailer cut. If it does not look like a game people would wishlist, return to art direction, not to features.

---

## Phase 6 — Ship

**Duration** 3 weeks · **Goal** On Steam, stable, with a demo that converts.

### Workstreams

- [ ] Steamworks via GodotSteam: app ID, achievements (3), cloud saves
- [ ] Build pipeline: signed Windows + Linux exports, version stamp, reproducible
- [ ] Perf certification on 3 machines: min-spec laptop, mid desktop, Steam Deck
- [ ] Crash reporting and a local log bundle on crash
- [ ] Store page: capsule art, 6 screenshots, 90 s trailer, short description
- [ ] Demo build: nights 1–3, save carryover into full game
- [ ] Press/creator kit, 20 keys, 2-week outreach
- [ ] Launch checklist: pricing, regional, refund policy read, day-one patch plan

### Acceptance

- Demo runs 30 min on min-spec without a crash.
- Store page live 4 weeks before launch.
- No P0 bugs open 72 h before launch.

### Gate

Ship. Then measure wishlist conversion and night-3 drop-off before planning any content update.

---

## 4. Cross-cutting tracks

### Performance (every phase, weekly)

Run the harness every Friday. Commit `perf.json` history. A regression over 10% blocks the next feature merge until explained.

### Testing

| Layer | What | Where |
|---|---|---|
| Unit | utility scoring, wave budget, flow field, save migration | GUT, headless CI |
| Integration | night loop, door breach, villager pathing | scene tests |
| Perf | frame time, draw calls, VRAM | harness scene |
| Manual | feel, readability, fairness | weekly recording |

### Assets

Every asset enters through the pipeline. No exceptions, no "I'll optimize it later." Later never comes.

### Scope control

When behind, cut in this order: archetype count → bell mechanic → fire spread → villager jobs (4→2) → stats screen → demo nights (3→2). Never cut: flame feel, 200-zombie perf, permadeath, dusk transition.

---

## 5. Asset strategy (why the dataset is not the village)

Measured from `data/train-00000-of-00001.parquet` on 2026-10-24:

| Fact | Value |
|---|---|
| Rows | 1,342 (~39 GB) |
| Formats | 1,138 GLB, 133 blend+glb, 41 SPZ, 23 PLY, 21 VOX, 7 FBX |
| Rows with a text prompt | 373 / 1,342 |
| Distinct generators | 15+ |
| Sample GLB | 67 MB |
| Settings seen | `targetPolycount` 150k–200k, `maxFaceNum` 40k–150k, `textureSize` 4096 |
| License | CC-BY-4.0, credit "Scenario" |

The previews are isolated product shots in incompatible styles: a wooden toy plane, a cel-shaded hooded figure, a photoreal potion table, a stylized chest. There are no rigs, no modular architecture, no LODs, no collision, no tiling materials.

Use it for: hero props, set dressing, silhouettes, oddities that make the village feel authored.

Do not use it for: buildings you compose, characters, terrain, anything needing animation.

Fetch only what you need:

```bash
hf download scenario-labs/3d-collection --repo-type dataset \
  --include "assets/*/*.glb" --local-dir raw/
```

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation | Owner phase |
|---|---|---|---|---|
| Flame does not feel dangerous | Med | Fatal | 5 s clip test at day 4; iterate VFX + audio before systems | 1 |
| Horde perf below 60 fps | Med | Fatal | Flow field + animation LOD designed in Phase 1, not retrofitted | 1 |
| Style incoherence across AI assets | High | High | One generator family, 3-hue palette, global desaturation | 3 |
| Villager AI reads as dumb | Med | High | Utility formula tuned in Phase 2, instrumented stuck detection | 2 |
| Asset pipeline eats the schedule | Med | High | Timeboxed to 1 week; fall back to KayKit-only shell | 3 |
| Scope creep after playtests | High | High | Fixed cut list in §4 | all |
| CC-BY attribution missed | Low | Med | Provenance ledger from asset one; credits screen generated from it | 3 |
| Steam launch with no audience | Med | Med | Store page + demo 4 weeks early; Next Fest submission | 6 |

---

## 7. Project layout

```
godor/
  AGENTS.md               # conventions, budgets, task granularity rules
  PLAN.md                 # this file
  project.godot
  assets/
    props/                # cleaned dataset output + manifest.json
    village/              # modular kit
    characters/           # shared skeleton, clips
    audio/
  scenes/
    levels/village.tscn
    actors/player.tscn
    actors/villager.tscn
    actors/zombie.tscn
    systems/perf_harness.tscn
  src/
    core/                 # GameClock, EventBus, SaveGame, NightDirector
    actors/               # Player, Villager, Zombie
    ai/                   # UtilityBrain, Steering, FlowField
    combat/               # Flamethrower, Damageable, FireSpread
    village/              # House, Door, Boarding
    ui/
  resources/              # all tuning: .tres
  tests/
  tools/
    pipeline/             # blender headless, gltf-transform, budget check
    ci/
  docs/
    decisions/            # one-page ADRs
    provenance.csv
```

### Task granularity

Every task is at most one day, has a written acceptance check, and lands as one commit. If a task cannot be verified without a human watching, it is two tasks.

---

## 8. Tuning defaults to revisit

These are starting points. Expect every one to move during Phase 4.

| Value | Start | Likely direction |
|---|---|---|
| Burn rate | 6/s | Faster (more tension) |
| Refills per night | 1 | 1, occasionally 0 |
| Zombie lunge speed | 4.5 | Slower (fairness) |
| Door HP | 200 | Higher (less punishing) |
| Night length | 5 min | 4 min (pacing) |
| Boarding time | 4 s | 3 s |
| Bell charges | 3 | 2 |

---

## 9. Definition of done, per phase

A phase is done when all four are true:

1. Gate metric measured and recorded, not estimated.
2. `perf.json` committed and within budget.
3. No P1 bug older than the phase start.
4. A 60 s recording exists showing the phase's headline feature.

Anything less is "nearly done," which is not done.
