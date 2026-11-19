# SPEC — Old School entrance and copper P11c

Captured before code, 2026-11-18. Root approved the bounded source menu owner,
exact corpse quirks and staged physical boss transaction. Root authorized the
bounded Runtime/Scene integration and canonical FullNeighborhood service point
after the model/boss gates passed. No new boss HP or death authority.

## Entry and modal authority

`RockBottomOldSchool(state, spatial, bosses)` holds weak owners. Public API:
`ready`, `supports(id)`, `open(id="oldschool")`, `select(token,action)`, `close`.
Successful pages use domain`oldschool`, actor`oldschool`, existing menu fields and
one-use ActionSession tokens; choices are`rip`,`leave`. A rank-locked page has only
leave. Fresh/restore invalidate old capabilities; a subsequent open binds current
p/s, while a stale select never changes replacement state.

Source entry: dialogue/vendors_places.js414–429; OLD_SCHOOL_DOOR at650 is
{x:3760,y:700,w:24,h:28}. Compare player center to(3772,714), strictly distance<44px.
Root's physical adapter additionally supplies actual valid placement/own-facade
LOS via`can_reach_target("oldschool")`. Recheck both p/s identities after this
external callback before changing mode. The existing physical service has1.76m
reach; Root must retain exact source center rather than inverse float32 drift.

E order is systems/interactions.js45–60: kingdom interaction blanket; Office;
owned Hideout; OldSchool; Kingdom door/mark; Office field; route; ordinary scan.
Only bossKind==kingdom blanket applies. Do not add an any-boss, HP or stun proxy
guard inside the menu. Scene input owns the existing source stun rule. Rank<3
shows the exact chained-door text; rank>=3 opens the two-choice interior. Rank,
reach and physical LOS are entry conditions, not repeated modal-choice conditions.
The captured live-Brutus truthiness belongs to each displayed page; same-epoch
actor mutations do not rewrite a callback that has already been offered.

## Exact copper branches and effect order

Authority: vendors_places.js432–491. All strings/durations remain literal.

1. `!osBrutusKilled && !capturedAlive`: no copper/RNG. glassBreak→boss spawn→
   4400ms first-rip receipt→playing→save. A successful new spawn itself emits its
   4200ms receipt, feed, glassBreak and save, so first rip has two sounds/two saves.
2. Otherwise: copper+2→copperStripped+2→copper_singer if>=10→glassBreak→3000ms
   receipt. If !capturedAlive, draw once and compare strictly<.4. A hit calls the
   boss spawn and closes playing with no trailing save; a miss saves and reopens.
   Captured alive means no random draw, then save/reopen. No cap or added cost.
3. Leave/escape closes playing with no effects. Reopened pages obtain fresh tokens
   and recapture live-Brutus state. Stale/replayed/unknown tokens cannot repeat work.

Preserved shipped quirks (already accepted in P07b): spawn refuses ANY os_brutus
record, dead included. After a kill, a retained corpse plus a successful .4 roll
therefore grants2copper, closes, creates no actor and performs NO immediate save.
A miss still grants2copper and saves/reopens. A legacy dead row with killedflag
false repeats the no-copper first-rip tax without respawning. Do not silently
remove the corpse or repair the advertised cousin fight. The menu label continues
to say40% risk even on the forced first rip.

## Boss capability and physical adaptation

Bosses remains the only owner of the OS Brutus record and existing death rewards.
Add`prepare_old_school_brutus()->Dictionary`,`commit_old_school_brutus(plan)->bool`,
`discard_old_school_brutus(plan)->void`. There is one bounded pending plan with
opaque one-use token, captured p/s identities and detached staged body; no save.
Prepare returns a successful no-op for an existing ID, or stages the canonical
record through Combat.clear_actor. It checks p/s identity after external physics.
No resources, events or RNG change on prepare/refusal. An unnormalized replacement
epoch refuses until Runtime runs the existing Boss normalization pipeline.

The menu only prepares when its captured branch could spawn AND no current ID
record exists. A probabilistic rip must preflight BEFORE effects/RNG, even though
the later roll may skip spawning; otherwise an unavailable physical spawn would
leave copper/achievement partial effects. On a miss, discard the unused plan.
Existing corpses skip staging entirely and preserve the source no-op. Recheck p/s
after prepare and discard callbacks; a replaced state is never mutated afterward.

Commit consumes before effects, does no external callbacks/physics, and uses only
its already staged body if identities/token remain valid. Existing ID appearing
before commit becomes the source no-op. With the valid synchronous capability,
commit follows source effect order without a new failure point after copper cost.
Direct legacy`spawn_old_school_brutus()` retains its existing bool contract and
delegates the shared preparation/commit path after normalization.

Canonical body: x3730,y780,w36,h28,250HP,speed1.5,35damage,hostile/aggro charger,
source charge/grab fields and isOsBrutus. Bosses/Combat already own death:
50cred,street+2,$80 territory-scaled physical pile,+5copper/counter,locker-aware
torch drop,copper_singer/school_s_out,osBrutusKilled,receipts/news/feed/save.

## Evidence required

Unchanged-source oracle covers strict44/rank boundaries, locked/interior copy,
all first/cousin/live/corpse branches, exactly.4, captured actor truthiness,
achievement threshold, raw HP/stun and ordinary-boss permission, leave and repeated
pages. Model tests use real Bosses/Combat with an explicit physical test adapter,
compare effects/RNG/save counts and source actor records, and test blocked/missing
placement, p-only/s-only callback replacement, stale/replay and one-use plans.

Root must add the actual service/E domain, canonical source point and physical
entry/spawn/controller checks before declaring this menu integrated. No fake boss
or placeholder interior geometry is authorized; the source interior is modal.

## Runtime and physical integration

Runtime constructs the owner only after its real Combat/Bosses are normalized;
`open_old_school()` and `select_old_school(token,action)` resolve its queued events
through the existing composition. Missing combat remains an explicit refusal.
All replacement menus, pause/title, death/arrest, fresh and restore close the old
capability. A stale token cannot close a newer page or change replacement state.
Scene resolves the aimed, physically reachable door after owned hideouts and before
Kingdom doors, then displays the exact owner envelope using existing numbered
choices. The shared menu-generation guard also rejects callbacks from old pages.
The only world change is retaining canonical source center(3772,714) on the
existing1.76m service; no collider, new interior or interaction radius is added.

`test_old_school_physical.gd` uses the real FullScene, world and adapter. Required
evidence: source strict44 boundary and rank3, actual approach/movement/eye ray,
unrelated LOS blocker refusal without effects, first rip's physically staged
canonical Brutus and original art, live/corpse branches, numbered/leave controls,
ordinary-vs-Kingdom boss permission, pause/cross-menu/fresh/restore invalidation.
The test retains the full authored roster and uses isolated test persistence.
