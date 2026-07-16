# SPEC — the economy gate (v21, branch `v21-economy`)

> Origin: the operator's 2026-07-16 playtest report ("a couple money bugs") and F-SOCK in
> REFACTOR-FINDINGS.md. One bug was found by reading. The question "what else is broken" has no
> mechanical answer. This gate is that answer. **It finds money bugs. It does not fix them.**

## WHAT

`tools/economy-gate.mjs` — a ruler over every site in `src/` that increases a player resource
(cash, rocks, soap rocks, copper, supplies, dirty supplies, inventory items). It asserts each
site is exactly one of:

- **TRADE** — guarded on a real precondition *and* consumes a player resource in the same
  transaction. Proven behaviorally, not asserted from a list: the gate drives the real menus.
- **LEDGER** — a deliberate no-item payout, named in the gate, citing a register token that
  literally appears in `REFACTOR-FINDINGS.md` (the I-EXCLUSION-LEDGER shape from OD-10, reused
  because it already survived contact: unsigned entries cannot compile green, stale entries go
  red too).
- **KNOWN VIOLATION** — a standing defect on the register (F-SOCK). Reported red by name, every
  run, until the operator rules. Not ledgered — a bug signed into the ledger would be a
  grandfather list, and OD-9 already ruled that instrument-deletion.

A site in none of the three classes is a red: a new money site nobody classified.

## WHY

The infinite-resource-loop family has nothing watching it. The sock proves the class exists in
shipped code; PETE_CAP clipping it to $200/day is luck, not design. Every future wave adds
vendors and payouts, and the fill wave (SPEC-v21-honest-map) is about to add many. Without this
gate, "is the economy sound" is answered by whoever happens to reread 40 dialogue actions.

## HOW (two halves, both load-bearing)

**Half 1 — static census.** Comment-stripped scan of `src/**/*.js` for resource-increase
statements (`P.cash +=`, `P.cash++`, lane `= … + …` self-increment forms, `P.inventory.push(`).
Census sites are keyed `(file, normalized statement, occurrence index)` — occurrence index
because the sock's grant line is byte-identical to the license plate's grant line nine lines
down. The census is the completeness backstop: **a grep finds assignment sites, not violations**
(named trap in the delegation) — so the census never judges, it only refuses to let a site go
unclassified. Classification lists live in the gate; both directions fail (unclassified census
site / list entry matching no census site / double-claimed site).

**Half 2 — behavioral audit.** Loads the modular game in the VM harness, instruments the
resource lanes with accessor traps that capture `Error().stack` on every increase (VM module
identifiers are real file paths, so an observed grant attributes to its exact census site), then
drives every reachable menu through the real `dialogue()`/`activeDialogue` machinery under two
state profiles:

- **BROKE** — zero everything. Any enabled option that produces a grant with no same-action
  consumption is a live free payout. TRADE sites must not fire at all here (that is the guard).
- **STOCKED** — copper, rocks, supplies, junk, license, lottery ticket, crossword, stripe's
  package, stash, faction tiers, the works. Any grant at a TRADE site must be accompanied by a
  same-action decrease of some player lane (cash, rocks, soap rocks, copper, supplies, dirty
  supplies, inventory multiset, hideout stash lanes). That is the consumption.

Options are run through their real `disabled` flags (a disabled option is a passing guard — the
UI is the contract). Submenus are walked by index-path replay with fresh rebuilds so every
closure sees honest state. RNG branches get repeated trials on the harness's seeded generator;
sites whose grant lives behind a die roll are marked `rng: true` in the lists, which tolerates
non-observation but still asserts conservation whenever the branch does fire. Deterministic
TRADE sites that the driver never reaches are a red — an unexercised trade is an unverified one.

Direct-call probes cover transactional functions that no menu reaches deterministically
(`applyCookOutcome` with forced outcomes, including the soap-rock branch).

## INPUTS

- `src/**/*.js` (census + live modules via `tools/runtime-harness.mjs`)
- `REFACTOR-FINDINGS.md` (cite-token existence for LEDGER and KNOWN_VIOLATIONS entries)

## OUTPUTS

- PASS only when: census fully classified both directions, all trades guard+conserve
  behaviorally, all ledger cites resolve, and the KNOWN_VIOLATIONS list is empty.
- Otherwise a red naming each offender by file, line, statement, and — when behaviorally
  observed — the exact lane deltas ("+$1, nothing consumed, inventory empty").
- Standing state at ship: **red, naming F-SOCK** (behaviorally confirmed live), because the
  operator is mid-playtest and the sock is deliberately left. The gate runs LAST in the suite so
  its standing red can never mask a regression in the ten gates that protect shipped behavior
  (same placement logic as world-gate's original slot).

## INVARIANTS

- **I-EVERY-DOLLAR-NAMED** — every census site is claimed by exactly one of TRADES / LEDGER /
  KNOWN_VIOLATIONS; every list entry resolves to a real census site. Both directions fail.
- **I-TRADE-CONSERVES** — every observed firing of a TRADE site includes a same-action decrease
  of some player resource lane. A guarded option that forgets its decrement goes red even though
  its guard is intact.
- **I-TRADE-GUARDED** — under the BROKE profile no TRADE site fires. A decrement that forgets
  its guard goes red even though its consumption is intact. (These two are one invariant seen
  from both sides; the sock fails both.)
- **I-SIGNED-LEDGER** — every LEDGER and KNOWN_VIOLATIONS entry cites a token that literally
  appears in `REFACTOR-FINDINGS.md`. Unsigned cannot compile green; stale (entry with no site)
  cannot either.
- **I-STANDING-RED** — KNOWN_VIOLATIONS entries always fail with the finding's name and current
  behavioral evidence. Emptying the list requires either fixing the bug (operator's call, not a
  gate change) or ratifying it into the LEDGER (operator's call, on the record).
- **I-NO-FIX** — the gate changes nothing in `src/`. A failing reading is a finding for the
  register, never a license to patch the game to make the light turn green. This wave ships the
  instrument with its violations *unfixed on purpose*: a gate that has never been red cannot be
  trusted to go red.

## EDGE CASES / NAMED SCOPE LIMITS

- **"Consumes what it claims"** is label prose; no grep can judge that the consumed noun matches
  the label's noun. The gate proves *a* real consumption and *a* real guard, not label truth.
  Same honest-scope rule as docs-gate not checking descriptions.
- **Gambles** (price guy, lottery) can be net-positive per firing. Conservation is asserted as
  "something was staked in the same action," not "net ≤ 0" — the invariant is you cannot mint
  from nothing, not that the house always wins.
- **Shared helpers**: `giveBusPass()` grants at one site with two callers — paid (pinky) and
  free (mom's dawn drop). Site-granularity cannot split callers, so the site is LEDGERed; the
  ledger licenses the free path and tolerates the paid one.
- **Cred, brain, hp, equipment, weapons are out of scope**, named here on purpose: none of them
  convert to cash anywhere in the tree (no sell-back path exists), so they cannot mint. If a
  future wave adds an equipment vendor that buys, the census lanes must grow first.
- **Transfers**: the hideout chest moves value between `state.hideoutStash` and `P`. Stash lanes
  count as consumption, so withdrawals read as conserving trades, which they are.
- **OD-10's known limit is inherited verbatim**: the cite check proves a signature exists, never
  that it was worth signing. REFACTOR-FINDINGS.md is append-only and an agent can append. Ledger
  growth is a human-review trigger — process control, not code control, stated in the gate
  header where the hand goes.
- The behavioral audit is deterministic per run (seeded RNG, sequential probes), so a green is
  reproducible; upstream code changes that reshuffle the RNG stream can shift which gamble
  branches a given run observes, which is why gamble sites are `rng: true` instead of
  must-observe.
