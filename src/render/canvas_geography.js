/* Generated from frozen rock_bottom_v19.html.
 * Source seams: canvas and connective geography.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { state } from '../core/runtime_ui.js';
import { CROSSWALKS, GROUND_PATHS, H, RAIL_LINES, ROAD_SEGMENTS, UTILITY_WIRES, W } from '../data/world.js';
import { parseGrid, rasterize } from './sprites.js';

export let cv, ctx, ENV_SPRITE_CACHE;

export function visibleWorldRect(x, y, w=1, h=1, pad=72) {
  return x+w >= state.cam.x-pad && x <= state.cam.x+W+pad &&
         y+h >= state.cam.y-pad && y <= state.cam.y+H+pad;
}

export function drawRoadSegment(r) {
  if (!visibleWorldRect(r.x, r.y, r.w, r.h, 24)) return;
  const service = r.kind === 'service';
  const arterial = r.kind === 'arterial';
  const curb = service ? '#494438' : '#5a5548';
  const walk = service ? '#343129' : '#454137';
  const road = service ? '#181714' : arterial ? '#1b1a17' : '#1d1c18';
  ctx.fillStyle = walk;
  ctx.fillRect(r.x, r.y, r.w, r.h);
  ctx.fillStyle = curb;
  if (r.axis === 'h') {
    ctx.fillRect(r.x, r.y+7, r.w, 4);
    ctx.fillRect(r.x, r.y+r.h-11, r.w, 4);
    ctx.fillStyle = road;
    ctx.fillRect(r.x, r.y+11, r.w, r.h-22);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(r.x, r.y+8, r.w, 1);
    ctx.fillRect(r.x, r.y+r.h-9, r.w, 1);
    if (!service) {
      const start = Math.max(r.x+18, Math.floor((state.cam.x-48-r.x)/44)*44+r.x+18);
      const end = Math.min(r.x+r.w, state.cam.x+W+48);
      ctx.fillStyle = arterial ? 'rgba(232,192,64,.34)' : 'rgba(212,200,150,.27)';
      for (let x=start; x<end; x+=44) ctx.fillRect(x, r.y+r.h/2-1, 22, 2);
    }
    const patchStart=Math.max(r.x+64,Math.floor((state.cam.x-r.x)/196)*196+r.x+64);
    for(let x=patchStart;x<Math.min(r.x+r.w,state.cam.x+W+80);x+=196){
      const wobble=((x*17+r.y*7)>>>0)%18;
      ctx.fillStyle='rgba(7,6,5,.24)';ctx.fillRect(x,r.y+22+wobble,42,16);
      ctx.strokeStyle='rgba(112,92,60,.16)';ctx.strokeRect(x+.5,r.y+22.5+wobble,41,15);
    }
    ctx.strokeStyle = 'rgba(20,16,10,.32)';
    ctx.lineWidth = 1;
    const seamStart = Math.max(r.x, Math.floor((state.cam.x-r.x)/48)*48+r.x);
    for (let x=seamStart; x<Math.min(r.x+r.w,state.cam.x+W+48); x+=48) {
      ctx.beginPath(); ctx.moveTo(x,r.y); ctx.lineTo(x,r.y+7); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x,r.y+r.h-7); ctx.lineTo(x,r.y+r.h); ctx.stroke();
    }
  } else {
    ctx.fillRect(r.x+7, r.y, 4, r.h);
    ctx.fillRect(r.x+r.w-11, r.y, 4, r.h);
    ctx.fillStyle = road;
    ctx.fillRect(r.x+11, r.y, r.w-22, r.h);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(r.x+8, r.y, 1, r.h);
    ctx.fillRect(r.x+r.w-9, r.y, 1, r.h);
    if (!service) {
      const start = Math.max(r.y+18, Math.floor((state.cam.y-48-r.y)/44)*44+r.y+18);
      const end = Math.min(r.y+r.h, state.cam.y+H+48);
      ctx.fillStyle = arterial ? 'rgba(232,192,64,.34)' : 'rgba(212,200,150,.27)';
      for (let y=start; y<end; y+=44) ctx.fillRect(r.x+r.w/2-1, y, 2, 22);
    }
    const patchStart=Math.max(r.y+64,Math.floor((state.cam.y-r.y)/196)*196+r.y+64);
    for(let y=patchStart;y<Math.min(r.y+r.h,state.cam.y+H+80);y+=196){
      const wobble=((y*13+r.x*11)>>>0)%18;
      ctx.fillStyle='rgba(7,6,5,.24)';ctx.fillRect(r.x+22+wobble,y,16,42);
      ctx.strokeStyle='rgba(112,92,60,.16)';ctx.strokeRect(r.x+22.5+wobble,y+.5,15,41);
    }
    ctx.strokeStyle = 'rgba(20,16,10,.32)';
    ctx.lineWidth = 1;
    const seamStart = Math.max(r.y, Math.floor((state.cam.y-r.y)/48)*48+r.y);
    for (let y=seamStart; y<Math.min(r.y+r.h,state.cam.y+H+48); y+=48) {
      ctx.beginPath(); ctx.moveTo(r.x,y); ctx.lineTo(r.x+7,y); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(r.x+r.w-7,y); ctx.lineTo(r.x+r.w,y); ctx.stroke();
    }
  }
}

export function drawCrosswalk(c) {
  if (!visibleWorldRect(c.x-20,c.y-20,80,80,8)) return;
  ctx.fillStyle = 'rgba(212,200,150,.31)';
  if (c.axis === 'h') {
    for (let i=0;i<5;i++) ctx.fillRect(c.x+i*9, c.y+16, 5, 38);
  } else {
    for (let i=0;i<5;i++) ctx.fillRect(c.x+16, c.y+i*9, 38, 5);
  }
}

export function drawGroundPaths() {
  for (const p of GROUND_PATHS) {
    if (!visibleWorldRect(p.x,p.y,p.w,p.h,p.width)) continue;
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(20,16,10,.32)'; ctx.lineWidth = p.width+5;
    ctx.beginPath(); ctx.moveTo(p.points[0][0],p.points[0][1]);
    for (let i=1;i<p.points.length;i++) ctx.lineTo(p.points[i][0],p.points[i][1]);
    ctx.stroke();
    ctx.strokeStyle = p.color; ctx.lineWidth = p.width;
    ctx.stroke();
    ctx.strokeStyle = 'rgba(212,200,150,.08)'; ctx.lineWidth = 2;
    ctx.stroke();
    ctx.lineCap = 'butt'; ctx.lineJoin = 'miter';
  }
}

export function drawRailLines() {
  for (const r of RAIL_LINES) {
    const minX=Math.min(r.x1,r.x2), maxX=Math.max(r.x1,r.x2);
    const minY=Math.min(r.y1,r.y2)-14, maxY=Math.max(r.y1,r.y2)+14;
    if (!visibleWorldRect(minX,minY,maxX-minX,maxY-minY,24)) continue;
    const start = Math.max(minX, Math.floor((state.cam.x-30-minX)/18)*18+minX);
    const end = Math.min(maxX, state.cam.x+W+30);
    ctx.fillStyle = '#44321f';
    for (let x=start;x<end;x+=18) ctx.fillRect(x,r.y1-13,6,26);
    ctx.fillStyle = '#676259';
    ctx.fillRect(minX,r.y1-9,maxX-minX,3);
    ctx.fillRect(minX,r.y1+7,maxX-minX,3);
    ctx.fillStyle = 'rgba(212,200,150,.24)';
    ctx.fillRect(minX,r.y1-9,maxX-minX,1);
    ctx.fillRect(minX,r.y1+7,maxX-minX,1);
  }
}

export function drawDistrictGroundMarks() {
  // the block: a court that gave up at the free-throw line.
  if (visibleWorldRect(900,740,300,210,16)) {
    ctx.strokeStyle='rgba(212,200,150,.17)'; ctx.lineWidth=3;
    ctx.strokeRect(914,760,270,170);
    ctx.beginPath(); ctx.arc(1050,845,54,Math.PI*.1,Math.PI*.9); ctx.stroke();
    ctx.strokeRect(1018,760,64,56);
  }
  // projects: painted key and a number that was never finished.
  if (visibleWorldRect(100,1700,600,180,16)) {
    ctx.strokeStyle='rgba(160,160,184,.15)'; ctx.lineWidth=3;
    ctx.strokeRect(118,1714,210,145);
    ctx.beginPath(); ctx.arc(328,1786,42,-Math.PI/2,Math.PI/2); ctx.stroke();
    ctx.fillStyle='rgba(212,200,150,.14)'; ctx.font='bold 24px Courier New'; ctx.fillText('4',350,1750);
  }
  // bus stop curb ledger.
  if (visibleWorldRect(1240,1080,220,180,20)) {
    ctx.save(); ctx.translate(1260,1246); ctx.rotate(-.04);
    ctx.fillStyle='rgba(232,192,64,.28)'; ctx.font='bold 13px Courier New';
    ctx.fillText('ROUTE 0 · STILL DUE',0,0); ctx.restore();
  }
  // old school court — regulation was not consulted.
  if (visibleWorldRect(3400,280,760,640,16)) {
    ctx.strokeStyle='rgba(212,200,150,.14)'; ctx.lineWidth=3;
    ctx.strokeRect(3435,740,610,130);
    ctx.beginPath(); ctx.arc(3740,805,52,0,Math.PI*2); ctx.stroke();
    ctx.strokeRect(3435,775,62,60); ctx.strokeRect(3983,775,62,60);
  }
  // v18 warehouse loading apron. Unit numbers disagree with the building signs.
  if (visibleWorldRect(4400,180,1100,760,24)) {
    ctx.strokeStyle='rgba(212,200,150,.18)';ctx.lineWidth=3;
    for(let i=0;i<8;i++){
      const x=4430+i*135;ctx.beginPath();ctx.moveTo(x,730);ctx.lineTo(x,930);ctx.stroke();
      ctx.fillStyle='rgba(212,200,150,.15)';ctx.font='bold 18px Courier New';ctx.fillText(String((i+11)%14),x+18,910);
    }
    ctx.fillStyle='rgba(192,128,56,.18)';ctx.fillRect(4872,710,104,10);
  }
  // v18 canal. The dark center is shallow municipal water and remains walkable.
  if (visibleWorldRect(4300,1540,1350,680,28)) {
    ctx.fillStyle='rgba(20,32,30,.55)';ctx.fillRect(4315,1810,1320,150);
    ctx.fillStyle='rgba(78,105,94,.22)';ctx.fillRect(4315,1870,1320,28);
    ctx.strokeStyle='rgba(150,164,148,.22)';ctx.lineWidth=4;
    ctx.beginPath();ctx.moveTo(4315,1680);ctx.lineTo(5635,1810);ctx.stroke();
    ctx.beginPath();ctx.moveTo(4315,2090);ctx.lineTo(5635,1960);ctx.stroke();
    ctx.font='bold 12px Courier New';ctx.fillStyle='rgba(212,200,150,.18)';
    for(let x=4380;x<5600;x+=160)ctx.fillText(String(9-Math.floor((x-4380)/160)),x,2000);
  }
  // v18 office lot. Every parking space is reserved for a car that is not present.
  if (visibleWorldRect(4300,2700,1250,850,24)) {
    ctx.strokeStyle='rgba(232,192,64,.16)';ctx.lineWidth=3;
    for(let row=0;row<2;row++)for(let i=0;i<8;i++){
      const x=4340+i*145,y=2760+row*610;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+42,y+130);ctx.stroke();
    }
    ctx.fillStyle='rgba(232,192,64,.13)';ctx.font='bold 22px Courier New';ctx.fillText('CUSTOMER',4330,3320);ctx.fillText('NO',4550,3320);
  }
  // v19 blue court: a regulation court copied onto tarp weather.
  if(visibleWorldRect(6200,620,600,300,20)){
    ctx.strokeStyle='rgba(120,144,160,.24)';ctx.lineWidth=3;ctx.strokeRect(6200,620,600,300);
    ctx.beginPath();ctx.moveTo(6500,620);ctx.lineTo(6500,920);ctx.arc(6500,770,64,0,Math.PI*2);ctx.stroke();
  }
  // cart keep: a corral whose parking spaces all face each other.
  if(visibleWorldRect(7480,1810,760,520,20)){
    ctx.strokeStyle='rgba(212,200,150,.20)';ctx.lineWidth=3;ctx.strokeRect(7480,1810,760,520);
    for(let x=7560;x<8220;x+=110){ctx.beginPath();ctx.moveTo(x,1810);ctx.lineTo(x-40,1940);ctx.stroke();}
  }
  // copper choir: inventory bays double as pews.
  if(visibleWorldRect(6060,3180,900,590,20)){
    ctx.strokeStyle='rgba(208,96,48,.20)';ctx.lineWidth=3;ctx.strokeRect(6060,3180,900,590);
    for(let x=6210;x<6960;x+=150){ctx.beginPath();ctx.moveTo(x,3180);ctx.lineTo(x,3770);ctx.stroke();}
  }
  // throne ditch: an outer appeal and an inner appeal. Both are lower than the chair.
  if(visibleWorldRect(7320,4580,880,620,20)){
    ctx.strokeStyle='rgba(212,200,150,.18)';ctx.lineWidth=4;ctx.strokeRect(7320,4580,880,620);ctx.strokeRect(7400,4680,720,420);
  }
}

export function drawWorldWireShadows() {
  ctx.strokeStyle='rgba(0,0,0,.24)'; ctx.lineWidth=2;
  for (const w of UTILITY_WIRES) {
    const minX=Math.min(w[0],w[2]), minY=Math.min(w[1],w[3]);
    if (!visibleWorldRect(minX,minY,Math.abs(w[2]-w[0]),Math.abs(w[3]-w[1]),80)) continue;
    const mx=(w[0]+w[2])/2+24, my=(w[1]+w[3])/2+18;
    ctx.beginPath(); ctx.moveTo(w[0]+22,w[1]+30); ctx.quadraticCurveTo(mx,my,w[2]+22,w[3]+30); ctx.stroke();
  }
}

export function drawWorldFabric() {
  for (const r of ROAD_SEGMENTS) drawRoadSegment(r);
  for (const c of CROSSWALKS) drawCrosswalk(c);
  drawGroundPaths();
  drawRailLines();
  drawDistrictGroundMarks();
  drawWorldWireShadows();
}

export function buildEnvironmentSprites() {
  const make = (rows,pal) => rasterize(parseGrid(rows), pal);
  ENV_SPRITE_CACHE.storm_drain = make([
    '................','................','................','................',
    '................','................','................','................',
    '..111111111111..','..122222222221..','..121212121221..','..122222222221..',
    '..111111111111..','................','................','................',
  ], {1:'#25231f',2:'#706858'});
  ENV_SPRITE_CACHE.news_box = make([
    '................','.....11111......','....1222221.....','....1222221.....',
    '....1333331.....','....1333331.....','....1333331.....','....1222221.....',
    '....1222221.....','....1222221.....','....1111111.....','.....11111......',
    '......11........','......11........','.....1111.......','................',
  ], {1:'#221d18',2:'#8a3a3a',3:'#d4c896'});
  ENV_SPRITE_CACHE.road_barrier = make([
    '................','................','................','................',
    '................','..111111111111..','..122112211221..','..211221122112..',
    '..111111111111..','....11......11..','....11......11..','....11......11..',
    '...1111....1111.','................','................','................',
  ], {1:'#3a3020',2:'#d06030'});
  // v18 district claim sign. One cached 16x16 logical sprite serves every owned district.
  ENV_SPRITE_CACHE.claim_sign = make([
    '................','..111111111111..','..122222222221..','..123333333321..',
    '..123232323321..','..123333333321..','..122222222221..','..111111111111..',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ], {1:'#2a1f10',2:'#d4c896',3:'#8a3a3a'});
  const bannerRows=[
    '.......11.......','.......11.......','..111111111111..','..122222222221..',
    '..123333333321..','..123232323321..','..123333333321..','..122222222221..',
    '..111111111111..','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ];
  ENV_SPRITE_CACHE.clan_banner_blue=make(bannerRows,{1:'#111418',2:'#34485a',3:'#e8c040'});
  ENV_SPRITE_CACHE.clan_banner_receipt=make(bannerRows,{1:'#17130d',2:'#d4c896',3:'#8a3a3a'});
  ENV_SPRITE_CACHE.clan_banner_wire=make(bannerRows,{1:'#100b08',2:'#8a5b3a',3:'#d06030'});
  ENV_SPRITE_CACHE.clan_banner_curb=make(bannerRows,{1:'#0a0805',2:'#5a5548',3:'#e8c040'});
  ENV_SPRITE_CACHE.rail_signal = make([
    '.......11.......','......1221......','......1331......','......1221......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.....111111.....','.....111111.....','................',
  ], {1:'#302a24',2:'#8a3a3a',3:'#e8c040'});
  ENV_SPRITE_CACHE.utility_top = make([
    '.......11.......','.......11.......','..111111111111..','..1....11....1..',
    '..1....11....1..','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
  ], {1:'#4a3723'});
  ENV_SPRITE_CACHE.utility_base = make([
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','.......11.......','.......11.......','.......11.......',
    '.......11.......','......1111......','.....111111.....','................',
  ], {1:'#4a3723'});
}

export function init_canvas_geography() {
  // ---------- RENDER ----------
  cv = document.getElementById('game');
  ctx = cv.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  
  
  
  // ----- v14 connective geography -----
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  // ----- v14 cached environment sprites -----
  ENV_SPRITE_CACHE = {};
  
  
  
}
