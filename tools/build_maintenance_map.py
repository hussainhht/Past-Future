"""Author the editable Level 02 layout using native Godot meshes and existing licensed props.
Run from any directory: python3 tools/build_maintenance_map.py.
Gameplay and network state live in the room controller, not this map.
"""
from pathlib import Path
from math import atan2, degrees, hypot, sin, cos, pi
ROOT=Path(__file__).resolve().parents[1]
resources=[];nodes=[];serial=0

def value(v):
    if isinstance(v,str):return '"'+v.replace('"','\\"')+'"'
    if isinstance(v,bool):return str(v).lower()
    if isinstance(v,(list,tuple)):return 'Vector3('+', '.join(str(x) for x in v)+')'
    return str(v)
def res(kind,body):
    global serial
    serial+=1;name=f'{kind}_{serial}'
    resources.append(f'[sub_resource type="{kind}" id="{name}"]\n'+body+'\n')
    return 'SubResource("'+name+'")'
def node(name,kind='Node3D',parent='.',**props):
    head=f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent is not None else '')+']'
    nodes.append(head+'\n'+'\n'.join(f'{k} = {value(v)}' for k,v in props.items())+'\n')
    return name if parent in ('.',None) else parent+'/'+name

def raw_node(name,kind,parent,**props):
    # Mesh/shape references are expressions, other properties use normal value formatting.
    head=f'[node name="{name}" type="{kind}" parent="{parent}"]'
    nodes.append(head+'\n'+'\n'.join(f'{k} = {v if k in ("mesh","shape","material_override") else value(v)}' for k,v in props.items())+'\n')
    return name if parent in ('.',None) else parent+'/'+name

def mat(hexcolor,emit=False,name=""):
    rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    body='resource_name = "corridor_'+name+'"\nalbedo_color = Color('+', '.join(map(str,rgb))+', 1)\nroughness = 0.85'
    if emit:body+='\nemission_enabled = true\nemission = Color('+', '.join(map(str,rgb))+', 1)\nemission_energy_multiplier = 0.5'
    return res('StandardMaterial3D',body)
M={n:mat(c,n in ['cyan','amber','red'],n) for n,c in dict(
 floor='65675e',future_floor='38484c',tile='73776c',edge='25373a',wall='929381',future_wall='48595d',
 steel='4b6060',dark='172a30',copper='a27b47',yellow='d9af59',cyan='7dc6ce',amber='d8a858',red='bb654d',
 concrete='66695f',black='111d23',paper='e6d7b1',wood='745a43',
 off='314147',green='70bea0',insulator='c1bdaa',rust='755448',blue='4d8b9f').items()}

def box(name,parent,pos,size,material,solid=False,rotation=None):
    root=node(name,'StaticBody3D' if solid else 'Node3D',parent,position=pos)
    if rotation:nodes[-1]+='rotation_degrees = '+value(rotation)+'\n'
    mesh=res('BoxMesh','size = '+value(size))
    raw_node('Mesh','MeshInstance3D',root,mesh=mesh,material_override=M[material])
    if solid:
        shape=res('BoxShape3D','size = '+value(size));raw_node('Collision','CollisionShape3D',root,shape=shape)
    return root

def cylinder(name,parent,pos,radius,height,material,rotation=None):
    path=node(name,parent=parent,position=pos)
    if rotation:nodes[-1]+='rotation_degrees = '+value(rotation)+'\n'
    mesh=res('CylinderMesh',f'top_radius = {radius}\nbottom_radius = {radius}\nheight = {height}\nradial_segments = 16')
    raw_node('Mesh','MeshInstance3D',path,mesh=mesh,material_override=M[material]);return path

def label(name,parent,pos,text,size=48,color='e2d5b4',billboard=True):
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    path=node(name,'Label3D',parent,position=pos,text=text,font_size=size,pixel_size=.005,billboard=1 if billboard else 0,no_depth_test=False)
    nodes[-1]+='modulate = Color('+', '.join(map(str,rgb))+', 1)\noutline_size = 5\ntexture_filter = 5\n'
    return path

def floor_text(name,parent,pos,text,size=64,color='c5c6ad'):
    path=label(name,parent,pos,text,size,color,False)
    nodes[-1]+='rotation_degrees = Vector3(-90, 0, 0)\n'
    return path

def torus(name,parent,pos,inner,outer,material,rotation=(90,0,0)):
    mesh=res('TorusMesh',f'inner_radius = {inner}\nouter_radius = {outer}\nrings = 32\nring_segments = 8')
    return raw_node(name,'MeshInstance3D',parent,mesh=mesh,material_override=M[material],position=pos,rotation_degrees=rotation)

def line(name,parent,start,end,width,material,y=.025,height=.022):
    x,z=start;ex,ez=end
    return box(name,parent,((x+ex)/2,y,(z+ez)/2),(width,height,hypot(ex-x,ez-z)),material,rotation=(0,degrees(atan2(ex-x,ez-z)),0))

def arrow(name,parent,x,z,material='yellow'):
    line(name+'L',parent,(x-.2,z+.22),(x,z),.065,material)
    line(name+'R',parent,(x+.2,z+.22),(x,z),.065,material)

def hazard(name,parent,x,z,width):
    box(name+'Bed',parent,(x,.017,z),(width,.022,.28),'dark')
    for i in range(int(width/.36)):
        box(name+str(i),parent,(x-width/2+.18+i*.36,.032,z),(.14,.009,.26),'yellow',rotation=(0,-28,0))

def route(name,points):
    root=node(name,parent='Shared/PowerRoutes')
    for i,(start,end) in enumerate(zip(points,points[1:])):
        line('Conduit'+str(i),root,start,end,.14,'dark',.035,.04)
        line('Current'+str(i),root,start,end,.047,'off',.060,.012)
    return root

def device(name,pos,text,material='steel'):
    node(name,'Marker3D','Devices',position=pos)
    parent=box(name+'Stand','Shared',(pos[0],.52,pos[2]-.48),(1.2,1.04,.68),material,True)
    box('Panel',parent,(0,.62,.04),(1.06,.24,.58),'dark')
    box('Indicator',parent,(-.43,.78,.1),(.10,.04,.25),'off')
    label(name+'Label','Shared',(pos[0],2.0,pos[2]-.45),text,52)
    # A small brass identification plate and a clear approach pad ground every terminal.
    box('Plate',parent,(0,.17,.35),(.62,.20,.035),'copper')
    box(name+'Pad','Shared',(pos[0],.012,pos[2]+.10),(1.45,.018,.85),'edge')
    box(name+'PadEdge','Shared',(pos[0],.025,pos[2]+.5),(1.35,.008,.045),'yellow')
    return parent

def instance(name,parent,pos,path,scale=(1,1,1),yaw=0):
    global serial
    serial+=1;ext=f'asset_{serial}';exts.append(f'[ext_resource type="PackedScene" path="{path}" id="{ext}"]')
    nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("{ext}")]\nposition = {value(pos)}\nscale = {value(scale)}\nrotation_degrees = Vector3(0, {yaw}, 0)\n')

def storage_floor(name,y,height,material,left,right,near,far,solid=False):
    # Boundaries subdivide the rectangle; cells inside the three hatch footprints are omitted.
    xs=sorted({left,right,-2.43,-1.07,-.68,.68,1.07,2.43})
    zs=sorted({near,far,-6.93,-5.57})
    for xi,(x1,x2) in enumerate(zip(xs,xs[1:])):
        for zi,(z1,z2) in enumerate(zip(zs,zs[1:])):
            x,z=(x1+x2)/2,(z1+z2)/2
            if -6.93 < z < -5.57 and any(abs(x-center)<.68 for center in [-1.75,0,1.75]):continue
            box(f'{name}_{xi}_{zi}','Shared',(x,y,z),(x2-x1,height,z2-z1),material,solid)

exts=[]
node('MaintenanceLayout',parent=None)
for name in ['Shared','PastOnly','FutureOnly','Devices']:
    node(name,**({'visible':False} if name=='FutureOnly' else {}))
# All floor tops are exactly y=0. Both eras have a continuous route to storage.
box('SouthFloor','Shared',(0,-.2,4.85),(16,.4,8.1),'floor',True)
storage_floor('NorthFloor',-.2,.4,'floor',-8,8,-9.6,-2.8,True)
box('CoreFloor','Shared',(0,-.2,-12.0),(8,.4,4.8),'floor',True)
box('IntactWalkway','PastOnly',(0,-.2,-1.0),(16,.4,3.6),'floor',True)
box('AgedWalkway','FutureOnly',(0,-.2,-1.0),(16,.4,3.6),'floor',True)
for side in [-1,1]:
    box('SideWall'+str(side),'Shared',(side*8.25,1.4,-.1),(.4,2.8,19.9),'wall',True)
    box('CoreSide'+str(side),'Shared',(side*4.2,1.3,-12),(.4,2.6,5),'wall',True)
    box('Bulkhead'+str(side),'Shared',(side*5,1.6,-9.7),(6.4,3.2,.4),'wall',True)
    cylinder('Pipe'+str(side),'Shared',(side*7.7,2.6,-.2),.10,19,'copper',(90,0,0))
    for z in [7,3,-4,-8]:
        box('WallFoot'+str(side)+'_'+str(z),'Shared',(side*7.8,1.4,z),(.45,2.8,.55),'steel')
box('EntryWall','Shared',(0,.4,9.1),(16.5,.8,.4),'wall',True)
box('CoreEnd','Shared',(0,1.4,-14.5),(8.5,2.8,.4),'wall',True)
floor_text('EntrySign','Shared',(0,.025,8.5),'02 / MAINTENANCE',58)
label('NorthSign','Shared',(0,3.35,-9.5),'CORE / AUTHORIZED ACCESS',70)
label('CoreSign','Shared',(0,2.8,-14.2),'ANCHOR 01',86)
for z in [7.8,5.8,3.8,1.8,-3.6,-5.25,-7.6]:
    box('FloorJoint'+str(z),'Shared',(0,.004,z),(15.7,.006,.025),'edge')
for side in [-1,1]:
    box('Lane'+str(side),'Shared',(side*2.5,.008,4.8),(.07,.009,8),'yellow')
    box('NorthLane'+str(side),'Shared',(side*2.5,.008,-6.1),(.07,.009,6.5),'yellow')
# Grounded stations stay out of the central walking lane.
device('Service',(-5.7,0,7.5),'SERVICE ISOLATOR')
device('ReservePast',(-2.5,0,7.5),'LOCAL RESERVE / I')
device('ReserveFuture',(2.5,0,7.5),'LOCAL RESERVE / II')
device('Battery',(5.7,0,7.5),'EMERGENCY CELL')
wheel=res('TorusMesh','inner_radius = 0.22\nouter_radius = 0.29\nrings = 24\nring_segments = 8')
crank=node('CrankWheel',parent='Shared/BatteryStand',position=(0,.95,.38))
raw_node('Mesh','MeshInstance3D',crank,mesh=wheel,material_override=M['copper'],rotation_degrees=(90,0,0))
box('CrankGrip',crank,(.25,.01,.09),(.10,.10,.28),'yellow')
device('BypassPast',(-6.2,0,4.7),'BYPASS / I')
device('BypassFuture',(6.2,0,4.7),'BYPASS / II')
device('Archive',(-5.4,0,-5.8),'MAINTENANCE ARCHIVE','wood')
device('Recorder',(5.4,0,-5.8),'INCIDENT RECORDER')
for side in [-1,1]:
    reel=res('CylinderMesh','top_radius = 0.19\nbottom_radius = 0.19\nheight = 0.07\nradial_segments = 24')
    raw_node('Reel'+str(side),'MeshInstance3D','Shared/RecorderStand',mesh=reel,material_override=M['copper'],position=(side*.27,.6,.40),rotation_degrees=(90,0,0))
box('Cell','Shared/RecorderStand',(0,.19,.39),(.35,.21,.10),'amber')
device('Keypad',(2.6,0,-8.2),'CORE AUTHORIZATION')
device('Release',(-2.6,0,-8.2),'MANUAL RELEASE')
device('Anchor',(0,0,-12.8),'STABILIZATION CONTROL')
node('Audit','Marker3D','Devices',position=(2.4,0,-12.5))
label('AuditLabel','Shared',(2.4,1.4,-12.5),'CORE AUDIT',40)
for variant,color in [('PastOnly','amber'),('FutureOnly','cyan')]:
    box('CoreGate',variant,(0,1.4,-9.7),(3.5,2.8,.3),'steel',True)
    box('GateBand',variant,(0,1.8,-9.51),(2.8,.13,.04),color)
# Reuse existing project models, preserving their authored asset provenance.
for side in [-1,1]:
    instance('Cabinet'+str(side),'Shared',(side*7.2,0,-6.6),'res://scenes/environment/props/cabinet_low.tscn',yaw=-side*90)
    instance('PipeDebris'+str(side),'FutureOnly',(side*6,0,-3.7),'res://scenes/environment/props/pipe_broken.tscn',yaw=side*35)
    instance('Rubble'+str(side),'FutureOnly',(side*4.7,0,-1.2),'res://scenes/environment/props/debris_a.tscn')
for i,z in enumerate([6,1,-5,-11]):
    for side in [-1,1]:
        box(f'Lamp_{i}_{side}','Shared',(side*7.65,2.65,z),(.20,.38,.7),'dark')
        box(f'LampLens_{i}_{side}','Shared',(side*7.51,2.65,z),(.06,.23,.48),'paper')
        node(f'Pool_{i}_{side}','OmniLight3D','Shared',position=(side*7,2.5,z),omni_range=4.2,light_energy=.22)
# Future wear: broken tiles and boundary damage without randomizing the playable path.
for i,(x,z) in enumerate([(-7,6.5),(7,2.4),(-6,-4.5),(6,-7.8)]):
    instance('BrokenTiles'+str(i),'FutureOnly',(x,.02,z),'res://scenes/environment/props/debris_tiles.tscn')
# Architectural detail: service trenches, wainscoting, repeating expansion panels and roof ribs.
# The roof stays open toward the camera; all set dressing stays outside the walking lane.
node('Architecture',parent='Shared')
for side in [-1,1]:
    for z in [8,6,4,2,0,-2,-4,-6,-8]:
        box(f'WallInset_{side}_{z}','Shared/Architecture',(side*8.015,1.45,z),(.025,1.65,1.65),'tile')
        box(f'WallBase_{side}_{z}','Shared/Architecture',(side*7.99,.24,z),(.08,.45,1.9),'edge')
        box(f'DrainFrame_{side}_{z}','Shared/Architecture',(side*7.5,.015,z),(.48,.022,1.8),'dark')
        for n in range(7):
            box(f'DrainRib_{side}_{z}_{n}','Shared/Architecture',(side*7.5,.031,z-.75+n*.25),(.43,.022,.04),'steel')
    for z in [8.4,3.5,-4.1,-8.9]:
        box(f'ColumnShoe_{side}_{z}','Shared/Architecture',(side*7.8,.16,z),(.65,.32,.72),'edge')
        box(f'ColumnTrim_{side}_{z}','Shared/Architecture',(side*7.8,2.65,z),(.58,.16,.72),'copper')
        cylinder(f'PipeDrop_{side}_{z}','Shared/Architecture',(side*7.64,1.35,z-.32),.055,2.5,'steel')
    # Suspended ribs stop at the wall so the overview and player remain unobscured.
    for z in [5.9,-5.3]:
        box(f'Rib_{side}_{z}','Shared/Architecture',(side*7.1,3.0,z),(2.2,.18,.2),'edge')
        box(f'RibBrace_{side}_{z}','Shared/Architecture',(side*7.3,2.75,z),(1.0,.12,.16),'steel',rotation=(0,0,side*26))

# Clear visual rhythm: power bay -> storage room -> Core.
box('PowerBayInset','Shared',(0,.006,6.25),(14.5,.008,4.7),'tile')
storage_floor('RecordsBayInset',.006,.008,'tile',-7.25,7.25,-8.85,-3.35)
for name,z,text in [('PowerBayTitle',8.0,'01 / POWER DISTRIBUTION'),('StorageRouteTitle',3.15,'STORAGE / STRAIGHT AHEAD'),('RecordsBayTitle',-4.25,'02 / STORAGE + ARCHIVE')]:
    floor_text(name,'Shared',(0,.035,z),text,54)
for z in [6,4.8,-3.5,-4.9,-7.4,-10.8,-11.7]: arrow('Route'+str(z),'Shared',0,z)
# Surface-mounted conduits communicate the shared circuit; the controller changes current strips.
node('PowerRoutes',parent='Shared')
route('Main',[(-5.7,6.7),(-5.7,6.05),(5.7,6.05),(5.7,6.7)])
route('PastFeed',[(-2.5,6.7),(-2.5,6.4),(-6.5,6.4),(-6.5,3.75),(-3.4,3.75)])
route('FutureFeed',[(2.5,6.7),(2.5,6.4),(6.5,6.4),(6.5,3.75),(3.4,3.75)])
route('Bypass',[(-6.2,4.0),(-7.0,4.0),(-7.0,5.65),(7.0,5.65),(7.0,4.0),(6.2,4.0)])
floor_text('BypassStencil','Shared',(0,.09,5.60),'ISOLATED BYPASS',34,'b2bcac')

# Distinct terminal silhouettes: equipment explains function before the player opens a panel.
service='Shared/ServiceStand'
box('BreakerBack',service,(0,.97,-.12),(1.08,.64,.18),'edge')
for i in range(3):
    box('Fuse'+str(i),service,(-.32+i*.32,1.0,.005),(.16,.32,.12),'insulator')
box('LeverMount',service,(0,.78,.24),(.48,.18,.16),'copper')
box('IsolatorLever',service,(0,1.0,.30),(.12,.58,.12),'red',rotation=(-28,0,0))
for name in ['ReservePast','ReserveFuture']:
    p='Shared/'+name+'Stand'
    box('MeterHousing',p,(0,1.03,-.12),(.9,.49,.24),'copper')
    cylinder('MeterFace',p,(-.16,1.08,.025),.18,.035,'paper',(90,0,0))
    box('MeterNeedle',p,(-.16,1.10,.05),(.025,.21,.012),'red',rotation=(0,0,-35))
    box('ReserveLever',p,(.30,.92,.26),(.10,.37,.10),'yellow',rotation=(-35,0,0))
    box('MeterLamp',p,(.30,1.14,.04),(.08,.09,.03),'off')

battery='Shared/BatteryStand'
for side in [-1,1]:
    cylinder('BatteryCan'+str(side),battery,(side*.28,.89,-.08),.20,.67,'dark')
    cylinder('Cap'+str(side),battery,(side*.28,1.25,-.08),.14,.06,'copper')
    box('CellStripe'+str(side),battery,(side*.28,.91,.13),(.21,.26,.018),'amber')
box('CageTop',battery,(0,1.34,-.08),(1.0,.09,.55),'steel')
for name in ['BypassPast','BypassFuture']:
    p='Shared/'+name+'Stand'
    box('FuseBack',p,(0,1.0,-.13),(1.04,.64,.12),'dark')
    box('OpenCover',p,(-.67,1.0,-.13),(.35,.64,.06),'copper',rotation=(0,-35,0))
    for side in [-1,1]:
        cylinder('Contact'+str(side),p,(side*.29,1.02,.01),.085,.10,'copper',(90,0,0))
    box('FuseLink',p,(0,1.02,.10),(.47,.12,.12),'insulator')
    torus('EarthLoop',p,(.30,.41,.40),.20,.235,'yellow')

archive='Shared/ArchiveStand'
box('ArchiveShelf',archive,(0,1.1,-.18),(1.1,.68,.42),'wood')
box('ShelfDark',archive,(0,1.12,.045),(.95,.49,.018),'dark')
for i in range(6):
    box('Folder'+str(i),archive,(-.37+i*.145,1.10,.11),(.105,.36,.16),'paper' if i%2 else 'copper')
    box('FolderTab'+str(i),archive,(-.37+i*.145,1.16,.20),(.075,.07,.018),'dark')
instance('ArchivePapers',archive,(.05,.67,.22),'res://scenes/environment/props/paper_stack.tscn',scale=(.5,.5,.5))
recorder='Shared/RecorderStand'
box('TapeDeckBack',recorder,(0,.63,-.05),(1.12,.75,.40),'dark')
for side in [-1,1]:
    cylinder('ReelHub'+str(side),recorder,(side*.27,.60,.45),.055,.07,'paper',(90,0,0))
line('TapeSpan',recorder,(-.25,.45),(.25,.45),.026,'black',.55,.026)
box('RecordLamp',recorder,(.44,.87,.18),(.08,.08,.05),'red')
box('CellHandle',recorder,(0,.19,.49),(.20,.055,.08),'copper')
export=box('ExportButton',recorder,(-.42,.90,.18),(.20,.15,.10),'green')
label('ExportStamp',export,(0,0,.065),'EXPORT',20,'172a30',False)
label('RecorderPlaque',recorder,(0,.33,.47),'23:44',26,'d9af59',False)
for i in range(12):
    row,col=divmod(i,3)
    box('Key'+str(i),'Shared/KeypadStand',(-.22+col*.22,.70,.30-row*.13),(.15,.07,.08),'paper')
box('CodeDisplay','Shared/KeypadStand',(0,.83,-.19),(.78,.18,.10),'cyan')
box('AnchorLever','Shared/AnchorStand',(0,.98,.22),(.15,.46,.15),'copper',rotation=(-28,0,0))
torus('ReleaseWheel','Shared/ReleaseStand',(0,1.12,.16),.30,.36,'red')
for a in [0,60,120]:
    box('WheelSpoke'+str(a),'Shared/ReleaseStand',(0,1.12,.16),(.61,.045,.06),'copper',rotation=(0,0,a))

# A recognisable machine at the destination rather than an empty final cubicle.
node('CoreMachine',parent='Shared')
box('Plinth','Shared/CoreMachine',(0,.15,-13.7),(3.3,.30,.85),'edge',True)
torus('AnchorRing','Shared/CoreMachine',(0,1.75,-13.65),1.06,1.23,'copper')
torus('AnchorLight','Shared/CoreMachine',(0,1.75,-13.61),.94,1.0,'cyan')
for side in [-1,1]:
    box('AnchorPylon'+str(side),'Shared/CoreMachine',(side*1.4,1.15,-13.6),(.38,2.30,.48),'steel')
    box('PylonCurrent'+str(side),'Shared/CoreMachine',(side*1.4,1.2,-13.32),(.10,1.8,.04),'off')
cylinder('SuspendedCore','Shared/CoreMachine',(0,1.75,-13.65),.35,.70,'cyan',(0,0,90))
box('AuditStand','Shared',(2.4,.50,-12.9),(1,.99,.65),'steel',True)
box('AuditScreen','Shared',(2.4,1.18,-12.95),(.86,.55,.12),'cyan')

# Workshop life in the Past, material decay in the same corners 31 years later.
for side in [-1,1]:
    instance('ToolCrate'+str(side),'PastOnly',(side*7.0,0,8.15),'res://scenes/environment/props/crate.tscn',scale=(.75,.75,.75))
    instance('CableReel'+str(side),'Shared',(side*7.15,0,5.0),'res://scenes/environment/props/cable_reel.tscn',yaw=side*65)
    instance('StorageRack'+str(side),'Shared',(side*7.1,0,-8.0),'res://scenes/environment/props/signal_rack.tscn',scale=(.65,.65,.65),yaw=side*-90)
    for i in range(3):
        box('FallenPanel'+str(side)+str(i),'FutureOnly',(side*(6.9-i*.21),.06+i*.045,8.0-i*.31),(.8,.09,.65),'rust',rotation=(0,i*23,0))
    # Leaks stain the wall and spread into the edge trench, away from puzzle approaches.
    for z in [5.2,-5.0]:
        for i in range(4):
            box('Leak'+str(side)+str(z)+str(i),'FutureOnly',(side*7.98,1.2-i*.16,z+i*.12),(.025,1.1+i*.23,.08),'rust')
        cylinder('OilStain'+str(side)+str(z),'FutureOnly',(side*6.9,.018,z+.6),.49,.018,'dark')
    for z in [6.8,-6.8]:
        box('SafetyBoard'+str(side)+str(z),'PastOnly',(side*7.96,1.5,z),(.025,.85,.62),'blue')
        box('FadedBoard'+str(side)+str(z),'FutureOnly',(side*7.96,1.5,z),(.025,.85,.62),'rust')
    for z in [7.1,4.1,-4.9,-7.1]:
        line('Crack'+str(side)+str(z),'FutureOnly',(side*6.5,z),(side*5.9,z-.45),.024,'black')
        line('CrackBranch'+str(side)+str(z),'FutureOnly',(side*6.15,z-.27),(side*6.35,z-.62),.018,'black')
floor_text('FailureTime','FutureOnly',(0,.03,-3.3),'23:44 / CONTAINMENT LOST',48,'d9af59')

# The final bulkhead reads as a secure machinery entrance, with tracks and a public route diagram.
for side in [-1,1]:
    box('GateJamb'+str(side),'Shared',(side*1.89,1.48,-9.43),(.22,2.96,.32),'edge')
    box('GateGuide'+str(side),'Shared',(side*1.72,1.47,-9.24),(.055,2.62,.04),'copper')
    box('GateSignal'+str(side),'Shared',(side*1.91,2.0,-9.22),(.11,.68,.045),'off')
box('GateLintel','Shared',(0,3.0,-9.43),(4.0,.25,.34),'edge')
hazard('CoreThreshold','Shared',0,-9.45,3.4)
for variant in ['PastOnly','FutureOnly']:
    gate=variant+'/CoreGate'
    box('DoorInset',gate,(0,0,.17),(2.9,2.35,.025),'edge')
    box('DoorSeam',gate,(0,0,.19),(.045,2.34,.025),'copper')
    for side in [-1,1]:
        box('Latch'+str(side),gate,(side*.22,-.1,.21),(.12,.58,.12),'steel')
        for y in [-.7,-.3]:box('Vent'+str(side)+str(y),gate,(side*.85,y,.20),(.65,.04,.02),'steel')

board=box('FacilityDiagram','Shared',(-5.25,1.73,-9.43),(2.8,1.75,.08),'edge')
box('DiagramFace',board,(0,0,.06),(2.60,1.55,.025),'paper')
label('DiagramTitle',board,(0,.54,.09),'SERVICE ROUTE',44,'293c42',False)
for i,(text,y) in enumerate([('POWER',.16),('STORAGE',-.17),('CORE',-.50)]):
    box('DiagramBay'+str(i),board,(-.70,y,.09),(.28,.22,.025),'blue')
    if i<2:box('DiagramLine'+str(i),board,(-.70,y-.17,.10),(.04,.14,.025),'edge')
    label('DiagramText'+str(i),board,(.30,y,.11),text,35,'293c42',False)

# A stopped clock and its fallen glass make the failure tangible rather than only a HUD line.
for variant,minute in [('PastOnly',43),('FutureOnly',44)]:
    clock=node('StoppedClock',parent=variant,position=(5.2,2.15,-9.38))
    cylinder('Rim',clock,(0,0,0),.58,.12,'copper',(90,0,0))
    cylinder('Dial',clock,(0,0,.075),.51,.025,'paper',(90,0,0))
    for i in range(12):
        angle=i*pi/6
        box('Tick'+str(i),clock,(sin(angle)*.43,cos(angle)*.43,.10),(.035,.09,.015),'dark',rotation=(0,0,-i*30))
    for name,length,angle in [('Hour',.29,352),('Minute',.42,minute*6)]:
        pivot=node(name+'Pivot',parent=clock,rotation_degrees=(0,0,-angle))
        box('Hand',pivot,(0,length/2,.13),(.045,length,.022),'dark')
    cylinder('Pin',clock,(0,0,.16),.065,.035,'red',(90,0,0))
    label('ClockCaption',variant,(5.2,1.24,-9.30),'SERVICE TIME' if variant=='PastOnly' else 'STOPPED / 23:44',36,'d9af59',False)
for i in range(3):
    box('ClockGlass'+str(i),'FutureOnly',(5.0+i*.27,.025,-8.9),(.24,.018,.15),'blue',rotation=(0,i*31,0))
text='[gd_scene format=3]\n\n'+'\n\n'.join(exts)+'\n\n'+'\n'.join(resources)+'\n'+'\n'.join(nodes)
path=ROOT/'scenes/environment/rooms/maintenance_layout.tscn';path.write_text(text)
print('Authored',path,'with',len(nodes),'nodes')
