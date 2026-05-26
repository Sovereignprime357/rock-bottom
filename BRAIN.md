# BRAIN.md — Session continuity log (append-only)

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
