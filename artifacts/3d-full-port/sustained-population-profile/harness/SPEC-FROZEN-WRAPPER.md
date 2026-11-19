# Frozen release wrapper addendum

2026-11-19. Draft only. Root executes; author does not run engine/Git. This adds
profile-frozen.ps1, not a production source or performance claim. SPEC-DRAFT.md,
RECOMMENDATION.md and INDEPENDENT-REVIEW.md retain the workload/acceptance contract.

Require an explicit committed revision (hex commit prefix or full40 digits), resolve
it to40 digits with git rev-parse, then git archive only game3d at that exact commit.
Never read production code from the dirty worktree for the runtime snapshot. Before
any overlay, inventory every archived file byte-for-byte. A caller-supplied simple
run label or generated commit/GUID name creates a new directory beneath the fixed
repository .build/full-port/sustained-population-profile root. Existing run paths
are refused; no recursive deletion, cleanup, retry or evidence overwrite.

Only these three pinned draft files may overlay the archive:
tests/full_actor_performance_probe.gd, tests/sustained_actor_driver.gd and
tests/test_sustained_actor_driver.gd. Preserve original archived hashes separately
from overlay hashes and final exported source hashes. Record the previous archived
probe even though the draft replaces it. Check the frozen MeasuredScene class
against the draft's pinned class text; do not modify full_scene.gd or any production
script. Reusing the exact wrapper/pins/three-file overlay for both8bcd and648 is
required for paired comparison. A changed pin fails closed, never auto-repins.

Generate only an isolated export_presets.cfg using the already pinned official
4.5.1 Windows release template, full_port feature and all_resources. Explicitly
include both production JSON tables and the three test scripts. Preserve the
archived project.godot. Give every engine/export/QA child its own APPDATA and
LOCALAPPDATA beneath this run, with environment set on the child process only;
the normal user save/editor state is never selected or copied. Record this layout.
On the pinned Windows engine, get_config_path reads APPDATA; get_data_path and
get_user_data_dir use that root, and get_cache_path reads LOCALAPPDATA. This is
verified in Godot4.5.1-stable platform/windows/os_windows.cpp, lines2231–2251 and
2317–2319; it does not require changing the production project.godot.

Pin both the small console launcher and its adjacent actual Windows engine EXE:
the launcher starts that engine, so launcher/version hashes alone are insufficient.
Keep the release template hash separate. Import may generate UID files for the
two added test scripts; record them in the final source inventory, permitting no
other added source and no changes to already inventoried source bytes.

The wrapper runs import, the detached driver contract, release export, then the
exported EXE. All native arguments use ProcessStartInfo.ArgumentList; paths with
spaces are individual arguments, with no composed command, nested shell, eval or
manual quote escaping. Every child uses Hidden window style. Source archive
entries are checked for containment before extraction. Child stdout/stderr and
Godot logs are kept separately. Errors in logs fail even when the process exits0.
Each stage has a900s hard bound, emits progress at most30s apart, and preserves
failed/timed-out evidence without a retry. Termination targets only that own child.

The driver owns fixed120 warm-up and1080 measured frames for each of core_day and
trainyard_night. The wrapper has no Frames parameter and never passes --frames.
No grade/pose-disable flags, alternate route/seed or reduced population. Native
--diagnostic is optional and only permits retaining failed workload reports; it
never turns acceptance:false into acceptance. Require both complete fixed phases,
expected workload version and exact report frame counts before calling the run
complete. Print acceptance separately from diagnostic completion. Non-diagnostic
acceptance:false remains an error. Existing16ms/60-actor assertions remain inside
the unchanged report contract.

External provenance pins wrapper/pin-file/three overlay hashes, requested/resolved
revision, archive/tree, original production inventory, isolated-preset/final-source
inventory, engine/template/version, exported EXE, arguments, phase constants,
isolated user paths, stage results and final report hash/status. Empty GDScript
hashes inside the compiled PCK are not equal-source proof. The wrapper never edits
the report or discards a failure. New export output/evidence files must not exist.
