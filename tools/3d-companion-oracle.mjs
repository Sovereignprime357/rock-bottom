import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),g=await loadModularGame();
const ui=g.module('src/core/runtime_ui.js'),a=g.module('src/dialogue/neighborhood_a.js');
const com=g.module('src/systems/communications.js'),spawns=g.module('src/data/npc_spawns.js');
const update=g.module('src/core/update.js'),ai=g.module('src/systems/npc_ai.js');
const save=g.module('src/core/audio_save.js'),start=g.module('src/core/start.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const ids=['possum','pet_possum','scrap_dog','freed_dog_follower'];
const playerKeys=['x','y','w','h','cash','cred','brain','hasPossum','inventory','faction'];
const stateKeys=['freedDogT','freedDogFollowT','freedDogFirstReturn'];
const actorKeys=['id','name','sprite','x','y','w','h','hp','maxHp','speed','hostile','archetype','chained','tailWag','isPet','freedFollower','revealT'];
const actors=()=>ui.runtime.npcs.filter(n=>ids.includes(n.id)).map(n=>({...pick(n,actorKeys),dead:!!n.dead}));
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
let saves=0,draws=0,cursor=0,rolls=[],fallback=.75;
const snapshot=()=>({player:pick(ui.P,playerKeys),state:pick(ui.state,stateKeys),quest:clone(ui.state.quests.scrap_dog),prophecies:ui.state.counters.possumProphecies,achievements:[...ui.state.achievements].sort(),actors:actors(),piles:clone(ui.runtime.cashPiles),posts:clone(com.phoneState.posts),mode:ui.state.mode,toast:ui.toastEl.textContent,saves});
const reset=spec=>{
 ui.init_runtime_ui();com.init_communications();spawns.spawnNpcs();
 ui.runtime.npcs=ui.runtime.npcs.filter(n=>['possum','scrap_dog'].includes(n.id));ui.runtime.cashPiles=[];ui.runtime.projectiles=[];
 Object.assign(ui.P,{x:3000,y:4000,hasPossum:false,wanted:0,shakes:0},clone(spec.player||{}));
 Object.assign(ui.state,{mode:'playing',day:1,dayTime:.35,ambientT:999999,dustT:999999,publicPhoneT:999999,phoneT:999999,eventT:999999,momTipT:999999},clone(spec.state||{}));
 Object.assign(ui.state.flags,{introDone:false,momIntroFired:true});
 Object.assign(ui.state.quests.scrap_dog,clone(spec.quest||{}));ui.state.counters.possumProphecies=spec.counter||0;
 g.context.Math.random=()=>.75;
 if(spec.pet)com.spawnPetPossum();
 if(spec.follower)a.spawnFreedDogFollower();
 com.init_communications();ui.toastEl.textContent='';saves=0;draws=0;cursor=0;rolls=spec.rolls||[];fallback=spec.roll??.75;
 g.context.storage={set:async()=>{saves++;},get:async()=>null};
 for(const n of ui.runtime.npcs){n.x=3000;n.y=4040;n.chatterCd=999999;}
 if(spec.actor)Object.assign(ui.runtime.npcs.find(n=>n.id===spec.actor.id),clone(spec.actor));
 if(spec.only)ui.runtime.npcs=ui.runtime.npcs.filter(n=>n.id===spec.only);
 if(spec.piles)ui.runtime.cashPiles=clone(spec.piles);
 g.context.__qa.timers.length=0;
 g.context.Math.random=()=>{draws++;return rolls[cursor++]??fallback;};
};
const open=id=>{
 const n=ui.runtime.npcs.find(n=>n.id===id);
 if(id==='possum')a.possumDialogue();
 else if(id==='scrap_dog')a.scrapDogDialogue(n);
 else n.interact(n);
};
const specs=[];
for(const state of ['idle','left','fed','freed'])for(const food of [false,true])specs.push({id:'menu_dog_'+state+'_'+food,quest:{state},player:{inventory:food?[{id:'food',n:'a can of food (unmarked)',q:1}]:[]},ops:[{kind:'open',id:'scrap_dog'}]});
for(const id of ['possum','pet_possum','freed_dog_follower'])specs.push({id:'menu_'+id,pet:id==='pet_possum',follower:id==='freed_dog_follower',ops:[{kind:'open',id}]});
for(let line=0;line<16;line++)for(let effect=0;effect<4;effect++)specs.push({id:`prophecy_${line}_${effect}`,rolls:[(line+.1)/16,(effect+.1)/4],ops:[{kind:'open',id:'possum'},{kind:'choice',index:0}]});
for(const count of [4,9,10])specs.push({id:'prophecy_threshold_'+count,counter:count,rolls:[.25,.75],ops:[{kind:'open',id:'possum'},{kind:'choice',index:0},{kind:'spawn_due'}]});
specs.push({id:'prophecy_brain_floor',player:{brain:2},rolls:[0,.25],ops:[{kind:'open',id:'possum'},{kind:'choice',index:0}]});
for(const state of ['idle','left'])for(const q of [1,3])specs.push({id:`feed_${state}_${q}`,quest:{state},player:{inventory:[{id:'food',n:'a can of food (unmarked)',q},{id:'food',n:'a can of food (unmarked)',q:1}]},ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:0}]});
for(const state of ['idle','left','fed','freed'])specs.push({id:'leave_'+state,quest:{state},ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:state==='fed'?1:state==='freed'?0:2}]});
for(const id of ['scrap_dog','freed_dog_follower','possum'])specs.push({id:'pet_'+id,quest:{state:'fed'},follower:id==='freed_dog_follower',ops:[{kind:'open',id},{kind:'choice',index:id==='possum'?1:0},{kind:'open',id},{kind:'choice',index:id==='possum'?1:0}]});
specs.push({id:'release_blocks_reacquire',pet:true,ops:[{kind:'open',id:'pet_possum'},{kind:'choice',index:0},{kind:'spawn'}]});
specs.push({id:'dead_blocks_reacquire',pet:true,actor:{id:'pet_possum',dead:true},ops:[{kind:'spawn'}]});
specs.push({id:'spawn_once',ops:[{kind:'spawn'},{kind:'spawn'}]});
for(const state of ['idle','left'])specs.push({id:'free_'+state,quest:{state},ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:1},...[0,1,2,3].map(index=>({kind:'choice',index}))]});
specs.push({id:'lock_wrong_then_success',player:{brain:1},ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:1},{kind:'choice',index:1},...[0,1,2,3].map(index=>({kind:'choice',index}))]});
specs.push({id:'lock_give_up',ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:1},{kind:'choice',index:4}]});
specs.push({id:'lock_escape',ops:[{kind:'open',id:'scrap_dog'},{kind:'choice',index:1},{kind:'escape'}]});
const cases=[];
for(const spec of specs){
 reset(spec);const setup=snapshot(),steps=[];
 for(const op of spec.ops){
  if(op.kind==='open')open(op.id);
  else if(op.kind==='choice'){const choice=ui.activeDialogue.opts[op.index];if(!choice.disabled){ui.closeDialogue();await choice.action?.();}}
  else if(op.kind==='escape')ui.closeDialogue();
  else if(op.kind==='spawn')com.spawnPetPossum();
  else if(op.kind==='spawn_due'){const timers=g.context.__qa.timers.filter(t=>t[0]==='timeout'&&t[1]===com.spawnPetPossum);for(const timer of timers)timer[1]();}
  steps.push({operation:op,menu:menu(),expected:snapshot(),draws,spawnDelays:g.context.__qa.timers.filter(t=>t[0]==='timeout'&&t[1]===com.spawnPetPossum).map(t=>t[2])});
 }
 cases.push({id:spec.id,rolls:spec.rolls||[],roll:spec.roll??.75,setup,steps});
}
const worlds=[];
for(const spec of [
 {id:'absence_above',quest:{state:'freed'},state:{freedDogT:17}},
 {id:'absence_equality',quest:{state:'freed'},state:{freedDogT:16}},
 {id:'absence_zero',quest:{state:'freed'},state:{freedDogT:0}},
 {id:'follow_above',quest:{state:'freed'},follower:true,state:{freedDogFollowT:17}},
 {id:'follow_equality',quest:{state:'freed'},follower:true,state:{freedDogFollowT:16}},
 {id:'follow_below',quest:{state:'freed'},follower:true,state:{freedDogFollowT:1}},
 {id:'tail_near',actor:{id:'scrap_dog',x:3000,y:4040,tailWag:.99}},
 {id:'tail_boundary',actor:{id:'scrap_dog',x:3001,y:4106,tailWag:.5}},
 {id:'tail_far_floor',actor:{id:'scrap_dog',x:3000,y:4200,tailWag:.01}},
 {id:'dead_dog_no_wag',actor:{id:'scrap_dog',dead:true,tailWag:.3}},
 {id:'unchained_no_wag',actor:{id:'scrap_dog',chained:false,tailWag:.3}},
]){
 reset(spec);Object.assign(ui.state,spec.state||{});const setup=snapshot();update.updateWorld(16);
 worlds.push({id:spec.id,setup,expected:{state:pick(ui.state,stateKeys),actors:actors()},roll:.75});
}
const reveals=[];
for(const spec of [
 {id:'empty',piles:[]},
 {id:'uncollected',piles:[{id:'qa',x:2500,y:4500,amt:12,collected:false}]},
 {id:'collected_skipped',piles:[{id:'old',x:2500,y:4500,amt:12,collected:true},{id:'qa',x:2500,y:4500,amt:0,equip:'priest_collar',collected:false}]},
 {id:'not_due',actor:{id:'pet_possum',revealT:17},piles:[{id:'qa',x:2500,y:4500,amt:12,collected:false}]},
 {id:'equal_due',actor:{id:'pet_possum',revealT:16},piles:[{id:'qa',x:2500,y:4500,amt:12,collected:false}]},
]){
 reset({...spec,pet:true,only:'pet_possum'});const setup=snapshot();ai.updateNpcActors(16);
 reveals.push({id:spec.id,setup,expected:snapshot(),draws,mechanicDraws:draws-(ui.particles.length>=6&&spec.id!=='not_due'&&spec.id!=='empty'?12:0),roll:.75});
}
// Characterize actual defects separately; these are not expected3D behavior.
reset({pet:true});ui.P.hasPossum=true;Object.assign(ui.state,{freedDogT:12345,freedDogFollowT:23456,freedDogFirstReturn:true});
let persisted;g.context.storage={set:async(k,v)=>{persisted=clone(v);},get:async()=>({value:persisted})};await save.saveGame();
const omitted={hasPossum:!('hasPossum'in persisted.player),...Object.fromEntries(stateKeys.map(k=>[k,!(k in persisted)]))};
await save.loadGame();start.startGame(true);
const ghost={hasPossum:ui.P.hasPossum,livePet:ui.runtime.npcs.some(n=>n.id==='pet_possum'&&!n.dead),state:pick(ui.state,stateKeys)};
a.spawnFreedDogFollower();ui.runtime.npcs.find(n=>n.id==='freed_dog_follower').dead=true;a.spawnFreedDogFollower();
const duplicateDogs=ui.runtime.npcs.filter(n=>n.id==='freed_dog_follower').map(n=>!!n.dead);
const output=JSON.stringify({source:'unchanged active dialogue/spawn callbacks, updateWorld/updateNpcActors, save/load/start;16 authored local fallback lines',cases,worlds,reveals,sourceDefects:{omitted,ghost,duplicateDogs}},null,2)+'\n';
const target=path.join(root,'game3d/tests/fixtures/companion_reference.json');
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Companion oracle drift');}
else fs.writeFileSync(target,output);
console.log(`3D COMPANION ORACLE: PASS (${cases.length} dialogue paths/${worlds.length} world boundaries/${reveals.length} reveal paths; original lifecycle defects characterized)`);
