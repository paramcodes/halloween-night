#!/usr/bin/env bash
# Compress a cleaned GLB with gltf-transform. Requires Node and network on the
# first run; the tool is fetched through npx and never vendored.
#
#   tools/pipeline/optimize_glb.sh in.glb out.glb [max-texture-size]
#
# Keeps one LOD and a 1K texture by default. Hero props may pass 1024; filler
# props should pass 512.
set -euo pipefail

if [ "$#" -lt 2 ]; then
	echo "usage: $0 <input.glb> <output.glb> [max-texture-size]" >&2
	exit 2
fi

SRC="$1"
DST="$2"
TEXTURE="${3:-1024}"

if ! command -v npx >/dev/null 2>&1; then
	echo "npx not found; install Node.js to run gltf-transform" >&2
	exit 1
fi

mkdir -p "$(dirname "$DST")"
npx --yes @gltf-transform/cli optimize "$SRC" "$DST" \
	--compress draco \
	--texture-compress webp \
	--texture-size "$TEXTURE" \
	--instance false

echo "wrote $DST"
echo "next: python3 tools/pipeline/manifest.py --write"
