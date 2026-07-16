// THE REGULAR — recognition ledger gate (v20 landing 2).
// Fails on registry/threshold drift, malformed-save leakage, counter decay,
// free-verb repeat grinding, transaction over-counting, wrong venue/source
// mapping, reward-state mutation, high-boundary timing drift, incomplete
// reaction data, or a Clerical Pattern share above 50%.
import { loadModularGame } from './runtime-harness.mjs';

const { context, module } = await loadModularGame();
context.window._rb.startGame(false);

const recognition = module('src/systems/recognition.js');
const runtime = module('src/core/runtime_ui.js');
const world = module('src/data/world.js');
const audioSave = module('src/core/audio_save.js');

const {
  REGULAR_VENUES, REGULAR_ACTIONS, REGULAR_TIERS, REGULAR_THRESHOLDS,
  RECOGNITION_REACTIONS, recognitionTier, recognitionTotal, recordRecognition,
  recordNpcBother, normalizeRecognition, freshRecognition, syncRecognitionVisit,
  recognitionVenueAt,
} = recognition;
const P = runtime.P, state = runtime.state, ZONES = world.ZONES;

const failures = [];
const fail = m => failures.push(m);
const zoneById = id => ZONES.find(z => z.id === id);

// place the player's center at the middle of a venue's zone rectangle
function standIn(venueId) {
  const venue = REGULAR_VENUES.find(v => v.id === venueId);
  const z = zoneById(venue.zoneId);
  P.x = z.x + z.w / 2 - P.w / 2;
  P.y = z.y + z.h / 2 - P.h / 2;
  syncRecognitionVisit();
}

// forbidden-state fingerprint: recognition may NEVER move any of these
function rewardFingerprint() {
  return JSON.stringify({
    cash: P.cash, rocks: P.rocks, hp: P.hp, maxHp: P.maxHp, shakes: P.shakes,
    brain: P.brain, cred: P.cred, rank: P.rank, speed: P.speed, copper: P.copper,
    supplies: P.supplies, wanted: P.wanted, rockedT: P.rockedT, crashT: P.crashT,
    inv: (P.inventory || []).length, equip: JSON.stringify(P.equip || {}),
    faction: JSON.stringify(P.faction || {}), day: state.day, mode: state.mode,
  });
}

// ---- 1. Registry + threshold contract --------------------------------------
if (REGULAR_VENUES.length !== 4) fail(`venue count ${REGULAR_VENUES.length}, expected 4`);
const venueIds = REGULAR_VENUES.map(v => v.id).sort().join(',');
if (venueIds !== 'choir_office,laundromat,park,underpass') fail(`venue ids drifted: ${venueIds}`);
if (REGULAR_ACTIONS.join(',') !== 'sit,bother,buy,sell,full_high') fail(`action schema drifted: ${REGULAR_ACTIONS.join(',')}`);
if (REGULAR_TIERS.join(',') !== 'stranger,counted,furniture,conceded') fail(`tier ladder drifted: ${REGULAR_TIERS.join(',')}`);
if (REGULAR_THRESHOLDS.counted !== 3 || REGULAR_THRESHOLDS.furniture !== 8 || REGULAR_THRESHOLDS.conceded !== 15) {
  fail(`thresholds drifted: ${JSON.stringify(REGULAR_THRESHOLDS)}`);
}
// tier derivation boundaries
const tierAt = [[0, 'stranger'], [2, 'stranger'], [3, 'counted'], [7, 'counted'], [8, 'furniture'], [14, 'furniture'], [15, 'conceded'], [999, 'conceded']];
for (const [n, want] of tierAt) if (recognitionTier(n) !== want) fail(`recognitionTier(${n}) = ${recognitionTier(n)}, expected ${want}`);

// ---- 2. Reaction data completeness + Clerical share ------------------------
const ALLOWED_PATTERNS = new Set(['inverted_authority', 'bad_trade', 'cursed_aside', 'possum_pattern', 'clerical', 'mundane_magical']);
let patternTotal = 0, clericalCount = 0;
for (const venue of REGULAR_VENUES) {
  const beats = RECOGNITION_REACTIONS[venue.id];
  if (!beats) { fail(`no reactions for venue ${venue.id}`); continue; }
  for (const tier of ['counted', 'furniture', 'conceded']) {
    const beat = beats[tier];
    if (!beat || !Array.isArray(beat.lines) || beat.lines.length === 0) { fail(`incomplete reaction ${venue.id}/${tier}`); continue; }
    if (!ALLOWED_PATTERNS.has(beat.pattern)) fail(`unknown pattern id '${beat.pattern}' at ${venue.id}/${tier}`);
    patternTotal++;
    if (beat.pattern === 'clerical') clericalCount++;
  }
}
if (patternTotal !== 12) fail(`venue/tier beat count ${patternTotal}, expected 12`);
if (clericalCount / patternTotal > 0.5) fail(`Clerical share ${clericalCount}/${patternTotal} exceeds 50%`);

// ---- 3. Tier ladder reachable via simulated verbs (headline fixture) --------
// climb THE PARK stranger -> counted -> furniture -> conceded with paid verbs.
standIn('park');
const climbStartFingerprint = rewardFingerprint();
const parkCounters = () => state.recognition.park;
if (recognitionTier(parkCounters()) !== 'stranger') fail('fresh park venue is not stranger');
const crossings = {};
for (let i = 1; i <= 15; i++) {
  const before = recognitionTier(parkCounters());
  const r = recordRecognition('park', 'buy', 'pigeon_secret');
  if (!r.credited) fail(`paid verb #${i} at park did not credit`);
  const after = recognitionTier(parkCounters());
  if (after !== before) crossings[after] = i;
}
if (crossings.counted !== 3) fail(`park reached counted at total ${crossings.counted}, expected 3`);
if (crossings.furniture !== 8) fail(`park reached furniture at total ${crossings.furniture}, expected 8`);
if (crossings.conceded !== 15) fail(`park reached conceded at total ${crossings.conceded}, expected 15`);
if (recognitionTier(parkCounters()) !== 'conceded') fail('park did not end at conceded');
// zero reward leakage across the entire climb
if (rewardFingerprint() !== climbStartFingerprint) fail('reward-state mutated during recognition climb');

// ---- 4. Transaction counting: paid verbs credit every successful option ----
if (recognitionTotal(parkCounters()) !== 15) fail(`park total ${recognitionTotal(parkCounters())}, expected 15 after 15 buys`);

// ---- 5. Free-verb dedup: sit/bother credit once per source per visit --------
standIn('laundromat');
const b1 = recordNpcBother('barb');
const b2 = recordNpcBother('barb');
if (!b1.credited) fail('first barb bother did not credit');
if (b2.credited) fail('repeated barb bother in one visit grinded a second credit');
// a different source in the same visit still credits
if (!recordNpcBother('karaoke').credited) fail('distinct source (karaoke) did not credit in same visit');
// leave and re-enter -> the same source credits again
standIn('park');            // venue change resets the visit witnesses
standIn('laundromat');      // re-entry
if (!recordNpcBother('barb').credited) fail('barb bother did not credit after leaving and re-entering');

// ---- 6. Wrong venue / source mapping rejected ------------------------------
standIn('laundromat');
if (recordRecognition('park', 'buy', 'x').credited) fail('park verb credited while player stood in laundromat');
if (recordNpcBother('pigeon').credited) fail('pigeon (park source) credited while player stood in laundromat');
if (recordNpcBother('not_a_real_npc').credited) fail('unknown npc id credited a bother');
if (recordRecognition('park', 'levitate', 'x').credited) fail('unknown action id credited');
if (recordRecognition('mall', 'buy', 'x').credited) fail('unknown venue id credited');
if (recognitionVenueAt(-99999, -99999) !== '') fail('recognitionVenueAt returned a venue outside every zone');

// ---- 7. High-boundary credit + exact 18000/8000 timing ---------------------
standIn('underpass');
const beforeHigh = recognitionTotal(state.recognition.underpass);
const statusFingerprint = rewardFingerprint();
state.mode = 'playing';
P.rockedT = 18000; P.crashT = 0;
context.window._rb.updateWorld(18000);
if (P.rockedT !== 0 || P.crashT !== 8000) fail(`high->crash timing drifted (${P.rockedT} -> ${P.crashT})`);
const afterHigh = recognitionTotal(state.recognition.underpass);
if (afterHigh !== beforeHigh + 1) fail(`full_high credited ${afterHigh - beforeHigh} at boundary, expected exactly 1`);
if (state.recognition.underpass.full_high < 1) fail('full_high lane did not receive the boundary credit');
// full_high must not touch reward state beyond the frozen status transition
const postHigh = JSON.parse(rewardFingerprint()), preHigh = JSON.parse(statusFingerprint);
for (const k of ['cash', 'rocks', 'cred', 'rank', 'copper', 'supplies', 'inv', 'equip', 'faction']) {
  if (JSON.stringify(postHigh[k]) !== JSON.stringify(preHigh[k])) fail(`full_high mutated reward field '${k}'`);
}

// ---- 8. No decay: counters hold across idle frames -------------------------
standIn('park');
P.rockedT = 0; P.crashT = 0;
const decaySnapshot = JSON.stringify(state.recognition.park);
for (let i = 0; i < 20; i++) { syncRecognitionVisit(); context.window._rb.updateWorld(16); }
if (JSON.stringify(state.recognition.park) !== decaySnapshot) fail('recognition counters changed across idle frames (decay/leak)');

// ---- 9. Malformed-save normalization (no leakage, no pollution) ------------
const dirty = normalizeRecognition({
  park: { sit: -5, bother: 2.7, buy: 'nope', full_high: Infinity, bogus: 9 },
  junk_venue: { sit: 100 },
  laundromat: null,
});
if (Object.getPrototypeOf(dirty) !== null) fail('normalized ledger carries a prototype');
if (Object.keys(dirty).sort().join(',') !== 'choir_office,laundromat,park,underpass') fail(`normalized ledger venues drifted: ${Object.keys(dirty)}`);
if (dirty.park.sit !== 0) fail(`negative counter not clamped (${dirty.park.sit})`);
if (dirty.park.bother !== 2) fail(`fractional counter not floored (${dirty.park.bother})`);
if (dirty.park.buy !== 0) fail(`non-numeric counter not zeroed (${dirty.park.buy})`);
if (!Number.isInteger(dirty.park.full_high) || dirty.park.full_high < 0) fail(`non-finite counter not bounded (${dirty.park.full_high})`);
if (Object.prototype.hasOwnProperty.call(dirty.park, 'bogus')) fail('unknown action key survived normalization');
if (Object.prototype.hasOwnProperty.call(dirty, 'junk_venue')) fail('unknown venue key survived normalization');
if (recognitionTotal(dirty.laundromat) !== 0) fail('null venue did not normalize to a fresh ledger');
if (Object.getPrototypeOf(freshRecognition()) !== null) fail('fresh ledger carries a prototype');

// ---- 10. Save/load roundtrip preserves recognition state -------------------
state.recognition = freshRecognition();
state.recognition.park.buy = 4;
state.recognition.park.sit = 1;
state.recognition.laundromat.bother = 9;
state.recognition.underpass.full_high = 2;
const savedLedger = JSON.stringify(state.recognition);
await audioSave.saveGame();
const stored = await context.window.storage.get(audioSave.SAVE_KEY);
if (stored?.value?.version !== 10) fail(`save version drifted to ${stored?.value?.version}, expected additive 10`);
if (!stored?.value?.recognition) fail('recognition key absent from save payload');
state.recognition = freshRecognition();          // clobber in memory
const ok = await audioSave.loadGame();
if (!ok) fail('loadGame returned falsy for a recognition save');
if (JSON.stringify(state.recognition) !== savedLedger) fail('recognition ledger did not survive save/load roundtrip');
if (recognitionTier(state.recognition.laundromat) !== 'furniture') fail('roundtrip lost a derived tier (laundromat should be furniture at 9)');

if (failures.length) {
  console.error(`RECOGNITION GATE: ${failures.length} failure(s)`);
  failures.forEach(f => console.error(`- ${f}`));
  process.exit(1);
}
console.log(`RECOGNITION GATE: PASS (4 venues, 5-lane schema, ${patternTotal} beats/${clericalCount} clerical, stranger->conceded ladder, zero reward leakage, high-boundary 18000->8000, malformed-save + save/load roundtrip)`);
