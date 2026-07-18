# SPEC — SMOKE-SPOT DISCOVERY (v22 Wave 5.2) — the map, not the key

status: 2026-07-18 · design ratified in `SPEC-V22-PACKET.md §1` ("the map, not the key"). AI-drafted contract, operator veto standing. Depends on the merged recognition + concession systems (Landings 2–3). Graduates into SPEC.md on green gate.

---

## THE HOLE THIS FILLS (verified in source, not assumed)

The four concession venues (park, choir_office, underpass, laundromat) become conditional smoke spots at the `conceded` tier — **15 visits** (`REGULAR_THRESHOLDS.conceded`). But **nothing tells a player a venue exists.** The only hint is `concessionActionHint(x,y)` (`campaigns.js:632`), which fires **only when you're near a spot you've already conceded.** Before that, the venue is invisible.

**So today the discovery path is: sit at the park fifteen times by coincidence, and only then does the game acknowledge it was ever a spot.** No player will do that. **The concession system is shipped and largely undiscoverable.** This wave is the discovery layer.

## WHAT

Wild-crackhead NPCs **tell you a venue exists.** Their dialogue flips a per-venue `discovered` flag. Discovery makes the venue **visible** — a hint/marker so you know to go earn it — but **you still have to sit there 15 times.** The neighborhood still concedes on its own terms, its own count.

**The quest is a map, not a key. It reveals the room. It does not open it.**

## WHY

- **It surfaces a whole shipped system** (recognition + concessions) that's currently a secret.
- **It's more VIBE than an unlock.** *"the dryer knows"* passed between crackheads is the world talking. A quest-giver handing you a reward is a different genre.
- **Secrets survive being told; achievements die when you have them.** A revealed-but-unearned room is a secret you're chasing. A granted room is a box you ticked.

## INVARIANTS

- **I-MAP-NOT-KEY.** ⭐⭐ **No NPC, dialogue, flag, or quest may grant a concession, move a venue to `conceded`, lower any `REGULAR_THRESHOLDS` value, or credit a recognition verb.** Discovery flips **only** a `discovered` boolean. The ledger remains the sole path to `conceded`. **This is the whole wave. If discovery ever shortcuts the count, the wave is a reward economy wearing a map costume and it's broken.**
- **I-REVEAL-IS-COSMETIC.** The `discovered` flag changes **visibility only** — hints, markers, dialogue availability. It touches **no** gameplay value: not the tier, not the count, not the condition, not the smoke transaction. A discovered venue and an undiscovered one at the same visit count are mechanically identical; only the UI differs.
- **I-STILL-EARNED.** After discovery, reaching `conceded` still requires the full 15 recognition visits. The hint may now say *"you know this counts — the bench doesn't know you yet"*, but the bench's count is untouched.
- **I-NO-LEDGER-TOUCH.** Discovery writes to a **new additive `discovered` set**, never to the recognition counters or visit ledger. `recognition-gate`'s zero-reward-leakage proof must still pass unchanged — and because discovery routes *around* the ledger, a **new gate check** must prove discovery cannot write tier/count (see THE GATE).
- **I-VIBE-TELLER.** The NPCs who reveal venues are cursed and specific, and they reveal by *implication*, not exposition. *"the choir office keeps hours. b flat to b flat."* — not *"NEW SMOKE SPOT UNLOCKED: choir office."* Fragments, lowercase, land flat (VIBE Rules 1–7). The Clerical rotation cap still applies to any new permanent beats.
- **I-SAVE-ADDITIVE.** The `discovered` set persists as new keys; save version and existing shape untouched; a pre-5.2 save loads with everything undiscovered (correct — those players hadn't been told yet).

## EDGE CASES

- **Discovering a venue you've already conceded** — no-op on gameplay; the dialogue can acknowledge it (*"you already know. the vent knows you know."*) but nothing changes. Never *un*-conceal or reset.
- **Discovering the same venue twice** — idempotent. Second telling is flavor, not a re-grant.
- **The Block** — is unconditional and always known; it is **not** a discoverable venue and must not enter the discovered set.
- **A discovered venue whose condition is currently false** (park in daytime) — the hint reflects "known, not currently open," never "go here now." Honesty rule from concessions carries over: never advertise a spot you can't use *right now* as usable now.
- **Order independence** — discovery and recognition are orthogonal. A player can grind a venue to `conceded` **without ever being told** (the old accidental path still works); discovery just makes the intended path visible. Both must coexist.

## ACCEPTANCE CRITERIA

- [ ] A `discovered` set exists as additive save state; fresh + pre-5.2 saves start empty.
- [ ] At least one (ideally 2–3) wild-crackhead reveal(s), each surfacing a venue by cursed implication, VIBE-passing.
- [ ] Discovery flips **only** visibility. A headless test proves: discover a venue → its recognition tier, count, and condition are **byte-identical** to before discovery.
- [ ] The hint/marker system shows discovered-but-unconceded venues as *known but unearned*; undiscovered venues stay invisible.
- [ ] `recognition-gate` still green (unchanged). **New gate check proves I-MAP-NOT-KEY**: no discovery path writes a counter, tier, or threshold — red-tested by wiring a discovery to grant tier and confirming the gate fails.
- [ ] Suite green (**14/14**, or **15/15** if a discovery gate is added). Frozen v19 untouched.
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` 5.2 marked shipped; findings written not fixed.

## THE TRAP

**The tempting shortcut is to make discovery "helpful" by nudging the count** — a free visit, a head start, "you've been here once now." **That is the exact thing that breaks it.** The moment discovery touches the ledger, it stops being a map and becomes a key, and the north star (recognition without reward, the bench earns you not the other way around) dies quietly while `recognition-gate` stays green — because the leak came in through a door the gate doesn't watch. **Discovery reveals. The count is sacred. Build the gate that proves the door is shut.**

Second trap: **exposition.** *"NEW LOCATION DISCOVERED"* is a different game. The crackhead mutters a fact about a place and moves on. You overhear the neighborhood; nobody hands you a quest marker with a bow on it.
