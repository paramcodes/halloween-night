#!/usr/bin/env bash
# Rebuild the eight shipped KayKit characters from the gitignored raw sources.
#
#   tools/pipeline/process_characters.sh
#
# Override RAW_DIR or OUT_DIR to work outside the repository layout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RAW_DIR="${RAW_DIR:-$ROOT/raw/kaykit}"
OUT_DIR="${OUT_DIR:-$ROOT/assets/characters/kaykit}"
BLENDER="${BLENDER:-blender}"
PIPELINE="$ROOT/tools/pipeline/blender_character.py"

if ! command -v "$BLENDER" >/dev/null 2>&1; then
	echo "blender binary not found: $BLENDER" >&2
	exit 1
fi

mkdir -p "$OUT_DIR"

# Adventurers keep helmets and capes; only weapons and held props are removed by
# the pipeline's name tokens. Skeletons collapse to one surface and one material
# so a zombie costs a single draw surface.
for name in Knight Barbarian Mage Rogue Rogue_Hooded; do
	"$BLENDER" -b -P "$PIPELINE" -- \
		"$RAW_DIR/$name.glb" "$OUT_DIR/$name.glb"
done

for name in Skeleton_Minion Skeleton_Rogue Skeleton_Warrior; do
	"$BLENDER" -b -P "$PIPELINE" -- \
		"$RAW_DIR/$name.glb" "$OUT_DIR/$name.glb" \
		--drop-accessories --single-material
done

echo "wrote eight characters to $OUT_DIR"
echo "run: godot --headless --path . --import"
