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
  // version-gate rides with docs-gate: same class, same origin. index.html said "v19"
  // through the whole v20 wave and Wave 4.1 while the README said v19 too, and the
  // operator lost an evening hard-refreshing a deploy that was already current.
  // The label was the bug. Consistency is gateable; which number is right is not.
  'version-gate.mjs',
  'module-gate.mjs',
  'sprite-gate.mjs',
  'npc-registry-gate.mjs',
  'legibility-gate.mjs',
  'presentation-gate.mjs',
  // phase1-lighting-gate rides behind presentation-gate in the same render-layer family.
  // Promoted standalone -> permanent 2026-07-19: Phase 1's lighting / grade / AO / emissive
  // invariants now run every commit. Nine counterexample modes red-tested.
  'phase1-lighting-gate.mjs',
  'recognition-gate.mjs',
  'concession-gate.mjs',
  // copper-sites-gate rides behind concession-gate — same invariant class, different resource:
  // concession proves one smoke loop across many rooms; this proves one heist engine across
  // many buildings, and that adding buildings cannot move the daily copper ceiling.
  'copper-sites-gate.mjs',
  // hitter-gate rides behind the two loops it must never beat: concession-gate
  // proves the one real high; copper-sites-gate proves the copper income the
  // craft consumes. This one proves the emergency hitter loses to the rock over
  // the FULL hit->high->crash cycle — the marathon, not the sprint — and that
  // neither acquiring nor using it adds a walk or mints anything back.
  'hitter-gate.mjs',
  // discovery-gate rides behind the recognition family it protects. recognition-gate's
  // zero-leakage proof watches the LEDGER; discovery routes around the ledger, so a
  // reveal that granted tier would leave that gate green. This one watches the door.
  'discovery-gate.mjs',
  // robbery-gate rides behind the income family (copper-sites, hitter) as their
  // mirror: they prove nothing mints; this proves the economy's first SINK only
  // subtracts (I-SINK-ONLY), can never take a progression key (I-NO-SOFTLOCK,
  // allowlist not denylist), robs only through the skid grabber's landed grab,
  // and stays governed — the mercy is the rate, not the outcome.
  'robbery-gate.mjs',
  // breakin-gate rides behind the income family and its sink: copper-sites proves
  // the one engine and the copper ceiling; robbery proves the sink only sinks;
  // this one proves the engine's two door kinds genuinely refuse (I-GATE-REAL)
  // and that break-ins ride their own governor, never copper's (I-NO-MINT-DRIFT).
  'breakin-gate.mjs',
  'solidity-gate.mjs',
  'runtime-smoke.mjs',
  // world-gate runs LAST, on purpose. It is a ruler over the shipped map, and the
  // SPEC expects it to read red until the operator rules on the findings it names
  // (a failing leg is a finding, not a defect in this branch). Last place means a
  // standing world reading can never mask a regression in the gates that
  // protect shipped behavior — the runner stops at the first failure.
  'world-gate.mjs',
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
