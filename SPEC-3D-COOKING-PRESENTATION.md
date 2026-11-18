# SPEC — The Heat presentation

Captured before implementation, 2026-11-18. Root owns Cooking, Runtime, input and scene
integration. This packet owns only the new CanvasLayer, its tests and this addendum.
Source: `src/minigames/heat.js` drawHeatMini, heatOutcomeLabel and drawSmokeOverlay.

## Pure view API

```gdscript
# cooking_presentation.gd — RockBottomCookingPresentation extends CanvasLayer
func update(snapshot: Dictionary, player: Dictionary, smoke_ms: float, delta: float) -> void
```

Root passes Cooking.snapshot() only while the model mode is cookmini; otherwise it passes an
empty dictionary. Smoke time is supplied independently in every mode. The view never calls
Cooking tick, tick_presentation, lock, bail, cancel or resource methods. No automatic process,
gameplay timers, event emission, input ownership, RNG, resource settlement or lifecycle changes.
It retains only detached sanitized display fields. Delta advances a bounded decorative smudge
phase; it never changes heat progress, hold duration, smoke duration or resolution progress.

All Controls use mouse_filter IGNORE and focus NONE. Space/1/Enter/click/tap/Escape remain one
root-owned action path. The heat display contains no second set of interactive buttons.

## Source display and scoped adaptation

The centered asphalt panel has a sodium border and a full-viewport black dim layer at .78.
It adapts to available viewport width and wraps subtitle/help text rather than clipping them.
At 1280×720 it leaves the top resource plate and bottom meter areas unobstructed by the panel;
the dim layer is intentionally behind the panel, matching the source. The overlay uses logical
viewport coordinates under canvas_items stretch, including narrow/resized browser views.
Below the readable panel's natural minimum height or width, scale the complete panel together
to the available viewport with margins; never clip individual labels or drop the locked result.
Normal desktop and narrow portrait sizes retain their authored font sizes.

Title is `the heat.`. Mode labels are low and slow / fast cook / shaky special / cook all /
propane. Subtitle is `<mode> — <n> packet[s] — clean × <clean> + dirty × <dirty>`, reading current
dirtySupplies, with dirty=min(n,dirtySupplies) and clean=n-dirty. Source labels remain exact:

- fill: `space / tap — lock the heat. esc — walk away.`
- idle: `you're letting it burn. tap to save it.`
- outcomes: perfect. / ok. / bad cook. / burnt. / never set. / soap.

The bar displays supplied progress, sweet interval/center, burn interval and a separate locked
marker whenever lockedAt is non-null, including zero. No second outcome calculation occurs.
The source bright-blue/green gradient is deliberately replaced by mold → sodium → rust →
asphalt, preserving its positions and hot-end darkness under VIBE's 3D palette constraint.
Sweet fill/border, center tick, cream needle and thicker sodium locked line remain readable.
Hold displays the supplied outcome in uppercase, using source yellow/rust/purple/cream colors.

The approved bounded finalization adds phase resolve. Keep its locked result visible, replace
input instructions with `the batch is settling.`, and show optional actual processed/total
counts only when snapshot.resolution supplies finite integral processed/total values. Current
Cooking snapshots omit that field; absence shows no invented percentage or time estimate.
Unknown phases suppress input instructions. Unknown/malformed display fields never create
nonfinite rectangles, text exceptions or implied gameplay authority.

Smoke reads clamp(smoke_ms/2000,0,1) on every update: source gray-brown haze at .85×alpha,
six dark moving smudges at .6×alpha, and `the smoke is in the floor.`. It draws below heat and
can remain visible with an empty heat snapshot. Zero/nonfinite smoke hides it immediately;
repeated updates with unchanged smoke_ms cannot decay it locally.

## Evidence

Properties use real Cooking snapshots plus malformed/extreme inputs. Verify exact copy and
plural counts, supplied-outcome authority, locked endpoints, sweet/burn/needle bounds, no
input capture, detached snapshots, no state/RNG/events/resource mutation, no invented phase
advancement, independent smoke visibility/alpha, honest resolve counts and viewport resizing.
Root captures fill/idle/hold/resolve/smoke at 1280×720 and a narrow viewport, then exercises
actual root keyboard/click/Escape controls. Passing view tests does not claim full integration.
