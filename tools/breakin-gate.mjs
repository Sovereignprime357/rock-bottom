#!/usr/bin/env node
/**
 * breakin-gate.mjs — v22 wave 5.5. Proves the two invariants break-ins live or
 * die by, then walks every gate, entry, take, and getaway headlessly.
 *
 * I-GATE-REAL: a `tool` door genuinely checks P.equip.tool identity; a `cred`
 * door genuinely checks P.cred >= n. Refusal is proven in both directions at
 * the exact boundary (24 refuses / 25 opens), with the wrong tool, and on the
 * both-gates site in declared precedence order (tool speaks before cred). A
 * refused door spends nothing — not the daily cap, not a dollar.
 *
 * I-ONE-ENGINE: break-ins run through the SAME startHeist/heistStage flow as
 * copper — the gate vocabulary (failedHeistGate), the breakinsToday increment,
 * and the cap declaration each exist exactly once across src/.
 *
 * I-NO-MINT-DRIFT: break-ins ride their own governor (breakinsToday, cap 2/day),
 * never heistsToday — proven by interleaving 3 copper heists with 2 break-ins in
 * one day and watching both counters, both refusals, and the dawn reset through
 * the REAL resetDailyCounters. Loot is structurally locked: allowed keys only,
 * cash <= 20/site, item ids from a vetted set, and no site can name copper,
 * rocks, supplies, or hitters anywhere in its JSON.
 *
 * I-NO-SOFTLOCK: every path — both refusals, every entry x both RNG branches,
 * take and alt, every exit x both branches, leave at stages 1 and 2 — ends at
 * state.mode === 'playing' with the dialogue closed.
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
  [/state\.counters\.breakinsToday\s*=\s*\(state\.counters\.breakinsToday\s*\|\|\s*0\)\s*\+\s*1/g, 'breakinsToday increment'],
  [/BREAKIN_DAILY_CAP\s*=\s*2\b/g, 'BREAKIN_DAILY_CAP = 2 declaration'],
  [/function\s+failedHeistGate/g, 'failedHeistGate definition (the gate vocabulary)'],
  [/g\.kind\s*===\s*'tool'/g, "tool gate check"],
  [/g\.kind\s*===\s*'cred'/g, "cred gate check"],
  [/function\s+startHeist/g, 'startHeist definition'],
  [/function\s+heistStage/g, 'heistStage definition'],
  [/BREAKIN_SITES\.find/g, 'engine lookup into BREAKIN_SITES'],
];
for (const [pattern, label] of SINGLETONS) {
  const n = countAll(pattern);
  if (n !== 1) fail(`one-engine: ${label} appears ${n} time(s), expected exactly 1`);
}
if (countAll(/breakinsToday\s*\+\+|\+\+\s*state\.counters\.breakinsToday|breakinsToday\s*\+=/g))
  fail('one-engine: a second breakinsToday mutation form exists');

// ---------- load the game ----------
const { context, module } = await loadModularGame();
context.window._rb.startGame(false);
const props = module('src/data/props.js');
const acts = module('src/minigames/activities.js');
const ui = module('src/core/runtime_ui.js');
const daily = module('src/systems/daily_hideouts.js');
const robbery = module('src/systems/robbery.js');
const catalogs = module('src/data/catalogs.js');
const rb = context.window._rb;
const state = rb.state, P = rb.P;

// ---------- 2. registry shape (structural loot lockdown) ----------
const SITES = props.BREAKIN_SITES;
const COPPER = props.COPPER_SITES;
// lockpick is engine vocabulary, but this walk has no solver for it; extend the
// walk before a break-in site may use it.
const ENTRY_KINDS = new Set(['roll', 'item', 'cash', 'wait', 'sure']);
const EFFECT_KEYS = new Set(['text', 'dur', 'hp', 'glass', 'wanted', 'brain', 'shakes']);
const EFFECT_BOUNDS = { hp: 15, wanted: 2, brain: 5, shakes: 10 };
const GATE_KINDS = new Set(['tool', 'cred']);
const LOOT_KEYS = new Set(['title', 'text', 'takeLabel', 'cash', 'items', 'takeToast', 'takeDur', 'altLabel', 'alt']);
const LOOT_ITEM_IDS = new Set(['food', 'junk']);
const LOOT_CASH_MAX = 20;
const DAILY_TAKE_CEILING = 40;
const FORBIDDEN_JSON_KEYS = ['"copper"', '"rocks"', '"supplies"', '"hitters"'];

function checkEffect(fx, where) {
  if (!fx || typeof fx !== 'object') { fail(`${where}: missing effects object`); return; }
  if (!String(fx.text || '').trim()) fail(`${where}: empty effect text`);
  for (const key of Object.keys(fx)) {
    if (!EFFECT_KEYS.has(key)) fail(`${where}: effect key '${key}' is not in the allowed set — sites cannot mint resources`);
    if (key in EFFECT_BOUNDS && !(fx[key] > 0 && fx[key] <= EFFECT_BOUNDS[key])) fail(`${where}: ${key}=${fx[key]} out of bounds (0, ${EFFECT_BOUNDS[key]}]`);
  }
}

// 5.5 proved the generalization at 2-3 sites; 5.6 filled the quarter's dead band
// with exactly two more (drained_pool, visitor_center). Growing this number again
// is a new wave with its own spec, not a drive-by edit.
if (!Array.isArray(SITES) || SITES.length !== 5) fail(`registry: ${SITES?.length} sites, expected exactly 5 (3 from wave 5.5 + 2 from wave 5.6)`);
for (const field of ['id', 'title', 'hint', 'who']) {
  const seen = new Set(SITES.map(site => site[field]));
  if (seen.size !== SITES.length || seen.has(undefined) || seen.has('')) fail(`registry: '${field}' values are not unique and non-empty`);
}
const copperIds = new Set(COPPER.map(site => site.id));
for (const site of SITES) if (copperIds.has(site.id)) fail(`registry: site id '${site.id}' collides with a copper site`);

for (const site of SITES) {
  const at = `site ${site.id}`;
  const raw = JSON.stringify(site);
  for (const forbidden of FORBIDDEN_JSON_KEYS) if (raw.includes(forbidden)) fail(`${at}: names ${forbidden} — break-in sites must be structurally unable to touch it`);
  if (!String(site.capText || '').trim()) fail(`${at}: empty capText`);
  if (!String(site.intro || '').trim()) fail(`${at}: empty intro`);
  if (!String(site.getawayText || '').trim()) fail(`${at}: empty getawayText`);

  // the door (I-GATE-REAL, static half)
  if (!Array.isArray(site.gates) || site.gates.length < 1 || site.gates.length > 2) fail(`${at}: expected 1-2 gates, got ${site.gates?.length}`);
  for (const [i, gate] of (site.gates || []).entries()) {
    const here = `${at} gate ${i} (${gate.kind})`;
    if (!GATE_KINDS.has(gate.kind)) { fail(`${here}: unknown gate kind`); continue; }
    if (!String(gate.refuse || '').trim()) fail(`${here}: a gate with no refusal text is a silent no-op`);
    if (gate.kind === 'tool' && gate.tool !== 'crowbar') fail(`${here}: tool gate names '${gate.tool}', expected 'crowbar'`);
    if (gate.kind === 'cred' && !(gate.cred >= 10 && gate.cred <= 400)) fail(`${here}: cred=${gate.cred} outside [10, 400]`);
  }
  const kinds = (site.gates || []).map(gate => gate.kind);
  if (new Set(kinds).size !== kinds.length) fail(`${at}: duplicate gate kinds`);
  if (kinds.length === 2 && !(kinds[0] === 'tool' && kinds[1] === 'cred')) fail(`${at}: both-gates site must list tool before cred (declared precedence)`);

  if (!Array.isArray(site.entries) || site.entries.length < 2) fail(`${at}: fewer than 2 entries`);
  for (const [i, entry] of (site.entries || []).entries()) {
    const here = `${at} entry ${i} (${entry.kind})`;
    if (!ENTRY_KINDS.has(entry.kind)) { fail(`${here}: kind not in the break-in walk vocabulary`); continue; }
    if (entry.kind === 'roll') {
      if (!(entry.p > 0 && entry.p < 1)) fail(`${here}: p=${entry.p} not in (0,1)`);
      checkEffect(entry.under, `${here}.under`); checkEffect(entry.over, `${here}.over`);
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

  // the take (I-NO-MINT-DRIFT, static half)
  const L = site.loot;
  if (!L || typeof L !== 'object') { fail(`${at}: missing loot`); continue; }
  for (const key of Object.keys(L)) if (!LOOT_KEYS.has(key)) fail(`${at}: loot key '${key}' is not in the allowed set`);
  for (const key of ['title', 'text', 'takeLabel', 'takeToast', 'altLabel']) if (!String(L[key] || '').trim()) fail(`${at}: empty loot.${key}`);
  if (!(L.cash > 0 && L.cash <= LOOT_CASH_MAX)) fail(`${at}: loot.cash=${L.cash} out of (0, ${LOOT_CASH_MAX}]`);
  if (!Array.isArray(L.items) || L.items.length < 1 || L.items.length > 2) fail(`${at}: loot.items must hold 1-2 items`);
  for (const item of (L.items || [])) {
    if (!LOOT_ITEM_IDS.has(item.id)) fail(`${at}: loot item id '${item.id}' is not vetted (allowed: ${[...LOOT_ITEM_IDS].join(', ')})`);
    if (!String(item.n || '').trim()) fail(`${at}: loot item without a name`);
  }
  if (!L.alt || !String(L.alt.text || '').trim()) fail(`${at}: loot.alt is not a real alternative`);
  for (const key of Object.keys(L.alt || {})) if (!['text', 'brain', 'dur'].includes(key)) fail(`${at}: loot.alt key '${key}' not allowed`);
  if (L.alt && L.alt.brain !== undefined && !(L.alt.brain > 0 && L.alt.brain <= 8)) fail(`${at}: loot.alt.brain=${L.alt.brain} out of (0,8]`);

  if (!Array.isArray(site.exits) || site.exits.length !== 2) fail(`${at}: expected exactly 2 exits`);
  for (const [i, exit] of (site.exits || []).entries()) {
    const here = `${at} exit ${i}`;
    if (!(exit.p > 0 && exit.p < 1)) fail(`${here}: p=${exit.p} not in (0,1)`);
    checkEffect(exit.under, `${here}.under`); checkEffect(exit.over, `${here}.over`);
  }
}

// gate coverage: one tool-only, one cred-only, one with both (the precedence witness).
const gateSignature = site => (site.gates || []).map(gate => gate.kind).sort().join('+');
const signatures = SITES.map(gateSignature);
for (const wanted of ['tool', 'cred', 'cred+tool']) {
  if (!signatures.includes(wanted)) fail(`gate coverage: no site with gate signature '${wanted}'`);
}

// the daily ceiling: cap 2/day x two richest sites.
const cashSorted = SITES.map(site => site.loot?.cash || 0).sort((a, b) => b - a);
const worstDay = (cashSorted[0] || 0) + (cashSorted[1] || 0);
if (worstDay > DAILY_TAKE_CEILING) fail(`ceiling: worst-case daily take $${worstDay} exceeds $${DAILY_TAKE_CEILING}`);

// governor wiring and robbery safety, through the real modules.
if (!daily.DAILY_COUNTER_KEYS.includes('breakinsToday')) fail("governor: 'breakinsToday' is not in DAILY_COUNTER_KEYS — the cap would never reset at dawn");
if (robbery.LOSABLE_EQUIP_SLOTS.includes('tool')) fail("robbery: the tool slot became losable — the crowbar (a door key) must not be stealable");
if (catalogs.EQUIPMENT.crowbar?.slot !== 'tool') fail(`equipment: crowbar slot is '${catalogs.EQUIPMENT.crowbar?.slot}', expected 'tool'`);

// ---------- 3. anchors: barren quarter, prop parity, disjoint triggers ----------
for (const site of SITES) {
  const anchor = site.anchor;
  const at = `anchor ${site.id}`;
  if (anchor.kind !== 'rect' || anchor.propType !== 'breakin_shell') { fail(`${at}: expected a rect anchored to a breakin_shell prop`); continue; }
  const prop = props.PROPS.find(p => p.type === 'breakin_shell' && p.x === anchor.x && p.y === anchor.y);
  if (!prop) { fail(`${at}: no breakin_shell prop at (${anchor.x},${anchor.y})`); continue; }
  if (prop.w !== anchor.w || prop.h !== anchor.h) fail(`${at}: rect drifted from its prop`);
  if (!(anchor.y >= 3800 && anchor.y + anchor.h <= 5600 && anchor.x >= 0 && anchor.x + anchor.w <= 5680))
    fail(`${at}: (${anchor.x},${anchor.y},${anchor.w},${anchor.h}) is outside the barren quarter (x<5680, 3800<=y<=5600)`);
}
const shells = props.PROPS.filter(p => p.type === 'breakin_shell');
if (shells.length !== SITES.length) fail(`anchors: ${shells.length} breakin_shell props for ${SITES.length} sites`);
for (const site of SITES) {
  const r = site.anchor;
  const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
  if (props.breakinSiteAt(cx, cy)?.id !== site.id) fail(`trigger: breakinSiteAt center of ${site.id} missed`);
  if (props.copperSiteAt(cx, cy)) fail(`trigger: copperSiteAt answered inside ${site.id}`);
}
for (const site of COPPER) {
  let r = site.anchor;
  if (r.kind === 'locked_building') r = props.BUILDINGS.find(b => b.locked);
  if (r && props.breakinSiteAt(r.x + r.w / 2, r.y + r.h / 2)) fail(`trigger: breakinSiteAt answered inside copper site ${site.id}`);
}
if (props.breakinSiteAt(200, 5500)) fail('trigger: breakinSiteAt answered in open scrub');

// ---------- dialogue driver (copper-gate idiom) ----------
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
function resetPlayer({ tool = 'crowbar', cred = 100 } = {}) {
  state.mode = 'playing';
  ui.closeDialogue();
  state.counters.breakinsToday = 0;
  state.counters.heistsToday = 0;
  P.equip.tool = tool;
  P.cred = cred;
  P.hp = P.maxHp; P.wanted = 0; P.brain = 50; P.cash = 50; P.shakes = 0;
  P.inventory = [{ id: 'soap', n: 'soap', q: 1 }, { id: 'food', n: 'a can of food (unmarked)', q: 1 }, { id: 'food', n: 'a can of food (unmarked)', q: 1 }];
}

// ---------- 4. I-GATE-REAL, dynamic: both directions at the exact boundary ----------
function expectRefusal(site, gate, where) {
  const cashBefore = P.cash, capBefore = state.counters.breakinsToday;
  acts.startHeist(site.id);
  const dlg = currentDialogue();
  if (!dlg) { fail(`${where}: no dialogue at the refused door`); return; }
  if (dlg.name !== site.title || dlg.text !== gate.refuse) fail(`${where}: door did not speak the ${gate.kind} refusal (got '${dlg.text?.slice(0, 40)}...')`);
  if (dlg.opts.length !== 1) fail(`${where}: refusal offered ${dlg.opts.length} options, expected the single clean bounce`);
  click(0, where);
  if (state.mode !== 'playing') fail(`${where}: refusal stranded mode='${state.mode}'`);
  if (state.counters.breakinsToday !== capBefore) fail(`${where}: a refused door spent the daily cap`);
  if (P.cash !== cashBefore) fail(`${where}: a refused door moved cash`);
}
function expectOpen(site, where) {
  acts.startHeist(site.id);
  const dlg = currentDialogue();
  if (!dlg || dlg.name !== site.title || dlg.text !== site.intro) fail(`${where}: door did not open to the intro (got '${dlg?.text?.slice(0, 40)}...')`);
  click('leave.', where);
  if (state.mode !== 'playing') fail(`${where}: stage-1 leave stranded mode='${state.mode}'`);
}

const toolSite = SITES.find(site => gateSignature(site) === 'tool');
const credSite = SITES.find(site => gateSignature(site) === 'cred');
const bothSite = SITES.find(site => gateSignature(site) === 'cred+tool');

if (toolSite) {
  resetPlayer({ tool: null });
  expectRefusal(toolSite, toolSite.gates[0], `${toolSite.id} bare-handed`);
  resetPlayer({ tool: 'propane_torch' });
  expectRefusal(toolSite, toolSite.gates[0], `${toolSite.id} wrong tool (torch)`);
  resetPlayer({ tool: 'crowbar' });
  expectOpen(toolSite, `${toolSite.id} with crowbar`);
}
if (credSite) {
  const need = credSite.gates[0].cred;
  resetPlayer({ tool: null, cred: need - 1 });
  expectRefusal(credSite, credSite.gates[0], `${credSite.id} at cred ${need - 1}`);
  resetPlayer({ tool: null, cred: need });
  expectOpen(credSite, `${credSite.id} at cred ${need} (no tool needed)`);
}
if (bothSite) {
  const toolGate = bothSite.gates.find(gate => gate.kind === 'tool');
  const credGate = bothSite.gates.find(gate => gate.kind === 'cred');
  resetPlayer({ tool: null, cred: credGate.cred + 50 });
  expectRefusal(bothSite, toolGate, `${bothSite.id} rich cred, no crowbar (tool speaks first)`);
  resetPlayer({ tool: 'crowbar', cred: credGate.cred - 1 });
  expectRefusal(bothSite, credGate, `${bothSite.id} crowbar, thin cred (cred speaks second)`);
  resetPlayer({ tool: 'crowbar', cred: credGate.cred });
  expectOpen(bothSite, `${bothSite.id} both gates pass`);
}

// ---------- 5. full walk: every entry x rng, take + alt, every exit x rng ----------
function runBreakin(site, entryIndex, entryForced, useAlt, exitIndex, exitForced, where) {
  resetPlayer();
  forced = entryForced;
  acts.startHeist(site.id);
  if (currentDialogue()?.name !== site.title) { fail(`${where}: stage-1 title ${currentDialogue()?.name}`); return; }
  const entry = site.entries[entryIndex];
  if (!click(entry.label || entry.haveLabel, where)) return;
  if (currentDialogue()?.name !== site.loot.title) { fail(`${where}: entry did not reach the take (dialogue: ${currentDialogue()?.name})`); return; }
  if (useAlt) {
    const brainBefore = P.brain;
    if (!click(site.loot.altLabel, where)) return;
    const expected = Math.min(100, brainBefore + (site.loot.alt.brain || 0));
    if (P.brain !== expected) fail(`${where}: alt moved brain to ${P.brain}, expected ${expected}`);
  } else {
    const cashBefore = P.cash, invBefore = P.inventory.length;
    if (!click(site.loot.takeLabel, where)) return;
    if (P.cash - cashBefore !== site.loot.cash) fail(`${where}: take paid $${P.cash - cashBefore}, expected exactly $${site.loot.cash}`);
    if (P.inventory.length - invBefore !== site.loot.items.length) fail(`${where}: take granted ${P.inventory.length - invBefore} items, expected ${site.loot.items.length}`);
    for (const item of site.loot.items) if (!P.inventory.some(i => i.n === item.n)) fail(`${where}: loot item '${item.n}' missing after take`);
  }
  if (currentDialogue()?.name !== 'GETAWAY') { fail(`${where}: the take did not reach the getaway`); return; }
  forced = exitForced;
  if (!click(site.exits[exitIndex].label, where)) return;
  if (state.mode !== 'playing') fail(`${where}: exit stranded state.mode='${state.mode}' — dead modal`);
  if (P.hp <= 0) fail(`${where}: full-health run ended dead (hp ${P.hp})`);
  if (currentDialogue()) fail(`${where}: dialogue still open after exit`);
  if (state.counters.breakinsToday !== 1) fail(`${where}: one break-in moved the counter to ${state.counters.breakinsToday}`);
  if (state.counters.heistsToday !== 0) fail(`${where}: a break-in leaked into heistsToday`);
}
for (const site of SITES) {
  for (let e = 0; e < site.entries.length; e++) {
    for (const entryForced of [0.0001, 0.9999]) {
      runBreakin(site, e, entryForced, false, 0, 0.0001, `${site.id} entry ${e} rng ${entryForced}`);
    }
  }
  runBreakin(site, 0, 0.0001, true, 0, 0.0001, `${site.id} alt path`);
  for (let x = 0; x < site.exits.length; x++) {
    for (const exitForced of [0.0001, 0.9999]) {
      runBreakin(site, 0, 0.0001, false, x, exitForced, `${site.id} exit ${x} rng ${exitForced}`);
    }
  }
  resetPlayer(); forced = 0.5; acts.startHeist(site.id);
  if (!click('leave.', `${site.id} stage-1 leave`) || state.mode !== 'playing') fail(`${site.id}: stage-1 leave did not restore playing`);
  resetPlayer(); acts.startHeist(site.id); forced = 0.0001;
  click(site.entries[0].label || site.entries[0].haveLabel, `${site.id} stage-2 leave entry`);
  if (!click('leave.', `${site.id} stage-2 leave`) || state.mode !== 'playing') fail(`${site.id}: stage-2 leave did not restore playing`);
}

// ---------- 6. the two governors never touch (I-NO-MINT-DRIFT, dynamic) ----------
resetPlayer();
forced = 0.0001;
for (const id of ['cold_not', 'water_dept', 'rust_car']) {
  const site = COPPER.find(s => s.id === id);
  acts.startHeist(id);
  click(site.entries.find(e => e.kind !== 'lockpick').label, `copper run ${id}`);
  click('strip them.', `copper run ${id}`);
  click(site.exits[0].label, `copper run ${id}`);
}
if (state.counters.heistsToday !== 3) fail(`separation: heistsToday=${state.counters.heistsToday} after 3 copper heists`);
if (state.counters.breakinsToday !== 0) fail(`separation: copper heists leaked into breakinsToday (${state.counters.breakinsToday})`);
// copper is capped out; both break-ins still open (their governor is their own).
const twoSites = [SITES[0], SITES[1]];
for (const site of twoSites) {
  acts.startHeist(site.id);
  if (currentDialogue()?.text !== site.intro) fail(`separation: ${site.id} refused while copper was capped — the governors are entangled`);
  click(site.entries[0].label || site.entries[0].haveLabel, `separation ${site.id}`);
  click(site.loot.takeLabel, `separation ${site.id}`);
  forced = 0.0001;
  click(site.exits[0].label, `separation ${site.id}`);
}
if (state.counters.breakinsToday !== 2) fail(`separation: breakinsToday=${state.counters.breakinsToday} after 2 break-ins`);
if (state.counters.heistsToday !== 3) fail(`separation: break-ins moved heistsToday to ${state.counters.heistsToday}`);
// both caps now bind: the 3rd break-in and a 4th copper heist both refuse, spending nothing.
const third = SITES[2] || SITES[0];
const cashAtCap = P.cash;
acts.startHeist(third.id);
const capDialogue = currentDialogue();
if (!capDialogue || capDialogue.text !== third.capText || capDialogue.opts.length !== 1) fail('cap: 3rd break-in did not show the single-option capText refusal');
else click(0, 'breakin cap refusal');
if (state.counters.breakinsToday !== 2) fail(`cap: refusal moved breakinsToday to ${state.counters.breakinsToday}`);
if (P.cash !== cashAtCap) fail('cap: the refused break-in changed cash');
if (state.mode !== 'playing') fail(`cap: refusal stranded mode='${state.mode}'`);
acts.startHeist('abandoned');
if (currentDialogue()?.opts.length !== 1) fail('cap: copper cap did not hold after break-ins');
else click(0, 'copper cap refusal');

// dawn resets both governors through the REAL reset path.
daily.resetDailyCounters();
if (state.counters.breakinsToday !== 0 || state.counters.heistsToday !== 0) fail(`dawn: resetDailyCounters left breakinsToday=${state.counters.breakinsToday}, heistsToday=${state.counters.heistsToday}`);

// ---------- 7. save: crowbar, locker, governor round-trip (I-SAVE-ADDITIVE) ----------
resetPlayer({ tool: 'crowbar' });
state.flags.peteToolLocker = 'propane_torch';
state.counters.breakinsToday = 1;
await rb.saveGame();
P.equip.tool = null;
state.flags.peteToolLocker = null;
state.counters.breakinsToday = 0;
const loaded = await rb.loadGame();
if (!loaded) fail('save: loadGame refused its own save');
if (P.equip.tool !== 'crowbar') fail(`save: crowbar did not round-trip (tool='${P.equip.tool}')`);
if (state.flags.peteToolLocker !== 'propane_torch') fail(`save: pete's locker did not round-trip ('${state.flags.peteToolLocker}')`);
if (state.counters.breakinsToday !== 1) fail(`save: breakinsToday did not round-trip (${state.counters.breakinsToday})`);

// ---------- verdict ----------
if (failures.length) {
  console.error(`BREAKIN GATE: ${failures.length} failure(s)`);
  failures.slice(0, 40).forEach(message => console.error(`- ${message}`));
  process.exit(1);
}
console.log(`BREAKIN GATE: PASS (${SITES.length} sites through the one engine, tool/cred doors refuse both directions at the exact boundary, both-gates precedence tool->cred, governors separate (2/day vs 3/day) through the real dawn reset, take locked <= $${DAILY_TAKE_CEILING}/day with vetted item ids, ${SITES.reduce((n, s) => n + s.entries.length, 0)} entries + ${SITES.reduce((n, s) => n + s.exits.length, 0)} exits + take/alt/leave exhaustively walked, crowbar + locker + governor round-trip)`);
