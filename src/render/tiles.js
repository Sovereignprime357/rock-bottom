/* Generated from frozen rock_bottom_v19.html.
 * Source seams: tile palettes and market stalls.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { BUILDINGS } from '../data/props.js';
import { TERRAIN_REGIONS, TILE, ZONES } from '../data/world.js';
import { ctx, drawWorldFabric, visibleWorldRect } from './canvas_geography.js';

export let TILE_PALETTES;

export function zoneAt(wx, wy) {
  for (const z of ZONES) {
    if (wx>=z.x && wx<z.x+z.w && wy>=z.y && wy<z.y+z.h) return z.id;
  }
  return 'default';
}

export function terrainAt(wx, wy) {
  const zid = zoneAt(wx, wy);
  if (zid !== 'default') return zid;
  for (const r of TERRAIN_REGIONS) {
    if (wx>=r.x && wx<r.x+r.w && wy>=r.y && wy<r.y+r.h) return r.palette;
  }
  return 'default';
}

export function drawGroundTile(x, y) {
  const cx = x + TILE/2, cy = y + TILE/2;
  const zid = terrainAt(cx, cy);
  const pal = TILE_PALETTES[zid] || TILE_PALETTES.default;
  const checker = ((x/TILE)+(y/TILE)) & 1;
  ctx.fillStyle = pal.base[checker];
  ctx.fillRect(x, y, TILE, TILE);
  // deterministic per-tile pseudo-random
  const h = (x*73 ^ y*131) >>> 0;
  // procedural grime patches
  if ((h % 97) < 12) {
    ctx.fillStyle = pal.grime;
    const gx = x + 6 + (h % 40);
    const gy = y + 8 + ((h>>5) % 36);
    ctx.fillRect(gx, gy, 10 + ((h>>3)%14), 6 + ((h>>7)%10));
  }
  // crack lines
  if ((h % 89) < 6) {
    ctx.strokeStyle = pal.crack;
    ctx.lineWidth = 1;
    ctx.beginPath();
    const cx0 = x + (h%TILE);
    const cy0 = y + ((h>>2)%TILE);
    ctx.moveTo(cx0, cy0);
    ctx.lineTo(cx0 + 8, cy0 + 4);
    ctx.lineTo(cx0 + 14, cy0 + 2);
    ctx.stroke();
  }
  // brick grout lines on marketplace
  if (pal.brick) {
    ctx.strokeStyle = 'rgba(40,20,10,.4)';
    ctx.lineWidth = 1;
    const off = (y / TILE) & 1 ? TILE/2 : 0;
    ctx.beginPath();
    for (let bx=0; bx<TILE; bx+=16) {
      ctx.moveTo(x+bx+off, y);
      ctx.lineTo(x+bx+off, y+TILE/2);
      ctx.moveTo(x+bx+off-8, y+TILE/2);
      ctx.lineTo(x+bx+off-8, y+TILE);
    }
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // tile grid for laundromat
  if (pal.tile) {
    ctx.strokeStyle = 'rgba(40,60,90,.4)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x+0.5, y+0.5, TILE-1, TILE-1);
    ctx.beginPath();
    ctx.moveTo(x+TILE/2, y); ctx.lineTo(x+TILE/2, y+TILE);
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // weed clumps on the block
  if (pal.weed && (h % 211) < 8) {
    const wx = x + (h % TILE), wy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#2a3818';
    ctx.fillRect(wx, wy, 3, 4);
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(wx+1, wy-1, 1, 2);
  }
  // v13 wave 6 — underpass: oil stains (black slick blobs) on top of the cracked concrete
  if (pal.oilstain && (h % 137) < 6) {
    const ox = x + 8 + (h % 36);
    const oy = y + 10 + ((h>>2) % 30);
    ctx.fillStyle = 'rgba(8,6,4,.72)';
    ctx.beginPath();
    ctx.ellipse(ox, oy, 7 + ((h>>3)%5), 4 + ((h>>5)%3), 0, 0, Math.PI*2);
    ctx.fill();
    // iridescent rainbow sheen on top
    ctx.fillStyle = 'rgba(80,60,90,.25)';
    ctx.fillRect(ox-3, oy-1, 6, 1);
  }
  // v13 wave 6 — underpass: cracked-concrete bigger fracture lines
  if (pal.concrete && (h % 73) < 9) {
    ctx.strokeStyle = 'rgba(0,0,0,.55)';
    ctx.lineWidth = 1;
    const cx1 = x + (h%TILE), cy1 = y + ((h>>4)%TILE);
    ctx.beginPath();
    ctx.moveTo(cx1, cy1);
    ctx.lineTo(cx1 + 16, cy1 + 6);
    ctx.lineTo(cx1 + 22, cy1 + 14);
    ctx.lineTo(cx1 + 12, cy1 + 22);
    ctx.stroke();
  }
  // v13 wave 6 — scrap yard: dirt mottling (warm clumps) reading as raked earth not pavement
  if (pal.dirt && (h % 53) < 14) {
    const dx = x + (h % TILE), dy = y + ((h>>3) % TILE);
    ctx.fillStyle = 'rgba(100,60,28,.32)';
    ctx.fillRect(dx, dy, 4, 3);
    if ((h % 211) < 30) {
      ctx.fillStyle = 'rgba(60,40,20,.5)';
      ctx.fillRect(dx+1, dy+1, 2, 1);
    }
  }
  // puddles in alley
  if (pal.puddle && (h % 167) < 5) {
    const px2 = x + 10 + (h % 30);
    const py2 = y + 14 + ((h>>3) % 24);
    ctx.fillStyle = 'rgba(40,55,70,.55)';
    ctx.beginPath();
    ctx.ellipse(px2, py2, 11, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(180,200,220,.18)';
    ctx.fillRect(px2-6, py2-1, 5, 1);
  }
  // v13 wave 8a — train yard: gravel ballast (small dark flecks)
  if (pal.gravel && (h % 41) < 18) {
    const gx = x + (h % TILE), gy = y + ((h>>3) % TILE);
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(gx, gy, 2, 2);
    if ((h % 113) < 30) {
      ctx.fillStyle = 'rgba(120,100,80,.3)';
      ctx.fillRect(gx+1, gy+1, 1, 1);
    }
  }
  // v13 wave 8a — train yard: horizontal rail bands. each band is 4px tall every 48px on the tile.
  // we render the bands as part of the ground tile so it's free per-tile work.
  if (pal.tracks) {
    // two parallel rails per tile row, with crossties between
    const railY1 = y + 22;
    const railY2 = y + 40;
    // dark crosstie underneath (wood)
    ctx.fillStyle = 'rgba(40,28,16,.55)';
    for (let tx=0; tx<TILE; tx+=14) {
      ctx.fillRect(x+tx+2, railY1-3, 8, railY2-railY1+6);
    }
    // steel rails
    ctx.fillStyle = '#605c50';
    ctx.fillRect(x, railY1, TILE, 2);
    ctx.fillRect(x, railY2, TILE, 2);
    // shine highlight on the rail head
    ctx.fillStyle = 'rgba(180,170,150,.35)';
    ctx.fillRect(x, railY1, TILE, 1);
    ctx.fillRect(x, railY2, TILE, 1);
  }
  // v13 wave 8a — park: grass tufts + occasional dandelion
  if (pal.grass && (h % 31) < 14) {
    const gx = x + (h % TILE), gy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#3a6028';
    ctx.fillRect(gx, gy, 1, 3);
    ctx.fillRect(gx+1, gy-1, 1, 4);
    ctx.fillRect(gx-1, gy, 1, 2);
    if ((h % 211) < 9) {
      // dandelion head
      ctx.fillStyle = '#e8c040';
      ctx.fillRect(gx+1, gy-3, 2, 2);
    }
  }
  // v13 wave 8a — skid row: scattered trash flecks (cigarette butts, wrappers)
  if (pal.skidtrash && (h % 47) < 7) {
    const tx = x + (h % TILE), ty = y + ((h>>3) % TILE);
    const flick = h & 1;
    ctx.fillStyle = flick ? '#5a4030' : '#a08868';
    ctx.fillRect(tx, ty, 3, 1);
    if ((h % 113) < 20) {
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(tx+1, ty, 1, 1);
    }
  }
  // v13 wave 8a — old school: faint chalk smudges + hopscotch flecks
  if (pal.schoolyard && (h % 79) < 5) {
    const cx = x + (h % TILE), cy = y + ((h>>2) % TILE);
    ctx.fillStyle = 'rgba(220,210,180,.25)';
    ctx.fillRect(cx, cy, 4, 1);
    ctx.fillRect(cx+1, cy+2, 2, 1);
  }
  // v14 — connective-region material accents.
  if (pal.deadgrass && (h % 43) < 10) {
    const gx = x + (h % TILE), gy = y + ((h>>4) % TILE);
    ctx.fillStyle = '#5a5028';
    ctx.fillRect(gx, gy, 1, 4);
    ctx.fillRect(gx+2, gy+1, 1, 3);
    ctx.fillStyle = '#786438';
    ctx.fillRect(gx+1, gy, 1, 2);
  }
  if (pal.patch && (h % 101) < 8) {
    const px = x + 5 + (h % 28), py = y + 9 + ((h>>3) % 28);
    ctx.fillStyle = 'rgba(8,7,5,.28)';
    ctx.fillRect(px, py, 18 + ((h>>5)%16), 11 + ((h>>7)%10));
    ctx.strokeStyle = 'rgba(94,78,54,.24)';
    ctx.strokeRect(px+.5, py+.5, 18 + ((h>>5)%16), 11 + ((h>>7)%10));
  }
  if (pal.wet && (h % 127) < 8) {
    const px = x + 10 + (h % 30), py = y + 12 + ((h>>3) % 26);
    ctx.fillStyle = 'rgba(38,55,56,.5)';
    ctx.beginPath();
    ctx.ellipse(px, py, 13, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(168,180,166,.12)';
    ctx.fillRect(px-7, py-1, 7, 1);
  }
  if (pal.transit) {
    ctx.fillStyle = 'rgba(232,192,64,.12)';
    ctx.fillRect(x, y+TILE-5, TILE, 3);
  }
}

export function drawMarketStalls() {
  const z = ZONES.find(z=>z.id==='market');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,48)) return;
  for (let i=0;i<4;i++) {
    const px = z.x + 80 + i*160;
    const py = z.y + 60;
    // base table
    ctx.fillStyle = '#3a2a1a';
    ctx.fillRect(px, py+10, 90, 22);
    ctx.fillStyle = '#5a4828';
    ctx.fillRect(px, py+10, 90, 6);
    // table legs
    ctx.fillStyle = '#1a1008';
    ctx.fillRect(px+2, py+30, 4, 8);
    ctx.fillRect(px+84, py+30, 4, 8);
    ctx.strokeStyle = '#1a1008';
    ctx.lineWidth = 1;
    ctx.strokeRect(px, py+10, 90, 22);
    // umbrella stripes
    const colors = [['#a8484a','#7a2a2c'],['#5a6028','#3a4018'],['#7a5028','#503018'],['#b8d040','#88a020']];
    const [base, dark] = colors[i];
    for (let s=0; s<13; s++) {
      ctx.fillStyle = (s & 1) ? base : dark;
      ctx.fillRect(px-8 + s*8.2, py-10, 8, 12);
    }
    // umbrella pole
    ctx.fillStyle = '#3a3020';
    ctx.fillRect(px+44, py+2, 2, 10);
    // wares on table
    ctx.fillStyle = ['#e8c040','#d488d4','#88c0ff','#d06030'][i];
    ctx.fillRect(px+18, py+14, 6, 6);
    ctx.fillRect(px+38, py+14, 6, 6);
    ctx.fillRect(px+58, py+14, 6, 6);
    ctx.fillStyle = ['#a08030','#8a5090','#5080a0','#a04020'][i];
    ctx.fillRect(px+18, py+18, 6, 2);
    ctx.fillRect(px+38, py+18, 6, 2);
    ctx.fillRect(px+58, py+18, 6, 2);
  }
}

export function init_tiles() {
  // ---------- Per-zone tile palettes (v10 visual overhaul) ----------
  TILE_PALETTES = {
    default:    { base:['#1a1810','#181610'], grime:'rgba(40,30,20,.55)', crack:'rgba(8,6,4,.4)' },
    block:      { base:['#22201a','#1f1d18'], grime:'rgba(80,60,30,.35)', crack:'rgba(0,0,0,.5)', weed:true },
    pawn:       { base:['#2a2818','#28261a'], grime:'rgba(60,50,30,.35)', crack:'rgba(8,6,4,.6)' },
    dealer:     { base:['#2a1a15','#241814'], grime:'rgba(140,40,30,.3)', crack:'rgba(0,0,0,.55)' },
    abandoned:  { base:['#1c1818','#181414'], grime:'rgba(80,30,30,.45)', crack:'rgba(0,0,0,.65)' },
    market:     { base:['#322a22','#2c241e'], grime:'rgba(168,80,30,.3)', crack:'rgba(0,0,0,.45)', brick:true },
    alley:      { base:['#161614','#131312'], grime:'rgba(20,60,80,.35)', crack:'rgba(0,0,0,.8)', puddle:true },
    church:     { base:['#262030','#221c2a'], grime:'rgba(80,60,100,.35)', crack:'rgba(0,0,0,.6)' },
    projects:   { base:['#1d1c20','#191820'], grime:'rgba(60,60,90,.3)', crack:'rgba(0,0,0,.6)' },
    // v13 wave 6 — underpass gets a heavier cracked-concrete palette: lighter base, oil stains, deeper cracks
    underpass:  { base:['#2a2a2d','#252528'], grime:'rgba(20,18,14,.55)', crack:'rgba(0,0,0,.85)', concrete:true, oilstain:true },
    laundromat: { base:['#3a3a48','#34344a'], grime:'rgba(120,160,200,.18)', crack:'rgba(0,0,0,.4)', tile:true },
    busstop:    { base:['#27251f','#23211c'], grime:'rgba(90,70,40,.32)', crack:'rgba(0,0,0,.58)', concrete:true, transit:true },
    // v13 wave 6 — scrap yard pushed warmer dirt brown so it reads as Yuri's home turf, not generic concrete
    scrap:      { base:['#3a2c1a','#322618'], grime:'rgba(120,60,30,.45)', crack:'rgba(50,30,15,.5)', dirt:true },
    // v14 draws coherent full-length rails in drawWorldFabric; the tile owns ballast only.
    trainyard:  { base:['#2c2a26','#26241f'], grime:'rgba(90,80,60,.4)', crack:'rgba(0,0,0,.55)', gravel:true },
    // v13 wave 8a — park gets a green grass palette + tufts/dandelions
    park:       { base:['#2e4a26','#28401f'], grime:'rgba(80,140,50,.18)', crack:'rgba(0,0,0,.25)', grass:true },
    // v13 wave 8a — skid row gets darker, oilier cracked asphalt than underpass + more trash flecks
    skidrow:    { base:['#1f1d18','#1b1915'], grime:'rgba(30,18,10,.55)', crack:'rgba(0,0,0,.85)', concrete:true, skidtrash:true },
    // v13 wave 8a — old school: weedy cracked playground concrete with chalk smudges
    oldschool:  { base:['#2a201c','#241a16'], grime:'rgba(120,70,40,.3)', crack:'rgba(0,0,0,.55)', schoolyard:true, weed:true },
    // v18 far-east materials. Tile geometry remains visual; declared STRUCTURES own collision.
    warehouse_row:{ base:['#292720','#25231e'], grime:'rgba(86,58,34,.42)', crack:'rgba(0,0,0,.76)', concrete:true, oilstain:true, patch:true },
    canal:        { base:['#252a27','#202522'], grime:'rgba(42,70,62,.42)', crack:'rgba(0,0,0,.72)', concrete:true, wet:true },
    the_lot:      { base:['#2b261d','#272219'], grime:'rgba(92,66,34,.38)', crack:'rgba(0,0,0,.66)', deadgrass:true, patch:true, weed:true },
    // v19 curb kingdoms. They are visually distinct but mechanically faction-neutral.
    blue_tarp_court:   { base:['#29333a','#252d33'], grime:'rgba(55,75,88,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true, wet:true },
    cart_cavalry_keep: { base:['#302c24','#29261f'], grime:'rgba(74,58,38,.48)', crack:'rgba(0,0,0,.78)', concrete:true, oilstain:true, skidtrash:true },
    copper_choir_yard: { base:['#39291e','#32241b'], grime:'rgba(130,68,35,.38)', crack:'rgba(54,28,14,.62)', dirt:true, oilstain:true, deadgrass:true },
    throne_ditch:      { base:['#292821','#24241f'], grime:'rgba(56,72,66,.48)', crack:'rgba(0,0,0,.8)', concrete:true, wet:true, deadgrass:true },
    // v14 outside-zone materials. They fill the connective world but never replace a zone palette.
    vacant:          { base:['#28231a','#242017'], grime:'rgba(96,66,34,.42)', crack:'rgba(0,0,0,.55)', dirt:true, deadgrass:true },
    service:         { base:['#211f1a','#1e1c18'], grime:'rgba(72,52,34,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true },
    drainage:        { base:['#201f1c','#1d1c19'], grime:'rgba(44,58,54,.45)', crack:'rgba(0,0,0,.78)', concrete:true, wet:true },
    rail_approach:   { base:['#302b22','#29251d'], grime:'rgba(95,70,42,.4)', crack:'rgba(0,0,0,.58)', gravel:true, deadgrass:true },
    dead_grass:      { base:['#292419','#252016'], grime:'rgba(95,76,38,.38)', crack:'rgba(0,0,0,.58)', dirt:true, deadgrass:true },
    school_outskirts:{ base:['#292019','#251b16'], grime:'rgba(100,64,36,.34)', crack:'rgba(0,0,0,.62)', schoolyard:true, deadgrass:true },
  };
  
  
  
  
  
  
  
}
