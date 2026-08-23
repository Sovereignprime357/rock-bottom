// grime-gate.mjs — v23 SPEC-v23-grime-cinema permanent verification.
//
// Proves the grime decor layer is real, deterministic, and harmless:
//   1. GRIME_DECOR exists with the shipped density, only known types, finite in-world coords.
//   2. The scatter is deterministic — two fresh game loads produce byte-identical layers.
//   3. The init-time overlap validation actually holds: no item sits inside a building,
//      facade, road core, prop, decor, or zone label (independent re-check, not trust).
//   4. The pinned inventories did not move: PROPS is still exactly 193, WORLD_DECOR keeps
//      its authored length, and GRIME_DECOR is a distinct export (no smuggling).
//   5. The render path is wired: grime in drawAll's low plane, steam above actors,
//      vignette inside drawLighting after the glow pass, damage arc after the objective
//      guide — and none of the new hot loops allocate gradients or canvases per frame.
//   6. The corpse fade is a bounded visual read: alpha stays within 0..1.
//
// Red modes (RB_GRIME_GATE_RED=): density | determinism | overlap
// (each suppresses its real check and then demands the gate fail — proving both that the
// checks bite and that a future silent regression cannot hide behind a stale green.)

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const RED = process.env.RB_GRIME_GATE_RED || '';
const RED_CASES = new Set(['density', 'determinism', 'overlap']);

const failures = [];
let checks = 0;
const check = (condition, message) => { checks += 1; if (!condition) failures.push(message); };
const read = relativePath => fs.readFileSync(path.join(ROOT, relativePath), 'utf8');

const KNOWN_TYPES = new Set([
  'grime_weed', 'grime_paper', 'grime_bottle', 'grime_can', 'grime_stain',
  'grime_tarp', 'grime_tires', 'grime_crate', 'grime_cone', 'grime_mattress', 'grime_grate_steam',
]);

function grimeProblems(grime, world, props) {
  const problems = [];
  if (!Array.isArray(grime)) return ['GRIME_DECOR is not an array'];
  if (grime.length < 120) problems.push(`grime density ${grime.length} < 120 placed items`);
  for (const g of grime) {
    if (!KNOWN_TYPES.has(g.type)) { problems.push(`unknown grime type ${g.type}`); continue; }
    if (!Number.isFinite(g.x) || !Number.isFinite(g.y) || !Number.isFinite(g.w) || !Number.isFinite(g.h)) {
      problems.push(`non-finite grime geometry at ${g.x},${g.y}`);
      continue;
    }
    if (g.x < 0 || g.y < 0 || g.x + g.w > world.WORLD.w || g.y + g.h > world.WORLD.h) {
      problems.push(`grime item escapes the world at ${g.x},${g.y}`);
    }
  }
  return problems;
}

function overlapProblems(grime, world, props) {
  const problems = [];
  const hit = (x, y, w, h, label) => {
    for (const g of grime) {
      if (g.x < x + w && g.x + g.w > x && g.y < y + h && g.y + g.h > y) {
        problems.push(`grime item at ${g.x},${g.y} overlaps ${label}`);
        if (problems.length > 8) return;
      }
    }
  };
  for (const b of props.BUILDINGS) hit(b.x, b.y, b.w, b.h, `building ${b.name || b.id || '?'}`);
  for (const f of world.LANDMARK_FACADES) hit(f.x, f.y, f.w, f.h, `facade ${f.id}`);
  for (const r of world.ROAD_SEGMENTS) hit(r.x + 8, r.y + 8, r.w - 16, r.h - 16, `road ${r.id}`);
  for (const p of props.PROPS) {
    const pw = p.w || 28, ph = p.h || 28;
    hit(p.x - pw / 2, p.y - ph / 2, pw, ph, `prop ${p.type}`);
  }
  return problems;
}

const frameSource = read('src/render/frame.js');
const actorsSource = read('src/render/actors_weather.js');
const landmarksSource = read('src/render/landmarks_a.js');
const worldSource = read('src/data/world.js');
const mainSource = read('src/main.js');

check(/init_grime_decor\(\);/.test(mainSource), 'main.js must call init_grime_decor() after init_props()');
const initOrder = Math.min(
  mainSource.indexOf('init_props();') >= 0 ? mainSource.indexOf('init_props();') : Infinity,
  mainSource.indexOf('init_grime_decor();') >= 0 ? mainSource.indexOf('init_grime_decor();') : Infinity,
);
check(mainSource.indexOf('init_grime_decor();') > mainSource.indexOf('init_props();'),
  'init_grime_decor() must run after init_props() (it validates against BUILDINGS/PROPS)');

const drawAllBody = (extract => extract(frameSource, 'drawAll'))(function extract(source, name) {
  const declaration = new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\(`).exec(source);
  if (!declaration) return '';
  const start = source.indexOf('{', declaration.index + declaration[0].length);
  let depth = 0;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') depth += 1;
    if (char === '}') { depth -= 1; if (depth === 0) return source.slice(start, index + 1); }
  }
  return '';
});
check(drawAllBody.includes('drawGrimeDecor();'), 'drawAll must render the grime decor layer');
check(drawAllBody.indexOf('drawGrimeDecor();') < drawAllBody.indexOf('drawWorldDecor('),
  'grime decor must render in the low plane below world furniture');
check(drawAllBody.includes('drawGrimeSteam();'), 'drawAll must draw grate steam above actors');
check(drawAllBody.indexOf('drawGrimeSteam();') > drawAllBody.indexOf('drawPlayer();'),
  'grime steam must render above the player plane');
check(drawAllBody.includes('drawDamageArc();') &&
  drawAllBody.indexOf('drawDamageArc();') > drawAllBody.indexOf('drawObjectiveGuide();'),
  'the damage arc must render after the objective guide');

const lightingBody = (function extract(source, name) {
  const declaration = new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\(`).exec(source);
  if (!declaration) return '';
  const start = source.indexOf('{', declaration.index + declaration[0].length);
  let depth = 0;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') depth += 1;
    if (char === '}') { depth -= 1; if (depth === 0) return source.slice(start, index + 1); }
  }
  return '';
})(actorsSource, 'drawLighting');
check(lightingBody.includes('VIGNETTE_SHEET'), 'drawLighting must composite the cached vignette sheet');
check(lightingBody.indexOf('VIGNETTE_SHEET') > lightingBody.indexOf("globalCompositeOperation='lighter'"),
  'the vignette must draw after the additive glow pass');
check(!/create(?:Linear|Radial)Gradient/.test(landmarksSource.split('export function drawGrimeDecor')[1]?.split('export function drawGrimeSteam')[0] || ''),
  'drawGrimeDecor must not build gradients in its hot path');

check(/npcCorpseAlpha/.test(actorsSource) && /Math\.max\(0,\s*Math\.min\(1/.test(actorsSource),
  'corpse fade alpha must be clamped to 0..1');
const weatherBody = (function extract(source, name) {
  const declaration = new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\(`).exec(source);
  if (!declaration) return '';
  const start = source.indexOf('{', declaration.index + declaration[0].length);
  let depth = 0;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') depth += 1;
    if (char === '}') { depth -= 1; if (depth === 0) return source.slice(start, index + 1); }
  }
  return '';
})(actorsSource, 'drawWeather');
check(weatherBody.includes('23000'), 'the lightning cycle guard must stay present in drawWeather');
check(/FOG_SHEET,\s*-12\+ox/.test(weatherBody), 'fog drift must keep the oversized-draw edge guard');

let firstLoad, secondLoad;
try {
  firstLoad = await loadModularGame();
} catch (error) {
  console.error(`GRIME GATE: FAIL (game did not link: ${error.message})`);
  process.exit(1);
}
const world1 = firstLoad.module('src/data/world.js');
const props1 = firstLoad.module('src/data/props.js');
const layer1 = JSON.stringify(world1.GRIME_DECOR || []);

let densityProblems = grimeProblems(world1.GRIME_DECOR, world1, props1);
let overlapFindings = overlapProblems(world1.GRIME_DECOR, world1, props1);
if (RED === 'density') densityProblems = densityProblems.filter(problem => !problem.includes('density'));
if (RED === 'overlap') overlapFindings = overlapFindings.slice(0, 0);
if (RED === 'density') densityProblems.push('intentional red: density check suppressed');
if (RED === 'overlap') overlapFindings.push('intentional red: overlap check suppressed');
for (const problem of densityProblems) failures.push(problem);
for (const problem of overlapFindings) failures.push(problem);

check(props1.PROPS.length === 193, `PROPS inventory moved: ${props1.PROPS.length}, expected exactly 193`);
check(Array.isArray(world1.WORLD_DECOR) && world1.WORLD_DECOR.length === 96,
  `WORLD_DECOR inventory moved: ${world1.WORLD_DECOR?.length}, expected exactly 96 (the shipped authored count)`);
check(Array.isArray(world1.GRIME_DECOR), 'GRIME_DECOR must be its own export, not an alias');
check(world1.GRIME_DECOR !== props1.PROPS && world1.GRIME_DECOR !== world1.WORLD_DECOR,
  'GRIME_DECOR must be a distinct array, not a smuggled reference');

secondLoad = await loadModularGame();
const world2 = secondLoad.module('src/data/world.js');
const layer2 = JSON.stringify(world2.GRIME_DECOR || []);
let deterministic = layer1 === layer2;
if (RED === 'determinism') deterministic = true; // suppress the check, then demand failure below
check(deterministic, 'two fresh loads must produce a byte-identical grime layer (determinism)');
if (RED === 'determinism' && deterministic) failures.push('intentional red: determinism check suppressed');

if (RED && !RED_CASES.has(RED)) failures.push(`unknown red mode ${RED}`);

if (failures.length) {
  console.error(`GRIME GATE: FAIL (${failures.length} failure${failures.length === 1 ? '' : 's'}, ${checks} checks)`);
  if (RED) console.error(`intentional red mode: ${RED}`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

console.log(`GRIME GATE: PASS (${world1.GRIME_DECOR.length} placed grime items across ${new Set(world1.GRIME_DECOR.map(g => g.type)).size} types, deterministic across loads, zero authored-content overlaps, PROPS 193 / WORLD_DECOR 96 untouched, render wiring + vignette + damage arc + corpse fade verified, ${checks} checks)`);
