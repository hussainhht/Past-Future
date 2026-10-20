"""Create an editable Blender file, or export artist edits without replacing clips.

python tools/student_blender.py --create
python tools/student_blender.py --export
Requires bpy, NumPy. The .blend stores named mesh parts, the retargeted armature,
77 source actions, materials, packed references, and embedded authoring scripts.
"""
import argparse
from pathlib import Path
import math
import json
import numpy as np
import bpy
from mathutils import Matrix, Vector
from build_student_kaykit import Student
from student_mesh import OUTPUT, ROOT, PALETTE

BLEND=OUTPUT/'source/student.blend'

def setup_neutral(rig):
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks: track.mute=True
    for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    for side,sign in [('l',-1),('r',1)]:
        p=rig.pose.bones['upperarm.'+side]
        rest=p.bone.matrix_local.copy()
        rotation=Matrix.Rotation(-math.radians(70)*sign,4,'Y')
        target=rotation @ rest
        target.translation=rest.translation
        p.matrix=target
    bpy.context.view_layer.update()


def create():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'student.glb'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    imported=next(o for o in bpy.data.objects if o.name=='Student_SkinnedMesh')
    materials={m.name:m for m in imported.data.materials}
    bpy.data.objects.remove(imported,do_unlink=True)
    student=Student();student.create()
    collection=bpy.data.collections.new('Character meshes'); bpy.context.scene.collection.children.link(collection)
    # Part ranges are recorded by the authoring geometry, so each lock and garment
    # remains individually selectable while all parts share the actual armature.
    face_offsets={}
    for part in student.parts:
        color=part['material'];g=student.geometry[color];start=part['vertex_start'];end=start+part['vertex_count']
        offset=face_offsets.get(color,0);faces=g['faces'][offset:offset+part['triangles']]
        face_offsets[color]=offset+part['triangles']
        vertices=[(p[0],-p[2],p[1]) for p in g['vertices'][start:end]]
        data=bpy.data.meshes.new(part['name']);data.from_pydata(vertices,[],[[i-start for i in f] for f in faces]);data.update()
        obj=bpy.data.objects.new(part['name'],data);collection.objects.link(obj)
        data.materials.append(materials[color])
        for poly in data.polygons: poly.use_smooth=True
        groups={}
        for i,values in enumerate(g['weights'][start:end]):
            weights=sorted([(k,w) for k,w in values.items() if w>1e-8],key=lambda kv:-kv[1])[:4]
            total=sum(v for _,v in weights)
            for name,value in weights:
                if name not in groups: groups[name]=obj.vertex_groups.new(name=name)
                groups[name].add([i],float(value/total),'REPLACE')
        modifier=obj.modifiers.new('KayKit proportion rig','ARMATURE'); modifier.object=rig
        obj.parent=rig
    rig.show_in_front=True
    setup_neutral(rig)
    refs=bpy.data.collections.new('Packed reference images (toggle to inspect)');bpy.context.scene.collection.children.link(refs)
    refs.hide_render=True;refs.hide_viewport=True
    for filename in ['frontview.png','backview.png','sideview1.png','sideview2.png']:
        img=bpy.data.images.load(str(ROOT/'assets/characters/references'/filename));img.pack()
        obj=bpy.data.objects.new(filename,None);obj.empty_display_type='IMAGE';obj.data=img
        obj.empty_display_size=4.0;obj.location=(0,.6,1.15);obj.rotation_euler=(math.pi/2,0,0);refs.objects.link(obj)
    for name in ['build_student_kaykit.py','student_mesh.py','student_rig.py','ground_student_clips.py','gltf_tools.py','student_blender.py']:
        bpy.data.texts.load(str(ROOT/'tools'/name))
    note=bpy.data.texts.new('READ ME')
    note.write('Original four-view student. All visible meshes are newly authored.\n'
               'Character meshes contains individually editable named parts with skin groups.\n'
               'Rig_Medium contains all 77 KayKit actions. NLA tracks are muted for neutral preview.\n'
               'To preview an action, select the rig and use the Action Editor (enable its slot).\n'
               'Export geometry edits: python tools/student_blender.py --export\n'
               'This retains the exact animation mapping and runtime mesh paths.\n'
               'Keep rig rest edits in student_rig.py and rebuild; geometry-only export does not export rig edits.\n'
               'Recreate the procedural source: python tools/build_student_kaykit.py; python tools/student_blender.py --create\n')
    bpy.context.scene.world=bpy.data.worlds.new('Studio world')
    bpy.context.scene.world.use_nodes=True
    background=bpy.context.scene.world.node_tree.nodes.get('Background')
    background.inputs['Color'].default_value=(.08,.09,.12,1)
    background.inputs['Strength'].default_value=.3
    bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=32
    bpy.context.scene.render.resolution_x=1024;bpy.context.scene.render.resolution_y=572;bpy.context.scene.render.resolution_percentage=100
    bpy.context.scene.view_settings.view_transform='AgX'
    bpy.ops.object.camera_add(location=(0,-8,1.55));camera=bpy.context.object;camera.name='Review camera'
    target=Vector((0,0,1.13));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=4.48
    bpy.context.scene.camera=camera
    for name,loc,power,size,color in [('Large warm key',(-3,-4,5),430,4,(1,.89,.77)),('Cool fill',(3,-2,3),180,3,(.78,.85,1)),('Hair rim',(1,3,4),500,3,(.78,.84,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.name=name;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.data.color=color
        light.rotation_euler=(Vector((0,0,1.1))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio floor';floor.location.z=-.005
    mat=bpy.data.materials.new('Studio charcoal');mat.use_nodes=True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.018,.020,.028,1)
    mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
    floor.data.materials.append(mat)
    BLEND.parent.mkdir(parents=True,exist_ok=True)
    if not (BLEND.parent/'.gdignore').exists(): (BLEND.parent/'.gdignore').touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print('EDITABLE BLENDER SOURCE:',BLEND)


def export_edits():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
    student=Student()
    for obj in bpy.data.collections['Character meshes'].objects:
        if obj.type!='MESH':continue
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();data.calc_loop_triangles()
        world=obj.matrix_world
        for slot,material in enumerate(data.materials):
            name=material.name
            shader=material.node_tree.nodes.get('Principled BSDF') if material.use_nodes else None
            rgba=list(shader.inputs['Base Color'].default_value if shader else material.diffuse_color)
            srgb=[v*12.92 if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in rgba[:3]]
            PALETTE[name]=''.join(f'{round(max(0,min(1,v))*255):02x}' for v in srgb)
            student.material_overrides[name]={'baseColorFactor':rgba,'roughnessFactor':float(shader.inputs['Roughness'].default_value if shader else material.roughness),'metallicFactor':float(shader.inputs['Metallic'].default_value if shader else material.metallic)}
            tris=[t for t in data.loop_triangles if t.material_index==slot]
            if not tris:continue
            indices=sorted({i for t in tris for i in t.vertices});lookup={index:i for i,index in enumerate(indices)}
            vertices=[];weights=[]
            for i in indices:
                v=data.vertices[i];p=world@v.co;vertices.append([p.x,p.z,-p.y])
                w={obj.vertex_groups[g.group].name:g.weight for g in v.groups if obj.vertex_groups[g.group].name in student.joints}
                if not w:raise ValueError(f'Unweighted vertex in {obj.name}')
                weights.append(w)
            g=student.geometry[name];start=len(g['vertices']);faces=[[lookup[i]+start for i in t.vertices] for t in tris]
            g['vertices'].extend(vertices);g['weights'].extend(weights);g['faces'].extend(faces)
            student.parts.append({'name':obj.name,'material':name,'vertex_start':start,'vertex_count':len(vertices),'triangles':len(faces)})
        evaluated.to_mesh_clear()
    student.export()
    manifest=json.loads((OUTPUT/'manifest.json').read_text());manifest['geometry']='Editable Blender geometry exported through tools/student_blender.py; KayKit source clips preserved and retargeted by student_rig.py.'
    (OUTPUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

def render_views():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.rotation_mode='XYZ'
    setup_neutral(rig)
    scene=bpy.context.scene
    scene.render.image_settings.file_format='PNG'
    destination=OUTPUT/'review/blender'
    destination.mkdir(parents=True,exist_ok=True)
    for view,yaw in [('front',0),('back',math.pi),('right',math.pi/2),('left',-math.pi/2),('three_quarter_left',-math.pi/4),('three_quarter_right',math.pi/4)]:
        rig.rotation_euler.z=yaw
        scene.render.filepath=str(destination/(view+'.png'))
        bpy.ops.render.render(write_still=True)
    print('BLENDER STUDIO RENDERS:',destination)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--create',action='store_true');group.add_argument('--export',action='store_true')
    group.add_argument('--render',action='store_true')
    args=parser.parse_args()
    create() if args.create else render_views() if args.render else export_edits()
