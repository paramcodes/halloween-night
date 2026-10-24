#!/usr/bin/env python3
"""Build and validate the asset manifest used by tools/ci/check_assets.py.

Reads GLB/GLTF files already present under assets/, counts triangles from the
glTF accessors (no Blender, no network), and writes assets/manifest.json with
paths relative to the repository root.

    python3 tools/pipeline/manifest.py --write
    python3 tools/pipeline/manifest.py          # report only

Class inference:
    assets/characters/**  -> character
    assets/village/**     -> kit
    assets/props/hero/**  -> hero
    assets/props/**       -> filler
Override a file with --class when the path is ambiguous.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRI_BUDGETS = {"hero": 15_000, "filler": 1_000, "kit": 2_000, "character": 20_000}
GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A


def read_glb_json(path: Path) -> dict:
    with path.open("rb") as handle:
        header = handle.read(12)
        magic, version, _length = struct.unpack("<III", header)
        if magic != GLB_MAGIC or version != 2:
            raise ValueError("not a glTF 2.0 binary")
        while True:
            chunk_header = handle.read(8)
            if len(chunk_header) < 8:
                raise ValueError("JSON chunk missing")
            chunk_length, chunk_type = struct.unpack("<II", chunk_header)
            data = handle.read(chunk_length)
            if chunk_type == JSON_CHUNK:
                return json.loads(data.decode("utf-8"))


def read_gltf_json(path: Path) -> dict:
    return json.loads(path.read_text())


def triangle_count(document: dict) -> int:
    accessors = document.get("accessors", [])
    total = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            mode = primitive.get("mode", 4)
            if mode != 4:  # only triangle lists have a meaningful triangle count
                continue
            if "indices" in primitive:
                count = accessors[primitive["indices"]].get("count", 0)
            else:
                count = accessors[primitive.get("attributes", {}).get("POSITION", 0)].get("count", 0)
            total += count // 3
    return total


def infer_class(relative: Path) -> str:
    parts = relative.parts
    if parts and parts[0] == "characters":
        return "character"
    if parts and parts[0] == "village":
        return "kit"
    if len(parts) > 1 and parts[0] == "props" and parts[1] == "hero":
        return "hero"
    return "filler"


def scan(class_override: str | None) -> list[dict]:
    entries: list[dict] = []
    assets = ROOT / "assets"
    for path in sorted(assets.rglob("*")):
        if path.suffix.lower() not in {".glb", ".gltf"} or path.name == "manifest.json":
            continue
        try:
            document = read_glb_json(path) if path.suffix.lower() == ".glb" else read_gltf_json(path)
        except (ValueError, json.JSONDecodeError, struct.error) as exc:
            print(f"SKIP {path.relative_to(ROOT)}: {exc}", file=sys.stderr)
            continue
        relative = path.relative_to(ROOT).as_posix()
        entries.append(
            {
                "path": relative,
                "class": class_override or infer_class(path.relative_to(assets)),
                "triangles": triangle_count(document),
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write assets/manifest.json")
    parser.add_argument("--class", dest="asset_class", choices=sorted(TRI_BUDGETS))
    args = parser.parse_args()

    entries = scan(args.asset_class)
    if not entries:
        print("no glTF assets found (greybox build)")
        return 0

    failures = 0
    for entry in entries:
        budget = TRI_BUDGETS[entry["class"]]
        verdict = "ok" if entry["triangles"] <= budget else "OVER BUDGET"
        if entry["triangles"] > budget:
            failures += 1
        print(
            f"{entry['path']}: {entry['triangles']} tris "
            f"({entry['class']} budget {budget}) {verdict}"
        )

    if args.write:
        output = ROOT / "assets" / "manifest.json"
        output.write_text(json.dumps({"assets": entries}, indent=2) + "\n")
        print(f"wrote {output.relative_to(ROOT)}")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
