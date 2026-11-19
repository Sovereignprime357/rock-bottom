"""Isolated one-owner sleep art candidate; no engine, Git or live writes."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def put(ref,data):
 p=HERE/ref;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
source={
 'game3d/scripts/actor_animation.gd':'3317d7a885e96a288828914b9289c4668ed89fb268bee300a3b92d938397603d',
 'game3d/scripts/cast_profiles.gd':'40d04a6b282c3710d9babeba2f8314f5838ed449f3f77ca15fc5590b124d3668',
 'game3d/scripts/character_roster.gd':'1e8d46483e3cae1304800e781590a534500515821f888cc8807bebf45331c4a1',
 'game3d/scripts/character_art.gd':'d935c7715015385812bbbdc8fc0c8948af19855a181b7bf3c3ed75277606a0c8',
 'game3d/scripts/presentation_visibility.gd':'76697233cbcd0bd26f6fb1beb76906505ff74ec73fdf2605e765b1abc41a3555',
}
for ref,h in source.items():assert sha((ROOT/ref).read_bytes())==h,ref
ref='game3d/scripts/actor_animation.gd';original=(ROOT/ref).read_bytes()
assert b'\r' not in original
changes=[
 ('\t\t\t_pose(rig,"root",Vector3(0,0,1.48),Vector3(0,0.27,0))',
  '\t\t\t_pose(rig,"root",Vector3(0,0,1.48),Vector3(0,0.31 if rig.definition.visual_id == &"dave" else 0.27,0))'),
 ('\t_apply_bones(rig,poses)\n\tRoster._sync_attachments(rig)\n\tif dead:',
  '\t_apply_bones(rig,poses)\n\tRoster._sync_attachments(rig)\n\tif not dead and action == &"sleep" and rig.definition.visual_id == &"dave":\n\t\t# Repose the existing cushion under the cheek; waking restores its wrist binding.\n\t\tvar pillow: Node3D = rig.prop_lookup.pillow.node\n\t\tvar head: Node3D = rig.prop_lookup.head.node\n\t\tvar cushion_basis := Basis(Vector3(0,0,1),Vector3(1,0,0),Vector3(0,2.2,0))\n\t\tRoster._attachment_target(rig,pillow,Transform3D(cushion_basis,Vector3(head.position.x-0.07,0.091,head.position.z)))\n\tif dead:'),
]
text=original.decode()
for before,after in changes:
 assert text.count(before)==1,before
 text=text.replace(before,after,1)
put('candidate/'+ref,text.encode())
put('original/'+ref,original)
reference=original.decode().replace('class_name RockBottomActorAnimation\n','',1)
put('candidate/game3d/tests/reference_actor_animation_sleep_original.gd',reference.encode())
put('transforms.json',(json.dumps([{'before':a,'after':b} for a,b in changes],indent=2)+'\n').encode())
evidence='.build/full-port/dave-wake/ground-native-v2/dave-walkthrough.json'
pins={'schema':1,'source':source,'groundV2':{'path':evidence,'sha256':sha((ROOT/evidence).read_bytes())},'candidateAnimator':sha(text.encode()),'referenceAnimator':sha(reference.encode()),'scope':'Dave sleep output only; same cached pillow mesh/material; no engine/Git/production writes'}
put('BASELINE.json',(json.dumps(pins,indent=2)+'\n').encode())
print('DAVE SLEEP PREPARE: PASS; one isolated Animator owner + original reference; two exact guarded edits')
