"""Explicit observer successor; static file preparation only."""
from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OLD=ROOT/'.build/3d/positive-certificate-performance-draft'
SNAP=ROOT/'.build/3d/performance-phase-snapshot-draft'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert not (HERE/'pins.json').exists(),'Refuse implicit repin'
assert sha((OLD/'MANIFEST.json').read_bytes())=='e7a04463f4324dd1ca76bf70bdaffda8282f58da8cadff970c69c889461a7d19'
assert sha((SNAP/'MANIFEST.json').read_bytes())=='5f0bf42e75cf19c5c399b099d7591acb5871108d0822c9c1b2b730143ba21c9f'
oldpins=json.loads((OLD/'pins.json').read_text());spins=json.loads((SNAP/'PINS.json').read_text())
transforms=[]
def derived(name,edits):
 text=(OLD/name).read_text();original=text;applied=[]
 for before,after in edits:
  assert before!=after and text.count(before)>0,(name,before[:80])
  expected=text.count(before);positions=[];cursor=0
  while True:
   at=text.find(before,cursor)
   if at<0:break
   text=text[:at]+after+text[at+len(before):];positions.append(at);cursor=at+len(after)
  assert len(positions)==expected
  applied.append({'old':before,'new':after,'positions':positions})
 reverse=text
 for edit in reversed(applied):
  for at in reversed(edit['positions']):
   assert reverse[at:at+len(edit['new'])]==edit['new']
   reverse=reverse[:at]+edit['old']+reverse[at+len(edit['new']):]
 assert reverse==original
 (HERE/name).write_text(text,encoding='utf-8',newline='\n')
 transforms.append({'file':name,'original_path':str((OLD/name).relative_to(ROOT)).replace('\\','/'),'original_sha256':sha((OLD/name).read_bytes()),'edits':applied})
driver_line="    if ($contract -notmatch 'SUSTAINED60 DRIVER CONTRACT: PASS') { throw 'Detached contract did not complete all required groups.' }"
snapshot_stage="""
    $snapshot = Invoke-IsolatedChild 'snapshot_contract' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'snapshot_contract.godot.log'),'--script','res://tests/test_performance_phase_snapshot.gd')
    if ($snapshot -notmatch '(?m)^PERFORMANCE PHASE SNAPSHOT: PASS; [1-9][0-9]* checks; 5/5 groups; original_alias_reproduced=true; no performance claim\\r?$') { throw 'Snapshot contract did not complete all five groups and original alias witness.' }
    $provenance.snapshot_contract_complete = $true"""
proof_check="""foreach ($relative in $pins.snapshot_proof.Keys) {
    $path = Assert-Within $repoRoot (Join-Path $repoRoot $relative)
    if ((Get-Sha $path) -ne $pins.snapshot_proof[$relative]) { throw "Common observer proof changed: $relative" }
}
"""
derived('profile-one.ps1',[
 ("'.build/full-port/positive-certificate-performance'","'.build/full-port/positive-certificate-performance-v2'"),
 ("'tests/test_sustained_actor_driver.gd')","'tests/test_sustained_actor_driver.gd','tests/test_performance_phase_snapshot.gd')"),
 ("'tests/test_sustained_actor_driver.gd.uid')","'tests/test_sustained_actor_driver.gd.uid','tests/test_performance_phase_snapshot.gd.uid')"),
 ("$pins.overlay.Count -ne 3","$pins.overlay.Count -ne 4"),
 ("exactly the three approved tests","the three workload files and snapshot regression"),
 ('candidate_proof_sha256=$pins.candidate_proof;','candidate_proof_sha256=$pins.candidate_proof; snapshot_proof_sha256=$pins.snapshot_proof;'),
 ('foreach ($relative in $pins.candidate_proof.Keys)',proof_check+'foreach ($relative in $pins.candidate_proof.Keys)'),
 (driver_line,driver_line+snapshot_stage)])
derived('run-paired.ps1',[("'.build/full-port/positive-certificate-performance'","'.build/full-port/positive-certificate-performance-v2'"),('POSITIVE CERTIFICATE PERFORMANCE PAIR:','POSITIVE CERTIFICATE PERFORMANCE V2 PAIR:')])
proof_tuple="('candidate_proof_sha256','candidate_proof'),"
stages="['version','import','contract']+(['retention_contract'] if variant=='positive_certificate' else [])"
receipt_line="        if variant=='positive_certificate':\n            receipt=(run/'retention_contract.stdout.log').read_text(errors='replace')"
new_receipt="""        snapshot_receipt=(run/'snapshot_contract.stdout.log').read_text(errors='replace')
        require(re.search(r'^PERFORMANCE PHASE SNAPSHOT: PASS; [1-9][0-9]* checks; 5/5 groups; original_alias_reproduced=true; no performance claim\\r?$',snapshot_receipt,re.M) is not None,'retained actual common snapshot contract receipt')
        if variant=='positive_certificate':
            receipt=(run/'retention_contract.stdout.log').read_text(errors='replace')"""
derived('compare-pair.py',[
 ("PARENT=ROOT/'.build/full-port/positive-certificate-performance'","PARENT=ROOT/'.build/full-port/positive-certificate-performance-v2'"),
 (proof_tuple,proof_tuple+"('snapshot_proof_sha256','snapshot_proof'),"),
 ("'tests/test_sustained_actor_driver.gd.uid'}","'tests/test_sustained_actor_driver.gd.uid','tests/test_performance_phase_snapshot.gd.uid'}"),
 (stages,"['version','import','contract','snapshot_contract']+(['retention_contract'] if variant=='positive_certificate' else [])"),
 ("    require([x['stage'] for x in stages]==expected_stages,'child stage census')","    require([x['stage'] for x in stages]==expected_stages,'child stage census')\n    require(provenance.get('snapshot_contract_complete') is True,'five-group actual observer snapshot contract completed')"),
 (receipt_line,new_receipt),('POSITIVE CERTIFICATE PAIR:','POSITIVE CERTIFICATE V2 PAIR:')])
addition="""    def test_common_snapshot_stage_required_in_both_variants(self):
        for variant in pair.VARIANTS:
            for mutation in [lambda p:p['stages'].pop(3),lambda p:p['stages'][3].update(exit_code=1),lambda p:p['stages'][3].update(timeout=True),lambda p:p.pop('snapshot_contract_complete'),lambda p:p.update(snapshot_contract_complete=False)]:
                p=provenance(variant);mutation(p)
                with self.assertRaises(ValueError):pair.validate_sources(p,PINS,variant)
    def test_original_shared_alias_probe_is_not_successor(self):
        p=provenance();p['prepared_source_sha256']['tests/full_actor_performance_probe.gd']='5013ed6ed7bee55213bc9f84060d9a5fbb68e44ddc9cf95fe3526fd4bcf58bef'
        with self.assertRaises(ValueError):pair.validate_sources(p,PINS,'baseline')

"""
derived('test-comparison.py',[
 (proof_tuple,proof_tuple+"('snapshot_proof_sha256','snapshot_proof'),"),
 (stages,"['version','import','contract','snapshot_contract']+(['retention_contract'] if variant=='positive_certificate' else [])"),
 ("    if variant=='positive_certificate':p['retention_contract_complete']=True","    p['snapshot_contract_complete']=True\n    if variant=='positive_certificate':p['retention_contract_complete']=True"),
 ("lambda p:p['stages'].pop(3),lambda p:p['stages'][3].update(exit_code=1),lambda p:p['stages'][3].update(timeout=True),lambda p:p.pop('retention_contract_complete')","lambda p:p['stages'].pop(4),lambda p:p['stages'][4].update(exit_code=1),lambda p:p['stages'][4].update(timeout=True),lambda p:p.pop('retention_contract_complete')"),
 ("if __name__=='__main__':",addition+"if __name__=='__main__':")])
(HERE/'transforms.json').write_text(json.dumps(transforms,indent=2)+'\n',encoding='utf-8',newline='\n')
shutil.copyfile(OLD/'source.zip',HERE/'source.zip')
overlay={}
for rel,digest in oldpins['overlay'].items():
 raw=(OLD/rel).read_bytes();assert sha(raw)==digest
 if rel=='tests/full_actor_performance_probe.gd':raw=(SNAP/'candidate/game3d'/rel).read_bytes();assert sha(raw)==spins['candidate_probe_sha256']
 dest=HERE/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw);overlay[rel]=sha(raw)
rel='tests/test_performance_phase_snapshot.gd';raw=(SNAP/'candidate/game3d'/rel).read_bytes();assert sha(raw)==spins['regression_sha256'];(HERE/rel).write_bytes(raw);overlay[rel]=sha(raw)
for rel,digest in oldpins['certificate_overlay'].items():
 raw=(OLD/'certificate'/rel).read_bytes();assert sha(raw)==digest
 dest=HERE/'certificate'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
proof={str((SNAP/name).relative_to(ROOT)).replace('\\','/'):sha((SNAP/name).read_bytes()) for name in ['MANIFEST.json','PINS.json','SPEC-DRAFT.md','EDITS.json']}
pins={**oldpins,'overlay':overlay,'snapshot_proof':proof,'wrapper_sha256':sha((HERE/'profile-one.ps1').read_bytes()),'paired_wrapper_sha256':sha((HERE/'run-paired.ps1').read_bytes()),'comparison_helper_sha256':sha((HERE/'compare-pair.py').read_bytes()),'reviewed_wrapper_sha256':oldpins['wrapper_sha256'],'reviewed_paired_wrapper_sha256':oldpins['paired_wrapper_sha256'],'note':'Explicit report-only common observer successor. Same driver/MeasuredScene, snapshot regression on both variants before export; no old day timeline relabeling; source and focused correctness await root.'}
(HERE/'pins.json').write_text(json.dumps(pins,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CERTIFICATE PERFORMANCE V2 PREPARE: PASS; common report snapshot only; no engine')
