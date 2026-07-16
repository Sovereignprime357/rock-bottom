// THE ECONOMY GATE — every dollar is named (v21, branch v21-economy).
// SPEC-v21-economy-gate.md · F-SOCK / F-ECON-PAYOUTS in REFACTOR-FINDINGS.md.
//
// This gate is a ruler, not a fix (I-NO-FIX). It enumerates every site in src/
// that increases a player resource — cash, rocks, soap rocks, copper, supplies,
// dirty supplies, inventory items — and refuses to compile green unless each
// one is exactly one of:
//
//   TRADE            guarded on a real precondition AND consumes a player
//                    resource in the same transaction. Not taken from the list
//                    on faith: the gate loads the real game, instruments the
//                    resource lanes, and drives the real menus through the real
//                    disabled flags — a BROKE profile (guards must hold at
//                    zero) and a STOCKED profile (payouts must consume).
//   LEDGER           a deliberate no-item payout, licensed by name below,
//                    citing a register token that literally appears in
//                    REFACTOR-FINDINGS.md (the I-EXCLUSION-LEDGER shape from
//                    OD-10, reused because it survived contact). Unsigned
//                    entries cannot compile green; stale entries go red too.
//   KNOWN VIOLATION  a standing defect already on the register (F-SOCK).
//                    Always red, by name, with live behavioral evidence, until
//                    the operator rules. NOT ledgered: a bug signed into a
//                    payout register is a grandfather list, and OD-9 already
//                    ruled that instrument-deletion.
//
// WHY A GREP IS NOT THIS GATE (the named trap): grep "P.cash +=" finds
// assignment sites, not violations — it cannot tell a guarded sale from a free
// dollar. The static census below exists only for COMPLETENESS (no site
// escapes classification); the judgment half is behavioral — guard and
// consumption reasoned together, the way the recognition gate diffed reward
// fields instead of trusting labels.
//
// TO WHOEVER IS HOLDING A RED READING FROM THIS GATE: a failing site is a
// finding for REFACTOR-FINDINGS.md, never a license to patch the game until
// the light turns green, and never a license to sign the site into the LEDGER
// yourself. LEDGER GROWTH IS A HUMAN-REVIEW TRIGGER (OD-10's known limit,
// inherited verbatim: the cite check proves a signature exists, never that it
// was worth signing). The sock stays red on purpose — whether "you always have
// another sock" is the joke is the operator's taste call, not a fix commit.
//
// Runs LAST in the suite: it ships with a standing honest red, and a standing
// reading must never mask a regression in the gates that protect shipped
// behavior (world-gate's original placement logic, inherited with the slot).
//
// SCOPE, NAMED: cred, brain, hp, equipment, and weapons are not census lanes —
// nothing in the tree converts them back to cash (no sell-back path exists),
// so they cannot mint. If a future wave adds a vendor that buys any of them,
// the census lanes must grow first. "Consumes what it CLAIMS" is label prose;
// the gate proves A real guard and A real consumption, not label truth
// (docs-gate's honest-scope rule). Gambles (the price guy, the lottery) may be
// net-positive per firing — conservation means something was staked in the
// same action, not that the house wins.
import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const TOOLS = import.meta.dirname;
const ROOT = path.resolve(TOOLS, '..');
const DEBUG_CENSUS = process.argv.includes('--census');
const DEBUG_OBSERVE = process.argv.includes('--observe');

const failures = [];
const fail = m => { if (!failures.includes(m)) failures.push(m); };

// ============================================================================
// HALF 1 — THE STATIC CENSUS (completeness; judges nothing)
// ============================================================================
const LANES = ['cash', 'rocks', 'soapRocks', 'copper', 'supplies', 'dirtySupplies'];

function* walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(full);
    else if (e.name.endsWith('.js')) yield full;
  }
}

// strip comments but PRESERVE line numbers (behavioral attribution joins on them)
function stripComments(src) {
  src = src.replace(/\/\*[\s\S]*?\*\//g, m => m.replace(/[^\n]/g, ' '));
  return src.split('\n').map(line => {
    let out = '', inStr = null;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (inStr) { out += c; if (c === '\\') { out += line[++i] ?? ''; } else if (c === inStr) inStr = null; continue; }
      if (c === '"' || c === "'" || c === '`') { inStr = c; out += c; continue; }
      if (c === '/' && line[i + 1] === '/') break;
      out += c;
    }
    return out;
  }).join('\n');
}

const census = []; // {file, line, norm, lane, occ}
const laneIncRe = new RegExp(`P\\.(${LANES.join('|')})\\s*(\\+\\+|\\+=|=(?!=))`, 'g');

for (const full of walk(path.join(ROOT, 'src'))) {
  const file = path.relative(ROOT, full).replace(/\\/g, '/');
  const clean = stripComments(fs.readFileSync(full, 'utf8'));
  clean.split('\n').forEach((raw, i) => {
    const norm = raw.trim().replace(/\s+/g, ' ');
    laneIncRe.lastIndex = 0;
    let m;
    while ((m = laneIncRe.exec(raw))) {
      const [, lane, op] = m;
      if (op === '=') {
        // plain assignment is a grant only when the RHS (to the next ';')
        // self-increments; resets and Math.max(0, x - n) decrements are not
        const rhs = raw.slice(m.index + m[0].length).split(';')[0];
        if (!/\+/.test(rhs)) continue;
      }
      census.push({ file, line: i + 1, norm, lane });
    }
    let idx = -1;
    while ((idx = raw.indexOf('P.inventory.push(', idx + 1)) !== -1) {
      census.push({ file, line: i + 1, norm, lane: 'inventory' });
    }
    // tripwire: an inventory reassignment must be a removal (filter) or a
    // reset — anything else is a grant path the census cannot see
    if (/P\.inventory\s*=(?!=)/.test(raw) && !/\.filter\(/.test(raw)
        && !/P\.inventory\s*=\s*\[\s*\]/.test(raw)
        && !/P\.inventory\s*=\s*(data|save|loaded|payload|normalized)/.test(raw)) {
      fail(`CENSUS: unrecognized P.inventory reassignment at ${file}:${i + 1} — not a filter, not a reset; the census cannot classify what it cannot parse (I-EVERY-DOLLAR-NAMED)`);
    }
  });
}
const seenNorm = new Map();
for (const s of census) {
  const k = `${s.file}#${s.norm}`;
  s.occ = seenNorm.get(k) || 0;
  seenNorm.set(k, s.occ + 1);
}
const censusByFileLine = new Map(census.map(s => [`${s.file}#${s.line}`, s]));

// ============================================================================
// THE CLASSIFICATION — every census site claimed exactly once, both directions.
// finds are statements, not line numbers, so cosmetic drift does not rot them;
// exact+occ disambiguates byte-identical lines (the sock's grant line is
// identical to the license plate's, nine lines down — line-content-only
// identity was never going to be enough).
// ============================================================================
const REGISTER = 'F-ECON-PAYOUTS';
const A = 'src/dialogue/neighborhood_a.js';
const B = 'src/dialogue/neighborhood_b.js';
const V = 'src/dialogue/vendors_places.js';
const CLASSIFIED = [
  // ---- pawn shop pete (A) ----
  { file: A, find: 'P.copper--; P.cash += pay', kind: 'trade', note: 'pete buys copper' },
  { file: A, find: 'P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;', exact: true, occ: 0, kind: 'violation', finding: 'F-SOCK', note: "'pawn a sock. $1.' — no guard, no decrement, no sock anywhere in the inventory system; $200/day from nothing under PETE_CAP" },
  { file: A, find: 'P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;', exact: true, occ: 1, kind: 'trade', note: 'pete buys the license plate' },
  { file: A, find: 'P.cash += pay;', exact: true, kind: 'trade', note: 'pete buys junk, 1:1 with what he paid for' },
  { file: A, find: "P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});", exact: true, kind: 'trade', note: 'pete sells food for $3' },
  { file: A, find: 'P.cash += 50; state.flags.scrapLoanDay', kind: 'ledger', cite: REGISTER, note: "pete's $50 loan — scrap-loved, daily" },
  // ---- tony, yuri (A) ----
  { file: A, find: 'P.cash -= rockPrice; P.rocks++', kind: 'trade', note: 'tony sells a rock' },
  { file: A, find: 'P.copper--; P.cash += yuriRate', kind: 'trade', note: 'yuri buys copper, single' },
  { file: A, find: 'const sold = P.copper; const got = sold * yuriRate; P.cash += got;', kind: 'trade', note: 'yuri buys copper, bulk (P.copper = 0 lands on the next line, same action)' },
  // ---- people (A) ----
  { file: A, find: 'P.inventory.push({id:\'crossword\', n:"barb\'s saturday crossword", q:1});', exact: true, occ: 0, kind: 'ledger', cite: REGISTER, note: 'dave waives the ransom at cred>=3 — social precondition' },
  { file: A, find: 'P.inventory.push({id:\'crossword\', n:"barb\'s saturday crossword", q:1});', exact: true, occ: 1, kind: 'trade', note: "dave's $20 crossword ransom" },
  { file: A, find: "P.cash += 8; toast('+ $8", kind: 'ledger', cite: REGISTER, note: "dave's wallet — petty crime, 30% wake risk" },
  { file: A, find: 'P.cash += 10; state.counters.kombuchaAskDay', kind: 'ledger', cite: REGISTER, note: "mom's $10 pity — daily" },
  { file: A, find: 'P.cash += 20; toast(', kind: 'ledger', cite: REGISTER, note: "mom's $20 ask — 40%, daily" },
  { file: A, find: 'P.cash += 2; toast(line', kind: 'ledger', cite: REGISTER, note: "the possum's $2 — a prophecy side effect" },
  { file: A, find: 'P.cash += 22; state.counters.plateStolen++', kind: 'ledger', cite: REGISTER, note: 'the collection plate — 45% smite' },
  // ---- neighborhood b ----
  { file: B, find: 'P.copper -= 3; P.cash += 90', kind: 'trade', note: 'the conductor buys 3 copper' },
  { file: B, find: "P.inventory.push({id:'soap',n:'a small bar of soap',q:1});", exact: true, occ: 0, kind: 'trade', rng: true, note: "stripe's rock is soap 40% of the time — cash was staked" },
  { file: B, find: "P.rocks++; toast(`- $${buyP}", kind: 'trade', rng: true, note: "stripe sells a rock, 60% branch" },
  { file: B, find: 'P.rocks--; P.cash += px', kind: 'trade', note: 'stripe fences one rock' },
  { file: B, find: 'P.cash += totalCash', kind: 'trade', note: 'stripe fences bulk' },
  { file: B, find: "P.inventory.push({id:'stripe_package'", kind: 'ledger', cite: REGISTER, note: "stripe's package — a quest prop, not currency; opening it is judged as a trade" },
  { file: B, find: 'P.rocks += 5', kind: 'trade', rng: true, note: 'the package holds five rocks (35%) — the package was consumed' },
  { file: B, find: "P.inventory.push({id:'soap',n:'a small bar of soap',q:1});", exact: true, occ: 1, kind: 'trade', rng: true, note: 'the package holds soap (30%), bar one' },
  { file: B, find: "P.inventory.push({id:'soap',n:'a small bar of soap',q:1});", exact: true, occ: 2, kind: 'trade', rng: true, note: 'the package holds soap (30%), bar two' },
  // ---- vendors & places ----
  { file: V, find: "P.inventory.push({ id:'bus_pass'", kind: 'ledger', cite: REGISTER, note: 'giveBusPass — one site, two callers: pinky sells it ($20, conserving), mom gifts it at dawn; site granularity cannot split callers' },
  { file: V, find: 'P.cash -= singlePrice; P.supplies', kind: 'trade', note: 'barb sells 1 packet' },
  { file: V, find: 'P.cash -= bulkPrice; P.supplies', kind: 'trade', note: 'barb sells 5 packets' },
  { file: V, find: 'P.supplies = (P.supplies||0) + 1;', exact: true, occ: 0, kind: 'trade', note: "barb's free packet for the returned crossword — the crossword is consumed" },
  { file: V, find: 'P.supplies = (P.supplies||0) + 1;', exact: true, occ: 1, kind: 'trade', note: 'pinky sells 1 house-cut packet' },
  { file: V, find: 'P.dirtySupplies = (P.dirtySupplies||0) + 1', kind: 'trade', note: 'pinky single: the house-cut shadow lane' },
  { file: V, find: 'P.supplies = (P.supplies||0) + 5;', exact: true, kind: 'trade', note: 'pinky sells 5 packets bulk' },
  { file: V, find: 'P.dirtySupplies = (P.dirtySupplies||0) + 5', kind: 'trade', note: 'pinky bulk: the house-cut shadow lane' },
  { file: V, find: 'P.copper += 2', kind: 'ledger', cite: REGISTER, note: 'the old-school copper rip — BRUTUS is the cost' },
  { file: V, find: 'P.cash += 200', kind: 'trade', rng: true, note: 'the price guy returns $200 (15%) — all cash was staked first' },
  { file: V, find: 'P.rocks++;', exact: true, kind: 'trade', rng: true, note: 'the price guy hands over a rock (25%)' },
  // ---- activities ----
  { file: 'src/minigames/activities.js', find: 'P.copper += got', kind: 'ledger', cite: REGISTER, note: 'heist pipes — daily-capped loot verb' },
  { file: 'src/minigames/activities.js', find: 'P.cash += pay; P.cred += Math.floor(hits/2)', kind: 'ledger', cite: REGISTER, note: 'karaoke pays per hit — the $5 stake is a separate action' },
  { file: 'src/minigames/activities.js', find: 'P.cash += got; audio.coin();', kind: 'ledger', cite: REGISTER, note: 'panhandling: ask for change' },
  { file: 'src/minigames/activities.js', find: 'P.cash++', kind: 'ledger', cite: REGISTER, note: 'panhandling: the single dollar with eye contact' },
  { file: 'src/minigames/activities.js', find: 'P.cash += 3; toast(', kind: 'ledger', cite: REGISTER, note: 'panhandling: the hummed song' },
  { file: 'src/minigames/activities.js', find: 'P.cash += 8; P.cred++', kind: 'ledger', cite: REGISTER, note: 'panhandling: the card trick' },
  { file: 'src/minigames/activities.js', find: 'P.cash += 500', kind: 'trade', rng: true, note: 'the lottery jackpot (1%) — the ticket is consumed either way' },
  { file: 'src/minigames/activities.js', find: 'P.cash += win', kind: 'trade', rng: true, note: 'the lottery small win (14%)' },
  // ---- interactions (world verbs) ----
  { file: 'src/systems/interactions.js', find: 'P.cash += 8 + Math.floor(Math.random()*7)', kind: 'ledger', cite: REGISTER, note: 'the dumpster tips jar' },
  { file: 'src/systems/interactions.js', find: "P.cash += v; toast('+ $'+v", kind: 'ledger', cite: REGISTER, note: 'dumpster: sellable find' },
  { file: 'src/systems/interactions.js', find: 'P.cash += it.val', kind: 'ledger', cite: REGISTER, note: 'dumpster: found cash' },
  { file: 'src/systems/interactions.js', find: 'P.inventory.push({id: it.id||', kind: 'ledger', cite: REGISTER, note: 'dumpster: found item' },
  { file: 'src/systems/interactions.js', find: "P.inventory.push({id:'junk', n:'a piece of junk', q:1});", exact: true, occ: 0, kind: 'ledger', cite: REGISTER, note: 'dumpster: junk drop' },
  { file: 'src/systems/interactions.js', find: 'P.supplies = (P.supplies||0) + 1', kind: 'ledger', cite: REGISTER, note: 'dumpster: the clean packet' },
  { file: 'src/systems/interactions.js', find: 'P.cash += amt', kind: 'ledger', cite: REGISTER, note: 'kicked trash can: coins (50%)' },
  { file: 'src/systems/interactions.js', find: "P.inventory.push({id:'junk', n:'a piece of junk', q:1});", exact: true, occ: 1, kind: 'ledger', cite: REGISTER, note: 'kicked trash can: junk (20%)' },
  { file: 'src/systems/interactions.js', find: "P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});", kind: 'ledger', cite: REGISTER, note: 'kicked trash can: food (10%)' },
  // ---- update (world pickups + quest delivery) ----
  { file: 'src/core/update.js', find: 'P.cash += c.amt', kind: 'ledger', cite: REGISTER, note: 'authored cash piles + boss drops — the pile leaves the world' },
  { file: 'src/core/update.js', find: 'P.cash += 40; P.cred += 3', kind: 'ledger', cite: REGISTER, note: "stripe's package delivered — quest reward" },
  // ---- campaigns / routes (wages and rewards) ----
  { file: 'src/systems/campaigns.js', find: 'P.cash+=pay', kind: 'ledger', cite: REGISTER, note: 'office work order wage' },
  { file: 'src/systems/campaigns.js', find: 'P.cash+=emperor', kind: 'ledger', cite: REGISTER, note: 'kingdom boss reward' },
  { file: 'src/systems/campaigns.js', find: 'P.cash+=10', kind: 'ledger', cite: REGISTER, note: 'pretender put down — reward' },
  { file: 'src/systems/progression_routes.js', find: 'if (r.cash) P.cash += r.cash', kind: 'ledger', cite: REGISTER, note: 'route stop cash' },
  { file: 'src/systems/progression_routes.js', find: 'P.cash+=cash; P.cred+=cred', kind: 'ledger', cite: REGISTER, note: 'route completion payout' },
  // ---- combat drops ----
  { file: 'src/systems/combat.js', find: 'P.copper += 5', kind: 'ledger', cite: REGISTER, note: "OS Brutus's copper — he was sitting on it" },
  { file: 'src/systems/combat.js', find: 'P.inventory.push({id:\'crossword\'', kind: 'ledger', cite: REGISTER, note: 'dave drops the crossword when beaten' },
  { file: 'src/systems/combat.js', find: 'P.cash += 2 + Math.floor(Math.random()*5)', kind: 'ledger', cite: REGISTER, note: 'kill pocket-change (50%)' },
  // ---- communications (ambient events + calls) ----
  { file: 'src/systems/communications.js', find: "from:'A WRONG NUMBER'", kind: 'ledger', cite: REGISTER, note: 'dolores tips $3' },
  { file: 'src/systems/communications.js', find: "id:'doordash'", kind: 'ledger', cite: REGISTER, note: 'the doordash bag' },
  { file: 'src/systems/communications.js', find: "id:'forget_year'", kind: 'ledger', cite: REGISTER, note: 'the traffic cone' },
  { file: 'src/systems/communications.js', find: "id:'pigeon_change'", kind: 'ledger', cite: REGISTER, note: 'the pigeon pays $4.20' },
  { file: 'src/systems/communications.js', find: "id:'guy_running'", kind: 'ledger', cite: REGISTER, note: 'the sorry man drops $3' },
  { file: 'src/systems/communications.js', find: "id:'wedding_guy'", kind: 'ledger', cite: REGISTER, note: 'the tuxedo man drops $5' },
  { file: 'src/systems/communications.js', find: "id:'free_money'", kind: 'ledger', cite: REGISTER, note: '$20 from nowhere' },
  { file: 'src/systems/communications.js', find: "id:'pizza_box'", kind: 'ledger', cite: REGISTER, note: 'the gold tooth' },
  // ---- npc spawn-table vendors ----
  { file: 'src/data/npc_spawns.js', find: "P.cash++; toast('+ $1", kind: 'ledger', cite: REGISTER, note: "the jogger's dollar (40%) — panhandling family; found by this gate's census on its first run" },
  { file: 'src/data/npc_spawns.js', find: "P.inventory.push({id:'detergent'", kind: 'trade', note: 'the laundromat lady sells detergent' },
  { file: 'src/data/npc_spawns.js', find: 'P.cash -= 15; P.rocks++', kind: 'trade', note: "the food truck's special burrito" },
  { file: 'src/data/npc_spawns.js', find: 'if (Math.random() < 0.5) { P.rocks++', kind: 'trade', rng: true, note: "the priest's son's real tic-tac — $10 staked, 50% rug" },
  // ---- the hideout chest (transfers, not payouts) ----
  { file: 'src/systems/daily_hideouts.js', find: 's.rocks--; P.rocks++', kind: 'trade', note: 'chest: withdraw a rock — the stash is the consumption' },
  { file: 'src/systems/daily_hideouts.js', find: 's.copper--; P.copper++', kind: 'trade', note: 'chest: withdraw copper' },
  { file: 'src/systems/daily_hideouts.js', find: 's.cash -= 10; P.cash += 10', kind: 'trade', note: 'chest: withdraw $10' },
  // ---- the cook (supplies -> rocks, same function, same action) ----
  { file: 'src/minigames/heat.js', find: 'P.soapRocks = (P.soapRocks||0) + rocks', kind: 'trade', rng: true, note: 'a soap-rock batch — the packets are consumed two lines up' },
  { file: 'src/minigames/heat.js', find: 'P.rocks += rocks', kind: 'trade', rng: true, note: 'the cook — packets consumed in the same apply' },
  { file: 'src/minigames/heat.js', find: "a small bar of soap (oops)", kind: 'trade', rng: true, note: 'the oops bar — a cook byproduct' },
];

// ---- resolve entries -> census sites, both directions -----------------------
const findingsText = fs.readFileSync(path.join(ROOT, 'REFACTOR-FINDINGS.md'), 'utf8');
const claimedBy = new Map(); // censusSite -> entry
for (const entry of CLASSIFIED) {
  const matches = census
    .filter(s => s.file === entry.file && (entry.exact ? s.norm === entry.find : s.norm.includes(entry.find)))
    .sort((a, b) => a.line - b.line);
  const site = matches[entry.occ || 0];
  if (!site) {
    fail(`CLASSIFICATION: entry "${entry.note}" (${entry.file} ~ "${entry.find}") matches no census site — stale entry; the code moved and the map did not (I-EVERY-DOLLAR-NAMED)`);
    continue;
  }
  if (claimedBy.has(site)) {
    fail(`CLASSIFICATION: ${site.file}:${site.line} is claimed twice — "${claimedBy.get(site).note}" and "${entry.note}" (I-EVERY-DOLLAR-NAMED)`);
    continue;
  }
  claimedBy.set(site, entry);
  entry.site = site;
  const token = entry.kind === 'ledger' ? entry.cite : entry.kind === 'violation' ? entry.finding : null;
  if (token && !findingsText.includes(token)) {
    fail(`CLASSIFICATION: "${entry.note}" cites ${token}, which appears nowhere in REFACTOR-FINDINGS.md — an unsigned ${entry.kind} cannot compile green (I-SIGNED-LEDGER)`);
  }
}
for (const s of census) {
  if (!claimedBy.has(s)) {
    fail(`CENSUS: unclassified resource grant at ${s.file}:${s.line} — "${s.norm.slice(0, 90)}" (${s.lane}). Every dollar is named: classify it as a trade (and let the audit prove it) or put it on the register and cite it (I-EVERY-DOLLAR-NAMED)`);
  }
}

if (DEBUG_CENSUS) {
  for (const s of census) {
    const e = claimedBy.get(s);
    console.log(`${(e ? e.kind : 'UNCLASSIFIED').padEnd(10)} ${s.file}:${s.line} [${s.lane}] ${s.norm.slice(0, 100)}`);
  }
  console.log(`census: ${census.length} sites, ${CLASSIFIED.length} entries`);
}

// ============================================================================
// HALF 2 — THE BEHAVIORAL AUDIT (judgment; drives the real menus)
// ============================================================================
Error.stackTraceLimit = 40;

const { context, module } = await loadModularGame();
context.window._rb.startGame(false);

const runtimeUi = module('src/core/runtime_ui.js');
const activities = module('src/minigames/activities.js');
const interactions = module('src/systems/interactions.js');
const dailyHideouts = module('src/systems/daily_hideouts.js');
const vendorsPlaces = module('src/dialogue/vendors_places.js');
const neighborhoodA = module('src/dialogue/neighborhood_a.js');
const heat = module('src/minigames/heat.js');

const { P, state, runtime } = runtimeUi;

// ---- lane instrumentation ---------------------------------------------------
let rec = null; // active recording: {grants:[{lane,amt,site}], consumed:bool}
function captureSite() {
  const stack = String(new Error().stack);
  for (const ln of stack.split('\n')) {
    if (ln.includes('economy-gate.mjs')) continue;
    const m = ln.match(/((?:[A-Za-z]:)?[^():\s][^():]*?src[\\/][^():]*?\.js):(\d+):\d+/);
    if (m) return { file: path.relative(ROOT, m[1]).replace(/\\/g, '/'), line: +m[2] };
  }
  return null;
}
const laneBacking = {};
for (const lane of LANES) {
  laneBacking[lane] = P[lane] || 0;
  Object.defineProperty(P, lane, {
    configurable: true, enumerable: true,
    get: () => laneBacking[lane],
    set: v => {
      const old = laneBacking[lane];
      laneBacking[lane] = v;
      if (rec && typeof v === 'number' && typeof old === 'number') {
        if (v > old) rec.grants.push({ lane, amt: v - old, site: captureSite() });
        else if (v < old) rec.consumed = true;
      }
    },
  });
}
function wrapInv(arr) {
  if (!Array.isArray(arr)) return arr;
  if (!Object.prototype.hasOwnProperty.call(arr, '__egWrapped')) {
    Object.defineProperty(arr, '__egWrapped', { value: true });
    Object.defineProperty(arr, 'push', {
      configurable: true, writable: true,
      value: function (...items) {
        if (rec && items.length) rec.grants.push({ lane: 'inventory', amt: items.length, site: captureSite() });
        return Array.prototype.push.apply(this, items);
      },
    });
  }
  return arr;
}
let invBacking = wrapInv(P.inventory || []);
Object.defineProperty(P, 'inventory', {
  configurable: true, enumerable: true,
  get: () => invBacking,
  set: v => {
    if (rec && Array.isArray(v) && Array.isArray(invBacking) && v.length < invBacking.length) rec.consumed = true;
    invBacking = wrapInv(v);
  },
});
function makeStash(init) {
  const s = { items: [] };
  const backing = { rocks: init.rocks, copper: init.copper, cash: init.cash };
  for (const k of ['rocks', 'copper', 'cash']) {
    Object.defineProperty(s, k, {
      configurable: true, enumerable: true,
      get: () => backing[k],
      set: v => { if (rec && v < backing[k]) rec.consumed = true; backing[k] = v; },
    });
  }
  return s;
}

// ---- state profiles ----------------------------------------------------------
const pristineCounters = JSON.stringify(state.counters);
const pristineFlags = JSON.stringify(state.flags);
const pristineQuests = JSON.stringify(state.quests);
const npcBaseline = runtime.npcs.map(n => [n, {
  asleep: n.asleep, hostile: n.hostile, aggro: n.aggro, dead: n.dead,
  priceResolved: n.priceResolved, shopClosed: false,
}]);

const BROKE = {
  name: 'BROKE', trials: 6,
  cash: 0, rocks: 0, soapRocks: 0, copper: 0, supplies: 0, dirtySupplies: 0,
  inv: [], stash: { rocks: 0, copper: 0, cash: 0 }, cred: 0,
  faction: { street: 0, scrap: 8, spiritual: 10 },
};
const STOCKED = {
  name: 'STOCKED', trials: 14,
  cash: 500, rocks: 8, soapRocks: 0, copper: 12, supplies: 6, dirtySupplies: 2,
  inv: [
    { id: 'license', n: 'a license plate', q: 1 },
    { id: 'junk', n: 'a piece of junk', q: 1 }, { id: 'junk', n: 'a piece of junk', q: 1 },
    { id: 'junk', n: 'a piece of junk', q: 1 },
    { id: 'lottery', n: 'a lottery ticket (unscratched)', q: 1 },
    { id: 'soap', n: 'a small bar of soap', q: 1 },
    { id: 'food', n: 'a can of food (unmarked)', q: 1 },
  ],
  stash: { rocks: 3, copper: 3, cash: 100 }, cred: 0,
  faction: { street: 0, scrap: 8, spiritual: 10 },
};

function applyProfile(profile, prep) {
  rec = null;
  state.mode = 'playing';
  state.day = 3; state.dayTime = 0.4; state.weather = 'clear';
  state.counters = JSON.parse(pristineCounters);
  state.flags = JSON.parse(pristineFlags);
  state.quests = JSON.parse(pristineQuests);
  state.hideoutStash = makeStash(profile.stash);
  state.heat = null;
  for (const lane of LANES) laneBacking[lane] = profile[lane];
  P.inventory = profile.inv.map(it => ({ ...it }));
  P.cred = profile.cred; P.hp = 80; P.brain = 80; P.shakes = 10; P.wanted = 0;
  P.rockedT = 0; P.crashT = 0;
  P.faction = { ...profile.faction };
  P.tonyOffenses = 0; P.stripeLoyalty = 0;
  for (const [n, snap] of npcBaseline) Object.assign(n, snap);
  if (prep) prep();
  try { runtimeUi.closeDialogue(); } catch { /* nothing open */ }
}

// ---- probes: every way the audit knows to open an economy surface ------------
const probes = [];
for (const [n] of npcBaseline) {
  if (typeof n.interact !== 'function') continue;
  probes.push({ id: `npc:${n.id || n.name}`, open: () => n.interact(n) });
}
probes.push(
  { id: 'npc:dave(asleep)', open: () => { const d = runtime.npcs.find(n => n.id === 'dave'); if (d) { d.asleep = true; d.interact(d); } } },
  { id: 'npc:dave(ransom)', prep: () => {
      state.flags.daveHasCrossword = true; state.flags.hasCrossword = false;
      if (state.quests.barb_crossword) { state.quests.barb_crossword.available = true; state.quests.barb_crossword.done = false; }
    }, open: () => { const d = runtime.npcs.find(n => n.id === 'dave'); if (d) { d.asleep = false; d.interact(d); } } },
  { id: 'npc:barb(return)', prep: () => {
      state.flags.hasCrossword = true; state.flags.daveHasCrossword = false;
      if (state.quests.barb_crossword) { state.quests.barb_crossword.available = true; state.quests.barb_crossword.done = false; }
      P.inventory.push({ id: 'crossword', n: "barb's saturday crossword", q: 1 });
    }, open: () => vendorsPlaces.barbDialogue() },
  { id: 'zone:block', prep: () => {
      state.flags.hasStripePackage = true;
      P.inventory.push({ id: 'stripe_package', n: "stripe's sealed package", q: 1 });
    }, open: () => activities.blockMenu() },
  { id: 'zone:market', open: () => activities.panhandle() },
  { id: 'place:chest', open: () => dailyHideouts.openHideoutChest('shed') },
  { id: 'place:dumpster', open: () => interactions.startDumpsterDive({ x: 5200, y: 4200, w: 40, h: 30 }) },
  { id: 'place:oldschool', prep: () => { state.flags.osBrutusKilled = true; P.rank = 5; }, open: () => vendorsPlaces.openOldSchoolInterior() },
  { id: 'npc:price_guy', open: () => vendorsPlaces.priceGuyDialogue({ id: 'price_guy_probe' }) },
  { id: 'npc:possum', open: () => { neighborhoodA.possumDialogue(); } },
  { id: 'minigame:heist', open: () => { activities.heistStage(2); } },
);

// ---- the drive ---------------------------------------------------------------
const MAX_DEPTH = 3;
const drain = () => new Promise(r => setTimeout(r, 0)) && Promise.resolve();
const activeMenu = () => runtimeUi.activeDialogue;
const sig = m => `${m.name}|${(m.opts || []).map(o => o.label).join('|')}`;

const observedConserving = new Set(); // classification entries seen granting WITH consumption
const violationEvidence = new Map();  // entry -> [evidence lines]
const freeMintFailures = new Map();   // site key -> message
let optionRuns = 0, menusSeen = 0;

async function settle(p) {
  if (p && typeof p.then === 'function') await Promise.race([p, Promise.resolve()]);
  await Promise.resolve(); await Promise.resolve();
}

async function openPath(probe, profile, pathIdx) {
  applyProfile(profile, probe.prep);
  try { await settle(probe.open()); } catch { return null; }
  for (const i of pathIdx) {
    const menu = activeMenu();
    if (!menu || !menu.opts || !menu.opts[i] || menu.opts[i].disabled) return null;
    const o = menu.opts[i];
    try { runtimeUi.closeDialogue(); } catch { /* keep going */ }
    try { await settle(o.action && o.action()); } catch { return null; }
  }
  return activeMenu();
}

function analyzeRun(probe, profile, label, run) {
  for (const g of run.grants) {
    const site = g.site && censusByFileLine.get(`${g.site.file}#${g.site.line}`);
    if (!site) {
      const where = g.site ? `${g.site.file}:${g.site.line}` : '(unattributed frame)';
      fail(`AUDIT: observed a ${g.lane} grant (+${g.amt}) at ${where}, which is not in the static census — the census patterns have a gap and the map is not the territory (I-EVERY-DOLLAR-NAMED) [${probe.id} · "${label}" · ${profile.name}]`);
      continue;
    }
    const entry = claimedBy.get(site);
    if (!entry) continue; // already failed as unclassified
    if (entry.kind === 'violation') {
      const list = violationEvidence.get(entry) || [];
      if (list.length < 4) list.push(`${profile.name}: "${label}" paid +${g.amt} ${g.lane}${run.consumed ? '' : ', nothing consumed'}${profile.name === 'BROKE' ? ', inventory empty, pockets empty' : ''}`);
      violationEvidence.set(entry, list);
      continue;
    }
    if (entry.kind === 'ledger') continue; // licensed free payout
    // trade: must conserve in this very action
    if (run.consumed) { observedConserving.add(entry); continue; }
    freeMintFailures.set(`${site.file}:${site.line}`,
      `TRADE: ${site.file}:${site.line} ("${entry.note}") granted +${g.amt} ${g.lane} with NOTHING consumed [${probe.id} · "${label}" · ${profile.name}]. ` +
      `A trade that pays without consuming is the sock's family — its guard or its decrement is gone (I-TRADE-CONSERVES / I-TRADE-GUARDED)`);
  }
  const negatives = LANES.filter(l => laneBacking[l] < 0).map(l => `${l}=${laneBacking[l]}`);
  if (negatives.length) {
    fail(`AUDIT: "${label}" [${probe.id} · ${profile.name}] left a resource lane below zero (${negatives.join(', ')}) — a purchase its guard did not fund (I-TRADE-GUARDED)`);
    for (const l of LANES) if (laneBacking[l] < 0) laneBacking[l] = 0;
  }
}

for (const profile of [BROKE, STOCKED]) {
  for (const probe of probes) {
    const root = await openPath(probe, profile, []);
    if (!root || !root.opts) { try { runtimeUi.closeDialogue(); } catch {} continue; }
    const seenSigs = new Set([sig(root)]);
    const queue = [[]];
    while (queue.length) {
      const pathIdx = queue.shift();
      const menu = await openPath(probe, profile, pathIdx);
      if (!menu || !menu.opts) continue;
      menusSeen++;
      const optCount = menu.opts.length;
      for (let i = 0; i < optCount; i++) {
        for (let t = 0; t < profile.trials; t++) {
          const m = await openPath(probe, profile, pathIdx);
          if (!m || !m.opts || !m.opts[i]) break;
          const o = m.opts[i];
          if (o.disabled) { try { runtimeUi.closeDialogue(); } catch {} break; }
          try { runtimeUi.closeDialogue(); } catch { /* keep going */ }
          rec = { grants: [], consumed: false };
          let threw = false;
          try { await settle(o.action && o.action()); } catch { threw = true; }
          const run = rec; rec = null;
          optionRuns++;
          if (!threw) analyzeRun(probe, profile, o.label, run);
          if (t === 0 && pathIdx.length < MAX_DEPTH) {
            const after = activeMenu();
            if (after && after !== m && after.opts && !seenSigs.has(sig(after))) {
              seenSigs.add(sig(after));
              queue.push([...pathIdx, i]);
            }
          }
          try { runtimeUi.closeDialogue(); } catch { /* nothing open */ }
        }
      }
    }
  }
}

// direct transactional probes: the cook pays inside one function call, with the
// outcome as a parameter — force each branch instead of praying at the dice
for (const [args, what] of [
  [[5, 'slow', 'ok'], 'cook: ok batch'],
  [[5, 'slow', 'perfect'], 'cook: perfect batch'],
  [[5, 'slow', 'soaprock'], 'cook: soap-rock batch'],
]) {
  applyProfile(STOCKED);
  rec = { grants: [], consumed: false };
  try { heat.applyCookOutcome(...args); } catch { /* recorded below as coverage */ }
  const run = rec; rec = null;
  analyzeRun({ id: 'direct:cook' }, STOCKED, what, run);
}

// coverage: a deterministic trade the audit never exercised is an unverified one
for (const entry of CLASSIFIED) {
  if (entry.kind !== 'trade' || entry.rng || !entry.site) continue;
  if (!observedConserving.has(entry)) {
    fail(`COVERAGE: trade site ${entry.site.file}:${entry.site.line} ("${entry.note}") was never observed conserving by the audit driver — extend the driver or justify the gap; an unexercised trade is an unverified trade (I-TRADE-CONSERVES)`);
  }
}
for (const [, msg] of freeMintFailures) fail(msg);

// standing violations: red by name, with live evidence, until the operator rules
for (const entry of CLASSIFIED) {
  if (entry.kind !== 'violation') continue;
  const ev = violationEvidence.get(entry);
  const evidence = ev && ev.length
    ? ev.join(' · ')
    : 'NOT observed live this run — if the site is gone, the operator ruled; retire this entry with the finding';
  fail(`STANDING VIOLATION ${entry.finding}: ${entry.site ? `${entry.site.file}:${entry.site.line}` : entry.file} — ${entry.note}. LIVE: ${evidence}. ` +
    `This is a finding, not a knob: do not guard it, do not ledger it, do not delete this entry to go green — the sock is the operator's taste call (I-STANDING-RED, I-NO-FIX)`);
}

if (DEBUG_OBSERVE) {
  console.log(`observed conserving: ${[...observedConserving].map(e => e.note).join(' | ')}`);
}

// ============================================================================
const trades = CLASSIFIED.filter(e => e.kind === 'trade').length;
const ledgered = CLASSIFIED.filter(e => e.kind === 'ledger').length;
const violations = CLASSIFIED.filter(e => e.kind === 'violation').length;
const summary = `${census.length} grant sites (${trades} trades, ${ledgered} ledgered payouts, ${violations} standing violation${violations === 1 ? '' : 's'}) · ${menusSeen} menus walked · ${optionRuns} option runs · ${observedConserving.size} trades observed conserving`;

if (failures.length) {
  console.error(`ECONOMY GATE: ${failures.length} failure(s) · ${summary}`);
  failures.forEach(f => console.error(`- ${f}`));
  process.exit(1);
}
console.log(`ECONOMY GATE: PASS (${summary})`);
