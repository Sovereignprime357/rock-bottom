// SMOKE CONCESSIONS — the one-loop gate (v20 landing 3).
// Proves, in order: (1) exactly one rockedT=18000 assignment site in src/ —
// structural, because a numeric check passes a copy-paste as happily as an
// extraction; (2) the smoke transaction is identical at all five spots (full
// P-fingerprint diff, reused from the recognition gate) except the feed text,
// and soap is soap everywhere; (3) each concession rejects below conceded,
// rejects with its condition false (including a stale menu), accepts with
// both; (4) royal static is Block-only — this check goes red if the spot
// guard is removed (verified red on 2026-07-16 before shipping); (5) BAD IDEA
// targeting is always legal across all 16 condition combinations, nearer wins,
// ties go to the Block; (6) a condition killed 1ms after ignition still yields
// the full 18000ms high and 8000ms crash; (7) the two authored clocks persist
// and normalize.
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const failures = [];
const fail = m => failures.push(m);

// ---- 1. Single-site: the loop exists once, by construction ------------------
const srcFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) srcFiles.push(full);
  }
})(path.join(ROOT, 'src'));
const ignitionSites = [], crashSites = [];
for (const file of srcFiles) {
  const text = fs.readFileSync(file, 'utf8');
  if (/\brockedT\s*=\s*18000\b/.test(text)) ignitionSites.push(path.relative(ROOT, file));
  if (/\bcrashT\s*=\s*8000\b/.test(text)) crashSites.push(path.relative(ROOT, file));
}
if (ignitionSites.length !== 1) fail(`rockedT=18000 assignment sites: ${ignitionSites.length} (${ignitionSites.join(', ')}), expected exactly 1`);
else if (!ignitionSites[0].endsWith('concessions.js')) fail(`the one ignition site lives in ${ignitionSites[0]}, expected src/systems/concessions.js`);
if (crashSites.length !== 1) fail(`crashT=8000 assignment sites: ${crashSites.length} (${crashSites.join(', ')}), expected exactly 1 (the update.js boundary)`);

// ---- harness boot -----------------------------------------------------------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);

const concessions = module('src/systems/concessions.js');
const recognition = module('src/systems/recognition.js');
const runtimeUi = module('src/core/runtime_ui.js');
const world = module('src/data/world.js');
const communications = module('src/systems/communications.js');
const audioSave = module('src/core/audio_save.js');

const {
  SMOKE_SPOTS, SMOKE_SPOT_BY_ID, smokeRockAt, concessionMenu, concessionUnlocked,
  concessionConditionMet, concessionAvailable, badIdeaSmokeSpot, nearestLegalSpot,
  freshConcessionClocks, normalizeConcessionClocks,
  CHOIR_OPEN_MS, DRYER_RUN_MS, DRYER_MID_MARGIN_MS,
} = concessions;
const { REGULAR_VENUES, freshRecognition } = recognition;
const P = runtimeUi.P, state = runtimeUi.state, runtime = runtimeUi.runtime;
const ZONES = world.ZONES;
const CONCESSION_IDS = ['park', 'choir_office', 'underpass', 'laundromat'];

function standIn(venueId) {
  const venue = REGULAR_VENUES.find(v => v.id === venueId);
  const z = ZONES.find(z => z.id === venue.zoneId);
  P.x = z.x + z.w / 2 - P.w / 2;
  P.y = z.y + z.h / 2 - P.h / 2;
}
function standAtBlock() { P.x = 1064 - P.w / 2; P.y = 882 - P.h / 2; }

function grantConceded() {
  for (const id of CONCESSION_IDS) state.recognition[id].buy = 15;
}
function setCondition(venueId, on) {
  const clocks = state.concessionClocks;
  if (venueId === 'park') state.dayTime = on ? 0.9 : 0.5;
  else if (venueId === 'choir_office') clocks.choir = on ? { phase: 'open', t: 30000 } : { phase: 'closed', t: 60000 };
  else if (venueId === 'laundromat') clocks.dryer = on ? { phase: 'running', t: 35000 } : { phase: 'idle', t: 40000 };
  else if (venueId === 'underpass') {
    runtime.npcs = runtime.npcs.filter(n => n.id !== 'freed_dog_follower');
    if (on) {
      runtime.npcs.push({ id: 'freed_dog_follower', dead: false, x: P.x + 30, y: P.y, w: 24, h: 20 });
      state.freedDogFollowT = 30000;
    } else state.freedDogFollowT = 0;
  }
}
function resetSmoker() {
  P.rocks = 3; P.soapRocks = 0; P.rockedT = 0; P.crashT = 0;
  P.shakes = 80; P.brain = 50; P.cred = 10;
  // accumulating ledgers return to one baseline so the identity fixture compares
  // per-smoke deltas, not fixture history; also keeps faction tier crossings
  // (which post their own feed lines) out of the frame.
  P.lifetime.rocksSmoked = 0;
  P.faction = { street: 0, scrap: 0, spiritual: 0 };
}
function fingerprint() {
  const p = {};
  for (const key of Object.keys(P)) p[key] = P[key];
  return JSON.parse(JSON.stringify(p));
}
function delta(before, after) {
  const d = {};
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  for (const key of keys) {
    const b = JSON.stringify(before[key]), a = JSON.stringify(after[key]);
    if (b !== a) d[key] = [b, a];
  }
  return d;
}

// burn the one-time intro completion + soap achievement so first-run side
// effects cannot masquerade as venue-dependent deltas in the identity fixture.
state.mode = 'playing';
resetSmoker();
standAtBlock();
smokeRockAt('block');
P.rockedT = 0; P.crashT = 0;
P.soapRocks = 1;
smokeRockAt('block');
resetSmoker();

// ---- 3. Gating: below conceded, condition false, both true ------------------
// (runs before conceded is granted so 'stranger' is genuinely stranger)
state.recognition = freshRecognition();
for (const venueId of CONCESSION_IDS) {
  standIn(venueId);
  setCondition(venueId, true);
  resetSmoker();
  const before = JSON.stringify(fingerprint());
  concessionMenu(venueId);
  if (runtimeUi.activeDialogue) fail(`${venueId}: menu opened below conceded tier (I-CONCEDED-ONLY)`);
  runtimeUi.closeDialogue();
  if (JSON.stringify(fingerprint()) !== before) fail(`${venueId}: state moved on a below-tier menu attempt`);
}
grantConceded();
for (const venueId of CONCESSION_IDS) {
  standIn(venueId);
  resetSmoker();
  // condition false: the room opens (legibility) but the option is disabled
  setCondition(venueId, false);
  concessionMenu(venueId);
  if (!runtimeUi.activeDialogue) { fail(`${venueId}: conceded venue did not open its room`); continue; }
  const closedOpt = runtimeUi.activeDialogue.opts[0];
  if (!closedOpt.disabled) fail(`${venueId}: smoke option enabled while condition false`);
  const beforeClosed = JSON.stringify(fingerprint());
  closedOpt.action();                       // a stale menu is a lie unless the ACTION re-checks
  if (P.rockedT !== 0 || JSON.stringify(fingerprint()) !== beforeClosed) fail(`${venueId}: smoked with condition false (action re-check missing)`);
  runtimeUi.closeDialogue();
  // condition flips false between render and action: the re-check must refuse
  setCondition(venueId, true);
  concessionMenu(venueId);
  const staleOpt = runtimeUi.activeDialogue && runtimeUi.activeDialogue.opts[0];
  if (!staleOpt || staleOpt.disabled) fail(`${venueId}: smoke option not enabled with condition true`);
  setCondition(venueId, false);
  if (staleOpt) staleOpt.action();
  if (P.rockedT !== 0) fail(`${venueId}: race — condition died after render and the smoke still fired`);
  runtimeUi.closeDialogue();
  // both true: accepted
  setCondition(venueId, true);
  concessionMenu(venueId);
  const openOpt = runtimeUi.activeDialogue && runtimeUi.activeDialogue.opts[0];
  if (openOpt) openOpt.action();
  runtimeUi.closeDialogue();
  if (P.rockedT !== 18000 || P.rocks !== 2) fail(`${venueId}: conceded + condition true did not smoke (rockedT ${P.rockedT}, rocks ${P.rocks})`);
  P.rockedT = 0; P.crashT = 0;
}

// ---- 2. Identity: one loop, many rooms (reward-fingerprint diff) ------------
const realDeltas = {}, soapDeltas = {};
for (const spot of SMOKE_SPOTS) {
  if (spot.id === 'block') standAtBlock(); else { standIn(spot.id); setCondition(spot.id, true); }
  // real rock
  resetSmoker();
  let before = fingerprint();
  smokeRockAt(spot.id);
  realDeltas[spot.id] = JSON.stringify(delta(before, fingerprint()));
  const post = communications.phoneState.posts[0];
  const expected = 'smoked a rock at ' + spot.feedName + '. for the bit.';
  if (!post || post.t !== expected) fail(`${spot.id}: feed said ${JSON.stringify(post && post.t)}, expected ${JSON.stringify(expected)} (I-VOICE)`);
  // soap rock (I-SOAP-PARITY)
  resetSmoker();
  P.soapRocks = 1;
  before = fingerprint();
  smokeRockAt(spot.id);
  soapDeltas[spot.id] = JSON.stringify(delta(before, fingerprint()));
  if (P.rockedT !== 0) fail(`${spot.id}: soap produced a high`);
  const soapPost = communications.phoneState.posts[0];
  if (!soapPost || soapPost.t !== 'smoked soap. tasted it. did it again.') fail(`${spot.id}: soap feed line drifted`);
}
for (const id of Object.keys(realDeltas)) {
  if (realDeltas[id] !== realDeltas.block) fail(`real smoke delta at ${id} differs from the block:\n  block: ${realDeltas.block}\n  ${id}: ${realDeltas[id]}`);
  if (soapDeltas[id] !== soapDeltas.block) fail(`soap delta at ${id} differs from the block (soap is soap everywhere)`);
}
const blockRealDelta = JSON.parse(realDeltas.block);
if (!blockRealDelta.rockedT || JSON.parse(blockRealDelta.rockedT[1]) !== 18000) fail('real smoke did not set the 18000ms high');
if (!blockRealDelta.brain || JSON.parse(blockRealDelta.brain[1]) !== 46) fail('real smoke brain delta drifted from -4');
if (!blockRealDelta.shakes || JSON.parse(blockRealDelta.shakes[1]) !== 30) fail('real smoke shakes delta drifted from -50');
if (!blockRealDelta.cred || JSON.parse(blockRealDelta.cred[1]) !== 11) fail('real smoke cred delta drifted from +1');
P.rockedT = 0; P.crashT = 0;

// ---- 5. BAD IDEA: 16 combinations, always legal, nearer wins, ties home -----
const PROBES = [[1600, 1150], [2500, 1100], [6800, 3100], [1064, 882]];
for (let mask = 0; mask < 16; mask++) {
  const legalNow = CONCESSION_IDS.filter((_, i) => mask & (1 << i));
  for (const venueId of CONCESSION_IDS) setCondition(venueId, legalNow.includes(venueId));
  for (const [x, y] of PROBES) {
    const spot = badIdeaSmokeSpot(x, y);
    if (spot.id !== 'block' && !legalNow.includes(spot.id)) fail(`mask ${mask}: strip targeted illegal spot ${spot.id} (I-BAD-IDEA-HONEST)`);
    const pure = nearestLegalSpot(x, y, legalNow);
    if (spot.id !== pure.id) fail(`mask ${mask} at (${x},${y}): live targeting ${spot.id} != pure ${pure.id} (predicate wiring)`);
    const dTarget = Math.hypot(spot.x - x, spot.y - y);
    for (const otherId of ['block', ...legalNow]) {
      if (Math.hypot(SMOKE_SPOT_BY_ID[otherId].x - x, SMOKE_SPOT_BY_ID[otherId].y - y) < dTarget) fail(`mask ${mask} at (${x},${y}): ${otherId} is nearer than target ${spot.id}`);
    }
  }
}
// two true, one nearer: laundromat beats underpass and the block from (1450,900)
for (const venueId of CONCESSION_IDS) setCondition(venueId, venueId === 'underpass' || venueId === 'laundromat');
if (badIdeaSmokeSpot(1450, 900).id !== 'laundromat') fail('nearer legal concession (laundromat) not selected over underpass/block');
// exact tie with the block goes to the block
for (const venueId of CONCESSION_IDS) setCondition(venueId, venueId === 'laundromat');
if (badIdeaSmokeSpot(1302, 1036).id !== 'block') fail('block/laundromat exact tie did not go to the block');
// exact tie between two concessions (block farther) still goes to the block
for (const venueId of CONCESSION_IDS) setCondition(venueId, venueId === 'underpass' || venueId === 'laundromat');
if (badIdeaSmokeSpot(1795, 605).id !== 'block') fail('underpass/laundromat exact tie did not go to the block');

// ---- 6. Mid-high expiry: the world tolerates what it already tolerated ------
standIn('laundromat');
setCondition('laundromat', true);
resetSmoker();
state.mode = 'playing';
concessionMenu('laundromat');
const igniteOpt = runtimeUi.activeDialogue && runtimeUi.activeDialogue.opts[0];
if (igniteOpt) igniteOpt.action();
runtimeUi.closeDialogue();
state.mode = 'playing';
if (P.rockedT !== 18000) fail(`expiry fixture failed to ignite (rockedT ${P.rockedT})`);
context.window._rb.updateWorld(1);
setCondition('laundromat', false);            // the dryer finishes 1ms into the high
context.window._rb.updateWorld(17999);
if (P.rockedT !== 0 || P.crashT !== 8000) fail(`condition death truncated the high (${P.rockedT} -> ${P.crashT}, expected 0 -> 8000)`);
context.window._rb.updateWorld(8000);
if (P.crashT !== 0) fail(`crash did not run its full 8000ms (${P.crashT})`);

// ---- 4. Coronation: royal static is not portable -----------------------------
state.kingdom.stage = 'anoint';
for (const venueId of CONCESSION_IDS) {
  standIn(venueId);
  setCondition(venueId, true);
  resetSmoker();
  smokeRockAt(venueId);
  if (state.kingdom.stage !== 'anoint') fail(`royal static fired at ${venueId} (stage -> ${state.kingdom.stage}); the coronation left the block`);
  state.kingdom.stage = 'anoint';
  P.rockedT = 0; P.crashT = 0;
}
standAtBlock();
resetSmoker();
smokeRockAt('block');
if (state.kingdom.stage !== 'emperor_gate') fail(`anoint smoke at the block did not advance the coronation (stage ${state.kingdom.stage})`);
P.rockedT = 0; P.crashT = 0;

// ---- 7. The two clocks persist and normalize ---------------------------------
state.concessionClocks = { seed: 12345, choir: { phase: 'open', t: 12345 }, dryer: { phase: 'running', t: 23456 } };
await audioSave.saveGame();
const stored = await context.window.storage.get(audioSave.SAVE_KEY);
if (!stored?.value?.concessionClocks) fail('concessionClocks key absent from save payload');
if (stored?.value?.version !== 10) fail(`save version drifted to ${stored?.value?.version}, expected additive 10`);
state.concessionClocks = freshConcessionClocks();
const loaded = await audioSave.loadGame();
if (!loaded) fail('loadGame returned falsy for a clock-bearing save');
const clocks = state.concessionClocks;
if (clocks.choir.phase !== 'open' || clocks.choir.t !== 12345 || clocks.dryer.phase !== 'running' || clocks.dryer.t !== 23456 || clocks.seed !== 12345) {
  fail(`clocks did not survive save/load roundtrip: ${JSON.stringify(clocks)}`);
}
const garbage = normalizeConcessionClocks({ seed: 'x', choir: { phase: 'open', t: 9e9 }, dryer: { phase: 'spin', t: -5 } });
if (garbage.choir.t !== CHOIR_OPEN_MS) fail(`open-phase clock not capped to CHOIR_OPEN_MS (${garbage.choir.t})`);
if (garbage.dryer.phase !== 'idle') fail(`malformed dryer phase survived normalization (${garbage.dryer.phase})`);
if (normalizeConcessionClocks(null).choir.t <= 0) fail('null clocks did not normalize to a fresh cycle');
// mid-cycle boundary maths: margins excluded on both ends
state.concessionClocks.dryer = { phase: 'running', t: DRYER_RUN_MS - DRYER_MID_MARGIN_MS + 1 };
if (concessionConditionMet('laundromat')) fail('mid-cycle began before the leading margin elapsed');
state.concessionClocks.dryer = { phase: 'running', t: DRYER_MID_MARGIN_MS - 1 };
if (concessionConditionMet('laundromat')) fail('mid-cycle survived into the trailing margin');
state.concessionClocks.dryer = { phase: 'running', t: DRYER_RUN_MS / 2 };
if (!concessionConditionMet('laundromat')) fail('the middle of the run does not count as mid-cycle');

if (failures.length) {
  console.error(`CONCESSION GATE: ${failures.length} failure(s)`);
  failures.forEach(f => console.error(`- ${f}`));
  process.exit(1);
}
console.log('CONCESSION GATE: PASS (1 ignition site, 5-spot identity + soap parity, tier/condition/race gating, Block-only coronation, 16-combo honest BAD IDEA + tie->block, mid-high expiry 18000->8000, clock persistence)');
