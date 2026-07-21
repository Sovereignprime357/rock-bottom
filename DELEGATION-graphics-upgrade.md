# DELEGATION → Codex — Rock Bottom graphics upgrade (research-grounded)

Authored 2026-07-19 from six parallel reference-game art studies (Octopath Traveler, Hyper Light
Drifter, Eastward, Blasphemous, Rogue Legacy, Soulbound). This is the graphics track the operator
reserved for you. **Build in phases, SPEC each one first, gate each one, and do NOT cross the Phase 3
line without an operator ruling.** Research briefs are summarized in §RESEARCH below; full source lists
at the bottom.

---

## THE THESIS (what the research actually found)

The six references span 32px to 330px sprites, but they **converge on one point**: the distance
between Rock Bottom and "those graphics" is **not pixel count** — it's the **lighting + color-grade +
atmosphere + density layer** sitting on top of the sprites, plus **palette craft**. Evidence:

- **Hyper Light Drifter** renders at 480×270 and its characters are **~32×32 — the same as ours.** The
  look is "soft light layers composited over crisp pixels." (Alex Preston.)
- **Octopath Traveler** uses modest sprites; every bit of depth is a point-light + cast-shadow rig and a
  color grade around them. Dev framing: raising sprite resolution is "the lowest-value lever."
- **Blasphemous**'s smallest humanoid runs on **6–8 colors — like our 8-index palettes.** Its richness
  is (a) *area* on deliberately-large hero sprites and (b) hand-baked tenebrist light. Dev: "no fancy
  shaders or 3D" — depth is painted into the pixels.
- **Eastward / Soulbound** look lush because of a **normal-map + shader + LUT lighting pipeline we
  cannot run in Canvas 2D.** Their *warmth* is a color-grade we CAN fake; their *resolution and color
  depth* we cannot and should not chase.
- **Rogue Legacy** is a **caution**: its clean/cute/high-key read is the exact inverse of RB's grimy
  mandate. Steal its *pipeline* (palette tinting + modular parts), reject its *look*.

**Direct answer to the resolution question:** do **not** do a global 32×32 raise. Keep 32×32 and the
8-index palette as identity. A *selective* bump for the hero + a few signature NPCs is a real option but
it is **Phase 3, optional, operator-gated** — after the lighting and grime work, only if silhouettes
still feel starved.

---

## WHAT ALREADY EXISTS (extend this — do NOT rebuild)

Rock Bottom already has a real lighting system. Ground every Phase-1 change in it:

- **`src/render/actors_weather.js` → `drawLighting()` (line ~34).** Current pipeline per frame:
  - builds a night-darkness mask on `LIGHT_CTX`/`LIGHT_MASK` (offscreen 800×600),
  - **punches light-holes** into the darkness with `destination-out` (via `punchLightMask` +
    `LIGHT_HOLE`), so lit areas show through,
  - composites the mask over the scene (`ctx.drawImage(LIGHT_MASK,0,0)`),
  - draws **per-source additive colored glows** with `globalCompositeOperation='lighter'`, iterating a
    light-source list (`for (l of …) LIGHT_GLOW_CACHE[l.rgb]`), plus a warm `'255,210,120'` glow,
  - composites `FOG_SHEET`.
- **`src/render/landmarks_a.js`** builds `LIGHT_GLOW_CACHE` (per-RGB radial glow sprites from the
  256×256 `LIGHT_HOLE` gradient), the `FOG_SHEET` gradient, and `nightAmount` day/night driving.
- **Sprites:** `src/render/sprite_art_{player,npc,special}_32.js` — **94 bases / 377 keys**, 32×32
  integer palette-index grids. Palettes are 8-entry `PALS` arrays in `src/render/sprites.js`.
- **`tools/sprite-gate.mjs`** freezes the base/key structure + a re-ratifiable palette-use hash + the
  no-smoothing rule. `tools/presentation-gate.mjs` guards the post/layout contract.

**The gap is not missing infrastructure — it's that the lighting system is under-deployed (few sources,
one warm glow color) and the sprites/palettes/density haven't been pushed to match it.** Every research
technique below maps onto extending this, not replacing it.

---

## PHASE 1 — the lighting & grade layer (biggest win; 32×32 and 8-index untouched)

**Status — SHIPPED, 2026-07-19.** Contract:
`SPEC-graphics-phase1-lighting.md`; merged baseline `fdd0ccc`. The shipped layer
normalizes streetlamps, four trash-barrel fires, neon/window fixtures, the high/pipe ember, and live
cop beacons through one reused registry; adds frozen zone/terrain multiply+overlay grades; replaces
fragmented actor/prop shadows with nearest-light AO plus contact bands; and derives opt-in emissive
masks for palette indices 2/7 without changing one source grid, palette, cache key, or draw anchor.
`tools/phase1-lighting-gate.mjs` is permanent; all counterexample modes went red. A real 800×600
browser profile with 64 visible cops measured 1.548ms/frame. Matched Block/Laundromat-Church/Skid
Row night renders are in `artifacts/graphics-phase1/` (left baseline, right Phase 1).

Every one of the six briefs named this as the #1 lever. Extend `drawLighting()` and the light-source
registry:

1. **More diegetic, grimy light sources.** Audit the current light-source list (the `for (l of …)` in
   `drawLighting`). Add sources at streetlamps, trash-barrel fires, neon signs, lit windows, the pipe
   ember, cop lights. Give each a **sickly diegetic RGB**, never a clean/magical one: sodium
   piss-yellow, fluorescent purple, fire orange, cop blue. These extend `LIGHT_GLOW_CACHE` (already
   keyed by rgb string).
2. **Per-district ambient grade.** The current day/night is one global `nightAmount`. Add a **per-zone
   ambient tint** (a `multiply`/`overlay` wash looked up by area — piss-yellow alley, mold-green
   stairwell, asphalt-black lot) layered before the vignette. This is HLD's + Eastward's + Soulbound's
   "one committed hue per zone." Low effort; ~half the mood engine.
3. **Contact shadows / fake AO.** Under every character and prop, draw a soft dark ellipse
   (`'multiply'`, ~30–40% alpha) offset opposite the nearest light; bake a 1–2px darker contact band
   where props meet ground. Named by all six as what "seats" sprites in the world (fakes Eastward's
   SSAO, Octopath's cast shadow).
4. **Emissive palette index.** Reserve **1–2 of the 8 palette indices as "self-lit"**; have the
   darkness/grade pass exempt or brighten those indices so cig cherries, fire, neon, cop lights, a lit
   pipe **punch through** the grime. This is the warm-accent-on-cool-field move (HLD, Soulbound,
   Blasphemous's blood-red pop) adapted to the 8-index constraint.

**Phase-1 invariants:** Canvas 2D only (no WebGL/shaders). `image-rendering: pixelated` stays — the
light layer may be smooth, the world layer must not. 8-index palettes untouched. Only VIBE-spine /
diegetic-grimy light colors. `sprite-gate` + `presentation-gate` stay green. This phase touches the
**render/lighting layer, not the sprite grids or palettes** — so `sprite-gate` should not even move.

---

## PHASE 2 — sprite palette craft + grime density

**Status — BUILT / PENDING OPERATOR EYE, 2026-07-21.** Contract:
`SPEC-graphics-phase2-full-map.md`; branch `codex/graphics-phase2-full-map`. The candidate finishes
screen-left tenebrist shading and two-index wear dither, prebuilds three topology-identical palette
variants across 54 eligible bases / 155 frames (465 canvases), and covers the full 8600×5600 map
with 1,350 deterministic non-overlapping cells, 3,017 cached grime stamps, and 273 phased placements
across six secondary loops. The tile-coordinate hash seam is repaired. `phase2-graphics-gate` is the
twentieth permanent gate; all 21 counterexample modes went red before the 20/20 suite returned green.
Matched full-map/day/night/detail sheets, atlases, loop strip, hashes, and real-browser profiles are
in `artifacts/graphics-phase2/`. Phase 3 remains unbuilt and operator-gated.

Now push the sprites and the world to match the new light. Art-heavy, not tech-heavy.

1. **Tenebrist ramp authoring (Blasphemous).** Fix a single implied light direction across the roster;
   author each 8-index palette as: near-black core shadow (0–1) → mid (2–3) → base (4–5) → warm
   rim/highlight (6) → one accent (7). High contrast, few midtones. **Hue-shift shadows toward
   mauve/magenta** — RB already owns fluorescent purple, so make that the shadow end (the research's
   "desaturated-magenta shadow" dread lever). Reserve one **blood-red / hot accent** index.
2. **Dithering inside the palette (Octopath, Blasphemous).** Ordered/checkerboard dither between two
   indices for grime buildup, contact AO, and banded light falloff — detail without leaving 8 colors,
   period-correct, reads directly as "grimier."
3. **Grime-prop density + secondary animation (Eastward, Blasphemous, Soulbound).** Build a deep
   grime-prop library (trash, puddles, stains, wires, needles, stubs, rats) and scatter-place it; add
   cheap **2–4 frame secondary loops** (flies, flickering/buzzing signs, steam off grates, dripping, a
   tremor, TV glow). The research is unanimous: **the world moving matters more than the hero moving**,
   and this is where "more detailed, grimier, more specific" is actually bought.
4. **Modular parts + palette tinting (Rogue Legacy pipeline).** RB's index-grids are *already* the ideal
   data model for this. Keep one base grid per character; maintain **several 8-color palettes per base**
   (fresh vs strung-out, sun-bleached vs shadowed, sicker-tier = ramp shifted darker/greener) and pick
   per instance. Optionally composite **reusable parts** (hoodie, cart, needle, bottle, wound) across
   bases via layered `drawImage` at per-frame offsets. This **multiplies the 94 bases several-fold with
   near-zero new grids** and deepens grime rather than fighting it.

**Phase-2 invariants:** 94 bases / 377 keys structure frozen (`sprite-gate` structural pins stay green —
this changes pixels/palettes, not the roster). **Re-ratify the `sprite-gate` palette-use hash once** at
the new denser state, and **RED-TEST it** (ORCHESTRATOR-NOTES #3). No smoothing. VIBE hues only.

---

## PHASE 3 — OPERATOR DECISION: selective resolution bump (optional, do NOT build unprompted)

Only Blasphemous and Eastward suggest more pixels, and both say **selective, not global, and after the
lighting work.** If — after Phase 1–2 — the hero and signature NPCs still read starved:

- Bump **only the hero + a handful of signature NPCs** to **48×48**, or to a **taller portrait box
  (~32w × 48–56h)** (Eastward's finding: character detail comes from *height*, not a bigger square).
- Keep **props and minor NPCs at 32×32.**
- Cost: `sprite-gate` base-size pins change for those bases; camera/anchor/hitbox review; re-author the
  bumped bases. This is a **real wave with its own SPEC**, and a **global** raise across ~94 bases is a
  cost multiplier to avoid.

**Flag this to the operator with the trade-off; build only on an explicit greenlight.** Recommendation
on the record: ship Phase 1, then Phase 2, let the operator judge on the big screen, and treat Phase 3
as calibration, not a default.

---

## INVARIANTS (all phases) — the VIBE is the moat, protect it

- **Canvas 2D only.** No WebGL, no shaders, no normal maps, no 3D compositing, no runtime `ctx.filter`
  blur in the hot path (pre-bake blurred halos instead). Everything is offscreen-canvas compositing.
- **`image-rendering: pixelated` stays.** The world/sprite layer is never smoothed; only the light/glow
  overlay may be soft.
- **8-index palettes are identity.** Do not expand per-sprite color counts to chase Eastward/Soulbound.
  Apparent richness comes from grade + additive light + more distinct palettes across props.
- **VIBE hues only.** Grimy diegetic emitters (sodium, fluorescent, fire, cop-blue). **FORBIDDEN:**
  neon-as-base, pastels-as-base, bright blue except cops, and **pure white** — use brightest cream/gold
  as the specular instead (Blasphemous uses white; we do not).
- **NEVER cute / clean / dignified / polished.** This is the Rogue Legacy + Soulbound trap, named in
  both briefs. Steal their *pipeline and grammar*, reject their *look*. Every added detail must serve
  **grime, wear, and specificity** — a sprite that reads *nicer* has failed; one that reads *more
  itself* has landed.
- **`sprite-gate` structure frozen** (94 bases / 377 keys); palette hash re-ratified + red-tested per
  audited change. **`presentation-gate`, `world-gate`, and all 20 gates stay green.**
- **Frozen `rock_bottom_v19.html` (and every `rock_bottom_v*.html`) untouched.**
- **SPEC before code, per phase.** Each phase is its own branch/worktree + its own gate; commit messages
  reference the SPEC section; `VIBE.md` palette/texture rules updated to match shipped art. The
  operator's eye is the acceptance gate for anything visual — render a before/after for each phase.

---

## ACCEPTANCE (per phase)

- **Phase 1:** a visible depth jump on the big screen — light pools, stronger contrast, sprites grounded
  by contact shadow, emissive accents punching through — with **32×32 and 8-index fully intact**; suite
  green; operator sign-off on a before/after.
- **Phase 2:** roster reads denser and grimier (tenebrist ramps, dither grime, magenta shadows), the
  world is cluttered and *alive* with cheap secondary motion, and the base count is multiplied via
  tint/parts; `sprite-gate` palette hash re-ratified + red-tested; suite green; operator sign-off.
- **Phase 3:** only if greenlit — selective hero/signature bump, `sprite-gate` size pins updated +
  red-tested, camera/hitbox verified, no global raise; operator sign-off.

---

## RESEARCH (condensed per-game; full sources below)

- **Octopath Traveler (2018):** modest sprites; depth = a point-light casting real shadows + tilt-shift/
  DoF/bloom/fog + global grade. Transferable: fake point-light + blob shadows, real global grade,
  parallax/particle haze, dither AO. NOT transferable: 3D environments, bloom/DoF, sprite resolution.
- **Hyper Light Drifter (2016):** 480×270, **~32×32 characters (= ours)**. Depth = flat base + big
  overlaid gradients/vignette + soft-light-over-crisp-pixels + emissive glow. Transferable: light-
  overlay layer, faked bloom on an emissive index, per-zone grade, "detail etched on flat blocks."
  NOT: neon palette (violates VIBE — steal method not hues), shader bloom, bigger sprites.
- **Eastward (2021):** ~31×54 logical on a 3× grid, **tall portrait box**; richness = 3D re-lighting +
  normal maps + warm-key/cool-shadow LUT + huge clutter + 70k frames. Transferable: warm/cool global
  grade, additive light pools, fake AO/contact shadow, clutter+verticality+cheap secondary motion.
  NOT: normal-mapped 3D lighting, bespoke non-tiled scenes, thousands of colors, huge frame counts.
- **Blasphemous (2019):** smallest humanoid ~70px but on **6–8 colors**; depth = hand-baked tenebrism +
  rim light + selective outline + stippled grime + magenta-shifted shadows + one blood-red accent, "no
  shaders." Transferable: bake tenebrist ramps + rim light into palettes, magenta-shadow bias + one
  accent, stipple grime + a top-down permastain layer, contrast/haze depth bands + additive glow. NOT:
  ornate 70–330px sprites, side-scroller parallax/vertical framing, pure-white speculars.
- **Rogue Legacy (2013):** ~40–50px, flat-lit, variety from **modular parts + palette tinting**, not
  pixels. Transferable: palette-index tinting to multiply the roster (RB's grids are native to this),
  modular part compositing, per-district sub-palette + tiny tile kit, same-entity prop reuse. **CAUTION:
  its clean/cute/high-key read is the inverse of RB — take the pipeline, reject the look.**
- **Soulbound (Spiderware pixel MMO):** ~48–64px hi-color (anti-reference on resolution/palette); depth
  = one grade wash per zone + additive emissive light-pools + bloom halos + baked AO + directional cast
  shadow + atmospheric haze. Transferable: additive light-pools (#1), per-zone grade, contact shadow/AO,
  emissive-index accents, prop density. NOT: HD hi-color sprites, clean/pretty palette, real per-pixel
  lighting, smooth internal gradients (use dither instead).

**Convergence:** all six → the lever is **light + grade + atmosphere + density + palette craft**, not
resolution. Techniques that appeared in *every* brief: additive emissive light-pools, per-zone color
grade, contact-shadow/AO, and reserving an emissive accent. Those are Phase 1.

## SOURCES (primary, per brief)
- Octopath / HD-2D: Unreal Engine dev spotlight + OT2 interview; Wikipedia "HD-2D"; Art-Eater grade
  breakdown.
- Hyper Light Drifter: Preston "480p and very intentionally so" (NeoGAF); DeSandro resolution tweet;
  Space Ape UI breakdown; Game Developer interview; GameMaker spotlight.
- Eastward: Game Developer "pixel art adventures" (Zhou) + "Road to the IGF"; 80 Level; Eastward Wiki
  sprite rips (÷3 grid verified); Steam resolution thread; Wireframe preview.
- Blasphemous: Kickstarter "Technology behind the game"; Hollywood Reporter ("no fancy shaders");
  GameAnim time-lapses; The Spriters Resource (measured rips); PCGamingWiki (640×360).
- Rogue Legacy: Glauber Kotaki "why less is more" (Game Developer, PRIMARY); portfolio; PCGamingWiki.
- Soulbound: soulbound.game + press kit + Steam (Spiderware); indiegame.com analysis; direct screenshot
  inspection.

---

## NOT IN THIS DELEGATION
- The **cart-freeze bug** (separate gameplay bug, needs a live console read).
- The **road-grid pass (G-ROADS)** — a separate map-quality wave, already captured in `SPEC-V22-PLAN.md`.
- **Phase 2 true-fill / zero-side-bars** display work — separate display track, operator-gated.
