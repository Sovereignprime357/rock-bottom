import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),spawns=game.module('src/data/npc_spawns.js');
const discovery=game.module('src/systems/discovery.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const playerKeys=['cash','cred','brain','hp','maxHp','shakes','wanted','iframes','hitFlash','rockedT','dirtySupplies','faction'];
const counterKeys=['lurchDollarDay','sherriSpiderDay','paulieFaceDay','pauliCompliments','kombuchaAskDay','kombuchaComplimentDay','priestVisits','priestDonateDay','churchDonations','plateStealAttempts','plateStolen','stripeBetrayed','mathInteractions','philosopherRepDay'];
const flagKeys=['momHideoutOwned','momRentDay','omalleyFallen','omalleyFallenDead','trainHopperTalkedTo'];
const actorKeys=['id','hp','maxHp','hostile','aggro','dmg','archetype','isOmalleyFallen','speed'];
const labels={
 give:/^(give a dollar|you don't have a dollar)/,lie:/^lie\./,sleeps:/^ask where he sleeps/,
 spider:/^pretend to see/,saw:/^ask what she saw/,compliment:/^compliment/,hears:/^ask what the face hears/,
 fight:/^(fight\.|tell her there is no spider)/,shout:/^match volume/,
 accept:/^accept \$10/,ask_twenty:/^ask for \$20/,ask_again:/^ask her for money/,couch:/^ask mom if you can stay/,
 tic_tac:/^accept the blessed/,donate:/^donate/,steal:/^steal the collection/,
 another:/^(ask for another number|ask where he's been)/,calculates:/^ask what he calculates/,
 trains:/^ask about the trains/,think:/^think about it/,why:/^ask why she's here/,leave:/^leave\./
};
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const snapshot=()=>({
 player:pick(ui.P,playerKeys),counters:pick(ui.state.counters,counterKeys),flags:pick(ui.state.flags,flagKeys),
 quests:Object.fromEntries(['priest_mercy','fallen_priest'].map(k=>[k,pick(ui.state.quests[k],['done','available'])])),
 achievements:[...ui.state.achievements].sort(),discovered:[...ui.state.discoveredVenues].sort(),
 actors:ui.runtime.npcs.filter(n=>['lurch','sherri','paulie','larry','priest','omalley_fallen'].includes(n.id)||n.id.startsWith('sherri_')).map(n=>pick(n,actorKeys))
});
const ops=(actor,...actions)=>actions.map(action=>({actor,action}));
const specs=[
 {id:'lurch_daily',player:{cash:4},ops:ops('lurch','give','give','lie')},
 {id:'lurch_poor',ops:ops('lurch','give')},
 {id:'lurch_discovery_repeat',ops:ops('lurch','sleeps','sleeps')},
 {id:'lurch_fight',ops:ops('lurch','fight')},
 {id:'sherri_daily',ops:ops('sherri','spider','spider')},
 {id:'sherri_two_rooms',ops:ops('sherri','saw','saw','saw')},
 {id:'sherri_fight',ops:ops('sherri','fight')},
 {id:'paulie_fifth',counters:{pauliCompliments:4},ops:ops('paulie','compliment','compliment')},
 {id:'paulie_discovery',ops:ops('paulie','hears','hears')},
 {id:'paulie_fight',ops:ops('paulie','fight')},
 {id:'larry_uncapped',ops:ops('larry','shout','shout','fight')},
 {id:'mom_accept_then_shared_cap',ops:ops('mom','accept','ask_again','compliment','compliment')},
 {id:'mom_twenty_wins',roll:0.3999,ops:ops('mom','ask_twenty')},
 {id:'mom_twenty_fails_equal',roll:0.4,player:{brain:1},ops:ops('mom','ask_twenty')},
 {id:'mom_night',state:{dayTime:0.8},ops:ops('mom','leave')},
 {id:'mom_boundary_day',state:{dayTime:0.75},ops:ops('mom','accept')},
 {id:'mom_couch',player:{cash:30,faction:{street:0,scrap:0,spiritual:10}},ops:ops('mom','couch')},
 {id:'mom_couch_short',player:{cash:29,faction:{street:0,scrap:0,spiritual:10}},ops:ops('mom','couch')},
 {id:'priest_mercy',player:{brain:99,shakes:88},ops:ops('priest','tic_tac','tic_tac')},
 {id:'priest_donation',player:{cash:15},counters:{churchDonations:95},ops:ops('priest','donate','donate')},
 {id:'priest_poor',player:{cash:4},ops:ops('priest','donate')},
 {id:'priest_steal_wins',roll:0.5499,counters:{stripeBetrayed:1},ops:ops('priest','steal')},
 {id:'priest_low_hp_direct_cost',roll:0.55,player:{hp:5,iframes:777,hitFlash:123,wanted:2},ops:ops('priest','steal')},
 {id:'priest_fourth_transform',counters:{priestVisits:3},ops:ops('priest','steal')},
 {id:'priest_spiritual_protects',roll:0.1,counters:{priestVisits:3},player:{faction:{street:0,scrap:0,spiritual:10}},ops:ops('priest','steal')},
 {id:'priest_defensive',flags:{omalleyFallen:true},ops:ops('priest','leave')},
 {id:'math_third_tip',counters:{mathInteractions:2},ops:ops('math','leave')},
 {id:'math_fifteenth_tip',counters:{mathInteractions:14},ops:ops('math','leave')},
 {id:'math_eighteenth_no_tip',counters:{mathInteractions:17},ops:ops('math','leave')},
 {id:'math_nested',ops:[{actor:'math',action:'another'},{actor:'math',action:'another',reuse:true},{actor:'math',action:'leave',reuse:true}]},
 {id:'math_high_brain_low',roll:0.1,player:{brain:0,rockedT:18000},ops:ops('math','calculates')},
 {id:'math_high_brain_upper',roll:0.25,player:{brain:100,rockedT:18000,dirtySupplies:2},ops:ops('math','leave')},
 {id:'math_cash_text',roll:0.45,player:{brain:45.5},ops:ops('math','leave')},
 {id:'hopper_day_nested',player:{brain:1},ops:[{actor:'train_hopper',action:'trains'},{actor:'train_hopper',action:'another'},{actor:'train_hopper',action:'leave',reuse:true}]},
 {id:'hopper_night',state:{dayTime:0.2499},ops:[{actor:'train_hopper',action:null}]},
 {id:'philosopher_daily',ops:ops('philosopher','think','think','why')},
 {id:'philosopher_next_question',state:{day:8},ops:ops('philosopher','think')},
 {id:'new_day_daily_stamps',player:{cash:3},ops:[{actor:'lurch',action:'give'},{actor:'lurch',action:'give',day:2}]}
];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();spawns.spawnNpcs();discovery.init_discovery();Object.assign(ui.state,{mode:'playing',dayTime:0.35},clone(spec.state||{}));
 Object.assign(ui.P,clone(spec.player||{}));Object.assign(ui.state.counters,clone(spec.counters||{}));Object.assign(ui.state.flags,clone(spec.flags||{}));
 game.context.Math.random=()=>spec.roll??0.75;
 const setup={player:pick(ui.P,playerKeys),state:pick(ui.state,['day','dayTime']),counters:pick(ui.state.counters,counterKeys),flags:pick(ui.state.flags,flagKeys)};
 const steps=[];
 for(const op of spec.ops){
  if(op.day!==undefined)ui.state.day=op.day;
  if(!op.reuse){ui.closeDialogue();const actor=ui.runtime.npcs.find(n=>n.id===op.actor);actor.interact(actor);}
  const before=menu(), option=ui.activeDialogue?.opts.find(o=>labels[op.action]?.test(o.label));
  if(option&&!option.disabled){ui.closeDialogue();option.action();}
  steps.push({operation:op,before,after:menu(),expected:snapshot()});
 }
 cases.push({id:spec.id,roll:spec.roll??0.75,setup,steps});
}
const target=path.join(root,'game3d/tests/fixtures/resident_reference.json');
const output=JSON.stringify({source:'unchanged active v22 resident opening and action callbacks',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Resident oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D RESIDENT ORACLE: PASS ('+cases.length+' source fixtures; exact menus, opening effects and transaction state)');
