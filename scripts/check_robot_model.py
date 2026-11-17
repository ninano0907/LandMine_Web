"""Validate exported geometry, animation continuity and planted spider feet."""
import json
import math
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parent.parent
scene=json.loads((ROOT/'app/assets/models/frontier_robot.scene.json').read_text())
asset=(ROOT/'app/assets/models/frontier_robot.glb').read_bytes()
magic,version,length=struct.unpack_from('<III',asset)
assert magic==0x46546c67 and version==2 and length==len(asset)
json_length,json_type=struct.unpack_from('<II',asset,12)
assert json_type==0x4e4f534a
gltf=json.loads(asset[20:20+json_length])
assert {a['name'] for a in gltf['animations']}=={'Idle','Walk','Mine'}
assert len(gltf['nodes'])==len(scene['nodes'])
for mesh in scene['meshes']:
    assert len(mesh['positions'])==len(mesh['normals'])
    assert all(math.isfinite(v) for v in mesh['positions']+mesh['normals'])
    assert all(0<=i<len(mesh['positions'])//3 for i in mesh['indices'])
for animation in scene['clips'].values():
    assert animation['times'][0]==0 and animation['times'][-1]==animation['duration']
    for frame in animation['poses']:
        for pose in frame.values():
            for values in pose.values():assert all(math.isfinite(v) for v in values)
            if 'rotation' in pose:assert abs(sum(q*q for q in pose['rotation'])-1)<1e-6
names={n['name']:i for i,n in enumerate(scene['nodes'])}
walk=scene['clips']['Walk']
speed=scene['metadata']['forwardSpeed'];duty=scene['metadata']['stanceDuty']
for index in range(8):
    key=str(names[f'Leg {index} foot'])
    offset=((index%4+index//4)%2)*.5
    last=None
    for time,frame in zip(walk['times'],walk['poses']):
        phase=(time+offset)%1
        foot=frame[key]['translation']
        if phase<duty:
            assert abs(foot[1])<1e-8,'Foot must remain on the floor in stance'
            world_z=foot[2]+speed*time
            if last and time-last[0]<.03 and phase>last[2]:
                assert abs(world_z-last[1])<1e-6,'Stance foot must not slide'
            last=(time,world_z,phase)
        else:last=None
for frame_index,time in enumerate(walk['times']):
    planted=sum((time+((i%4+i//4)%2)*.5)%1<duty for i in range(8))
    assert planted>=4,'At least four legs support the body'
mine=scene['clips']['Mine']['poses']
for part in ['Excavator elbow','Bucket articulation','Conveyor ore 0','Drill rotation']:
    key=str(names[part])
    assert len({json.dumps(f[key],sort_keys=True) for f in mine})>10,f'{part} is not animated'
print(f'PASS: standard GLB, {len(scene["nodes"])} nodes, three clips, eight legs, planted stance, moving drill/bucket/conveyor')
# The bucket must reach both the excavation and the actual conveyor intake.
cycle=scene['clips']['Mine'];poses=cycle['poses'];times=cycle['times']
def at(part,time):
    frame=min(range(len(times)),key=lambda i:abs(times[i]-time))
    return poses[frame][str(names[part])]
bucket_key='Bucket articulation'
assert at(bucket_key,.8)['translation'][1] < .3, 'Bucket must reach the ground'
assert at(bucket_key,2.5)['translation'][1] > 2, 'Loaded bucket must lift before swinging'
dump=at(bucket_key,4.1)
assert abs(dump['translation'][0]+1)<.01 and dump['translation'][2]>2.5, 'Dump must align with belt intake'
assert dump['rotation'] != at(bucket_key,3.3)['rotation'], 'Bucket must tip to release ore'
assert at('Bucket carried ore 0',2.5)['scale'][0]>.9
assert at('Bucket carried ore 0',4.6)['scale'][0]<.01
assert at('Falling ore 0',3.8)['scale'][0]>.5
for i in range(8):
    key=str(names[f'Leg {i} foot'])
    assert all(f[key]['translation']==poses[0][key]['translation'] for f in poses), 'Mining feet must stay braced'
for part in ['Bucket articulation','Excavator elbow','Body','Steam puff 0']:
    key=str(names[part])
    for prop in poses[0][key]:
        assert all(abs(a-b)<1e-6 for a,b in zip(poses[0][key][prop],poses[-1][key][prop])), f'{part} loop jumps'
for part in ['Belt cleat 0','Conveyor roller 0','Drill debris 0']:
    key=str(names[part])
    assert len({json.dumps(f[key],sort_keys=True) for f in poses})>10, f'{part} must move'
print('PASS: ground scoop, lift, belt-aligned dump, carried/falling ore, planted mining feet, seamless working rig')
