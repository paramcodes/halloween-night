"""Rig-preserving character cleaner for KayKit GLB sources.

Run through Blender:

    blender -b -P tools/pipeline/blender_character.py -- \
        raw/kaykit/Knight.glb assets/characters/kaykit/Knight.glb

What it does: import, drop cameras/lights, remove weapon/accessory meshes,
join the remaining skinned meshes under the armature, keep every vertex group
and every imported action, then export one GLB with the rig and animations.

Unlike `blender_clean.py`, this never applies an armature modifier, never
triangulates the skinned mesh, and never decimates. Those operations destroy
or distort skin weights.
"""

from __future__ import annotations

import argparse
import sys

import bpy

DROP_TOKENS = (
    "Sword",
    "Shield",
    "Staff",
    "Wand",
    "Bow",
    "Crossbow",
    "Dagger",
    "Axe",
    "Arrow",
    "Quiver",
    "Spellbook",
    "Mug",
    "Smokebomb",
)


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument(
        "--drop-accessories",
        action="store_true",
        help="Remove bone-parented helmets, capes and hoods to save draw calls.",
    )
    parser.add_argument(
        "--single-material",
        action="store_true",
        help="Merge every surface into material slot 0 so the mesh is one draw call.",
    )
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.source)

    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    kept = [
        obj
        for obj in meshes
        if not any(token.lower() in obj.name.lower() for token in DROP_TOKENS)
    ]
    dropped = [obj for obj in meshes if obj not in kept]
    for obj in dropped:
        bpy.data.objects.remove(obj, do_unlink=True)
    if not kept:
        print("no skinned meshes left after dropping accessories", file=sys.stderr)
        return 1

    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        print(f"expected one armature, found {len(armatures)}", file=sys.stderr)
        return 1

    skinned = [obj for obj in kept if obj.vertex_groups]
    accessories = [obj for obj in kept if not obj.vertex_groups]
    if not skinned:
        print("no skinned meshes left; refusing to export a static character", file=sys.stderr)
        return 1
    if args.drop_accessories:
        for obj in accessories:
            bpy.data.objects.remove(obj, do_unlink=True)
        kept = skinned
        accessories = []

    bpy.ops.object.select_all(action="DESELECT")
    for obj in skinned:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = skinned[0]
    if len(skinned) > 1:
        bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = "Body"

    if not merged.vertex_groups:
        print("merged mesh has no vertex groups; skinning would be lost", file=sys.stderr)
        return 1
    if not any(mod.type == "ARMATURE" for mod in merged.modifiers):
        print("merged mesh has no armature modifier", file=sys.stderr)
        return 1

    if args.single_material and merged.data.materials:
        first = merged.data.materials[0]
        for poly in merged.data.polygons:
            poly.material_index = 0
        merged.data.materials.clear()
        merged.data.materials.append(first)

    bpy.ops.object.select_all(action="DESELECT")
    merged.select_set(True)
    for obj in accessories:
        obj.select_set(True)
    armatures[0].select_set(True)
    bpy.context.view_layer.objects.active = armatures[0]

    bpy.ops.export_scene.gltf(
        filepath=args.destination,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    tris = sum(max(0, len(poly.vertices) - 2) for poly in merged.data.polygons)
    print(
        f"wrote {args.destination}: {len(merged.data.vertices)} verts, "
        f"{tris} tris, {len(merged.data.materials)} materials, "
        f"{len(bpy.data.actions)} actions, dropped {len(dropped)} accessories"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
