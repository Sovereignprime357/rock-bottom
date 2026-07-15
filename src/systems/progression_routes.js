/* Generated from frozen rock_bottom_v19.html.
 * Source seams: achievements, hustles, and block routes.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, die, last, panhandle, runtime, state, toast, unlockAchievement } from '../legacy.js';
import { activeOfficeContract, maybeUnlockOfficeQuest } from './campaigns.js';
import { broadcastNews, feedPost } from './communications.js';

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
