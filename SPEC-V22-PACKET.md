# SPEC-V22-PACKET — the map, not the key

status: operator ideas captured 2026-07-17 from voice, mid-drive. **AI-led draft, operator veto standing.**
Nothing here is ratified. Sections graduate into SPEC.md as each system implements and its gates pass.
Follows the `SPEC-V20-PACKET.md` idiom: packet first, SPEC on landing.

---

## NORTH STAR (unchanged, and it constrains everything below)

> success is the neighborhood adjusting around you. recognition without reward. the ladder is not
> upward — the throne was a lawn chair. it is inward.

**The operator restated this himself, unprompted, on 2026-07-17:** *"there's not like you beat the
game. you don't get to be — you don't get to win. Like, that's the thing. You don't get to win this
game."* **Two months after ratifying it, from memory, in a car.** The north star is holding without
enforcement. That is worth more than the gate that proves it.

---

## HOW IT WORKS TODAY (verified in source, not recalled)

The operator asked how the expansion actually works — *"I don't really know because it was vibe
coded."* Answer, from `src/systems/recognition.js` and `src/systems/concessions.js`:

- **Five verbs counted per venue:** `sit`, `bother`, `buy`, `sell`, `full_high`.
- **Ladder:** `stranger` → `counted` (3) → `furniture` (8) → `conceded` (15).
- **At `conceded`, the venue becomes a CONDITIONAL smoke spot** — not an unconditional one:
  - `park` → `isNight()`
  - `choir_office` → `choirOfficeOpen()` (its own clock — b flat to b flat, not the sun)
  - `underpass` → `dogPresent()`
  - `laundromat` → `dryerMidCycle()`
- **The Block is unconditional. Forever.** `concessionConditionMet` has no `block` case; the Block
  never asks.

**So: you never get to smoke anywhere. You earn four rooms, each of which still has to be in the
mood.**

---

## 1. THE UNLOCK TREE — and the tension it creates

**Operator's idea:** *"there's smoking spots throughout the map, and you have to unlock them by
doing these quests for these crazy fucking wild NPC crackheads. Go do this crazy crack mission, and
you unlock the smoke spot."*

### ⚠️ THE TENSION, NAMED BEFORE IT GETS BUILT

**A quest is a transaction: do X, receive Y. That is a reward.** The recognition system's entire
premise is that **you do not earn the bench** — you keep sitting on it and it develops your dent.
Nobody grants it. **Bolting a quest tree onto the venues builds a parallel economy whose rule is
the opposite of the ledger sitting next to it.** Two systems, contradictory laws, and the newer one
wins by being louder.

**Note what would NOT catch this:** `recognition-gate` proves zero reward leakage *through the
recognition ledger*. A quest that hands out a room doesn't touch the ledger — **it routes around
it.** The gate stays green while the north star dies. **Same shape as every corpus failure in
`ORCHESTRATOR-NOTES.md`: the check is real and it is pointed at the wrong thing.**

### ✅ THE SYNTHESIS — the quest is a MAP, not a KEY

**The quest does not give you the spot. It tells you the spot exists.**

A wild crackhead tells you the choir office keeps hours. **Now you know there is a room there. You
still have to sit in it fifteen times.** The neighborhood still concedes on its own terms, on its
own count, for its own reasons.

**Why this is strictly better than either half:**

1. **It preserves the north star exactly.** Nothing is granted. The dent is still earned by sitting.
2. **It solves a real hole the operator found by accident.** *How does a player currently learn the
   park counts?* **Nothing tells them.** `BAD IDEA` only points at a spot once you've already
   conceded it. Before that, the four venues are invisible — you'd have to sit at the park fifteen
   times **by coincidence**. **The discovery layer is missing and the quest tree is it.**
3. **It is more VIBE than an unlock.** *"the dryer knows"* is information passed between crackheads.
   That's the world talking. A quest-giver paying out a reward is a different genre.
4. **It makes the rooms secrets instead of achievements.** Secrets survive being told. Achievements
   die the moment you have them.

**Invariant candidate — I-MAP-NOT-KEY:** no quest, mission, NPC, or flag may grant a concession,
lower a threshold, or credit a recognition verb. **Quests may only reveal that a venue exists.**
The ledger remains the only path to `conceded`.

---

## 2. THE ROBBERY — losing things in gang territory

**Operator's idea:** *"if you go there and they beat you up, maybe they take a little bit of your
stuff. Or maybe they'll take some of your clothes."*

**This is a resource SINK, and this economy has almost none.** Every mechanic in the game so far
adds. `feedback: no infinite resource loops` has been the standing rule — this is the inverse and
the game needs it. **Losing your coat to the Skid boys is the most VIBE thing in this packet:** a
bad trade, an indignity, no editorializing, and it lands flat.

**Bounds, before anyone builds it:**
- **Cannot softlock.** Never take the last thing required to progress a live campaign objective.
- **Cannot take what the world needs back.** Gear that gates a route or a claim is off the table.
- **Must be visible.** If they take your coat, the coat comes off the sprite. `sprite-gate` now
  guards 93 declared bases — **an invisible robbery is a bug, not a mystery.**
- **Recovery is not guaranteed.** You do not get a quest to reclaim your coat. It is gone. Someone
  is wearing it. You may see it later. **You do not get it back.**

---

## 3. THE PIPE — scavenging and the emergency hitter

**Operator's idea:** *"maybe you get to take an emergency quick hitter. Or maybe you have to find a
hitter in the trash, or find parts to make a pipe."*

Raw and unresolved. **Two open questions the operator has to answer, not a builder:**
- Is the pipe a **tool** (durable, breaks, replaced) or a **consumable** (one hit, gone)?
- Does scavenging compete with the shakes clock, or run alongside it? **A scavenging loop that
  costs runway is a different game than one that doesn't** — `world-gate` will have opinions.

**The standing rule applies:** anything that grants a resource gets a cooldown, cap, diminishing
return, or cred gate **before it ships**, not after.

---

## 4. WHAT THIS PACKET IS ACTUALLY FOR

The operator, same conversation: *"it should be something that causes you to play the game more."*

**That is the whole brief, and it is not "add content."** The game already has more content than
any player has seen. **What it does not have is a reason to come back to a room you already know.**

Recognition was the first answer to that — the bench remembers you. **The unlock tree is the
second: there are rooms you haven't been told about yet.** Both work because they are **the world
noticing you**, not the world paying you.

**Anything in a future wave that answers "why play more?" with a reward has answered the wrong
question.**
