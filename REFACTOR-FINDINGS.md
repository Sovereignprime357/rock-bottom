# Refactor findings — v19 modularization

This list records things noticed while moving the frozen v19 build. It is deliberately not a fix list: the modularization wave preserves v19 behavior.

- The 83 dashed comments include 74 top-level seams and 9 nested labels. Six nested labels are branches inside the NPC-AI loop, two are labels inside `spawnNpcs`, and one is inside mobile setup. They cannot be independent modules without changing their containing control flow.
- The original UPDATE section and the v10 building-render section exceed 1,000 lines. UPDATE needs its complete NPC loop extracted as one helper; rendering can split at existing top-level function/comment seams.
- `npcs`, `cashPiles`, and `projectiles` are rebound from multiple systems. They require one shared runtime owner so module imports remain live and writable without a global shim.
- Campaign state, persistence, and startup form function-only import cycles. No module may read those imports during module evaluation; original top-level execution order stays centralized in `src/main.js`.
- `qa_v19_temp.js` contains an outdated normalization expectation (`marks === 0` after advancing to `cart_marks`). It is not a green refactor gate and remains untouched during this wave.
- The browser available in this workspace blocks local `file:///` navigation, while native ES modules require HTTP. Static linking and deterministic VM parity are automated; live visual/audio/keyboard feel still needs a served manual pass.
- The frozen file contains known legacy mojibake, registry omissions, and legibility defects documented in the ratified audits. Those remain byte-for-byte in v19 and are handled only after the behavior-identical refactor lands.

## Wave 4 — relationships the larger world never acquired

This is a dependency inventory, not a balance patch. None of the values below changed in Wave 4. The operator must decide which relationships become invariants, which become authored exceptions, and which remain deliberately unfair.

### Baseline

- v10 was `2200×1900` (`4.18M px²`); v19 is `8600×5600` (`48.16M px²`) at `src/data/world.js:15`. Area grew `11.52×`; the unobstructed diagonal grew from `2,906.9px` to `10,262.6px`, or `3.53×`.
- The camera remains the deliberate `800×600` contract at `src/data/world.js:12`. Base movement remains `2.2px / 16ms`, approximately `137.5px/s`, at `src/core/runtime_ui.js:338`. A v19 diagonal therefore takes `74.6s` before collision detours.
- The missing relationship is usually not “multiply this constant by 11.52.” Spatial systems need coverage, maximum-distance, or travel-time budgets. Content systems usually need an eligible-zone predicate plus explicit exemptions.

### Travel, survival, and clock budgets

| Dependency | Current constant(s) | Relationship that was never written down |
|---|---|---|
| Passive withdrawal | `+0.0008 * dt` at `src/core/update.js:122`; fresh shakes `20`, cap `100` | Time from ordinary starting shakes to the damaging cap must be compared with a typical objective leg, the longest mandatory leg, and a round trip to a valid smoke point. Fresh `20→100` is `100s`; one unobstructed world diagonal is already `74.6s`. |
| Sprint withdrawal | Speed `×1.7` at `src/core/update.js:79`; extra shakes `+0.012 * dt` at `:123` | Sprint range must have a stated relationship to objective-leg length. From `20`, shakes cap in about `6.25s`; a sprinted diagonal is about `43.9s`. |
| Smoke access and relief | Smoke is available only in `block` at `src/systems/interactions.js:163-166`; one rock removes `50` shakes and starts an `18s` high at `src/minigames/activities.js:230`; crash adds `30` at `src/core/update.js:140-141` | The number and placement of smoke points, and the net withdrawal relief, need a maximum-distance/round-trip relationship. Smoking at `100` returns to `100` shakes about `25s` later under passive accumulation; smoking at `50` or below provides about `87.5s` before cap. |
| High/crash travel coverage | High `18s × 1.8`; crash `8s × 0.5` at `src/minigames/activities.js:214,230` and `src/core/update.js:75-76,140` | The canonical `18s→8s` loop is deliberately frozen, but the surrounding map never received a coverage invariant. At base equipment, the high covers about `4,455px`, the crash `550px`, and block-to-throne is about `8,396px`. The loop must stay exact; map routes, access points, or transport must carry the relationship. |
| Damage at maximum shakes | Per-update `0.006` chance of `2` damage at `src/core/update.js:125` | Expected harm exposure grows with travel time, but there is no travel-budget invariant and the probability is not normalized by `dt`. At 60fps its expectation is about `0.72 HP/s`. |
| Recovery geography | Passive HP recovery exists only in `block` at `src/core/update.js:127-130`; death and arrest always return to `(1050,840)` at `src/systems/combat.js:439,451` | Recovery/respawn coverage needs a maximum return distance or an explicit “the whole kingdom still wakes up at the crate” rule. The travel penalty grew with every expansion even though the anchors did not. |
| Day length | One day remains `240,000ms` at `src/core/update.js:169-170` | Day duration must be related to typical and worst daily-work travel. One day held about `11.4` v10 diagonals; it holds about `3.2` v19 diagonals. |
| Endless block route | Exactly three random stops; after two routes the unlocked full-map pool is shuffled without a distance budget at `src/systems/progression_routes.js:94-124` | Route generation needs a maximum path length/travel-time relationship to withdrawal, the day clock, transport, and reward. The current worst direct two-leg sequence is about `16,398px` or `119.3s` before obstacles. The `$24 / 4 cred` caps at `:152-153` also have no relationship to route cost. |
| Office claims and orders | Survey → office → sign → office at `src/systems/campaigns.js:138-148`; one to three orders/day at `:78`; uniform owned-district selection at `:202-204` | Claim/order selection needs a travel-time budget against the `240s` day. The train-yard claim is roughly `11,820px / 86.0s` of direct base travel; its order round trip is about `9,240px / 67.2s`. |
| Bus capacity/topology | One ride per day, one origin, one-way teleport at `src/dialogue/vendors_places.js:61-97,275`; 18 destinations at `:576-595` | Destination count grew, but the number of operational origins and rides did not acquire a relationship to world diameter or loops that require returning to the block/office. Visual shelters are not transport nodes. |
| Public phone response | One phone at `(130,220)` in `src/data/props.js:134-135`; ring every `240–480s` with a `30s` window at `src/core/update.js:427-439` | Answer window and phone coverage need a maximum travel-time relationship. Phone-to-throne is about `9,538px`: `69.4s` base or `40.8s` sprint, so both exceed the window. The ring interval also equals one to two complete in-world days without an explicit clock relationship. |
| Police arrival | Cops spawn on the nearest `WORLD` boundary at `src/systems/combat.js:458-468`; wanted decays every `18s` at `:480-488` | Police response distance/time must be bounded independently of world dimensions, or the world-edge fiction must be explicitly kept. A player near the map center can be thousands of pixels from the spawn boundary while the wanted clock remains fixed. |
| Incident cadence | Initial `35–55s`, recurrence `70–110s`, max three/day, zone chosen only when the timer expires at `src/core/runtime_ui.js:400` and `src/systems/incidents.js:93,163-182` | Cadence needs a relationship to day length, travel time, and time spent inside an eligible authored zone. Longer transit increases expiries in uncovered space and therefore favors the one global fallback. |

### Population, resources, and authored coverage

| Dependency | Current constant(s) | Relationship that was never written down |
|---|---|---|
| Base NPC population | Fixed 41-entry spawn literal at `src/data/npc_spawns.js:46`; 32 are inside the old `2200×1900` core, nine outside it, none in the v19 footprint | Define peaceful, transactional, and hostile population floors per populated zone or zone area, plus intentionally-empty exemptions. Area grew `11.52×` from v10 while the base population grew only `1.37×` (`30→41`). |
| Kingdom guards | Fifteen authored posts, initially adding 15 guards to reach 56 active NPCs, at `src/systems/campaigns.js:513,763` | Guard count correctly scales by clan count, but only within four clan zones. It is not a substitute for a population relationship across the other nineteen zones; guard density per clan area is also unspecified. |
| Solid buildings and facades | 25 solid `BUILDINGS` records at `src/data/props.js:44`; 28 `LANDMARK_FACADES` at `src/data/world.js:160` | Define structures/frontage per named zone, road length, or maximum empty travel distance, with explicit vacant-zone exemptions. Manual per-wave append counts are not coverage. |
| Kickable trash cans | Six cans for 23 zones, all in the old core, at `src/data/props.js:10-19` despite the comment “one per zone roughly” | Make the prose executable: one per eligible zone, or another stated density with an exemption list. |
| Breakable bottles | Exactly eight active bottles from 16 candidates, all around `x≤1820,y≤1820`, at `src/data/props.js:20-38` | Both count and candidate-pool coverage need to track eligible zones/traversable area. Every world expansion currently requires a remembered manual append and received none. |
| Dumpsters and loot geography | Ten dumpsters in the fixed `PROPS` list, none in a v19 clan zone; distance bias saturates at `900px` from the block at `src/systems/interactions.js:202-225` | Define dumpsters per eligible zone/building cluster and the maximum verb-free distance. Loot tiers must relate to travel topology or a declared regional tier; almost the entire expanded world is now the same “far” bucket. |
| Authored cash | 28 fixed piles worth `$255` at `src/data/npc_spawns.js:361-376`: 22 old-core, five skid-row, one old-school; none in v18/v19 extensions | Define pickup count/value per eligible zone and maximum resource-free travel distance. Dynamic park/phone drops do not create map-wide coverage. |
| Graffiti quantity | `12–18` tags total for 24 eligible buildings and 72 candidate faces at `src/render/structures.js:255-292` | Tag quantity needs a per-eligible-wall/building/zone relationship and a duplicate-wall policy. Wave 3 fixed geometric fit, not density. |
| Graffiti identity | Pools are 36 street, 15 scrap, 15 spiritual at `src/data/catalogs.js:70-143`; neutral/clan areas fall back to street at `src/render/structures.js:231` | Content-pool coverage must relate to zone/faction identity. Seven neutral zones, including the four kingdoms, currently inherit legacy street copy. |
| Night lighting | 24 `WORLD_LIGHTS` at `src/data/world.js:298-323` plus 11 lamp props; only four world lights and no lamp props occupy the v19 footprint | Define lit coverage for entrances, objectives, and long road stretches, or maximum unlit travel distance. A raw global light count is not enough. |
| Mechanical phones | Exactly one pay phone at `src/data/props.js:134-135` | Phone count/placement must relate to travel diameter or reachable major regions. The response window is the separate timing dependency above. |
| Transport nodes | Five visual shelters in `src/data/world.js:192-269`, but only the original `busstop` zone is mechanical | Specify which shelters are scenery and which are operational. If transit offsets map growth, operational node coverage must relate to major regions/world diameter. |
| Road furniture | 92 fixed `WORLD_DECOR` records against 28 manually-authored road segments at `src/data/world.js:90,191` | Drains, poles, barriers, crosswalks, shelters, and news boxes need a relationship to road length, intersections, or frontage. No gate detects a new empty road. |
| Local incidents | Six definitions: one global and five tied to `market`, `laundromat`, `scrap`, `park`, and `trainyard` at `src/systems/incidents.js:242-310` | Require one incident per eligible zone or a generic pool at least as broad as the daily cap. Eighteen of 23 zones, including all v19 zones, have no local incident. |
| Route-stop membership | 23 fixed stops at `src/systems/progression_routes.js:250-274`, numerically equal to 23 zones only by accident: `abandoned` has none and `east service road` substitutes | Gate one stop per eligible zone with an explicit omission/substitution allowlist. New-zone coverage is currently a manual memory test. |
| Claim membership | 11 fixed `CLAIM_SITES` for 23 zones at `src/systems/campaigns.js:653-664` | Define the predicate for “claimable district” or maintain an explicit excluded-zone contract. Completion scales to the array length; membership does not scale to eligible zones. |
| Crown search | Six candidates, all in the legacy core, at `src/data/catalogs.js:177` | State that the quest is intentionally core-only, or relate candidate coverage to unlocked/visited zones. |
| Communications breadth | 12 incoming calls, 23 news lines, 29 world events, and 10 public-phone lines at `src/systems/communications.js:128-246` and `src/data/catalogs.js:48-67` | This is a content-breadth decision rather than raw density: define minimum representation per major zone/system if contextual repetition is meant to follow expansion. |

### Full-world map legibility

- The minimap always compresses the full world into `120×96` at `src/render/minimap.js:12-14` and `index.html:177`. At v19, `sx=.01395` and `sy=.01714`, so Y units render `22.9%` larger than X units. The `800×600` viewport box fell from about `43.64×30.32px` in v10 to `11.16×10.29px`; a `64px` tile projects to roughly `0.89×1.10px`.
- Parameterizing the denominators prevented stale coordinates, but it did not specify a map invariant. The missing relationship is a preserved aspect policy plus minimum projected size/separation for the viewport, objectives, zones, roads, NPCs, and facades—or an explicit threshold for switching to a zoomed/local map. The `Math.max(1, ...)` floors at `src/render/minimap.js:17-40` make unrelated features converge as density grows.

### Relationships repaired in Wave 3

These were the same class of missing set/geometry relationship, but they are no longer open findings:

- Every named building now maps to a non-empty `BUILDING_STYLE[name].sign` (`24/24`).
- Every zone-label ink box must clear building and awning art (`23/23`).
- Visible nameplate boxes are deconflicted against simultaneous visible-label density (`56` production actors plus the dense synthetic gate). Maximum upward stack displacement/viewport containment is still unspecified, but the overlap relationship is encoded.
- Graffiti placement and culling now derive from measured text and actual wall bounds (`14` fitted production tags in the current deterministic gate). Quantity and faction-pool coverage remain open above.

### Boundaries and counterexamples

- **The vignette is not a growth regression.** `inset 0 0 100px 20px #000` was byte-identical from v10 through v19. Wave 1 corrected only its z-order. Its intensity is an original fixed-viewport choice.
- Local interaction radii (`60px` NPC, `44px` doors/dumpster, `38px` phone, and similar), sprite hitboxes, combat scene distances, cull padding, and nameplate show radius should derive from local art/interaction geometry—not `WORLD.w/h`.
- Camera clamps, teleports, general culling, ground-tile iteration, and objective edge guidance already derive from `WORLD` and/or the fixed `800×600` viewport. They are correctly parameterized.
- Procedural ground, grime, and road rendering already follow visible world geometry. Posters already cap per faction zone. The building-style coverage failure is fixed. The single rideable cart is explicitly unique.
- Ambient call/news/event timers without a physical response window are player-time systems, not spatial systems. They should not be multiplied by map area.
- Fixed DOM HUD fonts, ticker width, dialogue placement, unclamped `(E)` prompts, rain count, and screen-effect radii have missing **viewport/content** relationships. They are real legibility work, but they are not evidence that world-size constants regressed. Likewise, the fixed `800×600` camera is an explicit SPEC decision; whether the player should see more of an `8600×5600` world is an operator call.

## Wave 5 — required registry repair

- [x] Restored the four-column VIBE registration requirement as `tools/npc-registry-gate.mjs`.
- [x] Backfilled 30 identities. The audit estimated approximately 26; the exhaustive source/runtime inventory also found `MAYOR'S COUSIN`, `THE PRIEST'S SON`, `SOMEONE YOU DON'T KNOW`, and the shared generic `COP` identity.
- [x] Kept four true state/variant aliases explicit rather than inventing duplicate people: Fallen O'Malley and the three source-declared SKID variants.
- [x] Flagged the four weak kingdom guard names below without changing a display name, id, sprite, behavior, or line.

## Operator decision register

The audit evidence and the 2026-07-15 operator decisions are recorded here. Each AI-led decision remains subject to operator veto. Register discipline: ratified decision text is append-only — execution and status notes are added beneath a decision, never edited into it.

### OD-NPC-NAMES

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Measured evidence:** `TARP KNIGHT`, `CART LANCER`, `WIRE DEACON`, and `CURB HOLDOUT` are the four kingdom rank/prop names that skipped the original four-column test and fail the audit's cursed-name test. They now have complete registry rows, so completeness and taste are separate questions.

**Non-ratified audit recommendation:** none; flag the names and leave taste in the operator's seat.

**Current behavior preserved:** only the throne-guard display label changes; ids, sprites, guard families, boss adds, and combat behavior remain unchanged.

**Operator decision:** DECIDED (AI-led). TARP KNIGHT, CART LANCER, and WIRE DEACON stay. Generic rank names are correct wallpaper for repeated ambient mobs — their formula flatness is what makes the ruler names (DARRYL UNDER BLUE) land by contrast. CURB HOLDOUT → KNIGHT EMERITUS. Post-completion holdouts are permanent endgame texture and deserve the mundane-wins beat: "emeritus" is the institutional word that deflates "knight" in the same breath. This ratification updates the VIBE registry row, campaigns.js display label, and the registry gate's reserved-name decision record. Veto reverses cleanly.

### OD-PATTERN-ROTATION

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Measured evidence:** the clerical construction owns 23/23 route stops, 22/22 claim beats, and 9/9 kingdom marks—approximately 54 permanent-loop beats. VIBE's four named escalation patterns remain concentrated in older incidental events. This happened because the clerical pattern is generative and “make it bigger” repeatedly selected the easiest pattern to extend.

**Non-ratified audit recommendation:** name the Clerical Pattern as a fifth VIBE pattern, keep it, and add a rotation/share rule so it does not monopolize future endless content.

**Current behavior preserved:** no shipped route, claim, mark, or permanent-loop beat changes; the 50% share rule applies only to new permanent-loop content.

**Operator decision:** DECIDED (AI-led). The Clerical Pattern is canonized as VIBE pattern #5 — it earned it; it is the game's spine. Share rule for FUTURE permanent-loop content only: clerical owns at most 50% of new permanent-loop beats per wave, remainder drawn from the other four patterns. The existing 54 beats are grandfathered — rewriting shipped copy to satisfy a ratio is churn, not craft.

### OD-MEDIEVAL-REGISTER

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Measured evidence:** kingdom, throne, crown, knight, bishop, anointing, and succession language is now a campaign register. The implementation repeatedly lets tarps, curbs, forms, wire, and a folding chair win in the same beat; the final throne remains a folding chair.

**Non-ratified audit recommendation:** amend HARD YES #6 toward “mundane > magical, and if the setup goes magical, the mundane must win in the same breath” rather than removing the kingdom register.

**Current behavior preserved:** only HARD YES #6 changes; campaign terms, dialogue, objectives, bosses, and ending copy remain unchanged.

**Operator decision:** DECIDED (AI-led). Audit amendment ratified verbatim: HARD YES #6 becomes "mundane > magical — and if the setup goes magical, the mundane must win in the same breath." The shipped campaign already obeys it (lawn-chair throne, rock coronation, folding-chair emperor); this writes down the rule the good content was already following. No copy changes.

### OD-VIBE-SCOPE

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Measured evidence:** VIBE strongly governs sentence-level tone but says nothing mechanical about world scope, campaign grammar, objective rotation, or how often the BAD IDEA must return to scoring and smoking. The world is now `8600×5600`; office, route, and kingdom objectives dominate long stretches after the intro, while the anoint stage is the one explicit return to the core loop.

**Non-ratified audit recommendation:** extend VIBE with a scope invariant and a meaningful recurring route back toward the rock loop; do not automatically roll back the map or campaign.

**Current behavior preserved:** no map rollback, objective reprioritization, campaign restructuring, or new percentage requirement was made.

**Operator decision:** DECIDED (AI-led). VIBE gains a scope clause: campaign-scale and endless systems must periodically route the player back through the score → smoke → 18s → 8s loop, and long-form objectives may not permanently displace it as the BAD IDEA. Mechanical enforcement (frequency, transport, coverage budgets) is deliberately deferred to the Wave 4 world-scale design session, where those relationships live. Spec language now, mechanics later — deciding enforcement numbers before the travel budgets exist would be the same missing-relationship mistake Wave 4 documents.


### OD-SMOKE-COVERAGE (OD-5)

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Question (operator, feel pass, day-2 save):** there is only one spot to smoke a rock — at what point does that change?

**Decision:** The Block remains the only UNCONDITIONAL smoke spot, permanently. Additional spots enter only as earned, conditional concessions granted by the v20 recognition system (THE REGULAR): a venue that reaches "conceded" tier tolerates the loop under its own condition (time of day, presence, phase). Cap: four concessions world-wide at full recognition, roughly one per district. Concessions distribute the loop; they never bypass it — the BAD IDEA still points, and the 18000ms/8000ms contract is byte-identical everywhere.

**Why:** it answers "what is success to a crackhead" mechanically — success is the neighborhood adjusting around you. It also converts the flagship Wave-4 travel defect (block-to-throne 8,396px vs ~4,455px of high) into the success arc instead of a transport band-aid: early game keeps the tight tether while the theme needs it; late game earns slack. Progression shaped like the arc itself, and the bleakest joke available — success measured in places that let you.

**Scope:** SPEC core-loop invariant amended to "only unconditional spot" (true of the current build — no concessions exist yet, so drift-check holds today). Full design in SPEC-V20-PACKET.md. No implementation in this commit.

### OD-HUD-CART-BOUNDARY (OD-6)

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Measured evidence:** HUD width followed the viewport breakpoint while the stage could shrink independently by height: `1280x300` produced a `400x300` game stage with the fixed desktop key ledger still present. On touch layouts, the four-button topbar measured `171px` while the ticker reserved `80px`, producing `91px` of overlap. The unique rideable cart at `(1100,1520)` sat only `13.416px` from BUSKER's center; the `60px` NPC-priority disc therefore covered the cart's entire `36px` use disc. THE BIG GUY and save/load set only `P.cartMounted`, while world rendering, guidance, and dismount also required `cart.mounted`, rendering both carts and removing the abandon path.

**Decision:** HUD placement is a function of the actual centered 4:3 game rectangle and enters a compact state at `520px`; touch ticker and topbar share one boundary. NPC-first interaction remains authoritative. The one rideable cart moves to the clear Marketplace anchor `(1000,1600)`, and `P.cartMounted` becomes the sole mount-state authority across every acquisition, render, hint, interaction, and save/load path.

**Preserved:** no NPC priority exception; no second rideable cart; no new save field; no cart stat, roadkill, damage, reward, achievement, status-timer, or 18000ms/8000ms change. Decorative cart husks stay non-interactive.

### OD-REGULAR-LEDGER (OD-7)

**Status:** DECIDED — AI-LED 2026-07-15 (operator veto standing)

**Question:** The packet names five repeated verbs but locks four future concession venues. None of those four currently exposes a successful `sell`; thresholds and repeat de-duplication are also unspecified.

**Decision:** v20 uses an explicit four-venue recognition allowlist and five-counter schema. Venue totals derive tiers at `3/8/15`. Free verbs credit once per source per venue visit; paid verbs credit once per successful option; full-high credits only at the existing high-to-crash boundary. `sell` remains a normalized, persisted, dormant schema lane rather than relabeling a trade or adding a fifth concession. Tier is derived, never saved.

**Voice/effect budget:** twelve venue-tier acknowledgments contain three clerical beats (25%). They change toast/feed/Q acknowledgment only. The encounter table's explicitly triggered first-counted `@blocklog` post graduates with the ledger; its other nine lines remain draft until cadence is specified.

**Preserved:** save key/version and all prior fields; cash/items/prices/factions/combat/status values; exact 18000ms/8000ms transition; four-concession cap; no recognition decay or reward path.

**Status note — 2026-07-16 (Fable / Claude Code, branch `v20-regular`):** SPEC-V20-PACKET item #2 (THE REGULAR) implemented. The `codex` mid-flight WIP (`1248cea`) was reviewed against packet section 1 and kept intact — `src/systems/recognition.js` plus its ten integration edits conform to the acknowledgment-only rule, the additive-save rule, and the 25% clerical share; nothing needed rewriting. OD-7 above originated in that WIP and is carried forward, not independently re-ratified — still operator-veto-standing. The one missing artifact, the permanent gate, was authored here as `tools/recognition-gate.mjs` and wired into `tools/run-gates.mjs` ahead of the runtime smoke. It asserts registry/threshold contract (4 venues, 5-lane schema, 3/8/15), the stranger→counted→furniture→conceded ladder via simulated paid verbs, zero reward-state leakage, free-verb per-visit dedup, wrong venue/source rejection, the full_high credit at the exact 18000→8000 boundary, no idle-frame decay, malformed-save normalization, and the save/load roundtrip. Full suite: 6/6 PASS. No timing constant, balance value, id, or sprite changed; `rock_bottom_v19.html` untouched. Branch pushed; not merged to main.

## Landing 3 extraction findings (2026-07-16, Fable / Claude Code, branch `v20-concessions`)

Things noticed while holding the smoke transaction during the I-ONE-LOOP extraction. Per the landing's standing order these are recorded, not fixed: the loop that came out is the loop that went in.

- The soap feed line (`smoked soap. tasted it. did it again.`) is venue-blind at all five spots. Kept byte-identical for I-SOAP-PARITY; if a venue-named soap post is ever wanted, that is a separate decision, not a drive-by.
- `P.cred += 1` per real smoke now applies at concessions too. It follows from smoking, not from *where* (I-NO-REWARD holds — the delta is identical everywhere), but the adjacency is worth a note: recognition pays nothing while the loop itself still pays one cred.
- `applyRep({ street: 1, spiritual: -1 })` is location-blind. Smoking in the park — a spiritual-faction zone — ledgers the same spiritual -1 as the block, no more. Identical everywhere by design; a location-aware rep ledger would violate I-ONE-LOOP.
- `completeIntroSmoke()` rides the transaction at every spot. It is unreachable pre-conceded in practice (the intro precedes any recognition climb) — by construction, not by guard.
- The smoke option disables on `rockedT > 0` but not on `crashT > 0`: chain-smoking through a crash was legal at the block and stays legal at concessions. Pre-existing; preserved for parity.
- `updateWorld` runs only in `playing` mode, so every world clock — sun, dog, choir, dryer — freezes while any menu or dialogue is open. The SPEC's "dog leaves while the menu is open" race is therefore unreachable in the current engine; the action-time re-check was installed anyway and is tested by direct state mutation in the gate.
- The real-smoke toast reports `shakes -50` even when shakes were below 50 and clamped at 0. The accounting line states the price, not the receipt. Pre-existing at the block; identical at concessions.
- The crash boundary's `+30` shakes (`update.js`) is the other half of the loop and was already single-site. Untouched.

### OD-CONCESSION-CLOCKS (OD-8)

**Status:** DECIDED — AI-LED 2026-07-16 (operator veto standing)

**Question:** SPEC-v20-concessions.md orders two new clocks (choir office hours, dryer mid-cycle) and a gate over all 16 condition combinations, but does not pin the choir clock's substrate, the cycle constants, the BAD IDEA trigger, or the tie rule's edge reading.

**Decision:** (1) Choir office hours are an independent authored clock — closed 90–150s, open 55s — not a `dayTime` window. Three reasons: the ratified flavor defines the hours by pitch, not sun ("b flat to b flat"); the hook audit's own standard says a predicate over an existing clock is a read, not a feature, and this landing owes two clocks; and a sun-coupled window would make park∧choir unreachable by construction, turning the SPEC's 16-combination gate matrix into theater for four of its rows. The office can hold b flat at 3am. It does. (2) Dryer: idle 50–90s, run 70s, mid-cycle is the run minus 15s margins — 40s of cover per ~2.2min cycle, ~29% duty. It bites. (3) Both clocks roll durations from a private persisted LCG, not `Math.random`: the runtime smoke runs the modular build in lockstep against frozen v19 on one shared seeded sequence, and a clock that ate from it desynchronized NPC dialogue parity (caught by the suite on first wiring). (4) BAD IDEA loop objective fires at rocks-in-pocket ∧ not-high ∧ shakes ≥ 50 (half the runway, ~60s before the cap starts collecting), placed under the intro, active office contracts, and every kingdom objective, above available office work, routes, and quests. (5) Conditions re-check at ACTION, once, stated in code. (6) ANY exact tie for nearest — block-vs-concession or concession-vs-concession — resolves to the Block. (7) The lanyard stays a line, not a flag, carrying the SPEC's own orchestrator decision forward.

**Preserved:** save key and version 10 (one additive `concessionClocks` key); every transaction value and its exact toast/flash/timing; Block-only royal static; zero reward from location; the four-concession cap; recognition thresholds and the Landing 2 gate untouched.

**Status note — 2026-07-16 (Fable / Claude Code, branch `v20-concessions`):** SPEC-V20-PACKET §2 implemented per SPEC-v20-concessions.md. The transaction extracted to `src/systems/concessions.js` `smokeRockAt()` — the only `rockedT = 18000` site in `src/`, gate-enforced structurally. Four conditional rooms behind `conceded` tier; two clocks authored, persisted, Q-readable; BAD IDEA targets only legal spots, ties to the Block; coronation provably Block-only — the gate check was verified RED (guard stripped → 4 failures) before it was trusted, and the single-site check was verified red against a planted duplicate. `tools/concession-gate.mjs` wired before runtime-smoke; suite 8/8 PASS. No timing constant, balance value, id, or sprite changed; `rock_bottom_v19.html` untouched. Branch pushed; not merged.

## Landing 4 measurement findings (2026-07-16, Fable / Claude Code, branch `v20-world`)

The world-relationship gate's first honest readings. Per the landing's standing order these are recorded, not fixed: the gate holds up the ruler; it does not get to like the answer. All distances straight-line lower bounds at 137.5 px/s walk (measured live).

- **The failing leg — route `scrap_gate ↔ ditch_gauge`: 8,274.6px = 60.2s, budget 8,250px = 60.0s. Over by 24.6px (0.3%), and straight-line is a lower bound, so the true walk is longer.** The endless route can assign these as consecutive stops once `throneDitchCleared` unlocks the ditch stop (post-campaign). This is the same arithmetic as the Wave-4 table's "worst direct two-leg sequence ≈16,398px": 8,274.6 (`scrap_gate↔ditch_gauge`) + 8,123.8 (`ditch_gauge↔pawn_sill`). The mandatory-to-finish pools (first two routes core-only; third route flag-free pool) pass comfortably — worst 3,982.8px, 48% of budget. The options are the operator's: move a stop, add an intermediate stop, ratify an authored exception with a register entry, or let the suite stand red as a standing debt. The gate does not choose.
- **Near misses worth knowing before anyone says "go wild" again:** `block → throne banner` (the emperor commute, mandatory) is 7,900.4px = **95.8% of budget**; `ditch_gauge ↔ pawn_sill` is 8,123.8px = 98.5%. One more map nudge outward and the campaign itself goes red.
- **Coverage is genuinely green:** with all four concessions earned, the worst map point (0,5600 — the southwest corner) is 4,671.2px = 34.0s from its nearest potential spot (the laundromat), 75% of budget. OD-5's concessions really do distribute the loop.
- **The day-1 floor is very green:** the farthest day-1 strip objective (quest `conductor`, the train yard) sits 2,072.4px from the Block — 25% of budget. The Block and one runway comfortably hold day 1.
- **RUNWAY-ROUTES-MANDATORY currently cannot fire** while the day-1 pool predicate is `x<2100 ∧ y<2100` (the maximum leg inside that box is under 3,000px). It is armed against the predicate changing, and the pools are sampled through the real roller (`rollBlockRoute`) rather than transcribed, so a predicate change moves the reading automatically.
- The bus is not measured: it is an optional one-way teleport, never assigned by the strip. If a future landing makes any bus trip mandatory, its return walk becomes a governed leg and the inventory must gain that family.

### OD-WORLD-GATE (OD-9)

**Status:** DECIDED — AI-LED 2026-07-16 (operator veto standing)

**Question:** SPEC-v20-world-relationships.md orders a gate over "mandatory route/campaign legs" and "~45s" coverage but does not pin which route legs are mandatory, the coverage ratio's derivation, the gate's suite position, or what to do with a leg that fails on day one.

**Decision:** (1) A leg is mandatory when the game assigns it as the standing BAD IDEA and the player cannot progress that lane without walking it — which includes rolled route legs over the full stop pool with unlock flags treated as potentially earned (the coverage clause's own "potentially", for the same reason: a reading must not flicker with progression state, and a gate row that can never fire is decoration). (2) The coverage budget is expressed as 45% of the measured runway, not a hardcoded 6,190px, so it scales if the withdrawal rate or walk speed ever legitimately changes; at shipped values it equals the SPEC's ~45s. (3) The gate runs LAST in the suite: it is expected to read red until the operator rules on its findings, and a standing world reading must never mask a regression in the seven gates that protect shipped behavior. (4) Budgets are derived from live measurement (walked speed cross-checked against the speed model; withdrawal measured standing still; cap measured against the clamp) — if the movement or withdrawal model drifts, the gate fails loudly rather than measuring with a stale ruler. (5) The failing `scrap_gate ↔ ditch_gauge` leg is reported and left standing. The budget was not widened; no content moved; no grandfather list was created — a grandfathered baseline is the same instrument-deletion as widening the budget, with extra steps.

**Preserved:** zero gameplay values — no timer, distance, spawn, price, speed, or table coordinate changed anywhere in `src/` this landing; every prior gate green (8/8 before the world reading).

**Status note — 2026-07-16 (Fable / Claude Code, branch `v20-world`):** SPEC-V20-PACKET §3 implemented per SPEC-v20-world-relationships.md. `tools/world-gate.mjs` wired last in `run-gates.mjs` (suite: 9). Leg inventory read through the live objective selectors (69 campaign legs, 175 mandatory-pool route legs, 253 full-pool route legs, 20 day-1 objectives, 19,780-point coverage grid, cart census). Red-verified before trusted: moved venue → COVERAGE fails naming the point; moved throne banner → RUNWAY-CAMPAIGN fails naming the leg; planted second cart → TRANSPORT fails; all restored green. Suite reads 8 PASS + world-gate's one honest failure naming `scrap_gate ↔ ditch_gauge`, its length, and its budget. Branch pushed; not merged.

## Landing 5 route budget (2026-07-16, Fable / Claude Code, branch `v20-world`)

- **OD-9's finding is resolved by constraining the generator** (SPEC-v20-route-budget.md, orchestrator decision). See the OD-9 status note below. The suite is 9/9 honestly green.
- Noticed, not fixed: a pool smaller than three stops has always produced an invalid route (`validBlockRoute` false), which `ensureBlockRoute` then re-rolls every guidance tick. Pre-existing, unreachable with the shipped table (day-1 pool is 11), preserved byte-for-byte per I-FILTERS-INTACT. If unlock gating ever makes a sub-3 pool reachable, that loop deserves its own look.
- Noticed, not fixed: the `player → first stop` leg remains ungoverned and ungovernable — the roller does not and should not know where the player is standing. The SPEC says this out loud; recording it here too so nobody later mistakes stop-to-stop coverage for the whole story.

### OD-9 status note — RESOLVED by Landing 5 (2026-07-16, Fable / Claude Code, branch `v20-world`)

The budget did not move. The content did not move. Nothing was grandfathered. `rollBlockRoute` learned the budget it always owed: after the same shuffle, each next stop is the first remaining candidate within the runway leg budget of the previous one — identical to blind first-three whenever first-three is legal (252 of the full pool's 253 pairs), and relax-to-nearest when no candidate is within budget, so the roller always returns three stops (I-ROLL-TOTAL), never null, never a spin. The budget is derived at run time in `routeLegBudgetPx()` — the literal 8250 appears nowhere in the tree — and the world gate certifies that derivation against the behaviorally measured world every run (I-NO-BUDGET-DRIFT), fails if they diverge, samples the real roller 10,000 rolls per pool configuration with chained `lastStopId` (zero over-budget assigned legs, zero nulls), and proves chain satisfiability instead of assuming it (min within-budget partners across the table: 21, at `scrap_gate`). Red-verified in both directions before trusted: constraint reverted to blind first-three → the gate fails naming `scrap_gate ↔ ditch_gauge` legs (69 assigned in 10,000 rolls); budget forced to a pathological 10px → every pick falls to the fallback, all 30,000 rolls still return three valid stops, and NO-BUDGET-DRIFT fires naming both numbers. The table pair itself still exists and is reported informationally as generator-excluded — the world was not redesigned for 24 pixels; the generator just cannot hand out the one illegal leg it contains. Worst assignable leg is now `pawn_sill → ditch_gauge` at 8,123.8px, 98.5% of budget.

### OD-STRUCTURAL-ROUTES (OD-10)

**Status:** RATIFIED — operator, 2026-07-16 (proposed by Fable / Claude Code after the operator named the silent-absorption hole in Landing 5's enforcement move)

**Question:** Once the generator filters illegal legs, a gate that measures generator output can no longer fail on world growth — the filter absorbs scope creep silently and a filtered world becomes indistinguishable from a clean one. The original ask was a headroom floor on the legal-pair fraction (99.6% at ratification); the proposal reframed it: protect the pairs, not the percentage.

**Decision:** Three structural invariants in `tools/world-gate.mjs`, all with derived thresholds, none invented: (1) **I-DEAD-STOP** — in every reachable pool, every stop keeps at least 1 + maximum-simultaneous-exclusions within-budget partners (3 for pools larger than three, 2 at exactly three). Below this floor the roller's relax-to-nearest fallback becomes reachable, and a firing fallback IS the generator assigning an over-budget leg — the one silent budget violation the constrained roller can still commit. The fallback must stay dead code deterministically, not probably. (2) **I-CO-ROUTABLE** — the legality graph over the full pool keeps diameter ≤ 2: every pair of stops, including excluded ones, can still share one three-stop route through some middle. The 2 is the number of legs in a route. Failure means the world has regionalized, and no ledger signature papers it — wanting regions is a SPEC change. (3) **I-EXCLUSION-LEDGER** — the set of over-budget table pairs must exactly equal a named ledger in the gate, each entry citing a register decision whose token must literally appear in this file; both directions fail (unratified exclusion = the world outgrew its table; vanished exclusion = stale ledger). The ledger tolerates no violation — excluded pairs are unassignable and the shipped game is legal; it converts the filter's silent work into an enumerable, signed list. It is fail-on-regression at single-pair resolution with names, which carries strictly more information than any fraction floor and fires earlier. The legal-pair fraction is printed as a human trend line, never thresholded.

**Ratified exclusions as of this entry:** exactly one — `scrap_gate ↔ ditch_gauge`, 8,274.6px straight-line against the 8,250px budget, excluded by the Landing 5 generator constraint (OD-9).

**Known limit, named at ratification (operator's order — in the gate header, not just here):** the signature check proves a signature exists, never that it was worth signing. REFACTOR-FINDINGS.md is append-only and an agent can append: an autonomous loop can grow the world, trip the gate, sign its own permission slip, and compile itself green. ORCHESTRATOR-NOTES entry #2's family; not fixable at this layer and deliberately not attempted. When the loop goes live, ledger growth is a human-review trigger — a process control, and the gate says so rather than implying it sees everything.

**Preserved:** zero gameplay values; the roller untouched by this addendum; the 60% budget itself unmoved — noting for the record the operator's own asymmetry: the three new thresholds are derived; the 60% at the center of the wave is chosen. Known, not moved.
