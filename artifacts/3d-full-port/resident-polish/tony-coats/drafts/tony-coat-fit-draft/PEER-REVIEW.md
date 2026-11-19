# Tony coat-fit bounded peer review

Reviewed the isolated specification, candidate, static selection, exact source
recipe, reference builders, overlay helper and focused geometry test. No new
production blocker or concrete GDScript parse/type issue was identified by this
source review. This is readiness for root validation, not engine or visual
acceptance.

Reviewed candidate `character_art.gd` SHA-256:
`a4a935c2759b4980cc59eb87399b3286c349ae47eb5cf16315fb310aeb625eef`.
Reviewed focused test SHA-256:
`1f5b732b9b23472f4e6d1c49919e3dc0ce1ab2101b2cf7bad5d212da540a9e33`.
The manifest before updating this review was
`dacb642b5c0b10d98deeff0c7c22a85292041e6b6de089e43be361e9e45f388c`;
all of its file pins matched. The supplied `fac5083` context was not independently
verified with Git.

The production recipe is limited to the default-zero construction argument,
front-only ring adjustment and Tony's one nonzero middle-coat call. The existing
back and X/Y positions, other callers, materials, topology and animation owner
remain outside that delta. Python-only `prepare.py verify` passed exact reversal
of the four production edits and all four test-reference normalizations. The
static selector reports 3,538 inner/middle samples and 10,156 middle/outer
grid samples, with selected minimum gaps of 1.229 mm and 4.691 mm. The final
proof-only extension clips the positively oriented projected front triangles
against each other and checks 369 overlap-boundary vertices. It finds the tighter
outer collar witness at x +/-0.145278522, y 1.366799951, with 2.325 mm clearance.
The regular grid's 4.691 mm result is not the minimum over that extended set.
Both corresponding coordinates are also included in the posed ray sample list;
actual posed coverage and clearance remain for the engine gate to establish.
Python verification reproduced the extended selection without changing the
production candidate or the 1 mm thresholds. The 22.5 mm
predecessor fails the unchanged 1 mm inner-front threshold. These are sampled
rest-space front-surface results, not continuous solid-volume collision proof.

The unrun focused Godot test uses actual published vertices, palette colors,
skin weights, bind transforms and current Animator poses. Its chest-relative
triangle rays require shared coverage, reproduce the original protrusion and
check outer-shell clearance through the collar region. Layer absence cannot
substitute for passing clearance. It specifies 48 pose/time/coat combinations,
cache/resource and geometry checks, reset/distant layer removal, and four actual
completion tails. Existing geometry validation supplies finite unit outward
normals and normalized skin-influence checks.

The initial review found one proof-scope gap: the inherited pose helper compared
only each root Skeleton. The final test closes it with `_fit_all_poses`, which
recursively records every Node3D transform and every Skeleton bone rest/pose,
including compound actors' child skeletons. The other 71 identity action
comparisons now use that recursive result alongside exact geometry/material
checks. This correction changes only the test.

The existing native probe invocation was also corrected in the README: its
unfiltered path is needed for Tony's coat-removal views. Root still needs actual
Godot import and focused/retained gates, then original native/Web front and
quarter images covering the named actions and coat counts. Review must reject
new lapel gaps, outer-shell clipping or an inflated silhouette even if the
sampled clearance checks pass. No Godot, native/Web capture, browser, Git,
gameplay, performance or acceptance-promotion operation was performed during
this peer review. The only authored file is this review.
