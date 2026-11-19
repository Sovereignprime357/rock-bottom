# Folded laundry contents — isolated art candidate

Root selected the visual proposal. Own only the Laundromat Lady accessory call
and private mesh helpers in an isolated copy of `cast_profiles.gd`, plus narrow
actual-geometry checks in a copy of the existing roster gate. No live edits,
engine, Git or source2D changes. Preserve the original files byte-for-byte.

Replace the64-triangle oval `folded_shirt` with one cached ArrayMesh containing
a shallow folded body, tucked sleeve planes, two collar folds and a front hem.
Use one surface and the unchanged `8c8164` fabric material. Geometry remains in
the old basket-local AABB `(-.26,.05,-.15)` to `(.26,.17,.15)` and has no more
than64 triangles. Each added fold is opaque closed geometry, not a texture,
decal, shader or separate animated object. No new material/surface, light,
collision, per-frame work, random draw, action or interaction is introduced.

Keep `laundry_basket` transform and contents name, basket/weave geometry,
hand/rim contact targets, profile, actor height, animation, release/death behavior
and all other identities unchanged. The baseline may already include root's
separate Dave action change; the exact patch must replace only the unique old
laundry construction line and insert laundry helpers at a unique neighboring
function boundary. Never overwrite an independently changed Dave row.

The new gate helper must inspect actual instantiated mesh vertices/indices,
finite nondegenerate faces, winding/normals, one surface, material color, cached
resource sharing and old bounds. Its explicit completion result participates in
the existing geometry/model completion guard. Preserve the existing bilateral
rim-contact and basket-collapse tests byte-for-byte. This is a local geometry
contract; human native/Web views decide whether the folded cloth reads better.

The existing attachment packer batches away named static leaves. The test must
therefore check the authored raw contents name/transform/material, then locate
the real published palette surface by its existing unique cloth tint and inspect
that batch's actual vertices. Do not disable batching to keep a test-only handle.

Provide original/candidate files, a minimal splice manifest and unified diff,
and static reverse-diff/geometry checks. Root stages the splice into its current
candidate and runs the existing roster gate and targeted Laundromat Lady render
probe. No new large harness. Retain original oval captures. This is not an
indexing change or a performance acceptance claim.

## Composition EOL correction

Root's first composition refused before writing: its profile is LF but its roster
test has981 uniform CRLF breaks. All old anchors otherwise match exactly. Adapt
only each inserted/removed splice fragment to that input file's existing uniform
LF or CRLF. Never normalize the full file. Refuse mixed/lone-CR source, ambiguous
anchors, already-applied edits or an existing output. Preflight every file and
verify exact byte reverse reconstruction before the first output write. Preserve
the failed attempt and every unrelated byte, including a disjoint Dave edit.
Add pure LF/CRLF/disjoint-owner/refused-second-file counterexamples; no production
source/test semantics or original baseline/candidate bytes change for this fix.
