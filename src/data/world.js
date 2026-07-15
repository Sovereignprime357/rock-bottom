/* Generated from frozen rock_bottom_v19.html.
 * Source seams: constants, zones, and visual world cohesion.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { currentZoneFaction } from './npc_spawns.js';
import { updateTerritory } from '../systems/factions.js';

export let W, H, WORLD, TILE, RANKS, ZONES, TERRAIN_REGIONS, ROAD_SEGMENTS, CROSSWALKS, GROUND_PATHS, RAIL_LINES, LANDMARK_FACADES, WORLD_DECOR, UTILITY_WIRES, WORLD_LIGHTS;

export function init_constants_world() {
  // ---------- constants ----------
  W = 800, H = 600;
  // v19 extends the v18 5800×3800 neighborhood to 8600×5600 without moving any old coordinate.
  // Camera, collision, objective, cop and minimap clamps remain parameterized end-to-end.
  WORLD = { w: 8600, h: 5600 };
  TILE = 64;
  RANKS = [
    { cred: 0,   name: 'stem-tip sucker' },
    { cred: 10,  name: 'sidewalk tweaker' },
    { cred: 25,  name: 'alley rat' },
    { cred: 50,  name: 'strip-mall fiend' },
    { cred: 100, name: 'block captain' },
    { cred: 200, name: 'pipe prophet' },
    { cred: 400, name: 'the glass mayor' },
    { cred: 800, name: 'CRACK LORD SUPREME' },
  ];
  
  // ---------- zones ----------
  // v13 wave 8b — every zone tagged with a faction lean (street / scrap / spiritual / neutral).
  // drives the territory ticker (hated → heat, liked → small bonus, loved → bigger + ambient).
  // see currentZoneFaction() + updateTerritory().
  ZONES = [
    { id: 'block',       name: 'THE BLOCK',           x: 880,  y: 720,  w: 340, h: 240, color: '#3a3220', label: '#e8c040', faction: 'street' },
    { id: 'scrap',       name: 'SCRAP YARD',          x: 100,  y: 80,   w: 520, h: 360, color: '#3a2f1a', label: '#d06030', faction: 'scrap' },
    { id: 'pawn',        name: 'PAWN SHOP',           x: 130,  y: 580,  w: 260, h: 200, color: '#2a2a18', label: '#c08820', faction: 'scrap' },
    { id: 'dealer',      name: "DEALER'S CORNER",     x: 1460, y: 780,  w: 320, h: 250, color: '#3a1810', label: '#d06030', faction: 'street' },
    { id: 'abandoned',   name: 'ABANDONED BUILDING',  x: 1500, y: 100,  w: 480, h: 360, color: '#241818', label: '#8a3a3a', locked: true, faction: 'neutral' },
    // MARKETPLACE is mom's neighborhood (mom NPC stands here). spiritual per wave 8b.
    { id: 'market',      name: 'MARKETPLACE',         x: 700,  y: 1380, w: 720, h: 260, color: '#2a3a20', label: '#a8c030', faction: 'spiritual' },
    { id: 'alley',       name: 'BACK ALLEY',          x: 100,  y: 1280, w: 540, h: 380, color: '#181818', label: '#8a3a3a', faction: 'street' },
    { id: 'church',      name: 'CHURCH',              x: 1600, y: 1300, w: 380, h: 320, color: '#241c2a', label: '#d488d4', faction: 'spiritual' },
    // THE PROJECTS — larry + stripe live here. street-leaning, even though it's hardscrabble.
    { id: 'projects',    name: 'THE PROJECTS',        x: 100,  y: 1700, w: 600, h: 180, color: '#1c1c20', label: '#a0a0c0', faction: 'street' },
    { id: 'underpass',   name: 'HIGHWAY UNDERPASS',   x: 1020, y: 240,  w: 380, h: 220, color: '#1a1a1c', label: '#888888', faction: 'scrap' },
    { id: 'laundromat',  name: 'THE LAUNDROMAT',      x: 1480, y: 1080, w: 320, h: 200, color: '#3a3a44', label: '#88c0ff', labelDy: -8, faction: 'street' },
    // v13 wave 2 — small transit-zone for pinky polenta. between the block / market / laundromat.
    { id: 'busstop',     name: 'BUS STOP',            x: 1240, y: 1080, w: 220, h: 180, color: '#2a2820', label: '#888888', faction: 'street' },
    // v13 wave 8a — four new zones placed in the expanded world space (existing zones unchanged).
    // TRAIN YARD: far south-west. Conductor's real home. spiritual-leaning.
    { id: 'trainyard',   name: 'TRAIN YARD',          x: 260,  y: 2700, w: 1100, h: 560, color: '#1f1c18', label: '#a8a090', faction: 'spiritual' },
    // THE PARK: central-east in new space. spiritual lean per wave 8b (bench, fountain, philosopher).
    { id: 'park',        name: 'THE PARK',            x: 2400, y: 900,  w: 620,  h: 500, color: '#243a22', label: '#a8d088', faction: 'spiritual' },
    // SKID ROW: east of marketplace. street faction, contested, dangerous.
    { id: 'skidrow',     name: 'SKID ROW',            x: 2480, y: 1520, w: 900,  h: 720, color: '#1a1612', label: '#8a3a3a', faction: 'street' },
    // OLD SCHOOL: far north-east corner. scrap-leaning, optional boss zone.
    { id: 'oldschool',   name: 'OLD SCHOOL',          x: 3400, y: 280,  w: 760,  h: 640, color: '#241a18', label: '#c08038', faction: 'scrap' },
    // v18 far-east expansion. THE LOT stays neutral so shelter ownership never leaks into
    // the older faction-territory heat ticker. The canal is paperwork on water.
    { id: 'warehouse_row', name: 'WAREHOUSE ROW',      x: 4400, y: 180,  w: 1100, h: 760, color: '#29231c', label: '#c08038', faction: 'scrap' },
    { id: 'canal',         name: 'THE DRAINAGE CANAL', x: 4300, y: 1540, w: 1350, h: 680, color: '#202624', label: '#87927c', faction: 'neutral' },
    { id: 'the_lot',       name: 'THE LOT',            x: 4300, y: 2700, w: 1250, h: 850, color: '#282218', label: '#e8c040', faction: 'neutral' },
    // v19 rival curb kingdoms. `clan` is deliberately separate from the legacy three-faction system.
    { id: 'blue_tarp_court',   name: 'BLUE TARP COURT',   x: 5920, y: 260,  w: 1160, h: 1060, color: '#202c35', label: '#7890a0', faction: 'neutral', clan: 'blue_tarp' },
    { id: 'cart_cavalry_keep', name: 'CART CAVALRY KEEP', x: 7340, y: 1460, w: 1040, h: 980,  color: '#302a20', label: '#d4c896', faction: 'neutral', clan: 'cart_cavalry' },
    { id: 'copper_choir_yard', name: 'COPPER CHOIR YARD', x: 5920, y: 2760, w: 1220, h: 1120, color: '#30231b', label: '#d06030', faction: 'neutral', clan: 'copper_choir' },
    { id: 'throne_ditch',      name: 'THE THRONE DITCH',  x: 7020, y: 4200, w: 1320, h: 1120, color: '#28251d', label: '#e8c040', faction: 'neutral', clan: 'throne' },
  ];
  
  // ---------- v14 visual world cohesion ----------
  // Mechanical zones remain the authority for gameplay. These layers only answer what the
  // space BETWEEN zones looks like, so the expanded world reads as one neighborhood.
  TERRAIN_REGIONS = [
    { id:'north_vacant',   x:1980, y:0,    w:1420, h:920,  palette:'vacant' },
    { id:'school_outside', x:3400, y:0,    w:1000, h:1500, palette:'school_outskirts' },
    { id:'east_service',   x:1980, y:760,  w:1500, h:1660, palette:'service' },
    { id:'south_drainage', x:0,    y:1880, w:2250, h:720,  palette:'drainage' },
    { id:'rail_approach',  x:0,    y:2480, w:1700, h:1320, palette:'rail_approach' },
    { id:'south_dead',     x:1700, y:2240, w:2700, h:1560, palette:'dead_grass' },
    { id:'far_north',      x:4400, y:0,    w:1400, h:1400, palette:'service' },
    { id:'far_mid',        x:3480, y:1400, w:2320, h:1080, palette:'drainage' },
    { id:'far_south',      x:4400, y:2480, w:1400, h:1320, palette:'dead_grass' },
    { id:'kingdom_north',   x:5800, y:0,    w:2800, h:1340, palette:'service' },
    { id:'kingdom_middle',  x:5800, y:1340, w:2800, h:1300, palette:'vacant' },
    { id:'kingdom_south',   x:5800, y:2640, w:2800, h:1360, palette:'dead_grass' },
    { id:'kingdom_bottom',  x:5800, y:4000, w:2800, h:1600, palette:'drainage' },
    { id:'southwest_scrub', x:0,    y:3800, w:2800, h:1800, palette:'dead_grass' },
    { id:'south_rail_spoil',x:2800, y:3800, w:3000, h:1800, palette:'rail_approach' },
  ];
  
  ROAD_SEGMENTS = [
    { id:'north_core',       x:0,    y:500,  w:2180, h:108, axis:'h', kind:'street' },
    { id:'block_cut',        x:620,  y:970,  w:1580, h:104, axis:'h', kind:'street' },
    { id:'market_cut',       x:0,    y:1258, w:2200, h:102, axis:'h', kind:'street' },
    { id:'projects_lane',    x:0,    y:1880, w:3400, h:112, axis:'h', kind:'service' },
    { id:'east_link',        x:1980, y:780,  w:1420, h:112, axis:'h', kind:'street' },
    { id:'park_skid_link',   x:1980, y:1400, w:3720, h:112, axis:'h', kind:'street' },
    { id:'south_service',    x:0,    y:2480, w:5700, h:116, axis:'h', kind:'service' },
    { id:'train_approach',   x:0,    y:2600, w:1500, h:96,  axis:'h', kind:'service' },
    { id:'west_spine',       x:620,  y:0,    w:104,  h:1880,axis:'v', kind:'street' },
    { id:'central_spine',    x:1380, y:0,    w:104,  h:1880,axis:'v', kind:'street' },
    { id:'east_spine',       x:2100, y:0,    w:112,  h:2480,axis:'v', kind:'arterial' },
    { id:'school_spine',     x:3280, y:0,    w:112,  h:2480,axis:'v', kind:'service' },
    { id:'rail_spine',       x:700,  y:1880, w:112,  h:820, axis:'v', kind:'service' },
    { id:'train_east',       x:1360, y:2480, w:112,  h:1320,axis:'v', kind:'service' },
    { id:'warehouse_cut',    x:3280, y:960,  w:2420, h:112, axis:'h', kind:'street' },
    { id:'far_east_spine',   x:4160, y:900,  w:112,  h:2800,axis:'v', kind:'arterial' },
    { id:'office_drive',     x:4868, y:2480, w:104,  h:390, axis:'v', kind:'service' },
    { id:'warehouse_cut_east',x:5680,y:960,  w:1600,h:112,axis:'h',kind:'street' },
    { id:'court_keep_cut',   x:5680, y:1340, w:2840, h:112, axis:'h', kind:'arterial' },
    { id:'kingdom_south_link',x:5680,y:2480, w:2840, h:116, axis:'h', kind:'service' },
    { id:'copper_docket',    x:5680, y:3980, w:2840, h:112, axis:'h', kind:'service' },
    { id:'throne_tail',      x:7000, y:5360, w:1520, h:104, axis:'h', kind:'service' },
    { id:'clan_spine',       x:7160, y:900,  w:112,  h:3180,axis:'v', kind:'arterial' },
    { id:'west_claim_spine', x:5680, y:2480, w:112,  h:2328,axis:'v', kind:'service' },
    { id:'east_bypass',      x:8400, y:1340, w:112,  h:4124,axis:'v', kind:'service' },
    { id:'ditch_spine',      x:7160, y:3980, w:112,  h:1484,axis:'v', kind:'service' },
    { id:'old_south_spine_extension',x:4160,y:3680,w:112,h:1128,axis:'v',kind:'service' },
    { id:'south_scrub_cut',  x:4160, y:4700, w:1632, h:108, axis:'h', kind:'service' },
  ];
  
  CROSSWALKS = [
    { x:635,  y:500,  axis:'v' }, { x:1395, y:500,  axis:'v' },
    { x:2104, y:780,  axis:'h' }, { x:3284, y:780,  axis:'h' },
    { x:2104, y:1400, axis:'h' }, { x:3284, y:1400, axis:'h' },
    { x:704,  y:1880, axis:'h' }, { x:2104, y:1880, axis:'h' },
    { x:704,  y:2480, axis:'h' }, { x:1364, y:2480, axis:'h' },
    { x:4164, y:960,  axis:'h' }, { x:4164, y:1400, axis:'h' },
    { x:4164, y:2480, axis:'h' },
    { x:7164, y:960,  axis:'h' }, { x:7164, y:1340, axis:'h' },
    { x:8404, y:1340, axis:'h' }, { x:5684, y:2480, axis:'h' },
    { x:7164, y:2480, axis:'h' }, { x:8404, y:2480, axis:'h' },
    { x:5684, y:3980, axis:'h' }, { x:7164, y:3980, axis:'h' },
    { x:8404, y:3980, axis:'h' }, { x:4164, y:4700, axis:'h' },
    { x:5684, y:4700, axis:'h' }, { x:7164, y:5360, axis:'h' },
    { x:8404, y:5360, axis:'h' },
  ];
  
  // Worn footpaths and coherent rail lines are drawn as whole routes rather than repeating
  // independently inside each 64px tile.
  GROUND_PATHS = [
    { id:'park_loop_a', x:2420,y:1080,w:580,h:40, points:[[2420,1120],[2520,1090],[2700,1120],[2870,1080],[3000,1120]], width:34, color:'#6a6040' },
    { id:'park_loop_b', x:2700,y:920,w:20,h:470, points:[[2700,920],[2710,1040],[2700,1140],[2720,1300],[2700,1390]], width:28, color:'#625a3c' },
    { id:'church_walk', x:1600,y:1510,w:380,h:5, points:[[1600,1515],[1700,1515],[1800,1510],[1980,1510]], width:24, color:'#51483b' },
    { id:'school_walk', x:3400,y:820,w:640,h:20, points:[[3400,840],[3550,820],[3760,820],[4040,820]], width:30, color:'#574a36' },
    { id:'tarp_court_walk',x:6040,y:620,w:900,h:450,points:[[6040,1060],[6260,940],[6500,900],[6800,760],[6940,620]],width:30,color:'#4c5660' },
    { id:'cart_keep_walk',x:7420,y:1840,w:840,h:420,points:[[7420,2260],[7600,2140],[7860,2050],[8120,2140],[8260,1840]],width:32,color:'#665d49' },
    { id:'choir_aisle',x:6040,y:3160,w:900,h:500,points:[[6040,3620],[6260,3540],[6510,3480],[6780,3540],[6940,3160]],width:28,color:'#68452f' },
    { id:'ditch_procession',x:7140,y:4660,w:1080,h:560,points:[[7140,5180],[7380,5060],[7680,4880],[7960,5060],[8220,4660]],width:36,color:'#5d584a' },
  ];
  
  RAIL_LINES = [
    { x1:180, y1:2780, x2:1510, y2:2780 },
    { x1:180, y1:2910, x2:1510, y2:2910 },
    { x1:180, y1:3040, x2:1510, y2:3040 },
    { x1:180, y1:3170, x2:1510, y2:3170 },
  ];
  
  // Set-back silhouettes. They are deliberately visual-only: v14 does not change NPC or
  // projectile collision. Their lots sit away from canonical routes and interaction anchors.
  LANDMARK_FACADES = [
    { id:'checks',          x:760,  y:90,   w:200, h:170, kind:'storefront', sign:'CHECKS' },
    { id:'rooms_no',        x:760,  y:310,  w:200, h:150, kind:'rowhouse',   sign:'ROOMS (NO)' },
    { id:'former_dentist',  x:1740, y:620,  w:300, h:140, kind:'storefront', sign:'FORMER DENTIST' },
    { id:'boxes',           x:2340, y:90,   w:420, h:270, kind:'warehouse',  sign:'BOXES' },
    { id:'tire_2',          x:2820, y:100,  w:360, h:260, kind:'warehouse',  sign:'TIRE 2' },
    { id:'car_wash',        x:2340, y:630,  w:360, h:130, kind:'storefront', sign:'CAR WASH · NO WATER' },
    { id:'used_mattress',   x:2780, y:620,  w:440, h:140, kind:'storefront', sign:'USED MATTRESS' },
    { id:'motel',           x:3050, y:940,  w:190, h:390, kind:'rowhouse',   sign:'MOTEL · OFFICE CLOSED' },
    { id:'projects_a',      x:100,  y:1685, w:260, h:78,  kind:'rowhouse',   sign:'BUILDING A' },
    { id:'self_storage',    x:70,   y:2070, w:500, h:270, kind:'warehouse',  sign:'SELF STORAGE' },
    { id:'carpet',          x:900,  y:2050, w:360, h:250, kind:'warehouse',  sign:'CARPET' },
    { id:'meat',            x:1400, y:2040, w:580, h:280, kind:'industrial', sign:'MEAT' },
    { id:'loading',         x:2240, y:2290, w:940, h:160, kind:'warehouse',  sign:'LOADING' },
    { id:'no_refunds',      x:1530, y:2700, w:600, h:300, kind:'warehouse',  sign:'NO REFUNDS' },
    { id:'tax',             x:2280, y:2690, w:600, h:270, kind:'industrial', sign:'TAX' },
    { id:'unit_4',          x:3050, y:2680, w:760, h:280, kind:'warehouse',  sign:'UNIT 4' },
    { id:'cold_not',        x:4440, y:1080, w:450, h:230, kind:'warehouse',  sign:'COLD (NOT)' },
    { id:'plastic_chair',   x:5060, y:1090, w:500, h:220, kind:'warehouse',  sign:'PLASTIC CHAIR' },
    { id:'water_dry',       x:4460, y:2250, w:520, h:210, kind:'industrial', sign:'WATER DEPT. (DRY)' },
    { id:'leasing_later',   x:5180, y:2250, w:420, h:200, kind:'storefront', sign:'LEASING · LATER' },
    { id:'tarp_wholesale',  x:5920, y:40,   w:520, h:180, kind:'warehouse', sign:'TARP WHOLESALE' },
    { id:'family_court_2',  x:6500, y:40,   w:560, h:180, kind:'rowhouse', sign:'FAMILY COURT 2' },
    { id:'wheel_witness',   x:7360, y:1120, w:420, h:190, kind:'warehouse', sign:'WHEEL WITNESS' },
    { id:'coin_return',     x:7900, y:1120, w:440, h:190, kind:'storefront', sign:'COIN RETURN' },
    { id:'wire_less',       x:5940, y:2600, w:500, h:130, kind:'industrial', sign:'WIRE (LESS)' },
    { id:'b_flat_storage',  x:6540, y:2600, w:520, h:130, kind:'warehouse', sign:'B FLAT STORAGE' },
    { id:'chair_annex',     x:7280, y:4100, w:440, h:80,  kind:'rowhouse', sign:'CHAIR ANNEX' },
    { id:'ditch_clerk',     x:7800, y:4100, w:520, h:80,  kind:'storefront', sign:'DITCH CLERK' },
  ];
  
  WORLD_DECOR = [
    { type:'bus_shelter', x:1250, y:1115, w:88, h:46, layer:'tall' },
    { type:'billboard', x:1990, y:650, w:116, h:64, text:'ROOM FOR RENT\nROOM NOT INCLUDED', layer:'tall' },
    { type:'water_tower', x:3130, y:390, w:92, h:118, text:'WATER', layer:'tall' },
    { type:'motel_sign', x:3025, y:940, w:28, h:76, text:'MOTEL\nNO', layer:'tall' },
    { type:'clothesline', x:160, y:1770, x2:340, y2:1740, layer:'tall' },
    { type:'clothesline', x:2580, y:1850, x2:2750, y2:1815, layer:'tall' },
    { type:'clothesline', x:2970, y:2150, x2:3180, y2:2110, layer:'tall' },
    { type:'crossbuck', x:760, y:2630, layer:'tall' },
    { type:'rail_signal', x:310, y:2750, layer:'tall' },
    { type:'rail_signal', x:1300, y:3020, layer:'tall' },
    { type:'rail_signal', x:1415, y:2580, layer:'tall' },
    { type:'news_box', x:900, y:1010, layer:'low' },
    { type:'news_box', x:1510, y:1040, layer:'low' },
    { type:'news_box', x:2380, y:1440, layer:'low' },
    { type:'news_box', x:3330, y:940, layer:'low' },
    { type:'road_barrier', x:2040, y:735, layer:'low' },
    { type:'road_barrier', x:3300, y:930, layer:'low' },
    { type:'road_barrier', x:2180, y:2440, layer:'low' },
    { type:'road_barrier', x:1430, y:2540, layer:'low' },
    { type:'storm_drain', x:670, y:575, layer:'low' },
    { type:'storm_drain', x:1415, y:575, layer:'low' },
    { type:'storm_drain', x:2135, y:835, layer:'low' },
    { type:'storm_drain', x:3315, y:835, layer:'low' },
    { type:'storm_drain', x:2135, y:1455, layer:'low' },
    { type:'storm_drain', x:3315, y:1455, layer:'low' },
    { type:'storm_drain', x:745, y:1940, layer:'low' },
    { type:'storm_drain', x:2135, y:1940, layer:'low' },
    { type:'storm_drain', x:3315, y:1940, layer:'low' },
    { type:'storm_drain', x:745, y:2540, layer:'low' },
    { type:'storm_drain', x:1415, y:2540, layer:'low' },
    { type:'utility_pole', x:680, y:470, layer:'tall' },
    { type:'utility_pole', x:1400, y:470, layer:'tall' },
    { type:'utility_pole', x:2100, y:470, layer:'tall' },
    { type:'utility_pole', x:3290, y:470, layer:'tall' },
    { type:'utility_pole', x:680, y:940, layer:'tall' },
    { type:'utility_pole', x:1400, y:940, layer:'tall' },
    { type:'utility_pole', x:2100, y:940, layer:'tall' },
    { type:'utility_pole', x:3290, y:940, layer:'tall' },
    { type:'utility_pole', x:680, y:1840, layer:'tall' },
    { type:'utility_pole', x:1400, y:1840, layer:'tall' },
    { type:'utility_pole', x:2100, y:1840, layer:'tall' },
    { type:'utility_pole', x:3290, y:1840, layer:'tall' },
    { type:'utility_pole', x:700, y:2440, layer:'tall' },
    { type:'utility_pole', x:1360, y:2440, layer:'tall' },
    { type:'utility_pole', x:2100, y:2440, layer:'tall' },
    { type:'utility_pole', x:4200, y:940,  layer:'tall' },
    { type:'utility_pole', x:4920, y:940,  layer:'tall' },
    { type:'utility_pole', x:5520, y:940,  layer:'tall' },
    { type:'utility_pole', x:4200, y:2440, layer:'tall' },
    { type:'utility_pole', x:4920, y:2440, layer:'tall' },
    { type:'storm_drain', x:4215, y:1015, layer:'low' },
    { type:'storm_drain', x:4215, y:1455, layer:'low' },
    { type:'storm_drain', x:4215, y:2538, layer:'low' },
    { type:'storm_drain', x:5420, y:2070, layer:'low' },
    { type:'road_barrier', x:4380, y:1010, layer:'low' },
    { type:'road_barrier', x:5500, y:1450, layer:'low' },
    { type:'news_box', x:4440, y:3140, layer:'low' },
    { type:'billboard', x:5740, y:760, w:116, h:64, text:'BLUE TARP\nWEATHER DEPT.', layer:'tall' },
    { type:'clothesline', x:6120, y:700, x2:6840, y2:760, layer:'tall' },
    { type:'road_barrier', x:7040, y:1010, layer:'low' },
    { type:'news_box', x:6300, y:990, layer:'low' },
    { type:'billboard', x:8240, y:2080, w:116, h:64, text:'KEEP RECEIPT\nKEEP EVERYTHING', layer:'tall' },
    { type:'road_barrier', x:7420, y:2500, layer:'low' },
    { type:'clothesline', x:6120, y:3260, x2:6880, y2:3340, layer:'tall' },
    { type:'billboard', x:5740, y:3400, w:116, h:64, text:'COPPER MASS\n11:11-ish', layer:'tall' },
    { type:'road_barrier', x:7040, y:4020, layer:'low' },
    { type:'motel_sign', x:8290, y:4560, w:28, h:76, text:'KING\nNO', layer:'tall' },
    { type:'road_barrier', x:7160, y:5320, layer:'low' },
    { type:'utility_pole', x:5700, y:940, layer:'tall' },
    { type:'utility_pole', x:7160, y:940, layer:'tall' },
    { type:'utility_pole', x:8400, y:1340, layer:'tall' },
    { type:'utility_pole', x:5700, y:2440, layer:'tall' },
    { type:'utility_pole', x:7160, y:2440, layer:'tall' },
    { type:'utility_pole', x:8400, y:2440, layer:'tall' },
    { type:'utility_pole', x:5700, y:3940, layer:'tall' },
    { type:'utility_pole', x:7160, y:3940, layer:'tall' },
    { type:'utility_pole', x:8400, y:3940, layer:'tall' },
    { type:'bus_shelter', x:6880, y:1130, w:88, h:46, layer:'low' },
    { type:'bus_shelter', x:8210, y:2240, w:88, h:46, layer:'low' },
    { type:'bus_shelter', x:5960, y:3680, w:88, h:46, layer:'low' },
    { type:'bus_shelter', x:8160, y:5140, w:88, h:46, layer:'low' },
    { type:'news_box', x:6020, y:1180, layer:'low' },
    { type:'storm_drain', x:7180, y:1015, layer:'low' },
    { type:'storm_drain', x:8420, y:1395, layer:'low' },
    { type:'storm_drain', x:5700, y:2550, layer:'low' },
    { type:'storm_drain', x:7180, y:2550, layer:'low' },
    { type:'storm_drain', x:8420, y:2550, layer:'low' },
    { type:'storm_drain', x:5700, y:4050, layer:'low' },
    { type:'storm_drain', x:7180, y:4050, layer:'low' },
    { type:'storm_drain', x:8420, y:4050, layer:'low' },
    { type:'storm_drain', x:7120, y:5240, layer:'low' },
    { type:'storm_drain', x:8420, y:5420, layer:'low' },
  ];
  
  UTILITY_WIRES = [
    [680,470,1400,470],[1400,470,2100,470],[2100,470,3290,470],
    [680,940,1400,940],[1400,940,2100,940],[2100,940,3290,940],
    [680,1840,1400,1840],[1400,1840,2100,1840],[2100,1840,3290,1840],
    [700,2440,1360,2440],[1360,2440,2100,2440],
    [4200,940,4920,940],[4920,940,5520,940],
    [4200,2440,4920,2440],
    [5700,940,7160,940],[7160,940,8400,1340],
    [5700,2440,7160,2440],[7160,2440,8400,2440],
    [5700,3940,7160,3940],[7160,3940,8400,3940],
  ];
  
  WORLD_LIGHTS = [
    { x:1620, y:810,  radius:105, rgb:'208,96,48',   power:.55 },
    { x:1600, y:1085, radius:115, rgb:'136,192,210', power:.50 },
    { x:1800, y:1350, radius:120, rgb:'186,120,180', power:.42 },
    { x:1292, y:1120, radius:88,  rgb:'232,192,64',  power:.38 },
    { x:2700, y:1140, radius:92,  rgb:'160,190,150', power:.28 },
    { x:3760, y:720,  radius:120, rgb:'232,192,64',  power:.42 },
    { x:3580, y:500,  radius:96,  rgb:'190,158,92',  power:.18 },
    { x:3980, y:510,  radius:96,  rgb:'190,158,92',  power:.18 },
    { x:1100, y:360,  radius:110, rgb:'208,128,48',  power:.40 },
    { x:1230, y:380,  radius:110, rgb:'208,128,48',  power:.40 },
    { x:1340, y:410,  radius:110, rgb:'208,128,48',  power:.40 },
    { x:310,  y:2738, radius:72,  rgb:'138,58,58',   power:.48 },
    { x:1300, y:3008, radius:72,  rgb:'138,58,58',   power:.48 },
    { x:2580, y:1650, radius:74,  rgb:'208,128,48',  power:.22 },
    { x:3200, y:1950, radius:74,  rgb:'208,128,48',  power:.22 },
    { x:300,  y:1740, radius:76,  rgb:'208,128,48',  power:.20 },
    { x:4460, y:850,  radius:100, rgb:'208,128,48',  power:.28 },
    { x:5410, y:850,  radius:100, rgb:'208,128,48',  power:.24 },
    { x:5420, y:2070, radius:84,  rgb:'120,160,145', power:.22 },
    { x:4920, y:3210, radius:130, rgb:'232,192,64',  power:.50, office:true },
    { x:6500, y:760,  radius:180, rgb:'72,88,94',    power:.34 },
    { x:7860, y:2050, radius:170, rgb:'190,158,92',  power:.30 },
    { x:6510, y:3480, radius:190, rgb:'208,96,48',   power:.46 },
    { x:7680, y:4880, radius:180, rgb:'138,58,58',   power:.32 },
  ];
  
  
}
