"""Mesh construction and glTF export utilities for the reference-led student.

Run: python3 tools/build_student_kaykit.py (requires NumPy).
Visible geometry is authored by build_student_kaykit.py. KayKit supplies bone
axes, hierarchy and animation. Rest positions and translation motion are
retargeted in student_rig.py, with contact clearance in ground_student_clips.py.
"""
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from gltf_tools import GLB, Writer
from student_rig import make_rig, translate_samples

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/third_party/kaykit_character_animations"
OUTPUT = ROOT / "assets/characters/student_3d"
PALETTE = {
    "jacket": "b18145", "jacket_light": "c99a5b", "jacket_dark": "886133",
    "shirt": "f0e2c7", "shirt_shadow": "cdbd9e", "skin": "e1ac7f",
    "skin_shadow": "bb805c", "hair": "302822", "hair_mid": "3e3026",
    "hair_light": "4d3a2a", "pants": "343c46", "pants_seam": "444b54",
    "boots": "60432e", "boot_trim": "815b39", "sole": "302d29",
    "bag": "795337", "bag_trim": "a17847", "brass": "c6a35a",
    "eyes": "252425", "eye_glint": "f4e5ce", "badge": "639c9f",
    "watch": "c7bdae", "watch_face": "eee5ce",
}


def smooth(a, b, value):
    t = np.clip((value-a)/(b-a), 0, 1)
    return float(t*t*(3-2*t))


def normalize(v):
    a = np.asarray(v, dtype=float)
    return a / max(np.linalg.norm(a), 1e-9)


class MeshAuthor:
    def __init__(self):
        # Animation files also include the two animated hand attachment bones.
        self.reference = GLB(SOURCE / "Rig_Medium_General.glb")
        self.skin = self.reference.doc["skins"][0]
        self.joints = {self.reference.doc["nodes"][i]["name"]: slot
                       for slot, i in enumerate(self.skin["joints"])}
        self.geometry = defaultdict(lambda: {"vertices": [], "faces": [], "weights": []})
        self.parts = []
        self.material_overrides = {}

    def rigid(self, bone):
        return lambda p: {bone: 1.0}

    def body_weights(self, p):
        x, y, z = p
        upper = smooth(.70, .99, y)
        lower = 1-smooth(.45, .69, y)
        return {"hips": lower, "spine": (1-lower)*(1-upper), "chest": (1-lower)*upper}

    def arm_weights(self, side):
        def weights(p):
            x = abs(p[0])
            elbow = smooth(.395, .51, x)
            wrist = smooth(.68, .76, x)
            palm = smooth(.78, .84, x)
            return {"upperarm."+side: 1-elbow, "lowerarm."+side: elbow*(1-wrist),
                    "wrist."+side: elbow*wrist*(1-palm), "hand."+side: elbow*wrist*palm}
        return weights

    def leg_weights(self, side):
        def weights(p):
            y = p[1]
            knee = 1-smooth(.25, .34, y)
            ankle = 1-smooth(.13, .21, y)
            return {"upperleg."+side: 1-knee, "lowerleg."+side: knee*(1-ankle), "foot."+side: knee*ankle}
        return weights

    def add(self, name, vertices, faces, color, weights):
        g = self.geometry[color]
        start = len(g["vertices"])
        g["vertices"].extend([list(v) for v in vertices])
        g["faces"].extend([[a+start,b+start,c+start] for a,b,c in faces])
        g["weights"].extend([weights(v) for v in vertices])
        self.parts.append({"name": name, "material": color, "triangles": len(faces),
                           "vertex_start": start, "vertex_count": len(vertices)})

    def rings(self, name, rings, color, weights):
        n = len(rings[0]); vertices = [v for ring in rings for v in ring]; faces = []
        for r in range(len(rings)-1):
            for j in range(n):
                a=r*n+j; b=r*n+(j+1)%n; c=(r+1)*n+(j+1)%n; d=(r+1)*n+j
                faces += [(a,b,c),(a,c,d)]
        for r, reverse in [(0,True),(len(rings)-1,False)]:
            center = np.mean(rings[r], axis=0).tolist(); ci=len(vertices); vertices.append(center)
            for j in range(n):
                a=r*n+j; b=r*n+(j+1)%n
                faces.append((ci,b,a) if reverse else (ci,a,b))
        self.add(name,vertices,faces,color,weights)

    def loft(self, name, sections, color, weights, segments=16, power=2.8, axis="y"):
        rings = []
        for height, rx, rz, cx, cz in sections:
            ring = []
            for j in range(segments):
                angle=j*math.tau/segments; sx=math.sin(angle); sz=math.cos(angle)
                point=[cx+rx*math.copysign(abs(sx)**(2/power),sx), height,
                       cz+rz*math.copysign(abs(sz)**(2/power),sz)]
                if axis == "x": point=[point[1],point[2],point[0]]
                ring.append(point)
            rings.append(ring)
        self.rings(name,rings,color,weights)

    def box(self, name, center, size, color, weights, bevel=.035):
        x,y,z=center; w,h,d=size; bevel=min(bevel,w*.3,h*.3,d*.3)
        self.loft(name,[(y-h/2,w/2-bevel,d/2-bevel,x,z),
                       (y-h/2+bevel,w/2,d/2,x,z),
                       (y+h/2-bevel,w/2,d/2,x,z),
                       (y+h/2,w/2-bevel,d/2-bevel,x,z)],color,weights,segments=16,power=5)

    def open_jacket(self, sections):
        # A genuine front opening. A solid torso with a shirt overlaid intersects
        # as the chest bends, so leave the center strip out of the jacket mesh.
        count=25; vertices=[]; faces=[]
        for y,rx,rz,cx,cz in sections:
            for a in np.linspace(.18,math.tau-.18,count):
                sx=math.sin(a);sz=math.cos(a)
                vertices.append([cx+rx*math.copysign(abs(sx)**(2/3.6),sx),y,
                                 cz+rz*math.copysign(abs(sz)**(2/3.6),sz)])
        for row in range(len(sections)-1):
            for j in range(count-1):
                a=row*count+j;b=a+1;c=b+count;d=a+count
                faces += [(a,b,c),(a,c,d)]
        self.add("Open field jacket",vertices,faces,"jacket",self.body_weights)

    def oval(self, name, center, size, color, weights, segments=16, rows=8):
        x,y,z=center; w,h,d=size
        self.loft(name,[(y+h*math.sin(a),max(.0001,w*math.cos(a)),
                        max(.0001,d*math.cos(a)),x,z)
                       for a in np.linspace(-math.pi/2,math.pi/2,rows+1)],
                  color,weights,segments,power=2)

    def ribbon(self, name, path, width, thickness, color, weights):
        # Rectangular leather/cloth strips with real edge thickness.
        points=np.asarray(path); rings=[]
        for i,p in enumerate(points):
            tangent=normalize(points[min(i+1,len(points)-1)]-points[max(0,i-1)])
            normal=np.array([0,0,1 if p[2]>=0 else -1])
            across=normalize(np.cross(tangent,normal))*width*.5
            rings.append([p-across-normal*thickness/2,p-across+normal*thickness/2,
                          p+across+normal*thickness/2,p+across-normal*thickness/2])
        self.rings(name,rings,color,weights)

    def patch(self, name, outline, depth, color, weights):
        outline=[list(v) for v in outline]
        signed=sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))
        if signed<0: outline.reverse()
        count=len(outline); center=np.mean(outline,axis=0)
        vertices=outline+[(center+(np.array(v)-center)*.85+np.array([0,0,depth])).tolist() for v in outline]
        faces=[]
        for i in range(count):
            j=(i+1)%count;faces += [(i,j,j+count),(i,j+count,i+count)]
        ci=len(vertices); vertices.append((center+[0,0,depth]).tolist())
        for i in range(count): faces.append((ci,i+count,(i+1)%count+count))
        self.add(name,vertices,faces,color,weights)

    def lock(self, name, path, widths, depths, color):
        rings=[]
        for i,p in enumerate(path):
            p=np.array(p); tangent=normalize(np.array(path[min(i+1,len(path)-1)])-np.array(path[max(0,i-1)]))
            across=normalize(np.cross(tangent,[0,0,1])); outward=normalize(np.cross(across,tangent))
            rings.append([p+across*math.sin(a)*widths[i]+outward*math.cos(a)*depths[i]
                          for a in np.linspace(0,math.tau,12,endpoint=False)])
        self.rings(name,rings,color,self.rigid("head"))

    def export(self):
        writer=Writer(); source=self.reference.doc
        count=max(self.skin["joints"])+1
        joint_nodes, inverse_binds, retarget = make_rig(source, self.skin)
        root_index=next(i for i,n in enumerate(joint_nodes) if n["name"]=="root")
        nodes=joint_nodes+[{"name":"Rig_Medium","children":[root_index,count+1]},
                           {"name":"Student_SkinnedMesh","mesh":0,"skin":0}]
        skin=deepcopy(self.skin)
        skin["inverseBindMatrices"]=writer.add(inverse_binds,"MAT4")
        primitives=[]; stats={}
        for color,g in self.geometry.items():
            vertices=np.array(g["vertices"]); faces=np.array(g["faces"])
            normals=np.zeros_like(vertices)
            face_normals=np.cross(vertices[faces[:,1]]-vertices[faces[:,0]],vertices[faces[:,2]]-vertices[faces[:,0]])
            for col in range(3): np.add.at(normals,faces[:,col],face_normals)
            normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
            joint_ids=np.zeros((len(vertices),4),dtype=np.uint16); weights=np.zeros((len(vertices),4))
            for i,values in enumerate(g["weights"]):
                values=sorted([(self.joints[k],v) for k,v in values.items() if v>1e-8],key=lambda kv:-kv[1])[:4]
                total=sum(v for _,v in values)
                assert total>0
                for j,(bone,value) in enumerate(values): joint_ids[i,j]=bone;weights[i,j]=value/total
            attributes={"POSITION":writer.add(vertices,"VEC3",target=34962,bounds=True),
                        "NORMAL":writer.add(normals,"VEC3",target=34962),
                        "JOINTS_0":writer.add(joint_ids,"VEC4",5123,34962),
                        "WEIGHTS_0":writer.add(weights,"VEC4",target=34962)}
            primitives.append({"attributes":attributes,"indices":writer.add(faces.reshape(-1,1),"SCALAR",5125,34963),"material":list(PALETTE).index(color)})
            stats[color]={"vertices":len(vertices),"triangles":len(faces)}
        node_map={n["name"]:i for i,n in enumerate(joint_nodes)}
        animations=[]; animation_sources={}; files={}
        # Bake the exact authored source tracks onto their matching bone names.
        # Do not approximate the clips with procedural limb motion.
        sets=["General","MovementBasic","MovementAdvanced","Simulation","Tools"]
        for group in sets:
            path=SOURCE/f"Rig_Medium_{group}.glb"; asset=GLB(path)
            files[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            cache={}
            def copy_accessor(index):
                if index not in cache:
                    a=asset.doc["accessors"][index]
                    cache[index]=writer.add(asset.read(index),a["type"],a["componentType"],bounds=a["type"]=="SCALAR")
                return cache[index]
            for original in asset.doc["animations"]:
                if original["name"]=="T-Pose": continue
                animation=deepcopy(original)
                channel_for_sampler = {c["sampler"]: c for c in original["channels"]}
                for sampler_index, sampler in enumerate(animation["samplers"]):
                    sampler["input"]=copy_accessor(sampler["input"])
                    channel = channel_for_sampler[sampler_index]
                    bone = asset.doc["nodes"][channel["target"]["node"]]["name"]
                    if channel["target"]["path"] == "translation":
                        assert sampler.get("interpolation", "LINEAR") != "CUBICSPLINE"
                        sampler["output"] = writer.add(translate_samples(asset.read(sampler["output"]), retarget[bone]), "VEC3")
                    else:
                        sampler["output"]=copy_accessor(sampler["output"])
                for channel in animation["channels"]:
                    name=asset.doc["nodes"][channel["target"]["node"]]["name"]
                    channel["target"]["node"]=node_map[name]
                animations.append(animation);animation_sources[animation["name"]]=path.name
        materials=[]
        for name,h in PALETTE.items():
            rgb=[int(h[i:i+2],16)/255 for i in [0,2,4]]
            rgb=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
            roughness = .38 if name in ("eyes", "watch_glass") else .48 if name.startswith(("bag","boot")) else .72
            metallic = .65 if name in ("brass","watch","steel") else 0
            pbr={"baseColorFactor":rgb+[1],"metallicFactor":metallic,"roughnessFactor":roughness}
            pbr.update(self.material_overrides.get(name,{}))
            materials.append({"name":name,"pbrMetallicRoughness":pbr})
        writer.save(OUTPUT/"student.glb",{"asset":{"version":"2.0","generator":"Past & Future original student mesh; KayKit Rig_Medium and CC0 animation tracks"},
                    "scene":0,"scenes":[{"name":"Student","nodes":[count]}],"nodes":nodes,"skins":[skin],
                    "meshes":[{"name":"Original_Student","primitives":primitives}],"materials":materials,"animations":animations})
        from ground_student_clips import bake
        ground_clearance = bake(OUTPUT/"student.glb")
        OUTPUT.mkdir(parents=True,exist_ok=True)
        all_vertices=np.concatenate([np.asarray(g["vertices"]) for g in self.geometry.values()])
        files.update({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob("*.glb")})
        manifest={"model":"student.glb","geometry":"Original mesh authored in tools/build_student_kaykit.py; no KayKit character geometry reused.",
                  "rig":"KayKit Rig_Medium hierarchy and axes; proportion-adjusted rest translations, rebuilt inverse binds, length-scaled translation deltas; unchanged rotation/scale samples",
                  "retarget": retarget,
                  "ground_clearance": ground_clearance,
                  "palette_hex_srgb": PALETTE,
                  "editable_source": "source/student.blend",
                  "reference_sha256": {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (OUTPUT.parent/"references/18").glob("*view*.png")},
                  "height":float(np.ptp(all_vertices[:,1])),"triangles":sum(g["triangles"] for g in stats.values()),
                  "vertices":sum(g["vertices"] for g in stats.values()),"joint_count":len(skin["joints"]),
                  "parts":self.parts,"animation_sources":animation_sources,"source_sha256":files}
        (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
        print(f"Built original skinned student: {manifest['triangles']} triangles, {manifest['joint_count']} joints, {len(animations)} genuine KayKit clips")
