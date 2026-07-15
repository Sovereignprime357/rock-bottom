/* Generated from frozen rock_bottom_v19.html.
 * Source seams: landmark and light caches.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, state } from '../core/runtime_ui.js';
import { PROPS } from '../data/props.js';
import { H, LANDMARK_FACADES, UTILITY_WIRES, W, WORLD_DECOR, WORLD_LIGHTS } from '../data/world.js';
import { ENV_SPRITE_CACHE, ctx, visibleWorldRect } from './canvas_geography.js';
import { KINGDOM_CLANS, KINGDOM_EMPEROR, freshKingdomState, kingdomStageClan } from '../systems/campaigns.js';

export let LANDMARK_CACHE, landmarkCacheReady, LIGHT_MASK, LIGHT_CTX, LIGHT_HOLE, LIGHT_GLOW_CACHE, FOG_SHEET;

export function buildLandmarkFacades() {
  for (const f of LANDMARK_FACADES) {
    const pad=16, c=document.createElement('canvas');
    c.width=f.w+pad*2; c.height=f.h+pad*2;
    const g=c.getContext('2d'); g.imageSmoothingEnabled=false;
    const x=pad, y=pad;
    g.fillStyle='rgba(0,0,0,.42)'; g.fillRect(x+7,y+f.h,f.w-4,7);
    const wall = f.kind==='warehouse' ? '#342f27' : f.kind==='industrial' ? '#30251f' : f.kind==='rowhouse' ? '#3b2a22' : '#3a3026';
    const edge = f.kind==='industrial' ? '#160d09' : '#1a1510';
    g.fillStyle=wall; g.fillRect(x,y,f.w,f.h);
    g.strokeStyle=edge; g.lineWidth=3; g.strokeRect(x+1,y+1,f.w-2,f.h-2);
    if (f.kind==='warehouse' || f.kind==='industrial') {
      g.strokeStyle='rgba(212,200,150,.07)'; g.lineWidth=1;
      for(let bx=8;bx<f.w;bx+=10){g.beginPath();g.moveTo(x+bx,y+2);g.lineTo(x+bx,y+f.h-2);g.stroke();}
      const bays=Math.max(1,Math.floor(f.w/170));
      for(let i=0;i<bays;i++){
        const bw=Math.min(96,(f.w-30)/bays), bx=x+18+i*(f.w/bays);
        g.fillStyle='#171512'; g.fillRect(bx,y+f.h-58,bw,56);
        g.strokeStyle='#5c5548'; g.strokeRect(bx+.5,y+f.h-57.5,bw-1,55);
        g.fillStyle='rgba(212,200,150,.08)';
        for(let sy=y+f.h-50;sy<y+f.h-5;sy+=9) g.fillRect(bx+2,sy,bw-4,1);
      }
      if (f.kind==='industrial') {
        g.fillStyle='#241a14';
        for(let i=0;i<3;i++){g.fillRect(x+f.w-48+i*12,y-12-i*5,7,20+i*5);}
      }
    } else if (f.kind==='rowhouse') {
      const bays=Math.max(2,Math.floor(f.w/58));
      for(let i=0;i<bays;i++){
        const bx=x+8+i*(f.w/bays), bw=f.w/bays-12;
        g.fillStyle='#12100e'; g.fillRect(bx,y+18,bw,18);
        g.fillStyle=(i%3===0)?'#8a6a32':'#655632'; g.fillRect(bx+2,y+20,bw-4,14);
        g.fillStyle='#17120f'; g.fillRect(bx+bw/2-7,y+f.h-30,14,28);
        g.fillStyle='#5b4634'; g.fillRect(bx+bw/2-12,y+f.h-3,24,3);
        g.fillRect(bx+bw/2-9,y+f.h,18,3);
      }
      g.strokeStyle='rgba(12,10,8,.75)';
      for(let fy=48;fy<f.h-40;fy+=34){g.beginPath();g.moveTo(x+6,y+fy);g.lineTo(x+f.w-6,y+fy);g.stroke();}
    } else {
      g.fillStyle='#13110e'; g.fillRect(x+10,y+36,f.w-20,Math.max(30,f.h-48));
      const cols=Math.max(2,Math.floor((f.w-20)/46));
      for(let i=0;i<cols;i++){
        const bx=x+16+i*((f.w-32)/cols);
        g.fillStyle=(i&1)?'#33281f':'#4c3928'; g.fillRect(bx,y+42,28,Math.max(20,f.h-60));
        g.fillStyle='rgba(212,200,150,.12)'; g.fillRect(bx+3,y+45,22,2);
      }
      for(let i=0;i<Math.floor(f.w/18);i++){
        g.fillStyle=(i&1)?'#6b2f26':'#b79a56'; g.fillRect(x+5+i*18,y+25,18,11);
      }
    }
    const label=f.sign||'';
    const fs=Math.max(8,Math.min(12,Math.floor((f.w-18)/Math.max(1,label.length)*1.7)));
    g.font=`bold ${fs}px Courier New`; g.textAlign='center';
    const tw=Math.min(f.w-18,g.measureText(label).width+14);
    g.fillStyle='#12100d'; g.fillRect(x+(f.w-tw)/2,y+7,tw,16);
    g.fillStyle='#c8b56f'; g.fillText(label,x+f.w/2,y+19);
    g.textAlign='left';
    LANDMARK_CACHE[f.id]={canvas:c,dx:-pad,dy:-pad};
  }
  landmarkCacheReady = true;
}

export function drawLandmarkFacades() {
  if (!landmarkCacheReady) buildLandmarkFacades();
  for (const f of LANDMARK_FACADES) {
    if (!visibleWorldRect(f.x,f.y,f.w,f.h,32)) continue;
    const cached=LANDMARK_CACHE[f.id];
    if (cached) ctx.drawImage(cached.canvas,f.x+cached.dx,f.y+cached.dy);
  }
}

export function decorBounds(p) {
  if (p.type==='utility_pole') return {x:p.x-18,y:p.y-64,w:36,h:68};
  if (p.type==='clothesline') return {x:Math.min(p.x,p.x2),y:Math.min(p.y,p.y2)-30,w:Math.abs(p.x2-p.x)+1,h:Math.abs(p.y2-p.y)+50};
  return {x:p.x-18,y:p.y-(p.h||24),w:(p.w||36)+18,h:(p.h||36)+24};
}

export function drawWorldDecor(layer) {
  for (const p of WORLD_DECOR) {
    if ((p.layer||'low')!==layer) continue;
    const b=decorBounds(p); if(!visibleWorldRect(b.x,b.y,b.w,b.h,40)) continue;
    if (p.type==='storm_drain'||p.type==='news_box'||p.type==='road_barrier'||p.type==='rail_signal') {
      const sp=ENV_SPRITE_CACHE[p.type]; if(sp) ctx.drawImage(sp,p.x-16,p.y-16,32,32);
    } else if (p.type==='utility_pole') {
      ctx.drawImage(ENV_SPRITE_CACHE.utility_top,p.x-16,p.y-64,32,32);
      ctx.drawImage(ENV_SPRITE_CACHE.utility_base,p.x-16,p.y-32,32,32);
    } else if (p.type==='bus_shelter') {
      ctx.fillStyle='rgba(0,0,0,.34)'; ctx.fillRect(p.x+4,p.y+p.h,p.w-8,5);
      ctx.fillStyle='rgba(92,104,100,.28)'; ctx.fillRect(p.x+5,p.y+5,p.w-10,p.h-8);
      ctx.strokeStyle='#504d44'; ctx.lineWidth=3; ctx.strokeRect(p.x+3,p.y+2,p.w-6,p.h-3);
      ctx.fillStyle='#5a4028'; ctx.fillRect(p.x+18,p.y+p.h-16,p.w-36,7);
      ctx.fillStyle='#2a2520'; ctx.fillRect(p.x+20,p.y+p.h-9,3,9); ctx.fillRect(p.x+p.w-23,p.y+p.h-9,3,9);
      ctx.fillStyle='#d4c896'; ctx.fillRect(p.x+9,p.y+10,15,20);
      ctx.fillStyle='#1a1810'; ctx.font='bold 7px Courier New'; ctx.fillText('0',p.x+14,p.y+23);
    } else if (p.type==='billboard') {
      ctx.fillStyle='#30281f'; ctx.fillRect(p.x+12,p.y+p.h-2,6,54); ctx.fillRect(p.x+p.w-18,p.y+p.h-2,6,54);
      ctx.fillStyle='#17130f'; ctx.fillRect(p.x,p.y,p.w,p.h);
      ctx.strokeStyle='#6a5840'; ctx.lineWidth=3; ctx.strokeRect(p.x+1,p.y+1,p.w-2,p.h-2);
      ctx.fillStyle='#c9b77a'; ctx.font='bold 9px Courier New'; ctx.textAlign='center';
      p.text.split('\n').forEach((line,i)=>ctx.fillText(line,p.x+p.w/2,p.y+22+i*14)); ctx.textAlign='left';
    } else if (p.type==='water_tower') {
      ctx.strokeStyle='#4d463b'; ctx.lineWidth=4;
      ctx.beginPath(); ctx.moveTo(p.x+18,p.y+p.h);ctx.lineTo(p.x+34,p.y+52);ctx.moveTo(p.x+p.w-18,p.y+p.h);ctx.lineTo(p.x+p.w-34,p.y+52);ctx.stroke();
      ctx.fillStyle='#37322a'; ctx.beginPath();ctx.ellipse(p.x+p.w/2,p.y+38,p.w/2,30,0,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#514a3e'; ctx.fillRect(p.x+5,p.y+28,p.w-10,23);
      ctx.fillStyle='#9b8b5b';ctx.font='bold 10px Courier New';ctx.textAlign='center';ctx.fillText(p.text,p.x+p.w/2,p.y+44);ctx.textAlign='left';
    } else if (p.type==='motel_sign') {
      ctx.fillStyle='#2c251d';ctx.fillRect(p.x+11,p.y+18,6,p.h-18);
      ctx.fillStyle='#15110e';ctx.fillRect(p.x,p.y,p.w,42);ctx.strokeStyle='#8a3a3a';ctx.lineWidth=2;ctx.strokeRect(p.x+1,p.y+1,p.w-2,40);
      ctx.fillStyle='#d06030';ctx.font='bold 8px Courier New';ctx.textAlign='center';p.text.split('\n').forEach((line,i)=>ctx.fillText(line,p.x+p.w/2,p.y+15+i*12));ctx.textAlign='left';
    } else if (p.type==='clothesline') {
      ctx.strokeStyle='#5a4a36';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.quadraticCurveTo((p.x+p.x2)/2,(p.y+p.y2)/2+15,p.x2,p.y2);ctx.stroke();
      ctx.fillStyle='#4b352c';ctx.fillRect(p.x-2,p.y-8,4,22);ctx.fillRect(p.x2-2,p.y2-8,4,22);
      const cols=['#8a3a3a','#4a5028','#675b46','#6b455e'];
      for(let i=1;i<5;i++){const t=i/5,x=p.x+(p.x2-p.x)*t,y=p.y+(p.y2-p.y)*t+Math.sin(t*Math.PI)*13;ctx.fillStyle=cols[i-1];ctx.fillRect(x-7,y+2,14,12);}
    } else if (p.type==='crossbuck') {
      ctx.fillStyle='#3a3024';ctx.fillRect(p.x-2,p.y-34,4,40);
      ctx.save();ctx.translate(p.x,p.y-30);ctx.rotate(.62);ctx.fillStyle='#d4c896';ctx.fillRect(-18,-3,36,6);ctx.rotate(-1.24);ctx.fillRect(-18,-3,36,6);ctx.restore();
    }
  }
}

export function drawKingdomSites(){
  const k=state.kingdom||freshKingdomState(),defs=[
    {d:KINGDOM_CLANS.blue_tarp,key:'clan_banner_blue',flag:'blueTarpCleared'},
    {d:KINGDOM_CLANS.cart_cavalry,key:'clan_banner_receipt',flag:'cartKeepCleared'},
    {d:KINGDOM_CLANS.copper_choir,key:'clan_banner_wire',flag:'copperChoirCleared'},
    {d:KINGDOM_EMPEROR,key:'clan_banner_curb',flag:'throneDitchCleared'},
  ];
  for(const b of defs){
    const p=b.d.banner;if(!visibleWorldRect(p.x-20,p.y-34,40,40,20))continue;
    const sp=ENV_SPRITE_CACHE[b.key];if(sp){ctx.globalAlpha=(state.flags&&state.flags[b.flag]) ? 0.58 : 1;ctx.drawImage(sp,p.x-16,p.y-30,32,32);ctx.globalAlpha=1;}
  }
  const clan=kingdomStageClan(k.stage);if(!clan||k.stage!==clan.marksStage)return;
  clan.marks.forEach((m,i)=>{
    if(!visibleWorldRect(m.x-18,m.y-18,36,36,10))return;const done=!!(k.marks&(1<<i));
    ctx.setLineDash(done?[]:[3,3]);ctx.strokeStyle=done?'#6f765e':'#e8c040';ctx.lineWidth=2;ctx.strokeRect(m.x-9,m.y-9,18,18);ctx.setLineDash([]);
    ctx.fillStyle=done?'#6f765e':'#d4c896';ctx.font='bold 9px Courier New';ctx.textAlign='center';ctx.fillText(done?'✓':String(i+1),m.x,m.y+3);ctx.textAlign='left';
  });
}

export function drawForegroundWorld() {
  // utility wires and laundry occupy the overhead plane.
  ctx.strokeStyle='rgba(28,22,16,.88)';ctx.lineWidth=1.5;
  for(const w of UTILITY_WIRES){
    const minX=Math.min(w[0],w[2]),minY=Math.min(w[1],w[3]);
    if(!visibleWorldRect(minX,minY,Math.abs(w[2]-w[0]),Math.abs(w[3]-w[1]),70))continue;
    const mx=(w[0]+w[2])/2,my=(w[1]+w[3])/2+12;
    ctx.beginPath();ctx.moveTo(w[0],w[1]-52);ctx.quadraticCurveTo(mx,my-52,w[2],w[3]-52);ctx.stroke();
    ctx.beginPath();ctx.moveTo(w[0],w[1]-48);ctx.quadraticCurveTo(mx,my-44,w[2],w[3]-48);ctx.stroke();
  }
  for(const p of WORLD_DECOR){
    if(p.type==='bus_shelter'&&visibleWorldRect(p.x,p.y,p.w,p.h,20)){
      ctx.fillStyle='#24221e';ctx.fillRect(p.x-2,p.y-3,p.w+4,7);
      ctx.fillStyle='rgba(212,200,150,.16)';ctx.fillRect(p.x,p.y-2,p.w,1);
    }
  }
  // existing park trees finally have a foreground canopy, so walking under one has depth.
  for(const p of PROPS){
    if(p.type!=='tree'||!visibleWorldRect(p.x-24,p.y-60,52,64,12))continue;
    const nearPlayer=Math.abs((P.x+P.w/2)-p.x)<26&&Math.abs((P.y+P.h/2)-(p.y-22))<34;
    ctx.globalAlpha = nearPlayer ? .64 : .92;
    ctx.fillStyle='#1d3b1c';ctx.beginPath();ctx.arc(p.x,p.y-38,20,0,Math.PI*2);ctx.fill();
    ctx.fillStyle='#31552a';ctx.beginPath();ctx.arc(p.x-8,p.y-43,13,0,Math.PI*2);ctx.arc(p.x+9,p.y-42,12,0,Math.PI*2);ctx.fill();
    ctx.globalAlpha=1;
  }
}

export function buildLightSprites() {
  const hg=LIGHT_HOLE.getContext('2d');
  const hole=hg.createRadialGradient(128,128,8,128,128,128);
  hole.addColorStop(0,'rgba(0,0,0,1)');
  hole.addColorStop(.45,'rgba(0,0,0,.72)');
  hole.addColorStop(1,'rgba(0,0,0,0)');
  hg.fillStyle=hole; hg.fillRect(0,0,256,256);
  const colors=new Set(['255,210,120',...WORLD_LIGHTS.map(l=>l.rgb)]);
  for(const rgb of colors){
    const c=document.createElement('canvas');c.width=256;c.height=256;
    const g=c.getContext('2d');
    const glow=g.createRadialGradient(128,128,3,128,128,128);
    glow.addColorStop(0,`rgba(${rgb},.62)`);
    glow.addColorStop(.38,`rgba(${rgb},.20)`);
    glow.addColorStop(1,`rgba(${rgb},0)`);
    g.fillStyle=glow;g.fillRect(0,0,256,256);
    LIGHT_GLOW_CACHE[rgb]=c;
  }
}

export function buildFogSheet() {
  const g=FOG_SHEET.getContext('2d');
  g.fillStyle='rgba(164,160,150,.14)';g.fillRect(0,0,W,H);
  const edge=g.createRadialGradient(W/2,H/2,90,W/2,H/2,390);
  edge.addColorStop(0,'rgba(164,160,150,0)');
  edge.addColorStop(1,'rgba(164,160,150,.46)');
  g.fillStyle=edge;g.fillRect(0,0,W,H);
  // cached horizontal banks keep the fog dirty and uneven without per-frame gradients.
  g.fillStyle='rgba(212,200,150,.045)';
  g.fillRect(0,118,W,52);g.fillRect(0,372,W,70);
}

export function nightAmount() {
  const t=state.dayTime;
  if(t<.2||t>=.8)return 1;
  if(t<.3)return 1-(t-.2)/.1;
  if(t<.7)return 0;
  return (t-.7)/.1;
}

export function punchLightMask(octx,sx,sy,r,power,amount){
  if(sx<-r||sx>W+r||sy<-r||sy>H+r)return;
  octx.globalAlpha=Math.min(1,power*amount);
  octx.drawImage(LIGHT_HOLE,sx-r,sy-r,r*2,r*2);
}

export function init_landmarks_a() {
  // ----- v14 cached set-back facades -----
  LANDMARK_CACHE = {};
  landmarkCacheReady = false;
  
  
  
  
  
  
  
  
  
  
  
  
  LIGHT_MASK = document.createElement('canvas');
  LIGHT_MASK.width=W; LIGHT_MASK.height=H;
  LIGHT_CTX = LIGHT_MASK.getContext('2d');
  LIGHT_HOLE = document.createElement('canvas');
  LIGHT_HOLE.width=256; LIGHT_HOLE.height=256;
  LIGHT_GLOW_CACHE = {};
  FOG_SHEET = document.createElement('canvas');
  FOG_SHEET.width=W; FOG_SHEET.height=H;
  
  
  
  
  
  
  
  
  
}
