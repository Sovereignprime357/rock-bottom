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
