import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

// Execute production v22 methods. This tool is never a runtime dependency of either export.
const root=path.resolve(import.meta.dirname,'..');
const game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js');
const routes=game.module('src/systems/progression_routes.js');
const factions=game.module('src/systems/factions.js');
const actors=game.module('src/data/npc_spawns.js');
const clone=v=>JSON.parse(JSON.stringify(v));
let seed=0;
function reset(){
  ui.init_runtime_ui(); actors.spawnNpcs();
  ui.state.flags.introDone=true;ui.state.quests.intro_smoke.done=true;ui.state.mode='playing';
  ui.state.hustles=[];ui.state.hustleSnapshot={};ui.state.blockRoute=null;
  seed=0x19c0ffee;
  game.context.Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/0x100000000;};
  game.context.performance.now=()=>100000;
}
const snapshot=()=>({
  cash:ui.P.cash,cred:ui.P.cred,brain:ui.P.brain,wanted:ui.P.wanted,wantedT:ui.P.wantedT,
  lifetime:clone(ui.P.lifetime),hustles:clone(ui.state.hustles),hustleSnapshot:clone(ui.state.hustleSnapshot),
  route:clone(ui.state.blockRoute),officeAvailable:ui.state.quests.office_space.available,
  achievements:[...ui.state.achievements].sort(),seed,
  territory:{heat:ui.state.territoryHeat||0,cashMult:ui.state.territoryCashMult??1,
    brainTicks:ui.state.territoryBrainTicks||0,zoneId:ui.state.territoryZoneId??null,
    greeted:[...(ui.state.territoryGreeted||[])],greetLast:clone(ui.state.territoryGreetLast||{})},
});
const cases=[
  {id:'roll_early',operations:[['route']]},
  {id:'route_intro_suppressed',flags:{introDone:false},operations:[['route'],['hustles']]},
  {id:'roll_full',player:{lifetime:{routesCompleted:2}},allUnlocks:true,operations:[['route']]},
  {id:'last_stop_excluded',allUnlocks:true,player:{lifetime:{routesCompleted:7}},operations:[['route','ditch_gauge']]},
  {id:'complete_first',operations:[['route'],['stamp_all'],['repeat_stamp']]},
  {id:'office_third',player:{lifetime:{routesCompleted:2}},operations:[['route'],['stamp_all']]},
  ...[4,19,49,999].map(n=>({id:`route_milestone_${n+1}`,player:{lifetime:{routesCompleted:n}},allUnlocks:true,operations:[['route'],['stamp_all']]})),
  {id:'hustles_fresh',operations:[['hustles']]},
  {id:'hustles_unavailable',dead:['lurch','sherri','paulie','priest','pete','tony','stripe','possum'],operations:[['hustles']]},
  {id:'hustles_betrayed',flags:{stripeBetrayed:true,omalleyFallen:true},operations:[['hustles']]},
  {id:'territory_loved',player:{x:1620,y:870,brain:70,faction:{street:25}},operations:[['territory',5]]},
  {id:'territory_hated',player:{x:1620,y:870,faction:{street:-10}},operations:[['territory',30]]},
  {id:'territory_liked',player:{x:1620,y:870,faction:{street:10}},operations:[['territory',6]]},
  {id:'territory_outside',player:{x:8500,y:5500,faction:{street:50}},operations:[['territory',6]]},
];
for(const template of routes.HUSTLE_TEMPLATES){
  cases.push({id:`pay_${template.id}`,hustle:template.id,operations:[['satisfy',template.id],['check'],['check']]});
}
const counts={rocks_3:3,copper_4:4,pawn_2:2,pan_5:1,church_2:5,fight_2:2,dump_3:3,possum_1:1,tony_2:2,sleep_1:1,eat_taco:1,cook_2:2,fence_3:3,laundry_1:1};
const outputCases=[];
for(const spec of cases){
  reset();
  for(const [key,value]of Object.entries(spec.player||{})){
    if(value&&typeof value==='object')Object.assign(ui.P[key],value);else ui.P[key]=value;
  }
  Object.assign(ui.state.flags,spec.flags||{});
  if(spec.allUnlocks)for(const stop of routes.ROUTE_STOPS)if(stop.unlockFlag)ui.state.flags[stop.unlockFlag]=true;
  for(const npc of ui.runtime.npcs)if(spec.dead?.includes(npc.id))npc.dead=true;
  if(spec.hustle){const h=routes.HUSTLE_TEMPLATES.find(x=>x.id===spec.hustle);ui.state.hustles=[{id:h.id,desc:h.desc,reward:clone(h.reward),done:false}];}
  const setup={player:clone(ui.P),flags:clone(ui.state.flags),hustles:clone(ui.state.hustles),npcs:ui.runtime.npcs.map(n=>({id:n.id,x:n.x,y:n.y,w:n.w,h:n.h,dead:!!n.dead}))};
  for(const [op,arg]of spec.operations){
    if(op==='route')routes.rollBlockRoute(true,arg||'');
    else if(op==='hustles')routes.rollHustles();
    else if(op==='stamp_all')for(let i=0;i<3;i++){const s=routes.currentBlockRouteStop();ui.P.x=s.x-ui.P.w/2;ui.P.y=s.y-ui.P.h/2;routes.tryStampBlockRoute();}
    else if(op==='repeat_stamp')routes.tryStampBlockRoute();
    else if(op==='satisfy'){
      const key=routes.HUSTLE_TEMPLATES.find(x=>x.id===arg).key;
      const owner=['rocksSmoked','rocksCooked','rocksFenced'].includes(key)?ui.P.lifetime:ui.state.counters;
      owner[key]=(ui.state.hustleSnapshot?.[key]||0)+counts[arg];
    }else if(op==='check')routes.checkHustles();
    else if(op==='territory')for(let i=0;i<arg;i++)factions.updateTerritory(2000);
    else throw new Error(`Unknown progression operation ${op}`);
  }
  outputCases.push({id:spec.id,setup,operations:spec.operations,expected:snapshot()});
}
const file=path.join(root,'game3d/tests/fixtures/progression_reference.json');
const text=JSON.stringify({source:'unchanged active v22 production methods',cases:outputCases},null,2)+'\n';
if(process.argv.includes('--check')){
  if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==text)throw new Error('Progression fixture drift; regenerate deliberately.');
}else{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,text);}
console.log(`3D PROGRESSION ORACLE: PASS (${outputCases.length} independent source-method fixtures)`);
