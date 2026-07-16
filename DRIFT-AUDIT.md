# DRIFT-AUDIT.md

**Audit date:** 2026-07-15
**Subject:** `rock_bottom_v19.html` (12,737 lines) scored against `VIBE.md`
**Method:** read-only. `VIBE.md` → `SPEC.md` (v13→v19 sections) → game text.
**Scope:** tone drift only. Not a code review, not a design proposal.

---

## HEADLINE

**The voice is not drifting. The rule that protects the voice is.**

I went in expecting to confirm that the v18/v19 empire direction had gone GTA. It hasn't — and I'll show the receipts for that below, because the operator asked me not to just confirm his hunch. What I found instead is quieter and, I'd argue, worse: **VIBE's one mechanically-enforceable rule (the NPC registry) stopped being enforced, and the game's weakest writing is sitting exactly where that rule stopped covering.** The rule didn't fail. It was dropped, and the damage showed up right on schedule.

Second finding, independent: **the game found one great joke and made it the entire endless loop.** ~54 authored beats run one construction. It's a good joke. It's one joke.

Rough scorecard against VIBE's own final check:

| VIBE's shipping question | Verdict |
|---|---|
| Out of place in Aqua Teen? | No. Passes. |
| NPCs named with full cursed lore? | **Partially. This is the finding.** |
| Toast text flat and accounting-style? | Yes. Strongly. |
| Avoided all HARD STOPS? | Yes. All 9 clear. |
| Does the bit get punched? | Rarely. 3 minor instances. |

---

# FINDING 1 — The NPC registry stopped being maintained (STRUCTURAL, HIGH)

## What

`VIBE.md`'s registry table ends at `GUTTER GREG`. That's a v18 NPC. **Every NPC v19 added is absent from it**, along with a long tail of older ambient NPCs.

Shipped in `rock_bottom_v19.html`, absent from the VIBE registry:

**v19 (all 9):** `DARRYL UNDER BLUE`, `GENERAL RECEIPT`, `BISHOP WIRE`, `THE CURB EMPEROR` (L1791–1830), `TARP KNIGHT`, `CART LANCER`, `WIRE DEACON`, `CURB HOLDOUT` (L2094), `CURB PRETENDER No. N` (L2102)

**Older, never registered:** `THE DOG` (L4369), `THE BIG GUY` (L4415), `CUBSCOUT` (L4419), `JOGGER` (L4431), `DOG WALKER (PAISLEY)` (L4441), `BUSKER` (L4450), `HORSE COP` (L4460), `THE VAPE LORD` (L4477), `A POTHOLE (TALKING)` (L4489), `THE PHONE GUY` (L4518), `LAUNDROMAT LADY` (L4574), `METER MAID` (L4592), `FOOD TRUCK GUY` (L4606), `KARAOKE MIKE` (L4643), `YOUR POSSUM` (L2279), `THE BUS DRIVER` (L11699), `BRUTUS THE OLDER` (L12093)

**~26 unregistered vs 25 registered. More than half the cast is off-book.**

## Which rule

> **Rule: New NPCs must extend this table.** If you can't fill all four columns, don't ship the NPC.

and

> Any new NPC must be added to this registry with: name, tic, relationship to world, transaction or threat.

Both verbatim from `VIBE.md` §"Named NPCs — canonical identity".

## How bad

**Structural, and it's the load-bearing one.** Here's why this is more than bookkeeping.

The registry is not documentation. It is **the enforcement mechanism for Rule 3** (names are specific and cursed). The four columns are a *test*: if you can't say what an NPC is missing / sells / pretends / had done to them, the name isn't cursed enough and the NPC doesn't ship. Filling the table is how the rule gets applied.

So: what happens when the test stops running? Look at which names are weakest.

- `DARRYL UNDER BLUE` — passes easily. What was done to him, where he lives, and a specific cursed first name.
- `GENERAL RECEIPT` — passes. What he pretends.
- `BISHOP WIRE` — passes. What he pretends.
- `THE CURB EMPEROR` — marginal. A title, not a name. Grounded only by "curb."
- `TARP KNIGHT` / `CART LANCER` / `WIRE DEACON` / `CURB HOLDOUT` — **fail.** These are rank labels, not names. They are `VIBE.md`'s own ❌ example — "Bandit" — with a prop stapled on.

The four names that fail the four-column test are precisely the four that were never made to take it. That's not coincidence. **The rule's decay produced the drift.**

## Traceable process regression

This one is clean enough to point at. `SPEC.md` §v18, "New people and activities" (L227) explicitly required:

> Both are palette-indexed 16x16 logical characters, prerendered to three cached frames, and **registered in VIBE before ship.**

`SPEC.md` §v19 has **no such requirement anywhere.** The v19 sprite contract (L97–101) specifies seven sprite families, cache ceilings, and silhouette differentiation — and says nothing about the registry. v18 remembered. v19 forgot. The two v18 NPCs are in the table; the nine v19 NPCs are not.

## The operator's four questions

- **Have we drifted?** Yes. Unambiguously — this is the only hard, mechanical, non-arguable rule violation in the audit.
- **Where?** `VIBE.md` registry table vs. the v19 combatant roster (L1787–2102), plus ~17 older ambient NPCs.
- **How?** The SPEC dropped the "registered in VIBE before ship" clause between v18 and v19. Nothing else changed.
- **Why?** Wave-scale. v19 added nine combatants at once as a *system* (clans, guards, adds) rather than as *people*. Guards were authored as spawn parameters — `hp`, `dmg`, `archetype` — and a guard with an `hp` value doesn't feel like it needs a tic. Rule 3 quietly became optional for anything the code treats as a mook.
- **Is it worth keeping?** **No — and this is the one I'd act on.** Not because the table is sacred, but because it's the only rule in `VIBE.md` a machine can check, and it demonstrably works: every NPC that went through it has a good name, and every name that skipped it is weak. Two coherent options: (a) restore the clause and backfill, or (b) **retire the rule honestly** and scope it to transactional NPCs only — which would legitimize the ~17 ambient NPCs but still leave the four v19 mook names failing Rule 3 on their own merits. What shouldn't stand is the current state: a rule that's still written down and silently not running. That's the worst of both — no enforcement *and* a document that lies about the game.

---

# FINDING 2 — One joke is now the entire endless loop (STRUCTURAL, MED-HIGH)

## What

The brief asked: *"Is one [pattern] over-used to the point of predictability?"* Yes — but it isn't one of VIBE's four.

There's an unnamed fifth pattern doing nearly all the work. Call it **the Clerical Pattern**: *observe a mundane municipal object → record it incorrectly on a form → land flat.*

Count of authored beats running this exact construction:

| Surface | Beats | Line |
|---|---|---|
| `ROUTE_STOPS` (v17, endless) | 23 / 23 | L1433–1458 |
| `CLAIM_SITES` survey + sign (v18) | 22 / 22 | L1545–1557 |
| Kingdom marks (v19) | 9 / 9 | L1795–1826 |
| **Total** | **~54** | |

Every single one:

> `'the box contains one coupon.\nyou file it as local news.'` (L1434)
> `'one gate. two on the form.\nyuri will dispute this.'` (L1435)
> `'the meter says 88.\nthere is no unit.'` (L1444)
> `'the sign says building c.\nthere is no building c.'` (L1548)
> `'one curb.\ntwo opinions.'` (L1549)
> `'bucket: one. weather: inside.\nstation entered as permanent.'` (L1796)
> `'horse absent. axle present.\ncavalry entered as rolling.'` (L1810)

The construction `entered as` alone appears **9 times** in player-facing copy.

## Which rule

No verbatim rule forbids this. It's a violation of the *spirit* of the pattern library:

> **Other valid patterns:** The Possum Pattern... The Bad Trade Pattern... The Cursed Aside Pattern... The Inverted Authority Pattern

VIBE lists four patterns because rotation is what keeps flatness from becoming flatline. A pattern the player can predict stops landing flat — it just lands.

## The sharpest version of this

I checked where VIBE's four named patterns actually live. **They're all in `WORLD_EVENTS` (L2385–2415)** — the v4-era content:

- **Possum:** `forklift_possum`, `twin_possums` — *"they are not twins. they are coworkers."*
- **Bad Trade:** `doordash`, `dachshund` — *"it is for a haircut you did not get."*
- **Cursed Aside:** `puddle_wave`, `pothole_say`, `mom_drives_by` — *"the driver is your mom. she does not stop."*
- **Inverted Authority:** `horse_nod`, `pigeon_road`, `pigeon_gang` — *"they nod at you. you are made."*

So:

> **The game's four best patterns are in the content that fires randomly. The game's one repeated pattern is in the content the player does forever.**

Everything v17→v19 added to the *permanent* loop is the Clerical Pattern. Everything VIBE actually names is in the *incidental* loop. The player will run hundreds of route stops and see `forklift_possum` a handful of times.

## How bad

**Structural, but the least "fixable" by rule-policing** — and I want to be careful here, because the individual writing is genuinely excellent. `'the sign says building c. there is no building c.'` is as good as anything in the game. `'rail continues west. train continues not arriving.'` (L1556) actively honors the Conductor bit per VIBE HARD YES #5. This is not bad writing. It's *good writing with no variance.*

The failure mode isn't a bad joke. It's that by route stop 6 the player knows the shape of stop 7. Flatness stops being a surprise and becomes a format. VIBE's thesis — *"Don't punch the joke. The flatness IS the comedy"* — depends on the flat landing being a small deflation of an expectation. If the flat landing is the expectation, there's nothing left to deflate.

## The operator's four questions

- **Have we drifted?** Yes, but sideways, not down. Quality held; range collapsed.
- **Where?** `ROUTE_STOPS` (L1433), `CLAIM_SITES` (L1545), kingdom marks (L1795). ~54 beats, one construction.
- **How?** v17 invented the Clerical Pattern for endless routes. It worked. v18 reused it for 22 claim beats. v19 reused it for 9 marks. Nobody made a bad call; each wave locally reused a proven pattern.
- **Why?** *This is the mechanism worth naming.* The pattern is **generative** — you can produce a passing beat for any object in the world in about nine seconds ("count X as two X"). VIBE's four patterns are not; a Possum beat requires an idea. When an AI is told "make it bigger" and one pattern scales and four don't, the scalable one wins by default, wave over wave. **No one chose this. It's what "bigger" selects for.** That's the real lesson for wave 20: "make it bigger" is not pattern-neutral — it silently promotes whatever is cheapest to mass-produce.
- **Is it worth keeping?** **Keep the pattern, absolutely — it's the funniest thing v17–v19 invented and it should be in `VIBE.md` as a named fifth pattern.** It earned that. What isn't worth keeping is its monopoly. `VIBE.md` should name it *and* say what share of endless content it's allowed to own, or the next wave will make it 70 beats for exactly the same reason it made it 54. **Retiring the rule here means writing a new one, not removing one.**

---

# FINDING 3 — The fantasy register vs. "mundane > magical" (MEDIUM — and I'd keep it)

## What

v19 chose a medieval-succession frame: kingdom, throne, crown, knight, bishop, general, emperor, anoint, royal, succession, court, keep.

## Which rule

> **Mundane > magical.** A possum that wears a construction helmet is funnier than a wizard. A pigeon that demands bread for secrets is funnier than an oracle.

`VIBE.md` §"What TO do (HARD YES)" #6.

This is the most legitimate version of the operator's hunch — stronger, I think, than the GTA framing he raised. VIBE has an explicit stated preference for starting mundane, and v19 starts magical.

## The argument against the finding (which I find stronger)

Every fantasy word in v19 is deflated on contact, usually within the same line:

- The throne is a lawn chair bolted to a curb. The ending reads: `'the kingdom is four curbs and a ditch · the throne is a folding chair'` (L11306)
- The coronation requires: `'smoke one real rock at the block. the crown requires bad reception.'` (L1933)
- The achievement: `'remove the curb emperor. inherit one folding chair and every objection.'` (L1333)
- Victory over a ruler: `'the throne remains a folding chair.'` (L2069)
- Ongoing succession: `'filing 4 remains nonprecedential.'` (L2108)
- Court doors: `'blue court is in recess. the recess has no end time.'` (L1782), `'choir office hours are b flat to b flat.'` (L1784)

That last one is worth pausing on. `'choir office hours are b flat to b flat'` — and `B FLAT STORAGE` as a building sign (L471) — are v19 **building on the copper-sings-in-B-flat lore**, which is `VIBE.md` HARD YES #4 stated verbatim: *"Let things sing. 'The copper sings to you in B flat' is a meaningful, repeatable piece of lore. Maintain it. Build on it."* v19 did exactly what the bible asked.

So the structure isn't *mundane → magical*. It's **magical premise → mundane payload**, where the mundane always wins. The wizard shows up and he's a guy under a tarp. That's arguably the same joke VIBE wants, entered from the other door.

## Where it does fail

The mook names (Finding 1): `TARP KNIGHT`, `CART LANCER`, `WIRE DEACON`. These take the fantasy word and *don't* deflate it. The prop is right there in the name and it still reads as a rank. These are the only places the magical register lands unpunctured.

## The operator's four questions

- **Have we drifted?** Technically yes; in spirit, no. The letter of HARD YES #6 says start mundane. v19 doesn't. The purpose of HARD YES #6 — mundane is funnier than magical — is honored, because the mundane is the punchline every single time.
- **Where?** `KINGDOM_*` copy, L1772–2108; ending L11304–11309.
- **How?** v19 borrowed a genre frame it could hang 12 campaign stages on. `VIBE.md` gives no structure for long-form content — it's a *tone* bible with no *campaign* grammar. v19 needed a spine and imported one.
- **Why?** "Make it bigger" needs a shape. VIBE supplies patterns for 4-beat moments and nothing for a 12-stage arc, so the wave reached outside for scaffolding. That's a gap in the bible, not defiance of it.
- **Is it worth keeping?** **Keep it, and I'd argue the bible should bend here.** `'the throne remains a folding chair'` is the most VIBE-compliant sentence v19 wrote, and it only works *because* there's a throne to deflate. Strict "mundane > magical" would have forbidden the setup that makes the payoff land. This is the case where the rule, read literally, is worse than what broke it. **Recommend: amend HARD YES #6** to something like *"mundane > magical — and if you must go magical, the mundane has to win in the same breath."* v19 already follows that rule. It just isn't written down. Fix the mook names and this direction is sound.

---

# FINDING 4 — Narrator opinions (LOW)

## What

Three places the narrator editorializes.

**a)** `philosopher_man`, L2413:
> `"a man in a robe says 'we live in a society.'\nhe is correct.\nhe asks for $5. he is also correct about that."`

`he is correct` is the narrator rendering a verdict.

**b)** L1621:
> `toast('· NEW BAD IDEA ·\nthe leasing guy has a unit.\nwalk-ins are somehow accepted.',3600)`

**c)** L4622, L7409: `"(+1 rock somehow)"`, `"it is day N. this is somehow your life."`

## Which rule

> **Rule 7: The narrator has no opinions.** The events have opinions. The narrator does not editorialize. There is no "unfortunately" or "thankfully" or "as it turns out."

`somehow` is in that family — a narrator shrug.

## How bad

**Low.** Three lines across 12,737. For calibration on how clean the rest is: I grepped `unfortunately|thankfully|as it turns out|luckily|sadly` across the entire file and got **zero** narrator hits. Rule 7 is otherwise perfectly held.

## The operator's four questions

- **Have we drifted?** Marginally. Three lines.
- **Where?** L2413, L1621, L4622, L7409.
- **How/Why?** `somehow` is a natural-language tic that slips in when copy is written fast; it reads as flat but is doing editorial work.
- **Is it worth keeping?** **Keep (a), it's funny — `he is correct` is deadpan, not editorial, and the $5 undercuts any thesis.** (b) and (c) are just soft. `'walk-ins are accepted.'` is flatter and funnier than `'walk-ins are somehow accepted.'` — the `somehow` is the narrator nudging you. But this is a one-word polish note, not a direction problem. Lowest priority in this document.

---

# FINDING 5 — Punched jokes (LOW — 3 instances)

The brief asked me to find punched jokes. There are very few.

**a)** L2970 `feedPost("the dog returned. then he didn't. legend.", '@crackheadcent')` — `legend` is a punch. Note it's the player's own social feed, which is arguably a character voice rather than the narrator, so it's defensible.

**b)** L2398 `sandwich_lecture`: `"...you nod. you understand none of it. you feel taller.\n(+1 cred)"` — `you feel taller` is a fourth beat after the flat landing. Minor.

**c)** L6968 `toast("BRUTUS THE OLDER IS DOWN.\nyou get +5 max hp.\n(it is called BRUTUS'S COLLAR.)\nyou are wearing the collar now.")` — four beats where three would land. Mild.

**Counter-evidence — the game is excellent at this.** The two biggest moments in the entire game both land dead flat:

> `"tony is on the ground.\nthe corner is yours.\nyou get tuesdays and thursdays."` (L6959)

> `'the kingdom is four curbs and a ditch · the throne is a folding chair'` (L11306)

Killing the final boss of a 12-stage campaign yields `+ $60 · + 40 cred / the throne remains a folding chair.` That is the escalation pattern executed at campaign scale. **v19's biggest structural swing lands flatter than most of v4.**

**Worth keeping?** All three. They're one-word trims, not drift.

---

# FINDING 6 — Asterisk stage directions (TRIVIAL)

L2223 `{ from:'A POSSUM (on a flip phone)', text:"...\n*click*" }` and L2227 `{ from:'YURI', text:"BRUTUS REMEMBER.\n*click*" }`.

**Rule 4:** *"Stage directions are sentences, not asterisks. No `*pulls out gun*`. No `:smirks:`."*

`*click*` is a phone hanging up — onomatopoeia, not a character action. Rule 4's target is characters narrating their own gestures. **Non-finding.** Listed only for completeness so the audit can claim full coverage of Rule 4. Keep.

---

# FINDING 7 — Encoding corruption in toast text (BUG, not drift — but it hits a VIBE surface)

Out of scope for tone, flagged because it corrupts a Rule 5 surface.

**11 mojibake sequences** (UTF-8 read as Latin-1). Player-visible example, L1621:

> `toast('Â· NEW BAD IDEA Â·\nthe leasing guy has a unit....')`

Compare the correct L1964: `toast('· CURB WAR OPEN ·...')`. Also L1531 `// v18 â€” THE OFFICE` (comment only, harmless).

The `Â·` renders as garbage in the toast — i.e. **VIBE Rule 5's ledger-entry format is visibly broken on at least one shipped toast.** Reported as a defect; not a tone judgment, and I made no changes.

---

# THE KNOWN LEAD — VERDICT: NOT CONFIRMED

The operator flagged: *"A KINGDOM is not one block"* → suspicion that v18/v19 drifted into the GTA satire `VIBE.md` forbids. He asked me not to confirm it just because he raised it. **I don't think it holds, and here's the evidence.**

## What the rule actually says

> **GTA satire** — too on-the-nose. We don't satirize "America." We satirize one block.

Read precisely, this is a rule about the **target of the satire**, not the **size of the map**. It sits in the "Tonal references / Lean away from" list — a list of *comedic registers* (Family Guy, Rick and Morty, Borderlands), not a list of level-design constraints. The test is "what is the joke aimed at," not "how many pixels wide is the world."

## What v19 actually satirizes

Municipal paperwork. Permits. Return policies. Buckets. Weather. A curb.

- `'return the return policy to itself.'` → `'return denied.\npolicy returned anyway.'` (L1811)
- `'six carts. one brick.\nbrake status: brick.'` (L1809)
- `'chair witnessed.\nchair requested mileage.'` (L1798)
- `'the sign points up.\nthe highway continues ignoring it.'` (L1551)

GTA's targets are national institutions, media, celebrity, corporate America. **None of that is here.** There is no politician, no corporation, no media personality, no national-institution gag anywhere in the file. The satire aperture is *narrower* than one block — it's frequently one object.

## The strongest counter-argument, and why it fails

`NEWS_POOL` (L2316–2340) is a media-parody device — GTA's signature form. But check the payload. All 23 lines are about the block's own NPCs:

> `"good evening. tony has not blinked since 1994."`
> `"pete weighed a single sock for 11 minutes. the sock did not survive."`
> `"in sports: nothing. the team has not arrived. the team does not exist."`

The **form** is news parody. The **target** is the block. That's Postal 2 (a VIBE lean-*into*: *"the world IS the comedy"*), not GTA. Two lines gesture wider — `"economists call it 'fair'"`, `"osha 'cautiously optimistic'"` — and both are two-word garnishes on a pigeon and a possum.

## The empire self-deflates by design

Both SPEC waves guard this explicitly and the code enforces it:

> "This is a comedy kingdom, not a realistic criminal organization. It owns curbs, bent signs, blue plastic, and incompatible receipts. **It never owns people, sells product, creates passive income, models trafficking**..." (`SPEC.md` L11)

> "The 'empire' owns bent signs and paper records, **never people.**" (`SPEC.md` L141)

v19 invariant 6 (L110): *"Clan conquest owns no person and produces no passive income, allegiance rewrite, faction reputation, product distribution, or new currency."* Achievement copy: `'a larger administrative problem'` (L4165). `'all eleven forms agree with themselves'` (L4166). `'the neighborhood will not acknowledge this.'` (L3975).

**A GTA-satire version of this game would let you run the corner. This one lets you file a form about a curb and the neighborhood doesn't notice.** That is the opposite failure mode from the one suspected.

## Verdict

**On-brief.** The hunch is not confirmed. `VIBE.md`'s GTA rule is about satirical target; v19's target is a bucket. If anything, v18/v19 satirize *one block* harder than v4 did — v4 aimed at a neighborhood, v19 aims at a plastic chair and asks it for mileage.

---

# THE RESIDUAL CONCERN THE LEAD WAS POINTING AT (STRUCTURAL — real, but it isn't GTA)

The instinct behind the lead is worth something even though the GTA framing misses. There **is** a scale problem. It's just a different one, and it's about **premise**, not satire.

## The numbers

| Version | World size | Area vs v17 |
|---|---|---|
| v17 | 4400 × 3400 | 1.0× |
| v18 | 5800 × 3800 | 1.47× |
| v19 | **8600 × 5600** | **3.2×** |

24 zones (L317–352). The throne ditch sits at `(7020,4200)`. The milk crate — the thing the whole game is about — is at `(1064,882)`.

## The premise test

`VIBE.md` opens with:

> **The premise in one sentence:** You are a crackhead. You need a rock. The world is between you and the rock. The world is also very stupid.

Now read `currentPrimaryObjective()` (L2123–2154). Priority order:

`intro → office contract → kingdom → office → block route → quests → idle`

**After the forced intro, the game never tells you to get a rock again.** Not once. The `BAD IDEA` strip — the game's single guidance surface, the thing that tells the player what this game is *about* — points at paperwork, claims, marks, and thrones for the entire mid and late game. The fallback when nothing else is active is `'walk until the neighborhood assigns something.'` (L2153).

The rock is still mechanically central (shakes climb ~0.77/sec at L7349, hit 100 in ~2 minutes, then chip HP at L7352 — the loop does press). And VIBE's premise is intact *in the fiction*. But the game's **stated purpose**, in its own UI, has moved from "you need a rock" to "you have paperwork."

## The mitigation v19 built (credit where due)

v19 saw this and routed the campaign **back through** the core loop. `anoint` (stage 8) cannot be advanced by anything except smoking a real rock at the Block:

> `'smoke one real rock at the block. the crown requires bad reception.'` (L1933)

`SPEC.md` L26 is emphatic: *"Only the successful existing normal `smoke a rock` branch, after one real rock is deducted, advances to `emperor_gate`. Soap, dialogue cancellation, inventory inspection, cooking, load repair, or rendering cannot advance it."*

That is a deliberate, well-made correction: it forces the empire to kneel to the rock. **This is the single best structural decision in v19** and it's evidence the direction is being steered, not drifting free.

## The operator's four questions

- **Have we drifted?** Yes — but on premise scope, not satirical target. The lead pointed at the right neighborhood and named the wrong crime.
- **Where?** `WORLD` L300; `ZONES` L317–352; `currentPrimaryObjective()` L2123–2154.
- **How?** Three consecutive waves each grew the map for a legitimate local reason. No wave was wrong. The compounding is what did it — 3.2× area in two waves.
- **Why?** *"Go wild, make it bigger, make it crazier."* "Bigger" has an unambiguous reading (more map, more systems, more stages) and "crazier" doesn't. An AI told to make it bigger will make it *bigger*, because that's the instruction that's measurable. The tone bible constrains *how lines sound*; it never constrained *how much game there is*. **`VIBE.md` has no scope invariant, so scope was the one axis with no brake.**
- **Is it worth keeping?** **Genuinely open — and this is the operator's call, not mine.** The honest read: the writing at 8600×5600 is as good as the writing at 4400×3400 (the v15 incidents and v19 marks are top-tier), so *quality* is not an argument against size. The argument against is **attention**: "you need a rock, the world is in the way" is a tighter, funnier premise than "you need a rock, and also you're the emperor of four curbs." The anoint gate is v19 admitting this and patching it.
  **My actual recommendation: don't roll anything back. Add the missing invariant.** `VIBE.md` should say what the map is allowed to be, and — more importantly — the `BAD IDEA` strip should have to point at the rock some meaningful fraction of the time, because that strip *is* the game's thesis statement to the player. Right now the bible governs every line of dialogue and has nothing to say about the one line of UI that tells the player what the game is.

---

# RANKED SUMMARY

| # | Finding | Severity | Verdict |
|---|---|---|---|
| 1 | NPC registry stopped being enforced (~26 unregistered; all 9 v19 NPCs) | **STRUCTURAL / HIGH** | **Fix or formally retire.** The only hard rule violation. Caused the weak mook names. |
| 2 | Clerical Pattern owns ~54/54 endless beats | **STRUCTURAL / MED-HIGH** | **Keep pattern, break monopoly.** Name it in VIBE as pattern #5. |
| R | Premise scope: map 3.2×; BAD IDEA never says "get a rock" | **STRUCTURAL / MED** | **Operator's call.** Don't roll back; add a scope invariant. |
| 3 | Medieval register vs "mundane > magical" | MEDIUM | **Keep — amend the rule.** Deflation is always immediate. Fix mook names only. |
| 4 | Narrator `somehow` / `he is correct` | LOW | Keep `he is correct`. Trim `somehow` (×3). |
| 5 | Punched jokes (`legend`, `you feel taller`, Brutus 4-beat) | LOW | Keep. One-word trims. |
| 6 | `*click*` asterisks (×2) | TRIVIAL | Non-finding. Keep. |
| 7 | 11 mojibake sequences corrupting a shipped toast | BUG | Defect, not drift. Reported only. |

**GTA-satire lead: NOT CONFIRMED. On-brief.**

---

# CLOSING ASSESSMENT

`rock_bottom_v19.html` is **substantially on-brief**, and I want to say that plainly because the audit was commissioned on a suspicion of the opposite.

Nine of nine HARD STOPS pass. No real drug information, no punching down, no slurs, no moralizing, no fourth-wall breaks, no real public figures, no player-as-victim, no player-as-villain, no pity. Rule 7 is held to three soft words in 12,737 lines. Rule 5 is held so well that the climax of a 12-stage campaign pays out `+ $60 · + 40 cred / the throne remains a folding chair.` The Conductor's bit is not only honored but *built on* four separate times (L1445, L1556, L2484, L2407). The B-flat copper lore has become a building sign and a set of office hours. The v15 incidents — `'a mattress enters traffic.'` → `'traffic yields.\nthe mattress does not.'` → `'it changes lanes without signaling.\nit has no driver.'` → `'the mattress exits.\nright of way is restored.'` — execute VIBE's 4-beat structure better than VIBE's own examples do.

Something worth naming: **this game got bigger without getting louder.** That is the rare outcome. The overwhelming failure mode of "go wild, make it crazier" is escalation into noise — punched jokes, quips, self-awareness, a thesis. v19 does none of that. It got *quieter* as it got bigger. The biggest thing in the game is a folding chair.

The two real findings are both about **the bible, not the game**:

1. The one rule VIBE can mechanically enforce got silently switched off between v18 and v19, and the damage landed exactly where the rule stopped covering. That's not a tone problem; it's a **process** problem, and it's traceable to one dropped clause in `SPEC.md`.

2. VIBE governs the sentence and says nothing about the shape. It has no scope invariant, no campaign grammar, and no rule about pattern rotation — so under "make it bigger," those three axes were the only ones with no brake, and all three moved. The document that wins every contradiction can only win contradictions it anticipated.

The operator's instinct that *something* went wrong at v18/v19 is correct. The specific charge — GTA satire — is not supported by the text. What actually happened is subtler and more useful: **the game didn't drift away from `VIBE.md`. `VIBE.md` stopped being big enough to cover the game.**

That's a document problem, and per the document's own header — *"If anything you ship later contradicts this document, this document wins"* — it's a problem only the operator can resolve. The bible cannot lose an argument, so it has to be *right*. On mook names it's right and was ignored. On mundane-vs-magical it's arguably wrong and was correctly overruled. On scope and pattern rotation it's silent, and silence is what "make it bigger" fills.

---

*READ-ONLY audit. No game file, `VIBE.md`, or `SPEC.md` was modified. `DRIFT-AUDIT.md` is the only write.*
