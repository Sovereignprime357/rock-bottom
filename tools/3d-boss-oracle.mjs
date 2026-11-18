import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..');
const game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'), combat=game.module('src/systems/combat.js');
const activity=game.module('src/minigames/activities.js'), vendors=game.module('src/dialogue/vendors_places.js');
const dialogue=game.module('src/dialogue/neighborhood_b.js'), ai=game.module('src/systems/npc_ai.js');
const update=game.module('src/core/update.js'), spawns=game.module('src/data/npc_spawns.js'), start=game.module('src/core/start.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const subset=(obj,keys)=>Object.fromEntries(keys.filter(k=>obj[k]!==undefined).map(k=>[k,clone(obj[k])]));
const keys=['id','name','sprite','x','y','w','h','hp','maxHp','speed','dmg','hostile','aggro','isAlly','allyTarget','dead','isBossB','isOsBrutus','isOmalleyFallen','archetype','coatsOff','berserk','grabber','chargeState','chargeT','chargeCdT','chargeLanded','attackCd','hitFlash','hitStun','addsT','fallenPhase2','throwT','throwAimT','aimingThrow','lungeVx','lungeVy'];
const body=(id,extra={})=>({id,name:id,sprite:id,x:230,y:230,w:26,h:30,hp:100,maxHp:100,speed:0,dmg:8,hostile:false,aggro:false,dead:false,chatterCd:999999,attackCd:0,...extra});
function reset(spec){
 ui.init_runtime_ui();spawns.spawnNpcs();ui.runtime.npcs=clone(spec.actors??[body('tony'),body('stripe'),body('priest')]);
 ui.runtime.projectiles=[];ui.runtime.cashPiles=[];
 Object.assign(ui.P,{x:330,y:230,hp:100,iframes:0},clone(spec.player||{}));
 Object.assign(ui.state,{mode:'playing',ambientT:99999,phoneT:99999,randomEventT:99999},clone(spec.state||{}));
 Object.assign(ui.state.flags,clone(spec.flags||{}));Object.assign(ui.state.counters,clone(spec.counters||{}));
 for(const [key,id] of Object.entries(spec.refs||{}))ui.state[key]=ui.runtime.npcs.find(n=>n.id===id);
 game.context.Math.random=()=>spec.roll??0.75;game.context.__qa.timers.length=0;
}
function snapshot(){return {
 player:subset(ui.P,['x','y','hp','maxHp','cred','cash','copper','weapon','stunT','slowT','faction']),
 state:subset(ui.state,['bossActive','bossKind','bossPhase','coopMode','brutusOlderActive','brutusOlderPhase']),
 flags:subset(ui.state.flags,['omalleyFallen','omalleyFallenDead','osBrutusKilled']),
 counters:subset(ui.state.counters,['copperStripped','omalleyFallenSurviveT']),
 quests:Object.fromEntries(['fallen_king','fallen_priest'].map(id=>[id,subset(ui.state.quests[id],['done','available'])])),
 achievements:[...ui.state.achievements].sort(),
 actors:ui.runtime.npcs.map(n=>subset(n,keys)),
 piles:ui.runtime.cashPiles.map(p=>subset(p,['x','y','amt','tool','equip','collected'])),
 projectiles:ui.runtime.projectiles.map(p=>subset(p,['x','y','vx','vy','dmg','slowMs','kind','life'])),
 timers:game.context.__qa.timers.filter(t=>t[0]==='timeout'&&[200,420,4000].includes(t[2])).map(t=>t[2]),
};}
const specs=[
 {id:'start_tony',kind:'tony'}, {id:'start_coop',kind:'coop'},
 {id:'start_coop_no_stripe',kind:'coop',actors:[body('tony')]},
 {id:'start_tony_active_refuses',kind:'tony',state:{bossActive:true,bossKind:'kingdom'}},
 {id:'start_older',kind:'older'}, {id:'start_older_loved',kind:'older',player:{faction:{street:25,scrap:0,spiritual:0}}},
 {id:'start_older_active_refuses',kind:'older',state:{brutusOlderActive:true}},
 {id:'transform_fallen',kind:'transform'},
 {id:'transform_preserves_hitflash',kind:'transform',actors:[body('priest',{hitFlash:100,hitStun:50})]},
 {id:'transform_missing_refuses',kind:'transform',actors:[]},
 {id:'transform_dead_refuses',kind:'transform',actors:[body('priest',{dead:true})]},
 {id:'spawn_old_school',kind:'school'}, {id:'oldschool_corpse_blocks',kind:'school',actors:[body('os_brutus',{dead:true})]},
];
for(const [id,hp,phase]of[['equal66',132,1],['phase2',131,1],['equal33',66,2],['phase3',65,2],['skip_phase2',1,1]]){
 specs.push({id:'tony_'+id,kind:'phase',actors:[body('tony',{hp,maxHp:200,hitStun:99999,coatsOff:phase})],state:{bossActive:true,bossKind:'tony',bossPhase:phase},refs:{bossNPC:'tony'}});
}
for(const [id,hp,phase,addsT]of[['equal50',100,1,0],['phase2',99,1,0],['equal25',50,2,0],['phase3',49,2,0],['skip_phase2',1,1,0],['one_add',90,2,7990],['add_cap',90,2,7990]]){
 const actors=[body('brutus_older',{hp,maxHp:200,isBossB:true,archetype:'charger_older',hitStun:99999,addsT,chargeLanded:id==='phase3'})];
 if(id==='add_cap')actors.push(body('sherri_one',{archetype:'swarmer',hitStun:99999}),body('sherri_two',{archetype:'swarmer',hitStun:99999}));
 specs.push({id:'older_'+id,kind:'phase',actors,state:{brutusOlderActive:true,brutusOlderPhase:phase},refs:{brutusOlderNPC:'brutus_older'}});
}
specs.push(
 {id:'death_tony',kind:'death',actors:[body('tony',{hp:0})],state:{bossActive:true,bossKind:'tony',bossPhase:3},refs:{bossNPC:'tony'}},
 {id:'death_coop',kind:'death',actors:[body('tony',{hp:0})],state:{bossActive:true,bossKind:'tony',bossPhase:3,coopMode:true},refs:{bossNPC:'tony'}},
 {id:'death_older',kind:'death',actors:[body('brutus_older',{hp:0,isBossB:true})],state:{brutusOlderActive:true}},
 {id:'death_oldschool',kind:'death',actors:[body('os_brutus',{hp:0})],state:{territoryCashMult:1.25},counters:{copperStripped:5}},
 {id:'death_oldschool_locker_torch',kind:'death',actors:[body('os_brutus',{hp:0})],flags:{peteToolLocker:'propane_torch'}},
 {id:'death_fallen',kind:'death',actors:[body('omalley_fallen',{hp:0,isOmalleyFallen:true})],flags:{omalleyFallen:true}},
);
for(const [id,overrides,player]of[
 ['ranged_aim',{hp:160}, {x:450}],
 ['holy_throw',{hp:160,throwAimT:10,aimingThrow:true}, {x:450}],
 ['phase2_windup',{hp:79},{}],
 ['phase2_release',{hp:79,fallenPhase2:true,chargeState:'windup',chargeT:10,lungeVx:1,lungeVy:0},{}],
 ['phase2_lunge',{hp:79,fallenPhase2:true,chargeState:'lunge',chargeT:500,lungeVx:1,lungeVy:0},{}],
 ['phase2_contact',{hp:79,fallenPhase2:true,chargeState:'lunge',chargeT:500,lungeVx:1,lungeVy:0},{x:250}],
 ['phase2_iframe',{hp:79,fallenPhase2:true,chargeState:'lunge',chargeT:500,lungeVx:1,lungeVy:0},{x:250,iframes:500}],
 ['phase2_miss',{hp:79,fallenPhase2:true,chargeState:'lunge',chargeT:10,lungeVx:0,lungeVy:1},{}],
]){
 specs.push({id:'fallen_'+id,kind:'ai',actors:[body('omalley_fallen',{maxHp:160,speed:1.6,dmg:22,archetype:'priest_fallen',isOmalleyFallen:true,hostile:true,aggro:true,...overrides})],player,flags:{omalleyFallen:true}});
}
const cases=[];
for(const spec of specs){
 reset(spec);
 // init_runtime_ui declares false/zero keys that startGame later omits. Carry the
 // exact source method's precondition into the fixture; do not add production defaults.
 const setup={player:clone(ui.P),state:clone(spec.state||{}),
  flags:{...subset(ui.state.flags,['omalleyFallen','omalleyFallenDead','osBrutusKilled']),...clone(spec.flags||{})},
  counters:{...subset(ui.state.counters,['copperStripped','omalleyFallenSurviveT']),...clone(spec.counters||{})},
  actors:clone(ui.runtime.npcs),refs:spec.refs||{}};
 let error=null;
 try{
  if(spec.kind==='tony')combat.spawnBoss();
  if(spec.kind==='coop')dialogue.spawnCoopBoss();
  if(spec.kind==='older')activity.spawnBrutusOlder();
  if(spec.kind==='transform')dialogue.triggerFallenPriestTransform();
  if(spec.kind==='school')vendors.spawnOldSchoolBrutus();
  if(spec.kind==='death')combat.onNpcDeath(ui.runtime.npcs[0]);
  if(spec.kind==='phase')update.updateWorld(16);
  if(spec.kind==='ai')ai.updateNpcActors(16);
 }catch(e){error=e.name+': '+e.message;}
 cases.push({id:spec.id,kind:spec.kind,roll:spec.roll??0.75,setup,expected:snapshot(),error});
}
// Separately characterize defects. These are NOT expected port results.
reset({actors:[body('priest')]});dialogue.triggerFallenPriestTransform();start.startGame(true);dialogue.triggerFallenPriestTransform();
const fallenRestart={flag:ui.state.flags.omalleyFallen,ordinary:ui.runtime.npcs.some(n=>n.id==='priest'&&!n.dead),fallen:ui.runtime.npcs.some(n=>n.id==='omalley_fallen')};
reset({state:{brutusOlderPhase:3}});activity.spawnBrutusOlder();
const olderStale={phase:ui.state.brutusOlderPhase,berserk:ui.state.brutusOlderNPC.berserk??false};
const width=game.module('src/data/world.js').WORLD.w;
reset({actors:[body('departing',{x:width-30,y:100,wanderOff:true,targetX:width+80,targetY:100,speed:1.4})]});
for(let i=0;i<300;i++)ai.updateNpcActors(16);
const departure={x:ui.runtime.npcs[0].x,targetX:ui.runtime.npcs[0].targetX,dead:ui.runtime.npcs[0].dead};
const out=JSON.stringify({source:'unchanged active v22 boss start/phase/death/AI functions',cases,defects:{fallenRestart,olderStale,departure}},null,2)+'\n';
const target=path.join(root,'game3d/tests/fixtures/boss_reference.json');
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==out)throw new Error('Boss oracle fixture drift; regenerate deliberately');}
else fs.writeFileSync(target,out);
const errors=cases.filter(c=>c.error);if(errors.length)throw new Error(JSON.stringify(errors.map(c=>({id:c.id,error:c.error}))));
console.log('3D BOSS ORACLE: PASS ('+cases.length+' source fixtures; 3 separate defect characterizations)');
