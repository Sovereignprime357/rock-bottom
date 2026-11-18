import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { ROOT, FIXED_EPOCH_MS, loadSeededSource, ensureVmFlag, stableStringify, sourceFiles } from './export-3d-content.mjs';

// Executes original functions/callbacks. Test fixtures do not become runtime behavior.
const OUTPUT = path.join(ROOT,'game3d/tests/fixtures/day_reference.json');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const copy = value => JSON.parse(JSON.stringify(value));
const PKEYS = ['x','y','hp','maxHp','cash','rocks','brain','shakes','wanted','weapon','equip','faction','rockedT','crashT'];
const FKEYS = ['day3Fired','day7Fired','day14Fired','day30Fired','silenceUntilT','busTaken','busRefused','priceGuyDay','priceGuyVisits','parkNightCashDay','momBusPassDay','momRentDay','momHideoutOwned','scrapHideoutOwned'];
const AKEYS = ['id','name','sprite','x','y','w','h','color','hp','maxHp','speed','hostile','archetype','isDay3Visitor','isPriceGuy','isBusDriver','hasFloater','priceResolved','priceWalkOff','wanderOff','targetX','targetY'];
const pluck = (record,keys) => Object.fromEntries(keys.filter(key=>record[key]!==undefined).map(key=>[key,copy(record[key])]));
const conditional = n => n.isDay3Visitor || n.isPriceGuy || n.isBusDriver;

export async function buildDayOracle() {
  const game=await loadSeededSource();
  const ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
  const homes=game.module('src/systems/daily_hideouts.js'),vendors=game.module('src/dialogue/vendors_places.js');
  const update=game.module('src/core/update.js'),activities=game.module('src/minigames/activities.js');
  const spawns=game.module('src/data/npc_spawns.js');
  let roll=.5,randomCalls=0,saves=0;
  game.context.storage={async set(){saves++;},async get(){return null;}};
  function reset(spec={}) {
    ui.init_runtime_ui();start.startGame(false);
    ui.state.mode='playing';ui.state.day=spec.day??2;ui.state.dayTime=spec.time??.35;
    ui.P.lifetime.dayCount=ui.state.day;
    Object.assign(ui.P,{hp:20,brain:20,shakes:10,wanted:0,cash:51,rockedT:0,crashT:0},copy(spec.player||{}));
    Object.assign(ui.state.flags,copy(spec.flags||{}));
    for(const key of homes.DAILY_COUNTER_KEYS) ui.state.counters[key]=7;
    Object.assign(ui.state.counters,{robLastClockMs:456,kombuchaAskDay:1,slept:2},copy(spec.counters||{}));
    ui.state.office.workDay=spec.workDay??1;ui.state.office.workToday=3;
    if(spec.office) {
      // Fixture arrangement preserves the source's canonical upgrade map. Malformed
      // office-save normalization belongs to the forthcoming campaign owner gate.
      const upgrades={...ui.state.office.upgrades,...spec.office.upgrades};
      Object.assign(ui.state.office,copy(spec.office));ui.state.office.upgrades=upgrades;
    }
    if(spec.locker) ui.state.flags.peteToolLocker=copy(spec.locker);
    if(spec.kingdom) Object.assign(ui.state.kingdom,copy(spec.kingdom));
    ui.state.phoneT=1e9;ui.state.eventT=1e9;ui.state.publicPhoneT=1e9;
    ui.state.momTipT=1e9;ui.state.incidentT=1e9;ui.state.hustleCheckT=0;
    ui.runtime.npcs=ui.runtime.npcs.filter(n=>n.kingdomGuard||n.kingdomPretender);
    ui.runtime.cashPiles=[];game.context.__qa.timers.length=0;
    roll=spec.roll??.5;randomCalls=0;saves=0;
    game.context.Math.random=()=>{randomCalls++;return roll;};
  }
  function snapshot() {
    return {player:pluck(ui.P,PKEYS),flags:pluck(ui.state.flags,FKEYS),
      counters:pluck(ui.state.counters,[...homes.DAILY_COUNTER_KEYS,'robLastClockMs','kombuchaAskDay','slept']),
      day:ui.state.day,time:ui.state.dayTime,lifetimeDay:ui.P.lifetime.dayCount,weather:ui.state.weather,
      office:copy(ui.state.office),kingdom:copy(ui.state.kingdom),locker:copy(ui.state.flags.peteToolLocker||null),
      achievements:[...ui.state.achievements].sort(),inventory:copy(ui.P.inventory),
      actors:ui.runtime.npcs.filter(conditional).map(n=>pluck(n,AKEYS)),
      cash:ui.runtime.cashPiles.filter(p=>p.isInheritance||p.id.startsWith('cp_park_night_')).map(copy),
      mode:ui.state.mode,endingContinue:!!ui.state.endingContinue,territoryCashMult:ui.state.territoryCashMult||1,
      randomCalls,saves};
  }
  function click(actor,matcher) {
	ui.P.x=actor.x+actor.w/2-ui.P.w/2;ui.P.y=actor.y+actor.h/2-ui.P.h/2;
    actor.interact(actor); const option=ui.activeDialogue.opts.find(o=>matcher.test(o.label));
    assert.ok(option,'source option missing');
    const enabled=!option.disabled;ui.closeDialogue();if(enabled)option.action();return enabled;
  }
  const cases=[];
  async function run(spec,action) {reset(spec);const before=snapshot();await action();cases.push({spec,before,after:snapshot()});}
  for(const value of [0,.649999,.65,.879999,.88,.999999]) await run({id:'weather_'+value,kind:'weather',roll:value},()=>ui.rollWeather());
  for(const workDay of [1,2]) await run({id:'reset_'+workDay,kind:'reset',workDay},()=>homes.resetDailyCounters());
  for(const day of [2,3,4,7,8,14,15,30,31]) await run({id:'event_'+day,kind:'event',day,roll:.1},()=>homes.fireDayEvents());
  for(const day of [3,7,14,30]) await run({id:'event_repeat_'+day,kind:'event_repeat',day,roll:.9},()=>{homes.fireDayEvents();homes.fireDayEvents();});
  for(const player of [{x:0,y:0},{x:8590,y:5590}]) for(const day of [3,14]) await run({id:`event_edge_${day}_${player.x}`,kind:'event',day,player,roll:.0},()=>homes.fireDayEvents());
  for(const action of ['take_bus','refuse_bus','leave']) await run({id:'conditional_'+action,kind:'interaction',day:action==='leave'?3:30,action},()=>{homes.fireDayEvents();click(ui.runtime.npcs.find(conditional),action==='take_bus'?/^yes\./:action==='refuse_bus'?/^no\./:/^leave\./);});
  for(const resolved of ['', 'busTaken','busRefused']) await run({id:'rehydrate_'+resolved,kind:'rehydrate',day:35,flags:{day30Fired:true,...(resolved?{[resolved]:true}:{})}},()=>{homes.rehydrateDay30Bus();homes.rehydrateDay30Bus();});
  for(const value of [0,.199999,.20,.349999,.35,.449999,.45,.699999,.70,.999999]) await run({id:'price_'+value,kind:'price',day:3,roll:value},()=>{vendors.maybeSpawnPriceGuy();click(ui.runtime.npcs.find(n=>n.id==='price_guy'),/^pay the price/);});
  for(const item of ['slot','locker','crowbar']) await run({id:'price_tool_'+item,kind:'price',day:3,roll:.4,player:{equip:{shoes:null,hat:null,coat:null,tool:item==='slot'?'propane_torch':item==='crowbar'?'crowbar':null}},...(item==='locker'?{locker:'propane_torch'}:{})},()=>{vendors.maybeSpawnPriceGuy();click(ui.runtime.npcs.find(n=>n.id==='price_guy'),/^pay the price/);});
  await run({id:'price_empty',kind:'price',day:3,roll:0,player:{cash:0}},()=>{vendors.maybeSpawnPriceGuy();click(ui.runtime.npcs.find(n=>n.id==='price_guy'),/^you have nothing/);});
  for(const day of [2,3,6]) await run({id:'price_poll_'+day,kind:'price_poll',day},()=>{vendors.maybeSpawnPriceGuy();vendors.maybeSpawnPriceGuy();});
  for(const value of [.249999,.25,.75,.750001]) await run({id:'night_'+value,kind:'night',time:value},()=>{});
  for(const value of [0,.299999,.3,.999999]) for(const spiritual of [0,25]) await run({id:`park_${value}_${spiritual}`,kind:'park',day:2,time:.8,roll:value,player:{x:2510,y:1320,faction:{street:0,scrap:0,spiritual}}},()=>update.updateWorld(0));
  for(const cause of ['natural','hideout_sleep','office_sleep','block_sleep']) for(const time of [.3,.300001]) await run({id:`cause_${cause}_${time}`,kind:'cause',cause,day:6,time,roll:.4,player:{x:1050,y:840},flags:{scrapHideoutOwned:true,momHideoutOwned:true},office:{owned:true,upgrades:{cot:true}}},()=>{
    if(cause==='natural'){ui.state.dayTime=1;update.updateWorld(0);return;}
    if(cause==='hideout_sleep') {const d=homes.HIDEOUT_DOORS.scrap;ui.P.x=d.x+d.w/2-ui.P.w/2;ui.P.y=d.y+d.h/2-ui.P.h/2;homes.openHideout('scrap');}
    else if(cause==='office_sleep') {const d=game.module('src/systems/campaigns.js').OFFICE_DOOR;ui.P.x=d.x+d.w/2-ui.P.w/2;ui.P.y=d.y+d.h/2-ui.P.h/2;homes.openOfficeCot();}
    else activities.blockMenu();
    const option=ui.activeDialogue.opts.find(o=>/^sleep/.test(o.label));assert.ok(option&&!option.disabled);ui.closeDialogue();option.action();
  });
  for(const entry of cases) if(entry.spec.kind==='night'){reset(entry.spec);entry.expectedNight=spawns.isNight();}
  // Dawn callback timing is read from actual source timers, not reconstructed in the fixture.
  const dawnTimers=[];
  for(const value of [.1,.5,.9]) {reset({day:1,time:1,roll:value});update.updateWorld(0);dawnTimers.push({roll:value,timers:game.context.__qa.timers.filter(t=>t[0]==='timeout'&&['garbageTruckRumble','maybeFireMomProudCall'].includes(t[1].name)).map(t=>({name:t[1].name,delay:t[2]}))});}
  // Save-normalizer identity fixtures use exact generated source guard/pretender payloads.
  reset({day:9,kingdom:{stage:'complete',pretendersDefeated:3}});homes.resetDailyCounters();
  const campaignActors=ui.runtime.npcs.filter(n=>n.kingdomGuard||n.kingdomPretender).map(copy);
  const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
  const artifact={schema:1,format:'rock-bottom-day-reference',unixMs:FIXED_EPOCH_MS,source:{authority:'unchanged active source functions and callbacks',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{cases:cases.length,weather:3,causes:4,events:4,dailyKeys:homes.DAILY_COUNTER_KEYS.length,conditionalFamilies:3,dawnTimers:dawnTimers.length},dailyKeys:copy(homes.DAILY_COUNTER_KEYS),cases,dawnTimers,campaignActors,scope:'Source model evidence. Deferred physical placement, required owner contracts and source ending presentation adaptation are tested separately.'};
  assert.equal(artifact.counts.dailyKeys,6);assert.ok(cases.length>=60);return artifact;
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildDayOracle());
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Day source fixture drift; regenerate deliberately.');
  else{fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,output);}
  const artifact=JSON.parse(output);console.log(`3D DAY ORACLE: PASS (${artifact.counts.cases} source cases;4 causes,4 events,6 daily reset keys,3 conditional families)`);
}
