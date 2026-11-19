import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,CONTRACT_REPORT,INPUT,TARGETS,read,readInputs,build,validate,sha,aliasProof,aliasCycles,emptyInitializer,selectJson,workspacePath,artifactWitness,selectedPins} from './parity-metadata.mjs';

export function runContract({readFile=read,pinArgs=process.argv.slice(2),reportPath=path.join(ROOT,CONTRACT_REPORT)}={}) {
const selection=selectedPins(pinArgs,readFile);const pins=selection.value;
const inputs=readInputs(readFile);const baseline=build(inputs,readFile);
const cache=new Map(Object.keys(pins.hashes).map(ref=>[ref,readFile(ref)]));
const reader=ref=>cache.get(ref)??readFile(ref);
let checks=0;let groups=0;const cases=[];
function check(ok,label){checks++;assert.ok(ok,label);}
function reject(label,mutate,fragment='') {
  const ledger=structuredClone(baseline);mutate(ledger);
  const result=validate(ledger,inputs,pins,{reader});
  check(!result.ok&&(!fragment||result.errors.some(e=>e.includes(fragment))),label);
  cases.push({label,errors:result.errors.slice(0,3)});
}

// Independent original census and parsed-field preservation, not generated counts alone.
check(inputs.content.omissions.filter(row=>row.reason==='function').length===585,'actual source exported function obligations585');
check(inputs.ledger.features.length===32&&inputs.dispositions.handlers.length===30,'actual feature and approved disposition counts');
check(validate(baseline,inputs,pins,{reader}).ok,'valid additive ledger');
check(baseline.features.flatMap(row=>row.evidenceRefs).length===96,'96 original narrow references');
check(new Set(baseline.features.flatMap(row=>row.evidenceRefs.map(r=>r.artifact.path))).size===29,'29 inspected evidence files');
for(const row of baseline.features)check(row.status===inputs.ledger.features.find(r=>r.id===row.id).status&&row.nativeEvidence.length===0&&row.webEvidence.length===0,'no feature promotion '+row.id);
reject('missing source handler',l=>l.handlers.pop(),'585');
reject('duplicate source identity',l=>l.handlers[1].id=l.handlers[0].id,'585');
reject('missing feature',l=>l.features.pop(),'32');
reject('invented excluded terminal status',l=>l.handlers[0].status='excluded','Unknown terminal');
reject('verified without actual existing platform proof',l=>l.features[0].status='verified','Existing manifest');
reject('metadata cannot write native evidence list',l=>l.features[0].nativeEvidence.push('artifacts/3d-full-port/world-details/hideout_mom.png'),'Existing manifest');
reject('unknown baseline field mutation',l=>l.baseline='invented','Existing manifest');
groups++;

const aliases=baseline.handlers.filter(row=>row.disposition?.kind==='exact_reexport_alias');
check(aliases.length===9,'nine actual named alias rows remain in census');
const sprites=reader('src/render/sprites.js').toString('utf8');
const toolkit=reader('src/render/sprite_toolkit.js').toString('utf8');
for(const row of aliases)check(aliasProof(sprites,toolkit,row.name),'actual import/export and canonical declaration '+row.name);
const renamedImport=sprites.replace(/rasterize,\s*\}\s*from/, 'rasterize as renamed,\n} from');
check(renamedImport!==sprites,'renamed-import counterexample changes actual CRLF or LF source');
check(!aliasProof(renamedImport,toolkit,'rasterize'),'renamed import cannot masquerade as same binding');
check(!aliasProof(sprites.replace("from './sprite_toolkit.js'","from './wrong.js'"),toolkit,'parseGrid'),'wrong module edge rejected');
check(!aliasProof(sprites,toolkit.replace('export function rasterize','export function other'),'rasterize'),'missing canonical export rejected');
check(!aliasProof(sprites,toolkit,'makeRoutePatch'),'actual legacy generator is not a toolkit reexport');
const aliasDeclaration="import { rasterize } from './sprite_toolkit.js'; export { rasterize };";
const canonicalDeclaration='export function rasterize() {}';
check(!aliasProof("/* import { rasterize } from './sprite_toolkit.js'; export { rasterize }; */",'/* export function rasterize() {} */','rasterize'),'peer counterexample: comment-only imports/exports are not bindings');
for(const source of ['// '+aliasDeclaration,'/* '+aliasDeclaration+' */',JSON.stringify(aliasDeclaration)+';','const fake = `'+aliasDeclaration+'`;','function wrapper(){'+aliasDeclaration+'}'])check(!aliasProof(source,canonicalDeclaration,'rasterize'),'alias declarations must be executable top-level bindings: '+source.slice(0,25));
for(const canonical of ['// '+canonicalDeclaration,'/* '+canonicalDeclaration+' */','const fake = /export function rasterize() {}/;','const fake = `'+canonicalDeclaration+'`;','function wrapper(){'+canonicalDeclaration+'}'])check(!aliasProof(aliasDeclaration,canonical,'rasterize'),'canonical function must be an executable top-level export: '+canonical.slice(0,25));
check(aliasProof("import /* comment */ { rasterize, } from './sprite_toolkit.js'; export /* comment */ { rasterize };",'export /* comment */ function rasterize() {}','rasterize'),'real commented module statements retain exact binding');
check(aliasCycles(new Map([['a','b'],['b','a']])).length===2,'independent cycle checker rejects two-node loop');
reject('wrong canonical symbol',l=>l.handlers.find(r=>r.id===aliases[0].id).disposition.canonicalId=aliases[1].disposition.canonicalId,'Exact source reexport');
reject('alias cycle',l=>{const a=l.handlers.find(r=>r.id===aliases[0].id);a.disposition.canonicalId=a.id;},'cycle-free');
reject('legacy generator falsely aliased',l=>{const r=l.handlers.find(r=>r.name==='makeRoutePatch');r.disposition.kind='exact_reexport_alias';r.disposition.canonicalId=aliases[0].disposition.canonicalId;},'Exact source reexport');
reject('alias cross-target laundering',l=>l.handlers.find(r=>r.id===aliases[0].id).disposition.targets=['web_keyboard_mouse'],'Scoped decision');
groups++;

const frame=reader('src/render/frame.js').toString('utf8');
check(emptyInitializer(frame,'init_frame'),'actual active source initializer empty');
for(const body of ['return;',';','"directive";','throw Error();','{}','// }\nrun();','/* } */\nrun();','`template`;'])check(!emptyInitializer(`export function init_frame(){${body}}`,'init_frame'),'nonempty initializer rejected '+body);
check(emptyInitializer('export function init_frame(){/* } fake */\n// } fake\n}','init_frame'),'comments cannot prematurely terminate body proof');
check(!emptyInitializer('/* export function init_frame(){} */','init_frame'),'commented declaration is not an exported initializer');
check(!emptyInitializer('const s=`export function init_frame(){}`;','init_frame'),'template text is not an exported initializer');
check(!emptyInitializer('export function init_frame(a){}','init_frame'),'changed initializer signature rejected');
check(!emptyInitializer('const fake = /export function init_frame() {}/;','init_frame'),'peer counterexample: regex literal is not an initializer declaration');
for(const source of [
  'if (true) /export function init_frame() {}/;',
  'while (false) /export function init_frame() {}/;',
  'const fake = /[\\/]export function init_frame() {}/g;',
  'const fake = `outer ${`export function init_frame() {}`}`;',
  'const fake = `outer ${/export function init_frame() {}/}`;',
  'function wrapper(){ export function init_frame() {} }',
  '/* export function init_frame() {}',
  'const fake = /unterminated; export function init_frame() {}',
  'const fake = `unterminated; export function init_frame() {}',
  'export function init_frame(){ /text/; }',
  'export function init_frame(){} export function init_frame(){}',
  '{} /ambiguous/; export function init_frame(){}',
])check(!emptyInitializer(source,'init_frame'),'opaque/nested/malformed executable proof refuses: '+source.slice(0,45));
for(const prefix of [
  'const fake = /export function init_frame() {}/;',
  'if (true) /export function init_frame() {}/;',
  'const fake = `outer ${`export function init_frame() {}`}`;',
  'const ratio = (10+2)/3; const list = [2]; const half = list[0]/2;',
])check(emptyInitializer(prefix+'\nexport function init_frame(){ /* empty */ }','init_frame'),'actual empty export survives opaque text and real division');
reject('mixed init retains title load',l=>l.handlers.find(r=>r.name==='init_mobile').disposition.retained=[],'Retained/excluded');
reject('touch exclusion cannot broaden to whole startup',l=>l.handlers.find(r=>r.name==='init_mobile').disposition.excludedSubbehavior=['all_mobile_module'],'Retained/excluded');
reject('drawAll cannot discharge aggregate gaps',l=>l.handlers.find(r=>r.name==='drawAll').disposition.completionCredit=true,'Scoped decision');
reject('source empty row cannot discharge drawAll',l=>l.handlers.find(r=>r.name==='drawAll').disposition.kind='proven_empty_initializer','Source initializer');
groups++;

const fixture={acceptance:true,failures:[],phases:[{id:'one',value:1},{id:'two',value:2}],slots:[{kind:'a'}]};
check(JSON.stringify(selectJson(fixture,'phases[id=two].value'))==='[2]','exact id selector actual value');
check(JSON.stringify(selectJson(fixture,'phases[*].value'))==='[1,2]','finite wildcard preserves order');
for(const selector of ['missing','phases[9]','phases[id=absent]','failures[*]','phases[?].value','__proto__'])assert.throws(()=>selectJson(fixture,selector),undefined,selector),checks++;
assert.throws(()=>selectJson({phases:[{id:'same'},{id:'same'}]},'phases[id=same]'));checks++;
const webFeature=baseline.features.find(f=>f.evidenceRefs.some(r=>r.target===TARGETS[1]&&r.artifact.path.endsWith('.json')));
const webId=webFeature.evidenceRefs.find(r=>r.target===TARGETS[1]&&r.artifact.path.endsWith('.json')).id;
reject('Web artifact cannot enter native slot',l=>l.features.find(f=>f.id===webFeature.id).evidenceRefs.find(r=>r.id===webId).target=TARGETS[0],'Actual JSON platform');
const nativeId=baseline.features[0].evidenceRefs[0].id;
reject('native artifact cannot enter Web slot',l=>l.features[0].evidenceRefs.find(r=>r.id===nativeId).target=TARGETS[1],'Actual JSON platform');
reject('forged positive outcome field',l=>l.features[0].evidenceRefs[0].outcome.observations[0].values=[false],'Evidence target/qualification/outcome');
reject('synthetic input cannot become trusted hardware',l=>l.features.find(f=>f.id===webFeature.id).evidenceRefs.find(r=>r.id===webId).qualification='trusted_hardware_input','Evidence target/qualification/outcome');
reject('fixture resources cannot become earned play',l=>l.features[0].evidenceRefs[0].fixtureDisclosure={qualification:'no_fixture',authority:'earned'},'Evidence target/qualification/outcome');
reject('invented human review',l=>l.features[0].evidenceRefs[0].humanVisualReview.asserted=true,'Index cannot fabricate');
reject('narrow artifact cannot verify whole feature',l=>l.features[0].evidenceRefs[0].fullFeatureAcceptance=true,'Index cannot fabricate');
reject('one generic image cannot replace96 refs',l=>{for(const f of l.features)for(const r of f.evidenceRefs)r.artifact={path:'artifacts/3d-full-port/world-details/hideout_mom.png'};},'Evidence target/qualification/outcome');
reject('duplicate evidence witness cannot inflate coverage',l=>l.features[0].evidenceRefs.push(structuredClone(l.features[0].evidenceRefs[0])),'Exactly96');
reject('remaining branch coverage cannot disappear',l=>l.features[0].coverageBoundary.remainingWeb=[],'Remaining coverage');
const failed=baseline.features.flatMap(f=>f.evidenceRefs).find(r=>r.qualification==='failed_sustained_performance');
check(failed?.outcome.explicitFalseOutcomes.acceptance===false,'actual failed profile indexed as failed');
reject('failed performance cannot become a pass',l=>{const r=l.features.flatMap(f=>f.evidenceRefs).find(r=>r.id===failed.id);r.outcome.explicitFalseOutcomes={};r.qualification='passed_performance';},'Failed outcome concealed');
const mixed=baseline.features.flatMap(f=>f.evidenceRefs).find(r=>r.artifact.path.endsWith('kingdom-release.json'));
check(mixed.outcome.explicitFalseOutcomes.sync_target_pass===false,'render pass does not hide actual local sync failure');
const synthetic=baseline.features.flatMap(f=>f.evidenceRefs).find(r=>r.artifact.path.endsWith('web-hands-960.json'));
check(synthetic.outcome.explicitFalseOutcomes.visual_acceptance===false,'raw Web visual false remains false');
groups++;

const changedSource=ref=>ref==='src/render/frame.js'?Buffer.from(frame.replace('export function init_frame() {','export function init_frame() {\nthrow Error("changed");')):reader(ref);
let result=validate(baseline,inputs,pins,{reader:changedSource});check(!result.ok&&result.errors.some(e=>e.includes('Source initializer is not empty'))&&result.errors.some(e=>e.includes('source drift')||e.includes('source hash drift')),'changed source triggers hash and independent empty-body proof');
const sourceRef='game3d/scripts/full_scene.gd';
result=validate(baseline,inputs,pins,{reader:ref=>ref===sourceRef?Buffer.concat([reader(ref),Buffer.from('\n# drift')]):reader(ref)});
check(!result.ok&&result.errors.some(e=>e.includes(sourceRef)),'changed referenced3D implementation invalidates pins');
const firstRef=baseline.features[0].evidenceRefs[0].artifact;
const changedArtifact=ref=>ref===firstRef.path?Buffer.concat([reader(ref),Buffer.from(' ')]):reader(ref);
result=validate(baseline,inputs,pins,{reader:changedArtifact});check(!result.ok&&result.errors.some(e=>e.includes('Evidence bytes changed')),'even parse-equivalent changed artifact bytes invalidate evidence');
for(const ref of ['../outside','C:/outside','/outside','artifacts/../VIBE.md','artifacts\\x']){assert.throws(()=>workspacePath(ref));checks++;}
for(const arguments_ of [['--pins=../INPUT-PINS.json'],['--pins=C:/INPUT-PINS.json'],['--pins=metadata-v1','--pins=metadata-v1']]){assert.throws(()=>selectedPins(arguments_));checks++;}
for(const args of [[],['--pins=latest'],['--pins=INPUT-PINS-v2.json']]){assert.throws(()=>selectedPins(args,reader));checks++;}
const copy=structuredClone(firstRef);copy.fields=['missing_outcome'];assert.throws(()=>artifactWitness(copy,reader));checks++;
const droppedPins=structuredClone(pins);delete droppedPins.hashes[sourceRef];result=validate(baseline,inputs,droppedPins,{reader});check(!result.ok&&result.errors.includes('Pin census does not cover every referenced input/source'),'cannot silently drop a source pin');
check(JSON.stringify(build(inputs,reader))===JSON.stringify(baseline),'deterministic migration');
result=validate(baseline,inputs,pins,{reader,complete:true});check(!result.ok&&result.errors.filter(e=>e.startsWith('Incomplete ')).length===617,'complete remains failing for all585+32 current obligations');
groups++;

check(groups===5,'all five independent groups completed');
const report={schema:1,pass:true,checks,groups,pins:selection.name,negativeCases:cases,scope:'Node metadata contracts only; no engine/platform/human acceptance',sourceFilesChanged:0,originalStatusesChanged:0};
fs.mkdirSync(path.dirname(reportPath),{recursive:true});
fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
console.log(`ADDITIVE PARITY CONTRACT: PASS (${checks} checks;${groups}/5 groups;${cases.length} ledger counterexamples; --complete still fails)`);
return report;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))runContract();
