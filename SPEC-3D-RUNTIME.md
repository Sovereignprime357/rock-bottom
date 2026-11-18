# SPEC — Full-model composition and first playable chain

P03c/P06 integration foundation,2026-11-18, root. This is a composition contract under the full-port
spec, not authorization to call missing activities complete. `full_runtime.gd` composes one
GameState, MemoryLoop, Progression, Inventory and CoreVendors. Later actor/combat/day/activity
modules join the same owner. No replacement player/resource/save dictionaries exist in views.

## API and responsibilities

- `new(spatial_adapter, boss_adapter=null)`, public `state` and read-only `p/s` getters; subsystem
  handles remain available for domain composition. Weak adapter references prevent retain cycles.
- `fresh`, `restore(snapshot)`, `snapshot` invalidate open action capabilities and clear queued
  presentation from the previous epoch. Successful restore normalizes all registered domains.
  Mode transitions remain explicit and close menus. Scene controls capture/focus and physical
  relocation; the model emits placement/reset events.
- `advance(seconds,context)` rejects nonfinite/negative/>240s input atomically, otherwise advances
  only playing mode. It subdivides into <=1/60s steps for body/status/day order, memory visits and
  clocks, territory and800ms hustle checks; one simulation time authority. Hitpause consumes
  its own active interval before world work. Context provides actual movement/sprint and optional
  at_block, plus monotonic_ms for presentation/greeting/wall-time adapters. Paused world cannot
  farm resources. Later wall-clock combat callbacks remain independently driven while paused.
- `open_vendor(id)`, `select_vendor(token,action)`, `close_dialogue` use the existing live spatial
  capability/token boundary. State replacements invalidate tokens even if values happen to match.
- `smoke(spot_id)` rechecks mode, full MemoryLoop legality and the adapter's live zone placement;
  `craft_hitter`/`use_hitter` are location-free pocket commands gated by mode/stun. They cannot
  bypass higher-priority scene interaction resolution. Modal wrappers will use one-use tokens
  before exposing these internal domain commands to buttons.
- `collect_cash(id)` validates live source pile, strict14px radius and authoritative clear reach.
  It marks collection once before applying cash/tool/equipment outcome. Canonical torch ownership
  includes Pete's locker; slot displacement uses GameState. All normal/intro/inheritance pickups
  preserve source counters, credit, faction and presentation. Auto-collect scans nearby piles
  only in active world steps; physical target visibility stays in the adapter.
- Intro remember completes at earned10 or held10 while intro active; Tony open and first smoke
  retain their existing domain handlers. The intro-completed event rolls hustles/routes once and
  publishes the original news/feed. Day-start event rolls daily hustles; weather, rent, special
  days and other dawn obligations remain the upcoming day-system packet.
- `drain_events()` first resolves queued domain consequences, then returns presentation events
  in order with one coalesced save request containing a final committed snapshot. That snapshot
  includes newly rolled routes/rewards, avoiding early achievement/quest writes racing later
  state. No IO in the model. Scene's serialized save queue must await writes and surface errors.

## Acceptance

Use real composed state/services with an explicit spatial test adapter: fresh resources, guaranteed
intro pile -> remember quest -> Tony open/buy -> Block smoke -> route/hustles and exact18s/8s
boundary, full save/restore and no duplicate rewards. Blocked LOS/out-of-range collection and
vendor menus fail, pause/focus time cannot grant resources, old tokens reject after new/load,
multiple save requests yield one final snapshot, tool drops do not duplicate locker ownership.
All claims remain model-level until the full generated world/controller is activated and tested.

## P03d first-person movement boundary

`advance` optionally accepts a finite `input_vector:Vector2` in source/world horizontal axes and
`sprinting:bool`. Reject malformed movement before any mutation. Clamp analog length to one;
derive source speed from `p.speed`, high1.8, crash0.5, slow0.5 and sprint1.7. Movement uses
source pixels per16ms; base2.2 maps to5.5m/s. A stun gates movement until its active countdown
expires. The spatial adapter casts a detached body and returns the actual position; only Runtime
commits it. Missing/malformed physical results fail closed. Source bounds apply before the cast,
never after it (post-cast clamping could cross a wall). One fixed step cannot tunnel through a
wall; hitpause/pause freeze movement too. Shake exertion follows intended movement as in source,
while visual hand gait uses measured displacement. Tests cover normal/sprint/high/crash/slow,
diagonal input, stun, collision denial, world bounds and invalid input atomicity. Existing model
callers without `input_vector` retain their explicit movement context and do not move the player.

## Zone-verb correction before scene activation

Source `tryInteract` answers Block/concession menus anywhere within the appropriate zone after
higher-priority doors/NPCs/props miss. The initial composition incorrectly imposed2.3m reach to
the map's smoke marker. Remove that extra walk: markers are guidance, not interaction-distance
gates. `can_use_zone(id)` checks actual current player placement against solids; MemoryLoop
checks the exact source zone/venue and current conditions. No line of sight to the marker is
required. Object interactions still require their real reach/LOS. The forthcoming resolver must
preserve priority and both menu-open/selection checks, with zone commands last and hitter pockets
last of all. Test a clear position inside the Block well beyond marker reach, an out-of-zone
position and a player embedded in a wall. This corrects source drift rather than adding a venue.

## Composed actors and travel

Runtime owns Travel, and may enable Combat/ActorDirector/Bosses once the live physics adapter is
available. `enable_actor_simulation()` validates required physics methods and reconciles the
restored boss state before enabling actor ticks. Pure state tests may leave this production layer
disabled; the full scene must explicitly enable it and bind every visual before play. Runtime
forwards special death/start requests to Bosses; campaign and robbery stay explicit unimplemented
dependencies until their owners are bound. Do not turn a missing robber dependency into a no-op
function that causes Director to treat it as supported.

`advance_wall(monotonic_ms)` has an independent clock that does not reset on fresh/restore and
runs in every mode. It ticks Combat/Boss wall callbacks and Travel's real-time delays, including
long suspended-frame gaps in bounded240s chunks. Active `advance` alone ticks status/combo,
police, actor decisions, projectiles and boss phases, once per fixed step, behind hitpause. It
does not fake wall time from accumulated active steps. No domain owns a second player timer.

Travel resets its ephemeral menu/delay/cart state on fresh and preserves only the previous cart
coordinates on same-process restore. Runtime cancels pending rides synchronously on death/arrest
before any wall callbacks run. Natural dawn invokes the travel rent/pass hook exactly once;
sleep/day causes and full day-system integration remain pending until the next packet supplies
the authoritative weather/event/reset path. Missing rollover sleep adapter must reject before
any transaction. Zone and physical relocation events invalidate relevant interaction tokens.

## Resident composition

Runtime owns the verified ResidentDialogue packet with the same state, spatial adapter, memory,
combat and boss instances. Core vendors, travel and residents form one modal domain: opening
any one closes the other two; pause, fresh, restore, death and arrest invalidate all capabilities.
Scene resolver exposes supported real resident IDs (including transformed priest), and returns
their exact source menus. Nested resident responses retain their new one-use token. Missing
resident packets remain tracked; there is no generic replacement dialogue.

QuestDialogue joins the same modal domain and is constructed before any restore so crownPickup
normalization is registered. Its actual source ordering is Conductor wait -> cash -> crown ->
package delivery -> Pete night closure -> actor AI -> projectiles -> boss phases -> ranks.
The current fixed step finishes after delivery sets dialogue; subsequent fixed steps pause.
Auto-delivery emits a `dialogue_requested` envelope consumed by the same scene menu presenter.
Block package opening is a zone command, with fresh physical and package-state validation.
The crown's exact source point has strict18px reach and real low-object LOS; never move it merely
to make a scene test pass. Actor visual transforms remain presentation and cannot award quests.
# Restore preflight and added domain composition, 2026-11-18

A full save with a live Fallen Priest requires an actual clear physical
placement before changing the current session. Runtime decodes an isolated
candidate and runs the real Boss/Combat normalization against the same spatial
adapter synchronously. Failure discards that candidate, preserving the live
player, state, RNG, projectiles, active menu capabilities and pending events.
The synchronous successful preflight precedes normal commit/epoch invalidation;
the view and physics world cannot advance between the two operations.

Street, Robbery and untimed Rhythm share the existing GameState. A returned
Street menu may transfer to `activities` or `travel`; the explicit domain owns
subsequent callbacks. Closing/replacing menus, fresh/load and authoritative
death/arrest cancel Rhythm, without a refund or guessed reward.
