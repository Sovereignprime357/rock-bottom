# SPEC — Interactive street props P10b

Captured before generation 2026-11-18; root approved model/source-fixture scope. Authority:
src/data/props.js21–52; interactions.js107–117,317–346; combat.js145–242;
update.js256–277; activities.js179–184; start.js125. Source stays unchanged.
This packet does not bind Runtime, Scene or World, create a second renderer, or claim that
the current static bottle colliders already follow these live records.

## Ownership and lifecycle

PropState owns one additional live14-record interactive array: six canonical trash cans and
eight breakable bottles, addressed strictly by interactive:0 through interactive:13. Existing
source PROPS lifecycle stays unchanged. interactive_record(id) returns the live record;
interactive_records() returns detached records. interactive_ready() is epoch-aware.

An explicit reset_interactive(reason) is separate from the existing static reset_session.
This keeps the24 gameplay draws at the root's source lifecycle seam instead of silently
moving them into static PROPS rebinding. Cold construction adopts exported initial records
without RNG. Fresh and restore each reset cans and rebuild eight bottles, once per p/s epoch:
for each slot6..13 draw candidate index, x jitter, y jitter in that exact order. Initial pool
has16 authored points; both jitter axes use(random-.5)*40. Restore does NOT restore broken
bottles or cooldowns: source startGame(true) also calls initInteractiveProps. Nothing here
enters the save schema. Pending placements never survive fresh/load.

Root order: state fresh/restore and source phone initialization; canonical actor/start setup;
static props.reset_session(reason); interactive_actions.reset_session(reason) invokes the
explicit shared-array reset, then stages all14 physical points. The last two calls can be
separated if other owners need static PROPS earlier. The24 bottle draws are contiguous and
remain candidate/x/y for slots6..13; physical staging/retry consumes no RNG.

## Commands and combat seam

RockBottomInteractivePropActions.new(host,spatial,props,combat) has weak owner references.
Public API: ready(), supports(id), reset_session(reason), kick(id), tick(dt_ms),
resolve_swing(capability), render_records(), snapshot(). Runtime schedules finite0<dt<=50ms
active-playing ticks immediately before dumpster cooldowns, after random events. No process,
wall clock, AI, player attack cooldown, inventory copy or duplicate interaction scan lives here.

Trash E uses strict50px player-center to can point and current spatial.can_reach_target(id).
Source priority is NPC/heist/bench, then first nearby trash can, then phone/cart/dumpster.
The root owns selection order. Kingdom battle blocks interaction; ordinary boss/raw HP/stun
add no new E gate. A positive can cdT emits exact refusal and no animation/RNG/save. A valid
kick sets cdT60000, tipT200, rotPulse200, source shake>=3 and sound, then draws one outcome:
r<.5 cash2+floor(random*4); r<.7 junk record; r<.8 food record; otherwise rats. Exact source
toast and one save. Cash is directly credited as in source; no invented coin pickup delay.
Cosmetic effect events carry the source count without consuming gameplay RNG.
At the Block can's exact excluded ±50px boundary, unchanged tryInteract falls through to the
separate Block zone menu. The oracle retains its full dialogue-mode result and explicitly marks
these two steps as a Block handoff, asserting zero prop changes/draws/saves and the actual source
dialogue title. The bounded prop gate checks refusal and every owned field; root's dispatcher
owns and must verify the resulting Block menu mode.

Combat.set_prop_attack_owner(owner) is optional. In an accepted swing, after every NPC hit/death
callback and before combo handling, Combat opens one opaque p/s-bound capability, synchronously
calls owner.resolve_swing(token), then revokes it. consume_prop_swing(token,candidates,consumer)
consumes before queries; validates the bound consumer and current epoch; applies the EXISTING
Combat swing SAT and fresh can_hit LOS to detached candidate rectangles. No second reach math,
attack owner or delayed input callback. Original weapon reach/direction/origin remain captured
even if a bottle equips another weapon midway through this swing. An epoch-replacing NPC
callback revokes old-swing work. Same-epoch mode changes do not erase an already accepted swing.
Fresh LOS/placement callbacks are epoch-checked after returning, including reentrant owner reset.
An old swing cannot finalize combo, achievements or player receipts against a replacement state;
staging loops stop at the callback that replaced their epoch rather than visiting stale records.

Unbroken, physically placed bottles provide rect(x-4,y-12,8,16); every hit resolves in array
order. Mark broken, draw respawnT60000+random*60000, emit glass effect, then ALWAYS draw the
weapon chance, including when already carrying broken_bottle. Only r<.25 and a different held
weapon equips it and emits pickupWeapon's exact toast/feed. This is immediate equipment,
not a world pickup. No bottle break or weapon receipt saves. Bottle-only hits never change
Combat connected/rewardable values, never earn combo credit, and still reset combo as a miss.
The final player_attack acknowledgment remains Combat-owned.

## Clocks, placement and rendering boundary

Positive can cdT/tipT/rotPulse subtract dt without clamping; source negative remainders remain.
Broken bottles subtract respawnT. On<=0, draw a candidate from the FIRST12 spawn points, then
x/y jitter exactly once. Initial pool16 versus respawn pool12 is deliberate source parity.

spatial.stage_interactive_prop(id,kind,desired,100) returns a Vector2 or null. Accept finite,
in-world points within100 source pixels. Every initial can/bottle and respawning bottle needs
a physical placement certificate before it is rendered or attackable. Failed staging retains
the already-rolled desired point, retries at most once per250 active ms without RNG, and emits
no placement/loot success. For respawn, old shards can remain until valid placement; no new
upright invisible target exists. Pending work belongs to both p/s identities. Explicit reset
or an unexpected epoch replacement cannot commit old work. Source respawnT's negative remainder
is retained when placement succeeds. The placement deferral is an explicit3D adaptation.

render_records() returns detached rows with canonical id/index and placed/pending state. Changed
events identify exactly the changed row; renderers use the authoritative clocks for bin tip,
pulse and empty contents and bottle upright/shards. Presentation creates no RNG or timers.
Dynamic view/World work is a separate packet: replace/adopt existing source_owner geometry,
remove stale bottle colliders, move/update live service targets and invalidate navigation.
Do not leave a ghost collider at the exporter seed coordinate or add duplicate actor geometry.
Kick/held-weapon viewmodel refinements remain explicitly pending; receipts never delay gameplay.

## RNG, evidence and scope

P07 simulation/presentation RNG split remains binding. Source trash cash particles consume12
cosmetic draws; trash rats24; bottle shards24; nonfatal NPC hit particles22. The oracle executes
unchanged functions and classifies actual source callsites rather than rewriting outcomes.
glassBreak schedules six audio pitch draws even with an unready audio gate; these remain audio
presentation draws, separately characterized, and do not enter authoritative gameplay RNG.

Oracle covers all branches/exact thresholds, initial/respawn pools, cardinal and oblique swing
boundaries, multiple bottles, already-equipped roll consumption, NPC-before-bottle-before-combo
receipts, no-save quirks, timer crossings, pause and fresh/load. Model properties cover real Combat
single-use capabilities, forged/stale/replaced epochs, blocked-to-clear placement without rerolls,
no invisible target, detached render records and shared static PROPS continuity. Root runs all
engines, physical integration and visual checks. Model/source passing alone is not full delivery.

Owned files: this spec; prop_state.gd interactive additions; combat_system.gd narrow optional seam;
new interactive_prop_actions.gd; new test_interactive_props.gd; new source oracle and fixture.
Runtime/Scene/World/first-person rig and source2D files are out of this packet.

## Bounded live presentation reads — 2026-11-18

`render_record(id)` returns exactly one detached current-epoch row, with the same
id/index/placed/pending fields as `render_records`. Canonical IDs are strictly
interactive:0 through interactive:13; aliases, malformed and expired epochs return
an empty dictionary. This is a live read, never a cache: direct same-epoch source
timer, position, broken, pending and placement changes remain immediately visible.
Adapter reach queries use this one-row read instead of copying all14 records for
each candidate. Physical collider, source reach and LOS checks remain unchanged.
