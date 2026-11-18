import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/office_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const PKEYS=['x','y','w','h','cash','copper','cred','hp','maxHp','brain','shakes','wanted','stunT','inventory','faction'];
const LIFE=['routesCompleted','officeJobs','territoriesClaimed','pretendersDefeated'];
const open=(target='office')=>({kind:'open',target});
const choose=action=>({kind:'select',action});
const field=(offset=0,context={})=>({kind:'field',offset,context});
const change=values=>({kind:'change',values});
const labels={
 purchase:/^(replace the lock|need \$40|file three block)/,includes:/^ask what the unit/,lease:/^ask about the lease/,
 look:/^look toward/,inventory:/^count (inventory|the canal)/,water:/^ask where the water/,leave:/^leave/,
 claims:/^(open the active claim|open district claims|district claims need)/,upgrades:/^look at office upgrades/,
 work:/^(work orders|work order \d+ is|take a work)/,file_work:/^(file work order|daily ledger closed)/,
 file_claim:/^(file (?!work order)|filing needs|need \$\d+ \+ 1 copper)/,
 cancel_claim:/^cancel the claim/,reroll:/^(route board|replace the current block)/,
 cot:/^(use the cot|cot not installed)/,locker:/^(open the chained locker|locker not installed)/,
 back:/^(back\.|back to the office)/,'page:1':/^next ledger/,'page:0':/^previous ledger/,
 rest:/^rest 30 minutes/,'deposit:cash':/^deposit \$10/,'withdraw:cash':/^withdraw \$10/,
};
export async function buildOfficeOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
 const campaign=game.module('src/systems/campaigns.js'),homes=game.module('src/systems/daily_hideouts.js');
 const comms=game.module('src/systems/communications.js');
 let writes=0,draws=0,roll=.4;
 game.context.storage={async set(){writes++;},async get(){return null;}};
 const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
 const snapshot=()=>({player:Object.fromEntries(PKEYS.map(k=>[k,copy(ui.P[k])])),
  lifetime:Object.fromEntries(LIFE.map(k=>[k,ui.P.lifetime[k]||0])),office:copy(ui.state.office),claims:copy(ui.state.districtClaims),
  kingdom:copy(ui.state.kingdom),quests:copy(ui.state.quests),achievements:[...ui.state.achievements].sort(),
  gutterInventoryDay:ui.state.counters.gutterInventoryDay||0,blockRoute:copy(ui.state.blockRoute),stash:copy(ui.state.hideoutStash),
  day:ui.state.day,dayTime:ui.state.dayTime,mode:ui.state.mode,bossActive:ui.state.bossActive,bossKind:ui.state.bossKind,
  brutusOlderActive:!!ui.state.brutusOlderActive,introDone:!!ui.state.flags.introDone,
  objective:copy(campaign.currentOfficeObjective()),draws,writes,toast:ui.toastEl.textContent||''});
 const apply=values=>{
  Object.assign(ui.P,copy(values.player||{}));Object.assign(ui.P.lifetime,copy(values.lifetime||{}));
  Object.assign(ui.state,copy(values.state||{}));Object.assign(ui.state.flags,copy(values.flags||{}));
  Object.assign(ui.state.counters,copy(values.counters||{}));
  if(values.office){Object.assign(ui.state.office,copy(values.office));if(values.office.upgrades)ui.state.office.upgrades={...Object.fromEntries(campaign.OFFICE_UPGRADE_DEFS.map(d=>[d.id,false])),...copy(values.office.upgrades)};}
  if(values.claims)ui.state.districtClaims=copy(values.claims);
  if(values.quests)for(const [id,v]of Object.entries(values.quests))Object.assign(ui.state.quests[id],copy(v));
 };
 const at=(point,offset=0)=>{ui.P.x=point.x+(point.w||0)/2-ui.P.w/2+offset;ui.P.y=point.y+(point.h||0)/2-ui.P.h/2;};
 const reset=spec=>{
  ui.init_runtime_ui();start.startGame(false);comms.init_communications();ui.closeDialogue();
  ui.P.cash=1000;ui.P.copper=100;ui.P.lifetime.routesCompleted=3;ui.P.faction={street:10,scrap:10,spiritual:10};
  ui.state.day=4;ui.state.flags.introDone=true;
  ui.state.office={...campaign.freshOfficeState(),owned:true,upgrades:Object.fromEntries(campaign.OFFICE_UPGRADE_DEFS.map(d=>[d.id,true])),workDay:4};
  apply(spec.setup||{});ui.toastEl.textContent='';writes=0;draws=0;roll=spec.roll??.4;
  game.context.Math.random=()=>{draws++;return roll;};game.context.__qa.timers.length=0;
 };
 const run=op=>{
  if(op.kind==='open'){
   ui.closeDialogue();at(op.target==='office'?campaign.OFFICE_DOOR:ui.runtime.npcs.find(n=>n.id===op.target),op.offset||0);
   if(op.target==='office')return {ok:homes.tryEnterOffice()};
   if(op.target==='lease_guy')campaign.leaseGuyDialogue();else campaign.gutterGregDialogue();return {ok:true};
  }
  if(op.kind==='select'){
   assert.ok(ui.activeDialogue,'Selection requires a real source menu');
   let match=labels[op.action];
   if(op.action.startsWith('claim:')){const d=campaign.CLAIM_SITE_BY_ID[op.action.slice(6)];match={test:label=>label.startsWith(d.name+' ·')||label.startsWith('✓ '+d.name+' ·')};}
   if(op.action.startsWith('upgrade:')){const d=campaign.OFFICE_UPGRADE_DEFS.find(d=>d.id===op.action.slice(8));match={test:label=>label.startsWith(d.name+' ·')||label.startsWith('✓ '+d.name+' installed.')};}
   const index=ui.activeDialogue.opts.findIndex(o=>match?.test(o.label));assert.ok(index>=0,'Missing source action '+op.action+' in '+JSON.stringify(menu()));
   const choice=ui.activeDialogue.opts[index],enabled=!choice.disabled;
   if(enabled){ui.closeDialogue();choice.action();}return {ok:enabled,index};
  }
  if(op.kind==='field'){
   ui.closeDialogue();const o=ui.state.office,job=o.claimJob||o.workJob;assert.ok(job,'Source field requires a contract');
   const site=campaign.CLAIM_SITE_BY_ID[job.id],point=job.stage==='survey'?site.survey:site.sign;at(point,op.offset||0);
   game.context.document.hidden=!!op.context.hidden;
   const previous={mode:ui.state.mode,stunT:ui.P.stunT,bossActive:ui.state.bossActive,brutusOlderActive:ui.state.brutusOlderActive};
   if(op.context.mode)ui.state.mode=op.context.mode;if(op.context.stun)ui.P.stunT=1;if(op.context.boss)ui.state.bossActive=true;if(op.context.older)ui.state.brutusOlderActive=true;
   const ok=campaign.tryUseOfficeFieldTarget();
   Object.assign(ui.state,{mode:previous.mode,bossActive:previous.bossActive,brutusOlderActive:previous.brutusOlderActive});ui.P.stunT=previous.stunT;game.context.document.hidden=false;
   return {ok};
  }
  if(op.kind==='change'){apply(op.values);return {ok:true};}
  throw Error('Unknown office operation '+op.kind);
 };
 const specs=[];
 for(const setup of [
  {id:'locked',office:{owned:false,upgrades:{}},lifetime:{routesCompleted:0}},
  {id:'routes2',office:{owned:false,upgrades:{}},lifetime:{routesCompleted:2}},
  {id:'cash39',office:{owned:false,upgrades:{}},player:{cash:39}},
  {id:'copper0',office:{owned:false,upgrades:{}},player:{copper:0}},
  {id:'exact',office:{owned:false,upgrades:{}},player:{cash:40,copper:1}},
  {id:'raw_low_hp_stun',office:{owned:false,upgrades:{}},player:{cash:40,copper:1,hp:-5,stunT:2000}},
 ]) specs.push({id:'purchase_'+setup.id,setup,ops:[open('office'),choose('look'),open('lease_guy'),choose('includes'),open('lease_guy'),choose('purchase'),open('lease_guy'),choose(setup.id==='exact'||setup.id==='raw_low_hp_stun'?'lease':'leave')]});
 for(const d of campaign.OFFICE_UPGRADE_DEFS)for(const condition of ['exact','poor_cash','poor_copper','owned']){
  if(condition==='poor_copper'&&d.copper===0)continue;
  specs.push({id:'upgrade_'+d.id+'_'+condition,setup:{office:{upgrades:condition==='owned'?{[d.id]:true}:{}},player:{cash:d.cash-(condition==='poor_cash'?1:0),copper:d.copper-(condition==='poor_copper'?1:0)}},ops:[open(),choose('upgrades'),choose('upgrade:'+d.id),choose('back')]});
 }
 for(const [i,d]of campaign.CLAIM_SITES.entries()){
  const ops=[open(),choose('claims')];if(i>=7)ops.push(choose('page:1'));ops.push(choose('claim:'+d.id),field(),open(),choose('file_claim'),choose('leave'),field(),open(),choose('claims'));if(i>=7)ops.push(choose('page:1'));ops.push(choose('claim:'+d.id));
  specs.push({id:'claim_full_'+d.id,ops});
  if(d.faction!=='neutral')for(const value of [9,10]){const denied=[open(),choose('claims')];if(i>=7)denied.push(choose('page:1'));denied.push(choose('claim:'+d.id));specs.push({id:'claim_faction_'+d.id+'_'+value,setup:{player:{faction:{street:value,scrap:value,spiritual:value}}},ops:denied});}
 }
 for(const stage of ['survey','file','install'])specs.push({id:'cancel_'+stage,setup:{office:{claimJob:{id:'canal',stage}}},ops:[open(),choose('claims'),choose('cancel_claim'),choose('claims')]});
 for(const count of [0,1,4,8,10])for(const deficit of ['none','cash','copper']){
  const claims=Object.fromEntries(campaign.CLAIM_SITES.slice(0,count).map(d=>[d.id,true]));const target=campaign.CLAIM_SITES[count].id,cost=20+5*count;
  specs.push({id:'filing_'+count+'_'+deficit,setup:{claims,office:{claimJob:{id:target,stage:'file'}},player:{cash:cost-(deficit==='cash'?1:0),copper:deficit==='copper'?0:1}},ops:[open(),choose('claims'),choose('file_claim')]});
 }
 for(const count of [1,3,4,7,8,11])for(const value of [0,.999999]){
  const claims=Object.fromEntries(campaign.CLAIM_SITES.slice(0,count).map(d=>[d.id,true]));
  specs.push({id:'work_'+count+'_'+value,roll:value,setup:{claims,office:{lastWorkId:'canal',jobsCompleted:4,orderSerial:4}},ops:[open(),choose('work'),field(),open(),choose('file_work'),choose('work')]});
 }
 for(const count of [1,4,8]){
  const claims=Object.fromEntries(campaign.CLAIM_SITES.slice(0,count).map(d=>[d.id,true]));
  specs.push({id:'work_daily_cap_'+count,setup:{claims,office:{workToday:1+Math.floor(count/4),workJob:{id:'canal',stage:'file',serial:6}}},ops:[open(),choose('file_work'),change({state:{day:5}}),open(),choose('file_work')]});
 }
 for(const stage of ['survey','file','install'])specs.push({id:'work_blocked_by_claim_'+stage,setup:{claims:{alley:true},office:{claimJob:{id:'canal',stage}}},ops:[open(),choose('work'),choose('reroll')]});
 specs.push({id:'ledger_work_busy',setup:{claims:{canal:true},office:{workJob:{id:'canal',stage:'inspect',serial:1}}},ops:[open(),choose('claims'),choose('back')]});
 specs.push({id:'ledger_both_pages',ops:[open(),choose('claims'),choose('page:1'),choose('page:0'),choose('back')]});
 for(const kind of ['survey','install','inspect'])for(const context of [{},{hidden:true},{stun:true},{boss:true},{older:true},{mode:'dialogue'}])for(const offset of (Object.keys(context).length?[0]:[57.99,58])){
  const office=kind==='inspect'?{workJob:{id:'canal',stage:'inspect',serial:1}}:{claimJob:{id:'canal',stage:kind}};
  specs.push({id:'field_'+kind+'_'+Object.keys(context).join('_')+'_'+offset,setup:{office,claims:kind==='inspect'?{canal:true}:{}},ops:[field(offset,context)]});
 }
 for(const rank of [-10,9,24,49,50])specs.push({id:'greg_'+rank,setup:{player:{faction:{street:0,scrap:rank,spiritual:0}}},ops:[open('gutter_greg'),choose('inventory'),open('gutter_greg'),choose('inventory'),choose('water'),change({state:{day:5}}),open('gutter_greg'),choose('inventory')]});
 specs.push({id:'greg_preserves_unowned_office',setup:{office:{owned:false,upgrades:{}}},ops:[open('gutter_greg'),choose('inventory')]});
 for(const offset of [43.99,44])specs.push({id:'office_range_'+offset,ops:[{...open(),offset}]});
 for(const owned of [false,true])specs.push({id:'ordinary_boss_menu_'+owned,setup:{state:{bossActive:true,bossKind:'tony'},office:{owned,upgrades:owned?{cot:true}:{}},player:{hp:-5,stunT:1000}},ops:[open()]});
 const route={stops:['pawn_sill','church_step','market_line'],cursor:1,serial:8,lastStopId:'pawn_sill'};
 for(const setup of [{id:'valid',state:{blockRoute:route}},{id:'invalid',state:{blockRoute:null}},{id:'used',office:{rerollDay:4}},{id:'no_board',office:{upgrades:{}}},{id:'no_intro',flags:{introDone:false}}])specs.push({id:'reroll_'+setup.id,setup,ops:[open(),choose('reroll'),open(),choose('reroll')]});
 specs.push({id:'cot_rest',setup:{player:{hp:50,brain:40,wanted:2}},ops:[open(),choose('cot'),choose('rest')]});
 specs.push({id:'locker_roundtrip',ops:[open(),choose('locker'),choose('deposit:cash'),choose('withdraw:cash')]});
 const cases=[];
 for(const spec of specs){reset(spec);const setup=snapshot(),steps=[];for(const op of spec.ops){ui.toastEl.textContent='';const result=run(op);steps.push({operation:op,result,menu:menu(),expected:snapshot()});}cases.push({id:spec.id,roll:spec.roll??.4,setup,steps});}
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-office-reference',source:{authority:'unchanged live office menus and callbacks',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),claims:11,upgrades:6,fieldAnchors:22,residents:2,ledgerPages:2},cases,scope:'Office action/menu parity; Kingdom ledger and battles remain P13c.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildOfficeOracle());
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Office oracle drift; regenerate deliberately.');else fs.writeFileSync(OUTPUT,output);
 const result=JSON.parse(output);console.log(`3D OFFICE ORACLE: PASS (${result.counts.cases} source paths; ${result.counts.steps} source steps;11 claims,6 upgrades,2 residents)`);
}
