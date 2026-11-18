# SPEC — Full game state, clock and save foundation

P03a, captured before generation,2026-11-18. Parent contract: `SPEC-3D-FULL-PORT.md`.
Owner files: `game3d/scripts/game_state.gd`, `game3d/tests/test_game_state.gd`.
This packet does not switch the playable scene from SliceSimulation or claim full integration.

## Authority and API

One RefCounted GameState owns `p` and `s` dictionaries with the source JavaScript names,
canonical pixel coordinates and millisecond timers. `content` is decoded immutable source
data; `npcs`, `cash_piles` and `projectiles` are transient mutable model arrays. Fresh defaults
come from Content `initial.player/state`, with day1 actors and fresh cash piles. No scene,
HUD, storage adapter or composed system gets a second copy of authoritative resources.
Decoded source Sets are unique Arrays. Input/render/session fields reset on load.

Constructor accepts optional decoded content injection. Public methods: `fresh`, `tick(seconds,
context={})`, `emit_event(kind,payload={})`, `drain_events`, `unlock_achievement`, `apply_rep`,
`apply_equip_stats`, `equip_tool`, `vendor_price`, `random_float`, `random_index`, `hurt`,
`die`, `arrest`, `complete_intro_smoke`, `snapshot`, `restore`, and
`register_state_normalizer(key,Callable)`. `content`, `p`, `s`, actor arrays and events are
public to the bounded domain modules. Event payloads are copied; draining clears the queue.
Consumers apply progression/presentation/save requests after a whole command finishes;
an achievement save request cannot capture a half-applied enclosing transaction.

Source default repair: fresh `startGame` omits equip.tool although the current contract has
four slots; core always supplies a null tool slot. Derived equipment values are recomputed,
not trusted from a save. Equipment effects, cart cap min(base*1.7,base+1.5), wanted-decay
multiplier and charisma discount follow `runtime_ui.js` and `catalogs.js`. No weapon durability.
Faction changes clamp -50..50 and signal threshold crossings; loved achievements use the
existing three milestone IDs. Intro-smoke commits its one-shot quest/+2cred/introDone state
and emits `intro_completed`; generation of hustles/routes is a required orchestration consumer.

## Time and random behavior

`tick` accepts finite positive delta up to240 seconds; invalid/larger input returns false
without partial state/time/RNG/event mutation. `context.advance_world=false` pauses. Scene
may instead omit ticking. Boolean `moving`, `sprinting`, `at_block` describe motion/healing;
when at_block is absent the source zone bounds determine it. World duration is240000ms.

Keep source high/crash timers in p.rockedT/crashT. Core only counts down. It partitions a
delta at high, crash, day and fixed withdrawal quantum boundaries. At high expiry it sets
rockedT=0, queues informational `high_expired`, then invokes `on_high_expired(was_hitter,
player_center:Vector2)` synchronously once. MemoryLoop applies normal/hitter crash and
recognition effects before remaining delta advances. Missing hook when this call would
expire a high rejects the entire call without mutation. No ignition or duplicated crash
effect belongs in core. Expiry center uses x+w/2,y+h/2; saved x/y remain top-left.

Passive shakes+0.8/s, sprint while moving adds12/s, Block healing6HP/s. Root approved replacing
the slice expectation drain with legacy withdrawal rolls at a fixed60Hz quantum: at shakes100,
one0.006 chance of2HP each quantum, with the normal500ms damage invulnerability. Fractional
quantum remainder survives between tick calls. Iframes integrate continuously, so splitting
the same interval must not change roll count, RNG, HP or status duration. This is an explicit
frame-rate normalization of the original requestAnimationFrame-dependent probability;0.72HP/s
is only the expectation before invulnerability effects and is no longer the full-port rule.
Randomness uses a uint32 LCG(1664525,1013904223), seeded state, values in[0,1), bounded indices.
Concession clocks retain their separate source LCG through MemoryLoop.

Dawn advances day/lifetime, resets source accumulating DAILY_COUNTER_KEYS and office day
capacity, and queues `day_started`. Weather, event spawns, calls, rent/pass, guard refresh and
hustles require consumers; this foundation cannot claim those integrated. Generic transient
player timers decay here; full police/AI/cooking/incidents run through their own composed
systems, never through an accidental second main-loop owner.

## Damage and failure

Reject nonfinite/nonpositive damage; ordinary hurt respects iframes, grants500ms protection,
breaks combo and emits hurt. Source die: HP60,shakes30,cred-10 clamped0,wanted0,Block position,
1000ms protection; cash/rocks/items and active high/crash remain. Source arrest: remove
floor(70%cash), remove real rocks,HP40,shakes100,wanted0,Block,arrest count+1. Both remove
police and request abort/retry of an active kingdom encounter through an explicit event.
Do not copy the source Brendan bare-cashPiles ReferenceError into new code. This packet
does not implement NPC death rewards, knockback, bosses or arrest combat triggers beyond
source.isCop dispatch after fatal hurt.

## Save schema2 and normalization

Use schema2, format `rock-bottom-full-state`, canonical `player`, `state`, permanent
`npcs_killed`, and RNG state. Persistence IO stays in the existing adapters and namespace
policy is owned by integration. Never touch the2D save key. Snapshot is detached from live
data and excludes unsafe session/UI/combat objects and transient timers. Restore uses fresh
content defaults, validates known resource/equipment/weapon/quest IDs and collection shapes,
clamps finite numeric values, and never accepts strings/bools as numbers. Natural resource,
counter and lifetime values cap at1e9; reputations[-50,50],brain/shakes[0,100],wanted[0,3].
Collections and nested optional JSON are bounded to prevent unbounded restore work.
Godot StringName keys/values created by runtime commands normalize to plain JSON strings;
dynamic flags such as Pete's locker retain ownership even when absent from fresh defaults.
Malformed/unknown schemas return a clean default state with an explicit rejected result.

Transient high/crash/stun/slow/attack/injury/input/boss/incident state resets on restore;
hitterHigh also resets because there is no active restored high. Owned items and durable
progress remain. Core invokes registered domain normalizers for recognition, concession
clocks/discovery and later campaign/route state; those domains own semantic reconciliation.
Until their normalizers/consumers are connected, generic structural safety is not full save
parity. Position is source-world-bounded, and restore reports that scene clear-placement
must run before control returns; this foundation cannot certify physical collision clearance.

Schema1 slice migration is explicit: source-equivalent HP/cash/rocks/copper/shakes/brain/cred,
day/day-time and Pete spend survive; junk/food counts become compact inventory records marked
`migration_units:true`. `SPEC-3D-ECONOMY.md` treats only these marked stacks as virtual q1
records, preserving every migrated unit through partial sales/uses without changing ordinary
source record semantics. The strict boolean marker is valid only for junk/food and survives
schema2 normalization. Full
defaults provide unrepresented systems. Mark the three intro quests complete/introDone true
without paying their rewards, matching the legacy-save principle of not replaying the intro.
If Lurch was defeated, retain his permanent death and alleyKills witness without paying again.
Retain old collected IDs in a migration receipt; they are not mapped onto unrelated source
cash piles/dumpsters. Re-spaced slice coordinates have no safe affine mapping: always return
to the new Block and report placement_reset with reason `slice_world_replaced`. No clamp-based
coordinate conversion. Slice yaw is presentation state and is not silently reused.

## Required proof

Tests use real exported Content, verify24 quests/49 achievements and mutation isolation,
known equipment/cart/discount math, finite normalization and invalid schemas, all migration
rows, detached roundtrips, permanent NPC death filtering, no reward replay, source death/arrest,
exact high/hitter hook timing and leftover delta, missing-hook atomic rejection, bounded delta,
seed/roll reproducibility, split-vs-unsplit withdrawal and500ms protection, dawn counters and
explicit events. No Godot runs are delegated here; root runs central parse/tests and reports
actual results. Scene/native/Web integration remains pending separately.
