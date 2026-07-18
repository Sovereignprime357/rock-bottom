#!/usr/bin/env node
/**
 * robbery-gate.mjs — v22 robbery (SPEC-v22-robbery.md). The economy's first sink.
 *
 * I-SINK-ONLY ⭐ — a robbery only subtracts. Statically the module is forbidden
 * every grant verb (push, +=, equip-to-non-null, rep, cred, achievement,
 * setTimeout give-backs); dynamically every theft category is run with a full
 * economy snapshot on both sides — exactly one axis goes down, nothing goes up,
 * and the taken thing stays gone through minutes of live updateWorld. A sink
 * you can dodge or reverse isn't a sink; the mercy is the rate, not the outcome.
 *
 * I-NO-SOFTLOCK ⭐ — losability is an ALLOWLIST. Default un-takeable; classes
 * opt in. The subject carries ONLY progression keys (stripe_package, the
 * crossword, a bus pass, the tool-slot torch, the pigeon crown) across a full
 * RNG sweep and every attempt resolves to the near-miss beat with the keys
 * byte-identical. A robbery that strands the campaign is a bug, not an indignity.
 *
 * Also held: I-ZONE-SCOPED (the robs flag exists once, on skid_lurch; the
 * back-alley grabber's landed grab — same real code path — takes nothing),
 * I-VISIBLE (equip theft: the gear_ layer provably stops being drawImage'd by
 * the real drawPlayer), I-BOUNDED-RATE (cooldown + daily cap through the real
 * dawn reset), I-SAVE-ADDITIVE (version stays 10; pre-robbery saves load to an
 * open governor). The theft itself is exercised through the REAL grabber
 * contact in updateNpcActors, not just the exported function (ORCH-NOTES #13).
 */
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const failures = [];
const fail = message => failures.push(message);

// ---------- 1. static: one flag, one call site, a module that cannot give ----------
const srcFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) srcFiles.push(full);
  }
})(path.join(ROOT, 'src'));
// comment-stripped (docs-gate precedent): counts are about what the code DOES;
// prose mentioning the flag must not trip them.
const stripComments = code => code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
const srcText = srcFiles.map(f => `// FILE ${path.relative(ROOT, f)}\n${stripComments(fs.readFileSync(f, 'utf8'))}`).join('\n');

const robsCount = (srcText.match(/robs\s*:\s*true/g) || []).length;
if (robsCount !== 1) fail(`static: robs:true appears ${robsCount} time(s) in src code, expected exactly 1 (I-ZONE-SCOPED is authored as a flag, not an archetype)`);
const spawns = stripComments(fs.readFileSync(path.join(ROOT, 'src/data/npc_spawns.js'), 'utf8'));
if (!/id:'skid_lurch'[\s\S]{0,400}robs:\s*true/.test(spawns)) fail('static: the robs flag is not on the skid_lurch def in npc_spawns.js');
const attemptCalls = (srcText.match(/attemptRobbery\s*\(/g) || []).length;
if (attemptCalls !== 2) fail(`static: attemptRobbery( appears ${attemptCalls} time(s), expected 2 (1 definition + 1 grabber hook)`);

// comment-stripped (docs-gate precedent): the check is about what the code DOES.
const robberyCode = fs.readFileSync(path.join(ROOT, 'src/systems/robbery.js'), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^\s*\/\/.*$/gm, '');
for (const forbidden of [
  /P\.cash\s*\+=/, /P\.inventory\.push/, /P\.equip\[[^\]]+\]\s*=(?!\s*null)/,
  /P\.hitters\s*(\+|=)/, /P\.rocks/, /P\.copper/, /P\.cred/, /P\.hp/, /P\.supplies/,
  /P\.shakes/, /P\.brain/, /applyRep|adjustFaction|recordRecognition|unlockAchievement/,
  /setTimeout|setInterval/,
]) {
  if (forbidden.test(robberyCode)) fail(`static: robbery.js code matches forbidden pattern ${forbidden} — a robbery that grants, heals, credits, or schedules a give-back is not a sink`);
}
for (const required of [/LOSABLE_INVENTORY_IDS\.has\(/, /LOSABLE_EQUIP_IDS\.has\(/]) {
  if (!required.test(robberyCode)) fail(`static: robbery.js does not gate candidates through ${required} — losability must flow through the allowlist`);
}

// ---------- boot ----------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);
const rb = context.window._rb;
const robbery = module('src/systems/robbery.js');
const daily = module('src/systems/daily_hideouts.js');
const ui = module('src/core/runtime_ui.js');
const aw = module('src/render/actors_weather.js');
const audioSave = module('src/core/audio_save.js');
const P = rb.P, state = rb.state, runtime = ui.runtime;
const {
  ROB_COOLDOWN_MS, ROB_DAILY_CAP, ROB_CASH_MIN, ROB_CASH_MAX,
  LOSABLE_INVENTORY_IDS, LOSABLE_EQUIP_SLOTS, LOSABLE_EQUIP_IDS,
  attemptRobbery, robberyReady,
} = robbery;

let forced = 0.5;
context.Math.random = () => forced;

// ---------- 2. the allowlist is an allowlist, and the keys are not on it ----------
if (typeof LOSABLE_INVENTORY_IDS.has !== 'function' || typeof LOSABLE_EQUIP_IDS.has !== 'function') fail('allowlist: the losable-id lists are not Sets (membership must be .has, not substring luck)');
for (const key of ['stripe_package', 'crossword', 'bus_pass']) {
  if (LOSABLE_INVENTORY_IDS.has(key)) fail(`allowlist: progression/route item '${key}' is losable — I-NO-SOFTLOCK`);
}
if (LOSABLE_EQUIP_SLOTS.includes('tool')) fail('allowlist: the tool slot is losable — the torch is route-gating');
for (const key of ['propane_torch', 'pigeon_crown', 'priest_collar']) {
  if (LOSABLE_EQUIP_IDS.has(key)) fail(`allowlist: unique/gating equip '${key}' is losable — I-NO-SOFTLOCK`);
}
if (!(ROB_COOLDOWN_MS >= 30000)) fail(`rate: cooldown ${ROB_COOLDOWN_MS}ms is not a governor`);
if (!(ROB_DAILY_CAP >= 1 && ROB_DAILY_CAP <= 3)) fail(`rate: daily cap ${ROB_DAILY_CAP} outside [1,3] — sting, not strip`);
if (!(ROB_CASH_MIN >= 1 && ROB_CASH_MAX <= 20)) fail(`rate: cash take ${ROB_CASH_MIN}-${ROB_CASH_MAX} is a tax, not a mugging`);

// ---------- 3. zone scope: the census (live roster, real defs) ----------
const robbers = runtime.npcs.filter(n => n.robs).map(n => n.id);
if (robbers.length !== 1 || robbers[0] !== 'skid_lurch') fail(`zone: robbing NPCs are [${robbers.join(', ')}], expected exactly [skid_lurch]`);

// ---------- helpers ----------
const skidLurch = runtime.npcs.find(n => n.id === 'skid_lurch');
const alleyLurch = runtime.npcs.find(n => n.id === 'lurch');
if (!skidLurch) fail('boot: skid_lurch not in the roster');
if (!alleyLurch) fail('boot: back-alley lurch not in the roster');
function openGovernor() {
  state.counters.robberiesToday = 0;
  state.counters.robLastClockMs = 0;
}
function subject(opts = {}) {
  ui.closeDialogue();
  state.mode = 'playing';
  state.day = 1; state.dayTime = 0.3;
  P.hp = P.maxHp; P.wanted = 0; P.stunT = 0; P.iframes = 0;
  P.rockedT = 0; P.crashT = 0; P.hitterHigh = false;
  P.shakes = 20; P.brain = 80; P.cred = 5;
  P.cash = opts.cash || 0;
  P.rocks = opts.rocks || 0; P.copper = 0; P.supplies = 0; P.hitters = opts.hitters || 0;
  P.inventory = (opts.inventory || []).map(i => ({ ...i }));
  P.equip = Object.assign({ shoes: null, hat: null, coat: null, tool: null }, opts.equip || {});
  ui.applyEquipStats();
  openGovernor();
}
function snapshot() {
  return {
    cash: P.cash, rocks: P.rocks, copper: P.copper, supplies: P.supplies,
    hitters: P.hitters, cred: P.cred, brain: P.brain, weapon: P.weapon,
    inv: JSON.stringify(P.inventory), equip: JSON.stringify(P.equip),
  };
}
const fakeRobber = { robs: true, dead: false, name: 'LURCH (SKID)' };

// ---------- 4. THE REAL PATH — the grab itself takes (and only the skid grab) ----------
{
  // positive: skid grabber's landed grab, driven through updateNpcActors
  subject({ cash: 100 });
  P.x = 2900; P.y = 2000; // open skid row ground
  const sx = skidLurch.x, sy = skidLurch.y;
  skidLurch.x = P.x; skidLurch.y = P.y; skidLurch.attackCd = 0; skidLurch.aggro = true; skidLurch.dead = false;
  rb.updateWorld(16);
  if (!(P.stunT > 0)) fail('real path: the skid grab did not land (no stun) — the positive test never reached the code path');
  if (!(P.cash < 100)) fail(`real path: a landed skid grab with an open governor took nothing (cash ${P.cash}) — the robbery is not wired into the grabber`);
  skidLurch.x = sx; skidLurch.y = sy; skidLurch.attackCd = 99999;

  // negative control: the back-alley grabber, SAME code path, must not rob
  subject({ cash: 100 });
  P.x = 300; P.y = 5300; // open ground, far from every zone actor
  const ax = alleyLurch.x, ay = alleyLurch.y;
  alleyLurch.x = P.x; alleyLurch.y = P.y; alleyLurch.attackCd = 0; alleyLurch.aggro = true; alleyLurch.dead = false;
  rb.updateWorld(16);
  if (!(P.stunT > 0)) fail('real path: the alley grab did not land (no stun) — the negative control never reached the code path');
  if (P.cash !== 100) fail(`real path: the back-alley lurch robbed (cash ${P.cash}) — I-ZONE-SCOPED broken through the live path`);
  alleyLurch.x = ax; alleyLurch.y = ay; alleyLurch.attackCd = 99999;
}

// ---------- 5. I-NO-SOFTLOCK — a full pocket of progression keys is untouchable ----------
{
  const keysOnly = {
    cash: 0,
    rocks: 3,
    inventory: [
      { id: 'stripe_package', n: "stripe's sealed package", q: 1 },
      { id: 'crossword', n: "barb's saturday crossword", q: 1 },
      { id: 'bus_pass', n: 'a bus pass', q: 1 },
    ],
    equip: { hat: 'pigeon_crown', tool: 'propane_torch' },
  };
  for (const roll of [0, 0.01, 0.2, 0.35, 0.5, 0.65, 0.8, 0.99]) {
    subject(keysOnly);
    forced = roll;
    const before = snapshot();
    const outcome = attemptRobbery(fakeRobber);
    const after = snapshot();
    if (outcome !== true) fail(`softlock: attempt at roll ${roll} did not resolve (near-miss beat expected — never nothing-happens-silently)`);
    if (after.inv !== before.inv) fail(`softlock: roll ${roll} touched a progression inventory (${before.inv} -> ${after.inv})`);
    if (after.equip !== before.equip) fail(`softlock: roll ${roll} touched the crown/torch equip (${before.equip} -> ${after.equip})`);
    if (after.rocks !== before.rocks) fail(`softlock: roll ${roll} took rocks — the intro needs one`);
    if (JSON.stringify(after) !== JSON.stringify(before)) fail(`softlock: roll ${roll} moved some axis: ${JSON.stringify(before)} -> ${JSON.stringify(after)}`);
  }
  forced = 0.5;
}

// ---------- 6. I-SINK-ONLY — every category subtracts one axis, grants none, forever ----------
function assertPureSink(label, before, after, expectDown) {
  for (const axis of ['cash', 'rocks', 'copper', 'supplies', 'hitters', 'cred', 'brain']) {
    if (after[axis] > before[axis]) fail(`sink (${label}): ${axis} INCREASED ${before[axis]} -> ${after[axis]} — a robbery granted something`);
    if (axis !== expectDown && after[axis] < before[axis]) fail(`sink (${label}): ${axis} decreased but only ${expectDown} should have`);
  }
  if (JSON.parse(after.inv).length > JSON.parse(before.inv).length) fail(`sink (${label}): the inventory GREW`);
}
{
  // (a) equipped coat — and it stays gone through live minutes (no return timer)
  subject({ equip: { coat: 'trench' } });
  let before = snapshot();
  attemptRobbery(fakeRobber);
  let after = snapshot();
  if (P.equip.coat !== null) fail(`sink (equip): coat is '${P.equip.coat}', expected null`);
  assertPureSink('equip', before, after, null);
  // freeze the roster and park the random-event clock for the long runs: the
  // no-return proof watches the TAKEN thing, not whatever an ambient event or a
  // cross-map chase would stir in. (The real-path proof already ran, unfrozen.)
  runtime.npcs.forEach(n => { n.speed = 0; n.attackCd = 9e9; });
  state.eventT = 9e9;
  P.x = 50; P.y = 5500;
  for (let i = 0; i < 120; i++) rb.updateWorld(1000); // two live minutes
  if (P.equip.coat !== null) fail('sink (equip): the coat came back — I-NO-RECOVERY-GUARANTEE');
  if (P.inventory.some(i => i.id === 'trench')) fail('sink (equip): the coat reappeared in the inventory');

  // (b) inventory item
  subject({ inventory: [{ id: 'gold_tooth', n: 'a tooth (gold)', q: 1 }] });
  state.eventT = 9e9;
  before = snapshot();
  attemptRobbery(fakeRobber);
  after = snapshot();
  if (P.inventory.length !== 0) fail(`sink (item): inventory has ${P.inventory.length} entries, expected 0`);
  assertPureSink('item', before, after, null);
  for (let i = 0; i < 60; i++) rb.updateWorld(1000);
  if (P.inventory.some(i => i.id === 'gold_tooth')) fail('sink (item): the tooth came back');

  // (c) stacked item loses exactly one
  subject({ inventory: [{ id: 'junk', n: 'a piece of junk', q: 3 }] });
  attemptRobbery(fakeRobber);
  if (!(P.inventory.length === 1 && P.inventory[0].q === 2)) fail(`sink (stack): junk x3 became ${JSON.stringify(P.inventory)}, expected x2`);

  // (d) the emergency hitter is losable (SPEC edge case) and only goes down
  subject({ hitters: 1 });
  before = snapshot();
  attemptRobbery(fakeRobber);
  after = snapshot();
  if (P.hitters !== 0) fail(`sink (hitter): ${P.hitters} hitters left, expected 0`);
  assertPureSink('hitter', before, after, 'hitters');

  // (e) cash — exact, bounded, capped at what exists
  subject({ cash: 50 });
  forced = 0.5;
  before = snapshot();
  attemptRobbery(fakeRobber);
  after = snapshot();
  const expected = ROB_CASH_MIN + Math.floor(0.5 * (ROB_CASH_MAX - ROB_CASH_MIN + 1));
  if (P.cash !== 50 - expected) fail(`sink (cash): took ${50 - P.cash}, expected ${expected}`);
  assertPureSink('cash', before, after, 'cash');
  subject({ cash: 3 });
  forced = 0.99; // max roll vs $3 pocket
  attemptRobbery(fakeRobber);
  if (P.cash !== 0) fail(`sink (cash cap): $3 pocket ended at $${P.cash}, expected $0 (never negative, never a grant)`);
  forced = 0.5;

  // (f) broke and keyless: the near-miss beat, all axes byte-identical
  subject({});
  before = snapshot();
  const outcome = attemptRobbery(fakeRobber);
  after = snapshot();
  if (outcome !== true) fail('sink (near-miss): the broke attempt did not resolve to the receipt beat');
  if (JSON.stringify(after) !== JSON.stringify(before)) fail(`sink (near-miss): a receipt moved an axis: ${JSON.stringify(before)} -> ${JSON.stringify(after)}`);
}

// ---------- 7. I-BOUNDED-RATE — cooldown, cap, and the real dawn reset ----------
{
  subject({ cash: 9999 });
  if (!attemptRobbery(fakeRobber)) fail('rate: first attempt with an open governor refused');
  const afterFirst = P.cash;
  if (robberyReady()) fail('rate: robberyReady() still true immediately after a robbery');
  if (attemptRobbery(fakeRobber) !== false || P.cash !== afterFirst) fail('rate: a second grab inside the cooldown took again — one crossing can strip you');
  let successes = 1;
  while (successes < ROB_DAILY_CAP) { // walk the rest of the day's allowance through the cooldown
    state.dayTime += ROB_COOLDOWN_MS / 240000; // the cooldown elapses on the world clock
    if (!attemptRobbery(fakeRobber)) { fail(`rate: attempt ${successes + 1} after a full cooldown refused (under the cap)`); break; }
    successes++;
  }
  state.dayTime += ROB_COOLDOWN_MS / 240000;
  const atCap = P.cash;
  if (attemptRobbery(fakeRobber) !== false || P.cash !== atCap) fail(`rate: robbery #${ROB_DAILY_CAP + 1} beat the daily cap`);
  daily.resetDailyCounters(); // the REAL dawn path, proving robberiesToday is registered
  state.dayTime += ROB_COOLDOWN_MS / 240000;
  if (!attemptRobbery(fakeRobber)) fail('rate: the real dawn reset did not reopen the governor — robberiesToday is not in DAILY_COUNTER_KEYS');
}

// ---------- 8. I-VISIBLE — the gear layer provably stops drawing ----------
{
  subject({ equip: { coat: 'trench' } });
  P.facing = 'down'; P.frame = 0; P.attacking = 0; P.cartMounted = false;
  const cache = rb.sprites;
  const gear = cache['gear_trench_down'];
  const body = cache['player_down_0'];
  if (!gear || !body) fail('visible: gear_trench_down / player_down_0 missing from SPRITE_CACHE');
  const qa = context.window.__qa;
  let drawn = [];
  qa.context2d.drawImage = img => { drawn.push(img); };
  aw.drawPlayer();
  if (!drawn.includes(body)) fail('visible: instrumented drawPlayer did not draw the body — the probe missed the real draw path');
  if (!drawn.includes(gear)) fail('visible: an equipped coat did not draw its gear_ layer');
  attemptRobbery(fakeRobber); // only candidate: the coat
  if (P.equip.coat !== null) fail('visible: the robbery did not un-equip the coat');
  drawn = [];
  aw.drawPlayer();
  if (drawn.includes(gear)) fail('visible: the stolen coat still draws — the loss is invisible');
  if (!drawn.includes(body)) fail('visible: post-robbery draw lost the body — probe invalid');
  delete qa.context2d.drawImage;
}

// ---------- 9. I-SAVE-ADDITIVE — version 10, counters round-trip, pre-robbery loads open ----------
{
  const store = new Map();
  context.window.storage = {
    async set(key, value) { store.set(key, JSON.parse(JSON.stringify(value))); },
    async get(key) { return { value: store.get(key) }; },
  };
  subject({ cash: 50 });
  attemptRobbery(fakeRobber); // stamps both counters and saves
  const clockAtRobbery = state.counters.robLastClockMs;
  await audioSave.saveGame();
  const saved = store.get(audioSave.SAVE_KEY);
  if (saved.version !== 10) fail(`save: version moved to ${saved.version} (must stay 10 — additive keys only)`);
  state.counters.robberiesToday = 99; state.counters.robLastClockMs = 5;
  if (!(await audioSave.loadGame())) fail('save: loadGame refused its own save');
  if (state.counters.robberiesToday !== 1 || state.counters.robLastClockMs !== clockAtRobbery) {
    fail(`save: governor round-tripped to ${state.counters.robberiesToday}/${state.counters.robLastClockMs}, expected 1/${clockAtRobbery}`);
  }
  delete saved.counters.robberiesToday; delete saved.counters.robLastClockMs; // a pre-robbery save
  await context.window.storage.set(audioSave.SAVE_KEY, saved);
  state.counters.robberiesToday = 99; state.counters.robLastClockMs = 99999999;
  if (!(await audioSave.loadGame())) fail('save: loadGame refused a pre-robbery save');
  if ((state.counters.robberiesToday || 0) !== 0 || (state.counters.robLastClockMs || 0) !== 0) {
    fail(`save: pre-robbery save loaded governor ${state.counters.robberiesToday}/${state.counters.robLastClockMs}, expected 0/0 (never robbed)`);
  }
  if (!robberyReady()) fail('save: pre-robbery save loaded with a CLOSED governor');
}

// ---------- verdict ----------
if (failures.length) {
  console.error(`ROBBERY GATE: ${failures.length} failure(s)`);
  failures.slice(0, 40).forEach(message => console.error(`- ${message}`));
  process.exit(1);
}
console.log(`ROBBERY GATE: PASS (1 robber flag on skid_lurch, real-path grab takes / alley grab doesn't, ${LOSABLE_INVENTORY_IDS.size}-id + ${LOSABLE_EQUIP_IDS.size}-id allowlists with keys untouchable across 8 rolls, all 5 theft categories pure-sink with no return over live minutes, governor ${ROB_COOLDOWN_MS / 1000}s + ${ROB_DAILY_CAP}/day through the real dawn reset, gear layer provably undrawn after coat theft, save additive at v10)`);
