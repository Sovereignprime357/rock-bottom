import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/fixtures/leash_border_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const fields=s=>({borderGlowT:s.borderGlowT??0,borderGlowColor:s.borderGlowColor??'',borderGlowRect:s.borderGlowRect??{},lastZoneId:s.lastZoneId??null});
export async function buildLeashBorderOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const geography=game.module('src/render/landmarks_b.js'),structures=game.module('src/render/structures.js'),props=game.module('src/data/props.js').PROPS;
 const text=fs.readFileSync(path.join(ROOT,'src/core/update.js'),'utf8');
 const start=text.indexOf('  if (state.borderGlowT > 0)'),end=text.indexOf('  // v13 wave 6 — first-time underpass entry:',start);
 assert.ok(start>=0&&end>start,'Exact source border statement block must exist.');
 const block=text.slice(start,end);assert.ok(block.includes('state.lastZoneId = curZoneId;'));
 const advance=vm.runInContext(`(function(state,currentZone,dt){${block}\n})`,game.context,{filename:'unchanged-update-border-block.js'});
 const ctx=game.context.__qa.context2d;let draws=0,strokes=[],dots=[],draw=null,at=null;
 game.context.Math.random=()=>{draws++;return .5;};
 ctx.save=()=>{};ctx.restore=()=>{};ctx.beginPath=()=>{};ctx.moveTo=(x,y)=>{at=[x,y];};
 ctx.lineTo=(x,y)=>{strokes.push({from:at,to:[x,y]});at=[x,y];};ctx.stroke=()=>{};
 ctx.fillRect=(x,y,w,h)=>dots.push({x,y,w,h,color:ctx.fillStyle});
 ctx.strokeRect=(x,y,w,h)=>{draw={visible:true,rect:{x,y,w,h},color:ctx.strokeStyle,alpha:ctx.globalAlpha,width:ctx.lineWidth};};
 const zone=(id,faction='street')=>({id,faction,x:100,y:200,w:300,h:250});
 const old={borderGlowT:450,borderGlowColor:'#c08038',borderGlowRect:{x:1,y:2,w:3,h:4},lastZoneId:'scrap'};
 const definitions=[
  {id:'first_unknown',previous:{},territory_zone_id:null,current_zone:null,delta_ms:16},
  {id:'first_zone_no_flash',previous:{},territory_zone_id:'block',current_zone:zone('block'),delta_ms:16},
  {id:'ticker_not_due',previous:{lastZoneId:'block'},territory_zone_id:'block',current_zone:zone('market'),delta_ms:16},
  {id:'ticker_transition',previous:{lastZoneId:'block'},territory_zone_id:'market',current_zone:zone('market'),delta_ms:16},
  ...['street','scrap','spiritual','neutral'].map(faction=>({id:'destination_'+faction,previous:old,territory_zone_id:'new_'+faction,current_zone:zone('new_'+faction,faction),delta_ms:16})),
  {id:'same_faction_zone_crossing',previous:{lastZoneId:'block'},territory_zone_id:'dealer',current_zone:zone('dealer','street'),delta_ms:50},
  {id:'exit_no_new_flash',previous:old,territory_zone_id:null,current_zone:null,delta_ms:100},
  {id:'null_to_zone_no_flash',previous:{...old,lastZoneId:null},territory_zone_id:'park',current_zone:zone('park','spiritual'),delta_ms:100},
  {id:'current_zone_matches_previous',previous:old,territory_zone_id:'other',current_zone:zone('scrap','scrap'),delta_ms:20},
  {id:'decrement_zero',previous:{...old,borderGlowT:0},territory_zone_id:'scrap',current_zone:zone('scrap','scrap'),delta_ms:16},
  {id:'decrement_exact',previous:{...old,borderGlowT:100},territory_zone_id:'scrap',current_zone:zone('scrap','scrap'),delta_ms:100},
  {id:'decrement_over',previous:{...old,borderGlowT:100},territory_zone_id:'scrap',current_zone:zone('scrap','scrap'),delta_ms:101},
  {id:'long_step_then_arm',previous:old,territory_zone_id:'church',current_zone:zone('church','spiritual'),delta_ms:10000},
  {id:'paused_not_called',previous:old,territory_zone_id:'market',current_zone:zone('market'),delta_ms:500,call:false},
  {id:'falsy_color_fallback',previous:{borderGlowT:300,borderGlowRect:old.borderGlowRect,lastZoneId:'scrap'},territory_zone_id:'scrap',current_zone:zone('scrap'),delta_ms:16},
  {id:'negative_prior_timer_preserved',previous:{...old,borderGlowT:-10},territory_zone_id:'scrap',current_zone:zone('scrap'),delta_ms:16},
  {id:'alpha_cap',previous:{...old,borderGlowT:1000},territory_zone_id:'scrap',current_zone:zone('scrap'),delta_ms:16},
 ];
 const border=[];
 for(const input of definitions){
  const s=copy(input.previous);s.territoryZoneId=input.territory_zone_id;const current=input.current_zone?copy(input.current_zone):null;
  const beforeZone=JSON.stringify(current);draws=0;
  if(input.call!==false)advance(s,()=>current,input.delta_ms);
  assert.equal(JSON.stringify(current),beforeZone);assert.equal(draws,0);
  for(const key of ['borderGlowT','borderGlowColor','borderGlowRect','lastZoneId'])delete ui.state[key];
  Object.assign(ui.state,s);draw=null;structures.drawBorderGlow();
  border.push({...input,call:input.call!==false,expected:copy(fields(s)),draw:draw||{visible:false,alpha:0,width:3},rngDraws:draws});
 }
 const post=props.find(p=>p.type==='leash_post');assert.ok(post);const originalProps=[...props];
 const dog={id:'scrap_dog',sprite:'scrap_dog',x:post.x+30,y:post.y+20,w:26,h:24,dead:false,chained:true};
 const leashInputs=[
  {id:'living_chained',post_present:true,npcs:[dog]},
  {id:'attacked_chain_flag_false',post_present:true,npcs:[{...dog,chained:false}]},
  {id:'hidden_living_quirk',post_present:true,npcs:[{...dog,hidden:true}]},
  {id:'dead_original',post_present:true,npcs:[{...dog,dead:true}]},
  {id:'freed_follower_only',post_present:true,npcs:[{...dog,id:'freed_dog_follower',chained:false}]},
  {id:'paisley_only',post_present:true,npcs:[{...dog,id:'paisley'}]},
  {id:'no_dog',post_present:true,npcs:[]},
  {id:'missing_post',post_present:false,npcs:[dog]},
  {id:'dead_then_living_original',post_present:true,npcs:[{...dog,dead:true},{...dog,x:dog.x+10}]},
  {id:'first_living_original_wins',post_present:true,npcs:[dog,{...dog,x:dog.x+90}]},
  {id:'exact_id_not_sprite',post_present:true,npcs:[{...dog,sprite:'brutus'}]},
 ];
 const leash=[];
 for(const input of leashInputs){
  props.splice(0,props.length,...originalProps.filter(p=>input.post_present||p.type!=='leash_post'));
  ui.runtime.npcs=copy(input.npcs);ui.state.cam={x:post.x-200,y:post.y-200};strokes=[];dots=[];draws=0;
  const before=JSON.stringify(ui.runtime.npcs);geography.drawDogLeash();assert.equal(JSON.stringify(ui.runtime.npcs),before);assert.equal(draws,0);
  const selected=input.npcs.find(n=>n.id==='scrap_dog'&&!n.dead)||{};
  assert.ok(strokes.length===0||strokes.length===2);assert.equal(dots.length,strokes.length?5:0);
  leash.push({id:input.id,post_present:input.post_present,source_npcs:input.npcs,dog:selected,drawn:strokes.length>0,strokes:copy(strokes),dots:copy(dots),rngDraws:draws});
 }
 props.splice(0,props.length,...originalProps);
 const files=['src/core/update.js','src/render/structures.js','src/render/landmarks_b.js','src/render/canvas_geography.js','src/systems/factions.js','src/data/props.js','src/core/runtime_ui.js','VIBE.md'];
 const hashes=Object.fromEntries(files.map(file=>[file,hash(fs.readFileSync(path.join(ROOT,file)))]));
 return {schema:1,format:'rock-bottom-leash-border-reference',source:{authority:'unchanged drawDogLeash/drawBorderGlow and exact extracted updateWorld border statements',hashes,blockSha256:hash(block),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs'))),undefinedDefaults:{borderGlowT:0,borderGlowColor:'',borderGlowRect:{},lastZoneId:null}},counts:{border:border.length,leash:leash.length},border,leash};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildLeashBorderOracle(),output=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Leash/border source oracle drift.');
 else{fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,output);}
 console.log(`LEASH BORDER ORACLE: PASS (${result.counts.border} border/${result.counts.leash} leash cases)`);
}
