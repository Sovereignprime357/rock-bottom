# SPEC — ROUTE BUDGET (v20 Landing 5)
## Project: Rock Bottom
## Resolves: OD-9 — the world gate's first finding
## Status: AI-led draft 2026-07-16 · **orchestrator decision, operator veto standing** · depends on Landing 4 (`v20-world`)

---

## THE FINDING, AND WHY IT IS NOT WHAT IT LOOKED LIKE

Landing 4's gate failed on one leg: **`scrap_gate ↔ ditch_gauge` = 8,274.6px = 60.2s against a
60.0s budget.** 0.3% over. It looked like a world-scope verdict. **It is not.** Measured across the
whole stop table:

| | |
|---|---|
| route stops | **23** |
| distinct pairs | **253** |
| pairs over budget | **1** — 0.40% |
| worst pair on the map | `scrap_gate ↔ ditch_gauge`, **100.3% of budget** |
| budget as share of world diagonal | **80.4%** |

**252 of 253 pairs fit. The single worst pair on the entire map misses by 24 pixels.** The world is
tuned far tighter to this budget than anyone knew — and nobody tuned it, because until Landing 4
nothing could measure it. It only fails on the **full** pool (everything unlocked); the
mandatory-pool legs are clean.

---

## THE DECISION (mine, veto standing)

**Do not move the budget. Do not move content. Do not grandfather. Constrain the generator.**

`rollBlockRoute` (`src/systems/progression_routes.js:167+`) filters the stop pool, **shuffles it,
and takes the first three.** It has **no distance awareness at all.** That is not a design choice —
it is the absence of one. The SPEC has declared the runway invariant since the packet; the
generator was simply never told.

**Rejecting one pair in 253 does not sand the joke.** The clipboard stays absurd and stays cruel;
it just cannot hand you the single worst pair on the map. Cost: **0.4% of theoretical route
variety.** Benefit: the invariant becomes **unrepresentable instead of detected.**

**Why not the other three options:**
- **Move the budget** → 0.3% is inside the noise of a threshold chosen to one significant figure,
  which makes it *tempting* and that is exactly the tell. Moving a threshold to accommodate a
  measurement turns evidence into decoration. `ORCHESTRATOR-NOTES.md` entry #8.
- **Move content** → 24 pixels of world redesign to satisfy an instrument. The world is not wrong;
  the generator is unconstrained.
- **Grandfather** → OD-9 already named it: instrument-deletion with extra steps.

---

## WHAT

Teach `rollBlockRoute` the budget it was always supposed to respect. Same absurdity, same pool,
same three boxes, one pen — the pen still works. It just can't assign the one illegal leg.

**Selection becomes budget-aware rather than blind:** pick the first stop as today, then each
subsequent stop from those within budget of the previous one. Preserve every existing filter
(`completed<2` neighborhood restriction, `unlockFlag` gating, `lastStopId` exclusion) exactly.

---

## INVARIANTS

- **I-ROUTE-BUDGET.** ⭐ No route the roller produces may contain a consecutive leg exceeding
  **60% of a fresh shakes runway** (8,250px, derived at run time — never hardcoded).
- **I-ROLL-TOTAL.** ⭐ **The roller must always return a valid three-stop route.** A constraint that
  can fail to produce a route is worse than the leg it prevents. Every stop has ≥21 legal partners;
  the constraint is satisfiable. **Prove it, don't assume it** — and if a pool is ever too small or
  too sparse (early-game filter, heavy unlock gating), **the documented fallback is to relax to the
  nearest legal partner rather than return null or loop forever.**
- **I-POOL-UNCHANGED.** The stop table does not change. No stop moves, is added, or removed. **This
  landing edits exactly one function.**
- **I-FILTERS-INTACT.** The `completed<2` neighborhood pool, `unlockFlag` gating, `lastStopId`
  exclusion, and the serial/toast behavior are preserved byte-for-byte.
- **I-NO-BUDGET-DRIFT.** The budget is **derived** from walk speed and withdrawal rate at run time,
  the same way Landing 4's gate derives it. **A second hardcoded 8250 anywhere in the tree is a
  violation** — two copies of a number is one copy and one future lie.
- **I-STILL-CRUEL.** The clipboard does not become kind. Routes stay long, stupid, and across town.
  **We are removing one pair out of 253, not adding mercy.**

---

## EDGE CASES

- **Early game (`completed < 2`)** — pool restricted to `x<2100 && y<2100`. Those stops are tightly
  clustered; the constraint should never bite. **Verify, don't assume.**
- **Heavy unlock gating** — a pool of 3–4 stops could in principle have no legal arrangement.
  I-ROLL-TOTAL's fallback covers it. **Test the smallest legal pool.**
- **`lastStopId` exclusion + budget constraint together** — two filters can interact to empty a
  candidate set. Order matters; state which applies first.
- **The player's current position** — the roll doesn't know where the player is standing, and the
  first leg is (player → stop0). **That leg is not governed here** and cannot be: the player can be
  anywhere. Out of scope, and say so out loud rather than quietly pretending stop-to-stop is the
  whole story.

---

## ACCEPTANCE CRITERIA

- [ ] `run-gates.mjs` reports **10/10**, world-gate included, honestly green.
- [ ] `git diff` touches exactly one function in `progression_routes.js`. No stop data changes.
- [ ] **Red-test the constraint**: temporarily widen a stop's coordinates so a legal route is
      impossible → the fallback fires and still returns three stops, never null, never a hang.
- [ ] **Red-test the gate still bites**: revert the roller fix → world-gate fails again. **If the
      gate goes green with the fix reverted, the fix isn't what made it green and something is
      lying.**
- [ ] Statistical check: roll ≥10,000 routes across the full pool and the early pool; **zero**
      contain an over-budget consecutive leg; **zero** return null.
- [ ] The budget appears as a derived value in exactly one place in `src/`.
- [ ] REFACTOR-FINDINGS Landing 4's OD-9 entry updated with the resolution and this reasoning.
- [ ] BRAIN appended; DELEGATION Landing 5 added and checked.

---

## THE TRAP

**The 0.3% will make this feel like ceremony.** Twenty-four pixels. One pair out of 253. Nobody
would ever hit it. **That feeling is the entire reason this is worth doing correctly** — it is the
precise size of problem that gets waved through, and waving it through is how a budget stops
meaning anything. The instrument found the one thing it was built to find, on its first run, in a
world nobody had ever measured. **Honor the reading.**

Second trap: **do not "improve" the roller while you are in it.** No smarter route shaping, no
difficulty curve, no clustering heuristics. One constraint, one function. Anything else you notice
goes in `REFACTOR-FINDINGS.md` and stays there.
