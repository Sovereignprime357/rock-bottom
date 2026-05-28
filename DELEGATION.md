# DELEGATION.md — Rock Bottom v4 Backlog

> Tasks for the next agent picking this up. Prioritized. Each task has a SPEC stub. Pick top-down. Don't ship a task without updating its status here.

---

## v13 wave 8a — SHIPPED ✓ (May 28, 2026) — world expansion + 4 new zones

Lands on `rock_bottom_v13.html`. SAVE_KEY untouched. See SPEC.md `WORLD EXPANSION (v13 wave 8a)` for the contract; BRAIN.md wave 8a entry for judgment calls + counterexample hunt.

- [x] **Part A — WORLD expanded** from 2200×1900 → 4400×3400. Every world-coord clamp routed through `WORLD.w` / `WORLD.h` (audit pass confirmed zero hardcoded refs in code). Camera + minimap math verified.
- [x] **Part B1 — TRAIN YARD** (zone @ 260,2700,1100,560). Conductor relocated here. Train Hopper NPC + 3 freight_car props + chalk lore message. First-entry feed post. Night gate.
- [x] **Part B2 — THE PARK** (zone @ 2400,900,620,500). Pigeon King relocated here. Park Bench Philosopher NPC + daily-cycle question (7-line cycle). Park bench sit mechanic (+1 brain/2s, BENCH_PRESS at 60s). Night-park hidden cash roll.
- [x] **Part B3 — SKID ROW** (zone @ 2480,1520,900,720). 8 makeshift SHACK buildings + 3 ambient hostiles (skid_brutus_1 / skid_lurch / skid_sherri) + 5 tweaker-vision hidden cash piles + Price Guy random encounter (every 3 days).
- [x] **Part B4 — THE OLD SCHOOL** (zone @ 3400,280,760,640). OLDSCHOOL building with modal-dialogue interior (Wave 7 pattern). Old School Brutus boss (hp 250, dmg 35). Schoolyard props + hidden $30 pile + mural.
- [x] **Part C — wire-up**. 4 new achievements (school_s_out, bench_press, the_price_paid, train_hopped). Vendor index entries for Train Hopper + Philosopher. Faction tags. Phone-feed first-entry posts (4 zones). Save backward-compat (8 new flags + 1 new counter, defaults wired).

---

## v13 wave 7 — SHIPPED ✓ (May 28, 2026) — faction rep + day events + hideouts

Lands on `rock_bottom_v13.html`. SAVE_KEY untouched. See SPEC.md `FACTIONS`, `DAY EVENTS`, `HIDEOUTS` for the contract; BRAIN.md wave 7 entry for judgment calls.

- [x] **Part A — faction reputation system**
  - [x] `P.faction = { street, scrap, spiritual }` + save/load forward-compat (old saves default neutral)
  - [x] `factionTier(value)` helper (hated ≤−10 / neutral −9..+9 / liked +10..+24 / loved ≥+25)
  - [x] `adjustFaction(faction, delta)` mutator with [-50,+50] clamp + tier transition broadcast + LOVED achievement unlocks
  - [x] Rep deltas wired into every existing transaction (Tony/Stripe/Yuri/Pete/priest/mom/smoking/kills/dog/Pinky/Math/Barb/sleep)
  - [x] Tier effects: Tony $8 base at street liked+; Brutus Older passive at street loved + torch drop 0.25→0.375; Yuri $25→$28 at scrap liked+; Pete $15→$17 at scrap liked+, $50 loan 1×/day at scrap loved, refuse-to-buy at scrap hated; Pinky refusal at street hated; O'Malley anti-fall gate at spiritual ≥+10; mom proud-call (+5 brain) 1×/day at spiritual liked+
  - [x] Q-key panel FACTIONS section at top with tier label + value bar per faction
  - [x] Tier transition phone-feed + toast lines (12 strings, one per faction × tier crossing)
- [x] **Part B — day-specific events** (fire once per save, guarded flags)
  - [x] Day 3 "the visit" — passive NPC + dialogue + wander-off-map
  - [x] Day 7 "the silence" — 4-min ticker/phone suppression via `silenceUntilT`
  - [x] Day 14 "the inheritance" — $500 pile + rep deltas + custom pickup toast
  - [x] Day 30 "the bus" — bus driver + THE_BUS ending + rehydrate-on-reload guard
- [x] **Part C — hideouts** (modal-dialogue interior, not scene swap — see BRAIN judgment-call note)
  - [x] Scrap yard hideout (gate: scrap ≥+5, cost $150 one-time, door at (520,200))
  - [x] Mom's apartment hideout (gate: spiritual ≥+10, $30/day with eviction on shortfall, door at (1230,1180))
  - [x] Shared storage chest (rocks/copper/cash/items, survives death via `state.hideoutStash`)
  - [x] Rest + sleep actions apply HP / wanted / day / rep effects discretely
- [x] **4 new achievements**: THE BUS, THE BLOCK KNOWS, YURI COUNTS YOU IN, MOM IS PROUD

---

## v13 wave 6.5 — SHIPPED ✓ (May 26, 2026) — economy balance pass

- [x] **Exploit 1: kombucha lady / mom infinite loop** — `momDialogue` ask-money (both $10 and $20 share a slot) gated 1×/day via `state.counters.kombuchaAskDay`; compliment kombucha gated 1×/day via `kombuchaComplimentDay`. Consumed branches surface VIBE refusal lines so the player sees the gate. Toast suffixes "come back tomorrow." on the productive paths.
- [x] **Exploit 2: tic tacs cure shakes** — `priestDialogue` accept-tic-tac branch no longer reduces `P.shakes`. New behavior: +5 brain (small sober buff). Canonical toast: `"the tic tac is gone. the shakes do not care."` Priest_mercy quest still completes on accept. Donation branch also gated 1×/day via `priestDonateDay` (closes the $5 → +3 cred grind once Mom's $10 is also capped).
- [x] **Exploit 3: Barb→Stripe arbitrage** — two-sided gate. **Stripe** (`stripeFencedToday`): tiered $6 / $4 / $2 / closed at rocks 0-3 / 4-6 / 7-9 / 10+. Bulk-sell loop applies the ladder per-rock and breaks on close. **Barb** (`barbPacketsToday`): 6-packet daily cap. Single = 1, bulk = 5. Bulk button hidden when remaining < 5 (own refusal). All four bracket tiers carry distinct VIBE refusal lines.
- [x] **Audit sweep gates** — `lurchDollarDay`, `sherriSpiderDay`, `paulieFaceDay` daily 1×/day on the small cred grants (was infinite cred trickle when paired with infinite mom-cash). `peteCashToday` $200/day cap on all sells to Pete (clipped payouts when near cap, full refusal at empty). `heistsToday` 3-heist/day cap on the abandoned-building copper run (closes the conductor-arbitrage path).
- [x] **Daily reset wiring** — new `resetDailyCounters()` helper iterates over `DAILY_COUNTER_KEYS = ['stripeFencedToday','barbPacketsToday','peteCashToday','heistsToday']`. Called from `updateWorld` inside the `state.dayTime >= 1` branch (day-tick) right after `rollHustles()`. Day-stamp counters (`*Day` fields) self-reset via `=== state.day` and don't need explicit reset.
- [x] **Save backward-compat** — new counter fields added to all 3 counter-init sites (load `Object.assign` defaults, top-level state init, `startGame` fresh-save reset). SAVE_KEY unchanged. Old saves load forward; new fields default to 0 → gates open as if it's day 1.
- [x] **SPEC.md** — added `## KNOWN EXPLOITS (v13 wave 6) — CLOSED in wave 6.5` block + a comprehensive `## ECONOMY GATES (v13 wave 6.5)` audit table covering every grant-side NPC. Pinky Polenta deliberately documented as the intentionally-ungated "overflow supply" lane.

Notes from shipping: Mom and the "kombucha lady" turned out to be the same NPC (`momDialogue`), so both exploits land on the same dialogue function. Daily-stamp counters (`*Day`) are cheaper than booleans + explicit reset — comparing `=== state.day` self-resets across day rollover without polluting `resetDailyCounters()`. Stripe's per-rock tier on bulk sell is computed inside the while-loop so a mid-batch crossing of $6→$4 charges correctly. Pete's daily cap uses a `tryPay` helper that clips the payout if the counter would exceed cap — the player gets partial money on the last sale that crosses the line, not a hard reject. Pinky kept ungated by design — Barb is the "capped, clean" lane; Pinky is the "uncapped, dirty" lane. Removing that asymmetry would kill the cook loop on bad days.

---

## v13 wave 6 — SHIPPED ✓ (May 26, 2026)

- [x] **Highway Underpass finish pass** — cracked-concrete `TILE_PALETTES.underpass` (oilstain + concrete flags, drawGroundTile fracture lines + black oil ellipses); 4 tents (varied tarp colors) as new `drawProp` branch; cardboard sign at (1340,412) next to The Mathematician ("WILL TRADE WORDS FOR MATH"); 3 sodium-orange light patches in `drawUnderpass` via additive radial gradients; one-shot first-entry echo line ("the air changes. you can hear yourself walk.") + feed post gated by `state.flags.underpassEntered`.
- [x] **SCRAP YARD depth pass** — judgment call: the zone already existed at (100,80,520,360), so no WORLD expansion needed. `TILE_PALETTES.scrap` reworked (dirt:true + warmer brown base + dirt mottling clumps in drawGroundTile). New `drawProp` branches for `scrap_pile` (twisted metal + rebar sticks), `car_wreck` (totaled sedan on cinderblocks), `leash_post` (small wooden post), `pay_phone` (rusty booth with rings indicator). Yuri stays at (300,200) — already in zone.
- [x] **`scrap_dog` NPC** — chained at (580,150), archetype `'passive'`, leash rendered by new `drawDogLeash` between drawProps and NPC pass. New `PALS.scrap_dog` palette + sprite cache entry reusing `makeDog()` shapes. Tail wags when player approaches within 100px.
- [x] **Interactive props system** — new `interactiveProps[]` array (parallel to PROPS) + `initInteractiveProps()` initializer (called from startGame). Update loop in `updateWorld` (cooldowns + bottle respawn).
- [x] **Kickable trash cans** — 6 placed (one per major zone). E within 50px: 50% cash $2-5, 20% junk, 10% food, 20% rats burst. 60s cooldown + 200ms tip rotation. New `audio.kick()` synth.
- [x] **Breakable bottles** — 8 placed at game start from 16 candidate spots, jittered ±20px. Shatter on player swing via `playerAttack` hit-box check. 12-particle glass burst + 25% chance to drop `broken_bottle` weapon (dmg+8 reach 6 cd 300). 60-120s respawn pool.
- [x] **Dumpster dig loot table** — distance-from-block biased (close = 50% nothing, far = 30%). Categories: 30% cash $1-4, 20% junk, 10% clean packet, 8% broken_bottle weapon. Far dumpsters (farFactor>0.6) carry rare propane drop (no-dupe gated via `state.flags.dumpsterPropaneAwarded`). Per-dumpster 90s `diveCdT` cooldown.
- [x] **Public phone** — one in SCRAP YARD at (130,220). Rings every 4-8 min for 30s. New `PUBLIC_PHONE_LINES` (10 cursed lines). Answer with E within 38px. `state.publicPhoneAnswered` counter unlocks PHONE_BOOTH_PROPHET at 5. One ~10% line plants a $50 cashPile at (1800,1320) behind the church.
- [x] **Procedural graffiti** — `GRAFFITI_LINES` constant (36 voice fragments). `buildGraffiti` rewritten to walk every non-locked BUILDING and assign 12-18 tags to randomly-selected wall faces. Persisted via `state.graffiti` (save/load). `drawGraffiti` uses bold low-saturation chalk colors, -5°/+5° rotation, 0.18-alpha double-pass for grit feel. Renders between drawBuilding and drawProps. (Crosses off backlog item 18.)
- [x] **`scrap_dog` side quest** — `state.quests.scrap_dog.state: 'idle'|'fed'|'freed'|'left'`. Three options: feed (consumes food, +1 cred, cop discomfort radius), free (lockpick → wandering follower + LIBERATOR), leave (no penalty). Attack-while-chained = one-time THE_PIECE_OF_SHIT + -5 cred, dog goes hostile. 200px cop-discomfort radius applied in updateWorld for both the chained-fed dog and the freed-wandering follower.
- [x] **Wandering freed dog follower** — `spawnFreedDogFollower` adds an `isPet:true` NPC that follows for ~60s then despawns. Reuses the pet-possum follow-at-distance AI (cash-reveal side effect gated to possum only). 1-3min between reappearances. First reappear toast: "the dog is back. he is here. for now."
- [x] **`food` item** — drops 10% from kicked cans, sold by Pete for $3, occasional dumpster bonus. Single-use (feed the dog).
- [x] **3 new achievements** — `LIBERATOR`, `THE_PIECE_OF_SHIT`, `PHONE_BOOTH_PROPHET`.
- [x] **Save backward-compat** — no SAVE_KEY bump. `graffiti` + `publicPhoneAnswered` + extended flags saved/loaded. Old saves default `underpassEntered: true` so they don't re-trigger the echo line on reload.

Notes from shipping: the SCRAP YARD already existed; expansion turned out to be a populate-in-place pass, not a new zone. Yuri's spawn was already inside the scrap yard so he didn't need to move. The graffiti subsystem in v13 was hardcoded — wave 6 rewrote it to use the GRAFFITI_LINES constant + state persistence in one pass. The cop-discomfort radius is applied as a per-frame flag (`n.dogSpookSlow`) in `updateWorld` and read in the default chase-bite branch; no archetype touches needed. The propane torch now has 3 acquisition paths (night-brutus drop / pete pawn at rank ≥3 / rare far-dumpster drop) all guarded by the single `hasPropane()` helper.

---

## v13 wave 5 — SHIPPED ✓ (May 26, 2026)

- [x] **Archetype dispatch** — `n.archetype` string switches in `updateNpc` (line 4084) route hostiles into per-pattern AI branches. 5 archetypes (`charger`, `grabber`, `swarmer`, `ranged`, `cop`) plus `priest_fallen` for the new mini-boss. Non-archetype'd NPCs (larry, dave, alley crackheads, generic cops without backup behavior) fall through to the v12 chase-bite default — no behavior change for them.
- [x] **CHARGER (brutus / brutus_older / berserk)** — `idle → windup (red tint, `!`, audio.windup cue) → lunge (vector locked at windup start) → cooldown (vulnerable: +25% playerAttack damage)`. Three tiers via `n.berserk` flag: standard windup 800/lunge 1000ms/×2.0, older 550/1400/×2.4, berserk 400/800/×3.0. `DODGED_THE_LUNGE` fires when a lunge ends without `n.chargeLanded`.
- [x] **GRABBER (lurch)** — chase + on-contact stun: dmg ×1.3, applies `P.stunT = 500ms` (input lock on movement / SPACE / E), 200ms post-grab freeze for the arms-extended pose. First-grab toast: "GRABBED.\nhis arms are too long."
- [x] **SWARMER (sherri)** — speed ×1.4, dmg ×0.6. On aggro, `spawnSwarmerSibling` pushes a clone 60px offset (cap 2 total, deduped by 400px proximity). Toast: "another one shows up.\nit has the same haircut."
- [x] **RANGED (paulie)** — maintains 180-260px envelope, throws bottles every 1500ms via the projectile system. 350ms aim-raise telegraph + `*` particle, 20% angle wobble (he misses often). Panic-chase 1s if player closes to <120px.
- [x] **Generic projectile system** — `projectiles[]` array; `spawnProjectile({x, y, tx, ty, speed, dmg, slowMs, kind, from, wobble})`; update loop in `updateWorld` (line 4438) handles motion + wall + world-edge + player overlap; pool capped at 40. Kinds: `bottle` (paulie, brown shard impact), `holy` (priest, cyan glow impact). Render between particles and player.
- [x] **Tony boss reframed as 3-act pattern shifts** — p2 (66%): converts `archetype='charger'`, speed 2.4, spawns 2 sherri swarmers ±80px, toast "tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers." p3 (33%): `berserk=true`, speed 3.0, dmg 16, triple-stack bossRoar, toast "tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up."
- [x] **Brutus Older boss reframed** — p1 charger_older from spawn. p2 (50%): spawns 1 sherri swarm pair every 8s as adds (cap 2), toast "he was warming up before." p3 (25%): `berserk + grabber-on-contact`, toast "he doesn't bite anymore.\nhe grabs."
- [x] **THE FALLEN PRIEST mini-boss** — `triggerFallenPriestTransform()` (line 2265) mutates the existing `priest` NPC in place: id → `omalley_fallen`, archetype → `priest_fallen`, hostile + aggro, HP 80 → 160, color `#2a1a2a`. Canonical transform line: "father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong."
- [x] **Two trigger paths** — STEAL: ≥4 priest visits + ≥1 prior steal attempt → next "steal the collection plate" fires the transform. PHONE CALL (`maybeFireFallenPriestCall`, line 2300): rank≥3 + church-visits≥3 + intro done → one-shot ringPhone "father o'malley says the church belongs to whoever has the keys.\nyou don't." Quest flips `available`. Player still has to walk back in + try to steal to actually trigger.
- [x] **Fallen priest 2-phase fight** — p1 (HP ≥50%): kite at 180-280px, throw holy water vials every 1200ms (22 dmg + 1.5s slow), 350ms cyan-glow aim telegraph. p2 (<50% HP): dasher (charger machine with priest tuning — windup 500ms, lunge 900ms/×2.4, cd 1200ms), lunge contact applies the slow too. One-shot phase 2 toast: "the lord is not here.\nthe lord left.\nhe took the bus."
- [x] **`priest_collar` equipment** — slot `hat`, cred +2, new `wantedDecay: 0.3` field (additive multiplier on the `manageCops` decay rate). Drops on omalley_fallen death alongside a $200 cash pile. Renders as small white band with black center seam.
- [x] **`fallen_priest` quest entry** — title "THE FALLEN PRIEST", flav "the priest has been wrong for a while. someone should say so." Closes on omalley_fallen death (line 3394) with questToast + collar pickup.
- [x] **3 new achievements** — `FALLEN` (kill the fallen priest), `DODGED_THE_LUNGE` (sidestep a charger's lunge — fires first time `chargeLanded` is false at lunge end), `OUTRAN_THE_PRIEST` (60s alive with omalley_fallen on the map, tracked via `state.counters.omalleyFallenSurviveT`).
- [x] **Status timers** — `P.stunT` (grabber 500ms, input lock) and `P.slowT` (holy water 1500ms, ×0.5 movement speed in `updatePlayer`). Both ephemeral, never saved. All sites read `Math.max(P.stunT||0, x)` / `Math.max(P.slowT||0, x)` so undefined-safe.
- [x] **Hit-stun baseline** — `n.hitStun = 120ms` on every `playerAttack` damage tick, freezes NPC AI early-return in each archetype branch. Knockback bumped 6 → 8 px on the same hit path. Makes combat feel chunkier without changing damage numbers.
- [x] **Charger vulnerability bonus** — `playerAttack` damage gets ×1.25 multiplier when target archetype is `charger`/`charger_older` AND `chargeState === 'cooldown'`. Rewards reading the lunge.
- [x] **Cop radio-for-backup** — generic cops with no `archetype` field, at d>120px from player, 25%/sec chance to schedule a backup cop spawn 5s later. Capped at COP_HARD_CAP=4. Brendan does NOT radio (his taser branch from wave 2 is untouched).
- [x] **SPEC.md update** — full COMBAT PATTERNS section (line 412) with archetype table, projectile spec, boss-phases-as-pattern-shifts, status effects, hit-stun, charger vulnerability. Plus FALLEN PRIEST section (line 462) with trigger paths, transform, reward, survival achievement.

Notes from shipping: archetype dispatch is by string, not function ref, because the NPC list is serialized — strings roundtrip through save/load cleanly. Default branch preserves v12 chase-bite EXACTLY so generic hostiles (larry, dave, alley crackheads, base cops) feel identical to last wave. The fallen priest's HP is 2× (160) so phase 1 lasts long enough to use the ranged kit (~6 throws) — at the original 80 the ranged phase would be a 2-throw blink. Holy water = slow (not stun) preserves player agency against a kiting enemy and avoids stacking with grabber stun in chaotic encounters (cap via Math.max). Projectile collision intentionally only checks player + walls + edges, NOT other NPCs — friendly fire would be a one-time joke that undermines AI cohesion. Cop radio doesn't apply to brendan because his taser difficulty already makes him a mini-boss; layering radio would compound. Boss phase entry is HP-threshold guarded (`< state.bossPhase`) so a single-frame overkill from p1 → death past p3 fires each phase once and the final death-handler.

---

## v13 wave 4 — SHIPPED ✓ (May 26, 2026)

- [x] **THE HEAT minigame** — `cookBatchMenu` now routes to `startHeatMini(n, mode)` instead of `doCook`. Real-time canvas skill check: gradient bar fills over `fillMs` (mode-dependent: slow=4000ms, fast=2400ms, shakes=1800ms, all=3200ms, propane=1200ms). Lock with SPACE / 1 / Enter / canvas tap; ESC bails (supplies still consumed). 1s grace after fill → auto-burn. 600ms outcome hold reveals the verdict before resuming play.
- [x] **6 outcomes** — PERFECT (yield × 1.15, soap × 0.70), OK (baseline), BAD (yield × 0.60, soap × 1.50), BURN (zero rocks, brain -10, wanted +1, 2s smoke overlay), UNDERCOOK (zero rocks, supplies flat), SOAP-ROCK (15% chance on far miss; yield × 0.5, all rocks tagged as soap). Sweet-spot width = `baseWidth + bb*0.10`, rocked penalty -0.06, clamp [0.05, 0.40] — the bb-brain modulation and dirty-packet weighting from v12/v13 wave 2 are preserved on top.
- [x] **Soap-rocks loop (`P.soapRocks`)** — parallel scalar counter to `P.rocks`. HUD shows the sum (concealed). FIFO smoke: when player smokes at the crate, soap rocks burn FIRST and silently — no rocked-up, no shakes relief, no brain hit, no cred. Canonical toast: "you smoke it. it's soap. you knew. you smoked it anyway." Unlocks SOAP_TONGUE.
- [x] **Propane torch + 4th cook mode** — `EQUIPMENT.propane_torch` (new `tool` slot on `P.equip`). Two acquisitions: (a) 25% drop on a NIGHT-ONLY brutus / brutus_older kill via `cashPiles` with `tool: 'propane_torch'` field (always-visible pickup, brass body + pulsing pilot flame); (b) Pete pawn at rank ≥ 3 stocks one at $80, one-and-done (`peteTorchStocked` / `peteTorchSold` flags). Owning the torch reveals the 5th `cookBatchMenu` option: "propane. (1 packet. tight bar. big yield.)" — tightest sweet (0.08 base) + biggest burn zone (0.15) + × 1.30 yield bonus.
- [x] **Heat-minigame canvas overlay** — 480×240 dark slab, dirty cream type, blue→green→yellow→red→black gradient bar (400×28), highlighted sweet-spot region + white tick, red burn-zone bracket, dirty cream needle, gold locked-in marker, mode-colored outcome label (gold/maroon/violet/cream).
- [x] **Cook predictor lines** — `pickHeatPredictor(brain, rocked, dirty)` surfaces 1 of 8 flavor lines in the menu describing the current cooking state ("rocked → hands aren't yours. the bar shrinks.", "sober + clean → wider sweet spot.", etc.).
- [x] **2s smoke overlay on BURN** — `state.smokeT = 2000` triggers a fullscreen haze + 6 wandering smudges + the line "the smoke is in the floor." Decays in the main loop regardless of game mode.
- [x] **3 new achievements** — THE HEAT HELD (perfect a cook), SOAP TONGUE (smoke a soap rock), CONTROLLED BURN (survive a burn).
- [x] **`hasPropane()` helper** — single source of truth (`P.equip.tool === 'propane_torch'`). Used by cookBatchMenu (gate the 5th option), onNpcDeath (skip dupe drops), peteDialogue (gate the buy / ask-again branches), and cash-pile pickup (skip if already owned).

Notes from shipping: the bb math + per-mode yield/burn rolls + dirty-packet weighted soap rate from v12/v13 are preserved EXACTLY — the new outcome is just a multiplier on top of the existing rolls. Save key (`rockbottom_save_v8`) unchanged; `soapRocks` and `equip.tool` default safely on load. The `state.heat` minigame state is intentionally NOT persisted — saving mid-cook drops you back at `'playing'` with supplies as last saved. The propane brutus drop is night-only because the torch has a "found in the dark" identity; the cash-pile render branch is always-visible so a 25% night drop isn't punishingly easy to miss. Pete's stock gate is rank 3 (strip-mall fiend) — earlier feels premature, later and the loop has already converged.

---

## v13 wave 3 — SHIPPED ✓ (May 26, 2026)

- [x] **Discoverability layer** — `state.metVendors` Set tracks first dialogue per vendor. Bobbing "?" floater above unmet vendors (13 canonical NPC ids), fades on first interaction. Q-key gets a "PEOPLE YOU'VE MET" section showing only met vendors with their zone + one-line tagline (`VENDOR_INDEX_META`).
- [x] **"The day you arrived" 3-quest intro chain** — `intro_remember` / `intro_tony` / `intro_smoke`, FORCED on new saves. Suppresses hustles + random events + ambient phone calls until `state.flags.introDone = true`. $10 pile guaranteed in THE BLOCK. New saves start at $0 cash. Existing saves default `introDone = true` and skip.
- [x] **Mom first-day phone tip** — fires once ~30s into a new save (`state.flags.momIntroFired`), exempt from intro suppression.
- [x] **Side quest: `pigeon_crown`** — pigeon king offers after 2 visits. Spawns crown at 1 of 6 deterministic spots. Pickup adds cursed hat (-3 cred, +1 charisma) and unlocks HEAD_THAT_WEARS.
- [x] **Side quest: `stripe_package`** — stripe offers after 3 visits. Deliver to conductor (auto on proximity) for +$40 +3 cred + EXACT_CHANGE. Or open at the crate for one of 4 outcomes (brick / soaps / knife / wire bait) + WHAT_S_IN_THE_BOX. Opening permanently sets `stripeBetrayed` flag — stripe goes hostile-text, fencing closed.
- [x] **Side quest: `barb_crossword`** — barb mentions on visit 2 (sets `daveHasCrossword`). Demand from dave: cred ≥3 free, else $20 ransom or fight. Killing dave also drops it. Return to barb for free packet + the "BLAME" reveal + SEVEN_ACROSS.
- [x] **Charisma stat** — hidden field on P, summed from EQUIPMENT charisma values via `applyEquipStats()`. Currently only `pigeon_crown` provides +1. `vendorPrice(base)` helper applies 10% discount when ≥1. Plumbed into tony/barb/pinky/stripe price calc.
- [x] **Q-key UI overhaul** — tri-state QUESTS (active / available / done) with reward preview, plus the PEOPLE YOU'VE MET index.
- [x] **4 new achievements** — HEAD_THAT_WEARS, EXACT_CHANGE, WHAT_S_IN_THE_BOX, SEVEN_ACROSS.
- [x] **New weapon: `knife`** — dmg 14, reach 8, cd 260. A possible drop from opening stripe's package.

Notes from shipping: the intro chain auto-completion threshold for `intro_remember` is "any cash >= $10" since the player starts at $0 — this preserves the brief's "any source" path while keeping the dedicated $10 pile as the discoverable breadcrumb. The pile is always-visible (not gated behind tweaker vision) with a gentle pulse glow to read as the tutorial target. Crown locations use a per-save seed (`state.flags.crownSpotIdx`) so the spot is deterministic for the playthrough but varies between saves. The stripe-package "open" UX is surfaced exclusively from the BLOCK's `blockMenu` ("open stripe's package. alone, no one is watching.") — the block is home, opening it anywhere else would feel weird.

---

## v13 wave 2 — SHIPPED ✓ (May 26, 2026)

- [x] **Sprite parity pass** — Baggie Barb got her own palette (faded purple house dress, gray hair, beige skin) and no longer shares launderlady. cubscout / jogger / busker / dogwalker each got a distinct palette in PALS (they had npcStyles entries but were falling through to PALS.tony — every "ambient pedestrian" looked like a small tony).
- [x] **PINKY POLENTA** — new rival supply vendor at a new BUS STOP zone. Sells "house cut" packets ($4 each, $18 for 5 — cheaper than Barb but soap-prone). Sprite uses new `pinky` palette (olive skin, yellow undershirt, gold accent, slick-back hair).
- [x] **THE MATHEMATICIAN** — under the highway underpass. Calculates live cook EV based on brain/rocked-up state. Every 3rd interaction reveals a hidden system tip (5 tips total). New `math` palette + `glasses` accessory option in `makeNPC`.
- [x] **COUSIN BRENDAN** — rookie cop mini-boss. Spawns at wanted ≥ 2 with 30% chance (capped at 1 instance). 55 HP, 2.3 speed, 50-damage taser on 4s recharge. Drops $30 cash pile on death. New `brendan` palette.
- [x] **Dirty-packet economy** — `P.dirtySupplies` counter tracks pinky-sourced packets within `P.supplies`. `doCook` consumes dirty first and applies weighted soap rate (`(dirtyUsed*0.25 + cleanUsed*0.12)/n`). Forward-compatible save (key unchanged).
- [x] **Achievements** — `DUE_DEALER_SYSTEM` (buy from pinky once), `BADGE_MONEY` (defeat brendan).
- [x] **Barb's passive aside** — first pinky purchase flips `state.barbAside`; next barb visit prepends a one-line aside. Flag consumed on display, persisted in save.
- [x] **CHATTER** — added ambient lines for pinky / math / brendan.
- [x] **VIBE.md** identity table extended with the 3 new NPCs (all 4 columns filled).

Notes from shipping: backed off from inventing a new "dirty packet" inventory item — `P.supplies` is a top-level scalar, not in `P.inventory`, so a parallel `P.dirtySupplies` counter fit the existing pattern cleaner. There is no canonical bus station in the world, so a small BUS STOP zone was added between the block, marketplace, and laundromat — natural foot-traffic crossroads, not on top of any existing vendor.

---

## v12 — SHIPPED ✓ (May 23, 2026)

- [x] **Copper heist wired in** — rank gate removed; the brutus jr. door is the gate. (was: rank ≥ 4)
- [x] **BAGGIE BARB** — new vendor in the laundromat. sells unmarked packets ($5 each / $22 for 5). does the crossword. does not look up.
- [x] **Cooking minigame at THE BLOCK** — 4 cook modes (slow / fast / shaky hands special / cook all). brain modulates outcome; rocked-up makes you a worse scientist. 12% soap chance.
- [x] **Stripe fences rocks** — buys at $6/each, bulk at 3+. closes the economy loop.
- [x] **New quest**: THE FINISHER (cook a rock).
- [x] **New hustles**: cook_2 (cook 2 rocks today), fence_3 (sell 3 rocks to stripe).
- [x] **New achievements**: THE CHEF (cook 10 rocks), ARSONIST OF NOTHING (burn a 3-packet batch).
- [x] **HUD** shows 🧪 supplies.
- [x] **Save v9** (supplies + lifetime rocksCooked/rocksFenced); v8 saves load forward.
- [x] **VIBE.md** identity table updated.
- [x] **News ticker** + ambient lore added for the new loop.

Notes from shipping: kept the laundromat as the supply location instead of inventing a new zone — it preserves the grandma-doing-laundry visual disguise. Barb shares the launderlady sprite for now (palette-tinted) — a unique sprite is on the v13 backlog.

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
**Status:** Shipped — initial in v13 wave 2 (The Big Guy + The Mathematician + car rumble), depth pass in v13 wave 6 (cracked-concrete tile palette + oil stains, tent encampment, cardboard sign, sodium-orange light patches, first-entry echo line).

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
**Status:** Shipped in v13 wave 3 (with onboarding chain + side quests + people-met index). Original spec below preserved for archeology.
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
**Status:** Shipped in v13 wave 6. `GRAFFITI_LINES` (36 voice-coherent fragments), 12-18 tags placed on non-locked BUILDING walls at level load via `buildGraffiti`, persisted in `state.graffiti`. Low-saturation chalk colors, -5°/+5° rotation, 8-10px bold Courier with a 0.18-alpha double-pass for the grit feel. Renders between `drawBuilding` and `drawProps`.

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
