/* v22 robbery — SPEC-v22-robbery.md (the economy's first sink).
 * In SKID ROW the grabber does not just hurt you — he takes something: cash, a
 * losable inventory item, an emergency hitter, or an equipped piece of clothing
 * that comes off your sprite (I-VISIBLE: drawPlayer reads P.equip per frame, so
 * nulling the slot IS the visible loss). It only subtracts (I-SINK-ONLY): no
 * drop in exchange, no resist roll, no timer that gives it back, no reclaim
 * quest (I-NO-RECOVERY-GUARANTEE). The mercy is the RATE, not the outcome: a
 * world-clock cooldown plus a daily cap (I-BOUNDED-RATE) so a crossing stings
 * instead of stripping. What can be taken is an ALLOWLIST (I-NO-SOFTLOCK):
 * default un-takeable, classes opt IN — a progression key added next wave is
 * safe by default, not by somebody remembering a denylist. Only the NPC def
 * carrying `robs: true` robs (I-ZONE-SCOPED): that is the skid grabber, no one
 * else. Every robbery number lives in this file; robbery-gate holds the shape.
 */
import { saveGame } from '../core/audio_save.js';
import { P, applyEquipStats, state, toast } from '../core/runtime_ui.js';
import { EQUIPMENT } from '../data/catalogs.js';
import { feedPost } from './communications.js';

// The governor (I-BOUNDED-RATE). Cooldown runs on the world clock (day +
// dayTime), so it needs no per-frame tick, survives save/load for free, and
// sleeping it off is a thing a person would do.
export const ROB_COOLDOWN_MS = 60000;   // one 4-min day is 240000ms
export const ROB_DAILY_CAP = 2;
export const ROB_CASH_MIN = 5;
export const ROB_CASH_MAX = 15;

// THE ALLOWLIST (I-NO-SOFTLOCK). Default un-takeable; a class must opt in.
// Deliberately absent: stripe_package, crossword, bus_pass (progression /
// route-gating), rocks (the intro needs one), and every id nobody vetted.
export const LOSABLE_INVENTORY_IDS = new Set([
  'junk', 'food', 'soap', 'detergent', 'cone', 'gold_tooth', 'lottery', 'license',
]);
// Cosmetic clothing slots only — never 'tool' (the torch gates cook mode 4 and
// the leasing-guy transaction).
export const LOSABLE_EQUIP_SLOTS = ['coat', 'hat', 'shoes'];
// And within those slots, only ordinary clothes. Deliberately absent:
// pigeon_crown and priest_collar (uniques the world cannot re-issue — "the
// last of something"), propane_torch (wrong slot anyway; belt and suspenders).
export const LOSABLE_EQUIP_IDS = new Set([
  'trench', 'windbreaker', 'bathrobe', 'parka',
  'mesh_cap', 'ski_mask', 'helmet', 'cowboy',
  'crocs', 'walmart_sneak', 'vibrams', 'airpods',
]);

const SLOT_BEATS = {
  coat:  'he does not put it on.\nhe just holds it.',
  hat:   'he checks the size.\nhe says nothing.',
  shoes: 'he holds them by the laces.',
};

export function robberyWorldClockMs() {
  return (state.day + state.dayTime) * 240000;
}

export function robberyReady() {
  if ((state.counters.robberiesToday || 0) >= ROB_DAILY_CAP) return false;
  return robberyWorldClockMs() - (state.counters.robLastClockMs || 0) >= ROB_COOLDOWN_MS;
}

// The take. Called from the grabber's landed grab (npc_ai.js) when the NPC def
// carries `robs: true`. Resolves atomically — the thing is gone before the save.
export function attemptRobbery(n) {
  if (!n || !n.robs || n.dead) return false;
  if (!robberyReady()) return false;

  // candidates come from the allowlist and nowhere else
  const candidates = [];
  for (const slot of LOSABLE_EQUIP_SLOTS) {
    const id = P.equip && P.equip[slot];
    if (id && LOSABLE_EQUIP_IDS.has(id)) candidates.push({ kind: 'equip', slot, id });
  }
  P.inventory.forEach((item, idx) => {
    if (LOSABLE_INVENTORY_IDS.has(item.id)) candidates.push({ kind: 'item', idx, item });
  });
  if ((P.hitters || 0) > 0) candidates.push({ kind: 'hitter' });
  if (P.cash > 0) candidates.push({ kind: 'cash' });

  // an attempt spends the governor either way — the near-miss beat is not free
  state.counters.robLastClockMs = robberyWorldClockMs();
  state.counters.robberiesToday = (state.counters.robberiesToday || 0) + 1;

  const pick = candidates.length ? candidates[Math.floor(Math.random() * candidates.length)] : null;
  if (!pick) {
    toast(n.name + ' checks your pockets.\nfinds a receipt.\nkeeps the receipt.', 3200);
    saveGame();
    return true;
  }

  if (pick.kind === 'equip') {
    const worn = EQUIPMENT[pick.id] ? EQUIPMENT[pick.id].n : pick.id;
    P.equip[pick.slot] = null;
    applyEquipStats();
    toast('- ' + worn + '\n' + n.name + ' takes your ' + pick.slot + '.\n' + SLOT_BEATS[pick.slot], 3600);
    feedPost("lurch is holding somebody's " + pick.slot + ' on skid row. just holding it.', '@local_eyewitness');
  } else if (pick.kind === 'item') {
    const item = pick.item;
    if ((item.q || 1) > 1) item.q--;
    else P.inventory.splice(pick.idx, 1);
    toast('- ' + item.n + '\n' + n.name + ' takes it.\nhe does not ask what it is. neither did you.', 3200);
  } else if (pick.kind === 'hitter') {
    P.hitters--;
    toast('- the emergency hitter\n' + n.name + ' takes the pipe.\nhe knows what it is.', 3200);
  } else {
    const amt = Math.min(P.cash, ROB_CASH_MIN + Math.floor(Math.random() * (ROB_CASH_MAX - ROB_CASH_MIN + 1)));
    P.cash -= amt;
    toast('- $' + amt + '\n' + n.name + ' counts it in front of you.\nthe math is correct.', 3200);
  }
  // no extra sound: the landed grab already paid audio.hurt() in damagePlayer.
  saveGame();
  return true;
}
