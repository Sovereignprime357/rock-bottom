# Dave sleep candidate: root-owned validation staging

This helper is specified before implementation. It does not alter the held art
candidate, live production or earlier evidence. It consumes the exact 495-file
resident archive `ede8f5bf...`, its original source inventory and the three
overlays from the held Dave sleep manifest `6bd74a9d...`. No index/eave/query
candidate is composed. This is a pinned source snapshot, not a claim that every
file equals the later Git checkpoint.

`stage.py` creates only a fresh named directory under
`.build/full-port/dave-sleep-validation/`. Validate archive inventory, safe entry
paths, all source hashes, candidate hashes and official engine/template hashes
before writing. Preserve exact source bytes and EOL. Reject an existing output;
never delete or overwrite a prior run. Retain prepared source hashes, overlay
old/new hashes, dependencies, absolute commands and no-acceptance fields.

Focused mode overlays exactly Animator + original-reference test + focused test.
`run-focused.ps1`, executed only by root, stages then serially imports and runs
the five specified headless tests. Absolute project/script paths, argument lists,
hidden owned children, isolated APPDATA/LOCALAPPDATA, 600-second stage limits,
10-second polling/cleanup, raw stdout/stderr and exit code are mandatory. A
nonzero exit, timeout, engine/script/parse error, leak warning, or missing exact
PASS marker fails. Preserve failure artifacts. Check source before/after each
child; the only additional import files permitted are the two named new test
UIDs, and only valid uid:// content. No frame-count forced exit or parallel engine.

Native/Web staging applies only the Animator production change. It reuses the
actual ground-v2 walkthrough wrapper `66eb0323...` and passive rigid-head helper
`64cfe67a...` byte-for-byte. Verify that the wrapper differs from the archived
ordinary Dave walkthrough by only the existing passive measurement line. Native
camera/three captures/actual wake remain unchanged. Web reuses the existing
`117d0dad...` shell and `2405ccd6...` bridge unchanged (960x540, ordinary Start,
120-second total watchdog and active error tracking). Only export configuration
and copied sidecars are additional delivery data. No shader, main scene, viewport
or gameplay change. Both modes emit absolute root commands but run nothing.

The Web export sidecars come from the pinned shell/bridge and archived storage
script. Root still imports/exports/serves/runs it serially and retains exported
hashes plus original PNGs/report. Native and Web machine/visual checks remain
separate, and source-byte equality is not visual acceptance. No promotion,
performance, clean-shutdown or full-parity claim follows from staging.
