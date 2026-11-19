# Query-resource release pair — root execution only

READY for serialized root review/run. No engine or Git was run by the author.
The candidate already passed root's actual Adapter634 and Navigation4759 checks;
those logs and their tested five-file overlay are pinned here.

One existing wrapper is necessary because the older indexed-performance wrapper
hardcodes an older491-file archive and two indexing files. This derivative keeps
its process isolation, watchdogs, workload and MeasuredScene intact. Reversible
transforms record only the explicit source/variant/output changes, query overlay
list, exact generated UID allowlist and final source-inventory check. Neither
variant includes indexing or another optimization.

Both runs use exact current-resident495 archive `ede8f5bf42ed80f4227d3d1d17b69f89c30eab65722932557ed3334c26a46ee2`.
Baseline remains original. Query_resource replaces only Adapter production code
and the four centrally tested test/observer files. Three sustained-workload files
are copied byte-for-byte from the reviewed wrapper into both runs. No code in
the measured scenario, driver or timing class changes.

Safe static checks:

```powershell
python .build/3d/query-resource-performance-draft/static-check.py
python .build/3d/query-resource-performance-draft/test-comparison.py
```

Root-only serial native pair, using a new name:

```powershell
pwsh -NoProfile -File .build/3d/query-resource-performance-draft/run-paired.ps1 -RunName query-pair-v1
```

It creates fresh baseline/query_resource directories under
`.build/full-port/query-resource-performance`, imports each exact source,
repeats the unchanged driver contract, exports with the pinned official template,
and runs both120+1080-frame phases. Each hidden owned child has the inherited
900s watchdog and10s termination/stream grace. User data is private to each run.
Existing run directories and existing comparison output are refused.

The offline comparison validates raw report hashes, exact retained source and
executable bytes, every frame's60-actor requirement, unchanged report settings,
source identities, lifecycle continuity and complete phase denominators. Only
the original16ms diagnostic failures are allowed; they remain in the output.
It reports Scene/driver p50/p95, actual stage counts, actor/clearance/motion/pose
per-call and per-active-second costs, models per rendered frame and actual
physics queries excluding the driver. Signed differences are descriptive, not
a claimed causal speed percentage. One pair cannot authorize promotion.

If the native pair completes but comparison is interrupted before it writes any
output, the exact offline command is:

```powershell
python .build/3d/query-resource-performance-draft/compare-pair.py --run-name query-pair-v1
```

It refuses overwriting a prior comparison. This helper is not a profiler.

Author validation initially caught an incorrect scalar assumption about the
existing `active_ms` report field. The helper now reads its actual
`{frames,total}` structure, validates its1080 samples, and reconciles reported
per-call/per-active-second values. Twelve offline test groups include short
phases, hidden sub60 frames, lifecycle/relocation, wrong denominators, source
mutations, unlisted index files, workload drift, child timeout and error cases,
and refusing to relabel an actual16ms failure as acceptance.
The old contact diagnostic is a pinned arithmetic fixture only; no new native
result is inferred from those tests.
