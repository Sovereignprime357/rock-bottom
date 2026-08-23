import io, sys

path = r"C:\Users\zenit\projects\Rock Bottom 2.0\Rock Bottom\BRAIN.md"
entry = """
## 2026-08-22 — v23: THE GRIME & CINEMA PASS (ox-alpha / Hermes, branch v23-grime-cinema)

**What / why.** Third agentic seat. Operator direction: "improve the graphics and gameplay as
much as you possibly can... needs to feel like a AAA game." Consumed the reserved Phase 2 /
Wave 4.3 lines of DELEGATION-graphics-upgrade.md as the operator go and shipped them as one
wave per SPEC-v23-grime-cinema.md (spec captured before code):

1. **Tenebrist palette regrade (4.3)** — one documented S-curve applied by a one-shot tool
   (tools/v23-palette-regrade.mjs): L<0.14 shadows crushed toward mauve, gentler mid steps,
   lights protected. 48 PALS + PLAYER_LAYER_PAL regraded; anchors (#d4c896/#e8c040/#000)
   untouched; cop/horsecop/brendan (authority blue rule) and player_high (rocked-up gold
   glow) exempt byte-for-byte. Same 8 slots, same index order, same identities. Full
   before/after ledger: artifacts/v23/palette-audit.json.
2. **Ground value dither** in drawGroundTile — deterministic hash-driven dark pits + pale
   dry flecks; asphalt is never one flat fill. Zero allocation.
3. **Facade enrichment** baked once into each LANDMARK_CACHE canvas at init: roofline grime
   streaks, parapet lip, chalk tag, worn trampled path below door apertures.
4. **GRIME_DECOR** — new world.js export, ~150 seeded deterministic items across 11 types,
   init-validated against BUILDINGS/LANDMARK_FACADES/ROAD_SEGMENTS cores/PROPS/WORLD_DECOR/
   zone labels. PROPS stayed exactly 193; WORLD_DECOR exactly 96. Rendered low plane under
   AO; grate steam drifts above actors from a reused buffer.
5. **Weather cinema** — rain splash flecks + a ~23s distant lightning cycle; fog banks
   drift on two slow sines via an oversized draw of the SAME cached FOG_SHEET.
6. **Cinema + feel** — cached VIGNETTE_SHEET composited after the light pass inside
   drawLighting(); damagePlayer() now lands a 60ms hit-stop beat + directional damage arc;
   corpses fade ~2.4s (n.deadAt visual clock); dead-flag/loot logic untouched.

**Decided.**
- Re-ratified sprite-gate's character palette-use hash ONCE at the final state with the
  audit ledger committed beside it — the gate's own designed protocol, not a fight with it.
- INCIDENT_PALS deliberately left untouched this pass: five world-object palettes already
  read grounded; noted for a later pass rather than churning more identity surfaces.
- The grime layer is its own export + own gate, NOT PROPS entries: PROPS=193 is load-bearing
  in solidity-gate, and litter must never be content (no loot, no collision, no NPCs).
- BUG-1 shipped as REGRESSION COVERAGE, not a fix-on-a-guess: static analysis found no
  unbounded loop or thrown-error path on the cart route; without a live console repro of
  the actual freeze, touching physics on a theory would have been ORCHESTRATOR-NOTES #2
  exactly. cart-park-gate now drives the mounted cart across the boundary both ways at
  dt=16/50, rocked speed, sprint seam wobble — throw/NaN/stall fails permanently.

**Tried / failed / caught.**
- First palette-script run corrupted sprites.js (regex match included quotes -> NaN ->
  doubled quotes). Caught by reading the diff before any gate run; restored, fixed, re-run.
- Second run silently skipped four aligned palettes (single-space regex). Caught by
  coverage counting; widened to whitespace-tolerant and re-ran clean.
- My facade enrichment added a SECOND if(f.doorGap) branch — solidity-gate failed on
  exactly "expected exactly one aperture branch" on its first run after the edit. Folded
  the art into the pinned branch. The gates do their job.
- grime-gate's first run caught two real bugs in my own work: an item escaping world
  bounds at 8581,5577 (now clamped) and my invented WORLD_DECOR count 34 vs the real 96
  (corrected to pin the shipped number). A gate written to catch me, catching me.
- TOOL-DISPLAY ARTIFACT, worth recording: two independent reads showed concessions.js
  line 91 as "101****4223" inside Math.imul — which cannot parse — while node --check
  passed and the suite was green. Raw char-code dump proved the file says 1013904223 and
  always said it. The mangling was in the agent tool layer's display, twice, consistently.
  Lesson: when text evidence and mechanical evidence disagree, trust the bytes; two
  instruments that share a fishbowl agree on the wrong thing together.
- Red tests observed firing: sprite-gate stale-hash (pre-ratification) + --red=
  character-palette (#fff injection), grime-gate density/determinism/overlap modes,
  cart-park injected stall. Removed two red-mode names listed but not implemented
  (wiring/alloc) rather than ship decoration.

**Proof.** Suite 21/21 (grime-gate + cart-park-gate promoted permanent; README table ==
runner array, version-gate title/subtitle/README all say v23). Headless drawAll probe:
0.415 ms/frame over 300 frames on a 60-cop night+rain fixture — far under 16ms (logic
upper bound; paint cost still belongs to the operator's eye). Live captures: v22-before vs
v23-after side-by-side at artifacts/v23/v22-v23-side-by-side.png (live-play captures, not
lab-matched fixtures — noted honestly).

**Findings, written not fixed.**
- BUG-2 (craft) and BUG-3 (smoking park) remain operator-detail-needed; untouched here.
- The real-browser frame-time eye gate should be repeated on deployed hardware; the
  headless probe bounds logic cost only.
- G-ROADS (the road-grid pass) remains unbuilt — real wave, own spec, real gates.
- The palette S-curve is a starting point; the operator's eye may want specific palettes
  pushed further. The audit ledger makes any per-palette follow-up surgical.

**Next.** Operator plays v23 on the big screen and rules on: the tenebrist read (mauve
shadows land or push back), grime density, vignette strength, lightning frequency (~23s).
Phase 3 (selective hero bump) stays operator-gated. BUG-2/BUG-3 need his symptoms before
anyone touches them.
"""

with io.open(path, "r", encoding="utf-8") as f:
    existing = f.read()

if "v23: THE GRIME & CINEMA PASS" in existing:
    print("ALREADY APPENDED")
else:
    with io.open(path, "a", encoding="utf-8") as f:
        f.write(entry)
    print("APPENDED", len(entry), "chars")

with io.open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
print("total lines:", len(lines))
