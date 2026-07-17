# SPEC — RAISE THE CHARACTER CEILING (v21 Wave 4.2)
## Project: Rock Bottom
## Status: operator-ratified 2026-07-16 · *"make the corrections, raise the ceiling... we can have a lot of detail and still be pixel."*
## Origin: `REFACTOR-FINDINGS.md` §F-VIBE-ART · `VIBE.md` §Texture (retracted + corrected `df1476e`)

---

## THE MEASUREMENT THIS IS BUILT ON

Not a taste argument. Checked in source:

| | |
|---|---|
| game canvas | `800×600` — `index.html:180` |
| **world draws at** | **1 canvas pixel** |
| sprite source | `16×16` — `sprites.js:190` |
| sprite drawn at | `32×32` — `actors_weather.js:136` |
| **character draws at** | **a 2×2 block of canvas pixels** |

**The actors have been running at half the resolution of the world they stand in.** `sprites.js:863`
says it out loud: *"Render palette-indexed sprite to a 32×32 offscreen canvas (16×16 scaled 2x)."*

**Nobody chose this.** It is the last surviving line of a v3 rule the environment abandoned when it
grew a 3,912-line renderer. The operator's *"avatars look a little weak"* is not a preference —
**it is him noticing a resolution mismatch that has been there for sixteen versions.**

---

## THE KEY FACT THAT MAKES THIS CHEAP

**The draw path does not change.** `ctx.drawImage(sp, drawX, drawY, 32, 32)` already draws into a
`32×32` screen rect. Raise the source from `16×16` to `32×32` and **the scale factor goes from 2×
to 1× on its own.** Same screen size. Same anchor. Same hitbox. **Four times the pixels.**

This is not a rescale of the game. **It is the characters finally landing on the world's pixel
grid.**

---

## WHAT

Parameterize the sprite toolkit so a sprite declares its logical size, support `16` and `32`
**simultaneously**, and **migrate everything.** All 93 bases. Characters, gear, weapons, props.

> **AMENDED 2026-07-16 — the operator overruled the one-sprite gate, and he was right.**
>
> This section originally said: *"Not all 93 sprites. The player. One sprite. Then stop and show
> the operator."* That caution came from **my doubt about whether an agent can author good pixel
> art** — doubt I had no evidence for. **The operator does:** *"5.6 SOL seems surprisingly good at
> pixel art, I've seen tons of examples online. Write the delegation, take the risk without fear.
> Tell codex to do the thing and then some. Sprites, clothes, weapons, etc. Go wild."*
>
> **His information beats my speculation.** I was speculating about a model's capability from
> nothing; he has seen the work. **A gate built out of an unfounded doubt is not caution, it is
> friction with a rationale.**
>
> **And the risk is genuinely contained, which is why this is not recklessness:**
> - **"Go wild" here costs zero runway.** This is the same word that took the world from 4400×3400
>   to 8600×5600 one wave at a time — but that was *distance* and this is *density*. **No sprite
>   can trip `world-gate`.** The budget this wave spends is bytes and taste, not the player's legs.
> - **`rock_bottom_v19.html` is the floor**, frozen and hash-pinned. Bad art is one branch,
>   unmerged, and a `git checkout` away from never happening.
> - **The invariants below are not caution — they are the things that break the game**, and they
>   all still bind. Hitboxes, identity, key count, palette. Go wild *inside* them.
>
> **What survives from the original caution:** the acceptance gate is still a human eye, because
> no gate reads art. That is not a reason to ship one sprite. It is a reason to be honest that
> 12/12 green means nothing about whether this looks good.

---

## INVARIANTS

- **I-SAME-SCREEN.** ⭐ A 32-logical sprite occupies the **exact same screen rect** as the 16-logical
  one it replaces: `32×32` at the same bottom-center anchor. **No character changes size, position,
  hitbox, or footprint.** If the player looks bigger, it is wrong.
- **I-BOTH-SIZES.** ⭐ 16 and 32 coexist for the whole migration. **A big-bang across 93 bases is
  forbidden** — if everything moves at once and it looks worse, nobody can tell which sprite did it.
  Same reasoning as `SPEC-refactor-modularize.md` §I-INCREMENTAL, and it was right then.
- **I-DECLARED-SIZE.** Every sprite base declares its logical grid size. **No default, no
  inference.** "Nobody said" is the state that produced this entire finding — see OD-11, which
  killed the same disease in the facades.
- **I-NO-KEY-LOSS.** `SPRITE_CACHE` holds **373 keys across 93 bases**. Migration may not silently
  drop one. A missing key falls back to `_0` at `actors_weather.js:129` and **fails invisibly** —
  the wrong frame renders and nothing errors.
- **I-IDENTITY.** `npc-registry-gate` guards **55 canonical rows / 59 source identities**. A sprite
  is not an identity. **Nobody becomes a stranger because their art changed.**
- **I-STILL-PIXEL.** ⭐ No anti-aliasing, no smoothing, no gradients, no sub-pixel placement.
  `image-rendering: pixelated` stays. Palette-indexed grids stay. **Detail is not refinement.** The
  operator's line is the contract: *"a lot of detail and still be pixel."*
- **I-PALETTE.** VIBE's canonical palette and its **FORBIDDEN COLORS** still bind — no pure white,
  no bright blue outside cops, no pastels, no neon. **More pixels is not permission for more
  colors.**
- **I-VIBE.** A crackhead rendered with four times the pixels is still a crackhead. **Do not make
  anyone dignified, heroic, or cute.** The game does not editorialize; neither does its art.

---

## THE HONEST PART — WHAT NO GATE CAN TELL US

**Art is the one thing in this repo that cannot be gated.** Every other task here is logic, and
logic gets a mechanical enforcer. **No gate knows whether Baggie Barb looks good.**
`runtime-smoke` will cheerfully report 373 keys of garbage and `GATE RUNNER: 12/12 PASS` underneath
it.

**So when this comes back green, green means the game still runs. It does not mean the art
landed.** Say that plainly in the report. **Do not let a passing suite stand in for a verdict it
cannot give** — that is the whole disease this repo has been treating all day, and it would be
embarrassing to catch it here.

**The eye is the gate. The operator's, not yours and not mine.** Ship it all, then say honestly
which sprites you think are weak. **An agent that reports 93 sprites as uniformly good has stopped
looking.**

---

## EDGE CASES

- **Gear overlays** (`gear_*`, ~15 bases) composite onto the player. A 32-logical player with
  16-logical gear will misalign. **Player and its gear migrate together or not at all** — that is
  the real first unit, not "the player."
- **`playerhi` / `playerattack` / `playerattackhi`** are player variants. Same unit.
- **The grid toolkit is 16-hardcoded in ~10 places** — `blankSpriteGrid` (:25), `gridPut` (:27),
  the loops at :36, :39, :195, :201, the clamps at :240 and :301. **124 bare `16`s across `src/`;
  most are unrelated.** Do not blind-replace.
- **`applyVars` / `parseGrid`** take string rows. A 32-wide row is a 32-char string. Verify no
  parser assumes width 16.
- **Sprite cache canvas** at `:189-190` is fixed `16×16`. It becomes the sprite's declared size,
  rendered into the same `32×32` output canvas.
- **The cart underlay** (`actors_weather.js:285`) and hit-flash / trail draws (`:303`, `:323-328`)
  all assume `32×32`. They stay correct by I-SAME-SCREEN — **verify, don't assume.**

---

## ACCEPTANCE CRITERIA

- [ ] Toolkit parameterized. 16 and 32 both render correctly, **in the same running game.**
- [ ] Every sprite base declares its logical size. Zero undeclared.
- [ ] `tools/sprite-gate.mjs`: fails on an undeclared size, on a key-count regression below 373, on
      any base losing a direction/frame. **Red-tested in every direction.**
- [ ] Player + its gear overlays migrated to 32-logical. **Everything else untouched at 16.**
- [ ] Screen rect identical — a diff of draw coordinates before/after shows **no change**.
- [ ] `npc-registry-gate`, `legibility-gate`, `presentation-gate`, `runtime-smoke` all green.
- [ ] **A screenshot for the operator, before any further sprite is touched.**
- [ ] Findings appended. BRAIN appended. DELEGATION updated.

---

## THE TRAP

**Ninety-three sprites is a grind and the temptation is to batch it.** Don't. The migration is not
the risk — **the art is.** One sprite tells us whether this direction is right; ninety-three tells
us nothing except that we spent a night.

Second trap: **more pixels invites more colors.** VIBE's palette is not a suggestion and the
forbidden list exists. **The reason this game looks like something is the constraint, not the
resolution.**
