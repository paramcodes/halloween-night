#!/usr/bin/env python3
"""Validate a Godor perf report against the budget in PLAN.md section 2.

Two modes:

  schema  Structural validation only. Used by CI, where no GPU is available.
          Also refuses reports that measured an empty scene (a harness that
          silently culls its own horde must not look fast).
  strict  Schema plus every performance budget. Run on reference hardware.

Examples:
    python3 tools/ci/check_perf.py --mode schema
    python3 tools/ci/check_perf.py --mode strict --path docs/evidence/perf.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BUDGETS = {
    "frame_p95_ms": 16.6,
    "cpu_p50_ms": 8.0,
    "draw_calls_p95": 800,
    "triangles_p50": 1_500_000,
    "vram_mb": 2500,
}

# A 200-zombie run that stages the horde in front of the camera cannot render
# fewer than these. Lower values mean the measurement is hiding geometry.
# Godot batches identical zombie surfaces, so the triangle count is the reliable
# horde guard; the draw-call floor only catches a nearly empty view.
SCHEMA_FLOORS = {
    "draw_calls_p95": 80,
    "triangles_p50": 100_000,
    "samples": 10,
}


def load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"perf report not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"perf report is not valid JSON: {exc}")


def dig(report: dict, dotted: str):
    value = report
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


def collect(report: dict) -> tuple[dict[str, float], list[str]]:
    metrics: dict[str, float] = {}
    errors: list[str] = []
    sources = {
        "frame_p95_ms": "frame_ms.p95",
        "cpu_p50_ms": "process_ms.p50",
        "draw_calls_p95": "draw_calls.p95",
        "triangles_p50": "triangles.p50",
        "vram_mb": "vram_mb",
    }
    for name, path in sources.items():
        value = dig(report, path)
        if not isinstance(value, (int, float)):
            errors.append(f"missing or non-numeric metric {path}")
            continue
        metrics[name] = float(value)
    return metrics, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode",
        choices=("schema", "strict"),
        default="schema",
        help="schema validates structure only; strict also enforces budgets",
    )
    parser.add_argument(
        "--path",
        type=Path,
        default=Path("perf.json"),
        help="path to perf.json (default: ./perf.json)",
    )
    args = parser.parse_args()

    report = load(args.path)
    metrics, errors = collect(report)

    zombies_end = report.get("zombies_end")
    zombies_target = report.get("zombies_target")
    if zombies_end != zombies_target:
        errors.append(
            f"horde not full at end of run: {zombies_end}/{zombies_target} alive"
        )
    if int(report.get("samples") or 0) < SCHEMA_FLOORS["samples"]:
        errors.append(f"too few samples: {report.get('samples')}")
    for name in ("draw_calls_p95", "triangles_p50"):
        if name in metrics and metrics[name] < SCHEMA_FLOORS[name]:
            errors.append(
                f"{name}={metrics[name]:.0f} is below the measurement floor "
                f"{SCHEMA_FLOORS[name]}; the harness probably rendered an empty view"
            )

    print(f"perf report: {args.path}")
    print(f"  engine      {report.get('engine', '?')}")
    print(f"  gpu         {report.get('gpu', '?')}")
    print(f"  window      {report.get('window', '?')}")
    print(f"  samples     {report.get('samples', '?')}")
    print(f"  zombies     {zombies_end}/{zombies_target}")
    for name, budget in BUDGETS.items():
        if name not in metrics:
            continue
        value = metrics[name]
        verdict = "PASS" if value <= budget else "FAIL"
        print(f"  {name:<16} {value:>10.2f}  budget {budget:>10}  {verdict}")

    gpu = str(report.get("gpu", ""))
    target_hardware = not any(
        token in gpu.lower() for token in ("hd graphics", "uhd graphics", "llvmpipe", "swiftshader")
    )
    if not target_hardware:
        print("  NOTE        integrated GPU detected; strict budget is not meaningful here")

    if args.mode == "strict":
        for name, budget in BUDGETS.items():
            if name in metrics and metrics[name] > budget:
                errors.append(f"{name}={metrics[name]:.2f} exceeds budget {budget}")

    if errors:
        print("\nFAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"\nOK ({args.mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
