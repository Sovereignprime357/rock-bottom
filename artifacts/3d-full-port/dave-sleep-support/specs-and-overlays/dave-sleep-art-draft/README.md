# Dave sleep support: isolated candidate

One production-owner overlay, no production or source-game changes. This remains
an engine-unvalidated candidate until root runs the focused contract and actual
three-capture walkthrough. Existing wake/laundry evidence stays unchanged.

The retained ground-v2 data establishes floor clipping, not general hovering.
The candidate raises only Dave's sleeping visual root by 4 cm and reposes his
existing pillow under the cheek. All mesh/material/rest data and the awake wrist
binding are reused. The pillow receives a sleep-only 2.2 vertical scale, which is
explicitly art geometry at the instance transform rather than a mesh rewrite.
The actor origin, collider, source wake action and simulation do not change.

`BASELINE.json` pins resident cast `40d04a6b`, current Animator `3317d7a8`, original
unindexed Roster `1e8d4648`, and the actual ground-v2 JSON. `transforms.json` reverses
the two Animator edits byte-exact. `prepare.py` can reproduce these isolated
Animator/reference bytes only while the source pins still match. There is no
index dependency, old snapshot overwrite or implicit repin.

Root staging is three exact overlays on the current resident project:

1. `candidate/game3d/scripts/actor_animation.gd`
2. `candidate/game3d/tests/reference_actor_animation_sleep_original.gd`
3. `candidate/game3d/tests/test_dave_sleep_support.gd`

Run the static check without an engine:

```powershell
python .build/3d/dave-sleep-art-draft/static-check.py
```

Root-only commands after isolated project composition, using the established
Godot 4.5.1 executable and the new isolated project path:

```powershell
& $Godot --headless --path $IsolatedProject --editor --import
& $Godot --headless --path $IsolatedProject --script res://tests/test_dave_sleep_support.gd
& $Godot --headless --path $IsolatedProject --script res://tests/test_character_roster.gd
& $Godot --headless --path $IsolatedProject --script res://tests/test_pose_input_memo.gd
& $Godot --headless --path $IsolatedProject --script res://tests/test_presentation_visibility.gd
& $Godot --headless --path $IsolatedProject --script res://tests/test_dave_walkthrough_contract.gd
```

The focused test CPU-skins actual four-weight geometry and uses the actual bound
rigid-head subtree. It checks 384 sleep samples (two seeds, two details, 96 phase
points across the combined breathing period), every original other identity,
and paired original output for awake/movement/combat/hurt/death/reset/hidden-wake.
It prewarms the original conservative radius before sleep. Triangle intersection
proves pillow contact at the lowest head point; an AABB alone cannot pass it.
Every group has a completion guard and failure output is bounded. These are
authored checks, not executed geometry evidence yet.

After CPU gates, reuse root's existing ground-native-v2 three-capture walkthrough
project and its corrected `posed_ground_diagnostic.gd` helper unchanged. Overlay
only this Animator. Use new output directories, e.g. `sleep-art-native-v1` and
`sleep-art-web-v1`; preserve all old bundles and errors. The existing production
`dave_walkthrough_probe.gd` remains unchanged; the ground diagnostic wrapper is
test-only. Its actual start/walk/E/wake, fixed framing, original PNGs and passive
above-ground rays must remain. Review sleeping support and awake grip in native
and Web images before visual acceptance. No new broad harness, art tolerance,
performance claim or gameplay acceptance shortcut is introduced.
