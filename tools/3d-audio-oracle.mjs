import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/audio_reference.json');
const IDS=['hit','hurt','pickup','coin','rockUp','crash','death','rankUp','dialogue','copSiren','bossRoar','glassBreak','cricket','traffic','carDoor','cough','dogBark','windup','bottleThrow','bottleHit','holyWaterThrow','holyWaterHit','radio','kick'];
const clone=x=>JSON.parse(JSON.stringify(x));
const next=x=>(Math.imul(x,1664525)+1013904223)>>>0;
async function build(){
 const game=await loadSeededSource(),save=game.module('src/core/audio_save.js'),ui=game.module('src/core/runtime_ui.js');
 const update=game.module('src/core/update.js'),props=game.module('src/data/props.js'),boot=game.module('src/core/start.js');
 const originalTimeout=game.context.setTimeout,plans=[];
 // Execute unchanged recipe bodies at their tone/noise seam. This deliberately
 // separates cosmetic pitch draws from noise filling; original coupling below.
 for(let kindIndex=0;kindIndex<IDS.length;kindIndex++)for(let bank=0;bank<8;bank++){
  save.init_audio_save();const audio=save.audio,kind=IDS[kindIndex];let seed=0x41554400+bank*7919+kindIndex*104729;
  let serial=0,task=null;const timers=[],rows=[];
  game.context.Math.random=()=>{seed=next(seed);return seed/2**32;};
  game.context.setTimeout=(fn,ms)=>{timers.push({fn,ms,serial:serial++});return serial;};
  const record=row=>rows.push({...row,offset_ms:task?.ms??0,deferred:!!task,order:task?.serial??serial++});
  audio.tone=(frequency,duration=.1,waveform='square',volume=.08,slide=null)=>record({type:'tone',frequency,duration,waveform,volume,slide});
  audio.noise=(duration=.08,volume=.06)=>record({type:'noise',duration,volume});
  audio[kind]();
  for(const timer of timers.sort((a,b)=>a.ms-b.ms||a.serial-b.serial)){task=timer;timer.fn();}
  rows.sort((a,b)=>a.order-b.order);for(const row of rows)delete row.order;
  plans.push({kind,bank,notes:rows});
 }
 // Original primitives remain unchanged here. Fake WebAudio records starts and
 // counts actual noise-buffer random draws at each sample rate/gate.
 function primitiveContext(rate,trace){
  let draws=0;
  game.context.Math.random=()=>{draws++;return .75;};
  const ctx={currentTime:0,sampleRate:rate,destination:{},createOscillator(){
   const row={type:'tone',frequency:null,slide:null,duration:null,waveform:'',volume:null};
   return {type:'square',frequency:{setValueAtTime(f){row.frequency=f;},exponentialRampToValueAtTime(f,t){row.slide=f;row.duration=t-ctx.currentTime;}},connect(g){row.g=g;return g;},start(t){row.waveform=this.type;row.volume=row.g.value;row.at=t*1000;trace.push(row);},stop(t){row.stop=t*1000;delete row.g;}};
  },createGain(){return {value:0,gain:{setValueAtTime(v){this.owner.value=v;},exponentialRampToValueAtTime(){}},connect(){return this;}};},
  createBuffer(_channels,count){const data=new Float32Array(count);return {count:data.length,getChannelData(){return data;}};},
  createBufferSource(){return {buffer:null,connect(g){this.g=g;return g;},start(t){trace.push({type:'noise',at:t*1000,samples:this.buffer.count,volume:this.g.gain.value});}};}};
  const gain=ctx.createGain;ctx.createGain=()=>{const g=gain();g.gain.owner=g;return g;};
  return {ctx,draws:()=>draws};
 }
 const coupling=[];
 for(const rate of [22050,48000])for(const ready of [false,true])for(const muted of [false,true]){
  save.init_audio_save();let starts=[];const fake=primitiveContext(rate,starts);
  Object.assign(save.audio,{ctx:fake.ctx,ready,muted});save.audio.noise(.08,.06);
  coupling.push({rate,ready,muted,draws:fake.draws(),starts:starts.length});
  assert.equal(fake.draws(),ready&&!muted?Math.floor(rate*.08):0);
 }
 const gates=[];
 for(const spec of [
  {id:'pickup_unlock_between',kind:'pickup',ready:false,muted:false,changes:[{at:20,ready:true}]},
  {id:'coin_mute_between',kind:'coin',ready:true,muted:false,changes:[{at:40,muted:true},{at:100,muted:false}]},
  {id:'rockup_unmute_middle',kind:'rockUp',ready:true,muted:true,changes:[{at:150,muted:false}]},
  {id:'death_mute_middle',kind:'death',ready:true,muted:false,changes:[{at:230,muted:true},{at:500,muted:false}]},
  {id:'glass_initial_locked',kind:'glassBreak',ready:false,muted:false,changes:[{at:25,ready:true}]},
  {id:'immediate_not_replayed',kind:'hurt',ready:false,muted:false,changes:[{at:1,ready:true}]}
 ]){
  save.init_audio_save();const starts=[],fake=primitiveContext(22050,starts),timers=[];let serial=0,now=0;
  Object.assign(save.audio,{ctx:fake.ctx,ready:spec.ready,muted:spec.muted});
  game.context.setTimeout=(fn,ms)=>{timers.push({at:now+ms,serial:serial++,fn});return serial;};
  save.audio[spec.kind]();
  for(const change of spec.changes)timers.push({at:change.at,serial:serial++,fn:()=>{if('ready'in change)save.audio.ready=change.ready;if('muted'in change)save.audio.muted=change.muted;}});
  timers.sort((a,b)=>a.at-b.at||a.serial-b.serial);
  for(const timer of timers){now=timer.at;fake.ctx.currentTime=now/1000;timer.fn();}
  gates.push({...spec,starts:starts.map(row=>({type:row.type,at:row.at})),draws:fake.draws()});
 }
 game.context.setTimeout=originalTimeout;
 const ambient=[];
 function reset(spec){
  game.context.Math.random=()=>.75;ui.init_runtime_ui();ui.closeDialogue();
  ui.runtime.npcs=[];ui.runtime.cashPiles=[];ui.runtime.projectiles=[];ui.particles.length=0;props.interactiveProps.length=0;
  Object.assign(ui.P,{x:4000,y:4000,wanted:spec.wanted??0,shakes:0,rockedT:0,crashT:0,hp:100,hasPossum:false});
  Object.assign(ui.state,{mode:'playing',day:1,dayTime:(spec.time??.35)-(spec.steps?.[0]??0)/240000,phoneT:1e9,eventT:1e9,momTipT:1e9,dustT:1e9,incidentT:1e9,publicPhoneT:1e9,phonePropRingT:0,territoryT:0,hustleCheckT:0});
  Object.assign(ui.state.flags,{introDone:false,momIntroFired:true,parkNightCashDay:1,silenceUntilT:spec.silence?Number.MAX_SAFE_INTEGER:0});
  // Satisfy manageCops with inert nearby rows, so wanted's ambient siren roll is
  // isolated from police creation/radio/AI randomness in this source update.
  if(spec.wanted>0)for(let i=0;i<4;i++)ui.runtime.npcs.push({id:'qa_inert_'+i,name:'qa',x:4040,y:4040,w:28,h:32,hp:60,maxHp:60,speed:0,isCop:true,hostile:false,wander:false,chatterCd:1e9,archetype:'qa_inert'});
  if('timer'in spec)ui.state.ambientT=spec.timer;else delete ui.state.ambientT;
  ui.state.quests.intro_remember.done=true;
 }
 const specs=[];
 for(const time of [0,.249999,.25,.75,.750001,.999])for(const roll of [0,.399999,.4,.499999,.5,.599999,.6,.699999,.7,.749999,.75,.849999,.85,.999999])specs.push({id:`pick_${time}_${roll}`,time,timer:1,rolls:[.25,roll],steps:[1]});
 for(const wanted of [0,1])for(const siren of [.299999,.3])specs.push({id:`wanted_${wanted}_${siren}`,wanted,timer:1,rolls:[.5,.99,siren],steps:[1]});
 for(const timer of [undefined,0,-1,1,25])specs.push({id:'clock_'+timer,...timer===undefined?{}:{timer},rolls:[0,.99],steps:[1,25,50]});
 specs.push({id:'silence_and_intro_do_not_gate',silence:true,timer:1,wanted:2,rolls:[.5,.1,.1],steps:[1]});
 for(const spec of specs){
  reset(spec);let sounds=[],draws=0,cursor=0;save.init_audio_save();
  for(const id of IDS)save.audio[id]=()=>sounds.push(id);
  game.context.Math.random=()=>{draws++;return spec.rolls[cursor++]??.75;};
  const steps=[];
  for(const dt of spec.steps){update.updateWorld(dt);steps.push({dt,time:ui.state.dayTime,timer:ui.state.ambientT,sounds:clone(sounds),draws});}
  assert.ok(draws<=3,'Unisolated non-ambient randomness in '+spec.id);
  ambient.push({setup:spec,steps});
 }
 reset({timer:1234});boot.startGame(false);const fresh=ui.state.ambientT;
 const persisted={version:22,player:clone(ui.P)};game.context.storage={get:async()=>({value:persisted}),set:async()=>{}};
 const loaded=await save.loadGame();const lifecycle={fresh,loaded,restore:ui.state.ambientT};
 assert.deepEqual(lifecycle,{fresh:1234,loaded:true,restore:1234});
 assert.equal(plans.length,192);assert.equal(ambient.length,94);
 return {schema:1,authority:'unchanged source recipes, original primitives/gates, and updateWorld ambient scheduler; separated cosmetic pitch/noise streams are explicit adaptation',plans,gates,coupling,ambient,lifecycle};
}
ensureVmFlag(fileURLToPath(import.meta.url));
const result=await build(),output=stableStringify(result);
if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Audio oracle drift.');else fs.writeFileSync(OUTPUT,output);
console.log(`3D AUDIO ORACLE: PASS (${result.plans.length} recipe banks / ${result.gates.length} gate timelines / ${result.coupling.length} original RNG cases / ${result.ambient.length} ambient cases)`);
