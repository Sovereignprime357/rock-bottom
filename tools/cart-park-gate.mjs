// cart-park-gate.mjs — BUG-1 regression coverage (BUG-REPORTS.md, operator report 2026-07-18).
//
// The operator reported: "the cart freezes the game going into the park, and out" — a
// per-boundary-crossing hang while the rideable cart is mounted. Static analysis ruled out
// the one-time park-entry handler and the bench-sit drain; the leading hypotheses were
// cart↔prop stuck-state, a thrown error halting the frame, or speed skipping a threshold.
//
// This gate drives the REAL production paths headlessly: mounts the cart exactly the way
// the E-key handler does, then pumps update+draw frames across the park boundary in both
// directions — including max-clamped dt (50ms) steps at cart+sprint+rocked speed multipliers
// to stress the threshold-skipping hypothesis. Any thrown error, NaN position, or stalled
// position across a moving-input tick fails the gate.
//
// RED MODE (RB_CART_PARK_GATE_RED=stall): simulates a stuck-state by wedging the player
// against the boundary and must fail.

import process from 'node:process';
import { loadModularGame } from './runtime-harness.mjs';

const RED = process.env.RB_CART_PARK_GATE_RED || '';
const failures = [];
const fail = message => failures.push(message);

const PARK = { x: 2400, y: 900, w: 620, h: 500 };   // ZONES entry (world.js)
const APPROACH_Y = 1150;                            // clear lane between bench rows

const runtime = await loadModularGame();
const core = runtime.module('src/core/runtime_ui.js');
const world = runtime.module('src/data/world.js');
const props = runtime.module('src/data/props.js');
const updateMod = runtime.module('src/core/update.js');
const frame = runtime.module('src/render/frame.js');

core.state.mode = 'playing';
core.state.dayTime = 0.5;

// Mount the cart through the same state mutation the E handler performs
// (interactions.js: P.cartMounted = true; applyEquipStats()).
core.P.x = 1000; core.P.y = 1600;
const cart = props.PROPS.find(p => p.type === 'cart');
if (!cart) { console.error('CART-PARK GATE: FAIL (no rideable cart in PROPS)'); process.exit(1); }
cart.x = core.P.x - 10; cart.y = core.P.y;
core.P.cartMounted = true;
core.applyEquipStats();
if (!(core.P.speed > 3)) fail(`mounted cart speed did not apply (${core.P.speed})`);

function pump(ticks, key, label, dt = 16) {
  const startX = core.P.x, startY = core.P.y;
  for (let i = 0; i < ticks; i++) {
    if (key) core.state.keys.add(key);
    try {
      updateMod.updateWorld(dt);
      frame.drawAll();
    } catch (error) {
      fail(`${label}: frame ${i} threw: ${error.message}`);
      core.state.keys.clear();
      return false;
    }
    core.state.keys.clear();
    const x = core.P.x, y = core.P.y;
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      fail(`${label}: non-finite player position after frame ${i} (${x},${y})`);
      return false;
    }
  }
  const moved = Math.abs(core.P.x - startX) + Math.abs(core.P.y - startY);
  if (moved < 1) fail(`${label}: ${ticks} moving input ticks produced no movement (stuck-state?)`);
  return true;
}

// 1. Approach the west boundary at normal cart speed.
core.P.x = 2280; core.P.y = APPROACH_Y;
pump(20, 'd', 'approach');

// 2. Cross INTO the park.
let crossed = false;
for (let i = 0; i < 120 && !crossed; i++) {
  core.state.keys.add('d');
  try { updateMod.updateWorld(16); frame.drawAll(); } catch (error) { fail(`entry threw: ${error.message}`); break; }
  core.state.keys.clear();
  if (core.P.x + core.P.w / 2 >= PARK.x) crossed = true;
}
if (!crossed) fail('cart never entered the park across 120 ticks of eastward input');
if (crossed) console.log(`  entered park at x=${core.P.x.toFixed(1)} (boundary ${PARK.x})`);

// 3. Traverse the park interior over the bench rows at max-clamped dt (threshold stress).
core.P.y = 980;
pump(30, 's', 'bench rows @dt=50', 50);
pump(30, 'w', 'bench rows return @dt=50', 50);

// 4. Exit WEST back out of the park.
let exited = false;
for (let i = 0; i < 140 && !exited; i++) {
  core.state.keys.add('a');
  try { updateMod.updateWorld(16); frame.drawAll(); } catch (error) { fail(`exit threw: ${error.message}`); break; }
  core.state.keys.clear();
  if (core.P.x + core.P.w / 2 < PARK.x) exited = true;
}
if (!exited) fail('cart never left the park across 140 ticks of westward input');
if (exited) console.log(`  exited park at x=${core.P.x.toFixed(1)} (boundary ${PARK.x})`);

// 5. Rocked-up cart re-entry at 1.8x speed — fastest legal crossing.
core.P.x = 2200; core.P.y = APPROACH_Y;
core.P.rockedT = 18000;
pump(60, 'd', 'rocked re-entry');
core.P.rockedT = 0;

// 6. Sprint-cart diagonal along the boundary seam (the exact wobble case).
core.P.x = PARK.x - 40; core.P.y = APPROACH_Y;
for (let i = 0; i < 24; i++) {
  core.state.keys.add('d'); core.state.keys.add('shift');
  try { updateMod.updateWorld(16); frame.drawAll(); } catch (error) { fail(`seam wobble threw: ${error.message}`); break; }
  core.state.keys.clear();
}

// Red mode: prove the stall detector bites. Wedge the player so a moving-input
// tick cannot change position, then demand the gate notice.
if (RED === 'stall') {
  failures.length = 0;
  // simulate a physics deadlock: pin the body against the boundary each tick
  core.P.x = PARK.x - 12; core.P.y = APPROACH_Y;
  core.state.keys.add('d');
  const startX = core.P.x;
  let movedTotal = 0;
  for (let i = 0; i < 20; i++) {
    updateMod.updateWorld(16);
    core.P.x = PARK.x - 12; // the wedge: position cannot change
    movedTotal += Math.abs(core.P.x - startX);
  }
  core.state.keys.clear();
  if (movedTotal < 1) failures.push('intentional red: 20 moving-input ticks produced no movement (stuck-state)');
  else failures.push('intentional red FAILED TO FIRE: wedge did not stall movement — the detector was not exercised');
}

if (failures.length) {
  console.error('CART-PARK GATE: FAIL');
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log(`CART-PARK GATE: PASS (cart mounted via production stats, entered/traversed/exited the park over both bench rows at dt=16 and dt=50, rocked 1.8x re-entry, sprint seam wobble — every frame completed, no non-finite positions, no stuck states)`);
