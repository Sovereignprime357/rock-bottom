# SPEC-V22-PLAN — the operator's ideas, organized into a build order

status: 2026-07-18 · organized from the operator's captured ideas (`SPEC-V22-PACKET.md` + this session's voice notes). AI-led plan, **operator veto standing.** Each wave graduates into its own sub-SPEC and green gate before it ships. Sequenced by *readiness and dependency*, not by size.

---

## THE NORTH STAR STILL RULES EVERYTHING BELOW

> success is the neighborhood adjusting around you. recognition without reward. you don't get to win.

Every idea here is measured against that. **The world noticing you = yes. The world paying you = suspect.** A reward that makes you stronger fights the game; a reward that makes you *known* or gives you *a reason to walk somewhere* fits it.

---

## THE SEQUENCE (why this order)

| Wave | Idea | Status | Why here |
|---|---|---|---|
| **5.1** | **Copper from multiple locations** | ✅ **READY — building now** | Smallest, self-contained, extends a proven pattern (the abandoned-building heist). It is the **pilot for the loot-site system** that break-ins later generalize. Pure density, zero runway cost. |
| **5.2** | **Smoke-spot discovery (map, not key)** | ✅ READY | Design already resolved in `SPEC-V22-PACKET.md §1`: quests *reveal* concession venues, never grant them. Fills a real hole — nothing currently tells a player the park counts. Depends on nothing. |
| **5.3** | **The robbery** (gang areas take your stuff) | ✅ READY | The economy's first real **sink** — everything so far only adds. Bounded in `§PACKET 2`. Medium size, no new tech (combat + inventory + sprite-visible loss already exist). |
| **5.4** | **Break-ins, generalized** (train yard, shacks, tool/cred-gated) | ⚙️ NEEDS SPEC | The big one. **5.1 proves the loot-site pattern; 5.4 generalizes it** into gated building entry across the map. Waits for 5.1 so it inherits a working pattern instead of inventing one. |
| **5.5** | **Fill the barren quarter** | ⛔ BLOCKED by 5.4 | ~25% of the map is empty. It stays empty until 5.4 gives a *reason* to go there (loot, break-ins). Content without a reason to visit is just more walking. Density, not distance. |
| **4.3** | **Sprite shading / more definition** | 🎨 PARALLEL | Operator's "more shading, more definition" note. Pure art track, independent of all gameplay above — can run alongside without collision. |

---

## ~~BLOCKED ON THE OPERATOR~~ → **RULED 2026-07-18**

- **The emergency hitter — ✅ UNBLOCKED, design locked.** The operator ruled both questions on
  2026-07-18: it's a **consumable**, obtained two ways (rare dumpster find **or** crafted by
  **consuming copper instead of selling it**), and it does **not** cost shakes-runway in seconds —
  the cost is that the hit is a **bad trade** (worse than a real rock). Full contract:
  `SPEC-v22-emergency-hitter.md`. **Sequenced right after Wave 5.1** — it depends on copper being a
  settled resource, and it's the wave that gives copper its second life ("sell it or keep it to save
  your life later"). This is the payoff of *not guessing*: the idea sat blocked one message, the
  operator answered, and the answer was better than either thing I'd have built on my own (copper as
  the craft cost was his connection, not mine).

- **The sock money bug (F-SOCK).** `'pawn a sock. $1.'` prints $200/day from an item that doesn't exist. The operator said leave it during his playtest — it's his fast path to late content. **`economy-gate` (built, on `v21-economy` branch) exists to catch it and its siblings.** His call when to close it.

---

# WAVE 5.1 — COPPER FROM MULTIPLE LOCATIONS (the build contract)

## WHAT

Copper is currently strippable from **one** place — the abandoned-building heist (`src/minigames/activities.js`, 3-stage modal: sneak/lockpick/distraction → strip → getaway, daily cap 3) — plus the separate choir-yard mass. The operator wants copper strippable from **several** sites across the map, each with its own flavor.

**This is not new tech. It is the existing heist pattern, parameterized by site.** One shared heist engine, a table of copper sites, each with its own guard, its own entry options, its own take, its own VIBE.

## WHY

Two reasons, both real:
1. **The far map is dead because there's nothing to do there** (operator's own read, confirmed by the barren-quarter finding). Copper sites are a reason to walk to warehouse row, the drainage canal, the train yard.
2. **It's the pilot for break-ins (5.4).** If the site pattern is clean here, 5.4 generalizes it. If it's messy, we learn that on the small version.

## INVARIANTS

- **I-ONE-ENGINE.** ⭐ The 3-stage heist logic is **extracted to one parameterized engine** every site calls with its own config. **Copy-pasting the abandoned-building flow per site is the failure** — same shape as the smoke-transaction extraction (I-ONE-LOOP). One engine, many buildings.
- **I-DAILY-CAP-SHARED.** The existing `heistsToday` cap (3/day) is **economy-load-bearing** — the comment says it caps the conductor-arbitrage floor at ~$270/day. Adding sites must **not** multiply the daily copper ceiling. Decide explicitly: one shared cap across all sites, or a small per-site cap whose *sum* ≤ the current ceiling. **More sites = more variety, not more income.** ([[feedback_no_infinite_resource_loops]])
- **I-NO-SOFTLOCK.** Every site's failure path (guard wakes, lock fails, caught) resolves to `playing` with hp/wanted consequences — never a dead modal. The abandoned building already does this; every new site inherits it.
- **I-VIBE-PER-SITE.** Each site is a *specific cursed place*, not a reskin. The abandoned building has Brutus Jr. dreaming of a tennis ball and pipes singing in b-flat. A new site needs its own equally-specific inhabitant and detail. **Generic "strip the copper" with no character is a VIBE failure**, not a content win.
- **I-REACHABLE.** Every new site sits in already-walkable space (solidity/collision respected post-Wave-4.1) and is far enough from the Block that reaching it is a real trip — but a mandatory objective is **never** gated behind one (`world-gate` I-RUNWAY still holds).
- **I-SAVE-ADDITIVE.** Any new per-site state (visited, cooldown) persists as **new additive keys**; save version and existing shape untouched.

## EDGE CASES

- **Shared cap vs per-site cap** — stated above; this is the one real design decision and it's an economy call. Default to **one shared cap** unless the operator wants site-specific pacing.
- **Guard variety** — Brutus Jr. is the abandoned building's. A second dog at every site is lazy. Each site's obstacle should be *different in kind* (a sleeping dog, a night watchman who's really just tired, a train-yard rail-cop, a feral committee of raccoons — whatever, but distinct).
- **The choir-yard copper mass already exists** — do not collide with it. It's a separate ritual, not a heist site. Leave it.
- **Wanted interaction** — the abandoned getaway can bump wanted. New sites should vary this (a quiet site vs a hot site), which is a natural difficulty knob without touching income.

## ACCEPTANCE CRITERIA

- [ ] One extracted heist engine; `grep` shows the 3-stage flow defined **once**, called per site.
- [ ] At least **2–3 new copper sites** beyond the abandoned building, each with a distinct guard, entry set, and VIBE detail — in distinct map regions (the empty quarter is the target).
- [ ] Daily copper income ceiling **unchanged or explicitly re-ratified** — not silently multiplied.
- [ ] Every site's every path resolves cleanly; no dead modal, no softlock (headless smoke of each site).
- [ ] New state additive; save version unchanged; a save round-trips.
- [ ] `runtime-smoke` + full suite green (**13/13**). If a new gate is warranted (site-registry parity, cap-sum proof), author it and wire it → **14/14**.
- [ ] BRAIN appended; DELEGATION updated; findings (if any) written, not fixed.

## THE TRAP

**The temptation is to make copper sites pay more the farther they are** — a distance-reward gradient. That's a reward economy, and it fights the north star and the daily cap at once. **The reward for walking to the train yard is the train yard** — a new cursed room, a new specific inhabitant, a different way in. Not more dollars per copper. Variety is the payout.

Second trap: **reskinning.** Three sites that are the abandoned building with the serial numbers filed off is worse than one good site. Each is a *place*, with a *who* and a *why-it's-weird*. If it hasn't got a possum-tier detail, it's not done.
