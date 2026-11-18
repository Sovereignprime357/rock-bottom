# SPEC — Full first-person scene composition

Captured2026-11-18 before the new scene implementation. P15a integrates already-verified model
packets; missing domain actions remain tracked until their real handlers arrive. The existing
slice entry is retained while the new development scene is tested. Switching the default entry,
native/Web export and complete parity require separate production evidence.

## Ownership and embodiment

`full_scene.gd` owns input, camera, visual nodes, target presentation, audio and serialized IO.
`full_runtime.gd` owns the single GameState and composed domains. The player scene node mirrors
source center/height returned by actual WorldAdapter capsule casts; it does not integrate a
second velocity/position simulation. Input supplies normalized world-horizontal movement, sprint
and view direction. Stun, status speeds, cooldowns, attack/contact and damage remain model-owned.
The existing hand rig receives actual camera-local displacement and accepted action events only.

Actor scene nodes mirror model records and validated Roster visual mappings. Unsupported visual
IDs must not silently become generic people. Stage cold template construction across frames with
a visible loading surface; cache subsequent instances. The actor director continues offscreen;
distance scheduling affects only art poses. Actual body dimensions/height register with physics.
Death, pause, dialogue, load and fresh epochs reset/freeze poses consistently. Generated actors
enter/leave the same scene registry. No invisible active threat may ship in the full scene.

## Input and interaction

WASD/mouse/Shift, E, left swing, I inventory, Q ledger, M mute and Escape preserve existing desktop
controls. Web continues the tested pending/refused capture and right-drag fallback; only losing
an acquired lock pauses. Escape must never resume and recapture in the same event. Button Leave
and Continue close modal state once; late capture never closes a modal. New/load state invalidates
all tokens. Focus loss freezes active world/poses. Monotonic wall callbacks continue independently.

Source interaction precedence remains doors -> campaign field targets -> current route stamp ->
closest eligible NPC -> copper/break-in -> bench/trash/phone/cart/dumpster -> zone verbs -> hitter
pockets. First-person object selection adds real sight/aim, while model actions recheck live reach
and LOS at both open and commit. Zone verbs retain their whole source region, without a new walk
to map markers; source MemoryLoop gates the zone and current concession conditions. Prompts must
describe the same resolver result consumed by E. No placeholder dialogue counts as a ported action.

## UI and IO

`full_hud.gd` reuses the local Godot HUD palette/styles and renders the full model directly. No
resource copies or simulation callbacks in UI. Modal menus scroll on desktop/Web so all source
options and Leave remain accessible. Inventory is a read-only source ledger; do not import the
slice's invented can-eating button into the full inventory. Hitter pocket actions remain the
lowest-priority E verb, distinct from I. Quest/hustle/route/achievement views use actual state.

Scene event consumption acknowledges existing original sound/gesture IDs, displays source copy,
and queues final snapshots from Runtime. Saves serialize and await the existing native file or
async window.storage/IndexedDB adapter; pending snapshots coalesce to the newest, errors surface.
QA has isolated filenames/namespaces. Loading validates schema and real clear placement before
resuming; missing/corrupt saves cannot erase current progress. Mouse capture after async Web load
waits for a user Continue click. Ending receipts retain durable progress and save before continuation.

## Acceptance

Headless production-scene checks cover full source placement, complete day-one visual mapping,
measured normal/sprint/high/crash movement, collision, live target/priority agreement, menu scroll
and escape/capture ordering, stale tokens, actual cash/Tony/Block chain and isolated persistence.
Native and Web tours must exercise real input and the18s/8s loop, inspect character/hand motion,
and detect script/runtime errors. Profile60+ actual actors with warm geometry and full AI, report
CPU/render/navigation costs and hardware/quality. Render-only duplicates do not satisfy this.

The development full scene uses `rockbottom_3d_full_v2` for native filename/Web storage key.
The shared bridge accepts an optional key, defaulting to the existing slice key. Full load first
looks in its own namespace and reads the legacy slice only when the full save is absent; it never
overwrites the legacy file. An invalid existing full save cannot trigger an older-save rollback.
Scene menu generations invalidate callbacks even for read-only and zone menus. Authoritative
ActionSession tokens continue to protect domain transactions. Source dayTime is a normalized
day; world lighting receives dayTime*240 seconds. Cast setup yields between cold identities.

FullRuntime exposes the milliseconds actually advanced by its latest call, excluding hitpause.
Scene poses/hands consume only that interval, so pauses and contact freezes cannot keep cosmetic
gait or gestures running. When a living, stationary actor has no authoritative combat/sleep pose,
the view may select its authored identity action (writing, strumming, folding, reading) using a
separate deterministic cosmetic phase. It consumes no gameplay RNG and changes no source state.
# Street and robbery composition, 2026-11-18

## Communications integration

Async save/load boundary: writes requested during a load remain queued until
the read finishes. Failed/empty/invalid loads retain and flush current-session
snapshots, including real wall-time bus arrivals. A successful restore discards
queued snapshots from the replaced session before writes resume. The load guard
already forbids starting a load during a pending/write operation, so this queue
cannot contain a preexisting write from another epoch. No concurrent read/write
on the single storage adapter; no silent discard on its busy refusal.

One session-global Communications and one live PropState are composed alongside
GameState. PropState rebinds after fresh/restore with the source's retention
quirks; Communications survives these epochs. Runtime consumes feed/news events
once, then the HUD renders detached snapshots on communications-change events.
P toggles the eight-post phone feed during play; wheel scrolling remains a view
operation. Menus hide the feed without clearing its requested visibility. News
uses a bounded clipped ticker line; neither view owns effects, clocks or RNG.

Root owns the source active-time scheduler in update.js: phone timer reset and
80% roll, forced30s Mom tip, then hustle polling; random-event timer follows the
future incident stage. Intro/silence suppress ambient effects while still
resetting elapsed timers. The forced Mom tip is unsuppressed. The existing50s
wall-time news rotation continues in paused/menu modes. No parallel timer owner.
Incident integration remains required; an existing state.incident suppresses
the ambient event at the source branch.

## Separate development exports

`build.ps1 -Entry Full` uses explicit Windows Full/Web Full export presets with
the `full_port` custom feature and writes `.build/3d/full/`. The project setting
`application/run/main_scene.full_port` selects `full_main.tscn` directly;
it must not construct a second model, HUD or save owner first. Default builds
remain the existing slice while full parity is unfinished. These presets make
the new scene independently playable in native and browser exports without
temporarily rewriting project settings or claiming complete gameplay parity.
Godot's native [feature override contract](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html)
owns entry selection. `serve.ps1 -Entry Full -Port 8074` serves this export.

The existing first-person interaction resolver now routes the15 Street IDs to
their literal Street owner (Pinky takes precedence over the legacy pass-only
Travel menu). Returned menus may explicitly transfer to Travel or Rhythm;
callbacks use the returned domain and fresh token. All domain sessions close
on another domain opening, pause, fresh/load, death/arrest. Missing feed/rhythm
owners keep their own transactions rejected until the real owners are wired.
Runtime exposes the source robbery owner to the already-authored landed grab;
the same state, equipment, governor, events and RNG remain authoritative.

Source number shortcuts1..9 select the corresponding currently visible modal
choice once on key press, ignoring repeat and disabled choices. They invoke the
same guarded Button callback as a click; no second transaction path. The
Karaoke modal retains five source options (four notes and forfeit); Escape
cancels it, so an extra sixth Leave button is not appended there.
