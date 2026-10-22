"""Prepare user-supplied UAZ GLBs: python3 tools/prepare_uaz_models.py expedition|bukhanka|classic SOURCE OUTPUT [THUMB]. Requires numpy/Pillow. Bakes transforms, splits actual wheel/lens triangles and caps textures at 1K; no runtime conversion."""
import json,struct,numpy as np
from pathlib import Path

def glb(path):
 raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+n]);off=20+n;bl=raw[off+8:];return d,bl

def arr(d,b,i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1',5122:'<i2',5120:'i1'}[a['componentType']];k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];return np.ndarray((a['count'],k),dtype=dt,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(dt).itemsize*k),np.dtype(dt).itemsize)).copy()
def transforms(d):
 out={}
 def visit(i,parent):
  n=d['nodes'][i]
  if 'matrix' in n:m=np.array(n['matrix']).reshape(4,4).T
  else:
   x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4);m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0])
  out[i]=parent@m
  for c in n.get('children',[]):visit(c,out[i])
 for i in d['scenes'][d.get('scene',0)]['nodes']:visit(i,np.eye(4))
 return out

import io,sys,copy
from PIL import Image,ImageDraw

def prepare(kind, source, output, thumb=None):
 d,b=glb(source); xf=transforms(d); chunks=[]; textures={}
 def sample(material, uv):
  m=d.get('materials',[])[material]; p=m.get('pbrMetallicRoughness',{})
  factor=np.array(p.get('baseColorFactor',[1,1,1,1])[:3])
  t=p.get('baseColorTexture')
  if t is None:return np.tile(factor*255,(len(uv),1))
  ti=t['index']
  if ti not in textures:
   im=d['images'][d['textures'][ti]['source']];bv=d['bufferViews'][im['bufferView']]
   textures[ti]=np.array(Image.open(io.BytesIO(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']])).convert('RGB'))
  tex=textures[ti];return tex[(uv[:,1]*tex.shape[0]).astype(int)%tex.shape[0],(uv[:,0]*tex.shape[1]).astype(int)%tex.shape[1]]*factor
 for i,n in enumerate(d['nodes']):
  if 'mesh'not in n:continue
  for p in d['meshes'][n['mesh']]['primitives']:
   if p.get('mode',4)!=4:raise ValueError('Only triangles supported')
   attrs={k:arr(d,b,a) for k,a in p['attributes'].items() if not k.startswith(('JOINTS','WEIGHTS'))}
   attrs['POSITION']=attrs['POSITION']@xf[i][:3,:3].T+xf[i][:3,3]
   if 'NORMAL'in attrs:
    normals=attrs['NORMAL']@np.linalg.inv(xf[i][:3,:3]);attrs['NORMAL']=normals/np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
   if 'TANGENT'in attrs:
    t=attrs['TANGENT'];t[:,:3]=t[:,:3]@xf[i][:3,:3].T;t[:,:3]/=np.maximum(np.linalg.norm(t[:,:3],axis=1,keepdims=True),1e-12)
    if np.linalg.det(xf[i][:3,:3])<0:t[:,3]*=-1
   idx=arr(d,b,p['indices']).ravel().reshape(-1,3) if 'indices'in p else np.arange(len(attrs['POSITION'])).reshape(-1,3)
   if np.linalg.det(xf[i][:3,:3])<0:idx=idx[:,[0,2,1]]
   c=attrs['POSITION'][idx].mean(1); groups=np.full(len(idx),'Body',dtype='<U12')
   wheel=i in ([3,4,5,6] if kind=='expedition' else [61] if kind=='bukhanka' else [34])
   splitx=-.7685 if kind=='bukhanka' else .0805 if kind=='expedition' else 0
   splitz=-1.706 if kind=='expedition' else -.15 if kind=='bukhanka' else -.02
   if wheel:
    for front in [False,True]:
     for positive in [False,True]:groups[((c[:,2]>splitz)==front)&((c[:,0]>splitx)==positive)]='W_'+('F'if front else'R')+('R'if positive else'L')
   else:
    head=np.zeros(len(c),dtype=bool);tail=head.copy()
    if kind=='bukhanka':
     head=(i==113)&(c[:,2]>2.07);tail=(i==87)&(c[:,2]<-2.38)
    elif kind=='classic':
     head=(i==20)&(c[:,2]>1.78)&(c[:,1]>.95);tail=(i==20)&(c[:,2]<-1.95)&(c[:,1]>.64)
    elif i==7:
     radial=np.minimum((c[:,0]+.58)**2+(c[:,1]-1.36)**2,(c[:,0]-.74)**2+(c[:,1]-1.36)**2)
     head=(radial<.085**2)&(c[:,2]>.70)
     color=sample(p['material'],attrs['TEXCOORD_0'][idx].mean(1))
     tail=(c[:,2]<-4.115)&(c[:,1]>1.17)&(c[:,1]<1.43)&(abs(c[:,0]-.11)>.8)&(color[:,0]>color[:,1]*1.6)&(color[:,0]>color[:,2]*1.6)
    for positive in [False,True]:
     side=(c[:,0]>splitx)==positive
     groups[head&side]='L_HEAD_'+('P'if positive else'N');groups[tail&side]='L_TAIL_'+('P'if positive else'N')
   for group in np.unique(groups):
    selected=idx[groups==group];used,remapped=np.unique(selected.ravel(),return_inverse=True)
    chunks.append((str(group),p.get('material',0),{k:v[used].copy() for k,v in attrs.items()},remapped.reshape(-1,3)))
 # Four independent wheel centers, ground level and axle midpoint define model coordinates.
 centers={}
 for name in ['W_RL','W_RR','W_FL','W_FR']:
  v=np.concatenate([a['POSITION'] for g,m,a,ix in chunks if g==name]);centers[name]=(v.min(0)+v.max(0))/2
 origin=np.mean(list(centers.values()),axis=0);origin[1]=min(np.min(a['POSITION'][:,1]) for g,m,a,ix in chunks if g.startswith('W_'))
 for name in centers:centers[name]-=origin
 groups={}
 for g,m,a,idx in chunks:
  a['POSITION']-=origin
  if g.startswith('W_'):a['POSITION']-=centers[g]
  groups.setdefault(g,{}).setdefault((m,tuple(sorted(a))),[]).append((a,idx))
 required=['Body','W_RL','W_RR','W_FL','W_FR','L_HEAD_N','L_HEAD_P','L_TAIL_N','L_TAIL_P']
 assert all(n in groups for n in required), f'Missing geometry: {set(required)-groups.keys()}'
 out={'asset':copy.deepcopy(d['asset']),'scene':0,'scenes':[{'nodes':list(range(len(groups)))}],'nodes':[],'meshes':[], 'materials':copy.deepcopy(d.get('materials',[])),'textures':copy.deepcopy(d.get('textures',[])),'samplers':copy.deepcopy(d.get('samplers',[])),'images':[],'bufferViews':[],'accessors':[]}
 out['asset']['generator']='Offroad deterministic UAZ preparation (numpy/Pillow)'
 if d.get('extensionsUsed'):out['extensionsUsed']=d['extensionsUsed']
 if d.get('extensionsRequired'):out['extensionsRequired']=d['extensionsRequired']
 buf=bytearray()
 def view(data):
  while len(buf)%4:buf.append(0)
  v={'buffer':0,'byteOffset':len(buf),'byteLength':len(data)};buf.extend(data);out['bufferViews'].append(v);return len(out['bufferViews'])-1
 def accessor(a,indices=False):
  a=np.asarray(a,dtype='<u4'if indices else'<f4');v=view(a.tobytes());k=a.shape[1] if a.ndim>1 else 1
  ac={'bufferView':v,'componentType':5125 if indices else 5126,'count':len(a),'type':{1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[k]}
  if not indices and k==3:ac['min']=a.min(0).tolist();ac['max']=a.max(0).tolist()
  out['accessors'].append(ac);return len(out['accessors'])-1
 render=[]
 for group,surfaces in groups.items():
  prims=[]
  for (mat,keys),parts in surfaces.items():
   arrays={k:np.concatenate([a[k]for a,ix in parts])for k in keys};indices=[];offset=0
   for a,ix in parts:indices.append(ix+offset);offset+=len(a['POSITION'])
   indices=np.concatenate(indices)
   prims.append({'attributes':{k:accessor(v) for k,v in arrays.items()},'indices':accessor(indices.ravel(),True),'material':mat})
   if thumb:
    v=arrays['POSITION']+(centers[group]if group.startswith('W_')else 0);uv=arrays.get('TEXCOORD_0',np.zeros((len(v),2)));render.append((v[indices],sample(mat,uv[indices].mean(1))))
  node={'name':group,'mesh':len(out['meshes'])}
  if group.startswith('W_'):node['translation']=centers[group].tolist()
  out['nodes'].append(node);out['meshes'].append({'name':group,'primitives':prims})
 for im in d.get('images',[]):
  bv=d['bufferViews'][im['bufferView']];pic=Image.open(io.BytesIO(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]));pic.thumbnail((1024,1024),Image.Resampling.LANCZOS);stream=io.BytesIO();pic.save(stream,format='PNG',optimize=True);out['images'].append({'name':im.get('name','texture'),'mimeType':'image/png','bufferView':view(stream.getvalue())})
 out['buffers']=[{'byteLength':len(buf)}];js=json.dumps(out,separators=(',',':')).encode();js+=b' '*((-len(js))%4);buf+=b'\0'*((-len(buf))%4)
 data=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(buf))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(buf),0x004e4942)+buf
 Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_bytes(data)
 print(kind,round(len(data)/1024**2,2),'MiB', 'wheel centers', {k:np.round(v,3).tolist()for k,v in centers.items()})
 if thumb:
  tri=np.concatenate([v for v,c in render]);colors=np.concatenate([c for v,c in render]);right=np.array([.82,0,-.57]);up=np.array([-.20,.94,-.29]);depth=np.cross(right,up);points=np.stack((tri@right,-tri@up),axis=2);lo=points.min((0,1));hi=points.max((0,1));scale=min(290/(hi[0]-lo[0]),135/(hi[1]-lo[1]));points=(points-(lo+hi)/2)*scale+[160,76]
  normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);normal/=np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-12);shade=.45+.55*np.maximum(0,normal@np.array([.3,.85,.4]));colors=np.clip(colors*shade[:,None],0,255).astype('uint8');im=Image.new('RGBA',(320,160),(0,0,0,0));draw=ImageDraw.Draw(im)
  for j in np.argsort(tri.mean(1)@depth):draw.polygon([tuple(v)for v in points[j]],fill=tuple(colors[j])+(255,))
  Path(thumb).parent.mkdir(parents=True,exist_ok=True);im.save(thumb)

if __name__=='__main__':prepare(*sys.argv[1:])
