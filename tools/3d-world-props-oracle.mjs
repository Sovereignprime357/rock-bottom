import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';

const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/world_props_reference.json');
const copy=value=>JSON.parse(JSON.stringify(value));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const pick=(value,keys)=>Object.fromEntries(keys.filter(key=>value[key]!==undefined).map(key=>[key,copy(value[key])]));
const PLAYER=['x','y','w','h','hp','maxHp','cash','copper','cred','brain','shakes','supplies','dirtySupplies','hitters','inventory','equip','weapon','speed','credBonus','charisma','wantedDecayMult','cartMounted','hasPossum'];
const BENCH=['sittingOnBench','benchSitT','benchSitGainT','benchSitPasserT'];
const PHONE=['publicPhoneT','phonePropRingT','publicPhoneAnswered'];
const FLAGS=['introDone','dumpsterPropaneAwarded','peteToolLocker','churchLoadedDumpsterX','churchLoadedDumpsterY'];
const PROP=['type','x','y','w','h','looted','tipsJar','diveCdT'];
const open=(id,offset=0)=>({kind:'open',id,offset});
const choice=index=>({kind:'choice',index});
const change=values=>({kind:'change',values});
const tick=(system,ms)=>({kind:'tick',system,ms});

export async function buildWorldPropsOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const props=game.module('src/data/props.js'),interactions=game.module('src/systems/interactions.js');
 const places=game.module('src/dialogue/vendors_places.js'),update=game.module('src/core/update.js');
 const comms=game.module('src/systems/communications.js'),boot=game.module('src/core/start.js');
 const persistence=game.module('src/core/audio_save.js');
 const canonical=props.PROPS.map((p,index)=>({id:'prop:'+index,index,...pick(p,PROP)})).filter(p=>['dumpster','pay_phone','park_bench'].includes(p.type));
 const dumpster=canonical.find(p=>p.type==='dumpster').id,phone=canonical.find(p=>p.type==='pay_phone').id;
 const benches=canonical.filter(p=>p.type==='park_bench').map(p=>p.id),bench=benches[0];
 const row=id=>{assert.match(id,/^prop:\d+$/);return props.PROPS[Number(id.slice(5))];};
 let draws=0,cosmeticDraws=0,saves=0,cursor=0,rolls=[],roll=.75,persisted=null;
 game.context.storage={async set(_key,value){persisted=copy(value);saves++;},async get(){return persisted?{value:copy(persisted)}:null;}};
 const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
 const propSnapshot=()=>canonical.map(({id,index})=>({id,index,...pick(row(id),PROP)}));
 const state=()=>({mode:ui.state.mode,sittingOnBench:!!ui.state.sittingOnBench,benchSitT:ui.state.benchSitT||0,
  benchSitGainT:ui.state.benchSitGainT||0,benchSitPasserT:ui.state.benchSitPasserT||0,...pick(ui.state,PHONE),
  flags:pick(ui.state.flags,FLAGS),counters:{dumpDives:ui.state.counters.dumpDives||0}});
 const snapshot=()=>({player:pick(ui.P,PLAYER),props:propSnapshot(),state:state(),achievements:[...ui.state.achievements].sort(),
  recognition:copy(ui.state.recognition),recognitionVisit:copy(ui.state.recognitionVisit),
  piles:ui.runtime.cashPiles.map((p,index)=>({...copy(p),id:p.id?.startsWith('cp_phone_church_')?'cp_phone_church_'+index:p.id})),
  posts:copy(comms.phoneState.posts),toast:ui.toastEl.textContent||'',saves});
 const apply=values=>{
  if(values.player){const equip=values.player.equip;Object.assign(ui.P,copy(values.player));if(equip){ui.P.equip={shoes:null,hat:null,coat:null,tool:null,...copy(equip)};ui.applyEquipStats();}}
  Object.assign(ui.state,copy(values.state||{}));Object.assign(ui.state.flags,copy(values.flags||{}));
  Object.assign(ui.state.counters,copy(values.counters||{}));
  for(const [id,fields]of Object.entries(values.props||{}))Object.assign(row(id),copy(fields));
  if(values.achievements)ui.state.achievements=new Set(values.achievements);
  if(values.recognition)ui.state.recognition=copy(values.recognition);
 };
 const at=(p,offset=0)=>{ui.P.x=p.x+(p.w||0)/2-ui.P.w/2+offset;ui.P.y=p.y+(p.h||0)/2-ui.P.h/2;};
 const reset=spec=>{
  game.context.Math.random=()=>.75;ui.init_runtime_ui();props.init_props();boot.startGame(false);ui.closeDialogue();comms.init_communications();
  ui.runtime.npcs=[];ui.runtime.cashPiles=[];ui.runtime.projectiles=[];props.interactiveProps.length=0;ui.particles.length=0;
  Object.assign(ui.P,{cash:20,copper:0,hp:50,brain:70,shakes:20,hitters:0,hasPossum:false});
  ui.P.equip={shoes:null,hat:null,coat:null,tool:null};ui.applyEquipStats();
  Object.assign(ui.state,{mode:'playing',day:1,dayTime:.35,sittingOnBench:false,benchSitT:0,benchSitGainT:0,benchSitPasserT:0,
   publicPhoneT:999999,phonePropRingT:0,publicPhoneAnswered:0,phoneT:1e9,eventT:1e9,momTipT:1e9,ambientT:1e9,dustT:1e9,incidentT:1e9});
  for(const name of Object.keys(ui.state.flags))if(name.endsWith('Entered'))ui.state.flags[name]=true;
  ui.state.flags.introDone=false;ui.state.flags.momIntroFired=true;
  // Keep the full updateWorld call, but remove an unrelated cash-based intro receipt.
  // The clock oracle projects no quest state and never substitutes prop timer arithmetic.
  ui.state.quests.intro_remember.done=true;
  apply(spec.setup||{});at(row(spec.prop||dumpster));
  draws=0;cosmeticDraws=0;saves=0;cursor=0;rolls=spec.rolls||[];roll=spec.roll??.75;persisted=null;
  ui.toastEl.textContent='';game.context.__qa.timers.length=0;
  game.context.Math.random=()=>{draws++;return rolls[cursor++]??roll;};
 };
 const project=(kind,current)=>{
  if(kind==='bench_clock')return {player:{brain:current.player.brain},state:pick(current.state,BENCH),achievements:current.achievements,toast:current.toast};
  if(kind==='phone_clock')return {state:pick(current.state,PHONE),posts:current.posts,toast:current.toast};
  if(kind==='props_clock')return {props:current.props,toast:current.toast};
  if(kind==='continuity')return {state:{...pick(current.state,[...BENCH,...PHONE]),flags:current.state.flags,counters:current.state.counters},props:current.props};
  return current;
 };
 const run=async op=>{
  if(op.kind==='open'){
   const p=row(op.id);ui.closeDialogue();at(p,op.offset||0);
   if(p.type==='park_bench')return {ok:places.tryParkBenchSit()};
   const unlooted=p.type==='dumpster'&&!p.looted;
   interactions.tryInteract();
   if(unlooted&&(op.offset||0)<44)assert.equal(ui.activeDialogue?.name,'THE DUMPSTER','A higher-priority source interaction stole the selected canonical dumpster');
   return {sourceReturn:null};
  }
  if(op.kind==='choice'){
   assert.ok(ui.activeDialogue,'Choice requires actual source menu');const selected=ui.activeDialogue.opts[op.index];assert.ok(selected,'Unknown option '+op.index);
   const enabled=!selected.disabled;if(enabled){
    const rats=ui.activeDialogue.name==='THE DUMPSTER'&&selected.label==='nothing. dumpsters know.';
    const before=draws;ui.closeDialogue();await selected.action?.();
    if(rats){assert.equal(draws-before,30,'Source rat particles changed their terminal draw count');cosmeticDraws+=30;}
   }return {ok:enabled,index:op.index};
  }
  if(op.kind==='escape'){ui.closeDialogue();return {ok:true};}
  if(op.kind==='change'){apply(op.values);return {ok:true};}
  if(op.kind==='tick'){
   assert.ok(Number.isFinite(op.ms)&&op.ms>0);let remaining=op.ms;
   while(remaining>0){const dt=Math.min(50,remaining);if(ui.state.mode==='playing')update.updateWorld(dt);remaining-=dt;}
   return {ok:true};
  }
  if(op.kind==='save'){await persistence.saveGame();return {ok:persisted!==null};}
  if(op.kind==='restore'){assert.ok(persisted,'Restore requires real preceding source save');const ok=await persistence.loadGame();assert.equal(ok,true);boot.startGame(true);return {ok};}
  if(op.kind==='fresh'){boot.startGame(false);return {ok:true};}
  throw Error('Unknown world-prop oracle operation '+op.kind);
 };
 const specs=[];
 // Two filler rolls follow the initial loot and optional Hitter roll. No item math is replicated.
 for(let index=0;index<22;index++)specs.push({kind:'dumpster',id:'filler_'+index,prop:dumpster,rolls:[.1,.9,(index+.25)/22,.1],ops:[open(dumpster),choice(0)]});
 const farSetup=far=>({props:{[dumpster]:{x:1050+900*far,y:840}}});
 for(const far of [0,.25,.250001,.6,.9,1]){
  const none=.3+(1-far)*.2;
  const points=[0,.999999,...[none,none+.3,none+.5,none+.6,none+.68].flatMap(value=>[value-1e-7,value])].filter(value=>value>=0&&value<1);
  for(const [index,r]of [...new Set(points)].entries())specs.push({kind:'dumpster',id:'table_'+far+'_'+index,prop:dumpster,setup:farSetup(far),rolls:[r,...(far>.25?[.9]:[]),.8,.1,.2,.3],ops:[open(dumpster),choice(2)]});
 }
 for(const value of [.039999,.04])specs.push({kind:'dumpster',id:'hitter_boundary_'+value,rolls:[.1,value,.1,.2],ops:[open(dumpster),choice(2)]});
 specs.push({kind:'dumpster',id:'hitter_grant_twice_saved',setup:{player:{hitters:4}},rolls:[.99,0,.1,.2],ops:[open(dumpster),choice(2)]});
 specs.push({kind:'dumpster',id:'loose_cash_independent_rolls',rolls:[.4,.9,0,.999,.1,.2],ops:[open(dumpster),choice(2)]});
 specs.push({kind:'dumpster',id:'tips_independent_rolls_escape',setup:{props:{[dumpster]:{tipsJar:true}}},rolls:[0,.999,.3,.9,0,.999,.1,.2],ops:[open(dumpster),{kind:'escape'}]});
 for(const condition of ['empty','equipped','awarded','locker','crowbar_locker','captured_equipped']){
  const setup={};
  if(condition==='equipped')setup.player={equip:{tool:'propane_torch'}};
  if(condition==='awarded')setup.flags={dumpsterPropaneAwarded:true};
  if(condition==='locker')setup.flags={peteToolLocker:'propane_torch'};
  if(condition==='crowbar_locker'){setup.player={equip:{tool:'crowbar'}};setup.flags={peteToolLocker:'propane_torch'};}
  const blocked=condition==='equipped'||condition==='awarded';
  specs.push({kind:'dumpster',id:'torch_'+condition,setup,rolls:[.99,.9,...(blocked?[]:[0]),.1,.2,.3],ops:[open(dumpster),...(condition==='captured_equipped'?[change({player:{equip:{tool:'propane_torch'}}})]:[]),choice(2)]});
 }
 for(const value of [.069999,.07])specs.push({kind:'dumpster',id:'torch_roll_boundary_'+value,rolls:[.99,.9,value,.1,.2,.3],ops:[open(dumpster),choice(2)]});
 specs.push({kind:'dumpster',id:'climb_marks_without_save',rolls:[.4,.9,.1,.2,.1,.2],ops:[open(dumpster),choice(3),open(dumpster)]});
 specs.push({kind:'dumpster',id:'escape_preserves_dumpster',rolls:[.4,.9,.1,.2,.1,.2],ops:[open(dumpster),{kind:'escape'}]});
 specs.push({kind:'dumpster',id:'already_looted_keeps_tips',setup:{props:{[dumpster]:{looted:true,tipsJar:true,diveCdT:3000}}},ops:[open(dumpster)]});
 specs.push({kind:'dumpster',id:'captured_offer_survives_prop_reset',rolls:[.1,.9,4.25/22,.1],ops:[open(dumpster),change({props:{[dumpster]:{looted:false,tipsJar:true,diveCdT:12}}}),choice(0)]});
 for(const hp of [99,100])specs.push({kind:'dumpster',id:'food_hp_cap_'+hp,setup:{player:{hp}},rolls:[.1,.9,.001,.1],ops:[open(dumpster),choice(0)]});
 for(const offset of [43.99,44])specs.push({kind:'dumpster',id:'dumpster_radius_'+offset,ops:[open(dumpster,offset)]});
 for(let index=0;index<10;index++)specs.push({kind:'phone',id:'phone_line_'+index,prop:phone,setup:{state:{phonePropRingT:30000}},rolls:[(index+.25)/10],ops:[open(phone),open(phone)]});
 for(const count of [3,4,5])specs.push({kind:'phone',id:'phone_achievement_'+count,prop:phone,setup:{state:{phonePropRingT:1,publicPhoneAnswered:count}},rolls:[0],ops:[open(phone)]});
 specs.push({kind:'phone',id:'phone_brain_floor',prop:phone,setup:{player:{brain:2},state:{phonePropRingT:1}},rolls:[.525],ops:[open(phone)]});
 specs.push({kind:'phone',id:'phone_hp_cap',prop:phone,setup:{player:{hp:99},state:{phonePropRingT:1}},rolls:[.825],ops:[open(phone)]});
 for(const offset of [37.99,38])specs.push({kind:'phone',id:'phone_radius_'+offset,prop:phone,setup:{state:{phonePropRingT:1}},rolls:[0],ops:[open(phone,offset)]});
 for(const offset of [49.99,50])specs.push({kind:'bench',id:'bench_radius_'+offset,prop:bench,ops:[open(bench,offset)]});
 specs.push({kind:'bench',id:'bench_toggle_another_bench',prop:bench,ops:[open(bench),change({state:{benchSitT:2999,benchSitGainT:333,benchSitPasserT:444}}),open(benches[1])]});
 specs.push({kind:'bench',id:'bench_repeat_same_visit',prop:bench,ops:[open(bench),open(bench),open(bench)]});
 for(const system of ['props','bench','phone'])for(const mode of ['dialogue','paused','cookmini'])specs.push({kind:system+'_clock',id:system+'_paused_'+mode,prop:system==='bench'?bench:system==='phone'?phone:dumpster,setup:{state:{mode,sittingOnBench:true,benchSitT:59999,benchSitGainT:1999,publicPhoneT:1,phonePropRingT:0},props:{[dumpster]:{looted:true,diveCdT:1}}},ops:[tick(system,50)]});
 for(const before of [49,50,51])specs.push({kind:'props_clock',id:'cooldown_'+before,setup:{props:{[dumpster]:{looted:true,diveCdT:before}}},ops:[tick('props',50)]});
 specs.push({kind:'props_clock',id:'cooldown_nonpositive_does_not_reset',setup:{props:{[dumpster]:{looted:true,diveCdT:0}}},ops:[tick('props',50)]});
 specs.push({kind:'bench_clock',id:'bench_gain_exact_boundary',prop:bench,setup:{state:{sittingOnBench:true,benchSitT:0,benchSitGainT:1999}},ops:[tick('bench',1),tick('bench',1999),tick('bench',1)]});
 specs.push({kind:'bench_clock',id:'bench_brain_cap',prop:bench,setup:{player:{brain:100},state:{sittingOnBench:true,benchSitGainT:1999}},ops:[tick('bench',1)]});
 specs.push({kind:'bench_clock',id:'bench_achievement_exact_boundary',prop:bench,setup:{state:{sittingOnBench:true,benchSitT:59999,benchSitGainT:999}},ops:[tick('bench',1),tick('bench',50)]});
 for(let index=0;index<5;index++)specs.push({kind:'bench_clock',id:'bench_passer_'+index,prop:bench,setup:{state:{sittingOnBench:true,benchSitT:60000,benchSitPasserT:29999},achievements:['bench_press']},rolls:[(index+.25)/5],ops:[tick('bench',1),tick('bench',1)]});
 for(const intro of [false,true])for(const before of [null,49,50,51,0,-1])specs.push({kind:'phone_clock',id:'phone_timer_'+intro+'_'+before,prop:phone,setup:{state:{publicPhoneT:before},flags:{introDone:intro}},rolls:[.25],ops:[tick('phone',50)]});
 for(const before of [49,50,51])specs.push({kind:'phone_clock',id:'phone_ring_'+before,prop:phone,setup:{state:{publicPhoneT:500,phonePropRingT:before},flags:{introDone:true}},ops:[tick('phone',50),tick('phone',1)]});
 const continued={sittingOnBench:true,benchSitT:54321,benchSitGainT:1234,benchSitPasserT:2345,publicPhoneT:123456,phonePropRingT:23456,publicPhoneAnswered:3};
 specs.push({kind:'continuity',id:'fresh_retains_props_and_bench',setup:{state:continued,props:{[dumpster]:{looted:true,tipsJar:true,diveCdT:45678}}},ops:[{kind:'fresh'}]});
 specs.push({kind:'continuity',id:'restore_retains_live_clocks_and_prop_flags',setup:{state:continued,props:{[dumpster]:{looted:false,tipsJar:true,diveCdT:45678}}},ops:[{kind:'save'},change({state:{benchSitT:11111,benchSitGainT:222,benchSitPasserT:333,publicPhoneT:654321,phonePropRingT:9876,publicPhoneAnswered:9},props:{[dumpster]:{looted:true,tipsJar:false,diveCdT:123}}}),{kind:'restore'}]});
 specs.push({kind:'continuity',id:'restore_overlays_saved_true_only',setup:{state:continued,props:{[dumpster]:{looted:true,tipsJar:false,diveCdT:987}}},ops:[{kind:'save'},change({props:{[dumpster]:{looted:false,tipsJar:true,diveCdT:321}}}),{kind:'restore'}]});
 const cases=[];
 for(const spec of specs){
  reset(spec);const setup=snapshot(),steps=[];
  for(const operation of spec.ops){
   ui.toastEl.textContent='';const result=await run(operation),current=snapshot();
   const scoped=spec.kind.endsWith('_clock')||spec.kind==='continuity';
   steps.push({operation:copy(operation),result,menu:menu(),expected:project(spec.kind,current),draws,sourceDraws:draws,mechanicDraws:draws-cosmeticDraws,cosmeticDraws,compareDraws:!scoped,compareSaves:spec.kind!=='continuity'});
  }
  cases.push({kind:spec.kind,id:spec.id,prop:spec.prop||dumpster,setup,rolls:spec.rolls||[],roll:spec.roll??.75,operations:copy(spec.ops),steps});
 }
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-world-props-reference',source:{authority:'unchanged tryInteract/startDumpsterDive/menu callbacks/answerPublicPhone/tryParkBenchSit/updateWorld/save/load/start',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},
  counts:{cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),fillers:22,phoneLines:10,passerLines:5},props:canonical,cases,
  scope:'Action snapshots compare full scoped state and gameplay draws. World clocks/continuity project only this owner; sourceDraws are retained but compareDraws=false because actual whole-world/start functions also own unrelated draws. Rats subtract exactly30 source cosmetic draws only after verifying the actual terminal callback. Physical church cash staging remains an explicit separate3D adaptation.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildWorldPropsOracle());
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'World prop oracle drift; regenerate deliberately.');else fs.writeFileSync(OUTPUT,output);
 const result=JSON.parse(output);console.log(`3D WORLD PROPS ORACLE: PASS (${result.counts.cases} source paths; ${result.counts.steps} steps; 22 fillers,10 phone lines,5 passers)`);
}
