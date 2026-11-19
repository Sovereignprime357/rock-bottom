# P05d — authored world pickups

Status: bounded presentation packet; central gates and native review pending.
Parent owns Runtime/Scene integration, engine runs, exports and release evidence.

## Source contract and supported variants

Read `VIBE.md` first. This extends the original native 3D art pipeline, without external
assets or changes to the existing 2D release. `src/render/frame.js:97–163` is the visual
authority; `src/core/update.js:596–645` and the existing Runtime remain collection owners.

| Source record | Visual kind | Authority and precedence |
| --- | --- | --- |
| `cashPiles` ordinary/intro/inheritance/badge/phone/night cash | `money` | All share the source banknote drawing; amount does not create extra physical loot. |
| `cashPiles.tool == "propane_torch"` | `propane_torch` | First priority, even when an equip tag is also present. |
| Otherwise `cashPiles.equip == "priest_collar"` | `priest_collar` | Second priority. |
| Any other cash-pile tool/equip tag, including a valid non-collar equipment ID | `money` | Exact source renderer fallback, even when collection later equips the record. |
| Separate `state.crownPickup`, existing and uncollected | `crown` | Independent of cash visibility and quest flags. |

The source has no persistent world-weapon or general loose-item registry. The nine
canonical weapon acquisitions equip immediately. Do not fabricate weapon drops, pickup
commands, inventory, IDs, collision or reward semantics. Brendan's badge and the inherited
wallet remain the same money art as the source; narrative wording alone is not another
pickup type. The existing torch/collar producers remain unchanged.

`Utilities.cash_visible` is the sole cash visibility decision: uncollected and vision,
strictly within60px, intro, or any truthy tool/equip. The view receives its result; it must
not independently re-evaluate distance, timed vision or flags. Runtime keeps strict14px
cash collection plus its real LOS check; Crown keeps its existing strict18px collection.
The visible mesh may not extend these ranges or become an interaction target.

## API and ownership

New `game3d/scripts/find_view.gd`, class `RockBottomFindView extends Node3D`:

```gdscript
static func create_cash() -> RockBottomFindView
static func create_crown() -> RockBottomFindView
func project_cash(record: Dictionary, is_visible: bool) -> bool
func project_crown(record: Variant) -> bool
```

Factories return unparented, hidden instances. Root owns parenting, dictionary keys,
record disappearance, queue/free and epoch replacement. The view stores only projected
identity/kind and cached node references. It holds no host/Runtime, ActionSession, callback,
source dictionary, clock, input handler, timer, collision object or gameplay authority.
Root calls `project_cash(pile, runtime.utilities.cash_visible(pile))` and retains all
existing collection/interaction paths. Root uses the separate crown factory/projector.

Projection returns true for a structurally valid record of its mode, including hidden or
collected records. A cash record needs a nonempty String ID and finite numeric x/y. Crown
needs finite numeric x/y and `collected` defaults true exactly as current Scene does.
Malformed records or a wrong-mode call return false and immediately hide that instance;
they never repair source state or retain the previous visible item. Accepted cash rows
use the supplied visibility AND not collected. Coordinates map through Content.to_world
at ground y0; mesh-local floor clearance is authored once. No relocated source point,
camera-facing scale, random yaw, spin, hover/bob or extra presentation clock is added.

Same-ID kind changes replace only Art's mesh leaves from cached immutable templates.
Same-kind updates do not recreate nodes/resources. Each instance owns transforms and
visibility; shared resources are never modified by projection. No per-frame scene-tree
search, rebuild, mesh mutation or material animation. Invalid→valid restores fresh
projection; one instance's state cannot change another.

## Art and budgets

- Money: several uneven folded dirty-yellow/cream notes, layered thin paper edges,
  broad inset border and original abstract printed marks. A raised folded corner gives
  a readable silhouette at a standing eye without a billboard or denomination label.
- Torch: dented brass reservoir, dark foot, shouldered neck, angular copper nozzle,
  valve wheel, paper label and a small sodium pilot attached to its nozzle. No real
  operating instructions or loose weapon model. The pilot alone may emit; no new light.
- Collar: visibly curved cloth band, thickness/inside surface, folded ends and a broad
  reversed dark tab. It must read as cloth equipment rather than another note or ring.
- Crown: bent hollow brass band, three prominent front points and shorter rear points,
  dull rivets and one fluorescent-purple inset gem. It must read at source pickup scale.

Use original code-native geometry, SliceSurfaceKit's authored palette/material pipeline,
and construction-time SliceMeshBatcher coalescing. If a moving object needs textured
paint, duplicate the shared material once for local triplanar mapping before caching;
never mutate the shared SurfaceKit material. All templates are shared immutable meshes
and materials; no raster asset generation or external pack. Per-kind target≤1500 triangles
and≤4 draw surfaces, overall width/depth≤.65m and height≤.65m. Native review must confirm
2m standing-eye readability and no excessive glow or floating ground gap.

The old source intro/torch/collar pulse and crown bob are not recreated with a new clock.
The authored pilot, high-contrast surfaces and crown gem provide static object identity.
Source vision's neon-green cash tint is not copied into new 3D art: money retains its
dirty-yellow/cream palette while Utilities alone decides vision-dependent visibility.
This is an explicit presentation adaptation only; visibility and timed gameplay remain
source-owned and unchanged.

## Evidence

New `test_find_view.gd` verifies tag precedence/fallback, detached source dictionaries,
malformed records/clock-free state, independent instances, actual finite bounded geometry
and front-facing unit normals, cached resource reuse/immutability and no colliders/input
or process owner. Actual Utilities visibility cases cover near/exact60/far, vision, intro,
known/unknown tags, collected; the view must honor the supplied result. Actual collection
ownership remains existing Runtime tests, not reimplemented by this presenter.

New `find_view_probe.gd` captures each source kind in existing production world lighting
at close detail and standing-eye near/far views, plus mixed-source row, hidden/collected,
same-ID type replacement and night torch/crown. Manifest reports mesh/surface/triangle
counts, source points, actual bounds and visibility; it does not claim interaction or
runtime performance acceptance. Parent runs the gate/probe; no child engine runs.

No edits to FullScene, Runtime, Cart, Rig, World, Adapter or accepted files in this packet.
