# SPEC — First-person desktop slice with a browser export

The subsequent visual/material/batching increment is scoped in `SPEC-3D-ART-PASS.md`; the
simulation and save contracts below remain its baseline.

Captured 2026-11-18, before implementation. Supersedes the unresolved platform choice in
`SPEC-3D-TRANSITION.md`. User: "yes first person desktop. playable in the browser would be nice as well".

## Scope and architecture amendment

Desktop first-person is primary; browser is a secondary export of the same source. Implement a
bounded first playable in `game3d/`, separate from the v22 browser entry and frozen v19. Use
GDScript and Godot **4.5.1 stable**, the existing local engine archive, with the Compatibility
renderer and single-threaded Web export. Pin this version for reproducibility; it is not asserted
to be the latest. No third-party runtime plugins, downloaded art packs, C#, or CDN assets.

This scoped implementation decision permits the engine/build/export pipeline, original low-poly
mesh geometry, 3D physics, a native HUD, and Godot audio/persistence within `game3d/`. The old
Canvas/palette-grid-only/no-build rules continue to govern `index.html` and `src/`. Original mesh
kits may be authored in code and cached at construction; no per-frame mesh generation. Blender
is an optional authoring tool, not a build prerequisite for this slice. Native tone synthesis
uses cached generated waveforms, no external samples. Optional subtle screen treatment replaces
mandatory CRT scanning in this first-person subtree for legibility. VIBE's voice, palette,
characters, source-grounded lighting and hard stops remain binding.

Engine binaries, export templates, imported caches and export builds are local ignored artifacts.
Commit source and reproducible build instructions. Keep the original 19-gate runner unchanged;
add a separate meaningful 3D gate/test command. Never call the new build full v22 parity.

## Playable boundary

One compact neighborhood: the Block/crate, Tony's corner, Pete's service window, Yuri's scrap
yard, Lurch's alley, three dumpsters, cash finds and a possum with a route. Existing identities
only. Walk, look, sprint, interact, punch, buy, sell, smoke, crash, recover, save and reload.
The slice has no kingdom, concessions, cooking, hitter, police, cart or full faction simulation;
those are explicit later parity landings. Lurch is an ordinary encounter, not a substitute boss.
Day cycles last 240 active seconds and refresh bounded earning opportunities, preventing a broke
save from losing access to the core loop. No walkthrough or explanatory NPC tutorial is added.

World coordinates are metres, Y up. Spawn `(0,0,8)`, looking toward -Z; Block/crate `(0,0,4)`;
Tony `(18,0,-13)`; Pete service window `(-18,1.1,-10.2)` (body behind it); Yuri `(-28,0,13)`;
Lurch `(27,0,14)`; possum around `(4,0,6)`. Author sensible collision and short open connections.
The front street uses Z -9..-3 so Pete's existing window anchor does not sit inside a road.
Bounds approximately X ±42, Z -38..30. Geometry may adjust for readability, with anchors and
tests updated together. No jumping/parkour is required. No visible building is a walk-through.

## Inputs, state, and transactions

WASD movement, mouse look, Shift sprint, E interact, left mouse punch, Escape pause/release mouse,
I pockets, M mute. Start/continue require a user click. Focus loss pauses and releases capture;
resume reacquires it only on a deliberate action. Menus pause the simulation. Look-to-interact
requires reach and line of sight; modal buttons recheck resources and reject duplicate spending.

One simulation object owns stats/counters/timers. Scene and HUD observe it and submit actions.
Start HP100, cash0, rocks0, shakes20, brain100, cred0. Walk 3.6m/s; high x1.8; sprint x1.7;
crash x0.5. Shakes +0.8/s, plus 12/s while moving and sprinting. Normal rock costs $10:
consume one, shakes -50 clamped, brain -4 clamped, cred +1, 18s high then 8s crash, shakes +30
at the boundary. High damage x1.5. Pauses do not spend high/crash time. No camera animation
delays the return of control. The slice does not implement the hitter or silently change its
future full-port contract. Soap and earned concessions are later ports, explicitly absent here.

Pete buys junk for $1 each and copper for $15, sells food for $3, and has the existing bounded
sock-for-$1 fallback. Yuri buys copper for $25. Pete's daily outlay follows the live $200 cap.
Three authored dumpsters allow one chosen find per day (small cash / junk / food); specific
offers are slice data, not claims of parity with the full randomized dumpster minigame. Cash
finds pay once per day ($5/$4/$3). Dumpster choices are $6 / three junk / one food; food heals15.
One optional copper find supplies Yuri's transaction without simulating
the full heist engine. The changed subset economy must be labeled in README. No passive income.

Melee has a 280ms cooldown, a short forward reach, line of sight and high-state damage. Lurch
telegraphs attacks, stays near his alley and can be defeated by backing out of reach. On death
the player returns to the Block, HP60, shakes30, timers cleared, cred -10 clamped at zero; inventory
and cash remain. Block healing is 6HP per active second. Repeated Lurch defeats cannot farm
rewards in one day. Vendors remain available after punches; this slice does not pretend their
full hostile/boss responses have been ported.

Slice combat is deterministic: baseline punch18, high27, Lurch reward3 cred once/day, no random
weapon/cash drops. At shakes100, withdrawal drains 0.72HP per active second (the expected 60Hz
rate of the legacy 0.006 chance of 2HP each tick), avoiding a frame-rate-dependent random test.
These are explicitly bounded slice choices, not an assertion of exact combat RNG parity.

## Persistence and audio

One new save namespace: `rockbottom_3d_slice_v1`, schema1. Native saves use a guarded file adapter
under Godot user data; web saves use async `window.storage.get/set` with an IndexedDB adapter in
the export shell. No localStorage/sessionStorage. Isolate from `rockbottom_save_v8` entirely.
Invalid/missing data defaults safely; clamp resources, known IDs, coordinates and day counters.
Save transactions and explicit pause-menu save; load closes modals and resets high/crash timers
as fresh v22 loads do. Browser save success must await persistence, and errors must be visible.

Audio begins after user input, remains under conservative gain, and honors mute. Generate short
square/saw/noise tones for hit, hurt, pickup, purchase, high and crash. Cache waveforms once;
avoid a continuous generator dependency for single-threaded web compatibility.

## Acceptance and counterexamples

- Parse/import and headless boot on pinned engine; desktop executable export. Web export and
  served Chromium smoke if templates/runtime are available; report any unverified platform.
- Production simulation tests: zero-money buy; zero-rock smoke; duplicate spend; exact 18/8
  transition; dialogue pause; death/reload; malformed saves; daily reset; seller outlay cap;
  one reward per enemy/day; bounded repeated collection. Tests must exercise real methods.
- Real rendered play: earn, visit Tony, return to crate, smoke, observe high and crash end to end;
  fight Lurch; reload a save. Inspect eye-level art, occlusion, signs, prompts and menu exits.
- No clipping through visible walls; interact/punch cannot hit through walls. Normal and high
  route walks remain comfortably inside the active shakes runway.
- Report FPS/frame measurements with hardware and resolution. Initial cast is small; do not
  claim the 60+ NPC performance target is met without a representative stress measurement.
- Current 19 browser gates pass unchanged; new native/web proof and source review remain separate.

Source contracts: `SPEC-3D-TRANSITION.md`, `src/core/update.js`, `src/systems/concessions.js`,
`src/dialogue/neighborhood_a.js`, `src/systems/combat.js`, `VIBE.md`.
