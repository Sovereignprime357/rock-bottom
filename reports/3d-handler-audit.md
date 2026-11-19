# 3D handler mapping audit — 2026-11-18

This is a mapping checkpoint, not full-port acceptance. Only the 585 handler rows in
`game3d/data/parity_manifest.json` were changed. The 32 feature rows, baseline, content hash and
root-owned `checkpointNote` retain their prior values. No gameplay files, source modules or
tests were changed, and no engine, browser, Git or native probe was run for this audit.

| Handler status | Before | After |
| --- | ---: | ---: |
| integrated | 89 | 534 |
| partial | 0 | 39 |
| planned | 496 | 12 |
| verified | 0 | 0 |

`integrated` means an implemented owner, a relevant checked-in test and a current Runtime/Scene
composition path were found. It does not mean every branch has independent platform evidence.
All handler `nativeEvidence` and `webEvidence` arrays remain empty. Existing native handoffs
reported by the other owners were not promoted into evidence for unrelated function rows.
The inventory is the exported callable-omission inventory, not a proof that every inline action,
render-loop branch or hardware/platform behavior has been exercised.

The audit checked source function groups against actual GDScript methods, Runtime construction,
step ordering and Scene interaction/projection bindings. World/Day/Campaign and Character/Prop
owners supplied independent filename/ownership checks. Source function IDs retain their exact
module/export paths; every mapped row now points to its concrete implementation and tests.
The full-port gate checks reference existence and mapping structure; it cannot establish
semantic parity by itself.

## Implemented systems that lacked mappings

| Source responsibilities | Actual owners | Principal tests |
| --- | --- | --- |
| State, equipment, saves, death/arrest | `game_state`, `inventory`, `save_store`, Runtime lifecycle | `test_game_state`, `test_economy`, `test_full_runtime`, `test_full_scene` |
| Vendor/resident/quest/street/conditional dialogue | `vendors_core`, `resident_dialogue`, `quest_dialogue`, `street_dialogue`, `day_system`, `old_school` | Matching domain tests, `test_old_school_physical`, Scene tests |
| Melee, police, archetypes, projectiles, bosses, robbery | `combat_system`, `actor_director`, `boss_system`, `robbery_system`, real Adapter | `test_combat`, `test_bosses`, `test_robbery`, navigation/contact/departure tests |
| Recognition, concessions, discovery, hitters, high/crash | `memory_loop`, sole `game_state` timers | `test_memory_loop`, Runtime/Guidance tests |
| Routes, factions, Office, Kingdom, daily lifecycle | `progression_routes`, `campaign_system`, `office_campaign`, `kingdom_campaign`, `day_system` | Domain source fixtures, `test_kingdom_physics`, Scene tests |
| Cooking, Karaoke, four-pin puzzle, nine heist sites | `cooking_system`, `rhythm_system`, shared `lockpick_system`, `heist_system` | Domain tests, `test_cooking_runtime`, `test_site_integration` |
| Possum, freed/chained dog, dumpster/bench/phone, cans/bottles/cart | `companion_system`, `world_prop_actions`, `prop_state`, `interactive_prop_actions`, `travel_system` | Domain tests and actual projection/physics tests |
| Feed, news, calls, world events, audio/ambient | `communications_system`, `source_audio`, `ambient_audio` | `test_communications`, `test_source_audio`, `test_audio_runtime` |
| Neighborhood utility actions, zone entries, autosave, squint | `neighborhood_utilities` | `test_neighborhood_utilities`, Runtime/Scene tests |
| Journal, objective, map, actor/combat cues, ending | `guidance_view`, projection/HUD, actor HUD trio, `ending_view` | Guidance/projection/HUD/Scene tests |
| World, incident paths, character/first-person art, weather | FullWorld/Adapter, Incident owners, Roster/Animator/Rig, `weather_presentation` | World, incident, roster/viewmodel, weather tests |

Names in this table are filenames under `game3d/scripts/` and `game3d/tests/`, respectively;
the manifest contains the explicit repository paths. Existing compatibility decisions remain
in their scoped specs: source corpse/phase quirks, approved defect repairs, shared puzzle sort,
bounded extreme cooking, fixed-step combat, deferred physical placement, inside-pad departure,
first-person art and projected UI. The mapping does not silently convert an adaptation into an
unchanged-source claim.

## Actual remaining behavior and presentation

Priority is based on visible state feedback, then world character. These are implementation
gaps, distinct from the missing native/Web acceptance evidence across the whole manifest.

1. **State-driven world ownership feedback.** Source `structures.js:380,409,434` draws owned
   hideout doors, Office ownership/sign stages, six upgrade adornments and district claim signs.
   `landmarks_a.js:174` draws Kingdom state-specific site/mark/seal detail. Current
   `full_neighborhood.gd:43,333` builds static shells; its only live site-board method is
   `set_site_available` at line 84. Guidance/map state and the Office generator light work, but
   do not replace these world projections. Keep purchases/claims authoritative in their current
   owners; the missing seam is a read-only world presentation owner.
2. **Persisted wall text.** Source `structures.js:247–345` generates, validates and renders
   faction graffiti/posters. `game_state.gd:27` preserves their save keys, but no 3D owner reads
   them for generation/rehydration/drawing. Eight helper rows remain planned; source start
   aggregation stays partial because copying one exported initial state does not implement this
   per-save visual lifecycle.
3. **Scrap-dog tether.** Source `landmarks_b.js:90` draws the live dog-to-post chain. The 3D post
   and dog exist; no live tether renderer was found. It must follow the actual chained/dead dog
   lifecycle, not the unrelated Paisley leash attached to the dog-walker rig.
4. **District and local visual feedback.** Source `landmarks_a.js:224,230` blends district
   `AMBIENT_GRADES`; current Weather applies a global day/weather wash. Source
   `structures.js:368` faction-border flash has no consumer. Source `landmarks_b.js:42` includes
   an overhead-car shadow and local underpass pulse; the 3D underpass is static. The generic
   original 3D facades also do not establish every source-specific animated window/steam/sign
   detail in `structures.js:19`. These stay partial/planned instead of being hidden by static
   record-count coverage.

During this audit root corrected the separate inventory-page omission: source cred/bonus,
wanted/cart, rounding, conditional supply/hitter rows and lifetime labels are now present.
Root reported the focused FullHUD 27-check pass. `renderInventory` therefore maps to the
current FullHUD/Scene tests as integrated; no platform-evidence promotion was made.

## Other unfinished rows: classification, not new gameplay commands

The 51 non-integrated rows comprise:

| Category | Rows | Meaning |
| --- | ---: | --- |
| Concrete world visual gaps above | 18 | Ten planned, eight partial |
| Pixel-only primitives / intentionally off-camera body layers | 24 | 21 grid/raster helpers, two route-patch helpers, one player contact shadow |
| Coarse-pointer/mobile and its layout | 4 | Desktop/browser keyboard-mouse support does not implement the source touch controller |
| Start/frame/structure aggregate functions | 5 | Their implemented core does not erase the unfinished visual children |

The 24 pixel/first-person rows have replacement-owner/test references and explicit notes. They
are not silently verified, nor a recommendation to recreate pixel grids or put a chest patch in
front of the first-person camera. They need an explicit scoped-obligation disposition in the
eventual completion audit. The four mobile rows likewise require a scope disposition or an
actual touch implementation; a secondary Web export alone is insufficient.

The dynamic-emitter owner initially reported pending acceptance. Before this mapping checkpoint
closed, root reported Dynamic 149 / Scene 367 functional checks and the native visual handoff
accepted. `drawEmissiveCore`, `drawPlayerEmissives`, `drawLighting` and `prepareLightingFrame`
therefore map as integrated with real owners/tests. Their editor sync measurement still misses
its target (0.269 ms p95); performance remains open and the native/Web handler arrays remain
empty. This update does not claim a completed feature or full-frame performance acceptance.

## Validation and remaining acceptance

Exact command run:

```text
node tools/3d-parity-gate.mjs
3D PARITY COVERAGE: PASS (10317 checks; 32 features, 585 explicit function obligations; 0/32 verified, full port INCOMPLETE)
```

No `--refresh` or `--complete` was used. Before writing, a structural comparison asserted every
top-level value except `handlers` was unchanged, and all implementation/test/integration paths
were checked for existence. Root's feature-level evidence remains authoritative. Full 60-actor
release frame time, uninterrupted late-game/endless native/Web tours, real boss fight timing,
platform persistence and platform interaction coverage are still acceptance work; this mapping
pass does not satisfy them.
