# Exclusive pose costs - isolated diagnostic

READY for root's serialized validation; no engine has been run by this author.
Read SPEC-POSE-COST-DRAFT.md first. This packet measures costs and implements no
touched-bone, attachment, geometry, LOD or animation optimization.

The archive captures485 current production files with the promoted effects,
excluding only `.godot`. Snapshot identity is
`c3d25e0d7a3838ea043858a3183083c6ad0b0b0af7baf8c47fe2df63268b76f6`;
archive SHA256 is
`776bc541a72d0aa60f962a9da6c1fa31311dedd8f77d5ad874ef00e9bdfcbc4b`.
It is explicitly a working-source snapshot, not a Git commit. No original source,
held weighted-index file, earlier wrapper or evidence is modified.

Seven exact overlays are pinned: instrumented ActorAnimation and CharacterRoster,
new passive pose_cost_metrics and its small accounting contract, the report-only
performance probe, and the unchanged reviewed sustained driver/driver contract.
FullScene, Runtime, Adapter, world and all geometry remain exact archived bytes.
Three complete stripping proofs restore all original production/probe statements;
MeasuredScene and the sustained driver hashes are unchanged.

The preparation generator initially rejected an ambiguous substring and its
static checker caught a diagnostic string replacement affecting `returning`.
Both were corrected before handoff; the original sealed archive was reused,
without recapturing advancing production. Current checks pass:

```
python .build/3d/pose-exclusive-cost-draft/static-check.py
POSE EXCLUSIVE COST STATIC: PASS; 6149 checks
```

Python AST and PowerShell parser checks passed. These do not compile GDScript.
Root-only engine checks, then the fresh isolated release diagnostic:

```
Godot --headless --path .build/3d/pose-exclusive-cost-draft/game3d --editor --import --quit
Godot --headless --path .build/3d/pose-exclusive-cost-draft/game3d --script res://tests/test_pose_cost_metrics.gd
pwsh -File .build/3d/pose-exclusive-cost-draft/profile-pose-exclusive.ps1 -RunName <fresh-name>
```

The wrapper repeats import and both contracts in its own immutable run directory,
exports with the pinned official template, and uses private user data. It launches
only its own hidden children and terminates those children after the existing
finite timeout. It neither calls Git nor adds a `--frames` override.

Each phase retains120 warmup/1080 measured frames and live minimum60. Report field
`pose_cost_breakdown` has Scene/driver timing/count groups. Reset, apply, attachment
and analytic contact helper spans are separate, split inside/outside actual pose
ticks. Fixed scan/write/query counters show the work represented by each span.
Nested child ticks are removed from their parent's exclusive interval and counted
once themselves. Root-inclusive and all-rig/child-inclusive fields overlap;
never add them together. Time/counter bookkeeping leaves an honest residual.

Counters and timers add overhead; probe snapshots can increase frame intervals
and source catch-up. No subtraction or expected speedup is claimed. The wrapper
requires complete1080 denominators, actual nonzero pose/helper work, no invalid
stack accounting, and only the explicit diagnostic/performance failure reasons.
Acceptance is always false. Original16ms and population gates remain unchanged.
Raw logs, report, archive/source/export hashes and provenance stay with each run.

The weighted-index experiment remains a separate candidate. Its central exact
contract/regressions now pass, but it must not be mixed into this diagnostic or
credited with native/Web rendering or speed until those independent checks run.

Root approved a narrow import-metadata correction: six existing promoted probe
scripts in the frozen archive had no generated `.gd.uid` yet. The wrapper and
static checker now allow exactly those six named sidecars in addition to the four
new diagnostic/workload sidecars. Original archive bytes and source hashes remain
unchanged. No arbitrary extra file is allowed. Corrected static count is6150.
