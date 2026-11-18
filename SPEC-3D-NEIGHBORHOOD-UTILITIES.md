# SPEC — Neighborhood utilities P09d

Captured before code, 2026-11-18. Parent approved the bounded owner/API and the
source continuity/captured-offer decisions below. Active modular v22 is authority.
Root owns Runtime/Scene composition, physical input, presentation and central engines.

## Authority and API

`RockBottomNeighborhoodUtilities(GameState, spatial)` holds weak dependencies.
GameState p/s, inventory, seeded RNG and event queue remain the only authorities.
The module owns no shadow resource, world clock or save store. Spatial must expose
`can_use_zone(id)->bool`; entry requires actual inclusive source-zone membership
plus the existing physical valid-placement capability, never a fixed crate radius.

Public API:

- `ready()`, `reset_session(kind)` where kind is cold/fresh/restore, `close()`.
- `open_zone("block"|"market")->Dictionary`, `select(token,action)->Dictionary`.
  Standard menu envelope domain=`utilities`. Exact source Block options include
  smoke, optional Stripe package, sleep, cook, think, optional lottery, leave.
  Market options are change/song/trick/leave. Tokens are one-use and p/s-identity
  bound. Selection closes before effects. A stale token never closes a newer menu;
  unexpected epoch replacement rejects without changing replacement state.
- Block smoke/sleep/cook/package selection returns consumed `handoff` equal to
  `smoke`, `sleep`, `cooking`, `package` (plus `zone:"block"`) for Root's existing
  real owners. Utilities never implements those transactions or rewards.
- `press_squint()->Dictionary`, `release_squint()`,
  `tick_squint(dt_ms,held)->bool`, `cash_visible(pile)->bool`.
- `tick_zone_entries()->Array[String]`, `finish_world_step(dt_ms)->bool`.

Each admitted world step is finite, positive and <=50ms, matching source update's
maximum frame delta. Root normally supplies the existing fixed <=16.667ms steps.
`tick_squint` and zone entries require playing. `finish_world_step` intentionally
does not inspect the current mode: source updateWorld continues to its autosave
tail if an automatic dialogue/ending opened earlier in that already-admitted step.
The composer calls it exactly once per admitted world step, never from paused,
dialogue, cookmini or hit-pause scheduling. Invalid deltas make no partial mutation.

## Source order

References: `src/input/keyboard.js:107–125`; `src/core/update.js:54–171,286–405,883–885`;
`src/minigames/activities.js:286–419`; `src/render/frame.js:96–142`.

1. Source world admission rejects paused/modal/cookmini/hit-pause updates.
2. Movement, shakes/regen/police/recognition and player high/crash/combat timers.
3. Squint cooldown, held vision lifetime and brain drain (update159–171).
4. Day and existing ambient/prop systems; territory tick.
5. Twelve entry checks (305–373), then bench/conditional-day actors, phone,
   dog discomfort, concession clocks, companion lifecycle and later source systems.
6. Actor/cash/crown/package/projectile/boss/rank sequence remains Root's existing
   source composition; this packet does not move or duplicate any of it.
7. Autosave at source tail (883–885), even after a same-update modal transition.

Underpass is an independent first check. The other eleven are one ordered
`else-if` chain: trainyard, park, skidrow, oldschool, warehouse_row, canal,
the_lot, blue_tarp_court, cart_cavalry_keep, copper_choir_yard, throne_ditch.
Therefore at most two flags can fire in one step if authored zones overlap.
Each branch sets its exact flag, posts the canonical feed text/handle, emits the
canonical toast/duration, then requests save. No proximity/LOS/intro gate is added
to traversal. Existing saved flags suppress replays and unlock Travel destinations.

Autosave uses `(s.autoSaveT || 0)+dt`, fires only at `>45000`, resets to zero,
and discards overshoot. It requests the existing save queue, never performs IO.

## Squint and visibility

Playing F keydown is blocked by stun just like other source action input. If
cooldown>0 or brain<=0, activation fails; brain<=0 also emits the source1500ms
receipt. Otherwise activation requires tweakerT exactly0, sets3000/6000ms and
subtracts5 brain with floor0. Holding does not itself reissue keydown.
Cooldown decrements only while positive, without clamp. If held, vision>0 and
brain>0, subtract the full step from vision and drain0.002 brain/ms, floor0. At
brain0 clear vision and emit the1800ms exhaustion receipt. If not held, clear
vision on the next active step, not at keyup itself. Modal/focus release does not
run paused clocks. A negative vision remainder stays negative while held; keyup
followed by an active step resets0. No invented automatic reactivation.

`release_squint` clears only source held-input membership (`s.keys` contains `f`);
`tick_squint` receives the real held snapshot. Root releases its physical input too.
Cold/new owner starts from canonical defaults. The source starts both fresh and
loaded games with `releaseAllInput()` (start.js19), while preserving existing
tweakerT/tweakerCdT/autoSaveT. Explicit `reset_session(fresh|restore)` copies those
three scalar fields from the owner's old s identity into new s, clears held input,
and invalidates menus. They remain unsaved: closing/relaunching starts cold. No
other old state survives through this seam. Forced unannounced replacement rejects.

Cash visibility is exactly: uncollected and (vision>0 OR strict center-distance
<60px OR intro OR truthy tool OR truthy equip). This does not collect cash, change
placement, grant reward, add LOS exceptions or change the14px collection radius.
Root adapts visible mesh treatment, including source tool/equipment distinctions.

## Menus, effects and compatibility ledger

Open is a zone verb after higher-priority interaction misses; kingdom combat
blocks it. No new HP/stun/ordinary-boss guard is added to callbacks. Root gates
physical E by stun. Modal choices capture source day/night and offered options;
there is no per-choice ray/zone recheck. Market night is `<.25 or >.75`; equality
is day. Enabled choices are captured; one-use capability is required to execute.

- Think: one uniform draw selects one of six exact thoughts; only the patience
  line adds1cred.4000ms toast. No save, cooldown, daily cap, feed or reward cap.
- Lottery: offered iff an inventory record has id=lottery. Its accepted callback
  removes ALL matching records, regardless q. One draw: <.01 pays500,4500ms
  toast, coin, exact news/feed; <.15 consumes another draw for5+floor(r*15),
  2500ms toast then coin; otherwise2200ms loss. Every scratch saves.
- Change: one roll, captured night modifier−.2. First threshold .45+modifier,
  then .65+modifier, then .85. First outcome consumes another roll for1–4 cash,
  coin, bigPan+1 only at4, then toast. Next outcome gives1cash/toast without coin.
  Advice emits toast then brain=max(0,brain−1). Last gives1cred after toast.
- Song: one draw <.4 gives3cash/toast, otherwise only toast.
- Trick: one draw <.25 gives8cash+1cred/toast; otherwise wanted=min(3,wanted+1)
  and toast. None of the market outcomes saves, grants intro cash, posts feed,
  applies faction reputation, or has an invented daily cap.

Approved source quirks (register proposals for Root when integrated):
1. Preserve negative squint timer overshoot and strict autosave boundary/reset.
2. Preserve all-ticket consumption and captured lottery eligibility: a valid
   offered callback still rolls once if tickets were removed after menu opening.
   One-use/epoch safety prevents stale/replayed grants, not this source behavior.
3. Preserve advertised `$1–5` versus actual1–4 change and small lottery5–19.
4. Preserve same-session fresh/load continuity of the three unsaved timers;
   input clears and first active non-held tick ends vision. No new epoch-reset
   exception or persisted clock schema is introduced.
5. The unchanged-source oracle also characterizes activation with0<brain<=5:
   activation floors brain0, then held ticking does not enter the brain>0 drain
   branch, so vision stays3000 until release plus an active step. Preserve this
   source quirk explicitly; do not silently invent expiry while brain is empty.

Successful local think/scratch/market actions emit one presentation-only interact
gesture after source effects. Delegations/leave/failed actions emit no speculative
gesture; the real destination owner acknowledges its accepted transaction.

## Evidence and boundary

Unchanged-source oracle executes real Block/panhandle callbacks, real keyboard
listeners, real updateWorld clock/zone branches and actual save/load/start paths.
Projected clock fixtures isolate unrelated systems without rewriting the tested
arithmetic. Tests compare source menus/resources/RNG draws/receipts/feed/news/save
counts and timer edge behavior; property tests cover source-zone bounds, physical
entry refusal, stale/replayed/cross-epoch sessions, missing ticket after open,
pause/hold/release, strict autosave, continuity, cash visibility and weak ownership.
Fixtures complete-count guards prevent skipped function bodies reporting PASS.

No Runtime/Scene/Memory/Core edits or engine runs belong to this packet. Model
READY is not scene/native/Web parity; Root must wire every seam at the listed
source positions, validate its active-step continuation and real F/input behavior,
and update the manifest/evidence before marking integrated.


## Live Runtime/Scene connection

One Utilities owner is composed over Runtime State/spatial. It is rebound after fresh/restore,
closed with every other action capability, and receives the active tick stages specified above.
Source Block actions hand off through their already consumed option to Memory smoke, Day sleep,
Cooking or Quest package. Market is a real zone capability with actual capsule clearance.
Scene F press/release owns a held-input latch; menus/focus/epoch reset clear that latch, and
Runtime advances source squint only on admitted active steps. The same cash_visible projection
controls actual cash meshes. Model visibility does not alter pickup availability or hidden RNG.
No extra tutorial or inventory-use action is introduced.
