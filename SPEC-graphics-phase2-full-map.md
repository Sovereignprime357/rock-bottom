# SPEC — Graphics Phase 2: palette craft + full-map grime density

status: captured 2026-07-21 · branch: `codex/graphics-phase2-full-map` · scope: **Phase 2 only**

This sub-SPEC executes Phase 2 of `DELEGATION-graphics-upgrade.md` after the shipped Phase 1
lighting/grade/AO/emissive layer. It subsumes the useful art work captured in
`SPEC-v22-sprite-shading.md` and extends it across the complete 8600×5600 map. Phase 3's selective
resolution experiment is explicitly excluded.

The requested `specmesh-spec-capture` executable is not installed in this workspace. This checked-in
contract is the project-documented manual SpecMesh capture fallback and must be committed by itself
before production code.

---

## WHAT

Phase 2 makes the existing 32px / eight-index world denser, dirtier, and more alive without changing
gameplay geometry:

1. Finish the pending tenebrist character shading pass: one screen-left key / screen-right shadow,
   worn material definition, mauve-biased shadow steps, warm dirty-cream/copper rims, and sparse hot
   rust/purple accents.
2. Add real ordered/checker dither to character wear and environmental grime. Dither only alternates
   two declared indices; it never introduces a ninth color or smoothing.
3. Add a visual-only, deterministic full-map grime registry with cached trash, puddle, stain, wire,
   bent-needle, stub, rat, glass, can, mildew, paper, oil, and grate art plus cheap 2–4 frame ambient
   loops for flies, sign buzz, grate steam, drips, wire tremor, and discarded-TV glow.
4. Multiply NPC appearance with three pre-rendered palette tints selected deterministically per
   instance. The original grid, alpha topology, key grammar, hitbox, anchor, and normal cache stay
   authoritative.
5. Correct the current tile-coordinate hash seam: tile multiples currently make `h % TILE` equal zero,
   pinning several texture families to every tile's left edge. Replace it with a salted avalanche hash
   over integer tile coordinates.

## WHY

Phase 1 supplied depth and mood, but the full map still exposes repeated ground seams, large empty
connective regions, mostly static scenery, and a roster whose new 32×32 area is under-authored. The
research packet identifies palette craft, controlled dither, clutter density, and unsynchronized
secondary motion as the highest-value remaining levers before any resolution change.

---

## AUTHORITIES AND OUTPUTS

- Character art remains in `src/render/sprite_art_{player,npc,special}_32.js`, registered through the
  one existing `cacheSprite()` path in `src/render/sprites.js`.
- Normal character authority remains exactly `SPRITE_CACHE`: **94 bases / 377 keys**.
- Phase 1 authority remains `SPRITE_EMISSIVE_CACHE`; Phase 2 may not reinterpret its base allowlist or
  change torch/pipe emissive topology.
- Variant art lives in a separate `SPRITE_VARIANT_CACHE` with frozen palette metadata and a stable
  resolver. It does not add keys to `SPRITE_CACHE`.
- Full-map art lives in a separate visual-only grime cache/layout owned by the tile renderer. It does
  not enter `PROPS`, `WORLD_DECOR`, collision, interaction, save data, rewards, or NPC registries.
- All grime source art is an explicit 16-logical integer palette-index grid prerendered by the shared
  toolkit to an exact 32×32 canvas during initialization.
- Frame rendering consumes only prebuilt canvases through `ctx.drawImage` and a visible-cell lookup.

---

## CHARACTER PALETTE + DITHER CONTRACT

### Tenebrist grammar

The existing sprite corpus uses index 0 for transparency and material-specific indices 1–7. A blind
global numerical remap would recolor skin as cloth and would collide with Phase 1's base-scoped
emissive meaning. Phase 2 therefore records and applies the research ramp as **roles per base**:

- transparent: index 0, unchanged;
- core/shadow: existing near-black plus a desaturated mauve/rust-biased shadow step;
- mid/base: the base's existing identity materials, darker and fewer than its highlights;
- rim: a warm dirty cream/gold/copper step, never pure white;
- accent: one restrained rust, copper, fluorescent-purple, or authority-only blue step.

The pending `v22-sprite-shading` grids may be reused, but their `shade`/`worn` roles must be audited
against this grammar. Larry's red may act as heat/accent, not a general shadow; Price Guy may not use
index 7 as a second gray merely to satisfy a role name. Mirrored locomotion must not make the perceived
key light flip where a screen-space correction can be made without moving the silhouette.

### Dither

- Production exposes one deterministic ordered-dither helper.
- A 2×2 probe must be exactly `A B / B A`, using only two caller-supplied, declared indices.
- Character dither is sparse: material wear or shadow transition, not a uniform screen-door texture.
- Grime families use dither to break flat fills; no family may depend on runtime alpha noise.
- Dither never uses an emissive index merely to make a checker pair.

### Per-instance variants

- DrawNpc-capable humanoid/state/special body bases receive three extra palettes:
  `mold_sick`, `mauve_shadow`, and `sun_bleached`.
- `sun_bleached` means dirty ochre/gray wear, not pastel or clean/high-key art.
- Every palette stays at eight entries including transparent index 0 and differs from its base in at
  least two nontransparent entries.
- Authority blue is preserved only for cop/horse-cop/Brendan bases; variant transforms may not create
  bright blue elsewhere.
- Each eligible normal frame gets one prebuilt 32×32 canvas per variant. Variant alpha/topology is
  identical to the normal grid.
- Selection is a stable hash of persistent actor identity and sprite base. It does not use position,
  `Math.random`, save state, or frame time. Missing/invalid variants fall back to the normal cache.

---

## FULL-MAP GRIME CONTRACT

### Coverage grid

- World: 8600×5600.
- Cell size: 192 world pixels.
- Coverage: `ceil(8600/192) × ceil(5600/192) = 45 × 30 = 1350` cells, including clipped east/south
  edge cells. No zone-only placement shortcut is allowed.
- Every cell owns 2–3 static grime stamps and a deterministic chance of one secondary loop.
- Placement uses a stable salted 32-bit coordinate hash. No `Math.random`, no frame-time placement,
  and no object creation in the hot draw path.
- The coverage grid necessarily spans all 23 `ZONES`, all 15 `TERRAIN_REGIONS`, and default gaps.

### Static library

The required semantic families are:

`trash_cluster`, `puddle`, `oil_slick`, `mildew_patch`, `wire_tangle`, `bent_needle`,
`spent_stub`, `glass_shards`, `can_cluster`, `rat_hole`, `paper_scraps`, `storm_grate`.

Each is a nonblank 16×16 grid, uses no more than eight VIBE-spine colors including transparency, and
is cached once at 32×32 with smoothing disabled. The full-map selector distributes all families; no
single family may own more than 20% of static placements.

### Secondary loops

Required families and frame counts:

- `flies`: 3 frames
- `sign_buzz`: 2 frames
- `grate_steam`: 4 frames
- `drip`: 3 frames
- `wire_tremor`: 4 frames
- `tv_glow`: 3 frames

Frames are distinct, nonblank cached grids. A per-placement phase derived from coordinates prevents
synchronized blinking. `state.visualNow` is the sole clock. Fixed time repeats exactly; advancing one
family's frame interval advances its witness; one full period returns it.

### Render order and culling

- Static grime renders after base tiles and `drawWorldFabric()`, before buildings/props/actors.
- Secondary loops render in the same world-space stack, above static grime and below actor bodies.
- Both passes run before `ctx.restore()` and before `drawLighting()`, so Phase 1 darkness, district
  grade, light holes, AO, and emissives remain authoritative.
- Visible-cell traversal is bounded to the camera rectangle plus one sprite margin. No full 1350-cell
  scan is permitted per frame.
- A normal 800×600 viewport draws at most 90 Phase 2 stamps/loop frames combined.

---

## INVARIANTS — BLOCKERS

- **I-PHASE-BOUNDARY.** Phase 3 is not built: no 48×48/tall-box bases, no size/anchor/hitbox change,
  no camera or destination-rect change.
- **I-CANVAS2D.** Canvas 2D only. No WebGL, shaders, normal maps, `ctx.filter`, or runtime blur.
- **I-PIXEL.** `image-rendering: pixelated` and `imageSmoothingEnabled=false` remain. World/sprite art
  stays crisp; new caches are exact 32×32.
- **I-STRUCTURE.** Exactly 94 character bases / 377 normal keys / 11 environment keys / 14 frozen
  character draw sites. No normal grid key or frame may be added or removed.
- **I-EIGHT.** Every source/variant palette has at most eight indices. No fractional or undeclared
  index. Transparent index remains 0 for character/grime arrays.
- **I-VIBE.** No pure white; no bright blue except authority; no pastel/neon base; cream/gold replaces
  white specular. Detail must increase grime, wear, and specificity, never cuteness, cleanliness,
  dignity, or heroic polish.
- **I-EMISSIVE.** Phase 1's opt-in indices 2/7 remain base-allowlisted only for propane torch and pipe.
  Their mask count/topology remains pinned.
- **I-VISUAL-ONLY.** Phase 2 changes no collision, spawn, AI, economy, quest, save, storage, dialogue,
  audio, timer, weather, day/night, or faction behavior.
- **I-DETERMINISTIC.** Full-map placement and instance tint are deterministic and save-free.
- **I-HOT-PATH.** No `createElement('canvas')`, gradient, rasterize, `getImageData`, `putImageData`, or
  `Math.random` inside Phase 2 draw functions. No per-frame arrays/objects for grime traversal.
- **I-FROZEN-REFERENCE.** `rock_bottom_v19.html` is untouched.

---

## GATE CONTRACT

Add a permanent `tools/phase2-graphics-gate.mjs` after the Phase 1 lighting gate; the permanent suite
becomes **20 gates**. It must prove:

1. Phase boundary, exact normal sprite/env structure, unchanged anchors, unchanged Phase 1 emissive
   allowlist/masks, Canvas 2D/no smoothing/no hot-path cache generation.
2. Normal grid topology metadata covers exactly 377 keys and is frozen/hash-pinned; the sprite palette
   snapshot is re-ratified once after art finishes. Environment palette hash remains unchanged.
3. Ordered-dither helper behavior, character/grid dither witnesses, palette legality, variant palette
   distinctness, exact eligible-frame variant cache coverage, topology preservation, authority blue,
   stable resolution, and invalid-variant fallback.
4. Exact 45×30 / 1350-cell coverage; 2–3 statics per cell; all 12 static and six loop families;
   world-bounded records; family distribution; deterministic placement; exact cache sizes/palettes;
   distinct loop frames and unsynchronized phase.
5. Visible-cell culling, ≤90 draw budget, required render order, state purity, and exclusion from
   gameplay registries.
6. The corrected tile hash spreads several samples across the full 0–63 coordinate range instead of
   pinning texture x offsets to zero.

Required intentional-red modes, each verified nonzero before final green:

`sprite-topology`, `character-palette`, `dither-third-index`, `duplicate-variant`,
`variant-topology`, `variant-blue`, `missing-cell`, `cell-density`, `missing-static-family`,
`missing-loop-family`, `bad-loop-frame-count`, `frozen-loop`, `synchronized-loop`,
`nondeterministic-layout`, `unculled-draw`, `visible-budget`, `runtime-raster`, `render-order`,
`gameplay-leak`, `tile-seam`.

The gate validates mechanics and discipline, not beauty. Visual acceptance remains the operator's eye.

---

## VISUAL + PERFORMANCE ACCEPTANCE

Baseline is Phase 1 main `fdd0ccc364540cc46d67b14be51a5f9fb145fc36` at a fixed fresh state.

- Real browser, real game canvas, 800×600 internal resolution, DPR 1.
- Gapless full-map origins: x=`0,800,…,7200,7800` (11) and y=`0,600,…,4800,5000` (10): 110 camera
  renders whose stitched crop union covers every one of the 48,160,000 world pixels.
- Deliver matched 25% before/after full-map mosaics plus 1:1 representative crops at day and night.
- Deliver a nearest-neighbor character/variant atlas and a frame strip for all six secondary loops.
- Record capture commit, fixed state, origins, union dimensions, and image hashes in a manifest.
- The before/after is the acceptance gate: dither must read as dirt rather than noise; density must not
  hide doors/paths/signs; motion must feel incidental and unsynchronized; variants must retain identity;
  Phase 1 lighting/AO/emissive coherence must survive.

Profile two real-browser 800×600 fixtures after 30 warmup frames for 240 measured frames:

1. 64 mixed body sprites cycling variant families in the densest Phase 2 viewport, day/clear.
2. 64 visible cops/dynamic lights in the same density, night/rain.

Both require mean frame time ≤8ms and p95 <16ms. Report p99/max but do not fail on one GC spike.

---

## ACCEPTANCE CHECKLIST

- [ ] Sub-SPEC committed before production code.
- [ ] Pending sprite shading integrated/audited; weak sprites named honestly in the handoff.
- [ ] 94 bases / 377 normal keys / 11 env keys / 14 draw sites intact; Phase 3 untouched.
- [ ] Dither, three per-instance palettes, full 1350-cell static grime, six loop families shipped.
- [ ] Tile seam hash corrected.
- [ ] All 20 intentional-red modes observed failing; production Phase 2 gate green.
- [ ] Permanent suite 20/20 green; frozen v19 untouched.
- [ ] Real-browser full-map before/after, detail/atlas/loop artifacts, and performance JSON ready.
- [ ] `SPEC.md`, `VIBE.md`, `DELEGATION-graphics-upgrade.md`, and append-only `BRAIN.md` updated.
- [ ] Named branch committed, pushed, and stopped before Phase 3.

## THE TRAPS

The first trap is confusing density with indiscriminate noise. Empty breathing room, doors, paths,
actors, and signs still need hierarchy. The second is treating a green gate as taste: 20/20 proves the
system survived, not that the grime landed. The third is allowing palette craft to become polish. If a
sprite looks healthier, cleaner, cuter, or more heroic, the pass failed. The possum still knows.
