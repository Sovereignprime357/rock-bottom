# SPEC — Character roster and presentation P05a

Captured 2026-11-18 before generation, approved by root under SPEC-3D-FULL-PORT.md.
Owned new files: `game3d/scripts/character_roster.gd`,
`game3d/scripts/actor_animation.gd`, `game3d/tests/test_character_roster.gd`.
This spec and the animation inventory report are also within this packet. No main, legacy
character art, source 2D, engine, gate-runner or git changes belong to this worker.

## Boundary and API

P05a migrates six existing visual identities: Tony, Pete, Yuri, Lurch, Brutus and possum.
It establishes the human and quadruped rig families; it does not claim the other 57 registry
identities, their interactions or their future bird/mounted/object families are delivered.
Roster names/roles remain source-backed. Physics, AI, transactions, roots, saves and hit timing
belong to production controllers. Source actors, visual IDs and combat archetypes remain separate.

```gdscript
# character_roster.gd — immutable shared authoring definitions/resources.
static func supported_visuals() -> PackedStringArray
static func definition(visual_id: StringName) -> Dictionary
static func create(visual_id: StringName, instance_seed: int = 0) -> Node3D

# actor_animation.gd — presentation only, called explicitly during active play.
static func reset(art: Node3D) -> void
static func tick(art: Node3D, delta: float, snapshot: Dictionary, detail: int = 0) -> void
```

Unsupported IDs return an empty definition/null model. No generic actor silently fills a missing
identity. Definitions returned to callers are deep copies; cached Mesh/Skin/Material resources
are shared and immutable. Per-instance bone poses, coats, props, clocks and cached bindings are
independent. Construction returns a grounded origin facing **+Z**. Godot camera forward is -Z:
the CastDirector adapter must explicitly convert its movement convention to actor-local +Z;
do not pass camera-local velocity unchanged.

| Snapshot key | Type/default | Meaning |
|---|---|---|
| local_velocity | Vector3.ZERO | Actual post-collision actor-local metres/second; +Z forward, Y ignored |
| turn_rate | float 0 | Actual yaw rate in radians/second |
| grounded | bool true | Cosmetic feet support; no physics ray or collision decision |
| action | StringName empty | Authoritative presentation action family |
| action_phase | float 0 | Normalized current simulation phase; controller never waits for a clip |
| action_serial | int 0 | Stable accepted-action sequence; cosmetic side variation only |
| ambient_action | bool false | True only for an injected ambient identity gesture; never grants gameplay timing authority |
| contact | bool false | Existing resolved contact; no new hit/projectile callbacks |
| hurt | float 0 | Authoritative 0..1 recoil envelope |
| dead | bool false | Authoritative death state, overrides idle/action |
| death_phase | float 1 | Authoritative 0..1 collapse progress; no animation-owned death timer |
| coat_count | int 3 | Tony's exact visible layers 3/2/1/0; pure presentation |
| gaze | Vector2.ZERO | Optional bounded head yaw/pitch radians |
| asleep | bool false | Source sleep state; Dave uses it only when no stronger current action is selected |

Malformed/nonfinite inputs normalize safely without modifying the snapshot. Invalid or nonpositive
delta does not advance any presentation. Positive stalled frames cap cosmetic integration.
Known values are bounded. Unknown actions return to the base locomotion/idle pose; capability
lists expose the implemented vocabulary so production integration can detect unsupported intent.

P05a humans expose idle/talk/eat/inspect/windup/strike/grab/throw and hurt/death overlays.
Quadrupeds expose idle/windup/lunge/bite and hurt/death overlays. `strike` begins at extension
and recovers, matching already-resolved immediate combat; windup is a separate simulation phase.
No clip events. Reset restores all bones/props/coat defaults and deterministic seeded idle phase.

## Bounded presentation scheduling — actual60 follow-up

The diagnostic actual60 profile measured the inclusive model synchronization scope at6.795ms
p95 in the core and6.274ms at the train yard. Most stationary residents received a nonempty
ambient identity action, bypassing the existing distant idle schedule. The approved correction
distinguishes that provenance with `ambient_action`, default false. At detail2 an unchanged
ambient gesture follows the existing every-third-call cosmetic schedule (about20Hz at60Hz).
Time, gait integration and child snapshots are still consumed on every call. At detail1/2,
ambient fingers may be omitted; authoritative actions keep their current per-call poses.
Windup/strike/grab/throw/lunge/bite/taser never become throttled through this flag. Changed
action/serial/contact/death/hurt/coat/grounded state and far-to-near return update immediately.
Current supplied phase is used directly on the next pose; no queued clip can replay old phases.

Cache the last applied local bone Transform3D per instance and omit an engine setter only when
the target is exactly equal, with no epsilon or pose quantization. Reset restores the same base
pose through that cache. Tony layer visibility is written on coat-count changes only. Track
presentation-only bone/visibility write counters for tests; they never feed gameplay. Checks
compare actual near geometry against an unthrottled instance at the same current time/phase,
force real actions and state transitions between distant pose slots, and verify unchanged
inert poses issue no redundant bone writes. A four-microradian still-head gaze test rejects
epsilon comparisons, and zero coats/reset/zero coats rejects stale visibility caches. Counters
reset for each explicit reset operation and count only engine writes made during/after it.
Profile native results before claiming frame savings.

### P04c exact caches and conservative hidden ambient scheduling (2026-11-18)

Approved scope preserves every authored mesh/material/skin, source snapshot, AI tick and RNG
draw. `ActorAnimation.tick(art, delta, snapshot, detail=0, pose_needed=true)` keeps the existing
callers unchanged. A false final argument may skip only an unchanged idle/ambient pose without
hurt/death. Clocks, gait integration, child snapshots and coats still consume every call;
accepted actions and state transitions retain their existing immediate updates. Returning to
`pose_needed=true` forces the current pose before the old distant schedule can skip it. Reset
clears this deferred state. No hidden clip queues, replayed events or autonomous gameplay timers.

Per-instance working global-pose caches retain the original child-to-parent multiplication
order exactly. Local writes invalidate that bone and its descendants; full pose reset invalidates
all entries. The uncached reference path remains available through the diagnostic-only rig
flag `pose_cache_enabled=false`. Attachment globals use the real Skeleton query, once per
distinct binding bone after a changed applied pose. Every binding still checks its current
node transform: death-released props must restore their binding before each current release
interpolation. Setters are omitted only on exact equality, never an epsilon. Presentation
counters (`global_pose_queries`, `global_pose_solves`, `attachment_queries`, `attachment_writes`,
`hidden_pose_skips`) are observational only and reset with the rig.

`presentation_visibility.gd` exposes `frame_context(camera, sun, min_receiver_y=-INF, sole_shadow_light=false)` and
`needs_pose(art, context)`. The caller computes one context per render. Missing/nonfinite
camera, light or rig bounds fails open. Missing receiver-floor data also fails open unless
the floor-free proof below certifies the entire infinite shadow extrusion. The conservative radius is
derived from bone-chain reach, full mesh bounds, rigid attachment transforms, released-prop
targets and nested independent rigs, including mounts and furniture. Its translation envelope
covers current root death/sleep, pelvis gait and mouth offsets; new translation animation must
extend that envelope. Scale and shear are bounded; it never uses an actor-center-only test.

An actor touching the camera frustum or the light's shadow-distance region always receives a
pose. Outside both, a directional-light sweep of the whole actor sphere continues to the
caller-certified lowest receiving surface. Only separation of that entire capsule from a
frustum plane permits hidden scheduling. This retains offscreen casters whose shadows enter
view. Horizontal/upward or unknown light/floor data fails open. This helper does not change
mesh visibility, renderer culling, collisions, shadow policy or actor existence. Root owns
FullScene wiring and a separately measured world-only shadow trial.

Tests compare actual weighted/attached geometry against uncached actors for all72 templates;
exercise hidden-return, active actions, hurt/death, coats, reset and nested child clocks; and
test frustum-edge, scale/shear, unknown bounds and offscreen-shadow counterexamples. Keep
original initial-collision probe audits and both scene/whole-engine16ms thresholds. Model
checks establish correctness only; report runtime gains only after central native measurement.

#### P04d floor-free shadow separation (2026-11-18)

Captured before implementation, approved to target the measured6.243ms pose/model scope.
The caller must certify that the supplied sun is the only current shadow-casting light by
passing `sole_shadow_light=true`. False/missing/invalid certification fails open even if the
sun itself has shadows disabled. Current source fixtures and future cosmetic beacons must
have `shadow_enabled=false`; a new shadow light revokes eligibility until incorporated into
the proof. Root owns the actual light-policy check and FullScene binding. This packet does
not change light/shadow settings, draw counts, actor/node visibility or model simulation.

Retain the existing visible-sphere and near-shadow-distance guards. For a finite direction
and an outward frustum plane with normal n, let the whole caster sphere have center c and
radius r. If `plane.distance_to(c) > r*length(n)` and `dot(n,direction) >= 0`, every point of
the sphere, extruded by any nonnegative distance along the sun ray, stays outside that same
plane. Such a caster cannot cast a shadow into the view at any receiver height. The radius
already bounds every current/future authored pose, attachment, death prop and nested rig;
unknown bounds remain ineligible. No guessed floor or sampled pose is used as a certificate.

Only this common-plane proof may bypass an unknown receiver floor. A ray entering a plane,
touching sphere, ambiguous direction, missing light certificate or invalid data still receives
its pose. The finite certified-floor capsule proof remains available as before. Root passes
only the boolean result to the existing fifth `ActorAnimation.tick` argument; every AI,
physics, RNG and model tick remains unchanged. Existing72-template hidden-return/current
action/death/hurt/coats/reset/nested-clock tests stay mandatory. Focused added cases retain
offscreen casters whose shadows enter view, reject only outward/parallel infinite rays,
exercise current real Camera3D planes and distinguish an additional shadow light from a
sun with shadows disabled. Release profiling is required before reporting savings.

## Prop contact refinement — P05b visual review

The guitar, laundry basket and equation board follow the chest through cached attachments.
During their supported idle/identity actions, an analytic two-bone cosmetic arm solve places
wrists against authored prop-space contact points. It preserves anatomical segment lengths,
uses an outward/downward elbow pole, clamps unreachable targets, and changes only the current
per-instance bone poses. Bone parents and prop bindings are cached at construction. No physics,
gameplay contact, action timing or new authority enters the helper. Combat and death supersede
these holding poses. Strumming/writing strokes use only the supplied action phase.
On collapse, a released rigid prop may interpolate to an explicitly authored actor-local
resting transform. Laundry Lady's basket settles upright beside her body, using the supplied
death phase; this is visual release only, with no spawned object, pickup, physics or timer.
Reset and every live pose restore the original cached attachment binding.

The basket remains upright; both hands support its rim. The guitar stays across the chest with
one hand at the neck and the other over the strings. The pencil tip meets the tilted board.
Tests inspect actual posed finger/prop vertices at several phases, plus immutable actor origins
and bounded geometry. Native targeted captures cover these contacts and the closed authored
cloth roofs on hooded heads. Passing matrices alone does not establish visual acceptance.

## P05b3 site residents — approved construction contract

The remaining eight registry rows are source site records, not NPC/sprite records. Add
`Roster.visual_for_site(kind: StringName, site_record: Dictionary) -> StringName`, accepting
only `copper`/`breakin` plus the exact source `id` and lowercase `who` below. Unknown kinds,
missing/non-string fields, mismatched identities and cross-table records return empty. Keep
`visual_for_actor` strict and unchanged; do not manufacture actor IDs, sprites or spawn flags.
The authored implementation lives in `site_cast_profiles.gd`, using the existing shared cache,
anatomical builders and pose API. Site placement/transactions remain the production binder's job.

| Kind / source ID | Exact source who | Visual ID / signature |
|---|---|---|
| copper / cold_not | dennis (nights) | dennis; night-watch uniform, empty thermos held in both hands |
| copper / water_dept | the raccoon quorum | raccoon_quorum; seven raccoons on a filing cabinet, evidence can |
| copper / rust_car | transit authority dan | transit_dan; peeling badge, transfer slips and ticket punch |
| breakin / model_home | the model family | model_family; father, mother and son at plastic dinner, empty fourth chair |
| breakin / spoil_bank | the former teller | former_teller; banking vest, stamp, papers and shoe drawer |
| breakin / sod_office | the goose (manager) | goose_manager; two-foot long-neck goose on a desk |
| breakin / drained_pool | the lifeguard (still certified) | lifeguard; elevated chair, whistle and score card6 |
| breakin / visitor_center | the docent (self-guided) | docent; brochure, visitor badge and wide presenting gesture |

Delivery is bounded in two checkpoints: five human residents first (six templates including the
seated lifeguard helper), then the quorum, model family and goose assemblies (eight templates
including their anatomical helpers). The final roster is expected to expose72 templates for63
canonical rows; helpers are never extra registry identities. During a checkpoint, advertise only
implemented templates. Raccoon count is seven; four is the vote/quorum count. The model family
has three distinct figures: eyeless father, mother and son holding a toast. These figures preserve
their rigid authored poses under all snapshots, including movement/death; no breathing/blinking.
The source does not provide a nighttime spawn flag for Dennis, nor autonomous resident AI.

Assemblies own immobile furniture roots and independently cached child rigs. Child authored
position/yaw and stable instance names distinguish seven raccoons or the seated family. An
assembly consumes snapshots/time without applying a human fall to furniture. The goose uses
two real leg chains and an articulated long neck, never the Pigeon King's missing-foot anatomy.
Resident actions reuse read/write/serve/inspect/talk/seated where appropriate; additive wave,
salute, stamp, vote and score poses use only supplied normalized phase. They cannot transact,
spawn resources, damage, queue a gameplay delay or own a resident timer.

Checks cover actual exported site records, rejected wrong kind/id/who and unchanged actor
resolution; all cached meshes/skins, finite weighted geometry and independent child poses;
actual seven/three/two-leg composition; rigid family stillness; seated support and physical hand
contacts. Native evidence must show near/far silhouettes and signature actions for all eight.
Full-scene placement and interaction parity remain parent-owned, separate from this art gate.

The parent subsequently approved integrating both B3 checkpoints together after the1586-check
58-template contact pass and native review. All14 B3 templates are now implemented and exposed,
for72 total templates and all63 canonical rows; engine/visual acceptance is pending. Small authored
animal paw/toe/tail sections opt out of redundant constructor subdivision, keeping the seven-member
group bounded. This changes no simulation rate, animation authority or per-frame traversal.
Per-profile skin colors participate in anatomical finger binding; arbitrary new skin tones do not
silently route fingertips to forearm bones. Assembly children have cached names/yaw/anchors and
independent poses. Static furniture remains fixed while child clocks consume the same snapshot.

## Geometry and rig

Use Godot 4.5.1 native Skeleton3D/Skin with at most four weights per vertex. Human target is
26 bones: pelvis/spine/chest/neck/head, shoulders/elbows/wrists, hips/knees/ankles, plus grouped
finger and thumb chains. Bone count may differ by family and must be reported, not assumed.
Coherent sleeves/trousers include intermediate rings at joints and smooth blends, avoiding
separate hinge tubes. UVs on deforming surfaces keep texture attached to cloth. Rigid authored
faces/props may use bone-following Node3D attachments and their existing local texture mapping.
No external models, bitmap stock, shader runtime dependency or per-frame mesh generation.

Preserve/refine the existing six faces and silhouette differences. Tony keeps three genuine
layered coats at rest and never blinks; his 0-coat state exposes the source bare torso, without
changing combat. Pete remains short/wide, gains source apron and holds/eats a hot pocket.
Yuri retains square beard/angry face, restores source bald crown and hubcap work prop.
Lurch retains long limbs, narrow shoulders and asymmetry. Brutus remains old with cloudy eye;
possum keeps the helmet, pointed face and thin tail. Quadruped animation uses its own anatomy.

Merge compatible weighted body geometry by material at construction; retain separate removable
coat layers and animated attachments. Cache bones/bindings and resource templates once.
The actor/art root transform never moves: hips/death presentation happens beneath it.
Stable root-level head/left_arm/right_arm/left_leg/right_leg markers are inspection adapters,
not a second animation authority. Additional skeleton bone names and grip markers are documented.

Detail0 updates all cosmetics. Detail1 suppresses finger/secondary motion; detail2 reduces distant
cosmetic posing. Every call still consumes current authoritative state; action/death/coat changes
apply immediately, even on reduced detail, and returning near cannot replay stale poses.
The director remains responsible for simulation and visibility; art detail never suspends AI.
Distance-driven gait uses actual motion and identity stride, not a source-specific speed cap.

## Gates and visual acceptance

Test all six supported IDs; unknown ID rejection; finite/rest bounds; material/mesh/skin cache
reuse; independent simultaneous instances; no body/timer/audio ownership. Report per-identity
mesh, surface, triangle, bone and maximum-weight counts. Every influenced vertex has valid bone
indices, finite nonnegative weights summing to one, max four weights, finite vertices/normals/UVs.
Verify elbow/knee deformation, grounded foot envelope, reset, action supersession, low-detail
state freshness, zero movement settling, malformed input bounds and immutable actor origin.
Tony coat visibility must distinguish all four counts and his eyes must remain unchanged.

Parent imports and runs gates centrally. Inspect rest, front/profile locomotion, strikes/grabs,
Pete bite, Yuri inspect and all coat states at ~2m and ~20m. Render actual posed geometry;
headless matrices alone cannot catch cuff/cloth occlusion. Profile 60 actual AI in the production
scene later, separately from repeated art stress. No performance promise based on bone count.

Native API references: [Skeleton3D](https://docs.godotengine.org/en/4.5/classes/class_skeleton3d.html),
[Skin](https://docs.godotengine.org/en/4.5/classes/class_skin.html),
[Mesh](https://docs.godotengine.org/en/4.5/classes/class_mesh.html),
[MeshInstance3D](https://docs.godotengine.org/en/4.5/classes/class_meshinstance3d.html).
The choice of four weights and these art budgets is this project's decision.

## P05b amendment — full canonical visual families

Approved before generation after P05a foundation. Additional owned file:
`game3d/scripts/cast_profiles.gd`. Existing roster/animation/test/probe files remain with this
worker; root still owns production integration and all engine runs. Preserve the P05a public API.

Add `Roster.visual_for_actor(source_actor: Dictionary) -> StringName`. This adapter uses known
canonical names, exported alias mappings and the declared generated pretender family together
with allowed source sprite fields. Unknown names/sprite combinations return an empty ID.
Runtime IDs are retained by the director, not rewritten into visual IDs. Explicit mismatches
such as `laundromat_lady`/`launderlady`, `meter_maid`/`metermaid`, `food_truck`/`foodtruck` and
`priests_son`/`priestson` are tested. Knight Emeritus may use any of the three canonical guard
uniforms. No guessed actor-ID stripping or generic-human fallback is permitted.

`cast_profiles.gd` owns immutable authored shape, face, hair, garment, palette, prop and source
mapping records plus their construction helpers. Its definitions return copies. Constructor
caches are per visual/profile, while poses and state remain per instance. Reuse anatomy and
materials, but give each source signature its actual silhouette/prop; changing a shirt color
alone is insufficient. Existing six heads/rigs remain compatible.

Deliver in three explicit review subpackets, holding for central gates/render review between them:

1. **P05b1:** all41 base actor instances and15 initial kingdom-guard instances. These cover38
   base canonical names plus4 guard names, not56 unique identities. Three skid aliases reuse
   their source bodies; Knight Emeritus uses the source uniform variants. New special families
   include scrap dog, Paisley companion, one-foot unblinking pigeon, horse/rider and flat pothole.
2. **P05b2:** thirteen police/conditional/ruler identities: COP, Brendan, Price Guy, Old School
   Brutus, Your Possum, Bus Driver, Brutus the Older, Someone You Don't Know, generated Pretender,
   and the four rulers. Preserve source alias sprites and state fields explicitly while giving
   named roles their authored silhouettes. No AI or boss mechanics are created by this art.
3. **P05b3:** eight site-only residents: Dennis, Raccoon Quorum, Transit Authority Dan, Model
   Family, Former Teller, Goose Manager, Lifeguard and Docent. Groups/animals get real geometry;
   still residents do not acquire patrol behavior. These have no independent source sprite base.

The actor snapshot may select the added sleep/read/write/phone/strum/fold/serve/radio/taser/seated
presentation actions. Dave's source `asleep` state maps to sleep; `isOmalleyFallen` or
`id == omalley_fallen` maps to the fallen priest visual; Tony `coatsOff` maps to existing
`coat_count = clamp(3-coatsOff,0,3)`. These adaptations belong in the director/source adapter,
not an autonomous pose timer. Unsupported actions remain detectable in per-profile capabilities.
No added gesture commits resources, fires a projectile, spawns an actor or changes an authority
timer. Animal/mounted/object families use their own bones/part controllers, not human limbs.
Companion anchoring distinguishes a rider following its horse's chest from Paisley staying at
the owner's unchanged actor origin. Each child collapses at most once; a human's visual fall
cannot also rotate a ground companion. Long-tool carriers use an authored collapse arm pose
so their cane/cart fork remains beside the body instead of piercing the ground.

Coverage must exercise actual exported base/day1 records, all canonical name mappings, allowed
variants and rejected malformed/unknown combinations. Tests inspect anatomical families,
unique proportions and named signature/prop geometry, resource reuse, independent poses,
state freshness, skin integrity and bounds. Native evidence includes near/far silhouettes,
family-specific actions and group composition. Registry rows become art-ready only after their
construction/tests/visual review; that status does not establish interaction or full-port parity.

### P05b2 construction contract

After the B1 central1165-check pass (native review pending), B2 implements the next13 canonical
rows. It adds14 templates: nine human bodies (`cop`, `brendan`, `price_guy`, `bus_driver`,
`day3_visitor`, and four rulers), two larger rust dog variants (`os_brutus`, `brutus_older`), and
three `pretender_*` uniform variants. YOUR POSSUM intentionally shares the original helmet
possum's anatomy. The complete B2 roster will therefore have58 templates, representing55
canonical rows; the eight site-only residents remain unimplemented until B3.

Mappings remain exact name plus allowed source sprite. THE BUS DRIVER and SOMEONE YOU DON'T
KNOW both arrive with sprite `lurch`, but receive distinct named uniforms/faces. BRUTUS THE
OLDER arrives with sprite `brutus` and source scale1.5; the authored larger variant incorporates
that scale, so a binding must not multiply it again. Passive/hostile and boss flags do not
select a different body. YOUR POSSUM uses sprite `possum`; the freed follower keeps THE DOG /
`scrap_dog`. Generated cop/Brendan/Sherri IDs do not need stripping or guessing: their exact
canonical names and sprite fields select the same profiles as any other instance.

Pretender names must match the exported generated-family regular expression, with a positive
integer and one of the three actual guard sprites. Their numbered actor IDs stay director-owned.
The variants retain the corresponding tarp/receipt/wire clothing plus a petition and an
unconvincing paper crown. They do not add a fourth guard family or a generic unknown fallback.

Police get distinct broad-gut versus thin-rookie bodies, caps, badges, carried radio/coffee/baton
or flashlight/taser props. Price Guy stays a motionless brim/long-black-coat silhouette with a
price tag. Bus Driver has a transit uniform and ticket roll; the day-3 stranger is a narrow,
unhurried dark coat. Darryl's oversized tarp remains the silhouette; General Receipt has paper
crown/epaulettes/long sash; Bishop Wire has antenna mitre/coils/crozier; the emperor has layered
coats, stacked-curb crown, broken ruler and actual folding-chair geometry.

Radio and taser poses acknowledge current authoritative actions; they never fire or queue an
effect. Intentional stillness suppresses cosmetic breath/gaze when stationary but never stalls
simulation or discards an explicit current action. B1 probe membership stays fixed; `--packet=b2`
captures only these new templates with near/far/action views and special collapse views where
props need them. Mapping tests cover source aliases, generated family positives/negatives,
boss/passive Older variants, independent caches, joint geometry and finite bounds.

## Canonical identity ledger

All 63 VIBE registry rows are accounted for below. Six have passed P05a;36 more rows have the
B1 central1165-check/native188-view evidence;13 B2 rows await central gates/render review;
eight site-only rows remain planned. Runtime aliases/state
bases and the Model Family/Quorum member counts do not
create additional registry identities. Planned means not implemented, not a generic substitute.

| Canonical identity | Family | P05 status |
|---|---|---|
| TRE BAG TONY | human | P05a accepted: `tony` |
| YURI | human | P05a accepted: `yuri` |
| BRUTUS | quadruped | P05a accepted: `brutus` |
| PAWN SHOP PETE | human | P05a accepted: `pete` |
| LURCH | human | P05a accepted: `lurch` |
| SPIDER-BITE SHERRI | human | P05b1 art accepted — central1165/native188 |
| PAULIE THE FACE | human | P05b1 art accepted — central1165/native188 |
| BAGGIE BARB | human | P05b1 art accepted — central1165/native188 |
| CHATTY DAVE | human | P05b1 art accepted — central1165/native188 |
| WHOLE FOODS MOM | human | P05b1 art accepted — central1165/native188 |
| THE POSSUM | quadruped | P05a accepted: `possum` |
| FATHER O'MALLEY | human | P05b1 art accepted — central1165/native188 |
| THE CONDUCTOR | human | P05b1 art accepted — central1165/native188 |
| LOUD LARRY | human | P05b1 art accepted — central1165/native188 |
| STRIPE | human | P05b1 art accepted — central1165/native188 |
| THE PIGEON KING | bird | P05b1 art accepted — central1165/native188 |
| PINKY POLENTA | human | P05b1 art accepted — central1165/native188 |
| THE MATHEMATICIAN | human | P05b1 art accepted — central1165/native188 |
| COUSIN BRENDAN | human | P05b2 art accepted — central1586/native review |
| THE TRAIN HOPPER | human | P05b1 art accepted — central1165/native188 |
| PARK BENCH PHILOSOPHER | human | P05b1 art accepted — central1165/native188 |
| THE PRICE GUY | human | P05b2 art accepted — central1586/native review |
| OLD SCHOOL BRUTUS | quadruped | P05b2 art accepted — central1586/native review |
| THE LEASING GUY | human | P05b1 art accepted — central1165/native188 |
| GUTTER GREG | human | P05b1 art accepted — central1165/native188 |
| THE DOG | quadruped | P05b1 art accepted — central1165/native188 |
| THE BIG GUY | human | P05b1 art accepted — central1165/native188 |
| CUBSCOUT | human | P05b1 art accepted — central1165/native188 |
| JOGGER | human | P05b1 art accepted — central1165/native188 |
| DOG WALKER (PAISLEY) | human + dog | P05b1 art accepted — central1165/native188 |
| BUSKER | human | P05b1 art accepted — central1165/native188 |
| HORSE COP | mounted human/horse | P05b1 art accepted — central1165/native188 |
| THE VAPE LORD | human | P05b1 art accepted — central1165/native188 |
| A POTHOLE (TALKING) | road object | P05b1 art accepted — central1165/native188 |
| MAYOR'S COUSIN | human | P05b1 art accepted — central1165/native188 |
| THE PHONE GUY | human | P05b1 art accepted — central1165/native188 |
| LAUNDROMAT LADY | human | P05b1 art accepted — central1165/native188 |
| METER MAID | human | P05b1 art accepted — central1165/native188 |
| FOOD TRUCK GUY | human | P05b1 art accepted — central1165/native188 |
| THE PRIEST'S SON | human | P05b1 art accepted — central1165/native188 |
| KARAOKE MIKE | human | P05b1 art accepted — central1165/native188 |
| YOUR POSSUM | quadruped | P05b2 art accepted — central1586/native review |
| THE BUS DRIVER | human | P05b2 art accepted — central1586/native review |
| BRUTUS THE OLDER | quadruped | P05b2 art accepted — central1586/native review |
| SOMEONE YOU DON'T KNOW | human | P05b2 art accepted — central1586/native review |
| COP | human | P05b2 art accepted — central1586/native review |
| DARRYL UNDER BLUE | human | P05b2 art accepted — central1586/native review |
| GENERAL RECEIPT | human | P05b2 art accepted — central1586/native review |
| BISHOP WIRE | human | P05b2 art accepted — central1586/native review |
| THE CURB EMPEROR | human | P05b2 art accepted — central1586/native review |
| TARP KNIGHT | human | P05b1 art accepted — central1165/native188 |
| CART LANCER | human | P05b1 art accepted — central1165/native188 |
| WIRE DEACON | human | P05b1 art accepted — central1165/native188 |
| KNIGHT EMERITUS | human | P05b1 art accepted — central1165/native188 |
| CURB PRETENDER No. N | human | P05b2 art accepted — central1586/native review |
| DENNIS (NIGHTS) | human | P05b3 central1898/native85; eye review passed |
| THE RACCOON QUORUM | seven quadrupeds / furniture | P05b3 central1898/native85; eye review passed, front row occludes rear heads |
| TRANSIT AUTHORITY DAN | human | P05b3 central1898/native85; eye review passed |
| THE MODEL FAMILY | three still humans / furniture | P05b3 central1898/native85; eye review passed |
| THE FORMER TELLER | human | P05b3 central1898/native85; eye review passed |
| THE GOOSE (MANAGER) | two-foot bird / desk | P05b3 central1898/native85; eye review passed |
| THE LIFEGUARD (STILL CERTIFIED) | seated human / elevated chair | P05b3 central1898/native85; eye review passed |
| THE DOCENT (SELF-GUIDED) | human | P05b3 central1898/native85; eye review passed |
#### P04e — near offscreen casters with a complete separation proof

Captured before code after the c61d9c9 release measurement (model projection p95
7.055/7.151 ms). The P04d infinite-extrusion proof is independent of distance to the
camera: if the entire caster sphere and every nonnegative ray extrusion stay beyond
one outward frustum plane, neither body nor its directional shadow can enter the view.
Therefore this complete proof may run before the old near-shadow-distance guard.
The guard remains for all cases without this proof, including the finite-floor fallback.
Visible/touching spheres, incoming shadow directions, invalid bounds/light policy and
additional shadow lights still update. All source AI, clocks, pose time, transitions,
death/hurt, coats and immediate visible return remain unchanged. This supersedes only
P04d's blanket near-distance exclusion; no render setting or actor visibility changes.

FullScene also omits identical root position/yaw and visibility setters, comparing
current values rather than assuming prior state. Changed transforms still publish in
the same frame. This is exact output equality, with no epsilon or quantization.
P14f's weighted collar markers are non-rendering leaf `Node3D` children. Visibility
bounds recognize only declared weighted markers that remain direct, finite, non-top-level
leaf nodes; a changed type/parent/child graph fails open even after the radius cache exists.
Their coordinates add no renderable geometry. The external chain presenter must force the
original live dog's pose while bound, because the chain can cross the view independently
of its actor sphere, just as a moving beacon can illuminate a visible receiver.

#### P04f — exact per-bone authored-pose input memo

Captured before implementation, after the world-details checkpoint332be27. Each actor
instance may retain one last `_pose` input/output tuple per bone: the actual current
`base_poses[index]` Transform3D, Euler angles, translation offset and computed local target.
Only exact equality of all three inputs permits reuse. A miss evaluates the original
expression unchanged: `Transform3D(rest.basis*Basis.from_euler(angles),rest.origin+offset)`.
No reassociation, approximate comparison, rounded key, identity shortcut or angle threshold.
Changing only base-pose origin or basis must miss, even if skeletal rest data is unchanged.

Every hit still calls `_set_local_pose`. An earlier overlay, contact IK or working-pose reset
may have replaced that bone, so an input hit must restore the authored target and invalidate
any populated descendant global cache exactly as a fresh calculation would. Reset may keep
these value-only tuples while restoring poses and clearing observational counters; it never
assumes the memo's target is currently applied. Independent instances/companion rigs own
independent tuples. No mesh, material, skin, root, clock, culling, scheduling or action change.

The diagnostic-only `pose_input_cache_enabled=false` isolates this memo from existing global
and attachment caching. The existing `pose_cache_enabled=false` also bypasses the new memo,
retaining a complete uncached reference. `pose_input_hits` and `pose_input_solves` count only
reused/computed targets and reset with the rig; they cannot drive gameplay or pose scheduling.
Storage is bounded by authored bone count and reused without per-miss tuple allocation.

Focused tests compare cache-on/off real Skeleton poses, rigid and weighted attachments and
actual four-weight mesh vertices across all original templates, actions, overlays, detail
and hidden-return transitions. Direct counterexamples cover repeated same-bone writes,
four-microradian angles/offsets, warmed targets after reset, changed base/rest data, populated
descendant caches after overlays/IK and disabling/re-enabling a warm memo. Mesh/skin/material
resources and caller snapshots remain unchanged. Reduced Euler solves establish work avoided,
not frame-time acceptance; Root owns central gates and frozen-release measurement.
