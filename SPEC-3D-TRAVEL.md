# SPEC — Hideouts, stash, cart and bus travel

P12a contract, captured 2026-11-18 before generation and approved by root. Subordinate to
`SPEC-3D-FULL-PORT.md`, `SPEC-3D-WORLD-PARITY.md` and VIBE. Root approved the shared
sleep-day adapter, exact bus destination/refund and bounded cart-drop adaptations.
This bounded model contract is not an implementation or integration completion claim.

## Source scope and exact inventory

The unchanged active ES modules are authoritative. There are two owned hideout
doors, one shared stash, one rideable cart, six decorative cart husks, and eighteen
ordinary bus destinations. The separate day-30 bus is an ending, not fast travel.

| Source | Contracts owned or consumed by this packet |
|---|---|
| `src/systems/daily_hideouts.js:233` | `hideoutOwned`, `tryEnterHideout`, `openHideout`, `openHideoutChest`; two doors from `HIDEOUT_DOORS` |
| `src/systems/daily_hideouts.js:211` | `openOfficeCot`, `sleepAtOffice`; office ownership/upgrades remain campaign authority |
| `src/dialogue/neighborhood_a.js:65` | `yuriDialogue` shed purchase is already implemented by CoreVendors; do not duplicate it |
| `src/dialogue/neighborhood_a.js:584` | mom couch purchase, spiritual gate and rent stamp |
| `src/dialogue/neighborhood_b.js:348` | `bigguDialogue` cart trade |
| `src/dialogue/vendors_places.js:21` | `hasBusPass`, `consumeBusPass`, `giveBusPass`, `combatActive`, `visitedZonesForBus`, `openBusPassMenu`; pass sale inside `pinkyDialogue` |
| `src/dialogue/vendors_places.js:581` | all eighteen exact `BUS_ZONE_TARGETS`, six per page |
| `src/systems/interactions.js:126` | unique cart mount/dismount; earlier interaction targets retain precedence |
| `src/data/props.js:9` | `RIDEABLE_CART_SPAWN`, `rideableCart`, `resetRideableCart` |
| `src/core/runtime_ui.js:33` | `applyEquipStats` remains GameState authority |
| `src/core/update.js:174` | natural dawn order, mom pass and couch rent |
| `src/core/audio_save.js:19` | mounted state, hideout flags and shared stash save/load; cart position is absent |
| `src/core/start.js:57` | fresh-game cart reset; loaded games do not reset the same-process cart |
| `src/systems/combat.js:164`, `src/systems/npc_ai.js:487` | mounted damage and roadkill are existing Combat/ActorDirector responsibilities |

No invented item, NPC, destination, vehicle health, storage capacity or item-transfer
menu. The stash has an `items` array in saved data, but its live source menu only
transfers rocks, copper and cash. Preserve items without adding unsupported actions.

## Economy and clock invariants

- Shed acquisition: scrap reputation >=5, unowned, $150; +2 scrap. Existing
  CoreVendors owns this transaction. Shed door is (520,200,24,32).
- Mom couch acquisition: spiritual >=10, unowned, $30; stamp `momRentDay` to
  current day, +2 spiritual. Door is (1230,1180,24,32).
- Door reach is strictly less than40 source pixels between player and door centers.
  The office uses its existing44px door reach and campaign ownership/upgrades.
- Stash has six transfer actions: deposit/withdraw one rock, one pure copper or
  $10. Shared across shed, couch and the installed office locker. Each operation
  checks current balances, commits both sides once, and requests a save. Soap rock
  bookkeeping is not changed by the source chest and is not silently repaired here.
- Shed rest adds8hp, couch rest12hp, both reduce wanted by1, clamped. The label says
  thirty minutes, but **no game time passes**. Do not simulate thirty minutes.
- Sleep sets `dayTime` to0.3. Only prior values strictly greater than0.3 increment
  the day; exactly0.3 or earlier stays on the same day. Shed grants50hp/25brain,
  couch60hp/30brain, both +15shakes, -2wanted and +1 matching faction, all clamped.
- Source sleep runs weather, daily counters, office/kingdom day synchronization,
  hustle roll and scripted day events on rollover. It does **not** execute ordinary
  dawn's mom pass/rent, news/feed, garbage truck or proud-call scheduling. Hideout
  sleep does not unlock `tuesday_again`. Preserve these asymmetries explicitly.
- Installed office cot rest adds10hp, or18hp and5brain with generator; -1wanted,
  no time. Office sleep grants55hp,25brain (+5 with generator),+15shakes,-2wanted.
  It adds no faction and, unlike hideout sleep, unlocks `tuesday_again` on rollover
  to day>=7. No office menu, upgrades or progression logic is duplicated here.
- Natural dawn: spiritual>=10 stamps `momBusPassDay` once/day even if already
  carrying a pass; otherwise grants one. Then owned couch charges $30 and stamps
  `momRentDay`; insufficient cash evicts and reduces spiritual by3. Stash survives
  eviction, death and arrest. Sleep deliberately does not invoke this hook.
- Mom apartment phone sets `phoneT=90000+random*150000`ms; no save request in source.

## Ordinary bus

Pinky sells one pass for fixed $20, without charisma/vendor-price adjustment and
without stacking. The first matching inventory record is consumed regardless of
its `q`. A pass may be purchased after riding, but riding is once per day via
`busPassUsedDay`. Carrying an existing pass prevents sale/grant, not other trades.

Destination order and coordinates come directly from `BUS_ZONE_TARGETS`: block,
market, scrap, alley, church, projects (always known); underpass, trainyard, park,
skidrow, oldschool, warehouse_row, canal, the_lot, blue_tarp_court,
cart_cavalry_keep, copper_choir_yard and throne_ditch (exact entry flags). The model
uses all eighteen records and six per page, rechecking flags/current zone per action.
Current-zone selection follows source inclusive bounds and greatest absolute
faction-reputation precedence on overlaps, preserving first array order on ties.

Wanted>0 or a living non-pet hostile/aggro actor strictly within220px blocks riding.
The current zone is disabled. Recheck these conditions when a token is consumed;
source stale menu closures are not permission to bypass live gates in3D.

Successful selection removes one pass and stamps the current day immediately;
after380 wall-clock milliseconds, source relocation clamps target center to20px
world margins, clears territory heat/greeted/zone tracking, flashes and saves. It
does not intentionally advance day/time, clear wanted, change mounted state, or
reset high/crash timers. Runtime continues ordinary simulation during the delay.

3D safety proposal: validate the exact destination capsule before consuming and
again before arrival. No nearest-spawn relocation for authored bus destinations.
If the destination becomes invalid during the380ms delay, do not teleport; restore
the exact consumed record at its former index and restore the prior use-day stamp
only if the same state epoch and this pending travel still own that stamp. A load,
new game or death cancels pending relocation. Cancellation never restores resources
into a replacement state. This compensation behavior is an explicit adaptation to
live3D collision, not a source behavior claim. Only one pending ride is permitted.

## Cart and physical adaptation proposal

Mounting the unique source prop requires strict36px distance from player center to
the cart's source x/y (not cart center), plus current visibility. Mount grants
`cart_baron`. THE BIG GUY trade costs5 pure copper and mounts immediately; source
allows repeated purchases even while mounted and grants no cart achievement there.

GameState alone recalculates equipment. Mounted base maxHP is110 rather than100;
mounting does not heal. Speed becomes `min(equippedBase*1.7,equippedBase+1.5)`;
dismount clamps current HP to the new maximum. There is no cart damage/health pool.
Source cart damage multiplier1.3 and roadkill14/600ms are not reimplemented here.

The exact source dismount location is player top-left +(4,8), which overlaps the
player body. Proposal: the scene adapter finds a clear, visible parked placement
within50px/2m of that preferred point, excluding overlap with the player and other
solids. Commit the returned source position to the one mutable cart record only
after validation; refuse dismount without mutation if no placement exists. A
mounted cart is attached art with its parked collider disabled. A parked cart has
matching collision and a live mutable interaction anchor. No duplicate prop or
invisible blocker remains at the old location. This physical placement deviation
requires root approval; speed, combat, costs and cart identity remain exact.

Cart x/y are session data, not durable source save fields. Fresh game resets to
(1000,1600). Cold load starts with that source prop position; same-process load
retains the current cart x/y while loading the saved mounted flag. Pending menus,
bus timers and capabilities are never saved. Root retains one authoritative cart
record in `GameState.s.travelRuntime`, excluded from the existing save allowlist.

## Proposed API and integration seams

`RockBottomTravel extends RefCounted` in `game3d/scripts/travel_system.gd`:

```
_init(owner: RefCounted, spatial_adapter: Object, day_adapter: Object = null)
open(service: String, page: int = 0) -> Dictionary
select(token: Variant, action: String) -> Dictionary
interact_cart() -> Dictionary
tick_real(milliseconds: float) -> void
on_natural_dawn() -> void
reset_session(reason: String, previous_cart: Dictionary = {}) -> void
cancel_travel(reason: String) -> void
cart_record() -> Dictionary
has_bus_pass() -> bool
buy_pinky_pass() -> Dictionary
```

`open` supports bus/Pinky pass submenu, mom couch acquisition, biggu cart trade,
owned `hideout:mom`, `hideout:scrap`, their chest submenus, and separately gated
office cot/chest submenus. It returns title/text/options and a one-use ActionSession
token using the existing `{id,label,enabled,reason}` option schema. Page/navigation
and chest reopen consume old tokens and create new capabilities. Public mutation
methods never accept a caller-supplied boolean authorization. NPC vendor dialogue
routing and the existing Yuri shed purchase remain root-owned integrations.

The full Pinky menu and the compatibility pass submenu both delegate to
`buy_pinky_pass`. It rechecks current Pinky reach/LOS, mode, pending travel,
kingdom lock, source street-hated refusal, absence of a pass and at least$20 before
the existing single item/cash/toast/sound/save transaction. It does not open another
menu or manufacture a session; the caller's existing ActionSession owns the click.
The public transaction does not apply charisma pricing or replay any vendor visit.

The model uses weak references, existing Inventory helpers and owner p/s dictionaries.
Every selection rechecks authoritative mode/death lifecycle, ownership, current resources, current
reputation, destination gates and a new spatial answer. Fresh/restore epochs and
replayed tokens are rejected. No rendering, filesystem, save implementation or
second clock/resource owner is introduced. Emit existing toast/feed/sound/save
events, plus cart/relocation presentation events after committed mutations.

Source correction P12-LIFECYCLE: raw `hp <= 0` and `stunT` are not travel eligibility
guards. Source food callbacks can leave negative HP in playing mode without invoking
death; that player may still buy a pass, ride, use a cart, or recover at an owned
hideout. Pending rides continue through that raw state. Actual death/arrest events
still synchronously cancel and refund the same-epoch ride; explicit dead mode is a
fallback cancellation guard. Range/LOS, kingdom/combat, pass/day, ownership and
physical placement checks remain required. Tests cover both raw state and genuine
lifecycle cancellation, so recovery HP cannot be mistaken for proof no death occurred.

Required spatial adapter methods (root owns adapter implementation):

```
can_reach_target(id: String) -> bool
clear_placement(body: Dictionary) -> Vector2 or null
find_cart_drop(preferred_top_left: Vector2, maximum_distance_px: float) -> Vector2 or null
```

Bus validation calls existing `clear_placement` but accepts only the exact requested
top-left point; recovery candidates are rejected. Drop adapter must guarantee
bounded distance, live collision clearance, line of sight and no player overlap.
Root must update the cart's scene/collider/interaction position from the authority.

Day dependency proposal: `day_adapter.advance_sleep_day(kind:String)->bool` performs
the same authoritative day increment/reset pipeline as ordinary dawn, marked as
`hideout_sleep` or `office_sleep`, without ordinary-only mom rent/pass effects.
It must finish weather/hustle/scripted-event consequences synchronously before save
capture. Missing adapter rejects a rollover sleep before any HP/resource/time change.
Non-rollover sleep needs no day increment. This avoids duplicating GameState's clock
and provides a cause distinction missing from the current `day_started` payload.
Root may replace this adapter with an approved public GameState day method before
implementation; travel must not independently recreate the full daily pipeline.

Root Runtime integration calls `on_natural_dawn` exactly once for an ordinary dawn
and `tick_real` with bounded wall-time deltas including paused/modal states, matching
the source setTimeout's timing. Pending travel remains ephemeral, epoch-checked,
and canceled on death/new/load. Explicit manual close does not cancel a ride already
purchased. All queued gameplay events resolve before a coalesced save snapshot.
Runtime calls `cancel_travel("death")` / `cancel_travel("arrest")` while resolving
those events: the core immediately restores positive HP, so a later HP poll cannot
identify the lifecycle transition. Same-epoch cancellation compensates the reserved
pass/use stamp; fresh/restore cancellation cannot refund into a replacement state.

## Independent verification plan

Office handoff follow-up: all six shared-chest option labels retain the source dynamic
stock count or exact empty/short wording (daily_hideouts.js292–303), including the two
office service aliases. Source chest transfer receipts, cot text and powered/unpowered
rest/sleep receipts are compared verbatim in18 additional UI paths. Preserve the shipped
powered-cot sleep label saying+25brain although the generator raises the actual grant to30.
The Scene displays the source choices only: cot/chest back links need no extra generic
leave choice; Escape remains available. Chest/cot back returns the existing office
navigation envelope, with Runtime/Scene responsible for reopening the real office owner.

A rejected stale Travel token must leave a newer active service/token intact. Clear the
captured service only after successful consumption, or on a non-stale capability failure;
otherwise a stale action could strand the newer valid menu with unknown_service. No
economy, day, cart, geometry, or source action-ID contract changes in this follow-up.

`tools/3d-travel-oracle.mjs` runs unchanged source functions and actual menu callbacks
under the seeded fixed-clock harness. Output is
`game3d/tests/fixtures/travel_reference.json`; `--check` compares deterministic bytes,
source hashes, generator hash and exact counts. Functions are executed, not copied
into the fixture. Timers are explicitly fired at their registered380ms boundary.

Fixture coverage: all18 destinations/flags/pages; combat strict220px boundary and
dead/pet exclusions; same-zone overlap precedence; fixed20 price under charisma;
first-record pass consumption and duplicate grants; stash six actions and partial
balances; both rest variants; sleep before/at/after0.3, day7 differences and all
stat clamps; office generator variants; natural-dawn pass-before-rent, eviction,
existing-pass day stamp; exact cart mount36px boundary, source dismount position,
equipment speed/HP, repeated biggu purchase and achievement distinction; fresh and
same-process save/load cart behavior. Stash item preservation and durable flags are
checked across death/save/restore using existing GameState semantics.

`test_travel.gd` compares those source snapshots and adds adversarial live-adapter
tests: stale/replayed tokens, moving behind a wall after menu open, ownership loss,
malformed/unknown actions, changed resources, blocked bus arrival/refund, replaced
state mid-delay, duplicate tick/selection, unavailable day adapter, invalid drop
position, and colliders/anchors synchronized by root integration. Model tests do
not claim actual scene integration or visual evidence. Root runs Godot serially.

## Explicitly separate packets

Day3/7/14 actors/events, day30 bus accept/refuse/ending/rehydration, full office
campaign menus, generic NPC dialogue, public phones/ambient call scheduling and
world cart scene mutation are integrations or later bounded packets. Their source
contracts are referenced here but are not silently claimed by this model packet.
Do not mark travel parity complete until production menu/spatial/day/save wiring
and actual native/Web journeys have been exercised.
