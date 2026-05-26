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
- Pixel art is CHUNKY, not refined. 16x16 logical, scaled 2x.
- Backgrounds use 64x64 checker grid + procedural grime splotches
- Emoji used unironically for NPCs and props. This is the look, not a placeholder.

### Building rules
- Solid buildings: filled rect + 3px dark border
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
6. **Mundane > magical.** A possum that wears a construction helmet is funnier than a wizard. A pigeon that demands bread for secrets is funnier than an oracle.
7. **Make the player do undignified things for small rewards.** Pawning a single AirPod. Selling a wet sock. Eating half a chimichanga out of a milk crate.

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
| THE CONDUCTOR | waits for a train | the projects | buys 3 PURE COPPER for $90 |
| LOUD LARRY | just loud | the projects | fights, big damage |
| STRIPE | rival dealer, sells soap | the projects | $8 rocks, 40% are soap |
| THE PIGEON KING | one foot, unblinking | wanders | trades secrets for $2 bread |

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
