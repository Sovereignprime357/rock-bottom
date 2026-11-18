import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/incidents_reference.json');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const copy=x=>JSON.parse(JSON.stringify(x));
const PKEYS=['x','y','w','h','hp','cash','copper','cred','brain','shakes','wanted','rocks','faction'];
const SKEYS=['day','dayTime','weather','mode','bossActive','brutusOlderActive','incident','incidentT','incidentPaperT','incidentWetT','shake'];
const FKEYS=['incidentDay','incidentMask','incidentsToday','lastIncidentId','silenceUntilT'];
const tick=(ms,intro=false,silence=false)=>({kind:'tick',ms,intro,silence});
const change=values=>({kind:'change',values});
const start=id=>({kind:'start',id});
export async function buildIncidentsOracle(){
 const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),inc=game.module('src/systems/incidents.js');
 const boot=game.module('src/core/start.js'),save=game.module('src/core/audio_save.js'),comms=game.module('src/systems/communications.js');
 let writes=0,draws=0,rolls=[],sounds=[],saved=null;
 game.context.storage={async set(_key,value){writes++;saved=copy(value);},async get(){return saved?{value:copy(saved)}:null;}};
 const soundOriginal=Object.fromEntries(['traffic','kick','radio','holyWaterHit'].map(id=>[id,save.audio[id]]));
 for(const[id,original]of Object.entries(soundOriginal))save.audio[id]=function(...args){sounds.push(id);return original.apply(this,args);};
 const picked=(object,keys)=>Object.fromEntries(keys.map(key=>[key,copy(object[key]??null)]));
 const actor=n=>({id:n.id,x:n.x,y:n.y,w:n.w,h:n.h,dead:!!n.dead,aggro:!!n.aggro,hostile:!!n.hostile,isDay3Visitor:!!n.isDay3Visitor,hidden:!!n.hidden});
 const snapshot=()=>({player:picked(ui.P,PKEYS),state:picked(ui.state,SKEYS),flags:picked(ui.state.flags,FKEYS),actors:ui.runtime.npcs.map(actor),posts:copy(comms.phoneState.posts),writes,draws,toast:ui.toastEl.textContent||'',sounds:[...sounds]});
 const apply=values=>{
  Object.assign(ui.P,copy(values.player||{}));Object.assign(ui.state,copy(values.state||{}));Object.assign(ui.state.flags,copy(values.flags||{}));
  for(const[id,fields]of Object.entries(values.actors||{})){const body=ui.runtime.npcs.find(n=>n.id===id);assert.ok(body,'Unknown actor '+id);Object.assign(body,copy(fields));}
 };
 const reset=spec=>{
  ui.init_runtime_ui();boot.startGame(false);comms.init_communications();ui.closeDialogue();
  ui.runtime.npcs=ui.runtime.npcs.filter(n=>['possum','barb','yuri','brutus','conductor','lurch'].includes(n.id));
  for(const n of ui.runtime.npcs)n.aggro=false;
  Object.assign(ui.state,{mode:'playing',day:2,dayTime:.5,weather:'clear',bossActive:false,brutusOlderActive:false,incident:null,incidentT:1,incidentPaperT:0,incidentWetT:0,shake:0});
  Object.assign(ui.state.flags,{incidentDay:2,incidentMask:0,incidentsToday:0,lastIncidentId:'',silenceUntilT:0});
  ui.P.x=8000;ui.P.y=5400;ui.P.faction={street:0,scrap:0,spiritual:0};apply(spec.setup||{});
  writes=0;draws=0;sounds=[];rolls=spec.rolls||[];ui.toastEl.textContent='';game.context.__qa.timers.length=0;
  game.context.Math.random=()=>rolls[draws++]??.4;
 };
 const run=op=>{
  if(op.kind==='start'){inc.startIncident(op.id);return;}
  if(op.kind==='finish'){inc.finishIncident(op.interrupted);return;}
  if(op.kind==='change'){apply(op.values);return;}
  if(op.kind==='ensure_flags'){inc.ensureIncidentFlags();return;}
  if(op.kind==='tick'){for(let remaining=op.ms;remaining>0;){const dt=Math.min(50,remaining);inc.updateIncidents(dt,op.intro,op.silence);remaining-=dt;}return;}
  if(op.kind==='align_actor'){
   ui.P.x=8000;ui.P.y=5400;ui.state.incident.t=op.time;inc.updateActiveIncident(ui.state.incident,0);
   const a=ui.state.incident.actors[0];op.center={x:a.x+(op.dx||0),y:a.y+(op.dy||0)};
   ui.P.x=op.center.x-ui.P.w/2;ui.P.y=op.center.y-ui.P.h/2;return;
  }
  if(op.kind==='update_active'){inc.updateActiveIncident(ui.state.incident,0);return;}
  throw Error('Unknown operation '+op.kind);
 };
 const specs=[];
 for(const id of inc.INCIDENT_IDS){
  const d=inc.INCIDENT_DEFS[id],times=[1,...d.beats.slice(1).flatMap(b=>[b[0]-1,b[0],b[0]+1]),d.duration-1,d.duration];
  let prior=0;const ops=[start(id)];for(const time of times){if(time>prior){ops.push(tick(time-prior));prior=time;}}
  specs.push({id:'complete_'+id,ops});
  for(const why of ['silence','boss','older','aggro_near','visitor','bus']){
   const effect=why==='boss'?{state:{bossActive:true}}:why==='older'?{state:{brutusOlderActive:true}}:why==='aggro_near'?{actors:{lurch:{x:8000,y:5400,aggro:true}}}:why==='visitor'?{actors:{lurch:{isDay3Visitor:true}}}:why==='bus'?{actors:{lurch:{id:'bus_driver'}}}:{};
   specs.push({id:'interrupt_'+id+'_'+why,rolls:[.75],ops:[start(id),tick(100),change(effect),tick(1,false,why==='silence')]});
  }
  specs.push({id:'intro_does_not_interrupt_'+id,ops:[start(id),tick(50,true)]});
 }
 for(const [id,required]of Object.entries(inc.INCIDENT_DEFS).filter(([,d])=>d.required).map(([id,d])=>[id,d.required])){
  for(const field of ['dead','aggro','hostile'])specs.push({id:'required_'+id+'_'+field,ops:[start(id),change({actors:{[required]:{[field]:true}}}),tick(1)]});
  specs.push({id:'hidden_required_allowed_'+id,ops:[start(id),change({actors:{[required]:{hidden:true}}}),tick(1)]});
 }
 const places={market:[1080,1510],laundromat:[1530,1150],scrap:[320,220],park:[2600,1280],trainyard:[800,3000],outside:[8000,5400]};
 for(const[zone,[x,y]]of Object.entries(places))specs.push({id:'schedule_'+zone,setup:{player:{x:x-12,y:y-14}},rolls:[.99],ops:[tick(1),tick(1)]});
 for(const [field,value]of [['weather','rain'],['weather','fog'],['dayTime',.24999],['dayTime',.25],['dayTime',.75],['dayTime',.75001]])specs.push({id:'park_schedule_'+field+'_'+value,setup:{player:{x:2588,y:1266},state:{[field]:value}},ops:[tick(1)]});
 for(const reason of ['intro','silence','boss','older','aggro','visitor','bus']){
  const setup=reason==='boss'?{state:{bossActive:true}}:reason==='older'?{state:{brutusOlderActive:true}}:reason==='aggro'?{actors:{lurch:{x:8000,y:5400,aggro:true}}}:reason==='visitor'?{actors:{lurch:{isDay3Visitor:true}}}:reason==='bus'?{actors:{lurch:{id:'bus_driver'}}}:{};
  specs.push({id:'idle_freeze_'+reason,setup,ops:[tick(50,reason==='intro',reason==='silence')]});
 }
 for(const distance of [319.999,320,320.001])specs.push({id:'aggro_distance_'+distance,setup:{actors:{lurch:{x:8012+distance-14,y:5398,aggro:true,w:28,h:32}}},ops:[tick(1)]});
 specs.push({id:'dead_aggro_ignored',setup:{actors:{lurch:{x:8000,y:5400,aggro:true,dead:true}}},ops:[tick(1)]});
 specs.push({id:'max_three_idle',setup:{flags:{incidentsToday:3}},ops:[tick(50)]});
 specs.push({id:'seen_specific_falls_back_mattress',setup:{player:{x:1068,y:1496},flags:{incidentMask:2}},ops:[tick(1)]});
 specs.push({id:'no_choices_retry30s',setup:{flags:{incidentMask:63}},ops:[tick(1),tick(50)]});
 specs.push({id:'null_countdown_draw_once',setup:{state:{incidentT:null}},rolls:[.75],ops:[tick(1),tick(50)]});
 specs.push({id:'zero_countdown_is_not_default',setup:{state:{incidentT:0}},ops:[tick(1)]});
 specs.push({id:'day_reset_preserves_last',setup:{flags:{incidentDay:1,incidentMask:63,incidentsToday:3,lastIncidentId:'yuri_receipt'}},ops:[tick(1)]});
 specs.push({id:'active_dawn_history_resets_lazily',ops:[start('yuri_receipt'),change({state:{day:3}}),tick(50),{kind:'finish',interrupted:false},change({state:{incidentT:1}}),tick(1)]});
 specs.push({id:'cosmetics_decay_before_idle_guard',setup:{state:{incidentPaperT:25,incidentWetT:100,bossActive:true}},ops:[tick(50)]});
 specs.push({id:'cosmetics_decay_before_interrupt',ops:[start('yuri_receipt'),change({state:{incidentPaperT:25,incidentWetT:100}}),tick(50,false,true)]});
 specs.push({id:'finish_without_active_no_draw',ops:[{kind:'finish',interrupted:false}]});
 for(const roll of [0,.999999])specs.push({id:'cooldown_bounds_'+roll,rolls:[roll,roll],ops:[start('runaway_mattress'),{kind:'finish',interrupted:true},start('runaway_mattress'),{kind:'finish',interrupted:false}]});
 for(const [name,x,y]of [['h_forward',500,530],['h_back',1800,530],['v_forward',2090,250],['v_back',2090,1700]])specs.push({id:'mattress_road_'+name,setup:{player:{x:x-12,y:y-14}},ops:[start('runaway_mattress'),tick(1000)]});
 for(const [name,time,dx,dy]of [['time_exact',1800,0,0],['time_after',1800.001,0,0],['x_exact',5000,25,0],['x_inside',5000,24.999,0],['y_exact',5000,0,25],['y_inside',5000,0,24.999],['negative_x_exact',5000,-25,0]])specs.push({id:'mattress_bump_'+name,ops:[start('runaway_mattress'),{kind:'align_actor',time,dx,dy},{kind:'update_active'},{kind:'update_active'}]});
 for(const alive of [true,false])specs.push({id:'receipt_dog_'+alive,setup:{actors:{brutus:{dead:!alive}}},ops:[start('yuri_receipt'),tick(12800)]});
 for(const [name,time,distance]of [['time_exact',5000,0],['time_after',5000.001,0],['distance_exact',6000,20],['distance_inside',6000,19.999]])specs.push({id:'paper_'+name,setup:{actors:{brutus:{dead:true}},player:{x:298,y:206}},ops:[start('yuri_receipt'),change({state:{incident:{id:'yuri_receipt',t:time,beat:-1,duration:28000,actors:[],bumped:false,anchor:{x:310,y:220,tx:570,ty:220}}},player:{x:428,y:206+distance}}),{kind:'update_active'},tick(50,false,true),tick(3950,true)]});
 for(const [name,time,distance]of [['start_exact',12000,0],['start_after',12000.001,0],['end_before',22999.999,0],['end_exact',23000,0],['radius_exact',13000,175],['radius_inside',13000,174.999]])specs.push({id:'wet_'+name,ops:[start('park_dry_committee'),change({state:{incident:{id:'park_dry_committee',t:time,beat:-1,duration:28000,actors:[],bumped:false,anchor:{x:2600,y:1280},sprayAngle:-.4}},player:{x:2588+distance,y:1266}}),{kind:'update_active'},tick(50,false,true),tick(3950,true)]});
 for(const time of [8999.999,9000,14499.999,14500,27000])specs.push({id:'suitcase_phase_'+time,ops:[start('ticketed_luggage'),{kind:'align_actor',time,dx:100,dy:100},{kind:'update_active'}]});
 for(const [dx,dy]of [[0,0],[32,0],[31.999,0],[0,28],[0,27.999]])specs.push({id:'suitcase_avoid_'+dx+'_'+dy,ops:[start('ticketed_luggage'),{kind:'align_actor',time:16000,dx,dy},{kind:'update_active'}]});
 const cases=[];
 for(const spec of specs){reset(spec);const setup=snapshot(),steps=[];for(const raw of spec.ops){const operation=copy(raw);ui.toastEl.textContent='';sounds=[];run(operation);steps.push({operation,expected:snapshot()});}cases.push({id:spec.id,rolls:spec.rolls||[],setup,steps});}
 for(const [zone,id]of Object.entries({market:'possum_inventory',laundromat:'laundromat_walkout',scrap:'yuri_receipt',park:'park_dry_committee',trainyard:'ticketed_luggage',outside:'runaway_mattress'}))assert.equal(cases.find(c=>c.id==='schedule_'+zone).steps[0].expected.state.incident.id,id,'Source eligibility witness '+zone);
 for(const id of inc.INCIDENT_IDS){const c=cases.find(c=>c.id==='complete_'+id);assert.equal(c.steps.at(-1).expected.state.incident,null);assert.equal(c.steps.at(-1).expected.writes,1);assert.equal(Math.max(...c.steps.map(s=>s.expected.state.incident?.beat??-1)),3);}
 // Actual source lifecycle, not an inferred replacement for the fresh-state bug.
 reset({});inc.startIncident('yuri_receipt');ui.state.incident.t=1234;ui.state.incidentT=321;ui.state.incidentPaperT=91;ui.state.incidentWetT=92;
 boot.startGame(false);
 const fresh={active:ui.state.incident.id,time:ui.state.incident.t,delay:ui.state.incidentT,paper:ui.state.incidentPaperT,wet:ui.state.incidentWetT,history:picked(ui.state.flags,FKEYS.slice(0,4))};
 Object.assign(ui.state.flags,{incidentDay:2,incidentMask:9,incidentsToday:2,lastIncidentId:'yuri_receipt'});ui.state.day=2;
 await save.saveGame();const storedHistory=picked(ui.state.flags,FKEYS.slice(0,4));draws=0;rolls=[.25];
 const restored=await save.loadGame();
 const restore={ok:restored,active:ui.state.incident,delay:ui.state.incidentT,paper:ui.state.incidentPaperT,wet:ui.state.incidentWetT,history:picked(ui.state.flags,FKEYS.slice(0,4)),storedHistory,draws};
 assert.equal(fresh.active,'yuri_receipt');assert.equal(fresh.delay,321);assert.equal(restore.active,null);assert.deepEqual(restore.history,storedHistory);
 const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
 return {schema:1,format:'rock-bottom-incidents-reference',source:{authority:'unchanged live incidents functions, real muted audio/feed/save and actual start/load lifecycle',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),incidents:inc.INCIDENT_IDS.length,beats:Object.values(inc.INCIDENT_DEFS).reduce((n,d)=>n+d.beats.length,0)},cases,lifecycle:{fresh,restore}};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildIncidentsOracle(),output=stableStringify(result);
 if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Incidents oracle drift; regenerate deliberately.');else fs.writeFileSync(OUTPUT,output);
 console.log(`3D INCIDENTS ORACLE: PASS (${result.counts.cases} source paths/${result.counts.steps} steps;6 scenes/24 beats; actual fresh/load characterization)`);
}
