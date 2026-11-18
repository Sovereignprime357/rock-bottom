import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),acts=game.module('src/minigames/activities.js');
const props=game.module('src/data/props.js'),spawns=game.module('src/data/npc_spawns.js');
const update=game.module('src/core/update.js'),save=game.module('src/core/audio_save.js'),start=game.module('src/core/start.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const playerKeys=['x','y','w','h','cash','cred','hp','maxHp','brain','shakes','wanted','iframes','hitFlash','copper','rocks','rockedT','crashT','inventory','equip','rank'];
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const snapshot=()=>({player:pick(ui.P,playerKeys),counters:pick(ui.state.counters,['heistsToday','breakinsToday','copperStripped']),quest:clone(ui.state.quests.copper_sings),achievements:[...ui.state.achievements].sort(),mode:ui.state.mode});
const sites=[...props.COPPER_SITES,...props.BREAKIN_SITES],specs=[];
const choice=(index,roll=.75)=>({index,roll});
for(const site of sites){
 for(let e=0;e<site.entries.length;e++){
  if(site.entries[e].kind==='lockpick')continue;
  for(const roll of site.entries[e].kind==='roll'?[0,.999]:[.75])
   specs.push({id:site.id+'_entry_'+e+'_'+roll,site:site.id,ops:[choice(e,roll),choice(0,.999),choice(1,.999)]});
 }
 const safe=site.entries.findIndex(e=>e.kind!=='lockpick');
 for(let take=0;take<2;take++)for(let exit=0;exit<2;exit++)for(const roll of [0,.999])
  specs.push({id:site.id+'_take_'+take+'_exit_'+exit+'_'+roll,site:site.id,ops:[choice(safe,0),choice(take,.25),choice(exit,roll)]});
 specs.push({id:site.id+'_entry_leave',site:site.id,ops:[choice(site.entries.length)]});
 specs.push({id:site.id+'_take_leave',site:site.id,ops:[choice(safe,0),choice(2)]});
 specs.push({id:site.id+'_cap',site:site.id,counters:{heistsToday:3,breakinsToday:2},ops:[choice(0)]});
}
for(const site of props.BREAKIN_SITES){
 for(let i=0;i<site.gates.length;i++){
  const gate=site.gates[i],player=gate.kind==='tool'?{equip:{shoes:null,hat:null,coat:null,tool:'propane_torch'}}:{cred:gate.cred-1};
  specs.push({id:site.id+'_gate_'+i,site:site.id,player,counters:{breakinsToday:2},ops:[choice(0)]});
 }
}
specs.push(
 {id:'soap_all_literal_records',site:'abandoned',player:{inventory:[{id:'soap',n:'soap',q:3},{id:'food',n:'food',q:1},{id:'soap',n:'soap',q:1}]},ops:[choice(2),choice(2)]},
 {id:'food_one_literal_record',site:'water_dept',player:{inventory:[{id:'food',n:'first',q:7},{id:'food',n:'second',q:1}]},ops:[choice(1),choice(2)]},
 {id:'cash_missing',site:'abandoned',player:{cash:2},ops:[choice(3)]},
 {id:'item_missing',site:'water_dept',player:{inventory:[]},ops:[choice(1)]},
 {id:'entry_fatal_raw_iframes',site:'abandoned',player:{hp:5,iframes:777,rockedT:5000,crashT:4000,wanted:2},ops:[choice(0,.7)]},
 {id:'entry_negative_hp_even_no_cost',site:'cold_not',player:{hp:-1},ops:[choice(1)]},
 {id:'getaway_fatal_retains_take',site:'abandoned',player:{hp:5,iframes:777,rockedT:5000,crashT:4000},ops:[choice(0,0),choice(0,.999),choice(0,.8)]},
 {id:'getaway_hp_cost_before_wanted_death',site:'water_dept',player:{hp:5,wanted:2},ops:[choice(0,0),choice(0,0),choice(0,.999)]},
 {id:'brain_shakes_caps',site:'cold_not',player:{brain:99,shakes:99},ops:[choice(2),choice(1),choice(1,.999)]},
 {id:'copper_achievement_boundary',site:'rust_car',counters:{copperStripped:8},ops:[choice(2),choice(0,0),choice(1,0)]},
 {id:'copper_quest_already_done',site:'rust_car',questDone:true,ops:[choice(2),choice(0,.999),choice(1,0)]},
 {id:'gate_equipped_not_locker',site:'model_home',player:{equip:{shoes:null,hat:null,coat:null,tool:'propane_torch'}},flags:{peteToolLocker:'crowbar'},ops:[choice(0)]},
 {id:'lock_success',site:'abandoned',ops:[choice(1,.75),choice(0),choice(1),choice(2),choice(3),choice(0,0),choice(1,.999)]},
 {id:'lock_wrong_reset_then_success',site:'abandoned',player:{brain:3},ops:[choice(1,.75),choice(0),choice(3),choice(3),choice(0),choice(1),choice(2),choice(3),choice(2)]},
 {id:'lock_giveup_extra',site:'abandoned',ops:[choice(1,.75),choice(4,.4999),choice(2)]},
 {id:'lock_giveup_boundary',site:'abandoned',ops:[choice(1,.75),choice(4,.5),choice(2)]},
 {id:'lock_giveup_fatal',site:'abandoned',player:{hp:5,iframes:700},ops:[choice(1,.75),choice(4,0)]},
 {id:'lock_escape_not_giveup',site:'abandoned',ops:[choice(1,.75),{index:'escape'}]},
 {id:'escape_after_take_keeps_reward',site:'spoil_bank',ops:[choice(0,0),choice(0),{index:'escape'}]}
);
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();spawns.spawnNpcs();
 const site=sites.find(s=>s.id===spec.site),anchor=site.anchor.kind==='locked_building'?props.BUILDINGS.find(b=>b.locked):site.anchor;
 Object.assign(ui.P,{cash:100,cred:60,inventory:[{id:'soap',n:'soap',q:1},{id:'food',n:'a can of food (unmarked)',q:1}],equip:{shoes:null,hat:null,coat:null,tool:'crowbar'},x:anchor.x+anchor.w/2-ui.P.w/2,y:anchor.y+anchor.h+10-ui.P.h/2},clone(spec.player||{}));
 Object.assign(ui.state,{mode:'playing'});Object.assign(ui.state.counters,{heistsToday:0,breakinsToday:0,copperStripped:0},spec.counters||{});Object.assign(ui.state.flags,spec.flags||{});
 if(spec.questDone)ui.state.quests.copper_sings.done=true;
 const setup={player:pick(ui.P,playerKeys),counters:pick(ui.state.counters,['heistsToday','breakinsToday','copperStripped']),flags:clone(spec.flags||{}),questDone:!!spec.questDone};
 let draws=0;game.context.Math.random=()=>{draws++;return .75;};
 acts.startHeist(spec.site);const initial={menu:menu(),expected:snapshot(),draws};const steps=[];
 for(const operation of spec.ops){
  draws=0;game.context.Math.random=()=>{draws++;return operation.roll??.75;};
  if(operation.index==='escape')ui.closeDialogue();
  else{
   const option=ui.activeDialogue?.opts[operation.index];if(!option)throw new Error(spec.id+' missing option '+operation.index);
   if(!option.disabled){ui.closeDialogue();option.action();}
  }
  steps.push({operation,menu:menu(),expected:snapshot(),draws});
 }
 cases.push({id:spec.id,site:spec.site,setup,initial,steps});
}
// Actual engine sort; independently pin all64 six-comparison sign streams and equality.
const sortCases=[];
for(let mask=0;mask<64;mask++)sortCases.push({id:'sign_'+mask,rolls:Array.from({length:6},(_,i)=>(mask&(1<<i))?.75:.25)});
sortCases.push({id:'equality',rolls:[.5,.5,.5,.5,.5,.5]},{id:'mixed_equality',rolls:[.25,.5,.5,.25,.5,.75]});
let seed=1979;for(let i=0;i<32;i++){const rolls=Array.from({length:6},()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;});sortCases.push({id:'seed_'+i,rolls});}
for(const test of sortCases){let draws=0;test.expected=[1,2,3,4].sort(()=>test.rolls[draws++]-.5);test.draws=draws;if(draws>6)throw new Error('unexpected JS comparator schedule');}
// Preserve the observed session-global trigger, rather than believing the word "unlocked".
ui.init_runtime_ui();spawns.spawnNpcs();const abandoned=props.BUILDINGS.find(b=>b.locked);
const center={x:abandoned.x+abandoned.w/2,y:abandoned.y+abandoned.h/2};
const availability={initial:props.copperSiteAt(center.x,center.y)?.id??null};
ui.P.rank=4;ui.state.mode='playing';update.updateWorld(0);availability.afterRank4=props.copperSiteAt(center.x,center.y)?.id??null;
start.startGame(false);availability.afterFresh={rank:ui.P.rank,locked:abandoned.locked,site:props.copperSiteAt(center.x,center.y)?.id??null};
const persisted={version:22,player:{...clone(ui.P),rank:0,cred:0}};game.context.storage={get:async()=>({value:persisted}),set:async()=>{}};
availability.lowerRankLoad={ok:await save.loadGame(),rank:ui.P.rank,locked:abandoned.locked,site:props.copperSiteAt(center.x,center.y)?.id??null};
const target=path.join(root,'game3d/tests/fixtures/heist_reference.json');
const output=JSON.stringify({source:'unchanged startHeist/heistStage/startLockpickMini callbacks; actual V8 Array.sort; updateWorld/startGame/loadGame trigger characterization',cases,sortCases,availability},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Heist oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D HEIST ORACLE: PASS ('+cases.length+' source paths;'+sortCases.length+' exact sort streams;9 sites/4 pins/session availability)');
