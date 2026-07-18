#!/usr/bin/env node
/**
 * hitter-gate.mjs — v22 emergency hitter (SPEC-v22-emergency-hitter.md).
 *
 * I-BAD-TRADE ⭐ — the load-bearing check is DYNAMIC and covers the FULL cycle:
 * both transactions run through the real updateWorld boundary to a common
 * 40-second horizon, and the real rock must win every axis — longer high,
 * shorter crash, deeper shakes relief, smaller brain cost, cred vs none, and
 * a strictly better shakes/brain position at the horizon. The horizon test is
 * the marathon: a hitter that "looks nerfed per-use" but out-survives real
 * rocks when spammed fails HERE, whatever its per-use numbers claim. The
 * numbers are the operator's knob; the ORDERING is the invariant. A failing
 * ordering is a finding about the trade, not a threshold to relax.
 *
 * I-NO-RUNWAY-COST ⭐ — craft and use both succeed in open scrub, no venue, no
 * zone, no walk; the pocket answers the E only when nothing else wants it and
 * never steals a zone verb. (The map itself is world-gate's jurisdiction —
 * this wave must leave that reading untouched.)
 *
 * I-COPPER-COST — copper in, hitter out, never back: the hitter module is
 * statically forbidden from minting copper or cash, and the craft path is
 * dynamically net-negative copper. I-RARE-FIND — the dumpster roll exists
 * once, is bounded <= 5%, and adjacent-to-the-block dumpsters never carry it.
 * I-CONSUMABLE — one use, gone, and no use while already rocked. The hitter
 * is also a nobody: no cred, no rep, no lifetime.rocksSmoked, no intro
 * credit, no recognition credit at the boundary — the room does not respect
 * the pipe. I-SAVE-ADDITIVE — round-trips; a pre-hitter save loads 0/false.
 */
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const failures = [];
const fail = message => failures.push(message);

// ---------- 1. static: one transaction, one roll, no minting ----------
const srcFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) srcFiles.push(full);
  }
})(path.join(ROOT, 'src'));
const srcText = srcFiles.map(f => `// FILE ${path.relative(ROOT, f)}\n${fs.readFileSync(f, 'utf8')}`).join('\n');
const countAll = pattern => (srcText.match(pattern) || []).length;

for (const [pattern, expected, label] of [
  [/function\s+hitEmergencyHitter/g, 1, 'hitEmergencyHitter definition'],
  // v22 robbery raised this from 1 to 2: the skid grabber may TAKE a hitter
  // (SPEC-v22-robbery.md edge case — a losable consumable). Both sites subtract;
  // grants stay pinned at 2 below, so the hitter still never mints.
  [/P\.hitters--/g, 2, 'hitter subtraction sites (use + skid robbery theft)'],
  [/P\.hitterHigh\s*=\s*true/g, 1, 'hitterHigh ignition site'],
  [/P\.hitters\s*=\s*\(P\.hitters\s*\|\|\s*0\)\s*\+\s*1/g, 2, 'hitter grant sites (craft + found)'],
  [/dumpsterHitterRoll\s*\(/g, 2, 'dumpsterHitterRoll call sites (1 definition + 1 dumpster hook)'],
]) {
  const n = countAll(pattern);
  if (n !== expected) fail(`static: ${label} appears ${n} time(s), expected ${expected}`);
}
// comment-stripped before scanning (docs-gate precedent): the check is about
// what the code DOES; prose mentioning a forbidden name must not trip it.
const hitterCode = fs.readFileSync(path.join(ROOT, 'src/systems/hitter.js'), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^\s*\/\/.*$/gm, '');
for (const forbidden of [/P\.copper\s*\+[=+]/, /P\.cash\s*[+-]?=/, /P\.rocks\b/, /rocksSmoked/, /completeIntroSmoke/, /P\.cred\b/, /applyRep/, /recordRecognition|recordFullHigh/, /adjustFaction/]) {
  if (forbidden.test(hitterCode)) fail(`static: hitter.js code matches forbidden pattern ${forbidden} — the hitter mints or credits something it must not`);
}

// ---------- boot ----------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);
const rb = context.window._rb;
const hitter = module('src/systems/hitter.js');
const concessions = module('src/systems/concessions.js');
const interactions = module('src/systems/interactions.js');
const ui = module('src/core/runtime_ui.js');
const audioSave = module('src/core/audio_save.js');
const world = module('src/data/world.js');
const P = rb.P, state = rb.state, runtime = ui.runtime;

const {
  HITTER_HIGH_MS, HITTER_CRASH_MS, HITTER_SHAKES_RELIEF, HITTER_BRAIN_COST,
  HITTER_CRASH_SHAKES, HITTER_COPPER_COST, HITTER_FIND_CHANCE,
  hitEmergencyHitter, craftHitter, pocketMenu, pocketHasBusiness, dumpsterHitterRoll,
} = hitter;

// ---------- 2. constants: the trade is declared bad ----------
// (Necessary, not sufficient — a literal that bypasses the constants is caught
// by the dynamic cycle below, which measures what actually happens.)
if (!(HITTER_HIGH_MS > 0 && HITTER_HIGH_MS < 18000)) fail(`constants: high ${HITTER_HIGH_MS} not in (0, 18000)`);
if (!(HITTER_CRASH_MS > 8000)) fail(`constants: crash ${HITTER_CRASH_MS} not rougher than 8000`);
if (!(HITTER_SHAKES_RELIEF >= 0 && HITTER_SHAKES_RELIEF < 50)) fail(`constants: relief ${HITTER_SHAKES_RELIEF} not weaker than 50`);
if (!(HITTER_BRAIN_COST > 4)) fail(`constants: brain cost ${HITTER_BRAIN_COST} not bigger than 4`);
if (!(HITTER_CRASH_SHAKES >= 30)) fail(`constants: crash shakes ${HITTER_CRASH_SHAKES} milder than the rock's +30`);
if (!(HITTER_COPPER_COST >= 2)) fail(`constants: copper cost ${HITTER_COPPER_COST} is a rounding error, not a decision`);
if (!(HITTER_FIND_CHANCE > 0 && HITTER_FIND_CHANCE <= 0.05)) fail(`constants: find chance ${HITTER_FIND_CHANCE} not rare (0, 0.05]`);

// ---------- helpers ----------
let forced = 0.5;
context.Math.random = () => forced;
const SCRUB = { x: 50, y: 5500 };
function resetSubject(x, y) {
  ui.closeDialogue();
  state.mode = 'playing';
  state.dayTime = 0.3; state.day = 1;
  runtime.npcs.length = 0;
  P.x = x; P.y = y;
  P.hp = P.maxHp; P.wanted = 0; P.stunT = 0;
  P.rockedT = 0; P.crashT = 0; P.hitterHigh = false;
  P.shakes = 60; P.brain = 80; P.cred = 5; P.cash = 50;
  P.rocks = 0; P.soapRocks = 0; P.hitters = 0; P.copper = 0;
}
function click(matcher, where) {
  const dlg = ui.activeDialogue;
  if (!dlg) { fail(`${where}: no dialogue open`); return false; }
  const opt = dlg.opts.find(o => String(o.label).includes(matcher));
  if (!opt) { fail(`${where}: option '${matcher}' not in [${dlg.opts.map(o => o.label).join(' | ')}]`); return false; }
  if (opt.disabled) { fail(`${where}: option '${opt.label}' is disabled`); return false; }
  ui.closeDialogue();
  opt.action && opt.action();
  return true;
}

// ---------- 3. THE FULL CYCLE — a real rock wins the marathon ----------
const HORIZON_MS = 40000;
function runCycle(kind) {
  const out = { kind };
  if (kind === 'rock') {
    resetSubject(1064 - P.w / 2, 882 - P.h / 2); // the block
    P.rocks = 1;
    concessions.smokeRockAt('block');
  } else {
    resetSubject(SCRUB.x, SCRUB.y); // open scrub: no venue, no zone, no walk
    P.hitters = 1;
    hitEmergencyHitter();
  }
  out.highMs = P.rockedT;
  out.reliefShakes = 60 - P.shakes;
  out.brainCost = 80 - P.brain;
  out.cred = P.cred - 5;
  if (out.highMs <= 0) { fail(`${kind}: did not ignite`); return out; }
  rb.updateWorld(out.highMs);           // to the boundary
  out.crashMs = P.crashT;
  let remaining = HORIZON_MS - out.highMs;
  while (remaining > 0) { rb.updateWorld(Math.min(1000, remaining)); remaining -= 1000; }
  out.horizonShakes = P.shakes;
  out.horizonBrain = P.brain;
  out.hitterHighLeak = !!P.hitterHigh;
  return out;
}
const rock = runCycle('rock');
const emergency = runCycle('hitter');
const axes = [
  ['high duration', rock.highMs > emergency.highMs, `rock ${rock.highMs}ms vs hitter ${emergency.highMs}ms`],
  ['crash duration', rock.crashMs < emergency.crashMs, `rock ${rock.crashMs}ms vs hitter ${emergency.crashMs}ms`],
  ['instant shakes relief', rock.reliefShakes > emergency.reliefShakes, `rock -${rock.reliefShakes} vs hitter -${emergency.reliefShakes}`],
  ['brain cost', rock.brainCost < emergency.brainCost, `rock -${rock.brainCost} vs hitter -${emergency.brainCost}`],
  ['cred', rock.cred > emergency.cred, `rock +${rock.cred} vs hitter +${emergency.cred}`],
  ['shakes at the 40s horizon (the marathon)', rock.horizonShakes < emergency.horizonShakes, `rock ${rock.horizonShakes.toFixed(1)} vs hitter ${emergency.horizonShakes.toFixed(1)}`],
  ['brain at the 40s horizon', rock.horizonBrain > emergency.horizonBrain, `rock ${rock.horizonBrain.toFixed(1)} vs hitter ${emergency.horizonBrain.toFixed(1)}`],
];
for (const [axis, rockWins, reading] of axes) {
  if (!rockWins) fail(`I-BAD-TRADE: the rock does not win '${axis}' (${reading}) — if the hitter is ever the better deal, the wave is broken. The trade is the finding, not the threshold.`);
}
if (emergency.crashMs !== HITTER_CRASH_MS) fail(`boundary: hitter crash ${emergency.crashMs} != declared ${HITTER_CRASH_MS} — a literal bypassed the constant`);
if (rock.crashMs !== 8000) fail(`boundary: rock crash drifted to ${rock.crashMs}`);
if (emergency.hitterHighLeak || rock.hitterHighLeak) fail('boundary: hitterHigh flag leaked past the crash');

// ---------- 4. the hitter is a nobody (no ledger of any kind) ----------
{
  // stand INSIDE a venue for the whole hitter cycle: recognition must not move.
  const zone = world.ZONES.find(z => z.id === 'park');
  resetSubject(zone.x + zone.w / 2, zone.y + zone.h / 2);
  rb.updateWorld(16); // settle visit state before the snapshot
  // the rock cycle above completed the intro; un-complete it so this proves a
  // hitter can NEVER be the intro smoke (the game stays unbeatable without a rock).
  if (state.quests.intro_smoke) state.quests.intro_smoke.done = false;
  state.flags.introDone = false;
  const recognitionBefore = JSON.stringify(state.recognition);
  const smokedBefore = P.lifetime.rocksSmoked;
  const factionBefore = JSON.stringify(P.faction);
  P.hitters = 1;
  hitEmergencyHitter();
  rb.updateWorld(HITTER_HIGH_MS);
  rb.updateWorld(HITTER_CRASH_MS);
  rb.updateWorld(2500); // past the deferred credit window a rock would use
  if (JSON.stringify(state.recognition) !== recognitionBefore) fail('nobody: a hitter high credited recognition — the room respected the pipe');
  if (state.quests.intro_smoke && state.quests.intro_smoke.done) fail('nobody: a hitter completed the intro smoke (the intro requires a real rock)');
  if (state.flags.introDone) fail('nobody: a hitter set introDone');
  if (P.lifetime.rocksSmoked !== smokedBefore) fail('nobody: a hitter counted as a smoked rock');
  if (JSON.stringify(P.faction) !== factionBefore) fail('nobody: a hitter moved faction rep');
  // restore the completed intro for the sections below
  if (state.quests.intro_smoke) state.quests.intro_smoke.done = true;
  state.flags.introDone = true;
}

// ---------- 5. consumable + guards ----------
resetSubject(SCRUB.x, SCRUB.y);
P.hitters = 1;
hitEmergencyHitter();
if (P.hitters !== 0) fail(`consumable: use left ${P.hitters} hitters, expected 0`);
const rockedMid = P.rockedT;
hitEmergencyHitter(); // none left AND already rocked — must be a no-op
if (P.rockedT !== rockedMid || P.hitters !== 0) fail('consumable: empty/rocked use was not a no-op');
resetSubject(SCRUB.x, SCRUB.y);
P.hitters = 2; P.rockedT = 5000;
hitEmergencyHitter();
if (P.hitters !== 2) fail('guard: a hitter was consumed while already rocked up');

// ---------- 6. copper: in, never back; craft is location-free ----------
resetSubject(SCRUB.x, SCRUB.y);
P.copper = HITTER_COPPER_COST + 1;
const cashBefore = P.cash;
craftHitter();
if (P.copper !== 1) fail(`copper: craft left ${P.copper}, expected 1`);
if (P.hitters !== 1) fail(`copper: craft made ${P.hitters} hitters, expected 1`);
if (P.cash !== cashBefore) fail('copper: craft touched cash');
const copperAfterCraft = P.copper;
hitEmergencyHitter();
rb.updateWorld(HITTER_HIGH_MS); rb.updateWorld(HITTER_CRASH_MS);
if (P.copper !== copperAfterCraft) fail(`copper: the use/crash path changed copper ${copperAfterCraft} -> ${P.copper} — the loop must be one-directional`);
craftHitter(); // 1 copper < cost — must refuse without spending
if (P.copper !== 1 || P.hitters !== 0) fail('copper: an unaffordable craft spent something');

// ---------- 7. the pocket: lowest-priority E, anywhere, never a walk ----------
resetSubject(SCRUB.x, SCRUB.y);
if (pocketHasBusiness()) fail('pocket: empty pockets claim business');
interactions.tryInteract();
if (ui.activeDialogue) fail('pocket: an empty-pocket whiffed E opened a dialogue (was silent before the wave)');
P.copper = HITTER_COPPER_COST;
interactions.tryInteract();
if (!ui.activeDialogue || ui.activeDialogue.name !== 'YOUR POCKETS') fail(`pocket: scrub E with copper opened '${ui.activeDialogue && ui.activeDialogue.name}', expected YOUR POCKETS`);
else {
  const leave = ui.activeDialogue.opts[ui.activeDialogue.opts.length - 1];
  if (!/leave/.test(leave.label)) fail('pocket: no leave option (the player always has an exit)');
  if (!click('fold a hitter', 'pocket craft')) {} else if (P.hitters !== 1 || P.copper !== 0) fail('pocket: menu craft did not spend copper for a hitter');
}
ui.closeDialogue(); state.mode = 'playing';
interactions.tryInteract(); // hitters=1, copper=0 — pocket still answers
if (!ui.activeDialogue || ui.activeDialogue.name !== 'YOUR POCKETS') fail('pocket: E with a hitter and no copper did not open the pocket');
else if (!click('hit the emergency hitter', 'pocket hit')) {} else if (P.rockedT !== HITTER_HIGH_MS) fail('pocket: menu hit did not ignite');
ui.closeDialogue(); state.mode = 'playing'; P.rockedT = 0; P.crashT = 0; P.hitterHigh = false;
// zone verbs keep priority: at the block with copper, the E is the block's.
resetSubject(1064 - P.w / 2, 882 - P.h / 2);
P.copper = 5;
interactions.tryInteract();
if (!ui.activeDialogue || ui.activeDialogue.name !== 'THE BLOCK') fail(`pocket: at the block the E went to '${ui.activeDialogue && ui.activeDialogue.name}', expected THE BLOCK — the pocket must never steal a zone verb`);
ui.closeDialogue(); state.mode = 'playing';

// ---------- 8. the rare find (I-RARE-FIND) ----------
if (dumpsterHitterRoll(0)) fail('rare find: an adjacent-to-the-block dumpster rolled a hitter');
resetSubject(SCRUB.x, SCRUB.y);
const farDumpster = { type: 'dumpster', x: 5480, y: 2140, w: 36, h: 24, looted: false };
forced = HITTER_FIND_CHANCE / 2; // under the rare threshold -> the find fires
interactions.startDumpsterDive(farDumpster);
if (!ui.activeDialogue) fail('rare find: dive opened no dialogue');
else if (!ui.activeDialogue.opts.some(o => o.label.includes('the emergency hitter'))) fail('rare find: forced-lucky far dive did not offer the hitter');
else {
  click('the emergency hitter', 'rare find take');
  if (P.hitters !== 1) fail(`rare find: taking the found hitter granted ${P.hitters}`);
}
ui.closeDialogue(); state.mode = 'playing';
const nearDumpster = { type: 'dumpster', x: 1050, y: 840, w: 36, h: 24, looted: false };
interactions.startDumpsterDive(nearDumpster); // same lucky roll, farFactor 0
if (ui.activeDialogue && ui.activeDialogue.opts.some(o => o.label.includes('the emergency hitter'))) fail('rare find: a block-adjacent dumpster offered the hitter');
ui.closeDialogue(); state.mode = 'playing';
forced = 0.5; // ordinary luck -> never offered
const dryDumpster = { type: 'dumpster', x: 5480, y: 2140, w: 36, h: 24, looted: false };
interactions.startDumpsterDive(dryDumpster);
if (ui.activeDialogue && ui.activeDialogue.opts.some(o => o.label.includes('the emergency hitter'))) fail('rare find: an ordinary dive offered the hitter — rare means rare');
ui.closeDialogue(); state.mode = 'playing';

// ---------- 9. save: additive, round-trips, junk-proof ----------
{
  const store = new Map();
  context.window.storage = {
    async set(key, value) { store.set(key, JSON.parse(JSON.stringify(value))); },
    async get(key) { return { value: store.get(key) }; },
  };
  resetSubject(SCRUB.x, SCRUB.y);
  P.hitters = 3; P.hitterHigh = false;
  await audioSave.saveGame();
  P.hitters = 0;
  if (!(await audioSave.loadGame())) fail('save: loadGame refused its own save');
  if (P.hitters !== 3) fail(`save: hitters round-tripped to ${P.hitters}, expected 3`);
  const saved = store.get(audioSave.SAVE_KEY);
  if (saved.version !== 10) fail(`save: version moved to ${saved.version} (must stay 10 — additive keys only)`);
  delete saved.player.hitters; delete saved.player.hitterHigh; // a pre-hitter save
  P.hitters = 9; P.hitterHigh = true;
  if (!(await audioSave.loadGame())) fail('save: loadGame refused a pre-hitter save');
  if (P.hitters !== 0 || P.hitterHigh !== false) fail(`save: pre-hitter save loaded hitters=${P.hitters}, hitterHigh=${P.hitterHigh}, expected 0/false`);
  saved.player = { ...saved.player, hitters: -7.5, hitterHigh: 'yes' };
  await context.window.storage.set(audioSave.SAVE_KEY, saved);
  await audioSave.loadGame();
  if (P.hitters !== 0) fail(`save: junk hitters normalized to ${P.hitters}, expected 0`);
}

// ---------- verdict ----------
if (failures.length) {
  console.error(`HITTER GATE: ${failures.length} failure(s)`);
  failures.slice(0, 40).forEach(message => console.error(`- ${message}`));
  process.exit(1);
}
console.log(`HITTER GATE: PASS (full-cycle marathon: rock ${rock.horizonShakes.toFixed(1)} shakes vs hitter ${emergency.horizonShakes.toFixed(1)} at 40s; high ${rock.highMs}/${emergency.highMs}ms, crash ${rock.crashMs}/${emergency.crashMs}ms, brain -${rock.brainCost}/-${emergency.brainCost}, cred +${rock.cred}/+${emergency.cred}; craft ${HITTER_COPPER_COST} copper one-way, find ${HITTER_FIND_CHANCE * 100}% far-only, save additive)`);
