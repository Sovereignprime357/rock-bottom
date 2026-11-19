# Dave sleep grounding diagnostic

Read-only adjunct to the existing Dave walkthrough; no new scenario, pose,
geometry, light, gameplay or acceptance change. Original native-v1 images remain
unchanged. The apparent gap in `01_sleeping_dave.png` cannot establish hovering:
the directional shadow is displaced, and a head need not touch the ground when
another body part supports it.

The current sleep branch sets root Z rotation to 1.48 radians and Y translation
to 0.27 m (`actor_animation.gd`), but that is not the final body clearance. The
actual actor root, skinned vertices and held pillow must be included. Existing
roster tests check horizontal pose/wake transitions, not these ground clearances.

`posed_ground_diagnostic.gd` exposes only `static measure(art: Node3D) -> Dictionary`.
It reads current visible meshes and evaluates CPU skinning using the established
`test_character_roster.gd::_posed_vertices` palette formula. No tick, pose reset,
resource write, clock, simulation or renderer mutation occurs. Rigid attachments
use their current global transforms. Vertices are grouped as all visible,
skinned head, other skinned body, rigid attachments and pillow. The head group
uses >=0.25 influence of the actual `head` bone, explicitly not an anatomical
segmentation claim. Each group's minimum world-Y point gets one actual downward
layer-1 ground ray. An additional root ground ray is independent of shadow
projection. Missing/steep support, unsupported skin layout, excessive geometry
or a missing rig fails the diagnostic rather than inventing a ground plane.

Root may copy this one helper into an isolated existing Dave probe project and
add the following field immediately before the existing `proof.frames.append(row)`
inside `_capture_dave`, after the completed frame is read:

```gdscript
row["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))
```

Run the unchanged walkthrough through its existing root-owned launcher. Read
the new field for sleeping/awake/dialogue captures. The helper records actual
source pose state, root transform and per-part bounds alongside the PNG receipt;
it makes no new pass/fail art threshold. Positive **all-visible** clearance plus
the separate body/head/pillow values would establish geometry above the support
surface; a displaced shadow alone would not. Any correction requires a separate
decision. This helper has not been engine-run here.
