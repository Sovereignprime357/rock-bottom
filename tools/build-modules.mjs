import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = path.resolve(import.meta.dirname, '..');
const REFERENCE = path.join(ROOT, 'rock_bottom_v19.html');
const EXPECTED_REFERENCE_SHA256 = 'C25DB5E17536AEC092143D87DBF8C113325076A8B8E196A98AECB84694A25C8B';

const chunks = [
  { id:'storage', file:'src/core/storage.js', title:'window.storage shim', ranges:[[249,295]] },
  { id:'constants_world', file:'src/data/world.js', title:'constants, zones, and visual world cohesion', ranges:[[296,609]] },
  { id:'props', file:'src/data/props.js', title:'buildings, props, and interactive props', ranges:[[610,887]] },
  { id:'catalogs', file:'src/data/catalogs.js', title:'chatter, equipment, phones, graffiti, and vendor catalogs', ranges:[[888,1063]] },
  { id:'factions', file:'src/systems/factions.js', title:'factions and territory', ranges:[[1064,1277]] },
  { id:'progression_routes', file:'src/systems/progression_routes.js', title:'achievements, hustles, and block routes', ranges:[[1278,1530]] },
  { id:'campaigns', file:'src/systems/campaigns.js', title:'office, claims, and curb kingdom campaign', ranges:[[1531,2214]] },
  { id:'communications', file:'src/systems/communications.js', title:'calls, possum, truck, news, feed, and world events', ranges:[[2215,2424]] },
  { id:'incidents', file:'src/systems/incidents.js', title:'living-neighborhood incidents', ranges:[[2425,2711]] },
  { id:'sprites', file:'src/render/sprites.js', title:'sprite data and sprite caches', ranges:[[2712,3559]] },
  { id:'audio_save', file:'src/core/audio_save.js', title:'audio and persistence', ranges:[[3560,3834]] },
  { id:'runtime_ui', file:'src/core/runtime_ui.js', title:'world state and status UI', ranges:[[3835,4320]], ownsRuntime:true },
  { id:'helpers_spawns', file:'src/data/npc_spawns.js', title:'helpers, NPC setup, and cash piles', ranges:[[4321,4695]] },
  { id:'dialogue_a', file:'src/dialogue/neighborhood_a.js', title:'neighborhood dialogue, first half', ranges:[[4696,5324]] },
  { id:'dialogue_b', file:'src/dialogue/neighborhood_b.js', title:'neighborhood dialogue, second half', ranges:[[5325,5678]] },
  { id:'vendors_places', file:'src/dialogue/vendors_places.js', title:'bus, vendors, and place encounters', ranges:[[5679,6279]] },
  { id:'heat', file:'src/minigames/heat.js', title:'cook and heat minigame', ranges:[[6280,6710]] },
  { id:'combat', file:'src/systems/combat.js', title:'combat primitives, intro, boss, and cops', ranges:[[6711,7253]] },
  { id:'npc_ai', file:'src/systems/npc_ai.js', title:'NPC AI and chatter loop', synthetic:'npc_ai' },
  { id:'update', file:'src/core/update.js', title:'world update loop', synthetic:'update' },
  { id:'hud', file:'src/ui/hud.js', title:'HUD', ranges:[[8581,8604]] },
  { id:'canvas_geography', file:'src/render/canvas_geography.js', title:'canvas and connective geography', ranges:[[8605,8880]] },
  { id:'landmarks_a', file:'src/render/landmarks_a.js', title:'landmark and light caches', ranges:[[8881,9105]] },
  { id:'frame', file:'src/render/frame.js', title:'frame renderer', ranges:[[9106,9430]] },
  { id:'landmarks_b', file:'src/render/landmarks_b.js', title:'fences, underpass, and leash', ranges:[[9431,9536]] },
  { id:'tiles', file:'src/render/tiles.js', title:'tile palettes and market stalls', ranges:[[9537,9830]] },
  { id:'structures', file:'src/render/structures.js', title:'buildings, graffiti, posters, and claim visuals', ranges:[[9831,10286]] },
  { id:'render_props', file:'src/render/props.js', title:'prop and interactive-prop rendering', ranges:[[10287,10889]] },
  { id:'actors_weather', file:'src/render/actors_weather.js', title:'lighting, weather, actors, and objectives', ranges:[[10890,11239]] },
  { id:'minimap', file:'src/render/minimap.js', title:'minimap', ranges:[[11240,11298]] },
  { id:'ending_interactions', file:'src/systems/interactions.js', title:'ending, interaction, and dumpster systems', ranges:[[11299,11612]] },
  { id:'daily_hideouts', file:'src/systems/daily_hideouts.js', title:'daily systems and hideouts', ranges:[[11613,11913]] },
  { id:'activities', file:'src/minigames/activities.js', title:'heist, weapons, rhythm, lockpick, Brutus, and panhandling', ranges:[[11914,12286]] },
  { id:'keyboard', file:'src/input/keyboard.js', title:'keyboard controls', ranges:[[12287,12401]] },
  { id:'start', file:'src/core/start.js', title:'game start and new-game initialization', ranges:[[12402,12536]] },
  { id:'boot', file:'src/core/boot.js', title:'cache and HUD boot sequence', ranges:[[12537,12548]] },
  { id:'mobile', file:'src/input/mobile.js', title:'mobile controls and final startup', ranges:[[12549,12733]] },
];

const args = process.argv.slice(2);
const countArg = args.indexOf('--count');
const requestedCount = countArg >= 0 ? Number(args[countArg + 1]) : chunks.length;
if (!Number.isInteger(requestedCount) || requestedCount < 0 || requestedCount > chunks.length) {
  throw new Error(`--count must be an integer from 0 through ${chunks.length}`);
}

const referenceBytes = fs.readFileSync(REFERENCE);
const referenceHash = crypto.createHash('sha256').update(referenceBytes).digest('hex').toUpperCase();
if (referenceHash !== EXPECTED_REFERENCE_SHA256) {
  throw new Error(`Frozen v19 hash drifted: ${referenceHash}`);
}
const html = referenceBytes.toString('utf8');
const lines = html.split(/\r?\n/);

function originalRange(start, end) {
  return `${lines.slice(start - 1, end).join('\n')}\n`;
}

function chunkSource(chunk) {
  let source;
  if (chunk.synthetic === 'npc_ai') {
    const loop = originalRange(7919, 8368);
    source = `// ---------- NPC AI + walk-frame anim + chatter ----------\nfunction updateNpcActors(dt) {\n${loop}}\n`;
  } else if (chunk.synthetic === 'update') {
    source = `${originalRange(7254, 7918)}  updateNpcActors(dt);\n${originalRange(8369, 8580)}`;
  } else {
    source = chunk.ranges.map(([start, end]) => originalRange(start, end)).join('');
  }
  return rewriteSharedRuntime(source);
}

function rewriteSharedRuntime(source) {
  source = source
    .replace(/^let npcs = \[\];$/m, 'runtime.npcs = [];')
    .replace(/^let cashPiles = \[\];$/m, 'runtime.cashPiles = [];')
    .replace(/^let projectiles = \[\];$/m, 'runtime.projectiles = [];');

  const targets = new Set(['npcs', 'cashPiles', 'projectiles']);
  let out = '';
  let i = 0;
  let state = 'code';
  let quote = '';
  let regexClass = false;
  while (i < source.length) {
    const ch = source[i], next = source[i + 1];
    if (state === 'line_comment') {
      out += ch; i++;
      if (ch === '\n') state = 'code';
      continue;
    }
    if (state === 'block_comment') {
      out += ch; i++;
      if (ch === '*' && next === '/') { out += '/'; i++; state = 'code'; }
      continue;
    }
    if (state === 'string') {
      out += ch; i++;
      if (ch === '\\' && i < source.length) { out += source[i++]; continue; }
      if (ch === quote) state = 'code';
      continue;
    }
    if (state === 'regex') {
      out += ch; i++;
      if (ch === '\\' && i < source.length) { out += source[i++]; continue; }
      if (ch === '[') regexClass = true;
      else if (ch === ']') regexClass = false;
      else if (ch === '/' && !regexClass) state = 'code';
      continue;
    }
    if (ch === '/' && next === '/') { out += '//'; i += 2; state = 'line_comment'; continue; }
    if (ch === '/' && next === '*') { out += '/*'; i += 2; state = 'block_comment'; continue; }
    if (ch === '/' && isRegexStart(source, i)) { out += ch; i++; state = 'regex'; regexClass = false; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { out += ch; i++; state = 'string'; quote = ch; continue; }
    if (/[A-Za-z_$]/.test(ch)) {
      let j = i + 1;
      while (j < source.length && /[\w$]/.test(source[j])) j++;
      const word = source.slice(i, j);
      if (targets.has(word)) {
        let p = i - 1;
        while (p >= 0 && /\s/.test(source[p])) p--;
        let q = j;
        while (q < source.length && /\s/.test(source[q])) q++;
        const prefix = source.slice(Math.max(0, i - 8), i);
        const getterKey = /\bget\s+$/.test(prefix) && source[q] === '(';
        out += (source[p] === '.' || getterKey) ? word : `runtime.${word}`;
      } else out += word;
      i = j;
      continue;
    }
    out += ch;
    i++;
  }
  return out;
}

function isRegexStart(source, index) {
  let p = index - 1;
  while (p >= 0 && /\s/.test(source[p])) p--;
  if (p < 0) return true;
  return '([{:;,=!?&|+-*%^~<>'.includes(source[p]);
}

function findFunctionBodyStart(source, start) {
  let paren = 0, bracket = 0;
  let state = 'code', quote = '', regexClass = false;
  for (let i = start; i < source.length; i++) {
    const ch = source[i], next = source[i + 1];
    if (state === 'line_comment') { if (ch === '\n') state = 'code'; continue; }
    if (state === 'block_comment') { if (ch === '*' && next === '/') { i++; state = 'code'; } continue; }
    if (state === 'string') {
      if (ch === '\\') { i++; continue; }
      if (ch === quote) state = 'code';
      continue;
    }
    if (state === 'regex') {
      if (ch === '\\') { i++; continue; }
      if (ch === '[') regexClass = true;
      else if (ch === ']') regexClass = false;
      else if (ch === '/' && !regexClass) state = 'code';
      continue;
    }
    if (ch === '/' && next === '/') { i++; state = 'line_comment'; continue; }
    if (ch === '/' && next === '*') { i++; state = 'block_comment'; continue; }
    if (ch === '/' && isRegexStart(source, i)) { state = 'regex'; regexClass = false; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { state = 'string'; quote = ch; continue; }
    if (ch === '(') paren++;
    else if (ch === ')') paren--;
    else if (ch === '[') bracket++;
    else if (ch === ']') bracket--;
    else if (ch === '{' && paren === 0 && bracket === 0) return i;
  }
  throw new Error('Function body start not found');
}

function findMatchingBrace(source, open) {
  let depth = 0, state = 'code', quote = '', regexClass = false;
  for (let i = open; i < source.length; i++) {
    const ch = source[i], next = source[i + 1];
    if (state === 'line_comment') { if (ch === '\n') state = 'code'; continue; }
    if (state === 'block_comment') { if (ch === '*' && next === '/') { i++; state = 'code'; } continue; }
    if (state === 'string') {
      if (ch === '\\') { i++; continue; }
      if (ch === quote) state = 'code';
      continue;
    }
    if (state === 'regex') {
      if (ch === '\\') { i++; continue; }
      if (ch === '[') regexClass = true;
      else if (ch === ']') regexClass = false;
      else if (ch === '/' && !regexClass) state = 'code';
      continue;
    }
    if (ch === '/' && next === '/') { i++; state = 'line_comment'; continue; }
    if (ch === '/' && next === '*') { i++; state = 'block_comment'; continue; }
    if (ch === '/' && isRegexStart(source, i)) { state = 'regex'; regexClass = false; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { state = 'string'; quote = ch; continue; }
    if (ch === '{') depth++;
    else if (ch === '}' && --depth === 0) return i;
  }
  throw new Error('Function closing brace not found');
}

function findStatementEnd(source, start) {
  let paren = 0, bracket = 0, brace = 0, state = 'code', quote = '', regexClass = false;
  for (let i = start; i < source.length; i++) {
    const ch = source[i], next = source[i + 1];
    if (state === 'line_comment') { if (ch === '\n') state = 'code'; continue; }
    if (state === 'block_comment') { if (ch === '*' && next === '/') { i++; state = 'code'; } continue; }
    if (state === 'string') {
      if (ch === '\\') { i++; continue; }
      if (ch === quote) state = 'code';
      continue;
    }
    if (state === 'regex') {
      if (ch === '\\') { i++; continue; }
      if (ch === '[') regexClass = true;
      else if (ch === ']') regexClass = false;
      else if (ch === '/' && !regexClass) state = 'code';
      continue;
    }
    if (ch === '/' && next === '/') { i++; state = 'line_comment'; continue; }
    if (ch === '/' && next === '*') { i++; state = 'block_comment'; continue; }
    if (ch === '/' && isRegexStart(source, i)) { state = 'regex'; regexClass = false; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { state = 'string'; quote = ch; continue; }
    if (ch === '(') paren++; else if (ch === ')') paren--;
    else if (ch === '[') bracket++; else if (ch === ']') bracket--;
    else if (ch === '{') brace++; else if (ch === '}') brace--;
    else if (ch === ';' && paren === 0 && bracket === 0 && brace === 0) return i;
  }
  throw new Error(`Variable declaration terminator not found near ${source.slice(start, start + 80)}`);
}

function splitDeclarators(body) {
  const parts = [];
  let start = 0, paren = 0, bracket = 0, brace = 0, state = 'code', quote = '', regexClass = false;
  for (let i = 0; i < body.length; i++) {
    const ch = body[i], next = body[i + 1];
    if (state === 'line_comment') { if (ch === '\n') state = 'code'; continue; }
    if (state === 'block_comment') { if (ch === '*' && next === '/') { i++; state = 'code'; } continue; }
    if (state === 'string') { if (ch === '\\') i++; else if (ch === quote) state = 'code'; continue; }
    if (state === 'regex') {
      if (ch === '\\') { i++; continue; }
      if (ch === '[') regexClass = true;
      else if (ch === ']') regexClass = false;
      else if (ch === '/' && !regexClass) state = 'code';
      continue;
    }
    if (ch === '/' && next === '/') { i++; state = 'line_comment'; continue; }
    if (ch === '/' && next === '*') { i++; state = 'block_comment'; continue; }
    if (ch === '/' && isRegexStart(body, i)) { state = 'regex'; regexClass = false; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { state = 'string'; quote = ch; continue; }
    if (ch === '(') paren++; else if (ch === ')') paren--;
    else if (ch === '[') bracket++; else if (ch === ']') bracket--;
    else if (ch === '{') brace++; else if (ch === '}') brace--;
    else if (ch === ',' && paren === 0 && bracket === 0 && brace === 0) {
      parts.push(body.slice(start, i)); start = i + 1;
    }
  }
  parts.push(body.slice(start));
  return parts;
}

function parsesAsProgram(source) {
  try { new Function(`'use strict';\n${source}`); return true; }
  catch (_) { return false; }
}

function findFunctionEndByParse(source, start) {
  for (let close = source.indexOf('}', start); close >= 0; close = source.indexOf('}', close + 1)) {
    const end = close + 1;
    if (parsesAsProgram(source.slice(start, end))) return end;
  }
  throw new Error('Function closing brace not found');
}

function findDeclarationEndByParse(source, start, searchFrom) {
  for (let end = source.indexOf(';', searchFrom); end >= 0; end = source.indexOf(';', end + 1)) {
    if (parsesAsProgram(source.slice(start, end + 1))) return end;
  }
  throw new Error(`Variable declaration terminator not found near ${source.slice(start, start + 80)}`);
}

function analyze(source, id) {
  const declarations = [];
  const functionRe = /^(async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(/gm;
  for (const match of source.matchAll(functionRe)) {
    const start = match.index;
    let close;
    try { close = findFunctionEndByParse(source, start) - 1; }
    catch (error) { throw new Error(`${error.message} in ${id}.${match[2]}`); }
    declarations.push({ kind:'function', name:match[2], names:[match[2]], start, end:close + 1, text:source.slice(start, close + 1) });
  }
  const variableRe = /^(const|let|var)\s+/gm;
  for (const match of source.matchAll(variableRe)) {
    if (declarations.some(d => match.index >= d.start && match.index < d.end)) continue;
    const start = match.index;
    const keywordEnd = match.index + match[0].length;
    const end = findDeclarationEndByParse(source, start, keywordEnd);
    const body = source.slice(keywordEnd, end);
    const names = splitDeclarators(body).map(part => {
      const name = part.match(/^\s*([A-Za-z_$][\w$]*)/);
      if (!name) throw new Error(`Unsupported top-level declaration in ${id}: ${part.slice(0, 100)}`);
      return name[1];
    });
    declarations.push({ kind:'variable', names, start, end:end + 1, keywordEnd, text:source.slice(start, end + 1) });
  }
  declarations.sort((a, b) => a.start - b.start);
  for (let i = 1; i < declarations.length; i++) {
    if (declarations[i].start < declarations[i - 1].end) {
      throw new Error(`Overlapping declarations in ${id}: ${declarations[i - 1].names.join(',')} -> ${declarations[i].names.join(',')}`);
    }
  }
  return declarations;
}

const sourceById = new Map(chunks.map(chunk => [chunk.id, chunkSource(chunk)]));
const declarationsById = new Map(chunks.map(chunk => [chunk.id, analyze(sourceById.get(chunk.id), chunk.id)]));

const extracted = new Set(chunks.slice(0, requestedCount).map(chunk => chunk.id));
const ownerFileFor = chunk => extracted.has(chunk.id) ? chunk.file : 'src/legacy.js';
const registry = new Map();
for (const chunk of chunks) {
  for (const decl of declarationsById.get(chunk.id)) {
    for (const name of decl.names) {
      if (registry.has(name)) throw new Error(`Duplicate top-level binding: ${name}`);
      registry.set(name, { chunk, file:ownerFileFor(chunk) });
    }
  }
}
const runtimeChunk = chunks.find(chunk => chunk.ownsRuntime);
registry.set('runtime', { chunk:runtimeChunk, file:ownerFileFor(runtimeChunk) });

function dependencyImports(moduleChunks, moduleFile) {
  const own = new Set();
  const combinedSource = moduleChunks.map(chunk => sourceById.get(chunk.id)).join('\n');
  for (const chunk of moduleChunks) for (const decl of declarationsById.get(chunk.id)) for (const name of decl.names) own.add(name);
  if (moduleChunks.some(chunk => chunk.ownsRuntime)) own.add('runtime');
  const byFile = new Map();
  for (const [name, provider] of registry) {
    if (own.has(name) || provider.file === moduleFile) continue;
    if (!new RegExp(`\\b${name.replace(/[$]/g, '\\$&')}\\b`).test(combinedSource)) continue;
    if (!byFile.has(provider.file)) byFile.set(provider.file, []);
    byFile.get(provider.file).push(name);
  }
  const lines = [];
  for (const [providerFile, names] of [...byFile].sort(([a], [b]) => a.localeCompare(b))) {
    let rel = path.posix.relative(path.posix.dirname(moduleFile), providerFile);
    if (!rel.startsWith('.')) rel = `./${rel}`;
    lines.push(`import { ${names.sort().join(', ')} } from '${rel}';`);
  }
  return lines.join('\n');
}

function renderChunk(chunk) {
  const source = sourceById.get(chunk.id);
  const declarations = declarationsById.get(chunk.id);
  const functions = declarations.filter(decl => decl.kind === 'function').map(decl => `export ${decl.text}`).join('\n\n');
  const variableNames = declarations.filter(decl => decl.kind === 'variable').flatMap(decl => decl.names);
  let cursor = 0, initBody = '';
  for (const decl of declarations) {
    initBody += source.slice(cursor, decl.start);
    if (decl.kind === 'variable') initBody += source.slice(decl.keywordEnd, decl.end);
    cursor = decl.end;
  }
  initBody += source.slice(cursor);
  const pieces = [];
  if (variableNames.length) pieces.push(`export let ${variableNames.join(', ')};`);
  if (chunk.ownsRuntime) pieces.push('export const runtime = Object.create(null);');
  if (functions) pieces.push(functions);
  pieces.push(`export function init_${chunk.id}() {\n${initBody.replace(/^/gm, '  ')}\n}`);
  return pieces.join('\n\n');
}

function renderModule(moduleChunks, moduleFile) {
  const imports = dependencyImports(moduleChunks, moduleFile);
  const header = `/* Generated from frozen rock_bottom_v19.html.\n * Source seams: ${moduleChunks.map(chunk => chunk.title).join(' | ')}.\n * Do not hand-edit; change the source module after the refactor lands.\n */`;
  return `${header}\n${imports ? `${imports}\n` : ''}\n${moduleChunks.map(renderChunk).join('\n\n')}\n`;
}

function ensureParent(file) { fs.mkdirSync(path.dirname(path.join(ROOT, file)), { recursive:true }); }
function write(file, content) { ensureParent(file); fs.writeFileSync(path.join(ROOT, file), content, 'utf8'); }

const extractedChunks = chunks.filter(chunk => extracted.has(chunk.id));
for (const chunk of extractedChunks) write(chunk.file, renderModule([chunk], chunk.file));
const legacyChunks = chunks.filter(chunk => !extracted.has(chunk.id));
if (legacyChunks.length) write('src/legacy.js', renderModule(legacyChunks, 'src/legacy.js'));
else if (fs.existsSync(path.join(ROOT, 'src/legacy.js'))) fs.unlinkSync(path.join(ROOT, 'src/legacy.js'));

const importsByFile = new Map();
for (const chunk of chunks) {
  const file = ownerFileFor(chunk);
  if (!importsByFile.has(file)) importsByFile.set(file, []);
  importsByFile.get(file).push(`init_${chunk.id}`);
}
const mainImports = [...importsByFile].map(([file, names]) => `import { ${names.join(', ')} } from './${file.slice(4)}';`).join('\n');
const mainCalls = chunks.map(chunk => `init_${chunk.id}();`).join('\n');
write('src/main.js', `/* Entry order is the original v19 top-level execution order. */\n${mainImports}\n\n${mainCalls}\n`);

const scriptStart = html.indexOf('<script>');
const scriptEnd = html.indexOf('</script>', scriptStart);
if (scriptStart < 0 || scriptEnd < 0) throw new Error('Reference script block not found');
const indexHtml = `${html.slice(0, scriptStart)}<script type="module" src="./src/main.js"></script>${html.slice(scriptEnd + '</script>'.length)}`;
write('index.html', indexHtml);

const manifest = {
  reference:'rock_bottom_v19.html', referenceSha256:referenceHash,
  extractedCount:requestedCount, totalChunks:chunks.length,
  chunks:chunks.map((chunk, index) => ({ index:index + 1, id:chunk.id, file:chunk.file, extracted:extracted.has(chunk.id), ranges:chunk.ranges || null, synthetic:chunk.synthetic || null })),
};
write('src/module-manifest.json', `${JSON.stringify(manifest, null, 2)}\n`);

console.log(JSON.stringify({ referenceHash, extracted:requestedCount, total:chunks.length, legacyChunks:legacyChunks.length }, null, 2));
