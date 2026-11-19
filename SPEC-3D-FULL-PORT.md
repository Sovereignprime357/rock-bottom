# SPEC — Full first-person 3D port

Captured 2026-11-18 before implementation. Operator requests full pixel-game parity, improved
textures/animation/interactions, natural hand positions/gestures, more NPCs, a moderately higher
polygon budget, and bounded agents continuing until complete. Branch `codex/3d-full-port`;
baseline `c9d61d2ce25d60737af2140206999d1242b260fa`.

## Scope and source authority

The active v22 modular game (`index.html` / `src/`) is the behavioral source; frozen v19 stays
untouched. `game3d/` remains Godot4.5.1/GDScript, Compatibility, Windows primary, single-threaded
Web secondary, original geometry/materials and synthesized audio. The full-port request
supersedes the slice-only scope restriction; it does not assert current parity. Existing
art/input/save contracts stand until a specific parity amendment replaces a slice simplification.
VIBE voice, identities, palette and hard stops remain. Existing canonical cast supplies new NPCs.

Parity means reachable player actions, state transitions, costs/rewards, governors, dialogue
beats, identities/roles/threats, progression, world coverage and persistence. Decorative actors,
menu labels or counters alone do not satisfy interactions. Camera, input targeting and physical
presentation adapt to first person. Source and documented exceptions outrank recollection.
External live-AI features retain an offline playable path; no credentials or new service are added.

## Integration architecture

One simulation authority owns resources, timers, durable state and action validation. Bounded
subsystem modules compose it; they never introduce parallel resource/timer/save owners. Scene
code owns input, camera, physics and presentation; menus submit validated actions. Static source
content may be exported deterministically to local JSON with source hashes and a check command.
Execution on native/Web requires no Node or CDN. Imported content is data, never executable eval.

Port equipment/inventory, stats/ranks, wanted/arrest/death, factions/territory, quests/routes,
office/kingdom, minigames, hideouts, recognition/concessions/discovery, robbery/heists/break-ins,
communications/incidents/day events, traversal/cart, every associated actor role and prop.
Preserve exact18s high/8s crash, soap/hitter distinctions, one ignition path, active-time clocks,
real line of sight, bounded daily grants and duplicate-spend protection. The parity ledger names
omissions until implemented and exercised. No new tutorial, redemption ending or cutscene story.

Persistence remains separate from 2D. Extend the 3D schema additively with schema1 migration,
guarded normalization and ephemeral combat/timer reset. Native uses the existing file adapter;
Web uses async window.storage/IndexedDB. No localStorage/sessionStorage. Saves await persistence
and expose errors. QA uses isolated files/namespaces. Coordinate changes require a real migration,
not arbitrary clamping into walls. Clear-placement recovery remains.

## World and actors

Represent every source zone, structure, interactive prop, route endpoint and canonical spawn.
Preserve spatial relationships and travel-time budgets when mapping pixels to metres. Standing
solids have matching physical collision; elevated decoration cannot block ground paths. Service
points remain visible/reachable without jumping. Test actual generated geometry/routes, not only
ID presence. World actors cannot speak generic no-op dialogue in place of canonical functions.

Use reusable authored rigs with per-identity silhouette/clothing/props. More polygons are
authorized where they improve faces, hands and articulated joints. Cache geometry; use spatial
batching and distance-aware art/animation scheduling. Simulation remains correct when art is
culled; governors or threats cannot silently stop off screen. Measure60+ actual NPCs separately
from art-only stress, with hardware/resolution/quality conditions and CPU/render/AI costs.

## First-person embodiment

Hands rest low with a relaxed silhouette and clear center. Actual locomotion drives bounded
arm swing/breathing; sprint lowers/changes the swing. Punches alternate with contact/recovery
readable at eye level. Combat owns damage/cooldowns; animation never mutates gameplay. Contact
results drive visual response. Improved presentation must not add an undocumented delay to hits.
Interact/collect/eat/smoke/equip gestures acknowledge successful actions only, briefly. They
cannot mint resources, delay timers, block camera control or strand a menu. Look sway is damped
and bounded; no viewmodel shadows or eye-plane clipping.

Pose controllers expose reset, action and tick APIs, advancing only in active play. Dialogue,
pause/focus loss freezes poses; new game/load/death resets them. Tony never blinks, Pete eats,
the possum has a route; animation serves the identity. Inspect rest/walk/sprint/look, both punches,
contact/recovery and contextual gestures visually. No per-frame mesh regeneration.

## Acceptance

`WORKFLOW-3D-PORT.md` bounds ownership and acceptance. Each parity row requires source refs,
implementation refs, production integration evidence and independent review. No placeholder or
partial row becomes complete merely because a test/ID exists. Preserve the original gate runner
and expand the separate3D runner; never weaken sprite/physicality/loop contracts.

Counterexamples include malformed saves, duplicate spending, daily rollover, death/respawn/quest
combinations, capture/refusal, modal exits, resource exhaustion, weapon/boss/police transitions,
campaign and post-coronation loops. Tony must be defeatable in under90s by a competent player;
smoking remains necessary. Exercise native and Web end to end and inspect eye-level evidence.
Rebuild both targets, profile the full world/cast, and retain comparison artifacts.

Complete means every parity row and visual/interaction criterion passes, a playable local entry,
named committed/pushed branch, green gate output, touched-file list, BRAIN history and executed
decision records. Public hosting is a separate deployment action. Keep the goal active until
all required port, review and delivery work is achieved.


## UI parity correction — action boundary and source receipts

The first-person E resolver refuses action while player stunT>0, as the source keyboard does;
read-only I/Q and pause remain usable. Source transaction callbacks retain their own existing
validation. The Q view uses quest title/flav and source intro filtering, includes missing
available as active, and distinguishes latent/done entries. Known but unearned venues expose
only their source discovery text/leave; conceded rooms show the source condition and a disabled
smoke option when unavailable or already high. Toast events retain their declared milliseconds
through the shared HUD rather than silently becoming four-second receipts.

The read-only Q journal and I inventory close on their own shortcut or Escape on both desktop
and Web. This matches the journal's visible close instruction. A presentation-only menu key is
cleared on every new menu/resume so these shortcuts cannot close or submit unrelated transactions.
Key repeats are ignored. Web Escape on other dialogue pages retains the existing pause behavior;
the ledger exit resets capture acquisition before any new pointer-lock request.

### Cart and incidents production composition — 2026-11-18

Scene selects dynamic cart geometry before World builds, adopts/publishes the cart
before actor placement and interactive staging, and enables incident owners only
after all dynamic colliders and a physics frame. Runtime retains strong references
to the incident model, path map and corridor adapter. The Scene retains their one
presenter and updates it from detached model snapshots and its existing visual time.
Incident ticks run after ambient phone/hustles, before random events and interactive
respawn. Refused certification emits a deduplicated dependency event, freezes the
incident transaction only and retries when geometry permits; ordinary play continues.

Successful fresh/restore replaces core state, resets Props, clears the old cart
physical epoch, releases incident reservation via reset, resets/publishes Travel's
current cart and then stages interactive props. WorldProps fresh phone initialization
precedes the24 bottle draws; restore's single incident delay draw also precedes them,
as in source. Source cart parking continuity and unsaved reset behavior remain Travel's.
Cart receipts synchronize geometry before other physical effects. E cart selection is
after phone and before dumpster, with strict source36px and aim/LOS for mounting;
mounted dismount requires no aim after earlier source targets miss. Hands read actual
camera-local handle markers each active pose and explicitly clear grips on release.
