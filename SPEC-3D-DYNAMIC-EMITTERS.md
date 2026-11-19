# P14e — fixture-backed moving lights

Approved before code, 2026-11-18. This is presentation only. Weather's existing39 static
fixtures, Combat, actor scheduling authority, player timers, RNG and persistence stay owned
by their existing systems. Root supplies actual animated attachment transforms and forces
eligible beacon actors to update poses when later applying presentation culling.

## Source and approved adaptations

`landmarks_a.js274–282` selects alive/unhidden actors with `isCop` or sprite `cop`/`horsecop`.
Brendan qualifies through isCop; Horse Cop qualifies without it. Four wanted cops plus the
resident Horse Cop require five normal beacon slots. Source blue field #4868d0 is steady,
power .62 and level max(.34,nightAmount), radius104px. Only the two visible blue/rust lenses
swap every150ms (`actors_weather.js56–60`); this is not a flashing/red world light.

Player light requires `rockedT>0 || hitterHigh`, independent of equipment. Source radius48px,
power .62, level max(.36,nightAmount), fire #d06030, core ember, no shadow. Source item masks
separately make the visible weapon pipe tip and propane-tool pilot emissive at all times
(`sprites.js30–33`, `actors_weather.js67–78`); these do not create extra world lights.

Use source coordinate-scaled ranges4.16m/1.92m and exact source piecewise night curve via the
existing Weather pure helper. Fixed pool: five cop OmniLights plus one player OmniLight,
all shadows OFF as the approved 3D performance adaptation. The source's 2D contact-shadow
direction does not justify allocating six new real-time shadow maps. No nearest-light drop.

Existing cop rigs have caps but no beacons. Five cached original two-lens fixtures sit on
actual cap tops (hair-style local y.24); Horse Cop binds the rider's head, never the horse.
Root provides `Art/head/hair_style.global_transform`, or
`Art/mounted_rider/head/hair_style.global_transform`. The fixture base touches the cap and
its actual lenses motivate the light. Missing/invisible/nonfinite anchors never emit.

There is no existing smoke mesh in the first-person rig. Add one abstract camera-mouth copper
stub, with a low visible bowl/ember, independent of both hands and equipped items. Stem runs
from (.09,-.22,-.085) toward (.12,-.21,-.23); bowl center(.14,-.205,-.30), radius about.022m,
height about.035m. Its back enters from below the frustum; all geometry remains behind the
.06m near plane. It has no functional detail, preparation, particles or new action.

Rig context adds optional bool `high_ember`, atomically validated with existing fields and
cleared by reset. Root supplies the exact current high/hitter gate. The fixture is visible
only while this gate and existing rig visibility hold AND no acknowledged action is active.
It stays visible through idle/walk/sprint/cart; any existing gesture/punch stows fixture and
light together, then restores only the CURRENT high gate. This brief gesture priority is an
approved 3D adaptation. No hand pose, tool/weapon selection, input, transaction or timer changes.

## API and ownership

New `RockBottomDynamicEmitters.create()` returns an unparented presenter with its fixed pool.
`sync(snapshot:Dictionary,visual_ms:float)->bool` takes detached values:

```
{dayTime: 0..1,
 cops: [{id:String,isCop:bool,sprite:String,dead:bool,hidden:bool,
         visible:bool,cap_transform:Transform3D}],
 player: {rockedT:number,hitterHigh:bool,visible:bool,ember_transform:Transform3D}}
```

Root supplies at most five current live qualifying actor rows, or zero. The exact source
predicate remains available as `qualifies_cop(record)`; actual model visibility is an
additional fixture requirement. Nonqualifying rows do not become lights. Transform is
required only for a qualifying visible fixture. Source numeric/string/bool fields must be
finite and typed; invalid input clears the presentation and returns false, never leaves an
orphan stale light. `clear()` hides the six lights/fixtures without freeing pooled resources.
`inspect()` exposes detached counts/levels/phase for bounded evidence.

FirstPersonRig adds `emitter_anchor(kind:StringName)->Node3D` for cached markers `player_ember`,
`weapon_pipe`, `torch_pilot`. Marker positions correspond to actual authored tips, not the
mesh-node origin at the wrist. Root caches the player marker; visible state must include its
ancestors. Item tips select immutable emissive materials at construction; no new OmniLights.

Root calls sync after actual actor/hand poses, with existing render wall milliseconds. No
owned Time queries, delta accumulation, autonomous processing, physics query, actor traversal,
input, audio or gameplay reference. Six lights/at most five beacon bodies are created once;
meshes and immutable base materials are shared, while per-presenter pulse/level materials are
independent. Ordinary frames only update cached transforms/energies; lens swaps happen on the
150ms phase boundary. The caster/recipient render cost still requires native measurement.

## Evidence and scope

Owned new dynamic_emitters.gd, test_dynamic_emitters.gd, dynamic_emitters_probe.gd and this spec;
narrow first_person_rig.gd context/fixture/marker/emissive-material changes only. Root owns
FullScene, engine/import/native/Web/Git. Other accepted source remains held.

Tests cover exact source gates including Horse Cop/Brendan, five plus one budget, source night
levels and lens phase, no red/blinking field, absent/dead/hidden/freed fixture cleanup, independent
cached resources, actual mouth/weapon/tool geometry anchors, gear/cart unchanged, gesture stow
and current-high recovery/reset. Native evidence includes both lens phases, actual rider cap,
day/night receivers and mouth fixture with fists/tool/weapon/cart plus gesture absence. Target
incremental sync CPU p95 <=.2ms, zero queries, zero dynamic shadows; no whole-frame acceptance
claim without root profiling the six active lights.

## Bounded setter optimization after native review

The first native pass accepted all16 fixture/gesture views but measured sync p95 .290ms
against the unchanged .2ms target. Keep the same fresh validation of every supplied row,
including typed fields, duplicate IDs and finite/nondegenerate transforms on every call.
Do not memoize input dictionaries, snapshot identity or validation results.

Cache only the presenter's last applied visibility mask and scalar light/emission outputs.
Skip identical renderer property writes; when a slot changes activity, write its visibility
and its active energy or zero immediately. `clear()` still disables every previously active
fixture/light, including invalid-input cleanup, without repeatedly notifying the renderer for
already hidden zero-energy slots. Construction uses an uninitialized output sentinel so the
first clear hides the engine's default-visible nodes. Existing transform equality checks,
150ms lens phase, public API, tests and native .2ms acceptance threshold remain unchanged.
