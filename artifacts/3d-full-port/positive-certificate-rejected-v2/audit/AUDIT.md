# Positive certificate pair: reject promotion

The corrected `certificate-pair-v2` provides no consistent performance benefit.
Retain the original production Adapter and hold the candidate. Both strict
performance results remain **FAIL**; no retry or altered workload is recommended.
This audit concerns the frozen495-file **d1b9b87 resident baseline**, not the
newer working source or Dave-only changes.

| Metric | Day baseline -> candidate | Night baseline -> candidate |
|---|---:|---:|
| Scene CPU p95, ms | 29.964 -> 30.128 | 25.536 -> 28.434 |
| Clearance CPU / actor-stage call, ms | 1.298850 -> 1.326118 | 1.362505 -> 1.366957 |
| Clearance CPU / admitted second, ms | 92.623 -> 93.992 | 95.024 -> 97.324 |
| Actor CPU / actor-stage call, ms | 3.699475 -> 3.743004 | 3.694516 -> 3.735288 |
| Scene queries / actor-stage call | 69.7666 -> 68.4185 | 62.7913 -> 64.3753 |
| Scene queries / admitted second | 4975.17 -> 4849.32 | 4379.22 -> 4583.38 |
| Actor-stage calls | 3320 -> 3142 | 2444 -> 2531 |
| Admitted seconds | 46.5562 -> 44.3302 | 35.0432 -> 35.5488 |

One actor-stage call updates the whole Director, not one NPC. Targeted clearance
cost per call worsened2.10%/0.33%; per active second worsened1.48%/2.42%. Scene
p95 increased0.164/2.898ms. Scene query totals fell231625->214971 by day but rose
153462->162934 at night. The lower daytime count accompanies5.36% fewer source
stage calls and4.78% less admitted time; it is not an isolated cache benefit.
Inclusive placement overlaps and positive-hit totals include driver calls and
are not claimed actor-only. Exact totals and normalization are in FINDINGS.json.

The driver and source algorithm are identical between variants, but this is a
live normal-input run, not a replay of identical collision requests. Trajectory
and admitted-step differences prevent a causal percentage claim. Scope timers
overlap; no percentiles were added, and no driver time was subtracted from Scene
CPU. Driver p95 remains14.366/14.227ms baseline versus14.311/14.357ms candidate.
Correctness174/6 with two saved-query witnesses establishes the narrow behavior,
not a production speed benefit.

The new observer correction is evidenced here. Each variant retains its own
120 warmup plus1080 measured rows for each phase, all60+ live/supported/rigged.
Day/night frame and decision arrays differ, with first source positions
`[673.750122070313,1296]` and `[757.750122070313,2634]`. Per-phase active-time sums
reconcile independently; the admitted row subdivisions exactly reproduce all
four actor-stage totals3320/2444/3142/2531. There are no recorded lifecycle
discontinuities or excluded death/arrest relocations. All4800 frame receipts were
checked. This does not repair older reports' overwritten day arrays; their
documented evidence limit and original failures remain.

Both actual runs completed version/import/driver-contract/snapshot-contract/
export/native with exit0, no timeout or logged script/engine error. Candidate
also completed the retention contract. Both actual snapshot gates passed27/5;
candidate passed174/6 and both saved-query witnesses. The exact495 archive,
all prepared/post-native source bytes, exact common/candidate overlays, original
wrapper/helper pins, log hashes, actual executable hashes and eight1280x720 PNGs
were independently verified. Executables will be retained by hash, not copied.

No optimizer was promoted, no production file was edited, and no engine or Git
command was run by this audit. No Web, GPU, startup, shutdown, full-port completion
or16ms acceptance follows from successful evidence packaging. INPUTS.json pins
the immutable original artifacts; the paired comparison is retained unchanged.
