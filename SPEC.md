# SPEC.md — Rock Bottom Behavioral Contract

> SpecMesh format. Read VIBE.md before this if you haven't already. Spec without vibe is a soulless port.

---

## CURB WAR + ONE CRACKLORD + KINGDOM EXPANSION (v19)

v19 turns the v18 office foothold into an absurd succession war. Four new districts extend the neighborhood east and south. Three rival curb clans defend improvised courts made from tarps, shopping carts, mattresses, wire, buckets, and municipal leftovers. A short, explicit campaign gives the player a purpose without making the world sensible: answer a hostile radio summons, deface three pieces of clan paperwork in each enemy district, defeat its ruler, smoke one real rock at the Block to receive royal static, and challenge the Curb Emperor in THE THRONE DITCH. The receipt names one cracklord; it does not clean up the neighborhood or end play. Routes, office work, faction systems, procedural incidents, daily hustles, and daily pretenders continue forever.

This is a comedy kingdom, not a realistic criminal organization. It owns curbs, bent signs, blue plastic, and incompatible receipts. It never owns people, sells product, creates passive income, models trafficking, or replaces the score -> smoke -> 18-second high -> 8-second crash loop.

### Campaign spine

The canonical durable state is `state.kingdom = { stage, marks, bossId, defeats, pretenderDay, pretenderDefeatedDay, pretendersDefeated }`.

Allowed stages are:

`locked -> summons -> tarp_marks -> tarp_boss -> cart_marks -> cart_boss -> wire_marks -> wire_boss -> anoint -> emperor_gate -> emperor_boss -> complete`

1. `locked` advances to `summons` exactly once when THE OFFICE is owned, at least four durable district claims are installed, and `THE FALLEN KING` is complete. This makes Tony/the co-op corner fight the local prologue to the larger succession claim. The unlock does not require a live NPC and cannot be lost if a partial save drops an availability bit.
2. In `summons`, the office radio carries a rival summons. If the player does not own the radio, the one primary objective says to install it. Answering the radio explicitly starts the war; no cutscene, automatic teleport, or resource reward occurs.
3. Each clan uses a three-mark field phase. `marks` is a three-bit mask (`0..7`) reset only when entering a new clan stage. The three authored public anchors may be handled in any order, each pays nothing, and each can be marked only once. At `marks === 7`, the district's challenge banner becomes the target.
4. Interacting with that banner starts the corresponding boss stage and spawns one ruler plus at most two transient reinforcements. Bosses never spawn from ordinary map initialization, cannot be killed out of sequence, and cannot be duplicated by reopening a dialogue or reloading.
5. Defeating DARRYL UNDER BLUE advances `tarp_boss -> cart_marks`; defeating GENERAL RECEIPT advances `cart_boss -> wire_marks`; defeating BISHOP WIRE advances `wire_boss -> anoint`. Each durable defeat id appears once in the whitelisted `defeats` set. The listed boss reward is granted once at death, then the next stage is saved.
6. `anoint` points back to the Block. Only the successful existing normal `smoke a rock` branch, after one real rock is deducted, advances to `emperor_gate`. Soap, dialogue cancellation, inventory inspection, cooking, load repair, or rendering cannot advance it. The smoke still sets exactly `rockedT = 18000`; its normal transition still creates exactly `crashT = 8000`.
7. `emperor_gate` points to THE THRONE DITCH. The throne challenge starts the Curb Emperor fight. Defeating him sets `complete`, records the finite quest and achievement, saves first, then shows the `ONE CRACKLORD` receipt. Returning from the receipt resumes the same world and all existing progress.
8. Completion is not a good ending and does not pacify the map. The throne is a lawn chair bolted to a curb. Enemy domains retain bounded daily holdouts, and one elite CURB PRETENDER appears per in-world day after completion. Defeating that day's pretender grants a small bounded cash/cred reward once and increments `P.lifetime.pretendersDefeated`. Reload, death, arrest, rest, bus travel, and repeated contact cannot duplicate it.

Campaign quest receipts are `HOSTILE CORRESPONDENCE`, `BLUE WEATHER`, `CART APPEAL`, `COPPER MASS`, `ROYAL STATIC`, and `ONE CRACKLORD`. They are terse ledgers, not narration screens. Only the final ruler uses the existing ending-receipt surface.

### Expanded kingdom map

`WORLD` grows from `5800x3800` to `8600x5600`. Every v18 coordinate remains unchanged. The east and south road network extends existing service roads rather than creating isolated rectangles. Camera, collision, projectiles, cop-edge spawning, edge arrows, minimap scaling, route distance, bus travel, and all clamps remain parameterized by `WORLD.w` / `WORLD.h`.

| Zone id | Display name | Bounds | Rival field | Identity |
|---------|--------------|--------|-------------|----------|
| `blue_tarp_court` | BLUE TARP COURT | `(5920,260,1160,1060)` | `blue_tarp` | overlapping blue roof plastic, bucket borders, pallet permits, plastic-chair court |
| `cart_cavalry_keep` | CART CAVALRY KEEP | `(7340,1460,1040,980)` | `cart_cavalry` | nested shopping-cart barricades, return slips, appliance ramparts, one working caster |
| `copper_choir_yard` | COPPER CHOIR YARD | `(5920,2760,1220,1120)` | `copper_choir` | wire clotheslines, hubcap chapel, stripped cable aisles, choir pews with no service |
| `throne_ditch` | THE THRONE DITCH | `(7020,4200,1320,1120)` | `throne` | drainage cut, ceremonial curbs, tire audience, bolted lawn-chair throne |

All four zones keep `faction:'neutral'` and declare a separate `clan` field. Clan hostility must never be fed into `P.faction`, office claim reputation gates, `currentZoneFaction()`, or the v13 territory ticker.

The map adds authored terrain regions, continuous road segments, crosswalks, worn paths, facades, barriers, lights, banners, and local clutter. New solid buildings preserve clear south-door gaps and do not intersect roads:

- BLUE TARP COURT: `TARP PERMITS (6000,300,340,180)` and `BLUE COURT (6660,300,340,180)`.
- CART CAVALRY KEEP: `CART IMPOUND (7420,1540,320,220)` and `THE KEEP (7960,1540,320,220)`.
- COPPER CHOIR YARD: `COPPER RETURNS (6000,2840,380,240)` and `CHOIR OFFICE (6620,2840,420,240)`.
- THE THRONE DITCH: `DITCH RECORDS (7280,4280,360,220)` and `THE THRONE (7840,4280,420,220)`.

Each district has an authored, collision-free bus arrival, challenge banner, three field marks, guard posts, route landmark, and first-entry receipt. Bus destinations stay hidden until the corresponding persisted `*Entered` flag is true. A district's route stop stays hidden until its ruler-clear flag is durable, so ordinary clipboards never send an unprepared player through a live court. New route ids are appended, never inserted or renamed: `tarp_docket`, `cart_barrier`, `choir_register`, and `ditch_gauge`. Existing serialized route ids remain valid.

### Rival clans and combat

| Clan | Common guard | Ruler | Boss contract | One-time reward |
|------|--------------|-------|---------------|-----------------|
| BLUE TARP COURT | TARP KNIGHT | DARRYL UNDER BLUE | charger, `180 HP`, no more than two adds | `$24 + 18 cred` |
| CART CAVALRY KEEP | CART LANCER | GENERAL RECEIPT | grabber, `200 HP`, no more than two adds | `$30 + 22 cred` |
| COPPER CHOIR YARD | WIRE DEACON | BISHOP WIRE | ranged, `210 HP`, no more than two adds | `$36 + 26 cred` |
| THE THRONE DITCH | conquered-family holdouts | THE CURB EMPEROR | elite charger, `280 HP`, at most two reinforcements | `$60 + 40 cred` and final receipt |

1. Rival guards are ordinary bounded NPC records with a `kingdomClan` tag and authored `zoneOnly` rectangle. Before conquest, at most five ambient guards occupy a clan district. After conquest, at most two daily holdouts remain. Guards do not reproduce per frame and the total authored NPC population remains compatible with the 60+ NPC frame budget.
2. A guard is hostile inside its own clan domain, but cannot follow indefinitely across the whole 8600x5600 world. Bus arrivals and building doors sit outside immediate contact range. Old factions, cops, vendors, office clerks, and quest NPCs do not inherit clan hostility.
3. Campaign bosses use the existing hostile archetype/update/damage pipeline and may be damaged by every normal player weapon. No boss is essential, invulnerable, or gated by a special damage type. Every fight must remain defeatable by a competent player in under 90 seconds; if testing exceeds that, reduce HP/add pressure rather than changing player combat.
4. `state.kingdomBattle` and the spawned ruler/adds are transient. Death, arrest, ending receipt, or malformed reload calls one abort path: remove campaign boss/add NPCs and their transient projectiles, clear the boss reference, preserve completed marks, and demote `*_boss` to its matching `*_marks` with `marks = 7`; `emperor_boss` demotes to `emperor_gate`. No loss path grants or removes a durable defeat.
5. After `complete`, one daily CURB PRETENDER uses a conquered guard sprite, `100 HP`, and a bounded `$10 + 2 cred` reward. `pretenderDefeatedDay === state.day` is the durable paid witness. Ambient holdouts grant no cash, cred, item, combo, or drop reward; this prevents boss abort, dawn, or reload recovery from becoming a guard-respawn mint.
6. Clan combat never grants rocks, copper, supplies, faction reputation, district claims, office jobs, passive cash, or a new currency. It never makes smoking possible outside the Block.

### Guidance, interaction, and gameflow

The forced intro remains first. After intro, active acquisition/claim/order work may finish normally; once the war is unlocked, its current authored step becomes the long-form primary objective. The Q ledger adds `CURB WAR` after `THE OFFICE`, showing the current absurd instruction, three clan seals, mark progress, next ruler, and lifetime pretenders. It never reveals unseen mark copy or a future boss before that clan becomes active.

World interaction priority is:

1. office/hideout/Old School and authored clan doors;
2. an active kingdom mark, challenge banner, or throne;
3. an active office survey/install/inspection target;
4. active block-route stamp;
5. closest NPC;
6. heist, props, and local zone verbs.

`resolveActionHint()` mirrors that exact ordering. Rendering is read-only. Campaign targets do not advance through proximity, attacking a banner, entering a bus, opening Q, or touching an inactive future anchor. During a live boss stage, office purchase/claim/order acceptance, bus travel, route stamping, incidents, and unrelated dialogue are unavailable until the boss is defeated or the fight aborts. Ordinary campaign travel does not suppress those systems.

The title receipt extends the visible long-term plan after the opening verbs: `file three routes -> acquire the office -> install four claims -> settle Tony -> answer the radio -> dispute every throne`. It does not explain boss solutions or freeze discovery.

### Save and normalization

1. `state.kingdom`, the four entry flags, campaign quest state, completion achievement, and `P.lifetime.pretendersDefeated` serialize in the existing `rockbottom_save_v8` payload. No new storage key is introduced.
2. Normalization whitelists stages, boss ids, defeat ids, mark bits, day stamps, and finite nonnegative counters. Duplicate/unknown defeat ids are discarded. Active boss stages always normalize to their restartable pre-fight stage because spawned combatants are not durable.
3. Durable witnesses reconcile forward but never fabricate rewards: three ruler defeats imply the matching later stage; `complete`/the final quest/achievement implies all prior defeat ids; a later stage implies prerequisite marks. Office ownership plus four real claim ids may restore `summons`, but an aggregate claim counter alone may not invent claims.
4. Old v18 saves receive `locked`, then unlock naturally if their normalized office, four claim ids, and completed `fallen_king` quest satisfy the contract. Fresh saves begin locked. Load does not spawn, pay, kill, mark, anoint, or show an ending receipt.
5. The single-file gzip ceiling rises from 185KB to 225KB for four authored districts, seven character families, campaign copy, and deterministic map detail. Save size remains below 50KB and initial paint remains below 250ms on the target desktop profile.
6. Durable ruler witnesses reconcile forward without paying: each clan quest/clear flag may restore its matching defeat, Royal Static may restore `emperor_gate`, and the final quest/achievement/clear flag may restore `complete`. The normalized defeat prefix advances to the first unpaid stage, so a partial save cannot replay a recorded ruler and soft-lock on the duplicate-reward guard.
7. Existing non-transient `npcsKilled` ids are cached during load and applied only after `spawnNpcs()`. Tony's death and `fallen_king` receipt are saved before the ending delay; reload cannot respawn a paid Tony or pay the corner reward twice.

### Sprite and rendering contract

Seven complete three-frame 16x16 palette-indexed families are added: `blue_tarp_guard`, `receipt_guard`, `wire_guard`, `darryl_under_blue`, `general_receipt`, `bishop_wire`, and `curb_emperor`. Their silhouettes are visibly different at 32x32 display: tarp hood/shield, cart-fork lance, wire stole/coil, blue canopy crown, receipt sash, antenna mitre, and stacked-curb crown. Bosses fill more of the logical grid but remain 32x32; runtime `scale` is not a substitute for authored pixels.

All 21 character frames are rasterized once during initialization and drawn only with cached `drawImage`. Four one-frame clan/banner environment sprites follow the same cache pattern. The character/player cache ceiling rises from 360 to 400; projected v19 use is 373. The auxiliary environment/landmark/light cache ceiling rises from 48 to 64 with an actual v19 use of 53 after the additional facades and glow color. No operating-system emoji, external bitmap, runtime per-pixel character drawing, CDN, font, module, or framework is introduced.

### v19 invariants

1. The Block remains the only smoke/cook location. A real rock remains mandatory for campaign coronation.
2. Rocked-up remains exactly 18 seconds and always becomes exactly 8 seconds of crash. The anoint hook does not change status, audio, consumption, or soap behavior.
3. v19 deliberately supersedes the v18 “no fourth ending” invariant only for the requested `ONE CRACKLORD` comedy receipt. The receipt returns to endless play and is neither redemption nor world completion.
4. Every v18 coordinate, serialized route/claim id, office cost/reward, faction rule, Tony phase, heist gate, and old ending remains valid.
5. One campaign stage, one campaign boss, one office claim, one office order, one block route, and one primary marker maximum. Systems may coexist durably, but only the highest-priority active field target is advertised/interactable.
6. Clan conquest owns no person and produces no passive income, allegiance rewrite, faction reputation, product distribution, or new currency.
7. Death/arrest/reload can restart a live battle but cannot erase marks/defeats or duplicate a boss/pretender reward.
8. All new roads, doors, mark anchors, guard posts, route points, bus arrivals, banners, and arenas have collision-clear approach space. No safe arrival starts inside a solid or immediate boss/add contact radius.
9. Character cache remains `<=400`, auxiliary cache remains `<=64`, and no character sprite is painted per pixel at runtime.
10. Four clan districts plus at least 60 active NPCs, weather, particles, office signs, guidance, and minimap remain below 16ms/frame on the deterministic target harness.
11. Darryl, General Receipt, Bishop Wire, and the Curb Emperor are each independently defeatable in under 90 seconds by a competent player.

### v19 required test matrix

| Property | Required result |
|----------|-----------------|
| Old/fresh/malformed save | fresh stays locked; eligible v18 save reaches summons once; malformed stages/marks/defeats/days normalize; durable defeat/quest/clear witnesses reconcile forward; active boss reload is restartable and unpaid; killed Tony is applied after NPC spawn |
| Unlock/radio | Tony + office + three claims does not unlock; Tony + fourth real claim does; without Tony the older corner objective remains; missing radio points to install; answering once enters tarp marks |
| Three mark phases | any order, each one-shot, exact `0..7` mask, no reward, inactive/future marks ignore E, reload preserves mask |
| Boss transaction | one ruler/add set, damageable by normal weapons, reward once, next stage saved, repeat interaction/reload cannot duplicate |
| Loss recovery | death/arrest removes transient boss/adds/projectiles, retains the completed three-mark mask (`marks=7`), restores challenge, no reward or permanent soft lock |
| Anoint status loop | soap never advances; real rock deducts once, enters emperor gate, sets exactly 18,000ms high, then exactly 8,000ms crash with one crash cue |
| Final receipt | Emperor death saves complete before receipt; return resumes same world; old endings and routes remain available |
| Endless pretender | one eligible elite per day after complete; one daily reward; reload cannot repeat; next dawn creates a new eligible pretender |
| Guidance parity | objective, marker, minimap, E/B hint, and interaction agree for radio, nine marks, four banners, and anoint |
| Expanded traversal | four zones, all roads/doors/anchors/route points/bus arrivals/arenas reachable and outside solids; no old coordinate moved |
| Clan isolation | `faction:'neutral'`; no office claim gate, territory heat, rep, cop, vendor, or ordinary NPC receives clan state |
| Controls/status | v16 WASD chords and partial release still pass; blur/modal clears; high/crash exact |
| Boss duration | all four rulers defeated under 90 seconds in the combat harness |
| Sprite/cache | all 21 family frames + four banners nonblank and cached; character <=400; aux <=64; visual signatures differ |
| Performance/standalone | 60+ NPC update/draw <16ms; one dependency-free HTML; async `window.storage` only; gzip <=225KB; save <50KB |

---

## THE OFFICE + BLOCK AUTHORITY + FAR-EAST EXPANSION (v18)

v18 gives the neighborhood a medium- and long-term spine without replacing its core joke. The player may acquire a condemned former tax office, improve it into a shelter/headquarters, file absurd ownership claims on public districts, and run bounded work orders forever. The "empire" owns bent signs and paper records, never people. Tony, the milk crate, the score -> smoke -> 18s high -> 8s crash loop, faction reputation, combat damage, and every existing ending remain canonical and mechanically unchanged.

### Gameflow contract

1. The forced three-step intro remains the only opening tutorial. Block routes 1-3 then teach traversal through play.
2. Filing route 3 exposes `THE OFFICE` quest and points to THE LEASING GUY in the new district called THE LOT.
3. Replacing the office lock costs `$40 + 1 pure copper`. The purchase is permanent, survives death/arrest/endings, and does not create rent or a new currency.
4. The office is a modal interior following the existing hideout pattern. Its exterior remains in the walkable world and visibly accumulates every permanent upgrade and claim milestone.
5. A desk unlocks authored district claims. The first claimable district is the neutral DRAINAGE CANAL, so the ownership loop is demonstrable without reputation grinding. Faction districts require the matching faction to be LIKED (`rep >= +10`) when a claim is selected.
6. Once one district is claimed and a radio is installed, the office issues bounded work orders. These require travel to an owned sign and a return to the office. They never pay while unattended.
7. The endless floor is two parallel loops: v17 block routes remain continuously available, while office orders are accepted explicitly. Active office campaign/order steps temporarily own the one BAD IDEA target; inactive paperwork never hides the block route.
8. Finite campaign milestones exist at office acquisition and 1/4/8/11 claims. Claim milestones grant visual progression, quest receipts, and one-time achievements only; the claim's listed `+2 cred` is its complete currency reward. Completing all claims changes the office exterior and ledger, but does not create a fourth ending. Routes and work orders continue forever.

### Expanded world

`WORLD` grows from `4400x3400` to `5800x3800`. Every v17 coordinate remains unchanged. Camera, cop spawning, player/projectile clamps, minimap scaling, bus travel, objective arrows, and collision continue to consume `WORLD.w` / `WORLD.h` rather than hardcoded bounds.

The authored world, office state machine, and ledger raise the single-file ceiling from 170KB to 185KB gzip. This is a deliberate v18 budget revision, not permission for external assets or runtime dependencies; initial paint remains under 200ms and save size remains under 50KB.

| Zone id | Display name | Bounds | Faction | Identity |
|---------|--------------|--------|---------|----------|
| `warehouse_row` | WAREHOUSE ROW | `(4400,180,1100,760)` | scrap | patched loading concrete, oil, two warehouse units, numbered aprons |
| `canal` | THE DRAINAGE CANAL | `(4300,1540,1350,680)` | neutral | walkable dry channel, wet seams, gauge marks, municipal water with no water |
| `the_lot` | THE LOT | `(4300,2700,1250,850)` | neutral | dead parking grid, abandoned furniture, THE OFFICE |

The old network is extended by an eastbound warehouse cut, a continuous park/skid road, a continuous south service road, a far-east spine, and the office drive. The three districts receive first-entry receipts and become bus destinations only after their corresponding persisted `*Entered` flag is true. Every bus destination has an authored collision-free arrival point rather than using a zone center that may lie inside a solid building. The destination ledger paginates at six locations so every destination and every navigation/leave action remains reachable from the `1-9` dialogue controls.

New route landmarks are appended, never inserted or renamed: `warehouse_manifest`, `canal_gauge`, and `lot_meter`. Each carries an `unlockFlag`; `rollBlockRoute()` excludes a far landmark until its district has been entered. Existing serialized route IDs remain valid.

### Headquarters contract

The solid office shell is at `(4700,2920,440,300)` with a centered south door at `(4908,3204,24,32)`. It is not marked `locked`; the first `locked` building remains the abandoned heist building. THE LEASING GUY at THE LOT is the only acquisition transaction.

Permanent upgrades use existing cash/copper only:

| Upgrade | Cost | Mechanical use | Exterior evidence |
|---------|------|----------------|-------------------|
| cot | `$30` | rest; sleep to dawn with the canonical `+15 shakes` consequence | mattress corner / chair |
| locker | `$45 + 1 copper` | opens the existing shared `state.hideoutStash` | chained metal cabinet |
| desk | `$60 + 2 copper` | selects, files, and tracks district claims | desk glow / paperwork window |
| generator | `$75 + 2 copper` | improves office rest and lights the door at night | patched cable and light |
| radio | `$90 + 2 copper` | unlocks bounded office work orders | roof antenna |
| route board | `$65 + 1 copper` | one unpaid block-route reroll per day | clipboard board by door |

All purchase checks and deductions are atomic. Reopening an owned upgrade cannot charge again. Every office dialogue has a leave/back route and exposes why a disabled action is disabled.

### District claim contract

Claims are a second system named `districtClaims`; they must not reuse or mutate the existing ephemeral `state.territory*` ticker fields. `ZONES[].faction`, `P.faction`, `currentZone()`, `currentZoneFaction()`, and `updateTerritory()` retain their v13 meanings.

Eleven claimable districts:

- STREET: `alley`, `projects`, `skidrow`
- SCRAP: `scrap`, `underpass`, `oldschool`, `warehouse_row`
- SPIRITUAL: `market`, `park`, `trainyard`
- NEUTRAL ONBOARDING: `canal`

`block`, `dealer`, `church`, `abandoned`, `pawn`, `laundromat`, `busstop`, and `the_lot` are structurally protected from claims. The crate, Tony, church, heist, office, and primary vendors are never reclassified as owned territory.

Only one claim contract may exist. Its persisted state is `{ id, stage }`, with whitelisted ids and stages:

1. `survey`: selected at the office desk. Travel to the district's authored survey point and interact.
2. `file`: return to the office. Filing costs `cash = 20 + 5 * claimedCount` and exactly `1 copper`.
3. `install`: travel to a second, clear public coordinate and install a bent sign.
4. completion: set `districtClaims[id] = true`, clear the active contract, grant exactly `+2 cred`, advance non-currency campaign milestones, save once.

The reputation gate is checked only when selecting. A later reputation loss cannot corrupt or cancel an active filing. Canceling an unfiled or filed contract grants no resource and never duplicates a payment. Claim coordinates never depend on a living NPC, boss, weather, day/night, loot roll, weapon, or external service.

Claimed signs are cached 16x16 logical sprites drawn with `drawImage`. Owned zone outlines also appear on the minimap. A claim does not suppress hated-faction heat, generate rocks, unlock smoking elsewhere, grant passive regeneration, or change local NPC allegiance. The form has no social authority.

### Endless office work orders

Work orders require the radio and at least one claimed district. They are accepted explicitly at the office, one at a time, and persist as `{ id, stage:'inspect'|'file', serial }`.

1. `inspect`: visit one selected owned claim sign and interact.
2. `file`: return to the office and close the ledger.
3. Filing pays `cash = min(12, 5 + claimedCount)`; every fifth lifetime office order also grants `+1 cred`.
4. Daily capacity is `min(3, 1 + floor(claimedCount / 4))`. Both acceptance and final filing recheck the cap; malformed same-day paperwork beyond capacity remains unpaid until dawn. The day stamp and count persist, reset through the same dawn path as existing daily counters, and cannot be reset by reload, rest, or reopening the menu.
5. There is no passive, offline, catch-up, or missed-day income. An inspected but unfiled job pays nothing until the player physically returns to THE OFFICE.
6. Orders never pay rocks, copper, supplies, equipment, faction reputation, combat power, or achievements more than once. Routes continue underneath and resume their saved cursor when no office step is active.

### New people and activities

- **THE LEASING GUY** stands in THE LOT with a key ring and clipboard. He explains the three-route requirement in-world and performs the one atomic office sale. He has no other economy.
- **GUTTER GREG** stands in the canal with a rubber duck and an inventory theory. Counting canal inventory is available once per day, grants `+1 scrap` reputation, and no cash/item. It is a small authored reason to revisit the new district, not a farm.

Both are palette-indexed 16x16 logical characters, prerendered to three cached frames, and registered in VIBE before ship. They are fixed essential clerical fixtures: a player swing may produce a paper-denial reaction, but cannot damage, kill, knock back, or permanently remove either transaction hook. Neither can call a remote service; the Possum remains the only AI-call NPC.

### Guidance, interaction, and save contract

1. Interaction priority becomes: office/hideout/Old School doors -> active office survey/install/order sign -> block-route stamp -> closest NPC -> heist -> props -> zone verbs.
2. `resolveActionHint()` mirrors that ordering. No prompt may advertise a route stamp through an active office target or a door through a nearby NPC.
3. `currentOfficeObjective()` runs after the forced intro and before the eternal route. It returns a target only for office acquisition, the first-claim onboarding, or an explicitly active claim/order step.
4. The Q ledger adds THE OFFICE between BLOCK ROUTE and TODAY'S HUSTLES: ownership, upgrades, claim count, active stage, order capacity, and claimed/unclaimed district list. It does not reveal hidden claim copy before selection.
5. `state.office`, `state.districtClaims`, `P.lifetime.officeJobs`, and `P.lifetime.territoriesClaimed` are serialized. Load normalization uses whitelisted ids/stages, finite nonnegative counters, deep upgrade defaults, and null-prototype lookup tables.
6. Old saves with 3+ routes unlock the office quest on load/start. Old saves missing v18 state receive a locked empty office, no claims, and no duplicate route reward. On partial saves, any durable purchase witness (`office.owned`, completed `office_space`, `squatters_rights`, claims, office upgrades/jobs, or downstream v18 lifetime/milestone records) reconciles the purchase records upward so the lock can never be sold twice. Durable claim/milestone evidence restores the permanent desk prerequisite; durable work paperwork/completions restore the permanent radio prerequisite. Claim ids are never fabricated from an aggregate count. Surviving claim ids likewise reconcile milestone quest availability and achievements idempotently.
7. The save key remains `rockbottom_save_v8`. Save size remains below 50KB. No `localStorage`, `sessionStorage`, network dependency, CDN, asset file, font, module, or build step is introduced.

### v18 invariants

1. The Block remains the only place to smoke/cook; the office has no cook action.
2. Rocked-up remains exactly 18 seconds and always becomes exactly 8 seconds of crash.
3. Tony, the abandoned heist, every old building/zone/NPC coordinate, and all existing quest/ending gates remain reachable and mechanically unchanged.
4. District ownership never alters faction reputation or faction-territory behavior. A claimed hated zone may still call the cops.
5. Death, arrest, dawn, ending receipts, and reload preserve the office, upgrades, claims, and active paperwork without paying them.
6. One primary objective, one active claim, and one active office order maximum. Claim and order jobs cannot be active simultaneously.
7. No passive income, no ownership decay, no real-world trafficking simulation, no people-as-property, and no new currency.
8. All far-east roads, survey points, sign points, NPCs, route stops, and the office door have clear approach space outside solid collision.
9. Character/player `SPRITE_CACHE` remains within its 360-canvas budget; separately bounded environment/landmark/light caches remain within 48 additional canvases. Repeated claim signs are prerendered once and new named sprites have complete keys.
10. Tony remains defeatable by a competent player in under 90 seconds; v18 does not touch boss HP/damage/phase code.

### v18 required test matrix

| Property | Required result |
|----------|-----------------|
| Old/fresh save | Fresh office locked; old route-3+ save receives quest exactly once; malformed office data normalizes safely |
| Acquisition | Route 3 unlocks Leasing Guy target; `$40 + 1 copper` deducts once; reload remains owned |
| Upgrade atomicity | Insufficient resources never partially deduct; owned upgrade cannot repurchase; exterior updates immediately |
| Claim state machine | survey -> office file -> install; fee once; +2 cred once; cancellation/reload cannot duplicate |
| Reputation gate | canal selectable at neutral; faction districts disabled below +10; active job survives later rep loss |
| Work order | accepted at office -> owned sign -> office; payout only at final file; daily cap survives reload |
| Objective priority | active office target hides route marker without advancing route; route target resumes afterward |
| Interaction parity | door/claim/order/route/NPC prompts and actual E/B action agree at every authored coordinate |
| Map traversal | all three new zones, office door, new NPCs, route points, and claim points are reachable around solids |
| Bus/discovery | far districts absent before visit, present after visit, six-per-page navigation remains keyboard-accessible, authored arrivals are outside solids, self-target/combat/day gates unchanged |
| Endless property | after 11 claims, office orders continue across days and block routes continue without cap |
| Economy | no passive payout; order cash <= $12; no order/claim grants rocks, supplies, copper, or equipment |
| Controls/status | v16 WASD chords/partial release pass; high remains 18s and crash remains 8s |
| Performance | expanded map + 60 NPCs + weather + incident + signs stays below 16ms/frame |
| Standalone | one dependency-free HTML opens directly and persists only through async `window.storage` |

---

## CURSED STICKERS + BAD-IDEA CLARITY + ENDLESS BLOCK ROUTES (v17)

v17 is a presentation and replayability fork of v16. It makes the player visually accumulate the junk they equip, exposes the neighborhood's existing depth without a blocking tutorial, and adds one repeatable travel loop that can continue forever. It does not add a city, currency, named NPC, real-world drug detail, redemption path, or new ending. Movement math, combat damage, the boss phase machine, and the 18s high -> 8s crash loop remain mechanically unchanged.

### Diegetic clarity contract

1. The title screen carries one compact receipt: desktop/mobile controls plus the opening plan (find $10 -> bother Tony -> smoke at the crate). It is a control ledger, not a modal tutorial, and never blocks play after start.
2. During play, a single `BAD IDEA` strip shows the current primary objective, distance, and coarse direction. Priority is intro step -> active block-route stop -> first active quest. Only one target is marked at once.
3. The primary target gets a world marker when visible and an edge arrow when off-screen. The minimap receives the same one target. Markers are guidance only: no teleport, collision, reward, or state mutation occurs in rendering.
4. A contextual action hint appears only when an interaction is currently in range. Desktop uses `E`; touch uses the existing `B` action. The hint scanner is read-only, rate-limited, and follows interaction priority closely enough that it never advertises a lower-priority object through a nearby NPC.
5. The Q panel starts with `WHAT TO PRESS`, the current bad idea, the active block route, and a compact activity ledger. The ledger surfaces existing verbs and districts without revealing hidden quest outcomes or un-met NPC identity.
6. Mobile action buttons carry verb labels (`HIT`, `BOTHER`, `SQUINT`) in addition to A/B/F. Keyboard, touch, and analog behavior remain the v16 input contract.
7. No tutorial freezes the world, requires acknowledgement, grades the player, or reappears after the intro. Discovery remains gameplay.

### Endless block-route contract

`ROUTE_STOPS` is a fixed authored list of reachable public landmarks. Each stop has `{id, x, y, zone, task, stamp}`. Copy uses the mundane -> specific -> escalation -> flat pattern. Stops never sit inside solid collision or require a vendor, boss, rank, item, night, weather, faction, or surviving NPC.

1. The route unlocks when `state.flags.introDone` becomes true. Existing saves with no route receive one on start. The intro remains focused and route-free.
2. One route contains three distinct stops. `rollBlockRoute()` avoids duplicating a stop inside a route and avoids immediately repeating the just-completed final stop when alternatives exist.
3. Pressing interact within 58px of the active stop stamps it. Only the next unfinished stop can advance. Dialogue, panel, minigame, boss, stun, death, and hidden-tab states cannot stamp a stop.
4. The third stamp completes the route immediately, increments `P.lifetime.routesCompleted`, pays a deliberately small ledger amount, then posts the next route. Formula: `cash = min(24, 6 + floor(routesCompleted / 5) * 2)` and `cred = min(4, 1 + floor(routesCompleted / 20))`.
5. Route progress is independent of day rollover and daily hustle caps. Death and arrest preserve the route and lifetime count. A reload resumes the same stop; it never pays twice.
6. Every 5 completed routes changes the player's cached route-patch layer, capped at the fourth visible patch tier. Milestone achievements exist at 5, 20, and 50 routes; the counter itself has no maximum.
7. The route grants no faction reputation, rocks, supplies, copper, equipment, combat advantage, or new currency. It is a small cash/cred floor and a reason to cross the entire authored map.
8. Boss/bus ending receipts never erase a route or lifetime grind. Their return action saves and resumes the same neighborhood; only an explicit fresh start from the normal opening title resets progression.

### Cursed-sticker sprite contract

The visual language is deterministic pixel pictograms: chunky, front-readable silhouettes with the instant readability of emoji, but no operating-system emoji glyphs. Every character image remains a 16x16 logical palette grid rasterized once to a cached 32x32 canvas.

1. The player has genuinely distinct up/down/side silhouettes, an asymmetric four-beat shuffle, and authored attack poses. Left/right may share a cached side pose through mirrored `drawImage`; runtime pixel painting is prohibited.
2. Equipped hats, coats, shoes, tools, and the active weapon use cached transparent palette-grid layers anchored to the same feet as the base player. Every equipment and weapon id must create a visible pixel delta at 2x display scale.
3. Route patches are cached player layers selected from lifetime route count. Rocked-up can palette-swap the base while gear remains readable. Crash may lower the draw anchor but cannot alter hitboxes or timing.
4. The old filled attack rectangle is replaced by a cached directional smear plus the cached weapon/attack pose. Hitbox, reach, damage, cooldown, and knockback remain unchanged.
5. Named NPC identity comes from silhouette-scale geometry and oversized signature objects, not only palette. Existing Tony coat loss, sleeping Dave, Fallen O'Malley, dog, pigeon, and possum state art remains canonical. Combat-only pose art may read existing state fields but cannot write AI state.
6. `resolveNpcPose(n, visualNow)` is pure visual selection. Missing sprite keys retain a release fallback but are a QA failure.
7. Sprite layers are bottom-center anchored. No gear, stride, attack, or pose frame may move the logical feet by more than one pixel from idle.

### Save and compatibility

- `SAVE_KEY` remains `rockbottom_save_v8`.
- `P.lifetime.routesCompleted` defaults to `0` on old saves.
- `state.blockRoute` is serialized as a small `{stops, cursor, serial, lastStopId}` record. Missing or malformed records are regenerated after intro completion.
- Objective/hint cache, marker pulse, sprite pose, and route-toast timers are ephemeral and never serialized.
- No `localStorage`, `sessionStorage`, external asset, font, script, module, or network dependency is introduced.

### Standalone free-release contract

1. A host-provided async `window.storage` remains authoritative. When an ordinary browser provides none, v17 installs an async `window.storage` adapter backed by IndexedDB; only browsers without usable IndexedDB fall back to volatile memory. Game code still talks exclusively to `window.storage`, and `localStorage` / `sessionStorage` remain prohibited.
2. The Possum always has an authored local prophecy ready. A host-provided completion service may replace that line only if it responds promptly and safely; missing, slow, or failed host completion never produces a dead interaction and never becomes required content.
3. Mobile rendering preserves the canvas's 4:3 aspect ratio. Portrait may use the surrounding black area for touch controls, but logical 32x32 sprites cannot be stretched into non-square display pixels.
4. Touch start/load and the Q control ledger name their actual touch verbs. The game remains fully playable without a keyboard, external service, account, download, or build step.

### v17 required test matrix

| Property | Required result |
|----------|-----------------|
| New save | Receipt is readable; objective points to the $10 intro path; no block route before intro completes |
| Intro handoff | Smoking at the crate completes intro and posts route 1 without skipping the high/crash loop |
| Route progression | Only ordered, in-range E/B stamps advance; three stamps pay once and generate the next route |
| Endless property | 100 simulated route completions produce 100 new valid three-stop routes and no capped state |
| Save/load | Mid-route cursor and lifetime count resume; completed payout cannot duplicate |
| Death/day/modal | Route survives death/day; modal or boss state cannot stamp |
| Guidance | Strip, world marker, edge arrow, and minimap agree on one target; no render function mutates route |
| Sprite cache | All referenced keys are 32x32/nonblank; every equipment/weapon changes visible pixels; cache count <= 360 |
| Sprite anchoring | Player base/gear/attack feet remain within one logical pixel; no runtime canvas creation after init |
| Performance | 60+ visible NPCs + weather + incident + player layers remain under 16ms/frame |
| Controls/status | v16 multi-key matrix passes; rocked-up is exactly 18s followed by exactly 8s crash |
| Boss | Tony remains defeatable by a competent player in under 90 seconds |
| Standalone | Hosted browser without injected storage persists through IndexedDB; missing completion service still yields local Possum content |
| Mobile pixels | Portrait and landscape preserve square logical pixels; touch receipt and Q ledger match the visible controls |

---

## CONTROL INPUT RELIABILITY (v16)

v16 is a focused input bug-fix fork of v15. It changes no movement speed, collision, status multiplier, animation timing, combat input, mobile joystick curve, NPC system, incident, economy, or save data.

### Keyboard state contract

1. Physical keyboard movement is event-latched: a movement key enters `state.keys` on `keydown` and remains there until its matching `keyup`, a modal explicitly clears input, the window blurs, or the document becomes hidden.
2. Held keys must never expire because time elapsed. Browser/OS key-repeat cadence is not evidence that another physically held key was released.
3. `W+D`, `W+A`, `S+D`, `S+A`, and their arrow-key equivalents produce normalized diagonal movement (`0.7071` per axis) for the entire hold, not only the first 700ms.
4. Releasing either key from a diagonal continues movement on the still-held axis without requiring a new keydown.
5. Pressing/releasing an unrelated pointer or action control must not clear physical keyboard movement.
6. Lost-focus safety remains explicit: `blur` and hidden-document events clear all latched keys. Modal open/close paths retain their existing key clearing, and movement auto-repeat may not resurrect a key that a safety/modal path cleared.
7. The mobile analog stick remains independent and continues to override keyboard vector input only while `state.stickMag > 0`.
8. Sprint (`Shift`) follows the same event-latched rule and may be combined with either cardinal or diagonal movement.

### Removed failure mechanisms

- The 700ms `state.keyTimes` stale-key pruner is prohibited. It cannot distinguish a missed `keyup` from a normally held key whose operating system is repeating a different key.
- The global `pointerup` keyboard purge is prohibited. Pointer release belongs to the mobile control that captured that pointer; it is not a keyboard-release signal.
- `keyup`, `blur`, `visibilitychange`, modal clearing, mobile `pointerup`/`pointercancel`/`lostpointercapture`, and analog-stick reset remain the authoritative release paths.

### Invariants and regressions

1. **Speed unchanged.** Cardinal speed remains `P.speed`; diagonal magnitude remains equal to cardinal magnitude after normalization.
2. **Collision unchanged.** Movement continues through the existing independent X/Y building collision checks and WORLD clamps.
3. **Status loop unchanged.** Rocked-up remains 1.8× for 18s; crash remains 0.5× for 8s; slow remains 0.5×.
4. **Control recovery.** After blur/visibility clearing, movement requires a fresh non-repeat keydown and cannot remain stuck.
5. **Modal recovery.** Dialogue/inventory/quest transitions cannot leave a movement key latched or revive one only because the browser emits repeat.
6. **Architecture/save unchanged.** v16 is still one dependency-free HTML file and `SAVE_KEY` remains `rockbottom_save_v8`.

### Required test matrix

| Input sequence | Required result |
|----------------|-----------------|
| Hold `W` for 2s | Continuous north movement for the full hold |
| Hold `W`, then add `D`, hold both for 2s | Continuous northeast movement; equal absolute X/Y displacement away from collision |
| Release `D`, keep `W` held | Immediate continuous north movement |
| Hold `Shift+W+D` | Continuous normalized diagonal at sprint multiplier |
| Hold `W`, click/release canvas | `W` remains latched and movement continues |
| Hold `W`, dispatch blur/hidden equivalent | Keys clear; movement stops; repeat alone cannot restart it |
| Open/close dialogue while moving | Keys clear; fresh press moves normally; no ghost/stuck key |
| Analog stick diagonal then release/cancel | Stick vector returns to zero; keyboard remains independent |
| Full smoke loop | 18s rocked-up transitions to exactly 8s crash |

---

## LIVING NEIGHBORHOOD + SPRITE IDENTITIES (v15)

v15 turns ambient absurdity into short physical scenes and makes the existing pixel roster readable by silhouette instead of palette alone. It does not add a new district, named NPC, currency, quest chain, ending, or required interaction. The neighborhood remains the same place; it is now visibly occupied by its own administrative problems.

### Neighborhood incident engine

`INCIDENT_DEFS` owns six bounded, world-space micro-scenes. An active incident is ephemeral scene state, never a canonical NPC or prop. Incident actors have no HP, faction, dialogue priority, death record, or save identity.

| Incident | Eligible space | Four-beat contract | Player consequence |
|----------|----------------|--------------------|--------------------|
| `runaway_mattress` | any nearby road | mattress enters traffic -> establishes right-of-way -> crosses the road under its own authority -> leaves | one small bump at most; never during combat |
| `possum_inventory` | Marketplace | inventory begins -> possum arrives with forklift/clipboard -> counts the player twice -> closes inventory | visual/counting scene only; canonical Possum is never moved |
| `laundromat_walkout` | Laundromat | dryer thumps -> rolls out with one wet sock -> takes the bus lane -> stops at a red light | visual scene only; Barb and the laundromat transaction remain available |
| `yuri_receipt` | Scrap Yard | Yuri weighs one hubcap -> receipt grows -> wind assigns Brutus/leash-post item status -> Yuri starts over | crossing the ribbon gives a temporary paper-stuck cosmetic only |
| `park_dry_committee` | Park, clear daytime | sprinkler starts -> six pigeons form a dry committee -> nozzle tracks the player -> meeting adjourns | temporary wet-drip cosmetic only; no slow or stat change |
| `ticketed_luggage` | Train Yard | suitcase arrives -> Conductor punches its ticket -> pigeons queue behind it -> suitcase leaves on foot | suitcase waits/detours; the train never arrives |

Incident copy follows VIBE order: mundane setup, specific absurdity, escalation, flat cleanup. Every line is lowercase except proper display labels. No incident uses a real place, victim, real-world drug instruction, tutorial text, or fourth-wall language.

### Scheduler and lifecycle

1. `MAX_ACTIVE_INCIDENTS = 1`. Incident actors are capped at 12 and incident particles at 30.
2. The first incident becomes due 35-55 seconds after the intro. Later incidents become due after 70-110 seconds. At most three start per in-game day.
3. A due incident may start only while `state.mode === 'playing'`, `state.flags.introDone`, day-7 silence is inactive, `state.bossActive` is false, no hostile is aggro within 320px, and no scripted day visitor/bus resolution is active.
4. The scheduler and scene phases use `dt`; no incident uses `setTimeout`. Modal screens naturally pause incidents because `updateWorld` is not advancing.
5. Selection prefers an eligible incident for the player's current canonical zone. `runaway_mattress` is the global fallback and anchors to the nearest authored road segment. Gameplay geography continues to come from `ZONES`/`ROAD_SEGMENTS`, never `terrainAt`.
6. Toast-only `WORLD_EVENTS` do not fire while an incident is active or during day-7 silence. They retain their existing effects and cadence otherwise.
7. `state.flags.incidentDay`, `incidentMask`, `incidentsToday`, and `lastIncidentId` persist. The bit is set when a scene starts, preventing reload repetition that day. Active actors/timers are deliberately not persisted and cleanly disappear on reload.
8. Every cleanup path restores any temporarily hidden canonical actor. v15 incident implementations should prefer not hiding one in the first place.
9. Incidents immediately clean up if a boss activates, scripted bus resolution begins, or their required canonical NPC becomes hostile/dead. They never delay Tony, Old School Brutus, Fallen O'Malley, arrest, smoke access, or heist input.

### Sprite identity pass

1. All character art remains palette-indexed 16x16 logical art, prerendered once to cached 32x32 canvases and drawn with `drawImage`.
2. `makeNPC` receives a signature id. Signature overlays author posture and props inside the same three cached frames: long arms, stacked coats, crossword, bottle, cap/ticket, backpack, cane, badge, open mouth, and other canonical identifiers. Hitboxes and foot anchors do not change.
3. The generic `tall` and `thin` families retain their silhouette in walk frames; walk animation may not reset them to the default wide legs.
4. Chatty Dave receives a cached horizontal sleep pose used only while `n.asleep`; he returns to his standing sprite when awake or hostile.
5. Fallen O'Malley receives a real cached fallen palette/silhouette. Tony's cached silhouette visibly loses one coat at each boss phase. These are render-state changes only; HP, speed, damage, phase thresholds, and boss timing are unchanged.
6. Raster outlines/highlights align to the 2x logical pixel grid. Pure-white palette entries are replaced with dirty cream. No half-logical-pixel gloss may blur the sprites.
7. Long names wrap onto at most two backed lines. Peaceful NPC nameplates fade outside 260px; vendors, unmet NPC markers, hostile/aggro names, HP bars, and combat telegraphs remain readable.
8. Sprite cache budget rises to 190 canvases to permit the six incident props and boss-state variants. At 32x32 this remains bounded and is verified at init; there is no runtime cache growth.

### Invariants (v15)

1. **Comedy core unchanged.** Smoking a rock remains required; 18 seconds rocked-up always transitions to 8 seconds crash.
2. **Bosses remain bounded.** Incidents cannot start during bosses, and Tony remains defeatable in under 90 seconds.
3. **Canonical identity unchanged.** No incident actor enters `npcs`, `PROPS`, `npcsKilled`, faction logic, vendor scans, or interaction priority.
4. **Possum authority unchanged.** Only the canonical Possum may call the live AI path. Incident possums are visual workers with no interaction.
5. **The train never arrives.** Ticketed luggage may depart. The Conductor remains at his post.
6. **Save compatibility.** `SAVE_KEY` stays `rockbottom_save_v8`; old v14 saves load with lazy incident defaults.
7. **Performance.** Night + rain + 60 visible NPCs + 12 incident actors remains below 16ms/frame. Drawing is viewport-culled; actor arrays are bounded.
8. **Architecture.** v15 remains a dependency-free single HTML file openable by double-click.
9. **Storage.** Persistence uses async `window.storage` calls inside try/catch only.

### Edge cases

| Case | Behavior |
|------|----------|
| Save/reload during a scene | Active visuals end; its daily bit remains set; the next unseen incident schedules normally |
| Player opens dialogue mid-scene | World update pauses; rendering remains stable; scene resumes after dialogue |
| Boss/hostile combat begins | Active scene cleans up on the next world tick; no reward or penalty is synthesized |
| Required NPC is dead/hostile | That district incident is ineligible; global mattress may still be selected outside combat |
| Player leaves an incident district | Scene completes its current route and exits; it does not teleport the player or canonical actors |
| Night + fog + crash | Incident art may dim; player/status/hostile telegraphs remain the top readable layers |

---

## VISUAL WORLD COHESION (v14)

v14 is a geography and rendering pass over the existing 4400×3400 world. It does **not** add a city, move a district, add an NPC, or change a transaction. The purpose is to make the sixteen existing zones read as parts of one neighborhood instead of isolated rectangles on a repeated asphalt field.

### Problem statement

The v13 zone rectangles cover roughly 3.44M of the world's 14.96M square units (about 23%). The remaining ~77% falls through to `TILE_PALETTES.default`. Expanded districts are separated by 380–1420px corridors that currently contain the same checker tile, so distance reads as empty canvas rather than geography.

### Static world-fabric layers

All v14 world-fabric data is deterministic, code-owned, and save-free.

| Layer | Contract | Collision | Draw order |
|-------|----------|-----------|------------|
| `TERRAIN_REGIONS` | Large rects assign an outside-zone ground material (`vacant`, `service`, `drainage`, `rail_approach`, `dead_grass`). Existing zone palettes always win. | none | ground tile selection |
| `ROAD_SEGMENTS` | Axis-aligned streets/service lanes connect the old core to Park/Skid Row/Old School and Projects to Train Yard. Each draws asphalt, curb, sidewalk, patch seams, drains, and worn lane marks. | none | above ground, below zones |
| `LANDMARK_FACADES` | Set-back facade/warehouse/rowhouse silhouettes break the empty world into readable blocks without becoming new gameplay walls. They sit outside canonical routes; kinds control wall treatment. | none | architecture-backdrop pass |
| `WORLD_DECOR` | Non-interactive utility poles, bus shelter, signs, barriers, storm drains, newspaper boxes, guardrail, rail signals, clotheslines, and district clutter. | none | low/tall decor passes |
| `WORLD_LIGHTS` | Static light sources for storefronts, bus shelter, underpass, park fountain, school door, and rail signals. | none | night mask + additive glow |

`terrainAt(wx, wy)` is visual-only. It first asks `zoneAt`; if a canonical zone matches, that zone id is returned. Only unzoned space may inherit a `TERRAIN_REGIONS` palette.

### District kits

Each district must read at viewport scale through at least four identifiers: ground material, boundary treatment, landmark silhouette, and one restrained moving detail.

| District | Required visual identity |
|----------|--------------------------|
| THE BLOCK | cracked residential asphalt, stoops/rowhouse frontage, utility wires, faded half-court marking around the crate |
| SCRAP YARD | dirt, fence, car/scrap silhouettes, crane hook or hanging chain |
| PAWN / DEALER / LAUNDROMAT | distinct storefront frontage, awning/sign light, curb furniture, unique window treatment |
| BUS STOP | its own tile palette, shelter + bench + route placard, worn curb lettering |
| MARKETPLACE | brick field, canopy rhythm, paper/produce debris, warm stall light |
| BACK ALLEY / SKID ROW | wet/dark ground, compressed wall/shack silhouettes, overhead wire/tarp rhythm, puddle or drip movement |
| PROJECTS | rowhouse massing, stoops, clotheslines, court markings; it may no longer be an empty labeled strip |
| HIGHWAY UNDERPASS | concrete/oil tile remains visible beneath the bridge slab; sodium pools and column shadows |
| PARK | grass edge, branching worn paths, tree-canopy border, animated fountain |
| TRAIN YARD | continuous rails (not one disconnected pair per tile), freight/loading silhouettes, signals, ballast approach |
| OLD SCHOOL | school mass, fenced yard, court markings, broken-window rhythm, isolated door light |

The existing VIBE rule remains intact: zone areas retain a dashed boundary and approximately 25% tinted fill. v14 may weather and soften the treatment, but may not replace it with clean HUD chrome.

### Rendering and performance contract

1. Static objects are camera-culled before detailed drawing. Buildings outside the viewport do not emit brick/corrugation loops.
2. `drawLighting` reuses one 800×600 offscreen canvas; it never allocates a canvas per frame.
3. New repeated sprite-like decor is prerendered at 16×16 logical size, cached, and drawn with `drawImage`. Large one-off roads/buildings remain canvas geometry.
4. Tall decor may receive a foreground cap/canopy pass so the player can walk visually behind it. Low decor stays below actors. Gameplay hitboxes do not change for decorative objects.
5. Roads, landmark shells, and major rail lines appear on the minimap so the expanded world reads as a connected neighborhood.
6. Richer rendering must remain under 16ms/frame with 60+ NPCs. Added arrays are static; no per-frame procedural allocation or full-world sorting.

### Save and compatibility

- `WORLD`, `ZONES`, `BUILDINGS`, NPC coordinates, door coordinates, bus targets, faction tags, and interaction ranges remain unchanged.
- v14 visual arrays are constants and are not serialized. No save-key or save-shape change.
- Existing `state.graffiti` and `state.posters` layouts remain loadable. New landmark buildings may receive fresh procedural wall marks only on a fresh layout; an old saved layout is not rebuilt.
- The desktop fallback for a missing `window.storage` is memory-only. `localStorage` and `sessionStorage` are prohibited even as a shim.

### Invariants (v14)

1. **Spawn → Tony remains clear.** A player-sized route at least 96px wide connects THE BLOCK to DEALER'S CORNER without entering a hostile zone.
2. **Every canonical interaction remains reachable.** Tony, Yuri, Pete, Barb, Pinky, the crate, church door, hideout doors, heist edge, park benches, Train Hopper/Conductor, Old School door, and bus destination centers retain clear approach space.
3. **Boss arenas remain unchanged.** v14 adds no new collision geometry in Tony's corner, the Old School schoolyard, or any existing boss spawn point.
4. **Existing zone mechanics are untouched.** Zone ids/rects/factions, territory overlap, zone verbs, entry flags, and bus travel continue to read `ZONES`, not visual regions.
5. **Interaction priority remains:** doors > closest NPC > heist > interactive props > zone verbs.
6. **Status readability remains.** Night/weather lighting cannot obscure rocked-up gold, crash purple, damage flash, hostile names, or charge telegraphs.
7. **Pixel discipline remains.** No external raster assets, CDN content, runtime per-pixel sprite painting, or mixed asset-pack aesthetic.
8. **Single-file architecture remains.** v14 opens by double-click with no build step or dependency.
9. **Storage remains `window.storage` only.** All calls async and wrapped; missing API falls back to the current page's memory only.
10. **Core timing remains untouched.** Rocked-up remains 18s and always transitions to the 8s crash.

### Edge cases

| Case | Behavior |
|------|----------|
| Old save contains graffiti/posters only for v13 buildings | Load them unchanged; missing marks on v14 landmarks are acceptable |
| Player walks at world edge | Terrain/roads clip to WORLD bounds; camera and player clamps remain parameterized |
| Road overlaps a canonical zone edge | Zone fill/border and district detail render above the road; mechanics still use the zone rect |
| Night with many lights visible | Cull lights outside radius; reuse the persistent mask canvas |
| Fog + night + crash | Fog and night retain contrast; crash tint remains the top status color layer |

---

## FACTION TERRITORY (v13 wave 8b)

Each zone carries a `faction: 'street' | 'scrap' | 'spiritual' | 'neutral'` tag. The territory ticker (`updateTerritory`, fires every 2s while `state.mode === 'playing'`) reads the player's current zone faction × rep tier and applies the matching effect.

### Zone faction map (v13 wave 8b)

| Zone | Faction | Notes |
|------|---------|-------|
| THE BLOCK | street | Tony's corner. |
| DEALER'S CORNER | street | Stripe's stoop. |
| BACK ALLEY | street | Alley crackheads. |
| LAUNDROMAT | street | Barb. |
| BUS STOP | street | Pinky. |
| SKID ROW | street | Wave 8a. |
| THE PROJECTS | street | Larry + Stripe. |
| SCRAP YARD | scrap | Yuri. |
| PAWN SHOP | scrap | Pete. |
| HIGHWAY UNDERPASS | scrap | Big Guy + Mathematician. |
| OLD SCHOOL | scrap | Wave 8a. |
| MARKETPLACE | spiritual | Mom's neighborhood. |
| CHURCH | spiritual | O'Malley. |
| THE PARK | spiritual | Philosopher + Pigeon King. |
| TRAIN YARD | spiritual | Train Hopper + Conductor. |
| ABANDONED BUILDING | neutral | Locked. |

### Zone-overlap rule

`currentZone()` returns the matching zone with the highest `|tier|`, so LOVED street beats neutral spiritual; HATED scrap beats neutral street. Same-tier ties → first match in ZONES order.

### Territory tier behavior

| Tier | Cash mult | Brain regen | Greetings | Hated heat | Loved ambient |
|------|-----------|-------------|-----------|------------|---------------|
| hated | 1.0× | none | none | +1/2s (cap 30 → wanted +1) | n/a |
| neutral | 1.0× | none | none | none | n/a |
| liked | 1.2× | none | once per NPC per zone-entry, ≤80px | none | n/a |
| loved | 1.4× | +1 brain / 10s | per NPC, 10s cooldown, ≤80px | none | once per faction per day |

The cash multiplier only affects dynamic spawns inside the territory (OS Brutus death drop; park-night swing-set pile). Static cash piles seeded at save start are unaffected.

Hated ambient lines fire roughly every 30s while heat is accumulating, per-faction via `TERRITORY_HATED_LINES`. Loved ambient lines (`TERRITORY_LOVED_LINES`) fire once per zone-entry-per-day-per-faction via `state.flags.lovedAmbient_<faction>_day` stamps.

The ticker pauses whenever `state.mode !== 'playing'` (dialogue, cookmini, heist, boss, hideout, ending). `state.territoryHeat` resets on zone exit, neutral zone, and mode change.

### Visual district identity

- **Graffiti**: `buildGraffiti` reads the building's zone-faction and pulls from `SCRAP_GRAFFITI_LINES` (15), `SPIRITUAL_GRAFFITI_LINES` (15), or `GRAFFITI_LINES` (street default, 36). Colors via `GRAFFITI_PALETTES` (street muted red/pink; scrap rust; spiritual faded blue/white).
- **Posters**: new persisted-in-save `state.posters` array. `buildPosters()` walks faction-tagged buildings, places 1-3 posters per zone (16×24 wall rects). `POSTER_LINES` provides 3 lines per faction. `drawPosters()` renders between graffiti and props.
- **Edge glow**: `state.borderGlowT` (ms, decays in updateWorld), `state.borderGlowRect`, `state.borderGlowColor`. Arms when player crosses into a new zone. 600ms fade. `drawBorderGlow()` traces the destination zone bounds in a faction tint (street red, scrap rust, spiritual gold).

### Bus pass

| Field | Value |
|-------|-------|
| Inventory id | `bus_pass` |
| Name | `a bus pass` |
| Stack | 1 (single, `giveBusPass` early-returns if already held) |
| Acquisition (Pinky) | $20 from `pinkyDialogue`, sold only when `!hasBusPass()` |
| Acquisition (Mom) | Free at dawn if `P.faction.spiritual >= 10`, once per day via `momBusPassDay` |
| Use trigger | `pinkyDialogue` "use the bus pass" option (when `hasBusPass()`) |
| Destinations | every zone in `BUS_ZONE_TARGETS` the player has visited (`*Entered` flags from waves 6/8a) |
| Cooldown | `state.flags.busPassUsedDay === state.day` (one ride per dawn) |
| Combat gate | `combatActive()` returns true if `P.wanted > 0` OR any hostile/aggro non-pet NPC within 220px |
| Self-target gate | option disabled if `currentZone().id === target.zoneId` |
| Teleport | 0.5s black flash → set P.x/P.y to zone center (clamped) → snap camera → reset territory state → 0.5s flash → toast |
| Save | `bus_pass` lives in `P.inventory`; cooldown + mom-day stamps live in `state.flags` |

### Cart speed cap

`if (P.cartMounted) baseSpeed = Math.min(baseSpeed * 1.7, baseSpeed + 1.5)` in `applyEquipStats`. The biggu cart trade routes through `applyEquipStats()` instead of setting `P.speed` directly, so the cap applies consistently.

### New state fields

| Field | Type | Persisted | Purpose |
|-------|------|-----------|---------|
| `state.territoryT` | number (ms) | no | ticker accumulator |
| `state.territoryHeat` | number | no | hated-district heat |
| `state.territoryZoneId` | string | no | last zone for transition detect |
| `state.territoryCashMult` | number | no | dynamic-drop multiplier |
| `state.territoryBrainTicks` | number | no | loved brain regen ticks |
| `state.territoryGreeted` | Set | no | liked-greeting per-NPC tracker |
| `state.territoryGreetLast` | object | no | loved-greeting per-NPC timestamp |
| `state.lastZoneId` | string | no | edge-glow transition trigger |
| `state.borderGlowT` | number (ms) | no | edge-glow timer |
| `state.borderGlowRect` | object | no | edge-glow zone bounds |
| `state.borderGlowColor` | string | no | edge-glow tint |
| `state.posters` | array | YES | poster layout |
| `state.flags.lovedAmbient_<f>_day` | number | YES | per-faction loved ambient day-stamp |
| `state.flags.busPassUsedDay` | number | YES | one-ride-per-day cooldown |
| `state.flags.momBusPassDay` | number | YES | mom-drop day-stamp |

All ephemeral fields default to 0/null/undefined on a fresh frame; the ticker handles missing values via `(x||0)`.

### Invariants (wave 8b)

1. **Bus pass is single-stack.** `giveBusPass` checks `hasBusPass()` first.
2. **Bus pass cannot escape combat.** `combatActive()` gate must fire BEFORE consume.
3. **Bus pass cannot route to unvisited zones.** Filtered by `BUS_ZONE_TARGETS.flag` against `state.flags.*Entered`.
4. **Cooldown survives reload.** `busPassUsedDay` is in `state.flags` and gets saved.
5. **Territory ticker pauses in any non-playing mode.** Early-return on `state.mode !== 'playing'`.
6. **Territory heat resets on zone exit.** Player cannot accumulate hated heat across zones.
7. **Cart speed = min(base × 1.7, base + 1.5).** Both multiplicative scaling AND an absolute clamp.
8. **Save format unchanged.** SAVE_KEY = `rockbottom_save_v8`. All new state fields default-defined in both load Object.assign paths and the startGame fresh-init.

---

## INTERACT PRIORITY (v13 wave 8.6)

`tryInteract` dispatches the E key by a fixed priority chain. Higher slots short-circuit lower slots.

| Slot | Trigger | Range | Notes |
|------|---------|-------|-------|
| 1 | hideout doors | 40px | owned hideouts only |
| 2 | old school door | 44px | gates by `P.rank >= 3` |
| 3 | **NPC scan (closest)** | 60px | wave 8.6 lift — was at slot 10 |
| 4 | abandoned heist trigger | building rect ±20 | proximity, not point |
| 5 | park bench sit | 50px | toggle |
| 6 | kickable trash can | 50px | RNG outcome |
| 7 | pay phone (ringing) | 38px | only when state.phonePropRingT > 0 |
| 8 | cart mount/dismount | 36px | |
| 9 | dumpster dive | 44px | |
| 10 | smoke at block (zone verb) | inZone('block') | |
| 11 | panhandle at market (zone verb) | inZone('market') | |

**Invariants (wave 8.6 interact priority):**
1. **NPCs win over interactive props.** A vendor within 60px always consumes E before any adjacent trash/phone/bench/cart/dumpster can fire. Verified by sweep audit (Pete vs pawn trashcan, Tony vs dealer trashcan, Philosopher vs park benches, Train Hopper vs freight cars).
2. **Doors win over NPCs.** Hideout door and Old School door come before the NPC scan because they're destinations, not roadside fixtures.
3. **Heist trigger is between NPCs and props.** Per brief: NPCs > heist > interactive props > generic prop.

---

## OLD SCHOOL GATING (v13 wave 8.6)

The Old School building (TINY pre-wave-8.6, free copper print) is now properly walled.

**Entry gate (rank).** `tryEnterOldSchool` at line ~4049: if `P.rank < 3`, opens a one-option refusal `dialogue` with the canonical line `"the door is chained.\nthe chain is rusted.\nyou don't have what it takes to break it yet.\n(rank 3 required.)"` and returns true (consumes the E so it doesn't fall through to props). When `P.rank >= 3`, normal interior modal opens.

**First-rip forced spawn (`openOldSchoolInterior` rip handler).**
- `firstEverRip = !state.flags.osBrutusKilled && !brutusAlive`
- If true: 0 copper, force `spawnOldSchoolBrutus()`, toast `"the copper is here. so is OLD SCHOOL BRUTUS.\nhe was sleeping in the gym. he is no longer sleeping.\nno copper this time."`, close interior.
- If false: existing path. +2 copper, 40% probabilistic spawn (guarded by `!brutusAlive`).
- Flag flip: `state.flags.osBrutusKilled = true` inside the OS Brutus death drop block (line ~4872, right before the school_s_out toast). Coupling to the actual reward path ensures the flag can't desync from "Brutus has been killed once for real."

**Save backward-compat.** `state.flags.osBrutusKilled` is undefined on any save that didn't write it. `!undefined === true` → first rip post-update forces spawn even for players who'd already ripped pre-fix. One-time tax, acceptable. Lazy-init safety nets (`if (!state.flags) state.flags = {};` at lines 4705 + 8764) cover the very-old-save case where flags itself is missing.

**Invariants (wave 8.6 Old School):**
1. **Rank 3 required to enter the Old School.** No bypass. The door itself refuses.
2. **First copper rip always spawns OS Brutus.** No 0-cost copper before the boss is dealt with.
3. **OS Brutus drop table unchanged.** $80 + 5 copper + propane torch + 50 cred + STREET +2 + SCHOOL_S_OUT. The boss fight is the unlock for repeatable copper farming.
4. **`state.flags.osBrutusKilled` is gated on death-drop, not despawn.** Walking away from a probabilistic spawn doesn't count.

---

## WORLD EXPANSION (v13 wave 8a)

**WORLD bounds:** `{ w: 4400, h: 3400 }` (up from 2200×1900). All existing zones keep their original x/y/w/h; the world grew around them. Every world-coord clamp (camera, projectile cull, cop spawn ring, player clamp, day-event NPC clamps, day-30 bus rehydrate) reads `WORLD.w` / `WORLD.h` exclusively. Minimap scale `(120/WORLD.w, 96/WORLD.h)` parameterized.

### Zone table (v13 wave 8a additions)

| Zone id | Name | Rect | Faction lean | Notes |
|---------|------|------|--------------|-------|
| trainyard | TRAIN YARD | 260,2700,1100,560 | spiritual | Conductor + Train Hopper. Tracks, freight cars, weeds, chalk lore. |
| park | THE PARK | 2400,900,620,500 | neutral / street-at-night | Pigeon King + Philosopher. Fountain, benches, swings, trees. |
| skidrow | SKID ROW | 2480,1520,900,720 | street, contested | Dense shacks + 3 hostiles + 5 hidden cash piles + Price Guy. |
| oldschool | OLD SCHOOL | 3400,280,760,640 | scrap | OLDSCHOOL building, modal interior, OS Brutus boss, mural + schoolyard. |

### New NPCs (v13 wave 8a)

| id | name | location | type | faction | grants | gate |
|----|------|----------|------|---------|--------|------|
| train_hopper | THE TRAIN HOPPER | trainyard `(820,2940)` | lore | spiritual | TRAIN_HOPPED on first daytime talk | hidden at night (`daytimeOnly:true` + dialogue night-guard) |
| philosopher | PARK BENCH PHILOSOPHER | park `(2680,1080)` | lore + rep | spiritual | +1 spiritual / day on engage | day-stamp via `state.counters.philosopherRepDay` |
| os_brutus | OLD SCHOOL BRUTUS | spawned by interior copper-rip | boss | street | $80 + 5 copper + propane torch (no-dupe) + 50 cred + street +2 + SCHOOL_S_OUT | hp 250, dmg 35, archetype 'charger' (windup→lunge→grab pattern) |
| price_guy | THE PRICE GUY | skidrow `(2940,1860)` | random encounter | neutral | RNG one-shot | spawns every `state.day % 3 === 0`, gated by `state.flags.priceGuyDay` |

### Relocated NPCs (v13 wave 8a)

- **Conductor**: `(240,1780)` THE PROJECTS → `(680,2960)` TRAIN YARD. Dialogue + 3-copper-for-$90 trade unchanged. Stripe's package-handoff lines updated to reference "the train yard." WORLD_EVENTS school_bus line updated.
- **Pigeon King**: `(1000,1000)` → `(2700,1180)` THE PARK (near fountain). Crown side-quest + secrets dialogue unchanged.

### Park bench sit mechanic

- E within 50px of any `park_bench` PROP toggles `state.sittingOnBench`.
- While sitting: +1 brain per 2 seconds (drift via `state.benchSitGainT`). Shakes UNCHANGED (calm, not a withdrawal cure).
- 60 seconds continuous → BENCH_PRESS achievement.
- After 60s, every 30s a random passerby toast fires (5 lines: philosopher said you'd be here / a pigeon walks past / a jogger passing on phone / the fountain coughs / you have been here a while).
- State is ephemeral (NOT saved). Standing or reloading resets the timer.

### Old School interior (modal dialogue)

- E within 44px of door at `(3760,700)` opens `openOldSchoolInterior()`.
- Two branches: "rip copper from the walls" (+2 copper, +1 to copper counter, 40% chance to spawn OS Brutus in the schoolyard outside) OR "leave."
- Spawn check: only if no live os_brutus exists. Spawn closes the modal automatically so the fight happens in open space.

### Price Guy RNG outcome table

| Roll band | Outcome | Notes |
|-----------|---------|-------|
| 0.00 — 0.20 | + knife (P.weapon = 'knife') | the handle is warm |
| 0.20 — 0.35 | + $200 | net positive on paper |
| 0.35 — 0.45 (only if !hasPropane) | + propane torch | smells like a parking lot. falls through to next band if already owned. |
| 0.45 — 0.70 | + 1 rock | "you suspect it is real" |
| 0.70 — 1.00 | nothing | "he handed you nothing. he nods. you nod." |

All branches set `state.flags.priceGuyVisits++`, unlock THE_PRICE_PAID, and trigger wanderOff. Walking away (not paying) has no penalty.

### Phone-feed first-entry hooks

| Zone | Handle | Line |
|------|--------|------|
| trainyard | @blocklog | trains stopped running here. they still come through. |
| park | @hardcandy | the pigeons remember faces. the philosopher remembers names. |
| skidrow | @crackheadcent | skid row knows you didn't ask first. |
| oldschool | @blocklog | the old school still has copper in the walls. the school still has brutus in the gym. |

Each gated by `state.flags.{trainYardEntered, parkEntered, skidRowEntered, oldSchoolEntered}` (defaults to false on fresh save, true on legacy save load).

### New achievements (v13 wave 8a)

- `school_s_out` — defeat the Old School Brutus.
- `bench_press` — sit on a park bench for 60 continuous seconds.
- `the_price_paid` — pay the Price Guy (any outcome).
- `train_hopped` — talk to the Train Hopper.

### New TILE_PALETTES branches

- `trainyard` — gravel ballast flecks + horizontal steel-rail bands per tile.
- `park` — green grass base + tuft sprites + occasional dandelion heads.
- `skidrow` — darker cracked-concrete (reuses concrete flag) + cigarette-butt and wrapper flecks.
- `oldschool` — playground tan + chalk smudges + weed:true tufts.

### Invariants (v13 wave 8a additions)

1. **WORLD parameterization** — every world-coord clamp reads `WORLD.w` / `WORLD.h`. No hardcoded world-dimension constants.
2. **Existing zones unmoved** — every zone defined before v13 wave 8a keeps its original x/y/w/h. New zones live only in the expanded area (no overlap with original zones).
3. **Conductor location** — referenced via `npcs.find(n=>n.id==='conductor')` everywhere. Stripe's package delivery uses proximity check (60px radius); the math is location-independent.
4. **Train Hopper night gate** — hidden at night (`daytimeOnly:true`) AND interactable-but-rejecting at night via in-dialogue check.
5. **Philosopher rep cap** — +1 spiritual once per day, gated by `state.counters.philosopherRepDay === state.day`.
6. **Bench sit ephemeral** — not in save schema. Resets each session.
7. **Price Guy cadence** — `state.day % 3 === 0` gate, one spawn per such day via `state.flags.priceGuyDay`. Old instances spliced on new-day spawn.
8. **Park night cash** — at most one roll per night via `state.flags.parkNightCashDay`.
9. **OS Brutus uniqueness** — at most one os_brutus alive at a time. Re-entering interior with him alive does not respawn.
10. **OS Brutus drops** — propane torch is no-dupe gated (skipped if `hasPropane()` is true).

---



---

## WHAT

Top-down action RPG built as a single HTML file. Palette-indexed pixel player and complete cached pixel NPC roster. Sixteen-zone, 4400×3400 walkable neighborhood with camera following the player on an 800×600 viewport. Real-time fist combat, multiple patterned bosses, resource management (rocks, cash, shakes, cred, brain, wanted), rank progression, factions, day/night/weather, equipment, quests, achievements, and persistent save via `window.storage`.

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

- **Visual:** 800×600 canvas, cached pixel player/NPC walk sprites, district terrain/roads/facades, day/night/weather, hit particles, lighting, and screen treatments for damage/high/crash
- **Audio:** Synth chiptune SFX via Web Audio API, no sampled audio
- **Persistence:** `window.storage.set('rockbottom_save_v8', JSON)` on rank up, transactions, heist completion, death, plus auto-save every 45 seconds

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
| HIGHWAY UNDERPASS | north-center (1020-1400, 240-460) | tent camp, cart trade, cook oracle | Big Guy, Mathematician |
| DEALER'S CORNER | middle-right (1450-1770, 780-1020) | buy rocks $10 | Tre Bag Tony |
| ABANDONED BUILDING | top-right (1500-1980, 100-460) | copper heist (LOCKED until rank 4) | — |
| BUS STOP | center-south (1240-1460, 1080-1260) | Pinky's supply lane, bus pass | Pinky Polenta |
| THE LAUNDROMAT | center-right (1480-1800, 1080-1280) | clean supply vendor | Baggie Barb |
| MARKETPLACE | bottom-center (700-1400, 1380-1620) | panhandling, shoplifting, mom | Whole Foods Mom, Chatty Dave |
| BACK ALLEY | bottom-left (100-600, 1280-1660) | hostile crackheads, dumpster dive | Lurch, Sherri, Paulie |
| CHURCH | bottom-right (1600-1980, 1300-1620) | tic-tac methadone, donations, steal plate | Father O'Malley |
| THE PROJECTS | bottom-far-left (100-700, 1700-1880) | street faction, Stripe's alternate lane | Loud Larry, Stripe |
| TRAIN YARD | far south-west (260-1360, 2700-3260) | copper trade, train lore | Conductor, Train Hopper |
| THE PARK | east-center (2400-3020, 900-1400) | benches, secrets, spiritual rep | Pigeon King, Philosopher |
| SKID ROW | east-south (2480-3380, 1520-2240) | contested hostile district, Price Guy | Price Guy, three hostiles |
| OLD SCHOOL | far north-east (3400-4160, 280-920) | rank-3 copper interior, comedy boss | Old School Brutus |

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

## FACTIONS (v13 wave 7)

Three reputation tracks, separate from `P.cred`. Each is a signed integer stored on `P.faction = { street: 0, scrap: 0, spiritual: 0 }`. Persisted in save (no SAVE_KEY bump — missing fields default to 0).

### TIER HELPER

`factionTier(value)` returns one of: `'hated' | 'neutral' | 'liked' | 'loved'`.

| value range | tier |
|---|---|
| ≤ −10 | hated |
| −9 to +9 | neutral |
| +10 to +24 | liked |
| ≥ +25 | loved |

### MEMBER AFFILIATIONS (who counts as which faction)

- **STREET**: Tre Bag Tony, Stripe, every Brutus (Younger, Older, Jr. boss), Lurch, Sherri, Paulie, Dave, Pinky Polenta, Cousin Brendan (family-soft on street rep — killing him deducts street rep)
- **SCRAP**: Yuri, Pete, Big Guy, the chained dog (wave 6), the Mathematician (he respects numbers)
- **SPIRITUAL**: Mom / kombucha lady, Father O'Malley (pre-fall only — fallen variant becomes street-coded), the Possum, the Conductor, O'Malley's tic-tac son, the karaoke mike (if surfaced)

### REP DELTA CONTRACT

Wired into every existing transaction. Soap rocks deliberately do not count for spiritual — the universe doesn't validate self-deception.

| Action | Street | Scrap | Spiritual |
|---|---|---|---|
| Buy rock from Tony | +1 | 0 | 0 |
| Fence rock with Stripe (each) | +1 | 0 | −1 (cap −3 / day) |
| Sell copper to Yuri | 0 | +1 | 0 |
| Sell copper to Pete | 0 | +1 | 0 |
| Donate to priest ($5) | 0 | 0 | +2 |
| Steal priest's collection plate | +1 | 0 | −3 |
| Ask mom for $10 / $20 | 0 | 0 | −1 |
| Compliment mom's kombucha | 0 | 0 | +1 |
| Smoke a rock at the crate | +1 | 0 | −1 |
| Smoke a SOAP rock | 0 | 0 | 0 |
| Kill Brutus / Lurch / Sherri / Paulie | +1 | 0 | 0 |
| Kill a cop / Cousin Brendan | −3 | 0 | +1 |
| Kill Father O'Malley (fallen) | +2 | 0 | 0 |
| Feed chained dog | 0 | +2 | 0 |
| Free chained dog (lockpick) | 0 | +3 | −1 |
| Buy from Pinky Polenta | +1 | 0 | −1 |
| Mathematician hidden tip received | 0 | +1 | 0 |
| Return crossword to Barb | +1 | 0 | 0 |
| Sleep at scrap hideout | 0 | +1 | 0 |
| Sleep at mom's hideout | 0 | 0 | +1 |
| Day 14 inheritance pickup | +2 | 0 | −1 |

`adjustFaction(faction, delta)` is the single mutator. It clamps to `[-50, +50]`, detects tier transitions, and broadcasts the matching phone-feed line + toast on crossings.

### TIER EFFECTS (wired into existing code paths)

**STREET LIKED** — Tony's rock base price drops $9 → $8 (still multiplicative with charisma).
**STREET LOVED** — Brutus Older variant no longer aggros unprovoked; propane torch drop chance +50%.
**STREET HATED** — Pinky Polenta refuses to sell ("you smell like a snitch.").
**SCRAP LIKED** — Yuri buys copper at $28 (+$3); Pete buys at $17 (+$2).
**SCRAP LOVED** — Pete will lend $50 once per day (`scrap_loan_day` flag); implicit cred-deduction over 3 days.
**SCRAP HATED** — Pete refuses to buy ("pete is full.").
**SPIRITUAL LIKED** — Mom calls randomly with proud-line: +5 brain on receive.
**SPIRITUAL LOVED** — Father O'Malley refuses to fall (fallen-priest trigger requires `P.faction.spiritual < +10`); Possum prophecy fires more often.
**SPIRITUAL HATED** — Mom's ambient phone line stops firing.

### TIER TRANSITION BROADCASTS

Tier crossings emit one phone-feed line and one short toast. Lines are flat, third-person, lowercase.

- STREET → LIKED: `"@hardcandy: someone has been seen with tony. someone keeps being seen."`
- STREET → LOVED: `"@hardcandy: tony said your name three times today."`
- STREET → HATED: `"@blocklog: word travels. word does not return."`
- SCRAP → LIKED: `"@blocklog: yuri counted three times today. counted right twice."`
- SCRAP → LOVED: `"@blocklog: pete wrote down a number. pete does not write down numbers."`
- SCRAP → HATED: `"@hardcandy: the yard gate is half closed. half closed is closed."`
- SPIRITUAL → LIKED: `"@blocklog: mom called. mom does not always call."`
- SPIRITUAL → LOVED: `"@hardcandy: the possum sat upright today. the possum is not always upright."`
- SPIRITUAL → HATED: `"@blocklog: mom hasn't called. her phone is on silent."`

### Q-KEY PANEL

New `FACTIONS` block at the top of the Q-panel. Three rows: `STREET`, `SCRAP`, `SPIRITUAL`. Each row shows the tier label and a thin bar that maps `[-50, +50]` onto fill. Color: muted green for liked/loved, muted red for hated, off-white for neutral. Below the panel: short legend `"hated · neutral · liked · loved"`.

## DAY EVENTS (v13 wave 7)

Tracked by `state.day`. Fire AT MOST ONCE per save. Each guarded by a flag on `state.flags`.

### Day 3 — "the visit"

Trigger: `state.day === 3 && !state.flags.day3Fired`, on morning tick.
- Spawn one passive aggressive-archetype NPC at player's current zone center, NOT aggro'd, with a `?` floater.
- Approach (within 32px) triggers single dialogue: `"someone you don't know.\nthey say:\n\n'i heard about you.'\n\nthat's all they say."`
- After dialogue closes, NPC wanders off and despawns on zone change.
- Feed: `"@crackheadcent: someone was on the block today. someone was watching."`
- Sets `state.flags.day3Fired = true`.

### Day 7 — "the silence"

Trigger: `state.day === 7 && !state.flags.day7Fired`, on morning tick.
- For 4 in-game minutes: news ticker suppressed, phone feed suppressed, ambient phone calls suppressed.
- Toast at trigger: `"the radio is off.\nthe phones are off.\nthe city is listening to something."`
- After 4 min, systems resume normally. Sets `state.flags.day7Fired = true` at trigger.

### Day 14 — "the inheritance"

Trigger: `state.day === 14 && !state.flags.day14Fired`, on morning tick.
- Spawn a $500 cash pile at random spot in player's current zone with a larger `?` floater.
- On collect: `"+ $500\n\nyou don't recognize the bill.\nyou don't recognize the wallet.\nyou recognize the smell."`
- Apply: +$500, +2 street, −1 spiritual.
- Feed on collect: `"@hardcandy: someone came into money. someone always does."`
- Sets `state.flags.day14Fired = true` at trigger; `state.flags.day14Collected = true` on pickup.

### Day 30 — "the bus"

Trigger: `state.day === 30 && !state.flags.day30Fired`, on morning tick.
- Spawn `bus_driver` NPC at the bus stop.
- Within 30px triggers dialogue: `"the bus is here.\nit hasn't been here in a while.\nthe driver looks at you.\n\nare you getting on?"`
- **yes** → THE_BUS ending screen modeled on existing `endingScreen`: `"you got on the bus.\nthe bus left.\nyou survived rock bottom.\nthe bus has a destination. it has not told you."` Plus stats summary and `THE_BUS` achievement. v17 saves the receipt and returns to the same neighborhood without erasing progression.
- **no** → bus despawns permanently this save. Toast: `"the bus leaves.\nit doesn't come back.\nthat was your chance."`
- Sets `state.flags.day30Fired = true` at trigger.

This is a third ending alongside the Tony and Stripe co-op endings.

## HIDEOUTS (v13 wave 7)

Two rentable interiors. Both: a shared storage chest survives death; rest/sleep actions apply discrete HP regen and wanted-decay rather than real-time tickers.

### IMPLEMENTATION NOTE — modal-dialogue interior (not a scene swap)

Originally the spec called for a real scene swap with a bounded interior camera. In practice this collided with the rest of the game's modal/dialogue-driven interaction model, so the actual implementation is a **modal-dialogue interior**: pressing E on the door (when owned) opens `openHideout(kind)` — a dialogue with rest, sleep, chest, and (mom only) phone-reset actions. There is no separate interior camera or paused world rendering. The "5× faster wanted decay" and "1 HP / 4 sec" effects from the original spec became discrete `rest 30 minutes` actions instead of per-tick rates. See BRAIN.md wave 7 entry for the judgment-call reasoning.

### SCRAP YARD HIDEOUT

- Door rendered in world at `(520, 200)` (back corner of scrap yard).
- Gate: talk to Yuri while `P.faction.scrap >= +5`.
- Cost: $150 one-time. Sets `state.flags.scrapHideoutOwned = true`.
- Rest action: +8 HP, −1 wanted.
- Sleep action: +50 HP, +25 brain, +15 shakes, −2 wanted, advance day, +1 scrap rep.

### MOM'S APARTMENT HIDEOUT

- Door rendered in world at `(1230, 1180)` (marketplace, near mom's typical position).
- Gate: talk to mom while `P.faction.spiritual >= +10`.
- Cost: $30/day stayed (deducted on each dawn rollover; if short, evicts and −3 spiritual). Sets `state.flags.momHideoutOwned`.
- Rest action: +12 HP, −1 wanted.
- Sleep action: +60 HP, +30 brain, +15 shakes, −2 wanted, advance day, +1 spiritual rep.
- Phone action: resets `state.phoneT` to skip the next ambient call deterministically.

### STORAGE CHEST (shared)

- E on the chest from either hideout opens `openHideoutChest(kind)` deposit/withdraw menu.
- Stash lives at `state.hideoutStash = { rocks, copper, cash, items }`. ONE stash, shared between both hideouts.
- Deposit/withdraw at fixed increments (1 rock, 1 copper, $10). Items array is allocated for future expansion (not yet wired).
- On player death/arrest: on-hand `P.cash` and `P.rocks` → 0 (existing behavior); `state.hideoutStash` is on `state` not `P` and is fully preserved. THIS is the point of the safe.

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
| Character/player `SPRITE_CACHE` | ≤ 360 prerendered 16×16-derived canvases |
| Environment/landmark/light caches | ≤ 48 additional fixed canvases, viewport-culled where applicable |
| Landmark facade cache | ≤ 20 static canvases, viewport-culled |
| Particle pool | Soft cap 200 (auto-prune on life expiry) |
| Save size | < 50KB |
| File size (total HTML) | ≤ 185KB gzip (v18 baseline: 179,459 bytes) |
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

## CURRENT OUT OF SCOPE / UNSHIPPED (v18)

- Networked multiplayer
- Procedural cities or a second city
- Boss music synth track
- Full per-zone ambient audio suite
- New Game+

Mobile controls, day/night, quest UI, equipment, Tweaker Vision, achievements, procedural graffiti, and weather were historical v3 exclusions and are now shipped.

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

## v19 post-audit legibility invariants (2026-07-15)

These contracts apply to the modular `index.html` build. They repair four measured failures from `LEGIBILITY-AUDIT.md`; they do not create a general text-vs-text collision system.

### Building sign coverage

- Every `BUILDINGS` entry with a non-empty `name` has an explicit `BUILDING_STYLE[name]` record with a non-empty `sign`.
- Repeated building names may share one authored style. Style fallback remains available only as defensive rendering, not as valid content authoring.
- The permanent gate enumerates building entries, not merely unique keys. Audited baseline: 21 uncovered entries of 24 named buildings. Required result: 0.

### Zone-label clearance

- A zone may declare an optional `labelDy`; absent values retain the v19 baseline of `18` logical pixels.
- The label bounding box must not intersect any building body or authored awning. `THE LAUNDROMAT` uses the data offset needed to clear its storefront; no gameplay coordinates move.
- Static text-vs-text collision testing is explicitly out of scope: the audit found 0 intersections across 75 static text boxes. Audited text-vs-art baseline: 1. Required result: 0.

### Dynamic nameplate de-confliction

- Visible nameplates are laid out in deterministic feet-sorted draw order.
- Before drawing a nameplate, its union box moves upward until it strictly clears every accepted nameplate box in the current frame.
- Layout reuses cached NPC box objects and one frame buffer. It does not move NPC gameplay coordinates or allocate a fresh list per actor per frame.
- Audited spawn baseline: 2 intersecting pairs. Required result, including a dense 60-label fixture: 0.

### Graffiti wall fit and persisted-layout migration

- Graffiti text width is measured with the exact selected Courier font size before placement.
- A tag is selected only from lines that fit the building's usable horizontal wall width (`building width - 12`). The placer may step the selected size down to 8px to find a valid line.
- Every generated record stores measured width and wall bounds. Horizontal placement preserves a 6px margin on each side, and render culling uses measured width rather than the historical 170px guess.
- Saved v19 graffiti records without the layout marker/metrics are rebuilt once. This intentionally supersedes the older invariant that every persisted v13 layout must remain geometrically unchanged; text containment is now authoritative.
- Audited baseline: approximately 51% of possible/generated tags overflow. Required result: 0.

### Permanent gate

`tools/legibility-gate.mjs` must remain runnable and must fail on any non-zero count for these four invariants. It must use measured text widths and art geometry from the production modules.

---

## NPC identity registry gate (post-audit 2026-07-15)

The `VIBE.md` canonical identity table is a shipping contract, not optional lore. Every runtime actor identity must resolve to exactly one complete row with the four required fields: `Name`, `Tic`, `Relationship`, and `Transaction/Threat`.

### Coverage contract

1. The permanent gate boots the modular new-game runtime and also scans every production source module for actor-shaped authoring (`name` together with `sprite`), explicit name mutation, kingdom `guardName`/`bossName`, and recognized generated-name expressions. It additionally starts the emperor fixture so both reserved throne-guard actor families are exercised. This covers actors that are absent from a fresh spawn because they appear only on a day event, quest branch, wanted response, boss phase, pet branch, or completed-campaign day.
2. A literal actor name must exactly match a canonical VIBE row or an explicit alias whose target is a canonical row. No free-form ignore list is valid.
3. Allowed aliases represent the same person/state, not a way around registration: `BRUTUS (SKID) -> BRUTUS`, `LURCH (SKID) -> LURCH`, `SHERRI (SKID) -> SPIDER-BITE SHERRI`, and `FATHER O'MALLEY (FALLEN) -> FATHER O'MALLEY`. Both chained/freed dog records share the canonical `THE DOG` row.
4. Generated display numbers normalize only through an explicit family rule. `CURB PRETENDER No. <positive integer>` resolves to the canonical row `CURB PRETENDER No. N`. An unrecognized computed `name` expression fails the gate and must receive a fixture/normalizer plus a complete canonical row before ship.
5. Every registry cell is trimmed and non-empty; names are unique. A row cannot pass with placeholder punctuation, `TBD`, or a duplicated canonical name.
6. Generic combat roles are not exempt merely because multiple instances share one display label. `COP` has one canonical identity row; all generated cops resolve to it.
7. The four operator-reserved guard slots are decision-registered. The 2026-07-15 ratification keeps `TARP KNIGHT`, `CART LANCER`, and `WIRE DEACON`, and changes the throne-guard display label from `CURB HOLDOUT` to `KNIGHT EMERITUS`. The gate stores the dated operator-ratified rename chain and binds each current approved value to its campaign authoring sites plus fresh-runtime id family; changing even one site, or changing source and VIBE together, must still fail until a new dated operator-ratified decision-register entry updates that slot.

### Required gate result

`tools/npc-registry-gate.mjs` must fail when:

- a runtime/source actor identity has no canonical row or explicit same-identity alias;
- a VIBE row omits any of its four cells;
- an alias points to a missing row, aliases chain, or two canonical rows use the same name;
- a new actor uses an unrecognized computed display name; or
- any current operator-reserved display name changes without a new dated operator-ratified decision-register entry.

The passing report includes canonical-row count, distinct actor identities covered, runtime actors observed, alias count, and generated-family count. This gate changes no gameplay state, dialogue, combat, save data, sprite, or display name.

---

## OD-1..4 ratification + gate launcher (2026-07-15)

### Ratified VIBE constraints

1. The Clerical Pattern is canonical pattern #5. For a wave adding `N` new permanent-loop beats, it may own at most `floor(N / 2)`; the other four patterns own the remainder. The existing 54 permanent-loop beats are grandfathered and are not rewritten to satisfy the ratio.
2. HARD YES #6 is exactly: “mundane > magical — and if the setup goes magical, the mundane must win in the same breath.”
3. Campaign-scale and endless systems must periodically return the BAD IDEA through score → smoke → 18s high → 8s crash. Long-form objectives may not permanently displace that loop. Frequency, transport, and coverage-budget enforcement is deferred to the Wave-4 world-scale session.
4. `KNIGHT EMERITUS` is a display-label-only ratification. IDs, sprites, spawn sites, rewards, balance, and behavior remain unchanged.

### Verification launcher

1. `node tools/run-gates.mjs` launches, in order, `module-gate.mjs`, `npc-registry-gate.mjs`, `legibility-gate.mjs`, `presentation-gate.mjs`, and `runtime-smoke.mjs` as child processes using the current Node executable plus `--experimental-vm-modules`.
2. Child output is inherited and streamed. The launcher stops at the first spawn error, signal, or non-zero exit, returns non-zero, and does not run later gates. Five successful children produce a 5/5 PASS summary.
3. `tools/run-gates.cmd` is a two-line Windows shim that invokes the plain-Node launcher without adding a dependency or package script.
4. `runtime-harness.mjs` and `runtime-smoke.mjs` guard `vm.SourceTextModule` before construction. Invocation without `--experimental-vm-modules` prints a friendly instruction, exits 1, and emits no stack trace.

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
| v13 wave 8.6 | May 2026 | Playtest bug fix wave. Two fixes: (1) interact priority overhaul — `tryInteract` now scans NPCs (closest within 60px) BEFORE interactive props (bench/trash/phone/cart/dumpster), so adjacent props no longer hijack vendor E. Doors (hideout, old school) stay above NPCs. Heist trigger between NPCs and props. Marketplace panhandle's redundant closeNpc check removed (now dead code after the lift). (2) Old School properly gated — `tryEnterOldSchool` refuses entry below `P.rank >= 3` with a one-option refusal dialogue; first ever copper rip per save FORCES OS Brutus spawn (0 copper that attempt), tracked via new `state.flags.osBrutusKilled` flipped on his death-drop. Subsequent rips revert to existing 40% probabilistic spawn. Save key unchanged. |
| v14 | July 2026 | Visual world cohesion: connective roads/terrain/rails, cached facade silhouettes and environment sprites, district lighting/fog, foreground depth, culling, connective minimap, memory-only storage fallback. Save key unchanged. |
| v15 | July 2026 | Living-neighborhood incident engine with six physical scenes; true logical-pixel raster pipeline; authored roster signatures; sleeping Dave, three dog silhouettes, crowned Pigeon King, Fallen O'Malley and Tony coat states; cached nameplates/buffer. Save key unchanged. |
| v16 | July 2026 | Control reliability fix: event-latched multi-key WASD/arrows/Shift, removed 700ms repeat watchdog and global pointer keyboard purge, unified keyboard/analog/modal/focus release. Movement math, status timing, bosses, and save key unchanged. |
| v17 | July 2026 | Cursed-sticker sprite pipeline with directional player/attack/gear/weapon/cart/route layers; BAD IDEA guidance and touch/keyboard control ledgers; persistent endless three-stop block routes; feasible/persisted daily hustles; IndexedDB-backed `window.storage` browser adapter; local Possum prophecy pool; square-pixel mobile letterboxing. Save key unchanged. |
| v18 | July 2026 | Far-east expansion to 5800×3800; condemned office/shelter with six visible upgrades; eleven reputation-gated survey/file/sign claims; bounded endless office orders; new Leasing Guy and Gutter Greg sprites; evolving office/sign/minimap presentation; safe paginated bus travel; hardened partial-save reconciliation. Save key unchanged. |


## v20 landing 1 — HUD deconfliction + unique-cart authority (2026-07-15)

This is the prerequisite presentation/interaction landing named first in `SPEC-V20-PACKET.md`. It does not implement THE REGULAR or a smoke concession.

### HUD presentation contract

1. HUD bounds derive from the centered 4:3 game rectangle inside the stage, not from viewport width alone. This relationship must hold when a short desktop window shrinks the stage by height and when a touch layout letterboxes the canvas in portrait or landscape.
2. The left and right HUD columns occupy disjoint halves of the available HUD width. Wallet groups may wrap within the left half; rank/time copy may wrap within the right half. Neither column may escape the game rectangle.
3. The redundant desktop key ledger remains one line while it fits and is hidden by the compact HUD state when the game rectangle is `520px` wide or narrower. The title receipt and Q ledger remain the full control references.
4. When touch controls are displayed, the news ticker's right edge and the touch topbar's left edge share one computed boundary. The topbar may shrink on a viewport narrower than its authored `171px` width; it may never paint over the ticker.
5. Layout is recomputed on resize. The permanent fixture covers `800x600`, `1024x480`, `1024x360`, `1280x300`, `390x844`, and `844x390` viewport/stage relationships.

### Unique rideable-cart contract

1. Exactly one `PROPS` record has `type:'cart'`. Decorative `cart_husk` records remain scenery and never enter interaction or ownership state.
2. NPC-first interaction priority remains unchanged. The rideable cart's authored Marketplace anchor is `(1000,1600)`, whose center-to-center distance from every fresh interactive NPC exceeds the combined `60px` NPC-priority radius plus `36px` cart-use radius. Every point that can mount the cart is therefore free of an NPC-priority shadow.
3. `P.cartMounted` is the sole mount-state authority for player stats, player underlay, world-cart visibility, action guidance, interaction, and persistence. The cart prop carries no parallel `mounted` flag.
4. Ordinary use mounts the unique cart, changes the hint to abandon, and a later use drops that same cart beside the player. THE BIG GUY acquisition enters the identical mounted state and retains the same abandon path.
5. Mounted save/load restores the existing `player.cartMounted` field and no new save key or parallel save shape. A fresh game clears the mounted state and returns the cart to its authored anchor.
6. Cart speed cap, `+10` maximum HP, roadkill behavior, collision, damage, reward, achievement, and every other balance value remain unchanged.

### Permanent gate

`tools/presentation-gate.mjs` must fail on a viewport fixture whose HUD columns leave/intersect the game rectangle, on touch ticker/topbar overlap, on a compact-threshold drift, on any rideable-cart count or spawn-clearance regression, or when ordinary mount/dismount, THE BIG GUY acquisition, fresh restart, and mounted save/load cease to share the one player authority.

---

## v20 landing 2 — THE REGULAR recognition ledger (2026-07-15)

### Registry and tiers

1. v20 recognizes exactly four venue ids: `park`, `laundromat`, `underpass`, and `choir_office`. These are the four future concession owners; recognition does not imply that a concession is implemented or currently legal.
2. Every venue owns exactly five natural-number counters: `sit`, `bother`, `buy`, `sell`, and `full_high`. Unknown venue/action keys are discarded. Negative, fractional, non-finite, inherited, and prototype-bearing values normalize to bounded natural integers.
3. Venue tier derives from the sum of its five counters and is never persisted: `stranger` at `0..2`, `counted` at `3..7`, `furniture` at `8..14`, and `conceded` at `15+`. Counters never decay in v20.
4. `sell` is schema-supported but dormant at these four venues. No existing successful sell occurs there. THE BIG GUY's cart exchange remains a trade, not a mislabeled sale; v20 does not invent a fifth recognition venue or concession to activate the verb.

### Credited verbs

1. Free verbs (`sit`, `bother`) credit once per source per venue visit. Leaving the venue clears only the ephemeral visit witnesses; re-entry permits another remembered action. E-key repeat cannot grind a tier in place.
2. Park `sit` credits only when a bench changes from standing to sitting. Park `bother` recognizes the philosopher and pigeon; Park `buy` recognizes one successful pigeon-secret purchase.
3. Laundromat `bother` recognizes Barb, Laundromat Lady, and Karaoke Mike. `buy` recognizes one successful Barb single/bulk option, laundry service, detergent purchase, or karaoke payment. Quantity does not multiply the verb; refusals and disabled options credit zero.
4. Underpass `bother` recognizes the Mathematician and THE BIG GUY. His cart exchange is not `buy` or `sell`.
5. Choir Office `bother` recognizes a successful read of the `wire` court door. It does not infer recognition from the broader clan campaign.
6. `full_high` credits exactly once at the existing `rockedT > 0` to `rockedT = 0; crashT = 8000` boundary, assigned by player-center containment at that boundary. It adds no continuous per-frame high ledger and changes neither status constant.

### Persistence and effects

1. `recognition` is one new additive top-level save key containing counters only. `SAVE_KEY`, save version, and every prior field remain unchanged. Missing legacy data normalizes to a fresh four-venue ledger.
2. Recognition recording may mutate only its counters, ephemeral visit witnesses, acknowledgment surfaces, and persistence. It grants no cash, item, discount, damage, combat state, faction, rank, shakes, brain, HP, speed, `rockedT`, or `crashT` change.
3. Only tier crossings toast/post a venue-specific acknowledgment. Ordinary increments remain quiet. The Q ledger shows all four venue tiers, remembered total, and non-zero verbs; it shows no reward, discount, next-threshold bar, or quest objective.
4. The 12 venue/tier beats contain three Clerical Pattern entries (`3/12 = 25%`), below the 50% future-beat cap. Pattern ids are restricted to `inverted_authority`, `bad_trade`, `cursed_aside`, `possum_pattern`, `clerical`, and `mundane_magical`.
5. The encounter-table line with an explicit trigger graduates now: the first venue to reach `counted` posts `he is still here. that is the whole post.` from `@blocklog`. The other nine encounter-table drafts remain untriggered until an encounter cadence is separately specified and gated.

### Permanent gate

`tools/recognition-gate.mjs` must fail on registry/threshold drift, malformed-save leakage, counter decay, free-verb repeat grinding, transaction over-counting, wrong venue/source mapping, reward-state mutation, high-boundary timing drift, incomplete reaction data, or a Clerical Pattern share above 50%. It runs inside `tools/run-gates.mjs` before the full runtime smoke.

---

## OD-5 ratification (2026-07-15)

Effective v20, the core-loop location invariant is amended to: "The Block is the only UNCONDITIONAL smoke/cook location. Additional smoke spots may exist only as earned, conditional concessions granted by the recognition system (SPEC-V20-PACKET.md, OD-SMOKE-COVERAGE)." The v18/v19 wave sections above record their own eras and stand unedited; the current build has zero concessions, so their invariants remain true of it today. Decision chain and rationale: REFACTOR-FINDINGS.md -> OD-SMOKE-COVERAGE (OD-5).

---

## v20 landing 3 — smoke concessions (2026-07-16)

Implements `SPEC-V20-PACKET.md` §2 (OD-5) per `SPEC-v20-concessions.md`. The "zero concessions" clause of the OD-5 ratification above records its own era; effective this landing the build has four.

### The one smoke transaction (I-ONE-LOOP)

1. The smoke transaction lives in exactly one exported function, `smokeRockAt(spotId)` in `src/systems/concessions.js`, and `rockedT = 18000` has exactly one assignment site in `src/` — enforced structurally by the permanent gate, because a numeric check passes a copy-paste as happily as an extraction.
2. The transaction is the blockMenu() transaction of v19, byte for byte: soap-first FIFO, `brain -4`, `shakes -50`, `cred +1`, `rockedT = 18000; crashT = 0`, the flash, the toast copy and timing, the street/spiritual rep ledger, the intro-chain completion, the save. Two named deltas only: the royal-static branch is additionally guarded on `spot.id==='block'`, and the feed line names the venue.
3. Soap is soap everywhere: the soap branch rides the same function and produces an identical delta and an identical feed line at all five spots.

### Spots and conditions

1. Five spots: the Block (unconditional, forever) plus `park` (night only), `choir_office` (during office hours), `underpass` (while the freed dog is present), `laundromat` (dryer mid-cycle only). Concession spot ids equal their recognition venue ids; smoking is legal anywhere inside the venue zone, the spot coordinate is the BAD IDEA anchor.
2. A concession exists only at `conceded` recognition tier (`recognitionTier()`, Landing 2). Below that tier the venue's room does not open and no state moves. No purchase path, no quest-flag path.
3. Night and dog presence read clocks that already existed (`state.dayTime`, `state.freedDogFollowT` plus the live follower). Choir office hours and the dryer cycle are clocks authored by this landing: the choir holds b flat on its own schedule (closed 90–150s, open 55s — office hours are b flat to b flat, the schedule does not convert), the dryer idles 50–90s and runs 70s, mid-cycle excluding 15s margins on both ends. The dog's lanyard is a line, not a flag (orchestrator decision, SPEC-v20-concessions.md).
4. The clocks tick in `updateWorld` on world time, persist as one additive save key (`concessionClocks`; save key and version 10 unchanged), normalize on load, reset on fresh save, and roll their phase durations from a private persisted LCG rather than `Math.random` (the runtime smoke runs this build in lockstep against frozen v19 on one shared seeded sequence).
5. Conditions are re-checked at ACTION, not at render — decided once, here: a menu opened legally may be refused at the click if the condition has died. In the current engine `updateWorld` pauses during dialogue, so the race is unreachable; the guard is load-bearing only if that ever changes.
6. A condition expiring mid-high changes nothing: the high runs its full 18000ms and the crash its full 8000ms. The world tolerates what it already tolerated.

### Surfaces

1. A conceded venue answers the E key like the block does: a zone verb at the bottom of the interaction chain, one smoke option, one exit, the condition stated and never explained. The action hint advertises the room (`consult the bench / the office / the bridge / the dryer`).
2. The Q ledger's REGULAR rows gain one concession line at conceded tier only — condition, plus live status. This is where choir office hours and the dryer state (mid-cycle / running-not-mid / idle) are readable from anywhere. Clock turnovers also toast, but only to a player standing in a venue that has already conceded.
3. BAD IDEA: when the player holds a rock (soap counts; the player cannot tell), is not high, and shakes have reached 50, the strip's selected thing becomes `smoke a rock at <spot>`, targeting the nearest LEGAL spot — a concession only while conceded and its condition is live, otherwise home. Ties (any exact tie for nearest, including between two concessions) go to the Block. Placement: below the intro, active office contracts, and every kingdom objective (the anoint objective still names the block — royal static is not portable), above available office work, routes, and quests. This lands the VIBE scope invariant mechanically.
4. No reward: a concession is permission, not payment. Nothing about *where* you smoke changes any currency, item, combat, or timer value — enforced by the identity fingerprint in the gate.

### Permanent gate

`tools/concession-gate.mjs` runs after `recognition-gate` and before `runtime-smoke` (suite: 8). It must fail on: a second `rockedT = 18000` site anywhere in `src/`; any P-fingerprint delta difference between the five spots (real or soap) beyond the venue-named feed text; a room opening below conceded tier; a smoke with a false condition (including the stale-menu race); royal static firing at any concession or failing to fire at the block — verified to go red with the spot guard removed before it was trusted; an illegal, farther-than-nearest, or tie-not-to-block BAD IDEA target across all 16 condition combinations; a truncated high or crash after mid-high condition death; or a clock persistence/normalization regression.

## v20 landing 4 — world relationships (2026-07-16)

Implements `SPEC-V20-PACKET.md` §3 per `SPEC-v20-world-relationships.md`. This landing is a ruler, not content: it adds one permanent gate and changes zero gameplay values (I-NO-BALANCE-CREEP — `git diff` on `src/` at this landing is empty). It closes the drift audit's open half: VIBE governs the sentence; this gate governs the map.

### The budget (derived, never authored)

1. Every budget is computed from live measurements at gate run time (I-MEASURED-NOT-VIBED): walk speed is measured by actually walking the player for one second and cross-checking against `P.speed × 1000/16` (`runtime_ui.js:33` via `update.js:82`); the withdrawal rate by standing still for one second (`update.js:124`); fresh shakes read from a fresh save (`runtime_ui.js:355`); the cap by overfilling and letting the clamp answer (`update.js:126`). At shipped values: 137.5 px/s, 0.8 shakes/s, 20→100, therefore a **100s runway = 13,750px**.
2. **I-RUNWAY**: no mandatory route/campaign leg over 60% of a fresh runway (8,250px at walk). **I-COVERAGE**: no map point farther than 45% of a runway (6,187.5px ≈ the SPEC's "~45s walk") from a *potentially* legal smoke spot — conditions deliberately ignored so coverage cannot flicker with a dryer. **I-BLOCK-DAY-1**: every day-1 strip objective within the leg budget of the Block. **I-TRANSPORT**: exactly one rideable cart; no fast travel.
3. All distances are **straight-line, a lower bound**. A leg that fails is definitely too long; a leg that passes may still be too long once collision detours are paid. The gate states this in its own output and never presents a lower bound as true path length.

### What counts as mandatory (the one interpretive call, operator-vetoable by name)

A leg is mandatory when the game assigns it as the standing BAD IDEA and the player cannot progress that lane without walking it: the intro chain, office acquisition, every claim/work-order leg (any four claims gate the kingdom), the kingdom chain in strip-guided order, and **route legs — a rolled route is assigned, not chosen; the clipboard does not negotiate**. The route pool is measured with unlock flags treated as potentially earned, the same load-bearing "potentially" as coverage. Not governed: the bus (optional one-way teleport), the public phone, hustles, wandering. The leg inventory is read through the real objective selectors (`currentPrimaryObjective` / `currentOfficeObjective` / `currentKingdomObjective`) by driving quest/stage state — the gate measures what the strip actually points at, not a hand-copied table.

### Permanent gate, and its standing honest reading

`tools/world-gate.mjs` runs LAST in the suite (a standing world reading must never mask a regression in the seven gates that protect shipped behavior — the runner stops at first failure). Red-verified before trusted: a moved venue fails COVERAGE naming the uncovered point; a moved banner fails RUNWAY-CAMPAIGN naming the leg; a planted second cart fails TRANSPORT; all restored to green. **The gate ships red on one genuine reading**: route leg `scrap_gate ↔ ditch_gauge` is 8,274.6px (60.2s) against the 8,250px (60s) budget. That is a finding in `REFACTOR-FINDINGS.md` (Landing 4, OD-9) awaiting an operator ruling — per this landing's own SPEC, the budget does not move to make the light turn green.

## v20 landing 5 — route budget (2026-07-16)

Resolves OD-9 per `SPEC-v20-route-budget.md` (on main at `6f57af8`): **constrain the generator** — not the budget, not the content, not a grandfather list. The world gate's first finding turned out to be a generator with no distance awareness handing out the one illegal pair it happens to contain: 253 table pairs, 252 within budget, the worst missing by 24 pixels.

1. **I-ROUTE-BUDGET.** `rollBlockRoute` may never assign a consecutive within-route leg over 60% of a fresh runway. Selection after the unchanged shuffle: each next stop is the first remaining candidate within budget of the previous — identical to blind first-three whenever first-three is legal. Every existing filter (`completed<2` neighborhood, `unlockFlag` gating, `lastStopId` exclusion, serial/toast) is preserved byte-for-byte; the shuffle consumes the identical `Math.random` sequence, so frozen-v19 lockstep parity is untouched.
2. **I-ROLL-TOTAL.** The roller always returns three stops. If no remaining candidate is within budget (pathologically small or sparse pool), it relaxes to the nearest remaining candidate — never null, never a spin. Satisfiability is proved by the gate, not assumed: every stop in the shipped table keeps ≥21 within-budget partners.
3. **I-NO-BUDGET-DRIFT.** The budget is derived at run time in `routeLegBudgetPx()` (`src/systems/progression_routes.js`); the literal 8250 appears nowhere. The derivation restates the engine's model inputs by name, and `tools/world-gate.mjs` measures those same quantities behaviorally every run and fails the suite the moment derivation and world disagree — a second copy pinned to the first by a gate is a tripwire, not a drift risk.
4. **The gate now measures the generator, not the table**: 10,000 rolls per pool configuration (day-1, pre-office, full-unlock) with chained `lastStopId`, zero over-budget assigned legs, zero nulls. Raw table pairs beyond budget are reported informationally as generator-excluded. The `player → first stop` leg is ungoverned and ungovernable (the player can be anywhere); stated in the gate rather than pretended away.
5. **I-STILL-CRUEL.** One pair in 253 removed, no mercy added: the worst assignable leg is still 8,123.8px — 98.5% of the budget.

Red-verified both directions before trusted: constraint reverted → gate red naming `scrap_gate ↔ ditch_gauge` (69 assigned in 10,000 rolls); budget forced to 10px → all 30,000 rolls still return three valid stops via the fallback and NO-BUDGET-DRIFT fires. Suite: **9/9 honestly green.**

### Landing 5 addendum — the detector restored as the alarm (OD-10, operator-ratified 2026-07-16)

Constraining the generator created a silent-failure mode the operator named: a gate that measures generator output can no longer fail on world growth — the filter absorbs scope creep and a filtered world is indistinguishable from a clean one. Three structural invariants close it, every threshold derived, none invented:

1. **I-DEAD-STOP.** In every reachable pool, every stop keeps ≥ 1 + maximum-simultaneous-exclusions within-budget partners (3 for pools larger than three, 2 at exactly three). Below the floor the relax-to-nearest fallback becomes reachable, and **a firing fallback is the generator assigning an over-budget leg** — the fallback stays dead code deterministically, not probably.
2. **I-CO-ROUTABLE.** The legality graph over the full pool keeps diameter ≤ 2 — every pair of stops, excluded ones included, can still share one three-stop route through some middle. The 2 is the number of legs in a route. Failure means regionalization; no ledger signature papers it.
3. **I-EXCLUSION-LEDGER.** Over-budget table pairs must exactly equal the named ledger in the gate; each entry cites a register decision whose token must literally appear in `REFACTOR-FINDINGS.md`; both directions fail (unratified exclusion / stale entry). The generator may exclude exactly what the register has signed, and nothing else. Ratified today: one pair, `scrap_gate ↔ ditch_gauge` (OD-10).

The legal-pair fraction (99.6% at ratification) is a printed trend line, never a threshold. **Known limit, stated in the gate header:** the signature check proves a signature exists, never that it was worth signing — an autonomous loop can sign its own permission slip (ORCHESTRATOR-NOTES entry #2's family, not fixable at this layer). When the loop goes live, ledger growth is a human-review trigger. Red-verified in all four directions: isolated stop (DEAD-STOP + CO-ROUTABLE + unratified pair, with the output sampling also catching the fallback's over-budget legs — the causal chain confirmed live), emptied ledger, stale ledger, phantom citation.
