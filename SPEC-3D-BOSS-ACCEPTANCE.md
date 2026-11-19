# SPEC — Actual native Tony fight acceptance

Captured before implementation, 2026-11-18. Root approved a bounded actual-input
acceptance probe. This is subordinate to AGENTS hard rules7/8, SPEC-3D-COMBAT,
SPEC-3D-BOSSES and the full-port contract. Root runs all Godot/native evidence.

## Claim and lawful fixture

Prove one competent first-person Tony fight is winnable in strictly less than90
wall seconds and90 admitted-world seconds, using the real source200HP encounter,
ordinary physical movement, damage, cooldowns, all three phases and source adds.
This is not a full campaign playthrough, Web evidence, performance acceptance or
a claim that every possible loadout/strategy wins. Failure stays a failed report.

## Explicit weapon contracts (approved after first complete native encounter)

The default `source_earned` contract starts with the same actual fresh fists/HP
and accepts only weapons earned by observed source combat rewards. The optional
`--fists-only` contract additionally requires every accepted pre-victory attack to
use fists. Reports always include both assessments and their exact claim labels.
No initial equipment/cash/stat fixture beyond the original $25 is added.

The retained `tony-capture` run correctly failed fists-only: the first ordinary
Sherri add kill equipped a pipe, which later dealt real damage before Tony died.
This is source behavior at `src/systems/combat.js:403`, retained in
`combat_system.gd:414–417`: any ordinary fists kill grants pipe; Lurch/Paulie can
grant their own random weapons. Tony's special victory grants his shoe separately.
The old report is not rewritten or reclassified. A fresh native run must produce
new source-earned evidence; it must never be labeled a fists-only victory.

A read-only input receipt brackets each actual accepted click: pre-attack weapon
and cooldown, `player_attack.used_weapon`, hit/death/reward toast/feed events,
before/after facts for affected real actors, and post-attack weapon/victory facts.
The chain begins at fists. Each next pre-weapon must equal the previous verified
post-weapon. A transition requires the corresponding actual ordinary death and
exact source reward toast/feed in that same accepted attack, in source event order;
an unbacked grant, reused corpse, unrelated kill, early shoe or changed starting
weapon rejects. Tony's shoe requires his live boss/death/quest transition and may
change the event observer's post-state while `used_weapon` still names the actual
fatal weapon. That post-state never retrospectively changes the attack weapon.
Cooldown intervals use the source catalog cooldown of the preceding actual weapon.
The receipt collector calls the unchanged normal Scene input handler once; it
never requests damage, runs RNG, alters source state or manufactures reward events.

One labeled fixture sets initial fresh-player cash to$25, obtainable from ordinary
source cash pickups. Everything else starts at actual fresh defaults:100HP, bare
fists, no equipment/companion/cart/stat/cred/progression bonus. No injected rock,
high, healing, enemy stats or invulnerability. The fixture occurs once before
the first action and is recorded in JSON; no position fixture is needed.

Actual controller route: walk to Tony, buy one real rock for$10, short him twice
for$5 each, walk to the Block, smoke through the real menu, return to Tony and
short him a third time for$5. The source third-offense callback starts the boss
without a100cred fixture. Source authority: vendors_core.gd:87–93/220–249,
src/systems/combat.js:137–168, src/core/update.js Tony phase machine, and
src/systems/concessions.js smokeRockAt. All source transaction/RNG effects remain.

## Input driver and observation

The native probe creates the actual FullScene, retains every canonical actor and
uses isolated QA persistence. Scene, Runtime, Combat, Director and physics remain
unchanged. Input actions drive movement, MouseMotion events drive aim (bounded
turn rate), E/numbered keys choose real menus, and left-click events request attacks.
Never invoke damage_actor, attack_player, Runtime.attack, boss start/death APIs,
set HP0, rewrite an actor/player position during the run, grant post-fixture
resources or bypass collision. Do not remove hostile adds or other residents.

The driver uses a100ms tactical cadence, bounded aim turns and source cooldown
readiness. It keeps ordinary melee distance, approaches out-of-range targets,
backs away from close contact and sidesteps visible charge windups/lunges.
Nearby hostile adds can be attacked through the same input path. It does not
read or manipulate future RNG or fabricate a successful attack. Misses and
incoming damage remain part of the report. No automatic retry/reload hides loss.

Walking uses a bounded test-driver visibility graph when current live residents
obstruct a static route. Keep exact service endpoints, original residents and
ordinary controller movement. Candidate corners surround the real source contact
envelopes; production capsule/contact sweeps certify edges without writing model
positions. At most 80 graph points and 32 replans per approach; check approaching
residents every 250ms, or replan after 500ms without physical progress. Failure
remains subject to the existing 20s waypoint/180s run limits. This is competent
input steering, not an AI/nav production change or a relaxed collision test.

The first central run never reached combat: the static route stalled behind live
residents and Sherri continued damaging the player. Its failed report is retained.
Failed scenarios now capture the actual frozen failure view and nearby contact
records. Cleanup queues the scene for deletion and awaits a frame, so a coroutine
resuming inside its frame-sampled signal cannot free a locked emitter.

The second failed run isolated a driver error, not a permissive route requirement:
per-axis `0.5 + 0.5*abs(component)` encoding changes diagonal direction under
`Input.get_vector`'s circular deadzone. Encode the desired vector's magnitude once,
then distribute that raw strength along its unchanged unit direction. The contract
test sends encoded cardinal, shallow-angle, diagonal and low-speed values through
actual `Input.action_press`/`Input.get_vector`, requiring the intended vector back.
Production input/deadzones, collision margin and route endpoints remain unchanged.

Service approaches end as soon as the actual Scene resolver offers the intended
kind/ID after ordinary bounded mouse aiming. The waypoint is a navigation aid,
not an additional interaction-distance rule. The real E input rechecks the same
resolver before opening; reaching some other nearby action never counts.
The third failed run completed the rock purchase and two shorts, then a live
Skid Sherri blocked the return doorway. If no swept detour exists and a real
hostile is within 65 source pixels, the driver may defend through the same normal
fist input for at most 10s, then replan. It never attacks neutral pre-boss Tony to
clear a route, never deletes a resident and never heals/refills. Pre-fight defense,
damage, drops and ordinary pickup gains stay in the event/resource receipt; only
the actual boss-start event opens the strict Tony encounter timing interval.

QA mode intentionally leaves the mouse visible after menus. The driver therefore
uses the normal first-left-click capture branch before subsequent mouse aiming;
that click captures look and does not request damage. Record these capture clicks
separately and require at least one, rather than silently assuming look events ran.
The fourth failed run exposed ignored aim events and zero attacks during defense.
After any attempted defense, including its timeout, refresh the route from the
actual current position; do not reuse the pre-defense start or require a kill.

The static route grid conservatively expands rectangular footprints, while the
real player uses a round capsule. At a physically legal corner that the grid
rejects, the driver may join a planner-clear point within 1m using an actual
unblocked capsule/contact sweep, then walk that short link through normal input.
Test at most 24 local candidates (eight headings at .25/.5/1m), with no relocated
player, changed radius, ignored contact, collider edit or substituted service goal.

A test-only FullScene subclass calls the unchanged super._process and observes
its actual admitted world milliseconds (`last_advanced_ms`) only when the frame
entered active play. This excludes source hitpause and modal/ending pauses. It
also copies selected emitted event payloads before the ordinary event consumer;
no event is removed, replaced or synthesized. Captures occur during ordinary
frames and therefore count toward wall time. No save/load/fresh is allowed after
the initial fixture. Fight timing begins at the actual boss-start callback and
ends at the real defeated actor/reward transition, not the ending screen.

## Rock loop, victory and receipt

Require one purchased rock spent by the real Block smoke callback, lifetime
rocksSmoked+1 and a source18000ms high. The fight must include a real high-state
hit. Track the same high through18000 admitted world milliseconds and its ensuing
8000ms crash, with a maximum100ms sampling tolerance per phase. Do not force a
longer fight merely to observe the crash. If victory occurs during the high,
the source delayed4s ending may pause it; record that wall/active distinction,
continue with the actual ending input and finish the unchanged loop back at the
Block. Ordinary residual hostiles remain active until naturally defeated/escaped.

Acceptance requires Tony dead, boss globals cleared, fallen_king complete, shoe
reward acquired, actual Tony-damage event sum at least200, and phases1/2/3 plus
the two real phase2 Sherris observed. The player must survive without death,
arrest, load/fresh replacement or resource/stat repair. Detect missing dependencies
and fail rather than accepting a partial encounter. Continue the source ending
only after its save guard releases; verify current progress survives continuation.

## Artifacts and bounded execution

`game3d/tests/boss_acceptance_probe.gd` runs native only. Options:
`--output=<absolute-directory>`, optional `--fists-only`, and optional `--diagnostic` (still writes
acceptance:false and prints FAIL on a failed run; only process exit is softened).
Default output `.build/full-port/boss-acceptance/tony`. Total probe timeout180s,
fight timeout90s, each approach waypoint20s; scenario and cold-start failures
produce a report (renderer/file-system startup failures may only reach stderr).

JSON schema1 `rock-bottom-boss-acceptance` contains acceptance/failures, engine
and renderer, explicitly labeled fixture, initial/final source summaries, actual
input counts, source event trace, timed phase/add records, frame/timer samples,
fight wall/active milliseconds, rock-loop high/crash samples, captures and scope.
The console gate is `3D TONY FIGHT ACCEPTANCE: PASS` only when every contract
holds. The companion `test_boss_acceptance_contract.gd` feeds counterexamples to
the report validator: missing high participation, ignored adds/phases,90s equality,
death/arrest, unearned victory, omitted loop or invalid resources must fail.
The validator checks the actual initial snapshot as well as its fixture label,
rejects duplicate/substituted add identities and rejects non-finite loop timing.
This checks the acceptance boundary, not a substitute simulated fight.

Root command (pinned4.5.1 native):
`Godot_v4.5.1-stable_win64_console.exe --path game3d --script res://tests/boss_acceptance_probe.gd -- --qa-full --output=<directory>`

The `--qa-full` launch flag is required: FullScene reads QA mode from user arguments
in _ready, replacing any pre-tree property assignment. Without it, ordinary resume
automatically captures the mouse and the probe's explicit capture-click requirement
correctly fails. The332be27 release invocation first omitted this flag, won the actual
fight in11.795s with239 Tony damage, but failed only that input-contract condition.
Keep its failed report and repeat the correctly launched scenario; do not relax the
validator or count an unlabeled input branch as the required capture test. The probe
sets its isolated save path before scenario actions regardless of that launch flag.

Headless report-contract gate (does not execute a fight):
`Godot_v4.5.1-stable_win64_console.exe --headless --path game3d --script res://tests/test_boss_acceptance_contract.gd`

Any concrete gameplay defect discovered is reported before production edits.
No production behavior, source file, exported artifact or Git operation belongs
to this packet.
