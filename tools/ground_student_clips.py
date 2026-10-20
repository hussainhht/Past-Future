"""Bake minimal vertical clearance for floor-contact clips after proportion retarget.
Uses actual weighted vertices, not guessed rig bounds. Source GLBs are read-only.
"""
from copy import deepcopy
import numpy as np
from gltf_tools import GLB, Writer, world_matrices

CONTACT_CLIPS={'Death_A','Death_A_Pose','Death_B','Death_B_Pose','Lie_Down','Lie_Idle','Lie_StandUp','Crawling','Push_Ups'}


def sample(times,values,t,path):
    i=max(0,min(len(times)-2,int(np.searchsorted(times,t,side='right')-1)))
    if len(times)==1:return values[0]
    f=float(np.clip((t-times[i])/max(times[i+1]-times[i],1e-8),0,1))
    a,b=values[i].astype(float),values[i+1].astype(float)
    if path=='rotation':
        dot=float(np.dot(a,b))
        if dot<0:b=-b;dot=-dot
        if dot>.9995:
            q=a+(b-a)*f;return q/np.linalg.norm(q)
        angle=np.arccos(np.clip(dot,-1,1))
        return (np.sin((1-f)*angle)*a+np.sin(f*angle)*b)/np.sin(angle)
    return a+(b-a)*f


def bake(path):
    asset=GLB(path);doc=deepcopy(asset.doc);skin=doc['skins'][0]
    positions=[];joints=[];weights=[]
    for p in doc['meshes'][0]['primitives']:
        a=p['attributes'];positions.append(asset.read(a['POSITION']));joints.append(asset.read(a['JOINTS_0']));weights.append(asset.read(a['WEIGHTS_0']))
    positions=np.concatenate(positions);positions=np.column_stack([positions,np.ones(len(positions))]);joints=np.concatenate(joints);weights=np.concatenate(weights)
    inverse=asset.read(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    root=next(i for i,n in enumerate(doc['nodes']) if n['name']=='root')
    writer=Writer();writer.binary=bytearray(asset.binary);writer.accessors=deepcopy(doc['accessors']);writer.views=deepcopy(doc['bufferViews'])
    report={}
    for animation in doc['animations']:
        if animation['name'] not in CONTACT_CLIPS:continue
        tracks=[];duration=0
        for c in animation['channels']:
            s=animation['samplers'][c['sampler']];ts=asset.read(s['input']).ravel();vs=asset.read(s['output'])
            assert s.get('interpolation','LINEAR')=='LINEAR'
            tracks.append((c['target']['node'],c['target']['path'],ts,vs));duration=max(duration,float(ts[-1]))
        # Include endpoint. 60 Hz sampling also bounds interpolation between keys.
        ts=np.linspace(0,duration,max(2,int(np.ceil(duration*60))+1));translations=[];clearances=[]
        for t in ts:
            posed={'nodes':deepcopy(doc['nodes']),'scenes':doc['scenes'],'scene':doc.get('scene',0)}
            for node,kind,times,values in tracks:posed['nodes'][node][kind]=sample(times,values,t,kind).tolist()
            world=world_matrices(posed)
            matrices=np.array([world[j] for j in skin['joints']])@inverse
            ys=np.zeros(len(positions))
            for influence in range(4):
                rows=matrices[joints[:,influence],1,:]
                ys+=np.einsum('ij,ij->i',rows,positions)*weights[:,influence]
            # Leave the model 2 mm above the plane, allowing skin precision error.
            clearance=max(0,.002-float(ys.min()))
            root_position=np.array(posed['nodes'][root].get('translation',[0,0,0]));root_position[1]+=clearance
            translations.append(root_position);clearances.append(clearance)
        channel=next((c for c in animation['channels'] if c['target']=={'node':root,'path':'translation'}),None)
        if channel is None:
            channel={'sampler':len(animation['samplers']),'target':{'node':root,'path':'translation'}}
            animation['channels'].append(channel);animation['samplers'].append({})
        animation['samplers'][channel['sampler']]={'input':writer.add(ts,'SCALAR',bounds=True),'output':writer.add(translations,'VEC3'),'interpolation':'LINEAR'}
        report[animation['name']]={'times':ts.tolist(),'vertical_offsets':clearances,'max_vertical_offset':max(clearances),'method':'60 Hz actual skinned surface floor clearance, minimum Y 0.002'}
    writer.save(path,doc)
    return report
