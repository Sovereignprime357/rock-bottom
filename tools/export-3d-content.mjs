import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Data interchange only. Callbacks are named in omissions, never converted to code.
export const ROOT = path.resolve(import.meta.dirname, '..');
export const OUTPUT = path.join(ROOT, 'game3d/data/source_content.json');
export const FIXED_EPOCH_MS = 1763424000000;
export const SOURCE_SEED = '0x19c0ffee';
const OMIT = Symbol('omitted');

export const ACTOR_ALIASES = Object.freeze({
  'BRUTUS (SKID)': 'BRUTUS',
  'LURCH (SKID)': 'LURCH',
  'SHERRI (SKID)': 'SPIDER-BITE SHERRI',
  "FATHER O'MALLEY (FALLEN)": "FATHER O'MALLEY",
});
export const GENERATED_FAMILIES = Object.freeze([
  { canonical: 'CURB PRETENDER No. N', pattern: '^CURB PRETENDER No\\. [1-9]\\d*$' },
]);

// Explicit exclusions are checked against actual exports: deletion/renaming fails.
// All other non-function exports are retained automatically, including render palettes.
export const EXCLUDED_EXPORTS = Object.freeze({
  'src/core/audio_save.js': { audio: 'audio graph and synthesized sound methods' },
  'src/core/runtime_ui.js': {
    P: 'relocated to initial.player', state: 'relocated to initial.state',
    runtime: 'relocated npcs to actors.day1; cashPiles/projectiles to initial',
    particles: 'presentation particle buffer', activeDialogue: 'live dialogue session',
    dialogueEl: 'DOM element', panelEl: 'DOM element', toastEl: 'DOM element',
    toastTimer: 'host timer handle',
  },
  'src/core/update.js': { last: 'presentation animation timestamp' },
  'src/input/keyboard.js': {
    INPUT_RELEASE_HOOKS: 'registered host input callbacks', titleLoadPending: 'title UI session',
  },
  'src/input/mobile.js': { loadBtnEl: 'DOM element' },
  'src/render/sprites.js': {
    SPRITE_CACHE: 'prerendered canvas resources', SPRITE_EMISSIVE_CACHE: 'prerendered canvas resources',
  },
  'src/render/canvas_geography.js': {
    cv: 'canvas element', ctx: 'canvas rendering context', ENV_SPRITE_CACHE: 'prerendered canvas resources',
  },
  'src/render/landmarks_a.js': {
    ACTIVE_LIGHTS: 'presentation light frame buffer', CONTACT_SHADOW_SHEET: 'canvas resource',
    FOG_SHEET: 'canvas resource', LANDMARK_CACHE: 'prerendered canvas resources',
    LIGHT_CTX: 'canvas rendering context', LIGHT_FRAME_SHAKE_X: 'presentation frame offset',
    LIGHT_FRAME_SHAKE_Y: 'presentation frame offset', LIGHT_GLOW_CACHE: 'prerendered canvas resources',
    LIGHT_HOLE: 'canvas resource', LIGHT_MASK: 'canvas resource', landmarkCacheReady: 'canvas cache status',
  },
  'src/render/actors_weather.js': {
    NAMEPLATE_BOX_BUFFER: 'presentation frame buffer', VISIBLE_NPC_BUFFER: 'presentation frame buffer',
  },
  'src/render/minimap.js': { mm: 'canvas element', mmctx: 'canvas rendering context' },
});

const slash = value => value.replaceAll('\\', '/');
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const childPath = (base, key) => `${base}[${JSON.stringify(String(key))}]`;

export function sourceFiles(dir = path.join(ROOT, 'src')) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? sourceFiles(full) : [full];
  }).sort();
}

export function stableStringify(value) {
  const sort = item => {
    if (Array.isArray(item)) return item.map(sort);
    if (item && typeof item === 'object') return Object.fromEntries(
      Object.keys(item).sort().map(key => [key, sort(item[key])]),
    );
    return item;
  };
  return JSON.stringify(sort(value), null, 2) + '\n';
}

export function parseRegistry() {
  const lines = fs.readFileSync(path.join(ROOT, 'VIBE.md'), 'utf8').split(/\r?\n/);
  const start = lines.findIndex(line => line.trim() === '| Name | Tic | Relationship | Transaction/Threat |');
  if (start < 0) throw new Error('VIBE identity registry header missing');
  const rows = [];
  for (let i = start + 2; i < lines.length && lines[i].trim().startsWith('|'); i++) {
    const cells = lines[i].trim().split('|').slice(1, -1).map(cell => cell.trim());
    if (cells.length !== 4 || cells.some(cell => !cell)) throw new Error(`Invalid VIBE identity row ${i + 1}`);
    const [name, tic, relationship, transaction] = cells;
    if (rows.some(row => row.name === name)) throw new Error(`Duplicate VIBE identity ${name}`);
    rows.push({ name, tic, relationship, transaction });
  }
  return rows;
}

export function makeSerializer(omissions) {
  const active = new WeakSet();
  const omit = (at, reason, details = {}) => {
    omissions.push({ path: at, reason, ...details });
    return OMIT;
  };
  function encode(value, at) {
    if (value === undefined) return omit(at, 'undefined');
    if (typeof value === 'function') return omit(at, 'function', { name: value.name || '(anonymous)' });
    if (typeof value === 'number') {
      if (!Number.isFinite(value)) throw new Error(`Non-finite source number at ${at}`);
      return value;
    }
    if (value === null || typeof value === 'string' || typeof value === 'boolean') return value;
    if (typeof value !== 'object') throw new Error(`Unsupported ${typeof value} at ${at}`);
    if (active.has(value)) throw new Error(`Cyclic source object at ${at}`);
    const tag = Object.prototype.toString.call(value);
    if (tag === '[object Promise]') return omit(at, 'runtime_resource', { detail: 'Promise' });
    // Reject unexpected host resources rather than silently walking mock DOM objects.
    if (typeof value.getContext === 'function' || typeof value.appendChild === 'function'
      || typeof value.createGain === 'function' || typeof value.drawImage === 'function') {
      throw new Error(`Unclassified host resource at ${at}`);
    }
    active.add(value);
    let result;
    if (tag === '[object Set]') {
      result = { $type: 'Set', values: Array.from(value, (entry, i) => {
        const encoded = encode(entry, `${at}.values[${i}]`);
        return encoded === OMIT ? null : encoded;
      }) };
    } else if (tag === '[object Map]') {
      result = { $type: 'Map', entries: Array.from(value, ([key, entry], i) => {
        const a = encode(key, `${at}.entries[${i}][0]`);
        const b = encode(entry, `${at}.entries[${i}][1]`);
        return [a === OMIT ? null : a, b === OMIT ? null : b];
      }) };
    } else if (Array.isArray(value)) {
      result = Array.from(value, (entry, i) => {
        const encoded = encode(entry, `${at}[${i}]`);
        return encoded === OMIT ? null : encoded;
      });
    } else if (tag === '[object Object]') {
      result = {};
      for (const key of Object.keys(value).sort()) {
        const atChild = childPath(at, key);
        if (at === 'initial.state' && key === 'endingSavePromise') {
          omit(atChild, 'runtime_resource', { detail: 'session persistence Promise slot' });
          continue;
        }
        const encoded = encode(value[key], atChild);
        if (encoded !== OMIT) Object.defineProperty(result, key, { value: encoded, enumerable: true, configurable: true });
      }
    } else {
      throw new Error(`Unsupported source object ${tag} at ${at}`);
    }
    active.delete(value);
    return result;
  }
  return encode;
}

// Bounded, non-executing extraction for inline inventory/loot records. Source has
// no central item table. Only quoted strings/numbers/booleans/null are read;
// expressions are recorded as mapping debt, never evaluated or copied as code.
function quotedLiteral(text, start = 0) {
  const quote = text[start];
  if (quote !== "'" && quote !== '"') throw new Error('Expected quoted literal');
  let value = '';
  for (let i = start + 1; i < text.length; i++) {
    const ch = text[i];
    if (ch === quote) return { value, end: i + 1 };
    if (ch !== '\\') { value += ch; continue; }
    const escaped = text[++i];
    const simple = { n: '\n', r: '\r', t: '\t', b: '\b', f: '\f', v: '\v', '0': '\0' };
    if (own(simple, escaped)) value += simple[escaped];
    else if (escaped === 'u' || escaped === 'x') {
      const width = escaped === 'u' ? 4 : 2, hex = text.slice(i + 1, i + 1 + width);
      if (!new RegExp(`^[0-9a-fA-F]{${width}}$`).test(hex)) throw new Error('Unsupported literal escape');
      value += String.fromCharCode(parseInt(hex, 16)); i += width;
    } else if (escaped === '\n') { /* JS line continuation */ }
    else if (escaped === '\r') { if (text[i + 1] === '\n') i++; }
    else value += escaped;
  }
  throw new Error('Unterminated source string literal');
}

function objectLiteralAt(source, start) {
  if (source[start] !== '{') throw new Error('Expected object literal');
  let depth = 0;
  for (let i = start; i < source.length; i++) {
    if (source[i] === "'" || source[i] === '"') { i = quotedLiteral(source, i).end - 1; continue; }
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return { text: source.slice(start, i + 1), end: i + 1 };
  }
  throw new Error('Unterminated source object literal');
}

function parseFlatLiteral(text) {
  const body = text.slice(1, -1), fields = [], data = {}, computed = [];
  let start = 0, depth = 0;
  for (let i = 0; i <= body.length; i++) {
    if (body[i] === "'" || body[i] === '"') { i = quotedLiteral(body, i).end - 1; continue; }
    if ('([{'.includes(body[i] || '\0')) depth++;
    if (')]}'.includes(body[i] || '\0')) depth--;
    if ((body[i] === ',' && depth === 0) || i === body.length) {
      const field = body.slice(start, i).trim(); if (field) fields.push(field); start = i + 1;
    }
  }
  for (const field of fields) {
    const match = /^([A-Za-z_$][\w$]*)\s*:\s*([\s\S]+)$/.exec(field);
    if (!match) throw new Error(`Unclassified item declaration field: ${field.slice(0, 60)}`);
    const [, key, expression] = match;
    let value;
    if (expression[0] === "'" || expression[0] === '"') {
      const literal = quotedLiteral(expression);
      if (literal.end === expression.length) value = literal.value; else { computed.push(key); continue; }
    } else if (/^-?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(expression)) value = Number(expression);
    else if (expression === 'true' || expression === 'false') value = expression === 'true';
    else if (expression === 'null') value = null;
    else { computed.push(key); continue; }
    if (own(data, key)) throw new Error(`Duplicate item declaration key ${key}`);
    data[key] = value;
  }
  return { data, computed };
}

export function extractItemData(omissions) {
  const records = new Map(), loot = [], declarations = [];
  function record(data, source, generated = null) {
    if (typeof data.id !== 'string' || typeof data.n !== 'string') return;
    const key = stableStringify(data);
    if (!records.has(key)) records.set(key, { ...data, derived: true, sources: [] });
    const item = records.get(key); item.sources.push(source);
    if (generated) item.derivation = generated;
  }
  function read(file, text, start, kind) {
    const literal = objectLiteralAt(text, start), parsed = parseFlatLiteral(literal.text);
    const source = { file, line: text.slice(0, start).split(/\r?\n/).length, kind };
    declarations.push({ ...source, fields: Object.keys(parsed.data).sort(), computed: parsed.computed });
    for (const field of parsed.computed) omissions.push({
      path: `catalogs.items.source[${JSON.stringify(file)}][${source.line}][${JSON.stringify(field)}]`,
      reason: 'computed_item_data', detail: 'nonliteral source field; gameplay handler must supply value', source,
    });
    return { ...parsed, source, end: literal.end };
  }
  for (const full of sourceFiles().filter(file => file.endsWith('.js'))) {
    const file = slash(path.relative(ROOT, full)), text = fs.readFileSync(full, 'utf8');
    const pushPattern = /\b(?:P\.)?inventory\.push\s*\(\s*/g;
    for (const match of text.matchAll(pushPattern)) {
      const start = match.index + match[0].length;
      if (text[start] !== '{') throw new Error(`Unclassified inventory insertion: ${file}:${text.slice(0, start).split(/\r?\n/).length}`);
      const parsed = read(file, text, start, 'inventory_push');
      record(parsed.data, parsed.source);
    }
    // Site loot is already in definitions; this index retains every exact variant
    // and links it to the authoring line instead of guessing a single item name.
    if (file === 'src/data/props.js') {
      for (const match of text.matchAll(/\bitems\s*:\s*\[/g)) {
        let offset = match.index + match[0].length;
        while (offset < text.length) {
          while (/\s|,/.test(text[offset])) offset++;
          if (text[offset] === ']') break;
          if (text[offset] !== '{') throw new Error('Unclassified site loot item declaration');
          const parsed = read(file, text, offset, 'site_loot');
          record(parsed.data, parsed.source); offset = parsed.end;
        }
      }
    }
    if (file === 'src/systems/interactions.js') {
      const pool = /const\s+trashPool\s*=\s*\[/.exec(text);
      if (!pool) throw new Error('Source dumpster loot table missing');
      let offset = pool.index + pool[0].length;
      while (offset < text.length) {
        while (/\s|,/.test(text[offset])) offset++;
        if (text[offset] === ']') break;
        const parsed = read(file, text, offset, 'dumpster_pool');
        loot.push({ ...parsed.data, derived: true, sources: [parsed.source] });
        if (parsed.data.q === 'item') {
          if (typeof parsed.data.id === 'string') record(parsed.data, parsed.source);
          else if (typeof parsed.data.n === 'string') {
            // Exact source fallback at interactions.js: it.id || it.n.replace(/\W/g,'').
            const id = parsed.data.n.replace(/\W/g, '');
            record({ ...parsed.data, id }, parsed.source, { classification: 'generated_item_data',
              sourceField: 'n', pattern: '\\W', flags: 'g', replacement: '', result: id,
              ruleSource: 'src/systems/interactions.js: P.inventory.push dumpster item fallback' });
          }
        }
        offset = parsed.end;
      }
      for (const match of text.matchAll(/\blootPicked\s*=\s*(?=\{)/g)) {
        const parsed = read(file, text, match.index + match[0].length, 'dumpster_outcome');
        loot.push({ ...parsed.data, derived: true, sources: [parsed.source],
          ...(parsed.computed.length ? { omittedFields: parsed.computed } : {}) });
      }
    }
  }
  const items = [...records.values()].sort((a, b) => stableStringify(a).localeCompare(stableStringify(b), 'en'));
  return { items, loot, declarations };
}

export async function loadSeededSource() {
  if (typeof vm.SourceTextModule !== 'function') throw new Error('Use node --experimental-vm-modules');
  const { makeGameContext } = await import('./runtime-harness.mjs');
  const context = makeGameContext();
  // Install before any source evaluation, not merely before startGame: generated IDs
  // and module-initialization timestamps must have the same clock on every run.
  vm.runInContext(`{
    const NativeDate = Date;
    function FixedDate(...args) {
      if (!new.target) return new NativeDate(${FIXED_EPOCH_MS}).toString();
      return new NativeDate(...(args.length ? args : [${FIXED_EPOCH_MS}]));
    }
    Object.setPrototypeOf(FixedDate, NativeDate);
    FixedDate.prototype = NativeDate.prototype;
    FixedDate.now = () => ${FIXED_EPOCH_MS};
    globalThis.Date = FixedDate;
  }`, context);
  const cache = new Map();
  function getModule(file) {
    const full = path.resolve(file);
    if (cache.has(full)) return cache.get(full);
    const mod = new vm.SourceTextModule(fs.readFileSync(full, 'utf8'), { context, identifier: full });
    cache.set(full, mod);
    return mod;
  }
  const main = getModule(path.join(ROOT, 'src/main.js'));
  await main.link((specifier, parent) => {
    if (!specifier.startsWith('.')) throw new Error(`Unexpected source dependency ${specifier}`);
    const target = path.resolve(path.dirname(parent.identifier), specifier);
    if (!target.startsWith(path.join(ROOT, 'src') + path.sep)) throw new Error(`Source import escapes src: ${specifier}`);
    return getModule(target);
  });
  await main.evaluate();
  await Promise.resolve();
  const module = relative => {
    const found = cache.get(path.join(ROOT, ...relative.split('/')));
    if (!found) throw new Error(`Source module not loaded: ${relative}`);
    return found.namespace;
  };
  module('src/core/start.js').startGame(false);
  return { context, cache, module };
}

export async function buildContent() {
  const game = await loadSeededSource();
  const omissions = [], encode = makeSerializer(omissions), definitions = {}, exports = {};
  const runtime = game.module('src/core/runtime_ui.js');
  const initial = {
    player: encode(runtime.P, 'initial.player'), state: encode(runtime.state, 'initial.state'),
    cashPiles: encode(runtime.runtime.cashPiles, 'initial.cashPiles'),
    projectiles: encode(runtime.runtime.projectiles, 'initial.projectiles'),
  };
  const day1 = encode(runtime.runtime.npcs, 'actors.day1');
  const day1Npcs = runtime.runtime.npcs;
  game.module('src/data/npc_spawns.js').spawnNpcs();
  const base = encode(runtime.runtime.npcs, 'actors.base');
  runtime.runtime.npcs = day1Npcs;
  const modules = Array.from(game.cache, ([full, mod]) => [slash(path.relative(ROOT, full)), mod.namespace])
    .sort(([a], [b]) => a.localeCompare(b, 'en'));
  for (const [file, namespace] of modules) {
    definitions[file] = {};
    exports[file] = {};
    for (const name of Object.keys(EXCLUDED_EXPORTS[file] || {})) {
      if (!own(namespace, name)) throw new Error(`Stale exclusion ${file}:${name}`);
    }
    for (const name of Object.keys(namespace).sort()) {
      const at = childPath(childPath('definitions', file), name);
      if (own(EXCLUDED_EXPORTS[file] || {}, name)) {
        omissions.push({ path: at, reason: 'runtime_resource', detail: EXCLUDED_EXPORTS[file][name] });
        exports[file][name] = { kind: 'omitted', path: at };
      } else {
        const encoded = encode(namespace[name], at);
        if (encoded !== OMIT) definitions[file][name] = encoded;
        exports[file][name] = { kind: encoded === OMIT ? 'omitted' : 'data', path: at };
      }
    }
  }
  const def = (file, name) => {
    if (!own(definitions[file] || {}, name)) throw new Error(`Missing definition ${file}:${name}`);
    return definitions[file][name];
  };
  const worldFile = 'src/data/world.js', propsFile = 'src/data/props.js', catalogsFile = 'src/data/catalogs.js';
  const world = {
    bounds: def(worldFile, 'WORLD'), tile: def(worldFile, 'TILE'), zones: def(worldFile, 'ZONES'),
    terrainRegions: def(worldFile, 'TERRAIN_REGIONS'), roadSegments: def(worldFile, 'ROAD_SEGMENTS'),
    crosswalks: def(worldFile, 'CROSSWALKS'), groundPaths: def(worldFile, 'GROUND_PATHS'),
    railLines: def(worldFile, 'RAIL_LINES'), landmarkFacades: def(worldFile, 'LANDMARK_FACADES'),
    decor: def(worldFile, 'WORLD_DECOR'), utilityWires: def(worldFile, 'UTILITY_WIRES'),
    lights: def(worldFile, 'WORLD_LIGHTS'), ambientGrades: def(worldFile, 'AMBIENT_GRADES'),
    diegeticLightRgb: def(worldFile, 'DIEGETIC_LIGHT_RGB'),
    structures: def('src/systems/physicality.js', 'STRUCTURES'),
  };
  const catalogs = {
    equipment: def(catalogsFile, 'EQUIPMENT'), weapons: def('src/minigames/activities.js', 'WEAPONS'),
    ranks: def(worldFile, 'RANKS'), publicPhoneLines: def(catalogsFile, 'PUBLIC_PHONE_LINES'),
    graffitiLines: def(catalogsFile, 'GRAFFITI_LINES'), scrapGraffitiLines: def(catalogsFile, 'SCRAP_GRAFFITI_LINES'),
    spiritualGraffitiLines: def(catalogsFile, 'SPIRITUAL_GRAFFITI_LINES'),
    vendorFloaterIds: def(catalogsFile, 'VENDOR_FLOATER_IDS'), vendorIndexMeta: def(catalogsFile, 'VENDOR_INDEX_META'),
    crownSpots: def(catalogsFile, 'CROWN_SPOTS'), achievements: def('src/systems/progression_routes.js', 'ACHIEVEMENTS'),
  };
  const itemData = extractItemData(omissions);
  catalogs.items = itemData.items;
  catalogs.itemLoot = itemData.loot;
  catalogs.itemDeclarations = itemData.declarations;
  const hashes = {};
  for (const file of [...sourceFiles(), path.join(ROOT, 'VIBE.md')].sort()) {
    hashes[slash(path.relative(ROOT, file))] = sha256(fs.readFileSync(file));
  }
  const toolHashes = {};
  for (const file of ['tools/export-3d-content.mjs', 'tools/runtime-harness.mjs', 'tools/npc-registry-gate.mjs']) {
    toolHashes[file] = sha256(fs.readFileSync(path.join(ROOT, file)));
  }
  omissions.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  return {
    schema: 1, format: 'rock-bottom-source-content',
    source: {
      hashes, corpusSha256: sha256(stableStringify(hashes)), toolHashes, exports,
      fixture: { seed: SOURCE_SEED, dateNowMs: FIXED_EPOCH_MS, performanceNowMs: 1000, entry: 'src/main.js', start: 'startGame(false)' },
      units: { coordinates: 'source pixels', durations: 'source milliseconds unless the source field says otherwise', simulationStepMs: 16 },
    },
    world, buildings: def(propsFile, 'BUILDINGS'), props: def(propsFile, 'PROPS'),
    interactiveProps: def(propsFile, 'interactiveProps'),
    actors: { base, day1, registry: parseRegistry(), aliases: ACTOR_ALIASES, generatedFamilies: GENERATED_FAMILIES },
    catalogs, initial, definitions, omissions,
    encoding: {
      objectKeys: 'lexicographically sorted', arrayOrder: 'authored/runtime order retained',
      set: { $type: 'Set', values: [] }, map: { $type: 'Map', entries: [] },
      functions: 'omitted with path and name; executable behavior is not exported',
      derivedItems: 'exact source literal records with source refs; generated IDs only reproduce the declared deterministic literal-name fallback',
      undefined: 'object property omitted; array slot becomes null; every path recorded',
      resources: 'explicitly omitted; unexpected host resources and cyclic/non-finite data fail export',
      parity: 'data coverage only; omitted callbacks require separately implemented and tested gameplay',
    },
  };
}

export function ensureVmFlag(scriptFile) {
  if (typeof vm.SourceTextModule === 'function') return;
  const result = spawnSync(process.execPath,
    ['--experimental-vm-modules', scriptFile, ...process.argv.slice(2)], { cwd: ROOT, stdio: 'inherit' });
  if (result.error) throw result.error;
  process.exit(result.status ?? 1);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  ensureVmFlag(fileURLToPath(import.meta.url));
  try {
    const unknown = process.argv.slice(2).filter(arg => arg !== '--check');
    if (unknown.length) throw new Error(`Unknown arguments: ${unknown.join(' ')}`);
    const content = await buildContent(), text = stableStringify(content);
    if (process.argv.includes('--check')) {
      if (!fs.existsSync(OUTPUT) || fs.readFileSync(OUTPUT, 'utf8') !== text) {
        throw new Error('source_content.json is stale; run node tools/export-3d-content.mjs');
      }
      console.log('3D CONTENT EXPORT CHECK PASS: source data and provenance match');
    } else {
      fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
      fs.writeFileSync(OUTPUT, text);
      console.log(`3D CONTENT EXPORTED: ${Buffer.byteLength(text)} bytes; ${content.actors.base.length} base / ${content.actors.day1.length} day-one actors; ${content.omissions.length} explicit omissions`);
    }
  } catch (error) {
    console.error(`3D CONTENT EXPORT FAIL: ${error.message}`);
    process.exitCode = 1;
  }
}
