# Full 3D port: world, population and place inventory

Audit date: 2026-11-18. Read-only source audit for the full-port goal. This document is an inventory and proposed implementation contract, not gameplay parity or a shipping report. Only this report was written during the audit; no Godot process was run and no production source was changed.

## Evidence and count boundaries

Read `VIBE.md` first. Data counts were evaluated from the live source initializers in an isolated Node VM, then cross-checked by the repository's seeded `loadModularGame()` harness and actual `startGame(false)`. Closures were not executed for the static inventory. The complete start confirmed the kingdom population that `spawnNpcs()` alone omits. Existing source gate output is cited as prior evidence, not represented as a newly run suite.

| Corpus | Exact count | Source / scope |
| --- | --- | --- |
| World | 8600 × 5600 source pixels | src/data/world.js:75 |
| Mechanical zones | 23 | world.js:92; faction/clan authority, distinct from visual terrain |
| Terrain regions / roads / footpaths | 15 / 28 / 8 | world.js:132,150,200 |
| Crosswalks / rails | 26 / 4 | world.js:182,211; anonymous records preserve authored index |
| Declared physical structures | 53 = 25 BUILDINGS + 28 LANDMARK_FACADES | props.js:55; world.js:220; physicality.js:21 |
| Solid / flat declared structures | 53 / 0 | Every live declaration is solid:true; flat is a registered schema choice, not inferred |
| South door gaps | 29 = 8 buildings + 21 facades | Counted from doorGap:true (the 21 doorway-preservation tests are facade tests) |
| Placed PROPS | 193 records / 30 types | props.js:94; mostly anonymous, so preserve authored index |
| WORLD_DECOR | 96 records / 12 types | world.js:251 |
| Utility wires / world lights | 20 / 24 | world.js; fixture records are separate from ordinary lamp props |
| Base actor records | 41 instances / 38 canonical identities | npc_spawns.js:47; three skid aliases reuse Brutus/Lurch/Sherri |
| Fresh game population | 56 = 41 base + 15 kingdom guards | campaigns.js:516; 45 distinct display spellings |
| Canonical VIBE registry | 63 rows | tools/npc-registry-gate.mjs; see identity accounting below |
| Fixed hidden cash / intro cash | 28 + 1 conditional | npc_spawns.js:368; cp_0..cp_27 + cp_intro_remember |
| Interactive prop boot population | 14 = 6 trash cans + 8 bottles | props.js:21; bottles drawn from 16 candidate spots with jitter |
| Copper sites / break-ins | 4 / 5 | props.js:357 / 533; modal speakers are not runtime NPC bodies |
| Equipment / vendor discovery IDs | 16 / 17 | catalogs.js:20 / 154 |
| Phone / graffiti lines | 10 / 66 (36 street + 15 scrap + 15 spiritual) | catalogs.js:52,74,115,132 |
| Crown candidates | 6 | catalogs.js:182 |
| Route stops / claims / quest target entries | 23 / 11 / 10 | progression_routes.js:285; campaigns.js:676,817 |
| Smoke anchors / recognition venues | 5 / 4 | concessions.js:21; recognition.js:10 |
| Current 3D scope | 6 bodies; 9 target Areas; 4 authored slice districts | game3d/scripts/main.gd:100,126; neighborhood.gd; not a full-map port |

Prior gate evidence: `reports/2026-11-18-3d-character-street-legacy-gates.txt:14` reports 63 canonical rows, 59 source identity spellings, 56 runtime actors / 45 display identities, four aliases and one generated name family. Its sprite line reports **94** declared character bases / **377** cache keys, so the older VIBE paragraph's 93/373 is historical. Art-base count is not the NPC count.

## Coverage against the current slice

The 3D slice implements art and limited interactions for `tony`, `pete`, `yuri`, `lurch`, `possum`, `brutus`; the first five have slice-specific transactions, while Brutus is chiefly scenery/lore. It has a crate, three dumpsters, three cash finds, one copper find, a pawn service opening and closed background buildings. These are re-spaced examples, not the corresponding complete source records. Slice IDs `dumpster_1..3`, `cash_1..3`, `copper_1` do not identify the original PROPS indexes or `cp_*` cash ledger. A similar bench, mailbox, car or sign is not evidence that the associated source mechanic exists.

Do not bolt the rest of the map onto the existing ±42m layout. Keep the slice as an art/control benchmark and build a separate source-backed full-world scene. Reuse meshes/material helpers, not its hard-coded neighborhood positions or simplified economy. Current branded shop text and generic distant blocks do not count as any of the 28 canonical facades until explicitly mapped.

## Mechanical geography

Rectangle coordinates below are exact source `x,y,w,h`. Proposed conversion is described later; export these raw values. Zone order and overlap resolution must remain source-driven (`currentZone()` / `currentZoneFaction()`), with terrain only choosing appearance.

| Zone ID | Name | Rect | Faction / clan | 3D coverage |
| --- | --- | --- | --- | --- |
| `block` | THE BLOCK | 880,720,340,240 | street | local slice analogue; no coordinate parity |
| `scrap` | SCRAP YARD | 100,80,520,360 | scrap | local slice analogue; no coordinate parity |
| `pawn` | PAWN SHOP | 130,580,260,200 | scrap | local slice analogue; no coordinate parity |
| `dealer` | DEALER'S CORNER | 1460,780,320,250 | street | local slice analogue; no coordinate parity |
| `abandoned` | ABANDONED BUILDING | 1500,100,480,360 | neutral | missing |
| `market` | MARKETPLACE | 700,1380,720,260 | spiritual | missing |
| `alley` | BACK ALLEY | 100,1280,540,380 | street | local slice analogue; no coordinate parity |
| `church` | CHURCH | 1600,1300,380,320 | spiritual | missing |
| `projects` | THE PROJECTS | 100,1700,600,180 | street | missing |
| `underpass` | HIGHWAY UNDERPASS | 1020,240,380,220 | scrap | missing |
| `laundromat` | THE LAUNDROMAT | 1480,1080,320,200 | street | missing |
| `busstop` | BUS STOP | 1240,1080,220,180 | street | missing |
| `trainyard` | TRAIN YARD | 260,2700,1100,560 | spiritual | missing |
| `park` | THE PARK | 2400,900,620,500 | spiritual | missing |
| `skidrow` | SKID ROW | 2480,1520,900,720 | street | missing |
| `oldschool` | OLD SCHOOL | 3400,280,760,640 | scrap | missing |
| `warehouse_row` | WAREHOUSE ROW | 4400,180,1100,760 | scrap | missing |
| `canal` | THE DRAINAGE CANAL | 4300,1540,1350,680 | neutral | missing |
| `the_lot` | THE LOT | 4300,2700,1250,850 | neutral | missing |
| `blue_tarp_court` | BLUE TARP COURT | 5920,260,1160,1060 | neutral / blue_tarp | missing |
| `cart_cavalry_keep` | CART CAVALRY KEEP | 7340,1460,1040,980 | neutral / cart_cavalry | missing |
| `copper_choir_yard` | COPPER CHOIR YARD | 5920,2760,1220,1120 | neutral / copper_choir | missing |
| `throne_ditch` | THE THRONE DITCH | 7020,4200,1320,1120 | neutral / throne | missing |

| Terrain ID | Rect | Palette |
| --- | --- | --- |
| `north_vacant` | 1980,0,1420,920 | vacant |
| `school_outside` | 3400,0,1000,1500 | school_outskirts |
| `east_service` | 1980,760,1500,1660 | service |
| `south_drainage` | 0,1880,2250,720 | drainage |
| `rail_approach` | 0,2480,1700,1320 | rail_approach |
| `south_dead` | 1700,2240,2700,1560 | dead_grass |
| `far_north` | 4400,0,1400,1400 | service |
| `far_mid` | 3480,1400,2320,1080 | drainage |
| `far_south` | 4400,2480,1400,1320 | dead_grass |
| `kingdom_north` | 5800,0,2800,1340 | service |
| `kingdom_middle` | 5800,1340,2800,1300 | vacant |
| `kingdom_south` | 5800,2640,2800,1360 | dead_grass |
| `kingdom_bottom` | 5800,4000,2800,1600 | drainage |
| `southwest_scrub` | 0,3800,2800,1800 | dead_grass |
| `south_rail_spoil` | 2800,3800,3000,1800 | rail_approach |

| Road ID | Rect | Axis / kind |
| --- | --- | --- |
| `north_core` | 0,500,2180,108 | h / street |
| `block_cut` | 620,970,1580,104 | h / street |
| `market_cut` | 0,1258,2200,102 | h / street |
| `projects_lane` | 0,1880,3400,112 | h / service |
| `east_link` | 1980,780,1420,112 | h / street |
| `park_skid_link` | 1980,1400,3720,112 | h / street |
| `south_service` | 0,2480,5700,116 | h / service |
| `train_approach` | 0,2600,1500,96 | h / service |
| `west_spine` | 620,0,104,1880 | v / street |
| `central_spine` | 1380,0,104,1880 | v / street |
| `east_spine` | 2100,0,112,2480 | v / arterial |
| `school_spine` | 3280,0,112,2480 | v / service |
| `rail_spine` | 700,1880,112,820 | v / service |
| `train_east` | 1360,2480,112,1320 | v / service |
| `warehouse_cut` | 3280,960,2420,112 | h / street |
| `far_east_spine` | 4160,900,112,2800 | v / arterial |
| `office_drive` | 4868,2480,104,390 | v / service |
| `warehouse_cut_east` | 5680,960,1600,112 | h / street |
| `court_keep_cut` | 5680,1340,2840,112 | h / arterial |
| `kingdom_south_link` | 5680,2480,2840,116 | h / service |
| `copper_docket` | 5680,3980,2840,112 | h / service |
| `throne_tail` | 7000,5360,1520,104 | h / service |
| `clan_spine` | 7160,900,112,3180 | v / arterial |
| `west_claim_spine` | 5680,2480,112,2328 | v / service |
| `east_bypass` | 8400,1340,112,4124 | v / service |
| `ditch_spine` | 7160,3980,112,1484 | v / service |
| `old_south_spine_extension` | 4160,3680,112,1128 | v / service |
| `south_scrub_cut` | 4160,4700,1632,108 | h / service |

| Footpath ID | Source width |
| --- | --- |
| `park_loop_a` | 34 |
| `park_loop_b` | 28 |
| `church_walk` | 24 |
| `school_walk` | 30 |
| `tarp_court_walk` | 30 |
| `cart_keep_walk` | 32 |
| `choir_aisle` | 28 |
| `ditch_procession` | 36 |

All 26 crossings, four rail polylines, 20 utility wire records and 24 light records must be exported unchanged by index. Their exact points remain in `world.js`; they are not independent progression territories. All eight footpath point arrays must accompany the width, not just the bounding box.

## Structures and explicit physicality

`STRUCTURES = [...BUILDINGS, ...LANDMARK_FACADES]` is the single collision source (`physicality.js:21`). The full port needs one source-backed footprint/door registry shared by movement, navigation, melee/projectiles, ray occlusion and load recovery. Preserve the source logical geometry before introducing cosmetic wall thickness. BUILDINGS has no stable textual IDs; preserve array index as source identity, e.g. reference `BUILDINGS[0]`, rather than silently generating a new gameplay identifier from the visible name.

| Source structure | Name | Rect | Door / contract | 3D representation |
| --- | --- | --- | --- | --- |
| `BUILDINGS[0]` | PAWN | 180,620,160,100 | solid shell | service-window pawn shell; source Pete exception |
| `BUILDINGS[1]` | CORNER | 1520,820,200,110 | solid shell | corner shop; source Tony exception |
| `BUILDINGS[2]` | (abandoned) | 1560,160,360,240 | locked copper-site anchor | authored collision shell |
| `BUILDINGS[3]` | CHURCH | 1680,1360,240,200 | south gap | church + priest actors / door |
| `BUILDINGS[4]` | LAUNDROMAT | 1520,1100,240,130 | south gap | laundromat + 3 actors / door |
| `BUILDINGS[5]` | OLDSCHOOL | 3520,380,520,340 | south gap | old-school modal door / boss yard |
| `BUILDINGS[6]` | SHACK | 2540,1660,120,70 | solid shell | authored collision shell |
| `BUILDINGS[7]` | SHACK | 2720,1740,100,80 | solid shell | authored collision shell |
| `BUILDINGS[8]` | SHACK | 2900,1620,130,90 | solid shell | authored collision shell |
| `BUILDINGS[9]` | SHACK | 3120,1720,110,70 | solid shell | authored collision shell |
| `BUILDINGS[10]` | SHACK | 2580,1900,140,80 | solid shell | authored collision shell |
| `BUILDINGS[11]` | SHACK | 2900,1980,160,80 | solid shell | authored collision shell |
| `BUILDINGS[12]` | SHACK | 3140,1900,130,90 | solid shell | authored collision shell |
| `BUILDINGS[13]` | SHACK | 2780,2080,120,80 | solid shell | authored collision shell |
| `BUILDINGS[14]` | UNIT 11 | 4460,280,390,420 | solid shell | authored collision shell |
| `BUILDINGS[15]` | RETURNS | 5010,280,400,420 | solid shell | authored collision shell |
| `BUILDINGS[16]` | THE OFFICE | 4700,2920,440,300 | south gap | owned office / separate office contract |
| `BUILDINGS[17]` | TARP PERMITS | 6000,300,340,180 | solid shell | authored collision shell |
| `BUILDINGS[18]` | BLUE COURT | 6660,300,340,180 | south gap | authored collision shell |
| `BUILDINGS[19]` | CART IMPOUND | 7420,1540,320,220 | solid shell | authored collision shell |
| `BUILDINGS[20]` | THE KEEP | 7960,1540,320,220 | south gap | authored collision shell |
| `BUILDINGS[21]` | COPPER RETURNS | 6000,2840,380,240 | solid shell | authored collision shell |
| `BUILDINGS[22]` | CHOIR OFFICE | 6620,2840,420,240 | south gap | authored collision shell |
| `BUILDINGS[23]` | DITCH RECORDS | 7280,4280,360,220 | solid shell | authored collision shell |
| `BUILDINGS[24]` | THE THRONE | 7840,4280,420,220 | south gap | authored collision shell |

| Facade ID | Sign | Kind | Rect | South gap |
| --- | --- | --- | --- | --- |
| `checks` | CHECKS | storefront | 760,90,200,170 | no |
| `rooms_no` | ROOMS (NO) | rowhouse | 760,310,200,150 | yes |
| `former_dentist` | FORMER DENTIST | storefront | 1740,620,300,140 | no |
| `boxes` | BOXES | warehouse | 2340,90,420,270 | yes |
| `tire_2` | TIRE 2 | warehouse | 2820,100,360,260 | yes |
| `car_wash` | CAR WASH · NO WATER | storefront | 2340,630,360,130 | no |
| `used_mattress` | USED MATTRESS | storefront | 2780,620,440,140 | no |
| `motel` | MOTEL · OFFICE CLOSED | rowhouse | 3050,940,190,390 | yes |
| `projects_a` | BUILDING A | rowhouse | 100,1685,260,78 | yes |
| `self_storage` | SELF STORAGE | warehouse | 70,2070,500,270 | yes |
| `carpet` | CARPET | warehouse | 900,2050,360,250 | yes |
| `meat` | MEAT | industrial | 1400,2040,580,280 | yes |
| `loading` | LOADING | warehouse | 2240,2290,940,160 | yes |
| `no_refunds` | NO REFUNDS | warehouse | 1530,2700,600,300 | yes |
| `tax` | TAX | industrial | 2280,2690,600,270 | yes |
| `unit_4` | UNIT 4 | warehouse | 3050,2680,760,280 | yes |
| `cold_not` | COLD (NOT) | warehouse | 4440,1080,450,230 | yes |
| `plastic_chair` | PLASTIC CHAIR | warehouse | 5060,1090,500,220 | yes |
| `water_dry` | WATER DEPT. (DRY) | industrial | 4460,2250,520,210 | yes |
| `leasing_later` | LEASING · LATER | storefront | 5180,2250,420,200 | no |
| `tarp_wholesale` | TARP WHOLESALE | warehouse | 5920,40,520,180 | yes |
| `family_court_2` | FAMILY COURT 2 | rowhouse | 6500,40,560,180 | yes |
| `wheel_witness` | WHEEL WITNESS | warehouse | 7360,1120,420,190 | yes |
| `coin_return` | COIN RETURN | storefront | 7900,1120,440,190 | no |
| `wire_less` | WIRE (LESS) | industrial | 5940,2600,500,130 | yes |
| `b_flat_storage` | B FLAT STORAGE | warehouse | 6540,2600,520,130 | yes |
| `chair_annex` | CHAIR ANNEX | rowhouse | 7280,4100,440,80 | yes |
| `ditch_clerk` | DITCH CLERK | storefront | 7800,4100,520,80 | no |

There are **21** facade door gaps and **8** BUILDINGS door gaps. `structureDoorAccepts()` uses the moving body's bottom within ±30 source pixels of the south face and body center X within ±30 of the structure center (`physicality.js:25`). It is an approach aperture, not authorization to open an unrestricted walkable interior. The five break-in shells and three freight cars are **PROPS, not entries in STRUCTURES**. Adding full solid boxes for them in 3D changes source collision and can block broad site triggers; explicitly author accessible exterior trigger space and test that change. Do not mark canonical solid facades as scenery to simplify the port.

Eight `legacyStructureIndex` actors intentionally occupy original solids: `tony:1`, `pete:0`, `priest:3`, `barb:4`, `laundromat_lady:4`, `priests_son:3`, `karaoke:4`, `skid_sherri:13`. Preserve their identity-specific interaction/placement contract; do not grant a blanket wall exception to all NPCs. Full 3D can position art behind visible service apertures, but target reach must resolve to a clear surface/approach. Existing solidity tests repair four impossible Tony-center route endpoints within his live 60px action region.

## Residents: all 41 base records

Exact spawn `x,y` is top-left; footprint is `w×h`. Sprite ID and runtime NPC ID are distinct in several rows. Tables record authoring facts, not all dialogue outcomes. Behavior callbacks remain source-code work; do not interpret a serialized record as an implemented actor.

| NPC ID | Display name / sprite | Spawn / footprint | Runtime role flags | Source line |
| --- | --- | --- | --- | --- |
| `tony` | TRE BAG TONY / `tony` | 1620,870 / 28×32 | vendor; legacy structure 1 | npc_spawns.js (ID-keyed record) |
| `yuri` | YURI / `yuri` | 300,200 / 28×32 | vendor | npc_spawns.js (ID-keyed record) |
| `brutus` | BRUTUS / `brutus` | 480,280 / 32×24 | charger; zoneOnly | npc_spawns.js (ID-keyed record) |
| `scrap_dog` | THE DOG / `scrap_dog` | 580,150 / 26×20 | passive; chained | npc_spawns.js (ID-keyed record) |
| `pete` | PAWN SHOP PETE / `pete` | 250,700 / 28×32 | vendor; legacy structure 0 | npc_spawns.js (ID-keyed record) |
| `lurch` | LURCH / `lurch` | 200,1400 / 28×34 | grabber; wanders; aggroOnHit | npc_spawns.js (ID-keyed record) |
| `sherri` | SPIDER-BITE SHERRI / `sherri` | 350,1480 / 26×30 | swarmer; wanders; aggroOnHit | npc_spawns.js (ID-keyed record) |
| `paulie` | PAULIE THE FACE / `paulie` | 450,1560 / 28×32 | ranged; wanders; aggroOnHit | npc_spawns.js (ID-keyed record) |
| `dave` | CHATTY DAVE / `dave` | 900,1480 / 28×32 | asleep | npc_spawns.js (ID-keyed record) |
| `mom` | WHOLE FOODS MOM / `mom` | 1200,1480 / 28×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `possum` | THE POSSUM / `possum` | 600,1500 / 28×24 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `priest` | FATHER O'MALLEY / `priest` | 1800,1460 / 28×32 | legacy structure 3 | npc_spawns.js (ID-keyed record) |
| `conductor` | THE CONDUCTOR / `conductor` | 680,2960 / 28×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `larry` | LOUD LARRY / `larry` | 440,1780 / 28×32 | aggroOnHit | npc_spawns.js (ID-keyed record) |
| `stripe` | STRIPE / `stripe` | 620,1780 / 28×32 | vendor | npc_spawns.js (ID-keyed record) |
| `pigeon` | THE PIGEON KING / `pigeon` | 2700,1180 / 24×20 | wanders | npc_spawns.js (ID-keyed record) |
| `biggu` | THE BIG GUY / `biggu` | 1200,340 / 32×38 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `cubscout` | CUBSCOUT / `cubscout` | 780,1500 / 22×26 | patrol 4 points; daytimeOnly | npc_spawns.js (ID-keyed record) |
| `jogger` | JOGGER / `jogger` | 1200,600 / 22×26 | patrol 4 points | npc_spawns.js (ID-keyed record) |
| `dogwalker` | DOG WALKER (PAISLEY) / `dogwalker` | 980,1200 / 22×26 | patrol 4 points | npc_spawns.js (ID-keyed record) |
| `busker` | BUSKER / `busker` | 1100,1500 / 24×28 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `horsecop` | HORSE COP / `horsecop` | 1320,1080 / 36×32 | patrol 4 points | npc_spawns.js (ID-keyed record) |
| `vapelord` | THE VAPE LORD / `vapelord` | 840,1100 / 28×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `pothole` | A POTHOLE (TALKING) / `pothole` | 980,920 / 32×18 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `mayorscousin` | MAYOR'S COUSIN / `mayorscousin` | 1340,1500 / 28×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `phoneguy` | THE PHONE GUY / `phoneguy` | 1180,1480 / 24×28 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `barb` | BAGGIE BARB / `barb` | 1540,1190 / 28×32 | vendor; legacy structure 4 | npc_spawns.js (ID-keyed record) |
| `pinky` | PINKY POLENTA / `pinky` | 1330,1160 / 26×32 | vendor | npc_spawns.js (ID-keyed record) |
| `math` | THE MATHEMATICIAN / `math` | 1340,380 / 26×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `train_hopper` | THE TRAIN HOPPER / `train_hopper` | 820,2940 / 26×32 | daytimeOnly | npc_spawns.js (ID-keyed record) |
| `philosopher` | PARK BENCH PHILOSOPHER / `philosopher` | 2680,1080 / 26×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `lease_guy` | THE LEASING GUY / `lease_guy` | 5400,3100 / 28×32 | essential | npc_spawns.js (ID-keyed record) |
| `gutter_greg` | GUTTER GREG / `gutter_greg` | 4500,2050 / 26×32 | essential | npc_spawns.js (ID-keyed record) |
| `laundromat_lady` | LAUNDROMAT LADY / `launderlady` | 1720,1180 / 28×32 | legacy structure 4 | npc_spawns.js (ID-keyed record) |
| `meter_maid` | METER MAID / `metermaid` | 1380,920 / 26×30 | patrol 4 points; aggroOnHit | npc_spawns.js (ID-keyed record) |
| `food_truck` | FOOD TRUCK GUY / `foodtruck` | 920,1500 / 30×32 | stationary dialogue | npc_spawns.js (ID-keyed record) |
| `priests_son` | THE PRIEST'S SON / `priestson` | 1740,1480 / 24×28 | legacy structure 3 | npc_spawns.js (ID-keyed record) |
| `karaoke` | KARAOKE MIKE / `karaoke` | 1660,1180 / 24×28 | legacy structure 4 | npc_spawns.js (ID-keyed record) |
| `skid_brutus_1` | BRUTUS (SKID) / `brutus` | 2700,1820 / 32×24 | charger; hostile; zoneOnly | npc_spawns.js (ID-keyed record) |
| `skid_lurch` | LURCH (SKID) / `lurch` | 3020,1940 / 28×34 | grabber; hostile; robs=true; zoneOnly | npc_spawns.js (ID-keyed record) |
| `skid_sherri` | SHERRI (SKID) / `sherri` | 2860,2080 / 26×30 | swarmer; hostile; zoneOnly; legacy structure 13 | npc_spawns.js (ID-keyed record) |

Preserve each base record's `hp`, `maxHp`, `speed`, `dmg`, patrol points, `zoneOnly`, sleep/day flags, `essential`, aggro behavior and interaction binding. In particular `lurch` is **55HP** in the full source; the slice's 120HP encounter is not that contract. `skid_lurch` alone has robbery enabled; neither back-alley Lurch nor kingdom grabbers acquire that flag by sharing an archetype. Pete's shop schedule and night closures must be ported, not replaced with an always-open slice transaction.

### Kingdom population and 60+ production coverage

| Family / runtime ID format | Initial count | Source post centers | Identity / lifecycle |
| --- | --- | --- | --- |
| `kingdom_guard_blue_tarp_<day>_<index>` | 4 | 6060,660; 6140,1120; 6800,700; 6500,1180 | TARP KNIGHT |
| `kingdom_guard_cart_cavalry_<day>_<index>` | 4 | 7440,1840; 7540,2240; 8240,1840; 7800,1800 | CART LANCER |
| `kingdom_guard_copper_choir_<day>_<index>` | 4 | 6040,3200; 6500,3200; 6940,3220; 7040,3700 | WIRE DEACON |
| `kingdom_guard_throne_<day>_<index>` | 3 | 7140,4680; 7500,4700; 7800,5000 | KNIGHT EMERITUS |

`syncKingdomForces()` (`campaigns.js:516`) yields 4 guards in each undefeated outer court + 3 throne guards. A defeated outer court retains 2; completed throne retains 2. Current boss-stage guards for that court are removed, not layered under the boss. Royal actors keep `zoneOnly` and `noComboReward`; they are actual production residents, not a generic crowd fill.

| Boss ID | Name / art | Boss center | Banner | Adds | Zone |
| --- | --- | --- | --- | --- | --- |
| `darryl_under_blue` | DARRYL UNDER BLUE / `darryl_under_blue` | 6500,760 | 6500,900 | 6200,720; 6800,720 | blue_tarp_court |
| `general_receipt` | GENERAL RECEIPT / `general_receipt` | 7860,2050 | 7860,2320 | 7500,1980; 8220,1980 | cart_cavalry_keep |
| `bishop_wire` | BISHOP WIRE / `bishop_wire` | 6510,3480 | 6510,3700 | 6140,3460; 6880,3460 | copper_choir_yard |
| `curb_emperor` | THE CURB EMPEROR / `curb_emperor` | 7680,4880 | 7680,5200 | 7240,4800; 8120,4800 | throne_ditch |

Boss additions use `kingdom_add_<bossId>_<index>`; two named clerks/deacons/knights are taken from each definition. `curb_pretender_<day>` is one daily post-coronation enemy at the day-selected outer ruler post, named `CURB PRETENDER No. N`, and can pay only once per day (`campaigns.js:531`).

A legitimate **60-NPC** scenario is the untouched 56 fresh residents plus the existing four-live-cop cap (`combat.js:594`). A **61-NPC** scenario additionally triggers the canonical Sherri sibling while keeping all other residents. Use those production spawners and actual AI/state/collision; do not clone six art meshes and call that full-AI proof. They occupy their authored districts, so run a camera traversal while all 60+ logical agents remain active. A separately declared dense art/idle test can measure worst visible rendering, but must not falsify zoneOnly to represent normal gameplay.

### Conditional identities and instances

| ID / family | Identity | Spawn / condition | Source |
| --- | --- | --- | --- |
| tony (same instance) | TRE BAG TONY | boss transformation, 200HP, three phases; two sherri_boss_<suffix> adds in phase 2 | combat.js:120; update.js:754 |
| sherri_<suffix> | SPIDER-BITE SHERRI | one sibling from base Sherri; cap2 live matching swarmers, proximity guard | combat.js:29 |
| sherri_boss_<suffix> | SPIDER-BITE SHERRI | two Tony reinforcements | update.js:773 |
| brutus_older | BRUTUS THE OLDER | player+(100,100), clamped; street-loved changes hostility; 200HP | activities.js:253 |
| sherri_brutus_<suffix> | SPIDER-BITE SHERRI | older-Brutus phase reinforcements | update.js:842 |
| os_brutus | OLD SCHOOL BRUTUS | (3730,780), 36×28; first rip forces encounter; later 40% risk; 250HP | vendors_places.js:474 |
| price_guy | THE PRICE GUY | (2940,1860), 26×32; every third day; one current-day visit | vendors_places.js:494 |
| freed_dog_follower | THE DOG | relative to player; single temporary companion, not new canonical identity | neighborhood_a.js:196 |
| pet_possum | YOUR POSSUM | player+(-30,12), 28×24; singular follower | communications.js:42 |
| day3_visitor_<timestamp> | SOMEONE YOU DON'T KNOW | player+(80,30), clamped; leaves after dialogue | daily_hideouts.js:40 |
| bus_driver | THE BUS DRIVER | (1330,1260), 24×28; day30, irreversible ride/refusal | daily_hideouts.js:84 |
| cop_<suffix> | COP | nearest map edge; wanted/radio; four total live police cap | combat.js:458 |
| brendan_<suffix> | COUSIN BRENDAN | wanted≥2, 30% replacement spawn; at most1 live Brendan within police cap | combat.js:497 |
| priest (same instance) | FATHER O'MALLEY (FALLEN) | combat mutation, registered alias; not a second priest | combat.js / npc-registry-gate.mjs |

Canonical accounting: 38 base identities + 4 guard identities + 4 rulers + 7 conditional identities (older Brutus, OS Brutus, Price Guy, Your Possum, day-3 visitor, bus driver, pretender) + 2 police identities + 8 modal-only registered speakers = 63. The three skid names and fallen-priest name are aliases, not four extra identities. No generic new civilian name is needed to meet performance targets.

## Place interactions and address mapping

Preserve the source interaction precedence: owned office/hideout/old-school/kingdom doors → kingdom/office field targets → route stamps → nearest eligible NPC → copper/break-in site → bench → trash can → ringing pay phone → cart → dumpster → zone verbs (Block, market, concession/discovery) → pocket fallback. `interactions.js:43` is the authoritative order. In 3D, aiming/rays add occlusion but cannot silently change who receives the action when colocated or mask the zone/pocket fallback. Hint and executed action must share the resolver.

| Anchor type | ID / binding | Source geometry | 3D mapping contract |
| --- | --- | --- | --- |
| Block zone / crate | block, PROPS[32] | zone(880,720,340,240); smoke point(1064,882) | crate helps locate the verb; original Block zone action remains available when higher priorities miss |
| Cart | PROPS[5] / RIDEABLE_CART_SPAWN | (1000,1600); one rideable cart | one mutable transport state + physical cart model; never duplicate it when a chunk reloads |
| Pay phone | PROPS[52] | (130,220), actual reach38px while ringing | one phone fixture/target; preserve ring window and call side effects |
| Old school | OLD_SCHOOL_DOOR | (3760,700,24,28), 44px approach | rank-gated modal entry; boss emerges in schoolyard |
| Owned hideout | scrap | (520,200,24,32) | ownership and 40px door priority; source shed is not the current slice shed |
| Owned hideout | mom | (1230,1180,24,32) | ownership/rent contract and 40px door priority |
| Office | OFFICE_DOOR | (4908,3204,24,32) | distinct office type; never hideoutOwned('office') |
| Kingdom door | blue | 6818,464,24,32 | 44px approach; authored refusal/recognition, not an invented interior |
| Kingdom door | cart | 8108,1744,24,32 | 44px approach; authored refusal/recognition, not an invented interior |
| Kingdom door | wire | 6818,3064,24,32 | 44px approach; authored refusal/recognition, not an invented interior |
| Kingdom door | throne | 8038,4484,24,32 | 44px approach; authored refusal/recognition, not an invented interior |
| Copper site | abandoned | BUILDINGS[2] (1560,160,360,240) | brutus jr.; shared staged heist engine |
| Copper site | cold_not | {"kind":"rect","facadeId":"cold_not","x":4440,"y":1080,"w":450,"h":230} | dennis (nights); shared staged heist engine |
| Copper site | water_dept | {"kind":"rect","facadeId":"water_dry","x":4460,"y":2250,"w":520,"h":210} | the raccoon quorum; shared staged heist engine |
| Copper site | rust_car | {"kind":"rect","propType":"freight_car","x":380,"y":2820,"w":220,"h":64} | transit authority dan; shared staged heist engine |
| Break-in | model_home | {"kind":"rect","propType":"breakin_shell","x":950,"y":4350,"w":240,"h":150} | the model family; ordered gates: crowbar |
| Break-in | spoil_bank | {"kind":"rect","propType":"breakin_shell","x":3350,"y":4450,"w":260,"h":140} | the former teller; ordered gates: cred 25 |
| Break-in | sod_office | {"kind":"rect","propType":"breakin_shell","x":4800,"y":5050,"w":240,"h":130} | the goose (manager); ordered gates: crowbar then cred 50 |
| Break-in | drained_pool | {"kind":"rect","propType":"breakin_shell","x":1880,"y":3820,"w":250,"h":140} | the lifeguard (still certified); ordered gates: crowbar |
| Break-in | visitor_center | {"kind":"rect","propType":"breakin_shell","x":2960,"y":3840,"w":240,"h":130} | the docent (self-guided); ordered gates: cred 20 |

Modal speaker coverage comprises `brutus jr.` (longstanding abandoned-building dialogue, not a registry/runtime NPC row), and the eight registered speakers Dennis, Raccoon Quorum, Transit Authority Dan, Model Family, Former Teller, Goose, Lifeguard and Docent. Do not invent runtime IDs for them just to inflate population. Preserve modal entry/exit/stage state; author interior representations only when they help the existing interaction, without adding cutscenes.

Copper/break-in lookup uses the source rectangle expanded ±20px, strict inequalities (`props.js:506`); its trigger is not a generic 3m door ray. NPC range is 60px, dumpster44px, bench/trash50px, cart36px, phone38px; all need a named 3D conversion or explicit first-person adapter. Current slice reach3.2m is not equivalent to those differentiated radii.

| Smoke ID | Anchor | Condition beyond earned recognition |
| --- | --- | --- |
| `block` | 1064,882 | unconditional base spot |
| `park` | 2540,1046 | night |
| `choir_office` | 6830,3096 | office-hours open |
| `underpass` | 1210,350 | freed dog physically present |
| `laundromat` | 1540,1190 | dryer middle cycle |

Four recognition venues retain 3/8/15 thresholds, discovery≠permission, and condition recheck at execution. No extra smoke spot is added to solve distance. The source royal-static/coronation action remains Block-only.

| Route stop ID | Coordinate | Unlock flag |
| --- | --- | --- |
| `block_news` | 900,1010 | none |
| `scrap_gate` | 360,468 | none |
| `pawn_sill` | 390,690 | none |
| `under_sign` | 1340,478 | none |
| `corner_curb` | 1475,965 | none |
| `bus_glass` | 1285,1170 | none |
| `laundry_sock` | 1788,1190 | none |
| `market_line` | 1120,1350 | none |
| `alley_can` | 300,1560 | none |
| `church_step` | 1800,1592 | none |
| `project_meter` | 650,1810 | none |
| `train_signal` | 310,2750 | none |
| `park_fountain` | 2700,1140 | none |
| `skid_drain` | 3315,1940 | none |
| `school_chain` | 3760,760 | none |
| `motel_no` | 3025,1045 | none |
| `warehouse_manifest` | 4930,850 | warehouseRowEntered |
| `canal_gauge` | 5420,2070 | canalEntered |
| `lot_meter` | 4440,3140 | theLotEntered |
| `tarp_docket` | 6020,1180 | blueTarpCleared |
| `cart_barrier` | 7440,2380 | cartKeepCleared |
| `choir_register` | 7000,3760 | copperChoirCleared |
| `ditch_gauge` | 7120,5240 | throneDitchCleared |

| Claim ID | Definition |
| --- | --- |
| `canal` | {"id":"canal","name":"THE DRAINAGE CANAL","faction":"neutral","survey":{"x":5420,"y":2070,"task":"read the water gauge while the water is absent.","stamp":"gauge says nine.\nwater says nothing."},"sign":{"x":4380,"y":2110,"task":"install the WATER PENDING sign.","stamp":"the sign leans east.\nthe canal is entered as pending."}} |
| `alley` | {"id":"alley","name":"BACK ALLEY","faction":"street","survey":{"x":620,"y":1300,"task":"measure the alley entrance using your arms.","stamp":"two arms wide.\narm standard not attached."},"sign":{"x":620,"y":1640,"task":"install the RESIDENT OFFICE sign.","stamp":"the wall accepts one nail.\nthe second nail is theoretical."}} |
| `projects` | {"id":"projects","name":"THE PROJECTS","faction":"street","survey":{"x":300,"y":1810,"task":"record building a as two buildings.","stamp":"one building. letter a.\ntwo entered."},"sign":{"x":130,"y":1810,"task":"install the BUILDING LETTER sign.","stamp":"the sign says building c.\nthere is no building c."}} |
| `skidrow` | {"id":"skidrow","name":"SKID ROW","faction":"street","survey":{"x":3330,"y":2180,"task":"count the east curb without entering traffic.","stamp":"one curb.\ntwo opinions."},"sign":{"x":2500,"y":1560,"task":"install the NO VACANCY sign.","stamp":"no vacancy.\nseveral vacancies object."}} |
| `scrap` | {"id":"scrap","name":"SCRAP YARD","faction":"scrap","survey":{"x":360,"y":420,"task":"inventory the gate as two gates.","stamp":"one gate.\ntwo entered."},"sign":{"x":590,"y":420,"task":"install the METAL OFFICE sign.","stamp":"the sign is mostly rust.\nyuri calls that pure."}} |
| `underpass` | {"id":"underpass","name":"HIGHWAY UNDERPASS","faction":"scrap","survey":{"x":1070,"y":430,"task":"count the bridge supports from below.","stamp":"four supports.\none bridge. no receipt."},"sign":{"x":1360,"y":250,"task":"install the CEILING DEPARTMENT sign.","stamp":"the sign points up.\nthe highway continues ignoring it."}} |
| `oldschool` | {"id":"oldschool","name":"OLD SCHOOL","faction":"scrap","survey":{"x":3460,"y":860,"task":"inspect the court line for education.","stamp":"chalk. chain.\nno curriculum."},"sign":{"x":4100,"y":860,"task":"install the ALUMNI OFFICE sign.","stamp":"the school did not attend.\nthe form says present."}} |
| `warehouse_row` | {"id":"warehouse_row","name":"WAREHOUSE ROW","faction":"scrap","survey":{"x":4930,"y":850,"task":"compare the manifest to both warehouses.","stamp":"unit 14. returns.\nneither is unit 14."},"sign":{"x":5450,"y":850,"task":"install the RECEIVING sign.","stamp":"receiving refuses delivery.\nsign delivered."}} |
| `market` | {"id":"market","name":"MARKETPLACE","faction":"spiritual","survey":{"x":740,"y":1600,"task":"locate the checkout line after checkout.","stamp":"the line moved around you.\nyou were not in it."},"sign":{"x":1390,"y":1600,"task":"install the CUSTOMER SERVICE sign.","stamp":"no customer requested service.\nservice documented."}} |
| `park` | {"id":"park","name":"THE PARK","faction":"spiritual","survey":{"x":2450,"y":1360,"task":"ask the dry bench if it is public.","stamp":"the bench remains silent.\npublic entered as yes."},"sign":{"x":2980,"y":1360,"task":"install the RECREATION OFFICE sign.","stamp":"two pigeons witnessed.\nneither signed."}} |
| `trainyard` | {"id":"trainyard","name":"TRAIN YARD","faction":"spiritual","survey":{"x":1320,"y":3200,"task":"verify the last rail also goes nowhere.","stamp":"rail continues west.\ntrain continues not arriving."},"sign":{"x":300,"y":3200,"task":"install the ARRIVALS OFFICE sign.","stamp":"arrivals: zero.\noffice: open."}} |

## Props and catalogs

| PROPS type | Count |
| --- | --- |
| dumpster | 10 |
| cart | 1 |
| lamp | 11 |
| hydrant | 4 |
| mailbox | 3 |
| cone | 6 |
| trash | 23 |
| crate | 4 |
| syringe | 5 |
| bottle | 6 |
| tent | 8 |
| cardsign | 12 |
| scrap_pile | 10 |
| car_wreck | 6 |
| leash_post | 1 |
| pay_phone | 1 |
| freight_car | 3 |
| chalk_message | 1 |
| weeds | 37 |
| fountain | 1 |
| park_bench | 6 |
| swing_set | 2 |
| drink_fountain | 2 |
| tree | 7 |
| school_mural | 1 |
| broken_hoop | 1 |
| school_fence | 5 |
| broken_window | 5 |
| cart_husk | 6 |
| breakin_shell | 5 |

| WORLD_DECOR type | Count |
| --- | --- |
| bus_shelter | 5 |
| billboard | 4 |
| water_tower | 1 |
| motel_sign | 2 |
| clothesline | 5 |
| crossbuck | 1 |
| rail_signal | 3 |
| news_box | 7 |
| road_barrier | 10 |
| storm_drain | 25 |
| utility_pole | 29 |
| burn_barrel | 4 |

| Equipment ID | Slot | Speed delta / HP / other |
| --- | --- | --- |
| `airpods` | shoes | +0 / 0HP / -1cred |
| `crocs` | shoes | +0.6 / 0HP / -5cred |
| `walmart_sneak` | shoes | +0.2 / 0HP / 0cred |
| `vibrams` | shoes | +0.4 / 0HP / -3cred |
| `mesh_cap` | hat | +0 / 0HP / 2cred |
| `ski_mask` | hat | +0 / 0HP / 4cred |
| `helmet` | hat | +0 / 8HP / 6cred |
| `cowboy` | hat | +0 / 0HP / 3cred |
| `trench` | coat | -0.1 / 8HP / 3cred |
| `windbreaker` | coat | +0.1 / 4HP / 1cred |
| `bathrobe` | coat | +0 / 6HP / -2cred |
| `parka` | coat | -0.2 / 12HP / 4cred |
| `pigeon_crown` | hat | +0 / 0HP / -3cred / charisma1 |
| `propane_torch` | tool | +0 / 0HP / 0cred |
| `crowbar` | tool | +0 / 0HP / 0cred |
| `priest_collar` | hat | +0 / 0HP / 2cred / wantedDecay0.3 |

Vendor discovery/index IDs: `tony`, `yuri`, `pete`, `barb`, `biggu`, `conductor`, `larry`, `paulie`, `stripe`, `mom`, `priest`, `pinky`, `math`, `train_hopper`, `philosopher`, `lease_guy`, `gutter_greg`. All 17 IDs have metadata. The 10 phone call entries include action closures; omit only the executable closure from data export and explicitly record the missing binding. The 66 graffiti entries and six crown spots are content, not proof of their placement/scheduling engine.

**Known source defect to record, not copy as mechanics:** `catalogs.js:171` still claims priest tic-tacs reduce shakes by30. VIBE's corrected contract and actual dialogue give +5 brain without shake relief. The port must carry actual transaction outcomes; a stale index tag is not a balance authority. VIBE's Tony fixed-stare rule also does not authorize implementing ambient blink animation from the isolated legacy `tony_blinks` random-event text.

### Complete placed-prop address ledger

The first column is an audit reference to the authored array slot, not a newly invented source ID. Retain position, dimensions, variant, sign/text and mutable flags when exporting. Four crates are not four smoke anchors; `cart_husk` is not another rideable cart; `bottle` scenery is not an interactive `b_bottle`.

| PROPS index | Type | Position | Dimensions / variant / notable data |
| --- | --- | --- | --- |
| 0 | `dumpster` | 140,1320 | 36×24 |
| 1 | `dumpster` | 440,1640 | 36×24 |
| 2 | `dumpster` | 1340,1480 | 36×24 |
| 3 | `dumpster` | 1620,280 | 36×24 |
| 4 | `dumpster` | 780,240 | 36×24 |
| 5 | `cart` | 1000,1600 | 24×20 |
| 6 | `lamp` | 740,840 |  |
| 7 | `lamp` | 1340,840 |  |
| 8 | `lamp` | 1740,1100 |  |
| 9 | `lamp` | 240,1100 |  |
| 10 | `lamp` | 1600,1700 |  |
| 11 | `lamp` | 840,1700 |  |
| 12 | `lamp` | 340,560 |  |
| 13 | `lamp` | 1500,560 |  |
| 14 | `lamp` | 1240,340 |  |
| 15 | `lamp` | 1100,1200 |  |
| 16 | `hydrant` | 680,920 |  |
| 17 | `hydrant` | 1480,1200 |  |
| 18 | `hydrant` | 280,1240 |  |
| 19 | `hydrant` | 1740,1660 |  |
| 20 | `mailbox` | 920,1100 |  |
| 21 | `mailbox` | 1500,1000 |  |
| 22 | `mailbox` | 440,840 |  |
| 23 | `cone` | 1080,340 |  |
| 24 | `cone` | 1200,380 |  |
| 25 | `cone` | 1360,420 |  |
| 26 | `cone` | 380,380 |  |
| 27 | `trash` | 240,1500 |  |
| 28 | `trash` | 380,1620 |  |
| 29 | `trash` | 120,1380 |  |
| 30 | `trash` | 1640,340 |  |
| 31 | `trash` | 1800,240 |  |
| 32 | `crate` | 1050,880 |  |
| 33 | `crate` | 1080,870 |  |
| 34 | `syringe` | 280,1440 |  |
| 35 | `syringe` | 520,1540 |  |
| 36 | `syringe` | 420,1340 |  |
| 37 | `bottle` | 340,1620 |  |
| 38 | `bottle` | 580,1380 |  |
| 39 | `bottle` | 1380,1520 |  |
| 40 | `tent` | 1060,330 |  |
| 41 | `tent` | 1120,380 |  |
| 42 | `tent` | 1230,350 |  |
| 43 | `tent` | 1300,400 |  |
| 44 | `cardsign` | 1340,412 | WILL TRADE / WORDS FOR / MATH |
| 45 | `scrap_pile` | 200,200 | 32×18 |
| 46 | `scrap_pile` | 520,340 | 36×20 |
| 47 | `scrap_pile` | 380,380 | 28×16 |
| 48 | `scrap_pile` | 160,330 | 30×18 |
| 49 | `car_wreck` | 430,160 | 60×28 |
| 50 | `car_wreck` | 240,380 | 62×30 |
| 51 | `leash_post` | 570,130 |  |
| 52 | `pay_phone` | 130,220 |  |
| 53 | `freight_car` | 380,2820 | 220×64 |
| 54 | `freight_car` | 720,2900 | 240×64 |
| 55 | `freight_car` | 1040,2780 | 200×60 |
| 56 | `chalk_message` | 760,2898 | the bus knows where / the train doesn't go |
| 57 | `weeds` | 540,2730 |  |
| 58 | `weeds` | 990,2880 |  |
| 59 | `weeds` | 320,3100 |  |
| 60 | `weeds` | 1230,3060 |  |
| 61 | `weeds` | 700,3180 |  |
| 62 | `weeds` | 470,2980 |  |
| 63 | `fountain` | 2700,1140 |  |
| 64 | `park_bench` | 2520,1040 | 40×12 |
| 65 | `park_bench` | 2880,1040 | 40×12 |
| 66 | `park_bench` | 2520,1240 | 40×12 |
| 67 | `park_bench` | 2880,1240 | 40×12 |
| 68 | `swing_set` | 2480,1320 |  |
| 69 | `drink_fountain` | 2820,1340 |  |
| 70 | `tree` | 2460,950 |  |
| 71 | `tree` | 2980,970 |  |
| 72 | `tree` | 2460,1350 |  |
| 73 | `tree` | 2980,1330 |  |
| 74 | `tree` | 2620,970 |  |
| 75 | `tree` | 2820,970 |  |
| 76 | `trash` | 2580,1620 |  |
| 77 | `trash` | 2780,1700 |  |
| 78 | `trash` | 2980,1680 |  |
| 79 | `trash` | 3200,1820 |  |
| 80 | `trash` | 2640,1900 |  |
| 81 | `trash` | 2880,2000 |  |
| 82 | `trash` | 3100,2080 |  |
| 83 | `trash` | 2700,2160 |  |
| 84 | `dumpster` | 2820,1780 | 36×24 |
| 85 | `dumpster` | 3100,1980 | 36×24 |
| 86 | `lamp` | 2920,1880 |  |
| 87 | `bottle` | 2680,1740 |  |
| 88 | `bottle` | 3040,1840 |  |
| 89 | `bottle` | 2780,2040 |  |
| 90 | `syringe` | 2960,1660 |  |
| 91 | `syringe` | 3220,1940 |  |
| 92 | `school_mural` | 3530,720 | FUTU EA HE M C |
| 93 | `swing_set` | 3520,800 |  |
| 94 | `broken_hoop` | 3920,540 |  |
| 95 | `school_fence` | 3420,880 | 720×6 |
| 96 | `weeds` | 3640,350 |  |
| 97 | `weeds` | 3820,480 |  |
| 98 | `weeds` | 3500,620 |  |
| 99 | `weeds` | 4040,760 |  |
| 100 | `weeds` | 3760,820 |  |
| 101 | `weeds` | 3960,380 |  |
| 102 | `broken_window` | 3600,460 |  |
| 103 | `broken_window` | 3700,460 |  |
| 104 | `broken_window` | 3800,460 |  |
| 105 | `broken_window` | 3900,460 |  |
| 106 | `broken_window` | 4000,460 |  |
| 107 | `scrap_pile` | 4430,820 | 36×20 |
| 108 | `scrap_pile` | 5200,850 | 34×18 |
| 109 | `car_wreck` | 4860,760 | 62×30 |
| 110 | `dumpster` | 5350,760 | 36×24 |
| 111 | `cardsign` | 4930,850 | MANIFEST / PENDING |
| 112 | `weeds` | 4440,900 |  |
| 113 | `weeds` | 5480,880 |  |
| 114 | `cardsign` | 4380,1640 | CITY WATER / IS A THEORY |
| 115 | `school_fence` | 4560,2120 | 120×6 |
| 116 | `trash` | 4700,2040 |  |
| 117 | `trash` | 5260,1740 |  |
| 118 | `weeds` | 4380,2180 |  |
| 119 | `weeds` | 5560,1580 |  |
| 120 | `dumpster` | 5480,2140 | 36×24 |
| 121 | `car_wreck` | 4380,3340 | 60×28 |
| 122 | `dumpster` | 5320,3400 | 36×24 |
| 123 | `trash` | 4560,3420 |  |
| 124 | `trash` | 5220,2780 |  |
| 125 | `weeds` | 4340,3500 |  |
| 126 | `weeds` | 5480,3480 |  |
| 127 | `tent` | 5980,650 |  |
| 128 | `tent` | 6040,820 |  |
| 129 | `tent` | 6900,650 |  |
| 130 | `tent` | 6960,820 |  |
| 131 | `cardsign` | 5960,600 | COURT OPEN / ROOF PENDING |
| 132 | `trash` | 5960,1260 |  |
| 133 | `trash` | 7040,300 |  |
| 134 | `school_fence` | 5920,1280 | 1160×6 |
| 135 | `weeds` | 5940,300 |  |
| 136 | `weeds` | 7040,1260 |  |
| 137 | `cart_husk` | 7420,1810 | 24×20 |
| 138 | `cart_husk` | 7480,2250 | 24×20 |
| 139 | `cart_husk` | 8240,1810 | 24×20 |
| 140 | `cart_husk` | 8280,2250 | 24×20 |
| 141 | `cart_husk` | 7440,2100 | 24×20 |
| 142 | `cart_husk` | 8260,2070 | 24×20 |
| 143 | `school_fence` | 7420,2380 | 840×6 |
| 144 | `cone` | 7380,1500 |  |
| 145 | `cone` | 8340,2400 |  |
| 146 | `cardsign` | 7440,1780 | CARTS FORM / ONE UNIT |
| 147 | `scrap_pile` | 5980,3200 | 36×20 |
| 148 | `scrap_pile` | 7000,3200 | 36×20 |
| 149 | `scrap_pile` | 5980,3540 | 36×20 |
| 150 | `scrap_pile` | 7000,3540 | 36×20 |
| 151 | `car_wreck` | 6100,3160 | 62×30 |
| 152 | `cardsign` | 7000,3760 | B FLAT / RECEIVED |
| 153 | `school_fence` | 5920,3840 | 1220×6 |
| 154 | `weeds` | 5960,3100 |  |
| 155 | `weeds` | 7060,3820 |  |
| 156 | `breakin_shell` | 950,4350 | 240×150; model_home; MODEL HOME |
| 157 | `breakin_shell` | 3350,4450 | 260×140; spoil_bank; BANK (FORMER) |
| 158 | `breakin_shell` | 4800,5050 | 240×130; sod_office; SOD · OFFICE |
| 159 | `cardsign` | 1000,4530 | IF YOU LIVED HERE / YOU WOULD BE / HOME NOW |
| 160 | `weeds` | 920,4520 |  |
| 161 | `weeds` | 1220,4380 |  |
| 162 | `weeds` | 3320,4610 |  |
| 163 | `weeds` | 3640,4470 |  |
| 164 | `weeds` | 4770,5200 |  |
| 165 | `weeds` | 5070,5090 |  |
| 166 | `breakin_shell` | 1880,3820 | 250×140; drained_pool; MUNICIPAL POOL |
| 167 | `breakin_shell` | 2960,3840 | 240×130; visitor_center; VISITOR CENTER |
| 168 | `cardsign` | 1930,3990 | CLOSED FOR / WINTER / (2011) |
| 169 | `cardsign` | 3010,4000 | YOU ARE HERE |
| 170 | `weeds` | 1850,3980 |  |
| 171 | `weeds` | 2160,3860 |  |
| 172 | `weeds` | 2930,3990 |  |
| 173 | `weeds` | 3230,3880 |  |
| 174 | `park_bench` | 7580,400 | 40×12 |
| 175 | `park_bench` | 7650,400 | 40×12 |
| 176 | `drink_fountain` | 7720,420 |  |
| 177 | `tree` | 7530,360 |  |
| 178 | `cardsign` | 7600,460 | SCENIC OVERLOOK / THE VIEW IS / BEING DISCUSSED |
| 179 | `cardsign` | 7740,470 | DO NOT / FEED THE |
| 180 | `weeds` | 7550,470 |  |
| 181 | `weeds` | 7700,380 |  |
| 182 | `weeds` | 7810,440 |  |
| 183 | `cardsign` | 7660,4540 | ONE CHAIR / NO APPEALS |
| 184 | `crate` | 7630,4565 |  |
| 185 | `crate` | 7690,4565 |  |
| 186 | `trash` | 7080,4620 |  |
| 187 | `trash` | 8280,4620 |  |
| 188 | `trash` | 7080,5120 |  |
| 189 | `trash` | 8280,5120 |  |
| 190 | `car_wreck` | 8160,5050 | 60×28 |
| 191 | `weeds` | 7060,4260 |  |
| 192 | `weeds` | 8300,5280 |  |

Fixed cash IDs are `cp_0` through `cp_27` (28 records) plus conditional `cp_intro_remember`. Dynamic families include `cp_phone_church_<timestamp>`, `cp_inheritance_<timestamp>` and combat/loot drops; reuse their single ledger semantics and lifecycle. Do not reuse the slice `cash_1..3` save keys.

## Exact proposed coordinate and routing contract

**Proposal for the next spec, not a claim of ratification:** keep exported coordinates in raw source pixels. Use a named adapter `S=0.04 metres/pixel`, X east and Z south, with origin at the canonical Block smoke anchor `(1064,882)`: `world_x=(source_center_x-1064)*S`, `world_z=(source_center_y-882)*S`, ground Y=0. Actor source coordinates are top-left: add half `w,h` exactly once. Rectangles convert min/max corners; waypoints/doors/point objectives use their documented point/rectangle-center rule. Inverse conversion remains exact for source zone, route and save logic.

This yields **344×224m**, X **[-42.56,301.44]**, Z **[-35.28,188.72]**; fresh player center `(1062,854)` becomes `(-0.08,-1.12)`. A 64px tile is2.56m, 108px road4.32m, pawn160px width6.4m. Do not scale character vertical height from the top-down collision height: human height stays authored around1.7m, with identity differences.

| Scale | Full extent | Walking speed preserving source time | 108px road | Tradeoff |
| --- | --- | --- | --- | --- |
| 0.026181818 (=3.6/137.5) | 225.164×146.618m | 3.6m/s | 2.828m | matches slice walk speed; narrow street footprints |
| 0.03125 (=1/32) | 268.75×175m | 4.296875m/s | 3.375m | middle geometry scale |
| 0.04 | 344×224m | 5.5m/s | 4.32m | more readable streets/buildings; faster first-person base motion |

The source body is **24×28px for the player**, usual NPC28×32px. At .04 those logical footprints are .96×1.12m and1.12×1.28m; **16px is commonly a half-body center offset, not full body width**. Retaining current .60/.68m capsule diameters is a collision change, not exact scaling. Recommended implementation keeps a source-space footprint/door query for navigation and reach, with a separately authored visible body and calibrated 3D collider; tests must cover disagreement. Do not blindly call `ensureClearPlacement()` on the eight intentional legacy actors.

At S=.04 exact baseline rates are walk5.5m/s, sprint9.35m/s, high9.9m/s, high+sprint16.83m/s, crash2.75m/s. Equipment source speed deltas multiply by `1000/16*S=2.5`; e.g. crocs+0.6→+1.5m/s before other multipliers. NPC motion uses the corresponding source-rate conversion. Projectile source px/s uses S directly, not the16ms movement factor.

All exact scale/rate pairs preserve the same time stress. Prior collision-aware gate readings (`reports/2026-11-18-3d-character-street-legacy-gates.txt:26`): Block→throne banner57.802s; pawn_sill↔ditch_gauge59.400s (99.001% of60s); forbidden scrap_gate↔ditch_gauge60.542s. The last is the one ratified excluded pair, not a route to restore. A naive first-person walk has only0.600s of headroom on the longest valid route.

Run baseline physical walks first. If necessary, propose a single explicit **1.05–1.10 mobility calibration**, preserving relative movement and additive equipment relationships, rather than secretly altering shakes/high/crash timers or removing content. At 1.05 the59.400s motion component becomes56.571s; at1.10 it becomes54.000s, leaving3.429/6.000s for first-person orientation and door approach. This is a named behavior deviation requiring the full-port spec/register decision, with NPC pursuit and projectile relationships assessed together. It is not silently baked into source-data export.

Routing invariants: preserve 23-zone adjacency, all existing road connections, corridor widths, south apertures, all69 objective-selector campaign legs and252 assignable route pairs. Never route straight through a visible wall to meet a budget. Test actual input-driven capsule walks with turns, doors and occlusion; pure Euclidean/navigation lengths are lower bounds. Derived budgets remain walk137.5px/s, shakes0.8/s, fresh shakes20,100s runway,60s mandatory leg and45s coverage in source terms. Source active gameplay milliseconds, modal pause and day/night clocks remain authoritative.

## Construction and performance plan

1. Export source data deterministically first, with exact module/export names, array order and hashes. Keep callbacks explicitly unimplemented in the export. Add a coverage matrix binding each source ID/index to a 3D presentation and simulation handler; zero invented economy or NPC identity rows.
2. Build a full-world logical registry and immutable source-backed collision/interaction definitions. Spawn all41 base actors plus15 production guards. Port their action/state handlers separately; stable source IDs own saves, regardless of loaded scene chunks.
3. At S=.04 use **32m render cells (800 source pixels)**: 11×7=77 cells. Keep the tiny global53-structure collision/navigation registry and all population state loaded; stream/cull art, never the state itself. Geometry spanning cells must be split or assigned conservative multi-cell visibility bounds; the current batcher groups by instance origin only and does not cut oversized meshes.
4. Keep near cells detailed (candidate radius64m), distant buildings reduced (64–128m), and skyline beyond as silhouettes; these are proposed tuning bands, to be profiled. No runtime full-city mesh rebuild. Prebuilt per-cell batches share cached material palettes. Visible structural walls retain collision whether art detail is culled. Interactive models remain independent of static batches.
5. Simulate60+ production agents continuously at the accepted fixed simulation cadence initially. Cache navigation paths; recompute on blocked movement/meaningful target drift, not every frame. Visual animation can stop outside visibility without freezing wanted decay, patrol state, companion windows, day events, bosses or rewards. Reduced-rate distant AI is a separate semantic change requiring differential fixtures, not the default shortcut.
6. Use pooled actor presentations keyed by stable ID and reusable species/cloth parts. Keep readable distinct cast silhouettes. Fixture lights use small ranges, bounded shadow counts and shared styles. Static signage remains small/mounted. Never use generic crowd clones to substitute for missing residents.
7. Measure CPU logic, physics, draw calls, geometry and frame p95 separately at1280×720 on stated hardware. Current6-body slice reports838 day draws;60-art/idle stress4914 draws and9.052ms frame p95 on RTX3080 (`reports/2026-11-18-3d-character-street-render.txt`). That is not evidence of full-world AI, new chunks, navigation or browser performance. Require desktop and browser measurements after integration.

## Acceptance and counterexamples

- Exact inventory gate:23 zones,53 solids,193 props,28 roads,41 base records,56 fresh production actors,63 canonical names with aliases, source-backed item/place catalogs; no dropped indexes or duplicate keys. Source changes must cause export `--check` failure until reviewed regeneration.
- Body truth: wall ray/melee/projectile occlusion, outward charge stop, narrow alley traversal, all south-door approach regions, source-specific legacy occupants, load recovery at boundaries/intersecting walls.
- Every source NPC interaction is reachable from a valid view at the corresponding place; no dumpster/bin steals Pete's action; vendor closed-hours/refusal paths preserve resources and exits.
- All69 campaign legs and252 legal route pairs physically walkable within accepted budgets, plus the forbidden pair remains excluded. Check the critical59.4s route explicitly; do not compensate by adding a smoke concession.
- State survives crossing chunks: cart remains singular/moved, a looted dumpster stays looted, a fallen enemy stays fallen, royal guards reflect defeat state, Price Guy and companions obey day/window gates, dead NPCs do not respawn from render reload.
- 60/61 real-agent scenario via existing spawners runs with production AI and a traversal camera. Separate dense art stress remains clearly labeled.
- Modal copper/break-in NPCs remain modal speakers unless a later spec deliberately gives them world bodies. No new identity required.

Next bounded packet: deterministic raw-source data export and a drift/identity/count gate. This report identifies the data surface; it does not implement any missing gameplay.
