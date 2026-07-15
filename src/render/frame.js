/* Generated from frozen rock_bottom_v19.html.
 * Source seams: frame renderer.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, particles, runtime, state } from '../core/runtime_ui.js';
import { isNight } from '../data/npc_spawns.js';
import { BUILDINGS } from '../data/props.js';
import { H, TILE, W, ZONES } from '../data/world.js';
import { VISIBLE_NPC_BUFFER, drawLighting, drawMinimap, drawNpc, drawObjectiveGuide, drawPlayer, drawProps, drawWeather } from '../legacy.js';
import { drawHeatMini, drawSmokeOverlay } from '../minigames/heat.js';
import { ctx, drawWorldFabric, visibleWorldRect } from './canvas_geography.js';
import { drawForegroundWorld, drawKingdomSites, drawLandmarkFacades, drawWorldDecor } from './landmarks_a.js';
import { drawDogLeash, drawScrapFence, drawUnderpass } from './landmarks_b.js';
import { SPRITE_CACHE } from './sprites.js';
import { drawBorderGlow, drawBuilding, drawClaimSites, drawGraffiti, drawHideoutDoors, drawOfficeExterior, drawPosters } from './structures.js';
import { drawGroundTile, drawMarketStalls } from './tiles.js';
import { playerAttack } from '../systems/combat.js';
import { drawIncidentPlayerCosmetics, drawIncidents } from '../systems/incidents.js';

export function drawAll() {
  state.visualNow = performance.now();
  ctx.fillStyle = '#0a0805';
  ctx.fillRect(0,0,W,H);
  if (state.mode === 'title') return; // title is DOM overlay
  ctx.save();
  const sx = (state.shake>0?(Math.random()-.5)*state.shake:0);
  const sy = (state.shake>0?(Math.random()-.5)*state.shake:0);
  ctx.translate(-state.cam.x + sx, -state.cam.y + sy);
  // ground tiles — per-zone variety + procedural texture
  const startX = Math.floor(state.cam.x/TILE)*TILE;
  const startY = Math.floor(state.cam.y/TILE)*TILE;
  for (let x=startX; x<state.cam.x+W+TILE; x+=TILE) {
    for (let y=startY; y<state.cam.y+H+TILE; y+=TILE) {
      drawGroundTile(x, y);
    }
  }
  // v14 — roads, footpaths, rails and district ground marks connect the zone islands.
  drawWorldFabric();
  // zones (dashed border + tinted fill)
  for (const z of ZONES) {
    if (!visibleWorldRect(z.x,z.y,z.w,z.h,20)) continue;
    // canonical VIBE treatment: ~25% wash + dashed neighborhood edge.
    ctx.fillStyle = z.color + '40';
    ctx.fillRect(z.x, z.y, z.w, z.h);
    ctx.setLineDash([6,4]);
    ctx.strokeStyle = z.label;
    ctx.lineWidth = 2;
    ctx.strokeRect(z.x+1, z.y+1, z.w-2, z.h-2);
    ctx.setLineDash([]);
    ctx.fillStyle = z.label;
    ctx.font = '11px Courier New';
    ctx.fillText(z.name, z.x+8, z.y+18);
  }
  // low street furniture sits on the pavement; cached set-back facades establish blocks.
  drawWorldDecor('low');
  drawLandmarkFacades();
  // scrap yard fence (perimeter except south gap)
  drawScrapFence();
  // underpass concrete + rebar
  drawUnderpass();
  // buildings — v10 upgrade with awnings, framed windows, signs
  for (const b of BUILDINGS) {
    if (!visibleWorldRect(b.x,b.y,b.w,b.h,40)) continue;
    drawBuilding(b);
  }
  // marketplace stalls (decoration only)
  drawMarketStalls();
  // v13 wave 7 — hideout doors (only render if owned)
  drawHideoutDoors();

  // procedural graffiti on building walls
  drawGraffiti();
  // v13 wave 8b — wall-mounted posters (per-faction zone, 1-3 each)
  drawPosters();
  // Permanent office fixtures sit above wall grime and tags so every paid upgrade reads.
  drawOfficeExterior();
  // v13 wave 8b — zone-border crossing flash (decays each frame, faction-tinted)
  drawBorderGlow();

  // props (dumpsters, lamps, hydrants, etc.)
  drawProps();
  drawKingdomSites();
  drawClaimSites();
  // poles, shelter, signs, signals and clotheslines. bodies render below actors;
  // only their overhead caps return in drawForegroundWorld.
  drawWorldDecor('tall');
  // v13 wave 6 — dog leash (rendered between props and NPCs so leash sits under dog)
  drawDogLeash();

  // hidden cash piles — only render under tweaker vision OR if close
  for (const c of runtime.cashPiles) {
    if (c.collected) continue;
    const dx = (P.x+P.w/2) - c.x, dy = (P.y+P.h/2) - c.y;
    const close = (dx*dx + dy*dy) < 60*60;
    // intro pile is always visible (it's the tutorial breadcrumb)
    const alwaysVisible = !!c.intro;
    if (state.tweakerT > 0 || close || alwaysVisible || c.tool || c.equip) {
      // v13 wave 4 — torch pickups are always visible (a brutus drop in the dark is hard enough to find)
      if (c.tool === 'propane_torch') {
        const t = (Math.sin(performance.now()/180)+1)/2;
        // brass body
        ctx.fillStyle = '#c08038';
        ctx.fillRect(c.x-5, c.y-4, 10, 8);
        // valve
        ctx.fillStyle = '#604020';
        ctx.fillRect(c.x-2, c.y-7, 4, 3);
        // pilot flame
        ctx.fillStyle = `rgba(232,192,64,${0.6 + t*0.4})`;
        ctx.fillRect(c.x-1, c.y-11, 2, 4);
        continue;
      }
      // v13 wave 5 — priest's collar pickup: small white band with a black center seam
      if (c.equip === 'priest_collar') {
        const t = (Math.sin(performance.now()/240)+1)/2;
        // halo / glow
        ctx.fillStyle = `rgba(212,200,150,${0.18 + t*0.16})`;
        ctx.fillRect(c.x-9, c.y-9, 18, 18);
        // white band
        ctx.fillStyle = '#d4c896';
        ctx.fillRect(c.x-6, c.y-3, 12, 4);
        // reversed black tab
        ctx.fillStyle = '#0a0805';
        ctx.fillRect(c.x-2, c.y-2, 4, 2);
        continue;
      }
      ctx.fillStyle = state.tweakerT>0 ? '#80ff80' : '#e8c040';
      ctx.fillRect(c.x-4, c.y-3, 8, 6);
      ctx.fillStyle = '#604020';
      ctx.fillRect(c.x-3, c.y-2, 6, 1);
      // gentle pulse glow on the intro pile so day-1 player notices it
      if (alwaysVisible) {
        const t = (Math.sin(performance.now()/220)+1)/2;
        ctx.fillStyle = `rgba(232,192,64,${0.18 + t*0.18})`;
        ctx.fillRect(c.x-8, c.y-6, 16, 12);
      }
    }
  }

  // v13 wave 3 — pigeon crown world pickup (visible whenever the quest is active)
  if (state.crownPickup && !state.crownPickup.collected) {
    const cp = state.crownPickup;
    const t = performance.now()/200;
    const bob = Math.sin(t)*2;
    // base
    ctx.fillStyle = '#a07a18';
    ctx.fillRect(cp.x-7, cp.y-3+bob, 14, 5);
    // band points
    ctx.fillStyle = '#e8c040';
    ctx.fillRect(cp.x-7, cp.y-8+bob, 3, 6);
    ctx.fillRect(cp.x-2, cp.y-9+bob, 3, 7);
    ctx.fillRect(cp.x+3, cp.y-8+bob, 3, 6);
    // gem
    ctx.fillStyle = '#d488d4';
    ctx.fillRect(cp.x-1, cp.y-7+bob, 2, 2);
    // halo
    ctx.fillStyle = `rgba(232,192,64,${0.2 + Math.sin(t*1.5)*0.12})`;
    ctx.fillRect(cp.x-12, cp.y-12+bob, 24, 18);
  }

  // Bounded scene actors sit above props and below canonical actors. They never enter npcs.
  drawIncidents();

  // NPCs. Reuse the viewport buffer so a crowded scene does not manufacture an array
  // and a garbage-collection hitch every frame.
  VISIBLE_NPC_BUFFER.length=0;
  for(const n of runtime.npcs)if(!n.dead&&
    n.x>=state.cam.x-60&&n.x<=state.cam.x+W+40&&
    n.y>=state.cam.y-60&&n.y<=state.cam.y+H+40)VISIBLE_NPC_BUFFER.push(n);
  VISIBLE_NPC_BUFFER.sort((a,b)=>(a.y+a.h)-(b.y+b.h));
  for (const n of VISIBLE_NPC_BUFFER) {
    if (n.dead) continue;
    if (n.id==='mom' && isNight()) continue;
    if (n.id==='pete' && isNight()) continue;
    if (n.daytimeOnly && isNight()) continue;
    drawNpc(n);
  }
  // particles — additive glow + scale rendering
  ctx.globalCompositeOperation = 'lighter';
  for (const p of particles) {
    if (p.glow) {
      const s = (p.sz || 4) * 2;
      ctx.fillStyle = p.c;
      ctx.globalAlpha = Math.max(0, p.life/700);
      ctx.fillRect(p.x-s/2, p.y-s/2, s, s);
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1;
  for (const p of particles) {
    if (p.glow) continue;
    ctx.fillStyle = p.c;
    const s = p.sz || 4;
    ctx.fillRect(p.x-s/2, p.y-s/2, s, s);
  }
  // v13 wave 5 — projectiles (bottles, holy water) rendered after particles, before player
  for (const pr of runtime.projectiles) {
    ctx.save();
    ctx.translate(pr.x, pr.y);
    ctx.rotate(pr.rot);
    if (pr.kind === 'bottle') {
      // body — brown glass
      ctx.fillStyle = '#604020';
      ctx.fillRect(-10, -4, 20, 8);
      // shine line
      ctx.fillStyle = '#a07020';
      ctx.fillRect(-10, -3, 20, 1);
      // neck
      ctx.fillStyle = '#3a2010';
      ctx.fillRect(8, -2, 3, 4);
    } else if (pr.kind === 'holy') {
      const t = (Math.sin(performance.now()/80)+1)/2;
      // glow halo
      ctx.fillStyle = `rgba(200,230,255,${0.18 + t*0.18})`;
      ctx.fillRect(-10, -12, 20, 24);
      // vial body
      ctx.fillStyle = `rgba(160,200,240,${0.75 + t*0.25})`;
      ctx.fillRect(-5, -8, 10, 16);
      // cap
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(-3, -10, 6, 2);
    }
    ctx.restore();
  }
  // player sprite
  drawPlayer();
  drawIncidentPlayerCosmetics();
  // v17 attack smear: cached chunky motion art replaces the old filled hitbox rectangle.
  // Collision/reach still come exclusively from playerAttack().
  if (P.attacking > 0) {
    const phase=P.attacking>80?0:1,smear=SPRITE_CACHE['attack_smear_'+P.facing+'_'+phase];
    let ax=P.x-2,ay=P.y-4;
    if(P.facing==='down')ay+=17;
    if(P.facing==='up')ay-=18;
    if(P.facing==='left')ax-=18;
    if(P.facing==='right')ax+=18;
    if(smear){ctx.globalAlpha=.45+P.attacking/160*.45;ctx.drawImage(smear,ax,ay,32,32);ctx.globalAlpha=1;}
  }

  // canopies, shelter roof and overhead wires complete the foreground plane.
  drawForegroundWorld();

  ctx.restore();

  // lighting (screen-space pass — uses cam offsets)
  drawLighting();
  // weather
  drawWeather();
  drawObjectiveGuide();

  // flash overlay
  if (state.flash > 0) {
    ctx.fillStyle = state.flashColor;
    ctx.globalAlpha = Math.min(1, state.flash);
    ctx.fillRect(0,0,W,H);
    ctx.globalAlpha = 1;
  }
  // status overlays
  if (P.rockedT > 0) {
    ctx.fillStyle = `rgba(232,192,64,${0.08 + Math.sin(performance.now()/120)*0.04})`;
    ctx.fillRect(0,0,W,H);
  }
  if (P.crashT > 0) {
    ctx.fillStyle = 'rgba(180,80,180,.18)';
    ctx.fillRect(0,0,W,H);
  }
  // v13 wave 5 — stun overlay: red corner border + center "GRABBED" floater
  if (P.stunT > 0) {
    const t = (Math.sin(performance.now()/80)+1)/2;
    ctx.fillStyle = `rgba(208,64,64,${0.10 + t*0.10})`;
    ctx.fillRect(0,0,W,8); ctx.fillRect(0,H-8,W,8);
    ctx.fillRect(0,0,8,H); ctx.fillRect(W-8,0,8,H);
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 18px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('GRABBED', W/2, 50);
    ctx.textAlign = 'left';
  }
  // v13 wave 5 — slow overlay: pale-blue veil for holy-water slow
  if (P.slowT > 0) {
    ctx.fillStyle = `rgba(160,200,240,${0.08 + Math.sin(performance.now()/220)*0.05})`;
    ctx.fillRect(0,0,W,H);
  }
  if (P.hp <= 30) {
    ctx.fillStyle = `rgba(160,40,40,${0.08 + Math.sin(performance.now()/200)*0.05})`;
    ctx.fillRect(0,0,W,H);
  }

  // boss UI
  if (state.bossActive && state.bossNPC && !state.bossNPC.dead) {
    const b = state.bossNPC;
    ctx.fillStyle = 'rgba(0,0,0,.7)';
    ctx.fillRect(W/2-160, 8, 320, 32);
    ctx.strokeStyle = '#8a3a3a';
    ctx.lineWidth = 2;
    ctx.strokeRect(W/2-160, 8, 320, 32);
    ctx.fillStyle = '#d4c896';
    ctx.font = 'bold 12px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText((state.bossKind==='kingdom'?b.name:'TRE BAG TONY')+' · '+Math.max(0,Math.ceil(b.hp))+'/'+b.maxHp, W/2, 22);
    ctx.fillStyle = '#8a3a3a';
    ctx.fillRect(W/2-150, 28, 300*(b.hp/b.maxHp), 8);
    ctx.textAlign = 'left';
  }

  // combo display
  if (state.combo >= 2) {
    const fade = Math.min(1, state.comboT/1000);
    ctx.fillStyle = `rgba(232,192,64,${fade})`;
    ctx.font = 'bold ' + (16 + state.combo*2) + 'px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText(state.combo + 'x', W/2, H-80);
    ctx.font = '10px Courier New';
    ctx.fillText('combo', W/2, H-66);
    ctx.textAlign = 'left';
  }

  // low-HP edge vignette
  if (P.hp <= 30) {
    const intensity = (1 - P.hp/30) * 0.6 + Math.sin(performance.now()/300)*0.1;
    const g = ctx.createRadialGradient(W/2, H/2, 150, W/2, H/2, 460);
    g.addColorStop(0, 'rgba(160,40,40,0)');
    g.addColorStop(1, `rgba(160,40,40,${intensity})`);
    ctx.fillStyle = g;
    ctx.fillRect(0,0,W,H);
  }

  // shakes-max wobble
  if (P.shakes >= 90) {
    ctx.fillStyle = 'rgba(212,136,212,.08)';
    ctx.fillRect(0,0,W,H);
  }

  // weather under HUD
  // already drawn after restore

  // minimap
  drawMinimap();

  // v13 wave 4 — smoke overlay from a burnt cook (sits above gameplay, below the heat mini)
  if (state.smokeT > 0) drawSmokeOverlay();
  // v13 wave 4 — the heat minigame panel (only when mode === 'cookmini')
  if (state.mode === 'cookmini') drawHeatMini();
}

export function init_frame() {
  
  
  
}
