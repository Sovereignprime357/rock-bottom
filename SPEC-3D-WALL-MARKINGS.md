# P14g — graffiti and poster parity

Approved bounded owner/presenter packet, 2026-11-18, after the lifecycle audit. Use the existing
State RNG; Root owns lifecycle bindings. Own new owner/presenter/tests/oracle/probe and a new
read-only FullNeighborhood facade accessor. Existing P14f/Runtime/Scene/HUD/Visibility remain
untouched. Actual browser Canvas measurements are captured and pinned below.

## Existing authority and missing behavior

GameState already lists graffiti/posters in STATE_SAVE_KEYS (`game_state.gd:27`), copies them
from source defaults on fresh (`71–72`), and saves/restores supplied values through the existing
safe-data codec (`329–330`, `425–426`). The content exporter executes actual startGame(false)
before capturing initial.state (`export-3d-content.mjs:337`). The current capture has17 graffiti
records and6 posters. It is a fixed source fixture, not a runtime procedural owner.

FullNeighborhood never reads either state array. Runtime has no equivalent of buildGraffiti or
buildPosters. Fresh repeats the captured layouts. Restore with absent keys inherits those same
defaults; explicit null remains null, and nonempty legacy/invalid data is not repaired. A pure
presenter can display valid existing records, but cannot truthfully close the lifecycle gap.

## Exact source lifecycle and RNG

`start.js:105–106` clears both fields only on fresh. Lines119–129 spawn NPCs/cash/interactive
props, then build graffiti followed by posters, before hustle/route/campaign initialization.
`audio_save.js:59–61` saves whole arrays;231–233 restores each saved value or null. Builders
never save by themselves. No death/day/claim reroll exists.

`structures.js:247–293` reuses only a nonempty measured layoutV2 graffiti array whose finite
textW/wallX/wallW and x span pass its exact predicates; start rebuilds older/invalid layouts.
drawGraffiti297 only retries absent/empty data, so a nonempty invalid array is not migrated by
the draw call alone. buildPosters317 trusts any nonempty array. drawPosters346 retries absent
or empty output, including an all-rejected poster build, on the next world draw.

The RNG is the shared source stream, not a new cosmetic stream. Graffiti consumes one draw for
12–18 attempts. Each attempt consumes wall and starting-size draws; a successful attempt adds
line, x, y, color and rotation draws (seven total). Empty eligible-line checks consume no draw.
Walls are bottom/leftside/rightside in source BUILDINGS order, excluding locked buildings.
Faction uses the first half-open containing zone at building center (`tiles.js:11–15`).
Posters visit eligible unlocked, nonneutral faction buildings in order, capped at three per
zone: one chance draw, accepted at <=.55, then three draws for text/wall/coordinate. Preserve
the graffiti-then-poster order and empty-output retry quirk; do not silently make generation
once-only or move it to an isolated RNG.

Width eligibility is an additional approval boundary. Live source calls Canvas measureText
with bold Courier New at8–10px (`structures.js:237–244`). The existing exporter/oracle harness
uses length*size*.6 (`runtime-harness.mjs:27–29`). Existing saved textW values remain authority.
A runtime generator needs a pinned source-font width table (or an explicitly accepted harness
measurement adaptation) so selecting a different Godot font cannot change eligible pools and
later RNG results. Do not approximate this boundary without recording the decision.

## Approved ownership/API

1. New State-bound `WallMarkings` owner, using only host.random_float and host.s fields.
   `prepare_start(reason,loaded_state)->bool` handles fresh clearing and restore missing-key
   semantics, then source buildGraffiti/buildPosters in order; valid measured layouts consume
   no RNG. Root inserts it after interactive-prop initialization and before subsequent start
   rolls. Root preserves raw saved key presence while supplying the corresponding normalized
   GameState values, so absent keys cannot be confused with exported defaults and raw arrays
   cannot bypass the existing save codec. Invalid-envelope rejection remains the Runtime/Save owner.
2. `before_world_draw()->bool` performs only the source absent/empty retries, called once per
   non-title world draw by Root. This unusual render-triggered shared-RNG mutation is explicit
   source parity, not hidden inside the presenter. No automatic save, clock or gameplay effect.
   The owner exposes detached `snapshot()->{graffiti,posters,revision}` for projection.
3. New pure `WallMarkingView.create()/sync(snapshot,surfaces)/clear()/inspect()`. It owns cached
   original text/paper meshes only, never generation, RNG, save or source coordinates. Exact
   per-record equality and private instances avoid rebuilding unchanged layouts every frame.
   Invalid/unplaceable records are reported, not replaced with invented tags.
4. New read-only FullNeighborhood.wall_marking_surfaces() provides source building index,
   source bounds, actual3D face transform/span and aperture/sign/window keepouts. This avoids
   painting a door opening or putting a tag on a fictitious wall. It may read existing wall
   collider bounds, aperture witnesses, authored bay/fascia dimensions and source records;
   it never creates, moves or modifies a building, collider, sign or keepout.

Implementation contract: RockBottomWallMarkings.new(state) binds a weak owner; ready() requires
the complete pinned Canvas width table for all66 current strings at8/9/10px before any draw.
prepare_start accepts fresh or restore; loaded_state retains original saved key presence and
uses bounded normalized values. Direct restore calls also pass each present value through the
same GameState `_safe_data` codec before source layout validation/generation; they require that
owner capability and do not introduce another normalization policy. The existing per-field
limits remain 1024 array entries, 512 dictionary entries, 4096 string characters, depth8 and
20000 visited values. Absent fields remain absent; explicit null/empty/malformed values retain
their normalized meaning and then follow the existing source builder predicates. No change to
the pure view's arbitrary snapshot contract or source layout RNG follows from this boundary.
before_world_draw is a no-op at title and fails closed on an unprepared
new p/s epoch. snapshot() returns detached arrays and revision; inspect() exposes RNG/build
counters for evidence. Temporary generated arrays commit only to the captured p/s epoch, with
no event/save request. Nonempty legacy poster data stays authoritative and may be reported
unplaceable by the view. A render call does not run graffiti's startup migration predicate on
an already nonempty layout.

Facade placement is presentation only. Bottom tags use source x within the building; side tags
map their source x span proportionally onto the corresponding3D side span. Source y determines
a preferred readable height. A fixed deterministic candidate search may move the presentation
rectangle within that same face to avoid apertures, signs and windows, and uniformly fit it to
an available panel; all saved coordinates/text/counts remain unchanged. Source rotation is
retained and its rotated envelope participates in clearance. Unplaceable records must be listed
with their index/reason, never omitted silently. Only explicit mapped records create geometry.

## Visual contract and mapping decisions

Source graffiti records contain x,y,text,sz,textW,wallX,wallW,wallKind,layoutV,col,rot; no building
id or faction. All17 captured records uniquely match one current BUILDING via wallX=b.x+6 and
wallW=b.w-12. Source side kinds still distribute x across the building width, so mapping them
to vertical3D left/right walls needs a declared normalized-coordinate adaptation, not literal
world-coordinate placement. Persisted source values and text remain unchanged.

Source draw (`structures.js:296–313`) uses bold Courier, sz||9, source color, rotation, alpha.65,
plus a chalk pass at(.5,.5) with alpha.18. Use original corpus text and measured width to size
wall lettering; do not substitute new jokes. Existing palette records are preserved as source
content rather than adding new clean/neon colors. Godot text resources may render these glyphs;
no stock decal pack or external imagery is needed.

Posters contain only x,y,w16,h24,faction,text, despite the stale source comment mentioning col/bg.
Palette comes from exported POSTER_BG. Preserve newline content, dark paper, top/bottom torn
edge strokes and source-derived colors. Source has no stored wallKind/building id; a deterministic
source band/containment resolver must be audited against all records. The text is not clipped
to16px paper in Canvas; any3D paper/text fit correction is an explicit visual adaptation, not
a saved-data rewrite. Presenter geometry is flat, nonsolid and shadowless; no emitter is added.

Approved paper-only adaptation: expand the rendered paper width to contain every unchanged
source line plus padding, retaining source font proportion, colors, line spacing and source
record w16/h24. The whole poster may then uniformly fit a clear wall panel. No rewritten text,
truncation, source-coordinate mutation or new random choice is allowed. Empty source generation
may increment revision without changing arrays; the presenter compares actual layout values and
does not rebuild unchanged markings for a revision-only change.

Glyph-bound correction: saved textW remains the Canvas advance, never a fabricated ink width.
Presentation reserves an eighth of its actual rendered font-line height (at least two raster
texels), plus the entire second chalk offset, on every side before rotation/clearance. This
covers bold terminal ink overhang and Label3D atlas quads without changing source data. Tests
await deferred glyph construction for every exercised layout, require nonzero actual glyph
bounds, then require the real text/paper AABBs inside the audited wall envelope; no tolerance
relaxation or zero-bounds skip can turn a missing glyph proof into a pass.

## Pinned Canvas evidence

Native-reviewed front-pier correction: the previous11cm front plane cleared projecting piers
but visibly floated over the wall. Front face anchors now sit6mm outside the actual flat wall;
the existing4/6mm glyph offsets place pigment10/12mm outside it. The read-only survey records
each authored0.20m-wide full-height facade pier at bay*width/bays as an additional keepout.
The complete rotated ink envelope must fit between those piers as well as all prior doors,
windows and signs. Saved source coordinates/text/counts remain unchanged. Existing side
planes remain unchanged. Any necessary fit extension must remain deterministic and uniform;
every stored and generated normal record must still be placed, with any impossible legacy
record explicitly reported. Tests independently reconstruct actual pier strips, verify the
flat-wall outset and real glyph envelope clearance, and repeat native front/oblique views.
The prior0.30 scale floor cannot fit the373px/14.92m longest eligible source line between
real bays. Append bounded0.22/0.18/0.15 candidates after the existing scales; choose the first
clear fit. Very long sentences become smaller lettering, retaining their complete original
text. Fit scales x/y only, retaining the tiny fixed paper/pigment depth against the wall.
An additional longest-eligible-corpus-line counterexample on every surveyed building must
place all rows, with deferred actual glyph bounds checked. Bay counts derive from actual
float32 facade widths, exactly as the existing builder, not idealized decimal dimensions.

Root measured all198 corpus/size combinations in actual Windows Chrome157 Canvas using
bold Courier New, document.fonts status loaded and check true. The retained no-game-state
measurement page is tools/courier-metrics-probe.html. Runtime table game3d/data/courier_canvas_metrics.json
SHA256 is73679c61dcfb7b3141e1a01b086bdc01dc6256a50bacbb55ab1f80ca9dce69c0.
All66 source lines and all198 measurements match the installed Courier New Bold6.95 advance
1229/2048 exactly;90 rounded widths differ from the old harness approximation. Example:
"the bus is late" at10px measures90.0146484375 and ceils to91. No font is redistributed.
The unchanged-source oracle substitutes only this measured Canvas API into the harness,
then executes the actual source builders/draws/save seams. Node generation and --check passed
36 cases/65 steps. Runtime/native rendering gates remain pending until Root executes them.

Root explicitly includes data/courier_canvas_metrics.json in both Native/Web export presets;
raw test fixture JSON is not an implicit exported dependency. Startup composition inserts this
owner immediately after interactive reset/sync, before utilities reset and subsequent force
reconciliation. Fresh phone timer RNG already precedes interactive draws; existing fixed
NPC/cash defaults are an earlier port adaptation, not claimed as full JavaScript-start RNG
equivalence. Restore supplies schema2 fields selected by original data.state key presence,
with values from normalized live state (or {} for migrated schema1). Scene placement retains
candidate normalized values and erases only fields absent from the original save; it never
reinserts raw arrays. Schema1 ignores its unrelated state field even when that field is scalar.

Approved projection revision contract: normal production writes to these two layouts occur
only through prepare_start/before_world_draw. State p/s identity replacement requires prepare;
projection_revision()->int returns -1 while unbound, otherwise the current monotonically
increasing owner revision. Prepare increments even when valid loaded arrays compare equal;
every source absent/empty rebuild increments after committing. Scene still calls the source
before_world_draw hook every non-title frame, but copies/syncs the detached snapshot only when
the revision differs from its last successful projection. Clear/reset invalidates that Scene
cache. This is an explicit closed-owner lifecycle contract, not caching mutable caller data;
the pure view continues to validate and compare arbitrary directly supplied snapshots.

## Proposed gates before acceptance

Unchanged-source oracle: exact emitted arrays, RNG draw count/order, seed continuation, measured
layoutV2 reuse/rebuild, each empty/null/legacy case, nonempty poster trust, chance boundary.55,
per-zone cap and no automatic save. State integration: raw missing fields versus explicit null,
valid save roundtrip with zero extra draws, fresh/reset order and stale epoch rejection.

Presentation gates: actual existing source text/colors, all approved facade bindings, no hidden
or coplanar text, door/window/sign clearance, stable resources on unchanged snapshots, independent
instances, no input/physics/RNG/state writes. Native proof: representative bottom/left/right
tags, all three poster factions, loaded/replaced layouts and day/night readability. Engine,
native/export/Git and Runtime/Scene/HUD/World composition remain owned by Root.
