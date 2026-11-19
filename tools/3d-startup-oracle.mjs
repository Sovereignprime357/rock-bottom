import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..');
const clone=value=>JSON.parse(JSON.stringify(value));
const specs=[
 {id:'fresh_intro',loaded:false,rank:0,day:1,intro:false,silence:0,repeats:1},
 ...Array.from({length:8},(_,rank)=>({id:`load_rank_${rank}`,loaded:true,rank,day:3,intro:true,silence:0,repeats:1})),
 {id:'load_unfinished_intro',loaded:true,rank:0,day:1,intro:false,silence:0,repeats:1},
 {id:'load_silent',loaded:true,rank:2,day:7,intro:true,silence:1000001,repeats:1},
 {id:'load_silence_boundary',loaded:true,rank:2,day:7,intro:true,silence:1000000,repeats:1},
 {id:'repeated_load',loaded:true,rank:1,day:2,intro:true,silence:0,repeats:5},
 {id:'repeated_fresh',loaded:false,rank:0,day:1,intro:false,silence:0,repeats:3}
];
const cases=[];
for(const spec of specs){
 const game=await loadModularGame();
 const ui=game.module('src/core/runtime_ui.js'),com=game.module('src/systems/communications.js'),start=game.module('src/core/start.js');
 vm.runInContext('Date.now=()=>1000000',game.context);
 // Real first start prepares wall layouts and source structures before the observed suffix.
 start.startGame(false);com.init_communications();com.rotateNews();
 com.feedPost('retained before start','@qa');
 const baselineNews=game.context.document.getElementById('tape').textContent;
 Object.assign(ui.state,{day:spec.day,hustles:[]});Object.assign(ui.state.flags,{introDone:spec.intro,silenceUntilT:spec.silence});ui.P.rank=spec.rank;
 let draws=0,publicationStart=0,active=false,order=[],toast='',duration=0;
 game.context.Math.random=()=>{draws++;return .375;};
 const toastEl=ui.toastEl;
 Object.defineProperty(toastEl,'textContent',{configurable:true,get:()=>toast,set:value=>{
  toast=value;if(String(value).startsWith('you wake up on the sidewalk.')){active=true;publicationStart=draws;order.push({kind:'toast',text:value});}
 }});
 const originalTimer=game.context.setTimeout;
 game.context.setTimeout=(fn,ms)=>{if(active)duration=ms;return originalTimer(fn,ms);};
 const unshift=com.phoneState.posts.unshift;
 com.phoneState.posts.unshift=function(post){if(active)order.push({kind:'feed',text:post.t,author:post.h});return unshift.call(this,post);};
 const tape=game.context.document.getElementById('tape');let news=tape.textContent;
 Object.defineProperty(tape,'textContent',{configurable:true,get:()=>news,set:value=>{news=value;if(active)order.push({kind:'news',text:value});}});
 const steps=[];
 for(let index=0;index<spec.repeats;index++){
  active=false;order=[];duration=0;start.startGame(spec.loaded);
  steps.push({toast,duration,posts:clone(com.phoneState.posts),news,order:clone(order),publicationDraws:draws-publicationStart,day:ui.state.day,rank:ui.P.rank});
  if(steps.at(-1).publicationDraws!==0)throw Error('source publication suffix unexpectedly draws RNG');
 }
 cases.push({...spec,baselineNews,steps});
}
const game=await loadModularGame(),ui=game.module('src/core/runtime_ui.js'),spawns=game.module('src/data/npc_spawns.js');
const piles=[];
for(const intro of [false,true])for(const collected of [false,true]){
 ui.state.flags.introDone=intro;ui.state.cashPilesCollected.clear();if(collected)ui.state.cashPilesCollected.add('cp_intro_remember');
 spawns.spawnCashPiles();
 piles.push({intro,collected,count:ui.runtime.cashPiles.length,introPresent:ui.runtime.cashPiles.some(p=>p.id==='cp_intro_remember')});
}
ui.state.flags.introDone=false;ui.state.cashPilesCollected.clear();spawns.spawnCashPiles();ui.state.flags.introDone=true;
const sameSession={introPresent:ui.runtime.cashPiles.some(p=>p.id==='cp_intro_remember'),count:ui.runtime.cashPiles.length};
// Separate exact seeded start order. Observers do not replace any source function.
const content=JSON.parse(fs.readFileSync(path.join(root,'game3d/data/source_content.json'),'utf8'));
const metrics=JSON.parse(fs.readFileSync(path.join(root,'game3d/data/courier_canvas_metrics.json'),'utf8'));
const widths=new Map(metrics.entries.map(row=>[JSON.stringify([row.text,row.size]),row.width]));
const hustleSpecs=[
 ...['missing','null','scalar','object','empty','valid'].map(shape=>({id:'hustles_'+shape,shape,walls:'valid',route:'valid',seed:0x19c0ffee})),
 {id:'hustles_missing_route',shape:'missing',walls:'valid',route:'missing',seed:0x19c0ffee},
 ...[1,0x19c0ffee,0xffffffff].map(seed=>({id:'hustles_rebuild_'+seed,shape:'missing',walls:'missing',route:'missing',seed})),
 {id:'hustles_dead_fighters',shape:'missing',walls:'valid',route:'missing',seed:0x19c0ffee,dead:['lurch','sherri','paulie']},
 {id:'hustles_intro_suppressed',shape:'missing',walls:'missing',route:'missing',seed:0x19c0ffee,intro:false}
];
const hustleCases=[];
for(const spec of hustleSpecs){
 const game=await loadModularGame(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js'),progression=game.module('src/systems/progression_routes.js');
 vm.runInContext('Date.now=()=>1000000',game.context);
 const ctx=game.context.__qa.context2d;
 ctx.measureText=function(text){const size=Number(String(this.font).match(/(\d+(?:\.\d+)?)px/)?.[1]);const width=widths.get(JSON.stringify([String(text),size]));if(width===undefined)throw Error('Missing captured Canvas metric');return {width};};
 start.startGame(false);
 const route={stops:progression.ROUTE_STOPS.slice(0,3).map(stop=>stop.id),cursor:0,serial:4,lastStopId:''};
 const validJob=progression.HUSTLE_TEMPLATES.find(job=>job.id==='rocks_3');
 const rawState={day:3,flags:{...clone(content.initial.state.flags),introDone:spec.intro!==false},counters:{...clone(content.initial.state.counters),bigPan:7},hustleSnapshot:{rocksSmoked:1},blockRoute:spec.route==='valid'?route:null};
 if(spec.walls==='valid'){rawState.graffiti=clone(content.initial.state.graffiti);rawState.posters=clone(content.initial.state.posters);}
 if(spec.shape==='null')rawState.hustles=null;
 if(spec.shape==='scalar')rawState.hustles=17;
 if(spec.shape==='object')rawState.hustles={length:3};
 if(spec.shape==='empty')rawState.hustles=[];
 if(spec.shape==='valid')rawState.hustles=[{id:validJob.id,desc:validJob.desc,reward:clone(validJob.reward),done:true}];
 const player={equip:{shoes:'crocs',hat:'priest_collar',coat:'parka',tool:null},hp:109,lifetime:{...clone(content.initial.player.lifetime),rocksSmoked:9}};
 Object.assign(ui.P,clone(player));Object.assign(ui.state,clone(rawState));
 // Actual source load projection: missing/nonarray becomes null, and absent walls null.
 ui.state.hustles=Array.isArray(rawState.hustles)?clone(rawState.hustles):null;
 ui.state.graffiti=rawState.graffiti??null;ui.state.posters=rawState.posters??null;
 ui.state.loadedNpcDeaths=vm.runInContext(`new Set(${JSON.stringify(spec.dead??[])})`,game.context);
 let seed=spec.seed>>>0,draws=0;const stages=[];let equipmentAtHustle=null;
 game.context.Math.random=()=>{
  const stack=new Error().stack;
  const stage=stack.includes('rollHustles')?'hustles':stack.includes('rollBlockRoute')?'route':stack.includes('buildGraffiti')?'graffiti':stack.includes('buildPosters')?'posters':stack.includes('spawnBreakableBottle')?'bottles':'other';
  if(stage==='hustles'&&equipmentAtHustle===null)equipmentAtHustle=clone(Object.fromEntries(['hp','maxHp','speed','credBonus','charisma','wantedDecayMult'].map(k=>[k,ui.P[k]])));
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;draws++;
  const previous=stages.at(-1);if(previous?.stage===stage){previous.draws++;previous.endSeed=seed;}else stages.push({stage,draws:1,endSeed:seed});
  return seed/4294967296;
 };
 start.startGame(true);
 if(stages.some(stage=>stage.stage==='other'))throw Error('Unclassified source startup RNG '+spec.id);
 const expected={seed,draws,stages,hustles:clone(ui.state.hustles),hustleSnapshot:clone(ui.state.hustleSnapshot),bigPan:ui.state.counters.bigPan,route:clone(ui.state.blockRoute),graffiti:clone(ui.state.graffiti),posters:clone(ui.state.posters),equipmentAtHustle};
 hustleCases.push({...spec,rawState,player,expected});
}
const output=JSON.stringify({source:'unchanged startGame, real Communications observers, spawnCashPiles and captured-Canvas seeded startup hustle order',now:1000000,cases,piles,sameSession,hustleCases},null,2)+'\n';
const target=path.join(root,'game3d/tests/fixtures/startup_reference.json');
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw Error('Startup source oracle drift');}
else fs.writeFileSync(target,output);
console.log(`3D STARTUP SOURCE ORACLE: PASS (${cases.length} publication paths, ${cases.reduce((n,c)=>n+c.steps.length,0)} starts, ${piles.length} cash variants, ${hustleCases.length} seeded hustle starts; zero publication RNG draws)`);
for(const row of hustleCases)console.log(`${row.id}: ${row.seed} -> ${row.expected.seed}; ${row.expected.stages.map(stage=>stage.stage+':'+stage.draws).join(' > ')}`);
