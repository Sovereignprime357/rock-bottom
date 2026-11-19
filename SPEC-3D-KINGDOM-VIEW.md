# SPEC — Kingdom world marks and banners

Approved bounded presentation packet, 2026-11-18. Source authority is
`src/render/landmarks_a.js:174–192` (`drawKingdomSites`), the four banner palettes in
`canvas_geography.js`, and immutable Kingdom definitions in `campaigns.js`. This entry
precedes implementation. Existing Kingdom/Combat/Day owners retain all transactions.

## Pure snapshot contract

`kingdom_world_view.gd` exposes static `facts({kingdom,flags})`, `build(full_world)`,
`sync(snapshot)` and detached `inspect()` diagnostics. Scene constructs the cached bank once
after the real world build and supplies current snapshots in every mode. The presenter retains
no source dictionaries, owner references, clocks, RNG, input, saves, lights, collision or
navigation authority. Fresh/restore/revocation are ordinary reverseable snapshots. It never
calls `active_targets()`: that action list excludes completed marks which the source still draws.

Four banners always exist, even in locked/boss/complete stages. Independent truthy flags
blueTarpCleared/cartKeepCleared/copperChoirCleared/throneDitchCleared select opacity .58;
otherwise opacity is 1. These flags are not inferred from stage, defeat records or marks.
There is no separate world seal trophy or seal caption in the source. The faded banners are
its visible completed-clan feedback; journal/seal counts remain with the existing HUD owner.

Exactly tarp_marks/cart_marks/wire_marks display their respective three marks, including
completed marks. Source bitwise semantics select completed bits 0–2; done uses a solid
#6f765e square and ✓, otherwise a dashed #e8c040 square and cream #d4c896 number 1–3.
Every other stage displays no marks. Canonical source definitions supply all 13 positions.
The readonly model tolerates missing/null data like source fallback without normalizing it.
Finite numeric/string/boolean/null marks use JavaScript ToInt32 semantics for render bits;
noncanonical containers produce zero. Flag truthiness includes empty arrays/objects.

## Registered first-person projection

Four original low-poly wooden posts/boards express the source 16×16 banner patterns and
their exact frame/face/ink palettes. Both faces carry the same nonverbal pattern, so likely
approaches do not reveal an invisible back. Prepared opaque/faded banks preserve .58 alpha
with normal depth testing and lighting; they do not become lights or gameplay obstacles.

The ordinary 18px marks become .72m ground-painted frames at exact canonical X/Z, raised
only .025m to avoid z fighting. Text is fixed to that surface, depth tested and lit, without
billboarding or an independent interaction prompt. The completed and pending variants are
prepared once, with the original solid versus 3/3 dashed outline and exact text/colors.

Cart mark 0 is exactly on the north face of the existing school fence (props:143). The
approved adaptation mounts its same .72m mark vertically at 1.1m on that actual face, .012m
clear of the wall. A construction-time read of real obstacle bounds validates that face and
the canonical X/Z coincidence; missing/moved geometry refuses the entire bank explicitly.
Its source action target and range remain unchanged. Native LOS exposed a second real overlap:
blue_tarp mark0 is exactly inside the source news box (decor:81). The approved replacement is
the same stencil at uniform .45 scale on that object's lower south face, centered .24m above
its base and .012m outside its actual front. Its .36m painted outer width fits the .46m box;
the entire stencil stays below the window/paper. Construction validates source-center alignment
and real bounds; canonical action coordinates/range remain unchanged. Other marks, including the copper mark
beside the existing B FLAT RECEIVED sign, remain ground paint. No shared world/adapter edit
or collision hole is authorized by this presentation packet.

Meshes/materials/font and 26 independently toggled groups (8 banner states, 18 mark states)
are built once. Identical sync performs no node/resource/property changes. Source view-culling
becomes ordinary Godot frustum/depth culling; it never changes source state. No transparency
stacking of the two states is permitted. Bank budget: 6,000 triangles, 90 mesh surfaces,
180 nodes and 18 fixed Label3D instances. Local unchanged-sync p95 target is <.05ms; full-scene
<16ms remains separate acceptance evidence.

The first central bank had 98 surfaces because the generic batcher correctly excludes alpha
materials. Each banner face's six disjoint coplanar same-color ink pieces now merge during
construction while opaque, then receive that face's prepared alpha material. This narrow
motif merge preserves every triangle, color and depth; it does not merge the transparent
front/back/board/post into one unsorted object or weaken the generic batcher's safety rule.

## Evidence and scope

The development oracle invokes unchanged `drawKingdomSites`, captures its canvas operations,
and projects all four banners/nine marks with camera-local captures. It exercises all twelve
stages, eight mark masks and sixteen clear-flag combinations, plus source truthiness/bitwise
edge cases and independent flags. It prohibits RNG and checks source state is untouched.
The GDScript gate checks those exact facts, complete fixture execution, reverse transitions,
no source mutation, bounded finite geometry, immutable cached resources, exact anchors and
actual fence/newsbox face clearance without changing services/colliders/footprints.

A separate native probe uses the actual world/lighting, each banner opaque/faded, all nine
pending/done marks, boss-stage disappearance, night and 960×540. It records real camera/LOS,
projected geometry bounds, source facts, images and local sync timing. These are staged visual
fixtures, not proof of earning seals or completing the campaign. Parent owns Scene binding,
serialized engine/native runs, global register/BRAIN and release commits.
