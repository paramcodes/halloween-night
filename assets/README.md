# Assets

The village and environment remain a procedural greybox: every building mesh is
generated at runtime by `src/core/mesh_factory.gd`. The only imported binaries
are the rigged KayKit characters in `assets/characters/kaykit/`.

## Character pack

- **KayKit Adventurers 1.0** and **KayKit Skeletons 1.0**, both CC0-1.0.
- Eight glTF models with embedded textures and animation libraries: 76 clips for
  adventurers, 95 for skeletons.
- `tools/pipeline/blender_character.py` joins skinned meshes, preserves the
  armature and actions, strips weapons and accessories, and can merge every
  surface into material slot 0.
- Skeletons use one surface and one material per zombie. Adventurers keep
  helmet and cape accessories; the player and four villagers are the only
  characters that use them.
- Godot extracts each embedded texture to a sidecar PNG during import. The PNGs
  and the GLBs are both listed in `manifest.json` and `docs/provenance.csv`.

## Rules

1. Fetch source files into `raw/` (gitignored), never straight into `assets/`.
2. Run the Blender pipeline and import with `godot --headless --path . --import`.
3. Add a provenance row and a manifest row for every binary file.
4. Run `python3 tools/ci/check_assets.py` before a merge.

Budgets per class live in `tools/ci/check_assets.py` and mirror `PLAN.md`
section 2.
