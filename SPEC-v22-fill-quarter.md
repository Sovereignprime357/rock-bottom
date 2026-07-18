# SPEC — FILL THE BARREN QUARTER (v22 Wave 5.6)

status: 2026-07-18 · greenlit by the operator. Unblocked by Wave 5.5 (break-ins) — which built both the *reason* to go to the quarter and the *pattern* this wave populates it with. AI-drafted, operator veto standing. **This is a DENSITY wave, not a systems wave.** Graduates into SPEC.md on green gate.

---

## THE MEASUREMENT (grounded, not vibed)

Gridded the `8600×5600` world into 800px cells and marked any cell with a content anchor (building, facade, prop, zone, copper/break-in site). **26 of 77 cells (34%) have nothing.** The barren regions cluster:
- **A bottom-left band:** roughly `(0–4800, 3200–4000)` — the largest contiguous dead zone.
- **The far-right top:** `(7200–8000, 0–1600)`.
- Scattered singles mid-map.

The operator felt ~25%; the measure says 34%. Either way: **a third of the map is dead, and Wave 5.5 just gave players a reason to walk there.** This wave makes that walk worth it.

## WHAT

Populate the barren regions with **cursed life and reasons to be there — using only the systems already built.** More break-in targets (the engine shipped in 5.5), maybe a copper site (5.1), ambient cursed NPCs and props (existing), the odd discoverable thing. **No new mechanic.** The quarter stops being a walk across nothing and becomes a place.

## WHY

- **It's the last debt from the operator's original read** — *"20–25% of the map is barren wasteland, just grass, nothing to do."* Now there's a reason (break-ins) and a pattern (sites are data) to fix it.
- **It closes the density-not-distance loop.** The world hit its walkable ceiling at 8600×5600 (`world-gate`: two legs at 96%/99%). We can't make the map *bigger*. Filling what's already there is the only remaining direction — and this wave is that direction made real.

## INVARIANTS

- **I-DENSITY-NOT-DISTANCE.** ⭐⭐ This wave adds **zero mandatory legs and moves zero stops.** Everything it adds is **optional** — a reason to detour, never a required crossing. `world-gate`'s readings (campaign legs, route pairs, the 96%/99% ceiling) must be **byte-identical** after this wave. Run it; confirm. **Filling the quarter with a mandatory objective would trip the exact budget the whole map-gate exists to protect.**
- **I-NO-NEW-SYSTEMS.** ⭐ This wave writes **content, not code.** It reuses the shipped engines — break-in sites (`BREAKIN_SITES`), copper sites, ambient NPC spawns, props, discovery tellers. **If an addition needs a new mechanic, it belongs in a different wave, not here.** The temptation to invent while filling is the drift; resist it.
- **I-VIBE-PER-ADDITION.** ⭐ Every single addition is **specific and cursed** — a who, a why-it's-weird, a flat landing. **Generic filler is the failure of this wave specifically.** 26 empty cells is a lot of room to sprinkle noise; don't. Fewer, better, cursed beats more, blander. If it hasn't got a possum-tier detail, it doesn't go in.
- **I-DECLARED-PHYSICALITY.** Any new structure declares `solid` or `flat` with a reason (Wave 4.1 / OD-11). **No ghost buildings** — `solidity-gate` holds. New structures merge into the one collision authority.
- **I-BOUNDED.** New break-in/copper sites ride their existing governors (`breakinsToday` 2/day, `heistsToday` 3/day) — more sites = variety, not income. No new income cascade. ([[feedback_no_infinite_resource_loops]])
- **I-SAVE-ADDITIVE.** Any new state is additive; save version untouched; round-trips.
- **I-SCOPED.** ⭐ This wave does **not** fill all 26 cells. It targets the **worst contiguous dead regions** (the bottom-left band + far-right top) with a **bounded** set of additions, gate-proven. **A tight, verified density pass beats a sprawling half-tested sprinkle** — the same discipline that made copper and break-ins trustworthy. If the quarter's still sparse after, that's a 5.7, not a reason to balloon this.

## THE ONE TASTE FORK (operator's call — recommendation given)

**What weight — gameplay or atmosphere?** The quarter can be filled with:
- **(a) Gameplay** — more break-in targets, a copper site: reasons to *act* out there.
- **(b) Atmosphere** — ambient cursed NPCs, props, texture: reasons to *feel* the place.
- **(c) Both, weighted.**

**Recommend (c), leaning gameplay in the bottom-left band (break-in targets, since burglary just shipped and the quarter is where it belongs) and atmosphere in the far-right sliver.** But this is your taste — the SPEC guarantees the density is cursed and bounded; you weight act-vs-feel at review.

## EDGE CASES

- **A new site near an existing zone edge** — don't overlap a zone rect or a route stop; the empty cells are chosen precisely to avoid that. Verify placement lands in genuinely dead space.
- **Ambient hostiles in a fill region** — if any new NPC is hostile, it's `zoneOnly`-scoped like Skid Row's, never a wandering ambush on a mandatory path.
- **New break-in target's loot** — rides `BREAKIN_SITES`' capped, allowlisted take; can't mint, can't cascade.
- **The far-right sliver `(7200–8000, 0)`** — check it's actually reachable (post-Wave-4.1 collision) before placing content there; barren *and unreachable* is a different problem (leave it, or note it).

## ACCEPTANCE CRITERIA

- [ ] The bottom-left band and far-right top get **bounded, cursed density** — a defined count of additions, each VIBE-passing, each specific.
- [ ] **`world-gate` readings byte-identical** — no new mandatory leg, no moved stop, the 96%/99% ceiling unchanged. (Run it; diff it.)
- [ ] **Zero new mechanics** — `git diff` shows additions to data tables (sites, spawns, props) and content, not new systems. Any new structure declares physicality; `solidity-gate` green.
- [ ] New sites ride existing governors; no income cascade; a headless run confirms.
- [ ] Save additive, round-trips; suite green (**18/18**, or **19/19** only if a genuinely new invariant needs pinning — but this wave should mostly lean on the gates already built).
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` 5.6 shipped; findings written not fixed.

## THE TRAP

**"Fill the barren quarter" is the most unbounded instruction in the whole plan, and unbounded is how content waves rot.** The failure isn't a bad diff — it's a sprawling, generic, half-tested sprinkle of filler that makes the map *busier* without making it *better*, and quietly slips a mandatory leg or a ghost building past the gates. **Bounded, cursed, optional, gate-proven.** Target the worst regions, make every addition earn its cell, and let `world-gate` + `solidity-gate` prove you didn't break the map filling it. **The quarter should feel lived-in, not littered.**
