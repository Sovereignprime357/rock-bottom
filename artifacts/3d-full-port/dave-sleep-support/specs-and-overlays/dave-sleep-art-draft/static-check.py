"""No engine/Git: raw pins, exact reverse patch and bounded contract inventory."""
from pathlib import Path
import hashlib,json,re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
checks=0
def check(ok,label):
 global checks
 checks+=1
 if not ok: raise AssertionError(label)

pins=json.loads((HERE/'BASELINE.json').read_text())
for ref,digest in pins['source'].items():
 check(sha((ROOT/ref).read_bytes())==digest,'live source unchanged '+ref)
evidence=pins['groundV2']
check(sha((ROOT/evidence['path']).read_bytes())==evidence['sha256'],'original ground-v2 bytes')
ref='game3d/scripts/actor_animation.gd'
old=(HERE/'original'/ref).read_bytes()
new=(HERE/'candidate'/ref).read_bytes()
check(sha(old)==pins['source'][ref],'retained original Animator')
check(sha(new)==pins['candidateAnimator'],'candidate Animator pin')
check(b'\r' not in old and b'\r' not in new,'preserve original LF')
changes=json.loads((HERE/'transforms.json').read_text())
check(len(changes)==2,'only two scoped edits')
text=new.decode()
for row in reversed(changes):
 check(text.count(row['after'])==1,'unique reverse replacement')
 text=text.replace(row['after'],row['before'],1)
check(text.encode()==old,'byte-exact reverse to production Animator')
reference=(HERE/'candidate/game3d/tests/reference_actor_animation_sleep_original.gd').read_bytes()
check(sha(reference)==pins['referenceAnimator'],'reference pin')
check(reference==old.replace(b'class_name RockBottomActorAnimation\n',b'',1),'reference removes only global class registration')
check([p.relative_to(HERE/'candidate/game3d/scripts').as_posix() for p in (HERE/'candidate/game3d/scripts').rglob('*') if p.is_file()]==['actor_animation.gd'],'only one production owner overlay')
check(new.count(b'rig.definition.visual_id == &"dave"')==old.count(b'rig.definition.visual_id == &"dave"')+2,'both changes identity-guarded')
check(b'if not dead and action == &"sleep" and rig.definition.visual_id == &"dave":' in new,'pillow requires current living sleep action')
insert=changes[1]['after'].replace(changes[1]['before'].split('\n\tif dead:')[0],'',1)
for forbidden in ['rand','ray','get_surface','get_bone','load(','new()','process','set_meta','get_tree','emit']:
 check(forbidden not in insert,'no new runtime '+forbidden)
test=(HERE/'candidate/game3d/tests/test_dave_sleep_support.gd').read_text()
for required in ['sleep_samples == 384','registry_samples == 71','completed_groups == 3',
 'for seed_value: int in [17,733]','for detail: int in [0,2]','range(96)',
 'Geometry3D.segment_intersects_triangle','part.skin.get_bind_pose(index)',
 'head.is_ancestor_of(part)','pillow.is_ancestor_of(part)',
 'facts.radius == original_radius','_resources(art) == resources',
 '_pose_receipt(left) == _pose_receipt(right)','Original.tick','Original.reset',
 'float(facts.contact) >= -0.025','float(facts.contact) <= 0.005',
 'float(facts.body) >= 0.004','failures.size() <= 12',
 'snapshot == original_snapshot','quit(0 if failures.is_empty() else 1)']:
 check(required in test,'focused contract includes '+required)
for method in re.findall(r'^func (\w+)\(',test,re.M):
 check(len(re.findall(r'^func '+method+r'\(',test,re.M))==1,'no duplicate test method '+method)
spec=(HERE/'SPEC-DRAFT.md').read_text()
check('Spec before isolated code.' in spec and 'No performance or full-port completion claim.' in spec,'bounded acceptance')
print(f'DAVE SLEEP STATIC: PASS {checks} checks; exact original reverse/pins; no engine/render/geometry acceptance')
