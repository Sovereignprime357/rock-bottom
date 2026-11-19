# Held visual draft

Files: `SPEC-DRAFT.md`, `world_feedback_visual_probe.gd`,
`test_world_feedback_visual_contract.gd`, `BASELINE.json`, `validate-static.py`.
Thin Web files: `web_feedback_visual_probe.gd`, `feedback-shell.html`,
`feedback-bridge.js`, `project.godot`, `main.tscn`, `export_presets.cfg`.

The agent does not run the engine; centralized results and their limitations
are recorded below. The latest pose/HUD correction has no parser/native/Web PASS yet.
The source integration candidate remains read-only. `BASELINE.json` records87
candidate script/data hashes. Check these before copying the two probe scripts
into the candidate's tests directory (or a new isolated copy). Any intentional
source change requires a new provenance record, not silent reuse of this one.

Root commands, after that copy:

```powershell
& '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe' --headless --path '.build/3d/world-feedback-integration/game3d' --script res://tests/test_world_feedback_visual_contract.gd
& '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe' --path '.build/3d/world-feedback-integration/game3d' --script res://tests/world_feedback_visual_probe.gd -- --qa-full --packet=core --width=1280 --output='.build/full-port/feedback-visual/core-1280'
& '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe' --path '.build/3d/world-feedback-integration/game3d' --script res://tests/world_feedback_visual_probe.gd -- --qa-full --packet=authority --width=1280 --output='.build/full-port/feedback-visual/authority-1280'
```

Repeat each packet with `--width=960` and a distinct fresh output directory. If
using Start-Process, quote absolute paths with spaces and hide the launch window;
the engine window still needs focus for the existing source shake focus guard.

The headless marker is `ACTUAL DOMAIN FEEDBACK VISUAL CONTRACT`. The native marker
is `ACTUAL DOMAIN FEEDBACK VISUAL`, with exit1 for receipt/geometry/capture failure.
`feedback-visual.json` has explicit `complete`, `acceptance`, `visual_review_required`,
packet, resolution, source hashes, completed-case/context counts, named fixture
changes, real events, pool snapshots, view inspections and PNG hashes. Neither
marker proves native/Web aesthetic acceptance. Actual screenshots require review.

Packet core:7 cases/7 contexts/9 recipes. Packet authority:11 cases/13 contexts/9
additional recipes. Ranged and Fallen aim are observed at birth, then continue
through Runtime to an actual swept projectile impact. Full birth/active/recovery
captures attach to that impact context; the aim is not artificially kept alive.
Core also captures near-camera melee, actual-wall occlusion, and an unchanged-pose
shake pair with opaque HUD glyph and actual health-fill pixel checks. All runs cap wall time300s including
startup90s, contexts24 and PNGs96. Staging is visual-only; no gameplay tour claim.

Fresh resets happen through Runtime; normal domain saves are isolated to
`visual-only-save.json` under that run's output. Original gameplay saves and all
earlier acceptance evidence remain untouched. A stale existing report refuses to
run. Exported builds may not expose `.gd` hashes; the source archive/export pack
hashes remain required provenance and source_content.json remains readable.

Static verification performed by the agent is limited to delimiter/string
balance, fixture/case census, source method presence, authority-write inspection,
and baseline hash agreement. Central Godot parsing and physical behavior may
still expose a fixture that needs a bounded correction.

Web staging (root only): create an isolated copy of the integration candidate,
retain its scripts/data/resources, and overlay this draft's project.godot,
main.tscn, export_presets.cfg and feedback-shell.html. Copy both native/contract
scripts and web_feedback_visual_probe.gd into its tests directory. Export with
the same pinned Compatibility/no-thread Web template. Next to the exported HTML,
copy feedback-bridge.js and the unchanged existing game3d/web/storage.js. Do not
alter the source candidate or existing game's export shell.

Serve that export through the root's existing local static server. Open the HTML
with `?packet=core&size=1280` or `?packet=authority&size=960`; these only preset the
selectors. Click Start to instantiate the real engine. Reload for another packet.
The selected PNG is an original held image, explicitly labeled; the Live button
shows the separate real canvas. Download JSON and selected PNG buttons export
the engine report and verified original bytes. `window.rbFeedbackEvidence`
exposes ready/complete/acceptance, source receipts, hashes and browser errors.
No Web renderer or export was run by the agent.
# Correction to retained V1–V3 evidence

The probe's old `PROCESS_MODE_DISABLED` setting removed inherited collision
bodies from physics while retaining rendered meshes. All V1–V3 physical
clearance, ray and legal-placement claims are invalid; those failed reports and
PNGs remain retained as art references only. The new probe suspends scene/HUD
callbacks individually, preserving collider participation, and requires actual
existing-wall overlap and crossing-ray sentinels before each fixture. This is a
probe correction, not a production physics or geometry change. Rerun both
packets for physical/render evidence; old images cannot be promoted retroactively.

The later art-core-v4 run has valid real-wall sentinels and melee wall occlusion,
but its two trash cases fail framing because their source ground point is inside
the selected standing can. The next probe accepts that exact body's first hit
only as `source_prop_occluded`, preserving clear-eye checks and rejecting every
unrelated blocker. It records real particle-center sightlines at birth,80ms and
250ms with the same camera/geometry; PNG review must still establish visible
emergence. The18-recipe contract permits the combined candidate's two separately
tested dust recipes to coexist without counting them as burst coverage.

The retained art-authority-v1 run passed10/11 cases. Its final death-then-taser
fixture sampled a26px ring which misses Tony's actual strict-overlap/contact
band. The corrected fixture preflights16 shape-derived candidates per original
actor, including real static placement, source contact and LOS, then selects a
disjoint pair before writing either disclosed initial position. It retains the
real Director death/removal/detached-taser order; native proof remains pending.

Combined core-v5 centrally passed413 checks/7 contexts/29 captures; root reviewed
cash/rats emerging at250ms and actual melee wall occlusion. Authority-v5 completed
all11 physical cases/13 contexts/35 captures, including death-then-taser, but two
impact expiry checks accidentally included longer-lived ambient motes. The next
probe scopes tracked identities to the declared context recipes, preserving the
full mixed pool and strict2200ms burst bound. The failed v5 report stays intact;
its result is not retroactively promoted. Eight contract groups include the
long-lived-mote coexistence counterexample; central rerun is pending.

## Held pose and960 HUD correction

Authority1280-v6 centrally passed603 checks/13 contexts/35 captures. Core960-v6
completed every case but failed the foreground minimum: only three opaque gold
glyph pixels survived font antialiasing, with byte-identical before/after hashes.
The unchanged minimum12 now applies to unique glyph plus actual opaque health
fill pixels. The fill mask uses the live ProgressBar value/style/geometry and
viewport transform, excludes borders and translucent UI, and compares exact RGBA8.
An independent read-only check of the retained960 PNGs finds1815 identical opaque
health-fill pixels in framebuffer rectangle(26,476)–(191,487), hash
`a744a3f0b13643f8df8254f3c962cf5ca306c0faac3465e09acc3523bace6cd9`.
This verifies the proposed mask against existing images; it does not rerun or
retroactively pass the old report.

All retained v5/v6 images have an additional pose limitation: the old manual
Runtime driver never advanced ActorPose after source steps. Its zero-delta
painting left reset coats/actions in place. Effects, receipts and valid physical
sentinels remain evidence, but active actor poses require new captures. The new
driver synchronizes actual `last_advanced_ms/1000` exactly once per accepted
Runtime interval, before Scene consumes events, in both aging/projectile paths.
Painting and all screenshot/shake pairs stay zero-clock. Direct-command birth
is labeled before the next pose step. Up to two actual model/Director/rig
receipts, including visible coat mesh counts, accompany each capture; active,
midlife and recovery must match the current Director snapshot.

The contract now has eleven completion-guarded groups. `BASELINE.json` continues
to pin the original87-file integration tree and is not silently rewritten to
claim the current combined candidate. Root's combined archive/export hashes
remain that candidate's authority; `POSE-HUD-CHECKPOINT.json` pins this draft
correction and the reviewed combined pose/HUD source files. Stage only the two
updated native/contract scripts plus unchanged Web subclass into the current
combined candidate. Use fresh output directories for core/authority at both
sizes; preserve every earlier report and PNG. No production owner is changed.

