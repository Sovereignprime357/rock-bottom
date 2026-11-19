# P07c — projectile presentation

Approved before code, 2026-11-18. Source `src/render/frame.js:209–234` draws only `bottle`
and `holy`; `combat.js:52–64` constructs centered records and `update.js:717–749` owns
motion/spin/expiry. The accepted 3D Combat owner already supplies all of these records and
their authoritative rotation. This packet replaces FullScene's identical olive boxes.

## Pure projection contract

New `RockBottomProjectileView` in `projectile_view.gd`, with:

```
static create() -> RockBottomProjectileView
project(record: Dictionary, render_ms: float = 0.0) -> bool
```

Create returns a hidden, unparented Node3D with cached original geometry. `project` reads
only exact String `kind`, finite numeric `x`, `y`, `rot`, and the explicit caller render time.
`bottle` and `holy` are the only accepted kinds. Invalid input hides and returns false;
finite scalar values must also remain finite after Vector2/world conversion. No caller
record is retained or mutated. Public `presentation_kind` and `source_rotation` are observations.

Root owns the existing indexed node dictionary, parenting and removal of absent records.
Every projection replaces the selected kind and transform, including when an earlier shot
is removed and the array compacts. No invented ID, fallback projectile or stale kind survives.
The presenter never reads/advances velocity, life, rotVel, slowMs or damage. No input, physics,
callbacks, Timer, autonomous process, authoritative RNG, particles, sound or impact handling.

Position is exactly `Content.to_world(Vector2(x,y),1.0)`. The existing actual projectile sweep
also runs at height 1.0. Source +x maps world +X; source +y maps +Z. The Art pivot yaw is
`-record.rot`, reduced modulo TAU for finite trigonometry. Bottle long axis and neck are +X;
holy vial long axis is Z, with its cap at -Z. Do not infer orientation from velocity.

## Original bounded art

Source dimensions keep their proportions at an approved visual scale of .016m per art pixel,
independent of the .04m source-coordinate mapping. Bottle body is .32m long/.128m wide;
neck extends the silhouette to .336m. Brown faceted glass, amber shine seam and dark neck
preserve the source identity. The holy body is .16m wide/.256m long, with a cream cap extending
it to .288m. Original beveled facets and restrained collar/seam details replace flat boxes.

The source holy renderer uses forbidden pale-blue new-art colors; the approved 3D adaptation
uses dirty-cream glass, a faint fluorescent-purple shell and a cream cap. No world light.
The caller supplies its existing wall/render milliseconds, so the source pulse is sampled as
`t=(sin(render_ms/80)+1)/2`, glass alpha `.75+.25*t`, halo alpha `.18+.18*t`. Neither the
presenter nor a shader owns another clock. Paused snapshots may pulse when their caller's
wall time advances, but their pose and authoritative records stay fixed.

All meshes and solid materials are cached and immutable across instances. Each view owns at
most two small holy alpha-material duplicates, created once and reused; one view's sample
cannot change another view's opacity. Glass/shell have no shadows, transparency receives no
new emitters, and texture coordinates stay object-local. Solid bottle/cap retain world shadow
behavior. Both cached banks remain attached, and variant selection only toggles visibility.
No resource construction or scene traversal occurs during repeated projection.

## Owned files and evidence

Only this spec and new `projectile_view.gd`, `test_projectile_view.gd`, and
`projectile_view_probe.gd`. Root alone updates FullScene, runs Godot/native/Web/Git and handles
commit evidence. Existing Combat, World, Adapter, rig and accepted files remain held.

Tests cover the exact two kinds/unknown hiding, same-index kind replacement, centered world
coordinates and rotation at cardinal/source angles, provided-time pulse, source immutability,
per-instance opacity/pose isolation, repeated cached resources and finite oriented geometry.
Native probe captures both types/rotations at readable distances and holy pulse endpoints in
production day/night lighting. No performance or visual acceptance claim follows from a
successful headless gate alone.
