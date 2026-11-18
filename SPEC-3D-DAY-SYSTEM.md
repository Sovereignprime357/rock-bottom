# SPEC — Authoritative days and conditional residents P14a

Captured before generation, 2026-11-18. Parent approved four-cause synchronous day
composition and the deferred-placement adaptation below. This packet does not own
Runtime/scene integration, atmospheric rendering, campaign logic or the phone feed.

## Source inventory and scope

- `src/core/runtime_ui.js:76–81`: one weather roll; clear at r<.65, rain at r<.88,
  fog otherwise. Three states, no independent weather clock or gameplay speed bonus.
- `src/core/update.js:173–217`: natural240000ms day, weather, daily reset, hustles,
  tuesday_again, dawn toast/news/feed, garbage roll/schedule, scripted events,
  proud-call schedule, mom pass then rent. Preserve this RNG/effect ordering.
- `src/systems/daily_hideouts.js:17–129,220–225,265–276,308–322`: six accumulating
  daily counters, four scripted events, day30 rehydration/ending, two sleep variants.
- `src/minigames/activities.js:305–324`: Block sleep is the fourth cause. Increment
  slept and settle today's hustles before tomorrow's sheet; stats afterward.
- `src/dialogue/vendors_places.js:494–576`: every-third-day Price Guy plus five
  outcomes, source equipment ownership/locker rule and real walk-off.
- `src/core/update.js:405–428`: price-day poll and once-per-day nighttime park cash.
- `src/data/npc_spawns.js:45`, `src/render/frame.js:175–187`,
  `src/core/update.js:699`, `src/systems/interactions.js:65–77`: strict night predicate
  t<.25 or t>.75, four hidden daytime presentations (mom,pete,cubscout,train_hopper),
  Pete shopClosed. Source still scans hidden NPCs; do not silently turn a rendering
  rule into a new transaction gate. Root must author readable first-person service
  presentation when these source actions remain available at night.
- `src/systems/campaigns.js:83–85,516–537`: office day stamp and guard/pretender
  refresh are delegated to the single campaign owner, never reimplemented here.
- `src/systems/communications.js:30–40,64–79,92–105`: proud call, garbage truck,
  persisted Unix-ms silence. These remain required communication/prop-owner seams.

Scope totals: four rollover causes, three weather outcomes, six daily reset keys,
four exact-day events, three conditional actor families (visitor/Price Guy/driver),
one nighttime cash roll, four presentation visibility rules, two delayed dawn
callbacks. Ambient phone/random incidents, bench/dog timers and their menus are
separate packets. No new identities or economy are introduced.

## Cause contract and single authority

GameState remains the only day/lifetime increment writer. Its `_advance_day(cause)`
accepts natural,hideout_sleep,office_sleep,block_sleep; a synchronous installed
callback completes daily consequences before the method returns and before a save
snapshot. `day_started` carries cause and a handled marker, so Runtime must not
repeat hustle/pass/rent work. Foundation-only GameState retains its existing fallback
when no handler is installed; production installation requires real dependencies.

Natural time keeps existing high/crash/quantum logic. Core preflights required day
capabilities before an interval crossing dawn. A missing owner rejects that interval
without spending time/RNG/resources. Physical spawn failure is deferred, not a failed
day commit. There is no detached full-state simulation or second transaction engine.

All rollover causes set lifetime.dayCount, roll weather, zero exactly the exported
DAILY_COUNTER_KEYS (stripeFencedToday,barbPacketsToday,peteCashToday,heistsToday,
robberiesToday,breakinsToday), synchronize office/campaign forces, and roll hustles.
Keep *Day stamps and robLastClockMs. Natural unlocks tuesday_again before its dawn
receipt/events. Office/Block unlock it after scripted events; hideout does not.
All sleep reaches dayTime.3, increments only when prior>.3, and omits ordinary
dawn news/feed, garbage/proud scheduling and Travel's mom pass/rent.

Travel continues to own shed/mom/office stat rewards and its existing once-day mom
pass/rent transaction. DaySystem implements its advance_sleep_day dependency.
Block sleep alone adds slept/check_hustles before rollover, then50hp/25brain,
+15shakes,-1wanted clamped, source coin/toast/feed/save. No sleep clears18s/8s timers.
Block action requires current Block membership and a fresh can_use_zone answer.

## Dynamic event and persistence contract

Exact days only:3 visitor,7 silence,14 inheritance,30 bus. No catch-up of missed
day flags on loading a later day. Once-fired flags prevent reroll/reward duplication.
Visitor source top-left is player+(80,30), clamped40..world-40; fixed24x28 stats.
Its leave action sets wanderOff/speed1.2/targetX=W+80, with actual ActorDirector
departure routing. No instant deletion substitutes for walking out.

Day7 sets silenceUntilT=shared injected Unix milliseconds+240000. It persists and
expires during menus/offline time; monotonic combat time cannot replace Unix time.
The writer emits only source toast/save. Dawn's earlier news/feed is not retroactively
suppressed. Feed/ticker handlers evaluate silence at their own source call time.
Day-owned feed/news calls therefore invoke the required Communications post/broadcast
owner synchronously, before later events change silence. Other producers (including
Progression's earlier hustle news) must preserve call-time suppression through the
Runtime composition; delayed outbox consumption is not a new silence decision point.
The approved narrow seam is Communications.flush_pending_events(), called immediately
after roll_hustles and before any scripted day event. It consumes feed/news in original
order while preserving unrelated queued events and emits only distinct presentation
events; it does not re-enter gameplay or duplicate the producers.

Day14 rolls exactly two jitter values, each[-160,160), clamps40..world-40, creates
one500cash inheritance record and source toast/save. Existing pickup owner grants
the later flag/rep/receipt. No reward occurs while the pickup is pending placement.

Day30 unresolved driver is1330,1260,24x28, passive and stationary. Accept removes
the driver, sets busTaken, unlocks the_bus and emits the original ending receipt;
refuse removes it, sets busRefused and emits source toast/feed/save. Both revalidate
live geometry and token/state. The3D ending uses the existing ending presentation
mode while retaining source return-to-block/save semantics; no new-game reset.
Reload rehydrates an unresolved fired bus once. The source rehydrate comment is
incorrect: calling fireDay30Bus again really re-emits its toast/feed/save. Preserve
those effects, subject to current silence, without duplicate model actors.

Price Guy polls only playing day%3==0 and a different priceGuyDay stamp. Replace
the previous same-ID actor, stamp once, spawn2940,1860,26x32 and emit source feed.
Pay requires positive current cash and one-use capability; consume all cash once,
increment priceGuyVisits, mark priceResolved, unlock the_price_paid. Outcomes:
r<.20 knife; <.35 cash200; <.45 torch only when not owned in slot/locker; otherwise
r<.70 one rock; else nothing. An owned torch converts its interval to a rock.
Keep displaced crowbar via existing equipment owner. All outcomes set walk-off
speed1.4,targetX=-80,targetY=current y,wanderOff; Director owns actual movement.

Park cash: first playing night per day stamps parkNightCashDay before the<.30 roll;
success consumes a second roll for20+floor(r*21), then rounds by current
territoryCashMult. Fixed source center2510,1320 and ID cp_park_night_DAY; no immediate
save in source unless a physical deferral requires persistence under the adaptation.

Already spawned visitor/Price Guy/inheritance persistence retains source omissions:
normal source reload reconstructs base actors/piles and only explicitly rehydrates
the unresolved bus. Do not respawn a paid Price Guy or grant inheritance twice.
The pending queue exception below applies to effects that never acquired a real
physical entity; it is not permission to respawn all vanished source transients.

## Executed decision P14-PHYSICAL-DEFER

Approved by parent before code: natural time never stalls because a dynamic actor
or cash pickup lacks legal placement. Source RNG, event order and once flags commit
once. Retain a normalized saved pending-placement record containing kind, source ID,
source position and exact payload; retry using live geometry without repeating RNG,
toasts, rewards or day increments. No invisible model actor enters npcs, and no cash
becomes collectible before successful placement. Remove pending only after actual
spawn. No fallback relocates the player to the Block or crosses a wall invisibly.

Actor candidates use existing clear_placement with at most100px source recovery;
record source and accepted coordinates as presentation evidence. Cash candidates
require stage_cash_pickup(source_point,100px), which must return visible, accessible,
collision-clear source coordinates within the bound or null. Root owns this live
spatial implementation. Missing capability prevents installation; a current physical
refusal merely retains the pending entry. Recheck returned finite coordinates/bounds
and displacement. Same-ID Price Guy/campaign generation replacement supersedes its
older pending entry in the same way source replaces the old actor generation.

Approved live cash staging algorithm: treat the source coordinate as pickup center;
test it first, then at most16 deterministic angles on radii4,8,16,24,40,64,100px
clipped to the caller's bound (0..100px, with one final bounded ring if needed).
Require an actual player capsule clear at the candidate, a standing-eye-to-low-pickup
ray, and, for recovered points, a source-to-candidate ray at0.18m. This prevents
recovery across an occluding wall. Refuse invalid/obstructed candidates and return
null after the finite search; preserve the pending record. No player/model movement,
RNG, reward or source-state mutation occurs in staging. A source anchor inside a
solid may remain pending until its geometry changes; no invisible wall jump repairs it.

Save extension `dayPendingPlacements` is a normalized bounded array, maximum64.
Whitelist event kinds/IDs and payload schemas; reject functions, unknown identities,
invalid numbers/out-of-world positions, duplicates and oversized records. Reserve
scripted-event/guard space; queue capacity is an explicit diagnostic before a new
optional recurring roll, never silent removal of an existing pending effect. Root
must treat saturation as an unresolved integration fault, not parity success.
Attempts are throttled/bounded per active tick; restored records retry without a
new source RNG draw. Reset ephemeral scheduling on state epoch; preserve this queue.

## API and required composition

RockBottomDaySystem.new(state,spatial,progression,travel,campaign,communications,unix_ms)
uses weak references and the owner's p/s/npcs/cash_piles/RNG/events. Proposed methods:

```
ready() -> bool
install() -> bool
preflight_day(cause: String) -> bool
commit_day(cause: String) -> void
advance_sleep_day(kind: String) -> bool
sleep_at_block() -> Dictionary
tick_active(dt_ms: float) -> bool
tick_wall(monotonic_ms: float) -> bool
rehydrate() -> bool
replace_campaign_forces(plan: Dictionary) -> bool
can_replace_campaign_forces(prospective_kingdom: Dictionary, lifetime_pretenders: Variant) -> bool
discard_pending_campaign_clan(clan: String, persist: bool = false) -> bool
is_night() -> bool
actor_visible(body: Dictionary) -> bool
supports(actor_id: String) -> bool
open(actor_id: String) -> Dictionary
select(token: Variant, action_id: String) -> Dictionary
close() -> void
```

Use existing ActionSession/Inventory; strict60px current actor reach, real LOS,
living actor and kingdom interaction lock. Dynamic IDs resolve only through actual
source role/identity records. Keep normal nested/stale/epoch capability semantics.

Campaign prepares its daily state/actor synchronization before commit using its real
owner; failed capability preparation prevents paid sleep/installation. Physical
actors it cannot yet place follow the same saved deferral rule. No stub campaign or
feed object may be passed by production to make install succeed. Root will supply
final real callback adapter methods with the campaign/communications packets.

P13a composition uses the real Campaign.prepare_day result
`{ok,day,kingdom,pretenders_defeated,actors}`. Validate canonical Kingdom state,
integer day/count bounds, exact generation day, unique canonical actor IDs and
queue capacity before mutation. Commit the source max-reconciled pretender count to
both Kingdom and lifetime. replace_campaign_forces accepts current-day plans only,
and compares every field against Campaign's pure current-state canonical builder.
An empty/partial actor list or a valid ID paired with wrong known visuals/stats is
not a valid generation. JSON numeric representation differences are accepted only
when the finite numeric values are exactly equal; keys, array order and nonnumeric
types must match. No normalization silently repairs an untrusted generation.
Replacement uses the same removal/validated placement/defer implementation as natural dawn.
Restored queues and fresh/load/abort/victory refreshes therefore share one physical
spawn authority; no caller injects an invisible model actor or a second pending queue.

P13c approved seams: can_replace_campaign_forces is a pure current-day prospective
canonical-state/count/generation/capacity check used before fatal battle damage;
it never normalizes/mutates the live state, places actors, emits events or consumes
RNG. discard_pending_campaign_clan accepts only the three source clan IDs or throne,
removes only matching pending ordinary guards, and optionally requests one save.
The boss-start owner calls it after all three encounter bodies pass actual placement
and before its source save. It does not replace or clear other clans/event families.

Natural dawn schedules garbage callback at8s only after its<.5 draw, then scripted
events, then proud callback at12000+r*30000ms. Wall timers are ephemeral and tied to
the current state epoch. They use Runtime's monotonic wall input and dispatch into
the real communication/prop owner; DaySystem does not duplicate garbage loot/feed
or mom call actions. Shared Unix-ms is used only where Date.now is the source contract.
Existing Travel owns the separate delayed6s mom-pass toast.

## Evidence plan

Unchanged-source oracle executes actual weather/reset/fireDayEvents, rehydration,
Price Guy callbacks, Block/office/hideout sleep, and bounded updateWorld predicates.
Pin relevant source and generator hashes with deterministic --check. Cover exact
thresholds .25/.75,.3,.65/.88,.20/.35/.45/.70, all four days, repeated/missed flags,
six daily resets vs retained stamps, sleep reward ordering, bus accept/refuse/reload,
torch ownership/locker displacement, park roll/amount/multiplier and no-save quirks.

Godot tests compare source snapshots and prove real missing-dependency rejection,
callback cause/order/idempotence, no double resets/payments, stale/replaced menus,
pending physical refusal/restore/success without rerolls or phantom actors, malformed
pending normalization, bounds/capacity and shared Unix vs monotonic clocks. Root runs
all engine processes and adds real Runtime/scene/weather/departure evidence later.

## Runtime composition

FullRuntime composes one Campaign and Day owner against the same State, Progression, Travel, Communications and physical adapter. Travel sleep delegates through the bound Day owner. Campaign normalization is registered before restore; reconciliation and shared force refresh precede Day rehydration. Handled day_started receipts must not roll hustles or natural rent/pass twice. Active Price Guy/night-cash checks run after territory and before concession clocks/pickups; delayed callbacks use the existing monotonic wall input. Conditional actor menus resolve through the same physical closest-NPC scan. Night presentation follows source Mom/Pete/daytimeOnly visibility, while the unchanged-source interaction scan still includes those records. No second day counter, weather draw or guard population is introduced.
