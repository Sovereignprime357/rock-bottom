# SPEC — Bounded actor detours P04b

Captured before implementation, 2026-11-18; root approved this packet under the full
port and combat contracts. Source authority is `src/systems/physicality.js:241–325`
and `src/systems/npc_ai.js:495–497`. This is local steering plus real movement
consumer evidence, not a claim that the full60-actor rendered game meets16ms.

## Authority and exact units

`RockBottomActorNavigation` is a RefCounted helper. It owns only static collision
indexing, ephemeral path caches and a planning work queue. GameState/Combat still
own actor records. WorldAdapter still executes every real physics sweep and returns
its actual result. Navigation never writes authoritative x/y, changes speed, rolls
gameplay RNG, moves the player or reports a planned path as completed movement.

The constructor's `world_bounds_px` is source-plane Rect2, normally(0,0,8600,5600).
All body x/y/w/h, intended positions, goals and returned steering positions are
source pixels. Positions are actor top-left; goals and internal waypoints are body
centers. Input obstacle records use **world-metre AABBs**, matching the existing
FullNeighborhood obstacle API; mapping is world X/Z divided by0.04 plus(1050,840).
Obstacle vertical extents and registered actor height remain metres. Feet are0.06m.

Each record is `{id?,owner,bounds:AABB,enabled?}`. If no ID is supplied the indexed
owner/record order produces a stable ID for that topology revision. The helper does
not retain scene bodies; root supplies actual enabled collision and refreshed AABBs
when a mutable cart/prop changes. AABB geometry is conservative for rotated boxes
and cylinders. Final physics, never the AABB approximation, decides movement.

NPCs use the existing axis-aligned BoxShape dimensions(w*0.04,height,h*0.04), not the
player's0.48m capsule and not a radius made from only width. Horizontal inflation
uses half-width/half-depth plus the same0.002m query margin. Waypoints alone receive
a0.0004m numerical corner allowance; inflating blockers by that extra allowance
would falsely classify a physically tangent starting body as already inside a wall.
Vertical candidates intersect[feet,feet+height]. No full-building
envelope replaces its individual walls; real door gaps remain represented.

## API and adapter hook

```
new(world_bounds_px: Rect2 = Rect2(0,0,8600,5600))
set_obstacles(records: Array) -> bool
update_obstacles(owner: String, records: Array) -> bool
begin_frame(frame_serial: int, active_ms: float) -> void
steering(body: Dictionary, intended_px: Vector2, goal_center_px: Variant,
         height_m: float = 1.8) -> Dictionary
note_motion(body: Dictionary, before_px: Vector2, intended_px: Vector2,
            result: Dictionary, goal_center_px: Variant, height_m: float = 1.8) -> void
invalidate_actor(id: String) -> void
reset() -> void
metrics() -> Dictionary
```

`steering` returns `{intended:Vector2,detouring:bool,status:String}` and does no
physics. Adapter calls it before its raw sweep. Adapter passes the **original**
requested intended position to `note_motion` after physics, with actual finite
`{position,blocked}`. The model commits only that raw physics result. A failed
first direct move may retain its safe slide while a detour is queued for a later
frame; it receives no bonus movement after the asynchronous plan becomes ready.

Player calls bypass the helper. Charges/stop_on_block invalidate the actor's cache
and bypass steering/queueing, retaining straight swept motion and collision-driven
cooldown. Nonzero goal-less movement/knockback clears the path. A zero-motion zone
clamp must not erase an otherwise valid path: the source returns on zero step before
its path-clearing branches, and Director currently submits such clamps each tick.
Root calls `reset` on state replacement and invalidates IDs on despawn/reuse.

Root delegated the WorldAdapter hook/contact correction to this packet after the
first real-sweep counterexample. Godot's box cast returned center285.9922px at a
wall whose body-expanded face is286px; the next0.002m-margin overlap query rejected
that cast endpoint. Do not weaken overlap checks. Raw movement now retains a small
0.0025m skin on blocked casts, verifies the returned position with the same live
query margin, and uses bounded bisection toward the known-clear origin only if a
glancing contact still fails. A margin-blocked intended endpoint counts as blocked
even when the raw cast fraction is1. Every returned endpoint is clear or is the
unchanged rejected input; contact/charge status reflects the actual collision.

WorldAdapter exposes `begin_navigation_frame(render_serial,active_ms)`,
`reset_navigation()`, `update_navigation_obstacles(owner,records)`,
`invalidate_navigation_actor(id)` and `navigation_metrics()`. It owns the helper,
initializes from world obstacle records, and detects bound GameState dictionary
epoch replacement. Runtime integration remains root-owned. Null-goal raw consumers
and player movement do not receive autonomous steering.

Registration is an actor lifetime boundary: `register_body(id,node,height)` clears
any prior path for that ID, and `unregister_body(id)` removes its weak registration,
height cache and pending navigation. Root unregisters before rig replacement or
despawn, and invalidates on `actor_died` without removing the visible corpse.
State-epoch reset also clears metadata-only height caches.
If placement exhausts its bounded recovery search for an unregistered actor, discard
that ID's metadata cache too: a refused pre-append spawn never gets a rig/despawn
callback. Repeated refused spawns must not accumulate orphan profile entries.

An actor may be placed or moved before its rig exists. Unregistered actors resolve
height from `Roster.visual_for_actor` and `Roster.definition`, cached by ID and
resolved visual; this never builds a mesh. Live registered rigs retain the fast
height lookup. Combat's detached geometry packet additionally carries the existing
`name`, `sprite` and `isOmalleyFallen` scalar hints, so a newly spawned cop can be
checked before it is appended to `host.npcs`. No stats, coordinates or actor identity
are changed. An ID-only query can resolve a current host actor or reuse its cached
profile. Unknown fixture identities retain the existing1.8m fallback. Regression
queries use actual cop1.91m/Brendan1.86m profiles beneath a lintel that would admit
the former1.8m fallback, proving correct first placement and movement clearance.

## Local plan and lifetime

Static collision records are indexed once in8m/200px buckets, with per-query body
inflation and vertical filtering. No per-frame full-world scan, world grid copy per
actor, navigation server bake or `FullNeighborhood.find_route` call is permitted.

On actual obstruction, find the nearest indexed collider on the requested segment.
First try the source's eight directed two-corner routes around that collider. Both
local legs must be clear against all nearby standing solids. The final conceptual
leg must clear the original collider; it may meet a later obstruction, matching the
source's chained local detours. Rank by walked length plus distance to actual goal,
with deterministic tie order. Cache the selected corners and the current goal.

If adjacent wall/prop components invalidate all eight candidates, grow a bounded
local visibility graph from only the obstructing connected components: at most16
colliders and64 corner nodes in a64m/1600px local region. Edges are checked lazily
with the same indexed body-aware segment query. Reaching a corner that clears the
original blocker is local progress, not a claim of a complete route to a far goal.
The graph cannot invent an aperture, cross a solid, accept an uncleared endpoint,
or silently call a global planner. A capped/unreachable request reports an explicit
failed/deferred status; normal safe physics movement remains the fallback.

Cached steering travels at most the original requested step length. It clamps to
the next waypoint and does not spend the leftover step on a second waypoint, like
the source. Invalidate on>48px target drift (exact source threshold), shape/height
change, topology revision, observed position discontinuity, waypoint obstruction,
or sustained lack of movement. Reuse until completed rather than replanning each
frame. Unseen actor caches expire after10 active seconds; failed local requests wait
250ms before retry. Keep at most256 actor entries and128 queued requests.

## Work budgets and fairness

`begin_frame` receives an actual render-frame serial, not the number of simulation
substeps. The same serial never resets any budget; catch-up steps cannot multiply
work. Per-frame hard caps: four newly started jobs and192 segment/visibility tests.
Soft planning deadline:1000 microseconds, checked between bounded units. Jobs yield
with their phase/cursor retained and resume FIFO with round-robin work slices;
retry cannot jump ahead of an older request. No whole graph is rebuilt on yield.
Deadline is a CPU goal, not an absolute guarantee on arbitrary hardware; expose
actual maximum/p95 cost, work counts, queued age and deferred/failure counts.

Pending work does not count as success and never substitutes an unverified straight
path. Idle/paused frames do not advance active-time cache expiry. Metrics distinguish
index construction, planning, cache hits, raw collision queries (adapter-owned),
bounded-region failures and source-compatible local paths.

## Verification and evidence

`test_actor_navigation.gd` checks the pure contract plus a real PhysicsDirectSpace
consumer using the actual BoxShape and collision mask/margins: wall detours, repeated
props, adjacent components/U bays, real doorway width, short/tall actor overheads,
tangent starts, unreachable goals, boundaries, target48/48.001 drift, shape changes,
teleport/cache reuse, moved/disabled cart records, reset, no-goal/zero clamp and charge
bypass. Every committed movement is cast physically and checked for penetration;
path records alone do not pass. Preserve requested speed and return actual blocked
results, including on stale topology. Bound repeated-frame budget and fairness under
simultaneous real actor-shape requests. No charge bends around a corner.

`navigation_probe.gd` uses full authored world geometry and56 canonical day1 bodies
plus four source cop-shaped fixtures, real movement queries and deterministic goals.
Report hardware/engine, index cost, planning p50/p95/max, hard-work maxima, starvation
and route progress into `.build/full-port/p04b/`. This motion-consumer probe is not a
claim of production AI/render/rig performance. Full Director+Combat+rig stress remains
a separately required native/Web integration gate. Root runs all Godot processes.

## Native production composition probe

`full_actor_performance_probe.gd` instantiates the actual FullScene and wraps its
unchanged `_process` call for CPU timing. Actual FullRuntime, Combat, ActorDirector,
WorldAdapter, authored roster rigs, animation LOD, HUD, hands and Compatibility
rendering remain enabled. Start with56 canonical day-one records, set source wanted4
once, and let production police spawning create four real cop/Brendan actors. No
fixture clones, invented identities, uniform movement consumers or no-op domain
adapters stand in for production actors. Require at least60 live, supported actors
and matching visual instances throughout each measured phase.

Two phases reset the isolated state once each: daytime core streets and nighttime
train-yard streets. Each uses120 warmup frames and1080 measured frames by default,
capped at1200 measured frames. Initial player placement, RNG seed and day phase are
explicit test setup. Source speeds, statistics, role flags and subsequent simulation
are unchanged. A fixed street loop is planned once before measurement; ordinary
bounded input then drives the real controller. No per-frame teleport, global actor
route lookup, forced invulnerability or actor relocation is allowed. The script
uses only an isolated save destination under its evidence output directory.

Report hardware/engine/renderer, source and relevant script hashes, exact source
actor IDs/profiles and route setup, complete scene CPU and engine process monitor
p50/p95/p99/max, frame intervals, frames above16ms, rendered draws/objects/primitives,
memory, physical query counts, planner work/age, actor count minimum, actual movers,
charges/projectiles and lifecycle events. Measure diagnostics outside the wrapped
scene CPU interval and disclose that total frame intervals include probe bookkeeping.
Validate actual body clearance at phase boundaries, capture native day/night frames,
and retain the ordinary presentation lifecycle.

Strict acceptance requires both phase CPU p95 values below16ms on the reported
native machine, no missing visuals or dependencies, no penetration, at least60
supported live actors/rigs, and navigation hard caps preserved. Missing source
handlers (currently the skid_lurch robbery domain before P11) are real blockers:
record them, keep useful measurements, and return failure. `--diagnostic` may return
success after writing a complete diagnostic artifact, but its JSON acceptance stays
false and its console result must say DIAGNOSTIC, never PASS. Native CPU success is
not a Web measurement or a GPU timing claim. Root owns all executions and reviews.

## P04b exact placement certificate optimization

Approved after the real60 diagnostic: reduce repeated positive origin-overlap queries,
not collision accuracy. WorldAdapter may reuse only its last positive placement per
body ID, keyed by exact source point, logical width/depth, resolved physical height,
current Engine physics frame, current begin_navigation_frame render serial, and
collision revision. Feet, collision mask1 and query margin.002m remain fixed parts
of this contract. The certificate expires on either frame change; no approximate
position, persistent clear region, negative result, or geometric path is a certificate.

Only placement/origin checks can reuse it. Every actual movement still performs its
cast and uncached endpoint/contact/skin checks. Register/unregister/actor invalidation,
model epoch/reset and obstacle updates clear applicable certificates. Any other
standing-collider writer must call invalidate_placement_cache after mutation and
before querying movement; this is mandatory even within a single render/physics frame.
The dictionary contains at most one point per queried body and clears each frame.
Counters report hits and actual overlap queries separately from cast/ray totals.

Regression evidence uses real geometry: repeated origin requests reuse one positive
answer, movement/shape/height/frame/epoch changes do not reuse it, failed placement is
never cached, explicit topology invalidation rejects newly obstructed points, and
movement casts plus endpoint proof remain present after a cache hit. Re-run existing
actual physical detour/charge/contact tests and the native production probe centrally.

Accepted endpoint-publication correction, 2026-11-18: `allow_certificate=false`
disables certificate **reads**, not publication of a newly proven positive result.
Every successful actual overlap query may replace that body's last positive point,
under the unchanged render/physics/revision/shape key. A movement endpoint still
receives its mandatory fresh query; after Combat commits that returned point, the
next origin check may reuse it. A false-call against an already certified point
still performs the real query. Negative queries erase the body's certificate.
Regression commits the actual movement result before the next-origin check, tests
false-call bypass/publication and retains all same-frame mutation/shape/frame/
epoch/cast/contact counterexamples. No persistent/approximate clearance is added.

Native measurement correction (2026-11-18): screenshots and clearance audits run before the initial120 active warmup frames, not immediately before measurement. Godot monitors can retain a value for up to1second (https://docs.godotengine.org/en/4.5/classes/class_performance.html); a PNG capture stall otherwise contaminates the sampled engine-process window. Keep scene and whole-engine p95 thresholds unchanged, report every measured frame, actor counts and unfiltered intervals; no artificial pause or sample dropping within measurement.

Full Runtime preflights all live actor capsules through the existing clear_placement adapter before first ready/fresh/restore presentation. Commit placements only when every point is finite and valid. The Director still validates subsequent movement, but cannot be the first repair after an actor has already been displayed intersecting geometry. Native initial clearance remains a requirement before warmup; do not move that audit past the bug.


Native measurement may enable a Runtime-only diagnostic profile dictionary. It measures
movement, state/ambient, combat timers, memory/day/territory, quests/pickups, AI, projectiles/boss
and progression with monotonic microseconds; it never participates in saved state, RNG, dt,
input, governors or outcomes. Disabled normal play takes no timestamps. The actual60 probe
reports these nested scopes to explain full frame failures; isolated planner timings are not
substituted for the whole frame budget. Static prop ID dispatch indexes preserve source order
and rebind only with their existing epoch/reset; they do not cache live action eligibility.

### Query-local height reuse — 2026-11-18

The frozen release attributes over4ms p95 to actor clearance. Within one synchronous
query construction, resolve the current authored height once and pass that exact value
to shape selection and vertical placement. `_clear` already resolves height for its
certificate key and may pass it to the actual query. No cross-frame height assumption,
new clearance certificate, reduced overlap/cast count or asynchronous retained snapshot
is introduced. Calls without a resolved height still resolve the current actor profile.
Existing shape-change, Fallen-priest, cache-invalidation and physical-contact gates apply.
