# SPEC — Physical day-event departures

Captured before implementation, 2026-11-18. This completes the already approved
inside-perimeter exit-pad adaptation in `SPEC-3D-BOSSES.md:148–174`; it does not
repair or change the 2D source. Root owns integration and all engine runs.

## Source authority and scope

Exactly two writers opt into walking away: the Day3 visitor's `leave` callback
(`src/systems/daily_hideouts.js:44–52`) selects east, speed1.2 and WORLD.w+80;
Price Guy's completed purchase (`src/dialogue/vendors_places.js:554–559`) selects
west, speed1.4 and -80. `src/systems/npc_ai.js:448–459` walks at speed*dt/16 then
marks dead at the destination. Source structure-motion clamping makes that off-map
destination unreachable. The approved 3D adaptation instead walks to a visible
named pad inside the same edge and removes the actor only within4 source pixels.
Freed dogs, the bus, deaths and unrelated wanderers are not departure consumers.

No reward, HP mutation, corpse, wanted change, save, dialogue, gameplay RNG or
new clock is added. Day remains the source transaction owner; Director remains
the sole movement/removal writer. Adapter never writes player/state/actor data.
All movement uses the actual existing box sweep and soft actor/player contact.
The solid perimeter stays intact; this is edge-pad arrival, not off-map travel.

## World and adapter contract

FullNeighborhood publishes `departure_pads()->Array[Dictionary]` with immutable
copies of `{id,edge,source:Vector2}`. Original flat cream markings and small
lowercase `exit` signs mark existing source road ends. No new standing obstacle,
service interaction, road, economy or NPC is introduced. Candidate centers are
west x28 at y554/1309/1936/2538/2648 and east x8572 at y1396/2538/4036/5412.
Only centers with existing full-world0.7m horizontal clearance are published;
the actor's actual rectangular footprint/rig height and live physics must still
certify the selected destination. These records are not generic spawn fallbacks.

Existing public seam remains:

```
resolve_departure(body: Dictionary, edge: String) -> Dictionary
# success {exit_id:String,target:Vector2,route:Array[Vector2]}, otherwise {}
departure_status(id: String) -> Dictionary
departure_metrics() -> Dictionary
```

Every position is a source-pixel body center; input body is the detached Combat
geometry record. A request must match a current unique live roster actor, its
current coordinates/dimensions/visual hints, the exact allowed Day identity and
its current wanderOff/targetX direction. A guessed ID, removed/replaced actor,
dead actor, wrong edge, stale geometry or state epoch cannot reuse a route.

Plans and caches bind both current p/s dictionary identities, the live actor
dictionary identity, shape/rig height, and Adapter collision revision. Registration,
unregistration, actor invalidation and epoch reset discard that actor's work.
Changes to current cart/prop obstacle publication invalidate cached geometry.
Ordinary actor/player contact remains physical and never becomes a permanent
environmental obstacle. A displaced actor exceeding24px between requests replans;
normal walking keeps its stable route so Director's waypoint cursor can advance.

## Bounded planning and collision proof

Reuse the Adapter's existing spatial obstacle index, including current mutable
cart/interactive props. Do not call the200ms global FullNeighborhood.find_route
from actor ticks. A lazy0.4m/10px eight-way grid uses the actor's exact width/depth
and actual rig height with existing0.002m query margin. Diagonal edges are tested
as segments, never corner-cut. A multi-goal search chooses a reachable same-edge
pad; occupied pad candidates fall back to another authored pad, not a relocation.

Maximum2 concurrent source jobs,120000 expanded nodes/job,256 planner work units
and a soft1000us total per render serial. Repeated resolve calls never reset that
allowance. The queue rotates fairly. Sparse search limits are160000 visited-cost
entries and320000 heap entries, checked before each expansion (at most8 new
neighbors beyond a limit before refusal); blocked-cell keys are confined to the
481600-cell world. There are no preallocated full-world grid copies per actor.
The original accepted implementation retains the bounded cost map for status
evidence after finishing; other transient search maps are released. Each segment of the
compressed route must pass the actual current box start-overlap, cast and endpoint
checks before publication (at most4 such certificates/render frame). Body clearance
and physical movement remain the final authority. The adapter exposes pending,
failed and ready explicitly in diagnostics; `{}` never means fake success.

No-route/budget failures remain cached until a meaningful geometry/position/
identity/epoch change, avoiding per-frame retries. Pending actors remain at their
actual position; no off-camera/time-based deletion. Returned routes are detached
copies, end exactly at the named pad and fit Combat's existing2048-point guard.
Actual traversal retains the source speed and removes only after physical arrival.

## Required evidence

New `test_departures.gd` composes real FullNeighborhood, Adapter, Runtime, Day,
Combat and Director. Keep the canonical roster, real heights and world solids.
Exercise source Day visitor leave and Price Guy pay (then isolate the departure
consumer for accelerated active-time traversal without rewriting its HP/position).
Check original transaction effects only once; walking grants no new resource,
achievement/death reward or RNG. Measure source displacement bound per step and
all actual endpoints; require physical arrival before actor_departed/removal.

Cover both directions, alternate-pad occupation, late geometry revision, same-frame
unpublished obstacle bounds, body clearance/height, p-only/s-only epochs, same-ID
actor replacement, caller-mutated return values, repeated calls in one render
serial, two-job fairness, removed actors and bounded failed routes. World signs
and pads must be real nodes/records at safe positions. Full-world321 route tests,
existing navigation/contact gates and a native visible departure tour remain
central integration evidence; no model-only test substitutes for them.

## Native visibility witness

`departure_probe.gd` composes the actual FullScene with isolated QA persistence.
One fixture places the player near an existing east road-end pad before the Day
visitor exists; the real Day source spawner creates the actor. The player then
walks through ordinary Input actions to the real E/menu/leave callback. After
that callback the probe neither writes actor position nor drives/removes the
actor: the unmodified scene/Runtime/Director frames do the walk. Captures show
the original rig, departure start, midpoint, approach and empty marked exit.
The probe compares displacement with admitted source active time, requires
removal only within4px of the certified named pad, and reports both wall and
active elapsed time. This short exit witness is not a full-world player journey,
60-AI performance measurement or competent boss-fight certificate.
