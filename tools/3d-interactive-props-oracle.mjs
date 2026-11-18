import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';

const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/interactive_props_reference.json');
const copy=value=>JSON.parse(JSON.stringify(value));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const pick=(value,keys)=>Object.fromEntries(keys.filter(key=>value[key]!==undefined).map(key=>[key,copy(value[key])]));
const PLAYER=['x','y','w','h','facing','weapon','attackCd','attacking','cash','hp','maxHp','inventory','cred','wanted','rockedT','cartMounted'];
const STATE=['mode','combo','comboT','shake','hitPause'];
const change=values=>({kind:'change',values});
const attack=()=>({kind:'attack'});
const tick=ms=>({kind:'tick',ms});

export async function buildInteractivePropsOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const props=game.module('src/data/props.js'),combat=game.module('src/systems/combat.js');
 const interactions=game.module('src/systems/interactions.js'),update=game.module('src/core/update.js');
 const comms=game.module('src/systems/communications.js'),boot=game.module('src/core/start.js');
 const persistence=game.module('src/core/audio_save.js'),activities=game.module('src/minigames/activities.js');
 const particleSites=new Set();
 for(const file of ['src/systems/combat.js','src/systems/interactions.js']){
  fs.readFileSync(path.join(ROOT,file),'utf8').split(/\r?\n/).forEach((line,index)=>{
   if(line.includes('particles.push(')&&line.includes('Math.random()'))particleSites.add(file+':'+(index+1));
  });
 }
 let sourceDraws=0,mechanicDraws=0,cosmeticDraws=0,audioDraws=0,cursor=0,rolls=[],roll=.75;
 let saves=0,persisted=null,toastText='',orderedToasts=[],capturing=false,drawSites={};
 Object.defineProperty(ui.toastEl,'textContent',{configurable:true,get:()=>toastText,set:value=>{toastText=String(value);if(capturing&&toastText)orderedToasts.push(toastText);}});
 game.context.storage={async set(_key,value){persisted=copy(value);saves++;},async get(){return persisted?{value:copy(persisted)}:null;}};
 const random=()=>{
  const frame=new Error().stack.split('\n')[2].replaceAll('\\','/');
  const found=frame.match(/(src\/[^():]+\.js):(\d+):\d+/);assert.ok(found,'RNG must originate in unchanged source: '+frame);
  const site=found[1]+':'+found[2];let lane='mechanic',value;
  if(particleSites.has(site)){lane='cosmetic';cosmeticDraws++;value=.5;}
  else if(found[1]==='src/core/audio_save.js'){lane='audio';audioDraws++;value=.5;}
  else{mechanicDraws++;value=rolls[cursor++]??roll;}
  sourceDraws++;const key=site+':'+lane;drawSites[key]=(drawSites[key]||0)+1;return value;
 };
 const records=()=>props.interactiveProps.map((body,index)=>({id:'interactive:'+index,index,...copy(body)}));
 const snapshot=()=>({player:pick(ui.P,PLAYER),state:pick(ui.state,STATE),interactiveProps:records(),actors:ui.runtime.npcs.map(copy),
  achievements:[...ui.state.achievements].sort(),posts:copy(comms.phoneState.posts),toast:toastText,orderedToasts:[...orderedToasts],saves});
 const apply=values=>{
  Object.assign(ui.P,copy(values.player||{}));Object.assign(ui.state,copy(values.state||{}));
  for(const [index,fields]of Object.entries(values.interactiveProps||{})){assert.ok(Number(index)>=0&&Number(index)<14);Object.assign(props.interactiveProps[Number(index)],copy(fields));}
  if(values.actors)ui.runtime.npcs=copy(values.actors);
  if(values.achievements)ui.state.achievements=new Set(values.achievements);
 };
 const reset=spec=>{
  capturing=false;game.context.Math.random=()=>.75;ui.init_runtime_ui();props.init_props();boot.startGame(false);ui.closeDialogue();comms.init_communications();
  ui.runtime.npcs=[];ui.runtime.cashPiles=[];ui.runtime.projectiles=[];ui.particles.length=0;
  Object.assign(ui.P,{x:1000,y:1000,w:24,h:28,facing:'right',attackCd:0,attacking:0,cash:20,copper:0,hp:100,brain:70,shakes:20,wanted:0,cred:0,weapon:'fists',rockedT:0,cartMounted:false});
  Object.assign(ui.state,{mode:'playing',day:1,dayTime:.35,combo:0,comboT:0,shake:0,hitPause:0,publicPhoneT:1e9,phoneT:1e9,eventT:1e9,momTipT:1e9,ambientT:1e9,dustT:1e9,incidentT:1e9});
  for(const key of Object.keys(ui.state.flags))if(key.endsWith('Entered'))ui.state.flags[key]=true;
  ui.state.flags.introDone=false;ui.state.flags.momIntroFired=true;ui.state.quests.intro_remember.done=true;
  // Retain all14 slots. Only selected source records move into the isolated swing.
  for(let index=6;index<14;index++)Object.assign(props.interactiveProps[index],{x:7000+(index-6)*30,y:5000,broken:false});
  apply(spec.setup||{});assert.equal(props.interactiveProps.length,14);
  sourceDraws=0;mechanicDraws=0;cosmeticDraws=0;audioDraws=0;cursor=0;rolls=spec.rolls||[];roll=spec.roll??.75;
  saves=0;persisted=null;toastText='';orderedToasts=[];drawSites={};game.context.__qa.timers.length=0;
  game.context.Math.random=random;capturing=true;
 };
 const projection=(kind,current)=>{
  if(kind==='clock'||kind==='continuity'||kind==='initial')return {interactiveProps:current.interactiveProps};
  return current;
 };
 const run=async op=>{
  if(op.kind==='init_props'){props.initInteractiveProps();return {ok:true};}
  if(op.kind==='open_trash'){
   const body=props.interactiveProps[op.index];assert.equal(body.type,'trashcan');
   ui.P.x=body.x-ui.P.w/2+(op.offset||0);ui.P.y=body.y-ui.P.h/2;
   interactions.tryInteract();return {sourceReturn:null};
  }
  if(op.kind==='attack'){combat.playerAttack();return {sourceReturn:null};}
  if(op.kind==='change'){apply(op.values);return {ok:true};}
  if(op.kind==='tick'){
   assert.ok(Number.isFinite(op.ms)&&op.ms>0);let remaining=op.ms;
   while(remaining>0){const dt=Math.min(50,remaining);if(ui.state.mode==='playing'&&ui.state.hitPause<=0)update.updateWorld(dt);remaining-=dt;}
   return {ok:true};
  }
  if(op.kind==='audio_due'){
   const timers=game.context.__qa.timers.filter(timer=>timer[0]==='timeout'&&String(timer[1]).includes('2000+Math.random()*2000'));
   for(const timer of timers){const index=game.context.__qa.timers.indexOf(timer);game.context.__qa.timers.splice(index,1);timer[1]();}
   return {ok:true,callbacks:timers.length};
  }
  if(op.kind==='save'){await persistence.saveGame();return {ok:persisted!==null};}
  if(op.kind==='fresh'){boot.startGame(false);return {ok:true};}
  if(op.kind==='restore'){assert.ok(persisted);const ok=await persistence.loadGame();assert.equal(ok,true);boot.startGame(true);return {ok};}
  throw Error('Unknown interactive prop oracle operation '+op.kind);
 };
 const specs=[];
 for(let bank=0;bank<2;bank++){
  const inputs=[];for(let index=0;index<8;index++)inputs.push((bank*8+index+.25)/16,index%2?0:.999999,index%2?.999999:0);
  specs.push({kind:'initial',id:'initial_candidates_'+bank,rolls:inputs,ops:[{kind:'init_props'}]});
 }
 specs.push({kind:'initial',id:'initial_zero_jitter',roll:0,ops:[{kind:'init_props'}]});
 specs.push({kind:'initial',id:'initial_high_jitter',roll:.999999,ops:[{kind:'init_props'}]});
 for(const outcome of [0,.499999,.5,.699999,.7,.799999,.8,.999999])specs.push({kind:'trash',id:'trash_threshold_'+outcome,rolls:[outcome,.999999],ops:[{kind:'open_trash',index:0}]});
 for(const cash of [0,.249999,.25,.499999,.5,.749999,.75,.999999])specs.push({kind:'trash',id:'trash_cash_'+cash,rolls:[.1,cash],ops:[{kind:'open_trash',index:0}]});
 for(const index of [0,1,2,3,4,5])specs.push({kind:'trash',id:'trash_can_'+index,rolls:[.6],ops:[{kind:'open_trash',index}]});
 for(const cdT of [0,.00001,-1])specs.push({kind:'trash',id:'trash_cooldown_'+cdT,setup:{interactiveProps:{0:{cdT,tipT:17,rotPulse:19}}},rolls:[.6],ops:[{kind:'open_trash',index:0}]});
 for(const offset of [-50,-49.999,49.999,50])specs.push({kind:'trash',id:'trash_range_'+offset,rolls:[.6],ops:[{kind:'open_trash',index:0,offset}]});
 specs.push({kind:'trash',id:'trash_repeat_cannot_pay',rolls:[.1,0],ops:[{kind:'open_trash',index:0},{kind:'open_trash',index:0}]});
 const samples={
  right:[[1042,1014],[1063.999,1014],[1064,1014],[1020,1014],[1020.001,1014],[1042,1006],[1042,1006.001],[1042,1030],[1042,1029.999]],
  left:[[978,1014],[960.001,1014],[960,1014],[1004,1014],[1003.999,1014],[978,1006],[978,1006.001],[978,1030],[978,1029.999]],
  down:[[1012,1046],[1012,1075.999],[1012,1076],[1012,1024],[1012,1024.001],[1004,1046],[1004.001,1046],[1020,1046],[1019.999,1046]],
  up:[[1012,978],[1012,960.001],[1012,960],[1012,1012],[1012,1011.999],[1004,978],[1004.001,978],[1020,978],[1019.999,978]],
 };
 for(const [facing,points]of Object.entries(samples))for(const [index,[x,y]]of points.entries())specs.push({kind:'bottle',id:'swing_'+facing+'_'+index,setup:{player:{facing},interactiveProps:{6:{x,y}}},rolls:[.5,.5],ops:[attack()]});
 for(const weapon of Object.keys(activities.WEAPONS))for(const edge of [-.001,0]){
  const reach=36+activities.WEAPONS[weapon].reach;
  specs.push({kind:'bottle',id:'weapon_reach_'+weapon+'_'+edge,setup:{player:{weapon},interactiveProps:{6:{x:1024+reach+4+edge,y:1014}}},rolls:[0,.5],ops:[attack()]});
 }
 for(const equipped of [false,true])for(const drop of [.249999,.25])specs.push({kind:'bottle',id:'drop_'+equipped+'_'+drop,setup:{player:{weapon:equipped?'broken_bottle':'fists'},interactiveProps:{6:{x:1042,y:1014}}},rolls:[0,drop],ops:[attack()]});
 specs.push({kind:'bottle',id:'multiple_bottles_captured_weapon',setup:{state:{combo:4,comboT:777},interactiveProps:{6:{x:1042,y:1014},7:{x:1043,y:1015},8:{x:1068,y:1014}}},rolls:[.1,0,.2,0],ops:[attack(),{kind:'audio_due'}]});
 specs.push({kind:'bottle',id:'broken_and_cooldown_skip',setup:{player:{attackCd:1},interactiveProps:{6:{x:1042,y:1014},7:{x:1042,y:1014,broken:true,respawnT:12345}}},ops:[attack(),change({player:{attackCd:0}}),attack()]});
 specs.push({kind:'bottle',id:'bottle_only_resets_combo_without_save',setup:{state:{combo:4,comboT:999},interactiveProps:{6:{x:1042,y:1014}}},rolls:[.999999,0],ops:[attack()]});
 const actor={id:'lurch',name:'LURCH',sprite:'lurch',x:1030,y:1002,w:26,h:32,hp:1000,maxHp:1000,hostile:true,aggro:true,archetype:'charger',chargeState:'idle',dead:false};
 for(const combo of [4,9])specs.push({kind:'combo',id:'npc_bottle_combo_'+combo,setup:{state:{combo,comboT:500},actors:[actor],interactiveProps:{6:{x:1042,y:1014}}},rolls:[.5,.25,0],ops:[attack()]});
 for(const noComboReward of [true,false])specs.push({kind:'combo',id:'npc_connected_'+noComboReward,setup:{state:{combo:3,comboT:500},actors:[{...actor,noComboReward}],interactiveProps:{6:{x:1042,y:1014}}},rolls:[.5,.25,.5],ops:[attack()]});
 specs.push({kind:'combo',id:'essential_then_bottle',setup:{state:{combo:4,comboT:500},actors:[{...actor,essential:true}],interactiveProps:{6:{x:1042,y:1014}}},rolls:[.25,0],ops:[attack()]});
 for(const timer of [49,50,51])specs.push({kind:'clock',id:'can_timer_'+timer,setup:{interactiveProps:{0:{cdT:timer,tipT:timer,rotPulse:timer}}},ops:[tick(50)]});
 specs.push({kind:'clock',id:'can_negative_timers_preserved',setup:{interactiveProps:{0:{cdT:-1,tipT:0,rotPulse:-2}}},ops:[tick(50)]});
 for(let index=0;index<12;index++)specs.push({kind:'clock',id:'respawn_candidate_'+index,setup:{interactiveProps:{6:{broken:true,respawnT:49}}},rolls:[(index+.25)/12,0,.999999],ops:[tick(50)]});
 for(const timer of [0,50,51])specs.push({kind:'clock',id:'respawn_timer_'+timer,setup:{interactiveProps:{6:{broken:true,respawnT:timer}}},rolls:[.999999,.5,.5],ops:[tick(50)]});
 specs.push({kind:'clock',id:'unbroken_respawn_timer_ignored',setup:{interactiveProps:{6:{broken:false,respawnT:0}}},ops:[tick(50)]});
 for(const mode of ['dialogue','paused','cookmini'])specs.push({kind:'clock',id:'paused_'+mode,setup:{state:{mode},interactiveProps:{0:{cdT:1,tipT:1,rotPulse:1},6:{broken:true,respawnT:1}}},ops:[tick(50)]});
 specs.push({kind:'clock',id:'hitpause_freezes_props',setup:{state:{hitPause:40},interactiveProps:{0:{cdT:1,tipT:1,rotPulse:1},6:{broken:true,respawnT:1}}},ops:[tick(16)]});
 specs.push({kind:'continuity',id:'fresh_rebuilds_interactive',setup:{interactiveProps:{0:{cdT:123,tipT:123,rotPulse:123},6:{x:4567,y:2345,broken:true,respawnT:987}}},ops:[{kind:'fresh'}]});
 specs.push({kind:'continuity',id:'restore_rebuilds_interactive',setup:{interactiveProps:{0:{cdT:123,tipT:123,rotPulse:123},6:{x:4567,y:2345,broken:true,respawnT:987}}},ops:[{kind:'save'},change({interactiveProps:{0:{cdT:555},6:{x:888,y:999,respawnT:10}}}),{kind:'restore'}]});
 const cases=[];
 for(const spec of specs){
  reset(spec);const setup=snapshot(),steps=[];
  for(const operation of spec.ops){
   const beforeRecords=records(),beforeDraws=sourceDraws,beforeSaves=saves;
   toastText='';orderedToasts=[];drawSites={};const result=await run(operation);assert.equal(props.interactiveProps.length,14,'Every fixture preserves the production14slots');
   const current=snapshot();
   assert.equal(sourceDraws,mechanicDraws+cosmeticDraws+audioDraws,'Every actual source RNG call is classified');
   if(spec.kind==='initial')assert.equal(mechanicDraws,24,'Source initialization creates eight three-draw bottles');
   if(spec.kind==='clock')assert.ok(Object.keys(drawSites).every(site=>/^src\/core\/update\.js:27[234]:mechanic$/.test(site)),'Clock projection must not conceal unrelated RNG');
   const step={operation:copy(operation),result,expected:projection(spec.kind,current),sourceDraws,mechanicDraws,cosmeticDraws,audioDraws,drawSites:copy(drawSites),compareDraws:spec.kind!=='continuity',compareSaves:!['continuity','clock','initial'].includes(spec.kind)};
   if(spec.kind==='trash'&&spec.id.startsWith('trash_range_')&&operation.kind==='open_trash'&&Math.abs(operation.offset)===50){
    // Source dispatch falls through the missed can into its separate Block owner.
    // Keep dialogue mode in the source snapshot; the bounded kick test owns only refusal.
    assert.deepEqual(current.interactiveProps,beforeRecords,'Range handoff must leave all trash/bottle records untouched');
    assert.equal(sourceDraws,beforeDraws,'Range handoff must consume no source RNG');
    assert.equal(saves,beforeSaves,'Range handoff must not save');
    assert.equal(current.state.mode,'dialogue');assert.equal(ui.activeDialogue?.name,'THE BLOCK');
    step.handoff={owner:'block',reason:'trash_out_of_reach'};
   }
   steps.push(step);
  }
  cases.push({kind:spec.kind,id:spec.id,setup,rolls:spec.rolls||[],roll:spec.roll??.75,operations:copy(spec.ops),steps});
 }
 assert.equal(cases.flatMap(entry=>entry.steps).filter(step=>step.handoff).length,2,'Only the two exact trash range witnesses hand off to Block');
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-interactive-props-reference',source:{authority:'unchanged initInteractiveProps/spawnBreakableBottle/tryInteract/kickTrashCan/playerAttack/updateWorld/save/load/start with callsite-classified source RNG',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},
  counts:{cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),cans:6,bottles:8,initialCandidates:16,respawnCandidates:12,cardinalDirections:4},cases,
  scope:'Full action snapshots; initial/clock/continuity project the14 shared records. Actual source particle and audio callsites retain real draw counts but use fixed presentation rolls. Authoritative supplied rolls advance only at gameplay callsites. Source glass pitch callbacks are explicitly invoked only by audio_due. Whole start/load source draws are characterized rather than compared to the bounded interactive reset.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildInteractivePropsOracle());
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Interactive prop oracle drift; regenerate deliberately.');else fs.writeFileSync(OUTPUT,output);
 const result=JSON.parse(output);console.log(`3D INTERACTIVE PROPS ORACLE: PASS (${result.counts.cases} source paths; ${result.counts.steps} steps; 6 cans/8 bottles,16 initial/12 respawn candidates)`);
}
