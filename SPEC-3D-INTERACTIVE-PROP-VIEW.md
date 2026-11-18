# SPEC — Live street prop presentation P10c

Captured before code, 2026-11-18. Parent approved a bounded presentation/physical binding for
the shared P10b14 records. No Runtime, Scene, source2D, gameplay clocks, RNG or resource writes.
The original upright meshes/materials and existing solid-prop dimensions remain authoritative.

## Construction and ownership

FullNeighborhood.dynamic_interactive defaults false, preserving the standalone legacy world
contract. Production sets it true before build. This mode creates the same28 tagged meshes and
14 source coverage records, initially hidden, but creates no interactive seed StaticBodies,
obstacles, spatial footprints or blocked-grid entries. The ordinary props remain unchanged.

RockBottomInteractivePropView extends Node3D. bind(world,adapter,actions) adopts exactly these
original28 MeshInstances once into14 named slots. It preserves their Mesh and Material resource
identity, local geometry, names and source_owner metadata. No per-frame scene traversal or mesh
construction. bind is idempotent only for the same owners; unknown/duplicate/missing geometry
fails closed. No new contents, shards, particle effects or alternate prop kit enter this packet.

API: bind(world,adapter,actions)->bool; sync(records:Array)->bool; slot(id)->Node3D;
collider(id)->StaticBody3D; collision_rid(id)->RID; clear_active()->void; dispose()->void. The latter accessors expose
cached presentation nodes for physical queries/tests, never gameplay state. sync consumes the
detached Actions.render_records array. Exactly14 canonical identities/types, finite coordinates,
placed/pending booleans and bounded source animation fields are required. Rows must match the
current Actions.render_records snapshot exactly. Invalid or stale input
hides/disables all slots and removes their dynamic services/navigation entries.

Only placed, nonpending, unbroken records show an upright object and enable its collider. Broken
and pending bottles have no upright mesh, attackable model target, physics obstruction or service.
Pending cans also remain absent. No cosmetic success is invented before model placement commits.
Source tipT drives rotation sin(tipT/30)*0.4; rotPulse drives scale1+rotPulse/1000, with zero/negative
timers at rest. This brief200ms source wobble is cosmetic around the can's stable circular ground
footprint. Pausing the source snapshot pauses the exact pose; there is no view clock.

Live colliders retain the existing upright cylinders: can radius.30m/height.76m and bottle
radius.065m/height.25m. Each collider carries the original interactiveProps:index source owner.
On placement or active-state change only, sync updates that owner's actual physics transform/layer
and calls Adapter.update_navigation_obstacles(owner, records). That established operation replaces
only this owner's entries and invalidates the real cached routes/index revision. Unchanged poses,
timer wobble and repeated syncs never reindex navigation. There is no old seed footprint to remove.
Dispose removes only the view's14 owners and disables their colliders immediately.

The14 world.service_points entries follow accepted live positions: target is the actual object
surface/height, source_point remains its exact source coordinate, and approach is a certified clear
player position. Inactive entries are removed, so prompts/maps cannot point to an old seed target.
Can reach is50 source pixels; bottles are melee targets and have no E action.

## Physical placement and interaction

Adapter.bind_interactive_props(actions,view) stores weak references. Placement may run before view
binding during model construction. stage_interactive_prop(id,kind,desired,maximum_px) validates
strict canonical identity/type and finite in-bounds input; maximum is0..100. It returns a source
Vector2 or null and never mutates shared records. It tries the desired point then deterministic
bounded radial candidates, with no RNG and no crossing intervening walls. The query excludes only
this slot's prior collider and covers the full upright visual envelope above a small ground-contact
skin. It does not use actor-specific contact-repair helpers.

Every accepted point also has a usable actual player-capsule approach: real clearance, real LOS
from player eye to object and strict can50px reach or existing captured-weapon melee reach for a
bottle. Approach search uses source cardinal directions so the established Combat rectangle can
reach the bottle from that location; it does not implement a second damage or hit authority.
interactive_approach(id,source_point=Vector2.INF) exposes the latest epoch-bound placement
certificate for service presentation; the optional point prevents a stale-coordinate approach.

Batch staging reserves each accepted certificate while its same-epoch source record remains
placed. A later prop cannot occupy an earlier certified player capsule or its eye-to-object ray;
new approaches also avoid earlier reserved prop envelopes before their real colliders are enabled.
This bounded14-record physical reservation closes the gap between sequential model staging and
the following presentation sync. It consumes no RNG and never changes source outcome/intent.

On a new p/s epoch, Actions calls Adapter.begin_interactive_epoch()->bool before resetting its
interactive array, drawing24 initial values or staging any point. The adapter immediately invokes
View.clear_active(), retaining all adopted resources while disabling old colliders/navigation/
services, then clears placement certificates. A same-epoch call is idempotent. Old other-prop
colliders therefore cannot perturb new-game/load placement. The adapter is a geometry owner only.

can_reach_target has one strict interactive branch: it reads current authoritative action records,
requires placed/nonpending trashcan, checks strict50 source pixels, then casts fresh LOS to its body.
The target's own collider can terminate the ray; unrelated colliders refuse it. can_hit has one
interactive target-height branch for bottles, using the actual bottle height and the same own-body
allowance. Combat continues to own original weapon reach/SAT/swing capability; all actor branches,
movement/contact rules and corrected source-range logic remain unchanged.
These new interaction branches apply only when world.dynamic_interactive is explicitly true.
Defaultfalse worlds retain their existing static service/LOS contract; dynamic worlds with missing
owner/view bindings fail closed.

## Evidence and integration

New native/headless physical gate covers original mesh/material identity, all14 canonical slots,
zero seed blockers, live collider/nav/service replacement on movement/break/respawn, no changed
model/RNG, unusable placements, actual capsule approach/LOS, exact range, source-clock wobble,
repeated-sync topology stability and owner-only cleanup. Parent runs all engines and checks actual
rendered can kick, bottle break, hidden pending and respawn frames before accepting visual delivery.

Root integration order: set world.dynamic_interactive=true; build world and Adapter; construct
Runtime/Actions; add/bind View; sync committed records after reset and each active model update.
Adapter must already be bound to State before Actions' cold constructor stages initial points.
Fresh/reset reuses the same14 slots/resources. Existing standalone world construction remains
defaultfalse intentionally; production must explicitly select the dynamic contract.

Owned files: this spec, new interactive_prop_view.gd and test_interactive_prop_view.gd, narrow
FullNeighborhood dynamic construction branch, and narrow WorldAdapter binding/placement/interactive
reach and bottle-height LOS branches. Root owns composition and all engine/export/git work.


## Full runtime composition (2026-11-18)
The production Scene selects dynamic interactive geometry before world construction. After State binding and Combat creation, Runtime installs the single shared Actions owner; the Scene binds the original-mesh View. Cold binding consumes no gameplay draws. Fresh/restore reset through Actions after ordinary Props rebind, clearing the previous physical epoch before the exact24 source bottle draws. Each admitted world step ticks interactive props immediately after random events; a narrow Adapter projection synchronizes current colliders before actor physics. Accepted swings synchronize broken bodies immediately. Source E precedence remains NPC/heist, bench, can, phone, cart, dumpster, zone. Can reach is strict50source pixels plus aim and actual LOS; exact boundary falls through to the zone action.

Combat player_attack carries the weapon ID captured at acceptance, before NPC loot or a bottle can equip a replacement. This is presentation metadata only; captured damage/reach/cadence and all source effects remain authoritative in Combat.
