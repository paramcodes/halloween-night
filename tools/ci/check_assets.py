#!/usr/bin/env python3
"""Enforce the asset entrance rules from PLAN.md section 2.

The greybox repository intentionally contains no imported art. That is allowed
and reported as such. Once assets land they must:

  * appear in docs/provenance.csv (CC-BY-4.0 credit for Scenario assets),
  * be listed in a manifest with a class and triangle count,
  * stay inside the per-class triangle budget.

This script never downloads anything and never rewrites assets.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
PROVENANCE = ROOT / "docs" / "provenance.csv"

TRI_BUDGETS = {
    "hero": 15_000,
    "filler": 1_000,
    "kit": 2_000,
    "character": 20_000,
}

PROVENANCE_HEADER = [
    "asset_path",
    "source_dataset",
    "source_id",
    "license",
    "author",
    "retrieved",
    "sha256",
    "notes",
]


def read_provenance() -> tuple[list[dict[str, str]], list[str]]:
    errors: list[str] = []
    if not PROVENANCE.exists():
        return [], [f"missing provenance ledger: {PROVENANCE.relative_to(ROOT)}"]
    with PROVENANCE.open(newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != PROVENANCE_HEADER:
            errors.append(
                "provenance header mismatch: "
                f"{reader.fieldnames} != {PROVENANCE_HEADER}"
            )
        return list(reader), errors


def read_manifests() -> tuple[dict[str, dict], list[str]]:
    entries: dict[str, dict] = {}
    errors: list[str] = []
    for manifest in sorted(ASSETS.rglob("manifest.json")):
        try:
            data = json.loads(manifest.read_text())
        except json.JSONDecodeError as exc:
            errors.append(f"{manifest.relative_to(ROOT)}: invalid JSON ({exc})")
            continue
        for item in data.get("assets", []):
            path = str(item.get("path", ""))
            if not path:
                errors.append(f"{manifest.relative_to(ROOT)}: entry without path")
                continue
            entries[path] = item
    return entries, errors


def count_binary_files() -> list[Path]:
    if not ASSETS.exists():
        return []
    return [
        path
        for path in sorted(ASSETS.rglob("*"))
        if path.is_file()
        and path.suffix.lower() in {".glb", ".gltf", ".fbx", ".blend", ".png", ".jpg", ".wav", ".ogg", ".mp3"}
        and path.name != "manifest.json"
    ]


def main() -> int:
    errors: list[str] = []
    binaries = count_binary_files()
    provenance, provenance_errors = read_provenance()
    errors.extend(provenance_errors)
    manifests, manifest_errors = read_manifests()
    errors.extend(manifest_errors)

    if not binaries:
        print("assets: greybox only (no imported binaries)")
        print("  provenance ledger present:", PROVENANCE.exists())
        for error in errors:
            print(f"  FAIL {error}")
        return 1 if errors else 0

    print(f"assets: {len(binaries)} imported binaries")
    known = {row.get("asset_path", "") for row in provenance}
    for path in binaries:
        rel = path.relative_to(ROOT).as_posix()
        if rel not in known:
            errors.append(f"{rel}: missing from docs/provenance.csv")
        entry = manifests.get(rel)
        if entry is None:
            errors.append(f"{rel}: missing from a manifest.json")
            continue
        asset_class = entry.get("class")
        tris = entry.get("triangles")
        if asset_class not in TRI_BUDGETS:
            errors.append(f"{rel}: unknown class {asset_class!r}")
            continue
        if not isinstance(tris, int):
            errors.append(f"{rel}: manifest needs an integer 'triangles'")
            continue
        budget = TRI_BUDGETS[asset_class]
        if tris > budget:
            errors.append(f"{rel}: {tris} tris exceeds {asset_class} budget {budget}")

    if errors:
        print("FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
