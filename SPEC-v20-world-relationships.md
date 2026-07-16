# SPEC — WORLD RELATIONSHIPS (v20 Landing 4)
## Project: Rock Bottom
## Implements: `SPEC-V20-PACKET.md` §3 (Wave-4 budgets)
## Status: AI-led draft 2026-07-16 · operator veto standing · closes the v20 wave
## Depends on: Landing 2 (`ccdbf75`) and Landing 3 (`ad96cbe`), both merged

---

## WHAT

A permanent gate that computes **runway** and **coverage** from the route/venue tables and **fails
on regression**. Not new content. A ruler.

---

## WHY — THIS IS THE GATE THE DRIFT AUDIT ASKED FOR

The audit's finding, in its own words: **the game didn't drift from VIBE — VIBE stopped being big
enough to cover the game.** `VIBE.md` governs *the sentence*. It is **silent on scope**. And
silence is what *"make it bigger"* fills. The world went 4400×3400 → 5800×3800 → **8600×5600**, one
"go wild" at a time, and **nothing ever said no, because nothing could.** Every gate we have checks
whether the game is correct. **None of them check whether the game is still walkable.**

**For the autonomous loop this is the most important gate in the repo.** A loop pointed at this
game *will* make it bigger — that's what the instruction "improve it" decays into. Content gates
will stay green the whole way down while the world quietly becomes a commute.

**The budget is not a style preference. It is arithmetic**, and all of it is traceable to source
(re-derived 2026-07-16, not taken from the packet on faith):

| Quantity | Source | Value |
|---|---|---|
| walk speed | `baseSpeed = 2.2` px/16ms, `runtime_ui.js:33` | **137.5 px/s** |
| withdrawal rate | `P.shakes += 0.0008 * dt`, `update.js:124` | **0.8 shakes/s** |
| fresh shakes → cap | `shakes: 20` (`runtime_ui.js:355`) → 100 | **80 shakes = 100s runway** |
| world | `WORLD = { w: 8600, h: 5600 }`, `world.js:15` | diagonal **10,262px = 74.6s** |

**One unobstructed corner-to-corner walk already burns 74.6% of a fresh runway — before collision
detours.** That is the number that should make everyone nervous, and it is the current shipped
state, not a projection.

---

## INVARIANTS

- **I-RUNWAY.** No **mandatory** route or campaign leg may exceed **60% of a fresh shakes runway**
  at walk speed = **60s = 8,250px** of actual traversal. Mandatory means: the player cannot
  progress without it. Optional wandering is not governed — **the game is allowed to be big; it is
  not allowed to make you commute to finish it.**
- **I-COVERAGE.** With all four concessions earned, **no map point sits farther than ~45s walk
  (~6,190px) from a *potentially* legal smoke spot.** "Potentially" is load-bearing: a concession
  is measured as coverage even when its condition is currently false. **Otherwise coverage would
  flicker with a dryer.**
- **I-BLOCK-DAY-1.** **The Block alone must cover every day-1 strip objective** inside I-RUNWAY. A
  new player has earned zero concessions. **The floor of this game is the Block and one runway.**
- **I-TRANSPORT.** The rideable cart stays **unique**. **No fast travel in v20.** Concessions *are*
  the fast travel, thematically — the reward for being known somewhere is not having to walk home.
- **I-MEASURED-NOT-VIBED.** Every number this gate asserts is **computed from the tables at run
  time**, never hardcoded. A budget you have to hand-update is a budget that silently rots.
- **I-NO-BALANCE-CREEP.** ⭐ This landing **changes zero gameplay values.** Not one timer, not one
  distance, not one spawn. **It measures.** If a measurement fails, that is a finding for the
  operator — **not a license to widen the budget until it passes.**

---

## THE TRAP, NAMED

**If the gate fails on first run, the tempting fix is to change the budget.** Do not. The budget is
derived from the withdrawal rate and the walk speed — **it is what the game already is.** Moving
the number to make the light turn green is not fixing anything; it is **deleting the instrument and
reporting the absence of readings as health.** That is precisely how the world got to 8600×5600
with every gate green.

**If a real leg genuinely exceeds the budget, that is a finding.** Write it down. Hand it to the
operator. **Landing 4's job is to hold up the ruler, not to like the answer.**

Second trap: **"make the world smaller" is not this landing's job either.** No content moves. This
is a measuring device shipped alone, on purpose, so that the measurement is trustworthy before
anyone acts on it.

---

## EDGE CASES

- **Collision detours make true path length > straight-line.** Straight-line is a **lower bound** —
  a leg that fails straight-line is definitely too long; one that passes might still be too long in
  practice. **State which the gate uses and never let a lower bound masquerade as the real number.**
- **The cart exists and is faster** (`baseSpeed * 1.7`, `runtime_ui.js:50`). Budgets are computed at
  **walk** speed. The cart is one object in an 8600×5600 world; **it is not a transport system and
  must not be modeled as one.**
- **Sprinting burns shakes faster** (`+0.012 * dt`, `update.js:125`) — sprinting is not an escape
  from the runway, it is a **loan against it.** Budgets assume walking.
- **Bus destinations exist** (14 of them, v18). If the bus already breaks I-RUNWAY as a mandatory
  path, **that is a finding about the bus**, not a reason to loosen the rule.
- **A leg that fails today.** Likely. Expected. **Report it; do not fix it here.**

---

## ACCEPTANCE CRITERIA

- [ ] `tools/world-gate.mjs` computes runway + coverage **from the live tables**, not constants.
- [ ] Wired into `run-gates.mjs`. Suite reports **9/9** — or reports an honest failure with the
      offending leg named, its length, and its budget.
- [ ] Every asserted constant traced to a `file:line` in the gate's own comments.
- [ ] **Red-tested**: move a venue far enough to break coverage → gate fails naming the venue;
      restore → green. **A budget gate that has never failed is a decoration with a number on it.**
- [ ] Zero gameplay values changed. `git diff` on `src/data/` and `src/core/` shows no value edits.
- [ ] Findings appended to `REFACTOR-FINDINGS.md` for anything measured and not fixed.
- [ ] BRAIN.md appended; DELEGATION Landing 4 checked; register entry added.

---

## WHAT THIS BUYS, BEYOND V20

After this lands, **"make it bigger" has a mechanical opponent for the first time.** The loop can
add zones forever and the moment one of them puts a mandatory objective past the runway, **the
suite goes red and names it.** VIBE governs the sentence; **this gate governs the map**; between
them the corpus finally covers both halves of what the game is.

The gap it does **not** close: nothing measures whether the game is *fun*. That stays a human's job
and always will. **Gates make bad work impossible. They do not make good work happen.**
