"""Read-only successor preservation checks; no engine, Git or live writes."""
from pathlib import Path
import ast,hashlib,json,re,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OLD=ROOT/'.build/3d/positive-certificate-performance-draft';SNAP=ROOT/'.build/3d/performance-phase-snapshot-draft'
sha=lambda b:hashlib.sha256(b).hexdigest()
checks=0
def check(ok,label):
 global checks
 checks+=1
 if not ok:raise AssertionError(label)
p=json.loads((HERE/'pins.json').read_text());old=json.loads((OLD/'pins.json').read_text());spins=json.loads((SNAP/'PINS.json').read_text())
check(sha((HERE/'source.zip').read_bytes())==p['archive_sha256']==old['archive_sha256'],'identical frozen archive')
check(p['source']==old['source'] and len(p['source'])==495,'same495 inventory')
with zipfile.ZipFile(HERE/'source.zip') as z:
 check(set(z.namelist())=={'game3d/'+k for k in p['source']},'exact archive paths')
 for rel,digest in p['source'].items():check(sha(z.read('game3d/'+rel))==digest,'archive '+rel)
check(p['certificate_overlay']==old['certificate_overlay'],'owner candidate unchanged')
for rel,digest in p['certificate_overlay'].items():check(sha((HERE/'certificate'/rel).read_bytes())==digest==sha((OLD/'certificate'/rel).read_bytes()),'same candidate '+rel)
check(set(p['overlay'])==set(old['overlay'])|{'tests/test_performance_phase_snapshot.gd'},'only common snapshot regression added')
for rel,digest in p['overlay'].items():check(sha((HERE/rel).read_bytes())==digest,'common bytes '+rel)
for rel in ['tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd']:check(p['overlay'][rel]==old['overlay'][rel],'driver/contract untouched '+rel)
check(p['overlay']['tests/full_actor_performance_probe.gd']==spins['candidate_probe_sha256'],'corrected common observer')
check(p['overlay']['tests/test_performance_phase_snapshot.gd']==spins['regression_sha256'],'actual snapshot regression')
for name in ['candidate_proof','snapshot_proof']:
 for rel,digest in p[name].items():check(sha((ROOT/rel).read_bytes())==digest,'proof '+rel)
for key in ['runtime_sources','measured_scene_sha256','engine_launcher_sha256','engine_runtime_sha256','release_template_sha256']:check(p[key]==old[key],'same runtime boundary '+key)
for key,path in [('engine_launcher_sha256','.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'),('engine_runtime_sha256','.tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe'),('release_template_sha256','.tools/templates/windows_release_x86_64.exe')]:check(sha((ROOT/path).read_bytes())==p[key],'runtime byte pin '+key)
for name,key in [('profile-one.ps1','wrapper_sha256'),('run-paired.ps1','paired_wrapper_sha256'),('compare-pair.py','comparison_helper_sha256')]:check(sha((HERE/name).read_bytes())==p[key],'helper '+name)
for row in json.loads((HERE/'transforms.json').read_text()):
 text=(HERE/row['file']).read_text();original=ROOT/row['original_path']
 check(sha(original.read_bytes())==row['original_sha256'],'held original '+row['file'])
 for edit in reversed(row['edits']):
  for at in reversed(edit['positions']):
   check(text[at:at+len(edit['new'])]==edit['new'],'reverse splice '+row['file'])
   text=text[:at]+edit['old']+text[at+len(edit['new']):]
 check(text==original.read_text(),'exact old helper restored '+row['file'])
probe=(HERE/'tests/full_actor_performance_probe.gd').read_text()
check(probe==(SNAP/'candidate/game3d/tests/full_actor_performance_probe.gd').read_text(),'same common observer code')
measured=probe[probe.index('class MeasuredScene:\n'):probe.index('\nvar game: MeasuredScene')].rstrip()+'\n'
check(sha(measured.encode())==p['measured_scene_sha256'],'unchanged actual measured class')
one=(HERE/'profile-one.ps1').read_text();compare=(HERE/'compare-pair.py').read_text()
check("[ValidateSet('baseline','positive_certificate')]" in one and '$pins.overlay.Count -ne 4' in one,'two exact variants/four common test files')
check('snapshot_contract_complete = $true' in one and "'snapshot_contract'" in one,'actual common gate')
check("'retention_contract'" in one and '6/6 groups; focused_saved_queries=2' in one,'actual candidate gate retained')
check('tests/test_performance_phase_snapshot.gd.uid' in one and 'tests/test_performance_phase_snapshot.gd.uid' in compare,'one exact added UID')
check('900' in one and '$process.Kill($true)' in one and 'WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden' in one,'same owned finite child lifetime')
check('Sustained60 population requirement failed.' in one and 'Non-performance workload failure' in one and '--frames' not in one,'no threshold/population/frame shortcuts')
pattern=r'^PERFORMANCE PHASE SNAPSHOT: PASS; [1-9][0-9]* checks; 5/5 groups; original_alias_reproduced=true; no performance claim\r?$'
good='PERFORMANCE PHASE SNAPSHOT: PASS; 27 checks; 5/5 groups; original_alias_reproduced=true; no performance claim'
check(bool(re.search(pattern,good,re.M)),'completed snapshot marker')
for bad in [good.replace('5/5','4/5'),good.replace('true','false'),good.replace('PASS','FAIL'),good.replace('27 checks','0 checks')]:check(re.search(pattern,bad,re.M) is None,'incomplete snapshot refuses')
for path in HERE.glob('*.py'):ast.parse(path.read_text());checks+=1
print(f'CERTIFICATE PERFORMANCE V2 STATIC: PASS{checks}; same495/owner/driver/timer; corrected common snapshot; no engine')
