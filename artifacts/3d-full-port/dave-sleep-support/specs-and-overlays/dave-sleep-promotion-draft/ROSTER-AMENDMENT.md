
#### Dave sleep support - local art correction

Specified before code in the isolated sleep-support packet, after passive
ground-v2 measurements established body/pillow clipping rather than general
actor hovering. Only living Dave's current sleep action changes: the original
1.48-radian visual root rotation remains, with its Y offset raised from 0.27 to
0.31 m. Actor root, collider, source asleep/wake authority, original breathing,
limb poses and all other identities stay unchanged. Death retains precedence.

After ordinary attachment synchronization, repose the existing pillow under the
already-current rigid head. Its original mesh, triangles, material and wrist
binding remain immutable. The authored basis maps local X to actor Z, local Y
to actor X, and local Z vertically at scale 2.2. Node origin is
`(head.x - 0.07, 0.091, head.z)`; accounting for the mesh center `(0,0.05,0)` gives
cushion center `head.x - 0.02`. With the existing actor feet offset 0.06 m, its
world minimum is 0.008 m and full dimensions are 0.44 x 0.286 x 0.32 m. This is a
sleep-only folded-cushion presentation, not a physics support object. Awake,
combat, death and reset use ordinary synchronization to restore the exact wrist
grip. No extra cache, clock, scans, rays, collisions, RNG or gameplay state.

The focused regression CPU-skins actual geometry, inspects the actual rigid-head
binding, prewarms the original conservative culling radius, and intersects the
index-expanded pillow triangles under the lowest head point. At 384 finite
phase/detail/seed samples require body clearance >=4 mm, pillow clearance 8 mm
within construction precision, and head/cushion soft contact from -25 to +5 mm.
Finite samples do not claim a continuous-time proof. Exact paired-original
checks cover awake/movement/action/hurt/death/reset/hidden-wake outputs and all
71 other identities. Mesh/material/skin/rest/snapshot/root data remain unchanged.

Central focused results: 2028 support checks, 384 sleep samples; body minimum
0.008692 m, pillow minimum 0.008000 m, contact range [-0.009924,-0.007648] m.
Existing roster2040, pose13458, visibility2112 and Dave103 gates remain green.
Native three-capture walkthrough passes ordinary wake and movement with the
pillow visible under the sleeping head and original awake grip restored. Web
and final release acceptance remain separately recorded by root; this amendment
does not change parity statuses or claim the 16ms/full-port goal.
