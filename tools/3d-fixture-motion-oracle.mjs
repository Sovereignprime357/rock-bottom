import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
function findRoot(){
  for(const initial of [HERE,process.cwd()]){
    for(let current=path.resolve(initial);;current=path.dirname(current)){
      if(['VIBE.md','src/render/structures.js','tools/export-3d-content.mjs'].every(file=>fs.existsSync(path.join(current,file))))return current;
      if(path.dirname(current)===current)break;
    }
  }
  throw new Error('Rock Bottom source root was not found in script/cwd ancestors.');
}
const ROOT=findRoot();
const {loadSeededSource,ensureVmFlag,stableStringify,sourceFiles}=await import(pathToFileURL(path.join(ROOT,'tools/export-3d-content.mjs')).href);
const OUTPUT=path.join(ROOT,'game3d/fixtures','fixture_motion_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const relative=file=>path.relative(ROOT,file).replaceAll('\\','/');
const rgbaAlpha=style=>Number(style.slice(style.lastIndexOf(',')+1,-1));

export async function buildFixtureMotionOracle(){
  const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
  const structures=game.module('src/render/structures.js'),landmarks=game.module('src/render/landmarks_b.js');
  const frame=game.module('src/render/frame.js'),world=game.module('src/data/world.js');
  const buildings=game.module('src/data/props.js').BUILDINGS;
  const selected=Object.fromEntries(['CORNER','LAUNDROMAT','PAWN'].map(name=>[name,buildings.find(row=>row.name===name)]));
  const zone=world.ZONES.find(row=>row.id==='underpass');
  assert.ok(zone&&Object.values(selected).every(Boolean),'Canonical fixture records must exist.');
  const pete=ui.runtime.npcs.find(actor=>actor.id==='pete');assert.ok(pete,'Actual Pete record must exist.');
  const originalPeteDead=pete.dead;
  const ctx=game.context.__qa.context2d;let calls=[],stack=[],draws=0,writes=0,visualMs=0,unixMs=0;
  const savedKeys=['fillStyle','strokeStyle','globalAlpha','globalCompositeOperation','lineWidth','font','shadowColor','shadowBlur','textAlign'];
  ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';
  ctx.save=()=>stack.push(Object.fromEntries(savedKeys.map(key=>[key,ctx[key]])));
  ctx.restore=()=>{assert.ok(stack.length,'Canvas restore underflow.');Object.assign(ctx,stack.pop());};
  ctx.fillRect=(x,y,w,h)=>calls.push({op:'rect',x,y,w,h,color:ctx.fillStyle,alpha:ctx.globalAlpha,blend:ctx.globalCompositeOperation});
  ctx.arc=(x,y,r,start,end)=>calls.push({op:'arc',x,y,r,start,end,color:ctx.fillStyle,alpha:ctx.globalAlpha,blend:ctx.globalCompositeOperation});
  ctx.createRadialGradient=(...args)=>({kind:'radial',args,stops:[],addColorStop(offset,color){this.stops.push({offset,color});}});
  game.context.performance.now=()=>visualMs;
  game.context.Date.now=()=>unixMs;
  game.context.Math.random=()=>{draws++;return .5;};
  game.context.window.storage={set:async()=>{writes++;},get:async()=>null};
  const timerCount=()=>game.context.__qa.timers.length;
  const immutable=()=>JSON.stringify({P:ui.P,state:ui.state,npcs:ui.runtime.npcs,buildings,zones:world.ZONES});
  const runBuilding=name=>{calls=[];structures.drawBuilding(selected[name]);assert.equal(stack.length,0);return calls;};
  const inputs=[];
  const add=(id,extra={})=>inputs.push({id,visual_ms:0,unix_ms:0,dayTime:.5,mode:'playing',pete_dead:false,...extra});
  add('origin_day');add('origin_night',{dayTime:0});
  const rising=Math.asin(.3)*110,falling=(Math.PI-Math.asin(.3))*110;
  for(const [name,time] of [['rising',rising],['falling',falling]]){
    for(const [suffix,offset] of [['before',-.000001],['exact',0],['after',.000001]])add('tv_'+name+'_'+suffix,{visual_ms:time+offset});
  }
  for(const [id,time] of [['peak',Math.PI*55],['trough',Math.PI*165],['wrap_before',Math.PI*220-.000001],['wrap',Math.PI*220],['wrap_after',Math.PI*220+.000001]])add('tv_'+id,{visual_ms:time});
  for(const [id,time] of [['quarter',Math.PI*150],['half',Math.PI*300],['three_quarters',Math.PI*450],['wrap',Math.PI*600]])add('washer_'+id,{visual_ms:time});
  for(const [id,time] of [['before',1599.999999],['exact',1600],['after',1600.000001],['positive',Math.PI*200],['negative',Math.PI*600]])add('steam_'+id,{visual_ms:time,dayTime:0});
  for(const [id,value] of [['zero',0],['dawn_before',.249999999],['dawn_exact',.25],['dawn_after',.250000001],['dusk_before',.749999999],['dusk_exact',.75],['dusk_after',.750000001],['one',1]])add('night_'+id,{dayTime:value,visual_ms:713,unix_ms:813});
  for(const [id,time] of [['end_before',1599.999999],['end_exact',1600],['end_after',1600.000001],['wrap_before',7999.999999],['wrap_exact',8000],['wrap_after',8000.000001],['second_end',9600]])add('shadow_'+id,{unix_ms:time,visual_ms:713,dayTime:0});
  add('visual_clock_only_a',{visual_ms:17,unix_ms:913,dayTime:0});
  add('visual_clock_only_b',{visual_ms:1431,unix_ms:913,dayTime:0});
  add('unix_clock_only_a',{visual_ms:917,unix_ms:111,dayTime:0});
  add('unix_clock_only_b',{visual_ms:917,unix_ms:1731,dayTime:0});
  add('paused_visual_continuity_a',{visual_ms:17,unix_ms:913,dayTime:0,mode:'paused'});
  add('paused_visual_continuity_b',{visual_ms:1431,unix_ms:913,dayTime:0,mode:'paused'});
  add('dialogue_visual_continuity',{visual_ms:1431,unix_ms:913,dayTime:0,mode:'dialogue'});
  add('dead_pete_source_steam',{visual_ms:713,unix_ms:813,dayTime:0,pete_dead:true});
  add('absolute_epoch',{visual_ms:713,unix_ms:1763424000913,dayTime:0});
  add('absolute_epoch_boundary',{visual_ms:713,unix_ms:1763424001600,dayTime:0});
  add('large_independent_clocks',{visual_ms:1000000000123,unix_ms:1000000000000913,dayTime:0});
  for(const [id,time] of [['peak',Math.PI*350],['trough',Math.PI*1050],['wrap_before',Math.PI*1400-.000001],['wrap_exact',Math.PI*1400],['wrap_after',Math.PI*1400+.000001]])add('sodium_'+id,{visual_ms:time});
  const cases=[];
  for(const input of inputs){
    visualMs=input.visual_ms;unixMs=input.unix_ms;ui.state.dayTime=input.dayTime;ui.state.mode=input.mode;pete.dead=input.pete_dead;
    ui.state.cam={x:zone.x-100,y:zone.y-100};draws=0;writes=0;
    const before=immutable(),timersBefore=timerCount();
    const tvCalls=runBuilding('CORNER');
    const screens=tvCalls.filter(call=>call.op==='rect'&&call.w===14&&call.h===9&&['#88c0ff','#3a4858'].includes(call.color));
    assert.equal(screens.length,5,'Source CORNER still supplies five indexed screens.');
    const washerCalls=runBuilding('LAUNDROMAT');
    const panes=washerCalls.filter(call=>call.op==='rect'&&call.w===22&&call.h===18&&typeof call.color==='string'&&call.color.startsWith('rgba(180,220,255,'));
    const drums=washerCalls.filter(call=>call.op==='arc'&&call.r===6&&call.color==='rgba(0,0,0,.5)');
    const patches=washerCalls.filter(call=>call.op==='rect'&&call.w===4&&call.h===2&&call.color==='#0a0805');
    assert.equal(panes.length,6);assert.equal(drums.length,6);assert.equal(patches.length,6);
    const washerOffsets=patches.map((patch,index)=>({x:patch.x+patch.w/2-drums[index].x,y:patch.y+patch.h/2-drums[index].y}));
    assert.ok(panes.every(pane=>pane.color===panes[0].color),'All source washers share the day/night pane alpha.');
    const pawnCalls=runBuilding('PAWN');
    const pawnPanes=pawnCalls.filter(call=>call.op==='rect'&&call.w===22&&call.h===18&&typeof call.color==='string'&&call.color.startsWith('rgba(232,192,64,'));
    const steam=pawnCalls.filter(call=>call.op==='arc'&&call.r===1.5&&call.color==='rgba(232,232,200,.4)');
    assert.equal(pawnPanes.length,4);assert.ok(steam.length<=1);
    calls=[];landmarks.drawUnderpass();assert.equal(stack.length,0);
    const shadows=calls.filter(call=>call.op==='rect'&&call.w===120&&call.h===8&&call.color==='rgba(0,0,0,.5)');
    const sodium=calls.filter(call=>call.op==='rect'&&call.color?.kind==='radial');
    assert.equal(sodium.length,3,'All three actual additive radial source patches must be captured.');
    for(const [i,call] of sodium.entries()){
      const [x,y]=[[1100,320],[1240,380],[1340,310]][i];
      assert.deepEqual(call.color.args,[x,y,4,x,y,70]);
      assert.deepEqual([call.x,call.y,call.w,call.h,call.alpha,call.blend],[x-70,y-70,140,140,1,'lighter']);
      assert.deepEqual(call.color.stops.map(stop=>stop.offset),[0,.5,1]);
      assert.ok(call.color.stops[0].color.startsWith('rgba(232,140,40,'));
      assert.deepEqual(call.color.stops.slice(1),[{offset:.5,color:'rgba(220,120,30,.18)'},{offset:1,color:'rgba(220,120,30,0)'}]);
    }
    assert.ok(shadows.length<=1);
    const expected={tv_on:screens[0].color==='#88c0ff',washer_offsets:washerOffsets.slice(0,4),pane_alpha:rgbaAlpha(panes[0].color),steam_visible:steam.length===1,shadow_visible:shadows.length===1};
    expected.sodium_alpha=rgbaAlpha(sodium[0].color.stops[0].color);
    if(steam.length){expected.steam_x=steam[0].x-(pawnPanes[0].x+11);expected.steam_rise=pawnPanes[0].y+1-steam[0].y;}
    if(shadows.length){expected.shadow_phase=(shadows[0].x-zone.x)/(zone.w*6);expected.shadow_rect={x:shadows[0].x,y:shadows[0].y,w:shadows[0].w,h:shadows[0].h};}
    assert.equal(immutable(),before,'Fixture renderers must not mutate source game state.');
    assert.equal(draws,0);assert.equal(writes,0);assert.equal(timerCount(),timersBefore);
    cases.push({id:input.id,input:Object.fromEntries(Object.entries(input).filter(([key])=>key!=='id')),expected,source_draw:{screens:copy(screens),washer_offsets:washerOffsets,washer_pane:copy(panes[0]),steam:copy(steam),shadow:copy(shadows),sodium:copy(sodium)},rng_draws:draws,save_writes:writes,timers_added:timerCount()-timersBefore});
  }
  const sourceText=fs.readFileSync(path.join(ROOT,'src/render/frame.js'),'utf8');
  const underpassOrder=sourceText.indexOf('  drawUnderpass();');
  const buildingsOrder=sourceText.indexOf('  for (const b of BUILDINGS)');
  assert.ok(underpassOrder>=0&&buildingsOrder>underpassOrder,'drawAll must cover the underpass strip with later buildings.');
  // Capture the unchanged two renderers in their asserted actual frame order.
  // This is a source-covered tail, never permission to raise a3D shadow above a floor.
  const covering=buildings[2];
  assert.deepEqual([covering.x,covering.y,covering.w,covering.h],[1560,160,360,240]);
  visualMs=713;unixMs=1599;calls=[];draws=0;writes=0;
  const coverBefore=immutable(),coverTimers=timerCount();
  landmarks.drawUnderpass();
  const stripIndex=calls.findIndex(call=>call.op==='rect'&&call.w===120&&call.h===8&&call.color==='rgba(0,0,0,.5)');
  assert.ok(stripIndex>=0,'The late source strip must still be visible before the building is drawn.');
  structures.drawBuilding(covering);assert.equal(stack.length,0);
  const wallIndex=calls.findIndex(call=>call.op==='rect'&&call.x===covering.x&&call.y===covering.y&&call.w===covering.w&&call.h===covering.h&&call.color===covering.color);
  assert.ok(wallIndex>stripIndex,'The actual opaque building paint must cover the earlier strip.');
  const strip=calls[stripIndex],wall=calls[wallIndex];
  assert.equal(wall.alpha,1);assert.equal(wall.blend,'source-over');
  const coverX=Math.max(strip.x,wall.x),coverY=Math.max(strip.y,wall.y);
  const covered={x:coverX,y:coverY,w:Math.min(strip.x+strip.w,wall.x+wall.w)-coverX,h:Math.min(strip.y+strip.h,wall.y+wall.h)-coverY};
  assert.ok(covered.w>35&&covered.w<36&&covered.h===8,'The1599ms strip has the canonical building_02-covered tail.');
  assert.equal(immutable(),coverBefore);assert.equal(draws,0);assert.equal(writes,0);assert.equal(timerCount(),coverTimers);
  const occlusion={method:'actual unchanged drawUnderpass then drawBuilding in asserted drawAll source order',building_index:2,unix_ms:unixMs,
    frame_order:{underpass_before_buildings:true,underpass_line:sourceText.slice(0,underpassOrder).split(/\r?\n/).length,buildings_line:sourceText.slice(0,buildingsOrder).split(/\r?\n/).length},
    shadow:copy(strip),wall:copy(wall),covered_rect:covered,strip_call_index:stripIndex,wall_call_index:wallIndex,rng_draws:draws,save_writes:writes,timers_added:timerCount()-coverTimers};
  const titleGuard=sourceText.split(/\r?\n/).find(line=>line.includes("if (state.mode === 'title') return;"));
  assert.ok(titleGuard,'The exact title-only drawAll early return must remain present.');
  ui.state.mode='title';visualMs=741.125;unixMs=1600;calls=[];draws=0;writes=0;
  const titleTimers=timerCount();frame.drawAll();
  assert.equal(calls.length,1);assert.equal(calls[0].op,'rect');assert.equal(calls[0].w,world.W);assert.equal(calls[0].h,world.H);
  assert.equal(ui.state.visualNow,visualMs);assert.equal(draws,0);assert.equal(writes,0);assert.equal(timerCount(),titleTimers);
  const title={method:'actual unchanged drawAll',input:{mode:'title',visual_ms:visualMs,unix_ms:unixMs},expected:{world_visible:false,visualNow:ui.state.visualNow,background_draws:1,fixture_draws:0},rng_draws:draws,save_writes:writes};
  pete.dead=originalPeteDead;
  const files=[...sourceFiles(),path.join(ROOT,'VIBE.md')];
  const hashes=Object.fromEntries(files.map(file=>[relative(file),hash(fs.readFileSync(file))]));
  return {schema:1,format:'rock-bottom-fixture-motion-reference',source:{authority:'unchanged drawBuilding/drawUnderpass Canvas calls with independently injected performance.now and Date.now; unchanged drawAll title execution',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs'))),loaderSha256:hash(fs.readFileSync(path.join(ROOT,'tools/export-3d-content.mjs'))),title_guard:titleGuard.trim(),omitted_hidden_coordinates:'No coordinates or phase are asserted when Canvas does not emit the steam/shadow; raw source calls retained.',numeric_comparison:'Recovered relative coordinates may contain source Canvas-coordinate cancellation; compare numbers within 1e-9 absolute tolerance.',scope:'All three700ms additive sodium gradients are actual source draw captures; displayed3D color is a renderer adaptation, not pixel equality. Source blue TV colors are adapted separately. Later building_02 paint covers the original underpass strip tail.'},counts:{samples:cases.length,source_screens:5,source_washers:6,adapted_screens:1,adapted_washers:4,sodium_patches:3,title:1,source_covered_tail:1},bindings:{buildings:copy(selected),underpass:copy(zone)},cases,title,occlusion};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));
  assert.ok(process.argv.slice(2).every(arg=>arg==='--check'),'Only --check is supported.');
  const result=await buildFixtureMotionOracle(),output=stableStringify(result);
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Fixture motion oracle drift.');
  else{fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,output);}
  console.log(`FIXTURE MOTION ORACLE: PASS (${result.counts.samples} samples/${result.counts.title} actual title draw/${result.counts.source_covered_tail} source-covered tail; zero RNG/save/timer work)`);
}
