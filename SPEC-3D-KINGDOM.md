# SPEC — Curb Kingdom actions and encounters P13c

Captured before code, 2026-11-18. Parent approved a disjoint Kingdom owner and the
two narrow Day seams below. This extends SPEC-3D-CAMPAIGN without changing the
accepted office, normalization, daily force, combat or movement authorities.
Root owns Runtime/scene integration, all engine runs and native fight evidence.

## Inventory and composition

Source campaigns313–544: stage clan/objective/hint/bitcount projections, four doors,
summons and two ledger forms, nine correction marks, four boss banners, four boss
encounters (one boss plus two adds), escape/abort, four once-only boss rewards and
one daily pretender reward. The12 stages,3 clans,4 boss definitions,15 guard posts
and rotating pretenders remain exported Content authority. P13a owns ordinary
force generation and restore; P13b owns all office resources/work. MemoryLoop alone
owns the real-rock Block anointing step, source concessions294–304. There is no
second crown pickup or alternate rock transaction in this packet.

New RockBottomKingdomCampaign(state,spatial,campaign,office,combat,memory,
communications,days) uses weak references and the single p/s/npcs/projectiles.
New files: kingdom_campaign.gd, test_kingdom_campaign.gd,
tools/3d-kingdom-oracle.mjs, tests/fixtures/kingdom_reference.json and this spec.
Only approved Day prospective validation/pending-clan methods modify accepted code.

Public API:

```
ready() -> bool
open_ledger() -> Dictionary
select(token: Variant, action: String) -> Dictionary
close() -> void
active_targets() -> Array[Dictionary]
use_door(id: String) -> Dictionary
use_target(id: String, context: Dictionary = {}) -> Dictionary
objective() -> Dictionary
start_boss(clan_id: String) -> bool
can_finish_actor(detached_body: Dictionary) -> bool
finish_actor(id: String) -> bool
after_tony_defeat() -> bool
abort(show_receipt: bool = false, refresh: bool = false) -> bool
tick_active(dt_ms: float) -> bool
tick_wall(monotonic_ms: float) -> bool
commit_ending() -> bool
```

Root routes Office's consumed kingdom_actions_pending branch into open_ledger.
Ledger selection uses ActionSession at the actual office door, strict44px/fresh
LOS on open and selection. Work delegates to Office._start_work only after that
capability and current source enabled checks; it never duplicates route/work math.
Back delegates Office.open('office') with domain:'office'. Summons needs the radio
and exact summons stage; it changes tarp_marks/0, synchronizes quests, emits source
radio/news/feed/receipt/save. Communications broadcast/post run through their real
owner at the source call site. Choir door uses Memory.record('choir_office','bother',
'wire_door'); an accepted duplicate/venue refusal is source behavior, not a missing
dependency. Missing real owners reject readiness/actions explicitly.
After a valid capability is consumed, a fresh geometry or unknown-action failure
closes only this owner's dialogue and restores playing if dialogue is still the
current mode. Stale tokens preserve a newer menu; replaced-state failures never
write into the new epoch or override an external lifecycle mode.

Doors preserve source strict44px and source order. Marks use strict58px, banners
strict72px. Both targets preserve playing-only, hidden, stun, any-boss and older
Brutus guards; doors/ledger retain ordinary interaction rules and do not invent
rawHP gates. World already exposes the exact source IDs and1.76/2.32/2.88m reaches.
The three correction bits can be served in any source order and once each. Three
bits are required before each clan banner; emperor banner requires emperor_gate.

## Approved physical adaptation KINGDOM-BATTLE-STAGING

Starting a fight first constructs all three exact source records and stages actual
body placements through Combat.clear_actor using profile-specific capsule heights.
Every returned position must be finite, inside world bounds and at most100px from
its source position. Refusal of any one leaves all model actors, stage, pending
placements, resources, RNG, receipts and saves unchanged. Placement caches may be
prepared, but no invisible boss/add is appended. No fallback moves the player.

After all three pass, cancel only the challenged clan's pending ordinary guards via
Day.discard_pending_campaign_clan(clan,false), then remove that clan's live guards,
append the boss/two adds and commit source globals/stage/receipt/save. Other clans
are not respawned by starting a fight. Pending guards must not later materialize
inside the same active boss fight. Guard refresh after escape/victory stays in the
one Campaign→Day generation path and may defer inaccessible guards normally.

Before fatal damage, can_finish_actor validates the actual current live identity,
matching battle/stage, absence of the durable defeat, and prospective refresh
capacity through Day.can_replace_campaign_forces(kingdom,lifetime_pretenders).
That method is pure: exact canonical state, bounded integer counters/current day,
canonical source generation, required live placement capability and pending capacity.
It performs no placement/RNG/state/event mutation. A failed preflight cannot consume
fatal damage or pay a partial award. finish_actor rechecks before a synchronous
commit. Actual placement refusal after capacity preflight becomes saved pending
guards under the approved Day contract, not a failure after awarding victory.

Approved adaptation KINGDOM-REJECTED-COMPLETION-PURITY: source's direct invalid-stage
completion call may normalize malformed Kingdom state before returning false.
The3D Combat fatal-damage contract instead requires failed can_finish_actor and
finish_actor to leave state, death flags and rewards untouched. Runtime reaches
these methods only after codec/foundation normalization. Keep those unchanged-source
counterexamples labeled in the oracle, prove their source repair independently in
P13a, and explicitly test the3D pure refusal. No valid completion behavior changes.

## Battle clocks, outcomes and lifecycle

Source updateKingdomBattle runs once per accepted active step, before actor AI and
paused by menus/hitpause/cook activity. dt is finite positive and at most50ms. Zone
membership includes its edges. Outside escapeT accumulates; inside resets it. Only
strictly greater than5000ms aborts, refreshes guards and saves. A missing/dead boss
does not advance its battle timer. Emperor phase uses source else-if: below.66 from
phase1 becomes ranged/speed1.2; below.33 from phase2 becomes charger/berserk/speed2.6/
damage15 on a later update, with exact receipts/sound. No additional phase health.

Death/arrest call abort(false,false) synchronously and remove Kingdom bosses/adds and
their projectiles before recovery/save; source death/arrest do not refresh guards.
Abort restores clan marks7 or emperor_gate/0, clears globals/quest projection and
retains all durable defeats. Escape calls abort(true,true), then source save. Fresh/
restore clear ephemeral timers/capabilities; P13a performs canonical load demotion
and refreshed forces. The model epoch must never receive an earlier state's ending.

Combat/Boss delegates can_finish_actor/finish_actor without adding their own rewards.
Boss IDs/rewards are Darryl24cash/18cred, General30/22, Bishop36/26, Emperor60/40.
Remove matching boss/all adds/projectiles and clear battle globals, write defeat,
next stage/marks/clear flag, source quests/receipts/feed, refresh source forces, save.
No combo/pickup/ordinary death rewards accrue to any Kingdom actor. Pretender death
marks the actual live actor dead, stamps current day, increments the reconciled
counter and lifetime once, and grants exactly10cash/2cred. A repeat callback or same
day duplicate cannot pay. Daily respawn remains P13a/Day responsibility.

Emperor completion saves complete/pretenderDefeatedDay before scheduling2600ms on
Runtime's monotonic wall clock. The Kingdom owner emits one epoch-bound
kingdom_ending_due event at expiry; it never changes modes from a wall callback.
Runtime must route that request through its lifecycle queue, including accepted
Cooking resolution protection. Once the mode transition is accepted, commit_ending
sets endingContinue and emits the source save plus ending_requested presentation
with ONE CRACKLORD and the original folding-chair receipt. Return preserves the
existing world and endless pretenders. Forced fresh/restore drops old requests.

after_tony_defeat delegates foundation maybe_unlock_kingdom(false,true) and
sync_quests; Tony's existing completion owns its save. The MemoryLoop kingdom_changed
event synchronizes quest/objective projection, never performs another smoke. No
soap/hitter/remote smoke can replace the real Block rock before emperor_gate.

## Evidence and limits

The unchanged-source oracle executes real summons/ledger callbacks, all marks and
door receipts, all four complete boss payloads, stage/reward/duplicate failures,
inside/outside/5000ms escape boundaries, phase thresholds/else-if order, source
death/arrest differences, three pretender profiles, same-day reward suppression and
the actual2600ms ending callback. Separate action sequences retain exact RNG order,
resources, canonical actors, source save count and quest/achievement projection.

Godot gates additionally exercise actual Combat/Boss fatal-damage delegation, all-
three staging refusal, malformed/unbounded placement, pending-clan cancellation,
prospective queue saturation refusal, guard defer/retry, stale menu/fresh geometry,
one-shot epoch-bound ending lifecycle, and source active/wall clock separation.
Root must prove world banner/door/mark reach, real mesh/collider coverage, uninterrupted
Block smoke18s high→8s crash, competent fights under90s, and final native/Web behavior.
Model gates alone do not establish those physical/render/performance claims.

## P13c physical gate appendix

Before generation, parent authorized only new `tests/test_kingdom_physics.gd` and
this appendix. The gate builds the actual FullNeighborhood once, uses the actual
WorldAdapter and real Campaign/Office/Day/Combat/Boss/Memory/Communications owners,
and registers actual Roster rigs at the accepted boss/add positions. No replacement
geometry, fake placement success or Runtime implementation is introduced.

For all9 marks,4 doors and4 banners, require a clear standing approach, an accepted
real sight ray, source strict58/44/72px boundary rejection and a clear point just
inside that boundary. A temporary unrelated collision body across the actual eye
ray must reject the same command without consuming a correction, starting a boss
or changing resources. Removing it must restore access. The test fixture body is
removed and adapter collision certificates invalidated before continuing.

Physical audit correction: service range is evaluated in canonical source pixels,
before world conversion. Kingdom service records retain raw door centers, marks
and banners; their source point is never reconstructed from a float32 rendered
position. Only the eye/target LOS endpoints are converted to metres. This preserves
strict44/58/72px boundaries without an epsilon or radius change. World approach
selection grows standing footprints by0.006m beyond the0.48m player radius, matching
the existing navigation safety allowance and exceeding the0.002m overlap-query
margin. The fence, correction coordinates and actor capsule remain unchanged.

Walk the source progression from the office through each clan's3 corrections and
banner, the real Block anointing position and the throne banner. Each selected
physical route must be followed by actual player capsule sweeps; no intermediate
position teleport may stand in for route completion. Fixtures may set a normalized
stage between isolated cases, but do not call injected damage a completed fight.
The route graph test proves access to every required stage, not fight difficulty.

Each arena must accept all3 exact source encounter records using actual profile
heights, within the already approved100px placement bound. Require each returned
shape clear, matching nonempty visual/rig height and unique live IDs. Actual world
placement refusal caused by a bounded temporary solid must reject the whole start
without partial actors, stage, pending-force or resource mutation. A saturated Day
queue must make completion preflight false before damage; this is not a victory.

For each arena, select a clear source-zone interior and exterior, route the actual
player capsule between them, verify inclusive edge/reset semantics where physical
placement permits, and verify that5000ms outside retains the fight while5001ms
recesses it through the real shared force owner. Log physical route length and
walk time; no60s campaign deadline is invented for these untimed court walks.

This gate uses synchronous bounded world routing only in QA and never per actor
per frame. Root alone runs it. Native competent-input battles under90s, visible
animation/telegraph quality and60+ actor frame budgets remain separate acceptance
evidence; a direct-damage call cannot satisfy any of those claims.


## Production owner and scene connection

FullRuntime composes exactly one Kingdom after Combat and before Bosses; Bosses delegates
Kingdom death preflight/commit and Tony-unlock aftermath to that owner. Runtime consumes the
already validated Office kingdom choice into a new Kingdom ledger. All ordinary menu
replacement/lifecycle closes its capability. Fresh/restore syncs the epoch; no delayed ending
from a replaced run can survive. Active Kingdom updates occur before actor AI; wall time is
advanced once per Runtime wall tick. kingdom_abort_requested is consumed before death/arrest
presentation and queued save capture, without refreshing campaign guards.

The2600ms ending is an event, never a direct timer mutation of cookmini. Runtime queues it
behind an accepted cooking resolution, with existing first-request/epoch rules, and then
commits Kingdom's original title/text/save once. Memory's kingdom_changed synchronizes quest
state. The real interaction order is office/hideout/old-school/Kingdom doors, active Kingdom
marks/banner, Office field, route, NPC, heist and prop/zone verbs. Aim+source radius+LOS are
required. Quest ledger shows the authoritative Kingdom objective. No scene grants resources,
marks, wins or summons. Native actual button/target tests must cover the Office handoff,
three marks, battle admission/abort and resource-preserving rejected interaction.

Objective predicate correction from the Guidance source counterexample: clan and
emperor live objective coordinates require kingdomBoss, matching ID and !dead,
exactly as campaigns.js349/359. A same-ID ordinary row cannot replace the fixed
court coordinate; normal combat lookup is unchanged. Two independent source paths
toggle that flag, restore it and mark the same actor dead, bringing the oracle to
159 paths/369 steps. This corrects a read-only objective seam, not battle behavior.
