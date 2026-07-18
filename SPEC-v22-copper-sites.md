# SPEC — v22 Wave 5.1: Copper From Multiple Locations

status: building on `v22-copper` · graduated from `SPEC-V22-PLAN.md` § WAVE 5.1 · operator veto standing

## WHAT

Copper is strippable from **four** sites instead of one. The 3-stage heist flow
(entry → strip → getaway) is extracted from the abandoned-building code into **one
parameterized engine**; each site is a config row, not a copy of the flow. The
choir-yard copper mass is untouched — it is a ritual, not a heist site.

## THE SITES

| id | place | region | who guards it | heat |
|----|-------|--------|---------------|------|
| `abandoned` | ABANDONED BUILDING | dealer's corner north | brutus jr. (asleep, dreams of a tennis ball) | as shipped |
| `cold_not` | COLD (NOT) | warehouse row (`cold_not` facade, 4440,1080) | DENNIS (NIGHTS) — guards the cold that left; holds an empty thermos with both hands | quiet — **no path bumps wanted** |
| `water_dept` | WATER DEPT. (DRY) | the drainage canal (`water_dry` facade, 4460,2250) | THE RACCOON QUORUM — seven raccoons; the vote is binding | mid — grate noise / the man from the city |
| `rust_car` | THE RUST FREIGHT CAR | the train yard (rust freight car prop, 380,2820) | TRANSIT AUTHORITY DAN — laminated his own badge; the lamination is peeling | hot — citations, a disbanded department answers |

The b-flat lore is maintained and varied, never contradicted: the freon lines sing
it colder, the dry service lines sing it higher ("like a question"), the signal
wire makes the whole car a tuning fork.

## INVARIANTS

- **I-ONE-ENGINE.** `startHeist` / `heistStage` exist once, in
  `src/minigames/activities.js`. The load-bearing single-instance expressions —
  the `heistsToday` increment, `state.mode = 'heist'` entry, and the copper-yield
  roll — each appear **exactly once** in `src/`. Sites are data
  (`COPPER_SITES`, `src/data/props.js`).
- **I-DAILY-CAP-SHARED.** One `heistsToday >= HEIST_DAILY_CAP (3)` check gates
  **every** site. Yield is `HEIST_YIELD_MIN (2) + rand(HEIST_YIELD_SPAN (3))` =
  2–4 at **every** site. Daily copper ceiling stays 3 × 2–4 = 6–12; the
  conductor-arbitrage floor stays ~$270/day. **More sites = variety, not income.**
  No distance→dollars gradient exists anywhere in the table.
- **I-NO-SOFTLOCK.** Every entry option, both RNG branches, and every getaway,
  both branches, resolves to `state.mode === 'playing'` (or death via `die()`).
  The engine, not the site, owns mode transitions — a site config cannot
  introduce a dead modal.
- **I-ABANDONED-VERBATIM.** The abandoned building's texts, probabilities,
  costs, RNG call order, effect order (toast → hp → glass → wanted), die()
  semantics, and cap-refusal dialogue are preserved exactly from the shipped
  build. Its availability rule (trigger keys on the still-`locked` building, so
  it vanishes at rank ≥ 4 per `update.js` rank unlock) is preserved, not
  extended to new sites.
- **I-SAVE-ADDITIVE.** No new persisted state. Sites are stateless beyond the
  existing shared `heistsToday` counter. Save version untouched; a save
  round-trips unchanged.
- **I-REACHABLE.** All three new sites anchor to existing walkable-adjacent
  geometry (two Wave-4.1 declared facades, one non-solid freight-car prop).
  No new structures, props, zones, or objectives — `world-gate` I-RUNWAY holds
  by construction. Trigger priority slot unchanged (after NPC scan, before
  props), margin ±20px as shipped.

## EDGE CASES

- Cap refusal at any site: site-specific "not tonight" text, `leave` restores
  `playing`, counter does **not** increment.
- Item entry (`water_dept`, a can of food id `food`): consumes exactly **one**
  can (splice, not filter — the soap filter-all at `abandoned` is preserved
  as shipped for parity).
- Cash entries disable below cost; item entries disable when the item is absent
  (label swaps to the have-nothing line, abandoned pattern).
- Death mid-heist: entry-stage death stops the flow (`die()`, no stage 2);
  getaway-stage death follows the shipped quirk (die, then mode playing + save).
- NPC non-collision: conductor (680,2960) and train hopper (820,2940) sit
  outside the rust-car trigger (360–620, 2800–2904); gutter greg (4500,2050)
  sits outside the water-dept trigger (4440–5000, 2230–2480).

## GATE

`tools/copper-sites-gate.mjs` (14th gate, wired into `run-gates.mjs` +
README table):

1. **One-engine proof** — exactly one `heistsToday` increment, one
   `state.mode = 'heist'`, one yield roll in `src/`.
2. **Registry shape** — ≥ 4 sites, unique ids/titles/hints/guards, every entry
   kind known, every site ends options with `leave`, 2 exits per site.
3. **Anchor parity** — facade-anchored rects equal the `world.js` facade rects;
   prop-anchored rect equals the freight-car prop rect.
4. **Shared cap, dynamic** — 3 heists across 3 different sites complete; the 4th
   at a 4th site refuses (counter stays 3, copper unchanged, mode restores).
5. **Ceiling proof** — 200 seeded strip rolls all land in [2,4] at every site.
6. **Path exhaustion** — every site × every entry × forced-low/forced-high RNG,
   then every exit × both branches: mode returns to `playing`, hp/wanted/brain
   deltas match the config bounds. No dead modal.

Red-tested in both directions before trust (duplicate increment → red; cap 4 →
red; a site exit that strands mode → red; yield span change → red).
