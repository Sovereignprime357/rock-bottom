import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {selectedPins,readInputs,validate,build,load,LIVE_MANIFEST} from './validation/tools/parity-metadata.mjs';
import {runContract} from './validation/tools/parity-metadata-test.mjs';
import {runGate} from './validation/tools/parity-metadata-gate.mjs';
import {runMigration} from './validation/tools/parity-metadata-migrate.mjs';

const draft=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(draft,'../../..');
const raw=ref=>fs.readFileSync(path.join(root,ref));
const local=ref=>fs.readFileSync(path.join(draft,ref));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const v1ref='reports/3d-parity-metadata/input-pins-metadata-v1.json';
const v2ref='reports/3d-parity-metadata/input-pins-metadata-v2.json';
const v1=JSON.parse(raw(v1ref));
const v2=JSON.parse(local('candidate/'+v2ref));
const record=JSON.parse(local('candidate/reports/3d-parity-metadata/revisions/metadata-v2.json'));
const changed=record.changes.map(r=>r.path);
const baseMap=new Map(changed.map(ref=>[ref,local('originals/'+ref)]));
const finalMap=new Map(changed.map(ref=>[ref,local('composed-inputs/'+ref)]));
const makeReader=map=>ref=>ref===v2ref?local('candidate/'+v2ref):(map.get(ref)??raw(ref));
const oldReader=makeReader(baseMap), newReader=makeReader(finalMap);
const logs=[];
const logger={log:value=>logs.push(String(value)),error:value=>logs.push(String(value))};
let checks=0;
const check=(condition,message)=>{checks++;assert.ok(condition,message);};
const eq=(a,b,message)=>{checks++;assert.deepEqual(a,b,message);};
const throws=(fn,message)=>{checks++;assert.throws(fn,undefined,message);};
const retainedBefore=new Map([v1ref,LIVE_MANIFEST,'reports/3d-parity-metadata/evidence-index.json','reports/3d-parity-metadata/handler-dispositions.json','SPEC-3D-PARITY-METADATA.md','.gitattributes',...Object.keys(v1.hashes)].map(ref=>[ref,sha(raw(ref))]));

eq(Object.keys(v2.hashes),Object.keys(v1.hashes),'same ordered exact 247 path census');
eq(Object.keys(v1.hashes).filter(ref=>v1.hashes[ref]!==v2.hashes[ref]),changed,'exactly approved three changed pins');
check(Object.keys(v2.hashes).length===247,'247 input paths');
eq(v2.previousPins,{path:v1ref,sha256:sha(raw(v1ref))},'immutable actual v1 raw link');
for(const ref of Object.keys(v1.hashes)){
  check(sha(oldReader(ref))===v1.hashes[ref],'old raw view '+ref);
  check(sha(newReader(ref))===v2.hashes[ref],'final raw view '+ref);
}
for(const row of record.changes){
  const candidate=raw('.build/3d/resident-art-integration/'+row.path);
  check(sha(candidate)===row.testedCandidateSha256,'tested input '+row.path);
  check(sha(baseMap.get(row.path))===row.oldSha256,'original bytes '+row.path);
  check(sha(finalMap.get(row.path))===row.finalSha256,'final bytes '+row.path);
  if(row.checkoutNormalization){
    const text=candidate.toString('utf8');
    check((text.match(/\r\n/g)??[]).length===1052&&text.replaceAll('\r\n','').indexOf('\n')===-1,'exact CRLF-only input');
    check(Buffer.from(text.replaceAll('\r\n','\n')).equals(finalMap.get(row.path)),'only CRLF normalization');
    check(!finalMap.get(row.path).includes(13),'final LF policy');
  }else check(candidate.equals(finalMap.get(row.path)),'no unapproved byte transform');
}
check(record.unchangedOwner.path==='game3d/scripts/character_roster.gd'&&sha(raw(record.unchangedOwner.path))===record.unchangedOwner.sha256,'original roster owner unchanged');
for(const [ref,hash] of Object.entries(record.approvedResidentComposition.testedInputs))check(sha(raw('.build/3d/resident-art-integration/'+ref))===hash,'exact approved composition '+ref);
for(const ref of record.separateAcceptedResidentReview.rawInputs)check(sha(raw(ref.path))===ref.sha256,'raw historical review unchanged '+ref.path);

const ledger=load(LIVE_MANIFEST,newReader);
const inputs=readInputs(newReader);
const oldResult=validate(ledger,readInputs(oldReader),v1,{reader:oldReader});
check(oldResult.ok,'v1 original view passes: '+oldResult.errors.join(';'));
const oldOnNew=validate(ledger,inputs,v1,{reader:newReader});
eq(oldOnNew.errors,changed.map(ref=>'Referenced input/source drift: '+ref),'v1 refuses exactly all three new paths');
const newResult=validate(ledger,inputs,v2,{reader:newReader});
check(newResult.ok,'v2 exact composed view passes: '+newResult.errors.join(';'));
for(let mask=0;mask<7;mask++){
  const mixed=new Map(changed.map((ref,index)=>[ref,(mask&(1<<index))?finalMap.get(ref):baseMap.get(ref)]));
  const reader=makeReader(mixed);
  const result=validate(ledger,readInputs(reader),v2,{reader});
  eq(result.errors,changed.filter((_,index)=>!(mask&(1<<index))).map(ref=>'Referenced input/source drift: '+ref),'all partial/old compositions refused '+mask);
}
for(const ref of changed){
  const drift=new Map(finalMap);drift.set(ref,Buffer.concat([drift.get(ref),Buffer.from('\n# unapproved drift')]));
  const reader=makeReader(drift);const result=validate(ledger,readInputs(reader),v2,{reader});
  eq(result.errors,['Referenced input/source drift: '+ref],'unapproved exact-byte drift refused '+ref);
}
const unnormalized=new Map(finalMap);
unnormalized.set('game3d/tests/test_character_roster.gd',raw('.build/3d/resident-art-integration/game3d/tests/test_character_roster.gd'));
const unnormalizedReader=makeReader(unnormalized);
eq(validate(ledger,readInputs(unnormalizedReader),v2,{reader:unnormalizedReader}).errors,['Referenced input/source drift: game3d/tests/test_character_roster.gd'],'tested CRLF candidate is not final LF delivery');
for(const args of [[],['--pins=latest'],['--pins=metadata-v3'],['--pins=../input-pins-metadata-v2.json'],['--pins=C:/input-pins-metadata-v2.json'],['--pins=metadata-v1','--pins=metadata-v2'],['--pins=metadata-v2','--pins=metadata-v2']])throws(()=>selectedPins(args,newReader),'explicit selector refusal '+args.join(','));
eq(selectedPins(['--pins=metadata-v1'],oldReader).value,v1,'v1 stays selectable');
eq(selectedPins(['--pins=metadata-v2'],newReader).value,v2,'v2 literal selected');

const contract=runContract({readFile:newReader,pinArgs:['--pins=metadata-v2'],reportPath:path.join(draft,'results/metadata-contract.json')});
check(contract.pass&&contract.groups===5&&contract.checks===152,'unchanged actual metadata negative contract');
const gate=runGate(['--pins=metadata-v2'],{reader:newReader,logger});
check(gate.ok&&gate.checks===1315,'actual gate export');
const migration=runMigration(['--pins=metadata-v2','--check'],{reader:newReader,outputPath:path.join(root,LIVE_MANIFEST),logger});
check(migration.ok&&migration.checks===1315,'actual deterministic migration export');
check(Buffer.from(JSON.stringify(build(inputs,newReader),null,2)+'\n').equals(raw(LIVE_MANIFEST)),'same exact manifest bytes');
const complete=runGate(['--pins=metadata-v2','--complete'],{reader:newReader,logger:{log:logger.log,error:()=>{}}});
check(!complete.ok&&complete.errors.length===617&&complete.errors.every(e=>e.startsWith('Incomplete ')),'complete refuses exactly 617 original obligations');
check(ledger.handlers.length+ledger.features.length===617&&ledger.features.flatMap(f=>f.evidenceRefs).length===96,'retained obligation/evidence census');

const toolOriginal=local('originals/tools/parity-metadata.mjs');
const tool=local('candidate/tools/parity-metadata.mjs');
const reversedTool=tool.toString('utf8')
 .replace(",'metadata-v2':'reports/3d-parity-metadata/input-pins-metadata-v2.json'",'')
 .replace('Exactly one explicit --pins=<named revision> selection is required.','Exactly one explicit --pins=metadata-v1 selection is required.');
check(Buffer.from(reversedTool).equals(toolOriginal),'tool reverses exactly two literal edits');
for(const name of ['parity-source-proof.mjs','parity-metadata-test.mjs','parity-metadata-gate.mjs','parity-metadata-migrate.mjs'])check(local('validation/tools/'+name).equals(raw('tools/'+name)),'unchanged exported validator support '+name);
const runner=local('candidate/game3d/tests/run-gates.ps1').toString('utf8');
const gateLine="Invoke-Gate -Name 'dave-walkthrough-contract' -GodotArgs @('--script', 'res://tests/test_dave_walkthrough_contract.gd', '--quit-after', '6000') -PassPattern 'DAVE WALKTHROUGH CONTRACT: PASS'\r\n";
const reversedRunner=runner.replaceAll('--pins=metadata-v2','--pins=metadata-v1')
 .replace("'test_incident_presentation.gd', 'test_dave_walkthrough_contract.gd')) {","'test_incident_presentation.gd')) {")
 .replace(gateLine,'').replace('131/131 PASS (import clean; 86 engine suites and 45 source/parity checks;','130/130 PASS (import clean; 85 engine suites and 45 source/parity checks;');
check(Buffer.from(reversedRunner).equals(local('originals/game3d/tests/run-gates.ps1')),'runner exact reversible delta only');
check((runner.match(/^Invoke-Gate -Name '/gm)??[]).length===87,'86 engine suites plus one import');
check((runner.match(/@\{ Name = '/g)??[]).length===45,'45 source suites');
check((runner.match(/--pins=metadata-v2/g)??[]).length===3&&!runner.includes('--pins=metadata-v1'),'all three metadata calls explicitly select v2');
check(runner.includes(gateLine)&&runner.includes("'test_incident_presentation.gd', 'test_dave_walkthrough_contract.gd')) {"),'new contract has actual invocation and required-file entry');
const newTest=raw('.build/3d/resident-art-integration/game3d/tests/test_dave_walkthrough_contract.gd').toString('utf8');
check(newTest.includes('print("DAVE WALKTHROUGH CONTRACT: ","PASS" if failures.is_empty() else "FAIL"')&&newTest.includes('completed_groups == 4'),'actual output marker and all-group guard');
for(const [ref,hash] of retainedBefore)check(sha(raw(ref))===hash,'no live bytes changed '+ref);
const report={schema:1,pass:true,checks,pins:'metadata-v2',changedPins:changed,oldGate:oldResult.checks,newGate:newResult.checks,contractChecks:contract.checks,contractGroups:contract.groups,completeRefusals:complete.errors.length,manifestSha256:sha(raw(LIVE_MANIFEST)),statusesChanged:0,evidenceRefsChanged:0,engineRun:false,gitRun:false};
fs.mkdirSync(path.join(draft,'results'),{recursive:true});
fs.writeFileSync(path.join(draft,'results/revision-contract.json'),JSON.stringify(report,null,2)+'\n');
fs.writeFileSync(path.join(draft,'results/metadata-exports.log'),logs.join('\n')+'\n');
console.log(`RESIDENT METADATA REVISION: PASS (${checks} checks; exactly3 revised pins;617 complete refusals; no production writes)`);
