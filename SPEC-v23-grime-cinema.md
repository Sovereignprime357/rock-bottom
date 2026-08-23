# SPEC-V23 — THE GRIME & CINEMA PASS (Graphics Phase 2 + Wave 4.3 + feel pack)

status: 2026-08-22 · third agentic seat. Operator direction: "improve the graphics and gameplay as
much as you possibly can... needs to feel like a AAA game... run at max everything." This packet
consumes the operator go that `DELEGATION-graphics-upgrade.md` reserved for Phases 2–3 and the
Wave 4.3 shading pass (`SPEC-v22-sprite-shading.md`). AI-led, **operator veto standing.** Every
system here extends the Phase 1 lighting stack; none replaces it.

---

## WHAT THIS WAVE IS

The research thesis (six reference studies) was: *the distance between Rock Bottom and AAA pixel
games is not pixel count — it's lighting + grade + atmosphere + density + palette craft.* Phase 1
shipped the light. This wave ships the rest:

1. **Tenebrist palette regrade** (Wave 4.3): every character palette re-ranked as
   near-black core → mid → base → warm rim → accent, hue-shifted shadows, same 8 slots.
2. **Ground value work**: per-tile dither/value variation so asphalt is never one flat fill.
3. **Grime decor library**: a new WORLD_DECOR-family grime layer (dead shrubs, paper litter,
   bottles, tire piles, tar stains, crates, cones, mattresses, wires) scattered across the world,
   plus cheap secondary motion (sign flicker, grate steam, barrel smoke, wire sway).
4. **Weather upgrade**: rain splash particles, drifting fog banks, occasional far lightning.
5. **Cinematic frame**: cached vignette sheet always on; damage comes with a directional indicator
   and a hit-stop pulse; sprinting kicks dust puffs.
6. **BUG-1** (cart freeze at park boundary), reproduced live if possible: fix root cause + regression
   coverage via runtime-smoke extension or its own gate check.

## INVARIANTS

- **I-ONE-STACK.** ⭐ All rendering stays inside the shipped pipeline: ground tiles → fabric → zones
  → facades/buildings/props/decor → AO plane → actors → particles/player → foreground → restore →
  `drawLighting()` (mask → grade → emissive → glow) → weather → overlays. Nothing renders before the
  ground or after the glows except through existing overlay sites.
- **I-CANVAS2D-NOSMOOTH.** No WebGL/shaders/`ctx.filter`; no `imageSmoothingEnabled = true`
  anywhere. New soft visuals come from pre-baked sheets built once at init from radial gradients.
  `image-rendering: pixelated` on the canvas stays untouched.
- **I-GATE-FROZEN-PINS.** sprite-gate: 94 bases / 377 keys / draw-site hash / anchor expressions
  byte-identical. phase1-lighting-gate: emitter families, grade alpha bounds (multiply .04–.18,
  overlay ≤.08), render order, contact-shadow contract, emissive allowlist all unchanged.
  solidity-gate: WORLD/ZONES/PROPS(193)/ROAD_SEGMENTS(28)/NPC counts frozen. version-gate:
  title/subtitle/README tell one story (**v23**). docs-gate: README table matches runner GATES.
- **I-RERATIFY-NOT-DRIFT.** The sprite-gate character palette-use hash is re-ratified ONCE, after
  all palette edits land, by an audit proving the change is a pure re-map of values inside the same
  8 slots (no key count change, no index semantic change), then red-tested once in both directions
  (stale-hash fails; tampered forbidden color fails). Same discipline for any environment hash move.
- **I-PALETTE-DISCIPLINE.** Character palettes stay arrays of ≤8 hex entries, index 0 transparent.
  Forbidden colors still forbidden (no `#fff`, no bright blue outside cops/horsecop/brendan, no
  pastel/neon bases). Shadows shift toward mauve/magenta; one warm rim step; accents stay cursed.
- **I-GRIME-IS-DECOR.** The new layer lives in a NEW export (`GRIME_DECOR`) in world data — PROPS
  stays exactly 193, WORLD_DECOR keeps its existing entries and types. Grime items are non-solid,
  non-interactive, carry no loot, spawn no NPCs, cast no shadows, own no save state. They render in
  the low decor plane under the AO pass. Placement is deterministic (seeded), viewport-culled, and
  must not overlap building rects, road segments' cores, or prop footprints (checked at init).
- **I-MOTION-IS-CHEAP.** Secondary animation is bounded per frame: one shared time-base read
  (`state.visualNow` or `performance.now()` once per frame), zero allocations in loops, no new
  canvases or gradients after init. Steam/smoke use the existing additive particle budget pattern;
  ambient loops are culled off-screen. Frame budget: the full stack stays <16ms/frame headless
  fixture equivalent (measured via the runtime harness timing where possible).
- **I-WEATHER-SUBTLE.** Rain splashes/fog drift/lightning are screen-space reads of existing
  `state.weather`; they never touch gameplay state. Lightning flash rides the existing
  `state.flash` overlay channel. Fog drift reuses FOG_SHEET with a slow offset, not a second sheet.
- **I-FEEL-NO-BALANCE.** Hit-stop, directional damage indicator, sprint dust, corpse fade change
  presentation only: no damage numbers, cooldowns, speeds, drops, or timers beyond visual decay.
  The 18s→8s loop, boss <90s rule, and economy constants untouched.
- **I-VIBE.** Everything added serves grime, wear, specificity. If it reads cleaner/cuter/nicer, it
  is wrong. The vignette darkens; the fog dirties; the lightning is distant and sickly, not epic.

## EDGE CASES

| Case | Required behavior |
|---|---|
| daylight (nightAmount≈0) | grade/vignette still apply; grime layer unaffected; lightning disabled |
| deep night | vignette multiplies with night mask without crushing nameplates/objective marker |
| fog + night + crash | ordered compositing survives; player/hostile readability holds |
| grime item under a facade/prop | placement validation rejects overlaps at init (console assert + gate) |
| unknown future decor type | grime renderer ignores unlisted types loudly in dev (once) |
| hit while invulnerable (iframes blink) | indicator shows only for actual hp loss events |
| corpse fade vs persistence | fade is visual only; dead-flag logic and respawn rules untouched |
| cart mounted during hit-stop | freeze applies to sim already; indicator/dust must not double-spawn |
| title screen | none of the new passes run (mode guard preserved) |
| mobile canvas scale | vignette sheet scales with canvas; DOM HUD untouched |

## ACCEPTANCE CRITERIA

- [ ] Palettes regraded across the roster; sprite-gate green with ONE re-ratified hash + audit note;
      red-tested stale-hash and forbidden-color directions.
- [ ] Ground dither live; zone palettes keep their hues (legibility-gate untouched inputs).
- [ ] GRIME_DECOR shipped with init-time overlap validation; ≥120 placed items; zero PROPS/WORLD_DECOR
      regressions; rendered below AO; culled off-screen; deterministic.
- [ ] Secondary motion live: ≥3 loop types (steam, sign flicker, wire sway / barrel smoke); all
      allocation-free in the hot path.
- [ ] Weather: rain splashes + fog drift + rare lightning; all screen-space; suite green.
- [ ] Vignette sheet always-on post-lighting; hit-stop + directional damage indicator + sprint dust +
      corpse fade shipped; no balance drift (world-gate/solidity/recognition/concession all green).
- [ ] BUG-1: reproduced live (or root-caused statically with the repro attempt documented), fixed,
      regression-tested.
- [ ] New permanent gate `grime-gate` wired into run-gates + README table (docs-gate green);
      suite reports 20/20.
- [ ] Before/after matched screenshots committed to artifacts; BRAIN appended; DELEGATION/SPEC-V22-PLAN
      status lines updated; version bumped to v23 everywhere version-gate looks.
- [ ] Frozen v19 + lineage files untouched.

## THE TRAPS

1. **"AAA" sliding into polish.** The mandate is denser and more cinematic, not nicer. Rogue Legacy's
   clean high-key look is the anti-target. If the neighborhood stops looking condemned, undo it.
2. **Palette regrade becoming a recolor.** Same 8 slots, same identities: Tony's coats stay Tony's
   coats. A player must recognize every NPC instantly. Re-rank VALUES, keep HUE FAMILIES except the
   shadow-shift toward mauve which is the point.
3. **Grime becoming clutter that hides gameplay.** Items never render over actors, never sit in door
   apertures (60px south-center of facades), never under interaction-dense spots (Tony corner, pawn
   window, church steps, block crate).
4. **Per-frame allocations.** Every loop allocates nothing. Strings/colors resolved at init. The
   Phase-1 perf discipline is load-bearing.
5. **Red tests that can't fire.** Every gate addition gets one observed red before its green is
   trusted (ORCHESTRATOR-NOTES #3/#13).
