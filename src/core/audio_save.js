/* Generated from frozen rock_bottom_v19.html.
 * Source seams: audio and persistence.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, dialogue, runtime, state, toast } from './runtime_ui.js';
import { startGame } from './start.js';
import { PROPS } from '../data/props.js';
import { ctx } from '../render/canvas_geography.js';
import { drawGraffiti } from '../render/structures.js';
import { CLAIM_SITES, KINGDOM_STAGE_RANK, claimedDistrictIds, freshKingdomState, freshOfficeState, normalizeDistrictClaims, normalizeKingdomState, normalizeOfficeState, officeNat, syncKingdomQuests } from '../systems/campaigns.js';
import { resetDailyCounters } from '../systems/daily_hideouts.js';
import { validBlockRoute } from '../systems/progression_routes.js';

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
