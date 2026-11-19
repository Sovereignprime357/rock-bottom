"""Read-only exact stripping, snapshot/workload/pin and bounded source checks."""
from pathlib import Path
import hashlib,json,re,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];PROJECT=HERE/'game3d'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda s:s.replace('\r\n','\n')
manifest=json.loads((HERE/'manifest.json').read_text());pins=json.loads((HERE/'profile-pose-exclusive.pins.json').read_text())
checks=0
def check(ok,label):
    global checks
    assert ok,label
    checks+=1
def strip(s):return re.sub(r'(?ms)^\t*# POSE-COST-BEGIN [^\n]+\n.*?^\t*# POSE-COST-END [^\n]+\n','',norm(s))
reviewed=ROOT/'.build/3d/sustained-population-draft'
archive=ROOT/manifest['archive']
check(sha(archive.read_bytes())==manifest['archive_sha256']==pins['archive_sha256'],'frozen working source archive')
check(sha(json.dumps(manifest['base_files'],sort_keys=True,separators=(',',':')).encode())==manifest['snapshot_sha256'],'complete source inventory digest')
for rel,key in [('profile-frozen.ps1','reviewed_wrapper_sha256'),('profile-frozen.pins.json','reviewed_pins_sha256')]:check(sha((reviewed/rel).read_bytes())==manifest[key],'reviewed workload provenance '+rel)
check(sha((ROOT/'.build/3d/profile-cost-breakdown-draft/profile-cost-breakdown.ps1').read_bytes())==manifest['reviewed_cost_wrapper_sha256'],'original cost wrapper untouched')
with zipfile.ZipFile(archive) as z:
    check(set(z.namelist())=={'game3d/'+rel for rel in manifest['base_files']},'complete archive census')
    for rel,expected in manifest['base_files'].items():
        original=z.read('game3d/'+rel);check(sha(original)==expected,'archive source '+rel)
        if rel not in manifest['overlay']:check((PROJECT/rel).read_bytes()==original,'unchanged candidate '+rel)
    for rel,expected in manifest['stripped_originals'].items():
        source=norm((PROJECT/rel).read_text())
        check(source.count('# POSE-COST-BEGIN ')==source.count('# POSE-COST-END ')==manifest['instrumentation_blocks'][rel],'balanced tagged blocks '+rel)
        original=norm((reviewed/rel).read_text()) if rel.startswith('tests/') else norm(z.read('game3d/'+rel).decode())
        check(strip(source)==original and sha(original.encode())==expected,'every noninstrumented statement/branch/order exact '+rel)
for rel,expected in manifest['overlay'].items():check(sha((PROJECT/rel).read_bytes())==expected==pins['overlay'][rel],'exact overlay '+rel)
check(len(manifest['overlay'])==7,'seven overlays only')
new={'scripts/pose_cost_metrics.gd','tests/test_pose_cost_metrics.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd'}
promoted_uid_sources={'tests/test_world_dust_visual_contract.gd','tests/test_world_feedback_visual_contract.gd','tests/web_dust_visual_probe.gd','tests/web_feedback_visual_probe.gd','tests/world_dust_visual_probe.gd','tests/world_feedback_visual_probe.gd'}
check({p for p in manifest['base_files'] if p.endswith('.gd') and p+'.uid' not in manifest['base_files']}==promoted_uid_sources,'exact six original scripts missing only generated import UIDs')
for p in PROJECT.rglob('*'):
    if not p.is_file() or '.godot' in p.relative_to(PROJECT).parts:continue
    rel=p.relative_to(PROJECT).as_posix()
    if rel in manifest['base_files'] or rel in new:continue
    check(rel.endswith('.gd.uid') and rel[:-4] in new|promoted_uid_sources and re.fullmatch(r'uid://[a-z0-9]+\s*',p.read_text()) is not None,'only explicit generated sidecar '+rel)
for rel in ['tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd']:check((PROJECT/rel).read_bytes()==(reviewed/rel).read_bytes(),'identical sustained workload '+rel)
probe=norm((PROJECT/'tests/full_actor_performance_probe.gd').read_text());a=probe.index('class MeasuredScene:\n');b=probe.index('\nvar game: MeasuredScene')
check(sha((probe[a:b].rstrip()+'\n').encode())==pins['measured_scene_sha256'],'unchanged MeasuredScene')
for text in ['var sample_frames: int = 1080','var warmup_frames: int = 120','_fail("instrumented exclusive pose costs only; overhead included; acceptance ineligible")','pose_cost_before_driver','pose_cost_before_scene','pose_cost_after_scene']:
    check(text in probe,'fixed workload/accounting '+text)
metrics=(PROJECT/'scripts/pose_cost_metrics.gd').read_text()
for forbidden in ['GameState','randf','rand_range','emit_event','set_bone','set_meta','Node.new','load_content','call_deferred','await ']:check(forbidden not in metrics,'no diagnostic authority '+forbidden)
for required in ['MAX_DEPTH := 16','elapsed-int(frame.children)','frames.back().children += elapsed','"outside_tick"','times.duplicate()','counts.duplicate()']:
    check(required in metrics,'bounded exclusive metric '+required)
actor=(PROJECT/'scripts/actor_animation.gd').read_text()
check(actor.count('PoseCost.begin_tick()')==1 and actor.count('PoseCost.finish_tick(')==4,'balanced four valid exits and one entry')
for rel in manifest['overlay']:
    if not rel.endswith('.gd'):continue
    text=(PROJECT/rel).read_text();stack=[];quote=None;escaped=False;comment=False
    for c in text:
        if c=='\n':
            check(quote is None,'single-line string closes '+rel);comment=False;continue
        if comment:continue
        if quote:
            if escaped:escaped=False
            elif c=='\\':escaped=True
            elif c==quote:quote=None
        elif c=='#':comment=True
        elif c in "\"'":quote=c
        elif c in '([{':stack.append(c)
        elif c in ')]}':check(bool(stack) and '([{'.index(stack.pop())==')]}'.index(c),'balanced delimiter '+rel)
    check(not stack and quote is None,'complete lexical source '+rel)
wrapper=(HERE/'profile-pose-exclusive.ps1').read_text()
check(sha(wrapper.encode())==pins['wrapper_sha256'],'wrapper pin')
for required in ['$Diagnostic = $true','$pins.overlay.Count -ne 7','Strip-PoseInstrumentation','$phase.min_live_actors -lt 60','$phase.min_supported_live_actors -lt 60','$phase.min_live_rigs -lt 60','$metric.frames.samples -ne 1080','POSE EXCLUSIVE COST CONTRACT: PASS','CreateNoWindow = $true','WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden','900','$process.Kill($true)']:
    check(required in wrapper,'runner invariant '+required)
check('& git' not in wrapper and '--frames' not in wrapper,'no Git or sample weakening')
print('POSE EXCLUSIVE COST STATIC: PASS;',checks,'pins/strip/accounting/lexical checks; no engine or performance claim.')
