"""Headless Blender cleaner for imported GLB props.

Run through Blender, not plain Python:

    blender -b -P tools/pipeline/blender_clean.py -- \
        raw/props/lantern.glb assets/props/hero/lantern.glb --target-tris 15000

What it does, in order: import, drop cameras/lights, apply transforms, weld
duplicate vertices, triangulate, decimate to the triangle budget, recalculate
normals, and export a single GLB with materials preserved.

It does not download anything and it does not guess licences. Add a row to
docs/provenance.csv for every output file.
"""

from __future__ import annotations

import argparse
import sys

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("--target-tris", type=int, default=15_000)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path: str) -> None:
    bpy.ops.import_scene.gltf(filepath=path)


def remove_non_mesh_objects() -> None:
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT", "EMPTY"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def main() -> int:
    args = parse_args()
    clear_scene()
    import_glb(args.source)
    remove_non_mesh_objects()

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if not meshes:
        print("no mesh objects after import", file=sys.stderr)
        return 1

    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()

    joined = bpy.context.view_layer.objects.active
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")

    triangles = len(joined.data.loop_triangles) or sum(
        max(0, len(poly.vertices) - 2) for poly in joined.data.polygons
    )
    if triangles > args.target_tris:
        ratio = args.target_tris / float(triangles)
        modifier = joined.modifiers.new("Decimate", "DECIMATE")
        modifier.ratio = ratio
        bpy.context.view_layer.objects.active = joined
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        print(f"decimated {triangles} -> target {args.target_tris} tris")

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    bpy.ops.export_scene.gltf(
        filepath=args.destination,
        export_format="GLB",
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"wrote {args.destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
