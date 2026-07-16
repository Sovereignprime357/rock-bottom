/* Generated from frozen rock_bottom_v19.html.
 * Source seams: buildings, props, and interactive props.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { dialogue, state } from '../core/runtime_ui.js';
import { buildGraffiti } from '../render/structures.js';

export let BUILDINGS, PROPS, interactiveProps, CHATTER;

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
    { type:'cart', x:1100, y:1520, w:24, h:20, color:'#888', mounted:false },
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
