# SPEC — Read-only guidance and journal P08c

Captured before code, 2026-11-18. Parent approved pure presenter, source ordering,
the explicit journal defect repair, and narrow FullHUD objective/minimap binding.
Runtime/Scene and E interaction arbitration remain Root-owned.

## Authority and API

`RockBottomGuidanceView(state,progression,memory,office,kingdom,campaign)` keeps all
owners weak. `ready`, `primary_objective`, `objective_view(camera_yaw=0)`, `journal`,
`journal_text`, `map_static`, `map_dynamic` are pure reads. No RNG, events, mutable
p/s caches, quest normalization, eligibility changes, reward, save or timing owner.
Missing real owners fail closed with empty views; do not invent gameplay fallbacks.
Fresh/restore continue to read the current GameState through the same owner refs.
Returned dictionaries/arrays are detached. Static map geometry caches once from
the immutable content corpus; changing the live world is outside this presenter.

FullHUD exposes `bind_guidance(view)` and `set_view_heading(yaw)` for Root Scene.
It displays the authoritative objective alongside high/crash status, a readable
camera-relative direction and paces, and a north-fixed minimap. It refreshes model
views at a presentation-only120ms cadence while playing, matching source guidance
cadence; no gameplay clock depends on it. Map geometry is retained once per bind.
Root uses `journal_text()` for Q and keeps physical E prompts from its single real
aim/reach/LOS resolver. No second source `resolveActionHint` scan is added.

## Exact objective priority

Authority: `src/systems/campaigns.js545–590,645–653` and existing owner methods.

1. Unfinished intro: uncollected intro cash (fallback1180,870), then Tony1634,886,
   then Block1064,882, retaining exact progress/copy and soap-inclusive rock count.
2. Existing Office objective if an active claim/work contract exists.
3. Existing Kingdom objective, including live boss/pretender center and Block-only
   anoint objective. Call the real owner's read-only `objective()`.
4. With any real/soap rock, no high and shakes>=50: nearest currently legal smoke
   spot from Memory, retaining Block tie behavior.
5. Existing Office objective without active contract, then current route stamp.
6. First unfinished, available-not-false, non-intro quest with a target; crown uses
   its current uncollected pickup. Finally the source idle objective at the player.

Source object insertion order is semantic. Stable exported JSON alphabetizes
keys, so use the explicit24-ID source order from runtime_ui.js449–479, verified by
unchanged-source oracle. Unknown additive quest IDs follow known IDs in their
existing insertion order; no invented target exists for an unknown quest.
Source hustle reward prose orders cash,cred,brain; notably Possum is cred then
brain. Preserve that order rather than JSON alphabetical order.

Source HUD HERE is distance<28px; otherwise ceil(distance/10), minimum1 pace.
Source octant HERE separately uses abs(dx)<24 && abs(dy)<24. JS Math.round ties
use floor(value+.5), including negative halves. `objective_view` retains source
target/direction/pace fields and adds camera-relative bearing for first person:
yaw0 faces source north (negativeY), positive Godot yaw turns toward negativeX.
The relative direction display adapts to camera orientation; this does not alter
the selected target or action legality. World projection/ring integration stays
Root Scene-owned. There are no new waypoints, teleports, tutorial or path grants.

Central counterexample: V8 and Godot/libm `atan2` differ by an ULP for synthetic
exact octant bisectors, e.g. (-38.268343236509,-92.387953251129). Approved
presentation-only compatibility: snap the octant quotient within1e-12 of a half
to that half, then floor(x+.5). The unchanged V8 output remains in each fixture;
the stable tie result is a separate expected field. Points1e-9 radians on either
side still require the exact V8 direction. No target/action/state changes.
Root must record this executed compatibility decision alongside the journal fix.

## Complete Q content

Authority: runtime_ui.js166–356. Structured `journal()` sections and text include:

- What to press (approved first-person left-mouse attack/look controls, existing
  WASD/arrows,Shift,E,I,Q,F,P,M,Escape); NOW uses the same primary objective.
- All three route stamps, serial/filed count, done/current markers and source zone.
- Office locked/unlocked/owned copy, active claim/work stage, daily cap/count,
  lifetime work, all11claim marks and six-upgrade count.
- Kingdom locked requirements or stage/seals/corrections/pretenders and four
  cleared district marks; read state, do not advance or reconcile progression.
- Today’s hustles, exact `hustle_progress`, rewards and done marks.
- Active/latent/done quest sections using title/flav, exact reward preview, source
  intro filtering and available-absent=true semantics. Done rows omit reward copy.
- Three faction values/tier labels and normalized bar metadata; four regular
  venues with totals/tier/each recorded verb and Memory concession/discovery line.
- All ten source activity rows and the source met-vendor index metadata/denominator.

The index looks up live actor names including source dead records; missing actor
falls back to uppercase ID. Stale source metadata remains literal, including the
priest's inaccurate '-30 shakes' tag; no gameplay effect or prose repair is implied.

## Source defects and approved 3D adaptations

1. The active modular `renderQuests()` references bare `npcs` at line219, which is
   undefined once a known vendor is met. Actual unchanged execution is captured
   as a ReferenceError fixture. Approved 3D repair uses GameState.npcs. Intended
   remaining source HTML is characterized separately with a harness-only global
   binding to the actual runtime.npcs, never by editing production JS. Register
   the repair when integrated; do not describe the crashing original as passing.
2. Source's120×96 minimap is always displayed, with no map hotkey or travel action.
   Retain north-fixed zones→roads→facades→rails→claims/clans→office→NPCs→objective
   →player ordering. Scale the widget for readable desktop/Web presentation.
3. Replace the meaningless2D viewport rectangle with a first-person player heading
   triangle. Relative HUD direction rotates with the camera; source coordinates,
   exact paces and source octant remain available for oracle comparison.
4. Source map shows living NPCs even when their daytime art is hidden. Preserve
   that information rule; dead/departed records are omitted (departed is the
   approved physical-exit adaptation). Preserve Tony/cop/hostile/neutral colors.
5. Main objective remains visible during high/crash as in source; status moves to
   separate text so the existing source target is not overwritten by a timer.

## Verification and limits

Unchanged-source fixtures cover all priority branches, active contract vs kingdom,
legal smoke conditions/ties, source quest order, all24quest classifications/rewards,
all14hustles, faction boundaries, all regular-venue lines, vendor naming, stage and
map marker conditions. Journal compares normalized rendered source text separately
from the documented first-person control adaptation. Map compares actual source
draw calls where relevant. Property checks prove repeated views do not change
p/s/actors/events/RNG, detached outputs cannot mutate owners, missing weak owners
fail closed, and heading/layout stays finite. Exact completion guards are required.

Model and headless HUD gates do not prove native/Web readability, world-projected
target visibility or physical route validity. Root must bind the real view, inspect
both targets, retain performance evidence and reconcile the parity manifest.

FullRuntime now constructs the pure Guidance owner after real Kingdom composition. FullScene binds it once, forwards actual player yaw and renders Q from journal_text. High/crash continue their own status readout beside the objective. No gameplay clock or duplicate E dispatcher is installed.
