/* Generated from frozen rock_bottom_v19.html.
 * Source seams: buildings, graffiti, posters, and claim visuals.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, state } from '../core/runtime_ui.js';
import { updateWorld } from '../core/update.js';
import { GRAFFITI_LINES, SCRAP_GRAFFITI_LINES, SPIRITUAL_GRAFFITI_LINES } from '../data/catalogs.js';
import { isNight } from '../data/npc_spawns.js';
import { BUILDINGS } from '../data/props.js';
import { ZONES } from '../data/world.js';
import { HIDEOUT_DOORS, hideoutOwned } from '../legacy.js';
import { ENV_SPRITE_CACHE, ctx, visibleWorldRect } from './canvas_geography.js';
import { zoneAt } from './tiles.js';
import { CLAIM_SITES, OFFICE_DOOR, claimedDistrictIds, freshOfficeState } from '../systems/campaigns.js';

export let BUILDING_STYLE, GRAFFITI_PALETTES, POSTER_LINES, POSTER_BG;

export function drawBuilding(b) {
  // base shadow under building
  ctx.fillStyle = 'rgba(0,0,0,.45)';
  ctx.fillRect(b.x+4, b.y+b.h, b.w-8, 6);
  // wall — base color
  ctx.fillStyle = b.color;
  ctx.fillRect(b.x, b.y, b.w, b.h);
  // brick texture overlay (subtle)
  ctx.fillStyle = 'rgba(0,0,0,.12)';
  for (let by=8; by<b.h; by+=10) {
    const off = ((by/10) & 1) ? 8 : 0;
    for (let bx=0; bx<b.w; bx+=16) {
      ctx.fillRect(b.x+bx+off, b.y+by, 14, 1);
    }
  }
  for (let by=0; by<b.h; by+=10) {
    for (let bx=0; bx<b.w; bx+=16) {
      const off = ((by/10) & 1) ? 8 : 0;
      ctx.fillRect(b.x+bx+off+13, b.y+by, 1, 10);
    }
  }
  // border / mortar shadow
  ctx.strokeStyle = b.border;
  ctx.lineWidth = 3;
  ctx.strokeRect(b.x+1, b.y+1, b.w-2, b.h-2);
  // top edge highlight
  ctx.fillStyle = 'rgba(255,240,180,.08)';
  ctx.fillRect(b.x, b.y, b.w, 2);

  const style = BUILDING_STYLE[b.name];
  // awning
  if (style && style.awning && !(b.locked && P.rank < 4)) {
    const aw = b.w - 12;
    const aH = 12;
    ctx.fillStyle = style.awning;
    // alternating stripes
    for (let s=0; s<Math.floor(aw/8); s++) {
      ctx.fillStyle = (s & 1) ? style.awning : '#fff8d0';
      ctx.fillRect(b.x + 6 + s*8, b.y - aH + 2, 8, aH);
    }
    // awning frame
    ctx.fillStyle = '#1a1008';
    ctx.fillRect(b.x+6, b.y-aH, aw, 3);
    ctx.fillRect(b.x+6, b.y-aH+2, 3, aH);
    ctx.fillRect(b.x+b.w-9, b.y-aH+2, 3, aH);
  }

  // windows
  if (!b.locked || P.rank >= 4) {
    const winY = b.y + (style && style.awning ? 18 : 14);
    const winH = 18;
    const winN = Math.max(2, Math.floor(b.w / 40));
    const gap = (b.w - winN*22) / (winN+1);
    for (let i=0;i<winN;i++) {
      const wx = b.x + gap + i*(22+gap);
      // window frame (dark)
      ctx.fillStyle = '#0a0805';
      ctx.fillRect(wx-1, winY-1, 24, winH+2);
      // window pane (lit / dim based on time)
      const baseLit = isNight() ? 1 : 0.55;
      const flick = (b.name === 'CORNER') ? (Math.sin(performance.now()/110 + i*0.7)>0.3) : false;
      let paneColor;
      if (b.name === 'CHURCH') {
        // stained glass — alternates cells
        paneColor = ['#d488d4','#88c0ff','#e8c040','#a8c030'][(i + Math.floor(winY/2)) % 4];
        ctx.fillStyle = paneColor;
        ctx.fillRect(wx, winY, 22, winH);
        // lead came (cross + diagonals)
        ctx.strokeStyle = '#0a0805';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(wx+11, winY); ctx.lineTo(wx+11, winY+winH);
        ctx.moveTo(wx, winY+winH/2); ctx.lineTo(wx+22, winY+winH/2);
        ctx.moveTo(wx, winY); ctx.lineTo(wx+22, winY+winH);
        ctx.moveTo(wx+22, winY); ctx.lineTo(wx, winY+winH);
        ctx.stroke();
      } else if (b.name === 'LAUNDROMAT') {
        // bright fluorescent
        ctx.fillStyle = `rgba(180,220,255,${0.5 + baseLit*0.3})`;
        ctx.fillRect(wx, winY, 22, winH);
        // washing machine drum visible
        ctx.fillStyle = 'rgba(0,0,0,.5)';
        ctx.beginPath();
        ctx.arc(wx+11, winY+winH/2, 6, 0, Math.PI*2);
        ctx.fill();
        ctx.fillStyle = '#88c0ff';
        ctx.beginPath();
        ctx.arc(wx+11, winY+winH/2, 4, 0, Math.PI*2);
        ctx.fill();
        // spin
        const spin = performance.now()/300 + i;
        ctx.fillStyle = '#0a0805';
        ctx.fillRect(wx+9 + Math.cos(spin)*2, winY+winH/2 + Math.sin(spin)*2 - 1, 4, 2);
      } else if (b.name === 'CORNER') {
        // dark with flickering TV
        ctx.fillStyle = '#080805';
        ctx.fillRect(wx, winY, 22, winH);
        ctx.fillStyle = flick ? '#88c0ff' : '#3a4858';
        ctx.fillRect(wx+4, winY+5, 14, 9);
        // TV stand
        ctx.fillStyle = '#1a1010';
        ctx.fillRect(wx+9, winY+winH-3, 4, 2);
      } else {
        // generic warm light interior
        ctx.fillStyle = `rgba(232,192,64,${baseLit})`;
        ctx.fillRect(wx, winY, 22, winH);
        // PAWN — Pete behind glass
        if (b.name === 'PAWN' && i === 0) {
          ctx.fillStyle = '#3a2818';
          ctx.fillRect(wx+6, winY+4, 10, 10);
          ctx.fillStyle = '#d4c896';
          ctx.fillRect(wx+8, winY+6, 6, 4);
          // hot pocket steam
          if (isNight()) {
            const t = performance.now()/400;
            ctx.fillStyle = 'rgba(232,232,200,.4)';
            ctx.beginPath();
            ctx.arc(wx+11 + Math.sin(t)*2, winY+1 - (t%4)*1.5, 1.5, 0, Math.PI*2);
            ctx.fill();
          }
        }
        // cross panes
        ctx.strokeStyle = 'rgba(20,10,5,.85)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(wx+11, winY); ctx.lineTo(wx+11, winY+winH);
        ctx.moveTo(wx, winY+winH/2); ctx.lineTo(wx+22, winY+winH/2);
        ctx.stroke();
      }
      // window-sill
      ctx.fillStyle = '#5a4028';
      ctx.fillRect(wx-2, winY+winH, 26, 2);
    }
  }

  // sign / neon
  if (style && style.sign) {
    const sigY = b.y - (style.awning ? 22 : 12);
    const sigW = style.sign.length * 8 + 12;
    const sigX = b.x + (b.w - sigW)/2;
    // back plate
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(sigX-2, sigY-2, sigW+4, 14);
    // neon glow at night
    if (isNight()) {
      ctx.save();
      ctx.shadowColor = style.neon;
      ctx.shadowBlur = 14;
      ctx.fillStyle = style.signColor;
      ctx.font = 'bold 11px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText(style.sign, b.x + b.w/2, sigY+9);
      ctx.shadowBlur = 0;
      ctx.restore();
    } else {
      ctx.fillStyle = style.signColor;
      ctx.font = 'bold 11px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText(style.sign, b.x + b.w/2, sigY+9);
    }
    ctx.textAlign = 'left';
  } else if (b.name && b.name !== '') {
    ctx.fillStyle = '#d4c896';
    ctx.font = 'bold 11px Courier New';
    ctx.fillText(b.name, b.x+8, b.y+10);
  }

  // church cross
  if (style && style.cross) {
    ctx.fillStyle = '#d488d4';
    ctx.fillRect(b.x + b.w/2 - 2, b.y - 18, 4, 14);
    ctx.fillRect(b.x + b.w/2 - 6, b.y - 14, 12, 4);
  }

  // boarded planks for locked building
  if (b.locked && P.rank < 4) {
    ctx.strokeStyle = '#5a3a1a';
    ctx.lineWidth = 4;
    for (let i=0;i<3;i++) {
      ctx.beginPath();
      ctx.moveTo(b.x+10, b.y+b.h/2 - 14 + i*14);
      ctx.lineTo(b.x+b.w-10, b.y+b.h/2 - 8 + i*14);
      ctx.stroke();
    }
    // nail heads
    ctx.fillStyle = '#3a2010';
    for (let i=0;i<3;i++) {
      ctx.fillRect(b.x+12, b.y+b.h/2 - 14 + i*14 - 1, 2, 2);
      ctx.fillRect(b.x+b.w-14, b.y+b.h/2 - 8 + i*14 - 1, 2, 2);
    }
    ctx.font = '16px monospace';
    ctx.fillText('🔒', b.x+b.w/2-8, b.y+b.h/2+6);
    ctx.font = '9px Courier New';
    ctx.fillStyle = '#8a3a3a';
    ctx.fillText('RANK 4+', b.x+b.w/2-22, b.y+b.h-8);
  }
  // door gap
  if (b.doorGap) {
    // door shadow
    ctx.fillStyle = '#0a0518';
    ctx.fillRect(b.x+b.w/2-25, b.y+b.h-8, 50, 12);
    // door frame light spill
    if (isNight()) {
      const g = ctx.createRadialGradient(b.x+b.w/2, b.y+b.h, 4, b.x+b.w/2, b.y+b.h, 60);
      g.addColorStop(0, 'rgba(232,192,64,.4)');
      g.addColorStop(1, 'rgba(232,192,64,0)');
      ctx.fillStyle = g;
      ctx.fillRect(b.x+b.w/2-60, b.y+b.h-4, 120, 70);
    }
  }
}

export function pickGraffitiLine(faction) {
  const pool = (faction === 'scrap') ? SCRAP_GRAFFITI_LINES
             : (faction === 'spiritual') ? SPIRITUAL_GRAFFITI_LINES
             : GRAFFITI_LINES;
  return pool[Math.floor(Math.random()*pool.length)];
}

export function buildGraffiti() {
  // if saved layout exists, just reuse it
  if (state.graffiti && state.graffiti.length) return;
  const out = [];
  const N = 12 + Math.floor(Math.random()*7); // 12-18
  // candidate walls: every BUILDING, both side and bottom faces (not roof, not under awnings).
  const walls = [];
  for (const b of BUILDINGS) {
    if (b.locked) continue; // skip the abandoned (boarded up — graffiti unreadable through planks)
    // bottom strip
    walls.push({ b, kind:'bottom' });
    // both side strips
    walls.push({ b, kind:'leftside' });
    walls.push({ b, kind:'rightside' });
  }
  for (let i=0;i<N;i++) {
    const wall = walls[Math.floor(Math.random()*walls.length)];
    const b = wall.b;
    // determine faction by where the building sits
    const zid = zoneAt(b.x + b.w/2, b.y + b.h/2);
    const z = ZONES.find(z=>z.id===zid);
    const faction = (z && z.faction) || 'street';
    const text = pickGraffitiLine(faction);
    const palette = GRAFFITI_PALETTES[faction] || GRAFFITI_PALETTES.street;
    let x, y;
    if (wall.kind === 'bottom') {
      x = b.x + 6 + Math.random()*(b.w-80);
      y = b.y + b.h - 8 - Math.random()*16;
    } else if (wall.kind === 'leftside') {
      x = b.x + 4;
      y = b.y + 24 + Math.random()*(b.h-50);
    } else {
      x = b.x + b.w - 70;
      y = b.y + 24 + Math.random()*(b.h-50);
    }
    out.push({
      x, y, text,
      col: palette[Math.floor(Math.random()*palette.length)],
      rot: ((Math.random()-.5) * 0.18), // -5° to +5° (radians ~0.087)
      sz: 8 + Math.floor(Math.random()*3), // 8-10 px
    });
  }
  state.graffiti = out;
}

export function drawGraffiti() {
  if (!state.graffiti || !state.graffiti.length) buildGraffiti();
  if (!state.graffiti) return;
  for (const g of state.graffiti) {
    if (!visibleWorldRect(g.x-80,g.y-18,170,28,16)) continue;
    ctx.save();
    ctx.translate(g.x, g.y);
    ctx.rotate(g.rot);
    ctx.font = 'bold '+(g.sz||9)+'px Courier New';
    ctx.fillStyle = g.col;
    ctx.globalAlpha = 0.65;
    ctx.fillText(g.text, 0, 0);
    // chalky double-pass for that spray-grit feel
    ctx.globalAlpha = 0.18;
    ctx.fillText(g.text, 0.5, 0.5);
    ctx.globalAlpha = 1;
    ctx.restore();
  }
}

export function buildPosters() {
  if (state.posters && state.posters.length) return;
  const out = [];
  // for each non-locked building, decide if it's in a faction zone, and if so place 1-3 posters
  // on its bottom/left/right wall faces.
  const perZoneCounts = {};
  for (const b of BUILDINGS) {
    if (b.locked) continue;
    const zid = zoneAt(b.x + b.w/2, b.y + b.h/2);
    const z = ZONES.find(z=>z.id===zid);
    if (!z || !z.faction || z.faction === 'neutral') continue;
    const k = z.id;
    perZoneCounts[k] = perZoneCounts[k] || 0;
    if (perZoneCounts[k] >= 3) continue;
    // probability scaled so each zone usually gets 1-3 posters across its buildings
    if (Math.random() > 0.55) continue;
    perZoneCounts[k]++;
    const faction = z.faction;
    const text = POSTER_LINES[faction][Math.floor(Math.random()*POSTER_LINES[faction].length)];
    const wallPick = Math.floor(Math.random()*3); // 0 bottom, 1 left, 2 right
    let x, y;
    if (wallPick === 0)      { x = b.x + 12 + Math.random()*(b.w-48); y = b.y + b.h - 30; }
    else if (wallPick === 1) { x = b.x + 4;                            y = b.y + 30 + Math.random()*(b.h-60); }
    else                     { x = b.x + b.w - 20;                     y = b.y + 30 + Math.random()*(b.h-60); }
    out.push({ x, y, w:16, h:24, faction, text });
  }
  state.posters = out;
}

export function drawPosters() {
  if (!state.posters || !state.posters.length) buildPosters();
  if (!state.posters) return;
  for (const p of state.posters) {
    if (!visibleWorldRect(p.x,p.y,p.w,p.h,12)) continue;
    const skin = POSTER_BG[p.faction] || POSTER_BG.street;
    // paper
    ctx.fillStyle = skin.bg;
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // torn-edge / nail accents
    ctx.fillStyle = 'rgba(0,0,0,.45)';
    ctx.fillRect(p.x, p.y, p.w, 1);
    ctx.fillRect(p.x, p.y+p.h-1, p.w, 1);
    // text
    ctx.fillStyle = skin.fg;
    ctx.font = 'bold 4px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) {
      ctx.fillText(lines[i], p.x+2, p.y+5 + i*4);
    }
  }
}

export function drawBorderGlow() {
  if (!state.borderGlowT || state.borderGlowT <= 0 || !state.borderGlowRect) return;
  const r = state.borderGlowRect;
  const alpha = Math.min(0.55, state.borderGlowT / 600 * 0.55);
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.strokeStyle = state.borderGlowColor || '#888';
  ctx.lineWidth = 3;
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  ctx.restore();
}

export function drawHideoutDoors() {
  for (const kind of ['scrap', 'mom']) {
    if (!hideoutOwned(kind)) continue;
    const d = HIDEOUT_DOORS[kind];
    const sx = d.x, sy = d.y;
    if (!visibleWorldRect(sx,sy,d.w,d.h,60)) continue;
    // door
    ctx.fillStyle = kind === 'mom' ? '#6a4a30' : '#4a3a28';
    ctx.fillRect(sx, sy, d.w, d.h);
    // panel
    ctx.fillStyle = kind === 'mom' ? '#8a6440' : '#5a4830';
    ctx.fillRect(sx+3, sy+4, d.w-6, d.h-8);
    // knob
    ctx.fillStyle = '#c8a060';
    ctx.fillRect(sx + d.w - 7, sy + d.h/2 - 1, 2, 2);
    // "(E)" hint if player close
    const ddx = (P.x+P.w/2) - (d.x+d.w/2), ddy = (P.y+P.h/2) - (d.y+d.h/2);
    if (ddx*ddx + ddy*ddy < 60*60) {
      ctx.fillStyle = 'rgba(0,0,0,.8)';
      ctx.fillRect(sx + d.w/2 - 10, sy - 14, 20, 12);
      ctx.fillStyle = '#e8c040';
      ctx.font = 'bold 10px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E)', sx + d.w/2, sy - 5);
      ctx.textAlign = 'left';
    }
  }
}

export function drawOfficeExterior(){
  const d=OFFICE_DOOR;if(!visibleWorldRect(4660,2860,520,390,40))return;
  const o=state.office||freshOfficeState(),owned=!!o.owned,claims=claimedDistrictIds().length,u=o.upgrades||{};
  // Door and lock. The building shell itself is canonical BUILDINGS geometry.
  ctx.fillStyle=owned?'#5a4028':'#2a211b';ctx.fillRect(d.x,d.y,d.w,d.h);
  ctx.fillStyle=owned?'#8a6840':'#3a3028';ctx.fillRect(d.x+3,d.y+4,d.w-6,d.h-8);
  ctx.fillStyle=owned?'#e8c040':'#77665a';ctx.fillRect(d.x+d.w-7,d.y+d.h/2,2,2);
  if(!owned){ctx.fillStyle='#0a0805';ctx.fillRect(d.x+8,d.y+13,8,8);ctx.fillStyle='#604020';ctx.fillRect(d.x+10,d.y+15,4,4);}
  // Sign grows from an old TAX HELP plate into a regional administrative mistake.
  const sign=claims>=11?'PAPER AUTHORITY':claims>=4?'REGIONAL OFFICE':owned?'THE OFFICE':'TAX HELP · NO TAX HELP';
  const sw=Math.max(150,sign.length*8+20),sx=4920-sw/2,sy=2890;
  ctx.fillStyle='#0a0805';ctx.fillRect(sx,sy,sw,22);ctx.strokeStyle=owned?'#e8c040':'#5a4838';ctx.strokeRect(sx+.5,sy+.5,sw-1,21);
  ctx.fillStyle=owned?'#d4c896':'#8a7868';ctx.font='bold 11px Courier New';ctx.textAlign='center';ctx.fillText(sign,4920,2905);ctx.textAlign='left';
  if(u.route_board){ctx.fillStyle='#d4c896';ctx.fillRect(5146,3128,28,34);ctx.fillStyle='#5a4028';ctx.fillRect(5152,3136,16,2);ctx.fillRect(5152,3143,16,2);ctx.fillRect(5152,3150,12,2);}
  if(u.locker){ctx.fillStyle='#384038';ctx.fillRect(4670,3130,30,46);ctx.strokeStyle='#171a17';ctx.strokeRect(4670.5,3130.5,29,45);ctx.fillStyle='#c08038';ctx.fillRect(4692,3152,3,3);}
  if(u.cot){ctx.fillStyle='#6a5840';ctx.fillRect(4652,3207,56,8);ctx.fillStyle='#29231c';ctx.fillRect(4656,3215,4,10);ctx.fillRect(4700,3215,4,10);}
  if(u.generator){ctx.fillStyle='#3a382f';ctx.fillRect(5160,3172,48,34);ctx.fillStyle='#c08038';ctx.fillRect(5168,3180,10,10);ctx.strokeStyle='#8a3a3a';ctx.beginPath();ctx.moveTo(5160,3188);ctx.lineTo(5122,3192);ctx.stroke();}
  if(u.radio){ctx.strokeStyle='#8a7868';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(5080,2920);ctx.lineTo(5102,2842);ctx.lineTo(5120,2920);ctx.stroke();ctx.fillStyle='#d06030';ctx.fillRect(5099,2838,6,6);}
  if(u.desk){ctx.fillStyle='rgba(212,200,150,.72)';for(let i=0;i<Math.min(6,1+claims);i++)ctx.fillRect(4750+i*12,2918-(i%2)*3,9,5);}
  if(claims>=1){ctx.fillStyle='#5a4830';ctx.fillRect(4720,3230,30,18);ctx.fillStyle='#d4c896';ctx.fillRect(4724,3233,22,4);}
  if(claims>=8){ctx.fillStyle='#8a3a3a';ctx.fillRect(4680,2876,480,6);ctx.fillStyle='#c08038';for(let x=4688;x<5150;x+=28)ctx.fillRect(x,2876,14,6);}
  const dx=(P.x+P.w/2)-(d.x+d.w/2),dy=(P.y+P.h/2)-(d.y+d.h/2);
  if(dx*dx+dy*dy<64*64){ctx.fillStyle='rgba(0,0,0,.82)';ctx.fillRect(4908,3186,24,13);ctx.fillStyle='#e8c040';ctx.font='bold 10px Courier New';ctx.textAlign='center';ctx.fillText('(E)',4920,3196);ctx.textAlign='left';}
}

export function drawClaimSites(){
  const sp=ENV_SPRITE_CACHE.claim_sign;if(!sp)return;
  for(const def of CLAIM_SITES){
    if(!(state.districtClaims&&state.districtClaims[def.id]))continue;
    const p=def.sign;if(!visibleWorldRect(p.x-20,p.y-34,40,44,20))continue;
    ctx.drawImage(sp,Math.round(p.x-16),Math.round(p.y-30),32,32);
    if(Math.hypot((P.x+P.w/2)-p.x,(P.y+P.h/2)-p.y)<100){
      ctx.fillStyle='rgba(0,0,0,.72)';ctx.fillRect(p.x-38,p.y-42,76,10);ctx.fillStyle='#d4c896';ctx.font='bold 7px Courier New';ctx.textAlign='center';ctx.fillText('THE OFFICE CLAIMS',p.x,p.y-34);ctx.textAlign='left';
    }
  }
}

export function init_structures() {
  // ---------- v10 building style + drawBuilding ----------
  BUILDING_STYLE = {
    PAWN:        { awning:'#a08030', sign:'PAWN',        signColor:'#e8c040', neon:'#fff080' },
    CORNER:      { awning:'#7a2018', sign:"TONY'S",      signColor:'#d06030', neon:'#ff6020' },
    CHURCH:      { awning:'#3a2840', sign:'',            signColor:'#d488d4', neon:'#d488d4', cross:true },
    LAUNDROMAT:  { awning:'#4858a0', sign:'WASH·DRY',   signColor:'#88c0ff', neon:'#a0d0ff' },
  };
  
  
  
  // v13 wave 6 — Procedural graffiti — placed once per save and persisted via state.graffiti.
  // v13 wave 8b — faction-themed: each building's tag is pulled from the pool matching the
  // zone the building sits in (street default = GRAFFITI_LINES, scrap = SCRAP_GRAFFITI_LINES,
  // spiritual = SPIRITUAL_GRAFFITI_LINES). Tag color is also faction-tinted.
  GRAFFITI_PALETTES = {
    street:    ['#a06868','#b8706e','#a87a80','#c08070'],   // muted red / pink chalk
    scrap:     ['#c08038','#a87038','#d09048','#a86028'],   // rust orange / metallic
    spiritual: ['#8898b8','#a8b0c8','#c0c0c0','#d0d8e0'],   // faded blue / chalk white
    neutral:   ['#a89878','#88a070','#a08070'],             // grey-green chalk
  };
  
  
  
  
  // v13 wave 8b — wall-mounted posters. 1-3 per faction-tagged zone, procedural per save.
  // Persisted in state.posters. Drawn between graffiti and props so they appear on walls,
  // below any prop overlays. Each poster has {x,y,w,h,faction,text,col,bg}.
  POSTER_LINES = {
    street: [
      "MISSING DOG\n(REWARD)",
      "WANTED\nLOOKS JUST\nLIKE YOU",
      "DJ DANGER\nPRESENTS\nA DJ NIGHT",
    ],
    scrap: [
      "CASH FOR\nCOPPER",
      "ASK ABOUT\nTHE PRICE",
      "PETE'S PAWN\nOPEN ALWAYS",
    ],
    spiritual: [
      "REPENT",
      "PRAYER MEETING\nTHURSDAYS",
      "THE CHURCH IS\nA BUILDING.\nTHE BUILDING\nIS A CHURCH.",
    ],
  };
  POSTER_BG = {
    street:    { bg:'#3a1818', fg:'#f0d8b0' },
    scrap:     { bg:'#2a1f10', fg:'#e8c878' },
    spiritual: { bg:'#1f1820', fg:'#d8d0e8' },
  };
  
  
  
  // v13 wave 8b — short border-glow flash on zone-faction crossings. timer is set in updateWorld,
  // rendered post-world (screen-space, but tinted in world-space rect).
  
  
  // v13 wave 7 — small wooden-door decal at each owned hideout. drawn in world space.
  
  
  
  
  
  
}
