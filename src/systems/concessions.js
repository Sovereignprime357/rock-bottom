/* v20 landing 3 — SMOKE CONCESSIONS (SPEC-v20-concessions.md, OD-5).
 * Owns the ONE smoke transaction (I-ONE-LOOP): the 18000ms/8000ms loop lives here
 * and nowhere else. Every spot — the Block and every earned concession — calls
 * smokeRockAt(). The loop that moved here is the loop that was at
 * activities.js blockMenu(), byte for byte. One loop, many rooms.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { inZone, isNight } from '../data/npc_spawns.js';
import { syncKingdomQuests } from './campaigns.js';
import { completeIntroSmoke } from './combat.js';
import { broadcastNews, feedPost } from './communications.js';
import { applyRep } from './factions.js';
import { REGULAR_VENUE_BY_ID, recognitionTier, recognitionVenueAt } from './recognition.js';

// ---------- spot registry ----------
// The Block is the only unconditional spot, forever (OD-5). Concession spot ids
// equal their recognition venue ids; the Block has no venue and no condition.
// Coordinates are BAD IDEA anchors: the crate, the bench, the choir office door,
// the underpass center, the laundromat dryer (the incident dryer's post).
export const SMOKE_SPOTS = Object.freeze([
  Object.freeze({ id:'block',        venueId:'',             feedName:'the block',        x:1064, y:882  }),
  Object.freeze({ id:'park',         venueId:'park',         feedName:'the park',         x:2540, y:1046 }),
  Object.freeze({ id:'choir_office', venueId:'choir_office', feedName:'the choir office', x:6830, y:3096 }),
  Object.freeze({ id:'underpass',    venueId:'underpass',    feedName:'the underpass',    x:1210, y:350  }),
  Object.freeze({ id:'laundromat',   venueId:'laundromat',   feedName:'the laundromat',   x:1540, y:1190 }),
]);
export const SMOKE_SPOT_BY_ID = Object.freeze(Object.fromEntries(SMOKE_SPOTS.map(spot=>[spot.id,spot])));

// ---------- conditions ----------
// Two are reads of clocks that already existed (night, the dog). Two are clocks
// authored for this landing (choir office hours, the dryer cycle) and return
// false until their state exists — a concession without its clock is closed.

export function choirOfficeOpen() {
  const clocks=state.concessionClocks;
  return !!(clocks&&clocks.choir&&clocks.choir.phase==='open');
}

export function dryerMidCycle() {
  const clocks=state.concessionClocks,dryer=clocks&&clocks.dryer;
  if(!dryer||dryer.phase!=='running')return false;
  const elapsed=DRYER_RUN_MS-dryer.t;
  return elapsed>=DRYER_MID_MARGIN_MS&&dryer.t>=DRYER_MID_MARGIN_MS;
}

export function dogPresent() {
  // presence is the follow window AND the live follower. the lanyard is a line, not a flag.
  return state.freedDogFollowT>0
    &&Array.isArray(runtime.npcs)
    &&runtime.npcs.some(n=>n.id==='freed_dog_follower'&&!n.dead);
}

export function concessionConditionMet(venueId) {
  switch(venueId){
    case 'park': return isNight();
    case 'choir_office': return choirOfficeOpen();
    case 'underpass': return dogPresent();
    case 'laundromat': return dryerMidCycle();
    default: return false;
  }
}

export function concessionUnlocked(venueId) {
  if(!REGULAR_VENUE_BY_ID[venueId])return false;
  return recognitionTier(state.recognition&&state.recognition[venueId])==='conceded';
}

export function concessionAvailable(venueId) {
  return concessionUnlocked(venueId)&&concessionConditionMet(venueId);
}

// ---------- the two authored clocks (choir office hours, the dryer) ----------
// Office hours are b flat to b flat: the office is open while the choir holds the
// note, on the choir's own schedule, not the sun's. The dryer runs on professional
// courtesy; mid-cycle is the middle of the run, margins excluded. Both persist.
export const CHOIR_CLOSED_MIN_MS = 90000;
export const CHOIR_CLOSED_MAX_MS = 150000;
export const CHOIR_OPEN_MS = 55000;
export const DRYER_IDLE_MIN_MS = 50000;
export const DRYER_IDLE_MAX_MS = 90000;
export const DRYER_RUN_MS = 70000;
export const DRYER_MID_MARGIN_MS = 15000;

// The clocks carry their own tiny LCG instead of Math.random: the runtime smoke
// runs this build in lockstep against frozen v19 on one shared seeded random
// sequence, and a clock that ate from it would desynchronize the parity. The
// seed persists with the clocks, so the neighborhood's rhythm survives a load.
const CLOCK_SEED = 0x0bf1a75;
function clockRandom(clocks) {
  clocks.seed=(Math.imul(clocks.seed,1664525)+1013904223)>>>0;
  return clocks.seed/0x100000000;
}
function rollChoirClosed(clocks){ return CHOIR_CLOSED_MIN_MS+Math.floor(clockRandom(clocks)*(CHOIR_CLOSED_MAX_MS-CHOIR_CLOSED_MIN_MS)); }
function rollDryerIdle(clocks){ return DRYER_IDLE_MIN_MS+Math.floor(clockRandom(clocks)*(DRYER_IDLE_MAX_MS-DRYER_IDLE_MIN_MS)); }

export function freshConcessionClocks() {
  const clocks={seed:CLOCK_SEED,choir:null,dryer:null};
  clocks.choir={phase:'closed',t:rollChoirClosed(clocks)};
  clocks.dryer={phase:'idle',t:rollDryerIdle(clocks)};
  return clocks;
}

export function normalizeConcessionClocks(raw) {
  const clocks=freshConcessionClocks();
  if(!raw||typeof raw!=='object')return clocks;
  if(Number.isFinite(raw.seed))clocks.seed=raw.seed>>>0;
  const choir=raw.choir,dryer=raw.dryer;
  if(choir&&(choir.phase==='closed'||choir.phase==='open')&&Number.isFinite(choir.t)&&choir.t>0){
    const cap=choir.phase==='open'?CHOIR_OPEN_MS:CHOIR_CLOSED_MAX_MS;
    clocks.choir={phase:choir.phase,t:Math.min(cap,Math.floor(choir.t))};
  }
  if(dryer&&(dryer.phase==='idle'||dryer.phase==='running')&&Number.isFinite(dryer.t)&&dryer.t>0){
    const cap=dryer.phase==='running'?DRYER_RUN_MS:DRYER_IDLE_MAX_MS;
    clocks.dryer={phase:dryer.phase,t:Math.min(cap,Math.floor(dryer.t))};
  }
  return clocks;
}

// A clock turning over is world texture, but it only speaks to a player the
// venue has conceded to, and only if they are standing in it. An invisible
// condition is a bug; an advertised one is a different bug (I-CONCEDED-ONLY).
function announceClockTurn(venueId,line) {
  if(!concessionUnlocked(venueId))return;
  const venue=REGULAR_VENUE_BY_ID[venueId];
  if(!venue||!inZone(P.x+P.w/2,P.y+P.h/2,venue.zoneId))return;
  toast(line,2600);
}

export function updateConcessionClocks(dt) {
  if(!state.concessionClocks)state.concessionClocks=freshConcessionClocks();
  const clocks=state.concessionClocks;
  const choir=clocks.choir;
  choir.t-=dt;
  while(choir.t<=0){
    choir.phase=choir.phase==='open'?'closed':'open';
    choir.t+=choir.phase==='open'?CHOIR_OPEN_MS:rollChoirClosed(clocks);
    announceClockTurn('choir_office',choir.phase==='open'
      ? 'b flat begins.\nthe office is open.'
      : 'b flat ends.\nthe office is closed.');
  }
  const dryer=clocks.dryer;
  dryer.t-=dt;
  while(dryer.t<=0){
    dryer.phase=dryer.phase==='running'?'idle':'running';
    dryer.t+=dryer.phase==='running'?DRYER_RUN_MS:rollDryerIdle(clocks);
    announceClockTurn('laundromat',dryer.phase==='running'
      ? 'the dryer starts.\nprofessional courtesy resumes.'
      : 'the dryer stops.\nthe laundromat is just a room again.');
  }
}

// ---------- BAD IDEA targeting ----------
// The strip may target a concession only while its condition is TRUE; otherwise it
// points home (I-BAD-IDEA-HONEST). The Block is always legal. Ties go to the Block.
export function nearestLegalSpot(x,y,legalConcessionIds) {
  const block=SMOKE_SPOT_BY_ID.block;
  let best=null,bestD=Infinity,tied=false;
  for(const spot of SMOKE_SPOTS){
    if(spot.id!=='block'&&!legalConcessionIds.includes(spot.id))continue;
    const d=Math.hypot(spot.x-x,spot.y-y);
    if(d<bestD){best=spot;bestD=d;tied=false;}
    else if(d===bestD)tied=true;
  }
  return (tied||!best)?block:best;
}

export function badIdeaSmokeSpot(x,y) {
  const legal=SMOKE_SPOTS.filter(spot=>spot.id!=='block'&&concessionAvailable(spot.id)).map(spot=>spot.id);
  return nearestLegalSpot(x,y,legal);
}

// ---------- the rooms ----------
// Each concession answers the E key the way the block does: a small menu, one
// smoke option, one exit. The condition is stated, never explained.
function dryerStatusLine() {
  const clocks=state.concessionClocks,dryer=clocks&&clocks.dryer;
  if(dryerMidCycle())return 'mid-cycle.';
  if(dryer&&dryer.phase==='running')return 'running. not mid.';
  return 'idle.';
}

// v22 wave 5.2 — exported so discovery reuses the exact hint verb and
// qCondition wording; one source of truth per room, no drifting copies.
export const CONCESSION_TEXT = {
  park: {
    hint:'consult the bench',
    closedShort:'(the philosopher is awake.)',
    refusal:'the philosopher opens one eye.\nthe arrangement is off.',
    body:open=>open
      ? 'the bench is here. the philosopher pretends to be asleep.\nhe is not.'
      : 'the bench is here. the philosopher is awake.\nthe arrangement is off until dark.',
    qCondition:'night only',
    qStatus:()=>isNight()?'the philosopher is asleep enough.':'daylight.',
  },
  choir_office: {
    hint:'consult the office',
    closedShort:'(the office is closed.)',
    refusal:'b flat ends.\nthe office is closed.',
    body:open=>open
      ? 'the office is open. the choir is holding b flat.\na loose vent is louder.'
      : 'the office is closed.\noffice hours are b flat to b flat.\nthe schedule does not convert.',
    qCondition:'office hours · b flat to b flat',
    qStatus:()=>choirOfficeOpen()?'in session.':'closed.',
  },
  underpass: {
    hint:'consult the bridge',
    closedShort:'(the dog is elsewhere.)',
    refusal:'the dog has left.\nthe arrangement left with it.',
    body:open=>open
      ? 'the dog with the lanyard is here.\nthe dog does not know it is a condition.'
      : 'the dog is elsewhere.\nthe bridge tolerates you. the arrangement needs the dog.',
    qCondition:'while the dog is present',
    qStatus:()=>dogPresent()?'the dog is here.':'the dog is elsewhere.',
  },
  laundromat: {
    hint:'consult the dryer',
    closedShort:'(the dryer is not mid-cycle.)',
    refusal:'the dryer finished.\nthe cover is gone.',
    body:open=>open
      ? 'the dryer is mid-cycle. the dryer provides cover.\nthe dryer knows.'
      : (dryerStatusLine()==='running. not mid.'
        ? 'the dryer is running. it is not mid-cycle.\nthe margins count.'
        : 'the dryer is idle.\nprofessional courtesy is on break.'),
    qCondition:'mid-cycle only',
    qStatus:dryerStatusLine,
  },
};

export function concessionActionHint(x,y) {
  const venueId=recognitionVenueAt(x,y);
  if(!venueId||!concessionUnlocked(venueId))return '';
  return CONCESSION_TEXT[venueId]?CONCESSION_TEXT[venueId].hint:'';
}

// One line for the Q ledger, only after the venue has conceded. This is where
// choir office hours and the dryer state are readable from anywhere.
export function concessionQLine(venueId) {
  if(!concessionUnlocked(venueId))return '';
  const text=CONCESSION_TEXT[venueId];
  return text?'concession: '+text.qCondition+' · '+text.qStatus():'';
}

export function concessionMenu(venueId) {
  const spot=SMOKE_SPOT_BY_ID[venueId],venue=REGULAR_VENUE_BY_ID[venueId],text=CONCESSION_TEXT[venueId];
  if(!spot||!venue||!text||!concessionUnlocked(venueId))return;
  const totalRocks = (P.rocks||0) + (P.soapRocks||0);
  const open=concessionConditionMet(venueId);
  const opts=[];
  opts.push({
    label: totalRocks<=0 ? 'smoke a rock. (you have none.)'
      : open ? 'smoke a rock. (-1 rock, +18s rocked-up)'
      : 'smoke a rock. '+text.closedShort,
    disabled: totalRocks<=0||P.rockedT>0||!open,
    action: () => {
      // the condition is re-checked at ACTION, not at render (SPEC edge case —
      // decided once, stated here). today the world pauses during dialogue, so
      // the race is unreachable; the guard is for the world where it isn't.
      if(!concessionAvailable(venueId)){toast(text.refusal,2600);return;}
      smokeRockAt(venueId);
    }
  });
  opts.push({ label:'leave.', action:()=>{} });
  dialogue(venue.label, text.body(open)+'\nyour shakes are '+Math.round(P.shakes)+'. your brain is '+Math.round(P.brain)+'.', opts);
}

// ---------- THE ONE SMOKE TRANSACTION ----------
// Extracted from blockMenu() (activities.js) — the values below are the loop and
// are not editable here or anywhere. Royal static is Block-only: the coronation
// branch is guarded on the spot, not just the stage (I-BLOCK-CORONATION).
// The only venue-aware output is the feed line (I-VOICE). Soap is soap everywhere.
export function smokeRockAt(spotId) {
  const spot=SMOKE_SPOT_BY_ID[spotId];
  if(!spot)return;
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
  // v22 hitter — a real rock never inherits the hitter's rougher crash boundary.
  P.hitterHigh = false;
  P.rocks--; P.rockedT = 18000; P.crashT = 0; P.shakes = Math.max(0, P.shakes-50);
  P.brain = Math.max(0, P.brain-4); P.lifetime.rocksSmoked++;
  P.cred += 1;
  let royalStatic=false;
  if(spot.id==='block'&&state.kingdom&&state.kingdom.stage==='anoint'){
    state.kingdom.stage='emperor_gate';state.kingdom.marks=0;royalStatic=true;syncKingdomQuests();
  }
  audio.rockUp();
  state.flash = 1; state.flashColor = 'rgba(232,192,64,.5)';
  toast(royalStatic
    ? '· ROYAL STATIC ·\nthe sun moves. the throne ditch answers.\nbrain -4. shakes -50. emperor available.'
    : '· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50.', royalStatic?4300:2500);
  feedPost("smoked a rock at "+spot.feedName+". for the bit.", '@crackheadcent');
  if(royalStatic){broadcastNews('ROYAL STATIC RECEIVED. ONE DITCH ACKNOWLEDGES THE SIGNAL.');feedPost('the rock had a crown in the reception. the ditch is calling.','@blocklog');}
  applyRep({ street: 1, spiritual: -1 }); // wave 7 — smoking real rocks ledger
  // v13 wave 3 — completes the intro chain
  completeIntroSmoke();
  saveGame();
}

export function init_concessions() {
  state.concessionClocks=freshConcessionClocks();
}
