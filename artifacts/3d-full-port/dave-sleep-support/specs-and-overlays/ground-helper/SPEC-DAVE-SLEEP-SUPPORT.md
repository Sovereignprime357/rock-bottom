# Dave sleep support: passive diagnostic, then bounded proposal

This packet is isolated. Original `ground-native-v1` PNGs/report and the v1 helper
are immutable. No engine, production change, animation constant or gameplay write
is authorized by the diagnostic. Current approved resident baseline is cast
`40d04a6b282c3710d9babeba2f8314f5838ed449f3f77ca15fc5590b124d3668`;
the existing wake and laundry corrections remain intact. Root owns serialized
engine/native/Web runs and eventual integration decisions.

## Observed issue, not generalized hovering

The original actual sleeping sample has body minimum Y = -0.031074692 m and pillow
minimum Y = -0.088619329 m. The rigid head's minimum is +0.239447102 m. Actor origin
is +0.06 m above the actual ray-hit floor. Awake feet are +0.074999988 m. The images
show a sideways sleeper with unclear head support; they do not establish a wholly
hovering body. Directional shadow displacement is not a support measurement.

The helper's v1 `skinned_head` category is empty because the actual face/hair are
rigid descendants of the `head` attachment, packed by CharacterRoster onto the
head bone. It is not evidence that Dave lacks a head. The pillow minimum's ray
starts 4 cm above that vertex, still below the actual floor, so its missing hit is
a ray-origin defect. The current pillow is a 0.16/0.22/0.065 m-radius authored oval,
attached to the left wrist; the shared sleep arm pose carries it below the ground.

## Passive helper v2

Keep the API `measure(art: Node3D) -> Dictionary` and existing node/part/vertex caps.
Use actual roster attachment bindings to identify the rigid `head` subtree, not a
mesh-name guess. Add `rigid_head` and combined `head` groups, retain weighted-head
classification and all old groups. Preserve `minimum_world` as the actual lowest
vertex witness; separately report full componentwise bounds minimum and maximum,
part transforms, bound-head/pillow transforms and the support ray's actual from/to.

For every lowest witness cast the same layer-1 ray from an altitude above the whole
measured actor: max(actor-origin + 2 m, actual visible maximum Y + 0.5 m), down to
3 m below that witness. This chooses a ray start, not a floor height. Only an actual
physics hit with an upward normal supplies support/clearance. Missing/steep support
still reports failure. The original witness Y remains unchanged, so penetration
is preserved as a negative clearance rather than clamped away. No pose tick,
resource write, geometry/physics edit, clock or simulation call occurs.

Root inserts this one helper into the existing three-capture Dave walkthrough,
using the existing passive measure call. The corrected baseline must show the
real rigid head group and actual floor hits for below-floor vertices. Its awake
and dialogue bounds should agree because the simulation is frozen in dialogue.
There is no new general acceptance harness or fabricated ground plane.

## Sleep-only correction proposal (not implemented)

Keep source `asleep` as the sole state authority and retain the accepted upright
wake behavior. Preserve actor/collider origins, skeleton topology, hand contact,
all awake poses, all other identities and all other actions. Limit an eventual
correction to Dave's sleep visual root and existing pillow accessory after normal
attachment synchronization; waking/reset must restore the existing attachment.

The measured body penetration calls for a small Dave-only upward sleep-root change,
derived from the actual lowest skin point plus a small visible ground clearance.
The existing minimum implies roughly 0.039 m for 8 mm clearance at this sample;
this is a measured estimate, **not a proposed hard-coded constant yet**. The
corrected v2 bounds across the actual sample must establish the final amount.

Moving that root alone cannot fix the pillow or support the head: it leaves the
pillow below ground and raises the head further. The smallest coherent accessory
change is to place the pillow below the actual sleeping cheek instead of leaving
it on the unsupported wrist. Prefer a folded version of the same authored pillow
with its existing fabric material; its horizontal footprint and thickness must
come from the measured head/pillow bounds. A folded thickness near 0.27 m is
suggested by the measured head clearance after the body correction, whereas the
current flat pillow is only 0.13 m thick. The placement must fit both the real floor
and the rigid head envelope, with a shallow visible cushion overlap rather than a
floating gap. If the v2 bounds show this is disproportionate, use a small Dave-only
neck/shoulder resting articulation instead and remeasure; do not force it by moving
the rigid face independently of its neck.

No pose/accessory candidate is generated before root reviews the corrected baseline
bounds. An approved candidate would use one cached Dave-only support transform or
mesh, no per-frame vertex scans or raycasts, no new physics, no general ground snap
and no changes to active held items or any other NPC. The existing three native
captures must prove sleep support, actual E wake and the awake pigeon dialogue.
