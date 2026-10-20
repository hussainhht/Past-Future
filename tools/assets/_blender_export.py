"""Blender-side helper for convert_models.py: import one model file and export it as a binary glTF.

Imported by convert_models.py when the `bpy` module is installed, or run inside Blender:
  blender --background --factory-startup --python tools/assets/_blender_export.py -- SRC DST

Only geometry formats are imported. .blend files are never opened and no script is executed.
Nothing is scaled, recentred or re-materialled here; the export is a faithful format conversion.
"""
from pathlib import Path
import sys

import bpy

IMPORTERS = {
    ".fbx": lambda path: bpy.ops.import_scene.fbx(filepath=path),
    ".obj": lambda path: bpy.ops.wm.obj_import(filepath=path),
    ".gltf": lambda path: bpy.ops.import_scene.gltf(filepath=path),
    ".glb": lambda path: bpy.ops.import_scene.gltf(filepath=path),
}


def unloadable_textures() -> list:
    """Texture files the importer referenced but could not read. Blender exports those untextured, silently."""
    return sorted({Path(image.filepath).name or image.name for image in bpy.data.images
                   if image.source == "FILE" and image.users and (tuple(image.size) == (0, 0) or not image.has_data)})


def convert(source, destination) -> tuple:
    """Import source and write destination as GLB. Returns (tool description, unloadable texture names)."""
    suffix = Path(source).suffix.lower()
    if suffix not in IMPORTERS:
        raise ValueError(f"Cannot convert '{suffix}' files; supported: {', '.join(sorted(IMPORTERS))}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.use_scripts_auto_execute = False
    IMPORTERS[suffix](str(source))
    if not any(obj.type == "MESH" for obj in bpy.data.objects):
        raise ValueError(f"'{source}' imported no mesh objects")
    missing = unloadable_textures()
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(destination), export_format="GLB", export_apply=False, export_yup=True,
        export_cameras=False, export_lights=False, export_animations=True, export_image_format="AUTO",
        use_selection=False)
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF export did not finish: {result}")
    return f"Blender {bpy.app.version_string}", missing


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(arguments) != 2:
        sys.exit("usage: blender --background --factory-startup --python _blender_export.py -- SRC DST")
    tool, absent = convert(*arguments)
    print("CONVERTED_WITH", tool)
    for name in absent:
        print("MISSING_TEXTURE", name)
