# SPEC — Linked neighborhood quests P06b2

Captured before code, 2026-11-18. Scope/API approved. Parent SPEC-3D-FULL-PORT.md.
Sources: vendors_places.js107-216; neighborhood_a.js481-539; neighborhood_b.js64-76,
88-275,305-346; combat.js102-118,387-394; update.js585-694; activities.js286-306.
This packet is model logic, not a claim of scene, physical pickup or native/Web parity.

## API and ownership

RockBottomQuestDialogue.new(owner,spatial,memory,combat,bosses) uses WeakRefs, existing
ActionSession and Inventory. GameState alone owns p/s/npcs/events. New quest_dialogue.gd,
test_quest_dialogue.gd, source oracle/fixture; no runtime/core/scene edits.
supports(actor_id), open(actor_id), select(token,action_id), close() use the same menu envelope
as resident/core vendor handlers. Supported IDs: barb,dave,stripe,conductor,pigeon.
Nested pages retain the same actor identity, consume parent tokens and issue new capabilities.
Only explicit main openings count visits; validation and nested pages never replay them.
Common real interaction records metVendors and Memory.bother; each action revalidates current
resources, flags, quests, day/caps, actor death, strict60px reach, actual LOS and kingdom lock.
Living Stripe ally interaction is the source non-modal "this is happening" receipt.

Lifecycle methods: tick_before_pickups(dt_ms), tick_after_pickups()->Dictionary,
collect_crown()->bool, open_package()->Dictionary, pick_crown_spot()->Dictionary.
Active step bound0<dt<=50ms; no new wall-clock work. Returned delivery/result menus must be
presented by Runtime. close revokes actor and Block-zone capabilities. Fresh/restore identities
invalidate tokens. Source stage state remains in s.quests/flags/counters/crownPickup.

Register static normalize_crown(raw) through the existing GameState normalizer registry:
null or finite world-bounded {x,y,collected:bool}; malformed values become null. Preserve valid
coordinates/collection state. No new save schema or duplicate pickup store. CROWN_SPOTS is
exported source data. Invalid seed index is rejected before indexing; choose one valid source
spot through the seeded owner RNG. A valid per-save index is reused, even after declining.
Asking fixes the index but does not itself request save; accepting creates the source pickup.

## Canonical handlers and shared boundaries

Barb increments barbVisits. A second visit starts barb_crossword and sets daveHasCrossword.
Returning removes all crossword records, clears hasCrossword, grants one clean supply and
street1, completes the quest, grants seven_across and shows the authored BLAME receipt.
Packet prices use vendor_price(5/22); clean single1 or bulk5 share6/day cap. A quest reward
is outside that cap. Memory.record laundromat/buy uses barb_single or barb_bulk exactly.
barbAside is consumed once with source random aside before random main flavor.

Dave asleep/awake menus remain distinct. Crossword demand requires the active quest and
daveHasCrossword&&!hasCrossword: cred>=3 grants it; lower cred opens20 ransom/fight/leave.
Payment rechecks cash; combat wakes Dave before aggro. Ordinary pickpocket succeeds at<.7
for8cash, otherwise wakes/aggros and wanted+1; no new daily cap or immediate save.
Wake and listen(-5brain capped0) retain source behavior. Combat already owns crossword-on-death;
this module does not add another death listener or reward.

Stripe increments stripeVisits before betrayed/package-held branches. Buy uses vendor_price8,
loyalty+1,40% inventory soap (also offenses-1), otherwise one real rock; street1 either way.
Single/bulk fence uses per-rock vendor_price6 for indices0-2,4 for3-5,2 (min1) for6-9,
then daily closure at10. Bulk requires3 held but sells only remaining daily room. Count
stripeFencedToday/lifetime.rocksFenced per rock; street1 each, spiritual-1 at most3/day using
stripeSpiritualDayHits plus its day stamp. No new generic sale cap.

Package offer starts on third visit and can be revisited until accepted/resolved; acceptance
sets availability/held flag and exact inventory record. Holding locks normal Stripe commerce.
Betrayal locks commerce and closes the quest. Loyalty>=5 opens coop proposal; decline sets-1
(not a new permanent decline flag, so later purchases can raise it). Agreement invokes the
single Bosses.start_coop atomic transaction; missing/false capability refuses without partial
quest/payment changes. Tony aftermath remains Bosses→Runtime/campaign, never this module.

Conductor's independent trade consumes3copper for90cash and completes conductor quest once.
Pigeon secret2cash increments pigeonTrade by2 and one_foot at20; exact park/buy/pigeon_secret
recognition. Second visit can offer crown; accepting sets quest available and a source pickup.
Collecting equips pigeon_crown through existing apply_equip_stats, marks collected, completes
quest and head_that_wears once. No duplicate item/drop or separate bonus stat.

## World lifecycle, order and physicality

Source updateWorld order is Conductor wait(585-593), cash pickup(596-650), crown(653-669),
package delivery(673-694), actor AI(updateNpcActors at701), particles(704-713), projectiles(718-749),
boss phases(757-856), rank(859-867). Root must reconcile current Runtime ordering explicitly.
Conductor wait is strict80px,60s; leaving radius resets, but a dead/missing Conductor freezes the
counter as source. Waiting is a proximity observation, not a newly invented LOS interaction.

Crown collection is strict18px plus current spatial.can_reach_target("quest:crown"), resolving
the real s.crownPickup at0.72m reach and actual walls. Never silently relocate the authored spot.
Auto-delivery requires playing, held flag, living Conductor, strict60px and current Conductor
LOS. Remove held flag/all package records; pay40cash/3cred and exact_change only if quest not
already done. Emit the original receipt even when the quest was already done, preserving its
source wording. It opens dialogue during this update; the current source call still processes
actor AI/projectiles/boss phases/rank afterward. Only subsequent world updates pause.

open_package is an action from the real Block menu after source interaction priority resolves.
Validate current Block zone plus spatial.can_use_zone("block"), mode/kingdom lock and held flag;
no reach to the guidance marker, invented shortcut or inventory-presence gate. Raw held flag
is the source authority. Consume all package records/flag once, set betrayal flag/quest done and
what_s_in_the_box. RNG<.35:5rocks; <.65:two separate soap records; <.90:knife; else wanted+2 capped3.
Return exact close-only result menu, with current zone capability. Root owns input/presentation.

Route/hustle authority stays Progression. Mutate exact source counters/lifetime only; no
independent route rolls/checks/rewards. Flag stripeBetrayed blocks its existing fence route gate.
Source counter stripeBetrayed is a separate death-path counter: opening the package only sets
the flag. Preserve that asymmetry; do not invent judas credit for opening alone.

## Evidence

Unchanged-source oracle: exact menus/open effects and outcomes at caps, RNG thresholds,
crossword branches, nested stale capabilities, fencing bracket boundaries/loyalty/betrayal,
crown seed/accept/equip, package branches/delivery, Conductor waiting and source no-save quirks.
Properties: no replay/duplicate reward, current LOS/geometry, missing coop capability, restore,
malformed crown data, migrated inventory units, one owner, ordering and simultaneous pickups.
Root alone runs Godot and adds actual crown geometry/adapter, Block option, auto-receipt and
Runtime orchestration. Missing integration stays pending rather than counted as parity.
