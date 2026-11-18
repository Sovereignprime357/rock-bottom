import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),spawns=game.module('src/data/npc_spawns.js');
const recognition=game.module('src/systems/recognition.js'),communications=game.module('src/systems/communications.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const playerKeys=['cash','cred','hp','maxHp','brain','shakes','wanted','iframes','hitFlash','rocks','supplies','dirtySupplies','inventory','faction','charisma'];
const counterKeys=['pinkyFirstBuy','laundryDone','tacosEaten'];
const labels={
 buy_one:/^(buy 1 house|house cut is)/,buy_five:/^(buy 5 packets bulk|5 packets bulk is)/,buy_pass:/^(buy a bus pass|a bus pass is)/,use_pass:/^use the bus pass/,no_like:/^you no like/,cut:/^ask about the cut/,
 popcorn:/^(buy popcorn|you don't have \$8\.)/,mom:/^ask if his mom/,dollar:/^ask for \$1/,pet:/^(pet paisley|try to pet)/,
 tip:/^(tip \$1|you don't have \$1\.)/,song:/^request a different/,nod:/^nod back/,compliment:/^compliment the horse/,
 pod:/^(buy a pod|you don't have \$6\.)/,free:/^ask for a free/,argue:/^argue with/,throw:/^throw something/,
 mayor:/^ask about the mayor/,favor:/^ask for a favor/,bribe:/^(bribe him|you don't have \$5\.)/,
 posting:/^ask what he's posting/,content:/^(give him content|you don't have \$3\.)/,
 laundry:/^(do a load|need \$2\.)/,detergent:/^(buy detergent|detergent is)/,why:/^ask why/,
 meter:/^(pay the meter|meters cost)/,flirt:/^try to flirt/,taco:/^(buy a mystery|\$4 minimum)/,
 horchata:/^(buy a horchata|horchata is)/,burrito:/^(buy a 'special'|specials are \$15\.)/,
 priest:/^ask about the priest/,tic_tac:/^(buy a real tic-tac|specials run)/,sing:/^(sing a song|karaoke is)/,request:/^request a song/,
 leave:/^leave\./
};
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const snapshot=()=>({
 player:pick(ui.P,playerKeys),counters:pick(ui.state.counters,counterKeys),barbAside:ui.state.barbAside,
 achievements:[...ui.state.achievements].sort(),recognition:clone(ui.state.recognition),
 phone:clone(communications.phoneState),joggerSpeed:ui.runtime.npcs.find(n=>n.id==='jogger').speed
});
const ops=(actor,...actions)=>actions.map(action=>({actor,action}));
const specs=[
 {id:'pinky_single_bulk_first_once',player:{cash:100},ops:ops('pinky','buy_one','buy_five','no_like','cut')},
 {id:'pinky_discount',player:{cash:100,charisma:1},ops:ops('pinky','buy_one','buy_five')},
 {id:'pinky_hated',player:{cash:100,faction:{street:-10,scrap:0,spiritual:0}},ops:ops('pinky','leave')},
 {id:'pinky_not_hated_boundary',player:{faction:{street:-9,scrap:0,spiritual:0}},ops:ops('pinky','buy_one')},
 {id:'pinky_poor',player:{cash:3},ops:ops('pinky','buy_one','buy_five','buy_pass')},
 {id:'pinky_pass_fixed20',player:{cash:20,charisma:1},ops:ops('pinky','buy_pass','leave')},
 {id:'pinky_pass_owned',player:{inventory:[{id:'bus_pass',n:'a bus pass',q:1}]},ops:ops('pinky','use_pass')},
 {id:'pinky_many_packets',player:{cash:100,supplies:50,dirtySupplies:50},ops:ops('pinky','buy_five','buy_five')},
 {id:'cubscout_popcorn_mom',player:{cash:16},ops:ops('cubscout','popcorn','popcorn','mom')},
 {id:'cubscout_poor',player:{cash:7},ops:ops('cubscout','popcorn')},
 {id:'cubscout_night_source_callback',state:{dayTime:0.8},ops:ops('cubscout','popcorn')},
 {id:'jogger_success_repeat',roll:0.3999,ops:ops('jogger','dollar','dollar')},
 {id:'jogger_failure_no_speed',roll:0.4,ops:ops('jogger','dollar')},
 {id:'paisley_repeat',ops:ops('dogwalker','pet','pet','pet')},
 {id:'busker_tip_song',player:{cash:2},ops:ops('busker','tip','tip','song')},
 {id:'busker_poor',player:{cash:0},ops:ops('busker','tip')},
 {id:'horse_repeat_nods',ops:ops('horsecop','nod','nod','compliment')},
 {id:'horse_pet_success',roll:0.3999,ops:ops('horsecop','pet')},
 {id:'horse_low_hp_raw_boundary',roll:0.4,player:{hp:5,iframes:777,hitFlash:123,wanted:2},ops:ops('horsecop','pet')},
 {id:'horse_wanted_cap',roll:0.9,player:{wanted:3},ops:ops('horsecop','pet')},
 {id:'vape_brain_cap',player:{brain:99},ops:ops('vapelord','pod','free')},
 {id:'vape_poor',player:{cash:5},ops:ops('vapelord','pod')},
 {id:'vape_fixed_price_charisma',player:{cash:6,charisma:1},ops:ops('vapelord','pod')},
 {id:'pothole_floor_and_throw',player:{brain:2,cash:1},ops:ops('pothole','argue','throw','throw')},
 {id:'mayor_favor_success',roll:0.2999,player:{wanted:2},ops:ops('mayorscousin','favor','mayor')},
 {id:'mayor_favor_boundary',roll:0.3,player:{wanted:2},ops:ops('mayorscousin','favor')},
 {id:'mayor_favor_floor',roll:0.1,ops:ops('mayorscousin','favor')},
 {id:'mayor_bribe_repeat',player:{cash:10},ops:ops('mayorscousin','bribe','bribe')},
 {id:'mayor_poor',player:{cash:4},ops:ops('mayorscousin','bribe')},
 {id:'phone_open',ops:ops('phoneguy','leave')},
 {id:'phone_post_first',roll:0,ops:ops('phoneguy','posting')},
 {id:'phone_post_last',roll:0.999,ops:ops('phoneguy','posting')},
 {id:'phone_paid_repeat',player:{cash:6},ops:ops('phoneguy','content','content')},
 {id:'phone_poor',player:{cash:2},ops:ops('phoneguy','content')},
 {id:'laundry_heal_cap',player:{hp:95,cash:4},ops:ops('laundromat_lady','laundry','laundry')},
 {id:'laundry_detergent',player:{cash:10,brain:1},ops:ops('laundromat_lady','detergent','detergent','why')},
 {id:'laundry_poor',player:{cash:1},ops:ops('laundromat_lady','laundry','detergent')},
 {id:'meter_floor_and_cap',player:{wanted:0,cash:2},ops:ops('meter_maid','meter','flirt','flirt','flirt','flirt')},
 {id:'meter_poor',player:{cash:1},ops:ops('meter_maid','meter')},
 {id:'taco_shakes_boundary_low',roll:0.1499,player:{hp:50,shakes:10},ops:ops('food_truck','taco')},
 {id:'taco_bad_low_hp',roll:0.15,player:{hp:5,iframes:777,hitFlash:123},ops:ops('food_truck','taco')},
 {id:'taco_bad_upper',roll:0.2499,player:{hp:99},ops:ops('food_truck','taco')},
 {id:'taco_plain_boundary',roll:0.25,player:{hp:99},ops:ops('food_truck','taco')},
 {id:'food_horchata_cap',player:{brain:90},ops:ops('food_truck','horchata')},
 {id:'food_burrito',player:{cash:15,rocks:0,wanted:2},ops:ops('food_truck','burrito')},
 {id:'food_burrito_label_quirk',player:{cash:30,rocks:3,wanted:3},ops:ops('food_truck','burrito','burrito')},
 {id:'food_poor',player:{cash:3},ops:ops('food_truck','taco','horchata','burrito')},
 {id:'son_question_floor',player:{brain:0.5},ops:ops('priests_son','priest')},
 {id:'son_real_boundary_low',roll:0.4999,ops:ops('priests_son','tic_tac')},
 {id:'son_tictac_boundary',roll:0.5,ops:ops('priests_son','tic_tac')},
 {id:'son_poor',player:{cash:9},ops:ops('priests_son','tic_tac')},
 {id:'karaoke_request',ops:ops('karaoke','request')},
 {id:'karaoke_poor_menu',player:{cash:4},ops:ops('karaoke','sing')}
];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();spawns.spawnNpcs();recognition.init_recognition();communications.init_communications();
 Object.assign(ui.state,{mode:'playing',dayTime:0.35},clone(spec.state||{}));Object.assign(ui.P,clone(spec.player||{}));
 game.context.Math.random=()=>spec.roll??0.75;
 const setup={player:pick(ui.P,playerKeys),state:pick(ui.state,['day','dayTime','barbAside']),counters:pick(ui.state.counters,counterKeys)};
 const steps=[];
 for(const op of spec.ops){
  ui.closeDialogue();const actor=ui.runtime.npcs.find(n=>n.id===op.actor);
  ui.P.x=actor.x+(actor.w-ui.P.w)/2;ui.P.y=actor.y+(actor.h-ui.P.h)/2;
  recognition.recordNpcBother(op.actor);actor.interact(actor);
  const before=menu(),option=ui.activeDialogue?.opts.find(o=>labels[op.action]?.test(o.label));
  if(!option)throw new Error(spec.id+' missing action '+op.action);
  if(!option.disabled){ui.closeDialogue();option.action();}
  steps.push({operation:op,before,after:menu(),expected:snapshot()});
 }
 cases.push({id:spec.id,roll:spec.roll??0.75,setup,steps});
}
const target=path.join(root,'game3d/tests/fixtures/street_reference.json');
const output=JSON.stringify({source:'unchanged active v22 Pinky and14 inline resident callbacks',partial:'Phone fixtures test the delegate contract, not feed implementation; Karaoke paid rhythm is a separate P09 packet.',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Street oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D STREET ORACLE: PASS ('+cases.length+' source fixtures;15 exact menus,direct commerce/banter,approved quirks;feed/rhythm integration partial)');
