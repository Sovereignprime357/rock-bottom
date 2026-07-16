/**
 * docs-gate.mjs — the README must not lie about the suite
 * ========================================================
 *
 * WHY THIS EXISTS
 * ---------------
 * On 2026-07-16 the README said the runner "streams all four gates in order." It streamed
 * seven. Nothing caught it, because every gate in this repo checks the game or the corpus,
 * and a stale sentence in a README is neither. It was found by a human reading the file
 * for an unrelated reason — which is to say, by luck.
 *
 * That drift is small and boring and that is exactly the problem: a README that is wrong
 * about something checkable is a README nobody trusts about anything, and the first thing
 * a fresh agent does in this repo is read the README. The corpus is the seed. A seed that
 * misdescribes its own tooling reproduces agents that misunderstand the tooling.
 *
 * ORIGIN, SPECIFICALLY
 * --------------------
 * ORCHESTRATOR-NOTES.md entry #6 named this class as UNGUARDED and said out loud that a
 * gate asserting "README's gate list == the GATES array" was a real candidate and had not
 * been built. Writing "this is still unguarded" into a notes file and moving on is the
 * precise failure that same file spends six entries arguing against. A note is a prompt.
 * Prompts leak. Only a gate holds. So: the gate.
 *
 * WHAT IT CHECKS
 * --------------
 * 1. Every gate in run-gates.mjs's GATES array appears in the README's gate table.
 * 2. Every gate named in the README's table actually exists in the GATES array.
 * 3. Every gate file in the array exists on disk.
 * It compares two living sources against each other. It transcribes nothing, so it
 * cannot itself rot — the failure mode of a doc gate with a hardcoded list is that it
 * becomes one more thing to keep in sync.
 *
 * WHAT IT DELIBERATELY DOES NOT CHECK
 * -----------------------------------
 * Whether the README's *descriptions* are accurate. That is prose about behavior and no
 * grep can judge it. This gate holds the list, not the sentences. Claiming otherwise
 * would be a gate-shaped decoration, which is the thing being guarded against.
 */

import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

const TOOLS = import.meta.dirname;
const ROOT = path.resolve(TOOLS, "..");

const red = (s) => `\x1b[31m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;

console.log("docs-gate: the README must not lie about the suite");

const failures = [];

// ---------- source 1: the GATES array, read from the runner itself ----------
const runnerSrc = readFileSync(path.join(TOOLS, "run-gates.mjs"), "utf8");
const arrayMatch = runnerSrc.match(/const\s+GATES\s*=\s*\[([\s\S]*?)\]/);
if (!arrayMatch) {
  console.error(red("FAIL — could not find the GATES array in run-gates.mjs."));
  console.error("       This gate reads the runner as its source of truth. If the runner's");
  console.error("       shape changed, this gate must be taught the new shape — do not");
  console.error("       delete it to make the suite green.");
  process.exit(1);
}
// Strip comments before extracting, so a gate name mentioned in a comment isn't counted.
const arrayBody = arrayMatch[1].replace(/\/\/[^\n]*/g, "").replace(/\/\*[\s\S]*?\*\//g, "");
const declared = [...arrayBody.matchAll(/['"]([\w.-]+\.mjs)['"]/g)].map((m) => m[1]);

if (declared.length === 0) {
  console.error(red("FAIL — GATES array parsed but contained no gate files."));
  process.exit(1);
}

// ---------- source 2: the README's gate table ----------
const readmeSrc = readFileSync(path.join(ROOT, "README.md"), "utf8");
// Table rows look like: | `corpus-gate` | ...what it enforces... |
const documented = [...readmeSrc.matchAll(/^\|\s*`([\w-]+)`\s*\|/gm)].map((m) => m[1]);

const base = (f) => f.replace(/\.mjs$/, "");

// ---------- check 1: every real gate is documented ----------
for (const file of declared) {
  if (!documented.includes(base(file))) {
    failures.push(
      `${file} runs in the suite but is missing from the README's gate table.\n` +
        `    A gate nobody documented is a gate the next agent deletes as mystery tooling.`
    );
  }
}

// ---------- check 2: every documented gate is real ----------
for (const name of documented) {
  if (!declared.some((f) => base(f) === name)) {
    failures.push(
      `README's gate table lists "${name}" but it is not in run-gates.mjs's GATES array.\n` +
        `    The README is describing a suite that does not exist.`
    );
  }
}

// ---------- check 3: every declared gate is on disk ----------
for (const file of declared) {
  if (!existsSync(path.join(TOOLS, file))) {
    failures.push(`${file} is in the GATES array but does not exist in tools/.`);
  }
}

if (failures.length) {
  console.error(red(`\nFAIL — ${failures.length} docs violation(s):\n`));
  for (const f of failures) console.error(`  ${red("✗")} ${f}`);
  console.error(
    `\n  Fix the README (or the array). Do NOT delete this gate to move on:\n` +
      `  the README is the first thing a fresh agent reads, and a corpus that\n` +
      `  misdescribes its own tooling reproduces agents that misuse it.\n`
  );
  process.exit(1);
}

console.log(
  green(
    `DOCS GATE: PASS (${declared.length} gates in the runner, ${documented.length} documented, ` +
      `all present on disk, both lists agree)`
  )
);
