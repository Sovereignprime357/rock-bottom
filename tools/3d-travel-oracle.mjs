import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { ROOT, loadSeededSource, ensureVmFlag, stableStringify, sourceFiles } from './export-3d-content.mjs';

// Development evidence only. Invoke live source functions/callbacks, never copied transaction math.
const OUTPUT = path.join(ROOT, 'game3d/tests/fixtures/travel_reference.json');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const clone = value => JSON.parse(JSON.stringify(value));
const pass = (q = 1) => ({ id: 'bus_pass', n: 'a bus pass', q });
const PKEYS = ['x','y','w','h','hp','maxHp','cash','rocks','copper','brain','shakes','wanted','speed','cartMounted','inventory','equip','faction'];
const FLAGS = ['scrapHideoutOwned','momHideoutOwned','momRentDay','busPassUsedDay','momBusPassDay'];
const COUNTERS = ['stripeFencedToday','barbPacketsToday','peteCashToday','heistsToday','robberiesToday','breakinsToday'];
const LABELS = {
  buy_pass: /^(buy a bus pass\.|a bus pass is)/, use_pass: /^use the bus pass/,
  rent_couch: /^ask mom if you can stay over/, buy_cart: /^(trade 5 PURE COPPER|you need 5 pure copper)/,
  rest: /^rest 30 minutes/, sleep: /^sleep until morning/, phone: /^use the apartment phone/,
  'deposit:rocks': /^deposit (1 rock|a rock)/, 'withdraw:rocks': /^withdraw (1 rock|a rock)/,
  'deposit:copper': /^deposit (1 copper|copper)/, 'withdraw:copper': /^withdraw (1 copper|copper)/,
  'deposit:cash': /^deposit \$10/, 'withdraw:cash': /^withdraw \$10/,
  back: /^(close the chest\.|back to the office\.)/,
};

export async function buildTravelOracle() {
  const game = await loadSeededSource();
  const ui = game.module('src/core/runtime_ui.js');
  const start = game.module('src/core/start.js');
  const homes = game.module('src/systems/daily_hideouts.js');
  const vendors = game.module('src/dialogue/vendors_places.js');
  const neighbors = game.module('src/dialogue/neighborhood_a.js');
  const other = game.module('src/dialogue/neighborhood_b.js');
  const props = game.module('src/data/props.js');
  const campaign = game.module('src/systems/campaigns.js');
  const update = game.module('src/core/update.js');
  const interactions = game.module('src/systems/interactions.js');
  const audioSave = game.module('src/core/audio_save.js');
  const spawns = game.module('src/data/npc_spawns.js');
  let saved = null;
  game.context.storage = { async set(_key, value) { saved = clone(value); }, async get() { return { value: saved }; } };
  const snapshot = () => ({
    player: Object.fromEntries(PKEYS.map(key => [key, clone(ui.P[key])])),
    flags: Object.fromEntries(FLAGS.map(key => [key, ui.state.flags[key] ?? null])),
    counters: Object.fromEntries(COUNTERS.map(key => [key, ui.state.counters[key] ?? 0])),
    stash: clone(ui.state.hideoutStash), day: ui.state.day, dayTime: ui.state.dayTime,
    lifetimeDay: ui.P.lifetime.dayCount, achievements: [...ui.state.achievements].sort(),
    cart: clone(props.rideableCart()), territoryHeat: ui.state.territoryHeat,
    territoryGreeted: [...ui.state.territoryGreeted], territoryZoneId: ui.state.territoryZoneId ?? null,
    phoneT: ui.state.phoneT,
  });
  function reset(spec = {}) {
    ui.init_runtime_ui(); start.startGame(false);
    ui.P.equip.tool = null;
    Object.assign(ui.P, clone(spec.player || {}));
    Object.assign(ui.state.flags, clone(spec.flags || {}));
    Object.assign(ui.state.counters, clone(spec.counters || {}));
    if (spec.stash) ui.state.hideoutStash = clone(spec.stash);
    if (spec.office) Object.assign(ui.state.office, clone(spec.office));
    ui.state.day = spec.day ?? 2; ui.P.lifetime.dayCount = ui.state.day;
    ui.state.dayTime = spec.dayTime ?? 0.35;
    ui.state.phoneT = 30000; ui.state.territoryHeat = 17;
    ui.state.territoryGreeted = new Set(['already']); ui.state.territoryZoneId = 'market';
    ui.state.mode = 'playing';
    for (const n of ui.runtime.npcs) { n.hostile = false; n.aggro = false; }
    ui.applyEquipStats();
    game.context.__qa.timers.length = 0;
    let seed = 0x19c0ffee;
    game.context.Math.random = () => ((seed = (Math.imul(seed,1664525)+1013904223) >>> 0) / 0x100000000);
  }
  function at(service) {
    let location;
    if (['pinky','bus','mom','biggu'].includes(service)) location = ui.runtime.npcs.find(n => n.id === (service === 'bus' ? 'pinky' : service));
    else if (service.includes('office')) location = campaign.OFFICE_DOOR;
    else location = homes.HIDEOUT_DOORS[service.split(':')[1]];
    assert.ok(location, `No source location ${service}`);
    ui.P.x = location.x + location.w/2 - ui.P.w/2;
    ui.P.y = location.y + location.h/2 - ui.P.h/2;
  }
  function menu(service, page = 0) {
    if (service === 'bus') vendors.openBusPassMenu(page);
    else if (service === 'pinky') vendors.pinkyDialogue();
    else if (service === 'mom') neighbors.momDialogue();
    else if (service === 'biggu') other.bigguDialogue();
    else if (service === 'office:cot') homes.openOfficeCot();
    else if (service === 'office:chest') homes.openHideoutChest('office');
    else if (service.startsWith('chest:')) homes.openHideoutChest(service.split(':')[1]);
    else homes.openHideout(service.split(':')[1]);
  }
  async function operation(op) {
    if (op.kind === 'menu') {
      at(op.service); menu(op.service, op.page || 0);
      const matcher = op.action.startsWith('ride:')
        ? label => { const name=vendors.BUS_ZONE_TARGETS.find(t => t.zoneId === op.action.slice(5)).label; return label.startsWith('take the bus to '+name+'.')||label.startsWith(name+' —'); }
        : label => LABELS[op.action]?.test(label);
      const choice = ui.activeDialogue.opts.find(o => matcher(o.label));
      const outcome = { present: !!choice, enabled: !!choice && !choice.disabled };
      if (outcome.enabled) { ui.closeDialogue(); choice.action(); }
      else ui.closeDialogue();
      return outcome;
    }
    if (op.kind === 'bus_tick') {
      const timer = game.context.__qa.timers.find(t => t[0] === 'timeout' && t[2] === 380);
      assert.ok(timer, 'Source bus delay must be registered as380ms'); timer[1]();
      return { delayMs: timer[2] };
    }
    if (op.kind === 'dawn') {
      ui.state.dayTime = 1; update.updateWorld(0);
      return { day: ui.state.day };
    }
    if (op.kind === 'mount') {
      ui.runtime.npcs = []; const cart = props.rideableCart();
      ui.P.x = cart.x-ui.P.w/2+(op.offset || 0); ui.P.y = cart.y-ui.P.h/2;
      interactions.tryInteract(); return { mounted: ui.P.cartMounted };
    }
    if (op.kind === 'dismount') {
      ui.runtime.npcs = []; ui.P.x = op.x; ui.P.y = op.y; interactions.tryInteract();
      return { sourceDrop: { x: props.rideableCart().x, y: props.rideableCart().y } };
    }
    throw new Error(`Unknown oracle operation ${op.kind}`);
  }
  const steps = (service, ...actions) => actions.map(action => ({ kind:'menu', service, action }));
  const specs = [
    { id:'pinky_fixed_price_with_charisma', player:{cash:20,equip:{hat:'pigeon_crown'}}, ops:steps('pinky','buy_pass','buy_pass') },
    { id:'pinky_short', player:{cash:19}, ops:steps('pinky','buy_pass') },
    { id:'pinky_raw_negative_hp_stun', player:{cash:20,hp:-3,stunT:500}, ops:steps('pinky','buy_pass') },
    { id:'mom_raw_negative_hp_stun_rest', player:{hp:-3,stunT:500}, flags:{momHideoutOwned:true}, ops:steps('hideout:mom','rest') },
    { id:'bus_raw_negative_hp_stun', player:{hp:-3,stunT:500,inventory:[pass()]}, ops:[...steps('bus','ride:block'),{kind:'bus_tick'}] },
    { id:'cart_raw_negative_hp_stun', player:{hp:-3,stunT:500}, ops:[{kind:'mount'}] },
    { id:'pinky_already_carrying', player:{cash:40,inventory:[pass(7)]}, ops:steps('pinky','buy_pass') },
    { id:'mom_gate_below', player:{cash:30,faction:{street:0,scrap:0,spiritual:9}}, ops:steps('mom','rent_couch') },
    { id:'mom_short', player:{cash:29,faction:{street:0,scrap:0,spiritual:10}}, ops:steps('mom','rent_couch') },
    { id:'mom_purchase_once', player:{cash:90,faction:{street:0,scrap:0,spiritual:10}}, ops:steps('mom','rent_couch','rent_couch') },
    { id:'biggu_repeat_mount', player:{copper:10,hp:65}, ops:steps('biggu','buy_cart','buy_cart') },
    { id:'biggu_short', player:{copper:4}, ops:steps('biggu','buy_cart') },
    { id:'cart_mount', player:{hp:65}, ops:[{kind:'mount'}] },
    { id:'cart_boundary36', ops:[{kind:'mount',offset:36}] },
    { id:'cart_equipped', player:{equip:{shoes:'crocs',hat:null,coat:null,tool:null},hp:65}, ops:[{kind:'mount'}] },
    { id:'cart_slow_equipment', player:{equip:{shoes:null,hat:null,coat:'parka',tool:null},hp:65}, ops:[{kind:'mount'}] },
    { id:'cart_source_dismount', player:{cartMounted:true,hp:109}, ops:[{kind:'dismount',x:2100,y:2200}] },
    { id:'stash_shared', player:{rocks:2,copper:2,cash:25}, flags:{momHideoutOwned:true,scrapHideoutOwned:true}, ops:[...steps('chest:mom','deposit:rocks','deposit:copper','deposit:cash'),...steps('chest:scrap','withdraw:rocks','withdraw:copper','withdraw:cash')] },
    { id:'stash_empty', flags:{momHideoutOwned:true}, ops:steps('chest:mom','deposit:rocks','deposit:copper','deposit:cash','withdraw:rocks','withdraw:copper','withdraw:cash') },
    { id:'stash_short_cash_items', player:{cash:9}, stash:{rocks:0,copper:0,cash:9,items:[{id:'junk',n:'a piece of junk',q:1}]}, flags:{scrapHideoutOwned:true}, ops:steps('chest:scrap','deposit:cash','withdraw:cash') },
    { id:'mom_phone', flags:{momHideoutOwned:true}, ops:steps('hideout:mom','phone') },
    { id:'natural_dawn_pass_rent', player:{cash:30,faction:{street:0,scrap:0,spiritual:10}}, flags:{momHideoutOwned:true}, ops:[{kind:'dawn'}] },
    { id:'natural_dawn_pass_before_eviction', player:{cash:29,faction:{street:0,scrap:0,spiritual:10}}, flags:{momHideoutOwned:true}, ops:[{kind:'dawn'}] },
    { id:'natural_dawn_existing_pass_stamp', player:{inventory:[pass()],faction:{street:0,scrap:0,spiritual:10}}, ops:[{kind:'dawn'}] },
    { id:'natural_dawn_below_gate', player:{faction:{street:0,scrap:0,spiritual:9}}, ops:[{kind:'dawn'}] },
    { id:'natural_dawn_previously_stamped', player:{faction:{street:0,scrap:0,spiritual:10}}, flags:{momBusPassDay:3}, ops:[{kind:'dawn'}] },
    { id:'bus_first_record', player:{inventory:[pass(9),{id:'junk',n:'a piece of junk',q:1},pass()]}, ops:[...steps('bus','ride:block'),{kind:'bus_tick'}] },
    { id:'bus_used_today', player:{inventory:[pass()]}, flags:{busPassUsedDay:2}, ops:steps('bus','ride:block') },
    { id:'bus_no_pass', ops:steps('bus','ride:block') },
    { id:'bus_wanted', player:{wanted:0.1,inventory:[pass()]}, ops:steps('bus','ride:block') },
  ];
  for (const kind of ['mom','scrap']) {
    specs.push({id:`${kind}_rest`,player:{hp:40,wanted:2},flags:{[kind+'HideoutOwned']:true},ops:steps('hideout:'+kind,'rest')});
    for (const time of [0.1,0.3,0.30001,0.9]) specs.push({id:`${kind}_sleep_${time}`,day:6,dayTime:time,player:{hp:20,brain:20,shakes:10,wanted:3,cash:50,faction:{street:0,scrap:0,spiritual:10}},flags:{[kind+'HideoutOwned']:true},counters:{peteCashToday:199,heistsToday:3},ops:steps('hideout:'+kind,'sleep')});
    specs.push({id:`${kind}_sleep_clamped`,player:{hp:98,brain:99,shakes:99,wanted:1},flags:{[kind+'HideoutOwned']:true},ops:steps('hideout:'+kind,'sleep')});
  }
  for (const generator of [false,true]) {
    for (const action of ['rest','sleep']) specs.push({id:`office_${action}_${generator}`,day:6,player:{hp:20,brain:20,shakes:10,wanted:3},office:{owned:true,upgrades:{cot:true,locker:true,generator}},ops:steps('office:cot',action)});
    specs.push({id:`office_stash_${generator}`,player:{rocks:1,copper:1,cash:10},office:{owned:true,upgrades:{cot:true,locker:true,generator}},ops:steps('chest:office','deposit:rocks','deposit:copper','deposit:cash')});
  }
  const cases = [];
  for (const spec of specs) {
    reset(spec); const setup = snapshot(); const offered=[];
    for (const op of spec.ops) offered.push(await operation(op));
    cases.push({id:spec.id,setup,office:clone(ui.state.office),operations:spec.ops,offered,expected:snapshot()});
  }
  const menuView=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(option=>({label:option.label,enabled:!option.disabled}))}:null;
  const presentation=[];
  for(const service of ['chest:mom','chest:scrap','chest:office','office:chest']) for(const balance of ['empty','funded','partial']) {
    const player=balance==='funded'?{rocks:2,copper:2,cash:20}:balance==='partial'?{rocks:1,copper:0,cash:9}:{rocks:0,copper:0,cash:0};
    const stash=balance==='funded'?{rocks:3,copper:4,cash:30,items:[]}:balance==='partial'?{rocks:0,copper:2,cash:9,items:[{id:'junk',n:'a piece of junk',q:1}]}:{rocks:0,copper:0,cash:0,items:[]};
    reset({player,stash,flags:{momHideoutOwned:true,scrapHideoutOwned:true},office:{owned:true,upgrades:{cot:true,locker:true}}});
    at(service);ui.toastEl.textContent='';const setup=snapshot(),office=clone(ui.state.office);menu(service);
    const opening=menuView(),steps=[];
    if(balance==='funded')for(const action of ['deposit:rocks','withdraw:rocks','deposit:copper','withdraw:copper','deposit:cash','withdraw:cash','back']){
      const choice=ui.activeDialogue.opts.find(option=>LABELS[action].test(option.label));assert.ok(choice&&!choice.disabled,'Source UI option '+action);
      ui.closeDialogue();choice.action();steps.push({action,menu:menuView(),toast:ui.toastEl.textContent,mode:ui.state.mode});
    }
    presentation.push({id:service+'_'+balance,service,setup,office,opening,steps});
  }
  for(const generator of [false,true])for(const action of ['rest','sleep','back']){
    reset({dayTime:.2,player:{hp:20,brain:20,shakes:10,wanted:3},office:{owned:true,upgrades:{cot:true,locker:true,generator}}});
    at('office:cot');ui.toastEl.textContent='';const setup=snapshot(),office=clone(ui.state.office);menu('office:cot');const opening=menuView();
    const choice=ui.activeDialogue.opts.find(option=>LABELS[action].test(option.label));assert.ok(choice&&!choice.disabled,'Source cot UI '+action);
    ui.closeDialogue();choice.action();presentation.push({id:'cot_'+generator+'_'+action,service:'office:cot',setup,office,opening,steps:[{action,menu:menuView(),toast:ui.toastEl.textContent,mode:ui.state.mode}]});
  }
  const busCases=[];
  for (let index=0;index<vendors.BUS_ZONE_TARGETS.length;index++) {
    const target=vendors.BUS_ZONE_TARGETS[index]; reset({player:{inventory:[pass()]}});
    for (const entry of vendors.BUS_ZONE_TARGETS) if(entry.flag) ui.state.flags[entry.flag]=true;
    at('bus'); const setup=snapshot(); vendors.openBusPassMenu(Math.floor(index/6));
    const option=ui.activeDialogue.opts.find(o=>o.label===`take the bus to ${target.label}.`);
    assert.ok(option&&!option.disabled,`Destination absent ${target.zoneId}`); ui.closeDialogue(); option.action();
    const selected=snapshot(); await operation({kind:'bus_tick'});
    busCases.push({target:clone(target),page:Math.floor(index/6),setup,selected,arrived:snapshot()});
  }
  const busGates=[];
  for(const distance of [219.999,220,220.001]) for(const variant of ['hostile','aggro','dead','pet']){
    reset({player:{inventory:[pass()]}}); at('bus');
    const center={x:ui.P.x+ui.P.w/2,y:ui.P.y+ui.P.h/2};
    ui.runtime.npcs=[{id:'test_source_actor',x:center.x+distance-12,y:center.y-14,w:24,h:28,hostile:variant!=='aggro',aggro:variant==='aggro',dead:variant==='dead',isPet:variant==='pet'}];
    busGates.push({distance,variant,active:vendors.combatActive()});
  }
  reset(); const knownZones=vendors.visitedZonesForBus().map(t=>t.zoneId);
  const gatedZones=[];
  for(const target of vendors.BUS_ZONE_TARGETS.filter(t=>t.flag)){
    reset();ui.state.flags[target.flag]=true;gatedZones.push({flag:target.flag,zones:vendors.visitedZonesForBus().map(t=>t.zoneId)});
  }
  const zoneCases=[],zones=game.module('src/data/world.js').ZONES;
  for(let i=0;i<zones.length;i++) for(let j=i+1;j<zones.length;j++) {
    const a=zones[i],b=zones[j],x=Math.max(a.x,b.x),y=Math.max(a.y,b.y),right=Math.min(a.x+a.w,b.x+b.w),bottom=Math.min(a.y+a.h,b.y+b.h);
    if(x>right||y>bottom)continue;
    for(const faction of [{street:0,scrap:0,spiritual:0},{street:50,scrap:10,spiritual:-25},{street:-10,scrap:50,spiritual:25}]) {
      reset({player:{faction}});ui.P.x=(x+right)/2-ui.P.w/2;ui.P.y=(y+bottom)/2-ui.P.h/2;
      zoneCases.push({point:{x:(x+right)/2,y:(y+bottom)/2},faction,expected:spawns.currentZone()?.id||''});
    }
  }
  // Save behavior is executed through real async source methods and same-process state.
  reset({player:{cartMounted:true,rocks:3},flags:{momHideoutOwned:true},stash:{rocks:2,copper:4,cash:30,items:[{id:'junk',n:'a piece of junk',q:1}]}});
  props.rideableCart().x=2000;props.rideableCart().y=2100;await audioSave.saveGame();
  const savedCartKeys=Object.keys(saved).filter(k=>/cart/i.test(k));
  props.rideableCart().x=2300;props.rideableCart().y=2400;ui.P.cartMounted=false;
  assert.equal(await audioSave.loadGame(),true);start.startGame(true);
  const loaded={mounted:ui.P.cartMounted,cart:{x:props.rideableCart().x,y:props.rideableCart().y},stash:clone(ui.state.hideoutStash),savedCartKeys};
  start.startGame(false); const fresh={mounted:ui.P.cartMounted,cart:{x:props.rideableCart().x,y:props.rideableCart().y}};
  const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
  const artifact={schema:1,format:'rock-bottom-travel-reference',source:{authority:'unchanged active source functions and menu callbacks',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{destinations:vendors.BUS_ZONE_TARGETS.length,hideouts:Object.keys(homes.HIDEOUT_DOORS).length,cart:props.PROPS.filter(p=>p.type==='cart').length,cartHusks:props.PROPS.filter(p=>p.type==='cart_husk').length,cases:cases.length,presentation:presentation.length,busCases:busCases.length,busGates:busGates.length},cases,presentation,busCases,busGates,knownZones,gatedZones,zoneCases,saveLifecycle:{loaded,fresh},scope:'source model evidence; physical destination/drop adaptations are separately tested'};
  assert.deepEqual([artifact.counts.destinations,artifact.counts.hideouts,artifact.counts.cart,artifact.counts.cartHusks],[18,2,1,6]);
  return artifact;
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  ensureVmFlag(fileURLToPath(import.meta.url));
  const text=stableStringify(await buildTravelOracle());
  if(process.argv.includes('--check')) assert.equal(fs.readFileSync(OUTPUT,'utf8'),text,'Travel oracle fixture drift; regenerate deliberately.');
  else {fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,text);}
  const data=JSON.parse(text);console.log(`3D TRAVEL ORACLE: PASS (${data.counts.cases} source action cases,${data.counts.presentation} exact chest/cot UI paths,18 destinations,12 combat gates,2 hideouts,1 cart; explicit3D adaptations separate)`);
}
