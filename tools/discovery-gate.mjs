// SMOKE-SPOT DISCOVERY — the map-not-key gate (v22 wave 5.2).
// The leak recognition-gate cannot see: discovery routes AROUND the ledger,
// so the zero-reward-leakage proof stays green even if a reveal grants tier —
// the leak comes through a door that gate does not watch. This gate watches
// the door. It proves, in order: (1) structurally, the discovery module and
// the reveal path cannot name a recognition writer, and the discovered set is
// written nowhere else; (2) discoverVenue leaves the entire recognition
// ledger, tier, condition, and reward state BYTE-IDENTICAL at stranger,
// counted, furniture, and conceded counts; (3) the same holds through the
// real door — the three teller dialogue options — including idempotent
// second tellings; (4) the Block can never enter the discovered set;
// (5) visibility is exactly the contract: hidden until told, known-but-
// unearned after, conceded rooms unchanged, and the unearned room grants
// nothing when used; (6) discovery and recognition stay orthogonal — 14
// visits is not conceded with the flag set, 15 is conceded without it;
// (7) the set save-roundtrips and a pre-5.2 save loads all-undiscovered.
// Red-verified 2026-07-18: a reveal wired to credit the ledger, a Block
// admitted to the set, and a dropped save key each turn this gate red.
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const failures = [];
const fail = m => failures.push(m);

// ---- 1. Structural: the door has one frame and no ledger vocabulary ---------
// comment-stripped before scanning (docs-gate's lesson): a comment naming the
// forbidden thing is documentation, not a violation — and vice versa.
const stripComments = text => text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:'"])\/\/[^\n]*/g, '$1');
const discoverySource = stripComments(fs.readFileSync(path.join(ROOT, 'src/systems/discovery.js'), 'utf8'));
for (const forbidden of ['state.recognition', 'recordRecognition', 'recordNpcBother', 'recordFullHighAtPlayer', 'REGULAR_THRESHOLDS']) {
  if (discoverySource.includes(forbidden)) fail(`discovery.js names '${forbidden}' — the map module may not hold ledger vocabulary`);
}
const srcFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) srcFiles.push(full);
  }
})(path.join(ROOT, 'src'));
for (const file of srcFiles) {
  const rel = path.relative(ROOT, file).replaceAll('\\', '/');
  const text = fs.readFileSync(file, 'utf8');
  const code = stripComments(text);
  if (rel !== 'src/systems/discovery.js' && /\bdiscoverVenue\s*\(/.test(code)) {
    fail(`${rel} calls discoverVenue directly; reveals route through tellVenue so the whole door stays in discovery.js`);
  }
  if (!['src/systems/discovery.js', 'src/core/audio_save.js'].includes(rel) && code.includes('state.discoveredVenues')) {
    fail(`${rel} touches state.discoveredVenues; only discovery.js (owner) and audio_save.js (persistence) may`);
  }
}

// ---- harness boot -----------------------------------------------------------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);

const discovery = module('src/systems/discovery.js');
const recognition = module('src/systems/recognition.js');
const concessions = module('src/systems/concessions.js');
const runtimeUi = module('src/core/runtime_ui.js');
const world = module('src/data/world.js');
const audioSave = module('src/core/audio_save.js');
const communications = module('src/systems/communications.js');
const dialogueA = module('src/dialogue/neighborhood_a.js');

const {
  DISCOVERY_TEXT, freshDiscovered, normalizeDiscovered, venueDiscovered,
  discoverVenue, tellVenue, discoveryActionHint, discoveryQLine, discoveryMenu,
} = discovery;
const { REGULAR_VENUES, REGULAR_THRESHOLDS, freshRecognition, recognitionTier } = recognition;
const { CONCESSION_TEXT, concessionUnlocked, concessionConditionMet, concessionActionHint, concessionQLine } = concessions;
const P = runtimeUi.P, state = runtimeUi.state, ZONES = world.ZONES;
const VENUE_IDS = ['park', 'laundromat', 'underpass', 'choir_office'];

function standIn(venueId) {
  const venue = REGULAR_VENUES.find(v => v.id === venueId);
  const z = ZONES.find(z => z.id === venue.zoneId);
  P.x = z.x + z.w / 2 - P.w / 2;
  P.y = z.y + z.h / 2 - P.h / 2;
}
function centerOf(venueId) {
  const venue = REGULAR_VENUES.find(v => v.id === venueId);
  const z = ZONES.find(z => z.id === venue.zoneId);
  return [z.x + z.w / 2, z.y + z.h / 2];
}
// forbidden-state fingerprint (recognition-gate's): discovery may NEVER move these
function rewardFingerprint() {
  return JSON.stringify({
    cash: P.cash, rocks: P.rocks, hp: P.hp, maxHp: P.maxHp, shakes: P.shakes,
    brain: P.brain, cred: P.cred, rank: P.rank, speed: P.speed, copper: P.copper,
    supplies: P.supplies, wanted: P.wanted, rockedT: P.rockedT, crashT: P.crashT,
    inv: (P.inventory || []).length, equip: JSON.stringify(P.equip || {}),
    faction: JSON.stringify(P.faction || {}), day: state.day,
  });
}
// the whole mechanical surface of a venue, as bytes
function venueMechanics(venueId) {
  return JSON.stringify({
    ledger: state.recognition,
    tier: recognitionTier(state.recognition[venueId]),
    unlocked: concessionUnlocked(venueId),
    condition: concessionConditionMet(venueId),
    thresholds: REGULAR_THRESHOLDS,
  });
}

// ---- 2. Byte-identical at every tier: the reveal is cosmetic ---------------
for (const venueId of VENUE_IDS) {
  for (const count of [0, 7, 14, 15]) {
    state.recognition = freshRecognition();
    state.recognition[venueId].buy = count;
    state.discoveredVenues = freshDiscovered();
    const beforeMechanics = venueMechanics(venueId);
    const beforeReward = rewardFingerprint();
    const result = discoverVenue(venueId);
    if (result !== 'revealed') fail(`${venueId}@${count}: first discoverVenue returned '${result}', expected 'revealed'`);
    if (!venueDiscovered(venueId)) fail(`${venueId}@${count}: flag did not flip`);
    if (venueMechanics(venueId) !== beforeMechanics) fail(`${venueId}@${count}: discovery moved venue mechanics (I-REVEAL-IS-COSMETIC)\n  before: ${beforeMechanics}\n  after:  ${venueMechanics(venueId)}`);
    if (rewardFingerprint() !== beforeReward) fail(`${venueId}@${count}: discovery moved reward state (I-MAP-NOT-KEY)`);
    // second telling: idempotent, still byte-identical
    if (discoverVenue(venueId) !== 'known') fail(`${venueId}@${count}: second discoverVenue was not 'known'`);
    if (state.discoveredVenues.size !== 1) fail(`${venueId}@${count}: repeat discovery grew the set`);
    if (venueMechanics(venueId) !== beforeMechanics) fail(`${venueId}@${count}: repeat discovery moved mechanics`);
  }
}

// ---- 3. Through the real door: the three tellers ---------------------------
const TELLERS = [
  { fn: dialogueA.lurchDialogue, label: 'ask where he sleeps.', venueId: 'underpass', feed: 'lurch says the bridge has a dog now. arrangements exist.' },
  { fn: dialogueA.paulieDialogue, label: 'ask what the face hears.', venueId: 'choir_office', feed: 'paulie says the choir office keeps hours. b flat to b flat.' },
  { fn: dialogueA.sherriDialogue, label: 'ask what she saw.', venueId: 'park', feed: 'sherri saw something at the park bench. after dark.' },
  { fn: dialogueA.sherriDialogue, label: 'ask what she saw.', venueId: 'laundromat', feed: 'sherri says the dryer provides. mid-cycle. noted.' },
];
state.recognition = freshRecognition();
state.discoveredVenues = freshDiscovered();
state.mode = 'playing';
for (const teller of TELLERS) {
  teller.fn({});
  const opt = runtimeUi.activeDialogue && runtimeUi.activeDialogue.opts.find(o => o.label === teller.label);
  if (!opt) { fail(`teller option '${teller.label}' missing`); runtimeUi.closeDialogue(); continue; }
  const beforeMechanics = venueMechanics(teller.venueId);
  const beforeReward = rewardFingerprint();
  const beforePosts = communications.phoneState.posts.length;
  opt.action();
  if (!venueDiscovered(teller.venueId)) fail(`'${teller.label}' did not reveal ${teller.venueId}`);
  if (venueMechanics(teller.venueId) !== beforeMechanics) fail(`teller reveal of ${teller.venueId} moved venue mechanics (the door recognition-gate cannot see)`);
  if (rewardFingerprint() !== beforeReward) fail(`teller reveal of ${teller.venueId} moved reward state`);
  const post = communications.phoneState.posts[0];
  if (communications.phoneState.posts.length !== beforePosts + 1 || !post || post.t !== teller.feed) {
    fail(`${teller.venueId} reveal feed drifted: got ${JSON.stringify(post && post.t)}`);
  }
  runtimeUi.closeDialogue();
  state.mode = 'playing';
}
if (state.discoveredVenues.size !== 4) fail(`four tellings discovered ${state.discoveredVenues.size} venues, expected 4`);
// repeat tellings: flavor only — no new posts, no mechanics, no set growth
for (const teller of [TELLERS[0], TELLERS[1], TELLERS[2]]) {
  teller.fn({});
  const opt = runtimeUi.activeDialogue && runtimeUi.activeDialogue.opts.find(o => o.label === teller.label);
  const beforeMechanics = venueMechanics(teller.venueId);
  const beforePosts = communications.phoneState.posts.length;
  if (opt) opt.action();
  if (communications.phoneState.posts.length !== beforePosts) fail(`repeat telling of ${teller.venueId} posted to the feed again`);
  if (state.discoveredVenues.size !== 4) fail(`repeat telling of ${teller.venueId} changed the discovered set`);
  if (venueMechanics(teller.venueId) !== beforeMechanics) fail(`repeat telling of ${teller.venueId} moved mechanics`);
  runtimeUi.closeDialogue();
  state.mode = 'playing';
}

// ---- 4. The Block can never enter the set ----------------------------------
const blockBefore = state.discoveredVenues.size;
if (discoverVenue('block') !== '') fail(`discoverVenue('block') returned a result; the Block is not a venue`);
if (state.discoveredVenues.size !== blockBefore || state.discoveredVenues.has('block')) fail('the Block entered the discovered set');
const filtered = normalizeDiscovered(['block', 'park', 'junk_venue', 5, null, 'park']);
if (filtered.size !== 1 || !filtered.has('park')) fail(`normalizeDiscovered kept garbage: ${JSON.stringify([...filtered])}`);
if (normalizeDiscovered('x').size !== 0) fail('non-array discovered payload did not normalize to empty');
if (normalizeDiscovered(null).size !== 0) fail('null discovered payload did not normalize to empty');

// ---- 5. Visibility contract -------------------------------------------------
state.recognition = freshRecognition();
state.discoveredVenues = freshDiscovered();
for (const venueId of VENUE_IDS) {
  const [cx, cy] = centerOf(venueId);
  // hidden: undiscovered + unconceded says nothing anywhere
  if (discoveryActionHint(cx, cy) !== '') fail(`${venueId}: undiscovered venue advertised a hint`);
  if (discoveryQLine(venueId) !== '') fail(`${venueId}: undiscovered venue wrote a Q line`);
  runtimeUi.closeDialogue(); state.mode = 'playing';
  discoveryMenu(venueId);
  if (runtimeUi.activeDialogue) fail(`${venueId}: unearned room opened while undiscovered`);
  // known: discovered + unconceded shows the conceded verb, a known: line, a grant-nothing room
  state.discoveredVenues.add(venueId);
  if (discoveryActionHint(cx, cy) !== CONCESSION_TEXT[venueId].hint) fail(`${venueId}: discovered hint '${discoveryActionHint(cx, cy)}' != conceded verb '${CONCESSION_TEXT[venueId].hint}'`);
  const qline = discoveryQLine(venueId);
  if (!qline.startsWith('known: ') || !qline.includes(CONCESSION_TEXT[venueId].qCondition) || !qline.includes(DISCOVERY_TEXT[venueId].keeper)) {
    fail(`${venueId}: known Q line drifted: '${qline}'`);
  }
  if (/in session|the dog is here|mid-cycle\.|asleep enough/.test(qline)) fail(`${venueId}: known Q line advertises live now-ness (honesty rule)`);
  discoveryMenu(venueId);
  if (!runtimeUi.activeDialogue) { fail(`${venueId}: known room did not open`); continue; }
  if (runtimeUi.activeDialogue.opts.some(o => /smoke/i.test(o.label))) fail(`${venueId}: unearned room offers a smoke option`);
  const beforeMechanics = venueMechanics(venueId);
  const beforeReward = rewardFingerprint();
  for (const opt of runtimeUi.activeDialogue.opts) opt.action();
  if (venueMechanics(venueId) !== beforeMechanics || rewardFingerprint() !== beforeReward) fail(`${venueId}: using the unearned room moved state`);
  runtimeUi.closeDialogue(); state.mode = 'playing';
  // conceded: the conceded surfaces own the venue again, discovered or not
  state.recognition[venueId].buy = 15;
  if (discoveryActionHint(cx, cy) !== '') fail(`${venueId}: discovery hint shadowed a conceded room`);
  if (concessionActionHint(cx, cy) !== CONCESSION_TEXT[venueId].hint) fail(`${venueId}: conceded hint broke under discovery`);
  if (discoveryQLine(venueId) !== '') fail(`${venueId}: discovery Q line shadowed the conceded line`);
  if (concessionQLine(venueId) === '') fail(`${venueId}: conceded Q line vanished under discovery`);
  discoveryMenu(venueId);
  if (runtimeUi.activeDialogue) fail(`${venueId}: unearned room opened over a conceded room`);
  state.recognition[venueId].buy = 0;
  state.discoveredVenues.delete(venueId);
}

// ---- 6. Orthogonality: the count is sacred in both directions ---------------
state.recognition = freshRecognition();
state.discoveredVenues = freshDiscovered();
// told but unearned: 14 visits is still not conceded
state.discoveredVenues.add('park');
state.recognition.park.buy = 14;
if (concessionUnlocked('park')) fail('a discovered venue conceded at 14 visits (discovery shortcut)');
state.recognition.park.buy = 15;
if (!concessionUnlocked('park')) fail('a discovered venue did not concede at 15 visits');
// never told: the old accidental grind still works
state.recognition.underpass.sit = 15;
if (venueDiscovered('underpass')) fail('grinding a venue flipped its discovered flag');
if (!concessionUnlocked('underpass')) fail('an undiscovered venue at 15 visits did not concede (accidental path broken)');
if (REGULAR_THRESHOLDS.counted !== 3 || REGULAR_THRESHOLDS.furniture !== 8 || REGULAR_THRESHOLDS.conceded !== 15) fail(`thresholds moved: ${JSON.stringify(REGULAR_THRESHOLDS)}`);

// ---- 7. Save round-trip + pre-5.2 saves -------------------------------------
state.recognition = freshRecognition();
state.discoveredVenues = freshDiscovered();
tellVenue('underpass', 'x', 'y', '');
tellVenue('choir_office', 'x', 'y', '');
await audioSave.saveGame();
const stored = await context.window.storage.get(audioSave.SAVE_KEY);
if (stored?.value?.version !== 10) fail(`save version drifted to ${stored?.value?.version}, expected additive 10`);
if (!Array.isArray(stored?.value?.discovered)) fail('discovered key absent from save payload');
else if ([...stored.value.discovered].sort().join(',') !== 'choir_office,underpass') fail(`saved discovered set drifted: ${stored.value.discovered}`);
state.discoveredVenues = freshDiscovered();
if (!await audioSave.loadGame()) fail('loadGame returned falsy for a discovery-bearing save');
if (![...state.discoveredVenues].length || [...state.discoveredVenues].sort().join(',') !== 'choir_office,underpass') {
  fail(`discovered set did not survive save/load roundtrip: ${JSON.stringify([...state.discoveredVenues])}`);
}
// a pre-5.2 save has no key: everyone loads untold (correct — they weren't told yet)
const legacy = JSON.parse(JSON.stringify(stored.value));
delete legacy.discovered;
await context.window.storage.set(audioSave.SAVE_KEY, legacy);
if (!await audioSave.loadGame()) fail('loadGame returned falsy for a pre-5.2 save');
// (instanceof Set is unusable across the vm realm boundary; duck-type the set)
const loadedSet = state.discoveredVenues;
if (!loadedSet || typeof loadedSet.has !== 'function' || loadedSet.size !== 0) {
  fail(`pre-5.2 save did not load all-undiscovered: ${JSON.stringify([...(loadedSet || [])])}`);
}

if (failures.length) {
  console.error(`DISCOVERY GATE: ${failures.length} failure(s)`);
  console.error('the map is not the key. discovery flips visibility; the ledger is the only path to conceded.');
  failures.forEach(f => console.error(`- ${f}`));
  process.exit(1);
}
console.log('DISCOVERY GATE: PASS (structural door sweep, byte-identical reveals at 4 tiers x 4 venues, 4 teller reveals + idempotent retells through real dialogue, Block excluded, visibility contract + grant-nothing room, 14/15 orthogonality both ways, save roundtrip + pre-5.2 all-undiscovered)');
