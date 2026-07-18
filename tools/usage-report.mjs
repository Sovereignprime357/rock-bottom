/**
 * usage-report.mjs — what did that actually cost?
 * ===============================================
 * Sums the per-call `usage` objects the clients themselves write to disk.
 * Transcribes nothing, estimates nothing.
 *
 * v2: THREE roots, not one. The first version read ~/.claude/projects and reported
 * 18,278 calls as if that were the ledger. AppData\Roaming\Claude\claude-code is 2.5x
 * larger and was never opened. Same failure as ORCHESTRATOR-NOTES entry #4: found an
 * instrument, stopped looking for better ones.
 *
 * WHAT IT STILL CANNOT DO: report a % of any limit. Anthropic publishes no formula,
 * and cache reads/writes/model tiers do not price like raw tokens. Any percentage here
 * would be invented. It measures what was spent, not what remains.
 *
 * WHAT IS NOT HERE AND CANNOT BE: claude.ai web chats. Those live on Anthropic's
 * servers. Nothing on this disk knows about them.
 */
import fs from "node:fs"; import path from "node:path"; import os from "node:os";

const ROOTS = [
  { name: "claude-code (~/.claude)", dir: path.join(os.homedir(), ".claude", "projects") },
  { name: "claude-code (AppData)",   dir: path.join(os.homedir(), "AppData", "Roaming", "Claude", "claude-code") },
  { name: "cowork/dispatch",         dir: path.join(os.homedir(), "AppData", "Roaming", "Claude", "local-agent-mode-sessions") },
];
const walk = d => { try { return fs.readdirSync(d,{withFileTypes:true}).flatMap(e =>
  e.isDirectory()?walk(path.join(d,e.name)):e.name.endsWith(".jsonl")?[path.join(d,e.name)]:[]); } catch { return []; } };

const rows = []; const seen = new Set();
for (const R of ROOTS) {
  for (const f of walk(R.dir)) {
    let L; try { L = fs.readFileSync(f,"utf8").split("\n"); } catch { continue; }
    for (const line of L) {
      if (!line.includes('"usage"')) continue;
      let j; try { j = JSON.parse(line); } catch { continue; }
      const u = j?.message?.usage; if (!u) continue;
      const ts = j.timestamp; if (!ts) continue;
      // dedupe: the same session can be mirrored across roots
      const id = j.message?.id || (ts + "|" + (u.output_tokens||0) + "|" + (u.cache_read_input_tokens||0));
      if (seen.has(id)) continue; seen.add(id);
      rows.push({ ts, root: R.name, model: j.message?.model || "?",
        inp: u.input_tokens||0, out: u.output_tokens||0,
        cw: u.cache_creation_input_tokens||0, cr: u.cache_read_input_tokens||0,
        side: !!j.isSidechain });
    }
  }
}
rows.sort((a,b)=>a.ts.localeCompare(b.ts));
const n = x => x.toLocaleString();
const bill = r => r.inp + r.out + r.cw;
const M = x => (x/1e6).toFixed(1) + "M";
const B = x => (x/1e9).toFixed(2) + "B";

if (!rows.length) { console.log("no rows"); process.exit(0); }
console.log("\n=================== EVERYTHING ON THIS DISK ===================");
console.log("deduped calls : " + n(rows.length));
console.log("earliest      : " + rows[0].ts);
console.log("latest        : " + rows[rows.length-1].ts);
const days = (new Date(rows[rows.length-1].ts) - new Date(rows[0].ts)) / 86400000;
console.log("span          : " + days.toFixed(1) + " days\n");

const agg = (key) => { const m={}; for (const r of rows) { const k=key(r);
  (m[k] ??= {c:0,inp:0,out:0,cw:0,cr:0}); m[k].c++; m[k].inp+=r.inp; m[k].out+=r.out; m[k].cw+=r.cw; m[k].cr+=r.cr; } return m; };
const show = (title, m) => { console.log(title);
  for (const [k,v] of Object.entries(m).sort((a,b)=>(b[1].inp+b[1].out+b[1].cw)-(a[1].inp+a[1].out+a[1].cw))) {
    console.log("  " + String(k).slice(0,26).padEnd(27) + n(v.c).padStart(7) + " calls | billable " + M(v.inp+v.out+v.cw).padStart(8)
      + " | cache-read " + B(v.cr).padStart(7) + " | output " + M(v.out).padStart(7)); }
  console.log(""); };

show("BY SOURCE", agg(r=>r.root));
show("BY MODEL",  agg(r=>r.model));

const T = rows.reduce((s,r)=>({inp:s.inp+r.inp,out:s.out+r.out,cw:s.cw+r.cw,cr:s.cr+r.cr}),{inp:0,out:0,cw:0,cr:0});
const billable = T.inp+T.out+T.cw;
console.log("=================== THE TOTALS ===================");
console.log("  fresh input (never seen) : " + M(T.inp).padStart(9));
console.log("  cache WRITE (park a page): " + M(T.cw).padStart(9) + "   ~1.25x price");
console.log("  OUTPUT (actual work)     : " + M(T.out).padStart(9) + "   most expensive per token");
console.log("  ---------------------------------------");
console.log("  BILLABLE-ISH total       : " + M(billable).padStart(9));
console.log("  cache READ (the glance)  : " + B(T.cr).padStart(9) + "   ~0.1x price -- the discount");
console.log("");
console.log("  re-read per word written : " + (T.cr/T.out).toFixed(0) + " : 1");
console.log("  what the cache saved you : ~" + B(T.cr*0.9) + " tokens of full-freight cost");
console.log("");
console.log("NOT INCLUDED, and it cannot be: every claude.ai web chat you have ever sent.");
console.log("Those live on Anthropic's servers. This disk has no idea they happened.");