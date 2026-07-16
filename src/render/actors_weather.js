/* Generated from frozen rock_bottom_v19.html.
 * Source seams: lighting, weather, actors, and objectives.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, dialogue, runtime, state } from '../core/runtime_ui.js';
import { last } from '../core/update.js';
import { VENDOR_FLOATER_IDS } from '../data/catalogs.js';
import { clamp } from '../data/npc_spawns.js';
import { PROPS } from '../data/props.js';
import { H, W, WORLD_LIGHTS } from '../data/world.js';
import { ctx } from './canvas_geography.js';
import { FOG_SHEET, LIGHT_CTX, LIGHT_GLOW_CACHE, LIGHT_MASK, nightAmount, punchLightMask } from './landmarks_a.js';
import { SPRITE_CACHE } from './sprites.js';
import { routePatchTier } from '../systems/progression_routes.js';

export let VISIBLE_NPC_BUFFER, NAMEPLATE_BOX_BUFFER, NPC_IDLE_SPRITES, NPC_TWO_FRAME_SPRITES;

export function nameplateBoxesIntersect(a,b) {
  return a.x < b.x+b.w && a.x+a.w > b.x && a.y < b.y+b.h && a.y+a.h > b.y;
}

export function placeNameplateBox(n,labelLines,labelWidths) {
  const maxWidth=Math.max(...labelWidths),cx=n.x+n.w/2;
  let top=n.y-8-labelLines.length*10;
  const box=n._labelBox||(n._labelBox={x:0,y:0,w:0,h:0,top:0});
  box.x=Math.round(cx-maxWidth/2-3);box.y=top-8;box.w=maxWidth+6;box.h=labelLines.length*10;box.top=top;
  while(NAMEPLATE_BOX_BUFFER.some(other=>nameplateBoxesIntersect(box,other))){
    top-=box.h+2;box.y=top-8;box.top=top;
  }
  NAMEPLATE_BOX_BUFFER.push(box);
  return box;
}

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
    const cx=n.x+n.w/2, top=placeNameplateBox(n,labelLines,labelWidths).top;
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
  NAMEPLATE_BOX_BUFFER=[];
  NPC_IDLE_SPRITES = new Set(['barb','larry','phoneguy','math','pigeon','possum','scrap_dog']);
  NPC_TWO_FRAME_SPRITES = new Set(['dave_sleep','brutus','scrap_dog','os_brutus','horsecop','pigeon','possum']);
  // Pure visual-state selector: rendering can ask for a pose without changing simulation state.
  // This keeps animation decisions deterministic for screenshots, tests, and cached sprite reuse.
  
  
  
  
  
  
  
  
}
