import { spawn } from 'node:child_process';
import path from 'node:path';

const TOOLS = import.meta.dirname;
const ROOT = path.resolve(TOOLS, '..');
const GATES = [
  'module-gate.mjs',
  'npc-registry-gate.mjs',
  'legibility-gate.mjs',
  'runtime-smoke.mjs',
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
