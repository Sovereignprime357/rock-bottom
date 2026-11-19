import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/kingdom_view_reference.json');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const clone=x=>JSON.parse(JSON.stringify(x));
export async function buildKingdomViewOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
 const source=game.module('src/render/landmarks_a.js'),geo=game.module('src/render/canvas_geography.js'),campaign=game.module('src/systems/campaigns.js');
 ui.init_runtime_ui();start.startGame(false);geo.buildEnvironmentSprites();
 const defs=[['blue_tarp',campaign.KINGDOM_CLANS.blue_tarp,'clan_banner_blue','blueTarpCleared'],['cart_cavalry',campaign.KINGDOM_CLANS.cart_cavalry,'clan_banner_receipt','cartKeepCleared'],['copper_choir',campaign.KINGDOM_CLANS.copper_choir,'clan_banner_wire','copperChoirCleared'],['emperor',campaign.KINGDOM_EMPEROR,'clan_banner_curb','throneDitchCleared']];
 let calls=[],dash=[],draws=0;const ctx=geo.ctx;
 game.context.Math.random=()=>{draws++;throw Error('Random draw in readonly Kingdom renderer');};
 ctx.setLineDash=value=>{dash=[...value];};
 ctx.drawImage=(image,...args)=>calls.push({op:'image',args,alpha:ctx.globalAlpha,key:Object.keys(geo.ENV_SPRITE_CACHE).find(key=>geo.ENV_SPRITE_CACHE[key]===image)});
 ctx.strokeRect=(...args)=>calls.push({op:'border',args,color:ctx.strokeStyle,dash:[...dash]});
 ctx.fillText=(...args)=>calls.push({op:'text',args,color:ctx.fillStyle});
 function capture(point){ui.state.cam={x:point.x-400,y:point.y-300};calls=[];const before=stableStringify({kingdom:ui.state.kingdom,flags:ui.state.flags,p:ui.P});source.drawKingdomSites();assert.equal(stableStringify({kingdom:ui.state.kingdom,flags:ui.state.flags,p:ui.P}),before);return clone(calls);}
 function expected(snapshot){
  ui.state.kingdom=clone(snapshot.kingdom??null);ui.state.flags=clone(snapshot.flags??null);
  const banners={},marks={};
  for(const [id,d,key] of defs){const a=capture(d.banner),image=a.find(c=>c.op==='image'&&c.key===key);assert(image,'canonical banner '+id);banners[id]={alpha:image.alpha};
   for(const [index,m]of(d.marks||[]).entries()){const a=capture(m),border=a.find(c=>c.op==='border'&&c.args[0]===m.x-9&&c.args[1]===m.y-9);if(!border){marks[id+':'+index]={visible:false};continue;}const text=a.find(c=>c.op==='text'&&c.args[1]===m.x&&c.args[2]===m.y+3);assert(text);marks[id+':'+index]={visible:true,done:text.args[0]==='✓',text:text.args[0],border:border.color,text_color:text.color,dashed:border.dash.length>0};}
  }
  return {banners,marks};
 }
 const cases=[];const add=(id,snapshot)=>cases.push({id,snapshot,expected:expected(snapshot)});
 for(const stage of campaign.KINGDOM_STAGES)for(let marks=0;marks<8;marks++)for(let mask=0;mask<16;mask++)add(stage+'_'+marks+'_'+mask,{kingdom:{stage,marks},flags:Object.fromEntries(defs.map(([, , ,flag],index)=>[flag,!!(mask&(1<<index))]))});
 for(const value of [null,false,true,0,1,-1,1.9,-2.9,7,8,4294967297,2147483648,'','7','nonsense',[],{}])for(const d of campaign.KINGDOM_CLAN_LIST)add('bits_'+d.id+'_'+JSON.stringify(value),{kingdom:{stage:d.marksStage,marks:value},flags:{}});
 for(const value of [null,false,true,0,1,'','yes',[],{}])add('flags_'+JSON.stringify(value),{kingdom:{stage:'locked',marks:7},flags:Object.fromEntries(defs.map(([, , ,flag])=>[flag,value]))});
 add('missing',{});add('null',{kingdom:null,flags:null});add('unknown_stage',{kingdom:{stage:'invented',marks:7},flags:{blueTarpCleared:true}});
 assert.equal(draws,0);assert.equal(cases.length,1599);
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-kingdom-view-reference',source:{authority:'unchanged drawKingdomSites; captured canvas operations with canonical per-site cameras',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},counts:{cases:cases.length,banners:4,marks:9,rngDraws:draws},cases};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildKingdomViewOracle(),out=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),out,'Kingdom view oracle drift');else fs.writeFileSync(OUTPUT,out);
 console.log('3D KINGDOM VIEW ORACLE: PASS ('+result.counts.cases+' views; 4 banners / 9 marks; zero RNG and state mutation)');
}
