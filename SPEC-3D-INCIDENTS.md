# SPEC — Neighborhood incidents P14b

Captured before generation, 2026-11-18. Parent approved a bounded model/oracle
packet. Root owns Runtime activation, shared source, engine runs and integration.
This packet does not activate invisible incidents in the live scene. A subsequent
original incident presenter and actual trajectory/collision review are required.

## Source inventory and authority

Active `src/systems/incidents.js` owns11 behavioral functions and6 definitions with
24 timed beats. Definitions already exist in exported Content; no copied dialogue
table or invented NPC identity is added. IDs and durations are runaway_mattress25s,
possum_inventory30s, laundromat_walkout29s, yuri_receipt28s, park_dry_committee28s,
and ticketed_luggage31s. Four moving prop kinds, receipt sheets, sprinkler, possum
and pigeons are scene actors. They never enter GameState.npcs, enemy targeting,
interaction priority, faction rewards, persistent corpses or the economy.

New files: incident_system.gd, test_incidents.gd, tools/3d-incidents-oracle.mjs,
tests/fixtures/incidents_reference.json and this contract. One owner references the
existing GameState, spatial adapter and Communications. All source state remains
in s.incident, s.incidentT, s.incidentPaperT, s.incidentWetT and four existing flags:
incidentDay, incidentMask, incidentsToday, lastIncidentId. Active actors are never
saved; flags retain the existing save codec. No new persistent schema is needed.

```
Incidents.new(state, spatial, communications)
ready() -> bool
reset_session(kind: String) -> bool  # fresh or restore, once per replaced epoch
tick_active(dt_ms: float, intro_active: bool, silence_active: bool) -> bool
visual_snapshot() -> Dictionary
```

Construction binds the current initial epoch without drawing randomness. Explicit
fresh/restore rebinding is idempotent for the same state dictionaries. A replaced
epoch that has not been rebound cannot tick. dt must be finite, positive and at
most50ms. Runtime calls only during playing active steps after core status/day,
phone and hustle checks, before random-event selection (update.js244–253). Menus,
hitpause and other non-playing modes pause the scene and its cosmetic timers.
Only this owner changes incident clocks; Day does not reset an active incident at
dawn. Source history resets lazily when the next eligible idle update observes a
different day, leaving lastIncidentId intact.

## Scheduling and beats

Paper/wet timers decay first. An active scene interrupts if silence, any boss,
older Brutus, a live aggro NPC strictly within320px, a live day3 visitor/bus driver,
or a required NPC absent/dead/hostile/aggro is observed. Hidden alone is not a source
exclusion. Intro suppresses idle scheduling but does not interrupt an active scene.
Interrupted cooldown is45000+random*20000ms; normal completion70000+random*40000ms.

Idle busy/intro/silence freezes the scheduling countdown. At most3 incidents start
per day, each ID at most once in the6-bit mask. Null timer initializes35000+random*
20000, then subtracts the accepted dt. If expired, choose unseen eligible IDs in
source order; current-zone specific choices replace the global mattress option.
Current-zone selection keeps the source's greatest absolute faction reputation,
with authored-zone order breaking ties. The present23 zones do not overlap and
each specific incident has a distinct zone; the multiple-choice avoid-last branch
is retained but currently unreachable with the canonical six definitions.
The park incident additionally requires clear weather and not isNight (<.25 or>.75).
Required identities are possum, barb, yuri and conductor. No choice sets30000ms
without a choice draw. Otherwise draw one index; if multiple choices and the pick
equals lastIncidentId, use the first different candidate without another draw.

Start builds the exact source trajectory/anchor, sets beat-1 and t0, writes history,
saves, then posts the first line to @local_eyewitness. Beat0 appears on the next
accepted update. Active time advances before trajectory and a while loop emits all
crossed beats in order. Beat1 emits its source sound. Final beat lasts2600ms; other
beats3200ms. The four source cues are traffic, kick, radio and holyWaterHit. Traffic
consumes one source pitch RNG draw before emitting cached audio, matching the
existing Communications compatibility rule. No second audio owner or noise-buffer
RNG loop is introduced. At duration, all due beats run before normal completion.

## Motion and physical adaptation

Preserve exact nearest-road selection/tie order, road direction, clamped endpoints,
smoothstep and sinusoidal trajectories. Mattress collision uses strict t>1800ms,
strict x/y distance<25px and one bumped flag. It raises shake to at least5, moves
14px in each source travel-axis direction, and shows the original insurance receipt.
Approved INCIDENT-CAPSULE-BUMP adaptation: source writes the clamped position
directly;3D instead commits the actual legal result of spatial.move_body for that
same clamped intent. Walls may shorten the bump; the event still counts once. No
damage, stun, velocity, extra push, teleport or new standing incident collider is
invented. Missing/malformed spatial capability rejects readiness; an invalid return
retains the last legal player point and reports a dependency failure.

Yuri's paper uses strict t>5000 and point-to-segment distance<20, refreshes4000ms,
and uses the source leash-post fallback if Brutus is absent at start. Park wetness
uses strict12000<t<23000 and distance<175, refreshes4000ms; it never changes stats.
The suitcase's strict32×28px avoidance changes only its drawn y position. Forklift,
dryer and suitcase trajectories cannot push or damage. visual_snapshot returns a
detached view of active scene/actor coordinates and paper/wet timers, not a second
clock or a collection of NPCs.

## Epoch lifecycle adaptation and evidence

Source loadGame221–224 clears the active incident and both cosmetics and draws a
fresh35000–55000ms delay while preserving saved history. Match that once on restore.
Source startGame(false) resets history but accidentally retains an old active
incident/timer in a reused JavaScript session. Approved INCIDENT-FRESH-EPOCH-CLEANUP
instead drops old active/cosmetic state on fresh3D epochs; retain the fresh core's
initial timer and new-save history without an extra draw. Keep the source behavior
as an explicit oracle characterization, not silently label it parity. Death/arrest
do not independently erase scenes: source busy rules on the next active step own
interruption. A saved history cannot resume an invisible old scene after load.

The unchanged-source oracle must capture all6 trajectories,24 beats, scheduler
choice/RNG order, strict eligibility/busy/proximity/timing boundaries, source saves,
feed, no economy changes and actual fresh/load characterization. Model tests use
real Communications and source definitions, plus spatial refusal/shortened-push,
epoch/idempotence and detached-view regressions. Root later composes the exact
Runtime slot and proves the18s high→8s crash remains uninterrupted. No engine run,
native scene appearance, Web behavior or60+actor performance is implied by this gate.

Weather ownership remains separate: Day selects clear/rain/fog; paper/wet effects
are cosmetic. The active source has no lightning timer or lightning damage.

## P14c presenter and physical-route proposal (not yet activated)

Captured before presentation code. Proposed ownership is new
`incident_presentation.gd`, `test_incident_presentation.gd` and
`incident_presentation_probe.gd`, plus this appendix. Runtime/Scene wiring and any
shared geometry correction remain root-owned and require the physical results.
The P14b owner remains the only incident clock/state authority.

```
IncidentPresentation extends Node3D
build(world: FullNeighborhood) -> Dictionary # cached original mesh banks/report
sync(view: Dictionary, visual_ms: float) -> bool
clear() -> void
metrics() -> Dictionary
route_report() -> Dictionary
inspect(view: Dictionary, previous_report: Dictionary = {}) -> Dictionary
record_route_report(report: Dictionary) -> void # test/development evidence only
```

`sync` accepts the detached P14b snapshot and the existing presentation timestamp;
it never increments time, calls RNG, mutates state, consumes events, saves, produces
audio or creates an authoritative NPC. One active bank is visible. Mesh/material
construction happens once, with static subparts batched while wheel/door/sock and
animal pivots remain separate. Cached geometry uses SurfaceKit and the existing
Roster possum (as an unregistered decorative child). All scene objects have zero
physics/interaction layers; the actual mattress player push remains Adapter-owned.
The existing event presenter retains the 24 exact beat receipts and four audio cues.

Original banks:

- A stained cream mattress with piped seams, a bent corner, underside slats and
  an exposed spring. Low wobble follows the source scalar trajectory.
- A rust/mold forklift with two forks, wheels, mast, cage, a seated helmeted
  possum and a small physical clipboard. No new named possum is registered.
- A chipped cream dryer with a circular dark drum, visible wet sock and small
  rolling feet; limited dirty cream/slate bubbles reuse a fixed mesh pool.
- Up to 12 separate creased cream receipt sheets revealed by source time from
  Yuri to Brutus/the existing leash-post fallback, with short dark printed bars.
- A rust sprinkler, source-directed segmented water stream and exactly six small
  original slate pigeons arranged as the source committee. The stream stops at23s.
- A worn brown suitcase with handle, ticket and tiny legs; three pigeons appear
  only after14s. The source pause and avoidance remain visible.

No clean white/bright blue water, invented light source, screen text label, particle
emitter or unbounded mesh stream is introduced. Paper/wet status remains a detached
presentation channel: a small cream paper corner/three dirty slate drips may be
attached to the existing first-person hands by a later root-owned Scene hook;
the world presenter itself must not acquire or move the player's camera.

### Clearance evidence and proposed adaptation

Before activation, actual FullNeighborhood physics must sweep each authored mesh
envelope over its complete trajectory at no more than50ms source increments,
including interval casts between samples. Query owner metadata identifies every
collision. Tests exclude the floor only, never walls/props/roofs by category.
All six canonical starts, four mattress axis/direction witnesses, all28 road
segments with reachable source projections/end clamping, suitcase avoidance
offsets, receipt endpoints and pigeon/support placements are included. Actual
Adapter mattress bumps are tested unobstructed, shortened by a wall and fully
blocked; clear returned player capsules and one-shot semantics remain mandatory.

Known conflict from the current authored geometry: the source dryer crosses the
LAUNDROMAT east wall at x1760, approximately y1217; its existing south doorway is
centered x1640/y1230. A source-only mesh transform would cross a visible solid.
Approved `INCIDENT-VISUAL-CLEARANCE` adaptation: for the
non-interactive dryer/forklift/suitcase only, a fixed local visual route may use
prevalidated waypoints through existing openings while keeping the same source
duration, phase boundaries, receipts and scalar model state. Maximum displacement
from the source trajectory is100px/4m; begin/end remain exactly canonical.
If either endpoint is obstructed, the route fails rather than moving it.
No state/effect/RNG or source definition changes follow
from this visual mapping. The proposed dryer detour uses the existing south door;
no building aperture or collectible is silently moved.

The mattress cannot use a visual-only detour: the visible body and source proximity
bump must remain aligned. A blocked mattress route, unresolvable prop route,
inaccessible support, or missing canonical display is an explicit failed clearance
result, not a hidden mesh, successful empty presentation, teleport or readiness
claim. Dynamic trajectory validity and any further geometry/physical adaptation
will be decided from the first actual collider report before Runtime activation.
The complete route report is an activation dependency. While it fails or is
incomplete, Runtime must not install/tick this owner at all: no active incident,
history update, countdown consumption or RNG draw is hidden behind a missing
presentation. This is explicit incomplete integration, not a scheduler reroll,
suppression or successful empty fallback. Any later collision-revision change
that invalidates a certified path needs an explicit policy before activation;
this packet must report the conflict instead of inventing one.
Receipt sheets can pass over low objects using a continuous authored height arc;
the source x/z segment and paper trigger remain unchanged. Water streams stop
visually at solid surfaces; the source cosmetic wetness rules remain model-owned.

### Verification and render acceptance

Headless tests compose real World/Adapter/State/Comms/Incidents, check bank identity,
exact animal/sheet counts and source beat boundaries, physical intervals, detached
state, fresh/restore clearing and bounded node/mesh counts after repeated cycles.
The native probe captures each scene at all four beats from actual eye-level
positions, plus night samples, and records elapsed sync CPU/draw/triangle costs.
This is a bounded render probe, not a new player-controller clock. Root performs
the engine runs and inspects all24 beat captures before live activation. An actual
60+actor Runtime performance comparison remains required once composed; a quiet
six-scene probe alone does not establish the global16ms contract.

First actual-world diagnostic:9,285 checks completed with no script errors. Four
canonical trajectories were clear: dryer (maximum66.603302px visual detour), Yuri
receipt, sprinkler/pigeon committee and luggage. Mattress intersected news boxes
decor11/12; forklift intersected interactive trashcan3 and dumpster prop2. Eighteen
of28 conservative full-road corridors reported obstacles. Nine included boundary
contact because the first authored mattress envelope was oversized relative to the
source18px endpoint padding. Approved correction folds both the real mattress mesh
and envelope to1.16m along travel:14.5px half-length plus3px sine remains inside18px
padding with positive clearance. No boundary collider is ignored or moved.

The approved noninteractive forklift mapping now uses a14px southward arc past
trashcan3 and a22px southward arc near dumpster2. The latter also covers the source
sine continuing after its longitudinal motion stops at24.5s. Both visual endpoints
remain exactly canonical. Actual physical rerun is required; scalar checks alone
are not acceptance. The native probe is now authored for24 day beat captures plus
six night captures, with five existing canonical Roster witnesses for beat0 context.
They are isolated decorative probe instances, never appended authoritative NPCs.
The first mapped-road gate passed all28 cached lanes and their physical casts;
its only remaining canonical collision was the forklift against dumpster2's lid
overhang at29.1s. The22px arc includes that real0.05m overhang and query margin;
neither the collider nor the query envelope is narrowed to hide it.

Approved mattress spatial adaptation: precompute a monotonic lateral lane
for each of28 source roads from actual low-height obstacle bounds, then prove it
with actual box sweeps. The offset is at most100px; longitudinal progress/ease/sine,
duration, scheduling/RNG and one-shot push remain source-owned. The same mapped
point must drive both visible placement and the authoritative proximity check.
Some arbitrary source start/end projections land directly on a source news box;
therefore effective physical endpoints also receive this bounded mapping, while
source sx/ex records remain unchanged. This is an explicit necessary 3D spatial
adaptation, not a claim that source actors had collision-aware trajectories.

`incident_path_map.gd` owns geometry-only cached maps. It builds once from actual
low-height obstacle bounds, using a monotonic corner-visibility graph within the
100px corridor. At most512 graph nodes and192 intersecting obstacle rectangles per
road are allowed; overflow is an explicit diagnostic failure. Each lane and its
full source sine envelope is then certified by actual box overlap and interval
casts. `build(world)->Dictionary`, `ready()->bool`, `map_mattress(incident,source)
->Dictionary` and `report()->Dictionary` expose no gameplay mutation or RNG.

`Incidents.bind_path_owner(mapper)->bool` requires the complete real mapper before
installing it; source-oracle tests leave this capability unbound and retain exact
2D coordinates. In the real composition, start and active updates map the source
point before both proximity detection and presentation. No second visual mapping
can disagree with that point. The source14px travel-axis push still commits the
actual Adapter sweep result; mapped lateral motion does not become extra player
force, an extra bump, damage or stun.

Approved dynamic policy for a subsequent narrow Adapter seam: certify the current
actual collision revision before activation, without any RNG/state/history change;
reserve an active incident corridor so later source-defined movable-prop staging
must avoid it. Actors/player are expected participants, not environmental blockers.
The concrete reservation API is proposed after static maps pass. A model path must
never be silently consumed while its visual is missing, nor may a cached map become
a justification for crossing a new environmental solid. Runtime stays off until
certification and reservation composition have real implementations and evidence.

### P14c live collision reservation seam

Approved bounded Adapter additions (movement/contact/cache internals remain under
root ownership):

```
incident_geometry_snapshot() -> {revision,records,player_epoch,state_epoch}
reserve_incident_corridor(id,expected_revision,segments,player_epoch,state_epoch) -> bool
release_incident_corridor(id) -> bool
_reservation_clear(candidate_bounds: AABB) -> bool
```

The snapshot is rebuilt from the same current obstacle records maintained by
navigation updates, with detached bounds and epoch identity handles. It is not a
second mutable geometry authority. Reserve accepts at most2048 finite bounded box
segments, makes an immutable deep copy, checks actual overlaps and interval casts,
and rechecks collision revision plus both p/s identities before installing one
reservation. This is an ephemeral spatial certificate, not a collider or clock.
Source NPC/player collision layers are excluded; standing environment/props remain
included. A stale epoch automatically drops its old reservation. Release is
idempotent and cannot erase another reservation ID.

`stage_interactive_prop` checks each candidate envelope against this same reserved
swept volume before its existing actual cast/ray/service-approach checks. It keeps
the source-authorized100px bounded search and existing refusal/deferred-placement
behavior. Future real cart drop staging must use this predicate and publish its
actual collider changes through update_navigation_obstacles; no second registry
or synthetic cart drop implementation is introduced by incidents.

New geometry-only `incident_corridors.gd` preflights all eligible prospective scene
plans before the source choice RNG. This checks all six scene kinds over its source
fixtures, not just the mattress. Fixed trajectories retain their approved visual
maps, source phases and exact endpoints. It stages one immutable preparation token
with revision/epoch handles, and reserves only the selected plan synchronously
before history/save/feed commit. There is no await or external writer between
preflight and reservation. Failed dependencies leave timer/history/RNG untouched;
no invisible active scene, alternate choice or silent cooldown is consumed.

The incident model releases the reservation synchronously on normal/interrupted
finish and on epoch replacement. Source-only oracle composition leaves the optional
physical capabilities unbound; real Runtime must bind both map and corridor owner.
Tests must exercise changed revisions, altered preparation tokens, replacement of
either epoch, caller mutation of supplied segment arrays, actual source prop
placement refusal/recovery, and all six prospective plans. Native/runtime activation
is still root-owned after those gates.

The concrete model seam is `preview_scene(id)->Dictionary` (detached canonical
source start payload, no clock/history/RNG writes) and
`bind_corridor_owner(owner)->bool`. Idle ticks whose existing countdown expires
preflight the exact eligible source candidates before cosmetic decay, lazy daily
history reset, timer subtraction or choice RNG. An unchanged failed preparation
may be cached only by exact candidate values, collision revision and both epoch
identities. Normal source selection then draws once and reserves its prepared
candidate synchronously. Source-only oracle use remains unbound.

`PathMap.synchronize_geometry(snapshot)` compares detached current bounds by
owner and replans only roads touched by changed low-height bounds inside their
100px lane envelope. New maps install together only after all affected plans pass
actual casts. Failure preserves the previous usable maps but refuses new
preparation for that revision; retry after a new revision remains possible.
`mattress_segments(raw_start)` clips the cached monotonic lane to the source
start/end range, retaining every corner and the complete three-pixel sine envelope.
This does not replan during an active incident or replace source sx/ex records.

Reservation checks both the current published obstacle bounds and actual physics
overlaps/casts. The former prevents a same-frame new prop publication from relying
on an old PhysicsServer transform; it does not replace actual geometry authority.
Every environmental collider writer must publish through the existing obstacle
update seam and respect the reservation predicate before committing its position.

Counterexample found before live activation: the mapped model's prediction checked
coordinates at t+dt against a payload still tagged t. The corrected validation
receives a detached t+dt prediction; only the accepted normal tick advances the
authoritative clock. Tests use repeated real tick_active calls through completion,
not only direct visual seeks.

The earlier cube pigeon exceeded its declared query: local forward extent .205m
rotated into a world .10m half-width; feet reached .0075m and head .385m versus the
declared .02..38m vertical interval. Approved original faceted body/head/beak/wing/
feet meshes now fit within a .10m horizontal radius and that existing vertical
interval at every heading. No query enlargement, NPC/model change or new clock.
Regression checks transformed mesh AABB corners across actual event rotations
and heading extrema, with native park/luggage recapture still required.

The live six-scene gate exposed the previously untested full luggage avoidance
envelope at rail signal decor:9 (source center1300,3020). Its baseline route clears;
the source optional +28px Y displacement intersects the retained pole near
x1290..1310. Approved display-only correction subtracts
`12*sin(pi*clamp((actor.x-1200)/120,0,1))` pixels from displayed Y. Before1200 and
at/after1320 the offset is exactly zero, retaining canonical physical endpoints.
Source actor coordinates, avoidance condition, phase times, RNG and effects do not
change. Reservation uses the same display mapping, inserts the x1200 phase knot
and includes a .030m Z interpolation allowance: half .015m exceeds the combined
200ms chord error of source sine plus the12px arc. All world solids remain fixed.

Postcallback epoch guards cover prospective preparation, activation, release and
mapped predictions before any following model write/RNG. P-only and S-only
replacement witnesses must return false while preserving the replacement state.
This enforces the existing single-authority lifecycle contract, without changing
normal synchronous owner behavior.

### P14d live composition gate

Root owns production Runtime/Scene activation. Runtime retains strong
`incidents`, `incident_paths`, `incident_corridors` and exposes
`enable_incidents(world)`; Scene retains one `incident_view`. Cold composition
publishes actual actors, cart and interactive colliders, waits for physics, then
builds/binds maps and presentation before title readiness. Active ticks run after
phone/hustle checks and before ambient random events/interactive respawns.
Presentation consumes a detached snapshot and the existing visual clock.

After successful core epoch replacement, static Props rebind first; clear old cart
physics, release/reset incidents, reset/sync Travel cart, then rebuild/stage the
interactive props. Restore consumes the one35–55s incident-delay draw before the
24 contiguous bottle draws. Fresh consumes no new incident draw; the source public
phone initialization draw precedes those24. Root owns that exact composition order.

New isolated `test_incident_runtime.gd` boots the actual full Scene and uses an
in-memory implementation of the existing IO interface. It never touches user saves.
It verifies strong real owners, cold title pause, actual menu pause/resume,
source-busy interruption, live start/finish presentation, one18s high/8s crash loop,
fresh/restore epoch cleanup and source RNG order. Actual Cart/Prop staging must
reject an active reserved corridor in the same frame, then accept the identical
clear candidate after release. Test scenario setup may position authoritative
records; accepted actions, time, physical staging and lifecycle run through the
real composed owners. Missing cart/incident integration is a failed dependency,
never a successful skipped group. This gate is functional evidence, not a60NPC
frame-budget or browser/native-render performance claim.

The first live gate proved clock/menu and RNG ordering, and correctly refused a
later incident after26s of genuine NPC pursuit: skid_brutus_1 had reached69.678px
and skid_lurch248.827px from the player. The independent cart fixture now begins
through actual Scene new-game, retains all56 fresh actors and asserts source busy
guards are false. It does not erase actors, clear aggro or weaken scheduling.
The same gate exposed one stale visual frame after fresh/load; root added
synchronous incident-view clearing at the existing presentation reset.
