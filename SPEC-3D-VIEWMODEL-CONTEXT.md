# SPEC — First-person weapons and contextual gestures P05c

Captured before code, 2026-11-18; parent approved the bounded projection API and original art.
Authority: src/minigames/activities.js428–440 weapon catalog; combat.js137–242 instantaneous
accepted swing; existing P01 hand contract and tests. No Runtime, Scene, gameplay, source2D,
damage, cooldown, RNG, inventory, timers outside presentation, audio or save ownership changes.

## Backward-compatible API

Keep create(), reset(), tick(delta,actual_local_velocity,sprint,high,crash,shakes,look_delta) and
the existing three acknowledge arguments. Add:

```
set_context(snapshot: Dictionary) -> bool
acknowledge(kind: StringName, success: bool = true, contact: bool = false,
    used_weapon: StringName = &"") -> void
static supported_weapons() -> Array[StringName]
```

Known context fields are weapon, seated, visible and walk_speed. Omitted fields retain their
current values. The canonical weapon must be a String/StringName; seated/visible are booleans;
walk_speed is finite1..10m/s. Validate the complete supplied known context before applying any
field; malformed/unknown weapon input is an atomic no-op. Ignore unrelated snapshot fields.
Never retain caller dictionaries. Reset restores default fists, visible standing hands and the
slice3.6m/s normalization; root reapplies current context after fresh/load/death. Full mode passes
walk_speed5.5, giving bounded cosmetic motion through its existing16.83m/s high/sprint peak.
These presentation clamps never alter source movement or camera transforms.

An accepted punch captures used_weapon when supplied, otherwise current context.weapon. That
capture remains immutable for the entire visual swing. A bottle hit that equips a new weapon
therefore finishes the original fist/weapon motion, then shows the new resting item. Root must
pass Combat's original accepted weapon in the event; the rig never infers the damage weapon
from later inventory state. Invalid explicit used_weapon refuses only this visual acknowledgement.
Existing callers with no context retain alternating empty fists and their current API/markers.

## Original art and poses

| Canonical ID | Held art and grip | Source swing family / visual recovery budget |
|---|---|---|
| fists | existing articulated bare hands | arc, existing.24s |
| pipe | worn capped copper tube, fingers around shaft | pipe,.28s |
| brick | chipped rectangular brick, palm/edge grip | thud,.32s |
| cart_wheel | rubber tire, axle and metal fork | spin,.22s |
| shoe | Tony's worn brown shoe, heel grip and visible sole | sole,.29s |
| baguette | faceted stale bread with scoring | crumble,.20s |
| microphone | rubber cord and plug only; no invented microphone head | whip,.30s |
| knife | taped handle and original flat blade | stab,.22s |
| broken_bottle | opaque dirty glass neck and jagged broken rim | jagged,.25s |

The right hand holds equipped items low beside the central sightline; the left remains relaxed.
Each grip has its own finger/thumb curl and a stable wrist-mounted grip marker. Armed attacks
use the dominant hand and weapon-specific arm/wrist/prop motion, with immediate visible movement,
contact compression and a brief recovery shorter than the source cooldown. No animation callback,
contact frame or recovery phase controls combat acceptance or consequences. A new accepted swing
can always replace the old cosmetic motion. Empty fists preserve alternating left/right punches.

Meshes/materials are original cached resources, built once per rig construction and shared across
instances. The small cord uses cached articulated segments, with no rope physics or per-frame mesh
creation. A hidden fixed camera-local weapon pool parks unselected geometry safely; only the
selected item mounts to the wrist. No world shadows, collisions, areas, audio nodes or process
callbacks. Per-instance pose state is independent; shared resource state is immutable.

## Context acknowledgements

Retain interact, pickup, receipt, eat, abstract smoke and equip. Add phone, bench, dumpster and
kick acknowledgements only after successful authoritative outcomes. Phone is a short edge-of-view
hand/receiver motion; bench lowers/supports the hands and seated context changes resting posture;
dumpster is a brief downward open-hand reach; kick can use a bounded low leg/shoe silhouette when
native review supports it. Nothing opens a menu, spends cash, collects loot, changes sitting state
or delays interaction. Repeated cosmetic receipts coalesce with no queue and cannot displace an
accepted swing. Equipment may be temporarily hidden during an incompatible food/phone gesture,
then return to the current context. Smoke remains abstract with no procedure or real paraphernalia.

The camera center and0.06m near plane stay clear; all visible and parked geometry remains finite
under maximum look, shakes, high/crash, actual gait and sprint. Menu visibility hides the rig without
driving its clock. Pause/resume/death behavior remains root-owned; no extra wall time enters here.

## Evidence and boundaries

Keep the existing41 test_viewmodel checks unchanged. Add test_viewmodel_context.gd for exact
catalog coverage, independent rigs/shared resources, real grip/geometry bounds, all armed action
phases, original-weapon capture through equip, invalid atomic context, standing/seated/menu/reset,
context gestures and full5.5/16.83m/s motion. Add viewmodel_context_probe.gd for actual native captures
of all held weapons at rest/contact/miss/recovery and each context gesture. Parent runs engines
and reviews images before visual acceptance; passing mathematical bounds does not prove a good grip.

Owned: this spec, first_person_rig.gd, new test_viewmodel_context.gd and viewmodel_context_probe.gd.
No edits to existing test_viewmodel, Runtime/Scene/Combat or source2D. Root supplies the accepted
weapon event field and context snapshots, and performs engine, integration, export and git gates.

Root composition clarification: dumpster reach follows a committed withdrawal/loot choice or source climb-out. Opening the modal emits no frozen hidden reach, so Escape cannot replay a stale entry motion on resume. Food keeps its eat gesture; phone/bench/kick remain active-play acknowledgements.

Native refinement: the bottle rim uses uneven broad tangential glass wedges and one deep
notch, preserving neck/grip/material/cache. The active kick raises the shoe and connected
cuff into the lower78-degree view; hidden rest, duration and input semantics are unchanged.
The context gate checks actual shoe/cuff vertex projection at the visible action phase.

## P05f — relaxed empty hands, captured before implementation

The actual 1280 Block and 960 crash captures show mirrored, nearly flat palms. Retain
the authored palm/digit meshes and add a separate empty-hand relaxation profile: the
left wrist rests slightly lower and farther back, both wrists turn away from the flat
forward presentation, and fingers curl progressively from index to little finger with
a quieter thumb spread. Neither hand becomes a permanent guard fist. Existing gait,
sprint, breathing, look and crash motion remain the only stance clocks.

Apply this profile only to a hand with no equipped/captured weapon, tool or cart grip.
Do not change the shared grip evaluator: all weapon/tool/cart finger and wrist anchors
keep their current transforms. Blend the empty profile out with the existing action
envelope and restore it through recovery, including phase zero and the action-to-idle
boundary. Full-extension fist contact keeps the existing pose, cuff clearance, immediate
acknowledgement and duration. No cosmetic queue or interpolation delays accepted combat.
Replace only the pickup/dumpster open-to-close finger discontinuities with short smooth
phase transitions; their acknowledgement, reaches, peak/end timing and outcomes stay
unchanged. No geometry, shared resource, API, camera, input or model changes.

Extend the existing context gate with actual skin geometry/projection at 1280x720 and
960x540, reflected palm/digit asymmetry, nonuniform relaxed joint flexion, uninterrupted
gesture start/recovery, unchanged occupied grip poses, and finite near-plane/center
clearance during gait/crash/sprint. Retain the original 41 P01 checks unchanged. Extend
the context native probe with both sizes, empty idle/crash/walk/settle/sprint, pickup and
dumpster transition poses, and alternating fist contact. Native review remains required;
mathematical bounds alone do not establish that the new stance reads naturally.

## Committed core-vendor receipt gesture (2026-11-19)

The existing vendor_action event may acknowledge the existing receipt gesture
once at its original queue position. Require actual boolean success and one exact
canonical pair:Tony buy_rock/short; Yuri sell_copper/sell_all_copper/rent_shed;
Pete sell_copper/sock/sell_license/sell_junk/buy_food/buy_torch/buy_crowbar/loan.
These thirteen actions commit their source transaction before this projection.
Third-offense short still spends5 dollars and starts its unchanged consequence.

Exclude ordinary talk, leave, challenge, refusals, stale capabilities and the
free swap_tools action. Do not infer a transaction from cash, sound or toast.
Do not also acknowledge from menu selection, enqueue a delayed receipt, change
the0.32s gesture clock or interrupt an accepted punch. Existing pause/reset/tool
context and action priority remain unchanged; no model, RNG or event mutations.

The existing FullScene gate consumes actual source-owner events for all13 pairs,
tests excluded/malformed/stale paths and one-time consumption, and retains its
completion guard. Actual native/Web paid transaction originals remain required
for visual acceptance; the model extension alone does not establish appearance.
