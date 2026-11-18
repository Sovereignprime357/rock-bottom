# SPEC — Full source world geometry

P04a subordinate contract, captured 2026-11-18 before generation. Parent authority is
`SPEC-3D-WORLD-PARITY.md`; content authority is the checked deterministic source JSON.
This packet delivers geometry and physical-access evidence, not full gameplay parity.

## API and ownership

New `FullNeighborhood` in `game3d/scripts/full_neighborhood.gd` extends the existing
`SliceNeighborhood` mesh/material/facade/lighting toolkit. It does not build the slice.
`build()` is idempotent and fails visibly if source content is unavailable. `anchors()`
returns exact source actor body centers plus namespaced source interaction points.
`service_points` records target, approach, original source point, owner structure and kind.
`source_records` indexes each authored placement by category and stable source ID/index.
`collision_footprints()` and `obstacle_records()` expose actual generated static solids.
`route_points()` exposes all23 source route stops; `find_route(from,to,clearance=0.48)`
returns a collision-clear world polyline or an empty result, never a teleport substitute.
`is_clear_position`/`safe_spawn` use the full world, not obsolete slice bounds. Invalid save
placement recovers to a tested clear point near the source spawn; the caller records recovery.
`set_day_time` retains the established seconds-per240-second-day API and cached sky updates.

The parent owns content loading, actors, main activation, controller and shared lighting.
This packet edits only this contract, the new geometry script and its new scene test.

## Placement, bodies and collision

Source point(1050,840) maps to world origin at0.04m/pixel: X[-42,302], Z[-33.6,190.4].
Ground surface is Y0; static walls/standing props use collision layer1. Actors retain their
source body centers. A0.48m radius/1.8m tall physical test capsule matches source player
width24px=.96m; source logical depth28px=1.12m remains simulation data and is not claimed
to equal a circular3D footprint. First-person route/turn trials remain an integration gate.

All53 source structure footprints are represented as authored physical shells, with side
and rear walls, differentiated fronts and roofs. Declared south door gaps and the eight
legacy actors inside five structures receive explicit visible apertures and accessible
interior floor/service space. No full invisible collider spans an open doorway. No opaque
front panel lacks matching collision. Legacy actors retain their coordinates; interaction
approaches are explicit and are not implemented by teleporting actors or the player.
An inside-structure interactable receives a documented real opening if needed; decorative
objects may remain inside a closed shell. Such presentation adaptations are reported.

All193 props and96 decor records receive type-specific original geometry. Standing solid
objects have physical collision; paper, paint, weeds, ground stains and other flat surface
marks are explicitly nonblocking. Elevated signs/wires/roof details have no invented ground
obstacle. Long fences retain source gaps; any gate required for a source interaction is
explicit rather than a walk-through fence. Large water features retain walkable edges.

## Coverage and appearance

Represent23 zones,15 terrain regions,28 road segments,26 crossings,8 ground paths,4 rails,
25 legacy buildings plus28 facades,193 props of30 types,96 decor placements of12 types,
20 utility wires and24 light sources. Preserve authored order/IDs and original world text.
Original brick/plaster/corrugated/wood facade families use recessed glazing, door/window
frames, sills, fascia, roof variation and restrained weathering. Roads have asphalt value
separation, crossings, repairs and low curbs without raising floating floor strips. The
world boundary is physically closed and visually supported by original perimeter dressing.

Cache materials/meshes; batch static leaves into32m spatial cells after construction.
Physics, labels and lights remain separate. Ground navigation uses packed occupancy,
bounded lazy A* and collision-aware smoothing; it must not allocate hundreds of thousands
of Node/AStarPoint objects or run per frame. Construction and route diagnostics expose
elapsed time/expansion counts for later native/Web measurement. Simulation is never culled.

## Verification

`game3d/tests/test_full_world.gd` builds the actual scene and checks coverage and physical
evidence: live collider ownership, solid wall rays, doorway/service rays and capsule
clearance, source actor/service coordinates, source route stops and reachable paths.
Returned route segments must clear the generated solids at the documented radius; an
empty/budget-limited route is a failure requiring investigation, not a substituted line.
Check source critical pawn_sill→ditch_gauge travel at5.5m/s base and9.35m/s sprint against
the source60s budget; do not change speed or timer budgets within this packet. Test real
controller turning/approaching and60+ production NPC performance after parent activation.
Geometry gates alone do not establish those later gameplay/performance requirements.

No source2D changes, new NPC identities, economies, interactions or external assets. Root
runs the pinned engine serially; this worker provides tests without concurrent Godot runs.

First physical review adaptations: the source TRAIN HOPPER and two conductor quest points
are inside freight_car prop54; a derailed shell with an open ground-level cargo bay preserves
them. Route signal/fence targets and cash on exact wall faces bind their visible contact
owner; an unrelated wall still blocks the ray. Newly authored viaduct supports move inward
to avoid source cash cp16/cp17. Cash reach remains the exact14px=.56m. Grid search selects a
safe corridor, then collision-tested string pulling/corner refinement removes quantization
detours; the timed gate uses normal5.5m/s walking, never sprinting as a substitute.

The separate development tool `tools/3d-world-oracle.mjs` runs the unchanged seeded live
objective selectors through the same69 transitions as the source solidity gate, then
enumerates252 legal route pairs and the one excluded scrap_gate↔ditch_gauge pair. Its local
JSON fixture pins the source corpus and generator hashes and is verified with `--check`.
Full geometry tests resolve all63 exact endpoints to physical source action approaches,
walk all321 legal legs, and sweep the real0.48m/1.8m capsule across every returned segment.
Every leg is measured at base5.5m/s against60s. This remains geometric traversal evidence;
real player turning/interaction delays are still an explicit controller integration gate.

Navigation keeps the packed grid as a guaranteed bounded search and safe-route fallback.
An optional bounded visibility refinement considers at most256 exposed physical corners
inside the improving-distance ellipse, with exact segment collision checks accelerated by
8m footprint buckets. No full-world all-pairs graph or per-frame search is constructed.

## Runtime navigation cost boundary

The full-world `find_route` query is for QA, explicit long-distance planning and infrequent
replanning. Native evidence currently averages roughly200ms per complete refined route;
it is deliberately **not** an actor movement/update method. The controller must move its
body through physics each tick and must not call `find_route` in its per-frame loop. The
director must not call it once per actor per frame. Cache a global path until its goal or
physical topology changes, follow waypoints using local collision movement, and stagger
replans behind a per-frame budget. Static `is_clear_position`, `segment_clear` and physics
queries are distinct from global route planning. If pursuit requires local detours, profile
the60 production actors first, then implement a separately bounded local planner/cache in
the runtime adapter; this packet does not assume a global route call is cheap or introduce
an unmeasured replacement algorithm. Gate time is not gameplay frame time.

`tests/full_world_probe.gd` captures all23 zones at eye level in day/night, two overhead
views and seven important service interiors into `.build/full-port/p04/`. Its scene contains
only the full geometry and a camera. No NPC or gameplay claim is implied; the manifest
records exact camera placement, source hash, scope and still-frame rendering counters.
