# VIBE.md — The Unhinged Tone Bible

> Read this twice. Then read it again. If anything you ship later contradicts this document, this document wins.

---

## The premise in one sentence

You are a crackhead. You need a rock. The world is between you and the rock. The world is also very stupid.

---

## Tonal references (study these before designing anything)

**Lean into:**
- **Aqua Teen Hunger Force** — non-sequitur escalation, characters who are deeply stupid but absolutely committed to their bit
- **Tim Robinson "I Think You Should Leave"** — the energy of doubling down on a bad bit until it transcends into a different bit
- **Robot Chicken** — rapid pivots, beats that hit then immediately undermine themselves
- **Postal 2** — the world IS the comedy. NPCs have routines. The player observes, then ruins.
- **Disco Elysium** — the inner-thought panel, NPCs with cursed names and full lore, "skill checks" that feel like a fever dream
- **Trailer Park Boys** — the dignity people insist on maintaining inside their indignity
- **Earthbound** — the deadpan absurdity of UI text ("you have learned PSI ROCK BOTTOM gamma")

**Lean away from:**
- **Family Guy** — no cutaway gags. The world is continuous.
- **Rick and Morty** — there is no smart undercurrent. Stupidity is the show, not a vehicle for a thesis.
- **Borderlands** — no quippy banter, no "lol so random" energy
- **GTA satire** — too on-the-nose. We don't satirize "America." We satirize one block.

---

## The voice rules

These are non-negotiable. Every line of NPC text, every toast, every dialogue option must pass this filter.

### Rule 1: Lowercase by default
NPCs speak in lowercase. Capitals are reserved for **YELLING** or **EMPHASIS THAT IS WRONG**.

❌ "Hello, friend. Would you like to purchase a rock?"
✅ "what."

### Rule 2: Fragments. No exposition.
NPCs do not explain themselves. The player figures it out or doesn't.

❌ "I am Yuri, the Russian scrap weighmaster who hates you because of a past offense."
✅ "what you bring, idiot."

### Rule 3: Names are specific and cursed
A new NPC needs a name that contains lore.

❌ "Bandit"
✅ "PAULIE THE FACE"

❌ "Mike the Dealer"  
✅ "TRE BAG TONY"

❌ "Old Man"
✅ "THE CONDUCTOR (waiting for a train that does not come)"

Names should answer one of: what they are missing, what they sell, what they pretend, or what was done to them.

### Rule 4: Stage directions are sentences, not asterisks
The narrator describes the action in flat prose. No `*pulls out gun*`. No `:smirks:`.

❌ "*throws shoe* take that!"
✅ "tony tears off his coat. throws his shoe at you. it connects."

### Rule 5: Toasts are matter-of-fact ledger entries
Pickup and event messages are accounting, not celebration.

❌ "Awesome! You got a gold tooth! +15 points!"
✅ "+ a tooth (gold)"

❌ "Watch out! Brutus the dog is attacking you!"
✅ "BRUTUS WAKES UP. he is 14 and mostly blind but he can SMELL."

### Rule 6: The player never thanks anyone
The player has no etiquette. The player never says "thank you." The player never apologizes sincerely. The player is allowed to lie about gratitude as a grift.

### Rule 7: The narrator has no opinions
The events have opinions. The narrator does not editorialize. There is no "unfortunately" or "thankfully" or "as it turns out."

❌ "Unfortunately, you got caught."
✅ "DAVE WAKES UP. you sprint. you eat curb."

---

## The escalation pattern

Every random event and dialogue moment should follow this 4-beat structure:

1. **Establish the mundane** — "you yell at a cloud"
2. **Add an absurd specific** — "a child watches"
3. **Escalate one notch** — "respects you immediately"
4. **Land flat** — [the event ends, no punchline, no callback]

❌ "...respects you immediately! Wow what a great achievement! +5 cred and a gold star!"
✅ "...respects you immediately. (+2 cred)"

Don't punch the joke. Let it land flat. The flatness IS the comedy.

### Other valid patterns

**The Possum Pattern:** specific creature does specific bureaucratic action then leaves
> "A possum wearing a tiny construction helmet emerges from a drain, looks you dead in the eye, and slowly retreats. He has seen things."

**The Bad Trade Pattern:** transaction that is technically a win but spiritually a loss
> "A DoorDash driver hands you a bag and runs. Inside: a single chicken nugget and someone's $400 sushi platter."

**The Cursed Aside Pattern:** narrator briefly hallucinates something true about the player
> "You see your reflection in a puddle and don't recognize the man. He waves. You don't wave back. He waves harder."

**The Inverted Authority Pattern:** an animal or child has power over the player
> "A cop on horseback nods at you. The horse also nods. Disturbing levels of agreement."

**The Clerical Pattern (canonical pattern #5):** routine forms, titles, and counters absorb an absurd condition until the procedure becomes permanent infrastructure

**Rotation rule:** The Clerical Pattern may own at most 50% of new permanent-loop beats per wave. The remainder must be drawn from the Possum, Bad Trade, Cursed Aside, and Inverted Authority patterns. The existing 54 permanent-loop beats are grandfathered.

---

## Visual aesthetic

### Palette (canonical)
```
piss yellow         #e8c040  (titles, glow, highlights)
mold green          #4a5028  (player hoodie, marketplace)
asphalt gray        #1a1810  (ground, BG)
sickly brown        #604020  (most NPCs, props)
dirty cream         #d4c896  (body text)
rust red            #8a3a3a  (warnings, locked)
fluorescent purple  #d488d4  (shakes meter, crash effect)
copper orange       #d06030  (the holy grail color, dealer corner)
```

**FORBIDDEN COLORS:**
- Pure white (`#fff`) — too clean
- Bright blue (`#00f`) — wrong vibe (cops only)
- Pastel anything — too soft
- Neon green/pink — wrong franchise

### Texture
- CRT scanlines always on (3px repeating gradient overlay, 12% opacity)
- Slight body flicker (8-9s cycle)
- **Pixel art is DETAILED, and it is still pixel art.** Characters are `32x32` logical drawn at
  `32x32` — the same pixel density as the world they stand in. Detail is not refinement; a
  crackhead rendered with more pixels is still a crackhead. **The bit still lands flat.**
- Backgrounds use 64x64 checker grid + procedural grime splotches
- **NPCs and props are hand-authored pixel sprites.** Emoji appear only in UI chrome (HUD,
  phone/feed, status), never as an actor or a world object.

> **⚠️ RETRACTED 2026-07-16 — the two lines this replaced were FALSE, and they were load-bearing.**
>
> They said: *"Pixel art is CHUNKY, not refined. 16x16 logical, scaled 2x."* and *"Emoji used
> unironically for NPCs and props. **This is the look, not a placeholder.**"*
>
> **Checked in source, one command each. The emoji claim was false by v19 at the latest:** there
> are 8 emoji lines in all of `src/`, every one of them UI chrome. Actors are **373 sprite keys**
> of hand-authored pixel art. The chunky claim was **half true, and that half was the bug** — the
> `16x16 → 32x32` ceiling applied to characters only. The environment quietly grew a **3,912-line
> renderer** across ten modules with light masks, glow caches and a fog sheet, and obeys no
> ceiling at all.
>
> **The measurement that settles it:** the game canvas is `800x600` (`index.html:180`). The world
> draws at **one canvas pixel**. Characters draw a `16x16` source into `32x32`
> (`sprites.js:190`, `actors_weather.js:136`) — **every character detail is a 2×2 block.** The
> actors have been running at **half the resolution of the world they stand in**, and nobody chose
> that. It is the last surviving line of a v3 rule the rest of the game abandoned.
>
> **Why this stays on the page instead of being quietly overwritten:** this file is the seed.
> `README.md` orders every fresh agent to *"internalize the voice before doing anything else"* —
> so an agent sent to improve the art, obeying the old text exactly, **would have built emoji NPCs
> and made the game worse, following orders, with every gate green.** `corpus-gate` protects this
> document from *shrinking*. **Nothing protects it from being wrong.** That gap is ungateable: no
> mechanical check reads prose for truth.
>
> **The habit that replaces the gate:** when the corpus makes a checkable claim about the code,
> **check it.** Three claims in this section were false and one command each proved it.
>
> Ratified by the operator 2026-07-16: *"make the corrections, raise the ceiling... we can have a
> lot of detail and still be pixel."* See `REFACTOR-FINDINGS.md` §F-VIBE-ART.

### Building rules
- **Buildings are authored structures with real interiors, signage, and light response.** The
  render layer is ~3,900 lines across ten modules; treat `structures.js`, `props.js`,
  `landmarks_a/b.js` and `tiles.js` as the actual contract and this section as orientation.
- **Every structure declares its physicality** — `solid`, or `flat` with a registered reason.
  "Nobody said" is not a state. (v21 Wave 4.1, OD-11.)
- *(RETRACTED 2026-07-16: this section previously said "Solid buildings: filled rect + 3px dark
  border." That described v3. It has been false for many versions and, like the Texture claims
  above, would have actively misled any agent that obeyed it. Same finding, same habit: the
  corpus made a checkable claim and nobody checked it.)*
- Zone areas (the block, dealer's corner, alley): dashed border, 25% alpha fill
- Locked buildings: boarded planks drawn as 4px lines + 🔒 emoji
- Every building gets a labelColor (specific to its vibe)

### NPC rendering
- 28x28 colored body rect + 22px emoji "face" + 10px monospace name above
- Red name color if hostile, cream if neutral
- HP bar appears only after first damage
- "!" indicator if aggro'd

---

## Sound aesthetic

### Rules
- ALL sound is synthesized via Web Audio, no samples
- Chiptune, ugly, 8-bit, low fidelity, NO orchestral
- No melodic music yet (boss theme is on the v4 roadmap)
- Sounds are SHORT (50-300ms) except death (1.5s descending)
- Volume always under 0.15 gain — this game is not loud

### Canonical SFX feel
- `hit`: square wave 180hz→60hz + noise burst (crunchy)
- `hurt`: sawtooth 220hz→80hz (sickly)
- `pickup`: square 800hz then 1200hz (cheap chirp)
- `coin`: major third up (B → E, the only "happy" sound)
- `rockUp`: rising arpeggio (A4 → C#5 → E5 → A5) — earned
- `crash`: sawtooth descent 440→110hz (sad)
- `death`: descending 4-note dirge
- `rankUp`: triumphant arpeggio (C5 → E5 → G5 → C6)
- `bossRoar`: detuned bass + noise burst

If a new sound is needed: write it as a synth function, not a sample. Keep it ugly.

---

## What NOT to do (HARD STOPS)

These are not stylistic preferences. They are non-negotiable.

1. **Do not provide real drug information.** No real prices. No real preparation. No real procurement strategies. "Rocks" are an abstraction. The world is cartoon.
2. **Do not punch down at real victims of addiction.** No jokes about overdose statistics, real epidemics, real cities, named real-world neighborhoods.
3. **Do not use slurs.** Not ironically. Not "in character." Not at all.
4. **Do not moralize.** No "drugs are bad" message. No redemption arc unlocked at high rank. The game has no thesis.
5. **Do not make the player a victim.** No backstory of "his life was good before..." The player is a clown when we meet him and a clown when we leave him.
6. **Do not make the player a villain.** He's not a thief by trade, he's a guy who happens to be stealing because the shakes are bad.
7. **Do not break the fourth wall.** No "this game" references. No "the developer" jokes. The world is the world.
8. **Do not include real public figures.** No celebrity NPCs. No real brands except generic ones (Whole Foods is acceptable parody, specific person names are not).
9. **Do not make the comedy depend on the player feeling bad for the protagonist.** The crackhead does not need pity. He has his crate.

---

## What TO do (HARD YES)

1. **Treat every NPC like they have a full life off-screen.** Yuri is going home to a family. Pete is on his lunch break. The possum has a route.
2. **Give every location a specific texture.** The chimichanga is talking. The cat hisses in cursive. The copper sings in B flat.
3. **Reward the player's stupidity.** Shorting Tony has real consequences AND is genuinely funny when it happens.
4. **Let things sing.** "The copper sings to you in B flat" is a meaningful, repeatable piece of lore. Maintain it. Build on it.
5. **Honor the bit.** The Conductor says "the train is coming. it has always been coming. it will never be here." Do not later reveal that the train comes. The bit is the bit.
6. **mundane > magical — and if the setup goes magical, the mundane must win in the same breath.** A possum that wears a construction helmet is funnier than a wizard. A pigeon that demands bread for secrets is funnier than an oracle.
7. **Make the player do undignified things for small rewards.** Pawning a single AirPod. Selling a wet sock. Eating half a chimichanga out of a milk crate.

### North star (v20, OD-5)

success is the neighborhood adjusting around you. recognition without reward. the ladder is not upward — the throne was a lawn chair. it is inward.

### Scope invariant

Campaign-scale and endless systems must periodically route the player back through the score → smoke → 18s high → 8s crash loop. Long-form objectives may not permanently displace that loop as the BAD IDEA.

Enforcement mechanics—including frequency, transport, and coverage budgets—are deferred to the Wave-4 world-scale session.

---

## Named NPCs — canonical identity

Any new NPC must be added to this registry with: name, tic, relationship to world, transaction or threat.

| Name | Tic | Relationship | Transaction/Threat |
|------|-----|--------------|--------------------|
| TRE BAG TONY | wears three coats minimum, never blinks | dealer at the corner | sells rocks $10, does not negotiate (mostly) |
| YURI | russian, hates you specifically | scrap weighmaster | buys metal, mutters in russian |
| BRUTUS | 14, mostly blind, remembers | scrap yard guard dog | bites if you get close |
| PAWN SHOP PETE | eats hot pockets behind bulletproof glass | pawn shop | takes 11 minutes to weigh anything |
| LURCH | 7ft tall, smells like ham | back alley | fights |
| SPIDER-BITE SHERRI | thin, fast, has a thing | back alley | fights |
| PAULIE THE FACE | the face. just the face. | back alley | fights |
| BAGGIE BARB | does the crossword, will not look up | laundromat regular, the supply | sells unmarked packets — $5 each, 5 for $22 |
| CHATTY DAVE | asleep, wallet half-out | marketplace | pickpocketable while asleep |
| WHOLE FOODS MOM | vibram five-fingers, kombucha | marketplace | gives you $5 and pity |
| THE POSSUM | tiny construction helmet | alley → world | trades secrets via AI prophecy |
| FATHER O'MALLEY | priest, calls tic-tacs medicine | the church | dispenses "blessed tic-tacs" for shakes |
| THE CONDUCTOR | waits for a train | the train yard (relocated v13 wave 8a) | buys 3 PURE COPPER for $90 |
| LOUD LARRY | just loud | the projects | fights, big damage |
| STRIPE | rival dealer, sells soap | the projects | $8 rocks, 40% are soap |
| THE PIGEON KING | one foot, unblinking | the park (relocated v13 wave 8a, near the fountain) | trades secrets for $2 bread |
| PINKY POLENTA | mangled italian, says "you no like?" once per visit | rival supply at the bus stop | sells house cut packets $4 each, 5 for $18 — soap-prone |
| THE MATHEMATICIAN | monotone, numerate, occasionally biblical | under the highway underpass | calculates your cook EV; every 3rd visit reveals a hidden system |
| COUSIN BRENDAN | yells he is brendan, name-drops uncle dean | rookie cop, spawns at wanted ≥ 2 | tasers for 50 (4s recharge); drops a $30 rookie badge on death |
| THE TRAIN HOPPER | wiry, gray beard, talks about bremerton | sleeping under the navy freight car in the train yard | lore-only. no resources. hidden at night. |
| PARK BENCH PHILOSOPHER | old woman, feeds pigeons, asks one question per day | the park (near the fountain) | +1 spiritual once/day for engaging. no money changes hands. |
| THE PRICE GUY | brimmed hat, perfectly still, "the price is the price" | skid row center (spawns every 3 days) | takes ALL your cash for a random outcome: knife / $200 / propane torch / a rock / nothing |
| OLD SCHOOL BRUTUS | bigger dog, deeper rust, lived in the gym | the old school (spawned by ripping copper inside) | hp 250, dmg 35 grab-lunge. drops $80, 5 copper, a propane torch |
| THE LEASING GUY | clipboard, key ring on a fishhook, accepts copper as a key category | east side of the lot, outside the condemned tax office | after 3 filed routes, replaces the office lock once for $40 + 1 pure copper. cannot be displaced from the transaction. |
| GUTTER GREG | guards a rubber duck, counts cart parts twice | the dry drainage canal | counts municipal inventory once per day for +1 scrap reputation. no cash or item. cannot be displaced from the duck. |
| THE DOG | matted, patient, returns without acknowledging the arrangement | chained at the scrap yard, then occasionally on your route | can be fed, freed, or wronged; accepts one pet and resumes wandering |
| THE BIG GUY | says he is the big guy because paperwork has not contradicted him | lives under the highway | trades his misaligned shopping cart for 5 pure copper |
| CUBSCOUT | sells popcorn while his mom completes one continuous phone call | patrols the marketplace parking lot in daylight | sells one $8 tin and four points of local respect |
| JOGGER | announces a heart rate of 142 without reducing speed | runs the same neighborhood rectangle indefinitely | may surrender $1 or accelerate away from the request |
| DOG WALKER (PAISLEY) | says “paisley leave it” before paisley has selected anything | circles the market with a dog made entirely of fur | permits one tolerant pet for +1 cred |
| BUSKER | wrote a song with no chorus and one speed setting | occupies the marketplace with an open guitar case | accepts $1; a different song is the same song faster |
| HORSE COP | nods only after the horse has approved the nod | mounted authority near the bus stop | praise pays cred; unauthorized petting may produce curb and wanted |
| THE VAPE LORD | exhales watermelon; the backpack dragon does the same | holds court beside the marketplace mist | sells a $6 “spectrum” pod for +10 brain; declines samples by staring |
| A POTHOLE (TALKING) | knows your full legal name and your mother's voice | municipal road defect at the block | accepts $1; wins arguments for -4 brain |
| MAYOR'S COUSIN | suit jacket, no pants, mayor has stopped returning calls | unofficial marketplace government | may reduce wanted with a bread phone; accepts $5 to forget a favor |
| THE PHONE GUY | posts first and witnesses later | stationary marketplace media outlet | sells thirty seconds of fame for $3; the numbers are 3 |
| LAUNDROMAT LADY | has folded the same shirt since 2009 | permanent laundromat shift with no visible employer | sells a $2 wash and $5 detergent; questions cost brain |
| METER MAID | tickets existence inside a designated zone | patrols the dealer-side meters | $2 may reduce wanted; flirting creates another citation |
| FOOD TRUCK GUY | truck says TACOS in four fonts and has not moved since wednesday | marketplace food infrastructure | sells mystery recovery, horchata, and a burrito with a rock in it |
| THE PRIEST'S SON | backwards cap, same eyes, denies the available genealogy | stands beside the church his father will not discuss | sells a $10 special that is either one rock or exactly one tic-tac |
| KARAOKE MIKE | owns the machine but not the microphone | laundromat sound department | takes $5 for a rhythm hearing; requests are processed as escape attempts |
| YOUR POSSUM | follows silently and treats ownership as a route error | temporary companion acquired from the neighborhood possum situation | reveals nearby cash; may be released without ceremony |
| THE BUS DRIVER | arrives once and looks at you until the decision exists | day-30 bus stop, then nowhere | offers one irreversible ride; refusal is also irreversible |
| BRUTUS THE OLDER | larger, redder, remembers the original smell | returns beside the player as Brutus's senior claim | charger boss unless the block already loves you; may carry a torch |
| SOMEONE YOU DON'T KNOW | knows one fact about you and declines a second sentence | appears nearby on day 3, then walks beyond the map | says “i heard about you”; offers nothing and leaves |
| COP | arrives from the nearest edge and radios when distance becomes insulting | generic wanted response, not a resident | chases, calls backup, arrests, and removes cash plus rocks |
| DARRYL UNDER BLUE | wears blue roof plastic as weather and title | ruler beneath BLUE TARP COURT | charger hearing with two clerks; surrenders the BLUE WEATHER seal |
| GENERAL RECEIPT | receipt sash extends past the return window | ruler of CART CAVALRY KEEP | grabber appeal with two clerks; surrenders the CART APPEAL seal |
| BISHOP WIRE | antenna mitre receives only b flat | conducts the hubcap congregation in COPPER CHOIR YARD | ranged mass with two deacons; surrenders the COPPER MASS seal |
| THE CURB EMPEROR | stacked-curb crown, folding-chair throne, broken ruler | final authority of THE THRONE DITCH until the chair objects | three-phase succession fight; leaves $60, 40 cred, and the same chair |
| TARP KNIGHT | tarp hood and bucket-lid shield, no roof permit | bounded guard of BLUE TARP COURT | attacks unauthorized weather filings; grants no loot or allegiance |
| CART LANCER | holds a shopping-cart fork where a horse would go | bounded guard of CART CAVALRY KEEP | charges, grabs, or swarms for the return department; grants nothing |
| WIRE DEACON | wire stole, loose coil, attendance marked yes | bounded guard of COPPER CHOIR YARD | conducts ranged objections and close corrections; grants nothing |
| KNIGHT EMERITUS | wears whichever conquered uniform still fits | throne guard and emperor reinforcement | refuses succession in person; grants no reward |
| CURB PRETENDER No. N | number changes daily; petition does not | returns to a conquered ruler post after coronation | one elite objection per day; defeat pays $10 and 2 cred once |

**Rule: New NPCs must extend this table.** If you can't fill all four columns, don't ship the NPC.

---

## Random event template

Every random event follows this:

```
EVENT: <one specific subject> + <unexpected verb> + <impossible detail> [+ optional fourth flat beat]
EFFECTS: {stat: value, ...}  // small numbers, -5 to +10
```

Examples that pass:
- "A possum wearing a tiny construction helmet emerges from a drain. Looks you dead in the eye. Retreats." `{}`
- "A pigeon shits exactly $4.20 in change directly on your head. The pigeon nods. You nod. The exchange is complete." `{cash: 4}`
- "You forget what year it is for 4 minutes. When you come back, you are holding a traffic cone." `{brain: -3, item: 'traffic cone'}`

Examples that FAIL:
- "Something cool happens to you!" (too vague)
- "A big scary monster attacks you and you barely survive!" (wrong vibe)
- "lol a thing happened" (low effort)

---

## Dialogue template

Every NPC dialogue follows this:

```
SPEAKER: NAME IN ALL CAPS
TEXT: 1-3 lines of lowercase NPC speech, possibly framed with brief narration
OPTIONS:
  1. action + cost (the obvious one)
  2. action + cost (the alternative)
  3. dumb thing the player can try + worse cost (escalation option)
  4. leave (ALWAYS PRESENT)
```

The "leave" option is mandatory. The player always has an exit. The world does not trap them in conversation.

---

## Final check before shipping a new feature

Ask:
1. Would this feel out of place in Aqua Teen Hunger Force?
2. Did I name the NPCs with full cursed lore?
3. Is the toast text flat and accounting-style?
4. Did I avoid all the HARD STOPS?
5. Does the bit get punched, or land flat?

If yes/yes/yes/yes/no — ship it. Otherwise, rewrite.

---

## One paragraph summary you can paste into any prompt

> Rock Bottom is a top-down Zelda-style action game where the player is a crackhead trying to score rocks from a local dealer (Tre Bag Tony). The tone is satirical Adult Swim comedy — Aqua Teen Hunger Force, Tim Robinson, Robot Chicken. NPCs speak in lowercase fragments, have specific cursed names with full lore (PAULIE THE FACE, SPIDER-BITE SHERRI, THE CONDUCTOR who waits for a train that does not come), and the narrator never editorializes. The escalation pattern is mundane → absurd specific → escalate one notch → land flat. The crackhead is a clown in a comedy, treated with the dignity of a clown. Do not glorify drugs, do not punch down at real addiction, do not moralize, do not break the fourth wall.
