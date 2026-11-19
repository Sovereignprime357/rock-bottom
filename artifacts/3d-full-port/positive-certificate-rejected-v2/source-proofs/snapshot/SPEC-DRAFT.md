# Native performance observer: independent phase snapshots

Spec before code. This is an isolated test-observer correction; production,
source simulation, normal-input driver, timers, MeasuredScene, thresholds,
120+1080 sampling and source physics remain byte-for-byte unchanged. No engine
or performance run is part of authoring this packet. Old evidence is immutable.

The old `_phase` return record retains four member arrays by reference:
`driver_decisions`, `workload_frames`, `lifecycle_timeline`, and
`population_timeline`. The next phase clears/reuses these arrays. Consequently,
the first returned phase acquires the second phase's timelines before final JSON
serialization. Actual retained reports confirm identical day/night frame rows.
This does not rewrite earlier scalar CPU distributions, counters, min population
or strict performance failures, but invalidates independent day-frame timeline
claims. `AUDIT-LIMITS.md` records the precise evidence boundary without relabeling
old failed reports.

Change only the report return boundary: route the complete `_phase` Dictionary
through `snapshot_phase(record)`, a pure `record.duplicate(true)`. It recursively
copies every returned Dictionary/Array, not a handpicked four-field subset.
All current leaves are JSON-compatible values, String/StringName and math value
types; there are no Node, Resource, RefCounted or callable leaves to deep-clone.
An explicit return-field/producer census and recursive test witness check that
assumption. Other nested maps/arrays currently local or reassigned are copied
as well, protecting both directions from later mutation.

The snapshot occurs after measurement stops, post-run clearance/capture and
derived statistics. It must not enter `_drive`, `_process`, an admitted Runtime
step or the measured time window. It adds no yield, input, physics, clock read,
RNG use or owner write. Field values/order and scalar failure conditions stay
unchanged. Setup-failure records contain only scalars and need no new behavior.

Regression uses the actual new static return-boundary helper without starting a
scene. Hold an original by-reference record and a corrected snapshot; clear and
refill the four same arrays as phase two does. The original must demonstrably
lose day evidence while the corrected snapshot retains it. Exercise full1200
rows and nested decision/actor/stat/route/navigation dictionaries, mutate every
mutable returned field and also mutate the snapshot in reverse. Two snapshots
must remain independent with exact original scalar/statistic/failed acceptance
data. Require all bounded groups to finish; errors cannot masquerade as PASS.

The old paired wrappers and all raw profiles remain held. New pair manifests
must explicitly pin this corrected common probe and its regression in both
variants, keeping the driver and MeasuredScene identical. No existing source
or evidence pin may be silently replaced. Focused root validation precedes any
new pair. Indexing and positive-certificate owner variants remain separate.
