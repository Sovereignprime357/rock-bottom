/* v20 landing 3 — SMOKE CONCESSIONS (SPEC-v20-concessions.md, OD-5).
 * Owns the ONE smoke transaction (I-ONE-LOOP): the 18000ms/8000ms loop lives here
 * and nowhere else. Every spot — the Block and every earned concession — calls
 * smokeRockAt(). The loop that moved here is the loop that was at
 * activities.js blockMenu(), byte for byte. One loop, many rooms.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { isNight } from '../data/npc_spawns.js';
import { syncKingdomQuests } from './campaigns.js';
import { completeIntroSmoke } from './combat.js';
import { broadcastNews, feedPost } from './communications.js';
import { applyRep } from './factions.js';
import { REGULAR_VENUE_BY_ID, recognitionTier } from './recognition.js';

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

function rollChoirClosed(){ return CHOIR_CLOSED_MIN_MS+Math.floor(Math.random()*(CHOIR_CLOSED_MAX_MS-CHOIR_CLOSED_MIN_MS)); }
function rollDryerIdle(){ return DRYER_IDLE_MIN_MS+Math.floor(Math.random()*(DRYER_IDLE_MAX_MS-DRYER_IDLE_MIN_MS)); }

export function freshConcessionClocks() {
  return {
    choir:{phase:'closed',t:rollChoirClosed()},
    dryer:{phase:'idle',t:rollDryerIdle()},
  };
}

export function normalizeConcessionClocks(raw) {
  const clocks=freshConcessionClocks();
  if(!raw||typeof raw!=='object')return clocks;
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
