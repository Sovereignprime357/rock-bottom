# Live neighborhood presentation checkpoint — 2026-11-18

Branch: `codex/3d-full-port`. Full-port work remains active. This checkpoint adds the
live cart and incidents, Old School interactions, source audio and weather, original
pickups/projectiles, readable NPC combat cues, equipped first-person tools/clothing,
moving light fixtures, source ending receipts and actual visitor departure routing.
It also fixes missing inventory fields and source rounding.

The active pixel runtime and frozen v19 are unchanged. No feature or source handler
is promoted to fully verified merely because its model or presenter has a passing test.
The full campaign tours, real boss timing and 60-actor frame target remain separate
acceptance work.

## Native checks

The real full-scene opening used controller movement, actual interaction menus and
transactions. Its high ended at 18.12 seconds and the complete high/crash cycle at
26.17 seconds; 56 actors, menu exits and isolated save/load passed. Individual native
presentation probes cover 18 pickup views, 30 weather views, 36 gear views, 14 projectile
views, 14 final HUD views and five departure views. The departure probe passed 117
checks and observed arrival within 3.52 source pixels before removal.

Visual review corrected an obscured shelter camera and an actual HUD overlap: measured
text bounds now allow a label/health cluster beside the head with a connecting line.
The first moving-fixture probe produced all 16 views but failed its incremental CPU
target at 0.290 ms p95; that failure is retained rather than counted as acceptance.

## Performance boundary

The previous frozen release (`8f7f1aea1263cf6024ebaa75abfd9c480a1fd775`) retained 60
actors but failed: scene CPU p95 was 22.159/19.986 ms by day/night and engine process
p95 was 29.171/27.970 ms. The current source reduces redundant interaction queries,
reuses exact endpoint certificates and rejects pose writes only with a conservative
visibility/shadow proof. Results require a new frozen release measurement; no frame
budget or full-port completion is claimed here.

Executed decisions: `IMPL-3D-FULL-09` through `IMPL-3D-FULL-15` in
`REFACTOR-FINDINGS.md`, with scoped specifications linked from `SPEC.md`.
Final gate output, current build/browser evidence, file ledger and delivery hashes
follow after verification.

## Central gate output

Original runtime: `GATE RUNNER: 19/19 PASS`.

```text
3D SIMULATION GATE: PASS (106 checks; transactions, exact 18/8 boundary, daily governors, death and save normalization)
3D SCENE GATE: PASS (92 checks; scene boot, physical rays, collision, menus, real loop, persistence, recovery and browser capture/fallback controls)
3D ART GATE: PASS (196 checks; deterministic periodic tiles, transformed geometry, bounded character meshes, selective normals, render state and untouched pivots/collision)
3D VIEWMODEL GATE: PASS (41 checks; relaxed articulated hands, resolved-action gestures, alternating contact/recovery, bounded inputs and shared geometry)
3D FULL STATE GATE: PASS (211 checks; source defaults, clocks, equipment, failure and schema2 migration; scene integration pending)
3D MEMORY GATE: PASS (421 checks; source oracle, smoke/soap/hitter, exact boundaries, conditions, recognition/discovery and save clocks)
3D ECONOMY GATE: PASS (679 checks; 27 source fixtures, inventory/migration, live action sessions and Tony/Pete/Yuri; scene/combat integration pending)
FULL WORLD GEOMETRY PASS: 7783 checks; 0 failures
3D CHARACTER ROSTER GATE: PASS (1954 checks; B1/B2/B3 cast, exact actor/site mappings, shared resources/independent poses, finite joints/UVs and current actions)
3D COMBAT GATE: PASS (2870 checks; 63 source fixtures; physics, archetypes, police lifecycle, atomic death seams; P07b and scene integration pending)
3D FULL RUNTIME GATE: PASS (128 checks; composed intro/vendor/loop/save chain, pause, stale capabilities and physical access boundaries; full scene pending)
3D PHYSICS ADAPTER GATE: PASS (21 checks; native shape/ray/sphere sweeps, slide/charge, live access, no model mutation)
3D FULL INTEGRATION GATE: PASS (245 checks; real world services, controller walk, purchase and smoke)
3D BOSS GATE: PASS (2200 checks;39 source fixtures;atomic special deaths,phase boundaries,restore repairs;campaign and scene fight tours pending)
3D TRAVEL GATE: PASS (3739 checks;48 source action cases,18 exact chest/cot UI paths,18 bus arrivals,12 combat boundaries; live scene/day integration pending)
3D ACTOR NAVIGATION GATE: PASS (4753 checks; real box sweeps, bounded detours/caches/work, source48px target drift; full60AI/rig performance pending)
3D FULL HUD GATE: PASS (27 checks; pure model view, full ledger, status units and reachable scrolling menus)
3D FULL SCENE GATE: PASS (367 checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)
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
3D COOKING RUNTIME GATE: PASS (175 checks; real cook commands/boss wall ending, atomic settlement, lifecycle precedence, forced epochs, clocks and receipt isolation)
3D COMPANION GATE: PASS (11638 checks;114 source paths;four handlers/shared puzzle/physical deferred lifecycle;Runtime and dumpster integration pending)
3D KINGDOM CAMPAIGN GATE: PASS (22688 checks;159 source paths/369 steps; physical/native fight budgets remain root evidence)
3D KINGDOM PHYSICS GATE: PASS (593 checks; actual world/17 service points/4 arenas/12 rigs; competent fight timing remains pending)
3D WORLD PROP ACTIONS GATE: PASS (34269 checks; 159 unchanged-source paths; shared props/capabilities/physical phone/continuity; root integration pending)
3D INTERACTIVE PROPS GATE: PASS (13040 checks; 126 unchanged-source paths; shared14 records/real Combat/physical pending/epoch reset; world binding pending)
3D ACTOR CONTACT GATE: PASS (83 checks; real casts, symmetric overlap band, source combat/charges, repairs and lifecycle)
3D PRESENTATION VISIBILITY GATE: PASS (2106 checks; 72 templates; exact caches, hidden return, full bounds and shadows)
3D INCIDENTS GATE: PASS (21899 checks;132 source paths458steps/6 scenes24beats; presenter/physical paths/Runtime activation pending)
3D NEIGHBORHOOD UTILITIES GATE: PASS (1571 checks;133 source cases;Block/market/squint/12zone entries/autosave/session continuity;Runtime/Scene pending)
3D INTERACTIVE PROP VIEW GATE: PASS (3172 checks; original28meshes/14slots, actual rays/capsules, live owner topology, source-only clocks, pending/stale/cleanup)
3D VIEWMODEL CONTEXT GATE: PASS (1253 checks;9canonical weapons, original grip geometry, immutable accepted weapon, camera bounds, contexts/caches)
3D GUIDANCE: PASS (1137 checks / 165 source views / 58 directions)
3D INCIDENT PRESENTATION GATE: PASS (11737 checks;6 trajectories/24beats/28 corridors; Runtime OFF)
3D GUIDANCE PROJECTION: PASS (362 checks / 30 source draw cases)
3D INCIDENT RESERVATION GATE: PASS (1413 checks; six prospective scenes/actual props/revisions/epochs/source RNG)
3D INCIDENT RUNTIME GATE: PASS (80 checks;4 actual Scene groups; cold/fresh/load/menu/clock/cart/props)
3D CART VIEW GATE: PASS (3639 checks; original17/real capsule and drop/strict36/epochs/resources)
3D OLD SCHOOL: PASS (1170 checks / 22 source entries / 48 paths / 57 steps)
3D OLD SCHOOL PHYSICAL GATE: PASS (69 checks;actual44px/LOS/controller/spawn/epoch/corpse)
3D SOURCE AUDIO GATE: PASS (11225 checks;192recipe banks/6gate timelines/94ambient cases)
3D AUDIO RUNTIME GATE: PASS (40 checks;actual FullScene input/ambient/wall/fresh/restore/18s8s loop)
3D FIND VIEW GATE: PASS (230 checks;4cached kinds/source visibility/no authority)
3D WEATHER PRESENTATION GATE: PASS (8045 checks;49 curves/48 render cases/936 fixture cases; actual roof/revision coverage)
3D ACTOR HUD: PASS (14252 checks / 249 actor + 208 combat source views)
3D VIEWMODEL GEAR GATE: PASS (729 checks;2tools/4coats/4shoe slots/9independent weapons)
3D DEPARTURE PHYSICS GATE: PASS (6306 checks; actual two-source transactions, full-height paths and physical removals; no native timing claim)
3D PROJECTILE VIEW GATE: PASS (113 checks; two source kinds)
3D DYNAMIC EMITTER GATE: PASS (149 checks;fixed six lights)
3D CONTENT GATE PASS: 4116 assertions
3D CONTENT EXPORT CHECK PASS: source data and provenance match
3D MEMORY ORACLE: PASS (13 independent source-method fixtures)
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
3D GUIDANCE PROJECTION ORACLE: PASS (30 unchanged-source draw cases; modal/RNG zero)
3D OLD SCHOOL ORACLE: PASS (22 entries / 48 paths / 57 steps; unchanged source)
3D AUDIO ORACLE: PASS (192 recipe banks / 6 gate timelines / 8 original RNG cases / 94 ambient cases)
3D WEATHER ORACLE: PASS (49 curve/48 render/936 fixture cases;39 static sources)
3D ACTOR HUD ORACLE: PASS (249 actor views / 208 combat views; zero random draws)
3D PARITY COVERAGE: PASS (10317 checks; 32 features, 585 explicit function obligations; 0/32 verified, full port INCOMPLETE)
3D GATE RUNNER: 95/95 PASS (import clean; 62 engine suites and 33 source/parity checks; complete-port acceptance remains tracked separately)
```
## Build and browser result

```text
3D BUILD: PASS (Full / All; Godot 4.5.1.stable.official.f62fdbde1)
```

Both Windows and Web exports are rebuilt. `artifacts/3d-full-port/live-neighborhood/`
contains build hashes, complete gate logs and selected reviewed native images.
The local full preview at `http://127.0.0.1:8074/` serves this checkpoint; public
GitHub Pages remains the original pixel game.

Actual browser UI checks passed wake-up/menu exit, Q journal open/close, I inventory
open/close with corrected fields, WASD movement, Escape pause, manual save/load,
the Block interaction and Leave. A complete page reload returned to the title;
Remember restored the saved position and Continue resumed movement. These checks
used the export's isolated QA storage key, through a local wrapper with actual
`--qa-interactive` arguments. They do not claim a full campaign playthrough or
audible sound verification. The browser logged Chromium UnknownError messages on
pointer-capture requests; gameplay continued with the displayed right-mouse-look
fallback, and no menu loop recurred. The QA tab was closed before native profiling.

The source-handler ledger now records 534 integrated, 39 partial and 12 planned
obligations. Feature and platform verification remain open. New boss-acceptance
probe files are intentionally outside this checkpoint until centrally exercised.
