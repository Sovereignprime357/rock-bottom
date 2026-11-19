# SPEC — Rendered Karaoke acceptance

Captured before implementation, 2026-11-18; promoted after root review. Root owns
all engine verification. Authority: activities.js186–215, npc_spawns.js338–345,
SPEC-3D-RHYTHM.md, FullScene's real input and domain-menu routing.

Use a fresh ordinary FullScene with mandatory --qa-full and isolated QA storage.
The sole fixture mutation, before the first gameplay input/frame, sets cash to5.
Retain snapshots before/after that assignment and require every other player/state
field identical. No seed, position, HP, speed, equipment, progress, clock, NPC or
note-result injection. Physically walk from the canonical spawn to actual Mike,
using existing certified static/live-resident routes and ordinary input. Require
living Mike, strict60px source distance, actual reach/LOS and the live street/karaoke
resolver before E. Do not move actors or suppress threats; unexpected death,
arrest, boss, epoch replacement, resource acquisition or missing dependency fails.

Use the existing Boss probe's input/geometry helpers through script inheritance,
not a second SceneTree. Override its scenario and liveness; combat defense is
disabled for this short receipt witness. Keep its20s waypoint watchdog/32 resident
replans/80-point graph bounds. Cold startup is bounded120s; the entire gameplay
scenario120s, paid sequence30s, save drain10s and movement recovery5s. Missing
routes fail honestly. No mechanic or physical acceptance threshold is relaxed.

After the actual rendered Mike menu, send its enabled sing-a-song choice through
numbered input, costing exactly5. The source activity is UNTIMED: the WASD keyMap
is unused. Read only the rendered '(now!)' labels, title and history; never inspect
or set private sequence/hits/index. Every page must have four arrow choices plus
forfeit. Wait for rendering before each real1–4 press/release. Dwell at least500ms
on page1 and prove menu, resources, world-admitted time and note state do not
advance. Compare entry RNG before/after exactly eight existing LCG draws; do not
freeze or replace RNG elsewhere. Capture all eight pages before their inputs.

Perfect completion pays24cash/4cred, one not_a_phase achievement and authored
news. Fresh Runtime then completes intro_remember for another1cred, enables
intro_tony and may overwrite the visible receipt. Therefore require cash24/cred5,
exact emitted Karaoke result text and event order, plus a screenshot/copy of the
actual final visible HUD receipt; never manufacture a results screen. Check one
activity start/completion and one intro reward. Save requests may coalesce: require
durable schema2 cash/cred/achievement/quest state, not a fabricated write count.
Finally capture ordinary movement after the modal closes, with current pointers,
source timers and controls restored. No reward may change during that recovery.

Write karaoke-acceptance.json with platform/build/script provenance, bounded input
counts, initial fixture snapshots, physically reached target, menu/choice rows,
event receipts, dwell, final/durable state, movement and failures. Persist the report
after each sample/capture so failed native runs retain useful evidence. A headless
contract checks synthetic report counterexamples only; it never claims gameplay.

Tracked files are this spec, game3d/tests/karaoke_acceptance_probe.gd and
game3d/tests/test_karaoke_acceptance_contract.gd. No production code is changed.
The contract preloads the tracked probe; there is no dependency on the draft path.

Root commands with the pinned4.5.1 engine:

```
Godot_v4.5.1-stable_win64_console.exe --headless --path game3d --script res://tests/test_karaoke_acceptance_contract.gd
Godot_v4.5.1-stable_win64_console.exe --path game3d --script res://tests/karaoke_acceptance_probe.gd -- --qa-full --output=<isolated-directory>
```

Promotion is not execution evidence. The headless marker is
`3D KARAOKE ACCEPTANCE CONTRACT: PASS`; the separately earned native marker is
`3D KARAOKE NATIVE ACCEPTANCE: PASS`. A native failure writes acceptance:false
and exits nonzero, retaining screenshots and the partial receipt chain.

Web feasibility: existing release excludes tests, so root must export a temporary
same-source QA runner/pack (no production default scene change), include the probe
and inherited test helper, and supply --qa-full before FullScene initializes. Use
the existing isolated Web storage namespace and expose JSON to a page/download
instead of a native path. Actual browser run/capture remains required. Synthetic
viewport key events establish rendered input routing, not trusted audio unlocking;
no Web evidence is claimed by the native runner or contract.
