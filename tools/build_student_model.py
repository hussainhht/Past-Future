"""Build the game's original student mesh using only Python's standard library.
Run from any directory: python3 tools/build_student_model.py
Writes assets/characters/student_v2.glb. Coordinates are metres, Y up, +Z forward.
"""
from pathlib import Path
import json
import math
import struct

ROOT = Path(__file__).resolve().parents[1]
COLORS = {
    'jacket': 'b18c52', 'jacket_trim': 'c49b5e', 'jacket_shadow': '856439',
    'shirt': 'eee0bd', 'skin': 'd7a179', 'skin_shadow': 'b97b59',
    'hair': '392c28', 'hair_mid': '49362d', 'hair_light': '5a4030',
    'pants': '354655', 'pants_seam': '455769', 'boots': '4b3930',
    'sole': '262e33', 'bag': '805838', 'bag_edge': 'a27a4b',
    'metal': 'd8b56b', 'eye_white': 'f5e9d3', 'eyes': '202a2d',
    'badge': '82b9b6',
}
nodes, meshes, accessors, views = [], [], [], []
blob = bytearray()
roots = []

def vadd(a,b): return tuple(x+y for x,y in zip(a,b))
def vsub(a,b): return tuple(x-y for x,y in zip(a,b))
def vmul(a,s): return tuple(x*s for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return vmul(a,1/max(math.sqrt(dot(a,a)),1e-12))
def linear(x): return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4

def node(name, pos=(0,0,0), parent=None):
    i=len(nodes); nodes.append({'name':name,'translation':list(pos)})
    if parent is None: roots.append(i)
    else: nodes[parent].setdefault('children',[]).append(i)
    return i

def accessor(data, count, kind, component, target, bounds=False):
    while len(blob)%4: blob.append(0)
    offset=len(blob); blob.extend(data)
    view=len(views); views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data),'target':target})
    item={'bufferView':view,'componentType':component,'count':count,'type':kind}
    if bounds:
        floats=struct.unpack('<'+'f'*(len(data)//4),data)
        item['min']=[min(floats[j::3]) for j in range(3)]
        item['max']=[max(floats[j::3]) for j in range(3)]
    accessors.append(item); return len(accessors)-1

def mesh(name, verts, faces, material, parent=None, pos=(0,0,0)):
    normals=[(0.,0.,0.) for _ in verts]
    for a,b,c in faces:
        n=cross(vsub(verts[b],verts[a]),vsub(verts[c],verts[a]))
        for i in (a,b,c): normals[i]=vadd(normals[i],n)
    normals=[unit(n) for n in normals]
    pack=lambda vs: struct.pack('<'+'f'*(len(vs)*3),*(x for v in vs for x in v))
    p=accessor(pack(verts),len(verts),'VEC3',5126,34962,True)
    n=accessor(pack(normals),len(normals),'VEC3',5126,34962)
    indices=[i for f in faces for i in f]
    ix=accessor(struct.pack('<'+'I'*len(indices),*indices),len(indices),'SCALAR',5125,34963)
    mid=len(meshes)
    meshes.append({'name':name,'primitives':[{'attributes':{'POSITION':p,'NORMAL':n},'indices':ix,'material':list(COLORS).index(material)}]})
    ni=node(name,pos,parent); nodes[ni]['mesh']=mid
    return ni

def rings_mesh(name, rings, material, parent=None, pos=(0,0,0)):
    n=len(rings[0]); verts=[v for ring in rings for v in ring]; faces=[]
    for r in range(len(rings)-1):
        for j in range(n):
            a=r*n+j;b=r*n+(j+1)%n;c=(r+1)*n+(j+1)%n;d=(r+1)*n+j
            faces.extend([(a,b,c),(a,c,d)])
    for ring,reverse in [(0,True),(len(rings)-1,False)]:
        center=tuple(sum(v[k] for v in rings[ring])/n for k in range(3))
        ci=len(verts);verts.append(center)
        for j in range(n):
            a=ring*n+j;b=ring*n+(j+1)%n
            faces.append((ci,b,a) if reverse else (ci,a,b))
    return mesh(name,verts,faces,material,parent,pos)

def loft(name, sections, material, parent=None, segments=16, power=2, pos=(0,0,0)):
    rings=[]
    for y,rx,rz,cx,cz in sections:
        ring=[]
        for j in range(segments):
            t=2*math.pi*j/segments; sx=math.sin(t); sz=math.cos(t)
            ring.append((cx+rx*math.copysign(abs(sx)**(2/power),sx),y,cz+rz*math.copysign(abs(sz)**(2/power),sz)))
        rings.append(ring)
    return rings_mesh(name,rings,material,parent,pos)

def ellipsoid(name, center, scale, material, parent=None, segments=16, rows=10):
    sections=[]
    for k in range(rows+1):
        a=-math.pi/2+math.pi*k/rows
        sections.append((center[1]+scale[1]*math.sin(a),max(.001,scale[0]*math.cos(a)),max(.001,scale[2]*math.cos(a)),center[0],center[2]))
    return loft(name,sections,material,parent,segments)

def rounded_box(name, center, size, material, parent=None):
    x,y,z=center;w,h,d=size; b=min(w,h,d)*.18
    sections=[(y-h/2,w/2-b,d/2-b,x,z),(y-h/2+b,w/2,d/2,x,z),(y+h/2-b,w/2,d/2,x,z),(y+h/2,w/2-b,d/2-b,x,z)]
    return loft(name,sections,material,parent,16,4)

def patch(name, outline, depth, material, parent=None):
    # Outline is clockwise as seen from +Z; bevel gives lapels and seams real thickness.
    if sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))<0:
        outline=list(reversed(outline))
    n=len(outline); center=tuple(sum(v[k] for v in outline)/n for k in range(3))
    verts=list(outline)+[(center[0]+(x-center[0])*.86,center[1]+(y-center[1])*.92,z+depth) for x,y,z in outline]
    faces=[]
    for i in range(n):
        j=(i+1)%n;faces.extend([(i,j,j+n),(i,j+n,i+n)])
    ci=len(verts);verts.append((center[0],center[1],center[2]+depth))
    for i in range(n): faces.append((ci,i+n,(i+1)%n+n))
    return mesh(name,verts,faces,material,parent)

def tube(name, path, radii, material, parent=None, sides=10):
    rings=[]
    for i,p in enumerate(path):
        tangent=unit(vsub(path[min(i+1,len(path)-1)],path[max(0,i-1)]))
        ref=(0,0,1) if abs(tangent[2])<.9 else (1,0,0)
        u=unit(cross(tangent,ref));v=unit(cross(u,tangent))
        # ring orientation follows increasing distance along the path
        rings.append([vadd(p,vadd(vmul(u,math.sin(2*math.pi*j/sides)*radii[i][0]),vmul(v,math.cos(2*math.pi*j/sides)*radii[i][1]))) for j in range(sides)])
    return rings_mesh(name,rings,material,parent)

# A tailored torso with a narrower waist and integrated shoulders.
loft('Jacket',[(.83,.215,.14,0,0),(.87,.255,.17,0,0),(1.02,.245,.17,0,0),(1.29,.29,.19,0,0),(1.43,.315,.175,0,-.015),(1.49,.235,.135,0,-.015),(1.51,.14,.10,0,0)],'jacket',power=3)
loft('JacketHem',[(.83,.22,.145,0,0),(.85,.257,.174,0,0),(.89,.257,.174,0,0)],'jacket_shadow',power=3)
patch('Shirt',[(-.13,1.47,.15),(.13,1.47,.15),(.08,1.01,.177),(-.075,1.01,.177)],.015,'shirt')
patch('LeftLapel',[(-.13,1.50,.14),(-.245,1.43,.15),(-.085,1.15,.19),(-.015,1.34,.20)],.025,'jacket_trim')
patch('RightLapel',[(.13,1.50,.14),(.245,1.43,.15),(.085,1.15,.19),(.015,1.34,.20)],.025,'jacket_trim')
for side in [-1,1]:
    x=side*.166
    patch(('Left' if side<0 else 'Right')+'Pocket',[(x-.063,1.12,.18),(x+.063,1.12,.18),(x+.058,.99,.178),(x-.058,.99,.178)],.012,'jacket_shadow')
    rounded_box(('Left' if side<0 else 'Right')+'PocketFlap',(x,1.115,.20),(.14,.032,.025),'jacket_trim')
for i,y in enumerate([1.17,1.08,.96]): ellipsoid(f'JacketButton{i}',(.035,y,.207),(.015,.015,.01),'metal',segments=8,rows=6)
rounded_box('StudentBadge',(-.15,1.30,.197),(.09,.115,.015),'shirt')
rounded_box('BadgeStripe',(-.15,1.325,.209),(.077,.025,.008),'badge')
rounded_box('BadgePortrait',(-.167,1.284,.209),(.027,.036,.008),'pants')
loft('Waist',[(.73,.22,.135,0,0),(.86,.23,.15,0,0)],'pants',power=3)

# Shaped jaw and cheeks instead of a sphere; facial features follow the front surface.
head=node('Head')
loft('Neck',[(1.43,.09,.08,0,0),(1.63,.105,.09,0,0)],'skin',head)
loft('Face',[(1.57,.11,.10,0,.025),(1.61,.19,.16,0,.02),(1.68,.255,.20,0,.005),(1.78,.30,.235,0,0),(1.90,.295,.225,0,-.01),(2.00,.245,.19,0,-.015),(2.055,.12,.11,0,-.02),(2.07,.02,.02,0,-.02)],'skin',head,24)
for side in [-1,1]:
    prefix='Left' if side<0 else 'Right'
    ellipsoid(prefix+'Ear',(side*.298,1.78,-.01),(.062,.091,.053),'skin',head)
    ellipsoid(prefix+'EarInset',(side*.329,1.78,.023),(.022,.048,.018),'skin_shadow',head)
    x=side*.125
    ellipsoid(prefix+'EyeRim',(x,1.84,.212),(.077,.058,.030),'skin_shadow',head)
    ellipsoid(prefix+'EyeWhite',(x,1.843,.231),(.062,.044,.023),'eye_white',head)
    ellipsoid(prefix+'Iris',(x+side*.004,1.841,.251),(.030,.036,.012),'eyes',head)
    ellipsoid(prefix+'EyeGlint',(x-.009,1.855,.262),(.009,.010,.005),'eye_white',head,8,6)
    tube(prefix+'Brow',[(x-side*.068,1.918,.227),(x,1.929,.235),(x+side*.062,1.917,.207)],[(.013,.012),(.018,.014),(.009,.008)],'hair',head)
# A narrow bridge and softly bevelled nose tip.
loft('Nose',[(1.745,.032,.018,0,.246),(1.758,.051,.037,0,.261),(1.79,.035,.038,0,.26),(1.85,.021,.015,0,.237)],'skin',head,12)
tube('Mouth',[(-.059,1.686,.197),(0,1.68,.209),(.059,1.687,.197)],[(.007,.005),(.008,.005),(.006,.004)],'skin_shadow',head)

# Swept hair cap with an irregular hairline and overlapping sculpted locks.
rings=[]
for level in range(6):
    ring=[]
    for j in range(24):
        a=2*math.pi*j/24;front=max(0,math.cos(a)); low=1.79+.16*front+.018*math.sin(3*a)
        t=level/5; y=low+(2.11-low)*t
        radius=[1,1.04,1.02,.88,.60,.04][level]
        ring.append((.311*math.sin(a)*radius,y,-.025+.249*math.cos(a)*radius))
    rings.append(ring)
rings_mesh('HairCap',rings,'hair',head)
for i in range(4):
    z=-.035+i*.048
    path=[(-.24+i*.026,2.025,z),(-.13+i*.025,2.08,z+.055),(.08+i*.025,2.065,z+.11),(.19+i*.018,1.94+i*.012,z+.14)]
    tube(f'SweptLock{i}',path,[(.028,.025),(.045,.037),(.047,.034),(.003,.003)],'hair_mid' if i%2 else 'hair_light',head,12)
for side in [-1,1]:
    tube(('Left' if side<0 else 'Right')+'Sideburn',[(side*.279,1.96,.045),(side*.295,1.85,.075),(side*.27,1.76,.07)],[(.043,.035),(.037,.030),(.012,.012)],'hair',head)

# Articulated sleeves, forearms and hands.
for side,prefix in [(-1,'Left'),(1,'Right')]:
    arm=node(prefix+'Arm',(side*.325,1.425,0))
    loft(prefix+'Sleeve',[(0,.11,.115,0,0),(-.06,.12,.12,side*.012,0),(-.23,.09,.095,side*.035,0),(-.28,.082,.085,side*.035,0)][::-1],'jacket',arm)
    elbow=node(prefix+'Elbow',(side*.035,-.27,0),arm)
    loft(prefix+'Forearm',[(-.225,.063,.068,0,.015),(-.19,.072,.077,0,.012),(-.04,.086,.088,0,0),(0,.084,.087,0,0)],'jacket',elbow)
    loft(prefix+'Cuff',[(-.23,.068,.073,0,.015),(-.19,.075,.081,0,.015)],'jacket_trim',elbow)
    loft(prefix+'Hand',[(-.35,.037,.047,0,.026),(-.32,.059,.06,0,.023),(-.26,.065,.063,0,.018),(-.225,.047,.05,0,.015)],'skin',elbow)
    ellipsoid(prefix+'Thumb',(-side*.055,-.275,.052),(.027,.048,.029),'skin',elbow)

# Tapered trousers, knee pivots, welted shoes and laces.
for side,prefix in [(-1,'Left'),(1,'Right')]:
    leg=node(prefix+'Leg',(side*.137,.86,0))
    loft(prefix+'Thigh',[(-.38,.095,.102,0,0),(-.32,.102,.11,0,0),(-.08,.133,.135,0,0),(0,.13,.13,0,0)],'pants',leg,power=2.7)
    knee=node(prefix+'Knee',(0,-.38,0),leg)
    loft(prefix+'Shin',[(-.35,.084,.083,0,.004),(-.30,.095,.09,0,0),(-.06,.096,.103,0,0),(0,.095,.102,0,0)],'pants',knee,power=2.7)
    loft(prefix+'TrouserCuff',[(-.35,.095,.095,0,.002),(-.31,.099,.10,0,0)],'pants_seam',knee,power=3)
    loft(prefix+'Sole',[(-.48,.11,.21,0,.075),(-.46,.135,.245,0,.075),(-.425,.134,.242,0,.075)],'sole',knee,power=3.5)
    loft(prefix+'Shoe',[(-.425,.126,.233,0,.075),(-.39,.13,.23,0,.075),(-.335,.111,.19,0,.045),(-.30,.083,.11,0,-.005)],'boots',knee,power=3)
    for i in range(3):
        tube(prefix+f'Lace{i}',[(-.058,-.33-i*.018,.06+i*.036),(.058,-.33-i*.018,.06+i*.036)],[(.007,.006)]*2,'bag_edge',knee,6)

# Leather messenger bag sits behind the right hip; strap wraps around the torso.
rounded_box('Satchel',(.285,.94,-.20),(.26,.34,.19),'bag')
rounded_box('SatchelFlap',(.285,1.08,-.19),(.29,.11,.22),'bag_edge')
rounded_box('BagClasp',(.30,1.03,-.067),(.055,.065,.018),'metal')
tube('FrontStrap',[(-.21,1.48,.165),(-.12,1.37,.214),(.01,1.19,.227),(.16,1.00,.192),(.29,.96,.04)],[(.026,.012)]*5,'bag',sides=8)
tube('BackStrap',[(-.21,1.48,-.10),(-.09,1.29,-.198),(.12,1.10,-.20),(.285,1.08,-.20)],[(.027,.012)]*4,'bag',sides=8)
rounded_box('StrapBuckle',(-.055,1.28,.245),(.075,.09,.018),'metal')

materials=[]
for name,h in COLORS.items():
    rgb=[linear(int(h[i:i+2],16)/255) for i in (0,2,4)]
    materials.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':rgb+[1],'metallicFactor':0,'roughnessFactor':.85},'doubleSided':False})
doc={'asset':{'version':'2.0','generator':'Past & Future original student mesh builder'},'scene':0,'scenes':[{'name':'StudentModel','nodes':roots}],'nodes':nodes,'meshes':meshes,'materials':materials,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(blob)}]}
js=json.dumps(doc,separators=(',',':')).encode()
while len(js)%4: js+=b' '
while len(blob)%4: blob.append(0)
out=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(blob))+struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(blob),b'BIN\0')+blob
path=ROOT/'assets/characters/student_v2.glb';path.write_bytes(out)
tris=sum(a['count']//3 for a in accessors if a['type']=='SCALAR')
print(f'Built {path.name}: {len(meshes)} mesh parts, {tris:,} triangles, {len(out):,} bytes')
