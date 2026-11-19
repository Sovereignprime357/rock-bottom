# Correction to earlier per-phase timeline claims

This addendum preserves all earlier raw reports, screenshots, profiles, comparisons
and failure decisions. It does not regenerate or relabel them.

The common sustained probe SHA256
`5013ed6ed7bee55213bc9f84060d9a5fbb68e44ddc9cf95fe3526fd4bcf58bef`
returned four reused Array references from `_phase`. Starting phase two cleared
and filled those arrays before `_write_report` serialized phase one. Both retained
query-pair reports reproduce the defect:

| Raw report | SHA256 | Day / night Scene p95 | Actor-stage calls |
|---|---|---|---|
| `query-pair-v1-baseline/evidence/full-actor-performance.json` | `7f912e6ba942aa7e3798db7be8fd53e6527c0d8b9ff954f2abaa89c6dbaf8c6b` | 30.467 / 26.950ms | 3266 / 3081 |
| `query-pair-v1-query_resource/evidence/full-actor-performance.json` | `46339efc128e8bfd2802e201b6cab8acf587bbf599515691fe58bd22c0dfe5da` | 31.764 / 30.274ms | 3403 / 3136 |

Paths are under `.build/full-port/query-resource-performance`. In each raw report,
day and night `driver_decisions`, `workload_frames`, `lifecycle_timeline` and
`population_timeline` compare equal. Day's initial position is `[660,1296]`, but
its first retained frame position is the night row `[757.750122070313,2634]`.
Baseline's two phase decision arrays each contain218 night decisions; candidate's
each contain223. The day `driver_work.decisions` scalar still correctly differs
(228 baseline,244 candidate), demonstrating that the overwritten arrays are not
independent day receipts.

Withdraw the earlier claim that those raw day timelines independently prove all
120 warmup and1080 measured day frames, day threat/decision history or day event
ordering. The old comparator checked the serialized second-phase rows twice.
Day scalar min-population and timing distributions were accumulated in separate
phase locals; they are still useful limited evidence, not a replacement for the
missing independent timeline. Night rows remain the last phase's records. The
old body-counter attribution reports derived from this observer require the same
timeline limitation; their separately computed counter totals are not thereby
rewritten. Do not derive day decision rates or per-frame correlations from the
aliased arrays.

The scalar CPU/active-time/stage totals and raw strict16ms failures remain. Query
resource promotion remains rejected. This correction neither produces a pass nor
justifies subtracting probe overhead from Scene CPU. A new snapshot-only common
observer is required for future pairs; both variants must use its exact same
bytes and still satisfy the unchanged workload and acceptance rules.

All63 return fields were inspected. Four reused arrays were demonstrably unsafe;
`driver_input_counts` is reassigned to a new Dictionary at each phase and therefore
did not exhibit the defect. Other returned arrays/maps are fresh phase locals,
stats dictionaries, actor manifests, ID lists, an already copied event counter,
or the fresh `navigation_metrics()` snapshot. Their leaves contain no Node,
Resource or callable. The correction snapshots the entire return Dictionary
recursively so none depends on that current allocation detail.
