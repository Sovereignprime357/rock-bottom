/* Generated from frozen rock_bottom_v19.html.
 * Source seams: fences, underpass, and leash.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { runtime } from '../core/runtime_ui.js';
import { PROPS } from '../data/props.js';
import { ZONES } from '../data/world.js';
import { ctx, visibleWorldRect } from './canvas_geography.js';

export function drawScrapFence() {
  const z = ZONES.find(z=>z.id==='scrap');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,24)) return;
  ctx.strokeStyle = '#3a2818';
  ctx.lineWidth = 4;
  // top
  ctx.beginPath(); ctx.moveTo(z.x, z.y); ctx.lineTo(z.x+z.w, z.y); ctx.stroke();
  // left
  ctx.beginPath(); ctx.moveTo(z.x, z.y); ctx.lineTo(z.x, z.y+z.h); ctx.stroke();
  // right
  ctx.beginPath(); ctx.moveTo(z.x+z.w, z.y); ctx.lineTo(z.x+z.w, z.y+z.h); ctx.stroke();
  // south with gap (140px gap centered)
  const gapX = z.x+z.w/2 - 70;
  ctx.beginPath(); ctx.moveTo(z.x, z.y+z.h); ctx.lineTo(gapX, z.y+z.h); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(gapX+140, z.y+z.h); ctx.lineTo(z.x+z.w, z.y+z.h); ctx.stroke();
  // chainlink texture
  ctx.strokeStyle = 'rgba(80,60,40,.5)';
  ctx.lineWidth = 1;
  for (let x=z.x; x<z.x+z.w; x+=10) {
    ctx.beginPath(); ctx.moveTo(x, z.y); ctx.lineTo(x, z.y+10); ctx.stroke();
  }
  // scrap piles
  for (let i=0;i<8;i++) {
    const px = z.x + 40 + ((i*73)%(z.w-80));
    const py = z.y + 50 + ((i*97)%(z.h-100));
    ctx.fillStyle = '#604020';
    ctx.fillRect(px, py, 24, 14);
    ctx.fillStyle = '#d06030';
    ctx.fillRect(px+4, py+3, 8, 3);
  }
}

export function drawUnderpass() {
  const z = ZONES.find(z=>z.id==='underpass');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,80)) return;
  // Keep the oil/crack tile work visible; this is bridge shadow, not replacement floor.
  ctx.fillStyle = 'rgba(24,24,27,.42)';
  ctx.fillRect(z.x, z.y, z.w, z.h);
  // overhead beams
  ctx.fillStyle = '#1a1a1c';
  for (let i=0;i<5;i++) {
    ctx.fillRect(z.x + 20 + i*70, z.y+10, 6, z.h-20);
  }
  // rebar
  ctx.strokeStyle = '#a08060';
  ctx.lineWidth = 2;
  for (let i=0;i<3;i++) {
    ctx.beginPath();
    ctx.moveTo(z.x+40+i*100, z.y+z.h-30);
    ctx.lineTo(z.x+90+i*100, z.y+z.h-60);
    ctx.stroke();
  }
  // v13 wave 6 — sodium-orange light patches (always-on, additive in world space).
  // makes the zone read as perpetually dim even in daytime.
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const patches = [
    { x: z.x + 80,  y: z.y + 80 },
    { x: z.x + 220, y: z.y + 140 },
    { x: z.x + 320, y: z.y + 70 },
  ];
  const t = (Math.sin(performance.now()/700)+1)/2;
  for (const lp of patches) {
    const g = ctx.createRadialGradient(lp.x, lp.y, 4, lp.x, lp.y, 70);
    g.addColorStop(0, `rgba(232,140,40,${0.32 + t*0.08})`);
    g.addColorStop(0.5, 'rgba(220,120,30,.18)');
    g.addColorStop(1, 'rgba(220,120,30,0)');
    ctx.fillStyle = g;
    ctx.fillRect(lp.x-70, lp.y-70, 140, 140);
  }
  ctx.restore();
  // car shadow rumble — every 8s a "car" sweeps overhead visually
  const phase = ((Date.now()/8000)%1);
  if (phase < 0.2) {
    const cx = z.x + phase*z.w*6;
    ctx.fillStyle = 'rgba(0,0,0,.5)';
    ctx.fillRect(cx, z.y-10, 120, 8);
  }
}

export function drawDogLeash() {
  const post = PROPS.find(p => p.type === 'leash_post');
  if (!post) return;
  const dog = runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead);
  if (!dog) return;
  if (!visibleWorldRect(Math.min(post.x,dog.x),Math.min(post.y,dog.y),Math.abs(post.x-dog.x)+dog.w,Math.abs(post.y-dog.y)+dog.h,24)) return;
  // simple zig-zag dark chain
  ctx.strokeStyle = '#3a2810';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(post.x, post.y-8);
  const midX = (post.x + dog.x+dog.w/2)/2;
  const midY = (post.y-8 + dog.y+dog.h/2)/2 + 4;
  ctx.lineTo(midX, midY);
  ctx.lineTo(dog.x+dog.w/2, dog.y+dog.h/2);
  ctx.stroke();
  // chain "links" — small dots along the path
  ctx.fillStyle = '#5a4828';
  for (let i=0.15; i<1; i+=0.18) {
    const lx = post.x*(1-i) + (dog.x+dog.w/2)*i;
    const ly = (post.y-8)*(1-i) + (dog.y+dog.h/2)*i;
    ctx.fillRect(lx-1, ly-1, 2, 2);
  }
}

export function init_landmarks_b() {
  
  
  
  
  // v13 wave 6 — render the chain leash from the leash_post to the scrap_dog
  
  
  
}
