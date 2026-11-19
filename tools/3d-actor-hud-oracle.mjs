import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/actor_hud_reference.json');
const clone=x=>JSON.parse(JSON.stringify(x));
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
function recorder(ctx){
 const commands=[],stack=[];Object.assign(ctx,{font:'10px Courier New',fillStyle:'#000',strokeStyle:'#000',globalAlpha:1,textAlign:'left'});
 const capture=(op,values)=>commands.push({op,values,fill:ctx.fillStyle,stroke:ctx.strokeStyle,font:ctx.font,alpha:ctx.globalAlpha,align:ctx.textAlign});
 for(const op of ['fillText','fillRect','strokeRect','drawImage','moveTo','lineTo','beginPath','fill'])ctx[op]=(...v)=>capture(op,v);
 ctx.measureText=text=>({width:String(text).length*5.4});
 ctx.save=()=>stack.push({font:ctx.font,fillStyle:ctx.fillStyle,strokeStyle:ctx.strokeStyle,globalAlpha:ctx.globalAlpha,textAlign:ctx.textAlign});
 ctx.restore=()=>Object.assign(ctx,stack.pop());
 ctx.createRadialGradient=(...values)=>{const g={values,stops:[]};g.addColorStop=(at,color)=>g.stops.push({at,color});return g;};
 return commands;
}
const alpha=color=>Number(String(color).match(/,([^,]+)\)$/)?.[1]??0);
function actorResult(n,commands){
 const texts=commands.filter(c=>c.op==='fillText'),cx=n.x+n.w/2,markers=[];
 for(const c of texts){
  let kind=null;
  if(c.font==='10px Courier New'&&c.values[0]==='z')kind='sleep';
  else if(c.font==='bold 14px Courier New')kind='aggro';
  else if(c.font==='bold 18px Courier New')kind='windup';
  else if(c.font==='bold 10px Courier New')kind='aim';
  else if(c.font==='bold 11px Courier New')kind='radio';
  else if(c.font==='bold 12px Courier New')kind='grab';
  else if(/^bold (16|22)px Courier New$/.test(c.font)&&c.fill==='#e8c040')kind='floater';
  if(kind)markers.push({kind,text:c.values[0],x:c.values[1]-cx,y:c.values[2]-n.y,font_px:Number(c.font.match(/(\d+)px/)[1]),color:c.fill,bold:c.font.startsWith('bold'),alpha:c.alpha});
 }
 const rects=commands.filter(c=>c.op==='fillRect'),hp=rects.find(c=>['#a8c030','#e8c040','#d04040'].includes(c.fill));
 const windup=rects.find(c=>String(c.fill).startsWith('rgba(208,64,64,'));
 const cooldown=rects.find(c=>String(c.fill).startsWith('rgba(208,192,160,'));
 const chatter=rects.some(c=>c.fill==='rgba(0,0,0,.85)')?texts.at(-1).values[0]:'';
 const lines=n._labelLines??[];
 return {show_name:Object.hasOwn(n,'_labelLines'),name_lines:lines,name_color:texts.find(c=>c.font==='9px Courier New'&&lines.includes(c.values[0]))?.fill??null,
  hp:hp?{hp:n.hp,max_hp:n.maxHp,ratio:hp.values[2]/n.w,color:hp.fill}:{},markers,
  windup:windup?{color:'#d04040',alpha:alpha(windup.fill)}:{},cooldown:cooldown?{color:'#d0c0a0',alpha:alpha(cooldown.fill)}:{},chatter};
}
function combatResult(commands){
 const rects=commands.filter(c=>c.op==='fillRect'),texts=commands.filter(c=>c.op==='fillText');
 const tint=prefix=>alpha(rects.find(c=>String(c.fill).startsWith(prefix))?.fill);
 const flash=rects.find(c=>c.fill==='#123456'),gradient=rects.find(c=>typeof c.fill==='object');
 const bossText=texts.find(c=>c.font==='bold 12px Courier New'),bossBar=rects.find(c=>c.values[1]===28&&c.fill==='#8a3a3a');
 const combo=texts.find(c=>c.values[0].endsWith('x'));
 return {flash:flash?.alpha??0,flash_color:'#123456',high:tint('rgba(232,192,64,'),crash:tint('rgba(180,80,180,'),
  stun:tint('rgba(208,64,64,'),stun_text:texts.find(c=>c.values[0]==='GRABBED')?.values[0]??'',slow:tint('rgba(160,200,240,'),low_hp:tint('rgba(160,40,40,'),
  vignette:gradient?alpha(gradient.fill.stops[1].color):0,shakes:tint('rgba(212,136,212,'),
  boss:bossText?{text:bossText.values[0],ratio:bossBar.values[2]/300}:{},combo:combo?{text:combo.values[0],label:'combo',font_px:Number(combo.font.match(/(\d+)px/)[1]),alpha:alpha(combo.fill)}:{}};
}
export async function buildActorHudOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),render=game.module('src/render/actors_weather.js'),catalog=game.module('src/data/catalogs.js');
 const ctx=game.context.__qa.context2d,actors=[],combat=[];let now=0,randomDraws=0;
 game.context.performance.now=()=>now;game.context.Math.random=()=>{randomDraws++;return .5;};
 const base={id:'unknown',name:'THE MAN WITH MANY OTHER IMPORTANT WORDS',x:100,y:200,w:28,h:34,hp:100,maxHp:100,showHp:true,sprite:'tony',frame:0,color:'#604020'};
 const player={x:100,y:200,w:28,h:34};
 const variants=[{},...['asleep','aggro','hostile','vendor','aimingThrow'].map(k=>({[k]:true})),
  {chargeState:'windup'},{chargeState:'cooldown'},{radioVisualT:1},{radioVisualT:0},{radioVisualT:-1},{grabFreezeT:1},{grabFreezeT:0},
  {hasFloater:'?'},{hasFloater:'?',isBusDriver:true},{hasFloater:'!'},{hasFloater:0},{id:'tony'},{id:'train_hopper'},{id:'hopper'},{id:'tony',hostile:true},{id:'tony',aggro:true},
  {chatterT:1,chatter:'the copper sings in b flat.'},{chatterT:0,chatter:'not yet.'},{chatterT:1,chatter:''},
  {hp:60.00001},{hp:60},{hp:30.00001},{hp:30},{hp:0},{hp:-8},{hp:200},{hp:50,showHp:false},
  {name:'A'},{name:'12345678901234567 X Y Z'},{name:'  ONE    TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE '},{name:''},
  {asleep:true,aggro:true,chargeState:'windup',aimingThrow:true,radioVisualT:1,grabFreezeT:1,chatterT:20,chatter:'all at once.',hp:24},
  {id:'tony',hasFloater:'?',isBusDriver:true,chargeState:'cooldown',hp:65,chatterT:10,chatter:'what.'}];
 for(const time of [0,1,180,997,5700])for(let index=0;index<variants.length;index++){
  const input={...base,...variants[index]},n=clone(input);now=time;Object.assign(ui.P,player);ui.state.metVendors=new Set();render.NAMEPLATE_BOX_BUFFER.length=0;
  const calls=recorder(ctx);render.drawNpc(n);actors.push({id:`variant${index}@${time}`,actor:input,player,met:[],visual_ms:time,expected:actorResult(n,calls)});
 }
 for(const distance of [259.9999,260,260.0001,3000])for(const variant of [{},{vendor:true},{hostile:true},{aggro:true}]){
  const input={...base,...variant},n=clone(input),p={...player,x:player.x+distance};Object.assign(ui.P,p);now=123;ui.state.metVendors=new Set();render.NAMEPLATE_BOX_BUFFER.length=0;
  const calls=recorder(ctx);render.drawNpc(n);actors.push({id:`distance${distance}:${JSON.stringify(variant)}`,actor:input,player:p,met:[],visual_ms:now,expected:actorResult(n,calls)});
 }
 for(const id of [...catalog.VENDOR_FLOATER_IDS,'hopper','cubscout'])for(const met of [[],[id]]){
  const input={...base,id},n=clone(input);Object.assign(ui.P,player);now=321;ui.state.metVendors=new Set(met);render.NAMEPLATE_BOX_BUFFER.length=0;
  const calls=recorder(ctx);render.drawNpc(n);actors.push({id:`vendor:${id}:${met.length}`,actor:input,player,met,visual_ms:now,expected:actorResult(n,calls)});
 }
 const frameFile=fs.readFileSync(path.join(ROOT,'src/render/frame.js'),'utf8');
 const start=frameFile.indexOf('  // flash overlay'),end=frameFile.indexOf('  // weather under HUD',start);assert(start>0&&end>start);
 const drawCombat=vm.runInContext(`(function(P,state,ctx,W,H){${frameFile.slice(start,end)}\n})`,game.context);
 const combatBase={mode:'playing',flash:0,flashColor:'#123456',bossActive:false,bossNPC:null,bossKind:null,combo:0,comboT:0};
 const pbase={hp:100,rockedT:0,crashT:0,stunT:0,slowT:0,shakes:0};
 const combos=[{},...['rockedT','crashT','stunT','slowT'].map(k=>({p:{[k]:1}})),{p:{rockedT:1,crashT:1}},
  ...[31,30,0,-20].map(hp=>({p:{hp}})),...[89.999,90,120].map(shakes=>({p:{shakes}})),
  ...[1,2,4].flatMap(combo=>[0,200,1000,2000].map(comboT=>({s:{combo,comboT}}))),
  ...[0,.1,1,2].map(flash=>({s:{flash}})),
  ...['tony','kingdom','older','omalley','os_brutus'].flatMap(bossKind=>[100,0,-4,3.2].map(hp=>({s:{bossActive:true,bossKind,bossNPC:{name:'DARRYL UNDER BLUE',hp,maxHp:100}}}))),
  {s:{bossActive:true,bossNPC:{name:'gone',hp:50,maxHp:100,dead:true}}},{s:{bossActive:false,bossNPC:{name:'not active',hp:50,maxHp:100}}},
  {p:{hp:15,stunT:1,slowT:1,rockedT:1,crashT:1,shakes:100},s:{flash:.2,combo:3,comboT:500,bossActive:true,bossKind:'kingdom',bossNPC:{name:'THE CURB EMPEROR',hp:400,maxHp:400}}}];
 for(const time of [0,1,301,1990])for(let index=0;index<combos.length;index++){
  now=time;const p={...pbase,...combos[index].p},s={...combatBase,...combos[index].s};const calls=recorder(ctx);drawCombat(p,s,ctx,800,600);
  const expected=combatResult(calls);if(!Object.keys(expected.boss).length)assert.equal(calls.some(c=>c.op==='fillText'&&c.font==='bold 12px Courier New'),false);
  combat.push({id:`combat${index}@${time}`,player:p,state:s,visual_ms:time,expected});
 }
 assert.equal(randomDraws,0);assert(actors.length>200&&combat.length>150);
 return {schema:1,format:'rock-bottom-actor-hud-reference',source:{files:['src/render/actors_weather.js','src/render/frame.js','src/data/catalogs.js'].map(file=>({file,sha256:sha(fs.readFileSync(path.join(ROOT,file)))})),generatorSha256:sha(fs.readFileSync(fileURLToPath(import.meta.url))),authority:'unchanged drawNpc canvas calls and verbatim frame flash-to-shakes block; camera/LOS/layout are explicit3D adaptations'},vendor_ids:[...catalog.VENDOR_FLOATER_IDS],randomDraws,actor_count:actors.length,combat_count:combat.length,actors,combat};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildActorHudOracle(),out=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),out,'Actor HUD source fixture drift.');else fs.writeFileSync(OUTPUT,out);
 console.log(`3D ACTOR HUD ORACLE: PASS (${result.actor_count} actor views / ${result.combat_count} combat views; zero random draws)`);
}
