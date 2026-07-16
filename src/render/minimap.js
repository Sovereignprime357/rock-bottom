/* Generated from frozen rock_bottom_v19.html.
 * Source seams: minimap.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, runtime, state } from '../core/runtime_ui.js';
import { H, LANDMARK_FACADES, RAIL_LINES, ROAD_SEGMENTS, W, WORLD, ZONES } from '../data/world.js';
import { claimedDistrictIds, officeOwned } from '../systems/campaigns.js';

export let mm, mmctx;

export function drawMinimap() {
  const sx = 120/WORLD.w, sy = 96/WORLD.h;
  mmctx.fillStyle = '#000';
  mmctx.fillRect(0,0,120,96);
  // District color is the base layer. Roads, facades and rails must sit above it or an
  // expanded map still reads like disconnected colored rectangles.
  for (const z of ZONES) {
    mmctx.fillStyle = z.color;
    mmctx.fillRect(z.x*sx, z.y*sy, z.w*sx, z.h*sy);
  }
  mmctx.fillStyle = '#38352e';
  for (const r of ROAD_SEGMENTS) mmctx.fillRect(r.x*sx,r.y*sy,Math.max(1,r.w*sx),Math.max(1,r.h*sy));
  mmctx.fillStyle = '#171510';
  for (const f of LANDMARK_FACADES) mmctx.fillRect(f.x*sx,f.y*sy,Math.max(1,f.w*sx),Math.max(1,f.h*sy));
  mmctx.strokeStyle = '#6b6253'; mmctx.lineWidth = 1;
  for (const r of RAIL_LINES) {
    mmctx.beginPath(); mmctx.moveTo(r.x1*sx,r.y1*sy); mmctx.lineTo(r.x2*sx,r.y2*sy); mmctx.stroke();
  }
  // v18 owned forms: a gold outline means the office has a sign there, not that locals agree.
  mmctx.strokeStyle='#e8c040';mmctx.lineWidth=1;
  for(const id of claimedDistrictIds()){
    const z=ZONES.find(x=>x.id===id);if(z)mmctx.strokeRect(z.x*sx+.5,z.y*sy+.5,Math.max(1,z.w*sx-1),Math.max(1,z.h*sy-1));
  }
  // v19 clan authority is separate from office claims: rust while hostile, clan color when cleared.
  const clanClears={blue_tarp:'blueTarpCleared',cart_cavalry:'cartKeepCleared',copper_choir:'copperChoirCleared',throne:'throneDitchCleared'};
  const clanColors={blue_tarp:'#7890a0',cart_cavalry:'#d4c896',copper_choir:'#d06030',throne:'#e8c040'};
  for(const z of ZONES){
    if(!z.clan)continue;const cleared=!!(state.flags&&state.flags[clanClears[z.clan]]);
    mmctx.strokeStyle=cleared?clanColors[z.clan]:'#8a3a3a';mmctx.lineWidth=cleared?2:1;
    mmctx.strokeRect(z.x*sx+.5,z.y*sy+.5,Math.max(1,z.w*sx-1),Math.max(1,z.h*sy-1));
  }
  if(officeOwned()||(state.flags&&state.flags.theLotEntered)){
    mmctx.fillStyle=officeOwned()?'#e8c040':'#776';mmctx.fillRect(4920*sx-2,3210*sy-2,4,4);
  }
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    if (n.id==='tony') mmctx.fillStyle = '#d06030';
    else if (n.isCop) mmctx.fillStyle = '#5aa0ff';
    else if (n.hostile||n.aggro) mmctx.fillStyle = '#d04040';
    else mmctx.fillStyle = '#88aa66';
    mmctx.fillRect(n.x*sx-1, n.y*sy-1, 2, 2);
  }
  // one current bad idea. The same cached objective drives HUD, world guide and minimap.
  if(state.primaryObjective){
    const o=state.primaryObjective,ox=o.x*sx,oy=o.y*sy;
    mmctx.strokeStyle='#e8c040';mmctx.lineWidth=1;
    mmctx.strokeRect(Math.round(ox)-2,Math.round(oy)-2,5,5);
  }
  // player
  mmctx.fillStyle = '#e8c040';
  mmctx.fillRect(P.x*sx-1, P.y*sy-1, 3, 3);
  // viewport box
  mmctx.strokeStyle = 'rgba(232,192,64,.4)';
  mmctx.lineWidth = 1;
  mmctx.strokeRect(state.cam.x*sx, state.cam.y*sy, W*sx, H*sy);
}

export function init_minimap() {
  mm = document.getElementById('minimap');
  mmctx = mm.getContext('2d');
  
  
  
}
