import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

if (!process.execArgv.includes('--experimental-vm-modules')) {
  const child = spawnSync(process.execPath, [
    '--experimental-vm-modules', '--no-warnings', fileURLToPath(import.meta.url), ...process.argv.slice(2),
  ], { stdio: 'inherit' });
  process.exit(child.status ?? 1);
}

const ROOT = path.resolve(import.meta.dirname, '..');
const RED_CASE = process.argv.find(argument => argument.startsWith('--red='))?.slice(6) || '';
const RED_CASES = new Set([
  'sprite-topology',
  'character-palette',
  'dither-third-index',
  'duplicate-variant',
  'variant-topology',
  'variant-blue',
  'missing-cell',
  'cell-density',
  'stamp-overlap',
  'missing-static-family',
  'missing-loop-family',
  'bad-loop-frame-count',
  'frozen-loop',
  'synchronized-loop',
  'nondeterministic-layout',
  'unculled-draw',
  'visible-budget',
  'runtime-raster',
  'render-order',
  'gameplay-leak',
  'tile-seam',
]);

const EXPECTED_BASE_COUNT = 94;
const EXPECTED_NORMAL_KEY_COUNT = 377;
const EXPECTED_ENV_KEYS = Object.freeze([
  'storm_drain', 'news_box', 'road_barrier', 'claim_sign', 'clan_banner_blue',
  'clan_banner_receipt', 'clan_banner_wire', 'clan_banner_curb', 'rail_signal',
  'utility_top', 'utility_base',
]);
const EXPECTED_DRAW_SITE_HASH = 'fefd005d79ad33fd9f3919b7da44870405b862706adcfcde301e9dc1f7512585';
const EXPECTED_CHARACTER_PALETTE_HASH = 'cf0ba657e8e4d63b89f9c0cf9cde085b8555fbc15fb2c271f960e0e3aa874b81';
const EXPECTED_ENVIRONMENT_PALETTE_HASH = 'ab49d9868ec172f3d3e487ed0230df09319ba395f8df3f8e4d6baaa734348bd3';
// Ratified after the production metadata exports land. A blank pin is a loud failure, never a bypass.
const EXPECTED_GRID_TOPOLOGY_HASH = '84f9d23b18af3f82ead85fd241b758ff24a4545fb4f371f48e5f1c47e91e8e45';
const EXPECTED_TILE_SEAM_HASH = '877031defb829981375890ace90061750562539efeae9ab8724e7bbd12db38ac';
const EXPECTED_LAYOUT_HASH = 'a2d9ef37';

const EXPECTED_VARIANT_KINDS = Object.freeze(['mold_sick', 'mauve_shadow', 'sun_bleached']);
const HUMANOID_BASES = Object.freeze([
  'barb', 'biggu', 'bishop_wire', 'blue_tarp_guard', 'brendan', 'busker', 'conductor', 'cop',
  'cubscout', 'curb_emperor', 'darryl_under_blue', 'dave', 'dogwalker', 'foodtruck',
  'general_receipt', 'gutter_greg', 'jogger', 'karaoke', 'larry', 'launderlady', 'lease_guy',
  'lurch', 'math', 'mayorscousin', 'metermaid', 'mom', 'paulie', 'pete', 'philosopher',
  'phoneguy', 'pinky', 'price_guy', 'priest', 'priestson', 'receipt_guard', 'sherri', 'stripe',
  'tony', 'train_hopper', 'vapelord', 'wire_guard', 'yuri',
]);
const STATE_BASES = Object.freeze(['dave_sleep', 'tony_coat_2', 'tony_coat_1', 'tony_bare', 'priest_fallen']);
const SPECIAL_BASES = Object.freeze(['possum', 'brutus', 'scrap_dog', 'os_brutus', 'pigeon', 'horsecop', 'pothole']);
const EXPECTED_VARIANT_BASES = Object.freeze([...HUMANOID_BASES, ...STATE_BASES, ...SPECIAL_BASES].sort());
const AUTHORITY_BLUE_BASES = new Set(['cop', 'horsecop', 'brendan']);

const EXPECTED_STATIC_FAMILIES = Object.freeze([
  'trash_cluster', 'puddle', 'oil_slick', 'mildew_patch', 'wire_tangle', 'bent_needle',
  'spent_stub', 'glass_shards', 'can_cluster', 'rat_hole', 'paper_scraps', 'storm_grate',
]);
const EXPECTED_LOOP_FRAME_COUNTS = Object.freeze({
  flies: 3,
  sign_buzz: 2,
  grate_steam: 4,
  drip: 3,
  wire_tremor: 4,
  tv_glow: 3,
});

const failures = [];
let checks = 0;
let poisonLanded = false;
const failureStart = () => failures.length;
const fail = message => failures.push(message);
function check(condition, message) {
  checks += 1;
  if (!condition) fail(message);
}
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const sorted = values => [...values].sort();
const sameSet = (a, b) => JSON.stringify(sorted(a)) === JSON.stringify(sorted(b));
const read = relative => fs.readFileSync(path.join(ROOT, relative), 'utf8');
const hashText = text => createHash('sha256').update(text).digest('hex');

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
const hashValue = value => hashText(canonical(value));

function clone(value) {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    const result = {};
    for (const [key, child] of Object.entries(value)) result[key] = clone(child);
    return result;
  }
  return value;
}

function markPoison(condition, detail) {
  if (!condition) fail(`[intentional red ${RED_CASE}] poison did not land: ${detail}`);
  else poisonLanded = true;
}

function requireExport(namespace, name, owner) {
  if (!namespace || !(name in namespace) || namespace[name] == null) {
    fail(`${owner} is missing required export ${name}`);
    return null;
  }
  return namespace[name];
}

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
}

function extractFunction(source, name) {
  const declaration = new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\(`).exec(source);
  if (!declaration) return '';
  const start = source.indexOf('{', declaration.index + declaration[0].length);
  if (start < 0) return '';
  let depth = 0, quote = '', escaped = false, lineComment = false, blockComment = false;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index], next = source[index + 1];
    if (lineComment) { if (char === '\n') lineComment = false; continue; }
    if (blockComment) {
      if (char === '*' && next === '/') { blockComment = false; index += 1; }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '/' && next === '/') { lineComment = true; index += 1; continue; }
    if (char === '/' && next === '*') { blockComment = true; index += 1; continue; }
    if (char === "'" || char === '"' || char === '`') { quote = char; continue; }
    if (char === '{') depth += 1;
    else if (char === '}' && --depth === 0) return source.slice(start, index + 1);
  }
  return '';
}

function ordered(source, needles, label) {
  let cursor = -1;
  for (const needle of needles) {
    const index = source.indexOf(needle, cursor + 1);
    check(index >= 0, `${label} must contain ${needle}`);
    if (index < 0) return;
    check(index > cursor, `${label} must order ${needle} after the preceding step`);
    cursor = index;
  }
}

function parseHex(raw) {
  if (typeof raw !== 'string') return null;
  let value = raw.trim().toLowerCase();
  if (value === 'transparent') return 'transparent';
  if (!/^#[0-9a-f]{3}(?:[0-9a-f]{3})?$/.test(value)) return null;
  value = value.slice(1);
  if (value.length === 3) value = [...value].map(char => char + char).join('');
  return [0, 2, 4].map(index => Number.parseInt(value.slice(index, index + 2), 16));
}

function isBrightBlue(rgb) {
  if (!Array.isArray(rgb)) return false;
  const [red, green, blue] = rgb;
  return blue >= 180 && blue - red >= 50 && blue - green >= 35;
}

function paletteProblems(label, palette, {
  authority = false, basePalette = null, exactEight = false, strictBlue = false,
} = {}) {
  const problems = [];
  if (!Array.isArray(palette) || palette.length < 2 || palette.length > 8 || (exactEight && palette.length !== 8)) {
    problems.push(`${label}: palette must contain ${exactEight ? 'exactly 8' : '2..8'} entries`);
    return problems;
  }
  if (palette[0] !== 'transparent') problems.push(`${label}: palette index 0 must be transparent`);
  for (let index = 1; index < palette.length; index += 1) {
    const rgb = parseHex(palette[index]);
    if (!rgb || rgb === 'transparent') {
      problems.push(`${label}: index ${index} is not a hex color`);
      continue;
    }
    if (rgb.every(channel => channel === 255)) problems.push(`${label}: pure white is forbidden`);
    if (isBrightBlue(rgb) && !authority && (strictBlue || (rgb[0] === 0 && rgb[1] === 0 && rgb[2] === 255))) {
      const inherited = basePalette && parseHex(basePalette[index]);
      if (!inherited || !isBrightBlue(inherited)) problems.push(`${label}: variant creates bright blue outside authority`);
    }
  }
  return problems;
}

function validateNormalSprites(fixture) {
  const { sizes, keyBases, cache, pixelCounts, palettes, topology, gridStats, envCache, envPalettes } = fixture;
  if (!sizes || !keyBases || !cache || !pixelCounts || !palettes || !topology || !gridStats || !envCache || !envPalettes) return;
  check(Object.keys(sizes).length === EXPECTED_BASE_COUNT, `normal sprite base count must remain ${EXPECTED_BASE_COUNT}`);
  check(Object.isFrozen(sizes), 'SPRITE_BASE_SIZES must remain frozen');
  check(Object.values(sizes).every(size => size === 32), 'Phase 3 boundary: every character base must remain 32-logical');
  const keys = Object.keys(cache);
  check(keys.length === EXPECTED_NORMAL_KEY_COUNT, `normal SPRITE_CACHE key count must remain ${EXPECTED_NORMAL_KEY_COUNT}`);
  check(sameSet(keys, Object.keys(keyBases)), 'normal cache keys and SPRITE_KEY_BASES must match exactly');
  check(sameSet(keys, Object.keys(pixelCounts)), 'normal cache keys and pixel-count metadata must match exactly');
  check(sameSet(keys, Object.keys(palettes)), 'normal cache keys and palette metadata must match exactly');
  check(sameSet(keys, Object.keys(topology)), 'SPRITE_GRID_TOPOLOGY must cover exactly the 377 normal keys');
  check(sameSet(keys, Object.keys(gridStats)), 'SPRITE_GRID_STATS must cover exactly the 377 normal keys');
  check(Object.isFrozen(topology), 'SPRITE_GRID_TOPOLOGY must be frozen');
  check(Object.isFrozen(gridStats), 'SPRITE_GRID_STATS must be frozen');
  for (const key of keys) {
    const canvas = cache[key], stats = gridStats[key], signature = topology[key];
    check(canvas?.width === 32 && canvas?.height === 32, `${key}: normal cache canvas must remain 32x32`);
    check(Number.isInteger(pixelCounts[key]) && pixelCounts[key] > 0, `${key}: normal frame must remain nonblank`);
    check(typeof signature === 'string' && signature.length === 256 && /^[0-9a-f]+$/i.test(signature),
      `${key}: topology signature must be 256 hexadecimal characters`);
    check(Boolean(stats) && Object.isFrozen(stats), `${key}: grid stats must exist and be frozen`);
    if (stats) {
      check(stats.width === 32 && stats.height === 32, `${key}: source grid stats must remain 32x32`);
      check(stats.paintedPixels === pixelCounts[key], `${key}: grid stats painted count must match cache metadata`);
      check(Number.isInteger(stats.transparentPixels) && stats.transparentPixels + stats.paintedPixels === 1024,
        `${key}: painted + transparent topology must total 1024`);
      check(Number.isInteger(stats.indexMask) && stats.indexMask >= 0 && stats.indexMask < 256,
        `${key}: index mask must stay within the eight-index model`);
    }
    for (const problem of paletteProblems(`normal sprite ${key}`, palettes[key], {
      authority: AUTHORITY_BLUE_BASES.has(keyBases[key]),
    })) fail(problem);
  }
  const topologyHash = hashValue(Object.entries(topology).sort(([a], [b]) => a.localeCompare(b)));
  check(Boolean(EXPECTED_GRID_TOPOLOGY_HASH),
    `normal topology pin is unset; ratify ${topologyHash} after auditing the 377-key Phase 2 grid corpus`);
  if (EXPECTED_GRID_TOPOLOGY_HASH) check(topologyHash === EXPECTED_GRID_TOPOLOGY_HASH,
    `normal grid topology corpus drifted (${topologyHash})`);
  const paletteSnapshot = Object.entries(palettes).sort(([a], [b]) => a.localeCompare(b));
  check(hashText(JSON.stringify(paletteSnapshot)) === EXPECTED_CHARACTER_PALETTE_HASH,
    'character palette-use corpus does not match the once-ratified Phase 2 hash');
  check(sameSet(Object.keys(envCache), EXPECTED_ENV_KEYS), 'environment cache must remain the exact 11-key Phase 1 set');
  for (const key of EXPECTED_ENV_KEYS) check(envCache[key]?.width === 32 && envCache[key]?.height === 32,
    `${key}: environment cache canvas must remain 32x32`);
  const environmentSnapshot = Object.entries(envPalettes).map(([key, value]) => [key, clone(value)])
    .sort(([a], [b]) => a.localeCompare(b));
  check(hashText(JSON.stringify(environmentSnapshot)) === EXPECTED_ENVIRONMENT_PALETTE_HASH,
    'environment palette-use hash moved during Phase 2');
}

function validateDither(toolkit, sources, probe) {
  if (!toolkit?.gridDither) { fail('sprite_toolkit.js is missing required export gridDither'); return; }
  const expected = [[2, 3], [3, 2]];
  check(JSON.stringify(probe) === JSON.stringify(expected), 'gridDither 2x2 probe must be exactly A B / B A with no third index');
  check(new Set(probe.flat()).size === 2 && probe.flat().every(value => value === 2 || value === 3),
    'gridDither probe must use only its two caller-supplied indices');
  for (const relative of [
    'src/render/sprite_art_player_32.js',
    'src/render/sprite_art_npc_32.js',
    'src/render/sprite_art_special_32.js',
  ]) {
    const count = (stripComments(sources[relative]).match(/\bgridDither\s*\(/g) || []).length;
    check(count > 0, `${relative} must contain a production gridDither witness`);
  }
  const invalids = [
    () => toolkit.gridDither([[0]], 0, 0, 1, 1, 2, 2),
    () => toolkit.gridDither([[0]], 0, 0, 1, 1, 2, 8),
    () => toolkit.gridDither([[0]], 0.5, 0, 1, 1, 2, 3),
  ];
  for (const [index, run] of invalids.entries()) {
    let threw = false;
    try { run(); } catch { threw = true; }
    check(threw, `gridDither invalid-input probe ${index} must throw`);
  }
}

function validateVariants(fixture, sprites) {
  const { kinds, eligibleBases, palettes, cache, topology, stats } = fixture;
  if (!kinds || !eligibleBases || !palettes || !cache || !topology || !stats) return;
  check(JSON.stringify([...kinds]) === JSON.stringify(EXPECTED_VARIANT_KINDS),
    'variant kinds must be exactly mold_sick, mauve_shadow, sun_bleached');
  check(Object.isFrozen(kinds), 'SPRITE_VARIANT_KINDS must be frozen');
  check(sameSet(eligibleBases, EXPECTED_VARIANT_BASES), 'variant eligible bases must be the exact 54 drawNpc body bases');
  check(Object.isFrozen(eligibleBases), 'SPRITE_VARIANT_ELIGIBLE_BASES must be frozen');
  check(Object.isFrozen(palettes), 'SPRITE_VARIANT_PALETTES must be frozen');
  check(Object.isFrozen(cache), 'SPRITE_VARIANT_CACHE must be frozen');
  check(Object.isFrozen(topology), 'SPRITE_VARIANT_TOPOLOGY must be frozen');
  const expectedKeys = Object.entries(sprites.SPRITE_KEY_BASES)
    .filter(([, base]) => eligibleBases.includes(base)).map(([key]) => key).sort();
  check(expectedKeys.length === 155, `variant eligible normal-frame count must be exactly 155, got ${expectedKeys.length}`);
  for (const base of eligibleBases) {
    const rows = palettes[base];
    check(Boolean(rows) && Object.isFrozen(rows), `${base}: variant palette rows must exist and be frozen`);
    if (!rows) continue;
    check(sameSet(Object.keys(rows), kinds), `${base}: variant palette kinds must be exact`);
    const baseKey = expectedKeys.find(key => sprites.SPRITE_KEY_BASES[key] === base);
    const basePalette = sprites.SPRITE_KEY_PALETTES[baseKey];
    const fingerprints = new Set();
    for (const kind of kinds) {
      const palette = rows[kind];
      check(Object.isFrozen(palette), `${base}/${kind}: variant palette must be frozen`);
      for (const problem of paletteProblems(`variant ${base}/${kind}`, palette, {
        authority: AUTHORITY_BLUE_BASES.has(base), basePalette, exactEight: true, strictBlue: true,
      })) fail(problem);
      if (Array.isArray(palette) && Array.isArray(basePalette)) {
        const changed = palette.slice(1).filter((color, index) => color !== basePalette[index + 1]).length;
        check(changed >= 2, `${base}/${kind}: variant must differ from base at two nontransparent entries`);
      }
      const fingerprint = JSON.stringify(palette);
      check(!fingerprints.has(fingerprint), `${base}: variant palettes must be mutually distinct`);
      fingerprints.add(fingerprint);
    }
  }
  for (const kind of kinds) {
    const family = cache[kind];
    const topologyFamily = topology[kind];
    check(Boolean(family) && Object.isFrozen(family), `${kind}: variant cache family must exist and be frozen`);
    check(Boolean(topologyFamily) && Object.isFrozen(topologyFamily), `${kind}: variant topology family must exist and be frozen`);
    if (!family) continue;
    check(sameSet(Object.keys(family), expectedKeys), `${kind}: variant cache must cover exactly 155 eligible normal frames`);
    check(sameSet(Object.keys(topologyFamily || {}), expectedKeys), `${kind}: variant topology must cover exactly 155 eligible normal frames`);
    for (const key of expectedKeys) {
      check(family[key]?.width === 32 && family[key]?.height === 32, `${kind}/${key}: variant cache canvas must be 32x32`);
      check(topologyFamily?.[key] === sprites.SPRITE_GRID_TOPOLOGY[key],
        `${kind}/${key}: variant alpha topology must exactly match its normal frame`);
    }
  }
  const canvasCount = kinds.reduce((total, kind) => total + Object.keys(cache[kind] || {}).length, 0);
  check(canvasCount === 465, `variant cache must contain exactly 465 canvases, got ${canvasCount}`);
  check(Object.isFrozen(stats), 'SPRITE_VARIANT_STATS must be frozen');
  check(stats.eligibleFrameCount === 155, 'variant stats must report exactly 155 eligible frames');
  check(stats.canvasCount === 465, 'variant stats must report exactly 465 canvases');
  check(stats.topologyMismatches === 0, 'every variant must preserve the normal frame alpha topology');

  check(typeof sprites.selectSpriteVariantKind === 'function', 'selectSpriteVariantKind export is required');
  check(typeof sprites.resolveSpriteVariantCanvas === 'function', 'resolveSpriteVariantCanvas export is required');
  if (typeof sprites.selectSpriteVariantKind === 'function' && typeof sprites.resolveSpriteVariantCanvas === 'function') {
    const base = eligibleBases[0], key = expectedKeys.find(candidate => sprites.SPRITE_KEY_BASES[candidate] === base);
    const selections = new Set();
    for (let index = 0; index < 96; index += 1) {
      const identity = `phase2-gate-${index}`;
      const first = sprites.selectSpriteVariantKind(identity, base);
      const second = sprites.selectSpriteVariantKind(identity, base);
      check(first === second, `${base}/${identity}: variant selection must be stable`);
      check(kinds.includes(first), `${base}/${identity}: selector returned undeclared variant ${first}`);
      selections.add(first);
    }
    check(selections.size === kinds.length, 'stable identity resolver fixture must reach all three variant kinds');
    check(sprites.resolveSpriteVariantCanvas(key, base, 'phase2-gate', '__invalid__') === sprites.SPRITE_CACHE[key],
      'invalid requested variant must fall back to normal SPRITE_CACHE');
    check(sprites.resolveSpriteVariantCanvas(key, '__invalid__', 'phase2-gate', kinds[0]) === sprites.SPRITE_CACHE[key],
      'invalid variant base must fall back to normal SPRITE_CACHE');
    check(sprites.resolveSpriteVariantCanvas(key, base, '', kinds[0]) === sprites.SPRITE_CACHE[key],
      'missing persistent identity must fall back to normal SPRITE_CACHE');
  }
}

function sourceGridProblems(label, grid, palette) {
  const problems = [];
  if (!Array.isArray(grid) || grid.length !== 16 || grid.some(row => !Array.isArray(row) || row.length !== 16)) {
    return [`${label}: source grid must be exactly 16x16`];
  }
  let painted = 0;
  for (let y = 0; y < 16; y += 1) for (let x = 0; x < 16; x += 1) {
    const index = grid[y][x];
    if (!Number.isInteger(index) || index < 0 || index >= palette.length) {
      problems.push(`${label}: undeclared palette index ${index} at ${x},${y}`);
    }
    if (index !== 0) painted += 1;
  }
  if (!painted) problems.push(`${label}: source grid may not be blank`);
  return problems;
}

function gridHash(grid) {
  let hash = 0x811c9dc5;
  for (let y = 0; y < grid.length; y += 1) for (let x = 0; x < grid[y].length; x += 1) {
    const index = grid[y][x];
    hash ^= (index + 1 + x * 17 + y * 31) & 0xff;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

function gridIndexMask(grid) {
  let mask = 0;
  for (const row of grid) for (const index of row) mask |= 1 << index;
  return mask >>> 0;
}

function paintedPixels(grid) {
  let painted = 0;
  for (const row of grid) for (const index of row) if (index !== 0) painted += 1;
  return painted;
}

function hasOrderedChecker(grid) {
  if (!Array.isArray(grid)) return false;
  for (let y = 0; y < grid.length - 1; y += 1) for (let x = 0; x < grid[y].length - 1; x += 1) {
    const a = grid[y][x], b = grid[y][x + 1];
    if (a !== b && a !== 0 && b !== 0 && grid[y + 1][x] === b && grid[y + 1][x + 1] === a) return true;
  }
  return false;
}

function validateArtMetadata(label, grid, palette, metadata) {
  check(Boolean(metadata) && Object.isFrozen(metadata), `${label}: source metadata must exist and be frozen`);
  if (!metadata) return;
  check(metadata.width === 16 && metadata.height === 16, `${label}: metadata must report 16x16 source art`);
  check(metadata.painted === paintedPixels(grid), `${label}: metadata painted count must match its source grid`);
  check(metadata.indexMask === gridIndexMask(grid), `${label}: metadata index mask must match its source grid`);
  check(metadata.gridHash === gridHash(grid), `${label}: metadata grid hash must match its source grid`);
  check(metadata.palette === palette, `${label}: metadata must retain the frozen source palette`);
}

function validateGrimeArt(tiles, fixture) {
  const { staticFamilies, loopFamilies, frameCounts, staticArt, loopArt, staticCache, loopCache, metadata } = fixture;
  if (!staticFamilies || !loopFamilies || !frameCounts || !staticArt || !loopArt || !staticCache || !loopCache || !metadata) return;
  check(JSON.stringify([...staticFamilies]) === JSON.stringify(EXPECTED_STATIC_FAMILIES),
    'static grime families must be the exact twelve-family grammar');
  check(Object.isFrozen(staticFamilies), 'GRIME_STATIC_FAMILIES must be frozen');
  check(JSON.stringify([...loopFamilies]) === JSON.stringify(Object.keys(EXPECTED_LOOP_FRAME_COUNTS)),
    'loop grime families must be the exact six-family grammar');
  check(Object.isFrozen(loopFamilies), 'GRIME_LOOP_FAMILIES must be frozen');
  check(JSON.stringify(frameCounts) === JSON.stringify(EXPECTED_LOOP_FRAME_COUNTS),
    'loop frame counts must remain flies3/sign2/steam4/drip3/wire4/tv3');
  check(Object.isFrozen(frameCounts), 'GRIME_LOOP_FRAME_COUNTS must be frozen');
  check(tiles.GRIME_LOGICAL_SIZE === 16 && tiles.GRIME_CACHE_SIZE === 32,
    'grime art must remain explicit 16-logical source rasterized to 32x32 caches');
  check(metadata.logicalSize === 16 && metadata.cacheSize === 32, 'GRIME_ART_METADATA must report 16->32 rasterization');
  check(Object.isFrozen(metadata), 'GRIME_ART_METADATA must be frozen');
  check(sameSet(Object.keys(staticArt), staticFamilies), 'static source art must exactly cover the static family registry');
  check(sameSet(Object.keys(staticCache), staticFamilies), 'static cache must exactly cover the static family registry');
  check(sameSet(Object.keys(metadata.statics || {}), staticFamilies), 'static metadata must exactly cover the static family registry');
  check(Object.isFrozen(staticArt) && Object.isFrozen(staticCache), 'static art and cache registries must be frozen');
  for (const family of staticFamilies) {
    const art = staticArt[family], canvas = staticCache[family];
    check(Boolean(art) && Object.isFrozen(art), `${family}: static source art must be frozen`);
    if (!art) continue;
    check(art.logicalSize === 16, `${family}: static art logical size must be 16`);
    check(Object.isFrozen(art.palette) && Object.isFrozen(art.grid), `${family}: palette and grid must be frozen`);
    check(art.grid.every(row => Object.isFrozen(row)), `${family}: source grid rows must be frozen`);
    for (const problem of paletteProblems(`static grime ${family}`, art.palette, { strictBlue: true })) fail(problem);
    for (const problem of sourceGridProblems(`static grime ${family}`, art.grid, art.palette)) fail(problem);
    check(hasOrderedChecker(art.grid), `${family}: source art must contain an ordered two-index checker witness`);
    check(canvas?.width === 32 && canvas?.height === 32, `${family}: static cache canvas must be exactly 32x32`);
    validateArtMetadata(`static grime ${family}`, art.grid, art.palette, metadata.statics?.[family]);
  }
  check(sameSet(Object.keys(loopArt), loopFamilies), 'loop source art must exactly cover the loop family registry');
  check(sameSet(Object.keys(loopCache), loopFamilies), 'loop cache must exactly cover the loop family registry');
  check(sameSet(Object.keys(metadata.loops || {}), loopFamilies), 'loop metadata must exactly cover the loop family registry');
  check(Object.isFrozen(loopArt) && Object.isFrozen(loopCache), 'loop art and cache registries must be frozen');
  for (const family of loopFamilies) {
    const art = loopArt[family], canvases = loopCache[family], expected = frameCounts[family];
    check(Boolean(art) && Object.isFrozen(art), `${family}: loop source art must be frozen`);
    if (!art) continue;
    check(art.logicalSize === 16, `${family}: loop art logical size must be 16`);
    check(Object.isFrozen(art.palette) && Object.isFrozen(art.frames), `${family}: loop palette and frame list must be frozen`);
    for (const problem of paletteProblems(`loop grime ${family}`, art.palette, { strictBlue: true })) fail(problem);
    check(art.frames.length === expected, `${family}: source loop must contain exactly ${expected} frames`);
    check(Array.isArray(canvases) && canvases.length === expected, `${family}: cache must contain exactly ${expected} frames`);
    check(Object.isFrozen(canvases), `${family}: loop cache frame list must be frozen`);
    check(new Set(canvases).size === expected, `${family}: cached loop frames must be distinct canvas objects`);
    const fingerprints = new Set();
    for (const [index, grid] of art.frames.entries()) {
      check(Object.isFrozen(grid) && grid.every(row => Object.isFrozen(row)), `${family}/${index}: source frame must be deeply frozen`);
      for (const problem of sourceGridProblems(`loop grime ${family}/${index}`, grid, art.palette)) fail(problem);
      check(hasOrderedChecker(grid), `${family}/${index}: source frame must contain an ordered checker witness`);
      fingerprints.add(canonical(grid));
      check(canvases?.[index]?.width === 32 && canvases?.[index]?.height === 32,
        `${family}/${index}: cached loop frame must be exactly 32x32`);
      validateArtMetadata(`loop grime ${family}/${index}`, grid, art.palette, metadata.loops?.[family]?.frames?.[index]);
    }
    check(fingerprints.size === expected, `${family}: all source loop frames must be visibly distinct grids`);
    const loopMetadata = metadata.loops?.[family];
    check(loopMetadata?.frameCount === expected, `${family}: metadata frame count must be ${expected}`);
    check(loopMetadata?.interval === tiles.GRIME_LOOP_INTERVALS?.[family], `${family}: metadata interval must match registry`);
  }
}

function recordHasGameplayField(record) {
  const banned = new Set(['solid', 'interact', 'interaction', 'reward', 'cash', 'item', 'loot', 'npc', 'save', 'collision']);
  return Object.keys(record || {}).some(key => banned.has(key.toLowerCase()));
}

function validateGrimeLayout(tiles, fixture, world) {
  const { cells, metadata, staticFamilies, loopFamilies, frameCounts } = fixture;
  if (!cells || !metadata || !staticFamilies || !loopFamilies || !frameCounts) return;
  check(tiles.GRIME_WORLD_WIDTH === 8600 && tiles.GRIME_WORLD_HEIGHT === 5600, 'grime world dimensions must remain 8600x5600');
  check(tiles.GRIME_CELL_SIZE === 192, 'grime coverage cell size must remain 192');
  check(tiles.GRIME_GRID_COLUMNS === 45 && tiles.GRIME_GRID_ROWS === 30,
    'grime coverage topology must remain exactly 45x30');
  check(tiles.GRIME_CELL_COUNT === 1350 && cells.length === 1350, 'grime layout must contain all 1350 cells');
  check(Object.isFrozen(cells), 'GRIME_CELLS must be frozen');
  const staticCounts = Object.fromEntries(staticFamilies.map(family => [family, 0]));
  const loopCounts = Object.fromEntries(loopFamilies.map(family => [family, 0]));
  const loopPhases = Object.fromEntries(loopFamilies.map(family => [family, new Set()]));
  let staticCount = 0, loopCount = 0;
  const seenIndices = new Set();
  for (let index = 0; index < cells.length; index += 1) {
    const cell = cells[index];
    check(Boolean(cell) && Object.isFrozen(cell), `grime cell ${index} must exist and be frozen`);
    if (!cell) continue;
    const expectedCol = index % 45, expectedRow = Math.floor(index / 45);
    check(cell.index === index && cell.col === expectedCol && cell.row === expectedRow,
      `grime cell ${index} must retain row-major index/coordinate topology`);
    check(!seenIndices.has(cell.index), `grime cell index ${cell.index} is duplicated`);
    seenIndices.add(cell.index);
    const expectedX = expectedCol * 192, expectedY = expectedRow * 192;
    const expectedWidth = Math.min(192, 8600 - expectedX), expectedHeight = Math.min(192, 5600 - expectedY);
    check(cell.x === expectedX && cell.y === expectedY && cell.width === expectedWidth && cell.height === expectedHeight,
      `grime cell ${index} must exactly cover its clipped world rectangle`);
    check(Array.isArray(cell.statics) && Object.isFrozen(cell.statics), `grime cell ${index} statics must be a frozen list`);
    check(cell.statics?.length >= 2 && cell.statics?.length <= 3, `grime cell ${index} must own 2-3 static stamps`);
    for (const [slot, stamp] of (cell.statics || []).entries()) {
      check(Object.isFrozen(stamp), `grime cell ${index} static ${slot} must be frozen`);
      check(staticFamilies.includes(stamp.family), `grime cell ${index} static ${slot} uses undeclared family ${stamp.family}`);
      check(Number.isInteger(stamp.x) && Number.isInteger(stamp.y), `grime cell ${index} static ${slot} coordinates must be integers`);
      check(stamp.x >= cell.x && stamp.y >= cell.y && stamp.x + 32 <= cell.x + cell.width && stamp.y + 32 <= cell.y + cell.height,
        `grime cell ${index} static ${slot} must stay within its clipped cell`);
      check(!recordHasGameplayField(stamp), `grime cell ${index} static ${slot} leaked a gameplay field`);
      if (own(staticCounts, stamp.family)) staticCounts[stamp.family] += 1;
      staticCount += 1;
    }
    if (cell.loop) {
      const loop = cell.loop;
      check(Object.isFrozen(loop), `grime cell ${index} loop must be frozen`);
      check(loopFamilies.includes(loop.family), `grime cell ${index} loop uses undeclared family ${loop.family}`);
      check(Number.isInteger(loop.x) && Number.isInteger(loop.y), `grime cell ${index} loop coordinates must be integers`);
      check(loop.x >= cell.x && loop.y >= cell.y && loop.x + 32 <= cell.x + cell.width && loop.y + 32 <= cell.y + cell.height,
        `grime cell ${index} loop must stay within its clipped cell`);
      check(loop.frameCount === frameCounts[loop.family], `grime cell ${index} loop frame count must match its family`);
      check(loop.interval === tiles.GRIME_LOOP_INTERVALS?.[loop.family], `grime cell ${index} loop interval must match its family`);
      check(Number.isInteger(loop.phase) && loop.phase >= 0 && loop.phase < loop.frameCount,
        `grime cell ${index} loop phase must be a valid frame offset`);
      check(!recordHasGameplayField(loop), `grime cell ${index} loop leaked a gameplay field`);
      if (own(loopCounts, loop.family)) {
        loopCounts[loop.family] += 1;
        loopPhases[loop.family].add(loop.phase);
      }
      loopCount += 1;
    }
    const records = [...(cell.statics || []), ...(cell.loop ? [cell.loop] : [])];
    for (let first=0; first<records.length; first++) for (let second=first+1; second<records.length; second++) {
      const a = records[first], b = records[second];
      const overlaps = a.x < b.x + 32 && a.x + 32 > b.x && a.y < b.y + 32 && a.y + 32 > b.y;
      check(!overlaps, `grime cell ${index} records ${first}/${second} must not overlap`);
    }
    check(!recordHasGameplayField(cell), `grime cell ${index} leaked a gameplay field`);
  }
  check(sameSet(Object.keys(staticCounts), EXPECTED_STATIC_FAMILIES), 'all twelve static families must remain represented');
  for (const family of staticFamilies) check(staticCounts[family] > 0, `${family}: static family must occur in the full-map layout`);
  const largestShare = Math.max(...Object.values(staticCounts)) / Math.max(1, staticCount);
  check(largestShare <= 0.20, `no static family may own over 20% of placements (observed ${(largestShare * 100).toFixed(2)}%)`);
  for (const family of loopFamilies) {
    check(loopCounts[family] > 0, `${family}: loop family must occur in the full-map layout`);
    check(loopPhases[family].size > 1, `${family}: loop placements must use multiple unsynchronized phases`);
  }
  check(Object.isFrozen(metadata), 'GRIME_LAYOUT_METADATA must be frozen');
  check(metadata.cells === cells, 'layout metadata must point at the authoritative frozen cell registry');
  check(metadata.worldWidth === 8600 && metadata.worldHeight === 5600 && metadata.cellSize === 192,
    'layout metadata world/cell geometry must match the contract');
  check(metadata.columns === 45 && metadata.rows === 30 && metadata.cellCount === 1350,
    'layout metadata must report exact 45x30/1350 coverage');
  check(metadata.staticCount === staticCount && metadata.loopCount === loopCount,
    'layout metadata placement totals must match the cell registry');
  check(canonical(metadata.staticFamilyCounts) === canonical(staticCounts), 'layout metadata static family counts must match records');
  check(canonical(metadata.loopFamilyCounts) === canonical(loopCounts), 'layout metadata loop family counts must match records');
  check(typeof metadata.layoutHash === 'string' && /^[0-9a-f]{8}$/.test(metadata.layoutHash),
    'layout metadata must expose an eight-hex deterministic layout hash');
  check(metadata.layoutHash === EXPECTED_LAYOUT_HASH, `full-map layout hash drifted (${metadata.layoutHash})`);
  check(metadata.spriteMargin === 32 && metadata.drawBudget === 90, 'layout metadata must pin the 32px margin and 90-draw budget');
  check(metadata.maxCandidate?.draws <= 90 && metadata.maxCandidate?.cells <= 30,
    'layout metadata candidate traversal must fit the 90-draw/30-cell bounds');
  for (const area of [...(world.ZONES || []), ...(world.TERRAIN_REGIONS || [])]) {
    check(cells.some(cell => cell.x < area.x + area.w && cell.x + cell.width > area.x &&
      cell.y < area.y + area.h && cell.y + cell.height > area.y),
    `coverage grid must intersect ${area.id || area.palette || 'world area'}`);
  }
}

function validateDrawSites(sources) {
  const definitions = [
    ['src/render/actors_weather.js', /^(?:sp|cart|layer|patch|weapon),/, 9],
    ['src/render/frame.js', /^smear,/, 1],
    ['src/systems/incidents.js', /^(?:sp|ps),/, 4],
  ];
  const drawSources = Object.create(null);
  const cacheDrawSites = definitions.map(([relative, pattern, expectedCount]) => {
    const source = sources[relative];
    drawSources[relative] = source;
    const calls = [...source.matchAll(/ctx\.drawImage\(([\s\S]*?)\);/g)]
      .map(match => match[1].replace(/\s+/g, ' ').trim()).filter(call => pattern.test(call));
    check(calls.length === expectedCount, `${relative}: expected ${expectedCount} character-cache draw sites, found ${calls.length}`);
    return [relative, calls];
  });
  function geometryMatch(relative, pattern, label) {
    const matched = drawSources[relative]?.match(pattern)?.[0];
    check(Boolean(matched), `${relative}: ${label} destination geometry must remain explicit`);
    return matched ? matched.replace(/\s+/g, ' ').trim() : '';
  }
  const cacheDrawGeometry = [
    geometryMatch('src/render/actors_weather.js', /const\s+drawX\s*=\s*Math\.round\([^;]+;\s*const\s+drawY\s*=\s*Math\.round\([^;]+;/, 'NPC anchor'),
    geometryMatch('src/render/actors_weather.js', /const\s+playerDrawX\s*=\s*P\.x-2\s*,\s*playerDrawY\s*=\s*P\.y-4\+\(P\.crashT>0\?1:0\)\s*;/, 'player anchor'),
    geometryMatch('src/render/frame.js', /let\s+ax=P\.x-2\s*,\s*ay=P\.y-4\s*;[\s\S]*?if\(P\.facing==='right'\)ax\+=18\s*;/, 'attack-smear anchor'),
  ];
  const digest = hashText(JSON.stringify({ cacheDrawSites, cacheDrawGeometry }));
  check(digest === EXPECTED_DRAW_SITE_HASH, `character-cache destination rect/anchor corpus drifted (${digest})`);
}

function validatePhaseOneAuthority(sprites, sources) {
  check(JSON.stringify(sprites.EMISSIVE_PALETTE_INDICES) === JSON.stringify([2, 7]),
    'Phase 1 emissive indices must remain exactly [2,7]');
  check(Object.isFrozen(sprites.EMISSIVE_PALETTE_INDICES), 'Phase 1 emissive index reservation must remain frozen');
  const expectedAllowlist = { gear_propane_torch: [2, 7], weapon_pipe: [2] };
  check(JSON.stringify(sprites.EMISSIVE_BASE_INDICES) === JSON.stringify(expectedAllowlist),
    'Phase 1 emissive base allowlist must remain torch:[2,7], pipe:[2]');
  check(Object.isFrozen(sprites.EMISSIVE_BASE_INDICES), 'Phase 1 emissive base allowlist must remain frozen');
  for (const indices of Object.values(sprites.EMISSIVE_BASE_INDICES || {})) check(Object.isFrozen(indices),
    'Phase 1 emissive per-base index lists must remain frozen');
  const expectedKeys = Object.entries(sprites.SPRITE_KEY_BASES || {})
    .filter(([, base]) => own(expectedAllowlist, base)).map(([key]) => key).sort();
  check(expectedKeys.length === 12, `Phase 1 emissive derivation must retain exactly 12 normal frames, got ${expectedKeys.length}`);
  check(sameSet(Object.keys(sprites.SPRITE_EMISSIVE_CACHE || {}), expectedKeys),
    'Phase 1 emissive cache must exactly cover the 12 allowlisted normal frames');
  for (const key of expectedKeys) check(sprites.SPRITE_EMISSIVE_CACHE[key]?.width === 32 && sprites.SPRITE_EMISSIVE_CACHE[key]?.height === 32,
    `${key}: Phase 1 emissive mask must remain 32x32`);
  const lighting = extractFunction(sources['src/render/actors_weather.js'], 'drawLighting');
  check(Boolean(lighting), 'drawLighting must remain present for Phase 1 authority');
  ordered(lighting, [
    'ctx.drawImage(LIGHT_MASK', 'drawAmbientGrade()', 'drawEmissiveCore', 'drawPlayerEmissives()',
    "globalCompositeOperation='lighter'", "globalCompositeOperation='source-over'",
  ], 'drawLighting Phase 1 stack');
}

function validateSourceContracts(sources, frameOrderSource, grimeDrawSource) {
  const phaseSource = Object.values(sources).join('\n');
  check(!/(?:getContext\s*\(\s*['"]webgl2?['"]|WebGLRenderingContext|createShader\s*\(|shaderSource\s*\(|fragmentShader|vertexShader|normalMap)/i.test(phaseSource),
    'Phase 2 must remain Canvas 2D with no WebGL, shaders, or normal maps');
  check(!/\b(?:ctx|octx|gctx|lctx|mctx)\.filter\s*=/.test(phaseSource), 'Phase 2 may not use runtime canvas filters');
  check(!/imageSmoothingEnabled\s*=\s*true/.test(phaseSource), 'Phase 2 may not enable image smoothing');
  check(/canvas#game\s*\{[^}]*image-rendering\s*:\s*pixelated/i.test(sources['index.html']),
    'world canvas must retain image-rendering: pixelated');
  const strippedFrame = stripComments(frameOrderSource);
  check(/drawWorldFabric\s*\(\s*\)\s*;\s*drawFullMapGrime\s*\(\s*\)\s*;/.test(strippedFrame),
    'drawFullMapGrime must run immediately after drawWorldFabric');
  ordered(strippedFrame, ['drawWorldFabric()', 'drawFullMapGrime()', 'drawProps()', 'ctx.restore()', 'drawLighting()'],
    'drawAll Phase 2/Phase 1 render stack');
  check(/import\s*\{[^}]*\bdrawFullMapGrime\b[^}]*\}\s*from\s*['"]\.\/tiles\.js['"]/.test(frameOrderSource),
    'frame renderer must import drawFullMapGrime from the tile renderer');

  check(Boolean(grimeDrawSource), 'drawFullMapGrime must remain an exported function');
  const helperBodies = [
    'grimeRecordVisible', 'firstVisibleGrimeColumn', 'lastVisibleGrimeColumn',
    'firstVisibleGrimeRow', 'lastVisibleGrimeRow', 'grimeLoopFrameIndex',
  ].map(name => extractFunction(sources['src/render/tiles.js'], name)).join('\n');
  const hotPathSource = `${grimeDrawSource}\n${helperBodies}`;
  const bannedHotPath = [
    [/createElement\s*\(/, 'createElement'], [/create(?:Linear|Radial)Gradient\s*\(/, 'gradient creation'],
    [/\brasterize\s*\(/, 'rasterize'], [/getImageData\s*\(/, 'getImageData'], [/putImageData\s*\(/, 'putImageData'],
    [/Math\.random\s*\(/, 'Math.random'], [/\.(?:map|filter|reduce|forEach)\s*\(/, 'array iterator allocation'],
    [/Array\.from\s*\(/, 'Array.from'], [/new\s+Array\s*\(/, 'new Array'],
    [/=\s*\[/, 'per-frame array literal'], [/=\s*\{/, 'per-frame object literal'], [/return\s*\{/, 'returned object allocation'],
  ];
  for (const [pattern, name] of bannedHotPath) check(!pattern.test(hotPathSource),
    `drawFullMapGrime hot path may not use ${name}`);
  check(!/for\s*\([^)]*\bof\s+GRIME_CELLS\b/.test(grimeDrawSource) &&
    !/GRIME_CELLS\s*\.\s*(?:map|filter|forEach|reduce)\s*\(/.test(grimeDrawSource),
  'drawFullMapGrime may not scan the full 1350-cell registry');
  check(/firstVisibleGrimeColumn\s*\(/.test(grimeDrawSource) && /lastVisibleGrimeRow\s*\(/.test(grimeDrawSource) &&
    /row\s*\*\s*GRIME_GRID_COLUMNS\s*\+\s*col/.test(grimeDrawSource),
  'drawFullMapGrime must traverse bounded visible row/column indices');
  check(/ctx\.drawImage\s*\(/.test(grimeDrawSource), 'drawFullMapGrime must consume prerendered canvases via drawImage');
  check(!/\b(?:fillRect|strokeRect|fill|stroke|ellipse|arc|lineTo|moveTo)\s*\(/.test(grimeDrawSource),
    'drawFullMapGrime may only draw cached images, not runtime geometry');
  check(/state\.visualNow/.test(grimeDrawSource) && !/performance\.now\s*\(/.test(grimeDrawSource),
    'secondary grime loops must consume state.visualNow without a second clock');
  const groundBody = extractFunction(sources['src/render/tiles.js'], 'drawGroundTile');
  check(/tileCoordHash\s*\(\s*Math\.floor\(x\s*\/\s*TILE\)\s*,\s*Math\.floor\(y\s*\/\s*TILE\)/.test(groundBody),
    'drawGroundTile must feed integer tile coordinates through tileCoordHash');
  check(!/\(x\s*\*\s*73\s*\^\s*y\s*\*\s*131\)/.test(groundBody),
    'drawGroundTile may not restore the world-pixel-multiple seam hash');
  const selectorBody = extractFunction(sources['src/render/sprites.js'], 'selectSpriteVariantKind');
  check(Boolean(selectorBody) && /identity/.test(selectorBody) && /base/.test(selectorBody),
    'variant selector must hash persistent identity together with sprite base');
  check(!/(?:Math\.random|performance\.now|state\.|window\.storage|localStorage|sessionStorage)/.test(selectorBody),
    'variant selector must remain position/time/random/save independent');
}

function validateGameplayExclusion(sources, cells, dataProps, world) {
  const allowed = new Set(['src/render/tiles.js', 'src/render/frame.js']);
  for (const [relative, source] of Object.entries(sources)) {
    if (relative === 'index.html' || allowed.has(relative)) continue;
    check(!/\b(?:GRIME_[A-Z_]+|drawFullMapGrime|buildGrimeLayout|grimeLoopFrameIndex)\b/.test(stripComments(source)),
      `${relative}: Phase 2 grime may not leak outside the visual render layer`);
  }
  const tileSource = stripComments(sources['src/render/tiles.js']);
  check(!/(?:window\.storage|localStorage|sessionStorage|saveGame|loadGame|cash|reward|collision|interact)/i.test(tileSource),
    'tile grime implementation may not touch storage, economy, collision, or interaction systems');
  const props = new Set([...(dataProps.PROPS || []), ...(dataProps.interactiveProps || [])]);
  const decor = new Set(world.WORLD_DECOR || []);
  for (const cell of cells || []) {
    check(!props.has(cell) && !decor.has(cell), 'grime cells must not be registered as props or world decor');
    for (const stamp of cell.statics || []) check(!props.has(stamp) && !decor.has(stamp),
      'grime stamps must remain absent from gameplay/world-decor registries');
    if (cell.loop) check(!props.has(cell.loop) && !decor.has(cell.loop), 'grime loops must remain absent from gameplay registries');
  }
}

function validateLoopGrammar(tiles, cells) {
  check(typeof tiles.grimeLoopFrameIndex === 'function', 'grimeLoopFrameIndex export is required');
  if (typeof tiles.grimeLoopFrameIndex !== 'function') return;
  for (const [family, count] of Object.entries(EXPECTED_LOOP_FRAME_COUNTS)) {
    const interval = tiles.GRIME_LOOP_INTERVALS?.[family];
    check(Number.isInteger(interval) && interval > 0, `${family}: loop interval must be a positive integer`);
    const phase = 0;
    const atZero = tiles.grimeLoopFrameIndex(family, phase, 0);
    check(atZero === tiles.grimeLoopFrameIndex(family, phase, 0), `${family}: fixed time must repeat exactly`);
    check(tiles.grimeLoopFrameIndex(family, phase, interval) === (atZero + 1) % count,
      `${family}: advancing one interval must advance one frame`);
    check(tiles.grimeLoopFrameIndex(family, phase, interval * count) === atZero,
      `${family}: advancing one full period must return to the starting frame`);
    check(tiles.grimeLoopFrameIndex(family, 1, 0) === (atZero + 1) % count,
      `${family}: placement phase must offset the visible frame`);
    check((cells || []).some(cell => cell.loop?.family === family), `${family}: runtime loop needs a layout witness`);
  }
}

function validateDeterminism(tiles, context, poisonedDigest = '') {
  check(typeof tiles.buildGrimeLayout === 'function', 'buildGrimeLayout export is required for deterministic audit');
  if (typeof tiles.buildGrimeLayout !== 'function') return;
  const originalRandom = context.Math.random;
  context.Math.random = () => { throw new Error('Math.random reached deterministic Phase 2 layout'); };
  let first, second;
  try {
    first = tiles.buildGrimeLayout();
    second = tiles.buildGrimeLayout();
  } catch (error) {
    fail(`full-map grime layout must build without Math.random: ${error.message}`);
  } finally {
    context.Math.random = originalRandom;
  }
  if (!first || !second) return;
  const firstDigest = hashValue(first.cells), secondDigest = poisonedDigest || hashValue(second.cells);
  check(firstDigest === secondDigest, `full-map grime placement must repeat byte-for-byte (${firstDigest} != ${secondDigest})`);
  check(first.metadata.layoutHash === second.metadata.layoutHash, 'deterministic layout metadata hash must repeat exactly');
}

function validateTileSeam(tiles, suppliedOffsets = null) {
  check(typeof tiles.tileCoordHash === 'function', 'tileCoordHash export is required');
  if (typeof tiles.tileCoordHash !== 'function') return;
  const offsets = suppliedOffsets || [];
  if (!suppliedOffsets) {
    for (let row = 0; row < 64; row += 1) for (let col = 0; col < 64; col += 1) {
      offsets.push(tiles.tileCoordHash(col, row, 0x51ed270b) & 63);
    }
  }
  const residues = new Set(offsets);
  check(residues.size === 64 && Math.min(...residues) === 0 && Math.max(...residues) === 63,
    'tile coordinate hash must spread samples across every 0-63 offset');
  const pinSample = [];
  for (let row = -4; row < 12; row += 1) for (let col = -4; col < 12; col += 1) {
    pinSample.push(tiles.tileCoordHash(col, row, 0x51ed270b) >>> 0);
  }
  const digest = hashValue(pinSample);
  check(Boolean(EXPECTED_TILE_SEAM_HASH), `tile seam hash pin is unset; ratify ${digest} after auditing the coordinate avalanche`);
  if (EXPECTED_TILE_SEAM_HASH) check(digest === EXPECTED_TILE_SEAM_HASH, `tile coordinate hash drifted (${digest})`);
  for (const [x, y, salt] of [[0, 0, 0], [17, 29, 3], [-4, 8, 99]]) {
    const first = tiles.tileCoordHash(x, y, salt), second = tiles.tileCoordHash(x, y, salt);
    check(Number.isInteger(first) && first >= 0 && first <= 0xffffffff && first === second,
      `tileCoordHash(${x},${y},${salt}) must return a stable uint32`);
  }
}

function grimeCanvasLabels(tiles) {
  const labels = new Map();
  for (const [family, canvas] of Object.entries(tiles.GRIME_STATIC_CACHE || {})) {
    labels.set(canvas, Object.freeze({ kind: 'static', family, frame: 0 }));
  }
  for (const [family, frames] of Object.entries(tiles.GRIME_LOOP_CACHE || {})) {
    for (const [frame, canvas] of frames.entries()) labels.set(canvas, Object.freeze({ kind: 'loop', family, frame }));
  }
  return labels;
}

function captureGrimeDraw(tiles, core, context, labels, camX, camY, visualNow) {
  core.state.cam.x = camX;
  core.state.cam.y = camY;
  core.state.visualNow = visualNow;
  const context2d = context.__qa.context2d;
  const originalDrawImage = context2d.drawImage;
  const trace = [];
  context2d.drawImage = function capture(image, x, y, ...rest) {
    const label = labels.get(image);
    if (label) trace.push({ ...label, x, y, args: rest.length + 3 });
  };
  let returned;
  try {
    returned = tiles.drawFullMapGrime();
  } catch (error) {
    fail(`drawFullMapGrime threw at camera ${camX},${camY}: ${error.message}`);
  } finally {
    context2d.drawImage = originalDrawImage;
  }
  return { trace, returned };
}

function validateTrace(trace, returned, tiles, camX, camY, { expectedCount = null } = {}) {
  const left = camX - 32, top = camY - 32, right = camX + 800 + 32, bottom = camY + 600 + 32;
  check(returned === trace.length, `drawFullMapGrime return count must equal observed cached draws at ${camX},${camY}`);
  if (expectedCount != null) check(trace.length === expectedCount,
    `observed grime draws must match bounded counter at ${camX},${camY}`);
  check(trace.length <= 90, `normal 800x600 viewport may draw at most 90 Phase 2 images (observed ${trace.length})`);
  check(trace.every(draw => draw.kind === 'static' || draw.kind === 'loop'), 'drawFullMapGrime must draw only registered Phase 2 cache canvases');
  check(trace.every(draw => Number.isInteger(draw.x) && Number.isInteger(draw.y)), 'Phase 2 draw coordinates must remain integer pixel positions');
  check(trace.every(draw => draw.x < right && draw.x + 32 > left && draw.y < bottom && draw.y + 32 > top),
    `drawFullMapGrime emitted an offscreen record outside the camera margin at ${camX},${camY}`);
  const firstLoop = trace.findIndex(draw => draw.kind === 'loop');
  check(firstLoop < 0 || trace.slice(firstLoop).every(draw => draw.kind === 'loop'),
    'all static grime must draw before every secondary loop frame');
}

function validateRuntimeDraw(tiles, core, context, dataProps, world, redTraceMode = '') {
  check(typeof tiles.drawFullMapGrime === 'function', 'drawFullMapGrime runtime export is required');
  check(typeof tiles.grimeVisibleDrawCount === 'function', 'grimeVisibleDrawCount runtime export is required');
  if (typeof tiles.drawFullMapGrime !== 'function' || typeof tiles.grimeVisibleDrawCount !== 'function') return;
  const labels = grimeCanvasLabels(tiles);
  const originalRandom = context.Math.random;
  context.Math.random = () => { throw new Error('Math.random reached Phase 2 draw path'); };
  const playerBefore = canonical(core.P);
  const comparableState = () => {
    const value = clone(core.state);
    delete value.cam;
    delete value.visualNow;
    return value;
  };
  const stateBefore = canonical(comparableState());
  const propsBefore = canonical(dataProps.PROPS);
  const interactiveBefore = canonical(dataProps.interactiveProps);
  const decorBefore = canonical(world.WORLD_DECOR);
  let worst = { count: -1, x: 0, y: 0 };
  try {
    const cameras = [
      [0, 0], [7800, 5000], [3900, 2500], [800, 600], [7200, 4800],
    ];
    for (let row = 0; row < 30; row += 1) for (let col = 0; col < 45; col += 1) {
      cameras.push([Math.min(7800, col * 192), Math.min(5000, row * 192)]);
    }
    for (const [camX, camY] of cameras) {
      const capture = captureGrimeDraw(tiles, core, context, labels, camX, camY, 123456);
      const expected = tiles.grimeVisibleDrawCount(camX, camY);
      if (capture.trace.length > worst.count) worst = { count: capture.trace.length, x: camX, y: camY };
      // Aggregate the common checks to keep a failing gate readable while still sweeping every cell origin.
      if (capture.returned !== capture.trace.length || capture.trace.length !== expected || capture.trace.length > 90 ||
          capture.trace.some(draw => draw.x >= camX + 832 || draw.x + 32 <= camX - 32 ||
            draw.y >= camY + 632 || draw.y + 32 <= camY - 32)) {
        validateTrace(capture.trace, capture.returned, tiles, camX, camY, { expectedCount: expected });
      }
    }
    let sample = captureGrimeDraw(tiles, core, context, labels, worst.x, worst.y, 123456);
    const repeat = captureGrimeDraw(tiles, core, context, labels, worst.x, worst.y, 123456);
    check(canonical(sample.trace) === canonical(repeat.trace), 'fixed camera/time draw trace must repeat exactly');
    if (redTraceMode === 'unculled-draw') {
      sample.trace.push({ kind: 'static', family: 'trash_cluster', frame: 0, x: worst.x + 900, y: worst.y, args: 3 });
      sample.returned += 1;
      markPoison(sample.trace.at(-1).x >= worst.x + 832, 'offscreen trace record was not injected');
    } else if (redTraceMode === 'visible-budget') {
      while (sample.trace.length <= 90) sample.trace.push({
        kind: 'static', family: 'trash_cluster', frame: 0, x: worst.x, y: worst.y, args: 3,
      });
      sample.returned = sample.trace.length;
      markPoison(sample.trace.length > 90, 'over-budget trace was not injected');
    }
    validateTrace(sample.trace, sample.returned, tiles, worst.x, worst.y,
      { expectedCount: redTraceMode ? null : tiles.grimeVisibleDrawCount(worst.x, worst.y) });
  } finally {
    context.Math.random = originalRandom;
  }
  check(canonical(core.P) === playerBefore, 'Phase 2 rendering may not mutate player state');
  // Ignore camera/time values deliberately set by the harness; compare all other state.
  check(canonical(comparableState()) === stateBefore, 'Phase 2 rendering may not mutate gameplay state');
  check(canonical(dataProps.PROPS) === propsBefore && canonical(dataProps.interactiveProps) === interactiveBefore,
    'Phase 2 rendering may not mutate prop registries');
  check(canonical(world.WORLD_DECOR) === decorBefore, 'Phase 2 rendering may not mutate world decor');
  check(worst.count <= 90, `swept maximum Phase 2 viewport count must remain <=90 (observed ${worst.count})`);
}

function collectSources() {
  const result = { 'index.html': read('index.html') };
  const visit = directory => {
    for (const entry of fs.readdirSync(path.join(ROOT, directory), { withFileTypes: true })) {
      const relative = path.posix.join(directory.replaceAll('\\', '/'), entry.name);
      if (entry.isDirectory()) visit(relative);
      else if (entry.isFile() && entry.name.endsWith('.js')) result[relative] = read(relative);
    }
  };
  visit('src');
  return result;
}

function frozenCellReplacement(cells, index, changes) {
  const copy = cells.slice();
  copy[index] = Object.freeze({ ...copy[index], ...changes });
  return Object.freeze(copy);
}

const EXPECTED_RED_DIAGNOSTIC = Object.freeze({
  'sprite-topology': /topology corpus drifted/i,
  'character-palette': /pure white|palette-use corpus/i,
  'dither-third-index': /gridDither.*(?:exactly|only)/i,
  'duplicate-variant': /mutually distinct/i,
  'variant-topology': /preserve.*topology/i,
  'variant-blue': /bright blue/i,
  'missing-cell': /1350 cells/i,
  'cell-density': /2-3 static/i,
  'stamp-overlap': /must not overlap/i,
  'missing-static-family': /exact twelve-family/i,
  'missing-loop-family': /exact six-family/i,
  'bad-loop-frame-count': /loop frame counts/i,
  'frozen-loop': /distinct canvas objects/i,
  'synchronized-loop': /unsynchronized phases/i,
  'nondeterministic-layout': /repeat byte-for-byte/i,
  'unculled-draw': /offscreen record/i,
  'visible-budget': /at most 90/i,
  'runtime-raster': /hot path may not use rasterize/i,
  'render-order': /immediately after drawWorldFabric|render stack/i,
  'gameplay-leak': /leaked a gameplay field/i,
  'tile-seam': /every 0-63 offset/i,
});

async function main() {
  if (RED_CASE && !RED_CASES.has(RED_CASE)) fail(`unknown --red mode: ${RED_CASE}`);
  const sources = collectSources();
  let runtime;
  try {
    const { loadModularGame } = await import('./runtime-harness.mjs');
    runtime = await loadModularGame();
  } catch (error) {
    fail(`modular game failed to load: ${error.stack || error.message}`);
  }
  if (!runtime) {
    console.error('PHASE 2 GRAPHICS GATE: FAIL');
    for (const failure of failures) console.error(`  - ${failure}`);
    process.exit(1);
  }

  const sprites = runtime.module('src/render/sprites.js');
  const manifest = runtime.module('src/render/sprite_manifest.js');
  const geography = runtime.module('src/render/canvas_geography.js');
  const toolkit = runtime.module('src/render/sprite_toolkit.js');
  const tiles = runtime.module('src/render/tiles.js');
  const core = runtime.module('src/core/runtime_ui.js');
  const dataProps = runtime.module('src/data/props.js');
  const world = runtime.module('src/data/world.js');

  let normalFixture = {
    sizes: manifest.SPRITE_BASE_SIZES,
    keyBases: sprites.SPRITE_KEY_BASES,
    cache: sprites.SPRITE_CACHE,
    pixelCounts: sprites.SPRITE_PIXEL_COUNTS,
    palettes: sprites.SPRITE_KEY_PALETTES,
    topology: sprites.SPRITE_GRID_TOPOLOGY,
    gridStats: sprites.SPRITE_GRID_STATS,
    envCache: geography.ENV_SPRITE_CACHE,
    envPalettes: geography.ENV_SPRITE_PALETTES,
  };
  if (RED_CASE === 'sprite-topology') {
    const topology = { ...normalFixture.topology };
    const key = Object.keys(topology).sort()[0];
    topology[key] = `${topology[key][0] === '0' ? '1' : '0'}${topology[key].slice(1)}`;
    normalFixture = { ...normalFixture, topology: Object.freeze(topology) };
    markPoison(normalFixture.topology[key] !== sprites.SPRITE_GRID_TOPOLOGY[key], 'normal topology signature was not changed');
  } else if (RED_CASE === 'character-palette') {
    const palettes = { ...normalFixture.palettes };
    const key = own(palettes, 'player_down_0') ? 'player_down_0' : Object.keys(palettes)[0];
    palettes[key] = [...palettes[key]];
    palettes[key][1] = '#fff';
    normalFixture = { ...normalFixture, palettes };
    markPoison(normalFixture.palettes[key][1] === '#fff', 'pure-white character palette poison was not applied');
  }
  validateNormalSprites(normalFixture);
  validateDrawSites(sources);
  validatePhaseOneAuthority(sprites, sources);

  const ditherProbe = [[0, 0], [0, 0]];
  try { toolkit.gridDither(ditherProbe, 0, 0, 2, 2, 2, 3); }
  catch (error) { fail(`gridDither production probe threw: ${error.message}`); }
  if (RED_CASE === 'dither-third-index') {
    ditherProbe[0][0] = 7;
    markPoison(new Set(ditherProbe.flat()).size === 3, 'third-index dither poison was not applied');
  }
  validateDither(toolkit, sources, ditherProbe);

  let variantFixture = {
    kinds: sprites.SPRITE_VARIANT_KINDS,
    eligibleBases: sprites.SPRITE_VARIANT_ELIGIBLE_BASES,
    palettes: sprites.SPRITE_VARIANT_PALETTES,
    cache: sprites.SPRITE_VARIANT_CACHE,
    topology: sprites.SPRITE_VARIANT_TOPOLOGY,
    stats: sprites.SPRITE_VARIANT_STATS,
  };
  if (RED_CASE === 'duplicate-variant') {
    const base = EXPECTED_VARIANT_BASES[0], first = EXPECTED_VARIANT_KINDS[0], second = EXPECTED_VARIANT_KINDS[1];
    variantFixture = { ...variantFixture, palettes: Object.freeze({
      ...variantFixture.palettes,
      [base]: Object.freeze({ ...variantFixture.palettes[base], [second]: variantFixture.palettes[base][first] }),
    }) };
    markPoison(variantFixture.palettes[base][first] === variantFixture.palettes[base][second], 'duplicate variant palette was not injected');
  } else if (RED_CASE === 'variant-topology') {
    variantFixture = { ...variantFixture, stats: Object.freeze({ ...variantFixture.stats, topologyMismatches: 1 }) };
    markPoison(variantFixture.stats.topologyMismatches === 1, 'variant topology mismatch was not injected');
  } else if (RED_CASE === 'variant-blue') {
    const base = EXPECTED_VARIANT_BASES.find(candidate => !AUTHORITY_BLUE_BASES.has(candidate));
    const kind = EXPECTED_VARIANT_KINDS[0];
    const palette = [...variantFixture.palettes[base][kind]];
    palette[1] = '#0000ff';
    variantFixture = { ...variantFixture, palettes: Object.freeze({
      ...variantFixture.palettes,
      [base]: Object.freeze({ ...variantFixture.palettes[base], [kind]: Object.freeze(palette) }),
    }) };
    markPoison(variantFixture.palettes[base][kind][1] === '#0000ff', 'non-authority bright-blue variant poison was not injected');
  }
  validateVariants(variantFixture, sprites);

  let grimeArtFixture = {
    staticFamilies: tiles.GRIME_STATIC_FAMILIES,
    loopFamilies: tiles.GRIME_LOOP_FAMILIES,
    frameCounts: tiles.GRIME_LOOP_FRAME_COUNTS,
    staticArt: tiles.GRIME_STATIC_ART,
    loopArt: tiles.GRIME_LOOP_ART,
    staticCache: tiles.GRIME_STATIC_CACHE,
    loopCache: tiles.GRIME_LOOP_CACHE,
    metadata: tiles.GRIME_ART_METADATA,
  };
  if (RED_CASE === 'missing-static-family') {
    grimeArtFixture = { ...grimeArtFixture, staticFamilies: Object.freeze(grimeArtFixture.staticFamilies.slice(1)) };
    markPoison(grimeArtFixture.staticFamilies.length === 11, 'static-family removal was not applied');
  } else if (RED_CASE === 'missing-loop-family') {
    grimeArtFixture = { ...grimeArtFixture, loopFamilies: Object.freeze(grimeArtFixture.loopFamilies.slice(1)) };
    markPoison(grimeArtFixture.loopFamilies.length === 5, 'loop-family removal was not applied');
  } else if (RED_CASE === 'bad-loop-frame-count') {
    grimeArtFixture = { ...grimeArtFixture, frameCounts: Object.freeze({ ...grimeArtFixture.frameCounts, flies: 2 }) };
    markPoison(grimeArtFixture.frameCounts.flies !== EXPECTED_LOOP_FRAME_COUNTS.flies, 'loop frame-count poison was not applied');
  } else if (RED_CASE === 'frozen-loop') {
    const frames = [...grimeArtFixture.loopCache.flies];
    frames[1] = frames[0];
    grimeArtFixture = { ...grimeArtFixture, loopCache: Object.freeze({
      ...grimeArtFixture.loopCache, flies: Object.freeze(frames),
    }) };
    markPoison(new Set(grimeArtFixture.loopCache.flies).size < grimeArtFixture.loopCache.flies.length,
      'duplicate cached loop frame was not applied');
  }
  validateGrimeArt(tiles, grimeArtFixture);

  let layoutCells = tiles.GRIME_CELLS;
  if (RED_CASE === 'missing-cell') {
    layoutCells = Object.freeze(layoutCells.slice(0, -1));
    markPoison(layoutCells.length === 1349, 'coverage cell was not removed');
  } else if (RED_CASE === 'cell-density') {
    layoutCells = frozenCellReplacement(layoutCells, 0, { statics: Object.freeze(layoutCells[0].statics.slice(0, 1)) });
    markPoison(layoutCells[0].statics.length === 1, 'cell density poison was not applied');
  } else if (RED_CASE === 'stamp-overlap') {
    const statics = [...layoutCells[0].statics];
    statics[1] = Object.freeze({ ...statics[1], x:statics[0].x, y:statics[0].y });
    layoutCells = frozenCellReplacement(layoutCells, 0, { statics:Object.freeze(statics) });
    markPoison(layoutCells[0].statics[0].x === layoutCells[0].statics[1].x &&
      layoutCells[0].statics[0].y === layoutCells[0].statics[1].y, 'stamp overlap poison was not applied');
  } else if (RED_CASE === 'synchronized-loop') {
    layoutCells = Object.freeze(layoutCells.map(cell => cell.loop
      ? Object.freeze({ ...cell, loop: Object.freeze({ ...cell.loop, phase: 0 }) }) : cell));
    markPoison(layoutCells.filter(cell => cell.loop).every(cell => cell.loop.phase === 0), 'loop phases were not synchronized');
  } else if (RED_CASE === 'gameplay-leak') {
    const statics = [...layoutCells[0].statics];
    statics[0] = Object.freeze({ ...statics[0], solid: true });
    layoutCells = frozenCellReplacement(layoutCells, 0, { statics: Object.freeze(statics) });
    markPoison(layoutCells[0].statics[0].solid === true, 'gameplay field was not injected into a grime stamp');
  }
  const layoutFixture = {
    cells: layoutCells,
    metadata: tiles.GRIME_LAYOUT_METADATA,
    staticFamilies: grimeArtFixture.staticFamilies,
    loopFamilies: grimeArtFixture.loopFamilies,
    frameCounts: grimeArtFixture.frameCounts,
  };
  validateGrimeLayout(tiles, layoutFixture, world);
  validateLoopGrammar(tiles, layoutCells);
  validateGameplayExclusion(sources, layoutCells, dataProps, world);

  const deterministicPoison = RED_CASE === 'nondeterministic-layout' ? 'intentional-layout-drift' : '';
  if (RED_CASE === 'nondeterministic-layout') markPoison(Boolean(deterministicPoison), 'deterministic digest poison was not applied');
  validateDeterminism(tiles, runtime.context, deterministicPoison);

  let frameOrderSource = sources['src/render/frame.js'];
  if (RED_CASE === 'render-order') {
    frameOrderSource = frameOrderSource.replace(/\s*drawFullMapGrime\(\);/, '')
      .replace('drawProps();', 'drawProps();\n  drawFullMapGrime();');
    markPoison(frameOrderSource.indexOf('drawFullMapGrime()') > frameOrderSource.indexOf('drawProps()'),
      'render-order poison was not applied');
  }
  let grimeDrawSource = extractFunction(sources['src/render/tiles.js'], 'drawFullMapGrime');
  if (RED_CASE === 'runtime-raster') {
    grimeDrawSource += '\nrasterize([], []);';
    markPoison(/rasterize\s*\(/.test(grimeDrawSource), 'runtime raster poison was not applied');
  }
  validateSourceContracts(sources, frameOrderSource, grimeDrawSource);

  let seamOffsets = null;
  if (RED_CASE === 'tile-seam') {
    seamOffsets = Array(4096).fill(0);
    markPoison(new Set(seamOffsets).size === 1, 'tile seam poison was not applied');
  }
  validateTileSeam(tiles, seamOffsets);
  validateRuntimeDraw(tiles, core, runtime.context, dataProps, world,
    RED_CASE === 'unculled-draw' || RED_CASE === 'visible-budget' ? RED_CASE : '');

  if (RED_CASE) {
    const expected = EXPECTED_RED_DIAGNOSTIC[RED_CASE];
    if (!poisonLanded) fail(`[intentional red ${RED_CASE}] poison was never applied`);
    if (!failures.some(message => expected?.test(message))) {
      fail(`[intentional red ${RED_CASE}] expected diagnostic ${expected} was not observed`);
    }
    if (!failures.length) fail(`[intentional red ${RED_CASE}] gate unexpectedly passed`);
    console.error(`PHASE 2 GRAPHICS GATE: INTENTIONAL RED (${RED_CASE})`);
    for (const failure of failures) console.error(`  - ${failure}`);
    process.exit(1);
  }

  if (failures.length) {
    console.error('PHASE 2 GRAPHICS GATE: FAIL');
    for (const failure of failures) console.error(`  - ${failure}`);
    process.exit(1);
  }
  console.log(`PHASE 2 GRAPHICS GATE: PASS (${checks} checks; 94 bases / 377 normal keys / 465 variants; 1350 cells / 3017 statics / 6 loop families; <=90 visible draws)`);
  console.log('  structural/runtime gate only: before/after visual acceptance remains the operator eye');
}

main().catch(error => {
  console.error('PHASE 2 GRAPHICS GATE: FAIL');
  console.error(`  - unhandled gate error: ${error.stack || error.message}`);
  process.exit(1);
});
