"""Conform the student's sewn trim and face to their actual supporting meshes."""
import numpy as np
from fit_professor_clothes import make_attacher, fit_authored_clothing, Surface
from fit_professor_face import fit_authored_face, ring_depth


def fit_clothing(parts):
    report=[]
    select,attach=make_attacher(parts,report)
    jacket=select('Jacket / continuous open shell')
    shirt=select('Shirt / continuous cream henley')
    neck=select('Skin / neck')
    attach(select('Shirt / open henley collar'),shirt+neck,'patch',high=.004)
    attach(select('Shirt / henley placket'),shirt,'ribbon',high=.002)
    attach(select('Shirt / small ivory button'),select('Shirt / henley placket')+shirt,'oval',high=.003,sides=12)
    # Wrap the standing collar around the actual neck, retaining its fold.
    n=neck[0]['vertices'];profiles=[]
    for y in np.unique(np.round(n[:,1],6)):
        row=n[abs(n[:,1]-y)<1e-5]
        profiles.append((y,np.ptp(row[:,0])/2,np.ptp(row[:,2])/2,(row[:,2].max()+row[:,2].min())/2))
    profiles=np.asarray(profiles)
    for part in select('Jacket / standing collar'):
        v=part['vertices'];rx=np.interp(v[:,1],profiles[:,0],profiles[:,1]);rz=np.interp(v[:,1],profiles[:,0],profiles[:,2])
        cz=np.interp(v[:,1],profiles[:,0],profiles[:,3])
        radial=np.maximum((abs(v[:,0]/rx)**2.5+abs((v[:,2]-cz)/rz)**2.5)**.4,1e-8)
        x=v[:,0]/radial;z=(v[:,2]-cz)/radial
        direction=np.column_stack([x,z]);direction/=np.linalg.norm(direction,axis=1,keepdims=True)
        offsets=np.r_[np.tile([.001,.006,.006,.001],(len(v)-2)//4),[.0035,.0035]]
        v[:,0]=x+direction[:,0]*offsets;v[:,2]=cz+z+direction[:,1]*offsets
        report.append({'name':part['name'],'support':['Skin / neck']})
    attach(select('Jacket / front placket'),jacket,'ribbon',low=.0015,high=.008)
    plackets=select('Jacket / front placket')
    attach(select('Jacket / placket stitch'),plackets+jacket,'tube',high=.001,sides=10)
    attach(select('Jacket / slant welt pocket'),jacket,'ribbon',high=.005)
    attach(select('Jacket / welt pocket opening'),select('Jacket / slant welt pocket')+jacket,'tube',high=.0015,sides=10)
    attach(select('Jacket / four horn buttons'),plackets+jacket,'oval',high=.006,sides=16)
    attach(select('Button holes'),select('Jacket / four horn buttons'),'oval',high=.0006,sides=8)
    attach(select('Jacket / right breast pocket'),jacket,'box',high=.005)
    pocket=select('Jacket / right breast pocket')
    attach(select('Jacket / pocket face'),pocket,'box',high=.003)
    attach(select('Jacket / pointed breast flap'),pocket+select('Jacket / pocket face')+jacket,'patch',high=.005)
    attach(select('Jacket / breast snap'),select('Jacket / pointed breast flap'),'oval',high=.005,sides=16)
    attach(select('Jacket / back shoulder seam'),jacket,'tube',high=.001,sides=10,side=-1)
    for side,sign in [('l',1),('r',-1)]:
        seams=[p for p in select('Jacket / side seam') if np.mean(p['vertices'][:,0])*sign>0]
        attach(seams,jacket,'tube',high=.001,sides=10,axis=0,side=sign)
        attach(select('Trousers / outer seam '+side),select('Trousers / leg '+side),'tube',high=.001,sides=10,axis=0,side=sign)
        boot=select('Boot / leather toe and shaft '+side)
        attach(select('Boot / tongue '+side),boot,'patch',high=.003)
        attach(select('Boot / crossed lace '+side,'Boot / return lace '+side),select('Boot / tongue '+side)+boot,'tube',high=.007,sides=10)
    attach(select('Boot / eyelet'),select('Boot / leather toe and shaft','Boot / tongue'),'oval',high=.004,sides=12)
    attach(select('Boot / heel seam'),select('Boot / leather toe and shaft'),'tube',high=.001,sides=10,side=-1)
    sleeve=select('Jacket sleeve / l')
    attach(select('Jacket / left sleeve pocket'),sleeve,'box',high=.005,axis=1)
    attach(select('Jacket / sleeve flap'),select('Jacket / left sleeve pocket')+sleeve,'box',high=.004,axis=1)
    attach(select('Jacket / sleeve pocket snap'),select('Jacket / sleeve flap'),'oval',high=.004,sides=16,axis=1)
    attach(select('ID / jacket mount'),jacket,'box',high=.004)
    attach(select('ID / card'),select('ID / jacket mount'),'box',high=.003)
    card=select('ID / card')
    attach(select('ID / blue header','ID / photo background','ID / printed line'),card,'box',high=.0009)
    attach(select('ID / metal clip'),select('ID / jacket mount')+card+jacket,'box',high=.004)
    attach(select('ID / portrait head'),select('ID / photo background')+card,'oval',high=.001,sides=12)
    attach(select('ID / portrait shirt'),select('ID / photo background')+card,'box',high=.001)
    # Keep the strap's hip connectors and shoulder bridge in their existing
    # 3D paths; seat only its torso sections against the jacket.
    bones=sorted({name for p in parts for w in p['weights'] for name in w}|{'chest'})
    for side,label in [(1,'front'),(-1,'back')]:
        support=jacket
        surface=Surface(support,bones,side=side,max_distance=.15)
        for part in select('Leather / diagonal '+label+' shoulder strap','Leather / strap saddle stitch'):
            v=part['vertices']
            mask=(v[:,2]*side>0)&(abs(v[:,0])<.30)&(v[:,1]>.75)&(v[:,1]<1.20)
            if not np.any(mask):continue
            depth,weights=surface.sample(v[mask])
            if 'saddle stitch' in part['name']:
                rows=v[:-2].reshape(-1,8,3)
                rx=np.ptp(rows[:,:,0],axis=1)/2
                relief=ring_depth(v,8,rx*.75,.018)[mask]
            else:
                n=(len(v)-2)//4
                relief=np.r_[np.tile([.004,.017,.017,.004],n),[.0105,.0105]][mask]
            v[mask,2]=side*(depth+relief)
            for index,w in zip(np.flatnonzero(mask),weights):
                ids=np.argsort(w)[-4:];total=w[ids].sum()
                part['weights'][index]={bones[i]:float(w[i]/total) for i in ids if w[i]>1e-8}
            report.append({'name':part['name'],'support':[p['name'] for p in support]})
    attach(select('Strap / adjustment stud'),select('Leather / diagonal front shoulder strap'),'oval',high=.004,sides=16)
    return report


def fit_authored_details(character):
    face=fit_authored_face(character)
    clothing=fit_authored_clothing(character,fit=fit_clothing,include=lambda name:True)
    return face,clothing
