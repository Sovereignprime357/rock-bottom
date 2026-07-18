/* v22 emergency hitter — SPEC-v22-emergency-hitter.md (operator-ratified 2026-07-18).
 * A consumable that is strictly worse than a real rock over the FULL hit→high→crash
 * cycle (I-BAD-TRADE): shorter high, weaker relief, bigger brain hit, no cred, no
 * recognition credit, rougher crash. The reference transaction is smokeRockAt()
 * (concessions.js): an 18s high, shakes-50, brain-4, cred+1, then an 8s/+30 crash.
 * Every hitter number lives in this file so the trade stays tunable in one place
 * and hitter-gate can hold the ordering. Two ways in (I-COPPER-COST, I-RARE-FIND):
 * fold copper instead of selling it, or a rare opportunistic dumpster find. Neither
 * path nor the use adds a walk (I-NO-RUNWAY-COST): the pocket answers the E that
 * nothing else wanted, anywhere. Copper in, hitter out, never back (no loops).
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, state, toast } from '../core/runtime_ui.js';
import { feedPost } from './communications.js';

// The bad trade, one axis per line. Ordering vs the real rock is the invariant
// (hitter-gate); the exact numbers are the operator's knob.
export const HITTER_HIGH_MS = 6000;        // rock: 18000
export const HITTER_CRASH_MS = 14000;      // rock: 8000
export const HITTER_SHAKES_RELIEF = 20;    // rock: 50
export const HITTER_BRAIN_COST = 8;        // rock: 4
export const HITTER_CRASH_SHAKES = 35;     // rock: +30 at the boundary
export const HITTER_COPPER_COST = 2;       // ~$50-60 unsold at yuri; a rock is $10
export const HITTER_FIND_CHANCE = 0.04;    // rare (I-RARE-FIND); crafting is the supply

// One dumpster roll, one place. Adjacent-to-the-block dumpsters stay junk-only,
// same bias philosophy as the existing loot table.
export function dumpsterHitterRoll(farFactor) {
  return farFactor > 0.25 && Math.random() < HITTER_FIND_CHANCE;
}

export function grantFoundHitter() {
  P.hitters = (P.hitters || 0) + 1;
  audio.pickup();
  toast('+ the emergency hitter\n(it is still warm. you do not ask.)', 3000);
  feedPost('found a pipe in a dumpster. still warm. asked nothing.', '@crackheadcent');
  saveGame();
}

// Crafting is an inventory action: copper in, hitter out, never back.
export function craftHitter() {
  if ((P.copper || 0) < HITTER_COPPER_COST) return;
  P.copper -= HITTER_COPPER_COST;
  P.hitters = (P.hitters || 0) + 1;
  audio.pickup();
  toast('- ' + HITTER_COPPER_COST + ' pure copper\n+ 1 emergency hitter\nthe copper stops singing.', 3000);
  saveGame();
}

// ---------- THE OTHER TRANSACTION ----------
// Deliberately not smokeRockAt() and deliberately worse everywhere: no cred, no
// rep, no smoked-rock count, no intro credit, no royal static, and no full-high
// ledger entry (update.js skips the boundary credit for a hitter high — the room
// does not respect the pipe). The rougher crash lives at the update.js boundary,
// keyed on P.hitterHigh.
export function hitEmergencyHitter() {
  if ((P.hitters || 0) <= 0 || P.rockedT > 0) return;
  P.hitters--;
  P.rockedT = HITTER_HIGH_MS; P.crashT = 0; P.hitterHigh = true;
  P.shakes = Math.max(0, P.shakes - HITTER_SHAKES_RELIEF);
  P.brain = Math.max(0, P.brain - HITTER_BRAIN_COST);
  audio.hurt();
  state.flash = 1; state.flashColor = 'rgba(208,96,48,.4)';
  toast('· the emergency hitter ·\nit tastes like pennies.\nbrain -' + HITTER_BRAIN_COST + '. shakes -' + HITTER_SHAKES_RELIEF + '.', 2500);
  feedPost('hit the emergency pipe. it counts.', '@crackheadcent');
  saveGame();
}

// The pocket only answers when there is business in it (a hitter, or copper that
// could become one). Empty pockets keep the whiffed E silent, as before.
export function pocketHasBusiness() {
  return (P.hitters || 0) > 0 || (P.copper || 0) > 0;
}

// Zone-less verb, lowest priority: NPCs, doors, props, dumpsters, and every zone
// menu take the E first (interactions.js). Anywhere, no walk (I-NO-RUNWAY-COST).
export function pocketMenu() {
  const hitters = P.hitters || 0;
  const opts = [];
  opts.push({
    label: hitters <= 0 ? 'hit the emergency hitter. (you have none.)'
      : 'hit the emergency hitter. (-1 hitter, +' + (HITTER_HIGH_MS / 1000) + 's. it is not a rock.)',
    disabled: hitters <= 0 || P.rockedT > 0,
    action: () => hitEmergencyHitter(),
  });
  opts.push({
    label: (P.copper || 0) >= HITTER_COPPER_COST
      ? 'fold a hitter out of copper. (-' + HITTER_COPPER_COST + ' pure copper)'
      : 'fold a hitter out of copper. (you need ' + HITTER_COPPER_COST + ' pure copper.)',
    disabled: (P.copper || 0) < HITTER_COPPER_COST,
    action: () => craftHitter(),
  });
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('YOUR POCKETS', 'the pockets contain what they contain.\nhitters ' + hitters + ' · pure copper ' + (P.copper || 0) + '.\nyour shakes are ' + Math.round(P.shakes) + '.', opts);
}
