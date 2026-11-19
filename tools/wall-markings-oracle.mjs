import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';

const OUTPUT=path.join(ROOT,'game3d/fixtures/wall_markings_reference.json');
const METRICS=path.join(ROOT,'game3d/data/courier_canvas_metrics.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const fields=state=>({graffiti:state.graffiti??null,posters:state.posters??null});
const advance=seed=>(Math.imul(seed,1664525)+1013904223)>>>0;
function randomStream(options={}){
 let seed=options.seed??0x19c0ffee,draws=0,rolls=options.rolls??[],index=0,fallback=options.fallback;
 return {
  draw(){seed=advance(seed);draws++;return index<rolls.length?rolls[index++]:fallback??seed/4294967296;},
  change(next){if(Object.hasOwn(next,'rolls')){rolls=next.rolls;index=0;}if(Object.hasOwn(next,'fallback'))fallback=next.fallback;},
  inspect(){const nextSeed=advance(seed);return {draws,seed,next:index<rolls.length?rolls[index]:fallback??nextSeed/4294967296,next_lcg:nextSeed/4294967296};},
 };
}

export async function buildWallMarkingsOracle(metrics=JSON.parse(fs.readFileSync(METRICS,'utf8'))){
 assert.equal(metrics.format,'rock-bottom-courier-canvas-metrics');
 assert.equal(metrics.evidence.method,'canvas-measureText','A real Canvas capture is required.');
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const art=game.module('src/render/structures.js'),catalogs=game.module('src/data/catalogs.js');
 const ctx=game.context.__qa.context2d,save=game.module('src/core/audio_save.js');
 const expectedPools={graffitiLines:catalogs.GRAFFITI_LINES,scrapGraffitiLines:catalogs.SCRAP_GRAFFITI_LINES,spiritualGraffitiLines:catalogs.SPIRITUAL_GRAFFITI_LINES};
 const table=new Map();
 for(const entry of metrics.entries){
  assert.ok([8,9,10].includes(entry.size)&&Number.isFinite(entry.width)&&entry.width>0);
  assert.equal(entry.ceil,Math.ceil(entry.width));
  assert.equal(expectedPools[entry.pool]?.[entry.index],entry.text,'Canvas corpus identity drift.');
  const key=JSON.stringify([entry.text,entry.size]);assert.ok(!table.has(key));table.set(key,entry.width);
 }
 assert.equal(table.size,198);
 for(const lines of Object.values(expectedPools))for(const text of lines)for(const size of [8,9,10])assert.ok(table.has(JSON.stringify([text,size])));
 ctx.measureText=function(text){
  const size=Number(String(this.font).match(/(\d+(?:\.\d+)?)px/)?.[1]);
  const key=JSON.stringify([String(text),size]);assert.ok(table.has(key),'Missing exact captured Canvas metric '+key);
  return {width:table.get(key)};
 };
 // Reuse the exact source assignments at the decoration lifecycle seam. Unrelated
 // player/spawn/cash/phone/incidents/hustle rolls are outside this bounded owner.
 const startText=fs.readFileSync(path.join(ROOT,'src/core/start.js'),'utf8');
 const saveText=fs.readFileSync(path.join(ROOT,'src/core/audio_save.js'),'utf8');
 const freshBlock=startText.split(/\r?\n/).filter(line=>/^\s*state\.(graffiti|posters) = null;/.test(line)).join('\n');
 const restoreBlock=saveText.split(/\r?\n/).filter(line=>/^\s*state\.(graffiti|posters) = sv\.(graffiti|posters) \|\| null;/.test(line)).join('\n');
 assert.equal(freshBlock.split('\n').length,2);assert.equal(restoreBlock.split('\n').length,2);
 const fresh=vm.runInContext(`(function(state){${freshBlock}\n})`,game.context,{filename:'unchanged-start-wall-markings.js'});
 const restore=vm.runInContext(`(function(state,sv){${restoreBlock}\n})`,game.context,{filename:'unchanged-load-wall-markings.js'});
 const valid=copy(fields(ui.state)),tag=valid.graffiti[0],poster=valid.posters[0];
 const validOne={graffiti:[tag],posters:[poster]};
 const legacy={x:tag.x,y:tag.y,text:'legacy chalk',sz:9,col:'#a06868',rot:0};
 const restoreOp=raw_state=>({kind:'start_restore',raw_state});
 const rows=[
  {id:'fresh_minimum_attempts',setup:validOne,rng:{fallback:0},operations:[{kind:'start_fresh'},{kind:'save'}]},
  {id:'fresh_maximum_attempts',setup:validOne,rng:{fallback:0.999999},operations:[{kind:'start_fresh'}]},
  ...[1,0x19c0ffee,0xffffffff,0x5eed1234].map(seed=>({id:'fresh_lcg_'+seed,setup:validOne,rng:{seed},operations:[{kind:'start_fresh'},{kind:'before_draw'},{kind:'save'}]})),
  {id:'fresh_boot_after_phone_and_bottles',setup:validOne,rng:{seed:65195085},operations:[{kind:'start_fresh'}]},
  {id:'fresh_clears_custom_layout',setup:{graffiti:[{...tag,text:'retained only on restore'}],posters:[{...poster,text:'old paper'}]},rng:{seed:123},operations:[{kind:'start_fresh'}]},
  {id:'valid_export_reuse',setup:{graffiti:null,posters:null},rng:{seed:123},operations:[restoreOp(valid),{kind:'before_draw'},{kind:'save'}]},
  {id:'valid_custom_measured_reuse',setup:{},rng:{seed:123},operations:[restoreOp({graffiti:[{...tag,text:'saved custom chalk',textW:1}],posters:[{...poster,text:'saved custom paper',faction:'neutral'}]}),{kind:'before_draw'},{kind:'save'}]},
  {id:'legacy_graffiti_start_migrates',setup:{},rng:{seed:123},operations:[restoreOp({graffiti:[legacy],posters:[poster]})]},
  {id:'legacy_graffiti_draw_retained',setup:validOne,rng:{seed:123},operations:[restoreOp(validOne),{kind:'before_draw',replace:{graffiti:[legacy]}},{kind:'save'}]},
  {id:'invalid_version_rebuild',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,layoutV:1}],posters:[poster]})]},
  {id:'invalid_missing_measure_rebuild',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[Object.fromEntries(Object.entries(tag).filter(([key])=>key!=='textW'))],posters:[poster]})]},
  {id:'invalid_too_wide_rebuild',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,textW:tag.wallW+1}],posters:[poster]})]},
  {id:'invalid_left_bound_rebuild',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,x:tag.wallX-0.002}],posters:[poster]})]},
  {id:'invalid_right_bound_rebuild',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,x:tag.wallX+tag.wallW-tag.textW+0.002}],posters:[poster]})]},
  {id:'left_tolerance_retained',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,x:tag.wallX-0.0005}],posters:[poster]})]},
  {id:'right_tolerance_retained',setup:{},rng:{seed:321},operations:[restoreOp({graffiti:[{...tag,x:tag.wallX+tag.wallW-tag.textW+0.0005}],posters:[poster]})]},
  ...[['missing',{}],['null',{graffiti:null,posters:null}],['empty',{graffiti:[],posters:[]}],['false',{graffiti:false,posters:false}],['zero',{graffiti:0,posters:0}],['blank',{graffiti:'',posters:''}]].map(([suffix,raw])=>({id:'restore_'+suffix,setup:valid,rng:{seed:901},operations:[restoreOp(raw),{kind:'save'}]})),
  {id:'restore_missing_only_graffiti',setup:valid,rng:{seed:901},operations:[restoreOp({posters:[poster]})]},
  {id:'restore_missing_only_posters',setup:valid,rng:{seed:901},operations:[restoreOp({graffiti:[tag]})]},
  {id:'nonempty_legacy_poster_trusted',setup:{},rng:{seed:901},operations:[restoreOp({graffiti:[tag],posters:[{x:11,y:12,w:16,h:24,text:'old paper'}]}),{kind:'before_draw'},{kind:'save'}]},
  ...[0.549999,0.55,0.550001].map(roll=>({id:'poster_probability_'+roll,setup:{},rng:{fallback:roll},operations:[restoreOp({graffiti:[tag],posters:null})]})),
  ...[0,0.4,0.7].map(wall=>({id:'poster_wall_'+wall,setup:{},rng:{rolls:[0,0,wall,0.5],fallback:0.99},operations:[restoreOp({graffiti:[tag],posters:null})]})),
  {id:'poster_per_zone_cap',setup:{},rng:{fallback:0},operations:[restoreOp({graffiti:[tag],posters:null})]},
  {id:'empty_poster_render_retries',setup:{},rng:{fallback:0.99},operations:[restoreOp({graffiti:[tag],posters:null}),{kind:'before_draw'},{kind:'before_draw',rng:{fallback:0.55}},{kind:'before_draw'},{kind:'save'}]},
  {id:'draw_null_both_rebuilds_ordered',setup:validOne,rng:{seed:410},operations:[restoreOp(validOne),{kind:'before_draw',replace:{graffiti:null,posters:null}},{kind:'before_draw'}]},
 ];
 let stored=null,writes=0;
 game.context.storage={set:async(_key,value)=>{writes++;stored=copy(value);return true;},get:async()=>stored?{value:stored}:null};
 ui.state.cam={x:0,y:0};
 const cases=[];
 for(const row of rows){
  delete ui.state.graffiti;delete ui.state.posters;Object.assign(ui.state,copy(row.setup));
  stored=null;writes=0;const rng=randomStream(row.rng);game.context.Math.random=()=>rng.draw();
  const steps=[];
  for(const operation of row.operations){
   if(operation.rng)rng.change(operation.rng);
   if(operation.replace)Object.assign(ui.state,copy(operation.replace));
   const before=copy(fields(ui.state)),beforeRandom=rng.inspect(),beforeWrites=writes;
   if(operation.kind==='start_fresh'){fresh(ui.state);art.buildGraffiti();art.buildPosters();}
   else if(operation.kind==='start_restore'){restore(ui.state,copy(operation.raw_state));art.buildGraffiti();art.buildPosters();}
   else if(operation.kind==='before_draw'){art.drawGraffiti();art.drawPosters();}
   else if(operation.kind==='save')await save.saveGame();
   else throw new Error('Unknown oracle operation '+operation.kind);
   const expected=copy(fields(ui.state)),afterRandom=rng.inspect();
   if(operation.kind==='save'){
    assert.deepEqual(expected,before);assert.equal(writes,beforeWrites+1);assert.ok(stored);
    assert.deepEqual(copy(fields(stored)),expected);
   }else assert.equal(writes,beforeWrites,'Decoration generation must never write a save.');
   const step={operation,expected,rng:{...afterRandom,stepDraws:afterRandom.draws-beforeRandom.draws},writes,sourceValid:art.currentGraffitiLayout(ui.state.graffiti)};
   if(stored)step.saved=copy(fields(stored));
   steps.push(step);
  }
  cases.push({id:row.id,setup:row.setup,rng:row.rng,steps});
 }
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].sort().map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-wall-markings-reference',source:{authority:'unchanged buildGraffiti/buildPosters/drawGraffiti/drawPosters/saveGame with verbatim lifecycle assignment seams',hashes,corpusSha256:hash(stableStringify(hashes)),metricsSha256:hash(stableStringify(metrics)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs'))),freshBlockSha256:hash(freshBlock),restoreBlockSha256:hash(restoreBlock),boundaryNotes:['The RNG begins at the decoration seam after NPC/cash/interactive initialization; unrelated start/load draws are outside this owner.','Canvas widths are injected only at the harness measureText boundary; source builders are unchanged.','Expected absent/undefined fields canonicalize to null; raw_state still preserves absence.','Operation replace is an explicit external test input, not a new owner command.','Underlying LCG advances on every draw, including scripted output overrides; next and next_lcg do not consume it.']},counts:{cases:cases.length,steps:cases.reduce((n,row)=>n+row.steps.length,0),metrics:table.size},cases};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));
 const result=await buildWallMarkingsOracle(),output=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Wall markings source oracle drift.');
 else{fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,output);}
 console.log(`WALL MARKINGS ORACLE: PASS (${result.counts.cases} cases/${result.counts.steps} steps/${result.counts.metrics} Canvas metrics)`);
}
