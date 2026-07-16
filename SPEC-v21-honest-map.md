# SPEC — THE HONEST MAP (v21 Wave 4.1)
## Project: Rock Bottom
## Status: AI-led draft 2026-07-16 · operator veto standing · **prerequisite for the fill wave**
## Origin: operator playtest 2026-07-16 — see `REFACTOR-FINDINGS.md` §F-GHOST

---

## THE FINDING THAT WROTE THIS SPEC

The operator said the far map "has a ton of new buildings, but a lot of them have no boundary
markers — you can just walk right over top of it." Measured in source:

| | |
|---|---|
| `BUILDINGS` | **25**, all solid, footprint **1,552,100 px²** |
| `LANDMARK_FACADES` | **28**, **zero** solid, footprint **2,582,280 px²** |
| facades overlapping a real building | **0 of 28** — they are *distinct structures*, not decoration on top of real ones |
| **ghost-to-solid footprint ratio** | **1.66×** |

**There is 66% more painted building in this world than real building, by area.** The collision
loop iterates `BUILDINGS` and nothing else.

**And this is not a missing flag.** Look at the two schemas:

```
BUILDING       { x, y, w, h, color, border, name, solid: true }
LANDMARK_FACADE{ id, x, y, w, h, kind, sign }              ← no `solid` key exists
```

**Physicality is not a property facades have set to false. It is a concept the facade schema does
not contain.** Facades were conceived as a render-layer idea and then the render layer grew larger
than the architecture. Nobody made a mistake; two parallel systems drifted and one of them got the
whole expansion.

---

## WHY THIS COMES BEFORE THE FILL

The operator's read is that the far map feels dead because it's **empty**. The measurement says
something sharper: **it feels dead because it isn't there.** The laundromat is alive and the
warehouse row isn't, and the difference is not decoration — **one is architecture and one is
wallpaper.** You cannot lean on a facade. You cannot be blocked by it, hide behind it, be cornered
against it, or break into it. **The city ends where the collision ends**, and right now the
collision ends well before the map does.

**This is the prerequisite, not a chore before the fun part.** Two reasons:

1. **Solidity is probably the majority of the felt fix.** A world where every structure stops you
   reads as a city even before a single new interaction ships. The complaint "there's nothing to
   do out there" and the complaint "I walk through the buildings" are closer to the same complaint
   than they look.
2. **The ghost path is the path of least resistance.** Every building added during the fill wave
   will be added as a facade, because that is the cheap thing that renders, and the fill wave will
   double the wallpaper. **Fix the class before generating more of it.**

---

## INVARIANTS

- **I-DECLARED.** ⭐ **Every structure in the world declares its physicality explicitly. No
  default.** A facade is `solid` or it is registered `flat` with a reason. **"Nobody said" must
  stop being a possible state** — that state is what produced this.
- **I-FLAT-IS-A-CHOICE.** `flat` is legitimate and must stay available: a mural, a painted-on
  storefront, a backdrop behind a road the player can never reach. **Do not blanket `solid: true`
  across 28 structures.** A backdrop made solid is an invisible wall, which is a worse bug than a
  walk-through building because the player cannot see why they stopped.
- **I-ONE-COLLISION-SOURCE.** ⭐ After this lands there is **exactly one** collision iteration over
  **one** merged set. **Two arrays, one of which is checked, is the bug.** Do not add a second
  loop over facades — that reproduces the defect with more steps.
- **I-NO-NEW-CONTENT.** This wave adds **zero** buildings, zones, props, NPCs, or interactions. It
  makes existing structures honest. **The fill is the next wave and it is not this one.**
- **I-NO-STOP-MOVES.** No route stop, venue, or campaign anchor moves. The world gate's readings
  must remain comparable across this landing.
- **I-DOOR-PARITY.** `BUILDINGS` supports `doorGap` (`update.js`). Any facade that becomes solid
  and has a visible entrance must respect the same door convention. **A solid building with a
  painted door you cannot walk through is a promise the world breaks.**

---

## ⚠️ THE INTERACTION THAT MATTERS — READ BEFORE ESTIMATING

**The world gate measures straight-line distance and says so out loud: every reading is a lower
bound.** Adding collision does not change any straight-line number by a single pixel. **It changes
the real walk.**

**So solidifying 28 structures can push real mandatory legs over budget while the world gate stays
green.** The emperor commute is already at **95.8%** of budget and `pawn_sill ↔ ditch_gauge` at
**98.5%** — both measured straight-line, both with **no detour allowance at all**, and this wave
inserts detours into a map that currently has none.

**This is a known blind spot in an instrument that shipped four hours ago, and this wave is what
exposes it.** It is the same family as OD-10: a change that degrades reality while the gauge holds
still. **Do not solidify 28 structures and report the gate green as if that settled anything —
the gate cannot see this and says so.**

**What this SPEC requires instead:** measure the real path length for the mandatory legs before and
after, with an actual traversal — not a straight line. If a leg crosses budget once detours exist,
**that is a finding for the operator**, and it is a real one, not 24 pixels. **Do not solve it by
leaving structures flat.** Leaving a building a ghost to keep a number green is instrument-deletion
wearing a level-design costume.

---

## EDGE CASES

- **A facade sitting on a mandatory path.** Solid, it becomes a detour or a wall. Finding, not a
  silent choice.
- **A facade the player can currently walk *inside* and stand in.** Solidifying could trap a save
  loaded at those coordinates. **Loading into a newly-solid structure must eject, not wedge.**
- **Facades overlapping roads.** The README claims zero facade-road overlaps; **verify rather than
  inherit that claim.**
- **Facades outside walkable space entirely.** These are the true backdrops and the honest `flat`
  candidates. Reachability, not aesthetics, decides.
- **NPC and cop pathing.** They use the same collision (`update.js:723`). Solidifying can trap or
  reroute them. **A cop wedged in a warehouse is funny exactly once.**

---

## ACCEPTANCE CRITERIA

- [ ] All 28 facades carry an explicit physicality declaration. **Zero undeclared.**
- [ ] Exactly one collision iteration over one merged set. `grep` proves no second loop.
- [ ] `tools/solidity-gate.mjs` — fails if any structure is undeclared; fails if a `flat` entry has
      no registered reason; **red-tested in both directions.**
- [ ] **Real-path measurement** on every mandatory leg, before/after, by traversal. Deltas reported
      with the straight-line numbers beside them so the gap is visible.
- [ ] Save-load into every newly-solid footprint ejects cleanly. No wedge.
- [ ] NPC/cop pathing smoke across each newly-solid structure.
- [ ] Suite green, world-gate included. **If a real-path finding appears, it is reported, not fixed.**
- [ ] Zero new content. `git diff` shows no additions to zone, prop, NPC, or interaction tables.

---

## THE TRAP

**28 structures × `solid: true` is a five-minute diff and it is the wrong answer.** It converts
backdrops into invisible walls, wedges NPCs, and traps saves — and it will pass a naive gate that
only checks "is the field present." **The work is deciding which 28 are architecture and which are
scenery, and that decision is reachability, not vibes.**

Second trap: **the fill wave is right there and it is more fun than this.** Do not start it. **The
fill wave is why this has to be right** — everything it adds will inherit whatever convention this
landing establishes, correct or not.
