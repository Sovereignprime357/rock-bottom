# Rock Bottom — The Block in 3D

A first-person desktop slice, with a secondary browser export from the same Godot project.
This is the start of the port, not full v22 parity. The existing 2D release remains at `../index.html`.

## Play the local builds

- Windows: `../.build/3d/windows/RockBottom.exe` (standalone, embedded data).
- Browser: serve `../.build/3d/web/` over HTTP and open its `index.html` in Chromium or Firefox.
  From the repository root: `python -m http.server 8073 --bind 127.0.0.1 --directory .build/3d/web`.
  Open `http://127.0.0.1:8073/`. WebAssembly/WebGL2 are required; double-clicking the HTML is not supported.
- Editor: open `project.godot` in **Godot 4.5.1 stable**, then run the main scene.

WASD moves, mouse looks, Shift sprints, E interacts, left mouse punches, I opens pockets,
Escape pauses/releases capture, M mutes. Start or resume by clicking. Conversations pause the world.
Desktop is the primary target. The browser uses the same simulation, geometry and controls,
with a single-threaded Compatibility/WebGL2 export. No external runtime plugins or CDN assets.

## What is in this slice

The Block and crate, Tony's corner, Pete's service window, Yuri's scrap yard, Lurch's alley,
three dumpsters, loose cash, copper, Brutus and the helmeted possum. Original source-authored
low-poly meshes and materials; no stock character pack. Meshes and material kits are constructed
once, not regenerated each frame. Sound is synthesized into cached waveforms at startup and
played only after input.

You can earn, buy, sell, smoke, fight, crash, die/recover, save and load. Real rocks use the
18-second high / 8-second crash. A 240-second active day refreshes bounded finds and Pete's
$200 outlay. Native saves use a separate Godot user-data file; browser saves go through async
`window.storage` backed by IndexedDB. Neither writes the 2D game's save. Missing/corrupt saves
default safely, timers reset on load, and blocked placements return to the Block.

**Deliberate subset choices:** fixed dumpster offers ($6 / three junk / food); three cash finds
($5/$4/$3); one copper find; deterministic punch18/high27 and Lurch reward3 cred once per day;
withdrawal at shakes100 drains0.72HP/s. These are documented in `../SPEC-3D-SLICE.md`.

Not ported yet: Tony's boss, police/arrest, factions, recognition/concessions, soap, emergency
hitter, cooking, heists, carts, campaign/kingdom, phone/feed and the full neighborhood. The
six-character scene is not evidence that the 60+ NPC performance target has been met. Character
rigs are simple mesh pivots; richer animation and Blender-authored replacements can follow.

## Reproduce the build

Use the official [Godot 4.5.1 archive](https://godotengine.org/download/archive/4.5.1-stable/).
The version is pinned because it is available locally and supports both targets; it is not a
claim to be the latest release.

1. Extract the Windows editor to `../.tools/godot-4.5.1/`.
2. Extract these files from the matching export-template archive's `templates/` folder into
   `../.tools/templates/`: `version.txt`, `windows_release_x86_64.exe`,
   `windows_debug_x86_64.exe`, `web_nothreads_release.zip`, `web_nothreads_debug.zip`.
3. From the repo root run `pwsh -File game3d/tools/build.ps1`.
   `-Target Windows` or `-Target Web` limits the export. `-Engine <path>` overrides the editor path.

The script downloads nothing. Templates/editor must both report4.5.1. Build output is ignored
by Git. The browser head includes the local `storage.js` adapter, copied by the build script.
No cross-origin-isolation headers are needed for this single-threaded export. Browser save
availability depends on the origin's IndexedDB permissions; failures are reported in the HUD.

## Verification

From the repo root: `pwsh -File game3d/tests/run-gates.ps1`.
This imports the project and runs production simulation and scene integration checks. It fails
on engine error text as well as nonzero exits, because Godot can report a script error with exit0.
The original suite remains `node tools/run-gates.mjs`.

Development-only engine arguments after `--`: `--qa-tour` runs a real-time rendered smoke/crash
and isolated save roundtrip; `--qa-capture` captures the Block, Tony, Pete and Lurch, and reports
frame intervals. These are not player controls. Test saves/captures go under `../.build/3d/`;
automated native tests do not overwrite the player's save.

Contracts: `../SPEC-3D-SLICE.md` and `../SPEC-3D-TRANSITION.md`. Identity and tone: `../VIBE.md`.
