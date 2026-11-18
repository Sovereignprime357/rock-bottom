# SPEC — Boss transactions and remaining combat pattern P07b

Captured before code, 2026-11-18. Scope/API approved; model implementation follows the pushed
P07a checkpoint 74986ce. This is subordinate to SPEC-3D-FULL-PORT.md and SPEC-3D-COMBAT.md.
The source oracle covers 39 cases and three separate defect characterizations. Central model
validation passed 2200 checks; runtime composition remains in progress. No completed native/Web boss fight tour
or 90-second playability claim follows from the model implementation.

Sources: combat.js spawnBoss/onNpcDeath; neighborhood_b.js spawnCoopBoss,
triggerFallenPriestTransform; activities.js spawnBrutusOlder; vendors_places.js
spawnOldSchoolBrutus; npc_ai.js priest_fallen; update.js Tony/Older phase machines and Fallen
survival timer; campaigns.js completeKingdomBoss/completeKingdomPretender and ending receipts.

## Ownership and APIs

New files: game3d/scripts/boss_system.gd, game3d/tests/test_bosses.gd,
tools/3d-boss-oracle.mjs and game3d/tests/fixtures/boss_reference.json. Extend only existing
owned combat/director code after its checkpoint; no main, scene, art, GameState or runtime edits.

RockBottomBosses.new(owner, combat, campaign_adapter=null) holds weak owner/combat/campaign
references. GameState remains the sole p/s/npcs/cash-piles/RNG authority. Combat stages actor
HP and owns player hurt/death/arrest. Bosses never duplicates HP, invulnerability, player timers,
movement/collision, RNG or save storage. Root Runtime is the composite domain facade and forwards
atomic death, robbery and boss requests. The robbery subsystem remains a separate dependency;
P07b does not silently treat the skid grabber as an ordinary grabber.

Public API:

* can_start_tony()->bool; start_tony()->bool; start_coop()->bool.
* spawn_brutus_older()->bool; transform_fallen_priest()->bool;
  spawn_old_school_brutus()->bool.
* tick_before_actors(dt_ms)->bool: Fallen survival clock, once per active step.
* tick_after_actors(dt_ms,wall_ms)->bool: Tony/Older phase transitions, once after actor decisions
  and projectile contact, before rank progression. Existing active step bound0<dt<=50ms applies.
* tick_wall(wall_ms)->bool: due sound/ending presentation, including modal/paused time. Monotonic
  finite wall time; new p/s identity discards callbacks. No elapsed callback may pay rewards.
* can_handle_death(detached_actor)->bool: pure capability and quest-state preflight.
  handle_death(actor_id)->bool: synchronous atomic domain completion, given staged lethal HP.
  False changes nothing; true marks dead or removes the actor and cannot pay twice.
* normalize_state()->bool: call once after GameState fresh/restore and before actors run or scene
  models are bound. Clears session queues on new p/s identity, reconciles Fallen identity silently,
  preserves all durable flags/quests/rewards, and reports failed placement. Repeated calls on the
  same state are idempotent; they never heal a live encounter, reset phase or replay a receipt.

Runtime invokes normalize_state explicitly after successful fresh/restore. The constructor may
call it for initial data. Normalization is not a second save decoder. It does not restore high,
combat countdowns or active boss battles that the core deliberately resets.

All start methods preflight required actor identity and pure placement on detached records before
mutating p/s or appending actors. Missing actors, already-active guards and failed placement
return false without spending money/offenses or partially opening a fight. Existing vendor
ActionSession performs live spatial/rank/payment guards; Bosses adds no invented price/rank gate.
Tony/coop preserve the source bossActive gate; Older activity alone does not block Tony. Coop
uses optional Stripe if present and does not create a substitute ally. Fallen requires living
priest and no omalleyFallen flag. Old School refuses ANY existing os_brutus, including a corpse.
Older refuses an active/live Older and replaces only a previous dead Older record on a fresh
summon, resetting encounter phase1 as explicitly approved below.

## Patterns and phase boundaries

Tony start mutates the existing actor to200HP,1.8speed,12damage,hostile+aggro,coatsOff1,
bossActive/bossKind/phase1/bossNPC. Coop sets coopMode, makes existing Stripe a100HP/1.4speed
ally targeting Tony, and uses collision-validated placement near player+32px. No source
invariant is replaced by an animation. Changing rig poses cannot advance or damage a boss.

Tony strictly below66% enters phase2: charger, reset charge scratch, speed2.4, exactly two
45HP/2speed/5damage Sherris at±80px, with real clear placement and unique transient IDs.
Strictly below33% enters phase3: charger berserk, reset charge scratch, speed3,damage16,
coatsOff3. The sequential source tests allow a single large hit to skip phase2 AND its adds;
preserve that behavior. Phase3's immediate roar stack and delayed200/420ms roars are presentation.
Threshold equality does not advance a phase.

Older starts200HP,2.4speed,14damage,48x36px; position player+100px on both axes, source-clamped
then physicality-cleared. Loved street starts passive and not hostile; that passive archetype
continues the shipped default chase behavior if subsequently provoked, rather than silently
becoming charger_older. Other Older starts charger_older. Below50% phase2 initializes addsT0;
below25% phase3 sets berserk/grabber and idle chargeState. A phase jump may skip phase2.
At phase>=2 addsT advances; at>=8000ms reset0 and spawn ONE Sherri if the global live swarmer
count is<2. The source comment saying "pair" is false; do not spawn two. Phase3 consumes
chargeLanded once and applies500ms stun even through player iframes, as source.

Director gains the remaining priest_fallen pattern; it continues to own per-actor countdowns.
At HP>=50%, keep180–280px, strafe on wall_ms/600, speed fallback1.6, holy projectile280px/s,
22damage/1500ms slow,350ms aim,1200ms throw cooldown and160–300px throw window.
At HP<50%, transition once and use500ms windup,900ms fixed-vector lunge×2.4,
1200ms cooldown,30damage/1500ms slow on contact,600ms contact cooldown. Preserve source phase2
chargeCdT asymmetry: landing does not assign a new chargeCdT while the ordinary charger does.
Motion/contact/LOS ordering still follows the approved P07a wall-first adaptation.
Fallen survival time accumulates whenever a living Fallen actor exists, even after player
respawn, and resets only when no living Fallen exists; at60000ms grant outran_the_priest once.

Old School uses the existing charger pattern:250HP,1.5speed,35damage,36x28px. The source comment
promises grab-freeze but no isOsBrutus grab logic consumes that field; do not invent a stun.
Its door/rip/rank3 transaction belongs to the later site/vendor owner, which calls this spawn API.

## Death transactions and campaign seam

Special branches return before ordinary kills, pipe/drop rolls and ordinary faction rewards:

* Tony active boss: clear boss globals, +200cred, fallen_king done, shoe equipped; synchronous
  campaign unlock/sync hook when available; save immediately, then ending receipt after4000ms.
  Coop changes receipt text/kind. A missing campaign consumer stays an explicit dependency;
  integration parity cannot be declared until connected.
* Older isBossB: brutusOlderActive=false,+100cred,+5maxHp and source receipts. The maxHp bonus
  is the source direct stat mutation, not a newly invented equip item or durable schema field.
  Source lacks an immediate save in this return branch; record that asymmetry rather than
  quietly rewriting save policy.
* os_brutus: +50cred,+2street, cash pile round(80*territoryCashMult) atcenterX-22,
  +5copper/copperStripped with copper_singer threshold, torch atcenterX+22 only if neither
  tool slot nor locker owns it, school_s_out, osBrutusKilled flag, source receipts/save.
* Fallen: omalleyFallenDead flag,+2street,$200 pile atcenterX-18, priest_collar equipment pile
  atcenterX+18, fallen_priest done/unavailable, fallen achievement, source receipts/save.

Kingdom boss/pretender transactions remain with the campaign owner. Adapter contract:
can_finish_actor(detached_actor)->bool performs exact state preflight without mutation;
finish_actor(actor_id)->bool commits the complete source outcome, removes appropriate adds and
projectiles, clears battle globals, syncs quests/forces and saves. Both must exist and consent
before lethal HP is staged. Missing/false handling cannot fall through to ordinary rewards.
Tony's progression hook is campaign.after_tony_defeat()->bool, wrapping source
maybeUnlockKingdom(false,false)+syncKingdomQuests. It may not alter the paid Tony result twice.
The root facade must also synchronously route core kingdom_abort_requested before the next
actor step; otherwise kingdom death/arrest integration remains incomplete.

## Explicit compatibility and repair register

Approved repair1 — unchanged source probe: transform priest, startGame(true) -> ordinary living
priest with omalleyFallen=true; trigger again -> no Fallen. Normalization repairs that softlock.
If fallen flag and not dead flag, rebuild/relabel the authored priest as a fresh Fallen at its
canonical location with fresh combat scratch; if dead flag, there must be no living ordinary or
Fallen priest. No transform sounds/feed, death rewards or achievement replay on restore.
Keep the original source failure as its own oracle fixture and test the corrected property
separately; do not claim corrected behavior matches the broken source.

Preserved asymmetry2 — after Old School dies, same-session spawnOldSchoolBrutus sees its corpse
and refuses cousins despite the40% risk label. No guard change, extra fight or extra reward is
authorized. Source reload recreates base actors; dynamic spawns do not automatically inherit a
saved death ID. The dynamic-spawn boundary must be explicit rather than treating all IDs alike.

Approved repair3 — unchanged source spawnBrutusOlder with stale phase3 yields phase3 but
berserk=false. A new encounter now explicitly initializes phase1, clears old phase scratch and
replaces a prior dead Older record. One authored live identity, no reward replay. Original bug
and corrected properties remain separate evidence.

Preserve remaining phase-jump, single-add, passive-Older, survival-timer, Old School no-grab and
Older maxHp/save asymmetries above. Cosmetic RNG remains separate from gameplay under P07a.
No new sounds or dialogue lines; reuse source receipts and existing synthesized sound IDs.

## Scoped departure adaptation (approved, implemented after P07a checkpoint)

Exactly two source writers set wanderOff: day3 visitor leave uses east off-map target WORLD.w+80
and speed1.2 (daily_hideouts.js:52); completed Price Guy purchase uses west target-80 and speed1.4
(vendors_places.js:554-559). Freed dog expiry directly marks dead and bus resolution directly
removes its actor; neither is routed through this adaptation.

The source physicality clamps bodies to world bounds, so the off-map target is unreachable even
before the 3D perimeter fences. Preserve fences and ordinary movement; do not bypass collision.
Add optional physics adapter resolve_departure(detached_geometry,edge:String)->Dictionary:
{exit_id:String,target:Vector2,route:Array[Vector2]} on success, or{} on unavailable/no route.
All positions are source body-center pixels. Target is a named, visible, authored walkable exit
pad INSIDE the perimeter. Nonempty route ends at that target; points must be finite and route
must reflect current geometry. Geometry input is the same detached x/y/w/h/id record as P07a.

Only wanderOff actors with isDay3Visitor or isPriceGuy/priceWalkOff invoke the seam; targetX
outside west/east source bounds selects direction. Director follows the returned route through
ordinary move_body collision, and removes the actor only when its actual center is within4px of
the pad. Emit actor_departed with actor_id and exit_id. There is no HP/death handler, reward,
corpse animation, wanted change or permanent saved death. Invalid/missing routes emit explicit
dependency evidence and leave the actor physically blocked; no timeout or off-camera deletion.
Other future departure writers require an explicit spec extension.

Root owns authored pads, physical route implementation and actual scene tour. Model tests only
prove the optional seam, route validation, collision stop and no-reward removal. Original
off-map/clamp noncompletion is recorded separately in the source oracle. Until the real pads
and both transaction consumers are connected, departure integration remains incomplete.

## Required evidence and remaining integration

Source oracle covers start gates, exact threshold equality/jumps, adds cadence/caps, Fallen
phase formulas, all special reward branches, duplicate calls and original defect probes.
Model tests cover atomic refusal, blocked placement, weak-reference lifecycle, unique transient
adds, silent/idempotent restore reconciliation, campaign rejection, wall-delayed receipts across
pause and cancellation on fresh/load, equipped-or-locker no-dupe, and domain completion once.
Every test group and fixture loop has a completion guard against script-abort false PASS.

Root alone imports/runs Godot and owns runtime composition. A competent-player <90s defeat
demonstration per integrated boss, damage/readability observation, blocked-wall fights and
native/Web end-to-end tours remain required after model gates. Model damage calculations alone
do not satisfy that playability requirement. Campaign, robbery, breakable props and source actor
departure behavior remain separately tracked dependencies; no pending consumer counts as parity.
