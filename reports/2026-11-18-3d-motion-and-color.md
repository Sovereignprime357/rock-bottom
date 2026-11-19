# Motion and color checkpoint — 2026-11-18

Branch: `codex/3d-full-port`. This checkpoint is validated locally; the full port
remains active. The original pixel release and frozen v19 are unchanged.

The first-person empty-hand stance sits lower and less symmetrically, with gradual
finger curl and smoother pickup/dumpster closing. Existing weapon/tool/cart grips
and peak punches retain their targets. Context 1,329 and gear 729 checks pass;
93 native views cover the existing nine weapons and added empty-hand transitions
at 1280×720 and 960×540. Selected views are retained with the capture manifest.

District colors now use the original ordered zone/region selection and six source
recipes through one screen pass below the HUD. Actual Chromium Canvas samples
compared with native Compatibility and WebGL2 have maximum error 2/255 across 270
channels; the UI patch remains unchanged. This explicitly grades final 3D hands,
rain and emissives together. It does not reproduce the original layered Canvas
composition byte for byte. A 23-view native gallery covers district/day/night/rain,
high/crash, pause/cooking and title exclusion. Its smaller viewport exposed a header
overlap; the two plates now share the available width with a gap at 960×540.

The neighborhood now has a source-timed CORNER television, four moving laundry
drums, night steam, the passing underpass shadow and three pulsing sodium patches.
Existing 3D facade counts and the pawn service aperture are declared adaptations.
Pete is hidden at night by the real Day owner, so absent food uses the actual front
counter opening; no window, collider or actor is invented. One additive mesh follows
the actual ground/curb tops, with ordinary depth occlusion. Displayed 3D light color
is renderer-dependent, not an exact Canvas additive-color claim.

Fixture model 1,286, actual-world 195 and source oracle 53 checks pass. All 31 native
captures pass; isolated sync p95 is 0.159 ms against its 0.2 ms local target. This is
not a whole-frame benchmark. The live Scene gate checks actual hidden-Pete night
behavior and both strict day boundaries. Selected native output was visually reviewed.

Source startup publications now use the existing Communications owner. Restore
honors the conditional intro cash pile and missing/non-array jobs, while explicit
empty arrays remain empty. Twelve seeded source fixtures pin bottle/wall/job/route
RNG order and safe reward normalization. Startup parity 321, State 211, Runtime 160
and Communications 1,219 checks pass. Arrow movement aliases now match the journal.

Exact bone-input memoization and synchronous physics-query setup reuse preserve
the actual poses, query counts, collision results and invalidation boundaries.
Pose memo checks pass 13,458; physics adapter 180 and navigation 4,756 pass. No NPC
count, model detail, gameplay clock, damage or collision rule is reduced.

The mapping ledger now records 555 integrated / 28 partial / 2 planned handlers.
All 585 obligations remain present, and no handler or aggregate feature is marked
verified. Completed startup/grade/fixture mappings replace stale missing-code notes;
pixel-helper, off-camera player and touch-scope dispositions remain explicit work.

## Acceptance and measurement boundaries

The corrected Tony driver on frozen `332be27711935bc1e3f04e6aba5685e5818f05bf`
production source passes in 3.364 seconds wall / 2.751 seconds active: all three
phases, both Sherris, nine source-earned attacks and 249 damage. The same rock
finishes 18.032 seconds high / 8.019 seconds crash, followed by actual ending
continuation. It uses the disclosed fresh $25 fixture and state-aware normal-input
driver. Updated test scripts were copied into that archived source; this is
editor-native evidence, not a new frozen release executable. The transient-route
failure preceding the bounded retry correction is retained separately. Office
contract 260 passes; its actual campaign tour remains pending.

The previous frozen 60-actor profile still fails the frame requirement. A measurement
audit found Godot's `TIME_PROCESS` reports a held roughly one-second maximum.
Prior `engine_process_ms` samples must not be read as independent engine frames.
New reports use `engine_process_monitor_window_max_ms` and retain the same strict
16 ms comparison, alongside the actual Scene CPU bracket. Active time, supplied
delta, stage counts/totals and query rate make the workload explicit. Viewport
CPU/GPU timings are delayed completed-render samples; they cannot be summed with
same-index script CPU, and a zero-only GPU series means unavailable. See
[the pinned timing contract](../SPEC-3D-ACTOR-NAVIGATION.md).

## Delivery status

Both complete runners pass:

```text
3D GATE RUNNER: 114/114 PASS (import clean; 74 engine suites and 40 source/parity checks; complete-port acceptance remains tracked separately)
GATE RUNNER: 19/19 PASS
```

Both Full Windows/Web exports pass. Local `http://127.0.0.1:8074/` now serves this
motion/color build. The actual browser check used isolated `qa.html` persistence:
wake-up, arrow movement, Q/Q journal, I/I inventory, pause, manual save, reload,
remember and continue passed. Restored source feed entries and new idle hands are
visible. Chromium still reports its pointer-capture `UnknownError`; the existing
right-mouse-look fallback is shown. This is not a clean pointer-lock claim or an
earned campaign/combat/mounted-cart tour.

The isolated fixture WebGL2 harness passes all 15 staged views, 568 checks and six
min/max pulse comparisons. Actual framebuffer samples show positive contributions
from every patch; shader/browser error lists are empty. The downloaded raw report,
external copied-source/export hashes and exact harness are retained. Compiled
GDScript hashes unavailable inside the package are explicitly marked unavailable.
The first harness import failed for a missing empty `exclude_filter` preset field;
the corrected harness imports/exports cleanly, without a production change.

Delivered as `8bcd5bd124b16b8e783a8d340043237d11cf72ae` on
`codex/3d-full-port`, pushed to origin. The frozen 1080-frame-per-phase release
measurement fails: core/day scene CPU p95 21.626ms, trainyard/night 20.746ms;
held engine-process monitor p95 43.411/36.963ms. Both phases record an actual arrest
and lose their four spawned officers, reaching only 56 live supported actors/rigs.
This is neither sustained60 evidence nor a performance pass. The raw report and
source/executable provenance are retained under the next packet's
`artifacts/3d-full-port/input-and-acceptance/`. Different active time and actor
counts prevent an isolated optimization claim against earlier shorter runs.

Full campaign/platform acceptance and the 60-actor budget remain open. The source
audit found two advertised shortcut gaps: Space attack in ordinary play and M mute
during cooking. Their bounded fixes proceed after this frozen baseline.

Evidence: `artifacts/3d-full-port/motion-and-color/`. Decision register:
`REFACTOR-FINDINGS.md`, IMPL-3D-FULL-21 through 27. Bounded next drafts stay under
`.build/3d/` while root owns the engine/export/Git freeze.
