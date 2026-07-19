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
| **5.1** | **Copper from multiple locations** | ✅ **SHIPPED 2026-07-18** — 4 sites, `copper-sites-gate`, suite 14/14, merged | Smallest, self-contained, extended a proven pattern (the abandoned-building heist). It **piloted the loot-site system** that break-ins later generalize. Pure density, zero runway cost. |
| **5.2** | **Smoke-spot discovery (map, not key)** | ✅ **SHIPPED 2026-07-18** — branch `v22-discovery`, contract `SPEC-v22-smoke-discovery.md` graduated to SPEC.md; `discovery-gate` permanent, suite 15/15 | Design already resolved in `SPEC-V22-PACKET.md §1`: quests *reveal* concession venues, never grant them. Fills a real hole — nothing currently tells a player the park counts. Depends on nothing. |
| **5.3** | **The emergency hitter** (copper's second life) | ✅ **SHIPPED 2026-07-18** — `hitter-gate`, suite 16/16, merged | Consumable, crafted from copper or found rare, strictly worse than a rock. Made copper a "sell it or keep it to save your life later" decision. Shipped right after copper by design. |
| **5.4** | **The robbery** (gang areas take your stuff) | ✅ **SHIPPED 2026-07-18** — `robbery-gate`, suite 17/17, merged | The economy's first real **sink** — everything before it only adds. Bounded in `§PACKET 2`. No new tech (combat + inventory + sprite-visible loss already existed). |
| **5.5** | **Break-ins, generalized** (barren-quarter buildings, tool/cred-gated) | ✅ **BUILT 2026-07-18** — branch `v22-breakins`, contract graduated to SPEC.md; `breakin-gate` permanent, suite 18/18, pushed without merge (operator review) | The big one. **5.1 built the heist engine; 5.5 generalized it**: `tool`/`cred` door kinds in the one engine, `BREAKIN_SITES` (3 sites, barren quarter), the $35 crowbar sharing the tool slot with the torch via pete's swap locker. Own governor (2/day), never copper's. |
| **5.6** | **Fill the barren quarter** | ✅ **BUILT 2026-07-18** — branch `v22-fill-quarter`, contract `SPEC-v22-fill-quarter.md` graduated to SPEC.md; no new gate (leans on world/solidity/breakin gates, both raised pins red-tested), suite 18/18, world-gate byte-identical, pushed without merge (operator review) | Density, not distance. Band got 2 more break-in sites (pool, visitor center: `BREAKIN_SITES` 3→5); sliver got the SCENIC OVERLOOK tableau (reachability driven live first). Bounded on purpose — still-sparse cells are a 5.7, not scope creep. |

*(Numbering corrected 2026-07-18 to ship order: copper 5.1 · discovery 5.2 · hitter 5.3 · robbery 5.4 · break-ins 5.5 · fill 5.6. The earlier table had the hitter and robbery both labeled 5.3; resolved.)*
| **4.3** | **Sprite shading / more definition** | ⚙️ **NEXT — spec ready** (`SPEC-v22-sprite-shading.md`) | Operator's "more shading, more definition... just run the sprites." Pure art track. Reshades the 94-base / 377-key roster denser within the 32×32 ceiling; the operator's eye is the acceptance gate, not the suite. Runs clean — 5.6 left sprite files untouched. |

---

## ~~BLOCKED ON THE OPERATOR~~ → **RULED 2026-07-18**

- **The emergency hitter — ✅ SHIPPED 2026-07-18** — branch `v22-hitter`, contract
  `SPEC-v22-emergency-hitter.md` graduated to SPEC.md; `hitter-gate` permanent, suite 16/16.
  The operator ruled both questions on
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

---

## GRAPHICS / POLISH BACKLOG (operator direction 2026-07-18, post-v22)

Decision: **NOT going full 3D.** Keep shipping the 2D game; the corpus (VIBE + systems + world) is the real asset and is medium-portable later if ever wanted. "Better" = specific, grounded improvements, not a rebuild. Graphics/map track routes to **Codex** (operator's pick; and Codex built the honest-map/physicality layer, so it knows the render/world code — the real reason it fits, since sprites are hand-authored code grids, not generated images). Workflow: operator plays on the big screen → notes specifics → grounded SPEC → Codex builds → gates + operator's eye verify.

- **G-ROADS — the road network isn't a grid (CONFIRMED 2026-07-18).** 28 `ROAD_SEGMENTS`, 0 fully-disconnected (all touch), but edges land on arbitrary coords (X-gaps 620/80/24/88/548/20…, no modulus) and widths wobble 102–112px. Intersections meet off-aligned; reads sloppy though it connects. **Fix:** a road-grid pass — snap positions to a modulus, normalize widths to a constant, clean intersections into a real street system. **Risk/invariants:** roads are walkable and buildings solid, so moving a road can collide a building (`solidity-gate`), move a route stop or mandatory leg (`world-gate` must stay byte-identical or the change is deliberate + re-ratified), or strand a copper/break-in site placed relative to a road. Not cosmetic — a real wave with real gates. Operator's own read: *"some of the roads don't connect, and it's not an actual gridded system."*
- **G-SHADING (4.3)** — sprite shading pass, building now (Fable), operator's eye is the acceptance gate.
- **(collect on the big-screen playthrough)** — operator hasn't played since v19 on a real screen; his played notes become the rest of this backlog.
