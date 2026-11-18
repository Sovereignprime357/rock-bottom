# SPEC — Source world/data foundation

P02/P04 contract, captured before data/world generation,2026-11-18. Source inventory is
`reports/3d-full-port-world-inventory.md`. Root owns shared contract and content loader; worker
owns exporter/content gate/JSON only until the geometry packet is separately assigned.

## Content contract

`tools/export-3d-content.mjs` executes the unchanged ES modules in the seeded development harness
and writes deterministic `game3d/data/source_content.json`. Schema1, format
`rock-bottom-source-content`. Top-level source hashes, world, buildings, props, interactiveProps,
actors(base/day1/registry/aliases/generatedFamilies), catalogs, initial(player/state), definitions
by source module/export name, explicit omissions, and encoding record. Object keys sorted; array
order preserved. Sets/Maps have explicit tagged encodings; no executable callback strings,
DOM/audio resources or nonfinite numbers. Hashes/--check detect drift. Data is not gameplay parity.

Root `content_catalog.gd` loads/decodes immutable shared data; instance_copy provides mutable
copies. Sets become unique arrays, Maps become dictionaries. definition(module,name,fallback)
exposes exact source export names. Native/Web use this same local JSON with no runtime Node.
Both export presets explicitly include data JSON. Failure to load must be a surfaced error,
not a silently empty world.

## Coordinate and time contract

Canonical simulation/data remain in original pixel coordinates and millisecond timer fields.
Scene conversion maps source point(1050,840) to3D origin, X→X, Y→Z,0.04m/pixel. World344×224m.
Body visuals/collision use source body centers, not top-left coordinates. Source speed uses
pixels per16ms; base2.2 maps to5.5m/s and ratios/additive equipment speed remain exact. No
unmeasured mobility bonus is applied. Camera height/art scale are first-person adaptations.

Source player24×28px and usual NPC28×32px logical footprints are larger than the current slice
capsules. Geometry implementation must explicitly distinguish its chosen3D physical footprint,
and validate narrow corridors, no-wall hits, entry/service clearance and all key paths. Current
slice anchors are not full-world truth. Schema1 save migration preserves resources/progression
and explicitly relocates to the new Block because there is no coherent global affine mapping
from the re-spaced slice; schema2 saves store canonical source placement.

Source critical pawn_sill→ditch_gauge route is59.4s against60s at exact conversion. Actual first-
person turn/approach trials must pass. If physical traversal needs calibration, record the
specific adjustment in this contract before changing movement, apply consistently across
spatial rates, and remeasure. Do not enlarge timer budgets or claim Euclidean distance is a walk.

## World coverage acceptance

23 zones,53 declared structures,193 props/30types,41 base actors plus15 day1 kingdom guards,
28 roads,15 terrain regions,8 paths,26 crossings,4 rails,96 decor placements/12types,20 wires,
24 emitters,4 copper sites and5 break-in sites are source inventory, not current implementation
claims. Dynamic families/conditional actors also require their real spawn/event behavior.
Use all56 fresh actors plus the actual four-cop cap for60-agent production stress, not clones.
The eventual geometry packet requires eye-level and collision/route review of the full map.
