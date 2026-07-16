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
