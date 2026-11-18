# SPEC — Full-scene startup preparation

Captured before implementation, 2026-11-18. Root approved a bounded startup correction:
retain all 72 original character templates, improve exact template preparation, and present
an opaque loading surface. Root owns FullScene integration, engine runs and exports.

## Boundary and observed problem

The current FullScene constructs day-one actors at their default origin, then prepares all
remaining templates by creating and freeing complete actors. Final position synchronization
occurs after that loop. In the browser this exposes overlapping models behind the translucent
menu and makes a long cold build appear broken. Root will position every real actor before
adding it to the visible tree. This packet does not change FullScene, gameplay or actor art.

Template skinning currently solves bone influences independently for every emitted triangle
corner. Subdivision duplicates many positions; the same ordered bone chain and exact Vector3
produce identical weights. Cache those results only within one template build. Do not round
positions, merge vertices, change normals/UVs/materials, approximate weights or share poses.
Discard temporary influence caches when construction ends. All final mesh arrays, skin binds,
attachments and contacts must remain byte-equivalent to uncached construction.

## APIs

```gdscript
# CharacterRoster: preparation constructs immutable resources, never a live actor rig.
static func prepare(visual_id: StringName) -> bool
static func is_prepared(visual_id: StringName) -> bool
static func preparation_stats() -> Dictionary
# Existing create(id, seed) remains unchanged and uses prepare internally.

# New startup_presentation.gd, RockBottomStartupPresentation extends CanvasLayer.
func show_stage(text: String, completed: int, total: int) -> void
func stage_timings() -> Array[Dictionary]
func finish() -> void
```

prepare includes every authored companion template, succeeds repeatedly without rebuilding,
and rejects unknown IDs. It retains only the existing immutable resource cache; each later
create still owns an independent Skeleton, pose/write caches, markers and mutable attachment
transforms. is_prepared requires both the requested template and its companions. Diagnostics
report completed template count, construction microseconds, exact weight solves and cache hits.
Diagnostics are observational and consume no authoritative RNG or simulation time.

The startup CanvasLayer covers the entire viewport with an alpha-one panel above the HUD.
It blocks pointer delivery, displays the caller's stage and actual completed/total count,
and uses a determinate progress bar only when a positive total exists. Stage changes record
monotonic elapsed time for evidence. It creates no 3D models, timers, gameplay state or input
actions. finish records the final stage and hides the layer; it never starts or resumes play.
Use plain world-compatible stage labels such as "the block." and "the neighbors.".

Root creates the overlay before world construction and yields a frame so it can paint. It
updates stage progress before/after real preparation work, calls prepare for all 72 templates
with yields between identities, creates/positions the actual actors, and removes the overlay
only once the synchronized title view is ready. Yielding between identities does not claim a
hard per-frame budget for synchronous work inside a single identity.

## Rendering and evidence

This bounded pass does not create GPU proxy characters. Material/layout equality alone does
not establish complete light/shadow shader coverage. Initial actual actors render at their
authored positions beneath the opaque surface; fresh browser measurements must establish the
remaining first-use rendering cost. There is no first-encounter fallback to simpler geometry.

Tests compare every prepared template's final mesh arrays and skin binds against the same
authored builder with memoization disabled; cache hits must occur without changing any byte.
They verify repeated preparation preserves resource identity, companions prepare recursively,
two created instances retain independent poses/resources as specified, and temporary weight
caches are not retained. UI tests verify full viewport coverage/opacity, actual progress,
resize behavior, observational timing and finish semantics without constructing 3D warmups.

Root measures cold native and fresh browser startup with stage/template timings, first title
frame, console errors and subsequent conditional spawns/gestures. Preserve the existing roster
geometry/contact gates. Report improvements only from comparable runs. If runtime procedural
construction remains excessive, an export-baked library of these exact authored resources is
a separate measured follow-up, not a silent quality reduction or an unverified claim here.
