import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),heat=game.module('src/minigames/heat.js'),comms=game.module('src/systems/communications.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const keys=['cash','hp','brain','shakes','wanted','supplies','dirtySupplies','rocks','soapRocks','rockedT','crashT','inventory','lifetime','equip'];
const pick=(o,list)=>Object.fromEntries(list.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const state=()=>({player:pick(ui.P,keys),quest:clone(ui.state.quests.finisher),achievements:[...ui.state.achievements].sort(),mode:ui.state.mode,heat:clone(ui.state.heat??null),smokeT:ui.state.smokeT||0,posts:clone(comms.phoneState.posts),toast:game.context.document.getElementById('toast').textContent});
function reset(player={}){ui.init_runtime_ui();comms.init_communications();Object.assign(ui.state,{mode:'playing',smokeT:0});Object.assign(ui.P,{supplies:5,dirtySupplies:2,soapRocks:0,equip:{shoes:null,hat:null,coat:null,tool:'propane_torch'}},clone(player));game.context.document.getElementById('toast').textContent='';}
const menus=[];
for(const supplies of [0,1,2,3,4,5,50])for(const tool of [null,'propane_torch']){
 reset({supplies,dirtySupplies:supplies>0?1:0,equip:{shoes:null,hat:null,coat:null,tool}});heat.cookBatchMenu();menus.push({id:'packets_'+supplies+'_'+tool,player:pick(ui.P,keys),expected:menu()});
}
for(const brain of [0,30,31,69,70,100])for(const dirty of [0,1])for(const rocked of [false,true]){
 reset({brain,dirtySupplies:dirty,rockedT:rocked?18000:0,shakes:60});heat.cookBatchMenu();menus.push({id:'predictor_'+brain+'_'+dirty+'_'+rocked,player:pick(ui.P,keys),expected:menu()});
}
const outcomes=[];
for(const mode of Object.keys(heat.COOK_MODES))for(const outcome of ['perfect','ok','bad','burn','undercook','soaprock'])for(const roll of [0,.5,.999]){
 const n=mode==='all'?5:mode==='fast'?3:1;
 reset({supplies:n,dirtySupplies:roll===0?n:roll===.5?Math.min(1,n):0,brain:roll===0?0:roll===.5?70:100,shakes:roll===0?99:60,rockedT:roll===.5?17000:0,crashT:1234});
 ui.P.lifetime.rocksCooked=roll===.5?9:0;
 const setup=pick(ui.P,keys);let draws=0;game.context.Math.random=()=>{draws++;return roll;};
 heat.applyCookOutcome(n,mode,outcome);
 outcomes.push({id:mode+'_'+outcome+'_'+roll,n,mode,outcome,roll,setup,expected:state(),draws});
}
// The same source arithmetic with many packets provides an independent chunked-commit oracle.
for(const outcome of ['perfect','soaprock']){
 reset({supplies:2051,dirtySupplies:1800,brain:80,shakes:20});const setup=pick(ui.P,keys);let draws=0;game.context.Math.random=()=>{draws++;return .5;};
 heat.applyCookOutcome(2051,'all',outcome);outcomes.push({id:'large_'+outcome,n:2051,mode:'all',outcome,roll:.5,setup,expected:state(),draws});
}
{
 reset({supplies:2051,dirtySupplies:1000,brain:80,shakes:20});const setup=pick(ui.P,keys);
 let seed=531;const rolls=Array.from({length:2060},()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;});
 let draws=0;game.context.Math.random=()=>{if(draws===2048)draws++;return rolls[draws++];};
 heat.applyCookOutcome(2051,'all','ok');outcomes.push({id:'large_interleaved_authoritative_rng',n:2051,mode:'all',outcome:'ok',rolls,interleave_after:2048,setup,expected:state(),draws});
}
const starts=[];
for(const mode of Object.keys(heat.COOK_MODES))for(const brain of [0,30,70,100])for(const rocked of [false,true]){
 const n=mode==='all'?5:mode==='fast'?3:1;reset({supplies:n,brain,rockedT:rocked?18000:0,shakes:60});const setup=pick(ui.P,keys);
 let draws=0;game.context.Math.random=()=>{draws++;return .75;};heat.startHeatMini(n,mode);starts.push({id:mode+'_'+brain+'_'+rocked,n,mode,setup,expected:state(),draws});
}
const bounds=[];
for(const x of [.199999,.2,.249999,.25,.4,.400000001,.6,.600000001,.68,.680000001,.8,.800000001,.919999,.92,1])for(const roll of [.149999,.15]){
 const h={lockedAt:x,sweetCenter:.5,sweetHalf:.1,burnZone:.08};let draws=0;game.context.Math.random=()=>{draws++;return roll;};bounds.push({h,roll,outcome:heat.resolveHeatOutcome(h),draws});
}
const timelines=[];
const timelineSpecs=[
 {id:'slow_no_input',mode:'slow',ops:[{dt:49,count:81},{dt:50,count:1},{dt:50,count:19},{dt:50,count:1},{dt:50,count:11},{dt:50,count:1}]},
 {id:'propane_perfect',mode:'propane',ops:[{dt:50,count:15},{dt:30,count:1},{lock:true},{lock:true},{dt:50,count:11},{dt:50,count:1}]},
 {id:'bail_fill',mode:'fast',ops:[{dt:50,count:3},{bail:true}]},
 {id:'bail_idle',mode:'fast',ops:[{dt:50,count:48},{bail:true}]},
 {id:'bail_hold',mode:'all',ops:[{dt:50,count:40},{lock:true},{dt:50,count:5},{bail:true}]}
];
for(const spec of timelineSpecs){
 const n=spec.mode==='all'?5:spec.mode==='fast'?3:1;reset({supplies:n,shakes:60});const setup=pick(ui.P,keys);let draws=0;game.context.Math.random=()=>{draws++;return .5;};heat.startHeatMini(n,spec.mode);
 const initial=state(),steps=[];for(const op of spec.ops){if(op.lock)heat.lockHeatMini();else if(op.bail)heat.bailHeatMini();else for(let i=0;i<op.count;i++)heat.updateHeatMini(op.dt);steps.push({op,expected:state(),draws});}
 timelines.push({...spec,n,setup,initial,steps});
}
const target=path.join(root,'game3d/tests/fixtures/cooking_reference.json');
const result={source:'unchanged cookBatchMenu/startHeatMini/updateHeatMini/resolveHeatOutcome/applyCookOutcome/bailHeatMini',menus,outcomes,starts,bounds,timelines};
const output=JSON.stringify(result,null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Cooking oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D COOKING ORACLE: PASS ('+[menus.length,outcomes.length,starts.length,bounds.length,timelines.length].join('/')+' menus/outcomes/starts/boundaries/timelines)');
