# 3D full-port animation inventory and P01 contract

2026-11-18. Read-only source audit before implementation, followed by the bounded P01 proposal
under `SPEC-3D-FULL-PORT.md`. This is an inventory and subordinate presentation contract, not
a claim of full-port parity. Source inspected: the active `src/` game, current `game3d/` rigs,
and VIBE in full. Frozen v19 was not used as the live authority.

## Current 3D implementation

| Area | Actual implementation | Gap relevant to the port |
|---|---|---|
| Cast | `character_art.gd:create_character` makes Tony, Pete, Yuri, Lurch, possum, Brutus and player hands | Six world identities; the full active cast is much larger |
| Geometry | Original cached authored cross-sections, selective normals, static children batched per pivot | Coherent silhouettes exist, but there are no deforming elbow/knee/hand joints or authored character UVs |
| Human rig | Head; left/right shoulder; nested forearm; left/right leg | No pelvis/spine/clavicle/hand/finger/knee/ankle articulation; legs swing as a single rigid piece |
| Animal rig | Head, four whole legs, tail; Brutus jaw and ear pivots | No articulated feet/hocks, spine or attack-specific poses |
| Pose API | `animate_character(root,id,time,moving,punch)` and cached rest transforms | `punch` means elapsed phase for hands but windup progress for Lurch; cannot express contact, items, hurt, death or layered gestures |
| Idle | Tony slow head turn; Pete cyclic bite; Yuri look; Lurch crooked head; animal breathing/tail sway | Identity idles are useful but largely share the same global sine phase |
| Locomotion | Human leg/arm sine swing; animal paired-leg sine swing | No planted stance, knee lift, turn/strafe response or sprint state |
| Hands | Two always-closed fists at camera-local `(±0.275,-0.385,-0.50)`; all finger surfaces are static | Rest is a permanent guard; fingers cannot relax, grip or present an item |
| Hand movement | `main.gd:244` adds input-based root bob; `character_art.gd:103` adds another gait layer | Two presentation owners; a blocked player still bobs; no sprint/look input to the rig |
| Punch | Main accepts every 0.28s; 0.22s right-only visual; immediate ray and damage | Sine reaches extension about 0.11s after the immediate hit; hit/miss/contact does not reach the viewmodel |
| Interactions | `_act` validates transaction, resumes, emits receipt/audio, updates finds and saves | No collect/eat/smoke/receipt gesture; absence of gesture currently does not delay gameplay |
| Enemy | Lurch windup 0.65s, cooldown 1.6s, immediate model recoil on player hit, Art root tipped on death | Slice-specific attack is not the source grabber; Brutus has no charge behavior in the slice |
| Pause | Physics returns unless playing; active `clock` feeds poses | Keep this property. A separate automatic `_process` animation loop would violate it |
| Camera | FOV 78, near 0.06m, eye 1.63m; first-person model has no shadows | Retain clear sightline, no eye-plane intersection, no floating hand shadows |

Source anchors: `game3d/scripts/main.gd:_make_player`, `_physics_process`, `_act`, `_punch`,
`_tick_enemy`, `_animate_people`; `game3d/scripts/character_art.gd:_cache_rig`,
`animate_character`, `_arm`, `_leg`, `_hands`. Parent remains owner of simulation/input integration.

## Active 2D art and identity coverage

`src/render/sprites.js:buildSprites` contains **42 humanoid style definitions**. Five extra
humanoid state bases cover three Tony coat-loss states, sleeping Dave and fallen O'Malley.
Seven special bases cover Brutus, scrap dog, Old School Brutus, possum, pigeon, mounted cop and
pothole. These are **54 NPC visual bases**, not 54 distinct runtime actors. Repeated spawns,
day-event aliases and dialogue-only occupants must be tracked separately.

The current manifest has **94 total bases**, checked from `sprite_manifest.js`; VIBE's historical
93-base paragraph describes an earlier pinned corpus. Do not silently use that historical count
as the present port denominator. Player/equipment/weapon/incident bases are not all NPCs.

| Existing source identity/art family | Silhouette and prop evidence to preserve | Required presentation vocabulary |
|---|---|---|
| Tony; `tony_coat_2`, `tony_coat_1`, `tony_bare` | Three badly stacked coats, fixed eyes | Still idle, distinct visible coat count, boss phase presentation, melee/recoil; never blink |
| Yuri, Pete | Yuri bald crown/square beard/hubcap; Pete wide body/apron/pocket/hot pocket | Weigh/present metal, bite/chew, transaction acknowledgement. Current 3D Yuri cap/scarf and Pete shirt do not yet reproduce all sprite signatures |
| Lurch, Sherri, Paulie, Larry | Long elbows/slumped shoulders; thin fast spiky-haired phone holder; oversized face; yelling body with raised hands | Grab/contact hold, quick pursuit, aim/throw/panic, yell/strike |
| Dave, Mom, priest/fallen priest | Dave horizontal sleeping body/pillow/slipper/drool; Mom tote/bottle/sensible shoes; priest collar/cross, fallen untucked state | Sleep/wake, hold/present, stand/talk, ranged throw and charge phase |
| Conductor, Stripe, Big Guy | Cap/ticket punch/timetable; hood/stripe/soap packet; tall and wide | Wait, inspect/present, ally attack/follow, cart transaction |
| Barb, Pinky, Mathematician, Price Guy | Cardigan/purse/low glasses; uneven braids; crooked glasses/board; black brim/coat/tag | Read without looking up, small exchange, board glance, deliberate stillness |
| Cubscout, Jogger, Dog Walker/Paisley | Pack/sash/popcorn; headband/bent limbs/stopwatch; leash and separate little dog | Patrol, jog, hold item, walk human/dog pair, brief pet response |
| Busker, Vape Lord, Mayor's Cousin, Phone Guy | Guitar/case; device/backpack dragon; jacket/no pants/bread phone; phone/cord/power bank | Strum, idle exhale, call, tap/show phone. These are tics, not new reward sources |
| Laundromat Lady, Meter Maid, Food Truck Guy, Priest's Son, Karaoke Mike | Basket/shirt, ticket book, apron/pad/spatula, cap/collar/player, microphone/machine/cable | Fold, write, serve, listen, hold microphone |
| Train Hopper, Philosopher, Leasing Guy, Gutter Greg | Pack/bedroll/beard; cane/pockets/glasses; clipboard/key ring; hook/rubber duck | Rest, feed birds, inspect/write/point, count inventory |
| Cop, Cousin Brendan | Broad/junior caps, badges, baton/coffee or radio/light | Pursuit, strike, hand-to-radio, taser readiness/contact; readable recovery |
| Tarp/receipt/wire guards and their rulers | Tarp silhouette, paper sash/crown/scroll, wire coils/mitre/staff | Shared charge/grab/ranged rigs with identity-specific props; do not recolor one undifferentiated mannequin |
| Curb Emperor, Knight Emeritus, pretenders | Crown, chair struts, layered garments; conquered uniform variants | Phase transitions, shared attack families, seated/throne presentation where source establishes it |
| Brutus / older / Old School / scrap dog | Old cloudy eye/jowl/collar; older heavy hump/towel; scrap dog's ribs/missing fur | Walk, windup/lunge/pant, bite, hurt; chained/fed/free/follow/tail-wag states |
| Possum / pet possum | Low hunch, pointed face, thin tail, tiny helmet | Walk/retreat, observe, follow and cash-reveal acknowledgement |
| Pigeon King | One foot, crown, fixed stare | One-foot hop, wing beat, head turn; no invented second foot or blink |
| Horse Cop | Rider, reins, four horse legs | Mounted patrol, separate horse/rider nods, rear outcome |
| Talking pothole | Flat road defect with three mouth states | Local mouth change, no standing humanoid rig |

The authoritative authored signatures are in `sprite_art_npc_32.js:applySignature` and
`sprite_art_special_32.js`. Most signatures are **static authored details**; a proposed 3D
strum/write/fold gesture is a visual interpretation of the tic, not evidence that a full animation
already exists in 2D. The 2D human builder creates three frames; animal/mounted/sleep bases use
two. `actors_weather.js:resolveNpcPose` selects them without changing simulation state.

Runtime aliases matter: skid variants reuse Brutus/Lurch/Sherri; Sherri siblings reuse Sherri;
`pet_possum` reuses possum; the bus driver and stranger reuse Lurch; older Brutus uses Brutus
while Old School Brutus has `os_brutus`; kingdom guards/pretenders share clan bases. Preserve
runtime actor ID, visual identity and combat archetype as separate fields.

Dennis, the Raccoon Quorum, Transit Authority Dan, the Model Family, the Former Teller, the Goose,
the Lifeguard and the Docent are defined through `src/data/props.js` site dialogue. They are
canonical identities but currently have no independent sprite base in this inventory. Full 3D
presence needs an explicit site-art packet; do not claim they are already modeled NPCs or invent
patrol/combat behavior to fill the gap. The Model Family's stillness is intentional.

## Existing action/state evidence

| Source state | Evidence | Animation mapping must preserve |
|---|---|---|
| Player walk/sprint/high/crash/stun/slow | `core/update.js:updateWorld` | Gameplay speed/status ownership; 18s high and 8s crash remain exact; gait follows actual displacement |
| Player attack | `systems/combat.js:playerAttack`; `activities.js:WEAPONS` | Immediate source hit resolution, weapon-specific cooldown/reach/damage, hit-stun/hit pause and knockback ownership |
| Nine weapon identities | fists, pipe, brick, cart_wheel, shoe, baguette, microphone, knife, broken_bottle | Separate grip/swing families, visible equipped object; no new weapon introduced by art |
| Visible gear | `catalogs.js:EQUIPMENT`; `actors_weather.js:drawPlayer` | Hat/coat/shoes/tool layers and route patch; first-person sleeves/held tool should reflect equipment when ported |
| Collect/dumpster/buy/sell/eat/phone/cart | `systems/interactions.js`, dialogue modules, `activities.js` | Receipt after authoritative success; no resources committed by a clip or queued twice |
| Smoke / soap / hitter | `concessions.js:smokeRockAt`, `hitter.js`, `core/update.js` | Distinct outcomes and timers; abstract hand acknowledgement only, no preparation/paraphernalia sequence |
| NPC patrol/wander/leave/follow/ally | `npc_ai.js:updateNpcActors` | Root motion stays with AI/physics; visual culling cannot suspend simulation |
| Charger | `npc_ai.js:124` onward | Windup → locked-direction lunge → cooldown/pant; actual duration/phase supplied by gameplay |
| Grabber | `npc_ai.js:210` onward | Arms extended during brief grab freeze; player stun/robbery resolved by source behavior, never by hand contact animation |
| Swarmer | `npc_ai.js:238` onward | Faster pursuit/quick contact; sibling spawn remains simulation |
| Ranged/fallen priest | `npc_ai.js:252` onward | Aim raise then projectile release; panic and later charge phase; never release another projectile from a clip event |
| Hit/essential/death | `combat.js:playerAttack`, `onNpcDeath` | Essential actors remain available and undisplaced; hit reactions must not bypass protected behavior |
| Tony boss coat phases | `combat.js:spawnBoss`; `core/update.js:760` onward | Visible coat count follows `coatsOff`; decorative removal cannot alter phase or rewards |
| Sleep/awake, chained/free/fed | `neighborhood_a.js`, `core/update.js:499` | State-driven pose change, not a random idle that contradicts durable state |
| Radio/taser | `combat.js:manageCops`, `npc_ai.js` | `radioVisualT` and charge/contact as presentation inputs, no separate authority timers |

## P01: bounded first-person implementation contract

Implement a self-contained `game3d/scripts/first_person_rig.gd` and
`game3d/tests/test_viewmodel.gd`. Parent owns production integration. Existing world/NPC art and
its API remain unchanged in this packet. Full NPC skeleton migration is later work.

Proposed API, sent to parent before generation:

```gdscript
static func create() -> Node3D
func reset() -> void
func tick(delta: float, local_velocity: Vector3, sprinting: bool,
    high: bool = false, crash: bool = false, shakes: float = 0.0,
    look_delta: Vector2 = Vector2.ZERO) -> void
func acknowledge(action: StringName, success: bool = true, contact: bool = false) -> void
```

`local_velocity` is actual post-collision horizontal player velocity in metres/second, relative
to player yaw; Y is ignored. `look_delta` is accumulated yaw/pitch radians for this active tick,
not raw mouse pixels. Shakes use the existing 0–100 scale. No automatic processing callback:
only `tick` advances the rig. Dialogue/pause/focus loss freeze it; new/load/death call `reset`.
No gameplay references, resource counters, cooldown checks, saves, random outcomes or callbacks
belong in the rig. Parent removes the existing duplicate root bob and Art hand animation call.

Input handling for P01: nonfinite/negative/zero delta is a no-op; a stalled positive delta is
capped to 0.10s for presentation. Nonfinite velocity/look/shakes components become zero;
velocity, look rate and shakes are bounded. These clamps never modify simulation data.
The initial presentation uses the live slice's 3.6m/s gait/strafe normalization and a 12m/s
visual velocity cap. Full-world controller activation must revisit that normalization and
cadence for its proposed 5.5m/s base and 16.83m/s high/sprint peak; visual saturation must not
silently become a simulation speed cap.

The implementation exposes presentation observations `action`, `action_phase` and
`last_punch_side` for captures. Stable marker paths are
`left_arm/forearm/wrist/{palm_marker,knuckle_marker}` and their `right_arm` counterparts.
Each wrist has `index`, `middle`, `ring`, `little` chains with nested `middle/tip` joints,
plus `thumb/tip`. Context props are `left_arm/forearm/wrist/receipt` and
`right_arm/forearm/wrist/food`. The controller root has `rig_kind=first_person` metadata.
These are visual inspection handles, not gameplay targets.

The new test entry is `res://tests/test_viewmodel.gd`. Parent runs it centrally with the pinned
engine: `Godot_v4.5.1-stable_win64_console.exe --headless --path game3d --script res://tests/test_viewmodel.gd`.
This audit/implementation agent did not launch the engine or alter the central runner.

The viewmodel starts with relaxed, slightly curled fingers low at the screen edges, wrists partly
out of view and a clear center. Original higher-detail palms and fingers have wrist, knuckle and
finger curl pivots; thumb motion closes across the fist. Sleeves conceal articulated elbow joins.
Geometry and materials are cached once and shared across instances. Articulated pieces retain
their individual rigid meshes; no per-instance batching or per-frame reconstruction occurs.
All hand and action-prop meshes suppress shadows. FOV 78
and near 0.06m are the first acceptance camera, with wider/narrower viewport checks as well.

Locomotion phase follows travelled distance/speed, stops at a wall, and blends to rest without
snapping. Walk has unequal small arm swing; sprint pulls arms lower/back and increases cadence.
Look lag is damped and clamped on the arms only. High/crash/shakes can change bounded hand
energy/tremor; they never steer the camera or create another status timer.

| Acknowledged visual action | Pose and provisional maximum visual duration | Authority/cancellation |
|---|---|---|
| `punch` | Alternate left/right; rapid extension, contact compression or miss follow-through, recovery within current 0.28s cadence | Main retains cooldown and immediate hit; no delayed damage callback, long windup or input lock |
| `interact` | Brief open-hand reach, about 0.24s | Successful interaction only; no handshake or forced camera |
| `pickup` | Low reach/curl/withdraw, about 0.32s | Item already collected; repeated pickups coalesce |
| `receipt` | Small palm/paper acknowledgement, about 0.32s | Transaction already committed; no cash-counting wait |
| `eat` | Brief hand-to-lower-edge motion with generic food silhouette, about 0.50s | Effect already applied; no animation-gated healing |
| `smoke` | Abstract brief hand lift near screen edge and withdrawal, about 0.55s | High starts immediately; no real equipment, preparation or technique depiction |
| `equip` | Lower and return hands, about 0.26s | Cosmetic acknowledgement now; actual equipment props/grip families come with their parity packet |

Failed actions do nothing. Accepted punches interrupt cosmetic gestures; newer accepted cosmetic
actions replace or coalesce, never build an unbounded queue. Interrupted gestures do not refund
or repeat gameplay effects. Reset clears held presentation props and returns the next punch to
its documented initial side. Contact is presentation feedback only. The existing immediate hit
contract rules out adding a long anticipation phase; any future delayed contact window requires
a separate combat amendment, not an animation implementation choice.

## Scalable NPC rig and art proposal for later packets

Use a data definition separating `actor_id`, `visual_id`, `rig_kind`, proportions, clothing,
props/sockets, idle policy, allowed gestures and state variants. A common human hierarchy adds
pelvis/spine/neck, upper/lower legs/feet and wrists to the current anatomy. Quadruped, bird,
mounted and flat-world-object families have their own rigs. Props attach to named sockets;
Tony's coat layers remain individually switchable. Large hands, bent knees, skinny shoulders,
potbellies and asymmetry are authored identity data, not global scale alone.

For deforming near characters, evaluate original native `Skeleton3D`/`Skin` meshes and authored
`AnimationLibrary` clips, with bounded procedural look/breath layered above. Godot 4.5 documents
the bone/rest/pose hierarchy and library-based playback; Compatibility is the OpenGL renderer
used by default for Web. This is an implementation direction, not an unmeasured performance
guarantee: [Skeleton3D](https://docs.godotengine.org/en/4.5/classes/class_skeleton3d.html),
[Skin](https://docs.godotengine.org/en/4.5/classes/class_skin.html),
[AnimationPlayer](https://docs.godotengine.org/en/4.5/classes/class_animationplayer.html),
[renderers](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html).

Start with roughly 20–26 human body bones plus optional hand detail, and a richer viewmodel hand
rig. Four influences per vertex are a proposed conservative budget, not an engine limit claim.
Target close human meshes around 6–12k triangles, reduced distant variants and a small shared
material set; these are **provisional art budgets**, subject to native/Web and actual-AI profiling.
More polygons should buy eyelids, cheeks, finger joints and smooth joint deformation, not dense
noise. Native cached meshes or reproducible authored local assets are both acceptable; no stock
pack, external runtime dependency or borrowed reference asset.

Skinned surfaces should receive stable authored UVs and restrained painted/baked wear masks.
Current object-space triplanar mapping is useful for rigid pieces, but is not a complete solution
for skin/cloth deforming across joints. Share cloth/skin atlases where practical; keep face marks,
seams and grime attached to their anatomy. Do not apply generic grit over every face. Higher
resolution and atlas memory must be measured on the actual Web export.

Replace the overloaded `punch` argument with a read-only actor presentation snapshot: actual
local velocity, facing/turn rate, grounded state, action kind/phase, attack ID, contact result,
hurt/recovery/dead state, equipment/coat state, and deterministic idle seed. Continuous action
phase comes from simulation; visual-only clocks cannot mint hits or projectiles. Keep one pose
owner. Preserve existing queryable head/limb markers through an adapter during migration; do
not run old pivot animation and new skeletal animation on the same limb.

Distance-aware art scheduling can reduce far-away finger/face/secondary motion and use coarser
meshes; combat silhouettes and state transitions remain legible. Simulation and threat timers
continue off screen. Report 60+ actual AI cost separately from the previous art-only stress.

## Packet boundaries and acceptance

1. **P01 now:** relaxed articulated viewmodel, actual-motion gait/sprint/look, both punches and
   successful-action gestures, production wiring, tests and eye review. No new NPC identity,
   attack rule, item governor or status timer.
2. **NPC rig foundation:** migrate the existing six identities with idle/walk/turn/hurt/death
   presentation and needed current combat phases. Retain authored identity and pause contracts.
3. **Core/ambient cast packets:** add source residents in bounded region groups, with their
   actual interactions, prop sockets and identity idles. A decorative model alone is not parity.
4. **Authority/companions and combat families:** radio/taser, chained/fed/free dogs, mounted
   actors, pigeon, thrown items, grabs and chargers, alongside corresponding gameplay ports.
5. **Boss/campaign/site packets:** coat-loss/fallen forms, clan clothing/props, throne states and
   dialogue-only site occupants. Do not invent movement for intentionally still residents.

Meaningful P01 checks: resting hands remain low; left/right punches alternate and settle;
contact and miss produce distinct visual response; failure is a no-op; rapid requests cannot
leave stuck props; reset clears all offsets; walk at a wall is absent when supplied velocity is
zero; sprint/look/tremor remain bounded; finite transforms and finite unit mesh normals; no
collision bodies or hand shadows; mesh/material identities remain stable across repeated ticks.
Inspect native and Web rest/walk/sprint/look, both punches, contact/recovery and each contextual
gesture at eye level. Keep camera input and menus responsive during gestures. Existing 18s/8s,
spending, ray/collision, pause/save and legacy gates stay green.

For later skinned rigs add normalized finite bone weights, UV bounds, joint deformation and
prop socket tests; inspect face profiles, knees/elbows, clothing overlap and foot contact.
All observations here are source findings; no engine, game or browser was run for this audit.
