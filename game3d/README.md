# Rock Bottom — The Block in 3D

A first-person desktop slice, with a secondary browser export from the same Godot project.
This is the start of the port, not full v22 parity. The existing 2D release remains at `../index.html`.

## Play the local builds

- Windows: `../.build/3d/windows/RockBottom.exe` (standalone, embedded data).
- Browser: serve `../.build/3d/web/` over HTTP and open its `index.html` in Chromium or Firefox.
  To start a hidden background preview: `pwsh -File game3d/tools/serve.ps1` from the repo root.
  From the repository root: `python -m http.server 8073 --bind 127.0.0.1 --directory .build/3d/web`.
  Open `http://127.0.0.1:8073/`. WebAssembly/WebGL2 are required; double-clicking the HTML is not supported.
- Editor: open `project.godot` in **Godot 4.5.1 stable**, then run the main scene.

WASD moves, mouse looks, Shift sprints, E interacts, left mouse punches, I opens pockets,
Escape pauses/releases capture, M mutes. Start or resume by clicking. Conversations pause the world.
If the browser refuses mouse capture, hold the right mouse button and drag to look; movement,
interaction and left-click punching still work. In the browser, Escape only pauses; click
**continue.** to resume. Refresh the page after rebuilding the Web export.
Desktop is the primary target. The browser uses the same simulation, geometry and controls,
with a single-threaded Compatibility/WebGL2 export. No external runtime plugins or CDN assets.

## What is in this slice

The Block and crate, Tony's corner, Pete's service window, Yuri's scrap yard, Lurch's alley,
three dumpsters, loose cash, copper, Brutus and the helmeted possum. Original source-authored
low-poly meshes and materials; no stock character pack. Meshes and material kits are constructed
once, not regenerated each frame. Sound is synthesized into cached waveforms at startup and
played only after input.

The neighborhood art pass adds nine original procedural surface tiles with mipmaps, masonry and
plaster storefronts, furnished/lit Pete interior, a parked sedan, utility cabinets, scrap-yard
workbench and street details. Existing residents have more defined faces, layered clothes,
hands and shoes; Pete eats, the possum walks and Brutus moves his jaw. These are bounded idle
gestures, not new transactions. Static geometry batches once; animated pivots stay independent.

The character/street refinement replaces primitive-looking faces and limbs with connected
authored forms and selective smooth shading. Each resident has a distinct head/body silhouette;
Brutus, the possum and first-person fists use the same coherent approach. Shops have layered
window bays, smaller mounted signs, awnings, side-wall details and varied rooflines. The streets
have a zebra crossing, gutters/drains, manholes, flush repairs and grouped curbside props. Smaller
masonry courses, smoother wear fields, balanced cream/slate lighting and 4x MSAA improve clarity.
Original palettes and all gameplay/capture/save contracts remain intact. Native day/night views,
portraits and before/after measurements are in `../reports/2026-11-18-3d-character-street.md`.

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

Full-world development entry: run `res://full_main.tscn` in Godot. Export it with
`pwsh -File game3d/tools/build.ps1 -Entry Full`, then serve with
`pwsh -File game3d/tools/serve.ps1 -Entry Full -Port 8074`. Outputs are under
`.build/3d/full/windows/` and `.build/3d/full/web/`. These are separate from the
default slice and its save namespace. The full development scene includes real
source NPCs, combat, dialogue, travel, cooking, heists, Office/Kingdom, world
props, marketplace/Block actions, source objectives/journal/minimap, and nine held
weapon contexts. The cart, six street incidents, Old School, source weather/audio,
authored pickups/projectiles, actor combat cues, equipped tools/clothing/footwear,
moving light fixtures and visitor departures are connected. Remaining world adornments,
full campaign tours, browser acceptance and the measured 60-actor frame target are tracked
in the parity manifest and checkpoint reports. This is not yet complete game parity.

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
Game-data packs use a content hash in their filename so refreshing after a build fetches the
updated gameplay even when the browser retains cached subresources.

## Verification

From the repo root: `pwsh -File game3d/tests/run-gates.ps1`.
This imports the project and runs production simulation, scene integration and art/batching checks. It fails
on engine error text as well as nonzero exits, because Godot can report a script error with exit0.
The original suite remains `node tools/run-gates.mjs`.

The full-port runner now registers75 checks:47 engine suites and28 source/provenance/
parity checks, in addition to a clean import. It exercises the real full scene,
physical source world, full cast, combat/bosses, navigation, travel, dialogue,
robbery, Karaoke, communications and day model. The32-feature/585-handler ledger
is `data/parity_manifest.json`; `node tools/3d-parity-gate.mjs --complete`
intentionally fails until every obligation has integrated native/Web evidence.
Day is composed with the real Campaign owner; street-event physical/native suites
are registered separately and do not imply their Runtime activation.

Development-only engine arguments after `--`: `--qa-tour` runs a real-time rendered smoke/crash
and isolated save roundtrip; `--qa-capture` captures the Block, Tony, Pete and Lurch.
These are not player controls. Test saves/captures go under `../.build/3d/`;
automated native tests do not overwrite the player's save.

For native graphics evidence run `pwsh -File game3d/tools/render-probe.ps1 -Stress` from the repo
root. It records eye-level day/night PNGs and a five-second warmed render sample at 1280x720.
The optional stress scene adds 54 art-only duplicates to the six actual residents; it measures
rendering/idle-animation pressure, not full 60-NPC AI/gameplay. It changes no player save and uses
its own output directory under `.build/art-pass/`. Draw-call counts and CPU/render timings are
reported separately, with hardware/focus state and VSync disabled for the probe.

Contracts: `../SPEC-3D-SLICE.md`, `../SPEC-3D-ART-PASS.md`, `../SPEC-3D-CHARACTER-STREET.md`
and `../SPEC-3D-TRANSITION.md`.
Character/street refinement: `../SPEC-3D-CHARACTER-STREET.md`.
Identity and tone: `../VIBE.md`.
