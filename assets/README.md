# Assets

This directory is intentionally empty in the greybox build. Every visible mesh
is generated at runtime by `src/core/mesh_factory.gd`; no third-party art is
committed.

The Scenario 3D collection referenced by `PLAN.md` has **not** been downloaded:
it is about 39 GB and most rows are isolated product shots, not modular
architecture or rigged characters. `PLAN.md` section 5 already explains why it
is unsuitable as a village kit.

## When real assets land

1. Fetch only the files you need into `raw/` (gitignored).
2. Run `tools/pipeline/blender_clean.py` to normalise, decimate, and re-export.
3. Run `tools/pipeline/optimize_glb.sh` for texture and buffer compression.
4. Add a row to `docs/provenance.csv` for every file. CC-BY-4.0 needs the
   "Scenario" credit and the dataset id.
5. Record class and triangle count in `assets/**/manifest.json`.
6. `python3 tools/ci/check_assets.py` must pass before a merge.

Triangle budgets per class live in `tools/ci/check_assets.py` and mirror
`PLAN.md` section 2.
