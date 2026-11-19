# P14f — dog leash and faction border cue

Approved before implementation, 2026-11-18. This packet projects existing source facts;
Combat, Companions, Progression, Runtime and FullHUD retain all gameplay/timer/tint authority.

## Source contracts

`src/render/landmarks_b.js:90–113` finds the leash post and the first living actor whose
id is exactly `scrap_dog`. It does not inspect `chained` or `hidden`. Preserve that quirk:
the attacked living original still has a leash after Combat clears `chained`; freeing the
original sets it dead and removes the leash. Never attach to `freed_dog_follower` or Paisley.
The source uses two bent dark strokes and five lighter dots. Six narrow 3D segments and five
small links, with a downward sag of at most .16m, are the approved first-person adaptation.

`src/core/update.js:288–304` runs immediately after updateTerritory: decrement positive
borderGlowT, then compare lastZoneId to territoryZoneId (null when absent). If different,
arm600ms only when currentZone exists, the prior id is non-null and currentZone.id differs
from the prior id. Update lastZoneId even when no flash is armed. This preserves the existing
2s territory ticker delay, no first/null-to-zone flash, no zone-to-outside flash, and a flash
between different zones even when they share a faction. Destination colors: street#a04848,
scrap#c08038, spiritual#d8c068, otherwise#888. `structures.js:368–379` draws a3px world-rect
outline with alpha=min(.55,borderGlowT/600*.55). The first-person adaptation is a3px viewport
perimeter, transparent center, with those exact colors/alpha. No extra district title/toast.

## Leash view and anchors

New `RockBottomDogLeashView.create()` returns an unparented Node3D with exactly two pooled
MultiMesh instances: six dark segments and five worn links. All meshes/materials are cached;
instance transforms are private. No dynamic shadows, lights, collisions, queries or RNG.
`sync(snapshot:Dictionary)->bool` accepts:

```
{post_present:bool, dog:{id:String,dead:bool},
 post_position:Vector3, collar_position:Vector3}
```

An empty dog means absent. Nonqualifying/dead dog or absent post clears successfully without
requiring endpoint values. Invalid active input clears and returns false. Finite coincident
endpoints hide the zero-length chain successfully. Chained/hidden fields are deliberately
irrelevant. `clear()` hides pooled geometry; `inspect()` returns detached bounded observations.
No retained actor dictionaries or autonomous processing. Only changed local endpoints rewrite
the fixed11 transforms; parent transform changes are accounted for through local conversion.

FullNeighborhood's existing leash_post cylinder gets a stable `LeashPostAnchor` on its actual
surface plus a small metal staple. `leash_post_anchor()` returns the marker without traversal.
The original post collider and position stay unchanged. This branch is disjoint from current
office/ownership work. The marker survives static mesh batching.

CharacterRoster adds `leash_collar` only to the scrap_dog visual. Its rest point is an actual
vertex of the existing broken_link mesh; template construction records that point's existing
four skin indices/weights and inverse binds. The existing attachment update computes that one
weighted point after changed poses, without changing any mesh, skin weight or bone. Root can
cache `Art/leash_collar` and supply its current global position after the actor pose pass.
Pose culling must refresh the dog when the leash is visible, or on re-entry before sync.

## Border view and pure timing helper

New `RockBottomDistrictBorderView` extends Control, mouse_filter IGNORE, no process/input.
`sync({remaining_ms:number,color:String,visible:bool})->bool` validates fresh input and draws
only the3px inset perimeter. Invalid input clears. `clear()` and `inspect()` are presentation
only. Resize redraw follows the full-viewport Control; parent/HUD tint is never modified.

Static `advance(previous:Dictionary,territory_zone_id:Variant,current_zone:Dictionary,
delta_ms:float)->Dictionary` is a pure calculation returning the four source fields
`borderGlowT`, `borderGlowColor`, `borderGlowRect`, `lastZoneId`; it never mutates previous or
zone and owns no history or timer. Missing prior fields use source-falsy defaults. It returns
an empty dictionary for malformed inputs. It consumes the caller's accepted active step.

Root integration after `progression.tick_territory(step,...)` and before existing zone-entry
utilities: call advance with current s, s.get("territoryZoneId"), current_zone and step;
copy only the returned four fields into s. As in the source, query progression.current_zone()
only when lastZoneId differs from territoryZoneId; otherwise pass an empty dictionary.
Do this in the existing active-world path
only: pause/modal/hitpause/cooking retain their current clock behavior. Do not use wall time or
add a second decrement. Root supplies current source fields to the separate Control, placed
under modal chrome. Its visible input is world-visible AND a present nonempty borderGlowRect,
matching the source render guard; title/reset cleanup clears only the view.
Existing high/crash tint, current-zone status, first-entry toasts and faction effects remain
owned by their existing systems. Source border fields are not newly persisted.

Explicit epoch-reset adaptation: retain the existing full-3D fresh/load policy in
SPEC-3D-STATE and SPEC-3D-FULL-PORT. A new state epoch resets the entire transient
territory/border tuple to defaults. The source browser retains those11 fields within
one page session, including its partially elapsed2s territory tick. Carrying only
the four border fields would be incoherent; carrying the gameplay ticker would change
the established3D timing policy. This packet adds no carryover. Cold startup and new
epochs have no flash; view clear alone never mutates a continuing runtime epoch.

## Validation and scope

Own new presenters, this spec, focused tests/source oracle/fixture/native probe; narrow Roster
weighted marker and FullNeighborhood post branch/accessor only. Root owns Runtime/Scene/HUD,
all Godot/import/native/export/Git. No broader art edits.

Gates compare pure timing against unchanged source-extracted statements, including ticker
delay, same-faction crossing, neutral/null transitions, paused calls and a long active step.
Leash tests compare the marker against actual weighted mesh vertices through idle/yaw/hurt,
verify alive-only/id/freeing gates, missing/malformed/coincident input, shared immutable meshes
and independent transforms. Border tests cover resize,3px/alpha/colors, no mouse interception,
no parent tint mutation and no RNG/model changes. Native proof uses actual world post and dog
plus each faction border under existing high/crash tint; images and incremental costs must be
reviewed centrally. Fixed budget:2 leash draws,6 segments,5 links,0 queries/lights/shadows.

Verification handoff: `node tools/leash-border-oracle.mjs --check` passes20 border and11 leash
cases against unchanged source. Central Godot gate is
`--headless --path game3d --script res://tests/test_leash_border.gd`; native evidence is
`--path game3d --script res://tests/leash_border_probe.gd -- --output=<absolute-directory>`.
The native probe records15 views and independently reads actual MultiMesh transforms; the
headless gate compares collar position with an independently skinned final mesh vertex.
Engine/visual/performance acceptance is pending central execution, not inferred from source.
