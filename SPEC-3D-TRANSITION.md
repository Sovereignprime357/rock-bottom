# SPEC — Rock Bottom in low-poly 3D

Date: 2026-11-18. Baseline: `fdd0ccc364540cc46d67b14be51a5f9fb145fc36` (v22).

**Status: direction captured; implementation proposal.** The operator requested a 3D low-poly
Rock Bottom with graphics similar to Schedule I. That authorizes exploring the new medium.
First-person desktop, Godot, the slice below, and its provisional art budgets are recommendations,
not recorded operator decisions. No 3D runtime, asset set, or playable build is delivered by this
document. The existing browser release retains its active contracts.

## What we are carrying forward

Rock Bottom is a neighborhood that gradually makes room for one persistent clown. The reward is
recognition: stranger, counted, furniture, conceded. Its eventual throne is still a folding chair.
The repeatable spine is small hustles, a bad purchase, a return to the crate, eighteen seconds of
confidence, eight seconds of consequences, and another outing. The world has its own routines.

VIBE remains the authority for lowercase fragments, specific cursed identities, flat narration,
the dirty palette, mundane resolutions to magical setups, and the five comedy patterns. The
Clerical Pattern still has its future-content share cap. The Conductor's train never arrives,
copper still sings in B flat, and the throne remains a folding chair. No tutorial exposition, redemption arc,
real-world drug instruction, or explanatory cutscenes enter through the move to 3D.

The Schedule I reference supplies a target for approachable stylized 3D: simple architectural
forms, distinctive people, readable props, and street-level presence. Rock Bottom's content,
progression, palette, and original character designs supply the actual game. Its kingdom owns
curbs, tarps, bent signs, and receipts; the existing kingdom contract excludes distribution
management and passive income (`SPEC.md`, v19 campaign section).

## Verified starting point

The active entry is `index.html` and `src/main.js`, version **v22**, with native ES modules,
Canvas 2D, synthesized Web Audio, and asynchronous `window.storage` backed by IndexedDB.
The supplied AGENTS header still names v21. Historical prose and research proposals are not a
replacement for reading the current source.

Baseline `node tools/run-gates.mjs`: **19/19 PASS**, exit 0. This proves the existing game against
its current gates, not the proposed 3D version. Runtime inventory reports 23 zones, 56 initial
NPCs, 193 props, and 53 declared structures in an 8600 by 5600 world. The art corpus has 94
character bases / 377 cached keys; sprites are identity references, not ready-made 3D meshes.

Source owners:

| Concern | Current authority | Treatment in 3D |
| --- | --- | --- |
| World, roads, districts | `src/data/world.js`, `src/data/props.js` | Preserve IDs, adjacency, landmarks and travel budgets; reauthor geometry. |
| People and transactions | `src/data/npc_spawns.js`, `src/dialogue/` | Carry identities and transaction outcomes; separate text/data from DOM callbacks. |
| High, crash, movement | `src/systems/concessions.js`, `src/core/update.js`, `src/systems/hitter.js` | Port one state machine with explicit simulation time. |
| Recognition and permission | `src/systems/recognition.js`, `concessions.js`, `discovery.js` | Preserve counters, thresholds, conditions and reward neutrality. |
| Combat and obstruction | `src/systems/combat.js`, `npc_ai.js`, `physicality.js` | Preserve encounter intent; rebuild 3D movement, collision, aiming and telegraphs. |
| Routes and succession | `src/systems/progression_routes.js`, `campaigns.js` | Preserve progression graph and stable IDs; port after the local loop works. |
| Save and sound | `src/core/audio_save.js`, `storage.js` | Separate persistence from audio; retain behavior through explicit adapters. |
| Rendering and input | `src/render/`, `src/input/`, `src/ui/` | New engine presentation; existing code remains a behavioral/art reference. |

The module split is not a renderer-independent game model. It contains shared mutable `P`/`state`,
DOM calls, canvas assumptions, callback transactions, and initialization order. Replacing a
canvas with a 3D viewport does not port the game. Extract documented data and replayable behavior
fixtures deliberately; do not translate every line or maintain two handwritten balance tables.

## Recommended production direction

First-person, single-player, Windows desktop is the working recommendation. It puts the player
at Pete's glass, below Lurch's face, and near the possum's route. A first-person view also hides
the player's outfit and peripheral threats; those are acceptance concerns, not free gains.

**Recommended toolchain: Godot 4 plus Blender, with exported glTF/GLB assets.** Godot's text
scenes/scripts suit reviewable incremental work; a single neighborhood and bounded simulation
make a useful first target. Blender is present on this machine at review time. Engine availability
and an exact stable version must be verified and pinned when implementation begins. This is a
fit judgment, not a claim that one engine guarantees the reference's graphics.

Unity is a reasonable alternative if existing Unity experience or a particular asset/animation
workflow drives the choice. A browser target would instead require an explicit rendering/runtime
decision compatible with browser deployment and storage. Do not build a bespoke 3D engine merely
to preserve the legacy release's zero-dependency constraint. Do not silently import a framework
into that release either.

Before implementation, record the selected platform, perspective, engine/version, and scoped
architecture amendment. Put the new project in a separate `game3d/` subtree on a named branch.
Native-engine exceptions belong to that subtree; they must not rewrite the browser's storage,
sprite, dependency, or frozen-v19 contracts. The operator's present instruction already establishes
the low-poly direction; it does not need another vote on whether 3D may be explored.

## Art direction: a place with bad maintenance

Author original meshes from the established identities. Use broad faces, angular noses, heavy
eyelids, uneven posture, and clothes whose silhouettes carry the bit. Flat or selectively smooth
normals are a tool, not a rule that every face must be visibly triangulated. Model important
shapes; reserve small texture atlases and vertex colors for dirt, fabric, signs and wear.

| Anchor | 3D treatment | Recognition test |
| --- | --- | --- |
| Tre Bag Tony | Three visible coat layers, narrow eyes, planted stance; outer coat can leave in combat. | Recognizable without a floating name. |
| Player | Mold-green hoodie, bad shoes, visibly held equipment; sleeve/body representation. | Clothing loss must remain visible when robbery is ported. |
| Pete | Bulletproof service window, hot pocket, weighing surface, indifferent posture. | The joke reads before a conversation opens; eleven minutes stays dialogue, not a wait timer. |
| Yuri and Brutus | Crooked scale, sorted metal, old heavy dog, a navigable yard. | Useful scrap and the dog read separately from decoration. |
| Possum | Small low silhouette, pointed snout, construction helmet, purposeful route. | An animal doing a job, without a quest-beacon treatment. |
| The Block | Milk crate, curb, patched asphalt, a named sodium lamp, a persistent return sightline. | Home can be found while moving, without an exposition panel. |

Keep VIBE's sodium yellow, mold green, asphalt, sickly brown, dirty cream, rust red, fluorescent
purple and copper orange. Reserve bright/emissive cop blue for police; retain the established
muted tarp and slate colors. Give each district one dirty ambient wash.
Light has a fixture: streetlamp, barrel, shop window, sign, ember. Use grounded contact shadows,
bounded local lights, subtle fog and rough materials. Grime belongs in corners, under gutters and
around repeated use, not as a uniform noise filter. Keep text and exits readable at night.

Provisional authoring budgets to measure in-engine: ordinary characters 1,500–4,000 triangles,
hero characters up to 6,000 including clothes, common props 50–500, a reusable 512–1024px material
atlas per kit. These are starting budgets, not a description of Schedule I's meshes. One humanoid
rig plus separate creature rigs; prioritize idle, walk, run, talk, hit, attack and stagger.

In first person, propose reduced camera motion and an optional subtle CRT treatment. These change
VIBE's presentation clauses and require a scoped amendment before shipping. Hands, audio, HUD and
movement must communicate high/crash without relying on forced head sway or unreadable blur.

## First playable slice

Build one compact connected circuit: **Block → scavenging/pawn/scrap → Tony → Block**, with a short
alley encounter. Suggested cast: Tony, Pete, Yuri, Brutus, Lurch and the possum. This is a proposed
subset of existing content, not six newly invented characters. Keep one repeatable money source
available after failure so the slice cannot strand a broke player.

The playable must support walking and sprinting, look-to-interact, short lowercase conversations
with an exit, one economy route, a real purchase, the complete high/crash cycle, a readable melee
encounter, death/recovery, and save/load. The next increment adds wanted/arrest and Tony's fight.
Do not label the slice full v22 parity or replace the browser landing page with it.

| Landing | Concrete result | Exit evidence |
| --- | --- | --- |
| A. Spatial/art proof | Walkable Block and corner; authored Tony, crate and lamp; day/night views. | Operator can judge scale, face, palette and readability from player height. |
| B. Complete small loop | Earn, buy, smoke, fight, crash, recover, save, reload. | Playthrough plus timer, transaction and save fixtures. |
| C. Consequences | Wanted/arrest, Tony's fight, equipment visibility, one recognition venue. | Boss under 90s; no reward leakage; normal and failure routes both work. |
| D. Neighborhood | More districts, earned concessions, heists, robbery, routines and incident staging. | Travel budgets and old economy invariants hold per addition. |
| E. Succession | Office, claims, three courts, royal static, Emperor, continued play. | End-to-end progression and post-victory regression pass. |

Defer vehicles, multiplayer, a full-city remake and new production systems. Existing carts,
minigames, weather, phone/feed, days and late-game content return in declared parity increments.
The larger content ledger must say what is missing; a placeholder is not a shipped feature.

## Behavioral contract for the port

1. **One status authority.** Real rock: 18,000ms high then 8,000ms crash. Port source effects,
   including shakes -50, brain -4, cred +1, high movement x1.8/damage x1.5, crash movement x0.5
   and shakes +30. Preserve soap handling and transaction ordering. Animation cannot spend most
   of the usable high before control returns.
2. **Simulation time is explicit.** Current dialogue pauses the world. Preserve that initially,
   including movement/status/concession clocks; prohibit duplicate actions during animations,
   pause/resume and loading. Any later real-time dialogue change is a gameplay decision.
3. **Keep the deliberate exception.** The emergency hitter is 6s high, 14s crash, no real-rock
   recognition or coronation, and a worse full-cycle trade. Do not accidentally normalize it to
   18/8 or use it to make a no-rock campaign possible.
4. **Permission is not income.** Four recognition venues use 3/8/15 thresholds; the Block is the
   unconditional smoke spot. Earned conditions remain park/night, choir/office hours,
   underpass/freed dog present, laundromat/dryer mid-cycle. Discovery is knowledge, not a key.
   Royal static remains Block-only. A condition ending mid-high never cancels the accepted high.
   At action execution, recheck tier/condition, available rock or soap, and no active high before
   consuming anything; a refused action spends nothing. The existing `smokeRockAt()` relies on
   caller guards, so wiring a raycast directly to it would bypass part of the contract.
5. **Distance is a time budget.** Preserve adjacency and reachable loops, not a literal conversion
   of 8600x5600 pixels into metres. At baseline the ruler derives 137.5px/s walking, 0.8 shakes/s,
   a 100s fresh runway, 60s mandatory-leg budget and 45s coverage budget. Some production paths
   nearly exhaust that allowance. Measure actual 3D walks including turns, doors and obstruction;
   shortest lines on a map are insufficient. Do not compensate by secretly lengthening the high.
6. **Physical space tells the truth.** Visible walls obstruct bodies and attacks consistently;
   interact rays do not pass through walls. No jump/parkour shortcut is assumed. Doors have
   reachable interaction space; load recovery never leaves the player embedded in geometry.
7. **Transactions remain bounded.** Carry daily governors, no-duplication rules, protected quest
   items, tool-slot tradeoffs and original sale-price relationships when each system is ported.
8. **Failure is recoverable.** Death does not delete the save; a broken transaction cannot trap a
   menu. Tony remains reachable. Bosses remain defeatable in under 90s by a competent player.
9. **Persistent data has one owner.** Define a new native save namespace/schema and adapter before
   writing saves. Never overwrite the browser key `rockbottom_save_v8` (payload version 10).
   Browser import is a separate, versioned feature with explicit position/ID normalization.
   Current v10 saves `hitterHigh` but does not persist `rockedT` or `crashT`; a fresh load starts
   with zero timers. The initial parity target keeps that timer-reset behavior. Resuming a saved
   high/crash would be an explicit behavior change, not an assumed feature of the new format.
10. **Presentation carries state.** Telegraph threats that an overhead camera once revealed;
    expose stolen clothing and equipped tools visually. Keep synthesized sound character and
    mute behavior. A native audio implementation must be documented, not called Web Audio.
11. **Performance is measured.** Preserve the <16ms / 60+ active NPC target, but establish test
    hardware, resolution and CPU/GPU/p95 measurement for 3D. Old Canvas timings prove nothing
    about a new engine. Profile culling, AI and light budgets before expanding the city.

## Counterexamples and verification

For the port, reuse the existing test scenarios as behavioral fixtures, not as evidence that a
different executable passes. Capture seeded commands and expected resource/state deltas from the
JS implementation; execute equivalent commands in the new simulation with documented tolerances.

Required hostile cases: zero money/rocks; soap before a real rock; duplicate interaction input;
normal-high expiration; hitter expiration; loading during a high or dialogue; concession closing
between selection and action; theft with protected items; held/duplicate input within one visit
(genuine venue exit/re-entry remains a new visit for recognition);
death and arrest ordering; loading inside a wall; a route that only works by sprinting; a boss
that loses its readable telegraph when viewed at eye level. Port scenarios with each owning system.

The three checks remain separate: counterexample hunt, spec drift check, invariant verification.
Keep the 19 browser gates green. Add engine boot/export, simulation and playthrough checks for
the new project; do not weaken sprite-gate to make 3D assets pass a 2D contract. Operator visual
and comedy judgment remains necessary after automated checks.

## References and open choice

Read together: `VIBE.md`, current `SPEC.md` versioned sections, `CORPUS-AUDIT.md`,
`REFACTOR-FINDINGS.md`, `DELEGATION.md`, `BRAIN.md`, current source and gates.
`RESEARCH-ABSURDITY.md` contains proposals; it is not a shipped-content manifest.

- [Schedule I official press kit and visual references](https://www.scheduleonegame.com/presskit/schedule-one/index.html)
- [Godot: supported 3D formats and Blender/glTF workflow](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Godot: Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

Platform/perspective remains the open user preference: first-person desktop (recommended),
first-person browser, or third-person desktop. Settle that before selecting the runtime and
capturing the implementation amendment. No budget, delivery date, engine choice or full-port
authorization beyond the user's stated direction is invented here.
