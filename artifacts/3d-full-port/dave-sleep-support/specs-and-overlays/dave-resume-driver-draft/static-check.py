from pathlib import Path
import ast,hashlib,json
H=Path(__file__).resolve().parent;R=H.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
count=0
def check(ok,label):
 global count
 count+=1
 if not ok:raise AssertionError(label)
m=json.loads((H/'MANIFEST.json').read_text());edits=json.loads((H/'EDITS.json').read_text())
for ref,digest in m['old'].items():check(sha((R/ref).read_bytes())==digest,'unchanged production '+ref)
for ref,digest in m['candidate'].items():check(sha((H/'candidate'/ref).read_bytes())==digest,'candidate '+ref)
for ref,digest in m['failedWebV1'].items():check(sha((R/ref).read_bytes())==digest,'retained failed evidence '+ref)
p=(H/'candidate/game3d/tests/dave_walkthrough_probe.gd').read_bytes();t=p.decode()
for row in reversed(edits['probe']):check(t.count(row['after'])==1,'one exact probe splice');t=t.replace(row['after'],row['before'],1)
check(t.encode()==(H/'original/game3d/tests/dave_walkthrough_probe.gd').read_bytes(),'exact original scenario reverse')
test=(H/'candidate/game3d/tests/test_dave_walkthrough_contract.gd').read_bytes();s=test.decode()
s=s.replace(edits['contractAddition'],'').replace('_completion_checks(); _resume_checks()','_completion_checks()').replace('completed_groups == 5,"all five contract groups reached their actual tails"','completed_groups == 4,"all four contract groups reached their actual tails"').replace('completed_groups,"/5 groups; no rendered acceptance)"','completed_groups,"/4 groups; no rendered acceptance)"')
check(s.encode()==(H/'original/game3d/tests/test_dave_walkthrough_contract.gd').read_bytes(),'original103 assertions and4 groups exact')
line=b'\trow["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))\n'
ground=(H/'ground-wrapper/dave_walkthrough_probe.gd').read_bytes();check(sha(ground)==m['groundWrapper'] and ground.count(line)==1 and ground.replace(line,b'',1)==p,'unchanged passive ground line only')
for token in ['TOTAL_MS := 120000','Time.get_ticks_msec()-move_start < 5000','distance_to(origin) < 0.15','choices < 20','now-last_choice >= 250','_combat_segment(game.player.position,point)','Callable(self,"_combat_segment")','_motion(','await game.frame_sampled']:
 check(token in p.decode(),'retained actual boundary '+token)
tail=edits['probe'][1]['after']
for forbidden in ['runtime.p.','runtime.s.','rng','game.player.position =','game.physics.','teleport','set_position']:
 check(forbidden not in tail,'no source/physics write '+forbidden)
for name in ['prepare.py','stage.py']:ast.parse((H/name).read_text());count+=1
print(f'DAVE RESUME STATIC: PASS {count} checks; exact scenario reversal and original assertions; no engine')
