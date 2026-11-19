# SPEC — shaped hands and the cart grip

2026-11-19. Scoped to original `game3d/` art. This follows the spec-first isolated
hand-art proposals and actual native/browser review. The pixel game is unchanged.

The cached palm has a connected thumb-side heel, shallow thumb/index valley and
knuckle planes. Its eight authored rings use24 sides; only the thumb's existing
base gets its own flared profile. Existing segment lengths, pivots, markers,
surfaces, materials and resource sharing remain. Both hands together increase
from4,984 to5,368 actual indexed triangles:7.7047%, below the10% bound. No meshes
are rebuilt during play. Rest framing, action timing, contact/recovery, alternating
punches, weapons, tools and gestures retain their exact transforms and state.

Only the rideable cart's existing handle mesh changes: a closed twelve-sided
shaft, .96m long and .038m diameter, at its original center, height and material.
The existing node is tagged `cart_part=handle`; CartView checks its authored mesh,
surface count and bounds. The six cart husks, all collision and conservative
placement envelopes remain unchanged. This supersedes the old visible box-shaft
identification and bound assertions, not physical reach or placement checks.

After the unchanged arm/grip solve, cart-only digit poses wrap around that shaft.
The same local grip marker `(0,-.036,-.082)` remains exact. At least three finger
pads and the thumb must lie within8mm of actual rendered shaft triangles, on
opposing sides. Skin triangles must not intersect the shaft volume inset2.5mm;
triangle clipping catches crossings even when all vertices are outside. This is
a declared superficial skin tolerance, not zero-intersection or an8mm penetration
allowance. Palms remain outside the shaft. Attacking releases the active hand;
recovery regrips; level look releases both through the original context rule.

Verification compares an exact separately named baseline Rig, all non-cart poses
and state, nine weapons, two tools, resources and second-instance isolation. Only
Godot-generated `@Class@number` path suffixes normalize to sibling index/class;
authored names, counts, order, class, visibility and transforms remain exact.
Counterexamples must reject renamed nodes, pose changes, moved pads, same-side
contacts and crossing triangles. Native18 anatomy/cart captures, retained93
context/36 gear/18 cart views, and actual browser16-phase sequences at1280×720
and960×540 are distinct evidence. Staged native poses do not prove normal input.
Browser synthetic input does not prove hardware pointer lock, audio or60fps.

The source transaction, Combat, Travel, Adapter and Runtime owners do not change.
This is an art refinement checkpoint, not complete neighborhood/platform parity.
