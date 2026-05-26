# SPEC.md — Rock Bottom Behavioral Contract

> SpecMesh format. Read VIBE.md before this if you haven't already. Spec without vibe is a soulless port.

---

## WHAT

Top-down action RPG built as a single HTML file. Pixel-art player sprite, emoji NPCs. 7+ zone walkable city, ~2200×1800 world with camera following player on 800×600 viewport. Real-time fist combat. Resource management (rocks, cash, shakes, cred, brain, wanted). Rank progression with one ascension boss. Persistent save via window.storage.

## WHY

Satirical comedy in the Adult Swim tradition. Sandbox absurdity rewards exploration and pattern recognition. The player learns the NPCs, finds optimal routes, escalates their crimes, and earns the ending through commitment.

The game is also a VibeKoded portfolio piece — a demonstration of building an unhinged comedic product through AI orchestration without sacrificing taste.

---

## INPUTS (player actions)

| Key | Action | Notes |
|-----|--------|-------|
| WASD / Arrow Keys | Move | 4-directional, normalized diagonal speed |
| SPACE | Swing fist | Instant hitbox in facing direction, 280ms cooldown |
| E | Interact / Talk | 60px radius from NPC center |
| SHIFT | Sprint | 1.7x speed, increases shakes faster |
| I | Toggle inventory panel | Pauses world while open |
| M | Mute audio | Toggle, toast confirmation |
| L (title only) | Load save | Visible only if save exists |

## OUTPUTS

- **Visual:** 800×600 canvas, pixel-art sprite player with walk animation, emoji-based NPCs, particle effects on hit, screen flashes for damage/high/crash
- **Audio:** Synth chiptune SFX via Web Audio API, no sampled audio
- **Persistence:** `window.storage.set('rockbottom_save', JSON)` on rank up, purchase, heist completion, death, plus auto-save every 45 seconds

---

## RESOURCES (player stats)

| Stat | Range | Decay | Death | Display |
|------|-------|-------|-------|---------|
| HP | 0-100 | None (regenerates only via actions) | Triggers respawn at 0 | 5 hearts in HUD |
| Cash | 0-∞ | None | N/A | `$N` |
| Rocks | 0-∞ | None | N/A | `🪨 N` |
| Pure Copper | 0-∞ | None | N/A | `🪙 N` — stolen from abandoned bldg |
| Supplies | 0-∞ | None | N/A | `🧪 N` — unmarked packets from Baggie Barb (clean) or Pinky Polenta (dirty/house cut) |
| Dirty Supplies | 0 ≤ N ≤ Supplies | None | N/A | counter within Supplies; consumed first by `doCook`; ramps post-roll soap rate |
| Shakes | 0-100 | Climbs +0.0025/ms passively, +0.05/ms sprinting | At 100, 1.5% chance per tick of 2 damage | bar, red above 70 |
| Cred | 0-∞ | None (losses only from in-game events) | N/A | gates ranks |
| Brain | 0-100 | Decays from drug use and trauma | N/A | currently cosmetic, future: gates dialogue |
| Wanted | 0-3 | -1 every 30 seconds | At 0 = no cops | star icons in HUD |

---

## COOKING (v13 wave 4) — the heat minigame

At THE BLOCK, with `P.supplies > 0`, the milk crate becomes a kitchen. The cycle:
steal copper → sell to Yuri → buy packets from Baggie Barb → cook at the crate via THE HEAT minigame → smoke or fence to Stripe → repeat.

### Cook modes (5)

| Mode | Packets | Fill ms | Sweet center | Spread | Base width | Burn zone |
|------|---------|---------|--------------|--------|------------|-----------|
| low and slow | 1 | 4000 | 0.55 | ±0.05 | 0.22 | 0.08 |
| fast cook | 3 | 2400 | 0.70 | ±0.05 | 0.16 | 0.08 |
| shaky hands special | 1 (needs shakes ≥ 60) | 1800 | 0.78 | ±0.07 | 0.10 | 0.08 |
| cook all | 5+ | 3200 | 0.65 | ±0.05 | 0.13 | 0.08 |
| propane (unlock) | 1 | 1200 | 0.65 | ±0.05 | 0.08 | 0.15 |

`width = clamp(baseWidth + bb*0.10, 0.05, 0.40); if (rockedUp) width -= 0.06;`
`bb = clamp((brain-30)/70, -0.4, 0.6)`.

### Outcomes from the heat (distance d from sweet-spot center, half-width halfW)

| Outcome | Trigger | Modifiers |
|---------|---------|-----------|
| PERFECT | d ≤ halfW | yield × 1.15, soap rate × 0.70, unlock THE_HEAT_HELD |
| OK | d ≤ halfW × 1.8 | baseline math |
| BAD | d ≤ halfW × 3.0 | yield × 0.60 (floor), soap rate × 1.50 |
| BURN | needle in top burnZone OR no input within 1s | 0 rocks, brain -10, wanted +1, 2s smoke overlay, unlock CONTROLLED_BURN |
| UNDERCOOK | needle < 0.20 OR pre-emptive lock < 0.25 | 0 rocks, supplies consumed flat |
| SOAP-ROCK | far miss (d > halfW × 3.0) and not burn/cold, 15% chance | yield × 0.5 (floor), all rocks tagged as soap (P.soapRocks); other 85% of far-miss → BAD |

### Yield base math (per packet, preserved from v12/v13)

| Mode | 2-rock chance | Burn chance |
|------|---------------|-------------|
| slow | 0.08 + bb*0.15 | 0.10 - bb*0.08 |
| fast | 0.35 + bb*0.20 | 0.30 - bb*0.10 |
| shakes | 0.55 | 0.45 (ignores brain) |
| all  | 0.15 + bb*0.18 | 0.18 - bb*0.10 |
| propane | 0.30 + bb*0.20 | 0.20 - bb*0.10, ×1.30 yield bonus |

Each cook costs 1-6 brain and adds 2*n shakes (except shakes special). Post-roll soap rate is `(dirtyUsed*0.25 + cleanUsed*0.12) / n * soapAdjust`; dirty (Pinky's house cut) consumed first. Cooking 3+ at once has a 35% wanted+1 (the smell), but only on OK or PERFECT (BAD/BURN already bump wanted).

ESC during the minigame consumes supplies and gives 0 rocks. Tap/click on canvas or press SPACE to lock the needle.

Stripe buys real rocks at $6 each (1) or bulk (3+); resells at his $8. Stripe does not fence soap rocks (they live on P.soapRocks, parallel to P.rocks).

### Soap rocks

`P.soapRocks` is a parallel FIFO counter to `P.rocks`. The HUD `🪨` count shows the total of both — soap is indistinguishable in inventory. When smoking, soap rocks burn first: they consume the smoke action without granting rocked-up, shake relief, brain hit, or cred. They unlock SOAP_TONGUE and trigger the canonical line: "you smoke it. it's soap. you knew. you smoked it anyway."

### Propane torch (4th mode unlock)

`EQUIPMENT.propane_torch` is a `slot:'tool'` item (new tool slot added to `P.equip`). Acquisition:
- 25% drop on a night-time kill of BRUTUS or BRUTUS THE OLDER. Uses the existing cash-pile pickup pattern with `tool:'propane_torch'` field; the pickup loop branches on that field and equips the torch directly. Always-visible pickup (a brass body + pilot flame sprite).
- Pete's pawn shop stocks one once player reaches rank ≥ 3 (`state.flags.peteTorchStocked` flips on dialogue open). Sells for $80. One and done (`state.flags.peteTorchSold`).

Owning the torch (`P.equip.tool === 'propane_torch'` via `hasPropane()`) reveals the 5th cookBatchMenu option.

**Invariants:**
- Cooking only at THE BLOCK (matches the smoke invariant)
- The crash always follows the high (cooking does not bypass)
- Supplies are cook-only; no street value
- The bb brain modulation continues to apply on yield/burn rolls under the heat minigame
- Soap rocks never trigger rocked-up — they are silent in the smoke
- Pete's torch is one-time per save

---

## RANK PROGRESSION

```
0  Stem-Tip Sucker        [  0+ cred]
1  Sidewalk Tweaker       [ 10+ cred]
2  Alley Rat              [ 25+ cred]
3  Strip-Mall Fiend       [ 50+ cred]
4  Block Captain          [100+ cred]  → unlocks Abandoned Building
5  Pipe Prophet           [200+ cred]
6  The Glass Mayor        [400+ cred]
7  CRACK LORD SUPREME     [800+ cred OR defeat boss]
```

Rank up: triggers `sfx.rankUp()`, toast notification, save.

---

## WORLD MAP (zones, in canonical positions)

| Zone | Position | Role | Key NPCs |
|------|----------|------|----------|
| THE BLOCK | center (900-1200, 740-960) | spawn, smoke spot, sleep spot | — |
| SCRAP YARD | top-left (100-600, 80-440) | metal collection, $25/copper to Yuri | Yuri, Brutus |
| PAWN SHOP | left-middle (130-380, 580-760) | pawn loot, $15/copper to Pete | Pete |
| DEALER'S CORNER | middle-right (1450-1770, 780-1020) | buy rocks $10 | Tre Bag Tony |
| ABANDONED BUILDING | top-right (1500-1980, 100-460) | copper heist (LOCKED until rank 4) | — |
| MARKETPLACE | bottom-center (700-1400, 1380-1620) | panhandling, shoplifting, mom | Whole Foods Mom, Chatty Dave |
| BACK ALLEY | bottom-left (100-600, 1280-1660) | hostile crackheads, dumpster dive | Lurch, Sherri, Paulie |
| CHURCH | bottom-right (1600-1980, 1300-1620) | tic-tac methadone, donations, steal plate | Father O'Malley |
| THE PROJECTS | bottom-far-left (100-700, 1700-1780) | Conductor copper trade, Loud Larry, Stripe | Conductor, Larry, Stripe |

### Building collision rules

- `solid: true` → blocks all movement (player can't enter)
- `locked: true` → BLOCKS movement; press E adjacent to trigger heist. **(v12: rank gate removed — the brutus jr. door is now the gate, not your cred.)**
- `fences: true` (scrap yard) → perimeter blocks except 140px gap on south side
- `dashed: true` (zones) → no collision, visual marker only
- Church has a 60px door gap on south side, passable

---

## NPCS

See `VIBE.md` for full identity registry. Mechanical spec:

### NPC fields (canonical)
```js
{
  id: string,           // unique
  name: string,         // displayed above sprite
  emoji: string,        // sprite face
  x, y, w, h,           // 28x28 standard
  color: hex,           // body rect color
  hp, maxHp, speed,     // combat
  hostile: bool,        // attacks player on contact
  aggro: bool,          // active chase state
  wander: bool,         // random walk pattern
  dmg: int,             // damage per hit (default 8)
  zoneOnly: rect?,      // hostile only inside this rect (e.g. Brutus in scrap yard)
  interact: fn?,        // E-key dialogue handler
  isCop: bool,          // special: triggers arrest at player 0 HP
  dead: bool,           // removed from active updates
}
```

### Hostility tiers
- **Always hostile in zone:** Brutus (scrap yard only)
- **Hostile if seen, aggros on damage:** Lurch, Sherri, Paulie, Loud Larry
- **Spawned hostile:** Cops (when `wanted >= 1`)
- **Vendor/peaceful:** Tony, Yuri, Pete, Mom, Possum, Priest, Conductor, Stripe, Pigeon, Barb, Pinky, Mathematician
  - Hitting a peaceful NPC → they go hostile, wanted +1

### Cousin Brendan (v13 wave 2 mini-boss)
- Spawn rule: in `manageCops`, when wanted ≥ 2 and no live Brendan exists, the next spawning cop has a 30% chance to be Brendan. Hard cap: 1 Brendan at a time.
- Stats: HP 55, speed 2.3, taser dmg 50.
- Taser state machine: `taserChargeT` accumulates dt up to 4000ms whenever Brendan is in aggro/chase. On touch, if `taserChargeT >= 4000`, fires (50 dmg, blue particle burst, 1000ms attackCd) and resets the timer. Below 4000 he just chases.
- Drop: a $30 cash pile at his body (re-using the cash-pile pickup mechanic — the "rookie badge").
- Unlocks: `BADGE_MONEY` achievement; first kill broadcasts "uncle dean is posting on facebook again."

---

## COMBAT

### Player attack
- Triggered by SPACE
- 36px hitbox in facing direction, 4px on perpendicular axis
- Damage: 14-22 base, ×1.5 if rocked-up
- 280ms cooldown
- Knockback applied to target proportional to direction vector × 6
- 6 hit particles spawned at target center

### Player damage taken
- Touch damage from hostile NPCs, on 800ms cooldown per attacker
- 500ms invincibility frames after hit
- 250ms red sprite flash, screen flash overlay
- Knockback proportional to attacker direction × 8

### Death
- HP ≤ 0 triggers `die()`
- Special case: cop kills player → `arrestScene()` instead
- Respawn at THE BLOCK with hp=60, shakes=30, cred-10, wanted=0
- All cops despawn on death

### Arrest
- Loses 70% of cash
- Loses all rocks
- Inventory preserved (including copper — "they didn't check your sock")
- shakes = 100
- wanted = 0

---

## STATUS EFFECTS

### Rocked Up
- Trigger: smoke a rock at THE BLOCK (consumes 1 rock)
- Duration: 18 seconds (18000ms)
- Effects: 1.8× movement speed, 1.5× attack damage
- Visual: gold sprite palette swap, gold aura ring around player, screen tint with chromatic wobble
- Audio: rising arpeggio on activation
- Side effect: shakes -50 on activation, brain -4
- **MUST transition into Crash on expiry**

### Crash
- Trigger: Rocked Up timer expires
- Duration: 8 seconds (8000ms)
- Effects: 0.5× movement speed
- Visual: purple haze screen overlay
- Audio: sawtooth descent on activation
- Side effect: +30 shakes on activation

### Wanted (1-3)
- Trigger: punching vendors, shoplifting fail, killing NPCs, B&E
- Decay: -1 every 30 seconds (paused while wanted = 0)
- Effects: spawns N cops where N = wanted level
- Cops have 80 HP, 1.8 speed, 18 damage, 500px vision range

---

## SAVE / LOAD

### Save trigger
- Auto-save: every 45 seconds (`setInterval`)
- Event-save: rank up, transaction completion, heist completion, death, arrest
- Mute does NOT trigger save (cosmetic only)

### Save shape
```js
{
  version: 3,
  player: { ...full player state },
  npcsKilled: ['lurch', 'sherri', ...],
  bossActive: bool
}
```

### Load
- Title screen detects save via `window.storage.get`
- "[L] load save" appears if save exists with `version >= 2`
- Load restores player state, marks dead NPCs as dead
- Attack timers / hit flashes reset to 0 on load (safety)

---

## QUESTS (v13 wave 3)

The quest infrastructure is a flat object `state.quests` keyed by quest id. Each quest has `{ title, flav, done, available?, intro? }`. `available` is the "told but not started" state used by the new tri-state UI (active / available / done). `intro: true` marks an intro-chain quest.

### Intro chain (FORCED on new saves)

The intro chain is three quests auto-given when a new save begins. While any intro quest is undone, hustle generation, world events, and ambient phone calls are suppressed (the mom intro tip is exempt — it fires regardless ~30s into a new save). New saves also start at $0 cash.

| id | objective | completion | reward |
|----|-----------|------------|--------|
| intro_remember | find ten dollars somewhere on the block. | pick up the $10 pile spawned in THE BLOCK OR accumulate $10 cash from any source | +1 cred, toast "you arrive somewhere by walking. who knew." |
| intro_tony | the man at the corner has a job for you. | open Tony's dialogue once | +1 cred, toast "he charges ten dollars. that is the price. he does not negotiate. sometimes he does." |
| intro_smoke | the crate is for sitting. the rock is for smoking. | smoke 1 rock at the crate | +2 cred, toast "you understand the loop." + sets `state.flags.introDone = true`, un-suppresses world systems |

Existing saves load with `introDone = true` defaulted-on and skip the intro chain.

### Side quests (standalone, NPC-offered)

| id | hook | objective | reward | achievement |
|----|------|-----------|--------|-------------|
| pigeon_crown | pigeon king dialogue ≥2 → offers quest | pick up the crown from 1 of 6 deterministic spots (seed: `state.flags.crownSpotIdx`) | the cursed crown hat: -3 cred BUT +1 charisma (10% vendor discount) | HEAD_THAT_WEARS |
| stripe_package | stripe dialogue ≥3 → offers quest | deliver to conductor (auto on 60px proximity) OR open at the crate | deliver: +$40 +3 cred. open: 35% brick (+5 rocks), 30% 2 soaps, 25% knife (weapon), 10% wire bait (+2 wanted) | EXACT_CHANGE (deliver) or WHAT_S_IN_THE_BOX (open) — open sets `state.flags.stripeBetrayed = true`, closes fencing |
| barb_crossword | barb dialogue ≥2 → quietly sets `state.flags.daveHasCrossword = true` | demand from dave (cred ≥3 = free; else $20 ransom or fight); return to barb | +1 clean packet, unique "BLAME" reveal dialog | SEVEN_ACROSS |

### Discoverability layer

`VENDOR_FLOATER_IDS` is a canonical Set of 13 NPC ids (tony, yuri, pete, barb, biggu, conductor, larry, paulie, stripe, mom, priest, pinky, math). For each id NOT in `state.metVendors`, a bobbing semi-transparent "?" renders ~16px above the NPC head. First call to `interact` from `tryInteract` adds the id to `state.metVendors` and saves. The Q-key panel surfaces only met vendors in its "PEOPLE YOU'VE MET" section — never a list of all vendors (preserves discovery).

### Q-key UI

`renderQuests()` now renders three sections: HUSTLES, QUESTS (split into ACTIVE / AVAILABLE / DONE), and PEOPLE YOU'VE MET (only `state.metVendors` entries, with zone + tagline from `VENDOR_INDEX_META`). Quest entries show reward preview text.

## CHARISMA (v13 wave 3)

`P.charisma` is summed from `EQUIPMENT[id].charisma` across all equipped slots in `applyEquipStats()`. Currently only `pigeon_crown` has `charisma: 1`. The `vendorPrice(base)` helper returns `Math.max(1, Math.round(base * 0.9))` when `P.charisma >= 1`, else `base`. Plumbed into Tony's $10 rock, Barb's $5/$22 packets, Pinky's $4/$18 packets, and Stripe's $8 buy / $6 fence.

## INVARIANTS

These properties MUST hold across all builds. Violating any of these breaks the game spec.

1. **Player can always reach Tre Bag Tony from spawn** — no zone is locked behind a hostile gauntlet
2. **Dealer's Corner is the canonical rocks vendor** — Stripe is an unreliable alternative, never the primary
3. **The Block is the canonical smoke spot** — rocks cannot be smoked elsewhere
4. **Yuri pays MORE per PURE COPPER than Pete** — $25 vs $15. Yuri is always the optimal sell.
5. **Boss is unwinnable without combat experience** — player must have learned to fight Lurch/Sherri first
6. **Death never deletes save** — only resets position and small cred penalty
7. **Quitting mid-conversation preserves state** — dialogue closes cleanly on next load
8. **Audio init only on first user input** — no autoplay violation
9. **The Possum is the only AI-call NPC** — no other NPC should pull from a remote API
10. **The crash always follows the high** — rocked-up cannot expire without triggering crash
11. **The boss is defeatable in <90 seconds for a competent player** — it's a comedy fight, not a tactical RPG fight
12. **Save uses window.storage, NEVER localStorage** — Claude.ai artifacts do not support localStorage
13. **Intro chain cannot be re-triggered** — once `state.flags.introDone` is true, it stays true. The chain is one-shot per save.
14. **Existing saves never re-enter the intro** — load defaults `introDone: true` so v12/early-v13 saves skip the chain entirely.
15. **Charisma discount applies only on the way out** — `vendorPrice(base)` is consulted at the moment of dialogue rendering; transactions in-flight don't refund or re-tax if charisma changes mid-trade.

---

## EDGE CASES

| Case | Behavior |
|------|----------|
| Player at $0 buying from Tony | Dialogue closes, toast: `"come back with money."` |
| Player at 0 rocks tries to smoke | No-op, toast informs |
| Player with empty inventory distracting copper-heist dog | Spends $3 instead of throwing item |
| Cop killed | +10 cred but +2 wanted level (escalates) |
| Player arrested at 0 HP from cop | Arrest scene fires, not death |
| Stripe's rock is soap (40%) | Cash spent, no rock added, Tony offenses -1 (Tony respects you slightly more) |
| Father O'Malley collection plate stolen and failed | Damage + wanted +1 |
| Boss spawned but player has rank 7 already | Boss still spawns, ending only triggers on boss defeat OR cred check, not both |
| Save loaded mid-boss | Boss state not preserved across saves (boss resets on load) — KNOWN LIMITATION |
| Player presses I during dialogue | Inventory does NOT open (dialogue blocks input) |
| Window resized | Canvas remains 800×600, CSS max-width handles fit |

---

## PERFORMANCE BUDGETS

| Metric | Budget |
|--------|--------|
| Frame time | < 16ms with 60 NPCs on screen |
| Sprite count | < 100 prerendered |
| Particle pool | Soft cap 200 (auto-prune on life expiry) |
| Save size | < 50KB |
| File size (total HTML) | < 80KB compressed |
| Initial paint | < 200ms after script load |

---

## API DEPENDENCIES

### Anthropic API (live AI events)
- Triggered ONLY by Possum interaction
- Model: `claude-sonnet-4-20250514`
- Max tokens: 400
- Failure mode: silent fallback ("the possum is busy. try again later.")
- NO API key passed (handled by artifact infrastructure)

### Window Storage API
- `window.storage.set(key, value)` — async
- `window.storage.get(key)` — async, returns `{value}` or null
- Used for save persistence ONLY
- All calls wrapped in try/catch — failures are silent

---

## OUT OF SCOPE (v3)

The following are NOT in v3 and should be considered for v4+ via DELEGATION.md:

- Multiplayer / co-op
- Mobile touch controls
- Day/night cycle
- Quest log UI
- Equipment system
- Tweaker vision mode
- Boss music
- Per-zone ambient audio
- Achievements
- New Game+
- Procedural graffiti
- Weather

---

## COMBAT PATTERNS (v13 wave 5)

Each hostile NPC archetype has a distinct attack pattern. Set via `n.archetype` at spawn (or — for transformed NPCs like the fallen priest — set at transformation). Non-archetype'd NPCs fall through to the default chase-bite (cops, larry, dave-on-aggro, etc).

### Archetypes

| Archetype | NPCs | Behavior |
|-----------|------|----------|
| `charger` | brutus | Windup 800ms (visible: red tint + giant `!`, audio.windup cue) → lunge 2.0× speed for 1.0s in vector locked at windup-start → cooldown 1.4s (vulnerable: +25% playerAttack damage). Damage ×1.5. Counter: dodge perpendicular during lunge. |
| `charger_older` | brutus_older | Same machine but windup 550ms, lunge 1.4s, damage ×1.8, cooldown 1.7s. Boss-only. |
| `grabber` | lurch | Default chase + on-contact stun: damage ×1.3, applies `P.stunT = 500ms`. All inputs gated while stunned (movement, SPACE, E). Lurch freezes for 200ms post-grab (arms-extended pose). |
| `swarmer` | sherri | Speed ×1.4, damage ×0.6. On aggro (via `aggroNpc`), if no other live sherri within 400px, spawns a sibling 60px to the side (cap 2 total). Toast: "another one shows up. it has the same haircut." |
| `ranged` | paulie | Maintains 180-260px from player. Throws bottles every 1500ms via the projectile system. 300ms aim-raise telegraph + `*` particle. 20% angle wobble (he misses). Panic-chase 1s if player closes to <120px. |
| `cop` | cop | Default chase-bite + radio-for-backup: at >120px, 25%/s chance to radio in an additional cop within 5s. Cap 4 total (`COP_HARD_CAP`). Brendan does NOT radio. |
| `brendan` | brendan | Unchanged from wave 2 (taser recharge state machine). |
| `priest_fallen` | omalley_fallen | Phase 1 (≥50% HP): ranged-holy — kite 180-280px, throw holy water vials every 1200ms (22 dmg + 1.5s slow). Phase 2 (<50% HP): dasher — charger variant (windup 500ms, lunge ×2.4 speed), lunge applies slow on contact. |

### Projectile system

`projectiles` is a flat array, generic by `kind` ('bottle' | 'holy'). Update loop runs in `updateWorld` after particles: linear motion, wall collision (solid buildings), world-edge despawn, player overlap → `damagePlayer(dmg)` + optional `P.slowT = slowMs`. Pool capped at 40. Render path in `drawAll` after particles, before player. Spawn via `spawnProjectile({x, y, tx, ty, speed, dmg, slowMs, kind, from, wobble})`.

### Boss phases as pattern shifts

**Tony (rank-4 boss):**
- P1 (100-66% HP): default chase-bite. Player learns the fight.
- P2 (66-33% HP): converts `archetype = 'charger'` + spawns 2 sherri swarmer adds. Toast: "tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers."
- P3 (33-0% HP): berserk charger (`n.berserk = true` — windup 400ms, lunge ×3, cooldown 600ms). Toast: "tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up." Boss roar triple-stack on entry.

**Brutus Older (boss 2):**
- P1 (100-50%): charger from start.
- P2 (50-25%): charger + spawns 1 sherri swarmer every 8s as adds. Toast: "he was warming up before."
- P3 (25-0%): berserk + grabber-on-contact (post-lunge contact also applies 500ms stun). Toast: "he doesn't bite anymore.\nhe grabs."

### Status effects (v13 wave 5 additions)

- **Stun** (`P.stunT`): 500ms input lock (movement + SPACE attack + E interact). Triggered by grabber-on-contact or brutus_older P3.
- **Slow** (`P.slowT`): 1500ms ×0.5 movement speed multiplier. Triggered by holy water projectile or fallen priest P2 lunge contact.

Both status timers are ephemeral — never persisted to save.

### Hit-stun

`n.hitStun = 120ms` on every `playerAttack` damage tick. Freezes NPC AI for 120ms. Plus knockback bumped from 6 to 8 px. Makes combat feel chunkier without changing damage numbers.

### Charger vulnerability

`playerAttack` damage gets ×1.25 multiplier when target is `archetype in [charger, charger_older]` AND `chargeState === 'cooldown'`. Rewards good dodging.

---

## FALLEN PRIEST (v13 wave 5)

Side quest `fallen_priest` + transformation of the existing `priest` NPC.

### Trigger paths

1. **Steal path**: priest visits ≥4 + at least 1 steal attempt (the "steal the collection plate" branch). Auto-fires `triggerFallenPriestTransform()` inside `priestDialogue`.
2. **Quest path**: rank ≥3 + church visits (zone-entry counter, debounced edge) ≥3. Fires a one-shot phone call: `"unknown number: 'father o'malley says the church belongs to whoever has the keys. you don't.'"` Quest goes `available`. Player still has to walk back into the church and try to steal to trigger the actual transform (one path of completion).

### Transform

Same NPC entity: `n.id = 'omalley_fallen'`, name `"FATHER O'MALLEY (FALLEN)"`, `archetype = 'priest_fallen'`, HP doubled (160), darker palette tint via `n.color = '#2a1a2a'`. Canonical transform line: `"father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong."`

### Reward

On death: $200 cash pile + `priest_collar` equip-tagged pickup (slot `hat`, cred +2, `wantedDecay: +0.3` — additive multiplier on the `manageCops` decay rate). Achievement `FALLEN`. Quest closes. Toast: `"the church is quiet again.\nthe pews are still wrong."`

### Survival achievement

`OUTRAN_THE_PRIEST`: survive 60 seconds with `n.isOmalleyFallen` alive on the map. Tracked via `state.counters.omalleyFallenSurviveT`.

---

## MAP DEPTH + INTERACTIVE PROPS (v13 wave 6)

### Highway Underpass

Existing underpass zone (1020,240,380,220) gets a finish pass:

- `TILE_PALETTES.underpass` carries `concrete:true` + `oilstain:true` flags. `drawGroundTile` adds longer fracture lines and black oil ellipses (with rainbow sheen).
- `PROPS` adds 4 `tent` entries (varied tarp colors) and 1 `cardsign` next to The Mathematician ("WILL TRADE WORDS FOR MATH").
- `drawUnderpass` renders 3 sodium-orange light patches via additive radial gradients (sin-pulsed). Always-on regardless of day/night.
- First-entry detection in `updateWorld` fires once: canonical echo line `"the air changes.\nyou can hear yourself walk."` + feed post `"under the bridge. the bridge has ears."`. Gated by `state.flags.underpassEntered`. Old saves default to true.

### Scrap Yard depth pass

Existing zone (100,80,520,360). No WORLD expansion. New populates:

- `TILE_PALETTES.scrap` carries `dirt:true` + warmer brown base. `drawGroundTile` adds dirt mottling clumps.
- `PROPS` adds 4 `scrap_pile` (twisted metal + rebar sticks), 2 `car_wreck` (totaled sedan on cinderblocks), 1 `leash_post`, 1 `pay_phone`.
- `scrap_dog` NPC at (580,150), archetype `'passive'` (does not aggro by default). Sprite uses new `PALS.scrap_dog` palette over the existing `makeDog()` shapes.
- `drawDogLeash` renders the chain from `leash_post` to the dog between drawProps and the NPC pass.

### Interactive props system

New parallel array `interactiveProps[]` initialized via `initInteractiveProps()` from `startGame`. Update loop in `updateWorld` ticks cooldowns + bottle respawn.

**Kickable trash cans** — 6 entries, one per major zone. Outcome on E within 50px:
| Roll | Outcome |
|------|---------|
| 0.0-0.5 | cash $2-5 |
| 0.5-0.7 | junk inventory item (sells to Pete for $1) |
| 0.7-0.8 | food inventory item (single-use, feed the dog) |
| 0.8-1.0 | rats particle burst + toast `"the rats are upset. they have lives."` |

60s `cdT` cooldown + 200ms tip rotation + 200ms scale pulse. New `audio.kick()` synth.

**Breakable bottles** — 8 placed at game start from a 16-spot candidate pool (jittered ±20px). Detected by `playerAttack` hitbox. On hit: 12-particle glass burst + 25% chance to drop `broken_bottle` weapon (dmg+8, reach 6, cd 300). 60-120s respawn.

**Dumpster dig loot table** — `startDumpsterDive` was rewritten. Distance-from-block factor `farFactor = min(1, dist/900)` controls the "nothing" cut:

| Loot | Rate (close → far) |
|------|--------------------|
| nothing (rats) | 50% close, 30% far |
| cash $1-4 | 30% |
| junk item | 20% |
| clean packet (`P.supplies += 1`) | 10% |
| broken_bottle weapon | 8% |
| propane torch (no-dupe) | only if `farFactor > 0.6` AND `!hasPropane()` AND `!dumpsterPropaneAwarded`, 7% of fallthrough |

Per-dumpster 90s `diveCdT` cooldown after a dig. Auto-resets `looted` flag via `updateWorld`.

**Public phone** — one `pay_phone` prop in the scrap yard. Ring scheduler in `updateWorld`: 4-8 min between rings, 30s answer window (`state.phonePropRingT`). On E within 38px: random pull from `PUBLIC_PHONE_LINES` (10 cursed lines). Achievement `PHONE_BOOTH_PROPHET` at `publicPhoneAnswered >= 5`. One ~10% line plants a $50 cashPile at (1800,1320) behind the church.

### Procedural graffiti

`GRAFFITI_LINES` (36 voice-coherent fragments, lowercase mundane + occasional shouting-caps for emphasis).

`buildGraffiti` walks every non-locked BUILDING and assigns 12-18 tags to randomly-selected wall faces (bottom / leftside / rightside). Each tag: `{x, y, text, col, rot, sz}`. Persisted in `state.graffiti` (Array of plain objects, serializes cleanly). Re-used on next `drawGraffiti` if already populated.

`drawGraffiti` renders bold 8-10px Courier text with a low-saturation chalk color, -5°/+5° rotation, plus a 0.18-alpha double-pass for the grit feel. Called between `drawBuilding` and `drawProps` in `drawAll`.

### Scrap dog side quest

`state.quests.scrap_dog.state: 'idle' | 'fed' | 'freed' | 'left'`.

| Choice | Effect |
|--------|--------|
| **Feed** | Consumes 1 food item, +1 cred, `state='fed'`. Chained dog stays; creates a 200px cop-discomfort radius (cops + brendan + horsecop at 0.5× speed inside the radius). |
| **Free** | Triggers `startLockpickMini`. Success: dog NPC removed, `state='freed'`, `LIBERATOR` unlocked. Spawns `freed_dog_follower` (isPet:true, archetype:passive) at random intervals 1-3min later; follows ~60s, then wanders off. While follower is present, same 200px cop-discomfort radius applies. First reappear toast: `"the dog is back.\nhe is here.\nfor now."` |
| **Leave** | `state='left'`. No penalty. Dog stays chained, dialogue still accessible. |
| **Attack-while-chained** | One-time `THE_PIECE_OF_SHIT` achievement + permanent -5 cred + `state='left'`. Dog becomes hostile, chain snaps (n.chained=false), speed 1.6 + dmg 6. |

### Food item

`{id:'food', n:'a can of food (unmarked)', q:1}`. Drops 10% from kicked trash cans, sold by Pete at $3, possible dumpster bonus. Single-use (feed the dog). Single-use.

### Achievements (new)

| ID | Trigger |
|----|---------|
| `LIBERATOR` | Free the chained dog via successful lockpick. |
| `THE_PIECE_OF_SHIT` | Attack the chained dog. One-time, permanent -5 cred. |
| `PHONE_BOOTH_PROPHET` | Answer the public phone ≥5 times. Counter persists across NG+. |

### Save backward-compat

- `state.flags.underpassEntered` defaults to true on load (old saves don't re-trigger echo).
- `state.flags.dumpsterPropaneAwarded` defaults false (existing save still gates the rare dumpster drop normally).
- `state.quests.scrap_dog` defaults to `{state:'idle', done:false, available:false}` on missing.
- `state.graffiti` defaults to null on missing; `drawGraffiti` lazily builds + caches.
- `state.publicPhoneAnswered` defaults 0.
- Save key unchanged (`rockbottom_save_v8`).

### Invariants

1. **Save backward-compat.** New saves load forward; old saves don't see the first-entry echo, can't accidentally double-mint propane.
2. **Cop-discomfort radius is geometric, not zone-bound.** Either dog can be anywhere; the 200px radius is real-time.
3. **Chained dog attack penalty is one-time.** Subsequent attacks just damage the dog without re-applying.
4. **Propane no-dupe.** Dumpster propane drop is gated by `!hasPropane() && !dumpsterPropaneAwarded`. Brutus + Pete paths still gated by their existing flags.
5. **Graffiti is persistent.** Once built and saved, the same tags appear on the same walls next session.

---

## KNOWN EXPLOITS (v13 wave 6) — CLOSED in wave 6.5

Operator playtest of wave 6 surfaced three infinite-loop exploits where NPCs hand out cash/items/cred without a daily, cooldown, or cred gate. Wave 6.5 closes all three.

1. **Kombucha lady (Whole Foods Mom / marketplace) — unlimited ask + compliment.** `momDialogue` had three ungated branches (accept $10, ask $20, compliment kombucha +5 cred). Spam-cycle = unlimited money + cred. **CLOSED:** ask-money branch (both $10 and $20 share one slot) once-per-day via `state.counters.kombuchaAskDay`; compliment branch once-per-day via `state.counters.kombuchaComplimentDay`. Consumed branches replaced with VIBE refusal lines ("she remembers because she has nothing else to do" / "she is tired of you").
2. **Tic tacs cure shakes.** `priestDialogue` had `P.shakes = Math.max(0, P.shakes-30)` on accept-the-tic-tac — undercutting the core addiction lever. **CLOSED:** removed the shakes line. Tic tacs now give `+5 brain` (small sober buff). Canonical toast: `"the tic tac is gone. the shakes do not care."` Priest_mercy quest still completes the same way (any acceptance counts).
3. **Barb → Stripe arbitrage.** Buy packets from Barb → cook → fence to Stripe. No daily ceiling on either end. **CLOSED — two-sided gate:**
   - **Stripe** (`state.counters.stripeFencedToday`): first 3 rocks at $6, rocks 4-6 at $4, rocks 7-9 at $2 floor, 10+ closes fence entirely until dawn. Tiered toasts at brackets 4 / 7 / 10.
   - **Barb** (`state.counters.barbPacketsToday`): 6-packet/day cap. Single = 1, bulk = 5. Bulk hidden when remaining < 5 with its own refusal. At cap: "she's tired. come back tomorrow. she has 14 across to think about."

The accumulating counters (`stripeFencedToday`, `barbPacketsToday`, `peteCashToday`, `heistsToday`) reset on the day-tick via `resetDailyCounters()` invoked from `updateWorld` when `state.day` increments. The day-stamp counters (`*Day` fields) self-reset via `=== state.day` comparison and don't need explicit zeroing.

Save backward-compat preserved (new counter fields default to 0 via `Object.assign`; SAVE_KEY unchanged).

**Status (wave 6.5):** CLOSED on all three. See ECONOMY GATES section below.

---

## ECONOMY GATES (v13 wave 6.5)

Comprehensive audit of every NPC / interaction that can grant cash, items, cred, or status. Resource sinks (player pays vendor) are not gated — those are self-limiting by player cash. Only resource GRANTS (vendor pays player or grants cred/items) need gating.

### Daily-gated grants

| NPC / interaction | Grant | Gate | Counter |
|---|---|---|---|
| Whole Foods Mom — accept $10 | +$10 | 1×/day, shared slot with ask $20 | `kombuchaAskDay` |
| Whole Foods Mom — ask $20 | +$20 (40%) or -2 brain | 1×/day, shared with $10 | `kombuchaAskDay` |
| Whole Foods Mom — compliment kombucha | +5 cred | 1×/day | `kombuchaComplimentDay` |
| Father O'Malley — donate $5 | +3 cred + $5 to churchDonations | 1×/day | `priestDonateDay` |
| Father O'Malley — accept tic-tac | +5 brain (was -30 shakes) | none (small grant) | n/a |
| Lurch — give a dollar | -$1, +2 cred (net +2 cred per save day) | 1×/day | `lurchDollarDay` |
| Sherri — pretend to see spider | +1 cred | 1×/day | `sherriSpiderDay` |
| Paulie — compliment the face | +1 cred + paulieCompliments++ | 1×/day | `paulieFaceDay` |
| Stripe — fence rocks | $6 → $4 → $2 → closed | volume-gated (3 / 3 / 3 / +1 cap) | `stripeFencedToday` (max 10) |
| Baggie Barb — buy packets | +1 or +5 supplies | 6 packets/day | `barbPacketsToday` |
| Pawn Shop Pete — sell items | various $ | $200 cash/day cap | `peteCashToday` |
| Abandoned Building — heist | +2-4 copper | 3 heists/day | `heistsToday` |

### Already gated (pre-wave-6.5)

| NPC / interaction | Gate type | Notes |
|---|---|---|
| Tre Bag Tony — buy rock | money sink (player pays) | not a grant |
| Tony — short / boss | one-shot triggers | tonyOffenses-cap, then boss spawn |
| Yuri — sell copper $25 | gated by P.copper supply | copper is gated by heist cap above |
| Pete — buy copper $15 | gated by P.copper + Pete cap | sell-to-Pete also gated by `peteCashToday` |
| Pete — torch sale | one-shot per save | `peteTorchStocked / peteTorchSold` |
| The Conductor — sell 3 copper $90 | gated by P.copper supply | with heist cap = ~$270/day max |
| Father O'Malley — steal plate | RNG ±, wanted+1 on fail, one-trigger fallen-priest path | escalates to mini-boss |
| Brutus / Brutus_older — torch drop | 25% night-only, one-shot via `dumpsterPropaneAwarded` + `hasPropane()` | |
| Dumpster dig — loot table | 90s per-dumpster cooldown (`diveCdT`) | propane no-dupe gate |
| Trash can kick — loot | 60s per-can cooldown (`cdT`) | |
| Public phone — answer | 4-8min ring scheduler, 30s answer window | no cash grant (lore + rare $50 cash-pile plant at fixed spot) |
| Cash piles | one-time per save (`state.cashPilesCollected`) | not respawned |
| Pigeon King — $2 for secret | money sink | not a grant |
| Pigeon Crown — pickup | one-shot per save | quest item |
| Stripe's Package — open / deliver | one-shot per save | mutually-exclusive outcomes |
| Barb's Crossword — return | one-shot per save | +1 free packet |
| Daily hustles | reset on `state.day++` via `rollHustles()` | already daily |
| Possum prophecy | one of 4 micro-effects (+$2 / -3 brain / +1 cred / nothing) | very small grant, kept ungated as flavor |
| Dave — pickpocket $8 | one-shot per save (Dave wakes once, never re-sleeps) | self-gated |
| Big Guy — cart trade | one-shot per save (5 copper for cart) | |
| Karaoke Mike — sing $5 | money sink (player pays into rhythm minigame) | |
| Priest's Son — buy "tic-tac" $10 | money sink (50% rock, 50% nothing) | net negative EV |
| The Mathematician — interaction | pure flavor (no resource grant) | EV oracle only |
| Pinky Polenta — buy packets | INTENTIONALLY UNGATED | the "overflow supply" lane. Barb caps at 6, Pinky stays uncapped as the dirty-but-available alternative. Soap rate × 0.25 (vs Barb's × 0.12) is the trade-off. |
| Cousin Brendan — kill | $30 cash pile, one-time `brendanFirstKill` achievement | wanted-escalation gate |
| Cop kill | +10 cred + 2 wanted | cred grant offset by escalation cost |

### Design notes

- **Pinky stays ungated** by design. Barb is the "patient, capped, cleaner" supply; Pinky is the "always-on, dirty, smaller per-packet" supply. If both were daily-capped, the cook loop dies. The asymmetry IS the system.
- **Heist cap = 3/day** chosen so the Conductor floor caps at ~$270/day (3 × 3-copper bundles × $90 ÷ 3). With Stripe's $6→$0 ladder and Barb's 6-packet ceiling, the daily cash ceiling is bounded and the player needs day rollover to hit higher numbers.
- **Pete cap = $200/day** — high enough to absorb 1-2 successful copper heists' worth of pure copper at his price, low enough that grinding socks ($1 each) for cred is no longer viable.
- **Tic tacs**: shakes are the addiction-lever knob. The tic-tac's job is now FLAVOR + a small sober buff (+5 brain) — the priest is not your harm-reduction clinic.

### Invariants (wave 6.5)

1. **Daily counters reset on day-tick.** `resetDailyCounters()` is called inside the day-increment branch of `updateWorld` before any other day-roll work (weather, hustles).
2. **Day-stamp counters are self-resetting.** `*Day` counters compare `=== state.day`, so when `state.day++` they become stale and the gates open without an explicit reset.
3. **Save backward-compat.** All new counter fields default to 0 via `Object.assign` in load. Old saves don't see consumed gates on first load.
4. **Tic tacs grant no shakes / no rockedT side effects.** The priest's healing branch is brain-only.
5. **Pinky is the deliberate ungated overflow lane.** Do not add a daily cap to Pinky without removing it from Barb (or finding another asymmetry).

---

## CHANGE LOG

| Version | Date | Major changes |
|---------|------|---------------|
| v1 | May 2026 | Menu-driven DnD-style prototype |
| v2 | May 2026 | Top-down Zelda-style canvas game, emoji sprites, real-time combat |
| v3 | May 2026 | Pixel-art player, synth audio, boss fight, cops, rocked-up status, save system, title screen, 3 new zones, 5 new NPCs |
| v12 | May 2026 | Wired copper heist (no rank gate). Baggie Barb vendor. Cooking minigame at the crate. Stripe buys rocks. THE FINISHER quest. Save v9. |
| v13 wave 1 | May 2026 | Housekeeping fork from v12. Dead rank-gate collision skip removed. README, .gitattributes, title refreshed. |
| v13 wave 2 | May 2026 | Sprite parity: Barb gets her own palette; cubscout/jogger/busker/dogwalker get distinct palettes (were rendering with tony's). 3 new NPCs: PINKY POLENTA (rival supply, dirty packets, soap-weighted cook math), THE MATHEMATICIAN (cook-EV oracle, discoverability reveals every 3rd visit), COUSIN BRENDAN (rookie-cop mini-boss with taser recharge state machine). New BUS STOP zone. Achievements: DUE_DEALER_SYSTEM, BADGE_MONEY. New `glasses` accessory for makeNPC. Save key unchanged. |
| v13 wave 3 | May 2026 | Discoverability layer + onboarding chain + 3 side quests + Q-key UI overhaul. New: `state.metVendors` Set with `?` floaters above unmet vendor NPCs; first-day mom phone tip; intro 3-quest chain (intro_remember / intro_tony / intro_smoke) FORCED on new saves that suppresses hustles/events/phone calls until introDone; 3 side quests (pigeon_crown, stripe_package, barb_crossword); hidden `charisma` stat on P (driven by equipment, currently only pigeon_crown=+1) wired into vendor pricing via `vendorPrice(base)` helper used in tony/barb/pinky/stripe; new equipment `pigeon_crown` (-3 cred, +1 charisma); new weapon `knife` (a possible stripe-package outcome); 4 new achievements (HEAD_THAT_WEARS, EXACT_CHANGE, WHAT_S_IN_THE_BOX, SEVEN_ACROSS). New saves start at $0. Save key unchanged. |
| v13 wave 4 | May 2026 | THE HEAT minigame (real-time canvas skill check, 6 outcomes including SOAP-ROCK); parallel `P.soapRocks` FIFO counter (smoked first, silently); 4th cook mode `propane` gated on new `propane_torch` tool (two acquisitions: night-only brutus drop OR pete at rank 3 for $80); 3 new achievements (THE_HEAT_HELD, SOAP_TONGUE, CONTROLLED_BURN). Save key unchanged. |
| v13 wave 5 | May 2026 | Combat depth pass. 5 archetypes (charger / grabber / swarmer / ranged / cop) with distinct patterns dispatched by `n.archetype`. New generic projectile system (`projectiles` array, kinds: bottle, holy). Boss phases reframed as pattern shifts (tony p2 = charger + sherri adds, p3 = berserk; brutus_older p2 = adds every 8s, p3 = grabber-on-contact). FATHER O'MALLEY FALLEN mini-boss + `fallen_priest` quest with two trigger paths (steal OR rank-3 phone call). New equipment `priest_collar` (+2 cred, +0.3 wantedDecay multiplier). 3 new achievements (FALLEN, DODGED_THE_LUNGE, OUTRAN_THE_PRIEST). New player status timers `P.stunT` + `P.slowT`. Cop radio-for-backup (25%/s at >120px, cap 4 cops). Hit-stun 120ms on every NPC damage. Save key unchanged. |
| v13 wave 6 | May 2026 | Map depth pass. Highway Underpass: cracked-concrete tile palette + oil stains, 4 tents, cardboard sign next to The Mathematician, sodium-orange light patches, first-entry echo line. Scrap Yard depth: dirt-brown tile palette, scrap piles, 2 car wrecks, leash post, pay phone. New `scrap_dog` NPC (archetype `passive`, chained, leash render). Interactive props system (`interactiveProps[]` array): 6 kickable trash cans + 8 respawning breakable bottles + 1 pay phone. `startDumpsterDive` rewritten with distance-from-block loot table + rare propane drop (3rd acquisition path). Procedural graffiti rebuild: `GRAFFITI_LINES` (36) + 12-18 persisted tags via `state.graffiti`. `scrap_dog` side quest with 3 branches (feed/free/leave) + cop discomfort radius (200px). New `broken_bottle` weapon + `food` inventory item. 3 new achievements (LIBERATOR, THE_PIECE_OF_SHIT, PHONE_BOOTH_PROPHET). Save key unchanged. |
