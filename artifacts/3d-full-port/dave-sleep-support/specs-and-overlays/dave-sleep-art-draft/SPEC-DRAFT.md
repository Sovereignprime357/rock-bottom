# Dave-only sleep support candidate

Spec before isolated code. Root approved a bounded follow-up to the actual
ground-native-v2 diagnosis, not a general actor-grounding system. Production,
original ground/wake/laundry evidence and held index packets remain untouched.
Base profiles are resident40d04a6b; Animator3317d7a8; unindexed Roster1e8d4648.
This packet has no indexing dependency.

Actual sleeping measurements have body minimum -0.031092 m, rigid head minimum
+0.239449 m, pillow minimum -0.088651 m and maximum +0.229206 m. The floor ray hits
Y approximately0 and the actor origin is +0.06m. Pillow height is already0.317857m
in its tilted wrist pose; the old suggestion that its world height was0.13m was
wrong. The corrected helper also establishes the real rigid head rather than
mistaking an absent skinned-head group for missing geometry. Awake feet are
+0.075m. The evidence supports local clipping/head support correction, not moving
the whole actor/collider down.

Change only Animator's Dave sleep output:

1. Keep the original1.48-radian sleep rotation and all other limb/breathing poses.
   Increase its existing root-bone visual offset Y from0.27 to0.31 for Dave only.
   The4cm lift gives approximately9mm body-floor clearance at the observed sample.
   Other identities retain0.27, and death still overrides the whole sleep pose.
2. After ordinary attachment synchronization, while Dave is in the sleep action
   and not dead, repose the existing pillow node. Reuse its exact cached mesh,
   triangles, materials and rest/awake wrist binding. No mesh mutation or extra
   part. Orient the pillow's long localY across actorX, localX across actorZ, and
   localZ vertically with2.2 scale: full dimensions0.44 x0.286 x0.32m. This reads as
   the existing cushion folded under the head and is thinner vertically than its
   old tilted0.318m world envelope.
3. Author a constant support height from the existing+0.06m feet placement: pillow
   center actorY0.091 gives world minimum0.008 and maximum0.294m. Project the live
   already-synchronized head attachment's X/Z to the cushion center, with X-0.02m.
   This follows original breathing without raycasts or vertex scans. Account for
   the existing pillow geometry's local center(0,0.05,0) in the authored transform.
   A contact test must establish actual triangle support under the lowest head
   vertex, allowing soft cushion overlap up to25mm and gap no more than5mm.

Only the selected sleep output changes. No actor-root/collider movement, physical
footprint, gameplay resources, state, wake transaction, RNG, simulation clock,
collision query, automatic process or new resource cache. The profile/basket and
all original authored mesh data remain byte-identical. The ordinary attachment
sync already compares the actual prop transform and restores its wrist binding
on the next awake/combat/death/reset pose. No persistent sleep-only marker is added.

The production delta is only actor_animation.gd: the Dave-specific root offset
and a guarded post-sync pillow transform. Applying a direct current-frame head
attachment position does not query live actor IDs or introduce new pose authority.
All original action precedence, timers, child-rig updates, skip rules, input memo,
coat logic, collapse and other identities stay unchanged.

New focused headless tests use the actual current Roster geometry and independent
original Animator reference (only class_name removed). CPU-skin real vertices;
inspect actual rigid head/pillow binding descendants and index-expanded cushion
triangles. The 384 finite samples cover the whole628.3185s combined breathing
phase (96 phase points at two detail levels and two seeds), plus
reset/hidden-return/action/death transitions. Prewarm the original radius before
any sleep pose, matching Scene construction. Its original Dave root allowance is
at least height*0.27 (0.4806m), already greater than the proposed0.31m offset; the
sampled actual complete geometry must still fit that unchanged conservative bound.
Report sampling scope honestly; it is not a continuous-time physics proof.

Require body clearance at least4mm and pillow clearance8mm within floating-point
construction accuracy; real vertical triangle contact must meet the stated
head-cushion interval. Keep all transformed vertices finite and within existing
conservative presentation bounds. Compare every non-sleep Dave bone/attachment
transform exactly with the original, including waking after sleep and reset.
Check representative other sleepers and the complete registry's unchanged action
output without introducing new source states. Immutable mesh/material resources,
rest poses, clocks and actor roots must stay exact.

Root alone runs engines. After CPU tests pass, reuse the existing three-capture
Dave native/Web walkthrough with the corrected passive ground helper. Retain
raw originals and actual E/wake/dialogue proof. Visual support, silhouette and
restored awake grip require original-image review; CPU checks alone do not claim
native/Web acceptance. No performance or full-port completion claim.
