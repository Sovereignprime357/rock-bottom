# SPEC — World ownership presentation

Approved bounded successor to the handler audit, 2026-11-18. Capture before implementation.
Source: `src/render/structures.js:380–448`, `campaigns.js` Office/claim definitions and
`daily_hideouts.js` hideout definitions. Kingdom feedback, graffiti and posters are separate.

## Authority and API

`world_ownership_view.gd` is a pure presentation owner. `facts(snapshot, player_center)` reads
only detached `office`, `districtClaims` and `flags` data plus immutable source definitions.
`build(world)` creates a fixed cached bank once after FullWorld build; `sync(snapshot, center)`
changes only visibility of existing groups/labels. `inspect()` returns detached facts, anchors
and counters. It owns no gameplay state, RNG, timers, audio, lights, input, save or collision.
Scene supplies current snapshots, including fresh/load/revoked ownership. No p/s WeakRef is
necessary because it retains neither owner nor mutable source dictionaries. No E resolver is
added; the existing real Scene resolver remains authoritative.

FullNeighborhood adds opt-in `dynamic_ownership` (false by default) and a detached
`ownership_surfaces()` accessor. The option suppresses only the Office's static fascia/label
before mesh batching, so the dynamic sign is not layered over stale THE OFFICE text. Existing
walls, aperture, service points, colliders and navigation remain unchanged. The accessor
publishes actual Office facade bounds/attachment transform and canonical claim/hideout points.

## Source facts

Office ownership uses source truthiness. Canonical claim count uses exactly `=== true`, while
each claim sign uses source truthiness. The four exact titles are selected in source order:
11 claims → PAPER AUTHORITY; 4 → REGIONAL OFFICE; owned → THE OFFICE; otherwise
TAX HELP · NO TAX HELP. Ownership separately selects the source door/panel/knob/sign colors
and lock, even for inconsistent direct snapshots. All six upgrade bits render independently
of ownership: cot, locker, desk, generator, radio, route_board. Desk paper count is
`min(6,1+claims)` only when desk is present. The mailbox appears at one claim; striped trim
at eight. Each of 11 canonical claim signs appears only for its claim value; its exact
THE OFFICE CLAIMS caption appears at strict source distance `<100px`. Hideout panels appear
only for the corresponding truthy scrapHideoutOwned/momHideoutOwned flags, with source colors.
The source `<60px` hideout / `<64px` Office E-hint facts are retained in the oracle/model;
the existing Scene prompt presents interaction permission, so no second floating E is drawn.

## Registered first-person adaptations

The real Office is source building 16, x4700/y2920/w440/h300, with south aperture centered
on (4920,3220). Door/lock treatment is a shallow panel on the existing left jamb/wall,
never across that opening. Six original low-poly facade reliefs express the source upgrade
fixtures; desk papers, mailbox and trim retain their source predicates. The generator's
existing Weather light remains the only generator-light owner. No new light is added.

Source hideout centers (532,216) and (1242,1196) have no authored wall. The approved replacement
is a wooden ground door/hatch panel in the exact source rectangle, with panel/knob detail.
These are flat nonblocking visual surfaces, not invented buildings or entrances. Claim signs
are original wooden posts/boards at exact canonical sign pivots; like their source sprite,
they are non-solid decorative displays. None adds a CollisionObject or changes physical
clearance. Source interaction ranges, site positions and transactions remain untouched.

All labels are world-depth-tested, fixed-orientation objects. No billboard through walls,
fullbright material, floating invented ownership text or new action is introduced. The four
Office captions, 11 claim captions, all meshes and materials are prepared once; static pieces
within independently toggled groups may use the existing batcher. Repeated identical sync
performs no resource creation or node/property writes. There are no autonomous frame callbacks.
The bank is bounded to 10,000 triangles / 100 mesh surfaces / 200 nodes / 15 Label3D instances;
central profiling records no-change sync cost (target p95 <0.05ms), without claiming full-scene
16ms acceptance. Construction and native visual evidence are separate from gameplay completion.

Measured native editor sync initially cost .313ms p95. The approved refinement retains only a
scalar semantic key (ownership, six upgrade truths, eleven claim truths and eleven strict-true
claim values, two hideout truths), scalar proximity key and exact last finite Vector2. Canonical
centers are copied once at build. Every sync rereads those source values; unchanged semantics
and position skip reconstruction. Movement evaluates all applicable strict distance predicates;
if none changes, the detached output remains exact without rebuilding nested dictionaries.
No input dictionary/reference is cached. Source mutations in place and equal fresh dictionaries
are both valid. Invalid nonfinite center returns false before keys, counters or nodes change.
Uncached facts remain the oracle and all source cases must match the cached path exactly.

The Old School claim sign is .8m north of props:95's school fence. Its native probe must consider
bounded oblique front-face approaches around the fence's east end, still within the source
caption distance and real clear-placement/LOS checks. The sign and obstruction do not move.

## Evidence

The development oracle executes unchanged drawOfficeExterior/drawClaimSites/drawHideoutDoors
with captured canvas operations. It covers all 64 upgrade masks, ownership and claim-count
thresholds, source truthiness asymmetry, strict proximity boundaries and hideout revocation;
state/RNG must remain unchanged. GDScript compares independently derived facts against that
fixture. Meaningful properties cover stable resources, changed/reversed state, no owner writes,
finite geometry, bounded bank, fixed labels, exact source anchors and preserved real Office
aperture/services/colliders. A native probe uses the actual full world and lighting for Office
title stages/upgrades, every claim location and both hideouts, including night and smaller
viewport fixtures. Captures use explicit staged state and establish visual/placement evidence,
not proof of earning every purchase or full campaign completion. Root owns serialized engine
runs, Scene binding, final integration checks, register/BRAIN and commits.
