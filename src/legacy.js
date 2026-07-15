/* Generated from frozen rock_bottom_v19.html.
 * Source seams: prop and interactive-prop rendering | lighting, weather, actors, and objectives | minimap | ending, interaction, and dumpster systems | daily systems and hideouts | heist, weapons, rhythm, lockpick, Brutus, and panhandling | keyboard controls | game start and new-game initialization | cache and HUD boot sequence | mobile controls and final startup.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { SAVE_KEY, audio, loadGame, saveGame } from './core/audio_save.js';
import { P, activeDialogue, applyEquipStats, closeDialogue, closePanel, dialogue, particles, renderInventory, renderQuests, rollWeather, runtime, state, toast, unlockAchievement } from './core/runtime_ui.js';
import { last, update, updateWorld } from './core/update.js';
import { EQUIPMENT, PUBLIC_PHONE_LINES, VENDOR_FLOATER_IDS, VENDOR_INDEX_META } from './data/catalogs.js';
import { clamp, inZone, isNight, spawnCashPiles, spawnNpcs } from './data/npc_spawns.js';
import { BUILDINGS, PROPS, initInteractiveProps, interactiveProps } from './data/props.js';
import { H, LANDMARK_FACADES, RAIL_LINES, RANKS, ROAD_SEGMENTS, W, WORLD, WORLD_LIGHTS, ZONES } from './data/world.js';
import { possumDialogue } from './dialogue/neighborhood_a.js';
import { openStripePackage } from './dialogue/neighborhood_b.js';
import { tryEnterOldSchool, tryParkBenchSit } from './dialogue/vendors_places.js';
import { bailHeatMini, cookBatchMenu, hasPropane, lockHeatMini } from './minigames/heat.js';
import { buildEnvironmentSprites, ctx, visibleWorldRect } from './render/canvas_geography.js';
import { drawAll } from './render/frame.js';
import { FOG_SHEET, LIGHT_CTX, LIGHT_GLOW_CACHE, LIGHT_MASK, buildFogSheet, buildLandmarkFacades, buildLightSprites, nightAmount, punchLightMask } from './render/landmarks_a.js';
import { PALS, SPRITE_CACHE, buildSprites } from './render/sprites.js';
import { buildGraffiti, buildPosters } from './render/structures.js';
import { CLAIM_SITES, CLAIM_SITE_BY_ID, OFFICE_DOOR, OFFICE_UPGRADE_DEFS, activeOfficeContract, cancelDistrictClaim, claimFileCost, claimGateReason, claimedDistrictIds, currentPrimaryObjective, ensureKingdomState, ensureOfficeState, fileDistrictClaim, fileOfficeWork, freshKingdomState, freshOfficeState, maybeUnlockKingdom, maybeUnlockOfficeQuest, officeDailyCap, officeOwned, openKingdomLedger, purchaseOfficeUpgrade, selectDistrictClaim, startOfficeWork, syncKingdomForces, syncKingdomQuests, syncOfficeDay, tryKingdomDoor, tryUseKingdomTarget, tryUseOfficeFieldTarget, updateOfficeMilestones } from './systems/campaigns.js';
import { completeIntroSmoke, die, playerAttack, questToast } from './systems/combat.js';
import { broadcastNews, feedPost, phoneState, renderPhone, rotateNews } from './systems/communications.js';
import { adjustFaction, applyRep, factionTier } from './systems/factions.js';
import { startIncident, updateActiveIncident } from './systems/incidents.js';
import { ROUTE_STOPS, checkHustles, ensureBlockRoute, hustleProgress, rollBlockRoute, rollHustles, routePatchTier, tryStampBlockRoute, validBlockRoute } from './systems/progression_routes.js';
import { updateHUD } from './ui/hud.js';

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

export let VISIBLE_NPC_BUFFER, NPC_IDLE_SPRITES, NPC_TWO_FRAME_SPRITES;

export function drawLighting() {
  const amount=nightAmount();
  if(amount<=.01)return;
  const octx=LIGHT_CTX;
  octx.globalCompositeOperation='source-over';
  octx.globalAlpha=1;
  octx.clearRect(0,0,W,H);
  octx.fillStyle=`rgba(0,0,0,${(.72*amount).toFixed(3)})`;
  octx.fillRect(0,0,W,H);
  octx.globalCompositeOperation='destination-out';
  for(const p of PROPS){
    if(p.type!=='lamp')continue;
    punchLightMask(octx,p.x-state.cam.x,p.y-32-state.cam.y,120,1,amount);
  }
  for(const l of WORLD_LIGHTS){
    if(l.office&&!(state.office&&state.office.upgrades&&state.office.upgrades.generator))continue;
    punchLightMask(octx,l.x-state.cam.x,l.y-state.cam.y,l.radius,l.power+.35,amount);
  }
  const px=P.x+P.w/2-state.cam.x,py=P.y+P.h/2-state.cam.y;
  punchLightMask(octx,px,py,P.rockedT>0?132:92,P.rockedT>0?1:.86,amount);
  octx.globalAlpha=1;octx.globalCompositeOperation='source-over';
  ctx.drawImage(LIGHT_MASK,0,0);

  // Colored cached glow sprites. Static gradients were built once at init.
  ctx.globalCompositeOperation='lighter';
  for(const p of PROPS){
    if(p.type!=='lamp')continue;
    const sx=p.x-state.cam.x,sy=p.y-32-state.cam.y,r=74;
    if(sx<-r||sx>W+r||sy<-r||sy>H+r)continue;
    ctx.globalAlpha=.72*amount;
    ctx.drawImage(LIGHT_GLOW_CACHE['255,210,120'],sx-r,sy-r,r*2,r*2);
  }
  for(const l of WORLD_LIGHTS){
    if(l.office&&!(state.office&&state.office.upgrades&&state.office.upgrades.generator))continue;
    const sx=l.x-state.cam.x,sy=l.y-state.cam.y,r=l.radius*.74;
    if(sx<-r||sx>W+r||sy<-r||sy>H+r)continue;
    ctx.globalAlpha=l.power*amount;
    const glow=LIGHT_GLOW_CACHE[l.rgb];
    if(glow)ctx.drawImage(glow,sx-r,sy-r,r*2,r*2);
  }
  ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';
}

export function drawWeather() {
  if (state.weather === 'rain') {
    ctx.strokeStyle = 'rgba(180,200,220,.5)';
    ctx.lineWidth = 1;
    const t = performance.now() / 30;
    for (let i=0;i<160;i++) {
      const x = ((i*73 + t) % W);
      const y = ((i*47 + t*1.4) % H);
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x-3, y+10);
      ctx.stroke();
    }
  }
  if (state.weather === 'fog') {
    // Cached fog sheet; reduce opacity at night so the player and boss telegraphs survive
    // the night + fog stack instead of disappearing into a gray-black slab.
    ctx.globalAlpha = .72 - nightAmount()*.18;
    ctx.drawImage(FOG_SHEET,0,0);
    ctx.globalAlpha = 1;
  }
}

export function resolveNpcPose(n, visualNow) {
  let frame = Number.isFinite(n.frame) ? n.frame : 0;
  let spriteKey = n.sprite;
  if (n.asleep && n.sprite === 'dave') {
    spriteKey = 'dave_sleep'; frame = Math.floor(visualNow/850)%2;
  } else if (n.isOmalleyFallen || n.id === 'omalley_fallen') {
    spriteKey = 'priest_fallen';
  } else if (n.sprite === 'tony' && (n.coatsOff||0)>0) {
    spriteKey = n.coatsOff>=3 ? 'tony_bare' : n.coatsOff===2 ? 'tony_coat_1' : 'tony_coat_2';
  } else if (n.sprite === 'scrap_dog' && n.chargeState === 'windup') {
    frame = 1;
  } else if (!n.aggro && !n.hostile && frame===0) {
    if(n.sprite==='scrap_dog') frame=(n.tailWag||0)>.25?Math.floor(visualNow/180)%2:0;
    else if (NPC_IDLE_SPRITES.has(n.sprite)) frame = Math.floor((visualNow + n.x*7 + n.y*3)/900)%2;
  }
  if(NPC_TWO_FRAME_SPRITES.has(spriteKey))frame=((frame%2)+2)%2;
  return { spriteKey, frame, bob:(n.frame===1||n.frame===2)?-1:0 };
}

export function drawNpc(n) {
  // body shadow — soft elliptical
  ctx.fillStyle = 'rgba(0,0,0,.45)';
  ctx.beginPath();
  ctx.ellipse(n.x+n.w/2, n.y+n.h-1, n.w/2, 3, 0, 0, Math.PI*2);
  ctx.fill();
  // sprite (with walk/identity frame). Bottom-center anchoring keeps 22px pedestrians,
  // 36px horse cops and 28px vendors aligned to their actual hitbox feet.
  const visualNow = state.visualNow || performance.now();
  const pose=resolveNpcPose(n,visualNow),frame=pose.frame,spriteKey=pose.spriteKey;
  const sp = SPRITE_CACHE[spriteKey+'_'+frame] || SPRITE_CACHE[spriteKey+'_0'];
  if (sp) {
    if (n.hitFlash) ctx.globalCompositeOperation = 'lighter';
    // tiny bob when walking
    const bob = pose.bob;
    const drawX = Math.round(n.x+n.w/2-16);
    const drawY = Math.round(n.y+n.h-32+bob);
    ctx.drawImage(sp, drawX, drawY, 32, 32);
    ctx.globalCompositeOperation = 'source-over';
  } else {
    ctx.fillStyle = n.color;
    ctx.fillRect(n.x, n.y, n.w, n.h);
  }
  // asleep "Z"
  if (n.asleep) {
    ctx.fillStyle = '#d4c896';
    ctx.font = '10px Courier New';
    const zT = Math.sin(performance.now()/600) * 2;
    ctx.fillText('z', n.x+n.w, n.y+zT);
    ctx.fillText('z', n.x+n.w+4, n.y-6-zT);
  }
  // Nameplates back away when they are not useful. Long cursed names wrap instead of
  // carpeting the roster; vendors and combat states remain explicit at any visible range.
  const pdx=(P.x+P.w/2)-(n.x+n.w/2), pdy=(P.y+P.h/2)-(n.y+n.h/2);
  const showName = n.vendor || n.hostile || n.aggro || (pdx*pdx+pdy*pdy)<260*260;
  if (showName) {
    ctx.font='9px Courier New';
    if(n._labelText!==n.name){
      const words=String(n.name||'').split(' '), lines=[''];
      for(const word of words){
        const last=lines.length-1, joined=(lines[last]+' '+word).trim();
        if(joined.length>17&&lines[last]&&lines.length<2)lines.push(word);else lines[last]=joined;
      }
      n._labelText=n.name;n._labelLines=lines;n._labelWidths=lines.map(line=>Math.ceil(ctx.measureText(line).width));
    }
    const labelLines=n._labelLines,labelWidths=n._labelWidths;
    ctx.textAlign='center';
    const cx=n.x+n.w/2, top=n.y-8-labelLines.length*10;
    for(let i=0;i<labelLines.length;i++){
      const line=labelLines[i], tw=labelWidths[i];
      ctx.fillStyle='rgba(10,8,5,.76)'; ctx.fillRect(Math.round(cx-tw/2-3),top+i*10-8,tw+6,10);
      ctx.fillStyle=(n.hostile||n.aggro)?'#d04040':'#d4c896'; ctx.fillText(line,cx,top+i*10);
    }
    ctx.textAlign='left';
  }
  // hp bar — graphical with frame
  if (n.showHp && n.hp < n.maxHp) {
    ctx.fillStyle = '#000';
    ctx.fillRect(n.x-1, n.y-5, n.w+2, 4);
    ctx.fillStyle = '#220';
    ctx.fillRect(n.x, n.y-4, n.w, 2);
    const hpRatio = n.hp/n.maxHp;
    const c = hpRatio > 0.6 ? '#a8c030' : hpRatio > 0.3 ? '#e8c040' : '#d04040';
    ctx.fillStyle = c;
    ctx.fillRect(n.x, n.y-4, n.w*hpRatio, 2);
  }
  // aggro "!"
  if (n.aggro) {
    const bounce = Math.sin(performance.now()/180) * 2;
    ctx.fillStyle = '#e8c040';
    ctx.font = 'bold 14px Courier New';
    ctx.fillText('!', n.x+n.w+2, n.y+8 + bounce);
  }
  // v13 wave 5 — charger windup telegraph: red tint + giant white "!" floating up
  if (n.chargeState === 'windup') {
    const pulse = (Math.sin(performance.now()/60)+1)/2;
    ctx.fillStyle = `rgba(208,64,64,${0.18 + pulse*0.22})`;
    ctx.fillRect(n.x-3, n.y-5, n.w+6, n.h+8);
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 18px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('!', n.x+n.w/2, n.y - 12 - pulse*4);
    ctx.textAlign = 'left';
  }
  // charger cooldown — soft panting visual
  if (n.chargeState === 'cooldown') {
    const t = (Math.sin(performance.now()/120)+1)/2;
    ctx.fillStyle = `rgba(208,192,160,${0.10 + t*0.10})`;
    ctx.fillRect(n.x-2, n.y-3, n.w+4, n.h+4);
  }
  // ranged / fallen-priest aim raise
  if (n.aimingThrow) {
    ctx.fillStyle = '#fff080';
    ctx.font = 'bold 10px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('*', n.x+n.w/2, n.y - 10);
    ctx.textAlign = 'left';
  }
  // cop radio (hand to ear)
  if (n.radioVisualT > 0) {
    ctx.fillStyle = '#88c0ff';
    ctx.font = 'bold 11px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('*', n.x+n.w/2 + 8, n.y - 6 + Math.sin(performance.now()/100)*1);
    ctx.textAlign = 'left';
  }
  // grabber freeze pose — small "✋" marker (text-safe fallback)
  if (n.grabFreezeT > 0) {
    ctx.fillStyle = '#d488d4';
    ctx.font = 'bold 12px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText('-<', n.x+n.w/2, n.y - 12);
    ctx.textAlign = 'left';
  }
  // v13 wave 3 — unvisited-vendor "?" floater. fades on first dialogue open.
  // never on hostile or aggro'd npcs (would clash with the aggro "!" and read weird).
  // v13 wave 7 — also draw for npcs flagged with n.hasFloater (day event actors).
  if ((VENDOR_FLOATER_IDS.has(n.id) || n.hasFloater) && !state.metVendors.has(n.id) && !n.aggro && !n.hostile) {
    const bob = Math.sin(performance.now()/360 + (n.x*0.013)) * 2;
    const fy = n.y - 16 + bob;
    const fx = n.x + n.w/2;
    const sym = n.hasFloater || '?';
    const sz = n.hasFloater === '?' && n.isBusDriver ? 22 : 16;
    ctx.save();
    ctx.globalAlpha = 0.78;
    ctx.fillStyle = '#0a0805';
    ctx.font = `bold ${sz}px Courier New`;
    ctx.textAlign = 'center';
    ctx.fillText(sym, fx+1, fy+1);
    ctx.fillStyle = '#e8c040';
    ctx.fillText(sym, fx, fy);
    ctx.textAlign = 'left';
    ctx.restore();
  }
  // chatter bubble
  if (n.chatterT > 0 && n.chatter) {
    const tw = n.chatter.length * 5.4 + 8;
    ctx.fillStyle = 'rgba(0,0,0,.85)';
    ctx.fillRect(n.x+n.w/2 - tw/2, n.y-26, tw, 14);
    ctx.strokeStyle = '#665';
    ctx.lineWidth = 1;
    ctx.strokeRect(n.x+n.w/2 - tw/2, n.y-26, tw, 14);
    // tail
    ctx.fillStyle = 'rgba(0,0,0,.85)';
    ctx.beginPath();
    ctx.moveTo(n.x+n.w/2 - 3, n.y-12);
    ctx.lineTo(n.x+n.w/2 + 3, n.y-12);
    ctx.lineTo(n.x+n.w/2, n.y-7);
    ctx.fill();
    ctx.fillStyle = '#d4c896';
    ctx.font = '9px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText(n.chatter, n.x+n.w/2, n.y-16);
    ctx.textAlign = 'left';
  }
}

export function drawPlayer() {
  // shadow
  ctx.fillStyle = 'rgba(0,0,0,.5)';
  ctx.fillRect(P.x+2, P.y+P.h-2, P.w-4, 4);
  const dir = P.facing, f = P.frame;
  // Cached 16x16 cart underlay. It uses the same logical-pixel discipline as every body
  // instead of becoming a runtime rectangle costume when mounted.
  if (P.cartMounted) {
    const cart=SPRITE_CACHE['cart_underlay_'+dir];
    if(cart)ctx.drawImage(cart,P.x-4,P.y,32,32);
  }
  const playerDrawX=P.x-2,playerDrawY=P.y-4+(P.crashT>0?1:0);
  // rocked-up ghost trail (3 frames back, chromatic split)
  if (P.rockedT > 0) {
    const t = performance.now();
    // push trail history
    if (!P.trail) P.trail = [];
    P.trail.push({ x: P.x, y: P.y, dir, f });
    if (P.trail.length > 6) P.trail.shift();
    for (let i=0;i<P.trail.length-1;i++) {
      const tr = P.trail[i];
      const alpha = (i/P.trail.length) * 0.35;
      const sp = SPRITE_CACHE['playerhi_' + tr.dir + '_' + tr.f];
      if (sp) {
        ctx.globalAlpha = alpha;
        // RGB-shifted ghost trio (chromatic aberration)
        ctx.globalCompositeOperation = 'lighter';
        ctx.drawImage(sp, tr.x-2 + (i-3), tr.y-4, 32, 32);
        ctx.globalCompositeOperation = 'source-over';
      }
    }
    ctx.globalAlpha = 1;
  } else if (P.trail) {
    P.trail.length = 0;
  }
  const attackPhase=P.attacking>0?(P.attacking>80?0:1):0;
  const key = P.attacking>0
    ? (P.rockedT>0?'playerattackhi_':'playerattack_')+dir+'_'+attackPhase
    : (P.rockedT>0?'playerhi_':'player_')+dir+'_'+f;
  const sp = SPRITE_CACHE[key];
  if (sp) {
    const damageAlpha=(P.hitFlash > 0 || (P.iframes>0 && Math.floor(P.iframes/80)%2))?.5:1;
    // chromatic split when rocked
    if (P.rockedT > 0) {
      const shake = Math.sin(performance.now()/60) * 1.2;
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = 0.5*damageAlpha;
      ctx.drawImage(sp, playerDrawX + shake, playerDrawY, 32, 32);
      ctx.drawImage(sp, playerDrawX - shake, playerDrawY, 32, 32);
      ctx.globalCompositeOperation = 'source-over';
    }
    ctx.globalAlpha=damageAlpha;
    ctx.drawImage(sp, playerDrawX, playerDrawY, 32, 32);
    // Equipment is a stack of cached transparent 16x16-derived layers. Loot now changes
    // the avatar instead of only changing numbers in the inventory panel.
    const eq=P.equip||{};
    const drawGear=(slot)=>{
      const id=eq[slot];if(!id)return;const layer=SPRITE_CACHE['gear_'+id+'_'+dir];if(layer)ctx.drawImage(layer,playerDrawX,playerDrawY,32,32);
    };
    drawGear('coat');
    const patchTier=routePatchTier();
    if(patchTier){const patch=SPRITE_CACHE['route_patch_'+patchTier+'_'+dir];if(patch)ctx.drawImage(patch,playerDrawX,playerDrawY,32,32);}
    drawGear('shoes');drawGear('hat');drawGear('tool');
    // Attack phase 0 holds the item close; phase 1 commits the extended swing layer.
    const weaponState=P.attacking>0?attackPhase:0;
    const weapon=SPRITE_CACHE['weapon_'+(P.weapon||'fists')+'_'+dir+'_'+weaponState];
    if(weapon)ctx.drawImage(weapon,playerDrawX,playerDrawY,32,32);
    ctx.globalAlpha = 1;
  } else {
    ctx.fillStyle = '#604020';
    ctx.fillRect(P.x, P.y, P.w, P.h);
  }
  // rocked-up aura
  if (P.rockedT > 0) {
    ctx.strokeStyle = `rgba(232,192,64,${0.4 + Math.sin(performance.now()/120)*0.3})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(P.x+P.w/2, P.y+P.h/2, 22 + Math.sin(performance.now()/200)*2, 0, Math.PI*2);
    ctx.stroke();
    // pulsing inner ring
    ctx.strokeStyle = `rgba(255,240,180,${0.2 + Math.sin(performance.now()/80)*0.15})`;
    ctx.beginPath();
    ctx.arc(P.x+P.w/2, P.y+P.h/2, 16 + Math.sin(performance.now()/100)*1.5, 0, Math.PI*2);
    ctx.stroke();
  }
}

export function drawObjectiveGuide(){
  if(state.mode!=='playing'||!state.primaryObjective)return;
  const o=state.primaryObjective,sx=o.x-state.cam.x,sy=o.y-state.cam.y;
  const t=(state.visualNow||performance.now())/180,pulse=(Math.sin(t)+1)/2;
  ctx.save();ctx.lineWidth=2;ctx.strokeStyle=`rgba(232,192,64,${.62+pulse*.3})`;ctx.fillStyle='#e8c040';
  if(sx>24&&sx<W-24&&sy>36&&sy<H-30){
    const r=11+pulse*3;ctx.beginPath();ctx.arc(sx,sy,r,0,Math.PI*2);ctx.stroke();
    ctx.fillRect(Math.round(sx-2),Math.round(sy-r-8),4,4);
  }else{
    const cx=W/2,cy=H/2,ang=Math.atan2(sy-cy,sx-cx),ex=clamp(sx,24,W-24),ey=clamp(sy,42,H-34);
    ctx.translate(ex,ey);ctx.rotate(ang);ctx.beginPath();ctx.moveTo(10,0);ctx.lineTo(-7,-6);ctx.lineTo(-4,0);ctx.lineTo(-7,6);ctx.closePath();ctx.fill();
  }
  ctx.restore();
}

export function init_actors_weather() {
  // Lighting + weather overlay (rendered AFTER everything in world space)
  
  
  // Weather (rain)
  
  
  VISIBLE_NPC_BUFFER=[];
  NPC_IDLE_SPRITES = new Set(['barb','larry','phoneguy','math','pigeon','possum','scrap_dog']);
  NPC_TWO_FRAME_SPRITES = new Set(['dave_sleep','brutus','scrap_dog','os_brutus','horsecop','pigeon','possum']);
  // Pure visual-state selector: rendering can ask for a pose without changing simulation state.
  // This keeps animation decisions deterministic for screenshots, tests, and cached sprite reuse.
  
  
  
  
  
  
  
  
}

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

export function endingScreen(kind) {
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  const titleText = kind === 'kingdom' ? 'ONE CRACKLORD' : kind === 'coop' ? 'TUESDAYS AND THURSDAYS' : 'CRACK LORD SUPREME';
  const subText = kind === 'kingdom'
    ? 'the kingdom is four curbs and a ditch · the throne is a folding chair'
    : kind === 'coop'
      ? 'you and stripe split the corner · you get the slow days'
      : 'the corner is yours · you get tuesdays and thursdays';
  t.innerHTML = `
    <h1 style="color:#d06030;font-size:36px">${titleText}</h1>
    <div class="sub">${subText}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum still knows</div>`;
  // An ending is a receipt, not a save eraser. The route ledger survives the punchline.
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryInteract() {
  if(state.bossKind==='kingdom')return;
  // v18 headquarters is a separate door type; it never enters hideoutOwned(kind).
  if (tryEnterOffice()) return;
  // v13 wave 7 — hideout doors (E within 40px while owned). doors win over everything.
  if (tryEnterHideout()) return;
  // v13 wave 8a — old school door (E within 44px). modal interior dialogue (hideout pattern).
  // wave 8.6: now rank-gated (P.rank >= 3) inside tryEnterOldSchool.
  if (tryEnterOldSchool()) return;
  if (tryKingdomDoor()) return;
  if (tryUseKingdomTarget()) return;
  if (tryUseOfficeFieldTarget()) return;
  // v17 block-route stamps are authored away from NPC anchors. They sit after doors and
  // before the general scan so the prompt and the actual E action always agree.
  if (tryStampBlockRoute()) return;

  // v13 wave 8.6 — NPCs win over interactive props. closest-NPC-within-60px first.
  // before this lift, kickable trash / pay phone / dumpster / cart / bench all fired ahead
  // of the NPC scan, which routed E to a trash can when standing next to a vendor.
  // chain (post-doors): NPCs > heist trigger > interactive props (bench, trash, phone, cart,
  // dumpster) > zone-only verbs (smoke at block, panhandle at market).
  let bestNpc = null, bestNpcD = 60*60;
  for (const n of runtime.npcs) {
    if (n.dead || !n.interact) continue;
    const dx = (P.x+P.w/2) - (n.x+n.w/2), dy = (P.y+P.h/2) - (n.y+n.h/2);
    const d2 = dx*dx+dy*dy;
    if (d2 < bestNpcD) { bestNpcD = d2; bestNpc = n; }
  }
  if (bestNpc) {
    if (bestNpc.id === 'pete' && bestNpc.shopClosed) {
      toast("pete is sleeping inside.\n'we open at 6.'", 1800); return;
    }
    // v13 wave 3 — first-time interaction with a tracked vendor lifts the "?" floater
    // and adds them to the people-met index.
    if (VENDOR_FLOATER_IDS.has(bestNpc.id)) {
      const first = !state.metVendors.has(bestNpc.id);
      state.metVendors.add(bestNpc.id);
      if (first) saveGame();
      // intro_tony auto-completes the moment the player opens tony's dialogue
      if (bestNpc.id === 'tony' && state.quests.intro_tony && state.quests.intro_tony.available && !state.quests.intro_tony.done) {
        state.quests.intro_tony.done = true;
        P.cred += 1;
        questToast('THE MAN AT THE CORNER');
        toast("he charges ten dollars. that is the price.\nhe does not negotiate. sometimes he does.", 3400);
        if (state.quests.intro_smoke) state.quests.intro_smoke.available = true;
      }
    }
    bestNpc.interact(bestNpc);
    return;
  }

  // abandoned heist trigger — proximity to the locked building. NPCs already missed; this is
  // the highest-priority non-NPC interaction because it's the canonical late-game gate.
  const heistB = BUILDINGS.find(b=>b.locked);
  if (heistB) {
    const cx = P.x+P.w/2, cy = P.y+P.h/2;
    if (cx > heistB.x-20 && cx < heistB.x+heistB.w+20 && cy > heistB.y-20 && cy < heistB.y+heistB.h+20) {
      startHeist(); return;
    }
  }
  // v13 wave 8a — park bench sit toggle (E within 50px of any park_bench).
  if (tryParkBenchSit()) return;
  // v13 wave 6 — kickable trash cans (E within 50px). 50% cash / 20% junk / 30% rats.
  for (const ip of interactiveProps) {
    if (ip.type !== 'trashcan') continue;
    const ddx = (P.x+P.w/2) - ip.x, ddy = (P.y+P.h/2) - ip.y;
    if (ddx*ddx + ddy*ddy < 50*50) {
      if (ip.cdT > 0) { toast("the can is empty.\nyou kick it anyway.\nit barely moves.", 1500); return; }
      kickTrashCan(ip);
      return;
    }
  }
  // v13 wave 6 — pay phone answer (E within 30px while ringing)
  const phone = PROPS.find(p => p.type === 'pay_phone');
  if (phone) {
    const ddx = (P.x+P.w/2) - phone.x, ddy = (P.y+P.h/2) - phone.y;
    if (ddx*ddx + ddy*ddy < 38*38 && state.phonePropRingT > 0) {
      answerPublicPhone();
      return;
    }
  }
  // shopping cart mount/dismount
  const cart = PROPS.find(p => p.type==='cart');
  if (cart) {
    if (P.cartMounted) {
      // dismount near player
      const dx = (P.x+P.w/2) - cart.x, dy = (P.y+P.h/2) - cart.y;
      if (cart.mounted === 'me') {
        P.cartMounted = false; cart.mounted = false;
        cart.x = P.x + 4; cart.y = P.y + 8;
        applyEquipStats();
        toast('you abandon the cart.\nit rolls slightly. accuses you.', 1800);
        return;
      }
    } else {
      const dx = (P.x+P.w/2) - cart.x, dy = (P.y+P.h/2) - cart.y;
      if (dx*dx + dy*dy < 36*36) {
        P.cartMounted = true; cart.mounted = 'me';
        applyEquipStats();
        unlockAchievement('cart_baron');
        toast('+ shopping cart\n+1 speed. you can hit people now.', 2200);
        return;
      }
    }
  }
  // dumpster dive
  for (const p of PROPS) {
    if (p.type !== 'dumpster') continue;
    const dx = (P.x+P.w/2) - (p.x+p.w/2), dy = (P.y+P.h/2) - (p.y+p.h/2);
    if (dx*dx + dy*dy < 44*44) {
      if (p.looted) { toast('the dumpster is empty.\nyou look anyway.', 1500); return; }
      // tips jar bonus
      if (p.tipsJar) {
        p.tipsJar = false;
        P.cash += 8 + Math.floor(Math.random()*7);
        audio.coin();
        toast("there's a 'TIPS' jar duct-taped to the dumpster.\nit has cash in it.\n+ $"+ (8 + Math.floor(Math.random()*7))+"\n(then there's the rest of the dumpster.)", 3000);
      }
      startDumpsterDive(p);
      return;
    }
  }
  // smoke at block — open menu (zone verb, fires only when no NPC / prop took the E)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'block')) {
    blockMenu();
    return;
  }
  // panhandling at marketplace — easy money (zone verb, NPC scan already missed)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'market')) {
    panhandle();
    return;
  }
}

export function startDumpsterDive(dumpster) {
  state.mode = 'dialogue';
  const items = [];
  const trashPool = [
    {n:'half a chimichanga', q:'eat', heal:12},
    {n:'a wet sock', q:'sell', val:2},
    {n:'a license plate', q:'item', id:'license'},
    {n:'a hot pocket sleeve', q:'sell', val:3},
    {n:'a tooth (gold)', q:'sell', val:18},
    {n:'a strange shoe', q:'equip', id:'crocs'},
    {n:'a parka in august', q:'equip', id:'parka'},
    {n:'a single airpod', q:'equip', id:'airpods'},
    {n:'a mesh hat', q:'equip', id:'mesh_cap'},
    {n:'a cowboy hat', q:'equip', id:'cowboy'},
    {n:'a hotel bathrobe', q:'equip', id:'bathrobe'},
    {n:'a windbreaker', q:'equip', id:'windbreaker'},
    {n:'a ski mask in june', q:'equip', id:'ski_mask'},
    {n:'a tiny construction helmet', q:'equip', id:'helmet'},
    {n:'a trench coat (one of three)', q:'equip', id:'trench'},
    {n:'a flashlight (dead)', q:'item'},
    {n:'a receipt', q:'item'},
    {n:'a lottery ticket (unscratched)', q:'item', id:'lottery'},
    {n:"someone's wallet ($15)", q:'cash', val:15},
    {n:"a stack of singles ($8)", q:'cash', val:8},
    {n:'a possum (alive)', q:'event', what:'possum'},
    {n:"someone's wedding ring", q:'sell', val:22},
  ];
  // v13 wave 6 — bias by distance from THE BLOCK center (1050, 840).
  // close dumpsters lean toward nothing; far dumpsters carry the loot table.
  const blockCx = 1050, blockCy = 840;
  const dDist = Math.sqrt((dumpster.x-blockCx)**2 + (dumpster.y-blockCy)**2);
  const farFactor = Math.min(1, dDist / 900); // 0 = next to block, 1 = max distance
  // table: 30% nothing, 30% $1-4, 20% junk, 10% clean packet, 8% broken bottle, 2% propane (one-and-done)
  // bias: closer dumpsters get higher nothing chance.
  const r = Math.random();
  const noNothingBoost = farFactor * 0.6; // far dumpsters have less "nothing"
  const noneCut = 0.30 + (1 - farFactor) * 0.20; // close = 50% nothing, far = 30%
  let lootPicked = null;
  if (r < noneCut) {
    lootPicked = {n:'nothing. dumpsters know.', q:'rats'};
  } else if (r < noneCut + 0.30) {
    lootPicked = {n:"$"+(1+Math.floor(Math.random()*4))+' in loose bills', q:'cash', val: 1+Math.floor(Math.random()*4)};
  } else if (r < noneCut + 0.50) {
    lootPicked = {n:'a piece of junk (sells $1)', q:'junkdrop'};
  } else if (r < noneCut + 0.60) {
    lootPicked = {n:'a clean packet of supply', q:'clean_packet'};
  } else if (r < noneCut + 0.68) {
    lootPicked = {n:'a broken bottle (weapon)', q:'bb_weapon'};
  } else {
    // remaining slice (~32% buffer) — propane only if far enough AND not already awarded
    if (farFactor > 0.6 && !hasPropane() && !state.flags.dumpsterPropaneAwarded && Math.random() < 0.07) {
      lootPicked = {n:'a propane torch (dented)', q:'torch_drop'};
    } else {
      // fall back to a random standard item from the trashPool
      lootPicked = trashPool[Math.floor(Math.random()*trashPool.length)];
    }
  }
  // 2 random fillers + the loot-table pick
  for (let i=0;i<2;i++) items.push(trashPool[Math.floor(Math.random()*trashPool.length)]);
  items.push(lootPicked);
  dialogue('THE DUMPSTER', "you are inside a dumpster.\nyou find three things.\nyou can take one.", items.map((it,idx) => ({
    label: it.n + (it.q==='sell'?' (sell)':it.q==='eat'?' (eat)':it.q==='cash'?' (take)':it.q==='equip'?' (wear)':''),
    action: () => {
      if (it.q === 'eat') { P.hp = Math.min(P.maxHp, P.hp + (it.heal||5)); toast('+ '+it.heal+' hp\n(it tastes like the dumpster.)'); }
      else if (it.q === 'sell') { const v = it.val || (3 + Math.floor(Math.random()*4)); P.cash += v; toast('+ $'+v+'\n('+it.n+'.)'); audio.coin(); }
      else if (it.q === 'cash') { P.cash += it.val; audio.coin(); toast('+ $'+it.val+'\n('+it.n+'.)'); }
      else if (it.q === 'item') { P.inventory.push({id: it.id||it.n.replace(/\W/g,''), n: it.n, q: 1}); toast('+ '+it.n); }
      else if (it.q === 'equip' && it.id && EQUIPMENT[it.id]) {
        const slot = EQUIPMENT[it.id].slot;
        P.equip[slot] = it.id; applyEquipStats();
        toast('+ EQUIPPED · '+EQUIPMENT[it.id].n);
      }
      else if (it.q === 'event' && it.what === 'possum') {
        toast("a possum.\nhe is annoyed.\nhe leaves through the lid.");
        possumDialogue();
      }
      // v13 wave 6 — new loot-table outcomes
      else if (it.q === 'rats') {
        toast("the rats are upset.\nthey have lives.", 2000);
        for (let i=0;i<10;i++) particles.push({x:dumpster.x+Math.random()*dumpster.w, y:dumpster.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-0.5, life:600, c:'#181010', sz:2});
      }
      else if (it.q === 'junkdrop') {
        P.inventory.push({id:'junk', n:'a piece of junk', q:1});
        toast("+ a piece of junk.\n(pete will take it. for one dollar.)", 2200);
      }
      else if (it.q === 'clean_packet') {
        P.supplies = (P.supplies||0) + 1;
        toast("+ a clean packet.\n(unmarked. you take it. you don't ask.)", 2400); audio.coin();
      }
      else if (it.q === 'bb_weapon') {
        pickupWeapon('broken_bottle');
        toast("+ a broken bottle.\nit cuts. you understand this.\n(weapon equipped.)", 2600);
      }
      else if (it.q === 'torch_drop') {
        if (!hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          state.flags.dumpsterPropaneAwarded = true;
          toast("+ a propane torch (dented).\nsomebody buried this.\n(equipped.)", 4400);
          feedPost("found a torch in a dumpster. the dumpster knew.", '@crackheadcent');
        } else {
          toast("a torch. you already have one.\nyou close the lid.", 2000);
        }
      }
      dumpster.looted = true;
      dumpster.diveCdT = 90000; // v13 wave 6 — 90s cooldown per dumpster after a dig
      state.counters.dumpDives = (state.counters.dumpDives||0) + 1;
      saveGame();
    }
  })).concat([{label:'climb out.', action:()=>{ dumpster.looted = true; toast('you climb out.\nno one saw.\n(some saw.)'); }}]));
}

export function kickTrashCan(can) {
  can.cdT = 60000;
  can.tipT = 200;
  can.rotPulse = 200;
  audio.kick ? audio.kick() : audio.hit();
  state.shake = Math.max(state.shake, 3);
  const r = Math.random();
  if (r < 0.5) {
    // cash $2-5
    const amt = 2 + Math.floor(Math.random()*4);
    P.cash += amt;
    audio.coin();
    toast("- nothing\n+ $"+amt+"\nthe can falls. coins spill.", 2200);
    // particles for cash poof
    for (let i=0;i<6;i++) particles.push({x:can.x, y:can.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-1, life:600, c:'#e8c040', sz:3, glow:true});
  } else if (r < 0.7) {
    // junk
    P.inventory.push({id:'junk', n:'a piece of junk', q:1});
    toast("+ a piece of junk.\npete will take it. for one dollar.", 2400);
  } else if (r < 0.8) {
    // food (10% bonus drop)
    P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});
    toast("+ a can of food (unmarked).\nthe label is in a language.\nthe language is not yours.", 2600);
  } else {
    // rats
    toast("the rats are upset. they have lives.", 2000);
    for (let i=0;i<8;i++) particles.push({x:can.x+(Math.random()-.5)*16, y:can.y, vx:(Math.random()-.5)*4, vy:-Math.random()*2-0.5, life:700, c:'#181010', sz:2});
  }
  saveGame();
}

export function answerPublicPhone() {
  state.phonePropRingT = 0;
  state.publicPhoneAnswered = (state.publicPhoneAnswered||0) + 1;
  audio.dialogue();
  const line = PUBLIC_PHONE_LINES[Math.floor(Math.random()*PUBLIC_PHONE_LINES.length)];
  toast("📞 PUBLIC PHONE\n\n"+line.text, 6000);
  if (line.action) line.action();
  if (state.publicPhoneAnswered >= 5) unlockAchievement('phone_booth_prophet');
  saveGame();
}

export function init_ending_interactions() {
  // ---------- ENDING ----------
  
  
  // ---------- INTERACT ----------
  
  
  // ---------- DUMPSTER DIVE ----------
  // v13 wave 6 — distance-from-block biases the loot. far dumpsters can drop a propane torch (rare).
  
  
  // v13 wave 6 — kickable trash. RNG outcome + 60s cooldown + tip-over anim.
  
  
  // v13 wave 6 — answer the public pay phone. randomly picks a PUBLIC_PHONE_LINE.
  
  
  
}

export let DAILY_COUNTER_KEYS, HIDEOUT_DOORS;

export function resetDailyCounters() {
  for (const k of DAILY_COUNTER_KEYS) state.counters[k] = 0;
  // v18 office capacity shares the authoritative dawn path used by world and sleep actions.
  if (state.office) syncOfficeDay();
  if(state.kingdom)syncKingdomForces();
}

export function fireDayEvents() {
  if (!state.flags) state.flags = {};
  if (state.day === 3 && !state.flags.day3Fired)   fireDay3Visit();
  if (state.day === 7 && !state.flags.day7Fired)   fireDay7Silence();
  if (state.day === 14 && !state.flags.day14Fired) fireDay14Inheritance();
  if (state.day === 30 && !state.flags.day30Fired) fireDay30Bus();
}

export function rehydrateDay30Bus() {
  if (!state.flags) return;
  if (!state.flags.day30Fired || state.flags.busTaken || state.flags.busRefused) return;
  if (runtime.npcs.find(n => n.id === 'bus_driver')) return;
  // re-run fireDay30Bus without re-firing the broadcast, by temporarily clearing the flag and restoring.
  state.flags.day30Fired = false;
  fireDay30Bus();
}

export function fireDay3Visit() {
  state.flags.day3Fired = true;
  // spawn passive "someone you don't know" near the player. wanders off after the encounter.
  const id = 'day3_visitor_' + Date.now();
  const visitor = {
    id, name: "SOMEONE YOU DON'T KNOW", sprite: 'lurch',
    x: P.x + 80, y: P.y + 30, w: 24, h: 28, color: '#3a3030',
    hp: 30, maxHp: 30, speed: 0.6, hostile: false, archetype: 'passive',
    isDay3Visitor: true, hasFloater: '?',
    interact: (n) => dialogue("SOMEONE YOU DON'T KNOW",
      "someone you don't know.\nthey say:\n\n'i heard about you.'\n\nthat's all they say.",
      [{ label: 'leave.', action: () => { n.wanderOff = true; n.speed = 1.2; n.targetX = WORLD.w + 80; n.targetY = n.y; }}]),
  };
  visitor.x = Math.max(40, Math.min(WORLD.w - 40, visitor.x));
  visitor.y = Math.max(40, Math.min(WORLD.h - 40, visitor.y));
  runtime.npcs.push(visitor);
  toast("someone you don't know is on the block today.\nthey are not moving.\nthey are watching.", 4200);
  feedPost("someone was on the block today. someone was watching.", '@crackheadcent');
  saveGame();
}

export function fireDay7Silence() {
  state.flags.day7Fired = true;
  state.flags.silenceUntilT = Date.now() + 4 * 60 * 1000; // 4 in-game minutes (real-time, since dayTime is real-time)
  toast("the radio is off.\nthe phones are off.\nthe city is listening to something.", 5400);
  // we don't broadcast or post — that's the point.
  saveGame();
}

export function fireDay14Inheritance() {
  state.flags.day14Fired = true;
  // spawn a $500 pile in player's current zone area (near player, jittered, clamped to world)
  const px = P.x + (Math.random()-.5) * 320;
  const py = P.y + (Math.random()-.5) * 320;
  runtime.cashPiles.push({
    id: 'cp_inheritance_' + Date.now(),
    x: Math.max(40, Math.min(WORLD.w-40, px)),
    y: Math.max(40, Math.min(WORLD.h-40, py)),
    amt: 500, isInheritance: true, collected: false,
  });
  toast("something arrived today.\nyou don't know what.\nyou will, when you find it.", 4200);
  saveGame();
}

export function fireDay30Bus() {
  state.flags.day30Fired = true;
  if (state.flags.busTaken || state.flags.busRefused) return; // already resolved
  // bus stop is where pinky stands (per VENDOR_INDEX_META). spawn the driver a few tiles south.
  let bx = 1330, by = 1260;
  const driver = {
    id: 'bus_driver', name: 'THE BUS DRIVER', sprite: 'lurch',
    x: bx, y: by, w: 24, h: 28, color: '#1a2a3a',
    hp: 60, maxHp: 60, speed: 0, hostile: false, archetype: 'passive',
    isBusDriver: true, hasFloater: '?',
    interact: (n) => dialogue('THE BUS DRIVER',
      "the bus is here.\nit hasn't been here in a while.\nthe driver looks at you.\n\nare you getting on?",
      [
        { label: 'yes. get on the bus.', action: () => takeTheBus() },
        { label: 'no. not today.', action: () => {
          state.flags.busRefused = true;
          const idx = runtime.npcs.findIndex(x => x.id === 'bus_driver'); if (idx >= 0) runtime.npcs.splice(idx, 1);
          toast("the bus leaves.\nit doesn't come back.\nthat was your chance.", 5200);
          feedPost("the bus left. someone watched it leave.", '@crackheadcent');
          saveGame();
        }},
      ]),
  };
  runtime.npcs.push(driver);
  toast("a bus is at the stop.\nit hasn't been there in a while.\nthe driver is looking at you.", 5400);
  feedPost("the bus is back. it does not come back often.", '@crackheadcent');
  saveGame();
}

export function takeTheBus() {
  state.flags.busTaken = true;
  const driverIdx=runtime.npcs.findIndex(n=>n.id==='bus_driver');if(driverIdx>=0)runtime.npcs.splice(driverIdx,1);
  unlockAchievement('the_bus');
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  t.innerHTML = `
    <h1 style="color:#6080a0;font-size:32px">THE BUS</h1>
    <div class="sub">you got on the bus.<br>the bus left.<br>you survived rock bottom.<br>the bus has a destination. it has not told you.</div>
    <div class="sub" style="margin-top:14px;opacity:.6">days: ${state.day} · rocks smoked: ${P.lifetime.rocksSmoked||0} · cred: ${P.cred|0}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum stayed</div>`;
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryEnterOffice(){
  const d=OFFICE_DOOR,dx=(P.x+P.w/2)-(d.x+d.w/2),dy=(P.y+P.h/2)-(d.y+d.h/2);
  if(dx*dx+dy*dy>=44*44)return false;
  if(officeOwned())openOffice();
  else dialogue('THE OFFICE','the key does not fit.\nthe door has one lock and three opinions.\nthe leasing guy is standing somewhere in the lot.',[
    {label:'look toward the leasing guy.',action:()=>toast('east side of the lot.\nclipboard. key ring. no urgency.',2200)},
    {label:'leave.',action:()=>{}},
  ]);
  return true;
}

export function officeUpgradeCount(){const o=state.office||freshOfficeState();return OFFICE_UPGRADE_DEFS.filter(d=>o.upgrades&&o.upgrades[d.id]).length;}

export function openOffice(){
  const o=ensureOfficeState();syncOfficeDay();updateOfficeMilestones();maybeUnlockKingdom(false,true);syncKingdomQuests();
  const claims=claimedDistrictIds().length,cap=officeDailyCap(),opts=[];
  if(o.claimJob&&o.claimJob.stage==='file'){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
    opts.push({label:can?'file '+d.name.toLowerCase()+'. $'+cost+' + 1 copper.':'filing needs $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openOffice();}});
  }
  if(o.workJob&&o.workJob.stage==='file'){
    const capBlocked=o.workToday>=cap;
    opts.push({label:capBlocked?'daily ledger closed. inspected order waits for morning.':'file work order '+o.workJob.serial+'. collect the net.',disabled:capBlocked,action:()=>{fileOfficeWork();openOffice();}});
  }
  opts.push({label:o.upgrades.desk?(o.claimJob?'open the active claim file.':'open district claims. ('+claims+'/'+CLAIM_SITES.length+')'):'district claims need a desk.',disabled:!o.upgrades.desk,action:()=>openClaimLedger(0)});
  const workLabel=!o.upgrades.radio?'work orders need a radio.'
    :o.workJob?'work order '+o.workJob.serial+' is '+o.workJob.stage+'.'
    :!claims?'work orders need one claimed district.'
    :o.workToday>=cap?'work orders closed today. ('+o.workToday+'/'+cap+')'
    :'take a work order. ('+o.workToday+'/'+cap+' filed today)';
  opts.push({label:workLabel,disabled:!o.upgrades.radio||!!o.workJob||!!o.claimJob||!claims||o.workToday>=cap,action:()=>{startOfficeWork();}});
  if(state.kingdom&&state.kingdom.stage!=='locked'){
    opts.push({label:state.kingdom.stage==='summons'?'open the hostile correspondence.':'open the CURB WAR ledger.',action:()=>openKingdomLedger()});
  }
  opts.push({label:'look at office upgrades. ('+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+')',action:()=>openOfficeUpgrades()});
  opts.push({label:o.upgrades.locker?'open the chained locker.':'locker not installed.',disabled:!o.upgrades.locker,action:()=>openHideoutChest('office')});
  opts.push({label:o.upgrades.cot?'use the cot.':'cot not installed.',disabled:!o.upgrades.cot,action:()=>openOfficeCot()});
  const rerollBlocked=!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract();
  opts.push({label:!o.upgrades.route_board?'route board not installed.':o.rerollDay===state.day?'route board used today.':'replace the current block route. (no payout)',disabled:rerollBlocked,action:()=>rerollBlockRouteAtOffice()});
  opts.push({label:'leave the office.',action:()=>{}});
  dialogue('THE OFFICE','one room. one lock. '+claims+' district'+(claims===1?'':'s')+' entered in pen.\nupgrades: '+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+'. orders filed: '+o.jobsCompleted+'.\nthe smell has seniority.',opts);
}

export function openOfficeUpgrades(){
  const o=ensureOfficeState();
  const opts=OFFICE_UPGRADE_DEFS.map(d=>{
    const owned=o.upgrades[d.id],can=P.cash>=d.cash&&P.copper>=d.copper;
    const price='$'+d.cash+(d.copper?' + '+d.copper+' copper':'');
    return {label:owned?'✓ '+d.name+' installed.':d.name+' · '+price+' · '+d.desc,disabled:owned||!can,action:()=>{purchaseOfficeUpgrade(d.id);openOfficeUpgrades();}};
  });
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('OFFICE IMPROVEMENTS','a legal pad is taped to the wall.\nthe legal pad is not legal advice.\ncash $'+P.cash+' · pure copper '+P.copper+'.',opts);
}

export function openClaimLedger(page=0){
  const o=ensureOfficeState();if(!o.upgrades.desk){openOffice();return;}
  if(o.claimJob){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],stage=o.claimJob.stage;
    const lines=stage==='survey'?d.survey.task:stage==='file'?'survey attached. filing fee pending.':d.sign.task;
    const opts=[];
    if(stage==='file'){
      const cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
      opts.push({label:can?'file now. $'+cost+' + 1 copper.':'need $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openClaimLedger(0);}});
    }
    opts.push({label:stage==='install'?'cancel the claim. (no refund)':'cancel the claim.',action:()=>{cancelDistrictClaim();openOffice();}});
    opts.push({label:'back to the office.',action:()=>openOffice()});
    dialogue('ACTIVE CLAIM · '+d.name,'stage: '+stage+'.\n'+lines,opts);return;
  }
  if(o.workJob){dialogue('DISTRICT CLAIMS','the desk is occupied by work order '+o.workJob.serial+'.\nfinish the order before opening another file.',[{label:'back.',action:()=>openOffice()}]);return;}
  const pageSize=7,maxPage=Math.floor((CLAIM_SITES.length-1)/pageSize);page=Math.max(0,Math.min(maxPage,page));
  const slice=CLAIM_SITES.slice(page*pageSize,page*pageSize+pageSize),opts=slice.map(d=>{
    const why=claimGateReason(d),owned=(state.districtClaims||{})[d.id];
    return {label:owned?'✓ '+d.name+' · entered in pen.':why?d.name+' · '+why:d.name+' · open a survey file.',disabled:!!why,action:()=>selectDistrictClaim(d.id)};
  });
  if(page<maxPage)opts.push({label:'next ledger page.',action:()=>openClaimLedger(page+1)});
  if(page>0)opts.push({label:'previous ledger page.',action:()=>openClaimLedger(page-1)});
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('DISTRICT CLAIMS · PAGE '+(page+1),'the form recognizes signs, curbs, and faction permission.\nstreet '+((P.faction&&P.faction.street)||0)+' · scrap '+((P.faction&&P.faction.scrap)||0)+' · spiritual '+((P.faction&&P.faction.spiritual)||0)+'.',opts);
}

export function openOfficeCot(){
  const o=ensureOfficeState(),powered=!!o.upgrades.generator;
  dialogue('THE COT','the cot is one inch shorter than you.\nthis has been entered as adequate.',[
    {label:'rest 30 minutes. (+'+(powered?18:10)+' hp'+(powered?' · +5 brain':'')+' · -1 wanted)',action:()=>{P.hp=Math.min(P.maxHp,P.hp+(powered?18:10));P.brain=Math.min(100,P.brain+(powered?5:0));P.wanted=Math.max(0,P.wanted-1);toast('the generator clicks.\nthe cot files no complaint.',2400);saveGame();}},
    {label:'sleep until morning. (+55 hp · +25 brain · +15 shakes)',action:()=>sleepAtOffice()},
    {label:'back to the office.',action:()=>openOffice()},
  ]);
}

export function sleepAtOffice(){
  const target=state.dayTime>0.3?1.3:0.3;state.dayTime=target;
  if(state.dayTime>=1){state.dayTime-=1;state.day++;P.lifetime.dayCount=state.day;rollWeather();resetDailyCounters();rollHustles();fireDayEvents();if(state.day>=7)unlockAchievement('tuesday_again');}
  const powered=!!(state.office&&state.office.upgrades.generator);
  P.hp=Math.min(P.maxHp,P.hp+55);P.brain=Math.min(100,P.brain+25+(powered?5:0));P.shakes=Math.min(100,P.shakes+15);P.wanted=Math.max(0,P.wanted-2);
  toast('you slept at the office.\nthe office opened before you did.\nthe day is the next day.',3200);saveGame();
}

export function rerollBlockRouteAtOffice(){
  const o=ensureOfficeState();if(!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract())return false;
  o.rerollDay=state.day;const last=validBlockRoute(state.blockRoute)?state.blockRoute.lastStopId:'';rollBlockRoute(false,last);toast('the old sheet goes under the desk.\nit receives no payout.',2200);saveGame();return true;
}

export function hideoutOwned(kind) {
  if (!state.flags) return false;
  return kind === 'scrap' ? !!state.flags.scrapHideoutOwned : !!state.flags.momHideoutOwned;
}

export function tryEnterHideout() {
  for (const kind of ['scrap', 'mom']) {
    if (!hideoutOwned(kind)) continue;
    const d = HIDEOUT_DOORS[kind];
    const ddx = (P.x + P.w/2) - (d.x + d.w/2);
    const ddy = (P.y + P.h/2) - (d.y + d.h/2);
    if (ddx*ddx + ddy*ddy < 40*40) { openHideout(kind); return true; }
  }
  return false;
}

export function openHideout(kind) {
  const isMom = kind === 'mom';
  const title = isMom ? "MOM'S COUCH" : "THE SHED";
  const intro = isMom
    ? "the apartment is warm.\nben is at work.\nthe couch is cleared.\nyou recognize this couch."
    : "the shed smells like dust and old grease.\nthere is a chest in the corner.\nthere is a cot.\nthe door locks from the inside.";
  dialogue(title, intro, [
    { label: "open the chest. (stash survives death.)", action: () => openHideoutChest(kind) },
    { label: isMom ? "rest 30 minutes. (+12 hp · -1 wanted)" : "rest 30 minutes. (+8 hp · -1 wanted)",
      action: () => {
        P.hp = Math.min(P.maxHp, P.hp + (isMom ? 12 : 8));
        P.wanted = Math.max(0, P.wanted - 1);
        toast("you sit down.\nthe walls have nothing to say.\n" + (isMom ? '+ 12 hp · - 1 wanted' : '+ 8 hp · - 1 wanted'), 2800);
        saveGame();
      }
    },
    { label: "sleep until morning. advances a day.", action: () => {
      const target = state.dayTime > 0.3 ? 1.3 : 0.3;
      state.dayTime = target;
      if (state.dayTime >= 1) { state.dayTime -= 1; state.day++; P.lifetime.dayCount = state.day; rollWeather(); resetDailyCounters(); rollHustles(); fireDayEvents(); }
      P.hp = Math.min(P.maxHp, P.hp + (isMom ? 60 : 50));
      P.brain = Math.min(100, P.brain + (isMom ? 30 : 25));
      P.shakes = Math.min(100, P.shakes + 15);
      P.wanted = Math.max(0, P.wanted - 2);
      adjustFaction(isMom ? 'spiritual' : 'scrap', 1);
      toast("you slept.\nyou are still here.\nthe day is the next day.", 3000);
      saveGame();
    }},
    isMom ? { label: "use the apartment phone. (skip the next ambient call.)", action: () => {
      state.phoneT = 90000 + Math.random()*150000;
      toast("the phone goes back on the hook.\nben uses this phone.\nben is at work.", 2400);
    }} : null,
    { label: "leave.", action: () => {} },
  ].filter(Boolean));
}

export function openHideoutChest(kind) {
  // chest is shared across both hideouts (one stash). simpler + matches the "your stuff" mental model.
  if (!state.hideoutStash) state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
  const s = state.hideoutStash;
  dialogue("THE CHEST",
    "metal box. dented. heavy.\nin the chest:\n  rocks: " + s.rocks + "\n  pure copper: " + s.copper + "\n  cash: $" + s.cash + "\n  items: " + (s.items.length||0),
    [
      { label: P.rocks>0 ? "deposit 1 rock. (chest: " + s.rocks + ")" : "deposit a rock. (you have none.)",
        disabled: P.rocks<=0, action: () => { P.rocks--; s.rocks++; toast("- 1 rock · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.rocks>0 ? "withdraw 1 rock. (chest: " + s.rocks + ")" : "withdraw a rock. (chest empty.)",
        disabled: s.rocks<=0, action: () => { s.rocks--; P.rocks++; toast("← chest · + 1 rock", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.copper>0 ? "deposit 1 copper. (chest: " + s.copper + ")" : "deposit copper. (you have none.)",
        disabled: P.copper<=0, action: () => { P.copper--; s.copper++; toast("- 1 copper · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.copper>0 ? "withdraw 1 copper. (chest: " + s.copper + ")" : "withdraw copper. (chest empty.)",
        disabled: s.copper<=0, action: () => { s.copper--; P.copper++; toast("← chest · + 1 copper", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.cash>=10 ? "deposit $10. (chest: $" + s.cash + ")" : "deposit $10. (short.)",
        disabled: P.cash<10, action: () => { P.cash -= 10; s.cash += 10; toast("- $10 · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.cash>=10 ? "withdraw $10. (chest: $" + s.cash + ")" : "withdraw $10. (chest short.)",
        disabled: s.cash<10, action: () => { s.cash -= 10; P.cash += 10; toast("← chest · + $10", 1400); saveGame(); openHideoutChest(kind); }},
      { label: "close the chest.", action: () => kind==='office' ? openOffice() : openHideout(kind) },
    ]);
}

export function init_daily_hideouts() {
  // ---------- v13 wave 6.5 — daily counter reset ----------
  // called from updateWorld when state.day increments. iterates over the accumulating
  // "today" counters and zeros them. the per-day "*Day" counters (kombuchaAskDay etc)
  // self-reset via "=== state.day" comparison, so they don't need explicit reset.
  DAILY_COUNTER_KEYS = [
    'stripeFencedToday', // exploit 3a (stripe fence price ladder)
    'barbPacketsToday',  // exploit 3b (barb supply cap)
    'peteCashToday',     // audit (pete daily $200 cap)
    'heistsToday',       // audit (heist daily cap = 3)
  ];
  
  
  // ---------- v13 wave 7 — day-specific scripted events ----------
  // fire at most once per save, guarded by state.flags.dayNFired booleans.
  
  // re-spawn the bus driver on reload if day 30 fired but resolution didn't.
  
  
  
  
  
  
  
  
  
  
  
  
  // ---------- v13 wave 7 — hideouts ----------
  // scrap-yard hideout: door at (520, 200) — back corner of scrap yard, behind yuri.
  // mom's apartment hideout: door at (1230, 1180) — marketplace area, close to mom (mom is at ~1280,1180).
  // E within 40px while owned = openHideout(kind). interactive dialogue with chest, rest, sleep, leave.
  
  
  
  
  
  
  
  
  
  HIDEOUT_DOORS = {
    scrap: { x: 520, y: 200, w: 24, h: 32 },
    mom:   { x: 1230, y: 1180, w: 24, h: 32 },
  };
  
  
  
  
  
  
}

export let WEAPONS;

export async function startHeist() {
  // v13 wave 6.5 — heist has a daily cap (3/day). closes the conductor-arbitrage grind path.
  // 3 heists × 2-4 copper × ($90 / 3 copper) caps the conductor floor at ~$270 / day.
  if ((state.counters.heistsToday||0) >= 3) {
    dialogue('ABANDONED BUILDING', "the door is half off.\nthere is no air coming out.\nbrutus jr. is awake and watching the door.\nnot tonight.", [
      { label: 'come back tomorrow.', action: () => { state.mode = 'playing'; }},
    ]);
    return;
  }
  state.counters.heistsToday = (state.counters.heistsToday||0) + 1;
  state.mode = 'heist';
  await heistStage(1);
}

export async function heistStage(stage) {
  return new Promise(resolve => {
    if (stage === 1) {
      dialogue('ABANDONED BUILDING', "the door is half off.\nbrutus jr. is inside. he is asleep.\nyou hear pipes singing in b flat.", [
        { label: 'sneak past brutus jr.', action: () => {
          if (Math.random()<0.7) { toast('you sneak. brutus jr. dreams of a tennis ball.'); heistStage(2); }
          else { toast('BRUTUS JR. WAKES UP. he is a puppy. he is FURIOUS.'); P.hp -= 10; if (P.hp<=0) die(); else heistStage(2); }
          resolve();
        }},
        { label: 'pick the side door lock. (4-pin lockpick)', action: () => {
          startLockpickMini(
            () => {
              toast("CLICK. the door opens.\nbrutus jr. dreams uninterrupted.\nyou are inside.");
              audio.glassBreak();
              heistStage(2); resolve();
            },
            () => {
              toast("you give up on the lock.\nthe door is harder than it looks.\nyou take the front door.");
              if (Math.random()<.5) { P.hp -= 12; toast('BRUTUS JR. WAS WAITING.\n- 12 hp', 1800); }
              if (P.hp<=0) die(); else heistStage(2); resolve();
            }
          );
        }},
        { label: P.inventory.find(i=>i.id==='soap') ? 'throw soap as distraction.' : "throw something (you have nothing useful).", disabled: !P.inventory.find(i=>i.id==='soap'), action: () => {
          P.inventory = P.inventory.filter(i=>i.id!=='soap');
          toast('brutus jr. licks the soap. is consumed.'); heistStage(2); resolve();
        }},
        { label: P.cash>=3 ? 'pay $3 for a chimichanga distraction.' : "you don't have $3.", disabled: P.cash<3, action: () => {
          P.cash -= 3; toast("the chimichanga is talking.\nbrutus jr. listens."); heistStage(2); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else if (stage === 2) {
      dialogue('THE COPPER PIPES', "the pipes hum.\nin b flat.\nthey are waiting.", [
        { label: 'strip them.', action: () => {
          const got = 2 + Math.floor(Math.random()*3);
          P.copper += got; audio.glassBreak();
          state.counters.copperStripped += got;
          if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
          toast(`+ ${got} pure copper\nthe singing stops.\nyou feel watched.`);
          if (!state.quests.copper_sings.done) { state.quests.copper_sings.done = true; questToast('THE COPPER SINGS'); }
          heistStage(3); resolve();
        }},
        { label: 'listen to them sing.', action: () => {
          P.brain = Math.min(100, P.brain+8); toast('+ 8 brain\nthey know your name now.');
          heistStage(3); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else {
      dialogue('GETAWAY', "the floor creaks.\nthere is a window.\nthere is also a door.", [
        { label: 'window. fast.', action: () => {
          if (Math.random()<0.8) { toast('you jump. the landing is bad but legal.'); P.hp -= 3; }
          else { toast('the glass breaks. so does your dignity.'); P.hp -= 12; audio.glassBreak(); P.wanted = Math.min(3,P.wanted+1); }
          if (P.hp<=0) die();
          state.mode = 'playing'; saveGame(); resolve();
        }},
        { label: 'door. slow.', action: () => {
          if (Math.random()<0.5) { toast('a cop is waiting on the other side.\nyou run.'); P.wanted = Math.min(3,P.wanted+2); }
          else { toast('you walk out like you own the place.\n(you do not.)'); }
          state.mode = 'playing'; saveGame(); resolve();
        }},
      ]);
    }
  });
}

export function pickupWeapon(id) {
  if (!WEAPONS[id]) return;
  P.weapon = id;
  toast('+ '+WEAPONS[id].n+'\n(equipped.)');
  feedPost("picked up " + WEAPONS[id].n + ". things are escalating.", '@crackheadcent');
}

export function startRhythmMini() {
  state.mode = 'dialogue';
  const arrows = ['↑','↓','←','→'];
  const keyMap = { '↑':'w','↓':'s','←':'a','→':'d' };
  const seq = [];
  for (let i=0;i<8;i++) seq.push(arrows[Math.floor(Math.random()*4)]);
  let idx = 0, hits = 0;
  const renderRhythm = () => {
    const opts = arrows.map(a => ({
      label: a + ' ' + (a===seq[idx]?'(now!)':''),
      action: () => {
        if (a === seq[idx]) { hits++; }
        idx++;
        if (idx >= seq.length) {
          const pay = hits * 3;
          P.cash += pay; P.cred += Math.floor(hits/2);
          audio.coin();
          toast('· '+hits+'/8 hits ·\n+ $'+pay+' · + '+Math.floor(hits/2)+' cred\nthe crowd was three people.\ntwo of them were waiting for the bus.', 3000);
          if (hits === 8) { unlockAchievement('not_a_phase'); broadcastNews("KARAOKE PERFECTION REPORTED. WITNESSES UNAVAILABLE."); }
          saveGame();
        } else {
          renderRhythm();
        }
      }
    }));
    opts.push({ label: 'forfeit. (you sound tired)', action: () => { toast("you stop singing.\nthe crowd stays."); }});
    dialogue('· '+(idx+1)+' / '+seq.length+' ·', "next: " + seq[idx] + "\n\nyour line:\n" + seq.slice(0, idx).map((x,i)=> i<idx ? x : '').join(' '), opts);
  };
  renderRhythm();
}

export function startLockpickMini(onSuccess, onFail) {
  state.mode = 'dialogue';
  // 4-pin lock — random target indices, player guesses by pressing 1-4 in any order
  const pins = [false,false,false,false];
  const target = [1,2,3,4].sort(()=>Math.random()-.5);
  let nextPin = 0;
  const renderLP = () => {
    const display = pins.map(p => p ? '[●]' : '[ ]').join(' ');
    dialogue('LOCKPICK', "the lock has 4 pins.\npush them in the right order.\n\n" + display + "\n\n(it makes a small click when you guess right.)", [
      { label: '1. set pin 1', action: () => { tryPin(1); }},
      { label: '2. set pin 2', action: () => { tryPin(2); }},
      { label: '3. set pin 3', action: () => { tryPin(3); }},
      { label: '4. set pin 4', action: () => { tryPin(4); }},
      { label: 'give up.', action: () => { onFail && onFail(); }},
    ]);
  };
  const tryPin = (n) => {
    if (target[nextPin] === n) {
      pins[n-1] = true;
      audio.pickup();
      nextPin++;
      if (nextPin >= 4) { onSuccess && onSuccess(); return; }
      renderLP();
    } else {
      audio.hurt();
      // wrong — reset all pins and lose 1 brain
      pins.forEach((_,i) => pins[i] = false);
      nextPin = 0;
      P.brain = Math.max(0, P.brain - 2);
      toast("CLUNK. all pins reset.\n- 2 brain", 1400);
      renderLP();
    }
  };
  renderLP();
}

export function spawnBrutusOlder() {
  if (state.brutusOlderActive) return;
  state.brutusOlderActive = true;
  // v13 wave 7 — street loved: brutus older spawns but does not aggro unprovoked.
  const streetLoved = factionTier(P.faction ? P.faction.street : 0) === 'loved';
  const b = {
    id:'brutus_older', name:'BRUTUS THE OLDER', sprite:'brutus',
    x: P.x + 100, y: P.y + 100,
    w: 48, h: 36, color:'#8a3030',
    hp:200, maxHp:200, speed:2.4, dmg:14,
    hostile: !streetLoved, aggro: !streetLoved, isBossB:true,
    showHp:true, attackCd:0, scale: 1.5,
    // v13 wave 5 — charger from the start; grabber added at phase 3 via state.brutusOlderPhase
    archetype: streetLoved ? 'passive' : 'charger_older',
    addsT: 0,
  };
  b.x = clamp(b.x, 40, WORLD.w-80);
  b.y = clamp(b.y, 40, WORLD.h-60);
  runtime.npcs.push(b);
  state.brutusOlderNPC = b;
  audio.bossRoar();
  state.flash = 1; state.flashColor = 'rgba(160,40,40,.4)';
  state.shake = 14;
  if (streetLoved) {
    toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe sniffs once. he sits.\n(the block knows you.)", 5400);
    feedPost("the dog came back. he is bigger now. he did not charge.", '@crackheadcent');
  } else {
    toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe is ASCENDED.", 4500);
    feedPost("the dog came back. he is bigger now.", '@crackheadcent');
  }
  broadcastNews("BRUTUS HAS RETURNED. WITNESSES DESCRIBE 'LARGER. REDDER.'");
}

export function blockMenu() {
  const opts = [];
  // v13 wave 4 — soap rocks smoke first (FIFO with the real rocks).
  // looks identical in inventory; the truth comes when you light it.
  const totalRocks = (P.rocks||0) + (P.soapRocks||0);
  opts.push({
    label: totalRocks > 0 ? "smoke a rock. (-1 rock, +18s rocked-up)" : "smoke a rock. (you have none.)",
    disabled: totalRocks <= 0 || P.rockedT > 0,
    action: () => {
      if ((P.soapRocks||0) > 0) {
        // soap rock — no rocked-up effect, no shakes relief, no cred. you knew.
        P.soapRocks--;
        P.lifetime.rocksSmoked++;
        audio.hurt(); audio.glassBreak();
        toast("you smoke it. it's soap.\nyou knew. you smoked it anyway.", 3600);
        feedPost("smoked soap. tasted it. did it again.", '@crackheadcent');
        unlockAchievement('soap_tongue');
        // intro chain still completes — the loop is the loop
        completeIntroSmoke();
        saveGame();
        return;
      }
      P.rocks--; P.rockedT = 18000; P.crashT = 0; P.shakes = Math.max(0, P.shakes-50);
      P.brain = Math.max(0, P.brain-4); P.lifetime.rocksSmoked++;
      P.cred += 1;
      let royalStatic=false;
      if(state.kingdom&&state.kingdom.stage==='anoint'){
        state.kingdom.stage='emperor_gate';state.kingdom.marks=0;royalStatic=true;syncKingdomQuests();
      }
      audio.rockUp();
      state.flash = 1; state.flashColor = 'rgba(232,192,64,.5)';
      toast(royalStatic
        ? '· ROYAL STATIC ·\nthe sun moves. the throne ditch answers.\nbrain -4. shakes -50. emperor available.'
        : '· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50.', royalStatic?4300:2500);
      feedPost("smoked a rock at the block. for the bit.", '@crackheadcent');
      if(royalStatic){broadcastNews('ROYAL STATIC RECEIVED. ONE DITCH ACKNOWLEDGES THE SIGNAL.');feedPost('the rock had a crown in the reception. the ditch is calling.','@blocklog');}
      applyRep({ street: 1, spiritual: -1 }); // wave 7 — smoking real rocks ledger
      // v13 wave 3 — completes the intro chain
      completeIntroSmoke();
      saveGame();
    }
  });
  // v13 wave 3 — open stripe's package "alone, where no one sees" (the block is home)
  if (state.flags && state.flags.hasStripePackage) {
    opts.push({
      label: "open stripe's package. (alone, no one is watching.)",
      action: () => openStripePackage()
    });
  }
  opts.push({
    label: "sleep until morning. (+50 hp · +25 brain · -1 wanted)",
    action: () => {
      // Settle today's crate contract before dawn posts tomorrow's sheet.
      state.counters.slept = (state.counters.slept||0) + 1;
      checkHustles();
      const target = state.dayTime > 0.3 ? 1.3 : 0.3;
      state.dayTime = target;
      if (state.dayTime >= 1) {
        state.dayTime -= 1; state.day++; P.lifetime.dayCount=state.day;
        rollWeather(); resetDailyCounters(); rollHustles(); fireDayEvents();
        if(state.day>=7)unlockAchievement('tuesday_again');
      }
      P.hp = Math.min(P.maxHp, P.hp + 50);
      P.brain = Math.min(100, P.brain + 25);
      P.shakes = Math.min(100, P.shakes + 15);
      P.wanted = Math.max(0, P.wanted - 1);
      audio.coin();
      toast("you sleep on the crate.\nyou dream of a chimichanga that has opinions.\n+50 hp · +25 brain", 3000);
      feedPost("slept on the block. felt like 7 hours. was 14 minutes.", '@crackheadcent');
      saveGame();
    }
  });
  opts.push({
    label: P.supplies > 0 ? `cook a batch. (🧪${P.supplies} → rocks)` : `cook a batch. (you have no packets.)`,
    disabled: (P.supplies||0) <= 0,
    action: () => cookBatchMenu()
  });
  opts.push({
    label: "sit on the crate and think.",
    action: () => sitOnCrate()
  });
  if (P.inventory.find(i => i.id === 'lottery')) {
    opts.push({ label: "scratch the lottery ticket.", action: () => scratchLottery() });
  }
  opts.push({ label: "leave.", action: () => {} });
  dialogue('THE BLOCK', "the milk crate is here. the sky is here.\nyour shakes are " + Math.round(P.shakes) + ". your brain is " + Math.round(P.brain) + ".", opts);
}

export function sitOnCrate() {
  const thoughts = [
    "you sit. the crate accepts you. you remember nothing useful.",
    "you sit. a cloud passes. it does not acknowledge you.\n(+1 cred for the patience.)",
    "you sit. a possum walks by. nods. continues.\nyou are on his route.",
    "you sit. you remember a birthday from 1996.\nit was not yours.",
    "you sit. the milk crate is very old.\nit has seen kings.",
    "you sit. you almost have a thought.\nit leaves.",
  ];
  const t = thoughts[Math.floor(Math.random()*thoughts.length)];
  if (t.includes('+1 cred')) P.cred++;
  toast(t, 4000);
}

export function panhandle() {
  const isDay = !isNight();
  dialogue("THE MARKETPLACE", isDay
    ? "people are walking by.\nthey are pretending you are scenery."
    : "the marketplace is asleep.\nyou could still try.", [
    {
      label: "ask for change. (chance of $1-5)",
      action: () => {
        const r = Math.random();
        const mod = isDay ? 0 : -0.2;
        if (r < 0.45 + mod) {
          const got = 1 + Math.floor(Math.random()*4);
          P.cash += got; audio.coin();
          if (got >= 4) state.counters.bigPan = (state.counters.bigPan||0) + 1;
          toast("+ $"+got+"\na person handed it to you and immediately regretted it.");
        } else if (r < 0.65 + mod) {
          P.cash++; toast("+ $1\nyou were given a single dollar with eye contact you did not consent to.");
        } else if (r < 0.85) {
          toast("a woman gave you advice.\nthe advice was 'have you tried not.'\n(- 1 brain)");
          P.brain = Math.max(0, P.brain - 1);
        } else {
          toast("a man told you to 'get a job.'\nhe has not had one since 2003.\n+1 cred (out of spite)");
          P.cred++;
        }
      }
    },
    {
      label: "perform a song you don't know.",
      action: () => {
        if (Math.random() < 0.4) {
          P.cash += 3; toast("+ $3\nyou hummed. people walked faster. one tipped.");
        } else toast("you hummed. no one tipped.\nyou hum louder. still nothing.\nthe humming was the song.");
      }
    },
    {
      label: "do a card trick you don't know.",
      action: () => {
        if (Math.random() < 0.25) {
          P.cash += 8; P.cred++; toast("+ $8 + 1 cred\nit worked. you don't know how.\nneither does the audience.");
        } else {
          P.wanted = Math.min(3, P.wanted + 1);
          toast("the trick was 'i have the card and now you don't.'\nthis is, in fact, theft.\nwanted +1");
        }
      }
    },
    { label: "leave.", action: () => {} },
  ]);
}

export function scratchLottery() {
  P.inventory = P.inventory.filter(i => i.id !== 'lottery');
  const r = Math.random();
  if (r < 0.01) {
    P.cash += 500; toast("· $500 ·\nyou won. the world is wrong.\nthe ticket combusts.", 4500);
    audio.coin(); broadcastNews("LOCAL MAN WINS $500. REFUSES INTERVIEW.");
    feedPost("won the lottery. immediately spent half of it. on what.", '@crackheadcent');
  } else if (r < 0.15) {
    const win = 5 + Math.floor(Math.random()*15); P.cash += win;
    toast("· $"+win+" ·\na small win. dignity-shaped.", 2500); audio.coin();
  } else {
    toast("nothing. as ever.\nthe ticket smells like a basement.", 2200);
  }
  saveGame();
}

export function init_activities() {
  // ---------- HEIST (simple 3-stage) ----------
  
  
  
  // ---------- WEAPONS ----------
  WEAPONS = {
    fists:        { n:"bare fists",          dmg: 0,  reach: 0,  cd: 280, swing:'arc' },   // baseline
    pipe:         { n:"a length of copper pipe", dmg: 8, reach: 12, cd: 320, swing:'pipe', sings:true },
    brick:        { n:"a brick",              dmg: 12, reach: 6,  cd: 380, swing:'thud' },
    cart_wheel:   { n:"a shopping cart wheel",dmg: 6,  reach: 10, cd: 260, swing:'spin' },
    shoe:         { n:"a shoe (tony's)",      dmg: 10, reach: 14, cd: 340, swing:'sole' },
    baguette:     { n:"a stale baguette",     dmg: 4,  reach: 16, cd: 240, swing:'crumble' },
    microphone:   { n:"a karaoke microphone (just the cord)", dmg: 7, reach: 18, cd: 360, swing:'whip' },
    // v13 wave 3 — stripe's bait knife (possible outcome of opening the package)
    knife:        { n:"a knife (handle taped)",   dmg: 14, reach: 8,  cd: 260, swing:'stab' },
    // v13 wave 6 — drops from smashed bottles + (rare) dumpsters. dmg+8, reach short. it cuts.
    broken_bottle:{ n:"a broken bottle",           dmg: 8,  reach: 6,  cd: 300, swing:'jagged' },
  };
  
  
  
  // ---------- RHYTHM PANHANDLE MINIGAME ----------
  
  
  // ---------- LOCKPICK MINIGAME ----------
  
  
  // ---------- BRUTUS OLDER (boss 2) ----------
  
  
  
  
  
  // ---------- PANHANDLE ----------
  
  
  
  
  
}

export let MOVEMENT_KEYS, INPUT_RELEASE_HOOKS, titleLoadPending;

export async function loadFromTitle() {
  if(state.mode!=='title'||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    const ok=await loadGame();
    if(ok)startGame(true);else toast('no save.',1200);
  }finally{titleLoadPending=false;}
}

export async function continueAfterEnding(){
  if(state.mode!=='title'||!state.endingContinue||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    if(state.endingSavePromise)await state.endingSavePromise;
    state.endingContinue=false;state.endingSavePromise=null;
    releaseAllInput();document.getElementById('title').classList.add('hide');state.mode='playing';
    toast('the block is still here.\nthe clipboard has another sheet.',2400);
  }finally{titleLoadPending=false;}
}

export function releaseAllInput() {
  state.keys.clear();
  state.stickX=0; state.stickY=0; state.stickMag=0;
  for(const release of INPUT_RELEASE_HOOKS)release();
  document.querySelectorAll('#mobile-ctrls .active').forEach(el=>el.classList.remove('active'));
}

export function init_keyboard() {
  // ---------- INPUT ----------
  // Physical movement keys are latched by keydown/keyup. Auto-repeat is deliberately not
  // used as a heartbeat: most operating systems repeat only the newest key in a chord.
  MOVEMENT_KEYS = new Set(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright','shift']);
  INPUT_RELEASE_HOOKS=[];
  titleLoadPending=false;
  
  
  window.addEventListener('keydown', async (e) => {
    const k = e.key.toLowerCase();
    // If a modal/focus safety path cleared a still-physical key, browser repeat may not
    // resurrect it. Releasing and pressing again creates the fresh non-repeat keydown.
    if (e.repeat && !state.keys.has(k) && MOVEMENT_KEYS.has(k)) {
      return;
    }
    // title screen
    if (state.mode === 'title') {
      if (k === ' ' || k === 'spacebar') { e.preventDefault(); audio.init(); if(state.endingContinue)await continueAfterEnding();else startGame(false); return; }
      if (k === 'l') { await loadFromTitle(); return; }
      return;
    }
    // global
    if (k === 'm') { audio.muted = !audio.muted; toast(audio.muted?'muted.':'unmuted.', 800); return; }
    if (k === 'escape') {
      if (state.mode === 'dialogue') closeDialogue();
      else if (state.mode === 'inv' || state.mode === 'quest') closePanel();
      else if (state.mode === 'cookmini') { e.preventDefault(); bailHeatMini(); }
      return;
    }
    // v13 wave 4 — heat minigame: SPACE / 1 locks the needle
    if (state.mode === 'cookmini') {
      if (k === ' ' || k === 'spacebar' || k === '1' || k === 'enter') {
        e.preventDefault();
        lockHeatMini();
      }
      return;
    }
    if (state.mode === 'dialogue') {
      // 1-9 select dialogue option
      const n = parseInt(k);
      if (n>=1 && n<=9 && activeDialogue && activeDialogue.opts[n-1]) {
        const o = activeDialogue.opts[n-1];
        if (!o.disabled) { audio.dialogue(); closeDialogue(); o.action && o.action(); }
      }
      return;
    }
    if (k === 'i') {
      if (state.mode==='inv') { closePanel(); }
      else if (state.mode==='quest') { closePanel(); state.mode='inv'; renderInventory(); }
      else { releaseAllInput(); state.mode='inv'; renderInventory(); }
      return;
    }
    if (k === 'q') {
      if (state.mode==='quest') { closePanel(); }
      else if (state.mode==='inv') { closePanel(); state.mode='quest'; renderQuests(); }
      else { releaseAllInput(); state.mode='quest'; renderQuests(); }
      return;
    }
    if (k === 'p') {
      phoneState.visible = !phoneState.visible;
      renderPhone();
      return;
    }
    // play mode keys
    if (state.mode !== 'playing') return;
    if (MOVEMENT_KEYS.has(k)) e.preventDefault();
    state.keys.add(k);
    // v13 wave 5 — stun gates all action inputs (SPACE attack, E interact). Movement is gated
    // in updateWorld; menu/inv/mute keys above still work so the player can pause/leave.
    if (P.stunT > 0) return;
    if (k === ' ' || k === 'spacebar') { e.preventDefault(); playerAttack(); }
    if (k === 'e') tryInteract();
    if (k === 'f') {
      if (state.tweakerCdT > 0 || P.brain <= 0) {
        if (P.brain <= 0) toast('your brain has nothing left to give.', 1500);
      } else if (state.tweakerT === 0) {
        state.tweakerT = 3000; state.tweakerCdT = 6000;
        // small cost on activation
        P.brain = Math.max(0, P.brain - 5);
      }
    }
  });
  window.addEventListener('keyup', (e) => {
    const k = e.key.toLowerCase();
    state.keys.delete(k);
  });
  
  // Focus loss is authoritative release evidence for both keyboard and analog input.
  
  window.addEventListener('blur', releaseAllInput);
  document.addEventListener('visibilitychange', () => { if (document.hidden) releaseAllInput(); });
  
  
}

export function startGame(loaded) {
  releaseAllInput();
  state.endingContinue=false;state.endingSavePromise=null;
  document.getElementById('title').classList.add('hide');
  if (!loaded) {
    // fresh save state
    state.cashPilesCollected = new Set();
    state.achievements = new Set();
    P.lifetime.routesCompleted = 0;
    P.lifetime.officeJobs = 0;
    P.lifetime.territoriesClaimed = 0;
    P.lifetime.pretendersDefeated = 0;
    state.blockRoute = null;
    state.office = freshOfficeState();
    state.districtClaims = Object.create(null);
    state.kingdom = freshKingdomState();
    state.kingdomBattle=null;state.bossActive=false;state.bossKind='';state.bossNPC=null;
    state.loadedNpcDeaths=null;
    state.counters = {
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0, pigeonTrade: 0,
      peteSold: 0, alleyKills: 0, dumpDives: 0, slept: 0,
      tacosEaten: 0, laundryDone: 0, bigPan: 0,
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0, introCashEarned: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      // v13 wave 6.5 — economy gates
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      // v13 wave 8a — philosopher daily spiritual gate
      philosopherRepDay: 0,
      gutterInventoryDay: 0,
    };
    Object.values(state.quests).forEach(q => { q.done = false; if (q.available === true) q.available = q.intro?undefined:false; });
    state.day = 1; state.dayTime = 0.35;
    state.weather = 'clear';
    state.combo = 0;
    P.equip = { shoes:null, hat:null, coat:null };
    P.cartMounted = false;
    P.hasPossum = false;
    state.hustles = null;
    // v13 wave 3 — fresh save state for discoverability + intro chain
    state.metVendors = new Set();
    state.flags = {
      introDone: false, momIntroFired: false, hasStripePackage: false,
      stripeBetrayed: false, daveHasCrossword: false, hasCrossword: false, crownSpotIdx: -1,
      // v13 wave 7 — day events + hideouts
      day3Fired: false, day7Fired: false, day14Fired: false, day30Fired: false,
      day14Collected: false, busTaken: false, busRefused: false,
      silenceUntilT: 0,
      scrapHideoutOwned: false, momHideoutOwned: false,
      momRentDay: 0, scrapLoanDay: 0, momProudCallDay: 0,
      // v13 wave 8a — fresh saves get the first-entry toasts as they discover the new zones.
      trainYardEntered: false, parkEntered: false, skidRowEntered: false, oldSchoolEntered: false,
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      trainHopperTalkedTo: false,
      priceGuyDay: 0, priceGuyVisits: 0,
      parkNightCashDay: 0,
      // v13 wave 8b — loved ambient + bus pass day-stamps
      lovedAmbient_street_day: 0, lovedAmbient_scrap_day: 0, lovedAmbient_spiritual_day: 0,
      busPassUsedDay: 0, momBusPassDay: 0,
      // v15 living-neighborhood incident history
      incidentDay: 0, incidentMask: 0, incidentsToday: 0, lastIncidentId: '',
    };
    // v13 wave 7 — faction reputation + hideout chest
    P.faction = { street: 0, scrap: 0, spiritual: 0 };
    state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
    state.dayEventActor = null;
    state.crownPickup = null;
    state.momTipT = 30000; // ~30s into the new save
    // intro chain seeds
    if (state.quests.intro_remember) { state.quests.intro_remember.available = undefined; state.quests.intro_remember.done = false; }
    if (state.quests.intro_tony)     { state.quests.intro_tony.available = false; state.quests.intro_tony.done = false; }
    if (state.quests.intro_smoke)    { state.quests.intro_smoke.available = false; state.quests.intro_smoke.done = false; }
    // v13 wave 6 — fresh save state for map-depth pass
    state.flags.underpassEntered = false;
    state.flags.dumpsterPropaneAwarded = false;
    state.flags.churchLoadedDumpsterX = 0;
    state.flags.churchLoadedDumpsterY = 0;
    if (state.quests.scrap_dog) { state.quests.scrap_dog.state = 'idle'; state.quests.scrap_dog.done = false; state.quests.scrap_dog.available = false; }
    state.graffiti = null; // build a fresh layout
    state.posters = null;  // v13 wave 8b — fresh poster layout on new save
    state.publicPhoneT = 240000 + Math.random()*240000;
    state.phonePropRingT = 0;
    state.publicPhoneAnswered = 0;
    state.freedDogT = 0;
    state.freedDogFollowT = 0;
    state.freedDogFirstReturn = false;
    // new save starts broke. find the ten dollars.
    P.cash = 0;
    P.charisma = 0;
    P.barbAside = false;
    state.barbAside = false;
  }
  spawnNpcs();
  if(state.loadedNpcDeaths instanceof Set){
    for(const n of runtime.npcs)if(state.loadedNpcDeaths.has(n.id))n.dead=true;
    state.loadedNpcDeaths=null;
  }
  spawnCashPiles();
  initInteractiveProps();
  // v13 wave 6 — build (or re-use persisted) graffiti layout
  buildGraffiti();
  // v13 wave 8b — build (or re-use persisted) wall poster layout
  buildPosters();
  applyEquipStats();
  if (!loaded || !Array.isArray(state.hustles)) rollHustles();
  ensureBlockRoute();
  ensureOfficeState();
  syncOfficeDay();
  maybeUnlockOfficeQuest();
  updateOfficeMilestones();
  ensureKingdomState();
  maybeUnlockKingdom(true,false);
  syncKingdomQuests();
  syncKingdomForces();
  // v13 wave 7 — re-spawn bus driver if day 30 fired but bus unresolved
  rehydrateDay30Bus();
  state.mode = 'playing';
  // v13 wave 3 — different first-toast for the intro
  if (!loaded && state.flags && !state.flags.introDone) {
    toast("you wake up on the sidewalk.\nyour mouth tastes like a battery.\nyou do not remember.\n(Q to see what's next.)", 4200);
  } else {
    toast('you wake up on the sidewalk.\nyour mouth tastes like a battery.\n(Q to see today\'s hustles.)', 3500);
  }
  // initial feed posts
  feedPost("woke up.\nstill in the neighborhood.\nfeels like a tuesday.", '@crackheadcent');
  feedPost("good morning. tony has not blinked.", '@tony_observer');
  broadcastNews("good evening. " + RANKS[P.rank].name + " is once again at large.");
}

export function init_start() {
  // ---------- START ----------
  
  
  
}

export function init_boot() {
  // ---------- INIT ----------
  buildSprites();
  buildEnvironmentSprites();
  buildLandmarkFacades();
  buildLightSprites();
  buildFogSheet();
  updateHUD();
  rotateNews();
  setInterval(rotateNews, 50000);
  // CRT power-on auto-dismiss
  setTimeout(() => { const p = document.getElementById('poweron'); if (p) p.classList.add('gone'); }, 800);
  
  
}

export let loadBtnEl, titleLoadTap;

export function setupMobile() {
  // detect touch
  const isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
  if (!isTouch && window.innerWidth > 820) return;
  state.touchMode = true;
  document.getElementById('mobile-ctrls').style.display = 'block';
  const fireKey = (key, down) => {
    const ev = new KeyboardEvent(down ? 'keydown' : 'keyup', { key });
    window.dispatchEvent(ev);
  };
  // D-pad replaced in v11 by analog joystick — see below
  document.querySelectorAll('#mobile-ctrls .ab').forEach(el => {
    const key = el.dataset.key;
    let pressed = false;
    const press = (e) => {
      if (pressed) return;
      pressed = true;
      e.preventDefault();
      el.classList.add('active');
      fireKey(key, true);
      if (e.pointerId !== undefined && el.setPointerCapture) {
        try { el.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const release = (e) => {
      if (!pressed) return;
      pressed = false;
      if (e && e.preventDefault) e.preventDefault();
      el.classList.remove('active');
      fireKey(key, false);
    };
    el.addEventListener('pointerdown', press);
    el.addEventListener('pointerup', release);
    el.addEventListener('pointercancel', release);
    el.addEventListener('lostpointercapture', release);
    el.addEventListener('touchstart', press, {passive:false});
    el.addEventListener('touchend', release, {passive:false});
    el.addEventListener('touchcancel', release, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{pressed=false;el.classList.remove('active');});
  });

  // ---------- ANALOG JOYSTICK ----------
  const stick = document.getElementById('stick');
  const nub = document.getElementById('stickNub');
  if (stick && nub) {
    let activePointer = null;
    let cx = 0, cy = 0; // stick center in screen coords
    const RADIUS = 42;
    const DEAD_ZONE = 0.18;
    const setVector = (dx, dy) => {
      // distance ratio
      const mag = Math.sqrt(dx*dx + dy*dy);
      const norm = Math.min(1, mag / RADIUS);
      const nx = norm > 0.001 ? dx/mag : 0;
      const ny = norm > 0.001 ? dy/mag : 0;
      // store on state for updateWorld to consume
      if (norm < DEAD_ZONE) {
        state.stickX = 0; state.stickY = 0; state.stickMag = 0;
      } else {
        state.stickX = nx;
        state.stickY = ny;
        state.stickMag = norm;
      }
      // visual position of nub
      const clampedMag = Math.min(mag, RADIUS);
      const px = norm > 0.001 ? (dx/mag) * clampedMag : 0;
      const py = norm > 0.001 ? (dy/mag) * clampedMag : 0;
      nub.style.transform = `translate(calc(-50% + ${px}px), calc(-50% + ${py}px))`;
    };
    const onDown = (e) => {
      if (activePointer !== null) return;
      e.preventDefault();
      activePointer = e.pointerId !== undefined ? e.pointerId : 1;
      const rect = stick.getBoundingClientRect();
      cx = rect.left + rect.width/2;
      cy = rect.top + rect.height/2;
      stick.classList.add('dragging');
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
      if (e.pointerId !== undefined && stick.setPointerCapture) {
        try { stick.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const onMove = (e) => {
      if (activePointer === null) return;
      // for pointer events, check id; for touch, take first
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      e.preventDefault();
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
    };
    const onUp = (e) => {
      if (activePointer === null) return;
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      activePointer = null;
      stick.classList.remove('dragging');
      setVector(0, 0);
    };
    stick.addEventListener('pointerdown', onDown);
    stick.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    stick.addEventListener('pointercancel', onUp);
    // touch fallback
    stick.addEventListener('touchstart', onDown, {passive:false});
    stick.addEventListener('touchmove', onMove, {passive:false});
    stick.addEventListener('touchend', onUp, {passive:false});
    stick.addEventListener('touchcancel', onUp, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{
      activePointer=null;
      stick.classList.remove('dragging');
      setVector(0,0);
    });
  }
  // top bar (single tap toggles)
  document.querySelectorAll('#mobile-ctrls .topbar .mb').forEach(el => {
    const key = el.dataset.key;
    const tap = (e) => {
      e.preventDefault();
      el.classList.add('active');
      setTimeout(() => el.classList.remove('active'), 120);
      fireKey(key, true);
      setTimeout(() => fireKey(key, false), 30);
    };
    el.addEventListener('touchstart', tap, {passive:false});
    el.addEventListener('click', tap);
  });
  // title tap = start
  document.getElementById('title').addEventListener('touchstart', (e) => {
    e.preventDefault();
    if (state.mode === 'title') {
      audio.init();
      if(state.endingContinue)continueAfterEnding();else startGame(false);
    }
  }, {passive:false});
  // prevent canvas touch from scrolling
  document.getElementById('game').addEventListener('touchstart', e => e.preventDefault(), {passive:false});
  // v13 wave 4 — tap anywhere on canvas to lock during the heat minigame
  const onCookTap = (e) => {
    if (state.mode !== 'cookmini') return;
    e.preventDefault();
    lockHeatMini();
  };
  document.getElementById('game').addEventListener('pointerdown', onCookTap);
  document.getElementById('game').addEventListener('touchstart', onCookTap, {passive:false});
  // global block double-tap zoom
  document.addEventListener('gesturestart', e => e.preventDefault());
  document.addEventListener('dblclick', e => e.preventDefault());
}

export function init_mobile() {
  // ---------- MOBILE TOUCH CONTROLS ----------
  
  setupMobile();
  
  // The visible load receipt is a real touch/click target, not keyboard-only decoration.
  loadBtnEl=document.getElementById('loadBtn');
  titleLoadTap=(e)=>{
    e.preventDefault();e.stopPropagation();
    loadFromTitle();
  };
  loadBtnEl.addEventListener('pointerdown',titleLoadTap);
  loadBtnEl.addEventListener('touchstart',titleLoadTap,{passive:false});
  loadBtnEl.addEventListener('click',titleLoadTap);
  
  // detect existing save for title screen; storage absence must not break a double-clicked build.
  (async () => {
    try{
      const s = await window.storage.get(SAVE_KEY);
      if (s && s.value) loadBtnEl.style.display = 'block';
    }catch(_){ /* volatile play still works when the host provides no storage adapter */ }
  })();
  
  requestAnimationFrame(update);
  
  // local QA accessor (data/functions remain inside the single-file closure)
  window._rb = {
    P, state,
    get npcs() { return runtime.npcs; },
    get sprites() { return SPRITE_CACHE; },
    get pals() { return PALS; },
    get routeStops() { return ROUTE_STOPS; },
    startGame, updateWorld, drawAll, startIncident, updateActiveIncident,
    validBlockRoute, rollBlockRoute, ensureBlockRoute, tryStampBlockRoute, routePatchTier, hustleProgress,
    currentPrimaryObjective, resolveNpcPose, renderQuests, saveGame, loadGame,
    endingScreen, takeTheBus, continueAfterEnding,
  };
  
}
