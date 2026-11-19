import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/world_ownership_reference.json');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const clone=x=>JSON.parse(JSON.stringify(x));
export async function buildOwnershipOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
 const source=game.module('src/render/structures.js'),geo=game.module('src/render/canvas_geography.js');
 const campaign=game.module('src/systems/campaigns.js'),daily=game.module('src/systems/daily_hideouts.js');
 ui.init_runtime_ui();start.startGame(false);geo.buildEnvironmentSprites();
 let calls=[],draws=0;const ctx=geo.ctx;game.context.Math.random=()=>{draws++;throw Error('Random draw in readonly ownership renderer');};
 for(const op of ['fillRect','strokeRect','fillText','drawImage'])ctx[op]=(...args)=>calls.push({op,args:op==='drawImage'?args.slice(1):args,color:op==='strokeRect'?ctx.strokeStyle:ctx.fillStyle});
 function capture(fn,point){ui.state.cam={x:point.x-400,y:point.y-300};calls=[];const before=stableStringify({p:ui.P,office:ui.state.office,claims:ui.state.districtClaims,flags:ui.state.flags});fn();assert.equal(stableStringify({p:ui.P,office:ui.state.office,claims:ui.state.districtClaims,flags:ui.state.flags}),before);return clone(calls);}
 const rect=(a,x,y)=>a.find(c=>c.op==='fillRect'&&c.args[0]===x&&c.args[1]===y);
 function expected(snapshot,center){
  ui.state.office=clone(snapshot.office||{});ui.state.districtClaims=clone(snapshot.districtClaims||{});ui.state.flags=clone(snapshot.flags||{});
  ui.P.x=center[0]-ui.P.w/2;ui.P.y=center[1]-ui.P.h/2;
  const a=capture(source.drawOfficeExterior,{x:4920,y:3050}),d=campaign.OFFICE_DOOR;
  const title=a.find(c=>c.op==='fillText'&&c.args[2]===2905),border=a.find(c=>c.op==='strokeRect');
  const upgrades={};const coords={route_board:[5146,3128],locker:[4670,3130],cot:[4652,3207],generator:[5160,3172],radio:[5099,2838]};
  for(const [id,at]of Object.entries(coords))upgrades[id]=!!rect(a,...at);
  const papers=a.filter(c=>c.op==='fillRect'&&c.args[0]>=4750&&c.args[0]<=4810&&c.args[2]===9&&c.args[3]===5);upgrades.desk=papers.length>0;
  const office={owned:rect(a,d.x,d.y).color==='#5a4028',claims:campaign.claimedDistrictIds().length,title:title.args[0],locked:!!rect(a,d.x+8,d.y+13),door_color:rect(a,d.x,d.y).color,panel_color:rect(a,d.x+3,d.y+4).color,knob_color:rect(a,d.x+d.w-7,d.y+d.h/2).color,sign_border:border.color,sign_color:title.color,upgrades,paper_count:papers.length,mailbox:!!rect(a,4720,3230),trim:!!rect(a,4680,2876),e_hint:a.some(c=>c.op==='fillText'&&c.args[0]==='(E)')};
  const claims={};for(const site of campaign.CLAIM_SITES){const b=capture(source.drawClaimSites,site.sign);claims[site.id]={visible:b.some(c=>c.op==='drawImage'&&c.args[0]===Math.round(site.sign.x-16)&&c.args[1]===Math.round(site.sign.y-30)),caption:b.some(c=>c.op==='fillText'&&c.args[0]==='THE OFFICE CLAIMS'&&c.args[1]===site.sign.x&&c.args[2]===site.sign.y-34)};}
  const hideouts={};for(const id of ['scrap','mom']){const door=daily.HIDEOUT_DOORS[id],b=capture(source.drawHideoutDoors,door),base=rect(b,door.x,door.y),panel=rect(b,door.x+3,door.y+4);hideouts[id]={visible:!!base,door_color:base?.color||palettes[id].door_color,panel_color:panel?.color||palettes[id].panel_color,e_hint:b.some(c=>c.op==='fillText'&&c.args[0]==='(E)'&&c.args[1]===door.x+door.w/2)};}
  return {office,claims,hideouts};
 }
 const palettes={};ui.state.flags={scrapHideoutOwned:true,momHideoutOwned:true};for(const id of ['scrap','mom']){const d=daily.HIDEOUT_DOORS[id],a=capture(source.drawHideoutDoors,d);palettes[id]={door_color:rect(a,d.x,d.y).color,panel_color:rect(a,d.x+3,d.y+4).color};}
 const cases=[];const ids=campaign.CLAIM_SITES.map(s=>s.id),upgradeIds=campaign.OFFICE_UPGRADE_DEFS.map(d=>d.id);
 const snapshot=(owned=false,count=0,mask=0)=>({office:{owned,upgrades:Object.fromEntries(upgradeIds.map((id,i)=>[id,!!(mask&(1<<i))]))},districtClaims:Object.fromEntries(ids.slice(0,count).map(id=>[id,true])),flags:{scrapHideoutOwned:false,momHideoutOwned:false}});
 const add=(id,s,center=[4920,3260])=>cases.push({id,snapshot:s,center,expected:expected(s,center)});
 for(const owned of [false,true])for(const count of [0,1,3,4,7,8,10,11])for(let mask=0;mask<64;mask++)add('office_'+Number(owned)+'_'+count+'_'+mask,snapshot(owned,count,mask));
 for(const site of campaign.CLAIM_SITES)for(const distance of [99.99,100,100.01])add('caption_'+site.id+'_'+distance,{...snapshot(),districtClaims:{[site.id]:true}},[site.sign.x+distance,site.sign.y]);
 for(const distance of [59.99,60,60.01])for(const id of ['scrap','mom']){const s=snapshot();s.flags[id+'HideoutOwned']=true;const d=daily.HIDEOUT_DOORS[id];add('hideout_'+id+'_'+distance,s,[d.x+d.w/2+distance,d.y+d.h/2]);}
 for(const distance of [63.99,64,64.01])add('office_hint_'+distance,snapshot(true),[4920+distance,3220]);
 for(const value of [false,null,0,1,'','yes',[],{}]){const s=snapshot();s.office.owned=value;s.office.upgrades={desk:value,generator:value};s.districtClaims={canal:value,unknown:true};s.flags={scrapHideoutOwned:value,momHideoutOwned:value};add('truth_'+JSON.stringify(value),s,[4380,2110]);}
 for(let mask=0;mask<4;mask++){const s=snapshot(true,11,63);s.flags={scrapHideoutOwned:!!(mask&1),momHideoutOwned:!!(mask&2)};add('hideout_mask_'+mask,s,[532,216]);}
 assert.equal(draws,0);assert.equal(cases.length,1078);
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-world-ownership-reference',source:{authority:'unchanged drawOfficeExterior, drawClaimSites, drawHideoutDoors; captured canvas calls, no rewritten outcome rules',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},counts:{cases:cases.length,claims:ids.length,upgrades:upgradeIds.length,rngDraws:draws},cases};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildOwnershipOracle(),out=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),out,'Ownership oracle drift');else fs.writeFileSync(OUTPUT,out);
 console.log('3D WORLD OWNERSHIP ORACLE: PASS ('+result.counts.cases+' views; 11 claims / 6 upgrades; zero RNG and state mutation)');
}
