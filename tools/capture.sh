#!/usr/bin/env bash
# Record the feel clip with Godot's Movie Maker mode. Needs a real window and a
# GPU; a headless run cannot render frames.
#
#   tools/capture.sh [seconds] [fps] [out]
#
# Defaults: 8 s at 30 fps, 1280x720, docs/evidence/flame_feel.mp4.
# An `.avi` output is written by Godot directly; anything else is written as a
# PNG sequence and encoded with ffmpeg (smaller file, same frames).
# The output is gameplay, but the crowd is staged and the player is invulnerable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"
DURATION="${1:-8}"
FPS="${2:-30}"
OUT="${3:-docs/evidence/flame_feel.mp4}"
RES="${RES:-1280x720}"

case "$OUT" in
	/*) OUT_ABS="$OUT" ;;
	*) OUT_ABS="$ROOT/$OUT" ;;
esac

if [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
	echo "capture needs a real window: set DISPLAY or WAYLAND_DISPLAY" >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT_ABS")"
rm -f "$OUT_ABS" capture.json
rm -rf build/capture
mkdir -p build
touch build/.gdignore

MOVIE_TARGET="$OUT_ABS"
if [ "${OUT_ABS##*.}" != "avi" ]; then
	if ! command -v ffmpeg >/dev/null 2>&1; then
		echo "ffmpeg is required for $OUT; pass an .avi path to skip encoding" >&2
		exit 1
	fi
	mkdir -p build/capture
	MOVIE_TARGET="$ROOT/build/capture/frame.png"
fi

"$GODOT" --path . \
	--write-movie "$MOVIE_TARGET" \
	--fixed-fps "$FPS" \
	--resolution "$RES" \
	--audio-driver Dummy \
	${DRIVER:+--display-driver "$DRIVER"} \
	-- --capture --fresh --seconds "$DURATION" 2>&1 | tee docs/evidence/capture.log

if [ "$OUT_ABS" != "$MOVIE_TARGET" ]; then
	first_frame=$(find build/capture -name 'frame*.png' | head -1 || true)
	if [ -z "$first_frame" ]; then
		echo "capture produced no frames" >&2
		exit 1
	fi
	ffmpeg -y -loglevel error -framerate "$FPS" -i "$ROOT/build/capture/frame%08d.png" \
		-c:v libx264 -pix_fmt yuv420p -crf 23 -vf scale=1280:720 -movflags +faststart \
		"$OUT_ABS"
fi

if [ ! -s "$OUT_ABS" ]; then
	echo "capture produced no movie at $OUT" >&2
	exit 1
fi
cp capture.json docs/evidence/capture.json
ls -lh "$OUT_ABS"
echo "clip: $OUT"
