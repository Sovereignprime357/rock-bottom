"""Read-only source checks; neither calls stage() nor launches child processes."""
from pathlib import Path
import ast,hashlib,json,runpy,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
checks=0
def check(value,label):
 global checks
 checks+=1
 if not value:raise AssertionError(label)
ast.parse((HERE/'stage.py').read_text());checks+=1
m=runpy.run_path(str(HERE/'stage.py'))
for ref,digest in m['SOURCES'].items():check(sha((ROOT/ref).read_bytes())==digest,ref)
base=json.loads(m['read']('.build/3d/resident-index-composition-draft/manifest.json'))
with zipfile.ZipFile(ROOT/'.build/3d/resident-index-composition-draft/source.zip') as z:
 check(len(z.infolist())==495,'exact archive entries')
 for item in z.infolist():
  ref=str(m['safe'](item.filename));check(ref.startswith('game3d/'),'source root')
  check(sha(z.read(item))==base['source'][ref[7:]],'source hash '+ref)
 ordinary=z.read('game3d/tests/dave_walkthrough_probe.gd')
wrapper=m['read']('.build/3d/dave-ground-native-v2/game3d/tests/dave_walkthrough_probe.gd')
line=b'\trow["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))\n'
check(wrapper.count(line)==1 and wrapper.replace(line,b'',1)==ordinary,'exact retained ground-v2 adjunct')
art=json.loads(m['read']('.build/3d/dave-sleep-art-draft/MANIFEST.json'))
check(len(art['overlays'])==3,'only approved three focused overlays')
for row in art['overlays']:
 check(sha((ROOT/'.build/3d/dave-sleep-art-draft'/row['candidate']).read_bytes())==row['sha256'],'art overlay unchanged')
 check(base['source'].get(row['target'][7:])==row['baseSha256'],'base owner unchanged')
check(len(m['TESTS'])==5 and len(set(n for n,_ in m['TESTS']))==5,'five distinct focused tests')
ps=(HERE/'run-focused.ps1').read_text()
for token in ['UseShellExecute=$false','CreateNoWindow=$true','ProcessWindowStyle]::Hidden','ArgumentList.Add','WaitForExit(10000)','Elapsed.TotalSeconds-ge 600','Kill($true)','SCRIPT ERROR|ERROR|Parse Error','ObjectDB instances leaked','resources still in use at exit','pass_marker','VerifySource','engine_tests_pass=$false']:
 check(token in ps,'bounded strict child '+token)
check('--frames' not in ps,'no forced frame exit')
print(f'DAVE VALIDATION STATIC: PASS {checks} checks; no staging/engine/export/browser/Git run')
