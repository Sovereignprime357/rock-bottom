/**
 * version-gate.mjs — the game must not lie about which game it is
 * ================================================================
 *
 * WHY THIS EXISTS
 * ---------------
 * `index.html` said "ROCK BOTTOM v19" in its <title> and its subtitle through the ENTIRE
 * v20 recognition wave — five landings — and through v21 Wave 4.1. The README's "Current
 * shipped build" section said v19 too. Three stale claims, none of them checked by anything.
 *
 * On 2026-07-16 the operator opened the live build to play the work that had just shipped,
 * saw "v19", hard-refreshed several times, opened an incognito window, and reported the
 * deploy as stale. **The deploy was perfectly current.** GitHub Pages had built the exact
 * HEAD commit; physicality.js was serving 200. He was playing Wave 4.1 and the game was
 * telling him it was v19.
 *
 * **The label was the bug.** It cost a human his time, on the one night he had time to play,
 * chasing a phantom that a three-character diff would have prevented.
 *
 * It was also FOUND and REPORTED hours earlier and deliberately left alone as "the operator's
 * call, a one-line fix either way." That is the entry-#6 mistake — notice the gap, describe
 * the gap, ship the gap. A known-stale string is not a matter of taste. It is a lie the
 * program tells, and it told it to the one person who could not check it against the source.
 *
 * WHAT IT CHECKS
 * --------------
 * The <title>, the .sub subtitle, and README's "Current shipped build" heading all name the
 * same version. Three living sources compared against each other — nothing transcribed, so
 * this gate cannot itself rot into the thing it guards.
 *
 * WHAT IT DELIBERATELY DOES NOT CHECK
 * -----------------------------------
 * Whether the version number is CORRECT. No mechanical check knows that v21 is the truth;
 * "which version is this" is a human decision about what shipped. This gate only proves the
 * program tells ONE story about itself. Consistency is gateable. Truth here is not, and
 * claiming otherwise would make this decoration.
 */

import { readFileSync } from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");
const red = (s) => `\x1b[31m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;

console.log("version-gate: the game must not lie about which game it is");

const html = readFileSync(path.join(ROOT, "index.html"), "utf8");
const readme = readFileSync(path.join(ROOT, "README.md"), "utf8");

const failures = [];
const found = {};

const title = html.match(/<title>\s*ROCK BOTTOM\s+(v\d+)\s*<\/title>/i);
if (!title) failures.push('index.html <title> does not match "ROCK BOTTOM v<N>". This gate reads it as a source of truth — teach it the new shape, do not delete it.');
else found.title = title[1];

const sub = html.match(/class="sub">\s*the crackhead's odyssey\s*·\s*(v\d+)\s*</i);
if (!sub) failures.push("index.html .sub subtitle does not match \"the crackhead's odyssey · v<N>\".");
else found.subtitle = sub[1];

const shipped = readme.match(/##\s*Current shipped build\s*\n+\s*\*\*(v\d+)/i);
if (!shipped) failures.push('README.md "## Current shipped build" does not open with **v<N>.');
else found.readme = shipped[1];

const versions = [...new Set(Object.values(found))];
if (versions.length > 1) {
  failures.push(
    `the build tells ${versions.length} different stories about itself: ` +
      Object.entries(found).map(([k, v]) => `${k}=${v}`).join(", ") +
      `\n    Pick one and make all three agree. A player cannot read the source to find out\n` +
      `    which one is true — the label is the only version they will ever see.`
  );
}

if (failures.length) {
  console.error(red(`\nFAIL — ${failures.length} version violation(s):\n`));
  for (const f of failures) console.error(`  ${red("✗")} ${f}`);
  console.error(
    `\n  A stale version label is not cosmetic. It sent the operator hard-refreshing and\n` +
      `  opening incognito windows against a deploy that was already current, on the night\n` +
      `  he had time to play. The label was the bug.\n`
  );
  process.exit(1);
}

console.log(green(`VERSION GATE: PASS (title, subtitle, and README all say ${versions[0]})`));
