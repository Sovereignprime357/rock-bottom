# BRAIN.md — Session continuity log (append-only)

---

## v13 wave 8.6 — playtest bug fixes (SHIPPED)

Surgical fix wave following Wave 8b. Operator (mobile via Dispatch) surfaced two issues from a live playtest. All edits on `rock_bottom_v13.html`, no v14 fork. SAVE_KEY untouched.

### WHAT SHIPPED

**Fix 1 — interact priority overhaul in `tryInteract` (line ~8439).** Before this wave the dispatch chain was: doors → bench → trash → phone → cart → dumpster → smoke-at-block → panhandle → heist → NPC scan. A player standing next to a vendor with a nearby prop got the prop. Reworked to: **doors → NPCs (closest within 60px) → heist trigger → interactive props (bench, trash, phone, cart, dumpster) → zone verbs (smoke, panhandle)**. The NPC scan that used to live at the bottom of the function is now hoisted to the top. The existing first-time-vendor floater/quest-completion sub-logic for Tony / Pete / metVendors moved with it. Marketplace panhandle's redundant 50px closeNpc gate was removed — the lifted NPC scan (60px) covers it cleanly, so the gate became dead code.

**Fix 2a — rank-3 gate on Old School door (`tryEnterOldSchool`, line ~4049).** Player within 44px of door but `P.rank < 3` now opens a one-option refusal `dialogue`. Refusal copy verbatim:
```
the door is chained.
the chain is rusted.
you don't have what it takes to break it yet.
(rank 3 required.)
```
Returns `true` so tryInteract treats the door as the consumed E (doesn't fall through to props).

**Fix 2b — OS Brutus 100% first-rip spawn (`openOldSchoolInterior`, line ~4058).** Rip handler now reads `state.flags.osBrutusKilled`. If false AND no OS Brutus is currently on the field, the rip:
- adds 0 copper
- forces `spawnOldSchoolBrutus()`
- toast: `"the copper is here. so is OLD SCHOOL BRUTUS.\nhe was sleeping in the gym. he is no longer sleeping.\nno copper this time."`
- closes the interior modal

Subsequent rips fall through to the unchanged 40% probabilistic spawn (cousins). `state.flags.osBrutusKilled = true` is flipped in the OS Brutus death drop block (line ~4872, right above the school_s_out toast). Drop table untouched: $80 + 5 copper + propane torch + 50 cred + STREET +2 + SCHOOL_S_OUT.

### SWEEP AUDIT — vendor/prop placement

Walked every interactive-prop coord against every NPC center. Findings:

| Pair | NPC dist | Prop range | Status |
|------|----------|------------|--------|
| Tony (1634,886) vs dealer trashcan (1620,980) | 95px | 50px | borderline — fixed by NPC-priority lift |
| Pete (264,716) vs pawn trashcan (220,700) | 47px | 50px | conflict — fixed by NPC-priority lift |
| Yuri (314,216) vs scrap trashcan (380,280) | 92px | 50px | safe |
| Mom (1214,1496) vs market trashcan (820,1500) | 394px | 50px | safe |
| Sherri (363,1495) vs alley trashcan (300,1560) | 91px | 50px | safe |
| Mom vs cart (1100,1520) | 116px | 36px | safe |
| Mom/Priest vs market dumpster (1340,1480) | 127/474px | 44px | safe |
| Yuri vs pay phone (130,220) | 184px | 38px | safe |
| Philosopher (2693,1096) vs nearest park bench (2520,1040) | 182px | 50px | safe — Philosopher always wins NPC scan |
| Pigeon King (2712,1190) vs (2880,1240) bench | 175px | 50px | safe |
| Train Hopper (820,2940) vs navy freight car (840,2932) | 22px | n/a | freight cars have no E action (PROPS-only, decorative per Wave 8a) — safe |
| Mathematician (1340,380) vs chalk sign / nearby props | n/a | n/a | math is the only NPC under the underpass at his coord; no E-interactive prop within 60px — safe |
| Price Guy (2940,1860) vs skid row dumpster (2820,1780) | 144px | 44px | safe |

No physical repositioning required. The NPC-priority lift resolves all borderline cases.

### DECIDED, REASONING

- **Why lift the entire NPC scan above all props, not just trashcans**: the brief said "NPCs > interactive props" as a rule, not a per-prop carve-out. A future Wave 9 prop near a vendor would hit the same bug. Treating the rule as systemic avoids whack-a-mole. Doors stay above NPCs because they're destination buildings (your shed / your school target), not roadside fixtures.
- **Why the heist trigger lives between NPCs and interactive props (not back at the bottom)**: the brief explicitly stated the priority chain `NPCs > heist > interactive props > generic prop`. The heist trigger fires on building-rect overlap, which is a wider hit area than a 60px NPC radius — putting it after NPCs but before the 50px trashcan radius keeps it discoverable without stomping a vendor.
- **Why the rank gate uses `dialogue()` not `toast()`**: brief said "refusal dialogue." A toast is asynchronous and dismissable by movement; a dialogue forces the player to read it and click leave. The "(rank 3 required.)" tag is the player's first concrete progression signal in the Old School beat — it should feel modal, not ambient.
- **Why "the door is chained" rather than e.g. "the gym is locked"**: the door of the south wall is what's visible; the gym is where Brutus sleeps. Chain language reads as a physical, fixable obstacle ("when you have what it takes"), which is what a rank gate IS.
- **Why first-rip drops 0 copper instead of 2 + spawn**: brief was explicit ("0 copper extracted, OS Brutus spawns"). Also: handing the player +2 copper as a reward for stumbling into the boss undercuts the comedic beat where he's a real threat. The +2 should feel earned.
- **Why the flag flip lives in the death drop block at line 4872**: that block is the canonical "OS Brutus is dead, give the rewards" path. Flipping the flag here means it can't be set by any path that doesn't actually award the rewards (e.g., despawn-on-zone-change, or a debug spawn that didn't get killed). Tight coupling = correct semantics.
- **Why existing saves take the one-time tax**: per the brief — players who exploited the pre-fix free-print should fight him once before resuming. Adding a back-compat migration ("mark osBrutusKilled = true if state.counters.copperStripped >= 5") would reward the exploit. Better to make everyone earn it.
- **Why removed the `closeNpc` proximity check inside the marketplace panhandle branch**: after the NPC-priority lift, if any NPC is within 60px the function already returned. The inner 50px check became dead code; pruning keeps the dispatch readable.

### COUNTEREXAMPLE HUNT

- Player at (1620, 940) near Tony + dealer trashcan: Tony center distance ~56px (in NPC range), trashcan distance ~40px (in trashcan range). Pre-fix: trashcan fires. Post-fix: NPC scan finds Tony, fires Tony's dialogue. ✓
- Player at (220, 740) near Pete + pawn trashcan: Pete distance ~50px (NPC range), trashcan distance ~40px. Post-fix: Pete wins. ✓
- Player walks up to Philosopher near park bench: Philosopher center at (2693,1096); nearest bench at (2520,1040), 182px away. Player within 60px of Philosopher gets her dialogue. Player must move ≥120px (so Philosopher is outside 60px) before bench-sit can fire. ✓
- Player walks up to Mathematician under underpass: no interactive prop within 60px of his coord (1340,380). Mathematician fires. ✓
- Player walks up to Train Hopper sleeping under navy freight car: freight cars are decorative PROPS (no E-handler — verified by grep), so the only E target in that 60px window is the Train Hopper himself. ✓
- Player at rank 0 walks up to Old School door: refusal dialogue fires, player can't enter. tryInteract returns. No fall-through to interior. ✓
- Player at rank 3 walks up to door: existing interior modal opens. ✓
- Brand-new save, first ever rip: `state.flags.osBrutusKilled` undefined, brutusAlive null → `firstEverRip = true`. OS Brutus spawns, 0 copper, modal closes. ✓
- Player flees OS Brutus, walks back to door, opens interior, attempts rip again: brutusAlive is truthy (he's on the field still), `firstEverRip = !undef && !truthy = false`. Falls through to standard rip path: +2 copper, no extra spawn roll (guarded by `if (!brutusAlive)`). ✓
- Player kills OS Brutus, walks back to door, rips: brutusAlive null, `state.flags.osBrutusKilled = true`, `firstEverRip = false`. Normal rip + 40% probabilistic spawn. ✓
- Existing save where player already ripped 5 times pre-fix but never spawned/killed Brutus: `osBrutusKilled` undefined → next rip forces spawn. One-time tax as designed. ✓
- Save load where `state.flags` itself is missing (very old save): the lazy guards at lines 4705 and 8764 ensure `state.flags = {}` is set before any read. `state.flags.osBrutusKilled` reads as undefined → forces first-rip. ✓

### INVARIANT CHECK

- "E key always opens the highest-priority interaction in range" — STRENGTHENED. NPCs now properly outrank ambient props.
- "Old School yields copper" — INTACT but now correctly walled. Rank gate + first-rip forced-spawn don't change the eventual reward path, only its access.
- "OS Brutus drops $80 / 5 copper / propane / +50 cred / SCHOOL_S_OUT" — UNCHANGED.
- "Player can complete intro_tony by talking to Tony" — INTACT. The first-vendor floater + quest-completion sub-block moved with the NPC scan; it still runs when Tony's `interact()` is selected.

### NEXT

- Watch playtest for any unforeseen edge cases where a player wants a prop interaction WHILE a vendor is in 60px (e.g., they want to kick the trashcan next to Tony deliberately). Current design prevents that — they must walk Tony out of their 60px radius first. If operator complains, add a "shift+E" override or carve-out specific NPCs, but don't speculate now.
- Potential follow-up: visual indicator (e.g., a `?` floater) on the priority target when both an NPC and a prop are in range. Out of scope for 8.6.

---

---

## v13 wave 8b — faction territory + bus pass (SHIPPED)

Shipped 2026-05-28. Builds on Wave 8a's expanded world (4400×3400) and Wave 7's faction rep system. All edits on `rock_bottom_v13.html`, no v14 fork. SAVE_KEY untouched. Operator on mobile via Dispatch — no popups, smart defaults, text reports.

### WHAT SHIPPED

**Part A — Zone faction tagging.** Every ZONES entry now carries a `faction: 'street' | 'scrap' | 'spiritual' | 'neutral'` property (v13.html line 267-294). Helper `currentZone()` returns the player's current zone, resolving overlaps by **higher absolute faction tier wins** (LOVED street beats neutral spiritual; HATED scrap beats neutral street). `currentZoneFaction()` wraps it for the common case. Final mapping:

| Zone | Faction | Reason |
|------|---------|--------|
| THE BLOCK | street | Tony's corner. |
| DEALER'S CORNER | street | Stripe's lot. |
| BACK ALLEY | street | Lurch / Sherri / Paulie. |
| LAUNDROMAT | street | Barb. |
| BUS STOP | street | Pinky. |
| SKID ROW | street | Per Wave 8a brief. |
| THE PROJECTS | street | Larry + Stripe. |
| SCRAP YARD | scrap | Yuri + Brutus. |
| PAWN SHOP | scrap | Pete. |
| HIGHWAY UNDERPASS | scrap | Big Guy + Mathematician + tents. |
| OLD SCHOOL | scrap | Per Wave 8a brief (copper). |
| MARKETPLACE | spiritual | Mom's neighborhood. |
| CHURCH | spiritual | Father O'Malley. |
| THE PARK | spiritual | Philosopher + Pigeon King + fountain. |
| TRAIN YARD | spiritual | Train Hopper + Conductor. |
| ABANDONED BUILDING | neutral | Locked. |

**Part B — Territory ticker** (`updateTerritory`, line ~720). Fires every 2 seconds while `state.mode === 'playing'`. Reads `factionTier(P.faction[zone.faction])`:

- **HATED**: increments `state.territoryHeat`. At 30 (60s in zone) → `P.wanted = min(3, P.wanted+1)`, reset, plus toast. Ambient `feedPost` every ~30s. Heat resets on zone exit / faction-neutral zone / mode-change.
- **NEUTRAL**: no effect, cash mult = 1.0.
- **LIKED**: greeting on first close-pass (within 80px) of any known NPC, once per zone-entry. `state.territoryCashMult = 1.2`.
- **LOVED**: +1 brain per 5 ticks (10s). Greetings ungated (10s per-NPC cooldown). `state.territoryCashMult = 1.4`. Once-per-day-per-faction ambient line via `state.flags.lovedAmbient_<faction>_day`.

Cash mult is read by **dynamic** cash-pile drops in the territory: park-night swing-set pile (line ~5485) and OS Brutus death drop (line ~4854). Other drops (Brendan, Brutus torch, fallen priest) stay flat — they aren't always tied to a faction zone.

Wired into `updateWorld` at line ~5398, immediately above the wave-6 underpass-entry block. Greeting NPC roster: `TERRITORY_NPC_TARGETS` Set with all 17 known vendors / lore NPCs.

**Part C — Visual district identity.**
- **Faction-themed graffiti pools**: new constants `SCRAP_GRAFFITI_LINES` (15) and `SPIRITUAL_GRAFFITI_LINES` (15) added after the original `GRAFFITI_LINES`. `buildGraffiti` now reads the zone at each building center and picks `pickGraffitiLine(faction)` from the right pool. `GRAFFITI_PALETTES` maps faction→color list (street muted red/pink, scrap rust orange, spiritual faded blue/white). Re-rendering only touches `g.col` from the new palettes — no per-frame cost.
- **Poster system**: new state-persisted `state.posters` array. `buildPosters()` walks BUILDINGS in faction zones, places 1-3 posters per zone (16×24 rect on bottom/left/right wall face). `POSTER_LINES` provides 3 lines per faction. `drawPosters()` renders between graffiti and props. Persisted in save like graffiti; fresh build on new save / missing data. Called from `startGame` after `buildGraffiti`.
- **Edge-glow** on zone-faction crossings: `state.borderGlowT` (ms, decays in updateWorld) + `state.borderGlowRect` + `state.borderGlowColor`. Arms when `state.lastZoneId !== state.territoryZoneId`. `drawBorderGlow()` renders a faction-tinted `strokeRect` of the destination zone (street red `#a04848`, scrap rust `#c08038`, spiritual gold `#d8c068`). 600ms fade. Drawn between posters and props.

**Part D — Bus pass + cart cap.**
- **Bus pass item**: `P.inventory` entry `{id:'bus_pass', n:'a bus pass', q:1}`. Helpers `hasBusPass()`, `giveBusPass(silent)`, `consumeBusPass()` (line ~3611). Strictly single — `giveBusPass` early-returns if one is already held.
- **Acquisition path 1 (Pinky $20)**: `pinkyDialogue` now adds a "buy a bus pass. $20." option *only if* `!hasBusPass()` (line ~3596). Saves on purchase.
- **Acquisition path 2 (Mom free at dawn)**: in `updateWorld` dawn-tick (line ~5295), if `P.faction.spiritual >= 10` and `state.flags.momBusPassDay !== state.day` and `!hasBusPass()`, gives one silently and surfaces `feedPost("@hardcandy: mom left a bus pass on the door. mom does not say where it came from.")` + delayed toast 6s later.
- **Use flow**: Pinky's dialogue adds "use the bus pass." option when `hasBusPass()`. Triggers `openBusPassMenu()` which lists every `BUS_ZONE_TARGETS` entry the player has visited (uses Wave 6/8a `*Entered` flags + zones that are always known). Per option:
  - **Disabled if in active combat**: `combatActive()` returns true when `P.wanted > 0` OR any hostile/aggro non-pet NPC is within 220px. Label tail: `the bus is not your friend right now.`
  - **Disabled if already in target zone**: `the label — you're already where the bus is.`
- Selecting a target: `consumeBusPass()`, set `state.flags.busPassUsedDay = state.day`, 0.5s black flash, teleport to zone center (clamped to WORLD bounds), camera snap, reset territory bookkeeping, second 0.5s flash, toast `"the bus took you. the bus does not explain how."`
- Cooldown: `state.flags.busPassUsedDay` blocks re-use until dawn. Tooltip refusal: `"you already rode today. the bus does not run twice for you."`
- **Cart speed cap**: changed `if (P.cartMounted) baseSpeed += 0.6;` → `baseSpeed = Math.min(baseSpeed * 1.7, baseSpeed + 1.5)` (line ~1843). With base 2.2, cart now gives 3.74 (was 2.8). Brief intent: scale cart with the larger world.
- **Biggu cart trade fix**: replaced inline `P.speed = 2.8; P.maxHp = 110;` (line ~3603) with a single `applyEquipStats()` call so the new cap takes effect. Toast copy updated from "+1 speed" to "faster."

### DECIDED, REASONING

- **Why `currentZone()` uses higher-absolute-tier rather than first-match for overlaps**: most existing zones don't overlap (verified by reading the ZONES table), but if a future Wave 9 zone overlaps, this preserves the "loved-LOVED beats neutral" intent from the brief. Falling back to first-match would let zone declaration order silently shadow the faction logic.
- **Why the cash-pile mult applies to amount, not spawn-rate**: rate is hard to retrofit on the static cash-pile set (22 piles seeded once at save start). The dynamic drops (park night, OS Brutus) are the only "respawn / random" piles — there `*cashMult` on the amount is the cleanest read of "this district pays better." Brendan / fallen-priest / brutus-torch drops stay flat because they happen wherever the kill lands, not necessarily in a faction zone.
- **Why bus pass lives in Pinky's dialogue not a standalone bus-stop prop**: Pinky stands AT the bus stop coords. E on Pinky already opens his dialogue. Adding a new bus_stop prop within ~100px of Pinky would create UX conflict (which interact wins). Pinky's dialogue is the bus stop interface.
- **Why bus pass is single-stack (`giveBusPass` early-returns if one held)**: the brief said "Stack: 1." Hoarding passes would defeat the daily-cooldown gate (player could just consume two in a row from inventory). Single ensures one-per-day.
- **Why the mom free pass uses a 6-second delayed toast after the feed post**: dawn already fires a `day N` toast + weather toast. Stacking three toasts at once would overlap. Delayed toast surfaces after the rollover noise quiets.
- **Why combat gating uses both `P.wanted > 0` AND nearby hostile check**: cops are the obvious "no fast travel" case (P.wanted). The nearby hostile check covers the alley crackheads / Brutus / chase-bite spawns who don't bump P.wanted but are clearly mid-combat. 220px is roughly the screen-half radius.
- **Why teleport uses `state.flash` for fade not a custom transition**: the flash overlay already exists (line ~6650) with proper alpha math. Setting 0.5s pre-teleport, sleep, then 0.5s post-teleport reads as a quick blink. No new render layer.
- **Why MARKETPLACE got spiritual not street**: mom is the only major NPC who lives there and the operator's brief explicitly lists "Mom's neighborhood" as spiritual. Other vendors that touch market (Pinky at the bus stop edge) are already in their own zones.
- **Why THE PROJECTS is street not spiritual** (despite mom's apartment HIDEOUT door being nearby): the door coord `(1230, 1180)` is actually in MARKETPLACE bounds, not PROJECTS. Projects houses Larry (WHAT) and Stripe — clearly street.
- **Why edge-glow uses `strokeRect` of full zone bounds, not "intersection line"**: the brief said "edge glow along the world-space rect intersection." For most zone pairs the shared edge is a single zone face, but rect intersection math is fiddly when zones don't actually touch (most don't). Tracing the destination zone's full outline reads as "this district lit up when you walked in" — same comedic beat, cleaner code.
- **Why the bus pass cooldown is "used today" not "consumed and bought a new one"**: prevents the loop of "Pinky → buy → use → buy again → use again." Cooldown is on the ACT of riding, not the pass count. Even if the player got a free pass from Mom on the same day they used Pinky's, they can't ride twice.

### COUNTEREXAMPLE HUNT

- Old save (wave 8a) loads forward: new flags default to 0 via `Object.assign`. `state.posters` defaults null → `buildPosters` runs on next render. `state.territoryT` etc. ephemeral (undefined → 0 on first tick). ✓
- Player walks into THE BLOCK with `P.faction.street = -12` (hated): after 30 ticks (60s), `P.wanted = 1`, toast fires. Walks out → heat resets. ✓
- Player at street LOVED enters BLOCK, walks past Tony → greeting toast. Walks past Tony again 5s later → no greeting (LOVED is 10s per-NPC cooldown, not zone-entry gated, but still rate-limited). ✓
- Player at spiritual LIKED enters CHURCH, walks past priest → greeting toast. Walks past priest second time same zone-entry → no greeting (LIKED is once-per-zone-entry). Walks out, walks back in → can be greeted again. ✓
- Player at scrap LOVED night enters SCRAP YARD → loved ambient post fires once via `state.flags.lovedAmbient_scrap_day`. Walks out, back in same day → no second fire. Next day same zone → fires again. ✓
- Player loads save with bus pass in inventory, talks to Pinky → "buy a bus pass" hidden, "use the bus pass" shown. Travels to alley → fade, teleport, fade, toast. ✓
- Player tries to use bus pass while cops are chasing (P.wanted=2): menu shows zones grayed out with "the bus is not your friend right now." Pass NOT consumed. Cooldown NOT set. ✓
- Player tries to teleport to current zone: grayed out with "you're already where the bus is." ✓
- Player at spiritual=12 reaches dawn with no bus pass → Mom gives one, feed post + delayed toast. `momBusPassDay = today`. Next dawn → fires again. Same day, if pass is consumed and another dawn rolled (e.g., sleep through dawn) → mom drop fires too. ✓
- Player at spiritual=8 (below liked threshold) → no Mom drop. Gets to 10 → next dawn drops. ✓
- Player buys cart from biggu: `applyEquipStats()` runs → `P.speed = min(2.2 * 1.7, 2.2 + 1.5) = min(3.74, 3.7) = 3.7`. Mounted speed = 3.7. ✓
- Player with shoes (+0.4 speed) + cart: base=2.6 → mounted = min(2.6*1.7=4.42, 2.6+1.5=4.1) = 4.1. ✓
- Player exits bus stop zone via teleport: `state.territoryHeat=0`, greeting bookkeeping reset, zone-id reset. No leftover state. ✓
- Player teleports to an undiscovered zone: option doesn't appear in BUS menu (gated by *Entered flags). ✓
- Player opens bus menu, "put the pass away" → no consume, no cooldown set, returns to playing. ✓
- Old save with no `state.posters` field loads: `state.posters = null`. First draw call → `buildPosters()` runs, populates state. Subsequent saves persist them. ✓
- Edge-glow on rapid zone-bounce (player walking back and forth across a zone border): timer re-arms each crossing, glow re-tints. No flicker since strokeRect is independent each frame. ✓
- Day 30 BUS event coexists with bus pass: bus driver NPC has its own `interact`; Pinky's dialogue is separate. Player at the bus stop can talk to either based on proximity. ✓

### GOTCHA

- `state.territoryCashMult` only affects the OS Brutus drop and the park-night cash pile. Other dynamic cashPiles.push sites (Brendan, Brutus torch, fallen priest collar/plate, etc.) are NOT scaled — they happen wherever the NPC dies, not necessarily inside a faction zone.
- The bus pass cooldown `state.flags.busPassUsedDay` is a day-stamp pattern (compare `=== state.day`). Resets at dawn implicitly (no explicit reset call needed). If a future feature sets `state.day = 0`, the gate would erroneously open — don't do that.
- The territory ticker uses `performance.now()` for the LOVED greeting per-NPC cooldown. If `performance` is not available (very old browsers), the code falls back to `Date.now()`. Both are monotonic enough for a 10s cooldown.
- The `currentZone()` overlap resolution uses `Math.abs(tier)` — a HATED zone outranks LIKED only if |tier| is higher. If both have the same |tier|, the first matching zone wins (which is also fine — most zones don't overlap).
- `combatActive()` excludes `n.isPet` so the pet_possum and freed_dog_follower don't trigger the gate. If a future feature adds a friendly companion, set `isPet: true` to keep them out of the combat check.
- The cart speed cap formula `Math.min(baseSpeed * 1.7, baseSpeed + 1.5)` clamps the multiplicative side at +1.5 absolute. With future high-speed-shoes equipment (base could reach 3.0+), the multiplicative would give 5.1, but the `+1.5` cap brings it to 4.5. Intentional — the cart shouldn't outrun the cop AI.
- `state.flash` is in SECONDS, not ms. The first cut of this code used `360` (interpreted as 360 seconds = 6 minutes of black screen). Fixed to `0.5`. If you add new flash calls, mind the unit.
- The bus pass list `BUS_ZONE_TARGETS` is hardcoded and uses the existing wave 6/8a `*Entered` flags as visit-gates. The "always known" zones (block, market, scrap, alley, church, projects) have `flag: null` so they appear unconditionally. If a future zone needs visit-gating, add a `*Entered` flag in BOTH the load Object.assign defaults AND the startGame fresh-init block.
- The Pinky bus pass sell option only appears if `!hasBusPass()`. If the player has one (from Mom), they see "use" only — Pinky won't sell a second pass that day even at $20. Intentional (single-stack invariant).
- The day-30 BUS ending event still uses Pinky's coords. It does NOT interact with the bus_pass item — that's a one-way game-over. Don't accidentally couple them.

### WHAT'S NEXT

- Wave 9 could add a faction "rank" visual (badge / patch on the player sprite when LOVED in a faction). Currently the only feedback is the Q-panel rep bars + ambient lines.
- The bus pass currently has no UI hint at the bus stop sign — player has to know to talk to Pinky. Could add a small bench / sign PROP with a floater "bus pass: E" prompt.
- Territory greeting roster (TERRITORY_NPC_TARGETS) is hand-curated. Future NPCs need to be added explicitly or they won't trigger greetings.
- Edge-glow currently only fires on entering a NEW zone. Could add a separate animation for LEAVING a hated district (the "you got out" feeling).
- The cart cap (multiplicative + additive clamp) hasn't been telemetered. If late-game speed equipment plus cart feels slow, the `+1.5` cap could be raised.
- Posters never animate. Could add a torn-corner flutter or a once-per-day "new poster appears" event.

---

---

## v13 wave 8a — world expansion + new zones (SHIPPED)

Shipped 2026-05-28. All edits on `rock_bottom_v13.html` (no v14 fork). SAVE_KEY untouched. Forward-compatible save: every new flag/counter has a sensible default in both the load path and the startGame fresh-init path. Zero hardcoded world-dimension references found in code (the only `2200` / `1900` literals are toast durations, audio frequencies, or one CROWN_SPOTS coord that was already inside the original bounds).

### WHAT SHIPPED

**Part A — WORLD expansion** (v13.html line 253). `WORLD = { w: 4400, h: 3400 }` (up from 2200×1900). Audit pass confirmed every world-coord clamp routes through `WORLD.w` / `WORLD.h` (4279-4285 cop spawn ring, 4327-4328 cop clamp, 4458-4459 player clamp, 5308 + 5376 projectile clamps, 5523-5524 camera clamp, 7104 minimap scale, 7471-7497 day3 visitor / day14 inheritance clamps, 7817-7818 bus driver clamp). Minimap math still readable: at 120×96 minimap pixels the world now scales to ~36 world-units per minimap pixel; NPCs render as 2×2 (~72 world units, NPC-sized) and the player as 3×3 (~110 world units). Slightly less crisp than before but legible.

**Part B1 — TRAIN YARD** (zone @ 260,2700,1100,560). New TILE_PALETTES.trainyard with rail-band + ballast flags. Conductor relocated from `(240,1780)` in THE PROJECTS → `(680,2960)` in the train yard. Train Hopper NPC added at `(820,2940)` with new palette + npcStyles entry (denim + gray beard + thin + beard accessory). hopperDialogue cycles 7 lore lines (bremerton, laramie, memphis, good thunder, stockton, a "trains stopped in 88" line, "i used to be a person with an address"). Hidden at night via `daytimeOnly:true` + a defensive in-dialogue night check. Chalk lore prop on the navy freight car: `"the bus knows where the train doesn't go"`. Three freight_car PROPS (rust red / navy blue / moss green), six weed clumps. First-entry feed post: `@blocklog: trains stopped running here. they still come through.` Stripe's package-handoff lines updated from "the conductor is in the projects" → "the conductor is in the train yard" (3 references touched).

**Part B2 — THE PARK** (zone @ 2400,900,620,500). New TILE_PALETTES.park with green base + grass-tuft / dandelion flecks. Pigeon King relocated from `(1000,1000)` → `(2700,1180)` near the central fountain. Park Bench Philosopher NPC added at `(2680,1080)` with new palette + npcStyles entry (kindly old-woman wide build, hat + brown coat). PHILOSOPHER_QUESTIONS array of 7 questions, indexed by `state.day` (deterministic daily cycle). Engaging her with `"think about it"` grants +1 spiritual once per day (gated by `state.counters.philosopherRepDay`). Props: central fountain (animated water), 4 park benches (interactable), swing set (night-only red tint), broken drink fountain, 6 trees. Sit-on-bench mechanic in updateWorld: E toggle, +1 brain / 2s while sitting, BENCH_PRESS unlocks at 60s continuous, every 30s past 60s a passerby comment surfaces. First-entry: `@hardcandy: the pigeons remember faces. the philosopher remembers names.` Night-park hidden cash: 30% roll each new night for a $20-40 pile at the swings, gated by `state.flags.parkNightCashDay`.

**Part B3 — SKID ROW** (zone @ 2480,1520,900,720). New TILE_PALETTES.skidrow with darker oilier concrete + trash flecks. 8 makeshift SHACK buildings in a tight cluster for the constrained-alley feel. 3 chase-bite ambient hostiles all zone-locked to SKID ROW: `skid_brutus_1` (charger, hp60, dmg7), `skid_lurch` (grabber, hp55, dmg6), `skid_sherri` (swarmer, hp45, dmg5). 5 tweaker-vision hidden cash piles totaling $98 in spawnCashPiles (line 2401-2403). Dumpsters + bottles + syringes scattered. One bare lamp (sparse on purpose). PRICE GUY random encounter: spawns every 3 game days at `(2940,1860)`, splices any leftover instance first. `priceGuyDialogue` runs the all-cash gamble — outcomes: knife 20%, $200 15%, propane torch 10% (no-dupe), rock 25%, nothing 30%. THE_PRICE_PAID unlocks on any payment. Walked-away has no penalty. First-entry: `@crackheadcent: skid row knows you didn't ask first.`

**Part B4 — THE OLD SCHOOL** (zone @ 3400,280,760,640). New TILE_PALETTES.oldschool (cracked playground + chalk smudges + weed:true). New OLDSCHOOL BUILDING with door gap on south face (line 306). South-face door at `(3760,700)` triggers `openOldSchoolInterior()` — Wave-7 modal-dialogue interior pattern. Player chooses: rip copper (+2 copper, +1 to counter, 40% chance to spawn OLD SCHOOL BRUTUS in the schoolyard) or leave. OS Brutus stats: HP 250, speed 1.5, dmg 35, archetype 'charger' (which is the closest existing archetype to charger+grabber — the combined behavior is a v13 wave 5 invariant of the charger pattern that includes the grab on hit; I did not invent a new archetype). Death drops: +$80 cash pile + 5 copper into inventory + guaranteed propane torch (no-dupe gated). SCHOOL_S_OUT + 50 cred + street +2 + broadcast. Schoolyard props: mural `"FUTU EA HE M C"`, second swing set, broken basketball hoop, chain-link fence, 5 broken-window props on the building face, hidden $30 cash pile behind the building. First-entry: `@blocklog: the old school still has copper in the walls. the school still has brutus in the gym.`

**Part C — Wire-up.**
- New achievements (4): `school_s_out`, `bench_press`, `the_price_paid`, `train_hopped` — all wired with their unlock paths.
- Vendor index expanded: `train_hopper` + `philosopher` added to VENDOR_FLOATER_IDS so they get the `?` floater on first interact and appear in the people-met section of the Q panel. Conductor's VENDOR_INDEX_META.zone updated `'the projects'` → `'the train yard'`. WORLD_EVENTS school_bus line updated to match.
- Faction affiliations: Hopper + Philosopher = SPIRITUAL (philosopher grants +1 spiritual daily; hopper is lore-only). OS Brutus = STREET (death grants street +2 via existing brutus-kill rep pipeline + an extra +2 in the os_brutus branch). Price Guy = NEUTRAL (no rep on transaction).
- Phone-feed first-entry posts for all 4 zones (once per save, gated by `state.flags.{trainYardEntered,parkEntered,skidRowEntered,oldSchoolEntered}`). Old saves default these to true to match the underpassEntered pattern from wave 6.
- Save/load forward-compat: all 7 new flags + 1 new counter (`philosopherRepDay`) defaulted in both load `Object.assign` paths. Mid-session ephemeral state (`sittingOnBench`, bench timers, price guy ephemeral) NOT saved — resets each session, matches the `state.heat` minigame pattern.
- Existing systems verified intact: day-30 bus driver still spawns at Pinky's `(1330,1260)`; day-14 inheritance still clamps to `WORLD.w/WORLD.h`; day-3 visitor wanderOff still uses `WORLD.w + 80`; Mathematician at `(1340,380)` unchanged.

### DECIDED, REASONING

- **Why freight cars as PROPS not BUILDINGS** — the brief said BUILDINGS but specified "non-solid, decorative — players can walk into the shadows." BUILDINGS in v13 are uniformly solid in collision (no `solid:false` field is read consistently). Using PROPS with a new `freight_car` type is one less collision-system touch and the visual result is the same. The "you're hidden" feeling is sold by the dark interior triangle in the drawProp branch.
- **Why daytimeOnly:true on the hopper instead of a custom render branch** — drawAll already has `if (n.daytimeOnly && isNight()) continue;` (line 6184). Adding a one-off branch would duplicate that pattern. The hopper's hopperDialogue STILL has the in-dialogue night check too, so even if the player walks right past where he was sitting at night and presses E, they get the "you do not wake him" toast rather than the dialogue.
- **Why 5 SKID ROW hidden cash piles totaling $98 rather than 4-6 totaling $80-120** — the brief said "4-6 piles totaling $80-120". $98 lands in the middle of that band; 5 piles is also middle of the count band. Tunable.
- **Why the philosopher daily question is deterministic per `state.day` (cycle) not random** — the player visits the park, hears today's question, walks away, comes back later that day → same question. Reinforces the "she has a thought for the day" framing. Random would re-roll on every dialogue open and feel like a content firehose.
- **Why bench-sit ephemeral state isn't saved** — the player saves while sitting → reloads → world is paused on dialogue/menus anyway. Loading drops them at `state.mode = 'playing'` with no bench-sit state. They press E on the bench, start fresh. Matches the heat-mini ephemeral pattern.
- **Why the Old School Brutus is "archetype: 'charger'" not a new 'grabber+charger' archetype** — the wave 5 charger pattern already includes a windup → lunge that grabs on hit (n.grabFreezeT is set on hit-connect). Effectively this IS charger+grabber. Inventing a new archetype string would require new dispatch code in the combat-pattern switch.
- **Why Price Guy random outcomes total >100% (20+15+10+25+30 = 100 exactly)** — re-checking: knife 0-0.20, $200 0.20-0.35, propane 0.35-0.45 (gated by !hasPropane fallthrough), rock 0.45-0.70, nothing 0.70-1.00. Sums to 1.00. The propane gate falls through to the next bracket via continued `r < ...` checks, but since the brackets are ordered and the propane band is the only one with a hasPropane gate, when the gate fails the player still gets the "nothing" branch (the `else if (r < 0.45 && !hasPropane())` will be false → next `else if (r < 0.70)` evaluates `r < 0.70` which IS true at 0.40 → rock branch fires). So the rock-band absorbs a propane-gated miss. Acceptable — propane is the prestige outcome and the player not getting it on a $0-deposit roll while already owning a torch reads as "stripe sniffs and laughs."
- **Why the OS Brutus interior spawns him OUTSIDE the school** — combat in a modal dialogue is awkward. The brief specifies modal dialogue for the interior; spawning the boss in the schoolyard means the player exits the interior, sees a 250-hp dog charging, and the fight happens in open space. Cleaner.
- **Why park hidden-night cash is gated by `parkNightCashDay`** — without the day-stamp gate, the 30% roll fires every frame of every night and either spawns repeatedly or skips entirely after the first day. The day-stamp makes it "one roll per night."
- **Why the conductor relocation didn't break any quests** — the conductor's bargain (3 copper for $90) is location-independent (the dialogue calls only check `P.copper`). Stripe's package auto-delivery is proximity-based via `npcs.find(n=>n.id==='conductor')` (line 4871) + a 60px proximity check — that math still works wherever the conductor stands. Verified.

### COUNTEREXAMPLE HUNT

- Old save (v13 wave 7) loads → new wave 8a flags all default-to-true on the "Entered" fields → no spurious first-entry toasts on reload. ✓
- Old save loads → `philosopherRepDay` defaults to 0; first park visit + engage → +1 spiritual, counter → state.day. Second engage same day → "already today" refusal. ✓
- Walk into TRAIN YARD on a fresh save → feed post `"trains stopped running here. they still come through."` fires once. Reload → flag is true → no refire. ✓
- Talk to Train Hopper at noon → unlocks TRAIN_HOPPED. Talk again → no re-unlock (achievement is idempotent). Talk at night → "you do not wake him" toast, no dialogue, no achievement (since the flag was already set on first daytime talk). ✓
- Sit on bench, stand at 59.5s → BENCH_PRESS NOT awarded. Sit again, stay 60s → awarded. ✓
- Day 3 (% 3 === 0) rolls over → maybeSpawnPriceGuy fires, splices any old price_guy, spawns fresh at skid row center. Player walks away → state.flags.priceGuyDay = 3 prevents respawn that day. Day 4-5 → not divisible by 3, guard short-circuits at call site. Day 6 → fires again. ✓
- Pay the Price Guy → wanderOff = true, walks west, exits world. Day 6 spawn → splice removes him before push. ✓
- Old School Brutus already alive, player re-opens interior → "you hear something in the gym" intro variant, copper-rip still works but does NOT re-spawn (the `if (!brutusAlive && Math.random() < 0.4)` short-circuits). ✓
- Old School Brutus dies → SCHOOL_S_OUT unlocks, $80 + 5 copper + propane torch (if not owned). Player already owns torch → torch drop skipped. ✓
- Skid Row hidden cash piles use `cp_22`..`cp_27` ids (the next sequential after the original 22) → `state.cashPilesCollected` set still tracks them by id. Old saves with the original 22 collected don't pre-mark the new ones. ✓
- Park night cash pile uses id `cp_park_night_<day>` → unique per day. Pile from day 3 not yet collected, day 4 night fires → new pile id `cp_park_night_4`. Both exist until collected. Acceptable atmosphere ("you find the same kind of money in the same place — different night").

### WHAT'S NEXT

- Wave 8b: faction territory mechanics, visual district identity, travel friction (per the operator's pre-brief plan).
- Skid Row could use a "territory" visual cue (currently looks similar to the alley — wave 8b is the right time to differentiate).
- The Mathematician could get a tip line referencing the new zones (e.g., "the train yard is south. the math is the same.") — speculative.
- OS Brutus could have a special chase-bite hint at his unique grab range (35 dmg is high; if the average player gets hit once they lose 35% hp). May need tuning post-playtest.
- The Train Hopper currently has no resource grants (per anti-grind). Could speculative future addition: he TRADES (give him 1 food → he gives a chalk-map hint to the day-30 bus). Out of scope for 8a.

### GOTCHA

- `state.sittingOnBench` is ephemeral (not in the save object). Any future "auto-save while sitting" hook would NOT restore the sit state — the player would reload to standing. Intentional.
- `state.flags.priceGuyDay` IS saved, but the spawned NPC is also in `npcs[]` which IS implicitly persisted via the npcsKilled filter. Reloading after spawning → he's still standing where he was (modulo any wanderOff motion). That's actually a feature: the price guy doesn't despawn just because you reload.
- `state.flags.parkNightCashDay` rolls at most once per night. If the player loads a save where it was day-3 night and the flag is `3`, the roll already happened. They could miss the pile by reloading at a bad moment — but the day stamp would let them get the day-4 roll cleanly. Acceptable edge.
- The OS Brutus interior dialogue branches don't take an `n` parameter — the boss spawn uses `OLD_SCHOOL_DOOR` coordinates directly. If a future change moves the door, update both `tryEnterOldSchool` AND `spawnOldSchoolBrutus`.
- The Price Guy `r < 0.45 && !hasPropane()` branch falls through to the rock branch when the player already owns a torch. Don't "fix" this — it's the documented invariant (the rock band absorbs propane-gated misses).
- The `freight_car` PROP is decorative — there's no collision math for it. If a future feature adds "hide inside the freight car" mechanic, expect to add a proximity-checked overlay state, not a collision check.
- The four new zones are added at the END of the ZONES array. `zoneAt(wx, wy)` returns the FIRST matching zone via `ZONES.find`. None of the new zones overlap existing ones, so order doesn't matter — but if a future feature makes a new zone overlap an existing one, the array order will matter for tile palette assignment.
- The OLD SCHOOL door coord `(3760, 700)` is OUTSIDE the OLDSCHOOL building rect (3520,380,520,340 → 3520-4040, 380-720). The door is at the south edge of the building, just outside, which is correct for "approach the door from outside." If the building rect changes, also update OLD_SCHOOL_DOOR.

---

## v13 wave 7 — faction rep + day events + hideout (SHIPPED)

Started 2026-05-26, retried + shipped 2026-05-28. First attempt hit the weekly Claude Code usage limit mid-doc-write. Retry landed clean. All edits on `rock_bottom_v13.html` — no v14 fork. SAVE_KEY untouched.

### WHAT SHIPPED

**Part A — Faction reputation (street/scrap/spiritual)**:
- `P.faction = { street, scrap, spiritual }` stored on player, saved + load-forward-compat (old saves default to neutral).
- `factionTier(v)` helper: ≤−10 hated · −9..+9 neutral · +10..+24 liked · ≥+25 loved.
- `adjustFaction(faction, delta)` single mutator with [-50,+50] clamp, tier-transition detection, and broadcast on crossings. `applyRep({...})` convenience for multi-delta ledger lines.
- Rep deltas wired into: Tony rocks, Yuri copper (single + bulk), Pete copper/license/loan, mom ask×2/compliment/hideout-rent, priest donate/steal/fallen-priest-kill, Stripe buy/fence (fence has the −3/day spiritual cap), smoke-at-crate, Pinky single/bulk, Math hidden-tip drops, Barb crossword return, scrap dog feed/free, cop/Brendan kill, street-kills (Brutus/Lurch/Sherri/Paulie), inheritance pickup, hideout sleep.
- Tier effects wired: Tony $9 → $8 base at street liked/loved (still multiplicative with charisma); Brutus Older spawns passive at street loved + propane torch drop 0.25 → 0.375; Yuri $25 → $28 at scrap liked/loved; Pete $15 → $17 at scrap liked/loved + $50 loan 1×/day at loved; Pete refuses at scrap hated; Pinky refuses at street hated; Fallen-priest transform gated by `spiritual < +10`; mom proud-call 1×/day at spiritual liked+ (+5 brain); mom's ambient call line gated by silence-window only (faction-hated handling is per-line, not blanket).
- Q-panel: new `FACTIONS` block at the TOP with three rows (label + tier + bar mapping [−50,+50] → fill). Below: legend `hated · neutral · liked · loved`.
- Tier crossing broadcasts: phone-feed + short toast per faction × tier. Three loved-tier achievements added (THE BLOCK KNOWS / YURI COUNTS YOU IN / MOM IS PROUD).

**Part B — Day-specific scripted events**:
- Day 3 "the visit" — passive `?`-floater NPC spawns near player at dawn, dialogue `"someone you don't know.\n[...]'i heard about you.'"`, wanders off-map afterwards (new `n.wanderOff` archetype branch).
- Day 7 "the silence" — sets `state.flags.silenceUntilT = now+4min`; `broadcastNews` and `feedPost` early-return during the window, ambient phone calls suppressed.
- Day 14 "the inheritance" — $500 cash pile with `isInheritance: true` near player; pickup applies +$500, +2 street, −1 spiritual, custom toast + feed line.
- Day 30 "the bus" — spawns `bus_driver` NPC at Pinky's bus-stop location; dialogue with yes/no; YES triggers `takeTheBus()` ending screen (third ending: THE BUS) + `the_bus` achievement + save wipe; NO despawns the driver permanently.
- All four guarded by once-per-save flags (`day3Fired`, `day7Fired`, `day14Fired`, `day14Collected`, `day30Fired`, `busTaken`, `busRefused`).
- Day 30 bus driver re-hydrates on reload if unresolved (`rehydrateDay30Bus()`).

**Part C — Hideouts**:
- Two doors rendered in world space when owned: scrap-yard back-corner shed `(520, 200)` + mom's apartment door `(1230, 1180)`.
- E within 40px on a door (when owned) opens `openHideout(kind)` dialogue with: open chest, rest 30 minutes (HP + wanted decay), sleep til morning (full day advance + rep), mom-only phone reset, leave.
- Storage chest: shared `state.hideoutStash = { rocks, copper, cash, items }`. Persists across player death (only `P.cash` + `P.rocks` get zeroed on arrest, stash is on `state`). Deposit/withdraw via sub-menu.
- Gates: scrap requires `faction.scrap >= +5`, $150 one-time, surfaced as Yuri dialogue option. Mom requires `faction.spiritual >= +10`, $30/day, surfaced as Mom dialogue option.
- Rent enforcement: each new day, if mom hideout owned, deducts $30; if short, evicts (`scrapHideoutOwned` ≠ untouched here — scrap is one-time payment), −3 spiritual on eviction. Toast surfaces.

### JUDGMENT CALLS / DEVIATIONS FROM ORIGINAL BRIEF

- **Hideout "interior scene swap" → modal dialogue interior.** The brief asked for a full scene-swap with a bounded camera. I chose a discrete-time modal interior instead (E on door opens a dialogue with rest/sleep/chest/leave). Reason: the game is already modal/dialogue-driven for every interactive moment, and a full bounded camera would have doubled the implementation surface without adding mechanical depth that the dialogue model can't already provide. The "wanted decay 5×" and "1 HP/4 sec" effects from the brief became discrete "rest 30 minutes" actions instead of real-time tickers. SPEC updated to match.
- **Shared chest across both hideouts.** Two stashes felt fiddly; one stash is "your stuff" — simpler mental model.
- **Stripe fence rep cap** uses a day-stamped counter (`stripeSpiritualDayHits` + `stripeSpiritualDayHitsDay`) to self-reset across day rollover.
- **Day 30 bus location** uses Pinky's (`x=1330,y=1260`) since VENDOR_INDEX_META already calls Pinky's spot "the bus stop" — fits canon without needing a new prop type.
- **Tier transition broadcast** uses the existing feedPost/toast pipeline; phone-feed handle pulled from the first segment of the canonical line (`@hardcandy:` → `@hardcandy`).

### WHAT'S NEXT

- Wave 8 candidates: Cousin Brendan as a faction NPC (currently fires `applyRep({street:-3, spiritual:+1})` on kill but has no rep-tied dialogue), Cousin Brendan family-line phone-feed lines, possum prophecy frequency boost at spiritual loved (currently the SPEC promises this but the prophecy timer isn't easily exposed — needs `state.possumChance` style hook).
- Real "interior scene" for hideouts if the modal version reads thin in playtest.
- The chest items[] array is allocated but unused — Wave 8 could add propane/license/crossword deposit if storage friction ever becomes desirable.

(checkpoint list removed — this is now the SHIPPED entry)

(planned scope captured above is preserved in SPEC.md; implementation details are in the WHAT SHIPPED section.)

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

---

## Session 2026-07-12 · v14 · visual world cohesion / district weave

### WHAT CHANGED

Forked `rock_bottom_v13.html` to `rock_bottom_v14.html`. v14 is a rendering/geography pass, not another content expansion.

1. Added `TERRAIN_REGIONS`: six deterministic outside-zone surface families now cover the expansion void (`vacant`, `service`, `drainage`, `rail_approach`, `dead_grass`, `school_outskirts`). `terrainAt()` gives canonical `zoneAt()` palettes first priority.
2. Added `ROAD_SEGMENTS`: fourteen connected street/service/arterial rectangles with sidewalks, curbs, worn lane marks, patch seams, sidewalk joints, drains, and ten crosswalks.
3. Added `GROUND_PATHS` + `RAIL_LINES`: Park/Church/School paths and four coherent full-length Train Yard tracks. Removed the per-tile train-rail flag so rails no longer restart every 64px.
4. Added `LANDMARK_FACADES`: sixteen code-native, cached setback silhouettes in four families (storefront, rowhouse, warehouse, industrial). Signs are flat ledger objects: CHECKS, ROOMS (NO), FORMER DENTIST, TIRE 2, CAR WASH · NO WATER, USED MATTRESS, SELF STORAGE, CARPET, MEAT, TAX, UNIT 4.
5. Added `WORLD_DECOR`: bus shelter, billboard, water tower, motel sign, clotheslines, utility poles/wires, rail signals, crossbuck, newspaper boxes, barriers, and storm drains.
6. Added district ground marks: the Block's failed half-court, Projects court/number, Bus Stop curb ledger, and Old School court.
7. Added small palette-indexed environment sprites in `ENV_SPRITE_CACHE` (storm drain, news box, barrier, rail signal, two-piece utility pole). All are 16×16 logical grids rasterized once to 32×32.
8. Added foreground depth: utility wires, shelter roof, clothesline plane, and tree-canopy occlusion. Tree canopies fade when the player is underneath.
9. Rebuilt lighting around one persistent 800×600 mask plus cached radial holes/glows. Added static color sources for Tony, laundromat, church, bus shelter, park, underpass, Old School, rail signals, Projects, and Skid Row. No canvas allocation inside `drawLighting`.
10. Cached the fog sheet and reduced night-fog stacking so the player/telegraphs remain visible.
11. Added viewport/full-bounds culling for zones, buildings, graffiti, posters, props, interactive props, underpass, marketplace stalls, scrap fence, and new decor. Rendering now sorts a visible NPC copy instead of mutating `npcs` every frame.
12. Fixed hideout-door rendering: it previously subtracted camera coordinates inside an already world-translated context (double transform). Doors now render at their world coordinates.
13. Expanded minimap geography with roads, facade blocks, and rail lines.
14. Removed the prohibited browser-persistence shim. Missing `window.storage` now falls back to async page-memory only.
15. Updated README/SPEC/DELEGATION drift: v14 is current; the world/NPC/output summary reflects the live build; obvious shipped backlog items are marked shipped; performance/file-size budgets reflect reality.

No NPC, dialogue, sound, resource, quest, faction, save-shape, combat, economy, zone rectangle, building collision, or interaction-priority change shipped.

### WHY

The audit found the map expansion's actual failure: sixteen zones occupy only about 3.44M of 14.96M world units (~23%). Roughly 77% of the 4400×3400 world fell through to the same default checker tile. Park, Skid Row, Old School, and Train Yard had internal props but were separated from the original neighborhood by 380–1420px of visually identical nothing.

The fix was geography before detail. Roads establish routes, terrain regions establish material neighborhoods, facades establish block rhythm, and utilities/lights establish scale. The existing zones remain the mechanical truth.

### DECIDED / REASONING

- **No second expansion.** More world would repeat the problem and drift into the speculative procedural-city backlog.
- **No NPC redesign.** v13 already has a full cached pixel roster. The mismatch described in old docs was stale.
- **No new solid landmark blocks.** A solid-building plan was drafted and grid-verified, but NPC chase logic does not share player building collision. Adding new solids would create NPC-through-wall behavior unless collision was reworked as a separate system. Facades are setback visual architecture instead.
- **Canonical zones still draw their ~25% wash + dashed edge.** VIBE.md explicitly requires it. Roads and fabric sit underneath so the borders read as neighborhood markings rather than the only geography.
- **Continuous rails replaced tile rails.** A rail that restarts each tile reads as patterned floor. Whole-route ties/rails give Train Yard a silhouette at viewport and minimap scales.
- **Cached facades instead of embedded art.** Sixteen code-rendered canvases add ~9.4KB gzip over v13. No bitmap payload, CDN, framework, or asset-pack mismatch.
- **Persistent lighting canvas.** v13 allocated a new 800×600 canvas/context every night frame. Reuse removes the largest obvious allocation before adding more sources.
- **Visual-only fabric is save-free.** Roads/regions/facades/decor are constants. SAVE_KEY remains `rockbottom_save_v8`; old saves require no migration.

### TRIED / ABANDONED

- The required in-app browser connection failed because its runtime could not read the sandboxed AppData path. Used approved headless Chromium/CDP for local visual QA instead.
- First automated smoke-loop attempt used a browser-level E injection that the page ignored. Confirmed the failure changed nothing, switched to a page-dispatched `KeyboardEvent`, verified the real THE BLOCK menu/options, then ran the complete timer test.
- Initial night screenshots made Skid Row too black and night+fog made Old School unreadable. Added restrained district sources and a cached lower-opacity night-fog treatment.
- One Old School screenshot showed a GRABBED overlay because Skid Row hostiles followed the debug-teleported player between captures. This was a test contamination, not a map defect; live zone AI/state was unchanged.
- Considered full entity depth sorting. Deferred: existing buildings are already colliders, while a safe prop/NPC/player depth queue needs interaction-hint and telegraph priority rules. v14 ships foreground canopies/wires without rewriting simulation order.

### COUNTEREXAMPLE HUNT

- **Old save with v13 graffiti/posters:** loads unchanged. New visual constants are not saved; missing facade graffiti is acceptable. ✓
- **Road overlaps a zone:** zone wash/border renders above the road; mechanics still read the unchanged ZONES table. ✓
- **New facade crosses player route:** facades are visual-only and set back from canonical connectors; collision arrays hash-identical. ✓
- **Large freight car/school fence leaves screen by anchor:** full-bounds culling keeps visible portions drawn. ✓
- **Night + rain + 60 NPCs:** 119 sampled frames held 16.7ms median / 16.8ms p95 (steady 60Hz, no drops), zero runtime exceptions. ✓
- **Night + fog:** cached sheet opacity drops with `nightAmount`; Old School door light and player pool remain visible. ✓
- **Rocked-up/crash:** real crate option consumed one real rock; `rockedT` began at ~17.73s after click, reached ~0.22s at 17.75s, transitioned to `crashT` ~6.92s at 18.8s, and both reached 0 after the 8s crash. ✓
- **Storage unavailable:** memory shim remains async and try/catch wrapped. No prohibited browser store name/call remains in v14 HTML. ✓
- **File size:** v13 = 134,795 bytes gzip; v14 = 144,219 bytes gzip. Under revised 150KB current-build guardrail. ✓

### DRIFT CHECK

SHA-256 slice comparisons between v13 and v14:

- `ZONES`: unchanged.
- `BUILDINGS`: unchanged.
- `spawnNpcs`: unchanged.
- `updateWorld`: unchanged.
- `tryInteract`: unchanged.
- `blockMenu`: unchanged.

The v14 implementation matches the new `VISUAL WORLD COHESION` SPEC: visual layers are deterministic/save-free, canonical mechanics remain authoritative, repeated small decor is cached, lights reuse one mask, map geography appears on the minimap, and no external dependency entered the file.

### PROPERTY VERIFICATION

- Spawn → Tony route and every canonical interaction remain as reachable as v13 because collision geometry is byte-identical. ✓
- Boss arenas and boss logic are unchanged; no new collider enters either arena. ✓
- NPC > heist > prop > zone-verb priority is byte-identical. ✓
- 18s high always transitions to 8s crash in the live browser. ✓
- Single-file, double-click architecture preserved. ✓
- Audio initialization path untouched. ✓
- No new NPCs, so VIBE identity table needs no change. ✓
- No new sounds, so the SPEC sound registry needs no change. ✓

### NEXT

- Operator playtest v14 on the normal route: Block → Tony → Market → Alley → east connector → Park/Skid Row → Old School → Train Yard. The visual sweep used direct coordinate placement; walking the whole route will surface rhythm problems between screenshots.
- If foreground depth still feels flat, spec a proper visible-renderable queue (player/NPC/tall-prop foot-y sort + telegraph overlay) as its own wave.
- Cache ground-tile variants if future district work pushes frame cost; v14's 60-NPC stress scene did not require it.
- Boss music and the full per-zone ambient audio suite remain clean next backlog candidates.

### GOTCHA

- `LANDMARK_FACADES` are visual-only by design. Do not silently add them to `BUILDINGS`; NPCs need shared collision first.
- Existing `state.graffiti` / `state.posters` do not regenerate on old saves, so cached facade silhouettes intentionally have no persisted tags.
- `LIGHT_MASK`, `LIGHT_HOLE`, `LIGHT_GLOW_CACHE`, and `FOG_SHEET` are built once at init. New light colors must be present in `WORLD_LIGHTS` before `buildLightSprites()` runs or they will have no cached glow canvas.
- Train rails now live in `RAIL_LINES`; do not restore `tracks:true` on the trainyard tile palette unless double rails are intended.
- `drawHideoutDoors` is called under the world transform. Door coordinates must remain world-space; do not subtract camera values again.
- Road/facade/rail minimap geometry is visual context only. Bus targets and territory still use `ZONES`.

---

## July 12, 2026 — v15 living neighborhood + sprite identities

### WHAT

1. Wrote `LIVING NEIGHBORHOOD + SPRITE IDENTITIES (v15)` in SPEC before generation, then forked v14 to `rock_bottom_v15.html` without overwriting lineage.
2. Added a bounded `INCIDENT_DEFS` scene engine with six incidents: `runaway_mattress`, `possum_inventory`, `laundromat_walkout`, `yuri_receipt`, `park_dry_committee`, and `ticketed_luggage`.
3. Added four-beat, dt-driven scene timing. Incidents pause with the world, suppress the existing random-event toast while active, respect day-7 silence, and clean up for boss/combat/scripted-visitor state.
4. Added save-compatible daily incident history in `state.flags` (`incidentDay`, `incidentMask`, `incidentsToday`, `lastIncidentId`). Active actors/timers remain ephemeral; reload cannot repeat a started incident that day.
5. Added ten cached incident sprite frames across five prop families (mattress, forklift, dryer, suitcase, sprinkler). Pigeon/Possum actors reuse their canonical cached art. Receipt ribbon/water are bounded scene geometry.
6. Rebuilt `rasterize` around a true 16×16 logical canvas scaled once to 32×32. Removed the old 1-device-pixel halo/shine that introduced half-logical pixels.
7. Fixed `makeNPC` structure: hat values now reach hat pixels; tall is a silhouette instead of a recolor; thin/tall bodies retain their legs during walk frames.
8. Added cached signature pixels across the humanoid roster for coat layers, hot pocket, long arms, crossed newspaper, kombucha, cross, ticket/watch, sash, phone, guitar, leash, badge/taser, backpack, cane, and other canonical identifiers.
9. Added special state art: horizontal sleeping Dave, Fallen O'Malley, and Tony with 3/2/1/0 visible coats. Tony's existing phase transitions now set `coatsOff`; no phase threshold/HP/speed/damage change.
10. Split Brutus, Scrap Dog, and Old School Brutus by silhouette/detail instead of palette alone. Scrap Dog's computed `tailWag` now reaches the pixels. Added Pigeon King's crown and cleaned the Possum's construction helmet.
11. Bottom-centered the cached 32×32 art on each NPC's real hitbox baseline. Long labels wrap to two backed lines and peaceful non-vendors fade outside 260px. Label layouts are cached per name.
12. Replaced the per-frame `filter` allocation with a reusable visible-NPC buffer. Cache count is fixed at 162 canvases and does not grow during play.
13. Updated README, SPEC changelog/budgets, and DELEGATION. No new named NPC or sound was added, so VIBE identity and sound tables did not need changes.

### WHY

v14 made the expanded map geographically coherent, but the absurdity still mostly arrived as text boxes and most humanoids still shared one directionless body. v15 makes the neighborhood visibly conduct its own business and gives the canonical cast enough silhouette/prop information to land before a label is read.

The incidents are district punctuation rather than quests. They make Yuri, the Conductor, Barb's laundromat, the Park pigeons, and the Marketplace feel tied to their surroundings without adding another economy, tutorial, or story layer.

### DECIDED / REASONING

- **One scene engine, not six minigames.** Every incident shares scheduling, beats, cleanup, save flags, culling, and render boundaries.
- **Scene actors are not NPCs.** Putting forklifts/pigeons/luggage into `npcs` would leak into combat, corpses, faction rewards, interaction priority, and save persistence.
- **Five authored districts + one road fallback.** Exploration reveals specific incidents; the mattress lets the connective map misbehave without inventing another district.
- **Mostly cosmetic consequences.** Receipt paper and sprinkler water are visual. Only the mattress can nudge once. Incidents do not touch wanted, resources, faction, brain, smoke, rocked-up/crash, or boss numbers.
- **State sprites before more walk directions.** Fallen O'Malley and Tony's disappearing coats were narrated but visually false. Repairing those state lies has more value than multiplying generic frames.
- **Keep the cache simple.** Atlases could lower canvas count, but 162 tiny 32×32 canvases are bounded, below the revised 190 contract, and the existing draw path stays stable.
- **No image generation.** The hard project contract calls for palette-indexed code-native 16×16 art in the one-file build; external raster style would break the visual language and architecture.

### TRIED / ABANDONED

- In-app browser control again failed at its AppData runtime boundary. Continued with the approved hidden Chromium/CDP harness used for v14.
- The first CDP script attached to Chrome's extension background page instead of the game tab. Filtered targets to `type === 'page'`.
- The build is closure-scoped, so the first test attempted unavailable global functions. Expanded the existing local `_rb` QA accessor with narrow references to state/cache/update/start helpers.
- First screenshots were black because the CRT power-on overlay still covered the stage. The harness now dismisses that overlay after programmatic start; normal game startup is unchanged.
- A tight 160-draw microbenchmark reported periodic 30–50ms GPU queue flushes despite a ~4ms average. It was not representative of paced frames. Replaced it with 180 real animation frames under the stress scene: steady 60 Hz, 0 drops, 16.8ms max interval.
- Label wrapping initially split/measured every visible name each frame. Cached line/width data and reused the viewport actor buffer before final profiling.

### COUNTEREXAMPLE HUNT

- **Old v14 save has no incident flags:** load defaults/lazy day initialization create zeroed history; SAVE_KEY stays `rockbottom_save_v8`. ✓
- **Reload during incident:** active visuals end; start bit was already persisted; it does not repeat that day. ✓
- **Boss starts during a scene:** active incident cleaned on the next update. Automated test passed. ✓
- **Brutus is dead during Yuri's receipt:** ribbon targets the leash post and uses the post-specific flat line. ✓
- **Required NPC is dead/hostile:** district definition is ineligible or active scene cleans. ✓
- **Dialogue opens mid-scene:** `updateWorld` pauses; scene resumes without setTimeout drift. ✓
- **Night + rain + 66 visible NPCs + six-pigeon committee:** 180 paced frames held 60.00 Hz, p95 16.8ms, max 16.8ms, zero dropped frames. ✓
- **Sprite cache completeness:** 162 entries; every canvas 32×32; no missing live NPC keys, missing required variants, blank required frames, or pure-white PALS values. ✓
- **All incident lifecycles:** all six ran past duration and returned `state.incident === null`; zero runtime exceptions. ✓
- **18s → 8s core loop:** after exactly 18,000 simulated ms `rockedT=0`, `crashT=8000`; after another 8,000ms both were zero. ✓
- **File architecture:** 509,070 bytes raw / 152,816 bytes gzip; no external script/link, CDN URL, localStorage, or sessionStorage reference. ✓

### DRIFT CHECK

The implementation matches the v15 SPEC: six scene ids, one active incident, bounded actors/cache, current-zone eligibility with road fallback, daily persisted seen mask, active-state reload cleanup, boss/combat/silence/intro gates, code-native cached art, logical pixel grid, explicit state variants, backed labels, and unchanged save key.

No incident path enters `npcs`, `PROPS`, `npcsKilled`, vendor scans, factions, quests, or interaction priority. The only core-update edit is the late `updateIncidents` call after player/status/day timing plus the random-event suppression condition.

### PROPERTY VERIFICATION

- Single HTML, no dependency/build step. ✓
- `window.storage` only; async calls and try/catch preserved. ✓
- Audio context initialization still occurs from title key/touch. ✓
- Player/NPC/incident art is palette-indexed, cached at init, and drawn via `drawImage`. ✓
- Incidents do not start in boss/combat and do not add boss collision; existing Tony numbers remain unchanged and comfortably under the 90s bound. ✓
- Smoke remains required and the 18s high always enters the 8s crash. ✓
- No new named NPC, real city, real victim, tutorial, cure ending, or fourth-wall line. ✓
- No new audio function, so no sound-spec addition was necessary. ✓

### NEXT

- Operator route playtest: deliberately linger in Marketplace, Laundromat, Scrap Yard, Park, and Train Yard long enough to see each authored scene in context.
- If incidents feel too sparse, adjust only the scheduler intervals/max-per-day after play evidence; do not duplicate scene actors into the toast pool.
- If the forklift still reads too small at game scale, build it as two adjacent cached 16×16 tiles rather than scaling one sprite beyond 32×32.
- A future art pass can add directional NPC heads/feet or equipment overlays, but should preserve the v15 state sprites and cache validation.

### GOTCHA

- `INCIDENT_IDS` order defines the persisted bitmask. Append new ids; do not reorder existing ids without a migration.
- `startIncident` is exposed only through the existing `_rb` local QA surface for automated visual tests. Normal scheduling still goes through `updateIncidents` gates.
- `VISIBLE_NPC_BUFFER` is render scratch only. Never retain it outside `drawAll`.
- Tony's visual mapping is `coatsOff 1 → two coats`, `2 → one coat`, `3 → bare`; phase mechanics remain `state.bossPhase`.
- Receipt/water geometry is deliberately bounded. Do not push it into the general particle array without retaining the 30-particle incident cap.

---

## July 12, 2026 — v16 control input reliability

### WHAT

1. Wrote the `CONTROL INPUT RELIABILITY (v16)` behavioral contract before code and forked `rock_bottom_v15.html` to `rock_bottom_v16.html`.
2. Removed the 700ms `state.keyTimes` stale-key pruning block from the start of `updateWorld`.
3. Removed all timestamp writes/deletes and the obsolete global pointer-up handler that deleted physical movement keys.
4. Preserved event-latched keyboard semantics: keydown adds; matching keyup deletes; blur/hidden/modal paths clear.
5. Retained repeat suppression only for a movement key already cleared by a modal/focus safety path. A physically held key cannot ghost-restart after the clear; release and fresh press works.
6. Added `releaseAllInput()` to reset `state.keys`, analog vector, mobile button closure state/classes, joystick pointer ownership, dragging class, and nub position.
7. Wired unified release to dialogue open/close, inventory/quest open/close, `startGame`, window blur, and hidden-document transitions.
8. Added per-control release hooks inside `setupMobile`; the remaining global pointer-up listener belongs only to the active analog stick and never mutates keyboard state.
9. Updated README, SPEC changelog/current-version label, and DELEGATION. No VIBE or sound-table change was needed.

### WHY

The stopped/diagonal-collapse behavior came from a false safety assumption. Operating systems generally repeat only the newest key in a chord. Holding W and then D refreshed D but not W; after 700ms the watchdog deleted W even though the player still held it. Releasing D then left no direction. The repeat guard correctly refused to resurrect a safety-cleared key, which made the false deletion feel stuck until a full release/repress.

A second path made the symptom intermittent: any mouse/touch `pointerup` could delete all WASD/arrows/Shift because a handler written for an old D-pad did not distinguish pointer input from physical keyboard input.

### DECIDED / REASONING

- **Keyboard events are the authority.** Time since auto-repeat is not a release signal. `keyup`, blur, hidden-document, and explicit modal clearing are.
- **Input sources do not delete one another.** Pointer release resets its captured mobile control; it does not touch keyboard-down state.
- **Keep the repeat guard after legitimate safety clears.** Without it, holding W through a dialogue/blur could resume movement from repeat alone. The removed false clears were the bug, not this no-ghost property.
- **Do not rewrite movement math.** Existing cardinal speed, 0.7071 diagonal normalization, independent X/Y collision, sprint, high/crash, and analog precedence already behave correctly once keys remain latched.
- **Unify mobile safety while here.** A blur during a captured stick/action press could otherwise leave analog drift or a permanently `pressed` button closure.

### TRIED / ABANDONED

- Connected to the in-app browser workflow, but its URL safety policy rejected navigation to the new local file. Did not route around the policy or use another browser surface.
- Used an isolated actual-source harness instead: it extracts v16's real input event block, real movement block, and real status-transition block, supplies bounded DOM/input stubs, and drives deterministic key/focus/pointer sequences.
- Considered changing opposing-key behavior to “latest press wins.” Deferred because it is unrelated to the reported regression and would change established movement semantics.

### COUNTEREXAMPLE HUNT

- **W held for 2s with no repeats:** continuous -275px Y; W remains latched. ✓
- **W+D held for 2s:** +194.453px X / -194.453px Y; magnitude 274.997px, equal to cardinal distance within tolerance. ✓
- **Release D while W stays held:** next ten frames move exactly 22px north and 0px east. ✓
- **Pointer release while W held:** W remains latched; movement continues. ✓
- **Shift+W+D:** normalized sprint magnitude 467.5px over the same 2s. ✓
- **Blur/visibility:** keyboard and analog vector clear; ten further movement steps produce no displacement. ✓
- **Repeat after safety clear:** repeat alone produces no movement; fresh non-repeat keydown moves normally. ✓
- **Inventory/quest open:** all keyboard/analog input clears immediately. ✓
- **18s → 8s:** exactly one crash cue; at 18,000ms `rockedT=0`, `crashT=8000`; after 8,000ms crash is zero. ✓
- **Compile/static:** full v16 script compiles; no `state.keyTimes`, stale-pruner label, prohibited storage, or global pointer keyboard-purge text remains. ✓

### DRIFT CHECK

SHA-256 slices between v15 and v16:

- Movement vector, speed multipliers, collision, animation/dust block: unchanged (`3be94b832a69…`).
- Rocked-up/crash/status block: unchanged (`38536fc21de7…`).
- Tony boss phase block: unchanged (`4a7ee5860d10…`).

Only input ownership/release logic changed. SAVE_KEY, save shape, incidents, sprite cache, factions, economy, NPCs, boss numbers, and interaction priority remain v15 behavior.

### PROPERTY VERIFICATION

- Multi-key WASD/arrows remain simultaneous for the full physical hold. ✓
- Releasing one diagonal axis preserves the other without a new keydown. ✓
- Cardinal and diagonal total speed remain equal. ✓
- Pointer actions cannot cancel keyboard motion. ✓
- Focus/modal safety cannot leave keyboard or analog movement stuck. ✓
- The 18s high always transitions to the complete 8s crash. ✓
- Single-file architecture, first-interaction audio initialization, and async `window.storage` remain unchanged. ✓
- No new system copy, NPC, sound, asset, or save field. ✓

### NEXT

- Operator keyboard feel test in the normal browser: hold W, add D for several seconds, release D while keeping W down, then click/release the canvas while still holding W.
- On a touch device, hold the analog stick with one finger and tap A/B/F with another; app-switch mid-stick once to verify the nub/action closures recover visually.
- If opposing directions later feel wrong, spec a separate last-pressed-per-axis policy rather than folding it into this repair.

### GOTCHA

- Do not reintroduce a short TTL for physical keys. Key repeat belongs to text entry, not movement truth.
- `INPUT_RELEASE_HOOKS` owns closure-local mobile reset state. New hold-style touch controls must register a hook.
- The remaining `window.pointerup` inside `setupMobile` is analog-only: `onUp` returns unless `activePointer` owns a stick gesture.
- Modal helpers must call `releaseAllInput`, not only `state.keys.clear`, or analog drift can return.

---

## July 14, 2026 — v17 cursed stickers + bad-idea clarity + endless block routes

### WHAT

1. Read VIBE first, wrote `CURSED STICKERS + BAD-IDEA CLARITY + ENDLESS BLOCK ROUTES (v17)` in SPEC, then forked v16 to `rock_bottom_v17.html` without overwriting lineage.
2. Rebuilt the player cache around four distinct directions, a four-beat uneven shuffle, two attack poses, and two geometrically distinct directional smear phases. Movement hitboxes/math are unchanged.
3. Added cached transparent player layers for all 15 equipment ids, all 9 weapons in idle/attack states, four lifetime route-patch tiers, and four directional cart underlays. Loot now changes the avatar instead of only changing inventory numbers.
4. Enlarged named-NPC signature geometry and held objects for Yuri, Pete, Lurch/Big Guy, Sherri, Paulie, Mom, Conductor, Larry, and Stripe. Existing Tony coat loss, sleeping Dave, Fallen O'Malley, dog, pigeon, possum, and horse-cop art remains.
5. Added pure `resolveNpcPose(n, visualNow)`. Known two-frame families normalize global frame 2 to a valid 0/1 key; rendering no longer asks the cache for missing dog/horse frames.
6. Added a title receipt with opening plan and desktop/touch verbs, tappable load receipt, live `BAD IDEA` strip, shared world/edge/minimap target, and read-only contextual E/B prompt.
7. Reordered Q as WHAT TO PRESS → NOW → BLOCK ROUTE → TODAY'S HUSTLES → quests/factions/activity ledger. Touch devices receive touch-specific control copy.
8. Added 16 authored `ROUTE_STOPS`. After the intro, each sheet selects three distinct ordered public landmarks. The third stamp pays capped cash/cred, increments a permanent route count, updates patches/milestones, and immediately posts another route.
9. Persisted routes and hustles. Old/malformed route records regenerate. New route count defaults to zero on old saves; SAVE_KEY remains `rockbottom_save_v8`.
10. Repaired adjacent daily-contract failures: panhandle asks for a possible $4 roll, church asks for one $5 donation and displays 0/1, unavailable NPC contracts are filtered, and crate sleep settles today's contract before rolling tomorrow's sheet.
11. Closed intro guidance counterexamples: talking to Tony without buying no longer sends a rockless player to the crate; the marker returns to Tony until a rock exists.
12. Made the free standalone build retain the grind. Missing host storage now receives an async IndexedDB-backed `window.storage` adapter, falling back to memory only when IndexedDB is unusable. No game path uses localStorage/sessionStorage.
13. Added 16 authored local Possum prophecies. Optional host completion may replace one only within 1.8 seconds; absence/failure/latency keeps the local line.
14. Preserved square pixels on touch screens by letterboxing the fixed 4:3 canvas inside the full touch-control stage instead of stretching 800×600 to the device aspect.
15. Changed Tony/co-op/bus endings from save wipes into resumable receipts. SPACE/TAP returns to the exact in-memory block after the ending save finishes, so an endless route ledger cannot vanish at victory.
16. Updated README, SPEC changelog/budget, and DELEGATION. No new named NPC or sound was added, so VIBE identity and sound tables were not expanded.

### WHY

The world already contained sixteen districts, vendors, bosses, quests, factions, minigames, equipment, day events, secrets, and daily jobs. The weak point was not raw system count; it was that the player could not see what they wore, could not read many silhouettes, and had no reliable answer to “what now?” after waking up.

The block route is the endless floor under that existing depth. It gives short sessions a three-box receipt, sends the player across the authored map, pays enough to keep motion useful, and never replaces the score/smoke/crash economy or invents another currency.

### DECIDED / REASONING

- **Code-native cursed stickers, not raster assets.** The one-file/palette/cache contract is part of the look. Direction, layers, and oversized props produce more value than importing a different asset language.
- **One live objective.** Multiple quest pins turn the neighborhood into UI. Intro → route → active quest keeps the current bad decision legible while Q exposes the rest.
- **Guidance is read-only.** Objective, prompt, world ring, edge arrow, and minimap all consume one cached target; drawing never advances or pays a route.
- **Endless travel, bounded economy.** Routes have no cap but cash reaches $24 and cred reaches 4. They grant no rocks, copper, supplies, equipment, rep, or combat stats.
- **First two sheets stay local.** Route 1–2 teach the clipboard in the original neighborhood; the full 4400×3400 map enters afterward.
- **Visible equipment is layered.** One base body plus cached transparent gear/weapon layers avoids combinatorial full-body sprites and stays within the cache budget.
- **Browser persistence stays behind `window.storage`.** IndexedDB is an implementation detail of the fallback adapter, not a second game-facing persistence API.
- **Portrait uses black space for controls.** A smaller square-pixel world is preferable to turning every character into a 3:1 smear; a responsive-camera rewrite remains a separate project.

### TRIED / ABANDONED

- The in-app browser control surface rejected local `file://` navigation under its URL policy. Did not route around that policy or use a different browser surface.
- Used actual-inline-source deterministic VM/DOM/canvas harnesses for init, update/draw, cache pixels, controls, routes, panels, storage, and status timing.
- Generated a temporary full-color cache contact sheet, inspected player directions/attacks/cart, all equipment, weapons, named NPCs, and animals, then removed the temporary image files.
- The first right-facing gait edited coordinates after mirroring the base and produced a malformed limp. Final right frames mirror the completed left gait.
- The first smear pass changed only color between phases. Final phase 0 is tight and phase 1 is long/broken, using the same cached-canvas count.
- Several route coordinates named props that were not actually under the marker. Retargeted the Block news box, Alley can, Park fountain, and Skid Row storm drain to their authored visual coordinates.

### COUNTEREXAMPLE HUNT

- **Hold W+D for 2s, release D:** 194.453px diagonal components; W continues; pointer release cannot clear it. ✓
- **Intro player talks but does not buy:** primary objective stays/returns to Tony until rock inventory is positive. ✓
- **Route record has string serial/unknown/prototype id:** validation uses a null-prototype index plus own-property checks; `toString`/`constructor` and malformed fields reject and regenerate. ✓
- **Hidden tab/modal/stun/boss at a landmark:** stamp returns false and stale prompts hide on modal open. ✓
- **100 routes / 300 stamps:** all routes valid and distinct; no immediate final-stop repeat; route 101 exists; exact totals $1,968 and 283 cred. ✓
- **Route target collision:** all 16 centers remain outside solid BUILDINGS and use visible authored landmarks. ✓
- **Daily sleep contract after morning:** counter is credited and checked before dawn replaces the sheet. ✓
- **All equipment/weapons:** 60 gear-direction layers and 72 weapon-direction/state layers exist and are nonblank. ✓
- **Sprite cache:** 346 bounded 32×32 canvases, under the 360 cap; four distinct player directions; required states nonblank; animals have bottom-anchor pixels. ✓
- **Two-frame NPC families:** pose selector never requests nonexistent frame 2. ✓
- **No host completion:** Possum selects from 16 local lines and still applies its micro-effect. ✓
- **No host storage:** fake IndexedDB round-tripped an object and null; unusable IDB falls back to session memory. ✓
- **Tony/co-op/bus receipt:** progression is saved; return hides the receipt and resumes current state without respawning/reinitializing the world. ✓
- **Bus receipt returns in-place:** `takeTheBus` removes the driver before saving, so he cannot immediately sell the same ending again. ✓
- **Mobile aspect:** 390×844 resolves game canvas to 390×292.5; 844×390 resolves to 520×390. X/Y scale remains equal. ✓
- **18s → 8s:** exact existing high/crash harness still passes with one crash cue. ✓
- **Size/architecture:** 546,304 bytes raw / 164,853 bytes gzip; no external script/link/import/fetch, localStorage, or sessionStorage. ✓

### DRIFT CHECK

Implementation matches the v17 SPEC: one receipt, one primary target, desktop/touch verbs, non-blocking prompts, ordered persistent three-stop routes, capped reward formula, patch/milestone thresholds, pure pose selection, cached gear/weapons/cart/smears, malformed-save regeneration, IndexedDB window.storage fallback, and local Possum content.

Tony/other boss phase blocks, playerAttack mechanics, v16 movement vector/collision, and the high/crash status block remain mechanically unchanged. Route code grants no faction rep or non-cash/cred resource.

### PROPERTY VERIFICATION

- One standalone HTML, no CDN/framework/build step/external gameplay asset. ✓
- Game persistence calls only async `window.storage` methods inside try/catch. ✓
- Audio context still initializes from a user key/touch/click. ✓
- Player/NPC/cart/weapon/equipment/route art is 16×16 logical, cached at init, and drawn with `drawImage`. ✓
- 346 sprite canvases remain inside the 360 budget; no runtime sprite creation. ✓
- Smoke remains required; 18 seconds high always enters the full 8-second crash. ✓
- Boss mechanics were not changed and remain inside the existing <90-second contract. ✓
- No new named NPC, real city, victim, tutorial modal, cure ending, currency, or fourth-wall line. ✓
- No new audio function, so no sound-spec addition was necessary. ✓

### NEXT

- Operator playtest route 1–3 on keyboard and a real touch device. Confirm the first two local sheets teach the pattern and the third makes the expanded map feel worth crossing.
- Test refresh persistence on the actual free host/origin. IndexedDB is the normal-browser fallback; hosts that inject `window.storage` remain authoritative.
- If portrait feels too visually small, spec a responsive-camera/viewport pass. Do not restore non-uniform canvas stretching.
- If more grind is wanted after route feel is proven, add authored route-stop variants or route-specific stamp copy before adding another currency/system.

### GOTCHA

- `ROUTE_STOPS` ids are serialized. After public saves exist, append ids or migrate them; do not casually rename/remove them.
- Cache headroom is 14 canvases. New player/NPC pose families require updating the ≤360 SPEC budget or replacing existing entries.
- `resolveNpcPose` is visual-only. Never mutate AI timers/aggro/charge state from it.
- The route patch draws after coat but before shoes/hat/tool/weapon so it remains visible without painting over held tools.
- The game canvas is letterboxed inside a full-viewport touch stage. Canvas-space art and DOM-space controls intentionally use different boxes.
- A browser that blocks both injected storage and IndexedDB can only keep a volatile save. The title/load path must continue failing softly in that case.

---

## July 14, 2026 — v18 the office + paper empire + far-east expansion

### WHAT

1. Read VIBE first, wrote `THE OFFICE + BLOCK AUTHORITY + FAR-EAST EXPANSION (v18)` in SPEC, then forked v17 to `rock_bottom_v18.html` without overwriting lineage.
2. Expanded WORLD from 4400×3400 to 5800×3800 while leaving every v17 coordinate intact. Added WAREHOUSE ROW, THE DRAINAGE CANAL, and THE LOT with distinct terrain palettes, continuous roads, facades, buildings, props, drains, barriers, lights, entry receipts, bus discovery, and three appended route landmarks.
3. Added THE OFFICE, a condemned former tax office in THE LOT. Filing route 3 exposes THE LEASING GUY; replacing the lock costs $40 + 1 pure copper exactly once.
4. Added six permanent, separately priced office upgrades: cot, shared locker, desk, generator, radio, and route board. Each has a mechanical use and visible exterior evidence. The office sign/facade changes again at claim milestones.
5. Added eleven district claim files in a separate `districtClaims` ledger: Alley, Projects, Skid Row, Scrap Yard, Underpass, Old School, Warehouse Row, Market, Park, Train Yard, and the neutral Canal onboarding claim.
6. Claims follow `survey → file → install`. Filing costs `$20 + $5 × claimedCount + 1 copper`; installation pays exactly +2 cred and draws one cached bent sign. Faction districts require matching reputation ≥ +10 only when selected.
7. Added the finite campaign receipts THE OFFICE, PAPER EMPIRE, REGIONAL OFFICE, and ALL BUSINESS at acquisition and 1/4/11 claims, plus achievements at 1/4/8/11. Milestones grant no extra claim currency.
8. Added bounded endless office work orders. A radio + one claim permits one owned-sign inspection and a return filing. Payout is `$min(12, 5 + claimedCount)`, every fifth order adds +1 cred, and daily capacity rises from one to three with claim count. No passive or offline payout exists.
9. Gave the Q ledger a full office section: ownership, upgrade count, active paper, daily order capacity, lifetime filings, and all claimable districts. Active acquisition/onboarding/paperwork temporarily owns the one BAD IDEA target; the saved block route resumes afterward.
10. Added THE LEASING GUY and GUTTER GREG to the VIBE registry, chatter/index, spawn roster, palettes, and signature sprite geometry. Greg grants +1 scrap reputation once per day for counting a rubber duck and no item/cash.
11. Made both clerical hooks `essential`. Swinging at them produces one paper-denial reaction but cannot damage, kill, knock back, aggro, raise wanted, show an HP bar, or feed combo rewards.
12. Rebuilt bus travel around fourteen authored safe arrivals and six-destination pages. This fixes the pre-existing Church/Old School center traps and prevents THE LOT from teleporting the player inside the office shell.
13. Reordered the minimap so roads/facades/rails render above district color, and reordered the office exterior above graffiti/posters so purchased fixtures remain legible.
14. Hardened office persistence: finite counter clamps, whitelisted ids/stages, active-serial reconciliation, one-job-at-a-time normalization, prerequisite restoration, no duplicate purchase, no claim double-pay, final daily-cap recheck, and idempotent milestone repair from durable save witnesses.
15. Updated README, VIBE, SPEC, DELEGATION, and this append-only session record. No new sound function was added, so the sound table did not change.

### WHY

The existing world had many verbs but no medium-to-long spine after the immediate score/smoke loop. The office gives the player a place that visibly accumulates effort, claims turn faction reputation and map traversal into a long goal, and work orders provide a short repeatable toilet-session loop without introducing a currency, passive empire income, or a realistic trafficking simulation.

The empire is paperwork because literal gang conquest would change the joke and erase the neighborhood's agency. A claimed district can still hate the player and call the cops. The sign belongs to the office; the people do not.

### DECIDED / REASONING

- **Three routes before the office.** The route clipboard teaches movement and earns some acquisition money before the larger system appears.
- **Neutral first claim.** The Canal demonstrates the full claim loop without a faction grind; the other ten make existing reputation systems matter.
- **Escalating fees, bounded return.** Full office + all claims costs roughly $900 and 20 copper. Office orders top out at $12, below mature block routes, so the new loop funds motion without deleting the old economy.
- **No passive income or decay.** Every dollar requires an accepted order, a walk to a sign, and a return filing. Missing a day does not punish the player.
- **Separate ownership vocabulary.** `districtClaims` never touches `state.territory*`, `ZONES[].faction`, local heat, or NPC allegiance. Paper authority and social authority remain different systems.
- **Six independent upgrades instead of tiers.** The player chooses utility order and every purchase adds a readable piece of junk to the exterior.
- **Permanent clerks.** Critical acquisition/activity NPCs are fixed bureaucratic facts. Paper denial is funnier and safer than 9,999 HP.
- **Authored bus anchors.** Zone centers are not travel contracts; several are inside buildings. Every destination now declares its own tested arrival.
- **Revised file ceiling.** The authored expansion measured 179,459 bytes gzip, so the SPEC ceiling moved from 170KB to 185KB. The one-file/no-dependency rule and <200ms initial-paint contract remain.

### TRIED / ABANDONED

- Connected to the in-app browser workflow, but browser security policy rejected the local `file://` v18 URL. Did not route around the policy or switch browser surfaces. Used actual-source deterministic state/DOM/canvas harnesses and static geometry audits instead.
- The first lot bus implementation reused zone centers. THE LOT, Church, and Old School centers sit inside solid buildings and could trap the player. Replaced all fourteen centers with authored arrivals.
- The first LEASING LATER facade crossed the south service road and visually erased it. Moved the facade north; the full facade/road intersection audit is now zero.
- The first Projects survey reused the meter route marker on Stripe's body. Moved it to Building A and rewrote the task around the visible building.
- The first clerical protection used 9,999 HP. Rejected after attacks could still shove the only seller away and eventually kill him. Replaced with explicit essential behavior and death-path defense.
- The first milestone draft added +3 cred on top of the claim's +2. Removed it to keep the written economy exact and the long grind intact.
- The first unlock/milestone implementation could issue overlapping async save snapshots. Routed route/claim transactions through one final save and batched repair saves after all mutations.
- The original 170KB gzip budget was no longer honest after the authored expansion. Revised the SPEC ceiling rather than minifying the source into an unmaintainable blob.

### COUNTEREXAMPLE HUNT

- **Bus into a building:** all 14 player-centered arrivals overlap zero solid BUILDINGS. ✓
- **Claim/route collision:** 22 claim anchors + 19 route stops overlap zero solid BUILDINGS; projects no longer sits on Stripe. ✓
- **Office door:** centered south gap; an E-valid point 20px outside is collision-free and can exit the gap. ✓
- **Facade blocks a road:** zero LANDMARK_FACADES × ROAD_SEGMENTS intersections; new solids also avoid roads. ✓
- **Kill/push the only seller:** 20 repeated attacks leave each essential clerk at 80 HP, original coordinates, alive, no wanted/cred/combo change. ✓
- **Repurchase office/upgrade:** owned records and durable partial-save witnesses reconcile upward; deductions occur once. ✓
- **Malformed Infinity counters:** normalize to finite nonnegative values. ✓
- **Duplicate work serial:** active serial, completed count, and order serial reconcile monotonically. ✓
- **Fourth same-day payout:** final filing rechecks capacity; malformed over-cap paperwork waits unpaid until dawn. ✓
- **Claim duplicate/reward drift:** actual-source flow paid one fee and exactly +2 cred; install performed one transaction save. ✓
- **Lost desk/radio bit:** durable claim/work evidence restores the permanent prerequisite instead of preserving impossible paperwork. ✓
- **Partial milestone save:** surviving claim ids repair quest availability and all threshold achievements idempotently in one save. ✓
- **Route hidden during paperwork:** office target owns hint/interaction/objective priority; route cursor remains unchanged and resumes afterward. ✓
- **Cache:** 352/360 character/player canvases, zero blank entries; 7 environment and 20 landmark canvases nonblank. ✓
- **Performance smoke:** 65-NPC deterministic update/draw harness remained far below 16ms with no runtime exception; fixed-count new loops are bounded/culling-aware. ✓
- **WASD:** W+D remained equal-axis normalized; releasing D continued W immediately; blur/repeat safety remained intact. ✓
- **18s → 8s:** at exactly 18,000ms high became crashT=8000; exactly 8,000ms later crash reached zero. ✓
- **Standalone/save:** one script, no external script/link/import URL, prohibited storage, or dependency; maxed v18 save measured 8,576 bytes. ✓

### DRIFT CHECK

Implementation matches the v18 SPEC: 5800×3800 world, three far districts, route-3 office unlock, exact acquisition/upgrade/claim costs, eleven separated claims, LIKED selection gates, one active paper contract, explicit radio orders, capped rewards/capacity, one primary target, persisted normalized state, essential clerks, cached signs/sprites, safe paginated bus travel, and no passive income.

The code does not grant rocks, copper, supplies, equipment, combat power, or faction allegiance from claims/orders. The Block remains the only smoke/cook location. Tony HP/phases and the high/crash timing were not changed. The only playerAttack change is the explicit early denial for `essential` clerical fixtures.

### PROPERTY VERIFICATION

- One standalone HTML, no CDN/framework/build step/external asset. ✓
- Game persistence still speaks only through async `window.storage` calls inside try/catch. ✓
- Audio still initializes on first key/click/touch; no new autoplay path. ✓
- New named sprites are 16×16 logical, palette-indexed, cached to 32×32, and drawn with `drawImage`. ✓
- Character/player cache stays below 360; fixed auxiliary caches stay below 48. ✓
- The office survives death/arrest/endings/reload because every mutation saves durable state; paperwork never pays on load. ✓
- Claims never mutate faction territory, protected districts, Tony, the crate, the church, the heist, or vendors. ✓
- Work remains endless but bounded; ownership never decays and never pays unattended. ✓
- Boss code remains within the existing <90-second contract. ✓
- No real city, real victim, real-world trafficking detail, cure ending, tutorial modal, fourth wall, or new currency. ✓

### NEXT

- Operator playtest the intended spine in a normal browser: intro → three routes → walk to THE LOT → buy office → install desk → claim Canal → install radio → file one order → sleep → file another.
- Walk every far-east road once at day and night. Confirm Warehouse Row, Canal, and Lot read as different places and that the office upgrades remain visible under real canvas rendering.
- Test a real persisted refresh after office purchase, after the claim fee, after sign installation, and while carrying an inspected work order.
- Profile a real target browser with 60+ visible NPCs/weather/incident/signs; deterministic harness numbers are strong but not a substitute for GPU/canvas timing.
- If the paper empire needs more content, add authored task-copy variants and visible office clutter milestones before adding another resource or passive system.

### GOTCHA

- `CLAIM_SITES` and `ROUTE_STOPS` ids are serialized. Append or migrate; do not casually rename/remove them.
- `districtClaims` is not faction territory. Never feed it into `updateTerritory()` or rewrite `ZONES[].faction` from a form.
- `ensureOfficeState()` replaces the normalized office object. Do not retain a local reference across another normalizing call unless that call is known not to replace state.
- Claim install must call `updateOfficeMilestones(false)` because its final `saveGame()` owns the complete transaction.
- Work filing must keep the final daily-cap check even though acceptance also checks it; malformed/partial saves are part of the contract.
- THE LEASING GUY is the only purchase transaction. Keep him and GUTTER GREG `essential`, and keep the playerAttack early branch free of combo/reward side effects.
- Bus destinations require explicit safe `x,y`; a zone center may be a building.
- Character cache headroom is now 8 canvases. A new three-frame named NPC family consumes three.
- Gzip headroom is roughly 5.5KB under the v18 ceiling. Prefer extending existing data/state/render systems over adding another parallel framework.
- Cold-load `npcsKilled` hydration still runs before `spawnNpcs()` in the inherited code, so ordinary saved NPC deaths do not currently rehydrate. This pre-existing issue does not affect essential v18 clerks; fix it only with a separate spec because Tony/vendor persistence consequences need a decision.

---

## July 15, 2026 — Claude audit response / v19 modular stabilization

### WHAT

1. Read `DELEGATIONCODEX.md` first, then `DRIFTAUDIT.md` and `LEGIBILITYAUDIT.md` as directed. Froze the audited `rock_bottom_v19.html` reference at SHA-256 `C25DB5E17536AEC092143D87DBF8C113325076A8B8E196A98AECB84694A25C8B` and checkpointed the existing lineage before changes.
2. Made the one-line Wave 1 repair: `#vignette` now sits below gameplay UI. Its shadow, size, opacity, scanlines, canvas, and gameplay values are unchanged.
3. Ratified retirement of the artifact-era single-file rule. Active source is `index.html` plus 38 native ES-module files under `src/`; v19 remains an untouched behavior oracle. Extracted all 37 source chunks, removed the transitional `legacy.js`, and kept every module below 1,000 lines.
4. Added deterministic module/runtime tooling. The module gate checks reference hash, exact source-range coverage, linkability, module size, and forbidden synchronous storage. The runtime smoke compares frozen and modular initialization, new-game state, W+D movement, partial key release, Tony dialogue, exact 18,000ms high → 8,000ms crash, sprite keys, and real save/load round trips.
5. Wrote the four legibility contracts before fixing them. Added complete authored signs, a data-driven laundromat label offset, feet-sorted nameplate deconfliction with reused boxes, and measured graffiti fitting/culling with one-time migration of v19 layouts.
6. Added `tools/legibility-gate.mjs`: 24/24 named building signs, 23/23 clear zone labels, 56 production nameplates plus a dense 60-label fixture with zero intersections, and 14/14 deterministic graffiti records inside measured wall bounds.
7. Completed Wave 4 as documentation only. `REFACTOR-FINDINGS.md` now inventories every found travel/withdrawal/day/route/office/bus/phone/police/incident dependency, authored population/resource/prop/light/transport/content coverage gap, and minimap resolution relationship. It also records positive relationships and exclusions so the vignette, local hitboxes, fixed camera, and player-time events are not falsely swept into the growth thesis.
8. Restored the VIBE registry as a mechanical shipping gate. The audit estimated roughly 26 missing rows; exhaustive source/runtime inventory found 30. VIBE now has 55 complete canonical rows covering 59 distinct source identities, four explicit same-person/state aliases, one generated CURB PRETENDER family, 60 actor-authoring sites, and all 56 fresh-game actors.
9. Flagged `TARP KNIGHT`, `CART LANCER`, `WIRE DEACON`, and `CURB HOLDOUT` without renaming them. Added separate open operator records for those names, clerical-pattern monopoly, the medieval register, and VIBE's missing scope/campaign grammar.
10. Repaired only the audited office encoding block: 17 corrupt middle dots on ten player-facing lines plus one corrupt em dash in the v18 section comment. Added a targeted regression assertion and left the frozen v19 file untouched.
11. Updated README and DELEGATION for the modular entry point, current build, gates, shipped audit work, and honest HTTP requirement. No new sound, NPC behavior, save field, resource, currency, boss rule, or external runtime dependency was added.

### WHY

The audits found a process failure more than a lack of content: systems grew by copied constants, visual relationships were implied instead of asserted, and the one machine-checkable VIBE rule quietly stopped running. The repair makes relationships executable where the answer is objective, documents them where the answer is a design choice, and leaves taste decisions with the operator.

The modular split was necessary to make the game maintainable without pretending the old monolith remained safe at v19 scale. Behavior parity came first; improvements landed only after the frozen extraction passed.

### DECIDED / REASONING

- **Frozen v19 is an oracle, not active source.** Its hash is a hard gate. Post-audit fixes live only in modules, making every intentional divergence reviewable.
- **Static plus deterministic runtime registry verification.** Startup catches 56 live actors. Source scanning catches bosses, pets, day actors, transformations, cops, adds, and generated families that are not all alive together.
- **Registry names, not duplicate state rows.** Fallen O'Malley and SKID variants explicitly alias their canonical people. Brutus the Older, Old School Brutus, Your Possum, and the day visitor remain distinct identities.
- **Register generic COP.** Guard mooks must pass the table, so exempting generic cops would reproduce the same loophole under another uniform.
- **No automatic world-scale rebalance.** A larger map may justify more phones, smoke access, transit, light, cash, incidents, or time; it may also justify intentional scarcity. Wave 4 exposes the relationships and measured costs without choosing them.
- **Measured geometry over guessed string length.** Building coverage is set-based; zone labels use ink boxes; nameplates use accepted boxes; graffiti uses the actual selected font and wall. Counts alone cannot prove those relationships.
- **Vignette kept out of the growth story.** It was byte-identical across versions. Only its UI z-order was objectively wrong; intensity is a separate fixed-viewport decision.
- **Operator recommendations remain non-ratified.** Neither an auditor nor an implementation pass gets to rename guards, ration the clerical pattern, amend VIBE's mundane rule, or set campaign-scope quotas.

### TRIED / ABANDONED

- The permitted in-app browser refused local `file://` navigation. Native modules require HTTP, and browser policy forbade routing around that restriction with a localhost server, headless browser, or different browser surface. Continued with the deterministic VM harness and static geometry/source gates; did not claim a live visual/audio pass.
- Considered a central runtime NPC insertion API and live validator. Rejected for this wave because it would reroute every roster mutation and risk behavior/performance changes. The gate instead enforces the existing adjacent `name, sprite` authoring form, recognizes only enumerated computed expressions, and fails when authoring escapes that boundary.
- The audit's “~26” registry estimate omitted `MAYOR'S COUSIN`, `THE PRIEST'S SON`, `SOMEONE YOU DON'T KNOW`, and generic `COP`. Enumerated all 59 source display identities instead of stopping at the estimate.
- Did not run a broad encoding cleanup. Legacy mojibake exists elsewhere in frozen lineage; only the eleven audited office lines were authorized and repaired.
- Did not expand the map, rebalance withdrawal, add transit nodes, rewrite routes, or change the four guard names while documenting Wave 4/5 findings.

### COUNTEREXAMPLE HUNT

- **Reference drift:** frozen v19 SHA-256 still equals the ratified hash. ✓
- **Lost/duplicate extraction:** every v19 script-body line 249–12733 belongs to exactly one manifest range; 37/37 chunks extracted and 38 JS files link. ✓
- **Legacy escape hatch:** no `src/legacy.js`; no module exceeds 1,000 lines. ✓
- **Storage regression:** no production module references `localStorage` or `sessionStorage`; real `window.storage` and save/load round trips pass. ✓
- **WASD chord bug:** W+D moves diagonally; releasing D leaves W moving immediately with zero lateral drift. ✓
- **Core loop drift:** exactly 18,000ms rocked-up creates exactly 8,000ms crash; another exact 8,000ms reaches zero in both reference and modules. ✓
- **Missing sign:** all 24 named building entries resolve to a non-empty authored sign. ✓
- **Zone label over art:** measured boxes for all 23 labels overlap zero building bodies/awnings. ✓
- **Crowded names:** production 56 and dense synthetic 60 place with zero strict box intersections. ✓
- **Graffiti overflow:** production tags, every eligible building/font-size pool, and migrated legacy records remain inside measured walls. ✓
- **Registry omission:** 55 complete rows cover 59 source identities, 60 actor sites, 56 runtime actors, four aliases, and the numbered pretender family. Unknown computed names and incomplete rows fail. ✓
- **Taste disguised as fix:** four guard names and three broader design questions are recorded OPEN; runtime names and VIBE rules are unchanged except for required row backfill. ✓
- **Encoding recurrence:** the campaign module contains neither audited corrupt token; the module gate asserts both sequences stay absent. ✓

### DRIFT CHECK

The modular initialization and exercised runtime snapshots match frozen v19 except for explicitly ratified post-audit presentation/content-encoding changes. Movement math, combat numbers, boss phases, player resources, save key/shape, route/claim ids, interaction priority, audio initialization path, smoke access, and high/crash timing were not altered.

Wave 3 implementation matches its four written contracts. Wave 4 changed findings only. Wave 5 changes VIBE completeness and test enforcement, not runtime names or behavior. The office encoding repair changes displayed punctuation only.

### PROPERTY VERIFICATION

- Active build has zero external runtime dependencies, CDN imports, frameworks, or build step. ✓
- Persistence remains async `window.storage`; IndexedDB adapter behavior is unchanged. ✓
- Audio context creation remains gated by first user key/click/touch. ✓
- Character art remains palette-indexed, 16×16 logical, prerendered/cached, and drawn with `drawImage`; cache still reports 373 keys. ✓
- The Block remains the only smoke/cook location and a real rock remains required for anointing. ✓
- Exact 18s high → 8s crash is now a permanent runtime gate. ✓
- Boss implementation and HP/add values were untouched; the existing <90-second contract is unchanged. ✓
- VIBE row backfill introduces no new actor, dialogue, currency, real place, victim reference, cure ending, tutorial modal, or fourth-wall line. ✓
- Nameplate layout reuses the existing frame buffer; graffiti remains bounded/persisted; no new per-frame full-world loop was added. ✓

### NEXT

- Operator playtest the served `index.html` build at desktop and mobile sizes. Inspect all four fixed legibility cases in motion, especially dense laundromat names and old-save graffiti migration.
- Run a real audio pass from title click through smoke → crash, combat, office toast, and a kingdom boss. The VM proves timing/state, not speaker output.
- Decide the four open records in `REFACTOR-FINDINGS.md`: weak guard names, clerical-pattern rotation, medieval register wording, and VIBE scope/campaign grammar.
- Review Wave 4's dependency inventory and ratify relationships before balancing. The highest-risk measured interaction is the sole `30s` public-phone window against `40.8–69.4s` far-map travel; the highest-scope decision is smoke/transit/recovery coverage against an `8600×5600` world.
- If live browser inspection finds a new defect, add its measurable relationship to SPEC and a failing gate before changing implementation.

### GOTCHA

- `rock_bottom_v19.html` is immutable reference material. Do not “sync” modular fixes back into it or update its manifest hash.
- Native modules require HTTP. Do not restore the monolith just to regain double-click execution.
- `tools/*.mjs` gates require `node --experimental-vm-modules` on the current Node runtime.
- NPC actor literals are deliberately authored with adjacent `name, sprite` fields. Reordering or introducing a computed name makes the registry gate fail until the expression is explicitly modeled.
- VIBE aliases are same-person/state exceptions, not a generic ignore list. The numbered pretender is the only generated display-name family.
- Wave 4 findings are not approved balance changes. Do not multiply timers or counts by world area; choose a travel/coverage invariant first.
- Nameplate collision is solved, but maximum upward displacement/viewport containment remains a documented viewport relationship, not silently fixed.
- Live visual/audio QA is still pending. Do not describe VM/static verification as a browser playtest.

---

## July 15, 2026 — OD-1..4 ratification / gate hardening

### WHAT

1. Preserved and included the pre-existing `REFACTOR-FINDINGS.md` decision-register changes, then reconciled its stale “all open” preface with the four decided 2026-07-15 entries.
2. Canonized the Clerical Pattern as VIBE pattern #5. New permanent-loop beats are capped at 50% clerical per wave; the shipped 54 beats are grandfathered.
3. Replaced HARD YES #6 with the ratified sentence verbatim and added the campaign/endless scope invariant: BAD IDEA must periodically return through score → smoke → 18s high → 8s crash. Enforcement mechanics remain deferred to the Wave-4 world-scale session.
4. Changed the throne-guard display label to `KNIGHT EMERITUS` in the complete four-cell VIBE row and the three campaign authoring literals. IDs, sprites, spawn sites, counts, HP, damage, speed, archetypes, rewards, saves, and behavior are unchanged.
5. Converted the four reserved guard labels into dated decision chains. Each current name must exist in the canonical registry, authored source identities, and the fresh runtime, preventing an orphaned old VIBE row from concealing a later unratified rename.
6. Added the plain-Node `tools/run-gates.mjs` launcher and two-line Windows shim. The launcher streams the four gates with `--experimental-vm-modules`, suppresses experimental warnings, stops on first failure, and reports 4/4 only after all children pass.
7. Added early `vm.SourceTextModule` guards to the runtime harness and smoke test. Naive invocation now prints one command hint and exits 1 without a stack trace.

### WHY

The decision register had moved from audit evidence to ratified canon, but VIBE, source, SPEC, and the permanent gate still described the old state. This pass makes the decisions agree across every authority surface while keeping gameplay values frozen. The runner removes a fragile four-command setup step without adding a package manager or dependency.

### DECIDED / REASONING

- **Future share, not retroactive churn.** The clerical pattern remains the world spine; only new permanent-loop beats enter the 50% budget.
- **Scope now, numbers later.** The core loop remains the BAD IDEA, but frequency, transport, and coverage budgets require the deferred world-scale relationship work.
- **Reservation means presence, not a stale row.** A reserved label must be canonical, authored, and live at fresh start. A later rename requires a new dated chain entry.
- **Display-only rename.** Stable runtime IDs make a save migration unnecessary; the label is not persisted.
- **One review command.** The runner uses the current Node executable and inherited stdio for Windows-safe, immediate gate output.

### TRIED / ABANDONED

- GitHub CLI authentication initially could not read its user config inside the filesystem sandbox. Retried through the approved GitHub configuration boundary; authentication is valid.
- Did not add numeric scope enforcement, rewrite any of the 54 shipped clerical beats, change campaign dialogue/objective/ending copy beyond the approved display label, or touch the frozen v19 reference.

### COUNTEREXAMPLE HUNT

- A source-only guard rename fails as an unregistered identity and as a missing reserved source/runtime name.
- A coordinated source + VIBE rename that leaves the old row behind still fails because the registered current name is no longer authored or live.
- A broken or undated reserved-name decision chain fails before registry/runtime acceptance.
- Naive `node tools/runtime-smoke.mjs` exits 1 with a friendly line and no raw `TypeError` stack.
- The all-gates runner reaches its success receipt only after all four children exit zero.

### DRIFT / PROPERTY CHECK

- Frozen v19 SHA-256 remains `c25db5e17536aec092143d87dbf8c113325076a8b8e196a98aecb84694a25c8b`.
- Module extraction/linking, 56-NPC runtime parity, WASD chord/release, exact 18s→8s status timing, legibility geometry, registry counts, storage, dialogue, and 373 sprite keys all pass.
- No save key, timing constant, ID, sprite, balance value, package file, lockfile, dependency, or non-display gameplay copy changed.

### NEXT

- Use the Wave-4 world-scale session to choose frequency, transport, and coverage mechanics for the ratified core-loop scope clause.
- Any future reserved guard rename must append a dated decision-chain entry and update VIBE/source together.

### GOTCHA

- `rock_bottom_v19.html` remains immutable.
- Direct runtime-gate invocation still needs `--experimental-vm-modules`; `node tools/run-gates.mjs` supplies it automatically.

---

## July 15, 2026 — v20 landing 1 / presentation boundary + unique cart

### WHAT

1. Reproduced both HUD audit failures: height-limited desktop stages retained a fixed-width key ledger, and the `171px` mobile topbar covered `91px` of the ticker's `80px` reservation.
2. Added a pure presentation resolver and wired HUD/chrome bounds to the actual centered 4:3 game rectangle on startup and resize. HUD columns now own disjoint flex halves, long text wraps inside its half, and the redundant key ledger hides at a `520px` game width.
3. Reproduced the cart blocker: BUSKER's `60px` NPC-priority disc fully covered the cart's `36px` mount disc at `(1100,1520)`. Moved only the rideable cart to `(1000,1600)`, `106.2px` from the nearest interactive NPC.
4. Removed the cart prop's parallel `mounted` field. `P.cartMounted` now controls ordinary mount/dismount, Big Guy acquisition, world visibility, player underlay, action hint, stats, restart, and the existing save field.
5. Added `presentation-gate`, placed it in the permanent runner, and recorded OD-6 plus the implemented SPEC slice.

### WHY / PATTERN

- Preserve NPC-first interaction instead of creating a cart exception; fix the authored relationship that made the cart unreachable.
- One durable authority prevents the player/cart prop from disagreeing after Big Guy acquisition or load.
- The HUD follows the game rectangle because viewport width and rendered game width are not the same relationship in short or letterboxed layouts.

### TRIED / ABANDONED

- The in-app browser could not navigate to the local HTTP/file preview under its URL/network policy. No alternate browser workaround was used. Deterministic runtime and geometry fixtures became the verification surface.
- A simple `cart.mounted='me'` reconciliation was rejected: it would leave two authorities and would not repair every acquisition/restart path.
- Lifting cart interaction above NPCs was rejected because it would regress the ratified NPC-first priority chain.

### COUNTEREXAMPLE / DRIFT / PROPERTY CHECK

- Fixtures cover `800x600`, `1024x480`, `1024x360`, `1280x300`, `390x844`, and `844x390`; HUD columns stay inside the game rectangle and touch chrome is disjoint.
- Cart spawn clearance exceeds `60+36px`; ordinary use, Big Guy, mounted save/load, and fresh reset share one authority. Base `2.2` speed / `100` HP and mounted `3.7` speed / `110` HP remain unchanged.
- Full gate stack passes 5/5. Frozen v19, save key/version, NPC priority, cart roadkill/damage, WASD chord/release, and exact 18000ms→8000ms status timing remain intact.

### NEXT / GOTCHA

- Implement THE REGULAR as landing 2. `sell` is part of the five-verb schema but has no honest hook at the four concession venues; register it as dormant rather than relabeling Big Guy's trade or adding a fifth concession.
- Keep `rock_bottom_v19.html` immutable. Live visual inspection is still pending; do not describe deterministic geometry as a browser playtest.

---
