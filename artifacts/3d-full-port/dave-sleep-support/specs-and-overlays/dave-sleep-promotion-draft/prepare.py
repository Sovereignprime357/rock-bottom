"""Explicit isolated delivery composition; no live source, engine or Git writes."""
from pathlib import Path
import copy,hashlib,json
H=Path(__file__).resolve().parent;R=H.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def raw(ref):return (R/ref).read_bytes()
def put(ref,b):
 p=H/ref;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
def js(v):return (json.dumps(v,indent=2,ensure_ascii=False)+'\n').encode()
def edit(b,a,c):
 a=a.encode();c=c.encode();assert b.count(a)==1,a;return b.replace(a,c,1)

v2ref='reports/3d-parity-metadata/input-pins-metadata-v2.json';v3ref='reports/3d-parity-metadata/input-pins-metadata-v3.json'
v2bytes=raw(v2ref);assert sha(v2bytes)=='54904feef56e31ebd967d818bf946dc8b6ba1c728986c13d671ef6cac433f276'
v2=json.loads(v2bytes);assert len(v2['hashes'])==247
for ref,digest in v2['hashes'].items():assert sha(raw(ref))==digest,ref
owner='game3d/scripts/actor_animation.gd';old=v2['hashes'][owner]
assert old=='3317d7a885e96a288828914b9289c4668ed89fb268bee300a3b92d938397603d'
artroot=R/'.build/3d/dave-sleep-art-draft';artbytes=(artroot/'MANIFEST.json').read_bytes()
assert sha(artbytes)=='6bd74a9df548ded1633cf83f122f4aaafc344b743042bf42f058c80ecb04224d'
art=json.loads(artbytes);artmap={row['target']:row for row in art['overlays']};assert len(artmap)==3
for ref,row in artmap.items():
 b=(artroot/row['candidate']).read_bytes();assert sha(b)==row['sha256'];assert b'\r' not in b
 if row['baseSha256'] is not None:assert sha(raw(ref))==row['baseSha256'];put('originals/'+ref,raw(ref))
 else:assert not (R/ref).exists()
 put('candidate/'+ref,b)
new=artmap[owner]['sha256'];assert new=='d35234cd61c3a489f459da420b26d00118b66be1497ab83d500a95a46306b45e'
v3=copy.deepcopy(v2);v3['scope']='Explicit metadata-v3 Dave-only sleep support; exactly one existing Animator pin changes; no evidence/status promotion';v3['hashes'][owner]=new
v3['previousPins']={'path':v2ref,'sha256':sha(v2bytes)};put('candidate/'+v3ref,js(v3))
manifestref='game3d/data/parity_manifest.json';manifestbytes=raw(manifestref);manifest=json.loads(manifestbytes)
assert sha(manifestbytes)=='a24f663ad71cda9dc9879caca7d7df9a9fc89bfc88e998f462d40725902eaa42'
links=[]
for group in ['features','handlers']:
 for row in manifest[group]:
  for field in ['implementation','tests','integration']:
   refs=[p for p in row[field] if p.split('#')[0]==owner]
   if refs:links.append({'group':group,'id':row['id'],'field':field,'references':refs})
ids={r['id'] for r in links if r['group']=='features'}
evidence=[r['id'] for f in manifest['features'] if f['id'] in ids for r in f.get('evidenceRefs',[])]
proofs=['.build/full-port/dave-sleep-validation/focused-v1/focused-result.json','.build/full-port/dave-sleep-validation/focused-v1/test_dave_sleep_support.stdout.log','.build/full-port/dave-sleep-validation/native-v1/staging.json','.build/full-port/dave-sleep-validation/native-v1/evidence/dave-walkthrough.json']
proofrows=[{'path':p,'sha256':sha(raw(p))} for p in proofs]
assert json.loads(raw(proofs[0]))['engine_tests_pass'] is True
assert b'DAVE SLEEP SUPPORT: PASS; 2028 checks; 3/3 groups; 384 sleep samples' in raw(proofs[1])
assert json.loads(raw(proofs[3]))['acceptance'] is True
record={'schema':1,'revision':'metadata-v3','selectedExplicitly':True,'previousPins':v3['previousPins'],'newPins':{'path':v3ref,'sha256':sha(js(v3))},'pinCensus':247,'changes':[{'path':owner,'oldSha256':old,'finalSha256':new,'testedCandidateSha256':new,'checkoutNormalization':None,'reason':'Dave-only sleep visual lift and original pillow under-cheek support; awake/rest/other identities and all gameplay remain unchanged.'}],'deliveryTests':{p:r['sha256'] for p,r in artmap.items() if p!=owner},'testedPacket':{'path':'.build/3d/dave-sleep-art-draft/MANIFEST.json','sha256':sha(artbytes)},'unchangedManifest':{'path':manifestref,'sha256':sha(manifestbytes),'handlers':585,'features':32,'existingEvidenceRefs':96,'statusesChanged':0,'referencesChanged':0},'affectedDependencyLinks':links,'linkedExistingEvidenceIds':evidence,'historicalEvidenceBoundary':'Dependency information only. Original raw bytes, qualifiers, outcomes and source provenance remain unchanged; no older evidence automatically validates this Animator.','separateFocusedNativeEvidence':proofrows,'webAtPreparation':'Pending root browser outcome; no Web acceptance inferred here.','gateRevision':{'engineSuites':87,'sourceChecks':45,'total':132,'newEngineSuite':'test_dave_sleep_support.gd','actualNewFullRunnerClaim':False},'completeGate':'Must refuse all 617 current obligations.','excluded':['weighted indexing','query-resource optimization','eave','gameplay changes','engine shutdown acceptance','performance acceptance','full-port completion']}
put('candidate/reports/3d-parity-metadata/revisions/metadata-v3.json',js(record))
put('candidate/SPEC-3D-PARITY-METADATA-V3.md',(H/'SPEC-DRAFT.md').read_bytes())
rosterref='SPEC-3D-CHARACTER-ROSTER.md';assert rosterref not in v2['hashes']
roster=raw(rosterref);assert sha(roster)=='55a87e8e681fbaa59da5772a6ca4e623b43fa499d27c9ba89fd27c7a673c5640'
put('originals/'+rosterref,roster);put('candidate/'+rosterref,roster+(H/'ROSTER-AMENDMENT.md').read_bytes())
toolref='tools/parity-metadata.mjs';tool=raw(toolref);assert sha(tool)=='1d4293917ee5c23c9cb4c92bc84d60829a9a3d7c4c43d80273ac3ec5a12051fd'
added=",'metadata-v3':'reports/3d-parity-metadata/input-pins-metadata-v3.json'"
nexttool=edit(tool,"'metadata-v2':'reports/3d-parity-metadata/input-pins-metadata-v2.json'});","'metadata-v2':'reports/3d-parity-metadata/input-pins-metadata-v2.json'"+added+"});")
put('originals/'+toolref,tool);put('candidate/'+toolref,nexttool);put('validation/'+toolref,nexttool)
for name in ['parity-source-proof.mjs','parity-metadata-test.mjs','parity-metadata-gate.mjs','parity-metadata-migrate.mjs']:put('validation/tools/'+name,raw('tools/'+name))
runnerref='game3d/tests/run-gates.ps1';runner=raw(runnerref);assert sha(runner)=='a1e50f8a3eeff81851893bbbfb022525d51f9e61e5ae6e01496014a45fac0f0b'
assert runner.count(b'--pins=metadata-v2')==3
nextrunner=runner.replace(b'--pins=metadata-v2',b'--pins=metadata-v3')
nextrunner=edit(nextrunner,"'test_dave_walkthrough_contract.gd')) {","'test_dave_walkthrough_contract.gd', 'test_dave_sleep_support.gd', 'reference_actor_animation_sleep_original.gd')) {")
gateline="Invoke-Gate -Name 'dave-sleep-support' -GodotArgs @('--script', 'res://tests/test_dave_sleep_support.gd', '--quit-after', '12000') -PassPattern 'DAVE SLEEP SUPPORT: PASS'\r\n"
nextrunner=edit(nextrunner,'foreach ($entry in @(\r\n',gateline+'foreach ($entry in @(\r\n')
nextrunner=edit(nextrunner,'131/131 PASS (import clean; 86 engine suites and 45 source/parity checks;','132/132 PASS (import clean; 87 engine suites and 45 source/parity checks;')
put('originals/'+runnerref,runner);put('candidate/'+runnerref,nextrunner)
targets=list(artmap)+[rosterref,'SPEC-3D-PARITY-METADATA-V3.md',v3ref,'reports/3d-parity-metadata/revisions/metadata-v3.json',toolref,runnerref]
delivery={'schema':1,'scope':'Isolated nine-file Dave sleep promotion plan; root applies exact bytes after final visual decision','files':[{'path':p,'oldSha256':sha(raw(p)) if (R/p).exists() else None,'sha256':sha((H/'candidate'/p).read_bytes())} for p in targets],'onlyChangedExistingPin':owner,'manifestUnchanged':sha(manifestbytes),'engineRunByThisPacket':False,'sourceWrites':False,'gitRun':False}
put('DELIVERY.json',js(delivery));print('DAVE SLEEP PROMOTION PREPARE: PASS; 9 isolated files; one existing pin; no live writes')
