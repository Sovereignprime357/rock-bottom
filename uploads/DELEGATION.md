# DELEGATION.md — Rock Bottom v4 Backlog

> Tasks for the next agent picking this up. Prioritized. Each task has a SPEC stub. Pick top-down. Don't ship a task without updating its status here.

---

## v3 — SHIPPED ✓

- [x] Top-down canvas game with camera
- [x] WASD/arrows movement, normalized diagonal
- [x] Real-time fist combat (SPACE), 36px hitbox in facing direction
- [x] Pixel-art player sprite, 4 directions × 2 walk frames
- [x] Walk animation (180ms frame swap when moving)
- [x] Web Audio synth SFX (hit, hurt, pickup, coin, rockUp, crash, death, rankUp, dialogue, copSiren, bossRoar, glassBreak)
- [x] 9 zones (Block, Scrap Yard, Pawn, Dealer, Marketplace, Alley, Abandoned, Church, Projects)
- [x] 15 named NPCs (see VIBE.md identity table)
- [x] Hostile NPC AI with zone-based and aggro-based chase
- [x] Wanted level system (0-3 stars) with cop spawning
- [x] Arrest cutscene (lose cash/rocks, keep copper, 0 wanted, +shakes)
- [x] Rocked-up status effect (18s buff + visual + audio)
- [x] Crash status effect (8s debuff following high)
- [x] Multi-phase Tre Bag Tony boss fight (3 phases)
- [x] Copper heist 3-stage mini-game (Abandoned Building, gated at rank 4)
- [x] Persistent save via window.storage with auto-save + event-save
- [x] Title screen with [SPACE] start, [L] load
- [x] Inventory panel (I key) with lifetime stats
- [x] Minimap with player/cop/Tony/boss dots
- [x] Live AI-generated chaos events via Possum (Anthropic API)
- [x] CRT scanlines + flicker aesthetic
- [x] 4 status effect visual treatments (rocked-up gold tint, crash purple haze, hit red flash, low HP heart drain)

---

## v4 — HIGH PRIORITY (ship these first, in order)

### 1. NPC pixel sprites
**Status:** Backlog
**Why:** v3 has pixel-art player but emoji NPCs — visual inconsistency.
**Spec:**
- Convert ALL named NPCs to 16×16 pixel sprites, not just some
- Each NPC gets a unique palette + 1 static front-facing frame (no walk animation, optimization)
- Tony, Yuri, Brutus, Pete, Lurch, Sherri, Paulie, Dave, Mom, Possum, Priest, Conductor, Larry, Stripe, Pigeon, Cop
- Cop sprite should be DIFFERENT enough to read at a glance (blue uniform)
- Brutus is the only 4-legged sprite (different aspect)
- Pigeon should be smaller (12×12 scaled)
- Use the same prerender + draw pattern as the player
**Invariants:**
- All NPC sprites prerendered at init
- No runtime fillRect per pixel
- File size budget: <30KB added
**Estimated effort:** 4-6 hours

### 2. Highway Underpass zone
**Status:** Backlog
**Why:** World feels small. One more zone with a distinct identity.
**Spec:**
- Position: top-center area (1000-1500, 200-500) — squeezed above the abandoned building
- Visual: dim, concrete texture, drawn rebar prop
- New NPC: **THE BIG GUY** — a guy who is big. Tic: tall. Relationship: lives under the underpass. Transaction: will trade his shopping cart (gives +5 inventory cap, +1 speed) for 5 PURE COPPER.
- Random pickup: a single license plate (sells $20 at Pete)
- Ambient SFX: car passing overhead (low rumble every 8s)
**Invariants:**
- Reachable from spawn within 60s of walking
- Does not gate any other zone
**Estimated effort:** 2-3 hours

### 3. Tweaker Vision (hold F)
**Status:** Backlog
**Why:** Adds discovery layer. Rewards exploration with brain cost.
**Spec:**
- Hold F: world overlay tints sickly green for 3 seconds, hidden cash piles become visible
- Costs 5 brain per activation (3s cooldown)
- Hidden cash piles: 15-20 spawned around world at game start in non-obvious spots (behind dumpsters, in corners of zones, near props)
- Visible only during tweaker vision OR by stumbling within 8px
- Each pile = $2-5
- Persist across saves (which piles collected)
**Invariants:**
- Brain can't go below 0 → vision fails with toast "your brain has nothing left to give"
- Toggle off if F released early
**Estimated effort:** 2 hours

### 4. Day/Night Cycle
**Status:** Backlog
**Why:** Time pressure + variety. Different events at different hours.
**Spec:**
- Cycle: 4 minutes (2 min day, 2 min night)
- Visual: canvas-wide tint overlay (warm yellow tint day, dark blue tint night, with sunrise/sunset transitions)
- At night: 
  - +2 random crackheads spawn in alley (Lurch/Sherri/Paulie variants)
  - Possum more likely to appear (3x spawn weight)
  - Pawn shop closed (Pete sleeping inside, dialogue: "we open at 6.")
  - Abandoned building easier (Brutus II asleep, +20% heist success)
- At day:
  - Whole Foods Mom present (only daytime NPC)
  - Cubscout pedestrian walks through marketplace
**Invariants:**
- Cycle pauses during dialogue
- Cycle resumes on game load
- Save includes current cycle position
**Estimated effort:** 3-4 hours

### 5. Quest log UI (Q key)
**Status:** Backlog
**Why:** Without it, players don't know about The Conductor's copper trade, Father O'Malley's tic-tac, etc.
**Spec:**
- Press Q: opens quest panel (same style as inventory)
- 5 starter quests:
  1. "THE FIRST ROCK" — buy a rock from Tony (auto-completes on first purchase)
  2. "THE COPPER SINGS" — strip copper from the abandoned building (auto on first heist)
  3. "THE CONDUCTOR'S BARGAIN" — sell 3 PURE COPPER to The Conductor
  4. "THE PRIEST'S MERCY" — accept a blessed tic-tac from Father O'Malley
  5. "THE FALLEN KING" — defeat Tre Bag Tony in boss fight
- Each quest: title, 1-sentence flavor text, complete checkbox
- Completed quests show with strikethrough
- "All complete" message at bottom when 5/5
- Persists in save
**Invariants:**
- Quests are flavor only, no rewards beyond the actions themselves
- Cannot fail a quest, only complete or ignore
**Estimated effort:** 2 hours

---

## v4 — MEDIUM PRIORITY

### 6. Rideable Shopping Cart
**Status:** Backlog
**Spec:**
- Spawn one rideable shopping cart in marketplace (use 🛒 emoji + special prop type)
- Press E near it: mount/dismount
- While mounted: 1.5× speed, can run over hostile NPCs for damage (8 dmg, knockback), +5 inventory cap
- Loses cart if hit by cop or by NPC attack (cart drops, must remount)
- Cart respawns in marketplace if abandoned for 60s
**Estimated effort:** 3-4 hours

### 7. Boss 2: BRUTUS THE OLDER
**Status:** Backlog
**Spec:**
- Trigger: kill the original Brutus 5 times across runs (counter persists in save)
- Encounter: Brutus returns "ascended" — larger (40×40), red eyes, 200 HP
- Phase 1: chase + bite (high damage, fast)
- Phase 2 (<50%): summons 2 normal puppies as adds
- Phase 3 (<25%): becomes spectral, phases through walls
- Defeat: gives "BRUTUS'S COLLAR" item (+5 max HP permanent)
**Estimated effort:** 4-5 hours

### 8. Boss 3: FATHER O'MALLEY FALLEN
**Status:** Backlog
**Spec:**
- Trigger: steal collection plate 5 times successfully
- Encounter: Father O'Malley turns black-eyed, dialogue shifts to all-caps
- Phase 1: throws blessed tic-tacs as projectiles (small dmg, lots of them)
- Phase 2: summons a "blessed dog" (gold version of Brutus)
- Phase 3: 1v1, brutal
- Defeat: unlocks atheism. The church closes. Father O'Malley becomes a wandering NPC who occasionally apologizes.
**Estimated effort:** 4-5 hours

### 9. Co-op Ending with Stripe
**Status:** Backlog
**Spec:**
- Alternative to defeating Tony as boss
- Trigger: buy 5+ soap rocks from Stripe (proving loyalty by stupidity)
- Stripe approaches player, dialogue: "yo. we should team up. take tony's corner."
- Cutscene: walk to dealer's corner with Stripe alongside
- Tony boss fight triggers but Stripe fights alongside (NPC ally, 80 HP, 12 damage attacks)
- Win condition: same as boss
- Different ending dialogue: "you and stripe split the corner. you get tuesdays and thursdays."
- Title screen now shows two endings unlocked
**Estimated effort:** 5-6 hours

### 10. Mobile touch controls
**Status:** Backlog
**Spec:**
- Detect touch device on load
- Show virtual D-pad bottom-left
- Show A button (attack) bottom-right
- Show B button (interact) above A
- Show menu buttons (I, M, Q) along top right
- Canvas full-screen on mobile
- Don't break desktop keyboard input
**Estimated effort:** 4-5 hours

---

## v4 — POLISH / NICE-TO-HAVE

### 11. Boss music synth track
**Status:** Backlog
**Spec:**
- 16-step looping bassline (synth bass, A minor)
- Plays during boss fight only
- Fades in over 2s, fades out on boss death
- Looped Web Audio buffer or simple sequencer
**Estimated effort:** 3-4 hours

### 12. Per-zone ambient audio
**Status:** Backlog
**Spec:**
- Scrap yard: distant clanging every 6-12s
- Alley: dripping water + distant car horn occasional
- Marketplace: muffled conversation hum
- Church: distant choir hum (single sustained chord)
- Projects: distant siren occasional
- All synthesized, all very quiet
**Estimated effort:** 2-3 hours

### 13. Weather system
**Status:** Backlog
**Spec:**
- 3 weather types: clear, rain, fog
- Random per-day (in-game time)
- Rain: visible falling lines, +shakes rate
- Fog: reduces visibility radius, harder to see NPCs
- Per-zone exception: alley always rains in 1 of 4 cycles
**Estimated effort:** 3-4 hours

### 14. Equipment system
**Status:** Backlog
**Spec:**
- 3 slots: shoes, hat, coat
- Shoes affect speed
- Hat affects cred (random NPCs respect/disrespect based on hat)
- Coat affects damage resistance
- 5-8 items per slot, found as world pickups or bought from Pete
- Cursed items exist (a single crocs gives +20% speed but -50% cred)
**Estimated effort:** 6-8 hours

### 15. New mini-games
**Status:** Backlog
**Spec:**
- **Rhythm panhandling** — press WASD in time with prompts as people walk by, more cash per perfect
- **Timing lockpick** — moving needle, click in green zone for abandoned building entry
- **Dumpster diving** — 3×3 grid of trash, click to flip, find one good item among 8 disgusting ones
**Estimated effort:** 4-6 hours total

### 16. Achievements (cursed accolades)
**Status:** Backlog
**Spec:**
- Track 12-15 achievements
- Examples:
  - "I HAVE SEEN HORRORS" — view 10 unique random events
  - "MAYOR OF 4TH STREET" — defeat all 3 alley crackheads in one run
  - "TONY'S WORST CUSTOMER" — buy 50 rocks
  - "BRUTUS REMEMBERS" — get killed by Brutus 5 times
  - "ECCLESIASTES" — donate $100 total to the church
  - "JUDAS" — steal collection plate AND betray Stripe
- Display in inventory panel (toggleable tab)
**Estimated effort:** 3-4 hours

### 17. New Game+
**Status:** Backlog
**Spec:**
- After defeating boss or hitting CRACK LORD SUPREME, "RESTART AS LEGEND" option appears
- Carries over: cred, lifetime stats, save the title of "crack lord supreme"
- Resets: cash, rocks, inventory, position, dead NPCs
- Adds: harder enemies (1.3× HP), better loot drops, Tony's dialogue changes ("you again."), Possum recognizes you
**Estimated effort:** 3-4 hours

### 18. Procedural graffiti
**Status:** Backlog
**Spec:**
- 20-30 graffiti tags generated at game start, placed on building walls
- Pool of phrases: cursed but mundane ("HONK IF U LOVE PETE," "I LOST A TOOTH HERE," "DON'T TRUST STRIPE," "TONY 4 EVER")
- Some procedural: "[NAME] WAS HERE [YEAR]" with random crackhead names and years 1987-2024
- Rendered as small white/yellow text rotated -10 to +10 degrees
**Estimated effort:** 2-3 hours

---

## v5+ — SPECULATIVE (don't build without operator approval)

- Multiplayer (websocket-based, see-other-players-in-the-same-zone)
- Procedural cities (different layouts per run)
- A second city (different vibe — coastal? desert? both)
- VR mode (lol)
- A real ending where everything makes sense (this would be wrong, do not build)

---

## How to update this file

When you ship a task:
1. Move it from its priority section to the "v3 — SHIPPED" section at top (renamed to vN)
2. Add the actual ship date
3. Add a 1-line "Notes from shipping" if anything changed from spec
4. Update SPEC.md with the new system
5. Update BRAIN.md with the session log
6. If you added NPCs: update VIBE.md identity table
7. If you added sounds: document in SPEC.md sound section

## How to add a new task

1. Pick the priority section (HIGH, MEDIUM, POLISH, v5+)
2. Follow the existing format: title / status / spec (with sub-bullets for behavior and invariants) / estimated effort
3. Be specific. "Add more juice" is not a task. "Add 200ms screen shake on hit (cap 4px translate, ease-out)" is a task.
4. If the task touches an invariant in SPEC.md, call it out explicitly.
