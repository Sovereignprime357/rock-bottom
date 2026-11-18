# Full neighborhood systems checkpoint — 2026-11-18

Branch: `codex/3d-full-port`. The full port remains active/incomplete. This
checkpoint connects additional source systems and fixes physical/UI integration;
it does not certify all 32 parity features or all 585 source obligations.

The full scene now includes the original Office and Kingdom progression owners,
Day transitions, companions, heists, cooking, dumpster/bench/payphone actions,
the Block and marketplace utilities, and the live cans/bottles. The quest journal
and north-fixed minimap read the same source progression. Nine original held
weapon models use distinct grips, and accepted attacks retain the weapon that
started the swing. Phone, bench, dumpster, food and can actions acknowledge the
actual committed action in the first-person rig.

The moving prop view adopts the existing authored meshes and removes obsolete
seed collisions. Fresh/load replaces its whole placement epoch before staging
new props, so old colliders cannot perturb the next source RNG sequence. Actual
NPC envelopes, reachable approaches and line of sight constrain placement.

The canonical six street incidents have a source-tested model and original
presentation banks. Runtime activation is deliberately pending dynamic corridor
reservations. The cart projection, projected objective marker, Old School
interaction facade, weather/full audio, complete progression tours and final
performance work are still open. Dormant incident/projection helpers and their
specifications must not be mistaken for live gameplay integration.

## Counterexamples resolved

- Dynamic-prop interaction ranges initially leaked into the legacy static-world
  adapter; the dynamic branch now requires its live owner/view binding.
- Newly solid NPC contact exposed a walking test that kept aiming through Brutus
  and Lurch. The controller now verifies physical detours around retained NPCs;
  production collision and exact campaign endpoints were not changed.
- Native images exposed an offscreen minimap and receipt caused by assigning
  absolute Control positions after parenting. Anchored offsets and real viewport
  containment tests cover both; unbinding guidance also restores the fallback HUD.
- An attack that awarded a different weapon could change its own visible swing.
  Presentation metadata now carries the original accepted weapon identity.
- Source journal and objective comparisons caught an unbound pixel `npcs` lookup,
  a 3D Kingdom boss-target predicate drift, and language-library octant tie
  differences. Each is characterized explicitly in the decision register.

Executed decisions: `IMPL-3D-FULL-04` through `IMPL-3D-FULL-08` in
`REFACTOR-FINDINGS.md`. No original 2D runtime or frozen v19 changes.

## Native evidence and limits

The hand probe generated 63 native captures, with representative grips, contacts,
miss/recovery, motion, seating and contextual gestures inspected. The street-event
probe generated 30 captures; all six event families were inspected. These are
presentation checks, not full campaign playthroughs.

The latest short actual-60-NPC diagnostic retained 60 actors in both samples.
Scene CPU p95 was 31.408 ms by day and 31.840 ms by night; the engine process
monitor was 41.888/42.151 ms. This fails the 16 ms target. It uses the editor
executable's native renderer, not a release-template performance certificate.
No NPC simulation, AI clocks, quality settings or collision rules were disabled.

Central gates, build/browser evidence, files and delivery hash are recorded below
when the current verification finishes.

## Central gate output

Original unchanged runtime: `GATE RUNNER: 19/19 PASS`.

```text
3D SIMULATION GATE: PASS (106 checks; transactions, exact 18/8 boundary, daily governors, death and save normalization)
3D SCENE GATE: PASS (92 checks; scene boot, physical rays, collision, menus, real loop, persistence, recovery and browser capture/fallback controls)
3D ART GATE: PASS (196 checks; deterministic periodic tiles, transformed geometry, bounded character meshes, selective normals, render state and untouched pivots/collision)
3D VIEWMODEL GATE: PASS (41 checks; relaxed articulated hands, resolved-action gestures, alternating contact/recovery, bounded inputs and shared geometry)
3D FULL STATE GATE: PASS (211 checks; source defaults, clocks, equipment, failure and schema2 migration; scene integration pending)
3D MEMORY GATE: PASS (421 checks; source oracle, smoke/soap/hitter, exact boundaries, conditions, recognition/discovery and save clocks)
3D PROGRESSION GATE: PASS (898 checks; 31 source fixtures, routes/hustles, territory, ranks and save guards; scene integration pending)
3D ECONOMY GATE: PASS (679 checks; 27 source fixtures, inventory/migration, live action sessions and Tony/Pete/Yuri; scene/combat integration pending)
FULL WORLD GEOMETRY PASS: 7783 checks; 0 failures
3D CHARACTER ROSTER GATE: PASS (1954 checks; B1/B2/B3 cast, exact actor/site mappings, shared resources/independent poses, finite joints/UVs and current actions)
3D COMBAT GATE: PASS (2870 checks; 63 source fixtures; physics, archetypes, police lifecycle, atomic death seams; P07b and scene integration pending)
3D FULL RUNTIME GATE: PASS (128 checks; composed intro/vendor/loop/save chain, pause, stale capabilities and physical access boundaries; full scene pending)
3D PHYSICS ADAPTER GATE: PASS (21 checks; native shape/ray/sphere sweeps, slide/charge, live access, no model mutation)
3D FULL INTEGRATION GATE: PASS (245 checks; real world services, controller walk, purchase and smoke)
3D BOSS GATE: PASS (2200 checks;39 source fixtures;atomic special deaths,phase boundaries,restore repairs;campaign and scene fight tours pending)
3D TRAVEL GATE: PASS (3739 checks;48 source action cases,18 exact chest/cot UI paths,18 bus arrivals,12 combat boundaries; live scene/day integration pending)
3D ACTOR NAVIGATION GATE: PASS (4750 checks; real box sweeps, bounded detours/caches/work, source48px target drift; full60AI/rig performance pending)
3D FULL HUD GATE: PASS (21 checks; pure model view, full ledger, status units and reachable scrolling menus)
3D FULL SCENE GATE: PASS (279 checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)
3D RESIDENT GATE: PASS (4753 checks;38 source fixtures;exact menus,daily governors,discovery,atomic Fallen transition;runtime/scene pending)
3D QUEST GATE: PASS (6514 checks;56 source fixtures;five linked handlers,crown/package lifecycle,live sessions;runtime/scene pending)
3D STREET GATE: PASS (3166 checks;53 source fixtures;15 authored handlers;Phone/Karaoke production dependencies explicitly partial)
3D RHYTHM GATE: PASS (1432 checks;14 source fixtures;real untimed8-choice session;scene/native/Web pending)
3D ROBBERY GATE: PASS (462 checks;30 unchanged-source cases;governor/save/allowlists)
3D DAY GATE: PASS (3487 checks;68 source cases,4 causes,4 scripted events; real Campaign/Runtime integration pending)
3D COMMUNICATIONS GATE: PASS (1219 checks;69 source fixtures;12 calls/29 events,real feed/ticker/prop reset;Runtime/UI scheduling pending)
3D HEIST GATE: PASS (16893 checks;162 source paths/98 comparator streams;9 sites/4 pins;physical Runtime integration pending)
3D SITE INTEGRATION GATE: PASS (62 checks;9actual sites,facade/capsule/LOS,modal and rank latch)
3D CAMPAIGN FOUNDATION GATE: PASS (1364 checks;215 source cases; P13b/c menus/battles remain pending)
3D OFFICE CAMPAIGN GATE: PASS (23986 checks;136 source paths/592 steps; Kingdom actions remain P13c)
3D COOKING GATE: PASS (3857 checks;206 source fixtures;five modes/six outcomes/phase clocks/atomic chunks;Runtime/UI integration pending)
3D COOKING PRESENTATION GATE: PASS (106 checks; pure supplied-state view, source labels, finite bar, smoke, narrow layout; root input/render acceptance pending)
3D STARTUP GATE: PASS (590 checks;72 exact authored templates, shared immutable resources and opaque progress)
3D COOKING RUNTIME GATE: PASS (175 checks; real cook commands/boss wall ending, atomic settlement, lifecycle precedence, forced epochs, clocks and receipt isolation)
3D COMPANION GATE: PASS (11638 checks;114 source paths;four handlers/shared puzzle/physical deferred lifecycle;Runtime and dumpster integration pending)
3D KINGDOM CAMPAIGN GATE: PASS (22688 checks;159 source paths/369 steps; physical/native fight budgets remain root evidence)
3D KINGDOM PHYSICS GATE: PASS (593 checks; actual world/17 service points/4 arenas/12 rigs; competent fight timing remains pending)
3D WORLD PROP ACTIONS GATE: PASS (34269 checks; 159 unchanged-source paths; shared props/capabilities/physical phone/continuity; root integration pending)
3D INTERACTIVE PROPS GATE: PASS (13015 checks; 126 unchanged-source paths; shared14 records/real Combat/physical pending/epoch reset; world binding pending)
3D ACTOR CONTACT GATE: PASS (83 checks; real casts, symmetric overlap band, source combat/charges, repairs and lifecycle)
3D PRESENTATION VISIBILITY GATE: PASS (1521 checks; 72 templates; exact caches, hidden return, full bounds and shadows)
3D INCIDENTS GATE: PASS (21899 checks;132 source paths458steps/6 scenes24beats; presenter/physical paths/Runtime activation pending)
3D NEIGHBORHOOD UTILITIES GATE: PASS (1571 checks;133 source cases;Block/market/squint/12zone entries/autosave/session continuity;Runtime/Scene pending)
3D INTERACTIVE PROP VIEW GATE: PASS (3169 checks; original28meshes/14slots, actual rays/capsules, live owner topology, source-only clocks, pending/stale/cleanup)
3D VIEWMODEL CONTEXT GATE: PASS (1141 checks;9canonical weapons, original grip geometry, immutable accepted weapon, camera bounds, contexts/caches)
3D GUIDANCE: PASS (1137 checks / 165 source views / 58 directions)
3D INCIDENT PRESENTATION GATE: PASS (11737 checks;6 trajectories/24beats/28 corridors; Runtime OFF)
3D CONTENT GATE PASS: 4116 assertions
3D CONTENT EXPORT CHECK PASS: source data and provenance match
3D MEMORY ORACLE: PASS (13 independent source-method fixtures)
3D PROGRESSION ORACLE: PASS (31 independent source-method fixtures)
3D ECONOMY ORACLE: PASS (27 independent source-method fixtures)
3D WORLD ORACLE CHECK PASS: source hashes, selectors and deterministic fixture match
3D COMBAT ORACLE: PASS (63 source fixtures; Brendan ReferenceError retained as explicit defect)
3D BOSS ORACLE: PASS (39 source fixtures; 3 separate defect characterizations)
3D TRAVEL ORACLE: PASS (48 source action cases,18 exact chest/cot UI paths,18 destinations,12 combat gates,2 hideouts,1 cart; explicit3D adaptations separate)
3D RESIDENT ORACLE: PASS (38 source fixtures; exact menus, opening effects and transaction state)
3D QUEST ORACLE: PASS (56 source fixtures; linked dialogue, crown/package lifecycle, strict ranges and caps)
3D STREET ORACLE: PASS (53 source fixtures;15 exact menus,direct commerce/banter,approved quirks;feed/rhythm integration partial)
3D RHYTHM ORACLE: PASS (14 source fixtures;0–8hits,exact note/history menus,forfeit,Escape,repeat)
3D ROBBERY ORACLE: PASS (30 source cases)
3D DAY ORACLE: PASS (68 source cases;4 causes,4 events,6 daily reset keys,3 conditional families)
3D COMMUNICATIONS ORACLE: PASS (69 source fixtures;12 calls/29 events/feed/ticker/garbage;fresh-load characterization={"fresh":{"looted":true,"tipsJar":true,"postRetained":true},"load":{"ok":true,"priorLooted":true,"addedLooted":true,"tipsJar":true}})
3D HEIST ORACLE: PASS (162 source paths;98 exact sort streams;9 sites/4 pins/session availability)
3D CAMPAIGN ORACLE: PASS (215 P13a source cases; office actions/battles remain separate)
3D OFFICE ORACLE: PASS (136 source paths; 592 source steps;11 claims,6 upgrades,2 residents)
3D COOKING ORACLE: PASS (38/93/40/30/5 menus/outcomes/starts/boundaries/timelines)
3D COMPANION ORACLE: PASS (98 dialogue paths/11 world boundaries/5 reveal paths; original lifecycle defects characterized)
3D KINGDOM ORACLE: PASS (159 source paths; 369 source steps; 9 marks,4 doors,4 bosses,3 pretender profiles)
3D WORLD PROPS ORACLE: PASS (159 source paths; 287 steps; 22 fillers,10 phone lines,5 passers)
3D INTERACTIVE PROPS ORACLE: PASS (126 source paths; 132 steps; 6 cans/8 bottles,16 initial/12 respawn candidates)
3D INCIDENTS ORACLE: PASS (132 source paths/458 steps;6 scenes/24 beats; actual fresh/load characterization)
3D NEIGHBORHOOD UTILITIES ORACLE: PASS (23 menus / 75 action cases / 20 timelines / 13 entry cases / 2 continuity; unchanged source)
3D GUIDANCE ORACLE: PASS (165 views / 58 direction cases; unchanged source; original journal ReferenceError separately recorded)
3D PARITY COVERAGE: PASS (6357 checks; 32 features, 585 explicit function obligations; 0/32 verified, full port INCOMPLETE)
3D GATE RUNNER: 75/75 PASS (import clean; 47 engine suites and 28 source/parity checks; complete-port acceptance remains tracked separately)
```

Focused unintegrated projection helper: `3D GUIDANCE PROJECTION: PASS (341 checks / 30 source draw cases)`. This extra check is not counted in the registered75.

## Browser follow-up and release build
The first rebuilt browser pass reached play, showed the minimap on screen, walked to the opening objective, opened the source Block menu, scrolled the full journal, and saved/loaded through the IndexedDB-backed adapter. The journal's visible Q/Esc close instruction exposed an input mismatch: Q did nothing inside the page and Web Escape opened pause. A presentation-only ledger key now closes the corresponding Q/I page or Escape, clears on every new menu, and ignores key repeats. The full scene suite was rerun after that fix:

```text
3D FULL SCENE GATE: PASS (300 checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)
3D BUILD: PASS (Full / All; Godot 4.5.1.stable.official.f62fdbde1)
```

The75-suite output above precedes this narrowly scoped input correction; the300-check full-scene rerun covers the changed production entry. Both release targets were rebuilt again. Executable/pack hashes are in `artifacts/3d-full-port/systems/build-hashes.json`. The local `qa.html` test wrapper passes the existing `--qa-interactive` argument to the exact release pack; a query string alone is not a Godot command-line argument. Public Pages is unchanged.
Final browser follow-up used the rebuilt release pack: Q opened/closed the journal and returned to real movement; I opened inventory and Escape returned directly to play; F consumed its source brain cost; save/load displayed REMEMBERED and resumed movement. The full journal scroll reached its leave action. The minimap remained visible at the lower right. Screenshot: `artifacts/3d-full-port/systems/browser-gameplay.jpg`. The test tab was closed before further native profiling. This is an opening/control/persistence check, not a complete browser campaign tour.

Playable local full browser entry: http://127.0.0.1:8074/ . Windows executable: `.build/3d/full/windows/RockBottom.exe`. Public Pages still serves the original2D release.
## Files touched

The complete checkpoint list is in [the touched-file ledger](2026-11-18-3d-neighborhood-systems-files.txt). Unfinished incident_corridors/test_incident_reservations files are excluded from this checkpoint.
