/**
 * usage-report.mjs — what did that actually cost?
 * ===============================================
 * Reads Claude Code's own per-call transcripts (~/.claude/projects/**\/*.jsonl).
 * Every assistant message carries a real `usage` object written by the client at
 * request time. This transcribes nothing and estimates nothing: it sums what the
 * machine already recorded.
 *
 * WHAT IT CANNOT DO, said out loud so nobody builds on a guess:
 * It cannot tell you "that was 11% of your daily limit." Anthropic does not publish
 * the limit formula, and cache reads / cache writes / model tiers do not price the
 * same as raw tokens. Any percentage here would be invented. What it CAN do is
 * measure EMPIRICALLY: find the 5h window where you actually hit the wall, and
 * report what was consumed inside it. That is a derived ceiling, not a guessed one.
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const ROOT = path.join(os.homedir(), ".claude", "projects");
const args = process.argv.slice(2);
const SINCE = args.find(a => a.startsWith("--since="))?.split("=")[1];
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith(".jsonl") ? [path.join(d, e.name)] : []);

const rows = [];
for (const f of walk(ROOT)) {
  let lines;
  try { lines = fs.readFileSync(f, "utf8").split("\n"); } catch { continue; }
  for (const line of lines) {
    if (!line.includes('"usage"')) continue;
    let j; try { j = JSON.parse(line); } catch { continue; }
    const u = j?.message?.usage; if (!u) continue;
    const ts = j.timestamp || j.message?.timestamp; if (!ts) continue;
    if (SINCE && ts < SINCE) continue;
    rows.push({
      ts, model: j.message?.model || "unknown",
      inp: u.input_tokens || 0, out: u.output_tokens || 0,
      cw: u.cache_creation_input_tokens || 0, cr: u.cache_read_input_tokens || 0,
      sidechain: !!j.isSidechain, session: path.basename(f, ".jsonl"),
    });
  }
}
rows.sort((a, b) => a.ts.localeCompare(b.ts));
const n = x => x.toLocaleString();
const bill = r => r.inp + r.out + r.cw; // cache READS are the cheap part; keep them separate

console.log(`\nCLAUDE CODE USAGE — read from ${rows.length ? n(rows.length) : 0} logged API calls on disk`);
console.log(`source: ~/.claude/projects/**/*.jsonl  (the client's own accounting, not an estimate)`);
if (!rows.length) { console.log("no rows"); process.exit(0); }
console.log(`range : ${rows[0].ts}  ->  ${rows[rows.length-1].ts}\n`);

const by = (key) => {
  const m = {};
  for (const r of rows) { const k = key(r); (m[k] ??= { calls:0, inp:0, out:0, cw:0, cr:0 });
    m[k].calls++; m[k].inp+=r.inp; m[k].out+=r.out; m[k].cw+=r.cw; m[k].cr+=r.cr; }
  return m;
};
const table = (title, m, sortByBill=true) => {
  console.log(title);
  const e = Object.entries(m).sort((a,b) => sortByBill
    ? (b[1].inp+b[1].out+b[1].cw)-(a[1].inp+a[1].out+a[1].cw) : a[0].localeCompare(b[0]));
  console.log("  " + "key".padEnd(30) + "calls".padStart(7) + "billable".padStart(13) + "cache-read".padStart(13) + "  (in/out/cachewrite)");
  for (const [k, v] of e) {
    const b = v.inp+v.out+v.cw;
    console.log("  " + String(k).slice(0,29).padEnd(30) + String(v.calls).padStart(7) + n(b).padStart(13) + n(v.cr).padStart(13)
      + `   ${n(v.inp)}/${n(v.out)}/${n(v.cw)}`);
  }
  console.log("");
};

table("BY MODEL", by(r => r.model));
table("BY LOCAL DAY", by(r => new Date(r.ts).toLocaleDateString("en-CA")), false);

// rolling 5h windows — the actual limit shape
const W = 5 * 3600 * 1000;
let worst = null;
for (let i = 0; i < rows.length; i++) {
  const t0 = new Date(rows[i].ts).getTime();
  let b = 0, c = 0;
  for (let j = i; j < rows.length && new Date(rows[j].ts).getTime() - t0 < W; j++) { b += bill(rows[j]); c++; }
  if (!worst || b > worst.b) worst = { b, c, start: rows[i].ts };
}
console.log("HEAVIEST 5-HOUR WINDOW (the shape of the session limit)");
console.log(`  starting ${worst.start}`);
console.log(`  ${n(worst.b)} billable tokens across ${n(worst.c)} calls`);
console.log(`  ^ this is EMPIRICAL. It is what a real window cost, not a published cap.\n`);

const sc = rows.filter(r => r.sidechain);
console.log(`SUBAGENT (sidechain) SHARE: ${n(sc.length)} of ${n(rows.length)} calls, ${n(sc.reduce((s,r)=>s+bill(r),0))} billable tokens`);
console.log(`  fan-out is where the budget goes. 114 agents is not free.\n`);