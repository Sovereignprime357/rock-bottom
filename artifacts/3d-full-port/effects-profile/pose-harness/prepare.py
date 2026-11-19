"""Freeze current source and add diagnostic blocks only. Never runs Godot or Git."""
from pathlib import Path
import hashlib,json,re,zipfile,sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
REVIEWED=ROOT/'.build/3d/sustained-population-draft'
PROJECT=HERE/'game3d'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda s:s.replace('\r\n','\n')

def block(label,code,indent=''):
    return f'{indent}# POSE-COST-BEGIN {label}\n'+code+f'{indent}# POSE-COST-END {label}\n'
def before(s,needle,label,code):
    assert s.count(needle)==1,(label,s.count(needle))
    indent=needle[:len(needle)-len(needle.lstrip('\t'))]
    return s.replace(needle,block(label,code,indent)+needle)
def after(s,needle,label,code):
    assert s.count(needle)==1,(label,s.count(needle))
    indent=needle[:len(needle)-len(needle.lstrip('\t'))]
    return s.replace(needle,needle+block(label,code,indent))
def function(s,name,operation):
    found=re.search(r'(?m)^(?:static )?func '+re.escape(name)+r'\(',s);assert found,name
    start=found.start(); end=re.search(r'(?m)^(?:static )?func ',s[found.end():])
    stop=found.end()+end.start() if end else len(s)
    return s[:start]+operation(s[start:stop])+s[stop:]
def strip(s):
    return re.sub(r'(?ms)^\t*# POSE-COST-BEGIN [^\n]+\n.*?^\t*# POSE-COST-END [^\n]+\n','',norm(s))
def append_function(s,label,code):
    tail=len(s)-len(s.rstrip('\n'))
    return s[:-tail]+ '\n'+block(label,code,'\t')+s[-tail+1:] if tail else s+block(label,code,'\t')
def write(rel,text):
    p=PROJECT/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf8',newline='\n')

base={}; payload={}
if '--resume-from-archive' in sys.argv:
    assert not (HERE/'manifest.json').exists(),'Refuse replacing completed candidate'
    with zipfile.ZipFile(HERE/'source.zip') as archive:
        for name in archive.namelist():
            assert name.startswith('game3d/') and '..' not in Path(name).parts
            rel=name[len('game3d/'):];payload[rel]=archive.read(name);base[rel]=sha(payload[rel])
else:
    assert not PROJECT.exists(),'Refuse existing isolated candidate'
    assert not (HERE/'source.zip').exists(),'Refuse existing snapshot'
    for p in sorted((ROOT/'game3d').rglob('*')):
        if not p.is_file() or '.godot' in p.relative_to(ROOT/'game3d').parts:continue
        rel=p.relative_to(ROOT/'game3d').as_posix(); data=p.read_bytes()
        base[rel]=sha(data);payload[rel]=data
    for rel,digest in base.items(): assert sha((ROOT/'game3d'/rel).read_bytes())==digest,'Source changed while snapshotting: '+rel
    current={p.relative_to(ROOT/'game3d').as_posix() for p in (ROOT/'game3d').rglob('*') if p.is_file() and '.godot' not in p.relative_to(ROOT/'game3d').parts}
    assert current==set(base),'Source census changed while snapshotting'
    with zipfile.ZipFile(HERE/'source.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for rel,data in payload.items():
            info=zipfile.ZipInfo('game3d/'+rel,(2026,11,19,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,data)
for rel,data in payload.items():
    dest=PROJECT/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
snapshot=sha(json.dumps(base,sort_keys=True,separators=(',',':')).encode())
originals={rel:norm(payload[rel].decode()) for rel in ['scripts/actor_animation.gd','scripts/character_roster.gd']}
for rel in ['tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd']:
    dest=PROJECT/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((REVIEWED/rel).read_bytes())
originals['tests/full_actor_performance_probe.gd']=norm((REVIEWED/'tests/full_actor_performance_probe.gd').read_text())
write('scripts/pose_cost_metrics.gd',(HERE/'pose_cost_metrics.gd').read_text())
write('tests/test_pose_cost_metrics.gd',(HERE/'test_pose_cost_metrics.gd').read_text())

actor=before(originals['scripts/actor_animation.gd'],'const Roster = preload("res://scripts/character_roster.gd")\n','metrics-import','const PoseCost = preload("res://scripts/pose_cost_metrics.gd")\n')
def tick(s):
    s=after(s,'\tif art == null or not art.has_meta("roster_rig") or not is_finite(delta) or delta <= 0.0: return\n','tick-enter','\tPoseCost.begin_tick()\n')
    s=after(s,'\t\trig.hidden_pose_skips += 1\n','tick-hidden','\t\tPoseCost.finish_tick("hidden")\n')
    condition='if quality == 2 and not returning and may_skip and int(rig.frame)%3 != 0: return'
    s=before(s,'\t'+condition+'\n','tick-distant','\t'+condition.replace(': return',': PoseCost.finish_tick("distant")')+'\n')
    s=after(s,'\t\trig.pose_updates += 1\n','tick-inert','\t\tPoseCost.finish_tick("inert")\n')
    return after(s,'\n\trig.pose_updates += 1\n','tick-finish','\tPoseCost.finish_tick("posed")\n')
actor=function(actor,'tick',tick)
def simple_helper(s,key,finish):
    signature=s[:s.index('\n')+1]
    s=after(s,signature,key+'-start','\tvar pose_cost_started: int = Time.get_ticks_usec()\n')
    return append_function(s,key+'-finish',finish)
actor=function(actor,'_reset_working_pose',lambda s:simple_helper(s,'reset','\tPoseCost.helper("reset",pose_cost_started,poses.size())\n'))
def apply(s):
    s=after(s,s[:s.index('\n')+1],'apply-start','\tvar pose_cost_started: int = Time.get_ticks_usec()\n\tvar pose_cost_writes: int = rig.bone_writes\n')
    return append_function(s,'apply-finish','\tPoseCost.helper("apply",pose_cost_started,poses.size(),int(rig.bone_writes)-pose_cost_writes)\n')
actor=function(actor,'_apply_bones',apply)
actor=function(actor,'_human_contacts',lambda s:simple_helper(s,'contacts','\tPoseCost.helper("contacts",pose_cost_started)\n'))
write('scripts/actor_animation.gd',actor)

roster=before(originals['scripts/character_roster.gd'],'const Legacy = preload("res://scripts/character_art.gd")\n','metrics-import','const PoseCost = preload("res://scripts/pose_cost_metrics.gd")\n')
def attachments(s):
    s=after(s,s[:s.index('\n')+1],'attachments-start','\tvar pose_cost_started: int = Time.get_ticks_usec()\n\tvar pose_cost_writes: int = rig.attachment_writes\n\tvar pose_cost_queries: int = rig.attachment_queries\n')
    return append_function(s,'attachments-finish','\tPoseCost.helper("attachments",pose_cost_started,0,int(rig.attachment_writes)-pose_cost_writes,int(rig.attachment_queries)-pose_cost_queries)\n')
roster=function(roster,'_sync_attachments',attachments)
write('scripts/character_roster.gd',roster)

probe=before(originals['tests/full_actor_performance_probe.gd'],'const Content = preload("res://scripts/content_catalog.gd")\n','metrics-import','const PoseCost = preload("res://scripts/pose_cost_metrics.gd")\n')
probe=before(probe,'\tif grade_disabled or pose_input_disabled:\n','diagnostic-only','\tdiagnostic = true\n\t_fail("instrumented exclusive pose costs only; overhead included; acceptance ineligible")\n')
probe=after(probe,'\tvar scopes: Dictionary = {}\n','pose-cost-series','\tvar pose_cost_series: Dictionary = {}\n')
needle='\t\tvar before_p: Dictionary = game.runtime.p; var before_s: Dictionary = game.runtime.s\n\t\t_drive()\n\t\tawait game.frame_sampled\n\t\tcpu.append(float(game.sample_cpu_us)/1000.0)\n'
assert probe.count(needle)==1
probe=probe.replace(needle,'\t\tvar before_p: Dictionary = game.runtime.p; var before_s: Dictionary = game.runtime.s\n'+block('before-driver','\t\tvar pose_cost_before_driver: Dictionary = PoseCost.snapshot()\n','\t\t')+'\t\t_drive()\n'+block('after-driver','\t\tvar pose_cost_before_scene: Dictionary = PoseCost.snapshot()\n','\t\t')+'\t\tawait game.frame_sampled\n'+block('after-scene','\t\tvar pose_cost_after_scene: Dictionary = PoseCost.snapshot()\n\t\t_pose_cost_sample(pose_cost_series,pose_cost_before_driver,pose_cost_before_scene,"driver",frame)\n\t\t_pose_cost_sample(pose_cost_series,pose_cost_before_scene,pose_cost_after_scene,"scene",frame)\n','\t\t')+'\t\tcpu.append(float(game.sample_cpu_us)/1000.0)\n')
probe=before(probe,'\t\t"scene_scopes_ms":scope_stats,"scene_scope_totals_ms":scope_totals,\n','phase-report','\t\t"pose_cost_breakdown":_pose_cost_report(pose_cost_series),\n')
helpers='''func _pose_cost_sample(series: Dictionary,before: Dictionary,after: Dictionary,part: String,frame: int) -> void:
\tif before.depth != 0 or after.depth != 0 or before.stack_size != 0 or after.stack_size != 0: _fail("pose-cost stack imbalance at measured boundary")
\tfor key: String in ["overflow","imbalance","negative_span","unknown_key"]:
\t\tif int(after.counts[key]) != 0: _fail("pose-cost invalid accounting: "+key)
\tfor group: String in ["us","counts"]:
\t\tvar current: Dictionary = {}
\t\tfor key: String in after[group]: current[key] = int(after[group][key])-int(before[group][key])
\t\tvar label: String = part+"_"+group
\t\tif not series.has(label): series[label] = {}
\t\t_append_frame_series(series[label],current,frame,0.001 if group == "us" else 1.0)
func _pose_cost_report(series: Dictionary) -> Dictionary:
\tvar result: Dictionary = {}
\tfor group: String in series:
\t\tvar rows: Dictionary = {}
\t\tfor key: String in series[group]:
\t\t\tvar samples: PackedFloat64Array = series[group][key]
\t\t\trows[key] = {"frames":_stats(samples,false),"total":_sum(samples),"units":"ms" if group.ends_with("_us") else "count"}
\t\tresult[group.trim_suffix("_us")+"_ms" if group.ends_with("_us") else group] = rows
\treturn result

'''
probe=before(probe,'func _append_frame_series(series: Dictionary,current: Dictionary,frame: int,scale: float = 1.0) -> void:\n','report-helpers',helpers)
probe=before(probe,'\t\t"workload_version":"sustained60_normal_input_v2_draft","comparison_requires_identical_driver":true,"fixed_measured_frames":1080,"fixed_warmup_frames":120,\n','report-metadata','\t\t"pose_cost_diagnostic":true,"pose_cost_overhead":"Instrumentation and report sampling included; frame catch-up can change. No overhead subtraction or performance acceptance.",\n\t\t"pose_cost_scopes":"Exclusive rig intervals remove directly nested child tick spans; root-inclusive, all-rig-inclusive and child-inclusive overlap. Reset/apply/attachments/contacts helper spans are mutually exclusive and split inside/outside tick. Helper/caller clocks have bookkeeping residual. Never sum percentiles or infer recoverable time.",\n')
write('tests/full_actor_performance_probe.gd',probe)

for rel,original in originals.items():assert strip((PROJECT/rel).read_text())==original,rel
pins=json.loads((REVIEWED/'profile-frozen.pins.json').read_text())
def measured(s):
    a=s.index('class MeasuredScene:\n');b=s.index('\nvar game: MeasuredScene')
    return sha((s[a:b].rstrip()+'\n').encode())
assert measured(probe)==measured(norm(payload['tests/full_actor_performance_probe.gd'].decode()))==pins['measured_scene_sha256']
overlay=['scripts/actor_animation.gd','scripts/character_roster.gd','scripts/pose_cost_metrics.gd','tests/test_pose_cost_metrics.gd','tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd']
manifest={'schema':1,'status':'DRAFT ONLY; no engine; instrumentation only; no performance acceptance','snapshot_kind':'current working production with promoted effects, not a Git revision','snapshot_sha256':snapshot,'revision':'working-'+snapshot[:12],'game3d_tree':'not_a_git_tree','archive':(HERE/'source.zip').relative_to(ROOT).as_posix(),'archive_sha256':sha((HERE/'source.zip').read_bytes()),'reviewed_wrapper_sha256':sha((REVIEWED/'profile-frozen.ps1').read_bytes()),'reviewed_pins_sha256':sha((REVIEWED/'profile-frozen.pins.json').read_bytes()),'reviewed_cost_wrapper_sha256':sha((ROOT/'.build/3d/profile-cost-breakdown-draft/profile-cost-breakdown.ps1').read_bytes()),'measured_scene_sha256':pins['measured_scene_sha256'],'base_files':base,'overlay':{rel:sha((PROJECT/rel).read_bytes()) for rel in overlay},'stripped_originals':{rel:sha(s.encode()) for rel,s in originals.items()},'instrumentation_blocks':{rel:len(re.findall(r'(?m)^\t*# POSE-COST-BEGIN ',(PROJECT/rel).read_text())) for rel in originals}}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('POSE COST PREPARE: PASS;',len(base),'frozen production files;7 explicit overlays;3 complete strip proofs; unchanged MeasuredScene/driver.')
