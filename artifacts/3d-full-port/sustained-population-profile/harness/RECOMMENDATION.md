# Sustained actual 60+ actor workload — proposal and isolated draft

2026-11-18. Read-only diagnosis of frozen `8bcd5bd124b1-92451f2a`; no engine run, production edit, or acceptance promotion.

2026-11-19 draft status: SPEC-DRAFT.md, the isolated driver, copied native probe and
detached contract now exist under this directory. They have not been engine-run.
BASELINE.json pins the source probe; its MeasuredScene timing class is unchanged.
The later actual Office corner evidence adds a fresh short-step certificate to the
proposal's long-edge check. Root must validate and run identical copies in both
comparison snapshots before drawing population or performance conclusions.

## Evidence

`evidence/full-actor-performance.json` contains two complete 1080-frame phases after 120 warm-up frames. Both warm-up manifests have exactly 60 actors: 41 ordinary source records, all 15 canonical Kingdom guards, and four real source-spawned police (including one Brendan). Each phase records one actual arrest and exactly four removed police IDs, no born or dead IDs during measurement, and minimum live/supported/rigged counts 56. Core day walks 88.519m, admits 27,372.759ms, and has scene CPU p95 21.626ms. Trainyard night walks 128.309m, admits 25,830.119ms, and has scene CPU p95 20.746ms. Both independently fail the unchanged 16ms timing gate. Population failure is real and does not explain away CPU failure.

The report stores event totals, not per-event timestamps/positions or HP history. It proves arrest/removal but cannot identify the exact catch location, contact sequence, or which attack was fatal. The recorded walked distance can include source arrest relocation, so the future report must exclude lifecycle discontinuities from its actual-walk metric.

`game3d/tests/full_actor_performance_probe.gd:123–153` starts each phase from fresh state, then assigns seed/dayTime and wanted=4 once, places the player once, and lets Runtime spawn the four cops normally. `_drive` (324–335) follows a static route, changes heading, and holds forward; it does not sprint, inspect threats, refresh a blocked dynamic segment, or react to arrest relocation. This is a poor evasion driver, not a disabled police system. Source `src/systems/combat.js:446–456` clears all isCop records, wanted and rocks on arrest. Source `manageCops:480–550` decays wanted every18s, spawns toward wanted count and caps backup at4. These remain authoritative.

## Recommended bounded next packet

Keep the existing two districts, seeds, 120-frame warm-up, 1080-frame measured phases, initial normal HP/equipment and one-time wanted4 setup. Add a versioned, normal-input evasive tour controller. It may read live actors/player and actual physical queries, rotate the camera, and press/release movement/sprint only. It must not attack to remove population, alter actor records/positions, reset HP/wanted/stun/shakes, suppress lifecycle, teleport after the initial disclosed placement, or replenish resources. Source movement, sprint shakes, stun, police speed/range, taser, damage and arrest stay unchanged.

At a bounded cadence (e.g.200ms), evaluate the intended next segment against the real player capsule and live neutral/hostile peers. Score a finite set of short reachable headings using current cop/Brendan distance and approach velocity, favoring progress along the fixed district loop while avoiding dead ends. Use real sweep/start/end clearance and actual input each frame; retain only a finite local route and invalidate on obstruction, target/peer drift or physical revision. Sprint only through ordinary Input, using live shakes/stun constraints; do not give a privileged speed. If no legal segment is available, release input and retry within an explicit no-progress watchdog, then fail. Never count a route merely planned as walked. Need actual native evidence before asserting this survives the two full phases.

Keep the 60 threshold for EVERY measured sample. Arrest remains legal production behavior but invalidates this workload attempt immediately with a complete failure report; never restart a failed phase silently or choose a favorable seed after results. Preserve old failed evidence. Publish any new driver/route revision and rerun both baseline and candidate frozen snapshots with identical driver, seed, setup, resolution, clocks and phase duration; old fixed-route timings are a different workload and not a valid before/after comparison.

## Expanded population alternative — not preferred

The current56 nonpolice already include all15 undefeated Kingdom guards (`campaign_system.gd:252–275`; source `refreshKingdomForces`), so simply turning on Kingdom cannot add another15. Defeating clans reduces guards. Normal conditional residents (Price Guy, day3 visitor, day30 bus driver), companions and Old School Brutus have distinct real spawn/removal/ownership contracts; do not fabricate four generic NPCs or insert dictionary clones. Any larger canonical scenario must first prove a reachable source state and use its real owners to create each record, disclose day/history prerequisites, count actual supported live bodies and rigs, and preserve every subsequent removal. It is a separate late-game workload, not directly comparable to this opening-day police tour. Do not freeze visitors or bosses just to preserve population. No sufficiently audited, simple arrest-proof60 baseline was established in this bounded diagnosis.

## Counterexample contract and evidence additions

- Reject any of1080 samples below60 live/supported/rigged actors, missing frames, unresolved owner/visual, or changed existing CPU thresholds. No shortened sample window.
- Reject a source-cop removal suppressed after arrest, a post-start HP/wanted/stat write, body clone/replacement, direct actor relocation, persistent invulnerability, or lifecycle reset inserted into measurement.
- Keep actual admitted active milliseconds and stage-call counts plus per-call/per-active-second CPU/query rates; faster code admits a different number of source subdivisions under real delta. Report driver CPU/query count outside scene CPU separately and retain total frame intervals.
- Record every arrest/death, per-frame population changes and canonical actor family, player HP/shakes/wanted/stun, input/sprint, actual displacement, threat distances and current blocked segment/replan reason. Normalize generated ID suffixes only for comparing manifests; do not alter live IDs.
- Test a moving neutral crossing, a wall plus chasing Brendan, a temporarily empty detour, high shakes, stun and actual arrest. The first cases retry or fail boundedly; arrest must still remove all cops and invalidate the60 workload.
- Preserve source spawn stats and canonically generated records before and after. No claim of deterministic wall-clock outcomes: same seeded source inputs/driver are comparable, while timestamps, frame deltas and Runtime instance suffixes must be reported.
- Passing population alone is not performance acceptance. Preserve strict scene CPU and held engine-process p95<16ms, actual route travel and all existing navigation/visual/physics gates. Native evidence is not Web evidence.
