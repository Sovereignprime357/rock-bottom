import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const HERE=path.dirname(fileURLToPath(import.meta.url));
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/district_grade_reference.json');
const clone=value=>JSON.parse(JSON.stringify(value));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const rgb=value=>value.split(',').map(v=>Number(v)/255);
const recipe=value=>({multiply:rgb(value.multiply),multiplyAlpha:value.multiplyAlpha,overlay:rgb(value.overlay),overlayAlpha:value.overlayAlpha});
const encode=value=>Number.isNaN(value)?'NaN':value===Infinity?'Infinity':value===-Infinity?'-Infinity':value;

export async function buildOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),world=game.module('src/data/world.js');
 const source=game.module('src/render/landmarks_a.js'),ctx=game.module('src/render/canvas_geography.js').ctx;
 const initial={zones:clone(world.ZONES),terrainRegions:clone(world.TERRAIN_REGIONS),ambientGrades:clone(world.AMBIENT_GRADES)};
 const variants={source:initial},lookups=[],grades=[];
 let calls=[],stack=[],draws=0;
 game.context.Math.random=()=>{draws++;throw Error('Random draw in pure grade source');};
 ctx.save=()=>stack.push({alpha:ctx.globalAlpha,operation:ctx.globalCompositeOperation,fill:ctx.fillStyle});
 ctx.restore=()=>{const s=stack.pop();assert.ok(s);ctx.globalAlpha=s.alpha;ctx.globalCompositeOperation=s.operation;ctx.fillStyle=s.fill;};
 ctx.fillRect=(...rect)=>calls.push({operation:ctx.globalCompositeOperation,alpha:ctx.globalAlpha,rgb:rgb(ctx.fillStyle.slice(4,-1)),rect});
 function capture(x,y){
  ui.P.x=x-ui.P.w/2;ui.P.y=y-ui.P.h/2;
  const before=stableStringify({player:ui.P,state:ui.state});
  ctx.globalAlpha=.37;ctx.globalCompositeOperation='xor';ctx.fillStyle='#b00b1e';calls=[];stack=[];
  const selected=source.ambientGradeAt(x,y);source.drawAmbientGrade();
  assert.equal(stableStringify({player:ui.P,state:ui.state}),before,'source grade mutated authority');
  assert.equal(ctx.globalAlpha,1);assert.equal(ctx.globalCompositeOperation,'source-over');assert.equal(ctx.fillStyle,'#b00b1e');assert.equal(stack.length,0);
  assert.equal(calls[0].operation,'multiply');assert.deepEqual(calls[0].rect,[0,0,world.W,world.H]);
  assert.equal(calls.length,selected.overlayAlpha>0?2:1);
  if(calls.length===2)assert.equal(calls[1].operation,'overlay');
  return {expected:recipe(selected),operations:clone(calls)};
 }
 function add(id,x,y,variant='source'){lookups.push({id,variant,point:[encode(x),encode(y)],...capture(x,y)});}
 for(const [kind,rows]of [['zone',initial.zones],['region',initial.terrainRegions]])for(const r of rows){
  add(`${kind}_${r.id}_center`,r.x+r.w/2,r.y+r.h/2);
  for(const [i,p]of [[r.x,r.y],[r.x+r.w,r.y],[r.x,r.y+r.h],[r.x+r.w,r.y+r.h]].entries())add(`${kind}_${r.id}_corner${i}`,...p);
  for(const d of [-.000001,0,.000001]){
   add(`${kind}_${r.id}_left_${d}`,r.x+d,r.y+r.h/2);add(`${kind}_${r.id}_right_${d}`,r.x+r.w+d,r.y+r.h/2);
   add(`${kind}_${r.id}_top_${d}`,r.x+r.w/2,r.y+d);add(`${kind}_${r.id}_bottom_${d}`,r.x+r.w/2,r.y+r.h+d);
  }
 }
 for(const [i,p]of [[-1,-1],[0,0],[8601,5601],[NaN,100],[100,NaN],[Infinity,100],[-Infinity,100],[100,Infinity],[100,-Infinity]].entries())add('default_or_nonfinite_'+i,...p);
 function replace(rows,regions){world.ZONES.splice(0,world.ZONES.length,...clone(rows));world.TERRAIN_REGIONS.splice(0,world.TERRAIN_REGIONS.length,...clone(regions));}
 const rect=id=>({id,x:0,y:0,w:10,h:10});
 for(const [id,zones,regions]of [
  ['zone_first',[rect('block'),rect('church')],[rect('far_mid')]],
  ['zone_reversed',[rect('church'),rect('block')],[rect('far_mid')]],
  ['region_first',[],[rect('far_north'),rect('far_mid')]],
  ['region_reversed',[],[rect('far_mid'),rect('far_north')]],
  ['unknown_zone_stops',[rect('unknown'),rect('block')],[rect('far_north')]],
  ['unknown_region_stops',[],[rect('unknown'),rect('far_north')]],
  ['closed_zero_area',[{id:'church',x:10,y:10,w:0,h:0}],[]]
 ]){
  variants[id]={zones,terrainRegions:regions,ambientGrades:initial.ambientGrades};replace(zones,regions);
  for(const [i,p]of [[0,0],[10,10],[10.000001,10]].entries())add(id+'_'+i,...p,id);
 }
 // Execute unchanged lookup/draw for every grade ID, including region/default recipes.
 for(const id of Object.keys(initial.ambientGrades)){
  replace([rect(id)],[]);const captured=capture(5,5);
  grades.push({id,...captured});
 }
 replace(initial.zones,initial.terrainRegions);
 // Independent standards compositor over captured source operations, not a claimed
 // browser pixel oracle. Real Canvas/native/Web raster patches remain pending.
 const patches=[[0,0,0],[1,1,1],[.5,.5,.5],[127/255,128/255,129/255],[1,0,0],[0,1,0],[0,0,1],
  ...['e8c040','4a5028','1a1810','604020','d4c896','8a3a3a','d488d4','d06030'].map(hex=>[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255))];
 function composite(backdrop,operations){
  return operations.reduce((b,op)=>b.map((v,i)=>{
   const blend=op.operation==='multiply'?v*op.rgb[i]:v<=.5?2*v*op.rgb[i]:1-2*(1-v)*(1-op.rgb[i]);
   return (1-op.alpha)*v+op.alpha*blend;
  }),backdrop.slice());
 }
 const blends=[];for(const grade of grades)for(const [i,background]of patches.entries())blends.push({id:grade.id+'/'+i,recipe:grade.expected,background,expected:composite(background,grade.operations)});
 assert.equal(draws,0);assert.equal(initial.zones.length,23);assert.equal(initial.terrainRegions.length,15);assert.equal(grades.length,39);
 const sourceFiles=['src/render/landmarks_a.js','src/data/world.js','src/render/actors_weather.js','src/render/frame.js'];
 const hashes=Object.fromEntries(sourceFiles.map(file=>[file,hash(fs.readFileSync(path.join(ROOT,file)))]));
 return {schema:1,format:'rock-bottom-district-grade-draft-reference',source:{authority:'unchanged ambientGradeAt/drawAmbientGrade; captured operations; W3C float compositor only, no raster oracle',hashes,generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},counts:{lookups:lookups.length,grades:grades.length,blends:blends.length,rngDraws:draws},variants,lookups,grades,blends};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildOracle(),output=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'District grade oracle drift');else fs.writeFileSync(OUTPUT,output);
 console.log(`DISTRICT GRADE DRAFT ORACLE: PASS (${result.counts.lookups} lookups / ${result.counts.grades} grades / ${result.counts.blends} mathematical blends; zero RNG)`);
}
