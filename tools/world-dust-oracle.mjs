import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..');
const out=path.join(root,'game3d/tests/fixtures/world_dust_reference.json');
const update=fs.readFileSync(path.join(root,'src/core/update.js'),'utf8');
const hashes={};
for(const file of ['src/core/update.js','src/core/start.js','src/core/audio_save.js','src/core/runtime_ui.js','src/render/frame.js'])
  hashes[file]=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
function between(begin,end){const first=update.indexOf(begin),last=update.indexOf(end,first+begin.length);if(first<0||last<0||update.indexOf(begin,first+1)>=0)throw Error(`Ambiguous source: ${begin}`);return {file:'src/core/update.js',line:update.slice(0,first).split('\n').length,statement:update.slice(first,last)};}
const walk=between('  // anim','  // shakes —');
const ambient=between('  // ambient dust motes','  // rain droplets');
const movement=between('  // input — v13 wave 5:','  // shakes —');
function stream(seed,fixed=null){let state=((seed%2147483646)+2147483646)%2147483646+1;const values=[],numerators=[];const math=Object.create(Math);math.random=()=>{let value;if(fixed){if(values.length>=fixed.length)throw Error('Fixture exhausted supplied randoms');value=fixed[values.length];}else{state=state*48271%2147483647;value=state/2147483647;numerators.push(state);}if(!(value>=0&&value<1))throw Error('Invalid fixture random');values.push(value);return value;};return {math,values,numerators,state:()=>state};}
const copy=value=>JSON.parse(JSON.stringify(value));
function walkCase(id,seed,timer,steps,fixed=null){const random=stream(seed,fixed);const ctx={Math:random.math,P:{x:1050,y:840,w:24,h:28,frame:0,frameT:0},particles:[]};if(timer!==null)ctx.P.dustT=timer;const snapshots=[];for(const step of steps){Object.assign(ctx,step);const first=random.values.length,birth=ctx.particles.length;vm.runInNewContext(walk.statement,ctx,{timeout:1000});snapshots.push({step,clock:ctx.P.dustT??null,births:copy(ctx.particles.slice(birth)),samples:random.values.slice(first),numerators:random.numerators.slice(first),rng_state:random.state(),rng_draws:random.values.length});}return{id,kind:'walk',seed,timer,steps:snapshots};}
function ambientCase(id,seed,timer,weather,dayTime,steps,fixed=null){const random=stream(seed,fixed);const ctx={Math:random.math,state:{weather,dayTime,cam:{x:-400,y:-300}},W:800,H:600,particles:[]};if(timer!==null)ctx.state.dustT=timer;const snapshots=[];for(const dt of steps){ctx.dt=dt;const first=random.values.length,birth=ctx.particles.length;vm.runInNewContext(ambient.statement,ctx,{timeout:1000});snapshots.push({step:{dt},clock:ctx.state.dustT,births:copy(ctx.particles.slice(birth)),samples:random.values.slice(first),numerators:random.numerators.slice(first),rng_state:random.state(),rng_draws:random.values.length});}return{id,kind:'ambient',seed,timer,weather,dayTime,steps:snapshots};}
const cases=[];
for(const seed of [1,7,71231,2147483646]){
  cases.push(walkCase(`walk/strict110/${seed}`,seed,100,[{dt:10,vx:1,vy:0},{dt:.001,vx:1,vy:0}]));
  cases.push(walkCase(`walk/idleCarry/${seed}`,seed,80,[{dt:50,vx:0,vy:0},{dt:30,vx:-1,vy:0},{dt:1,vx:-1,vy:0}]));
  cases.push(walkCase(`walk/fresh/${seed}`,seed,null,[{dt:50,vx:0,vy:1},{dt:50,vx:0,vy:1},{dt:50,vx:0,vy:1},{dt:50,vx:0,vy:1}]));
  cases.push(walkCase(`walk/largeDiscard/${seed}`,seed,109,[{dt:1000,vx:.25,vy:-.5},{dt:110,vx:.25,vy:-.5},{dt:.001,vx:.25,vy:-.5}]));
  cases.push(walkCase(`walk/diagonal/${seed}`,seed,110,[{dt:1,vx:.7071,vy:-.7071}]));
  for(const weather of ['clear','rain','unknown'])for(const dayTime of [.1,.5,.9])
    cases.push(ambientCase(`ambient/allWeatherTime/${seed}/${weather}/${dayTime}`,seed,null,weather,dayTime,[1,50,200,500,1000]));
  cases.push(ambientCase(`ambient/equality/${seed}`,seed,50,'clear',.5,[49,1]));
  cases.push(ambientCase(`ambient/negativeDiscard/${seed}`,seed,-300,'rain',.1,[1000,1]));
}
for(const r of [0,.199999999,.2,.999999999]){
  cases.push(walkCase(`walk/fixed/${r}`,1,110,[{dt:1,vx:-.5,vy:.25}],Array(5).fill(r)));
  cases.push(ambientCase(`ambient/fixed/${r}`,1,0,'clear',.5,[1],Array(7).fill(r)));
}
// These witnesses execute source input/stun/movement as well as the birth block.
const movementCases=[];
for(const stunT of [0,16,16.001])for(const blocked of [false,true]){
  const random=stream(7);const ctx={Math:random.math,P:{x:1050,y:840,w:24,h:28,frame:0,frameT:0,stunT,slowT:0,speed:2.6,rockedT:0,crashT:0,dustT:110},state:{keys:new Set(['d'])},WORLD:{w:8000,h:4000},particles:[],dt:16,clamp:(x,a,b)=>Math.min(b,Math.max(a,x)),moveBodyAgainstStructures:(body,x,y)=>{if(!blocked){body.x=x;body.y=y;}}};
  vm.runInNewContext(movement.statement,ctx,{timeout:1000});
  movementCases.push({id:`movement/stun${stunT}/blocked${blocked}`,stunT,blocked,expected:copy(ctx.P),births:copy(ctx.particles),samples:random.values,numerators:random.numerators});
}
// Source start/load do not replace or reset these unsaved clocks; record the exact absence.
const start=fs.readFileSync(path.join(root,'src/core/start.js'),'utf8'),save=fs.readFileSync(path.join(root,'src/core/audio_save.js'),'utf8');
if(/\bdustT\b/.test(start)||/\bdustT\b/.test(save))throw Error('Source lifecycle changed: inspect dustT persistence before regenerating');
const data={schema:1,rngEncoding:{modulus:2147483647,samples:'diagnostic decimal values',numerators:'exact per-draw LCG states; reconstruct with float(numerator)/2147483647.0',fixed:'literal formula inputs have no LCG numerators'},oracle:'Exact unchanged source walking/ambient blocks with controlled cosmetic stream; spatial first-person adaptation is tested separately.',sourceHashes:hashes,blocks:{walk,ambient,movement},cases,movementCases,lifecycle:{source:'same-session fresh/load leave both unsaved dustT fields untouched',evidence:['startGame has no dustT reset','saveGame has no dustT field','loadGame has no dustT reset'],candidate:'proposed feedback-generation reset; not source behavior'}};
const generated=JSON.stringify(data,null,2)+'\n';
if(process.argv.includes('--check')) {
  if(!fs.existsSync(out)||fs.readFileSync(out,'utf8')!==generated)throw Error('Source fixture drift: '+out);
} else { fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,generated); }
console.log(`WORLD DUST SOURCE ORACLE: PASS; ${cases.length} schedule cases; ${movementCases.length} actual source input/stun/blocked witnesses; ${cases.reduce((n,c)=>n+c.steps.reduce((s,t)=>s+t.births.length,0),0)} births; original source unchanged.`);
