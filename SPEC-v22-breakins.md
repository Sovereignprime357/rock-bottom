# SPEC — BREAK-INS, GENERALIZED (v22 Wave 5.5)

status: 2026-07-18 · design from `SPEC-V22-PACKET.md` + the barren-map conversation. AI-drafted, operator veto standing. **Depends on Wave 5.1 (copper) — which already built the engine this generalizes.** Graduates into SPEC.md on green gate.

---

## THE HAND-OFF COPPER LEFT (grounded, so this reuses instead of reinventing)

Wave 5.1 didn't just add copper sites — it built a **parameterized heist engine**:
- `COPPER_SITES` is a **data table** (`src/data/props.js:323`); the engine iterates it (`:474`) and `activities.js` runs any site by id.
- The engine already understands **entry kinds**: `roll` (probability, over/under effects), `lockpick` (the 4-pin minigame), `item` (spend something), plus distraction options (`props.js:319`).
- **The tool slot exists** — `P.equip.tool` (`update.js:604`, currently the propane torch). A crowbar is a natural tool.
- **Cred/rank gating exists** — `P.cred`, `RANKS[].cred` thresholds, `P.rank` (`update.js:859`). A cred gate is a natural entry condition.

**So break-ins is not new tech. It is: (1) a general loot-site table beyond copper, (2) two new entry-gate kinds — `tool` and `cred`, (3) varied cursed loot per building.** The engine is already the abstraction; this wave feeds it new data and two new gate types.

## WHAT

Break into buildings across the map — especially the **barren quarter** — each gated by a **crowbar** (`P.equip.tool`) or a **cred threshold**, each with its own cursed inhabitant and its own specific loot. Same 3-beat engine (get in → take → get out), new doors, new takes.

## WHY

- **It gives the empty quarter a reason to exist** — which is why Wave 5.6 (fill the quarter) is blocked on this. Break-in targets ARE the content the barren map is missing.
- **It's the payoff of copper being the pilot.** The engine held across 4 copper sites; now it generalizes. If copper's engine was clean (it was — one faucet, gate-proven), this is mostly data + two gate kinds.

## THE THREE DESIGN FORKS (operator's calls — recommendations given, not blocking)

1. **New table or extend `COPPER_SITES`?** — **Recommend a new `BREAKIN_SITES` table using the same engine**, leaving copper sites as-is. Copper sites share the `heistsToday` cap and yield copper; break-in sites want their own loot and their own gates. Same engine, second table. (Extending copper's table risks entangling the copper income cap with unrelated loot — cleaner to keep them separate tables through one engine.)

2. **The crowbar — how do you get it?** — The operator said *"maybe you need to find a crowbar."* Options: buy from Pete (a known vendor), find it (rare, like the hitter), or it's a one-time world pickup. **Recommend: a one-time purchase from Pete OR a findable pickup** — a durable tool (unlike the consumable hitter) that lives in `P.equip.tool`. It gates the `tool`-kind doors. **Flag:** if the crowbar occupies the same `tool` slot as the propane torch, the player chooses which to carry — that's a real, interesting decision, but confirm it doesn't break torch-gated content. This is the one to get the operator's read on.

3. **What's the loot?** — Copper sites give copper; break-in buildings give **varied cursed loot**: cash, a consumable, a gear item, maybe crowbar-tier tools, maybe copper. **This is where VIBE lives** — each building's take is specific (*"a drawer of expired coupons and one (1) working flashlight"*). Not a generic loot roll. Operator taste territory; the SPEC sets the caps, he sets the flavor at review.

## INVARIANTS

- **I-ONE-ENGINE.** ⭐ Break-in sites run through the **same** heist engine copper uses — no second heist implementation. New entry kinds (`tool`, `cred`) are added to the engine's vocabulary once; sites are data. Copy-pasting the flow is the failure (same as I-ONE-LOOP, I-ONE-ENGINE from copper).
- **I-GATE-REAL.** ⭐ A `tool` gate genuinely checks `P.equip.tool === 'crowbar'`; a `cred` gate genuinely checks `P.cred >= N`. A gated door the player can open without the gate is a bug. **Red-test the gate holds** (no crowbar → door refuses).
- **I-NO-MINT-DRIFT.** Break-in loot is **capped** — per-building cooldown or daily cap, like copper's `heistsToday`. More buildings ≠ uncapped income. The economy stays governed. ([[feedback_no_infinite_resource_loops]]) The robbery's sink and this wave's source must stay balanced — check the net after adding.
- **I-NO-SOFTLOCK.** Every break-in path (gate refused, guard wakes, caught) resolves to `playing`. No dead modal. The crowbar/cred gate refusing is a clean bounce, not a trap.
- **I-VIBE-PER-BUILDING.** Each building is a *specific cursed place* with a specific inhabitant and a specific take. A reskinned copper site is a failure. Possum-tier detail or it's not done.
- **I-REACHABLE.** Sites sit in walkable space (post-Wave-4.1 collision), target the barren quarter, and **never gate a mandatory objective** — `world-gate` I-RUNWAY holds. Optional content only.
- **I-SAVE-ADDITIVE.** Crowbar ownership, per-site cooldowns, looted-once flags — all additive; save version untouched; round-trips.

## EDGE CASES

- **Crowbar vs torch in the `tool` slot** — if they share the slot, swapping is the cost of carrying one. Confirm no torch-gated content (the propane-torch heist path) becomes permanently unreachable — the player can always re-acquire/re-swap.
- **Cred-gated building below the threshold** — the door states the gate flat (*"the lock knows you're a nobody. come back somebody."*), never a silent no-op.
- **Break-in loot that's also robbable** — anything looted that's in the robbery's losable allowlist can be taken by skid row later. That's fine and cursed (the loop closes), but note it.
- **A building with both a tool gate and a cred gate** — decide precedence; state it. Don't let one silently bypass the other.
- **Interaction with the copper engine's `heistsToday`** — break-in sites should NOT consume the copper daily cap (separate loot, separate governor), or copper and break-ins starve each other. Separate counters.

## ACCEPTANCE CRITERIA

- [ ] Two new entry-gate kinds (`tool`, `cred`) added to the **one** engine; `grep` shows the engine defined once, both gate kinds handled in it.
- [ ] A `BREAKIN_SITES` data table (separate from `COPPER_SITES`), **2–3 cursed buildings** in the barren quarter, each with a distinct inhabitant, gate, and specific loot.
- [ ] The crowbar exists as a durable `tool`-slot item with a defined acquisition path; a `tool`-gated door **refuses without it** (headless-proven, red-tested).
- [ ] A `cred`-gated door refuses below threshold, opens at/above it (headless-proven).
- [ ] Loot is capped/cooldowned; a headless run proves income can't cascade; break-in cap is **separate** from copper's `heistsToday`.
- [ ] Every path resolves to `playing`; no softlock; save additive + round-trips; `world-gate` unaffected.
- [ ] Suite green (**17/17**, or **18/18** if a break-in gate is warranted — likely, to pin I-GATE-REAL + I-NO-MINT-DRIFT). Red-test it, and prove the mutation reaches the real path (ORCHESTRATOR-NOTES #13).
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` updated; findings written not fixed.

## THE TRAP

**Break-ins is the biggest wave in the plan, and the temptation is to fill the whole barren quarter at once.** Don't. **This wave proves the generalization on 2–3 buildings; filling the quarter is 5.6.** A tight, gate-proven core beats a sprawling half-tested one — the copper wave earned its trust by being small and provable, and 5.6 inherits whatever this establishes.

Second trap: **a second heist engine.** The copper engine is right there and it's proven. Adding `tool`/`cred` to its vocabulary is the move; forking a parallel break-in flow reintroduces exactly the drift I-ONE-ENGINE exists to prevent. One engine, more doors.
