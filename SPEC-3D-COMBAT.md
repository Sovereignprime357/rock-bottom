# SPEC — Combat and actor director foundation P07a

Captured before generation, 2026-11-18; approved under `SPEC-3D-FULL-PORT.md`.
Sources: `src/systems/combat.js`, `src/systems/npc_ai.js`, projectile/police/actor sections of
`src/core/update.js`, `src/minigames/activities.js:179-184,428-439`, and physicality.js.
P07b retains Tony/Older/FallenPriest phase orchestration and kingdom/coop campaign outcomes.
This foundation is not a complete fight or scene integration claim.

## Authority, clocks and physics protocol

`combat_system.gd` and `actor_director.gd` keep weak owner/adapter references. GameState owns
p/s, npcs, cash_piles, projectiles, player timers, RNG and events. Combat calls its existing
hurt/die/arrest; never copies player HP or failure mutations. Inventory remains the owned-record
helper. Director changes source actor records and emits presentation snapshots; it creates no art.

All simulation vectors are source pixel coordinates; all durations are milliseconds. Combat API:
attack_player(horizontal_forward:Vector2), damage_player(amount,source_record), kill_actor(id),
aggro(id), spawn_projectile(spec), tick_status(dt_ms), tick_projectiles(dt_ms), tick_police(dt_ms,wall_ms),
tick_wall(wall_ms), move_actor(body,intended,goal=null,stop_on_block=false), clear_actor(body),
can_hit(from_center,to_center,source_id,target_id), actor(id), and spawn_swarmer(parent).
Director API: tick(dt_ms,wall_ms), snapshot(id), supported(actor). Active ticks accept finite
0<dt<=50ms; production Runtime uses fixed steps <=1000/60ms. Invalid input rejects before work.
Runtime ticks GameState player timers exactly once; Director ticks actor timers exactly once.
Combat.tick_status owns only combo timeout; Runtime invokes it once per active step.
Combat sets hitPause40ms (20ms essential contact); Runtime alone decays it and skips the entire
active fixed step while it was positive, matching source update(). Wall scheduling continues.

Physics adapter is mandatory, weak, pure with respect to model resources. Exact methods:

* move_body(body:Dictionary,intended:Vector2,goal:Variant=null,stop_on_block:bool=false)
  -> Dictionary `{position:Vector2,blocked:bool}`. Position is finite source top-left. Input
  body is a detached geometry record `{x,y,w,h,id}` with optional scalar `name`, `sprite` and
  `isOmalleyFallen` visual hints for exact pre-spawn body height; adapter cannot mutate actors.
* clear_placement(body:Dictionary) -> finite Vector2 source top-left, or null on failure.
* can_hit(from_center:Vector2,to_center:Vector2,source_id:String,target_id:String) -> bool,
  computed from actual current wall/height geometry. Missing adapter fails closed.
* sweep_projectile(start:Vector2,end:Vector2,radius:float) -> Dictionary
  `{blocked:bool,fraction:float,position:Vector2}`; fraction is finite[0,1], first wall impact,
  or1/end for clear. Runtime bridges pixels to metres and real physics; decorative reach flags
  and cached line-of-sight answers are insufficient. Wall contact wins equal-time ties.

Physics adapter results are validated before assignment. Actor motion/knockback cannot tunnel
through walls. Commit motion before contact/LOS checks, correcting source's pre-commit contact
ordering. Charger obstruction ends its lunge and enters cooldown on the next actor step. Swept
projectiles hit the earliest wall/player crossing, correcting endpoint-only tunneling. No adapter
means no accepted attack, contact damage, spawn placement or projectile movement.

## Melee, damage and death

First person adapts the cardinal source rectangle to an oriented horizontal corridor from the
player body's front: width8px, length36+weapon.reach. Every intersecting live body with current
LOS may be hit once per swing. All nine weapon cooldown/damage/reach values come from Content.
Attack is immediate; visual windup/contact never delays or triggers damage. No attack in modal,
stun, cooldown or invalid direction. Formula floor((14+random*8+weapon.dmg)*high1.5*cart1.3*
charger_cooldown1.25). Hit flash200ms, actor stun120ms, knockback8px, player attack pose160ms.
Essential bodies get harmless flash120ms/20ms hit pause and a debounced source receipt, no HP,
aggro, displacement, wanted, blood or combo reward. noComboReward actors reset combo safely.
Combo increments once per connected swing, lasts1800ms, pays+3cred/achievement at5 and+10 at10;
whiffs reset it, incoming accepted hurt resets it. Core's500ms player iframes remain authoritative.

Accepted incoming hurt uses core.hurt, source8px away-from-attacker knockback on nonfatal hits,
and source presentation. Fatal cop hits arrest; other hits die. No second death/arrest handler.
Projectiles apply their slow even when damage was blocked by iframes, matching source.
Actor contact cooldowns and stun/slow also preserve this source distinction.

Ordinary death is idempotent. Preserve basic+3cred, cop+10cred/wanted/copsKilled/rep, alley counts,
Dave crossword, Stripe betrayal/Judas, all-alley achievement, Brutus defeat/night torch rule,
weapon/drop checks and territory rules. Essentials cannot die; guards/adds yield no ordinary
rewards. Special boss/pretender/FallenPriest/OldSchool/Older deaths require a capable atomic
domain adapter (`can_handle_death(detached_actor)`, `handle_death(actor_id)->bool`); no generic reward path.
The latter sees staged lethal HP, must complete atomically and mark the actor dead on true;
false must be mutation-free and Combat restores staged HP before any hit effects or rewards.
Before lethal damage, unavailable special handling rejects that target without partial HP loss.
Brutus's fifth ordinary death schedules `spawn_brutus_older()` at wall+1500ms through the domain
adapter; an unavailable handler remains an explicit pending dependency, never a fabricated boss.
Robbery-flag grabbers require domain `attempt_robbery(actor)->bool` before contact damage. Without
that handler the actor reports unsupported and does not silently become an ordinary grabber.

## Director and police

Support passive/default/cop/Brendan, patrol/wander/wanderOff/zoneOnly/pet/ally, charger,
charger_older, grabber, swarmer and ranged patterns. Shared source speed is px/16ms. Source
archetype timers/tunings remain: charger800/1000/1400ms; Older550/1400/1700ms; berserk400/800/600ms;
fixed lunge direction, source lunge-speed multipliers2/2.4/3 and damage1.5/1.8/2. Grabber1.3damage,
500ms stun/200ms freeze; swarmer1.4speed/.6damage/700ms contact; ranged180–260px band,120px panic,
300ms aim,1500ms throw,320px/s bottle15damage. Brendan charges4000ms for50damage/1000ms cooldown.
Dog discomfort slows relevant cops within200px. Source pet follow/reveal and ally10damage/700ms
behavior use physical motion. Cart contact14damage/600ms and10px knockback stays combat-owned.
P07b-only archetypes report unsupported rather than receiving the default chase pattern.

Police wanted decays one star at18000ms/collar multiplier per source call; active target count
equals wanted, hard cap4. At wanted>=2, a30% spawn may be Brendan when none lives. Ordinary
radio attempts use .25*dt/1000,5s cooldown and wall delay800–4800ms. tick_wall runs even paused;
arrivals recheck caller alive, wanted>0 and cap4. Timed source summons use the same queue.
Fresh/restore replaces p/s identity and discards pending callbacks and presentation epochs.
Generated cops/siblings/adds have unique runtime IDs and transient:true. Authored IDs preserve
permanent death. This excludes meaningless historical generated IDs from new saves; no actor's
simulation stops because its art is offscreen. Source swarmer cap2 and nearby400px guard remain.

Snapshots expose actual post-collision local_velocity(+Z forward, metres/sec), turn_rate,
grounded, action/action_phase/action_serial/contact/hurt/dead/death_phase/coat_count/gaze,
plus source_position and yaw. Pose-only death age resets on new/load; no animation callback
changes gameplay. Supported action vocabulary follows the character family; source throw aim,
grab, charge, recoil and death are explicit states. Rig limitations never change AI or damage.

## Explicit defect and compatibility ledger

* Brendan bare `cashPiles` is a verified source ReferenceError after partial rewards. Approved
  repair uses host.cash_piles and finishes the intended30-dollar badge, achievement, factions,
  first-kill counters/feed and final save in one command. The oracle records the original error;
  corrected behavior has a separate property fixture, not a falsely passing source comparison.
* Preserve shipped `n.id==='larry'&&!P.weapon||P.weapon==='fists'`: any ordinary fists kill
  equips pipe; Larry also does so with missing weapon. This is intentional compatibility here.
* Approved RNG separation: gameplay uses host seeded LCG. Cosmetic particle/dust samples no
  longer consume gameplay draws. Controlled source oracle rolls prove mechanic formulas and
  branches, not whole-render-loop random-stream identity. Runtime IDs do not consume RNG.
* Pet exact-overlap division by zero is guarded with a finite denominator; no NaN actor escapes.
* Wall-first motion/LOS/sweep adaptation above is required by the ratified full3D physicality.
* Preserve the shipped dog-discomfort predicate (`cop` field or literal brendan/horsecop IDs).
  Generated `isCop` actors do not acquire that missing source flag through this port.
* Melee emits attack_props_requested with the exact swing corridor. Breakable-prop transactions
  require the later prop consumer; P07a does not claim bottle-prop parity without it.

## Evidence

Dev-only oracle executes unchanged source combat/AI at controlled random values and fixed time,
characterizes both defects, and captures cooldown/damage/contact/archetype/death/police outcomes.
Tests use real GameState with test physics and domain seams, inspect actual state and emitted
snapshots, exercise occluded melee/contact/projectiles, lethal handoff rejection, duplicate death,
iframes/slow, source modifiers/combo, radio cap/cancellation/modal arrival, fresh/load cancellation,
finite inputs, transient persistence and ordinary permanent deaths. Root alone imports/runs Godot.
Physics scene, boss subpacket, art visibility and native/Web fight tours remain required integration.
