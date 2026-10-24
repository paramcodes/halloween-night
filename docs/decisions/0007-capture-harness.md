# ADR-0007: Offline capture harness for feel clips

- **Status:** accepted
- **Date:** 2026-10-25
- **Context:** The Phase 1 gate asks for a recording of the flame in first
  contact, and Phase 5 ends in a trailer. The development machine renders this
  scene at roughly 13 fps, so a screen recording would show a stuttering build
  and a plume sampled at the wrong moments. Godot's Movie Maker mode renders
  offline at a fixed timestep, which decouples the clip from the machine's frame
  rate.
- **Context:** The first probes failed in specific, diagnosable ways: the plume
  read as a solid vertical bar (square untextured quads seen end-on), burning
  zombies glowed flat red (body-wide emission at night), and a walking crowd
  reached the player and filled the lens inside five seconds.

## Decision

1. **Capture the real composition root.** `--capture` is a flag on `main.gd`,
   not a separate demo scene. The village, horde, HUD, flamethrower and damage
   path are the shipped ones; `CaptureRig` only stages bodies and schedules the
   trigger.
2. **Offline render, fixed timestep.** `tools/capture.sh` runs
   `godot --write-movie --fixed-fps`. Defaults: 8 s at 30 fps, PNG sequence
   encoded to H.264 at 1280×720. An `.avi` output path writes MJPEG directly and
   skips ffmpeg.
3. **State what is staged.** `capture.json` records `staged: true`,
   `player_invulnerable: true`, the seed, kill count, GPU, engine version and
   frame count. The README says the same in prose. The clip is evidence of how
   the flame reads, not a playthrough.
4. **Hold the crowd.** `Zombie.hold_at()` keeps a staged body on its mark while
   damage, burning and death still run. Without it, a 1.4 m/s shambler crosses
   the 9 m staging ring before the take ends.
5. **Shoot from the flank.** The take uses a second camera at the player's right
   side. Firing straight away from an over-the-shoulder lens foreshortens the
   plume into a blob, so the in-game view cannot show plume length.
6. **The clip does not pass a gate by itself.** "Reads as dangerous" is a human
   judgement, and frame time still requires reference hardware. The clip is
   necessary evidence, not a pass.

## Consequences

- A capture needs a window (`DRIVER=x11` here; Wayland throttles presentation)
  and about two minutes per 8 s at 30 fps on the HD 4400.
- Movie Maker records at the project's 1600×900 viewport; the encoder downscales
  to 1280×720, so the committed clip is not a resolution claim.
- The clip forced real VFX work, recorded in the same commit: a soft radial puff
  texture for particle quads, additive blending at lower energy, a longer-lived
  plume with turbulence, a per-body ember emitter that exists only while the
  body burns, and a charred rather than self-illuminated burn material.
- `docs/evidence/flame_feel.mp4` is committed (1.2 MB). `capture.json` is
  committed beside it as provenance; a regenerated take overwrites both.
