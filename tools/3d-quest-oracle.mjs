import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),spawns=game.module('src/data/npc_spawns.js');
const recognition=game.module('src/systems/recognition.js'),discovery=game.module('src/systems/discovery.js');
const update=game.module('src/core/update.js'),dialogue=game.module('src/dialogue/neighborhood_b.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const playerKeys=['cash','cred','rocks','copper','supplies','brain','wanted','tonyOffenses','stripeLoyalty','charisma','weapon','equip','inventory','faction'];
const counterKeys=['barbVisits','barbPacketsToday','stripeVisits','stripeFencedToday','stripeSpiritualDayHits','stripeSpiritualDayHitsDay','stripeBetrayed','pigeonVisits','pigeonTrade'];
const flagKeys=['daveHasCrossword','hasCrossword','hasStripePackage','stripeBetrayed','crownSpotIdx'];
const questKeys=['barb_crossword','stripe_package','pigeon_crown','conductor'];
const stateKeys=['day','dayTime','barbAside','crownPickup','conductorWaitT','bossActive','bossKind','bossPhase','coopMode'];
const actorKeys=['id','hp','maxHp','hostile','aggro','asleep','isAlly','allyTarget','speed','dmg','coatsOff'];
const labels={
 buy_one:/^(buy 1 packet|a packet is)/,buy_five:/^(buy 5 packets\.|5 packets is)/,bulk_closed:/^buy 5 packets bulk/,packets_closed:/^buy packets/,
 contents:/^ask what's in/,clue:/^ask what 14 across is/,answer:/^ask what 14 across was/,return_crossword:/^give barb/,
 demand:/^demand/,pay_ransom:/^(pay \$20|you don't have \$20)/,fight_dave:/^fight him/,pickpocket:/^pickpocket/,wake:/^wake him/,listen:/^listen for/,
 buy_rock:/^(buy stripe|you can't afford)/,fence_one:/^(sell 1 rock|you have no rocks)/,fence_bulk:/^(sell rocks bulk|stripe wants 3)/,fence_closed:/^sell rocks to stripe/,
 package:/^(stripe leans|ask about the package)/,take_package:/^take it/,pass_package:/^pass\./,about:/^ask stripe about/,agree_coop:/^agree\./,decline_coop:/^decline\. \(the deal/,
 apologize:/^try to apologize/,sell_copper:/^sell 3 PURE/,train:/^ask when/,secret:/^(pay \$2 for|you don't have \$2\.)/,crown:/^ask about the crown/,
 accept_crown:/^accept the search/,decline_crown:/^decline\.$/,leave:/^(leave\.|\+\$40)/,sprint:/^sprint\./
};
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const snapshot=(lifecycle=false)=>({
 player:pick(ui.P,playerKeys.filter(k=>!lifecycle||k!=='brain')),
 counters:pick(ui.state.counters,counterKeys),flags:pick(ui.state.flags,flagKeys),
 state:pick(ui.state,stateKeys.filter(k=>k!=='dayTime')),rocksFenced:ui.P.lifetime.rocksFenced||0,
 quests:Object.fromEntries(questKeys.map(k=>[k,pick(ui.state.quests[k],['done','available'])])),
 achievements:[...ui.state.achievements].sort(),recognition:clone(ui.state.recognition),
 actors:ui.runtime.npcs.filter(n=>['dave','stripe','tony'].includes(n.id)).map(n=>pick(n,actorKeys))
});
const ops=(actor,...actions)=>actions.map(action=>({actor,action}));
const nested=(actor,first,second)=>[{actor,action:first},{actor,action:second,reuse:true}];
const crossword={barb_crossword:{available:true}};
const holding={hasStripePackage:true};
const packageItem={id:'stripe_package',n:"stripe's sealed package",q:1};
const specs=[
 {id:'barb_first_clue',ops:ops('barb','clue')},
 {id:'barb_second_offer',counters:{barbVisits:1},ops:ops('barb','leave')},
 {id:'barb_aside_once',state:{barbAside:true},ops:ops('barb','contents','leave')},
 {id:'barb_bulk_single_cap',player:{cash:100},ops:ops('barb','buy_five','buy_one','packets_closed')},
 {id:'barb_bulk_does_not_fit',player:{cash:100},counters:{barbPacketsToday:2},ops:ops('barb','bulk_closed')},
 {id:'barb_poor',player:{cash:4},ops:ops('barb','buy_one')},
 {id:'barb_discount',player:{cash:100,charisma:1,equip:{hat:'pigeon_crown',coat:null,shoes:null,tool:null}},ops:ops('barb','buy_five')},
 {id:'barb_return_outside_cap',counters:{barbPacketsToday:6},quests:crossword,flags:{hasCrossword:true},player:{inventory:[{id:'crossword',n:"barb's saturday crossword",q:1},{id:'crossword',n:"barb's saturday crossword",q:1}]},ops:[...nested('barb','return_crossword','leave'),...nested('barb','answer','leave')]},
 {id:'dave_pickpocket_success',roll:0.6999,ops:ops('dave','pickpocket','pickpocket')},
 {id:'dave_pickpocket_boundary',roll:0.7,ops:ops('dave','pickpocket','listen')},
 {id:'dave_wake_listen_floor',player:{brain:3},ops:ops('dave','wake','listen')},
 {id:'dave_cred_demand',player:{cred:3},quests:crossword,flags:{daveHasCrossword:true},ops:ops('dave','demand')},
 {id:'dave_ransom',player:{cash:20,cred:2},quests:crossword,flags:{daveHasCrossword:true},ops:nested('dave','demand','pay_ransom')},
 {id:'dave_ransom_poor',player:{cash:19},quests:crossword,flags:{daveHasCrossword:true},ops:nested('dave','demand','pay_ransom')},
 {id:'dave_ransom_fight',quests:crossword,flags:{daveHasCrossword:true},ops:nested('dave','demand','fight_dave')},
 {id:'dave_already_holds',quests:crossword,flags:{daveHasCrossword:true,hasCrossword:true},ops:ops('dave','leave')},
 {id:'stripe_soap',roll:0.3999,player:{tonyOffenses:2},ops:ops('stripe','buy_rock')},
 {id:'stripe_rock_boundary',roll:0.4,player:{stripeLoyalty:4},ops:ops('stripe','buy_rock')},
 {id:'stripe_poor',player:{cash:7},ops:ops('stripe','buy_rock')},
 {id:'stripe_bulk_all_brackets',player:{rocks:15,faction:{street:0,scrap:0,spiritual:8}},ops:ops('stripe','fence_bulk','fence_closed')},
 {id:'stripe_bulk_only_one_room',player:{rocks:3},counters:{stripeFencedToday:9},ops:ops('stripe','fence_bulk')},
 {id:'stripe_bulk_needs_three',player:{rocks:2},ops:ops('stripe','fence_bulk')},
 {id:'stripe_one_bracket_edges',player:{rocks:8},counters:{stripeFencedToday:2},ops:ops('stripe','fence_one','fence_one','fence_one','fence_one','fence_one')},
 {id:'stripe_spiritual_new_day',player:{rocks:1,faction:{street:0,scrap:0,spiritual:8}},state:{day:2},counters:{stripeSpiritualDayHits:3,stripeSpiritualDayHitsDay:1},ops:ops('stripe','fence_one')},
 {id:'stripe_third_package_take',counters:{stripeVisits:2},ops:[...nested('stripe','package','take_package'),...ops('stripe','leave')]},
 {id:'stripe_package_pass_then_return',counters:{stripeVisits:2},ops:[...nested('stripe','package','pass_package'),...nested('stripe','package','take_package')]},
 {id:'stripe_available_reoffer',quests:{stripe_package:{available:true}},ops:nested('stripe','package','take_package')},
 {id:'stripe_betrayed',flags:{stripeBetrayed:true},ops:ops('stripe','apologize')},
 {id:'stripe_about',ops:ops('stripe','about')},
 {id:'stripe_coop_decline',player:{stripeLoyalty:5},ops:[...nested('stripe','about','decline_coop'),...ops('stripe','buy_rock')]},
 {id:'stripe_coop_agree',player:{stripeLoyalty:5},ops:[...nested('stripe','about','agree_coop'),{actor:'stripe',action:null}]},
 {id:'conductor_copper',player:{copper:6},ops:ops('conductor','sell_copper','sell_copper','train')},
 {id:'conductor_short',player:{copper:2},ops:ops('conductor','sell_copper')},
 {id:'pigeon_secret_twentieth',player:{cash:4},counters:{pigeonTrade:18},ops:ops('pigeon','secret','secret')},
 {id:'pigeon_poor',player:{cash:1},ops:ops('pigeon','secret')},
 {id:'pigeon_second_accept',counters:{pigeonVisits:1},ops:[...nested('pigeon','crown','accept_crown'),...ops('pigeon','leave')]},
 {id:'pigeon_decline_reuses_seed',roll:0.1,counters:{pigeonVisits:1},ops:[...nested('pigeon','crown','decline_crown'),...nested('pigeon','crown','accept_crown')]},
 {id:'pigeon_preserved_spot',flags:{crownSpotIdx:2},counters:{pigeonVisits:1},ops:nested('pigeon','crown','accept_crown')},
 {id:'pigeon_done',quests:{pigeon_crown:{done:true}},ops:ops('pigeon','leave')},
 ...[0.3499,0.35,0.6499,0.65,0.8999,0.9].map(roll=>({id:'package_'+String(roll).replace('.','_'),roll,flags:holding,player:{wanted:2,inventory:[packageItem,packageItem]},package:true,ops:[]})),
 {id:'package_flag_only',roll:0.1,flags:holding,package:true,ops:[]},
 {id:'delivery',flags:holding,quests:{stripe_package:{available:true}},player:{inventory:[packageItem,packageItem]},lifecycle:{distance:0,dt:0}},
 {id:'delivery_done_no_second_reward',flags:holding,quests:{stripe_package:{done:true}},lifecycle:{distance:0,dt:0}},
 {id:'delivery_boundary',flags:holding,lifecycle:{distance:60,dt:0}},
 {id:'delivery_dead_conductor',flags:holding,lifecycle:{distance:0,dt:0,dead:true}},
 {id:'conductor_wait_60s',state:{conductorWaitT:59950},lifecycle:{distance:79.9,dt:50}},
 {id:'conductor_wait_boundary',state:{conductorWaitT:59950},lifecycle:{distance:80,dt:50}},
 {id:'conductor_wait_dead_freezes',state:{conductorWaitT:59950},lifecycle:{distance:0,dt:50,dead:true}},
 {id:'crown_collect',state:{crownPickup:{x:3000,y:4000,collected:false}},quests:{pigeon_crown:{available:true}},lifecycle:{crown:true,distance:17.9,dt:0}},
 {id:'crown_boundary',state:{crownPickup:{x:3000,y:4000,collected:false}},lifecycle:{crown:true,distance:18,dt:0}},
 {id:'crown_already_done',state:{crownPickup:{x:3000,y:4000,collected:false}},quests:{pigeon_crown:{done:true}},lifecycle:{crown:true,distance:0,dt:0}}
];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();spawns.spawnNpcs();discovery.init_discovery();recognition.init_recognition();
 Object.assign(ui.state,{mode:'playing',dayTime:0.35},clone(spec.state||{}));
 Object.assign(ui.P,clone(spec.player||{}));Object.assign(ui.state.counters,clone(spec.counters||{}));Object.assign(ui.state.flags,clone(spec.flags||{}));
 for(const [key,value]of Object.entries(spec.quests||{}))Object.assign(ui.state.quests[key],clone(value));
 game.context.Math.random=()=>spec.roll??0.75;
 const setup={player:pick(ui.P,playerKeys),state:pick(ui.state,stateKeys),counters:pick(ui.state.counters,counterKeys),flags:pick(ui.state.flags,flagKeys),quests:Object.fromEntries(questKeys.map(k=>[k,pick(ui.state.quests[k],['done','available'])]))};
 const steps=[];
 for(const op of spec.ops||[]){
  if(!op.reuse){
   ui.closeDialogue();const actor=ui.runtime.npcs.find(n=>n.id===op.actor);
   ui.P.x=actor.x+(actor.w-ui.P.w)/2;ui.P.y=actor.y+(actor.h-ui.P.h)/2;
   recognition.recordNpcBother(op.actor);actor.interact(actor);
  }
  const before=menu(),option=ui.activeDialogue?.opts.find(o=>labels[op.action]?.test(o.label));
  if(op.action!==null&&!option)throw new Error(spec.id+' missing action '+op.action);
  if(option&&!option.disabled){ui.closeDialogue();option.action();}
  steps.push({operation:op,before,after:menu(),expected:snapshot()});
 }
 if(spec.package){dialogue.openStripePackage();steps.push({operation:{kind:'package'},after:menu(),expected:snapshot()});}
 if(spec.lifecycle){
  const op=spec.lifecycle,conductor=ui.runtime.npcs.find(n=>n.id==='conductor');
  // Isolate the real updateWorld pickup stages in a clear source arena; other
  // actors and random event timers are not a second implementation of those stages.
  ui.runtime.npcs=op.crown?[]:[conductor];ui.runtime.cashPiles=[];ui.runtime.projectiles=[];
  conductor.x=2986;conductor.y=3984;conductor.dead=!!op.dead;
  ui.P.x=3000+op.distance-ui.P.w/2;ui.P.y=4000-ui.P.h/2;
  ui.state.flags.introDone=true;ui.state.mode='playing';
  update.updateWorld(op.dt);
  steps.push({operation:{kind:'lifecycle',...op},after:menu(),expected:snapshot(true)});
 }
 cases.push({id:spec.id,roll:spec.roll??0.75,setup,steps});
}
const target=path.join(root,'game3d/tests/fixtures/quest_reference.json');
const output=JSON.stringify({source:'unchanged active v22 callbacks and real updateWorld pickup stages',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Quest oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D QUEST ORACLE: PASS ('+cases.length+' source fixtures; linked dialogue, crown/package lifecycle, strict ranges and caps)');
