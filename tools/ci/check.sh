#!/usr/bin/env bash
# The local and CI quality gate. Run from anywhere inside the repository.
#
#   tools/ci/check.sh                  # import, lint-if-installed, tests, asset checks
#   tools/ci/check.sh --require-lint   # fail when gdtoolkit is missing (CI)
#   tools/ci/check.sh --perf-strict    # also enforce perf budgets (reference hardware)
#   tools/ci/check.sh --no-perf        # skip perf.json validation
#
# Godot is not installed for you. Set GODOT=/path/to/godot to override.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"
PERF_MODE="schema"
REQUIRE_LINT=0
LOG_DIR="${LOG_DIR:-$ROOT/.ci}"
mkdir -p "$LOG_DIR"

for arg in "$@"; do
	case "$arg" in
		--require-lint) REQUIRE_LINT=1 ;;
		--perf-strict) PERF_MODE="strict" ;;
		--no-perf) PERF_MODE="skip" ;;
		-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "godot binary not found: $GODOT" >&2
	echo "set GODOT=/path/to/godot or put godot on PATH" >&2
	exit 1
fi

echo "== godot =="
"$GODOT" --version

echo "== import =="
if ! "$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1; then
	cat "$LOG_DIR/import.log"
	exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error|Could not resolve script" "$LOG_DIR/import.log"; then
	cat "$LOG_DIR/import.log"
	echo "import produced script errors" >&2
	exit 1
fi

echo "== format =="
if command -v gdformat >/dev/null 2>&1; then
	gdformat --check src tests tools
elif [ "$REQUIRE_LINT" -eq 1 ]; then
	echo "gdformat missing; install gdtoolkit" >&2
	exit 1
else
	echo "gdformat missing; skipped (run with --require-lint to enforce)"
fi

echo "== lint =="
if command -v gdlint >/dev/null 2>&1; then
	gdlint src tests tools
elif [ "$REQUIRE_LINT" -eq 1 ]; then
	echo "gdlint missing; install gdtoolkit" >&2
	exit 1
else
	echo "gdlint missing; skipped (run with --require-lint to enforce)"
fi

echo "== tests =="
"$GODOT" --headless --path . res://tests/test_runner.tscn 2>&1 | tee "$LOG_DIR/tests.log"
if ! grep -qE "^\[TEST\] [0-9]+ assertions, 0 failures" "$LOG_DIR/tests.log"; then
	echo "test runner did not report a clean pass" >&2
	exit 1
fi

echo "== assets =="
python3 tools/ci/check_assets.py

if [ "$PERF_MODE" != "skip" ]; then
	if [ -f perf.json ]; then
		echo "== perf =="
		python3 tools/ci/check_perf.py --mode "$PERF_MODE"
	elif [ -f docs/evidence/perf.json ]; then
		echo "== perf (committed evidence, schema only) =="
		python3 tools/ci/check_perf.py --mode schema --path docs/evidence/perf.json
	else
		echo "== perf =="
		echo "no perf report; run tools/perf.sh on reference hardware (skipped)"
	fi
fi

echo "OK"
