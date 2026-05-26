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
| Shakes | 0-100 | Climbs +0.0025/ms passively, +0.05/ms sprinting | At 100, 1.5% chance per tick of 2 damage | bar, red above 70 |
| Cred | 0-∞ | None (losses only from in-game events) | N/A | gates ranks |
| Brain | 0-100 | Decays from drug use and trauma | N/A | currently cosmetic, future: gates dialogue |
| Wanted | 0-3 | -1 every 30 seconds | At 0 = no cops | star icons in HUD |

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
- `locked: true` + `rank < 4` → blocks; `rank >= 4` → passable (heist trigger by E)
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
- **Vendor/peaceful:** Tony, Yuri, Pete, Mom, Possum, Priest, Conductor, Stripe, Pigeon
  - Hitting a peaceful NPC → they go hostile, wanted +1

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
