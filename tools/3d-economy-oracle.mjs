import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';

// Dev-only oracle: unchanged source dialogue functions supply closures and all transaction math.
const root=path.resolve(import.meta.dirname,'..');
const game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js');
const vendors=game.module('src/dialogue/neighborhood_a.js');
const spawns=game.module('src/data/npc_spawns.js');
const clone=value=>JSON.parse(JSON.stringify(value));
const playerKeys=['cash','rocks','copper','cred','rank','tonyOffenses','equip','inventory','faction','charisma'];
const counterKeys=['rocksBought','peteSold','peteCashToday'];
const flagKeys=['peteTorchStocked','peteTorchSold','peteToolLocker','scrapLoanDay','scrapHideoutOwned'];
const labels={
  buy_rock:/^buy a rock\./,short:/^short him\./,negotiate:/^try to negotiate\./,challenge:/^(challenge for|try to take) the corner\./,
  sell_copper:/^sell 1 PURE COPPER\./,sell_all_copper:/^sell all pure copper\./,brutus:/^ask about brutus\./,dog:/^ask about the dog\./,
  rent_shed:/^rent (the back-corner shed|the shed)\./,sock:/^pawn a sock\./,sell_license:/^sell license plate\./,
  buy_food:/^(buy food\.|food is)/,sell_junk:/^sell junk\./,buy_torch:/^(buy the propane torch|the propane torch is)/,
  buy_crowbar:/^(buy the crowbar|the crowbar is)/,swap_tools:/^swap tools\./,loan:/^ask pete for \$50\./,
  torch_again:/^ask about the torch again\./,leave:/^leave\./,
};
const snapshot=()=>({
  player:Object.fromEntries(playerKeys.map(key=>[key,clone(ui.P[key])])),
  counters:Object.fromEntries(counterKeys.map(key=>[key,ui.state.counters[key]??0])),
  flags:Object.fromEntries(flagKeys.map(key=>[key,ui.state.flags[key]??null])),
  firstRock:ui.state.quests.first_rock.done,achievements:[...ui.state.achievements].sort(),
  boss:{active:ui.state.bossActive,kind:ui.state.bossKind,phase:ui.state.bossPhase},day:ui.state.day,
});
function reset(spec){
  ui.init_runtime_ui();spawns.spawnNpcs();
  ui.P.cash=0;ui.P.equip.tool=null;
  ui.state.quests.intro_tony.available=false;
  Object.assign(ui.P,clone(spec.player||{}));
  Object.assign(ui.state.flags,clone(spec.flags||{}));
  Object.assign(ui.state.counters,clone(spec.counters||{}));
  ui.applyEquipStats();
}
const item=(id,q=1)=>({id,n:id==='junk'?'a piece of junk':id==='food'?'a can of food (unmarked)':'a license plate (bent)',q});
const specs=[
  {id:'tony_normal',player:{cash:20,tonyOffenses:2},ops:[['tony','buy_rock']]},
  {id:'tony_threshold_reprice',player:{cash:30,faction:{street:9,scrap:0,spiritual:0}},ops:[['tony','buy_rock'],['tony','buy_rock']]},
  {id:'tony_crown_liked',player:{cash:20,equip:{hat:'pigeon_crown'},faction:{street:10,scrap:0,spiritual:0}},ops:[['tony','buy_rock']]},
  {id:'tony_fifty',player:{cash:20,faction:{street:24,scrap:0,spiritual:0}},counters:{rocksBought:49},ops:[['tony','buy_rock']]},
  {id:'tony_short_two',player:{cash:10},ops:[['tony','short'],['tony','short']]},
  {id:'tony_short_boss',player:{cash:5,tonyOffenses:2},ops:[['tony','short']]},
  {id:'tony_challenge',player:{cred:100},ops:[['tony','challenge']]},
  {id:'tony_poor',player:{cash:4},ops:[['tony','buy_rock'],['tony','short']]},
  {id:'yuri_single',player:{copper:2},ops:[['yuri','sell_copper']]},
  {id:'yuri_bulk_threshold',player:{copper:10,faction:{street:0,scrap:9,spiritual:0}},ops:[['yuri','sell_all_copper']]},
  {id:'yuri_liked',player:{copper:3,faction:{street:0,scrap:10,spiritual:0}},ops:[['yuri','sell_all_copper']]},
  {id:'yuri_shed',player:{cash:150,faction:{street:0,scrap:5,spiritual:0}},ops:[['yuri','rent_shed'],['yuri','rent_shed']]},
  {id:'pete_copper_cap',player:{copper:2},counters:{peteCashToday:195},ops:[['pete','sell_copper'],['pete','sell_copper']]},
  {id:'pete_liked',player:{copper:1,faction:{street:0,scrap:10,spiritual:0}},ops:[['pete','sell_copper']]},
  {id:'pete_license_all',player:{inventory:[item('license',3),item('license')]},counters:{peteCashToday:193},ops:[['pete','sell_license']]},
  {id:'pete_junk_partial',player:{inventory:[item('junk',9),item('junk'),item('junk')]},counters:{peteCashToday:198},ops:[['pete','sell_junk']]},
  {id:'pete_sock_then_empty',counters:{peteCashToday:199},ops:[['pete','sock'],['pete','sock']]},
  {id:'pete_food_after_cap',player:{cash:3},counters:{peteCashToday:200},ops:[['pete','buy_food']]},
  {id:'pete_tools_torch_first',player:{cash:200,rank:3},ops:[['pete','buy_torch'],['pete','buy_crowbar'],['pete','swap_tools'],['pete','torch_again']]},
  {id:'pete_tools_crowbar_first',player:{cash:200,rank:3},ops:[['pete','buy_crowbar'],['pete','buy_torch'],['pete','swap_tools']]},
  {id:'pete_owned_torch_not_resold',player:{cash:200,rank:3,equip:{tool:'crowbar'}},flags:{peteToolLocker:'propane_torch'},ops:[['pete','buy_torch']]},
  {id:'pete_loan_once',player:{cred:0,faction:{street:0,scrap:25,spiritual:0}},counters:{peteCashToday:200},ops:[['pete','loan'],['pete','loan']]},
  {id:'pete_hated_refuses_all',player:{cash:200,copper:3,rank:3,faction:{street:0,scrap:-10,spiritual:0}},ops:[['pete','buy_food'],['pete','sell_copper'],['pete','buy_crowbar']]},
];
const cases=[];
for(const spec of specs){
  reset(spec);const setup=snapshot();const offered=[];
  for(const [vendor,action] of spec.ops){
    vendors[`${vendor}Dialogue`](ui.runtime.npcs.find(n=>n.id===vendor));
    const option=ui.activeDialogue.opts.find(o=>labels[action].test(o.label));
    offered.push({vendor,action,present:!!option,enabled:!!option&&!option.disabled});
    if(option&&!option.disabled){ui.closeDialogue();option.action();}
  }
  cases.push({id:spec.id,setup,operations:spec.ops,offered,expected:snapshot()});
}
const output=path.join(root,'game3d/tests/fixtures/economy_reference.json');
const text=JSON.stringify({source:'unchanged active v22 dialogue callbacks',cases},null,2)+'\n';
if(process.argv.includes('--check')){
  if(!fs.existsSync(output)||fs.readFileSync(output,'utf8')!==text)throw new Error('Economy oracle fixture drift; regenerate deliberately.');
}else{fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,text);}
console.log(`3D ECONOMY ORACLE: PASS (${cases.length} independent source-method fixtures)`);
