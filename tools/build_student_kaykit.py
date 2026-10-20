"""Author an original low-poly student mesh on KayKit's real Rig_Medium skeleton.

Run: python3 tools/build_student_kaykit.py (requires NumPy).
All visible geometry is authored below. KayKit supplies the unchanged skeleton,
bind transforms and animation clips; no KayKit character mesh is reused.
"""
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from gltf_tools import GLB, Writer

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


class Student:
    def __init__(self):
        # Animation files also include the two animated hand attachment bones.
        self.reference = GLB(SOURCE / "Rig_Medium_General.glb")
        self.skin = self.reference.doc["skins"][0]
        self.joints = {self.reference.doc["nodes"][i]["name"]: slot
                       for slot, i in enumerate(self.skin["joints"])}
        self.geometry = defaultdict(lambda: {"vertices": [], "faces": [], "weights": []})
        self.parts = []

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
        self.parts.append({"name": name, "material": color, "triangles": len(faces)})

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

    def create(self):
        body=self.body_weights; head=self.rigid("head"); hips=self.rigid("hips")
        self.loft("Trousers waist",[(.39,.25,.155,0,0),(.46,.28,.18,0,0),(.56,.27,.18,0,0),(.62,.235,.16,0,0)],"pants",hips)
        self.loft("Shirt under jacket",[(.51,.24,.17,0,0),(.65,.255,.185,0,0),(.89,.26,.19,0,0),
                   (1.07,.27,.17,0,0),(1.17,.135,.09,0,0)],"shirt",body,power=3)
        self.open_jacket([(.48,.25,.18,0,0),(.52,.29,.215,0,0),(.64,.285,.215,0,0),(.87,.29,.22,0,0),
                   (1.04,.325,.21,0,-.005),(1.13,.30,.185,0,0),(1.185,.17,.125,0,0)])
        self.patch("Cream shirt",[(-.115,1.16,.175),(.115,1.16,.175),(.10,.53,.218),(-.10,.53,.218)],.012,"shirt",body)
        self.patch("Right lapel",[(-.10,1.18,.16),(-.21,1.12,.175),(-.13,.87,.222),(-.025,1.06,.215)],.025,"jacket_light",body)
        self.patch("Left lapel",[(.10,1.18,.16),(.21,1.12,.175),(.13,.87,.222),(.025,1.06,.215)],.025,"jacket_light",body)
        for side in [-1,1]:
            x=side*.18
            self.box("Lower patch pocket",(x,.645,.221),(.135,.15,.025),"jacket_dark",body,.012)
            self.box("Pocket flap",(x,.711,.24),(.15,.043,.025),"jacket_light",body,.008)
            self.oval("Pocket stud",(x,.703,.256),(.011,.011,.006),"brass",body,8,4)
        for y in [.87,.76,.57]: self.oval("Jacket button",(-.116,y,.238),(.012,.012,.009),"brass",body,8,4)
        for y in [.95,.84,.73]: self.oval("Shirt button",(0,y,.239),(.006,.009,.004),"shirt_shadow",body,8,4)
        self.box("Belt front",(0,.513,.20),(.49,.055,.024),"boots",hips,.009)
        self.box("Belt buckle",(0,.513,.218),(.065,.057,.018),"brass",hips,.009)
        self.box("Belt buckle inset",(0,.513,.23),(.04,.032,.008),"boots",hips,.006)
        self.loft("Neck",[(1.12,.10,.085,0,0),(1.36,.115,.105,0,0)],"skin",head)
        self.patch("Shirt collar right",[(-.10,1.22,.10),(-.16,1.16,.16),(-.065,1.08,.205),(0,1.17,.16)],.015,"shirt",body)
        self.patch("Shirt collar left",[(.10,1.22,.10),(.16,1.16,.16),(.065,1.08,.205),(0,1.17,.16)],.015,"shirt",body)
        # Rounded rectangular head, broad cheeks and a soft jaw. Avoid a sphere head.
        self.loft("Face and jaw",[(1.30,.19,.14,0,.01),(1.335,.29,.23,0,.02),(1.40,.365,.29,0,.02),
                   (1.50,.405,.325,0,.01),(1.72,.415,.335,0,0),(1.88,.39,.32,0,-.01),
                   (1.985,.32,.26,0,-.02),(2.025,.21,.17,0,-.025)],"skin",head,24,power=3.1)
        for side in [-1,1]:
            self.oval("Ear",(side*.405,1.59,-.015),(.074,.115,.064),"skin",head)
            self.oval("Ear inner",(side*.44,1.59,.033),(.027,.06,.016),"skin_shadow",head,12,6)
            self.oval("Dark oval eye",(side*.151,1.72,.331),(.034,.059,.018),"eyes",head,16,10)
            self.oval("Eye glint",(side*.151-.007,1.745,.349),(.007,.01,.004),"eye_glint",head,8,6)
            # Broad eyebrows and small oval eyes are readable at gameplay distance.
            self.ribbon("Eyebrow",[(side*.092,1.842,.334),(side*.15,1.85,.335),(side*.215,1.835,.324)],.034,.025,"hair",head)
        self.oval("Nose",(0,1.615,.346),(.052,.064,.059),"skin",head,12,8)
        self.ribbon("Smile",[(-.065,1.474,.319),(-.035,1.463,.328),(0,1.46,.331),(.038,1.466,.327),(.063,1.479,.319)],.008,.004,"skin_shadow",head)
        # Asymmetric cap with sculpted, broad swept locks instead of fine strands.
        rings=[]
        cap_profile=[(1.43,.405,.325),(1.50,.435,.36),(1.72,.45,.37),
                     (1.88,.425,.36),(1.985,.36,.30),(2.025,.29,.25),
                     (2.08,.19,.17),(2.13,.005,.005)]
        for level in range(10):
            ring=[]
            for j in range(24):
                a=j*math.tau/24; front=max(0,math.cos(a)); low=1.46+.43*front+.025*math.sin(a*2)
                t=level/9; y=low+(2.13-low)*t
                rx=np.interp(y,[p[0] for p in cap_profile],[p[1] for p in cap_profile])
                rz=np.interp(y,[p[0] for p in cap_profile],[p[2] for p in cap_profile])
                sx=math.sin(a);sz=math.cos(a)
                ring.append((rx*math.copysign(abs(sx)**(2/3.1),sx),y,
                             -.025+rz*math.copysign(abs(sz)**(2/3.1),sz)))
            rings.append(ring)
        self.rings("Sculpted hair cap",rings,"hair",head)
        self.lock("Swept fringe main",[(-.32,2.015,.18),(-.21,2.13,.25),(.02,2.12,.33),(.23,1.99,.35),(.29,1.81,.29)],
                  [.055,.10,.115,.10,.004],[.045,.075,.075,.055,.003],"hair_mid")
        self.lock("Swept fringe side",[(-.38,1.98,.17),(-.32,2.105,.26),(-.13,2.09,.35),(.04,1.94,.365),(.075,1.85,.35)],
                  [.04,.075,.09,.06,.002],[.035,.065,.065,.045,.002],"hair")
        self.lock("Crown quiff",[(-.25,2.075,-.17),(-.18,2.20,-.05),(.04,2.18,.10),(.17,2.08,.16)],
                  [.065,.10,.12,.02],[.05,.065,.06,.02],"hair_mid")
        self.lock("Crown side sweep",[(-.36,2.0,-.13),(-.30,2.13,-.01),(-.05,2.14,.14),(.14,2.03,.24)],
                  [.05,.07,.08,.01],[.035,.05,.05,.008],"hair_light")
        for side in [-1,1]:
            self.lock("Temple lock",[(side*.365,1.96,.13),(side*.42,1.79,.14),(side*.38,1.64,.14)],
                      [.06,.055,.003],[.035,.035,.002],"hair")
        # Limbs are continuous skinned surfaces, with overlapping rolled cuffs.
        for sign,side in [(1,"l"),(-1,"r")]:
            arm=self.arm_weights(side)
            sleeve=[]
            for x,r in [(.195,.105),(.25,.13),(.36,.115),(.435,.102),(.50,.094),(.525,.09)]:
                sleeve.append((sign*x,r,r,0,1.1068))
            # For x-axis loft: section radii become Z/Y and centers become Z/Y.
            if sign<0: sleeve.reverse()
            self.loft("Rolled jacket sleeve "+side,sleeve,"jacket",arm,16,power=2.5,axis="x")
            cuff=[(sign*x,.105,.105,0,1.1068) for x in [.485,.50,.535]]
            if sign<0: cuff.reverse()
            self.loft("Cream rolled cuff "+side,cuff,"shirt_shadow",arm,16,power=2.7,axis="x")
            forearm=[(sign*x,r,r,0,1.1068) for x,r in [(.515,.078),(.56,.078),(.65,.066),(.735,.055),(.79,.056)]]
            if sign<0: forearm.reverse()
            self.loft("Bare forearm "+side,forearm,"skin",arm,16,power=2.3,axis="x")
            self.oval("Mitten hand "+side,(sign*.845,1.1068,.008),(.103,.075,.064),"skin",arm,16,8)
            self.oval("Thumb "+side,(sign*.81,1.075,.058),(.04,.047,.039),"skin",arm,12,6)
            if side=="l":
                watch=[(sign*x,.061,.064,0,1.1068) for x in [.705,.73]]
                self.loft("Left wrist watch strap",watch,"boots",arm,16,axis="x")
                self.box("Watch bezel",(sign*.72,1.17,.003),(.055,.018,.057),"watch",arm,.006)
                self.box("Watch dial",(sign*.72,1.182,.003),(.04,.006,.041),"watch_face",arm,.004)
            leg=self.leg_weights(side); x=sign*.17095
            self.loft("Trouser leg "+side,[(.14,.088,.091,x,0),(.20,.10,.10,x,0),(.285,.102,.11,x,.008),
                       (.35,.112,.115,x,.004),(.47,.123,.125,x,0),(.55,.125,.13,x,0)],"pants",leg,16,power=3)
            self.loft("Trouser turned hem "+side,[(.145,.103,.105,x,0),(.19,.108,.108,x,0)],"pants_seam",leg,16,power=3)
            foot=self.rigid("foot."+side)
            self.loft("Boot sole "+side,[(.015,.106,.177,x,.06),(.03,.13,.205,x,.06),(.065,.13,.205,x,.06)],"sole",foot,16,power=4)
            self.loft("Leather boot "+side,[(.058,.122,.195,x,.06),(.09,.13,.19,x,.065),(.13,.115,.165,x,.045),
                       (.185,.085,.09,x,-.01),(.21,.083,.085,x,-.012)],"boots",foot,16,power=3.2)
            self.box("Boot tongue "+side,(x,.16,.105),(.10,.11,.03),"boot_trim",foot,.012)
            for y,z in [(.16,.132),(.135,.158),(.11,.18)]:
                self.ribbon("Boot lace",[(x-.035,y,z),(x+.035,y,z)],.009,.006,"bag_trim",foot)
        # Satchel on the anatomical right hip. Rear placement clears arm swings.
        self.box("Messenger bag",(-.37,.60,-.155),(.235,.30,.175),"bag",hips,.03)
        self.box("Satchel flap",(-.37,.71,-.137),(.255,.10,.20),"bag_trim",hips,.018)
        self.box("Satchel front panel",(-.37,.575,-.055),(.18,.17,.018),"bag",hips,.015)
        self.box("Bag buckle",(-.37,.65,-.025),(.045,.057,.018),"brass",hips,.008)
        self.box("Bag buckle inset",(-.37,.65,-.012),(.025,.034,.008),"boots",hips,.004)
        self.ribbon("Crossbody front strap",[(.20,1.17,.13),(.14,1.07,.23),(.015,.90,.247),(-.13,.73,.24),(-.28,.56,.20),(-.37,.56,.035)],.045,.017,"bag",body)
        self.ribbon("Crossbody back strap",[(.20,1.17,-.11),(.13,1.04,-.22),(-.02,.86,-.235),(-.19,.69,-.23),(-.37,.70,-.22)],.045,.017,"bag",body)
        self.box("Strap adjuster",(.085,.99,.264),(.066,.071,.018),"brass",body,.006)
        self.box("Strap adjuster inset",(.085,.99,.276),(.04,.044,.008),"bag",body,.004)
        # Oversized, readable badge geometry; avoid illegible tiny lettering.
        self.box("ID metal clip",(.20,1.02,.239),(.025,.055,.018),"watch",body,.005)
        self.box("Student ID",(.20,.945,.25),(.092,.115,.016),"shirt",body,.008)
        self.box("ID teal stripe",(.20,.98,.263),(.08,.025,.006),"badge",body,.003)
        self.box("ID portrait",(.183,.938,.264),(.027,.033,.006),"pants",body,.003)
        self.box("ID text mark",(.218,.942,.264),(.023,.007,.006),"shirt_shadow",body,.002)

    def export(self):
        writer=Writer(); source=self.reference.doc
        count=max(self.skin["joints"])+1
        joint_nodes=deepcopy(source["nodes"][:count])
        root_index=next(i for i,n in enumerate(joint_nodes) if n["name"]=="root")
        nodes=joint_nodes+[{"name":"Rig_Medium","children":[root_index,count+1]},
                           {"name":"Student_SkinnedMesh","mesh":0,"skin":0}]
        skin=deepcopy(self.skin)
        skin["inverseBindMatrices"]=writer.add(self.reference.read(skin["inverseBindMatrices"]),"MAT4")
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
                for sampler in animation["samplers"]:
                    sampler["input"]=copy_accessor(sampler["input"])
                    sampler["output"]=copy_accessor(sampler["output"])
                for channel in animation["channels"]:
                    name=asset.doc["nodes"][channel["target"]["node"]]["name"]
                    channel["target"]["node"]=node_map[name]
                animations.append(animation);animation_sources[animation["name"]]=path.name
        materials=[]
        for name,h in PALETTE.items():
            rgb=[int(h[i:i+2],16)/255 for i in [0,2,4]]
            rgb=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
            materials.append({"name":name,"pbrMetallicRoughness":{"baseColorFactor":rgb+[1],"metallicFactor":0,"roughnessFactor":.85}})
        writer.save(OUTPUT/"student.glb",{"asset":{"version":"2.0","generator":"Past & Future original student mesh; KayKit Rig_Medium and CC0 animation tracks"},
                    "scene":0,"scenes":[{"name":"Student","nodes":[count]}],"nodes":nodes,"skins":[skin],
                    "meshes":[{"name":"Original_Student","primitives":primitives}],"materials":materials,"animations":animations})
        OUTPUT.mkdir(parents=True,exist_ok=True)
        all_vertices=np.concatenate([np.asarray(g["vertices"]) for g in self.geometry.values()])
        manifest={"model":"student.glb","geometry":"Original mesh authored in tools/build_student_kaykit.py; no KayKit character geometry reused.",
                  "rig":"KayKit Rig_Medium, unchanged joint hierarchy/rest transforms/inverse bind matrices",
                  "height":float(np.ptp(all_vertices[:,1])),"triangles":sum(g["triangles"] for g in stats.values()),
                  "vertices":sum(g["vertices"] for g in stats.values()),"joint_count":len(skin["joints"]),
                  "parts":self.parts,"animation_sources":animation_sources,"source_sha256":files}
        (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
        print(f"Built original skinned student: {manifest['triangles']} triangles, {manifest['joint_count']} joints, {len(animations)} genuine KayKit clips")


if __name__=="__main__":
    student=Student();student.create();student.export()
