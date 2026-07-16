/* Generated from frozen rock_bottom_v19.html.
 * Source seams: prop and interactive-prop rendering.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, state } from '../core/runtime_ui.js';
import { isNight } from '../data/npc_spawns.js';
import { PROPS, interactiveProps } from '../data/props.js';
import { ctx, visibleWorldRect } from './canvas_geography.js';

export function drawProps() {
  for (const p of PROPS) {
    // Full-bounds culling keeps long freight cars / fences visible when their anchor leaves screen.
    const pw=p.w||64, ph=p.h||64;
    if (!visibleWorldRect(p.x-32,p.y-64,pw+64,ph+96,16)) continue;
    drawProp(p);
  }
  // v13 wave 6 — interactive props pass (parallel array)
  for (const ip of interactiveProps) {
    if (!visibleWorldRect(ip.x-20,ip.y-20,40,40,16)) continue;
    drawInteractiveProp(ip);
  }
}

export function drawProp(p) {
  if (p.type === 'dumpster') {
    ctx.fillStyle = p.looted ? '#1a1810' : p.color;
    ctx.fillRect(p.x, p.y, p.w, p.h);
    ctx.strokeStyle = '#0a0805'; ctx.lineWidth = 2;
    ctx.strokeRect(p.x, p.y, p.w, p.h);
    // lid
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x-2, p.y-4, p.w+4, 4);
    // flies
    if (!p.looted) {
      ctx.fillStyle = '#222';
      const t = performance.now()/200;
      for (let i=0;i<3;i++) {
        const fx = p.x + 6 + Math.sin(t+i*2)*8;
        const fy = p.y - 10 + Math.cos(t*1.3+i)*4;
        ctx.fillRect(fx, fy, 2, 2);
      }
    }
    // label
    ctx.font = '8px Courier New';
    ctx.fillStyle = '#665';
    ctx.fillText('TRASH', p.x+2, p.y+14);
  }
  else if (p.type === 'cart') {
    if (p.mounted) return; // mounted on player
    ctx.fillStyle = '#888';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // grid pattern
    ctx.strokeStyle = '#444'; ctx.lineWidth = 1;
    for (let i=4; i<p.w; i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x+i, p.y); ctx.lineTo(p.x+i, p.y+p.h); ctx.stroke();
    }
    // handle
    ctx.fillStyle = '#666';
    ctx.fillRect(p.x-2, p.y-6, 28, 3);
    // wheels
    ctx.fillStyle = '#000';
    ctx.fillRect(p.x+2, p.y+p.h, 4, 4);
    ctx.fillRect(p.x+p.w-6, p.y+p.h, 4, 4);
    // glint
    ctx.fillStyle = '#ccc';
    ctx.fillRect(p.x+2, p.y+2, 2, 2);
  }
  else if (p.type === 'cart_husk') {
    // v19 cart cavalry scenery. Deliberately not rideable and never selected by cart interaction.
    ctx.save();
    ctx.translate(p.x+p.w/2,p.y+p.h/2);ctx.rotate(((p.x+p.y)%2?1:-1)*0.12);
    ctx.strokeStyle='#6f6a5a';ctx.lineWidth=2;ctx.strokeRect(-p.w/2,-p.h/2,p.w,p.h);
    ctx.strokeStyle='#3a372f';ctx.lineWidth=1;
    for(let i=-p.w/2+4;i<p.w/2;i+=5){ctx.beginPath();ctx.moveTo(i,-p.h/2);ctx.lineTo(i,p.h/2);ctx.stroke();}
    ctx.fillStyle='#111';ctx.fillRect(-p.w/2+1,p.h/2,4,3);ctx.fillRect(p.w/2-5,p.h/2,4,3);
    ctx.fillStyle='#8a3a3a';ctx.fillRect(-p.w/2-4,-p.h/2-3,p.w+4,2);
    ctx.restore();
  }
  else if (p.type === 'lamp') {
    // post
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y-30, 3, 30);
    // head
    ctx.fillStyle = '#5a4828';
    ctx.fillRect(p.x-5, p.y-36, 11, 8);
    // bulb glow during night (rendered in lighting pass)
    if (isNight()) {
      ctx.fillStyle = '#fff0a0';
      ctx.fillRect(p.x-2, p.y-32, 5, 4);
    }
  }
  else if (p.type === 'hydrant') {
    ctx.fillStyle = '#8a3a3a';
    ctx.fillRect(p.x-4, p.y-10, 8, 12);
    ctx.fillStyle = '#a04848';
    ctx.fillRect(p.x-6, p.y-12, 12, 4);
    ctx.fillStyle = '#5a2020';
    ctx.fillRect(p.x-6, p.y-2, 12, 4);
  }
  else if (p.type === 'mailbox') {
    ctx.fillStyle = '#1818a0';
    ctx.fillRect(p.x-6, p.y-12, 12, 12);
    ctx.fillStyle = '#0a0a60';
    ctx.fillRect(p.x-1, p.y, 2, 6);
  }
  else if (p.type === 'cone') {
    ctx.fillStyle = '#d06030';
    ctx.beginPath();
    ctx.moveTo(p.x, p.y-12);
    ctx.lineTo(p.x-5, p.y);
    ctx.lineTo(p.x+5, p.y);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#fff0a0';
    ctx.fillRect(p.x-3, p.y-7, 6, 2);
  }
  else if (p.type === 'trash') {
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-6, p.y-4, 12, 8);
    ctx.fillStyle = '#5a4030';
    ctx.fillRect(p.x-2, p.y-6, 4, 4);
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x+2, p.y-2, 2, 2);
  }
  else if (p.type === 'crate') {
    ctx.fillStyle = '#604020';
    ctx.fillRect(p.x, p.y, 24, 16);
    ctx.strokeStyle = '#3a2010';
    ctx.lineWidth = 1;
    for (let i=4;i<24;i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x+i, p.y); ctx.lineTo(p.x+i, p.y+16); ctx.stroke();
    }
    for (let i=4;i<16;i+=4) {
      ctx.beginPath(); ctx.moveTo(p.x, p.y+i); ctx.lineTo(p.x+24, p.y+i); ctx.stroke();
    }
  }
  else if (p.type === 'syringe') {
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x-3, p.y, 7, 2);
    ctx.fillStyle = '#a08868';
    ctx.fillRect(p.x+4, p.y, 3, 2);
  }
  else if (p.type === 'bottle') {
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(p.x-3, p.y-2, 4, 6);
    ctx.fillStyle = '#5a7038';
    ctx.fillRect(p.x+1, p.y+1, 3, 2);
    ctx.fillStyle = '#a8c030';
    ctx.fillRect(p.x-4, p.y+4, 8, 1);
  }
  // v13 wave 6 — tent (makeshift, varied palette)
  else if (p.type === 'tent') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.35)';
    ctx.fillRect(p.x-2, p.y+14, 28, 4);
    // triangular tarp
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y-6);
    ctx.lineTo(p.x-2, p.y+16);
    ctx.lineTo(p.x+26, p.y+16);
    ctx.closePath();
    ctx.fill();
    // dark seam down center
    ctx.strokeStyle = 'rgba(0,0,0,.5)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y-6); ctx.lineTo(p.x+12, p.y+16);
    ctx.stroke();
    // patches / duct tape
    ctx.fillStyle = '#d4c896';
    ctx.fillRect(p.x+4, p.y+6, 5, 2);
    ctx.fillStyle = '#a08050';
    ctx.fillRect(p.x+18, p.y+10, 4, 2);
    // dark interior triangle (opening)
    ctx.fillStyle = '#0a0805';
    ctx.beginPath();
    ctx.moveTo(p.x+12, p.y+4);
    ctx.lineTo(p.x+6, p.y+16);
    ctx.lineTo(p.x+18, p.y+16);
    ctx.closePath();
    ctx.fill();
  }
  // v13 wave 6 — cardboard sign (held / propped, hand-scrawled marker text)
  else if (p.type === 'cardsign') {
    ctx.fillStyle = '#a08050';
    ctx.fillRect(p.x, p.y, 36, 22);
    // creases / cardboard texture
    ctx.fillStyle = '#604028';
    ctx.fillRect(p.x, p.y+10, 36, 1);
    ctx.fillRect(p.x+18, p.y, 1, 22);
    // text — scrawled black marker
    ctx.fillStyle = '#0a0805';
    ctx.font = 'bold 5px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x+2, p.y+6 + i*6);
  }
  // v13 wave 6 — scrap pile (twisted metal)
  else if (p.type === 'scrap_pile') {
    ctx.fillStyle = p.color || '#604020';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // top-edge glints
    ctx.fillStyle = '#a08040';
    ctx.fillRect(p.x+2, p.y+1, 4, 2);
    ctx.fillRect(p.x+p.w-8, p.y+2, 5, 2);
    // rebar sticks
    ctx.strokeStyle = '#a08060';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(p.x+4, p.y); ctx.lineTo(p.x+8, p.y-8);
    ctx.moveTo(p.x+p.w-6, p.y); ctx.lineTo(p.x+p.w-2, p.y-10);
    ctx.stroke();
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x+2, p.y+p.h, p.w-4, 3);
  }
  // v13 wave 6 — car wreck (totaled sedan, on blocks)
  else if (p.type === 'car_wreck') {
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.5)';
    ctx.fillRect(p.x, p.y+p.h, p.w, 4);
    // body
    ctx.fillStyle = p.color || '#5a3030';
    ctx.fillRect(p.x, p.y+6, p.w, p.h-10);
    // roof / cabin
    ctx.fillStyle = '#3a2020';
    ctx.fillRect(p.x+10, p.y, p.w-20, 10);
    // windows (smashed)
    ctx.fillStyle = '#181818';
    ctx.fillRect(p.x+12, p.y+2, p.w/2-14, 6);
    ctx.fillRect(p.x+p.w/2+2, p.y+2, p.w/2-14, 6);
    // missing wheels — sit on cinderblocks
    ctx.fillStyle = '#3a3a3a';
    ctx.fillRect(p.x+4, p.y+p.h-4, 6, 4);
    ctx.fillRect(p.x+p.w-10, p.y+p.h-4, 6, 4);
    // rust streaks
    ctx.fillStyle = 'rgba(140,60,20,.5)';
    ctx.fillRect(p.x+2, p.y+p.h/2, 1, p.h/2-4);
    ctx.fillRect(p.x+p.w-4, p.y+p.h/2, 1, p.h/2-4);
    // door dent
    ctx.fillStyle = 'rgba(0,0,0,.45)';
    ctx.fillRect(p.x+p.w/2-6, p.y+p.h/2, 12, 4);
  }
  // v13 wave 6 — leash post (dog is chained to this; rendered as small wooden post)
  else if (p.type === 'leash_post') {
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-2, p.y-10, 4, 12);
    ctx.fillStyle = '#604028';
    ctx.fillRect(p.x-3, p.y-12, 6, 3);
    // chain link nub
    ctx.fillStyle = '#888';
    ctx.fillRect(p.x-1, p.y-8, 2, 2);
  }
  // v13 wave 8a — TRAIN YARD: freight car (decorative, non-solid silhouette)
  else if (p.type === 'freight_car') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.55)';
    ctx.fillRect(p.x+4, p.y+p.h, p.w-8, 6);
    // body
    ctx.fillStyle = p.color || '#5a2a20';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // dark roof band
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x, p.y, p.w, 6);
    // rust streaks
    ctx.fillStyle = 'rgba(140,60,20,.45)';
    for (let i=14; i<p.w; i+=24) {
      ctx.fillRect(p.x+i, p.y+8, 1, p.h-14);
    }
    // sliding door outline (center)
    const doorW = 48;
    const doorX = p.x + p.w/2 - doorW/2;
    ctx.strokeStyle = 'rgba(0,0,0,.55)';
    ctx.lineWidth = 2;
    ctx.strokeRect(doorX, p.y+8, doorW, p.h-14);
    // dark "inside" through the door gap (where the hopper sleeps)
    ctx.fillStyle = '#080605';
    ctx.fillRect(doorX+3, p.y+11, doorW-6, p.h-20);
    // wheel trucks (small black blocks below)
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x+14,       p.y+p.h-2, 18, 5);
    ctx.fillRect(p.x+p.w-32,   p.y+p.h-2, 18, 5);
    // a faded paint stencil "RAILROAD" partial
    ctx.fillStyle = 'rgba(220,210,180,.18)';
    ctx.font = 'bold 7px Courier New';
    ctx.fillText('RA  ROAD', p.x+12, p.y+22);
  }
  // v13 wave 8a — TRAIN YARD: chalk message on a freight car side
  else if (p.type === 'chalk_message') {
    ctx.fillStyle = 'rgba(220,210,180,.72)';
    ctx.font = '7px Courier New';
    const lines = (p.text || '').split('\n');
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x, p.y + i*8);
    // smudge ghosting
    ctx.fillStyle = 'rgba(220,210,180,.22)';
    for (let i=0;i<lines.length;i++) ctx.fillText(lines[i], p.x+1, p.y+1 + i*8);
  }
  // v13 wave 8a — generic tall-weeds clump (park / train yard / old school)
  else if (p.type === 'weeds') {
    ctx.fillStyle = '#2a3818';
    ctx.fillRect(p.x-3, p.y, 1, 6);
    ctx.fillRect(p.x, p.y-2, 1, 8);
    ctx.fillRect(p.x+3, p.y-1, 1, 7);
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(p.x-2, p.y-3, 1, 3);
    ctx.fillRect(p.x+1, p.y-4, 1, 3);
    ctx.fillRect(p.x+4, p.y-3, 1, 2);
    // small base shadow
    ctx.fillStyle = 'rgba(0,0,0,.3)';
    ctx.fillRect(p.x-3, p.y+6, 8, 1);
  }
  // v13 wave 8a — THE PARK: stone fountain
  else if (p.type === 'fountain') {
    // base (octagonal-ish)
    ctx.fillStyle = '#6a655a';
    ctx.fillRect(p.x-20, p.y-4, 40, 18);
    ctx.fillStyle = '#5a554a';
    ctx.fillRect(p.x-22, p.y+10, 44, 4);
    // water in the basin
    const t = (Math.sin(performance.now()/600)+1)/2;
    ctx.fillStyle = `rgba(100,150,200,${0.45+t*0.18})`;
    ctx.fillRect(p.x-16, p.y, 32, 10);
    // center stem
    ctx.fillStyle = '#7a7568';
    ctx.fillRect(p.x-3, p.y-16, 6, 16);
    // upper bowl
    ctx.fillStyle = '#8a8578';
    ctx.fillRect(p.x-7, p.y-20, 14, 6);
    // a thin "spout" sparkle
    ctx.fillStyle = `rgba(200,220,240,${0.55+t*0.3})`;
    ctx.fillRect(p.x-1, p.y-22, 2, 4);
    // little base shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x-22, p.y+14, 44, 3);
  }
  // v13 wave 8a — THE PARK: bench (wood slats + iron frame)
  else if (p.type === 'park_bench') {
    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,.35)';
    ctx.fillRect(p.x+2, p.y+p.h, p.w-4, 3);
    // back rest
    ctx.fillStyle = '#5a4028';
    ctx.fillRect(p.x, p.y-8, p.w, 3);
    // seat
    ctx.fillStyle = '#6a4828';
    ctx.fillRect(p.x, p.y, p.w, p.h);
    // slat gaps
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x, p.y+3, p.w, 1);
    ctx.fillRect(p.x, p.y+7, p.w, 1);
    // iron legs
    ctx.fillStyle = '#2a2520';
    ctx.fillRect(p.x+1,       p.y, 2, p.h+4);
    ctx.fillRect(p.x+p.w-3,   p.y, 2, p.h+4);
    // (E) hint when close
    const ddx = (P.x+P.w/2) - (p.x+p.w/2), ddy = (P.y+P.h/2) - (p.y+p.h/2);
    if (ddx*ddx + ddy*ddy < 50*50 && !state.sittingOnBench) {
      ctx.fillStyle = '#e8c040';
      ctx.font = '8px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E) sit', p.x+p.w/2, p.y-14);
      ctx.textAlign = 'left';
    }
  }
  // v13 wave 8a — THE PARK / OLD SCHOOL: swing set silhouette
  else if (p.type === 'swing_set') {
    // night red tint flag (drawn after) — but base is universal
    // frame uprights
    ctx.fillStyle = '#3a3a44';
    ctx.fillRect(p.x,    p.y-26, 3, 28);
    ctx.fillRect(p.x+60, p.y-26, 3, 28);
    // crossbar
    ctx.fillRect(p.x, p.y-26, 64, 3);
    // chains + seats (two swings)
    ctx.strokeStyle = '#888';
    ctx.lineWidth = 1;
    ctx.beginPath();
    // gentle sway
    const s = Math.sin(performance.now()/1100)*1.5;
    ctx.moveTo(p.x+14+s,   p.y-23); ctx.lineTo(p.x+14+s,   p.y-8);
    ctx.moveTo(p.x+24+s,   p.y-23); ctx.lineTo(p.x+24+s,   p.y-8);
    ctx.moveTo(p.x+40-s,   p.y-23); ctx.lineTo(p.x+40-s,   p.y-8);
    ctx.moveTo(p.x+50-s,   p.y-23); ctx.lineTo(p.x+50-s,   p.y-8);
    ctx.stroke();
    // wooden seats
    ctx.fillStyle = '#5a3818';
    ctx.fillRect(p.x+12+s, p.y-8, 14, 2);
    ctx.fillRect(p.x+38-s, p.y-8, 14, 2);
    // night-only creepy red tint OR park-night tint (the park swings get it specifically)
    if (isNight()) {
      ctx.fillStyle = 'rgba(180,40,40,.18)';
      ctx.fillRect(p.x-2, p.y-30, 68, 36);
    }
  }
  // v13 wave 8a — THE PARK: drinking fountain (broken / dribbling)
  else if (p.type === 'drink_fountain') {
    ctx.fillStyle = '#5a554a';
    ctx.fillRect(p.x-5, p.y, 10, 12);
    ctx.fillStyle = '#6a655a';
    ctx.fillRect(p.x-7, p.y-2, 14, 4);
    // pipe nozzle
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y-5, 2, 4);
    // rust drip
    ctx.fillStyle = 'rgba(140,60,20,.6)';
    ctx.fillRect(p.x-1, p.y+2, 2, 6);
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.3)';
    ctx.fillRect(p.x-6, p.y+12, 12, 2);
  }
  // v13 wave 8a — THE PARK: tree (trunk + dark green canopy)
  else if (p.type === 'tree') {
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y+18, 14, 4, 0, 0, Math.PI*2);
    ctx.fill();
    // trunk
    ctx.fillStyle = '#3a2818';
    ctx.fillRect(p.x-3, p.y, 6, 18);
    // canopy (layered)
    ctx.fillStyle = '#1f3a18';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y-12, 18, 16, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = '#2a4a20';
    ctx.beginPath();
    ctx.ellipse(p.x-2, p.y-14, 14, 12, 0, 0, Math.PI*2);
    ctx.fill();
    // highlight
    ctx.fillStyle = '#3a5a28';
    ctx.fillRect(p.x-6, p.y-20, 4, 3);
  }
  // v13 wave 8a — OLD SCHOOL: mural (faded letters, scraped)
  else if (p.type === 'school_mural') {
    ctx.fillStyle = 'rgba(40,30,20,.55)';
    ctx.fillRect(p.x-4, p.y-4, 200, 22);
    ctx.fillStyle = 'rgba(220,200,150,.45)';
    ctx.font = 'bold 11px Courier New';
    ctx.fillText(p.text || '', p.x, p.y+8);
    // scrape marks
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x+30, p.y, 4, 14);
    ctx.fillRect(p.x+80, p.y+2, 6, 12);
    ctx.fillRect(p.x+130, p.y+1, 3, 13);
  }
  // v13 wave 8a — OLD SCHOOL: broken basketball hoop
  else if (p.type === 'broken_hoop') {
    // pole
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y, 3, 40);
    // backboard
    ctx.fillStyle = '#a08868';
    ctx.fillRect(p.x-10, p.y-22, 24, 16);
    ctx.fillStyle = '#604030';
    ctx.fillRect(p.x-10, p.y-22, 24, 1);
    ctx.fillRect(p.x-10, p.y-7,  24, 1);
    // rim (bent down)
    ctx.strokeStyle = '#c08038';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(p.x+2, p.y-8, 6, 0, Math.PI);
    ctx.stroke();
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(p.x-3, p.y+40, 6, 2);
  }
  // v13 wave 8a — OLD SCHOOL: chain-link fence (drawn as a thin horizontal band of "X" patterns)
  else if (p.type === 'school_fence') {
    ctx.strokeStyle = 'rgba(140,140,140,.6)';
    ctx.lineWidth = 1;
    for (let fx=0; fx<p.w; fx+=8) {
      ctx.beginPath();
      ctx.moveTo(p.x+fx,     p.y);
      ctx.lineTo(p.x+fx+8,   p.y+p.h);
      ctx.moveTo(p.x+fx+8,   p.y);
      ctx.lineTo(p.x+fx,     p.y+p.h);
      ctx.stroke();
    }
    // top + bottom rails
    ctx.fillStyle = '#666';
    ctx.fillRect(p.x, p.y, p.w, 1);
    ctx.fillRect(p.x, p.y+p.h-1, p.w, 1);
  }
  // v13 wave 8a — OLD SCHOOL: broken window (small dark rect on building face)
  else if (p.type === 'broken_window') {
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x, p.y, 14, 10);
    // jagged glass shards still in frame
    ctx.fillStyle = 'rgba(180,200,220,.45)';
    ctx.beginPath();
    ctx.moveTo(p.x,    p.y);
    ctx.lineTo(p.x+3,  p.y+5);
    ctx.lineTo(p.x,    p.y+10);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(p.x+14, p.y);
    ctx.lineTo(p.x+10, p.y+4);
    ctx.lineTo(p.x+14, p.y+10);
    ctx.closePath();
    ctx.fill();
  }
  // v13 wave 6 — pay phone (rings randomly; can answer with E)
  else if (p.type === 'pay_phone') {
    const ringing = state.phonePropRingT > 0;
    const sway = ringing ? Math.sin(performance.now()/40)*1.5 : 0;
    // pole
    ctx.fillStyle = '#3a3528';
    ctx.fillRect(p.x-1, p.y, 3, 24);
    // box
    ctx.fillStyle = '#2a3a5a';
    ctx.fillRect(p.x-10 + sway, p.y-22, 20, 26);
    // dial / receiver outline
    ctx.fillStyle = '#181818';
    ctx.fillRect(p.x-7 + sway, p.y-20, 14, 6);
    // coin slot
    ctx.fillStyle = '#88a0c0';
    ctx.fillRect(p.x-3 + sway, p.y-12, 6, 1);
    // receiver
    ctx.fillStyle = '#0a0805';
    ctx.fillRect(p.x-8 + sway, p.y-8, 4, 8);
    // rust accents
    ctx.fillStyle = 'rgba(140,60,20,.55)';
    ctx.fillRect(p.x-10 + sway, p.y-2, 4, 2);
    ctx.fillRect(p.x+6 + sway, p.y-16, 4, 2);
    // ring indicator: "?" floater above
    if (ringing) {
      const t = (Math.sin(performance.now()/120)+1)/2;
      ctx.fillStyle = '#e8c040';
      ctx.font = 'bold 14px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('?', p.x + sway, p.y - 32 - t*4);
      ctx.textAlign = 'left';
      // sound-wave rings
      ctx.strokeStyle = `rgba(232,192,64,${0.4 + t*0.4})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(p.x, p.y-12, 16 + t*6, 0, Math.PI*2);
      ctx.stroke();
    }
  }
}

export function drawInteractiveProp(p) {
  if (p.type === 'trashcan') {
    const rot = p.tipT > 0 ? Math.sin(p.tipT/30)*0.4 : 0;
    const scale = p.rotPulse > 0 ? 1.0 + (p.rotPulse/200)*0.2 : 1.0;
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(rot);
    ctx.scale(scale, scale);
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(-12, 14, 24, 4);
    // body (silver dented)
    ctx.fillStyle = '#5a5a5a';
    ctx.fillRect(-10, -16, 20, 30);
    // dents (vertical creases)
    ctx.fillStyle = '#3a3a3a';
    ctx.fillRect(-8, -14, 1, 26);
    ctx.fillRect(0, -14, 1, 26);
    ctx.fillRect(6, -14, 1, 26);
    // rim
    ctx.fillStyle = '#888';
    ctx.fillRect(-12, -18, 24, 4);
    // contents (when not on cooldown)
    if (p.cdT <= 0) {
      ctx.fillStyle = '#3a2818';
      ctx.fillRect(-8, -16, 16, 4);
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(-6, -16, 3, 2);
    }
    // empty marker
    if (p.cdT > 0) {
      ctx.fillStyle = 'rgba(0,0,0,.6)';
      ctx.fillRect(-10, -16, 20, 4);
    }
    ctx.restore();
    // tiny "(E)" hint floater when player is close
    const dx = (P.x+P.w/2) - p.x, dy = (P.y+P.h/2) - p.y;
    if (dx*dx + dy*dy < 50*50 && p.cdT <= 0) {
      ctx.fillStyle = '#e8c040';
      ctx.font = '8px Courier New';
      ctx.textAlign = 'center';
      ctx.fillText('(E) kick', p.x, p.y - 22);
      ctx.textAlign = 'left';
    }
  } else if (p.type === 'b_bottle') {
    if (p.broken) {
      // glass shards on ground
      ctx.fillStyle = 'rgba(180,200,220,.6)';
      ctx.fillRect(p.x-3, p.y, 2, 1);
      ctx.fillRect(p.x+1, p.y+1, 2, 1);
      ctx.fillRect(p.x-1, p.y-1, 1, 1);
    } else {
      // upright bottle — green
      ctx.fillStyle = '#3a6028';
      ctx.fillRect(p.x-2, p.y-7, 4, 9);
      ctx.fillStyle = '#5a8038';
      ctx.fillRect(p.x-2, p.y-7, 1, 9);
      // neck
      ctx.fillStyle = '#3a6028';
      ctx.fillRect(p.x-1, p.y-10, 2, 3);
      // cap
      ctx.fillStyle = '#888';
      ctx.fillRect(p.x-1, p.y-11, 2, 1);
    }
  }
}

export function init_render_props() {
  
  
  
  
  // v13 wave 6 — interactive prop render dispatcher (kickable trash, breakable bottles)
  
  
  
}
