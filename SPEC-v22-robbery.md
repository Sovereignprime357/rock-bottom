# SPEC — THE ROBBERY (v22 Wave 5.4) — the first sink

status: 2026-07-18 · design captured in `SPEC-V22-PACKET.md §2`. AI-drafted contract, operator veto standing. Uses only shipped systems (skid-row combat, inventory, equip, sprite gear layers). Graduates into SPEC.md on green gate.

---

## WHAT

In the gang zone (**SKID ROW**, `zone @ 2480,1520,900,720`), the hostiles don't just hurt you — **they take something.** A bit of cash, an inventory item, or an equipped piece of clothing that **comes off your sprite.** You do not get it back.

## WHY — THIS IS THE ECONOMY'S FIRST SINK

Every mechanic in the game so far **adds**: strip copper, panhandle, sell, find. Nothing takes. An economy that only fills has no weight — money stops mattering once you have enough. **The robbery is the first thing that subtracts**, and it's the most VIBE mechanic in the whole v22 plan: a bad trade, an indignity, no editorializing, it lands flat. *"you wake up with less. the coat is gone. someone is warmer."*

## WHAT ALREADY EXISTS (grounded, so this invents nothing)

- **Skid Row hostiles** (`npc_spawns.js:350`): brutus/lurch/sherri variants, aggro on sight, `zoneOnly` to the skid zone, archetypes **charger / grabber / swarmer**.
- **`P.equip = { shoes, hat, coat, tool }`** (`audio_save.js:95`), each equipped slot drawn as a `gear_<id>` layer on the player sprite (`actors_weather.js:333`). **Un-equipping a slot removes its layer — visible loss is free.**
- **`P.inventory`** — array of `{id, n, q}` items.
- **`die()`** and the wanted/hp systems already handle the "you got beaten" moment.

## THE ONE DESIGN DECISION (operator's call — recommendation given)

**What triggers the theft?** Three options:
- **(a) On the grabber's grab.** The `grabber` archetype (Lurch-Skid) already grabs; make the grab *take* instead of just damage. Clean, thematic — the grabber becomes "the one who takes your stuff," a distinct identity per archetype.
- **(b) On defeat** — instead of `die()` in the skid zone, you're robbed and dumped at the zone edge with less. **Skid Row doesn't kill you; it takes from you.** Gives death a zone-specific flavor and fits *"you don't get to win."*
- **(c) Low chance on any hit.** Simplest, but frequent and noisy.

**Recommendation: (a) as the core, optionally (b) as the escalation.** The grab-takes-a-thing is the readable, bounded version; robbed-instead-of-killed is a stronger beat if you want the zone to feel like a place that *empties* you rather than ends you. **(c) is the one to avoid** — theft on every hit is punishing and un-cursed. Operator picks; I build.

## INVARIANTS

- **I-SINK-ONLY.** ⭐ The robbery **only subtracts.** It never grants the player anything (no "they drop something better"), and the taken item does **not** come back on a timer. It's gone. That's the whole point — a sink, not a trade.
- **I-NO-SOFTLOCK.** ⭐ The theft may **never** take an item required to progress a live campaign objective, a route-gating tool, or the last of something the game needs back (`stripe_package`, an active quest item, the only `tool` a gate requires). **Bounded to the safely-losable set:** cash, food/junk/soap/detergent-class consumables, and cosmetic-ish equip (coat/hat/shoes) — never a progression key. A robbery that strands the campaign is a bug, not an indignity.
- **I-VISIBLE.** ⭐ If they take an equipped item, it **comes off the sprite** (un-equip the slot → the `gear_` layer stops drawing). `sprite-gate` guards the 93-base roster; this changes *what's equipped*, not the roster. **An invisible robbery is a bug** — the player must *see* they lost the coat.
- **I-NO-RECOVERY-GUARANTEE.** You do not get a quest to reclaim it. It's gone. (Stretch, not required: you *may* later see the item on the NPC who took it — flavor only, never a reliable get-back. If built, it stays a sighting, not a retrieval.)
- **I-BOUNDED-RATE.** Theft is **occasional, not every encounter.** A cap or cooldown so a skid-row crossing can't strip you naked in one pass. Getting robbed should sting, not softlock your economy. ([[feedback_no_infinite_resource_loops]] in reverse — a sink still needs a governor so it can't cascade.)
- **I-ZONE-SCOPED.** Only skid-row hostiles rob. The dog, the ambient pedestrians, the boss — none of them. This is a *place* that takes from you, not a universal mechanic.
- **I-SAVE-ADDITIVE.** Any new state (last-robbed cooldown, what-was-taken for a sighting) is additive; save version untouched; round-trips.
- **I-VIBE.** The theft lands flat and cursed. *"BRUTUS (SKID) takes your coat. he does not put it on. he just holds it."* No editorializing, no "unfortunately." The indignity is the joke.

## EDGE CASES

- **Robbed with nothing losable** — you carry only progression keys / nothing. Then they take **cash**, or if you're broke, the theft is a near-miss beat (*"he checks your pockets. finds a receipt. keeps the receipt."*) — never a softlock, never nothing-happens-silently.
- **Robbed of the emergency hitter** (Wave 5.3) — the hitter is a losable consumable, so yes, it can be taken. That's fine and cursed (you crafted a lifeline and skid row took it), but confirm it doesn't strand a max-shakes death spiral into an unavoidable loss — the shakes were always going to win anyway, so this is in-theme.
- **Equipped-slot theft with nothing equipped** — falls through to inventory/cash; never errors.
- **Save mid-robbery** — the theft resolves atomically (item removed before save), never a half-state.
- **Interaction with `die()`** — if option (b), robbed-instead-of-killed must not double-fire with the existing death path; exactly one resolution per defeat.

## ACCEPTANCE CRITERIA

- [ ] Skid-row hostiles can take cash / a losable inventory item / an equipped clothing slot, per the chosen trigger.
- [ ] **Never takes a progression key** — a headless test attempts theft while carrying `stripe_package` + an active quest item and confirms they're untouchable.
- [ ] Equipped theft **removes the sprite layer** — verified (equip a coat, get robbed, confirm `P.equip.coat === null` and the `gear_coat` layer no longer draws).
- [ ] It's a **pure sink** — a headless run confirms no robbery path ever increases cash/inventory/equip.
- [ ] Bounded rate — a full skid-row crossing can't strip everything; cooldown/cap proven.
- [ ] Zone-scoped — no non-skid NPC robs; a headless check confirms.
- [ ] Save additive, round-trips; `world-gate` unaffected (no new legs).
- [ ] Suite green (**16/16**, or **17/17** if a robbery gate is warranted — and one likely is, to pin I-SINK-ONLY and I-NO-SOFTLOCK). Red-test any new gate before trusting it, and prove your mutation reaches the real path (ORCHESTRATOR-NOTES #13).
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` robbery row shipped; findings written not fixed.

## THE TRAP

**The temptation is to make the robbery "fair" — a chance to resist, a way to get it back, a drop in exchange.** Every one of those softens it into a trade, and the whole reason this wave exists is that the game has no real sink. **A sink you can dodge or reverse isn't a sink.** It should sting and stay stung. The mercy is the *rate* (you're not robbed every step), not the *outcome* (what's taken is gone).

Second trap: **taking a progression item because "it's in the losable set by accident."** The bounded set must be an **allowlist of safely-losable classes**, not a denylist of known-bad items — a denylist misses the next quest item someone adds. Default to un-takeable; opt items *into* losability.
