"""Fit sewn details to their garment surfaces and transfer supporting skin weights.

Model coordinates are Y-up, +Z-forward. Base garment shells, their openings,
and the character's face are preserved. NumPy is the only dependency.
"""
import numpy as np
from collections import defaultdict
from fit_professor_face import ring_depth


def is_clothing(name):
    return name.startswith(("Coat /", "Shirt /", "Waistcoat /", "Research /", "Trousers /", "Boot /")) or name == "Skin / neck"


def refine_surface(vertices, faces, relief):
    """Add shared vertices so broad panels follow curved supports between corners."""
    vertices, relief = list(vertices), list(relief)
    faces = [list(f) for f in faces]
    for _ in range(6):
        edges={}
        for f in faces:
            for a,b in zip(f,f[1:]+f[:1]):
                key=tuple(sorted((a,b)))
                if key not in edges and np.linalg.norm(np.asarray(vertices[a])-vertices[b])>.024:
                    edges[key]=None
        if not edges:
            break
        for a,b in edges:
            edges[(a,b)]=len(vertices)
            vertices.append((np.asarray(vertices[a])+vertices[b])/2)
            relief.append((relief[a]+relief[b])/2)
        updated=[]
        for f in faces:
            boundary=[]
            for a,b in zip(f,f[1:]+f[:1]):
                boundary.append(a)
                midpoint=edges.get(tuple(sorted((a,b))))
                if midpoint is not None:
                    boundary.append(midpoint)
            if len(boundary)==3:
                updated.append(f)
                continue
            center=len(vertices)
            vertices.append(np.mean([vertices[i] for i in f],axis=0))
            relief.append(np.mean([relief[i] for i in f]))
            for a,b in zip(boundary,boundary[1:]+boundary[:1]):
                updated.append([center,a,b])
        faces=updated
    return np.asarray(vertices),np.asarray(faces),np.asarray(relief)


class Surface:
    def __init__(self, parts, bones, axis=2, side=1, max_distance=.06):
        self.axis, self.side = axis, side
        self.max_distance=max_distance
        self.order = {2:[0,1,2], 0:[2,1,0], 1:[0,2,1]}[axis]
        triangles, weights, normals = [], [], []
        for part in parts:
            original=part['vertices'];faces=part['faces']
            normal=np.zeros_like(original)
            face_normal=np.cross(original[faces[:,1]]-original[faces[:,0]],original[faces[:,2]]-original[faces[:,0]])
            # End caps must not tilt a sewn front panel's shading downward
            # when the panel extends just below its supporting shirt hem.
            face_normal[face_normal[:,axis]*side<=1e-15]=0
            for col in range(3):np.add.at(normal,faces[:,col],face_normal)
            normal/=np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-12)
            normals.append(part.get('normals',normal)[faces])
            v = part["vertices"][:,self.order].copy()
            v[:,2] *= side
            triangles.append(v[part["faces"]])
            dense = np.zeros((len(v),len(bones)))
            for i, values in enumerate(part["weights"]):
                for name, value in values.items():
                    # A standing collar belongs to the torso, not the head bone.
                    name = "chest" if part["name"] == "Skin / neck" and name == "head" else name
                    dense[i,bones.index(name)] += value
            weights.append(dense[part["faces"]])
        self.triangles = np.concatenate(triangles)
        self.weights = np.concatenate(weights)
        self.normals = np.concatenate(normals)
        a,b,c = self.triangles.transpose(1,0,2)
        den = (b[:,1]-c[:,1])*(a[:,0]-c[:,0])+(c[:,0]-b[:,0])*(a[:,1]-c[:,1])
        # A detail beside an opening must use the nearby front edge, rather
        # than projecting through the opening onto the back of the garment.
        valid = (abs(den)>1e-14) & (self.triangles[:,:,2].mean(axis=1)>0)
        self.a,self.b,self.c,self.den = a[valid],b[valid],c[valid],den[valid]
        self.weights = self.weights[valid]
        self.normals = self.normals[valid]
        self.minimum = self.triangles[valid,:,:2].min(axis=1)-1e-8
        self.maximum = self.triangles[valid,:,:2].max(axis=1)+1e-8

    def sample(self, vertices, include_normals=False):
        depths, weights, normals = [], [], []
        for x,y in vertices[:,self.order][:,:2]:
            ids = np.flatnonzero((self.minimum[:,0]<=x)&(x<=self.maximum[:,0])&
                                 (self.minimum[:,1]<=y)&(y<=self.maximum[:,1]))
            fallback = len(ids)==0
            if fallback:
                d = np.maximum(np.maximum(self.minimum-[x,y],[x,y]-self.maximum),0)
                ids = np.argsort(np.sum(d*d,axis=1))[:32]
            a,b,c,den = self.a[ids],self.b[ids],self.c[ids],self.den[ids]
            u=((b[:,1]-c[:,1])*(x-c[:,0])+(c[:,0]-b[:,0])*(y-c[:,1]))/den
            v=((c[:,1]-a[:,1])*(x-c[:,0])+(a[:,0]-c[:,0])*(y-c[:,1]))/den
            bary=np.column_stack([u,v,1-u-v])
            inside=np.all(bary>=-1e-7,axis=1)
            if np.any(inside):
                choices=np.flatnonzero(inside)
                z=np.sum(bary*np.column_stack([a[:,2],b[:,2],c[:,2]]),axis=1)
                i=choices[np.argmax(z[choices])]
            else:
                bary=np.maximum(bary,0)
                bary/=bary.sum(axis=1,keepdims=True)
                point=bary[:,0,None]*a+bary[:,1,None]*b+bary[:,2,None]*c
                i=int(np.argmin(np.sum((point[:,:2]-[x,y])**2,axis=1)))
                if np.linalg.norm(point[i,:2]-[x,y])>self.max_distance:
                    raise ValueError(f"Clothing detail too far from its support at {x}, {y}")
            depths.append(bary[i]@np.array([a[i,2],b[i,2],c[i,2]]))
            weights.append(bary[i]@self.weights[ids[i]])
            if include_normals:
                normal=bary[i]@self.normals[ids[i]]
                normals.append(normal/max(np.linalg.norm(normal),1e-12))
        result=(np.asarray(depths),np.asarray(weights))
        return result+(np.asarray(normals),) if include_normals else result


def make_attacher(parts, report):
    bones=sorted({name for p in parts for w in p["weights"] for name in w}|{"chest"})
    def select(*prefixes):
        return [p for p in parts if p["name"].startswith(prefixes)]
    def attach(targets, supports, kind, low=.0005, high=.004, sides=16, axis=2, side=1):
        if not targets:
            return
        surface=Surface(supports,bones,axis,side)
        for part in targets:
            v=part["vertices"]
            if kind=="patch":
                n=(len(v)-1)//2
                relief=np.r_[np.full(n,low),np.full(n+1,high)]
            elif kind=="ribbon":
                n=(len(v)-2)//4
                relief=np.r_[np.tile([low,high,high,low],n),[(low+high)/2]*2]
            else:
                radius=(high-low)/2
                relief=ring_depth(v,sides,radius,(high+low)/2)
                if kind=="oval":
                    rows=v[:-2].reshape(-1,sides,3)
                    rx=np.ptp(rows[:,:,0],axis=1)/2
                    relief=ring_depth(v,sides,radius*rx/max(rx.max(),1e-8),(high+low)/2)
                if kind=="box":
                    t=(np.arange(len(v)-2)%sides)*2*np.pi/sides
                    relief[:-2]=(low+high)/2+radius*np.sign(np.cos(t))*abs(np.cos(t))**.4
            if axis==1:
                # Sleeve pockets face upward in the bind pose. Their depth
                # comes from Y, rather than the usual front-facing Z rings.
                relief=low+(v[:,1]-v[:,1].min())/max(np.ptp(v[:,1]),1e-8)*(high-low)
            depth,_=surface.sample(v)
            v[:,axis]=side*(depth+relief)
            v,faces,relief=refine_surface(v,part["faces"],relief)
            depth,skin,normals=surface.sample(v,include_normals=True)
            v[:,axis]=side*(depth+relief)
            part["vertices"],part["faces"]=v,faces
            if kind in ('patch','ribbon'):
                # Sewn panels inherit the cloth's smooth lighting. Averaging
                # their extremely thin side walls otherwise creates edge noise.
                part['normals']=normals
            updated=[]
            for values in skin:
                indices=np.argsort(values)[-4:]
                total=values[indices].sum()
                updated.append({bones[i]:float(values[i]/total) for i in indices if values[i]>1e-8})
            part["weights"]=updated
            report.append({"name":part["name"],"support":[p["name"] for p in supports],"low":low,"high":high})

    return select, attach


def fit_clothing(parts):
    report=[]
    select,attach=make_attacher(parts,report)
    coat=select("Coat / long open shell")
    shirt=select("Shirt / slate button-up")
    neck=select("Skin / neck")
    # Fit the layers from inside to outside so each trim rests on its own cloth.
    attach(select("Waistcoat / tailored front"),shirt,"patch",high=.005)
    vest=select("Waistcoat / tailored front")
    attach(select("Shirt / pointed collar"),vest+shirt+neck,"patch",high=.005)
    attach(select("Shirt / button placket"),shirt+neck,"ribbon",high=.002)
    attach(select("Shirt / collar seam"),select("Shirt / pointed collar")+shirt+neck,"tube",high=.0008,sides=10)
    attach(select("Waistcoat / V neckline binding"),vest+shirt,"tube",high=.0012,sides=10)
    # The standing collar wraps the neck in 3D; retain its height and an outer fold.
    n=neck[0]["vertices"]
    ys=np.unique(np.round(n[:,1],6))
    profiles=[]
    for y in ys:
        row=n[abs(n[:,1]-y)<1e-5]
        profiles.append((y,np.ptp(row[:,0])/2,np.ptp(row[:,2])/2,(row[:,2].max()+row[:,2].min())/2))
    profiles=np.asarray(profiles)
    for part in select("Coat / collar stand"):
        v=part["vertices"]
        rx=np.interp(v[:,1],profiles[:,0],profiles[:,1]);rz=np.interp(v[:,1],profiles[:,0],profiles[:,2])
        cz=np.interp(v[:,1],profiles[:,0],profiles[:,3])
        radial=(abs(v[:,0]/rx)**2.5+abs((v[:,2]-cz)/rz)**2.5)**.4
        radial=np.maximum(radial,1e-8)
        x=v[:,0]/radial;z=(v[:,2]-cz)/radial
        direction=np.column_stack([x,z])
        direction/=np.linalg.norm(direction,axis=1,keepdims=True)
        offsets=np.r_[np.tile([-.0006,.004,.004,-.0006],(len(v)-2)//4),[.0017,.0017]]
        v[:,0]=x+direction[:,0]*offsets;v[:,2]=cz+z+direction[:,1]*offsets
        report.append({"name":part["name"],"support":["Skin / neck"],"low":-.0006,"high":.004})
    # Extend the coat edge across its opening. Combining shirt/coat ray hits
    # creates a discontinuous depth field and folds the trim into the opening.
    attach(select("Coat / long front facing"),coat,"ribbon",low=.0015,high=.006)
    attach(select("Coat / notched lapel"),coat,"patch",low=.007,high=.014)
    attach(select("Coat / shoulder seam"),coat,"tube",high=.0008,sides=10,side=-1)
    for part in select("Coat / back center seam"):
        v=part["vertices"]
        if v[:,1].min()<.533:
            lo,hi=v[:,1].min(),v[:,1].max()
            v[:,1]=.534+(v[:,1]-lo)*(hi-.534)/(hi-lo)
    attach(select("Coat / back center seam"),coat,"tube",high=.0008,sides=10,side=-1)
    attach(select("Coat / lower patch pocket","Coat / pen breast pocket"),coat,"box",high=.004)
    attach(select("Coat / lower pocket face"),select("Coat / lower patch pocket"),"box",high=.0025)
    attach(select("Coat / pen pocket face"),select("Coat / pen breast pocket"),"box",high=.0025)
    attach(select("Coat / pocket opening welt"),select("Coat / lower pocket face","Coat / lower patch pocket")+coat,"ribbon",high=.0015)
    attach(select("Coat / horn button"),select("Coat / long front facing")+coat+vest+shirt,"oval",low=-.001,high=.006,sides=18)
    attach(select("Coat / button highlight"),select("Coat / horn button"),"oval",low=-.0002,high=.0008,sides=10)
    attach(select("Waistcoat / center button"),vest+shirt,"oval",low=-.001,high=.006,sides=18)
    attach(select("Waistcoat / button rim"),select("Waistcoat / center button"),"oval",low=-.0002,high=.0008,sides=10)
    attach(select("Shirt / throat button"),select("Shirt / button placket")+shirt+neck,"oval",high=.003,sides=12)
    attach(select("Research / pen barrel"),coat,"box",low=-.001,high=.005)
    attach(select("Research / pen clip"),select("Research / pen barrel","Coat / pen pocket face")+coat,"tube",high=.001,sides=10)
    for side in ["l","r"]:
        sign=1 if side=="l" else -1
        attach(select("Trousers / outer seam "+side),select("Trousers / leg "+side),"tube",high=.0008,sides=10,axis=0,side=sign)
    attach(select("Boot / heel seam"),select("Boot / leather toe and shaft"),"tube",high=.0008,sides=10,side=-1)
    # A small sewn-cloth clearance avoids coplanar edge flicker after Godot's
    # vertex compression. Move complete front layers together, including trim.
    fitted={p["name"] for p in report}
    for part in parts:
        if is_front_layer(part["name"]) and part["name"] in fitted:
            part["vertices"][:,2] += .0025
    return report


def is_front_layer(name):
    return is_clothing(name) and name.startswith(("Coat /", "Shirt /", "Waistcoat /", "Research /")) and not name.startswith((
        "Coat / shoulder seam", "Coat / back center seam", "Coat / collar stand",
        "Coat / long open shell", "Coat / inner lining", "Coat / worn sleeve", "Coat / worn cuff",
        "Coat / subtle hem weathering", "Shirt / slate button-up"))


def fit_authored_clothing(character, fit=fit_clothing, include=is_clothing):
    parts,offsets=[],{}
    for part in character.parts:
        color=part["material"];offset=offsets.get(color,0);offsets[color]=offset+part["triangles"]
        start=part["vertex_start"];g=character.geometry[color];end=start+part["vertex_count"]
        parts.append({"name":part["name"],"vertices":np.asarray(g["vertices"][start:end]),
                      "faces":np.asarray(g["faces"][offset:offsets[color]])-start,
                      "weights":g["weights"][start:end],"original":part})
    report=fit([p for p in parts if include(p["name"])])
    character.geometry=defaultdict(lambda:{"vertices":[],"faces":[],"weights":[]})
    character.parts=[]
    for part in parts:
        original=part["original"];g=character.geometry[original["material"]];start=len(g["vertices"])
        g["vertices"].extend(part["vertices"].tolist())
        g["faces"].extend((part["faces"]+start).tolist())
        g["weights"].extend(part["weights"])
        if 'normals' in part:
            g.setdefault('normal_overrides',{}).update({start+i:n.tolist() for i,n in enumerate(part['normals'])})
        character.parts.append(dict(original,vertex_start=start,vertex_count=len(part["vertices"]),triangles=len(part["faces"])))
    return report
