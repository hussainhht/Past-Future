"""Editable professor source and geometry export, isolated from the student.

Run with Blender: blender --background --python tools/professor_blender.py -- --create
Options: --create (rebuild source), --export (save hand-edited geometry), --render.
Export retains the 77 source clips; edited Blender animation keys are not exported.
"""
import argparse
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector
import student_blender as shared
from build_professor import Professor, OUTPUT, REFERENCES
from student_mesh import ROOT

BLEND = OUTPUT / "source/professor.blend"


def create():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUTPUT / "professor.glb"))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    imported = next(o for o in bpy.data.objects if o.name == "Student_SkinnedMesh")
    materials = {m.name: m for m in imported.data.materials}
    bpy.data.objects.remove(imported, do_unlink=True)
    professor = Professor()
    professor.create()
    collection = bpy.data.collections.new("Character meshes")
    bpy.context.scene.collection.children.link(collection)
    face_offsets = {}
    for part in professor.parts:
        color = part["material"]
        g = professor.geometry[color]
        start = part["vertex_start"]
        end = start + part["vertex_count"]
        offset = face_offsets.get(color, 0)
        faces = g["faces"][offset:offset + part["triangles"]]
        face_offsets[color] = offset + part["triangles"]
        data = bpy.data.meshes.new(part["name"])
        data.from_pydata([(p[0], -p[2], p[1]) for p in g["vertices"][start:end]], [],
                         [[i - start for i in f] for f in faces])
        data.update()
        obj = bpy.data.objects.new(part["name"], data)
        collection.objects.link(obj)
        data.materials.append(materials[color])
        for poly in data.polygons:
            poly.use_smooth = True
        normals=[g.get('normal_overrides',{}).get(i) for i in range(start,end)]
        if all(n is not None for n in normals):
            data.normals_split_custom_set_from_vertices([(n[0],-n[2],n[1]) for n in normals])
        groups = {}
        for i, values in enumerate(g["weights"][start:end]):
            weights = sorted([(k,w) for k,w in values.items() if w > 1e-8], key=lambda kv: -kv[1])[:4]
            total = sum(w for _, w in weights)
            for name, value in weights:
                if name not in groups:
                    groups[name] = obj.vertex_groups.new(name=name)
                groups[name].add([i], float(value / total), "REPLACE")
        modifier = obj.modifiers.new("KayKit proportion rig", "ARMATURE")
        modifier.object = rig
        obj.parent = rig
    rig.show_in_front = True
    shared.setup_neutral(rig)
    refs = bpy.data.collections.new("Professor references (toggle to inspect)")
    bpy.context.scene.collection.children.link(refs)
    refs.hide_render = True
    refs.hide_viewport = True
    for filename in ["frontview.png", "backview.png", "sideview1.png", "sideview2.png"]:
        image = bpy.data.images.load(str(REFERENCES / filename))
        image.pack()
        obj = bpy.data.objects.new(filename, None)
        obj.empty_display_type = "IMAGE"
        obj.data = image
        obj.empty_display_size = 4
        obj.location = (0, .6, 1.15)
        obj.rotation_euler = (math.pi / 2, 0, 0)
        refs.objects.link(obj)
    for name in ["build_professor.py", "professor_blender.py", "fit_professor_face.py", "fit_professor_clothes.py", "build_student_kaykit.py",
                 "student_mesh.py", "student_rig.py", "ground_student_clips.py", "gltf_tools.py"]:
        bpy.data.texts.load(str(ROOT / "tools" / name))
    note = bpy.data.texts.new("READ ME - PROFESSOR")
    note.write("AGE 49 / PROFESSOR\n"
               "Named mesh parts are in Character meshes. The rig has 77 KayKit actions.\n"
               "References/49 images are packed in a hidden reference collection.\n"
               "Use Pose Mode and the Action Editor to inspect animations. NLA tracks start muted.\n"
               "Save hand edits in professor.blend. Geometry export: tools/professor_blender.py --export.\n"
               "This exporter preserves source clips; it does not export edited animation keys or rest bones.\n"
               "--create recreates the source from code and replaces manual changes.\n")
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Professor studio")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (.08, .09, .12, 1)
    background.inputs["Strength"].default_value = .3
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 572
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    bpy.ops.object.camera_add(location=(0, -8, 1.55))
    camera = bpy.context.object
    camera.name = "Professor review camera"
    camera.rotation_euler = (Vector((0, 0, 1.13)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.48
    scene.camera = camera
    for name, loc, power, size, color in [
        ("Warm key", (-3,-4,5), 430, 4, (1,.89,.77)),
        ("Cool fill", (3,-2,3), 180, 3, (.78,.85,1)),
        ("Hair rim", (1,3,4), 500, 3, (.78,.84,1)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        light.rotation_euler = (Vector((0,0,1.1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor = bpy.context.object
    floor.name = "Studio floor"
    floor.location.z = -.005
    material = bpy.data.materials.new("Studio charcoal")
    material.diffuse_color = (.018,.020,.028,1)
    floor.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    (BLEND.parent / ".gdignore").touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("PROFESSOR EDITABLE SOURCE:", BLEND)


def export_edits():
    # Reuse the tested mesh/weight extractor with a professor-specific profile.
    # These assignments are process-local; student tools and assets are unchanged.
    shared.Student = Professor
    shared.OUTPUT = OUTPUT
    shared.BLEND = BLEND
    shared.export_edits()
    import json
    path = OUTPUT / "manifest.json"
    manifest = json.loads(path.read_text())
    manifest["geometry"] = "Editable professor geometry exported by tools/professor_blender.py; KayKit clips preserved."
    path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    for option in ["create", "export", "render"]:
        group.add_argument("--" + option, action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    if args.create:
        create()
    elif args.export:
        export_edits()
    else:
        shared.OUTPUT = OUTPUT
        shared.BLEND = BLEND
        shared.render_views()
