#!/usr/bin/env bash
# Run the 200-zombie stress harness and enforce the strict performance budget.
# Needs a GPU and a real window. On an integrated GPU this is expected to fail;
# that failure is evidence, not something to hide.
#
#   tools/perf.sh [seconds] [warmup]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"
DURATION="${1:-20}"
WARMUP="${2:-4}"

"$GODOT" --path . -- --perf --seconds "$DURATION" --warmup "$WARMUP"
cp perf.json docs/evidence/perf.json
python3 tools/ci/check_perf.py --mode strict --path docs/evidence/perf.json
