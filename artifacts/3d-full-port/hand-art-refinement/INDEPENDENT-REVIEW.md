# Independent hand-art candidate review

Reviewed 2026-11-19 by the independent architecture worker. **No actionable blocker found in the requested static scope.** This review did not run Godot, render, export, use Git, modify production, or establish visual acceptance.

## Scope and integrity

The candidate manifest matches the actual isolated tree: exactly five changed existing files and the three declared new test/fixture files. Independently calculated SHA-256 values match every listed candidate/new hash; all five production base hashes still match the source manifest at review time. The baseline Rig fixture equals the production Rig after only replacing its two `SliceFirstPersonRig` self-class references with `SliceFirstPersonRigBaseline`.

The production delta is confined to the Rig palm/thumb-base construction and cart digit rotations, the unique-cart shaft construction, and CartView's shaft identification. Non-cart pose/action evaluators, attachment/pivot origins, segment lengths, collision shapes, placement/navigation envelopes, transaction owners and source records remain unchanged. The existing test amendments replace only the documented cart curl/visible-shaft geometry expectations.

## Geometry and adoption

- Counting the authored indexed triangles independently gives **4,984 baseline hand triangles → 5,368 candidate triangles**, an increase of **7.7047%**. This includes both palms, fourteen digit segments per hand and the five nail boxes per hand; no new hand mesh nodes, surfaces or materials are introduced. The engine gate separately counts actual mesh arrays rather than trusting these calculated totals.
- The two new palm rings and 24-sided sampling account for the increase. Thumb-base profiles retain the existing five-ring/16-sided topology. Non-owned geometry remains byte-equivalent in the baseline comparison; hand materials and shadow settings are inherited unchanged.
- The unique rideable cart receives one closed, twelve-sided shaft at the same center and length. Its actual local bounds are `(-.48,-.019,-.019)` through `(.48,.019,.019)`; the new `cart_part=handle` tag and CartView's ArrayMesh/single-surface/bounds checks agree. The surrounding source-owner tagging and dynamic adoption path remain intact. Six husks retain their original box shafts.
- The material lookup matches the previous `_box` call's color, roughness, emission and surface classification. Side/cap winding is consistent with the outward normals and Godot's clockwise convention. The shaft lies inside the old visible and conservative physical envelopes; it adds no collider.

## Guard meaningfulness

The new gate measures transformed, rendered skin and shaft triangles. Its palmar-pad samples are points on actual clipped triangles, and their minimum distances are measured against the actual shaft triangles. At least three finger pads and the thumb must satisfy the unchanged 8mm surface-gap limit, with opposed radial contact directions.

The 2.5mm penetration guard clips every skin triangle against the inward-offset convex shaft volume. It therefore rejects deep crossing triangles even when all three original vertices are outside the shaft. The supplied crossing counterexample exercises that distinction; the moved-pad and same-side opposition counterexamples test distinct false-contact cases. The threshold is explicitly superficial skin allowance, not a claim of zero intersection.

The independently constructed baseline, three completed-group guard, actual resource hashes, second-instance isolation, exact state/transform comparisons, all-weapon/non-cart gesture coverage and active-cart-hand release/recovery checks are relevant to the permitted changes. The native probe labels QA placement/acknowledgements and its supporting oblique camera explicitly; it does not present those captures as normal-input or gameplay evidence.

## Remaining evidence

Root must still execute the focused geometry test, the retained Rig/context/gear/cart gates, native captures and actual Web captures at both prescribed sizes. Static review cannot establish that the sculpted anatomy reads well, that all runtime geometry assertions pass, or that the candidate merits human visual approval. No required draft-only correction was identified or requested from the author.
