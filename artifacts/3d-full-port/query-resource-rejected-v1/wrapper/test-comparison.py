"""Offline counterexamples only; original diagnostic is a fixture, not a new run."""
from pathlib import Path
import copy,hashlib,importlib.util,json,unittest
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('query_pair',HERE/'compare-pair.py');pair=importlib.util.module_from_spec(spec);spec.loader.exec_module(pair)
fixture=ROOT/'.build/full-port/contact-attribution/effects-contact-v1/evidence/full-actor-performance.json'
assert hashlib.sha256(fixture.read_bytes()).hexdigest()=='9de924885a350569d8263f432f06b92d85bb0e71e0df429935a750a305e38cc8'
REPORT=json.loads(fixture.read_text());PINS=json.loads((HERE/'pins.json').read_text())
def provenance(variant='baseline'):
    p={'variant':variant,'status':'complete','complete_fixed_workload':True,'archive_input_sha256':PINS['archive_sha256'],'archive_sha256':PINS['archive_sha256']}
    for field,pin in [('wrapper_sha256','wrapper_sha256'),('overlay_sha256','overlay'),('query_overlay_sha256','query_overlay'),('measured_scene_sha256','measured_scene_sha256'),('engine_launcher_sha256','engine_launcher_sha256'),('engine_runtime_sha256','engine_runtime_sha256'),('template_sha256','release_template_sha256'),('central_proof_sha256','central_proof'),('source_runtime_pins','runtime_sources')]:p[field]=copy.deepcopy(PINS[pin])
    p['original_source_sha256']=copy.deepcopy(PINS['source']);p['isolated_preset_sha256']='0'*64
    prepared={**PINS['source'],**PINS['overlay']}
    if variant=='query_resource':prepared.update(PINS['query_overlay'])
    prepared['export_presets.cfg']=p['isolated_preset_sha256'];p['prepared_source_sha256']=prepared
    p['exported_source_sha256']=copy.deepcopy(prepared);p['post_native_source_sha256']=copy.deepcopy(prepared)
    p['stages']=[{'stage':name,'exit_code':0,'timeout':False,'arguments':['--qa-full','--diagnostic'] if name=='native' else []} for name in ['version','import','contract','export','native']]
    return p

class Comparison(unittest.TestCase):
    def test_actual_old_report_arithmetic_only(self):
        rows=pair.compare_reports(REPORT,REPORT)
        self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['signed_candidate_minus_baseline']['scene_p95_ms'],0)
        self.assertAlmostEqual(rows[0]['baseline']['actor_cpu_ms_per_call'],3.65002420916721)
        self.assertTrue(REPORT['failures']) # Its original16ms failures remain.
    def test_phase_and_population_refusals(self):
        mutations=[lambda x:x.update(fixed_measured_frames=1079),lambda x:x['phases'][0].update(frames=1079),lambda x:x['phases'][0].update(min_live_actors=59),lambda x:x['phases'][0]['workload_frames'][150].update(alive=59),lambda x:x['phases'][1].update(id='wrong'),lambda x:x['phases'][0]['workload_frames'].pop(),lambda x:x['phases'][0]['workload_frames'][125].update(frame=4)]
        for mutation in mutations:
            changed=copy.deepcopy(REPORT);mutation(changed)
            with self.assertRaises(ValueError):pair.validate_report(changed)
    def test_lifecycle_and_nonperformance_refusals(self):
        for mutation in [lambda x:x['failures'].append('core_day: arrest'),lambda x:x['phases'][0]['lifecycle_timeline'][0].update(discontinuities=['arrest']),lambda x:x['phases'][0].update(excluded_lifecycle_displacement_m=1),lambda x:x.update(acceptance=True)]:
            changed=copy.deepcopy(REPORT);mutation(changed)
            with self.assertRaises(ValueError):pair.validate_report(changed)
    def test_timing_and_query_denominators(self):
        mutations=[lambda x:x['phases'][0].update(active_ms=0),lambda x:x['phases'][0]['stage_calls']['actors'].update(total=0),lambda x:x['phases'][0]['stage_calls']['actors'].update(cpu_ms_per_call=1),lambda x:x['phases'][0]['scene_cpu_ms'].update(p95=float('nan')),lambda x:x['phases'][0]['scene_scope_totals_ms'].update(runtime_actor_motion=-1),lambda x:x['phases'][0].update(physics_queries=1)]
        for mutation in mutations:
            changed=copy.deepcopy(REPORT);mutation(changed)
            with self.assertRaises(ValueError):pair.validate_report(changed)
    def test_metric_identity_change(self):
        for key,value in [('msaa',0),('resolution',[960,540]),('fps_cap',30),('timing_boundary','different'),('gpu','different')]:
            changed=copy.deepcopy(REPORT);changed[key]=value
            with self.assertRaises(ValueError):pair.compare_reports(REPORT,changed)
    def test_cannot_relabel_actual_threshold_failure(self):
        changed=copy.deepcopy(REPORT);changed['failures']=[];changed['acceptance']=True
        with self.assertRaises(ValueError):pair.validate_report(changed)
    def test_two_exact_source_variants(self):
        for variant in pair.VARIANTS:pair.validate_sources(provenance(variant),PINS,variant)
    def test_index_or_unlisted_overlay_refused(self):
        p=provenance('query_resource');p['prepared_source_sha256']['scripts/exact_vertex_indexer.gd']='1'*64
        with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'query_resource')
    def test_source_or_native_mutation_refused(self):
        for section in ['original_source_sha256','prepared_source_sha256','exported_source_sha256','post_native_source_sha256']:
            p=provenance();p[section]['scripts/full_runtime.gd']='1'*64
            with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'baseline')
    def test_known_uid_only(self):
        p=provenance();p['exported_source_sha256']['tests/sustained_actor_driver.gd.uid']='1'*64;p['post_native_source_sha256']=copy.deepcopy(p['exported_source_sha256'])
        pair.validate_sources(p,PINS,'baseline')
        p['exported_source_sha256']['scripts/other.gd.uid']='2'*64;p['post_native_source_sha256']=copy.deepcopy(p['exported_source_sha256'])
        with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'baseline')
    def test_child_failure_timeout_and_shortcut_refused(self):
        for mutation in [lambda p:p['stages'][-1].update(timeout=True),lambda p:p['stages'][-1].update(exit_code=1),lambda p:p['stages'][-1]['arguments'].append('--frames=12'),lambda p:p['stages'][-1]['arguments'].remove('--qa-full'),lambda p:p.update(complete_fixed_workload=False)]:
            p=provenance();mutation(p)
            with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'baseline')
    def test_swapped_variant_or_workload_pin_refused(self):
        p=provenance()
        with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'query_resource')
        p['overlay_sha256']['tests/sustained_actor_driver.gd']='1'*64
        with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'baseline')

if __name__=='__main__':unittest.main(verbosity=2)
