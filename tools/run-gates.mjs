import { spawn } from 'node:child_process';
import path from 'node:path';

const TOOLS = import.meta.dirname;
const ROOT = path.resolve(TOOLS, '..');
const GATES = [
  // corpus-gate runs FIRST and on purpose. Every gate below it checks the GAME.
  // This one checks the CORPUS — the tone bible, the spec, the rules, the log —
  // which is the thing every future version is reproduced from. A suite that
  // protects the output but not the seed protects the wrong thing.
  // See the incident note at the top of corpus-gate.mjs (2026-07-16).
  'corpus-gate.mjs',
  // docs-gate runs second, right behind the corpus it belongs to. It asserts this very
  // array matches the README's gate table — the README said "four gates" while seven ran,
  // and nothing caught it because a stale sentence is neither game nor corpus deletion.
  // Named as UNGUARDED in ORCHESTRATOR-NOTES.md entry #6; this closes it.
  'docs-gate.mjs',
  'module-gate.mjs',
  'npc-registry-gate.mjs',
  'legibility-gate.mjs',
  'presentation-gate.mjs',
  'recognition-gate.mjs',
  'concession-gate.mjs',
  'runtime-smoke.mjs',
  // world-gate held the last slot while it carried OD-9's standing red; that
  // reading resolved in Landing 5 and it reads green. It stays behind the
  // shipped-behavior gates because it is still a ruler over the map.
  'world-gate.mjs',
  // economy-gate runs LAST, on purpose, inheriting the slot and the rationale:
  // it ships with a standing honest red (F-SOCK — left for the operator's taste
  // call, see REFACTOR-FINDINGS.md), and the runner stops at the first failure,
  // so a standing reading must sit where it can never mask a regression in the
  // gates above it.
  'economy-gate.mjs',
];

function runGate(filename) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [
      '--no-warnings',
      '--experimental-vm-modules',
      path.join(TOOLS, filename),
    ], {
      cwd: ROOT,
      stdio: 'inherit',
      windowsHide: true,
    });
    child.once('error', reject);
    child.once('close', (code, signal) => resolve({code, signal}));
  });
}

let completed = 0;
for (const gate of GATES) {
  try {
    const {code, signal} = await runGate(gate);
    if (signal) {
      console.error(`GATE RUNNER: FAIL (${gate} terminated by ${signal})`);
      process.exitCode = 1;
      break;
    }
    if (code !== 0) {
      process.exitCode = Number.isInteger(code) ? code : 1;
      break;
    }
    completed++;
  } catch (error) {
    console.error(`GATE RUNNER: FAIL (could not launch ${gate}: ${error.message})`);
    process.exitCode = 1;
    break;
  }
}

if (completed === GATES.length) console.log(`GATE RUNNER: ${completed}/${GATES.length} PASS`);
