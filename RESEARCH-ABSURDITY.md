# RESEARCH-ABSURDITY.md

**Date:** 2026-07-16
**Subject:** raw material for Rock Bottom, mined from real news
**Method:** web search → source verification → transformation. Read `VIBE.md`, `SPEC-V20-PACKET.md`, `DRIFT-AUDIT.md` first, in that order.
**Scope:** findings only. No game code written. No file in this repo modified except this one.

---

## HEADLINE

Nine candidates. Every seed traces to a cited source I actually opened. Four things got cut, and the cuts are documented in §CUTS — including one I liked and one where the research thread walked straight into the ethical line and I dropped it.

**The thing worth knowing up front:** the operator's special-rock ask has a clean solution hiding in a real 2018 court case, and it isn't a compromise. The power he wants (hit cops, no arrest) and the curse the north star requires (nobody serves you) turn out to be **the same fact viewed from two sides** — you are not on the list. One mechanism, two directions. That's `for every good thing, an equal and opposite` executed without bolting a penalty onto a power-up. See §SPECIAL ROCKS, Rock A.

**On the ethical line:** it did real work. It killed the entire shopping-cart thread (§CUTS 4). That thread was on the operator's own suggestion list and every route into it ran through someone's housing crisis. It's out.

---

## THE ETHICAL FILTER — what it actually rejected

Stating this plainly because a filter nobody can see working isn't a filter.

Searches run that produced usable material: municipal labor grievances, animal officeholders, courthouse wildlife, pothole vigilantism, legal-death bureaucracy, one-euro property schemes, prize-fulfilment absurdity, IP-geolocation defaults.

Searches run that produced material I **discarded on the line, not on quality**:
- **Shopping carts** (operator's own suggested vein). Every substantive result routed through unhoused people using carts to move their belongings. The humor required someone's housing crisis to land. Dropped the whole vein. See §CUTS 4.
- **"Florida Man" aggregators generally.** Skipped as a category. The genre's engine is arrest records, and arrest records are where crisis lives. The forklift-to-Wendy's story VIBE-style humor wants is one story in a hundred, and the aggregators don't sort them. Went to municipal/labor/animal beats instead, which is where the *situation* is absurd without anyone needing to be suffering.

No candidate below involves an overdose, an addiction, a possession arrest, a mental-health crisis, homelessness, or a death. No real name appears. No story is quoted verbatim.

---

# CANDIDATE 1 — THE GOATS HAVE A CONTRACT

**The real seed.** In June 2026 a city utility's public-sector union filed a formal grievance because management subcontracted waterway brush-clearing to a herd of goats without notifying the union — and the union's stated complaint included that its workers then had to clean up after the goats and do extra work to finish the job. A near-identical grievance was filed in 2017 when a university brought in a goat crew to clear poison ivy; the union called the goats "scab" labor.
Sources: [614NOW, 2026-06-15](https://614now.com/2026/hot-topics/barnyard-blues-city-hires-goats-against-union-agreement) · [Grand Rapids Patch, 2017](https://patch.com/michigan/grand-rapids/hungry-michigan-goats-devour-union-jobs-grievance) · [Quartz, 2017](https://qz.com/1025165/union-workers-in-michigan-are-blaming-goats-for-taking-away-landscaping-jobs)

**Why it survives both filters.** Nobody suffers. The aggrieved party is a procedure. The goats are fine. And the recurrence — this happened twice, nine years apart, in different states — means the goat labor dispute is a *genre*, not an incident. That's the world being stupid on a schedule.

**The transformation.** Yuri contracts goats to clear the scrap lot. They are cheaper. They are also goats. The grievance is filed against the goats. The goats are not served, because goats cannot be served.

**The material.**

```
EVENT: six goats arrive at the scrap lot. they have a contract.
they eat the weeds. they eat the weeds along the fence. they eat the fence.
gary files a grievance against the goats.
the goats are not served. goats cannot be served.
EFFECTS: {}
```

Dialogue:

```
SPEAKER: GRIEVANCE GARY
TEXT: local one. membership: one.
      they brought in goats.
      i had to clean up after the goats.
OPTIONS:
  1. ask what the grievance says ($0) → "it says goats."
  2. offer to clean up after the goats ($0, +$5)
  3. tell him the goats did it faster (-3 cred, he agrees, that is worse)
  4. leave
```

Toast: `+ $5 (goat-adjacent labor)`

The line to protect: **the goats were cheaper. then someone had to follow the goats.**

**Pattern.** Bad Trade. The transaction is a win on the invoice and a loss on the ground — the savings are real and a man is now behind a goat with a bag. Note it is *not* Inverted Authority: the goats hold no power and want none. They are eating. Authority is what fell over on contact with them.

**Registry row (VIBE §Named NPCs — required by the rule Finding 1 says stopped running):**

| Name | Tic | Relationship | Transaction/Threat |
|------|-----|--------------|--------------------|
| GRIEVANCE GARY | says "local one" and then "membership: one" without pausing | files against the scrap lot's subcontracted goats | pays $5 to be helped clean up after the goats; will not be consoled |

**Verdict: SHIP.** Best-sourced candidate here and the only one with two independent instances nine years apart.

---

# CANDIDATE 2 — THE PAPERWORK WAS IN ORDER

**The real seed.** In 1938 a small-town mayor entered a mule as a candidate for a local party precinct office. He took the animal to the courthouse and put its hoofprint on the registration documents, where it recorded as a smeared mark. It ran unopposed, made no campaign and offered no platform, and was elected by 51 votes. The mayor said afterwards he'd done it to show people vote without knowing who they're voting for.
Sources: [Museum of Hoaxes](https://hoaxes.org/archive/permalink/the_milton_mule) · [Wikipedia — the mayor who filed it](https://en.wikipedia.org/wiki/Kenneth_Simmons) · [TIME, 1938 archive](https://content.time.com/time/subscriber/article/0,33009,788780,00.html)

**Correcting my own premise:** I went in believing this was 1936 — the Wikipedia officeholder table carries no date and I'd half-remembered one. Three sources say the election was 13 September 1938. The 1936 date in my search query was wrong and I'm flagging it rather than quietly shipping the right number as if I'd always had it.

**The transformation.** The block holds an election nobody announced. One name is on the ballot. The filing is clean. The filing is a hoofprint.

**The material.**

```
EVENT: there is an election. nobody announced it.
there is one name on the ballot. it is a mule.
the mule filed correctly. the hoofprint smeared but it took.
the mule wins by 51. the block has 40 people.
EFFECTS: {}
```

Dialogue — reuses `MAYOR'S COUSIN`, already registered:

```
SPEAKER: MAYOR'S COUSIN
TEXT: i lost to a mule.
      the mule's paperwork was clean.
      mine was also clean. that is not the issue.
OPTIONS:
  1. ask what the issue is ($0) → "the mule."
  2. ask for a recount ($0) → "there were 51. we have 40. it holds."
  3. vote for the mule in front of him (-2 cred with the cousin, +0 everywhere else)
  4. leave
```

**Pattern.** Inverted Authority. An animal holds an office over the player and holds it *legitimately* — that's the escalation. It didn't cheat. It filed.

**Careful note.** The real mayor did this to make a point about voters. **Do not import the point.** VIBE lean-away: *"Rick and Morty — there is no smart undercurrent."* The mule is not a thesis about democracy. The mule is a mule that filed correctly and won. If a line in this ever gestures at what it *means*, cut the line.

**Registry row:**

| Name | Tic | Relationship | Transaction/Threat |
|------|-----|--------------|--------------------|
| THE INCUMBENT | a mule; has not attended | won the block's unannounced election unopposed, 51 votes to 40 residents | holds an office over you; offers nothing; cannot be petitioned or removed |

**Verdict: SHIP**, with the thesis surgically removed.

---

# CANDIDATE 3 — MAYOR OF THE ALLEY

**The real seed.** In September 2025 an informal election named a cat mayor — not of the city, but of a community bike path within it. The jurisdiction is the path.
Sources: [Wikipedia — list of animals in political office](https://en.wikipedia.org/wiki/List_of_animals_in_political_office) · [NBC Boston, 2025-09-16](https://www.nbcboston.com/news/local/somerville-cat-mayor-elected/3809629/)

**Why this one matters more than it looks.** VIBE: *"We don't satirize America. We satirize one block."* This is a real municipality voluntarily shrinking its own aperture to a footpath. The seed is already at Rock Bottom's scale — it needs almost no transformation, which is the tell that it's the right seed.

**The transformation.** A cat is mayor of the alley. Not the block. The alley. The jurisdiction ends at the dumpster and the cat knows exactly where that is.

**The material.**

```
EVENT: a cat sits at the mouth of the alley.
a laminated card is taped to the dumpster. it says MAYOR.
the cat is mayor of the alley. not the block. the alley.
you are in the alley.
EFFECTS: {}
```

Dialogue:

```
SPEAKER: THE MAYOR OF THE ALLEY
TEXT: the mayor does not acknowledge the meeting.
OPTIONS:
  1. petition the mayor ($0) → the mayor relocates four feet. the meeting is over.
  2. pet the mayor ($0) → permitted once. not twice.
  3. leave the alley and re-enter as a constituent ($0) → the mayor is asleep now. you are still a constituent.
  4. leave
```

**Pattern.** Inverted Authority. The fourth beat — `you are in the alley` — is the whole joke: the power is real precisely *because* it is tiny and you are standing inside it.

**Registry row:**

| Name | Tic | Relationship | Transaction/Threat |
|------|-----|--------------|--------------------|
| THE MAYOR OF THE ALLEY | a cat; laminated card taped to the dumpster; relocates four feet instead of ruling | jurisdiction is the alley and ends at the dumpster | permits one pet; grants nothing; you are in the alley |

**Verdict: SHIP.** Cheapest transformation-to-payoff ratio on the list.

---

# CANDIDATE 4 — THE CEILING RACCOON

**The real seed.** A fifty-pound raccoon came through the ceiling of a county courthouse annex. Staff got it out a door. The next morning the ceiling damage was worse despite the doors having been shut — and the report couldn't establish whether it was the same raccoon or a different one that had got back in. Evening meetings at the annex were cancelled until further notice.
Source: [Panola Watchman](https://www.panolawatchman.com/news/pound-raccoon-wreaks-havoc-at-panola-county-courthouse-annex/article_83bffb5a-049a-11e9-bfb3-efee6ea712d3.html)

**The transformation.** The condemned tax office already exists in this world. A raccoon comes through its ceiling. It is removed. The ceiling gets worse anyway. Evening filing is cancelled permanently and nobody establishes which raccoon did it.

**The material.**

```
EVENT: a raccoon comes through the ceiling of the tax office. it weighs fifty pounds.
someone opens a door. it leaves.
in the morning the ceiling is worse. the doors were shut.
evening filing is cancelled until further notice. it is not established which raccoon.
EFFECTS: {}
```

**Pattern.** Possum Pattern — specific creature, specific consequence, then it leaves. Deliberately a **raccoon and not a possum**: THE POSSUM is a registered character with a helmet and a route, and reusing him here would collapse a rotation slot into an existing bit. Different animal, same pattern, no cannibalisation.

**Honest classification note.** This one sits on the Possum/Clerical border — `evening filing is cancelled until further notice` is a procedure absorbing an absurd condition, which is textbook Clerical. I'm scoring it Possum because the creature is the subject and the payload is its *departure and ambiguity*, not the form. But if the operator reads it as Clerical, my tally below goes to 3/9 clerical and **exceeds the V20 2/10 cap** — in which case cut this one, not one of the other two. Flagging rather than letting a favourable reading pass unchallenged.

**Verdict: SHIP**, conditional on the pattern call above going my way. Cut it if it doesn't.

---

# CANDIDATE 5 — THE UNAUTHORIZED REPAIR

**The real seed.** A man began filling his city's potholes himself, at roughly $50 a hole out of his own pocket, and asked followers to send him addresses so he could do it free. The city's mayor publicly commended the effort and asked him to stop — writing that it was not up to him or his team to fill the potholes themselves. A teenager in another city did the same thing and the city responded by announcing a multi-million-dollar grant.
Sources: [CBC News](https://www.cbc.ca/news/canada/montreal/montreal-pothole-vigilante-9.7180547) · [MTL Blog](https://www.mtlblog.com/montreal-news-potholes-mayor-marquize) · [ClickOnDetroit, 2026-03-24](https://www.clickondetroit.com/news/local/2026/03/24/teen-was-so-fed-up-with-potholes-in-dearborn-heights-he-repaired-them-himself-how-city-responded/)

**The transformation.** `A POTHOLE (TALKING)` is already registered — it knows your full legal name and your mother's voice, and it wins arguments for -4 brain. So: you fill it. It stops talking. Then you are commended and asked to stop.

**The material.**

```
EVENT: you fill the pothole. it costs $5 and it takes a while.
the pothole stops talking.
a letter arrives. it commends you. it asks you to stop.
the letter is from the pothole's department.
EFFECTS: {cash: -5, item: 'a letter (commendation)'}
```

**Side quest — THE UNAUTHORIZED REPAIR.** Fill three potholes, $5 each. On the third:

```
the department commends you.
the department asks you to stop.
the department does not fill the potholes.
```

Reward: `+ a letter (commendation)`. The letter is an item. It has no value. Pawn Shop Pete will take it.

```
pete weighs the letter. eleven minutes.
pete offers $0.
pete is not being difficult. that is what it weighs.
```

**Pattern.** Clerical (1 of 2). The department absorbs a good deed into a procedure and the procedure becomes the permanent thing, not the repair.

**Why this is the north star and not a violation of it.** `recognition without reward` — this is that sentence as a mechanic. You are literally recognised, on paper, by name, and the recognition weighs nothing and Pete will tell you so in eleven minutes. The ladder is not upward. You paid $15 and received an acknowledgment. **This may be the single most on-brief item in the document** and it came from a mayor being polite.

**Verdict: SHIP.**

---

# CANDIDATE 6 — THE CORRECTION WINDOW

**The real seed.** A man who had been declared legally dead in absentia years earlier returned to his country and petitioned a court to be declared alive. The court rejected the petition — the appeal had been filed too late — while he was standing in the courtroom. (A second attempt months later succeeded.) In a separate US case, a man declared dead in absentia was told his state's law barred reversing a death declaration after three years, so he remained legally dead.
Sources: [NPR, 2018-03-16](https://www.npr.org/sections/thetwo-way/2018/03/16/594431754/man-claims-hes-not-dead-court-doesn-t-buy-it) · [Forbes, 2013-10-12](https://www.forbes.com/sites/kellyphillipserb/2013/10/12/judge-orders-man-to-stay-dead-despite-his-insistence-hes-alive-could-you-be-next/) · [Wikipedia — legal death](https://en.wikipedia.org/wiki/Legal_death)

**On the ethical line.** Deliberate call: I am mining the *filing deadline*, not the death. Nobody died in either case — that's the entire point of both stories. The absurdity is a clerk's calendar outranking a man standing in the room. No suffering is load-bearing.

**The transformation.** The tax office has you listed as gone. You are standing in the tax office. Being present is not the kind of evidence the window takes.

**The material.**

```
EVENT: the tax office has you listed as gone.
you are standing in the tax office.
the window says the correction window closed. it closed while you were gone.
you are still standing there. that is not the kind of evidence the window takes.
EFFECTS: {}
```

```
SPEAKER: THE LEASING GUY
TEXT: you are not on the list.
      i cannot put you on the list. that is a different clipboard.
      i can tell you that you are not on it. that is this clipboard.
OPTIONS:
  1. ask which clipboard ($0) → "the one that closed."
  2. ask when it closed ($0) → "while you were gone."
  3. explain that you are standing here ($0) → he writes nothing down. it is not that kind of window.
  4. leave
```

**Pattern.** Clerical (2 of 2). Cap reached. Everything else rotates.

**Verdict: SHIP** — and this seed is also the engine of Rock A below, which is the real find.

---

# CANDIDATE 7 — THE CENTER OF THE BLOCK

**The real seed.** An IP-geolocation company needed a default location for addresses it could only place as "somewhere in the US," so it picked coordinates at the geographic centre of the country. Those coordinates landed on a farm. For over a decade, ~600 million IP addresses resolved to that one house, and law enforcement, tax agencies, scam victims and angry strangers turned up at the door for things that had nothing to do with the residents. After litigation the company moved the default to the middle of a lake. Visits still happen occasionally, because not every database updates.
Sources: [The Week](https://theweek.com/articles/624040/how-internet-mapping-glitch-turned-kansas-farm-into-digital-hell) · [Wikipedia — MaxMind](https://en.wikipedia.org/wiki/MaxMind)

**On the ethical line.** The residents in the real story had a genuinely bad decade. I'm mining the *mechanism* — a rounding default becoming an accusation — and pointing it at the player, who is a clown and can take it. The seed's victims are not the joke and do not appear.

**The transformation.** Something has to be the middle of the block. You are standing closest to it.

**The material.**

```
EVENT: something has to be the middle of the block.
you are standing closest to it.
for the rest of the day everything with no known author is yours.
they fixed it. they pointed it at the fountain. some lists did not get the update.
EFFECTS: {}
```

Cursed aside variant, for the incidental loop:

```
EVENT: a man you have never met apologizes to you for something you did not do.
you accept the apology.
he seems relieved. he had the wrong guy and the right block.
EFFECTS: {}
```

**Pattern.** Cursed Aside — the narrator briefly hallucinates something true about the player. The truth: the world has already decided where you are and did not ask. `they pointed it at the fountain` is the flat landing, and it honours the existing fountain lore rather than inventing furniture.

**Verdict: SHIP.** Thinnest-populated pattern in the doc; this carries it alone, which is a fragility worth naming (see §TALLY).

---

# SPECIAL ROCKS — the operator's ask, and the trap in it

## OD-6 (proposed) — the north-star tension is real and it is the operator's call

**The ask:** side quests yielding a special rock granting a ~60-second power (e.g. beat up cops without arrest).

**The conflict, stated without softening:** `SPEC-V20-PACKET` §NORTH STAR is ratified — *"recognition without reward. the ladder is not upward."* §1 THE REGULAR is explicit that tier effects are *"acknowledgment only — never stats, cash, discounts, damage, or timers."* A rock that grants 60 seconds of combat immunity is a stat, a timer, and a reward. **As stated, the ask contradicts the ratified north star.** That's not my opinion about what's funny; it's two documents disagreeing, and per VIBE's header the document wins until the operator changes the document.

**What I am not doing:** pretending the tension away, and equally, refusing to build it. Below are three candidates built as genuine Bad Trades. If any reads as pure upside, I've failed the brief.

**The distinction I'd offer, for whatever it's worth:** §1's "acknowledgment only" governs **THE REGULAR's recognition tiers** — the counters. A side-quest item is a different surface and is not literally bound by that clause. But the north star sentence is broader than §1 and a power-up does move the ladder upward. **The honest read is that Rock A survives the north star and Rocks B and C bend it.** Reasoning below; the call isn't mine.

---

## ROCK A — THE GONE ROCK ⭐ (recommended)

**Seed:** Candidate 6 — the man the court would not declare alive because the correction window had closed.

**The side quest.** File to be alive at the condemned tax office. `THE LEASING GUY` runs the window. The window closed while you were gone. You were not gone. The filing fails. You are now, on paper, gone.

**The power.** For 60 seconds, a cop who reaches you radios you in. The radio says you are not a person. The cop leaves. You may do whatever you like in those 60 seconds and there is no arrest, because arrest is a procedure and procedures need a subject.

**The curse — and this is the whole design.** It is **the same list**. Tony reads the list. You are not on it. For the rest of the day Tony will not serve you — not out of anger, he simply cannot find you — and no NPC uses your name.

**Why this is the strongest candidate by a distance:** the power and the curse are *not two things balanced against each other*. They are **one fact seen from two sides.** You are not on the list. That is why the cops cannot take you and why Tony cannot serve you. Nothing is bolted on. There is no arbitrary penalty tuned to "feel fair" — the cost is the *logical consequence of the benefit*, which is what `for every good thing, an equal and opposite` actually asks for when read strictly.

It also lands the north star instead of fighting it. `recognition without reward` — you bought 60 seconds of untouchability with your recognition itself, and the neighborhood adjusts around you by not seeing you. The ladder is not upward. It's sideways and you end where you started, minus your name.

**The material.**

```
+ the gone rock
you are not on the list.
```

```
a cop reaches you. he radios it in.
the radio says you are not a person.
he stands there for a moment. then he goes back to his car.
```

```
tony looks at the list. tony looks at you. tony looks at the list.
"i don't have you."
he is not being difficult. he does not have you.
```

Barb does the crossword and does not read lists. **Barb still sells.** The out exists, it costs you the good supply, and it is not explained.

**Pattern.** Bad Trade, cleanly. **Verdict: SHIP.** This is the one.

---

## ROCK B — THE DEPOSIT ROCK

**Seed:** Municipalities sell derelict houses for €1, but the buyer posts a deposit (commonly €1,000–€10,000, sometimes more) and must complete a renovation inside ~3 years or forfeit the deposit and possibly the property. Permits routinely take 6+ months while the 3-year clock runs from purchase. Real all-in costs run to tens or hundreds of thousands.
Sources: [Impatria — 1 Euro Houses in Italy, 2026 guide](https://impatria.com/en/magazine/1-euro-houses-italy-foreigners/) · [European.realestate — real cost, 2026](https://european.realestate/the-real-cost-of-italys-1-euro-homes-in-2026/)

**The side quest.** `THE LEASING GUY` sells you a rock for $1. The rock is real. The rock is the best rock on the block. The deposit is $40 and one pure copper.

**The power.** 60 seconds. Everything works.

**The curse.** The deposit is returned when you return the rock in the condition you received it. You smoked it. That was the rock's purpose. The deposit is therefore never returned — not as a punishment, as a definition. And the leasing guy asks about it. Every time you pass. In front of whoever is standing there. He is not angry. He just asks. **It never escalates.** That is the joke: the flatness is permanent.

**The material.**

```
- $40 · - 1 pure copper (deposit)
+ the deposit rock ($1)
```

```
the leasing guy asks about the rock.
someone is standing there. he asks anyway.
he is not angry. he would like to close the file.
```

**Weight check.** $40 + one pure copper ≈ $70 by the Conductor's own rate (3 pure copper for $90). That is real money in this economy, plus a permanent small public toll. Against 60 seconds. **Honest assessment: this is close to equal but not clearly equal**, and it's the weakest of the three on that axis. The permanence is doing the work the number can't.

**Pattern.** Bad Trade. **Verdict: NEEDS WORK** — specifically, the deposit needs a pass at implementation to confirm it bites. Shipping it un-tuned would make it a $70 power-up, which is the failure mode the brief warns about.

---

## ROCK C — THE LIFETIME SUPPLY

**Seed.** People who won "lifetime supply" prizes report the reality: one lifetime supply of a lubricant spray arrived as four cans; a year's supply of fries arrived as 52 coupons each good for one small fries; one family's lifetime supply arrived all at once as two pallets about five feet high.
Sources: [Upworthy](https://www.upworthy.com/lifetime-supply-prize-truths-revealed/) · [BuzzFeed](https://www.buzzfeed.com/hannahmarder/lifetime-supply-winners-reveal-all)

**⚠️ SOURCING FLAG — read this before using it.** These are **aggregated crowd-sourced anecdotes** (Reddit/BuzzFeed roundups), not reported journalism. Every other seed in this document traces to a named outlet reporting a specific verified event. **This one does not, and I am not going to let it sit in the list pretending otherwise.** The *pattern* (companies cap "lifetime" at a calculated multiple and fulfil it in one delivery) is corroborated across many independent tellings and is legally routine, so the underlying mechanic is real. But "four cans" is an anecdote I cannot verify. If the operator's fabricated-specifics rule is applied strictly here — and it should be — **the number four is not a fact I can stand behind.** Use the mechanic, don't cite the number as real.

**The side quest.** You win a lifetime supply of rocks. It arrives at once. It is four.

**The power.** Each of the four grants 60 seconds. The lifetime is yours to allocate.

**The curse.** Tony's ledger marks you `SUPPLIED`. He will not sell to you again. You have a lifetime supply. It is four.

**The out, and why it's the best part.** `STRIPE` still sells. Stripe is the rival dealer at the projects — $8 rocks, **40% are soap**, already registered. So the curse doesn't wall you off; it *routes you to the soap dealer.* You traded the good dealer for the bad one and you did it by winning.

**The material.**

```
+ 4 rocks (lifetime supply)
tony marks you supplied.
```

```
you have a lifetime supply. it is four.
the lifetime is yours to allocate.
```

```
tony does not look up. "you're supplied."
you explain that you are not supplied.
"you're supplied." he taps the ledger. the ledger says supplied.
```

**Balance concern, flagged not buried.** 4×60s of power against permanently losing the primary dealer is the heaviest curse here and possibly *over*weighted — it may be strictly bad, which is a different failure than pure upside but still a failure. The Stripe routing is what makes it survivable. Needs a play-test, not a spec argument.

**Pattern.** Bad Trade. **Verdict: NEEDS WORK** — good bones, unverifiable specific, unproven balance.

---

# PATTERN TALLY

The drift audit's Finding 2 named the mechanism precisely: the Clerical Pattern is the only **generative** one — you can produce a passing clerical beat for any object in about nine seconds, while a Possum or Cursed Aside beat requires an idea. So under any instruction to *produce more*, clerical wins by default. **A research brief is exactly such an instruction**, and roughly two-thirds of what surfaced when I searched "absurd news" was bureaucratic. Rotating away from it was an active cost, not a preference.

| Pattern | Count | Share | Items |
|---|---|---|---|
| Bad Trade | 3 | 33% | 1 goats · B deposit rock · C lifetime supply |
| Inverted Authority | 2 | 22% | 2 mule · 3 alley mayor |
| **Clerical** | **2** | **22%** | 5 pothole · 6 correction window |
| Possum | 1 | 11% | 4 raccoon |
| Cursed Aside | 1 | 11% | 7 center of the block |
| **Total scored** | **9** | | Rock A shares seed 6; counted once, under 6 |

**Clerical: 2 of 9 (22%).** Against the V20 draft's 2/10 cap and VIBE's ≤50% rotation rule. **Compliant — but only because I refused three more clerical seeds that were sitting right there** (see §CUTS 3). This did not happen naturally.

**No pattern exceeds half.** Bad Trade at 33% is the plurality and that is a deliberate consequence of the special-rock brief, which is a Bad Trade brief by construction — all three rocks must be Bad Trades or they fail. Excluding the rocks, the world candidates run 1 Bad Trade / 2 Inverted Authority / 2 Clerical / 1 Possum / 1 Cursed Aside — an even spread with no plurality at all.

**The fragility worth naming:** Possum and Cursed Aside are carried by **one candidate each.** If Candidate 4's pattern call goes Clerical (§4's honest note), the tally becomes 3/9 clerical = 33%, **Possum drops to zero, and clerical exceeds the V20 cap.** One judgment call is load-bearing for two of the five patterns. That's thin, and I'd rather say so than present 22% as a comfortable margin. It isn't.

---

# CUTS — what I dropped, and why

The brief asked me to be willing to cut my own material. Four:

### 1. The cat stationmaster — CUT (duplicate joke)
A cat was appointed stationmaster of a rural Japanese railway station in 2007, credited with saving the line, and was later **promoted to "Operating Officer."** A third cat took the post in 2026.
Sources: [Wikipedia](https://en.wikipedia.org/wiki/Tama_(cat)) · [Tokyo Weekender](https://www.tokyoweekender.com/japan-life/news-and-opinion/new-cat-stationmaster-announced/)

I liked this one a lot and it's well-sourced. **Cutting it anyway:** `SPEC-V20-PACKET` §4 item 4 already ships *"the possum in the construction helmet has been promoted. nothing else changed. the helmet is the same helmet."* An animal-promoted-to-a-real-job-title beat **is that joke**, and adding it would be a second telling in the same wave. The drift audit's whole Finding 2 is about one construction quietly eating the rotation. This is how that happens — a good seed, locally justified, that duplicates an existing beat. Cut.

### 2. Prize/contest absurdity beyond the lifetime-supply vein — NOT FOUND
Searched for a documented case of a contest winner whose prize was technically delivered and worthless. **Returned nothing citable** — only scam warnings and legal explainers. I could have written a plausible one. I didn't. Reporting the empty result instead.

### 3. Three further clerical seeds — CUT ON ROTATION, NOT QUALITY
Deliberately not developed, purely to hold the cap: rat/bedbug courthouse closures; municipal permit-window paradoxes beyond Candidate 6; the €1-house permit clock as its own separate beat (folded into Rock B rather than run as a standalone). Any of these would have passed on quality. **They were cut because clerical was full.** Naming them so the operator can see the cap cost something real, and so a future wave doesn't rediscover them and assume they were missed.

### 4. The entire shopping-cart vein — CUT ON THE ETHICAL LINE
The operator's brief explicitly listed *"things people did with a shopping cart"* as a mine-able category. I searched it. **Every substantive result routed through unhoused people using carts to transport their belongings** — that's the primary documented reason carts leave lots, and it's the spine of the reporting. The remaining material was cart-theft arrests. Both fail the filter: one is homelessness-as-punchline, the other is arrest-as-punchline.

There is a live cart bit in the game already (`THE BIG GUY` trades his misaligned cart for 5 pure copper) and it works because it's about a man's relationship with a *bad wheel*, not his circumstances. **I found nothing in the real-news record that clears the line and adds to that.** Reporting the vein as dry rather than forcing it.

---

# WHAT I COULDN'T CONFIRM

Stated plainly, per the standard the prior auditors set:

- **The CBC pothole article returned an empty body** on fetch. The story is corroborated by MTL Blog and a parallel ClickOnDetroit report, and the mayor's "it is not up to you" quote appears in the search index against the CBC URL — but **I did not read that quote in the rendered CBC page myself.** Treated as corroborated-not-verified. The seed doesn't depend on the exact wording.
- **The alley-mayor seed (Candidate 3)** is sourced to a Wikipedia table row and its cited NBC Boston link. **I did not open the NBC article.** The Wikipedia entry is specific and dated; I rate this solid but one tier below Candidates 1, 2, 4 and 6, where I read the reporting.
- **"Four cans" (Rock C)** is unverifiable. Flagged in place, above, at length.
- **The 1938 mule date** — I corrected my own wrong assumption mid-research (§Candidate 2). Three sources agree on 1938. My query said 1936. Recording the error.
- **No claim in this document rests on a number I invented.** Where a specific couldn't be traced (Rock C), it is marked as untraceable rather than dressed up. Where I was wrong (the mule year), it's on the record.

---

# RECOMMENDED ORDER

1. **Rock A — THE GONE ROCK.** The find. Power and curse are one fact. Answers the operator's ask without breaking the north star, and it came out of a court case, not a whiteboard.
2. **Candidate 5 — THE UNAUTHORIZED REPAIR.** `recognition without reward` rendered as a letter that weighs nothing. Pete's eleven minutes are already built.
3. **Candidate 1 — THE GOATS.** Best-sourced. Two instances, nine years apart.
4. **Candidate 3 — MAYOR OF THE ALLEY.** Near-zero transformation cost.
5. **Candidates 2, 4, 6, 7.** Solid; 4 is conditional on its pattern call.
6. **Rocks B and C.** Needs-work, both flagged, neither ready.

**OD-6 stands unresolved and is the operator's call:** the ratified north star and the special-rock ask disagree. Rock A is my argument that they don't *have* to — but that's an argument, not a ruling, and the document wins until he moves it.

---

*Research + findings only. `RESEARCH-ABSURDITY.md` is the only file written. No game file, `VIBE.md`, `SPEC.md`, or SPEC packet was modified. No NPC was shipped — the registry rows above are proposals, pending the operator's call on Finding 1's unresolved enforcement question.*
