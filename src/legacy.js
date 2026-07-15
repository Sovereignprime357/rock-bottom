/* Generated from frozen rock_bottom_v19.html.
 * Source seams: achievements, hustles, and block routes | office, claims, and curb kingdom campaign | calls, possum, truck, news, feed, and world events | living-neighborhood incidents | sprite data and sprite caches | audio and persistence | world state and status UI | helpers, NPC setup, and cash piles | neighborhood dialogue, first half | neighborhood dialogue, second half | bus, vendors, and place encounters | cook and heat minigame | combat primitives, intro, boss, and cops | NPC AI and chatter loop | world update loop | HUD | canvas and connective geography | landmark and light caches | frame renderer | fences, underpass, and leash | tile palettes and market stalls | buildings, graffiti, posters, and claim visuals | prop and interactive-prop rendering | lighting, weather, actors, and objectives | minimap | ending, interaction, and dumpster systems | daily systems and hideouts | heist, weapons, rhythm, lockpick, Brutus, and panhandling | keyboard controls | game start and new-game initialization | cache and HUD boot sequence | mobile controls and final startup.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { CROWN_SPOTS, EQUIPMENT, GRAFFITI_LINES, PUBLIC_PHONE_LINES, SCRAP_GRAFFITI_LINES, SPIRITUAL_GRAFFITI_LINES, VENDOR_FLOATER_IDS, VENDOR_INDEX_META, vendorPrice } from './data/catalogs.js';
import { BUILDINGS, CHATTER, PROPS, initInteractiveProps, interactiveProps } from './data/props.js';
import { CROSSWALKS, GROUND_PATHS, H, LANDMARK_FACADES, RAIL_LINES, RANKS, ROAD_SEGMENTS, TERRAIN_REGIONS, TILE, UTILITY_WIRES, W, WORLD, WORLD_DECOR, WORLD_LIGHTS, ZONES } from './data/world.js';
import { FACTION_TIER_LABELS, adjustFaction, applyRep, factionTier, updateTerritory } from './systems/factions.js';

export let ACHIEVEMENTS, HUSTLE_TEMPLATES, ROUTE_STOPS, ROUTE_STOP_BY_ID;

export function rollHustles() {
  // v13 wave 3 — suppress hustle generation during the intro chain so day 1 stays focused.
  if (state.flags && !state.flags.introDone) {
    state.hustles = [];
    state.hustleSnapshot = state.hustleSnapshot || {};
    return;
  }
  // Pick only contracts that can still be completed in the current world state. The
  // clipboard route is the infinite floor; hustles remain the more mechanical daily layer.
  const live=id=>runtime.npcs.some(n=>n.id===id&&!n.dead);
  const eligible=HUSTLE_TEMPLATES.filter(h=>{
    if(h.id==='fight_2')return runtime.npcs.filter(n=>['lurch','sherri','paulie'].includes(n.id)&&!n.dead).length>=2;
    if(h.id==='church_2')return live('priest')&&!state.flags.omalleyFallen;
    if(h.id==='pawn_2')return live('pete');
    if(h.id==='tony_2')return live('tony');
    if(h.id==='fence_3')return live('stripe')&&!state.flags.stripeBetrayed;
    if(h.id==='possum_1')return live('possum');
    return true;
  });
  for(let i=eligible.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));const t=eligible[i];eligible[i]=eligible[j];eligible[j]=t;}
  const pool = eligible.slice(0,3);
  state.hustleSnapshot = {
    rocksSmoked: P.lifetime.rocksSmoked,
    copperStripped: state.counters.copperStripped||0,
    peteSold: state.counters.peteSold||0,
    bigPan: 0,
    churchDonations: state.counters.churchDonations||0,
    alleyKills: state.counters.alleyKills||0,
    dumpDives: state.counters.dumpDives||0,
    possumProphecies: state.counters.possumProphecies||0,
    rocksBought: state.counters.rocksBought||0,
    slept: state.counters.slept||0,
    tacosEaten: state.counters.tacosEaten||0,
    laundryDone: state.counters.laundryDone||0,
    rocksCooked: P.lifetime.rocksCooked||0,
    rocksFenced: P.lifetime.rocksFenced||0,
  };
  state.counters.bigPan = 0;
  state.hustles = pool.map(h => ({ id:h.id, desc:h.desc, reward:h.reward, done:false }));
  if (state.day > 1) {
    toast("· new hustles posted ·\n(Q to view)", 2400);
    broadcastNews("today's hustles posted in the back alley. (press Q to see them.)");
  }
}

export function checkHustles() {
  if (!state.hustles) return;
  for (const h of state.hustles) {
    if (h.done) continue;
    const tpl = HUSTLE_TEMPLATES.find(x=>x.id===h.id);
    if (tpl && tpl.check()) {
      h.done = true;
      const r = h.reward;
      if (r.cash) P.cash += r.cash;
      if (r.cred) P.cred += r.cred;
      if (r.brain) P.brain = Math.min(100, P.brain + r.brain);
      audio.rankUp();
      toast('· HUSTLE DONE ·\n' + h.desc + '\n' + Object.entries(r).map(([k,v])=>k==='cash'?'+ $'+v:'+ '+v+' '+k).join(' · '), 3200);
      feedPost("knocked out today's hustle: " + h.desc, '@crackheadcent');
      saveGame();
    }
  }
}

export function hustleProgress(h){
  const s=state.hustleSnapshot||{},c=state.counters||{},lt=P.lifetime||{};
  const map={
    rocks_3:[lt.rocksSmoked-(s.rocksSmoked||0),3],copper_4:[(c.copperStripped||0)-(s.copperStripped||0),4],
    pawn_2:[(c.peteSold||0)-(s.peteSold||0),2],pan_5:[c.bigPan||0,1],church_2:[Math.floor(((c.churchDonations||0)-(s.churchDonations||0))/5),1],
    fight_2:[(c.alleyKills||0)-(s.alleyKills||0),2],dump_3:[(c.dumpDives||0)-(s.dumpDives||0),3],
    possum_1:[(c.possumProphecies||0)-(s.possumProphecies||0),1],tony_2:[(c.rocksBought||0)-(s.rocksBought||0),2],
    sleep_1:[(c.slept||0)-(s.slept||0),1],eat_taco:[(c.tacosEaten||0)-(s.tacosEaten||0),1],
    cook_2:[(lt.rocksCooked||0)-(s.rocksCooked||0),2],fence_3:[(lt.rocksFenced||0)-(s.rocksFenced||0),3],
    laundry_1:[(c.laundryDone||0)-(s.laundryDone||0),1],
  };
  const p=map[h.id];if(!p)return '';
  return Math.max(0,Math.min(p[1],p[0]))+'/'+p[1];
}

export function validBlockRoute(route) {
  return !!route && Array.isArray(route.stops) && route.stops.length===3
    && route.stops.every(id=>Object.hasOwn(ROUTE_STOP_BY_ID,id))
    && new Set(route.stops).size===3
    && Number.isInteger(route.cursor) && route.cursor>=0 && route.cursor<=3
    && Number.isInteger(route.serial) && route.serial>=1
    && (route.lastStopId==='' || Object.hasOwn(ROUTE_STOP_BY_ID,route.lastStopId));
}

export function currentBlockRouteStop() {
  if (!validBlockRoute(state.blockRoute) || state.blockRoute.cursor>=3) return null;
  return ROUTE_STOP_BY_ID[state.blockRoute.stops[state.blockRoute.cursor]] || null;
}

export function routePatchTier() {
  return Math.min(4, Math.floor(((P.lifetime&&P.lifetime.routesCompleted)||0)/5));
}

export function rollBlockRoute(silent=false, forcedLastStop='') {
  if (!state.flags || !state.flags.introDone) { state.blockRoute=null; return null; }
  const previous=validBlockRoute(state.blockRoute)?state.blockRoute:null;
  const completed=(P.lifetime&&P.lifetime.routesCompleted)||0;
  // The first two clipboards stay in the original neighborhood. The full map joins after
  // the player has learned that the clipboard is not kidding.
  let pool=(completed<2?ROUTE_STOPS.filter(s=>s.x<2100&&s.y<2100):ROUTE_STOPS)
    .filter(s=>!s.unlockFlag||(state.flags&&state.flags[s.unlockFlag])).slice();
  const lastStopId=forcedLastStop||(previous&&previous.lastStopId)||'';
  if(pool.length>3&&lastStopId) pool=pool.filter(s=>s.id!==lastStopId);
  for(let i=pool.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));const t=pool[i];pool[i]=pool[j];pool[j]=t;}
  const serial=(previous&&previous.serial||0)+1;
  state.blockRoute={stops:pool.slice(0,3).map(s=>s.id),cursor:0,serial,lastStopId};
  if(!silent) toast('· BLOCK ROUTE '+serial+' ·\nthree boxes. one pen. the pen works.',2600);
  return state.blockRoute;
}

export function ensureBlockRoute() {
  if (!state.flags || !state.flags.introDone) { state.blockRoute=null; return; }
  if (!validBlockRoute(state.blockRoute) || state.blockRoute.cursor>=3) rollBlockRoute(true);
}

export function tryStampBlockRoute() {
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive||activeOfficeContract())return false;
  const stop=currentBlockRouteStop(); if(!stop)return false;
  const dx=(P.x+P.w/2)-stop.x,dy=(P.y+P.h/2)-stop.y;
  if(dx*dx+dy*dy>=58*58)return false;
  const route=state.blockRoute;
  route.cursor++;
  if(route.cursor<3){
    audio.coin();
    toast(stop.stamp+'\n['+route.cursor+'/3 stamped]',2800);
    saveGame();
    return true;
  }
  P.lifetime.routesCompleted=(P.lifetime.routesCompleted||0)+1;
  const total=P.lifetime.routesCompleted;
  // The route's final save owns this transaction. Avoid racing an earlier unlock-only
  // snapshot against the cash reward and freshly rolled route.
  const officeUnlocked=maybeUnlockOfficeQuest(false);
  const cash=Math.min(24,6+Math.floor(total/5)*2);
  const cred=Math.min(4,1+Math.floor(total/20));
  P.cash+=cash; P.cred+=cred;
  if(total===5)unlockAchievement('route_five');
  if(total===20)unlockAchievement('route_twenty');
  if(total===50)unlockAchievement('route_fifty');
  const last=stop.id;
  rollBlockRoute(true,last);
  audio.rankUp();
  toast(stop.stamp+'\n· ROUTE FILED '+total+' ·  + $'+cash+' · + '+cred+' cred\na new sheet is under the brick.'+(officeUnlocked?'\nthe leasing guy has a key in the lot.':''),officeUnlocked?5200:4300);
  feedPost('filed block route '+total+'. the clipboard did not say good job.','@crackheadcent');
  saveGame();
  return true;
}

export function init_progression_routes() {
  // ---------- achievements ----------
  ACHIEVEMENTS = {
    i_have_seen_horrors:  { name:"I HAVE SEEN HORRORS",  flav:"view 10 possum prophecies." },
    mayor_of_4th:         { name:"MAYOR OF 4TH STREET",  flav:"defeat all 3 alley crackheads in one run." },
    tonys_worst:          { name:"TONY'S WORST CUSTOMER",flav:"buy 50 rocks." },
    brutus_remembers:     { name:"BRUTUS REMEMBERS",     flav:"die to brutus 3 times." },
    ecclesiastes:         { name:"ECCLESIASTES",         flav:"donate $100 total to the church." },
    judas:                { name:"JUDAS",                flav:"steal plate AND betray stripe." },
    the_conductor_knows:  { name:"THE CONDUCTOR KNOWS",  flav:"wait by the conductor for 60 seconds." },
    glass_mayor:          { name:"GLASS MAYOR",          flav:"reach pipe prophet rank." },
    copper_singer:        { name:"COPPER SINGER",        flav:"strip 10 pure copper total." },
    chef:                 { name:"THE CHEF",             flav:"cook 10 rocks on the crate." },
    arson_of_nothing:     { name:"ARSONIST OF NOTHING",  flav:"burn a whole 3-packet batch." },
    the_route:            { name:"THE ROUTE",            flav:"pet the possum (you do not)." },
    one_foot:             { name:"ONE FOOT",             flav:"trade $20 with the pigeon king." },
    cart_baron:           { name:"CART BARON",           flav:"own the shopping cart." },
    not_a_phase:          { name:"NOT A PHASE",          flav:"hit a 5x combo." },
    tuesday_again:        { name:"TUESDAY, AGAIN",       flav:"survive 7 in-game days." },
    compliment_the_face:  { name:"COMPLIMENT THE FACE",  flav:"compliment paulie 5 times." },
    due_dealer_system:    { name:"DUE DEALER SYSTEM",    flav:"buy from pinky polenta once. you have options now." },
    badge_money:          { name:"BADGE MONEY",          flav:"put cousin brendan on the ground." },
    head_that_wears:      { name:"HEAD THAT WEARS",      flav:"return the pigeon king's lost crown. wear it." },
    exact_change:         { name:"EXACT CHANGE",         flav:"deliver stripe's package. don't open it." },
    what_s_in_the_box:    { name:"WHAT'S IN THE BOX",    flav:"open stripe's package. find out." },
    seven_across:         { name:"SEVEN ACROSS",         flav:"return barb's missing crossword. fourteen across was BLAME." },
    // v13 wave 4 — the heat minigame achievements
    the_heat_held:        { name:"THE HEAT HELD",        flav:"perfect a cook. the needle was steady. so were you." },
    soap_tongue:          { name:"SOAP TONGUE",          flav:"smoke a soap rock. you knew. you knew." },
    controlled_burn:      { name:"CONTROLLED BURN",      flav:"burn a batch and still walk away. the smell stays." },
    // v13 wave 5 — combat depth achievements
    fallen:               { name:"FALLEN",               flav:"put father o'malley on the ground. the church is quiet." },
    dodged_the_lunge:     { name:"DODGED THE LUNGE",     flav:"sidestep a charger's lunge. it lands on nothing." },
    outran_the_priest:    { name:"OUTRAN THE PRIEST",    flav:"survive father o'malley fallen for 60 seconds. the lord is busy." },
    // v13 wave 6 — map depth + scrap yard
    liberator:            { name:"LIBERATOR",            flav:"free the chained dog. he never looks back. he never needed to." },
    the_piece_of_shit:    { name:"THE PIECE OF SHIT",    flav:"attacked the chained dog. there is a piece of shit out there. it is you." },
    phone_booth_prophet:  { name:"PHONE BOOTH PROPHET",  flav:"answer five public phone calls. nobody is paying you. someone is calling." },
    // v13 wave 7 — third ending + faction milestones
    the_bus:              { name:"THE BUS",              flav:"day 30. the bus came. you got on. it has a destination. it has not told you." },
    the_block_knows:      { name:"THE BLOCK KNOWS",      flav:"reach street LOVED. tony said your name three times today." },
    yuri_counts_you:      { name:"YURI COUNTS YOU IN",   flav:"reach scrap LOVED. pete wrote down a number. pete does not write down numbers." },
    mom_is_proud:         { name:"MOM IS PROUD",         flav:"reach spiritual LOVED. she told the women at trader joe's. they nodded." },
    // v13 wave 8a — world expansion achievements
    school_s_out:         { name:"SCHOOL'S OUT",         flav:"defeat old school brutus. the gym is quiet. the gym was loud." },
    bench_press:          { name:"BENCH PRESS",          flav:"sit on a park bench for 60 continuous seconds. the bench remembers." },
    the_price_paid:       { name:"THE PRICE PAID",       flav:"pay the price guy. you found out what the price was for." },
    train_hopped:         { name:"TRAIN HOPPED",         flav:"talk to the train hopper. you heard about bremerton. you didn't go." },
    route_five:           { name:"PAPERWORK",             flav:"file five block routes. the paper has accepted you." },
    route_twenty:         { name:"LAMINATED",             flav:"file twenty block routes. the clipboard has authority now." },
    route_fifty:          { name:"MUNICIPAL EMPLOYEE OF NOTHING", flav:"file fifty block routes. no department claims you." },
    squatters_rights:     { name:"SQUATTER'S RIGHTS",               flav:"acquire one office. no lease was harmed." },
    zoning_error:         { name:"ZONING ERROR",                    flav:"install the first district sign. the district did not sign." },
    regional_office:      { name:"REGIONAL OFFICE",                 flav:"enter four districts in pen." },
    middle_management:    { name:"MIDDLE MANAGEMENT",               flav:"enter eight districts. acquire no employees." },
    paper_everywhere:     { name:"PAPER EVERYWHERE",                 flav:"enter all eleven districts. the forms agree with themselves." },
    one_cracklord:        { name:"ONE CRACKLORD",                    flav:"remove the curb emperor. inherit one folding chair and every objection." },
  };
  
  // ---------- HUSTLES (daily objectives) ----------
  HUSTLE_TEMPLATES = [
    { id:'rocks_3',     desc:"smoke 3 rocks today.",        check:()=>P.lifetime.rocksSmoked - (state.hustleSnapshot?.rocksSmoked||0) >= 3, reward:{cash:15, cred:3}, key:'rocksSmoked' },
    { id:'copper_4',    desc:"strip 4 pure copper.",        check:()=>state.counters.copperStripped - (state.hustleSnapshot?.copperStripped||0) >= 4, reward:{cash:25, cred:2}, key:'copperStripped' },
    { id:'pawn_2',      desc:"sell 2 things to pete.",      check:()=>(state.counters.peteSold||0) - (state.hustleSnapshot?.peteSold||0) >= 2, reward:{cash:18}, key:'peteSold' },
    { id:'pan_5',       desc:"earn $4 in one panhandle.",   check:()=>(state.counters.bigPan||0) >= 1, reward:{cred:5}, key:'bigPan' },
    { id:'church_2',    desc:"donate at the church once.",  check:()=>(state.counters.churchDonations||0) - (state.hustleSnapshot?.churchDonations||0) >= 5, reward:{cash:12, cred:4}, key:'churchDonations' },
    { id:'fight_2',     desc:"defeat 2 alley crackheads.",  check:()=>(state.counters.alleyKills||0) - (state.hustleSnapshot?.alleyKills||0) >= 2, reward:{cash:20, cred:5}, key:'alleyKills' },
    { id:'dump_3',      desc:"dive 3 dumpsters.",           check:()=>(state.counters.dumpDives||0) - (state.hustleSnapshot?.dumpDives||0) >= 3, reward:{cash:15}, key:'dumpDives' },
    { id:'possum_1',    desc:"consult the possum.",         check:()=>(state.counters.possumProphecies||0) - (state.hustleSnapshot?.possumProphecies||0) >= 1, reward:{cred:3, brain:10}, key:'possumProphecies' },
    { id:'tony_2',      desc:"buy 2 rocks from tony.",      check:()=>(state.counters.rocksBought||0) - (state.hustleSnapshot?.rocksBought||0) >= 2, reward:{cash:8}, key:'rocksBought' },
    { id:'sleep_1',     desc:"sleep on the crate.",         check:()=>(state.counters.slept||0) - (state.hustleSnapshot?.slept||0) >= 1, reward:{cash:5, brain:5}, key:'slept' },
    { id:'eat_taco',    desc:"buy a taco from the truck.",  check:()=>(state.counters.tacosEaten||0) - (state.hustleSnapshot?.tacosEaten||0) >= 1, reward:{cash:8, cred:1}, key:'tacosEaten' },
    { id:'cook_2',      desc:"cook 2 rocks on the crate.",  check:()=>(P.lifetime.rocksCooked||0) - (state.hustleSnapshot?.rocksCooked||0) >= 2, reward:{cash:14, cred:2}, key:'rocksCooked' },
    { id:'fence_3',     desc:"sell 3 rocks to stripe.",     check:()=>(P.lifetime.rocksFenced||0) - (state.hustleSnapshot?.rocksFenced||0) >= 3, reward:{cash:12, cred:2}, key:'rocksFenced' },
    { id:'laundry_1',   desc:"do a load of laundry.",       check:()=>(state.counters.laundryDone||0) - (state.hustleSnapshot?.laundryDone||0) >= 1, reward:{cash:5, cred:1}, key:'laundryDone' },
  ];
  
  
  
  
  // ---------- v17 — ENDLESS BLOCK ROUTES ----------
  // Three authored public-landmark stamps. The route never depends on a living NPC,
  // inventory roll, rank gate, weather, or day counter; it remains completable forever.
  ROUTE_STOPS = [
    { id:'block_news',  x:900,  y:1010, zone:'the block', task:'check the news box for news.', stamp:'the box contains one coupon.\nyou file it as local news.' },
    { id:'scrap_gate',  x:360,  y:468,  zone:'scrap yard', task:'count the scrap gate. count it as two gates.', stamp:'one gate. two on the form.\nyuri will dispute this.' },
    { id:'pawn_sill',   x:390,  y:690,  zone:'pawn shop', task:'inspect pete\'s east wall for east.', stamp:'the wall faces east.\npete is still weighing it.' },
    { id:'under_sign',  x:1340, y:478,  zone:'underpass', task:'read the cardboard sign without learning math.', stamp:'the sign says math.\nyou retain none.' },
    { id:'corner_curb', x:1475, y:965,  zone:'dealer corner', task:'verify the curb remains owned by the curb.', stamp:'the curb declines comment.\nownership unchanged.' },
    { id:'bus_glass',   x:1285, y:1170, zone:'bus stop', task:'check the bus glass for a bus.', stamp:'glass. no bus.\nthe schedule agrees.' },
    { id:'laundry_sock',x:1788, y:1190, zone:'laundromat', task:'count one wet sock as inventory.', stamp:'one sock entered.\none sock refuses valuation.' },
    { id:'market_line', x:1120, y:1350, zone:'marketplace', task:'stand where the checkout line used to be.', stamp:'the line moves around you.\nyou were not in it.' },
    { id:'alley_can',   x:300,  y:1560, zone:'back alley', task:'ask the alley can about municipal pickup.', stamp:'the can says tuesday.\nit is approximately tuesday.' },
    { id:'church_step', x:1800, y:1592, zone:'church', task:'touch the church step. remove hand.', stamp:'hand removed.\nthe step keeps no record.' },
    { id:'project_meter',x:650, y:1810, zone:'projects', task:'read the broken meter at full confidence.', stamp:'the meter says 88.\nthere is no unit.' },
    { id:'train_signal',x:310,  y:2750, zone:'train yard', task:'confirm the train signal is thinking about it.', stamp:'red. still red.\nthe train remains theoretical.' },
    { id:'park_fountain',x:2700,y:1140, zone:'park', task:'listen to the fountain cough. write "operational."', stamp:'the fountain coughs twice.\noperational.' },
    { id:'skid_drain',  x:3315, y:1940, zone:'skid row', task:'verify the east storm drain remains below grade.', stamp:'the drain is still down there.\ngrade status: below.' },
    { id:'school_chain',x:3760, y:760,  zone:'old school', task:'check the old school chain for education.', stamp:'chain. rust. no curriculum.\ninspection complete.' },
    { id:'motel_no',    x:3025, y:1045, zone:'east service road', task:'read the motel vacancy sign backwards.', stamp:'on. letom.\nno vacancy information obtained.' },
    { id:'warehouse_manifest',x:4930,y:850,zone:'warehouse row',unlockFlag:'warehouseRowEntered',task:'compare the manifest to the building. trust neither.',stamp:'manifest says unit 14.\nbuilding says returns. filed as close.' },
    { id:'canal_gauge',x:5420,y:2070,zone:'drainage canal',unlockFlag:'canalEntered',task:'read the water gauge while the water is absent.',stamp:'gauge says nine.\nwater says nothing. nine entered.' },
    { id:'lot_meter',x:4440,y:3140,zone:'the lot',unlockFlag:'theLotEntered',task:'check the dead meter for office hours.',stamp:'meter expired in 2008.\nwalk-ins remain accepted.' },
    // v19 ids are appended and unlock only after that rival ruler is down.
    { id:'tarp_docket',x:6020,y:1180,zone:'blue tarp court',unlockFlag:'blueTarpCleared',task:'count the blue tarp as a permanent roof.',stamp:'one roof. four ropes.\npermanence entered as weather.' },
    { id:'cart_barrier',x:7440,y:2380,zone:'cart cavalry keep',unlockFlag:'cartKeepCleared',task:'check the cavalry parking brake.',stamp:'six carts. one brick.\nbrake status: brick.' },
    { id:'choir_register',x:7000,y:3760,zone:'copper choir yard',unlockFlag:'copperChoirCleared',task:'listen to the copper rack. file its note.',stamp:'b flat. again.\nnoise entered as inventory.' },
    { id:'ditch_gauge',x:7120,y:5240,zone:'throne ditch',unlockFlag:'throneDitchCleared',task:'measure the throne ditch from the dry side.',stamp:'ditch remains lower.\nthrone remains a chair.' },
  ];
  ROUTE_STOP_BY_ID = Object.create(null);
  for(const stop of ROUTE_STOPS)ROUTE_STOP_BY_ID[stop.id]=stop;
  
  
  
  
  
  
  
  
  // ---------- v17 — ONE CURRENT BAD IDEA ----------
  
}

export let OFFICE_DOOR, OFFICE_UPGRADE_DEFS, OFFICE_UPGRADE_IDS, CLAIM_SITES, CLAIM_SITE_BY_ID, CLAIM_STAGES, WORK_STAGES, KINGDOM_STAGES, KINGDOM_DEFEAT_IDS, KINGDOM_STAGE_RANK, KINGDOM_DOORS, KINGDOM_CLANS, KINGDOM_CLAN_LIST, KINGDOM_EMPEROR, KINGDOM_GUARD_POSTS, QUEST_TARGETS;

export function freshOfficeState(){
  const upgrades=Object.create(null);for(const id of OFFICE_UPGRADE_IDS)upgrades[id]=false;
  return {owned:false,upgrades,claimJob:null,workJob:null,workDay:0,workToday:0,jobsCompleted:0,orderSerial:0,rerollDay:0,lastWorkId:''};
}

export function normalizeDistrictClaims(raw){
  const out=Object.create(null);
  if(raw&&typeof raw==='object')for(const c of CLAIM_SITES)if(raw[c.id]===true)out[c.id]=true;
  return out;
}

export function officeNat(value,max=1000000000){
  const n=Number(value);return Number.isFinite(n)?Math.max(0,Math.min(max,Math.floor(n))):0;
}

export function normalizeOfficeState(raw,claims){
  const out=freshOfficeState(),r=raw&&typeof raw==='object'?raw:{};
  out.owned=!!r.owned;
  if(r.upgrades&&typeof r.upgrades==='object')for(const id of OFFICE_UPGRADE_IDS)out.upgrades[id]=r.upgrades[id]===true;
  const cj=r.claimJob;
  if(cj&&Object.hasOwn(CLAIM_SITE_BY_ID,cj.id)&&CLAIM_STAGES.has(cj.stage)&&!claims[cj.id])out.claimJob={id:cj.id,stage:cj.stage};
  const wj=r.workJob;
  if(wj&&Object.hasOwn(CLAIM_SITE_BY_ID,wj.id)&&WORK_STAGES.has(wj.stage)&&claims[wj.id])out.workJob={id:wj.id,stage:wj.stage,serial:Math.max(1,officeNat(wj.serial))};
  out.workDay=officeNat(r.workDay);
  out.workToday=officeNat(r.workToday,3);
  out.jobsCompleted=officeNat(r.jobsCompleted);
  out.orderSerial=Math.max(out.jobsCompleted,officeNat(r.orderSerial),out.workJob?out.workJob.serial:0);
  out.rerollDay=officeNat(r.rerollDay);
  out.lastWorkId=Object.hasOwn(CLAIM_SITE_BY_ID,r.lastWorkId)?r.lastWorkId:'';
  if(out.claimJob)out.workJob=null;
  // A valid upgrade, claim, or job is stronger recovery evidence than one missing owned bit.
  // This preserves legitimate progress from a partially-written save without granting anything
  // to a pre-v18 save, whose office payload and district ledger are both empty.
  if(!out.owned){
    const hasUpgrade=OFFICE_UPGRADE_DEFS.some(d=>out.upgrades[d.id]);
    out.owned=hasUpgrade||!!out.claimJob||!!out.workJob||out.jobsCompleted>0||CLAIM_SITES.some(d=>claims[d.id]);
  }
  if(out.claimJob||CLAIM_SITES.some(d=>claims[d.id]))out.upgrades.desk=true;
  if(out.workJob||out.jobsCompleted>0)out.upgrades.radio=true;
  if(!out.owned){out.workDay=0;out.workToday=0;out.orderSerial=0;out.rerollDay=0;out.lastWorkId='';}
  return out;
}

export function ensureOfficeState(){
  state.districtClaims=normalizeDistrictClaims(state.districtClaims);
  state.office=normalizeOfficeState(state.office,state.districtClaims);
  return state.office;
}

export function claimedDistrictIds(){
  const claims=state.districtClaims||{};return CLAIM_SITES.filter(c=>claims[c.id]===true).map(c=>c.id);
}

export function officeOwned(){return !!(state.office&&state.office.owned);}

export function activeOfficeContract(){const o=state.office;return !!(o&&(o.claimJob||o.workJob));}

export function officeDailyCap(){return Math.min(3,1+Math.floor(claimedDistrictIds().length/4));}

export function syncOfficeDay(){
  if(!state.office)ensureOfficeState();const o=state.office;if(o.workDay!==state.day){o.workDay=state.day;o.workToday=0;}
}

export function maybeUnlockOfficeQuest(persist=true){
  if(!state.flags||!state.flags.introDone||!state.quests||officeOwned())return false;
  const q=state.quests.office_space;if(!q||q.done||(P.lifetime.routesCompleted||0)<3)return false;
  if(q.available===false){
    q.available=true;
    toast('Â· NEW BAD IDEA Â·\nthe leasing guy has a unit.\nwalk-ins are somehow accepted.',3600);
    feedPost('three routes filed. a leasing guy has noticed.','@crackheadcent');
    if(persist)saveGame();return true;
  }
  return false;
}

export function claimGateReason(def){
  if(!def)return 'not on the form.';
  if((state.districtClaims||{})[def.id])return 'already entered in pen.';
  if(def.faction!=='neutral'&&(!P.faction||(P.faction[def.faction]||0)<10))return def.faction+' must be liked (+10).';
  return '';
}

export function updateOfficeMilestones(persist=true){
  const count=claimedDistrictIds().length;
  let changed=P.lifetime.territoriesClaimed!==count;
  P.lifetime.territoriesClaimed=count;
  const qs=state.quests||{};
  const first=count>=1&&qs.paper_empire&&!qs.paper_empire.done;
  const regional=count>=4&&qs.regional_office&&!qs.regional_office.done;
  const all=count>=CLAIM_SITES.length&&qs.all_business&&!qs.all_business.done;
  const setQuest=(q,key,value)=>{if(q&&q[key]!==value){q[key]=value;changed=true;}};
  // Finish every milestone mutation before one optional save, so no partial snapshot can
  // race the final claim transaction or leave partial-save repairs repeating forever.
  if(count>=1){setQuest(qs.paper_empire,'done',true);setQuest(qs.paper_empire,'available',true);setQuest(qs.regional_office,'available',true);}
  if(count>=4){setQuest(qs.regional_office,'done',true);setQuest(qs.regional_office,'available',true);setQuest(qs.all_business,'available',true);}
  if(count>=CLAIM_SITES.length){setQuest(qs.all_business,'done',true);setQuest(qs.all_business,'available',true);}
  if(first)questToast('PAPER EMPIRE');
  if(regional)questToast('REGIONAL OFFICE');
  if(all)questToast('ALL BUSINESS');
  const earned=[];
  if(count>=1)earned.push('zoning_error');
  if(count>=4)earned.push('regional_office');
  if(count>=8)earned.push('middle_management');
  if(count>=CLAIM_SITES.length)earned.push('paper_everywhere');
  const fresh=earned.filter(id=>ACHIEVEMENTS[id]&&!state.achievements.has(id));
  for(const id of fresh){state.achievements.add(id);changed=true;}
  if(fresh.length){
    const last=fresh[fresh.length-1];toast('· ACHIEVEMENT ·\n'+ACHIEVEMENTS[last].name+(fresh.length>1?'\n'+fresh.length+' office records reconciled.':''),3000);audio.rankUp();
  }
  if(changed&&persist)saveGame();
  return changed;
}

export function currentOfficeObjective(){
  if(!state.flags||!state.flags.introDone||!state.quests)return null;
  const o=state.office||freshOfficeState(),officeQ=state.quests.office_space,paperQ=state.quests.paper_empire;
  if(!o.owned&&officeQ&&!officeQ.done&&officeQ.available===true)return {kind:'office',text:'find the leasing guy in the lot.',x:5400,y:3100};
  if(o.claimJob){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id];
    if(o.claimJob.stage==='survey')return {kind:'office',text:'survey '+d.name.toLowerCase()+'. '+d.survey.task,x:d.survey.x,y:d.survey.y};
    if(o.claimJob.stage==='file')return {kind:'office',text:'return to the office and file '+d.name.toLowerCase()+'.',x:4920,y:3210};
    return {kind:'office',text:'install the claim sign. '+d.sign.task,x:d.sign.x,y:d.sign.y};
  }
  if(o.workJob){
    const d=CLAIM_SITE_BY_ID[o.workJob.id];
    return o.workJob.stage==='inspect'
      ? {kind:'office',text:'order '+o.workJob.serial+' Â· inspect the '+d.name.toLowerCase()+' sign.',x:d.sign.x,y:d.sign.y}
      : {kind:'office',text:'order '+o.workJob.serial+' Â· return to the office and file.',x:4920,y:3210};
  }
  if(o.owned&&paperQ&&!paperQ.done&&paperQ.available===true){
    return {kind:'office',text:o.upgrades&&o.upgrades.desk?'use the office desk. claim the drainage canal.':'put a desk in the office.',x:4920,y:3210};
  }
  return null;
}

export function selectDistrictClaim(id){
  const o=ensureOfficeState(),d=CLAIM_SITE_BY_ID[id];
  if(!o.owned||!o.upgrades.desk||o.claimJob||o.workJob||!d)return false;
  const why=claimGateReason(d);if(why){toast(why,1800);return false;}
  o.claimJob={id,stage:'survey'};
  toast('Â· CLAIM OPENED Â·\n'+d.name+'\nfirst: '+d.survey.task,3200);saveGame();return true;
}

export function cancelDistrictClaim(){
  const o=ensureOfficeState();if(!o.claimJob)return;
  const paid=o.claimJob.stage==='install';o.claimJob=null;
  toast(paid?'the form is canceled.\nthe filing fee is not.':'the form is canceled.\nno one had signed it.',2400);saveGame();
}

export function claimFileCost(){return 20+5*claimedDistrictIds().length;}

export function fileDistrictClaim(){
  const o=ensureOfficeState();if(!o.claimJob||o.claimJob.stage!=='file')return false;
  const cost=claimFileCost();if(P.cash<cost||P.copper<1){toast('filing needs $'+cost+' and 1 pure copper.\nthe desk cannot spot you.',2400);return false;}
  P.cash-=cost;P.copper--;o.claimJob.stage='install';audio.coin();
  const d=CLAIM_SITE_BY_ID[o.claimJob.id];toast('- $'+cost+' Â· - 1 copper\nform filed.\nnow install the sign at '+d.name.toLowerCase()+'.',3400);saveGame();return true;
}

export function tryUseOfficeFieldTarget(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return false;
  const o=state.office;if(!o)return false;const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  if(o.claimJob&&(o.claimJob.stage==='survey'||o.claimJob.stage==='install')){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],p=o.claimJob.stage==='survey'?d.survey:d.sign;
    const dx=pcx-p.x,dy=pcy-p.y;if(dx*dx+dy*dy>=58*58)return false;
    if(o.claimJob.stage==='survey'){
      o.claimJob.stage='file';audio.coin();toast(p.stamp+'\nreturn to the office. the desk wants money.',3000);saveGame();return true;
    }
    state.districtClaims[d.id]=true;o.claimJob=null;P.cred+=2;updateOfficeMilestones(false);maybeUnlockKingdom(false,true);audio.rankUp();
    toast(p.stamp+'\nÂ· DISTRICT ENTERED Â·  + 2 cred\n'+d.name,3800);feedPost('installed a sign at '+d.name.toLowerCase()+'. the sign has standing.','@crackheadcent');saveGame();return true;
  }
  if(o.workJob&&o.workJob.stage==='inspect'){
    const d=CLAIM_SITE_BY_ID[o.workJob.id],p=d.sign,dx=pcx-p.x,dy=pcy-p.y;
    if(dx*dx+dy*dy>=58*58)return false;
    o.workJob.stage='file';audio.coin();toast('sign inspected.\nit is still leaning.\nreturn to the office.',2600);saveGame();return true;
  }
  return false;
}

export function startOfficeWork(){
  const o=ensureOfficeState();syncOfficeDay();const owned=claimedDistrictIds();
  if(!o.upgrades.radio||!owned.length||o.claimJob||o.workJob||o.workToday>=officeDailyCap())return false;
  let pool=owned.filter(id=>id!==o.lastWorkId);if(!pool.length)pool=owned.slice();
  const id=pool[Math.floor(Math.random()*pool.length)];o.orderSerial++;o.workJob={id,stage:'inspect',serial:o.orderSerial};o.lastWorkId=id;
  const d=CLAIM_SITE_BY_ID[id];toast('Â· WORK ORDER '+o.orderSerial+' Â·\ninspect the sign at '+d.name.toLowerCase()+'.\nbring the condition back.',3200);saveGame();return true;
}

export function fileOfficeWork(){
  const o=ensureOfficeState();syncOfficeDay();if(!o.workJob||o.workJob.stage!=='file')return false;
  if(o.workToday>=officeDailyCap()){toast('the daily ledger is closed.\nthe inspected order waits for morning.',2200);return false;}
  const count=claimedDistrictIds().length,pay=Math.min(12,5+count);o.jobsCompleted++;o.workToday++;
  P.lifetime.officeJobs=o.jobsCompleted;P.cash+=pay;const cred=o.jobsCompleted%5===0?1:0;if(cred)P.cred++;
  const serial=o.workJob.serial;o.workJob=null;audio.coin();
  toast('Â· ORDER '+serial+' FILED Â·\ngross $'+(pay+17)+'. chair rental $17.\nnet + $'+pay+(cred?' Â· + 1 cred':''),3600);saveGame();return true;
}

export function purchaseOfficeUpgrade(id){
  const o=ensureOfficeState(),d=OFFICE_UPGRADE_DEFS.find(x=>x.id===id);if(!o.owned||!d||o.upgrades[id])return false;
  if(P.cash<d.cash||P.copper<d.copper){toast(d.name+' needs $'+d.cash+(d.copper?' and '+d.copper+' pure copper':'')+'.\nthe office does not extend credit.',2200);return false;}
  P.cash-=d.cash;P.copper-=d.copper;o.upgrades[id]=true;audio.rankUp();toast('Â· OFFICE UPGRADE Â·\n'+d.name+' installed.\n'+d.desc,3000);saveGame();return true;
}

export function purchaseOffice(){
  const o=ensureOfficeState();if(o.owned)return false;
  if((P.lifetime.routesCompleted||0)<3||P.cash<40||P.copper<1){toast('the key needs three filed routes, $40, and 1 pure copper.',2400);return false;}
  P.cash-=40;P.copper--;o.owned=true;
  const q=state.quests.office_space;if(q){q.done=true;q.available=true;questToast('THE OFFICE');}
  if(state.quests.paper_empire)state.quests.paper_empire.available=true;
  unlockAchievement('squatters_rights');audio.rankUp();toast('- $40 Â· - 1 copper\n+ one key\nthe office is yours in the sense that no one stopped you.',4200);feedPost('acquired an office. the office was surprised.','@crackheadcent');saveGame();return true;
}

export function leaseGuyDialogue(){
  const o=ensureOfficeState(),routes=P.lifetime.routesCompleted||0;
  if(o.owned){dialogue('THE LEASING GUY','he checks the key ring.\none key is missing.\nhe knows which key.',[{label:'ask about the lease.',action:()=>toast('there is no lease.\nhe says this like a feature.')},{label:'leave.',action:()=>{}}]);return;}
  const ready=routes>=3,PAY=P.cash>=40&&P.copper>=1;
  dialogue('THE LEASING GUY',ready?'he has a key on a fishhook.\nthe unit says TAX HELP.\nthere is no tax help.':'he has a key on a fishhook.\nhe wants three route sheets before he knows your name.\nhe does not want your name.',[
    {label:ready?(PAY?'replace the lock. $40 + 1 pure copper.':'need $40 and 1 pure copper.'):'file three block routes first. ('+routes+'/3)',disabled:!ready||!PAY,action:purchaseOffice},
    {label:'ask what the unit includes.',action:()=>toast('four walls.\none door.\na smell with seniority.')},
    {label:'leave.',action:()=>{}},
  ]);
}

export function gutterGregDialogue(){
  const done=(state.counters.gutterInventoryDay||0)===state.day;
  dialogue('GUTTER GREG','greg is guarding a rubber duck.\nthe duck is in the municipal inventory.\nthe municipality has not been told.',[
    {label:done?'count inventory. (already counted today.)':'count the canal inventory. (+1 scrap)',disabled:done,action:()=>{state.counters.gutterInventoryDay=state.day;adjustFaction('scrap',1);toast('duck: one.\ncart parts: uncertain.\n+ 1 scrap',2400);saveGame();}},
    {label:'ask where the water went.',action:()=>toast('greg points downstream.\nthere is no downstream on the form.')},
    {label:'leave.',action:()=>{}},
  ]);
}

export function freshKingdomState(){
  return {stage:'locked',marks:0,bossId:'',defeats:[],pretenderDay:0,pretenderDefeatedDay:0,pretendersDefeated:0};
}

export function normalizeKingdomState(raw,demoteBoss=false){
  const r=raw&&typeof raw==='object'?raw:{},out=freshKingdomState();
  out.stage=KINGDOM_STAGES.has(r.stage)?r.stage:'locked';
  out.marks=officeNat(r.marks,7);
  if(Array.isArray(r.defeats))for(const id of KINGDOM_DEFEAT_IDS)if(r.defeats.includes(id))out.defeats.push(id);
  out.pretenderDay=officeNat(r.pretenderDay);
  out.pretenderDefeatedDay=officeNat(r.pretenderDefeatedDay);
  out.pretendersDefeated=officeNat(r.pretendersDefeated);
  out.bossId='';
  // Spawned combatants are ephemeral. A loaded fight becomes a full-HP retry at its banner.
  if(demoteBoss&&out.stage==='tarp_boss'){out.stage='tarp_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='cart_boss'){out.stage='cart_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='wire_boss'){out.stage='wire_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='emperor_boss'){out.stage='emperor_gate';out.marks=0;out.bossId='';}
  // A durable defeat is stronger than a stale earlier stage. Advance to the first unpaid
  // hearing before deriving the prerequisite prefix; repair never grants its reward again.
  let rank=KINGDOM_STAGE_RANK[out.stage]||0;
  if(out.defeats.includes('curb_emperor'))out.stage='complete';
  else if(out.defeats.includes('bishop_wire')&&rank<KINGDOM_STAGE_RANK.anoint)out.stage='anoint';
  else if(out.defeats.includes('general_receipt')&&rank<KINGDOM_STAGE_RANK.wire_marks)out.stage='wire_marks';
  else if(out.defeats.includes('darryl_under_blue')&&rank<KINGDOM_STAGE_RANK.cart_marks)out.stage='cart_marks';
  // Later durable stages witness prerequisite victories without replaying their rewards.
  rank=KINGDOM_STAGE_RANK[out.stage]||0;
  if(rank>=KINGDOM_STAGE_RANK.cart_marks&&!out.defeats.includes('darryl_under_blue'))out.defeats.push('darryl_under_blue');
  if(rank>=KINGDOM_STAGE_RANK.wire_marks&&!out.defeats.includes('general_receipt'))out.defeats.push('general_receipt');
  if(rank>=KINGDOM_STAGE_RANK.anoint&&!out.defeats.includes('bishop_wire'))out.defeats.push('bishop_wire');
  if(out.stage==='complete'&&!out.defeats.includes('curb_emperor'))out.defeats.push('curb_emperor');
  out.defeats=KINGDOM_DEFEAT_IDS.filter(id=>out.defeats.includes(id));
  if(!['tarp_marks','cart_marks','wire_marks'].includes(out.stage))out.marks=0;
  const expectedBoss={tarp_boss:'darryl_under_blue',cart_boss:'general_receipt',wire_boss:'bishop_wire',emperor_boss:'curb_emperor'}[out.stage]||'';
  if(!demoteBoss&&expectedBoss&&r.bossId===expectedBoss)out.bossId=expectedBoss;
  return out;
}

export function ensureKingdomState(){
  state.kingdom=normalizeKingdomState(state.kingdom);
  P.lifetime.pretendersDefeated=Math.max(officeNat(P.lifetime.pretendersDefeated),state.kingdom.pretendersDefeated);
  state.kingdom.pretendersDefeated=P.lifetime.pretendersDefeated;
  return state.kingdom;
}

export function kingdomEligible(){
  return officeOwned()&&claimedDistrictIds().length>=4&&!!(state.quests&&state.quests.fallen_king&&state.quests.fallen_king.done);
}

export function maybeUnlockKingdom(persist=true,announce=true){
  const k=ensureKingdomState();if(k.stage!=='locked'||!kingdomEligible())return false;
  k.stage='summons';k.marks=0;
  if(state.quests&&state.quests.hostile_correspondence)state.quests.hostile_correspondence.available=true;
  if(announce){
    toast('· HOSTILE CORRESPONDENCE ·\na radio frequency has billed your curb.\nthe office has the envelope.',4200);
    feedPost('regional office received a kingdom notice. postage due.','@blocklog');
  }
  if(persist)saveGame();return true;
}

export function kingdomStageClan(stage=(state.kingdom&&state.kingdom.stage)){
  return KINGDOM_CLAN_LIST.find(c=>c.marksStage===stage||c.bossStage===stage)||null;
}

export function syncKingdomQuests(){
  if(!state.quests)return;const k=state.kingdom||freshKingdomState(),rank=KINGDOM_STAGE_RANK[k.stage]||0,def=new Set(k.defeats||[]);
  const set=(id,available,done)=>{const q=state.quests[id];if(q){q.available=!!available;q.done=!!done;}};
  set('hostile_correspondence',rank>=1,rank>=2);
  set('blue_weather',rank>=2,def.has('darryl_under_blue'));
  set('cart_appeal',rank>=4,def.has('general_receipt'));
  set('copper_mass',rank>=6,def.has('bishop_wire'));
  set('royal_static',rank>=8,rank>=9);
  set('one_cracklord',rank>=9,k.stage==='complete');
}

export function currentKingdomObjective(){
  const k=state.kingdom;if(!k)return null;
  if(k.stage==='locked'){
    const fallen=state.quests&&state.quests.fallen_king;
    if(officeOwned()&&claimedDistrictIds().length>=4&&fallen&&!fallen.done&&fallen.available!==false){
      return {kind:'kingdom',text:'settle the corner with tre bag tony. the regional envelope needs one local vacancy.',x:1634,y:886};
    }
    return null;
  }
  if(k.stage==='summons'){
    const radio=state.office&&state.office.upgrades&&state.office.upgrades.radio;
    return {kind:'kingdom',text:radio?'answer the hostile radio summons at the office.':'install the office radio. hostile postage is waiting.',x:4920,y:3210};
  }
  const clan=kingdomStageClan(k.stage);
  if(clan){
    if(k.stage===clan.bossStage){
      const b=runtime.npcs.find(n=>n.kingdomBoss&&n.id===clan.bossId&&!n.dead);
      return {kind:'kingdom',text:'defeat '+clan.bossName.toLowerCase()+'. his court has no appeals.',x:b?b.x+b.w/2:clan.boss.x,y:b?b.y+b.h/2:clan.boss.y};
    }
    if(k.marks===7)return {kind:'kingdom',text:'challenge '+clan.bossName.toLowerCase()+' at the court banner.',x:clan.banner.x,y:clan.banner.y};
    const idx=[0,1,2].find(i=>(k.marks&(1<<i))===0),m=clan.marks[idx];
    return {kind:'kingdom',text:clan.name.toLowerCase()+' · '+(bitCount3(k.marks))+'/3 · '+m.task,x:m.x,y:m.y};
  }
  if(k.stage==='anoint')return {kind:'kingdom',text:'smoke one real rock at the block. the crown requires bad reception.',x:1064,y:882};
  if(k.stage==='emperor_gate')return {kind:'kingdom',text:'challenge the curb emperor in the throne ditch.',x:KINGDOM_EMPEROR.banner.x,y:KINGDOM_EMPEROR.banner.y};
  if(k.stage==='emperor_boss'){
    const b=runtime.npcs.find(n=>n.kingdomBoss&&n.id==='curb_emperor'&&!n.dead);
    return {kind:'kingdom',text:'defeat the curb emperor. measure nothing.',x:b?b.x+b.w/2:KINGDOM_EMPEROR.boss.x,y:b?b.y+b.h/2:KINGDOM_EMPEROR.boss.y};
  }
  if(k.stage==='complete'){
    const p=runtime.npcs.find(n=>n.kingdomPretender&&!n.dead);
    if(p)return {kind:'pretender',text:'today\'s curb pretender has filed in person.',x:p.x+p.w/2,y:p.y+p.h/2};
  }
  return null;
}

export function resolveKingdomActionHint(){
  const k=state.kingdom;if(!k)return '';const pcx=P.x+P.w/2,pcy=P.y+P.h/2,clan=kingdomStageClan(k.stage);
  if(clan&&k.stage===clan.marksStage){
    for(let i=0;i<clan.marks.length;i++){if(k.marks&(1<<i))continue;const m=clan.marks[i],dx=pcx-m.x,dy=pcy-m.y;if(dx*dx+dy*dy<58*58)return 'serve the curb correction';}
    if(k.marks===7){const dx=pcx-clan.banner.x,dy=pcy-clan.banner.y;if(dx*dx+dy*dy<72*72)return 'challenge '+clan.bossName.toLowerCase();}
  }
  if(k.stage==='emperor_gate'){const dx=pcx-KINGDOM_EMPEROR.banner.x,dy=pcy-KINGDOM_EMPEROR.banner.y;if(dx*dx+dy*dy<72*72)return 'challenge the curb emperor';}
  return '';
}

export function bitCount3(v){v=officeNat(v,7);return (v&1?1:0)+(v&2?1:0)+(v&4?1:0);}

export function tryKingdomDoor(){
  const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  for(const d of KINGDOM_DOORS){const dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44){toast(d.line,2200);return true;}}
  return false;
}

export function acceptKingdomSummons(){
  const k=ensureKingdomState(),o=ensureOfficeState();if(k.stage!=='summons'||!o.upgrades.radio)return false;
  k.stage='tarp_marks';k.marks=0;
  syncKingdomQuests();audio.radio();
  toast('· CURB WAR OPEN ·\nblue tarp court disputes your weather.\nserve three corrections.',4200);
  broadcastNews('SUCCESSION NOTICE FILED. THREE COURTS OBJECT. ONE DITCH IS LISTENING.');
  feedPost('answered the radio. blue tarp court says the sky belongs to a rope.','@crackheadcent');
  saveGame();return true;
}

export function openKingdomLedger(){
  const k=ensureKingdomState(),o=ensureOfficeState();
  if(k.stage==='summons'){
    dialogue('HOSTILE CORRESPONDENCE','the envelope says OCCUPANT / REGARDING KINGDOM.\nthe return address is a tarp tied to a fence.',[
      {label:o.upgrades.radio?'answer the frequency.':'install the radio first.',disabled:!o.upgrades.radio,action:acceptKingdomSummons},
      {label:'leave it under the stapler.',action:()=>{}},
    ]);return;
  }
  const obj=currentKingdomObjective(),seals=(k.defeats||[]).filter(id=>id!=='curb_emperor').length;
  syncOfficeDay();const claims=claimedDistrictIds().length,cap=officeDailyCap();
  const workLabel=!o.upgrades.radio?'work orders need a radio.'
    :o.workJob?'work order '+o.workJob.serial+' is '+o.workJob.stage+'.'
    :!claims?'work orders need one claimed district.'
    :o.workToday>=cap?'work orders closed today. ('+o.workToday+'/'+cap+')'
    :'take a work order. ('+o.workToday+'/'+cap+' filed today)';
  const opts=[
    {label:'read the succession clause.',action:()=>toast('one curb. one ruler.\nall measurements final.\nno ruler has supplied a ruler.',3000)},
    {label:workLabel,disabled:!o.upgrades.radio||!!o.workJob||!!o.claimJob||!claims||o.workToday>=cap,action:()=>{startOfficeWork();}},
    {label:'back to the office.',action:()=>openOffice()},
  ];
  dialogue('CURB WAR LEDGER',(obj?obj.text:'the chair remains occupied.')+'\n\nseals entered: '+seals+'/3\npretenders removed: '+(k.pretendersDefeated||0),opts);
}

export function tryUseKingdomTarget(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return false;
  const k=ensureKingdomState(),pcx=P.x+P.w/2,pcy=P.y+P.h/2,clan=kingdomStageClan(k.stage);
  if(clan&&k.stage===clan.marksStage){
    for(let i=0;i<clan.marks.length;i++){
      if(k.marks&(1<<i))continue;const m=clan.marks[i],dx=pcx-m.x,dy=pcy-m.y;
      if(dx*dx+dy*dy<58*58){k.marks|=(1<<i);audio.coin();toast(m.stamp+'\n['+bitCount3(k.marks)+'/3 corrections served]',3000);if(k.marks===7)toast('all three corrections entered.\n'+clan.bossName.toLowerCase()+' is accepting one appeal.',3600);saveGame();return true;}
    }
    if(k.marks===7){const dx=pcx-clan.banner.x,dy=pcy-clan.banner.y;if(dx*dx+dy*dy<72*72)return startKingdomBoss(clan.id);}
  }
  if(k.stage==='emperor_gate'){
    const dx=pcx-KINGDOM_EMPEROR.banner.x,dy=pcy-KINGDOM_EMPEROR.banner.y;
    if(dx*dx+dy*dy<72*72)return startKingdomBoss('emperor');
  }
  return false;
}

export function makeKingdomActor(def,at,extra={}){
  return {id:extra.id||('kingdom_'+Math.random().toString(36).slice(2,9)),name:extra.name||def.guardName,sprite:extra.sprite||def.guardSprite,
    x:at.x-16,y:at.y-16,w:32,h:32,color:'#3a3028',hp:extra.hp||55,maxHp:extra.hp||55,speed:extra.speed||1.35,dmg:extra.dmg||7,
    hostile:true,aggro:extra.aggro===true,showHp:!!extra.showHp,archetype:extra.archetype||'charger',attackCd:0,wanderT:0,targetX:at.x,targetY:at.y,
    zoneOnly:def.zoneOnly,kingdomClan:def.id||extra.kingdomClan,transient:true,noComboReward:true,...extra};
}

export function startKingdomBoss(id){
  const k=ensureKingdomState();if(state.bossActive||state.brutusOlderActive)return false;
  const emperor=id==='emperor',def=emperor?KINGDOM_EMPEROR:KINGDOM_CLANS[id];if(!def)return false;
  if(emperor?k.stage!=='emperor_gate':(k.stage!==def.marksStage||k.marks!==7))return false;
  const boss=makeKingdomActor(def,def.boss,{id:def.bossId,name:def.bossName,sprite:def.bossSprite,hp:def.bossHp,dmg:def.bossDmg,speed:def.bossSpeed,archetype:def.archetype,showHp:true,aggro:true,kingdomBoss:true,kingdomClan:emperor?'throne':def.id,kingdomPhase:1});
  if(!boss)return false;
  runtime.npcs=runtime.npcs.filter(n=>!(n.kingdomGuard&&(emperor?n.kingdomClan==='throne':n.kingdomClan===def.id)));
  runtime.npcs.push(boss);
  const addSprite=emperor?['blue_tarp_guard','receipt_guard']:null;
  def.adds.forEach((at,i)=>runtime.npcs.push(makeKingdomActor(def,at,{id:'kingdom_add_'+def.bossId+'_'+i,name:emperor?'CURB HOLDOUT':def.guardName,sprite:addSprite?addSprite[i%addSprite.length]:def.guardSprite,hp:45,dmg:6,speed:1.35,archetype:i?'swarmer':'charger',aggro:true,kingdomAdd:true,kingdomClan:emperor?'throne':def.id})));
  k.stage=emperor?'emperor_boss':def.bossStage;k.bossId=def.bossId;
  state.kingdomBattle={id:def.bossId,zoneId:def.zoneId,escapeT:0};state.bossActive=true;state.bossKind='kingdom';state.bossPhase=1;state.bossNPC=boss;
  audio.bossRoar();state.shake=10;
  toast(emperor?'the curb emperor stands from the chair.\nthe chair keeps the title.':def.bossName.toLowerCase()+' accepts the appeal.\ntwo clerks stand with him.',4000);
  saveGame();return true;
}

export function clearKingdomBossGlobals(){
  state.bossActive=false;state.bossKind='';state.bossPhase=0;state.bossNPC=null;state.kingdomBattle=null;
  if(state.kingdom)state.kingdom.bossId='';
}

export function abortKingdomFight(show=false){
  if(state.bossKind!=='kingdom'&&!state.kingdomBattle)return false;
  const k=ensureKingdomState();
  if(k.stage==='tarp_boss'){k.stage='tarp_marks';k.marks=7;}
  else if(k.stage==='cart_boss'){k.stage='cart_marks';k.marks=7;}
  else if(k.stage==='wire_boss'){k.stage='wire_marks';k.marks=7;}
  else if(k.stage==='emperor_boss'){k.stage='emperor_gate';k.marks=0;}
  const doomed=new Set(runtime.npcs.filter(n=>n.kingdomBoss||n.kingdomAdd).map(n=>n.id));
  runtime.npcs=runtime.npcs.filter(n=>!n.kingdomBoss&&!n.kingdomAdd);
  runtime.projectiles=runtime.projectiles.filter(p=>!(p.from&&(p.from.kingdomBoss||p.from.kingdomAdd||doomed.has(p.from.id))));
  clearKingdomBossGlobals();syncKingdomQuests();
  if(show)toast('the appeal is recessed.\nall three corrections remain entered.\nfull hearing available.',2800);
  return true;
}

export function completeKingdomBoss(n){
  const k=ensureKingdomState();if(!n||!n.kingdomBoss||k.bossId!==n.id||state.bossKind!=='kingdom')return false;
  const emperor=n.id==='curb_emperor',clan=emperor?null:KINGDOM_CLAN_LIST.find(c=>c.bossId===n.id);
  if(!emperor&&(!clan||k.stage!==clan.bossStage))return false;
  if(emperor&&k.stage!=='emperor_boss')return false;
  if(k.defeats.includes(n.id))return false;
  k.defeats.push(n.id);P.cash+=emperor?KINGDOM_EMPEROR.rewardCash:clan.rewardCash;P.cred+=emperor?KINGDOM_EMPEROR.rewardCred:clan.rewardCred;
  runtime.npcs=runtime.npcs.filter(x=>!x.kingdomAdd&&x!==n);runtime.projectiles=runtime.projectiles.filter(p=>!(p.from&&(p.from.kingdomBoss||p.from.kingdomAdd)));
  clearKingdomBossGlobals();
  if(!emperor){
    k.stage=clan.nextStage;k.marks=0;state.flags[clan.clearFlag]=true;
    const questName=clan.id==='blue_tarp'?'BLUE WEATHER':clan.id==='cart_cavalry'?'CART APPEAL':'COPPER MASS';
    questToast(questName);audio.rankUp();
    toast('· '+clan.seal+' ENTERED ·\n+ $'+clan.rewardCash+' · + '+clan.rewardCred+' cred\n'+clan.name.toLowerCase()+' retains two objectors.',4400);
    feedPost(clan.bossName.toLowerCase()+' is down. the seal is bent but legible.','@blocklog');
    syncKingdomQuests();syncKingdomForces();saveGame();return true;
  }
  k.stage='complete';k.marks=0;k.pretenderDefeatedDay=state.day;state.flags.throneDitchCleared=true;
  P.lifetime.pretendersDefeated=k.pretendersDefeated;
  if(state.quests&&state.quests.one_cracklord){state.quests.one_cracklord.available=true;state.quests.one_cracklord.done=true;}
  if(ACHIEVEMENTS.one_cracklord)unlockAchievement('one_cracklord');
  syncKingdomQuests();syncKingdomForces();audio.rankUp();
  toast('· ONE CRACKLORD ·\n+ $60 · + 40 cred\nthe throne remains a folding chair.',4800);
  saveGame();setTimeout(()=>endingScreen('kingdom'),2600);return true;
}

export function updateKingdomBattle(dt){
  if(state.bossKind!=='kingdom'||!state.bossNPC||state.bossNPC.dead)return;
  const b=state.bossNPC,battle=state.kingdomBattle,z=ZONES.find(x=>x.id===(battle&&battle.zoneId));if(!z)return;
  const cx=P.x+P.w/2,cy=P.y+P.h/2,inside=cx>=z.x&&cx<=z.x+z.w&&cy>=z.y&&cy<=z.y+z.h;
  battle.escapeT=inside?0:(battle.escapeT||0)+dt;
  if(battle.escapeT>5000){abortKingdomFight(true);syncKingdomForces();saveGame();return;}
  if(b.id==='curb_emperor'){
    const pct=b.hp/b.maxHp;
    if(pct<.66&&b.kingdomPhase===1){b.kingdomPhase=2;b.archetype='ranged';b.speed=1.2;toast('the emperor cites the curb from a distance.\nthe citation is airborne.',2400);}
    else if(pct<.33&&b.kingdomPhase===2){b.kingdomPhase=3;b.archetype='charger';b.berserk=true;b.speed=2.6;b.dmg=15;toast('the emperor breaks the ruler.\nmeasurement is now personal.',2600);audio.bossRoar();}
  }
}

export function syncKingdomForces(){
  if(!Array.isArray(runtime.npcs))return;const k=ensureKingdomState();
  runtime.npcs=runtime.npcs.filter(n=>!n.kingdomGuard&&!n.kingdomPretender);
  const defeated=new Set(k.defeats||[]);
  for(const clan of KINGDOM_CLAN_LIST){
    if(k.stage===clan.bossStage)continue;const posts=KINGDOM_GUARD_POSTS[clan.id],count=defeated.has(clan.bossId)?2:4;
    for(let i=0;i<count;i++)runtime.npcs.push(makeKingdomActor(clan,posts[i],{id:'kingdom_guard_'+clan.id+'_'+state.day+'_'+i,name:clan.guardName,sprite:clan.guardSprite,hp:defeated.has(clan.bossId)?48:58,dmg:7,speed:1.25,archetype:i%3===2?'ranged':i%2?'swarmer':'charger',kingdomGuard:true,transient:false}));
  }
  if(k.stage!=='emperor_boss'){
    const count=k.stage==='complete'?2:3,posts=KINGDOM_GUARD_POSTS.throne,sprites=['blue_tarp_guard','receipt_guard','wire_guard'];
    for(let i=0;i<count;i++)runtime.npcs.push(makeKingdomActor({id:'throne',guardName:'CURB HOLDOUT',guardSprite:sprites[i%3],zoneOnly:KINGDOM_EMPEROR.zoneOnly},posts[i],{id:'kingdom_guard_throne_'+state.day+'_'+i,name:'CURB HOLDOUT',sprite:sprites[i%3],hp:52,dmg:7,speed:1.25,archetype:i===2?'ranged':'charger',kingdomGuard:true,kingdomClan:'throne',transient:false}));
  }
  spawnDailyPretender();
}

export function spawnDailyPretender(){
  const k=state.kingdom;if(!k||k.stage!=='complete'||k.pretenderDefeatedDay===state.day||runtime.npcs.some(n=>n.kingdomPretender&&!n.dead))return null;
  const defs=KINGDOM_CLAN_LIST,index=state.day%defs.length,def=defs[index],at=def.boss;
  k.pretenderDay=state.day;
  const p=makeKingdomActor(def,at,{id:'curb_pretender_'+state.day,name:'CURB PRETENDER No. '+(k.pretendersDefeated+1),sprite:def.guardSprite,hp:100,dmg:9,speed:1.45,archetype:index===2?'ranged':index===1?'grabber':'charger',showHp:true,kingdomPretender:true,kingdomClan:def.id,transient:false});
  runtime.npcs.push(p);return p;
}

export function completeKingdomPretender(n){
  const k=ensureKingdomState();if(!n||!n.kingdomPretender||k.stage!=='complete'||k.pretenderDefeatedDay===state.day)return false;
  k.pretenderDefeatedDay=state.day;k.pretendersDefeated++;P.lifetime.pretendersDefeated=k.pretendersDefeated;P.cash+=10;P.cred+=2;
  toast('· PRETENDER DENIED ·\n+ $10 · + 2 cred\nfiling '+k.pretendersDefeated+' remains nonprecedential.',3400);feedPost('today\'s curb pretender withdrew in person.','@blocklog');saveGame();return true;
}

export function currentPrimaryObjective() {
  const flags=state.flags||{}, qs=state.quests||{};
  if(!flags.introDone){
    if(qs.intro_remember&&!qs.intro_remember.done){
      const pile=runtime.cashPiles.find(c=>c.intro&&!c.collected);
      const earned=(state.counters&&state.counters.introCashEarned)||0;
      return {kind:'intro',text:'find $10 on the block. $'+Math.min(10,earned)+'/10',x:pile?pile.x:1180,y:pile?pile.y:870};
    }
    if((qs.intro_tony&&!qs.intro_tony.done)||((P.rocks||0)+(P.soapRocks||0))<=0){
      return {kind:'intro',text:qs.intro_tony&&qs.intro_tony.done?'buy a rock from tony. talking did not count.':'bother the man at the corner.',x:1634,y:886};
    }
    return {kind:'intro',text:'take the rock back to the milk crate.',x:1064,y:882};
  }
  const officeObjective=currentOfficeObjective();
  if(activeOfficeContract()&&officeObjective)return officeObjective;
  const kingdomObjective=currentKingdomObjective();
  if(kingdomObjective)return kingdomObjective;
  if(officeObjective)return officeObjective;
  const stop=currentBlockRouteStop();
  if(stop){
    const r=state.blockRoute;
    return {kind:'route',text:'route '+r.serial+' · '+(r.cursor+1)+'/3 · '+stop.task,x:stop.x,y:stop.y};
  }
  for(const [id,q] of Object.entries(qs)){
    if(q.done||q.available===false||q.intro)continue;
    if(id==='pigeon_crown'&&state.crownPickup&&!state.crownPickup.collected){
      return {kind:'quest',text:q.flav,x:state.crownPickup.x,y:state.crownPickup.y};
    }
    const target=QUEST_TARGETS[id]; if(target)return {kind:'quest',...target};
  }
  return {kind:'idle',text:'walk until the neighborhood assigns something.',x:P.x+P.w/2,y:P.y+P.h/2};
}

export function objectiveDirection(dx,dy){
  if(Math.abs(dx)<24&&Math.abs(dy)<24)return 'HERE';
  const a=Math.atan2(dy,dx),oct=Math.round(a/(Math.PI/4));
  return ['→','↘','↓','↙','←','↖','↑','↗','→'][(oct+8)%8];
}

export function resolveActionHint(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return '';
  const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  {const d=OFFICE_DOOR,dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return officeOwned()?'open the office':'test the office key';}
  for(const kind of ['scrap','mom']){
    if(!hideoutOwned(kind))continue;const d=HIDEOUT_DOORS[kind],dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);
    if(dx*dx+dy*dy<40*40)return kind==='mom'?"open mom's door":'open the shed';
  }
  {const d=OLD_SCHOOL_DOOR,dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return 'test the old school chain';}
  for(const d of KINGDOM_DOORS){const dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return 'read the court door';}
  const kingdomHint=resolveKingdomActionHint();if(kingdomHint)return kingdomHint;
  const office=state.office;
  if(office&&office.claimJob&&(office.claimJob.stage==='survey'||office.claimJob.stage==='install')){
    const def=CLAIM_SITE_BY_ID[office.claimJob.id],p=office.claimJob.stage==='survey'?def.survey:def.sign,dx=pcx-p.x,dy=pcy-p.y;
    if(dx*dx+dy*dy<58*58)return office.claimJob.stage==='survey'?'survey the district':'install the claim sign';
  }
  if(office&&office.workJob&&office.workJob.stage==='inspect'){
    const p=CLAIM_SITE_BY_ID[office.workJob.id].sign,dx=pcx-p.x,dy=pcy-p.y;if(dx*dx+dy*dy<58*58)return 'inspect the claim sign';
  }
  const routeStop=currentBlockRouteStop();
  if(routeStop&&!activeOfficeContract()){const dx=pcx-routeStop.x,dy=pcy-routeStop.y;if(dx*dx+dy*dy<58*58)return 'stamp the clipboard';}
  let best=null,bestD=60*60;
  for(const n of runtime.npcs){if(n.dead||!n.interact)continue;const dx=pcx-(n.x+n.w/2),dy=pcy-(n.y+n.h/2),d=dx*dx+dy*dy;if(d<bestD){bestD=d;best=n;}}
  if(best)return 'bother '+String(best.name||'somebody').toLowerCase();
  const heistB=BUILDINGS.find(b=>b.locked);
  if(heistB&&pcx>heistB.x-20&&pcx<heistB.x+heistB.w+20&&pcy>heistB.y-20&&pcy<heistB.y+heistB.h+20)return 'test the abandoned boards';
  for(const p of PROPS){if(p.type!=='park_bench')continue;const dx=pcx-(p.x+p.w/2),dy=pcy-(p.y+p.h/2);if(dx*dx+dy*dy<50*50)return state.sittingOnBench?'stand up':'sit on the bench';}
  for(const ip of interactiveProps){if(ip.type!=='trashcan')continue;const dx=pcx-ip.x,dy=pcy-ip.y;if(dx*dx+dy*dy<50*50)return 'kick the can';}
  const phone=PROPS.find(p=>p.type==='pay_phone');
  if(phone&&state.phonePropRingT>0){const dx=pcx-phone.x,dy=pcy-phone.y;if(dx*dx+dy*dy<38*38)return 'answer the public phone';}
  const cart=PROPS.find(p=>p.type==='cart');
  if(cart){if(P.cartMounted&&cart.mounted==='me')return 'abandon the cart';const dx=pcx-cart.x,dy=pcy-cart.y;if(dx*dx+dy*dy<36*36)return 'get in the cart';}
  for(const p of PROPS){if(p.type!=='dumpster')continue;const dx=pcx-(p.x+p.w/2),dy=pcy-(p.y+p.h/2);if(dx*dx+dy*dy<44*44)return p.looted?'look in the empty dumpster':'get in the dumpster';}
  if(inZone(pcx,pcy,'block')){
    if(state.flags&&!state.flags.introDone&&((P.rocks||0)+(P.soapRocks||0))<=0)return '';
    return 'use the milk crate';
  }
  if(inZone(pcx,pcy,'market'))return 'work the marketplace';
  return '';
}

export function updateGuidance(dt){
  state.guidanceT=(state.guidanceT||0)+dt;if(state.guidanceT<120)return;state.guidanceT=0;
  state.primaryObjective=currentPrimaryObjective();
  const o=state.primaryObjective,dx=o.x-(P.x+P.w/2),dy=o.y-(P.y+P.h/2),dist=Math.hypot(dx,dy);
  const el=document.getElementById('objective');
  if(el){el.innerHTML='<b>BAD IDEA</b> · '+o.text+' · '+(dist<28?'HERE':Math.max(1,Math.ceil(dist/10))+' paces '+objectiveDirection(dx,dy));el.classList.toggle('show',state.mode==='playing');}
  const hint=resolveActionHint(),hintEl=document.getElementById('actionHint');
  if(hintEl){const key=state.touchMode?'B':'E';hintEl.innerHTML='<b>'+key+'</b> · '+hint;hintEl.classList.toggle('show',state.mode==='playing'&&!!hint);}
}

export function hideGuidance(){
  const objective=document.getElementById('objective'),hint=document.getElementById('actionHint');
  if(objective)objective.classList.remove('show');
  if(hint)hint.classList.remove('show');
}

export function init_campaigns() {
  // ---------- v18 â€” THE OFFICE + BLOCK AUTHORITY ----------
  OFFICE_DOOR = { x:4908, y:3204, w:24, h:32 };
  OFFICE_UPGRADE_DEFS = [
    { id:'cot',         name:'cot',         cash:30, copper:0, desc:'rest. sleep. wake up in the same room.' },
    { id:'locker',      name:'locker',      cash:45, copper:1, desc:'the shared chest, now with a chain.' },
    { id:'desk',        name:'desk',        cash:60, copper:2, desc:'select and file district claims.' },
    { id:'generator',   name:'generator',   cash:75, copper:2, desc:'light the door. improve office rest.' },
    { id:'radio',       name:'radio',       cash:90, copper:2, desc:'receive bounded work orders.' },
    { id:'route_board', name:'route board', cash:65, copper:1, desc:'replace one unpaid route per day.' },
  ];
  OFFICE_UPGRADE_IDS = new Set(OFFICE_UPGRADE_DEFS.map(x=>x.id));
  
  // Survey and sign anchors are authored away from solids and named NPCs. The claim never
  // owns a person; it owns one damaged sign and a line in a desk ledger.
  CLAIM_SITES = [
    { id:'canal', name:'THE DRAINAGE CANAL', faction:'neutral', survey:{x:5420,y:2070,task:'read the water gauge while the water is absent.',stamp:'gauge says nine.\nwater says nothing.'}, sign:{x:4380,y:2110,task:'install the WATER PENDING sign.',stamp:'the sign leans east.\nthe canal is entered as pending.'} },
    { id:'alley', name:'BACK ALLEY', faction:'street', survey:{x:620,y:1300,task:'measure the alley entrance using your arms.',stamp:'two arms wide.\narm standard not attached.'}, sign:{x:620,y:1640,task:'install the RESIDENT OFFICE sign.',stamp:'the wall accepts one nail.\nthe second nail is theoretical.'} },
    { id:'projects', name:'THE PROJECTS', faction:'street', survey:{x:300,y:1810,task:'record building a as two buildings.',stamp:'one building. letter a.\ntwo entered.'}, sign:{x:130,y:1810,task:'install the BUILDING LETTER sign.',stamp:'the sign says building c.\nthere is no building c.'} },
    { id:'skidrow', name:'SKID ROW', faction:'street', survey:{x:3330,y:2180,task:'count the east curb without entering traffic.',stamp:'one curb.\ntwo opinions.'}, sign:{x:2500,y:1560,task:'install the NO VACANCY sign.',stamp:'no vacancy.\nseveral vacancies object.'} },
    { id:'scrap', name:'SCRAP YARD', faction:'scrap', survey:{x:360,y:420,task:'inventory the gate as two gates.',stamp:'one gate.\ntwo entered.'}, sign:{x:590,y:420,task:'install the METAL OFFICE sign.',stamp:'the sign is mostly rust.\nyuri calls that pure.'} },
    { id:'underpass', name:'HIGHWAY UNDERPASS', faction:'scrap', survey:{x:1070,y:430,task:'count the bridge supports from below.',stamp:'four supports.\none bridge. no receipt.'}, sign:{x:1360,y:250,task:'install the CEILING DEPARTMENT sign.',stamp:'the sign points up.\nthe highway continues ignoring it.'} },
    { id:'oldschool', name:'OLD SCHOOL', faction:'scrap', survey:{x:3460,y:860,task:'inspect the court line for education.',stamp:'chalk. chain.\nno curriculum.'}, sign:{x:4100,y:860,task:'install the ALUMNI OFFICE sign.',stamp:'the school did not attend.\nthe form says present.'} },
    { id:'warehouse_row', name:'WAREHOUSE ROW', faction:'scrap', survey:{x:4930,y:850,task:'compare the manifest to both warehouses.',stamp:'unit 14. returns.\nneither is unit 14.'}, sign:{x:5450,y:850,task:'install the RECEIVING sign.',stamp:'receiving refuses delivery.\nsign delivered.'} },
    { id:'market', name:'MARKETPLACE', faction:'spiritual', survey:{x:740,y:1600,task:'locate the checkout line after checkout.',stamp:'the line moved around you.\nyou were not in it.'}, sign:{x:1390,y:1600,task:'install the CUSTOMER SERVICE sign.',stamp:'no customer requested service.\nservice documented.'} },
    { id:'park', name:'THE PARK', faction:'spiritual', survey:{x:2450,y:1360,task:'ask the dry bench if it is public.',stamp:'the bench remains silent.\npublic entered as yes.'}, sign:{x:2980,y:1360,task:'install the RECREATION OFFICE sign.',stamp:'two pigeons witnessed.\nneither signed.'} },
    { id:'trainyard', name:'TRAIN YARD', faction:'spiritual', survey:{x:1320,y:3200,task:'verify the last rail also goes nowhere.',stamp:'rail continues west.\ntrain continues not arriving.'}, sign:{x:300,y:3200,task:'install the ARRIVALS OFFICE sign.',stamp:'arrivals: zero.\noffice: open.'} },
  ];
  CLAIM_SITE_BY_ID = Object.create(null);
  for(const c of CLAIM_SITES)CLAIM_SITE_BY_ID[c.id]=c;
  CLAIM_STAGES = new Set(['survey','file','install']);
  WORK_STAGES = new Set(['inspect','file']);
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  // ---------- v19 — CURB WAR / ONE CRACKLORD ----------
  // Rival courts are a separate absurd succession system. They never mutate faction reputation,
  // v18 district claims, prices, allegiance, or product supply.
  KINGDOM_STAGES = new Set([
    'locked','summons','tarp_marks','tarp_boss','cart_marks','cart_boss',
    'wire_marks','wire_boss','anoint','emperor_gate','emperor_boss','complete',
  ]);
  KINGDOM_DEFEAT_IDS = ['darryl_under_blue','general_receipt','bishop_wire','curb_emperor'];
  KINGDOM_STAGE_RANK = {
    locked:0,summons:1,tarp_marks:2,tarp_boss:3,cart_marks:4,cart_boss:5,
    wire_marks:6,wire_boss:7,anoint:8,emperor_gate:9,emperor_boss:10,complete:11,
  };
  KINGDOM_DOORS = [
    {id:'blue',x:6818,y:464,w:24,h:32,line:'blue court is in recess. the recess has no end time.'},
    {id:'cart',x:8108,y:1744,w:24,h:32,line:'the keep accepts returns through a different keep.'},
    {id:'wire',x:6818,y:3064,w:24,h:32,line:'choir office hours are b flat to b flat.'},
    {id:'throne',x:8038,y:4484,w:24,h:32,line:'the throne office is closed for succession.'},
  ];
  KINGDOM_CLANS = {
    blue_tarp:{
      id:'blue_tarp',zoneId:'blue_tarp_court',name:'BLUE TARP COURT',seal:'BLUE WEATHER',
      marksStage:'tarp_marks',bossStage:'tarp_boss',nextStage:'cart_marks',clearFlag:'blueTarpCleared',
      guardSprite:'blue_tarp_guard',guardName:'TARP KNIGHT',bossId:'darryl_under_blue',bossName:'DARRYL UNDER BLUE',bossSprite:'darryl_under_blue',
      bossHp:180,bossDmg:10,bossSpeed:1.55,archetype:'charger',rewardCash:24,rewardCred:18,
      banner:{x:6500,y:900},boss:{x:6500,y:760},adds:[{x:6200,y:720},{x:6800,y:720}],
      zoneOnly:{x:5920,y:260,w:1160,h:1060},
      marks:[
        {x:6020,y:1180,task:'enter the bucket as a weather station.',stamp:'bucket: one. weather: inside.\nstation entered as permanent.'},
        {x:6200,y:760,task:'serve a roof notice on the rope.',stamp:'rope received notice.\nroof refused signature.'},
        {x:6940,y:1040,task:'ask the plastic chair to witness the court.',stamp:'chair witnessed.\nchair requested mileage.'},
      ],
    },
    cart_cavalry:{
      id:'cart_cavalry',zoneId:'cart_cavalry_keep',name:'CART CAVALRY KEEP',seal:'CART APPEAL',
      marksStage:'cart_marks',bossStage:'cart_boss',nextStage:'wire_marks',clearFlag:'cartKeepCleared',
      guardSprite:'receipt_guard',guardName:'CART LANCER',bossId:'general_receipt',bossName:'GENERAL RECEIPT',bossSprite:'general_receipt',
      bossHp:200,bossDmg:9,bossSpeed:1.25,archetype:'grabber',rewardCash:30,rewardCred:22,
      banner:{x:7860,y:2320},boss:{x:7860,y:2050},adds:[{x:7500,y:1980},{x:8220,y:1980}],
      zoneOnly:{x:7340,y:1460,w:1040,h:980},
      marks:[
        {x:7440,y:2380,task:'cite the cavalry parking brake.',stamp:'six carts. one brick.\nbrake status: brick.'},
        {x:7580,y:1900,task:'stamp the axle where a horse would go.',stamp:'horse absent. axle present.\ncavalry entered as rolling.'},
        {x:8240,y:2200,task:'return the return policy to itself.',stamp:'return denied.\npolicy returned anyway.'},
      ],
    },
    copper_choir:{
      id:'copper_choir',zoneId:'copper_choir_yard',name:'COPPER CHOIR YARD',seal:'COPPER MASS',
      marksStage:'wire_marks',bossStage:'wire_boss',nextStage:'anoint',clearFlag:'copperChoirCleared',
      guardSprite:'wire_guard',guardName:'WIRE DEACON',bossId:'bishop_wire',bossName:'BISHOP WIRE',bossSprite:'bishop_wire',
      bossHp:210,bossDmg:8,bossSpeed:1.2,archetype:'ranged',rewardCash:36,rewardCred:26,
      banner:{x:6510,y:3700},boss:{x:6510,y:3480},adds:[{x:6140,y:3460},{x:6880,y:3460}],
      zoneOnly:{x:5920,y:2760,w:1220,h:1120},
      marks:[
        {x:7000,y:3760,task:'file the note held by the copper rack.',stamp:'b flat. again.\nnoise entered as inventory.'},
        {x:6100,y:3500,task:'count the wire loops without touching math.',stamp:'three loops. one loose end.\nmath not retained.'},
        {x:6900,y:3260,task:'serve the hubcap with a choir summons.',stamp:'hubcap rang once.\nattendance entered as yes.'},
      ],
    },
  };
  KINGDOM_CLAN_LIST = Object.values(KINGDOM_CLANS);
  KINGDOM_EMPEROR = {
    zoneId:'throne_ditch',bossId:'curb_emperor',bossName:'THE CURB EMPEROR',bossSprite:'curb_emperor',
    bossHp:280,bossDmg:12,bossSpeed:1.45,archetype:'charger_older',rewardCash:60,rewardCred:40,
    banner:{x:7680,y:5200},boss:{x:7680,y:4880},adds:[{x:7240,y:4800},{x:8120,y:4800}],
    zoneOnly:{x:7020,y:4200,w:1320,h:1120},
  };
  KINGDOM_GUARD_POSTS = {
    blue_tarp:[{x:6060,y:660},{x:6140,y:1120},{x:6800,y:700},{x:6500,y:1180}],
    cart_cavalry:[{x:7440,y:1840},{x:7540,y:2240},{x:8240,y:1840},{x:7800,y:1800}],
    copper_choir:[{x:6040,y:3200},{x:6500,y:3200},{x:6940,y:3220},{x:7040,y:3700}],
    throne:[{x:7140,y:4680},{x:7500,y:4700},{x:7800,y:5000}],
  };
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  QUEST_TARGETS = {
    first_rock:    {x:1634,y:886,text:'buy a rock from tre bag tony.'},
    copper_sings:  {x:1740,y:430,text:'test the boards on the abandoned building.'},
    finisher:      {x:1064,y:882,text:'cook something at the milk crate.'},
    conductor:     {x:820,y:2940,text:'find the conductor in the train yard.'},
    priest_mercy:  {x:1800,y:1585,text:'find father o\'malley at the church.'},
    fallen_king:   {x:1634,y:886,text:'settle the corner with tre bag tony.'},
    stripe_package:{x:820,y:2940,text:'take stripe\'s package to the conductor.'},
    barb_crossword:{x:1200,y:1510,text:'find the missing saturday crossword.'},
    fallen_priest: {x:1800,y:1585,text:'go back to the church.'},
    scrap_dog:     {x:560,y:150,text:'check on the scrap yard dog.'},
  };
  
  
  
  
  
  
  
}

export let PHONE_CALL_LINES, MOM_TIP_CALL, MOM_PROUD_LINES, NEWS_POOL, newsState, phoneState, FEED_HANDLES, WORLD_EVENTS;

export function ringPhone(forced) {
  if (state.mode !== 'playing') return;
  // v13 wave 3 — `forced` lets the intro mom-tip fire even during the suppression window.
  const call = forced || PHONE_CALL_LINES[Math.floor(Math.random()*PHONE_CALL_LINES.length)];
  audio.dialogue();
  toast('📞 incoming call · ' + call.from + '\n\n' + call.text, 5500);
  feedPost('phone call from ' + call.from.toLowerCase() + '.', '@phone_guy');
  if (call.action) call.action();
}

export function fireMomIntroTipOnce() {
  if (!state.flags) return;
  if (state.flags.momIntroFired) return;
  if (state.mode !== 'playing') return;
  state.flags.momIntroFired = true;
  ringPhone(MOM_TIP_CALL);
  saveGame();
}

export function maybeFireMomProudCall() {
  if (!state.flags) return;
  if (state.mode !== 'playing') return;
  if ((state.flags.momProudCallDay || 0) === state.day) return;
  if (!P.faction || P.faction.spiritual < 10) return;
  // silence window guard (day 7 event)
  if (state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  state.flags.momProudCallDay = state.day;
  const txt = MOM_PROUD_LINES[Math.floor(Math.random()*MOM_PROUD_LINES.length)];
  ringPhone({ from: 'YOUR MOM', text: txt + "\n(+5 brain)", action: () => { P.brain = Math.min(100, P.brain + 5); } });
}

export function spawnPetPossum() {
  if (runtime.npcs.find(n=>n.id==='pet_possum')) return;
  runtime.npcs.push({
    id:'pet_possum', name:'YOUR POSSUM', sprite:'possum',
    x: P.x - 30, y: P.y + 12, w:28, h:24, color:'#604030',
    hp:30, maxHp:30, speed:1.6, hostile:false, isPet:true, frame:0,
    interact: () => dialogue('YOUR POSSUM', "he stares.\nhe has been with you for some time now.\nhe has things to say. he will not.", [
      { label: 'release the possum back to the wild.', action: () => {
        const pet = runtime.npcs.find(n=>n.id==='pet_possum'); if (pet) pet.dead = true;
        toast("you set the possum down.\nhe walks the other way without looking back.\nyou understand.");
        P.hasPossum = false;
      }},
      { label: 'leave.', action:()=>{} },
    ]),
  });
  P.hasPossum = true;
  toast("the possum follows you now.\nhe is on his route.\nyou are on his route.", 3500);
  broadcastNews("LOCAL MAN ACQUIRES POSSUM. POSSUM SEEMINGLY UNFAZED.");
  feedPost("the possum follows me now. i don't know what this means.", '@crackheadcent');
  unlockAchievement('the_route');
}

export function garbageTruckRumble() {
  audio.traffic();
  audio.traffic();
  toast("a garbage truck rumbles down the street.\nall dumpsters are reset.\none of them now has a 'TIPS' jar duct-taped to the side.", 4200);
  feedPost("garbage truck went through. fresh dumpsters in the neighborhood.", '@local_eyewitness');
  // reset all dumpsters
  PROPS.filter(p => p.type === 'dumpster').forEach(p => { p.looted = false; });
  // pick one to get a tips jar
  const dumps = PROPS.filter(p => p.type === 'dumpster');
  if (dumps.length) {
    const lucky = dumps[Math.floor(Math.random()*dumps.length)];
    lucky.tipsJar = true;
  }
  broadcastNews("GARBAGE TRUCK COMPLETES ROUTE. DUMPSTERS REOPEN FOR BUSINESS.");
}

export function rotateNews() {
  const tape = document.getElementById('tape');
  if (!tape) return;
  // build a rotating string of 4-6 news items
  const items = [];
  for (let i=0;i<5;i++) items.push(NEWS_POOL[(newsState.idx + i) % NEWS_POOL.length]);
  newsState.idx = (newsState.idx + 1) % NEWS_POOL.length;
  tape.textContent = items.join('   ◆   ');
}

export function broadcastNews(line) {
  // v13 wave 7 — silence window suppresses the ticker. day-event triggers always go through (Date.now check).
  if (state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  const tape = document.getElementById('tape');
  if (!tape) return;
  tape.textContent = '· BREAKING · ' + line + '   ◆   ' + tape.textContent;
}

export function feedPost(text, handle) {
  // v13 wave 7 — silence window suppresses the phone feed (day 7 event).
  if (state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  const h = handle || FEED_HANDLES[Math.floor(Math.random()*FEED_HANDLES.length)];
  phoneState.posts.unshift({ h, t: text, day: state.day });
  while (phoneState.posts.length > 8) phoneState.posts.pop();
  renderPhone();
}

export function renderPhone() {
  const box = document.getElementById('phonebox');
  const list = document.getElementById('phPosts');
  const day = document.getElementById('phDay');
  if (!box || !list) return;
  box.classList.toggle('show', phoneState.visible && state.mode==='playing');
  day.textContent = state.day;
  list.innerHTML = phoneState.posts.map(p => `<div class="post"><b>${p.h}</b><br>${p.t}</div>`).join('');
}

export function fireRandomEvent() {
  const ev = WORLD_EVENTS[Math.floor(Math.random()*WORLD_EVENTS.length)];
  toast(ev.text, 5500);
  if (ev.effect) ev.effect();
  if (ev.sfx) audio[ev.sfx]();
  feedPost(ev.text.split('\n')[0].toLowerCase(), '@local_eyewitness');
  if (Math.random() < 0.3) broadcastNews(ev.text.split('\n')[0]);
}

export function init_communications() {
  // ---------- INCOMING PHONE CALLS ----------
  PHONE_CALL_LINES = [
    { from:'TRE BAG TONY', text:"come see me.\ni have rocks.\nyou know how this works.", action:() => {} },
    { from:'YOUR MOM', text:"don't come over for thanksgiving.\nben said you can't.\nben is not your dad.\n(- 5 brain)", action:() => { P.brain = Math.max(0, P.brain - 5); } },
    { from:'A WRONG NUMBER', text:"this is dolores.\nis carl there.\ncarl owes me $40.\n(+$3, the wrong number gave you advice)", action:() => { P.cash += 3; } },
    { from:'STRIPE', text:"yo. i got new product.\nfor sure not soap this time.\nfor sure.", action:() => {} },
    { from:'THE CONDUCTOR', text:"the train.\nit is closer now.\nit will not be here.", action:() => {} },
    { from:'YOUR LANDLORD', text:"you do not have a landlord.\nyou do not have an apartment.\nhe is calling anyway.", action:() => {} },
    { from:'A POSSUM (on a flip phone)', text:"...\n*click*", action:() => { P.brain = Math.min(100, P.brain + 4); } },
    { from:'FATHER O\'MALLEY', text:"come to mass.\nbring shakes.\nthe tic-tacs are blessed today.", action:() => {} },
    { from:'A SCAM', text:"hello sir we are calling about your car's extended warranty.\nyou do not have a car.\nyou do not have an extended warranty.\n(+1 cred for hanging up)", action:() => { P.cred += 1; } },
    { from:'PAULIE', text:"the face is doing a thing.\nyou should come look at it.", action:() => {} },
    { from:'YURI', text:"BRUTUS REMEMBER.\n*click*", action:() => {} },
    { from:'YOUR OWN VOICE', text:"hey.\nit's you.\nyou should drink water.\n(+10 brain)", action:() => { P.brain = Math.min(100, P.brain + 10); } },
  ];
  
  
  // v13 wave 3 — mom's first-day tip. fires ~30s after a new save begins. only fires once per save.
  MOM_TIP_CALL = {
    from: 'YOUR MOM',
    text: "remember tony likes you.\nyou said you'd come see him.\nyou said it twice.",
    action: () => {}
  };
  
  
  // v13 wave 7 — spiritual LIKED+: mom calls with a proud line, +5 brain.
  // fires at most once per day, only when spiritual >= +10 (LIKED).
  MOM_PROUD_LINES = [
    "remember when you were six.\nyou drew a duck.\nthe duck was good.\nthe duck is on the fridge.",
    "kelly's son is fine. he is fine.\nhe is not you. you are also fine.",
    "ben says hi. ben says it the way ben says it.\nyou know what i mean.",
    "i told the women at trader joe's about you.\nthey nodded.\nthey nodded a lot.",
  ];
  
  
  // ---------- PET POSSUM follower ----------
  
  
  // ---------- GARBAGE TRUCK event ----------
  
  
  // ---------- news ticker ----------
  NEWS_POOL = [
    "good evening. tony has not blinked since 1994.",
    "weather: tuesday. with a 40% chance of more tuesday.",
    "local pigeon demands $2. economists call it 'fair'.",
    "the train is coming. the train will never be here. more at 11.",
    "father o'malley refuses comment on whether tic-tacs are medicine.",
    "yuri says: 'BRUTUS remember.' yuri did not elaborate.",
    "an entire family of crackheads moved into the alley. they were already there.",
    "the conductor's pocket watch is set to a year that does not exist yet.",
    "possum spotted wearing tiny construction helmet. osha 'cautiously optimistic'.",
    "marketplace stall #3 sells only umbrellas. weather forecast: lawsuit.",
    "stripe insists rock is real. lab tests inconclusive (it is soap).",
    "the abandoned building is humming. b flat. it has been for 12 years.",
    "pete weighed a single sock for 11 minutes. the sock did not survive.",
    "loud larry remains loud. doctors stunned.",
    "whole foods mom is worried. about you. specifically.",
    "the big guy is, in fact, tall. updates as they happen.",
    "in sports: nothing. the team has not arrived. the team does not exist.",
    "baggie barb is doing the crossword. she will not look up. she has packets.",
    "the crate is, by ordinance, not a kitchen. the crate is, by use, a kitchen.",
    "stripe is buying rocks now. he says 'inventory.' he says it once.",
    "horoscope: avoid copper. embrace copper. you will trade copper.",
    "BREAKING: a dachshund in a blazer was seen entering the church.",
    "the pigeon king has named a successor. the successor is also a pigeon.",
  ];
  newsState = { current: [], idx: 0, t: 0 };
  
  
  
  // ---------- phone feed ----------
  phoneState = { posts: [], visible: false };
  FEED_HANDLES = [
    '@crackheadcent','@tony_observer','@possum_official','@pawn_pete','@the_corner',
    '@father_o','@conductor_eta','@stripe_certified','@whole_foods_mom_irl','@pigeon_news',
    '@yuri_metals','@lurch_thoughts','@brutus_blog','@the_alley_post','@cubscout_mom',
  ];
  
  
  
  // ---------- world events (random absurd spawns) ----------
  WORLD_EVENTS = [
    { id:'forklift_possum', text:"a possum drives a forklift through the marketplace.\nhe has a clipboard. he is doing inventory." },
    { id:'cloud_yell', text:"a man yells at a cloud.\na child watches. respects you immediately. (+2 cred)", effect: () => { P.cred += 2; } },
    { id:'doordash', text:"a doordash driver hands you a bag and runs.\ninside: a single chicken nugget and someone's $400 sushi platter.\n(+$12)", effect: () => { P.cash += 12; } },
    { id:'car_alarm', text:"a car alarm goes off.\nit plays a song that has lyrics. no one acknowledges this.", sfx:'glassBreak' },
    { id:'chimichanga', text:"a chimichanga rolls past you.\nit is talking. it has opinions about a man named greg." },
    { id:'horse_nod', text:"a cop on horseback nods at you. the horse also nods.\ndisturbing levels of agreement." },
    { id:'pothole_say', text:"a pothole says your full legal name.\nyou did not give it your full legal name." },
    { id:'pigeon_road', text:"a pigeon stands in the road.\nthree cars wait. it is the pigeon king's nephew." },
    { id:'forget_year', text:"you forget what year it is for 4 minutes.\nwhen you come back, you are holding a traffic cone.\n(- 3 brain)", effect: () => { P.brain = Math.max(0, P.brain-3); P.inventory.push({id:'cone', n:'a traffic cone', q:1}); } },
    { id:'puddle_wave', text:"you see your reflection in a puddle.\nhe waves. you don't wave back.\nhe waves harder." },
    { id:'pigeon_change', text:"a pigeon shits exactly $4.20 in change directly on your head.\nthe pigeon nods. you nod. the exchange is complete.\n(+$4)", effect: () => { P.cash += 4; } },
    { id:'sushi_wedding', text:"a wedding procession crosses the street.\nthe bride is unaccompanied. the groom is a vending machine." },
    { id:'sandwich_lecture', text:"a sandwich lectures you about logistics for 8 seconds.\nyou nod. you understand none of it. you feel taller.\n(+1 cred)", effect: () => { P.cred += 1; } },
    { id:'siren_distant', text:"sirens. far away. somebody else's problem.", sfx:'copSiren' },
    { id:'tony_blinks', text:"tony blinks.\nyou see it.\nit is the only thing.\n(+5 cred)", effect: () => { P.cred += 5; broadcastNews("EYEWITNESS: TONY BLINKED. UNCONFIRMED."); } },
    { id:'dachshund', text:"a dachshund in a blazer hands you a receipt.\nit is for a haircut you did not get." },
    { id:'guy_running', text:"a man sprints past you yelling 'sorry. sorry. sorry.'\nhe is not sorry.", effect: () => { P.cash += 3; }, },
    { id:'helicopter', text:"a helicopter circles overhead for 4 seconds.\nit was a leaf.", sfx:'traffic' },
    { id:'twin_possums', text:"two possums in matching helmets walk by.\nthey are not twins. they are coworkers." },
    { id:'wedding_guy', text:"a man in a tuxedo sprints past you.\nhe is late for a wedding. or escaping one.\n(+$5)", effect: () => { P.cash += 5; } },
    { id:'pizza_box', text:"a pizza box flies past at head height.\ninside: a single tooth (gold).\n(+ a tooth (gold))", effect: () => { P.inventory.push({id:'gold_tooth', n:'a tooth (gold)', q:1}); } },
    { id:'school_bus', text:"a school bus drives past.\nthe driver is the conductor.\nthe driver is also still at his post in the train yard." },
    { id:'mom_drives_by', text:"a minivan slows down.\nthe driver looks at you.\nthe driver is your mom. she does not stop.\nyou wave. she pretends not to see.\n(-3 brain)", effect: () => { P.brain = Math.max(0, P.brain - 3); } },
    { id:'free_meatball', text:"a meatball rolls toward you.\nit is steaming.\nyou eat it. (+12 hp)", effect: () => { P.hp = Math.min(P.maxHp, P.hp + 12); } },
    { id:'man_with_sign', text:"a man holds a sign that says 'THE END.'\nthe sign is from a furniture store." },
    { id:'singing_streetlight', text:"a streetlight is singing in b flat.\nthe copper agrees." },
    { id:'free_money', text:"$20 lands at your feet.\nthere is no one nearby.\nyou look up. there is no helicopter.\n(+$20)", effect: () => { P.cash += 20; } },
    { id:'philosopher_man', text:"a man in a robe says 'we live in a society.'\nhe is correct.\nhe asks for $5. he is also correct about that.", effect: () => { if (P.cash >= 5) { P.cash -= 5; P.cred += 6; } } },
    { id:'pigeon_gang', text:"seven pigeons walk by in formation.\nthey are coordinating.\nthey nod at you. you are made." },
  ];
  
  
  
}

export let INCIDENT_IDS, INCIDENT_DEFS;

export function ensureIncidentFlags() {
  if (!state.flags) state.flags={};
  if (state.flags.incidentDay !== state.day) {
    state.flags.incidentDay=state.day;
    state.flags.incidentMask=0;
    state.flags.incidentsToday=0;
  }
  state.flags.incidentMask=state.flags.incidentMask||0;
  state.flags.incidentsToday=state.flags.incidentsToday||0;
  state.flags.lastIncidentId=state.flags.lastIncidentId||'';
}

export function incidentNpc(id) {
  return runtime.npcs.find(n=>n.id===id&&!n.dead);
}

export function incidentCombatBusy() {
  if (state.bossActive || state.brutusOlderActive) return true;
  const cx=P.x+P.w/2, cy=P.y+P.h/2;
  return runtime.npcs.some(n=>!n.dead&&n.aggro&&Math.hypot(n.x+n.w/2-cx,n.y+n.h/2-cy)<320);
}

export function incidentScriptBusy() {
  return runtime.npcs.some(n=>!n.dead&&(n.isDay3Visitor||n.id==='bus_driver'));
}

export function nearestIncidentRoad() {
  const cx=P.x+P.w/2, cy=P.y+P.h/2;
  let best=ROAD_SEGMENTS[0], bestD=Infinity;
  for(const r of ROAD_SEGMENTS){
    const qx=clamp(cx,r.x,r.x+r.w), qy=clamp(cy,r.y,r.y+r.h);
    const d=(qx-cx)*(qx-cx)+(qy-cy)*(qy-cy);
    if(d<bestD){bestD=d;best=r;}
  }
  return best;
}

export function startIncident(id) {
  const def=INCIDENT_DEFS[id]; if(!def)return;
  const inc={id,t:0,beat:-1,duration:def.duration,actors:[],bumped:false};
  if(id==='runaway_mattress'){
    const r=nearestIncidentRoad(), horizontal=r.axis==='h';
    const center=horizontal?P.x+P.w/2:P.y+P.h/2;
    const lo=horizontal?r.x:r.y, hi=horizontal?r.x+r.w:r.y+r.h;
    const projected=clamp(center,lo+18,hi-18);
    const roomForward=hi-projected, roomBack=projected-lo;
    const dir=roomForward>=roomBack?1:-1;
    const start=clamp(projected-dir*380,lo+18,hi-18), end=clamp(projected+dir*560,lo+18,hi-18);
    inc.road=r; inc.dir=dir;
    inc.actors=[{kind:'mattress',x:horizontal?start:r.x+r.w/2,y:horizontal?r.y+r.h/2:start,
      sx:horizontal?start:r.x+r.w/2,sy:horizontal?r.y+r.h/2:start,
      ex:horizontal?end:r.x+r.w/2,ey:horizontal?r.y+r.h/2:end}];
  } else if(id==='possum_inventory') {
    inc.actors=[{kind:'forklift',x:720,y:1515}];
  } else if(id==='laundromat_walkout') {
    inc.actors=[{kind:'dryer',x:1540,y:1190}];
  } else if(id==='yuri_receipt') {
    const dog=incidentNpc('brutus');
    inc.anchor={x:310,y:220,tx:dog?dog.x+dog.w/2:570,ty:dog?dog.y+dog.h/2:150};
    if(!dog)inc.overrideBeat2='the wind wraps the leash post.\nthe post remains employed.';
  } else if(id==='park_dry_committee') {
    inc.anchor={x:2600,y:1280}; inc.sprayAngle=-.4;
  } else if(id==='ticketed_luggage') {
    inc.actors=[{kind:'suitcase',x:360,y:2985}];
  }
  state.incident=inc;
  ensureIncidentFlags();
  const bit=1<<INCIDENT_IDS.indexOf(id);
  state.flags.incidentMask|=bit;
  state.flags.incidentsToday++;
  state.flags.lastIncidentId=id;
  saveGame();
  feedPost(def.beats[0][1].split('\n')[0], '@local_eyewitness');
}

export function finishIncident(interrupted=false) {
  if(!state.incident)return;
  state.incident=null;
  state.incidentT=(interrupted?45000:70000)+Math.random()*(interrupted?20000:40000);
}

export function incidentRequiredValid(inc) {
  const def=INCIDENT_DEFS[inc.id];
  if(!def||!def.required)return true;
  const n=incidentNpc(def.required);
  return !!n&&!n.aggro&&!n.hostile;
}

export function pointSegmentDistance(px,py,x1,y1,x2,y2){
  const dx=x2-x1,dy=y2-y1,l2=dx*dx+dy*dy;
  const t=l2?clamp(((px-x1)*dx+(py-y1)*dy)/l2,0,1):0;
  return Math.hypot(px-(x1+t*dx),py-(y1+t*dy));
}

export function updateActiveIncident(inc,dt) {
  const p=Math.min(1,inc.t/inc.duration), ease=p*p*(3-2*p);
  if(inc.id==='runaway_mattress'){
    const a=inc.actors[0];
    a.x=a.sx+(a.ex-a.sx)*ease; a.y=a.sy+(a.ey-a.sy)*ease+Math.sin(inc.t/240)*3;
    if(!inc.bumped&&inc.t>1800&&Math.abs(a.x-(P.x+P.w/2))<25&&Math.abs(a.y-(P.y+P.h/2))<25){
      inc.bumped=true; state.shake=Math.max(state.shake,5);
      P.x=clamp(P.x+Math.sign(a.ex-a.sx)*14,0,WORLD.w-P.w);
      P.y=clamp(P.y+Math.sign(a.ey-a.sy)*14,0,WORLD.h-P.h);
      toast('the mattress has insurance.\nyou do not.',1800);
    }
  } else if(inc.id==='possum_inventory'){
    const a=inc.actors[0], q=Math.min(1,inc.t/24500);
    a.x=720+q*620; a.y=1515+Math.sin(inc.t/430)*5;
  } else if(inc.id==='laundromat_walkout'){
    const a=inc.actors[0], q=Math.min(1,inc.t/24500);
    a.x=1540+q*360; a.y=1190+q*45+Math.sin(inc.t/170)*3;
  } else if(inc.id==='yuri_receipt'){
    const a=inc.anchor, cx=P.x+P.w/2,cy=P.y+P.h/2;
    if(inc.t>5000&&pointSegmentDistance(cx,cy,a.x,a.y,a.tx,a.ty)<20) state.incidentPaperT=4000;
  } else if(inc.id==='park_dry_committee'){
    const a=inc.anchor,cx=P.x+P.w/2,cy=P.y+P.h/2;
    inc.sprayAngle=inc.t>12000&&inc.t<23000?Math.atan2(cy-a.y,cx-a.x):Math.sin(inc.t/900)*.7-.5;
    const dist=Math.hypot(cx-a.x,cy-a.y);
    if(inc.t>12000&&inc.t<23000&&dist<175) state.incidentWetT=4000;
  } else if(inc.id==='ticketed_luggage'){
    const a=inc.actors[0];
    if(inc.t<9000)a.x=360+(inc.t/9000)*310;
    else if(inc.t<14500)a.x=670;
    else a.x=670+Math.min(1,(inc.t-14500)/12500)*650;
    a.y=2985+Math.sin(inc.t/260)*3;
    if(Math.abs(a.x-(P.x+P.w/2))<32&&Math.abs(a.y-(P.y+P.h/2))<28)a.y+=28;
  }
}

export function updateIncidents(dt,introActive,silenceActive) {
  state.incidentPaperT=Math.max(0,(state.incidentPaperT||0)-dt);
  state.incidentWetT=Math.max(0,(state.incidentWetT||0)-dt);
  if(state.incident){
    if(silenceActive||incidentCombatBusy()||incidentScriptBusy()||!incidentRequiredValid(state.incident)){
      finishIncident(true); return;
    }
    const inc=state.incident, def=INCIDENT_DEFS[inc.id];
    inc.t+=dt;
    updateActiveIncident(inc,dt);
    while(inc.beat+1<def.beats.length&&inc.t>=def.beats[inc.beat+1][0]){
      inc.beat++;
      const beatText=(inc.beat===2&&inc.overrideBeat2)||def.beats[inc.beat][1];
      toast(beatText,inc.beat===def.beats.length-1?2600:3200);
      if(inc.beat===1&&def.sfx&&audio[def.sfx])audio[def.sfx]();
    }
    if(inc.t>=inc.duration)finishIncident(false);
    return;
  }
  if(introActive||silenceActive||state.bossActive||state.brutusOlderActive||incidentCombatBusy()||incidentScriptBusy())return;
  ensureIncidentFlags();
  if(state.flags.incidentsToday>=3)return;
  state.incidentT=(state.incidentT==null?35000+Math.random()*20000:state.incidentT)-dt;
  if(state.incidentT>0)return;
  const z=currentZone(), unseen=id=>!(state.flags.incidentMask&(1<<INCIDENT_IDS.indexOf(id)));
  let choices=INCIDENT_IDS.filter(id=>{
    const d=INCIDENT_DEFS[id];
    if(!unseen(id))return false;
    if(d.zone&&(!z||z.id!==d.zone))return false;
    if(d.clearDay&&(state.weather!=='clear'||isNight()))return false;
    if(d.required){const n=incidentNpc(d.required);if(!n||n.aggro||n.hostile)return false;}
    return true;
  });
  const specific=choices.filter(id=>INCIDENT_DEFS[id].zone);
  if(specific.length)choices=specific;
  if(!choices.length){state.incidentT=30000;return;}
  let pick=choices[Math.floor(Math.random()*choices.length)];
  if(choices.length>1&&pick===state.flags.lastIncidentId)pick=choices.find(id=>id!==pick)||pick;
  startIncident(pick);
}

export function drawIncidentSprite(key,x,y,frame=0) {
  const sp=SPRITE_CACHE[key+'_'+frame]||SPRITE_CACHE[key+'_0'];
  if(sp&&visibleWorldRect(x-20,y-36,44,48,16))ctx.drawImage(sp,Math.round(x-16),Math.round(y-28),32,32);
}

export function drawIncidents() {
  const inc=state.incident;if(!inc)return;
  const t=state.visualNow||performance.now(), frame=Math.floor(t/320)%2;
  if(inc.id==='runaway_mattress'){
    const a=inc.actors[0];
    ctx.fillStyle='rgba(0,0,0,.36)';ctx.beginPath();ctx.ellipse(a.x,a.y+5,18,4,0,0,Math.PI*2);ctx.fill();
    drawIncidentSprite('incident_mattress',a.x,a.y,frame);
  } else if(inc.id==='possum_inventory'){
    const a=inc.actors[0];drawIncidentSprite('incident_forklift',a.x,a.y,frame);
    const ps=SPRITE_CACHE['possum_'+frame];if(ps)ctx.drawImage(ps,Math.round(a.x-13),Math.round(a.y-39),32,32);
    ctx.fillStyle='#d4c896';ctx.fillRect(Math.round(a.x+12),Math.round(a.y-22),7,9);
  } else if(inc.id==='laundromat_walkout'){
    const a=inc.actors[0];drawIncidentSprite('incident_dryer',a.x,a.y,frame);
    ctx.fillStyle='rgba(136,192,255,.45)';
    for(let i=0;i<6;i++){const bx=a.x-10+((i*13+t/80)%28),by=a.y-25-Math.abs(Math.sin(t/400+i))*18;ctx.fillRect(bx,by,2,2);}
  } else if(inc.id==='yuri_receipt'){
    const a=inc.anchor, reveal=clamp((inc.t-3500)/9000,0,1), count=Math.floor(12*reveal);
    for(let i=0;i<count;i++){
      const q=i/11,x=a.x+(a.tx-a.x)*q,y=a.y+(a.ty-a.y)*q+Math.sin(q*15+t/240)*8;
      ctx.save();ctx.translate(x,y);ctx.rotate(Math.sin(q*9)*.35);ctx.fillStyle='#d4c896';ctx.fillRect(-7,-3,14,6);ctx.fillStyle='#5a4828';ctx.fillRect(-5,-1,7,1);ctx.restore();
    }
  } else if(inc.id==='park_dry_committee'){
    const a=inc.anchor;drawIncidentSprite('incident_sprinkler',a.x,a.y,frame);
    if(inc.t<23000){
      ctx.strokeStyle='rgba(136,192,255,.55)';ctx.lineWidth=2;ctx.setLineDash([3,5]);
      ctx.beginPath();ctx.moveTo(a.x,a.y-12);ctx.lineTo(a.x+Math.cos(inc.sprayAngle)*170,a.y-12+Math.sin(inc.sprayAngle)*170);ctx.stroke();ctx.setLineDash([]);
    }
    for(let i=0;i<6;i++){
      const ang=-2.8+i*.52,px=a.x+Math.cos(ang)*78,py=a.y+Math.sin(ang)*48;
      const ps=SPRITE_CACHE['pigeon_'+((frame+i)&1)];if(ps)ctx.drawImage(ps,Math.round(px-16),Math.round(py-24),32,32);
    }
  } else if(inc.id==='ticketed_luggage'){
    const a=inc.actors[0];drawIncidentSprite('incident_suitcase',a.x,a.y,frame);
    if(inc.t>14000)for(let i=0;i<3;i++){
      const ps=SPRITE_CACHE['pigeon_'+((frame+i)&1)],px=a.x-30-i*26,py=a.y+8+(i&1)*5;
      if(ps)ctx.drawImage(ps,Math.round(px-16),Math.round(py-24),32,32);
    }
  }
}

export function drawIncidentPlayerCosmetics(){
  if(state.incidentPaperT>0){ctx.fillStyle='#d4c896';ctx.fillRect(P.x+P.w-3,P.y+7,9,5);ctx.fillStyle='#5a4828';ctx.fillRect(P.x+P.w-1,P.y+9,5,1);}
  if(state.incidentWetT>0){
    const t=(state.visualNow||performance.now())/120;ctx.fillStyle='#88c0ff';
    for(let i=0;i<3;i++)ctx.fillRect(P.x+3+i*8,P.y+P.h+((t+i*3)%7),2,3);
  }
}

export function init_incidents() {
  // ---------- v15 living-neighborhood incidents ----------
  // These are scene actors, never NPCs. They cannot be targeted, killed, saved as corpses,
  // scanned by interaction priority, or counted by faction/economy systems.
  INCIDENT_IDS = [
    'runaway_mattress','possum_inventory','laundromat_walkout',
    'yuri_receipt','park_dry_committee','ticketed_luggage'
  ];
  INCIDENT_DEFS = {
    runaway_mattress:{
      zone:null, duration:25000, sfx:'traffic', required:null,
      beats:[
        [0,'a mattress enters traffic.'],
        [5200,'traffic yields.\nthe mattress does not.'],
        [12800,'it changes lanes without signaling.\nit has no driver.'],
        [21000,'the mattress exits.\nright of way is restored.'],
      ]
    },
    possum_inventory:{
      zone:'market', duration:30000, sfx:'kick', required:'possum',
      beats:[
        [0,'the marketplace begins inventory.'],
        [5800,'a possum arrives with a forklift and a clipboard.'],
        [14200,'he counts you twice.\nhe does not correct it.'],
        [24800,'inventory closes.'],
      ]
    },
    laundromat_walkout:{
      zone:'laundromat', duration:29000, sfx:'kick', required:'barb',
      beats:[
        [0,'a dryer starts thumping.'],
        [5400,'it rolls out with one wet sock inside.'],
        [13700,'it takes the bus lane.\nbarb fills in 12 down.'],
        [24000,'the dryer stops at a red light.'],
      ]
    },
    yuri_receipt:{
      zone:'scrap', duration:28000, sfx:'radio', required:'yuri',
      beats:[
        [0,'yuri weighs one hubcap.'],
        [5000,'the scale prints fourteen feet of receipt.'],
        [12800,'the wind wraps the dog.\nthe dog remains employed.'],
        [23000,'yuri starts over.'],
      ]
    },
    park_dry_committee:{
      zone:'park', duration:28000, sfx:'holyWaterHit', required:null, clearDay:true,
      beats:[
        [0,'the park sprinkler turns on.'],
        [5200,'six pigeons form a dry committee.'],
        [12600,'the sprinkler turns toward you.\nthey take minutes.'],
        [23000,'the water stops.\nmeeting adjourned.'],
      ]
    },
    ticketed_luggage:{
      zone:'trainyard', duration:31000, sfx:'traffic', required:'conductor',
      beats:[
        [0,'a suitcase rolls into the train yard.'],
        [6000,'the conductor punches its ticket.'],
        [14500,'three pigeons stand behind it.\nthe suitcase leaves on foot.'],
        [26000,'the train does not.'],
      ]
    },
  };
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
}

export let PALS, PLAYER_LAYER_PAL, CART_LAYER_PAL, SPRITE_CACHE, INCIDENT_PALS;

export function parseGrid(rows) {
  return rows.map(r => r.split('').map(c => c === '.' ? 0 : parseInt(c)));
}

export function applyVars(rows, vars) {
  return rows.map(r => {
    let out = r;
    for (const k in vars) out = out.split(k).join(vars[k]);
    return out;
  });
}

export function blankSpriteGrid(){return Array.from({length:16},()=>Array(16).fill(0));}

export function gridPut(g,x,y,v){if(x>=0&&x<16&&y>=0&&y<16)g[y][x]=v;}

export function gridBox(g,x,y,w,h,v){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)gridPut(g,xx,yy,v);}

export function gridLine(g,x1,y1,x2,y2,v){const n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1));for(let i=0;i<=n;i++)gridPut(g,Math.round(x1+(x2-x1)*(i/(n||1))),Math.round(y1+(y2-y1)*(i/(n||1))),v);}

export function mirrorGrid(g){return g.map(row=>row.slice().reverse());}

export function anchorGridToBottom(g){
  let bottom=-1;for(let y=0;y<16;y++)for(let x=0;x<16;x++)if(g[y][x])bottom=Math.max(bottom,y);
  if(bottom<0||bottom===15)return g.map(r=>r.slice());
  const out=blankSpriteGrid(),shift=15-bottom;
  for(let y=0;y<16;y++)for(let x=0;x<16;x++)if(g[y][x])gridPut(out,x,y+shift,g[y][x]);
  return out;
}

export function makePlayer() {
  const base=(dir)=>{
    const g=blankSpriteGrid(),H=1,S=2,T=4,P=6,A=5,E=6,X=7;
    if(dir==='down'){
      gridBox(g,7,1,3,1,H);gridBox(g,6,2,5,1,H);gridBox(g,5,3,7,1,H);
      gridBox(g,5,4,7,3,H);gridBox(g,6,4,5,3,S);gridPut(g,7,5,H);gridPut(g,9,5,H);gridPut(g,8,6,X);
      gridBox(g,6,7,5,1,H);gridBox(g,4,8,8,5,T);gridBox(g,6,9,4,2,A);gridPut(g,3,10,S);gridPut(g,12,11,S);
      gridBox(g,5,13,3,2,P);gridBox(g,9,13,2,2,P);gridBox(g,4,15,4,1,E);gridBox(g,9,15,3,1,E);
    }else if(dir==='up'){
      gridBox(g,7,1,3,1,H);gridBox(g,6,2,5,1,H);gridBox(g,5,3,7,4,H);gridBox(g,7,4,2,3,X);
      gridBox(g,6,7,5,1,H);gridBox(g,4,8,8,5,T);gridLine(g,8,8,8,12,A);gridPut(g,3,11,S);gridPut(g,12,10,S);
      gridBox(g,5,13,3,2,P);gridBox(g,9,13,2,2,P);gridBox(g,4,15,4,1,E);gridBox(g,9,15,3,1,E);
    }else{
      gridBox(g,5,1,4,1,H);gridBox(g,4,2,6,1,H);gridBox(g,3,3,7,1,H);gridBox(g,3,4,7,3,H);
      gridBox(g,3,4,5,3,S);gridPut(g,4,5,H);gridPut(g,2,5,S);gridPut(g,7,6,X);gridBox(g,4,7,5,1,H);
      gridBox(g,4,8,6,5,T);gridBox(g,6,9,3,2,A);gridLine(g,4,10,2,12,S);gridPut(g,10,10,S);
      gridBox(g,5,13,2,2,P);gridBox(g,8,13,2,2,P);gridBox(g,4,15,3,1,E);gridBox(g,8,15,3,1,E);
    }
    return dir==='right'?mirrorGrid(g):g;
  };
  const step=(dir,frame)=>{
    const g=base(dir),S=2,T=4,P=6,E=6;
    if(frame===1){
      if(dir==='left'||dir==='right'){
        gridBox(g,3,10,2,2,0);gridLine(g,dir==='left'?4:11,10,dir==='left'?1:14,11,S);
        gridBox(g,4,13,3,2,0);gridBox(g,4,14,2,1,P);gridBox(g,3,15,4,1,E);
      }else{
        gridPut(g,3,10,0);gridLine(g,4,9,2,11,S);gridBox(g,5,13,3,3,0);gridBox(g,4,13,3,2,P);gridBox(g,3,15,4,1,E);
      }
    }else if(frame===2){
      gridPut(g,4,8,0);gridPut(g,11,8,0);gridPut(g,3,12,T);gridPut(g,12,12,T);gridBox(g,5,14,2,1,P);gridBox(g,9,14,2,1,P);
    }else if(frame===3){
      if(dir==='left'||dir==='right'){
        gridPut(g,10,10,0);gridLine(g,dir==='left'?9:6,10,dir==='left'?12:3,12,S);
        gridBox(g,8,13,3,3,0);gridBox(g,9,14,2,1,P);gridBox(g,9,15,4,1,E);
      }else{
        gridPut(g,12,11,0);gridLine(g,11,9,13,11,S);gridBox(g,9,13,3,3,0);gridBox(g,10,13,2,2,P);gridBox(g,9,15,4,1,E);
      }
    }
    return g;
  };
  const left=[0,1,2,3].map(f=>step('left',f));
  return {
    down:[0,1,2,3].map(f=>step('down',f)),
    up:[0,1,2,3].map(f=>step('up',f)),
    left,
    // Finish the left gait before mirroring it. Editing an already mirrored base produced
    // a second left leg on two frames and made rightward movement look like a limp.
    right:left.map(mirrorGrid),
  };
}

export function makePlayerAttack(player,dir,phase){
  const g=player[dir][0].map(r=>r.slice()),S=2,T=4;
  if(dir==='left'){gridBox(g,1,9,5,4,0);gridLine(g,5,9,phase?0:1,11,T);gridBox(g,phase?0:1,10,2,2,S);}
  if(dir==='right'){gridBox(g,10,9,5,4,0);gridLine(g,10,9,phase?15:14,11,T);gridBox(g,phase?14:13,10,2,2,S);}
  if(dir==='down'){gridLine(g,4,9,phase?7:5,13,T);gridBox(g,phase?7:5,12,2,2,S);gridPut(g,12,11,0);}
  if(dir==='up'){gridLine(g,11,9,phase?8:10,5,T);gridBox(g,phase?7:9,4,2,2,S);gridPut(g,3,11,0);}
  return g;
}

export function makePlayerGear(id,dir){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  if(id==='mesh_cap'){if(side){gridBox(g,3,1,7,2,6);gridBox(g,1,3,5,1,2);}else{gridBox(g,5,1,7,2,6);gridBox(g,4,3,8,1,2);}}
  else if(id==='ski_mask'){if(side){gridBox(g,3,3,7,4,1);gridPut(g,4,5,5);}else{gridBox(g,5,3,7,4,1);gridPut(g,7,5,5);gridPut(g,9,5,5);}}
  else if(id==='helmet'){if(side){gridBox(g,4,0,6,2,2);gridBox(g,2,2,8,1,4);}else{gridBox(g,6,0,5,2,2);gridBox(g,4,2,9,1,4);}}
  else if(id==='cowboy'){if(side){gridBox(g,4,0,5,2,4);gridBox(g,1,2,10,1,3);}else{gridBox(g,6,0,5,2,4);gridBox(g,3,2,10,1,3);}}
  else if(id==='pigeon_crown'){if(side){gridBox(g,3,2,8,1,2);gridPut(g,4,0,2);gridPut(g,7,0,2);gridPut(g,9,1,2);}else{gridBox(g,4,2,9,1,2);gridPut(g,5,0,2);gridPut(g,8,0,2);gridPut(g,11,0,2);gridPut(g,8,1,7);}}
  else if(id==='priest_collar'){if(side){gridBox(g,4,7,5,1,5);gridPut(g,5,7,1);}else{gridBox(g,5,7,7,1,5);gridBox(g,7,7,2,1,1);}}
  else if(id==='trench'){if(side){gridBox(g,4,8,7,6,3);gridLine(g,6,8,8,14,1);}else{gridBox(g,3,8,10,6,3);gridLine(g,5,8,8,14,1);gridLine(g,11,8,8,14,1);}}
  else if(id==='windbreaker'){if(side){gridBox(g,4,8,7,4,7);gridLine(g,5,9,9,9,2);}else{gridBox(g,3,8,10,4,7);gridLine(g,4,9,11,9,2);}}
  else if(id==='bathrobe'){if(side){gridBox(g,4,8,7,6,5);gridLine(g,5,8,8,12,7);gridBox(g,4,11,7,1,7);}else{gridBox(g,3,8,10,6,5);gridLine(g,4,8,8,12,7);gridLine(g,11,8,8,12,7);gridBox(g,3,11,10,1,7);}}
  else if(id==='parka'){if(side){gridBox(g,3,8,8,6,6);gridBox(g,3,8,8,1,2);}else{gridBox(g,2,8,12,6,6);gridBox(g,3,8,10,1,2);gridPut(g,2,10,2);gridPut(g,13,10,2);}}
  else if(id==='airpods'){if(side)gridBox(g,2,5,1,3,5);else gridBox(g,4,5,1,3,5);}
  else if(id==='crocs'){gridBox(g,3,15,4,1,3);}
  else if(id==='walmart_sneak'){gridBox(g,3,15,4,1,5);gridBox(g,9,15,4,1,5);gridPut(g,4,15,1);gridPut(g,10,15,1);}
  else if(id==='vibrams'){gridBox(g,3,15,4,1,4);gridBox(g,9,15,4,1,4);gridPut(g,3,15,2);gridPut(g,12,15,2);}
  else if(id==='propane_torch'){if(side){gridBox(g,10,10,3,5,4);gridPut(g,11,9,2);}else{gridBox(g,12,10,3,5,4);gridPut(g,13,9,2);}}
  return right?mirrorGrid(g):g;
}

export function makeRoutePatch(tier,dir){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  if(tier>=1)gridBox(g,5,9,2,2,2);
  if(tier>=2)gridBox(g,side?7:9,11,2,2,4);
  if(tier>=3)gridLine(g,side?4:3,12,side?8:5,12,7);
  if(tier>=4){gridBox(g,side?8:10,8,3,4,5);gridPut(g,side?9:11,9,1);gridPut(g,side?9:11,11,1);}
  return right?mirrorGrid(g):g;
}

export function makeWeaponLayer(id,dir,attack){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  let x1=side?(attack?0:1):12,y1=side?(attack?10:11):(attack?8:10),x2=side?6:14,y2=side?11:14;
  if(d==='down'){x1=attack?7:12;y1=attack?10:10;x2=attack?9:13;y2=15;}
  if(d==='up'){x1=attack?7:3;y1=attack?3:9;x2=attack?9:4;y2=attack?9:13;}
  const line=v=>gridLine(g,x1,y1,x2,y2,v);
  if(id==='fists'){
    // A tiny wrist + two knuckles. One isolated cream pixel read as sprite damage.
    gridBox(g,x1,y1,attack?3:2,2,5);gridPut(g,x1+(side?-1:2),y1+1,2);
  }
  else if(id==='pipe'){line(4);gridPut(g,x2,y2,2);}
  else if(id==='brick'){gridBox(g,x1,y1,3,3,3);gridPut(g,x1+1,y1+1,4);}
  else if(id==='cart_wheel'){
    const cx=x1+((d==='down'&&!attack)?1:2),cy=y1+2;
    for(let a=0;a<8;a++){const q=a*Math.PI/4;gridPut(g,Math.round(cx+Math.cos(q)*2),Math.round(cy+Math.sin(q)*2),5);}gridPut(g,cx,cy,1);
  }
  else if(id==='shoe'){gridLine(g,x1,y1,x2,y2,3);gridBox(g,x2-1,y2-1,3,2,3);}
  else if(id==='baguette'){line(5);gridPut(g,x1,y1,2);gridPut(g,x2,y2,2);}
  else if(id==='microphone'){line(1);gridBox(g,x1-1,y1-1,3,3,7);}
  else if(id==='knife'){gridLine(g,x1,y1,x2,y2,5);gridPut(g,x1,y1,3);gridPut(g,x1+1,y1,3);}
  else if(id==='broken_bottle'){gridLine(g,x1,y1,x2,y2,7);gridBox(g,x1-1,y1-1,3,3,4);gridPut(g,x2,y2,5);}
  return right?mirrorGrid(g):g;
}

export function makeAttackSmear(dir,phase){
  const g=blankSpriteGrid(),v=phase?4:2;
  if(dir==='right'){
    if(!phase){gridLine(g,5,5,11,7,v);gridLine(g,6,8,12,10,v);}else{gridLine(g,2,3,13,7,v);gridLine(g,4,8,15,11,v);gridPut(g,13,12,5);}
  }
  if(dir==='left'){
    if(!phase){gridLine(g,10,5,4,7,v);gridLine(g,9,8,3,10,v);}else{gridLine(g,13,3,2,7,v);gridLine(g,11,8,0,11,v);gridPut(g,2,12,5);}
  }
  if(dir==='down'){
    if(!phase){gridLine(g,5,4,7,10,v);gridLine(g,9,5,10,11,v);}else{gridLine(g,3,1,7,14,v);gridLine(g,9,3,12,15,v);gridPut(g,13,13,5);}
  }
  if(dir==='up'){
    if(!phase){gridLine(g,5,11,7,5,v);gridLine(g,9,10,10,4,v);}else{gridLine(g,3,14,7,1,v);gridLine(g,9,12,12,0,v);gridPut(g,13,2,5);}
  }
  return g;
}

export function makeCartUnderlay(dir){
  const g=blankSpriteGrid();
  gridLine(g,2,8,13,8,3);gridLine(g,3,13,12,13,2);gridLine(g,2,8,3,13,2);gridLine(g,13,8,12,13,2);
  for(let x=4;x<=11;x+=2)gridLine(g,x,9,x,12,2);
  gridLine(g,3,10,12,10,3);gridLine(g,3,12,12,12,3);
  gridBox(g,3,14,3,2,1);gridBox(g,10,14,3,2,1);putCartHub(g,4,14);putCartHub(g,11,14);
  if(dir==='left')gridLine(g,2,8,0,6,3);else if(dir==='right')gridLine(g,13,8,15,6,3);else gridLine(g,12,8,14,6,3);
  return g;
}

export function putCartHub(g,x,y){gridPut(g,x,y,4);gridPut(g,x+1,y+1,2);}

export function rasterize(grid, palette, opts={}) {
  // v15: paint on the true 16x16 logical grid, then scale once. The old 1-device-pixel
  // halo and shine created half-logical pixels that blurred every silhouette.
  const logical = document.createElement('canvas');
  logical.width = 16; logical.height = 16;
  const lg = logical.getContext('2d');
  lg.imageSmoothingEnabled = false;
  if (!opts.noOutline) {
    lg.fillStyle = 'rgba(0,0,0,.9)';
    for (let y=0;y<16;y++) for (let x=0;x<16;x++) {
      if (!grid[y] || grid[y][x] === 0) continue;
      lg.fillRect(x-1,y,1,1); lg.fillRect(x+1,y,1,1);
      lg.fillRect(x,y-1,1,1); lg.fillRect(x,y+1,1,1);
    }
  }
  for (let y=0;y<16;y++) for (let x=0;x<16;x++) {
    const idx = grid[y] ? grid[y][x] : 0;
    const col = palette[idx];
    if (!idx || !col || col === 'transparent') continue;
    lg.fillStyle = col;
    lg.fillRect(x,y,1,1);
  }
  const c = document.createElement('canvas');
  c.width = 32; c.height = 32;
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  g.drawImage(logical,0,0,32,32);
  return c;
}

export function makeDog() {
  const B=3, D=2, E=1, T=4, M=7;
  const f = (frame) => parseGrid(applyVars([
    '................',
    '...BBBB.........',
    '..BBBBBBB.......',
    '..BBM.MBBBBBB...',
    '..BBBBBBBBBBBB..',
    '.BBBBBBBBBBBBBT.',
    '..BBBBBBBBBBBB..',
    '..BBBBBBBBBBBB..',
    '..D..D...D..D...',
    '..D..D...D..D...',
    frame===0 ? '..D..D...D..D...' : '...D.....D......',
    frame===0 ? '..E..E...E..E...' : '...E..D..E..D...',
    frame===0 ? '................' : '..........E..E..',
    '................',
    '................',
    '................',
  ], {B:B, D:D, E:E, T:T, M:M}));
  return [f(0), f(1)];
}

export function applyDogSignature(kind, source, frame) {
  const g=source.map(row=>row.slice()),put=(x,y,v)=>{if(g[y]&&x>=0&&x<16)g[y][x]=v;};
  if(kind==='brutus'){
    put(4,3,5);put(6,3,1); // one cloudy eye. fourteen years is enough information.
    put(13,5,0);put(14,5,2);put(14,6,2);
  } else if(kind==='scrap_dog'){
    put(7,5,1);put(9,5,1);put(11,5,1);put(8,6,1);put(10,6,1); // ribs
    put(1,8,0);put(13,8,0);put(14,5,0);put(14,6,0);
    put(frame?14:13,7,2);put(frame?15:14,6,2); // the wag finally reaches the pixels
  } else if(kind==='os_brutus'){
    for(let x=4;x<12;x++)put(x,1,2);
    for(let x=2;x<14;x++)put(x,2,3);
    put(1,4,3);put(14,4,3);put(4,3,1);put(6,3,1);
  }
  return g;
}

export function makePigeon() {
  const f = (frame) => parseGrid(applyVars([
    '................',
    '.....C.C.C......',
    '.....CCCCC......',
    '......HHHO......',
    '.....HHHHHHF....',
    '....BBBBBBBB....',
    '...BBBBBBBBBB...',
    '...BBBBBBBBBB...',
    '....BBBBBBBB....',
    frame===0 ? '......F.F.......' : '......FF........',
    frame===0 ? '......F.F.......' : '......F.........',
    '................',
    '................',
    '................',
    '................',
    '................',
  ], {H:'2', O:'6', B:'3', F:'6', C:'7'}));
  return [f(0), f(1)];
}

export function makePossum() {
  const f = (frame) => parseGrid(applyVars([
    '................',
    '.....OOOOO......',
    '.....OPPPPO.....',
    '.....OPPPPO.....',
    '....HHHHHHH.....',
    '...HFFFFFFF.....',
    '..HFFOoOOoOF....',
    '..HFFFFFFFFFF...',
    '.HFFFFFFFFFFFF..',
    '.HFFFFFFFFFFFFt.',
    '..HFFFFFFFFFFF..',
    frame===0 ? '..D..D....D..D..' : '...D..D....D..D.',
    '................',
    '................',
    '................',
    '................',
  ], {O:'6', P:'7', H:'2', F:'4', o:'1', D:'3', t:'2'}));
  return [f(0), f(1)];
}

export function applyNpcSignature(id, g, frame) {
  const put=(x,y,v)=>{ if(y>=0&&y<16&&x>=0&&x<16) g[y][x]=v; };
  const line=(x1,y1,x2,y2,v)=>{
    const n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1));
    for(let i=0;i<=n;i++) put(Math.round(x1+(x2-x1)*(i/(n||1))),Math.round(y1+(y2-y1)*(i/(n||1))),v);
  };
  const box=(x,y,w,h,v)=>{for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)put(xx,yy,v);};
  const clear=(x,y,w,h)=>box(x,y,w,h,0);

  if (id === 'tony_coat_3' || id === 'tony') {
    box(2,8,2,5,4); box(12,8,2,5,4); line(5,8,7,12,7); line(10,8,8,12,7);
  } else if (id === 'tony_coat_2') {
    put(3,9,4); put(12,9,4); line(5,8,7,12,7); line(10,8,8,12,7);
  } else if (id === 'tony_coat_1') {
    clear(3,9,1,4); clear(12,9,1,4); line(6,8,7,12,7); line(9,8,8,12,7);
  } else if (id === 'tony_bare') {
    clear(3,8,2,5); clear(11,8,2,5); box(5,8,6,5,6); put(6,5,1); put(9,5,1);
  } else if (id === 'yuri') {
    // bald crown, square beard, and a hubcap held like an invoice.
    clear(5,1,6,2); box(6,2,4,1,4); box(5,6,6,2,2); put(7,6,4); put(9,6,4);
    line(11,9,13,10,2); put(13,9,5); put(14,10,5); put(13,11,5); put(12,10,5); put(13,10,1);
  } else if (id === 'pete') {
    // apron, chest pocket, and one rectangular hot-pocket unit.
    box(5,8,6,6,5); line(5,8,7,13,1); line(10,8,8,13,1); box(7,10,3,2,7);
    line(11,9,13,10,3); box(13,9,3,2,4); put(14,9,5);
  } else if (id === 'lurch' || id === 'biggu') {
    clear(3,10,2,3); clear(11,10,2,3); line(4,8,1,14,3); line(11,8,14,14,3);
    put(1,15,5); put(14,15,5); if(id==='biggu'){put(2,8,4);put(13,8,4);put(2,9,4);put(13,9,4);}
  } else if (id === 'sherri') {
    // hard hair spikes and a phone already halfway into the next conversation.
    put(4,0,2); put(6,0,2); put(9,0,2); put(11,1,2);
    line(3,9,1,12,4); line(12,9,14,7,4); box(14,5,2,4,7); put(2,13,5);
  } else if (id === 'paulie') {
    clear(3,1,10,7); box(4,1,8,1,2); box(3,2,10,6,4); box(4,3,8,4,5);
    box(5,4,2,2,1); box(9,4,2,2,1); box(6,7,4,1,1); box(13,10,2,3,6);
  } else if (id === 'mom') {
    // kombucha bottle, label, and sensible little shoes.
    line(11,9,13,10,4); box(13,8,2,5,6); put(14,7,7); put(13,10,5);
    box(4,15,3,1,5); box(10,15,3,1,5);
  } else if (id === 'priest') {
    box(7,7,2,1,7); line(7,9,7,12,6); line(6,10,8,10,6);
  } else if (id === 'priest_fallen') {
    clear(7,7,2,1); line(2,8,5,13,6); line(13,8,10,13,6); put(6,5,7); put(9,5,7); box(7,6,2,1,1);
  } else if (id === 'conductor') {
    box(4,0,8,2,1); box(3,2,10,1,2); put(8,1,5);
    line(10,9,13,11,5); box(13,10,3,3,7); line(13,11,15,11,1);
  } else if (id === 'larry') {
    box(6,5,4,3,1); box(7,5,2,1,5); put(6,7,5); put(9,7,5);
    line(3,9,0,7,6); line(12,9,15,7,6); put(0,6,5); put(15,6,5);
  } else if (id === 'stripe') {
    // hood aperture, one severe diagonal stripe, and the suspicious soap package.
    box(5,3,6,4,1); box(6,4,4,3,5); put(7,5,1); put(9,5,1);
    line(3,8,11,13,5); line(4,8,12,13,7); box(13,10,3,3,6); put(14,11,7);
  } else if (id === 'cubscout') {
    line(5,8,10,12,5); box(13,10,2,3,6);
  } else if (id === 'jogger') {
    line(4,9,2,11,4); line(11,9,14,8,4); if(frame) put(13,14,0);
  } else if (id === 'busker') {
    line(4,8,11,14,2); box(9,10,4,3,4);
  } else if (id === 'dogwalker') {
    line(12,11,15,14,2); put(14,14,4); put(15,14,4); put(15,13,5);
  } else if (id === 'vapelord') {
    box(3,8,2,4,2); put(13,6,6); put(14,5,6);
  } else if (id === 'mayorscousin') {
    box(5,13,2,3,5); box(9,13,2,3,5);
  } else if (id === 'phoneguy') {
    box(12,5,2,4,7); put(11,8,5);
  } else if (id === 'launderlady') {
    box(4,10,8,3,7); line(5,11,10,11,6);
  } else if (id === 'metermaid') {
    box(12,9,3,4,5); line(12,10,14,10,7);
  } else if (id === 'foodtruck') {
    box(5,9,6,5,5); line(12,8,15,11,7);
  } else if (id === 'priestson') {
    line(4,2,11,2,1); put(4,1,1);
  } else if (id === 'karaoke') {
    box(4,10,8,4,2); box(6,11,4,1,6);
  } else if (id === 'barb') {
    box(3,9,10,5,7); line(5,10,10,10,1); line(5,12,9,12,1); put(12,8+(frame?1:0),5);
  } else if (id === 'pinky') {
    line(4,1,11,1,1); line(5,8,5,13,5); line(10,8,10,13,5);
  } else if (id === 'math') {
    box(11,9,4,5,7); line(12,10,14,10,1); line(12,12,14,12,1);
  } else if (id === 'brendan') {
    line(12,8,15,9,7); put(15,8,6); put(14,7,6);
  } else if (id === 'train_hopper') {
    box(3,7,2,6,7); put(2,8,7); line(11,8,13,13,2);
  } else if (id === 'philosopher') {
    line(12,8,14,15,2); put(14,15,1); box(3,9,2,3,7);
  } else if (id === 'lease_guy') {
    // Clipboard on one side, an unreasonable key ring on the other.
    box(11,8,4,6,7);line(12,9,14,9,1);line(12,11,14,11,1);
    line(4,9,2,12,6);put(1,12,6);put(2,13,6);put(3,12,6);put(2,11,6);put(2,12,1);
  } else if (id === 'gutter_greg') {
    // Crooked hook plus the rubber duck he has entered as inventory.
    line(3,8,1,14,7);put(2,15,7);box(12,10,3,3,6);put(13,9,6);put(15,11,5);
  } else if (id === 'blue_tarp_guard') {
    clear(2,0,12,5);box(3,0,10,3,2);line(2,3,13,3,2);box(3,3,2,6,2);put(4,2,5);put(11,2,5);put(12,4,7);
  } else if (id === 'receipt_guard') {
    line(4,7,11,14,2);line(5,7,12,14,2);box(12,8,3,6,2);put(13,10,1);put(14,10,1);put(12,12,5);put(14,13,1);
  } else if (id === 'wire_guard') {
    line(4,9,11,9,5);line(4,11,11,11,5);line(5,13,10,13,5);box(12,8,3,5,7);line(13,12,15,15,5);
  } else if (id === 'darryl_under_blue') {
    clear(1,0,14,13);box(2,0,12,3,2);line(1,3,14,3,2);box(1,3,3,10,2);box(12,3,3,10,2);box(5,4,6,4,3);put(3,2,5);put(12,2,5);put(7,5,1);put(9,5,1);
  } else if (id === 'general_receipt') {
    clear(2,0,12,4);line(3,2,7,0,2);line(8,0,12,2,2);line(3,2,12,2,2);box(2,8,3,4,2);box(11,8,3,4,2);box(6,8,4,5,2);put(7,9,1);put(8,9,1);put(7,11,7);put(8,11,7);box(13,11,3,5,2);
  } else if (id === 'bishop_wire') {
    clear(4,0,8,4);line(5,3,7,0,5);line(10,3,8,0,5);line(7,0,8,0,7);line(12,7,14,15,5);put(13,6,5);put(15,8,5);box(6,7,4,1,7);line(4,10,11,10,5);line(4,12,11,12,5);
  } else if (id === 'curb_emperor') {
    clear(1,0,14,4);box(3,2,10,2,2);put(3,0,2);put(6,1,2);put(9,0,2);put(12,1,2);box(1,8,4,4,2);box(11,8,4,4,2);line(4,8,11,14,5);line(13,8,15,14,7);box(14,7,2,2,5);
  } else if (id === 'price_guy') {
    box(3,1,10,2,1); box(4,7,8,8,2); put(7,5,7);
  }
  return g;
}

export function makeSleepingDave() {
  const f=(frame)=>parseGrid([
    '................','................','................','................',
    '................','................','................','................',
    '..........222...','...111...2333...','..15511115555...','..55555556666...',
    '.6666666666666..','..66..66..66....',frame?'...7.......7....':'..7.........7...','................'
  ]);
  return [f(0),f(1)];
}

export function makeNPC(opts={}) {
  const H = opts.hat ?? 1, S = opts.skin ?? 3, T = opts.shirt ?? 4, P = opts.pants ?? 6, A = opts.accent ?? 5;
  const C2 = opts.shirt2 ?? T;
  const ACC = opts.accColor ?? 5;
  const E = 6; // boots/feet color index
  const isWide = opts.wide, isTall = opts.tall, isThin = opts.thin;
  const isBald = opts.bald, isHood = opts.hood;
  const isYell = opts.yelling, hasBeard = opts.beard;
  const cap = opts.cap;
  const coats = opts.coats ?? 1;
  const accessory = opts.accessory;

  const f = (frame) => {
    // head row layout
    let headTop = '......HHHH......';
    let headW1  = '.....HHHHHH.....';
    if (isTall) { headTop = '.......HH.......'; headW1 = '......HHHH......'; }
    if (cap) {
      headTop = '....HHHHHHHHHH..';
      headW1  = '....HHHHHHHHHH..';
    }
    if (isHood) {
      headTop = '.....HHHHHH.....';
      headW1  = '....HHHHHHHH....';
    }
    let row3 = isBald ? '.....SSSSSS.....' : '.....HHHHHH.....';
    let row4 = '.....SSSSSS.....';
    let eyes = isYell ? '.....SOOOOS.....' : '.....SeSeS......';
    let row6 = '.....SSSSSS.....';
    if (hasBeard) row6 = '.....HSHHSH.....';
    if (isHood) { row3 = '.....HHHHHH.....'; row4 = '.....HSSSSH.....'; eyes = '.....HSeSeH.....'; row6 = '.....HSSSSH.....'; }
    // body
    let body = [
      '................',
      headTop,
      headW1,
      row3,
      row4,
      eyes,
      row6,
      isWide ? '....TTTTTTTTTT..' : '....TTTTTTTT....',
      coats >= 2 ? '....CCTTTTTTCC..' : '....TTAAAATT....',
      coats >= 3 ? '...CCCCTTTTCCC..' : '...TTTTTTTTT....',
      '...STTTTTTTTS...',
      isWide ? '...STTTTTTTTTS..' : '...STTTTTTTS....',
      '....TTTTTTTT....',
      '....PPPPPPPP....',
      '....PP....PP....',
      '....EE....EE....',
    ];
    if (isThin) {
      body[7]  = '.....TTTTTT.....';
      body[8]  = '....TTAATT......';
      body[9]  = '....TTTTTT......';
      body[10] = '....STTTTS......';
      body[11] = '....STTTTS......';
      body[12] = '.....TTTT.......';
      body[13] = '.....PPPP.......';
      body[14] = '.....P..P.......';
      body[15] = '.....E..E.......';
    }
    // walk frames — staggered legs
    if (frame === 1) {
      body[14] = isThin ? '.....PP.P.......' : '....PPP.PPPP....';
      body[15] = isThin ? '.....EE..P......' : '....EE.....P....';
    } else if (frame === 2) {
      body[14] = isThin ? '.....P.PP.......' : '....PPPP.PPP....';
      body[15] = isThin ? '.....P..EE......' : '....P.....EE....';
    }
    // accessory overlays
    if (accessory === 'cross') {
      body[9]  = '...TTTTAATTT....';
      body[11] = '...STTTAATTS....';
    }
    if (accessory === 'kombucha') {
      body[11] = '...STTTTTTTKS...'.replace(/K/g, A);
      body[12] = '....TTTTTTTK....'.replace(/K/g, A);
    }
    if (accessory === 'badge') {
      body[9] = '....TTAAAATB....'.replace(/B/g, ACC);
    }
    if (accessory === 'sash') {
      body[9] = '....AATTTTAA....';
      body[10] = '...TAATTTTAAT...';
    }
    if (accessory === 'glasses') {
      // square wire-frame glasses — accent frames bracketing each eye, skin nose bridge between
      body[5] = '....ASeASeSA....';
      body[4] = '.....AAAAAA.....';
    }
    if (isTall) {
      body[0]=body[1]; body[1]=body[2]; body[2]=body[3]; body[3]=body[4];
      body[4]=body[5]; body[5]=body[6]; body[6]='.....TTTTTT.....';
      body[13]='.....PPPP.......';
      body[14]=frame===1?'.....PP.P.......':frame===2?'.....P.PP.......':'.....P..P.......';
      body[15]=frame===1?'.....EE.P.......':frame===2?'.....P.EE.......':'.....E..E.......';
    }
    body = applyVars(body, {H:H, S:S, T:T, P:P, A:A, E:E, C:C2, O:'1', e:'1'});
    return applyNpcSignature(opts.signature||'', parseGrid(body), frame);
  };
  return [f(0), f(1), f(2)];
}

export function buildSprites() {
  // v17 player — four-beat shuffle, two attack poses, visible equipment, weapons and route patches.
  const p = makePlayer();
  ['down','up','left','right'].forEach(d => {
    p[d].forEach((g,i) => {
      SPRITE_CACHE['player_'+d+'_'+i] = rasterize(g, PALS.player);
      SPRITE_CACHE['playerhi_'+d+'_'+i] = rasterize(g, PALS.player_high);
    });
    for(let phase=0;phase<2;phase++){
      const attack=makePlayerAttack(p,d,phase);
      SPRITE_CACHE['playerattack_'+d+'_'+phase]=rasterize(attack,PALS.player);
      SPRITE_CACHE['playerattackhi_'+d+'_'+phase]=rasterize(attack,PALS.player_high);
      SPRITE_CACHE['attack_smear_'+d+'_'+phase]=rasterize(makeAttackSmear(d,phase),PLAYER_LAYER_PAL,{noOutline:true});
    }
    for(const id of Object.keys(EQUIPMENT)){
      SPRITE_CACHE['gear_'+id+'_'+d]=rasterize(makePlayerGear(id,d),PLAYER_LAYER_PAL,{noOutline:true});
    }
    for(const id of Object.keys(WEAPONS)){
      SPRITE_CACHE['weapon_'+id+'_'+d+'_0']=rasterize(makeWeaponLayer(id,d,false),PLAYER_LAYER_PAL,{noOutline:id==='fists'});
      SPRITE_CACHE['weapon_'+id+'_'+d+'_1']=rasterize(makeWeaponLayer(id,d,true),PLAYER_LAYER_PAL,{noOutline:id==='fists'});
    }
    for(let tier=1;tier<=4;tier++){
      SPRITE_CACHE['route_patch_'+tier+'_'+d]=rasterize(makeRoutePatch(tier,d),PLAYER_LAYER_PAL,{noOutline:true});
    }
    SPRITE_CACHE['cart_underlay_'+d]=rasterize(makeCartUnderlay(d),CART_LAYER_PAL,{noOutline:true});
  });
  // NPCs — distinctive styles, 3-frame walks
  const npcStyles = {
    tony:      { hat:6, skin:3, shirt:4, pants:6, accent:5, coats:3, shirt2:7 },          // three coats, never blinks
    yuri:      { hat:6, skin:3, shirt:2, pants:6, accent:5, bald:true, beard:true },      // bald, beard
    pete:      { hat:2, skin:3, shirt:6, pants:5, accent:4, wide:true },                  // wide, behind glass
    lurch:     { hat:1, skin:3, shirt:6, pants:6, accent:5, tall:true },                  // 7ft tall
    sherri:    { hat:6, skin:3, shirt:6, pants:2, accent:5, thin:true },                  // thin, fast
    paulie:    { hat:1, skin:4, shirt:3, pants:6, accent:5 },                             // the face
    dave:      { hat:2, skin:3, shirt:6, pants:6, accent:5 },                             // sleeps
    mom:       { hat:6, skin:5, shirt:4, pants:5, accent:6, accessory:'kombucha' },       // kombucha
    priest:    { hat:1, skin:5, shirt:1, pants:1, accent:6, accessory:'cross' },          // collar + cross
    conductor: { hat:6, skin:3, shirt:6, pants:1, accent:5, cap:true },                   // train cap
    larry:     { hat:5, skin:3, shirt:6, pants:2, accent:4, yelling:true, wide:true },    // YELLING
    stripe:    { hat:5, skin:3, shirt:6, pants:2, accent:4, hood:true },                  // hood up
    cop:       { hat:3, skin:5, shirt:3, pants:1, accent:7, cap:true, accessory:'badge', accColor:5 },
    biggu:     { hat:5, skin:3, shirt:6, pants:6, accent:5, tall:true, wide:true },       // tall AND big
    cubscout:  { hat:5, skin:5, shirt:4, pants:1, accent:7, accessory:'sash', thin:true },
    jogger:    { hat:5, skin:5, shirt:4, pants:1, accent:7, thin:true },
    busker:    { hat:5, skin:3, shirt:4, pants:6, accent:7 },
    dogwalker: { hat:6, skin:5, shirt:4, pants:1, accent:6 },
    vapelord:  { hat:5, skin:3, shirt:2, pants:1, accent:6, hood:true, accessory:'kombucha' },
    mayorscousin: { hat:1, skin:3, shirt:6, pants:1, accent:5, coats:2, shirt2:5 },
    phoneguy:  { hat:5, skin:3, shirt:2, pants:6, accent:7, thin:true },
    launderlady: { hat:6, skin:5, shirt:4, pants:1, accent:6, wide:true },
    metermaid: { hat:6, skin:5, shirt:4, pants:1, accent:6, cap:true, accessory:'badge', accColor:5 },
    foodtruck: { hat:5, skin:3, shirt:6, pants:6, accent:5, wide:true, accessory:'badge' },
    priestson: { hat:5, skin:5, shirt:2, pants:1, accent:6, thin:true, cap:true },
    karaoke:   { hat:5, skin:3, shirt:6, pants:2, accent:4 },
    // v13 wave 2
    barb:      { hat:2, skin:3, shirt:4, pants:6, accent:5, wide:true },
    pinky:     { hat:2, skin:3, shirt:4, pants:6, accent:5, thin:true },
    math:      { hat:2, skin:3, shirt:4, pants:6, accent:5, thin:true, accessory:'glasses' },
    brendan:   { hat:3, skin:5, shirt:3, pants:6, accent:7, cap:true, accessory:'badge', accColor:5, thin:true },
    // v13 wave 8a — train hopper: wiry, gray beard, faded jacket. accessory shows the backpack on his back via accent color.
    train_hopper: { hat:2, skin:3, shirt:3, pants:6, accent:7, thin:true, beard:true },
    // v13 wave 8a — philosopher: kindly old woman, gray hair under a hat, brown coat
    philosopher:  { hat:6, skin:5, shirt:2, pants:6, accent:7, wide:true },
    lease_guy:    { hat:2, skin:5, shirt:3, pants:1, accent:7, cap:true, wide:true },
    gutter_greg:  { hat:2, skin:4, shirt:3, pants:7, accent:6, thin:true, beard:true },
    blue_tarp_guard:   {hat:2,skin:3,shirt:4,pants:6,accent:5,hood:true,wide:true},
    receipt_guard:     {hat:7,skin:3,shirt:4,pants:6,accent:2,cap:true,accessory:'sash'},
    wire_guard:        {hat:1,skin:3,shirt:4,pants:6,accent:5,thin:true,beard:true},
    darryl_under_blue: {hat:2,skin:3,shirt:4,pants:6,accent:5,hood:true,wide:true,coats:2,shirt2:2},
    general_receipt:   {hat:2,skin:3,shirt:4,pants:6,accent:7,cap:true,wide:true,coats:2,shirt2:2},
    bishop_wire:       {hat:5,skin:3,shirt:4,pants:6,accent:7,tall:true,beard:true},
    curb_emperor:      {hat:2,skin:3,shirt:4,pants:6,accent:5,wide:true,yelling:true,coats:3,shirt2:2},
    // v13 wave 8a — price guy: silhouette in a black coat. brim hat. unsettling.
    price_guy:    { hat:1, skin:4, shirt:3, pants:3, accent:6, hood:true },
    // v13 wave 8a — old school brutus reuses the dog sprite (handled below), this entry not used
  };
  Object.entries(npcStyles).forEach(([k, opts]) => {
    const frames = makeNPC({...opts, signature:k});
    frames.forEach((g, i) => {
      SPRITE_CACHE[k+'_'+i] = rasterize(g, PALS[k] || PALS.tony);
    });
  });
  // v15 readable state art: Dave lies down; Tony's contractually numbered coats actually
  // leave his body; Fallen O'Malley no longer relies on n.color that cached art ignores.
  makeSleepingDave().forEach((g,i)=>{ SPRITE_CACHE['dave_sleep_'+i]=rasterize(anchorGridToBottom(g),PALS.dave); });
  const tonyStates = [
    ['tony_coat_2', {...npcStyles.tony, coats:2, signature:'tony_coat_2'}],
    ['tony_coat_1', {...npcStyles.tony, coats:1, signature:'tony_coat_1'}],
    ['tony_bare',   {...npcStyles.tony, coats:1, signature:'tony_bare'}],
  ];
  for (const [key,def] of tonyStates) makeNPC(def).forEach((g,i)=>{
    SPRITE_CACHE[key+'_'+i]=rasterize(g,PALS.tony);
  });
  makeNPC({...npcStyles.priest, coats:1, signature:'priest_fallen'}).forEach((g,i)=>{
    SPRITE_CACHE['priest_fallen_'+i]=rasterize(g,PALS.priest_fallen);
  });
  // possum, brutus, pigeon — special silhouettes, 2-frame
  const possum = makePossum();
  possum.forEach((g,i) => { SPRITE_CACHE['possum_'+i] = rasterize(anchorGridToBottom(g), PALS.possum); });
  const dog = makeDog();
  dog.forEach((g,i) => { SPRITE_CACHE['brutus_'+i] = rasterize(anchorGridToBottom(applyDogSignature('brutus',g,i)), PALS.brutus); });
  // v13 wave 6 — scrap_dog reuses the dog shape with a different (mangier) palette
  dog.forEach((g,i) => { SPRITE_CACHE['scrap_dog_'+i] = rasterize(anchorGridToBottom(applyDogSignature('scrap_dog',g,i)), PALS.scrap_dog); });
  // v13 wave 8a — old school brutus reuses the dog shape with the deeper-rust palette. boss-tier.
  dog.forEach((g,i) => { SPRITE_CACHE['os_brutus_'+i] = rasterize(anchorGridToBottom(applyDogSignature('os_brutus',g,i)), PALS.os_brutus); });
  const pig = makePigeon();
  pig.forEach((g,i) => { SPRITE_CACHE['pigeon_'+i] = rasterize(anchorGridToBottom(g), PALS.pigeon); });

  // horse cop — horse with cop on top (special)
  const hc = makeHorseCop();
  hc.forEach((g,i) => { SPRITE_CACHE['horsecop_'+i] = rasterize(anchorGridToBottom(g), PALS.horsecop); });
  // pothole — a hole that talks
  SPRITE_CACHE['pothole_0'] = rasterize(makePothole(0), PALS.pothole);
  SPRITE_CACHE['pothole_1'] = rasterize(makePothole(1), PALS.pothole);
  SPRITE_CACHE['pothole_2'] = rasterize(makePothole(2), PALS.pothole);
  buildIncidentSprites();
}

export function buildIncidentSprites() {
  const defs={
    incident_mattress:[
      [
        '................','................','...1111111111...','..122222222221..',
        '.12333333333321.','.12343333333421.','.12333333333321.','.12333333333321.',
        '.12333333333321.','.12343333333421.','.12333333333321.','..122222222221..',
        '...1111111111...','....6......6....','................','................'
      ],
      [
        '................','................','....111111111...','...12222222221..',
        '..1233333333321.','..1234333333421.','..1233333333321.','..1233333333321.',
        '..1233333333321.','..1234333333421.','..1233333333321.','...12222222221..',
        '....111111111...','...6......6.....','................','................'
      ]
    ],
    incident_forklift:[
      [
        '................','................','.....3333.......','....333333......',
        '....311113......','....311113......','....333333......','...222233333....',
        '..2222233333....','..2222233333.11.','..2222233333.11.','..4444444444.11.',
        '.41111111111411.','..11......11.11.','..66......66....','................'
      ],
      [
        '................','................','.....3333.......','....333333......',
        '....311113......','....311113......','....333333......','...222233333....',
        '..2222233333.11.','..2222233333.11.','..2222233333.11.','..4444444444.11.',
        '.41111111111411.','...11....11..11.','...66....66.....','................'
      ]
    ],
    incident_dryer:[
      [
        '................','....11111111....','...1222222221...','...1233333321...',
        '...1234444321...','...1241111421...','...1241551421...','...1241551421...',
        '...1241111421...','...1234444321...','...1233333321...','...1222222221...',
        '...1222222221...','...1111111111...','....6......6....','................'
      ],
      [
        '................','.....11111111...','....1222222221..','....1233333321..',
        '....1234444321..','....1241111421..','....1241551421..','....1241551421..',
        '....1241111421..','....1234444321..','....1233333321..','....1222222221..',
        '....1222222221..','....1111111111..','.....6......6...','................'
      ]
    ],
    incident_suitcase:[
      [
        '................','......1111......','.....122221.....','.....1....1.....',
        '...1111111111...','..122222222221..','..123333333321..','..123333333321..',
        '..123336633321..','..123336633321..','..123333333321..','..123333333321..',
        '..122222222221..','...1111111111...','....7......7....','................'
      ],
      [
        '................','.......1111.....','......122221....','......1....1....',
        '....1111111111..','...122222222221.','...123333333321.','...123333333321.',
        '...123336633321.','...123336633321.','...123333333321.','...123333333321.',
        '...122222222221.','....1111111111..','.....7......7...','................'
      ]
    ],
    incident_sprinkler:[
      [
        '................','................','................','...........44...',
        '..........444...','.....1111144....','....1222221.....','....1233321.....',
        '....1233321.....','....1233321.....','....1233321.....','....1222221.....',
        '...111111111....','..12222222221...','..11111111111...','................'
      ],
      [
        '................','................','................','...44...........',
        '...444..........','....4411111.....','.....1222221....','.....1233321....',
        '.....1233321....','.....1233321....','.....1233321....','.....1222221....',
        '....111111111...','...12222222221..','...11111111111..','................'
      ]
    ],
  };
  for(const [key,frames] of Object.entries(defs)) frames.forEach((rows,i)=>{
    SPRITE_CACHE[key+'_'+i]=rasterize(parseGrid(rows),INCIDENT_PALS[key.slice(9)]);
  });
}

export function makeHorseCop() {
  // 16x16 sprite, horse body + cop torso on top
  const f = (frame) => parseGrid(applyVars([
    '...HHHH.........', // cop hat
    '...HHHH.........',
    '....SSSS........', // cop face
    '....SeSe........',
    '....cccc........', // cop torso
    '...cBccBc.......', // badge
    '...cccccc.......',
    '..HHHHHHHHH.....', // horse back
    '..HHHHHHHHHHH...',
    '.HHHHHHHHHHHHM..',
    '.HHHHHHHHHHHHH..',
    '.HHHHHHHHHHHHH..',
    frame===0 ? '.DD..D.D..D.D...' : '.D.D.DD..DD.D...',
    frame===0 ? '.DD..D.D..D.D...' : '.D.D.DD..DD.D...',
    '.EE..E.E..E.E...',
    '................',
  ], {H:'6', S:'5', e:'1', c:'3', B:'7', M:'7', D:'3', E:'1'}));
  return [f(0), f(1)];
}

export function makePothole(frame) {
  // dark oval, slightly animating shape (it's TALKING)
  const open = frame === 1 ? 'eeee' : (frame === 2 ? 'EEEE' : 'eEEe');
  return parseGrid(applyVars([
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....2222.......',
    '....222222......',
    '...22XXXX22.....'.replace(/XXXX/g, open),
    '...22XXXX22.....'.replace(/XXXX/g, open),
    '....222222......',
    '.....2222.......',
    '................',
    '................',
    '................',
    '................',
  ], {e:'1', E:'1'}));
}

export function init_sprites() {
  // ---------- NPCs canonical data ----------
  // pixel-art sprite as palette-indexed strings (16x16)
  PALS = {
    player: ['transparent','#2a1f10','#604020','#a07050','#e8c040','#d4c896','#1a1810','#3a2820'],
    player_high: ['transparent','#5a4020','#a07020','#e8c040','#fff0a0','#fff8d0','#3a2810','#7a5020'],
    tony: ['transparent','#1a0805','#3a1818','#5a2820','#8a3a3a','#d4c896','#603020','#000'],
    yuri: ['transparent','#1a1008','#4a2818','#8a3a18','#d4c896','#e8c040','#5a3018','#000'],
    brutus: ['transparent','#000','#3a2018','#603020','#a07050','#1a0805','#d4c896','#8a3018'],
    pete: ['transparent','#1a1008','#4a4028','#8a7050','#d4c896','#604020','#a08840','#000'],
    lurch: ['transparent','#1a0810','#3a2030','#604040','#a07060','#d4c896','#2a1810','#d4c896'],
    sherri: ['transparent','#1a0808','#3a1820','#603030','#a05050','#d4c896','#d488d4','#000'],
    paulie: ['transparent','#1a0808','#5a3030','#8a5050','#d4a880','#d4c896','#603020','#000'],
    dave: ['transparent','#1a1008','#3a2818','#604020','#a07050','#d4c896','#88663a','#000'],
    mom: ['transparent','#1a0810','#503040','#80a050','#a8c030','#d4c896','#d488d4','#d4c896'],
    possum: ['transparent','#1a0805','#3a2820','#604030','#a08868','#d4c896','#e8c040','#a07020'],
    priest: ['transparent','#000','#1a1020','#2a2030','#4a3040','#d4c896','#d488d4','#d4c896'],
    priest_fallen: ['transparent','#050306','#160b18','#321438','#5a205f','#d4c896','#8a3a78','#e8c040'],
    conductor: ['transparent','#1a1010','#3a2820','#604030','#a07050','#d4c896','#8a3a3a','#604030'],
    larry: ['transparent','#1a0808','#3a1818','#8a3030','#d4c896','#e8c040','#d06030','#d4c896'],
    stripe: ['transparent','#0a0a18','#1a1828','#3a3848','#7a7888','#d4c896','#e8c040','#d4d4d4'],
    pigeon: ['transparent','#1a1810','#3a3828','#605840','#888070','#d4c896','#d06030','#e8c040'],
    cop: ['transparent','#000','#080820','#1818a0','#2828d0','#d4c896','#e8c040','#d4c896'],
    biggu: ['transparent','#1a1008','#3a2818','#604030','#a08060','#d4c896','#604020','#000'],
    horsecop: ['transparent','#000','#080820','#1818a0','#2828d0','#d4c896','#604030','#d4c896'],
    vapelord: ['transparent','#1a0820','#3a1850','#603080','#a050c0','#d4c896','#d488d4','#d4c896'],
    mayorscousin: ['transparent','#1a1008','#3a2818','#604030','#a07050','#d4c896','#8a3a3a','#d4c896'],
    phoneguy: ['transparent','#1a1008','#3a2818','#604030','#a07050','#d4c896','#88c0ff','#d4c896'],
    pothole: ['transparent','#000','#0a0805','#1a1810','#2a2818','#3a3828','#604020','#d4c896'],
    launderlady: ['transparent','#1a0820','#3a3a44','#605a70','#a09abd','#d4c896','#88c0ff','#d4c896'],
    metermaid: ['transparent','#1a1810','#3a3818','#605828','#a8c030','#d4c896','#8a3a3a','#d4c896'],
    foodtruck: ['transparent','#1a0805','#3a1810','#603020','#a04830','#d4c896','#d06030','#d4c896'],
    priestson: ['transparent','#1a0820','#2a2030','#4a3040','#80708a','#d4c896','#88c0ff','#d4c896'],
    karaoke: ['transparent','#1a0820','#3a1850','#603080','#a050c0','#d4c896','#e8c040','#d4c896'],
    // v13 wave 2 — converting the last four emoji-era styles and giving barb her own skin
    cubscout: ['transparent','#1a1810','#2828a8','#e8c0a0','#2a5028','#e8c040','#20202a','#d4c896'],
    jogger: ['transparent','#1a0810','#c8a850','#f0c8b0','#d488d4','#f8a8c8','#1a1a20','#d4c896'],
    busker: ['transparent','#1a1008','#5a3018','#d4a878','#8a6840','#604030','#283848','#d4c896'],
    dogwalker: ['transparent','#1a1010','#604020','#e8c8a8','#e8a880','#88c0ff','#4a4848','#d4c896'],
    barb: ['transparent','#20182a','#b0a8a0','#c0a890','#8a6080','#c898c0','#4a3040','#d4c896'],
    pinky: ['transparent','#0a0805','#180810','#c08850','#c8b070','#e8c040','#2a1810','#d4c896'],
    math: ['transparent','#0a0a08','#2a1810','#b09078','#c8b8a0','#6a6a5a','#6a5a4a','#d4c896'],
    brendan: ['transparent','#000','#0a0a28','#2838c0','#4048e8','#f4d8b8','#181828','#d4c896'],
    // v13 wave 6 — scrap_dog: scrappy brown + black, mangier than brutus
    scrap_dog: ['transparent','#000','#3a2010','#4a2810','#684830','#a08040','#d4c896','#181010'],
    // v13 wave 8a — train hopper: faded denim jacket + gray beard + dusty backpack
    train_hopper: ['transparent','#0a0805','#3a3a4a','#5a5a78','#8a8898','#d4c896','#3a2818','#a09080'],
    // v13 wave 8a — park bench philosopher: gray hair + brown coat + kindly face
    philosopher:  ['transparent','#0a0805','#604838','#8a7868','#c8c0b8','#d4c896','#3a2820','#88a08c'],
    // v13 wave 8a — price guy: black coat + hat brim + a stillness about him. mostly silhouette.
    price_guy:    ['transparent','#000','#0a0808','#181818','#2a2a2a','#d4c896','#5a3030','#d4c896'],
    lease_guy:    ['transparent','#15100a','#3a3024','#6a5840','#9a8058','#d4c896','#c08038','#88c0ff'],
    gutter_greg:  ['transparent','#10120f','#29382f','#496050','#7a8060','#d4c896','#e8c040','#3a2818'],
    // v19 rival courts. Slate blue avoids the bright cop-only blue language.
    blue_tarp_guard: ['transparent','#111418','#34485a','#9a6848','#263540','#e8c040','#2a2118','#6a7b80'],
    receipt_guard: ['transparent','#17130d','#d4c896','#9a6848','#5a4b38','#8a3a3a','#2a241c','#9a9270'],
    wire_guard: ['transparent','#100b08','#4a5028','#8a5b3a','#33251d','#d06030','#201814','#8a3a3a'],
    darryl_under_blue: ['transparent','#0b0e10','#2f4658','#a07050','#1d2b34','#e8c040','#2a2018','#7890a0'],
    general_receipt: ['transparent','#15110d','#d4c896','#a07050','#604c30','#e8c040','#302820','#8a3a3a'],
    bishop_wire: ['transparent','#0b0907','#2e241c','#a07050','#4a5028','#d06030','#211812','#d4c896'],
    curb_emperor: ['transparent','#0a0805','#5a5548','#9a6848','#8a3a3a','#e8c040','#1a1810','#d06030'],
    // v13 wave 8a — old school brutus: bigger brutus palette w/ deeper rust + darker accents
    os_brutus:    ['transparent','#000','#2a1810','#4a2818','#604030','#1a0805','#a08040','#5a2010'],
  };
  
  // 16x16 pixel art helpers — parse a row string of 0-7 (dot=transparent)
  
  
  
  // player sprites — 4 directions, 3 walk frames each (idle / left-step / right-step)
  
  
  
  
  
  
  
  // v17: real directional silhouettes and a four-beat uneven shuffle.
  
  
  
  
  PLAYER_LAYER_PAL=['transparent','#0a0805','#e8c040','#8a3a3a','#d06030','#d4c896','#4a5028','#d488d4'];
  
  
  
  
  
  CART_LAYER_PAL=['transparent','#0a0805','#66665e','#9a988b','#d4c896'];
  
  
  
  // Render palette-indexed sprite to a 32×32 offscreen canvas (16×16 scaled 2x)
  // v10: adds automatic outline (1px black around all opaque pixels) and shading
  // (lighter pixel on top-left of each colored region) for a more polished look.
  
  
  // Quadruped (Brutus) — 14 year old mostly blind dog. 2-frame trot.
  
  
  
  
  // Pigeon — small, one foot per VIBE
  
  
  // Possum — flat brown lump, dignified, tiny construction helmet
  
  
  // v15 authored identity layer. These are still edits to the 16x16 palette grid, not
  // runtime drawing. Shared bodies keep the roster coherent; silhouette/held-object pixels
  // carry the joke before a nameplate is read.
  
  
  
  
  // Generic humanoid NPC with style options
  // opts:
  //   hat,skin,shirt,pants,accent  — palette indices (1-7)
  //   tall: bool (add rows up top)
  //   wide: bool (extend body sides)
  //   bald: bool (flatter head, skin showing)
  //   yelling: bool (open mouth)
  //   hood: bool (hood drape over face)
  //   coats: 1-3 (layered shirts/colors)
  //   cap: bool (square hat top)
  //   accessory: 'cross' | 'pipe' | 'kombucha' | 'badge' | 'sash' | null
  //   beard: bool
  //   thin: bool (narrower body)
  
  
  // Build the SPRITE_CACHE
  SPRITE_CACHE = {};
  
  
  INCIDENT_PALS = {
    mattress:['transparent','#1a1008','#8a6840','#d4c896','#6a4a35','#e8c040','#3a2818','#8a3a3a'],
    forklift:['transparent','#17130f','#5a4828','#e8c040','#a07020','#d4c896','#604020','#8a3a3a'],
    dryer:['transparent','#17130f','#4a4848','#8a8880','#b0aaa0','#88c0ff','#604020','#d4c896'],
    suitcase:['transparent','#17130f','#3a2818','#6a4828','#a07020','#d4c896','#8a3a3a','#e8c040'],
    sprinkler:['transparent','#172018','#3a5030','#6a7860','#88c0ff','#d4c896','#305878','#e8c040'],
  };
  
  
  
  
  
  
  
}

export let audio, SAVE_KEY;

export async function saveGame() {
  try {
    await window.storage.set(SAVE_KEY, {
      version: 10,
      player: {
        x: P.x, y: P.y, hp: P.hp, cash: P.cash, rocks: P.rocks, copper: P.copper, supplies: P.supplies||0, dirtySupplies: P.dirtySupplies||0, shakes: P.shakes,
        cred: P.cred, brain: P.brain, wanted: P.wanted, rank: P.rank,
        inventory: P.inventory, lifetime: P.lifetime, tonyOffenses: P.tonyOffenses,
        equip: P.equip, cartMounted: P.cartMounted,
        weapon: P.weapon, brutusDefeated: P.brutusDefeated, stripeLoyalty: P.stripeLoyalty,
        charisma: P.charisma||0,
        soapRocks: P.soapRocks||0,
        // v13 wave 7 — faction reputation
        faction: P.faction || { street: 0, scrap: 0, spiritual: 0 },
      },
      npcsKilled: runtime.npcs.filter(n=>n.dead&&!n.transient&&!n.kingdomGuard&&!n.kingdomPretender).map(n=>n.id),
      cashPilesCollected: Array.from(state.cashPilesCollected),
      achievements: Array.from(state.achievements),
      counters: state.counters,
      quests: state.quests,
      hustles: state.hustles || [],
      hustleSnapshot: state.hustleSnapshot || {},
      blockRoute: validBlockRoute(state.blockRoute) ? state.blockRoute : null,
      office: state.office || freshOfficeState(),
      districtClaims: state.districtClaims || {},
      kingdom: state.kingdom || freshKingdomState(),
      day: state.day,
      dayTime: state.dayTime,
      weather: state.weather,
      lootedDumpsters: PROPS.filter(p=>p.type==='dumpster' && p.looted).map(p=>p.x+','+p.y),
      barbAside: !!state.barbAside,
      // v13 wave 3
      metVendors: Array.from(state.metVendors || []),
      flags: state.flags || {},
      crownPickup: state.crownPickup || null,
      // v13 wave 6 — graffiti layout + phone counter (quest state lives inside state.quests)
      graffiti: state.graffiti || null,
      // v13 wave 8b — poster layout (procedural, persisted like graffiti)
      posters: state.posters || null,
      publicPhoneAnswered: state.publicPhoneAnswered || 0,
      // v13 wave 7 — hideout stash survives death; flags carry day-event triggers
      hideoutStash: state.hideoutStash || { rocks:0, copper:0, cash:0, items:[] },
    });
  } catch(e) {}
}

export async function loadGame() {
  try {
    const s = await window.storage.get(SAVE_KEY);
    if (!s || !s.value || s.value.version < 8) return false;
    const sv = s.value;
    Object.assign(P, sv.player);
    P.attackCd = 0; P.hitFlash = 0; P.iframes = 0;
    P.facing = P.facing || 'down';
    P.supplies = P.supplies || 0;
    P.dirtySupplies = Math.min(P.dirtySupplies || 0, P.supplies);
    P.lifetime.rocksCooked = P.lifetime.rocksCooked || 0;
    P.lifetime.rocksFenced = P.lifetime.rocksFenced || 0;
    P.lifetime.routesCompleted = P.lifetime.routesCompleted || 0;
    P.lifetime.officeJobs = officeNat(P.lifetime.officeJobs);
    P.lifetime.territoriesClaimed = officeNat(P.lifetime.territoriesClaimed,CLAIM_SITES.length);
    P.lifetime.pretendersDefeated = officeNat(P.lifetime.pretendersDefeated);
    P.equip = Object.assign({ shoes:null, hat:null, coat:null, tool:null }, P.equip || {});
    P.soapRocks = Math.max(0, P.soapRocks||0);
    // v13 wave 5 — status timers are ephemeral; never restored from save (start clean).
    P.stunT = 0; P.slowT = 0;
    // v13 wave 7 — faction reputation; old saves default all to 0 (neutral).
    P.faction = Object.assign({ street: 0, scrap: 0, spiritual: 0 }, (sv.player && sv.player.faction) || {});
    // NPC definitions are instantiated in startGame(), after loadGame() returns. Hold the
    // durable ids until that spawn boundary instead of applying them to the empty title array.
    state.loadedNpcDeaths = new Set(Array.isArray(sv.npcsKilled)?sv.npcsKilled.filter(id=>typeof id==='string'):[]);
    state.cashPilesCollected = new Set(sv.cashPilesCollected || []);
    state.achievements = new Set(sv.achievements || []);
    state.counters = Object.assign({
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0, pigeonTrade: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0, introCashEarned: 0,
      // v13 wave 5 — fallen priest counters
      priestVisits: 0, plateStealAttempts: 0, churchVisits: 0, omalleyFallenSurviveT: 0,
      // v13 wave 6.5 — economy gate counters. defaults 0 keep old saves working;
      // *Today fields reset at dawn via resetDailyCounters(); *Day fields self-reset.
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      // v13 wave 8a — philosopher gives +1 spiritual once/day; gated by day-stamp counter.
      philosopherRepDay: 0,
      gutterInventoryDay: 0,
    }, sv.counters || {});
    state.barbAside = !!sv.barbAside;
    state.quests = Object.assign({}, state.quests, sv.quests || {});
    state.hustles = Array.isArray(sv.hustles) ? sv.hustles : null;
    state.hustleSnapshot = (sv.hustleSnapshot && typeof sv.hustleSnapshot==='object') ? sv.hustleSnapshot : null;
    state.blockRoute = validBlockRoute(sv.blockRoute) ? {
      stops:sv.blockRoute.stops.slice(),cursor:sv.blockRoute.cursor,serial:sv.blockRoute.serial||1,lastStopId:sv.blockRoute.lastStopId||''
    } : null;
    state.districtClaims = normalizeDistrictClaims(sv.districtClaims);
    state.office = normalizeOfficeState(sv.office,state.districtClaims);
    state.office.jobsCompleted = Math.max(officeNat(P.lifetime.officeJobs),state.office.jobsCompleted||0);
    state.office.orderSerial = Math.max(state.office.orderSerial||0,state.office.jobsCompleted,state.office.workJob?state.office.workJob.serial:0);
    if(state.office.jobsCompleted>0)state.office.upgrades.radio=true;
    P.lifetime.officeJobs = state.office.jobsCompleted;
    const officeQuest=state.quests.office_space,paperQuest=state.quests.paper_empire,regionalQuest=state.quests.regional_office,allQuest=state.quests.all_business;
    const paperWitness=officeNat(P.lifetime.territoriesClaimed,CLAIM_SITES.length)>0
      ||!!(paperQuest&&paperQuest.done)||!!(regionalQuest&&regionalQuest.done)||!!(allQuest&&allQuest.done)
      ||['zoning_error','regional_office','middle_management','paper_everywhere'].some(id=>state.achievements.has(id));
    const officePurchased=state.office.owned||state.office.jobsCompleted>0||paperWitness
      ||!!(officeQuest&&officeQuest.done)||state.achievements.has('squatters_rights');
    if(officePurchased){
      state.office.owned=true;
      if(paperWitness)state.office.upgrades.desk=true;
      if(officeQuest){officeQuest.done=true;officeQuest.available=true;}
      if(state.quests.paper_empire&&!state.quests.paper_empire.done)state.quests.paper_empire.available=true;
      state.achievements.add('squatters_rights');
    }
    P.lifetime.territoriesClaimed = claimedDistrictIds().length;
    // v13 wave 3 — discoverability + flags + crown state. existing saves default to introDone=true.
    state.metVendors = new Set(sv.metVendors || []);
    state.flags = Object.assign({
      introDone: true, momIntroFired: true, hasStripePackage: false,
      stripeBetrayed: false, daveHasCrossword: false, hasCrossword: false, crownSpotIdx: -1,
      // v13 wave 4 — pete keeps the torch stocked once rank>=3. peteTorchSold flips on first buy.
      peteTorchStocked: false, peteTorchSold: false,
      // v13 wave 5 — fallen priest
      omalleyFallen: false, omalleyFallenDead: false, fallenPriestCallFired: false,
      // v13 wave 6 — map-depth flags. underpassEntered defaults to true on old saves
      // so they don't get the first-entry toast on reload.
      underpassEntered: true, dumpsterPropaneAwarded: false,
      churchLoadedDumpsterX: 0, churchLoadedDumpsterY: 0,
      // v13 wave 7 — day events + hideouts + tier-effect day flags
      day3Fired: false, day7Fired: false, day14Fired: false, day30Fired: false,
      day14Collected: false, busTaken: false, busRefused: false,
      silenceUntilT: 0,
      scrapHideoutOwned: false, momHideoutOwned: false,
      momRentDay: 0, scrapLoanDay: 0, momProudCallDay: 0,
      // v13 wave 8a — world expansion + new zones. Old saves default-to-true on the entry
      // flags so the first-entry toast doesn't fire on reload (matches the underpass pattern).
      trainYardEntered: true, parkEntered: true, skidRowEntered: true, oldSchoolEntered: true,
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      trainHopperTalkedTo: false,
      priceGuyDay: 0, priceGuyVisits: 0,
      parkNightCashDay: 0,
      // v13 wave 8b — loved-district ambient lines are once-per-day-per-faction; track per save.
      // bus pass cooldown is once-per-day (cleared at dawn). mom's free pass drop is once-per-day too.
      lovedAmbient_street_day: 0, lovedAmbient_scrap_day: 0, lovedAmbient_spiritual_day: 0,
      busPassUsedDay: 0, momBusPassDay: 0,
      // v15 incident history (active scene state is never serialized)
      incidentDay: 0, incidentMask: 0, incidentsToday: 0, lastIncidentId: '',
    }, sv.flags || {});
    const rawKingdom=(sv.kingdom&&typeof sv.kingdom==='object')?{...sv.kingdom}:{};
    const witnessedDefeats=new Set(Array.isArray(rawKingdom.defeats)?rawKingdom.defeats:[]);
    if((state.quests.blue_weather&&state.quests.blue_weather.done)||state.flags.blueTarpCleared)witnessedDefeats.add('darryl_under_blue');
    if((state.quests.cart_appeal&&state.quests.cart_appeal.done)||state.flags.cartKeepCleared)witnessedDefeats.add('general_receipt');
    if((state.quests.copper_mass&&state.quests.copper_mass.done)||state.flags.copperChoirCleared)witnessedDefeats.add('bishop_wire');
    if((state.quests.one_cracklord&&state.quests.one_cracklord.done)||state.achievements.has('one_cracklord')||state.flags.throneDitchCleared)witnessedDefeats.add('curb_emperor');
    rawKingdom.defeats=Array.from(witnessedDefeats);
    const raiseRawKingdomStage=stage=>{
      const current=KINGDOM_STAGE_RANK[rawKingdom.stage]||0,target=KINGDOM_STAGE_RANK[stage]||0;
      if(target>current)rawKingdom.stage=stage;
    };
    if(state.quests.hostile_correspondence&&state.quests.hostile_correspondence.done)raiseRawKingdomStage('tarp_marks');
    if(state.quests.royal_static&&state.quests.royal_static.done)raiseRawKingdomStage('emperor_gate');
    if(witnessedDefeats.has('curb_emperor'))rawKingdom.stage='complete';
    state.kingdom=normalizeKingdomState(rawKingdom,true);
    state.kingdom.pretendersDefeated=Math.max(state.kingdom.pretendersDefeated,P.lifetime.pretendersDefeated);
    P.lifetime.pretendersDefeated=state.kingdom.pretendersDefeated;
    state.flags.blueTarpCleared=state.flags.blueTarpCleared||state.kingdom.defeats.includes('darryl_under_blue');
    state.flags.cartKeepCleared=state.flags.cartKeepCleared||state.kingdom.defeats.includes('general_receipt');
    state.flags.copperChoirCleared=state.flags.copperChoirCleared||state.kingdom.defeats.includes('bishop_wire');
    state.flags.throneDitchCleared=state.flags.throneDitchCleared||state.kingdom.defeats.includes('curb_emperor');
    syncKingdomQuests();
    state.bossActive=false;state.bossKind='';state.bossPhase=0;state.bossNPC=null;state.kingdomBattle=null;
    state.incident = null;
    state.incidentT = 35000 + Math.random()*20000;
    state.incidentPaperT = 0;
    state.incidentWetT = 0;
    // v13 wave 7 — hideout storage chest survives death. default empty.
    state.hideoutStash = Object.assign({ rocks:0, copper:0, cash:0, items:[] }, sv.hideoutStash || {});
    state.dayEventActor = null; // ephemeral visit/bus NPC; rebuilt per session if conditions match
    state.crownPickup = sv.crownPickup || null;
    // v13 wave 6 — restore graffiti layout + phone counter; if missing, leave null so a fresh layout
    // gets built on next drawGraffiti call (existing saves get one-time fresh tags — fine, decorative).
    state.graffiti = sv.graffiti || null;
    // v13 wave 8b — posters re-hydrate like graffiti. Missing -> fresh build on next draw.
    state.posters = sv.posters || null;
    state.publicPhoneAnswered = sv.publicPhoneAnswered || 0;
    P.charisma = sv.player && sv.player.charisma || 0;
    state.day = sv.day ?? 1;
    state.dayTime = sv.dayTime ?? 0;
    state.weather = sv.weather || 'clear';
    const looted = new Set(sv.lootedDumpsters || []);
    PROPS.filter(p=>p.type==='dumpster').forEach(p => { if (looted.has(p.x+','+p.y)) p.looted = true; });
    return true;
  } catch(e) { return false; }
}

export function init_audio_save() {
  // ---------- audio ----------
  audio = {
    ctx: null,
    ready: false,
    muted: false,
    init() {
      if (this.ready) return;
      try {
        this.ctx = new (window.AudioContext || window.webkitAudioContext)();
        this.ready = true;
      } catch(e) {}
    },
    tone(freq, dur=0.1, type='square', vol=0.08, slide=null) {
      if (!this.ready || this.muted) return;
      const t = this.ctx.currentTime;
      const o = this.ctx.createOscillator();
      const g = this.ctx.createGain();
      o.type = type;
      o.frequency.setValueAtTime(freq, t);
      if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(slide,20), t+dur);
      g.gain.setValueAtTime(vol, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t+dur);
      o.connect(g).connect(this.ctx.destination);
      o.start(t); o.stop(t+dur+0.02);
    },
    noise(dur=0.08, vol=0.06) {
      if (!this.ready || this.muted) return;
      const t = this.ctx.currentTime;
      const buf = this.ctx.createBuffer(1, this.ctx.sampleRate*dur, this.ctx.sampleRate);
      const d = buf.getChannelData(0);
      for (let i=0;i<d.length;i++) d[i] = (Math.random()*2-1) * (1 - i/d.length);
      const s = this.ctx.createBufferSource();
      s.buffer = buf;
      const g = this.ctx.createGain();
      g.gain.value = vol;
      s.connect(g).connect(this.ctx.destination);
      s.start(t);
    },
    hit() { this.tone(180,.08,'square',.1,60); this.noise(.06,.08); },
    hurt() { this.tone(220,.18,'sawtooth',.1,80); },
    pickup() { this.tone(800,.06,'square',.07); setTimeout(()=>this.tone(1200,.06,'square',.07),60); },
    coin() { this.tone(494,.08,'square',.08); setTimeout(()=>this.tone(659,.12,'square',.08),80); },
    rockUp() {
      [440, 554, 659, 880].forEach((f,i)=> setTimeout(()=>this.tone(f,.18,'triangle',.09), i*100));
    },
    crash() { this.tone(440,.6,'sawtooth',.08,110); },
    death() {
      [440,330,247,165].forEach((f,i)=> setTimeout(()=>this.tone(f,.32,'sawtooth',.09), i*220));
    },
    rankUp() {
      [523,659,784,1047].forEach((f,i)=> setTimeout(()=>this.tone(f,.16,'square',.08), i*80));
    },
    dialogue() { this.tone(660,.04,'square',.05); },
    copSiren() { this.tone(900,.18,'sine',.06,500); setTimeout(()=>this.tone(500,.18,'sine',.06,900),200); },
    bossRoar() { this.tone(80,.45,'sawtooth',.12,40); this.noise(.35,.1); },
    glassBreak() {
      for (let i=0;i<6;i++) setTimeout(()=>this.tone(2000+Math.random()*2000,.05,'square',.05,800), i*30);
      this.noise(.2,.08);
    },
    cricket() { this.tone(2200+Math.random()*400, .04, 'triangle', .025, 1800); },
    traffic() { this.tone(60+Math.random()*30, .35, 'sawtooth', .025, 40); },
    carDoor() { this.tone(120, .08, 'square', .04, 80); this.tone(80, .06, 'sawtooth', .03, 50); },
    cough() { this.noise(.12, .03); this.tone(220+Math.random()*40, .08, 'sawtooth', .03, 110); },
    dogBark() { this.tone(280, .06, 'square', .04, 180); setTimeout(()=>this.tone(240,.06,'square',.04,160), 80); },
    // v13 wave 5 — combat depth cues
    windup() { this.tone(150,.45,'sawtooth',.06,70); this.noise(.25,.03); },
    bottleThrow() { this.tone(360,.07,'square',.05,260); },
    bottleHit() { for (let i=0;i<5;i++) setTimeout(()=>this.tone(1800+Math.random()*1600,.04,'square',.04,800), i*22); this.noise(.08,.04); },
    holyWaterThrow() { this.tone(660,.10,'triangle',.05); setTimeout(()=>this.tone(880,.08,'triangle',.04),50); },
    holyWaterHit() { this.tone(440,.16,'sine',.05,220); this.tone(880,.20,'sine',.04,660); this.noise(.08,.03); },
    radio() { this.tone(1600,.03,'square',.04); setTimeout(()=>this.tone(1200,.04,'square',.03),40); this.noise(.04,.02); },
    // v13 wave 6 — short percussive thump for kicked trash can
    kick() { this.tone(80,.10,'square',.07,40); this.noise(.08,.05); },
  };
  
  // ---------- save/load ----------
  SAVE_KEY = 'rockbottom_save_v8';
  
  
  
  
}

export let P, particles, state, toastEl, toastTimer, dialogueEl, activeDialogue, panelEl;

export const runtime = Object.create(null);

export function unlockAchievement(id) {
  if (state.achievements.has(id)) return;
  if (!ACHIEVEMENTS[id]) return;
  state.achievements.add(id);
  toast('· ACHIEVEMENT ·\n'+ACHIEVEMENTS[id].name, 3000);
  audio.rankUp();
  saveGame();
}

export function applyEquipStats() {
  let baseSpeed = 2.2;
  let baseHp = P.cartMounted ? 110 : 100;
  let credBonus = 0;
  let charisma = 0;
  let wantedDecayMult = 1.0;
  for (const slot in P.equip) {
    const id = P.equip[slot];
    if (!id || !EQUIPMENT[id]) continue;
    const e = EQUIPMENT[id];
    baseSpeed += (e.speed||0);
    baseHp += (e.hp||0);
    credBonus += (e.cred||0);
    charisma += (e.charisma||0);
    wantedDecayMult += (e.wantedDecay||0);
  }
  // v13 wave 8b — cart speed cap. Was +0.6 flat (v12 was +1, ~2.0 base). Now caps at base × 1.7
  // so the cart scales with the (now larger) world without breaking equipment stacking.
  if (P.cartMounted) baseSpeed = Math.min(baseSpeed * 1.7, baseSpeed + 1.5);
  P.speed = Math.max(0.8, baseSpeed);
  P.maxHp = baseHp;
  if (P.hp > P.maxHp) P.hp = P.maxHp;
  P.credBonus = credBonus;
  P.charisma = charisma;
  // v13 wave 5 — priest's collar shaves time off the wanted decay clock.
  P.wantedDecayMult = wantedDecayMult;
}

export function rollWeather() {
  const r = Math.random();
  if (r < 0.65) state.weather = 'clear';
  else if (r < 0.88) state.weather = 'rain';
  else state.weather = 'fog';
}

export function toast(msg, ms=2200) {
  toastEl.textContent = msg;
  toastEl.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.remove('show'), ms);
}

export function dialogue(name, text, opts) {
  hideGuidance();
  activeDialogue = { name, text, opts };
  releaseAllInput(); // release keyboard + analog movement when dialogue opens
  dialogueEl.innerHTML = `<div class="name">${name}</div><div class="text">${text}</div><div class="opts"></div>`;
  const optsBox = dialogueEl.querySelector('.opts');
  opts.forEach((o, i) => {
    const div = document.createElement('div');
    div.className = 'opt' + (o.disabled ? ' disabled' : '');
    div.innerHTML = `<b>${i+1}.</b> ${o.label}`;
    div.onclick = () => { if (!o.disabled) { audio.dialogue(); closeDialogue(); o.action && o.action(); } };
    optsBox.appendChild(div);
  });
  dialogueEl.classList.add('show');
  state.mode = 'dialogue';
}

export function closeDialogue() {
  activeDialogue = null;
  dialogueEl.classList.remove('show');
  releaseAllInput(); // and clear on close so no ghost movement
  if (state.mode === 'dialogue') state.mode = 'playing';
}

export function renderInventory() {
  hideGuidance();
  const r = RANKS[P.rank];
  const lt = P.lifetime;
  const eq = P.equip;
  const slotLabel = (slot) => {
    const id = eq[slot];
    if (!id || !EQUIPMENT[id]) return '<span style="color:#665">(none)</span>';
    return EQUIPMENT[id].n;
  };
  const achList = Object.entries(ACHIEVEMENTS).map(([k,a]) => {
    const got = state.achievements.has(k);
    return `<div class="row" style="${got?'':'opacity:.35'}"><span>${got?'✓':'·'} ${a.name}</span><span style="color:#776;font-size:9px">${a.flav}</span></div>`;
  }).join('');
  panelEl.innerHTML = `
    <h2>INVENTORY · ${r.name.toUpperCase()}</h2>
    <div class="row"><span>cash</span><span>$${P.cash}</span></div>
    <div class="row"><span>rocks</span><span>🪨 ${(P.rocks||0) + (P.soapRocks||0)}</span></div>
    <div class="row"><span>pure copper</span><span>🪙 ${P.copper}</span></div>
    <div class="row"><span>raw supplies</span><span>🧪 ${P.supplies||0}${(P.dirtySupplies||0)>0 ? ` (${P.dirtySupplies} house cut)` : ''}</span></div>
    <div class="row"><span>hp</span><span>${Math.round(P.hp)} / ${P.maxHp}</span></div>
    <div class="row"><span>shakes</span><span>${P.shakes.toFixed(0)}</span></div>
    <div class="row"><span>brain</span><span>${P.brain.toFixed(0)}</span></div>
    <div class="row"><span>cred</span><span>${P.cred}${P.credBonus?` (+${P.credBonus})`:''}</span></div>
    <div class="row"><span>wanted</span><span>${'★'.repeat(P.wanted)||'-'}</span></div>
    <div class="row"><span>cart</span><span>${P.cartMounted?'mounted':'-'}</span></div>
    <div class="sec">EQUIPMENT</div>
    <div class="row"><span>weapon</span><span>${WEAPONS[P.weapon||'fists'].n}</span></div>
    <div class="row"><span>hat</span><span>${slotLabel('hat')}</span></div>
    <div class="row"><span>coat</span><span>${slotLabel('coat')}</span></div>
    <div class="row"><span>shoes</span><span>${slotLabel('shoes')}</span></div>
    <div class="row"><span>tool</span><span>${slotLabel('tool')}</span></div>
    <div class="sec">ITEMS</div>
    ${P.inventory.length ? P.inventory.map(i=>`<div class="row"><span>${i.n}</span><span>x${i.q||1}</span></div>`).join('') : '<div class="row"><span>nothing</span><span>(yet)</span></div>'}
    <div class="sec">LIFETIME</div>
    <div class="row"><span>rocks smoked</span><span>${lt.rocksSmoked||0}</span></div>
    <div class="row"><span>rocks cooked</span><span>${lt.rocksCooked||0}</span></div>
    <div class="row"><span>rocks fenced</span><span>${lt.rocksFenced||0}</span></div>
    <div class="row"><span>block routes filed</span><span>${lt.routesCompleted||0}</span></div>
    <div class="row"><span>office orders filed</span><span>${lt.officeJobs||0}</span></div>
    <div class="row"><span>districts entered</span><span>${lt.territoriesClaimed||0}/${CLAIM_SITES.length}</span></div>
    <div class="row"><span>cops killed</span><span>${lt.copsKilled||0}</span></div>
    <div class="row"><span>arrests</span><span>${lt.arrests||0}</span></div>
    <div class="row"><span>day</span><span>${state.day}</span></div>
    <div class="row"><span>weather</span><span>${state.weather}</span></div>
    <div class="sec">CURSED ACCOLADES · ${state.achievements.size}/${Object.keys(ACHIEVEMENTS).length}</div>
    ${achList}
    <div class="close">[ i / esc ] close</div>`;
  panelEl.classList.add('show');
}

export function renderQuests() {
  hideGuidance();
  const qs = Object.values(state.quests);
  // a quest is ACTIVE if (a) not done, AND (b) either no `available` field or available===true,
  // AND (c) not an undone intro that depends on a prior intro step still incomplete.
  const isActive = (q) => !q.done && (q.available === undefined || q.available === true);
  const isAvailableButLatent = (q) => !q.done && q.available === false;
  const introFocused=state.flags&&!state.flags.introDone;
  const visibleDuringIntro=q=>!introFocused||!!q.intro;
  const active   = qs.filter(q=>isActive(q)&&visibleDuringIntro(q));
  const latent   = qs.filter(q=>isAvailableButLatent(q)&&visibleDuringIntro(q));
  const done     = qs.filter(q=>q.done&&visibleDuringIntro(q));
  const hustles  = state.hustles || [];
  // reward preview map — purely cosmetic, mirrors the in-line rewards in the actual handlers.
  const QUEST_REWARDS = {
    intro_remember:  '+1 cred',
    intro_tony:      '+1 cred',
    intro_smoke:     '+2 cred',
    pigeon_crown:    'the crown (cursed hat)',
    stripe_package:  '$40 + 3 cred OR a brick. depends.',
    barb_crossword:  '+ 1 clean packet',
    first_rock:      '—',
    copper_sings:    '—',
    finisher:        '—',
    conductor:       '—',
    priest_mercy:    '—',
    fallen_king:     'the corner',
    office_space:    'one office key',
    paper_empire:    'one bent sign · zoning error entered',
    regional_office: 'a larger administrative problem',
    all_business:    'all eleven forms agree with themselves',
    hostile_correspondence:'one hostile frequency',
    blue_weather:    '$24 + 18 cred · one bent seal',
    cart_appeal:     '$30 + 22 cred · one longer receipt',
    copper_mass:     '$36 + 26 cred · b flat entered',
    royal_static:    'the throne ditch answers',
    one_cracklord:   '$60 + 40 cred · one folding chair',
  };
  const renderQ = (q, key) => {
    const r = QUEST_REWARDS[key] || '—';
    return `<div class="quest ${q.done?'done':''}">
      <div class="qtitle">${q.done?'✓ ':'· '}${q.title}</div>
      <div class="qflav">${q.flav}${q.done?'':`\n<span style="color:#776">reward: ${r}</span>`}</div>
    </div>`;
  };
  // build people-met list (uses the canonical VENDOR_INDEX_META — only met vendors appear)
  const metKeys = Array.from(state.metVendors || []);
  const peopleHtml = metKeys.length === 0
    ? '<div class="quest"><div class="qflav" style="color:#776">no one yet. walk.</div></div>'
    : metKeys
        .filter(k => VENDOR_INDEX_META[k])
        .map(k => {
          const m = VENDOR_INDEX_META[k];
          const nm = (npcs.find(n=>n.id===k)||{}).name || k.toUpperCase();
          return `<div class="quest">
            <div class="qtitle">${nm}</div>
            <div class="qflav">${m.zone}\n<span style="color:#776">${m.tag}</span></div>
          </div>`;
        }).join('');
  // pair quest keys back so renderQ can pick the right reward
  const qPairs = Object.entries(state.quests);
  const activePairs = qPairs.filter(([_,q]) => isActive(q)&&visibleDuringIntro(q));
  const latentPairs = qPairs.filter(([_,q]) => isAvailableButLatent(q)&&visibleDuringIntro(q));
  const donePairs   = qPairs.filter(([_,q]) => q.done&&visibleDuringIntro(q));
  // v13 wave 7 — faction reputation block. tier label + bar (rep ∈ [-50, +50])
  const factionRow = (key) => {
    const v = (P.faction && P.faction[key]) | 0;
    const tier = factionTier(v);
    const pct = Math.max(0, Math.min(100, ((v + 50) / 100) * 100));
    const color = (tier === 'liked' || tier === 'loved') ? '#7fa055'
                : (tier === 'hated') ? '#a0554a'
                : '#776';
    return `<div class="quest" style="padding:6px 10px">
      <div class="qtitle" style="display:flex;justify-content:space-between">
        <span>${key.toUpperCase()}</span>
        <span style="color:${color}">${FACTION_TIER_LABELS[tier]} · ${v>=0?'+':''}${v}</span>
      </div>
      <div style="margin-top:4px;height:5px;background:#1a1a18;border:1px solid #2a2a26;position:relative">
        <div style="position:absolute;left:50%;top:0;bottom:0;width:1px;background:#3a3a34"></div>
        <div style="position:absolute;top:0;bottom:0;left:${v<0?pct:50}%;width:${Math.abs(pct-50)}%;background:${color};opacity:.7"></div>
      </div>
    </div>`;
  };
  const factionHtml = `
    <h2>FACTIONS</h2>
    ${factionRow('street')}
    ${factionRow('scrap')}
    ${factionRow('spiritual')}
    <div style="color:#776;font-size:11px;padding:0 10px 6px 10px">hated · neutral · liked · loved</div>
  `;
  const now=currentPrimaryObjective();
  const route=validBlockRoute(state.blockRoute)?state.blockRoute:null;
  const routeHtml=route?route.stops.map((id,i)=>{const s=ROUTE_STOP_BY_ID[id];return `<div class="quest ${i<route.cursor?'done':''}">
      <div class="qtitle">${i<route.cursor?'✓':'·'} ${i+1}. ${s.task}</div><div class="qflav">${s.zone}${i===route.cursor?' · NOW':''}</div></div>`;}).join('')
    : '<div class="quest"><div class="qflav">finish the first loop. the clipboard is under a brick.</div></div>';
  const office=state.office||freshOfficeState(),claimIds=claimedDistrictIds(),officeUnlocked=office.owned||(state.quests.office_space&&state.quests.office_space.available===true);
  const officeWorkToday=office.workDay===state.day?(office.workToday||0):0;
  const activePaper=office.claimJob
    ? 'claim · '+CLAIM_SITE_BY_ID[office.claimJob.id].name.toLowerCase()+' · '+office.claimJob.stage
    : office.workJob?'order '+office.workJob.serial+' · '+CLAIM_SITE_BY_ID[office.workJob.id].name.toLowerCase()+' · '+office.workJob.stage
    : 'none accepted';
  const officeHtml=office.owned?`<div class="quest">
      <div class="qtitle">OWNED · ${claimIds.length}/${CLAIM_SITES.length} DISTRICTS · ${officeUpgradeCount()}/${OFFICE_UPGRADE_DEFS.length} UPGRADES</div>
      <div class="qflav">active: ${activePaper}\norders: ${officeWorkToday}/${officeDailyCap()} today · ${office.jobsCompleted||0} lifetime</div>
    </div>
    <div class="quest"><div class="qflav">${CLAIM_SITES.map(d=>(state.districtClaims&&state.districtClaims[d.id]?'✓ ':'· ')+d.name.toLowerCase()).join(' · ')}</div></div>`
    :`<div class="quest"><div class="qtitle">${officeUnlocked?'THE LEASING GUY HAS A KEY':'LOCKED · FILE 3 BLOCK ROUTES'}</div>
      <div class="qflav">routes ${(P.lifetime.routesCompleted||0)}/3 · the lot · $40 + 1 pure copper</div></div>`;
  const kingdom=state.kingdom||freshKingdomState(),kingdomClan=kingdomStageClan(kingdom.stage);
  const kingdomSeals=(kingdom.defeats||[]).filter(id=>id!=='curb_emperor').length;
  const kingdomReq=`${state.quests.fallen_king&&state.quests.fallen_king.done?'✓':'·'} fallen king · ${office.owned?'✓':'·'} office · ${claimIds.length>=4?'✓':'·'} claims ${Math.min(4,claimIds.length)}/4`;
  const kingdomHtml=kingdom.stage==='locked'
    ? `<div class="quest"><div class="qtitle">LOCKED · LOCAL THRONE UNSETTLED</div><div class="qflav">${kingdomReq}</div></div>`
    : `<div class="quest"><div class="qtitle">${kingdom.stage==='complete'?'ONE CRACKLORD · CHAIR OCCUPIED':'ACTIVE · '+kingdom.stage.replaceAll('_',' ').toUpperCase()}</div>
       <div class="qflav">seals ${kingdomSeals}/3 · ${kingdomClan?'corrections '+bitCount3(kingdom.marks)+'/3 · ':''}pretenders ${(kingdom.pretendersDefeated||0)}</div></div>
       <div class="quest"><div class="qflav">${state.flags.blueTarpCleared?'✓':'·'} blue tarp court · ${state.flags.cartKeepCleared?'✓':'·'} cart cavalry keep · ${state.flags.copperChoirCleared?'✓':'·'} copper choir yard · ${state.flags.throneDitchCleared?'✓':'·'} throne ditch</div></div>`;
  const activities=[
    ['score · smoke · sleep · cook','dealer corner -> milk crate'],
    ['strip · sell · pawn · equip junk','abandoned building · scrap yard · pawn'],
    ['fight · dodge · cart-roadkill','alleys · projects · old school'],
    ['dumpster dive · kick cans · break bottles','everywhere with poor supervision'],
    ['panhandle · tacos · laundry · karaoke','marketplace · food truck · laundromat'],
    ['phone calls · prophecies · secrets','scrap phone · possum · pigeon'],
    ['faction work · hideouts · bus routes','street · scrap · spiritual'],
    ['benches · night cash · train waiting','park · train yard'],
    ['office upgrades · district claims · work orders','the lot · far east'],
    ['curb corrections · rival courts · daily pretenders','four kingdoms made of municipal leftovers'],
  ];
  const controlRows=state.touchMode
    ? `<div class="row"><span>move</span><span>drag the left stick</span></div>
       <div class="row"><span>hit / bother / squint</span><span>A HIT / B BOTHER / F SQUINT</span></div>
       <div class="row"><span>pockets / bad ideas</span><span>INV / QST</span></div>
       <div class="row"><span>feed / mute</span><span>FEED / MUTE</span></div>`
    : `<div class="row"><span>move / run</span><span>wasd or arrows / shift</span></div>
       <div class="row"><span>hit / bother</span><span>space / e</span></div>
       <div class="row"><span>pockets / bad ideas</span><span>i / q</span></div>
       <div class="row"><span>squint wrong / feed / mute</span><span>f / p / m</span></div>`;
  panelEl.innerHTML = `
    <h2>WHAT TO PRESS</h2>
    ${controlRows}

    <h2 style="margin-top:14px">NOW</h2>
    <div class="quest"><div class="qtitle">${now.text}</div><div class="qflav">the neighborhood has selected one thing.</div></div>

    <h2 style="margin-top:14px">BLOCK ROUTE ${route?'· '+route.serial:''} · FILED ${(P.lifetime&&P.lifetime.routesCompleted)||0}</h2>
    ${routeHtml}

    <h2 style="margin-top:14px">THE OFFICE</h2>
    ${officeHtml}

    <h2 style="margin-top:14px">CURB WAR</h2>
    ${kingdomHtml}

    <h2 style="margin-top:14px">TODAY'S HUSTLES · DAY ${state.day}</h2>
    ${hustles.length ? hustles.map(h => `<div class="quest ${h.done?'done':''}">
      <div class="qtitle">${h.done?'✓ ':'· '}${h.desc} <span style="float:right;color:#776">${hustleProgress(h)}</span></div>
      <div class="qflav">reward: ${Object.entries(h.reward).map(([k,v])=>'+'+v+' '+k).join(' · ')}</div>
    </div>`).join('') : '<div class="quest"><div class="qflav">no hustles today.</div></div>'}

    <h2 style="margin-top:14px">QUESTS · ACTIVE · ${active.length}</h2>
    ${activePairs.length ? activePairs.map(([k,q])=>renderQ(q,k)).join('') : '<div class="quest"><div class="qflav" style="color:#776">none active.</div></div>'}

    ${latentPairs.length ? `<h2 style="margin-top:14px">QUESTS · AVAILABLE · ${latent.length}</h2>
    ${latentPairs.map(([k,q])=>renderQ(q,k)).join('')}` : ''}

    ${donePairs.length ? `<h2 style="margin-top:14px;opacity:.6">QUESTS · DONE · ${done.length}</h2>
    <div style="opacity:.55">${donePairs.map(([k,q])=>renderQ(q,k)).join('')}</div>` : ''}

    <div style="margin-top:18px">${factionHtml}</div>

    <h2 style="margin-top:18px">WAYS TO WASTE TUESDAY</h2>
    ${activities.map(a=>`<div class="row"><span>${a[0]}</span><span style="color:#776">${a[1]}</span></div>`).join('')}

    <h2 style="margin-top:18px">PEOPLE YOU'VE MET · ${metKeys.length}/${VENDOR_FLOATER_IDS.size}</h2>
    ${peopleHtml}

    <div class="close">[ q / esc ] close</div>`;
  panelEl.classList.add('show');
}

export function closePanel() {
  panelEl.classList.remove('show');
  releaseAllInput();
  if (state.mode === 'inv' || state.mode === 'quest') state.mode = 'playing';
}

export function init_runtime_ui() {
  // ---------- world state ----------
  P = {
    x: 1050, y: 840, w: 24, h: 28,
    facing: 'down', frame: 0, frameT: 0,
    vx: 0, vy: 0, speed: 2.2,
    hp: 100, maxHp: 100,
    cash: 25, rocks: 0, copper: 0, supplies: 0, dirtySupplies: 0,
    shakes: 20, cred: 0, brain: 70,
    wanted: 0, wantedT: 0, rank: 0,
    attackCd: 0, attacking: 0, hitFlash: 0, iframes: 0,
    rockedT: 0, crashT: 0,
    inventory: [], lifetime: { rocksSmoked: 0, copsKilled: 0, arrests: 0, dayCount: 0, rocksCooked: 0, rocksFenced: 0, routesCompleted: 0, officeJobs: 0, territoriesClaimed: 0, pretendersDefeated: 0 },
    tonyOffenses: 0,
    cartMounted: false,
    equip: { shoes:null, hat:null, coat:null, tool:null },
    weapon: 'fists',
    brutusDefeated: 0,    // counter for Brutus Older trigger
    stripeLoyalty: 0,     // counter for co-op ending
    // v13 wave 3 — charisma is summed from equipment (see applyEquipStats).
    // 1+ trips the vendor 10% discount via vendorPrice().
    charisma: 0,
    // v13 wave 4 — soap rocks tracked as a parallel FIFO counter to P.rocks.
    // smoked first; produce no rocked-up effect; trigger SOAP_TONGUE.
    soapRocks: 0,
    // v13 wave 5 — combat-pattern status timers.
    // stunT: lurch's grab freezes input for 500ms. slowT: priest holy water = ×0.5 speed for 1500ms.
    stunT: 0, slowT: 0,
    // v13 wave 7 — faction reputation. tiers via factionTier(). default 0 = neutral.
    faction: { street: 0, scrap: 0, spiritual: 0 },
  };
  
  // Grant achievement helper
  
  
  // Equipment stat application — recompute derived stats
  
  
  // Weather selection per day
  
  
  runtime.npcs = [];
  particles = [];
  runtime.cashPiles = [];
  // v13 wave 5 — combat depth: generic projectile primitive. {x,y,vx,vy,dmg,slowMs,kind,from,life,rot,rotVel}
  runtime.projectiles = [];
  state = {
    mode: 'title',                       // title | playing | dialogue | inv | quest | heist | boss | tweakerVision
    bossActive: false, bossPhase: 0, bossKind: '',
    bossNPC: null,
    kingdomBattle: null,
    loadedNpcDeaths: null,
    cam: { x: 0, y: 0 },
    keys: new Set(),
    toastT: 0,
    shake: 0,
    tweakerT: 0, tweakerCdT: 0,
    day: 1, dayTime: 0,
    weather: 'clear',                    // clear | rain | fog
    rainT: 0,
    flash: 0, flashColor: '#fff',
    combo: 0, comboT: 0,
    hitPause: 0,
    carEngineT: 0,
    conductorWaitT: 0,
    // v15 living-neighborhood scenes. Active actors are ephemeral; daily history lives in flags.
    incident: null,
    incidentT: 35000 + Math.random()*20000,
    incidentPaperT: 0,
    incidentWetT: 0,
    blockRoute: null,
    office: freshOfficeState(),
    districtClaims: Object.create(null),
    kingdom: freshKingdomState(),
    primaryObjective: null,
    guidanceT: 0,
    touchMode: false,
    // v13 wave 4 — heat minigame state. heat=null when not active.
    heat: null,
    smokeT: 0,
    quests: {
      // v13 wave 3 — "the day you arrived" intro chain (auto-given on new save, suppresses normal world until done)
      intro_remember:{ title: "I DON'T REMEMBER",        done: false, intro: true, flav: 'find ten dollars somewhere on the block.' },
      intro_tony:    { title: 'THE MAN AT THE CORNER',  done: false, intro: true, available: false, flav: 'the man at the corner has a job for you. go see him.' },
      intro_smoke:   { title: 'YOU SMOKE THE ROCK',     done: false, intro: true, available: false, flav: 'the crate is for sitting. the rock is for smoking.' },
      first_rock:    { title: 'THE FIRST ROCK',         done: false, flav: 'buy a rock from tre bag tony. that is the entire quest.' },
      copper_sings:  { title: 'THE COPPER SINGS',       done: false, flav: 'strip copper from the abandoned building. in b flat.' },
      finisher:      { title: 'THE FINISHER',           done: false, flav: 'cook a rock on the crate. the crate is the kitchen now.' },
      conductor:     { title: "THE CONDUCTOR'S BARGAIN", done: false, flav: 'sell 3 pure copper to the conductor. he is still waiting.' },
      priest_mercy:  { title: "THE PRIEST'S MERCY",     done: false, flav: "accept a blessed tic-tac. let father o'malley help." },
      fallen_king:   { title: 'THE FALLEN KING',        done: false, flav: 'defeat tre bag tony at the corner. take what you can.' },
      // v13 wave 3 — standalone side quests, offered by NPCs after repeat visits.
      pigeon_crown:  { title: "THE PIGEON KING'S LOST CROWN", done: false, available: false, flav: "find the crown. the pigeons grieve." },
      stripe_package:{ title: "STRIPE'S PACKAGE",       done: false, available: false, flav: "take the package to the conductor. don't open it." },
      barb_crossword:{ title: "BARB'S MISSING CROSSWORD",done: false, available: false, flav: "find the saturday crossword. she is unwell without it." },
      // v13 wave 5 — fallen priest. opens via phone call (rank ≥3 + church visits ≥3) OR auto if you steal the plate enough.
      fallen_priest:{ title: "THE FALLEN PRIEST",        done: false, available: false, flav: "the priest has been wrong for a while. someone should say so." },
      // v13 wave 6 — the chained scrap-yard dog. opens on first close approach. branches: fed | freed | left.
      scrap_dog:    { title: "THE SCRAP YARD DOG",       done: false, available: false, state: 'idle', flav: "the dog. brown. matted. he blinks at you twice." },
      // v18 headquarters and paper-authority campaign.
      office_space: { title: "THE OFFICE",                done: false, available: false, flav: "the leasing guy has one unit. the unit has four walls and a smell." },
      paper_empire: { title: "PAPER EMPIRE",              done: false, available: false, flav: "put one bent sign where no one asked. file it in the desk." },
      regional_office:{title:"REGIONAL OFFICE",            done: false, available: false, flav: "enter four districts in pen. pencil has been rejected." },
      all_business: { title: "ALL BUSINESS",              done: false, available: false, flav: "enter every claimable district. the neighborhood will not acknowledge this." },
      // v19 curb-war campaign. Sequential receipts; the neighborhood remains open afterward.
      hostile_correspondence:{title:"HOSTILE CORRESPONDENCE",done:false,available:false,flav:"the office received a kingdom notice. postage is due."},
      blue_weather:{title:"BLUE WEATHER",done:false,available:false,flav:"serve three corrections on blue tarp court. weather is named as counsel."},
      cart_appeal:{title:"CART APPEAL",done:false,available:false,flav:"appeal the cavalry. retain the receipt. retain everything."},
      copper_mass:{title:"COPPER MASS",done:false,available:false,flav:"enter the choir register. the note is b flat. again."},
      royal_static:{title:"ROYAL STATIC",done:false,available:false,flav:"smoke one real rock at the block. the crown has poor reception."},
      one_cracklord:{title:"ONE CRACKLORD",done:false,available:false,flav:"one curb. one ruler. one folding chair."},
    },
    cashPilesCollected: new Set(),
    achievements: new Set(),
    // analog joystick input
    stickX: 0, stickY: 0, stickMag: 0,
    counters: {
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      // v13 wave 3 — dialogue-visit counts to gate side-quest offers
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0,
      // intro_remember tracks cash earned during day 1
      introCashEarned: 0,
      // v13 wave 5 — fallen-priest side quest tracking
      priestVisits: 0, plateStealAttempts: 0, churchVisits: 0,
      omalleyFallenSurviveT: 0,
      // v13 wave 6.5 — economy gate counters.
      // *Day fields hold the day-stamp of last use (self-reset via === state.day).
      // *Today fields accumulate counts and reset at dawn via resetDailyCounters().
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      gutterInventoryDay: 0,
    },
    barbAside: false,
    // v13 wave 3 — discoverability + quest-state additions
    metVendors: new Set(),
    flags: {
      introDone: true,            // existing saves default-on; new saves set false in startGame
      momIntroFired: false,
      hasStripePackage: false,
      stripeBetrayed: false,
      daveHasCrossword: false,
      hasCrossword: false,
      crownSpotIdx: -1,
      // v13 wave 4 — propane torch acquisition tracking
      peteTorchStocked: false,    // flipped true once rank>=3 (pete stocks one)
      peteTorchSold: false,       // flipped true on the buy (one and done)
      // v13 wave 5 — fallen priest flags
      omalleyFallen: false,       // priest has transformed (any path)
      omalleyFallenDead: false,   // mini-boss defeated, collar awarded
      fallenPriestCallFired: false, // unknown-number phone call fired (quest hook)
      // v13 wave 6 — map-depth pass
      underpassEntered: false,    // first-entry echo line + feed post fires once per save
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      dumpsterPropaneAwarded: false, // dumpster propane rare drop is one-and-done globally
      churchLoadedDumpsterX: 0,   // when the phone "tell pinky" line fires, plant a $50 pile here
      churchLoadedDumpsterY: 0,
      petePropaneTorchOption: false, // (legacy alias — not used; reserved for future)
    },
    crownPickup: null,            // {x, y, collected} — only present while pigeon_crown quest active
    // v13 wave 6 — graffiti tags placed once per save and persisted (replaces ephemeral GRAFFITI cache).
    graffiti: null,
    // v13 wave 6 — public phone ring timer + active-ring window
    publicPhoneT: 240000 + Math.random()*240000, // 4-8min initial
    phonePropRingT: 0,                            // counts up during the 30s answer window
    publicPhoneAnswered: 0,                        // counter for PHONE_BOOTH_PROPHET
    // v13 wave 6 — wandering freed-dog cooldown (state.quests.scrap_dog.state==='freed')
    freedDogT: 0,                                  // ms until next possible reappearance
    freedDogFollowT: 0,                            // ms remaining of current follow window
    freedDogFirstReturn: false,                    // toast-once on first reappear
  };
  
  // ---------- dialogue / toast helpers ----------
  toastEl = document.getElementById('toast');
  toastTimer = null;
  
  
  dialogueEl = document.getElementById('dialogue');
  activeDialogue = null;
  
  
  
  // ---------- panel (inventory + quest) ----------
  panelEl = document.getElementById('panel');
  
  
  
  
  
}

export function rectsOverlap(a,b){ return a.x < b.x+b.w && a.x+a.w > b.x && a.y < b.y+b.h && a.y+a.h > b.y; }

export function dist2(a,b){ const dx=a.x-b.x, dy=a.y-b.y; return dx*dx+dy*dy; }

export function clamp(v,lo,hi){ return Math.max(lo, Math.min(hi, v)); }

export function inZone(x,y,id) {
  const z = ZONES.find(z=>z.id===id);
  if (!z) return false;
  return x>=z.x && x<=z.x+z.w && y>=z.y && y<=z.y+z.h;
}

export function currentZone() {
  const cx = P.x + P.w/2, cy = P.y + P.h/2;
  let best = null, bestRank = -1;
  for (const z of ZONES) {
    if (cx<z.x || cx>z.x+z.w || cy<z.y || cy>z.y+z.h) continue;
    const f = z.faction || 'neutral';
    const tierAbs = (f === 'neutral') ? 0 : Math.abs((P.faction && P.faction[f]) || 0);
    if (tierAbs > bestRank) { bestRank = tierAbs; best = z; }
  }
  return best;
}

export function currentZoneFaction() {
  const z = currentZone();
  return z ? (z.faction || 'neutral') : 'neutral';
}

export function isNight() { return state.dayTime < 0.25 || state.dayTime > 0.75; }

export function spawnNpcs() {
  runtime.npcs = [
    { id:'tony', name:'TRE BAG TONY', sprite:'tony', x:1620, y:870, w:28,h:32, color:'#3a1810',
      hp:120, maxHp:120, speed:0, hostile:false, vendor:true,
      interact: tonyDialogue },
    { id:'yuri', name:'YURI', sprite:'yuri', x:300, y:200, w:28,h:32, color:'#4a2818',
      hp:60, maxHp:60, speed:0, hostile:false, vendor:true,
      interact: yuriDialogue },
    { id:'brutus', name:'BRUTUS', sprite:'brutus', x:480, y:280, w:32,h:24, color:'#604020',
      hp:50, maxHp:50, speed:1.4, hostile:false, dmg:7, zoneOnly:{x:100,y:80,w:520,h:360},
      archetype:'charger',
      interact: null },
    // v13 wave 6 — the chained scrap-yard dog. archetype 'passive' (does not aggro by default).
    // chained to leash_post at (570,130). interact handled by scrapDogDialogue.
    // becomes hostile only if attacked while chained.
    { id:'scrap_dog', name:'THE DOG', sprite:'scrap_dog', x:580, y:150, w:26, h:20, color:'#684830',
      hp:40, maxHp:40, speed:0, hostile:false, archetype:'passive', chained: true, tailWag:0,
      interact: scrapDogDialogue },
    { id:'pete', name:'PAWN SHOP PETE', sprite:'pete', x:250, y:700, w:28,h:32, color:'#4a4028',
      hp:80, maxHp:80, speed:0, hostile:false, vendor:true,
      interact: peteDialogue },
    { id:'lurch', name:'LURCH', sprite:'lurch', x:200, y:1400, w:28,h:34, color:'#3a2030',
      hp:55, maxHp:55, speed:1.4, hostile:false, aggroOnHit:true, dmg:6, wander:true,
      archetype:'grabber',
      interact: lurchDialogue },
    { id:'sherri', name:'SPIDER-BITE SHERRI', sprite:'sherri', x:350, y:1480, w:26,h:30, color:'#3a1820',
      hp:45, maxHp:45, speed:2.0, hostile:false, aggroOnHit:true, dmg:5, wander:true,
      archetype:'swarmer',
      interact: sherriDialogue },
    { id:'paulie', name:'PAULIE THE FACE', sprite:'paulie', x:450, y:1560, w:28,h:32, color:'#5a3030',
      hp:60, maxHp:60, speed:1.5, hostile:false, aggroOnHit:true, dmg:7, wander:true,
      archetype:'ranged',
      interact: paulieDialogue },
    { id:'dave', name:'CHATTY DAVE', sprite:'dave', x:900, y:1480, w:28,h:32, color:'#3a2818',
      hp:40, maxHp:40, speed:0, hostile:false, asleep:true,
      interact: daveDialogue },
    { id:'mom', name:'WHOLE FOODS MOM', sprite:'mom', x:1200, y:1480, w:28,h:32, color:'#80a050',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: momDialogue },
    { id:'possum', name:'THE POSSUM', sprite:'possum', x:600, y:1500, w:28,h:24, color:'#604030',
      hp:20, maxHp:20, speed:0, hostile:false,
      interact: possumDialogue },
    { id:'priest', name:"FATHER O'MALLEY", sprite:'priest', x:1800, y:1460, w:28,h:32, color:'#2a2030',
      hp:80, maxHp:80, speed:0, hostile:false,
      interact: priestDialogue },
    // v13 wave 8a — Conductor moved from THE PROJECTS to the TRAIN YARD. his real home turf.
    // dialogue + the 3-copper-for-$90 trade unchanged.
    { id:'conductor', name:'THE CONDUCTOR', sprite:'conductor', x:680, y:2960, w:28,h:32, color:'#604030',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: conductorDialogue },
    { id:'larry', name:'LOUD LARRY', sprite:'larry', x:440, y:1780, w:28,h:32, color:'#8a3030',
      hp:80, maxHp:80, speed:1.3, hostile:false, aggroOnHit:true, dmg:10,
      interact: larryDialogue },
    { id:'stripe', name:'STRIPE', sprite:'stripe', x:620, y:1780, w:28,h:32, color:'#3a3848',
      hp:70, maxHp:70, speed:0, hostile:false, vendor:true,
      interact: stripeDialogue },
    // v13 wave 8a — Pigeon King moved to THE PARK, near the central fountain. wanders inside the park.
    // dialogue / secrets / crown quest unchanged. faction-rep is still neutral on interaction.
    { id:'pigeon', name:'THE PIGEON KING', sprite:'pigeon', x:2700, y:1180, w:24,h:20, color:'#605840',
      hp:10, maxHp:10, speed:0.8, hostile:false, wander:true,
      interact: pigeonDialogue },
    { id:'biggu', name:'THE BIG GUY', sprite:'biggu', x:1200, y:340, w:32,h:38, color:'#604030',
      hp:120, maxHp:120, speed:0, hostile:false,
      interact: bigguDialogue },
    // ambient walking NPCs
    { id:'cubscout', name:'CUBSCOUT', sprite:'cubscout', x:780, y:1500, w:22,h:26, color:'#604020',
      hp:30, maxHp:30, speed:1.2, hostile:false,
      daytimeOnly:true,
      patrol:[{x:760,y:1450},{x:1200,y:1450},{x:1200,y:1580},{x:760,y:1580}],
      interact: (n)=> dialogue('CUBSCOUT', "popcorn?\n$8 a tin.\nhis mom is in the car.", [
        { label: P.cash>=8?'buy popcorn. $8.':"you don't have $8.", disabled: P.cash<8, action: ()=>{
          P.cash -= 8; P.cred += 4;
          toast('- $8\n+ 4 cred\nyou ate a fistful in the parking lot.'); audio.coin();
        }},
        { label: 'ask if his mom knows about this.', action: () => toast("she is on her phone.\nshe has been on her phone for 11 minutes.") },
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'jogger', name:'JOGGER', sprite:'jogger', x:1200, y:600, w:22,h:26, color:'#4a5028',
      hp:40, maxHp:40, speed:2.4, hostile:false,
      patrol:[{x:760,y:600},{x:1500,y:600},{x:1500,y:1100},{x:760,y:1100}],
      interact: (n)=> dialogue('JOGGER', "heart rate 142.\nshe does not stop. she is talking through it.", [
        { label: 'ask for $1.', action: ()=>{
          if (Math.random()<.4) { P.cash++; toast('+ $1\nshe gave you a dollar she did not need.'); }
          else { toast('she ran faster.\nthe ground absorbed your dignity.'); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'dogwalker', name:'DOG WALKER (PAISLEY)', sprite:'dogwalker', x:980, y:1200, w:22,h:26, color:'#604030',
      hp:40, maxHp:40, speed:0.9, hostile:false,
      patrol:[{x:900,y:1180},{x:1400,y:1180},{x:1400,y:1320},{x:900,y:1320}],
      interact: (n)=> dialogue('DOG WALKER', "paisley. no. paisley LEAVE IT.\npaisley is a small dog made of fur.", [
        { label: 'pet paisley.', action: ()=>{
          P.cred++; toast('+ 1 cred\npaisley accepts you. tolerantly.');
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'busker', name:'BUSKER', sprite:'busker', x:1100, y:1500, w:24,h:28, color:'#604020',
      hp:50, maxHp:50, speed:0, hostile:false,
      interact: (n)=> dialogue('BUSKER', "he is playing a song he wrote.\nit has no chorus.\nhe has a guitar case open at his feet.", [
        { label: P.cash>=1?'tip $1.':"you don't have $1.", disabled: P.cash<1, action: ()=>{
          P.cash--; P.cred++; toast('- $1\n+ 1 cred\nhe nods without losing the beat.');
        }},
        { label: 'request a different song.', action: ()=> toast("he plays the same song faster.\nthis is the new song now.") },
        { label: 'leave.', action:()=>{} },
      ]) },
    // — new NPCs in v6 —
    { id:'horsecop', name:'HORSE COP', sprite:'horsecop', x:1320, y:1080, w:36,h:32, color:'#1818a0',
      hp:120, maxHp:120, speed:0, hostile:false,
      patrol:[{x:1200,y:1080},{x:1500,y:1080},{x:1500,y:1240},{x:1200,y:1240}],
      interact: (n)=> dialogue('HORSE COP', "a cop on horseback nods at you.\nthe horse also nods.\ndisturbing levels of agreement.", [
        { label: 'nod back.', action: ()=>{
          P.cred += 2; toast("you nod. the horse nods.\nthe cop nods. you are all nodding.\n+ 2 cred");
        }},
        { label: 'compliment the horse.', action: ()=>{
          P.cred += 3; toast("the horse looks pleased.\nthe cop is jealous.\n+ 3 cred");
          feedPost("complimented the horse cop's horse. the horse was visibly pleased.", '@local_eyewitness');
        }},
        { label: 'try to pet the horse.', action: ()=>{
          if (Math.random()<.4) { P.cred += 4; toast("the horse permits it.\nthe cop says nothing.\n+ 4 cred"); }
          else { P.hp -= 6; P.wanted = Math.min(3, P.wanted+1); toast("the horse rears.\nyou eat curb.\n- 6 hp · wanted +1"); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'vapelord', name:'THE VAPE LORD', sprite:'vapelord', x:840, y:1100, w:28,h:32, color:'#3a1850',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('THE VAPE LORD', "he is exhaling watermelon mist.\nhe trades in juice.\nhe has a small dragon on his back.\nthe dragon is also vaping.", [
        { label: P.cash>=6?'buy a pod. $6. (+10 brain)':"you don't have $6.", disabled: P.cash<6, action: ()=>{
          P.cash -= 6; P.brain = Math.min(100, P.brain+10);
          toast('- $6\n+ 10 brain\nthe flavor is "spectrum".\nyou cannot taste it. that is the flavor.');
        }},
        { label: 'ask for a free hit.', action: ()=>{
          toast("the vape lord says nothing.\nthe dragon stares.\nyou leave.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'pothole', name:'A POTHOLE (TALKING)', sprite:'pothole', x:980, y:920, w:32,h:18, color:'#0a0805',
      hp:9999, maxHp:9999, speed:0, hostile:false,
      interact: (n)=> dialogue('A POTHOLE', "the pothole says your full legal name.\nyou did not give it your full legal name.", [
        { label: 'argue with the pothole.', action: ()=>{
          P.brain = Math.max(0, P.brain-4);
          toast("- 4 brain\nthe pothole has more facts than you do.\nthe pothole is also correct.");
        }},
        { label: 'throw something in it.', action: ()=>{
          if (P.cash>=1) { P.cash--; P.cred++; toast("- $1\n+ 1 cred\nthe pothole accepts.\nthe pothole says 'thank you' in your mother's voice."); }
          else toast("you have nothing to throw.\nthe pothole understands. the pothole is patient.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'mayorscousin', name:"MAYOR'S COUSIN", sprite:'mayorscousin', x:1340, y:1500, w:28,h:32, color:'#604020',
      hp:50, maxHp:50, speed:0, hostile:false,
      interact: (n)=> dialogue("THE MAYOR'S COUSIN", "he knows the mayor.\nhe is wearing a suit jacket.\nhe is not wearing pants.", [
        { label: 'ask about the mayor.', action: ()=>{
          toast("the mayor is, in fact, his cousin.\nthe mayor does not return his calls.\nthis information is true and useless.");
        }},
        { label: 'ask for a favor.', action: ()=>{
          if (Math.random()<.3) { P.wanted = Math.max(0, P.wanted-1); toast("a phone call is made.\nthe heat dies down.\n- 1 wanted"); }
          else toast("he makes a phone call.\nthe phone is a piece of bread.");
        }},
        { label: P.cash>=5?'bribe him. $5.':"you don't have $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; P.cred += 8;
          toast("- $5\n+ 8 cred\nhe whispers 'i'll remember this.'\nhe will not.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'phoneguy', name:'THE PHONE GUY', sprite:'phoneguy', x:1180, y:1480, w:24,h:28, color:'#3a2818',
      hp:30, maxHp:30, speed:0, hostile:false,
      interact: (n)=> {
        if (!phoneState.visible) { phoneState.visible = true; renderPhone(); }
        dialogue('THE PHONE GUY', "he is on his phone.\nhe has been on his phone.\nhe sees you. he tweets about you.", [
          { label: 'ask what he\'s posting.', action: ()=>{
            const posts = [
              "tagged a man at the corner. he didn't notice.",
              "live-posting a possum. 4 likes.",
              "the conductor is trending in zone 2.",
              "father o'malley followed me back.",
              "pawn pete weighed a sock again. 11 min. 2 hearts.",
            ];
            feedPost(posts[Math.floor(Math.random()*posts.length)], '@phone_guy');
            toast("he flips the phone toward you. you see it.\nyou are in the post.\n(press P or tap FEED)");
          }},
          { label: P.cash>=3?'give him content. $3. (+post)':"you don't have $3.", disabled: P.cash<3, action: ()=>{
            P.cash -= 3;
            feedPost("a man paid me $3 to make him famous. he is. for like 30 seconds.", '@phone_guy');
            toast("- $3\nhe posts about you.\nthe post does numbers.\nthe numbers are 3.");
          }},
          { label: 'leave.', action:()=>{} },
        ]);
      } },
    // --- v8 new NPCs ---
    // --- v12 new vendor: the supply ---
    { id:'barb', name:'BAGGIE BARB', sprite:'barb', x:1540, y:1190, w:28,h:32, color:'#8a6080',
      hp:80, maxHp:80, speed:0, hostile:false, vendor:true,
      interact: barbDialogue },
    // v13 wave 2 — rival supply at the bus stop
    { id:'pinky', name:'PINKY POLENTA', sprite:'pinky', x:1330, y:1160, w:26,h:32, color:'#c8b070',
      hp:70, maxHp:70, speed:0, hostile:false, vendor:true,
      interact: pinkyDialogue },
    // v13 wave 2 — the mathematician, under the highway underpass
    { id:'math', name:'THE MATHEMATICIAN', sprite:'math', x:1340, y:380, w:26,h:32, color:'#6a5a4a',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: mathematicianDialogue },
    // v13 wave 8a — THE TRAIN HOPPER, sleeping under the navy freight car in the train yard.
    // lore-only NPC: no resources granted. tells stories about other towns. hidden at night (sleeping inside the car).
    // daytimeOnly reuses the existing render filter (mom/pete pattern) — at night he's "inside the car".
    { id:'train_hopper', name:'THE TRAIN HOPPER', sprite:'train_hopper', x:820, y:2940, w:26,h:32, color:'#5a4030',
      hp:50, maxHp:50, speed:0, hostile:false, daytimeOnly:true,
      interact: hopperDialogue },
    // v13 wave 8a — THE PARK BENCH PHILOSOPHER, feeding pigeons near the fountain.
    // daily question cycle (5-7 questions). +1 spiritual once/day for engaging.
    { id:'philosopher', name:'PARK BENCH PHILOSOPHER', sprite:'philosopher', x:2680, y:1080, w:26,h:32, color:'#604838',
      hp:55, maxHp:55, speed:0, hostile:false,
      interact: philosopherDialogue },
    // v18 far-east clerical fixtures. Essential prevents the only office-sale hook and the
    // canal activity from being killed or punched away from their authored coordinates.
    { id:'lease_guy', name:'THE LEASING GUY', sprite:'lease_guy', x:5400, y:3100, w:28,h:32, color:'#6a5840',
      hp:80, maxHp:80, speed:0, hostile:false, essential:true,
      interact: leaseGuyDialogue },
    { id:'gutter_greg', name:'GUTTER GREG', sprite:'gutter_greg', x:4500, y:2050, w:26,h:32, color:'#496050',
      hp:80, maxHp:80, speed:0, hostile:false, essential:true,
      interact: gutterGregDialogue },
    { id:'laundromat_lady', name:'LAUNDROMAT LADY', sprite:'launderlady', x:1720, y:1180, w:28,h:32, color:'#3a3a44',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('LAUNDROMAT LADY', "she is folding the same shirt.\nshe has been folding the same shirt.\nthe shirt is hers, you think.", [
        { label: P.cash>=2?'do a load of laundry. $2. (regen +12 hp)':"need $2.", disabled: P.cash<2, action: ()=>{
          P.cash -= 2; P.hp = Math.min(P.maxHp, P.hp + 12);
          state.counters.laundryDone = (state.counters.laundryDone||0) + 1;
          toast("- $2\n+ 12 hp\nyou wore wet clothes back outside.\nit smells like a different country in here.");
        }},
        { label: P.cash>=5?"buy detergent. $5. (item)":"detergent is $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; P.inventory.push({id:'detergent', n:'a jug of detergent', q:1});
          toast("- $5\n+ detergent\nyou are not going to use it. you know this. she knows this.");
        }},
        { label: 'ask why she is here.', action: ()=>{
          toast("she does not answer. she folds.\nthe shirt has not been clean since 2009.\n(- 2 brain)");
          P.brain = Math.max(0, P.brain - 2);
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'meter_maid', name:'METER MAID', sprite:'metermaid', x:1380, y:920, w:26,h:30, color:'#a8c030',
      hp:55, maxHp:55, speed:1.6, hostile:false, aggroOnHit:true, dmg:8,
      patrol:[{x:1280,y:920},{x:1440,y:920},{x:1440,y:1020},{x:1280,y:1020}],
      interact: (n)=> dialogue('METER MAID', "she is writing a ticket.\nfor what.\nfor existing in a designated zone.", [
        { label: P.cash>=2?'pay the meter. $2. (-1 wanted)':'meters cost $2.', disabled: P.cash<2, action: ()=>{
          P.cash -= 2; P.wanted = Math.max(0, P.wanted - 1);
          toast("- $2\n- 1 wanted\nthe meter accepts. begrudgingly.");
        }},
        { label: 'try to flirt.', action: ()=>{
          toast("she looks you up and down.\nshe writes another ticket.\nthe ticket is for you. it says 'INSUFFICIENT.'");
          P.wanted = Math.min(3, P.wanted + 1);
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'food_truck', name:'FOOD TRUCK GUY', sprite:'foodtruck', x:920, y:1500, w:30,h:32, color:'#d06030',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('FOOD TRUCK GUY', "the truck says 'TACOS' in 4 fonts.\nthe truck has not moved since wednesday.\nit is wednesday.", [
        { label: P.cash>=4?'buy a mystery taco. $4. (+20 hp · ?)':"$4 minimum for hp.", disabled: P.cash<4, action: ()=>{
          P.cash -= 4;
          P.hp = Math.min(P.maxHp, P.hp + 20);
          state.counters.tacosEaten = (state.counters.tacosEaten||0) + 1;
          const r = Math.random();
          if (r < 0.15) { P.shakes = Math.max(0, P.shakes - 20); toast("- $4 · + 20 hp · - 20 shakes\nthe taco had something in it.\nyou should not ask."); }
          else if (r < 0.25) { P.hp -= 30; toast("- $4 · + 20 hp · - 30 hp\nthe taco had something in it.\nyou ARE asking now."); audio.hurt(); }
          else toast("- $4 · + 20 hp\nthe taco was a taco. you are stunned.");
        }},
        { label: P.cash>=8?'buy a horchata. $8. (+30 brain)':"horchata is $8.", disabled: P.cash<8, action: ()=>{
          P.cash -= 8; P.brain = Math.min(100, P.brain + 30);
          toast("- $8 · + 30 brain\nit tastes like a memory you don't have.");
        }},
        { label: P.cash>=15 && P.rocks<3?"buy a 'special' burrito. $15. (+1 rock somehow)":"specials are $15.", disabled: P.cash<15, action: ()=>{
          P.cash -= 15; P.rocks++; P.wanted = Math.min(3, P.wanted+1);
          toast("- $15 · + 1 rock · wanted +1\nthe burrito had a rock in it.\nthe rock is the burrito.");
          feedPost("food truck guy is selling rocks. probably. this is the news.", '@local_eyewitness');
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'priests_son', name:"THE PRIEST'S SON", sprite:'priestson', x:1740, y:1480, w:24,h:28, color:'#2a2030',
      hp:40, maxHp:40, speed:0, hostile:false,
      interact: (n)=> dialogue("THE PRIEST'S SON", "he is wearing a backwards cap.\nhe is the priest's son.\nthe priest does not acknowledge this.", [
        { label: 'ask about the priest.', action: ()=>{
          toast("'he's not my dad.'\n(the eyes are the same.)\n(- 1 brain)");
          P.brain = Math.max(0, P.brain - 1);
        }},
        { label: P.cash>=10?'buy a real tic-tac. $10. (+1 rock — actually??)':"specials run $10.", disabled: P.cash<10, action: ()=>{
          P.cash -= 10;
          if (Math.random() < 0.5) { P.rocks++; toast("- $10 · + 1 rock\nthe priest's son is a businessman."); }
          else { toast("- $10\nit was. it was just a tic-tac.\nthe priest's son walks away whistling."); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'karaoke', name:'KARAOKE MIKE', sprite:'karaoke', x:1660, y:1180, w:24,h:28, color:'#603080',
      hp:40, maxHp:40, speed:0, hostile:false,
      interact: (n)=> dialogue('KARAOKE MIKE', "he holds a karaoke machine.\nit is just a machine. there is no microphone.\nhe sings without one.", [
        { label: P.cash>=5?'sing a song. $5. (rhythm minigame)':"karaoke is $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; startRhythmMini();
        }},
        { label: 'request a song.', action: ()=>{
          toast("he sings the song you want.\nyou did not request a song.\nyou wanted, in fact, to leave.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    // v13 wave 8a — SKID ROW ambient hostiles. variants of brutus/lurch/sherri,
    // aggro on sight (n.hostile:true). street faction by archetype. high encounter rate.
    { id:'skid_brutus_1', name:'BRUTUS (SKID)', sprite:'brutus', x: 2700, y: 1820, w:32,h:24, color:'#3a2810',
      hp:60, maxHp:60, speed:1.5, hostile:true, aggro:true, dmg:7, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'charger', showHp:true },
    { id:'skid_lurch',    name:'LURCH (SKID)',  sprite:'lurch',  x: 3020, y: 1940, w:28,h:34, color:'#3a2030',
      hp:55, maxHp:55, speed:1.5, hostile:true, aggro:true, dmg:6, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'grabber', showHp:true },
    { id:'skid_sherri',   name:'SHERRI (SKID)', sprite:'sherri', x: 2860, y: 2080, w:26,h:30, color:'#3a1820',
      hp:45, maxHp:45, speed:2.1, hostile:true, aggro:true, dmg:5, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'swarmer', showHp:true },
  ];
  runtime.npcs.forEach(n => { n.hpMax = n.maxHp; n.attackCd=0; n.targetX=n.x; n.targetY=n.y; n.wanderT=0; n.showHp=n.showHp||false; });
}

export function spawnCashPiles() {
  // 22 piles scattered in non-obvious spots, $3-$10 each
  const spots = [
    {x:140,y:130,a:6},{x:580,y:420,a:5},{x:160,y:760,a:7},{x:380,y:780,a:5},
    {x:1540,y:840,a:8},{x:1760,y:980,a:4},{x:1620,y:160,a:7},{x:1940,y:380,a:8},
    {x:1380,y:1620,a:5},{x:780,y:1620,a:4},{x:110,y:1640,a:7},{x:600,y:1310,a:5},
    {x:1640,y:1320,a:8},{x:1940,y:1600,a:6},{x:120,y:1860,a:4},{x:680,y:1860,a:5},
    {x:1040,y:260,a:5},{x:1380,y:440,a:6},{x:900,y:1080,a:4},{x:1500,y:660,a:5},
    {x:260,y:1700,a:6},{x:1800,y:1180,a:7},
    // v13 wave 8a — SKID ROW hidden cash. 5 piles totaling ~$100. tweaker-vision gated like the rest.
    {x:2620,y:1780,a:18},{x:2980,y:1820,a:22},{x:3200,y:1940,a:14},
    {x:2780,y:2120,a:24},{x:3140,y:2140,a:20},
    // v13 wave 8a — OLD SCHOOL hidden cash. one pile, $30, behind the building.
    {x:3760,y:330,a:30},
  ];
  runtime.cashPiles = spots.map((s,i)=>({ id:'cp_'+i, x:s.x, y:s.y, amt:s.a, collected:state.cashPilesCollected.has('cp_'+i)}));
  // v13 wave 3 — intro_remember plant: guaranteed $10 pile inside THE BLOCK, just outside the crate.
  // crate is at (1050, 880). place pile at (1180, 870) — visible from spawn, not under the crate.
  if (state.flags && !state.flags.introDone) {
    const introId = 'cp_intro_remember';
    if (!state.cashPilesCollected.has(introId)) {
      runtime.cashPiles.push({ id: introId, x: 1180, y: 870, amt: 10, collected: false, intro: true });
    }
  }
}

export function init_helpers_spawns() {
  // ---------- helpers ----------
  
  
  
  
  
  
  // v13 wave 8b — returns the zone object the player currently stands in (or null).
  // when zones overlap, the one with the higher-absolute faction tier wins (so a LOVED
  // street overlap beats neutral spiritual; HATED scrap beats neutral street).
  
  
  
  
  
  // ---------- NPCs setup ----------
  
  
  // hidden cash piles
  
  
  
}

export let LOCAL_POSSUM_PROPHECIES;

export function tonyDialogue(n) {
  const lines = [
    "what.",
    "$10. you know the number.",
    "you again. of course.",
    "three coats. ten dollars. simple math.",
  ];
  // v13 wave 7 — street-liked or street-loved drops the base by $1 (then charisma further shaves).
  const streetTier = factionTier(P.faction ? P.faction.street : 0);
  const tonyBase = (streetTier === 'liked' || streetTier === 'loved') ? 9 : 10;
  const rockPrice = vendorPrice(tonyBase);
  const discount = rockPrice < 10;
  const charismaTag = discount ? "\nhe looks at your hat once. then twice. then not again." : '';
  const txt = `${lines[Math.floor(Math.random()*lines.length)]}\n\ntony does not blink. tony is wearing three coats.${charismaTag}`;
  dialogue('TRE BAG TONY', txt, [
    { label: `buy a rock. $${rockPrice}.`, disabled: P.cash<rockPrice, action: () => {
      P.cash -= rockPrice; P.rocks++; P.tonyOffenses = Math.max(0, P.tonyOffenses-1);
      state.counters.rocksBought++;
      if (state.counters.rocksBought >= 50) unlockAchievement('tonys_worst');
      toast(`- $${rockPrice}\n+ 1 rock${discount?'\n(the crown got you a discount.\nhe is not happy about it.)':''}`);
      audio.coin();
      adjustFaction('street', 1); // v13 wave 7 — tony rock buy = street +1
      if (!state.quests.first_rock.done) { state.quests.first_rock.done = true; questToast('THE FIRST ROCK'); }
      saveGame();
    }},
    { label: P.tonyOffenses > 2 ? 'short him. ($5)' : 'short him. ($5)', disabled: P.cash<5, action: () => {
      P.cash -= 5;
      P.tonyOffenses++;
      if (P.tonyOffenses < 3) {
        toast("tony stares. takes the $5. does not give a rock.\nyou now owe a kind of debt.");
      } else {
        toast("tony's eye twitches. he remembers.\nthe boss fight will come.");
        spawnBoss();
      }
      saveGame();
    }},
    { label: 'try to negotiate.', action: () => {
      toast('tony explains, slowly, that he does not negotiate.\nhe is, in fact, negotiating right now.\n(this changes nothing.)');
    }},
    { label: P.cred >= 100 ? 'challenge for the corner. (boss)' : 'try to take the corner. (need 100 cred)', disabled: P.cred < 100, action: () => {
      toast('tony tears off his coat. then another coat.\nthen a third coat.');
      spawnBoss();
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function yuriDialogue() {
  // v13 wave 7 — scrap liked = $28/copper; loved = $28 (same as liked); else $25
  const scrapTier = factionTier(P.faction ? P.faction.scrap : 0);
  const yuriRate = (scrapTier === 'liked' || scrapTier === 'loved') ? 28 : 25;
  // v13 wave 7 — scrap >= +5 unlocks the back-corner shed hideout (one-time $150).
  const hideoutGate = (P.faction && P.faction.scrap >= 5) && !(state.flags && state.flags.scrapHideoutOwned);
  const opts = [
    { label: `sell 1 PURE COPPER. $${yuriRate}.`, disabled: P.copper<1, action: () => {
      P.copper--; P.cash += yuriRate; toast('- 1 pure copper\n+ $'+yuriRate); audio.coin();
      adjustFaction('scrap', 1); // wave 7 — yuri copper sell = scrap +1
      saveGame();
    }},
    { label: 'sell all pure copper.', disabled: P.copper<1, action: () => {
      const sold = P.copper; const got = sold * yuriRate; P.cash += got;
      toast(`- ${sold} pure copper\n+ $${got}`); P.copper = 0; audio.coin();
      adjustFaction('scrap', Math.min(5, sold)); // cap +5 per bulk sale to avoid runaway
      saveGame();
    }},
    { label: 'ask about brutus.', action: () => {
      toast("yuri does not look up.\n'BRUTUS REMEMBER. you know what you did.'\n(you do not.)");
    }},
    { label: 'ask about the dog.', action: () => {
      const dq = state.quests.scrap_dog;
      if (!dq || dq.state === 'idle' || dq.state === 'left') {
        toast("yuri does not look up.\n'the dog. is the dog.\nthe dog is fine.'");
      } else if (dq.state === 'fed') {
        toast("yuri does not look up.\n'somebody fed the dog.\nthe dog is no different.'\n(yuri pauses. is different.)");
      } else if (dq.state === 'freed') {
        toast("yuri looks up.\n'the dog is gone.'\nhe looks back down.\n'good for the dog.'");
      }
    }},
  ];
  if (hideoutGate) {
    opts.push({ label: P.cash>=150 ? 'rent the back-corner shed. $150.' : 'rent the shed. ($150 — short.)',
      disabled: P.cash<150,
      action: () => {
        P.cash -= 150; state.flags.scrapHideoutOwned = true;
        toast("- $150\nyuri tosses you a bent key.\n'shed. back corner.\ndon't bring problems.'", 3600);
        feedPost("got a key today. it bent in the pocket.", '@crackheadcent');
        adjustFaction('scrap', 2);
        saveGame();
      }
    });
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('YURI', "what you bring, idiot." + (hideoutGate ? "\nthe shed is empty.\nthe shed could be yours." : ''), opts);
}

export function scrapDogDialogue(n) {
  const q = state.quests.scrap_dog;
  if (!q) return;
  // mark quest as encountered
  if (q.state === 'idle') q.available = true;
  // already-resolved branches
  if (q.state === 'fed') {
    dialogue('THE DOG', "the dog. fed. matted but slightly less so.\nhe blinks. once. that's the whole interaction.", [
      { label: 'pet him.', action: () => { toast("the dog accepts. tolerantly.\nthe chain rattles.", 1800); P.cred += 1; saveGame(); }},
      { label: 'leave him.', action: () => {} },
    ]);
    return;
  }
  if (q.state === 'freed') {
    dialogue('THE DOG (gone)', "the post is here.\nthe chain is on the ground.\nthe dog is not here.", [
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }
  if (q.state === 'left') {
    if (n.dead) return;
    dialogue('THE DOG', "the dog. still chained.\nhe blinks at you.\nhe has been waiting.", [
      { label: 'feed him. (-1 food, +1 cred)', disabled: !P.inventory.find(i=>i.id==='food'), action: () => {
        const i = P.inventory.findIndex(x=>x.id==='food'); if (i>=0) P.inventory.splice(i,1);
        P.cred += 1;
        q.state = 'fed'; q.done = true;
        toast("he ate it without looking up.\nhe looks at you once.\nthen back to the food.", 3200);
        feedPost("fed the scrap-yard dog.", '@crackheadcent');
        adjustFaction('scrap', 2); // wave 7
        saveGame();
      }},
      { label: 'free him. (lockpick.)', action: () => freeScrapDog() },
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }
  // first encounter
  dialogue('THE DOG', "the dog. brown. matted.\nchained to a post that looks bored.\nhe blinks at you twice.", [
    { label: P.inventory.find(i=>i.id==='food')
        ? 'feed him. (-1 food, +1 cred)'
        : 'feed him. (you have no food.)',
      disabled: !P.inventory.find(i=>i.id==='food'),
      action: () => {
        const i = P.inventory.findIndex(x=>x.id==='food'); if (i>=0) P.inventory.splice(i,1);
        P.cred += 1;
        q.state = 'fed'; q.done = true;
        toast("he ate it without looking up.\nhe looks at you once.\nthen back to the food.", 3200);
        feedPost("fed the scrap-yard dog.", '@crackheadcent');
        adjustFaction('scrap', 2); // wave 7
        saveGame();
      }
    },
    { label: 'free him. (lockpick.)', action: () => freeScrapDog() },
    { label: 'leave him.', action: () => {
      q.state = 'left'; q.done = true; q.available = false;
      toast("the dog blinks again. you walk away.\nhe is still there.\nhe is still there.", 2600);
      saveGame();
    }},
  ]);
}

export function freeScrapDog() {
  startLockpickMini(
    () => {
      const q = state.quests.scrap_dog; if (!q) return;
      const dog = runtime.npcs.find(n => n.id === 'scrap_dog');
      if (dog) { dog.dead = true; dog.chained = false; }
      q.state = 'freed'; q.done = true; q.available = false;
      state.freedDogT = 60000 + Math.random()*120000; // first reappear 1-3min later
      audio.glassBreak();
      unlockAchievement('liberator');
      toast("CLICK. the lock falls.\nthe dog stands up.\nhe walks past you. he does not look at you.\nhe is gone.", 4400);
      feedPost("freed the dog. the dog did not stay.", '@crackheadcent');
      applyRep({ scrap: 3, spiritual: -1 }); // wave 7 — freeing the dog (technically stealing)
      saveGame();
    },
    () => {
      toast("the lock holds.\nthe dog watches.\nhe is patient. you are not.", 2400);
    }
  );
}

export function spawnFreedDogFollower() {
  // already present?
  if (runtime.npcs.find(n => n.id === 'freed_dog_follower' && !n.dead)) return;
  const offsetX = (Math.random()-.5)*120;
  const offsetY = 80 + Math.random()*40;
  runtime.npcs.push({
    id: 'freed_dog_follower', name: 'THE DOG', sprite: 'scrap_dog',
    x: P.x + offsetX, y: P.y + offsetY, w: 26, h: 20, color: '#684830',
    hp: 40, maxHp: 40, speed: 1.4, hostile: false, archetype: 'passive',
    isPet: true, freedFollower: true, frame: 0,
    interact: (nn) => dialogue('THE DOG', "the dog.\nbrown. less matted.\nhe is here. for now.", [
      { label: 'pet him.', action: () => { P.cred += 1; toast("he accepts.\nhe leans into it.\nthe wandering resumes.", 2400); }},
      { label: 'leave.', action: () => {} },
    ]),
  });
  if (!state.freedDogFirstReturn) {
    state.freedDogFirstReturn = true;
    toast("the dog is back.\nhe is here.\nfor now.", 3200);
    feedPost("the dog came back today. just for a while.", '@crackheadcent');
  }
}

export function peteDialogue() {
  // v13 wave 4 — once player hits rank>=3, pete stocks the propane torch. one and done.
  if (P.rank >= 3 && state.flags && !state.flags.peteTorchStocked) {
    state.flags.peteTorchStocked = true;
  }
  const torchAvail = state.flags && state.flags.peteTorchStocked && !state.flags.peteTorchSold && !hasPropane();
  // v13 wave 7 — scrap-hated: pete refuses to buy. scrap-liked: +$2 on copper. scrap-loved: $50 loan 1×/day.
  const scrapTier = factionTier(P.faction ? P.faction.scrap : 0);
  if (scrapTier === 'hated') {
    dialogue('PAWN SHOP PETE', "pete looks up. pete looks back down.\n'pete is full.\npete does not need your things.'", [
      { label: 'leave.', action: () => {} }
    ]);
    return;
  }
  const peteCopper = (scrapTier === 'liked' || scrapTier === 'loved') ? 17 : 15;
  // v13 wave 6.5 — pete has a daily cash cap. $200/day across all sells to him.
  // sells become "pete is empty. pete is eating." once cap hit. resets at dawn.
  const PETE_CAP = 200;
  const peteCash = state.counters.peteCashToday || 0;
  const peteRoom = Math.max(0, PETE_CAP - peteCash);
  const peteEmpty = peteRoom <= 0;
  const tryPay = (amount) => {
    // returns actual amount pete pays out (clipped to his daily cash) and updates counter.
    const room = Math.max(0, PETE_CAP - (state.counters.peteCashToday||0));
    const pay = Math.min(amount, room);
    if (pay > 0) state.counters.peteCashToday = (state.counters.peteCashToday||0) + pay;
    return pay;
  };
  const peteEmptyLine = "pete is empty. pete is eating.\ncome back tomorrow.";
  const loanAvail = scrapTier === 'loved' && (state.flags.scrapLoanDay || 0) !== state.day;
  const opts = [
    peteEmpty
      ? { label: 'sell 1 PURE COPPER. (pete is empty.)', action: () => { toast(peteEmptyLine, 3000); }}
      : { label: `sell 1 PURE COPPER. $${peteCopper}.`, disabled: P.copper<1, action: () => {
          const pay = tryPay(peteCopper);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.copper--; P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast("pete weighs it for 11 minutes.\n- 1 pure copper\n+ $"+pay+(pay<peteCopper?"\npete is almost empty.":""), 2800);
          adjustFaction('scrap', 1); // wave 7 — pete copper sell = scrap +1
          audio.coin(); saveGame();
        }},
    peteEmpty
      ? { label: 'pawn a sock. (pete is empty.)', action: () => { toast(peteEmptyLine, 3000); }}
      : { label: 'pawn a sock. $1.', action: () => {
          const pay = tryPay(1);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast('+ $'+pay+'\n(it is wet.)'); audio.coin();
        }},
    peteEmpty
      ? { label: 'sell license plate. (pete is empty.)', disabled: !P.inventory.find(i=>i.id==='license'), action: () => { toast(peteEmptyLine, 3000); }}
      : { label: P.inventory.find(i=>i.id==='license') ? 'sell license plate. $20.' : 'ask about plates.', disabled: !P.inventory.find(i=>i.id==='license'), action: () => {
          const pay = tryPay(20);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.inventory = P.inventory.filter(i=>i.id!=='license');
          P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast('+ $'+pay+(pay<20?"\npete is almost empty.":"\n(do not ask where it came from.)")); audio.coin();
          adjustFaction('scrap', 1); // wave 7 — pete buy = scrap +1
          saveGame();
        }},
    // v13 wave 6 — pete sells generic food ($3). a junk inventory item with one use (feed the dog).
    // (note: this is pete SELLING TO player, not buying. not gated by pete's daily cash cap.)
    { label: P.cash>=3 ? 'buy food. $3. (canned. unmarked.)' : "food is $3.",
      disabled: P.cash<3,
      action: () => {
        P.cash -= 3;
        P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});
        toast("- $3\n+ a can of food (unmarked).\npete keeps eating his hot pocket.", 2400);
        audio.coin();
        state.counters.peteSold = (state.counters.peteSold||0)+1;
        saveGame();
      }
    },
    // v13 wave 6 — pete buys junk (subject to daily cash cap)
    peteEmpty
      ? { label: 'sell junk. (pete is empty.)', disabled: !P.inventory.find(i=>i.id==='junk'), action: () => { toast(peteEmptyLine, 3000); }}
      : { label: P.inventory.find(i=>i.id==='junk') ? 'sell junk. $1 each.' : 'ask about junk.',
          disabled: !P.inventory.find(i=>i.id==='junk'),
          action: () => {
            const junks = P.inventory.filter(i=>i.id==='junk');
            const want = junks.length * 1;
            const pay = tryPay(want);
            if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
            // only consume the junks pete actually paid for (1:1)
            const taken = Math.min(junks.length, pay);
            let removed = 0;
            P.inventory = P.inventory.filter(i => { if (i.id==='junk' && removed<taken) { removed++; return false; } return true; });
            P.cash += pay;
            state.counters.peteSold = (state.counters.peteSold||0)+1;
            toast("- "+taken+" junk\n+ $"+pay+(pay<want?"\npete is almost empty.":"\npete weighs each piece. it takes a while."), 2800);
            audio.coin(); saveGame();
          }
        },
  ];
  if (torchAvail) {
    opts.push({
      label: P.cash >= 80 ? "buy the propane torch. $80." : "the propane torch is $80. you don't have it.",
      disabled: P.cash < 80,
      action: () => {
        P.cash -= 80;
        P.equip.tool = 'propane_torch';
        applyEquipStats();
        state.flags.peteTorchSold = true;
        audio.coin();
        toast("- $80\n+ a propane torch (dented)\npete does not explain where he got it.\n(equipped.)", 4200);
        feedPost("bought a torch off pete. pete is eating.", '@crackheadcent');
        saveGame();
      }
    });
  } else if (P.rank >= 3 && state.flags && state.flags.peteTorchSold) {
    opts.push({ label: "ask about the torch again.", action: () => {
      toast("'sold the one.\ngo find your own.'\npete is still eating.", 2400);
    }});
  }
  // v13 wave 7 — scrap loved: pete will lend $50, once per day.
  if (loanAvail) {
    opts.push({ label: "ask pete for $50. (he likes you.)", action: () => {
      P.cash += 50; state.flags.scrapLoanDay = state.day;
      P.cred = Math.max(0, P.cred - 1); // implicit cred friction over time
      toast("pete looks at you for 11 minutes.\nthen counts out fifty.\n+ $50\n'pete remembers.'", 3800);
      feedPost("pete handed someone fifty. pete does not hand out money.", '@blocklog');
      saveGame();
    }});
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('PAWN SHOP PETE', "one second. eating.\npete is eating a hot pocket. behind glass.", opts);
}

export function lurchDialogue(n) {
  // v13 wave 6.5 — the dollar exchange is daily-capped (was an infinite cred trickle).
  const gaveToday = (state.counters.lurchDollarDay||0) === state.day;
  dialogue('LURCH', "you got a dollar.\nhe smells like ham.", [
    gaveToday
      ? { label: 'give a dollar. (he has forgotten you specifically.)', action: () => {
          toast("lurch is full. of dollars.\nhe is staring at the wall.\ncome back tomorrow.", 3000);
        }}
      : { label: P.cash>=1 ? 'give a dollar. (+2 cred)' : "you don't have a dollar.", disabled: P.cash<1, action: () => {
          P.cash--; P.cred += 2; state.counters.lurchDollarDay = state.day;
          toast('- $1\n+ 2 cred\nlurch immediately forgets.\ncome back tomorrow.'); saveGame();
        }},
    { label: 'lie. say you have a dollar.', action: () => {
      toast("lurch nods. waits. lurch is still waiting.\n(the lie did not work. he is just waiting.)");
    }},
    { label: 'fight.', action: () => { aggroNpc(n); toast('lurch swings. so do you. it begins.'); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function sherriDialogue(n) {
  // v13 wave 6.5 — spider cred grant is daily-capped.
  const sawToday = (state.counters.sherriSpiderDay||0) === state.day;
  dialogue('SPIDER-BITE SHERRI', "you seen the spider.\nshe is rolling her sleeve back down.", [
    sawToday
      ? { label: 'pretend to see the spider. (she has shown you today.)', action: () => {
          toast("sherri's sleeve is already down.\nthe spider is sleeping.\ncome back tomorrow.", 3000);
        }}
      : { label: 'pretend to see the spider.', action: () => {
          P.cred += 1; state.counters.sherriSpiderDay = state.day;
          toast('sherri respects you. (+1 cred)\ncome back tomorrow.'); saveGame();
        }},
    { label: 'tell her there is no spider.', action: () => {
      aggroNpc(n); toast("the spider is back.\nshe is hostile now.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function paulieDialogue(n) {
  // v13 wave 6.5 — the face compliment is daily-capped (was an infinite cred trickle).
  const flatteredToday = (state.counters.paulieFaceDay||0) === state.day;
  dialogue('PAULIE THE FACE', "the face.\nit is. it really is. just the face.", [
    flatteredToday
      ? { label: 'compliment the face. (the face has heard.)', action: () => {
          toast("paulie nods. the face is satisfied.\nthe face has been complimented today.\ncome back tomorrow.", 3000);
        }}
      : { label: 'compliment the face. (+1 cred)', action: () => {
          P.cred++; state.counters.pauliCompliments++;
          state.counters.paulieFaceDay = state.day;
          if (state.counters.pauliCompliments >= 5) unlockAchievement('compliment_the_face');
          toast("paulie does not smile but the face changes.\n+ 1 cred\ncome back tomorrow.");
          saveGame();
        }},
    { label: 'fight.', action: () => { aggroNpc(n); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function daveDialogue(n) {
  // v13 wave 3 — barb's crossword quest: dave has it. demand it back.
  const q = state.quests.barb_crossword;
  const daveHasIt = q && q.available && !q.done && state.flags.daveHasCrossword && !state.flags.hasCrossword;
  const crosswordOption = daveHasIt ? [{
    label: "demand the saturday crossword.",
    action: () => {
      if (P.cred >= 3) {
        state.flags.daveHasCrossword = false;
        state.flags.hasCrossword = true;
        P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
        toast("dave does the math.\nhe hands you a folded newspaper.\n'i thought she wouldn't notice.\nshe did.'\n+ saturday crossword", 4200);
        saveGame();
      } else {
        dialogue('CHATTY DAVE', "dave looks at you up and down.\n'$20 or fight.\nor walk. that is a third thing.'", [
          { label: P.cash>=20 ? "pay $20 ransom." : "you don't have $20.", disabled: P.cash<20, action: () => {
            P.cash -= 20;
            state.flags.daveHasCrossword = false;
            state.flags.hasCrossword = true;
            P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
            toast("- $20\n+ saturday crossword\nhe pockets your cash.\nhe is whistling.");
            saveGame();
          }},
          { label: "fight him.", action: () => {
            n.asleep = false; aggroNpc(n);
            toast("dave is hostile now.\nhe still has the crossword.\nbeat him until it falls out.");
          }},
          { label: "leave.", action: () => {} },
        ]);
      }
    }
  }] : [];

  if (n.asleep) {
    dialogue('CHATTY DAVE', "dave is asleep. his wallet is half out.", [
      ...crosswordOption,
      { label: 'pickpocket. (+$8)', action: () => {
        if (Math.random()<0.7) {
          P.cash += 8; toast('+ $8\ndave keeps sleeping.'); audio.coin();
        } else {
          n.asleep = false; n.hostile = true; n.aggro = true; P.wanted = Math.min(3, P.wanted+1);
          toast('DAVE WAKES UP.\nyou sprint. he chases.');
        }
      }},
      { label: 'wake him up.', action: () => {
        n.asleep = false; toast("dave wakes up. he is talking immediately.");
      }},
      { label: 'leave.', action: () => {} },
    ]);
  } else {
    dialogue('CHATTY DAVE', "dave is explaining a theory about pigeons.\nthe theory has 17 parts.", [
      ...crosswordOption,
      { label: 'listen for a while. (-5 brain)', action: () => {
        P.brain = Math.max(0, P.brain-5); toast('- 5 brain\nyou know more about pigeons now.\nthis was not free.');
      }},
      { label: 'leave.', action: () => {} },
    ]);
  }
}

export function momDialogue() {
  const isDaylight = !isNight();
  if (!isDaylight) {
    dialogue('WHOLE FOODS MOM', "she is not here at night.\nshe is at the wine bar with kelly.", [{label:'leave.',action:()=>{}}]);
    return;
  }
  // v13 wave 6.5 — daily-cap the ask + compliment branches. each branch fires at most once per
  // dayCount. when consumed, the option is replaced with a refusal line so the player sees the gate.
  const askedToday = (state.counters.kombuchaAskDay||0) === state.day;
  const complimentedToday = (state.counters.kombuchaComplimentDay||0) === state.day;
  const opts = [];
  if (!askedToday) {
    opts.push({ label: 'accept $10 and pity. (+$10)', action: () => {
      P.cash += 10; state.counters.kombuchaAskDay = state.day;
      toast("+ $10\nshe will tell ben about you tonight.\nben will not care.\ncome back tomorrow."); audio.coin();
      adjustFaction('spiritual', -1); // wave 7 — asking mom for money disappoints her
      saveGame();
    }});
    opts.push({ label: 'ask for $20.', action: () => {
      state.counters.kombuchaAskDay = state.day;
      if (Math.random()<0.4) { P.cash += 20; toast('+ $20\nshe pauses. she sighs. she gives.\nben will be furious.\ncome back tomorrow.'); audio.coin(); }
      else { toast("she explains capitalism for 4 minutes.\nyou leave with no money and -2 brain.\ncome back tomorrow.");
        P.brain = Math.max(0, P.brain-2); }
      adjustFaction('spiritual', -1); // wave 7 — even asking, regardless of outcome
      saveGame();
    }});
  } else {
    opts.push({ label: 'ask her for money. (she remembers.)', action: () => {
      toast("you've been by. she remembers.\nshe remembers because she has nothing else to do.\ncome back tomorrow.", 3600);
    }});
  }
  if (!complimentedToday) {
    opts.push({ label: 'compliment her kombucha. (+5 cred)', action: () => {
      P.cred += 5; state.counters.kombuchaComplimentDay = state.day;
      toast("she lights up.\nshe tells you it's lavender.\nyou agree it is lavender.\n+ 5 cred\ncome back tomorrow.");
      adjustFaction('spiritual', 1); // wave 7 — compliment = spiritual +1
      saveGame();
    }});
  } else {
    opts.push({ label: 'compliment her kombucha again.', action: () => {
      toast("she has heard about her kombucha today.\nshe is tired of her kombucha.\nshe is tired of you.", 3600);
    }});
  }
  // v13 wave 7 — mom's apartment hideout gate (spiritual >= +10, one-time setup)
  const momHideoutGate = (P.faction && P.faction.spiritual >= 10) && !(state.flags && state.flags.momHideoutOwned);
  if (momHideoutGate) {
    opts.push({ label: P.cash>=30 ? "ask mom if you can stay over. ($30/night.)" : "ask mom if you can stay over. ($30 — short.)",
      disabled: P.cash<30,
      action: () => {
        P.cash -= 30; state.flags.momHideoutOwned = true; state.flags.momRentDay = state.day;
        toast("- $30\n'oh sweetie.\nthe couch is yours.\nben works late.'\n(the spare key is on the hook.)", 4200);
        feedPost("got a couch tonight. ben works late.", '@crackheadcent');
        adjustFaction('spiritual', 2);
        saveGame();
      }
    });
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('WHOLE FOODS MOM', "oh. oh sweetie.\nshe is wearing vibram five-fingers.\nshe is holding kombucha.", opts);
}

export async function possumDialogue() {
  dialogue('THE POSSUM', "a possum wearing a tiny construction helmet looks up.\nhe is calculating something.", [
    { label: 'request a prophecy.', action: async () => {
      toast('the possum is thinking. give him a second.', 1500);
      let line = LOCAL_POSSUM_PROPHECIES[Math.floor(Math.random()*LOCAL_POSSUM_PROPHECIES.length)];
      try {
        if (window.claude && window.claude.complete) {
          const t = await Promise.race([window.claude.complete({
            messages: [{
              role:'user',
              content: `You are the POSSUM in a satirical Adult Swim-style game (Aqua Teen Hunger Force tone). Output ONE flat absurd in-world event, 1-3 sentences, lowercase, present tense, no second person past "you", no quotes, no editorializing. The event must be specific and mundane-with-an-impossible-detail. Example tones: "a possum wearing a tiny construction helmet emerges from a drain. looks you dead in the eye. retreats." or "a dachshund in a blazer hands you a receipt. it is for a haircut you did not get." No real drugs, no real places, no slurs. Output ONLY the event text, nothing else.`
            }]
          }),new Promise(resolve=>setTimeout(()=>resolve(null),1800))]);
          if (t && typeof t === 'string') line = t.trim().toLowerCase().replace(/^["']|["']$/g,'');
        }
      } catch(e) {}
      toast(line, 5500);
      state.counters.possumProphecies++;
      if (state.counters.possumProphecies >= 10) unlockAchievement('i_have_seen_horrors');
      if (state.counters.possumProphecies >= 5 && !P.hasPossum) {
        setTimeout(spawnPetPossum, 2200);
      }
      // small effect
      const eff = Math.floor(Math.random()*4);
      if (eff===0) { P.cash += 2; toast(line + '\n+ $2', 5500); }
      else if (eff===1) { P.brain = Math.max(0, P.brain-3); }
      else if (eff===2) { P.cred++; }
    }},
    { label: 'pet the possum.', action: () => { toast("you do not pet the possum.\nthe possum decides this."); unlockAchievement('the_route'); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function priestDialogue() {
  // v13 wave 5 — track visit + plate-steal counts so the fallen priest can trigger.
  state.counters.priestVisits = (state.counters.priestVisits||0) + 1;
  // already-fallen branch: if he transformed (anywhere), opening his dialogue does nothing —
  // the entity is no longer the priest. defensive: should never fire (priest_fallen has no interact).
  if (state.flags && state.flags.omalleyFallen && !state.flags.omalleyFallenDead) {
    dialogue("FATHER O'MALLEY",
      "the collar is on the floor.\nthe smile is wrong.\nthe medicine is no longer offered.",
      [{ label: 'leave.', action: () => {} }]);
    return;
  }
  // v13 wave 6.5 — donation cred is daily-capped (was an infinite cred grind via mom/sock farming).
  const donatedToday = (state.counters.priestDonateDay||0) === state.day;
  dialogue("FATHER O'MALLEY", "medicine. open your mouth.\nhe is holding a tic-tac.", [
    // v13 wave 6.5 — tic-tac is a TASTE, not a withdrawal substitute. removed shakes reduction;
    // gives a small +5 brain (sober person buff) and acknowledges that the shakes do not care.
    // the canonical line: the shakes do not care.
    { label: 'accept the blessed tic-tac. (+5 brain)', action: () => {
      P.brain = Math.min(100, P.brain+5);
      toast('the tic tac is gone.\nthe shakes do not care.');
      if (!state.quests.priest_mercy.done) { state.quests.priest_mercy.done = true; questToast("THE PRIEST'S MERCY"); }
      saveGame();
    }},
    donatedToday
      ? { label: "donate $5. (the lord heard already.)", action: () => {
          toast("father o'malley nods.\n'the lord has counted today.\ncome back tomorrow.'", 3000);
        }}
      : { label: P.cash>=5 ? 'donate $5. (+3 cred)' : 'donate $5.', disabled: P.cash<5, action: () => {
          P.cash-=5; P.cred+=3; state.counters.churchDonations += 5;
          state.counters.priestDonateDay = state.day;
          if (state.counters.churchDonations >= 100) unlockAchievement('ecclesiastes');
          toast('- $5\n+ 3 cred\nthe lord notices. then forgets.\ncome back tomorrow.');
          adjustFaction('spiritual', 2); // wave 7 — donate = spiritual +2
          saveGame();
        }},
    { label: 'steal the collection plate.', action: () => {
      state.counters.plateStealAttempts = (state.counters.plateStealAttempts||0) + 1;
      // v13 wave 5 — after 4+ priest visits AND a steal attempt, the priest stops being the priest.
      // v13 wave 7 — spiritual >= +10 (LOVED) overrides the fall trigger; the priest holds.
      const spiritualGate = (P.faction && P.faction.spiritual >= 10);
      if ((state.counters.priestVisits||0) >= 4
          && (state.counters.plateStealAttempts||0) >= 1
          && state.flags && !state.flags.omalleyFallen && !spiritualGate) {
        triggerFallenPriestTransform();
        // counts as a steal attempt for the faction ledger
        applyRep({ street: 1, spiritual: -3 });
        return;
      }
      if (Math.random()<0.55) {
        P.cash += 22; state.counters.plateStolen++;
        if (state.counters.plateStolen >= 1 && state.counters.stripeBetrayed >= 1) unlockAchievement('judas');
        toast('+ $22\n(the lord is busy.)'); audio.pickup();
      } else {
        P.hp -= 12; P.wanted = Math.min(3, P.wanted+1); toast("father o'malley smites you.\n- 12 hp · wanted +1"); audio.hurt();
      }
      applyRep({ street: 1, spiritual: -3 }); // wave 7 — every steal attempt counts
      saveGame();
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function init_dialogue_a() {
  // ---------- DIALOGUES ----------
  
  
  
  
  // v13 wave 6 — the chained scrap-yard dog. 3 outcome branches.
  // Feed: -1 food, +1 cred, state='fed', stays chained but creates 200px cop-discomfort radius.
  // Free: triggers lockpick mini. Success: dog disappears, state='freed', LIBERATOR unlocked,
  //       dog can RANDOMLY reappear in any zone as a follower for ~60s.
  // Leave: state='left' (no penalty).
  // Attack-while-chained (player swing connects): becomes hostile, state='left',
  //   THE_PIECE_OF_SHIT + -5 cred (handled at the playerAttack site).
  
  
  
  
  // v13 wave 6 — spawn the wandering freed-dog follower in a random zone close to the player.
  // follows for ~60s, then wanders off the screen.
  
  
  
  
  
  
  
  
  
  
  LOCAL_POSSUM_PROPHECIES = [
    "a parking meter prints a receipt for one cloud. the cloud contests the charge.",
    "a dachshund in a blazer measures the curb. the curb is two inches behind schedule.",
    "three pigeons open a checking account. the fourth pigeon is the branch manager.",
    "the laundromat loses power. one dryer continues on professional courtesy.",
    "a shopping cart returns from the east with a library card. the card is overdue.",
    "the bus shelter files for custody of the bench. the bench does not attend the hearing.",
    "a wet sock is elected treasurer. nobody asks what happened to the previous treasurer.",
    "the storm drain requests exact change. it accepts a button after a short meeting.",
    "a traffic cone receives a promotion. it remains in the same position with more authority.",
    "the pawn shop scale weighs itself. pete writes down twelve pounds and refuses an appeal.",
    "a motel key checks into the motel. the office is closed but the key knows somebody.",
    "the train signal turns green for one second. nothing takes advantage of it.",
    "a folding chair crosses the road under escort. the escort is another folding chair.",
    "the fountain coughs up a nickel. the park forms a committee around the nickel.",
    "a receipt blows past with your name misspelled. the amount is correct.",
    "the possum has reviewed your file. there is no file. this is considered worse.",
  ];
  
  
  
  
  // v13 wave 5 — fallen priest transform. flips the existing priest NPC in-place: same entity,
  // new id ('omalley_fallen'), hostile + aggro, archetype 'priest_fallen', HP doubled.
  // canonical line: "father o'malley does not stand up. he is already standing.\nthe collar comes off.\nthe smile is wrong."
  
}

export function triggerFallenPriestTransform() {
  const n = runtime.npcs.find(x => x.id === 'priest');
  if (!n || n.dead) return;
  if (state.flags.omalleyFallen) return;
  state.flags.omalleyFallen = true;
  // make the side quest active if it wasn't already
  if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
    state.quests.fallen_priest.available = true;
  }
  // transform in place
  n.id = 'omalley_fallen';
  n.name = "FATHER O'MALLEY (FALLEN)";
  n.archetype = 'priest_fallen';
  n.hostile = true; n.aggro = true;
  n.maxHp = 160; n.hp = 160;
  n.speed = 1.6;
  n.dmg = 22;
  n.color = '#2a1a2a';
  n.showHp = true;
  n.isOmalleyFallen = true;
  n.attackCd = 0;
  // reset combat scratch
  n.chargeState = 'idle'; n.chargeT = 0; n.chargeCdT = 0;
  audio.bossRoar();
  state.shake = 14;
  state.flash = 1; state.flashColor = 'rgba(120,40,140,.35)';
  toast("father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong.", 5500);
  broadcastNews("PRIEST AT CHURCH 'NOT BEHAVING AS EXPECTED.' WITNESSES UNCLEAR.");
  feedPost("father o'malley turned. the collar is on the floor.", '@crackheadcent');
  saveGame();
}

export function maybeFireFallenPriestCall() {
  if (!state.flags || state.flags.fallenPriestCallFired) return;
  if (state.flags.omalleyFallen) return;
  if (P.rank < 3) return;
  if ((state.counters.churchVisits||0) < 3) return;
  if (state.flags && !state.flags.introDone) return;
  state.flags.fallenPriestCallFired = true;
  if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
    state.quests.fallen_priest.available = true;
  }
  if (typeof ringPhone === 'function') {
    ringPhone({ from: 'unknown number', text: "father o'malley says the church belongs to whoever has the keys.\nyou don't." });
  } else {
    toast("unknown number:\n'father o'malley says the church belongs to whoever has the keys.\nyou don't.'", 5000);
  }
  saveGame();
}

export function conductorDialogue() {
  dialogue('THE CONDUCTOR', "the train is coming.\nit has always been coming.\nit will never be here.", [
    { label: 'sell 3 PURE COPPER. $90.', disabled: P.copper<3, action: () => {
      P.copper -= 3; P.cash += 90; toast('- 3 pure copper\n+ $90\nthe conductor nods at no one.'); audio.coin();
      if (!state.quests.conductor.done) { state.quests.conductor.done = true; questToast("THE CONDUCTOR'S BARGAIN"); }
      saveGame();
    }},
    { label: 'ask when the train arrives.', action: () => {
      toast("the conductor does not answer.\nthe conductor is the answer.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function larryDialogue(n) {
  dialogue('LOUD LARRY', "WHAT.\nWHAT.\nWHAT WHAT WHAT.", [
    { label: 'match volume. (+1 cred)', action: () => {
      P.cred++; toast("YOU YELL BACK.\nlarry respects this.\n+ 1 cred");
    }},
    { label: 'fight.', action: () => { aggroNpc(n); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function stripeDialogue() {
  // v13 wave 3 — visit-counter feeds package side quest after 3 visits.
  state.counters.stripeVisits = (state.counters.stripeVisits||0) + 1;
  const q = state.quests.stripe_package;

  // betrayed branch — once the player opened the package, stripe knows. fencing is closed.
  if (state.flags.stripeBetrayed) {
    dialogue('STRIPE', "stripe knows.\nstripe has friends.\nstripe is patient.\nthe windbreaker is still.", [
      { label: 'try to apologize.', action: () => {
        toast("stripe does not blink.\n(this is not tony's not-blinking.\nthis is different.)");
      }},
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }

  // package mid-quest: stripe waiting for delivery
  if (state.flags.hasStripePackage) {
    dialogue('STRIPE', "you have it.\nyou have not delivered it.\nthe conductor is in the train yard.\nhe does not move.", [
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }

  const buyP = vendorPrice(8);
  // v13 wave 6.5 — stripe's fence price degrades with daily volume.
  // first 3 rocks: full $6. rocks 4-6: $4. rocks 7-9: $2 floor. 10+: closed for the day.
  // helper returns the $ per rock at index (0-based) and the message for the bracket.
  const fencedToday = state.counters.stripeFencedToday || 0;
  const fencePerRock = (idx) => {
    if (idx < 3) return vendorPrice(6);
    if (idx < 6) return vendorPrice(4);
    return Math.max(1, vendorPrice(2));
  };
  const fenceClosed = fencedToday >= 10;
  // preview the immediate next-rock rate for the label
  const nextSellP = fencePerRock(fencedToday);
  // v13 wave 7 — stripe fence rep ledger. each rock fenced is +1 street, -1 spiritual,
  // with a spiritual cap of -3 per day (tracked on stripeSpiritualDayHits).
  const spiritualHits = (state.counters.stripeSpiritualDayHits || 0);
  const spiritualHitsDay = (state.counters.stripeSpiritualDayHitsDay || 0);
  const todaysHits = (spiritualHitsDay === state.day) ? spiritualHits : 0;
  function fenceRepTick() {
    adjustFaction('street', 1);
    const curDay = (state.counters.stripeSpiritualDayHitsDay === state.day) ? (state.counters.stripeSpiritualDayHits || 0) : 0;
    if (curDay < 3) {
      adjustFaction('spiritual', -1);
      state.counters.stripeSpiritualDayHits = curDay + 1;
      state.counters.stripeSpiritualDayHitsDay = state.day;
    }
  }
  const opts = [
    { label: P.cash>=buyP ? `buy stripe's rock. $${buyP}.` : "you can't afford it.", disabled: P.cash<buyP, action: () => {
      P.cash -= buyP;
      P.stripeLoyalty = (P.stripeLoyalty||0) + 1;
      if (Math.random()<0.4) {
        toast(`- $${buyP}\n(it is soap. you keep it. it is soap.)`);
        P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
        P.tonyOffenses = Math.max(0, P.tonyOffenses-1);
      } else {
        P.rocks++; toast(`- $${buyP}\n+ 1 rock\n(yeah it\'s probably real.)`); audio.coin();
      }
      adjustFaction('street', 1); // wave 7 — buying from stripe also nudges street
      if (P.stripeLoyalty === 5) {
        toast("stripe nods slowly.\nhe sees you.\nhe has a proposal.", 3000);
      }
      saveGame();
    }},
  ];
  if (fenceClosed) {
    opts.push({ label: 'sell rocks to stripe. (closed today.)', action: () => {
      toast("stripe will not buy from you today.\ntomorrow.", 3000);
    }});
  } else {
    opts.push({ label: P.rocks>=1 ? `sell 1 rock to stripe. $${nextSellP}.` : "you have no rocks to sell.", disabled: P.rocks<1, action: () => {
      const px = fencePerRock(state.counters.stripeFencedToday||0);
      P.rocks--; P.cash += px;
      state.counters.stripeFencedToday = (state.counters.stripeFencedToday||0) + 1;
      P.lifetime.rocksFenced = (P.lifetime.rocksFenced||0) + 1;
      fenceRepTick(); // wave 7 — fence rep delta
      const ft = state.counters.stripeFencedToday;
      let tail = '';
      if (ft === 4) tail = "\nstripe is taking less today.\nstripe is taking what stripe takes.";
      else if (ft === 7) tail = "\nstripe is done.\nstripe is done with rocks.\ngo away.";
      else if (ft === 10) tail = "\nstripe will not buy from you today.\ntomorrow.";
      toast(`- 1 rock\n+ $${px}${tail || `\nstripe pockets it.\nit will be $${buyP} by morning.`}`);
      audio.coin(); saveGame();
    }});
    opts.push({ label: P.rocks>=3 ? `sell rocks bulk. ($${nextSellP}/rock, gating.)` : "stripe wants 3+ for a bulk deal.", disabled: P.rocks<3, action: () => {
      let totalCash = 0; let sold = 0; let hitClose = false; let hitDegrade1 = false; let hitDegrade2 = false;
      while (P.rocks > 0 && (state.counters.stripeFencedToday||0) < 10) {
        const before = state.counters.stripeFencedToday||0;
        const px = fencePerRock(before);
        P.rocks--; sold++;
        totalCash += px;
        state.counters.stripeFencedToday = before + 1;
        fenceRepTick(); // wave 7 — fence rep delta per rock
        const after = state.counters.stripeFencedToday;
        if (after === 4) hitDegrade1 = true;
        if (after === 7) hitDegrade2 = true;
        if (after === 10) { hitClose = true; break; }
      }
      P.cash += totalCash;
      P.lifetime.rocksFenced = (P.lifetime.rocksFenced||0) + sold;
      let tail = '';
      if (hitClose) tail = "\nstripe will not buy from you today.\ntomorrow.";
      else if (hitDegrade2) tail = "\nstripe is done.\nstripe is done with rocks.";
      else if (hitDegrade1) tail = "\nstripe is taking less today.\nstripe is taking what stripe takes.";
      toast(`- ${sold} rocks\n+ $${totalCash}\nstripe stacks them with his.\nthe stack is now his stack.${tail}`, 4200);
      audio.coin(); saveGame();
    }});
  }
  // v13 wave 3 — package quest offer on 3rd+ visit
  if (q && !q.done && !q.available && state.counters.stripeVisits >= 3) {
    opts.push({ label: "stripe leans in. listen.", action: () => offerStripePackage() });
  } else if (q && q.available && !q.done && !state.flags.hasStripePackage) {
    opts.push({ label: "ask about the package again.", action: () => offerStripePackage() });
  }
  opts.push({ label: P.stripeLoyalty >= 5 ? "ask stripe about the corner." : "ask stripe about himself.", action: () => {
      if (P.stripeLoyalty >= 5) {
        dialogue('STRIPE', "yo. we should team up.\ntake tony's corner.\nyou get tuesdays and thursdays.\ni get the rest.\nyou ride at my side. on me. with me.", [
          { label: 'agree. ride with stripe.', action: () => { spawnCoopBoss(); }},
          { label: 'decline. (the deal expires.)', action: () => { toast("stripe nods.\nhe will not ask again.\nthe air shifts."); P.stripeLoyalty = -1; }},
        ]);
      } else {
        toast("'stripe is stripe.'\nhe stares.\nthe windbreaker rustles.");
      }
    }});
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('STRIPE', "$8 a rock. stripe got the deal.\nstripe is wearing a faded windbreaker.", opts);
}

export function offerStripePackage() {
  const q = state.quests.stripe_package;
  if (!q) return;
  dialogue('STRIPE', "stripe got a package.\ngoes to the conductor in the train yard.\nstripe's name. stripe's money.\ndon't open it.\ndon't.", [
    { label: 'take it.', action: () => {
      q.available = true;
      state.flags.hasStripePackage = true;
      P.inventory.push({id:'stripe_package', n:"stripe's sealed package", q:1});
      toast("+ stripe's package\nbrown paper. greasy in one corner.\ntake it to the conductor at the train yard.\ndon't.", 4000);
      saveGame();
    }},
    { label: 'pass. (offer holds.)', action: () => {
      toast("'next time.'\nstripe shrugs.\nthe windbreaker stays still.");
    }},
  ]);
}

export function openStripePackage() {
  const r = Math.random();
  state.flags.hasStripePackage = false;
  P.inventory = P.inventory.filter(i => i.id !== 'stripe_package');
  unlockAchievement('what_s_in_the_box');
  if (state.quests.stripe_package && !state.quests.stripe_package.done) {
    state.quests.stripe_package.done = true; // quest closes either way
  }
  state.flags.stripeBetrayed = true;
  if (r < 0.35) {
    // a brick of clean rocks
    P.rocks += 5;
    audio.coin();
    dialogue('THE PACKAGE', "you tear it open.\nfive rocks. wrapped in newsprint.\nthe newsprint is from 2003.\n\n+ 5 rocks\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else if (r < 0.65) {
    // 2 soap
    P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
    P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
    dialogue('THE PACKAGE', "you tear it open.\ntwo bars of soap.\nthey smell like cherries.\n\n+ 2 soaps\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else if (r < 0.90) {
    // a knife (new weapon)
    pickupWeapon('knife');
    dialogue('THE PACKAGE', "you tear it open.\nit is a knife.\nthe handle is wrapped in electrical tape.\n\n+ a knife\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else {
    // a wire — bait. wanted +2. cops arrive.
    P.wanted = Math.min(3, P.wanted + 2);
    audio.copSiren();
    dialogue('THE PACKAGE', "you tear it open.\nit is a wire.\na small bag of nothing taped to it.\n\nthe package was bait.\nwanted +2.\nstripe knows. stripe will know.", [
      { label: 'sprint.', action: () => {} },
    ]);
  }
  saveGame();
}

export function spawnCoopBoss() {
  if (state.bossActive) return;
  state.bossActive = true;
  state.bossKind = 'tony';
  state.bossPhase = 1;
  state.coopMode = true;
  const tony = runtime.npcs.find(n=>n.id==='tony');
  const stripe = runtime.npcs.find(n=>n.id==='stripe');
  if (!tony) return;
  state.bossNPC = tony;
  tony.hostile = true; tony.aggro = true; tony.maxHp = 200; tony.hp = 200; tony.speed = 1.8;
  tony.dmg = 12; tony.color = '#5a2018';
  tony.coatsOff = 1;
  // stripe becomes ally — teleport near player, hostile to tony only
  if (stripe) {
    stripe.x = P.x + 32; stripe.y = P.y;
    stripe.hp = 100; stripe.maxHp = 100;
    stripe.speed = 1.4;
    stripe.isAlly = true; stripe.allyTarget = 'tony';
    stripe.hostile = false; stripe.aggro = false;
    stripe.interact = () => toast("'this is happening.'\nstripe does not stop walking.");
  }
  audio.bossRoar();
  toast("stripe walks beside you.\nthe corner is ahead.\ntony sees you.\nthen he sees stripe.\nthen he tears off the first coat.", 4000);
  broadcastNews("ALLIANCE OBSERVED. TWO MEN. ONE WINDBREAKER. ONE CORNER.");
  feedPost("teamed up with stripe. heading to tony. wish us anything.", '@crackheadcent');
}

export function pigeonDialogue() {
  // v13 wave 3 — visit count drives the crown side-quest offer (2+ visits)
  state.counters.pigeonVisits = (state.counters.pigeonVisits||0) + 1;
  const q = state.quests.pigeon_crown;
  const opts = [
    { label: P.cash>=2 ? 'pay $2 for a secret.' : "you don't have $2.", disabled: P.cash<2, action: () => {
      P.cash -= 2;
      state.counters.pigeonTrade = (state.counters.pigeonTrade||0) + 2;
      if (state.counters.pigeonTrade >= 20) unlockAchievement('one_foot');
      const secrets = [
        "the copper sings in b flat.\nyou are not crazy.",
        "yuri is going home to a family.\nthis is information.",
        "pete is on his lunch break. forever.",
        "the possum has a route.\nyou are on it.",
        "tony has, in fact, blinked. once. in 1994.",
        "father o'malley is not real.\nhe is. but also not.",
      ];
      toast(secrets[Math.floor(Math.random()*secrets.length)], 4500);
    }},
  ];
  let headerExtra = '';
  if (q && !q.done && !q.available && state.counters.pigeonVisits >= 2) {
    headerExtra = "\nhe regards you.\nhis crown is missing.\nit has been missing for some time.";
    opts.push({ label: "ask about the crown.", action: () => {
      const spot = pickCrownSpot();
      dialogue('THE PIGEON KING', `the crown fell.\nthe pigeons grieve.\nhe says where it might be.\n\nlast seen: ${spot.where}.`, [
        { label: 'accept the search.', action: () => {
          startPigeonCrownQuest();
          toast("the pigeons watch you leave.\nyou are on a route now.", 3000);
        }},
        { label: 'decline.', action: () => { toast("the pigeons watch you leave.\nthey are not impressed."); }},
      ]);
    }});
  } else if (q && q.available && !q.done) {
    headerExtra = "\nhe has not blinked since you accepted.\nthe crown is still missing.";
  } else if (q && q.done) {
    headerExtra = "\nthe crown is back. the pigeons walk in formation now.";
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('THE PIGEON KING', "one foot.\nunblinking.\nhe wants the bread." + headerExtra, opts);
}

export function bigguDialogue() {
  dialogue('THE BIG GUY', "i am the big guy.\nhe is, in fact, tall.\nhe lives under here.", [
    { label: P.copper>=5 ? 'trade 5 PURE COPPER for the cart.' : "you need 5 pure copper.", disabled: P.copper<5, action: () => {
      P.copper -= 5; P.cartMounted = true;
      // v13 wave 8b — route through applyEquipStats so the cart cap (base × 1.7) takes effect
      applyEquipStats();
      toast("- 5 pure copper\n+ THE BIG GUY'S CART\n+10 max hp. faster.\n(the wheels do not align.)");
      saveGame();
    }},
    { label: 'ask how tall.', action: () => {
      toast("tall.\nthat is the answer he gives. tall.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function init_dialogue_b() {
  
  
  // v13 wave 5 — phone-call quest hook for the fallen priest. fires once when:
  //   rank >= 3, church visits >= 3, !introActive, !already-fallen, !call-already-fired.
  // the player gets a phone toast that opens the quest. completion = killing the fallen priest.
  
  
  
  
  
  
  
  
  // v13 wave 3 — stripe's package side quest
  
  
  // v13 wave 3 — opening stripe's package (from blockMenu when alone)
  
  
  
  
  
  
  
  
  
}

export let BUS_ZONE_TARGETS, HOPPER_LINES, PHILOSOPHER_QUESTIONS, OLD_SCHOOL_DOOR;

export function hasBusPass() { return !!P.inventory.find(i => i.id === 'bus_pass'); }

export function consumeBusPass() {
  const i = P.inventory.findIndex(x => x.id === 'bus_pass');
  if (i >= 0) P.inventory.splice(i, 1);
}

export function giveBusPass(silent) {
  if (hasBusPass()) return false;
  P.inventory.push({ id:'bus_pass', n:'a bus pass', q:1 });
  if (!silent) toast("+ a bus pass\nit smells like a wallet that wasn't yours.", 2600);
  return true;
}

export function combatActive() {
  if (P.wanted > 0) return true;
  const pcx = P.x + P.w/2, pcy = P.y + P.h/2;
  for (const n of runtime.npcs) {
    if (n.dead || n.isPet) continue;
    if (!(n.hostile || n.aggro)) continue;
    const dx = (n.x+n.w/2) - pcx, dy = (n.y+n.h/2) - pcy;
    if (dx*dx + dy*dy < 220*220) return true;
  }
  return false;
}

export function visitedZonesForBus() {
  // a zone is "visited" if its *Entered flag is true, OR if it has no gate flag (always known).
  const out = [];
  for (const t of BUS_ZONE_TARGETS) {
    if (t.flag && !(state.flags && state.flags[t.flag])) continue;
    out.push(t);
  }
  return out;
}

export function openBusPassMenu(page=0) {
  if (!hasBusPass()) {
    dialogue('BUS STOP', "you do not have a bus pass.\nthe bus does not care that you tried.", [{label:'leave.', action:()=>{}}]);
    return;
  }
  if (state.flags && state.flags.busPassUsedDay === state.day) {
    dialogue('BUS STOP', "you already rode today.\nthe bus does not run twice for you.", [{label:'leave.', action:()=>{}}]);
    return;
  }
  const aggro = combatActive();
  const here = currentZone();
  const destinations=visitedZonesForBus(),pageSize=6,maxPage=Math.max(0,Math.ceil(destinations.length/pageSize)-1);
  page=Math.max(0,Math.min(maxPage,Math.floor(Number(page)||0)));
  const opts = [];
  for (const t of destinations.slice(page*pageSize,page*pageSize+pageSize)) {
    const z = ZONES.find(z=>z.id===t.zoneId);
    if (!z) continue;
    const isHere = here && here.id === t.zoneId;
    const disabledHere = isHere;
    const disabledAggro = aggro;
    const lbl = disabledAggro ? `${t.label} — the bus is not your friend right now.`
              : disabledHere  ? `${t.label} — you're already where the bus is.`
              : `take the bus to ${t.label}.`;
    opts.push({ label: lbl, disabled: disabledAggro || disabledHere, action: () => {
      // consume + fade + teleport
      consumeBusPass();
      state.flags.busPassUsedDay = state.day;
       const tx = Number.isFinite(t.x)?t.x:z.x+z.w/2, ty = Number.isFinite(t.y)?t.y:z.y+z.h/2;
      state.flash = 0.5; state.flashColor = '#000';
      setTimeout(() => {
        P.x = Math.max(20, Math.min(WORLD.w - 20 - P.w, tx - P.w/2));
        P.y = Math.max(20, Math.min(WORLD.h - 20 - P.h, ty - P.h/2));
        state.cam.x = clamp(P.x + P.w/2 - W/2, 0, WORLD.w - W);
        state.cam.y = clamp(P.y + P.h/2 - H/2, 0, WORLD.h - H);
        // reset territory bookkeeping since the player just teleported zones
        state.territoryHeat = 0;
        state.territoryGreeted = new Set();
        state.territoryZoneId = null;
        state.flash = 0.5; state.flashColor = '#000';
        toast("the bus took you.\nthe bus does not explain how.", 3000);
        saveGame();
      }, 380);
    }});
  }
  if(page>0)opts.push({label:'previous destinations.',action:()=>openBusPassMenu(page-1)});
  if(page<maxPage)opts.push({label:'more destinations.',action:()=>openBusPassMenu(page+1)});
  opts.push({ label: 'put the pass away.', action: () => {} });
  dialogue('BUS STOP · PAGE '+(page+1)+'/'+(maxPage+1), "you take the pass out of your pocket.\nthe pass smells like a wallet that wasn't yours.\nwhere are you going.", opts);
}

export function barbDialogue() {
  // v13 wave 3 — visit count drives the crossword side-quest offer (+2 visits = offer + start)
  state.counters.barbVisits = (state.counters.barbVisits||0) + 1;
  const flav = [
    "she does not look up. she is doing the crossword.",
    "her cart has three packets and a romance novel.",
    "she hums. it is not a song.",
    "she is, in fact, someone's grandma. somewhere.",
    "the bingo dauber on the table has never been used for bingo.",
  ];
  let aside = '';
  if (state.barbAside) {
    const asides = [
      "\n(she taps the pen.)\n'pinky's salt is salt. just salt.\nmine has more salt.'",
      "\n(she does not look up.)\n'i hear pinky undercuts.\nhe will. eventually. cut himself.'",
      "\n(the dauber moves an inch.)\n'pinky calls it amore. it is not.'",
    ];
    aside = asides[Math.floor(Math.random()*asides.length)];
    state.barbAside = false;
  }
  const singlePrice = vendorPrice(5);
  const bulkPrice = vendorPrice(22);
  // v13 wave 6.5 — barb has a 6-packet/day cap. single counts as 1, bulk counts as 5.
  // if buying would exceed cap, refuse with a vibe line + a "14 across" callback.
  const packetsToday = state.counters.barbPacketsToday || 0;
  const remaining = Math.max(0, 6 - packetsToday);
  const atCap = remaining === 0;
  const opts = [];
  if (atCap) {
    opts.push({ label: 'buy packets. (she is tired.)', action: () => {
      toast("she's tired.\ncome back tomorrow.\nshe has 14 across to think about.", 3600);
    }});
  } else {
    // single packet — available unless at cap
    opts.push({ label: P.cash>=singlePrice ? `buy 1 packet. $${singlePrice}. (unmarked.)` : `a packet is $${singlePrice}.`, disabled: P.cash<singlePrice, action: () => {
      P.cash -= singlePrice; P.supplies = (P.supplies||0) + 1;
      state.counters.barbPacketsToday = (state.counters.barbPacketsToday||0) + 1;
      const left = 6 - state.counters.barbPacketsToday;
      const tail = left <= 0 ? "\nshe stops writing.\nshe's tired.\ncome back tomorrow." : '';
      toast(`- $${singlePrice}\n+ 1 packet (unmarked)\nshe does not look up.${tail}`);
      audio.coin(); saveGame();
    }});
    // bulk — only show if 5 will fit under cap (i.e. remaining >= 5)
    if (remaining >= 5) {
      opts.push({ label: P.cash>=bulkPrice ? `buy 5 packets. $${bulkPrice}. (bulk.)` : `5 packets is $${bulkPrice}.`, disabled: P.cash<bulkPrice, action: () => {
        P.cash -= bulkPrice; P.supplies = (P.supplies||0) + 5;
        state.counters.barbPacketsToday = (state.counters.barbPacketsToday||0) + 5;
        const left = 6 - state.counters.barbPacketsToday;
        const tail = left <= 0 ? "\nshe stops writing.\nshe's tired.\ncome back tomorrow." : '';
        toast(`- $${bulkPrice}\n+ 5 packets\nshe writes '14 across' in pen.${tail}`);
        audio.coin(); saveGame();
      }});
    } else {
      opts.push({ label: 'buy 5 packets bulk. (not today.)', action: () => {
        toast("she taps the pen.\n'i'm not weighing five out tonight.\ncome back tomorrow.'", 3200);
      }});
    }
  }
  opts.push({ label: "ask what's in them.", action: () => {
    toast("she does not look up.\n'salt.'\nyou both know.\nyou both agree to not.");
  }});
  // v13 wave 3 — quest C: barb_crossword
  const q = state.quests.barb_crossword;
  if (q && q.done) {
    // post-completion easter egg branch
    opts.push({ label: "ask what 14 across was.", action: () => {
      dialogue('BAGGIE BARB', "she looks up. her eyes are dry and the lashes are stuck.\n'fourteen across. five letters. begins with a B.\nit was BLAME.\nit's always BLAME.'\nshe looks back down.", [
        { label: 'leave.', action: () => {} },
      ]);
    }});
  } else if (q && q.available && state.flags.hasCrossword) {
    // returning the stolen crossword
    opts.unshift({ label: "give barb her crossword back.", action: () => {
      state.flags.hasCrossword = false;
      P.inventory = P.inventory.filter(i => i.id !== 'crossword');
      P.supplies = (P.supplies||0) + 1; // free clean packet
      q.done = true;
      questToast("BARB'S MISSING CROSSWORD");
      unlockAchievement('seven_across');
      adjustFaction('street', 1); // wave 7 — return crossword = street +1
      audio.coin();
      dialogue('BAGGIE BARB', "she takes it. for the first time in years she looks up.\nher eyes are dry and the lashes are stuck.\n'fourteen across. five letters. begins with a B.\nit was BLAME.\nit's always BLAME.'\nshe looks back down.\n\n+ 1 packet (free.)", [
        { label: 'leave.', action: () => {} },
      ]);
      saveGame();
    }});
  } else if (q && !q.available && state.counters.barbVisits >= 2) {
    // hook: offer the side quest after the second visit
    q.available = true;
    state.flags.daveHasCrossword = true;
    aside += "\n(her hand pauses over the puzzle.)\n'somebody took my saturday.\ni need it back. i am not well without it.'";
    saveGame();
  }
  // standard "14 across" flavor (only if quest not active)
  if (!q || (!q.available && !q.done)) {
    opts.push({ label: "ask what 14 across is.", action: () => {
      const clues = [
        "'a flightless bird.' 3 letters.\nit is EMU. it is always EMU.",
        "'a man with a plan.' 4 letters.\nshe writes BARB.\nyou do not correct her.",
        "'something you regret.' 11 letters.\nshe does not write anything.\nshe looks at you. briefly.",
        "'opposite of clean.' 5 letters.\nshe writes BARB again.",
      ];
      toast(clues[Math.floor(Math.random()*clues.length)], 3800);
    }});
  }
  opts.push({ label: "leave.", action: () => {} });
  dialogue('BAGGIE BARB', "what.\n" + flav[Math.floor(Math.random()*flav.length)] + aside, opts);
}

export function pinkyDialogue() {
  // v13 wave 7 — street-hated: pinky refuses to sell ("you smell like a snitch.")
  const streetTier = factionTier(P.faction ? P.faction.street : 0);
  if (streetTier === 'hated') {
    dialogue('PINKY POLENTA', "pinky steps back.\n'you smell like a snitch.\npinky no sell to a snitch.\nyou go barb. barb sell to snitch.'", [
      { label: 'leave.', action: () => {} }
    ]);
    return;
  }
  const flav = [
    "buongiorno mi crackhead.",
    "the cut is amore.",
    "is fresh. from the house.",
    "i price in lira sometimes. twenty four thousand. is four dollars. same number.",
    "pinky no negotiate. pinky also a little negotiate.",
  ];
  const onBuy = () => {
    if (!state.counters.pinkyFirstBuy) {
      state.counters.pinkyFirstBuy = 1;
      state.barbAside = true;
      unlockAchievement('due_dealer_system');
      broadcastNews("DUE DEALER SYSTEM OBSERVED. THE NEIGHBORHOOD HAS OPTIONS NOW.");
      feedPost("two packet guys. one block. choose your fighter.", '@crackheadcent');
    }
  };
  const oneP = vendorPrice(4);
  const fiveP = vendorPrice(18);
  // v13 wave 8b — bus pass: pinky sells one for $20 if player doesn't already carry one
  const passPrice = 20;
  const showBusPassSell = !hasBusPass();
  const showBusPassUse = hasBusPass();
  const opts = [
    { label: P.cash>=oneP ? `buy 1 house cut packet. $${oneP}.` : `house cut is $${oneP}.`, disabled: P.cash<oneP, action: () => {
      P.cash -= oneP;
      P.supplies = (P.supplies||0) + 1;
      P.dirtySupplies = (P.dirtySupplies||0) + 1;
      onBuy();
      toast(`- $${oneP}\n+ 1 packet (house cut)\nhe winks. with both eyes.`);
      applyRep({ street: 1, spiritual: -1 }); // wave 7
      audio.coin(); saveGame();
    }},
    { label: P.cash>=fiveP ? `buy 5 packets bulk. $${fiveP}.` : `5 packets bulk is $${fiveP}.`, disabled: P.cash<fiveP, action: () => {
      P.cash -= fiveP;
      P.supplies = (P.supplies||0) + 5;
      P.dirtySupplies = (P.dirtySupplies||0) + 5;
      onBuy();
      toast(`- $${fiveP}\n+ 5 packets (house cut)\nhe says 'amore.' he says it three times.`);
      applyRep({ street: 2, spiritual: -2 }); // wave 7 — bulk gets a slightly bigger ledger hit
      audio.coin(); saveGame();
    }},
  ];
  if (showBusPassSell) {
    opts.push({ label: P.cash>=passPrice ? `buy a bus pass. $${passPrice}.` : `a bus pass is $${passPrice}.`, disabled: P.cash<passPrice, action: () => {
      P.cash -= passPrice;
      giveBusPass();
      toast(`- $${passPrice}\n+ a bus pass\npinky shrugs.\n'is paper. is the bus. is paper.'`, 3400);
      audio.coin(); saveGame();
    }});
  }
  if (showBusPassUse) {
    opts.push({ label: 'use the bus pass.', action: () => openBusPassMenu() });
  }
  opts.push({ label: "you no like?", action: () => {
    toast("he is delighted you said it back.\n'you no like? you go barb.'\nhe says it once more under his breath.");
  }});
  opts.push({ label: "ask about the cut.", action: () => {
    toast("'is house. is what house had.'\nhe gestures behind him.\nthere is no house.");
  }});
  opts.push({ label: "leave.", action: () => {} });
  dialogue('PINKY POLENTA', flav[Math.floor(Math.random()*flav.length)] + "\nhe smells of cologne and onion.\nhe is always saying it once.", opts);
}

export function mathematicianDialogue() {
  state.counters.mathInteractions = (state.counters.mathInteractions||0) + 1;
  const count = state.counters.mathInteractions;

  // live EV calc — mirrors doCook's slow-mode math
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  if (P.rockedT > 0) bb -= 0.25;
  const slowDbl = clamp(0.08 + bb*0.15, 0, 0.7);
  const slowBrn = clamp(0.10 - bb*0.08, 0.02, 0.5);
  const evRocks = 1 - slowBrn + slowDbl;
  const evCash = evRocks * 6;       // stripe fences at $6
  const evNet = evCash - 5;          // minus barb's $5/packet
  const pct = Math.round(evRocks * 100);
  const dirty = P.dirtySupplies || 0;

  const stateLines = [
    `${pct} percent of two. you a coin flip with a busted edge.`,
    `brain ${Math.round(P.brain)}. ${P.rockedT>0 ? "rocked up. shaky scientist. minus point two five. don't." : "shaky mode equals minus point one eight. don't."}`,
    `expectation: a buck ${Math.max(0, evNet).toFixed(2).slice(2)}. you smoke it you lose two dollars and a year.`,
    `the math says barb. the math also says you sell. the math is a coward.`,
    `tony charges ten. you cook for five. the gap is moral.`,
  ];
  if (dirty > 0) {
    stateLines.push(`${dirty} dirty in the bag. soap rate twenty five. pinky knows what he did.`);
  }

  let lead = stateLines[Math.floor(Math.random()*stateLines.length)];
  let tip = null;
  if (count % 3 === 0) {
    const tipIdx = Math.floor(count / 3) - 1;
    const tips = [
      "the cook brain factor: brain minus thirty over seventy. minus point two five if you smoked first. they don't print that anywhere.",
      "stripe's coin lands soap two of every five tosses. forty percent. you knew. you kept buying.",
      "tony's patience is three. you short him three times. the corner becomes arena. simple math.",
      "twenty two coins are on the ground. you have stepped on most of them already. hold F. the math is green.",
      "the priest's son is half tic-tac, half rock. exactly half. fifty fifty. flip your coin.",
    ];
    if (tipIdx >= 0 && tipIdx < tips.length) {
      tip = tips[tipIdx];
      adjustFaction('scrap', 1); // wave 7 — math hidden tip received = scrap +1
    }
  }

  dialogue('THE MATHEMATICIAN', "he looks up from a clipboard.\n" + lead + (tip ? "\n\n· the numbers know what you did ·\n" + tip : ""), [
    { label: "ask for another number.", action: () => mathematicianDialogue() },
    { label: "ask what he calculates.", action: () => {
      toast("'expectation.'\nhe taps the clipboard.\n'i do not predict. i only count.'");
    }},
    { label: "leave.", action: () => {} },
  ]);
}

export function hopperDialogue(n) {
  // hidden at night (sleeping inside the car) — drawNpc handles the gating via n.hidden flag.
  if (isNight()) {
    toast("the freight car is dark.\nyou hear breathing inside.\nyou do not wake him.", 2800);
    return;
  }
  if (!state.flags.trainHopperTalkedTo) {
    state.flags.trainHopperTalkedTo = true;
    unlockAchievement('train_hopped');
  }
  const line = HOPPER_LINES[Math.floor(Math.random()*HOPPER_LINES.length)];
  dialogue('THE TRAIN HOPPER',
    "he is wiry. a beard the color of old steel.\nhe does not stand up.\n\n" + line,
    [
      { label: "ask about the trains.", action: () => {
        toast("'they don't stop here anymore.\nthey come through.\nthey come through.'\n(- 2 brain)", 4200);
        P.brain = Math.max(0, P.brain - 2);
      }},
      { label: "ask where he's been.", action: () => hopperDialogue(n) },
      { label: "leave.", action: () => {} },
    ]);
}

export function philosopherDialogue() {
  // pick question by day (deterministic per-day cycle)
  const qIdx = ((state.day - 1) % PHILOSOPHER_QUESTIONS.length + PHILOSOPHER_QUESTIONS.length) % PHILOSOPHER_QUESTIONS.length;
  const q = PHILOSOPHER_QUESTIONS[qIdx];
  const alreadyGavenRep = (state.counters.philosopherRepDay||0) === state.day;
  dialogue('PARK BENCH PHILOSOPHER',
    "an old woman feeding pigeons.\nbrown coat. gray hair.\nshe regards you with the patience of someone who has run out of patience.\n\n'" + q + "'",
    [
      { label: alreadyGavenRep ? "think about it. (you already did today.)" : "think about it. (+1 spiritual)", action: () => {
        if (!alreadyGavenRep) {
          state.counters.philosopherRepDay = state.day;
          adjustFaction('spiritual', 1);
          toast("you stand there.\nshe nods.\nthe pigeon nods.\n+ 1 spiritual", 3200);
        } else {
          toast("she has asked already today.\nshe is patient.\nthe pigeons are not.", 2800);
        }
      }},
      { label: "ask why she's here.", action: () => {
        toast("'i live in the building.\nthe bench is closer.\nthe pigeons remember faces.'", 3600);
      }},
      { label: "leave.", action: () => {} },
    ]);
}

export function tryParkBenchSit() {
  for (const p of PROPS) {
    if (p.type !== 'park_bench') continue;
    const ddx = (P.x+P.w/2) - (p.x+p.w/2), ddy = (P.y+P.h/2) - (p.y+p.h/2);
    if (ddx*ddx + ddy*ddy < 50*50) {
      if (state.sittingOnBench) {
        // already sitting — stand
        const sat = state.benchSitT || 0;
        state.sittingOnBench = false;
        state.benchSitT = 0;
        toast("you stand up.\nthe bench remembers.\n(sat for " + Math.floor(sat/1000) + " seconds.)", 2400);
      } else {
        state.sittingOnBench = true;
        state.benchSitT = 0;
        state.benchSitGainT = 0;
        state.benchSitPasserT = 0;
        toast("you sit.\nthe pigeons consider you furniture.\nE to stand.", 2400);
      }
      return true;
    }
  }
  return false;
}

export function tryEnterOldSchool() {
  const ddx = (P.x+P.w/2) - (OLD_SCHOOL_DOOR.x + OLD_SCHOOL_DOOR.w/2);
  const ddy = (P.y+P.h/2) - (OLD_SCHOOL_DOOR.y + OLD_SCHOOL_DOOR.h/2);
  if (ddx*ddx + ddy*ddy < 44*44) {
    // v13 wave 8.6 — rank-3 gate. before this, the school was an open-air copper print
    // (60% no-risk rip). progression now has a real wall.
    if ((P.rank||0) < 3) {
      dialogue("THE OLD SCHOOL",
        "the door is chained.\nthe chain is rusted.\nyou don't have what it takes to break it yet.\n(rank 3 required.)",
        [{ label: "leave.", action: () => { state.mode = 'playing'; } }]);
      return true;
    }
    openOldSchoolInterior();
    return true;
  }
  return false;
}

export function openOldSchoolInterior() {
  const brutusAlive = runtime.npcs.find(n => n.id === 'os_brutus' && !n.dead);
  const intro = brutusAlive
    ? "inside. dust. broken desks.\nyou hear something in the gym.\nit is breathing.\nit is large."
    : "inside. dust. broken desks.\nthe gym is quiet.\nthe walls smell of pennies.";
  dialogue("THE OLD SCHOOL",
    intro,
    [
      { label: "rip copper from the walls. (40% spawn risk.)", action: () => {
        // v13 wave 8.6 — first rip per save FORCES OS Brutus spawn. no copper this time.
        // after he's killed once (state.flags.osBrutusKilled = true, flipped in death drop
        // at line ~4849), subsequent rips revert to 40% probabilistic spawn (the cousins).
        // existing saves with no flag default to FALSE — first rip post-update forces spawn
        // even if the player already ripped pre-fix. one-time tax. acceptable.
        const firstEverRip = !state.flags.osBrutusKilled && !brutusAlive;
        if (firstEverRip) {
          audio.glassBreak();
          spawnOldSchoolBrutus();
          toast("the copper is here. so is OLD SCHOOL BRUTUS.\nhe was sleeping in the gym. he is no longer sleeping.\nno copper this time.", 4400);
          state.mode = 'playing';
          saveGame();
          return;
        }
        P.copper += 2;
        state.counters.copperStripped = (state.counters.copperStripped||0) + 2;
        if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
        audio.glassBreak();
        toast("+ 2 pure copper\nthe pipe groans.\nsomething hears it.", 3000);
        // spawn risk — cousins. only rolls after first kill, when no brutus is currently up.
        if (!brutusAlive && Math.random() < 0.4) {
          spawnOldSchoolBrutus();
          // close the interior — fight happens outside in the schoolyard
          state.mode = 'playing';
          return;
        }
        saveGame();
        openOldSchoolInterior();
      }},
      { label: "leave.", action: () => { state.mode = 'playing'; }},
    ]);
}

export function spawnOldSchoolBrutus() {
  if (runtime.npcs.find(n => n.id === 'os_brutus')) return;
  // spawn just south of the door, in the schoolyard
  const sb = {
    id: 'os_brutus', name: 'OLD SCHOOL BRUTUS', sprite: 'os_brutus',
    x: OLD_SCHOOL_DOOR.x - 30, y: OLD_SCHOOL_DOOR.y + 80, w: 36, h: 28,
    color: '#604030',
    hp: 250, maxHp: 250, speed: 1.5, hostile: true, aggro: true,
    dmg: 35, archetype: 'charger', showHp: true,
    // grab-lunge combined: charger windup → lunge → grabber freeze on hit
    chargeState: 'idle', chargeT: 0, grabFreezeT: 0,
    isOsBrutus: true,
  };
  runtime.npcs.push(sb);
  toast("OLD SCHOOL BRUTUS is loose.\nhe was sleeping in the gym.\nhe is no longer sleeping.", 4200);
  feedPost("@blocklog: old school brutus is up. someone tore copper out of the gym.", '@blocklog');
  audio.glassBreak();
  saveGame();
}

export function maybeSpawnPriceGuy() {
  if (!state.flags) return;
  // already spawned today
  if (state.flags.priceGuyDay === state.day) return;
  // every ~3 days — gated by day number
  if (state.day % 3 !== 0) return;
  // splice out any leftover price_guy from a prior day (walked-off or resolved)
  for (let i = runtime.npcs.length - 1; i >= 0; i--) {
    if (runtime.npcs[i].id === 'price_guy') runtime.npcs.splice(i, 1);
  }
  state.flags.priceGuyDay = state.day;
  // spawn at the skid row center
  const pg = {
    id: 'price_guy', name: 'THE PRICE GUY', sprite: 'price_guy',
    x: 2940, y: 1860, w: 26, h: 32, color: '#1a1818',
    hp: 80, maxHp: 80, speed: 0, hostile: false,
    isPriceGuy: true, hasFloater: '?',
    interact: priceGuyDialogue,
  };
  runtime.npcs.push(pg);
  feedPost("the price guy is back. nobody saw him arrive.", '@crackheadcent');
}

export function priceGuyDialogue(n) {
  // already paid this run-of-spawn? despawn message
  if (n.priceResolved) {
    dialogue("THE PRICE GUY", "he is gone.\nhe was here.", [{ label:'leave.', action:()=>{} }]);
    return;
  }
  dialogue("THE PRICE GUY",
    "the price guy. he has it. you have the price.\n\n'the price is what you have on you.\nall of it. or nothing.'",
    [
      { label: P.cash > 0 ? "pay the price. ($" + P.cash + ")" : "you have nothing to pay.", disabled: P.cash <= 0, action: () => {
        state.flags.priceGuyVisits = (state.flags.priceGuyVisits || 0) + 1;
        n.priceResolved = true;
        const paid = P.cash;
        P.cash = 0;
        unlockAchievement('the_price_paid');
        // RNG outcomes: knife (20%) / $200 (15%) / propane torch (10%, if not owned) / a rock (25%) / nothing (30%)
        const r = Math.random();
        if (r < 0.20) {
          P.weapon = 'knife';
          toast("you paid $" + paid + ".\nhe handed you a knife.\nthe handle is warm.\n(+ knife)", 4200);
          feedPost("the price guy handed someone a knife. the someone walked away with it.", '@crackheadcent');
        } else if (r < 0.35) {
          P.cash += 200;
          toast("you paid $" + paid + ".\nhe handed you $200.\nyou are net positive on this transaction.\nyou are not.\n(+ $200)", 5400);
          feedPost("the price guy gave someone $200. the someone gave him $" + paid + ". the math is moral.", '@crackheadcent');
        } else if (r < 0.45 && !hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          toast("you paid $" + paid + ".\nhe handed you a propane torch.\nit smells like a parking lot.\n(+ propane torch)", 5400);
          feedPost("the price guy gave someone a propane torch. he had one. now they do.", '@crackheadcent');
        } else if (r < 0.70) {
          P.rocks++;
          toast("you paid $" + paid + ".\nhe handed you a rock.\nyou suspect it is real.\n(+ 1 rock)", 4200);
        } else {
          toast("you paid $" + paid + ".\nhe handed you nothing.\nhe nods.\nyou nod. the transaction is complete.", 5400);
        }
        // despawn after a short delay so the player sees him "leave"
        n.priceWalkOff = true;
        n.speed = 1.4;
        n.targetX = -80;
        n.targetY = n.y;
        n.wanderOff = true;
        saveGame();
      }},
      { label: "walk away.", action: () => {
        toast("he watches you leave.\nhe does not move.\nthe price was the price.", 2800);
      }},
    ]);
}

export function init_vendors_places() {
  // ---------- v13 wave 8b — bus pass helpers ----------
  // the bus pass is a single-use consumable. Pinky sells one for $20; mom drops a free one at dawn
  // if spiritual ≥ liked. Using one at Pinky's spot teleports the player to the center of any
  // visited zone. State: P.inventory item id='bus_pass' (q:1, no stacking). Cooldown: once per day
  // via state.flags.busPassUsedDay === state.day.
  
  
  
  // "actively pursued" gate: any non-pet NPC that is hostile/aggro within ~220px,
  // or any cop alive (cops only exist if wanted > 0).
  
  // list of zones the player has visited (re-uses the wave 6/8a "*Entered" flags for parity).
  BUS_ZONE_TARGETS = [
    // {flag, zoneId, label}
    { flag:null,                 zoneId:'block',      label:'the block',             x:1050,y:840 },
    { flag:null,                 zoneId:'market',     label:"mom's neighborhood",   x:1060,y:1510 },
    { flag:null,                 zoneId:'scrap',      label:'the scrap yard',        x:360,y:260 },
    { flag:null,                 zoneId:'alley',      label:'the back alley',        x:370,y:1470 },
    { flag:null,                 zoneId:'church',     label:'the church',            x:1800,y:1592 },
    { flag:null,                 zoneId:'projects',   label:'the projects',          x:400,y:1790 },
    { flag:'underpassEntered',   zoneId:'underpass',  label:'the highway underpass', x:1210,y:350 },
    { flag:'trainYardEntered',   zoneId:'trainyard',  label:'the train yard',        x:810,y:2980 },
    { flag:'parkEntered',        zoneId:'park',       label:'the park',              x:2710,y:1150 },
    { flag:'skidRowEntered',     zoneId:'skidrow',    label:'skid row',              x:3315,y:1940 },
    { flag:'oldSchoolEntered',   zoneId:'oldschool',  label:'the old school',        x:3760,y:760 },
    { flag:'warehouseRowEntered',zoneId:'warehouse_row',label:'warehouse row',       x:4930,y:850 },
    { flag:'canalEntered',       zoneId:'canal',      label:'the drainage canal',   x:5420,y:2070 },
    { flag:'theLotEntered',      zoneId:'the_lot',    label:'the lot',              x:4440,y:3140 },
    { flag:'blueTarpCourtEntered',zoneId:'blue_tarp_court',label:'blue tarp court', x:7010,y:1180 },
    { flag:'cartKeepEntered',    zoneId:'cart_cavalry_keep',label:'cart cavalry keep',x:8120,y:2320 },
    { flag:'copperChoirEntered', zoneId:'copper_choir_yard',label:'copper choir yard',x:6100,y:3780 },
    { flag:'throneDitchEntered', zoneId:'throne_ditch',label:'the throne ditch',    x:8240,y:5240 },
  ];
  
  
  
  // ---------- BAGGIE BARB (the supply) ----------
  
  
  // ---------- PINKY POLENTA (rival supply, house cut) ----------
  
  
  // ---------- THE MATHEMATICIAN (under the underpass) ----------
  
  
  // ---------- v13 wave 8a — TRAIN HOPPER ----------
  // lore-only NPC under the navy freight car. tells stories about other towns.
  // no resources granted (per the anti-grind rule). first-time talk unlocks TRAIN_HOPPED.
  // faction: SPIRITUAL.
  HOPPER_LINES = [
    "a place called bremerton.\nthey pay more for copper.\nthey don't ask where you got it.",
    "i rode through laramie once.\nthe pigeons there don't have a king.\nthey have a council.",
    "memphis. the river is a vendor.\nyou give it a coin. it gives you a different coin.\nthe coin is the same coin.",
    "there is a town called good thunder.\nit is in minnesota.\nit is also a state of mind.\nyou are not in it.",
    "a guy in stockton kept a possum.\nthe possum kept him.\nthat is how it works.",
    "they say the trains stopped in '88.\nnobody told the trains.\nyou hear them.\nyou heard them.",
    "i used to be a person with an address.\nthen i was a person without one.\nnow i am the address.",
  ];
  
  
  // ---------- v13 wave 8a — PARK BENCH PHILOSOPHER ----------
  // asks one philosophical question per day. +1 spiritual once/day. faction: SPIRITUAL.
  PHILOSOPHER_QUESTIONS = [
    "the pigeons came back today.\ndid you?",
    "are you the man in the story\nor the man hearing it?",
    "the bench is wet.\nthat means something.",
    "a pigeon flew at me yesterday.\nit apologized.",
    "if you keep walking the loop,\nyou eventually walk a different loop.\nyou should know.",
    "i was a different person at noon.\nnoon was an hour ago.\nwho is asking.",
    "the fountain has been running since 1994.\nthe water is the same water.\nthat is also you.",
  ];
  
  
  // ---------- v13 wave 8a — PARK BENCH SIT MECHANIC ----------
  // E within range of a park_bench toggles sit. while sitting: +1 brain/2s, shakes unchanged.
  // Long sits (>60s continuous) trigger BENCH_PRESS + may surface a passerby comment.
  
  
  // ---------- v13 wave 8a — OLD SCHOOL interior (modal dialogue) ----------
  // Wave 7 hideout pattern. E on the school door opens a dialogue: extract copper (2/attempt,
  // 40% chance to spawn the OLD SCHOOL BRUTUS boss), or leave.
  OLD_SCHOOL_DOOR = { x: 3760, y: 700, w: 24, h: 28 }; // south face, door gap of the OLDSCHOOL building
  
  
  
  
  // ---------- v13 wave 8a — THE PRICE GUY (random encounter every ~3 days in SKID ROW) ----------
  // One-shot per day. Pays "the price" (all cash) for a single random outcome:
  // knife / $200 / propane torch / a rock / nothing. true gamble.
  
  
  
  
}

export let COOK_MODES;

export function hasPropane() { return P.equip && P.equip.tool === 'propane_torch'; }

export function cookBatchMenu() {
  const have = P.supplies || 0;
  const dirty = Math.min(P.dirtySupplies||0, have);
  const dirtyLine = dirty > 0 ? `\n${dirty} of them are pinky's house cut. (dirty first.)` : '';
  // predictor — 1 short flavor line tailored to current brain/rocked/dirty state.
  const brain = P.brain;
  const rocked = P.rockedT > 0;
  const predictor = pickHeatPredictor(brain, rocked, dirty);
  const torch = hasPropane();
  const opts = [
    { label: have>=1 ? "low and slow. (1 packet, safe.)" : "you have no packets.", disabled: have<1, action: () => startHeatMini(1, 'slow') },
    { label: have>=3 ? "fast cook. (3 packets, risky.)" : "fast cook (need 3 packets.)", disabled: have<3, action: () => startHeatMini(3, 'fast') },
    { label: have>=1 && P.shakes >= 60 ? "shaky hands special. (1 packet, all-or-nothing.)" : (P.shakes<60 ? "shakes too steady for the special." : "need a packet."), disabled: have<1 || P.shakes<60, action: () => startHeatMini(1, 'shakes') },
    { label: have>=5 ? `cook all (${have} packets).` : `cook all (need 5+ packets.)`, disabled: have<5, action: () => startHeatMini(have, 'all') },
  ];
  if (torch) {
    opts.push({
      label: have>=1 ? "propane. (1 packet. tight bar. big yield.)" : "propane. (need a packet.)",
      disabled: have<1,
      action: () => startHeatMini(1, 'propane')
    });
  }
  opts.push({ label: "leave.", action: () => {} });
  const torchLine = torch
    ? `\npropane. you bought it. or you found it. it doesn't care.`
    : '';
  dialogue('THE CRATE (KITCHEN)',
    `you have ${have} packet${have===1?'':'s'}.${dirtyLine}\nthe crate is a kitchen now.\nbrain: ${Math.round(P.brain)} · shakes: ${Math.round(P.shakes)}.\n${predictor}${torchLine}`,
    opts);
}

export function pickHeatPredictor(brain, rocked, dirty) {
  // up to 6 contextual flavor lines, never more than one
  if (rocked && dirty > 0)                return "rocked + dirty → good luck.";
  if (rocked)                             return "rocked → hands aren't yours. the bar shrinks.";
  if (brain >= 70 && dirty === 0)         return "sober + clean → wider sweet spot.";
  if (brain >= 70 && dirty > 0)           return "sober. but pinky in the bag. the cut argues with the math.";
  if (brain <= 30 && dirty > 0)           return "zonked + dirty → the smoke writes its own ending.";
  if (brain <= 30)                        return "zonked → narrow window. read the needle.";
  if (dirty > 0)                          return "dirty packets first. soap is louder.";
  return "the heat is the heat. the needle is the needle.";
}

export function startHeatMini(n, mode) {
  // close any active dialogue first (cookBatchMenu opened one)
  closeDialogue();
  const cfg = COOK_MODES[mode] || COOK_MODES.slow;
  // sweet-spot width math: base + brain mod, rocked penalty, floor 0.05 ceil 0.40
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  let width = cfg.baseWidth + bb * 0.10;
  if (P.rockedT > 0) width -= 0.06;
  width = clamp(width, 0.05, 0.40);
  // sweet-spot center: base ± random spread, clamped so it never sits on the edges
  const center = clamp(cfg.sweetCenter + (Math.random()*2 - 1) * cfg.sweetSpread, 0.10, 0.95);
  state.heat = {
    active: true,
    mode, n,
    fillMs: cfg.fillMs,
    burnZone: cfg.burnZone,
    sweetCenter: center,
    sweetHalf: width / 2,
    progress: 0,           // current needle position 0..1
    t: 0,                  // elapsed ms
    phase: 'fill',         // fill -> hold -> resolve
    lockedAt: null,
    outcome: null,
    holdT: 0,              // 600ms reveal hold after lock
    idleAfterFill: 1000,   // 1s grace after bar fully fills, then auto-burn
  };
  state.mode = 'cookmini';
  // brief chiptune cue so the player knows the minigame started
  if (audio && audio.dialogue) audio.dialogue();
}

export function updateHeatMini(dt) {
  const h = state.heat;
  if (!h || !h.active) return;
  if (h.phase === 'fill') {
    h.t += dt;
    h.progress = Math.min(1, h.t / h.fillMs);
    if (h.progress >= 1) {
      h.phase = 'idle';   // bar is full; auto-burn after idleAfterFill ms
    }
  } else if (h.phase === 'idle') {
    h.idleAfterFill -= dt;
    if (h.idleAfterFill <= 0) {
      // no input — auto-burn at the top of the bar
      h.lockedAt = 1.0;
      lockHeatMini();
    }
  } else if (h.phase === 'hold') {
    h.holdT -= dt;
    if (h.holdT <= 0) finalizeHeatMini();
  }
}

export function lockHeatMini() {
  const h = state.heat;
  if (!h || !h.active || (h.phase !== 'fill' && h.phase !== 'idle')) return;
  if (h.lockedAt === null) h.lockedAt = clamp(h.progress, 0, 1);
  h.phase = 'hold';
  h.holdT = 600;
  h.outcome = resolveHeatOutcome(h);
  // ledger cue per outcome — keep them short, no melodies
  if (h.outcome === 'perfect') audio.coin();
  else if (h.outcome === 'ok') audio.pickup();
  else if (h.outcome === 'burn') audio.hurt();
  else audio.glassBreak();
}

export function bailHeatMini() {
  const h = state.heat;
  if (!h || !h.active) return;
  // supplies still consumed — you walked away
  const n = h.n;
  const dirtyUsed = Math.min(n, P.dirtySupplies||0);
  P.supplies = Math.max(0, (P.supplies||0) - n);
  P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
  state.heat = null;
  state.mode = 'playing';
  toast("you walked away.\nthe supplies don't walk back.", 2800);
  feedPost("walked away from a half-cooked batch. the crate is patient.", '@blocklog');
  saveGame();
}

export function resolveHeatOutcome(h) {
  const x = h.lockedAt;
  const center = h.sweetCenter;
  const halfW = h.sweetHalf;
  const d = Math.abs(x - center);
  // pre-emptive lock (under 25%) = undercook regardless of distance
  if (x < 0.25 && d > halfW) return 'undercook';
  // burn-black: top of the bar (mode-dependent)
  if (x >= 1.0 - h.burnZone) return 'burn';
  if (d <= halfW)            return 'perfect';
  if (d <= halfW * 1.8)      return 'ok';
  if (d <= halfW * 3.0)      return 'bad';
  // far miss — too cold = undercook, otherwise small chance of soap-rock, else bad
  if (x < 0.20)              return 'undercook';
  if (Math.random() < 0.15)  return 'soaprock';
  return 'bad';
}

export function finalizeHeatMini() {
  const h = state.heat;
  if (!h) return;
  state.heat = null;
  state.mode = 'playing';
  applyCookOutcome(h.n, h.mode, h.outcome);
}

export function applyCookOutcome(n, mode, outcome) {
  // bb math — preserved from v12/v13.
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  if (P.rockedT > 0) bb -= 0.25;
  const dirtyUsed = Math.min(n, P.dirtySupplies||0);
  const cleanUsed = n - dirtyUsed;

  // BURN: supplies consumed, 0 rocks, smoke fills the screen, wanted+1, brain -10.
  if (outcome === 'burn') {
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    P.brain = Math.max(0, P.brain - 10);
    P.wanted = Math.min(3, P.wanted + 1);
    state.smokeT = 2000;
    audio.hurt(); audio.glassBreak();
    toast("the smoke is in the floor.\nit is in your hair.\nit will be in your hair on tuesday.", 4200);
    if (Math.random() < 0.5) feedPost("someone burnt the block. it's bad out here.", '@crackheadcent');
    // CONTROLLED_BURN — survive a burn (player is technically still upright)
    unlockAchievement('controlled_burn');
    if (n >= 3) unlockAchievement('arson_of_nothing');
    saveGame();
    return;
  }
  // UNDERCOOK: supplies consumed, 0 rocks. flat.
  if (outcome === 'undercook') {
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    audio.hurt();
    toast("it never set.\nyou waited.\nnothing crystallized.\nyou sit. you don't move.", 4200);
    if (Math.random() < 0.5) feedPost("nothing happened today. it counts.", '@blocklog');
    saveGame();
    return;
  }
  // SOAP-ROCK: supplies consumed, yield = BAD-cook yield * 0.5, but rocks tagged as soap.
  if (outcome === 'soaprock') {
    // base bad math first
    let rocks = 0, burnt = 0;
    for (let i=0;i<n;i++) {
      let dbl, brn;
      if (mode === 'slow')         { dbl = 0.08 + bb*0.15; brn = 0.10 - bb*0.08; }
      else if (mode === 'fast')    { dbl = 0.35 + bb*0.20; brn = 0.30 - bb*0.10; }
      else if (mode === 'shakes')  { dbl = 0.55;           brn = 0.45; }
      else if (mode === 'propane') { dbl = 0.30 + bb*0.20; brn = 0.20 - bb*0.10; }
      else                         { dbl = 0.15 + bb*0.18; brn = 0.18 - bb*0.10; }
      dbl = clamp(dbl, 0, 0.7); brn = clamp(brn, 0.02, 0.5);
      const r = Math.random();
      if (r < brn) burnt++;
      else if (r < brn + dbl) rocks += 2;
      else rocks++;
    }
    rocks = Math.floor(rocks * 0.5);
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    P.soapRocks = (P.soapRocks||0) + rocks;
    P.brain = Math.max(0, P.brain - Math.min(6, 1 + n));
    P.shakes = Math.min(100, P.shakes + 2 * n);
    audio.hurt();
    toast(`· batch ·\n- ${n} packet${n===1?'':'s'}\n+ ${rocks} 'rock${rocks===1?'':'s'}'\nit looks right. it isn't.`, 4200);
    if (Math.random() < 0.5) feedPost("cut is talking.", '@hardcandy');
    saveGame();
    return;
  }

  // PERFECT / OK / BAD — the real cook math, with outcome multipliers.
  const yieldMult  = outcome === 'perfect' ? 1.15 : outcome === 'bad' ? 0.60 : 1.00;
  const soapAdjust = outcome === 'perfect' ? 0.70 : outcome === 'bad' ? 1.50 : 1.00;

  let rocks = 0, burnt = 0, soap = 0;
  for (let i=0;i<n;i++) {
    let dbl, brn;
    if (mode === 'slow')         { dbl = 0.08 + bb*0.15; brn = 0.10 - bb*0.08; }
    else if (mode === 'fast')    { dbl = 0.35 + bb*0.20; brn = 0.30 - bb*0.10; }
    else if (mode === 'shakes')  { dbl = 0.55;           brn = 0.45; }   // ignores brain
    else if (mode === 'propane') { dbl = 0.30 + bb*0.20; brn = 0.20 - bb*0.10; }   // tight, hot
    else                         { dbl = 0.15 + bb*0.18; brn = 0.18 - bb*0.10; }
    dbl = clamp(dbl, 0, 0.7); brn = clamp(brn, 0.02, 0.5);
    const r = Math.random();
    if (r < brn) burnt++;
    else if (r < brn + dbl) rocks += 2;
    else rocks++;
  }

  // apply per-mode yield bonus (propane = 1.30 × base) then per-outcome multiplier
  if (mode === 'propane') rocks = Math.floor(rocks * 1.30);
  rocks = Math.max(0, Math.floor(rocks * yieldMult));

  // soap rate: weighted average, adjusted by outcome
  const baseRate = n > 0 ? (dirtyUsed * 0.25 + cleanUsed * 0.12) / n : 0;
  const soapRate = clamp(baseRate * soapAdjust, 0, 1);
  if (mode !== 'shakes' && rocks > 0 && Math.random() < soapRate) { soap = 1; rocks--; }

  P.supplies = Math.max(0, (P.supplies||0) - n);
  P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
  P.rocks += rocks;
  if (soap) P.inventory.push({id:'soap', n:'a small bar of soap (oops)', q:1});
  P.brain = Math.max(0, P.brain - Math.min(6, 1 + n));
  P.shakes = Math.min(100, P.shakes + (mode==='shakes' ? 0 : 2 * n));
  P.lifetime.rocksCooked = (P.lifetime.rocksCooked||0) + rocks;

  if (rocks > 0) audio.coin();
  if (burnt > 0) audio.hurt();
  audio.glassBreak();

  if (rocks > 0 && state.quests.finisher && !state.quests.finisher.done) {
    state.quests.finisher.done = true; questToast('THE FINISHER');
  }
  if ((P.lifetime.rocksCooked||0) >= 10) unlockAchievement('chef');
  if (burnt === n && n >= 3) unlockAchievement('arson_of_nothing');
  if (outcome === 'perfect') unlockAchievement('the_heat_held');

  const lines = [`- ${n} packet${n===1?'':'s'}`];
  if (rocks > 0) lines.push(`+ ${rocks} rock${rocks===1?'':'s'}`);
  if (soap > 0)  lines.push(`+ 1 'rock' (it's soap. it happens.)`);
  if (burnt > 0) lines.push(`burnt ${burnt}.\nthe crate has a smell now.`);

  let header;
  if (outcome === 'perfect') header = "the heat held.";
  else if (outcome === 'ok') header = "close enough. the rock is the rock.";
  else                       header = "the smell is wrong. you did this wrong.";

  toast(`· batch ·\n${header}\n${lines.join('\n')}`, 4200);

  // feed broadcasts — gated to ~50% per outcome so they don't spam
  if (Math.random() < 0.5) {
    if (outcome === 'perfect')   feedPost("the chef. quiet today. respect.", '@hardcandy');
    else if (outcome === 'ok')   feedPost(`cooked ${rocks} on the crate. the crate is a kitchen.`, '@crackheadcent');
    else                         feedPost("the smell is wrong on the block.", '@blocklog');
  }

  // smell: cooking in bulk attracts attention — only on OK / PERFECT (bad/burn handle their own bumps)
  if (n >= 3 && (outcome === 'perfect' || outcome === 'ok') && Math.random() < 0.35) {
    P.wanted = Math.min(3, P.wanted + 1);
    setTimeout(()=>toast("a neighbor opens a window.\nthe neighbor closes the window.\nwanted +1.", 2800), 2200);
  }
  saveGame();
}

export function drawHeatMini() {
  const h = state.heat;
  if (!h || !h.active) return;
  // panel — same language as dialogue overlay: dark slab, dirty cream text
  const PW = 480, PH = 240;
  const px = (W - PW) / 2, py = (H - PH) / 2;
  ctx.fillStyle = 'rgba(0,0,0,.78)';
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = '#1a1810';
  ctx.fillRect(px, py, PW, PH);
  ctx.strokeStyle = '#e8c040';
  ctx.lineWidth = 2;
  ctx.strokeRect(px+1, py+1, PW-2, PH-2);

  // title
  ctx.fillStyle = '#e8c040';
  ctx.font = 'bold 16px Courier New';
  ctx.textAlign = 'center';
  ctx.fillText('the heat.', W/2, py + 28);
  // subtitle
  const cleanCount = Math.max(0, h.n - Math.min(h.n, P.dirtySupplies||0));
  const dirtyCount = h.n - cleanCount;
  const modeLabel = ({slow:'low and slow', fast:'fast cook', shakes:'shaky special', all:'cook all', propane:'propane'})[h.mode] || h.mode;
  const subtitle = `${modeLabel} — ${h.n} packet${h.n===1?'':'s'} — clean × ${cleanCount} + dirty × ${dirtyCount}`;
  ctx.fillStyle = '#d4c896';
  ctx.font = '11px Courier New';
  ctx.fillText(subtitle, W/2, py + 48);

  // the bar
  const BW = 400, BH = 28;
  const bx = (W - BW) / 2, by = py + 90;
  // gradient: blue → green → yellow → red → black
  const grad = ctx.createLinearGradient(bx, 0, bx + BW, 0);
  grad.addColorStop(0.00, '#2848a0');
  grad.addColorStop(0.30, '#4a8830');
  grad.addColorStop(0.55, '#d4b820');
  grad.addColorStop(0.82, '#c84020');
  grad.addColorStop(0.96, '#1a0a08');
  grad.addColorStop(1.00, '#000');
  ctx.fillStyle = grad;
  ctx.fillRect(bx, by, BW, BH);
  // burn-zone marker (thin red bracket at top of bar)
  const bzX = bx + BW * (1 - h.burnZone);
  ctx.fillStyle = 'rgba(160,40,40,.4)';
  ctx.fillRect(bzX, by, BW - (bzX - bx), BH);

  // sweet-spot region (raised + white tick above)
  const sx1 = bx + BW * (h.sweetCenter - h.sweetHalf);
  const sx2 = bx + BW * (h.sweetCenter + h.sweetHalf);
  ctx.fillStyle = 'rgba(212,200,150,.18)';
  ctx.fillRect(sx1, by - 4, sx2 - sx1, BH + 8);
  ctx.strokeStyle = '#d4c896';
  ctx.lineWidth = 1;
  ctx.strokeRect(sx1, by - 4, sx2 - sx1, BH + 8);
  // tick mark
  ctx.fillStyle = '#d4c896';
  ctx.fillRect(bx + BW * h.sweetCenter - 1, by - 10, 2, 6);

  // bar border
  ctx.strokeStyle = '#604020';
  ctx.lineWidth = 2;
  ctx.strokeRect(bx, by, BW, BH);

  // needle
  const needleX = bx + BW * h.progress;
  ctx.fillStyle = '#d4c896';
  ctx.fillRect(needleX - 1, by - 6, 2, BH + 12);
  // locked-in indicator
  if (h.lockedAt !== null) {
    const lx = bx + BW * h.lockedAt;
    ctx.fillStyle = '#e8c040';
    ctx.fillRect(lx - 2, by - 8, 4, BH + 16);
  }

  // helper line
  ctx.fillStyle = '#776';
  ctx.font = '10px Courier New';
  ctx.fillText(
    h.phase === 'fill' ? 'space / tap — lock the heat. esc — walk away.' :
    h.phase === 'idle' ? "you're letting it burn. tap to save it." :
    h.outcome ? '· ' + heatOutcomeLabel(h.outcome) + ' ·' : '',
    W/2, by + BH + 28);

  // reveal phase — show outcome label larger
  if (h.phase === 'hold' && h.outcome) {
    ctx.fillStyle = h.outcome === 'perfect' ? '#e8c040'
                   : h.outcome === 'burn'    ? '#8a3a3a'
                   : h.outcome === 'soaprock'? '#d488d4'
                   : '#d4c896';
    ctx.font = 'bold 18px Courier New';
    ctx.fillText(heatOutcomeLabel(h.outcome).toUpperCase(), W/2, by + BH + 56);
  }
  ctx.textAlign = 'left';
}

export function heatOutcomeLabel(o) {
  return ({perfect:'perfect.', ok:'ok.', bad:'bad cook.', burn:'burnt.', undercook:'never set.', soaprock:'soap.'})[o] || o;
}

export function drawSmokeOverlay() {
  if (!state.smokeT || state.smokeT <= 0) return;
  const a = Math.min(1, state.smokeT / 2000);
  // gray haze layered with darker blobs
  ctx.fillStyle = `rgba(180,170,160,${a * 0.85})`;
  ctx.fillRect(0, 0, W, H);
  // a few wandering smudges
  for (let i = 0; i < 6; i++) {
    const t = performance.now() / 600 + i;
    const x = ((Math.sin(t * 1.3 + i) * 0.5 + 0.5) * W);
    const y = ((Math.cos(t * 0.9 + i) * 0.5 + 0.5) * H);
    ctx.fillStyle = `rgba(60,52,44,${a * 0.6})`;
    ctx.beginPath(); ctx.arc(x, y, 90 + (i%3)*20, 0, Math.PI*2); ctx.fill();
  }
  ctx.fillStyle = '#1a1810';
  ctx.font = 'bold 14px Courier New';
  ctx.textAlign = 'center';
  ctx.fillText("the smoke is in the floor.", W/2, H/2);
  ctx.textAlign = 'left';
}

export function init_heat() {
  // ---------- COOK (the finisher) ----------
  // v13 wave 4: cook is now a real-time canvas skill check called THE HEAT.
  // cookBatchMenu picks the mode + packet count, startHeatMini runs the bar,
  // resolveHeatOutcome reads needle vs sweet spot, applyCookOutcome does the math.
  
  // per-mode heat configuration. fillMs = full-bar travel time; sweetCenter = base sweet-spot center
  // (fraction of bar); sweetSpread = ± random jitter; baseWidth = sweet-spot width before brain mod;
  // burnZone = top fraction of bar that auto-burns.
  COOK_MODES = {
    slow:    { fillMs: 4000, sweetCenter: 0.55, sweetSpread: 0.05, baseWidth: 0.22, burnZone: 0.08 },
    fast:    { fillMs: 2400, sweetCenter: 0.70, sweetSpread: 0.05, baseWidth: 0.16, burnZone: 0.08 },
    shakes:  { fillMs: 1800, sweetCenter: 0.78, sweetSpread: 0.07, baseWidth: 0.10, burnZone: 0.08 },
    all:     { fillMs: 3200, sweetCenter: 0.65, sweetSpread: 0.05, baseWidth: 0.13, burnZone: 0.08 },
    propane: { fillMs: 1200, sweetCenter: 0.65, sweetSpread: 0.05, baseWidth: 0.08, burnZone: 0.15 },
  };
  
  
  
  
  
  
  
  // ---------- THE HEAT minigame ----------
  
  
  
  
  
  
  
  
  
  
  
  
  // preserve the doCook math contract — sweet-spot outcome modifies yield and soap rate,
  // but the bb-brain modulation and dirty-packet weighting still apply on top.
  
  
  // ---------- HEAT minigame render ----------
  
  
  
  
  // smoke overlay — 2s after a burn
  
  
  
}

export let COP_HARD_CAP;

export function aggroNpc(n) {
  n.hostile = true; n.aggro = true; n.dmg = n.dmg||8;
  P.wanted = Math.min(3, P.wanted+1);
  // v13 wave 5 — swarmer: aggro'ing sherri calls her cousin if none is nearby.
  if (n.archetype === 'swarmer' && n.id === 'sherri') spawnSwarmerSibling(n);
}

export function spawnSwarmerSibling(parent) {
  const liveSwarmers = runtime.npcs.filter(n => n.archetype === 'swarmer' && !n.dead && (n.id === 'sherri' || n.id.startsWith('sherri_')));
  if (liveSwarmers.length >= 2) return;
  // also require no other live sherri within 400px (preserves the "her cousin shows up" feel
  // — if another sherri is already nearby don't double-spawn)
  for (const s of liveSwarmers) {
    if (s === parent) continue;
    const dx = s.x - parent.x, dy = s.y - parent.y;
    if (dx*dx + dy*dy < 400*400) return;
  }
  const sib = {
    id: 'sherri_'+Math.random().toString(36).slice(2,6),
    name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
    x: parent.x + 60, y: parent.y,
    w: 26, h: 30, color: '#3a1820',
    hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
    aggroOnHit: true, dmg: 5, wander: true,
    archetype: 'swarmer', attackCd: 0, showHp: false,
  };
  runtime.npcs.push(sib);
  setTimeout(() => toast("another one shows up.\nit has the same haircut.", 2400), 200);
}

export function spawnProjectile({x, y, tx, ty, speed=320, dmg=15, slowMs=0, kind='bottle', from=null, wobble=0}) {
  let dx = tx - x, dy = ty - y;
  const len = Math.sqrt(dx*dx+dy*dy) || 1;
  // angle wobble (paulie misses often)
  let ang = Math.atan2(dy, dx);
  if (wobble) ang += (Math.random()-0.5) * wobble;
  const vx = Math.cos(ang) * speed, vy = Math.sin(ang) * speed;
  runtime.projectiles.push({
    x, y, vx, vy, dmg, slowMs, kind, from,
    rot: ang, rotVel: kind === 'holy' ? 0.05 : 0.25,
    life: 4000,
  });
}

export function questToast(title) { toast('· QUEST COMPLETE ·\n'+title); audio.rankUp(); }

export function tryCompleteIntroRemember() {
  const q = state.quests.intro_remember;
  if (!q || q.done) return;
  const earned = (state.counters && state.counters.introCashEarned) || 0;
  if (earned >= 10) {
    q.done = true;
    P.cred += 1;
    questToast("I DON'T REMEMBER");
    toast("you arrive somewhere by walking. who knew.", 2600);
    // unlock intro_tony as the next available step
    if (state.quests.intro_tony) state.quests.intro_tony.available = true;
    saveGame();
  }
}

export function completeIntroSmoke() {
  const q = state.quests.intro_smoke;
  if (!q || q.done) return;
  q.done = true;
  P.cred += 2;
  questToast('YOU SMOKE THE ROCK');
  toast("you understand the loop.\nthe loop understands you.\nneither of you is happy about it.", 4200);
  // un-suppress everything
  if (!state.flags) state.flags = {};
  state.flags.introDone = true;
  // roll the first real set of hustles now that the world is open
  rollHustles();
  rollBlockRoute();
  broadcastNews("the neighborhood notices you arrived. the neighborhood does not care.");
  feedPost("smoked one on the crate.\nthe sun moved.\nthe loop greeted me.", '@crackheadcent');
  saveGame();
}

export function pickCrownSpot() {
  // seed from day + character init time fingerprint (already-baked counter)
  if (state.flags && state.flags.crownSpotIdx >= 0 && state.flags.crownSpotIdx < CROWN_SPOTS.length) {
    return CROWN_SPOTS[state.flags.crownSpotIdx];
  }
  const idx = Math.floor(Math.random() * CROWN_SPOTS.length);
  state.flags.crownSpotIdx = idx;
  return CROWN_SPOTS[idx];
}

export function startPigeonCrownQuest() {
  const q = state.quests.pigeon_crown;
  if (!q || q.done) return;
  q.available = true;
  const spot = pickCrownSpot();
  state.crownPickup = { x: spot.x, y: spot.y, collected: false };
  saveGame();
}

export function spawnBoss() {
  if (state.bossActive) return;
  state.bossActive = true;
  state.bossKind = 'tony';
  state.bossPhase = 1;
  const tony = runtime.npcs.find(n=>n.id==='tony');
  if (!tony) return;
  state.bossNPC = tony;
  tony.hostile = true; tony.aggro = true; tony.maxHp = 200; tony.hp = 200; tony.speed = 1.8;
  tony.dmg = 12; tony.color = '#5a2018';
  tony.coatsOff = 1;
  audio.bossRoar();
  toast("tony tears off coat #1. then coat #2.\nthe corner is now arena.", 3500);
  broadcastNews("BREAKING: TRE BAG TONY IS REMOVING COATS. NEIGHBORHOOD WATCHES.");
  feedPost("tony is fighting at the corner. he had three coats. now two.", '@the_corner');
}

export function playerAttack() {
  if (P.attackCd > 0) return;
  const w = WEAPONS[P.weapon||'fists'];
  P.attackCd = w.cd;
  P.attacking = 160;
  audio.hit();
  const reach = 36 + (w.reach||0);
  const hit = { x: P.x, y: P.y, w: reach, h: 4 };
  if (P.facing==='down')  { hit.x = P.x + P.w/2 - 4; hit.y = P.y + P.h; hit.w = 8; hit.h = reach; }
  if (P.facing==='up')    { hit.x = P.x + P.w/2 - 4; hit.y = P.y - reach; hit.w = 8; hit.h = reach; }
  if (P.facing==='left')  { hit.x = P.x - reach; hit.y = P.y + P.h/2 - 4; hit.w = reach; hit.h = 8; }
  if (P.facing==='right') { hit.x = P.x + P.w; hit.y = P.y + P.h/2 - 4; hit.w = reach; hit.h = 8; }
  let connected = false, rewardableConnected = false;
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    if (rectsOverlap(hit, n)) {
      if(n.essential){
        // Bureaucracy wins this collision. Preserve hit feel without HP, wanted, blood,
        // knockback, aggro, or a persisted death that could remove a required transaction.
        n.hitFlash=120;n.showHp=false;state.shake=Math.max(state.shake,2);state.hitPause=20;
        particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*2,vy:-1.2,life:420,c:'#d4c896',sz:4});
        const now=Date.now();if((n.essentialToastAt||0)<=now){n.essentialToastAt=now+2500;toast(n.name+' enters the hit as a clerical error.\nno displacement authorized.',1800);}
        continue;
      }
      const baseDmg = 14 + Math.random()*8;
      // v13 wave 5 — charger cooldown is the vulnerable window. +25% damage on chargers panting.
      const vulnMult = ((n.archetype === 'charger' || n.archetype === 'charger_older') && n.chargeState === 'cooldown') ? 1.25 : 1.0;
      const dmg = Math.floor((baseDmg + w.dmg) * (P.rockedT>0 ? 1.5 : 1) * (P.cartMounted ? 1.3 : 1) * vulnMult);
      n.hp -= dmg; n.showHp = true; n.hitFlash = 200;
      // v13 wave 5 — chunky hit-stun: freeze + tint white + slight knockback for 120ms
      n.hitStun = 120;
      connected = true;
      if(!n.noComboReward)rewardableConnected=true;
      state.shake = Math.max(state.shake, 4);
      state.hitPause = 40; // freeze frame
      // v13 wave 6 — attacking the chained scrap_dog: one-time achievement, -5 cred,
      // dog becomes hostile and the quest closes as 'left' (no LIBERATOR ever).
      if (n.id === 'scrap_dog' && n.chained) {
        const q = state.quests.scrap_dog;
        if (q && q.state !== 'left') {
          q.state = 'left'; q.done = true; q.available = false;
        }
        if (!state.achievements.has('the_piece_of_shit')) {
          P.cred = Math.max(-50, P.cred - 5);
          unlockAchievement('the_piece_of_shit');
          toast("the dog growls. low. wrong.\nyou hit a dog that was tied up.\n- 5 cred", 4000);
          feedPost("there is a piece of shit out there. it is the man on the corner.", '@crackheadcent');
        }
        n.hostile = true; n.aggro = true;
        // make him able to fight — give him speed and snap the chain (lose the leash render)
        n.chained = false;
        n.speed = 1.6; n.dmg = 6;
        audio.hurt();
        saveGame();
      }
      // peaceful NPC hit -> wanted up
      if (!n.hostile && !n.aggroOnHit) { P.wanted = Math.min(3, P.wanted+1); toast(n.name + " did not deserve that.\nwanted +1"); }
      if (n.aggroOnHit && !n.aggro) { n.hostile = true; n.aggro = true; if (n.archetype === 'swarmer' && n.id === 'sherri') spawnSwarmerSibling(n); }
      // particles — sparks + blood drops, weapon-tinted, additive glow
      const sparkC = w.sings ? '#ffaa60' : '#fff080';
      for (let i=0;i<8;i++) particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*5,vy:(Math.random()-.5)*5,life:300,c:sparkC,sz:3,glow:true});
      for (let i=0;i<3;i++) particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*3,vy:(Math.random()-.5)*3-1,life:600,c:'#8a3a3a',sz:2,gravity:0.15});
      // big glow ring on hit
      particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:0,vy:0,life:200,c:sparkC,sz:14,glow:true});
      // v13 wave 5 — bigger knockback (5-10px, away from player) for hit-stun feel
      const kb = 8;
      if (P.facing==='down') n.y += kb;
      if (P.facing==='up') n.y -= kb;
      if (P.facing==='left') n.x -= kb;
      if (P.facing==='right') n.x += kb;
      if (n.hp <= 0) onNpcDeath(n);
    }
  }
  // v13 wave 6 — breakable bottles in the swing arc shatter; 25% drop a broken_bottle weapon pickup.
  for (const ip of interactiveProps) {
    if (ip.type !== 'b_bottle' || ip.broken) continue;
    const br = { x: ip.x-4, y: ip.y-12, w: 8, h: 16 };
    if (rectsOverlap(hit, br)) {
      ip.broken = true;
      ip.respawnT = 60000 + Math.random()*60000;
      audio.glassBreak();
      // glass shard burst
      for (let i=0;i<12;i++) particles.push({x:ip.x, y:ip.y-4, vx:(Math.random()-.5)*5, vy:-Math.random()*3-0.5, life:600, c:'rgba(180,200,220,.85)', sz:2, glow:true});
      // 25% chance to drop the weapon
      if (Math.random() < 0.25 && P.weapon !== 'broken_bottle') {
        pickupWeapon('broken_bottle');
      }
    }
  }
  if (rewardableConnected) {
    state.combo++;
    state.comboT = 1800;
    if (state.combo >= 3) state.shake = Math.max(state.shake, 6);
    if (state.combo === 5) {
      P.cred += 3; toast('· 5x COMBO ·\n+ 3 cred', 1400); unlockAchievement('not_a_phase');
    } else if (state.combo === 10) {
      P.cred += 10; toast('· 10x COMBO ·\n+ 10 cred', 1600);
    }
  } else if(!connected) {
    state.combo = 0;
  } else {
    // Repeatable kingdom actors provide hit feel but cannot mint combo cred.
    state.combo = 0;state.comboT=0;
  }
}

export function onNpcDeath(n) {
  if(n.essential){n.dead=false;n.hp=n.maxHp;return;}
  if(n.kingdomBoss){n.dead=true;audio.hurt();completeKingdomBoss(n);return;}
  if(n.kingdomPretender){n.dead=true;audio.hurt();completeKingdomPretender(n);return;}
  if(n.kingdomAdd){n.dead=true;audio.hurt();toast(n.name.toLowerCase()+' is removed from the minutes.',1400);return;}
  if(n.kingdomGuard){n.dead=true;audio.hurt();toast(n.name.toLowerCase()+' files an objection from the ground.\nno payment authorized.',1800);return;}
  n.dead = true;
  audio.hurt();
  if (n.id === 'tony' && state.bossActive && state.bossKind === 'tony') {
    state.bossActive = false;
    state.bossKind = '';
    state.bossPhase = 0;
    state.bossNPC = null;
    P.cred += 200;
    state.quests.fallen_king.done = true; questToast('THE FALLEN KING');
    maybeUnlockKingdom(false,false);syncKingdomQuests();
    // tony drops his shoe
    pickupWeapon('shoe');
    const wasCoop = state.coopMode;
    toast(wasCoop
      ? "tony is on the ground.\nstripe nods. 'good. tuesdays and thursdays. as agreed.'"
      : "tony is on the ground.\nthe corner is yours.\nyou get tuesdays and thursdays.", 5500);
    // The delayed receipt is presentation. The paid corner result is durable immediately.
    saveGame();
    setTimeout(() => endingScreen(wasCoop ? 'coop' : 'tony'), 4000);
    return;
  }
  if (n.id === 'brutus_older' && n.isBossB) {
    state.brutusOlderActive = false;
    P.cred += 100; P.maxHp += 5;
    toast("BRUTUS THE OLDER IS DOWN.\nyou get +5 max hp.\n(it is called BRUTUS'S COLLAR.)\nyou are wearing the collar now.", 5500);
    broadcastNews("BRUTUS THE OLDER DEFEATED. NEIGHBORHOOD UNCERTAIN HOW TO FEEL.");
    feedPost("the dog returned. then he didn't. legend.", '@crackheadcent');
    return;
  }
  // v13 wave 8a — OLD SCHOOL BRUTUS death drops: $80 cash pile + 5 copper + guaranteed propane torch
  // (no-dupe gated). street faction +2. SCHOOL_S_OUT achievement.
  if (n.id === 'os_brutus') {
    P.cred += 50;
    adjustFaction('street', 2);
    // cash pile — v13 wave 8b: scaled by current territory cash mult (scrap LIKED/LOVED → bigger)
    runtime.cashPiles.push({
      id: 'cp_os_brutus_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 - 22, y: n.y + n.h/2 + 8,
      amt: Math.round(80 * (state.territoryCashMult || 1.0)), collected: false,
    });
    // copper goes straight to inventory (he was sitting on it)
    P.copper += 5;
    state.counters.copperStripped = (state.counters.copperStripped||0) + 5;
    if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
    // guaranteed propane torch (no-dupe gated)
    if (!hasPropane()) {
      runtime.cashPiles.push({
        id: 'cp_os_torch_'+Math.random().toString(36).slice(2,6),
        x: n.x + n.w/2 + 22, y: n.y + n.h/2 + 8,
        amt: 0, tool: 'propane_torch', collected: false,
      });
    }
    unlockAchievement('school_s_out');
    // v13 wave 8.6 — flip the first-rip gate. subsequent rips revert to 40% probabilistic spawn
    // (the cousins). read in openOldSchoolInterior's rip handler.
    state.flags.osBrutusKilled = true;
    toast("OLD SCHOOL BRUTUS IS DOWN.\n+ $80. + 5 copper. + a torch he had on him.\nthe gym is finally quiet.", 5500);
    broadcastNews("THE OLD SCHOOL IS QUIET. SOMETHING LARGE NO LONGER LIVES IN THE GYM.");
    feedPost("school's out. the old school is empty. the copper is gone.", '@blocklog');
    saveGame();
    return;
  }
  // brutus killed — count toward Older trigger
  if (n.id === 'brutus') {
    P.brutusDefeated = (P.brutusDefeated||0) + 1;
    if (P.brutusDefeated >= 5) {
      setTimeout(spawnBrutusOlder, 1500);
    }
  }
  // v13 wave 5 — fallen priest death: drops $200 cash + the priest's collar pickup.
  // re-uses the cash-pile pickup pattern, with a collar variant tagged via `equip` field.
  if (n.isOmalleyFallen) {
    state.flags.omalleyFallenDead = true;
    adjustFaction('street', 2); // wave 7 — killing fallen priest = street +2
    runtime.cashPiles.push({
      id:'cp_plate_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 - 18, y: n.y + n.h/2 + 8,
      amt: 200, collected: false,
    });
    runtime.cashPiles.push({
      id:'cp_collar_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 + 18, y: n.y + n.h/2 + 8,
      amt: 0, equip: 'priest_collar', collected: false,
    });
    if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
      state.quests.fallen_priest.done = true;
      state.quests.fallen_priest.available = false;
      questToast("THE FALLEN PRIEST");
    }
    unlockAchievement('fallen');
    toast("the church is quiet again.\nthe pews are still wrong.", 4200);
    broadcastNews("PRIEST 'GONE'. CHURCH 'WEIRD NOW'. WITNESSES VAGUE.");
    feedPost("the priest is on the ground. the collar is on the floor. you have both.", '@crackheadcent');
    saveGame();
    return;
  }

  // v13 wave 4 — propane torch drops 25% on a night-time brutus kill (regular or older).
  // uses the existing cash-pile pickup pattern, with a `tool` field that triggers equip-on-pickup.
  // v13 wave 7 — street loved bumps the drop rate to ~37.5% (+50%).
  const torchDropRate = factionTier(P.faction ? P.faction.street : 0) === 'loved' ? 0.375 : 0.25;
  if ((n.id === 'brutus' || n.id === 'brutus_older') && isNight() && !hasPropane() && Math.random() < torchDropRate) {
    runtime.cashPiles.push({
      id:'cp_torch_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2, y: n.y + n.h/2 + 8,
      amt: 0, tool: 'propane_torch', collected: false,
    });
    toast("something falls off his collar.\nit smells like a parking lot.", 2400);
  }
  if (n.isCop) {
    P.cred += 10; P.wanted = Math.min(3, P.wanted+1); P.lifetime.copsKilled++;
    if (n.isBrendan) {
      // drops a "rookie badge" — uses the existing cash-pile pickup mechanic. $30.
      cashPiles.push({ id:'cp_brendan_'+Math.random().toString(36).slice(2,6), x:n.x+n.w/2, y:n.y+n.h/2+8, amt:30, collected:false });
      unlockAchievement('badge_money');
      if (!state.counters.brendanFirstKill) {
        state.counters.brendanFirstKill = 1;
        feedPost("uncle dean is posting on facebook again.", '@local_eyewitness');
        broadcastNews("LOCAL ROOKIE DOWN. UNCLE DEAN POSTING. FAMILY GROUP CHAT GOES QUIET.");
      } else {
        feedPost("brendan again. the family is going to have words.", '@local_eyewitness');
      }
      toast('+ 10 cred · wanted +1\ncousin brendan is on the ground.\nhis badge fell out. it is yours now.');
    } else {
      toast('+ 10 cred · wanted +1\na cop is on the ground.');
    }
    // v13 wave 7 — killing a cop = street -3, spiritual +1 (mom would have wanted you to fight back)
    applyRep({ street: -3, spiritual: 1 });
  }
  else { P.cred += 3; toast('+ 3 cred\n'+n.name+' is on the ground.'); }
  // alley kill counter for hustles
  if (['lurch','sherri','paulie'].includes(n.id)) {
    state.counters.alleyKills = (state.counters.alleyKills||0) + 1;
  }
  // v13 wave 7 — street-affiliated kills nudge street rep up (the block respects a finisher)
  if (['brutus','brutus_older','lurch','sherri','paulie'].includes(n.id)) {
    adjustFaction('street', 1);
  }
  // v13 wave 3 — dave drops the crossword if he had it
  if (n.id === 'dave' && state.flags && state.flags.daveHasCrossword && !state.flags.hasCrossword) {
    state.flags.daveHasCrossword = false;
    state.flags.hasCrossword = true;
    P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
    toast("a folded newspaper falls out of his coat.\n+ saturday crossword", 3000);
  }
  // mayor_of_4th — all 3 alley NPCs defeated this run
  const alleyDead = ['lurch','sherri','paulie'].every(id => runtime.npcs.find(x=>x.id===id)?.dead);
  if (alleyDead) unlockAchievement('mayor_of_4th');
  // stripe betrayed
  if (n.id === 'stripe') {
    state.counters.stripeBetrayed++;
    if (state.counters.plateStolen >= 1 && state.counters.stripeBetrayed >= 1) unlockAchievement('judas');
  }
  // weapon drops
  if (n.id === 'larry' && !P.weapon || P.weapon === 'fists') { pickupWeapon('pipe'); }
  if (n.id === 'lurch' && Math.random() < 0.5) { pickupWeapon('brick'); }
  if (n.id === 'paulie' && Math.random() < 0.5) { pickupWeapon('baguette'); }
  // drops
  if (n.id !== 'cop' && Math.random()<0.5) { P.cash += 2 + Math.floor(Math.random()*5); toast('+ a few dollars', 1400); }
  saveGame();
}

export function damagePlayer(amount, src) {
  if (P.iframes > 0) return;
  P.hp -= amount;
  P.iframes = 500;
  P.hitFlash = 250;
  audio.hurt();
  state.flash = 1; state.flashColor = 'rgba(160,40,40,.4)';
  state.shake = 8;
  state.combo = 0; // break combo
  if (src) {
    const dx = P.x - src.x, dy = P.y - src.y;
    const len = Math.sqrt(dx*dx+dy*dy)||1;
    P.x += (dx/len)*8; P.y += (dy/len)*8;
  }
  if (P.hp <= 0) {
    if (src && src.id === 'brutus') {
      state.counters.brutusDeaths++;
      if (state.counters.brutusDeaths >= 3) unlockAchievement('brutus_remembers');
    }
    if (src && src.isCop) arrestScene();
    else die();
  }
}

export function die() {
  abortKingdomFight(false);
  audio.death();
  P.hp = 60; P.shakes = 30; P.cred = Math.max(0, P.cred-10); P.wanted = 0;
  P.x = 1050; P.y = 840; P.iframes = 1000;
  // cops vanish
  runtime.npcs = runtime.npcs.filter(n => !n.isCop);
  toast('you wake up at the block.\nyour mouth tastes like a battery.\nit is approximately tuesday.', 3500);
  saveGame();
}

export function arrestScene() {
  abortKingdomFight(false);
  P.lifetime.arrests = (P.lifetime.arrests||0)+1;
  const lostCash = Math.floor(P.cash * 0.7);
  P.cash -= lostCash; P.rocks = 0; P.shakes = 100; P.wanted = 0; P.hp = 40;
  P.x = 1050; P.y = 840;
  runtime.npcs = runtime.npcs.filter(n => !n.isCop);
  toast(`arrested.\n- $${lostCash} · - all rocks\nthey didn't check your sock.`, 4000);
  feedPost("arrested again. they did not check the sock. the sock is safe.", '@crackheadcent');
  saveGame();
}

export function spawnCopAtEdge(reason) {
  if (runtime.npcs.filter(n => n.isCop && !n.dead).length >= COP_HARD_CAP) return null;
  // pick the nearest world edge to the player
  const px = P.x+P.w/2, py = P.y+P.h/2;
  const dl = px, dr = WORLD.w - px, du = py, dd = WORLD.h - py;
  const m = Math.min(dl, dr, du, dd);
  let x, y;
  if (m === dl)      { x = 30;            y = clamp(py + (Math.random()-.5)*300, 40, WORLD.h-40); }
  else if (m === dr) { x = WORLD.w - 30;  y = clamp(py + (Math.random()-.5)*300, 40, WORLD.h-40); }
  else if (m === du) { y = 30;            x = clamp(px + (Math.random()-.5)*300, 40, WORLD.w-40); }
  else               { y = WORLD.h - 30;  x = clamp(px + (Math.random()-.5)*300, 40, WORLD.w-40); }
  const cop = {
    id:'cop_'+Math.random().toString(36).slice(2,6), name:'COP', sprite:'cop',
    x, y, w:28, h:32, color:'#1818a0', hp:60, maxHp:60, speed:1.5, dmg:10,
    hostile:true, aggro:true, isCop:true, attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true,
    archetype:'cop',
  };
  runtime.npcs.push(cop);
  if (reason === 'radio') audio.copSiren();
  return cop;
}

export function manageCops(dt) {
  if (P.wanted > 0) {
    // v13 wave 5 — priest's collar speeds wanted decay (wantedDecayMult > 1.0).
    const decayMult = P.wantedDecayMult || 1.0;
    P.wantedT += dt * decayMult;
    // decay -1 every 18s (faster with collar)
    if (P.wantedT >= 18000) {
      P.wantedT = 0; P.wanted--;
      if (P.wanted === 0) toast('the heat dies down.\nfor now.', 1500);
    }
    const targetCops = P.wanted;
    const liveCops = runtime.npcs.filter(n=>n.isCop && !n.dead).length;
    if (liveCops < targetCops && liveCops < COP_HARD_CAP) {
      audio.copSiren();
      // v13 wave 2 — at wanted ≥ 2, one spawning cop has a 30% chance of being cousin brendan.
      // hard cap at one brendan on the map at a time.
      const liveBrendan = runtime.npcs.find(n => n.isBrendan && !n.dead);
      const spawnBrendan = (P.wanted >= 2) && !liveBrendan && (Math.random() < 0.3);
      const cop = spawnBrendan ? {
        id:'brendan_'+Math.random().toString(36).slice(2,6), name:'COUSIN BRENDAN', sprite:'brendan',
        x: P.x + (Math.random()<.5?-400:400), y: P.y + (Math.random()<.5?-300:300),
        w:26, h:30, color:'#2838c0', hp:55, maxHp:55, speed:2.3, dmg:50,
        hostile:true, aggro:true, isCop:true, isBrendan:true, taserChargeT:0,
        attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true, archetype:'brendan',
      } : {
        id:'cop_'+Math.random().toString(36).slice(2,6), name:'COP', sprite:'cop',
        x: P.x + (Math.random()<.5?-400:400), y: P.y + (Math.random()<.5?-300:300),
        w:28, h:32, color:'#1818a0', hp:60, maxHp:60, speed:1.5, dmg:10,
        hostile:true, aggro:true, isCop:true, attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true,
        archetype:'cop',
      };
      cop.x = clamp(cop.x, 40, WORLD.w-40);
      cop.y = clamp(cop.y, 40, WORLD.h-40);
      runtime.npcs.push(cop);
      if (spawnBrendan) {
        const lines = [
          "stop! it's me!! it's brendan!!",
          "uncle dean said don't make him come down here!!",
        ];
        setTimeout(() => toast("· COUSIN BRENDAN ARRIVES ·\n" + lines[Math.floor(Math.random()*lines.length)], 3200), 500);
      }
    }
    // v13 wave 5 — radio-for-backup. regular cops (not brendan) at >120px from player
    // roll 25%/sec to radio in another cop. cap at 4 total. brendan does not radio.
    for (const cop of runtime.npcs) {
      if (!cop.isCop || cop.dead || cop.isBrendan) continue;
      const cdx = (P.x+P.w/2) - (cop.x+cop.w/2), cdy = (P.y+P.h/2) - (cop.y+cop.h/2);
      const cdist2 = cdx*cdx + cdy*cdy;
      if (cdist2 < 120*120) { cop.radioT = 0; continue; }
      cop.radioCdT = (cop.radioCdT||0) - dt;
      cop.radioT = (cop.radioT||0) + dt;
      // chance roll once per second window (25% per second)
      if (cop.radioCdT <= 0 && Math.random() < 0.25 * (dt/1000)) {
        cop.radioCdT = 5000; // 5s minimum between radios per cop
        cop.radioVisualT = 800; // hand-to-ear pose
        audio.radio();
        // "*" particle above the cop's head
        particles.push({x: cop.x+cop.w/2, y: cop.y-6, vx:0, vy:-0.4, life:700, c:'#88c0ff', sz:3, glow:true});
        // backup arrives within 5 seconds
        const delay = 800 + Math.random()*4000;
        setTimeout(() => {
          if (cop.dead) return; // canceled if the caller dies
          if (P.wanted <= 0) return;
          spawnCopAtEdge('radio');
          if (runtime.npcs.filter(n=>n.isCop&&!n.dead).length <= COP_HARD_CAP) {
            toast("more flashing lights.\nfrom somewhere.", 1800);
          }
        }, delay);
      }
      if (cop.radioVisualT) cop.radioVisualT = Math.max(0, cop.radioVisualT - dt);
    }
  } else {
    P.wantedT = 0;
  }
}

export function init_combat() {
  
  
  // v13 wave 5 — swarm pair: spawn a clone of sherri 60px to the side.
  // cap: 2 live sherris on the map.
  
  
  // v13 wave 5 — generic projectile spawn used by ranged + fallen-priest patterns.
  
  
  
  // ---------- v13 wave 3: intro chain helpers ----------
  
  
  
  
  // v13 wave 3 — pick a crown spot from the 6 candidates using a per-save seed so the location
  // is deterministic for the playthrough but varies between saves.
  
  
  
  // ---------- SPAWN BOSS ----------
  
  
  // ---------- COMBAT ----------
  
  
  
  
  
  
  
  
  
  
  // ---------- WANTED & COPS ----------
  // v13 wave 5 — global cop cap. existing intent was N=wanted but radio-for-backup
  // can push us past that. hard ceiling at 4 keeps the screen survivable.
  COP_HARD_CAP = 4;
  
  
  
  
}

export function updateNpcActors(dt) {
  // NPC AI + walk-frame anim + chatter
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    n.attackCd = Math.max(0, (n.attackCd||0) - dt);
    if (n.hitFlash) n.hitFlash = Math.max(0, n.hitFlash - dt);
    // v13 wave 5 — hit-stun freezes NPC AI for 120ms post-damage.
    if (n.hitStun > 0) { n.hitStun = Math.max(0, n.hitStun - dt); continue; }
    if (n.chatterT > 0) n.chatterT -= dt;
    // ambient chatter
    n.chatterCd = (n.chatterCd||0) - dt;
    if (n.chatterCd <= 0 && !n.asleep && !n.aggro) {
      n.chatterCd = 7000 + Math.random()*9000;
      const dx2 = (P.x+P.w/2) - (n.x+n.w/2), dy2 = (P.y+P.h/2) - (n.y+n.h/2);
      if (dx2*dx2 + dy2*dy2 < 380*380 && CHATTER[n.id]) {
        const lines = CHATTER[n.id];
        n.chatter = lines[Math.floor(Math.random()*lines.length)];
        n.chatterT = 2600;
      }
    }

    const pdx = (P.x+P.w/2) - (n.x+n.w/2);
    const pdy = (P.y+P.h/2) - (n.y+n.h/2);
    const pd2 = pdx*pdx + pdy*pdy;

    // zoneOnly hostility
    if (n.zoneOnly && !n.aggro) {
      const z = n.zoneOnly;
      const px = P.x+P.w/2, py = P.y+P.h/2;
      n.hostile = (px>=z.x && px<=z.x+z.w && py>=z.y && py<=z.y+z.h);
    }

    let isMoving = false;
    // pet possum AI — follow player at distance, occasionally reveals cash
    if (n.isPet) {
      const pdxP = P.x - n.x, pdyP = P.y - n.y;
      const pdistP = Math.sqrt(pdxP*pdxP + pdyP*pdyP);
      if (pdistP > 48) {
        n.x += (pdxP/pdistP) * (n.speed||1.6) * (dt/16);
        n.y += (pdyP/pdistP) * (n.speed||1.6) * (dt/16);
        isMoving = true;
      } else if (pdistP < 24) {
        n.x -= (pdxP/pdistP) * 0.4 * (dt/16);
        n.y -= (pdyP/pdistP) * 0.4 * (dt/16);
      }
      // periodic cash-pile reveal — possum only (v13 wave 6: freed dog also uses isPet, skip for it).
      if (n.id === 'pet_possum') {
        n.revealT = (n.revealT||0) - dt;
        if (n.revealT <= 0) {
          n.revealT = 30000 + Math.random()*15000;
          const uncollected = runtime.cashPiles.filter(c => !c.collected);
          if (uncollected.length) {
            const target = uncollected[Math.floor(Math.random()*uncollected.length)];
            // teleport one cash pile near the player
            target.x = P.x + (Math.random()-.5)*60;
            target.y = P.y + 40 + Math.random()*30;
            for (let i=0;i<6;i++) particles.push({x:target.x, y:target.y, vx:(Math.random()-.5)*3, vy:-Math.random()*3, life:600, c:'#e8c040', sz:3});
            toast("the possum has placed something for you.\n(look around your feet.)", 2400);
          }
        }
      }
    }
    // ally AI (stripe in coop)
    if (n.isAlly) {
      const target = runtime.npcs.find(x => x.id === (n.allyTarget||'tony') && !x.dead);
      if (target) {
        const adx = target.x - n.x, ady = target.y - n.y;
        const alen = Math.sqrt(adx*adx+ady*ady)||1;
        if (alen > 30) {
          n.x += (adx/alen) * (n.speed||1.4) * (dt/16);
          n.y += (ady/alen) * (n.speed||1.4) * (dt/16);
          isMoving = true;
        } else {
          // hit
          n.attackCd = (n.attackCd||0);
          if (n.attackCd <= 0) {
            target.hp -= 10; target.hitFlash = 180; target.showHp = true;
            n.attackCd = 700;
            for (let i=0;i<4;i++) particles.push({x:target.x+target.w/2,y:target.y+target.h/2,vx:(Math.random()-.5)*4,vy:(Math.random()-.5)*4,life:280,c:'#88c0ff',sz:3});
            if (target.hp <= 0) onNpcDeath(target);
          }
        }
      } else {
        // patrol nearby player
        const dxP = P.x - n.x, dyP = P.y - n.y;
        const lenP = Math.sqrt(dxP*dxP+dyP*dyP);
        if (lenP > 80) { n.x += (dxP/lenP)*(n.speed||1.2)*(dt/16); n.y += (dyP/lenP)*(n.speed||1.2)*(dt/16); isMoving = true; }
      }
    }
    // aggro chase — v13 wave 5: archetype dispatch. patterns mutate the chase/touch flow.
    // existing non-archetype'd NPCs fall through to the default chase-bite (unchanged behavior).
    else if (n.aggro || (n.hostile && pd2 < 360*360)) {
      const len = Math.sqrt(pd2)||1;
      const arch = n.archetype || 'default';

      // ---------------- CHARGER (brutus, brutus_older) ----------------
      // windup → lunge → cooldown state machine. brutus_older variant has shorter windup,
      // longer lunge, bigger multiplier, longer cooldown — plus "berserk" variant when boss
      // is in phase 3 (state.brutusOlderPhase>=3 or n.berserk flag).
      if (arch === 'charger' || arch === 'charger_older') {
        const older = (arch === 'charger_older');
        const berserk = !!n.berserk;
        // tunables per variant + phase
        const windupMs = berserk ? 400 : (older ? 550 : 800);
        const lungeMs  = berserk ? 800 : (older ? 1400 : 1000);
        const lungeSpd = berserk ? 3.0 : (older ? 2.4 : 2.0);
        const dmgMult  = berserk ? 2.0 : (older ? 1.8 : 1.5);
        const cdMs     = berserk ? 600 : (older ? 1700 : 1400);

        n.chargeState = n.chargeState || 'idle';
        n.chargeT = n.chargeT || 0;
        n.chargeCdT = Math.max(0, (n.chargeCdT||0) - dt);

        if (n.chargeState === 'cooldown') {
          n.chargeT -= dt;
          if (n.chargeT <= 0) { n.chargeState = 'idle'; n.chargeT = 0; }
          // panting — light wobble, no movement
        }
        else if (n.chargeState === 'windup') {
          n.chargeT -= dt;
          // visible tint pulse driven by hitFlash short bursts so existing renderer picks it up
          if ((n.chargeT % 90) < 45) n.hitFlash = Math.max(n.hitFlash||0, 40);
          if (n.chargeT <= 0) {
            // commit the lunge — direction is fixed at windup START via stored vector
            n.chargeState = 'lunge';
            n.chargeT = lungeMs;
            audio.bossRoar();
          }
        }
        else if (n.chargeState === 'lunge') {
          n.chargeT -= dt;
          if (n.lungeVx !== undefined) {
            n.x += n.lungeVx * lungeSpd * (dt/16);
            n.y += n.lungeVy * lungeSpd * (dt/16);
            isMoving = true;
          }
          // hit detection during lunge
          if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
            damagePlayer(Math.floor((n.dmg||8) * dmgMult), n);
            n.attackCd = 600;
            n.chargeState = 'cooldown';
            n.chargeT = cdMs;
            n.chargeCdT = cdMs;
            n.chargeLanded = true;
          }
          if (n.chargeT <= 0) {
            // lunge missed — DODGED_THE_LUNGE achievement on first dodge
            if (!n.chargeLanded) unlockAchievement('dodged_the_lunge');
            n.chargeLanded = false;
            n.chargeState = 'cooldown';
            n.chargeT = cdMs;
            n.chargeCdT = cdMs;
          }
        }
        else {
          // idle — slow chase, enter windup when in range
          if (n.speed > 0) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          }
          if (pd2 < 200*200 && n.chargeCdT <= 0) {
            n.chargeState = 'windup';
            n.chargeT = windupMs;
            // freeze position; lock lunge vector toward player NOW
            const llen = Math.sqrt(pd2) || 1;
            n.lungeVx = pdx/llen;
            n.lungeVy = pdy/llen;
            audio.windup();
          }
        }
        // touch damage outside the charge (passive bite while idle/chasing close)
        if (n.chargeState === 'idle' && rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          damagePlayer(n.dmg||8, n);
          n.attackCd = 800;
        }
      }

      // ---------------- GRABBER (lurch) ----------------
      // chase-bite at ×1.3 damage, applies 500ms stun on contact.
      else if (arch === 'grabber') {
        if (n.speed > 0) {
          // lurch freezes briefly post-grab for the "arms-extended" beat
          const grabFreeze = (n.grabFreezeT||0) > 0;
          if (!grabFreeze) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          } else {
            n.grabFreezeT = Math.max(0, (n.grabFreezeT||0) - dt);
          }
        }
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          const dmg = Math.floor((n.dmg||8) * 1.3);
          damagePlayer(dmg, n);
          n.attackCd = 800;
          n.grabFreezeT = 200;
          P.stunT = Math.max(P.stunT||0, 500);
          // toast only on first grab per encounter (avoid spam)
          if (!n.grabbedOnce) { n.grabbedOnce = true; toast("GRABBED.\nhis arms are too long.", 1400); }
        }
      }

      // ---------------- SWARMER (sherri) ----------------
      // speed ×1.4, damage ×0.6. on aggro also calls a sibling (in aggroNpc).
      else if (arch === 'swarmer') {
        if (n.speed > 0) {
          const swSpd = n.speed * 1.4;
          n.x += (pdx/len) * swSpd * (dt/16);
          n.y += (pdy/len) * swSpd * (dt/16);
          isMoving = true;
        }
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          const dmg = Math.max(1, Math.floor((n.dmg||5) * 0.6));
          damagePlayer(dmg, n);
          n.attackCd = 700;
        }
      }

      // ---------------- RANGED (paulie) ----------------
      // keep 180-260px. throws bottles every 1500ms. panic-chase if player < 120px.
      else if (arch === 'ranged') {
        const d = Math.sqrt(pd2);
        n.panicT = Math.max(0, (n.panicT||0) - dt);
        n.throwT = (n.throwT||0) - dt;
        n.throwAimT = Math.max(0, (n.throwAimT||0) - dt);
        if (d < 120 && n.panicT <= 0) n.panicT = 1000; // panic for 1s when player closes
        if (n.panicT > 0) {
          // chase-bite for 1s
          if (n.speed > 0) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          }
          if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
            damagePlayer(n.dmg||7, n);
            n.attackCd = 800;
          }
        } else {
          // kite to keep 180-260px
          let mx = 0, my = 0;
          if (d < 180) { mx = -pdx/len; my = -pdy/len; isMoving = true; }
          else if (d > 260) { mx = pdx/len; my = pdy/len; isMoving = true; }
          // strafe a bit when in band
          else { const a = performance.now()/500; mx = -pdy/len * Math.sin(a); my = pdx/len * Math.sin(a); }
          n.x += mx * (n.speed||1.5) * (dt/16);
          n.y += my * (n.speed||1.5) * (dt/16);
          // throw bottles
          if (n.throwT <= 0 && d >= 160 && d <= 280) {
            // 300ms aim-raise telegraph before the throw
            if (n.throwAimT <= 0 && !n.aimingThrow) {
              n.aimingThrow = true;
              n.throwAimT = 300;
              // tiny "*" particle
              particles.push({x:n.x+n.w/2+8, y:n.y+4, vx:0, vy:-0.3, life:400, c:'#fff080', sz:2, glow:true});
            } else if (n.aimingThrow && n.throwAimT <= 0) {
              n.aimingThrow = false;
              n.throwT = 1500;
              spawnProjectile({
                x: n.x+n.w/2, y: n.y+n.h/2,
                tx: P.x+P.w/2, ty: P.y+P.h/2,
                speed: 320, dmg: 15, kind: 'bottle', from: n, wobble: 0.35,
              });
              audio.bottleThrow();
            }
          }
        }
      }

      // ---------------- FALLEN PRIEST (priest_fallen) ----------------
      // phase 1 (≥50% hp): keep 180-280px, throw holy water vials every 1200ms (22 dmg + 1.5s slow).
      // phase 2 (<50% hp): becomes a faster charger (×2.4 speed, 500ms windup, lunge applies slow).
      else if (arch === 'priest_fallen') {
        const pct = n.hp / n.maxHp;
        const inPhase2 = pct < 0.5;
        // phase transition once
        if (inPhase2 && !n.fallenPhase2) {
          n.fallenPhase2 = true;
          audio.bossRoar();
          state.shake = 12;
          toast("the lord is not here.\nthe lord left.\nhe took the bus.", 4200);
        }
        if (!inPhase2) {
          // ranged-holy
          const d = Math.sqrt(pd2);
          let mx = 0, my = 0;
          if (d < 180) { mx = -pdx/len; my = -pdy/len; isMoving = true; }
          else if (d > 280) { mx = pdx/len; my = pdy/len; isMoving = true; }
          else { const a = performance.now()/600; mx = -pdy/len * Math.sin(a); my = pdx/len * Math.sin(a); }
          n.x += mx * (n.speed||1.6) * (dt/16);
          n.y += my * (n.speed||1.6) * (dt/16);
          n.throwT = (n.throwT||0) - dt;
          n.throwAimT = Math.max(0, (n.throwAimT||0) - dt);
          if (n.throwT <= 0 && d >= 160 && d <= 300) {
            if (n.throwAimT <= 0 && !n.aimingThrow) {
              n.aimingThrow = true;
              n.throwAimT = 350;
              for (let i=0;i<4;i++) particles.push({x:n.x+n.w/2,y:n.y+8,vx:(Math.random()-.5)*1,vy:-Math.random()*1.5,life:500,c:'#a0d0ff',sz:2,glow:true});
            } else if (n.aimingThrow && n.throwAimT <= 0) {
              n.aimingThrow = false;
              n.throwT = 1200;
              spawnProjectile({
                x: n.x+n.w/2, y: n.y+n.h/2,
                tx: P.x+P.w/2, ty: P.y+P.h/2,
                speed: 280, dmg: 22, slowMs: 1500, kind: 'holy', from: n, wobble: 0.18,
              });
              audio.holyWaterThrow();
            }
          }
        } else {
          // dasher — charger with priest tuning
          n.chargeState = n.chargeState || 'idle';
          n.chargeT = n.chargeT || 0;
          n.chargeCdT = Math.max(0, (n.chargeCdT||0) - dt);
          const windupMs = 500, lungeMs = 900, lungeSpd = 2.4, cdMs = 1200;
          if (n.chargeState === 'cooldown') {
            n.chargeT -= dt;
            if (n.chargeT <= 0) { n.chargeState = 'idle'; }
          } else if (n.chargeState === 'windup') {
            n.chargeT -= dt;
            if ((n.chargeT % 90) < 45) n.hitFlash = Math.max(n.hitFlash||0, 40);
            if (n.chargeT <= 0) {
              n.chargeState = 'lunge';
              n.chargeT = lungeMs;
            }
          } else if (n.chargeState === 'lunge') {
            n.chargeT -= dt;
            if (n.lungeVx !== undefined) {
              n.x += n.lungeVx * lungeSpd * (dt/16);
              n.y += n.lungeVy * lungeSpd * (dt/16);
              isMoving = true;
            }
            if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
              damagePlayer(30, n);
              P.slowT = Math.max(P.slowT||0, 1500);
              n.attackCd = 600;
              n.chargeState = 'cooldown';
              n.chargeT = cdMs;
              n.chargeLanded = true;
            }
            if (n.chargeT <= 0) {
              if (!n.chargeLanded) unlockAchievement('dodged_the_lunge');
              n.chargeLanded = false;
              n.chargeState = 'cooldown';
              n.chargeT = cdMs;
            }
          } else {
            if (n.speed > 0) {
              n.x += (pdx/len) * (n.speed||1.6) * (dt/16);
              n.y += (pdy/len) * (n.speed||1.6) * (dt/16);
              isMoving = true;
            }
            if (pd2 < 220*220 && n.chargeCdT <= 0) {
              n.chargeState = 'windup';
              n.chargeT = windupMs;
              const llen = Math.sqrt(pd2) || 1;
              n.lungeVx = pdx/llen; n.lungeVy = pdy/llen;
              audio.windup();
            }
          }
        }
      }

      // ---------------- DEFAULT chase-bite (cops, larry, dave when aggro'd, etc) ----------------
      else {
        if (n.speed > 0) {
          // v13 wave 6 — fed/free dog cop-discomfort radius: cops at 0.5x speed near a friendly dog.
          // dogSpookSlow flag is set in updateWorld each frame; cleared at the end of this branch.
          const spookMult = (n.dogSpookSlow && (n.cop || n.id==='brendan' || n.id==='horsecop')) ? 0.5 : 1;
          n.x += (pdx/len) * n.speed * spookMult * (dt/16);
          n.y += (pdy/len) * n.speed * spookMult * (dt/16);
          isMoving = true;
        }
        // clear the per-frame flag so it can be re-set next tick
        if (n.dogSpookSlow) n.dogSpookSlow = 0;
        // v13 wave 2 — brendan's taser charges over 4 seconds; only zaps when ready.
        if (n.isBrendan) {
          n.taserChargeT = Math.min(4000, (n.taserChargeT||0) + dt);
        }
        // touch damage
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && n.attackCd===0) {
          if (n.isBrendan) {
            if (n.taserChargeT >= 4000) {
              damagePlayer(50, n);
              n.taserChargeT = 0;
              n.attackCd = 1000;
              audio.copSiren();
              for (let i=0;i<10;i++) particles.push({x:P.x+P.w/2,y:P.y+P.h/2,vx:(Math.random()-.5)*6,vy:(Math.random()-.5)*6,life:400,c:'#88c0ff',sz:3,glow:true});
            }
          } else {
            damagePlayer(n.dmg||8, n);
            n.attackCd = 800;
          }
        }
      }
    } else if (n.patrol) {
      // patrol along path
      n.patrolT = (n.patrolT||0) + dt;
      const tgt = n.patrol[Math.floor((n.patrolT/2000) % n.patrol.length)];
      const tdx = tgt.x - n.x, tdy = tgt.y - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * (n.speed||1) * (dt/16);
        n.y += (tdy/tlen) * (n.speed||1) * (dt/16);
        isMoving = true;
      }
    } else if (n.wanderOff) {
      // v13 wave 7 — day-event actor walking off-map. once past world bounds, despawn.
      const tdx = (n.targetX||(WORLD.w+80)) - n.x, tdy = (n.targetY||n.y) - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * (n.speed||1.2) * (dt/16);
        n.y += (tdy/tlen) * (n.speed||1.2) * (dt/16);
        isMoving = true;
      } else {
        n.dead = true;
      }
    } else if (n.wander && n.speed > 0) {
      n.wanderT = (n.wanderT||0) - dt;
      if (n.wanderT <= 0) {
        n.wanderT = 1500 + Math.random()*2000;
        n.targetX = n.x + (Math.random()-.5) * 120;
        n.targetY = n.y + (Math.random()-.5) * 120;
      }
      const tdx = n.targetX - n.x, tdy = n.targetY - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * n.speed*0.4 * (dt/16);
        n.y += (tdy/tlen) * n.speed*0.4 * (dt/16);
        isMoving = true;
      }
    }
    if((n.kingdomGuard||n.kingdomPretender||n.kingdomBoss||n.kingdomAdd)&&n.zoneOnly){
      const z=n.zoneOnly;n.x=clamp(n.x,z.x+6,z.x+z.w-n.w-6);n.y=clamp(n.y,z.y+6,z.y+z.h-n.h-6);
    }
    // frame anim
    if (isMoving) {
      n.frameT = (n.frameT||0) + dt;
      if (n.frameT > 200) { n.frameT = 0; n.frame = (n.frame||0)+1; if (n.frame>2) n.frame=1; }
    } else { n.frame = 0; n.frameT = 0; }
    // pothole "talks" — cycles frames always
    if (n.id === 'pothole') n.frame = Math.floor(performance.now()/220) % 3;
    // cart roadkill
    if (P.cartMounted && rectsOverlap({x:P.x-4,y:P.y-4,w:P.w+8,h:P.h+8}, n) && n.attackCd===0 && (n.hostile||n.aggro)) {
      n.hp -= 14; n.hitFlash = 180; n.attackCd = 600;
      const ang = Math.atan2(n.y-P.y, n.x-P.x);
      n.x += Math.cos(ang)*10; n.y += Math.sin(ang)*10;
      audio.hit();
      if (n.hp <= 0) onNpcDeath(n);
    }
  }
}

export function init_npc_ai() {
  // ---------- NPC AI + walk-frame anim + chatter ----------
  
  
}

export let last;

export function update(now) {
  try {
    const dt = Math.min(50, now - last); last = now;
    if (state.mode === 'playing' && state.hitPause <= 0) {
      updateWorld(dt);
    } else if (state.hitPause > 0) {
      // freeze frame — only decay timers
      state.hitPause -= dt;
    } else if (state.mode === 'cookmini') {
      updateHeatMini(dt);
    }
    // smoke overlay countdown (post-burn, runs regardless of mode)
    if (state.smokeT > 0) state.smokeT = Math.max(0, state.smokeT - dt);
    drawAll();
  } catch (err) {
    console.error('update error', err);
    window.__updateErr = err && (err.stack || err.message);
  }
  requestAnimationFrame(update);
}

export function updateWorld(dt) {
  // v16: keyboard movement is event-latched. A held key remains down until keyup,
  // modal clearing, blur, or visibility loss; key-repeat cadence is never release evidence.
  // input — v13 wave 5: P.stunT gates ALL inputs (lurch grab, fallen priest grabs at p2).
  let vx=0, vy=0;
  // tick status timers regardless
  if (P.stunT > 0) P.stunT = Math.max(0, P.stunT - dt);
  if (P.slowT > 0) P.slowT = Math.max(0, P.slowT - dt);
  const stunned = P.stunT > 0;
  if (!stunned) {
    if (state.keys.has('w') || state.keys.has('arrowup')) { vy = -1; P.facing = 'up'; }
    if (state.keys.has('s') || state.keys.has('arrowdown')) { vy = 1; P.facing = 'down'; }
    if (state.keys.has('a') || state.keys.has('arrowleft')) { vx = -1; P.facing = 'left'; }
    if (state.keys.has('d') || state.keys.has('arrowright')) { vx = 1; P.facing = 'right'; }
    if (vx && vy) { vx *= 0.7071; vy *= 0.7071; }
    // analog joystick input overrides keys when active
    if (state.stickMag && state.stickMag > 0) {
      vx = state.stickX * state.stickMag;
      vy = state.stickY * state.stickMag;
      // facing — derived from larger axis
      if (Math.abs(vx) > Math.abs(vy)) P.facing = vx > 0 ? 'right' : 'left';
      else P.facing = vy > 0 ? 'down' : 'up';
    }
  }
  let spd = P.speed;
  if (P.rockedT>0) spd *= 1.8;
  if (P.crashT>0) spd *= 0.5;
  if (P.slowT>0) spd *= 0.5; // priest holy water slow
  let sprinting = !stunned && state.keys.has('shift');
  if (sprinting && (vx||vy)) spd *= 1.7;
  const newX = P.x + vx*spd*(dt/16);
  const newY = P.y + vy*spd*(dt/16);
  // collision against buildings
  let blockedX=false, blockedY=false;
  const r = { x: newX, y: P.y, w: P.w, h: P.h };
  for (const b of BUILDINGS) {
    if (!b.solid) continue;
    if (b.doorGap && newY+P.h > b.y+b.h-30 && newY+P.h < b.y+b.h+30 && newX+P.w/2 > b.x+b.w/2-30 && newX+P.w/2 < b.x+b.w/2+30) continue;
    if (rectsOverlap(r, b)) { blockedX = true; break; }
  }
  const r2 = { x: P.x, y: newY, w: P.w, h: P.h };
  for (const b of BUILDINGS) {
    if (!b.solid) continue;
    if (b.doorGap && newY+P.h > b.y+b.h-30 && newY+P.h < b.y+b.h+30 && P.x+P.w/2 > b.x+b.w/2-30 && P.x+P.w/2 < b.x+b.w/2+30) continue;
    if (rectsOverlap(r2, b)) { blockedY = true; break; }
  }
  if (!blockedX) P.x = newX;
  if (!blockedY) P.y = newY;
  P.x = clamp(P.x, 0, WORLD.w - P.w);
  P.y = clamp(P.y, 0, WORLD.h - P.h);

  // anim
  if (vx || vy) {
    P.frameT += dt;
    if (P.frameT > 120) { P.frameT = 0; P.frame = ((P.frame||0)+1)%4; }
    // dust kick-up under feet
    P.dustT = (P.dustT||0) + dt;
    if (P.dustT > 110) {
      P.dustT = 0;
      particles.push({
        x: P.x+P.w/2 + (Math.random()-.5)*6,
        y: P.y+P.h - 2 + Math.random()*2,
        vx: -vx*0.4 + (Math.random()-.5)*0.4,
        vy: -0.3 - Math.random()*0.2,
        life: 380 + Math.random()*200,
        c: 'rgba(180,160,120,0.55)',
        sz: 2,
      });
    }
  } else { P.frame = 0; P.frameT = 0; }

  // shakes — slowed in v11 per user feedback
  P.shakes += 0.0008 * dt;
  if (sprinting && (vx||vy)) P.shakes += 0.012 * dt;
  P.shakes = clamp(P.shakes, 0, 100);
  if (P.shakes >= 100 && Math.random() < 0.006) damagePlayer(2);

  // passive HP regen at THE BLOCK (home base)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'block') && P.hp < P.maxHp && state.mode === 'playing') {
    P.hp = Math.min(P.maxHp, P.hp + 0.006 * dt);
  }

  // wanted timer
  manageCops(dt);
  updateKingdomBattle(dt);

  // status effects
  if (P.rockedT > 0) {
    P.rockedT -= dt;
    if (P.rockedT <= 0) {
      P.rockedT = 0; P.crashT = 8000;
      P.shakes = clamp(P.shakes+30, 0, 100);
      audio.crash();
      state.flash = 1; state.flashColor = 'rgba(180,80,180,.35)';
      toast('the crash arrives.\non schedule.', 2200);
    }
  } else if (P.crashT > 0) {
    P.crashT -= dt;
    if (P.crashT <= 0) P.crashT = 0;
  }
  if (P.attackCd > 0) P.attackCd -= dt;
  if (P.attacking > 0) P.attacking -= dt;
  if (P.iframes > 0) P.iframes -= dt;
  if (P.hitFlash > 0) P.hitFlash -= dt;

  // tweaker vision
  if (state.tweakerCdT > 0) state.tweakerCdT -= dt;
  if (state.keys.has('f') && state.tweakerT > 0 && P.brain > 0) {
    state.tweakerT -= dt;
    P.brain = Math.max(0, P.brain - dt*0.002);
    if (P.brain <= 0) {
      state.tweakerT = 0;
      toast('your brain has nothing left to give.', 1800);
    }
  } else if (!state.keys.has('f')) {
    state.tweakerT = 0;
  }
  document.getElementById('tweaker').classList.toggle('on', state.tweakerT > 0);

  // day/night cycle — 4 min cycle
  state.dayTime += dt / 240000;
  if (state.dayTime >= 1) {
    state.dayTime -= 1; state.day++; P.lifetime.dayCount = state.day;
    rollWeather();
    // v13 wave 6.5 — daily-reset accumulating counters at dawn (the *Today fields).
    // the *Day fields (kombuchaAskDay, priestDonateDay, etc.) self-reset via
    // "=== state.day" comparison, so they don't need to be zeroed.
    resetDailyCounters();
    rollHustles();
    if (state.day >= 7) unlockAchievement('tuesday_again');
    toast('· day ' + state.day + ' ·\n' + (state.weather==='rain'?'it is raining.':state.weather==='fog'?'fog.':'a tuesday.'), 2400);
    broadcastNews('day ' + state.day + ' has arrived. weather: ' + state.weather + '.');
    feedPost("it is day "+state.day+". this is somehow your life.", '@crackheadcent');
    // occasional garbage truck on new day
    if (Math.random() < 0.5) setTimeout(garbageTruckRumble, 8000);
    // v13 wave 7 — fire day-specific events at dawn rollover (each guarded by once-per-save flag)
    fireDayEvents();
    // v13 wave 7 — mom proud-call rolls at dawn (spiritual LIKED+ only, 1×/day)
    setTimeout(maybeFireMomProudCall, 12000 + Math.random()*30000);
    // v13 wave 8b — mom drops a free bus pass at dawn if spiritual >= liked AND player doesn't have one.
    // Once per day via momBusPassDay stamp. Surfaces a phone-feed line.
    if (P.faction && P.faction.spiritual >= 10 && state.flags.momBusPassDay !== state.day) {
      state.flags.momBusPassDay = state.day;
      if (!hasBusPass()) {
        giveBusPass(true);
        feedPost("mom left a bus pass on the door. mom does not say where it came from.", '@hardcandy');
        setTimeout(() => toast("+ a bus pass\nmom left it on the door.\nthe door does not lock.", 3200), 6000);
      }
    }
    // v13 wave 7 — mom's apartment hideout rent: $30/day if owned. failure evicts.
    if (state.flags && state.flags.momHideoutOwned) {
      if (P.cash >= 30) {
        P.cash -= 30; state.flags.momRentDay = state.day;
        toast("- $30\nmom's couch costs.\nshe says it does not.\nit does.", 3000);
      } else {
        state.flags.momHideoutOwned = false;
        toast("ben put your bag in the hallway.\nthe spare key does not fit anymore.\n(mom's couch — closed.)", 4000);
        feedPost("got put out. ben works late, ben changed the locks.", '@crackheadcent');
        adjustFaction('spiritual', -3);
      }
    }
  }
  applyDayNight();

  // v13 wave 3 — intro chain suppression. during the intro, suppress ambient phone calls,
  // random world events, and hustle generation so day 1 is focused on the three intro beats.
  // the mom intro tip is a separate forced timer (see momTipT below) and is NOT gated by this.
  const introActive = state.flags && !state.flags.introDone;
  // v13 wave 7 — silence window (day 7 event). suppresses ticker + phone + ambient calls for 4 min.
  const silenceActive = state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now();
  // v13 wave 7 — spiritual HATED: mom's ambient call line stops (gates the proud-call only;
  // ambient calls overall still ring). enforced inside maybeFireMomProudCall via faction check.

  // phone calls every 90-240s
  state.phoneT = (state.phoneT||120000) - dt;
  if (state.phoneT <= 0) {
    state.phoneT = 90000 + Math.random()*150000;
    if (!introActive && !silenceActive && Math.random() < 0.8) ringPhone();
  }

  // v13 wave 3 — mom intro tip timer (~30s after game start, once per save)
  if (state.flags && !state.flags.momIntroFired) {
    state.momTipT = (state.momTipT == null ? 30000 : state.momTipT) - dt;
    if (state.momTipT <= 0) fireMomIntroTipOnce();
  }

  // continuous hustle check (cheap, only re-evaluates undone hustles)
  state.hustleCheckT = (state.hustleCheckT||0) + dt;
  if (state.hustleCheckT > 800) { state.hustleCheckT = 0; checkHustles(); }

  // v15 physical neighborhood incidents. This call sits after core player/status/day timing;
  // it cannot skip or replace the 18s high -> 8s crash transition above.
  updateIncidents(dt, introActive, silenceActive);
  updateGuidance(dt);

  // random world events — every 15-35s
  state.eventT = (state.eventT||15000) - dt;
  if (state.eventT <= 0) {
    state.eventT = 15000 + Math.random()*20000;
    if (!introActive && !silenceActive && !state.incident) fireRandomEvent();
  }

  // v13 wave 6 — interactive props: cooldown / tip-over animation tick + bottle respawn
  for (const ip of interactiveProps) {
    if (ip.type === 'trashcan') {
      if (ip.cdT > 0) ip.cdT -= dt;
      if (ip.tipT > 0) ip.tipT -= dt;
      if (ip.rotPulse > 0) ip.rotPulse -= dt;
    } else if (ip.type === 'b_bottle' && ip.broken) {
      ip.respawnT -= dt;
      if (ip.respawnT <= 0) {
        // pop a fresh one in
        ip.broken = false;
        const pool = [
          {x:140, y:300}, {x:680, y:240}, {x:1100, y:540}, {x:1740, y:520},
          {x:240, y:980}, {x:900, y:1100}, {x:1500, y:1240}, {x:1700, y:1180},
          {x:320, y:1420},{x:540, y:1700}, {x:1100, y:1640}, {x:1380, y:1700},
        ];
        const sp = pool[Math.floor(Math.random()*pool.length)];
        ip.x = sp.x + (Math.random()-.5)*40;
        ip.y = sp.y + (Math.random()-.5)*40;
      }
    }
  }
  // v13 wave 6 — dumpster cooldown tick (used to gate re-dig)
  for (const p of PROPS) {
    if (p.type === 'dumpster' && p.diveCdT > 0) {
      p.diveCdT -= dt;
      if (p.diveCdT <= 0) { p.looted = false; }
    }
  }

  // v13 wave 8b — faction territory ticker (heat in hated, greetings + bonuses in liked/loved).
  // pauses automatically when state.mode flips off 'playing' (dialogue / interior / heist / boss).
  updateTerritory(dt);
  // v13 wave 8b — edge-glow effect (zone-border crossing). decays each frame; rendered post-world.
  if (state.borderGlowT > 0) state.borderGlowT = Math.max(0, state.borderGlowT - dt);
  // detect zone-border crossings (zone change in last frame) and arm the glow.
  const curZoneId = state.territoryZoneId || null;
  if (state.lastZoneId !== curZoneId) {
    const z = currentZone();
    if (z && state.lastZoneId != null && z.id !== state.lastZoneId) {
      // tint the glow by destination faction
      const colors = { street:'#a04848', scrap:'#c08038', spiritual:'#d8c068' };
      state.borderGlowT = 600;
      state.borderGlowColor = colors[z.faction] || '#888';
      state.borderGlowRect = { x:z.x, y:z.y, w:z.w, h:z.h };
    }
    state.lastZoneId = curZoneId;
  }

  // v13 wave 6 — first-time underpass entry: echo line + feed post
  if (state.flags && !state.flags.underpassEntered && state.mode === 'playing') {
    if (inZone(P.x+P.w/2, P.y+P.h/2, 'underpass')) {
      state.flags.underpassEntered = true;
      feedPost("under the bridge. the bridge has ears.", '@crackheadcent');
      toast("the air changes.\nyou can hear yourself walk.", 3600);
      saveGame();
    }
  }

  // v13 wave 8a — first-time entry feed posts for the four new zones. once per save.
  if (state.flags && state.mode === 'playing') {
    const cx = P.x + P.w/2, cy = P.y + P.h/2;
    if (!state.flags.trainYardEntered && inZone(cx, cy, 'trainyard')) {
      state.flags.trainYardEntered = true;
      feedPost("trains stopped running here. they still come through.", '@blocklog');
      toast("the rails hum.\nthe rails are warm.\nthe rails are not used.", 4000);
      saveGame();
    } else if (!state.flags.parkEntered && inZone(cx, cy, 'park')) {
      state.flags.parkEntered = true;
      feedPost("the pigeons remember faces. the philosopher remembers names.", '@hardcandy');
      toast("you are in the park.\nthe fountain is still running.", 3600);
      saveGame();
    } else if (!state.flags.skidRowEntered && inZone(cx, cy, 'skidrow')) {
      state.flags.skidRowEntered = true;
      feedPost("skid row knows you didn't ask first.", '@crackheadcent');
      toast("the alleys are tight.\nthe air is heavier here.", 3600);
      saveGame();
    } else if (!state.flags.oldSchoolEntered && inZone(cx, cy, 'oldschool')) {
      state.flags.oldSchoolEntered = true;
      feedPost("the old school still has copper in the walls. the school still has brutus in the gym.", '@blocklog');
      toast("the old school stands.\nthe paint is gone.\nthe building is not.", 3600);
      saveGame();
    } else if (!state.flags.warehouseRowEntered && inZone(cx, cy, 'warehouse_row')) {
      state.flags.warehouseRowEntered = true;
      feedPost("warehouse row received nothing. returns accepted nothing.", '@blocklog');
      toast("two warehouses.\nthree unit numbers.\none manifest refuses all of them.", 3800);
      saveGame();
    } else if (!state.flags.canalEntered && inZone(cx, cy, 'canal')) {
      state.flags.canalEntered = true;
      feedPost("the water department marked the canal water pending.", '@crackheadcent');
      toast("the canal is dry.\nthe water gauge says nine.\ngutter greg counted the duck.", 4000);
      saveGame();
    } else if (!state.flags.theLotEntered && inZone(cx, cy, 'the_lot')) {
      state.flags.theLotEntered = true;
      feedPost("walk-ins accepted at the office. tax help unavailable.", '@hardcandy');
      toast("the lot has forty spaces.\nzero cars.\none leasing guy.", 3800);
      saveGame();
    } else if (!state.flags.blueTarpCourtEntered && inZone(cx, cy, 'blue_tarp_court')) {
      state.flags.blueTarpCourtEntered = true;
      feedPost("four tarps filed one court date. weather is named as counsel.", '@blocklog');
      toast("four tarps share one court date.\nnone brought identification.", 3800);
      saveGame();
    } else if (!state.flags.cartKeepEntered && inZone(cx, cy, 'cart_cavalry_keep')) {
      state.flags.cartKeepEntered = true;
      feedPost("the cart cavalry formed a line. one wheel attended.", '@hardcandy');
      toast("six carts form a cavalry line.\none has a wheel.", 3800);
      saveGame();
    } else if (!state.flags.copperChoirEntered && inZone(cx, cy, 'copper_choir_yard')) {
      state.flags.copperChoirEntered = true;
      feedPost("the copper choir is holding b flat until inventory closes.", '@blocklog');
      toast("the copper choir rehearses b flat.\nattendance is mandatory on paper.", 4000);
      saveGame();
    } else if (!state.flags.throneDitchEntered && inZone(cx, cy, 'throne_ditch')) {
      state.flags.throneDitchEntered = true;
      feedPost("the ditch has a chair. the chair has jurisdiction.", '@crackheadcent');
      toast("the ditch has a chair in it.\nthe chair has jurisdiction.", 4000);
      saveGame();
    }
  }

  // v13 wave 8a — park bench sit mechanic ticker.
  // sitting: +1 brain per 2s. shakes unchanged. >60s: BENCH_PRESS achievement.
  // every 30s past 60s, an ambient passer-by line may surface.
  if (state.sittingOnBench) {
    state.benchSitT = (state.benchSitT||0) + dt;
    state.benchSitGainT = (state.benchSitGainT||0) + dt;
    while (state.benchSitGainT >= 2000) {
      state.benchSitGainT -= 2000;
      P.brain = Math.min(100, P.brain + 1);
    }
    if (state.benchSitT >= 60000 && !state.achievements.has('bench_press')) {
      unlockAchievement('bench_press');
    }
    if (state.benchSitT >= 60000) {
      state.benchSitPasserT = (state.benchSitPasserT||0) + dt;
      if (state.benchSitPasserT > 30000) {
        state.benchSitPasserT = 0;
        const lines = [
          "the philosopher said you'd be here.\nshe was right.",
          "a pigeon walks past.\nit nods.\nyou nod.",
          "a jogger passes.\nshe is talking on the phone.\nshe is talking about you.",
          "the fountain coughs.\nthe fountain continues.",
          "you have been here a while.\nthe bench has been here longer.",
        ];
        toast(lines[Math.floor(Math.random()*lines.length)], 3200);
      }
    }
  }

  // v13 wave 8a — price guy daily spawn check (every 3 days, day start). gated by day % 3
  // at the call site so we don't hammer maybeSpawnPriceGuy every frame on non-spawn days.
  if (state.flags && state.mode === 'playing'
      && state.day % 3 === 0
      && state.flags.priceGuyDay !== state.day) {
    maybeSpawnPriceGuy();
  }

  // v13 wave 8a — park night cash pile. 30% chance each new night, $20-40 at the swing set.
  // gated by day-stamp so it rolls at most once per night.
  if (state.flags && state.mode === 'playing' && isNight()) {
    if (state.flags.parkNightCashDay !== state.day) {
      state.flags.parkNightCashDay = state.day;
      if (Math.random() < 0.30) {
        // v13 wave 8b — territory mult applies in spiritual liked/loved (park is spiritual)
        const baseAmt = 20 + Math.floor(Math.random() * 21);
        const amt = Math.round(baseAmt * (state.territoryCashMult || 1.0));
        runtime.cashPiles.push({
          id: 'cp_park_night_' + state.day,
          x: 2510, y: 1320, amt, collected: false,
        });
        feedPost("the swings move on their own at night. they don't.", '@crackheadcent');
      }
    }
  }

  // v13 wave 6 — public phone ring scheduler. 4-8 min between rings. answer window 30s.
  if (state.publicPhoneT == null) state.publicPhoneT = 240000 + Math.random()*240000;
  if (state.phonePropRingT > 0) {
    state.phonePropRingT -= dt;
    if (state.phonePropRingT <= 0) {
      state.phonePropRingT = 0;
      // missed
    }
  } else {
    state.publicPhoneT -= dt;
    if (state.publicPhoneT <= 0 && state.mode === 'playing' && !introActive) {
      state.publicPhoneT = 240000 + Math.random()*240000;
      state.phonePropRingT = 30000; // 30s answer window
      audio.dialogue();
      feedPost("a phone is ringing in the scrap yard.", '@local_eyewitness');
    }
  }

  // v13 wave 6 — fed dog: 200px cop-discomfort radius (cops at 0.5x speed near the chained dog).
  // Applied here so it persists for the whole game regardless of dialogue state.
  const fedDog = (state.quests.scrap_dog && state.quests.scrap_dog.state === 'fed')
    ? runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead)
    : null;
  if (fedDog) {
    for (const n of runtime.npcs) {
      if (!n.cop && n.id !== 'brendan' && n.id !== 'horsecop') continue;
      const dx = (n.x+n.w/2) - (fedDog.x+fedDog.w/2);
      const dy = (n.y+n.h/2) - (fedDog.y+fedDog.h/2);
      if (dx*dx + dy*dy < 200*200) {
        n.dogSpookSlow = 1; // flag — read in cop AI for the 0.5x mult; cleared next frame
      }
    }
  }
  // also: fed wandering follower dog has the same radius
  const followerDog = runtime.npcs.find(n => n.id === 'freed_dog_follower' && !n.dead);
  if (followerDog) {
    for (const n of runtime.npcs) {
      if (!n.cop && n.id !== 'brendan' && n.id !== 'horsecop') continue;
      const dx = (n.x+n.w/2) - (followerDog.x+followerDog.w/2);
      const dy = (n.y+n.h/2) - (followerDog.y+followerDog.h/2);
      if (dx*dx + dy*dy < 200*200) {
        n.dogSpookSlow = 1;
      }
    }
  }

  // v13 wave 6 — freed dog wandering schedule. while state==='freed', a follower can spawn
  // every 1-3 min. when present, follow window counts down ~60s before despawn.
  if (state.quests.scrap_dog && state.quests.scrap_dog.state === 'freed') {
    if (followerDog) {
      state.freedDogFollowT -= dt;
      if (state.freedDogFollowT <= 0) {
        followerDog.dead = true; // walks off
        state.freedDogT = 90000 + Math.random()*180000; // 1.5-4.5 min before next return
      }
    } else {
      state.freedDogT -= dt;
      if (state.freedDogT <= 0 && state.mode === 'playing') {
        spawnFreedDogFollower();
        state.freedDogFollowT = 60000; // ~60s follow window
      }
    }
  }

  // v13 wave 6 — tail wag + stand-up when player approaches chained dog
  const sdog = runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead && n.chained);
  if (sdog) {
    const dx = (P.x+P.w/2) - (sdog.x+sdog.w/2);
    const dy = (P.y+P.h/2) - (sdog.y+sdog.h/2);
    const near = dx*dx + dy*dy < 100*100;
    sdog.tailWag = near ? Math.min(1, (sdog.tailWag||0) + dt*0.003) : Math.max(0, (sdog.tailWag||0) - dt*0.002);
  }

  // ambient SFX scheduler
  state.ambientT = (state.ambientT||4000) - dt;
  if (state.ambientT <= 0) {
    state.ambientT = 3500 + Math.random()*4500;
    const r = Math.random();
    if (isNight()) {
      if (r < 0.5) audio.cricket();
      else if (r < 0.7) audio.dogBark();
      else if (r < 0.85) audio.cough();
      else audio.carDoor();
    } else {
      if (r < 0.4) audio.traffic();
      else if (r < 0.6) audio.dogBark();
      else if (r < 0.75) audio.cough();
      else audio.carDoor();
    }
    if (P.wanted > 0 && Math.random()<0.3) audio.copSiren();
  }

  // ambient dust motes — drift across when night or rain
  state.dustT = (state.dustT||0) - dt;
  if (state.dustT <= 0) {
    state.dustT = 280 + Math.random()*350;
    const drift = state.weather==='rain' ? 'rgba(180,200,220,.6)' : 'rgba(232,210,160,.32)';
    particles.push({
      x: state.cam.x + Math.random()*W,
      y: state.cam.y - 4 + Math.random()*H,
      vx: 0.3 + Math.random()*0.4,
      vy: -0.15 + Math.random()*0.3,
      life: 4500 + Math.random()*1500,
      c: drift,
      sz: 1 + (Math.random()<0.2 ? 1 : 0),
      glow: false,
    });
  }
  // rain droplets when raining
  if (state.weather === 'rain') {
    for (let i=0;i<3;i++) {
      particles.push({
        x: state.cam.x + Math.random()*W,
        y: state.cam.y - 8,
        vx: -1.2,
        vy: 8,
        life: 800,
        c: 'rgba(160,200,240,0.5)',
        sz: 1,
      });
    }
  }

  // combo decay
  if (state.combo > 0) {
    state.comboT -= dt;
    if (state.comboT <= 0) state.combo = 0;
  }

  // hit pause
  if (state.hitPause > 0) state.hitPause -= dt;

  // v13 wave 5 — church visit counter (debounced edge — count one per entry, not per frame).
  // gates the fallen-priest phone call trigger.
  const inChurch = inZone(P.x+P.w/2, P.y+P.h/2, 'church');
  if (inChurch && !state.inChurchPrev) {
    state.counters.churchVisits = (state.counters.churchVisits||0) + 1;
    maybeFireFallenPriestCall();
  }
  state.inChurchPrev = inChurch;

  // v13 wave 5 — OUTRAN_THE_PRIEST survival timer (60s alive vs the fallen priest)
  const fallen = runtime.npcs.find(n => n.isOmalleyFallen && !n.dead);
  if (fallen) {
    state.counters.omalleyFallenSurviveT = (state.counters.omalleyFallenSurviveT||0) + dt;
    if (state.counters.omalleyFallenSurviveT >= 60000) unlockAchievement('outran_the_priest');
  } else {
    state.counters.omalleyFallenSurviveT = 0;
  }

  // conductor wait achievement
  const conductor = runtime.npcs.find(n=>n.id==='conductor');
  if (conductor && !conductor.dead) {
    const dx = (P.x+P.w/2) - (conductor.x+conductor.w/2), dy = (P.y+P.h/2) - (conductor.y+conductor.h/2);
    if (dx*dx + dy*dy < 80*80) {
      state.conductorWaitT += dt;
      if (state.conductorWaitT >= 60000) unlockAchievement('the_conductor_knows');
    } else state.conductorWaitT = 0;
  }

  // cash piles — auto-collect when near or visible by tweaker
  for (const c of runtime.cashPiles) {
    if (c.collected) continue;
    const dx = (P.x+P.w/2) - c.x, dy = (P.y+P.h/2) - c.y;
    if (dx*dx + dy*dy < 14*14) {
      c.collected = true; state.cashPilesCollected.add(c.id);
      // v13 wave 4 — propane torch pickup (a 'cash pile' variant tagged with tool)
      if (c.tool === 'propane_torch') {
        if (!hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          audio.pickup();
          toast("+ a propane torch (dented)\n(equipped.)\nit doesn't care.", 3400);
          feedPost("picked up a torch. found it. don't ask.", '@crackheadcent');
          saveGame();
        }
        continue;
      }
      // v13 wave 5 — equip drop (the priest's collar). generic equip-id-tagged pickup.
      if (c.equip && EQUIPMENT[c.equip]) {
        const slot = EQUIPMENT[c.equip].slot;
        P.equip[slot] = c.equip;
        applyEquipStats();
        audio.coin();
        toast("+ " + EQUIPMENT[c.equip].n + "\n(equipped.)", 3400);
        saveGame();
        continue;
      }
      P.cash += c.amt; audio.pickup();
      // v13 wave 3 — intro_remember accumulator (counts only day-1 cash gains during intro)
      if (state.flags && !state.flags.introDone) {
        state.counters.introCashEarned = (state.counters.introCashEarned||0) + c.amt;
      }
      // v13 wave 7 — day 14 inheritance has its own copy + rep deltas
      if (c.isInheritance) {
        state.flags.day14Collected = true;
        toast(`+ $${c.amt}\n\nyou don't recognize the bill.\nyou don't recognize the wallet.\nyou recognize the smell.`, 4800);
        feedPost("someone came into money. someone always does.", '@hardcandy');
        applyRep({ street: 2, spiritual: -1 });
      } else {
        toast(c.intro ? `+ $${c.amt}\nyou bend down. the ten dollars is yours now.\n(it was always there.)` : `+ $${c.amt}\n(found in a corner.)`, c.intro?2400:1400);
      }
      tryCompleteIntroRemember();
      saveGame();
    }
  }

  // v13 wave 3 — intro_remember alt completion: any cash >= $10 during the intro
  // (new save starts at $0; any source that gets you to $10 closes the loop).
  if (state.flags && !state.flags.introDone && state.quests.intro_remember && !state.quests.intro_remember.done) {
    if (P.cash >= 10) {
      state.counters.introCashEarned = Math.max(state.counters.introCashEarned||0, 10);
      tryCompleteIntroRemember();
    }
  }

  // v13 wave 3 — pigeon crown world pickup. drawn in render pass.
  if (state.crownPickup && !state.crownPickup.collected) {
    const cp = state.crownPickup;
    const dx = (P.x+P.w/2) - cp.x, dy = (P.y+P.h/2) - cp.y;
    if (dx*dx + dy*dy < 18*18) {
      cp.collected = true;
      const slot = EQUIPMENT.pigeon_crown.slot;
      P.equip[slot] = 'pigeon_crown';
      applyEquipStats();
      audio.coin();
      toast("· the crown ·\nit is heavier than it looks.\nthe pigeons stop walking. they watch.\n+ EQUIPPED · the pigeon king's crown", 4500);
      if (!state.quests.pigeon_crown.done) {
        state.quests.pigeon_crown.done = true;
        questToast("THE PIGEON KING'S LOST CROWN");
        unlockAchievement('head_that_wears');
      }
      saveGame();
    }
  }

  // v13 wave 3 — stripe's package auto-delivery near the conductor (within 60px)
  if (state.flags && state.flags.hasStripePackage && state.mode === 'playing') {
    const cn = runtime.npcs.find(n=>n.id==='conductor');
    if (cn && !cn.dead) {
      const dx2 = (P.x+P.w/2)-(cn.x+cn.w/2);
      const dy2 = (P.y+P.h/2)-(cn.y+cn.h/2);
      if (dx2*dx2+dy2*dy2 < 60*60) {
        state.flags.hasStripePackage = false;
        P.inventory = P.inventory.filter(i => i.id !== 'stripe_package');
        if (state.quests.stripe_package && !state.quests.stripe_package.done) {
          state.quests.stripe_package.done = true;
          P.cash += 40; P.cred += 3;
          questToast("STRIPE'S PACKAGE");
          unlockAchievement('exact_change');
        }
        audio.coin();
        dialogue('THE CONDUCTOR',
          "the conductor unfolds the package without looking at it.\n'stripe's name. stripe's money.\nyou are stripe's leg.\nit is monday.'", [
            { label: '+$40 · +3 cred · leave.', action: () => {} },
          ]);
        saveGame();
      }
    }
  }

  // hide pawn at night
  const pete = runtime.npcs.find(n=>n.id==='pete');
  if (pete) pete.shopClosed = isNight();

  updateNpcActors(dt);

  // particles
  for (let i=particles.length-1;i>=0;i--) {
    const p = particles[i];
    p.life -= dt;
    p.x += p.vx; p.y += p.vy;
    p.vx *= 0.92; p.vy *= 0.92;
    if (p.gravity) p.vy += p.gravity;
    if (p.life <= 0) particles.splice(i,1);
  }
  // particle pool cap
  if (particles.length > 220) particles.splice(0, particles.length - 220);

  // v13 wave 5 — projectile update (bottles + holy water vials).
  // generic primitive: kind drives only visuals + impact-side-effects, motion + collision are shared.
  for (let i=runtime.projectiles.length-1; i>=0; i--) {
    const pr = runtime.projectiles[i];
    pr.life -= dt;
    pr.x += pr.vx * (dt/1000);
    pr.y += pr.vy * (dt/1000);
    pr.rot += pr.rotVel;
    let dead = false;
    // wall (solid building) collision
    for (const b of BUILDINGS) {
      if (!b.solid) continue;
      if (pr.x > b.x && pr.x < b.x+b.w && pr.y > b.y && pr.y < b.y+b.h) { dead = true; break; }
    }
    // world edge
    if (!dead && (pr.x < 0 || pr.x > WORLD.w || pr.y < 0 || pr.y > WORLD.h)) dead = true;
    // player hit
    if (!dead && rectsOverlap({x:pr.x-4, y:pr.y-4, w:8, h:8}, P)) {
      damagePlayer(pr.dmg, pr.from);
      if (pr.slowMs > 0) P.slowT = Math.max(P.slowT||0, pr.slowMs);
      if (pr.kind === 'bottle') {
        audio.bottleHit();
        for (let j=0;j<10;j++) particles.push({x:pr.x,y:pr.y,vx:(Math.random()-.5)*5,vy:(Math.random()-.5)*5,life:380,c:'#a07020',sz:2});
      } else if (pr.kind === 'holy') {
        audio.holyWaterHit();
        for (let j=0;j<12;j++) particles.push({x:pr.x,y:pr.y,vx:(Math.random()-.5)*4,vy:(Math.random()-.5)*4,life:500,c:'#a0d0ff',sz:3,glow:true});
      }
      dead = true;
    }
    if (!dead && pr.life <= 0) {
      // expired mid-air — small fizzle, no damage
      if (pr.kind === 'bottle') audio.bottleHit();
      dead = true;
    }
    if (dead) runtime.projectiles.splice(i,1);
  }
  // projectile pool cap (paranoia)
  if (runtime.projectiles.length > 40) runtime.projectiles.splice(0, runtime.projectiles.length - 40);

  // boss phase transitions — v13 wave 5: phases now shift the ATTACK PATTERN, not just numbers.
  // tony (rank-4 boss):
  //   p1 (100-66%): standard chase-bite (default archetype).
  //   p2 (66-33%): converts to CHARGER + spawns 2 sherri adds ("he whistles. someone answers.").
  //   p3 (33-0%): BERSERK charger (windup 400ms, lunge ×3 speed, no breathing room).
  // existing coat-tearing flavor is preserved on each phase entry.
  if (state.bossKind === 'tony' && state.bossActive && state.bossNPC && !state.bossNPC.dead) {
    const b = state.bossNPC;
    const pct = b.hp / b.maxHp;
    let newPhase = state.bossPhase;
    if (pct < 0.66 && state.bossPhase < 2) newPhase = 2;
    if (pct < 0.33 && state.bossPhase < 3) newPhase = 3;
    if (newPhase !== state.bossPhase) {
      state.bossPhase = newPhase;
      b.coatsOff = newPhase;
      if (newPhase === 2) {
        b.archetype = 'charger';
        b.chargeState = 'idle'; b.chargeT = 0; b.chargeCdT = 0;
        b.speed = 2.4;
        toast("tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers.", 3200);
        // spawn 2 sherri adds 80px to either side
        const sherri1 = {
          id: 'sherri_boss_'+Math.random().toString(36).slice(2,6),
          name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
          x: b.x - 80, y: b.y, w: 26, h: 30, color: '#3a1820',
          hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
          aggroOnHit: true, dmg: 5, archetype: 'swarmer', attackCd: 0, showHp: false,
        };
        const sherri2 = { ...sherri1, id: 'sherri_boss_'+Math.random().toString(36).slice(2,6), x: b.x + 80 };
        runtime.npcs.push(sherri1, sherri2);
        broadcastNews("BREAKING: TRE BAG TONY DOWN TO 2 COATS. SOMETHING ELSE IS COMING.");
        feedPost("tony is on coat 2. and somebody else just showed up.", '@the_corner');
      } else if (newPhase === 3) {
        b.archetype = 'charger';
        b.berserk = true;
        b.chargeState = 'idle'; b.chargeT = 0; b.chargeCdT = 0;
        b.speed = 3.0; b.dmg = 16;
        toast("tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up.", 3500);
        // bossRoar loops higher pitch — fake it with a 3-shot quick stack
        audio.bossRoar(); setTimeout(()=>audio.bossRoar(), 200); setTimeout(()=>audio.bossRoar(), 420);
        broadcastNews("BREAKING: TRE BAG TONY BARE-KNUCKLE. CALL TIME OF DEATH ALREADY.");
        feedPost("tony has no coats. tony is lunging now. like a dog.", '@the_corner');
      }
      audio.bossRoar();
      state.shake = 12;
      const coatColors = {2: '#4a2018', 3: '#2a1010'};
      const cc = coatColors[newPhase] || '#5a2020';
      for (let i=0;i<24;i++) {
        particles.push({
          x: b.x+b.w/2, y: b.y+b.h/2,
          vx: (Math.random()-.5)*10, vy: (Math.random()-.7)*8,
          life: 1400, c: cc, sz: 5, gravity: 0.25,
        });
      }
    }
  }

  // v13 wave 5 — Brutus Older phase machine (parallel to boss tony).
  //   p1 (100-50%): charger from the start (already archetype='charger_older').
  //   p2 (50-25%): charger + spawns 1 sherri swarm pair every 8s.
  //   p3 (25-0%): berserk charger + grabber-on-contact (HE STARTS GRABBING).
  if (state.brutusOlderActive && state.brutusOlderNPC && !state.brutusOlderNPC.dead) {
    const bo = state.brutusOlderNPC;
    const pct = bo.hp / bo.maxHp;
    state.brutusOlderPhase = state.brutusOlderPhase || 1;
    let newP = state.brutusOlderPhase;
    if (pct < 0.5 && state.brutusOlderPhase < 2) newP = 2;
    if (pct < 0.25 && state.brutusOlderPhase < 3) newP = 3;
    if (newP !== state.brutusOlderPhase) {
      state.brutusOlderPhase = newP;
      audio.bossRoar();
      state.shake = 12;
      for (let i=0;i<20;i++) particles.push({x:bo.x+bo.w/2,y:bo.y+bo.h/2,vx:(Math.random()-.5)*8,vy:(Math.random()-.7)*6,life:1200,c:'#8a3030',sz:5,gravity:0.2});
      if (newP === 2) {
        bo.addsT = 0;
        toast("he was warming up before.", 3000);
      } else if (newP === 3) {
        bo.berserk = true;
        bo.grabber = true;
        bo.chargeState = 'idle';
        toast("he doesn't bite anymore.\nhe grabs.", 3200);
      }
    }
    // phase 2 adds — spawn a sherri swarm pair every 8s
    if (state.brutusOlderPhase >= 2) {
      bo.addsT = (bo.addsT||0) + dt;
      if (bo.addsT >= 8000) {
        bo.addsT = 0;
        const liveSwarm = runtime.npcs.filter(n => n.archetype === 'swarmer' && !n.dead);
        if (liveSwarm.length < 2) {
          const a = {
            id: 'sherri_brutus_'+Math.random().toString(36).slice(2,6),
            name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
            x: bo.x - 60, y: bo.y + 20, w: 26, h: 30, color: '#3a1820',
            hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
            aggroOnHit: true, dmg: 5, archetype: 'swarmer', attackCd: 0, showHp: false,
          };
          runtime.npcs.push(a);
        }
      }
    }
    // phase 3 grabber-on-contact: apply stun on contact during cooldown (post-lunge)
    if (state.brutusOlderPhase >= 3 && bo.chargeLanded) {
      bo.chargeLanded = false; // consume
      P.stunT = Math.max(P.stunT||0, 500);
    }
  }

  // rank progression
  while (P.rank < RANKS.length-1 && P.cred >= RANKS[P.rank+1].cred) {
    P.rank++;
    audio.rankUp();
    toast('· RANK UP ·\n' + RANKS[P.rank].name.toUpperCase(), 3000);
    feedPost('promoted to ' + RANKS[P.rank].name + '. the corner watches.', '@the_corner');
    broadcastNews(RANKS[P.rank].name.toUpperCase() + ' has been promoted. the streets react with mild interest.');
    if (P.rank >= 5) unlockAchievement('glass_mayor');
    saveGame();
  }
  if (P.rank >= 4) {
    const ab = BUILDINGS.find(b=>b.locked);
    if (ab) ab.locked = false; // unlocked
  }

  // camera
  state.cam.x = clamp(P.x + P.w/2 - W/2, 0, WORLD.w - W);
  state.cam.y = clamp(P.y + P.h/2 - H/2, 0, WORLD.h - H);

  // shake
  if (state.shake > 0) state.shake *= 0.9;
  if (state.flash > 0) state.flash -= dt/1000;
  if (state.flash < 0) state.flash = 0;

  // auto-save every 45s
  state.autoSaveT = (state.autoSaveT||0) + dt;
  if (state.autoSaveT > 45000) { state.autoSaveT = 0; saveGame(); }

  // interact / smoke at block
  // handled via keypress handler

  // update HUD
  updateHUD();
}

export function applyDayNight() {
  const t = state.dayTime;
  const dnEl = document.getElementById('daynight');
  // canvas drawLighting handles the heavy darkening at night.
  // CSS overlay does only the subtle warm/cool tinting.
  let r=0,g=0,b=0,a=0;
  if (t < 0.2) { r=40;g=50;b=100; a = 0.18; }
  else if (t < 0.3) { const k = (t-0.2)/0.1; r=120+k*100; g=80+k*60; b=80-k*40; a = 0.15 - k*0.1; }
  else if (t < 0.7) { r=255;g=240;b=180; a = 0.05; }
  else if (t < 0.8) { const k = (t-0.7)/0.1; r=240-k*80;g=140-k*60;b=80; a = 0.05 + k*0.13; }
  else { r=40;g=50;b=100; a = 0.18; }
  dnEl.style.background = `rgba(${r|0},${g|0},${b|0},${a.toFixed(3)})`;
  const tEl = document.getElementById('timeOfDay');
  const phase = t<0.2?'night':t<0.3?'dawn':t<0.7?'day':t<0.8?'dusk':'night';
  tEl.textContent = `day ${state.day} · ${phase} · ${state.weather}`;
}

export function init_update() {
  // ---------- UPDATE ----------
  last = 0;
  
  
  
  
  
  
  
}

export function updateHUD() {
  const hearts = Math.max(0, Math.ceil(P.hp/20));
  document.getElementById('hp').textContent = '♥'.repeat(hearts) + '♡'.repeat(5-hearts);
  document.getElementById('cash').textContent = P.cash;
  // v13 wave 4 — soap rocks look like real rocks in the HUD count. truth is in the smoke.
  document.getElementById('rocks').textContent = (P.rocks||0) + (P.soapRocks||0);
  document.getElementById('copper').textContent = P.copper;
  document.getElementById('supplies').textContent = P.supplies || 0;
  document.getElementById('shakeBar').style.width = P.shakes + '%';
  document.getElementById('brainBar').style.width = P.brain + '%';
  const filed=(P.lifetime&&P.lifetime.routesCompleted)||0;
  document.getElementById('rankName').textContent = RANKS[P.rank].name + (P.rank>=RANKS.length-1?' · term '+(1+Math.floor(filed/5)):'');
  document.getElementById('cred').textContent = P.cred;
  document.getElementById('wanted').textContent = '★'.repeat(P.wanted);
  // hustle micro-indicator in time-of-day line
  const h = state.hustles || [];
  const hdone = h.filter(x=>x.done).length;
  const ht = state.dayTime;
  const phase = ht<0.2?'night':ht<0.3?'dawn':ht<0.7?'day':ht<0.8?'dusk':'night';
  const tEl = document.getElementById('timeOfDay');
  if (tEl) tEl.textContent = `day ${state.day} · ${phase} · ${state.weather} · 🏷 ${hdone}/${h.length}`;
}

export function init_hud() {
  // ---------- HUD ----------
  
  
  
}

export let cv, ctx, ENV_SPRITE_CACHE;

export function visibleWorldRect(x, y, w=1, h=1, pad=72) {
  return x+w >= state.cam.x-pad && x <= state.cam.x+W+pad &&
         y+h >= state.cam.y-pad && y <= state.cam.y+H+pad;
}

export function drawRoadSegment(r) {
  if (!visibleWorldRect(r.x, r.y, r.w, r.h, 24)) return;
  const service = r.kind === 'service';
  const arterial = r.kind === 'arterial';
  const curb = service ? '#494438' : '#5a5548';
  const walk = service ? '#343129' : '#454137';
  const road = service ? '#181714' : arterial ? '#1b1a17' : '#1d1c18';
  ctx.fillStyle = walk;
  ctx.fillRect(r.x, r.y, r.w, r.h);
  ctx.fillStyle = curb;
  if (r.axis === 'h') {
    ctx.fillRect(r.x, r.y+7, r.w, 4);
    ctx.fillRect(r.x, r.y+r.h-11, r.w, 4);
    ctx.fillStyle = road;
    ctx.fillRect(r.x, r.y+11, r.w, r.h-22);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(r.x, r.y+8, r.w, 1);
    ctx.fillRect(r.x, r.y+r.h-9, r.w, 1);
    if (!service) {
      const start = Math.max(r.x+18, Math.floor((state.cam.x-48-r.x)/44)*44+r.x+18);
      const end = Math.min(r.x+r.w, state.cam.x+W+48);
      ctx.fillStyle = arterial ? 'rgba(232,192,64,.34)' : 'rgba(212,200,150,.27)';
      for (let x=start; x<end; x+=44) ctx.fillRect(x, r.y+r.h/2-1, 22, 2);
    }
    const patchStart=Math.max(r.x+64,Math.floor((state.cam.x-r.x)/196)*196+r.x+64);
    for(let x=patchStart;x<Math.min(r.x+r.w,state.cam.x+W+80);x+=196){
      const wobble=((x*17+r.y*7)>>>0)%18;
      ctx.fillStyle='rgba(7,6,5,.24)';ctx.fillRect(x,r.y+22+wobble,42,16);
      ctx.strokeStyle='rgba(112,92,60,.16)';ctx.strokeRect(x+.5,r.y+22.5+wobble,41,15);
    }
    ctx.strokeStyle = 'rgba(20,16,10,.32)';
    ctx.lineWidth = 1;
    const seamStart = Math.max(r.x, Math.floor((state.cam.x-r.x)/48)*48+r.x);
    for (let x=seamStart; x<Math.min(r.x+r.w,state.cam.x+W+48); x+=48) {
      ctx.beginPath(); ctx.moveTo(x,r.y); ctx.lineTo(x,r.y+7); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x,r.y+r.h-7); ctx.lineTo(x,r.y+r.h); ctx.stroke();
    }
  } else {
    ctx.fillRect(r.x+7, r.y, 4, r.h);
    ctx.fillRect(r.x+r.w-11, r.y, 4, r.h);
    ctx.fillStyle = road;
    ctx.fillRect(r.x+11, r.y, r.w-22, r.h);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(r.x+8, r.y, 1, r.h);
    ctx.fillRect(r.x+r.w-9, r.y, 1, r.h);
    if (!service) {
      const start = Math.max(r.y+18, Math.floor((state.cam.y-48-r.y)/44)*44+r.y+18);
      const end = Math.min(r.y+r.h, state.cam.y+H+48);
      ctx.fillStyle = arterial ? 'rgba(232,192,64,.34)' : 'rgba(212,200,150,.27)';
      for (let y=start; y<end; y+=44) ctx.fillRect(r.x+r.w/2-1, y, 2, 22);
    }
    const patchStart=Math.max(r.y+64,Math.floor((state.cam.y-r.y)/196)*196+r.y+64);
    for(let y=patchStart;y<Math.min(r.y+r.h,state.cam.y+H+80);y+=196){
      const wobble=((y*13+r.x*11)>>>0)%18;
      ctx.fillStyle='rgba(7,6,5,.24)';ctx.fillRect(r.x+22+wobble,y,16,42);
      ctx.strokeStyle='rgba(112,92,60,.16)';ctx.strokeRect(r.x+22.5+wobble,y+.5,15,41);
    }
    ctx.strokeStyle = 'rgba(20,16,10,.32)';
    ctx.lineWidth = 1;
    const seamStart = Math.max(r.y, Math.floor((state.cam.y-r.y)/48)*48+r.y);
    for (let y=seamStart; y<Math.min(r.y+r.h,state.cam.y+H+48); y+=48) {
      ctx.beginPath(); ctx.moveTo(r.x,y); ctx.lineTo(r.x+7,y); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(r.x+r.w-7,y); ctx.lineTo(r.x+r.w,y); ctx.stroke();
    }
  }
}

export function drawCrosswalk(c) {
  if (!visibleWorldRect(c.x-20,c.y-20,80,80,8)) return;
  ctx.fillStyle = 'rgba(212,200,150,.31)';
  if (c.axis === 'h') {
    for (let i=0;i<5;i++) ctx.fillRect(c.x+i*9, c.y+16, 5, 38);
  } else {
    for (let i=0;i<5;i++) ctx.fillRect(c.x+16, c.y+i*9, 38, 5);
  }
}

export function drawGroundPaths() {
  for (const p of GROUND_PATHS) {
    if (!visibleWorldRect(p.x,p.y,p.w,p.h,p.width)) continue;
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(20,16,10,.32)'; ctx.lineWidth = p.width+5;
    ctx.beginPath(); ctx.moveTo(p.points[0][0],p.points[0][1]);
    for (let i=1;i<p.points.length;i++) ctx.lineTo(p.points[i][0],p.points[i][1]);
    ctx.stroke();
    ctx.strokeStyle = p.color; ctx.lineWidth = p.width;
    ctx.stroke();
    ctx.strokeStyle = 'rgba(212,200,150,.08)'; ctx.lineWidth = 2;
    ctx.stroke();
    ctx.lineCap = 'butt'; ctx.lineJoin = 'miter';
  }
}

export function drawRailLines() {
  for (const r of RAIL_LINES) {
    const minX=Math.min(r.x1,r.x2), maxX=Math.max(r.x1,r.x2);
    const minY=Math.min(r.y1,r.y2)-14, maxY=Math.max(r.y1,r.y2)+14;
    if (!visibleWorldRect(minX,minY,maxX-minX,maxY-minY,24)) continue;
    const start = Math.max(minX, Math.floor((state.cam.x-30-minX)/18)*18+minX);
    const end = Math.min(maxX, state.cam.x+W+30);
    ctx.fillStyle = '#44321f';
    for (let x=start;x<end;x+=18) ctx.fillRect(x,r.y1-13,6,26);
    ctx.fillStyle = '#676259';
    ctx.fillRect(minX,r.y1-9,maxX-minX,3);
    ctx.fillRect(minX,r.y1+7,maxX-minX,3);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(minX,r.y1-9,maxX-minX,1);
    ctx.fillRect(minX,r.y1+7,maxX-minX,1);
  }
}

export function drawDistrictGroundMarks() {
  // the block: a court that gave up at the free-throw line.
  if (visibleWorldRect(900,740,300,210,16)) {
    ctx.strokeStyle='rgba(212,200,150,.17)'; ctx.lineWidth=3;
    ctx.strokeRect(914,760,270,170);
    ctx.beginPath(); ctx.arc(1050,845,54,Math.PI*.1,Math.PI*.9); ctx.stroke();
    ctx.strokeRect(1018,760,64,56);
  }
  // projects: painted key and a number that was never finished.
  if (visibleWorldRect(100,1700,600,180,16)) {
    ctx.strokeStyle='rgba(160,160,184,.15)'; ctx.lineWidth=3;
    ctx.strokeRect(118,1714,210,145);
    ctx.beginPath(); ctx.arc(328,1786,42,-Math.PI/2,Math.PI/2); ctx.stroke();
    ctx.fillStyle='rgba(212,200,150,.14)'; ctx.font='bold 24px Courier New'; ctx.fillText('4',350,1750);
  }
  // bus stop curb ledger.
  if (visibleWorldRect(1240,1080,220,180,20)) {
    ctx.save(); ctx.translate(1260,1246); ctx.rotate(-.04);
    ctx.fillStyle='rgba(232,192,64,.28)'; ctx.font='bold 13px Courier New';
    ctx.fillText('ROUTE 0 · STILL DUE',0,0); ctx.restore();
  }
  // old school court — regulation was not consulted.
  if (visibleWorldRect(3400,280,760,640,16)) {
    ctx.strokeStyle='rgba(212,200,150,.14)'; ctx.lineWidth=3;
    ctx.strokeRect(3435,740,610,130);
    ctx.beginPath(); ctx.arc(3740,805,52,0,Math.PI*2); ctx.stroke();
    ctx.strokeRect(3435,775,62,60); ctx.strokeRect(3983,775,62,60);
  }
  // v18 warehouse loading apron. Unit numbers disagree with the building signs.
  if (visibleWorldRect(4400,180,1100,760,24)) {
    ctx.strokeStyle='rgba(212,200,150,.18)';ctx.lineWidth=3;
    for(let i=0;i<8;i++){
      const x=4430+i*135;ctx.beginPath();ctx.moveTo(x,730);ctx.lineTo(x,930);ctx.stroke();
      ctx.fillStyle='rgba(212,200,150,.15)';ctx.font='bold 18px Courier New';ctx.fillText(String((i+11)%14),x+18,910);
    }
    ctx.fillStyle='rgba(192,128,56,.18)';ctx.fillRect(4872,710,104,10);
  }
  // v18 canal. The dark center is shallow municipal water and remains walkable.
  if (visibleWorldRect(4300,1540,1350,680,28)) {
    ctx.fillStyle='rgba(20,32,30,.55)';ctx.fillRect(4315,1810,1320,150);
    ctx.fillStyle='rgba(78,105,94,.22)';ctx.fillRect(4315,1870,1320,28);
    ctx.strokeStyle='rgba(150,164,148,.22)';ctx.lineWidth=4;
    ctx.beginPath();ctx.moveTo(4315,1680);ctx.lineTo(5635,1810);ctx.stroke();
    ctx.beginPath();ctx.moveTo(4315,2090);ctx.lineTo(5635,1960);ctx.stroke();
    ctx.font='bold 12px Courier New';ctx.fillStyle='rgba(212,200,150,.18)';
    for(let x=4380;x<5600;x+=160)ctx.fillText(String(9-Math.floor((x-4380)/160)),x,2000);
  }
  // v18 office lot. Every parking space is reserved for a car that is not present.
  if (visibleWorldRect(4300,2700,1250,850,24)) {
    ctx.strokeStyle='rgba(232,192,64,.16)';ctx.lineWidth=3;
    for(let row=0;row<2;row++)for(let i=0;i<8;i++){
      const x=4340+i*145,y=2760+row*610;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+42,y+130);ctx.stroke();
    }
    ctx.fillStyle='rgba(232,192,64,.13)';ctx.font='bold 22px Courier New';ctx.fillText('CUSTOMER',4330,3320);ctx.fillText('NO',4550,3320);
  }
  // v19 blue court: a regulation court copied onto tarp weather.
  if(visibleWorldRect(6200,620,600,300,20)){
    ctx.strokeStyle='rgba(120,144,160,.24)';ctx.lineWidth=3;ctx.strokeRect(6200,620,600,300);
    ctx.beginPath();ctx.moveTo(6500,620);ctx.lineTo(6500,920);ctx.arc(6500,770,64,0,Math.PI*2);ctx.stroke();
  }
  // cart keep: a corral whose parking spaces all face each other.
  if(visibleWorldRect(7480,1810,760,520,20)){
    ctx.strokeStyle='rgba(212,200,150,.20)';ctx.lineWidth=3;ctx.strokeRect(7480,1810,760,520);
    for(let x=7560;x<8220;x+=110){ctx.beginPath();ctx.moveTo(x,1810);ctx.lineTo(x-40,1940);ctx.stroke();}
  }
  // copper choir: inventory bays double as pews.
  if(visibleWorldRect(6060,3180,900,590,20)){
    ctx.strokeStyle='rgba(208,96,48,.20)';ctx.lineWidth=3;ctx.strokeRect(6060,3180,900,590);
    for(let x=6210;x<6960;x+=150){ctx.beginPath();ctx.moveTo(x,3180);ctx.lineTo(x,3770);ctx.stroke();}
  }
  // throne ditch: an outer appeal and an inner appeal. Both are lower than the chair.
  if(visibleWorldRect(7320,4580,880,620,20)){
    ctx.strokeStyle='rgba(212,200,150,.18)';ctx.lineWidth=4;ctx.strokeRect(7320,4580,880,620);ctx.strokeRect(7400,4680,720,420);
  }
}

export function drawWorldWireShadows() {
  ctx.strokeStyle='rgba(0,0,0,.24)'; ctx.lineWidth=2;
  for (const w of UTILITY_WIRES) {
    const minX=Math.min(w[0],w[2]), minY=Math.min(w[1],w[3]);
    if (!visibleWorldRect(minX,minY,Math.abs(w[2]-w[0]),Math.abs(w[3]-w[1]),80)) continue;
    const mx=(w[0]+w[2])/2+24, my=(w[1]+w[3])/2+18;
    ctx.beginPath(); ctx.moveTo(w[0]+22,w[1]+30); ctx.quadraticCurveTo(mx,my,w[2]+22,w[3]+30); ctx.stroke();
  }
}

export function drawWorldFabric() {
  for (const r of ROAD_SEGMENTS) drawRoadSegment(r);
  for (const c of CROSSWALKS) drawCrosswalk(c);
  drawGroundPaths();
  drawRailLines();
  drawDistrictGroundMarks();
  drawWorldWireShadows();
}

export function buildEnvironmentSprites() {
  const make = (rows,pal) => rasterize(parseGrid(rows), pal);
  ENV_SPRITE_CACHE.storm_drain = make([
    '................','................','................','................',
    '................','................','................','................',
    '..111111111111..','..122222222221..','..121212121221..','..122222222221..',
    '..111111111111..','................','................','................',
  ], {1:'#25231f',2:'#706858'});
  ENV_SPRITE_CACHE.news_box = make([
    '................','.....11111......','....1222221.....','....1222221.....',
    '....1333331.....','....1333331.....','....1333331.....','....1222221.....',
    '....1222221.....','....1222221.....','....1111111.....','.....11111......',
    '......11........','......11........','.....1111.......','................',
  ], {1:'#221d18',2:'#8a3a3a',3:'#d4c896'});
  ENV_SPRITE_CACHE.road_barrier = make([
    '................','................','................','................',
    '................','..111111111111..','..122112211221..','..211221122112..',
    '..111111111111..','....11......11..','....11......11..','....11......11..',
    '...1111....1111.','................','................','................',
  ], {1:'#3a3020',2:'#d06030'});
  // v18 district claim sign. One cached 16x16 logical sprite serves every owned district.
  ENV_SPRITE_CACHE.claim_sign = make([
    '................','..111111111111..','..122222222221..','..123333333321..',
    '..123232323321..','..123333333321..','..122222222221..','..111111111111..',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ], {1:'#2a1f10',2:'#d4c896',3:'#8a3a3a'});
  const bannerRows=[
    '.......11.......','.......11.......','..111111111111..','..122222222221..',
    '..123333333321..','..123232323321..','..123333333321..','..122222222221..',
    '..111111111111..','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ];
  ENV_SPRITE_CACHE.clan_banner_blue=make(bannerRows,{1:'#111418',2:'#34485a',3:'#e8c040'});
  ENV_SPRITE_CACHE.clan_banner_receipt=make(bannerRows,{1:'#17130d',2:'#d4c896',3:'#8a3a3a'});
  ENV_SPRITE_CACHE.clan_banner_wire=make(bannerRows,{1:'#100b08',2:'#8a5b3a',3:'#d06030'});
  ENV_SPRITE_CACHE.clan_banner_curb=make(bannerRows,{1:'#0a0805',2:'#5a5548',3:'#e8c040'});
  ENV_SPRITE_CACHE.rail_signal = make([
    '.......11.......','......1221......','......1331......','......1221......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.....111111.....','.....111111.....','................',
  ], {1:'#302a24',2:'#8a3a3a',3:'#e8c040'});
  ENV_SPRITE_CACHE.utility_top = make([
    '.......11.......','.......11.......','..111111111111..','..1....11....1..',
    '..1....11....1..','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
  ], {1:'#4a3723'});
  ENV_SPRITE_CACHE.utility_base = make([
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ], {1:'#4a3723'});
}

export function init_canvas_geography() {
  // ---------- RENDER ----------
  cv = document.getElementById('game');
  ctx = cv.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  
  
  
  // ----- v14 connective geography -----
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  // ----- v14 cached environment sprites -----
  ENV_SPRITE_CACHE = {};
  
  
  
}

export let LANDMARK_CACHE, landmarkCacheReady, LIGHT_MASK, LIGHT_CTX, LIGHT_HOLE, LIGHT_GLOW_CACHE, FOG_SHEET;

export function buildLandmarkFacades() {
  for (const f of LANDMARK_FACADES) {
    const pad=16, c=document.createElement('canvas');
    c.width=f.w+pad*2; c.height=f.h+pad*2;
    const g=c.getContext('2d'); g.imageSmoothingEnabled=false;
    const x=pad, y=pad;
    g.fillStyle='rgba(0,0,0,.42)'; g.fillRect(x+7,y+f.h,f.w-4,7);
    const wall = f.kind==='warehouse' ? '#342f27' : f.kind==='industrial' ? '#30251f' : f.kind==='rowhouse' ? '#3b2a22' : '#3a3026';
    const edge = f.kind==='industrial' ? '#160d09' : '#1a1510';
    g.fillStyle=wall; g.fillRect(x,y,f.w,f.h);
    g.strokeStyle=edge; g.lineWidth=3; g.strokeRect(x+1,y+1,f.w-2,f.h-2);
    if (f.kind==='warehouse' || f.kind==='industrial') {
      g.strokeStyle='rgba(212,200,150,.07)'; g.lineWidth=1;
      for(let bx=8;bx<f.w;bx+=10){g.beginPath();g.moveTo(x+bx,y+2);g.lineTo(x+bx,y+f.h-2);g.stroke();}
      const bays=Math.max(1,Math.floor(f.w/170));
      for(let i=0;i<bays;i++){
        const bw=Math.min(96,(f.w-30)/bays), bx=x+18+i*(f.w/bays);
        g.fillStyle='#171512'; g.fillRect(bx,y+f.h-58,bw,56);
        g.strokeStyle='#5c5548'; g.strokeRect(bx+.5,y+f.h-57.5,bw-1,55);
        g.fillStyle='rgba(212,200,150,.08)';
        for(let sy=y+f.h-50;sy<y+f.h-5;sy+=9) g.fillRect(bx+2,sy,bw-4,1);
      }
      if (f.kind==='industrial') {
        g.fillStyle='#241a14';
        for(let i=0;i<3;i++){g.fillRect(x+f.w-48+i*12,y-12-i*5,7,20+i*5);}
      }
    } else if (f.kind==='rowhouse') {
      const bays=Math.max(2,Math.floor(f.w/58));
      for(let i=0;i<bays;i++){
        const bx=x+8+i*(f.w/bays), bw=f.w/bays-12;
        g.fillStyle='#12100e'; g.fillRect(bx,y+18,bw,18);
        g.fillStyle=(i%3===0)?'#8a6a32':'#655632'; g.fillRect(bx+2,y+20,bw-4,14);
        g.fillStyle='#17120f'; g.fillRect(bx+bw/2-7,y+f.h-30,14,28);
        g.fillStyle='#5b4634'; g.fillRect(bx+bw/2-12,y+f.h-3,24,3);
        g.fillRect(bx+bw/2-9,y+f.h,18,3);
      }
      g.strokeStyle='rgba(12,10,8,.75)';
      for(let fy=48;fy<f.h-40;fy+=34){g.beginPath();g.moveTo(x+6,y+fy);g.lineTo(x+f.w-6,y+fy);g.stroke();}
    } else {
      g.fillStyle='#13110e'; g.fillRect(x+10,y+36,f.w-20,Math.max(30,f.h-48));
      const cols=Math.max(2,Math.floor((f.w-20)/46));
      for(let i=0;i<cols;i++){
        const bx=x+16+i*((f.w-32)/cols);
        g.fillStyle=(i&1)?'#33281f':'#4c3928'; g.fillRect(bx,y+42,28,Math.max(20,f.h-60));
        g.fillStyle='rgba(212,200,150,.12)'; g.fillRect(bx+3,y+45,22,2);
      }
      for(let i=0;i<Math.floor(f.w/18);i++){
        g.fillStyle=(i&1)?'#6b2f26':'#b79a56'; g.fillRect(x+5+i*18,y+25,18,11);
      }
    }
    const label=f.sign||'';
    const fs=Math.max(8,Math.min(12,Math.floor((f.w-18)/Math.max(1,label.length)*1.7)));
    g.font=`bold ${fs}px Courier New`; g.textAlign='center';
    const tw=Math.min(f.w-18,g.measureText(label).width+14);
    g.fillStyle='#12100d'; g.fillRect(x+(f.w-tw)/2,y+7,tw,16);
    g.fillStyle='#c8b56f'; g.fillText(label,x+f.w/2,y+19);
    g.textAlign='left';
    LANDMARK_CACHE[f.id]={canvas:c,dx:-pad,dy:-pad};
  }
  landmarkCacheReady = true;
}

export function drawLandmarkFacades() {
  if (!landmarkCacheReady) buildLandmarkFacades();
  for (const f of LANDMARK_FACADES) {
    if (!visibleWorldRect(f.x,f.y,f.w,f.h,32)) continue;
    const cached=LANDMARK_CACHE[f.id];
    if (cached) ctx.drawImage(cached.canvas,f.x+cached.dx,f.y+cached.dy);
  }
}

export function decorBounds(p) {
  if (p.type==='utility_pole') return {x:p.x-18,y:p.y-64,w:36,h:68};
  if (p.type==='clothesline') return {x:Math.min(p.x,p.x2),y:Math.min(p.y,p.y2)-30,w:Math.abs(p.x2-p.x)+1,h:Math.abs(p.y2-p.y)+50};
  return {x:p.x-18,y:p.y-(p.h||24),w:(p.w||36)+18,h:(p.h||36)+24};
}

export function drawWorldDecor(layer) {
  for (const p of WORLD_DECOR) {
    if ((p.layer||'low')!==layer) continue;
    const b=decorBounds(p); if(!visibleWorldRect(b.x,b.y,b.w,b.h,40)) continue;
    if (p.type==='storm_drain'||p.type==='news_box'||p.type==='road_barrier'||p.type==='rail_signal') {
      const sp=ENV_SPRITE_CACHE[p.type]; if(sp) ctx.drawImage(sp,p.x-16,p.y-16,32,32);
    } else if (p.type==='utility_pole') {
      ctx.drawImage(ENV_SPRITE_CACHE.utility_top,p.x-16,p.y-64,32,32);
      ctx.drawImage(ENV_SPRITE_CACHE.utility_base,p.x-16,p.y-32,32,32);
    } else if (p.type==='bus_shelter') {
      ctx.fillStyle='rgba(0,0,0,.34)'; ctx.fillRect(p.x+4,p.y+p.h,p.w-8,5);
      ctx.fillStyle='rgba(92,104,100,.28)'; ctx.fillRect(p.x+5,p.y+5,p.w-10,p.h-8);
      ctx.strokeStyle='#504d44'; ctx.lineWidth=3; ctx.strokeRect(p.x+3,p.y+2,p.w-6,p.h-3);
      ctx.fillStyle='#5a4028'; ctx.fillRect(p.x+18,p.y+p.h-16,p.w-36,7);
      ctx.fillStyle='#2a2520'; ctx.fillRect(p.x+20,p.y+p.h-9,3,9); ctx.fillRect(p.x+p.w-23,p.y+p.h-9,3,9);
      ctx.fillStyle='#d4c896'; ctx.fillRect(p.x+9,p.y+10,15,20);
      ctx.fillStyle='#1a1810'; ctx.font='bold 7px Courier New'; ctx.fillText('0',p.x+14,p.y+23);
    } else if (p.type==='billboard') {
      ctx.fillStyle='#30281f'; ctx.fillRect(p.x+12,p.y+p.h-2,6,54); ctx.fillRect(p.x+p.w-18,p.y+p.h-2,6,54);
      ctx.fillStyle='#17130f'; ctx.fillRect(p.x,p.y,p.w,p.h);
      ctx.strokeStyle='#6a5840'; ctx.lineWidth=3; ctx.strokeRect(p.x+1,p.y+1,p.w-2,p.h-2);
      ctx.fillStyle='#c9b77a'; ctx.font='bold 9px Courier New'; ctx.textAlign='center';
      p.text.split('\n').forEach((line,i)=>ctx.fillText(line,p.x+p.w/2,p.y+22+i*14)); ctx.textAlign='left';
    } else if (p.type==='water_tower') {
      ctx.strokeStyle='#4d463b'; ctx.lineWidth=4;
      ctx.beginPath(); ctx.moveTo(p.x+18,p.y+p.h);ctx.lineTo(p.x+34,p.y+52);ctx.moveTo(p.x+p.w-18,p.y+p.h);ctx.lineTo(p.x+p.w-34,p.y+52);ctx.stroke();
      ctx.fillStyle='#37322a'; ctx.beginPath();ctx.ellipse(p.x+p.w/2,p.y+38,p.w/2,30,0,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#514a3e'; ctx.fillRect(p.x+5,p.y+28,p.w-10,23);
      ctx.fillStyle='#9b8b5b';ctx.font='bold 10px Courier New';ctx.textAlign='center';ctx.fillText(p.text,p.x+p.w/2,p.y+44);ctx.textAlign='left';
    } else if (p.type==='motel_sign') {
      ctx.fillStyle='#2c251d';ctx.fillRect(p.x+11,p.y+18,6,p.h-18);
      ctx.fillStyle='#15110e';ctx.fillRect(p.x,p.y,p.w,42);ctx.strokeStyle='#8a3a3a';ctx.lineWidth=2;ctx.strokeRect(p.x+1,p.y+1,p.w-2,40);
      ctx.fillStyle='#d06030';ctx.font='bold 8px Courier New';ctx.textAlign='center';p.text.split('\n').forEach((line,i)=>ctx.fillText(line,p.x+p.w/2,p.y+15+i*12));ctx.textAlign='left';
    } else if (p.type==='clothesline') {
      ctx.strokeStyle='#5a4a36';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.quadraticCurveTo((p.x+p.x2)/2,(p.y+p.y2)/2+15,p.x2,p.y2);ctx.stroke();
      ctx.fillStyle='#4b352c';ctx.fillRect(p.x-2,p.y-8,4,22);ctx.fillRect(p.x2-2,p.y2-8,4,22);
      const cols=['#8a3a3a','#4a5028','#675b46','#6b455e'];
      for(let i=1;i<5;i++){const t=i/5,x=p.x+(p.x2-p.x)*t,y=p.y+(p.y2-p.y)*t+Math.sin(t*Math.PI)*13;ctx.fillStyle=cols[i-1];ctx.fillRect(x-7,y+2,14,12);}
    } else if (p.type==='crossbuck') {
      ctx.fillStyle='#3a3024';ctx.fillRect(p.x-2,p.y-34,4,40);
      ctx.save();ctx.translate(p.x,p.y-30);ctx.rotate(.62);ctx.fillStyle='#d4c896';ctx.fillRect(-18,-3,36,6);ctx.rotate(-1.24);ctx.fillRect(-18,-3,36,6);ctx.restore();
    }
  }
}

export function drawKingdomSites(){
  const k=state.kingdom||freshKingdomState(),defs=[
    {d:KINGDOM_CLANS.blue_tarp,key:'clan_banner_blue',flag:'blueTarpCleared'},
    {d:KINGDOM_CLANS.cart_cavalry,key:'clan_banner_receipt',flag:'cartKeepCleared'},
    {d:KINGDOM_CLANS.copper_choir,key:'clan_banner_wire',flag:'copperChoirCleared'},
    {d:KINGDOM_EMPEROR,key:'clan_banner_curb',flag:'throneDitchCleared'},
  ];
  for(const b of defs){
    const p=b.d.banner;if(!visibleWorldRect(p.x-20,p.y-34,40,40,20))continue;
    const sp=ENV_SPRITE_CACHE[b.key];if(sp){ctx.globalAlpha=(state.flags&&state.flags[b.flag]) ? 0.58 : 1;ctx.drawImage(sp,p.x-16,p.y-30,32,32);ctx.globalAlpha=1;}
  }
  const clan=kingdomStageClan(k.stage);if(!clan||k.stage!==clan.marksStage)return;
  clan.marks.forEach((m,i)=>{
    if(!visibleWorldRect(m.x-18,m.y-18,36,36,10))return;const done=!!(k.marks&(1<<i));
    ctx.setLineDash(done?[]:[3,3]);ctx.strokeStyle=done?'#6f765e':'#e8c040';ctx.lineWidth=2;ctx.strokeRect(m.x-9,m.y-9,18,18);ctx.setLineDash([]);
    ctx.fillStyle=done?'#6f765e':'#d4c896';ctx.font='bold 9px Courier New';ctx.textAlign='center';ctx.fillText(done?'✓':String(i+1),m.x,m.y+3);ctx.textAlign='left';
  });
}

export function drawForegroundWorld() {
  // utility wires and laundry occupy the overhead plane.
  ctx.strokeStyle='rgba(28,22,16,.88)';ctx.lineWidth=1.5;
  for(const w of UTILITY_WIRES){
    const minX=Math.min(w[0],w[2]),minY=Math.min(w[1],w[3]);
    if(!visibleWorldRect(minX,minY,Math.abs(w[2]-w[0]),Math.abs(w[3]-w[1]),70))continue;
    const mx=(w[0]+w[2])/2,my=(w[1]+w[3])/2+12;
    ctx.beginPath();ctx.moveTo(w[0],w[1]-52);ctx.quadraticCurveTo(mx,my-52,w[2],w[3]-52);ctx.stroke();
    ctx.beginPath();ctx.moveTo(w[0],w[1]-48);ctx.quadraticCurveTo(mx,my-44,w[2],w[3]-48);ctx.stroke();
  }
  for(const p of WORLD_DECOR){
    if(p.type==='bus_shelter'&&visibleWorldRect(p.x,p.y,p.w,p.h,20)){
      ctx.fillStyle='#24221e';ctx.fillRect(p.x-2,p.y-3,p.w+4,7);
      ctx.fillStyle='rgba(212,200,150,.16)';ctx.fillRect(p.x,p.y-2,p.w,1);
    }
  }
  // existing park trees finally have a foreground canopy, so walking under one has depth.
  for(const p of PROPS){
    if(p.type!=='tree'||!visibleWorldRect(p.x-24,p.y-60,52,64,12))continue;
    const nearPlayer=Math.abs((P.x+P.w/2)-p.x)<26&&Math.abs((P.y+P.h/2)-(p.y-22))<34;
    ctx.globalAlpha = nearPlayer ? .64 : .92;
    ctx.fillStyle='#1d3b1c';ctx.beginPath();ctx.arc(p.x,p.y-38,20,0,Math.PI*2);ctx.fill();
    ctx.fillStyle='#31552a';ctx.beginPath();ctx.arc(p.x-8,p.y-43,13,0,Math.PI*2);ctx.arc(p.x+9,p.y-42,12,0,Math.PI*2);ctx.fill();
    ctx.globalAlpha=1;
  }
}

export function buildLightSprites() {
  const hg=LIGHT_HOLE.getContext('2d');
  const hole=hg.createRadialGradient(128,128,8,128,128,128);
  hole.addColorStop(0,'rgba(0,0,0,1)');
  hole.addColorStop(.45,'rgba(0,0,0,.72)');
  hole.addColorStop(1,'rgba(0,0,0,0)');
  hg.fillStyle=hole; hg.fillRect(0,0,256,256);
  const colors=new Set(['255,210,120',...WORLD_LIGHTS.map(l=>l.rgb)]);
  for(const rgb of colors){
    const c=document.createElement('canvas');c.width=256;c.height=256;
    const g=c.getContext('2d');
    const glow=g.createRadialGradient(128,128,3,128,128,128);
    glow.addColorStop(0,`rgba(${rgb},.62)`);
    glow.addColorStop(.38,`rgba(${rgb},.20)`);
    glow.addColorStop(1,`rgba(${rgb},0)`);
    g.fillStyle=glow;g.fillRect(0,0,256,256);
    LIGHT_GLOW_CACHE[rgb]=c;
  }
}

export function buildFogSheet() {
  const g=FOG_SHEET.getContext('2d');
  g.fillStyle='rgba(164,160,150,.14)';g.fillRect(0,0,W,H);
  const edge=g.createRadialGradient(W/2,H/2,90,W/2,H/2,390);
  edge.addColorStop(0,'rgba(164,160,150,0)');
  edge.addColorStop(1,'rgba(164,160,150,.46)');
  g.fillStyle=edge;g.fillRect(0,0,W,H);
  // cached horizontal banks keep the fog dirty and uneven without per-frame gradients.
  g.fillStyle='rgba(212,200,150,.045)';
  g.fillRect(0,118,W,52);g.fillRect(0,372,W,70);
}

export function nightAmount() {
  const t=state.dayTime;
  if(t<.2||t>=.8)return 1;
  if(t<.3)return 1-(t-.2)/.1;
  if(t<.7)return 0;
  return (t-.7)/.1;
}

export function punchLightMask(octx,sx,sy,r,power,amount){
  if(sx<-r||sx>W+r||sy<-r||sy>H+r)return;
  octx.globalAlpha=Math.min(1,power*amount);
  octx.drawImage(LIGHT_HOLE,sx-r,sy-r,r*2,r*2);
}

export function init_landmarks_a() {
  // ----- v14 cached set-back facades -----
  LANDMARK_CACHE = {};
  landmarkCacheReady = false;
  
  
  
  
  
  
  
  
  
  
  
  
  LIGHT_MASK = document.createElement('canvas');
  LIGHT_MASK.width=W; LIGHT_MASK.height=H;
  LIGHT_CTX = LIGHT_MASK.getContext('2d');
  LIGHT_HOLE = document.createElement('canvas');
  LIGHT_HOLE.width=256; LIGHT_HOLE.height=256;
  LIGHT_GLOW_CACHE = {};
  FOG_SHEET = document.createElement('canvas');
  FOG_SHEET.width=W; FOG_SHEET.height=H;
  
  
  
  
  
  
  
  
  
}

export function drawAll() {
  state.visualNow = performance.now();
  ctx.fillStyle = '#0a0805';
  ctx.fillRect(0,0,W,H);
  if (state.mode === 'title') return; // title is DOM overlay
  ctx.save();
  const sx = (state.shake>0?(Math.random()-.5)*state.shake:0);
  const sy = (state.shake>0?(Math.random()-.5)*state.shake:0);
  ctx.translate(-state.cam.x + sx, -state.cam.y + sy);
  // ground tiles — per-zone variety + procedural texture
  const startX = Math.floor(state.cam.x/TILE)*TILE;
  const startY = Math.floor(state.cam.y/TILE)*TILE;
  for (let x=startX; x<state.cam.x+W+TILE; x+=TILE) {
    for (let y=startY; y<state.cam.y+H+TILE; y+=TILE) {
      drawGroundTile(x, y);
    }
  }
  // v14 — roads, footpaths, rails and district ground marks connect the zone islands.
  drawWorldFabric();
  // zones (dashed border + tinted fill)
  for (const z of ZONES) {
    if (!visibleWorldRect(z.x,z.y,z.w,z.h,20)) continue;
    // canonical VIBE treatment: ~25% wash + dashed neighborhood edge.
    ctx.fillStyle = z.color + '40';
    ctx.fillRect(z.x, z.y, z.w, z.h);
    ctx.setLineDash([6,4]);
    ctx.strokeStyle = z.label;
    ctx.lineWidth = 2;
    ctx.strokeRect(z.x+1, z.y+1, z.w-2, z.h-2);
    ctx.setLineDash([]);
    ctx.fillStyle = z.label;
    ctx.font = '11px Courier New';
    ctx.fillText(z.name, z.x+8, z.y+18);
  }
  // low street furniture sits on the pavement; cached set-back facades establish blocks.
  drawWorldDecor('low');
  drawLandmarkFacades();
  // scrap yard fence (perimeter except south gap)
  drawScrapFence();
  // underpass concrete + rebar
  drawUnderpass();
  // buildings — v10 upgrade with awnings, framed windows, signs
  for (const b of BUILDINGS) {
    if (!visibleWorldRect(b.x,b.y,b.w,b.h,40)) continue;
    drawBuilding(b);
  }
  // marketplace stalls (decoration only)
  drawMarketStalls();
  // v13 wave 7 — hideout doors (only render if owned)
  drawHideoutDoors();

  // procedural graffiti on building walls
  drawGraffiti();
  // v13 wave 8b — wall-mounted posters (per-faction zone, 1-3 each)
  drawPosters();
  // Permanent office fixtures sit above wall grime and tags so every paid upgrade reads.
  drawOfficeExterior();
  // v13 wave 8b — zone-border crossing flash (decays each frame, faction-tinted)
  drawBorderGlow();

  // props (dumpsters, lamps, hydrants, etc.)
  drawProps();
  drawKingdomSites();
  drawClaimSites();
  // poles, shelter, signs, signals and clotheslines. bodies render below actors;
  // only their overhead caps return in drawForegroundWorld.
  drawWorldDecor('tall');
  // v13 wave 6 — dog leash (rendered between props and NPCs so leash sits under dog)
  drawDogLeash();

  // hidden cash piles — only render under tweaker vision OR if close
  for (const c of runtime.cashPiles) {
    if (c.collected) continue;
    const dx = (P.x+P.w/2) - c.x, dy = (P.y+P.h/2) - c.y;
    const close = (dx*dx + dy*dy) < 60*60;
    // intro pile is always visible (it's the tutorial breadcrumb)
    const alwaysVisible = !!c.intro;
    if (state.tweakerT > 0 || close || alwaysVisible || c.tool || c.equip) {
      // v13 wave 4 — torch pickups are always visible (a brutus drop in the dark is hard enough to find)
      if (c.tool === 'propane_torch') {
        const t = (Math.sin(performance.now()/180)+1)/2;
        // brass body
        ctx.fillStyle = '#c08038';
        ctx.fillRect(c.x-5, c.y-4, 10, 8);
        // valve
        ctx.fillStyle = '#604020';
        ctx.fillRect(c.x-2, c.y-7, 4, 3);
        // pilot flame
        ctx.fillStyle = `rgba(232,192,64,${0.6 + t*0.4})`;
        ctx.fillRect(c.x-1, c.y-11, 2, 4);
        continue;
      }
      // v13 wave 5 — priest's collar pickup: small white band with a black center seam
      if (c.equip === 'priest_collar') {
        const t = (Math.sin(performance.now()/240)+1)/2;
        // halo / glow
        ctx.fillStyle = `rgba(212,200,150,${0.18 + t*0.16})`;
        ctx.fillRect(c.x-9, c.y-9, 18, 18);
        // white band
        ctx.fillStyle = '#d4c896';
        ctx.fillRect(c.x-6, c.y-3, 12, 4);
        // reversed black tab
        ctx.fillStyle = '#0a0805';
        ctx.fillRect(c.x-2, c.y-2, 4, 2);
        continue;
      }
      ctx.fillStyle = state.tweakerT>0 ? '#80ff80' : '#e8c040';
      ctx.fillRect(c.x-4, c.y-3, 8, 6);
      ctx.fillStyle = '#604020';
      ctx.fillRect(c.x-3, c.y-2, 6, 1);
      // gentle pulse glow on the intro pile so day-1 player notices it
      if (alwaysVisible) {
        const t = (Math.sin(performance.now()/220)+1)/2;
        ctx.fillStyle = `rgba(232,192,64,${0.18 + t*0.18})`;
        ctx.fillRect(c.x-8, c.y-6, 16, 12);
      }
    }
  }

  // v13 wave 3 — pigeon crown world pickup (visible whenever the quest is active)
  if (state.crownPickup && !state.crownPickup.collected) {
    const cp = state.crownPickup;
    const t = performance.now()/200;
    const bob = Math.sin(t)*2;
    // base
    ctx.fillStyle = '#a07a18';
    ctx.fillRect(cp.x-7, cp.y-3+bob, 14, 5);
    // band points
    ctx.fillStyle = '#e8c040';
    ctx.fillRect(cp.x-7, cp.y-8+bob, 3, 6);
    ctx.fillRect(cp.x-2, cp.y-9+bob, 3, 7);
    ctx.fillRect(cp.x+3, cp.y-8+bob, 3, 6);
    // gem
    ctx.fillStyle = '#d488d4';
    ctx.fillRect(cp.x-1, cp.y-7+bob, 2, 2);
    // halo
    ctx.fillStyle = `rgba(232,192,64,${0.2 + Math.sin(t*1.5)*0.12})`;
    ctx.fillRect(cp.x-12, cp.y-12+bob, 24, 18);
  }

  // Bounded scene actors sit above props and below canonical actors. They never enter npcs.
  drawIncidents();

  // NPCs. Reuse the viewport buffer so a crowded scene does not manufacture an array
  // and a garbage-collection hitch every frame.
  VISIBLE_NPC_BUFFER.length=0;
  for(const n of runtime.npcs)if(!n.dead&&
    n.x>=state.cam.x-60&&n.x<=state.cam.x+W+40&&
    n.y>=state.cam.y-60&&n.y<=state.cam.y+H+40)VISIBLE_NPC_BUFFER.push(n);
  VISIBLE_NPC_BUFFER.sort((a,b)=>(a.y+a.h)-(b.y+b.h));
  for (const n of VISIBLE_NPC_BUFFER) {
    if (n.dead) continue;
    if (n.id==='mom' && isNight()) continue;
    if (n.id==='pete' && isNight()) continue;
    if (n.daytimeOnly && isNight()) continue;
    drawNpc(n);
  }
  // particles — additive glow + scale rendering
  ctx.globalCompositeOperation = 'lighter';
  for (const p of particles) {
    if (p.glow) {
      const s = (p.sz || 4) * 2;
      ctx.fillStyle = p.c;
      ctx.globalAlpha = Math.max(0, p.life/700);
      ctx.fillRect(p.x-s/2, p.y-s/2, s, s);
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1;
  for (const p of particles) {
    if (p.glow) continue;
    ctx.fillStyle = p.c;
    const s = p.sz || 4;
    ctx.fillRect(p.x-s/2, p.y-s/2, s, s);
  }
  // v13 wave 5 — projectiles (bottles, holy water) rendered after particles, before player
  for (const pr of runtime.projectiles) {
    ctx.save();
    ctx.translate(pr.x, pr.y);
    ctx.rotate(pr.rot);
    if (pr.kind === 'bottle') {
      // body — brown glass
      ctx.fillStyle = '#604020';
      ctx.fillRect(-10, -4, 20, 8);
      // shine line
      ctx.fillStyle = '#a07020';
      ctx.fillRect(-10, -3, 20, 1);
      // neck
      ctx.fillStyle = '#3a2010';
      ctx.fillRect(8, -2, 3, 4);
    } else if (pr.kind === 'holy') {
      const t = (Math.sin(performance.now()/80)+1)/2;
      // glow halo
      ctx.fillStyle = `rgba(200,230,255,${0.18 + t*0.18})`;
      ctx.fillRect(-10, -12, 20, 24);
      // vial body
      ctx.fillStyle = `rgba(160,200,240,${0.75 + t*0.25})`;
      ctx.fillRect(-5, -8, 10, 16);
      // cap
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(-3, -10, 6, 2);
    }
    ctx.restore();
  }
  // player sprite
  drawPlayer();
  drawIncidentPlayerCosmetics();
  // v17 attack smear: cached chunky motion art replaces the old filled hitbox rectangle.
  // Collision/reach still come exclusively from playerAttack().
  if (P.attacking > 0) {
    const phase=P.attacking>80?0:1,smear=SPRITE_CACHE['attack_smear_'+P.facing+'_'+phase];
    let ax=P.x-2,ay=P.y-4;
    if(P.facing==='down')ay+=17;
    if(P.facing==='up')ay-=18;
    if(P.facing==='left')ax-=18;
    if(P.facing==='right')ax+=18;
    if(smear){ctx.globalAlpha=.45+P.attacking/160*.45;ctx.drawImage(smear,ax,ay,32,32);ctx.globalAlpha=1;}
  }

  // canopies, shelter roof and overhead wires complete the foreground plane.
  drawForegroundWorld();

  ctx.restore();

  // lighting (screen-space pass — uses cam offsets)
  drawLighting();
  // weather
  drawWeather();
  drawObjectiveGuide();

  // flash overlay
  if (state.flash > 0) {
    ctx.fillStyle = state.flashColor;
    ctx.globalAlpha = Math.min(1, state.flash);
    ctx.fillRect(0,0,W,H);
    ctx.globalAlpha = 1;
  }
  // status overlays
  if (P.rockedT > 0) {
    ctx.fillStyle = `rgba(232,192,64,${0.08 + Math.sin(performance.now()/120)*0.04})`;
    ctx.fillRect(0,0,W,H);
  }
  if (P.crashT > 0) {
    ctx.fillStyle = 'rgba(180,80,180,.18)';
    ctx.fillRect(0,0,W,H);
  }
  // v13 wave 5 — stun overlay: red corner border + center "GRABBED" floater
  if (P.stunT > 0) {
    const t = (Math.sin(performance.now()/80)+1)/2;
    ctx.fillStyle = `rgba(208,64,64,${0.10 + t*0.10})`;
    ctx.fillRect(0,0,W,8); ctx.fillRect(0,H-8,W,8);
    ctx.fillRect(0,0,8,H); ctx.fillRect(W-8,0,8,H);
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 18px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('GRABBED', W/2, 50);
    ctx.textAlign = 'left';
  }
  // v13 wave 5 — slow overlay: pale-blue veil for holy-water slow
  if (P.slowT > 0) {
    ctx.fillStyle = `rgba(160,200,240,${0.08 + Math.sin(performance.now()/220)*0.05})`;
    ctx.fillRect(0,0,W,H);
  }
  if (P.hp <= 30) {
    ctx.fillStyle = `rgba(160,40,40,${0.08 + Math.sin(performance.now()/200)*0.05})`;
    ctx.fillRect(0,0,W,H);
  }

  // boss UI
  if (state.bossActive && state.bossNPC && !state.bossNPC.dead) {
    const b = state.bossNPC;
    ctx.fillStyle = 'rgba(0,0,0,.7)';
    ctx.fillRect(W/2-160, 8, 320, 32);
    ctx.strokeStyle = '#8a3a3a';
    ctx.lineWidth = 2;
    ctx.strokeRect(W/2-160, 8, 320, 32);
    ctx.fillStyle = '#d4c896';
    ctx.font = 'bold 12px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText((state.bossKind==='kingdom'?b.name:'TRE BAG TONY')+' · '+Math.max(0,Math.ceil(b.hp))+'/'+b.maxHp, W/2, 22);
    ctx.fillStyle = '#8a3a3a';
    ctx.fillRect(W/2-150, 28, 300*(b.hp/b.maxHp), 8);
    ctx.textAlign = 'left';
  }

  // combo display
  if (state.combo >= 2) {
    const fade = Math.min(1, state.comboT/1000);
    ctx.fillStyle = `rgba(232,192,64,${fade})`;
    ctx.font = 'bold ' + (16 + state.combo*2) + 'px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText(state.combo + 'x', W/2, H-80);
    ctx.font = '10px Courier New';
    ctx.fillText('combo', W/2, H-66);
    ctx.textAlign = 'left';
  }

  // low-HP edge vignette
  if (P.hp <= 30) {
    const intensity = (1 - P.hp/30) * 0.6 + Math.sin(performance.now()/300)*0.1;
    const g = ctx.createRadialGradient(W/2, H/2, 150, W/2, H/2, 460);
    g.addColorStop(0, 'rgba(160,40,40,0)');
    g.addColorStop(1, `rgba(160,40,40,${intensity})`);
    ctx.fillStyle = g;
    ctx.fillRect(0,0,W,H);
  }

  // shakes-max wobble
  if (P.shakes >= 90) {
    ctx.fillStyle = 'rgba(212,136,212,.08)';
    ctx.fillRect(0,0,W,H);
  }

  // weather under HUD
  // already drawn after restore

  // minimap
  drawMinimap();

  // v13 wave 4 — smoke overlay from a burnt cook (sits above gameplay, below the heat mini)
  if (state.smokeT > 0) drawSmokeOverlay();
  // v13 wave 4 — the heat minigame panel (only when mode === 'cookmini')
  if (state.mode === 'cookmini') drawHeatMini();
}

export function init_frame() {
  
  
  
}

export function drawScrapFence() {
  const z = ZONES.find(z=>z.id==='scrap');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,24)) return;
  ctx.strokeStyle = '#3a2818';
  ctx.lineWidth = 4;
  // top
  ctx.beginPath(); ctx.moveTo(z.x, z.y); ctx.lineTo(z.x+z.w, z.y); ctx.stroke();
  // left
  ctx.beginPath(); ctx.moveTo(z.x, z.y); ctx.lineTo(z.x, z.y+z.h); ctx.stroke();
  // right
  ctx.beginPath(); ctx.moveTo(z.x+z.w, z.y); ctx.lineTo(z.x+z.w, z.y+z.h); ctx.stroke();
  // south with gap (140px gap centered)
  const gapX = z.x+z.w/2 - 70;
  ctx.beginPath(); ctx.moveTo(z.x, z.y+z.h); ctx.lineTo(gapX, z.y+z.h); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(gapX+140, z.y+z.h); ctx.lineTo(z.x+z.w, z.y+z.h); ctx.stroke();
  // chainlink texture
  ctx.strokeStyle = 'rgba(80,60,40,.5)';
  ctx.lineWidth = 1;
  for (let x=z.x; x<z.x+z.w; x+=10) {
    ctx.beginPath(); ctx.moveTo(x, z.y); ctx.lineTo(x, z.y+10); ctx.stroke();
  }
  // scrap piles
  for (let i=0;i<8;i++) {
    const px = z.x + 40 + ((i*73)%(z.w-80));
    const py = z.y + 50 + ((i*97)%(z.h-100));
    ctx.fillStyle = '#604020';
    ctx.fillRect(px, py, 24, 14);
    ctx.fillStyle = '#d06030';
    ctx.fillRect(px+4, py+3, 8, 3);
  }
}

export function drawUnderpass() {
  const z = ZONES.find(z=>z.id==='underpass');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,80)) return;
  // Keep the oil/crack tile work visible; this is bridge shadow, not replacement floor.
  ctx.fillStyle = 'rgba(24,24,27,.42)';
  ctx.fillRect(z.x, z.y, z.w, z.h);
  // overhead beams
  ctx.fillStyle = '#1a1a1c';
  for (let i=0;i<5;i++) {
    ctx.fillRect(z.x + 20 + i*70, z.y+10, 6, z.h-20);
  }
  // rebar
  ctx.strokeStyle = '#a08060';
  ctx.lineWidth = 2;
  for (let i=0;i<3;i++) {
    ctx.beginPath();
    ctx.moveTo(z.x+40+i*100, z.y+z.h-30);
    ctx.lineTo(z.x+90+i*100, z.y+z.h-60);
    ctx.stroke();
  }
  // v13 wave 6 — sodium-orange light patches (always-on, additive in world space).
  // makes the zone read as perpetually dim even in daytime.
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const patches = [
    { x: z.x + 80,  y: z.y + 80 },
    { x: z.x + 220, y: z.y + 140 },
    { x: z.x + 320, y: z.y + 70 },
  ];
  const t = (Math.sin(performance.now()/700)+1)/2;
  for (const lp of patches) {
    const g = ctx.createRadialGradient(lp.x, lp.y, 4, lp.x, lp.y, 70);
    g.addColorStop(0, `rgba(232,140,40,${0.32 + t*0.08})`);
    g.addColorStop(0.5, 'rgba(220,120,30,.18)');
    g.addColorStop(1, 'rgba(220,120,30,0)');
    ctx.fillStyle = g;
    ctx.fillRect(lp.x-70, lp.y-70, 140, 140);
  }
  ctx.restore();
  // car shadow rumble — every 8s a "car" sweeps overhead visually
  const phase = ((Date.now()/8000)%1);
  if (phase < 0.2) {
    const cx = z.x + phase*z.w*6;
    ctx.fillStyle = 'rgba(0,0,0,.5)';
    ctx.fillRect(cx, z.y-10, 120, 8);
  }
}

export function drawDogLeash() {
  const post = PROPS.find(p => p.type === 'leash_post');
  if (!post) return;
  const dog = runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead);
  if (!dog) return;
  if (!visibleWorldRect(Math.min(post.x,dog.x),Math.min(post.y,dog.y),Math.abs(post.x-dog.x)+dog.w,Math.abs(post.y-dog.y)+dog.h,24)) return;
  // simple zig-zag dark chain
  ctx.strokeStyle = '#3a2810';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(post.x, post.y-8);
  const midX = (post.x + dog.x+dog.w/2)/2;
  const midY = (post.y-8 + dog.y+dog.h/2)/2 + 4;
  ctx.lineTo(midX, midY);
  ctx.lineTo(dog.x+dog.w/2, dog.y+dog.h/2);
  ctx.stroke();
  // chain "links" — small dots along the path
  ctx.fillStyle = '#5a4828';
  for (let i=0.15; i<1; i+=0.18) {
    const lx = post.x*(1-i) + (dog.x+dog.w/2)*i;
    const ly = (post.y-8)*(1-i) + (dog.y+dog.h/2)*i;
    ctx.fillRect(lx-1, ly-1, 2, 2);
  }
}

export function init_landmarks_b() {
  
  
  
  
  // v13 wave 6 — render the chain leash from the leash_post to the scrap_dog
  
  
  
}

export let TILE_PALETTES;

export function zoneAt(wx, wy) {
  for (const z of ZONES) {
    if (wx>=z.x && wx<z.x+z.w && wy>=z.y && wy<z.y+z.h) return z.id;
  }
  return 'default';
}

export function terrainAt(wx, wy) {
  const zid = zoneAt(wx, wy);
  if (zid !== 'default') return zid;
  for (const r of TERRAIN_REGIONS) {
    if (wx>=r.x && wx<r.x+r.w && wy>=r.y && wy<r.y+r.h) return r.palette;
  }
  return 'default';
}

export function drawGroundTile(x, y) {
  const cx = x + TILE/2, cy = y + TILE/2;
  const zid = terrainAt(cx, cy);
  const pal = TILE_PALETTES[zid] || TILE_PALETTES.default;
  const checker = ((x/TILE)+(y/TILE)) & 1;
  ctx.fillStyle = pal.base[checker];
  ctx.fillRect(x, y, TILE, TILE);
  // deterministic per-tile pseudo-random
  const h = (x*73 ^ y*131) >>> 0;
  // procedural grime patches
  if ((h % 97) < 12) {
    ctx.fillStyle = pal.grime;
    const gx = x + 6 + (h % 40);
    const gy = y + 8 + ((h>>5) % 36);
    ctx.fillRect(gx, gy, 10 + ((h>>3)%14), 6 + ((h>>7)%10));
  }
  // crack lines
  if ((h % 89) < 6) {
    ctx.strokeStyle = pal.crack;
    ctx.lineWidth = 1;
    ctx.beginPath();
    const cx0 = x + (h%TILE);
    const cy0 = y + ((h>>2)%TILE);
    ctx.moveTo(cx0, cy0);
    ctx.lineTo(cx0 + 8, cy0 + 4);
    ctx.lineTo(cx0 + 14, cy0 + 2);
    ctx.stroke();
  }
  // brick grout lines on marketplace
  if (pal.brick) {
    ctx.strokeStyle = 'rgba(40,20,10,.4)';
    ctx.lineWidth = 1;
    const off = (y / TILE) & 1 ? TILE/2 : 0;
    ctx.beginPath();
    for (let bx=0; bx<TILE; bx+=16) {
      ctx.moveTo(x+bx+off, y);
      ctx.lineTo(x+bx+off, y+TILE/2);
      ctx.moveTo(x+bx+off-8, y+TILE/2);
      ctx.lineTo(x+bx+off-8, y+TILE);
    }
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // tile grid for laundromat
  if (pal.tile) {
    ctx.strokeStyle = 'rgba(40,60,90,.4)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x+0.5, y+0.5, TILE-1, TILE-1);
    ctx.beginPath();
    ctx.moveTo(x+TILE/2, y); ctx.lineTo(x+TILE/2, y+TILE);
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // weed clumps on the block
  if (pal.weed && (h % 211) < 8) {
    const wx = x + (h % TILE), wy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#2a3818';
    ctx.fillRect(wx, wy, 3, 4);
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(wx+1, wy-1, 1, 2);
  }
  // v13 wave 6 — underpass: oil stains (black slick blobs) on top of the cracked concrete
  if (pal.oilstain && (h % 137) < 6) {
    const ox = x + 8 + (h % 36);
    const oy = y + 10 + ((h>>2) % 30);
    ctx.fillStyle = 'rgba(8,6,4,.72)';
    ctx.beginPath();
    ctx.ellipse(ox, oy, 7 + ((h>>3)%5), 4 + ((h>>5)%3), 0, 0, Math.PI*2);
    ctx.fill();
    // iridescent rainbow sheen on top
    ctx.fillStyle = 'rgba(80,60,90,.25)';
    ctx.fillRect(ox-3, oy-1, 6, 1);
  }
  // v13 wave 6 — underpass: cracked-concrete bigger fracture lines
  if (pal.concrete && (h % 73) < 9) {
    ctx.strokeStyle = 'rgba(0,0,0,.55)';
    ctx.lineWidth = 1;
    const cx1 = x + (h%TILE), cy1 = y + ((h>>4)%TILE);
    ctx.beginPath();
    ctx.moveTo(cx1, cy1);
    ctx.lineTo(cx1 + 16, cy1 + 6);
    ctx.lineTo(cx1 + 22, cy1 + 14);
    ctx.lineTo(cx1 + 12, cy1 + 22);
    ctx.stroke();
  }
  // v13 wave 6 — scrap yard: dirt mottling (warm clumps) reading as raked earth not pavement
  if (pal.dirt && (h % 53) < 14) {
    const dx = x + (h % TILE), dy = y + ((h>>3) % TILE);
    ctx.fillStyle = 'rgba(100,60,28,.32)';
    ctx.fillRect(dx, dy, 4, 3);
    if ((h % 211) < 30) {
      ctx.fillStyle = 'rgba(60,40,20,.5)';
      ctx.fillRect(dx+1, dy+1, 2, 1);
    }
  }
  // puddles in alley
  if (pal.puddle && (h % 167) < 5) {
    const px2 = x + 10 + (h % 30);
    const py2 = y + 14 + ((h>>3) % 24);
    ctx.fillStyle = 'rgba(40,55,70,.55)';
    ctx.beginPath();
    ctx.ellipse(px2, py2, 11, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(180,200,220,.18)';
    ctx.fillRect(px2-6, py2-1, 5, 1);
  }
  // v13 wave 8a — train yard: gravel ballast (small dark flecks)
  if (pal.gravel && (h % 41) < 18) {
    const gx = x + (h % TILE), gy = y + ((h>>3) % TILE);
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(gx, gy, 2, 2);
    if ((h % 113) < 30) {
      ctx.fillStyle = 'rgba(120,100,80,.3)';
      ctx.fillRect(gx+1, gy+1, 1, 1);
    }
  }
  // v13 wave 8a — train yard: horizontal rail bands. each band is 4px tall every 48px on the tile.
  // we render the bands as part of the ground tile so it's free per-tile work.
  if (pal.tracks) {
    // two parallel rails per tile row, with crossties between
    const railY1 = y + 22;
    const railY2 = y + 40;
    // dark crosstie underneath (wood)
    ctx.fillStyle = 'rgba(40,28,16,.55)';
    for (let tx=0; tx<TILE; tx+=14) {
      ctx.fillRect(x+tx+2, railY1-3, 8, railY2-railY1+6);
    }
    // steel rails
    ctx.fillStyle = '#605c50';
    ctx.fillRect(x, railY1, TILE, 2);
    ctx.fillRect(x, railY2, TILE, 2);
    // shine highlight on the rail head
    ctx.fillStyle = 'rgba(180,170,150,.35)';
    ctx.fillRect(x, railY1, TILE, 1);
    ctx.fillRect(x, railY2, TILE, 1);
  }
  // v13 wave 8a — park: grass tufts + occasional dandelion
  if (pal.grass && (h % 31) < 14) {
    const gx = x + (h % TILE), gy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#3a6028';
    ctx.fillRect(gx, gy, 1, 3);
    ctx.fillRect(gx+1, gy-1, 1, 4);
    ctx.fillRect(gx-1, gy, 1, 2);
    if ((h % 211) < 9) {
      // dandelion head
      ctx.fillStyle = '#e8c040';
      ctx.fillRect(gx+1, gy-3, 2, 2);
    }
  }
  // v13 wave 8a — skid row: scattered trash flecks (cigarette butts, wrappers)
  if (pal.skidtrash && (h % 47) < 7) {
    const tx = x + (h % TILE), ty = y + ((h>>3) % TILE);
    const flick = h & 1;
    ctx.fillStyle = flick ? '#5a4030' : '#a08868';
    ctx.fillRect(tx, ty, 3, 1);
    if ((h % 113) < 20) {
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(tx+1, ty, 1, 1);
    }
  }
  // v13 wave 8a — old school: faint chalk smudges + hopscotch flecks
  if (pal.schoolyard && (h % 79) < 5) {
    const cx = x + (h % TILE), cy = y + ((h>>2) % TILE);
    ctx.fillStyle = 'rgba(220,210,180,.25)';
    ctx.fillRect(cx, cy, 4, 1);
    ctx.fillRect(cx+1, cy+2, 2, 1);
  }
  // v14 — connective-region material accents.
  if (pal.deadgrass && (h % 43) < 10) {
    const gx = x + (h % TILE), gy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#5a5028';
    ctx.fillRect(gx, gy, 1, 4);
    ctx.fillRect(gx+2, gy+1, 1, 3);
    ctx.fillStyle = '#786438';
    ctx.fillRect(gx+1, gy, 1, 2);
  }
  if (pal.patch && (h % 101) < 8) {
    const px = x + 5 + (h % 28), py = y + 9 + ((h>>3) % 28);
    ctx.fillStyle = 'rgba(8,7,5,.28)';
    ctx.fillRect(px, py, 18 + ((h>>5)%16), 11 + ((h>>7)%10));
    ctx.strokeStyle = 'rgba(94,78,54,.24)';
    ctx.strokeRect(px+.5, py+.5, 18 + ((h>>5)%16), 11 + ((h>>7)%10));
  }
  if (pal.wet && (h % 127) < 8) {
    const px = x + 10 + (h % 30), py = y + 12 + ((h>>3) % 26);
    ctx.fillStyle = 'rgba(38,55,56,.5)';
    ctx.beginPath();
    ctx.ellipse(px, py, 13, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(168,180,166,.12)';
    ctx.fillRect(px-7, py-1, 7, 1);
  }
  if (pal.transit) {
    ctx.fillStyle = 'rgba(232,192,64,.12)';
    ctx.fillRect(x, y+TILE-5, TILE, 3);
  }
}

export function drawMarketStalls() {
  const z = ZONES.find(z=>z.id==='market');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,48)) return;
  for (let i=0;i<4;i++) {
    const px = z.x + 80 + i*160;
    const py = z.y + 60;
    // base table
    ctx.fillStyle = '#3a2a1a';
    ctx.fillRect(px, py+10, 90, 22);
    ctx.fillStyle = '#5a4828';
    ctx.fillRect(px, py+10, 90, 6);
    // table legs
    ctx.fillStyle = '#1a1008';
    ctx.fillRect(px+2, py+30, 4, 8);
    ctx.fillRect(px+84, py+30, 4, 8);
    ctx.strokeStyle = '#1a1008';
    ctx.lineWidth = 1;
    ctx.strokeRect(px, py+10, 90, 22);
    // umbrella stripes
    const colors = [['#a8484a','#7a2a2c'],['#5a6028','#3a4018'],['#7a5028','#503018'],['#b8d040','#88a020']];
    const [base, dark] = colors[i];
    for (let s=0; s<13; s++) {
      ctx.fillStyle = (s & 1) ? base : dark;
      ctx.fillRect(px-8 + s*8.2, py-10, 8, 12);
    }
    // umbrella pole
    ctx.fillStyle = '#3a3020';
    ctx.fillRect(px+44, py+2, 2, 10);
    // wares on table
    ctx.fillStyle = ['#e8c040','#d488d4','#88c0ff','#d06030'][i];
    ctx.fillRect(px+18, py+14, 6, 6);
    ctx.fillRect(px+38, py+14, 6, 6);
    ctx.fillRect(px+58, py+14, 6, 6);
    ctx.fillStyle = ['#a08030','#8a5090','#5080a0','#a04020'][i];
    ctx.fillRect(px+18, py+18, 6, 2);
    ctx.fillRect(px+38, py+18, 6, 2);
    ctx.fillRect(px+58, py+18, 6, 2);
  }
}

export function init_tiles() {
  // ---------- Per-zone tile palettes (v10 visual overhaul) ----------
  TILE_PALETTES = {
    default:    { base:['#1a1810','#181610'], grime:'rgba(40,30,20,.55)', crack:'rgba(8,6,4,.4)' },
    block:      { base:['#22201a','#1f1d18'], grime:'rgba(80,60,30,.35)', crack:'rgba(0,0,0,.5)', weed:true },
    pawn:       { base:['#2a2818','#28261a'], grime:'rgba(60,50,30,.35)', crack:'rgba(8,6,4,.6)' },
    dealer:     { base:['#2a1a15','#241814'], grime:'rgba(140,40,30,.3)', crack:'rgba(0,0,0,.55)' },
    abandoned:  { base:['#1c1818','#181414'], grime:'rgba(80,30,30,.45)', crack:'rgba(0,0,0,.65)' },
    market:     { base:['#322a22','#2c241e'], grime:'rgba(168,80,30,.3)', crack:'rgba(0,0,0,.45)', brick:true },
    alley:      { base:['#161614','#131312'], grime:'rgba(20,60,80,.35)', crack:'rgba(0,0,0,.8)', puddle:true },
    church:     { base:['#262030','#221c2a'], grime:'rgba(80,60,100,.35)', crack:'rgba(0,0,0,.6)' },
    projects:   { base:['#1d1c20','#191820'], grime:'rgba(60,60,90,.3)', crack:'rgba(0,0,0,.6)' },
    // v13 wave 6 — underpass gets a heavier cracked-concrete palette: lighter base, oil stains, deeper cracks
    underpass:  { base:['#2a2a2d','#252528'], grime:'rgba(20,18,14,.55)', crack:'rgba(0,0,0,.85)', concrete:true, oilstain:true },
    laundromat: { base:['#3a3a48','#34344a'], grime:'rgba(120,160,200,.18)', crack:'rgba(0,0,0,.4)', tile:true },
    busstop:    { base:['#27251f','#23211c'], grime:'rgba(90,70,40,.32)', crack:'rgba(0,0,0,.58)', concrete:true, transit:true },
    // v13 wave 6 — scrap yard pushed warmer dirt brown so it reads as Yuri's home turf, not generic concrete
    scrap:      { base:['#3a2c1a','#322618'], grime:'rgba(120,60,30,.45)', crack:'rgba(50,30,15,.5)', dirt:true },
    // v14 draws coherent full-length rails in drawWorldFabric; the tile owns ballast only.
    trainyard:  { base:['#2c2a26','#26241f'], grime:'rgba(90,80,60,.4)', crack:'rgba(0,0,0,.55)', gravel:true },
    // v13 wave 8a — park gets a green grass palette + tufts/dandelions
    park:       { base:['#2e4a26','#28401f'], grime:'rgba(80,140,50,.18)', crack:'rgba(0,0,0,.25)', grass:true },
    // v13 wave 8a — skid row gets darker, oilier cracked asphalt than underpass + more trash flecks
    skidrow:    { base:['#1f1d18','#1b1915'], grime:'rgba(30,18,10,.55)', crack:'rgba(0,0,0,.85)', concrete:true, skidtrash:true },
    // v13 wave 8a — old school: weedy cracked playground concrete with chalk smudges
    oldschool:  { base:['#2a201c','#241a16'], grime:'rgba(120,70,40,.3)', crack:'rgba(0,0,0,.55)', schoolyard:true, weed:true },
    // v18 far-east materials. Geometry remains visual; only BUILDINGS participate in collision.
    warehouse_row:{ base:['#292720','#25231e'], grime:'rgba(86,58,34,.42)', crack:'rgba(0,0,0,.76)', concrete:true, oilstain:true, patch:true },
    canal:        { base:['#252a27','#202522'], grime:'rgba(42,70,62,.42)', crack:'rgba(0,0,0,.72)', concrete:true, wet:true },
    the_lot:      { base:['#2b261d','#272219'], grime:'rgba(92,66,34,.38)', crack:'rgba(0,0,0,.66)', deadgrass:true, patch:true, weed:true },
    // v19 curb kingdoms. They are visually distinct but mechanically faction-neutral.
    blue_tarp_court:   { base:['#29333a','#252d33'], grime:'rgba(55,75,88,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true, wet:true },
    cart_cavalry_keep: { base:['#302c24','#29261f'], grime:'rgba(74,58,38,.48)', crack:'rgba(0,0,0,.78)', concrete:true, oilstain:true, skidtrash:true },
    copper_choir_yard: { base:['#39291e','#32241b'], grime:'rgba(130,68,35,.38)', crack:'rgba(54,28,14,.62)', dirt:true, oilstain:true, deadgrass:true },
    throne_ditch:      { base:['#292821','#24241f'], grime:'rgba(56,72,66,.48)', crack:'rgba(0,0,0,.8)', concrete:true, wet:true, deadgrass:true },
    // v14 outside-zone materials. They fill the connective world but never replace a zone palette.
    vacant:          { base:['#28231a','#242017'], grime:'rgba(96,66,34,.42)', crack:'rgba(0,0,0,.55)', dirt:true, deadgrass:true },
    service:         { base:['#211f1a','#1e1c18'], grime:'rgba(72,52,34,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true },
    drainage:        { base:['#201f1c','#1d1c19'], grime:'rgba(44,58,54,.45)', crack:'rgba(0,0,0,.78)', concrete:true, wet:true },
    rail_approach:   { base:['#302b22','#29251d'], grime:'rgba(95,70,42,.4)', crack:'rgba(0,0,0,.58)', gravel:true, deadgrass:true },
    dead_grass:      { base:['#292419','#252016'], grime:'rgba(95,76,38,.38)', crack:'rgba(0,0,0,.58)', dirt:true, deadgrass:true },
    school_outskirts:{ base:['#292019','#251b16'], grime:'rgba(100,64,36,.34)', crack:'rgba(0,0,0,.62)', schoolyard:true, deadgrass:true },
  };
  
  
  
  
  
  
  
}

export let BUILDING_STYLE, GRAFFITI_PALETTES, POSTER_LINES, POSTER_BG;

export function drawBuilding(b) {
  // base shadow under building
  ctx.fillStyle = 'rgba(0,0,0,.45)';
  ctx.fillRect(b.x+4, b.y+b.h, b.w-8, 6);
  // wall — base color
  ctx.fillStyle = b.color;
  ctx.fillRect(b.x, b.y, b.w, b.h);
  // brick texture overlay (subtle)
  ctx.fillStyle = 'rgba(0,0,0,.12)';
  for (let by=8; by<b.h; by+=10) {
    const off = ((by/10) & 1) ? 8 : 0;
    for (let bx=0; bx<b.w; bx+=16) {
      ctx.fillRect(b.x+bx+off, b.y+by, 14, 1);
    }
  }
  for (let by=0; by<b.h; by+=10) {
    for (let bx=0; bx<b.w; bx+=16) {
      const off = ((by/10) & 1) ? 8 : 0;
      ctx.fillRect(b.x+bx+off+13, b.y+by, 1, 10);
    }
  }
  // border / mortar shadow
  ctx.strokeStyle = b.border;
  ctx.lineWidth = 3;
  ctx.strokeRect(b.x+1, b.y+1, b.w-2, b.h-2);
  // top edge highlight
  ctx.fillStyle = 'rgba(255,240,180,.08)';
  ctx.fillRect(b.x, b.y, b.w, 2);

  const style = BUILDING_STYLE[b.name];
  // awning
  if (style && style.awning && !(b.locked && P.rank < 4)) {
    const aw = b.w - 12;
    const aH = 12;
    ctx.fillStyle = style.awning;
    // alternating stripes
    for (let s=0; s<Math.floor(aw/8); s++) {
      ctx.fillStyle = (s & 1) ? style.awning : '#fff8d0';
      ctx.fillRect(b.x + 6 + s*8, b.y - aH + 2, 8, aH);
    }
    // awning frame
    ctx.fillStyle = '#1a1008';
    ctx.fillRect(b.x+6, b.y-aH, aw, 3);
    ctx.fillRect(b.x+6, b.y-aH+2, 3, aH);
    ctx.fillRect(b.x+b.w-9, b.y-aH+2, 3, aH);
  }

  // windows
  if (!b.locked || P.rank >= 4) {
    const winY = b.y + (style && style.awning ? 18 : 14);
    const winH = 18;
    const winN = Math.max(2, Math.floor(b.w / 40));
    const gap = (b.w - winN*22) / (winN+1);
    for (let i=0;i<winN;i++) {
      const wx = b.x + gap + i*(22+gap);
      // window frame (dark)
      ctx.fillStyle = '#0a0805';
      ctx.fillRect(wx-1, winY-1, 24, winH+2);
      // window pane (lit / dim based on time)
      const baseLit = isNight() ? 1 : 0.55;
      const flick = (b.name === 'CORNER') ? (Math.sin(performance.now()/110 + i*0.7)>0.3) : false;
      let paneColor;
      if (b.name === 'CHURCH') {
        // stained glass — alternates cells
        paneColor = ['#d488d4','#88c0ff','#e8c040','#a8c030'][(i + Math.floor(winY/2)) % 4];
        ctx.fillStyle = paneColor;
        ctx.fillRect(wx, winY, 22, winH);
        // lead came (cross + diagonals)
        ctx.strokeStyle = '#0a0805';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(wx+11, winY); ctx.lineTo(wx+11, winY+winH);
        ctx.moveTo(wx, winY+winH/2); ctx.lineTo(wx+22, winY+winH/2);
        ctx.moveTo(wx, winY); ctx.lineTo(wx+22, winY+winH);
        ctx.moveTo(wx+22, winY); ctx.lineTo(wx, winY+winH);
        ctx.stroke();
      } else if (b.name === 'LAUNDROMAT') {
        // bright fluorescent
        ctx.fillStyle = `rgba(180,220,255,${0.5 + baseLit*0.3})`;
        ctx.fillRect(wx, winY, 22, winH);
        // washing machine drum visible
        ctx.fillStyle = 'rgba(0,0,0,.5)';
        ctx.beginPath();
        ctx.arc(wx+11, winY+winH/2, 6, 0, Math.PI*2);
        ctx.fill();
        ctx.fillStyle = '#88c0ff';
        ctx.beginPath();
        ctx.arc(wx+11, winY+winH/2, 4, 0, Math.PI*2);
        ctx.fill();
        // spin
        const spin = performance.now()/300 + i;
        ctx.fillStyle = '#0a0805';
        ctx.fillRect(wx+9 + Math.cos(spin)*2, winY+winH/2 + Math.sin(spin)*2 - 1, 4, 2);
      } else if (b.name === 'CORNER') {
        // dark with flickering TV
        ctx.fillStyle = '#080805';
        ctx.fillRect(wx, winY, 22, winH);
        ctx.fillStyle = flick ? '#88c0ff' : '#3a4858';
        ctx.fillRect(wx+4, winY+5, 14, 9);
        // TV stand
        ctx.fillStyle = '#1a1010';
        ctx.fillRect(wx+9, winY+winH-3, 4, 2);
      } else {
        // generic warm light interior
        ctx.fillStyle = `rgba(232,192,64,${baseLit})`;
        ctx.fillRect(wx, winY, 22, winH);
        // PAWN — Pete behind glass
        if (b.name === 'PAWN' && i === 0) {
          ctx.fillStyle = '#3a2818';
          ctx.fillRect(wx+6, winY+4, 10, 10);
          ctx.fillStyle = '#d4c896';
          ctx.fillRect(wx+8, winY+6, 6, 4);
          // hot pocket steam
          if (isNight()) {
            const t = performance.now()/400;
            ctx.fillStyle = 'rgba(232,232,200,.4)';
            ctx.beginPath();
            ctx.arc(wx+11 + Math.sin(t)*2, winY+1 - (t%4)*1.5, 1.5, 0, Math.PI*2);
            ctx.fill();
          }
        }
        // cross panes
        ctx.strokeStyle = 'rgba(20,10,5,.85)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(wx+11, winY); ctx.lineTo(wx+11, winY+winH);
        ctx.moveTo(wx, winY+winH/2); ctx.lineTo(wx+22, winY+winH/2);
        ctx.stroke();
      }
      // window-sill
      ctx.fillStyle = '#5a4028';
      ctx.fillRect(wx-2, winY+winH, 26, 2);
    }
  }

  // sign / neon
  if (style && style.sign) {
    const sigY = b.y - (style.awning ? 22 : 12);
    const sigW = style.sign.length * 8 + 12;
    const sigX = b.x + (b.w - sigW)/2;
    // back plate
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(sigX-2, sigY-2, sigW+4, 14);
    // neon glow at night
    if (isNight()) {
      ctx.save();
      ctx.shadowColor = style.neon;
      ctx.shadowBlur = 14;
      ctx.fillStyle = style.signColor;
      ctx.font = 'bold 11px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText(style.sign, b.x + b.w/2, sigY+9);
      ctx.shadowBlur = 0;
      ctx.restore();
    } else {
      ctx.fillStyle = style.signColor;
      ctx.font = 'bold 11px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText(style.sign, b.x + b.w/2, sigY+9);
    }
    ctx.textAlign = 'left';
  } else if (b.name && b.name !== '') {
    ctx.fillStyle = '#d4c896';
    ctx.font = 'bold 11px Courier New';
    ctx.fillText(b.name, b.x+8, b.y+10);
  }

  // church cross
  if (style && style.cross) {
    ctx.fillStyle = '#d488d4';
    ctx.fillRect(b.x + b.w/2 - 2, b.y - 18, 4, 14);
    ctx.fillRect(b.x + b.w/2 - 6, b.y - 14, 12, 4);
  }

  // boarded planks for locked building
  if (b.locked && P.rank < 4) {
    ctx.strokeStyle = '#5a3a1a';
    ctx.lineWidth = 4;
    for (let i=0;i<3;i++) {
      ctx.beginPath();
      ctx.moveTo(b.x+10, b.y+b.h/2 - 14 + i*14);
      ctx.lineTo(b.x+b.w-10, b.y+b.h/2 - 8 + i*14);
      ctx.stroke();
    }
    // nail heads
    ctx.fillStyle = '#3a2010';
    for (let i=0;i<3;i++) {
      ctx.fillRect(b.x+12, b.y+b.h/2 - 14 + i*14 - 1, 2, 2);
      ctx.fillRect(b.x+b.w-14, b.y+b.h/2 - 8 + i*14 - 1, 2, 2);
    }
    ctx.font = '16px monospace';
    ctx.fillText('🔒', b.x+b.w/2-8, b.y+b.h/2+6);
    ctx.font = '9px Courier New';
    ctx.fillStyle = '#8a3a3a';
    ctx.fillText('RANK 4+', b.x+b.w/2-22, b.y+b.h-8);
  }
  // door gap
  if (b.doorGap) {
    // door shadow
    ctx.fillStyle = '#0a0518';
    ctx.fillRect(b.x+b.w/2-25, b.y+b.h-8, 50, 12);
    // door frame light spill
    if (isNight()) {
      const g = ctx.createRadialGradient(b.x+b.w/2, b.y+b.h, 4, b.x+b.w/2, b.y+b.h, 60);
      g.addColorStop(0, 'rgba(232,192,64,.4)');
      g.addColorStop(1, 'rgba(232,192,64,0)');
      ctx.fillStyle = g;
      ctx.fillRect(b.x+b.w/2-60, b.y+b.h-4, 120, 70);
    }
  }
}

export function pickGraffitiLine(faction) {
  const pool = (faction === 'scrap') ? SCRAP_GRAFFITI_LINES
             : (faction === 'spiritual') ? SPIRITUAL_GRAFFITI_LINES
             : GRAFFITI_LINES;
  return pool[Math.floor(Math.random()*pool.length)];
}

export function buildGraffiti() {
  // if saved layout exists, just reuse it
  if (state.graffiti && state.graffiti.length) return;
  const out = [];
  const N = 12 + Math.floor(Math.random()*7); // 12-18
  // candidate walls: every BUILDING, both side and bottom faces (not roof, not under awnings).
  const walls = [];
  for (const b of BUILDINGS) {
    if (b.locked) continue; // skip the abandoned (boarded up — graffiti unreadable through planks)
    // bottom strip
    walls.push({ b, kind:'bottom' });
    // both side strips
    walls.push({ b, kind:'leftside' });
    walls.push({ b, kind:'rightside' });
  }
  for (let i=0;i<N;i++) {
    const wall = walls[Math.floor(Math.random()*walls.length)];
    const b = wall.b;
    // determine faction by where the building sits
    const zid = zoneAt(b.x + b.w/2, b.y + b.h/2);
    const z = ZONES.find(z=>z.id===zid);
    const faction = (z && z.faction) || 'street';
    const text = pickGraffitiLine(faction);
    const palette = GRAFFITI_PALETTES[faction] || GRAFFITI_PALETTES.street;
    let x, y;
    if (wall.kind === 'bottom') {
      x = b.x + 6 + Math.random()*(b.w-80);
      y = b.y + b.h - 8 - Math.random()*16;
    } else if (wall.kind === 'leftside') {
      x = b.x + 4;
      y = b.y + 24 + Math.random()*(b.h-50);
    } else {
      x = b.x + b.w - 70;
      y = b.y + 24 + Math.random()*(b.h-50);
    }
    out.push({
      x, y, text,
      col: palette[Math.floor(Math.random()*palette.length)],
      rot: ((Math.random()-.5) * 0.18), // -5° to +5° (radians ~0.087)
      sz: 8 + Math.floor(Math.random()*3), // 8-10 px
    });
  }
  state.graffiti = out;
}

export function drawGraffiti() {
  if (!state.graffiti || !state.graffiti.length) buildGraffiti();
  if (!state.graffiti) return;
  for (const g of state.graffiti) {
    if (!visibleWorldRect(g.x-80,g.y-18,170,28,16)) continue;
    ctx.save();
    ctx.translate(g.x, g.y);
    ctx.rotate(g.rot);
    ctx.font = 'bold '+(g.sz||9)+'px Courier New';
    ctx.fillStyle = g.col;
    ctx.globalAlpha = 0.65;
    ctx.fillText(g.text, 0, 0);
    // chalky double-pass for that spray-grit feel
    ctx.globalAlpha = 0.18;
    ctx.fillText(g.text, 0.5, 0.5);
    ctx.globalAlpha = 1;
    ctx.restore();
  }
}

export function buildPosters() {
  if (state.posters && state.posters.length) return;
  const out = [];
  // for each non-locked building, decide if it's in a faction zone, and if so place 1-3 posters
  // on its bottom/left/right wall faces.
  const perZoneCounts = {};
  for (const b of BUILDINGS) {
    if (b.locked) continue;
    const zid = zoneAt(b.x + b.w/2, b.y + b.h/2);
    const z = ZONES.find(z=>z.id===zid);
    if (!z || !z.faction || z.faction === 'neutral') continue;
    const k = z.id;
    perZoneCounts[k] = perZoneCounts[k] || 0;
    if (perZoneCounts[k] >= 3) continue;
    // probability scaled so each zone usually gets 1-3 posters across its buildings
    if (Math.random() > 0.55) continue;
    perZoneCounts[k]++;
    const faction = z.faction;
    const text = POSTER_LINES[faction][Math.floor(Math.random()*POSTER_LINES[faction].length)];
    const wallPick = Math.floor(Math.random()*3); // 0 bottom, 1 left, 2 right
    let x, y;
    if (wallPick === 0)      { x = b.x + 12 + Math.random()*(b.w-48); y = b.y + b.h - 30; }
    else if (wallPick === 1) { x = b.x + 4;                            y = b.y + 30 + Math.random()*(b.h-60); }
    else                     { x = b.x + b.w - 20;                     y = b.y + 30 + Math.random()*(b.h-60); }
    out.push({ x, y, w:16, h:24, faction, text });
  }
  state.posters = out;
}

export function drawPosters() {
  if (!state.posters || !state.posters.length) buildPosters();
  if (!state.posters) return;
  for (const p of state.posters) {
    if (!visibleWorldRect(p.x,p.y,p.w,p.h,12)) continue;
    const skin = POSTER_BG[p.faction] || POSTER_BG.street;
    // paper
    ctx.fillStyle = skin.bg;
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // torn-edge / nail accents
    ctx.fillStyle = 'rgba(0,0,0,.45)';
    ctx.fillRect(p.x, p.y, p.w, 1);
    ctx.fillRect(p.x, p.y+p.h-1, p.w, 1);
    // text
    ctx.fillStyle = skin.fg;
    ctx.font = 'bold 4px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) {
      ctx.fillText(lines[i], p.x+2, p.y+5 + i*4);
    }
  }
}

export function drawBorderGlow() {
  if (!state.borderGlowT || state.borderGlowT <= 0 || !state.borderGlowRect) return;
  const r = state.borderGlowRect;
  const alpha = Math.min(0.55, state.borderGlowT / 600 * 0.55);
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.strokeStyle = state.borderGlowColor || '#888';
  ctx.lineWidth = 3;
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  ctx.restore();
}

export function drawHideoutDoors() {
  for (const kind of ['scrap', 'mom']) {
    if (!hideoutOwned(kind)) continue;
    const d = HIDEOUT_DOORS[kind];
    const sx = d.x, sy = d.y;
    if (!visibleWorldRect(sx,sy,d.w,d.h,60)) continue;
    // door
    ctx.fillStyle = kind === 'mom' ? '#6a4a30' : '#4a3a28';
    ctx.fillRect(sx, sy, d.w, d.h);
    // panel
    ctx.fillStyle = kind === 'mom' ? '#8a6440' : '#5a4830';
    ctx.fillRect(sx+3, sy+4, d.w-6, d.h-8);
    // knob
    ctx.fillStyle = '#c8a060';
    ctx.fillRect(sx + d.w - 7, sy + d.h/2 - 1, 2, 2);
    // "(E)" hint if player close
    const ddx = (P.x+P.w/2) - (d.x+d.w/2), ddy = (P.y+P.h/2) - (d.y+d.h/2);
    if (ddx*ddx + ddy*ddy < 60*60) {
      ctx.fillStyle = 'rgba(0,0,0,.8)';
      ctx.fillRect(sx + d.w/2 - 10, sy - 14, 20, 12);
      ctx.fillStyle = '#e8c040';
      ctx.font = 'bold 10px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E)', sx + d.w/2, sy - 5);
      ctx.textAlign = 'left';
    }
  }
}

export function drawOfficeExterior(){
  const d=OFFICE_DOOR;if(!visibleWorldRect(4660,2860,520,390,40))return;
  const o=state.office||freshOfficeState(),owned=!!o.owned,claims=claimedDistrictIds().length,u=o.upgrades||{};
  // Door and lock. The building shell itself is canonical BUILDINGS geometry.
  ctx.fillStyle=owned?'#5a4028':'#2a211b';ctx.fillRect(d.x,d.y,d.w,d.h);
  ctx.fillStyle=owned?'#8a6840':'#3a3028';ctx.fillRect(d.x+3,d.y+4,d.w-6,d.h-8);
  ctx.fillStyle=owned?'#e8c040':'#77665a';ctx.fillRect(d.x+d.w-7,d.y+d.h/2,2,2);
  if(!owned){ctx.fillStyle='#0a0805';ctx.fillRect(d.x+8,d.y+13,8,8);ctx.fillStyle='#604020';ctx.fillRect(d.x+10,d.y+15,4,4);}
  // Sign grows from an old TAX HELP plate into a regional administrative mistake.
  const sign=claims>=11?'PAPER AUTHORITY':claims>=4?'REGIONAL OFFICE':owned?'THE OFFICE':'TAX HELP · NO TAX HELP';
  const sw=Math.max(150,sign.length*8+20),sx=4920-sw/2,sy=2890;
  ctx.fillStyle='#0a0805';ctx.fillRect(sx,sy,sw,22);ctx.strokeStyle=owned?'#e8c040':'#5a4838';ctx.strokeRect(sx+.5,sy+.5,sw-1,21);
  ctx.fillStyle=owned?'#d4c896':'#8a7868';ctx.font='bold 11px Courier New';ctx.textAlign='center';ctx.fillText(sign,4920,2905);ctx.textAlign='left';
  if(u.route_board){ctx.fillStyle='#d4c896';ctx.fillRect(5146,3128,28,34);ctx.fillStyle='#5a4028';ctx.fillRect(5152,3136,16,2);ctx.fillRect(5152,3143,16,2);ctx.fillRect(5152,3150,12,2);}
  if(u.locker){ctx.fillStyle='#384038';ctx.fillRect(4670,3130,30,46);ctx.strokeStyle='#171a17';ctx.strokeRect(4670.5,3130.5,29,45);ctx.fillStyle='#c08038';ctx.fillRect(4692,3152,3,3);}
  if(u.cot){ctx.fillStyle='#6a5840';ctx.fillRect(4652,3207,56,8);ctx.fillStyle='#29231c';ctx.fillRect(4656,3215,4,10);ctx.fillRect(4700,3215,4,10);}
  if(u.generator){ctx.fillStyle='#3a382f';ctx.fillRect(5160,3172,48,34);ctx.fillStyle='#c08038';ctx.fillRect(5168,3180,10,10);ctx.strokeStyle='#8a3a3a';ctx.beginPath();ctx.moveTo(5160,3188);ctx.lineTo(5122,3192);ctx.stroke();}
  if(u.radio){ctx.strokeStyle='#8a7868';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(5080,2920);ctx.lineTo(5102,2842);ctx.lineTo(5120,2920);ctx.stroke();ctx.fillStyle='#d06030';ctx.fillRect(5099,2838,6,6);}
  if(u.desk){ctx.fillStyle='rgba(212,200,150,.72)';for(let i=0;i<Math.min(6,1+claims);i++)ctx.fillRect(4750+i*12,2918-(i%2)*3,9,5);}
  if(claims>=1){ctx.fillStyle='#5a4830';ctx.fillRect(4720,3230,30,18);ctx.fillStyle='#d4c896';ctx.fillRect(4724,3233,22,4);}
  if(claims>=8){ctx.fillStyle='#8a3a3a';ctx.fillRect(4680,2876,480,6);ctx.fillStyle='#c08038';for(let x=4688;x<5150;x+=28)ctx.fillRect(x,2876,14,6);}
  const dx=(P.x+P.w/2)-(d.x+d.w/2),dy=(P.y+P.h/2)-(d.y+d.h/2);
  if(dx*dx+dy*dy<64*64){ctx.fillStyle='rgba(0,0,0,.82)';ctx.fillRect(4908,3186,24,13);ctx.fillStyle='#e8c040';ctx.font='bold 10px Courier New';ctx.textAlign='center';ctx.fillText('(E)',4920,3196);ctx.textAlign='left';}
}

export function drawClaimSites(){
  const sp=ENV_SPRITE_CACHE.claim_sign;if(!sp)return;
  for(const def of CLAIM_SITES){
    if(!(state.districtClaims&&state.districtClaims[def.id]))continue;
    const p=def.sign;if(!visibleWorldRect(p.x-20,p.y-34,40,44,20))continue;
    ctx.drawImage(sp,Math.round(p.x-16),Math.round(p.y-30),32,32);
    if(Math.hypot((P.x+P.w/2)-p.x,(P.y+P.h/2)-p.y)<100){
      ctx.fillStyle='rgba(0,0,0,.72)';ctx.fillRect(p.x-38,p.y-42,76,10);ctx.fillStyle='#d4c896';ctx.font='bold 7px Courier New';ctx.textAlign='center';ctx.fillText('THE OFFICE CLAIMS',p.x,p.y-34);ctx.textAlign='left';
    }
  }
}

export function init_structures() {
  // ---------- v10 building style + drawBuilding ----------
  BUILDING_STYLE = {
    PAWN:        { awning:'#a08030', sign:'PAWN',        signColor:'#e8c040', neon:'#fff080' },
    CORNER:      { awning:'#7a2018', sign:"TONY'S",      signColor:'#d06030', neon:'#ff6020' },
    CHURCH:      { awning:'#3a2840', sign:'',            signColor:'#d488d4', neon:'#d488d4', cross:true },
    LAUNDROMAT:  { awning:'#4858a0', sign:'WASH·DRY',   signColor:'#88c0ff', neon:'#a0d0ff' },
  };
  
  
  
  // v13 wave 6 — Procedural graffiti — placed once per save and persisted via state.graffiti.
  // v13 wave 8b — faction-themed: each building's tag is pulled from the pool matching the
  // zone the building sits in (street default = GRAFFITI_LINES, scrap = SCRAP_GRAFFITI_LINES,
  // spiritual = SPIRITUAL_GRAFFITI_LINES). Tag color is also faction-tinted.
  GRAFFITI_PALETTES = {
    street:    ['#a06868','#b8706e','#a87a80','#c08070'],   // muted red / pink chalk
    scrap:     ['#c08038','#a87038','#d09048','#a86028'],   // rust orange / metallic
    spiritual: ['#8898b8','#a8b0c8','#c0c0c0','#d0d8e0'],   // faded blue / chalk white
    neutral:   ['#a89878','#88a070','#a08070'],             // grey-green chalk
  };
  
  
  
  
  // v13 wave 8b — wall-mounted posters. 1-3 per faction-tagged zone, procedural per save.
  // Persisted in state.posters. Drawn between graffiti and props so they appear on walls,
  // below any prop overlays. Each poster has {x,y,w,h,faction,text,col,bg}.
  POSTER_LINES = {
    street: [
      "MISSING DOG\n(REWARD)",
      "WANTED\nLOOKS JUST\nLIKE YOU",
      "DJ DANGER\nPRESENTS\nA DJ NIGHT",
    ],
    scrap: [
      "CASH FOR\nCOPPER",
      "ASK ABOUT\nTHE PRICE",
      "PETE'S PAWN\nOPEN ALWAYS",
    ],
    spiritual: [
      "REPENT",
      "PRAYER MEETING\nTHURSDAYS",
      "THE CHURCH IS\nA BUILDING.\nTHE BUILDING\nIS A CHURCH.",
    ],
  };
  POSTER_BG = {
    street:    { bg:'#3a1818', fg:'#f0d8b0' },
    scrap:     { bg:'#2a1f10', fg:'#e8c878' },
    spiritual: { bg:'#1f1820', fg:'#d8d0e8' },
  };
  
  
  
  // v13 wave 8b — short border-glow flash on zone-faction crossings. timer is set in updateWorld,
  // rendered post-world (screen-space, but tinted in world-space rect).
  
  
  // v13 wave 7 — small wooden-door decal at each owned hideout. drawn in world space.
  
  
  
  
  
  
}

export function drawProps() {
  for (const p of PROPS) {
    // Full-bounds culling keeps long freight cars / fences visible when their anchor leaves screen.
    const pw=p.w||64, ph=p.h||64;
    if (!visibleWorldRect(p.x-32,p.y-64,pw+64,ph+96,16)) continue;
    drawProp(p);
  }
  // v13 wave 6 — interactive props pass (parallel array)
  for (const ip of interactiveProps) {
    if (!visibleWorldRect(ip.x-20,ip.y-20,40,40,16)) continue;
    drawInteractiveProp(ip);
  }
}

export function drawProp(p) {
  if (p.type === 'dumpster') {
    ctx.fillStyle = p.looted ? '#1a1810' : p.color;
    ctx.fillRect(p.x, p.y, p.w, p.h);
    ctx.strokeStyle = '#0a0805'; ctx.lineWidth = 2;
    ctx.strokeRect(p.x, p.y, p.w, p.h);
    // lid
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x-2, p.y-4, p.w+4, 4);
    // flies
    if (!p.looted) {
      ctx.fillStyle = '#222';
      const t = performance.now()/200;
      for (let i=0;i<3;i++) {
        const fx = p.x + 6 + Math.sin(t+i*2)*8;
        const fy = p.y - 10 + Math.cos(t*1.3+i)*4;
        ctx.fillRect(fx, fy, 2, 2);
      }
    }
    // label
    ctx.font = '8px Courier New';
    ctx.fillStyle = '#665';
    ctx.fillText('TRASH', p.x+2, p.y+14);
  }
  else if (p.type === 'cart') {
    if (p.mounted) return; // mounted on player
    ctx.fillStyle = '#888';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // grid pattern
    ctx.strokeStyle = '#444'; ctx.lineWidth = 1;
    for (let i=4; i<p.w; i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x+i, p.y); ctx.lineTo(p.x+i, p.y+p.h); ctx.stroke();
    }
    // handle
    ctx.fillStyle = '#666';
    ctx.fillRect(p.x-2, p.y-6, 28, 3);
    // wheels
    ctx.fillStyle = '#000';
    ctx.fillRect(p.x+2, p.y+p.h, 4, 4);
    ctx.fillRect(p.x+p.w-6, p.y+p.h, 4, 4);
    // glint
    ctx.fillStyle = '#ccc';
    ctx.fillRect(p.x+2, p.y+2, 2, 2);
  }
  else if (p.type === 'cart_husk') {
    // v19 cart cavalry scenery. Deliberately not rideable and never selected by cart interaction.
    ctx.save();
    ctx.translate(p.x+p.w/2,p.y+p.h/2);ctx.rotate(((p.x+p.y)%2?1:-1)*0.12);
    ctx.strokeStyle='#6f6a5a';ctx.lineWidth=2;ctx.strokeRect(-p.w/2,-p.h/2,p.w,p.h);
    ctx.strokeStyle='#3a372f';ctx.lineWidth=1;
    for(let i=-p.w/2+4;i<p.w/2;i+=5){ctx.beginPath();ctx.moveTo(i,-p.h/2);ctx.lineTo(i,p.h/2);ctx.stroke();}
    ctx.fillStyle='#111';ctx.fillRect(-p.w/2+1,p.h/2,4,3);ctx.fillRect(p.w/2-5,p.h/2,4,3);
    ctx.fillStyle='#8a3a3a';ctx.fillRect(-p.w/2-4,-p.h/2-3,p.w+4,2);
    ctx.restore();
  }
  else if (p.type === 'lamp') {
    // post
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y-30, 3, 30);
    // head
    ctx.fillStyle = '#5a4828';
    ctx.fillRect(p.x-5, p.y-36, 11, 8);
    // bulb glow during night (rendered in lighting pass)
    if (isNight()) {
      ctx.fillStyle = '#fff0a0';
      ctx.fillRect(p.x-2, p.y-32, 5, 4);
    }
  }
  else if (p.type === 'hydrant') {
    ctx.fillStyle = '#8a3a3a';
    ctx.fillRect(p.x-4, p.y-10, 8, 12);
    ctx.fillStyle = '#a04848';
    ctx.fillRect(p.x-6, p.y-12, 12, 4);
    ctx.fillStyle = '#5a2020';
    ctx.fillRect(p.x-6, p.y-2, 12, 4);
  }
  else if (p.type === 'mailbox') {
    ctx.fillStyle = '#1818a0';
    ctx.fillRect(p.x-6, p.y-12, 12, 12);
    ctx.fillStyle = '#0a0a60';
    ctx.fillRect(p.x-1, p.y, 2, 6);
  }
  else if (p.type === 'cone') {
    ctx.fillStyle = '#d06030';
    ctx.beginPath();
    ctx.moveTo(p.x, p.y-12);
    ctx.lineTo(p.x-5, p.y);
    ctx.lineTo(p.x+5, p.y);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#fff0a0';
    ctx.fillRect(p.x-3, p.y-7, 6, 2);
  }
  else if (p.type === 'trash') {
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-6, p.y-4, 12, 8);
    ctx.fillStyle = '#5a4030';
    ctx.fillRect(p.x-2, p.y-6, 4, 4);
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x+2, p.y-2, 2, 2);
  }
  else if (p.type === 'crate') {
    ctx.fillStyle = '#604020';
    ctx.fillRect(p.x, p.y, 24, 16);
    ctx.strokeStyle = '#3a2010';
    ctx.lineWidth = 1;
    for (let i=4;i<24;i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x+i, p.y); ctx.lineTo(p.x+i, p.y+16); ctx.stroke();
    }
    for (let i=4;i<16;i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x, p.y+i); ctx.lineTo(p.x+24, p.y+i); ctx.stroke();
    }
  }
  else if (p.type === 'syringe') {
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x-3, p.y, 7, 2);
    ctx.fillStyle = '#a08868';
    ctx.fillRect(p.x+4, p.y, 3, 2);
  }
  else if (p.type === 'bottle') {
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(p.x-3, p.y-2, 4, 6);
    ctx.fillStyle = '#5a7038';
    ctx.fillRect(p.x+1, p.y+1, 3, 2);
    ctx.fillStyle = '#a8c030';
    ctx.fillRect(p.x-4, p.y+4, 8, 1);
  }
  // v13 wave 6 — tent (makeshift, varied palette)
  else if (p.type === 'tent') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.35)';
    ctx.fillRect(p.x-2, p.y+14, 28, 4);
    // triangular tarp
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y-6);
    ctx.lineTo(p.x-2, p.y+16);
    ctx.lineTo(p.x+26, p.y+16);
    ctx.closePath();
    ctx.fill();
    // dark seam down center
    ctx.strokeStyle = 'rgba(0,0,0,.5)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y-6); ctx.lineTo(p.x+12, p.y+16);
    ctx.stroke();
    // patches / duct tape
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x+4, p.y+6, 5, 2);
    ctx.fillStyle = '#a08050';
    ctx.fillRect(p.x+18, p.y+10, 4, 2);
    // dark interior triangle (opening)
    ctx.fillStyle = '#0a0805';
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y+4);
    ctx.lineTo(p.x+6, p.y+16);
    ctx.lineTo(p.x+18, p.y+16);
    ctx.closePath();
    ctx.fill();
  }
  // v13 wave 6 — cardboard sign (held / propped, hand-scrawled marker text)
  else if (p.type === 'cardsign') {
    ctx.fillStyle = '#a08050';
    ctx.fillRect(p.x, p.y, 36, 22);
    // creases / cardboard texture
    ctx.fillStyle = '#604028';
    ctx.fillRect(p.x, p.y+10, 36, 1);
    ctx.fillRect(p.x+18, p.y, 1, 22);
    // text — scrawled black marker
    ctx.fillStyle = '#0a0805';
    ctx.font = 'bold 5px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x+2, p.y+6 + i*6);
  }
  // v13 wave 6 — scrap pile (twisted metal)
  else if (p.type === 'scrap_pile') {
    ctx.fillStyle = p.color || '#604020';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // top-edge glints
    ctx.fillStyle = '#a08040';
    ctx.fillRect(p.x+2, p.y+1, 4, 2);
    ctx.fillRect(p.x+p.w-8, p.y+2, 5, 2);
    // rebar sticks
    ctx.strokeStyle = '#a08060';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(p.x+4, p.y); ctx.lineTo(p.x+8, p.y-8);
    ctx.moveTo(p.x+p.w-6, p.y); ctx.lineTo(p.x+p.w-2, p.y-10);
    ctx.stroke();
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x+2, p.y+p.h, p.w-4, 3);
  }
  // v13 wave 6 — car wreck (totaled sedan, on blocks)
  else if (p.type === 'car_wreck') {
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.5)';
    ctx.fillRect(p.x, p.y+p.h, p.w, 4);
    // body
    ctx.fillStyle = p.color || '#5a3030';
    ctx.fillRect(p.x, p.y+6, p.w, p.h-10);
    // roof / cabin
    ctx.fillStyle = '#3a2020';
    ctx.fillRect(p.x+10, p.y, p.w-20, 10);
    // windows (smashed)
    ctx.fillStyle = '#181818';
    ctx.fillRect(p.x+12, p.y+2, p.w/2-14, 6);
    ctx.fillRect(p.x+p.w/2+2, p.y+2, p.w/2-14, 6);
    // missing wheels — sit on cinderblocks
    ctx.fillStyle = '#3a3a3a';
    ctx.fillRect(p.x+4, p.y+p.h-4, 6, 4);
    ctx.fillRect(p.x+p.w-10, p.y+p.h-4, 6, 4);
    // rust streaks
    ctx.fillStyle = 'rgba(140,60,20,.5)';
    ctx.fillRect(p.x+2, p.y+p.h/2, 1, p.h/2-4);
    ctx.fillRect(p.x+p.w-4, p.y+p.h/2, 1, p.h/2-4);
    // door dent
    ctx.fillStyle = 'rgba(0,0,0,.45)';
    ctx.fillRect(p.x+p.w/2-6, p.y+p.h/2, 12, 4);
  }
  // v13 wave 6 — leash post (dog is chained to this; rendered as small wooden post)
  else if (p.type === 'leash_post') {
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-2, p.y-10, 4, 12);
    ctx.fillStyle = '#604028';
    ctx.fillRect(p.x-3, p.y-12, 6, 3);
    // chain link nub
    ctx.fillStyle = '#888';
    ctx.fillRect(p.x-1, p.y-8, 2, 2);
  }
  // v13 wave 8a — TRAIN YARD: freight car (decorative, non-solid silhouette)
  else if (p.type === 'freight_car') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.55)';
    ctx.fillRect(p.x+4, p.y+p.h, p.w-8, 6);
    // body
    ctx.fillStyle = p.color || '#5a2a20';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // dark roof band
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x, p.y, p.w, 6);
    // rust streaks
    ctx.fillStyle = 'rgba(140,60,20,.45)';
    for (let i=14; i<p.w; i+=24) {
      ctx.fillRect(p.x+i, p.y+8, 1, p.h-14);
    }
    // sliding door outline (center)
    const doorW = 48;
    const doorX = p.x + p.w/2 - doorW/2;
    ctx.strokeStyle = 'rgba(0,0,0,.55)';
    ctx.lineWidth = 2;
    ctx.strokeRect(doorX, p.y+8, doorW, p.h-14);
    // dark "inside" through the door gap (where the hopper sleeps)
    ctx.fillStyle = '#080605';
    ctx.fillRect(doorX+3, p.y+11, doorW-6, p.h-20);
    // wheel trucks (small black blocks below)
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x+14,       p.y+p.h-2, 18, 5);
    ctx.fillRect(p.x+p.w-32,   p.y+p.h-2, 18, 5);
    // a faded paint stencil "RAILROAD" partial
    ctx.fillStyle = 'rgba(220,210,180,.18)';
    ctx.font = 'bold 7px Courier New';
    ctx.fillText('RA  ROAD', p.x+12, p.y+22);
  }
  // v13 wave 8a — TRAIN YARD: chalk message on a freight car side
  else if (p.type === 'chalk_message') {
    ctx.fillStyle = 'rgba(220,210,180,.72)';
    ctx.font = '7px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x, p.y + i*8);
    // smudge ghosting
    ctx.fillStyle = 'rgba(220,210,180,.22)';
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x+1, p.y+1 + i*8);
  }
  // v13 wave 8a — generic tall-weeds clump (park / train yard / old school)
  else if (p.type === 'weeds') {
    ctx.fillStyle = '#2a3818';
    ctx.fillRect(p.x-3, p.y, 1, 6);
    ctx.fillRect(p.x, p.y-2, 1, 8);
    ctx.fillRect(p.x+3, p.y-1, 1, 7);
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(p.x-2, p.y-3, 1, 3);
    ctx.fillRect(p.x+1, p.y-4, 1, 3);
    ctx.fillRect(p.x+4, p.y-3, 1, 2);
    // small base shadow
    ctx.fillStyle = 'rgba(0,0,0,.3)';
    ctx.fillRect(p.x-3, p.y+6, 8, 1);
  }
  // v13 wave 8a — THE PARK: stone fountain
  else if (p.type === 'fountain') {
    // base (octagonal-ish)
    ctx.fillStyle = '#6a655a';
    ctx.fillRect(p.x-20, p.y-4, 40, 18);
    ctx.fillStyle = '#5a554a';
    ctx.fillRect(p.x-22, p.y+10, 44, 4);
    // water in the basin
    const t = (Math.sin(performance.now()/600)+1)/2;
    ctx.fillStyle = `rgba(100,150,200,${0.45+t*0.18})`;
    ctx.fillRect(p.x-16, p.y, 32, 10);
    // center stem
    ctx.fillStyle = '#7a7568';
    ctx.fillRect(p.x-3, p.y-16, 6, 16);
    // upper bowl
    ctx.fillStyle = '#8a8578';
    ctx.fillRect(p.x-7, p.y-20, 14, 6);
    // a thin "spout" sparkle
    ctx.fillStyle = `rgba(200,220,240,${0.55+t*0.3})`;
    ctx.fillRect(p.x-1, p.y-22, 2, 4);
    // little base shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x-22, p.y+14, 44, 3);
  }
  // v13 wave 8a — THE PARK: bench (wood slats + iron frame)
  else if (p.type === 'park_bench') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.35)';
    ctx.fillRect(p.x+2, p.y+p.h, p.w-4, 3);
    // back rest
    ctx.fillStyle = '#5a4028';
    ctx.fillRect(p.x, p.y-8, p.w, 3);
    // seat
    ctx.fillStyle = '#6a4828';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // slat gaps
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x, p.y+3, p.w, 1);
    ctx.fillRect(p.x, p.y+7, p.w, 1);
    // iron legs
    ctx.fillStyle = '#2a2520';
    ctx.fillRect(p.x+1,       p.y, 2, p.h+4);
    ctx.fillRect(p.x+p.w-3,   p.y, 2, p.h+4);
    // (E) hint when close
    const ddx = (P.x+P.w/2) - (p.x+p.w/2), ddy = (P.y+P.h/2) - (p.y+p.h/2);
    if (ddx*ddx + ddy*ddy < 50*50 && !state.sittingOnBench) {
      ctx.fillStyle = '#e8c040';
      ctx.font = '8px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E) sit', p.x+p.w/2, p.y-14);
      ctx.textAlign = 'left';
    }
  }
  // v13 wave 8a — THE PARK / OLD SCHOOL: swing set silhouette
  else if (p.type === 'swing_set') {
    // night red tint flag (drawn after) — but base is universal
    // frame uprights
    ctx.fillStyle = '#3a3a44';
    ctx.fillRect(p.x,    p.y-26, 3, 28);
    ctx.fillRect(p.x+60, p.y-26, 3, 28);
    // crossbar
    ctx.fillRect(p.x, p.y-26, 64, 3);
    // chains + seats (two swings)
    ctx.strokeStyle = '#888';
    ctx.lineWidth = 1;
    ctx.beginPath();
    // gentle sway
    const s = Math.sin(performance.now()/1100)*1.5;
    ctx.moveTo(p.x+14+s,   p.y-23); ctx.lineTo(p.x+14+s,   p.y-8);
    ctx.moveTo(p.x+24+s,   p.y-23); ctx.lineTo(p.x+24+s,   p.y-8);
    ctx.moveTo(p.x+40-s,   p.y-23); ctx.lineTo(p.x+40-s,   p.y-8);
    ctx.moveTo(p.x+50-s,   p.y-23); ctx.lineTo(p.x+50-s,   p.y-8);
    ctx.stroke();
    // wooden seats
    ctx.fillStyle = '#5a3818';
    ctx.fillRect(p.x+12+s, p.y-8, 14, 2);
    ctx.fillRect(p.x+38-s, p.y-8, 14, 2);
    // night-only creepy red tint OR park-night tint (the park swings get it specifically)
    if (isNight()) {
      ctx.fillStyle = 'rgba(180,40,40,.18)';
      ctx.fillRect(p.x-2, p.y-30, 68, 36);
    }
  }
  // v13 wave 8a — THE PARK: drinking fountain (broken / dribbling)
  else if (p.type === 'drink_fountain') {
    ctx.fillStyle = '#5a554a';
    ctx.fillRect(p.x-5, p.y, 10, 12);
    ctx.fillStyle = '#6a655a';
    ctx.fillRect(p.x-7, p.y-2, 14, 4);
    // pipe nozzle
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y-5, 2, 4);
    // rust drip
    ctx.fillStyle = 'rgba(140,60,20,.6)';
    ctx.fillRect(p.x-1, p.y+2, 2, 6);
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.3)';
    ctx.fillRect(p.x-6, p.y+12, 12, 2);
  }
  // v13 wave 8a — THE PARK: tree (trunk + dark green canopy)
  else if (p.type === 'tree') {
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y+18, 14, 4, 0, 0, Math.PI*2);
    ctx.fill();
    // trunk
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-3, p.y, 6, 18);
    // canopy (layered)
    ctx.fillStyle = '#1f3a18';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y-12, 18, 16, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = '#2a4a20';
    ctx.beginPath();
    ctx.ellipse(p.x-2, p.y-14, 14, 12, 0, 0, Math.PI*2);
    ctx.fill();
    // highlight
    ctx.fillStyle = '#3a5a28';
    ctx.fillRect(p.x-6, p.y-20, 4, 3);
  }
  // v13 wave 8a — OLD SCHOOL: mural (faded letters, scraped)
  else if (p.type === 'school_mural') {
    ctx.fillStyle = 'rgba(40,30,20,.55)';
    ctx.fillRect(p.x-4, p.y-4, 200, 22);
    ctx.fillStyle = 'rgba(220,200,150,.45)';
    ctx.font = 'bold 11px Courier New';
    ctx.fillText(p.text || '', p.x, p.y+8);
    // scrape marks
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x+30, p.y, 4, 14);
    ctx.fillRect(p.x+80, p.y+2, 6, 12);
    ctx.fillRect(p.x+130, p.y+1, 3, 13);
  }
  // v13 wave 8a — OLD SCHOOL: broken basketball hoop
  else if (p.type === 'broken_hoop') {
    // pole
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y, 3, 40);
    // backboard
    ctx.fillStyle = '#a08868';
    ctx.fillRect(p.x-10, p.y-22, 24, 16);
    ctx.fillStyle = '#604030';
    ctx.fillRect(p.x-10, p.y-22, 24, 1);
    ctx.fillRect(p.x-10, p.y-7,  24, 1);
    // rim (bent down)
    ctx.strokeStyle = '#c08038';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(p.x+2, p.y-8, 6, 0, Math.PI);
    ctx.stroke();
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x-3, p.y+40, 6, 2);
  }
  // v13 wave 8a — OLD SCHOOL: chain-link fence (drawn as a thin horizontal band of "X" patterns)
  else if (p.type === 'school_fence') {
    ctx.strokeStyle = 'rgba(140,140,140,.6)';
    ctx.lineWidth = 1;
    for (let fx=0; fx<p.w; fx+=8) {
      ctx.beginPath();
      ctx.moveTo(p.x+fx,     p.y);
      ctx.lineTo(p.x+fx+8,   p.y+p.h);
      ctx.moveTo(p.x+fx+8,   p.y);
      ctx.lineTo(p.x+fx,     p.y+p.h);
      ctx.stroke();
    }
    // top + bottom rails
    ctx.fillStyle = '#666';
    ctx.fillRect(p.x, p.y, p.w, 1);
    ctx.fillRect(p.x, p.y+p.h-1, p.w, 1);
  }
  // v13 wave 8a — OLD SCHOOL: broken window (small dark rect on building face)
  else if (p.type === 'broken_window') {
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x, p.y, 14, 10);
    // jagged glass shards still in frame
    ctx.fillStyle = 'rgba(180,200,220,.45)';
    ctx.beginPath();
    ctx.moveTo(p.x,    p.y);
    ctx.lineTo(p.x+3,  p.y+5);
    ctx.lineTo(p.x,    p.y+10);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(p.x+14, p.y);
    ctx.lineTo(p.x+10, p.y+4);
    ctx.lineTo(p.x+14, p.y+10);
    ctx.closePath();
    ctx.fill();
  }
  // v13 wave 6 — pay phone (rings randomly; can answer with E)
  else if (p.type === 'pay_phone') {
    const ringing = state.phonePropRingT > 0;
    const sway = ringing ? Math.sin(performance.now()/40)*1.5 : 0;
    // pole
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y, 3, 24);
    // box
    ctx.fillStyle = '#2a3a5a';
    ctx.fillRect(p.x-10 + sway, p.y-22, 20, 26);
    // dial / receiver outline
    ctx.fillStyle = '#181818';
    ctx.fillRect(p.x-7 + sway, p.y-20, 14, 6);
    // coin slot
    ctx.fillStyle = '#88a0c0';
    ctx.fillRect(p.x-3 + sway, p.y-12, 6, 1);
    // receiver
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x-8 + sway, p.y-8, 4, 8);
    // rust accents
    ctx.fillStyle = 'rgba(140,60,20,.55)';
    ctx.fillRect(p.x-10 + sway, p.y-2, 4, 2);
    ctx.fillRect(p.x+6 + sway, p.y-16, 4, 2);
    // ring indicator: "?" floater above
    if (ringing) {
      const t = (Math.sin(performance.now()/120)+1)/2;
      ctx.fillStyle = '#e8c040';
      ctx.font = 'bold 14px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('?', p.x + sway, p.y - 32 - t*4);
      ctx.textAlign = 'left';
      // sound-wave rings
      ctx.strokeStyle = `rgba(232,192,64,${0.4 + t*0.4})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(p.x, p.y-12, 16 + t*6, 0, Math.PI*2);
      ctx.stroke();
    }
  }
}

export function drawInteractiveProp(p) {
  if (p.type === 'trashcan') {
    const rot = p.tipT > 0 ? Math.sin(p.tipT/30)*0.4 : 0;
    const scale = p.rotPulse > 0 ? 1.0 + (p.rotPulse/200)*0.2 : 1.0;
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(rot);
    ctx.scale(scale, scale);
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(-12, 14, 24, 4);
    // body (silver dented)
    ctx.fillStyle = '#5a5a5a';
    ctx.fillRect(-10, -16, 20, 30);
    // dents (vertical creases)
    ctx.fillStyle = '#3a3a3a';
    ctx.fillRect(-8, -14, 1, 26);
    ctx.fillRect(0, -14, 1, 26);
    ctx.fillRect(6, -14, 1, 26);
    // rim
    ctx.fillStyle = '#888';
    ctx.fillRect(-12, -18, 24, 4);
    // contents (when not on cooldown)
    if (p.cdT <= 0) {
      ctx.fillStyle = '#3a2818';
      ctx.fillRect(-8, -16, 16, 4);
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(-6, -16, 3, 2);
    }
    // empty marker
    if (p.cdT > 0) {
      ctx.fillStyle = 'rgba(0,0,0,.6)';
      ctx.fillRect(-10, -16, 20, 4);
    }
    ctx.restore();
    // tiny "(E)" hint floater when player is close
    const dx = (P.x+P.w/2) - p.x, dy = (P.y+P.h/2) - p.y;
    if (dx*dx + dy*dy < 50*50 && p.cdT <= 0) {
      ctx.fillStyle = '#e8c040';
      ctx.font = '8px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E) kick', p.x, p.y - 22);
      ctx.textAlign = 'left';
    }
  } else if (p.type === 'b_bottle') {
    if (p.broken) {
      // glass shards on ground
      ctx.fillStyle = 'rgba(180,200,220,.6)';
      ctx.fillRect(p.x-3, p.y, 2, 1);
      ctx.fillRect(p.x+1, p.y+1, 2, 1);
      ctx.fillRect(p.x-1, p.y-1, 1, 1);
    } else {
      // upright bottle — green
      ctx.fillStyle = '#3a6028';
      ctx.fillRect(p.x-2, p.y-7, 4, 9);
      ctx.fillStyle = '#5a8038';
      ctx.fillRect(p.x-2, p.y-7, 1, 9);
      // neck
      ctx.fillStyle = '#3a6028';
      ctx.fillRect(p.x-1, p.y-10, 2, 3);
      // cap
      ctx.fillStyle = '#888';
      ctx.fillRect(p.x-1, p.y-11, 2, 1);
    }
  }
}

export function init_render_props() {
  
  
  
  
  // v13 wave 6 — interactive prop render dispatcher (kickable trash, breakable bottles)
  
  
  
}

export let VISIBLE_NPC_BUFFER, NPC_IDLE_SPRITES, NPC_TWO_FRAME_SPRITES;

export function drawLighting() {
  const amount=nightAmount();
  if(amount<=.01)return;
  const octx=LIGHT_CTX;
  octx.globalCompositeOperation='source-over';
  octx.globalAlpha=1;
  octx.clearRect(0,0,W,H);
  octx.fillStyle=`rgba(0,0,0,${(.72*amount).toFixed(3)})`;
  octx.fillRect(0,0,W,H);
  octx.globalCompositeOperation='destination-out';
  for(const p of PROPS){
    if(p.type!=='lamp')continue;
    punchLightMask(octx,p.x-state.cam.x,p.y-32-state.cam.y,120,1,amount);
  }
  for(const l of WORLD_LIGHTS){
    if(l.office&&!(state.office&&state.office.upgrades&&state.office.upgrades.generator))continue;
    punchLightMask(octx,l.x-state.cam.x,l.y-state.cam.y,l.radius,l.power+.35,amount);
  }
  const px=P.x+P.w/2-state.cam.x,py=P.y+P.h/2-state.cam.y;
  punchLightMask(octx,px,py,P.rockedT>0?132:92,P.rockedT>0?1:.86,amount);
  octx.globalAlpha=1;octx.globalCompositeOperation='source-over';
  ctx.drawImage(LIGHT_MASK,0,0);

  // Colored cached glow sprites. Static gradients were built once at init.
  ctx.globalCompositeOperation='lighter';
  for(const p of PROPS){
    if(p.type!=='lamp')continue;
    const sx=p.x-state.cam.x,sy=p.y-32-state.cam.y,r=74;
    if(sx<-r||sx>W+r||sy<-r||sy>H+r)continue;
    ctx.globalAlpha=.72*amount;
    ctx.drawImage(LIGHT_GLOW_CACHE['255,210,120'],sx-r,sy-r,r*2,r*2);
  }
  for(const l of WORLD_LIGHTS){
    if(l.office&&!(state.office&&state.office.upgrades&&state.office.upgrades.generator))continue;
    const sx=l.x-state.cam.x,sy=l.y-state.cam.y,r=l.radius*.74;
    if(sx<-r||sx>W+r||sy<-r||sy>H+r)continue;
    ctx.globalAlpha=l.power*amount;
    const glow=LIGHT_GLOW_CACHE[l.rgb];
    if(glow)ctx.drawImage(glow,sx-r,sy-r,r*2,r*2);
  }
  ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';
}

export function drawWeather() {
  if (state.weather === 'rain') {
    ctx.strokeStyle = 'rgba(180,200,220,.5)';
    ctx.lineWidth = 1;
    const t = performance.now() / 30;
    for (let i=0;i<160;i++) {
      const x = ((i*73 + t) % W);
      const y = ((i*47 + t*1.4) % H);
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x-3, y+10);
      ctx.stroke();
    }
  }
  if (state.weather === 'fog') {
    // Cached fog sheet; reduce opacity at night so the player and boss telegraphs survive
    // the night + fog stack instead of disappearing into a gray-black slab.
    ctx.globalAlpha = .72 - nightAmount()*.18;
    ctx.drawImage(FOG_SHEET,0,0);
    ctx.globalAlpha = 1;
  }
}

export function resolveNpcPose(n, visualNow) {
  let frame = Number.isFinite(n.frame) ? n.frame : 0;
  let spriteKey = n.sprite;
  if (n.asleep && n.sprite === 'dave') {
    spriteKey = 'dave_sleep'; frame = Math.floor(visualNow/850)%2;
  } else if (n.isOmalleyFallen || n.id === 'omalley_fallen') {
    spriteKey = 'priest_fallen';
  } else if (n.sprite === 'tony' && (n.coatsOff||0)>0) {
    spriteKey = n.coatsOff>=3 ? 'tony_bare' : n.coatsOff===2 ? 'tony_coat_1' : 'tony_coat_2';
  } else if (n.sprite === 'scrap_dog' && n.chargeState === 'windup') {
    frame = 1;
  } else if (!n.aggro && !n.hostile && frame===0) {
    if(n.sprite==='scrap_dog') frame=(n.tailWag||0)>.25?Math.floor(visualNow/180)%2:0;
    else if (NPC_IDLE_SPRITES.has(n.sprite)) frame = Math.floor((visualNow + n.x*7 + n.y*3)/900)%2;
  }
  if(NPC_TWO_FRAME_SPRITES.has(spriteKey))frame=((frame%2)+2)%2;
  return { spriteKey, frame, bob:(n.frame===1||n.frame===2)?-1:0 };
}

export function drawNpc(n) {
  // body shadow — soft elliptical
  ctx.fillStyle = 'rgba(0,0,0,.45)';
  ctx.beginPath();
  ctx.ellipse(n.x+n.w/2, n.y+n.h-1, n.w/2, 3, 0, 0, Math.PI*2);
  ctx.fill();
  // sprite (with walk/identity frame). Bottom-center anchoring keeps 22px pedestrians,
  // 36px horse cops and 28px vendors aligned to their actual hitbox feet.
  const visualNow = state.visualNow || performance.now();
  const pose=resolveNpcPose(n,visualNow),frame=pose.frame,spriteKey=pose.spriteKey;
  const sp = SPRITE_CACHE[spriteKey+'_'+frame] || SPRITE_CACHE[spriteKey+'_0'];
  if (sp) {
    if (n.hitFlash) ctx.globalCompositeOperation = 'lighter';
    // tiny bob when walking
    const bob = pose.bob;
    const drawX = Math.round(n.x+n.w/2-16);
    const drawY = Math.round(n.y+n.h-32+bob);
    ctx.drawImage(sp, drawX, drawY, 32, 32);
    ctx.globalCompositeOperation = 'source-over';
  } else {
    ctx.fillStyle = n.color;
    ctx.fillRect(n.x, n.y, n.w, n.h);
  }
  // asleep "Z"
  if (n.asleep) {
    ctx.fillStyle = '#d4c896';
    ctx.font = '10px Courier New';
    const zT = Math.sin(performance.now()/600) * 2;
    ctx.fillText('z', n.x+n.w, n.y+zT);
    ctx.fillText('z', n.x+n.w+4, n.y-6-zT);
  }
  // Nameplates back away when they are not useful. Long cursed names wrap instead of
  // carpeting the roster; vendors and combat states remain explicit at any visible range.
  const pdx=(P.x+P.w/2)-(n.x+n.w/2), pdy=(P.y+P.h/2)-(n.y+n.h/2);
  const showName = n.vendor || n.hostile || n.aggro || (pdx*pdx+pdy*pdy)<260*260;
  if (showName) {
    ctx.font='9px Courier New';
    if(n._labelText!==n.name){
      const words=String(n.name||'').split(' '), lines=[''];
      for(const word of words){
        const last=lines.length-1, joined=(lines[last]+' '+word).trim();
        if(joined.length>17&&lines[last]&&lines.length<2)lines.push(word);else lines[last]=joined;
      }
      n._labelText=n.name;n._labelLines=lines;n._labelWidths=lines.map(line=>Math.ceil(ctx.measureText(line).width));
    }
    const labelLines=n._labelLines,labelWidths=n._labelWidths;
    ctx.textAlign='center';
    const cx=n.x+n.w/2, top=n.y-8-labelLines.length*10;
    for(let i=0;i<labelLines.length;i++){
      const line=labelLines[i], tw=labelWidths[i];
      ctx.fillStyle='rgba(10,8,5,.76)'; ctx.fillRect(Math.round(cx-tw/2-3),top+i*10-8,tw+6,10);
      ctx.fillStyle=(n.hostile||n.aggro)?'#d04040':'#d4c896'; ctx.fillText(line,cx,top+i*10);
    }
    ctx.textAlign='left';
  }
  // hp bar — graphical with frame
  if (n.showHp && n.hp < n.maxHp) {
    ctx.fillStyle = '#000';
    ctx.fillRect(n.x-1, n.y-5, n.w+2, 4);
    ctx.fillStyle = '#220';
    ctx.fillRect(n.x, n.y-4, n.w, 2);
    const hpRatio = n.hp/n.maxHp;
    const c = hpRatio > 0.6 ? '#a8c030' : hpRatio > 0.3 ? '#e8c040' : '#d04040';
    ctx.fillStyle = c;
    ctx.fillRect(n.x, n.y-4, n.w*hpRatio, 2);
  }
  // aggro "!"
  if (n.aggro) {
    const bounce = Math.sin(performance.now()/180) * 2;
    ctx.fillStyle = '#e8c040';
    ctx.font = 'bold 14px Courier New';
    ctx.fillText('!', n.x+n.w+2, n.y+8 + bounce);
  }
  // v13 wave 5 — charger windup telegraph: red tint + giant white "!" floating up
  if (n.chargeState === 'windup') {
    const pulse = (Math.sin(performance.now()/60)+1)/2;
    ctx.fillStyle = `rgba(208,64,64,${0.18 + pulse*0.22})`;
    ctx.fillRect(n.x-3, n.y-5, n.w+6, n.h+8);
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 18px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('!', n.x+n.w/2, n.y - 12 - pulse*4);
    ctx.textAlign = 'left';
  }
  // charger cooldown — soft panting visual
  if (n.chargeState === 'cooldown') {
    const t = (Math.sin(performance.now()/120)+1)/2;
    ctx.fillStyle = `rgba(208,192,160,${0.10 + t*0.10})`;
    ctx.fillRect(n.x-2, n.y-3, n.w+4, n.h+4);
  }
  // ranged / fallen-priest aim raise
  if (n.aimingThrow) {
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 10px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('*', n.x+n.w/2, n.y - 10);
    ctx.textAlign = 'left';
  }
  // cop radio (hand to ear)
  if (n.radioVisualT > 0) {
    ctx.fillStyle = '#88c0ff';
    ctx.font = 'bold 11px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('*', n.x+n.w/2 + 8, n.y - 6 + Math.sin(performance.now()/100)*1);
    ctx.textAlign = 'left';
  }
  // grabber freeze pose — small "✋" marker (text-safe fallback)
  if (n.grabFreezeT > 0) {
    ctx.fillStyle = '#d488d4';
    ctx.font = 'bold 12px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('-<', n.x+n.w/2, n.y - 12);
    ctx.textAlign = 'left';
  }
  // v13 wave 3 — unvisited-vendor "?" floater. fades on first dialogue open.
  // never on hostile or aggro'd npcs (would clash with the aggro "!" and read weird).
  // v13 wave 7 — also draw for npcs flagged with n.hasFloater (day event actors).
  if ((VENDOR_FLOATER_IDS.has(n.id) || n.hasFloater) && !state.metVendors.has(n.id) && !n.aggro && !n.hostile) {
    const bob = Math.sin(performance.now()/360 + (n.x*0.013)) * 2;
    const fy = n.y - 16 + bob;
    const fx = n.x + n.w/2;
    const sym = n.hasFloater || '?';
    const sz = n.hasFloater === '?' && n.isBusDriver ? 22 : 16;
    ctx.save();
    ctx.globalAlpha = 0.78;
    ctx.fillStyle = '#0a0805';
    ctx.font = `bold ${sz}px Courier New`;
    ctx.textAlign = 'center';
    ctx.fillText(sym, fx+1, fy+1);
    ctx.fillStyle = '#e8c040';
    ctx.fillText(sym, fx, fy);
    ctx.textAlign = 'left';
    ctx.restore();
  }
  // chatter bubble
  if (n.chatterT > 0 && n.chatter) {
    const tw = n.chatter.length * 5.4 + 8;
    ctx.fillStyle = 'rgba(0,0,0,.85)';
    ctx.fillRect(n.x+n.w/2 - tw/2, n.y-26, tw, 14);
    ctx.strokeStyle = '#665';
    ctx.lineWidth = 1;
    ctx.strokeRect(n.x+n.w/2 - tw/2, n.y-26, tw, 14);
    // tail
    ctx.fillStyle = 'rgba(0,0,0,.85)';
    ctx.beginPath();
    ctx.moveTo(n.x+n.w/2 - 3, n.y-12);
    ctx.lineTo(n.x+n.w/2 + 3, n.y-12);
    ctx.lineTo(n.x+n.w/2, n.y-7);
    ctx.fill();
    ctx.fillStyle = '#d4c896';
    ctx.font = '9px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText(n.chatter, n.x+n.w/2, n.y-16);
    ctx.textAlign = 'left';
  }
}

export function drawPlayer() {
  // shadow
  ctx.fillStyle = 'rgba(0,0,0,.5)';
  ctx.fillRect(P.x+2, P.y+P.h-2, P.w-4, 4);
  const dir = P.facing, f = P.frame;
  // Cached 16x16 cart underlay. It uses the same logical-pixel discipline as every body
  // instead of becoming a runtime rectangle costume when mounted.
  if (P.cartMounted) {
    const cart=SPRITE_CACHE['cart_underlay_'+dir];
    if(cart)ctx.drawImage(cart,P.x-4,P.y,32,32);
  }
  const playerDrawX=P.x-2,playerDrawY=P.y-4+(P.crashT>0?1:0);
  // rocked-up ghost trail (3 frames back, chromatic split)
  if (P.rockedT > 0) {
    const t = performance.now();
    // push trail history
    if (!P.trail) P.trail = [];
    P.trail.push({ x: P.x, y: P.y, dir, f });
    if (P.trail.length > 6) P.trail.shift();
    for (let i=0;i<P.trail.length-1;i++) {
      const tr = P.trail[i];
      const alpha = (i/P.trail.length) * 0.35;
      const sp = SPRITE_CACHE['playerhi_' + tr.dir + '_' + tr.f];
      if (sp) {
        ctx.globalAlpha = alpha;
        // RGB-shifted ghost trio (chromatic aberration)
        ctx.globalCompositeOperation = 'lighter';
        ctx.drawImage(sp, tr.x-2 + (i-3), tr.y-4, 32, 32);
        ctx.globalCompositeOperation = 'source-over';
      }
    }
    ctx.globalAlpha = 1;
  } else if (P.trail) {
    P.trail.length = 0;
  }
  const attackPhase=P.attacking>0?(P.attacking>80?0:1):0;
  const key = P.attacking>0
    ? (P.rockedT>0?'playerattackhi_':'playerattack_')+dir+'_'+attackPhase
    : (P.rockedT>0?'playerhi_':'player_')+dir+'_'+f;
  const sp = SPRITE_CACHE[key];
  if (sp) {
    const damageAlpha=(P.hitFlash > 0 || (P.iframes>0 && Math.floor(P.iframes/80)%2))?.5:1;
    // chromatic split when rocked
    if (P.rockedT > 0) {
      const shake = Math.sin(performance.now()/60) * 1.2;
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = 0.5*damageAlpha;
      ctx.drawImage(sp, playerDrawX + shake, playerDrawY, 32, 32);
      ctx.drawImage(sp, playerDrawX - shake, playerDrawY, 32, 32);
      ctx.globalCompositeOperation = 'source-over';
    }
    ctx.globalAlpha=damageAlpha;
    ctx.drawImage(sp, playerDrawX, playerDrawY, 32, 32);
    // Equipment is a stack of cached transparent 16x16-derived layers. Loot now changes
    // the avatar instead of only changing numbers in the inventory panel.
    const eq=P.equip||{};
    const drawGear=(slot)=>{
      const id=eq[slot];if(!id)return;const layer=SPRITE_CACHE['gear_'+id+'_'+dir];if(layer)ctx.drawImage(layer,playerDrawX,playerDrawY,32,32);
    };
    drawGear('coat');
    const patchTier=routePatchTier();
    if(patchTier){const patch=SPRITE_CACHE['route_patch_'+patchTier+'_'+dir];if(patch)ctx.drawImage(patch,playerDrawX,playerDrawY,32,32);}
    drawGear('shoes');drawGear('hat');drawGear('tool');
    // Attack phase 0 holds the item close; phase 1 commits the extended swing layer.
    const weaponState=P.attacking>0?attackPhase:0;
    const weapon=SPRITE_CACHE['weapon_'+(P.weapon||'fists')+'_'+dir+'_'+weaponState];
    if(weapon)ctx.drawImage(weapon,playerDrawX,playerDrawY,32,32);
    ctx.globalAlpha = 1;
  } else {
    ctx.fillStyle = '#604020';
    ctx.fillRect(P.x, P.y, P.w, P.h);
  }
  // rocked-up aura
  if (P.rockedT > 0) {
    ctx.strokeStyle = `rgba(232,192,64,${0.4 + Math.sin(performance.now()/120)*0.3})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(P.x+P.w/2, P.y+P.h/2, 22 + Math.sin(performance.now()/200)*2, 0, Math.PI*2);
    ctx.stroke();
    // pulsing inner ring
    ctx.strokeStyle = `rgba(255,240,180,${0.2 + Math.sin(performance.now()/80)*0.15})`;
    ctx.beginPath();
    ctx.arc(P.x+P.w/2, P.y+P.h/2, 16 + Math.sin(performance.now()/100)*1.5, 0, Math.PI*2);
    ctx.stroke();
  }
}

export function drawObjectiveGuide(){
  if(state.mode!=='playing'||!state.primaryObjective)return;
  const o=state.primaryObjective,sx=o.x-state.cam.x,sy=o.y-state.cam.y;
  const t=(state.visualNow||performance.now())/180,pulse=(Math.sin(t)+1)/2;
  ctx.save();ctx.lineWidth=2;ctx.strokeStyle=`rgba(232,192,64,${.62+pulse*.3})`;ctx.fillStyle='#e8c040';
  if(sx>24&&sx<W-24&&sy>36&&sy<H-30){
    const r=11+pulse*3;ctx.beginPath();ctx.arc(sx,sy,r,0,Math.PI*2);ctx.stroke();
    ctx.fillRect(Math.round(sx-2),Math.round(sy-r-8),4,4);
  }else{
    const cx=W/2,cy=H/2,ang=Math.atan2(sy-cy,sx-cx),ex=clamp(sx,24,W-24),ey=clamp(sy,42,H-34);
    ctx.translate(ex,ey);ctx.rotate(ang);ctx.beginPath();ctx.moveTo(10,0);ctx.lineTo(-7,-6);ctx.lineTo(-4,0);ctx.lineTo(-7,6);ctx.closePath();ctx.fill();
  }
  ctx.restore();
}

export function init_actors_weather() {
  // Lighting + weather overlay (rendered AFTER everything in world space)
  
  
  // Weather (rain)
  
  
  VISIBLE_NPC_BUFFER=[];
  NPC_IDLE_SPRITES = new Set(['barb','larry','phoneguy','math','pigeon','possum','scrap_dog']);
  NPC_TWO_FRAME_SPRITES = new Set(['dave_sleep','brutus','scrap_dog','os_brutus','horsecop','pigeon','possum']);
  // Pure visual-state selector: rendering can ask for a pose without changing simulation state.
  // This keeps animation decisions deterministic for screenshots, tests, and cached sprite reuse.
  
  
  
  
  
  
  
  
}

export let mm, mmctx;

export function drawMinimap() {
  const sx = 120/WORLD.w, sy = 96/WORLD.h;
  mmctx.fillStyle = '#000';
  mmctx.fillRect(0,0,120,96);
  // District color is the base layer. Roads, facades and rails must sit above it or an
  // expanded map still reads like disconnected colored rectangles.
  for (const z of ZONES) {
    mmctx.fillStyle = z.color;
    mmctx.fillRect(z.x*sx, z.y*sy, z.w*sx, z.h*sy);
  }
  mmctx.fillStyle = '#38352e';
  for (const r of ROAD_SEGMENTS) mmctx.fillRect(r.x*sx,r.y*sy,Math.max(1,r.w*sx),Math.max(1,r.h*sy));
  mmctx.fillStyle = '#171510';
  for (const f of LANDMARK_FACADES) mmctx.fillRect(f.x*sx,f.y*sy,Math.max(1,f.w*sx),Math.max(1,f.h*sy));
  mmctx.strokeStyle = '#6b6253'; mmctx.lineWidth = 1;
  for (const r of RAIL_LINES) {
    mmctx.beginPath(); mmctx.moveTo(r.x1*sx,r.y1*sy); mmctx.lineTo(r.x2*sx,r.y2*sy); mmctx.stroke();
  }
  // v18 owned forms: a gold outline means the office has a sign there, not that locals agree.
  mmctx.strokeStyle='#e8c040';mmctx.lineWidth=1;
  for(const id of claimedDistrictIds()){
    const z=ZONES.find(x=>x.id===id);if(z)mmctx.strokeRect(z.x*sx+.5,z.y*sy+.5,Math.max(1,z.w*sx-1),Math.max(1,z.h*sy-1));
  }
  // v19 clan authority is separate from office claims: rust while hostile, clan color when cleared.
  const clanClears={blue_tarp:'blueTarpCleared',cart_cavalry:'cartKeepCleared',copper_choir:'copperChoirCleared',throne:'throneDitchCleared'};
  const clanColors={blue_tarp:'#7890a0',cart_cavalry:'#d4c896',copper_choir:'#d06030',throne:'#e8c040'};
  for(const z of ZONES){
    if(!z.clan)continue;const cleared=!!(state.flags&&state.flags[clanClears[z.clan]]);
    mmctx.strokeStyle=cleared?clanColors[z.clan]:'#8a3a3a';mmctx.lineWidth=cleared?2:1;
    mmctx.strokeRect(z.x*sx+.5,z.y*sy+.5,Math.max(1,z.w*sx-1),Math.max(1,z.h*sy-1));
  }
  if(officeOwned()||(state.flags&&state.flags.theLotEntered)){
    mmctx.fillStyle=officeOwned()?'#e8c040':'#776';mmctx.fillRect(4920*sx-2,3210*sy-2,4,4);
  }
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    if (n.id==='tony') mmctx.fillStyle = '#d06030';
    else if (n.isCop) mmctx.fillStyle = '#5aa0ff';
    else if (n.hostile||n.aggro) mmctx.fillStyle = '#d04040';
    else mmctx.fillStyle = '#88aa66';
    mmctx.fillRect(n.x*sx-1, n.y*sy-1, 2, 2);
  }
  // one current bad idea. The same cached objective drives HUD, world guide and minimap.
  if(state.primaryObjective){
    const o=state.primaryObjective,ox=o.x*sx,oy=o.y*sy;
    mmctx.strokeStyle='#e8c040';mmctx.lineWidth=1;
    mmctx.strokeRect(Math.round(ox)-2,Math.round(oy)-2,5,5);
  }
  // player
  mmctx.fillStyle = '#e8c040';
  mmctx.fillRect(P.x*sx-1, P.y*sy-1, 3, 3);
  // viewport box
  mmctx.strokeStyle = 'rgba(232,192,64,.4)';
  mmctx.lineWidth = 1;
  mmctx.strokeRect(state.cam.x*sx, state.cam.y*sy, W*sx, H*sy);
}

export function init_minimap() {
  mm = document.getElementById('minimap');
  mmctx = mm.getContext('2d');
  
  
  
}

export function endingScreen(kind) {
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  const titleText = kind === 'kingdom' ? 'ONE CRACKLORD' : kind === 'coop' ? 'TUESDAYS AND THURSDAYS' : 'CRACK LORD SUPREME';
  const subText = kind === 'kingdom'
    ? 'the kingdom is four curbs and a ditch · the throne is a folding chair'
    : kind === 'coop'
      ? 'you and stripe split the corner · you get the slow days'
      : 'the corner is yours · you get tuesdays and thursdays';
  t.innerHTML = `
    <h1 style="color:#d06030;font-size:36px">${titleText}</h1>
    <div class="sub">${subText}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum still knows</div>`;
  // An ending is a receipt, not a save eraser. The route ledger survives the punchline.
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryInteract() {
  if(state.bossKind==='kingdom')return;
  // v18 headquarters is a separate door type; it never enters hideoutOwned(kind).
  if (tryEnterOffice()) return;
  // v13 wave 7 — hideout doors (E within 40px while owned). doors win over everything.
  if (tryEnterHideout()) return;
  // v13 wave 8a — old school door (E within 44px). modal interior dialogue (hideout pattern).
  // wave 8.6: now rank-gated (P.rank >= 3) inside tryEnterOldSchool.
  if (tryEnterOldSchool()) return;
  if (tryKingdomDoor()) return;
  if (tryUseKingdomTarget()) return;
  if (tryUseOfficeFieldTarget()) return;
  // v17 block-route stamps are authored away from NPC anchors. They sit after doors and
  // before the general scan so the prompt and the actual E action always agree.
  if (tryStampBlockRoute()) return;

  // v13 wave 8.6 — NPCs win over interactive props. closest-NPC-within-60px first.
  // before this lift, kickable trash / pay phone / dumpster / cart / bench all fired ahead
  // of the NPC scan, which routed E to a trash can when standing next to a vendor.
  // chain (post-doors): NPCs > heist trigger > interactive props (bench, trash, phone, cart,
  // dumpster) > zone-only verbs (smoke at block, panhandle at market).
  let bestNpc = null, bestNpcD = 60*60;
  for (const n of runtime.npcs) {
    if (n.dead || !n.interact) continue;
    const dx = (P.x+P.w/2) - (n.x+n.w/2), dy = (P.y+P.h/2) - (n.y+n.h/2);
    const d2 = dx*dx+dy*dy;
    if (d2 < bestNpcD) { bestNpcD = d2; bestNpc = n; }
  }
  if (bestNpc) {
    if (bestNpc.id === 'pete' && bestNpc.shopClosed) {
      toast("pete is sleeping inside.\n'we open at 6.'", 1800); return;
    }
    // v13 wave 3 — first-time interaction with a tracked vendor lifts the "?" floater
    // and adds them to the people-met index.
    if (VENDOR_FLOATER_IDS.has(bestNpc.id)) {
      const first = !state.metVendors.has(bestNpc.id);
      state.metVendors.add(bestNpc.id);
      if (first) saveGame();
      // intro_tony auto-completes the moment the player opens tony's dialogue
      if (bestNpc.id === 'tony' && state.quests.intro_tony && state.quests.intro_tony.available && !state.quests.intro_tony.done) {
        state.quests.intro_tony.done = true;
        P.cred += 1;
        questToast('THE MAN AT THE CORNER');
        toast("he charges ten dollars. that is the price.\nhe does not negotiate. sometimes he does.", 3400);
        if (state.quests.intro_smoke) state.quests.intro_smoke.available = true;
      }
    }
    bestNpc.interact(bestNpc);
    return;
  }

  // abandoned heist trigger — proximity to the locked building. NPCs already missed; this is
  // the highest-priority non-NPC interaction because it's the canonical late-game gate.
  const heistB = BUILDINGS.find(b=>b.locked);
  if (heistB) {
    const cx = P.x+P.w/2, cy = P.y+P.h/2;
    if (cx > heistB.x-20 && cx < heistB.x+heistB.w+20 && cy > heistB.y-20 && cy < heistB.y+heistB.h+20) {
      startHeist(); return;
    }
  }
  // v13 wave 8a — park bench sit toggle (E within 50px of any park_bench).
  if (tryParkBenchSit()) return;
  // v13 wave 6 — kickable trash cans (E within 50px). 50% cash / 20% junk / 30% rats.
  for (const ip of interactiveProps) {
    if (ip.type !== 'trashcan') continue;
    const ddx = (P.x+P.w/2) - ip.x, ddy = (P.y+P.h/2) - ip.y;
    if (ddx*ddx + ddy*ddy < 50*50) {
      if (ip.cdT > 0) { toast("the can is empty.\nyou kick it anyway.\nit barely moves.", 1500); return; }
      kickTrashCan(ip);
      return;
    }
  }
  // v13 wave 6 — pay phone answer (E within 30px while ringing)
  const phone = PROPS.find(p => p.type === 'pay_phone');
  if (phone) {
    const ddx = (P.x+P.w/2) - phone.x, ddy = (P.y+P.h/2) - phone.y;
    if (ddx*ddx + ddy*ddy < 38*38 && state.phonePropRingT > 0) {
      answerPublicPhone();
      return;
    }
  }
  // shopping cart mount/dismount
  const cart = PROPS.find(p => p.type==='cart');
  if (cart) {
    if (P.cartMounted) {
      // dismount near player
      const dx = (P.x+P.w/2) - cart.x, dy = (P.y+P.h/2) - cart.y;
      if (cart.mounted === 'me') {
        P.cartMounted = false; cart.mounted = false;
        cart.x = P.x + 4; cart.y = P.y + 8;
        applyEquipStats();
        toast('you abandon the cart.\nit rolls slightly. accuses you.', 1800);
        return;
      }
    } else {
      const dx = (P.x+P.w/2) - cart.x, dy = (P.y+P.h/2) - cart.y;
      if (dx*dx + dy*dy < 36*36) {
        P.cartMounted = true; cart.mounted = 'me';
        applyEquipStats();
        unlockAchievement('cart_baron');
        toast('+ shopping cart\n+1 speed. you can hit people now.', 2200);
        return;
      }
    }
  }
  // dumpster dive
  for (const p of PROPS) {
    if (p.type !== 'dumpster') continue;
    const dx = (P.x+P.w/2) - (p.x+p.w/2), dy = (P.y+P.h/2) - (p.y+p.h/2);
    if (dx*dx + dy*dy < 44*44) {
      if (p.looted) { toast('the dumpster is empty.\nyou look anyway.', 1500); return; }
      // tips jar bonus
      if (p.tipsJar) {
        p.tipsJar = false;
        P.cash += 8 + Math.floor(Math.random()*7);
        audio.coin();
        toast("there's a 'TIPS' jar duct-taped to the dumpster.\nit has cash in it.\n+ $"+ (8 + Math.floor(Math.random()*7))+"\n(then there's the rest of the dumpster.)", 3000);
      }
      startDumpsterDive(p);
      return;
    }
  }
  // smoke at block — open menu (zone verb, fires only when no NPC / prop took the E)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'block')) {
    blockMenu();
    return;
  }
  // panhandling at marketplace — easy money (zone verb, NPC scan already missed)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'market')) {
    panhandle();
    return;
  }
}

export function startDumpsterDive(dumpster) {
  state.mode = 'dialogue';
  const items = [];
  const trashPool = [
    {n:'half a chimichanga', q:'eat', heal:12},
    {n:'a wet sock', q:'sell', val:2},
    {n:'a license plate', q:'item', id:'license'},
    {n:'a hot pocket sleeve', q:'sell', val:3},
    {n:'a tooth (gold)', q:'sell', val:18},
    {n:'a strange shoe', q:'equip', id:'crocs'},
    {n:'a parka in august', q:'equip', id:'parka'},
    {n:'a single airpod', q:'equip', id:'airpods'},
    {n:'a mesh hat', q:'equip', id:'mesh_cap'},
    {n:'a cowboy hat', q:'equip', id:'cowboy'},
    {n:'a hotel bathrobe', q:'equip', id:'bathrobe'},
    {n:'a windbreaker', q:'equip', id:'windbreaker'},
    {n:'a ski mask in june', q:'equip', id:'ski_mask'},
    {n:'a tiny construction helmet', q:'equip', id:'helmet'},
    {n:'a trench coat (one of three)', q:'equip', id:'trench'},
    {n:'a flashlight (dead)', q:'item'},
    {n:'a receipt', q:'item'},
    {n:'a lottery ticket (unscratched)', q:'item', id:'lottery'},
    {n:"someone's wallet ($15)", q:'cash', val:15},
    {n:"a stack of singles ($8)", q:'cash', val:8},
    {n:'a possum (alive)', q:'event', what:'possum'},
    {n:"someone's wedding ring", q:'sell', val:22},
  ];
  // v13 wave 6 — bias by distance from THE BLOCK center (1050, 840).
  // close dumpsters lean toward nothing; far dumpsters carry the loot table.
  const blockCx = 1050, blockCy = 840;
  const dDist = Math.sqrt((dumpster.x-blockCx)**2 + (dumpster.y-blockCy)**2);
  const farFactor = Math.min(1, dDist / 900); // 0 = next to block, 1 = max distance
  // table: 30% nothing, 30% $1-4, 20% junk, 10% clean packet, 8% broken bottle, 2% propane (one-and-done)
  // bias: closer dumpsters get higher nothing chance.
  const r = Math.random();
  const noNothingBoost = farFactor * 0.6; // far dumpsters have less "nothing"
  const noneCut = 0.30 + (1 - farFactor) * 0.20; // close = 50% nothing, far = 30%
  let lootPicked = null;
  if (r < noneCut) {
    lootPicked = {n:'nothing. dumpsters know.', q:'rats'};
  } else if (r < noneCut + 0.30) {
    lootPicked = {n:"$"+(1+Math.floor(Math.random()*4))+' in loose bills', q:'cash', val: 1+Math.floor(Math.random()*4)};
  } else if (r < noneCut + 0.50) {
    lootPicked = {n:'a piece of junk (sells $1)', q:'junkdrop'};
  } else if (r < noneCut + 0.60) {
    lootPicked = {n:'a clean packet of supply', q:'clean_packet'};
  } else if (r < noneCut + 0.68) {
    lootPicked = {n:'a broken bottle (weapon)', q:'bb_weapon'};
  } else {
    // remaining slice (~32% buffer) — propane only if far enough AND not already awarded
    if (farFactor > 0.6 && !hasPropane() && !state.flags.dumpsterPropaneAwarded && Math.random() < 0.07) {
      lootPicked = {n:'a propane torch (dented)', q:'torch_drop'};
    } else {
      // fall back to a random standard item from the trashPool
      lootPicked = trashPool[Math.floor(Math.random()*trashPool.length)];
    }
  }
  // 2 random fillers + the loot-table pick
  for (let i=0;i<2;i++) items.push(trashPool[Math.floor(Math.random()*trashPool.length)]);
  items.push(lootPicked);
  dialogue('THE DUMPSTER', "you are inside a dumpster.\nyou find three things.\nyou can take one.", items.map((it,idx) => ({
    label: it.n + (it.q==='sell'?' (sell)':it.q==='eat'?' (eat)':it.q==='cash'?' (take)':it.q==='equip'?' (wear)':''),
    action: () => {
      if (it.q === 'eat') { P.hp = Math.min(P.maxHp, P.hp + (it.heal||5)); toast('+ '+it.heal+' hp\n(it tastes like the dumpster.)'); }
      else if (it.q === 'sell') { const v = it.val || (3 + Math.floor(Math.random()*4)); P.cash += v; toast('+ $'+v+'\n('+it.n+'.)'); audio.coin(); }
      else if (it.q === 'cash') { P.cash += it.val; audio.coin(); toast('+ $'+it.val+'\n('+it.n+'.)'); }
      else if (it.q === 'item') { P.inventory.push({id: it.id||it.n.replace(/\W/g,''), n: it.n, q: 1}); toast('+ '+it.n); }
      else if (it.q === 'equip' && it.id && EQUIPMENT[it.id]) {
        const slot = EQUIPMENT[it.id].slot;
        P.equip[slot] = it.id; applyEquipStats();
        toast('+ EQUIPPED · '+EQUIPMENT[it.id].n);
      }
      else if (it.q === 'event' && it.what === 'possum') {
        toast("a possum.\nhe is annoyed.\nhe leaves through the lid.");
        possumDialogue();
      }
      // v13 wave 6 — new loot-table outcomes
      else if (it.q === 'rats') {
        toast("the rats are upset.\nthey have lives.", 2000);
        for (let i=0;i<10;i++) particles.push({x:dumpster.x+Math.random()*dumpster.w, y:dumpster.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-0.5, life:600, c:'#181010', sz:2});
      }
      else if (it.q === 'junkdrop') {
        P.inventory.push({id:'junk', n:'a piece of junk', q:1});
        toast("+ a piece of junk.\n(pete will take it. for one dollar.)", 2200);
      }
      else if (it.q === 'clean_packet') {
        P.supplies = (P.supplies||0) + 1;
        toast("+ a clean packet.\n(unmarked. you take it. you don't ask.)", 2400); audio.coin();
      }
      else if (it.q === 'bb_weapon') {
        pickupWeapon('broken_bottle');
        toast("+ a broken bottle.\nit cuts. you understand this.\n(weapon equipped.)", 2600);
      }
      else if (it.q === 'torch_drop') {
        if (!hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          state.flags.dumpsterPropaneAwarded = true;
          toast("+ a propane torch (dented).\nsomebody buried this.\n(equipped.)", 4400);
          feedPost("found a torch in a dumpster. the dumpster knew.", '@crackheadcent');
        } else {
          toast("a torch. you already have one.\nyou close the lid.", 2000);
        }
      }
      dumpster.looted = true;
      dumpster.diveCdT = 90000; // v13 wave 6 — 90s cooldown per dumpster after a dig
      state.counters.dumpDives = (state.counters.dumpDives||0) + 1;
      saveGame();
    }
  })).concat([{label:'climb out.', action:()=>{ dumpster.looted = true; toast('you climb out.\nno one saw.\n(some saw.)'); }}]));
}

export function kickTrashCan(can) {
  can.cdT = 60000;
  can.tipT = 200;
  can.rotPulse = 200;
  audio.kick ? audio.kick() : audio.hit();
  state.shake = Math.max(state.shake, 3);
  const r = Math.random();
  if (r < 0.5) {
    // cash $2-5
    const amt = 2 + Math.floor(Math.random()*4);
    P.cash += amt;
    audio.coin();
    toast("- nothing\n+ $"+amt+"\nthe can falls. coins spill.", 2200);
    // particles for cash poof
    for (let i=0;i<6;i++) particles.push({x:can.x, y:can.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-1, life:600, c:'#e8c040', sz:3, glow:true});
  } else if (r < 0.7) {
    // junk
    P.inventory.push({id:'junk', n:'a piece of junk', q:1});
    toast("+ a piece of junk.\npete will take it. for one dollar.", 2400);
  } else if (r < 0.8) {
    // food (10% bonus drop)
    P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});
    toast("+ a can of food (unmarked).\nthe label is in a language.\nthe language is not yours.", 2600);
  } else {
    // rats
    toast("the rats are upset. they have lives.", 2000);
    for (let i=0;i<8;i++) particles.push({x:can.x+(Math.random()-.5)*16, y:can.y, vx:(Math.random()-.5)*4, vy:-Math.random()*2-0.5, life:700, c:'#181010', sz:2});
  }
  saveGame();
}

export function answerPublicPhone() {
  state.phonePropRingT = 0;
  state.publicPhoneAnswered = (state.publicPhoneAnswered||0) + 1;
  audio.dialogue();
  const line = PUBLIC_PHONE_LINES[Math.floor(Math.random()*PUBLIC_PHONE_LINES.length)];
  toast("📞 PUBLIC PHONE\n\n"+line.text, 6000);
  if (line.action) line.action();
  if (state.publicPhoneAnswered >= 5) unlockAchievement('phone_booth_prophet');
  saveGame();
}

export function init_ending_interactions() {
  // ---------- ENDING ----------
  
  
  // ---------- INTERACT ----------
  
  
  // ---------- DUMPSTER DIVE ----------
  // v13 wave 6 — distance-from-block biases the loot. far dumpsters can drop a propane torch (rare).
  
  
  // v13 wave 6 — kickable trash. RNG outcome + 60s cooldown + tip-over anim.
  
  
  // v13 wave 6 — answer the public pay phone. randomly picks a PUBLIC_PHONE_LINE.
  
  
  
}

export let DAILY_COUNTER_KEYS, HIDEOUT_DOORS;

export function resetDailyCounters() {
  for (const k of DAILY_COUNTER_KEYS) state.counters[k] = 0;
  // v18 office capacity shares the authoritative dawn path used by world and sleep actions.
  if (state.office) syncOfficeDay();
  if(state.kingdom)syncKingdomForces();
}

export function fireDayEvents() {
  if (!state.flags) state.flags = {};
  if (state.day === 3 && !state.flags.day3Fired)   fireDay3Visit();
  if (state.day === 7 && !state.flags.day7Fired)   fireDay7Silence();
  if (state.day === 14 && !state.flags.day14Fired) fireDay14Inheritance();
  if (state.day === 30 && !state.flags.day30Fired) fireDay30Bus();
}

export function rehydrateDay30Bus() {
  if (!state.flags) return;
  if (!state.flags.day30Fired || state.flags.busTaken || state.flags.busRefused) return;
  if (runtime.npcs.find(n => n.id === 'bus_driver')) return;
  // re-run fireDay30Bus without re-firing the broadcast, by temporarily clearing the flag and restoring.
  state.flags.day30Fired = false;
  fireDay30Bus();
}

export function fireDay3Visit() {
  state.flags.day3Fired = true;
  // spawn passive "someone you don't know" near the player. wanders off after the encounter.
  const id = 'day3_visitor_' + Date.now();
  const visitor = {
    id, name: "SOMEONE YOU DON'T KNOW", sprite: 'lurch',
    x: P.x + 80, y: P.y + 30, w: 24, h: 28, color: '#3a3030',
    hp: 30, maxHp: 30, speed: 0.6, hostile: false, archetype: 'passive',
    isDay3Visitor: true, hasFloater: '?',
    interact: (n) => dialogue("SOMEONE YOU DON'T KNOW",
      "someone you don't know.\nthey say:\n\n'i heard about you.'\n\nthat's all they say.",
      [{ label: 'leave.', action: () => { n.wanderOff = true; n.speed = 1.2; n.targetX = WORLD.w + 80; n.targetY = n.y; }}]),
  };
  visitor.x = Math.max(40, Math.min(WORLD.w - 40, visitor.x));
  visitor.y = Math.max(40, Math.min(WORLD.h - 40, visitor.y));
  runtime.npcs.push(visitor);
  toast("someone you don't know is on the block today.\nthey are not moving.\nthey are watching.", 4200);
  feedPost("someone was on the block today. someone was watching.", '@crackheadcent');
  saveGame();
}

export function fireDay7Silence() {
  state.flags.day7Fired = true;
  state.flags.silenceUntilT = Date.now() + 4 * 60 * 1000; // 4 in-game minutes (real-time, since dayTime is real-time)
  toast("the radio is off.\nthe phones are off.\nthe city is listening to something.", 5400);
  // we don't broadcast or post — that's the point.
  saveGame();
}

export function fireDay14Inheritance() {
  state.flags.day14Fired = true;
  // spawn a $500 pile in player's current zone area (near player, jittered, clamped to world)
  const px = P.x + (Math.random()-.5) * 320;
  const py = P.y + (Math.random()-.5) * 320;
  runtime.cashPiles.push({
    id: 'cp_inheritance_' + Date.now(),
    x: Math.max(40, Math.min(WORLD.w-40, px)),
    y: Math.max(40, Math.min(WORLD.h-40, py)),
    amt: 500, isInheritance: true, collected: false,
  });
  toast("something arrived today.\nyou don't know what.\nyou will, when you find it.", 4200);
  saveGame();
}

export function fireDay30Bus() {
  state.flags.day30Fired = true;
  if (state.flags.busTaken || state.flags.busRefused) return; // already resolved
  // bus stop is where pinky stands (per VENDOR_INDEX_META). spawn the driver a few tiles south.
  let bx = 1330, by = 1260;
  const driver = {
    id: 'bus_driver', name: 'THE BUS DRIVER', sprite: 'lurch',
    x: bx, y: by, w: 24, h: 28, color: '#1a2a3a',
    hp: 60, maxHp: 60, speed: 0, hostile: false, archetype: 'passive',
    isBusDriver: true, hasFloater: '?',
    interact: (n) => dialogue('THE BUS DRIVER',
      "the bus is here.\nit hasn't been here in a while.\nthe driver looks at you.\n\nare you getting on?",
      [
        { label: 'yes. get on the bus.', action: () => takeTheBus() },
        { label: 'no. not today.', action: () => {
          state.flags.busRefused = true;
          const idx = runtime.npcs.findIndex(x => x.id === 'bus_driver'); if (idx >= 0) runtime.npcs.splice(idx, 1);
          toast("the bus leaves.\nit doesn't come back.\nthat was your chance.", 5200);
          feedPost("the bus left. someone watched it leave.", '@crackheadcent');
          saveGame();
        }},
      ]),
  };
  runtime.npcs.push(driver);
  toast("a bus is at the stop.\nit hasn't been there in a while.\nthe driver is looking at you.", 5400);
  feedPost("the bus is back. it does not come back often.", '@crackheadcent');
  saveGame();
}

export function takeTheBus() {
  state.flags.busTaken = true;
  const driverIdx=runtime.npcs.findIndex(n=>n.id==='bus_driver');if(driverIdx>=0)runtime.npcs.splice(driverIdx,1);
  unlockAchievement('the_bus');
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  t.innerHTML = `
    <h1 style="color:#6080a0;font-size:32px">THE BUS</h1>
    <div class="sub">you got on the bus.<br>the bus left.<br>you survived rock bottom.<br>the bus has a destination. it has not told you.</div>
    <div class="sub" style="margin-top:14px;opacity:.6">days: ${state.day} · rocks smoked: ${P.lifetime.rocksSmoked||0} · cred: ${P.cred|0}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum stayed</div>`;
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryEnterOffice(){
  const d=OFFICE_DOOR,dx=(P.x+P.w/2)-(d.x+d.w/2),dy=(P.y+P.h/2)-(d.y+d.h/2);
  if(dx*dx+dy*dy>=44*44)return false;
  if(officeOwned())openOffice();
  else dialogue('THE OFFICE','the key does not fit.\nthe door has one lock and three opinions.\nthe leasing guy is standing somewhere in the lot.',[
    {label:'look toward the leasing guy.',action:()=>toast('east side of the lot.\nclipboard. key ring. no urgency.',2200)},
    {label:'leave.',action:()=>{}},
  ]);
  return true;
}

export function officeUpgradeCount(){const o=state.office||freshOfficeState();return OFFICE_UPGRADE_DEFS.filter(d=>o.upgrades&&o.upgrades[d.id]).length;}

export function openOffice(){
  const o=ensureOfficeState();syncOfficeDay();updateOfficeMilestones();maybeUnlockKingdom(false,true);syncKingdomQuests();
  const claims=claimedDistrictIds().length,cap=officeDailyCap(),opts=[];
  if(o.claimJob&&o.claimJob.stage==='file'){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
    opts.push({label:can?'file '+d.name.toLowerCase()+'. $'+cost+' + 1 copper.':'filing needs $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openOffice();}});
  }
  if(o.workJob&&o.workJob.stage==='file'){
    const capBlocked=o.workToday>=cap;
    opts.push({label:capBlocked?'daily ledger closed. inspected order waits for morning.':'file work order '+o.workJob.serial+'. collect the net.',disabled:capBlocked,action:()=>{fileOfficeWork();openOffice();}});
  }
  opts.push({label:o.upgrades.desk?(o.claimJob?'open the active claim file.':'open district claims. ('+claims+'/'+CLAIM_SITES.length+')'):'district claims need a desk.',disabled:!o.upgrades.desk,action:()=>openClaimLedger(0)});
  const workLabel=!o.upgrades.radio?'work orders need a radio.'
    :o.workJob?'work order '+o.workJob.serial+' is '+o.workJob.stage+'.'
    :!claims?'work orders need one claimed district.'
    :o.workToday>=cap?'work orders closed today. ('+o.workToday+'/'+cap+')'
    :'take a work order. ('+o.workToday+'/'+cap+' filed today)';
  opts.push({label:workLabel,disabled:!o.upgrades.radio||!!o.workJob||!!o.claimJob||!claims||o.workToday>=cap,action:()=>{startOfficeWork();}});
  if(state.kingdom&&state.kingdom.stage!=='locked'){
    opts.push({label:state.kingdom.stage==='summons'?'open the hostile correspondence.':'open the CURB WAR ledger.',action:()=>openKingdomLedger()});
  }
  opts.push({label:'look at office upgrades. ('+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+')',action:()=>openOfficeUpgrades()});
  opts.push({label:o.upgrades.locker?'open the chained locker.':'locker not installed.',disabled:!o.upgrades.locker,action:()=>openHideoutChest('office')});
  opts.push({label:o.upgrades.cot?'use the cot.':'cot not installed.',disabled:!o.upgrades.cot,action:()=>openOfficeCot()});
  const rerollBlocked=!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract();
  opts.push({label:!o.upgrades.route_board?'route board not installed.':o.rerollDay===state.day?'route board used today.':'replace the current block route. (no payout)',disabled:rerollBlocked,action:()=>rerollBlockRouteAtOffice()});
  opts.push({label:'leave the office.',action:()=>{}});
  dialogue('THE OFFICE','one room. one lock. '+claims+' district'+(claims===1?'':'s')+' entered in pen.\nupgrades: '+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+'. orders filed: '+o.jobsCompleted+'.\nthe smell has seniority.',opts);
}

export function openOfficeUpgrades(){
  const o=ensureOfficeState();
  const opts=OFFICE_UPGRADE_DEFS.map(d=>{
    const owned=o.upgrades[d.id],can=P.cash>=d.cash&&P.copper>=d.copper;
    const price='$'+d.cash+(d.copper?' + '+d.copper+' copper':'');
    return {label:owned?'✓ '+d.name+' installed.':d.name+' · '+price+' · '+d.desc,disabled:owned||!can,action:()=>{purchaseOfficeUpgrade(d.id);openOfficeUpgrades();}};
  });
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('OFFICE IMPROVEMENTS','a legal pad is taped to the wall.\nthe legal pad is not legal advice.\ncash $'+P.cash+' · pure copper '+P.copper+'.',opts);
}

export function openClaimLedger(page=0){
  const o=ensureOfficeState();if(!o.upgrades.desk){openOffice();return;}
  if(o.claimJob){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],stage=o.claimJob.stage;
    const lines=stage==='survey'?d.survey.task:stage==='file'?'survey attached. filing fee pending.':d.sign.task;
    const opts=[];
    if(stage==='file'){
      const cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
      opts.push({label:can?'file now. $'+cost+' + 1 copper.':'need $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openClaimLedger(0);}});
    }
    opts.push({label:stage==='install'?'cancel the claim. (no refund)':'cancel the claim.',action:()=>{cancelDistrictClaim();openOffice();}});
    opts.push({label:'back to the office.',action:()=>openOffice()});
    dialogue('ACTIVE CLAIM · '+d.name,'stage: '+stage+'.\n'+lines,opts);return;
  }
  if(o.workJob){dialogue('DISTRICT CLAIMS','the desk is occupied by work order '+o.workJob.serial+'.\nfinish the order before opening another file.',[{label:'back.',action:()=>openOffice()}]);return;}
  const pageSize=7,maxPage=Math.floor((CLAIM_SITES.length-1)/pageSize);page=Math.max(0,Math.min(maxPage,page));
  const slice=CLAIM_SITES.slice(page*pageSize,page*pageSize+pageSize),opts=slice.map(d=>{
    const why=claimGateReason(d),owned=(state.districtClaims||{})[d.id];
    return {label:owned?'✓ '+d.name+' · entered in pen.':why?d.name+' · '+why:d.name+' · open a survey file.',disabled:!!why,action:()=>selectDistrictClaim(d.id)};
  });
  if(page<maxPage)opts.push({label:'next ledger page.',action:()=>openClaimLedger(page+1)});
  if(page>0)opts.push({label:'previous ledger page.',action:()=>openClaimLedger(page-1)});
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('DISTRICT CLAIMS · PAGE '+(page+1),'the form recognizes signs, curbs, and faction permission.\nstreet '+((P.faction&&P.faction.street)||0)+' · scrap '+((P.faction&&P.faction.scrap)||0)+' · spiritual '+((P.faction&&P.faction.spiritual)||0)+'.',opts);
}

export function openOfficeCot(){
  const o=ensureOfficeState(),powered=!!o.upgrades.generator;
  dialogue('THE COT','the cot is one inch shorter than you.\nthis has been entered as adequate.',[
    {label:'rest 30 minutes. (+'+(powered?18:10)+' hp'+(powered?' · +5 brain':'')+' · -1 wanted)',action:()=>{P.hp=Math.min(P.maxHp,P.hp+(powered?18:10));P.brain=Math.min(100,P.brain+(powered?5:0));P.wanted=Math.max(0,P.wanted-1);toast('the generator clicks.\nthe cot files no complaint.',2400);saveGame();}},
    {label:'sleep until morning. (+55 hp · +25 brain · +15 shakes)',action:()=>sleepAtOffice()},
    {label:'back to the office.',action:()=>openOffice()},
  ]);
}

export function sleepAtOffice(){
  const target=state.dayTime>0.3?1.3:0.3;state.dayTime=target;
  if(state.dayTime>=1){state.dayTime-=1;state.day++;P.lifetime.dayCount=state.day;rollWeather();resetDailyCounters();rollHustles();fireDayEvents();if(state.day>=7)unlockAchievement('tuesday_again');}
  const powered=!!(state.office&&state.office.upgrades.generator);
  P.hp=Math.min(P.maxHp,P.hp+55);P.brain=Math.min(100,P.brain+25+(powered?5:0));P.shakes=Math.min(100,P.shakes+15);P.wanted=Math.max(0,P.wanted-2);
  toast('you slept at the office.\nthe office opened before you did.\nthe day is the next day.',3200);saveGame();
}

export function rerollBlockRouteAtOffice(){
  const o=ensureOfficeState();if(!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract())return false;
  o.rerollDay=state.day;const last=validBlockRoute(state.blockRoute)?state.blockRoute.lastStopId:'';rollBlockRoute(false,last);toast('the old sheet goes under the desk.\nit receives no payout.',2200);saveGame();return true;
}

export function hideoutOwned(kind) {
  if (!state.flags) return false;
  return kind === 'scrap' ? !!state.flags.scrapHideoutOwned : !!state.flags.momHideoutOwned;
}

export function tryEnterHideout() {
  for (const kind of ['scrap', 'mom']) {
    if (!hideoutOwned(kind)) continue;
    const d = HIDEOUT_DOORS[kind];
    const ddx = (P.x + P.w/2) - (d.x + d.w/2);
    const ddy = (P.y + P.h/2) - (d.y + d.h/2);
    if (ddx*ddx + ddy*ddy < 40*40) { openHideout(kind); return true; }
  }
  return false;
}

export function openHideout(kind) {
  const isMom = kind === 'mom';
  const title = isMom ? "MOM'S COUCH" : "THE SHED";
  const intro = isMom
    ? "the apartment is warm.\nben is at work.\nthe couch is cleared.\nyou recognize this couch."
    : "the shed smells like dust and old grease.\nthere is a chest in the corner.\nthere is a cot.\nthe door locks from the inside.";
  dialogue(title, intro, [
    { label: "open the chest. (stash survives death.)", action: () => openHideoutChest(kind) },
    { label: isMom ? "rest 30 minutes. (+12 hp · -1 wanted)" : "rest 30 minutes. (+8 hp · -1 wanted)",
      action: () => {
        P.hp = Math.min(P.maxHp, P.hp + (isMom ? 12 : 8));
        P.wanted = Math.max(0, P.wanted - 1);
        toast("you sit down.\nthe walls have nothing to say.\n" + (isMom ? '+ 12 hp · - 1 wanted' : '+ 8 hp · - 1 wanted'), 2800);
        saveGame();
      }
    },
    { label: "sleep until morning. advances a day.", action: () => {
      const target = state.dayTime > 0.3 ? 1.3 : 0.3;
      state.dayTime = target;
      if (state.dayTime >= 1) { state.dayTime -= 1; state.day++; P.lifetime.dayCount = state.day; rollWeather(); resetDailyCounters(); rollHustles(); fireDayEvents(); }
      P.hp = Math.min(P.maxHp, P.hp + (isMom ? 60 : 50));
      P.brain = Math.min(100, P.brain + (isMom ? 30 : 25));
      P.shakes = Math.min(100, P.shakes + 15);
      P.wanted = Math.max(0, P.wanted - 2);
      adjustFaction(isMom ? 'spiritual' : 'scrap', 1);
      toast("you slept.\nyou are still here.\nthe day is the next day.", 3000);
      saveGame();
    }},
    isMom ? { label: "use the apartment phone. (skip the next ambient call.)", action: () => {
      state.phoneT = 90000 + Math.random()*150000;
      toast("the phone goes back on the hook.\nben uses this phone.\nben is at work.", 2400);
    }} : null,
    { label: "leave.", action: () => {} },
  ].filter(Boolean));
}

export function openHideoutChest(kind) {
  // chest is shared across both hideouts (one stash). simpler + matches the "your stuff" mental model.
  if (!state.hideoutStash) state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
  const s = state.hideoutStash;
  dialogue("THE CHEST",
    "metal box. dented. heavy.\nin the chest:\n  rocks: " + s.rocks + "\n  pure copper: " + s.copper + "\n  cash: $" + s.cash + "\n  items: " + (s.items.length||0),
    [
      { label: P.rocks>0 ? "deposit 1 rock. (chest: " + s.rocks + ")" : "deposit a rock. (you have none.)",
        disabled: P.rocks<=0, action: () => { P.rocks--; s.rocks++; toast("- 1 rock · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.rocks>0 ? "withdraw 1 rock. (chest: " + s.rocks + ")" : "withdraw a rock. (chest empty.)",
        disabled: s.rocks<=0, action: () => { s.rocks--; P.rocks++; toast("← chest · + 1 rock", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.copper>0 ? "deposit 1 copper. (chest: " + s.copper + ")" : "deposit copper. (you have none.)",
        disabled: P.copper<=0, action: () => { P.copper--; s.copper++; toast("- 1 copper · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.copper>0 ? "withdraw 1 copper. (chest: " + s.copper + ")" : "withdraw copper. (chest empty.)",
        disabled: s.copper<=0, action: () => { s.copper--; P.copper++; toast("← chest · + 1 copper", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.cash>=10 ? "deposit $10. (chest: $" + s.cash + ")" : "deposit $10. (short.)",
        disabled: P.cash<10, action: () => { P.cash -= 10; s.cash += 10; toast("- $10 · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.cash>=10 ? "withdraw $10. (chest: $" + s.cash + ")" : "withdraw $10. (chest short.)",
        disabled: s.cash<10, action: () => { s.cash -= 10; P.cash += 10; toast("← chest · + $10", 1400); saveGame(); openHideoutChest(kind); }},
      { label: "close the chest.", action: () => kind==='office' ? openOffice() : openHideout(kind) },
    ]);
}

export function init_daily_hideouts() {
  // ---------- v13 wave 6.5 — daily counter reset ----------
  // called from updateWorld when state.day increments. iterates over the accumulating
  // "today" counters and zeros them. the per-day "*Day" counters (kombuchaAskDay etc)
  // self-reset via "=== state.day" comparison, so they don't need explicit reset.
  DAILY_COUNTER_KEYS = [
    'stripeFencedToday', // exploit 3a (stripe fence price ladder)
    'barbPacketsToday',  // exploit 3b (barb supply cap)
    'peteCashToday',     // audit (pete daily $200 cap)
    'heistsToday',       // audit (heist daily cap = 3)
  ];
  
  
  // ---------- v13 wave 7 — day-specific scripted events ----------
  // fire at most once per save, guarded by state.flags.dayNFired booleans.
  
  // re-spawn the bus driver on reload if day 30 fired but resolution didn't.
  
  
  
  
  
  
  
  
  
  
  
  
  // ---------- v13 wave 7 — hideouts ----------
  // scrap-yard hideout: door at (520, 200) — back corner of scrap yard, behind yuri.
  // mom's apartment hideout: door at (1230, 1180) — marketplace area, close to mom (mom is at ~1280,1180).
  // E within 40px while owned = openHideout(kind). interactive dialogue with chest, rest, sleep, leave.
  
  
  
  
  
  
  
  
  
  HIDEOUT_DOORS = {
    scrap: { x: 520, y: 200, w: 24, h: 32 },
    mom:   { x: 1230, y: 1180, w: 24, h: 32 },
  };
  
  
  
  
  
  
}

export let WEAPONS;

export async function startHeist() {
  // v13 wave 6.5 — heist has a daily cap (3/day). closes the conductor-arbitrage grind path.
  // 3 heists × 2-4 copper × ($90 / 3 copper) caps the conductor floor at ~$270 / day.
  if ((state.counters.heistsToday||0) >= 3) {
    dialogue('ABANDONED BUILDING', "the door is half off.\nthere is no air coming out.\nbrutus jr. is awake and watching the door.\nnot tonight.", [
      { label: 'come back tomorrow.', action: () => { state.mode = 'playing'; }},
    ]);
    return;
  }
  state.counters.heistsToday = (state.counters.heistsToday||0) + 1;
  state.mode = 'heist';
  await heistStage(1);
}

export async function heistStage(stage) {
  return new Promise(resolve => {
    if (stage === 1) {
      dialogue('ABANDONED BUILDING', "the door is half off.\nbrutus jr. is inside. he is asleep.\nyou hear pipes singing in b flat.", [
        { label: 'sneak past brutus jr.', action: () => {
          if (Math.random()<0.7) { toast('you sneak. brutus jr. dreams of a tennis ball.'); heistStage(2); }
          else { toast('BRUTUS JR. WAKES UP. he is a puppy. he is FURIOUS.'); P.hp -= 10; if (P.hp<=0) die(); else heistStage(2); }
          resolve();
        }},
        { label: 'pick the side door lock. (4-pin lockpick)', action: () => {
          startLockpickMini(
            () => {
              toast("CLICK. the door opens.\nbrutus jr. dreams uninterrupted.\nyou are inside.");
              audio.glassBreak();
              heistStage(2); resolve();
            },
            () => {
              toast("you give up on the lock.\nthe door is harder than it looks.\nyou take the front door.");
              if (Math.random()<.5) { P.hp -= 12; toast('BRUTUS JR. WAS WAITING.\n- 12 hp', 1800); }
              if (P.hp<=0) die(); else heistStage(2); resolve();
            }
          );
        }},
        { label: P.inventory.find(i=>i.id==='soap') ? 'throw soap as distraction.' : "throw something (you have nothing useful).", disabled: !P.inventory.find(i=>i.id==='soap'), action: () => {
          P.inventory = P.inventory.filter(i=>i.id!=='soap');
          toast('brutus jr. licks the soap. is consumed.'); heistStage(2); resolve();
        }},
        { label: P.cash>=3 ? 'pay $3 for a chimichanga distraction.' : "you don't have $3.", disabled: P.cash<3, action: () => {
          P.cash -= 3; toast("the chimichanga is talking.\nbrutus jr. listens."); heistStage(2); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else if (stage === 2) {
      dialogue('THE COPPER PIPES', "the pipes hum.\nin b flat.\nthey are waiting.", [
        { label: 'strip them.', action: () => {
          const got = 2 + Math.floor(Math.random()*3);
          P.copper += got; audio.glassBreak();
          state.counters.copperStripped += got;
          if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
          toast(`+ ${got} pure copper\nthe singing stops.\nyou feel watched.`);
          if (!state.quests.copper_sings.done) { state.quests.copper_sings.done = true; questToast('THE COPPER SINGS'); }
          heistStage(3); resolve();
        }},
        { label: 'listen to them sing.', action: () => {
          P.brain = Math.min(100, P.brain+8); toast('+ 8 brain\nthey know your name now.');
          heistStage(3); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else {
      dialogue('GETAWAY', "the floor creaks.\nthere is a window.\nthere is also a door.", [
        { label: 'window. fast.', action: () => {
          if (Math.random()<0.8) { toast('you jump. the landing is bad but legal.'); P.hp -= 3; }
          else { toast('the glass breaks. so does your dignity.'); P.hp -= 12; audio.glassBreak(); P.wanted = Math.min(3,P.wanted+1); }
          if (P.hp<=0) die();
          state.mode = 'playing'; saveGame(); resolve();
        }},
        { label: 'door. slow.', action: () => {
          if (Math.random()<0.5) { toast('a cop is waiting on the other side.\nyou run.'); P.wanted = Math.min(3,P.wanted+2); }
          else { toast('you walk out like you own the place.\n(you do not.)'); }
          state.mode = 'playing'; saveGame(); resolve();
        }},
      ]);
    }
  });
}

export function pickupWeapon(id) {
  if (!WEAPONS[id]) return;
  P.weapon = id;
  toast('+ '+WEAPONS[id].n+'\n(equipped.)');
  feedPost("picked up " + WEAPONS[id].n + ". things are escalating.", '@crackheadcent');
}

export function startRhythmMini() {
  state.mode = 'dialogue';
  const arrows = ['↑','↓','←','→'];
  const keyMap = { '↑':'w','↓':'s','←':'a','→':'d' };
  const seq = [];
  for (let i=0;i<8;i++) seq.push(arrows[Math.floor(Math.random()*4)]);
  let idx = 0, hits = 0;
  const renderRhythm = () => {
    const opts = arrows.map(a => ({
      label: a + ' ' + (a===seq[idx]?'(now!)':''),
      action: () => {
        if (a === seq[idx]) { hits++; }
        idx++;
        if (idx >= seq.length) {
          const pay = hits * 3;
          P.cash += pay; P.cred += Math.floor(hits/2);
          audio.coin();
          toast('· '+hits+'/8 hits ·\n+ $'+pay+' · + '+Math.floor(hits/2)+' cred\nthe crowd was three people.\ntwo of them were waiting for the bus.', 3000);
          if (hits === 8) { unlockAchievement('not_a_phase'); broadcastNews("KARAOKE PERFECTION REPORTED. WITNESSES UNAVAILABLE."); }
          saveGame();
        } else {
          renderRhythm();
        }
      }
    }));
    opts.push({ label: 'forfeit. (you sound tired)', action: () => { toast("you stop singing.\nthe crowd stays."); }});
    dialogue('· '+(idx+1)+' / '+seq.length+' ·', "next: " + seq[idx] + "\n\nyour line:\n" + seq.slice(0, idx).map((x,i)=> i<idx ? x : '').join(' '), opts);
  };
  renderRhythm();
}

export function startLockpickMini(onSuccess, onFail) {
  state.mode = 'dialogue';
  // 4-pin lock — random target indices, player guesses by pressing 1-4 in any order
  const pins = [false,false,false,false];
  const target = [1,2,3,4].sort(()=>Math.random()-.5);
  let nextPin = 0;
  const renderLP = () => {
    const display = pins.map(p => p ? '[●]' : '[ ]').join(' ');
    dialogue('LOCKPICK', "the lock has 4 pins.\npush them in the right order.\n\n" + display + "\n\n(it makes a small click when you guess right.)", [
      { label: '1. set pin 1', action: () => { tryPin(1); }},
      { label: '2. set pin 2', action: () => { tryPin(2); }},
      { label: '3. set pin 3', action: () => { tryPin(3); }},
      { label: '4. set pin 4', action: () => { tryPin(4); }},
      { label: 'give up.', action: () => { onFail && onFail(); }},
    ]);
  };
  const tryPin = (n) => {
    if (target[nextPin] === n) {
      pins[n-1] = true;
      audio.pickup();
      nextPin++;
      if (nextPin >= 4) { onSuccess && onSuccess(); return; }
      renderLP();
    } else {
      audio.hurt();
      // wrong — reset all pins and lose 1 brain
      pins.forEach((_,i) => pins[i] = false);
      nextPin = 0;
      P.brain = Math.max(0, P.brain - 2);
      toast("CLUNK. all pins reset.\n- 2 brain", 1400);
      renderLP();
    }
  };
  renderLP();
}

export function spawnBrutusOlder() {
  if (state.brutusOlderActive) return;
  state.brutusOlderActive = true;
  // v13 wave 7 — street loved: brutus older spawns but does not aggro unprovoked.
  const streetLoved = factionTier(P.faction ? P.faction.street : 0) === 'loved';
  const b = {
    id:'brutus_older', name:'BRUTUS THE OLDER', sprite:'brutus',
    x: P.x + 100, y: P.y + 100,
    w: 48, h: 36, color:'#8a3030',
    hp:200, maxHp:200, speed:2.4, dmg:14,
    hostile: !streetLoved, aggro: !streetLoved, isBossB:true,
    showHp:true, attackCd:0, scale: 1.5,
    // v13 wave 5 — charger from the start; grabber added at phase 3 via state.brutusOlderPhase
    archetype: streetLoved ? 'passive' : 'charger_older',
    addsT: 0,
  };
  b.x = clamp(b.x, 40, WORLD.w-80);
  b.y = clamp(b.y, 40, WORLD.h-60);
  runtime.npcs.push(b);
  state.brutusOlderNPC = b;
  audio.bossRoar();
  state.flash = 1; state.flashColor = 'rgba(160,40,40,.4)';
  state.shake = 14;
  if (streetLoved) {
    toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe sniffs once. he sits.\n(the block knows you.)", 5400);
    feedPost("the dog came back. he is bigger now. he did not charge.", '@crackheadcent');
  } else {
    toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe is ASCENDED.", 4500);
    feedPost("the dog came back. he is bigger now.", '@crackheadcent');
  }
  broadcastNews("BRUTUS HAS RETURNED. WITNESSES DESCRIBE 'LARGER. REDDER.'");
}

export function blockMenu() {
  const opts = [];
  // v13 wave 4 — soap rocks smoke first (FIFO with the real rocks).
  // looks identical in inventory; the truth comes when you light it.
  const totalRocks = (P.rocks||0) + (P.soapRocks||0);
  opts.push({
    label: totalRocks > 0 ? "smoke a rock. (-1 rock, +18s rocked-up)" : "smoke a rock. (you have none.)",
    disabled: totalRocks <= 0 || P.rockedT > 0,
    action: () => {
      if ((P.soapRocks||0) > 0) {
        // soap rock — no rocked-up effect, no shakes relief, no cred. you knew.
        P.soapRocks--;
        P.lifetime.rocksSmoked++;
        audio.hurt(); audio.glassBreak();
        toast("you smoke it. it's soap.\nyou knew. you smoked it anyway.", 3600);
        feedPost("smoked soap. tasted it. did it again.", '@crackheadcent');
        unlockAchievement('soap_tongue');
        // intro chain still completes — the loop is the loop
        completeIntroSmoke();
        saveGame();
        return;
      }
      P.rocks--; P.rockedT = 18000; P.crashT = 0; P.shakes = Math.max(0, P.shakes-50);
      P.brain = Math.max(0, P.brain-4); P.lifetime.rocksSmoked++;
      P.cred += 1;
      let royalStatic=false;
      if(state.kingdom&&state.kingdom.stage==='anoint'){
        state.kingdom.stage='emperor_gate';state.kingdom.marks=0;royalStatic=true;syncKingdomQuests();
      }
      audio.rockUp();
      state.flash = 1; state.flashColor = 'rgba(232,192,64,.5)';
      toast(royalStatic
        ? '· ROYAL STATIC ·\nthe sun moves. the throne ditch answers.\nbrain -4. shakes -50. emperor available.'
        : '· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50.', royalStatic?4300:2500);
      feedPost("smoked a rock at the block. for the bit.", '@crackheadcent');
      if(royalStatic){broadcastNews('ROYAL STATIC RECEIVED. ONE DITCH ACKNOWLEDGES THE SIGNAL.');feedPost('the rock had a crown in the reception. the ditch is calling.','@blocklog');}
      applyRep({ street: 1, spiritual: -1 }); // wave 7 — smoking real rocks ledger
      // v13 wave 3 — completes the intro chain
      completeIntroSmoke();
      saveGame();
    }
  });
  // v13 wave 3 — open stripe's package "alone, where no one sees" (the block is home)
  if (state.flags && state.flags.hasStripePackage) {
    opts.push({
      label: "open stripe's package. (alone, no one is watching.)",
      action: () => openStripePackage()
    });
  }
  opts.push({
    label: "sleep until morning. (+50 hp · +25 brain · -1 wanted)",
    action: () => {
      // Settle today's crate contract before dawn posts tomorrow's sheet.
      state.counters.slept = (state.counters.slept||0) + 1;
      checkHustles();
      const target = state.dayTime > 0.3 ? 1.3 : 0.3;
      state.dayTime = target;
      if (state.dayTime >= 1) {
        state.dayTime -= 1; state.day++; P.lifetime.dayCount=state.day;
        rollWeather(); resetDailyCounters(); rollHustles(); fireDayEvents();
        if(state.day>=7)unlockAchievement('tuesday_again');
      }
      P.hp = Math.min(P.maxHp, P.hp + 50);
      P.brain = Math.min(100, P.brain + 25);
      P.shakes = Math.min(100, P.shakes + 15);
      P.wanted = Math.max(0, P.wanted - 1);
      audio.coin();
      toast("you sleep on the crate.\nyou dream of a chimichanga that has opinions.\n+50 hp · +25 brain", 3000);
      feedPost("slept on the block. felt like 7 hours. was 14 minutes.", '@crackheadcent');
      saveGame();
    }
  });
  opts.push({
    label: P.supplies > 0 ? `cook a batch. (🧪${P.supplies} → rocks)` : `cook a batch. (you have no packets.)`,
    disabled: (P.supplies||0) <= 0,
    action: () => cookBatchMenu()
  });
  opts.push({
    label: "sit on the crate and think.",
    action: () => sitOnCrate()
  });
  if (P.inventory.find(i => i.id === 'lottery')) {
    opts.push({ label: "scratch the lottery ticket.", action: () => scratchLottery() });
  }
  opts.push({ label: "leave.", action: () => {} });
  dialogue('THE BLOCK', "the milk crate is here. the sky is here.\nyour shakes are " + Math.round(P.shakes) + ". your brain is " + Math.round(P.brain) + ".", opts);
}

export function sitOnCrate() {
  const thoughts = [
    "you sit. the crate accepts you. you remember nothing useful.",
    "you sit. a cloud passes. it does not acknowledge you.\n(+1 cred for the patience.)",
    "you sit. a possum walks by. nods. continues.\nyou are on his route.",
    "you sit. you remember a birthday from 1996.\nit was not yours.",
    "you sit. the milk crate is very old.\nit has seen kings.",
    "you sit. you almost have a thought.\nit leaves.",
  ];
  const t = thoughts[Math.floor(Math.random()*thoughts.length)];
  if (t.includes('+1 cred')) P.cred++;
  toast(t, 4000);
}

export function panhandle() {
  const isDay = !isNight();
  dialogue("THE MARKETPLACE", isDay
    ? "people are walking by.\nthey are pretending you are scenery."
    : "the marketplace is asleep.\nyou could still try.", [
    {
      label: "ask for change. (chance of $1-5)",
      action: () => {
        const r = Math.random();
        const mod = isDay ? 0 : -0.2;
        if (r < 0.45 + mod) {
          const got = 1 + Math.floor(Math.random()*4);
          P.cash += got; audio.coin();
          if (got >= 4) state.counters.bigPan = (state.counters.bigPan||0) + 1;
          toast("+ $"+got+"\na person handed it to you and immediately regretted it.");
        } else if (r < 0.65 + mod) {
          P.cash++; toast("+ $1\nyou were given a single dollar with eye contact you did not consent to.");
        } else if (r < 0.85) {
          toast("a woman gave you advice.\nthe advice was 'have you tried not.'\n(- 1 brain)");
          P.brain = Math.max(0, P.brain - 1);
        } else {
          toast("a man told you to 'get a job.'\nhe has not had one since 2003.\n+1 cred (out of spite)");
          P.cred++;
        }
      }
    },
    {
      label: "perform a song you don't know.",
      action: () => {
        if (Math.random() < 0.4) {
          P.cash += 3; toast("+ $3\nyou hummed. people walked faster. one tipped.");
        } else toast("you hummed. no one tipped.\nyou hum louder. still nothing.\nthe humming was the song.");
      }
    },
    {
      label: "do a card trick you don't know.",
      action: () => {
        if (Math.random() < 0.25) {
          P.cash += 8; P.cred++; toast("+ $8 + 1 cred\nit worked. you don't know how.\nneither does the audience.");
        } else {
          P.wanted = Math.min(3, P.wanted + 1);
          toast("the trick was 'i have the card and now you don't.'\nthis is, in fact, theft.\nwanted +1");
        }
      }
    },
    { label: "leave.", action: () => {} },
  ]);
}

export function scratchLottery() {
  P.inventory = P.inventory.filter(i => i.id !== 'lottery');
  const r = Math.random();
  if (r < 0.01) {
    P.cash += 500; toast("· $500 ·\nyou won. the world is wrong.\nthe ticket combusts.", 4500);
    audio.coin(); broadcastNews("LOCAL MAN WINS $500. REFUSES INTERVIEW.");
    feedPost("won the lottery. immediately spent half of it. on what.", '@crackheadcent');
  } else if (r < 0.15) {
    const win = 5 + Math.floor(Math.random()*15); P.cash += win;
    toast("· $"+win+" ·\na small win. dignity-shaped.", 2500); audio.coin();
  } else {
    toast("nothing. as ever.\nthe ticket smells like a basement.", 2200);
  }
  saveGame();
}

export function init_activities() {
  // ---------- HEIST (simple 3-stage) ----------
  
  
  
  // ---------- WEAPONS ----------
  WEAPONS = {
    fists:        { n:"bare fists",          dmg: 0,  reach: 0,  cd: 280, swing:'arc' },   // baseline
    pipe:         { n:"a length of copper pipe", dmg: 8, reach: 12, cd: 320, swing:'pipe', sings:true },
    brick:        { n:"a brick",              dmg: 12, reach: 6,  cd: 380, swing:'thud' },
    cart_wheel:   { n:"a shopping cart wheel",dmg: 6,  reach: 10, cd: 260, swing:'spin' },
    shoe:         { n:"a shoe (tony's)",      dmg: 10, reach: 14, cd: 340, swing:'sole' },
    baguette:     { n:"a stale baguette",     dmg: 4,  reach: 16, cd: 240, swing:'crumble' },
    microphone:   { n:"a karaoke microphone (just the cord)", dmg: 7, reach: 18, cd: 360, swing:'whip' },
    // v13 wave 3 — stripe's bait knife (possible outcome of opening the package)
    knife:        { n:"a knife (handle taped)",   dmg: 14, reach: 8,  cd: 260, swing:'stab' },
    // v13 wave 6 — drops from smashed bottles + (rare) dumpsters. dmg+8, reach short. it cuts.
    broken_bottle:{ n:"a broken bottle",           dmg: 8,  reach: 6,  cd: 300, swing:'jagged' },
  };
  
  
  
  // ---------- RHYTHM PANHANDLE MINIGAME ----------
  
  
  // ---------- LOCKPICK MINIGAME ----------
  
  
  // ---------- BRUTUS OLDER (boss 2) ----------
  
  
  
  
  
  // ---------- PANHANDLE ----------
  
  
  
  
  
}

export let MOVEMENT_KEYS, INPUT_RELEASE_HOOKS, titleLoadPending;

export async function loadFromTitle() {
  if(state.mode!=='title'||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    const ok=await loadGame();
    if(ok)startGame(true);else toast('no save.',1200);
  }finally{titleLoadPending=false;}
}

export async function continueAfterEnding(){
  if(state.mode!=='title'||!state.endingContinue||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    if(state.endingSavePromise)await state.endingSavePromise;
    state.endingContinue=false;state.endingSavePromise=null;
    releaseAllInput();document.getElementById('title').classList.add('hide');state.mode='playing';
    toast('the block is still here.\nthe clipboard has another sheet.',2400);
  }finally{titleLoadPending=false;}
}

export function releaseAllInput() {
  state.keys.clear();
  state.stickX=0; state.stickY=0; state.stickMag=0;
  for(const release of INPUT_RELEASE_HOOKS)release();
  document.querySelectorAll('#mobile-ctrls .active').forEach(el=>el.classList.remove('active'));
}

export function init_keyboard() {
  // ---------- INPUT ----------
  // Physical movement keys are latched by keydown/keyup. Auto-repeat is deliberately not
  // used as a heartbeat: most operating systems repeat only the newest key in a chord.
  MOVEMENT_KEYS = new Set(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright','shift']);
  INPUT_RELEASE_HOOKS=[];
  titleLoadPending=false;
  
  
  window.addEventListener('keydown', async (e) => {
    const k = e.key.toLowerCase();
    // If a modal/focus safety path cleared a still-physical key, browser repeat may not
    // resurrect it. Releasing and pressing again creates the fresh non-repeat keydown.
    if (e.repeat && !state.keys.has(k) && MOVEMENT_KEYS.has(k)) {
      return;
    }
    // title screen
    if (state.mode === 'title') {
      if (k === ' ' || k === 'spacebar') { e.preventDefault(); audio.init(); if(state.endingContinue)await continueAfterEnding();else startGame(false); return; }
      if (k === 'l') { await loadFromTitle(); return; }
      return;
    }
    // global
    if (k === 'm') { audio.muted = !audio.muted; toast(audio.muted?'muted.':'unmuted.', 800); return; }
    if (k === 'escape') {
      if (state.mode === 'dialogue') closeDialogue();
      else if (state.mode === 'inv' || state.mode === 'quest') closePanel();
      else if (state.mode === 'cookmini') { e.preventDefault(); bailHeatMini(); }
      return;
    }
    // v13 wave 4 — heat minigame: SPACE / 1 locks the needle
    if (state.mode === 'cookmini') {
      if (k === ' ' || k === 'spacebar' || k === '1' || k === 'enter') {
        e.preventDefault();
        lockHeatMini();
      }
      return;
    }
    if (state.mode === 'dialogue') {
      // 1-9 select dialogue option
      const n = parseInt(k);
      if (n>=1 && n<=9 && activeDialogue && activeDialogue.opts[n-1]) {
        const o = activeDialogue.opts[n-1];
        if (!o.disabled) { audio.dialogue(); closeDialogue(); o.action && o.action(); }
      }
      return;
    }
    if (k === 'i') {
      if (state.mode==='inv') { closePanel(); }
      else if (state.mode==='quest') { closePanel(); state.mode='inv'; renderInventory(); }
      else { releaseAllInput(); state.mode='inv'; renderInventory(); }
      return;
    }
    if (k === 'q') {
      if (state.mode==='quest') { closePanel(); }
      else if (state.mode==='inv') { closePanel(); state.mode='quest'; renderQuests(); }
      else { releaseAllInput(); state.mode='quest'; renderQuests(); }
      return;
    }
    if (k === 'p') {
      phoneState.visible = !phoneState.visible;
      renderPhone();
      return;
    }
    // play mode keys
    if (state.mode !== 'playing') return;
    if (MOVEMENT_KEYS.has(k)) e.preventDefault();
    state.keys.add(k);
    // v13 wave 5 — stun gates all action inputs (SPACE attack, E interact). Movement is gated
    // in updateWorld; menu/inv/mute keys above still work so the player can pause/leave.
    if (P.stunT > 0) return;
    if (k === ' ' || k === 'spacebar') { e.preventDefault(); playerAttack(); }
    if (k === 'e') tryInteract();
    if (k === 'f') {
      if (state.tweakerCdT > 0 || P.brain <= 0) {
        if (P.brain <= 0) toast('your brain has nothing left to give.', 1500);
      } else if (state.tweakerT === 0) {
        state.tweakerT = 3000; state.tweakerCdT = 6000;
        // small cost on activation
        P.brain = Math.max(0, P.brain - 5);
      }
    }
  });
  window.addEventListener('keyup', (e) => {
    const k = e.key.toLowerCase();
    state.keys.delete(k);
  });
  
  // Focus loss is authoritative release evidence for both keyboard and analog input.
  
  window.addEventListener('blur', releaseAllInput);
  document.addEventListener('visibilitychange', () => { if (document.hidden) releaseAllInput(); });
  
  
}

export function startGame(loaded) {
  releaseAllInput();
  state.endingContinue=false;state.endingSavePromise=null;
  document.getElementById('title').classList.add('hide');
  if (!loaded) {
    // fresh save state
    state.cashPilesCollected = new Set();
    state.achievements = new Set();
    P.lifetime.routesCompleted = 0;
    P.lifetime.officeJobs = 0;
    P.lifetime.territoriesClaimed = 0;
    P.lifetime.pretendersDefeated = 0;
    state.blockRoute = null;
    state.office = freshOfficeState();
    state.districtClaims = Object.create(null);
    state.kingdom = freshKingdomState();
    state.kingdomBattle=null;state.bossActive=false;state.bossKind='';state.bossNPC=null;
    state.loadedNpcDeaths=null;
    state.counters = {
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0, pigeonTrade: 0,
      peteSold: 0, alleyKills: 0, dumpDives: 0, slept: 0,
      tacosEaten: 0, laundryDone: 0, bigPan: 0,
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0, introCashEarned: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      // v13 wave 6.5 — economy gates
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      // v13 wave 8a — philosopher daily spiritual gate
      philosopherRepDay: 0,
      gutterInventoryDay: 0,
    };
    Object.values(state.quests).forEach(q => { q.done = false; if (q.available === true) q.available = q.intro?undefined:false; });
    state.day = 1; state.dayTime = 0.35;
    state.weather = 'clear';
    state.combo = 0;
    P.equip = { shoes:null, hat:null, coat:null };
    P.cartMounted = false;
    P.hasPossum = false;
    state.hustles = null;
    // v13 wave 3 — fresh save state for discoverability + intro chain
    state.metVendors = new Set();
    state.flags = {
      introDone: false, momIntroFired: false, hasStripePackage: false,
      stripeBetrayed: false, daveHasCrossword: false, hasCrossword: false, crownSpotIdx: -1,
      // v13 wave 7 — day events + hideouts
      day3Fired: false, day7Fired: false, day14Fired: false, day30Fired: false,
      day14Collected: false, busTaken: false, busRefused: false,
      silenceUntilT: 0,
      scrapHideoutOwned: false, momHideoutOwned: false,
      momRentDay: 0, scrapLoanDay: 0, momProudCallDay: 0,
      // v13 wave 8a — fresh saves get the first-entry toasts as they discover the new zones.
      trainYardEntered: false, parkEntered: false, skidRowEntered: false, oldSchoolEntered: false,
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      trainHopperTalkedTo: false,
      priceGuyDay: 0, priceGuyVisits: 0,
      parkNightCashDay: 0,
      // v13 wave 8b — loved ambient + bus pass day-stamps
      lovedAmbient_street_day: 0, lovedAmbient_scrap_day: 0, lovedAmbient_spiritual_day: 0,
      busPassUsedDay: 0, momBusPassDay: 0,
      // v15 living-neighborhood incident history
      incidentDay: 0, incidentMask: 0, incidentsToday: 0, lastIncidentId: '',
    };
    // v13 wave 7 — faction reputation + hideout chest
    P.faction = { street: 0, scrap: 0, spiritual: 0 };
    state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
    state.dayEventActor = null;
    state.crownPickup = null;
    state.momTipT = 30000; // ~30s into the new save
    // intro chain seeds
    if (state.quests.intro_remember) { state.quests.intro_remember.available = undefined; state.quests.intro_remember.done = false; }
    if (state.quests.intro_tony)     { state.quests.intro_tony.available = false; state.quests.intro_tony.done = false; }
    if (state.quests.intro_smoke)    { state.quests.intro_smoke.available = false; state.quests.intro_smoke.done = false; }
    // v13 wave 6 — fresh save state for map-depth pass
    state.flags.underpassEntered = false;
    state.flags.dumpsterPropaneAwarded = false;
    state.flags.churchLoadedDumpsterX = 0;
    state.flags.churchLoadedDumpsterY = 0;
    if (state.quests.scrap_dog) { state.quests.scrap_dog.state = 'idle'; state.quests.scrap_dog.done = false; state.quests.scrap_dog.available = false; }
    state.graffiti = null; // build a fresh layout
    state.posters = null;  // v13 wave 8b — fresh poster layout on new save
    state.publicPhoneT = 240000 + Math.random()*240000;
    state.phonePropRingT = 0;
    state.publicPhoneAnswered = 0;
    state.freedDogT = 0;
    state.freedDogFollowT = 0;
    state.freedDogFirstReturn = false;
    // new save starts broke. find the ten dollars.
    P.cash = 0;
    P.charisma = 0;
    P.barbAside = false;
    state.barbAside = false;
  }
  spawnNpcs();
  if(state.loadedNpcDeaths instanceof Set){
    for(const n of runtime.npcs)if(state.loadedNpcDeaths.has(n.id))n.dead=true;
    state.loadedNpcDeaths=null;
  }
  spawnCashPiles();
  initInteractiveProps();
  // v13 wave 6 — build (or re-use persisted) graffiti layout
  buildGraffiti();
  // v13 wave 8b — build (or re-use persisted) wall poster layout
  buildPosters();
  applyEquipStats();
  if (!loaded || !Array.isArray(state.hustles)) rollHustles();
  ensureBlockRoute();
  ensureOfficeState();
  syncOfficeDay();
  maybeUnlockOfficeQuest();
  updateOfficeMilestones();
  ensureKingdomState();
  maybeUnlockKingdom(true,false);
  syncKingdomQuests();
  syncKingdomForces();
  // v13 wave 7 — re-spawn bus driver if day 30 fired but bus unresolved
  rehydrateDay30Bus();
  state.mode = 'playing';
  // v13 wave 3 — different first-toast for the intro
  if (!loaded && state.flags && !state.flags.introDone) {
    toast("you wake up on the sidewalk.\nyour mouth tastes like a battery.\nyou do not remember.\n(Q to see what's next.)", 4200);
  } else {
    toast('you wake up on the sidewalk.\nyour mouth tastes like a battery.\n(Q to see today\'s hustles.)', 3500);
  }
  // initial feed posts
  feedPost("woke up.\nstill in the neighborhood.\nfeels like a tuesday.", '@crackheadcent');
  feedPost("good morning. tony has not blinked.", '@tony_observer');
  broadcastNews("good evening. " + RANKS[P.rank].name + " is once again at large.");
}

export function init_start() {
  // ---------- START ----------
  
  
  
}

export function init_boot() {
  // ---------- INIT ----------
  buildSprites();
  buildEnvironmentSprites();
  buildLandmarkFacades();
  buildLightSprites();
  buildFogSheet();
  updateHUD();
  rotateNews();
  setInterval(rotateNews, 50000);
  // CRT power-on auto-dismiss
  setTimeout(() => { const p = document.getElementById('poweron'); if (p) p.classList.add('gone'); }, 800);
  
  
}

export let loadBtnEl, titleLoadTap;

export function setupMobile() {
  // detect touch
  const isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
  if (!isTouch && window.innerWidth > 820) return;
  state.touchMode = true;
  document.getElementById('mobile-ctrls').style.display = 'block';
  const fireKey = (key, down) => {
    const ev = new KeyboardEvent(down ? 'keydown' : 'keyup', { key });
    window.dispatchEvent(ev);
  };
  // D-pad replaced in v11 by analog joystick — see below
  document.querySelectorAll('#mobile-ctrls .ab').forEach(el => {
    const key = el.dataset.key;
    let pressed = false;
    const press = (e) => {
      if (pressed) return;
      pressed = true;
      e.preventDefault();
      el.classList.add('active');
      fireKey(key, true);
      if (e.pointerId !== undefined && el.setPointerCapture) {
        try { el.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const release = (e) => {
      if (!pressed) return;
      pressed = false;
      if (e && e.preventDefault) e.preventDefault();
      el.classList.remove('active');
      fireKey(key, false);
    };
    el.addEventListener('pointerdown', press);
    el.addEventListener('pointerup', release);
    el.addEventListener('pointercancel', release);
    el.addEventListener('lostpointercapture', release);
    el.addEventListener('touchstart', press, {passive:false});
    el.addEventListener('touchend', release, {passive:false});
    el.addEventListener('touchcancel', release, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{pressed=false;el.classList.remove('active');});
  });

  // ---------- ANALOG JOYSTICK ----------
  const stick = document.getElementById('stick');
  const nub = document.getElementById('stickNub');
  if (stick && nub) {
    let activePointer = null;
    let cx = 0, cy = 0; // stick center in screen coords
    const RADIUS = 42;
    const DEAD_ZONE = 0.18;
    const setVector = (dx, dy) => {
      // distance ratio
      const mag = Math.sqrt(dx*dx + dy*dy);
      const norm = Math.min(1, mag / RADIUS);
      const nx = norm > 0.001 ? dx/mag : 0;
      const ny = norm > 0.001 ? dy/mag : 0;
      // store on state for updateWorld to consume
      if (norm < DEAD_ZONE) {
        state.stickX = 0; state.stickY = 0; state.stickMag = 0;
      } else {
        state.stickX = nx;
        state.stickY = ny;
        state.stickMag = norm;
      }
      // visual position of nub
      const clampedMag = Math.min(mag, RADIUS);
      const px = norm > 0.001 ? (dx/mag) * clampedMag : 0;
      const py = norm > 0.001 ? (dy/mag) * clampedMag : 0;
      nub.style.transform = `translate(calc(-50% + ${px}px), calc(-50% + ${py}px))`;
    };
    const onDown = (e) => {
      if (activePointer !== null) return;
      e.preventDefault();
      activePointer = e.pointerId !== undefined ? e.pointerId : 1;
      const rect = stick.getBoundingClientRect();
      cx = rect.left + rect.width/2;
      cy = rect.top + rect.height/2;
      stick.classList.add('dragging');
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
      if (e.pointerId !== undefined && stick.setPointerCapture) {
        try { stick.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const onMove = (e) => {
      if (activePointer === null) return;
      // for pointer events, check id; for touch, take first
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      e.preventDefault();
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
    };
    const onUp = (e) => {
      if (activePointer === null) return;
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      activePointer = null;
      stick.classList.remove('dragging');
      setVector(0, 0);
    };
    stick.addEventListener('pointerdown', onDown);
    stick.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    stick.addEventListener('pointercancel', onUp);
    // touch fallback
    stick.addEventListener('touchstart', onDown, {passive:false});
    stick.addEventListener('touchmove', onMove, {passive:false});
    stick.addEventListener('touchend', onUp, {passive:false});
    stick.addEventListener('touchcancel', onUp, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{
      activePointer=null;
      stick.classList.remove('dragging');
      setVector(0,0);
    });
  }
  // top bar (single tap toggles)
  document.querySelectorAll('#mobile-ctrls .topbar .mb').forEach(el => {
    const key = el.dataset.key;
    const tap = (e) => {
      e.preventDefault();
      el.classList.add('active');
      setTimeout(() => el.classList.remove('active'), 120);
      fireKey(key, true);
      setTimeout(() => fireKey(key, false), 30);
    };
    el.addEventListener('touchstart', tap, {passive:false});
    el.addEventListener('click', tap);
  });
  // title tap = start
  document.getElementById('title').addEventListener('touchstart', (e) => {
    e.preventDefault();
    if (state.mode === 'title') {
      audio.init();
      if(state.endingContinue)continueAfterEnding();else startGame(false);
    }
  }, {passive:false});
  // prevent canvas touch from scrolling
  document.getElementById('game').addEventListener('touchstart', e => e.preventDefault(), {passive:false});
  // v13 wave 4 — tap anywhere on canvas to lock during the heat minigame
  const onCookTap = (e) => {
    if (state.mode !== 'cookmini') return;
    e.preventDefault();
    lockHeatMini();
  };
  document.getElementById('game').addEventListener('pointerdown', onCookTap);
  document.getElementById('game').addEventListener('touchstart', onCookTap, {passive:false});
  // global block double-tap zoom
  document.addEventListener('gesturestart', e => e.preventDefault());
  document.addEventListener('dblclick', e => e.preventDefault());
}

export function init_mobile() {
  // ---------- MOBILE TOUCH CONTROLS ----------
  
  setupMobile();
  
  // The visible load receipt is a real touch/click target, not keyboard-only decoration.
  loadBtnEl=document.getElementById('loadBtn');
  titleLoadTap=(e)=>{
    e.preventDefault();e.stopPropagation();
    loadFromTitle();
  };
  loadBtnEl.addEventListener('pointerdown',titleLoadTap);
  loadBtnEl.addEventListener('touchstart',titleLoadTap,{passive:false});
  loadBtnEl.addEventListener('click',titleLoadTap);
  
  // detect existing save for title screen; storage absence must not break a double-clicked build.
  (async () => {
    try{
      const s = await window.storage.get(SAVE_KEY);
      if (s && s.value) loadBtnEl.style.display = 'block';
    }catch(_){ /* volatile play still works when the host provides no storage adapter */ }
  })();
  
  requestAnimationFrame(update);
  
  // local QA accessor (data/functions remain inside the single-file closure)
  window._rb = {
    P, state,
    get npcs() { return runtime.npcs; },
    get sprites() { return SPRITE_CACHE; },
    get pals() { return PALS; },
    get routeStops() { return ROUTE_STOPS; },
    startGame, updateWorld, drawAll, startIncident, updateActiveIncident,
    validBlockRoute, rollBlockRoute, ensureBlockRoute, tryStampBlockRoute, routePatchTier, hustleProgress,
    currentPrimaryObjective, resolveNpcPose, renderQuests, saveGame, loadGame,
    endingScreen, takeTheBus, continueAfterEnding,
  };
  
}
