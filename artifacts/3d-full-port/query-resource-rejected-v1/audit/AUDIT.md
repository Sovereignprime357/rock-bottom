# Query-resource pair: reject promotion

The completed `query-pair-v1` diagnostic provides no consistent benefit for the
private query-resource pool. Keep the candidate isolated and held; retain the
unpooled production Adapter. No retry, shortened workload or new profiler is
recommended. Both original strict performance results remain **FAIL**.

| Observed metric | Day baseline â†’ candidate | Night baseline â†’ candidate |
|---|---:|---:|
| Scene CPU p95, ms | 30.467 â†’ 31.764 | 26.950 â†’ 30.274 |
| Driver CPU p95, ms | 14.189 â†’ 14.191 | 14.023 â†’ 14.258 |
| Actor CPU / actor-stage call, ms | 3.761280 â†’ 3.746505 | 3.596337 â†’ 3.754210 |
| Clearance CPU / actor-stage call, ms | 1.289929 â†’ 1.349247 | 1.300272 â†’ 1.379747 |
| Motion CPU / actor-stage call, ms | 1.200588 â†’ 1.125894 | 1.033167 â†’ 1.096719 |
| Clearance CPU / admitted second, ms | 93.855 â†’ 94.844 | 94.068 â†’ 98.898 |
| Admitted seconds | 44.887588 â†’ 48.410987 | 42.587566 â†’ 43.751118 |
| Actor-stage calls | 3,266 â†’ 3,403 | 3,081 â†’ 3,136 |
| Scene physical queries excluding driver | 267,264 â†’ 236,046 | 181,010 â†’ 213,008 |

An actor-stage call is the whole Director update, not one NPC. The targeted
clearance cost per such call worsened 4.60%/6.11%. Scene p95 increased 1.297/3.324ms.
The day-only actor total reduction0.39% and motion reduction6.22% do not offset
this: those metrics worsen at night, and the normal world trajectories differ.
The pool's additional lease/reset overhead is a plausible explanation, but this
pair does not isolate that overhead and does not prove a causal percentage.

Both variants use the same source archive, driver algorithm and fixed frame
counts, not a replay of identical query requests. Candidate admitted time rose
7.85%/2.73% and actor-stage calls rose4.19%/1.79%; queries fell11.68% by day and
rose17.68% at night. Thus lower total or per-active-second cost in a single scope
cannot be read as an allocation saving. All normalized values above were
recomputed from original totals and denominators. Scope timings overlap; p95
values were not added or subtracted to infer a replacement frame time.

The actual wrapper completed cleanly: version/import/driver-contract/export/native
all exited zero without timeout or script errors. Both variants completed120
warmup and1080 measured frames in each phase; all1200 per-phase receipts retained
at least60 live, supported, rigged actors. No lifecycle discontinuity or excluded
arrest/death relocation occurred. Driver/source stats and AI were not altered by
this audit. The prior physical differential gates remain Adapter634 and
Navigation4759; their correctness does not establish a speed benefit.

The original495 archive entries, prepared overlays, retained source bytes after
import/export/native, both executables, raw report/provenance hashes and staged
Godot-log hashes were independently verified. Both variants receive the same
three workload files (two additions and one replacement) and two generated UIDs.
Candidate additionally received the exact five centrally tested files and two
observer UIDs; its only production
change is world_adapter.gd. No indexed-roster composition entered either variant.
Both ran official Godot4.5.1 Windows Compatibility, RTX3080/i9-11900K,1280Ã—720,
MSAA4, vsync off,60fps cap.

The held engine-process monitor p95 also worsened67.250â†’70.230ms by day and
63.661â†’68.268ms at night; it is a frame-weighted held maximum, not independent
per-frame CPU or GPU time. This audit makes no GPU, Web, startup, shutdown,
full-port completion or16ms acceptance claim.

The comparison SHA256 is
`8e33c3bf7f1c3f801c6a797869e7b4ae4e613265aa879bbce2b72a49fd65162b`.
The exact source archive is
`ede8f5bf42ed80f4227d3d1d17b69f89c30eab65722932557ed3334c26a46ee2`.
All evidence paths and hashes are retained in INPUTS.json; none of the original
reports, wrapper files or candidate files was changed. The current production
Adapter still hashes to the baseline
`0dc4bbca7c969104da2c400884ea04a24ea30b14c61a4e85249ce8aa7f3f8802`.
No Git command or engine was run for this audit; the root's repository-clean
statement was not independently replaced with a Git claim.
