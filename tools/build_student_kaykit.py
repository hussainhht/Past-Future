"""Original reference-led student, fully procedural editable mesh authoring source.
Run with .venv/Scripts/python.exe tools/build_student_kaykit.py.
Coordinates: Y up, +Z face, +X anatomical left. All dimensions are model units.
"""
import math
import numpy as np
import student_mesh as mesh
from student_mesh import MeshAuthor, normalize, smooth

mesh.PALETTE.clear()
mesh.PALETTE.update({
    'jacket':'b98b43', 'jacket_light':'c29852', 'jacket_dark':'a77838',
    'jacket_seam':'9d7339', 'shirt':'e7dcc0', 'shirt_shadow':'c9bba0',
    'skin':'d29a71', 'skin_shadow':'b87954', 'mouth':'8b523b',
    'hair':'302e30', 'hair_mid':'383639', 'hair_light':'403e40',
    'pants':'303b46', 'pants_seam':'3b4650', 'boots':'70442c',
    'boot_trim':'875638', 'sole':'392a24', 'laces':'514031',
    'bag':'80573e', 'bag_trim':'94684a', 'stitch':'b99168',
    'brass':'ad8d5d', 'steel':'777875', 'eyes':'42271c',
    'eye_glint':'ad8264', 'badge':'e8dfc9', 'badge_blue':'638a96',
    'badge_ink':'3c4652', 'watch':'b4b1a3', 'watch_face':'d8d3bd',
})


def curve(points, steps=5):
    """Centrally interpolated sculpting control points (Catmull-Rom)."""
    p=np.asarray(points,dtype=float); result=[]
    for i in range(len(p)-1):
        a,b,c,d=p[max(0,i-1)],p[i],p[i+1],p[min(len(p)-1,i+2)]
        for t in np.linspace(0,1,steps,endpoint=False):
            result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return np.array(result+[p[-1]])

HAIR_Y=[1.36,1.48,1.65,1.85,2.0,2.10,2.18,2.23]
HAIR_X=[.19,.31,.369,.399,.37,.30,.19,.002]
HAIR_Z=[.20,.28,.325,.33,.32,.26,.17,.002]

class Student(MeshAuthor):
    def body_weights(self,p):
        upper=smooth(.75,1.10,p[1]); lower=1-smooth(.52,.72,p[1])
        return {'hips':lower,'spine':(1-lower)*(1-upper),'chest':(1-lower)*upper}

    def arm_weights(self,side):
        def weights(p):
            x=abs(p[0]); elbow=smooth(.47,.61,x); wrist=smooth(.745,.82,x); hand=smooth(.82,.88,x)
            # A short blended shoulder band avoids a detached sleeve during raises.
            shoulder=1-smooth(.235,.34,x)
            return {'chest':shoulder,'upperarm.'+side:(1-shoulder)*(1-elbow),
                    'lowerarm.'+side:(1-shoulder)*elbow*(1-wrist),
                    'wrist.'+side:wrist*(1-hand),'hand.'+side:hand}
        return weights

    def leg_weights(self,side):
        def weights(p):
            knee=1-smooth(.265,.365,p[1]); ankle=1-smooth(.16,.23,p[1])
            return {'upperleg.'+side:1-knee,'lowerleg.'+side:knee*(1-ankle),'foot.'+side:knee*ankle}
        return weights

    def loft(self,name,sections,color,weights,segments=32,power=2.5,axis='y'):
        sections=curve(sections,3)
        sections[:,1:3]=np.maximum(sections[:,1:3],.00015)
        super().loft(name,sections,color,weights,segments,power,axis)

    def tube(self,name,path,radius,color,weights,normal=(0,0,1),sides=10):
        pts=curve(path,5); rings=[]
        for i,p in enumerate(pts):
            tangent=normalize(pts[min(len(pts)-1,i+1)]-pts[max(0,i-1)])
            across=normalize(np.cross(tangent,normal)); out=normalize(np.cross(across,tangent))
            rings.append([p+radius*(across*math.sin(a)+out*math.cos(a)) for a in np.linspace(0,math.tau,sides,endpoint=False)])
        self.rings(name,rings,color,weights)

    def leaf(self,name,path,width,depth,color,normal=(0,0,1)):
        pts=curve(path,7); rings=[]
        raised_quiff=any(label in name for label in ('high quiff','crown wave'))
        def seat(point):
            p=np.array(point,dtype=float)
            if not raised_quiff and p[1] < 2.215:
                y=p[1]
                rx=np.interp(y,HAIR_Y,HAIR_X)
                rz=np.interp(y,HAIR_Y,HAIR_Z)
                radial=np.array([p[0],p[2]+.035])
                scale=1/max(np.linalg.norm(radial/[rx,rz]),1e-5)
                p[0]=radial[0]*scale
                p[2]=radial[1]*scale-.035
            return p
        pts=np.array([seat(p) for p in pts])
        for i,p in enumerate(pts):
            t=i/(len(pts)-1); taper=max(.006,math.sin(math.pi*t)**.65)*(1-.38*t)
            tangent=normalize(pts[min(len(pts)-1,i+1)]-pts[max(0,i-1)])
            normal=normalize([p[0]/.40**2,(p[1]-1.72)/.51**2,(p[2]+.035)/.34**2])
            across=normalize(np.cross(tangent,normal))
            ring=[]
            for a in np.linspace(0,math.tau,16,endpoint=False):
                q=seat(p+across*math.sin(a)*width*taper)
                outward=normalize([q[0]/.40**2,(q[1]-1.72)/.51**2,(q[2]+.035)/.34**2])
                ring.append(q+outward*math.cos(a)*depth*taper)
            rings.append(ring)
        self.rings(name,rings,color,self.rigid('head'))

    def ribbon(self,name,path,width,thickness,color,weights):
        super().ribbon(name,curve(path,4),width,thickness,color,weights)

    def jacket(self):
        body=self.body_weights
        sections=curve([(.565,.275,.18,0,0),(.59,.302,.196,0,0),(.70,.31,.205,0,0),
                        (.88,.31,.208,0,-.008),(1.08,.325,.195,0,-.012),(1.19,.278,.165,0,-.012),
                        (1.235,.14,.108,0,0)],4)
        count=65; vertices=[]; faces=[]
        for y,rx,rz,cx,cz in sections:
            for a in np.linspace(.19,math.tau-.19,count):
                sx,sz=math.sin(a),math.cos(a)
                vertices.append([rx*math.copysign(abs(sx)**(2/2.9),sx),y,cz+rz*math.copysign(abs(sz)**(2/2.9),sz)])
        for row in range(len(sections)-1):
            for j in range(count-1):
                a=row*count+j;b=a+1;c=b+count;d=a+count
                faces.extend([(a,b,c),(a,c,d)])
        self.add('Jacket / continuous open shell',vertices,faces,'jacket',body)
        # The bottom welt follows the actual shell; front plackets close its edges.
        path=[]
        for a in np.linspace(.20,math.tau-.20,70):
            path.append([.296*math.copysign(abs(math.sin(a))**(2/2.9),math.sin(a)),.582,
                         .197*math.copysign(abs(math.cos(a))**(2/2.9),math.cos(a))])
        self.tube('Jacket / rounded bottom welt',path,.025,'jacket_dark',body)
        for s in [-1,1]:
            self.ribbon('Jacket / front placket',[(s*.085,.59,.199),(s*.09,.75,.215),(s*.10,.98,.210),
                          (s*.105,1.14,.166)],.042,.023,'jacket_light',body)
            self.tube('Jacket / placket stitch',[(s*.108,.60,.215),(s*.113,.8,.230),(s*.119,1.02,.220)],.0025,'jacket_seam',body)
            self.ribbon('Jacket / slant welt pocket',[(s*.245,.685,.196),(s*.235,.75,.217),(s*.202,.815,.231)],.033,.018,'jacket_light',body)
            self.tube('Jacket / welt pocket opening',[(s*.231,.683,.214),(s*.213,.750,.230),(s*.19,.80,.234)],.004,'jacket_dark',body)
        for y in [.607,.735,.865,1.003]:
            self.oval('Jacket / four horn buttons',(-.097,y,.239),(.018,.022,.011),'bag_trim',body,16,8)
            for x in [-.101,-.093]: self.oval('Button holes',(x,y,.250),(.0016,.003,.001),'jacket_dark',body,8,4)
        # One chest patch pocket, on anatomical right. The opposite side holds ID.
        self.box('Jacket / right breast pocket',(-.209,1.01,.198),(.144,.157,.035),'jacket_dark',body,.022)
        self.box('Jacket / pocket face',(-.209,1.011,.218),(.128,.142,.024),'jacket',body,.018)
        self.patch('Jacket / pointed breast flap',[(-.282,1.085,.229),(-.137,1.085,.229),(-.145,1.025,.249),(-.207,1.008,.254),(-.272,1.027,.249)],.012,'jacket_light',body)
        self.oval('Jacket / breast snap',(-.207,1.044,.269),(.016,.016,.008),'bag_trim',body,16,8)
        self.tube('Jacket / back shoulder seam',[(-.29,1.153,-.12),(-.21,1.16,-.173),(0,1.16,-.185),(.21,1.16,-.173),(.29,1.153,-.12)],.003,'jacket_dark',body)
        for s in [-1,1]:
            self.tube('Jacket / side seam',[(s*.30,.62,-.035),(s*.313,.85,-.035),(s*.317,1.06,-.035)],.0028,'jacket_dark',body,normal=(1,0,0))

    def hair(self):
        head=self.rigid('head'); rings=[]
        for t in np.linspace(0,1,23):
            ring=[]
            for a in np.linspace(0,math.tau,64,endpoint=False):
                front=max(0,math.cos(a)); low=1.36+.59*front**2
                y=low+(2.23-low)*t
                rx=np.interp(y,HAIR_Y,HAIR_X)
                rz=np.interp(y,HAIR_Y,HAIR_Z)
                ring.append([rx*math.sin(a),y,-.035+rz*math.cos(a)])
            rings.append(ring)
        self.rings('Hair / sculpted underlying skull',rings,'hair',head)
        # Broad flattened swept locks, with sharp ends; deliberately not tubes.
        for name,path,w,d,c in [
            ('forelock',[(-.20,2.04,.18),(-.06,2.08,.30),(.055,1.99,.343),(.09,1.86,.325)],.115,.040,'hair_mid'),
            ('center sweep',[(-.22,2.08,.12),(-.02,2.13,.20),(.20,2.01,.286),(.32,1.91,.24)],.135,.045,'hair'),
            ('left wave',[(-.11,2.15,.05),(.11,2.14,.12),(.30,2.065,.17),(.405,2.055,.12)],.115,.044,'hair_mid'),
            ('outer wave',[(.10,2.10,.07),(.30,2.02,.14),(.39,1.94,.16),(.43,1.94,.12)],.105,.039,'hair'),
            ('right fringe',[(-.16,2.04,.23),(-.28,1.98,.29),(-.35,1.85,.26),(-.355,1.77,.22)],.078,.037,'hair_mid'),
            ('right fringe overlap',[(-.24,2.06,.16),(-.35,1.98,.20),(-.405,1.87,.15),(-.399,1.83,.10)],.082,.035,'hair'),
            ('high quiff',[(-.25,2.03,-.03),(-.255,2.14,.02),(-.195,2.21,.015),(-.11,2.245,-.025)],.072,.035,'hair_mid'),
            ('crown wave',[(-.24,2.12,-.11),(-.08,2.18,-.09),(.12,2.16,-.10),(.24,2.20,-.14)],.105,.04,'hair_mid'),
            ('temple left',[(.24,2.035,.235),(.34,1.90,.24),(.365,1.76,.16),(.33,1.65,.14)],.07,.036,'hair'),
            ('temple right',[(-.30,1.99,.21),(-.35,1.86,.23),(-.37,1.72,.16),(-.34,1.63,.13)],.055,.03,'hair'),
        ]: self.leaf('Hair / '+name,path,w,d,c)
        # Side and rear overlapping tiers establish the layered nape in all views.
        for side in [-1,1]:
            for index in range(3):
                y=2.17-index*.115; z=.15-index*.035
                self.leaf('Hair / swept temple layer',[(side*.23,y,z),(side*.35,y-.07,z-.08),
                          (side*.39,y-.18,z-.22),(side*.34,y-.16,z-.32)],.105,.039,
                          'hair_mid' if index==1 else 'hair',normal=(side,0,0))
            for index,z in enumerate([-.08,-.19]):
                self.leaf('Hair / side nape',[(side*.345,1.80,z),(side*.35,1.64,z-.015),
                          (side*.285,1.43,z+.005),(side*.245,1.36,z+.035)],.066,.027,'hair',normal=(side,0,-.1))
        for row in range(2):
            for col in range(7):
                x=(col-3)*.100 + (.025 if row%2 else 0)
                y=2.15-row*.27 - abs(x)*.20 +.024*math.sin(col*2+row)
                z=-.13-row*.11- .08*(1-abs(x)/.35)
                bend=.04*math.sin(col+row*2)
                self.leaf('Hair / rear layered lock',[(x-.055,y,z),(x+bend,y-.10,z-.07),
                          (x+bend+.03,y-.32,z-.07),(x+.015,max(1.35,y-(.50 if row else .43)-.025*math.cos(col*2)),z-.045)],.115-.02*row,.034,
                          ['hair_mid','hair','hair','hair_mid','hair','hair','hair_mid'][col],normal=(0,0,-1))

    def face(self):
        head=self.rigid('head')
        self.loft('Skin / neck',[(1.19,.11,.096,0,0),(1.35,.12,.11,0,.015)],'skin',head)
        face_start=len(self.geometry['skin']['vertices'])
        self.loft('Skin / rounded jaw cheeks forehead',[
            (1.265,.065,.07,0,.02),(1.295,.19,.155,0,.025),(1.35,.28,.231,0,.028),
            (1.47,.333,.282,0,.018),(1.53,.345,.296,0,.015),(1.57,.352,.301,0,.012),
            (1.60,.354,.303,0,.01),(1.64,.356,.306,0,.008),(1.69,.358,.309,0,.004),(1.76,.357,.31,0,0),
            (1.89,.336,.30,0,-.008),(1.985,.28,.25,0,-.02),(2.04,.12,.12,0,-.03)
        ],'skin',head,192,power=2.35)
        for p in self.geometry['skin']['vertices'][face_start:]:
            if p[2]>.20:
                p[2] += .060*math.exp(-.5*((p[0]/.050)**2+((p[1]-1.585)/.036)**2))
                p[2] += .013*math.exp(-.5*((p[0]/.028)**2+((p[1]-1.63)/.06)**2))
        for s in [-1,1]:
            self.oval('Skin / outer ear',(s*.363,1.585,-.008),(.065,.096,.052),'skin',head,24,12)
            self.oval('Skin / ear concha',(s*.384,1.59,.031),(.032,.059,.022),'skin_shadow',head,24,12)
            self.oval('Skin / inner ear',(s*.388,1.575,.042),(.018,.031,.018),'skin',head,20,10)
            self.oval('Face / brown oval eye',(s*.153,1.65,.303),(.037,.055,.022),'eyes',head,28,14)
            self.oval('Face / subtle eye catchlight',(s*.153-.009,1.672,.324),(.004,.006,.002),'eye_glint',head,12,6)
            self.leaf_brow(s,head)
        self.tube('Face / closed mouth',[(-.04,1.476,.307),(-.014,1.473,.312),(.015,1.474,.312),(.043,1.481,.307)],.003,'mouth',head)
        self.hair()

    def leaf_brow(self,s,head):
        pts=curve([(s*.075,1.80,.318),(s*.13,1.815,.314),(s*.195,1.811,.304),(s*.241,1.794,.289)],6)
        pts[:,1]-=.045
        pts[:,2]+=.006
        rings=[]
        for i,p in enumerate(pts):
            t=i/(len(pts)-1); r=.023*(.40+.60*math.sin(math.pi*t)**.35)
            rings.append([p+np.array([0,math.sin(a)*r,math.cos(a)*.014]) for a in np.linspace(0,math.tau,14,endpoint=False)])
        self.rings('Face / thick sculpted brow',rings,'hair',head)

    def limbs(self):
        for s,side in [(1,'l'),(-1,'r')]:
            arm=self.arm_weights(side); leg=self.leg_weights(side); foot=self.rigid('foot.'+side)
            def armloft(name,sections,col):
                specs=[(s*x,rz,ry,z,1.16) for x,ry,rz,z in sections]
                if s<0: specs.reverse()
                self.loft(name+' / '+side,specs,col,arm,32,power=2.2,axis='x')
            armloft('Jacket sleeve',[(.195,.12,.115,0),(.29,.142,.132,0),(.38,.131,.123,0),(.47,.114,.107,0),(.58,.108,.103,0),(.70,.10,.10,0)],'jacket')
            armloft('Sleeve fold',[(.57,.106,.105,0),(.605,.109,.108,0),(.65,.105,.103,0)],'jacket')
            armloft('Rolled cloth cuff',[(.665,.105,.103,0),(.68,.125,.122,0),(.72,.126,.121,0),(.75,.109,.106,0)],'jacket_light')
            armloft('Cuff fold edge',[(.724,.125,.122,0),(.74,.121,.12,0),(.752,.11,.106,0)],'jacket')
            armloft('Skin / continuous forearm and palm',[(.70,.081,.08,0),(.74,.077,.073,0),(.79,.070,.066,0),(.85,.069,.065,0),
                    (.90,.077,.075,.007),(.95,.076,.075,.011),(.985,.061,.063,.018),(1.005,.038,.041,.023)],'skin')
            # Palm and four attached fingers form a hand rather than a single mitten.
            for i in range(4):
                y=1.16+(i-1.5)*.030
                length=[.052,.068,.072,.060][i]
                self.oval('Hand / finger '+side,(s*(.977+length*.25),y,.036),(.033+length*.25,.022,.041),'skin',arm,20,10)
            self.oval('Hand / thumb base '+side,(s*.877,1.105,.044),(.052,.034,.039),'skin',arm,24,10)
            self.oval('Hand / thumb tip '+side,(s*.909,1.09,.056),(.034,.022,.026),'skin',arm,20,10)
            if side=='l':
                armloft('Watch / leather wrist strap',[(.774,.067,.064,0),(.812,.067,.064,0)],'boots')
                # Watch is on the outer wrist (+Y in bind), face points outward.
                self.oval('Watch / round bezel',(s*.794,1.232,0),(.047,.014,.047),'watch',arm,32,12)
                self.oval('Watch / ivory dial',(s*.794,1.246,0),(.035,.004,.035),'watch_face',arm,32,8)
                for i in range(12):
                    a=i*math.tau/12
                    self.oval('Watch / hour marker',(.794+.029*math.sin(a),1.250,.029*math.cos(a)),(.002,.001,.002),'steel',arm,8,4)
                self.tube('Watch / hour hand',[(.794,1.252,0),(.778,1.252,.011)],.002,'badge_ink',arm,normal=(0,1,0))
                self.tube('Watch / minute hand',[(.794,1.252,0),(.795,1.252,-.024)],.0015,'badge_ink',arm,normal=(0,1,0))
                # Small utility flap pocket on the left outer upper sleeve.
                self.box('Jacket / left sleeve pocket',(.405,1.285,0),(.15,.025,.117),'jacket_dark',arm,.012)
                self.box('Jacket / sleeve flap',(.377,1.302,0),(.064,.018,.132),'jacket_light',arm,.012)
                self.oval('Jacket / sleeve pocket snap',(.382,1.316,0),(.012,.005,.012),'bag_trim',arm,16,8)
            x=s*.18
            self.loft('Trousers / leg '+side,[(.235,.101,.101,x,-.006),(.28,.112,.113,x,0),(.34,.119,.12,x,.008),(.40,.113,.12,x,.008),(.49,.123,.13,x,0),(.58,.135,.145,x,0),(.62,.132,.144,x,0)],'pants',leg,32,power=2.6)
            self.tube('Trousers / outer seam '+side,[(x+s*.104,.27,0),(x+s*.12,.36,0),(x+s*.122,.5,0)],.0025,'pants_seam',leg,normal=(1,0,0))
            self.loft('Boot / thick outsole '+side,[(.016,.112,.172,x,.05),(.027,.138,.197,x,.05),(.068,.138,.197,x,.05),(.08,.131,.192,x,.05)],'sole',foot,40,power=3.1)
            self.loft('Boot / leather toe and shaft '+side,[(.074,.128,.186,x,.051),(.11,.13,.186,x,.052),(.155,.12,.173,x,.042),(.19,.109,.134,x,.019),(.245,.108,.107,x,-.012),(.285,.112,.11,x,-.014)],'boots',foot,40,power=2.8)
            self.loft('Boot / top rolled rim '+side,[(.273,.111,.11,x,-.014),(.286,.116,.114,x,-.014),(.295,.112,.109,x,-.014)],'boot_trim',foot,32)
            self.patch('Boot / tongue '+side,[(x-.051,.285,.091),(x+.051,.285,.091),(x+.054,.145,.178),(x-.054,.145,.178)],.008,'boot_trim',foot)
            for i in range(3):
                y=.254-i*.039; z=.119+i*.025
                self.tube('Boot / crossed lace '+side,[(x-.057,y,z),(x,y-.018,z+.013),(x+.052,y-.03,z+.021)],.006,'laces',foot)
                self.tube('Boot / return lace '+side,[(x+.057,y,z),(x,y-.013,z+.02),(x-.052,y-.03,z+.021)],.006,'laces',foot)
                for ss in [-1,1]: self.oval('Boot / eyelet',(x+ss*.058,y,z),(.009,.009,.005),'brass',foot,12,6)
            self.tube('Boot / heel seam',[(x,.10,-.134),(x,.20,-.124),(x,.276,-.122)],.0025,'boot_trim',foot,normal=(0,0,-1))

    def accessories(self):
        body=self.body_weights; hips=self.rigid('hips')
        starts={color:len(g['vertices']) for color,g in self.geometry.items()}
        # Bag shares pelvis motion, front and rear straps blend into hips at joins.
        self.box('Satchel / rounded leather body',(.387,.534,-.025),(.238,.341,.237),'bag',hips,.038)
        self.box('Satchel / front panel',(.388,.51,.105),(.207,.255,.025),'bag_trim',hips,.025)
        self.box('Satchel / flap',(.387,.652,.118),(.246,.133,.028),'bag',hips,.024)
        self.tube('Satchel / flap piped edge',[(.274,.683,.138),(.277,.613,.145),(.311,.596,.147),(.466,.596,.147),(.498,.62,.135)],.004,'bag_trim',hips)
        for x in [.305,.469]:
            self.ribbon('Satchel / fastening tab',[(x,.63,.151),(x,.552,.15),(x,.493,.142)],.025,.013,'boots',hips)
            self.box('Satchel / buckle frame',(x,.542,.165),(.047,.058,.012),'steel',hips,.008)
            self.box('Satchel / buckle opening',(x,.542,.173),(.029,.037,.006),'boots',hips,.004)
            self.tube('Satchel / buckle prong',[(x,.559,.179),(x,.534,.181)],.003,'steel',hips)
            self.oval('Satchel / flap rivet',(x,.618,.157),(.009,.009,.004),'brass',hips,12,6)
        # The bag's flap faces outwards at the left hip, as shown by sideview2.
        angle=math.radians(52); c,s=math.cos(angle),math.sin(angle)
        for color,g in self.geometry.items():
            for i in range(starts.get(color,0),len(g['vertices'])):
                x,y,z=g['vertices'][i]; x-=.387; z+=.025
                g['vertices'][i]=[.387+c*x+s*z,y,-.13-s*x+c*z]
        # Strap supported by the same skin weights as the jacket beneath it.
        front=[(-.255,1.221,.095),(-.218,1.165,.18),(-.10,1.05,.241),(.035,.916,.246),(.19,.77,.244),(.32,.668,.201),(.48,.65,-.045)]
        back=[(-.255,1.221,-.095),(-.205,1.15,-.186),(-.07,1.02,-.225),(.09,.858,-.229),(.245,.719,-.202),(.38,.66,-.25)]
        self.ribbon('Leather / diagonal front shoulder strap',front,.073,.020,'bag_trim',body)
        self.ribbon('Leather / diagonal back shoulder strap',back,.073,.020,'bag_trim',body)
        self.ribbon('Leather / shoulder bridge',[(-.255,1.221,.10),(-.259,1.239,.03),(-.259,1.239,-.04),(-.255,1.221,-.10)],.073,.02,'bag_trim',self.rigid('chest'))
        # Small stitches restrained to leather edges; no invented graphics.
        for path in [front,back]:
            pts=curve(path,6)
            for i in range(2,len(pts)-2,2):
                p=pts[i].copy(); p[2]+=.013 if p[2]>0 else -.013
                self.oval('Leather / strap saddle stitch',p,(.002,.004,.002),'stitch',body,8,4)
        self.oval('Strap / adjustment stud',(.219,.752,.263),(.015,.016,.007),'steel',body,16,8)
        # ID has a clip, cream backing, tiny portrait and short abstract print lines.
        self.box('ID / jacket mount',(.202,1.012,.212),(.13,.152,.029),'jacket_dark',body,.012)
        self.box('ID / card',(.202,.982,.242),(.112,.092,.011),'badge',body,.009)
        self.box('ID / blue header',(.202,1.018,.250),(.099,.012,.005),'badge_blue',body,.002)
        self.box('ID / metal clip',(.202,1.047,.25),(.023,.051,.011),'steel',body,.005)
        self.box('ID / photo background',(.176,.982,.251),(.033,.045,.004),'badge_blue',body,.002)
        self.oval('ID / portrait head',(.176,.991,.255),(.009,.011,.002),'skin',body,12,6)
        self.box('ID / portrait shirt',(.176,.971,.255),(.021,.016,.003),'badge_ink',body,.003)
        for y,w in [(.996,.030),(.983,.034),(.966,.02)]: self.box('ID / printed line',(.224,y,.252),(w,.006,.003),'badge_ink',body,.001)

    def create(self):
        body=self.body_weights; hips=self.rigid('hips')
        self.loft('Trousers / pelvis',[(.53,.20,.105,0,0),(.565,.266,.15,0,0),(.62,.276,.168,0,0)],'pants',hips,40,power=3)
        self.loft('Shirt / continuous cream henley',[(.586,.26,.174,0,0),(.75,.273,.19,0,0),(.97,.264,.187,0,0),(1.16,.246,.15,0,0),(1.24,.115,.087,0,0)],'shirt',body,40,power=2.8)
        self.jacket()
        # Raised stand collar wraps the back of the neck and opens at the throat.
        for s in [-1,1]:
            self.ribbon('Jacket / standing collar',[(s*.035,1.193,.135),(s*.11,1.265,.107),(s*.15,1.273,.02),(s*.119,1.26,-.105),(0,1.25,-.12)],.063,.025,'jacket_light',body)
            self.patch('Shirt / open henley collar',[(s*.017,1.14,.188),(s*.087,1.24,.122),(s*.113,1.202,.143),(s*.054,1.105,.193)],.009,'shirt_shadow',body)
        self.ribbon('Shirt / henley placket',[(0,1.14,.187),(0,1.04,.207)],.027,.009,'shirt_shadow',body)
        for y in [1.078,1.118]: self.oval('Shirt / small ivory button',(0,y,.215),(.005,.006,.003),'shirt',body,12,6)
        self.face(); self.limbs(); self.accessories()


if __name__=='__main__':
    student=Student(); student.create(); student.export()
