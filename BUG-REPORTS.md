# BUG-REPORTS — from live operator play (2026-07-18)

> Reported from the operator playing the deployed build — the outside-the-fishbowl check that the 18 gates cannot make. **Freezes and money bugs especially: a headless smoke never rides the cart into the park or crafts at the bench, so these live in exactly the blind spot the gates don't cover.** Each bug gets: a reproduction, a root cause, a fix, and — where possible — a **regression gate** so it can never come back silently. That last part is the SpecMesh move: a bug that's been fixed but not gated will be reintroduced by the next wave.

---

## BUG-1 — THE CART FREEZES THE GAME ON PARK TRANSITION · SEVERITY: HIGH (hang → unplayable)

**Operator's report:** *"the cart freezes the game going into the park, and out."*

**Repro (from the report):** mount the rideable cart, cross the park zone boundary (`park` @ `x:2400,y:900,w:620`). Freezes on entry **and** exit — so it's a per-crossing behavior, not the one-time `parkEntered` flag.

**Ruled out so far (static analysis, 2026-07-18):**
- The one-time park-entry handler (`update.js:323`) — fires once, flag-gated, just a toast + `saveGame()`. Not the repeat freeze.
- The bench-sit `while` loop (`update.js:382`) — drains `benchSitGainT -= 2000` each iteration; terminates. Gated on `sittingOnBench`, not the cart.
- No unbounded `while`/`for` in the cart or movement path — all loops bounded or draining.

**Leading hypotheses (unconfirmed — do NOT fix on a guess, [[ORCHESTRATOR-NOTES #2]]):**
1. **Cart ↔ park-prop collision stuck-state.** The park has four `park_bench` props (`props.js:164-167`, `x:2520–2880`) and a `fountain`. The cart follows the player (`interactions.js:132`). If a park prop became solid (Wave 4.1 physicality pass) and the cart's follow/collision fights the boundary, a per-frame stuck-state could hang or thrash.
2. **A thrown error halting the frame** — a render or update exception when the cart draws/updates inside the park, which reads as a freeze (rAF stops). **A live console read settles this instantly** — this is the fastest root-cause path and the right first move when bug-hunting starts.
3. **Cart speed (1.7×) skipping a boundary threshold** the transition logic assumes you cross slowly.

**Next step:** reproduce live (mount cart → walk into park → read console). A freeze with an exact repro is a browser-console job, not a static-analysis one. Then fix, then a **regression gate** that drives the cart across the park boundary headlessly and asserts the frame completes.

---

## BUG-2 — CRAFT BUG · SEVERITY: TBD (operator flagged, detail needed)

**Operator's report:** *"there are some bugs, especially with the craft"* — the emergency-hitter craft (Wave 5.3), most likely (copper → hitter in YOUR POCKETS).

**Detail needed:** what does it do wrong — wrong copper cost, no hitter produced, a stuck menu, a miscount? **Get the operator's specific symptom before touching it** — "craft is buggy" is not yet a reproduction. Candidate surfaces: the pocket craft option, `HITTER_COPPER_COST`, the `ownsTool`/inventory write.

---

## BUG-3 — SMOKING PARK BUG · SEVERITY: TBD (operator flagged, detail needed)

**Operator's report:** *"especially with the craft and the smoking park."* Likely the park **concession** smoke spot (Wave 5.3 landing) — smoking at the park once it's conceded, or the park's night-only condition.

**Detail needed:** what breaks — the smoke option missing when it should be there, present when it shouldn't (condition/tier), a wrong toast, a bad interaction with the bench-sit or the cart? Candidate surfaces: `concessionConditionMet('park')` (night-only), the park's `conceded` gating, the bench-sit vs smoke-spot overlap. **Possibly related to BUG-1** — both are "the park + something goes wrong."

---

## THE PHASE (operator's stated order)

1. **5.6 fill-the-barren-quarter** — the last v22 feature wave, building now.
2. **Sprite pass (4.3)** — "more shading, more definition." The art track, operator's next priority.
3. **Bug hunt** — the three above, cart-freeze first (severity). Each: repro → root cause → fix → regression gate.

**Discipline for the bug hunt, same as the waves:** no fix on a guess (reproduce first), verify from outside (a live console read beats a code theory), and every fix that can be gated gets a gate — because the gates are what stop the 30-day loop from reintroducing the exact bug we just fixed.
