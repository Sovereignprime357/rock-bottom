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

## OPERATOR PLAYTEST FINDINGS — 2026-07-16 (reported from live play, verified in source)

Two real defects and one scope reading, from the operator playing the deployed build. **Both bugs
were reported by feel and both are exact.** Recorded here, not fixed — the sock exploit is
currently the operator's only fast path to late-game content and removing it before his feel pass
would cost more than it buys.

### F-SOCK — the pawn shop prints money (`neighborhood_a.js:258-265`)

**Operator's report:** "at the pawn shop, and I believe at the junkyard, you can sell socks just
fine. But for some reason it lets me just keep selling socks... even if I don't have a sock in my
inventory. It will let me sell like 200 something of them. And then it'll say that the pawn shop's
out of inventory."

**Verified. `PETE_CAP = 200` — his "200 something" was exact.**

`'pawn a sock. $1.'` has **no `disabled:` guard and no decrement.** It is `P.cash += pay` with
nothing consumed. **There is no sock anywhere in the inventory system.** Every sibling option in
the same menu does it correctly:

| option | guard | consumes |
|---|---|---|
| sell 1 PURE COPPER | `disabled: P.copper<1` | `P.copper--` |
| sell license plate | `disabled: !P.inventory.find(i=>i.id==='license')` | filters it out |
| sell junk | `disabled: !P.inventory.find(i=>i.id==='junk')` | removes exactly what Pete paid for |
| **pawn a sock** | **none** | **nothing** |

It is not unbounded — `tryPay` clips against Pete's daily cash — so it is **$200/day from nothing**,
which is not infinite but does trivialize the early economy. **The label promises an item
transaction against an item that does not exist.**

**Open question for the operator, not for a builder to invent:** is the sock supposed to be an
item you find, or is "you always have another sock" the joke? The VIBE-consistent version is
probably *you have the two you are wearing* — pawn both and you are out until you find more. That
is a taste call. **Do not resolve it in a fix commit.**

**The class, which matters more than the instance:** this is the infinite-resource-loop family.
Nothing gates it. A vendor gate should assert that **every cash-paying option either guards on an
inventory item and consumes it, or is registered by name as a deliberate no-item payout.** If the
sock is broken, the question "what else is" currently has no mechanical answer.

### F-GHOST — 28 buildings you can walk through (`update.js:84-95`, `world.js`)

**Operator's report:** "since the map was expanded so much, there's a ton of new buildings, but a
lot of these buildings have no boundary markers. Like, you could just walk over top of it instead
of coming up to it and hitting it."

**Verified, and the ratio is worse than it sounds:**

- The collision loop iterates **`BUILDINGS` only** — `for (const b of BUILDINGS) { if (!b.solid) continue; ... }`
- `BUILDINGS`: **25, all 25 solid.**
- `LANDMARK_FACADES`: **28, none solid — and never entered into the collision loop at all.**

**There are more walk-through structures in this world than solid ones.** The map expansions added
*facades*, which are a render-layer concept, and nothing ever connected them to collision. The
operator noticed the exact seam between "the parts that look and behave like a city" and "the
parts that are painted on."

**Not necessarily all a bug** — some facades may be intended as unreachable background scenery
behind roads. **That distinction does not currently exist in the data**, which is the actual
defect: there is no way to tell an intentionally-flat backdrop from a building somebody forgot to
make real. **The fix is a registered distinction, not a blanket `solid: true`.**

### F-BARREN — the operator's 20–25% empty-map reading (NOT verified — measured the wrong thing)

**Operator's report:** "there's probably twenty percent of the map, twenty five percent of the
map that's just barren wasteland. Like, there's nothing there. It's just grass."

**A zone-coverage grid says 75.2% of the map sits outside any named zone — but that is not the same
claim** and must not be reported as if it were. Roads, connective tissue, and deliberate negative
space are all unzoned without being barren. **"Barren" is a felt property and this measurement does
not touch it.** Recorded as unverified. **The operator played it; the grid did not.**

### The scope reading these three point at

The world gate now says the map is at its **distance** ceiling — the emperor commute sits at 95.8%
of the runway budget and `pawn_sill ↔ ditch_gauge` at 98.5%. **The operator's instinct is to add
break-ins, a live train yard, tool-gated and cred-gated entry, and to fill the empty quarter.**

**Those are compatible, and it is worth saying plainly: density does not cost runway.** Filling
existing space makes the walk worth taking; it does not lengthen the leg. **For a world already at
its walkable limit, "stop expanding, start filling" is not a compromise — it is the only remaining
direction that the instrument will allow.** His feel and the gate agree, which is rare enough to
write down.

### OD-HONEST-PHYSICALITY (OD-11)

**Status:** DECIDED — AI-LED 2026-07-16 (operator veto standing)

**Question:** Which of the 28 facades are architecture versus scenery under the contract's reachability rule, and what does the requested NPC/cop traversal smoke mean when the cited source line is not actor collision?

**Measured evidence:** Movement has no terrain or zone walkability mask. A player-clearance flood from spawn reaches every facade center and all four exterior sides of all 28. Zero facades overlap a road, ground path, rail, existing building, NPC spawn, smoke spot, or mandatory anchor; all four renderer kinds paint filled structures, not murals. Twenty-one render a south entrance; ten generated entrances miss the existing centered aperture. Separately, `update.js:723` is projectile collision. `npc_ai.js` imports no structure table and directly mutates every actor position, so NPCs and cops have never shared building collision. A fresh-runtime overlap audit also finds eight deliberately embedded legacy actors: Tony in CORNER, Pete in PAWN, Father O'Malley and his son in CHURCH, Barb/the laundromat lady/Karaoke Mike in LAUNDROMAT, and Skid Sherri in a SHACK. Blind actor ejection would silently move eight canonical interaction anchors while claiming to fix facades that contain none of them.

**Decision:** (1) All 28 current facades are `solid:true`; zero are registered flat. `flat` remains available only through a non-empty registered reason, never as a quota or a way to save a route number. (2) The 21 entrance-bearing facades use `doorGap:true` and receive a centered painted aperture; the seven storefronts have no visible door and no gap. (3) One merged `STRUCTURES` set and one scanner own player, projectile, load, NPC, and cop collision. Ordinary obstructed actors use stable corner detours; charges stop both axes at the wall and enter their existing cooldown. (4) Saves inside new solids eject deterministically to the nearest clear boundary. (5) Each of the eight actors deliberately embedded in a legacy id-less building declares that exact building index on its source actor record and receives a one-way compatibility exit only from that footprint; a familiar id in the wrong building ejects. Newly-solid facade overlap always ejects, including dynamic cops. (6) The merged resolver preserves the legacy south-door predicate and its full-target-Y x-axis behavior. (7) The real-path ruler uses the shipped arbitrary-heading analog control with framewise collision replay and legal action regions for unreachable selector centers; WASD/octile cost is a separately reported sensitivity.

**Preserved:** no building/zone/prop/NPC/interaction additions; no route stop, venue, campaign anchor, world bound, walk speed, withdrawal rate, runway ratio, reward, save key/version, or 18000ms/8000ms timing change. `rock_bottom_v19.html` stays frozen. Any traversal-budget crossing is a finding recorded below and fixed nowhere in Wave 4.1.

### F-HONEST-TRAVERSAL — the straight ruler was optimistic, but no newly legal leg crossed

The collision-aware ledger traversed all 69 selector-derived campaign legs and all 252 generator-assignable route pairs before (`BUILDINGS` and the pre-v21 axis resolver) and after (the merged 53-structure authority). The complete row-by-row report is `node --no-warnings --experimental-vm-modules tools/solidity-gate.mjs --full`.

| Reading | Straight | Baseline traversal | v21 traversal | Wave 4.1 delta | v21 minus straight | v21 budget use |
|---|---:|---:|---:|---:|---:|---:|
| kingdom emperor: Block → throne banner | 7,900.4px | 7,939.4px | 7,947.8px | +8.5px | +47.4px | 57.802s / 96.337% |
| route `pawn_sill ↔ ditch_gauge` | 8,123.8px | 8,123.9px | 8,167.6px | +43.7px | +43.8px | 59.400s / 99.001% |
| largest campaign delta: canal office → survey | 1,244.8px | 1,450.5px | 1,555.9px | +105.5px | +311.1px | 11.316s / 18.860% |
| largest route delta: `motel_no ↔ canal_gauge` | 2,605.1px | 2,605.1px | 2,785.1px | +179.9px | +179.9px | 20.255s / 33.758% |
| ratified generator exclusion: `scrap_gate ↔ ditch_gauge` | 8,274.6px | 8,282.8px | 8,324.5px | +41.6px | +49.8px | 60.542s / 100.903% |

**Finding, fixed nowhere:** zero assignable route or campaign legs newly cross 8,250px, but `pawn_sill ↔ ditch_gauge` retains only 82.4px / 0.600s of analog headroom. The already-excluded `scrap_gate ↔ ditch_gauge` pair worsens by 41.6px and remains governed by OD-10; Wave 4.1 does not move it, widen the budget, or declare architecture flat.

**Control sensitivity, also fixed nowhere:** literal unobstructed WASD/octile lower bounds are already 8,404.6px (101.874%) for the emperor commute and 8,614.7px (104.420%) for `pawn_sill ↔ ditch_gauge`, before obstacle detours. The canonical Wave 4.1 collision delta therefore uses the shipped arbitrary-heading analog control and reports WASD separately rather than pretending the packet's straight-line percentages describe keyboard travel.

## F-VIBE-ART — the tone bible describes a game that stopped existing

**Trigger:** operator asked for better character sprites ("avatars do look a little weak... it
would be incredible to see that all look like legit game character sprites"). Before speccing it,
checked whether `VIBE.md` governs art the way it governs voice. **It does. And what it says is
false.**

### What VIBE.md §Visual aesthetic currently claims, against what the code does

| VIBE.md says | Reality | Verdict |
|---|---|---|
| L147: *"Emoji used unironically for NPCs and props. **This is the look, not a placeholder.**"* | **8 emoji lines in all of `src/`**, all in UI chrome (`hud.js`, `runtime_ui.js`, `communications.js`). NPCs are **373 sprite keys** of hand-authored pixel art. | **FALSE** |
| L150: *"Solid buildings: filled rect + 3px dark border"* | The render layer is **3,912 lines across 10 modules** — `structures.js` 523, `props.js` 621, `sprites.js` 919, `landmarks_a/b` 402, `tiles.js` 315, plus light masks, glow caches and a fog sheet. | **FALSE** |
| L145: *"Pixel art is CHUNKY, not refined. 16x16 logical, scaled 2x."* | **True — of characters only.** 16×16 grids drawn at 32×32 through one call at `actors_weather.js:136`. The environment obeys no such ceiling. | **HALF TRUE, and that half is the bug** |

### The finding

**The art drifted past VIBE many versions ago and nobody noticed, because nothing checks whether
the seed is true.** `corpus-gate` protects `VIBE.md` from *shrinking*. **Nothing protects it from
being wrong.** A gate that keeps a false document intact keeps a false document intact.

**This inverts the operator's request.** He is not asking to violate the aesthetic. **The
aesthetic was abandoned by the environment and the characters are the last thing still obeying
it.** The world got a 3,912-line renderer with atmospheric lighting; the characters got 373 tiny
grids and one `drawImage`. **That mismatch is what reads as "weak" — not the sprites themselves.**

### Why this is the most dangerous thing in the corpus right now

`README.md`'s read order tells every fresh agent: *"**VIBE.md** — internalize the voice before
doing anything else."* **An agent sent to improve the art, obeying the tone bible exactly, would
build emoji NPCs and filled-rect buildings.** It would be following orders. It would make the game
substantially worse. And every gate would stay green, because **no gate reads a document for
truth.**

**This is entry #11's shape at corpus scale.** A false premise, unread, load-bearing, with hands.
Entry #11 was one line I never opened. **This is a whole section of the seed, and the seed is what
every future version reproduces from.**

### Not resolved here — this is the operator's

`VIBE.md` is the soul and the tone bible is his. **Correcting a stale art section is not the same
decision as the "single HTML file" retirement** — that rule was obsolete, this one is **false**.
Retirement needs a reason; a false claim only needs a correction. **But it is still his hand on
the seed, and an AI silently rewriting the tone bible is exactly what `corpus-gate` exists to make
impossible.**

**Proposed, veto standing, not written:**
1. §Visual aesthetic gets corrected to describe the game that exists — sprites not emoji, a real
   renderer not filled rects — with the stale claims **retracted in place, not deleted**, the way
   `SPEC-refactor-modularize.md`'s fabricated prerequisite was.
2. The 16×16 character ceiling gets **decided rather than inherited**. It is currently the only
   surviving line of a rule the rest of the game abandoned, and it is load-bearing for the
   operator's complaint either way — keep it deliberately, or raise it deliberately.
3. **A `vibe-truth` gate is NOT proposed, because it cannot exist.** No mechanical check reads
   prose for truth. This class is ungateable, same as entry #2. What is available is a habit:
   **when the corpus makes a checkable claim about the code, check it.** Three of them were false
   and one command each proved it.

**Resolution note — Wave 4.2 / OD-12, 2026-07-16:** the operator corrected VIBE's Texture section
and raised the complete character ceiling. The final-diff audit then found that the first correction
had not propagated into `AGENTS.md`, VIBE's later NPC-rendering bullets, or the active clauses in
`SPEC.md`; a future agent would still have been ordered to restore 16×16 emoji actors. Those
governing documents now explicitly name 93 32-logical character bases, eleven 16-logical
environment holdouts, and the supersession of historical version ceilings. This is exactly the
ungateable prose-truth class described above: `corpus-gate` stayed green while the seed contradicted
itself. The independent read, not the suite, caught it.

## F-SPRITE-CEILING — 4× the authored pixels, zero change to the actor footprint

### What landed

All 93 character bases / 373 exact cache keys now declare and author a true `32×32` logical grid.
The cache output remains `32×32`, so the render scale becomes 1:1 without changing any destination
rectangle. The migration landed in four reviewable art checkpoints: shared dual-size machinery,
the complete player composite, 47 humanoid/state bases, then creatures and incident props. Eleven
environment cache bases remain explicitly `16×16` and use the same production rasterizer, so dual
size support is exercised by the running game rather than preserved as dead compatibility code.

The player unit was larger than the SPEC's gear warning: `player`, `playerhi`, both attack states,
15 gear bases, nine weapons, four route patches, the attack smear, and the cart underlay all share
the same unchanged 32px actor rectangle. Moving only player + gear would have left legal but visibly
misregistered layers. All of them moved together.

### False premises found before and during implementation — fixed nowhere by pretending they were true

- **F-AMENDMENT-DID-NOT-PROPAGATE.** The amended WHAT ordered all 93 bases, but the acceptance list,
  screenshot stop, and THE TRAP still ordered a player-only landing. The operator's later and
  explicit all-roster ruling governed. The stale clauses are now retracted in place rather than
  silently deleted.
- **F-I-STILL-PIXEL-SUBPIXEL.** The existing camera, player draw, cart/trail effects, and world
  motion already admit fractional positions. “No sub-pixel placement” could not be made
  retroactively true without changing shipped motion. Wave 4.2 adds no fractional grid geometry,
  preserves every actor draw expression byte-for-byte, and keeps smoothing disabled.
- **F-PALETTE-ALREADY-CLEAN.** The grandfathered palette corpus already contains colors broader
  than the short VIBE orientation list, including pale accents and blue outside the three authority
  palettes. Recoloring the whole game was not authorized. The gate freezes the exact shipped corpus,
  rejects pure white / literal bright blue misuse, and requires a separately audited snapshot for
  any future palette change.
- **F-BARE-16-COUNT.** The packet said 124 bare `16`s across `src/`; the branch contained 140. The
  warning was still directionally correct: only the sprite toolkit and its callers were
  parameterized. No blind replacement occurred.
- **F-FALLBACK-SCOPE.** The cited `_0` fallback is the NPC pose path, not a universal cache lookup.
  The gate therefore pins the complete 93-base grammar directly instead of assuming the fallback
  protects or threatens every key family in the same way.
- **F-ANCHOR-SCOPE.** NPCs are bottom-centered; the player keeps its shipped `P.x-2, P.y-4` draw
  expressions. The invariant is the exact destination expression and rectangle, not a new common
  anchor invented for the gate.

### The gate boundary and the eye reading

`tools/sprite-gate.mjs` proves declarations, exact key/frame grammar, nonblank frames, 16/32
coexistence, valid palette indices, 32px outputs, all 14 character-cache draw destinations, the
palettes actually consumed by every character and environment cache key, no gradients, and no
smoothing. Eight direct modes forced it red independently: undeclared base, invalid `24`, 372-key
cache, replaced player frame, present-but-blank player frame, forbidden character palette,
forbidden environment palette, and changed destination geometry. The last four hardenings followed
an independent audit demonstrating that key count alone could congratulate an empty canvas, named
palette exports omitted inline/environment consumers, and actor-only draw hashing omitted the
attack/incident paths. It cannot prove that any sprite is good art, and says so in its own PASS
output.

The browser atlas and live-world pass found three concrete misses before delivery: the mattress
read as an envelope, the possum read as an appliance, and OLD SCHOOL BRUTUS did not separate enough
from BRUTUS. Their silhouettes were revised. The old pothole generator also produced identical
mouth frames because two tokens resolved to the same palette index; the three replacement poses are
visibly and structurally distinct.

**Honest weak list for operator review:** MAYOR'S COUSIN remains the least specific humanoid and
depends heavily on lapels/pins; the AirPod and priest-collar layers are necessarily tiny at the
unchanged 32px footprint; the mattress remains the most context-dependent incident prop even after
the quilt/springs pass; horse cop compresses rider and horse into one legally unchanged rectangle;
and the attack smear / bottle fragments depend on dark-street contrast. These are visual findings,
not permission to move hitboxes or add colors under a green suite.

### OD-CHARACTER-CEILING (OD-12)

**Status:** RATIFIED — operator, 2026-07-16; visual veto standing.

**Question:** Keep the inherited 16-logical character ceiling, stop after one player proof, or use
the unchanged 32px destination rect to re-author the complete roster at the world's native pixel
grid?

**Decision:** Raise all 93 character bases / 373 keys to explicit 32-logical art. “Go wild” spends
density and taste, not map runway. Preserve exact screen rectangles, anchors, hitboxes, identity,
key grammar, palette corpus, timing, and the frozen v19 floor. Land reviewable commits. Keep the
shared renderer genuinely dual-size through eleven explicit 16-logical environment sprites. Green
means the runtime and art machinery survived; only the operator's eye can accept the art.

**Preserved:** `rock_bottom_v19.html`, save key/shape/version, `18000ms` high, `8000ms` crash,
movement and combat values, world geometry, interactions, NPC identity, actor hitboxes, draw
destinations, cache key grammar, and the existing color corpus.

## IMPL-GRAPHICS-P1-01 — one frame registry, opt-in emissive semantics, visual-only fire

**Status:** implementation decision record, 2026-07-19; not an operator-ratified OD. The operator's
visual veto and Phase 2/3 stop remain standing.

**Decision:** extend the shipped light machinery through one reused `ACTIVE_LIGHTS` frame buffer.
Static `WORLD_LIGHTS`, lamp props, burn barrels, live cops, and the player ember normalize there;
mask holes, cached glows, emissive cores, and nearest-light AO consume the same rows. Broad ambient
fields explicitly do not cast a directional shadow.

Palette indices `2` and `7` are emissive only on an allowlisted emitter-capable sprite base. They
cannot be reinterpreted globally: the grandfathered 94-base corpus uses both indices for ordinary
faces, clothes, paper, and trim. The normal grids, palettes, keys, and `SPRITE_CACHE` remain the
authority; `SPRITE_EMISSIVE_CACHE` is a transparent initialization-time derivative.

The four burn barrels are visual-only `WORLD_DECOR`, not `PROPS` or an interaction system. They add
no collision, damage, warmth, loot, save state, or verb. The Phase 1 acceptance gate stays beside,
not inside, `run-gates.mjs`, preserving the operator's exact 18-gate runner while still giving this
bounded visual wave a red-tested contract.

**Preserved:** Canvas 2D, pixelated world rendering, eight-entry palettes, sprite-gate's 94/377
snapshot and 14 destinations, gameplay geometry/state/random order, frozen v19, and the Phase 2/3
operator boundary.

## OD-3D-DIRECTION — low-poly 3D direction received (2026-11-18)

**Status:** operator-requested direction; platform/perspective/engine and implementation amendment
remain open. This entry does not retroactively alter an earlier decision.

**Operator request:** "Go into this repo, read the lore and corpus understand the game. I want to
build this out as a 3d low poly game similar to the graphics of the game schedule 1".

**Executed:** reviewed the corpus against the v22 runtime, ran the unchanged 19-gate baseline, and
captured `SPEC-3D-TRANSITION.md`. The architectural recommendation is a separate native 3D project
with explicit behavior fixtures and new assets, rather than an implicit change to the active
browser entry. First-person Windows/Godot/Blender is a recommendation, not an operator ruling.

**Scope interpretation:** the later user instruction authorizes the new low-poly visual direction.
The old sprite rules still govern the shipped 2D build; they do not prohibit investigating the
requested port. No code, engine dependency, asset pipeline, save migration, or 3D runtime has been
introduced in this session. Implementation must capture its own concrete scoped amendment first.

**Preserved:** VIBE's voice and identity, frozen v19, active browser source, current save namespace,
all current gate definitions, and the distinction between research proposals and shipped content.

## OD-3D-PLATFORMS — first-person desktop, browser secondary (2026-11-18)

**Status:** operator selected. Exact follow-up: "yes first person desktop. playable in the browser
would be nice as well". This resolves the open platform/perspective question in OD-3D-DIRECTION.
The native game is primary; one shared-source browser export is desirable, not permission to
silently sacrifice the desktop target or replace the existing root browser release.

## IMPL-3D-SLICE-01 — scoped engine and first-loop implementation (2026-11-18)

**Status:** executed technical decision within the requested direction, not a claim the operator
personally selected each engine setting. Captured in `SPEC-3D-SLICE.md` before generation.

**Decision:** isolate the first playable in `game3d/`, use the already available official Godot
4.5.1 stable with GDScript, Compatibility rendering and single-threaded Web export. Source-authored
mesh kits keep assets original and reviewable; Blender is optional for later replacements.
Native audio caches generated waveforms. Native file and web async `window.storage`/IndexedDB
adapters share a new schema/namespace and never touch the v22 save. Engine/templates/cache/builds
remain ignored; repeatable export scripts and original source are committed.

**Boundary:** bounded deterministic subset economy, no new NPC identities, no full v22 parity
claim. Both normal loop timers remain exact; simulation and scene tests exercise production
methods. Browser export is built, but its UI playthrough remains unverified after Computer Use's
URL-identification safety stop. Native rendered evidence is separate and completed.

**Preserved:** original `index.html`, all `src/` gameplay, frozen v19, existing 19-gate definitions,
all prior append-only decisions, VIBE identities and the distinction between build proof and
operator acceptance. Next parity work is explicitly listed in DELEGATION and the slice README.

## IMPL-3D-ART-01 — neighborhood materials, cast and static batching (2026-11-18)

**Status:** executed under the operator's request to keep improving graphics, textures, assets,
characters, buildings, streets and NPCs while away from the PC. Spec captured before generation
in `SPEC-3D-ART-PASS.md` on `codex/3d-neighborhood-art-pass`.

**Decision:** original deterministic 128px material tiles with mipmaps, original source-authored
mesh detail and bounded pivot gestures. World tiles use world coordinates; character cloth/skin
use object coordinates. A conservative construction-time batcher merges compatible static mesh
leaves, including palette tints baked into sRGB vertex colors. The neutral shader carrier adds
no visible palette color. Material flags, shadows, normals, collision, labels and moving pivots
retain their roles. Unsupported/transparent/tagged geometry remains independent.

**Reason:** readable surfaces and resident silhouettes need more detail than the first proof,
but hundreds of tiny individually submitted parts do not scale. Measure the same camera before
and after, and report an art/idle stress separately from full AI. A source fixture tests actual
triangle/color preservation, not only node counts. Day/night sky updates throttle to four per
simulation second and skip constant plateaus.

**Scope:** existing six identities and transactions; no new economy, campaign, save schema,
actor identities or 2D runtime changes. Lurch's short hit reaction now advances on active
simulation time, so visual motion respects pause. Public GitHub Pages remains the existing
release; local Windows and Web exports are the review artifacts for this pass.

## IMPL-3D-INPUT-01 — asynchronous browser capture and menu recovery (2026-11-18)

**Status:** executed on `codex/3d-browser-menu-fix` for the operator's blocking menu-loop report.
The behavior contract was amended in `SPEC-3D-SLICE.md` before code changes.

**Cause:** the Web engine reports actual pointer lock, not a pending request. Resume requested
capture, then the next physics tick reopened pause whenever capture was still absent. Refusal
made the loop permanent. Escape could also toggle back into play after lock-loss already paused.

**Decision:** observe successful acquisition per play session; only a subsequent loss pauses.
Never retry capture from physics. Web Escape pauses only, and deliberate Continue requests
capture once. Right-drag look and uncaptured left-click combat preserve play where capture is
unavailable. True focus loss and modal simulation pause remain intact; late lock is released
while a modal stays open. The native capture behavior is retained.

**Build correction:** normal browser refresh demonstrably retained the old `index.pck` even
after the new export. The build now copies game data to a SHA-256-named pack and updates the
supported `mainPack` and file-size config. No save-key, engine, hosting or 2D runtime changes.

**Evidence/boundary:** live in-app browser entry/movement/menu-exit proof and 38 additional
production scene checks. Browser event-order permutations and right-drag math are exercised by
the native scene gate; that does not claim every browser grants pointer lock. Full browser
gameplay/save acceptance remains separate. Details: `reports/2026-11-18-3d-menu-fix.md`.

## IMPL-3D-ART-02 — connected characters and coherent streets (2026-11-18)

**Status:** executed on `codex/3d-character-street-polish` under the operator's request to bring
graphics/textures, particularly characters, buildings, streets and NPCs closer to Schedule I.
Contract captured first in `SPEC-3D-CHARACTER-STREET.md`.

**Decision:** original authored cross-section meshes with selectively softened normals, coherent
face/nose/hair/body surfaces and distinct resident shapes. Keep exaggerated four-to-five-head
caricature proportions for recognition instead of forcing uniform realistic anatomy. Fit eye,
mouth, clothing and animal details onto those forms; retain every actor origin, rig API, identity
and bounded animation. Architecture gains deep bays/trim/awnings, varied roofs, smaller mounted
signs and grouped lived-in edges. Streets gain coherent crossing/repair/drain details. New blockers
have collision; elevated/flat decoration must not invent ground exclusion zones or cast floating
slab shadows.

**Materials/rendering:** original cached mipmapped neutral tiles with periodic smooth wear,
smaller masonry courses, restrained skin grain, cream sunlight/slate fill and 4x MSAA. Existing
Compatibility rendering and static batching remain. The before sample uses 2x MSAA; quality
changes are declared in the comparison. No new NPC identities, economy, save schema, tutorial,
external art assets, 2D runtime edits or claim of full 60-agent AI performance.

**Review:** day/night eye-level and six close-up portraits caught a reversed awning pitch,
floating shadow-casting puddles, detached moustache pieces and Pete's collar/jaw overlap; fixed
before handoff. Static review caught a shelf exactly on the ground-clearance cutoff; raised it
5cm with its contents. Production gates preserve routes, transactions, menu exits and loop
timing. Full evidence and measured limits: `reports/2026-11-18-3d-character-street.md`.

## IMPL-3D-FULL-01 — bounded full-port foundation (2026-11-18)

**Status:** executed foundation on `codex/3d-full-port`; full port remains active. User explicitly
requested the full pixel game, higher-poly original characters and sustained bounded-agent work.
`SPEC-3D-FULL-PORT.md` supersedes only the old slice scope, preserving the2D/frozen references.

**Architecture/content:** source-pixel/millisecond state and shared resources; weakly composed
subsystems; immutable provenance-checked JSON; manual semantic callback ports. All32 systems
and585 serialized function omissions have explicit ledger rows. Native/Web stay Godot4.5.1
Compatibility with local original art. No JS runtime is embedded. Audit coverage is not gameplay.

**Spatial/timing adaptation:** .04m/pixel and5.5m/s base speed preserve137.5px/s travel; physical
routes must pass60s base-walk constraints. Body radius.48m preserves source24px width, with
documented depth adaptation. Fixed60Hz withdrawal preserves per-frame RNG/iframe semantics
across render rates. The core partitions high/crash/day boundaries without time loss.

**Saves:** schema2 remains separate from2D. Schema1 resources survive; obsolete slice coordinates
relocate explicitly to the full Block. Collected IDs retain a receipt rather than claiming
unrelated full-world pickups. Tagged migrated junk/food stacks preserve every unit through
source record-based consumers. Safe JSON normalizes StringName keys/values to strings; tests
protect dynamically assigned tool-locker ownership. High/crash ephemeral save reset is explicit.

**Hands:** actual-travel gait and bounded look sway, articulated relaxed fingers, alternating
punches and success-only gesture acknowledgements. Damage/cooldowns remain in gameplay. Native
visual correction restored fist clearance beyond the cuff and connected props to the grip.

**Evidence/limits:** foundation runner12/12 and original19/19,44 independent source fixtures,
native real-time loop/save tour and browser controls; details in the foundation report.
Full world, complete cast/AI, all domain systems and whole-game native/Web acceptance remain
required before the persistent goal can be complete. Public deployment is unchanged.

## IMPL-3D-FULL-02 — full world and composed domain foundations (2026-11-18)

**Status:** executed bounded checkpoint on `codex/3d-full-port`; full port remains active.
Contracts: SPEC-3D-WORLD-BUILD, CHARACTER-ROSTER, ECONOMY, COMBAT, RUNTIME and PHYSICS-ADAPTER.

**World/physics:**53 standing structures,193 props and23 zones preserve source geography.
Authored ground openings resolve source-embedded services; real shape casts and rays validate
consumer access. Source bounds clamp intended positions before collision. All321 campaign/legal
route pairs pass physical sweeps at base5.5m/s, worst59.396s. The real fixed-step controller takes
59.402s on the critical path without stuck corners. Global planning is not a per-frame AI path.
Low pickups, strict44px office reach and actual vendor/smoke access also pass the composed230-check
consumer test.

**Characters:** six original skinned identities, up to26 bones and four normalized influences,
cached GPU geometry and independent pose state. Source identity and coat-state geometry remain;
finger ownership separates palm/finger/thumb/arm chains, avoiding deformation contamination.
Native pose review required a fitted front apron sheet over Pete's belly. Full63-cast parity is
still pending and cannot be inferred from these six models or the identity ledger.

**Domains:** live one-use action capabilities, exact source inventory record semantics, actual
core vendors and a single model composition. Movement uses source speed/status modifiers;
fixed-step timers and collision results remain authoritative. Save events coalesce only after
all domain consequences; malformed restore envelopes cannot erase an active Runtime session.

**Combat adaptations:** source rotated first-person melee, physical wall-first contacts and swept
projectiles, unchanged weapon/reward/archetype governors. Brendan's verified ReferenceError is
explicitly repaired to finish intended badge/cash/faction/achievement/save outcome; original
failure is a separate fixture. Preserve shipped any-ordinary-fists-kill pipe reward. Cosmetic
RNG no longer shifts gameplay rolls. Special deaths require an atomic capable domain handler.
No generic death reward substitutes for unfinished boss/campaign systems.

**Evidence/limits:** original19/19; expanded3D22/22 including2870 combat checks/63 source fixtures,
585 economy checks/23 source fixtures,159 rig checks,55 Runtime and21 adapter checks. Day/night
world captures62 and native rig captures58. Report contains gate output, files and selected images.
Production full-cast AI, remaining systems, full scene, exports and whole-game native/Web tours
remain required. No completed parity feature or full60AI performance is claimed.

## IMPL-3D-FULL-03 — Full scene, cast and source domains (2026-11-18)

**Status:** executed bounded work on `codex/3d-full-port`; full-port goal remains active.
Contracts: SCENE-COMPOSITION, CHARACTER-ROSTER, BOSSES, RESIDENT-DIALOGUE,
QUEST-DIALOGUE, STREET-DIALOGUE, RHYTHM, ROBBERY, DAY-SYSTEM, COMMUNICATIONS,
TRAVEL and ACTOR-NAVIGATION. These exceptions apply only to game3d.

The full scene uses one GameState/Runtime and real source actor/domain owners.
Full-state persistence has its own namespace; old slice saves are read only as
migration fallback. Bad envelopes and blocked restored Fallen placement cannot
replace live progress. Source menus use one-use capabilities and a scene callback
generation; explicit returned domains own nested Travel/Karaoke menus. Native
capture refusal retains fallback movement and deliberate menu exits.

Original cast expansion uses72 templates to represent63 canonical rows; site-only
identity resolution remains separate from actor aliases. Real authoring includes
hand/prop contacts and seated/inert assemblies. View clocks respect hitpause.
Distant ambient gestures may use the existing every-third-call presentation
cadence; authoritative actions, hurt/death/coat changes remain immediate. Exact
bone transforms/coat state skip redundant setter calls without approximate poses.

Robbery retains the source allowlists,60s world cooldown and2/day sink governor.
Raw dialogue HP/stun is not substituted for actual Travel death/arrest lifecycle.
Quest auto-delivery completes its source current-step AI/projectile/boss work
before future active steps pause. Crown positions are unchanged and physically
reachable. All new RNG/economy fixtures execute unchanged active JavaScript.

P14-PHYSICAL-DEFER: required day owners preflight before paid sleep. Chosen source
actor/cash payloads that cannot be placed enter a bounded normalized saved queue;
retries do not reroll/reward, and no invisible model actor is inserted. Natural
time is not stalled by physical placement failure. Real Campaign remains required
before production Day installation. Source dawn news precedes day7 silence through
synchronous Communications publication. Session-global feed/props preserve source
fresh/load retention; garbage clears looted state but not other tips jars. Source
traffic pitch RNG is retained where it affects later source event selections.

Physics caches certify exact positive origin queries only within the same render
and physics frame and geometry revision. Body/height/epoch/collider changes clear
certificates. Casts, endpoints, contacts and line of sight remain actual queries.
Day cash staging uses bounded capsule/low-target visibility tests; wall-blocked
recovery defers instead of moving a pickup through geometry.

Full Windows/Web export presets use Godot's native custom-feature main-scene
override and separate output directories. The default slice and public2D hosting
are unchanged. Full-game parity and60AI performance are not inferred from passing
model tests or source data. Native actual60 remains diagnostic until measured.


## IMPL-3D-FULL-04 — Shared activity owners and live campaign composition (2026-11-18)

Scope: continued operator-authorized full first-person port in `game3d/`; active2D and frozen19 unchanged. Integrate one Cooking, Heists, Campaign, Day, Office and Companions owner into FullRuntime, with one shared four-pin Lockpick and the existing State/Memory/Progression/Travel/Combat/Director. Exact source oracle outcomes govern normal gameplay. All scene actions still require actual source range, live capability and physical access.

Executed adaptations: extreme accepted cooking batches settle in bounded2048-packet chunks before mode/fresh/restore/save/native-close transitions; wall endings cannot stall settlement; delayed receipts/pending transitions are p/s-epoch-bound. A visible opaque startup prepares the same72 authored resources once, exact bytes/binds/materials preserved. Facade sites use nearest source-rectangle focus and own-facade LOS; source rank4 abandoned-site availability latch remains session-wide. Office field reach is strict58px/2.32m. Day validates complete canonical force plans rather than trusting caller actor data.

Companions keep one pending physical pet/dog/reveal with frozen random intent. Released/dead possum records retain source reacquisition blocking; returned dog replaces its prior dead row because the3D scene uses unique rig IDs. Fresh/restore resets unsaved pet ownership/return timers instead of retaining phantom ownership without an actor. Deferred reveals relocate the selected existing pile, retaining identity/value/equipment and preventing further draws until committed/collected. Departed animals are hidden; combat deaths keep death poses.

Counterexamples found and fixed: same-mode cookmini clearing active heat; Tony's delayed ending freezing accepted resolution; stale smoke receipts after forced epoch replacement; refused death/arrest cleanup; locked office/Greg normalizing unrelated office state; consumed Office capability leaving dialogue after changed-resource refusal. Live Scene165 includes cooking/save/close barriers, physical lease/claim/locker and pet/freed-dog lifecycle. Source Runtime128 and CookingRuntime156 pass. Full expanded runner and rendered native/Web acceptance are required at the checkpoint; these counts alone do not imply complete parity.


## IMPL-3D-FULL-05 — Physical contact, props and Kingdom (2026-11-18)

Authorized full-port continuation. Executed P04-CONTACT: player/live rendered NPC movement
uses swept source Minkowski rectangles with a deliberate1px overlap band, preserving source
melee/charge contact while keeping the camera outside torsos. Contacts slide symmetrically,
never push peers, never become static-wall charge impacts or navigation replans. Initial
coincidence repair is deterministic, wall/peer-swept and bounded; failed repair keeps a valid
world point without suppressing AI. Dead/departed and exact Day-hidden residents do not leave
invisible blockers. NPC/NPC collision remains the source behavior. Static service approaches
now stand outside initial resident bodies. The intro walking fixture retains the entire cast
and steers a real capsule around body corners instead of deleting actors from the test.

Native reproduction isolated source skid_lurch0.2176m from camera after60s; older120s evidence
also put the eye inside Sherri's hair attachment. All skeletons were finite. Fixed native120s
plus D/S movement: zero sampled NPC bounds contain the camera, Lurch remains1.0–1.2m away,
source overlap still permits damage and death recovery. Evidence: .build/full-port/contact-native-120.
This is native evidence; updated browser replay remains required.

PROP-DUMPSTER-TOOL preserves the source equipped-only torch overwrite, even if Pete's locker
already holds a torch. PROP-PHONE-PHYSICAL reserves one drawn church phone tip until its actual
50cash pile can be placed within100px, with250active-ms retries/no reroll; it never credits
invisible cash. WorldProps shares live PropState and Companion authority; dumpster/bench/phone
clocks run in source order. Escape does not select climb-out. Source159paths/287steps34269checks.

Kingdom uses the real Campaign/Office/Day/Combat owners, validated17 service points, strict
source44/58/72px ranges, canonical coordinates without world float round-trip or range epsilon.
World approach clearance includes the actual capsule margin. Corrupt-stage completion is a pure
rejection before damage/reward/repair; source normalization quirks remain in oracle evidence.
Office ledger handoff, correction/banner inputs, three staged encounter bodies, abort preserving
marks, anoint synchronization and2600ms ending are connected. Late owner installation seeds the
current wall clock; ending waits behind accepted cooking settlement and is dropped on replaced
epochs. Source157paths/361steps22204checks; physical558checks; liveScene248 before UI additions;
CookingRuntime175 includes actual Kingdom completion/cook boundary/fresh cancellation.

P04c exact pose/global-transform caches pass1521 visibility/return/bounds tests and1954 roster
checks. Offscreen eligibility remains unconnected pending a certified receiver floor. Native
cache-only actual60 run FAILED acceptance: scene CPU p95 day42.68/night35.964ms; police arrest
also removed four source actors, leaving56. No frame-budget claim; profile source subsystems
before changes. Probe .build/full-port/p04c-cache-only. Renderer shadow trial remains pending.

UI correction: E input honors stun; Q uses source title/flav/intro visibility; discovery rooms
are leave-only until conceded; concession labels/disabled conditions match source; receipts
retain source duration. No generic inventory-use system added: source inventory is read-only.
Full campaign/nativeWeb parity remains incomplete; incident/interactive-prop models are gated
but their world presenters are separate activation dependencies.


### IMPL-3D-FULL-06 — source utility composition and dynamic geometry
**Executed in `codex/3d-full-port`,2026-11-18; checkpoint validation in flight.**
- Production selects dynamic interactive geometry explicitly; legacy slice/static world preserves its old contracts. One shared14-record owner projects into original meshes and actual collider/navigation/service records after admitted commands/ticks, including synchronous epoch clear before the source24 initialization draws.
- Prop staging must reject live NPC physical envelopes as well as walls, prior prop volumes and reserved player approach/eye rays. Root's composed cold startup caught Karaoke Mike intersection and retained the failing assertion until fixed.
- Block/market/F/zone entries/autosave use the accepted Utilities owner; no invented inventory-use action. Source labels and odd clock boundaries remain. Spatial callbacks are reentrant and post-call epoch checks protect replacement sessions.
- First-person attacks carry the original accepted weapon ID in presentation metadata, so an NPC drop or broken bottle cannot rewrite the swing already committed. Specific phone/bench/dumpster/kick gestures follow successful source actions only.
- Mattress spatial adaptation preserves source longitudinal/ease/sine/time/RNG and source endpoint records, but may map physical endpoints laterally within100px when authored3D solids occupy them. The SAME mapped point is used for proximity and display; no invisible harmful trajectory. Actual28lane certificate passed; full incident activation awaits remaining continuous/dynamic/native checks.
- Performance remains rejected by measured whole-scene/engine evidence; diagnostic scopes do not change dt, source simulation, actor counts or render settings.


### IMPL-3D-FULL-07 — guidance source defects and directional compatibility
**Executed2026-11-18 on `codex/3d-full-port`.** The unchanged pixel journal throws a ReferenceError on its first met vendor because it refers to an unbound `npcs`; the3D pure presenter intentionally reads the shared State roster. Original defect remains characterized separately. Quest/reward iteration retains source canonical order rather than alphabetized export order. At exact octant bisectors, V8 and Godot atan2 differ by ULPs; presentation snaps values within1e-12 of a half-octant, then uses floor(value+.5). Exact V8 outcomes remain in the fixture alongside explicit deterministic tie expectations and just-either-side checks. No target, mode, command, RNG or resource changes. The comparison also exposed an existingKingdom objective predicate drift: only live marked `kingdomBoss` rows may supply the live objective position; same-ID ordinary actors use the authored fallback. Kingdom's combat lookup is unchanged. Guidance1125checks/165views58directions andKingdom22688/159paths369steps passed centrally.

### IMPL-3D-FULL-08 — physical witnesses and rendered HUD placement
**Executed 2026-11-18 on `codex/3d-full-port`.** The accepted actor-contact rule exposed a static-only Kingdom walking controller: real traces stopped at `skid_brutus_1` and `skid_lurch`, with clear static capsules and zero-fraction actor contacts. The test now builds bounded, actual-sweep-certified resident detours and checks every walked position against live actor envelopes. Exact source service endpoints, production movement, NPC bodies and campaign assertions remain unchanged; the focused physical gate passes593 checks. Separately, native1280×720 images showed the new minimap outside the viewport: assigning Control.position after parenting overwrote its intended anchor-relative placement. FullHUD now uses anchored offsets for minimap/receipt, restores receipt offsets and objective visibility when guidance is unbound, and checks real viewport containment at1280×720 and960×540. The new contact index preserves exact live source records and per-frame/epoch identity validation; it caches neither collision outcomes nor actor flags. Its native diagnostic still fails performance, and no release-template or complete-port performance acceptance is claimed.

Rendered browser follow-up to IMPL-3D-FULL-08: the source journal footer advertised Q/Escape close while FullScene only accepted those shortcuts from playing. Native/Web readonly journal/inventory pages now own a transient close key cleared by every new menu and resume. Same-key/Escape exit and echo/stale-menu boundaries pass the full300-check scene suite. Other dialogue and cooking paths retain their own exit rules. Browser QA uses a local export wrapper with existing --qa-interactive args; ?qa-full alone does not activate the isolated storage branch.
### IMPL-3D-FULL-09 — dynamic cart, bounded visual correction and live incident corridors
Executed on codex/3d-full-port, 2026-11-18; current checkpoint remains in flight.
The single rideable cart adopts its17 original meshes and retains Travel source authority. Dynamic publication replaces the original parked solids/services and preserves six unrelated cart husks. Full-visible parking bounds include the original wheels'1.48cm overhang per side. Source strict36px/top-left reach, maxHP without healing, same-process unsaved parking continuity and fresh spawn remain exact. Mounted wall witnesses require a clear visible model; a bounded32cm presentation-only correction leaves player movement, source records and active physics unchanged. Offscreen handles release to relaxed hands and regrip their actual markers when visible. Enclosed presentation fails explicitly rather than claiming clearance. Headless cart3639 checks pass; new native review is running.

Incidents now retain their model/path/reservation owners in FullRuntime and render through one presenter. Every prospective eligible scene is physically certified before source choice RNG/effects; active corridor reservations block same-frame prop/cart publication. Fresh/restore release old reservations before new geometry. Mattress uses the same bounded mapped point for effects and display. Ticketed luggage receives a12px northward visual arc near the rail signal, zero at canonical endpoints, without changing source actor position/avoidance/time/RNG. Pigeons now fit their declared swept geometry. Independent actual-world checks1413 and real-scene80 pass, including the18s/8s loop, source interruption and restore delay before24 bottle draws. A26s test naturally attracted two real aggressors; independent scenarios now start a real new game instead of disabling source combat suppression.

### IMPL-3D-FULL-10 — Old School, projected guidance and bounded live reads
Executed on codex/3d-full-port, 2026-11-18. Old School preserves source strict44px/rank gates and captured-page/corpse quirks. Bosses owns a staged, one-use p/s-bound spawn capability; the menu cannot charge resources or consume RNG before unavailable physical placement. Model1170 and actual-scene69 checks pass. Source E precedence and canonical door center are connected.
Projected objective markers use the actual camera and static LOS without changing target/interaction eligibility; behind/occluded targets remain informational. Guidance projection362 and actual-scene320 pass. Interactive prop single-row reads and one-pull synchronization avoid redundant14-row copies while retaining live records, epoch rejection and externally supplied snapshot equality; model13040 and physical view3172 pass. This is an optimization, not a frame-budget claim.

### IMPL-3D-FULL-11 — source audio with bounded independent cosmetic randomness
Executed on codex/3d-full-port, 2026-11-18; native/Web audible checks pending. Full-only synthesis replaces the six-cue slice adapter with all24 source recipes; slice synth remains unchanged. Primitive PCM is cached in eight bounded variation banks,32voices and256scheduled notes. Each delayed note checks mute/readiness at its own firing time; uncancelled source delays survive mode/session changes. Independent cosmetic randomness intentionally removes source sample-rate/audio-ready-dependent coupling from new synthesis/ambient clocks; existing model compatibility draws remain. The source ambientT clock and thresholds run once at the source Runtime seam. Input unlock belongs to actual key/click/current enabled menu callbacks, not programmatic resume. Source model11225 checks pass; actual Scene320 and incident Runtime80 remain green after integration. Complete performance/platform acceptance remains open.

### IMPL-3D-FULL-12 — original pickups and source-driven weather
Executed on codex/3d-full-port, 2026-11-18. Pickup meshes preserve torch→collar→money source priority and a separate crown; unknown equipment still renders source money. Runtime/Utilities keep collection and visibility ownership.230checks and18native views pass; no world weapon-drop system was invented.
Weather replaces only FullScene's sinusoidal lighting call with source .2/.3/.7/.8 boundaries, retaining the different gameplay isNight predicate. Existing39 fixture powers/generator gates are preserved. One160-instance rain mesh uses at most4 cached roof rays per sync, hiding uncertified columns until a new geometry revision has passed a physics frame. Compatibility fog density is an explicit presentation calibration.8045checks and30native captures pass; local rain p95.462ms and+1draw do not establish whole-scene performance. Headless checks decode the submitted buffer because the pinned dummy renderer's instance getter returns identity; native checks independently compare the actual160 instance transforms and roof clearance. A shelter capture obscured by a display NPC is being reframed before visual acceptance.

Audio integration follow-up to IMPL-3D-FULL-11:40actualScene checks pass with one wall pump per rendered frame. Extra input/event pumps were removed because they could execute deferred-zero notes inside the originating callback. Headless waits now observe actual monotonic milliseconds, matching the production clock, rather than SceneTreeTimer delta. All exact queue/counter/timing assertions remain. Current native full-scene opening passes18.12s high/26.17s cycle,56actors, real transactions/menus and isolatedsave; this is not all-source-path or audible-Web acceptance.
### IMPL-3D-FULL-13 — measured overlays and equipped first-person presentation

Executed on `codex/3d-full-port`, 2026-11-18. NPC labels, partial health, windup/stun,
chatter and global combat cues read the current source state and actual visible head/LOS.
Measured glyph unions and bounded side placements keep the cluster clear of occupied HUD
panels. The leader line identifies a displaced cluster. Final native evidence passes 14
captures after correcting a real occlusion and the staged health flag. Tools occupy the
off hand, clothing changes existing sleeves, and footwear appears in committed kicks;
gestures stow and restore current equipment. Gear passes 715 checks and 36 native captures.
Projectile art uses two cached original banks for bottle and holy types, retaining source
positions/rotation/lifetime authority; 113 checks and 14 native captures pass.

### IMPL-3D-FULL-14 — departure pads and ending continuation

Executed on `codex/3d-full-port`, 2026-11-18. Source departure targets beyond world bounds
cannot be reached by the actual movement clamp. The approved 3D adaptation uses visibly
marked, certified inside-edge pads, the existing movement clock, and removal only within
four source pixels. Bounded routing passes 6,390 checks; native input/clock evidence passes
117 checks and five captures, with final arrival at 3.52 pixels. No off-map motion is claimed.
Source ending variants now use their own receipts. A single Runtime continuation command
preserves progression, clears ending state and emits the source toast; pending saves block
button and Space continuation. This does not replace a full campaign/boss playthrough.

### IMPL-3D-FULL-15 — conservative presentation and query savings

Executed on `codex/3d-full-port`, 2026-11-18. Interaction candidates fail the existing
strict distance bound before domain-support reads. A successful actual endpoint overlap
query publishes its existing frame/geometry/body certificate, including when the caller
requires a fresh query. Navigation passes 4,753 checks. Pose rejection requires a complete
cached rig bound and proof that neither it nor its infinite sun-shadow extrusion enters
the frustum. Scene light registration immediately revokes the sole-shadow-light premise
when another shadow light appears. Eligible cop poses remain active for moving beacons.
Visibility passes 2,106 checks and combined pre-emitter Scene passes 359. The previous
frozen release failed performance; these changes await a new release measurement.
### IMPL-3D-FULL-16 — fixture-backed lights and inventory fields

Executed on `codex/3d-full-port`, 2026-11-18. Five pooled police fields and one player
field follow the source colors, ranges, night levels and eligibility, with visible original
cap/mouth fixtures and no dynamic shadows. Horse Cop uses the rider cap. The player fixture
stows during acknowledged gestures and returns only for the current high state. Source
pipe/torch tips use immutable emissive materials without adding lights. Detached current
snapshots are validated every call; output-only caches suppress redundant renderer writes.
149 focused checks and 367 combined Scene checks pass. All 16 native views were rendered
and reviewed; the editor CPU target remains failed at 0.269 ms p95 pending release measurement.

The source audit also found omitted inventory fields. The read-only view now includes
cred/bonus, wanted stars, cart status, source rounding and all eleven claim districts,
with source lifetime labels and conditional supplies/hitter rows. FullHUD passes 27 checks.

### IMPL-3D-FULL-17 — live ownership, tether and source world cues

Executed on `codex/3d-full-port`, 2026-11-18. Office titles/upgrades, eleven claim
signs and two ground hatch adaptations read current source facts without adding
collision or interaction owners. The dog chain binds an actual weighted collar
vertex and post staple; source alive-only selection deliberately retains the chain
after the living original loses its chained flag. The separate three-pixel faction
perimeter consumes the existing accepted world step after the territory ticker;
pause/hitpause freeze it and high/crash tint remains independent. Native leash
evidence has15 rendered views; ownership framing/performance corrections are active.
Kingdom banners and marks project source predicates, with a declared fence-mounted
cart mark. Remaining staged native evidence and combined runner are pending.

The existing3D state-epoch policy resets the complete transient territory/border
tuple on fresh/load. The source browser retains11 such fields in the same page
session. Keep the established3D reset rather than carrying only the visual fields
or covertly changing territory ticker/reward/greeting timing. This adaptation is
explicit in P14f; cold startup, active border timing and pause/hitpause remain tested.

### IMPL-3D-FULL-18 — complete shadow proof and query-local reuse

The infinite separating-half-space proof applies before the near-shadow guard:
distance cannot invalidate complete separation. Incoming/touching/unknown-light
cases still fail open. Nonrendering weighted markers must remain direct leaf Node3Ds;
new geometry beneath them immediately revokes cached eligibility. Visibility passes
2,112 checks over72 original templates. Exact unchanged actor transform setters are
omitted. Physics query construction reuses its already resolved height synchronously,
without changing overlap/cast counts or certificate lifetime; adapter21/navigation4753
pass. No full-frame performance improvement is claimed before a frozen measurement.

### IMPL-3D-FULL-19 — measured graffiti width authority

Actual Chromium Canvas measurements of all66 source lines at8/9/10px produced198
widths. They match installed Courier New Bold6.95 advance1229/2048;90 rounded widths
differ from the old exporter harness's0.6 approximation. The pinned measured table
ships as data, without distributing the font. Source generation uses that table;
valid saved textW/layouts are not rewritten. Normalized side-face placement and
paper-width-only poster fitting are explicit3D visual adaptations. Source RNG order,
empty-layout draw retries and save behavior remain separate owner responsibilities.

### IMPL-3D-FULL-20 — source-earned Tony acceptance

The original under90-second invariant permits ordinary earned equipment. The first
strict fists-only native tour defeated Tony but correctly failed its own narrower
contract: killing an ordinary reinforcement awards a pipe automatically in source.
Keep that failed report. A separate source-earned mode records every accepted input,
preceding weapon/cooldown, actor death and equipment award; it never writes equipment
or damage. Frozen production c61d9c9 passed in3.988s wall/3.380s active, seven Tony
hits totaling230 damage, all three phases and both reinforcements. Attack6 earned
the pipe from a real Sherri; Tony's later fatal pipe hit awarded the shoe afterward.
The same purchased rock completed18.049s high/7.995s crash and actual ending/continue.
The isolated fresh$25 fixture and state-aware automated driver are disclosed; this
proves one feasible native Tony fight, not human usability, browser/all-boss parity
or whole-campaign completion. No production behavior changed for this acceptance.

### IMPL-3D-FULL-21 — encoded district color pass

Adopt original ordered closed-edge zone/terrain grade selection and all39 recipe IDs
through one SDR screen pass beneath HUD. Six material recipes are initialized once;
no added light, gameplay state, RNG or clock. Explicit adaptation: final3D rain,
emissives and hands share grading, unlike the original separate2D layering. Actual
Chromium Canvas reference versus native and WebGL2 patches has maximum2/255 channel
error across270 channels; the UI patch is unchanged. This is quantization-bounded,
not byte-identical Canvas rasterization. Full-scene visual and performance acceptance
remain separately required.

### IMPL-3D-FULL-22 — passive original fixture motion

One adopted CORNER screen and four actual laundry drums retain existing3D counts
instead of introducing the source's5/6 facade tally. TV/washer phases and food steam
read monotonic visual time; the passing shadow reads Unix time; title alone hides
world motion. Pete steam uses the existing visible food prop when supplied; normal
night play hides Pete, so the existing front pawn service aperture supplies its
fallback anchor. The3D facade has no front framed pane at that opening. This is an
explicit counter/window adaptation, with no invented alive check or new geometry.
The shadow is split over bounded preexisting ground receiver rectangles,
with ordinary depth testing; its late tail at.017m is occluded by the actual later
building floor at.021m. No collider, source location, light, particle, gameplay timer
or save field changes. Native acceptance and local/whole-scene budgets remain open.

### IMPL-3D-FULL-23 — exact reuse and honest workload measurement

Reuse identical per-bone rest/angle/offset results while always reinstalling poses
through existing overlay/IK invalidation. Reuse overlap/sweep query setup only inside
a synchronous call; keep all actual physical proofs and lifetime invalidations.
Diagnostic stage-call counts and active milliseconds accompany future performance
reports because equal render-frame counts do not imply equal simulation work. No
AI clock, NPC count, model detail, renderer setting or frame target is reduced.

### IMPL-3D-FULL-24 — movement aliases and physical acceptance drivers

Bind the source journal's advertised arrow keys to the existing WASD movement actions
idempotently. Keep boss/Office acceptance as isolated normal-input tests, with actual
LOS/capsule approaches, explicit fixtures and finite work/time limits. Failed driver
runs remain evidence; driver repairs never change production damage or obstacles.

### IMPL-3D-FULL-25 — startup publications and conditional restore

Fresh/load publishes the source wake toast, two ordered feed entries and ranked
news through the existing Communications owner. Call-time silence and queued work
remain authoritative; there is no second feed. Restore removes the conditional
intro pile only when the source start/spawn boundary requires it, preserving its
same-session availability and rejecting stale pickup references. Missing/non-array
saved hustles invoke the existing owner after wall restoration and before route
generation; explicit arrays retain sanitized contents, including empty arrays.
Source fixtures cover exact bottle/wall/hustle/route RNG order and schema1 migration.
Central startup parity321, State211, Runtime160 and Communications1219 pass.

### IMPL-3D-FULL-26 — relaxed empty-hand stance

Lower and asymmetrically relax unoccupied hands through additive pose offsets and
progressive finger/thumb curl. Existing gesture envelopes fade the rest pose out
and back; occupied tool/weapon/cart grips and peak punches retain their prior
targets. Smooth pickup/dumpster finger ramps remove abrupt closing transitions.
No mesh, material, gameplay input or action receipt changes. Context1329 and Gear729
pass;93 native views include1280x720/960x540, both punch hands and recovery. Browser
acceptance remains a separate obligation.

### IMPL-3D-FULL-27 — retain truthful source obligations

Update seven source-handler mappings for centrally checked startup, grade and
fixture integration; retain all585 rows and every platform evidence obligation.
The result is555 integrated/28partial/2planned, with0verified features. Original
fixed spawn definitions do not imply omitted random generation. Aggregate frame
rows remain partial for explicit first-person/pixel-helper/touch-scope dispositions
and platform/performance acceptance. No original sprite contract or completion
gate is relaxed to admit3D geometry or to convert incomplete evidence into a pass.

### IMPL-3D-FULL-28 — source shortcuts through existing owners

Dispatch ordinary pressed Space, including OS repeats, through Runtime.attack and
its real cooldown/stun gates. Keep cook/ending priority. Dispatch non-repeat M before
cooking through the existing ready/mute owner and800ms source receipt; preserve
established3D mode/loading policy. No parallel audio/input/resource owner. Correct23
feature acceptance descriptions without changing statuses or evidence obligations.

### IMPL-3D-FULL-29 — sufficient current-player clearance

After existing static clearance, exact finite Contact center/half-extent arithmetic
may prove a non-player body separated from its only possible peer, the current
player. Strict > keeps equality on the old path. Invalid/overflow/current-state
changes fall through or are reread; no retained snapshot or static proof is removed.
Paired real-physics adapter437 checks pass. Performance benefit remains unproven.

### IMPL-3D-FULL-30 — rendered Karaoke acceptance and failed workload retention

Promote the declared-$5 actual-input Karaoke tour and synthetic59-check contract;
register it separately from actual platform evidence. Read notes from rendered
choices, preserve untimed dialogue and verify exact source/intro reward ordering,
durable save and resumed movement. Retain8bcd failed Office resident routing and
1080-frame performance evidence. An arrest reducing population to56 cannot become
a60-actor pass, and CPU above16ms remains independently failed.

### IMPL-3D-FULL-31 — Office resident retry without obstacle changes

Retain the failed8bcd bus-glass approach. Empty/newly blocked driver routes release
input and retry actual capsule/contact planning at750ms, preserving initial+32
plans,80points,20s real-displacement and120s leg limits. Neither planning nor
waypoint bookkeeping resets progress. Current certificates authorize each segment;
report graph/endpoint refusals and bounded walking context. Contract305 passes
including seven orchestration counterexamples; actual Office acceptance still
requires a completed native run. No production geometry, actor or stat changes.

IMPL-3D-FULL-31 continuation: strict NPC service range and unchanged-failed-aim
suppression prevent the driver waiting outside the actual 60px resolver. A later
real corner diagnostic showed that long casts can skip a narrow endpoint margin
band that short controller steps correctly refuse. Add exact-source short-step
checks and a finite local detour (24 candidates, four tail joins, at most 26 local
steps per candidate), retaining all original time/replan limits. Contract 1138 and
the focused native exact-origin replay pass; whole-tour acceptance stays separate.

### IMPL-3D-FULL-32 — legal Office service endpoints and native progression

An actual overlap identifies the late alley-can collider at its fixed guidance
point. Keep production collision unchanged; a derived test driver selects from33
finite endpoints within the original strict source/physical range, current capsule,
peer and target-ray checks. Four route attempts share each750ms window. Original
1138 routing checks remain and the separate85-check endpoint contract passes.
Focused retained-save replay advances the real route once. The complete native
tour passes in231.446s: same18.020s/7.999s loop, three sheets, Office/upgrades,
Canal sign, pending/paid persistence and next-day order, zero deaths/arrests.
Initial300cash/6copper is disclosed; resource earning, other claims, Kingdom and
Web are not proven. Evidence: artifacts/3d-full-port/office-endpoint-acceptance.

### IMPL-3D-FULL-33 — shaped hands and physical cart wrap

Original cached palms/thumb roots gain authored planes within a7.7047% triangle
increase, retaining all non-cart poses, durations, materials and shared resources.
The unique cart receives a .038m faceted shaft and opposing finger/thumb wrap;
its collider and conservative placement envelope remain. Actual triangle contact
checks replace only obsolete box/curl implementation pins. Generated engine node
suffixes are normalized in cross-instance comparisons; authored structure and
transforms remain exact. Initial failed comparison is retained.
Focused1537 and retained41/1329/729/3640 checks pass. Native18+93+36+18 capture
sets complete; both actual Web16-phase sequences pass with zero engine/browser
errors and selected images reviewed. No performance or hardware capture claim.
Contract: SPEC-3D-HAND-ART.md. Evidence: artifacts/3d-full-port/hand-art-refinement.

### IMPL-3D-FULL-34 — frozen sustained-population comparison

Replace only the diagnostic workload overlay for paired release measurements:
normal input avoids depopulation, fixed120 warm-up plus1080 measured frames per
phase, every-frame60 living/supported/rendered actors, unchanged MeasuredScene.
Archive committed8bcd and648 separately; pin original production, the same three
test overlays, wrapper, official launcher/runtime/template and final EXE/report.
No production profiler or gameplay change; no frame/population/16ms relaxation.
Both retain60 and both fail16ms:8bcd27.484/24.976ms versus64825.474/22.038ms scene
p95. Driver cost and trajectory/source-step differences are explicit; this is not
an isolated causal speedup estimate. Raw evidence and harness are retained in
artifacts/3d-full-port/sustained-population-profile. Earlier56-survivor failures
remain valid failures, not overwritten baselines.

The three new evidence directories explicitly disable Git text conversion so
retained report/log/PNG bytes continue matching their recorded hashes across
Windows checkouts. Source files retain the existing repository line-ending rules.
Raw engine log whitespace is preserved; source diff whitespace checks pass.

### IMPL-3D-FULL-35 — ordered world feedback and original street atmosphere

Promote the reviewed current-base composition of eighteen burst recipes plus
walking dust and ambient motes. Keep one220-slot pool/four banks/two meshes and
materials, independent cosmetic RNG, exact source births and ordered event cursors.
The four-triangle flash fan and asymmetric fragments retain880 maximum triangles.
Only the named dust recipes permit their longer lifetimes. Read source shake in
the existing district pass, with a physical-framebuffer offset bound and fixed
camera/aim/HUD. Preserve source transaction/RNG/actor/clock behavior; reject stale
Companion reveal commits at their current identity/epoch boundary.

Central combined pure/integration/geometry and native real-upload checks pass.
Live-pose native core452/authority664 checks pass at1280 and960; actual Web core481/
authority699 pass at both sizes, zero engine/browser errors. Dust native339 and
Web356 checks pass at both sizes, eight contexts/seventeen PNGs each. Original
downloaded bytes and source-overlay provenance are retained; representative images
were reviewed, including actual coat removal, taser pose, prop emergence, wall
occlusion and the small-window HUD. These are disclosed staged visual fixtures,
not earned campaign, hardware input, audio or performance acceptance.

Retain earlier invalid disabled-tree physics fixtures and frozen-ActorPose images
with explicit limits. The revised probe uses callback-only suspension, real-wall
sentinels, admitted-time poses and separate exact opaque glyph/meter masks. Do not
retroactively pass the old reports. Full regression/export/delivery and unchanged
60-actor16ms acceptance remain required after this integration.

Final integration validation: 127/127 3D and 19/19 original gates pass; Full
Windows/Web exports pass. Local 8074 serves the rebuilt pack. Browser menu exits
and movement pass with the existing pointer-capture fallback limitation retained.
The original-byte package includes full runner/build output and manual screenshot.
