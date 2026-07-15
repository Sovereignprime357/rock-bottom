/* Generated from frozen rock_bottom_v19.html.
 * Source seams: NPC AI and chatter loop.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio } from '../core/audio_save.js';
import { P, particles, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { clamp, rectsOverlap } from '../data/npc_spawns.js';
import { CHATTER } from '../data/props.js';
import { WORLD } from '../data/world.js';
import { updateWorld } from '../legacy.js';
import { aggroNpc, damagePlayer, onNpcDeath, spawnProjectile } from './combat.js';

export function updateNpcActors(dt) {
  // NPC AI + walk-frame anim + chatter
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    n.attackCd = Math.max(0, (n.attackCd||0) - dt);
    if (n.hitFlash) n.hitFlash = Math.max(0, n.hitFlash - dt);
    // v13 wave 5 — hit-stun freezes NPC AI for 120ms post-damage.
    if (n.hitStun > 0) { n.hitStun = Math.max(0, n.hitStun - dt); continue; }
    if (n.chatterT > 0) n.chatterT -= dt;
    // ambient chatter
    n.chatterCd = (n.chatterCd||0) - dt;
    if (n.chatterCd <= 0 && !n.asleep && !n.aggro) {
      n.chatterCd = 7000 + Math.random()*9000;
      const dx2 = (P.x+P.w/2) - (n.x+n.w/2), dy2 = (P.y+P.h/2) - (n.y+n.h/2);
      if (dx2*dx2 + dy2*dy2 < 380*380 && CHATTER[n.id]) {
        const lines = CHATTER[n.id];
        n.chatter = lines[Math.floor(Math.random()*lines.length)];
        n.chatterT = 2600;
      }
    }

    const pdx = (P.x+P.w/2) - (n.x+n.w/2);
    const pdy = (P.y+P.h/2) - (n.y+n.h/2);
    const pd2 = pdx*pdx + pdy*pdy;

    // zoneOnly hostility
    if (n.zoneOnly && !n.aggro) {
      const z = n.zoneOnly;
      const px = P.x+P.w/2, py = P.y+P.h/2;
      n.hostile = (px>=z.x && px<=z.x+z.w && py>=z.y && py<=z.y+z.h);
    }

    let isMoving = false;
    // pet possum AI — follow player at distance, occasionally reveals cash
    if (n.isPet) {
      const pdxP = P.x - n.x, pdyP = P.y - n.y;
      const pdistP = Math.sqrt(pdxP*pdxP + pdyP*pdyP);
      if (pdistP > 48) {
        n.x += (pdxP/pdistP) * (n.speed||1.6) * (dt/16);
        n.y += (pdyP/pdistP) * (n.speed||1.6) * (dt/16);
        isMoving = true;
      } else if (pdistP < 24) {
        n.x -= (pdxP/pdistP) * 0.4 * (dt/16);
        n.y -= (pdyP/pdistP) * 0.4 * (dt/16);
      }
      // periodic cash-pile reveal — possum only (v13 wave 6: freed dog also uses isPet, skip for it).
      if (n.id === 'pet_possum') {
        n.revealT = (n.revealT||0) - dt;
        if (n.revealT <= 0) {
          n.revealT = 30000 + Math.random()*15000;
          const uncollected = runtime.cashPiles.filter(c => !c.collected);
          if (uncollected.length) {
            const target = uncollected[Math.floor(Math.random()*uncollected.length)];
            // teleport one cash pile near the player
            target.x = P.x + (Math.random()-.5)*60;
            target.y = P.y + 40 + Math.random()*30;
            for (let i=0;i<6;i++) particles.push({x:target.x, y:target.y, vx:(Math.random()-.5)*3, vy:-Math.random()*3, life:600, c:'#e8c040', sz:3});
            toast("the possum has placed something for you.\n(look around your feet.)", 2400);
          }
        }
      }
    }
    // ally AI (stripe in coop)
    if (n.isAlly) {
      const target = runtime.npcs.find(x => x.id === (n.allyTarget||'tony') && !x.dead);
      if (target) {
        const adx = target.x - n.x, ady = target.y - n.y;
        const alen = Math.sqrt(adx*adx+ady*ady)||1;
        if (alen > 30) {
          n.x += (adx/alen) * (n.speed||1.4) * (dt/16);
          n.y += (ady/alen) * (n.speed||1.4) * (dt/16);
          isMoving = true;
        } else {
          // hit
          n.attackCd = (n.attackCd||0);
          if (n.attackCd <= 0) {
            target.hp -= 10; target.hitFlash = 180; target.showHp = true;
            n.attackCd = 700;
            for (let i=0;i<4;i++) particles.push({x:target.x+target.w/2,y:target.y+target.h/2,vx:(Math.random()-.5)*4,vy:(Math.random()-.5)*4,life:280,c:'#88c0ff',sz:3});
            if (target.hp <= 0) onNpcDeath(target);
          }
        }
      } else {
        // patrol nearby player
        const dxP = P.x - n.x, dyP = P.y - n.y;
        const lenP = Math.sqrt(dxP*dxP+dyP*dyP);
        if (lenP > 80) { n.x += (dxP/lenP)*(n.speed||1.2)*(dt/16); n.y += (dyP/lenP)*(n.speed||1.2)*(dt/16); isMoving = true; }
      }
    }
    // aggro chase — v13 wave 5: archetype dispatch. patterns mutate the chase/touch flow.
    // existing non-archetype'd NPCs fall through to the default chase-bite (unchanged behavior).
    else if (n.aggro || (n.hostile && pd2 < 360*360)) {
      const len = Math.sqrt(pd2)||1;
      const arch = n.archetype || 'default';

      // ---------------- CHARGER (brutus, brutus_older) ----------------
      // windup → lunge → cooldown state machine. brutus_older variant has shorter windup,
      // longer lunge, bigger multiplier, longer cooldown — plus "berserk" variant when boss
      // is in phase 3 (state.brutusOlderPhase>=3 or n.berserk flag).
      if (arch === 'charger' || arch === 'charger_older') {
        const older = (arch === 'charger_older');
        const berserk = !!n.berserk;
        // tunables per variant + phase
        const windupMs = berserk ? 400 : (older ? 550 : 800);
        const lungeMs  = berserk ? 800 : (older ? 1400 : 1000);
        const lungeSpd = berserk ? 3.0 : (older ? 2.4 : 2.0);
        const dmgMult  = berserk ? 2.0 : (older ? 1.8 : 1.5);
        const cdMs     = berserk ? 600 : (older ? 1700 : 1400);

        n.chargeState = n.chargeState || 'idle';
        n.chargeT = n.chargeT || 0;
        n.chargeCdT = Math.max(0, (n.chargeCdT||0) - dt);

        if (n.chargeState === 'cooldown') {
          n.chargeT -= dt;
          if (n.chargeT <= 0) { n.chargeState = 'idle'; n.chargeT = 0; }
          // panting — light wobble, no movement
        }
        else if (n.chargeState === 'windup') {
          n.chargeT -= dt;
          // visible tint pulse driven by hitFlash short bursts so existing renderer picks it up
          if ((n.chargeT % 90) < 45) n.hitFlash = Math.max(n.hitFlash||0, 40);
          if (n.chargeT <= 0) {
            // commit the lunge — direction is fixed at windup START via stored vector
            n.chargeState = 'lunge';
            n.chargeT = lungeMs;
            audio.bossRoar();
          }
        }
        else if (n.chargeState === 'lunge') {
          n.chargeT -= dt;
          if (n.lungeVx !== undefined) {
            n.x += n.lungeVx * lungeSpd * (dt/16);
            n.y += n.lungeVy * lungeSpd * (dt/16);
            isMoving = true;
          }
          // hit detection during lunge
          if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
            damagePlayer(Math.floor((n.dmg||8) * dmgMult), n);
            n.attackCd = 600;
            n.chargeState = 'cooldown';
            n.chargeT = cdMs;
            n.chargeCdT = cdMs;
            n.chargeLanded = true;
          }
          if (n.chargeT <= 0) {
            // lunge missed — DODGED_THE_LUNGE achievement on first dodge
            if (!n.chargeLanded) unlockAchievement('dodged_the_lunge');
            n.chargeLanded = false;
            n.chargeState = 'cooldown';
            n.chargeT = cdMs;
            n.chargeCdT = cdMs;
          }
        }
        else {
          // idle — slow chase, enter windup when in range
          if (n.speed > 0) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          }
          if (pd2 < 200*200 && n.chargeCdT <= 0) {
            n.chargeState = 'windup';
            n.chargeT = windupMs;
            // freeze position; lock lunge vector toward player NOW
            const llen = Math.sqrt(pd2) || 1;
            n.lungeVx = pdx/llen;
            n.lungeVy = pdy/llen;
            audio.windup();
          }
        }
        // touch damage outside the charge (passive bite while idle/chasing close)
        if (n.chargeState === 'idle' && rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          damagePlayer(n.dmg||8, n);
          n.attackCd = 800;
        }
      }

      // ---------------- GRABBER (lurch) ----------------
      // chase-bite at ×1.3 damage, applies 500ms stun on contact.
      else if (arch === 'grabber') {
        if (n.speed > 0) {
          // lurch freezes briefly post-grab for the "arms-extended" beat
          const grabFreeze = (n.grabFreezeT||0) > 0;
          if (!grabFreeze) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          } else {
            n.grabFreezeT = Math.max(0, (n.grabFreezeT||0) - dt);
          }
        }
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          const dmg = Math.floor((n.dmg||8) * 1.3);
          damagePlayer(dmg, n);
          n.attackCd = 800;
          n.grabFreezeT = 200;
          P.stunT = Math.max(P.stunT||0, 500);
          // toast only on first grab per encounter (avoid spam)
          if (!n.grabbedOnce) { n.grabbedOnce = true; toast("GRABBED.\nhis arms are too long.", 1400); }
        }
      }

      // ---------------- SWARMER (sherri) ----------------
      // speed ×1.4, damage ×0.6. on aggro also calls a sibling (in aggroNpc).
      else if (arch === 'swarmer') {
        if (n.speed > 0) {
          const swSpd = n.speed * 1.4;
          n.x += (pdx/len) * swSpd * (dt/16);
          n.y += (pdy/len) * swSpd * (dt/16);
          isMoving = true;
        }
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
          const dmg = Math.max(1, Math.floor((n.dmg||5) * 0.6));
          damagePlayer(dmg, n);
          n.attackCd = 700;
        }
      }

      // ---------------- RANGED (paulie) ----------------
      // keep 180-260px. throws bottles every 1500ms. panic-chase if player < 120px.
      else if (arch === 'ranged') {
        const d = Math.sqrt(pd2);
        n.panicT = Math.max(0, (n.panicT||0) - dt);
        n.throwT = (n.throwT||0) - dt;
        n.throwAimT = Math.max(0, (n.throwAimT||0) - dt);
        if (d < 120 && n.panicT <= 0) n.panicT = 1000; // panic for 1s when player closes
        if (n.panicT > 0) {
          // chase-bite for 1s
          if (n.speed > 0) {
            n.x += (pdx/len) * n.speed * (dt/16);
            n.y += (pdy/len) * n.speed * (dt/16);
            isMoving = true;
          }
          if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
            damagePlayer(n.dmg||7, n);
            n.attackCd = 800;
          }
        } else {
          // kite to keep 180-260px
          let mx = 0, my = 0;
          if (d < 180) { mx = -pdx/len; my = -pdy/len; isMoving = true; }
          else if (d > 260) { mx = pdx/len; my = pdy/len; isMoving = true; }
          // strafe a bit when in band
          else { const a = performance.now()/500; mx = -pdy/len * Math.sin(a); my = pdx/len * Math.sin(a); }
          n.x += mx * (n.speed||1.5) * (dt/16);
          n.y += my * (n.speed||1.5) * (dt/16);
          // throw bottles
          if (n.throwT <= 0 && d >= 160 && d <= 280) {
            // 300ms aim-raise telegraph before the throw
            if (n.throwAimT <= 0 && !n.aimingThrow) {
              n.aimingThrow = true;
              n.throwAimT = 300;
              // tiny "*" particle
              particles.push({x:n.x+n.w/2+8, y:n.y+4, vx:0, vy:-0.3, life:400, c:'#fff080', sz:2, glow:true});
            } else if (n.aimingThrow && n.throwAimT <= 0) {
              n.aimingThrow = false;
              n.throwT = 1500;
              spawnProjectile({
                x: n.x+n.w/2, y: n.y+n.h/2,
                tx: P.x+P.w/2, ty: P.y+P.h/2,
                speed: 320, dmg: 15, kind: 'bottle', from: n, wobble: 0.35,
              });
              audio.bottleThrow();
            }
          }
        }
      }

      // ---------------- FALLEN PRIEST (priest_fallen) ----------------
      // phase 1 (≥50% hp): keep 180-280px, throw holy water vials every 1200ms (22 dmg + 1.5s slow).
      // phase 2 (<50% hp): becomes a faster charger (×2.4 speed, 500ms windup, lunge applies slow).
      else if (arch === 'priest_fallen') {
        const pct = n.hp / n.maxHp;
        const inPhase2 = pct < 0.5;
        // phase transition once
        if (inPhase2 && !n.fallenPhase2) {
          n.fallenPhase2 = true;
          audio.bossRoar();
          state.shake = 12;
          toast("the lord is not here.\nthe lord left.\nhe took the bus.", 4200);
        }
        if (!inPhase2) {
          // ranged-holy
          const d = Math.sqrt(pd2);
          let mx = 0, my = 0;
          if (d < 180) { mx = -pdx/len; my = -pdy/len; isMoving = true; }
          else if (d > 280) { mx = pdx/len; my = pdy/len; isMoving = true; }
          else { const a = performance.now()/600; mx = -pdy/len * Math.sin(a); my = pdx/len * Math.sin(a); }
          n.x += mx * (n.speed||1.6) * (dt/16);
          n.y += my * (n.speed||1.6) * (dt/16);
          n.throwT = (n.throwT||0) - dt;
          n.throwAimT = Math.max(0, (n.throwAimT||0) - dt);
          if (n.throwT <= 0 && d >= 160 && d <= 300) {
            if (n.throwAimT <= 0 && !n.aimingThrow) {
              n.aimingThrow = true;
              n.throwAimT = 350;
              for (let i=0;i<4;i++) particles.push({x:n.x+n.w/2,y:n.y+8,vx:(Math.random()-.5)*1,vy:-Math.random()*1.5,life:500,c:'#a0d0ff',sz:2,glow:true});
            } else if (n.aimingThrow && n.throwAimT <= 0) {
              n.aimingThrow = false;
              n.throwT = 1200;
              spawnProjectile({
                x: n.x+n.w/2, y: n.y+n.h/2,
                tx: P.x+P.w/2, ty: P.y+P.h/2,
                speed: 280, dmg: 22, slowMs: 1500, kind: 'holy', from: n, wobble: 0.18,
              });
              audio.holyWaterThrow();
            }
          }
        } else {
          // dasher — charger with priest tuning
          n.chargeState = n.chargeState || 'idle';
          n.chargeT = n.chargeT || 0;
          n.chargeCdT = Math.max(0, (n.chargeCdT||0) - dt);
          const windupMs = 500, lungeMs = 900, lungeSpd = 2.4, cdMs = 1200;
          if (n.chargeState === 'cooldown') {
            n.chargeT -= dt;
            if (n.chargeT <= 0) { n.chargeState = 'idle'; }
          } else if (n.chargeState === 'windup') {
            n.chargeT -= dt;
            if ((n.chargeT % 90) < 45) n.hitFlash = Math.max(n.hitFlash||0, 40);
            if (n.chargeT <= 0) {
              n.chargeState = 'lunge';
              n.chargeT = lungeMs;
            }
          } else if (n.chargeState === 'lunge') {
            n.chargeT -= dt;
            if (n.lungeVx !== undefined) {
              n.x += n.lungeVx * lungeSpd * (dt/16);
              n.y += n.lungeVy * lungeSpd * (dt/16);
              isMoving = true;
            }
            if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && (n.attackCd||0) <= 0) {
              damagePlayer(30, n);
              P.slowT = Math.max(P.slowT||0, 1500);
              n.attackCd = 600;
              n.chargeState = 'cooldown';
              n.chargeT = cdMs;
              n.chargeLanded = true;
            }
            if (n.chargeT <= 0) {
              if (!n.chargeLanded) unlockAchievement('dodged_the_lunge');
              n.chargeLanded = false;
              n.chargeState = 'cooldown';
              n.chargeT = cdMs;
            }
          } else {
            if (n.speed > 0) {
              n.x += (pdx/len) * (n.speed||1.6) * (dt/16);
              n.y += (pdy/len) * (n.speed||1.6) * (dt/16);
              isMoving = true;
            }
            if (pd2 < 220*220 && n.chargeCdT <= 0) {
              n.chargeState = 'windup';
              n.chargeT = windupMs;
              const llen = Math.sqrt(pd2) || 1;
              n.lungeVx = pdx/llen; n.lungeVy = pdy/llen;
              audio.windup();
            }
          }
        }
      }

      // ---------------- DEFAULT chase-bite (cops, larry, dave when aggro'd, etc) ----------------
      else {
        if (n.speed > 0) {
          // v13 wave 6 — fed/free dog cop-discomfort radius: cops at 0.5x speed near a friendly dog.
          // dogSpookSlow flag is set in updateWorld each frame; cleared at the end of this branch.
          const spookMult = (n.dogSpookSlow && (n.cop || n.id==='brendan' || n.id==='horsecop')) ? 0.5 : 1;
          n.x += (pdx/len) * n.speed * spookMult * (dt/16);
          n.y += (pdy/len) * n.speed * spookMult * (dt/16);
          isMoving = true;
        }
        // clear the per-frame flag so it can be re-set next tick
        if (n.dogSpookSlow) n.dogSpookSlow = 0;
        // v13 wave 2 — brendan's taser charges over 4 seconds; only zaps when ready.
        if (n.isBrendan) {
          n.taserChargeT = Math.min(4000, (n.taserChargeT||0) + dt);
        }
        // touch damage
        if (rectsOverlap({x:P.x,y:P.y,w:P.w,h:P.h}, n) && n.attackCd===0) {
          if (n.isBrendan) {
            if (n.taserChargeT >= 4000) {
              damagePlayer(50, n);
              n.taserChargeT = 0;
              n.attackCd = 1000;
              audio.copSiren();
              for (let i=0;i<10;i++) particles.push({x:P.x+P.w/2,y:P.y+P.h/2,vx:(Math.random()-.5)*6,vy:(Math.random()-.5)*6,life:400,c:'#88c0ff',sz:3,glow:true});
            }
          } else {
            damagePlayer(n.dmg||8, n);
            n.attackCd = 800;
          }
        }
      }
    } else if (n.patrol) {
      // patrol along path
      n.patrolT = (n.patrolT||0) + dt;
      const tgt = n.patrol[Math.floor((n.patrolT/2000) % n.patrol.length)];
      const tdx = tgt.x - n.x, tdy = tgt.y - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * (n.speed||1) * (dt/16);
        n.y += (tdy/tlen) * (n.speed||1) * (dt/16);
        isMoving = true;
      }
    } else if (n.wanderOff) {
      // v13 wave 7 — day-event actor walking off-map. once past world bounds, despawn.
      const tdx = (n.targetX||(WORLD.w+80)) - n.x, tdy = (n.targetY||n.y) - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * (n.speed||1.2) * (dt/16);
        n.y += (tdy/tlen) * (n.speed||1.2) * (dt/16);
        isMoving = true;
      } else {
        n.dead = true;
      }
    } else if (n.wander && n.speed > 0) {
      n.wanderT = (n.wanderT||0) - dt;
      if (n.wanderT <= 0) {
        n.wanderT = 1500 + Math.random()*2000;
        n.targetX = n.x + (Math.random()-.5) * 120;
        n.targetY = n.y + (Math.random()-.5) * 120;
      }
      const tdx = n.targetX - n.x, tdy = n.targetY - n.y;
      const tlen = Math.sqrt(tdx*tdx+tdy*tdy);
      if (tlen > 4) {
        n.x += (tdx/tlen) * n.speed*0.4 * (dt/16);
        n.y += (tdy/tlen) * n.speed*0.4 * (dt/16);
        isMoving = true;
      }
    }
    if((n.kingdomGuard||n.kingdomPretender||n.kingdomBoss||n.kingdomAdd)&&n.zoneOnly){
      const z=n.zoneOnly;n.x=clamp(n.x,z.x+6,z.x+z.w-n.w-6);n.y=clamp(n.y,z.y+6,z.y+z.h-n.h-6);
    }
    // frame anim
    if (isMoving) {
      n.frameT = (n.frameT||0) + dt;
      if (n.frameT > 200) { n.frameT = 0; n.frame = (n.frame||0)+1; if (n.frame>2) n.frame=1; }
    } else { n.frame = 0; n.frameT = 0; }
    // pothole "talks" — cycles frames always
    if (n.id === 'pothole') n.frame = Math.floor(performance.now()/220) % 3;
    // cart roadkill
    if (P.cartMounted && rectsOverlap({x:P.x-4,y:P.y-4,w:P.w+8,h:P.h+8}, n) && n.attackCd===0 && (n.hostile||n.aggro)) {
      n.hp -= 14; n.hitFlash = 180; n.attackCd = 600;
      const ang = Math.atan2(n.y-P.y, n.x-P.x);
      n.x += Math.cos(ang)*10; n.y += Math.sin(ang)*10;
      audio.hit();
      if (n.hp <= 0) onNpcDeath(n);
    }
  }
}

export function init_npc_ai() {
  // ---------- NPC AI + walk-frame anim + chatter ----------
  
  
}
