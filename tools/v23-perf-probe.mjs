// v23 perf probe: headless drawAll wall-time over the stub canvas. Measures JS/logic
// overhead of the new passes (grime loop, dither, steam, arc, vignette draw call) —
// an upper bound on logic cost, not paint cost. The real-browser eye gate remains the
// operator's, per SPEC-v23-grime-cinema.md.
import { loadModularGame } from './runtime-harness.mjs';

const runtime = await loadModularGame();
const core = runtime.module('src/core/runtime_ui.js');
const frame = runtime.module('src/render/frame.js');
const landmarks = runtime.module('src/render/landmarks_a.js');

// night + rain + a crowd, worst-ish case for overlay work
core.state.dayTime = 0.05;
core.state.weather = 'rain';
core.state.mode = 'playing';
core.P.x = 1250; core.P.y = 850;
for (let i = 0; i < 60; i++) {
  core.runtime.npcs.push({ id: 'perf_cop_' + i, isCop: true, sprite: 'cop', name: 'COP ' + i,
    x: 900 + (i % 10) * 40, y: 700 + Math.floor(i / 10) * 40, w: 18, h: 22, hp: 10, maxHp: 10, dead: false });
}
landmarks.prepareLightingFrame(0, 0);

// warm-up
for (let i = 0; i < 30; i++) frame.drawAll();
const t0 = process.hrtime.bigint();
const FRAMES = 300;
for (let i = 0; i < FRAMES; i++) frame.drawAll();
const t1 = process.hrtime.bigint();
const perFrameMs = Number(t1 - t0) / 1e6 / FRAMES;
console.log(`v23 headless drawAll: ${perFrameMs.toFixed(3)} ms/frame over ${FRAMES} frames (60 cop fixture, night+rain) — ${perFrameMs < 16 ? 'UNDER' : 'OVER'} the 16ms budget`);
