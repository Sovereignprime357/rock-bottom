import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/guidance_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value,(_k,v)=>Object.prototype.toString.call(v)==='[object Set]'?[...v]:v));
const plain=html=>html.replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim();
const difference=(base,next)=>{
  if(JSON.stringify(base)===JSON.stringify(next))return undefined;
  if(base&&next&&!Array.isArray(base)&&!Array.isArray(next)&&typeof base==='object'&&typeof next==='object'){
    const delta={};for(const [key,value]of Object.entries(next)){const item=difference(base[key],value);if(item!==undefined)delta[key]=item;}return delta;
  }return next;
};
export async function buildGuidanceOracle(){
  const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
  const campaigns=game.module('src/systems/campaigns.js'),progression=game.module('src/systems/progression_routes.js'),minimap=game.module('src/render/minimap.js');
  const catalogs=game.module('src/data/catalogs.js'),recognition=game.module('src/systems/recognition.js'),discovery=game.module('src/systems/discovery.js');
  let randomCalls=0; const reset=()=>{ui.init_runtime_ui();start.startGame(false);game.context.__qa.timers.length=0;randomCalls=0;game.context.Math.random=()=>{randomCalls++;return .4;};delete game.context.npcs;};
  reset();ui.state.metVendors.add('tony');let originalDefect='';try{ui.renderQuests();}catch(e){originalDefect=e.name+': '+e.message;}
  assert.equal(originalDefect,'ReferenceError: npcs is not defined');
  const keys=['flags','quests','office','kingdom','districtClaims','blockRoute','hustles','hustleSnapshot','counters','recognition','concessionClocks','discoveredVenues','metVendors','day','dayTime','crownPickup','freedDogFollowT'];
  const capture=()=>({p:copy(ui.P),s:Object.fromEntries(keys.filter(k=>Object.hasOwn(ui.state,k)).map(k=>[k,copy(ui.state[k])])),npcs:copy(ui.runtime.npcs),cash:copy(ui.runtime.cashPiles)});
  const calls=[];let line=[];const ctx=minimap.mmctx;
  ctx.fillRect=(...values)=>calls.push({op:'fill',color:ctx.fillStyle,values,width:1});
  ctx.strokeRect=(...values)=>calls.push({op:'stroke',color:ctx.strokeStyle,values,width:ctx.lineWidth});
  ctx.beginPath=()=>{line=[];};ctx.moveTo=(...p)=>line.push(...p);ctx.lineTo=(...p)=>line.push(...p);
  ctx.stroke=()=>calls.push({op:'line',color:ctx.strokeStyle,values:[...line],width:ctx.lineWidth});
  const worlds=game.module('src/data/world.js');const staticCount=1+worlds.ZONES.length+worlds.ROAD_SEGMENTS.length+worlds.LANDMARK_FACADES.length+worlds.RAIL_LINES.length;
  const cases=[];
  const add=(id,setup=()=>{})=>{reset();setup();const before=capture();randomCalls=0;const objective=copy(campaigns.currentPrimaryObjective());
    // Explicit test-only alias for intended full journal, separate from original error above.
    game.context.npcs=ui.runtime.npcs;ui.renderQuests();const text=plain(ui.panelEl.innerHTML);const journal=text.slice(text.indexOf('NOW '));
    assert.deepEqual(capture(),before,'read-only source views '+id);assert.equal(randomCalls,0);
    ui.state.primaryObjective=objective;calls.length=0;minimap.drawMinimap();const map=copy(calls);assert.equal(map.at(-1).color,'rgba(232,192,64,.4)');map.pop();
    cases.push({id,before,objective,journal,mapStatic:map.slice(0,staticCount),mapDynamic:map.slice(staticCount),randomCalls});};
  const afterIntro=()=>{ui.state.flags.introDone=true;for(const q of Object.values(ui.state.quests))q.done=true;ui.state.blockRoute=null;ui.P.rocks=0;ui.P.soapRocks=0;};
  add('fresh_intro');add('intro_partial',()=>{ui.state.counters.introCashEarned=6;});
  add('intro_cash_fallback',()=>{ui.runtime.cashPiles.forEach(p=>p.collected=true);ui.state.counters.introCashEarned=12;});
  add('intro_tony',()=>{ui.state.quests.intro_remember.done=true;});
  add('intro_talking_not_purchase',()=>{ui.state.quests.intro_remember.done=true;ui.state.quests.intro_tony.done=true;});
  add('intro_soap_counts',()=>{ui.state.quests.intro_remember.done=true;ui.state.quests.intro_tony.done=true;ui.P.soapRocks=1;});
  add('idle',afterIntro);
  for(const q of Object.keys(ui.state.quests).filter(k=>!k.startsWith('intro_')))add('quest_'+q,()=>{afterIntro();ui.state.quests[q].done=false;ui.state.quests[q].available=true;});
  add('quest_canonical_order',()=>{afterIntro();for(const id of ['first_rock','copper_sings','finisher','conductor'])ui.state.quests[id].done=false;});
  add('crown_position',()=>{afterIntro();ui.state.quests.pigeon_crown.done=false;ui.state.quests.pigeon_crown.available=true;ui.state.crownPickup={x:345,y:678,collected:false};});
  add('crown_collected',()=>{afterIntro();ui.state.quests.pigeon_crown.done=false;ui.state.quests.pigeon_crown.available=true;ui.state.crownPickup={x:345,y:678,collected:true};});
  for(const value of [49.999,50,100])for(const high of [0,1])add('loop_'+value+'_'+high,()=>{afterIntro();ui.P.rocks=1;ui.P.shakes=value;ui.P.rockedT=high;});
  for(const venue of recognition.REGULAR_VENUES)for(const clock of [.1,.5,.9])add('legal_smoke_'+venue.id+'_'+clock,()=>{afterIntro();ui.P.rocks=1;ui.P.shakes=60;ui.state.dayTime=clock;ui.state.recognition[venue.id]={sit:20,bother:20,buy:20,sell:20,full_high:20};const z=worlds.ZONES.find(z=>z.id===venue.zoneId);if(z){ui.P.x=z.x+z.w/2-ui.P.w/2;ui.P.y=z.y+z.h/2-ui.P.h/2;}ui.state.discoveredVenues=discovery.freshDiscovered();ui.state.discoveredVenues.add(venue.id);});
  for(const venue of recognition.REGULAR_VENUES)add('discovered_'+venue.id,()=>{afterIntro();ui.state.discoveredVenues=discovery.freshDiscovered();ui.state.discoveredVenues.add(venue.id);});
  for(const venue of recognition.REGULAR_VENUES)for(const status of ['open','closed'])add('condition_'+venue.id+'_'+status,()=>{
    afterIntro();ui.P.rocks=1;ui.P.shakes=60;ui.state.recognition[venue.id].sit=15;const z=worlds.ZONES.find(z=>z.id===venue.zoneId);ui.P.x=z.x+z.w/2-ui.P.w/2;ui.P.y=z.y+z.h/2-ui.P.h/2;
    ui.state.dayTime=status==='open'?.1:.5;ui.state.concessionClocks.choir={phase:status==='open'?'open':'closed',t:40000};ui.state.concessionClocks.dryer={phase:'running',t:status==='open'?35000:69000};
    ui.state.freedDogFollowT=1000;ui.runtime.npcs.push({id:'freed_dog_follower',x:800,y:1600,w:24,h:24,dead:status!=='open'});
  });
  add('smoke_block_tie',()=>{afterIntro();ui.P.rocks=1;ui.P.shakes=90;ui.state.dayTime=.1;ui.state.recognition.park.sit=15;const smoke=game.module('src/systems/concessions.js');const park=smoke.SMOKE_SPOTS.find(x=>x.id==='park'),block=smoke.SMOKE_SPOTS.find(x=>x.id==='block');assert.ok(park&&block);ui.P.x=(park.x+block.x)/2-ui.P.w/2;ui.P.y=(park.y+block.y)/2-ui.P.h/2;});
  for(const cursor of [0,1,2,3])add('route_'+cursor,()=>{afterIntro();ui.state.blockRoute={serial:4,cursor,stops:progression.ROUTE_STOPS.slice(0,3).map(r=>r.id),lastStopId:''};});
  add('office_leasing',()=>{afterIntro();ui.state.quests.office_space.done=false;ui.state.quests.office_space.available=true;});
  for(const desk of [false,true])add('office_paper_'+desk,()=>{afterIntro();ui.state.office.owned=true;ui.state.office.upgrades.desk=desk;ui.state.quests.paper_empire.done=false;ui.state.quests.paper_empire.available=true;});
  for(const stage of ['survey','file','install'])add('claim_over_kingdom_'+stage,()=>{afterIntro();ui.state.office.owned=true;ui.state.office.claimJob={id:'canal',stage};ui.state.kingdom.stage='summons';ui.P.rocks=1;ui.P.shakes=90;});
  for(const stage of ['inspect','file'])add('work_over_kingdom_'+stage,()=>{afterIntro();ui.state.office.owned=true;ui.state.office.workJob={id:'canal',stage,serial:7};ui.state.kingdom.stage='summons';});
  for(const stage of campaigns.KINGDOM_STAGES)for(const marks of [0,3,7])add('kingdom_'+stage+'_'+marks,()=>{afterIntro();ui.state.office.owned=true;ui.state.kingdom.stage=stage;ui.state.kingdom.marks=marks;ui.P.rocks=1;ui.P.shakes=90;});
  add('kingdom_live_boss',()=>{afterIntro();ui.state.kingdom.stage='tarp_boss';ui.runtime.npcs.push({id:'darryl_under_blue',x:400,y:500,w:40,h:40,hp:1});});
  add('kingdom_dead_boss',()=>{afterIntro();ui.state.kingdom.stage='tarp_boss';ui.runtime.npcs.push({id:'darryl_under_blue',x:400,y:500,w:40,h:40,hp:0,dead:true});});
  add('kingdom_marked_live_boss',()=>{afterIntro();ui.state.kingdom.stage='tarp_boss';ui.runtime.npcs.push({id:'darryl_under_blue',kingdomBoss:true,x:400,y:500,w:40,h:40,hp:1});});
  add('kingdom_marked_dead_boss',()=>{afterIntro();ui.state.kingdom.stage='tarp_boss';ui.runtime.npcs.push({id:'darryl_under_blue',kingdomBoss:true,x:400,y:500,w:40,h:40,hp:0,dead:true});});
  add('kingdom_pretender',()=>{afterIntro();ui.state.kingdom.stage='complete';ui.runtime.npcs.push({id:'pretender_test',kingdomPretender:true,x:400,y:500,w:30,h:30});});
  add('kingdom_locked_requirements',()=>{afterIntro();ui.state.office.owned=true;for(const row of campaigns.CLAIM_SITES.slice(0,4))ui.state.districtClaims[row.id]=true;ui.state.quests.fallen_king.done=false;});
  add('all_quests_active',()=>{ui.state.flags.introDone=true;for(const q of Object.values(ui.state.quests)){q.done=false;q.available=true;}});
  add('all_quests_latent',()=>{ui.state.flags.introDone=true;for(const q of Object.values(ui.state.quests)){q.done=false;q.available=false;}});
  add('all_quests_done',afterIntro);
  for(const rep of [-50,-10,-9,0,9,10,24,25,50])add('factions_'+rep,()=>{afterIntro();ui.P.faction={street:rep,scrap:rep,spiritual:rep};});
  for(const job of progression.HUSTLE_TEMPLATES)for(const done of [false,true])add('hustle_'+job.id+'_'+done,()=>{afterIntro();ui.state.hustles=[{...copy(job),done}];for(const key of Object.keys(ui.state.counters))ui.state.counters[key]=9;for(const key of Object.keys(ui.P.lifetime))ui.P.lifetime[key]=9;});
  for(const count of [0,1,4,8,11])add('office_claims_'+count,()=>{afterIntro();ui.state.office.owned=true;for(const row of campaigns.CLAIM_SITES.slice(0,count))ui.state.districtClaims[row.id]=true;for(const row of campaigns.OFFICE_UPGRADE_DEFS)ui.state.office.upgrades[row.id]=true;ui.state.office.workDay=ui.state.day;ui.state.office.workToday=2;ui.state.office.jobsCompleted=17;});
  add('office_stale_workday',()=>{afterIntro();ui.state.office.owned=true;ui.state.office.workDay=-1;ui.state.office.workToday=3;});
  add('all_people',()=>{afterIntro();for(const id of catalogs.VENDOR_FLOATER_IDS)ui.state.metVendors.add(id);});
  add('people_missing_dead_unknown',()=>{afterIntro();ui.state.metVendors.add('tony');ui.state.metVendors.add('priest');ui.state.metVendors.add('unknown');ui.runtime.npcs=ui.runtime.npcs.filter(n=>n.id!=='priest');ui.runtime.npcs.find(n=>n.id==='tony').dead=true;});
  add('map_authorities',()=>{afterIntro();ui.state.flags.theLotEntered=true;for(const flag of ['blueTarpCleared','cartKeepCleared','copperChoirCleared','throneDitchCleared'])ui.state.flags[flag]=true;ui.runtime.npcs.push({id:'qa_cop',isCop:true,x:200,y:500});ui.runtime.npcs.push({id:'qa_aggro',aggro:true,x:201,y:502});});
  const directions=[];for(const dx of [-24,-23.999,0,23.999,24])for(const dy of [-24,-23.999,0,23.999,24])directions.push({dx,dy,expected:campaigns.objectiveDirection(dx,dy)});
  for(let n=-8;n<=8;n++){const angle=(n+.5)*Math.PI/4;const dx=Math.cos(angle)*100,dy=Math.sin(angle)*100;directions.push({dx,dy,expected:campaigns.objectiveDirection(dx,dy)});}
  for(let n=-4;n<4;n++)for(const offset of [-1e-9,1e-9]){const angle=(n+.5)*Math.PI/4+offset,dx=Math.cos(angle)*100,dy=Math.sin(angle)*100;directions.push({dx,dy,expected:campaigns.objectiveDirection(dx,dy)});}
  for(const row of directions){const octant=Math.atan2(row.dy,row.dx)/(Math.PI/4),half=Math.floor(octant*2+.5)*.5;row.sourceOctant=octant;row.ambiguous=Math.abs(octant-half)<=1e-12&&Math.abs(half%1)===.5;row.stableExpected=row.expected;if(row.ambiguous){const n=Math.floor(half+.5);row.stableExpected=['→','↘','↓','↙','←','↖','↑','↗'][(n+8)%8];}}
  const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
  const baseline=cases[0].before,mapStatic=cases[0].mapStatic,mapDynamic=cases[0].mapDynamic;
  for(const row of cases){assert.deepEqual(row.mapStatic,mapStatic);row.before=difference(baseline,row.before)||{};delete row.mapStatic;row.mapChanges=row.mapDynamic.flatMap((entry,index)=>JSON.stringify(mapDynamic[index])===JSON.stringify(entry)?[]:[{index,value:entry}]);row.mapLength=row.mapDynamic.length;delete row.mapDynamic;}
  return {schema:1,format:'rock-bottom-guidance-reference',source:{authority:'unchanged currentPrimaryObjective, objectiveDirection, renderQuests (harness-only npcs alias after separate original-defect characterization), drawMinimap',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},originalDefect,counts:{cases:cases.length,directions:directions.length,quests:Object.keys(ui.state.quests).length,hustles:progression.HUSTLE_TEMPLATES.length,staticCount},baseline,mapStatic,mapDynamic,cases,directions};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildGuidanceOracle();const output=stableStringify(result);
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Guidance oracle drift.');else fs.writeFileSync(OUTPUT,output);
  console.log(`3D GUIDANCE ORACLE: PASS (${result.counts.cases} views / ${result.counts.directions} direction cases; unchanged source; original journal ReferenceError separately recorded)`);
}
