"""Strict offline pair reconciliation; reads raw evidence, never profiles or repins."""
from pathlib import Path
import argparse,hashlib,json,math,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
PARENT=ROOT/'.build/full-port/query-resource-performance'
PHASES=('core_day','trainyard_night')
VARIANTS=('baseline','query_resource')
ALLOWED_FAILURES={f'{p}: scene CPU or held engine-process monitor p95 exceeds16ms' for p in PHASES}
SETTINGS=('engine','platform','processor','gpu','renderer','resolution','msaa','vsync','fps_cap','source_corpus','timing_boundary','workload_version','driver_timing','engine_monitor_semantics')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def require(value,label):
    if not value:raise ValueError(label)
def number(value,label,positive=False):
    require(type(value) in (int,float) and math.isfinite(value) and (value>0 if positive else value>=0),label)
    return value
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def stats(value,label):
    require(value.get('samples')==1080,label+' samples')
    return {key:number(value[key],label+' '+key) for key in ('p50','p95','p99','max')}
def close(a,b,label):require(math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-9),label)

def validate_report(report):
    require(report.get('schema')==1 and report.get('diagnostic') is True,'report schema/diagnostic')
    require(report.get('workload_version')=='sustained60_normal_input_v2_draft','workload version')
    require(report.get('fixed_measured_frames')==1080 and report.get('fixed_warmup_frames')==120,'fixed workload')
    require(report.get('comparison_requires_identical_driver') is True,'driver identity contract')
    require(type(report.get('failures')) is list and all(x in ALLOWED_FAILURES for x in report['failures']),'non-performance failure')
    require(len(set(report['failures']))==len(report['failures']),'duplicate failure labels')
    require(report.get('platform')=='Windows' and report.get('renderer')=='gl_compatibility' and report.get('resolution')==[1280,720] and report.get('msaa')==4 and report.get('fps_cap')==60 and report.get('vsync') is False,'fixed native render settings')
    require(type(report.get('acceptance')) is bool and report['acceptance']==(not report['failures']),'original acceptance/failures disagree')
    require([x.get('id') for x in report.get('phases',[])]==list(PHASES),'phase census/order')
    results=[]
    for p in report['phases']:
        name=p['id'];require(p.get('frames')==1080 and p.get('warmup_frames')==120,name+' phase frames')
        scene_stats=stats(p['scene_cpu_ms'],name+' scene')
        monitor_stats=stats(p['engine_process_monitor_window_max_ms'],name+' held engine-process monitor')
        performance_failure=scene_stats['p95']>16.0 or monitor_stats['p95']>16.0
        require((name+': scene CPU or held engine-process monitor p95 exceeds16ms' in report['failures'])==performance_failure,name+' original16ms threshold/failure agreement')
        for key in ('min_live_actors','min_supported_live_actors','min_live_rigs'):
            require(number(p[key],name+' '+key)>=60,name+' population')
        frames=p['workload_frames'];require(len(frames)==1200,name+' actual frame receipts')
        for part,count in [('warmup',120),('measured',1080)]:
            rows=[x for x in frames if x['part']==part]
            require([x['frame'] for x in rows]==list(range(count)),name+' '+part+' receipt indices')
            require(all(x['alive']>=60 and x['supported']>=60 and x['rigged']>=60 for x in rows),name+' per-frame population')
        require(all(not x['discontinuities'] for x in p['lifecycle_timeline']),name+' lifecycle discontinuity')
        require(number(p['excluded_lifecycle_displacement_m'],name+' excluded relocation')==0,name+' excluded relocation')
        require(type(p.get('active_ms')) is dict,name+' admitted-time record')
        stats(p['active_ms']['frames'],name+' admitted-time frames')
        active=number(p['active_ms']['total'],name+' admitted time',True)/1000
        elapsed=number(p['elapsed_ms'],name+' wall time',True)
        actor=p['stage_calls']['actors'];calls=number(actor['total'],name+' actor calls',True)
        require(float(calls).is_integer(),name+' integral actor calls')
        actor_ms=number(actor['cpu_total_ms'],name+' actor CPU')
        close(actor['cpu_ms_per_call'],actor_ms/calls,name+' actor per-call reconciliation')
        close(actor['cpu_ms_per_active_second'],actor_ms/active,name+' actor per-second reconciliation')
        scene_queries=number(p['physics_queries_excluding_driver'],name+' scene queries')
        driver_queries=number(p['driver_physics_queries'],name+' driver queries')
        close(number(p['physics_queries'],name+' total queries'),scene_queries+driver_queries,name+' query partition')
        totals=p['scene_scope_totals_ms'];scopes={}
        for key in ('runtime_actor_clearance','runtime_actor_motion','runtime_actor_pose'):
            value=number(totals[key],name+' '+key)
            scopes[key]={'cpu_total_ms':value,'cpu_ms_per_actor_stage_call':value/calls,'cpu_ms_per_active_second':value/active}
        models=number(totals['models'],name+' model sync')
        driver_ms=number(p['driver_cpu_total_ms'],name+' driver CPU')
        results.append({'id':name,'scene_cpu_ms':stats(p['scene_cpu_ms'],name+' scene'),'driver_cpu_ms':stats(p['driver_cpu_ms'],name+' driver'),
          'active_seconds':active,'elapsed_ms':elapsed,'actor_stage_calls':calls,'actor_calls_per_render_frame':calls/1080,'actor_calls_per_active_second':calls/active,
          'actor_cpu_total_ms':actor_ms,'actor_cpu_ms_per_call':actor_ms/calls,'actor_cpu_ms_per_active_second':actor_ms/active,'actor_subscopes':scopes,
          'models_cpu_ms_per_render_frame':models/1080,'driver_cpu_ms_per_render_frame':driver_ms/1080,'driver_cpu_ms_per_active_second':driver_ms/active,
          'scene_physics_queries':scene_queries,'scene_physics_queries_per_active_second':scene_queries/active,'driver_physics_queries':driver_queries,
          'min_live':p['min_live_actors'],'min_supported':p['min_supported_live_actors'],'min_rigged':p['min_live_rigs'],
          'driver_work':p['driver_work'],'player_walked_m':p['player_walked_m'],'source_stage_counts':p['stage_calls']})
    return results

def validate_sources(provenance,pins,variant):
    require(provenance.get('variant')==variant and provenance.get('status')=='complete' and provenance.get('complete_fixed_workload') is True,'complete variant provenance')
    require(provenance.get('archive_input_sha256')==pins['archive_sha256']==provenance.get('archive_sha256'),'archive identity')
    for field,pin in [('wrapper_sha256','wrapper_sha256'),('overlay_sha256','overlay'),('query_overlay_sha256','query_overlay'),('measured_scene_sha256','measured_scene_sha256'),('engine_launcher_sha256','engine_launcher_sha256'),('engine_runtime_sha256','engine_runtime_sha256'),('template_sha256','release_template_sha256'),('central_proof_sha256','central_proof'),('source_runtime_pins','runtime_sources')]:
        require(provenance.get(field)==pins[pin],'provenance pin '+field)
    require(provenance.get('original_source_sha256')==pins['source'],'original495 source inventory')
    expected={**pins['source'],**pins['overlay']}
    if variant=='query_resource':expected.update(pins['query_overlay'])
    expected['export_presets.cfg']=provenance['isolated_preset_sha256']
    require(re.fullmatch('[0-9a-f]{64}',expected['export_presets.cfg']) is not None,'preset hash')
    require(provenance.get('prepared_source_sha256')==expected,'only declared prepared overlays')
    exported=provenance['exported_source_sha256'];post=provenance['post_native_source_sha256']
    require(all(exported.get(k)==v for k,v in expected.items()),'prepared source unchanged through import')
    uids={'tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid'}
    if variant=='query_resource':uids|={'tests/fixtures/query_resource_candidate.gd.uid','tests/fixtures/query_resource_reference.gd.uid'}
    require(set(exported)-set(expected)<=uids,'only exact generated UID files')
    require(post==exported,'source unchanged through export and native')
    stages=provenance['stages'];require([x['stage'] for x in stages]==['version','import','contract','export','native'],'child stage census')
    require(all(x['exit_code']==0 and x['timeout'] is False for x in stages),'child exit/timeout')
    args=stages[-1]['arguments'];require('--qa-full' in args and '--diagnostic' in args and not any(x.startswith('--frames') for x in args),'unchanged native invocation')

def compare_reports(a,b):
    require(all(a.get(k)==b.get(k) for k in SETTINGS),'paired environment/metric/source identities')
    rows_a=validate_report(a);rows_b=validate_report(b);rows=[]
    scalar_keys=('active_seconds','elapsed_ms','actor_stage_calls','actor_calls_per_render_frame','actor_calls_per_active_second','actor_cpu_ms_per_call','actor_cpu_ms_per_active_second','models_cpu_ms_per_render_frame','driver_cpu_ms_per_render_frame','driver_cpu_ms_per_active_second','scene_physics_queries','scene_physics_queries_per_active_second','driver_physics_queries')
    for left,right in zip(rows_a,rows_b):
        delta={k:right[k]-left[k] for k in scalar_keys}
        delta.update({'scene_p95_ms':right['scene_cpu_ms']['p95']-left['scene_cpu_ms']['p95'],'driver_p95_ms':right['driver_cpu_ms']['p95']-left['driver_cpu_ms']['p95']})
        delta['actor_subscopes']={k:{s:right['actor_subscopes'][k][s]-left['actor_subscopes'][k][s] for s in left['actor_subscopes'][k]} for k in left['actor_subscopes']}
        rows.append({'id':left['id'],'baseline':left,'query_resource':right,'signed_candidate_minus_baseline':delta})
    return rows

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--run-name',required=True);args=parser.parse_args()
    require(re.fullmatch('[a-zA-Z0-9][a-zA-Z0-9_-]{0,46}',args.run_name) is not None,'safe run name')
    pins=load(HERE/'pins.json');require(sha(Path(__file__))==pins['comparison_helper_sha256'],'comparison helper pin')
    output=PARENT/(args.run_name+'-comparison.json');require(not output.exists(),'refuse existing comparison')
    reports={};provenances={};hashes={}
    for variant in VARIANTS:
        run=PARENT/(args.run_name+'-'+variant);evidence=run/'evidence';report_path=evidence/'full-actor-performance.json'
        report=load(report_path);provenance=load(evidence/'provenance.json')
        require(sha(report_path)==provenance['report_sha256'],'raw report pin '+variant)
        require(sha(HERE/'pins.json')==provenance['pins_sha256'],'original pair pins '+variant)
        require(sha(run/'source.zip')==pins['archive_sha256'],'retained source archive '+variant)
        validate_sources(provenance,pins,variant)
        source=run/'source/game3d'
        inventory={str(p.relative_to(source)).replace('\\','/'):sha(p) for p in source.rglob('*') if p.is_file() and '.godot' not in p.relative_to(source).parts}
        require(inventory==provenance['post_native_source_sha256'],'current retained source bytes '+variant)
        require(sha(run/'RockBottomSustained.exe')==provenance['executable_sha256'],'actual release executable '+variant)
        for path in [*run.glob('*.log'),evidence/'native.log']:
            log=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',path.read_text(errors='replace'))
            require(not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|Parse Error):',log,re.M),'engine error in '+str(path))
        reports[variant]=report;provenances[variant]=provenance;hashes[variant]={'report':sha(report_path),'provenance':sha(evidence/'provenance.json')}
    rows=compare_reports(reports['baseline'],reports['query_resource'])
    result={'schema':1,'comparison_complete':True,'diagnostic':True,'performance_acceptance':False,'promotion_authorized':False,'gpu_or_web_claim':False,
      'archive_sha256':pins['archive_sha256'],'workload_hashes':pins['overlay'],'query_overlay_hashes':pins['query_overlay'],'measured_scene_sha256':pins['measured_scene_sha256'],
      'pins_sha256':sha(HERE/'pins.json'),'report_inputs':hashes,'original_acceptance':{k:v['acceptance'] for k,v in reports.items()},'original_failures':{k:v['failures'] for k,v in reports.items()},'rows':rows,
      'limits':'One identical-driver native pair. Normal input/physics timing may diverge; per-call and active-second denominators are disclosed. Scope timings overlap and p95 values must not be added. Original16ms failures retained; no causal percentage or promotion claim.'}
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('x',encoding='utf-8',newline='\n') as stream:json.dump(result,stream,indent=2,allow_nan=False);stream.write('\n')
    print('QUERY RESOURCE PAIR: complete diagnostic; '+str(output))
if __name__=='__main__':main()
