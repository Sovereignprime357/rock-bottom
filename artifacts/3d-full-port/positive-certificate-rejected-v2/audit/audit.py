"""Offline frozen-pair audit; never profiles, repins or mutates original evidence."""
from pathlib import Path
import hashlib,importlib.util,json,math,re,zipfile
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
PAIR=ROOT/'.build/full-port/positive-certificate-performance-v2'
WRAPPER=ROOT/'.build/3d/positive-certificate-performance-v2-draft'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def require(ok,label):
 if not ok:raise ValueError(label)
def close(a,b,label):require(math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),label)
inputs={}
def pin(p,mode='copy'):
 rel=p.relative_to(ROOT).as_posix();inputs[rel]={'sha256':sha(p),'bytes':p.stat().st_size,'retention':mode};return inputs[rel]['sha256']
def main():
 require(not (HERE/'FINDINGS.json').exists(),'Retain prior audit output')
 spec=importlib.util.spec_from_file_location('frozen_certificate_pair',WRAPPER/'compare-pair.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
 pins=load(WRAPPER/'pins.json');manifest=load(WRAPPER/'MANIFEST.json')
 require(pin(WRAPPER/'MANIFEST.json')=='02d955d69c45c3991bc03333db053d6680f2d060008c3a8659a531e700a69eb7','exact held wrapper manifest')
 for rel,row in manifest['files'].items():require(pin(WRAPPER/rel)==row['sha256'],'wrapper file '+rel)
 for kind in ['candidate_proof','snapshot_proof']:
  for rel,digest in pins[kind].items():require(pin(ROOT/rel)==digest,'source proof '+rel)
 with zipfile.ZipFile(WRAPPER/'source.zip') as z:
  require(len(z.namelist())==495 and set(z.namelist())=={'game3d/'+p for p in pins['source']},'frozen495 archive census')
  for rel,digest in pins['source'].items():require(hashlib.sha256(z.read('game3d/'+rel)).hexdigest()==digest,'archive source '+rel)
 comparison_path=PAIR/'certificate-pair-v2-comparison.json';comparison=load(comparison_path);pin(comparison_path)
 require(comparison['performance_acceptance'] is False and comparison['promotion_authorized'] is False,'strict no promotion')
 reports={};facts={};pngs=[]
 for variant in ['baseline','positive_certificate']:
  run=PAIR/('certificate-pair-v2-'+variant);report_path=run/'evidence/full-actor-performance.json';prov_path=run/'evidence/provenance.json'
  report=load(report_path);prov=load(prov_path)
  require(pin(report_path)==comparison['report_inputs'][variant]['report']==prov['report_sha256'],'raw report pin '+variant)
  require(pin(prov_path)==comparison['report_inputs'][variant]['provenance'],'raw provenance '+variant)
  require(sha(WRAPPER/'pins.json')==prov['pins_sha256'],'pair pins '+variant)
  helper.validate_sources(prov,pins,variant);helper.validate_report(report)
  retained={p.relative_to(run/'source/game3d').as_posix():sha(p) for p in (run/'source/game3d').rglob('*') if p.is_file() and '.godot' not in p.parts}
  require(retained==prov['post_native_source_sha256'],'actual retained source inventory '+variant)
  require(pin(run/'source.zip','hash_only')==pins['archive_sha256'],'same duplicate archive '+variant)
  require(pin(run/'RockBottomSustained.exe','hash_only')==prov['executable_sha256'],'actual release executable '+variant)
  for stage in prov['stages']:
   require(stage['exit_code']==0 and stage['timeout'] is False,'actual stage success '+variant+'/'+stage['stage'])
   if stage.get('godot_log'):
    require(pin(Path(stage['godot_log']))==stage['godot_log_sha256'],'raw stage log pin')
  for log in [*run.glob('*.log'),run/'evidence/native.log']:
   body=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',log.read_text(errors='replace'));pin(log)
   require(not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|Parse Error):',body,re.M),'engine error '+str(log))
  snapshot=(run/'snapshot_contract.stdout.log').read_text()
  require('PERFORMANCE PHASE SNAPSHOT: PASS; 27 checks; 5/5 groups; original_alias_reproduced=true' in snapshot,'actual snapshot completion '+variant)
  if variant=='positive_certificate':require('POSITIVE CLEARANCE RETENTION: PASS; 174 checks; 6/6 groups; focused_saved_queries=2' in (run/'retention_contract.stdout.log').read_text(),'actual positive contract')
  shots=sorted((run/'evidence').glob('*.png'))
  require({p.name for p in shots}=={'core_day_initial.png','core_day_end.png','trainyard_night_initial.png','trainyard_night_end.png'},'four original capture names '+variant)
  for png in shots:
   with Image.open(png) as im:require(im.size==(1280,720) and im.format=='PNG','original capture dimensions')
   pngs.append({'source':png.relative_to(ROOT).as_posix(),'sha256':pin(png),'dimensions':[1280,720]})
  phase_rows=[]
  for phase in report['phases']:
   frames=phase['workload_frames'];measured=[r for r in frames if r['part']=='measured'];warmup=[r for r in frames if r['part']=='warmup']
   require(len(frames)==1200 and len(warmup)==120 and len(measured)==1080,'complete own phase rows')
   require([r['frame'] for r in warmup]==list(range(120)) and [r['frame'] for r in measured]==list(range(1080)),'own phase indices')
   require(all(r['alive']>=60 and r['supported']>=60 and r['rigged']>=60 for r in frames),'all1200 own population receipts')
   require(all(not r['discontinuities'] for r in phase['lifecycle_timeline']) and phase['excluded_lifecycle_displacement_m']==0,'no lifecycle shortcut')
   active=sum(r['active_ms'] for r in measured);close(active,phase['active_ms']['total'],'own rows reproduce active time')
   # Source loop's1e-6ms completion epsilon; records here have no hitpause gaps.
   calls=sum(math.ceil(r['active_ms']/(1000/60)-1e-6) for r in measured)
   require(calls==phase['stage_calls']['actors']['total'],'own rows reproduce source actor-stage calls')
   seconds=active/1000;scopes=phase['scene_scope_totals_ms'];before=phase['navigation_before'];after=phase['navigation_after']
   close(phase['physics_queries'],phase['driver_physics_queries']+phase['physics_queries_excluding_driver'],'query partition')
   phase_rows.append({'id':phase['id'],'warmup_rows':len(warmup),'measured_rows':len(measured),'min_row_live':min(r['alive'] for r in frames),'min_row_supported':min(r['supported'] for r in frames),'min_row_rigged':min(r['rigged'] for r in frames),'first_source_position':frames[0]['source_position'],'frame_rows_sha256':hashlib.sha256(json.dumps(frames,separators=(',',':')).encode()).hexdigest(),'decision_receipts':len(phase['driver_decisions']),'scene_p95_ms':phase['scene_cpu_ms']['p95'],'driver_p95_ms':phase['driver_cpu_ms']['p95'],'driver_mean_ms':phase['driver_cpu_total_ms']/1080,'actor_ms_per_stage_call':phase['stage_calls']['actors']['cpu_total_ms']/calls,'clearance_ms_per_stage_call':scopes['runtime_actor_clearance']/calls,'clearance_ms_per_active_second':scopes['runtime_actor_clearance']/seconds,'motion_ms_per_stage_call':scopes['runtime_actor_motion']/calls,'active_seconds':seconds,'actor_stage_calls':calls,'scene_queries':phase['physics_queries_excluding_driver'],'scene_queries_per_stage_call':phase['physics_queries_excluding_driver']/calls,'scene_queries_per_active_second':phase['physics_queries_excluding_driver']/seconds,'driver_queries':phase['driver_physics_queries'],'inclusive_placement_overlaps':after['placement_overlap_queries']-before['placement_overlap_queries'],'inclusive_positive_hits':after['placement_cache_hits']-before['placement_cache_hits'],'held_engine_process_p95_ms':phase['engine_process_monitor_window_max_ms']['p95']})
  require(report['phases'][0]['workload_frames']!=report['phases'][1]['workload_frames'],'day/night frame arrays are distinct')
  require(report['phases'][0]['driver_decisions']!=report['phases'][1]['driver_decisions'],'day/night driver arrays are distinct')
  reports[variant]=report;facts[variant]={'phases':phase_rows,'stage_names':[s['stage'] for s in prov['stages']],'source_files_after_native':len(retained),'acceptance':report['acceptance'],'failures':report['failures']}
 require(helper.compare_reports(reports['baseline'],reports['positive_certificate'])==comparison['rows'],'comparison values independently regenerated from raw totals')
 delta=[]
 for a,b in zip(facts['baseline']['phases'],facts['positive_certificate']['phases']):
  keys=['scene_p95_ms','actor_ms_per_stage_call','clearance_ms_per_stage_call','clearance_ms_per_active_second','motion_ms_per_stage_call','scene_queries','scene_queries_per_stage_call','scene_queries_per_active_second','inclusive_placement_overlaps','inclusive_positive_hits','active_seconds','actor_stage_calls']
  delta.append({'id':a['id'],'candidate_minus_baseline':{k:b[k]-a[k] for k in keys},'relative_percent':{k:(b[k]/a[k]-1)*100 for k in keys}})
 result={'schema':1,'decision':'reject_positive_certificate_promotion','scope':'frozen495 d1b9b87 resident archive only; not latest working source','archive_sha256':pins['archive_sha256'],'comparison_sha256':sha(comparison_path),'variants':facts,'delta':delta,'original_pngs':pngs,'corrected_phase_snapshots_verified':True,'all_source_and_log_pins_verified':True,'performance_acceptance':False,'promotion_authorized':False,'causal_improvement_claim':False,'retry_recommended':False,'engine_run_by_auditor':False,'production_modified':False}
 (HERE/'INPUTS.json').write_text(json.dumps({'schema':1,'inputs':inputs},indent=2)+'\n',encoding='utf-8',newline='\n')
 (HERE/'FINDINGS.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('CERTIFICATE FROZEN-PAIR AUDIT: verified distinct phases/4800 frame receipts/source+logs; reject promotion; inputs',len(inputs))
 for row in delta:print(row['id'],json.dumps(row['relative_percent']))
if __name__=='__main__':main()
