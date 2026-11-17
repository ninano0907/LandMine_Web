"""Build an original rigid-jointed mining robot and portable animated glTF.
Pure Python; the JSON scene is consumed by the Flutter mesh renderer.
All dimensions are model units. Y is up, Z is forward.
"""
import base64
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'app/assets/models'
TAU = math.tau
meshes, nodes, clips = [], [], {}
BRASS, IRON, COPPER, WOOD = '#c79d5c', '#725b49', '#b77b4b', '#8a5c3d'
STEEL, GLASS, LIGHT = '#80847b', '#b4bdab', '#ffc263'

def add(a,b): return [a[i]+b[i] for i in range(3)]
def sub(a,b): return [a[i]-b[i] for i in range(3)]
def mul(a,b): return [x*b for x in a]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def norm(v): return mul(v,1/max(1e-8,math.sqrt(dot(v,v))))
def quat(axis,angle): return [*(x*math.sin(angle/2) for x in norm(axis)),math.cos(angle/2)]
def align_y(delta):
    v=norm(delta)
    if v[1]<-.9999:return [1,0,0,0]
    q=[v[2],0,-v[0],1+v[1]]
    return [x/math.sqrt(sum(t*t for t in q)) for x in q]
def node(name, mesh=None, p=(0,0,0), q=(0,0,0,1), s=(1,1,1), parent=None):
    item={'name':name,'translation':list(p),'rotation':list(q),'scale':list(s),'children':[]}
    if mesh is not None:item['mesh']=mesh
    idx=len(nodes);nodes.append(item)
    if parent is not None:nodes[parent]['children'].append(idx)
    return idx

def mesh(name,positions,normals,indices,color):
    idx=len(meshes);meshes.append(dict(name=name,positions=positions,normals=normals,indices=indices,color=color));return idx

def lathe(name,profile,color,sides=12):
    pos,nor,ind=[],[],[]
    for j,(r,y) in enumerate(profile):
        prev=profile[max(0,j-1)];nxt=profile[min(len(profile)-1,j+1)]
        slope=(nxt[0]-prev[0])/max(.001,nxt[1]-prev[1])
        for i in range(sides):
            a=i*TAU/sides
            pos.extend([r*math.cos(a),y,r*math.sin(a)])
            nor.extend(norm([math.cos(a),-slope,math.sin(a)]))
    for j in range(len(profile)-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides;c=b+sides;d=a+sides
            ind.extend([a,d,b,b,d,c])
    return mesh(name,pos,nor,ind,color)

def ellipsoid(name,r,color):
    return lathe(name,[(max(.001,math.sin(j*math.pi/8))*r[0],-math.cos(j*math.pi/8)*r[1]) for j in range(9)],color,14)

def cube(name,color):
    pos,nor,idx=[],[],[]
    for axis,sign in [(0,1),(0,-1),(1,1),(1,-1),(2,1),(2,-1)]:
        normal=[0,0,0];normal[axis]=sign
        u=[0,0,0];u[(axis+1)%3]=1
        v=cross(normal,u)
        offset=len(pos)//3
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            pos.extend([normal[k]*.5+u[k]*a*.5+v[k]*b*.5 for k in range(3)]);nor.extend(normal)
        idx.extend([offset,offset+1,offset+2,offset,offset+2,offset+3])
    return mesh(name,pos,nor,idx,color)

root=node('Root')
body=node('Body',parent=root)
# Reusable parts. Rounded lathed surfaces, not 2D sprites.
metal_rod=lathe('Steel piston',[(.001,-.5),(.12,-.5),(.12,.5),(.001,.5)],STEEL,10)
upper=lathe('Armoured limb',[(.001,-.5),(.24,-.5),(.3,-.36),(.25,.35),(.18,.5),(.001,.5)],IRON,10)
lower=lathe('Brass limb',[(.001,-.5),(.17,-.5),(.21,-.35),(.19,.35),(.14,.5),(.001,.5)],BRASS,10)
joint=ellipsoid('Joint',(.24,.24,.24),BRASS)
footmesh=lathe('Ground pad',[(.001,0),(.38,0),(.45,.08),(.39,.23),(.29,.3),(.001,.3)],IRON,10)
bolt=ellipsoid('Rivet',(.07,.07,.07),BRASS)
hull=ellipsoid('Riveted boiler hull',(1.55,1.0,1.55),IRON)
node('Boiler hull',hull,p=(0,2.45,0),s=(1,1,1.15),parent=body)
# Brass belts wrapped around the sculpted hull.
for z in [-.95,.95]:
    ring=lathe('Boiler strap',[(1.48,-.065),(1.56,-.045),(1.56,.045),(1.48,.065)],BRASS,20)
    node('Boiler strap',ring,p=(0,2.45,z),q=quat([1,0,0],math.pi/2),s=(1,.75,.65),parent=body)
    for i in range(10):
        a=i*TAU/10
        node('Boiler rivet',bolt,p=(math.cos(a)*1.49,2.45+math.sin(a)*.94,z+.06),parent=body)
# Front furnace rim and warm grate.
front=lathe('Furnace bezel',[(.7,-.1),(.85,-.08),(.85,.08),(.7,.1)],BRASS,18)
node('Front furnace rim',front,p=(0,2.3,1.56),q=quat([1,0,0],math.pi/2),parent=body)
node('Furnace glow',ellipsoid('Furnace glow',(.68,.68,.68),LIGHT),p=(0,2.3,1.58),s=(1,1,.18),parent=body)
for x in [-.45,-.15,.15,.45]:
    node('Furnace grate',metal_rod,p=(x,2.28,1.7),s=(.4,.96,.4),parent=body)
# Wood carriage with ribs, roof, door, porch, windows and lamps.
woodbox=cube('Wood panel',WOOD);darkbox=cube('Dark iron panel',IRON);trimbox=cube('Brass trim',BRASS)
node('Recruitment carriage',woodbox,p=(0,2.25,-2.0),s=(2.25,1.9,1.45),parent=body)
roof=lathe('Curved carriage roof',[(.001,-.68),(1.24,-.68),(1.35,-.5),(1.35,.5),(1.24,.68),(.001,.68)],IRON,16)
node('Carriage roof',roof,p=(0,3.27,-2.0),q=quat([1,0,0],math.pi/2),s=(1,1,.29),parent=body)
for side in [-1,1]:
    for z in [-2.65,-2.0,-1.35]:
        node('Carriage frame',trimbox,p=(side*1.14,2.23,z),s=(.055,1.85,.065),parent=body)
    node('Carriage window frame',trimbox,p=(side*1.15,2.43,-2),s=(.06,.85,.66),parent=body)
    node('Carriage window glass',cube('Warm window',LIGHT),p=(side*1.19,2.43,-2),s=(.04,.65,.48),parent=body)
    for h in [-.18,.18]:node('Window mullion',darkbox,p=(side*1.22,2.43+h,-2),s=(.04,.04,.5),parent=body)
    node('Porch rail',trimbox,p=(side*1.4,1.55,-2.0),s=(.07,.1,1.8),parent=body)
    for z in [-2.7,-1.3]:node('Porch post',trimbox,p=(side*1.4,1.8,z),s=(.08,.7,.08),parent=body)
# Vertical chimney and copper pressure vessel.
chimney=lathe('Chimney',[(.01,0),(.23,0),(.23,1.4),(.34,1.44),(.34,1.6),(.21,1.6),(.21,1.45)],IRON,14)
node('Chimney',chimney,p=(-.6,3.25,-.2),parent=body)
node('Copper tank',lathe('Pressure vessel',[(.001,0),(.3,.08),(.36,.2),(.36,1.05),(.3,1.18),(.001,1.24)],COPPER,14),p=(1.13,2.5,-.45),parent=body)
for y in [2.7,3.4]:node('Pressure band',lathe('Pressure band',[(.34,-.05),(.39,-.04),(.39,.04),(.34,.05)],BRASS,14),p=(1.13,y,-.45),parent=body)
# Pressure gauge facing forward.
node('Pressure gauge rim',lathe('Gauge rim',[(.001,-.06),(.3,-.06),(.33,0),(.3,.06),(.001,.06)],BRASS,14),p=(-.7,3.35,.95),q=quat([1,0,0],math.pi/2),parent=body)
node('Gauge face',ellipsoid('Gauge dial',(.25,.25,.25),'#e7dcc1'),p=(-.7,3.35,1.04),s=(1,1,.12),parent=body)
node('Gauge needle',darkbox,p=(-.65,3.4,1.08),s=(.04,.21,.02),q=quat([0,0,1],-.6),parent=body)
# Compact twin-gun turret gives deployed mining bots an actual weapon.
turret=node('Turret pivot',p=(0,3.35,.1),parent=body)
node('Turret dome',ellipsoid('Gun turret',(.48,.3,.48),IRON),parent=turret)
barrel=lathe('Gun barrel',[(.001,-.5),(.08,-.5),(.08,.43),(.12,.43),(.12,.5),(.001,.5)],STEEL,10)
for x in [-.17,.17]:node('Twin cannon',barrel,p=(x,.05,.62),q=quat([1,0,0],math.pi/2),s=(1,1.0,1),parent=turret)
# Eight independently articulated legs (three rigid parts and a moving knee).
legs=[]
for i in range(8):
    side=-1 if i<4 else 1;j=i%4;z=-1.4+j*.88
    hip=[side*1.23,2.2,z]
    node('Hip joint %d'%i,joint,p=hip,parent=body)
    ids=[node('Leg %d upper'%i,upper,parent=root),node('Leg %d lower'%i,lower,parent=root),node('Leg %d knee'%i,joint,parent=root),node('Leg %d foot'%i,footmesh,parent=root)]
    legs.append((side,j,hip,ids))
# Rotating helical drill: the bit is a true mesh with two flutes.
shaft=lathe('Drill cone',[(.01,0),(.12,.08),(.34,.8),(.48,1.35),(.48,1.46),(.01,1.46)],STEEL,18)
drill=node('Drill rotation',p=(0,.16,1.35),parent=root)
node('Drill core',shaft,parent=drill)
for turn in [0,math.pi]:
    pos,nor,ind=[],[],[]
    for i in range(81):
        t=i/80;y=.08+t*1.3;a=t*TAU*2.5+turn;r=.07+t*.42
        for radius in [r,r+.06+.14*t]:
            pos.extend([math.cos(a)*radius,y,math.sin(a)*radius]);nor.extend(norm([math.cos(a)*.3,.9,math.sin(a)*.3]))
        if i<80:
            k=i*2;ind.extend([k,k+1,k+2,k+1,k+3,k+2,k+2,k+1,k,k+2,k+3,k+1])
    node('Spiral flight',mesh('Spiral flight',pos,nor,ind,BRASS),parent=drill)
node('Drill motor',lathe('Drill motor',[(.01,0),(.5,0),(.55,.15),(.55,.65),(.42,.8),(.01,.8)],IRON,14),p=(0,1.45,1.35),parent=body)
# Articulated excavator mounted on the left. Bucket has open jaw and teeth.
arm_upper=node('Excavator boom',upper,parent=root)
arm_lower=node('Excavator stick',lower,parent=root)
arm_knee=node('Excavator elbow',joint,parent=root)
bucket=node('Bucket articulation',parent=root)
node('Bucket back',darkbox,p=(0,.05,0),s=(.85,.6,.2),parent=bucket)
node('Bucket scoop',darkbox,p=(0,-.22,.3),s=(.85,.1,.7),parent=bucket)
for side in [-1,1]:node('Bucket cheek',trimbox,p=(side*.43,-.03,.29),s=(.06,.45,.7),parent=bucket)
for x in [-.33,-.11,.11,.33]:node('Bucket tooth',trimbox,p=(x,-.24,.74),s=(.1,.08,.3),parent=bucket)
# Sloped conveyor attached to the boiler face.
for x in [-.46,.46]:node('Conveyor rail',trimbox,p=(x,1.7,2.0),s=(.08,.1,1.8),q=quat([1,0,0],.46),parent=body)
node('Conveyor belt',darkbox,p=(0,1.68,2.0),s=(.82,.08,1.8),q=quat([1,0,0],.46),parent=body)
rollers=[]
roller_mesh=lathe('Conveyor roller',[(.001,-.45),(.1,-.45),(.1,.45),(.001,.45)],STEEL,8)
for i in range(6):
    z=1.25+i*.29;y=2.04-i*.14
    rollers.append(node('Conveyor roller %d'%i,roller_mesh,p=(0,y,z),q=quat([0,0,1],math.pi/2),parent=root))
goldmesh=ellipsoid('Gold ore',(.13,.11,.13),'#e8b748')
gold=[node('Conveyor ore %d'%i,goldmesh,parent=root) for i in range(4)]

# A bone represented by an oriented, scaled rigid mesh.
def bone_pose(a,b):return dict(translation=mul(add(a,b),.5),rotation=align_y(sub(b,a)),scale=[1,math.sqrt(dot(sub(b,a),sub(b,a))),1])
def solve_knee(hip,foot,l1,l2):
    delta=sub(foot,hip);d=math.sqrt(dot(delta,delta));direction=norm(delta)
    d=min(d,l1+l2-.01);along=(l1*l1-l2*l2+d*d)/(2*d)
    bend=norm(sub([0,1,0],mul(direction,direction[1])))
    return add(add(hip,mul(direction,along)),mul(bend,math.sqrt(max(0,l1*l1-along*along))))
def pose(mode,t):
    result={}
    walking=mode=='Walk';mining=mode=='Mine'
    bob=.065*math.sin(t*TAU*2) if walking else .018*math.sin(t*TAU)
    result[body]={'translation':[0,bob,0]}
    for i,(side,j,hip,ids) in enumerate(legs):
        # Alternating tetrapod gait: four legs remain in stance at all times.
        phase=(t+((j+i//4)%2)*.5)%1
        duty=.68
        zshift=1.25-2.5*phase/duty if phase<duty else -1.25+2.5*(phase-duty)/(1-duty)
        lift=0 if phase<duty else math.sin((phase-duty)/(1-duty)*math.pi)*.65
        foot=[side*(3.5+.12*abs(j-1.5)),lift,zshift+hip[2]*1.65] if walking else [side*(3.5+.12*abs(j-1.5)),0,hip[2]*1.65]
        h=add(hip,[0,bob,0]);knee=solve_knee(h,foot,2.05,2.25)
        result[ids[0]]=bone_pose(h,knee);result[ids[1]]=bone_pose(knee,add(foot,[0,.2,0]));result[ids[2]]={'translation':knee};result[ids[3]]={'translation':foot}
    result[drill]={'translation':[0,1.0 if walking else .16,1.35],'rotation':quat([0,1,0],t*TAU*6 if mining else 0)}
    phase=t%1
    if mining:
        bucket_at=[3.85+.35*math.sin(phase*TAU),.65+1.0*(1-math.cos(phase*TAU)),1.05+.3*math.sin(phase*TAU)]
        curl=-.6+math.sin(phase*TAU)*.65
    else:bucket_at=[3.3,1.9,.9];curl=-.7
    shoulder=[1.1,3.0+bob,.8];elbow=solve_knee(shoulder,bucket_at,2.1,2.2)
    result[arm_upper]=bone_pose(shoulder,elbow);result[arm_lower]=bone_pose(elbow,bucket_at);result[arm_knee]={'translation':elbow};result[bucket]={'translation':bucket_at,'rotation':quat([1,0,0],curl)}
    for i,key in enumerate(gold):
        progress=(t*1.5+i/4)%1
        result[key]={'translation':[.12*math.sin(i),1.35+progress*.7,2.7-progress*1.45],'scale':[1,1,1] if mining else [.001,.001,.001]}
    return {str(k):v for k,v in result.items()}

# Clips are baked for portable viewers and sampled identically by Flutter.
for mode,duration,frames in [('Idle',4,49),('Walk',1,49),('Mine',4,193)]:
    times=[i*duration/(frames-1) for i in range(frames)]
    clips[mode]={'duration':duration,'times':times,'poses':[pose(mode,t) for t in times]}
base=pose('Idle',0)
for key,values in base.items():nodes[int(key)].update(values)
scene={'format':'frontier-rigid-mesh-1','meshes':meshes,'nodes':nodes,'root':root,'clips':clips,'metadata':{'palette':'dark brown iron, copper and brass','legs':8,'stanceDuty':.68,'stride':2.5,'forwardSpeed':2.5/.68,'drillContact':[0,.16,1.35]}}
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'frontier_robot.scene.json').write_text(json.dumps(scene,separators=(',',':')))

# Export self-contained standard glTF 2.0 with rigid-node animation channels.
binary=bytearray();views=[];accessors=[]
def accessor(values,kind,component=5126,minimum=None,maximum=None):
    while len(binary)%4:binary.append(0)
    start=len(binary);fmt='f' if component==5126 else 'I'
    binary.extend(struct.pack('<'+fmt*len(values),*values));view=len(views)
    views.append({'buffer':0,'byteOffset':start,'byteLength':len(binary)-start})
    size={'SCALAR':1,'VEC3':3,'VEC4':4}[kind]
    a={'bufferView':view,'componentType':component,'count':len(values)//size,'type':kind}
    if minimum is not None:a['min']=minimum
    if maximum is not None:a['max']=maximum
    accessors.append(a);return len(accessors)-1
materials=[];gmeshes=[]
for m in meshes:
    color=[int(m['color'][i:i+2],16)/255 for i in [1,3,5]]+[1]
    material=len(materials);materials.append({'name':m['name'],'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':.65 if m['color'] in [IRON,BRASS,COPPER,STEEL] else .1,'roughnessFactor':.42},'doubleSided':True})
    bounds=([min(m['positions'][i::3]) for i in range(3)],[max(m['positions'][i::3]) for i in range(3)])
    gmeshes.append({'name':m['name'],'primitives':[{'attributes':{'POSITION':accessor(m['positions'],'VEC3',minimum=bounds[0],maximum=bounds[1]),'NORMAL':accessor(m['normals'],'VEC3')},'indices':accessor(m['indices'],'SCALAR',5125),'material':material}]})
animations=[]
for name,clip in clips.items():
    sampler_time=accessor(clip['times'],'SCALAR',minimum=[0],maximum=[clip['duration']])
    samplers,channels=[],[]
    for key in clip['poses'][0]:
        for prop in clip['poses'][0][key]:
            values=[x for frame in clip['poses'] for x in frame[key][prop]]
            sample=len(samplers);samplers.append({'input':sampler_time,'output':accessor(values,'VEC4' if prop=='rotation' else 'VEC3'),'interpolation':'LINEAR'})
            channels.append({'sampler':sample,'target':{'node':int(key),'path':prop}})
    animations.append({'name':name,'samplers':samplers,'channels':channels})
gltf={'asset':{'version':'2.0','generator':'Frontier procedural robot builder'},'scene':0,'scenes':[{'nodes':[root]}],'nodes':nodes,'meshes':gmeshes,'materials':materials,'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors,'animations':animations}
encoded=json.dumps(gltf,separators=(',',':')).encode()
while len(encoded)%4:encoded+=b' '
while len(binary)%4:binary.append(0)
glb=struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
(OUT/'frontier_robot.glb').write_bytes(glb)
print(f'Built {len(nodes)} nodes, {sum(len(m["indices"])//3 for m in meshes)} unique mesh triangles; clips: {list(clips)}')
print(f'GLB: {len(glb):,} bytes; JSON: {(OUT/"frontier_robot.scene.json").stat().st_size:,} bytes')
