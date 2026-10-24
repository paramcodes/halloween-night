# ADR-0006: Rigged KayKit characters and manual animation LOD

- Status: accepted
- Date: 2026-10-25

## Context

The greybox actors used a generated capsule humanoid with no skeleton. Swapping
in animated characters affects the draw-call budget, the animation update cost,
and every actor state machine. The 200-zombie night must still fit the budgets in
`PLAN.md` section 2 on reference hardware.

## Decision

Use **KayKit Adventurers 1.0** and **KayKit Skeletons 1.0**, both CC0-1.0.
Eight models cover the cast: Knight, Barbarian, Mage, Rogue, Rogue Hooded, and
three skeletons. `Skeleton_Mage` is not imported.

`tools/pipeline/process_characters.sh` runs the Blender cleaner headless for all
eight models. `blender_character.py` does the work:

- joins the skinned meshes while preserving the armature, vertex groups, and all
  actions;
- removes weapon, shield, staff, mug, and other hand accessories;
- with `--single-material`, remaps every polygon to material slot 0 so a
  skeleton is one surface. This is required: two surfaces per zombie doubles the
  shadow and main passes and pushes draw calls over budget.

Godot imports each GLB with its own armature and embedded animation library.
Instances of one archetype share the imported resources, so 200 shamblers do not
duplicate 95 clips. This is a deliberate deviation from the "one animation
library for every humanoid" line in `PLAN.md`: KayKit ships compatible bone names
but separate clip libraries. Retargeting every model into one shared library is
deferred until it buys something measurable.

Animation is manual. `CharacterVisual` sets the `AnimationPlayer` to manual
callback mode and calls `advance()` from the actor:

- LOD 0, under 15 m: advance every physics frame.
- LOD 1, under 35 m: advance once per 100 ms.
- LOD 2, beyond 35 m: freeze the pose.

The model is scaled to the capsule (player 0.82, villagers 0.80, shambler and
runner 0.82, brute 1.0). The visual faces the actor's movement or aim direction;
the hand bone drives the flamethrower nozzle.

## Consequences

- A zombie costs one surface, so 200 zombies plus shadows stay under the 800
  draw-call budget (measured p95 496 with the flame in the load).
- Skeletons keep 95 clips and a full humanoid skeleton; the per-archetype shared
  library keeps resident memory flat across the horde.
- The player, four villagers, and three zombie archetypes use eight GLBs and
  sixteen binary files including extracted textures.
- The glow eye material is merged into the skeleton texture. Eyes still read as
  yellow; there is no separate emissive pass.
- The perf harness holds the staged ring at zero speed. Without that, the horde
  collapses onto the camera and the sample measures a dozen bodies instead of
  200, which is not comparable run to run.
