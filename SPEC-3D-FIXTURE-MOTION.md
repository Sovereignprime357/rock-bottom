# P14h — source fixture motion

Approved bounded promotion, 2026-11-18. The original draft was reviewed before this
production packet. Only the reviewed optional FullNeighborhood attachment seam changes
existing production. Root owns FullScene integration, gate registration and native/Web
evidence; gameplay and fixture-light owners remain unchanged.

## Source contract

drawBuilding in src/render/structures.js79,99–138 supplies three visual motions. CORNER
screen index i is bright iff sin(visual_ms/110+i*0.7)>0.3, independently of day/night.
Laundry patch index i orbits at (cos(visual_ms/300+i)*2,sin(visual_ms/300+i)*2) source
pixels; the pane alpha is0.665 in day and0.8 at night. Night is exactly dayTime<0.25 or
dayTime>0.75, matching npc_spawns.js45, not Weather's gradual night_amount profile.
PAWN's first-window steam appears only at night. With t=visual_ms/400, its horizontal
offset is sin(t)*2px and rise is (t%4)*1.5px; radius1.5px, alpha0.4. The source does not
gate this steam on Pete being alive. All three use performance.now(), not simulation dt.

drawUnderpass in landmarks_b.js81–87 computes phase=(Date.now()/8000)%1. While phase<0.2,
the dark alpha0.5 strip starts at zone.x+phase*zone.w*6,zone.y-10 and measures120x8px.
It hides at phase>=0.2. The absolute wall clock is independent from visual monotonic time.
drawAll frame.js26–30 suppresses world rendering only at title; these motions continue in
paused/dialogue world views. No clock, RNG, action, resource, damage, sound or save is owned.

## Approved 3D adaptations

Keep the authored single usable CORNER front window and four laundry machines, versus five
TV windows/six laundry windows in Canvas. Their phases use indices0 and0–3. This is explicit
architecture adaptation, not claimed literal source fixture-count parity. Retain all existing
colliders, windows' outer frame/reveal/sill and washer bodies. A narrow optional World build
seam suppresses only the target window's static inner glass/mullion/dressing, records its
actual transform/size, records actual four drum faces and the underpass ground band, and
leaves the new presenter responsible for their moving visual inserts. No dynamic point light.

The TV is a small original recessed case/screen/stand inside the existing outer window frame.
Bright/dim materials adapt forbidden blue to dirty cream/slate; cached immutable resources
are swapped only when the source threshold changes. Washer inserts use their actual drum
centers; one dark rectangular patch per drum follows the source orbit and stays within the
existing circular face. Do not rotate a featureless cylinder and call that visible animation.

One original low-poly steam disc follows the actual hot-pocket attachment's upper bite when
that attachment is visible. The caller supplies food transform/visibility and camera basis;
there is deliberately no alive field. A live integration counterexample found that Day hides
Pete at night, exactly when source steam is due. Therefore hidden/absent food uses the
captured actual PAWN front service-aperture lintel, without changing Pete's lifecycle.
PAWN's160px facade has no surviving framed front pane: the existing Pete aperture excludes
both candidate windows. Mapping the source first counter/window to this real opening is an
explicit approved architecture adaptation, not a claim that a nonexistent pane was captured. This
fallback faces the actual facade and preserves the same source sine/rise/radius/alpha. It
needs no food/camera dependency. Capturing the aperture does not hide or change its geometry.
Following visible physical food remains the approved3D adaptation; the facade fallback
preserves the independent nightly window effect. A staged visible Pete is not evidence that
the live nighttime fallback works. Root must test the real Day-hidden Pete binding separately.
The disc has no lifetime simulation or particle system. The dark underpass strip follows
the original source ground coordinates, on supplied actual ground receiver rectangles. It is
non-solid, shadowless paint, never a new vehicle, light, dynamic collider or traffic system.

## API and boundaries

FixtureMotionView.create()->Node3D. build(bindings:Dictionary)->bool accepts immutable
audited world-space bindings: tv_window and pawn_counter {transform:Transform3D,size:Vector2}, washers:Array
of four front-face Transform3D values, and underpass {source_rect:Rect2,receivers:Array}.
Each receiver is {rect:Rect2,height:float} in world x/z with the captured ground/street
surface top plus3mm, before later structures are drawn.
The source band crosses foundation, a road, its gutters and a zone floor; using one maximum
height would visibly hover over lower surfaces. The optional World seam captures low direct
mesh AABBs after ground/streets and before batching, partitions only this fixed corridor, and
merges adjacent same-height cells. At most16 private cached quads intersect the same source
rectangle; this is one shadow split at existing surface steps, not extra shadow events. No
physics query, later mesh scan or geometry mutation is involved.
build is idempotent only for equal bindings; no scene traversal or source lookup occurs in sync.

The source corridor is x1020..1596,y230..238. Its x1560..1596 tail overlaps the
canonical building_02 rectangle(1560,160,360,240). Source frame.js draws the
underpass before buildings, and drawBuilding then paints this opaque wall rectangle.
The tail is also inside the source abandoned zone(1500,100,480,360): its existing
zone floor has top0.014m. Keep the original receiver at0.017m there; the subsequently
authored interior floor has top0.021m and must hide the strip with4mm separation. Do not lift this tail
above the building floor, remove its receiving segment, change a collider or change
source shadow endpoints. The oracle records actual unchanged underpass/wall draw
calls in the asserted source order. The actual-world gate samples receiver interiors
and the late1599ms shadow at multiple points in this source-covered tail, verifies
its plane stays below actual floor triangles with depth testing enabled, and verifies
uncovered receiver samples still sit3mm above their final visible ground. This
occluded region is an explicit exception to a blanket final-surface height claim.

sync(snapshot:Dictionary,visual_ms:float,unix_ms:float)->bool accepts world_visible:bool,
dayTime:finite0..1, food_visible:bool, food_transform:Transform3D, camera_basis:Basis.
Only active visible-food steam requires a valid physical food transform/camera basis. Hidden title clears
all dynamic visibility without clock accumulation. clear() hides presentation, preserving
cached resources. inspect() reports gates, exact sampled phases, transforms/material changes,
fixed mesh counts, zero physics/light/particle/RNG work. source_sample(...) is a pure source
phase helper for the unchanged-source oracle. Invalid inputs fail closed without writes to
caller data, World geometry, actor pose or gameplay owners.

Meshes/materials are cached once, private nodes own per-instance transforms, and setters are
suppressed when identical. Fixed capacity: one TV fixture, four washer inserts, one steam
disc, one shadow strip split only by up to16 fixed surface receivers. Parent transforms are handled in world-to-local projection; changing
camera orientation cannot move a wall fixture or change its phase. Root owns Scene binding,
the existing clocks, and physical anchor capture before static batching.

## Acceptance

Execute unchanged drawBuilding/drawUnderpass with captured Canvas calls, injected source
performance.now/Date.now, and no source-function rewrites. Test phase threshold/wrap points,
night boundaries, title hiding, pause continuity, source indices, large supplied timestamps,
missing food, malformed finite transforms, no source mutation/RNG, independent instances,
cached resource identity and setter stability. Geometry tests require washer patch within
its real drum, TV within original window frame, steam within bounded food-relative motion,
and exact source-derived shadow travel. Native/Web review follows Root integration; no
performance claim precedes a frozen-release measurement. Target bounded sync p95<0.2ms and
preserved whole-scene budget; no extra lights, physics casts, particles, timers or audio.

District ambient grading remains outside this packet. Weather remains the only owner of
its39 existing fixture-light energies. The sodium extension below adds surface pigment,
never a second owner of those lights.

## P14h sodium extension — approved before generation

Source landmarks_b.js62–79 draws three always-on additive radial patches at underpass
offsets(80,80),(220,140),(320,70), hence canonical centers(1100,320),(1240,380),(1340,310).
The supplied visual clock gives t=(sin(visual_ms/700)+1)/2. The concentric gradient has
inner radius4px, outer radius70px, and stops at0/0.5/1: encoded RGB(232,140,40) with
alpha0.32+t*0.08, RGB(220,120,30) with alpha0.18, and that second color with alpha0.
The middle stop is radius37px, not35px. Each source fill covers a140x140px square.
There is no night, weather, simulation-time or modal gate beyond world-visible/title.

The optional World seam captures actual horizontal BoxMesh top polygons after the existing
ground and streets, before structures/props and static batching. Rotated path rectangles
are transformed as real polygons; an axis-aligned bounding box is only a broad-phase test.
For each fixed patch square, subtract higher receiver polygons from lower ones and retain
nonoverlapping convex pieces at each actual surface top plus3mm. Never span a gutter/curb
step at a single maximum height. Later walls, supports, floors and standing props occlude
the overlay through ordinary depth testing; do not lift the overlay above them. Survey and
partition happen once in build with no physics query. Capacity per patch:64 intersecting
top surfaces,256 receiver pieces,16 vertices per piece; combined mesh cap4096 triangles.
Missing coverage, malformed polygons or any exceeded cap fails the optional binding closed.

Bindings add sodium:Array of exactly three records {source_center:Vector2,receivers:Array},
each receiver {polygon:PackedVector2Array,height:float} in world x/z. The view validates
finite convex coverage, disjoint interiors and canonical centers before creating anything.
One combined cached ArrayMesh surface carries patch-local UV coordinates; its three patches
remain separate primitives so overlapping patches add exactly once each. One private
ShaderMaterial shares an immutable Shader. It uses unshaded additive blending, ordinary
depth testing, no depth writes, no shadow cast/receive and no fog tint. Addition is order
independent between these patches; ordering against unrelated transparent surfaces is a
renderer limitation to inspect natively and on Web. No texture, particle, physics body,
light, autonomous TIME uniform, source write, gameplay RNG or save is introduced. sync
updates only one alpha uniform when the supplied phase changes; repeated inputs preserve
resource identity and avoid setters. clear/title hides the combined mesh.

Color adaptation is explicit: Canvas `lighter` combines encoded 2D colors; a3D material
passes source-color uniforms through Godot's renderer/color conversion and output pipeline.
Godot4.5 documents OUTPUT_IS_SRGB=true for Compatibility, and false for Forward+/Mobile;
the latter use linear color output. Environment tonemapping and framebuffer configuration
also differ from Canvas. Exact source gradient stops, radius and phase are retained, but
matching them does not establish pixel-identical displayed colors or brightness. Root must
review actual native/Web output. Do not compensate by changing Weather light energy.

Shader references: [spatial render modes and color output](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/spatial_shader.html)
and [source_color uniforms](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/shading_language.html#using-source-color).
Use the documented blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled
and fog_disabled modes; keep depth testing enabled. Source colors use source_color hints.

Extend the unchanged-source oracle to capture actual radial-gradient arguments, all three
stops, blend mode and fills, including sine extrema/wrap, independent Unix time, day/night,
pause and title. Tests cover rotated receivers, stepped surfaces, overlap/coverage rejection,
finite caps, actual-world vertex/interior heights, unchanged colliders/fixtures and one
surface/private uniform independence. Native evidence adds close/oblique sodium min/max
day/night views and includes it in the existing isolated sync profile. Web evidence and the
whole-frame budget remain Root-owned; no claim precedes those measurements.


## Files and central commands

- `game3d/scripts/fixture_motion_view.gd`: pure supplied-clock presenter.
- `game3d/scripts/full_neighborhood.gd`: opt-in `dynamic_fixture_motion` before
  build, then detached `fixture_motion_bindings()` after build.
- `tools/3d-fixture-motion-oracle.mjs`: unchanged-source capture and `--check`.
- `game3d/fixtures/fixture_motion_reference.json`:53 source phase cases, one
  actual title draw and one building-covered tail characterization.
- `game3d/tests/test_fixture_motion.gd` and `test_fixture_motion_world.gd`:
  phase/resource/purity and actual-world attachment/occlusion gates.

Root runs `Godot --headless --path game3d --script res://tests/test_fixture_motion.gd`
and the analogous `test_fixture_motion_world.gd`; markers are
`3D FIXTURE MOTION GATE: PASS` and `3D FIXTURE MOTION WORLD GATE: PASS`.
Node generation/check is `node tools/3d-fixture-motion-oracle.mjs [--check]`.
No native/Web/performance acceptance is claimed by these headless/source gates.

## Bounded native presentation probe

`game3d/tests/fixture_motion_probe.gd` builds the actual opt-in FullNeighborhood,
the real source-positioned Roster Pete and its weighted hot_pocket attachment,
one Camera3D, the existing Weather light owner, and this presenter. It creates no
Runtime, gameplay tick, save/load, extra authoritative actor or input simulation.
Visual/Unix phases and day/night snapshots are explicitly staged and recorded.

Thirty-one PNGs cover close and oblique TV on/off, all four washer inserts at two
phases in day/night, two night steam phases and hidden day steam, the passing
strip at0/800/1599ms and its1600ms disappearance, plus an interior view of the
source-covered1599ms tail. Three further views hide the staged Pete and show the actual
PAWN-counter fallback at two night phases and hidden day; this is not the separate live
Day/Scene lifecycle witness. Twelve further views cover each sodium patch at minimum and
maximum phase, with close day and oblique night cameras below the original underpass deck.
Camera sphere clearance, intended fixture projection
and visible-target rays are checked; the covered tail intentionally has no claim
of visible shadow. Its receiver remains below the unchanged building floor.

After60 warmup frames,180 supplied-clock samples time only view.sync with no
screen capture, readback, Weather sync, rig pose or world build inside the measured
interval. Report p50/p95/max and the local p95<0.2ms target separately from native
frame rendering. Presenter descendants must still contain zero physics bodies,
lights, particle nodes or autonomous timers. Existing world lights are reported
separately; this is not a whole-scene/60-actor/Web benchmark.

Root command: `Godot --path game3d --script res://tests/fixture_motion_probe.gd --
--output=<directory>`. Default `.build/full-port/fixture-motion`; report
`fixture-motion.json`, marker `3D FIXTURE MOTION NATIVE: PASS`. Root runs the
engine and visually reviews the PNGs before claiming native presentation acceptance.
