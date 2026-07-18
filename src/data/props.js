/* Generated from frozen rock_bottom_v19.html.
 * Source seams: buildings, props, and interactive props.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { dialogue, state } from '../core/runtime_ui.js';
import { buildGraffiti } from '../render/structures.js';

export let BUILDINGS, PROPS, interactiveProps, CHATTER;
export const RIDEABLE_CART_SPAWN = Object.freeze({ x:1000, y:1600 });

export function rideableCart() {
  return PROPS && PROPS.find(prop=>prop.type==='cart');
}

export function resetRideableCart() {
  const cart=rideableCart();
  if(!cart)return;
  cart.x=RIDEABLE_CART_SPAWN.x;cart.y=RIDEABLE_CART_SPAWN.y;
}

export function initInteractiveProps() {
  interactiveProps = [
    // kickable trash cans — one per zone roughly. each carries cooldown + state.
    { type:'trashcan', x: 980,  y: 800,  zone:'block',   cdT:0, tipT:0, rotPulse:0 },
    { type:'trashcan', x: 1620, y: 980,  zone:'dealer',  cdT:0, tipT:0, rotPulse:0 },
    { type:'trashcan', x: 220,  y: 700,  zone:'pawn',    cdT:0, tipT:0, rotPulse:0 },
    { type:'trashcan', x: 820,  y: 1500, zone:'market',  cdT:0, tipT:0, rotPulse:0 },
    { type:'trashcan', x: 300,  y: 1560, zone:'alley',   cdT:0, tipT:0, rotPulse:0 },
    { type:'trashcan', x: 380,  y: 280,  zone:'scrap',   cdT:0, tipT:0, rotPulse:0 },
  ];
  // breakable bottles — scattered. respawned over time.
  for (let i=0;i<8;i++) spawnBreakableBottle();
}

export function spawnBreakableBottle() {
  // pool of candidate spots — clear of buildings.
  const pool = [
    {x:140, y:300}, {x:680, y:240}, {x:1100, y:540}, {x:1740, y:520},
    {x:240, y:980}, {x:900, y:1100}, {x:1500, y:1240}, {x:1700, y:1180},
    {x:320, y:1420},{x:540, y:1700}, {x:1100, y:1640}, {x:1380, y:1700},
    {x:920, y:1820}, {x:280, y:1820}, {x:1700, y:920},  {x:1820, y:1380},
  ];
  const sp = pool[Math.floor(Math.random()*pool.length)];
  // jitter to avoid overlapping bottles
  interactiveProps.push({
    type:'b_bottle',
    x: sp.x + (Math.random()-.5)*40,
    y: sp.y + (Math.random()-.5)*40,
    broken: false,
  });
}

export function init_props() {
  // ---------- buildings (solid props) ----------
  BUILDINGS = [
    // pawn shop building
    { x: 180, y: 620, w: 160, h: 100, color: '#3a2a1a', border: '#1a1008', name: 'PAWN', solid: true },
    // dealer corner storefront
    { x: 1520, y: 820, w: 200, h: 110, color: '#4a2018', border: '#1a0805', name: 'CORNER', solid: true },
    // abandoned building
    { x: 1560, y: 160, w: 360, h: 240, color: '#1a1010', border: '#3a1010', name: '', locked: true, solid: true },
    // church
    { x: 1680, y: 1360, w: 240, h: 200, color: '#2a1f3a', border: '#0a0518', name: 'CHURCH', solid: true, doorGap: true },
    // laundromat (open south door)
    { x: 1520, y: 1100, w: 240, h: 130, color: '#3a3a44', border: '#222', name: 'LAUNDROMAT', solid: true, doorGap: true },
    // scrap yard fence is handled separately
    // v13 wave 8a — OLD SCHOOL building (door gap on south face). interior is modal dialogue (openOldSchool).
    { x: 3520, y: 380, w: 520, h: 340, color: '#3a2820', border: '#1a0805', name: 'OLDSCHOOL', solid: true, doorGap: true },
    // v13 wave 8a — SKID ROW: a tight cluster of makeshift shacks to make the alley network feel constrained.
    { x: 2540, y: 1660, w: 120, h: 70,  color: '#2a1a14', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 2720, y: 1740, w: 100, h: 80,  color: '#241814', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 2900, y: 1620, w: 130, h: 90,  color: '#1f1612', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 3120, y: 1720, w: 110, h: 70,  color: '#2a1814', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 2580, y: 1900, w: 140, h: 80,  color: '#241612', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 2900, y: 1980, w: 160, h: 80,  color: '#1c1410', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 3140, y: 1900, w: 130, h: 90,  color: '#241814', border: '#0a0805', name: 'SHACK', solid: true },
    { x: 2780, y: 2080, w: 120, h: 80,  color: '#1a120e', border: '#0a0805', name: 'SHACK', solid: true },
    // v18 far-east solids. The center warehouse aisle and office south-door gap remain clear.
    { x: 4460, y: 280,  w: 390, h: 420, color: '#302b24', border: '#15110e', name: 'UNIT 11', solid: true },
    { x: 5010, y: 280,  w: 400, h: 420, color: '#302820', border: '#15110e', name: 'RETURNS', solid: true },
    { x: 4700, y: 2920, w: 440, h: 300, color: '#33261d', border: '#130d09', name: 'THE OFFICE', solid: true, doorGap: true },
    // v19 rival court shells. South-door gaps stay clear; interiors remain implied paperwork.
    { x:6000, y:300,  w:340, h:180, color:'#263540', border:'#111418', name:'TARP PERMITS', solid:true },
    { x:6660, y:300,  w:340, h:180, color:'#2f4658', border:'#111418', name:'BLUE COURT', solid:true, doorGap:true },
    { x:7420, y:1540, w:320, h:220, color:'#514937', border:'#17130d', name:'CART IMPOUND', solid:true },
    { x:7960, y:1540, w:320, h:220, color:'#5b523d', border:'#17130d', name:'THE KEEP', solid:true, doorGap:true },
    { x:6000, y:2840, w:380, h:240, color:'#4b3023', border:'#100b08', name:'COPPER RETURNS', solid:true },
    { x:6620, y:2840, w:420, h:240, color:'#3d2b21', border:'#100b08', name:'CHOIR OFFICE', solid:true, doorGap:true },
    { x:7280, y:4280, w:360, h:220, color:'#454239', border:'#0a0805', name:'DITCH RECORDS', solid:true },
    { x:7840, y:4280, w:420, h:220, color:'#4d493d', border:'#0a0805', name:'THE THRONE', solid:true, doorGap:true },
  ];
  
  // ---------- props (decoration + interactables) ----------
  PROPS = [
    // dumpsters — interactable (dumpster dive)
    { type:'dumpster', x:140,  y:1320, w:36, h:24, color:'#2a3818', looted:false },
    { type:'dumpster', x:440,  y:1640, w:36, h:24, color:'#3a2818', looted:false },
    { type:'dumpster', x:1340, y:1480, w:36, h:24, color:'#2a2818', looted:false },
    { type:'dumpster', x:1620, y:280,  w:36, h:24, color:'#2a3818', looted:false },
    { type:'dumpster', x:780,  y:240,  w:36, h:24, color:'#2a2828', looted:false },
    // shopping cart (rideable)
    { type:'cart', x:RIDEABLE_CART_SPAWN.x, y:RIDEABLE_CART_SPAWN.y, w:24, h:20, color:'#888' },
    // lamp posts
    { type:'lamp', x:740,  y:840 }, { type:'lamp', x:1340, y:840 },
    { type:'lamp', x:1740, y:1100 },{ type:'lamp', x:240,  y:1100 },
    { type:'lamp', x:1600, y:1700 },{ type:'lamp', x:840,  y:1700 },
    { type:'lamp', x:340,  y:560 }, { type:'lamp', x:1500, y:560 },
    { type:'lamp', x:1240, y:340 }, { type:'lamp', x:1100, y:1200 },
    // fire hydrants
    { type:'hydrant', x:680,  y:920 }, { type:'hydrant', x:1480, y:1200 },
    { type:'hydrant', x:280,  y:1240 },{ type:'hydrant', x:1740, y:1660 },
    // mailboxes
    { type:'mailbox', x:920,  y:1100 },{ type:'mailbox', x:1500, y:1000 },
    { type:'mailbox', x:440,  y:840 },
    // traffic cones
    { type:'cone', x:1080, y:340 },{ type:'cone', x:1200, y:380 },
    { type:'cone', x:1360, y:420 },{ type:'cone', x:380,  y:380 },
    // trash piles
    { type:'trash', x:240, y:1500 },{ type:'trash', x:380, y:1620 },
    { type:'trash', x:120, y:1380 },{ type:'trash', x:1640, y:340 },
    { type:'trash', x:1800, y:240 },
    // milk crate at THE BLOCK
    { type:'crate', x:1050, y:880 },{ type:'crate', x:1080, y:870 },
    // syringes
    { type:'syringe', x:280, y:1440 },{ type:'syringe', x:520, y:1540 },
    { type:'syringe', x:420, y:1340 },
    // broken bottles
    { type:'bottle', x:340, y:1620 },{ type:'bottle', x:580, y:1380 },
    { type:'bottle', x:1380, y:1520 },
    // v13 wave 6 — highway underpass tent encampment (decorative, non-solid)
    { type:'tent',   x:1060, y:330,  color:'#3a5a8a' },   // blue tarp
    { type:'tent',   x:1120, y:380,  color:'#3a2a18' },   // brown trash bag tent
    { type:'tent',   x:1230, y:350,  color:'#605850' },   // gray
    { type:'tent',   x:1300, y:400,  color:'#4a3050' },   // purple sleeping bag pile
    // v13 wave 6 — cardboard sign next to the mathematician (deepest interior)
    { type:'cardsign', x:1340, y:412, text:'WILL TRADE\nWORDS FOR\nMATH' },
    // v13 wave 6 — scrap yard depth: piles + car wrecks + the chained dog's leash post
    { type:'scrap_pile', x:200, y:200, w:32, h:18, color:'#705028' },
    { type:'scrap_pile', x:520, y:340, w:36, h:20, color:'#604028' },
    { type:'scrap_pile', x:380, y:380, w:28, h:16, color:'#684830' },
    { type:'scrap_pile', x:160, y:330, w:30, h:18, color:'#503820' },
    { type:'car_wreck',  x:430, y:160, w:60, h:28, color:'#5a3030' },
    { type:'car_wreck',  x:240, y:380, w:62, h:30, color:'#4a4838' },
    { type:'leash_post', x:570, y:130 },   // the dog's post, dog spawns within 30px
    // v13 wave 6 — the public phone (scrap yard, on a pole). interactive.
    { type:'pay_phone', x:130, y:220 },
  
    // v13 wave 8a — TRAIN YARD props (zone @ 260,2700,1100,560)
    // three freight cars as decorative non-solid silhouettes. player can walk through.
    { type:'freight_car', x: 380,  y: 2820, w: 220, h: 64, color:'#5a2a20' },   // rust red
    { type:'freight_car', x: 720,  y: 2900, w: 240, h: 64, color:'#2a3a5a' },   // navy blue
    { type:'freight_car', x: 1040, y: 2780, w: 200, h: 60, color:'#3a4030' },   // moss green
    // the chalk lore message on the side of the navy freight car
    { type:'chalk_message', x: 760, y: 2898, text: 'the bus knows where\nthe train doesn\'t go' },
    // weeds clumps — train yard
    { type:'weeds', x: 540,  y: 2730 }, { type:'weeds', x: 990, y: 2880 },
    { type:'weeds', x: 320,  y: 3100 }, { type:'weeds', x: 1230, y: 3060 },
    { type:'weeds', x: 700,  y: 3180 }, { type:'weeds', x: 470,  y: 2980 },
  
    // v13 wave 8a — THE PARK props (zone @ 2400,900,620,500)
    // central fountain
    { type:'fountain',     x: 2700, y: 1140 },
    // park benches (4)
    { type:'park_bench',   x: 2520, y: 1040, w: 40, h: 12 },
    { type:'park_bench',   x: 2880, y: 1040, w: 40, h: 12 },
    { type:'park_bench',   x: 2520, y: 1240, w: 40, h: 12 },
    { type:'park_bench',   x: 2880, y: 1240, w: 40, h: 12 },
    // swing set (creepy at night)
    { type:'swing_set',    x: 2480, y: 1320 },
    // broken drinking fountain
    { type:'drink_fountain', x: 2820, y: 1340 },
    // trees
    { type:'tree', x: 2460, y: 950  }, { type:'tree', x: 2980, y: 970  },
    { type:'tree', x: 2460, y: 1350 }, { type:'tree', x: 2980, y: 1330 },
    { type:'tree', x: 2620, y: 970  }, { type:'tree', x: 2820, y: 970  },
  
    // v13 wave 8a — SKID ROW props (zone @ 2480,1520,900,720)
    // trash piles (graffiti density handled in buildGraffiti)
    { type:'trash', x: 2580, y: 1620 }, { type:'trash', x: 2780, y: 1700 },
    { type:'trash', x: 2980, y: 1680 }, { type:'trash', x: 3200, y: 1820 },
    { type:'trash', x: 2640, y: 1900 }, { type:'trash', x: 2880, y: 2000 },
    { type:'trash', x: 3100, y: 2080 }, { type:'trash', x: 2700, y: 2160 },
    // a few dumpsters
    { type:'dumpster', x: 2820, y: 1780, w:36, h:24, color:'#1a1a14', looted:false },
    { type:'dumpster', x: 3100, y: 1980, w:36, h:24, color:'#1a1614', looted:false },
    // a single bare bulb on a wire (one light source, intentionally sparse)
    { type:'lamp', x: 2920, y: 1880 },
    // broken bottles scattered
    { type:'bottle', x: 2680, y: 1740 }, { type:'bottle', x: 3040, y: 1840 },
    { type:'bottle', x: 2780, y: 2040 },
    // syringes (this is skid row)
    { type:'syringe', x: 2960, y: 1660 }, { type:'syringe', x: 3220, y: 1940 },
  
    // v13 wave 8a — OLD SCHOOL props (zone @ 3400,280,760,640)
    // mural on the south face of the school building. faded letters: "FUTU EA HE M C"
    { type:'school_mural', x: 3530, y: 720, text: 'FUTU EA HE M C' },
    // swing set in the schoolyard
    { type:'swing_set', x: 3520, y: 800 },
    // broken basketball hoop
    { type:'broken_hoop', x: 3920, y: 540 },
    // chain-link fence segments along the south edge
    { type:'school_fence', x: 3420, y: 880, w: 720, h: 6 },
    // tall weedy grass clumps
    { type:'weeds', x: 3640, y: 350 }, { type:'weeds', x: 3820, y: 480 },
    { type:'weeds', x: 3500, y: 620 }, { type:'weeds', x: 4040, y: 760 },
    { type:'weeds', x: 3760, y: 820 }, { type:'weeds', x: 3960, y: 380 },
    // broken-window props on the building face (small black squares)
    { type:'broken_window', x: 3600, y: 460 }, { type:'broken_window', x: 3700, y: 460 },
    { type:'broken_window', x: 3800, y: 460 }, { type:'broken_window', x: 3900, y: 460 },
    { type:'broken_window', x: 4000, y: 460 },
  
    // v18 WAREHOUSE ROW: open loading apron clutter. All are existing draw branches.
    { type:'scrap_pile', x: 4430, y: 820, w:36, h:20, color:'#604028' },
    { type:'scrap_pile', x: 5200, y: 850, w:34, h:18, color:'#503820' },
    { type:'car_wreck',  x: 4860, y: 760, w:62, h:30, color:'#3f3a34' },
    { type:'dumpster',   x: 5350, y: 760, w:36, h:24, color:'#25231d', looted:false },
    { type:'cardsign',   x: 4930, y: 850, text:'MANIFEST\nPENDING' },
    { type:'weeds',      x: 4440, y: 900 }, { type:'weeds', x: 5480, y: 880 },
  
    // v18 DRAINAGE CANAL: visual-only inventory. A second rideable cart is intentionally absent.
    { type:'cardsign', x: 4380, y: 1640, text:'CITY WATER\nIS A THEORY' },
    { type:'school_fence', x: 4560, y: 2120, w:120, h:6 },
    { type:'trash', x: 4700, y: 2040 }, { type:'trash', x: 5260, y: 1740 },
    { type:'weeds', x: 4380, y: 2180 }, { type:'weeds', x: 5560, y: 1580 },
    { type:'dumpster', x: 5480, y: 2140, w:36, h:24, color:'#1e2520', looted:false },
  
    // v18 THE LOT: THE OFFICE has belongings before it has an owner.
    { type:'car_wreck', x: 4380, y: 3340, w:60, h:28, color:'#49382b' },
    { type:'dumpster', x: 5320, y: 3400, w:36, h:24, color:'#2a281e', looted:false },
    { type:'trash', x: 4560, y: 3420 }, { type:'trash', x: 5220, y: 2780 },
    { type:'weeds', x: 4340, y: 3500 }, { type:'weeds', x: 5480, y: 3480 },
  
    // v19 BLUE TARP COURT: plastic weather, bucket borders, and one court with no roof permit.
    { type:'tent', x:5980, y:650, color:'#3a4f5c' }, { type:'tent', x:6040, y:820, color:'#334752' },
    { type:'tent', x:6900, y:650, color:'#3a4f5c' }, { type:'tent', x:6960, y:820, color:'#2f414b' },
    { type:'cardsign', x:5960, y:600, text:'COURT OPEN\nROOF PENDING' },
    { type:'trash', x:5960, y:1260 }, { type:'trash', x:7040, y:300 },
    { type:'school_fence', x:5920, y:1280, w:1160, h:6 },
    { type:'weeds', x:5940, y:300 }, { type:'weeds', x:7040, y:1260 },
  
    // v19 CART CAVALRY KEEP: visual-only cart husks. The original rideable cart stays unique.
    { type:'cart_husk', x:7420, y:1810, w:24, h:20 }, { type:'cart_husk', x:7480, y:2250, w:24, h:20 },
    { type:'cart_husk', x:8240, y:1810, w:24, h:20 }, { type:'cart_husk', x:8280, y:2250, w:24, h:20 },
    { type:'cart_husk', x:7440, y:2100, w:24, h:20 }, { type:'cart_husk', x:8260, y:2070, w:24, h:20 },
    { type:'school_fence', x:7420, y:2380, w:840, h:6 },
    { type:'cone', x:7380, y:1500 }, { type:'cone', x:8340, y:2400 },
    { type:'cardsign', x:7440, y:1780, text:'CARTS FORM\nONE UNIT' },
  
    // v19 COPPER CHOIR YARD: a chapel assembled from wire, hubcaps, and accounting.
    { type:'scrap_pile', x:5980, y:3200, w:36, h:20, color:'#8a5b3a' },
    { type:'scrap_pile', x:7000, y:3200, w:36, h:20, color:'#70452d' },
    { type:'scrap_pile', x:5980, y:3540, w:36, h:20, color:'#70452d' },
    { type:'scrap_pile', x:7000, y:3540, w:36, h:20, color:'#8a5b3a' },
    { type:'car_wreck', x:6100, y:3160, w:62, h:30, color:'#61412d' },
    { type:'cardsign', x:7000, y:3760, text:'B FLAT\nRECEIVED' },
    { type:'school_fence', x:5920, y:3840, w:1220, h:6 },
    { type:'weeds', x:5960, y:3100 }, { type:'weeds', x:7060, y:3820 },
  
    // v22 wave 5.5 — BREAK-IN SHELLS (the barren quarter). Non-solid authored
    // silhouettes like the freight cars; the interior is the dialogue. Coordinates
    // are the anchor of record — BREAKIN_SITES below mirrors them and breakin-gate
    // proves the parity. Southwest scrub + south rail spoil, clear of both roads.
    { type:'breakin_shell', variant:'model_home', x: 950,  y: 4350, w: 240, h: 150, color:'#5a5044', sign:'MODEL HOME' },
    { type:'breakin_shell', variant:'spoil_bank', x: 3350, y: 4450, w: 260, h: 140, color:'#4a3c2c', sign:'BANK (FORMER)' },
    { type:'breakin_shell', variant:'sod_office', x: 4800, y: 5050, w: 240, h: 130, color:'#3c4030', sign:'SOD · OFFICE' },
    { type:'cardsign', x: 1000, y: 4530, text:'IF YOU LIVED HERE\nYOU WOULD BE\nHOME NOW' },
    { type:'weeds', x: 920,  y: 4520 }, { type:'weeds', x: 1220, y: 4380 },
    { type:'weeds', x: 3320, y: 4610 }, { type:'weeds', x: 3640, y: 4470 },
    { type:'weeds', x: 4770, y: 5200 }, { type:'weeds', x: 5070, y: 5090 },

    // v19 THE THRONE DITCH: ceremonial curb inventory. The folding chair is not constitutional.
    { type:'cardsign', x:7660, y:4540, text:'ONE CHAIR\nNO APPEALS' },
    { type:'crate', x:7630, y:4565 }, { type:'crate', x:7690, y:4565 },
    { type:'trash', x:7080, y:4620 }, { type:'trash', x:8280, y:4620 },
    { type:'trash', x:7080, y:5120 }, { type:'trash', x:8280, y:5120 },
    { type:'car_wreck', x:8160, y:5050, w:60, h:28, color:'#3e3b34' },
    { type:'weeds', x:7060, y:4260 }, { type:'weeds', x:8300, y:5280 },
  ];
  
  // v13 wave 6 — interactive props. parallel array to PROPS; only the things that respond to E key
  // or to player attack get an entry here. each carries its own state (cooldown, broken, etc.).
  interactiveProps = [];
  
  // spawn one breakable bottle in a random reachable spot
  
  
  // ---------- ambient chatter ----------
  CHATTER = {
    tony: ["$10.", "no.", "three coats.", "what.", "i said $10."],
    yuri: ["bring metal.", "BRUTUS remember.", "what you want.", "no, you owe."],
    pete: ["one second.", "weighing.", "still weighing."],
    lurch: ["you got a dollar.", "smells like ham.", "i used to be normal."],
    sherri: ["the spider.", "did you see it.", "down my arm again."],
    paulie: ["the face.", "look at the face.", "do you like the face."],
    dave: ["...", "pigeons......", "they coordinate."],
    mom: ["oh sweetie.", "is your mom worried.", "kombucha?"],
    possum: ["...", "the helmet is osha."],
    priest: ["medicine.", "open your mouth.", "blessed are the tic-tacs."],
    conductor: ["the train.", "it has always been coming.", "the schedule lied."],
    larry: ["WHAT.", "I SAID WHAT.", "LOUDER."],
    stripe: ["$8 a rock.", "stripe got the deal.", "for sure not soap."],
    pigeon: ["coo.", "bread.", "$2."],
    biggu: ["tall.", "i am tall.", "i am the big guy."],
    cubscout: ["popcorn?", "$8 a tin.", "my mom is in the car."],
    jogger: ["heart rate 142.", "splits.", "5k."],
    busker: ["la la la", "for tips.", "i wrote this one."],
    dogwalker: ["paisley. no.", "leave it.", "paisley LEAVE IT."],
    cop: ["sir.", "sir please.", "10-4."],
    pinky: ["amore.", "you no like?", "is house cut.", "lira. lira lira.", "buongiorno mi crackhead."],
    math: ["expectation.", "carry the two.", "you a coin flip.", "the numbers know.", "thirty seven percent."],
    brendan: ["it's me!! it's brendan!!", "uncle dean said!!", "stop!!", "i didn't want this beat!!"],
    lease_guy: ["walk-ins.", "unit is a unit.", "key is extra.", "copper counts as a key."],
    gutter_greg: ["inventory.", "duck is one.", "water pending.", "count the cart twice."],
  };


}

// ---------- v22 wave 5.1 — copper sites ----------
// One registry, one engine (activities.js). Each site is DATA: the 3-stage heist flow is
// interpreted, never copied. All sites share the heistsToday cap (3/day) and the 2-4 yield —
// more sites is more neighborhood, not more income. See SPEC-v22-copper-sites.md.
//
// anchor kinds:
//   locked_building — resolves to the BUILDINGS entry with locked:true at call time, so the
//                     abandoned site keeps its shipped availability (gone once rank 4 unboards it).
//   rect            — literal trigger rect. Facade-anchored rects mirror world.js
//                     LANDMARK_FACADES coordinates (copper-sites-gate proves parity); the rust
//                     car mirrors the freight_car prop above (380,2820,220,64).
//
// entry kinds the engine understands: roll (p; under/over effects), lockpick, item, cash,
// wait, sure. Effects: { text, dur?, hp?, wanted?, brain?, shakes?, glass? } — hp/brain are
// costs, wanted/shakes are gains, glass fires audio.glassBreak(). Order of application is
// text -> hp -> glass -> wanted -> brain -> shakes (abandoned-building parity).
export const COPPER_SITES = [
  {
    id: 'abandoned',
    title: 'ABANDONED BUILDING',
    hint: 'test the abandoned boards',
    who: 'brutus jr.',
    anchor: { kind: 'locked_building' },
    capText: "the door is half off.\nthere is no air coming out.\nbrutus jr. is awake and watching the door.\nnot tonight.",
    intro: "the door is half off.\nbrutus jr. is inside. he is asleep.\nyou hear pipes singing in b flat.",
    entries: [
      { kind: 'roll', label: 'sneak past brutus jr.', p: 0.7,
        under: { text: 'you sneak. brutus jr. dreams of a tennis ball.' },
        over:  { text: 'BRUTUS JR. WAKES UP. he is a puppy. he is FURIOUS.', hp: 10 } },
      { kind: 'lockpick', label: 'pick the side door lock. (4-pin lockpick)',
        ok:   { text: "CLICK. the door opens.\nbrutus jr. dreams uninterrupted.\nyou are inside.", glass: true },
        fail: { text: "you give up on the lock.\nthe door is harder than it looks.\nyou take the front door.",
                extraChance: 0.5, extra: { text: 'BRUTUS JR. WAS WAITING.\n- 12 hp', dur: 1800, hp: 12 } } },
      { kind: 'item', itemId: 'soap', consume: 'all',
        haveLabel: 'throw soap as distraction.', lackLabel: 'throw something (you have nothing useful).',
        effect: { text: 'brutus jr. licks the soap. is consumed.' } },
      { kind: 'cash', cost: 3,
        haveLabel: 'pay $3 for a chimichanga distraction.', lackLabel: "you don't have $3.",
        effect: { text: 'the chimichanga is talking.\nbrutus jr. listens.' } },
    ],
    pipes: {
      text: 'the pipes hum.\nin b flat.\nthey are waiting.',
      stripAfter: 'the singing stops.\nyou feel watched.',
      listenAfter: 'they know your name now.',
    },
    getawayText: 'the floor creaks.\nthere is a window.\nthere is also a door.',
    exits: [
      { label: 'window. fast.', p: 0.8,
        under: { text: 'you jump. the landing is bad but legal.', hp: 3 },
        over:  { text: 'the glass breaks. so does your dignity.', hp: 12, glass: true, wanted: 1 } },
      { label: 'door. slow.', p: 0.5,
        under: { text: 'a cop is waiting on the other side.\nyou run.', wanted: 2 },
        over:  { text: 'you walk out like you own the place.\n(you do not.)' } },
    ],
  },
  {
    id: 'cold_not',
    title: 'COLD (NOT)',
    hint: 'try the cold (not) door',
    who: 'dennis (nights)',
    // world.js LANDMARK_FACADES cold_not — warehouse row.
    anchor: { kind: 'rect', facadeId: 'cold_not', x: 4440, y: 1080, w: 450, h: 230 },
    capText: "dennis is at the desk.\nthe log is open to today.\ntoday is full.\nnot tonight.",
    intro: "the warehouse said COLD. the parenthesis said (NOT).\ndennis is at the desk. the desk faces the wrong way.\nsomewhere inside, the old freon lines are singing. b flat. colder.",
    entries: [
      { kind: 'roll', label: 'walk in like you are the day shift.', p: 0.7,
        under: { text: 'you nod at dennis. dennis nods at the nod.\nyou are payroll now.' },
        over:  { text: "dennis asks for your badge.\nyou show him a receipt.\nhe writes you in the log as 'RECEIPT MAN.'", brain: 2 } },
      { kind: 'cash', cost: 2,
        haveLabel: 'buy dennis a coffee from the machine. ($2)', lackLabel: "you don't have $2.",
        effect: { text: 'the machine is dead. you hand him the empty cup.\nhe holds it with both hands.\nthis is the whole transaction.' } },
      { kind: 'wait', label: 'wait for his round.',
        effect: { text: 'dennis walks his route. the route is a circle.\nyou are inside the circle now.\nthe shakes came with you.', shakes: 6 } },
    ],
    pipes: {
      text: 'the freon lines are empty. they sing anyway.\nb flat. colder than the pipes downtown.\nthey are waiting.',
      stripAfter: 'the singing stops.\nthe warehouse is room temperature about it.',
      listenAfter: 'the cold is not here. the song is about that.',
    },
    getawayText: 'the aisles go on.\nthere is a loading dock.\nthere is also the front desk.',
    exits: [
      { label: 'the loading dock.', p: 0.75,
        under: { text: 'you roll off the dock like cargo.\nthe manifest does not mention you.', hp: 2 },
        over:  { text: 'the dock is taller than your plan.', hp: 8 } },
      { label: 'the front desk. wave at dennis.', p: 0.5,
        under: { text: 'dennis waves back.\nthe log says you were never here.\nthe log is wrong twice.' },
        over:  { text: "dennis asks you to sign out.\nyou sign 'RECEIPT MAN.'\nit is legally binding somehow.", brain: 1 } },
    ],
  },
  {
    id: 'water_dept',
    title: 'WATER DEPT. (DRY)',
    hint: 'test the dry grate',
    who: 'the raccoon quorum',
    // world.js LANDMARK_FACADES water_dry — the drainage canal.
    anchor: { kind: 'rect', facadeId: 'water_dry', x: 4460, y: 2250, w: 520, h: 210 },
    capText: "the quorum is in recess.\nthe docket is closed.\nnot tonight.",
    intro: "the water department has no water.\nthe service lines never held any. they sing b flat anyway.\nhigher. like a question.\nseven raccoons are in session on the filing cabinet.",
    entries: [
      { kind: 'roll', label: 'state your business to the quorum.', p: 0.6,
        under: { text: 'you state your business.\nthe raccoons confer.\nthe vote is 4 to 3. you may pass.' },
        over:  { text: 'the vote fails.\na raccoon touches your shoe with its small hand.\nyou lose the argument.', brain: 3 } },
      { kind: 'item', itemId: 'food', consume: 'one',
        haveLabel: 'submit a can of food (unmarked) as evidence.', lackLabel: 'submit evidence (you have no evidence).',
        effect: { text: 'the quorum accepts the can into the record.\nthe can is policy now.\nyou may pass.' } },
      { kind: 'roll', label: 'pry the maintenance grate.', p: 0.5,
        under: { text: 'the grate gives.\nthe quorum notes your method.\nnothing is said.' },
        over:  { text: 'the grate objects. loudly.\nsomeone from the city hears it.', hp: 6, wanted: 1 } },
    ],
    pipes: {
      text: 'the service lines have never held water.\nthey sing b flat. higher.\nlike a question.\nthey are waiting.',
      stripAfter: 'the singing stops.\nthe question does not.',
      listenAfter: 'the question is about you.',
    },
    getawayText: 'the filing room hums.\nthere is an outflow pipe.\nthere are also the front steps.',
    exits: [
      { label: 'the outflow pipe.', p: 0.8,
        under: { text: 'you exit through the outflow.\nthere is no water. there was never water.\nyou are dry and you know things.', hp: 2 },
        over:  { text: 'the pipe narrows where the map said it would not.', hp: 6 } },
      { label: 'the front steps.', p: 0.6,
        under: { text: 'a raccoon on the steps files your departure.\nno action is taken.' },
        over:  { text: 'a man from the city is on the steps.\nhe has a clipboard and has begun walking with purpose.', wanted: 1 } },
    ],
  },
  {
    id: 'rust_car',
    title: 'THE RUST FREIGHT CAR',
    hint: 'try the rust car door',
    who: 'transit authority dan',
    // PROPS freight_car (rust red) above — the train yard. conductor (680,2960) and the
    // hopper (820,2940) sit outside this rect + margin; no interaction collision.
    anchor: { kind: 'rect', propType: 'freight_car', x: 380, y: 2820, w: 220, h: 64 },
    capText: "dan is leaning on the rust car.\nhe is off duty. he says. while patrolling.\nnot tonight.",
    intro: "the rust freight car's door is open one hand.\ninside: signal wire. spooled. singing in b flat.\ntransit authority dan is on the ballast, checking tickets.\nthere are no tickets. there is no transit.",
    entries: [
      { kind: 'roll', label: 'present a ticket you do not have.', p: 0.5,
        under: { text: "you mime the ticket.\ndan punches the air where it would be.\n'proceed.'" },
        over:  { text: 'no ticket.\ndan writes a citation on a transfer slip from 1987.', wanted: 1 } },
      { kind: 'roll', label: 'go along the ballast, between the cars.', p: 0.7,
        under: { text: 'you move car to car.\nthe yard pretends not to notice.\nit is good at this.' },
        over:  { text: 'your foot finds every rock in the yard.\nyou eat ballast.', hp: 6 } },
      { kind: 'sure', label: 'pull the dead signal lever.',
        effect: { text: 'the signal has been wrong since 1987.\nnow it is wrong in green.\ndan salutes it. you walk past the salute.' } },
    ],
    pipes: {
      text: 'the signal wire is spooled to the ceiling.\nit sings b flat.\nthe whole car is a tuning fork.\nit is waiting.',
      stripAfter: 'the singing stops.\nthe car goes back to being a box.',
      listenAfter: 'the car remembers being a train.',
    },
    getawayText: 'the door is still one hand wide.\nthere are the couplers.\nthere is also the main gate.',
    exits: [
      { label: 'over the couplers.', p: 0.7,
        under: { text: 'you go over the couplers.\na freight car approves. silently.', hp: 2 },
        over:  { text: 'the coupler was higher than your leg believed.', hp: 10 } },
      { label: 'the main gate.', p: 0.4,
        under: { text: 'dan is explaining jurisdiction to the conductor.\nneither is listening. you walk.' },
        over:  { text: 'dan radios a department that was disbanded.\nsomeone answers.', wanted: 2 } },
    ],
  },
];

// Trigger lookup shared by tryInteract (interactions.js) and resolveActionHint (campaigns.js).
// Same ±20px proximity margin the abandoned building has always used. Returns the first
// available site whose rect contains the point, or null. The abandoned site resolves its rect
// from the still-locked BUILDINGS entry, which is also its availability switch.
export function copperSiteAt(cx, cy) {
  const margin = 20;
  for (const site of COPPER_SITES) {
    let r = site.anchor;
    if (r.kind === 'locked_building') {
      r = BUILDINGS && BUILDINGS.find(b => b.locked);
      if (!r) continue;
    }
    if (cx > r.x - margin && cx < r.x + r.w + margin && cy > r.y - margin && cy < r.y + r.h + margin) return site;
  }
  return null;
}

// ---------- v22 wave 5.5 — break-in sites ----------
// Same engine as COPPER_SITES (activities.js, I-ONE-ENGINE), second table. Break-ins
// differ from copper in exactly three data facts, not in flow:
//   1. `gates` — the door itself is gated. Kinds: tool (P.equip.tool identity) and
//      cred (P.cred >= n). Gates evaluate in listed order and ALL must pass; the
//      first failing gate states its refusal — never a silent no-op. A site listing
//      tool before cred means the door is answered before the reputation is.
//   2. `loot` — stage 2 is the take (specific cursed loot per building), not the
//      copper pipes. Loot is fixed, small, and structurally incapable of granting
//      copper or rocks — breakin-gate locks the allowed keys.
//   3. the governor — break-ins count `breakinsToday` (cap 2/day, activities.js),
//      NEVER `heistsToday`, so copper and break-ins cannot starve each other
//      (I-NO-MINT-DRIFT). A refused door does not spend the day's cap.
// Entries and exits use the exact copper vocabulary and effect bounds.
export const BREAKIN_SITES = [
  {
    id: 'model_home',
    title: 'MODEL HOME',
    hint: 'pry the model home',
    who: 'the model family',
    anchor: { kind: 'rect', propType: 'breakin_shell', x: 950, y: 4350, w: 240, h: 150 },
    gates: [
      { kind: 'tool', tool: 'crowbar',
        refuse: "the windows are plywood. the plywood is municipal.\nyour fingers are not.\na crowbar would change this conversation." },
    ],
    capText: "the plywood is back up.\nnobody put it back up.\nnot tonight.",
    intro: "the sign says MODEL HOME. the development never came.\ninside, the model family is at dinner.\nthey have been at dinner since 2016.\nthe food is plastic. the commitment is not.",
    entries: [
      { kind: 'roll', label: 'walk past the dining room. naturally.', p: 0.7,
        under: { text: 'you walk like a buyer.\nthe father watches you with the confidence\nof a man with no eyes.' },
        over:  { text: 'you knock the son over.\nhe keeps his pose on the floor. mid-toast.\nyou set him back. nobody saw.\nthe mother saw.', brain: 2 } },
      { kind: 'sure', label: 'compliment the kitchen.',
        effect: { text: "you say 'granite.'\nno one answers.\nthe kitchen accepts the compliment\non its own behalf." } },
      { kind: 'wait', label: 'wait for the family to finish dinner.',
        effect: { text: 'they do not finish.\nthey were never going to finish.\nyou stop waiting.', shakes: 6 } },
    ],
    loot: {
      title: 'THE STAGING',
      text: "the staging envelope is taped under the table.\n$14. the label says FOR REALISM.\non the table: a bowl of plastic fruit.\none of the apples is real. it has always been real.",
      takeLabel: 'take the envelope. and the real apple.',
      cash: 14,
      items: [{ id: 'food', n: 'an apple (real, from the bowl)' }],
      takeToast: "+ $14 (FOR REALISM)\n+ an apple (real, from the bowl)\nthe family does not turn.\nthe dinner goes on.",
      takeDur: 4200,
      altLabel: 'sit at the table instead.',
      alt: { brain: 8, text: 'you sit in the empty chair.\nthere was always an empty chair.\n+ 8 brain\nyou leave before it means something.', dur: 4200 },
    },
    getawayText: 'the front door is where you left it.\nthere is also the garage.\nthe garage has never held a car.',
    exits: [
      { label: 'the garage.', p: 0.75,
        under: { text: 'the garage door rolls up.\nyou exit through a garage that has never held a car.\nit holds you briefly. then nothing again.' },
        over:  { text: 'the door comes down on you.\nmunicipal plywood. municipal spite.', hp: 8 } },
      { label: 'the front door. like a buyer.', p: 0.5,
        under: { text: "you leave through the front door.\nyou wave at the family.\nthe father's confidence follows you out." },
        over:  { text: 'a man with a clipboard is on the lawn.\nhe has been sent about the plywood.\nhe begins walking with purpose.', wanted: 1 } },
    ],
  },
  {
    id: 'spoil_bank',
    title: 'THE SPOIL BANK',
    hint: 'present yourself at the spoil bank',
    who: 'the former teller',
    anchor: { kind: 'rect', propType: 'breakin_shell', x: 3350, y: 4450, w: 260, h: 140 },
    gates: [
      { kind: 'cred', cred: 25,
        refuse: "the teller looks through the little window.\nthe window is a gap in the dirt.\n'the bank knows everyone.\nthe bank does not know you.'\ncome back somebody." },
    ],
    capText: "the window shows CLOSED.\nthe sign is written on a shovel.\nbanking hours are over.\nnot tonight.",
    intro: "a vault door in a hill of fill dirt.\nthe bank was demolished in 1994.\nthe vault did not attend.\nthe former teller keeps the hours.\nthe hours are whenever he is here. he is always here.",
    entries: [
      { kind: 'roll', label: 'state a plausible account number.', p: 0.6,
        under: { text: "you say nine digits with confidence.\nhe stamps a paper that stamps nothing.\n'go on through.'" },
        over:  { text: 'you say eight digits.\nhe notices. of course he notices.\nhe makes you fill out a form\nfor the missing digit.', brain: 3 } },
      { kind: 'cash', cost: 2,
        haveLabel: 'pay the service fee. ($2)', lackLabel: "you don't have $2.",
        effect: { text: 'he takes the two dollars.\nhe puts it in the drawer.\nthe drawer is a shoe.' } },
      { kind: 'wait', label: 'wait in line.',
        effect: { text: 'there is no line.\nyou wait in it anyway.\nhe respects this deeply.', shakes: 6 } },
    ],
    loot: {
      title: 'THE VAULT',
      text: 'the vault is dirt on three sides.\nthe shelves hold what the fill dirt brought:\na paper band labeled $2,000.\ninside the band: $18.\na deposit slip, blank since 1994.',
      takeLabel: 'take the band. and the slip.',
      cash: 18,
      items: [{ id: 'junk', n: 'a deposit slip (blank, 1994)' }],
      takeToast: '+ $18 (the band said $2,000)\n+ a deposit slip (blank, 1994)\nthe shortfall is not your business.',
      takeDur: 4200,
      altLabel: 'ask the teller about compound interest.',
      alt: { brain: 8, text: 'he explains compound interest to the dirt.\nthe dirt compounds.\n+ 8 brain', dur: 3600 },
    },
    getawayText: 'the vault door is open.\nthere is also the hole in the back.\nthe hole is not on the schematic.',
    exits: [
      { label: 'the hole in the back.', p: 0.8,
        under: { text: 'you exit through the hole.\nyou are in the spoil.\nyou were always in the spoil.', hp: 2 },
        over:  { text: 'the hole narrows.\nthe dirt takes a deposit.', hp: 8 } },
      { label: 'the front. past the teller.', p: 0.6,
        under: { text: "he stamps you out.\n'the bank thanks you.'\nthe bank is a hill." },
        over:  { text: 'he asks you to sign the register.\nyou sign a name. not yours.\nhe files it under that name forever.', brain: 2 } },
    ],
  },
  {
    id: 'sod_office',
    title: 'SOD FARM OFFICE',
    hint: 'try the sod office door',
    who: 'the goose (manager)',
    anchor: { kind: 'rect', propType: 'breakin_shell', x: 4800, y: 5050, w: 240, h: 130 },
    // Both gates — the precedence witness. Listed order rules: the door (tool) is
    // answered before the goose (cred). Both must pass.
    gates: [
      { kind: 'tool', tool: 'crowbar',
        refuse: 'the door is swollen shut since the sod left.\nit needs a crowbar.\nthe goose watches you not have one.' },
      { kind: 'cred', cred: 50,
        refuse: 'the door would open.\nthe goose is standing on the desk.\nthe goose has not heard of you.\ncome back famous.' },
    ],
    capText: 'the goose is at the window.\nthe window is closed. the goose closed it.\nnot tonight.',
    intro: 'the sod farm office. the sod left in 2019.\nthe lawns it grew are still out there.\nsomewhere. being lawns.\na goose stands on the desk.\nit was not hired. it is the manager.',
    entries: [
      { kind: 'roll', label: 'announce yourself to the goose.', p: 0.6,
        under: { text: 'you state your name and business.\nthe goose accepts neither.\nit lets you pass anyway. management.' },
        over:  { text: 'the goose objects.\nthe objection connects.\nyou are hit by middle management.', hp: 6 } },
      { kind: 'item', itemId: 'food', consume: 'one',
        haveLabel: 'submit a can of food (unmarked) to the manager.', lackLabel: 'submit an offering (you have nothing canned).',
        effect: { text: 'the goose stands on the can.\nthe can is office equipment now.\nyou may pass.' } },
      { kind: 'sure', label: 'read the org chart on the wall.',
        effect: { text: 'the org chart is a photo of the goose.\nunder it, a name. the name is redacted.\nyou pass beneath the chart.' } },
    ],
    loot: {
      title: 'PETTY CASH',
      text: 'the petty cash tin is where tins are.\ninside: $9 and a receipt for $9.\non the wall: a rain gauge. dry. municipal.\na laminated map of lawns that no longer exist.',
      takeLabel: 'take the tin. and the rain gauge.',
      cash: 9,
      items: [{ id: 'junk', n: 'a rain gauge (dry)' }],
      takeToast: '+ $9 (receipt included)\n+ a rain gauge (dry)\nthe goose does not turn.\nthe goose knew.',
      takeDur: 4200,
      altLabel: 'study the map of former lawns.',
      alt: { brain: 8, text: 'the lawns are numbered.\nlawn 34 is circled.\nno reason is given.\n+ 8 brain', dur: 3600 },
    },
    getawayText: 'the door you pried is still pried.\nthere is also the loading window.\nthe goose is between you and both.',
    exits: [
      { label: 'the loading window.', p: 0.7,
        under: { text: 'you fold through the window.\nthe landing is soft.\nit is sod. the last sod.', hp: 2 },
        over:  { text: 'the window frame keeps a piece of your coat.\nthe goose files this.', hp: 6, wanted: 1 } },
      { label: 'past the goose. with dignity.', p: 0.5,
        under: { text: 'you walk past the goose.\nthe goose allows it.\nthis was a performance review.\nyou passed.' },
        over:  { text: 'the goose escorts you out.\nat speed.\nhonking. municipal honking.', hp: 4, wanted: 1 } },
    ],
  },
];

// Trigger lookup — same contract and margin as copperSiteAt, second table. Shared by
// tryInteract (interactions.js) and resolveActionHint (campaigns.js); breakin-gate
// proves the two lookups never answer for each other's sites.
export function breakinSiteAt(cx, cy) {
  const margin = 20;
  for (const site of BREAKIN_SITES) {
    const r = site.anchor;
    if (cx > r.x - margin && cx < r.x + r.w + margin && cy > r.y - margin && cy < r.y + r.h + margin) return site;
  }
  return null;
}
