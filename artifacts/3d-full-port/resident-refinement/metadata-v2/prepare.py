"""Stage only this isolated metadata revision; never promote or invoke Git/engines."""
from pathlib import Path
import copy
import hashlib
import json

DRAFT = Path(__file__).resolve().parent
ROOT = DRAFT.parents[2]
RESIDENT = ROOT / '.build/3d/resident-art-integration'
def sha(data): return hashlib.sha256(data).hexdigest()
def raw(ref): return (ROOT / ref).read_bytes()
def put(ref, data):
    target = DRAFT / ref
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
def js(value): return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()
def edit(data, old, new):
    a, b = old.encode(), new.encode()
    assert data.count(a) == 1, old
    return data.replace(a, b)

v1_path = 'reports/3d-parity-metadata/input-pins-metadata-v1.json'
v2_path = 'reports/3d-parity-metadata/input-pins-metadata-v2.json'
v1_bytes = raw(v1_path)
v1 = json.loads(v1_bytes)
assert len(v1['hashes']) == 247
old = {
 'game3d/scripts/cast_profiles.gd':'4bc71adc2c9d2e89ba6d207ec8bc7904d7655251cb74d9c30f3e966f1ea6d3cd',
 'game3d/tests/test_character_roster.gd':'75c992e163dd39756483b57ce6bb52dbfca8a8a6594bcc022515c733685c0c5c',
 'game3d/tests/test_full_scene.gd':'355cdc4d93e0c045f8693bc1c0785f1a673e566391437c135e5dd6287d3b4378',
}
final = {
 'game3d/scripts/cast_profiles.gd':'40d04a6b282c3710d9babeba2f8314f5838ed449f3f77ca15fc5590b124d3668',
 'game3d/tests/test_character_roster.gd':'f85737b38e96d24cc4c0557eb9500f6f728116a99210b0cca6d9e11246119b6c',
 'game3d/tests/test_full_scene.gd':'574073964fdcfd17e4e62d392c6c359e3eea0400551f07fadadcadf5f466831e',
}
composition_bytes = (RESIDENT / 'overlays.json').read_bytes()
composition = json.loads(composition_bytes)
assert len(composition) == 5
reasons = {
 'game3d/scripts/cast_profiles.gd': 'Approved Dave wake presentation and original folded laundry cloth; no weighted indexing or sleep-ground correction.',
 'game3d/tests/test_character_roster.gd': 'Approved folded laundry geometry regressions; explicit CRLF-to-LF checkout normalization only after the tested candidate.',
 'game3d/tests/test_full_scene.gd': 'Approved actual Dave wake/current-state presentation regression; source asleep authority stays unchanged.',
}
records = []
original_sources = {
 'game3d/scripts/cast_profiles.gd':'.build/3d/campaign-continuation-integration/game3d/scripts/cast_profiles.gd',
 'game3d/tests/test_character_roster.gd':'.build/3d/campaign-continuation-integration/game3d/tests/test_character_roster.gd',
 'game3d/tests/test_full_scene.gd':'.build/3d/all11-2c32-v1/game3d/tests/test_full_scene.gd',
}
for ref, expected in old.items():
    baseline = raw(original_sources[ref])
    assert v1['hashes'][ref] == expected and sha(baseline) == expected, ref
    assert sha(raw(ref)) in [expected, final[ref]], ref
    put('originals/' + ref, baseline)
    tested = (RESIDENT / ref).read_bytes()
    assert sha(tested) == composition[ref], ref
    normalized = tested.replace(b'\r\n', b'\n') if ref.endswith('test_character_roster.gd') else tested
    assert sha(normalized) == final[ref], ref
    if ref.endswith('test_character_roster.gd'):
        assert tested.count(b'\r\n') == 1052 and tested.count(b'\n') == 1052
        assert b'\r' not in normalized and normalized.count(b'\n') == 1052
    put('composed-inputs/' + ref, normalized)
    records.append({'path':ref, 'oldSha256':expected, 'originalRawCopy':original_sources[ref], 'testedCandidateSha256':sha(tested),
      'finalSha256':sha(normalized), 'reason':reasons[ref],
      'checkoutNormalization': {'kind':'CRLF_to_LF','lines':1052,'allOtherBytesUnchanged':True}
       if normalized != tested else None})
for ref, expected in composition.items():
    assert sha((RESIDENT / ref).read_bytes()) == expected, ref
unchanged_owner = 'game3d/scripts/character_roster.gd'
assert sha(raw(unchanged_owner)) == v1['hashes'][unchanged_owner]
v2 = copy.deepcopy(v1)
v2['scope'] = 'Explicit metadata-v2 approved Dave wake and laundry composition; exactly three implementation/test pins changed; no evidence/status promotion'
v2['hashes'].update(final)
v2['previousPins'] = {'path':v1_path, 'sha256':sha(v1_bytes)}
put('candidate/' + v2_path, js(v2))

manifest_ref = 'game3d/data/parity_manifest.json'
manifest_bytes = raw(manifest_ref)
manifest = json.loads(manifest_bytes)
evidence = json.loads(raw('reports/3d-parity-metadata/evidence-index.json'))
affected = []
for ref in old:
    links = []
    for group in ['features', 'handlers']:
        for row in manifest[group]:
            for field in ['implementation','tests','integration']:
                exact = [r for r in row[field] if r.split('#')[0] == ref]
                if exact: links.append({'group':group,'id':row['id'],'field':field,'references':exact})
    supported = [f['id'] for f in evidence['features'] if any(r.split('#')[0] == ref for r in f.get('supporting_tests',[]))]
    feature_ids = sorted({r['id'] for r in links if r['group'] == 'features'} | set(supported))
    affected.append({'path':ref,'directManifestLinks':links,'evidenceIndexSupportingFeatures':supported,
      'linkedExistingEvidenceIds':[r['id'] for f in manifest['features'] if f['id'] in feature_ids for r in f.get('evidenceRefs',[])],
      'boundary':'These are dependency links, not new validation. Historical artifacts retain original bytes, qualifications, outcomes and reported source provenance; they do not automatically certify the revised implementation.'})
review_paths = ['.build/3d/resident-acceptance-review/REVIEW.md','.build/3d/resident-acceptance-review/evidence.json']
review = [{'path':p,'sha256':sha(raw(p))} for p in review_paths]
assert review[0]['sha256'] == 'e3e32f704148cf280bdf1c851eb5387bdd3d3a75a01c339cd35691305fbf3f29'
assert review[1]['sha256'] == 'a249c73e70515b91be419c74c0de42472ac38d035a1687de87adfa3c002dcd03'
record = {
 'schema':1, 'revision':'metadata-v2','selectedExplicitly':True,'previousPins':v2['previousPins'],
 'newPins':{'path':v2_path,'sha256':sha(js(v2))},'pinCensus':247,'changes':records,
 'approvedResidentComposition':{'path':'.build/3d/resident-art-integration/overlays.json','sha256':sha(composition_bytes),'testedInputs':composition},
 'unchangedOwner':{'path':unchanged_owner,'sha256':v1['hashes'][unchanged_owner]},
 'unchangedManifest':{'path':manifest_ref,'sha256':sha(manifest_bytes),'handlers':585,'features':32,'existingEvidenceRefs':96,'statusesChanged':0,'referencesChanged':0},
 'affectedDependencyLinks':affected,
 'separateAcceptedResidentReview':{'rawInputs':review,'scope':'Native/Web Dave wake and dialogue plus folded laundry contents only. The review preserves its own capture-only Web/no-shutdown and unaccepted-performance boundaries. It is not appended to the 96-reference ledger.', 'indexOnlyLedgerChanged':False},
 'excluded':['weighted indexing','court eave','new Dave sleep-ground pose','ground-contact acceptance','engine-shutdown acceptance','performance acceptance','full-port completion'],
 'groundFollowup':'Later passive ground diagnostics are separate: body/pillow clipping was observed, whole-body hover was not established. No new pose or speculative ground hash enters this revision.',
 'gateRevision':{'engineSuites':86,'sourceChecks':45,'total':131,'newEngineSuite':'test_dave_walkthrough_contract.gd','actualEngineExecutionClaim':False},
 'completeGate':'Must continue to refuse all 617 current obligations.',
}
put('candidate/reports/3d-parity-metadata/revisions/metadata-v2.json', js(record))
put('candidate/SPEC-3D-PARITY-METADATA-V2.md', (DRAFT / 'SPEC-DRAFT.md').read_bytes())

tool_ref = 'tools/parity-metadata.mjs'
tool = raw(tool_ref)
changed = edit(tool,
 "export const PIN_REVISIONS=Object.freeze({'metadata-v1':'reports/3d-parity-metadata/input-pins-metadata-v1.json'});",
 "export const PIN_REVISIONS=Object.freeze({'metadata-v1':'reports/3d-parity-metadata/input-pins-metadata-v1.json','metadata-v2':'reports/3d-parity-metadata/input-pins-metadata-v2.json'});")
changed = edit(changed,'Exactly one explicit --pins=metadata-v1 selection is required.','Exactly one explicit --pins=<named revision> selection is required.')
put('originals/' + tool_ref, tool)
put('candidate/' + tool_ref, changed)
put('validation/' + tool_ref, changed)
for name in ['parity-source-proof.mjs','parity-metadata-test.mjs','parity-metadata-gate.mjs','parity-metadata-migrate.mjs']:
    put('validation/tools/' + name, raw('tools/' + name))

runner_ref = 'game3d/tests/run-gates.ps1'
runner = raw(runner_ref)
assert runner.count(b'--pins=metadata-v1') == 3
next_runner = runner.replace(b'--pins=metadata-v1', b'--pins=metadata-v2')
next_runner = edit(next_runner,"'test_incident_presentation.gd')) {", "'test_incident_presentation.gd', 'test_dave_walkthrough_contract.gd')) {")
new_gate = "Invoke-Gate -Name 'dave-walkthrough-contract' -GodotArgs @('--script', 'res://tests/test_dave_walkthrough_contract.gd', '--quit-after', '6000') -PassPattern 'DAVE WALKTHROUGH CONTRACT: PASS'"
next_runner = edit(next_runner,'foreach ($entry in @(\r\n',new_gate+'\r\nforeach ($entry in @(\r\n')
next_runner = edit(next_runner,'130/130 PASS (import clean; 85 engine suites and 45 source/parity checks;', '131/131 PASS (import clean; 86 engine suites and 45 source/parity checks;')
put('originals/' + runner_ref, runner)
put('candidate/' + runner_ref, next_runner)

promotion = ['SPEC-3D-PARITY-METADATA-V2.md',v2_path,'reports/3d-parity-metadata/revisions/metadata-v2.json',tool_ref,runner_ref]
delivery = {'schema':1,'scope':'Five-file metadata/runner overlay only; root separately composes approved five-file resident packet.',
 'files':[{'path':p,'sha256':sha((DRAFT/'candidate'/p).read_bytes()),'oldSha256':sha(raw(p)) if (ROOT/p).exists() else None} for p in promotion],
 'residentFinalInputs':final,'liveWrites':False,'engineRun':False,'gitRun':False}
put('DELIVERY.json',js(delivery))
print('RESIDENT METADATA PREPARE: PASS (5 isolated delivery files; exactly 3 changed raw pins; 1052-line LF normalization)')
