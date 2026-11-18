import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';

// Unchanged source functions, fixed gameplay rolls. Presentation particle draws deliberately
// share the constant: this compares mechanics, not a render-dependent RNG stream.
const root=path.resolve(import.meta.dirname,'..');
const game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js');
const combat=game.module('src/systems/combat.js');
const ai=game.module('src/systems/npc_ai.js');
const physical=game.module('src/systems/physicality.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pkeys=['x','y','hp','iframes','hitFlash','stunT','slowT','attackCd','attacking','cash','rocks','cred','wanted','wantedT','weapon','brutusDefeated','faction','inventory','lifetime'];
const akeys=['id','x','y','hp','dead','attackCd','hitFlash','hitStun','hostile','aggro','showHp','chargeState','chargeT','chargeCdT','chargeLanded','lungeVx','lungeVy','grabFreezeT','grabbedOnce','panicT','throwT','throwAimT','aimingThrow','taserChargeT','chatterT','chatterCd','wanderT','targetX','targetY','patrolT','radioT','radioCdT','radioVisualT','revealT','chained','speed','dmg'];
const subset=(obj,keys)=>Object.fromEntries(keys.filter(k=>obj[k]!==undefined).map(k=>[k,clone(obj[k])]));
let anchor=null;
for(let y=50;y<2500&&!anchor;y+=100)for(let x=50;x<3500&&!anchor;x+=100){if(!physical.firstBlockingStructure({x,y,w:500,h:500}))anchor={x:x+180,y:y+180};}
if(!anchor)throw new Error('No clear reference arena');
function actor(overrides={}){return {id:'test_actor',name:'TEST ACTOR',sprite:'lurch',x:anchor.x,y:anchor.y,w:26,h:30,hp:1000,maxHp:1000,speed:1.6,dmg:8,hostile:true,aggro:true,archetype:'default',attackCd:0,hitFlash:0,hitStun:0,chatterCd:999999,chatterT:0,dead:false,...overrides};}
function reset(spec){
  ui.init_runtime_ui();
  Object.assign(ui.P,{x:anchor.x+100,y:anchor.y,hp:100,iframes:0,weapon:'fists',facing:'left'},clone(spec.player||{}));
  Object.assign(ui.state,clone(spec.state||{}));
  Object.assign(ui.state.flags,clone(spec.flags||{}));
  Object.assign(ui.state.counters,clone(spec.counters||{}));
  ui.runtime.npcs=clone(spec.actors||[actor(spec.actor)]);ui.runtime.cashPiles=[];ui.runtime.projectiles=[];
  game.context.Math.random=()=>spec.roll??0.75;
  game.context.__qa.timers.length=0;
}
function snapshot(){return {
  player:subset(ui.P,pkeys),actors:ui.runtime.npcs.map(n=>subset(n,akeys)),
  combo:ui.state.combo,comboT:ui.state.comboT,
  counters:subset(ui.state.counters,['brutusDeaths','brendanFirstKill','alleyKills','stripeBetrayed']),
  flags:subset(ui.state.flags,['daveHasCrossword','hasCrossword']),
  achievements:[...ui.state.achievements].sort(),
  projectiles:ui.runtime.projectiles.map(p=>subset(p,['x','y','vx','vy','dmg','slowMs','kind','rot','rotVel','life'])),
  piles:ui.runtime.cashPiles.map(p=>subset(p,['x','y','amt','collected','tool'])),
  timers:game.context.__qa.timers.filter(t=>t[0]==='timeout').map(t=>t[2]).filter(t=>t===1500||t===500||t===800),
};}
const specs=[];
for(const weapon of ['fists','pipe','brick','cart_wheel','shoe','baguette','microphone','knife','broken_bottle']){
  specs.push({id:`weapon_${weapon}`,kind:'attack',roll:0.25,player:{x:anchor.x+30,weapon}});
}
specs.push(
  {id:'high_cart_vulnerable',kind:'attack',roll:0.5,player:{x:anchor.x+30,rockedT:18000,cartMounted:true},actor:{archetype:'charger',chargeState:'cooldown'}},
  {id:'essential',kind:'attack',player:{x:anchor.x+30},actor:{essential:true,hostile:false,aggro:false}},
  {id:'no_combo',kind:'attack',player:{x:anchor.x+30},state:{combo:4,comboT:400},actor:{noComboReward:true}},
  {id:'combo_five',kind:'attack',player:{x:anchor.x+30},state:{combo:4,comboT:400}},
  {id:'combo_ten',kind:'attack',player:{x:anchor.x+30},state:{combo:9,comboT:400}},
  {id:'whiff',kind:'attack',state:{combo:4,comboT:400}},
  {id:'peaceful_hit',kind:'attack',player:{x:anchor.x+30},actor:{hostile:false,aggro:false}},
  {id:'chained_dog',kind:'attack',player:{x:anchor.x+30},actor:{id:'scrap_dog',chained:true,hostile:false,aggro:false}},
);
const contact={x:anchor.x+20,y:anchor.y};
specs.push(
 {id:'default_chase',kind:'ai'},
 {id:'default_contact',kind:'ai',player:contact},
 {id:'stun_freezes_ai_not_cd',kind:'ai',actor:{hitStun:10,attackCd:30,hitFlash:25}},
 {id:'grab_contact',kind:'ai',player:contact,actor:{archetype:'grabber'}},
 {id:'grab_iframes',kind:'ai',player:{...contact,iframes:500},actor:{archetype:'grabber'}},
 {id:'swarmer_contact',kind:'ai',player:contact,actor:{archetype:'swarmer',dmg:5,speed:2}},
 {id:'charger_windup',kind:'ai',actor:{archetype:'charger'}},
 {id:'older_windup',kind:'ai',actor:{archetype:'charger_older'}},
 {id:'berserk_windup',kind:'ai',actor:{archetype:'charger_older',berserk:true}},
 {id:'charger_release',kind:'ai',actor:{archetype:'charger',chargeState:'windup',chargeT:10,lungeVx:1,lungeVy:0}},
 {id:'charger_lunge',kind:'ai',actor:{archetype:'charger',chargeState:'lunge',chargeT:500,lungeVx:1,lungeVy:0}},
 {id:'charger_lunge_contact',kind:'ai',player:contact,actor:{archetype:'charger',chargeState:'lunge',chargeT:500,lungeVx:1,lungeVy:0}},
 {id:'charger_miss',kind:'ai',actor:{archetype:'charger',chargeState:'lunge',chargeT:10,lungeVx:0,lungeVy:1}},
 {id:'charger_cooldown',kind:'ai',actor:{archetype:'charger',chargeState:'cooldown',chargeT:10}},
 {id:'ranged_aim',kind:'ai',player:{x:anchor.x+220},actor:{archetype:'ranged'}},
 {id:'ranged_throw',kind:'ai',player:{x:anchor.x+220},actor:{archetype:'ranged',throwAimT:10,aimingThrow:true}},
 {id:'ranged_panic',kind:'ai',player:contact,actor:{archetype:'ranged',dmg:7}},
 {id:'brendan_wait',kind:'ai',player:contact,actor:{archetype:'brendan',isCop:true,isBrendan:true,taserChargeT:3900,dmg:50}},
 {id:'brendan_zap',kind:'ai',player:contact,actor:{archetype:'brendan',isCop:true,isBrendan:true,taserChargeT:3990,dmg:50}},
 {id:'patrol',kind:'ai',actor:{hostile:false,aggro:false,patrol:[{x:anchor.x+100,y:anchor.y+100}],patrolT:0}},
 {id:'wander',kind:'ai',actor:{hostile:false,aggro:false,wander:true,wanderT:0}},
 {id:'pet_follow',kind:'ai',actor:{hostile:false,aggro:false,isPet:true}},
 {id:'pet_retreat',kind:'ai',player:{x:anchor.x+12},actor:{hostile:false,aggro:false,isPet:true}},
 {id:'cart_contact',kind:'ai',player:{...contact,cartMounted:true},actor:{hostile:true,aggro:false,speed:0,dmg:8,attackCd:16}},
);
for(const id of ['test_actor','larry','lurch','paulie','brutus','cop','stripe','dave'])specs.push({id:`death_${id}`,kind:'death',actor:{id,hp:0,isCop:id==='cop'},flags:{daveHasCrossword:true},counters:{plateStolen:1},roll:0.75});
specs.push({id:'night_torch',kind:'death',actor:{id:'brutus',hp:0},state:{dayTime:0.1},roll:0.1},
 {id:'night_torch_owned',kind:'death',actor:{id:'brutus',hp:0},flags:{peteToolLocker:'propane_torch'},state:{dayTime:0.1},roll:0.1},
 {id:'brutus_fifth',kind:'death',actor:{id:'brutus',hp:0},player:{brutusDefeated:4}},
 {id:'brendan_defect',kind:'death',actor:{id:'brendan_x',hp:0,isCop:true,isBrendan:true}},
 {id:'guard_no_pay',kind:'death',actor:{kingdomGuard:true,hp:0}},
 {id:'add_no_pay',kind:'death',actor:{kingdomAdd:true,hp:0}},
 {id:'hurt_iframe',kind:'damage',player:{iframes:500},amount:9},
 {id:'hurt_normal',kind:'damage',amount:9},
 {id:'hurt_death',kind:'damage',player:{hp:5,cred:14,rockedT:1000},amount:9},
 {id:'hurt_arrest',kind:'damage',player:{hp:5,cash:101,rocks:2},actor:{isCop:true},amount:9},
 {id:'police_decay',kind:'police',player:{wanted:1,wantedT:17990}},
 {id:'police_spawn',kind:'police',actors:[],player:{wanted:1},roll:0.75},
 {id:'police_brendan',kind:'police',actors:[],player:{wanted:2},roll:0.1},
 {id:'police_radio',kind:'police',actor:{id:'cop_test',isCop:true,x:anchor.x-100},player:{wanted:1},roll:0},
);
const cases=[];
for(const spec of specs){
 reset(spec);
 const setup={player:clone(ui.P),state:{combo:ui.state.combo,comboT:ui.state.comboT,dayTime:ui.state.dayTime},flags:clone(spec.flags||{}),counters:clone(spec.counters||{}),actors:clone(ui.runtime.npcs)};
 let error=null;
 try{
  if(spec.kind==='attack')combat.playerAttack();
  if(spec.kind==='death')combat.onNpcDeath(ui.runtime.npcs[0]);
  if(spec.kind==='damage')combat.damagePlayer(spec.amount,ui.runtime.npcs[0]);
  if(spec.kind==='ai')ai.updateNpcActors(16);
  if(spec.kind==='police')combat.manageCops(16);
 }catch(e){error=`${e.name}: ${e.message}`;}
 cases.push({id:spec.id,kind:spec.kind,roll:spec.roll??0.75,amount:spec.amount??null,setup,expected:snapshot(),error});
}
const output=path.join(root,'game3d/tests/fixtures/combat_reference.json');
const text=JSON.stringify({source:'unchanged active v22 combat / NPC AI; fixed rolls; clear arena',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(output)||fs.readFileSync(output,'utf8')!==text)throw new Error('Combat fixture drift; regenerate deliberately.');}
else fs.writeFileSync(output,text);
console.log(`3D COMBAT ORACLE: PASS (${cases.length} source fixtures; Brendan ReferenceError retained as explicit defect)`);
