# SPEC — Possum and scrap-yard dog companions P06c

Status: approved bounded implementation packet; Runtime/scene integration is separate. This
packet owns four source handlers (`possum`, `pet_possum`, `scrap_dog`,
`freed_dog_follower`) and their lifecycle, not the dumpster minigame or another combat engine.

## Source and authority

`src/dialogue/neighborhood_a.js:114–215,602–631,726–743` supplies the dog conversations,
free/return actions and16 authored prophecies. `communications.js:42–62` supplies the pet
spawn/release transaction; the3D companion owner performs that transaction while the existing
Communications owner remains the only feed/news authority. `update.js:451–507` supplies cop
discomfort, return timers and tail wag; `npc_ai.js:58–85` supplies collision-adapted following
and the existing-pile reveal. Combat retains all HP, attacks and actual kill rewards.

`RockBottomCompanions.new(host,spatial,communications,shared_lockpick,director=null)` uses weak
references for dependencies. Public methods: `ready`, `supports`, `open`, `select`, `close`,
`is_active`, `tick_world(dt_ms)`, `advance_wall(monotonic_ms)`,
`tick_possum_reveal(actor,dt_ms)`, `spawn_pet_possum`, and `pending_snapshot` (detached QA data).
Source pixels/ms remain model units. Active steps are finite0<dt<=50ms. Wall time is finite,
nonnegative and monotonic across epochs; fresh/restore discards pending work without rewinding
the clock. Death/arrest does not replace an epoch or cancel a source wall callback.

NPC menus require a live matching actor, strict center distance<60px, current physical
`can_reach_target(id)`, playing/dialogue mode and no kingdom battle. Ordinary bosses, raw
nonpositive HP and stun add no gates. Each choice consumes an ActionSession before effects.
Normal menu selections recheck live actor/reach/resources. The nested lockpick is a captured
modal with epoch/owner identity checks, no new per-pin geometry check. Missing dependencies
refuse before mutation or RNG. Text/choices/effects are the literal source, including fed-dog
petting giving repeatable+1cred/save and follower petting+1cred without a save.

Future dumpster access uses `set_dumpster_authority(owner)` (weak) and
`open_from_dumpster(ticket)`. The real dumpster owner must expose
`consume_possum_handoff(ticket)->bool`, consume an epoch-bound one-use transaction capability,
and call this only from its accepted possum outcome. No outdoor possum/reach is required.
Until that owner exists this branch refuses; this packet does not claim dumpster parity.

## Shared four-pin puzzle

`RockBottomLockpick` is the sole four-pin implementation. One instance can be injected into
Heists and Companions; Heists' optional constructor fallback preserves standalone callers.
`begin(context)`, `choose(context,pin)`, `snapshot(context)`, `active(context)` and
`cancel(context)` own only puzzle state and source wrong/correct pin effects. Context and
p/s epoch bind each puzzle. Beginning another context revokes the prior one. Callers own
ActionSessions, page construction, success/failure effects and mode changes. Give-up invokes
the caller's failure; Escape merely cancels. The existing HEIST-V8-SORT schedule remains
unchanged, including equality handling, and all existing98 sort-stream fixtures must pass.

Dog lockpick success marks the original dog dead/unchained, quest freed/done/unavailable,
sets first-return60,000+random*120,000ms, glassBreak, LIBERATOR, exact toast/feed,
scrap+3/spiritual-1 and save. Give-up only emits the authored failure toast. No tool is needed.
Food uses Inventory.remove_first_record, including one virtual unit of migrated food.

## Lifecycle, order and physical placement

Runtime order is Director.tick_dog_discomfort → Memory.tick → Companions.tick_world, then
the later Director.tick. Director owns follow motion (top-left distance>48 approach at source
speed;0<distance<24 retreat0.4px/16ms) and preserves its finite exact-overlap repair. Configured
Director does not repeat discomfort. Existing standalone Director callers retain their prior
pre-step call until composition installs Companions. The shipped cop-field/literal-ID predicate
is unchanged. A follower at its final step contributes the aura before leaving; a new return
does not contribute until the next step. Memory still requires a positive follow timer AND a
live dog to permit underpass smoking.

Freed dog: absent timer decrements until<=0; source offsets are (random-.5)*120 and80+random*40
from the player. On successful placement the follow window is60,000ms. Expiry marks it departed
without kill rewards and schedules90,000+random*180,000ms. A killed follower resumes the existing
absence timer, exactly as source. First successful return sets freedDogFirstReturn and emits
the one-time toast/feed. Chained living dog tailWag rises bydt*.003 within strict100px, falls by
dt*.002 otherwise, clamped0..1. Presentation can consume that value without owning its timer.

The fifth+ prophecy schedules spawn after2,200 wall ms when hasPossum is false. Identical pending
spawn callbacks may coalesce: after the first success every later source callback is a no-op.
No mode gate is added at the deadline. Candidate pet body is source x-30,y+12,28x24,HP30,speed1.6;
follower body is26x20,HP40,speed1.4. Candidate RNG/coordinates are captured once. Use physical
clear_placement(detached_body)->Vector2-or-null, finite, inside bounds and within100px of its
candidate. Failed placement retains at most one request per companion; retries never reroll.
Ownership/receipts commit only when the body can be placed. Deferred dog follow time starts on
placement. Retry work is bounded (at most three placement attempts per active step).

Possum reveal remains30,000+random*15,000ms, then a random uncollected EXISTING cash-pile record,
then player x+(random-.5)*60,y+40+random*30. It never creates money or changes the selected
record's ID/value/tool/equipment/collected status. `stage_cash_pickup(point,100)` must return a
finite in-bounds position within100px or failure. At most one chosen reveal is retained in the
current epoch until placed or that exact pile is collected/removed. Further reveal countdown
pauses while blocked, then resumes its already-drawn timer. Reveal receipts occur only on
placement. Source cosmetic particle samples remain excluded under the approved P07 RNG split.

Release/timed departure matches source immediate removal from active play, not a fabricated
walk-to-exit quest. Retain a dead record with departed=true and emit actor_departed; scene must
hide departed records rather than animate them as a combat death. Ordinary combat kills retain
their usual death presentation/rewards. New successful dog return replaces the prior dead row
and calls Director.reset_actor(id); actor_spawned indicates replacement for scene/nav reset.

## Explicit approved compatibility ledger

* COMPANION-LOCAL: all16 authored fallback prophecies. Source selects fallback before its
  optional1800ms window.claude.complete override; no external AI is installed or required here.
  Each prophecy draws line, increments counter, awards ten-prophecy achievement, schedules
  eligible spawn, then draws one of cash+2/brain-3floor0/cred+1/nothing. Petting the outdoor
  possum awards THE ROUTE but does not grant a companion. No added save on ordinary prophecy.
* COMPANION-CORPSE: source spawn checks ANY pet_possum record, including released/killed ones.
  Preserve that block until a fresh roster. Release clears hasPossum; combat death does not.
* COMPANION-ID: source appends repeated freed_dog_follower IDs after every departure. Replace
  the prior dead row on return so keyed3D actors/poses/navigation remain unique. No extra
  rewards, new IDs, altered return rolls or persistent follower resurrection.
* COMPANION-EPOCH: source saves neither hasPossum nor freedDogT/freedDogFollowT/FirstReturn.
  Its same-session load can retain hasPossum=true while spawnNpcs removes the pet. Fresh/restore
  resets these four unsaved values and pending callbacks, consistent with existing3D epoch
  replacement. Durable scrap_dog quest/deaths/counter/achievements remain. Characterize original
  stale behavior separately from the corrected property; do not claim exact source equivalence.
* COMPANION-PHYSICAL: bounded deferred spawn/reveal and paused reveal countdown while blocked,
  described above, replace unsafe source coordinate writes without rerolls or invented rewards.

## Validation and handoff

Unchanged-source oracle must cover all four menus/states,16 lines×4 effects, threshold timings,
food/faction/save order, four-pin success/failure/Escape, spawn/release/corpse behavior, exact
return/expiry boundaries and reveal selection. Separately characterize source load ghosts and
duplicate dog rows. Properties cover actual shared puzzle cross-context revocation, stale
tokens/epochs, missing/nonfinite physical adapters, blocked/retried selected placements,
collected-pile cancellation, no duplicate rewards/IDs and underpass timer/live coupling.
Existing Heist/Combat regressions stay green. Root alone runs Godot and owns Runtime/scene
composition, physical-world/browser evidence, corpus gates, register/BRAIN and shipping.

## Production composition

FullRuntime constructs one shared Lockpick and injects it into Heists and Companions. Companions binds the one Director after physical combat starts; no second pet or puzzle clock is created. Source active ordering is Director dog discomfort, Memory clocks, Companion lifecycle, then later Director movement/reveal. Its wall callback receives the same monotonic wall input in every mode. Fresh/restore synchronize its epoch before play; modal replacements invalidate only that owner's puzzle context. The scene dispatches all four IDs through its closest-NPC scan. Departed retained animal records are invisible and untargetable; killed animals retain their combat death pose. The retained record prevents source-forbidden possum reacquisition, and a returned dog replaces its old dead keyed body.
