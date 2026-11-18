import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const game=await loadModularGame(),ui=game.module('src/core/runtime_ui.js'),rob=game.module('src/systems/robbery.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const fields=['cash','hitters','inventory','equip','hp','maxHp','attackDmg','speed','stunT'];
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const specs=[
 {id:'empty'}, {id:'not_marked',actor:{robs:false}}, {id:'dead',actor:{dead:true}},
 {id:'cooldown_before',last:264001},{id:'cooldown_exact',last:264000},{id:'daily_cap',today:2},
 {id:'cash_low',player:{cash:3}},{id:'cash_min',player:{cash:50},rolls:[0,0]},
 {id:'cash_max',player:{cash:50},rolls:[0,0.99999]}, {id:'hitter',player:{hitters:3}},
 {id:'protected',player:{rocks:5,inventory:[{id:'stripe_package',n:'package',q:1},{id:'crossword',n:'crossword',q:1},{id:'bus_pass',n:'pass',q:1},{id:'unknown',n:'future key',q:1}],equip:{coat:null,hat:'pigeon_crown',shoes:null,tool:'propane_torch'}}},
 ...['junk','food','soap','detergent','cone','gold_tooth','lottery','license'].map(id=>({id:'item_'+id,player:{inventory:[{id,n:'a '+id,q:1}]}})),
 {id:'stack',player:{inventory:[{id:'soap',n:'soap',q:3}]}},
 ...[['coat','parka'],['hat','helmet'],['shoes','crocs']].map(([slot,id])=>({id:'equip_'+slot,player:{equip:{coat:null,hat:null,shoes:null,tool:null,[slot]:id}}})),
 ...Array.from({length:7},(_,i)=>({id:'order_'+i,rolls:[(i+.25)/7,0.5],player:{cash:30,hitters:1,equip:{coat:'trench',hat:'mesh_cap',shoes:'vibrams',tool:'crowbar'},inventory:[{id:'food',n:'food',q:3},{id:'junk',n:'junk',q:1}]}}))
];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();Object.assign(ui.state,{mode:'playing',day:1,dayTime:.35});
 Object.assign(ui.P,{cash:0,hitters:0,inventory:[],equip:{coat:null,hat:null,shoes:null,tool:null}},clone(spec.player||{}));
 ui.applyEquipStats();Object.assign(ui.state.counters,{robLastClockMs:spec.last||0,robberiesToday:spec.today||0});ui.toastEl.textContent='';
 const setup={player:pick(ui.P,fields),state:pick(ui.state,['day','dayTime']),counters:pick(ui.state.counters,['robLastClockMs','robberiesToday'])};
 const rolls=spec.rolls||[0.25],actor={id:'skid_lurch',name:'LURCH (SKID)',robs:true,dead:false,...spec.actor};let draws=0;
 game.context.Math.random=()=>rolls[Math.min(draws++,rolls.length-1)];
 const result=rob.attemptRobbery(actor);
 cases.push({id:spec.id,actor,setup,rolls,result,draws,toast:ui.toastEl.textContent,expected:{player:pick(ui.P,fields),counters:pick(ui.state.counters,['robLastClockMs','robberiesToday'])}});
}
const target=path.resolve(import.meta.dirname,'../game3d/tests/fixtures/robbery_reference.json');
const output=JSON.stringify({source:'unchanged active src/systems/robbery.js',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Robbery oracle drift');}else fs.writeFileSync(target,output);
console.log(`3D ROBBERY ORACLE: PASS (${cases.length} source cases)`);
