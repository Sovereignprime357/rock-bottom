# Full scene checkpoint — 2026-11-18

Branch: `codex/3d-full-port`. Full port remains **active/incomplete**; this is a
bounded integration checkpoint, not the32-feature/585-handler acceptance.

## What is connected

`full_main.tscn` now composes the full source world and56 day-one actors, the
authoritative movement/timer/state model, actual physics, local actor navigation,
combat and boss transitions. Core vendors, nine Resident handlers, five linked
Quest handlers,15 Street handlers, Travel, Karaoke and Robbery use the same
resources/RNG and one-use menu capabilities. Real crown pickup and automatic
package delivery retain source order, rewards and source locations. All six
crown positions have actual capsule and line-of-sight access evidence.

The original cast has72 visual templates for63 canonical identity rows, including
held-prop contacts, species silhouettes, groups and seated/frozen residents.
Only the56 day-one actor instances are currently placed by FullScene; site
residents and conditional progression still need their full interaction owners.
First-person gestures acknowledge accepted model actions; hitpause freezes
actor/hand pose clocks. The modal menu supports scrolling and numbered choices,
and stale callbacks cannot reopen an old transaction.

Communications and PropState are real session owners: source calls/events/news,
eight-post feed,50s wall ticker and source prop retention. Runtime includes the
source ambient phone, forced Mom tip and event clocks. The feed uses P and wheel
scrolling. Four-cause DaySystem is model checked but refuses installation without
the real Campaign owner; full day integration is still pending.

## Evidence and boundaries

The actual full-scene native opening used real input to walk from the intro
cash to Tony and back to the Block, bought and smoked through the real menus,
observed the crash at18.071s and full cycle at26.129s, and wrote an isolated
schema2 save. It covered56 actual actors. This evidence predates the latest
phone UI and distant-pose scheduling; it is not a final native/Web parity tour.

Native cast captures:188 B1,72 B2,52 prop-contact refinements and85 B3 PNGs.
Parent/worker visual review checked the named identities and gestures. Selected
images are in `artifacts/3d-full-port/p05b/` and the full-scene opening in
`artifacts/3d-full-port/p15a/`.

Actual60-native performance is **not accepted**. The first capture found the
missing robbery owner and one genuine arrest removing police; after Robbery,
the short rerun had60/60 supported live actors. Scene CPU p95 remained17–18ms;
inclusive model presentation cost was about6–7ms. The engine's sampled process
monitor also includes capture/probe stalls. Exact origin-query certificates and
ambient pose scheduling are now being validated; no performance win is claimed
without a new native capture. No fake actor clones or disabled source AI count.

Separate `-Entry Full` Windows/Web presets select `full_main.tscn` via the native
feature override, without changing the default slice or public Pages. Build,
browser review and final parity remain tracked work until observed.

## Counterexamples and decisions

- Replaced incomplete HP/stun travel proxies with actual lifecycle/mode guards;
  source dialogue can leave raw HP negative without a death event.
- Rejected boss restore placement before changing the current live session.
- Fixed actual HUD anchoring that had placed the pocket panel offscreen.
- Corrected contact-skin and preappend character-height physics queries.
- Distinguished ignored cosmetic gestures from immediate authoritative actions
  before applying distant pose scheduling and exact bone-write caching.
- Preserved source audio-traffic RNG draws that affect subsequent event/garbage
  choices, even when the audio context is not initialized.
- Day placement retries persist already-chosen bounded payloads; they do not
  reroll RNG/rewards or create invisible actors. Campaign remains a real required
  owner. Day7 news/feed are published before its silence mutation.

Executed decision register: `IMPL-3D-FULL-03` in `REFACTOR-FINDINGS.md`.
Gate output, file list, build evidence and commit delivery are appended after
the central run. Original2D runtime and frozen v19 remain untouched.

## Central gate output

Original runner: `GATE RUNNER: 19/19 PASS`.

```text
3D SIMULATION GATE: PASS (106 checks; transactions, exact 18/8 boundary, daily governors, death and save normalization)
3D SCENE GATE: PASS (92 checks; scene boot, physical rays, collision, menus, real loop, persistence, recovery and browser capture/fallback controls)
3D ART GATE: PASS (196 checks; deterministic periodic tiles, transformed geometry, bounded character meshes, selective normals, render state and untouched pivots/collision)
3D VIEWMODEL GATE: PASS (41 checks; relaxed articulated hands, resolved-action gestures, alternating contact/recovery, bounded inputs and shared geometry)
3D FULL STATE GATE: PASS (211 checks; source defaults, clocks, equipment, failure and schema2 migration; scene integration pending)
3D MEMORY GATE: PASS (421 checks; source oracle, smoke/soap/hitter, exact boundaries, conditions, recognition/discovery and save clocks)
3D PROGRESSION GATE: PASS (898 checks; 31 source fixtures, routes/hustles, territory, ranks and save guards; scene integration pending)
3D ECONOMY GATE: PASS (679 checks; 27 source fixtures, inventory/migration, live action sessions and Tony/Pete/Yuri; scene/combat integration pending)
3D CHARACTER ROSTER GATE: PASS (1954 checks; B1/B2/B3 cast, exact actor/site mappings, shared resources/independent poses, finite joints/UVs and current actions)
3D COMBAT GATE: PASS (2870 checks; 63 source fixtures; physics, archetypes, police lifecycle, atomic death seams; P07b and scene integration pending)
3D FULL RUNTIME GATE: PASS (101 checks; composed intro/vendor/loop/save chain, pause, stale capabilities and physical access boundaries; full scene pending)
3D PHYSICS ADAPTER GATE: PASS (21 checks; native shape/ray/sphere sweeps, slide/charge, live access, no model mutation)
3D FULL INTEGRATION GATE: PASS (246 checks; real world services, controller walk, purchase and smoke)
3D BOSS GATE: PASS (2200 checks;39 source fixtures;atomic special deaths,phase boundaries,restore repairs;campaign and scene fight tours pending)
3D TRAVEL GATE: PASS (3555 checks;48 source action cases,18 bus arrivals,12 combat boundaries; live scene/day integration pending)
3D ACTOR NAVIGATION GATE: PASS (4750 checks; real box sweeps, bounded detours/caches/work, source48px target drift; full60AI/rig performance pending)
3D FULL HUD GATE: PASS (21 checks; pure model view, full ledger, status units and reachable scrolling menus)
3D FULL SCENE GATE: PASS (96 checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)
3D RESIDENT GATE: PASS (4753 checks;38 source fixtures;exact menus,daily governors,discovery,atomic Fallen transition;runtime/scene pending)
3D QUEST GATE: PASS (6514 checks;56 source fixtures;five linked handlers,crown/package lifecycle,live sessions;runtime/scene pending)
3D STREET GATE: PASS (3166 checks;53 source fixtures;15 authored handlers;Phone/Karaoke production dependencies explicitly partial)
3D RHYTHM GATE: PASS (1432 checks;14 source fixtures;real untimed8-choice session;scene/native/Web pending)
3D ROBBERY GATE: PASS (462 checks;30 unchanged-source cases;governor/save/allowlists)
3D DAY GATE: PASS (3441 checks;68 source cases,4 causes,4 scripted events; real Campaign/Runtime integration pending)
3D COMMUNICATIONS GATE: PASS (1219 checks;69 source fixtures;12 calls/29 events,real feed/ticker/prop reset;Runtime/UI scheduling pending)
3D CONTENT GATE PASS: 4116 assertions
3D CONTENT EXPORT CHECK PASS: source data and provenance match
3D MEMORY ORACLE: PASS (13 independent source-method fixtures)
3D PROGRESSION ORACLE: PASS (31 independent source-method fixtures)
3D ECONOMY ORACLE: PASS (27 independent source-method fixtures)
3D WORLD ORACLE CHECK PASS: source hashes, selectors and deterministic fixture match
3D COMBAT ORACLE: PASS (63 source fixtures; Brendan ReferenceError retained as explicit defect)
3D BOSS ORACLE: PASS (39 source fixtures; 3 separate defect characterizations)
3D TRAVEL ORACLE: PASS (48 source action cases,18 destinations,12 combat gates,2 hideouts,1 cart; explicit3D adaptations separate)
3D RESIDENT ORACLE: PASS (38 source fixtures; exact menus, opening effects and transaction state)
3D QUEST ORACLE: PASS (56 source fixtures; linked dialogue, crown/package lifecycle, strict ranges and caps)
3D STREET ORACLE: PASS (53 source fixtures;15 exact menus,direct commerce/banter,approved quirks;feed/rhythm integration partial)
3D RHYTHM ORACLE: PASS (14 source fixtures;0�8hits,exact note/history menus,forfeit,Escape,repeat)
3D ROBBERY ORACLE: PASS (30 source cases)
3D DAY ORACLE: PASS (68 source cases;4 causes,4 events,6 daily reset keys,3 conditional families)
3D COMMUNICATIONS ORACLE: PASS (69 source fixtures;12 calls/29 events/feed/ticker/garbage;fresh-load characterization={"fresh":{"looted":true,"tipsJar":true,"postRetained":true},"load":{"ok":true,"priorLooted":true,"addedLooted":true,"tipsJar":true}})
3D PARITY COVERAGE: PASS (5578 checks; 32 features, 585 explicit function obligations; 0/32 verified, full port INCOMPLETE)
3D GATE RUNNER: 43/43 PASS (import clean; 26 engine suites and 17 source/parity checks; complete-port acceptance remains tracked separately)
```

A subsequent independent review found the asynchronous bus-arrival/load save race.
The scene now retains writes during reads, flushes them after failed loads and
discards replaced-epoch snapshots after successful restores. A real Travel ride
with an injected delayed storage response covers both paths.

Follow-up storage-race gate: **3D FULL SCENE GATE PASS 105**. The separate Full/All Windows and Web export passed with Godot 4.5.1. Native output: `.build/3d/full/windows/RockBottom.exe`; local full-world preview: `http://127.0.0.1:8074/`. Export success alone does not establish browser playthrough coverage.

## Files touched

```text
BRAIN.md
DELEGATION.md
REFACTOR-FINDINGS.md
SPEC-3D-ACTOR-NAVIGATION.md
SPEC-3D-BOSSES.md
SPEC-3D-CHARACTER-ROSTER.md
SPEC-3D-COMBAT.md
SPEC-3D-COMMUNICATIONS.md
SPEC-3D-DAY-SYSTEM.md
SPEC-3D-ECONOMY.md
SPEC-3D-QUEST-DIALOGUE.md
SPEC-3D-RESIDENT-DIALOGUE.md
SPEC-3D-RHYTHM.md
SPEC-3D-ROBBERY.md
SPEC-3D-RUNTIME.md
SPEC-3D-SCENE-COMPOSITION.md
SPEC-3D-STREET-DIALOGUE.md
SPEC-3D-TRAVEL.md
SPEC.md
WORKFLOW-3D-PORT.md
artifacts/3d-full-port/p05b/former_teller_stamp_contact.png
artifacts/3d-full-port/p05b/goose_manager_identity_gesture.png
artifacts/3d-full-port/p05b/lifeguard_front_rest_3m.png
artifacts/3d-full-port/p05b/model_family_front_rest_3m.png
artifacts/3d-full-port/p05b/raccoon_quorum_front_rest_3m.png
artifacts/3d-full-port/p15a/block_spawn.png
artifacts/3d-full-port/p15a/first_person_smoke.png
artifacts/3d-full-port/p15a/native-tour.json
artifacts/3d-full-port/p15a/tony_menu.png
game3d/README.md
game3d/export_presets.cfg
game3d/full_main.tscn
game3d/project.godot
game3d/scripts/actor_animation.gd
game3d/scripts/actor_director.gd
game3d/scripts/actor_navigation.gd
game3d/scripts/actor_navigation.gd.uid
game3d/scripts/boss_system.gd
game3d/scripts/boss_system.gd.uid
game3d/scripts/cast_profiles.gd
game3d/scripts/cast_profiles.gd.uid
game3d/scripts/character_roster.gd
game3d/scripts/combat_system.gd
game3d/scripts/communications_system.gd
game3d/scripts/communications_system.gd.uid
game3d/scripts/day_system.gd
game3d/scripts/day_system.gd.uid
game3d/scripts/full_hud.gd
game3d/scripts/full_hud.gd.uid
game3d/scripts/full_runtime.gd
game3d/scripts/full_scene.gd
game3d/scripts/full_scene.gd.uid
game3d/scripts/game_state.gd
game3d/scripts/prop_state.gd
game3d/scripts/prop_state.gd.uid
game3d/scripts/quest_dialogue.gd
game3d/scripts/quest_dialogue.gd.uid
game3d/scripts/resident_dialogue.gd
game3d/scripts/resident_dialogue.gd.uid
game3d/scripts/rhythm_system.gd
game3d/scripts/rhythm_system.gd.uid
game3d/scripts/robbery_system.gd
game3d/scripts/robbery_system.gd.uid
game3d/scripts/save_store.gd
game3d/scripts/site_cast_profiles.gd
game3d/scripts/site_cast_profiles.gd.uid
game3d/scripts/street_dialogue.gd
game3d/scripts/street_dialogue.gd.uid
game3d/scripts/travel_system.gd
game3d/scripts/travel_system.gd.uid
game3d/scripts/vendors_core.gd
game3d/scripts/world_adapter.gd
game3d/tests/character_roster_probe.gd
game3d/tests/fixtures/boss_reference.json
game3d/tests/fixtures/communications_reference.json
game3d/tests/fixtures/day_reference.json
game3d/tests/fixtures/economy_reference.json
game3d/tests/fixtures/quest_reference.json
game3d/tests/fixtures/resident_reference.json
game3d/tests/fixtures/rhythm_reference.json
game3d/tests/fixtures/robbery_reference.json
game3d/tests/fixtures/street_reference.json
game3d/tests/fixtures/travel_reference.json
game3d/tests/full_actor_performance_probe.gd
game3d/tests/full_actor_performance_probe.gd.uid
game3d/tests/full_scene_probe.gd
game3d/tests/full_scene_probe.gd.uid
game3d/tests/navigation_probe.gd
game3d/tests/navigation_probe.gd.uid
game3d/tests/run-gates.ps1
game3d/tests/test_actor_navigation.gd
game3d/tests/test_actor_navigation.gd.uid
game3d/tests/test_bosses.gd
game3d/tests/test_bosses.gd.uid
game3d/tests/test_character_roster.gd
game3d/tests/test_combat.gd
game3d/tests/test_communications.gd
game3d/tests/test_communications.gd.uid
game3d/tests/test_day_system.gd
game3d/tests/test_day_system.gd.uid
game3d/tests/test_economy.gd
game3d/tests/test_full_hud.gd
game3d/tests/test_full_hud.gd.uid
game3d/tests/test_full_integration.gd
game3d/tests/test_full_runtime.gd
game3d/tests/test_full_scene.gd
game3d/tests/test_full_scene.gd.uid
game3d/tests/test_quest_dialogue.gd
game3d/tests/test_quest_dialogue.gd.uid
game3d/tests/test_resident_dialogue.gd
game3d/tests/test_resident_dialogue.gd.uid
game3d/tests/test_rhythm.gd
game3d/tests/test_rhythm.gd.uid
game3d/tests/test_robbery.gd
game3d/tests/test_robbery.gd.uid
game3d/tests/test_street_dialogue.gd
game3d/tests/test_street_dialogue.gd.uid
game3d/tests/test_travel.gd
game3d/tests/test_travel.gd.uid
game3d/tools/build.ps1
game3d/tools/serve.ps1
game3d/web/storage.js
reports/2026-11-18-3d-full-scene.md
reports/3d-full-port-animation-inventory.md
tools/3d-boss-oracle.mjs
tools/3d-communications-oracle.mjs
tools/3d-day-oracle.mjs
tools/3d-economy-oracle.mjs
tools/3d-quest-oracle.mjs
tools/3d-resident-oracle.mjs
tools/3d-rhythm-oracle.mjs
tools/3d-robbery-oracle.mjs
tools/3d-street-oracle.mjs
tools/3d-travel-oracle.mjs
```

## Browser opening check

The Full Web export at port8074 visibly reached its start menu, entered the street, opened the crate dialogue, exited with numbered choice2, walked forward with W, toggled the feed with P, paused with Escape and resumed with the visible button. No menu loop occurred. IAB rejects pointer lock (`WrongDocumentError`), and the existing right-mouse look fallback remained available. Initial cast warming took several minutes and displayed enlarged warming models behind the loading panel; startup presentation/performance remains a concrete follow-up. This is an opening/control check, not complete Web progression acceptance.
