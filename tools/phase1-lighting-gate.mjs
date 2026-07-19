import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { loadModularGame } from './runtime-harness.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const RED_CASE = process.env.RB_PHASE1_GATE_RED || '';
const RED_CASES = new Set([
  'missing-emitter',
  'forbidden-rgb',
  'missing-grade',
  'grade-alpha',
  'shadow-direction',
  'contact-band',
  'emissive-index',
  'unclassified-prop',
  'render-order',
]);
const REQUIRED_EMITTERS = Object.freeze([
  'streetlamp',
  'barrel_fire',
  'neon_sign',
  'lit_window',
  'pipe_ember',
  'cop_light',
]);

const failures = [];
let checks = 0;

function check(condition, message) {
  checks += 1;
  if (!condition) failures.push(message);
}

function own(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function read(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), 'utf8');
}

function parseRgb(rgb) {
  if (typeof rgb !== 'string') return null;
  const match = rgb.match(/^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$/);
  if (!match) return null;
  const channels = match.slice(1).map(Number);
  return channels.every(channel => channel >= 0 && channel <= 255) ? channels : null;
}

function validateRgb(rgb, label, copOnly = false) {
  const channels = parseRgb(rgb);
  check(Boolean(channels), `${label} must use an r,g,b string with channels from 0 to 255`);
  if (!channels) return;
  const [red, green, blue] = channels;
  check(!(red === 255 && green === 255 && blue === 255), `${label} may not use pure white`);
  const isBrightBlue = blue >= 180 && blue - red >= 50 && blue - green >= 35;
  check(!isBrightBlue || copOnly, `${label} uses bright blue outside a cop light`);
}

function extractFunction(source, name) {
  const declaration = new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\(`).exec(source);
  if (!declaration) return '';
  const start = source.indexOf('{', declaration.index + declaration[0].length);
  if (start < 0) return '';
  let depth = 0;
  let quote = '';
  let escaped = false;
  let lineComment = false;
  let blockComment = false;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (char === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '/' && next === '/') {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === '/' && next === '*') {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === "'" || char === '"' || char === '`') {
      quote = char;
      continue;
    }
    if (char === '{') depth += 1;
    if (char === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  return '';
}

function ordered(source, needles, label) {
  let cursor = -1;
  for (const needle of needles) {
    const found = source.indexOf(needle, cursor + 1);
    if (found < 0) {
      check(false, source.includes(needle)
        ? `${label} must order ${needle} after the preceding render step`
        : `${label} must contain ${needle}`);
      return;
    }
    check(true, `${label} contains ${needle}`);
    check(found > cursor, `${label} must order ${needle} after the preceding render step`);
    cursor = found;
  }
}

function moduleNamespace(runtime, relativePath) {
  return runtime.module(relativePath.replaceAll('\\', '/'));
}

function omitGrade(grades, omittedId) {
  return Object.freeze(Object.fromEntries(Object.entries(grades).filter(([id]) => id !== omittedId)));
}

function validateGrades(grades, zones, terrainRegions) {
  const required = ['default', ...zones.map(zone => zone.id), ...terrainRegions.map(region => region.id)];
  for (const id of required) {
    check(own(grades, id), `ambient grade registry is missing ${id}`);
    const grade = grades[id];
    if (!grade) continue;
    validateRgb(grade.multiply, `ambient grade ${id}.multiply`);
    validateRgb(grade.overlay, `ambient grade ${id}.overlay`);
    check(Number.isFinite(grade.multiplyAlpha) && grade.multiplyAlpha >= 0.04 && grade.multiplyAlpha <= 0.18,
      `ambient grade ${id}.multiplyAlpha must stay within 0.04-0.18`);
    check(Number.isFinite(grade.overlayAlpha) && grade.overlayAlpha >= 0 && grade.overlayAlpha <= 0.08,
      `ambient grade ${id}.overlayAlpha must stay within 0-0.08`);
    check(Object.isFrozen(grade), `ambient grade ${id} must be frozen`);
  }
  check(Object.isFrozen(grades), 'ambient grade registry must be frozen');
}

function validateEmitters(activeLights, glowCache, diegeticRgb) {
  const kinds = new Set(activeLights.map(light => light.kind));
  for (const kind of REQUIRED_EMITTERS) {
    check(kinds.has(kind), `active light registry is missing required emitter kind ${kind}`);
  }
  for (const [name, rgb] of Object.entries(diegeticRgb)) {
    validateRgb(rgb, `DIEGETIC_LIGHT_RGB.${name}`, name === 'cop');
    check(Boolean(glowCache[rgb]), `LIGHT_GLOW_CACHE is missing DIEGETIC_LIGHT_RGB.${name} (${rgb})`);
  }
  for (const [index, light] of activeLights.entries()) {
    const label = `active light ${index} (${light.kind || 'unknown'})`;
    validateRgb(light.rgb, `${label}.rgb`, light.kind === 'cop_light');
    check(typeof light.kind === 'string' && light.kind.length > 0, `${label} must declare kind`);
    check(Number.isFinite(light.x) && Number.isFinite(light.y), `${label} must have finite coordinates`);
    check(Number.isFinite(light.radius) && light.radius > 0, `${label} must have positive radius`);
    check(Number.isFinite(light.power) && light.power > 0 && light.power <= 1.25,
      `${label} must have bounded positive power`);
    check(Number.isFinite(light.level) && light.level >= 0 && light.level <= 1, `${label} must have level from 0 to 1`);
    check(Boolean(glowCache[light.rgb]), `${label} rgb ${light.rgb} is absent from LIGHT_GLOW_CACHE`);
  }
}

function validateShadowDirection(samples) {
  for (const [index, sample] of samples.entries()) {
    const towardX = sample.lightX - sample.subjectX;
    const towardY = sample.lightY - sample.subjectY;
    const dot = sample.offsetX * towardX + sample.offsetY * towardY;
    check(dot < 0, `contact shadow sample ${index} must offset opposite its nearest light`);
    check(Math.hypot(sample.offsetX, sample.offsetY) >= 1 && Math.hypot(sample.offsetX, sample.offsetY) <= 4.01,
      `contact shadow sample ${index} offset must remain within 1-4px`);
  }
}

function validateContactBand(sample) {
  check(sample.composite === 'multiply', 'contact band must use multiply compositing');
  check(sample.alpha >= 0.30 && sample.alpha <= 0.40, 'contact band alpha must remain within 30-40%');
  check(sample.height >= 1 && sample.height <= 2, 'contact band must be 1-2px tall');
}

function validateEmissives(indices, allowlist, spriteKeyBases, emissiveCache) {
  check(JSON.stringify(indices) === JSON.stringify([2, 7]), 'emissive palette indices must be exactly [2,7]');
  check(Object.isFrozen(indices), 'emissive palette index reservation must be frozen');
  const expectedAllowlist = {
    gear_propane_torch: [2, 7],
    weapon_pipe: [2],
  };
  check(JSON.stringify(allowlist) === JSON.stringify(expectedAllowlist),
    'emissive sprite allowlist must be exactly gear_propane_torch:[2,7] and weapon_pipe:[2]');
  check(Object.isFrozen(allowlist), 'emissive sprite allowlist must be frozen');
  for (const [base, reserved] of Object.entries(allowlist)) {
    check(Object.isFrozen(reserved), `emissive allowlist entry ${base} must be frozen`);
    check(reserved.every(index => indices.includes(index)), `${base} uses an unreserved emissive palette index`);
  }

  const expectedKeys = Object.entries(spriteKeyBases)
    .filter(([, base]) => own(allowlist, base))
    .map(([key]) => key)
    .sort();
  const actualKeys = Object.keys(emissiveCache).sort();
  check(JSON.stringify(actualKeys) === JSON.stringify(expectedKeys),
    'SPRITE_EMISSIVE_CACHE keys must exactly cover every authored allowlisted sprite frame');
  for (const key of expectedKeys) {
    const canvas = emissiveCache[key];
    check(Boolean(canvas), `SPRITE_EMISSIVE_CACHE is missing ${key}`);
    if (!canvas) continue;
    check(canvas.width === 32 && canvas.height === 32, `${key} emissive mask must be an exact 32x32 cache canvas`);
  }
}

async function main() {
  if (RED_CASE && !RED_CASES.has(RED_CASE)) {
    failures.push(`unknown RB_PHASE1_GATE_RED mode: ${RED_CASE}`);
  }

  const sources = {
    actors: read('src/render/actors_weather.js'),
    frame: read('src/render/frame.js'),
    landmarks: read('src/render/landmarks_a.js'),
    props: read('src/render/props.js'),
    sprites: read('src/render/sprites.js'),
    incidents: read('src/systems/incidents.js'),
    index: read('index.html'),
  };

  const phaseSource = Object.values(sources).join('\n');
  check(!/(?:getContext\s*\(\s*['"]webgl2?['"]|WebGLRenderingContext|createShader\s*\(|shaderSource\s*\(|fragmentShader|vertexShader)/i.test(phaseSource),
    'Phase 1 render path must remain Canvas 2D with no WebGL/shaders');
  check(!/\b(?:ctx|octx|gctx|lctx|mctx)\.filter\s*=/.test(phaseSource),
    'Phase 1 render path may not use runtime canvas filter blur');
  check(!/imageSmoothingEnabled\s*=\s*true/.test(phaseSource),
    'Phase 1 render path may not enable smoothing');
  check(/canvas#game\s*\{[^}]*image-rendering\s*:\s*pixelated/i.test(sources.index),
    'world canvas must retain image-rendering: pixelated');

  const lightingBody = extractFunction(sources.actors, 'drawLighting');
  check(Boolean(lightingBody), 'drawLighting must remain an exported function');
  check(!/(?:createRadialGradient|createLinearGradient|\.filter\s*=)/.test(lightingBody),
    'drawLighting must consume prerendered sheets, not build gradients or filters per frame');
  let lightingOrderBody = lightingBody;
  if (RED_CASE === 'render-order') {
    lightingOrderBody = lightingBody
      .replace('drawAmbientGrade();', '')
      .replace('drawPlayerEmissives();', 'drawPlayerEmissives();drawAmbientGrade();');
  }
  ordered(lightingOrderBody, [
    'ctx.drawImage(LIGHT_MASK',
    'drawAmbientGrade()',
    'drawEmissiveCore',
    'drawPlayerEmissives()',
    "globalCompositeOperation='lighter'",
    "globalCompositeOperation='source-over'",
  ], 'drawLighting');

  const frameBody = extractFunction(sources.frame, 'drawAll');
  check(Boolean(frameBody), 'drawAll must remain an exported function');
  ordered(frameBody, ['prepareLightingFrame(', 'ctx.translate('], 'drawAll lighting preparation');
  ordered(frameBody, ['drawIncidentShadows()', 'drawIncidents()'], 'drawAll incident AO');
  ordered(frameBody, ['drawNpcContactShadow(', 'drawNpc(n)'], 'drawAll NPC AO');
  ordered(frameBody, ['drawPlayerContactShadow()', 'drawPlayer()'], 'drawAll player AO');
  ordered(frameBody, ['ctx.restore()', 'drawLighting()', 'drawWeather()'], 'drawAll grade/weather ordering');

  const propsBody = extractFunction(sources.props, 'drawProps');
  check(Boolean(propsBody), 'drawProps must remain an exported function');
  ordered(propsBody, ['drawPropContactShadow(', 'drawProp(p)'], 'prop contact shadow ordering');
  ordered(propsBody, ['drawInteractivePropContactShadow(', 'drawInteractiveProp('], 'interactive prop contact shadow ordering');
  const incidentShadowBody = extractFunction(sources.incidents, 'drawIncidentShadows');
  check(incidentShadowBody.includes('drawContactShadow(') && incidentShadowBody.includes('drawContactBand('),
    'incident shadows must delegate multiply AO and contact bands to the shared helpers');

  const runtime = await loadModularGame();
  const world = moduleNamespace(runtime, 'src/data/world.js');
  const dataProps = moduleNamespace(runtime, 'src/data/props.js');
  const core = moduleNamespace(runtime, 'src/core/runtime_ui.js');
  const landmarks = moduleNamespace(runtime, 'src/render/landmarks_a.js');
  const actors = moduleNamespace(runtime, 'src/render/actors_weather.js');
  const renderProps = moduleNamespace(runtime, 'src/render/props.js');
  const sprites = moduleNamespace(runtime, 'src/render/sprites.js');

  check(Object.isFrozen(world.DIEGETIC_LIGHT_RGB), 'DIEGETIC_LIGHT_RGB registry must be frozen');
  let grades = world.AMBIENT_GRADES;
  if (RED_CASE === 'missing-grade') {
    grades = omitGrade(grades, 'block');
  } else if (RED_CASE === 'grade-alpha') {
    grades = Object.freeze({
      ...grades,
      block: Object.freeze({ ...grades.block, multiplyAlpha: 0.19 }),
    });
  }
  validateGrades(grades, world.ZONES, world.TERRAIN_REGIONS);

  for (const zone of world.ZONES) {
    const grade = landmarks.ambientGradeAt(zone.x + zone.w / 2, zone.y + zone.h / 2);
    check(grade === world.AMBIENT_GRADES[zone.id], `ambientGradeAt must resolve zone ${zone.id}`);
  }

  core.state.cam.x = 900;
  core.state.cam.y = 500;
  core.state.dayTime = 0.05;
  core.P.x = 1250;
  core.P.y = 850;
  core.P.rockedT = 1000;
  core.P.facing = 'right';
  core.runtime.npcs.push({
    id: 'phase1_gate_cop',
    isCop: true,
    sprite: 'cop',
    x: 1450,
    y: 850,
    w: 18,
    h: 22,
    dead: false,
  });
  landmarks.prepareLightingFrame(0, 0);
  let activeLights = landmarks.ACTIVE_LIGHTS.map(light => ({ ...light }));
  if (RED_CASE === 'missing-emitter') {
    activeLights = activeLights.filter(light => light.kind !== 'barrel_fire');
  }
  if (RED_CASE === 'forbidden-rgb') {
    const index = activeLights.findIndex(light => light.kind !== 'cop_light');
    if (index >= 0) activeLights[index].rgb = '255,255,255';
  }
  validateEmitters(activeLights, landmarks.LIGHT_GLOW_CACHE, world.DIEGETIC_LIGHT_RGB);

  const canvasContext = runtime.context.__qa.context2d;
  const originalFillRect = canvasContext.fillRect;
  const originalDrawImage = canvasContext.drawImage;

  const gradeOps = [];
  canvasContext.fillRect = function captureGrade(x, y, width, height) {
    if (x === 0 && y === 0 && width === world.W && height === world.H) {
      gradeOps.push({
        composite: this.globalCompositeOperation,
        alpha: this.globalAlpha,
        fillStyle: this.fillStyle,
      });
    }
    return originalFillRect.apply(this, arguments);
  };
  core.state.dayTime = 0.5;
  landmarks.prepareLightingFrame(0, 0);
  actors.drawLighting();
  canvasContext.fillRect = originalFillRect;
  const daytimeGrade = landmarks.ambientGradeAt(core.state.cam.x + world.W / 2, core.state.cam.y + world.H / 2);
  const multiplyOp = gradeOps.find(operation => operation.composite === 'multiply');
  const overlayOp = gradeOps.find(operation => operation.composite === 'overlay');
  check(Boolean(multiplyOp), 'daytime drawLighting must still apply the per-area multiply grade');
  check(Boolean(overlayOp), 'daytime drawLighting must still apply the per-area overlay grade');
  if (multiplyOp) check(Math.abs(multiplyOp.alpha - daytimeGrade.multiplyAlpha) < 1e-9,
    'daytime multiply grade alpha must match the selected ambient grade');
  if (overlayOp) check(Math.abs(overlayOp.alpha - daytimeGrade.overlayAlpha) < 1e-9,
    'daytime overlay grade alpha must match the selected ambient grade');

  const directionSamples = [];
  const subjectX = 100;
  const subjectY = 100;
  for (const light of [
    { x: 140, y: 100 },
    { x: 60, y: 100 },
    { x: 100, y: 140 },
    { x: 100, y: 60 },
  ]) {
    landmarks.ACTIVE_LIGHTS.length = 0;
    landmarks.ACTIVE_LIGHTS.push({ ...light, active: true, castsShadow: true });
    const offset = landmarks.contactShadowOffset(subjectX, subjectY, [0, 0]);
    directionSamples.push({
      subjectX,
      subjectY,
      lightX: light.x,
      lightY: light.y,
      offsetX: offset[0],
      offsetY: offset[1],
    });
  }
  if (RED_CASE === 'shadow-direction' && directionSamples.length) {
    directionSamples[0].offsetX *= -1;
    directionSamples[0].offsetY *= -1;
  }
  validateShadowDirection(directionSamples);

  const shadowOps = [];
  canvasContext.drawImage = function captureShadow(image) {
    if (image === landmarks.CONTACT_SHADOW_SHEET) {
      shadowOps.push({ composite: this.globalCompositeOperation, alpha: this.globalAlpha });
    }
    return originalDrawImage.apply(this, arguments);
  };
  landmarks.drawContactShadow(100, 100, 10, 3, 0.36);
  canvasContext.drawImage = originalDrawImage;
  check(shadowOps.length === 1, 'drawContactShadow must draw the cached contact-shadow sheet once');
  if (shadowOps[0]) {
    check(shadowOps[0].composite === 'multiply', 'contact shadow must use multiply compositing');
    check(shadowOps[0].alpha >= 0.30 && shadowOps[0].alpha <= 0.40,
      'contact shadow alpha must remain within 30-40%');
  }

  let contactBand = null;
  canvasContext.fillRect = function captureBand(x, y, width, height) {
    contactBand = {
      composite: this.globalCompositeOperation,
      alpha: this.globalAlpha,
      height,
    };
    return originalFillRect.apply(this, arguments);
  };
  landmarks.drawContactBand(100, 100, 12, 0.34, 2);
  canvasContext.fillRect = originalFillRect;
  check(Boolean(contactBand), 'drawContactBand must issue a ground-contact rectangle');
  if (contactBand) {
    if (RED_CASE === 'contact-band') contactBand.height = 3;
    validateContactBand(contactBand);
  }

  const propTypes = [...new Set(dataProps.PROPS.map(prop => prop.type))].sort();
  let profiled = Object.keys(renderProps.PROP_AO_PROFILE);
  if (RED_CASE === 'unclassified-prop') profiled = profiled.slice(1);
  const exempt = [...renderProps.PROP_AO_EXEMPT];
  const declared = [...new Set([...profiled, ...exempt])].sort();
  check(JSON.stringify(declared) === JSON.stringify(propTypes),
    'every PROPS type must have exactly one AO profile or explicit exemption, with no stale declarations');
  check(profiled.every(type => !renderProps.PROP_AO_EXEMPT.has(type)),
    'a prop type may not be both AO-profiled and exempt');
  check(Object.isFrozen(renderProps.PROP_AO_PROFILE), 'PROP_AO_PROFILE must be frozen');
  check(profiled.every(type => typeof renderProps.PROP_AO_PROFILE[type] === 'string'),
    'PROP_AO_PROFILE entries must use named renderer profiles');
  core.P.cartMounted = false;
  for (const type of profiled) {
    const prop = dataProps.PROPS.find(candidate => candidate.type === type);
    const operations = { shadows: [], bands: [] };
    canvasContext.drawImage = function captureProfileShadow(image) {
      if (image === landmarks.CONTACT_SHADOW_SHEET) {
        operations.shadows.push({ composite: this.globalCompositeOperation, alpha: this.globalAlpha });
      }
      return originalDrawImage.apply(this, arguments);
    };
    canvasContext.fillRect = function captureProfileBand(x, y, width, height) {
      operations.bands.push({ composite: this.globalCompositeOperation, alpha: this.globalAlpha, height });
      return originalFillRect.apply(this, arguments);
    };
    renderProps.drawPropContactShadow(prop);
    canvasContext.drawImage = originalDrawImage;
    canvasContext.fillRect = originalFillRect;
    check(operations.shadows.length === 1, `${type} must draw exactly one cached contact shadow`);
    check(operations.bands.length === 1, `${type} must draw exactly one contact band`);
    const shadow = operations.shadows[0];
    const band = operations.bands[0];
    if (shadow) {
      check(shadow.composite === 'multiply', `${type} shadow must use multiply compositing`);
      check(shadow.alpha >= 0.30 && shadow.alpha <= 0.40, `${type} shadow alpha must remain within 30-40%`);
    }
    if (band) {
      check(band.composite === 'multiply', `${type} contact band must use multiply compositing`);
      check(band.alpha >= 0.30 && band.alpha <= 0.40, `${type} contact band alpha must remain within 30-40%`);
      check(band.height >= 1 && band.height <= 2, `${type} contact band must be 1-2px tall`);
    }
  }

  let emissiveIndices = sprites.EMISSIVE_PALETTE_INDICES;
  if (RED_CASE === 'emissive-index') emissiveIndices = Object.freeze([2, 8]);
  validateEmissives(
    emissiveIndices,
    sprites.EMISSIVE_BASE_INDICES,
    sprites.SPRITE_KEY_BASES,
    sprites.SPRITE_EMISSIVE_CACHE,
  );

  check(landmarks.CONTACT_SHADOW_SHEET?.width === 64 && landmarks.CONTACT_SHADOW_SHEET?.height === 24,
    'contact shadow sheet must remain a prerendered 64x24 canvas');
  check(landmarks.FOG_SHEET?.width > 0 && landmarks.FOG_SHEET?.height > 0,
    'FOG_SHEET must remain a prerendered canvas');

  if (RED_CASE && failures.length === 0) {
    failures.push(`intentional red mode ${RED_CASE} did not trip a gate`);
  }

  if (failures.length) {
    console.error(`phase1-lighting-gate: FAIL (${failures.length} failure${failures.length === 1 ? '' : 's'}, ${checks} checks)`);
    if (RED_CASE) console.error(`intentional red mode: ${RED_CASE}`);
    for (const failure of failures) console.error(`  - ${failure}`);
    process.exitCode = 1;
    return;
  }

  console.log(`phase1-lighting-gate: PASS (${checks} checks)`);
}

main().catch(error => {
  console.error('phase1-lighting-gate: ERROR');
  console.error(error?.stack || error);
  process.exitCode = 1;
});
