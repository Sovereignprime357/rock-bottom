import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

// Build-time oracle only: execute unchanged v22 methods, never ship executable JS to Godot.
const root = path.resolve(import.meta.dirname, '..');
const game = await loadModularGame();
const ui = game.module('src/core/runtime_ui.js');
const recognition = game.module('src/systems/recognition.js');
const concession = game.module('src/systems/concessions.js');
const discovery = game.module('src/systems/discovery.js');
const hitter = game.module('src/systems/hitter.js');
const playerKeys = ['x','y','w','h','hp','cash','rocks','copper','soapRocks','hitters','hitterHigh',
  'rockedT','crashT','shakes','brain','cred','faction','lifetime'];
const clone = value => JSON.parse(JSON.stringify(value));
const snapshot = () => ({
  player:Object.fromEntries(playerKeys.map(key => [key,clone(ui.P[key])])),
  recognition:clone(ui.state.recognition), discovered:[...ui.state.discoveredVenues],
  clocks:clone(ui.state.concessionClocks), kingdomStage:ui.state.kingdom.stage,
  kingdomMarks:ui.state.kingdom.marks, achievements:[...ui.state.achievements].sort(),
});
function reset() {
  ui.init_runtime_ui();
  recognition.init_recognition(); concession.init_concessions(); discovery.init_discovery();
  ui.P.cash = 0;
  ui.state.flags.introDone = true;
  ui.state.quests.intro_smoke.done = true;
  ui.state.dayTime = 0.35;
}
const specifications = [
  {id:'real_block',player:{rocks:1,shakes:80},operations:[['smoke','block']]},
  {id:'soap_priority',player:{rocks:1,soapRocks:1,shakes:80},operations:[['smoke','block']]},
  {id:'real_clears_hitter',player:{rocks:1,hitterHigh:true,crashT:12000,shakes:80},operations:[['smoke','block']]},
  {id:'royal_block',player:{rocks:1,shakes:80},kingdom:'anoint',operations:[['smoke','block']]},
  {id:'royal_park_stays',player:{x:2500,y:1000,rocks:1,shakes:80},kingdom:'anoint',night:true,conceded:'park',operations:[['smoke','park']]},
  {id:'hitter_trade',player:{copper:2,shakes:80},operations:[['craft'],['hitter']]},
  {id:'hitter_blocked',player:{hitters:1,rockedT:1000},operations:[['hitter']]},
  {id:'insufficient_copper',player:{copper:1},operations:[['craft']]},
  {id:'found_hitter',player:{hitters:2},operations:[['found']]},
  {id:'recognition_conceded',player:{x:2500,y:1000},operations:Array.from({length:15},()=>['record','park','buy','pigeon'])},
  {id:'recognition_visit_dedup',player:{x:2500,y:1000},operations:[['record','park','bother','pigeon'],['record','park','bother','pigeon'],['record','park','sit','bench']]},
  {id:'discovery_only',player:{x:2500,y:1000},operations:[['discover','park'],['discover','park'],['discover','block']]},
  {id:'clock_rollover',operations:[['clocks',160000]]},
];
const cases = [];
for (const spec of specifications) {
  reset(); Object.assign(ui.P,spec.player||{});
  if(spec.kingdom)ui.state.kingdom.stage=spec.kingdom;
  if(spec.night)ui.state.dayTime=.1;
  if(spec.conceded)ui.state.recognition[spec.conceded].buy=15;
  const setup=snapshot(); setup.dayTime=ui.state.dayTime;
  for(const [op,a,b,c] of spec.operations){
    if(op==='smoke')concession.smokeRockAt(a);
    else if(op==='craft')hitter.craftHitter();
    else if(op==='hitter')hitter.hitEmergencyHitter();
    else if(op==='found')hitter.grantFoundHitter();
    else if(op==='record')recognition.recordRecognition(a,b,c);
    else if(op==='discover')discovery.discoverVenue(a);
    else if(op==='clocks')concession.updateConcessionClocks(a);
    else throw new Error(`Unknown oracle operation ${op}`);
  }
  cases.push({id:spec.id,setup,operations:spec.operations,expected:snapshot()});
}
const output=path.join(root,'game3d/tests/fixtures/memory_reference.json');
const text=JSON.stringify({source:'unchanged active v22 production methods',cases},null,2)+'\n';
if(process.argv.includes('--check')){
  if(!fs.existsSync(output)||fs.readFileSync(output,'utf8')!==text)throw new Error('Memory oracle fixture drift; regenerate deliberately.');
}else{
  fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,text);
}
console.log(`3D MEMORY ORACLE: PASS (${cases.length} independent source-method fixtures)`);
