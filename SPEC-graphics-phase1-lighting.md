# PHASE 1 — LIGHTING & GRADE LAYER (2026-07-19)

Status: captured before implementation. This packet governs Phase 1 of
`DELEGATION-graphics-upgrade.md` only. Phase 2 palette/grime-density work and Phase 3 sprite-size
work are explicitly out of scope.

## Outcome

The existing Canvas 2D lighting stack remains the authority: `drawLighting()` still owns the
screen-space night mask, `destination-out` light holes, cached additive glows, and fog ordering.
Phase 1 deploys that stack across more of the neighborhood, adds one area-owned ambient grade,
seats physical actors/props with directional contact shadow, and restores a deliberately small
self-lit accent layer after darkness. It does not replace the renderer, recolor the sprite corpus,
or change gameplay.

## Inputs and authorities

- `nightAmount()` remains the single day/night scalar. Phase 1 may use it at more compositing
  sites but may not create a second clock or mutate `state.dayTime` while rendering.
- `WORLD_LIGHTS` remains the static light registry. Lamp props and bounded runtime emitters are
  adapted into the same normalized light-source shape; no second glow loop owns a parallel color
  cache.
- `ZONES` and `TERRAIN_REGIONS` are the area lookup authorities for ambient grade. Gameplay zone
  membership, faction, collision, and route semantics are not changed.
- `PROPS`, `interactiveProps`, the visible NPC buffer, and the player are the physical shadow
  owners. A prop type must resolve to a footprint or to an explicit flat/wall-mounted exemption;
  there is no silent geometry default.
- Existing integer sprite grids, `PALS`, `PLAYER_LAYER_PAL`, `CART_LAYER_PAL`, and every
  `SPRITE_CACHE` key remain byte-for-byte palette/grid inputs. Phase 1 may derive a separate
  post-light cache from those inputs at initialization but may not edit them.

## 1. One diegetic light registry

Every source consumed by `drawLighting()` normalizes to:

```js
{ kind, x, y, radius, power, rgb, active, castsShadow, core }
```

`active` is evaluated at draw time from existing state. Static records remain plain data;
runtime sources are written into one reused frame buffer with no per-frame canvas or gradient.

Required source families:

| Family | Authority | Hue | Behavior |
|---|---|---|---|
| streetlamp | `PROPS` lamp records | sodium piss-yellow `232,192,64` | night mask hole + cached glow + self-lit bulb |
| barrel fire | authored physical prop/light records | fire orange `208,96,48` | dirty flicker in radius/power; no random allocation |
| neon sign | authored facade/decor light records | fluorescent purple `212,136,212` | night glow + self-lit broken sign strokes |
| lit window | authored facade/building light records | dirty cream/gold `212,200,150` | low-power night glow; never pure white |
| pipe ember | live player status/equipment | copper orange `208,96,48` | bounded player-attached source while the relevant ember is visibly live |
| cop light | live `cop`/`brendan`/`horsecop` actors | authority blue `72,104,208` | blue is cops-only; source follows the living visible actor |

The existing warm and world-specific hues remain valid grandfathered emitters. Every RGB that a
runtime source can request must be present in `LIGHT_GLOW_CACHE` after initialization. A missing
cache entry is a gate failure, never a silent no-glow fallback.

Mask holes and additive glows are viewport-culled. Fire/ember/cop cores may remain visibly
self-lit in daylight at restrained opacity; the global darkness mask still exists only when
`nightAmount() > .01`. No source changes collision, wanted state, AI, damage, inventory, or save
data.

## 2. Per-area ambient grade

`AMBIENT_GRADES` is a frozen render-data table covering all canonical zone ids plus terrain/default
fallbacks. Each row declares one committed grime hue and bounded Canvas blend values:

```js
{ multiply: 'r,g,b', multiplyAlpha, overlay: 'r,g,b', overlayAlpha }
```

The lookup uses the player/camera area's existing authored geography. It never writes gameplay
state and never infers a new mechanical zone. Zone examples establish the range, not a new color
language: mold-green underpass/scrap, piss-yellow block/alley, fluorescent-purple laundromat/church,
asphalt-black lot/ditch, copper-orange choir/dealer.

Compositing order is fixed:

1. world and actors;
2. night darkness mask with holes;
3. per-area multiply/overlay wash;
4. restored emissive cores/indices;
5. cached additive light glows;
6. fog/weather and existing status/UI layers;
7. existing low-HP vignette.

The grade is deliberately low-alpha and may be smooth because it is a light overlay. It may not
enable image smoothing on the world canvas, use `ctx.filter`, allocate a gradient per frame, or
make a district pastel/clean/high-key. Exact alpha bounds: multiply `0.04..0.18`, overlay
`0..0.08`; combined grade cannot hide hostile telegraphs, objective markers, rocked-up gold, crash
purple, or text.

## 3. Contact shadow / fake AO

All physical characters receive a dark ellipse immediately below their cached sprite. All physical
props and interactive props receive a footprint ellipse plus a 1–2px contact band at the authored
ground seam. Flat ground marks and wall-mounted art are explicit exemptions and receive neither a
floating fake ellipse nor a made-up ground seam.

For a footprint center `(cx, cy)`, the nearest active `castsShadow` light supplies the direction.
The shadow offset is the normalized vector away from that light, clamped to `1..4px`; with no active
light it uses the existing top-down fallback `(1,2)`. Actor alpha is `0.34..0.40`, prop alpha is
`0.30..0.38`, and both use `globalCompositeOperation='multiply'`. Shadow radius derives from the
existing hitbox/footprint and never changes that geometry.

The nearest-light query consumes the same culled/reused registry buffer as the glow pass. It does
not allocate objects in the actor/prop loop. At 60 visible NPCs plus the authored visible props,
the complete Phase-1 render remains below 16ms/frame on the deterministic target harness.

## 4. Emissive indices without sprite-corpus drift

Phase 1 reserves palette indices `2` and `7` as opt-in self-lit accent indices for
emitter-capable cached layers. Because the grandfathered corpus predates this semantic, the
reservation is allowlisted by sprite base rather than applied blindly to every old highlight.
Initial allowlist: `gear_propane_torch` and `weapon_pipe`. New emitter-capable cached layers must use
one of these two indices or receive an explicit later SPEC amendment.

At sprite-cache initialization, allowlisted grids are rasterized a second time into a bounded
`SPRITE_EMISSIVE_CACHE`, retaining only indices `2`/`7`, with transparent background, no outline,
no smoothing, and an exact 32×32 output. The normal `SPRITE_CACHE` canvas, key grammar, pixel count,
palette-use snapshot, grid modules, and palette arrays do not change. The derived cache is drawn
only after darkness/grade at the player's existing destination anchor. Procedural bulb, fire, neon,
window, pipe-status, and cop-light cores use the same post-dark emissive pass and VIBE hues.

No full-frame `getImageData`, runtime per-pixel scan, WebGL, shader, normal map, external bitmap,
sample, font, CDN, framework, or build step is permitted.

## Read-only rendering and compatibility

- `drawLighting`, ambient-grade lookup, contact-shadow selection, and emissive drawing are pure
  visual reads. They may update only reused render buffers/canvas state, never `P`, durable `state`,
  NPC AI, props, clocks, counters, save payloads, or random gameplay order.
- All Canvas state changes are paired by save/restore or explicitly restore alpha/composite mode.
- `rock_bottom_v19.html` and every `rock_bottom_v*.html` remain untouched.
- `index.html` retains `image-rendering: pixelated`; no runtime smoothing of world/sprite art.
- Save key/version/shape, world geometry, collision, routes, economy, factions, status values,
  `P.rockedT = 18000`, and `P.crashT = 8000` are unchanged.
- Phase 1 adds no NPC, dialogue, sound, currency, interaction, quest, reward, or fourth-wall copy.

## Edge cases

| Case | Required behavior |
|---|---|
| full daylight | no darkness mask; restrained fire/ember/cop cores may remain; grade stays low-alpha |
| deep night + fog + crash | grade, fog, and crash remain ordered; player/hostile/objective readability survives |
| office generator absent | office light remains inactive exactly as shipped |
| source outside viewport | no mask/glow/core draw and no shadow influence on visible objects |
| two equidistant lights | stable registry order wins; no frame-to-frame shadow flip |
| source overlaps footprint | offset clamps to the fallback direction; no NaN transform |
| dead/hidden cop | contributes no dynamic light |
| mounted cart / large horse cop / incident actor | footprint remains aligned to the existing bottom-center anchor |
| unknown new prop type | presentation gate fails until footprint or explicit exemption is authored |
| missing emissive cache key | normal sprite still renders; permanent gate fails the build |

## Permanent verification

The permanent suite remains 18 gates. Phase-1 structural/behavioral checks are added to
`presentation-gate.mjs` (the existing render/presentation owner); `sprite-gate.mjs`, its key count,
palette hashes, and destination hash do not move.

New presentation checks must prove:

1. all six required light families normalize through one registry and every requested RGB has a
   prebuilt glow cache;
2. all 23 zone ids plus terrain/default paths resolve to bounded, VIBE-legal grade rows;
3. render order is darkness → grade → emissive → glow → weather/status → vignette;
4. nearest-light offsets point away, remain finite/clamped, and use stable tie/fallback behavior;
5. every production prop type is classified as footprint or explicit flat/wall exemption;
6. emissive cache keys equal the allowlisted base grammar, contain only indices `2`/`7`, remain
   32×32/nonblank, and leave the ordinary sprite/palette snapshots unchanged;
7. no `WebGL`, shader, `ctx.filter`, hot-path canvas/gradient creation, or smoothing regression;
8. a 60-NPC night fixture plus visible props remains below 16ms/frame.

Each new check is red-tested by a temporary, observed mutation before the green result is trusted:
remove one source family, exceed a grade alpha bound, invert a shadow vector, leave a prop type
unclassified, admit a forbidden emissive index, and reorder grade/emissive. Mutations are restored
before the 18-gate run.

Required final verification:

- `node tools/run-gates.mjs` → `18/18 PASS`;
- `sprite-gate` output and hashes unchanged from baseline;
- `git diff -- rock_bottom_v*.html` empty;
- matched 800×600 before/after night renders from the same camera/state fixture;
- operator eye sees light pools, area hue, grounded sprites/props, and self-lit accents without a
  cute, clean, pastel, or polished read.

## Phase boundary

Stop after the green Phase-1 commit, pushed branch, gate transcript, files-touched list, decision
record, and before/after renders. Do not recolor/dither sprite grids, add grime-density animation,
change palette hashes, or alter sprite resolution. Those are Phase 2/3 and require a new SPEC plus
explicit operator direction.
