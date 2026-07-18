#!/usr/bin/env node
/**
 * copper-sites-gate.mjs — v22 wave 5.1. Proves the two invariants the copper-site
 * system lives or dies by, then walks every path of every site headlessly.
 *
 * I-ONE-ENGINE: the 3-stage heist flow exists ONCE (activities.js), interpreted per
 * site from COPPER_SITES data. The load-bearing single-instance expressions — the
 * heistsToday increment, the `state.mode = 'heist'` entry, the yield roll — are
 * counted across all of src/. A copy-pasted flow trips this before it ships.
 *
 * I-DAILY-CAP-SHARED: one cap (3/day) across ALL sites, one yield (2-4) at ALL
 * sites. Site effects are structurally forbidden from granting cash or copper —
 * the ONLY copper faucet is the engine's single roll — so adding sites cannot
 * move the daily income ceiling (conductor floor stays ~$270/day). Proven both
 * statically (allowed effect keys) and dynamically (3 heists at 3 different
 * sites, then a 4th site refuses).
 *
 * I-NO-SOFTLOCK: every entry × both RNG branches × every exit × both branches
 * ends at state.mode === 'playing'. A dead modal reds this gate, not a player.
 */
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const failures = [];
const fail = message => failures.push(message);

// ---------- 1. one-engine proof (static, all of src/) ----------
function sourceFiles(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...sourceFiles(full));
    else if (entry.name.endsWith('.js')) out.push(full);
  }
  return out;
}
const srcText = sourceFiles(path.join(ROOT, 'src'))
  .map(file => `// FILE ${path.relative(ROOT, file)}\n${fs.readFileSync(file, 'utf8')}`)
  .join('\n');
const countAll = pattern => (srcText.match(pattern) || []).length;

const SINGLETONS = [
  [/state\.counters\.heistsToday\s*=\s*\(state\.counters\.heistsToday\s*\|\|\s*0\)\s*\+\s*1/g, 'heistsToday increment'],
  [/state\.mode\s*=\s*'heist'/g, "state.mode = 'heist' entry"],
  [/HEIST_YIELD_MIN\s*\+\s*Math\.floor\(Math\.random\(\)\s*\*\s*HEIST_YIELD_SPAN\)/g, 'copper yield roll'],
  [/function\s+heistStage/g, 'heistStage definition'],
  [/function\s+startHeist/g, 'startHeist definition'],
  [/HEIST_DAILY_CAP\s*=\s*3\b/g, 'HEIST_DAILY_CAP = 3 declaration'],
  [/HEIST_YIELD_MIN\s*=\s*2\b/g, 'HEIST_YIELD_MIN = 2 declaration'],
  [/HEIST_YIELD_SPAN\s*=\s*3\b/g, 'HEIST_YIELD_SPAN = 3 declaration'],
];
for (const [pattern, label] of SINGLETONS) {
  const n = countAll(pattern);
  if (n !== 1) fail(`one-engine: ${label} appears ${n} time(s), expected exactly 1`);
}
if (countAll(/heistsToday\s*\+\+|\+\+\s*state\.counters\.heistsToday|heistsToday\s*\+=/g))
  fail('one-engine: a second heistsToday mutation form exists');

// ---------- load the game ----------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);
const props = module('src/data/props.js');
const world = module('src/data/world.js');
const acts = module('src/minigames/activities.js');
const ui = module('src/core/runtime_ui.js');
const rb = context.window._rb;
const state = rb.state, P = rb.P;

// ---------- 2. registry shape (structural income lockdown) ----------
const SITES = props.COPPER_SITES;
const ENTRY_KINDS = new Set(['roll', 'lockpick', 'item', 'cash', 'wait', 'sure']);
const EFFECT_KEYS = new Set(['text', 'dur', 'hp', 'glass', 'wanted', 'brain', 'shakes']);
const EFFECT_BOUNDS = { hp: 15, wanted: 2, brain: 5, shakes: 10 };
function checkEffect(fx, where) {
  if (!fx || typeof fx !== 'object') { fail(`${where}: missing effects object`); return; }
  if (!String(fx.text || '').trim()) fail(`${where}: empty effect text`);
  for (const key of Object.keys(fx)) {
    if (key === 'extra' || key === 'extraChance') continue; // lockpick-fail rider, checked by caller
    if (!EFFECT_KEYS.has(key)) fail(`${where}: effect key '${key}' is not in the allowed set — sites cannot mint resources`);
    if (key in EFFECT_BOUNDS && !(fx[key] > 0 && fx[key] <= EFFECT_BOUNDS[key])) fail(`${where}: ${key}=${fx[key]} out of bounds (0, ${EFFECT_BOUNDS[key]}]`);
  }
}
if (!Array.isArray(SITES) || SITES.length < 4) fail(`registry: ${SITES?.length} sites, expected >= 4`);
for (const field of ['id', 'title', 'hint', 'who']) {
  const seen = new Set(SITES.map(site => site[field]));
  if (seen.size !== SITES.length || seen.has(undefined) || seen.has('')) fail(`registry: '${field}' values are not unique and non-empty`);
}
for (const site of SITES) {
  const at = `site ${site.id}`;
  if (!String(site.capText || '').trim()) fail(`${at}: empty capText`);
  if (!String(site.intro || '').trim()) fail(`${at}: empty intro`);
  if (!String(site.getawayText || '').trim()) fail(`${at}: empty getawayText`);
  for (const key of ['text', 'stripAfter', 'listenAfter']) if (!String(site.pipes?.[key] || '').trim()) fail(`${at}: empty pipes.${key}`);
  if (!Array.isArray(site.entries) || site.entries.length < 2) fail(`${at}: fewer than 2 entries`);
  for (const [i, entry] of (site.entries || []).entries()) {
    const here = `${at} entry ${i} (${entry.kind})`;
    if (!ENTRY_KINDS.has(entry.kind)) { fail(`${here}: unknown kind`); continue; }
    if (entry.kind === 'roll') {
      if (!(entry.p > 0 && entry.p < 1)) fail(`${here}: p=${entry.p} not in (0,1)`);
      checkEffect(entry.under, `${here}.under`); checkEffect(entry.over, `${here}.over`);
    } else if (entry.kind === 'lockpick') {
      checkEffect(entry.ok, `${here}.ok`); checkEffect(entry.fail, `${here}.fail`);
      if (entry.fail?.extra) { checkEffect(entry.fail.extra, `${here}.fail.extra`); if (!(entry.fail.extraChance > 0 && entry.fail.extraChance < 1)) fail(`${here}: bad extraChance`); }
    } else if (entry.kind === 'item') {
      if (!entry.itemId || !entry.haveLabel || !entry.lackLabel) fail(`${here}: item entry incomplete`);
      checkEffect(entry.effect, `${here}.effect`);
    } else if (entry.kind === 'cash') {
      if (!(entry.cost > 0 && entry.cost <= 5)) fail(`${here}: cost=${entry.cost} out of (0,5]`);
      if (!entry.haveLabel || !entry.lackLabel) fail(`${here}: cash entry incomplete`);
      checkEffect(entry.effect, `${here}.effect`);
    } else {
      checkEffect(entry.effect, `${here}.effect`);
    }
  }
  if (!Array.isArray(site.exits) || site.exits.length !== 2) fail(`${at}: expected exactly 2 exits`);
  for (const [i, exit] of (site.exits || []).entries()) {
    const here = `${at} exit ${i}`;
    if (!(exit.p > 0 && exit.p < 1)) fail(`${here}: p=${exit.p} not in (0,1)`);
    checkEffect(exit.under, `${here}.under`); checkEffect(exit.over, `${here}.over`);
  }
}
// heat profile: the quiet site never touches wanted; at least one site does (the knob is real).
const mentionsWanted = site => JSON.stringify(site).includes('"wanted"');
const quiet = SITES.find(site => site.id === 'cold_not');
if (quiet && mentionsWanted(quiet)) fail('heat profile: cold_not is the quiet site and must not touch wanted on any path');
if (!SITES.some(mentionsWanted)) fail('heat profile: no site varies wanted at all');

// ---------- 3. anchor parity (registry rects cannot drift from the world) ----------
for (const site of SITES) {
  const anchor = site.anchor;
  if (anchor.kind === 'locked_building') {
    if (site.id !== 'abandoned') fail(`anchor: only the abandoned site may key on the locked building (${site.id})`);
    continue;
  }
  if (anchor.facadeId) {
    const facade = world.LANDMARK_FACADES.find(f => f.id === anchor.facadeId);
    if (!facade) { fail(`anchor: facade '${anchor.facadeId}' not found for ${site.id}`); continue; }
    for (const key of ['x', 'y', 'w', 'h']) if (facade[key] !== anchor[key]) fail(`anchor: ${site.id}.${key}=${anchor[key]} drifted from facade ${anchor.facadeId}.${key}=${facade[key]}`);
  } else if (anchor.propType) {
    const prop = props.PROPS.find(p => p.type === anchor.propType && p.x === anchor.x && p.y === anchor.y);
    if (!prop) { fail(`anchor: no ${anchor.propType} prop at (${anchor.x},${anchor.y}) for ${site.id}`); continue; }
    if (prop.w !== anchor.w || prop.h !== anchor.h) fail(`anchor: ${site.id} rect drifted from its ${anchor.propType} prop`);
  } else {
    fail(`anchor: ${site.id} rect has neither facadeId nor propType — unanchored coordinates drift silently`);
  }
}
// trigger lookup answers inside every anchor (abandoned building is locked at start).
for (const site of SITES) {
  let r = site.anchor;
  if (r.kind === 'locked_building') r = props.BUILDINGS.find(b => b.locked);
  const found = props.copperSiteAt(r.x + r.w / 2, r.y + r.h / 2);
  if (found?.id !== site.id) fail(`trigger: copperSiteAt center of ${site.id} returned ${found?.id ?? 'null'}`);
}
if (props.copperSiteAt(50, 5500)) fail('trigger: copperSiteAt answered in open scrub');

// ---------- dialogue driver ----------
let forced = 0.5;
context.Math.random = () => forced;
function currentDialogue() { return ui.activeDialogue; }
function click(matcher, where) {
  const dlg = currentDialogue();
  if (!dlg) { fail(`${where}: no dialogue open`); return false; }
  const opt = typeof matcher === 'number' ? dlg.opts[matcher] : dlg.opts.find(o => String(o.label).includes(matcher));
  if (!opt) { fail(`${where}: option '${matcher}' not found in [${dlg.opts.map(o => o.label).join(' | ')}]`); return false; }
  if (opt.disabled) { fail(`${where}: option '${opt.label}' is disabled`); return false; }
  ui.closeDialogue();
  opt.action && opt.action();
  return true;
}
function resetPlayer() {
  state.mode = 'playing';
  ui.closeDialogue();
  state.counters.heistsToday = 0;
  P.hp = P.maxHp; P.wanted = 0; P.brain = 100; P.cash = 50; P.shakes = 0;
  P.inventory = [{ id: 'soap', n: 'soap', q: 1 }, { id: 'food', n: 'a can of food (unmarked)', q: 1 }, { id: 'food', n: 'a can of food (unmarked)', q: 1 }];
}
function solveLockpick(where) {
  // target order is hidden; learn it — a wrong pin resets ALL pins but the target is fixed,
  // and a right pin STAYS set, so track live progress and only replay after a reset.
  const known = [];
  let progress = 0; // pins currently set in the live mini
  let guesses = 0;
  while (known.length < 4 && guesses < 40) {
    let advanced = false;
    for (const candidate of [1, 2, 3, 4]) {
      if (known.includes(candidate)) continue;
      while (progress < known.length) { // replay the learned prefix after a reset
        if (!click(`set pin ${known[progress]}`, `${where} replay`)) return false;
        progress++;
      }
      guesses++;
      const before = (currentDialogue()?.text.match(/●/g) || []).length;
      if (!click(`set pin ${candidate}`, `${where} probe`)) return false;
      const dlg = currentDialogue();
      if (!dlg || !/LOCKPICK/.test(dlg.name)) return true; // 4th pin set -> lock opened -> next stage
      const after = (dlg.text.match(/●/g) || []).length;
      if (after > before) { known.push(candidate); progress = after; advanced = true; break; }
      progress = 0; // wrong guess — the mini reset every pin
    }
    if (!advanced) return false;
  }
  return known.length === 4;
}

// ---------- 4+6. dynamic: every site, every entry, both branches, every exit, both branches ----------
function runHeist(site, entryIndex, entryForced, exitIndex, exitForced, where) {
  resetPlayer();
  forced = entryForced;
  acts.startHeist(site.id);
  if (currentDialogue()?.name !== site.title) { fail(`${where}: stage-1 dialogue title ${currentDialogue()?.name}`); return; }
  const entry = site.entries[entryIndex];
  const entryLabel = entry.label || entry.haveLabel; // resetPlayer stocks cash + items, so the have-side renders
  if (entry.kind === 'lockpick') {
    if (entryForced < 0.5) { // drive the mini to success
      if (!click(entryLabel, where)) return;
      if (!solveLockpick(where)) { fail(`${where}: lockpick solver stalled`); return; }
    } else { // give up -> fail path (+ possible extra at forced RNG)
      if (!click(entryLabel, where)) return;
      if (!click('give up.', where)) return;
    }
  } else {
    if (!click(entryLabel, where)) return;
  }
  if (currentDialogue()?.name !== 'THE COPPER PIPES') { fail(`${where}: entry did not reach the pipes (dialogue: ${currentDialogue()?.name})`); return; }
  const copperBefore = P.copper;
  if (!click('strip them.', where)) return;
  const got = P.copper - copperBefore;
  if (got < 2 || got > 4) fail(`${where}: yield ${got} outside [2,4] — the ceiling moved`);
  if (currentDialogue()?.name !== 'GETAWAY') { fail(`${where}: strip did not reach the getaway`); return; }
  forced = exitForced;
  if (!click(site.exits[exitIndex].label, where)) return;
  if (state.mode !== 'playing') fail(`${where}: exit stranded state.mode='${state.mode}' — dead modal`);
  if (P.hp <= 0) fail(`${where}: full-health run ended dead (hp ${P.hp})`);
  if (currentDialogue()) fail(`${where}: dialogue still open after exit`);
}
for (const site of SITES) {
  for (let e = 0; e < site.entries.length; e++) {
    for (const entryForced of [0.0001, 0.9999]) {
      runHeist(site, e, entryForced, 0, 0.0001, `${site.id} entry ${e} rng ${entryForced}`);
    }
  }
  for (let x = 0; x < site.exits.length; x++) {
    for (const exitForced of [0.0001, 0.9999]) {
      runHeist(site, 0, 0.0001, x, exitForced, `${site.id} exit ${x} rng ${exitForced}`);
    }
  }
  // leave at stage 1 and stage 2 both restore play.
  resetPlayer(); forced = 0.5; acts.startHeist(site.id);
  if (!click('leave.', `${site.id} stage-1 leave`) || state.mode !== 'playing') fail(`${site.id}: stage-1 leave did not restore playing`);
  resetPlayer(); acts.startHeist(site.id); forced = 0.0001;
  click(site.entries.find(e => e.kind !== 'lockpick').label, `${site.id} stage-2 leave entry`);
  if (!click('leave.', `${site.id} stage-2 leave`) || state.mode !== 'playing') fail(`${site.id}: stage-2 leave did not restore playing`);
}

// shared cap: 3 heists at 3 different sites exhaust the day for a 4th site.
resetPlayer();
forced = 0.0001;
for (const id of ['cold_not', 'water_dept', 'rust_car']) {
  const site = SITES.find(s => s.id === id);
  acts.startHeist(id);
  click(site.entries.find(e => e.kind !== 'lockpick').label, `cap run ${id}`);
  click('strip them.', `cap run ${id}`);
  click(site.exits[0].label, `cap run ${id}`);
}
if (state.counters.heistsToday !== 3) fail(`cap: heistsToday=${state.counters.heistsToday} after 3 heists`);
const copperAtCap = P.copper, cashAtCap = P.cash;
acts.startHeist('abandoned');
const capDialogue = currentDialogue();
if (!capDialogue || capDialogue.opts.length !== 1) fail('cap: 4th site did not show the single-option refusal');
else click(0, 'cap refusal');
if (state.counters.heistsToday !== 3) fail(`cap: refusal moved the counter to ${state.counters.heistsToday}`);
if (P.copper !== copperAtCap || P.cash !== cashAtCap) fail('cap: the refused heist changed copper or cash');
if (state.mode !== 'playing') fail(`cap: refusal stranded mode='${state.mode}'`);

// ---------- 5. ceiling proof: forced-extreme yields identical at every site ----------
for (const site of SITES) {
  for (const [f, expect] of [[0.0001, 2], [0.9999, 4]]) {
    resetPlayer(); forced = f;
    acts.startHeist(site.id);
    click(site.entries.find(e => e.kind !== 'lockpick').label, `yield ${site.id}`);
    const before = P.copper;
    click('strip them.', `yield ${site.id}`);
    if (P.copper - before !== expect) fail(`yield: ${site.id} forced ${f} gave ${P.copper - before}, expected ${expect} — sites must share one yield`);
    click(site.exits[0].label, `yield ${site.id}`);
  }
}

// ---------- verdict ----------
if (failures.length) {
  console.error(`COPPER SITES GATE: ${failures.length} failure(s)`);
  failures.slice(0, 40).forEach(message => console.error(`- ${message}`));
  process.exit(1);
}
console.log(`COPPER SITES GATE: PASS (${SITES.length} sites, one engine, shared cap 3/day, yield locked 2-4, ${SITES.reduce((n, s) => n + s.entries.length, 0)} entries + ${SITES.reduce((n, s) => n + s.exits.length, 0)} exits exhaustively walked, cold_not quiet / rust_car hot)`);
