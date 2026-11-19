import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/weather_reference.json');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const copy=x=>JSON.parse(JSON.stringify(x));
export async function buildWeatherOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const lights=game.module('src/render/landmarks_a.js'),weather=game.module('src/render/actors_weather.js');
 const props=game.module('src/data/props.js').PROPS,world=game.module('src/data/world.js');
 const ctx=game.context.__qa.context2d;
 let visual=0,draws=0,lines=[],images=[],start=null,strokes=0;
 game.context.performance.now=()=>visual; game.context.Math.random=()=>{draws++;return .5;};
 ctx.beginPath=()=>{};ctx.moveTo=(x,y)=>{start=[x,y];};ctx.lineTo=(x,y)=>{lines.push({from:start,to:[x,y]});};ctx.stroke=()=>{strokes++;};
 ctx.drawImage=(_image,x,y)=>{images.push({x,y,alpha:ctx.globalAlpha});};
 const phases=[...new Set([...Array.from({length:41},(_,i)=>i/40),.2-1e-7,.2+1e-7,.3-1e-7,.3+1e-7,.7-1e-7,.7+1e-7,.8-1e-7,.8+1e-7])].sort((a,b)=>a-b);
 const curve=phases.map(t=>{ui.state.dayTime=t;return {t,night:lights.nightAmount()};});
 assert.equal(curve.find(x=>x.t===.65).night,0);
 const cases=[];
 for(const kind of ['clear','rain','fog'])for(const time of [0,1000,34000,100000])for(const t of [.25,.65,.75,.9]){
  Object.assign(ui.state,{weather:kind,dayTime:t});visual=time;draws=0;lines=[];images=[];start=null;strokes=0;ctx.globalAlpha=1;ctx.strokeStyle='';ctx.lineWidth=0;
  const before=JSON.stringify({p:ui.P,s:ui.state});weather.drawWeather();
  assert.equal(JSON.stringify({p:ui.P,s:ui.state}),before);assert.equal(draws,0);
  assert.equal(lines.length,kind==='rain'?160:0);assert.equal(images.length,kind==='fog'?1:0);
  cases.push({weather:kind,visual_ms:time,t,night:lights.nightAmount(),lines:copy(lines),images:copy(images),strokes,strokeStyle:ctx.strokeStyle,lineWidth:ctx.lineWidth,alphaAfter:ctx.globalAlpha,rngDraws:draws,stateUnchanged:true});
 }
 const definitions=[...props.filter(p=>p.type==='lamp').map((p,i)=>({id:'streetlamp:'+i,source_id:'streetlamp',x:p.x,y:p.y-32,power:1,kind:'streetlamp'})),
  ...world.WORLD_LIGHTS.map(p=>({...copy(p),source_id:p.id})),
  ...world.WORLD_DECOR.filter(p=>p.type==='burn_barrel').map((p,i)=>({id:'burn_barrel:'+i,source_id:'burn_barrel',x:p.x,y:p.y-19,power:.68,kind:'barrel_fire'}))];
 assert.equal(definitions.length,39);
 ui.runtime.npcs=[];ui.P.rockedT=0;ui.P.hitterHigh=false; const fixtures=[];
 for(const t of [.199,.2,.25,.299,.3,.65,.7,.701,.75,.799,.8,.99])for(const generator of [false,true]){
  ui.state.dayTime=t;ui.state.office={upgrades:{generator}};
  for(const definition of definitions){
   ui.state.cam={x:definition.x-400,y:definition.y-300};draws=0;
   const active=lights.prepareLightingFrame().find(l=>l.id===definition.source_id&&l.x===definition.x&&l.y===definition.y);
   fixtures.push({id:definition.id,t,generator,active:!!active,level:active?.level??0,power:active?.power??0,draws});
   assert.equal(draws,0);
  }
 }
 const files=['src/render/actors_weather.js','src/render/landmarks_a.js','src/render/frame.js','src/core/runtime_ui.js','src/core/update.js','src/data/world.js','src/data/props.js','VIBE.md'];
 const hashes=Object.fromEntries(files.map(file=>[file,hash(fs.readFileSync(path.join(ROOT,file)))]));
 return {schema:1,format:'rock-bottom-weather-reference',source:{authority:'actual unchanged nightAmount/drawWeather/prepareLightingFrame calls',hashes,generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{curve:curve.length,weather:cases.length,fixtures:fixtures.length,definitions:definitions.length},curve,cases,definitions,fixtures};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildWeatherOracle(),output=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Weather source oracle drift.');else fs.writeFileSync(OUTPUT,output);
 console.log(`3D WEATHER ORACLE: PASS (${result.counts.curve} curve/${result.counts.weather} render/${result.counts.fixtures} fixture cases;39 static sources)`);
}
