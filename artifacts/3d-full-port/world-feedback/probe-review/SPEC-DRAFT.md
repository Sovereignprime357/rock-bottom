# Actual-domain feedback visual evidence (draft)

This packet reads the isolated `.build/3d/world-feedback-integration/game3d`
candidate. It changes no production source, shader, collider, identity or recipe.
It is a staged visual test, not a controller, campaign, fight or performance
acceptance test. Root owns engine execution and native/Web review.

## Authority and fixture boundary

The real FullScene builds the real world, Adapter, source actors, rigs, HUD,
Runtime, feedback bridge and four-bank presenter. A probe subclass records the
real outgoing event stream before delegating to FullScene's existing consumer.
Source save requests go to one isolated output save path. The probe never calls
`Feedback.accept`, appends a particle, emits a synthetic feedback event, edits a
mesh transform, injects a projectile, or invokes the cosmetic RNG.

Each independent case starts with Runtime.fresh and FullScene reset. The initial
fixture may place the player and an existing canonical actor through real
Adapter/Combat clearance, stage a ready source timer, select a source RNG seed,
or set a live boss just below its ordinary phase threshold. These changes happen
before the recorded trigger and are included in the report. Spawned identities
come from actual Boss/Combat/Companion methods, never invented records. Source
HP/damage/speed and collision are otherwise unchanged. A camera observer pose is
explicitly staged for readability; this is not first-person input evidence.

FullScene processing is held while taking screenshots. Trigger methods and
Runtime.resolve retain their real transaction logic and physical checks. The
active/recovery interval uses Runtime.advance in <=16.667ms quanta; particles
therefore age only at the real source update boundary, including hitpause.
Unrelated actor activity remains authoritative and is recorded, not deleted.
Camera framing may change between named views, never as part of shake sampling.
Source gameplay RNG is checked unchanged by painting/readback.

## Finite coverage

Packet A has seven cases, nine unique recipes:

| Case | Real trigger | Exact birth receipt |
|---|---|---|
| essential | Combat.attack_player at canonical lease_guy | essential_contact; one essential chip; no HP change |
| melee | Combat.attack_player at canonical Tony's existing physical storefront approach, without starting a boss | actor_hit before knockback, player_attack;8 sparks+3 rust+1 flash |
| bottle | Combat.attack_player through real bottle swing owner | committed broken bottle, respawn timer;12 bottle_break |
| trash_cash | InteractiveProps.kick at placed source can, seed1 | cdT60000, tipT200, accepted cash branch;6 trash_cash |
| trash_rats | same source can, independent fresh case, seed1456 | same timer commit, no cash reward;8 trash_rats |
| dumpster | WorldProps.open/select actual third rats offer, seed1 | prop_effect rats, looted/dive counter;10 dumpster_rats |
| possum | Companion.spawn_pet_possum then tick_possum_reveal | actual placed source cash pile + cash_revealed;6 possum_reveal |

Packet B has eleven case entries, nine further unique recipes (Tony and Older each
receive both phase variants; ranged/Fallen each capture two transitions):

| Case | Real trigger | Exact receipt |
|---|---|---|
| ranged | actual canonical ranged actor hostile decision;300ms aiming;actual projectile sweep | ranged_aim1 then bottle_impact10; accepted HP hit or documented iframes |
| fallen | Boss.transform_fallen_priest, real350ms aim and projectile sweep | fallen_aim4 then holy_impact12 |
| tony2 / tony3 | Boss.start_tony then legal phase check at hp130/60 of200 | boss_phase_changed phase2/3;24 tony_coat, phase2 requires both real adds |
| older2 / older3 | Boss.spawn_brutus_older then hp98/48 of200 | boss_phase_changed;20 older_phase |
| ally | Boss.start_coop, real Stripe ally decision in contact range | target HP minus10, ally_hit4; no player melee recipe |
| radio | actual source COP spawner then Combat.tick_police at distance>=120, wanted1, seed1972 | radio sound, radioVisualT, delayed backup queue;radio1 |
| taser | actual source Brendan spawner, ready charge, real hostile hit | post-hit player point, charge0/cooldown1000;taser10 |
| taser_fatal | same real charged hit with initialHP1 and a prior actual essential contact | source arrest reset appears before taser, pool retains only10 new tasers at respawn point; old essential epoch gone |
| death_then_taser | actual prior essential, canonical aggro Tony and source-spawned charged Brendan physically staged around source respawn; one real Director.tick | Tony's ordinary lethal contact emits death; source captured roster finishes detached Brendan after police removal; post-reset iframes refuse HP loss but10 taser particles remain |

A canonical Brendan has isCop=true. His own fatal hit must exercise arrest,
never a fabricated death variant. The separate death sequence must occur through
the actual Director's captured-roster ordering; if physical clearance or that
source ordering prevents it, report failure. Do not remove isCop or hand-invoke a
detached actor after a completed source loop to manufacture the sequence.

The real-physics authority-v1 run passed10/11 cases but exposed an invalid
fixed-radius26px staging search for the two-hit fixture. The current contact
owner retains a1px logical-overlap band. Tony/player half-sums are26x30px,
Brendan/player25x29px:26px cardinal X either misses strict overlap or is beyond
it, cardinal Y and diagonals are repaired outward. Keep that failed report.
Generate16 deterministic positions per actor on its source overlap rectangle,
0.5px inside the edge, beginning on positive Y. This is only candidate
generation: each detached original actor requires exact real Adapter placement,
actual `can_hit` to the unchanged canonical respawn center, strict source
overlap, and no Contact.penetrating against the player. Both candidates must
also have disjoint source rectangles. Choose the first valid pair from at most
256 combinations, then commit their disclosed initial positions together.
Record all32 bounded candidate proofs and the chosen pair. No failed candidate
moves an actor; no stat, identity, speed, body shape or collider is changed.
The actual Director tick still owns ordinary death, police removal, the
captured detached Brendan continuation and post-respawn taser. If no pair
passes, fail before that tick rather than weaken clearance or lifecycle gates.

Seeds are declared before a trigger, never repeatedly rerolled until a desirable
effect appears. RNG expectations use GameState's existing LCG. Fresh random
bottle positions are accepted as source-owned. If an actual actor, source prop,
legal eye position or transition is unavailable, the case fails explicitly.

## Rendering and evidence

Run at1280x720 or960x540, one resolution per invocation. Packet B is eleven cases,
13 transition contexts; Packet A seven contexts. Limits:24 contexts,96 PNGs,
300seconds global wall time including startup,90seconds startup,8seconds admitted
source time per transition. No route tour or live combat completion is claimed.

The combined candidate may additionally contain `walking_dust` and
`ambient_mote`, tested in their own packet. This probe still requires every
one of its18 named burst recipes and exact source birth counts, records
incidental dust honestly, and never counts dust toward its nine-per-packet
coverage or suppresses its scheduler.

Combined authority-v5 completed every physical case, but its two projectile
impact recovery checks incorrectly tracked ambient motes already born during
flight. Those source motes live4500–6000ms, outside the burst packet's2200ms
expiry bound. Retain the failed report. Track only birth serials whose recipe
belongs to the current context's declared burst list, within its captured epoch.
Preserve all incidental motes and the full mixed pool in every report and PNG.
Do not extend the2200ms bound, clear motes, change aging or accept a retained
original burst merely because another particle expired. Counterexamples include
a retained original burst beside a long-lived mote, an expired burst with that
same mote still alive, a new later same-recipe birth, and an epoch replacement.

### Actual pose clock and opaque HUD proof correction

Retain v5/v6 effects/physics evidence with an explicit pose limitation. The old
probe advanced Runtime but only called `_sync_model_nodes(0)`, which never calls
ActorAnimation.tick. Reset rigs therefore retained three coat layers even after
Director snapshots had the correct Tony coat_count. After each accepted Runtime
step, call the real `_sync_model_nodes(last_advanced_ms/1000)` once, before Scene
event consumption, matching FullScene order. Use actual admitted time including
zero for hitpause; never epsilon, extra source ticks or independent pose clocks.
Apply this to both ordinary aging and projectile flight. Capture painting stays
delta0, so screenshot/shake pairs remain frozen. A birth immediately following
a direct owner command is explicitly before its next admitted pose frame.

Each context identifies at most two relevant original actors. Captures record
their actual Director snapshot, model coat/dead fields, rig frame/time/last_state,
and visible/total mesh counts for the three coat layers. Active/midlife/recovery
must agree with the current Director coat count, action serial/contact/dead/
grounded/hurt state, and supported nonempty action; ambient fallback stays owned
by FullScene. An actually removed actor must have no retained view entry. This
does not assert model/Director equality during the source's one-step phase lag.
No all-roster pose dump or altered actor presentation is introduced.

The960px v6 shake pair has three exact opaque gold glyph pixels with identical
hashes; the old12-glyph minimum is font-raster dependent. Keep the12-pixel minimum
for combined opaque foreground. Preserve glyph count/hash separately and add
pixels from the existing health meter's actual opaque StyleBoxFlat fill. Derive
the filled rectangle from actual Control size, range ratio, fill minimum size
and LTR fill mode using Godot4.5.1's real ProgressBar draw formula, transform it
through the actual Control-to-screen transform, and inset the bounds by two
framebuffer pixels. Require flat opaque style/no borders or rounded corners,
unit inherited alpha and no percentage overlay. Reject unsupported styles.
Only original-image pixels matching the known opaque fill RGB enter the mask;
compare identical coordinates as exact original RGBA bytes against the shifted
image. The translucent meter background/plate is never evidence. Combined unique
glyph+fill pixels must remain at least12 and byte-identical at either size.

Formula authority: [Godot4.5.1 ProgressBar draw implementation](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/gui/progress_bar.cpp#L100).
No HUD/gameplay changes, new Canvas render, image manipulation or lower threshold.

Every context records initial fixture, actual trigger return/events, old/new
source data, pool before/after (epoch, serials, recipe counts, anchors, life),
actual presenter counts, source hash availability and PNG SHA256. Birth means the
first rendered observation after the accepted owner callback, before any later
source update. Active is80ms admitted source time (hitpause wall time separately
recorded). Recovery waits until all particles born in that context expire, with
a bounded2200ms admitted limit; unrelated new emissions are reported separately.

The initial native core report is retained as failed evidence: its Lurch melee
anchor was27.88m from the nearest source building, so the11m occlusion search
could not produce a close wall. The corrected fixture uses the existing Tony
ordinary-melee placement instead; actor/world geometry and source receipts stay
unchanged. Occlusion requires an actual structures:* collider and a near-horizontal
wall normal, not an invisible map boundary or floor.

CoreV2 still lacked a suitable radial eye and is retained. The bounded correction
uses actual World standing-wall AABBs, not a guessed actor or guide point: select
the nearest16 structures:* slabs within12m, height>=2m, horizontal thickness<=.55m
and length>=.8m. Place an eye across the full slab thickness on its opposite face,
then try only.3m/.7m outward clearance. Every candidate still needs the actual eye
sphere clear, no rig overlap, and an actual horizontal structures:* ray hit to
the unchanged particle point. If all fail, the original64 radial candidates are
the finite fallback. Record every rejected candidate's eye proof, ray owner,
normal and expected wall; failure stays failure. No occluder or actor is moved.

Before the invariant capture window, paint once and allow one deferred GUI layout
frame without advancing source time. Record full pre-layout/settled/end states
and exact field differences. Camera/player/FOV must remain unchanged even during
settling; all HUD transforms must remain unchanged during the measured capture.
This isolates legitimate label/container minimum-size layout without ignoring an
actual shake-driven transform mutation.

### Physics-preserving callback suspension correction

V1–V3 used `FullScene.process_mode = PROCESS_MODE_DISABLED`. This was a probe
defect: inherited CollisionObject3D nodes default to `DISABLE_MODE_REMOVE`, so
the visible walls were removed from the physics space. Empty ray/overlap results
did not prove physical clearance. Preserve all failed reports/images; their
physics/framing claims are invalid and images are art reference only.

Suspend only the FullScene and HUD process, physics-process and input callbacks,
using the corresponding `set_process*` methods. Do not change Node.process_mode,
CollisionObject3D.disable_mode, masks, transforms, shapes or geometry. FullScene
owns the model clock; manually admitted Runtime intervals remain authoritative.
HUD deferred layout/rendering still runs, while its autonomous timers stay held.

Before each source fixture, after actual physics synchronization, use an existing
axis-aligned standing `structures:building_01` wall as a sentinel: its real body
must remain processable on layer1; a sphere at the actual wall-box center must
overlap that body, and a ray across the actual full slab thickness must hit that
same body. Record its actual bounds, transform, process/disable modes, mask,
ray hit and overlap owners. A missing sentinel fails the case before the trigger;
no fake blocker, extra search radius, collider mutation or actor relocation.

Reference: [Godot4.5 CollisionObject3D disable mode](https://docs.godotengine.org/en/4.5/classes/class_collisionobject3d.html#enum-collisionobject3d-disablemode)
and [Node callback processing](https://docs.godotengine.org/en/4.5/classes/class_node.html#class-node-method-set-process).

The melee context adds a near-camera view and a same-pose world-offset pair.
The pair must keep actual Camera3D transform/FOV, player transform/aim basis and
all HUD Control transforms byte-equal. Fully opaque gold foreground pixels of the
existing status label are selected from the baseline image and hashed again at
the same coordinates; they must remain unchanged when only the supplied
world-feedback strength changes0→1. The plate itself is translucent, so its
background pixels are explicitly excluded. This proves stability, not aesthetic quality.
The ordinary active image retains strength1. No source shake is invented.

Ground-burst contexts `trash_cash`, `trash_rats`, `dumpster` and `possum` also
capture a midlife image after at least250ms of actual admitted Runtime time.
The80ms active frame is retained: a can can legitimately hide the first ground
births. Advance the same source owner/pool through ordinary intervals, record
the exact admitted total and retained birth serial count, then recover normally.
Do not move the anchor, prop, geometry or camera to expose the effect, increase
alpha/count/life, or call particle advancement directly. An effect still hidden
at midlife is reported/reviewed as occluded, not automatically visually accepted.
This adds four core captures and retains the96-image/300s global caps.

### Ground birth inside its source can

The real-physics art-core-v4 run passed the existing-wall sentinels and melee
occlusion view, but refused both trash contexts because the canonical ground
anchor lies inside its selected standing can. Preserve that failed report.
For only these two contexts, framing may accept a clear observer sphere whose
first ray hit is the exact live StaticBody3D returned by
`prop_view.collider(selected.id)`, with its canonical trashcan owner0..5.
Matching metadata on another body is insufficient. A different can, a wall,
floor or unowned collider still rejects the observer. The pre-trigger frame
uses this same rule so the ordinary feedback bridge captures the intended
camera-right basis. No collider, mesh, anchor or source state is changed.

Report `clear` versus `source_prop_occluded` separately, including the actual
first-hit owner/position/normal, selected body transform/shape and clear-eye
proof. Accepting a framing fixture does not assert that its birth is visible.
At birth,80ms and250ms, cast at most220 real rays to retained original particle
centers from the unchanged camera, using the same immutable anchor, frozen
birth-right and current source-aged offsets as the presenter. Report clear,
source-can and other-obstacle counts and every first hit. These are collision
center sightlines, not mesh/pixel visibility proof: the original PNGs decide
whether the burst emerges. No favorable recapture, extra source aging, moving
camera or automatic visual acceptance is allowed. Actual-wall occlusion
continues to require an unrelated real standing structure as before.

An occlusion view finds a real wall between a clear observer eye and the same
live melee effect, preserving source/pool state. The report records the actual
ray collider and image; native/Web reviewers decide visual depth correctness.
If no bounded real occluder can be found, that evidence item fails rather than
adding a fake blocker. Near-camera framing similarly requires a clear eye sphere.

The isolated draft is ready only after static contract checks; engine PASS and
visual acceptance remain separate. A report can say `complete:true` while
`acceptance:false`; all case and context completion counts must match. Runtime
errors cannot yield PASS because an independent global watchdog writes failure.

## Actual pose clock and opaque HUD proof correction

Retain v5/v6 as effects/physics evidence with a pose limitation: their manual
Runtime steps were followed only by zero-delta model synchronization, leaving
ActorPose at its reset state (including three Tony coat layers). They do not
prove active actor presentation. After each accepted Runtime interval, synchronize
model nodes exactly once with `last_advanced_ms/1000.0`, before Scene event
consumption, matching normal FullScene order. This applies to burst aging and
projectile travel. Zero admitted time stays zero; no epsilon or extra source step
is allowed. Painting remains zero-delta and capture/shake pairs keep clocks frozen.
Direct-command birth is explicitly before the next admitted pose boundary.

Each context names at most two relevant actors. Capture their current model,
Director snapshot, rig frame/time/state and visible/total mesh counts for each
coat layer. At active/midlife/recovery, require the rig's coat count, layer
visibility, action serial/contact/dead/grounded/hurt state and supported explicit
action to match the current Director snapshot. FullScene retains its own ambient
action fallback. A removed actor must have no retained Scene actor entry. Record
model phase separately: source ordering can put it one step ahead of Director.

The960 v6 image pair had three opaque gold glyph pixels with identical bytes.
Keep the minimum12 foreground-pixel requirement, adding the actual health
ProgressBar's opaque StyleBoxFlat fill. Derive its filled rectangle from current
value/range ratio, Control size, fill minimum size and the ordinary left-to-right
mode, then map its actual Control transform into framebuffer coordinates and
inset two framebuffer pixels. Reject transparent, bordered, rounded, mirrored,
rotated or otherwise unsupported fill configurations. Use only original pixels
matching the known opaque fill color; compare exact RGBA bytes at identical
coordinates. Report glyph and fill counts/hashes separately and require at least
12 unique combined pixels. Translucent plates and world backgrounds are excluded;
no UI, screenshot, threshold or shader change is permitted. The fill extent uses
the pinned engine's [ProgressBar draw rule](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/gui/progress_bar.cpp#L100).

Contract counterexamples cover the old three-coat state, action/contact drift,
zero admitted pose time, insufficient glyph-only evidence, fill shrinkage and
unsupported opacity/style/transforms. Native/Web reruns remain required.

## Thin Web entry

`web_feedback_visual_probe.gd` inherits the held native scenario and only wraps
capture/final report IO. It sends bytes read from each original saved framebuffer
PNG, plus that file's SHA256. It does not redraw, resize or recolor a frame.
The browser verifies SHA256 and decoded1280x720/960x540 dimensions, keeps at most96
images/192MiB, and offers individually selected original PNG/JSON downloads.
An optional `<img>` displays a labeled captured PNG; the actual live Godot canvas
remains separate and can be selected. There is no Canvas2D replacement.

The shell requires an explicit Start click, finite core/authority and1280/960
selection, and reload for another run. It supplies `--qa-full` before engine
startup. The existing `game3d/web/storage.js` is reused unchanged; normal source
save requests use the probe's separate `world_feedback_visual_fixture` key. A
unique user:// output directory isolates each report and its original PNG files.
Browser and engine each retain the300s failure watchdog; browser time also includes
download/startup. A browser timeout marks the run incomplete and instructs close
or reload; it never fabricates a model result. Native-script logic is unchanged.

DOM evidence is `window.rbFeedbackEvidence`; `#status`, `#frame-label`, `#report`
and the download controls expose the same bounded report for CUA. Browser
acceptance requires engine receipts, exact capture count, every original PNG
verified, WebGL2 and no engine/browser errors. `visual_acceptance` remains false
until external human review. Exported source hashes may be unavailable and do
not replace the archived copied-source/export hashes.

## Central invocation (not executed by agent)

Copy the draft's two `.gd` files into the isolated candidate's `game3d/tests/`.
Do not overwrite the candidate's feedback source. Run the contract first:

```
Godot --headless --path <isolated/game3d> --script res://tests/test_world_feedback_visual_contract.gd
Godot --path <isolated/game3d> --script res://tests/world_feedback_visual_probe.gd -- --qa-full --packet=core --width=1280 --output=<fresh-dir>
Godot --path <isolated/game3d> --script res://tests/world_feedback_visual_probe.gd -- --qa-full --packet=authority --width=960 --output=<another-fresh-dir>
```

Both packets must be run at both sizes for complete native coverage. Exported
Web use needs the root's existing browser entry/JavaScriptBridge wrapper; this
draft is the native scenario and evidence schema, not a Web PASS. Compiled script
hashes may be unavailable; the copied-source manifest/export hashes remain the
provenance authority. No hidden screenshot Canvas or mocked renderer is used.
