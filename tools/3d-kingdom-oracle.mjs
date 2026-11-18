import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,FIXED_EPOCH_MS,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';

const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/kingdom_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const PKEYS=['x','y','w','h','cash','copper','cred','hp','maxHp','stunT','shakes','wanted','rocks','iframes'];
const LIFE=['routesCompleted','officeJobs','territoriesClaimed','pretendersDefeated','arrests'];
const kingdomActor=n=>!!(n.kingdomGuard||n.kingdomAdd||n.kingdomBoss||n.kingdomPretender);
const permutations=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]];
const open=()=>({kind:'open_ledger'});
const select=action=>({kind:'select',action});
const change=values=>({kind:'change',values});
const target=(id,offset=0,context={})=>({kind:'target',id,offset,context});
const start=clan=>({kind:'start',clan});
const damage=id=>({kind:'damage',id});
const tick=(ms,where='inside')=>({kind:'tick',ms,where});
const menuLabels={accept:/^(answer the frequency|install the radio first)/,leave:/^leave it under the stapler/,
 clause:/^read the succession clause/,work:/^(work orders|work order \d+ is|take a work order)/,back:/^back to the office/};

/** Every expected value below is read after executing unchanged source functions. */
export async function buildKingdomOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js');
 const boot=game.module('src/core/start.js'),campaign=game.module('src/systems/campaigns.js');
 const combat=game.module('src/systems/combat.js'),comms=game.module('src/systems/communications.js');
 const world=game.module('src/data/world.js'),recognition=game.module('src/systems/recognition.js');
 let writes=0,draws=0,roll=.4,ending=null,endingElapsed=0;
 const remembered=new Map();
 game.context.storage={async set(){writes++;},async get(){return null;}};
 const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,
  options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
 const projectile=p=>({...copy({...p,from:undefined}),from:p.from?.id||null});
 const endingPresentation=()=>{
  if(!ui.state.endingContinue)return null;
  const html=game.context.document.getElementById('title').innerHTML;
  return {title:html.match(/<h1[^>]*>([^<]*)<\/h1>/)?.[1]||'',subtitle:html.match(/<div class="sub">([^<]*)<\/div>/)?.[1]||'',continueText:html.match(/<div class="start">([^<]*)<\/div>/)?.[1]||''};
 };
 const snapshot=()=>({
  player:Object.fromEntries(PKEYS.map(k=>[k,ui.P[k]??0])),
  lifetime:Object.fromEntries(LIFE.map(k=>[k,ui.P.lifetime[k]||0])),
  office:copy(ui.state.office),claims:copy(ui.state.districtClaims),kingdom:copy(ui.state.kingdom),
  quests:copy(ui.state.quests),flags:copy(ui.state.flags),achievements:[...ui.state.achievements].sort(),
  actors:ui.runtime.npcs.filter(kingdomActor).map(copy),projectiles:ui.runtime.projectiles.map(projectile),
  bossActive:!!ui.state.bossActive,bossKind:ui.state.bossKind||'',bossPhase:ui.state.bossPhase||0,
  brutusOlderActive:!!ui.state.brutusOlderActive,
  bossNPC:ui.state.bossNPC?.id||'',kingdomBattle:copy(ui.state.kingdomBattle||null),
  day:ui.state.day,mode:ui.state.mode,endingContinue:!!ui.state.endingContinue,endingPresentation:endingPresentation(),
  menu:menu(),objective:copy(campaign.currentKingdomObjective()),hint:campaign.resolveKingdomActionHint(),
  recognition:copy(ui.state.recognition),recognitionVisit:copy(ui.state.recognitionVisit),
  communications:{posts:copy(comms.phoneState.posts),news_text:game.context.document.getElementById('tape').textContent,news_index:comms.newsState.idx},
  writes,draws,toast:ui.toastEl.textContent||'',
 });
 const remember=()=>{for(const actor of ui.runtime.npcs)if(kingdomActor(actor))remembered.set(actor.id,actor);};
 const apply=values=>{
  Object.assign(ui.P,copy(values.player||{}));Object.assign(ui.P.lifetime,copy(values.lifetime||{}));
  Object.assign(ui.state,copy(values.state||{}));Object.assign(ui.state.flags,copy(values.flags||{}));
  if(values.office){Object.assign(ui.state.office,copy(values.office));if(values.office.upgrades)ui.state.office.upgrades={...Object.fromEntries(campaign.OFFICE_UPGRADE_DEFS.map(d=>[d.id,false])),...copy(values.office.upgrades)};}
  if(values.claims)ui.state.districtClaims=copy(values.claims);
  if(values.kingdom)Object.assign(ui.state.kingdom,copy(values.kingdom));
  for(const [id,fields]of Object.entries(values.quests||{}))Object.assign(ui.state.quests[id],copy(fields));
  if(values.recognition)ui.state.recognition=copy(values.recognition);
  if(values.actors)for(const [id,fields]of Object.entries(values.actors)){const actor=ui.runtime.npcs.find(n=>n.id===id);assert.ok(actor,'Unknown changed actor '+id);Object.assign(actor,copy(fields));}
  if(values.projectiles)ui.runtime.projectiles=values.projectiles.map(p=>({...copy(p),from:ui.runtime.npcs.find(n=>n.id===p.from)||{id:p.from}}));
 };
 const at=(point,offset=0)=>{ui.P.x=point.x+(point.w||0)/2-ui.P.w/2+offset;ui.P.y=point.y+(point.h||0)/2-ui.P.h/2;};
 const pointFor=id=>{
  const parts=id.split(':');
  if(parts[0]==='kingdom')return campaign.KINGDOM_DOORS.find(d=>d.id===parts[1]);
  if(parts[0]==='kingdom_mark')return campaign.KINGDOM_CLANS[parts[1]]?.marks[Number(parts[2])];
  if(parts[0]==='kingdom_banner')return parts[1]==='throne'?campaign.KINGDOM_EMPEROR.banner:campaign.KINGDOM_CLANS[parts[1]]?.banner;
  throw Error('Unknown registered Kingdom target '+id);
 };
 const reset=spec=>{
  ui.init_runtime_ui();boot.startGame(false);comms.init_communications();comms.rotateNews();ui.closeDialogue();
  ui.P.cash=100;ui.P.copper=10;ui.P.cred=20;ui.P.lifetime.routesCompleted=3;
  ui.state.day=6;ui.state.flags.introDone=true;
  ui.state.office={...campaign.freshOfficeState(),owned:true,upgrades:Object.fromEntries(campaign.OFFICE_UPGRADE_DEFS.map(d=>[d.id,true])),workDay:6};
  ui.state.districtClaims=Object.fromEntries(campaign.CLAIM_SITES.slice(0,4).map(d=>[d.id,true]));
  ui.state.quests.fallen_king.done=true;
  ui.state.kingdom={...campaign.freshKingdomState(),stage:'summons'};
  apply(spec.setup||{});campaign.syncKingdomQuests();campaign.syncKingdomForces();
  ui.runtime.projectiles=[];at(campaign.OFFICE_DOOR);
  remembered.clear();remember();ending=null;endingElapsed=0;
  ui.toastEl.textContent='';writes=0;draws=0;roll=spec.roll??.4;
  game.context.Math.random=()=>{draws++;return roll;};game.context.__qa.timers.length=0;
  game.context.document.hidden=false;
 };
 const run=op=>{
  if(op.kind==='open_ledger'){ui.closeDialogue();at(campaign.OFFICE_DOOR);campaign.openKingdomLedger();return {ok:true};}
  if(op.kind==='select'){
   assert.ok(ui.activeDialogue,'Select requires a real source menu');
   const index=ui.activeDialogue.opts.findIndex(o=>menuLabels[op.action]?.test(o.label));
   assert.ok(index>=0,'Missing source action '+op.action+' in '+JSON.stringify(menu()));op.index=index;
   const choice=ui.activeDialogue.opts[index],enabled=!choice.disabled;
   if(enabled){ui.closeDialogue();choice.action();}return {ok:enabled,index};
  }
  if(op.kind==='target'){
   const point=pointFor(op.id);assert.ok(point,'Missing source point '+op.id);ui.closeDialogue();at(point,op.offset);
   const context=op.context||{},previous={mode:ui.state.mode,stunT:ui.P.stunT,bossActive:ui.state.bossActive,brutusOlderActive:ui.state.brutusOlderActive};
   game.context.document.hidden=!!context.hidden;if(context.mode)ui.state.mode=context.mode;
   if(context.stun)ui.P.stunT=1;if(context.boss)ui.state.bossActive=true;if(context.older)ui.state.brutusOlderActive=true;
   const ok=campaign.tryUseKingdomTarget();
   // Temporary guard inputs are restored, except globals changed by an accepted banner.
   ui.state.mode=previous.mode;ui.P.stunT=previous.stunT;
   if(context.boss)ui.state.bossActive=previous.bossActive;
   if(context.older)ui.state.brutusOlderActive=previous.brutusOlderActive;
   game.context.document.hidden=false;remember();return {ok};
  }
  if(op.kind==='door'){ui.closeDialogue();at(pointFor(op.id),op.offset||0);return {ok:campaign.tryKingdomDoor()};}
  if(op.kind==='start'){ui.closeDialogue();const ok=campaign.startKingdomBoss(op.clan);remember();return {ok};}
  if(op.kind==='damage'||op.kind==='complete'){
   const actor=ui.runtime.npcs.find(n=>n.id===op.id)||remembered.get(op.id);assert.ok(actor,'Unknown death/callback actor '+op.id);
   const firstTimer=game.context.__qa.timers.length;let ok;
   if(op.kind==='damage'){actor.hp=0;combat.onNpcDeath(actor);ok=true;}
   else ok=actor.kingdomPretender?campaign.completeKingdomPretender(actor):campaign.completeKingdomBoss(actor);
   const candidate=game.context.__qa.timers.slice(firstTimer).find(t=>t[0]==='timeout'&&t[2]===2600);
   if(candidate){assert.equal(actor.id,'curb_emperor','Only final boss schedules ending');ending=candidate[1];endingElapsed=0;}
   remember();return {ok};
  }
  if(op.kind==='tick'){
   assert.ok(Number.isFinite(op.ms)&&op.ms>0);const battle=ui.state.kingdomBattle;
   assert.ok(battle,'Battle clock operation requires active source battle');const zone=world.ZONES.find(z=>z.id===battle.zoneId);assert.ok(zone);
   at(op.where==='outside'?{x:zone.x-1,y:zone.y+zone.h/2}:op.where==='edge'?{x:zone.x,y:zone.y+zone.h}:{x:zone.x+zone.w/2,y:zone.y+zone.h/2});
   let remaining=op.ms;while(remaining>0){const dt=Math.min(50,remaining);campaign.updateKingdomBattle(dt);remaining-=dt;}
   remember();return {ok:true};
  }
  if(op.kind==='set_boss_health'){assert.ok(ui.state.bossNPC);ui.state.bossNPC.hp=ui.state.bossNPC.maxHp*op.ratio;return {ok:true};}
  if(op.kind==='change'){apply(op.values);return {ok:true};}
  if(op.kind==='abort'){const ok=campaign.abortKingdomFight(!!op.show);if(ok&&op.refresh)campaign.syncKingdomForces();remember();return {ok};}
  if(op.kind==='refresh'){campaign.syncKingdomForces();remember();return {ok:true};}
  if(op.kind==='sync_recognition'){recognition.syncRecognitionVisit();return {ok:true};}
  if(op.kind==='death'){combat.die();return {ok:true};}
  if(op.kind==='arrest'){combat.arrestScene();return {ok:true};}
  if(op.kind==='ending'){
   assert.ok(Number.isFinite(op.elapsed_ms)&&op.elapsed_ms>=0);endingElapsed+=op.elapsed_ms;
   if(!ending||endingElapsed<2600)return {ok:false};const callback=ending;ending=null;callback();return {ok:true};
  }
  throw Error('Unknown Kingdom operation '+op.kind);
 };
 const specs=[];
 for(const radio of [false,true])specs.push({id:'summons_radio_'+radio,setup:{office:{upgrades:{radio}}},ops:[open(),select('accept'),...(radio?[open(),select('clause')]:[select('leave')])]});
 specs.push({id:'summons_silenced_communications',setup:{flags:{silenceUntilT:FIXED_EPOCH_MS+5000}},ops:[open(),select('accept')]});
 for(const stage of campaign.KINGDOM_STAGES)specs.push({id:'ledger_'+stage,setup:{kingdom:{stage}},ops:[open(),select(stage==='summons'?'leave':'clause'),open(),select(stage==='summons'?'leave':'back')]});
 for(const condition of ['available','no_radio','no_claim','claim_active','work_active','cap']){
  const setup={kingdom:{stage:'tarp_marks'}};
  if(condition==='no_radio')setup.office={upgrades:{}};
  if(condition==='no_claim')setup.claims={};
  if(condition==='claim_active')setup.office={claimJob:{id:'park',stage:'survey'}};
  if(condition==='work_active')setup.office={workJob:{id:'canal',stage:'inspect',serial:3}};
  if(condition==='cap')setup.office={workToday:2};
  specs.push({id:'ledger_work_'+condition,setup,ops:[open(),select('work')]});
 }
 for(const clan of campaign.KINGDOM_CLAN_LIST){
  const setup={kingdom:{stage:clan.marksStage,marks:0}};
  for(const order of permutations)specs.push({id:'marks_'+clan.id+'_'+order.join(''),setup,ops:[...order.map(i=>target('kingdom_mark:'+clan.id+':'+i)),target('kingdom_mark:'+clan.id+':'+order[0])]});
  for(let i=0;i<3;i++)for(const offset of [57.99,58])specs.push({id:'mark_boundary_'+clan.id+'_'+i+'_'+offset,setup,ops:[target('kingdom_mark:'+clan.id+':'+i,offset)]});
  for(const context of [{hidden:true},{stun:true},{boss:true},{older:true},{mode:'dialogue'}])specs.push({id:'mark_guard_'+clan.id+'_'+Object.keys(context)[0],setup,ops:[target('kingdom_mark:'+clan.id+':0',0,context)]});
  specs.push({id:'banner_missing_marks_'+clan.id,setup,ops:[target('kingdom_banner:'+clan.id)]});
 }
 for(const door of campaign.KINGDOM_DOORS)for(const offset of [43.99,44])specs.push({id:'door_'+door.id+'_'+offset,ops:[{kind:'door',id:'kingdom:'+door.id,offset}]});
 specs.push({id:'wire_recognition_repeat_and_reentry',ops:[{kind:'door',id:'kingdom:wire'},{kind:'door',id:'kingdom:wire'},{kind:'door',id:'kingdom:blue'},{kind:'sync_recognition'},{kind:'door',id:'kingdom:wire'}]});
 const definitions=[...campaign.KINGDOM_CLAN_LIST,campaign.KINGDOM_EMPEROR];
 for(const def of definitions){
  const clan=def===campaign.KINGDOM_EMPEROR?'emperor':def.id,stage=clan==='emperor'?'emperor_gate':def.marksStage;
  const setup={kingdom:{stage,marks:clan==='emperor'?0:7}};
  const banner='kingdom_banner:'+(clan==='emperor'?'throne':clan),bossId=def.bossId;
  for(const offset of [71.99,72])specs.push({id:'banner_boundary_'+clan+'_'+offset,setup,ops:[target(banner,offset)]});
  for(const context of [{hidden:true},{stun:true},{boss:true},{older:true},{mode:'dialogue'}])specs.push({id:'banner_guard_'+clan+'_'+Object.keys(context)[0],setup,ops:[target(banner,0,context)]});
  const projectiles=[{id:'boss_shot',x:1,y:2,vx:3,vy:4,damage:5,from:bossId},{id:'add_shot',x:1,y:2,from:'kingdom_add_'+bossId+'_0'},{id:'unrelated_shot',x:1,y:2,from:'tony'}];
  specs.push({id:'boss_win_'+clan,setup,ops:[start(clan),change({projectiles}),damage('kingdom_add_'+bossId+'_0'),damage(bossId),{kind:'complete',id:bossId},...(clan==='emperor'?[{kind:'ending',elapsed_ms:2599},{kind:'ending',elapsed_ms:1},{kind:'ending',elapsed_ms:2600}]:[])]});
  specs.push({id:'boss_wrong_stage_'+clan,setup,ops:[start(clan),change({kingdom:{stage:'summons'}}),{kind:'complete',id:bossId}]});
  specs.push({id:'boss_escape_'+clan,setup,ops:[start(clan),change({projectiles}),tick(5000,'outside'),tick(1,'edge'),tick(5000,'outside'),tick(1,'outside')]});
  for(const kind of ['abort','death','arrest'])specs.push({id:'boss_'+kind+'_'+clan,setup,ops:[start(clan),change({projectiles}),kind==='abort'?{kind,show:false,refresh:false}:{kind}]});
  for(const blocker of ['stage','boss','older']){
   const blocked=copy(setup);
   if(blocker==='stage')blocked.kingdom.stage='summons';
   if(blocker==='boss')blocked.state={bossActive:true,bossKind:'tony'};
   if(blocker==='older')blocked.state={brutusOlderActive:true};
   specs.push({id:'start_refused_'+clan+'_'+blocker,setup:blocked,ops:[start(clan)]});
  }
 }
 specs.push({id:'emperor_phase_exact_thresholds',setup:{kingdom:{stage:'emperor_gate'}},ops:[start('emperor'),{kind:'set_boss_health',ratio:.66},tick(1),{kind:'set_boss_health',ratio:.6599},tick(1),{kind:'set_boss_health',ratio:.33},tick(1),{kind:'set_boss_health',ratio:.3299},tick(1)]});
 specs.push({id:'emperor_phase_else_if',setup:{kingdom:{stage:'emperor_gate'}},ops:[start('emperor'),{kind:'set_boss_health',ratio:.1},tick(1),tick(1)]});
 specs.push({id:'dead_boss_timer_stops',setup:{kingdom:{stage:'tarp_marks',marks:7}},ops:[start('blue_tarp'),change({actors:{darryl_under_blue:{dead:true}}}),tick(5050,'outside')]});
 specs.push({id:'missing_boss_timer_stops',setup:{kingdom:{stage:'tarp_marks',marks:7}},ops:[start('blue_tarp'),change({state:{bossNPC:null}}),tick(5050,'outside')]});
 for(const [clan,id,stage]of [['blue_tarp','darryl_under_blue','tarp_marks'],['emperor','curb_emperor','emperor_gate']])
  specs.push({id:'objective_requires_live_kingdom_boss_'+clan,setup:{kingdom:{stage,marks:7}},ops:[start(clan),change({actors:{[id]:{x:400,y:500,kingdomBoss:false}}}),change({actors:{[id]:{kingdomBoss:true}}}),change({actors:{[id]:{dead:true}}})]});
 for(const day of [6,7,8])specs.push({id:'pretender_profile_'+day,setup:{state:{day},kingdom:{stage:'complete',pretendersDefeated:2},lifetime:{pretendersDefeated:2}},ops:[damage('curb_pretender_'+day),{kind:'complete',id:'curb_pretender_'+day},{kind:'refresh'},change({state:{day:day+1}}),{kind:'refresh'}]});
 specs.push({id:'ordinary_guard_no_reward',ops:[damage('kingdom_guard_blue_tarp_6_0')]});
 specs.push({id:'abort_without_battle',ops:[{kind:'abort',show:true,refresh:true}]});
 const cases=[];
 for(const spec of specs){
  reset(spec);const setup=snapshot(),steps=[];
  for(const raw of spec.ops){
   const operation=copy(raw),beforeKingdom=copy(ui.state.kingdom);ui.toastEl.textContent='';
   const result=run(operation),step={operation,result,expected:snapshot()};
   if(operation.kind==='complete'&&result.ok===false&&stableStringify(beforeKingdom)!==stableStringify(ui.state.kingdom))Object.assign(step,{characterization:'rejected_completion_normalizes',beforeKingdom});
   steps.push(step);
  }
  cases.push({id:spec.id,roll:spec.roll??.4,setup,steps});
 }
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-kingdom-reference',source:{authority:'unchanged live Kingdom ledger callbacks, targets, battles, combat deaths and real 2600ms ending closure',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},
  counts:{cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),clans:3,marks:9,doors:4,bosses:4,addsPerBoss:2,pretenderProfiles:3},cases,
  scope:'P13c unchanged-source action and battle evidence. Source functions own outputs; physical staging, stale capabilities and epoch-bound ending delivery are separate model/integration gates.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildKingdomOracle());
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Kingdom oracle drift; regenerate deliberately.');
 else fs.writeFileSync(OUTPUT,output);
 const result=JSON.parse(output);console.log(`3D KINGDOM ORACLE: PASS (${result.counts.cases} source paths; ${result.counts.steps} source steps; 9 marks,4 doors,4 bosses,3 pretender profiles)`);
}
