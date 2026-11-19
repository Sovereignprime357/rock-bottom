# Evidence-backed correction of the expanded surface test

This test-only successor follows the retained actual v4 failure and v5
diagnostic. Art remains exactly b8b4b58b; no geometry or production edits.
All4+2 completion groups,48 shell/48 surface poses,71 other identities and
all1mm shell/lapel/skin/layer requirements remain. Root owns engine validation.

## Actual evidence

The v5 diagnostic identifies only Mesh.ARRAY_TANGENT (slot2) as a differing
non-position/normal channel on coat_one/two/three. Both arrays retain their
sizes1440/4080/4080. The authored _sculpt_mesh writes only normals/positions.
Godot4.5.1-stable servers/rendering_server.cpp1114–1117 adds the tangent slot
when normals exist;618–639 derives and packs it from those normals. Thus changed
upper-ring normals legitimately change this engine-derived channel. The source
reference is https://raw.githubusercontent.com/godotengine/godot/4.5.1-stable/servers/rendering_server.cpp .

Permit that slot only on the three named changed garment meshes, alongside the
already permitted normals/positions. Keep exact UV/color/index/bone/weight and
all other channels, formats and counts. Require both old/new tangents to have
four finite values per vertex, unit XYZ and exact handedness ±1. The six lapel
parts receive no new channel exception. This changes no shader/material input
policy; it recognizes the pinned engine's existing normal-derived representation.

The same run records99 body self-ray misses. A concrete edge midpoint has exact
authored barycentric weights(0,.5,.5) but float32 Vector3 interpolation followed
by projection/reconstruction gives(-.000002259535,.500002262452,.499999997083).
That exceeds the existing containment epsilon and was skipped, even though the
sample was constructed from an actual submitted skin triangle. The determinant
is finite−.00005755636755 and the triangle is correctly outward-facing. Other
recorded midpoint witnesses show the same mechanism. No missing cloth or failed
1mm clearance appeared; the old completeness assertion still failed correctly.

## Precise completeness witness

Do not loosen containment epsilon, reduce counts or drop boundary samples.
Every selected skin sample already carries its actual posed generating triangle
and barycentric weights. Use that directly constructed surface point as its
known body depth; when the independent full-body self-ray succeeds, use the
maximum of known depth and ray depth, preserving the stronger outer-body test.
When the numerical self-ray misses, count and retain that diagnostic but still
test the known actual surface point against the real cloth projection. An absent
cloth ray remains missing coverage and fails. Every selected finite sample must
be checked; the original covered==sample-count and1mm requirements remain.

Add bounded counterexamples using the retained actual midpoint: old self-ray
miss is reproduced, the actual surface point remains measured, an empty cloth
set fails, sub1mm cloth fails, and a farther visible body surface wins over the
known point. Add tangent invalid-length/handedness/nonfinite counterexamples.
No invented support plane, observed-count substitution or geometry threshold
change is permitted. Preserve old test, actual failures and diagnostics intact.

Fresh central composition remains the immutable v3 project plus unchanged Art
and only this corrected focused test. Run import→focused→roster→Art under the
existing finite root runner. Native/Web17 remain untouched and must follow only
after actual gates pass; no earlier failed run is reclassified.
