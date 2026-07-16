// WORLD RELATIONSHIPS — the gate that governs the map (v20 landing 4).
// SPEC-v20-world-relationships.md · SPEC-V20-PACKET §3 (Wave-4 budgets).
//
// This gate is a ruler, not a fix. It computes RUNWAY and COVERAGE from the live
// tables and fails on regression. It changes nothing (I-NO-BALANCE-CREEP): every
// number below is measured or derived at run time; a failing reading is a finding
// for the operator, never a license to widen the budget until the light turns green.
//
// THE BUDGET, DERIVED (I-MEASURED-NOT-VIBED — measured live each run, sources cited):
//   walk speed        baseSpeed = 2.2 px/16ms      src/core/runtime_ui.js:33, applied
//                     as vx*spd*(dt/16)            src/core/update.js:82
//                     -> measured here by actually walking the player, cross-checked
//                        against P.speed * 1000/16 (the dt/16 frame base is the one
//                        source constant this file must know about)
//   withdrawal        P.shakes += 0.0008 * dt      src/core/update.js:124 (measured live)
//   fresh shakes      shakes: 20                   src/core/runtime_ui.js:355 (read live)
//   shakes cap        clamp(P.shakes, 0, 100)      src/core/update.js:126 (measured live)
//   world             WORLD = { w:8600, h:5600 }   src/data/world.js:15 (read live)
//   runway            (cap - fresh) / rate         = 100s at shipped values
//   I-RUNWAY budget   60% of runway at walk speed  SPEC-v20-world-relationships.md I-RUNWAY
//   I-COVERAGE budget 45% of runway at walk speed  SPEC-v20-world-relationships.md I-COVERAGE
//                     (the SPEC's "~45s walk (~6,190px)" of a 100s runway)
//
// EVERY DISTANCE IN THIS FILE IS STRAIGHT-LINE, WHICH IS A LOWER BOUND. A leg that
// fails here is definitely too long; a leg that passes may still be too long once
// collision detours are paid. The gate never presents these numbers as true path
// length (SPEC edge case: never let a lower bound masquerade as the real number).
//
// WHAT COUNTS AS MANDATORY (the one interpretive call in this file, stated so the
// operator can overrule it by name): a leg is mandatory when the game assigns it as
// the standing BAD IDEA and the player cannot progress that lane without walking it.
//   - intro chain legs (day 1, no choice at all)
//   - office acquisition + claim/work-order legs (each claim, once accepted, pins
//     the strip until finished; any 4 claims are required to reach the kingdom)
//   - the kingdom campaign chain in strip-guided order (required to finish)
//   - route legs: a rolled route is assigned, not chosen — the clipboard does not
//     negotiate. The full stop pool is measured with unlock flags treated as
//     potentially earned, the same load-bearing "potentially" as I-COVERAGE;
//     otherwise the reading would flicker with progression state, and a gate row
//     that can never fire is decoration.
// NOT governed: the bus (optional one-way teleport, never assigned), the public
// phone (optional), hustles (Q-panel, never on the strip), optional wandering.
//
// The leg inventory is read through the REAL objective selectors
// (currentPrimaryObjective / currentOfficeObjective / currentKingdomObjective) by
// driving quest/stage state, so the gate measures what the strip actually points
// at — not a hand-copied table that silently rots.
import { loadModularGame } from './runtime-harness.mjs';

const failures = [];
const fail = m => failures.push(m);
const px = n => `${n.toFixed(1)}px`;
const secs = (n, pxPerSec) => `${(n / pxPerSec).toFixed(1)}s`;

const { context, module } = await loadModularGame();
context.window._rb.startGame(false);
const updateWorld = context.window._rb.updateWorld;

const runtimeUi = module('src/core/runtime_ui.js');
const campaigns = module('src/systems/campaigns.js');
const progression = module('src/systems/progression_routes.js');
const concessions = module('src/systems/concessions.js');
const world = module('src/data/world.js');
const props = module('src/data/props.js');

const { P, state, applyEquipStats } = runtimeUi;
const { currentPrimaryObjective, currentOfficeObjective, currentKingdomObjective,
        CLAIM_SITES, KINGDOM_CLAN_LIST, QUEST_TARGETS } = campaigns;
const { ROUTE_STOPS, ROUTE_STOP_BY_ID, rollBlockRoute } = progression;
const { SMOKE_SPOTS, SMOKE_SPOT_BY_ID, badIdeaSmokeSpot } = concessions;
const { WORLD } = world;

// ---- 0. measure the constants the budget is made of --------------------------
const spawn = { x: P.x + P.w / 2, y: P.y + P.h / 2 };
const freshShakes = P.shakes;
// day-1 quest snapshot BEFORE any state is driven below
const day1QuestTargets = Object.entries(state.quests)
  .filter(([id, q]) => !q.intro && !q.done && q.available !== false && QUEST_TARGETS[id])
  .map(([id]) => ({ name: `quest ${id}`, ...QUEST_TARGETS[id] }));

state.mode = 'playing';

// withdrawal rate: stand still for one measured second (src/core/update.js:124)
const shakes0 = P.shakes;
updateWorld(1000);
const ratePerSec = P.shakes - shakes0;

// walk speed: hold 'd' for one measured second in open ground and read the odometer.
// cross-checked against P.speed * 1000/16 (src/core/runtime_ui.js:33 via update.js:82).
P.cartMounted = false;
applyEquipStats();
const expectedPxPerSec = P.speed * 1000 / 16;
let pxPerSec = 0;
for (const start of [spawn, { x: 2200, y: 2600 }, { x: 4300, y: 4600 }]) {
  P.x = start.x; P.y = start.y;
  const x0 = P.x;
  state.keys.add('d');
  updateWorld(1000);
  state.keys.delete('d');
  const walked = P.x - x0;
  if (walked > 0 && Math.abs(walked - expectedPxPerSec) / expectedPxPerSec < 0.005) { pxPerSec = walked; break; }
}
if (!pxPerSec) fail(`walk-speed measurement failed: no open ground walk matched P.speed*1000/16 = ${expectedPxPerSec.toFixed(2)}px/s — the movement model drifted from update.js:82 and this gate no longer knows the walk speed`);

// shakes cap: overfill and let the clamp answer (src/core/update.js:126)
P.shakes = 1e6;
updateWorld(16);
const shakesCap = P.shakes;
P.shakes = freshShakes; P.hp = P.maxHp;
P.x = spawn.x - P.w / 2; P.y = spawn.y - P.h / 2;

if (!(ratePerSec > 0)) fail(`withdrawal rate measured as ${ratePerSec}/s — nothing is counting down; runway is undefined and every budget below would be fiction`);
if (!(shakesCap > freshShakes)) fail(`shakes cap ${shakesCap} is not above fresh shakes ${freshShakes}; runway is undefined`);
if (failures.length) {
  console.error(`WORLD GATE: ${failures.length} failure(s) before the budget could even be derived`);
  failures.forEach(f => console.error(`- ${f}`));
  process.exit(1);
}

const runwayS = (shakesCap - freshShakes) / ratePerSec;
const runwayPx = runwayS * pxPerSec;
const LEG_RATIO = 0.60;       // I-RUNWAY: 60% of a fresh runway per mandatory leg
const COVERAGE_RATIO = 0.45;  // I-COVERAGE: ~45s of a 100s runway to a potential spot
const legBudgetPx = LEG_RATIO * runwayPx;
const coverageBudgetPx = COVERAGE_RATIO * runwayPx;

// ---- 1. mandatory legs, read through the live objective selectors ------------
const legs = [];
function addLeg(family, name, a, b) {
  legs.push({ family, name, len: Math.hypot(b.x - a.x, b.y - a.y) });
}
function need(objective, what) {
  if (!objective || !Number.isFinite(objective.x) || !Number.isFinite(objective.y)) {
    fail(`objective selector returned nothing for ${what} — the leg inventory is incomplete and this run cannot be trusted`);
    return { x: NaN, y: NaN };
  }
  return objective;
}

// intro chain (day 1): the strip's first three instructions, driven in order
const day1Objectives = [];
const oPile = need(currentPrimaryObjective(), 'intro find-cash');
state.quests.intro_remember.done = true;
const oTony = need(currentPrimaryObjective(), 'intro tony');
state.quests.intro_tony.done = true; P.rocks = 1;
const oCrate = need(currentPrimaryObjective(), 'intro crate');
for (const o of [oPile, oTony, oCrate]) { if (o.kind !== 'intro') fail(`intro objective came back kind=${o.kind} — the intro model changed under this gate`); day1Objectives.push(o); }
addLeg('campaign', 'intro spawn -> find-cash', spawn, oPile);
addLeg('campaign', 'intro find-cash -> tony', oPile, oTony);
addLeg('campaign', 'intro tony -> crate', oTony, oCrate);
P.rocks = 0;

state.flags.introDone = true;

// office acquisition: crate -> the leasing guy in the lot
state.quests.office_space.available = true;
const oLot = need(currentOfficeObjective(), 'office leasing guy');
addLeg('campaign', 'crate -> leasing guy (office_space)', oCrate, oLot);

// the office anchor, read from the selector's own file-stage objective
state.office.owned = true;
state.office.upgrades.desk = true;
state.office.claimJob = { id: CLAIM_SITES[0].id, stage: 'file' };
const OFFICE = need(currentOfficeObjective(), 'office file anchor');
addLeg('campaign', 'leasing guy -> office', oLot, OFFICE);

// district claims: office -> survey -> office -> sign (claim), and the work-order
// return sign -> office. Any 4 claims are mandatory to reach the kingdom; each
// claim, once accepted, pins the strip — so every claim's legs are measured.
for (const site of CLAIM_SITES) {
  state.office.claimJob = { id: site.id, stage: 'survey' };
  const oSurvey = need(currentOfficeObjective(), `claim ${site.id} survey`);
  state.office.claimJob = { id: site.id, stage: 'install' };
  const oSign = need(currentOfficeObjective(), `claim ${site.id} sign`);
  addLeg('campaign', `claim ${site.id}: office -> survey`, OFFICE, oSurvey);
  addLeg('campaign', `claim ${site.id}: survey -> office`, oSurvey, OFFICE);
  addLeg('campaign', `claim ${site.id}: office -> sign`, OFFICE, oSign);
  addLeg('campaign', `work ${site.id}: sign -> office`, oSign, OFFICE);
}
state.office.claimJob = null;

// kingdom chain, in strip-guided order (marks index order — campaigns.js picks the
// lowest unserved mark), through every stage to the folding chair
for (const id of CLAIM_SITES.slice(0, 4).map(c => c.id)) state.districtClaims[id] = true;
const k = state.kingdom;
k.stage = 'locked';
const oCorner = need(currentKingdomObjective(), 'kingdom prereq (fallen_king corner)');
addLeg('campaign', 'kingdom prereq: office -> corner', OFFICE, oCorner);
k.stage = 'summons';
state.office.upgrades.radio = true;
const oSummons = need(currentKingdomObjective(), 'kingdom summons');
addLeg('campaign', 'kingdom summons: corner -> office', oCorner, oSummons);
let prev = oSummons, prevName = 'office';
for (const clan of KINGDOM_CLAN_LIST) {
  k.stage = clan.marksStage;
  for (const [marks, idx] of [[0, 0], [1, 1], [3, 2]]) {
    k.marks = marks;
    const o = need(currentKingdomObjective(), `${clan.id} mark ${idx}`);
    addLeg('campaign', `kingdom ${clan.id}: ${prevName} -> mark${idx}`, prev, o);
    prev = o; prevName = `mark${idx}`;
  }
  k.marks = 7;
  const oBanner = need(currentKingdomObjective(), `${clan.id} banner`);
  addLeg('campaign', `kingdom ${clan.id}: ${prevName} -> banner`, prev, oBanner);
  k.stage = clan.bossStage; k.marks = 0;
  const oBoss = need(currentKingdomObjective(), `${clan.id} boss`);
  addLeg('campaign', `kingdom ${clan.id}: banner -> boss`, oBanner, oBoss);
  prev = oBoss; prevName = `${clan.id} boss`;
}
k.stage = 'anoint';
const oAnoint = need(currentKingdomObjective(), 'anoint (the block)');
addLeg('campaign', `kingdom anoint: ${prevName} -> block`, prev, oAnoint);
k.stage = 'emperor_gate';
const oThroneBanner = need(currentKingdomObjective(), 'emperor gate');
addLeg('campaign', 'kingdom emperor: block -> throne banner', oAnoint, oThroneBanner);
k.stage = 'emperor_boss';
const oEmperor = need(currentKingdomObjective(), 'emperor boss');
addLeg('campaign', 'kingdom emperor: banner -> boss', oThroneBanner, oEmperor);
k.stage = 'locked'; k.marks = 0;

// route legs: any ordered pair of pool stops can be consecutive (uniform shuffle,
// progression_routes.js rollBlockRoute; cross-route continuity too — the next
// route starts where the last one ended). Worst leg = max pairwise distance.
// The day-1 and pre-office pools are sampled through the REAL roller so the
// pool predicate (progression_routes.js:118) is exercised, not transcribed.
function samplePool(routesCompleted, rolls = 400) {
  P.lifetime.routesCompleted = routesCompleted;
  state.blockRoute = null;
  const ids = new Set();
  for (let i = 0; i < rolls; i++) {
    state.blockRoute = null;
    const route = rollBlockRoute(true);
    if (route) for (const id of route.stops) ids.add(id);
  }
  state.blockRoute = null;
  return [...ids].map(id => ROUTE_STOP_BY_ID[id]);
}
const day1Pool = samplePool(0);        // first two routes: the original neighborhood
const preOfficePool = samplePool(2);   // third route: full unlocked pool, flags fresh
P.lifetime.routesCompleted = 0;
if (!day1Pool.length) fail('day-1 route pool sampled empty — the roller returned nothing for a fresh save');
function addPoolLegs(family, pool) {
  for (let i = 0; i < pool.length; i++) for (let j = i + 1; j < pool.length; j++) {
    addLeg(family, `route ${pool[i].id} <-> ${pool[j].id}`, pool[i], pool[j]);
  }
}
addPoolLegs('route-mandatory', day1Pool);
addPoolLegs('route-mandatory', preOfficePool);
addPoolLegs('route-full', ROUTE_STOPS); // all flags treated as potentially earned

// ---- 2. the checks ------------------------------------------------------------
const familyResults = new Map();
function checkFamily(family, label) {
  const members = legs.filter(l => l.family === family);
  if (!members.length) { fail(`${label}: no legs measured — the inventory for this family is empty and that is itself a failure`); return; }
  const worst = members.reduce((a, b) => (b.len > a.len ? b : a));
  const offenders = members.filter(l => l.len > legBudgetPx);
  familyResults.set(family, { label, count: members.length, worst, offenders });
  for (const leg of offenders) {
    fail(`${label}: leg "${leg.name}" is ${px(leg.len)} (${secs(leg.len, pxPerSec)}) — budget ${px(legBudgetPx)} (${secs(legBudgetPx, pxPerSec)}), and straight-line is a lower bound, so the true walk is longer (I-RUNWAY)`);
  }
}
checkFamily('campaign', 'RUNWAY-CAMPAIGN');
checkFamily('route-mandatory', 'RUNWAY-ROUTES-MANDATORY');
checkFamily('route-full', 'RUNWAY-ROUTES-FULL');

// I-BLOCK-DAY-1: the Block alone covers every day-1 strip objective inside I-RUNWAY
const block = SMOKE_SPOT_BY_ID.block;
const day1Items = [
  ...day1Objectives.map(o => ({ name: `intro "${o.text}"`, x: o.x, y: o.y })),
  ...day1Pool.map(s => ({ name: `route stop ${s.id}`, x: s.x, y: s.y })),
  ...day1QuestTargets,
];
let day1Worst = { name: '(none)', d: 0 };
for (const item of day1Items) {
  const d = Math.hypot(item.x - block.x, item.y - block.y);
  if (d > day1Worst.d) day1Worst = { name: item.name, d };
  if (d > legBudgetPx) fail(`BLOCK-DAY-1: ${item.name} sits ${px(d)} from the block — budget ${px(legBudgetPx)}; the floor of this game is the Block and one runway (I-BLOCK-DAY-1)`);
}
const day1Loop = badIdeaSmokeSpot(block.x, block.y);
if (day1Loop.id !== 'block') fail(`BLOCK-DAY-1: a fresh save's loop objective points at ${day1Loop.id}, not the block — concessions leaked into day 1`);

// I-COVERAGE: with all four concessions earned, no map point sits farther than the
// coverage budget from a POTENTIALLY legal spot (conditions deliberately ignored —
// coverage must not flicker with a dryer)
const GRID_STEP = 50;
let coverageWorst = { x: 0, y: 0, d: 0, nearest: '' };
for (let gx = 0; gx <= WORLD.w; gx += GRID_STEP) {
  for (let gy = 0; gy <= WORLD.h; gy += GRID_STEP) {
    let best = Infinity, nearest = '';
    for (const spot of SMOKE_SPOTS) {
      const d = Math.hypot(spot.x - gx, spot.y - gy);
      if (d < best) { best = d; nearest = spot.id; }
    }
    if (best > coverageWorst.d) coverageWorst = { x: gx, y: gy, d: best, nearest };
  }
}
if (coverageWorst.d > coverageBudgetPx) {
  fail(`COVERAGE: map point (${coverageWorst.x},${coverageWorst.y}) is ${px(coverageWorst.d)} (${secs(coverageWorst.d, pxPerSec)}) from its nearest potential spot (${coverageWorst.nearest}) — budget ${px(coverageBudgetPx)} (${secs(coverageBudgetPx, pxPerSec)}) (I-COVERAGE)`);
}
if (SMOKE_SPOTS.length !== 5) fail(`COVERAGE: smoke spot table has ${SMOKE_SPOTS.length} entries, expected the Block + four concessions (OD-5 cap)`);

// I-TRANSPORT: the rideable cart stays unique; concessions ARE the fast travel
const rideables = props.PROPS.filter(p => p.type === 'cart');
if (rideables.length !== 1) fail(`TRANSPORT: ${rideables.length} rideable carts in PROPS, expected exactly 1 (I-TRANSPORT — no fast travel in v20)`);

// ---- 3. the reading -----------------------------------------------------------
function report() {
  console.log('WORLD GATE — measured, not vibed. All distances straight-line (lower bounds).');
  if (pxPerSec) {
    console.log(`  walk ${pxPerSec.toFixed(1)}px/s (walked & cross-checked) · withdrawal ${ratePerSec.toFixed(2)}/s · shakes ${freshShakes}->${shakesCap}`);
    console.log(`  runway ${runwayS.toFixed(1)}s = ${px(runwayPx)} · leg budget ${(LEG_RATIO * 100)}% = ${px(legBudgetPx)} · coverage budget ${(COVERAGE_RATIO * 100)}% = ${px(coverageBudgetPx)}`);
    console.log(`  world ${WORLD.w}x${WORLD.h} · diagonal ${px(Math.hypot(WORLD.w, WORLD.h))} = ${secs(Math.hypot(WORLD.w, WORLD.h), pxPerSec)} of a ${runwayS.toFixed(0)}s runway`);
    for (const { label, count, worst, offenders } of familyResults.values()) {
      console.log(`  ${offenders.length ? 'FAIL' : 'ok'} ${label}: ${count} legs, worst "${worst.name}" ${px(worst.len)} (${secs(worst.len, pxPerSec)}) / ${px(legBudgetPx)}${offenders.length ? ` — ${offenders.length} over budget` : ''}`);
    }
    console.log(`  ${day1Worst.d > legBudgetPx ? 'FAIL' : 'ok'} BLOCK-DAY-1: ${day1Items.length} day-1 objectives, farthest "${day1Worst.name}" ${px(day1Worst.d)} / ${px(legBudgetPx)}`);
    console.log(`  ${coverageWorst.d > coverageBudgetPx ? 'FAIL' : 'ok'} COVERAGE: worst point (${coverageWorst.x},${coverageWorst.y}) ${px(coverageWorst.d)} (${secs(coverageWorst.d, pxPerSec)}) from ${coverageWorst.nearest} / ${px(coverageBudgetPx)}`);
    console.log(`  ${rideables.length === 1 ? 'ok' : 'FAIL'} TRANSPORT: ${rideables.length} rideable cart(s)`);
  }
  if (failures.length) {
    console.error(`WORLD GATE: ${failures.length} failure(s)`);
    failures.forEach(f => console.error(`- ${f}`));
    console.error('Do not widen the budget to clear this. The budget is derived from the withdrawal');
    console.error('rate and the walk speed — it is what the game already is. A failing leg is a');
    console.error('finding for the operator (REFACTOR-FINDINGS.md), not a knob.');
    process.exit(1);
  }
  console.log('WORLD GATE: PASS (runway legs within 60% of a fresh runway, block covers day 1, coverage within 45%, one cart)');
  process.exit(0);
}
report();
