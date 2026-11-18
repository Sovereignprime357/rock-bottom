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
- `smoke(spot_id)` rechecks mode, full MemoryLoop legality and the adapter's live target access;
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
