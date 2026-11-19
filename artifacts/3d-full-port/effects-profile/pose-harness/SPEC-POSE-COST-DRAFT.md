# Exclusive pose-cost diagnostic draft

2026-11-19. Spec before code. This is an isolated instrumentation experiment, not
an optimization or performance acceptance. Root alone runs engines and exports.

Capture all current production `game3d` files except `.godot` cache into a pinned
archive, including the promoted feedback/dust/art source. Verify a second read of
every source byte before sealing it. This is explicitly a working-source snapshot,
not a claim of a committed revision. Do not copy an older indexing or effects
project over it. The reviewed sustained60 driver, its contract and MeasuredScene
remain byte-identical; two phases retain120 warmup plus1080 measured frames,
normal input, live minimum60, real physics/AI/clocks and the original16ms gate.

Only ActorAnimation and CharacterRoster receive tagged diagnostic additions.
Removing these blocks must reproduce every original statement, branch, return,
call and order exactly after line-ending normalization. No existing statement is
replaced. A new isolated static metrics resource has no GameState, RNG, pose,
geometry, event, save or input access. The probe only samples/reports counters
outside the unchanged MeasuredScene timing boundary.

## Scope and accounting

- Time `_reset_working_pose`, `_apply_bones`, `_sync_attachments` and
  `_human_contacts` around the complete existing function work. No per-bone clocks.
  Reset includes its global-cache clear. Apply includes exact comparisons and
  actual Skeleton setters. Attachments include their existing global cache,
  markers and transform comparisons. These scopes do not call one another.
- Distinguish helper work inside ActorPose.tick from construction/reset work
  outside it. Record calls, reset/apply slots, actual bone writes, attachment
  queries/writes, and IK calls. Counters are fixed numeric keys, never actor IDs.
- Track valid tick nesting in a bounded depth16 stack. At each tick exit,
  inclusive time minus directly nested child tick time gives that rig's exclusive
  tick interval. Sum exclusive intervals once across rigs. Root-tick inclusive,
  all-rig inclusive and direct-child inclusive remain separately labeled; the
  latter two overlap and must not be summed. All existing early exits remain in
  place and balanced. Invalid input returns before entering metrics.
- Counter/stack failures produce diagnostic-invalid counters, not gameplay control
  changes. The runner refuses stack imbalance, negative measured exclusive spans,
  overflow and incomplete1080-frame denominators. Current cast nesting is bounded;
  no depth cap is imposed on actual animation recursion.
- Preserve Scene/driver attribution by snapshots immediately before and after the
  existing driver and measured frame. Source calls keep the existing denominator.
  Metadata snapshots, clock calls and counters add overhead and can increase real
  frame time/catch-up. Do not subtract overhead, sum unrelated percentiles, label
  all pose time recoverable, or infer an uninstrumented speed result.

No attachment skip, touched-bone list, cache policy, LOD, geometry indexing or
quality change is part of this packet. The next decision requires these actual
exclusive measurements and the separately held indexing contract result.

## Provenance and execution

Pin the full source archive, all source files, the seven explicit diagnostic/workload
overlays, original reviewed wrapper/pins, official engine/template binaries, and
the exact MeasuredScene hash. Generate a distinct wrapper from the reviewed cost
wrapper, retaining hidden own-child launch, private user-data, finite timeout,
error-log scanning and immutable run directories. It uses this archive only,
never Git or advancing production. Three tagged stripping proofs cover ActorPose,
Roster and the report-only probe changes. Original wrappers remain untouched.

Diagnostic acceptance is always false. The runner accepts only the explicit
diagnostic reason and the unchanged performance failure message; all population,
workload, source, script, stack and evidence failures remain fatal. Raw files,
source inventory, report and executable hashes are retained. No engine has been
run by this author.
