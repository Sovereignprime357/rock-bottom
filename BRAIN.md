# BRAIN.md — Session continuity log (append-only)

---

## Session 2026-05-26 · v13 wave 6.5 — economy balance pass (SHIPPED)

### WHAT
Three operator-found infinite-loop exploits closed; full audit sweep of every resource-granting NPC; daily reset wiring put in place. ALL edits landed on `rock_bottom_v13.html` (no v14 fork). SAVE_KEY untouched.

### WHAT CHANGED (HIGH LEVEL)

**Exploit 1 — Whole Foods Mom (kombucha lady)** — `momDialogue` (line ~2468). The three productive branches were ungated:
- "accept $10 and pity" (+$10)
- "ask for $20" (40% +$20 / 60% -2 brain)
- "compliment her kombucha" (+5 cred)
Fix: ask-money branches (both share a single slot) gated once-per-day via `state.counters.kombuchaAskDay === state.day`. Compliment branch gated separately via `kombuchaComplimentDay`. Both consumed branches surface VIBE refusal lines ("you've been by. she remembers." / "she is tired of her kombucha. she is tired of you."). Productive toasts append "come back tomorrow."

**Exploit 2 — tic tacs cure shakes** — `priestDialogue` (line ~2534). The accept-tic-tac branch called `P.shakes = Math.max(0, P.shakes-30)` — undercutting the entire withdrawal lever. Fix: removed the shakes line. Replaced with `P.brain = Math.min(100, P.brain+5)` (small sober buff, fits priest-as-not-quite-doctor framing). Canonical toast `"the tic tac is gone. the shakes do not care."` priest_mercy quest still completes on accept. The $5 donation branch was also caught in the audit and gated daily via `priestDonateDay` (was the secondary +3 cred grind once Mom's cash was capped).

**Exploit 3 — Barb / Stripe arbitrage** — `barbDialogue` (line ~2865) + `stripeDialogue` (line ~2648). Two-sided gate:
- **Stripe** (`stripeFencedToday`): rocks 0-3 fence at full ($6), rocks 4-6 at $4, rocks 7-9 at floor $2, rocks 10+ closes fence for the day. Single-rock sell uses the current bracket. Bulk sell runs a while-loop applying per-rock pricing and breaks on close.
- **Barb** (`barbPacketsToday`): 6-packet/day cap. Single = 1, bulk = 5. When remaining < 5, the bulk button is replaced with its own refusal. At cap, both buttons collapse into a single "she is tired" refusal.

Tiered VIBE refusal lines at brackets:
- Stripe rock 4: `"stripe is taking less today. stripe is taking what stripe takes."`
- Stripe rock 7: `"stripe is done. stripe is done with rocks. go away."`
- Stripe rock 10: `"stripe will not buy from you today. tomorrow."`
- Barb at cap: `"she's tired. come back tomorrow. she has 14 across to think about."`
- Barb bulk-impossible: `"she taps the pen. 'i'm not weighing five out tonight. come back tomorrow.'"`

**Audit sweep — additional gates added:**
- `lurchDialogue` (line ~2375): "give a dollar" +2 cred now 1×/day via `lurchDollarDay`. Refusal: `"lurch is full. of dollars. he is staring at the wall. come back tomorrow."`
- `sherriDialogue` (line ~2387): "pretend to see the spider" +1 cred now 1×/day via `sherriSpiderDay`. Refusal: `"sherri's sleeve is already down. the spider is sleeping. come back tomorrow."`
- `paulieDialogue` (line ~2398): "compliment the face" +1 cred now 1×/day via `paulieFaceDay`. Refusal: `"paulie nods. the face is satisfied. the face has been complimented today. come back tomorrow."` (lifetime `pauliCompliments` counter still ticks for the achievement gate at 5.)
- `peteDialogue` (line ~2305): all sell-to-Pete branches gated by a $200/day cash cap via `peteCashToday`. New `tryPay(amount)` helper clips payout when near the cap so the player gets partial money on the last sale that crosses the line, full refusal once empty. Refusal: `"pete is empty. pete is eating. come back tomorrow."` Food sale (sell-to-player) NOT gated — pete spending player money is fine.
- `startHeist` (line ~6928): 3-heist/day cap via `heistsToday`. Closes the conductor-arbitrage path. Refusal dialog: `"the door is half off. there is no air coming out. brutus jr. is awake and watching the door. not tonight."`

**Daily reset wiring** — new helper `resetDailyCounters()` at line ~6927 (just above `startHeist`):
```js
const DAILY_COUNTER_KEYS = [
  'stripeFencedToday', 'barbPacketsToday', 'peteCashToday', 'heistsToday',
];
function resetDailyCounters() {
  for (const k of DAILY_COUNTER_KEYS) state.counters[k] = 0;
}
```
Called from `updateWorld` inside the day-tick branch (line ~4111-4120, after `rollHustles()`). The `*Day` (day-stamp) counters self-reset via `=== state.day` comparison so they don't need explicit zeroing.

**Save backward-compat** — added new counter fields to all 3 init sites:
1. Load `Object.assign` defaults at line ~1434
2. Top-level `state.counters` literal at line ~1597
3. `startGame` fresh-save reset at line ~7381

SAVE_KEY unchanged. Old saves load forward — new fields default to 0 → gates open as if it's day 1.

### DECIDED, REASONING

- **Why a day-stamp pattern (`*Day === state.day`) instead of a boolean reset on day-tick**: cheaper to write (no reset code per counter), more robust (a missed reset can't desync the gate), and reads like English in the gate check. Limitation: only works for "1×/day max" gates. Accumulating gates (Stripe ladder, Barb cap, Pete cap, heist cap) still need explicit reset, hence the `resetDailyCounters()` helper for those 4 counters only.
- **Why Stripe's price ladder steps down rather than a hard cap at the start**: comedy + design. A hard cap ("stripe is done after rock 3") would feel bait-and-switch. Watching the price degrade ($6 → $4 → $2 → closed) communicates the dynamic naturally and pushes the player toward day-rotation. Also lets Mathematician tie a future tip to "stripe gets less per rock today."
- **Why Pete cap = $200 and not lower**: he buys $15/copper, $20/license plate, $1/sock, $1/junk. A successful copper heist nets 8-12 copper = $120-180 at Pete (vs $200-300 at Yuri). $200 means one full Pete-sell of a good heist works; the *second* heist would partially clip. That's the intended pressure.
- **Why heist cap = 3 and not lower**: a player needs the heist to fail occasionally without burning a day. 3 attempts gives ~70%×3 = ~85% chance of at least one success, but also lets a competent player grind copper aggressively early. 4+ would re-enable the conductor grind; 1-2 would feel punishing on lockpick-fail.
- **Why Pinky stays uncapped**: explicit design call. Barb caps; Pinky doesn't. Pinky's dirty packets carry double the soap rate (0.25 vs 0.12), which is the inherent cost. If both were capped, the cook loop dies on bad days. Documented as an invariant.
- **Why tic tac became +5 brain, not zero effect**: zero effect makes the priest's accept branch dead weight — the player would skip it. A small sober buff keeps the priest visit on the loop (priest_mercy quest still wants to fire) but doesn't undercut the addiction lever. Brain is also the cooking-EV input so this is a small cook-prep buff, which is on-theme for the priest as a (failed) caretaker figure.
- **Why donations got pulled into the audit even though they weren't a listed exploit**: cred gates. Once Mom's $5 cred / day is capped, $5 → +3 cred at the church becomes the new infinite cred trickle (player has any source of $5 → grind cred). Daily-capping the donation closes that loop too. The audit pass is doing its job.
- **Why pause for a daily-cap on the food sale at Pete (sell-to-player)**: didn't. Player paying $3 for food is a money sink, not a grant. Only sells-TO-Pete are gated. The Stripe-buys-rock branch ($8 to player) and Big Guy's cart trade are similarly NOT gated — these consume player resources.
- **Why Mom's "$10 ask" and "$20 ask" share a slot rather than each having their own daily**: the brief's wording (`"ask for $10 / $20"` as a single phrase with `/`) plus the structural reading that both are "ask Mom for money today" — semantically one beat. Separate slots would feel like a loophole. The compliment is a different beat (validation, not money), so it gets its own slot.

### COUNTEREXAMPLE HUNT

- Old save (wave 6) loads forward: new counter fields default to 0 via `Object.assign`. `state.day` defaults to 1. Day-stamp checks `0 === 1 → false` so gates are open. ✓
- New save day 1: ask Mom for $10 → `kombuchaAskDay = 1`. Try $20 → button replaced with refusal line. ✓
- New save day 1: compliment Mom → `kombuchaComplimentDay = 1`. Re-open dialogue → compliment button now refusal. Ask-money branch still available. ✓
- Day rollover: `state.day` increments 1 → 2. Mom's `kombuchaAskDay` is still 1; `1 === 2 → false` → branch re-opens. ✓
- Tic tac accept: P.brain goes up 5 (clamped at 100); P.shakes UNCHANGED; P.rockedT UNCHANGED. ✓
- priest_mercy quest: still flips done on first accept regardless of brain max. ✓
- Stripe rocks 0-2 fenced today, sell 1 rock: price `$6`. Counter → 3. Toast no tail. ✓
- Stripe rock 4: counter was 3, fence price = $4, counter → 4, toast carries "stripe is taking less today." ✓
- Stripe bulk-sell with 5 rocks and 0 fenced today: rock 1-3 at $6 ($18), rock 4-5 at $4 ($8). Total $26. After: counter = 5. ✓
- Stripe bulk-sell with 10 rocks and 0 fenced: rocks 1-3 at $6, 4-6 at $4, 7-9 at $2, rock 10 at $2 → counter hits 10 → break. Total: 18+12+6+2=$38. Player has 0 rocks left. Tail toast: "stripe will not buy from you today. tomorrow." ✓
- Stripe bulk-sell with 5 rocks and `stripeFencedToday=9`: rock 1 at $2, counter → 10 → break. Total $2. Player has 4 rocks remaining. Tail: "stripe will not buy from you today." ✓
- Re-open Stripe dialogue with counter = 10: both sell buttons collapse into "(closed today.)" refusal. Buy-from-stripe still works (player paying Stripe is fine). ✓
- Barb buy 1 packet × 6: counter → 6. Re-open: both buy buttons replaced with "she is tired" refusal. ✓
- Barb buy 5-pack on counter=0: counter → 5, remaining=1, single still available, bulk gone next open. ✓
- Barb buy 5-pack on counter=2: would push to 7, but the bulk button is hidden because `remaining=4 < 5`. Single still available (would push counter to 3). ✓
- Pete sell 1 copper with `peteCashToday=190`: tryPay(15) clips to 10. P.copper--, P.cash += 10. Counter → 200. Toast "pete is almost empty." ✓
- Pete sell another copper: tryPay(15) returns 0 → refusal toast, P.copper unchanged. ✓
- Pete sells 5 junk worth $5 with peteCashToday=198: tryPay(5) clips to 2. taken = min(5, 2) = 2. Counter → 200. Player loses 2 junk (not 5), gets $2. ✓
- Heist attempt with heistsToday=3: refusal dialog fires, mode does NOT change. ✓
- Heist attempt with heistsToday=2: increments to 3 inside startHeist, opens stage 1 normally. ✓
- Day rollover during a heist run: heist counter for THAT heist stays at 3 (incremented before dawn). After dawn, counter resets to 0. Doesn't double-bill. ✓
- Lurch / Sherri / Paulie cred grants: each 1×/day, refusal lines on second attempt. paulieCompliments lifetime counter still ticks (achievement gate intact). ✓
- Priest donation $5: 1×/day via priestDonateDay. Repeat tries get the new "the lord has counted today" refusal. ✓
- Mom is at night: existing daytime gate fires first ("she is at the wine bar with kelly"), no new logic touches it. ✓
- Save / reload mid-day: counter values persist via `state.counters` serialization. Reload restores. Gates intact. ✓
- Save / reload across day rollover (player saves, exits, comes back next day): when player returns, state.day is whatever was saved. day-tick must fire to advance. So technically gates DON'T reset on reload alone — they reset on the next dawn after reload. Acceptable behavior.

### TRIED, ABANDONED

- Considered making the kombucha ask-money use two separate counters (one for $10, one for $20). Decided one slot is the right read of the brief (`"ask for $10 / $20"` is one beat). Player picks risk-tier per day.
- Considered making Stripe's fence price degrade with `P.lifetime.rocksFenced` (career counter) instead of daily. Abandoned: punishes long-running saves and never resets. Daily volume is the right axis — the joke is "stripe is having a long day," not "stripe is sick of you forever."
- Considered a single `lastResetDay` sentinel instead of separate `*Day` per counter. Abandoned: the per-counter day-stamp doubles as "was this used today?" — cleaner read at the gate site, no extra state needed.
- Considered making Pinky's house-cut packets also count toward a daily cap (separate from Barb). Abandoned per brief ("recommend: keep Pinky ungated"). Documented as intentional asymmetry.
- Considered gating Dave's $8 pickpocket. Abandoned: Dave wakes up after one pickpocket and never re-sleeps (no `asleep = true` reassignment exists). Self-gated. ✓
- Considered gating Possum's small prophecy effects (+$2 / -3 brain / +1 cred / nothing). Abandoned: each effect is small AND requires the Anthropic API call AND grants are 25% each. Real-life rate-limited by API. The +1 cred is the only grant; capping it would be over-correction.

### NEXT

- Day/night cycle currently 4 minutes (2 day / 2 night). The new daily caps reset every 4 minutes, which means a patient player can still grind by just waiting. Consider whether the day cycle should be longer in a future wave. Operator call.
- The Mom dialogue could use one of the Mathematician's tips: "she gives once a day. ask once. or the loop closes." — would teach the new gate via the existing tip channel.
- Stripe's ladder is currently silent in his idle dialogue — could add a flavor line referencing how much he's bought today ("stripe has done his rocks today" / "stripe is open for business").
- The "intro chain" assumes new saves start at $0 and the player works UP. Verify that the new gates don't break the intro chain (intro_remember = $10 = mom's pity gets them there in 1 ask, which is still legal day 1). Tested implicitly via reading the intro chain code — defaults to false / 0 counters → first interaction works.
- Pete cap at $200 might be tight for late-game heists; could be raised to $300 after telemetry. Watch.

### GOTCHA

- `state.day` must be a NUMBER at all gate sites — load defaults to `sv.day ?? 1`, startGame inits to 1. If a future feature reads `state.day` as a string ("day 7") the `===` check breaks. Don't.
- `resetDailyCounters()` is called from inside `updateWorld`'s day-tick branch. If a future feature triggers a day-rollover from a different code path (debug button, cheat code, etc.), it MUST also call `resetDailyCounters()` or the accumulating counters will desync.
- The `*Day` day-stamp pattern requires `state.day >= 1` always. If a future feature ever sets `state.day = 0` for any reason (boss intro? cutscene?), the gates will appear to reset (since `0 === 0` is true with default 0 counter). Don't.
- Pete's `tryPay()` mutates `state.counters.peteCashToday` directly. If you add a new sell-to-Pete branch, USE `tryPay()` — don't bypass it or you'll silently break the cap.
- Stripe's bulk-sell while-loop increments `state.counters.stripeFencedToday` per rock — if you add a new fence path (e.g. a "fence soap rocks" branch later), it must also increment this counter, otherwise the player has a side channel that's untracked.
- Pinky stays ungated by INVARIANT. Don't add `pinkyPacketsToday` without a corresponding SPEC update + invariant removal.
- The `dayCount` and `state.day` are different things — `P.lifetime.dayCount` tracks lifetime day-rolls (achievement gate at 7), `state.day` is current day number. The gates use `state.day`. Don't confuse them.

---

## Session 2026-05-26 · v13 wave 6 — map depth + scrap yard (SHIPPED)

---

## Session 2026-05-26 · v13 wave 6 — map depth + scrap yard (SHIPPED)

### WHAT
Five-part expansion to v13 widening the map's texture rather than its bounds. Highway Underpass got finished: cracked-concrete TILE_PALETTES entry with oil-stain mottling, 4 tent props, a cardboard sign next to The Mathematician, 3 sodium-orange light patches additively rendered in `drawUnderpass`, and a one-shot first-entry echo line ("the air changes. you can hear yourself walk."). The SCRAP YARD existed already; instead of expanding WORLD, the zone was deepened in place — new dirt-brown TILE_PALETTES entry, scrap_pile + car_wreck + leash_post + pay_phone props, and a chained `scrap_dog` NPC (archetype `passive`) at (580,150). Yuri stayed where he was — he's already in the scrap yard at (300,200). A new `interactiveProps[]` array sits parallel to `PROPS` and carries the kickable trash cans (6, one per zone-ish), respawning breakable bottles, and the dumpster cooldown — its update loop ticks in `updateWorld`. Dumpster dig was rewritten with a distance-from-block loot table that can rarely drop a propane torch (no-dupe gated). One pay phone in the scrap yard rings every 4-8min with one of 10 cursed PUBLIC_PHONE_LINES (one ~10% line plants a $50 cash pile behind the church). Procedural graffiti was rebuilt to use a 36-line GRAFFITI_LINES constant, placed 12-18 tags on building walls at level load, persisted in `state.graffiti`. The chained `scrap_dog` carries a 3-branch dialogue (feed → cop discomfort radius / free → lockpick + wandering follower / leave → no penalty); attacking the chained dog awards `THE_PIECE_OF_SHIT` + -5 cred (one-time). Three new achievements: `LIBERATOR`, `THE_PIECE_OF_SHIT`, `PHONE_BOOTH_PROPHET`. Save key unchanged.

### WHAT CHANGED (HIGH LEVEL)

**Part A — Highway Underpass finish pass**
1. `TILE_PALETTES.underpass` (line ~5026) replaced: lighter base, `concrete:true` + `oilstain:true` flags. New branches in `drawGroundTile` (~line 5102+) render cracked-concrete fracture lines (longer than default) + black ellipse oil stains with iridescent sheen.
2. `PROPS` extended with 4 tents (varied colors) at (1060..1300, 330..400) — non-solid, decorative. New `drawProp` branch for `'tent'` draws triangular tarp + patches + dark opening + ground shadow.
3. Cardboard sign at (1340, 412) next to The Mathematician (he's at 1340,380). Renders as cardboard rectangle with 5px marker text "WILL TRADE / WORDS FOR / MATH".
4. `drawUnderpass` extended with 3 sodium-orange light patches via additive radial gradients (always-on, sin-pulsed). Makes the zone read perpetually dim even in daytime.
5. `state.flags.underpassEntered` boolean. First-entry detection in `updateWorld` fires the canonical echo line and feed post once per save. Old saves default to `true` so they don't re-trigger.

**Part B — Scrap yard depth (no zone expansion needed; the SCRAP YARD already existed at (100,80,520,360))**
1. `TILE_PALETTES.scrap` reworked: warmer dirt-brown base + `dirt:true` flag. `drawGroundTile` adds dirt mottling clumps.
2. `PROPS` extended with 4 scrap_pile entries + 2 car_wreck entries + leash_post at (570,130) + pay_phone at (130,220). New `drawProp` branches for each (twisted metal w/ rebar sticks; totaled sedan on cinderblocks with smashed windows and rust streaks; small wooden post for the leash; rusty pay phone with rings indicator).
3. `scrap_dog` NPC added in `spawnNpcs` at (580,150), archetype `'passive'`, `chained: true`, sprite uses new PALS.scrap_dog (scrappy brown + black) on the existing `makeDog()` shapes (added at `buildSprites`).
4. New `drawDogLeash` renders a zigzag chain from leash_post to the dog, called between `drawProps` and the NPC pass in `drawAll`. While chained the dog has `tailWag` that ramps up when player is within 100px (tick in `updateWorld`).
5. Yuri's "ask about the dog" branch added to his dialogue — three flavor lines tracking the dog's quest state (idle/fed/freed).

**Part C — Interactive props system**
1. New top-level `interactiveProps` array + `initInteractiveProps()` initializer (called from `startGame` after `spawnNpcs`).
2. 6 kickable `trashcan` entries (one per major zone). Player E-press within 50px kicks: 50% cash $2-5, 20% junk item, 10% food item, 20% rats (particle burst + toast). 60s cooldown. 200ms tip rotation + 200ms scale pulse animation. New `audio.kick()` synth.
3. 8 respawning `b_bottle` entries placed at game start, plus respawn from a pool of 16 candidate spots after a 60-120s broken-state. Player attack hit-box detection in `playerAttack` shatters them + 12 glass shard particles. 25% chance to drop a `broken_bottle` weapon (`dmg+8, reach 6, cd 300`).
4. `startDumpsterDive` was rewritten with a distance-from-block loot table: `noneCut = 0.30 + (1-farFactor)*0.20` (close = 50% nothing, far = 30%). Far dumpsters (`farFactor>0.6`) carry a 7%-of-fallthrough chance to drop a propane torch (no-dupe gated via `state.flags.dumpsterPropaneAwarded` + `hasPropane()`). Each dumpster takes a 90s cooldown (`diveCdT`) after a dig — auto-resets via `updateWorld` ticker. New outcome handlers: rats, junkdrop, clean_packet, bb_weapon, torch_drop.
5. One `pay_phone` prop in the scrap yard. Ring scheduler in `updateWorld` (4-8min between rings, 30s answer window). 10 cursed `PUBLIC_PHONE_LINES`. E-press within 38px → `answerPublicPhone()` rolls a random line; `state.publicPhoneAnswered` counter unlocks `PHONE_BOOTH_PROPHET` at 5. The 10% "tell pinky" line plants a $50 `cashPiles` entry at (1800,1320) behind the church.

**Part D — Procedural graffiti**
1. `GRAFFITI_LINES` constant — 36 voice-coherent fragments. Lowercase mundane (e.g. "if you are reading this you owe sherri money", "call mom", "crawdad on hudson"); some capitalized for emphasis (e.g. "BAGGIE BARB CHEATS AT THE CROSSWORD", "BOOK 14 ACROSS IS BLAME").
2. `buildGraffiti` rewritten to walk every non-locked BUILDING and assign 12-18 tags to randomly-selected wall faces (bottom / leftside / rightside). Each tag carries x/y/text/col/rot/sz. Stored in `state.graffiti` so it persists in save (Array of plain objects, serializes cleanly).
3. `drawGraffiti` renders bold low-saturation chalk/spray text with a small (-5°/+5°) rotation + a 0.18-alpha double-pass for the grit feel. Called between `drawBuilding` and `drawProps` in `drawAll` (already wired in v13 — re-used).
4. Save/load: `graffiti` and `publicPhoneAnswered` added to the save object. Old saves with no graffiti get a fresh layout on next render.

**Part E — scrap_dog side quest**
1. `state.quests.scrap_dog` added with `state: 'idle' | 'fed' | 'freed' | 'left'`.
2. `scrapDogDialogue` — three options: feed (consumes 1 food item, +1 cred), free (calls `startLockpickMini` — success kills the chained dog NPC + flips `state='freed'` + unlocks LIBERATOR + schedules first follower reappear in 1-3min), leave (state='left', no penalty).
3. Cop discomfort radius (200px) applied in `updateWorld` whenever the chained dog (fed) OR the wandering follower is present — flags `n.dogSpookSlow = 1` on cops + brendan + horsecop in radius; the default chase-bite branch reads this and multiplies n.speed by 0.5 before clearing the flag at the end of the cop iteration.
4. `spawnFreedDogFollower` spawns a new `freed_dog_follower` NPC (`isPet: true`, `freedFollower: true`) near the player, reuses the existing `n.isPet` follow-at-distance AI. The pet_possum's cash-reveal side effect was gated behind `n.id === 'pet_possum'` so the freed dog doesn't accidentally inherit it. ~60s follow window via `state.freedDogFollowT`. After despawn, next return 1.5-4.5min later.
5. Attacking the chained dog (player swing connects, `n.id === 'scrap_dog' && n.chained`) — quest state flips to 'left', `THE_PIECE_OF_SHIT` unlocked one-time, -5 cred, dog becomes hostile (chain snaps visually — `n.chained=false` removes the leash render), gets speed 1.6 + dmg 6.
6. New `food` inventory item — drops 10% from kicked cans, sold by Pete for $3, also a possible dumpster bonus (junk + food).

### DECIDED, REASONING

- **Why not expand WORLD bounds**: the SCRAP YARD already existed at (100,80,520,360). The brief authorized expansion if needed, but adding props in-place is cleaner — no camera/minimap math touch needed. Documented as a judgment call.
- **Why the scrap_dog uses archetype 'passive' (a new string) not 'default'**: passive is documentation, not behavior — the dispatch falls through to default chase-bite, but the string communicates intent ("does not aggro by default"). Future audits searching for `archetype==='passive'` will find this NPC.
- **Why graffiti goes through state.graffiti not a module-level cache**: persistence. Wave 3 added the discoverability layer based on save state; graffiti is the same instinct — the world should feel the same on reload. Old saves get a one-time fresh layout (acceptable).
- **Why dumpsters use distance-from-block bias not zone-bias**: distance is continuous; zones are discrete. A dumpster on the edge of THE BLOCK shouldn't suddenly become a huge loot pinata. Linear distance falls off cleanly and keeps the math one variable.
- **Why the dumpster propane is gated by `dumpsterPropaneAwarded`**: existing brutus night-drop + pete-rank-3 paths already exist for the propane torch; the dumpster path is the THIRD acquisition route. Without the gate a dedicated digger could chain-dig the torch. Once-per-save.
- **Why the public phone "plant" line plants a real cashPile rather than something more fancy**: cashPiles already render + collect cleanly; piggybacking is the smallest possible delta. The pile is intentionally NOT marked `intro:true` so it's gated by proximity / tweaker-vision like normal piles — discovery is the gameplay.
- **Why 36 GRAFFITI_LINES not 30**: the brief said 30-40. 36 lands in the sweet spot — wide enough that repeat tags across a build feel coincidental.
- **Why `n.isPet` reused for the freed dog follower**: the follow-at-distance AI was already tested and tuned. Wrapping the cash-reveal side effect in `n.id === 'pet_possum'` was a one-line gate. Cheaper than building a new follower system.
- **Why the chained-dog attack triggers a one-time achievement with permanent cred penalty**: the brief explicitly called for this. The achievement label IS the moral commentary ("there is a piece of shit out there. it is you."). No need to soften it.

### TRIED, ABANDONED

- Considered adding the scrap_dog with a `wantedDecay`-style flag that lowers player wanted while in radius. Abandoned: cop discomfort already does the same job geometrically (cops at half speed = effective wanted decay) without polluting more equipment math.
- Considered making each kickable trash can a unique entity with per-zone flavor (alley can spits roaches, market can spits orange peels). Abandoned: tone overrun. Three outcomes (cash/junk/rats) sells the joke without bloating the loot table.
- Considered separate cooldown buckets per dumpster vs global garbage truck reset. Kept BOTH — per-dumpster `diveCdT` (90s) + the existing `garbageTruckRumble` global reset. Garbage truck overrides the cooldown; per-dumpster cooldown handles repeat digs of the same can within one day.
- Considered making the public phone show the toast through the existing `ringPhone` channel. Abandoned: that channel routes through the phoneState/feed display which doesn't fit a "public booth" vibe. Bespoke `answerPublicPhone()` keeps the public-booth call distinct from the cell-phone calls.

### COUNTEREXAMPLE HUNT

- Old save (v13 wave 5) loads forward: `state.flags.underpassEntered` defaults to true on load → no spurious first-entry toast. ✓
- `state.quests.scrap_dog` survives `Object.assign({}, state.quests, sv.quests||{})` because in-memory defaults are merged first. Old saves missing the quest get the default `{state:'idle'}`. ✓
- New save: scrap_dog starts at 'idle', dialogue offers all 3 options. ✓
- Feed the dog with no food: option is `disabled: !P.inventory.find(i=>i.id==='food')`. ✓
- Free the dog → lockpick succeeds: dog dies (NPC removed from npcs), state='freed', LIBERATOR unlocks, freedDogT = 60000-180000ms. ✓
- Freed dog follower spawns: passes `npcs.find(n=>n.id==='freed_dog_follower')` guard so no duplicates. Disappears after 60s via `state.freedDogFollowT`. ✓
- Attack chained dog: one-time THE_PIECE_OF_SHIT + -5 cred; subsequent attacks just damage the dog without re-applying penalty (guard: `!state.achievements.has('the_piece_of_shit')`). ✓
- Pete sells food at $3 once player has $3: button enables, item lands in inventory. ✓
- Kickable can on cooldown: shows "the can is empty" toast, no double-trigger. ✓
- Breakable bottle on respawn: pool of 16 candidate spots, jittered ±20px. Same bottle can respawn at the same spot — fine, decorative. ✓
- Dumpster dig propane drop, no-dupe: gated by `!hasPropane() && !state.flags.dumpsterPropaneAwarded`. After award, the flag stays. ✓
- Public phone "tell pinky" plant fires twice (player answers two phones, both roll the 10% line): both plant a cash pile with unique `id: 'cp_phone_church_'+Date.now()`. No dedup, but each pile is independently collectable. Acceptable. ✓
- Fed dog cop-discomfort radius: cop in radius gets `dogSpookSlow=1` set in `updateWorld`, read in default chase-bite (×0.5), cleared at end of branch. Re-set every frame from updateWorld → continuous effect. ✓
- Freed dog (wandering follower) carries the same radius. ✓
- Graffiti renders for an existing save: `state.graffiti` is null on first load forward, `drawGraffiti` calls `buildGraffiti` which lazily builds + caches in state. Next save persists the layout. ✓
- PUBLIC_PHONE_LINES "tell pinky" plant when the church has already had a pile collected at that exact spot: the new pile uses a fresh unique id, so it doesn't collide. ✓

### NEXT
- Boss music (v4 backlog #11) still untouched — wave 6 didn't address it.
- Day/night cycle's effect on the public phone (different lines at night?) is unexplored — could be a follow-up.
- The Mathematician now has a cardboard sign visible from outside but his dialogue doesn't reference it. A one-line "the sign says what i do" branch would be cheap.
- The `food` item is single-use (feed the dog). Could be eaten for HP if no dog available. Speculative.

### GOTCHA
- `state.graffiti` is an Array of plain objects on disk and in memory — serializes fine. Don't switch it to a Set.
- The chained dog's `tailWag` field is ephemeral (not saved). On reload, the player has to approach again to re-trigger.
- `state.publicPhoneT` is NOT saved — it resets to 4-8min on each load. Means a player can't strategy-cheese the phone by save-scumming. Intentional.
- The freed dog follower NPC is appended to `npcs[]` at spawn time. If you save while a follower is present, the follower IS saved (npcs.dead filter doesn't catch it). On reload, the follower will be standing wherever it was, with no follow timer. Edge case — acceptable since followers are short-lived and the comedy still lands.
- `audio.kick()` is a short percussive thump; if you add a new audio cue with similar parameters, give it a distinct name to avoid the existing dispatchers.
- The `state.publicPhoneAnswered` counter is global across the campaign (not per-save). On NG+ it persists. Intentional — PHONE_BOOTH_PROPHET should stick.

---

## Session 2026-05-26 · v13 wave 4 · the heat minigame + soap-rock loop + propane

### WHAT
Replaced the v12-era dialogue-driven cook with a real-time canvas skill check (THE HEAT). Five outcomes (PERFECT / OK / BAD / BURN / UNDERCOOK / SOAP-ROCK) gate the existing yield + soap math instead of replacing it. Added a parallel `P.soapRocks` counter that smokes first and silently — the canonical "you knew. you smoked it anyway." Introduced the 4th cook mode (`propane`) gated on a new `EQUIPMENT.propane_torch` (slot: `tool`). Two acquisition paths: 25% night-only drop from BRUTUS / BRUTUS THE OLDER, OR Pete pawn-shop stock at rank ≥ 3 for $80, one-and-done. Three new achievements (THE HEAT HELD / SOAP TONGUE / CONTROLLED BURN). Save key unchanged. Existing saves load forward — `soapRocks` defaults to 0, `equip.tool` defaults to null.

### WHY
1. **Cook needed teeth.** v12's `doCook` was four dialogue options with hidden RNG — players reported it felt like "press a button, get rocks." A real-time skill check makes the brain modulation (`bb` factor) and rocked-up penalty *visible* — the sweet-spot bar literally shrinks. Same math, now legible.
2. **Soap-rocks needed a loop.** v12's 12% soap-on-cook just pushed `{id:'soap'}` into inventory as a flavor item. The brief asked for soap rocks that *behave* like rocks until you smoke them. A parallel FIFO counter (`P.soapRocks`) — indistinguishable in the HUD — turns the failure path into a comedic mid-loop beat instead of an inventory pellet.
3. **Propane is the prestige tool.** A 4th cook mode with the tightest sweet-spot + biggest yield needed a *unique* acquisition story. Pete's pawn at $80 is the "i earned this" path; the 25% night-Brutus drop is the "i found this in the dark" path. Both feed the same equip slot. The kitchen tool, not a fit — it gives no speed/cred/hp.

### WHAT CHANGED

1. **`COOK_MODES` table (line 2631)** — 5 modes (`slow / fast / shakes / all / propane`) parameterized by `fillMs / sweetCenter / sweetSpread / baseWidth / burnZone`. Propane is the only mode with a wider burn zone (0.15 vs 0.08) — high reward, high risk.
2. **`startHeatMini(n, mode)` at line 2685** — opens `state.heat` with a 3-phase state machine (`fill` → `idle` (1s grace) → `hold` (600ms reveal)), pre-computes sweet-spot center (jittered ±spread) and half-width (`baseWidth + bb*0.10`, rocked penalty -0.06, clamp [0.05, 0.40]). Sets `state.mode = 'cookmini'`. Plays `audio.dialogue` as start cue. Closes any active dialogue first (cookBatchMenu opened one).
3. **`updateHeatMini(dt)` at line 2716** — called from the main loop only when `state.mode === 'cookmini'` (line 3373). Fill phase ramps `progress 0→1`; idle phase counts down 1000ms then auto-burns at `progress=1.0`; hold phase counts down 600ms then calls `finalizeHeatMini`.
4. **`lockHeatMini()` at line 2738** — bound to SPACE / 1 / Enter (keydown, line 5621-5626) AND `pointerdown` / `touchstart` on the canvas (mobile, line 5892-5899). Snaps `lockedAt = progress`, transitions to `hold`, calls `resolveHeatOutcome`, plays an outcome-specific cue (coin/pickup/hurt/glassBreak).
5. **`bailHeatMini()` at line 2752** — ESC during minigame. Supplies + dirty consumed, zero rocks, dedicated walked-away toast. The crate is patient.
6. **`resolveHeatOutcome(h)` at line 2767** — pure function. Distance `d = |x - center|`. Pre-emptive lock < 0.25 outside sweet = undercook. Top burn-zone = burn. `d ≤ halfW` = perfect; `≤ halfW × 1.8` = ok; `≤ halfW × 3.0` = bad. Far miss + cold lock (`x < 0.20`) = undercook; otherwise 15% soap-rock, else bad.
7. **`applyCookOutcome(n, mode, outcome)` at line 2795** — 4 branches (burn / undercook / soaprock / perfect-ok-bad). The bb-brain math + dirty-packet weighting + per-mode yield/burn rolls are **preserved verbatim from v12/v13 wave 2**, then multiplied by outcome modifiers (perfect: yield × 1.15 + soap × 0.70; bad: yield × 0.60 floor + soap × 1.50). Propane gets a flat × 1.30 yield bonus before outcome mult. Soap rate is the same weighted average `(dirtyUsed*0.25 + cleanUsed*0.12)/n`, now scaled by `soapAdjust`.
8. **`drawHeatMini()` at line 2933** — canvas overlay panel (480×240, dirty cream on dark slab), bar with blue→green→yellow→red→black gradient, sweet-spot region highlighted (raised + white tick above), red burn-zone bracket at top, dirty cream needle, gold locked-in marker. Outcome label renders 18px during hold phase, color-coded (gold/maroon/violet/cream).
9. **`drawSmokeOverlay()` at line 3033** — 2s post-burn full-screen gray haze with 6 sin-walked smudges. Renders regardless of mode (countdown runs in main loop at line 3377).
10. **`hasPropane()` helper at line 2639** — single source of truth: `P.equip.tool === 'propane_torch'`. Used by `cookBatchMenu` to gate the 5th option AND by `onNpcDeath` to skip dupe drops AND by `peteDialogue` to gate the buy/ask-again branch.
11. **`cookBatchMenu()` rewrite at line 2641** — same 4 options as v13 wave 2 (slow/fast/shakes/all), now each routes to `startHeatMini(n, mode)` instead of `doCook(mode, n)`. Conditionally appends propane option when `hasPropane()`. Adds a contextual flavor `predictor` line via `pickHeatPredictor(brain, rocked, dirty)` — 8 outcomes covering rocked+dirty / rocked / sober+clean / sober+dirty / zonked+dirty / zonked / dirty / default.
12. **`pickHeatPredictor()` at line 2672** — the in-dialogue tells. "rocked + dirty → good luck." / "rocked → hands aren't yours. the bar shrinks." / "sober + clean → wider sweet spot." / "sober. but pinky in the bag. the cut argues with the math." / "zonked + dirty → the smoke writes its own ending." / "zonked → narrow window. read the needle." / "dirty packets first. soap is louder." / "the heat is the heat. the needle is the needle."
13. **`P.soapRocks` counter** — added to player init (line 1340), save (line 1253), load (line 1285). HUD reads `🪨 ${(P.rocks||0) + (P.soapRocks||0)}` (lines 1507, 3970) — soap is invisible in inventory.
14. **`blockMenu` smoke branch at line 5440-5471** — `totalRocks = rocks + soapRocks`. When player smokes and `soapRocks > 0`, FIFO branch fires: decrement `soapRocks`, increment `rocksSmoked` lifetime, play `audio.hurt()` + `audio.glassBreak()` (the cursed combo — chiptune for "you fucked up"), toast the canonical line, feed post, unlock SOAP_TONGUE, complete intro_smoke if active (the loop is the loop). Real rocks branch is unchanged.
15. **`EQUIPMENT.propane_torch` at line 381** — `slot: 'tool'`, all stat mods zero. New `tool` slot added to `P.equip` and to the load defaults: `Object.assign({ shoes:null, hat:null, coat:null, tool:null }, P.equip || {})` (line 1284).
16. **Brutus drop at line 3216-3225** — in `onNpcDeath`, after the `brutus_older` and `brutus` death handlers, a single guarded block: `isNight() && !hasPropane() && Math.random() < 0.25`. Pushes a `cashPiles` entry with `tool: 'propane_torch'` field and `amt: 0`. Dedicated toast: "something falls off his collar.\nit smells like a parking lot."
17. **Cash-pile branches at line 3631-3642 (pickup) and 4047-4059 (render)** — pickup branch: when `c.tool === 'propane_torch'` and `!hasPropane()`, sets `P.equip.tool = 'propane_torch'`, calls `applyEquipStats()`, pickup sfx, equip toast. Render branch: always-visible regardless of tweaker vision (a night Brutus drop in the dark would be too punishing to gate), brass body + valve + sin-pulsed pilot flame.
18. **`peteDialogue` at line 1982-2024** — gates on `P.rank >= 3` flipping `state.flags.peteTorchStocked = true` on dialogue open. Buy branch checks `peteTorchStocked && !peteTorchSold && !hasPropane()`. On purchase: -$80, equip, `peteTorchSold = true`, feed post. Post-sale branch shows "ask about the torch again." with a "sold the one. go find your own." reply.
19. **3 new achievements (lines 450-453)** — `the_heat_held` (perfect a cook), `soap_tongue` (smoke a soap rock), `controlled_burn` (survive a burn).
20. **SPEC.md update (line 56-120)** — full COOKING section: 5-mode table with all parameters, outcome trigger/modifier table, base yield math table per mode, soap-rock + propane subsections, invariants. The bb/dirty math is restated for the record since it carries over.

### DECIDED, REASONING

- **Why preserve v12's per-packet roll math under the new outcome wrapper, not redesign yield from scratch**: the original economy is well-tuned. Existing saves have rocked-up loops built around the slow/fast yield curves. A redesign would invalidate player intuition. The cleaner refactor is "outcome multiplies the existing math" — the bb factor still matters, the dirty soap rate still matters, just gated by a skill check now.
- **Why `idleAfterFill = 1000ms` not auto-burn-at-fill**: a 0ms grace would feel punishing for new players who hesitate. 1s gives the player one beat to read the needle and tap. Past 1s, you let it burn — and CONTROLLED_BURN unlocks anyway, so it's not pure punishment.
- **Why 600ms hold phase (the outcome reveal)**: long enough to read the colored outcome label, short enough that the player doesn't get bored. Matches the dialogue close cadence elsewhere in the game.
- **Why parallel `P.soapRocks` scalar instead of tagging individual rocks**: the HUD is one number. Two scalars with FIFO smoke ordering preserves that. Tagging individual rocks would require either an array of rock objects (heavy refactor) or a tag list (sync nightmare with `P.rocks`). The scalar pair is the smallest change that delivers the comedic invariant: "you can't tell from the inventory."
- **Why soap rocks burn FIRST (FIFO) not LAST or random**: comedy. The player notices on smoke #1. If soap burned last the player would never know the batch was tainted. If random, the cursed feeling is diffuse. FIFO makes the failure crisp and immediate.
- **Why `audio.hurt() + audio.glassBreak()` on soap smoke, not a dedicated synth**: matches v12's "cursed combo" idiom for failure-but-not-death. A new synth would have to communicate "you knew" — better to recycle the existing two-tone cue.
- **Why the propane torch grants no speed/cred/hp**: it's a kitchen tool. Stacking stat bonuses on it would make it a *strictly better* hat/coat/shoe at $80, breaking the equipment economy. Zero stats = pure cook unlock. The yield × 1.30 + tightest sweet spot is the reward.
- **Why pete stocks the torch at rank 3 not earlier**: rank 3 = $50 cred = "strip-mall fiend" — the player has cooked enough to want the upgrade. Earlier and it'd feel premature. Later and the slow/fast/all loop has already converged.
- **Why the brutus drop is night-only**: the propane torch has a "found-in-the-dark" identity. Day Brutus drops feel ordinary. Night Brutus + 25% rare drop + the cash-pile toast ("smells like a parking lot") sells the "this fell off something disreputable" framing.
- **Why ESC bails (not auto-undercooks)**: the player needs an escape hatch for a misclick. Supplies still consumed = no exploit (you can't dodge a bad bar to retry). Walked-away toast + feed post = comedic acknowledgment.
- **Why `state.smokeT` countdown runs regardless of mode (line 3377)**: the overlay should keep fading even if the player opens an inventory panel mid-haze. Tied to the global update loop, not the cookmini phase.

### TRIED, ABANDONED

- Considered making the needle bounce back-and-forth (pong-style) instead of one-shot fill. Abandoned: bounce gives infinite re-tries which kills the tension. One-shot lock = one commitment.
- Considered putting soap rocks in `P.inventory` with an id like `'rock_soap'`. Abandoned: the HUD shows `P.rocks` not inventory rock-count, and `blockMenu` reads `P.rocks` for the smoke gate. Two scalars (`rocks` / `soapRocks`) is the smallest delta.
- Considered making propane a *consumable* (gas runs out, refill at pete). Abandoned: the equipment slot pattern is "permanent unlock." A consumable would need a new system (gas meter, refill UI, depletion math). The torch is a tool, not ammo.
- Considered showing a soap-rock count *somewhere* (inventory panel? a debug toast?). Abandoned: the joke requires concealment. Reveal would make the player game it ("oh I have 3 soap, smoke them last").
- Considered a sweet-spot that *moves* during the fill (oscillates). Abandoned: the sweet-spot jitter at start (±spread) already adds replay variance. A moving spot would make `shakes` mode unplayable.
- Considered gating the propane mode behind a cook-count milestone (e.g. "cook 20 rocks unlocks it"). Abandoned: gating by item is more legible — you can *see* the torch in your equip panel. A milestone gate is invisible.

### COUNTEREXAMPLE HUNT

- v13 wave 3 save loads into wave 4: `P.soapRocks = Math.max(0, P.soapRocks||0)` defaults to 0; `P.equip.tool` defaults to null via `Object.assign({...tool:null}, ...)`. Old saves carry no torch, no soap rocks. ✓
- Cook with 0 brain (zonked, no rocked): `bb = clamp((0-30)/70, -0.4, 0.6) = -0.4`. Slow width = `0.22 + (-0.4)*0.10 = 0.18`. Clamped above 0.05. Still playable, just hard. ✓
- Cook while rocked + zonked: `width = 0.18 - 0.06 = 0.12`. Floor clamp still passes. Hardest legitimate state. ✓
- Cook propane while sober (brain=100, no rocked): `bb = 0.6`. Width = `0.08 + 0.06 = 0.14`. Still narrow, still tighter than fast cook. Propane stays the *tightest* mode regardless of brain. ✓
- ESC during the minigame: supplies + dirty consumed (dirty floor at 0). `state.heat = null`. mode reverts to `'playing'`. Save fires. Re-entering `cookBatchMenu` shows the new supplies count. ✓
- Lock at exact sweet center: `d=0 ≤ halfW` → perfect. THE_HEAT_HELD unlocks first time. ✓
- Lock at progress=0.05 (very early, far from center): `x < 0.25 && d > halfW` → undercook. Zero rocks. ✓
- No input at all, bar fills to 1.0: `idle` phase counts down 1000ms then `lockedAt = 1.0` → top burn-zone → burn. Toast + smoke overlay + CONTROLLED_BURN unlock. ✓
- Soap rock generated (15% on far miss): `P.soapRocks += rocks`. HUD `🪨` increments. Player smokes → soap branch fires first → toast → SOAP_TONGUE. ✓
- Smoke with rocks=0, soapRocks=2: gate is `totalRocks > 0`, button enabled, soap branch fires. ✓
- Smoke with rocks=2, soapRocks=2: FIFO — soap goes first (twice), then real rocks. ✓
- Intro player who happens to soap-rock-cook before intro_smoke: soap branch calls `completeIntroSmoke()` regardless. Player still progresses. The loop is the loop. ✓
- Brutus dies during day: `isNight()` returns false. No torch pile. ✓
- Brutus dies at night, player already has torch: `hasPropane()` returns true. Skip. No dupe. ✓
- Brutus dies at night, RNG fails 25%: no pile. Standard cred + cash drops only. ✓
- Pete dialogue at rank 2: torch branch gated off. Standard pete options only. ✓
- Pete dialogue at rank 3, first open: `peteTorchStocked = true` flips. Buy option appears. ✓
- Pete buy at $79: button disabled label "the propane torch is $80. you don't have it." ✓
- Pete buy succeeds: `peteTorchSold = true`. Re-open dialogue → "ask about the torch again." → "sold the one. go find your own." ✓
- Player buys from pete THEN gets a brutus drop: pickup checks `!hasPropane()`, skips. No second torch in inventory. The pile still consumes from `cashPiles` (collected=true) so it doesn't re-trigger. ✓
- Player picks up brutus drop THEN visits pete at rank 3: `peteTorchStocked` flips but buy branch checks `!hasPropane()` and falls through to "ask about the torch again." ✓
- Cook 5 packets with 3 dirty: `dirtyUsed=3, cleanUsed=2`. baseRate = `(3*0.25 + 2*0.12)/5 = 0.198`. Perfect outcome: soapAdjust=0.70 → 0.139. Bad: 1.50 → 0.297. Math survives. ✓
- Cook propane (n=1) perfect: rocks rolled, × 1.30 propane bonus, × 1.15 perfect multiplier, soap rate 0.12 × 0.70 = 0.084 chance of soap. ✓
- Save during cookmini phase: `state.heat` is not serialized — re-loading drops you back into `'playing'` mode with no minigame in flight. Supplies match whatever was true at last `saveGame()` call. (cookmini state is ephemeral by design.) ✓
- Audio not initialized yet (first interaction was the smoke action): `audio.dialogue` is wrapped in `if (audio && audio.dialogue)`. Falls through silently. ✓

### NEXT

- The minigame visualization is functional but could use polish: a brief tutorial pulse the first time `cookmini` opens for a new save (one-shot, `state.flags.heatTutorialShown`). Currently the helper line at the bottom carries the load.
- Boss music (v4 backlog #11) still untouched. The heat minigame would actually benefit from a tense looping bassline during the `fill` phase.
- The "ask the mathematician about the heat" path is unwritten — Math's dialogue could add a 6th tip that reveals the sweet-spot center math. Speculative.
- Stripe's fence does NOT touch `P.soapRocks` (per spec — "Stripe does not fence soap rocks"). Possible micro-feature: a single dialogue branch where stripe sniffs a soap rock and laughs. Pure flavor.
- Watch for the propane mode becoming dominant once the player owns the torch. If late-game telemetry shows >80% propane cook rate, consider reducing the × 1.30 yield bonus to × 1.15.

### GOTCHA

- `state.heat` is NOT in the save schema. If a player saves mid-cook, reload drops them at `'playing'` mode with supplies in whatever state `saveGame()` last persisted them. We don't call `saveGame()` from inside the minigame loop — only on resolve/bail. This is intentional. Don't add a save-mid-minigame.
- The propane torch pickup branches exist in TWO places (line 3631 auto-collect, line 4047 render). If you add a third tool item, both branches need updates. Consider extracting a `TOOL_PICKUPS` registry if a 2nd tool ever lands.
- `audio.dialogue` is called inside `startHeatMini` as the start cue — it's the same SFX used for menu open. Don't "fix" this to a new synth without also updating the dialogue-open call site (they share intent: a soft attention pull).
- `state.smokeT` decay runs in the main loop, not gated by mode. If you add a new mode that *should* pause the smoke (e.g. a fullscreen menu), wrap the decrement at line 3377.
- The HUD line `(P.rocks||0) + (P.soapRocks||0)` appears at lines 1507 (inventory panel) and 3970 (HUD bar). Both must agree. Don't change one without the other.
- `bailHeatMini` consumes supplies but does NOT play `audio.glassBreak` — soft exit. If a player wants a louder "i quit" feedback, that'd be a follow-up.
- The minigame uses SPACE for both lock AND the title-screen-start. The mode check at line 5621 (`state.mode === 'cookmini'`) short-circuits before the global hotkeys. Don't reorder the keydown branches.
- `hasPropane()` returns truthy on `P.equip.tool === 'propane_torch'`. If a future tool slot equips something else (a lighter? a butane refill?), `hasPropane` would still return false correctly — but the cook menu propane branch ONLY tests `hasPropane()`. New tools won't accidentally unlock propane mode.

---

## Session 2026-05-26 · v13 wave 3 · discoverability + onboarding + side quests

### WHAT
Closed v13 wave 3 in one pass: vendor discoverability layer (the "?" floater + people-met index), a forced 3-quest "the day you arrived" intro chain on new saves (with hustle/event/phone suppression until done), the mom first-day phone tip, three NPC-offered side quests (pigeon_crown, stripe_package, barb_crossword), a hidden `charisma` stat plumbed through vendor pricing, a Q-key UI overhaul with quest-status tri-state and reward previews, 4 new achievements, the pigeon_crown cursed hat, and the `knife` weapon (a possible package-open outcome). Save key unchanged. Existing saves load as `introDone = true` and skip the intro.

### WHY
1. **Discoverability layer** — the world was content-dense but unmarked. Players have been finishing playthroughs without meeting half the vendors. The "?" floater + people-met index is the lowest-vibe-cost solution: no tutorial UI, no quest pointer, just one bobbing question mark per unmet vendor. It fades on first dialogue, never to return. The people-met index in Q reinforces the "you remember who you met" framing — Disco-Elysium-style notebook, not GameFAQs.
2. **Intro chain** — new players land at THE BLOCK with no idea what to do. The 3-quest chain (find $10 → meet tony → smoke a rock) is the canonical loop in miniature. Suppressing hustles/events/phone during the chain keeps day 1 focused. Once intro_smoke fires, the whole world opens up.
3. **Side quests** — `state.quests` had 6 entries but only 2 had real bespoke content (FINISHER, FALLEN_KING). The 3 new side quests give the late-mid game (when hustles repeat and the cook loop converges) actual story-shaped hooks. Each is gated on dialogue visit count so they emerge naturally as the player explores.
4. **Charisma** — the brief asked for a hidden stat. Tying it to a single equipment piece (the cursed crown) keeps the math simple: 0 charisma is normal, 1+ is "you wear the crown, you pay less, you eat the cred hit." Future equipment can layer in without redesign.

### WHAT CHANGED

1. **`VENDOR_FLOATER_IDS` / `VENDOR_INDEX_META`** — canonical 13-id list of vendors that get the "?" floater and appear in the people-met index. Excludes ambient pedestrians (cubscout/jogger/busker/dogwalker), dave (steal target), and pure flavor NPCs (possum, pigeon, phoneguy, pothole, etc.). The exact list is from the brief; lurch/sherri are intentionally omitted.
2. **`state.metVendors` Set** — saved/loaded as an Array. `tryInteract` adds `best.id` to it whenever the player opens a tracked vendor's dialogue. First-time addition triggers a save.
3. **"?" floater render** — added in `drawNpc`. Skipped on hostile/aggro'd NPCs (would clash with "!"). Gentle sin-based bob, two-pass black outline + piss-yellow fill.
4. **`renderQuests()` overhaul** — split into HUSTLES + QUESTS (ACTIVE/AVAILABLE/DONE) + PEOPLE YOU'VE MET. Quest entries show reward preview text from a static `QUEST_REWARDS` map.
5. **Intro chain** — 3 new quests in `state.quests` (intro_remember, intro_tony, intro_smoke), each with `intro: true` and `available: false` (chained sequentially). `state.flags.introDone` gates hustle/event/phone suppression. `rollHustles` early-returns during intro. `updateWorld` skips `fireRandomEvent` and skips ambient `ringPhone` during intro. The mom tip uses a separate `state.momTipT` countdown that fires once.
6. **`completeIntroSmoke()`** — called from `blockMenu`'s smoke action. Sets `introDone = true`, rolls the first real hustle set, broadcasts a welcome news line.
7. **Intro $10 cash pile** — appended to `cashPiles` in `spawnCashPiles` when `!introDone`. Special `intro: true` flag makes it always-visible with a pulsing glow. Pickup adds to `state.counters.introCashEarned` and calls `tryCompleteIntroRemember`. Also: `updateWorld` runs an alt completion check (any `P.cash >= 10` during intro completes intro_remember) so non-pile income paths also work.
8. **Mom first-day tip** — `fireMomIntroTipOnce()` calls `ringPhone(MOM_TIP_CALL)`. The `ringPhone` signature was extended with an optional `forced` call object so the tip fires through the intro suppression filter.
9. **`pigeonDialogue`** — visit counter (`state.counters.pigeonVisits`). On visit 2+ if quest not started, offers crown quest. On accept: `startPigeonCrownQuest()` picks one of 6 candidate spots via `pickCrownSpot()` (seeded into `state.flags.crownSpotIdx`), spawns `state.crownPickup`.
10. **Crown render + pickup** — drawn directly in `drawAll` (between cash piles and NPCs), shaped like a tiny gold crown with a purple gem. Pickup zone 18×18px. Pickup equips the hat directly (no inventory step), unlocks HEAD_THAT_WEARS.
11. **`stripeDialogue`** — visit counter (`state.counters.stripeVisits`). On visit 3+, surfaces "stripe leans in. listen." option → `offerStripePackage()`. Mid-quest (`hasStripePackage`), the dialogue becomes a single "go to the conductor" line. Post-betrayal (`stripeBetrayed`), dialogue is the hostile-but-still-talking variant: `"stripe knows. stripe has friends. stripe is patient."` No fencing, no transactions.
12. **Stripe package delivery** — auto-triggers in `updateWorld` when player is within 60px of conductor with `hasStripePackage`. Removes the package, awards $40+3 cred, opens a final conductor dialogue with the canonical line: `"stripe's name. stripe's money. you are stripe's leg. it is monday."`
13. **`openStripePackage()`** — surfaced via `blockMenu` when `hasStripePackage` is true. Rolls one of 4 outcomes (35/30/25/10). Always unlocks WHAT_S_IN_THE_BOX, always sets `stripeBetrayed = true`, always closes the quest as done.
14. **`barbDialogue`** — visit counter (`state.counters.barbVisits`). On visit 2+ if quest not started, sets `daveHasCrossword = true` and slips the hint into barb's flav. Return path: when player has crossword in inventory, top of barb's dialogue prepends a "give barb her crossword back" option. Post-completion, the dialogue has a permanent "ask what 14 across was" branch that reveals the BLAME line.
15. **`daveDialogue`** — added a "demand the saturday crossword" option when quest is active and dave hasn't been resolved yet. cred ≥ 3 = free hand-over; otherwise sub-dialog for $20 ransom or fight. Killing dave (already aggro pipeline) also drops the crossword in `onNpcDeath`.
16. **`vendorPrice(base)`** — helper for charisma-aware pricing. Plumbed into tony's $10, barb's $5/$22, pinky's $4/$18, stripe's $8 buy / $6 fence. Discount only kicks in at `P.charisma >= 1`.
17. **EQUIPMENT.pigeon_crown** — new entry. -3 cred, +1 charisma. `applyEquipStats` now sums charisma the same way it sums cred/hp.
18. **WEAPONS.knife** — new entry. dmg 14, reach 8. Used by `pickupWeapon('knife')` from the package-open knife outcome.
19. **ACHIEVEMENTS** — 4 new: HEAD_THAT_WEARS, EXACT_CHANGE, WHAT_S_IN_THE_BOX, SEVEN_ACROSS.
20. **Save/load** — `metVendors` (Array↔Set), `flags`, `crownPickup`, `charisma` on player, plus the new counters. Defaults in load are gentle (existing saves get `introDone: true` so they don't reload into the intro).
21. **Q-key UI** — `renderQuests()` now produces the tri-state quest panel + people-met index. Built off pair-iteration `Object.entries(state.quests)` so each quest can route to its reward preview.

### DECIDED, REASONING

- **Why 13 vendors not 14+**: the brief gave an exact list. Lurch/Sherri/Possum/Pigeon were left off deliberately — they're not "vendor" enough. Lurch begs $1, Sherri is paranoid, possum is the AI oracle, pigeon is a secret-seller. Following the brief; the index can grow later.
- **Why the intro pile is always-visible**: tweaker vision is mid-game content (player learns to hold F via the mathematician's tip). Day-1 player has no idea F exists. Making the intro pile always-visible (with a pulse glow) is a one-time exception that reads as a tutorial breadcrumb.
- **Why $0 starting cash on new saves**: the brief said "find ten dollars" — that doesn't work if the player already has $25. Resetting to $0 makes the intro_remember objective meaningful. After intro_smoke completes, the player has whatever they earned (the $10 pile + the $0 starting).
- **Why crown spawns are per-save-seeded not per-quest-roll**: replay value. If every save picked a random spot, the spots would be predictable across replays. Per-save seed means each playthrough hides the crown somewhere different.
- **Why open-package UX is at the block, not from an inventory "use" action**: the inventory panel is HTML innerHTML with no per-item action handlers. Adding click-handlers to inventory items would require a structural refactor. Surfacing the option from `blockMenu` instead is narratively cleaner anyway — "open it where no one is watching" matches the crate's home-base framing.
- **Why a hostile-text branch for stripe instead of full hostile NPC**: stripe is the co-op partner. Making him aggro would conflict with the rank-up co-op ending path (which requires 5 loyalty + a peaceful interaction). The text-only hostile branch closes the fence without nuking the ending.
- **Why the mom tip isn't part of `PHONE_CALL_LINES`**: it's one-shot and forced. Mixing it into the random rotation would either spam or hide it. Separate timer + separate call object.
- **Why charisma is hidden and not displayed in the HUD**: the brief says "hidden charisma field." Inventory panel does show the charisma value indirectly (via the equipped crown). The price discount is visible the moment the player opens tony's dialogue and sees $9 instead of $10 — that's the reveal.
- **Why barb's "ask 14 across" branch persists post-completion**: the BLAME line is the comedic payoff. Players should be able to revisit it. It's gated behind `q.done` so it doesn't fire pre-quest.

### TRIED, ABANDONED

- Considered storing the package as a `state.flags.hasStripePackage` boolean only and NOT putting it in `P.inventory`. Abandoned: showing it in the inventory list reinforces "you have something. it is here." The dialogue option to open it at the block now references the item, which feels more grounded.
- Considered showing the people-met index as a separate Q key (Q opens quests, P opens people). Abandoned: P is already the phone feed. Adding a third panel-toggle would fragment the mobile UI. Unifying into the Q panel is denser but cleaner.
- Considered making `pigeon_crown` give +2 charisma so prices were 20% off. Abandoned: 10% is enough to feel real, 20% breaks the math elsewhere. Keep the dial low.
- Considered intercepting `P.cash` writes via a setter to track intro_remember accumulation precisely. Abandoned: per-frame check (`P.cash >= 10` during intro) is functionally equivalent and far simpler.

### COUNTEREXAMPLE HUNT

- v12/wave-2 save loads into v13 wave 3: `state.flags` defaults to `introDone: true`, `metVendors` defaults to empty Set (player will see "?" floaters on every vendor they haven't visited yet — actually that's a feature, not a bug). ✓
- New save flow: P.cash=0, intro_remember active, $10 pile visible at (1180, 870), pickup → quest complete → intro_tony available → tony dialogue opens → intro_tony complete → intro_smoke available → smoke at crate → intro_smoke complete → introDone = true → hustles roll → world events un-suppress. ✓
- Charisma off (no crown): vendorPrice(10) returns 10. tony's UI shows "buy a rock. $10." ✓
- Charisma on (crown equipped): vendorPrice(10) returns 9. tony's UI shows "buy a rock. $9." ✓
- Stripe package: pick up → run to conductor 60px → auto-delivery dialog → +$40 +3 cred → EXACT_CHANGE. ✓
- Stripe package open: pick up → return to block → blockMenu offers "open" → roll → either rocks/soap/knife/wire → stripeBetrayed = true → future stripe dialogues show the patient-friends line, no fencing. ✓
- Barb crossword: visit 1 (normal) → visit 2 (aside drops, daveHasCrossword=true) → visit dave (option appears) → cred>=3 ? free : ransom/fight → return to barb → quest complete + free packet + BLAME reveal. ✓
- Pigeon crown: visit pigeon 1 (normal) → visit 2 (offer surfaces with `last seen: …`) → accept → crown spawns → pickup → cursed hat equips → -3 cred but tony charges $9. ✓
- Killing dave with crossword still on him: `onNpcDeath` checks `daveHasCrossword`, drops crossword into inventory. ✓
- Mom tip on existing save: `momIntroFired` defaults true → tip never fires. ✓
- Mom tip on new save: momTipT starts at 30000, decrements to 0 in updateWorld, fires once, momIntroFired=true persists across save. ✓
- Intro suppression: introActive flag short-circuits fireRandomEvent + ambient ringPhone. rollHustles early-returns. ✓
- The "?" floater on hostile lurch/paulie: skipped (the `!n.aggro && !n.hostile` guard). ✓
- Loading after intro_smoke completion: introDone=true persisted, rollHustles works normally. ✓

### NEXT (the v13 campaign continued)

- Wave 4 brief is TBD. Likely candidates from DELEGATION.md backlog: NPC pixel sprites (still emoji for most), tweaker vision polish (now competing with the always-visible intro pile), or weapon variety (knife is the second non-fist; could expand the trade-up tree).
- The abandoned-building "RANK 4+" cosmetic gate is STILL untouched. Original wave-1 debt. Probably wave 4 or 5.
- Charisma is currently single-source (crown). If we add a second piece (rumor: a charm bracelet, a "fancy" tie at the laundromat), the discount could stack — verify the price math doesn't go below $1 (the `Math.max(1, ...)` floor in vendorPrice catches it).
- Consider a fourth side quest tied to The Mathematician (he has the perfect tone for one — "the numbers want a thing from you").

### GOTCHA

- `state.metVendors` is a Set in memory and an Array on disk. Always read with `Array.from(...)` on save and `new Set(arr)` on load.
- `state.quests` is merged via `Object.assign({}, state.quests, sv.quests)` so new quest defaults survive into old saves (the wave 2 pattern). But: a `q.available` field that's `false` in defaults will be overwritten by `undefined` in old saves if the save didn't have it. Watch for this on future quest additions — better to set `available: false` explicitly in both the default and the load-time fixup.
- `vendorPrice` is called at dialogue-render time, not at click time. If the player un-equips the crown after opening tony's dialogue but before clicking buy, the UI still shows the discounted price. The transaction itself reads `vendorPrice(10)` again (so it'd revert) but the LABEL would be stale. Minor edge case; acceptable.
- The stripe `stripeBetrayed` flag is set both on `openStripePackage()` AND on the existing kill path (`state.counters.stripeBetrayed`). Two flags overlap conceptually but mean different things: the counter is for the JUDAS achievement (plate+stripe death), the flag is for the package opening. Don't unify them.
- The Q-key panel's "AVAILABLE" section will be empty for most of the playthrough since quests transition active → done quickly. That's fine — empty section just hides itself (`latentPairs.length ? … : ''`).
- New saves start at $0 cash — this is intentional but means a player who quits during intro will reload to $0 + whatever they earned. The intro quest auto-completes on `P.cash >= 10` regardless of source, so they're not soft-locked.

---

## Session 2026-05-26 · v13 wave 2 · sprite parity + three new NPCs

### WHAT
Closed the v13 wave 2 brief in one pass: sprite consistency cleanup (Barb gets her own palette, the four "ambient pedestrian" NPCs get palettes instead of falling through to tony's), and three brand-new named NPCs implemented end-to-end (PINKY POLENTA — rival supply, THE MATHEMATICIAN — cook-EV oracle, COUSIN BRENDAN — rookie-cop mini-boss). Plus dirty-packet economy hook into `doCook`, two new achievements, a new BUS STOP zone, a `glasses` accessory option for `makeNPC`, and matching docs.

### WHY
1. **Pinky = economy depth.** Barb is the only supply lane. Picking the cheaper vendor at a tradeoff (more soap rolls) gives the player a real second axis to optimize, without changing barb's flow. The "you no like? you go barb" exchange is also the comedic payoff.
2. **The Mathematician = onboarding-as-character.** The game's surface is dense with hidden systems (cook bb factor, soap chance, tony's offense threshold, cash piles). A character who *cryptically tells you the math* is a discoverability tool that doesn't break vibe — Disco-Elysium-style "skill check that is a fever dream." Cadence is every 3rd interaction so it doesn't dump everything at once.
3. **Cousin Brendan = combat variety.** Cops have been one flavor for the whole campaign. Brendan adds a fast/squishy/burst archetype — squishier than a regular cop but punishing if you whiff (taser 50). The recharge gives a tactical window. The lore line ("uncle dean is posting on facebook again") is the comedy load — Brendan is a Trailer-Park-Boys nephew, not a dramatic enforcer.

### WHAT CHANGED

1. **PALS additions** — `barb`, `pinky`, `math`, `brendan`, plus newly-added `cubscout`/`jogger`/`busker`/`dogwalker` palettes. Discovery: those four had `npcStyles` entries already, but no PALS entry — they were silently rendering with `PALS.tony` (the fallback at line 1004). That's the "half-converted" inconsistency the brief called out. Real fix is just giving them palettes.
2. **`makeNPC` `glasses` accessory** — paints accent-color glasses around the eye row + bridge over row 4. Used by The Mathematician.
3. **`P.dirtySupplies`** — new player scalar tracking how many of `P.supplies` came from Pinky (dirty). Saved/loaded forward-compatibly (defaulted to 0 on legacy saves; clamped to ≤ supplies on load). The save key (`rockbottom_save_v8`) was NOT bumped — additive change.
4. **`doCook` math** — consumes dirty packets first (FIFO), and the post-roll soap chance is now a packet-weighted average: `(dirtyUsed*0.25 + cleanUsed*0.12) / n`. Pure-clean batches keep the exact 12% legacy behavior. Pure-dirty batches hit 25%. Mixed pro-rates.
5. **`cookBatchMenu`** — shows a one-line "X of them are pinky's house cut. (dirty first.)" hint if dirty > 0. Otherwise unchanged.
6. **New NPCs in `spawnNpcs`** — `pinky` at (1330, 1160) in the new BUS STOP zone, `math` at (1340, 380) in the existing HIGHWAY UNDERPASS zone (east-of-biggu so they don't collide).
7. **New zone** — `BUS STOP` at (1240, 1080, 220, 180). Sits between THE BLOCK, MARKETPLACE, LAUNDROMAT — a natural crossroads. Foot-traffic plausibility check: horsecop patrol crosses it (fine), no other vendor inside the rect.
8. **`pinkyDialogue` + `mathematicianDialogue`** — added next to `barbDialogue`. Pinky says "you no like?" by player choice not by RNG; Math re-enters itself via "ask for another number" (no stack risk — synchronous dialogue replacement).
9. **`barbDialogue` aside** — when `state.barbAside` is true (set on first pinky purchase), barb's next visit prepends a passive-aggressive one-liner. Flag is consumed on display, persisted across saves.
10. **`manageCops`** — Brendan spawn variant. If `P.wanted >= 2` and no live brendan and `Math.random() < 0.3`, spawn config switches to Brendan's stats and id namespace. Followed by a toast announcing his arrival with one of two cursed yelled lines.
11. **NPC AI loop** — added `taserChargeT` accumulator for Brendan in the aggro/chase branch (caps at 4000ms). Touch damage branch checks `isBrendan`: only applies damage (50) and resets the timer when ≥ 4000. Otherwise Brendan just chases. Includes blue particle burst + cop siren on zap.
12. **`onNpcDeath` cop branch** — Brendan-specific: pushes a $30 cash pile at his body (re-uses the existing cashPiles array), unlocks `BADGE_MONEY`, and broadcasts the "uncle dean is posting" line on first kill only (gate via `state.counters.brendanFirstKill`).
13. **Achievements** — `due_dealer_system`, `badge_money` added to ACHIEVEMENTS map. Persisted via the existing achievement set, no schema change.
14. **CHATTER** — pinky / math / brendan ambient line pools.
15. **Inventory panel** — shows `🧪 N (M house cut)` if dirty > 0.
16. **VIBE.md** — identity table extended with all 3 new NPCs (all 4 columns filled).
17. **SPEC.md** — Cooking table updated for dirty packets; new section on Cousin Brendan spawn/state machine; change log bumped.
18. **DELEGATION.md** — v13 wave 2 SHIPPED section at top of file.

### DECIDED, REASONING

- **Why `P.dirtySupplies` (scalar) instead of `P.inventory` items**: the brief offered two options — flag on an inventory item, or a separate inventory id like `packet_dirty`. But `P.supplies` is a top-level scalar, *not* in `P.inventory` (inspect: only physical curiosities go in `P.inventory` — gold tooth, traffic cone, soap, license plate, detergent). A parallel scalar `P.dirtySupplies` is the cleanest fit and preserves Barb's single-counter flow.
- **Why FIFO-consume dirty packets first in cook**: a player intuition pump — "you use the cheap stuff first when you're still figuring it out." Also it means the long-term cook strategy converges on stocking clean for the high-stakes burns. Gives the dirty packet a real tactical identity instead of being indistinguishable from clean once mixed.
- **Why a new BUS STOP zone instead of placing Pinky free-standing**: there is no bus station in v13's world. Free-standing NPCs read as decorative; vendors are anchored to a zone (Tony at the corner, Barb in laundromat, Pete in pawn). A small zone gives Pinky a sense of territory and reads as foot-traffic-plausible.
- **Why Math re-enters itself rather than re-running interaction logic in-place**: cleaner narratively — each "ask for another number" is a new beat with its own ev calc and possible tip reveal. Counter increments per click, so tips unlock in expected cadence.
- **Why Brendan's taser charges only while aggroing (not always)**: if it charged passively while off-screen / despawned, the player would be hit instantly on his first touch. Charging during chase gives a fair tactical signal — the longer he's been chasing you, the more dangerous getting close becomes.
- **Why drop a cash pile (not a unique badge item)**: brief explicitly says "use existing cash-pile pickup mechanic." Same flow as the 22 world piles. No new pickup type needed. Toast labels it as "his badge fell out" — narratively it's a badge, mechanically it's cash.
- **Why broadcast facebook line only on first kill**: repeat broadcasts get spammy on the ticker. First-kill is the cursed-introduction moment; subsequent kills get a quieter feed post instead.

### TRIED, ABANDONED

- Considered making Brendan a regular NPC (not a cop variant) so his AI could be simpler. Abandoned: he needs to count toward wanted-level cop logic (player kill = +1 wanted, normal cop drops on death, etc.) so it has to be the cop pipeline.
- Considered having Pinky's house cut be a separate inventory item (`packet_dirty`) with cook-menu options to "cook 1 clean / cook 1 dirty / cook all". Abandoned: the cook menu already has 4 modes — doubling that to 8 fragments the UI. FIFO consumption is simpler and the dirty-batch effect surfaces in soap-rate.
- Considered giving Math a "skill check" UI à la Disco Elysium. Abandoned: out of scope for this wave; the dialogue-as-character approach is the v13 style.
- Considered moving the Mathematician to the deepest interior point of underpass at (1210, 350). Abandoned because biggu is at (1200, 340) — placed math at the east edge (1340, 380) instead.

### COUNTEREXAMPLE HUNT

- v12 save loads into v13 wave 2: `P.dirtySupplies = Math.min(P.dirtySupplies||0, P.supplies)` defaults to 0 on legacy saves and clamps if somehow corrupted. Forward-compatible. ✓
- `doCook` with 0 dirty packets: `soapRate = (0 + n*0.12)/n = 0.12` — exact legacy behavior preserved. ✓
- `doCook` with all dirty packets: `soapRate = 0.25` — matches the spec. ✓
- `doCook('shakes')`: still skips soap entirely (mode === 'shakes' branch). ✓
- Two cops spawning, both rolling Brendan: prevented by `!liveBrendan` check before each spawn roll. ✓
- Brendan spawned, player runs to opposite end of map and waits 30s: cop decay reduces wanted by -1 every 18s, all cops despawn at 0. Brendan despawn-on-decay is handled by the same path as regular cops (he isn't a special-cased exception). ✓
- Brendan dies, his cash pile gets picked up: the pile uses the existing `cashPiles` array and pickup loop. `state.cashPilesCollected` set gets a `cp_brendan_xxx` entry, persists across save. ✓
- Player buys from Pinky, then immediately visits Barb: `state.barbAside = true` triggers the one-liner; flag is then cleared. Subsequent barb visits show no aside until next pinky purchase. ✓
- `state.barbAside` persists across save: yes, added to save/load. ✓

### NEXT (the v13 campaign continued)

- The visible inconsistency from wave 1 is still there — abandoned building still draws "RANK 4+" cosmetic boards before rank 4. Either fix the cosmetic gate or repurpose the cue. Probably wave 3.
- Boss music (v4 backlog #11) still untouched.
- The cook brain-factor tip reveal at 3rd interaction implies the player understands `bb`. If the Mathematician's tips get spammed-through, the player may have unlocked all 5 by the time they need them. Consider gating reveals on real-time intervals if it becomes a problem.
- Possible additional Pinky hook: a "limited time" deal where Pinky discounts further if you have already killed Brendan (family beef). Speculative.

### GOTCHA

- The cubscout/jogger/busker/dogwalker palette discovery: anyone touching `npcStyles` in the future should always check that the same key exists in `PALS` — fallback to `PALS.tony` is silent and shipping it would re-introduce the same bug.
- `makeNPC`'s `glasses` accessory mutates `body[4]` AND `body[5]`. If a future NPC has both `cap:true` and `accessory:'glasses'`, the glasses bridge row may overlap with the cap. Current Mathematician has no cap so it's fine, but watch for combinations.
- Brendan's `attackCd` is 1000ms (not the standard 800) so his post-zap cooldown is slightly longer than the recharge — gives the player a small breathing window after eating a taser. Don't "fix" this to 800 — it's tuned.
- `state.counters.brendanFirstKill` gates the broadcast — if a save is reloaded after first kill, subsequent brendans don't re-broadcast. Intentional.
- The `BUS STOP` zone has no buildings inside it, only the new NPC. If we later add a bench prop, it'd go in `PROPS` at around (1340, 1180).

---

## Session 2026-05-26 · v12 → v13 wave 1 · repo live, housekeeping fork

### WHAT
Opened the v13 campaign with a foundation/housekeeping wave. Forked v12 → v13. Stripped a dead rank-gate collision check. Refreshed README to match reality. Locked line endings via `.gitattributes`. GitHub repo went live earlier in the session.

### WHY
The discovery pass before this wave found docs and code had drifted apart — README still claimed v3 was the shipped build (we're on v12 going into v13), DELEGATION.md still listed ~9 of 12 "out-of-scope" items that have actually been shipped, and small bits of stale code lingered after the v12 finisher work. Before any new features land in v13 (sprites, map depth, minigame variety, combat patterns — the actual top weak spots), the foundation needs to match the game. Plus: lineage hygiene. v12 untouched, edits land on v13.

### WHAT CHANGED

1. **Repo live** — `https://github.com/Sovereignprime357/rock-bottom` (private). Initial push earlier in the session covered v4..v12 + the markdown docs. CRLF/LF noise on the initial commit motivated the `.gitattributes` lock-in this wave.
2. **v12 → v13 fork** — `rock_bottom_v13.html` copied from v12. v12 left untouched as lineage.
3. **`<title>` tag** — was still "ROCK BOTTOM v11" in the v12 file (slipped past the v12 ship). Bumped to "ROCK BOTTOM v13".
4. **Dead rank-gate collision check removed** — in `updateWorld`, both collision loops had `if (b.locked && P.rank>=4 && b.x>1500 && b.x<1600) continue;`. With the v12 heist rank-gate removal, `BUILDINGS.find(b=>b.locked)` is auto-unlocked at rank 4 (line ~2799), so the outer abandoned rect drops `locked` before this skip can fire. The skip only ever applied to the interior solid rect, and the interior is content-empty — nothing inside, no shortcut value. Removed cleanly.
5. **README.md** — rewritten to match the v13 reality: single-HTML / vanilla JS / Canvas 2D / Web Audio / zero deps / double-click to play; version lineage v4..v13 preserved; design-doc index; tone line in VIBE voice. v3-era claims gone.
6. **`.gitattributes`** — `* text=auto` + explicit `*.html text eol=lf` and `*.md text eol=lf` to kill the CRLF chatter on commits going forward.

### DECIDED, REASONING

- **Why fork to v13 instead of editing v12 in place**: hard rule from CLAUDE.md — keep the lineage. Every shipped build is a checkpoint. v12 is now frozen.
- **Why remove the rank-gate skip cleanly, not refactor the rest of the rank-4 cosmetic logic**: scope discipline. Wave 1 is housekeeping, not redesign. The residual rank-4 cosmetics (boarded planks visual at line ~3422, awning gating at ~3278, window gating at ~3295, the rank-4 unlock side-effect at ~2798-2800) are visually inconsistent with the heist now being available pre-rank-4 — the building still shows "RANK 4+" boards even though Brutus Jr. is the real gate. Flagging for a later wave instead of band-aiding now.
- **Why a TONE line in the README in VIBE voice**: README is mostly ordinary copy, but a fresh agent should hear the voice once on the way in. One sentence is enough.

### TRIED, ABANDONED

- Considered also unlocking the interior solid rect (line ~285) along with the outer one at rank 4 so post-rank-4 players can walk through the building — abandoned. There's nothing inside. Building-as-impassable-prop is the simplest model. If we add interior content later, fix it then.
- Considered ripping out the rank-4 cosmetic gating (planks, "RANK 4+" label, awning suppression) in this wave — abandoned. Out of scope for wave 1 and the visual gating actually still has utility as a *visual cue* even if the mechanical gate moved to Brutus Jr. The fix is to reframe what that cue means, not delete it. Wave 3+ concern.

### COUNTEREXAMPLE HUNT

- Removing the rank-gate skip: does anything else read `b.locked` that would now fail? Grep shows references in `updateWorld` (the removed lines), `drawBuilding` (cosmetic only), the rank-4 unlock side-effect (still works — the outer rect still gets `b.locked = false` at rank 4), and the heist trigger in `tryInteract` (still works — proximity-based, no rank check). No orphan reads. No band-aid required.
- v12 saves load into v13: forward-compatible. No save schema change this wave.
- v13 title in `<title>` matches the file basename: ✓.
- `.gitattributes` doesn't break the existing committed files: text=auto + explicit eol=lf is standard, applied to new commits going forward.

### DISCOVERY PASS PUNCHLINE (from earlier this session)

The operator already has the full discovery report. Summary for continuity:
- Docs were significantly out of sync with the code. ~9 of 12 items the v3-era SPEC.md listed as "out of scope" have actually shipped (achievements, mobile touch, equipment, weather, day/night, quest log, mini-games, etc.). Updating SPEC.md to reflect this is a separate wave.
- Top weak spots flagged for the v13 campaign: discoverability, NPC sprites (still emoji), map depth (world is small for current content density), minigame variety (cook + heist + lockpick + rhythm — feels good but converges fast), combat patterns (still pure fist + space + knockback).
- These map onto the wave 2+ backlog.

### NEXT (the v13 campaign — 6 waves)

- **Wave 1** (this) — housekeeping, fork, docs, CI hygiene. SHIPPED.
- **Wave 2+** — TBD in operator's plan. The top weak-spot list above is the prioritization.

### GOTCHA

- The v12 file had its `<title>` still saying "ROCK BOTTOM v11" — a v11→v12 ship miss. Watch for this on every fork: bump `<title>` and the `SAVE_KEY` if the save schema changes (it didn't this wave).
- After this wave, there is a visible inconsistency: the abandoned building still draws "RANK 4+" boards before rank 4 even though the heist works at any rank. This is intentional debt — flagged above. A future wave should either (a) drop the cosmetic gate entirely, or (b) change the cue from "rank 4+" to "brutus jr is awake" / "the dog has nightmares" / whatever fits VIBE.
- `.gitattributes` only affects commits going forward. The v4..v12 files already in history keep whatever EOLs they were committed with. That's fine — we don't re-normalize history.

---

## Session 2026-05-23 · v11 → v12 · wire copper, build the finisher

### WHAT
Wired the copper heist into the gameplay loop and added a cooking economy on top of it. Closes the loop: steal → sell → buy supplies → cook → smoke or sell → buy more. The "finisher move."

### WHY
v11 had the copper heist mechanically complete but gated behind rank 4 (100 cred), which meant most players never saw it. v11 also had no internal rock economy — Tony was the only source. The user explicitly asked for: wire copper stealing in, plus a self-cook + buy/sell loop. The cook loop is the late-game grind that pays off all the earlier scaffolding (Barb's packets, the crate at the block, Stripe's fence, the abandoned building).

### WHAT CHANGED

1. **Abandoned-building heist** — removed the `P.rank >= 4` gate in `interact()`. Always accessible. The Brutus Jr. dialogue is the actual gate now.
2. **`P.supplies`** — new player stat. HUD slot 🧪 added. Save schema bumped 8 → 9.
3. **BAGGIE BARB** — new vendor NPC at the laundromat (x:1540, y:1190). Uses launderlady sprite (palette-tinted). Sells $5/packet, $22/5pack. Has crossword dialogue + 14-across joke pool.
4. **`cookBatchMenu()` + `doCook()`** — 4 cook modes wired into `blockMenu`. Brain modulates outcome (`bb` factor), rocked-up subtracts 0.25 from bb (shaky scientist = comedy). 12% soap chance post-roll. Cooking 3+ at once has 35% wanted+1 (smell). All cooking is THE BLOCK only (matches smoke invariant).
5. **Stripe fence** — added "sell 1 rock $6" and "sell all (3+) bulk" options to `stripeDialogue`. Tracks `P.lifetime.rocksFenced`.
6. **Quest**: `finisher` (THE FINISHER — cook a rock).
7. **Hustles**: `cook_2`, `fence_3`.
8. **Achievements**: `chef`, `arson_of_nothing`.
9. **Lore**: news ticker, VIBE.md identity table (Barb), SPEC.md cooking table.

### DECIDED, REASONING

- **Why laundromat for Barb, not a new zone**: extending an existing space preserves the grandma-camouflage joke (she's "just doing laundry"). Less code, more comedy. Soft rule #1: prefer extending existing systems.
- **Why no rank gate on heist**: the operator's intent is "this is the finisher move." A finisher you can't unlock until rank 4 isn't a finisher, it's a treadmill reward. The Brutus Jr. encounter is the real difficulty gate and stays untouched.
- **Why brain modulates cook**: gives the player a reason NOT to smoke before cooking. Self-balancing tradeoff. Also free comedy — being rocked-up makes you a worse cook, which is true.
- **Why Stripe fences at $6 (not Tony)**: Tony does not negotiate. Stripe is the rival hustler — fencing through him is in-character. Also: he can resell at $8 with 40% soap, this fits his MO.
- **Why $5 packets / 0.08-0.55 double-rock**: economy math: avg yield per packet ~1.05-1.6 rocks depending on mode/brain. At $6 fence, that's $6.30-$9.60 revenue vs $5 cost. Always positive EV but skill-dependent. Smoking them straight makes them effectively $5 rocks (vs Tony's $10) — the real value is the rocked-up uptime.
- **Why dialogue-driven cook (not a timing minigame)**: matches the existing heist + lockpick style for consistency. Adding a third UI pattern would fragment the game's feel.

### TRIED, ABANDONED

- Considered a new NPC zone ("The Cookhouse") — overbuilt. The laundromat is funnier.
- Considered making cooking a sliding-needle skill check — would have been a third minigame pattern. Cut for consistency.
- Considered making Tony also buy rocks back at $7 — broke the "tony does not negotiate" rule and his "$10. simple math." voice. Cut.

### COUNTEREXAMPLE HUNT (gates checked)

- Cook with 0 supplies → button disabled.
- Cook with rocked-up active → bb -0.25 makes burn more likely; not broken.
- Fence rocks with 0 rocks → button disabled.
- Load v8 save → forward-compatible; `P.supplies = P.supplies || 0` post-Object.assign.
- Cooking 3+ → smell wanted bump is gated by `Math.random() < 0.35`, doesn't always trigger; doesn't run on 1-packet cooks.
- The rocked-up → crash transition is untouched. Invariant 10 preserved.

### NEXT

- Unique sprite for BAGGIE BARB (currently shares launderlady palette).
- Possible: a 4th cook mode unlocked by an item (a propane torch?) — would need a vendor for it (Pete?). On the v13 backlog as speculative.
- Boss music (still v4 backlog #11).
- Tweaker vision (v4 backlog #3) interacts well with hidden cash piles already in v11; would also work for "spot the unwatched packet" — could be a passive on Barb's cart.
- Watch for cook+smoke loop becoming too dominant in late game. If it does, slightly bump brain decay during a long rocked-up streak so the player has to sleep.

### GOTCHA

- The `state.quests.finisher` field is added to the default quests object now; old v8 saves merging into it works because `Object.assign({}, state.quests, sv.quests || {})` keeps the new default if not in the save.
- `setTimeout` on the smell wanted-bump toast: chosen so the batch toast lands first, then the consequence. Watch in case browser tab loses focus.
- `audio.glassBreak()` reused for cook complete — chiptune-appropriate but if it gets too samey, write a `audio.cook()` synth (sawtooth 200→90hz, brief). v13 polish.

---

## Session 2026-05-26 · v13 wave 5 · combat patterns + fallen priest

### WHAT
Replaced the v12-era "every hostile is a chase-biter with different stats" model with a proper archetype dispatch in `updateNpc`. Five archetypes (`charger` / `grabber` / `swarmer` / `ranged` / `cop`) each have their own AI branch keyed off `n.archetype`. Added a generic projectile system (`projectiles[]`, kinds `bottle` + `holy`) for ranged attackers. Reframed both bosses' phases as PATTERN shifts, not just HP/speed scaling — tony p2 converts to charger + spawns sherri adds, p3 goes berserk; brutus_older p2 adds swarmers every 8s, p3 berserk + grabber-on-contact. New side quest `fallen_priest` (two trigger paths) flips FATHER O'MALLEY in-place into `omalley_fallen` (archetype `priest_fallen`, 160 HP, ranged-holy → dasher phase machine). Death drops $200 + `priest_collar` (slot `hat`, +2 cred, wantedDecay ×1.3). 3 new achievements (FALLEN / DODGED_THE_LUNGE / OUTRAN_THE_PRIEST). New status timers `P.stunT` (grabber) + `P.slowT` (holy water). Hit-stun 120ms baseline on every NPC damage tick. Cop radio-for-backup loop. Save key unchanged.

### WHY
1. **Combat felt flat.** v12/wave 4 had 8 distinct hostile types, but on the player side every fight read the same — close to range, hold SPACE. Adding archetypes makes each hostile *demand a different response*: charger wants you reading windups and dodging perpendicular; grabber wants you to break contact before he grabs; swarmer wants you to kill her first before the sibling lands; ranged wants you to close OR break LOS; priest_fallen wants both halves of the fight learned.
2. **Boss phases were just numbers.** v12 brutus phases were "HP threshold → speed +X, dmg +Y." Functionally the same fight, slightly faster. Reframing phase entry as a PATTERN shift (with a flavor toast + add spawn + archetype mutation) gives each boss three readable acts.
3. **The priest was a hanging thread.** Stealing the collection plate flagged hostile but never had a payoff — the priest as a normal-stat hostile was a non-event. Promoting him to a true mini-boss with his own quest closes the church arc and finally rewards the steal-plate dialogue option with consequences worth caring about.

### WHAT CHANGED

1. **Archetype dispatch in `updateNpc` (line 4084)** — `const arch = n.archetype || 'default'` switches into the per-archetype branch. Default branch (cops without archetype, larry, dave-on-aggro) preserves the v12 chase-bite flow exactly. Each archetype gets ~30-50 lines of dedicated logic.
2. **CHARGER (line 4090)** — `charger` and `charger_older` share the machine; `n.berserk` flag adds a 3rd tier. State machine: `idle → windup (red tint + giant `!` + audio.windup) → lunge (vector locked at windup-start) → cooldown (vulnerable: +25% playerAttack damage)`. Tunings vary by tier: standard windup 800/lunge 1000ms/2.0×, older 550/1400/2.4×, berserk 400/800/3.0×. DODGED_THE_LUNGE unlocks first time a lunge ends without `n.chargeLanded`.
3. **GRABBER (line 4171)** — `lurch`. Default chase + on-contact: damage ×1.3, sets `P.stunT = 500ms` (input lock), 200ms post-grab freeze on the NPC for arms-extended pose. First-grab-per-encounter toast: "GRABBED.\nhis arms are too long."
4. **SWARMER (line 4196)** — `sherri`. Speed ×1.4, dmg ×0.6. On aggro (in `aggroNpc`, line 3175) calls `spawnSwarmerSibling(parent)` if liveSwarmers < 2 — pushes a clone 60px offset with id `sherri_<random>`. Cap 2 total. Toast: "another one shows up.\nit has the same haircut."
5. **RANGED (line 4212)** — `paulie`. Maintains 180-260px envelope (back off if d<180, advance if d>260). Throws bottles every 1500ms via `spawnProjectile({kind:'bottle', wobble:0.20})`. 350ms aim-raise telegraph with `*` particle. Panic-chase 1s if player closes to <120px.
6. **`spawnProjectile()` helper (line 3204)** — generic primitive. Computes velocity from `(x,y) → (tx,ty)`, applies optional angle wobble, pushes onto `projectiles` array. Kind drives only visuals + impact-side-effects; motion + collision + pool-cap are shared.
7. **Projectile update loop (line 4438)** — runs in `updateWorld` after particles. Linear motion (`vx,vy` in px/sec, dt-normalized), wall collision against solid BUILDINGS, world-edge despawn, player overlap → `damagePlayer(dmg)` + optional `P.slowT = slowMs`. Pool capped at 40. Kind-specific impact particles (brown shards for bottle, cyan glow for holy).
8. **Projectile render (in `drawAll`)** — between particles and player. Bottle: rotating amber rectangle. Holy water: pulsing cyan vial with a + cross.
9. **Tony boss phase machine (line 4481)** — three thresholds (66%, 33%). p2 sets `archetype='charger'`, resets charge state, speed 2.4, spawns 2 sherri swarmers ±80px, toast: "tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers." p3 sets `berserk=true`, speed 3.0, dmg 16, triple-stack bossRoar, toast: "tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up."
10. **Brutus Older boss phase machine (line 4535)** — parallel structure on `state.brutusOlderNPC` / `state.brutusOlderPhase`. p1 already charger_older from spawn. p2 toast "he was warming up before." starts an 8s add-spawn timer that pushes sherri swarm pairs (cap 2). p3 sets `bo.berserk = true; bo.grabber = true`, toast "he doesn't bite anymore.\nhe grabs." — the contact code in the charger branch reads `n.grabber` and stacks the stun on lunge contact.
11. **FALLEN PRIEST (line 4263)** — archetype `priest_fallen`. Phase 1 (HP ≥50%): ranged-holy. Maintains 180-280px with orbital strafing inside the band. Throws holy water vials every 1200ms via `spawnProjectile({kind:'holy', dmg:22, slowMs:1500, wobble:0.18})`. 350ms cyan-glow telegraph. Phase 2 (HP <50%): dasher — same charger state machine but priest-tuned (windup 500ms, lunge 900ms, ×2.4, cd 1200ms). Lunge contact applies the slow as well as damage. One-shot phase transition toast: "the lord is not here.\nthe lord left.\nhe took the bus."
12. **`triggerFallenPriestTransform()` (line 2265)** — flips the existing `priest` NPC entity in place. Sets `id='omalley_fallen'`, archetype, hostile+aggro, doubles HP to 160, darkens color to `#2a1a2a`, sets `isOmalleyFallen=true`. Audio bossRoar + screen shake 14 + purple flash. Canonical line: "father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong."
13. **Two trigger paths**:
    - **Steal path** — inside `priestDialogue`, ≥4 priest visits + at least 1 prior steal attempt fires the transform on next "steal the collection plate" tap.
    - **Quest path** — `maybeFireFallenPriestCall()` (line 2300) fires once when rank≥3, church-visits≥3, intro done, and call not yet fired. Plays `ringPhone({from:'unknown number', text:"father o'malley says the church belongs to whoever has the keys.\nyou don't."})`. Quest flips to `available`. Player still has to walk back into the church + try to steal to trigger the actual transform.
14. **`priest_collar` equipment (line 384)** — `slot:'hat'`, `cred:+2`, new `wantedDecay:0.3` field (additive to a 1.0 base multiplier in `manageCops`). Drops on omalley_fallen death via cash-pile branch (line 3915) with `equipId:'priest_collar'` field. Pickup binds to head slot. Renders as a small white band with a black center seam at world coords.
15. **`P.stunT` + `P.slowT` (line 1362)** — both ephemeral, never persisted. `stunT` blanks movement+attack+interact in their respective handlers (early-return when >0). `slowT` multiplies player speed ×0.5 in `updatePlayer` (line 3675).
16. **Hit-stun (n.hitStun)** — set to 120ms on every `playerAttack` damage tick. Most NPC AI branches early-return when `n.hitStun > 0`. Knockback bumped from 6 to 8 px on the same hit path. Makes combat feel chunkier without changing damage numbers.
17. **Charger vulnerability** — `playerAttack` damage gets ×1.25 multiplier when `(n.archetype === 'charger' || 'charger_older') && n.chargeState === 'cooldown'` (line 3308). Rewards reading the lunge → striking on the pant.
18. **Cop radio-for-backup** — in the default branch when target is a cop and distance >120px, 25%/sec chance to schedule `spawnCop(...)` after 5s, capped at COP_HARD_CAP=4 total. Brendan does NOT radio (his branch is unchanged).
19. **Quest entry `fallen_priest`** (line 1452) — title "THE FALLEN PRIEST", flav "the priest has been wrong for a while. someone should say so." Default `available:false`, `done:false`. Auto-set `available=true` via either trigger path. Closed via omalley_fallen death handler (line 3394) with rewards + questToast.
20. **3 new achievements (lines 458-460)** — `fallen` ("put father o'malley on the ground. the church is quiet."), `dodged_the_lunge` ("sidestep a charger's lunge. it lands on nothing."), `outran_the_priest` ("survive father o'malley fallen for 60 seconds. the lord is busy.").
21. **SPEC.md update** — full COMBAT PATTERNS section (line 412), archetype table, projectile system spec, boss-phases-as-pattern-shifts subsection, status effects, hit-stun, charger vulnerability. Plus FALLEN PRIEST section (line 462) with the two trigger paths, transform, reward, survival achievement.

### DECIDED, REASONING

- **Why dispatch by `n.archetype` string, not inheritance / function refs**: the NPC list is data-driven (PALS / npcs[] / serialized save). A string tag survives the save/load roundtrip naturally; a function ref does not. Plus the dispatch is one switch in one place — easy to find, easy to extend. Adding a 6th archetype = add a tag + one branch.
- **Why default branch preserves chase-bite exactly**: 60% of hostiles in the world (larry, dave, generic cops, alley crackheads, brendan) shouldn't change behavior — that would invalidate v12 muscle memory. Only the NPCs with declared archetypes get new patterns. Brendan's taser state machine is its own pattern (legacy from wave 2), kept untouched.
- **Why boss phase = PATTERN swap, not just HP gating**: the old "phase 2 = +20% speed" was invisible to a non-attentive player. Spawning adds + toast + archetype mutation makes the phase entry FEEL like a fight changing. Sells the rank-4 stakes.
- **Why fallen priest transforms the SAME entity (mutate in place), not spawn a new NPC**: continuity. The player has a relationship with father o'malley (visited him, possibly stole from him). Spawning a new NPC at the same position breaks the entity identity and the dialogue history. Mutating his id + archetype + stats preserves "this is the same priest, he just fell." The corpse on death is the same model — there is no priest to come back to.
- **Why TWO trigger paths and not just one**: the steal path rewards the player who already wronged the priest organically. The phone-call path opens the door for players who never tried stealing (a moralist run never sees the priest fall otherwise). Both converge on the same transform — the actual fall still requires walking into the church and steal-attempting, which gives the player one clear narrative beat ("you decide to do it").
- **Why HP 160 (double the priest's 80)**: he needs to survive long enough to use both phases. Phase 1 (ranged-holy) lasts until 50% HP, so on 80 HP that's a 40 HP window — barely enough to throw 3 vials. At 160, phase 1 lasts ~80 HP = ~6 throws = a real ranged section.
- **Why holy water = slow not stun**: stun stacks awkwardly on the grabber. Slow lets the player keep agency (still inputs, just sluggish), which is more interesting against a kiting enemy — you have to *try* harder to close, not stand frozen.
- **Why projectile pool cap = 40**: paranoia gate. Realistic max in normal play is ~4-6 alive at once (one ranged NPC throwing every 1.2-1.5s, projectiles last 4s). 40 is 10× headroom against pathological cases (multiple fallen priests, world-edge griefing).
- **Why projectile collision against solid buildings + world edge, not against NPCs**: friendly-fire would be funny once but undermine the AI cohesion ("paulie killed lurch by missing me"). Plus the math doubles the per-projectile cost.
- **Why hit-stun 120ms (not 200ms / not 80ms)**: 120ms is one frame past the human reaction threshold (~200ms). The player FEELS the hit-stun as chunkiness without noticing it as a freeze. Tested longer (200ms) — felt slow. Shorter (80ms) — invisible.
- **Why charger vulnerability bonus = ×1.25 (not ×1.5 or ×2.0)**: the cooldown window is already vulnerable (NPC doesn't attack during it). Stacking a damage multiplier rewards the dodge but doesn't trivialize the boss. ×1.5 would let you melt a charger in two cycles; ×1.25 keeps it at three.
- **Why priest_collar slot = hat (not collar/jewelry)**: existing slot system has 4 (shoes/hat/coat/tool). Inventing a "neck" slot for one item is overengineering. The collar reads as a head-area accessory; the +2 cred is the meaningful stat anyway.
- **Why wantedDecay on the collar (and not on something else)**: thematically the collar grants "the cops give you the religious benefit of the doubt." Mechanically it's a stat that has no other equipment representation yet — gives the collar a unique reason to exist beyond cred. Additive 0.3 (so manageCops decay rate goes from 1.0× → 1.3×) — a real but not gamebreaking effect.
- **Why phone call uses `ringPhone()` with a typeof-check fallback to `toast()`**: defensive — older code paths or save states might not have ringPhone wired. The toast fallback preserves the line. Quote-style line wraps the spoken portion in single quotes so it reads as dialogue inside the SMS-style frame.
- **Why cop radio cap = 4 / why only at d>120**: 4 cops is "manageable swarm" — more makes the screen unreadable. The d>120 gate prevents a melee-locked cop from calling backup mid-grapple (would feel cheap).

### TRIED, ABANDONED

- Considered making the swarmer's sibling DIFFERENT (e.g. a male relative with a different palette). Abandoned: the joke is "another one shows up. it has the same haircut." A different sprite undermines the gag. Same model + offset reads as funnier and is one fewer thing to maintain.
- Considered giving the ranged archetype an ammo counter (5 bottles, then he stops). Abandoned: the throw interval is already a soft limit. Ammo would add an inventory + reload cycle that breaks the unit's silhouette.
- Considered making holy water a stackable slow (each vial adds 500ms). Abandoned: stacks the slow into unplayability if the priest lands 3 vials in a row. Capping via Math.max preserves the single-vial difficulty curve.
- Considered the fallen priest dropping the holy water vials as throwable consumables for the player. Abandoned: adding a player-side throw system + new inventory item + a UI for it is wave-6 scope. The collar is the right-size reward for the scope.
- Considered making the boss phase transitions stackable (tony p2 happens while p3 is also true if HP drops fast). Abandoned: the toasts overlap, the state mutations conflict, the boss roar triple-fires. Sequential `if (newPhase !== state.bossPhase)` gating is cleaner and the player rarely flies through both thresholds in one frame anyway.
- Considered putting the cop radio behavior on EVERY cop instance including brendan. Abandoned: brendan is already a mini-boss with the taser machine; layering radio would compound difficulty during a wanted spike. Generic cops radio, brendan does not.
- Considered making the fallen priest re-spawnable (kill him, he respawns 5min later as the regular priest). Abandoned: kills the finality of the FALLEN achievement and the quest closure. The pews are still wrong is the canon ending.

### COUNTEREXAMPLE HUNT

- Save from v13 wave 4 loads into wave 5: no archetype on existing NPCs in the save → falls through to default branch. ✓
- `n.archetype` typo (e.g. 'Charger' caps) → no branch matches, default fires. Safe failure mode. ✓
- Charger windup with player in walk-around-radius: windup vector locked at start → if player sidesteps before the lunge fires, lunge whiffs → `chargeLanded` false → DODGED_THE_LUNGE unlocks. ✓
- Grabber stun while smoking at the crate: smoke gate reads input independently of `P.stunT`? Verified — `P.stunT` gates movement/SPACE/E in their handlers; blockMenu has its own button-click path. Player can still smoke through grab (canonical comedy: the crackhead doesn't even feel it). ✓
- Swarmer with already 2 live siblings: `spawnSwarmerSibling` guards `if (liveSwarmers.length >= 2) return`. No spam. ✓
- Ranged paulie throws into a building: projectile collides on next frame → despawned, no damage. ✓
- Holy water lands on player who is already slowed: `P.slowT = Math.max(P.slowT||0, 1500)` → no stack, just refreshed. ✓
- Tony phase 2 entry while berserk-already (impossible state but) → guarded by `newPhase < 2` check, no re-entry. ✓
- Brutus older p2 swarm spawn while already at cap → `liveSwarm.length < 2` guard skips the spawn. ✓
- Fallen priest call already fired but flag wiped (legacy save) → `state.flags.omalleyFallen` guard prevents re-trigger. ✓
- Fallen priest call fires while intro NOT done → `!state.flags.introDone` returns early. ✓
- Quest path: rank3 + church-visits=3 but priest already dead from steal path → guard `state.flags.omalleyFallen` returns early. ✓
- Steal path: priest never visited 4 times → menu branch not present. ✓
- Player kills priest BEFORE phase 2 (high burst damage at >50% HP): phase 2 toast still fires from a death handler? Checked — phase 2 transition is HP-threshold-based; if death undercuts 50% by overkill, phase 2 fires once on the same frame. Toast lands. OUTRAN_THE_PRIEST counter resets at death so it doesn't fire. ✓
- OUTRAN_THE_PRIEST timer with fallen priest off-screen but alive: counter still increments (it tracks alive-on-map, not visible). At 60s tick the achievement fires whether priest is visible or not. ✓
- Collar pickup with hat slot already occupied (pigeon_crown): old hat returns to inventory, collar binds. Same pattern as other hat equips. ✓
- Wanted decay with collar equipped at wanted=0: still 0, multiplier on 0 is 0. No glitch. ✓
- Save mid-cookmini + boss phase transition: phase state is on `state.bossPhase`, persisted; cookmini is not persisted. Reload drops you to playing with boss at last saved HP + phase. ✓
- Cop radio with COP_HARD_CAP=4 already alive: spawnCop guard skips. ✓
- Projectiles array hits the 40 cap (paranoia): `projectiles.splice(0, ...)` drops oldest. No leak. ✓
- Projectile vs world-edge despawn while damaging — order matters: collision check runs BEFORE life-decay/edge despawn. Damage applied first, then despawn. ✓

### NEXT

- The cop radio cap at 4 might be too low for late-rank players who can solo 4 cops easily. Watch for "wanted level feels weightless past rank 4."
- The fallen priest fight is balanced for ~rank 3 (the trigger gate). A late-game player at rank 5+ may stomp it. Possible: scale `n.maxHp` by `1.0 + (P.rank-3)*0.25` at transform time.
- Holy water `slow` is only used by the priest. If another ranged enemy gets added (gunner? sniper?), reuse the slowMs param rather than inventing a new status.
- Projectile system has room for a 3rd kind (`coin`? for the conductor? `bottle_thrown_back` for a reflect mechanic?) — generic enough that adding is just a new kind switch + render branch.
- Watch for boss phase 2 + brutus_older p3 adds compounding offscreen: if a brutus_older p3 fight is going while tony p2 fires elsewhere, 4 sherri swarmers could coexist. Cap is per-fight scoped; consider a global swarmer cap if it becomes a problem.
- v13 wave 6 backlog: tweaker vision (#3), boss music (#11), unique BARB sprite (#1 — still pending from wave 2 era — wave 2 partially addressed via palette).

### GOTCHA

- The `priest_fallen` archetype branch is the longest of any single archetype — ~90 lines including both phases. If a 3rd phase is ever added, factor the phase-1 and phase-2 helpers into separate functions.
- `n.berserk` is a flag, not an archetype. Berserk chargers still match `arch === 'charger'`. Worked correctly because berserk tunings are layered on top of the charger tunings in the same branch.
- `P.stunT` reads as 0 when undefined; all sites use `Math.max(P.stunT||0, x)` for safety. Same for `P.slowT`.
- The fallen priest phone call uses `ringPhone({from:'unknown number', ...})`. If `ringPhone` becomes a real ring-back loop in a future wave, the unknown-number sender will need a non-callback identity (it's not in CONTACTS).
- The `priest_collar` `wantedDecay` field is read by `manageCops` (line ~3536) as `wantedDecayMult` — additive to base 1.0. Forward-compat: a future item that also reduces wanted decay should add to the same multiplier, not invent a new field.
- Boss phase machine assumes `state.bossPhase` exists on save load. Default-init to 1 in `loadGame` (verified, otherwise the `< state.bossPhase` check NaN-fails).
- `OUTRAN_THE_PRIEST` counter uses `state.counters.omalleyFallenSurviveT`. Don't accidentally reset it in a generic `state.counters = {}` reset path (none exist currently, but flag for future refactors).
