import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {ROOT,loadSeededSource,stableStringify} from './export-3d-content.mjs';

const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
const acts=game.module('src/minigames/activities.js'),comms=game.module('src/systems/communications.js');
const update=game.module('src/core/update.js'),world=game.module('src/data/world.js');
const props=game.module('src/data/props.js'),boot=game.module('src/core/start.js'),save=game.module('src/core/audio_save.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const FLAGS=['underpassEntered','trainYardEntered','parkEntered','skidRowEntered','oldSchoolEntered','warehouseRowEntered','canalEntered','theLotEntered','blueTarpCourtEntered','cartKeepEntered','copperChoirEntered','throneDitchEntered'];
const ZONES=['underpass','trainyard','park','skidrow','oldschool','warehouse_row','canal','the_lot','blue_tarp_court','cart_cavalry_keep','copper_choir_yard','throne_ditch'];
const originalZones=clone(world.ZONES);
const clocks=()=>Object.fromEntries(['tweakerT','tweakerCdT','autoSaveT'].map(key=>[key,ui.state[key]??0]));
const flagSnapshot=()=>Object.fromEntries(FLAGS.map(key=>[key,!!ui.state.flags[key]]));
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
let draws=0,saves=0,rolls=[],cursor=0,toasts=[],sounds=[],persisted=null,pendingToast=null,toastText='';
Object.defineProperty(ui.toastEl,'textContent',{configurable:true,get:()=>toastText,set:value=>{toastText=String(value);pendingToast=toastText;}});
const sourceTimeout=game.context.setTimeout;
game.context.setTimeout=(fn,ms)=>{if(pendingToast!==null){toasts.push({text:pendingToast,duration_ms:ms});pendingToast=null;}return sourceTimeout(fn,ms);};
save.audio.coin=()=>sounds.push('coin');
game.context.storage={set:async(_key,value)=>{saves++;persisted=clone(value);},get:async()=>persisted?{value:clone(persisted)}:null};
const keydown=game.context.__qa.listeners.find(([where,type])=>where==='window'&&type==='keydown')[2];
const keyup=game.context.__qa.listeners.find(([where,type])=>where==='window'&&type==='keyup')[2];
const keyEvent=(key,repeat=false)=>({key,repeat,preventDefault(){}});
function reset(spec={}){
 game.context.Math.random=()=>.75;
 for(let i=0;i<world.ZONES.length;i++)Object.assign(world.ZONES[i],clone(originalZones[i]));
 ui.init_runtime_ui();ui.closeDialogue();comms.init_communications();
 ui.runtime.npcs=[];ui.runtime.cashPiles=[];ui.runtime.projectiles=[];ui.particles.length=0;props.interactiveProps.length=0;
 Object.assign(ui.P,{x:4000,y:4000,cash:20,cred:0,brain:70,shakes:0,hp:100,maxHp:100,wanted:0,stunT:0,rockedT:0,crashT:0,hasPossum:false,inventory:[]},clone(spec.player||{}));
 Object.assign(ui.state,{mode:'playing',day:1,dayTime:.35,tweakerT:0,tweakerCdT:0,autoSaveT:0,phoneT:1e9,eventT:1e9,momTipT:1e9,ambientT:1e9,dustT:1e9,incidentT:1e9,publicPhoneT:1e9,phonePropRingT:0,territoryT:0,hustleCheckT:0},clone(spec.state||{}));
 Object.assign(ui.state.flags,{introDone:false,momIntroFired:true,silenceUntilT:0},clone(spec.flags||{}));
 for(const key of FLAGS)ui.state.flags[key]=spec.entries?false:true;
 ui.state.quests.intro_remember.done=true;
 ui.state.counters.bigPan=spec.bigPan??0;
 if(spec.overlap)for(const zone of world.ZONES)if(spec.overlap.includes(zone.id))Object.assign(zone,{x:100,y:100,w:200,h:200});
 if(spec.zone){const zone=world.ZONES.find(z=>z.id===spec.zone);assert.ok(zone);ui.P.x=zone.x+zone.w/2-ui.P.w/2;ui.P.y=zone.y+zone.h/2-ui.P.h/2;}
 if(spec.center){ui.P.x=spec.center[0]-ui.P.w/2;ui.P.y=spec.center[1]-ui.P.h/2;}
 draws=0;saves=0;cursor=0;rolls=spec.rolls||[];toasts=[];sounds=[];pendingToast=null;toastText='';persisted=null;
 comms.phoneState.posts.length=0;game.context.document.getElementById('tape').textContent='';game.context.__qa.timers.length=0;
 game.context.Math.random=()=>{draws++;return rolls[cursor++]??.75;};
}
const outcomes=()=>({player:{cash:ui.P.cash,cred:ui.P.cred,brain:ui.P.brain,wanted:ui.P.wanted,inventory:clone(ui.P.inventory)},bigPan:ui.state.counters.bigPan,
 mode:ui.state.mode,toasts:clone(toasts),sounds:clone(sounds),posts:clone(comms.phoneState.posts),news:game.context.document.getElementById('tape').textContent,saves,draws});
const menus=[];
for(const rocks of [0,1])for(const high of [0,18000])for(const supplies of [0,3])for(const extras of [false,true]){
 const spec={zone:'block',player:{rocks,soapRocks:0,rockedT:high,supplies,shakes:49.5,brain:69.5,inventory:extras?[{id:'lottery',n:'a lottery ticket',q:1}]:[]},flags:{hasStripePackage:extras}};
 reset(spec);acts.blockMenu();menus.push({id:`block_${rocks}_${high}_${supplies}_${extras}`,setup:spec,expected:menu()});
}
for(const dayTime of [0,.249999,.25,.5,.75,.750001,1]){
 const spec={zone:'market',state:{dayTime}};reset(spec);acts.panhandle();menus.push({id:'market_'+dayTime,setup:spec,expected:menu()});
}
const specs=[];
for(let thought=0;thought<6;thought++)specs.push({id:'thought_'+thought,zone:'block',action:'think',rolls:[(thought+.1)/6]});
for(const roll of [0,.009999,.01,.149999,.15,.999999])for(const small of [0,.999999])specs.push({id:`lottery_${roll}_${small}`,zone:'block',action:'lottery',player:{inventory:[{id:'lottery',n:'one',q:7},{id:'food',n:'food',q:2},{id:'lottery',n:'two',q:1}]},rolls:[roll,small]});
specs.push({id:'lottery_captured_removed',zone:'block',action:'lottery',player:{inventory:[{id:'lottery',n:'ticket',q:1}]},afterOpen:{inventory:[]},rolls:[0]});
for(const dayTime of [.25,.75,0,.8]){
 const mod=dayTime<.25||dayTime>.75?-.2:0;
 for(const roll of [0,.45+mod-1e-7,.45+mod,.65+mod-1e-7,.65+mod,.849999,.85,.999999]){
  specs.push({id:`change_${dayTime}_${roll}`,zone:'market',action:'change',state:{dayTime},rolls:[roll,.999999]});
 }
}
for(let amount=0;amount<4;amount++)specs.push({id:'change_amount_'+amount,zone:'market',action:'change',rolls:[0,(amount+.1)/4]});
for(const brain of [0,.5,1,100])specs.push({id:'advice_brain_'+brain,zone:'market',action:'change',player:{brain},rolls:[.7]});
for(const [action,bound]of [['song',.4],['trick',.25]])for(const roll of [0,bound-1e-7,bound,.999999])specs.push({id:action+'_'+roll,zone:'market',action,rolls:[roll]});
for(const wanted of [2,3])specs.push({id:'trick_wanted_'+wanted,zone:'market',action:'trick',player:{wanted},rolls:[.8]});
specs.push({id:'captured_day_now_night',zone:'market',action:'change',state:{dayTime:.5},afterOpenState:{dayTime:0},rolls:[.3,0]});
specs.push({id:'captured_night_now_day',zone:'market',action:'change',state:{dayTime:0},afterOpenState:{dayTime:.5},rolls:[.3,0]});
for(const zone of ['block','market'])for(const action of ['leave','escape'])specs.push({id:zone+'_'+action,zone,action});
const cases=[];
for(const spec of specs){
 reset(spec);if(spec.zone==='block')acts.blockMenu();else acts.panhandle();
 const initial=menu();Object.assign(ui.P,clone(spec.afterOpen||{}));Object.assign(ui.state,clone(spec.afterOpenState||{}));
 const labels={think:'sit on the crate',lottery:'scratch the lottery',change:'ask for change',song:'perform a song',trick:'do a card trick',leave:'leave.'};
 const choice=spec.action==='escape'?null:ui.activeDialogue.opts.find(o=>o.label.startsWith(labels[spec.action]));
 if(spec.action!=='escape')assert.ok(choice&&!choice.disabled,'Source choice missing: '+spec.id);
 ui.closeDialogue();choice?.action?.();
 cases.push({id:spec.id,setup:spec,menu:initial,expected:outcomes()});
}
const timelines=[];
const timelineSpecs=[
 {id:'activate_hold_release',ops:[{key:'down'},{dt:16,held:true},{key:'up'},{dt:16,held:false},{key:'down'}]},
 {id:'deplete_activation',player:{brain:3},ops:[{key:'down'},{dt:16,held:true},{key:'up'},{dt:16,held:false}]},
 {id:'deplete_drain',player:{brain:5.03},ops:[{key:'down'},{dt:16,held:true}]},
 {id:'vision_negative',state:{tweakerT:1,tweakerCdT:1},ops:[{dt:16,held:true},{dt:16,held:true},{key:'down'},{key:'up'},{dt:16,held:false},{key:'down'}]},
 {id:'vision_equal',state:{tweakerT:16,tweakerCdT:16},ops:[{dt:16,held:true},{key:'down'}]},
 {id:'cooldown_only',state:{tweakerCdT:1},ops:[{key:'down'},{dt:16,held:false},{key:'down'}]},
 {id:'stunned_press',player:{stunT:500},ops:[{key:'down'}]},
 {id:'empty_brain_press',player:{brain:0},ops:[{key:'down'}]},
 {id:'empty_brain_cooldown',player:{brain:0},state:{tweakerCdT:99},ops:[{key:'down'}]},
 ...['dialogue','inv','quest','cookmini','title'].map(mode=>({id:'paused_'+mode,state:{mode,tweakerT:100,tweakerCdT:200},ops:[{dt:16,held:true}]})),
 {id:'modal_input_release',ops:[{key:'down'},{open:'block'},{dt:16,held:false},{close:true},{dt:16,held:false}]},
 ...[44949,44950,44951,45000,0].map(autoSaveT=>({id:'autosave_'+autoSaveT,state:{autoSaveT},ops:[{dt:50,held:false},{dt:1,held:false}]})),
];
for(const spec of timelineSpecs){
 reset(spec);const steps=[];
 for(const op of spec.ops){
  if(op.key==='down')await keydown(keyEvent('f'));
  else if(op.key==='up')keyup(keyEvent('f'));
  else if(op.open)acts.blockMenu();
  else if(op.close)ui.closeDialogue();
  else{if(op.held)ui.state.keys.add('f');else ui.state.keys.delete('f');if(ui.state.mode==='playing')update.updateWorld(op.dt);}
  steps.push({op,expected:{...clocks(),brain:ui.P.brain,mode:ui.state.mode,held:ui.state.keys.has('f'),toasts:clone(toasts),saves}});
 }
 timelines.push({id:spec.id,setup:spec,steps});
}
const entries=[];
for(const zone of ZONES){
 const spec={entries:true,zone};reset(spec);const before={x:ui.P.x,y:ui.P.y};update.updateWorld(16);
 assert.ok(ui.state.flags[FLAGS[ZONES.indexOf(zone)]],'Source position did not enter '+zone);
 const first={flags:flagSnapshot(),toasts:clone(toasts),posts:clone(comms.phoneState.posts),saves};update.updateWorld(16);
 entries.push({id:zone,setup:spec,center:[before.x+ui.P.w/2,before.y+ui.P.h/2],first,repeat:{flags:flagSnapshot(),toasts:clone(toasts),posts:clone(comms.phoneState.posts),saves}});
}
{
 const spec={entries:true,overlap:['underpass','trainyard','park'],center:[150,150]};reset(spec);const steps=[];
 for(let i=0;i<3;i++){update.updateWorld(16);steps.push({flags:flagSnapshot(),toasts:clone(toasts),posts:clone(comms.phoneState.posts),saves});}
 entries.push({id:'independent_underpass_else_if_order',setup:spec,center:[150,150],steps});
}
const continuity=[];
for(const kind of ['fresh','restore']){
 reset();ui.state.tweakerT=-9;ui.state.tweakerCdT=1234;ui.state.autoSaveT=44999;ui.state.keys.add('f');
 const before={...clocks(),held:true};await save.saveGame();
 if(kind==='restore')assert.equal(await save.loadGame(),true);
 boot.startGame(kind==='restore');
 continuity.push({kind,before,after:{...clocks(),held:ui.state.keys.has('f')},persistedHasClocks:['tweakerT','tweakerCdT','autoSaveT'].some(k=>Object.hasOwn(persisted,k))});
}
const result={source:'Unchanged activities Block/panhandle callbacks, keyboard listeners, updateWorld, saveGame/loadGame/startGame; clock projections exclude unrelated world effects',menus,cases,timelines,entries,continuity};
const output=stableStringify(result),target=path.join(ROOT,'game3d/tests/fixtures/neighborhood_utilities_reference.json');
if(process.argv.includes('--check'))assert.equal(fs.readFileSync(target,'utf8'),output,'Neighborhood utilities oracle drift; regenerate deliberately');
else fs.writeFileSync(target,output);
console.log(`3D NEIGHBORHOOD UTILITIES ORACLE: PASS (${menus.length} menus / ${cases.length} action cases / ${timelines.length} timelines / ${entries.length} entry cases / ${continuity.length} continuity; unchanged source)`);
