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
| contact | bool false | Existing resolved contact; no new hit/projectile callbacks |
| hurt | float 0 | Authoritative 0..1 recoil envelope |
| dead | bool false | Authoritative death state, overrides idle/action |
| death_phase | float 1 | Authoritative 0..1 collapse progress; no animation-owned death timer |
| coat_count | int 3 | Tony's exact visible layers 3/2/1/0; pure presentation |
| gaze | Vector2.ZERO | Optional bounded head yaw/pitch radians |

Malformed/nonfinite inputs normalize safely without modifying the snapshot. Invalid or nonpositive
delta does not advance any presentation. Positive stalled frames cap cosmetic integration.
Known values are bounded. Unknown actions return to the base locomotion/idle pose; capability
lists expose the implemented vocabulary so production integration can detect unsupported intent.

P05a humans expose idle/talk/eat/inspect/windup/strike/grab/throw and hurt/death overlays.
Quadrupeds expose idle/windup/lunge/bite and hurt/death overlays. `strike` begins at extension
and recovers, matching already-resolved immediate combat; windup is a separate simulation phase.
No clip events. Reset restores all bones/props/coat defaults and deterministic seeded idle phase.

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

Coverage must exercise actual exported base/day1 records, all canonical name mappings, allowed
variants and rejected malformed/unknown combinations. Tests inspect anatomical families,
unique proportions and named signature/prop geometry, resource reuse, independent poses,
state freshness, skin integrity and bounds. Native evidence includes near/far silhouettes,
family-specific actions and group composition. Registry rows become art-ready only after their
construction/tests/visual review; that status does not establish interaction or full-port parity.

## Canonical identity ledger

All 63 VIBE registry rows are accounted for below. Six are in this implementation checkpoint;
57 remain planned. Runtime aliases/state bases and the Model Family/Quorum member counts do not
create additional registry identities. Planned means not implemented, not a generic substitute.

| Canonical identity | Family | P05 status |
|---|---|---|
| TRE BAG TONY | human | P05a implementing: `tony` |
| YURI | human | P05a implementing: `yuri` |
| BRUTUS | quadruped | P05a implementing: `brutus` |
| PAWN SHOP PETE | human | P05a implementing: `pete` |
| LURCH | human | P05a implementing: `lurch` |
| SPIDER-BITE SHERRI | human | P05b1 specified — unimplemented |
| PAULIE THE FACE | human | P05b1 specified — unimplemented |
| BAGGIE BARB | human | P05b1 specified — unimplemented |
| CHATTY DAVE | human | P05b1 specified — unimplemented |
| WHOLE FOODS MOM | human | P05b1 specified — unimplemented |
| THE POSSUM | quadruped | P05a implementing: `possum` |
| FATHER O'MALLEY | human | P05b1 specified — unimplemented |
| THE CONDUCTOR | human | P05b1 specified — unimplemented |
| LOUD LARRY | human | P05b1 specified — unimplemented |
| STRIPE | human | P05b1 specified — unimplemented |
| THE PIGEON KING | bird | P05b1 specified — unimplemented |
| PINKY POLENTA | human | P05b1 specified — unimplemented |
| THE MATHEMATICIAN | human | P05b1 specified — unimplemented |
| COUSIN BRENDAN | human | later packet — unimplemented |
| THE TRAIN HOPPER | human | P05b1 specified — unimplemented |
| PARK BENCH PHILOSOPHER | human | P05b1 specified — unimplemented |
| THE PRICE GUY | human | later packet — unimplemented |
| OLD SCHOOL BRUTUS | quadruped | later packet — unimplemented |
| THE LEASING GUY | human | P05b1 specified — unimplemented |
| GUTTER GREG | human | P05b1 specified — unimplemented |
| THE DOG | quadruped | P05b1 specified — unimplemented |
| THE BIG GUY | human | P05b1 specified — unimplemented |
| CUBSCOUT | human | P05b1 specified — unimplemented |
| JOGGER | human | P05b1 specified — unimplemented |
| DOG WALKER (PAISLEY) | human + dog | P05b1 specified — unimplemented |
| BUSKER | human | P05b1 specified — unimplemented |
| HORSE COP | mounted human/horse | P05b1 specified — unimplemented |
| THE VAPE LORD | human | P05b1 specified — unimplemented |
| A POTHOLE (TALKING) | road object | P05b1 specified — unimplemented |
| MAYOR'S COUSIN | human | P05b1 specified — unimplemented |
| THE PHONE GUY | human | P05b1 specified — unimplemented |
| LAUNDROMAT LADY | human | P05b1 specified — unimplemented |
| METER MAID | human | P05b1 specified — unimplemented |
| FOOD TRUCK GUY | human | P05b1 specified — unimplemented |
| THE PRIEST'S SON | human | P05b1 specified — unimplemented |
| KARAOKE MIKE | human | P05b1 specified — unimplemented |
| YOUR POSSUM | quadruped | later packet — unimplemented |
| THE BUS DRIVER | human | later packet — unimplemented |
| BRUTUS THE OLDER | quadruped | later packet — unimplemented |
| SOMEONE YOU DON'T KNOW | human | later packet — unimplemented |
| COP | human | later packet — unimplemented |
| DARRYL UNDER BLUE | human | later packet — unimplemented |
| GENERAL RECEIPT | human | later packet — unimplemented |
| BISHOP WIRE | human | later packet — unimplemented |
| THE CURB EMPEROR | human | later packet — unimplemented |
| TARP KNIGHT | human | P05b1 specified — unimplemented |
| CART LANCER | human | P05b1 specified — unimplemented |
| WIRE DEACON | human | P05b1 specified — unimplemented |
| KNIGHT EMERITUS | human | P05b1 specified — unimplemented |
| CURB PRETENDER No. N | human | later packet — unimplemented |
| DENNIS (NIGHTS) | human | later packet — unimplemented |
| THE RACCOON QUORUM | quadruped | later packet — unimplemented |
| TRANSIT AUTHORITY DAN | human | later packet — unimplemented |
| THE MODEL FAMILY | still human group | later packet — unimplemented |
| THE FORMER TELLER | human | later packet — unimplemented |
| THE GOOSE (MANAGER) | bird | later packet — unimplemented |
| THE LIFEGUARD (STILL CERTIFIED) | human | later packet — unimplemented |
| THE DOCENT (SELF-GUIDED) | human | later packet — unimplemented |
