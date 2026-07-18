# SPEC — THE EMERGENCY HITTER (v22 Wave, operator-ratified 2026-07-18)

status: design **locked by the operator 2026-07-18** (was BLOCKED in `SPEC-V22-PLAN.md`; now ready). Depends on Wave 5.1 (copper sites) landing first — this is the wave that gives copper its second life. AI-drafted contract, operator veto standing. Graduates into SPEC.md on green gate.

---

## THE RULING (operator's words, verbatim, so it can't drift)

> *"the pipe hitter can be found — its rare but can be found in dumpsters — or made by consuming copper rather than selling it. so essentially the hitter cost to build. sell it or keep it to save your life later. that's great. it's kind of both."*

And on the runway question, endorsing the drafted recommendation:

> *"overall I like your idea"* — i.e. **the hitter does not cost shakes-runway in seconds; the cost is that the hit is a bad trade.**

---

## WHAT

An **emergency hitter**: a consumable that gives a *worse* hit than a real rock, for when you're out of rocks and the shakes are climbing. Two ways to obtain one, both confirmed:

1. **Found** — rare, in dumpsters you're already passing (opportunistic scavenge, never a destination).
2. **Crafted** — by **consuming copper** instead of selling it. Copper is the build cost.

This turns copper from pure sell-fodder into a live decision at every strip: **sell it for cash now, or keep it to save your own life later.** That decision is the whole point of the wave, and it pairs directly with Wave 5.1 (more copper sites = the decision recurs more often).

## WHY

- **It makes copper a survival resource, not just money.** Wave 5.1 adds copper *access*; this adds a *reason to hoard it*. Together they make copper matter.
- **It extends the loop without softening it.** The core tension is that the shakes always win (*"do not stop smoking, the shakes will take you out"*). An emergency hitter that were a free, reliable escape would defuse that. This one doesn't — see I-BAD-TRADE.

## INVARIANTS

- **I-CONSUMABLE.** ⭐ One use, then gone. Not a durable tool. Using it removes it from inventory. (Operator: "consumable.")
- **I-BAD-TRADE.** ⭐ The hitter is **strictly worse than a real rock at the Block.** For reference the real rock is `P.rockedT = 18000; P.crashT = 0; P.shakes -= 50; P.brain -= 4; P.cred += 1` (`src/minigames/activities.js`). The emergency hitter must give **less** on the axes that help and **more** on the axes that hurt — shorter high, weaker or no shakes relief, a bigger brain hit, **no cred**, and a rougher crash. Exact numbers are the operator's to tune, but the *ordering* is the invariant: **a real rock is always the better deal.** If the emergency hitter is ever preferable to a real rock, the wave is broken.
- **I-NO-RUNWAY-COST.** ⭐ Neither obtaining nor using the hitter adds a **mandatory walk**. Dumpster finds are opportunistic (loot what you pass); crafting is an inventory action. **Nothing here adds a leg to `world-gate`'s budget** (two mandatory legs already sit at 96% / 98.5%). The cost lives in the bad trade, not in the clock or the map.
- **I-COPPER-COST.** Crafting spends copper — a real amount, enough that "sell vs keep" is a genuine choice, not a rounding error. The copper sink must not create an infinite loop (you can't strip copper → craft hitter → get copper back). One-directional: copper in, hitter out. ([[feedback_no_infinite_resource_loops]])
- **I-RARE-FIND.** The dumpster find is **rare** (operator's word) — a low-probability opportunistic drop, not a reliable supply. If dumpsters reliably hand out hitters, crafting becomes pointless and the copper decision evaporates.
- **I-SAVE-ADDITIVE.** Hitter inventory + any craft state persists as new additive keys; save version and shape untouched.
- **I-VIBE.** The hitter is a cursed object, described flat. A crafted copper pipe, a found one that's "still warm," whatever — but it lands flat, doesn't editorialize, and doesn't dignify the act. It's a bad idea you're doing anyway. That's the register.

## EDGE CASES

- **Out of rocks AND out of copper AND no found hitter** — this is the intended desperation floor. The shakes climb, you scrounge, maybe you find one, maybe you don't. **That's the game working, not a softlock** — there's always the shakes and always the hustle to get real rocks. Do not add a guaranteed bailout.
- **Crafting at max shakes** — using the hitter at the last second is the whole fantasy; make sure the bad-trade math still leaves you net-worse after the crash, or the emergency hitter becomes a reliable clutch and I-BAD-TRADE is violated in practice even if the per-use numbers look worse on paper. **Verify the full cycle (hit → high → crash) leaves you behind a real rock, not just the instant.**
- **Copper is also sellable and used elsewhere** (Yuri, Pete, the choir mass) — the craft path is one more copper sink among several; it must not starve or collide with those. Check the copper economy still balances after adding a sink.
- **Interaction with Wave 5.1** — 5.1 must land first so copper income is settled before this adds a copper sink. Building them out of order means tuning the sink against a moving supply.

## ACCEPTANCE CRITERIA

- [ ] Emergency hitter exists as a consumable inventory item; using it consumes it.
- [ ] Two acquisition paths: rare dumpster find (opportunistic) + copper craft (spends copper).
- [ ] **The full hit→high→crash cycle is provably worse than a real rock** — a headless comparison of the two, net of the crash, shows the rock ahead on every axis that matters. This is the load-bearing test.
- [ ] No new mandatory leg; `world-gate` budgets unchanged (run it, confirm).
- [ ] Copper craft is one-directional (no strip→craft→strip loop); the copper economy still balances with the new sink.
- [ ] Save additive; round-trips; version unchanged.
- [ ] Suite green (13/13, or +1 if a hitter/economy gate is warranted). Red-test any new gate before trusting it.
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` updated to mark this wave shipped; findings written not fixed.

## THE TRAP

**The instant-relief math will look worse than a rock, and the full-cycle math might not be.** If the hitter gives a short high but a *mild* crash, a player spamming crafted hitters could out-survive someone smoking real rocks — quietly inverting I-BAD-TRADE while every per-use number looks properly nerfed. **The test is the whole cycle, not the hit.** A real rock must win the marathon, not just the sprint.

Second trap: **making the dumpster find generous because "it feels good to find one."** It's supposed to be rare. A reliable found supply kills the copper decision, which is the entire reason this wave exists.
