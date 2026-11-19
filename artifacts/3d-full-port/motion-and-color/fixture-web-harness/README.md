# Isolated actual Web fixture evidence — draft contract

Prepared before code. This directory is an evidence harness, not production or a completed
browser result. Root copies the accepted production dependencies into an isolated project,
imports/exports it with the pinned engine, serves it on the existing loopback server, and
observes actual browser rendering. No broad server or engine is started by this packet.

The probe extends the actual `tests/fixture_motion_probe.gd`, reusing its World/View/Weather,
real Pete rig/food attachment, camera helpers and geometry queries. It stages only fifteen
views: three real sodium patches at source sine minimum/maximum in day/night (twelve),
then the actual PAWN-counter fallback at two night phases and hidden day (three). Pete is
hidden throughout this isolated probe; the independent actual Day/FullScene visibility gate
is separate evidence. No Runtime, gameplay/input loop, save/load, state/resources or RNG.

`visual_ms` is explicitly PI*1050 / PI*350 for sodium minimum/maximum, or713 /1373 for
steam. Unix time stays3000ms. Weather reads staged dayTime .5/.9 and clear weather; this
harness never writes existing fixture light energies directly. Source clock functions do not
run here. This is presentation evidence, not an earned-playthrough or frame-budget claim.

The HTML uses the engine's real WebGL canvas; it never creates Canvas2D or draws substitute
pixels. After each requested step, Godot waits for real rendered frames, checks camera/LOS
and supplied phase, reads the actual framebuffer and reports through JavaScriptBridge.
For sodium it also reads the same camera with only the combined overlay hidden, restores
the exact view, then records a3x3 center-pixel comparison. Any all-zero overlay delta fails.
Min/max comparisons at identical camera/day must show an actual positive framebuffer delta.
These comparisons prove a visible compiled contribution, not Canvas color equality. Browser
engine errors fail the page's acceptance. Actual WebGL2 context/version is reported only
after the engine renders. Normal occlusion and overall appearance still need visual review.

The page provides a named step selector, Render step, Previous and Next buttons. DOM
`#status`, `#current-step`, `#step-result` and `#result` expose real readiness/results for
CUA. The canvas has `data-ready` and `data-step`. A step becomes screenshot-ready only after
framebuffer readback and its Godot result. No automatic advance; the rendered view stays
still while CUA captures it. Results retain at most15 step records; requests are capped60.
Browser logs cap100 entries and errors50. Replacing a step refreshes its record, not history.
Startup timeout120s reports a failure; it is a harness watchdog, not a gameplay timer.

## Files and staging

- `project.godot`, `main.tscn`, `export_presets.cfg`: isolated Compatibility/no-thread Web setup.
- `fixture-shell.html`: custom export shell, real DOM controls/results and actual canvas.
- `tests/fixture_web_probe.gd`: SceneTree subclass of the accepted native probe.

Copy these files into a fresh isolated directory, for example
`.build/3d/fixture-web-project/`. Copy `game3d/scripts/` and `game3d/data/` there unchanged,
plus `game3d/tests/fixture_motion_probe.gd` to its `tests/` directory. Do not copy the full
Runtime scene as its entry point. This project explicitly starts the evidence SceneTree
with `--script res://tests/fixture_web_probe.gd` via the custom shell's engine arguments.
The empty main scene is only a fallback export entry.

Root commands, using its pinned4.5.1 executable:

```
Godot --headless --path .build/3d/fixture-web-project --editor --import --quit
Godot --headless --path .build/3d/fixture-web-project --export-release Web .build/3d/full/web/fixture-motion/index.html
```

The preset's no-thread template points to this repo's existing approved local template;
Root may resolve that absolute path for its isolated copy. Serve the export from the existing
loopback server, e.g. `/fixture-motion/index.html` beneath its existing Web directory. Do not
open a file:// page. No new browser persistence is requested.

Wait for `READY`, capture the actual canvas with the current step text visible, then choose
each next named step. `#result` records visited/all15, per-step and pair evidence, geometry
checks, shader/source hashes, renderer, WebGL version, engine errors and explicit limitations.
Compiled Web exports may remap/remove GDScript source files, so an empty runtime hash is
explicitly reported as unavailable, never treated as a source-identity match or failed shader.
The JSON content hash remains separately available. Root retains external hashes of the
copied source files, isolated archive and export pack as the actual provenance authority.
`acceptance` is false until all15 real steps and all6 min/max pairs pass with WebGL2 and no
engine/browser errors. The visible Download JSON button saves that same report; DOM text
can also be read directly. Root retains screenshots and report alongside native evidence.

Official APIs checked: Godot4.5 JavaScriptBridge create_callback/get_interface/eval and
custom HTML shell GODOT_URL/GODOT_CONFIG/startGame/onPrint/onPrintError. No production files,
engine, Git, Web browser or server were run by the draft author.
