// ONE-SHOT Wave 4.3 tenebrist palette regrade (SPEC-v23-grime-cinema.md).
// Run once: node tools/v23-palette-regrade.mjs   (idempotence NOT guaranteed; restore via git first)
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const FILE = path.join(ROOT, 'src/render/sprites.js');
let src = fs.readFileSync(FILE, 'utf8');

// Anchors keep the roster instantly recognizable (VIBE spine + identity).
const ANCHORS = new Set(['transparent', '#000', '#d4c896', '#e8c040']);
// Authority + core-visual exemptions: byte-identical palettes (blue rule, rocked-up gold glow).
const EXEMPT_PALETTES = new Set(['cop', 'horsecop', 'brendan', 'player_high']);

function lum(hex) {
  const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
}
// The tenebrist S-curve: crush shadows toward mauve, protect lights. SPEC-v23 §I-PALETTE-DISCIPLINE.
function shift(hex) {
  let r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
  const L = lum(hex);
  if (L < 0.14) { r *= 0.82; g *= 0.74; b = Math.min(255, b * 0.90 + 8); }
  else if (L < 0.34) { r *= 0.88; g *= 0.80; b = Math.min(255, b * 0.94 + 6); }
  else if (L < 0.58) { r *= 0.95; g *= 0.90; b = Math.min(255, b * 0.98 + 2); }
  else return hex.toUpperCase();
  const to = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
  return ('#' + to(r) + to(g) + to(b));
}
function regradeLine(line, paletteName) {
  return line.replace(/'#[0-9a-fA-F]{6}'/g, m => {
    const bare = m.slice(1, -1).toLowerCase(); // strip the matched quotes BEFORE any color math
    if (ANCHORS.has(bare)) return "'" + bare + "'";
    return "'" + shift(bare) + "'";
  });
}
const audit = [];

function regradeBlock(markerStart, markerEnd, label, nameRegex) {
  const start = src.indexOf(markerStart);
  const end = src.indexOf(markerEnd, start);
  if (start < 0 || end < 0) throw new Error(`block not found: ${label}`);
  let block = src.slice(start, end);
  block = block.split('\n').map(line => {
    const nameMatch = nameRegex.exec(line);
    if (!nameMatch) return line;
    const name = nameMatch[1];
    if (EXEMPT_PALETTES.has(name)) return line;
    const before = line;
    const after = regradeLine(line, name);
    if (before !== after) audit.push({ palette: `${label}.${name}`, before, after });
    return after;
  }).join('\n');
  src = src.slice(0, start) + block + src.slice(end);
}

// Character roster (array form).
regradeBlock('  PALS = {', '\n  };', 'PALS', /^    ([A-Za-z_]+):\s+\[/);
// Incident world-object props (drawn in-world; benefit most from grounded shadows).
regradeBlock('  INCIDENT_PALS = {', '\n  };', 'INCIDENT_PALS', /^    ([A-Za-z_]+):\s+\[/);
// Player gear/weapon/route-patch layer palette (single line, array form).
src = src.replace(/^(  PLAYER_LAYER_PAL=\[)(.*)(\];)$/m, (m, a, body, c) => {
  const line = a + body + c;
  const after = regradeLine(line, 'PLAYER_LAYER_PAL');
  if (line !== after) audit.push({ palette: 'PLAYER_LAYER_PAL', before: line.trim(), after: after.trim() });
  return after;
});

fs.writeFileSync(FILE, src, 'utf8');
fs.mkdirSync(path.join(ROOT, 'artifacts/v23'), { recursive: true });
fs.writeFileSync(path.join(ROOT, 'artifacts/v23/palette-audit.json'), JSON.stringify(audit, null, 1), 'utf8');
console.log(`regraded ${audit.length} palettes; audit written to artifacts/v23/palette-audit.json`);
