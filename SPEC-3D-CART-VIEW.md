# SPEC — Unique cart projection P12c (proposal)

Captured before implementation, 2026-11-18. This packet projects the existing Travel cart;
it does not create another cart state, purchase, movement controller or combat owner.
Implementation awaits parent approval of this contract and the small hand-grip extension.

## Source and existing authority

- `src/data/props.js:9–18,101–102`: one rideable cart, source spawn `(1000,1600)`,
  size `24×20`. Six `cart_husk` entries are separate scenery and never rideable.
- `src/systems/interactions.js:62–145`: after doors/route targets, NPC and heist
  selection precede bench, trash and ringing phone; cart precedes dumpster/zone verbs.
  Parked mount is strictly less than36px from player center to cart **top-left**.
  Mounted E dismounts regardless of an aim target, once earlier interactions have missed.
- `src/render/actors_weather.js:317–322` and `sprite_art_player_32.js:512–534`: mounted
  art is an underlay in the player's own32px destination, supporting a riding posture
  inside the basket rather than an invented separate pushing simulation.
- `src/dialogue/neighborhood_b.js:348–358`: THE BIG GUY charges5 copper, mounts and
  applies equipment stats. Repeated purchases, including already mounted, remain legal.
  Buying does not grant `cart_baron`; ordinary prop mounting does.
- `src/core/runtime_ui.js:35–51`: mounted maxHP110 without healing and existing speed
  formula. Source combat/roadkill stays in Combat/Director; no cart health is introduced.
- `src/core/audio_save.js:28,81`, `start.js:57–58`, `combat.js:435–461`: mounted flag
  is durable, parked coordinates are not; fresh resets, same-process restore retains
  previous parked coordinates, cold load starts at spawn. Death/arrest preserve mounted
  state and parked coordinates. No new implicit dismount or drop is allowed.

`RockBottomTravel` remains sole transaction owner. Its approved 3D adaptation searches
at most50px around source preferred top-left `P+(4,8)` and commits only a valid clear
drop. Failure leaves mounted state, cart record, stats and receipts untouched. No retry
clock or RNG is added. A narrow boundary guard captures p/s dictionary identities before
`find_cart_drop` and rejects if either changes before return.

## Owned implementation scope

- New `game3d/scripts/cart_view.gd`, `game3d/tests/test_cart_view.gd`,
  `game3d/tests/cart_view_probe.gd`, and this spec.
- `full_neighborhood.gd`: only `dynamic_cart=false` build flag and unique-cart seed
  solid exclusion/adoption metadata. Default static geometry contract stays unchanged.
- `world_adapter.gd`: cart binding, projection sync, dynamic cart reach, bounded drop
  staging and current cart approach. Use the shared incident reservation query.
- `travel_system.gd`: only post-spatial-call p/s identity guard in `interact_cart`.
- `first_person_rig.gd`: only additive validated cart-grip projection after P05c hold
  is released; existing weapon/default APIs and all accepted gestures stay intact.

Root owns Runtime/Scene integration, interaction ordering, clocks, engines, exports and git.
No 2D source changes, Travel purchase/stat changes, player movement or collision-envelope
changes, new audio, resources, authoritative timers, save fields, RNG or incident registry.

## Projection API proposal

`RockBottomCartView extends Node3D`:

```
bind(world: Node3D, adapter: RefCounted, travel: RefCounted) -> bool
sync() -> bool
tick_pose(delta: float, player_transform: Transform3D, actual_local_velocity: Vector3) -> void
grip_context(camera_transform: Transform3D) -> Dictionary
collision_rids() -> Array[RID]
parked_body() -> StaticBody3D
clear_active() -> void
dispose() -> void
```

Bind caches weak owners and adopts exactly17 unique-cart MeshInstance children, including
the intentionally invisible basket collision proxy. It preserves object/mesh/material
identities, authored palette, source-owner metadata and original transforms. Verify the
full expected original set before any reparenting. Never adopt husks, notably props:143
which remains the cart-cavalry route/Kingdom contact owner.

`sync()` validates the bound host's existing travelRuntime/cart record, then reads
current `travel.cart_record()` and the bound host's mounted flag; it does
not accept a caller-authored record or write model state. Parked mode enables original
frame/basket physical shapes at committed coordinates and restores original part poses.
Mounted mode immediately removes both parked solids, owner navigation entries and its
parked service target before attached art is shown. No old seed or previous-position
collider survives. Changes invalidate navigation/placement caches once; stable poses do
not rebuild obstacles, geometry, resources or scene bindings. Missing/stale/malformed
owners fail closed and remove this view's physical presentation only. In particular,
malformed/missing travelRuntime must not invoke Travel's lazy initializer through a
view read or otherwise repair authoritative dictionaries.

`dynamic_cart=true` must be set before World.build. It creates all original meshes and
coverage records but no unique-cart seed solids, solid footprints or grid cells. Those
meshes stay hidden until binding. Default false retains existing static tests/services.

Adapter proposal:

```
bind_cart(travel: RefCounted, view: Node3D) -> bool
begin_cart_epoch() -> bool
sync_cart() -> bool
find_cart_drop(preferred_top_left: Vector2, maximum_distance_px: float) -> Vector2 or null
cart_approach(source_top_left: Vector2) -> Vector3
```

The unique dynamic service branch requires current same-epoch Travel record, parked
state and a matching live view body. Range is strict36 source pixels to top-left; ray
target is the visible basket/handle. The service's source_point follows that top-left,
target follows actual geometry, and approach is a verified player-capsule point inside
the same36px range. Dynamic unbound/missing state refuses; static legacy fallback remains.

## Drop staging and physical evidence

Validate finite bounds and maximum0..50. Enumerate preferred position then a fixed bounded
radial candidate order; never sample RNG. Candidates stay within50px of preferred and
source world bounds. Reject source player-rectangle overlap, actual player capsule and
live NPC envelopes using existing registered height/FEET and source width/depth, all
solid geometry, other active dynamic props, and the authoritative incident reservation
via Adapter `_reservation_clear(AABB)`. Do not introduce a parallel reservation map.

Test the actual cart envelope, including handle and wheels, with a narrow ground-contact
skin. Do not rely on the old center service, a point ray, or an empty source rectangle.
Require fresh player eye LOS, no cross-wall relocation, and an actual clear approach
capsule at less than36px from proposed top-left. Recheck both host epochs before return.
The query is presentation-only; Travel alone commits the returned source point.

On source fresh/restore, root calls `begin_cart_epoch` after p/s replacement and before
any new interactive-prop staging or actor placement, not merely at the final cart receipt.
It clears previous view collision/services and certificates once per changed p/s identity,
while retaining adopted meshes. This prevents a previously parked cart from perturbing
fresh/restore placement elsewhere in the reset sequence. Same-epoch calls are no-ops.
Do not relocate or rewrite source spawn/restored records to manufacture a valid
state. Test actual spawn clearance and retain existing live-actor placement reconciliation.
Mounted buy/death/arrest/restore changes follow the source flags immediately; resetting
wheel/grip pose does not clear ownership or invent a drop.

## Mounted art and hand proposal

Use the source riding-underlay posture: original basket centered under the player's ground
position, yaw-only, existing handle oriented toward camera-forward. Keep its authored
1.02m ground height and original mesh size. Camera pitch never pitches the cart through
the floor. Cache wheel pivots and roll them only from accepted actual travel; a blocked
player or paused/menu frame produces no roll. No delta accumulator advances gameplay.

`grip_context` returns camera-local left/right positions derived from the actual handle,
not a second drifting handle. The Rig receives an optional `cart_grips` value containing
`{"left":Vector3,"right":Vector3}`, or an empty Dictionary meaning released. It validates the
whole context atomically; no caller dictionary is retained. Both relaxed hands can grasp
the low bar; current weapon is stowed only as presentation. Accepted attacks/food/phone
gestures release their active hand immediately and preserve original captured weapon and
recovery. Returning to grip cannot delay input or effects. Extreme pitch/reach releases
or hides a hand rather than falsely claiming contact; menu visibility remains root-owned.

Native review must judge the deliberately low riding view at neutral pitch and looking
down. The handle is approximately0.48m ahead and0.67m below the eye; raising the whole
cart to fake an eye-level grip would float its wheels and is not proposed.

**Mounted clearance boundary:** parked/drop collision is fully certified by this packet.
The existing rectangular basket/handle extends beyond the player's round capsule at some
corners. This proposal does not claim that unchanged movement collision guarantees every
mounted visual corner clears walls. The native probe must include diagonal wall-skimming;
if visible clipping occurs, root must select a bounded presentation retreat or separately
approve a movement-envelope adaptation before declaring mounted visual acceptance. No
silent enlargement of gameplay collision or hidden quality reduction is allowed.

## Required verification and root integration

Headless tests must cover original17 mesh/resource identity and hidden proxy preservation;
exactly one rideable cart/six untouched husks; no dynamic seed blockers; parked mount,
mount removal, valid/blocked dismount, current service positions and strict35.999/36 edges;
wall/player/NPC/incident exclusions; actual capsule approach/LOS; body transforms matching
accepted record; owner-only cache invalidation; repeated purchase; fresh/same-process/cold
restore; death/arrest mounted retention; p-only/s-only callbacks; malformed input; resource
reuse; independent view state; zero pose drift during pause/zero actual travel. Real source
Travel tests remain green. New test must not weaken existing static geometry contracts.

Root inserts cart in the exact interaction chain after ringing phone and before dumpster;
mounted dismount is not aim-gated. Root calls projection sync immediately after committed
Travel cart receipts and fresh/restore, before the next physics query. It calls tick_pose
only with accepted active presentation time and post-move velocity, then supplies grips
to the existing hands tick. No second hand bob or wall-time gesture clock is introduced.

The native probe captures parked/approach/mount/forward/down-look/rolling/weapon attack/
blocked-drop/successful-drop/restored/death positions plus narrow and diagonal wall cases.
It records authoritative coordinates, physical bounds, actual grip distances and resource
identity counts; passing metadata is not a substitute for reviewing the images.
