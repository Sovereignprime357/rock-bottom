# SPEC — Office and curb kingdom campaign P13

Captured API/packet contract, 2026-11-18; parent approved P13a before generation.
This contract describes the complete source campaign and a bounded P13a foundation first;
it does not claim that an office menu or a Kingdom boss is currently playable.
Root owns Runtime/scene composition and all engine execution.

## Inventory and authority

`src/systems/campaigns.js` exports54 functions. Its source-owned data is already in
Content, with no renamed IDs: six upgrades;11 claim sites with22 physical field
anchors; three claim stages and two work stages;12 Kingdom stages; three clans;
four boss definitions including the emperor; nine correction marks, four banners,
four flavor doors,15 ordinary guard posts and three rotating pretender profiles.
The two campaign residents are `lease_guy` and `gutter_greg`, already in source/roster.

Source surfaces by packet:

- State/restore: campaigns24–85,254–329; audio_save140–143,200–219;
  start133–142. Exact Office/DistrictClaims/Kingdom normalization, office day stamp,
  durable milestone/defeat witnesses, six Kingdom quest projections and ephemeral
  boss-load demotion. No repair grants old cash/cred rewards again.
- Office economy/actions: campaigns87–253 and daily_hideouts142–209,228–231.
  Existing Progression owns maybeUnlockOfficeQuest's equivalent; retain one writer.
  Office purchase, upgrades, claim select/survey/file/install/cancel, radio work,
  daily caps, route-board reroll, milestone repair and both residents' dialogue.
  Travel remains the sole owner of cot/rest/sleep/shared locker transactions.
- Kingdom progression: campaigns299–432 and concessions294–304. Eligibility,
  summons, ledger, nine marks, four doors and four banner challenges. MemoryLoop
  already owns real-rock Block anointing; consume its kingdom_changed event to
  synchronize quest projections, without adding another smoke transaction.
- Battle lifecycle: campaigns433–544. Source actor factory, three clan bosses,
  emperor phases, two adds per battle, abort/escape, one-time rewards, cleanup,
  force refresh and once-per-day pretender. Existing Combat/ActorDirector owns
  movement, damage, projectiles and charge behavior. Existing Boss calls
  can_finish_actor/finish_actor for these campaign actors.
- Objective/hint projection: campaigns137–158,329–375,545–659. Return source
  campaign objective data and active service targets to the existing presentation;
  no second HUD or new tutorial. Cross-system primary-objective priority stays in
  root composition, not a parallel campaign tick.

Claim IDs in source order: canal,alley,projects,skidrow,scrap,underpass,oldschool,
warehouse_row,market,park,trainyard. Upgrades are cot,locker,desk,generator,radio,
route_board. Clans are blue_tarp,cart_cavalry,copper_choir; bosses are
darryl_under_blue,general_receipt,bishop_wire,curb_emperor.

## Single-authority/API proposal

One `RockBottomCampaign` RefCounted uses GameState p/s/npcs/projectiles and existing
Content definitions. No copied saved state, replacement RNG, independent actor
registry or second interaction capability system. Weak references to spatial,
Progression, Travel, Communications and the eventual Recognition facade are explicit.
Pure normalization/planning needs no fake presentation/service dependencies.

Approved P13a files: `campaign_system.gd`, `test_campaign.gd`,
`tools/3d-campaign-oracle.mjs`, `tests/fixtures/campaign_reference.json`, this spec.
Small approved Day changes would consume the plan extension and share force refresh.

```
new(state, spatial = null, progression = null, travel = null,
    communications = null, recognition = null)
normalize_claims(raw) -> Dictionary
normalize_office(raw, claims) -> Dictionary
normalize_kingdom(raw, demote_boss = false) -> Dictionary
plan_for_state(day: int, kingdom: Variant, lifetime_pretenders: Variant) -> Dictionary
reconcile_loaded_state() -> Dictionary
prepare_day(next_day: int) -> Dictionary
sync_quests() -> void
update_office_milestones(persist = true) -> bool
bind_day_owner(day_owner) -> void
refresh_forces() -> bool
```

The registered Kingdom codec normalizer uses load demotion before defeat-based
promotion. In particular, a saved tarp_boss with a general_receipt defeat repairs
to wire_marks with all seven retry marks, matching the source load order. Live
prepare_day uses non-demoting normalization; registration belongs to fresh/load
composition, never mid-battle reconstruction. plan_for_state is the same pure
builder used by prepare_day and by Day's complete generation validation. Validation
compares against the current owner's canonical Kingdom/lifetime and requested day,
including actor count/order, identity pairing, stats, posts and every payload field.
Equal finite JSON integer/float representations compare numerically; omitted/extra
fields, altered known identities, stale state or invented force generations reject
before actor removal, saved-pending replacement or counter mutation.

`prepare_day` is deterministic, side-effect-free, finite and RNG-free. It reads
current campaign/lifetime, normalizes the same way source ensureKingdomState does,
and returns `{ok, kingdom, pretenders_defeated, actors}`. `actors` contains canonical
source guard/pretender payloads at the requested day, no callbacks. The additive
pretenders_defeated field records the exact source max of durable Kingdom and lifetime
counters; Day commits it with the Kingdom before rolling hustles. A failed plan
mutates neither current day nor state. Only GameState advances day/lifetime dayCount.

Approved shared physical seam `Day.replace_campaign_forces(plan)->bool` validates a
current-day canonical plan, replaces old guard/pretender generations and uses the
already approved dayPendingPlacements queue. Dawn commit and Campaign's fresh/load,
abort/victory refresh call this single implementation. No separate campaign pending
queue, invisible actor or geometry bypass. Capacity is checked before replacement;
physical refusal defers exact generated payload without reroll/reward replay.
Plans include their exact `day` and finite integer `pretenders_defeated` in0..1e9.
Reject wrong-day, duplicate-ID, malformed canonical Kingdom/payload or over-capacity
plans before any removal. Dawn validates its next-day plan before the Core increment;
current-day refresh validates before replacing actors. Applying a plan synchronizes
both Kingdom and lifetime pretender counts before creating or deferring actors.

Later P13b/c methods on the same owner:

```
supports(service_id) -> bool
open(service_id, page = 0) -> Dictionary
select(token, action_id) -> Dictionary
use_field_target(target_id) -> Dictionary
objective() -> Dictionary
active_targets() -> Array[String]
can_finish_actor(detached_body) -> bool
finish_actor(id) -> bool
tick_active(dt_ms) -> bool
tick_wall(monotonic_ms) -> bool
abort_battle(reason) -> bool
```

Menus reuse ActionSession/current state/LOS with source predicates and prices. NPCs
use strict60px reach; office/Kingdom doors strict44px; claim survey/sign and Kingdom
marks strict58px; banners strict72px. Existing full-world IDs are office,
claim:ID:survey/sign,kingdom:DOOR,kingdom_mark:CLAN:INDEX,
kingdom_banner:CLAN and kingdom_banner:throne. Field actions retain source playing,
hidden/stun/boss/older-boss guards. Dialogue callbacks do not invent rawHP/stun gates.
Root routes parent office cot/chest options into Travel envelopes, retaining its
single resource/day authority and fresh capabilities.

## Exact economic and state contracts

Office purchase requires three filed block routes,$40,1 copper; complete office
quest, unlock paper_empire and squatters_rights once. Upgrades consume source costs
in Content, no charisma pricing. Recover ownership from valid upgrade/claim/job or
completed-office-work evidence, exactly as normalizeOfficeState specifies; infer
desk/radio where durable jobs imply them. Malformed partial upgrade maps receive
all six canonical boolean keys. Claim and work jobs are mutually exclusive.

Claim faction threshold is liked+10 except neutral canal. Filing consumes
$20+5*existing_claim_count and1 copper; cancellation after filing has no refund.
Installation adds exactly2cred and no cash. Office milestone counts1/4/8/11 update
source quests/achievements/lifetime as one complete state mutation before optional
save. Radio work excludes the prior claim when alternatives exist, consumes one
RNG selection, pays min(12,5+claims), grants1cred every fifth completed order and
caps daily work at min(3,1+floor(claims/4)). An inspected order waits through a full
ledger until morning. Route board rerolls once/day without route payout.

Kingdom unlock requires office, four claims and fallen_king done; no faction or
product economy is changed by the Kingdom. Three marks per clan are a bitmask.
Clan rewards are24/18,30/22,36/26 cash/cred; emperor60/40; daily pretender10/2.
Rewards require the actual matching live campaign stage/boss ID and durable defeat
absence, and cannot replay after repair/load or duplicate death callback.
Real-rock Block anointing remains required to reach emperor_gate; soap/hitter or a
remote rock cannot satisfy it. The existing18s high/8s crash loop stays intact.

Force refresh removes old guard/pretender generations, creates four guards per
uncleared clan or two per defeated clan, omits a clan during its boss stage, creates
three throne guards (two after completion; none during emperor battle). Completion
can add one pretender if not defeated today: source day%3 profile and numbered name,
100HP,9damage,1.45speed; at most16 source refresh actors. No random identity changes.
Source noComboReward/transient/zoneOnly/target/charge fields remain intact.

## Proposed physical battle adaptation (approval before P13c code)

A banner start preflights all three actual boss/add placements using bounded existing
clear_placement and canonical mesh heights before removing guards or changing stage.
Any refusal leaves the banner retryable and emits a concrete blocked-placement result;
no partial battle or hidden boss enters the model. Boss-spawn candidates remain at
most100px from authored source positions. This is distinct from the approved daily
guard deferral: a player-initiated fight starts as one complete encounter.

Escape is source continuous outside-zone time strictly>5000ms, reset inside. Abort
preserves three marks/full retry, clears matching boss/adds and their projectiles,
and refreshes ordinary forces. Death/arrest/restore must use the same lifecycle hook.
Emperor changes at hp/maxHp<.66 and<.33: phase2 ranged/speed1.2, phase3 charger,
berserk/speed2.6/damage15. After emperor victory schedule the source2600ms ending
receipt once in the same model epoch; save durable completion before scheduling.
Native actual combat must prove competent defeat under90s; model math alone cannot
establish the user-facing fight budget.

## P13b bounded office contract — approved before generation

Keep the accepted Campaign foundation stable. Add RockBottomOfficeCampaign in
office_campaign.gd, constructed with (state,spatial,campaign,progression,travel).
It is an action/menu facade over the same p/s, with no copied durable state or
second office state machine. Approved owned files are office_campaign.gd,
test_office_campaign.gd, a new
tools/3d-office-oracle.mjs with office_reference.json, and this spec. Root owns
Runtime, service routing, scene prompts and actual geometry checks. Keep the
accepted P13a/Day force and normalization contracts unchanged.

This packet ports sixteen campaign functions: officeOwned, activeOfficeContract,
officeDailyCap, claimGateReason, currentOfficeObjective, selectDistrictClaim,
cancelDistrictClaim, claimFileCost, fileDistrictClaim, tryUseOfficeFieldTarget,
startOfficeWork, fileOfficeWork, purchaseOfficeUpgrade, purchaseOffice,
leaseGuyDialogue and gutterGregDialogue. Six daily_hideouts functions complete
the office menus: tryEnterOffice, officeUpgradeCount, openOffice,
openOfficeUpgrades, openClaimLedger and rerollBlockRouteAtOffice. The existing
openOfficeCot/openHideoutChest delegation surfaces remain Travel-owned.
Existing ensureOfficeState/syncOfficeDay are reused,
Progression keeps maybeUnlockOfficeQuest and route generation, and P13a keeps
milestone/Kingdom eligibility/quest repair. There are eleven claim paths, twenty-two
field anchors, six upgrades, two resident menus, two claim-ledger pages (7+4),
three claim phases and two work phases. No new identities, prices or rewards.

Approved public API:

```
supports(target_id: String) -> bool # office, lease_guy, gutter_greg
open(target_id: String) -> Dictionary
select(token: Variant, action_id: String) -> Dictionary
close() -> void
active_field_target() -> Dictionary # exact service ID/source point/stage, or {}
use_field_target(context: Dictionary = {}) -> Dictionary
office_objective() -> Dictionary # source objective projection, or {}
```

Nested upgrade/claim pages use the same ActionSession and consume one capability
before reopening the next page. Every command rechecks offered/enabled options,
current resources/contracts/day/ownership and fresh live geometry. Successful
token consumption closes this owner's dialogue before those fresh
checks, matching the source callback order; an external non-dialogue lifecycle
mode is preserved. A stale token does not close the current valid menu.
At the office
door use strict44px from the source door center; at either resident use strict60px
from its actual current body center. Menus reject actual noninteractive lifecycle
modes and Kingdom fights, but do not invent rawHP/stun or ordinary-boss guards.
Field actions instead preserve the source playing-only, hidden, stun, any-boss and
brutusOlderActive guards and strict58px from the active survey/sign. The world
currently declares claim reach2.30m: root must correct it to2.32m before the
57.99px/58px physical boundary gate. A fresh spatial answer is still mandatory.

Office opening retains source ensure/sync/milestone/Kingdom ordering after access
validation. An unowned office offers the original locked-door aside, never a new
purchase shortcut. The locked-door branch does not call ensureOfficeState or sync
the work day; source tryEnterOffice only normalizes by entering an owned office.
The leasing menu independently normalizes at its own source call site.
Greg's menu and duck-count transaction never normalize or synchronize office state.
Lease purchase is the sole $40/one-copper/three-routes command.
Greg uses GameState.apply_rep for his once-per-day +1 scrap and tier transitions.
Claim start/fill/cancel/install and radio inspect/file all preserve source receipts,
saves and exact order; there is no payment refund after a filed cancellation.
Work may be accepted/filed only under the source cap and competing-contract rules;
closed daily ledgers retain inspected work until a later day. Selection consumes
exactly one authoritative random draw and excludes lastWorkId when alternatives
exist. Route-board reroll calls Progression.valid_route/roll_route(false,last),
retains lastStopId, uses the existing RNG stream and grants no completion payout.

Cot/locker selections call Travel.open('office:cot'|'office:chest') and return its
envelope with domain:'travel'; Travel's office back navigation returns through the
same Campaign.open('office'). No duplicate rest/sleep/stash logic. An unlocked
Kingdom ledger remains an explicit P13c dependency: keep the source option but
return kingdom_actions_pending until its real implementation exists. Do not claim
the complete office/Kingdom menu graph is playable before that packet integrates.

The unchanged-source oracle will invoke real menus and callback transactions,
pin all offered labels/disabled flags, and snapshot resources, offices/claims,
quests, achievements, counters, routes, events and RNG calls. Cover every claim,
upgrade and page; cash/copper/routes/faction/cap boundaries; install-cancel replay;
last-work exclusion and one-claim fallback; fifth-order cred; dawn reopening;
reroll last-stop/RNG/no-payout; field57.99/58 and door43.99/44; negativeHP/stunned
menu actions versus guarded field actions; resident once-day and tier boundaries;
stale token, moved/occluded target, replaced epoch and nested-menu revalidation.
Godot tests use the real Progression, Travel and P13a foundation where relevant.
Root later proves actual world access and movement; model fixtures alone do not.

## Gates and explicit packet limits

P13a first: unchanged-source oracle for normalizers, malformed/legacy durable-witness
repair, all12stages, day changes, guard counts/IDs/stats, three pretender variants,
same-day defeated suppression, pure plan no-RNG/no-state mutation, exact lifetime
reconciliation, and deferred placement/save recovery through the real Day seam.
Model tests include source office partial-upgrade-map repair identified in P14's
oracle arrangement review. Do not claim office/battle actions from a day-ready owner.

P13b next: every11claim path, both ledger pages, all6upgrades, price/threshold/daily
boundaries, source cash/copper/faction atomicity, office/field actual LOS/range,
two residents, Travel delegation, stale capabilities and milestone replay hunts.

P13c next: full stage chain, all4bosses/adds, phase thresholds, exact rewards,
abort/death/arrest/load, daily pretender, real anoint smoke, actor/collider/rig coverage,
actual native combat budget and source2600ms ending epoch behavior. The choir-office
door requires the real Recognition consumer; a missing owner is an explicit blocker,
never a successful no-op. Root owns composition, physical scene and final exports.

## P13b production composition

Runtime owns one Office instance sharing Campaign, Progression and Travel. Every replacement menu, pause, fresh/restore and death/arrest closes its one-use capability. Scene uses the actual 44px office door before hideouts and the active 58px survey/sign before route stamps; both require the existing physical line of sight and first-person aim. Lease/Greg participate in the same closest-resident scan. Returned Travel envelopes retain their domain, and locker back returns through a new validated Office.open. The quest ledger includes the source office objective. The field reach is now corrected to2.32m; paused/hidden surfaces cannot issue field input. No marker can grant a claim without its live stage, proximity and physical permission.
