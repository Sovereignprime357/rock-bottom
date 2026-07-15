import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import vm from 'node:vm';

const ROOT = path.resolve(import.meta.dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'src/module-manifest.json'), 'utf8'));
const failures = [];
const assert = (condition, message) => { if (!condition) failures.push(message); };

const referencePath = path.join(ROOT, manifest.reference);
const referenceHash = crypto.createHash('sha256').update(fs.readFileSync(referencePath)).digest('hex').toUpperCase();
assert(referenceHash === manifest.referenceSha256, `frozen v19 hash mismatch: ${referenceHash}`);
assert(referenceHash === 'C25DB5E17536AEC092143D87DBF8C113325076A8B8E196A98AECB84694A25C8B', 'manifest reference hash is not the ratified post-vignette build');

const covered = new Map();
for (const chunk of manifest.chunks) {
  const ranges = chunk.ranges || (chunk.synthetic === 'npc_ai'
    ? [[7919, 8368]]
    : chunk.synthetic === 'update' ? [[7254, 7918], [8369, 8580]] : []);
  for (const [start, end] of ranges) {
    for (let line = start; line <= end; line++) covered.set(line, (covered.get(line) || 0) + 1);
  }
}
for (let line = 249; line <= 12733; line++) assert(covered.get(line) === 1, `source coverage at v19 line ${line} is ${covered.get(line) || 0}, expected 1`);
for (const line of covered.keys()) assert(line >= 249 && line <= 12733, `source coverage escapes script body at line ${line}`);

const indexHtml = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
assert(indexHtml.includes('<script type="module" src="./src/main.js"></script>'), 'index.html is missing the native module entry');
assert(!/<script>([\s\S]*?)<\/script>/.test(indexHtml), 'index.html still has an inline classic script');

const jsFiles = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes:true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) jsFiles.push(full);
  }
}
walk(path.join(ROOT, 'src'));
for (const file of jsFiles) {
  const source = fs.readFileSync(file, 'utf8');
  const rel = path.relative(ROOT, file).replaceAll('\\', '/');
  const lineCount = source.split(/\r?\n/).length;
  const transitionalLegacy = rel === 'src/legacy.js' && manifest.extractedCount < manifest.totalChunks;
  assert(transitionalLegacy || lineCount <= 1000, `${rel} has ${lineCount} lines (limit 1000)`);
  assert(!/\b(?:localStorage|sessionStorage)\b/.test(source), `${rel} uses a forbidden synchronous storage API`);
}
if (manifest.extractedCount === manifest.totalChunks) assert(!fs.existsSync(path.join(ROOT, 'src/legacy.js')), 'legacy.js remains after final extraction');

if (typeof vm.SourceTextModule !== 'function') {
  failures.push('vm.SourceTextModule unavailable; run with --experimental-vm-modules');
} else {
  const context = vm.createContext({});
  const cache = new Map();
  function getModule(file) {
    const full = path.resolve(file);
    if (cache.has(full)) return cache.get(full);
    const source = fs.readFileSync(full, 'utf8');
    const mod = new vm.SourceTextModule(source, { context, identifier:full });
    cache.set(full, mod);
    return mod;
  }
  try {
    const root = getModule(path.join(ROOT, 'src/main.js'));
    await root.link((specifier, referencing) => {
      const resolved = path.resolve(path.dirname(referencing.identifier), specifier);
      assert(fs.existsSync(resolved), `missing import ${specifier} from ${path.relative(ROOT, referencing.identifier)}`);
      return getModule(resolved);
    });
  }
  catch (error) { failures.push(`ES module link failed: ${error.stack || error.message}`); }
}

if (failures.length) {
  console.error(`MODULE GATE: ${failures.length} failure(s)`);
  failures.slice(0, 30).forEach(message => console.error(`- ${message}`));
  process.exit(1);
}
console.log(`MODULE GATE: PASS (${manifest.extractedCount}/${manifest.totalChunks} chunks extracted, ${jsFiles.length} JS files linked)`);
