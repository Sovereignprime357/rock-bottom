/* v22 wave 5.2 — SMOKE-SPOT DISCOVERY (SPEC-v22-smoke-discovery.md).
 * The map, not the key (I-MAP-NOT-KEY): this module flips one per-venue
 * `discovered` boolean and nothing else. It never touches state.recognition,
 * never credits a verb, never reads a threshold to change it. A discovered
 * venue and an undiscovered one at the same visit count are mechanically
 * identical; only the UI differs (I-REVEAL-IS-COSMETIC). Every teller's
 * reveal routes through tellVenue() below, so the whole door lives in this
 * file — and discovery-gate proves the door is shut.
 */
import { saveGame } from '../core/audio_save.js';
import { dialogue, state, toast } from '../core/runtime_ui.js';
import { feedPost } from './communications.js';
import { CONCESSION_TEXT, concessionUnlocked } from './concessions.js';
import { REGULAR_VENUE_BY_ID, recognitionVenueAt } from './recognition.js';

// Per-venue keeper line: who has not conceded yet. Used by the Q ledger and
// the known-but-unearned room (I-STILL-EARNED phrasing).
export const DISCOVERY_TEXT = Object.freeze({
  park:         Object.freeze({ keeper:'the bench does not know you yet.' }),
  laundromat:   Object.freeze({ keeper:'the dryer does not know you yet.' }),
  underpass:    Object.freeze({ keeper:'the bridge does not know you yet.' }),
  choir_office: Object.freeze({ keeper:'the office does not know you yet.' }),
});

export function freshDiscovered() { return new Set(); }

// The Block is unconditional and always known; it is not a venue id and can
// never enter the set. Unknown ids and non-strings are dropped, not kept.
export function normalizeDiscovered(raw) {
  const out=new Set();
  const list=Array.isArray(raw)?raw:[];
  for(const id of list)if(typeof id==='string'&&Object.hasOwn(REGULAR_VENUE_BY_ID,id))out.add(id);
  out.delete('block');
  return out;
}

export function venueDiscovered(venueId) {
  return !!(state.discoveredVenues instanceof Set&&state.discoveredVenues.has(venueId));
}

// Flips visibility. Returns 'revealed' on the first telling, 'known' after,
// '' for a non-venue. Writes the discovered set and nothing else.
export function discoverVenue(venueId) {
  if(!Object.hasOwn(REGULAR_VENUE_BY_ID,venueId))return '';
  if(!(state.discoveredVenues instanceof Set))state.discoveredVenues=freshDiscovered();
  if(state.discoveredVenues.has(venueId))return 'known';
  state.discoveredVenues.add(venueId);
  saveGame();
  return 'revealed';
}

// A teller's reveal: the fact lands, the flag flips, nothing is granted.
// Second telling is flavor, not a re-grant. Telling a player about a room
// they already conceded acknowledges it and changes nothing.
export function tellVenue(venueId, revealText, repeatText, feedLine) {
  const result=discoverVenue(venueId);
  if(!result)return;
  if(result==='known'){toast(repeatText,3000);return;}
  const conceded=concessionUnlocked(venueId);
  toast(revealText+(conceded?'\nyou already know.\nthe room knows you know.':''),conceded?4200:3600);
  if(feedLine)feedPost(feedLine,'@crackheadcent');
}

// The E hint for a discovered-but-unconceded venue: the same verb the room
// will answer to once conceded. Conceded venues keep their own hint
// (concessions.js); undiscovered venues say nothing.
export function discoveryActionHint(x,y) {
  const venueId=recognitionVenueAt(x,y);
  if(!venueId||!venueDiscovered(venueId)||concessionUnlocked(venueId))return '';
  return CONCESSION_TEXT[venueId]?CONCESSION_TEXT[venueId].hint:'';
}

// One Q-ledger line for a known-but-unearned room. States the condition as a
// fact and never the current now-ness — a room you cannot use yet is never
// advertised as usable now (the honesty rule carries over).
export function discoveryQLine(venueId) {
  if(!venueDiscovered(venueId)||concessionUnlocked(venueId))return '';
  const text=CONCESSION_TEXT[venueId],known=DISCOVERY_TEXT[venueId];
  if(!text||!known)return '';
  return 'known: '+text.qCondition+' · '+known.keeper;
}

// The known-but-unearned room. Refuses to open over a conceded room (that
// one belongs to concessions.js) or an undiscovered one (still a secret).
export function discoveryMenu(venueId) {
  const venue=REGULAR_VENUE_BY_ID[venueId],text=CONCESSION_TEXT[venueId],known=DISCOVERY_TEXT[venueId];
  if(!venue||!text||!known)return;
  if(!venueDiscovered(venueId)||concessionUnlocked(venueId))return;
  dialogue(venue.label,'you know this counts.\n'+known.keeper+'\n('+text.qCondition+'.)',[
    { label:'leave.', action:()=>{} },
  ]);
}

export function init_discovery() {
  state.discoveredVenues=freshDiscovered();
}
