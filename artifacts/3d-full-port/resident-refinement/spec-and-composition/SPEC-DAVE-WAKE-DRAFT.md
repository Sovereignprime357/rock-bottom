# Dave wakes in the world — isolated correction

2026-11-19. Spec precedes candidate generation. Root approved this narrow draft
against the reported2c32cb155567b859be067736ca63bc0c81005576 production checkpoint.
No live source, engine, browser, Git, gameplay state or accepted evidence changes.
Existing campaign and pretender drafts remain held byte-for-byte.

## Concrete counterexample

`src/dialogue/neighborhood_a.js:525–536` changes Dave's `asleep` to false and offers
his awake pigeon conversation. `src/render/actors_weather.js:139–140` selects the
sleep sprite only while that source flag is true. The3D Quest owner already makes
the same state change (`quest_dialogue.gd:293`) and Director snapshots carry it.
ActorAnimation already derives Dave's sleep pose from that snapshot when no action
is supplied (`actor_animation.gd:44–49`).

But `cast_profiles.gd:26` also selects sleep as Dave's static identity action.
FullScene caches it at actor construction and injects it on stationary, living,
awake, action-free frames (`full_scene.gd:205,240–243`). Thus an ordinary wake can
remove his Z and change his dialogue while returning the rig to horizontal sleep.
This is established by the code path; actual rendered reproduction is still owed.

## Bounded correction and invariants

Change only Dave's profile `action` from `sleep` to the empty StringName. The
existing authoritative `snapshot.asleep` path remains the sole automatic selector
of his sleep pose. Awake Dave uses ordinary relaxed idle and the existing source
chatter; no replacement invented action, timer, state writer or second controller.
The authored sleep action remains available for explicit animation fixtures and
all existing combat/action precedence remains intact. Every other profile field,
identity, mesh, material, skeleton, pose algorithm and cached resource is unchanged.

Only candidate copies of `game3d/scripts/cast_profiles.gd` and
`game3d/tests/test_full_scene.gd` may change. The original production bytes are
pinned and copied under `baseline/`; their hashes must equal the retained2c32
production inventory. Do not edit FullScene, Quest, Director or ActorAnimation.

## Regression and counterexamples

Extend the existing composed Scene test with a fresh ordinary Dave record and the
existing physical-service setup fixture. The fixture places only the test player
for the headless boundary check; it does not set Dave's sleep/action/state. Send
the actual E input, select the actual wake button, let the real Scene presentation
consume the resulting snapshot, and reopen E into the changed pigeon dialogue.
Assert horizontal asleep geometry before, upright awake root orientation and
absent asleep marker afterward, continued upright idle across a full cosmetic
period, unchanged Dave actor origin and resource/HP/RNG values for the wake, and
clean modal exit. Counterexamples are the original profile (regression must fail),
awake idle after a long cosmetic wrap, and fresh reset returning to source sleep.
Keep existing direct roster sleep/wake and quest source tests unchanged.

The headless test establishes composed state/pose behavior, not visible art or a
real walked route. Root must run existing Quest/Roster/FullScene gates and inspect
the finite actual-input native/Web reproduction separately.

## Minimal rendered reproduction

Reuse the existing full-scene normal movement/menu input seams and isolated QA
storage. Fresh start, walk to Dave without grants/teleport/clock/state changes,
capture his sleeping silhouette and Z, press E and choose `wake him up.`, leave,
wait for a stationary awake frame, capture the upright body and absent Z, reopen
E and capture the pigeon conversation, then leave and move. Retain source actor
flag, actual skeleton up-axis, receipts and framebuffer at each phase. A maximum
120s whole attempt and three captures suffice; no automatic failed-run retry.
Repeat with the actual Web export at960x540 after native review;1280x720 uses the
same source state/pose contract. This is a small acceptance extension/manual tour,
not a new broad harness, campaign, art-quality or performance claim.

## Headless fixture ordering correction

Root's actual baseline-v2 failed all41 awake-posture assertions. Candidate-v1
passed those same41 assertions but still failed the second E target and completion
tail. The fixture left fresh()'s placement_reset event pending; its first actual E
consumed that event and reset camera yaw/pitch after opening the first menu. Dave
did not wander: processing is disabled, his source speed is zero and the full
presentation actor/origin equality check passed.

Consume the genuine fresh events before the player-only service placement/aim at
both fresh boundaries. Before the second E, reacquire the current authoritative
Dave center and the same established relative service approach, placing/aiming
only the fixture player. Preserve every actual E/Button/pigeon/Leave/completion
assertion and every sleep/upright/resource/actor/RNG witness. No production reset,
camera, interaction, AI or gameplay behavior changes. Retain both failed logs;
candidate-v1's posture result alone is not a completed Scene or native acceptance.
