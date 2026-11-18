# SPEC — Player/actor soft contact P04d

Captured before implementation2026-11-18; root approved after native exported-build idle60s
reproduced a hostile actor surrounding the first-person camera. Source2D actors overlap freely;
3D static-only casts allowed their torsos to occupy the camera. This is an explicit physical
adaptation, not new combat AI or art simplification. Original meshes remain visible and unchanged.

## Ownership and contract

`actor_contact.gd` is pure source-pixel rectangle math. WorldAdapter owns bounded physical
integration in move_body/_move_body_raw/clear_placement; model callers still commit returned
positions. The adapter never moves another actor, writes resources, consumes RNG or owns a
timer. Root retains Runtime/Scene. Adapter.can_reach_target belongs to the disjoint service-range
packet and is unchanged here. No NPC/NPC collision, no dynamic navigation obstacles.

Only player versus live, nondeparted source actors participate. Exclude exactly the existing
Day.actor_visible night predicate (dayTime<.25 or>.75 for mom/pete/daytimeOnly), symmetrically;
invisible services must not leave blockers. Read the shared clock without a new day owner.
Use current p/npcs, not delayed
render-node transforms. Missing host means existing static-only behavior. Canonical source
width/depth define the exclusion region: combined half-extents minus1px on both axes (bounded
below by positive extent for malformed tiny profiles). This deliberately retains strict source
Combat.overlaps at contact, including diagonal contact. The player24x28 versus Lurch28x34
region has half-extents25x30px. Do not replace it with summed hard capsule radii.

Each movement segment sweeps against that region before a real static-world cast. Static slide
segments are retested for peers; endpoint-only checks are insufficient for fast movement and
charges. Every committed endpoint is statically clear. Total travel cannot exceed requested
motion. At most4 combined segments and the existing2 static-wall responses are allowed per call.
Tangential sliding is allowed; head-on neutral contact may spend the remaining distance on a
deterministic tangent, chosen by stable IDs, to pass rather than trapping a resident. Hostile
head-on contact stops at the overlap band. No pushes or collision-driven acceleration.

Existing result `blocked` continues to mean actual static obstruction only. Additive
`body_contact` reports peer contact. A peer cannot set Director.structureChargeHit, produce
wall cooldowns or queue a static path. Existing _touching, source damage, iframe/cooldown,
chargeLanded and dodge-achievement code remains unchanged. Real contacts can change encounter
positions/outcomes compared with overlapping2D sprites; combat formulas and timing are not
rewritten. Actual world LOS remains required, and no actors enter its static collision mask.

## Initial penetration and lifecycle

After finding a statically clear placement through the existing policy, attempt bounded initial
peer repair. Prefer the shortest separating axis displacements with a stable ID tie-break; try
at most8 verified candidates, each a swept, statically clear segment, within100px of the supplied
origin. Check all relevant peers at the endpoint. No random/radial actor pushes. If no candidate
works, return the statically clear position unchanged and increment an observational deferred
counter. This must not return null merely for a peer overlap: clear_actor returning false would
skip source AI/timers and could make the player invulnerable. Existing static-placement failure
still returns null. Movement out of a preexisting peer penetration remains possible, with no
further inward approach; coincident centers get a deterministic escape/contact direction.

Fresh/restore and actor births use existing placement callers; no new saved state. Dead/departed
rows immediately cease participating. Counters report pair tests/contact/repair/deferred work
only; they cannot drive source decisions. Existing navigation budgets/collision certificates
remain static-world concerns.

## Validation

Pure cases cover contact overlap, strict boundaries/corners, fast sweeps, outward escape,
deterministic initial repairs, tiny/invalid inputs and stable ordering. Real Godot physics cases
must prove player and actor symmetry, wall-safe tangents/repairs/knockback, neutral passage,
multiple peers, no displacement gain and no static-navigation work caused by mere peer contact.
Use real Combat/Director to prove default/grabber/swarmer/charger damage and source cooldowns,
plus charge-versus-wall distinction and melee reach. Preserve fake-Spatial source combat fixtures.
The integrated native Block idle120s reproduction must retain all actors and original art,
receive attacks, and avoid deep living torso overlap at the camera. Keep the initial world
collision audit and report any deferred repairs; no hidden enemies or moved measurement boundary.
No performance or playable-parity claim until central gates and the native reproduction pass.


Physical service approaches must also stand outside the same source body exclusion band.
FullNeighborhood checks initial live source residents when selecting its static service
approaches. It does not move residents or reduce their hitboxes. The intro controller test
retains the full roster and adds a bounded visibility graph around nearby body corners; every
edge is checked by the real player capsule/contact sweep, then walked through Runtime input.
This is test steering around residents, not a gameplay teleport or an actor-free fixture.


### Exact live roster lookup optimization
Repeated NPC↔player contact queries may cache an ID→(array index, Dictionary reference) lookup. It is valid only for the same player/state epoch, same NPC Array identity and size, and the exact referenced Dictionary still at that index with the same ID. Rebuild at each new render frame, on epoch/array/size changes, on missing ID or mismatched slot. Duplicate source IDs disable the index for that query. Live flags, position, shape and night state are always read from the referenced current record. Detached pre-append actors retain the original default player-contact behavior. No body positions, peer arrays, contact outcomes or source clocks are cached. This removes repeated full-roster searches during each NPC placement/motion without changing collision queries.
