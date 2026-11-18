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
