import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/guidance_projection_reference.json');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
export async function buildProjectionOracle(){
  const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),render=game.module('src/render/actors_weather.js');
  const ctx=game.context.__qa.context2d;const cases=[];let calls=[];
  for(const name of ['save','restore','beginPath','closePath','stroke','fill','arc','fillRect','translate','rotate','moveTo','lineTo'])ctx[name]=(...values)=>calls.push({op:name,values});
  ui.state.mode='playing';ui.state.cam={x:0,y:0};let draws=0;game.context.Math.random=()=>{draws++;return .4;};
  for(const visualMs of [1,90,180,Math.PI*90,1000,5700])for(const point of [[400,300],[-20,100],[900,700],[24,36],[776,570]]){
    calls=[];ui.state.visualNow=visualMs;ui.state.primaryObjective={x:point[0],y:point[1]};render.drawObjectiveGuide();
    const alpha=Number(ctx.strokeStyle.match(/,([^,]+)\)$/)[1]);const arc=calls.find(c=>c.op==='arc');
    cases.push({point,visualMs,alpha,width:ctx.lineWidth,fill:ctx.fillStyle,kind:arc?'ring':'arrow',radius:arc?arc.values[2]:null,
      square:calls.find(c=>c.op==='fillRect')?.values||null,vertices:calls.filter(c=>c.op==='moveTo'||c.op==='lineTo').map(c=>c.values),
      translation:calls.find(c=>c.op==='translate')?.values||null,angle:calls.find(c=>c.op==='rotate')?.values[0]??null});
  }
  assert.equal(draws,0);ui.state.mode='dialogue';calls=[];render.drawObjectiveGuide();assert.equal(calls.length,0);
  const file=path.join(ROOT,'src/render/actors_weather.js');return {schema:1,format:'rock-bottom-guidance-projection-reference',source:{file:'src/render/actors_weather.js',sha256:sha(fs.readFileSync(file)),generatorSha256:sha(fs.readFileSync(fileURLToPath(import.meta.url))),authority:'unchanged drawObjectiveGuide actual canvas calls;3D projection is separately documented adaptation'},count:cases.length,cases,modalDraws:calls.length,randomDraws:draws};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildProjectionOracle();const out=stableStringify(result);
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),out,'Projection source fixture drift.');else fs.writeFileSync(OUTPUT,out);
  console.log(`3D GUIDANCE PROJECTION ORACLE: PASS (${result.count} unchanged-source draw cases; modal/RNG zero)`);
}
