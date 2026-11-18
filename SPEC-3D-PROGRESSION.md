# SPEC — Full-port progression and territory foundation

P08a, captured before generation on 2026-11-18. Owner root. Source authority:
`src/systems/progression_routes.js`, `src/systems/factions.js`, `currentZone()` in
`src/data/npc_spawns.js`, rank progression in `src/core/update.js`, and the office unlock
predicate in `src/systems/campaigns.js`. Campaign stages and individual quest transactions
remain separate later packets; this foundation does not claim those are reachable.

`progression_routes.gd` composes GameState with a weak owner reference. It owns no duplicate
resources, persistence or RNG. Static tables come from the provenance-checked content catalog.
Public methods: `roll_hustles`, `check_hustles`, `hustle_progress`, `valid_route`, `current_stop`,
`roll_route`, `ensure_route`, `stamp_route(context)`, `patch_tier`, `maybe_unlock_office`,
`update_ranks`, `current_zone`, and `tick_territory(delta_ms, monotonic_ms)`.

## Contracts

- Fourteen hustle predicates preserve source thresholds and snapshots; three eligible shuffled
  jobs/day, intro suppression, dead vendor/combat eligibility, capped displayed progress. A done
  job never pays twice. Rewards come from canonical definitions, not untrusted save reward text.
- Routes use all23 source stops, first-two early pool, unlock flags, previous final exclusion,
  three unique stops and finite shuffle/nearest fallback. Leg budget remains source-derived8250px.
  Source serial/cursor invariants and58px strict interaction radius apply; scene supplies an
  additional authoritative reach/LOS boolean. No stamp when paused, hidden, stunned, boss or
  office contract active. Successful final stamp atomically grants bounded cash/cred, advances
  lifetime, milestones, office availability and next route before one final save request.
- Three completed routes expose the office quest only after intro, before ownership/completion.
  This helper is shared by future campaign code; no duplicate office-unlock reward path.
- Ranks increase through all crossed source thresholds and never decrease with cred loss. Rank5
  unlocks glass_mayor; boss spawning remains the combat owner's task.
- Overlapping zones choose greatest absolute faction reputation, preserving source order on ties.
  Every2s territory evaluates current zone. Neutral/outside clears cash multiplier/heat; hated
  accumulates30 ticks for wanted+1; liked/loved cash multipliers1.2/1.4; loved grants1brain per5
  ticks and one ambient per faction/day. Greeting eligibility/radius80px and per-entry/per10s
  limits match source. Presentation emits typed events. Root calls only during active world time.
- Territory's source accumulator intentionally fires once per invocation at >=2s and resets,
  rather than retroactively paying missed ticks. Production calls every fixed step. Monotonic
  milliseconds are supplied by the scene, preserving source greeting behavior across pauses.
- Save normalizers reject malformed route IDs/duplicates/cursors, unknown hustle IDs, arbitrary
  reward injection, and invalid counters. Valid historical snapshots and completed rewards remain.

## Evidence

Use unchanged source functions in a development-only oracle for deterministic route/hustle
outputs, reward boundaries, zone choice and territory outcomes. Test insufficient distance,
exact58px edge, every blocking mode, duplicate calls, seeded shuffle equivalence, all14 predicates,
eligibility exhaustion, capped rewards, milestones, save/reload and malformed records. Physical
route times are P04/P12 evidence and cannot be inferred from these model checks.
