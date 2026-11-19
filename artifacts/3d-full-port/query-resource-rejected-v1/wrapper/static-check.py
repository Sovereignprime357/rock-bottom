"""Read-only checks for the bounded pair; no engine, Git or production mutation."""
from pathlib import Path
import ast,hashlib,json,re,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
count=0
def check(ok,label):
 global count
 count+=1
 if not ok:raise AssertionError(label)
p=json.loads((HERE/'pins.json').read_text())
check(sha((HERE/'source.zip').read_bytes())==p['archive_sha256']=='ede8f5bf42ed80f4227d3d1d17b69f89c30eab65722932557ed3334c26a46ee2','current resident archive identity')
with zipfile.ZipFile(HERE/'source.zip') as z:
 check(set(z.namelist())=={'game3d/'+x for x in p['source']} and len(p['source'])==495,'exact495 archive census')
 for rel,digest in p['source'].items():check(sha(z.read('game3d/'+rel))==digest,'source '+rel)
 source_probe=z.read('game3d/tests/full_actor_performance_probe.gd').decode().replace('\r\n','\n')
check('scripts/exact_vertex_indexer.gd' not in p['source'],'no indexed helper in baseline')
for rel,digest in p['overlay'].items():
 check(sha((HERE/rel).read_bytes())==digest,'fixed workload '+rel)
 check((HERE/rel).read_bytes()==(ROOT/'.build/3d/indexed-performance-draft'/rel).read_bytes(),'unchanged reviewed workload '+rel)
check(len(p['overlay'])==3,'exact3 workload overlays')
proof=json.loads((ROOT/'.build/3d/query-reuse-resident-v1/provenance.json').read_text())
check(p['query_overlay']=={k.removeprefix('game3d/'):v for k,v in proof['overlays'].items()} and len(p['query_overlay'])==5,'exact5 centrally tested overlays')
for rel,digest in p['query_overlay'].items():
 check(sha((HERE/'query'/rel).read_bytes())==digest,'query candidate '+rel)
 check(sha((ROOT/'.build/3d/query-reuse-resident-v1/game3d'/rel).read_bytes())==digest,'central tested source '+rel)
for rel,digest in p['central_proof'].items():check(sha((ROOT/rel).read_bytes())==digest,'central proof '+rel)
for rel,digest in p['runtime_sources'].items():check(p['source'][rel]==digest,'explicit runtime/helper '+rel)
for key,path in [('engine_launcher_sha256','.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'),('engine_runtime_sha256','.tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe'),('release_template_sha256','.tools/templates/windows_release_x86_64.exe')]:check(sha((ROOT/path).read_bytes())==p[key],'official runtime '+key)
for name,key in [('profile-one.ps1','wrapper_sha256'),('run-paired.ps1','paired_wrapper_sha256'),('compare-pair.py','comparison_helper_sha256')]:check(sha((HERE/name).read_bytes())==p[key],'executable helper '+name)
for name,transform_path in [('profile-one.ps1','launcher-transform.json'),('run-paired.ps1','paired-transform.json')]:
 transform=json.loads((HERE/transform_path).read_text());text=(HERE/name).read_text()
 for edit in reversed(transform['edits']):check(text.count(edit['new'])==1,'unique transform '+name);text=text.replace(edit['new'],edit['old'])
 check(sha(text.encode())==transform['normalized_original_sha256'],'exact normalized launcher reversal '+name)
 check(sha((ROOT/transform['original_path']).read_bytes())==transform['original_sha256'],'original reviewed launcher held '+name)
 check(text==(ROOT/transform['original_path']).read_text(),'same original statements '+name)
probe=(HERE/'tests/full_actor_performance_probe.gd').read_text()
def measured(s):return s[s.index('class MeasuredScene:\n'):s.index('\nvar game: MeasuredScene')].rstrip()+'\n'
check(measured(probe)==measured(source_probe),'archived MeasuredScene identical')
check(sha(measured(probe).encode())==p['measured_scene_sha256'],'exact measured boundary pin')
check('var sample_frames: int = 1080' in probe and 'var warmup_frames: int = 120' in probe,'full unchanged workload')
one=(HERE/'profile-one.ps1').read_text();paired=(HERE/'run-paired.ps1').read_text()
check("[ValidateSet('baseline','query_resource')]" in one,'bounded variants')
check('$indexNames' not in one and 'index_overlay' not in one and 'exact_vertex_indexer' not in one,'no index-specific composition')
check('$Diagnostic = $true' in one and 'Sustained60 population requirement failed.' in one and 'Non-performance workload failure' in one,'strict population/failure policy')
check('post_native_source_sha256' in one and one.count('Assert-SourceUnchanged')==4,'checks after import/export/native')
check('900' in one and '$process.Kill($true)' in one and 'WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden' in one,'same bounded owned hidden child')
check('--frames' not in one and '& git ' not in one,'no frame shortcut or Git')
check("@('baseline','query_resource')" in paired and 'comparison_helper_sha256' in paired,'serial pair and pinned pure helper')
for path in HERE.glob('*.py'):ast.parse(path.read_text());count+=1
print(f'QUERY RESOURCE PERFORMANCE STATIC: PASS{count};495 source/3 unchanged workload/5 validated overlays; no engine')
