/* Generated from frozen rock_bottom_v19.html.
 * Source seams: world update loop.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from './audio_save.js';
import { P, applyEquipStats, dialogue, equipTool, particles, rollWeather, runtime, state, toast, unlockAchievement } from './runtime_ui.js';
import { EQUIPMENT } from '../data/catalogs.js';
import { clamp, currentZone, inZone, isNight, rectsOverlap } from '../data/npc_spawns.js';
import { BUILDINGS, PROPS, interactiveProps } from '../data/props.js';
import { H, RANKS, W, WORLD } from '../data/world.js';
import { spawnFreedDogFollower } from '../dialogue/neighborhood_a.js';
import { maybeFireFallenPriestCall } from '../dialogue/neighborhood_b.js';
import { giveBusPass, hasBusPass, maybeSpawnPriceGuy } from '../dialogue/vendors_places.js';
import { ownsTool, updateHeatMini } from '../minigames/heat.js';
import { drawLighting } from '../render/actors_weather.js';
import { drawAll } from '../render/frame.js';
import { updateGuidance, updateKingdomBattle } from '../systems/campaigns.js';
import { damagePlayer, manageCops, questToast, tryCompleteIntroRemember } from '../systems/combat.js';
import { broadcastNews, feedPost, fireMomIntroTipOnce, fireRandomEvent, garbageTruckRumble, maybeFireMomProudCall, ringPhone } from '../systems/communications.js';
import { updateConcessionClocks } from '../systems/concessions.js';
import { fireDayEvents, resetDailyCounters } from '../systems/daily_hideouts.js';
import { adjustFaction, applyRep, updateTerritory } from '../systems/factions.js';
import { HITTER_CRASH_MS, HITTER_CRASH_SHAKES } from '../systems/hitter.js';
import { updateIncidents } from '../systems/incidents.js';
import { updateNpcActors } from '../systems/npc_ai.js';
import { firstBlockingStructure, moveBodyAgainstStructures } from '../systems/physicality.js';
import { checkHustles, rollHustles } from '../systems/progression_routes.js';
import { recordFullHighAtPlayer, syncRecognitionVisit } from '../systems/recognition.js';
import { updateHUD } from '../ui/hud.js';

export let last;

export function update(now) {
  try {
    const dt = Math.min(50, now - last); last = now;
    if (state.mode === 'playing' && state.hitPause <= 0) {
      updateWorld(dt);
    } else if (state.hitPause > 0) {
      // freeze frame — only decay timers
      state.hitPause -= dt;
    } else if (state.mode === 'cookmini') {
      updateHeatMini(dt);
    }
    // smoke overlay countdown (post-burn, runs regardless of mode)
    if (state.smokeT > 0) state.smokeT = Math.max(0, state.smokeT - dt);
    drawAll();
  } catch (err) {
    console.error('update error', err);
    window.__updateErr = err && (err.stack || err.message);
  }
  requestAnimationFrame(update);
}

export function updateWorld(dt) {
  // v16: keyboard movement is event-latched. A held key remains down until keyup,
  // modal clearing, blur, or visibility loss; key-repeat cadence is never release evidence.
  // input — v13 wave 5: P.stunT gates ALL inputs (lurch grab, fallen priest grabs at p2).
  let vx=0, vy=0;
  // tick status timers regardless
  if (P.stunT > 0) P.stunT = Math.max(0, P.stunT - dt);
  if (P.slowT > 0) P.slowT = Math.max(0, P.slowT - dt);
  const stunned = P.stunT > 0;
  if (!stunned) {
    if (state.keys.has('w') || state.keys.has('arrowup')) { vy = -1; P.facing = 'up'; }
    if (state.keys.has('s') || state.keys.has('arrowdown')) { vy = 1; P.facing = 'down'; }
    if (state.keys.has('a') || state.keys.has('arrowleft')) { vx = -1; P.facing = 'left'; }
    if (state.keys.has('d') || state.keys.has('arrowright')) { vx = 1; P.facing = 'right'; }
    if (vx && vy) { vx *= 0.7071; vy *= 0.7071; }
    // analog joystick input overrides keys when active
    if (state.stickMag && state.stickMag > 0) {
      vx = state.stickX * state.stickMag;
      vy = state.stickY * state.stickMag;
      // facing — derived from larger axis
      if (Math.abs(vx) > Math.abs(vy)) P.facing = vx > 0 ? 'right' : 'left';
      else P.facing = vy > 0 ? 'down' : 'up';
    }
  }
  let spd = P.speed;
  if (P.rockedT>0) spd *= 1.8;
  if (P.crashT>0) spd *= 0.5;
  if (P.slowT>0) spd *= 0.5; // priest holy water slow
  let sprinting = !stunned && state.keys.has('shift');
  if (sprinting && (vx||vy)) spd *= 1.7;
  const newX = P.x + vx*spd*(dt/16);
  const newY = P.y + vy*spd*(dt/16);
  // Every declared structure shares this one physicality source.
  moveBodyAgainstStructures(P,newX,newY);
  P.x = clamp(P.x, 0, WORLD.w - P.w);
  P.y = clamp(P.y, 0, WORLD.h - P.h);

  // anim
  if (vx || vy) {
    P.frameT += dt;
    if (P.frameT > 120) { P.frameT = 0; P.frame = ((P.frame||0)+1)%4; }
    // dust kick-up under feet
    P.dustT = (P.dustT||0) + dt;
    if (P.dustT > 110) {
      P.dustT = 0;
      particles.push({
        x: P.x+P.w/2 + (Math.random()-.5)*6,
        y: P.y+P.h - 2 + Math.random()*2,
        vx: -vx*0.4 + (Math.random()-.5)*0.4,
        vy: -0.3 - Math.random()*0.2,
        life: 380 + Math.random()*200,
        c: 'rgba(180,160,120,0.55)',
        sz: 2,
      });
    }
  } else { P.frame = 0; P.frameT = 0; }

  // shakes — slowed in v11 per user feedback
  P.shakes += 0.0008 * dt;
  if (sprinting && (vx||vy)) P.shakes += 0.012 * dt;
  P.shakes = clamp(P.shakes, 0, 100);
  if (P.shakes >= 100 && Math.random() < 0.006) damagePlayer(2);

  // passive HP regen at THE BLOCK (home base)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'block') && P.hp < P.maxHp && state.mode === 'playing') {
    P.hp = Math.min(P.maxHp, P.hp + 0.006 * dt);
  }

  // wanted timer
  manageCops(dt);
  updateKingdomBattle(dt);
  syncRecognitionVisit();

  // status effects
  if (P.rockedT > 0) {
    P.rockedT -= dt;
    if (P.rockedT <= 0) {
      P.rockedT = 0;
      if (P.hitterHigh) {
        // v22 hitter — the rougher crash (I-BAD-TRADE). Longer, steeper, and it
        // records nothing: a hitter high is not a full high, so the room gets no
        // recognition credit. The room does not respect the pipe.
        P.hitterHigh = false; P.crashT = HITTER_CRASH_MS;
        P.shakes = clamp(P.shakes + HITTER_CRASH_SHAKES, 0, 100);
        audio.crash();
        state.flash = 1; state.flashColor = 'rgba(180,80,180,.35)';
        toast('the crash arrives.\nahead of schedule.', 2200);
      } else {
        P.crashT = 8000;
        P.shakes = clamp(P.shakes+30, 0, 100);
        audio.crash();
        state.flash = 1; state.flashColor = 'rgba(180,80,180,.35)';
        toast('the crash arrives.\non schedule.', 2200);
        recordFullHighAtPlayer({deferMs:2300});
      }
    }
  } else if (P.crashT > 0) {
    P.crashT -= dt;
    if (P.crashT <= 0) P.crashT = 0;
  }
  if (P.attackCd > 0) P.attackCd -= dt;
  if (P.attacking > 0) P.attacking -= dt;
  if (P.iframes > 0) P.iframes -= dt;
  if (P.hitFlash > 0) P.hitFlash -= dt;

  // tweaker vision
  if (state.tweakerCdT > 0) state.tweakerCdT -= dt;
  if (state.keys.has('f') && state.tweakerT > 0 && P.brain > 0) {
    state.tweakerT -= dt;
    P.brain = Math.max(0, P.brain - dt*0.002);
    if (P.brain <= 0) {
      state.tweakerT = 0;
      toast('your brain has nothing left to give.', 1800);
    }
  } else if (!state.keys.has('f')) {
    state.tweakerT = 0;
  }
  document.getElementById('tweaker').classList.toggle('on', state.tweakerT > 0);

  // day/night cycle — 4 min cycle
  state.dayTime += dt / 240000;
  if (state.dayTime >= 1) {
    state.dayTime -= 1; state.day++; P.lifetime.dayCount = state.day;
    rollWeather();
    // v13 wave 6.5 — daily-reset accumulating counters at dawn (the *Today fields).
    // the *Day fields (kombuchaAskDay, priestDonateDay, etc.) self-reset via
    // "=== state.day" comparison, so they don't need to be zeroed.
    resetDailyCounters();
    rollHustles();
    if (state.day >= 7) unlockAchievement('tuesday_again');
    toast('· day ' + state.day + ' ·\n' + (state.weather==='rain'?'it is raining.':state.weather==='fog'?'fog.':'a tuesday.'), 2400);
    broadcastNews('day ' + state.day + ' has arrived. weather: ' + state.weather + '.');
    feedPost("it is day "+state.day+". this is somehow your life.", '@crackheadcent');
    // occasional garbage truck on new day
    if (Math.random() < 0.5) setTimeout(garbageTruckRumble, 8000);
    // v13 wave 7 — fire day-specific events at dawn rollover (each guarded by once-per-save flag)
    fireDayEvents();
    // v13 wave 7 — mom proud-call rolls at dawn (spiritual LIKED+ only, 1×/day)
    setTimeout(maybeFireMomProudCall, 12000 + Math.random()*30000);
    // v13 wave 8b — mom drops a free bus pass at dawn if spiritual >= liked AND player doesn't have one.
    // Once per day via momBusPassDay stamp. Surfaces a phone-feed line.
    if (P.faction && P.faction.spiritual >= 10 && state.flags.momBusPassDay !== state.day) {
      state.flags.momBusPassDay = state.day;
      if (!hasBusPass()) {
        giveBusPass(true);
        feedPost("mom left a bus pass on the door. mom does not say where it came from.", '@hardcandy');
        setTimeout(() => toast("+ a bus pass\nmom left it on the door.\nthe door does not lock.", 3200), 6000);
      }
    }
    // v13 wave 7 — mom's apartment hideout rent: $30/day if owned. failure evicts.
    if (state.flags && state.flags.momHideoutOwned) {
      if (P.cash >= 30) {
        P.cash -= 30; state.flags.momRentDay = state.day;
        toast("- $30\nmom's couch costs.\nshe says it does not.\nit does.", 3000);
      } else {
        state.flags.momHideoutOwned = false;
        toast("ben put your bag in the hallway.\nthe spare key does not fit anymore.\n(mom's couch — closed.)", 4000);
        feedPost("got put out. ben works late, ben changed the locks.", '@crackheadcent');
        adjustFaction('spiritual', -3);
      }
    }
  }
  applyDayNight();

  // v13 wave 3 — intro chain suppression. during the intro, suppress ambient phone calls,
  // random world events, and hustle generation so day 1 is focused on the three intro beats.
  // the mom intro tip is a separate forced timer (see momTipT below) and is NOT gated by this.
  const introActive = state.flags && !state.flags.introDone;
  // v13 wave 7 — silence window (day 7 event). suppresses ticker + phone + ambient calls for 4 min.
  const silenceActive = state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now();
  // v13 wave 7 — spiritual HATED: mom's ambient call line stops (gates the proud-call only;
  // ambient calls overall still ring). enforced inside maybeFireMomProudCall via faction check.

  // phone calls every 90-240s
  state.phoneT = (state.phoneT||120000) - dt;
  if (state.phoneT <= 0) {
    state.phoneT = 90000 + Math.random()*150000;
    if (!introActive && !silenceActive && Math.random() < 0.8) ringPhone();
  }

  // v13 wave 3 — mom intro tip timer (~30s after game start, once per save)
  if (state.flags && !state.flags.momIntroFired) {
    state.momTipT = (state.momTipT == null ? 30000 : state.momTipT) - dt;
    if (state.momTipT <= 0) fireMomIntroTipOnce();
  }

  // continuous hustle check (cheap, only re-evaluates undone hustles)
  state.hustleCheckT = (state.hustleCheckT||0) + dt;
  if (state.hustleCheckT > 800) { state.hustleCheckT = 0; checkHustles(); }

  // v15 physical neighborhood incidents. This call sits after core player/status/day timing;
  // it cannot skip or replace the 18s high -> 8s crash transition above.
  updateIncidents(dt, introActive, silenceActive);
  updateGuidance(dt);

  // random world events — every 15-35s
  state.eventT = (state.eventT||15000) - dt;
  if (state.eventT <= 0) {
    state.eventT = 15000 + Math.random()*20000;
    if (!introActive && !silenceActive && !state.incident) fireRandomEvent();
  }

  // v13 wave 6 — interactive props: cooldown / tip-over animation tick + bottle respawn
  for (const ip of interactiveProps) {
    if (ip.type === 'trashcan') {
      if (ip.cdT > 0) ip.cdT -= dt;
      if (ip.tipT > 0) ip.tipT -= dt;
      if (ip.rotPulse > 0) ip.rotPulse -= dt;
    } else if (ip.type === 'b_bottle' && ip.broken) {
      ip.respawnT -= dt;
      if (ip.respawnT <= 0) {
        // pop a fresh one in
        ip.broken = false;
        const pool = [
          {x:140, y:300}, {x:680, y:240}, {x:1100, y:540}, {x:1740, y:520},
          {x:240, y:980}, {x:900, y:1100}, {x:1500, y:1240}, {x:1700, y:1180},
          {x:320, y:1420},{x:540, y:1700}, {x:1100, y:1640}, {x:1380, y:1700},
        ];
        const sp = pool[Math.floor(Math.random()*pool.length)];
        ip.x = sp.x + (Math.random()-.5)*40;
        ip.y = sp.y + (Math.random()-.5)*40;
      }
    }
  }
  // v13 wave 6 — dumpster cooldown tick (used to gate re-dig)
  for (const p of PROPS) {
    if (p.type === 'dumpster' && p.diveCdT > 0) {
      p.diveCdT -= dt;
      if (p.diveCdT <= 0) { p.looted = false; }
    }
  }

  // v13 wave 8b — faction territory ticker (heat in hated, greetings + bonuses in liked/loved).
  // pauses automatically when state.mode flips off 'playing' (dialogue / interior / heist / boss).
  updateTerritory(dt);
  // v13 wave 8b — edge-glow effect (zone-border crossing). decays each frame; rendered post-world.
  if (state.borderGlowT > 0) state.borderGlowT = Math.max(0, state.borderGlowT - dt);
  // detect zone-border crossings (zone change in last frame) and arm the glow.
  const curZoneId = state.territoryZoneId || null;
  if (state.lastZoneId !== curZoneId) {
    const z = currentZone();
    if (z && state.lastZoneId != null && z.id !== state.lastZoneId) {
      // tint the glow by destination faction
      const colors = { street:'#a04848', scrap:'#c08038', spiritual:'#d8c068' };
      state.borderGlowT = 600;
      state.borderGlowColor = colors[z.faction] || '#888';
      state.borderGlowRect = { x:z.x, y:z.y, w:z.w, h:z.h };
    }
    state.lastZoneId = curZoneId;
  }

  // v13 wave 6 — first-time underpass entry: echo line + feed post
  if (state.flags && !state.flags.underpassEntered && state.mode === 'playing') {
    if (inZone(P.x+P.w/2, P.y+P.h/2, 'underpass')) {
      state.flags.underpassEntered = true;
      feedPost("under the bridge. the bridge has ears.", '@crackheadcent');
      toast("the air changes.\nyou can hear yourself walk.", 3600);
      saveGame();
    }
  }

  // v13 wave 8a — first-time entry feed posts for the four new zones. once per save.
  if (state.flags && state.mode === 'playing') {
    const cx = P.x + P.w/2, cy = P.y + P.h/2;
    if (!state.flags.trainYardEntered && inZone(cx, cy, 'trainyard')) {
      state.flags.trainYardEntered = true;
      feedPost("trains stopped running here. they still come through.", '@blocklog');
      toast("the rails hum.\nthe rails are warm.\nthe rails are not used.", 4000);
      saveGame();
    } else if (!state.flags.parkEntered && inZone(cx, cy, 'park')) {
      state.flags.parkEntered = true;
      feedPost("the pigeons remember faces. the philosopher remembers names.", '@hardcandy');
      toast("you are in the park.\nthe fountain is still running.", 3600);
      saveGame();
    } else if (!state.flags.skidRowEntered && inZone(cx, cy, 'skidrow')) {
      state.flags.skidRowEntered = true;
      feedPost("skid row knows you didn't ask first.", '@crackheadcent');
      toast("the alleys are tight.\nthe air is heavier here.", 3600);
      saveGame();
    } else if (!state.flags.oldSchoolEntered && inZone(cx, cy, 'oldschool')) {
      state.flags.oldSchoolEntered = true;
      feedPost("the old school still has copper in the walls. the school still has brutus in the gym.", '@blocklog');
      toast("the old school stands.\nthe paint is gone.\nthe building is not.", 3600);
      saveGame();
    } else if (!state.flags.warehouseRowEntered && inZone(cx, cy, 'warehouse_row')) {
      state.flags.warehouseRowEntered = true;
      feedPost("warehouse row received nothing. returns accepted nothing.", '@blocklog');
      toast("two warehouses.\nthree unit numbers.\none manifest refuses all of them.", 3800);
      saveGame();
    } else if (!state.flags.canalEntered && inZone(cx, cy, 'canal')) {
      state.flags.canalEntered = true;
      feedPost("the water department marked the canal water pending.", '@crackheadcent');
      toast("the canal is dry.\nthe water gauge says nine.\ngutter greg counted the duck.", 4000);
      saveGame();
    } else if (!state.flags.theLotEntered && inZone(cx, cy, 'the_lot')) {
      state.flags.theLotEntered = true;
      feedPost("walk-ins accepted at the office. tax help unavailable.", '@hardcandy');
      toast("the lot has forty spaces.\nzero cars.\none leasing guy.", 3800);
      saveGame();
    } else if (!state.flags.blueTarpCourtEntered && inZone(cx, cy, 'blue_tarp_court')) {
      state.flags.blueTarpCourtEntered = true;
      feedPost("four tarps filed one court date. weather is named as counsel.", '@blocklog');
      toast("four tarps share one court date.\nnone brought identification.", 3800);
      saveGame();
    } else if (!state.flags.cartKeepEntered && inZone(cx, cy, 'cart_cavalry_keep')) {
      state.flags.cartKeepEntered = true;
      feedPost("the cart cavalry formed a line. one wheel attended.", '@hardcandy');
      toast("six carts form a cavalry line.\none has a wheel.", 3800);
      saveGame();
    } else if (!state.flags.copperChoirEntered && inZone(cx, cy, 'copper_choir_yard')) {
      state.flags.copperChoirEntered = true;
      feedPost("the copper choir is holding b flat until inventory closes.", '@blocklog');
      toast("the copper choir rehearses b flat.\nattendance is mandatory on paper.", 4000);
      saveGame();
    } else if (!state.flags.throneDitchEntered && inZone(cx, cy, 'throne_ditch')) {
      state.flags.throneDitchEntered = true;
      feedPost("the ditch has a chair. the chair has jurisdiction.", '@crackheadcent');
      toast("the ditch has a chair in it.\nthe chair has jurisdiction.", 4000);
      saveGame();
    }
  }

  // v13 wave 8a — park bench sit mechanic ticker.
  // sitting: +1 brain per 2s. shakes unchanged. >60s: BENCH_PRESS achievement.
  // every 30s past 60s, an ambient passer-by line may surface.
  if (state.sittingOnBench) {
    state.benchSitT = (state.benchSitT||0) + dt;
    state.benchSitGainT = (state.benchSitGainT||0) + dt;
    while (state.benchSitGainT >= 2000) {
      state.benchSitGainT -= 2000;
      P.brain = Math.min(100, P.brain + 1);
    }
    if (state.benchSitT >= 60000 && !state.achievements.has('bench_press')) {
      unlockAchievement('bench_press');
    }
    if (state.benchSitT >= 60000) {
      state.benchSitPasserT = (state.benchSitPasserT||0) + dt;
      if (state.benchSitPasserT > 30000) {
        state.benchSitPasserT = 0;
        const lines = [
          "the philosopher said you'd be here.\nshe was right.",
          "a pigeon walks past.\nit nods.\nyou nod.",
          "a jogger passes.\nshe is talking on the phone.\nshe is talking about you.",
          "the fountain coughs.\nthe fountain continues.",
          "you have been here a while.\nthe bench has been here longer.",
        ];
        toast(lines[Math.floor(Math.random()*lines.length)], 3200);
      }
    }
  }

  // v13 wave 8a — price guy daily spawn check (every 3 days, day start). gated by day % 3
  // at the call site so we don't hammer maybeSpawnPriceGuy every frame on non-spawn days.
  if (state.flags && state.mode === 'playing'
      && state.day % 3 === 0
      && state.flags.priceGuyDay !== state.day) {
    maybeSpawnPriceGuy();
  }

  // v13 wave 8a — park night cash pile. 30% chance each new night, $20-40 at the swing set.
  // gated by day-stamp so it rolls at most once per night.
  if (state.flags && state.mode === 'playing' && isNight()) {
    if (state.flags.parkNightCashDay !== state.day) {
      state.flags.parkNightCashDay = state.day;
      if (Math.random() < 0.30) {
        // v13 wave 8b — territory mult applies in spiritual liked/loved (park is spiritual)
        const baseAmt = 20 + Math.floor(Math.random() * 21);
        const amt = Math.round(baseAmt * (state.territoryCashMult || 1.0));
        runtime.cashPiles.push({
          id: 'cp_park_night_' + state.day,
          x: 2510, y: 1320, amt, collected: false,
        });
        feedPost("the swings move on their own at night. they don't.", '@crackheadcent');
      }
    }
  }

  // v13 wave 6 — public phone ring scheduler. 4-8 min between rings. answer window 30s.
  if (state.publicPhoneT == null) state.publicPhoneT = 240000 + Math.random()*240000;
  if (state.phonePropRingT > 0) {
    state.phonePropRingT -= dt;
    if (state.phonePropRingT <= 0) {
      state.phonePropRingT = 0;
      // missed
    }
  } else {
    state.publicPhoneT -= dt;
    if (state.publicPhoneT <= 0 && state.mode === 'playing' && !introActive) {
      state.publicPhoneT = 240000 + Math.random()*240000;
      state.phonePropRingT = 30000; // 30s answer window
      audio.dialogue();
      feedPost("a phone is ringing in the scrap yard.", '@local_eyewitness');
    }
  }

  // v13 wave 6 — fed dog: 200px cop-discomfort radius (cops at 0.5x speed near the chained dog).
  // Applied here so it persists for the whole game regardless of dialogue state.
  const fedDog = (state.quests.scrap_dog && state.quests.scrap_dog.state === 'fed')
    ? runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead)
    : null;
  if (fedDog) {
    for (const n of runtime.npcs) {
      if (!n.cop && n.id !== 'brendan' && n.id !== 'horsecop') continue;
      const dx = (n.x+n.w/2) - (fedDog.x+fedDog.w/2);
      const dy = (n.y+n.h/2) - (fedDog.y+fedDog.h/2);
      if (dx*dx + dy*dy < 200*200) {
        n.dogSpookSlow = 1; // flag — read in cop AI for the 0.5x mult; cleared next frame
      }
    }
  }
  // also: fed wandering follower dog has the same radius
  const followerDog = runtime.npcs.find(n => n.id === 'freed_dog_follower' && !n.dead);
  if (followerDog) {
    for (const n of runtime.npcs) {
      if (!n.cop && n.id !== 'brendan' && n.id !== 'horsecop') continue;
      const dx = (n.x+n.w/2) - (followerDog.x+followerDog.w/2);
      const dy = (n.y+n.h/2) - (followerDog.y+followerDog.h/2);
      if (dx*dx + dy*dy < 200*200) {
        n.dogSpookSlow = 1;
      }
    }
  }

  // v20 landing 3 — the two concession clocks (choir office hours, the dryer cycle).
  // they run on world time like the sun and the dog; menus pause them with everything else.
  updateConcessionClocks(dt);

  // v13 wave 6 — freed dog wandering schedule. while state==='freed', a follower can spawn
  // every 1-3 min. when present, follow window counts down ~60s before despawn.
  if (state.quests.scrap_dog && state.quests.scrap_dog.state === 'freed') {
    if (followerDog) {
      state.freedDogFollowT -= dt;
      if (state.freedDogFollowT <= 0) {
        followerDog.dead = true; // walks off
        state.freedDogT = 90000 + Math.random()*180000; // 1.5-4.5 min before next return
      }
    } else {
      state.freedDogT -= dt;
      if (state.freedDogT <= 0 && state.mode === 'playing') {
        spawnFreedDogFollower();
        state.freedDogFollowT = 60000; // ~60s follow window
      }
    }
  }

  // v13 wave 6 — tail wag + stand-up when player approaches chained dog
  const sdog = runtime.npcs.find(n => n.id === 'scrap_dog' && !n.dead && n.chained);
  if (sdog) {
    const dx = (P.x+P.w/2) - (sdog.x+sdog.w/2);
    const dy = (P.y+P.h/2) - (sdog.y+sdog.h/2);
    const near = dx*dx + dy*dy < 100*100;
    sdog.tailWag = near ? Math.min(1, (sdog.tailWag||0) + dt*0.003) : Math.max(0, (sdog.tailWag||0) - dt*0.002);
  }

  // ambient SFX scheduler
  state.ambientT = (state.ambientT||4000) - dt;
  if (state.ambientT <= 0) {
    state.ambientT = 3500 + Math.random()*4500;
    const r = Math.random();
    if (isNight()) {
      if (r < 0.5) audio.cricket();
      else if (r < 0.7) audio.dogBark();
      else if (r < 0.85) audio.cough();
      else audio.carDoor();
    } else {
      if (r < 0.4) audio.traffic();
      else if (r < 0.6) audio.dogBark();
      else if (r < 0.75) audio.cough();
      else audio.carDoor();
    }
    if (P.wanted > 0 && Math.random()<0.3) audio.copSiren();
  }

  // ambient dust motes — drift across when night or rain
  state.dustT = (state.dustT||0) - dt;
  if (state.dustT <= 0) {
    state.dustT = 280 + Math.random()*350;
    const drift = state.weather==='rain' ? 'rgba(180,200,220,.6)' : 'rgba(232,210,160,.32)';
    particles.push({
      x: state.cam.x + Math.random()*W,
      y: state.cam.y - 4 + Math.random()*H,
      vx: 0.3 + Math.random()*0.4,
      vy: -0.15 + Math.random()*0.3,
      life: 4500 + Math.random()*1500,
      c: drift,
      sz: 1 + (Math.random()<0.2 ? 1 : 0),
      glow: false,
    });
  }
  // rain droplets when raining
  if (state.weather === 'rain') {
    for (let i=0;i<3;i++) {
      particles.push({
        x: state.cam.x + Math.random()*W,
        y: state.cam.y - 8,
        vx: -1.2,
        vy: 8,
        life: 800,
        c: 'rgba(160,200,240,0.5)',
        sz: 1,
      });
    }
  }

  // combo decay
  if (state.combo > 0) {
    state.comboT -= dt;
    if (state.comboT <= 0) state.combo = 0;
  }

  // hit pause
  if (state.hitPause > 0) state.hitPause -= dt;

  // v13 wave 5 — church visit counter (debounced edge — count one per entry, not per frame).
  // gates the fallen-priest phone call trigger.
  const inChurch = inZone(P.x+P.w/2, P.y+P.h/2, 'church');
  if (inChurch && !state.inChurchPrev) {
    state.counters.churchVisits = (state.counters.churchVisits||0) + 1;
    maybeFireFallenPriestCall();
  }
  state.inChurchPrev = inChurch;

  // v13 wave 5 — OUTRAN_THE_PRIEST survival timer (60s alive vs the fallen priest)
  const fallen = runtime.npcs.find(n => n.isOmalleyFallen && !n.dead);
  if (fallen) {
    state.counters.omalleyFallenSurviveT = (state.counters.omalleyFallenSurviveT||0) + dt;
    if (state.counters.omalleyFallenSurviveT >= 60000) unlockAchievement('outran_the_priest');
  } else {
    state.counters.omalleyFallenSurviveT = 0;
  }

  // conductor wait achievement
  const conductor = runtime.npcs.find(n=>n.id==='conductor');
  if (conductor && !conductor.dead) {
    const dx = (P.x+P.w/2) - (conductor.x+conductor.w/2), dy = (P.y+P.h/2) - (conductor.y+conductor.h/2);
    if (dx*dx + dy*dy < 80*80) {
      state.conductorWaitT += dt;
      if (state.conductorWaitT >= 60000) unlockAchievement('the_conductor_knows');
    } else state.conductorWaitT = 0;
  }

  // cash piles — auto-collect when near or visible by tweaker
  for (const c of runtime.cashPiles) {
    if (c.collected) continue;
    const dx = (P.x+P.w/2) - c.x, dy = (P.y+P.h/2) - c.y;
    if (dx*dx + dy*dy < 14*14) {
      c.collected = true; state.cashPilesCollected.add(c.id);
      // v13 wave 4 — propane torch pickup (a 'cash pile' variant tagged with tool)
      if (c.tool === 'propane_torch') {
        // v22 wave 5.5 — ownership counts the locker (no duplicate torches), and a
        // crowbar in the slot is displaced to pete's glass, never destroyed.
        if (!ownsTool('propane_torch')) {
          const displaced = equipTool('propane_torch');
          audio.pickup();
          toast("+ a propane torch (dented)\n(equipped.)\nit doesn't care." + (displaced ? "\nthe crowbar goes to pete's glass.\nthis is the arrangement." : ""), 3400);
          feedPost("picked up a torch. found it. don't ask.", '@crackheadcent');
          saveGame();
        }
        continue;
      }
      // v13 wave 5 — equip drop (the priest's collar). generic equip-id-tagged pickup.
      if (c.equip && EQUIPMENT[c.equip]) {
        const slot = EQUIPMENT[c.equip].slot;
        P.equip[slot] = c.equip;
        applyEquipStats();
        audio.coin();
        toast("+ " + EQUIPMENT[c.equip].n + "\n(equipped.)", 3400);
        saveGame();
        continue;
      }
      P.cash += c.amt; audio.pickup();
      // v13 wave 3 — intro_remember accumulator (counts only day-1 cash gains during intro)
      if (state.flags && !state.flags.introDone) {
        state.counters.introCashEarned = (state.counters.introCashEarned||0) + c.amt;
      }
      // v13 wave 7 — day 14 inheritance has its own copy + rep deltas
      if (c.isInheritance) {
        state.flags.day14Collected = true;
        toast(`+ $${c.amt}\n\nyou don't recognize the bill.\nyou don't recognize the wallet.\nyou recognize the smell.`, 4800);
        feedPost("someone came into money. someone always does.", '@hardcandy');
        applyRep({ street: 2, spiritual: -1 });
      } else {
        toast(c.intro ? `+ $${c.amt}\nyou bend down. the ten dollars is yours now.\n(it was always there.)` : `+ $${c.amt}\n(found in a corner.)`, c.intro?2400:1400);
      }
      tryCompleteIntroRemember();
      saveGame();
    }
  }

  // v13 wave 3 — intro_remember alt completion: any cash >= $10 during the intro
  // (new save starts at $0; any source that gets you to $10 closes the loop).
  if (state.flags && !state.flags.introDone && state.quests.intro_remember && !state.quests.intro_remember.done) {
    if (P.cash >= 10) {
      state.counters.introCashEarned = Math.max(state.counters.introCashEarned||0, 10);
      tryCompleteIntroRemember();
    }
  }

  // v13 wave 3 — pigeon crown world pickup. drawn in render pass.
  if (state.crownPickup && !state.crownPickup.collected) {
    const cp = state.crownPickup;
    const dx = (P.x+P.w/2) - cp.x, dy = (P.y+P.h/2) - cp.y;
    if (dx*dx + dy*dy < 18*18) {
      cp.collected = true;
      const slot = EQUIPMENT.pigeon_crown.slot;
      P.equip[slot] = 'pigeon_crown';
      applyEquipStats();
      audio.coin();
      toast("· the crown ·\nit is heavier than it looks.\nthe pigeons stop walking. they watch.\n+ EQUIPPED · the pigeon king's crown", 4500);
      if (!state.quests.pigeon_crown.done) {
        state.quests.pigeon_crown.done = true;
        questToast("THE PIGEON KING'S LOST CROWN");
        unlockAchievement('head_that_wears');
      }
      saveGame();
    }
  }

  // v13 wave 3 — stripe's package auto-delivery near the conductor (within 60px)
  if (state.flags && state.flags.hasStripePackage && state.mode === 'playing') {
    const cn = runtime.npcs.find(n=>n.id==='conductor');
    if (cn && !cn.dead) {
      const dx2 = (P.x+P.w/2)-(cn.x+cn.w/2);
      const dy2 = (P.y+P.h/2)-(cn.y+cn.h/2);
      if (dx2*dx2+dy2*dy2 < 60*60) {
        state.flags.hasStripePackage = false;
        P.inventory = P.inventory.filter(i => i.id !== 'stripe_package');
        if (state.quests.stripe_package && !state.quests.stripe_package.done) {
          state.quests.stripe_package.done = true;
          P.cash += 40; P.cred += 3;
          questToast("STRIPE'S PACKAGE");
          unlockAchievement('exact_change');
        }
        audio.coin();
        dialogue('THE CONDUCTOR',
          "the conductor unfolds the package without looking at it.\n'stripe's name. stripe's money.\nyou are stripe's leg.\nit is monday.'", [
            { label: '+$40 · +3 cred · leave.', action: () => {} },
          ]);
        saveGame();
      }
    }
  }

  // hide pawn at night
  const pete = runtime.npcs.find(n=>n.id==='pete');
  if (pete) pete.shopClosed = isNight();

  updateNpcActors(dt);

  // particles
  for (let i=particles.length-1;i>=0;i--) {
    const p = particles[i];
    p.life -= dt;
    p.x += p.vx; p.y += p.vy;
    p.vx *= 0.92; p.vy *= 0.92;
    if (p.gravity) p.vy += p.gravity;
    if (p.life <= 0) particles.splice(i,1);
  }
  // particle pool cap
  if (particles.length > 220) particles.splice(0, particles.length - 220);

  // v13 wave 5 — projectile update (bottles + holy water vials).
  // generic primitive: kind drives only visuals + impact-side-effects, motion + collision are shared.
  for (let i=runtime.projectiles.length-1; i>=0; i--) {
    const pr = runtime.projectiles[i];
    pr.life -= dt;
    pr.x += pr.vx * (dt/1000);
    pr.y += pr.vy * (dt/1000);
    pr.rot += pr.rotVel;
    let dead = false;
    // wall collision uses the same declared structure source as movement.
    if (firstBlockingStructure({x:pr.x-.5,y:pr.y-.5,w:1,h:1})) dead = true;
    // world edge
    if (!dead && (pr.x < 0 || pr.x > WORLD.w || pr.y < 0 || pr.y > WORLD.h)) dead = true;
    // player hit
    if (!dead && rectsOverlap({x:pr.x-4, y:pr.y-4, w:8, h:8}, P)) {
      damagePlayer(pr.dmg, pr.from);
      if (pr.slowMs > 0) P.slowT = Math.max(P.slowT||0, pr.slowMs);
      if (pr.kind === 'bottle') {
        audio.bottleHit();
        for (let j=0;j<10;j++) particles.push({x:pr.x,y:pr.y,vx:(Math.random()-.5)*5,vy:(Math.random()-.5)*5,life:380,c:'#a07020',sz:2});
      } else if (pr.kind === 'holy') {
        audio.holyWaterHit();
        for (let j=0;j<12;j++) particles.push({x:pr.x,y:pr.y,vx:(Math.random()-.5)*4,vy:(Math.random()-.5)*4,life:500,c:'#a0d0ff',sz:3,glow:true});
      }
      dead = true;
    }
    if (!dead && pr.life <= 0) {
      // expired mid-air — small fizzle, no damage
      if (pr.kind === 'bottle') audio.bottleHit();
      dead = true;
    }
    if (dead) runtime.projectiles.splice(i,1);
  }
  // projectile pool cap (paranoia)
  if (runtime.projectiles.length > 40) runtime.projectiles.splice(0, runtime.projectiles.length - 40);

  // boss phase transitions — v13 wave 5: phases now shift the ATTACK PATTERN, not just numbers.
  // tony (rank-4 boss):
  //   p1 (100-66%): standard chase-bite (default archetype).
  //   p2 (66-33%): converts to CHARGER + spawns 2 sherri adds ("he whistles. someone answers.").
  //   p3 (33-0%): BERSERK charger (windup 400ms, lunge ×3 speed, no breathing room).
  // existing coat-tearing flavor is preserved on each phase entry.
  if (state.bossKind === 'tony' && state.bossActive && state.bossNPC && !state.bossNPC.dead) {
    const b = state.bossNPC;
    const pct = b.hp / b.maxHp;
    let newPhase = state.bossPhase;
    if (pct < 0.66 && state.bossPhase < 2) newPhase = 2;
    if (pct < 0.33 && state.bossPhase < 3) newPhase = 3;
    if (newPhase !== state.bossPhase) {
      state.bossPhase = newPhase;
      b.coatsOff = newPhase;
      if (newPhase === 2) {
        b.archetype = 'charger';
        b.chargeState = 'idle'; b.chargeT = 0; b.chargeCdT = 0;
        b.speed = 2.4;
        toast("tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers.", 3200);
        // spawn 2 sherri adds 80px to either side
        const sherri1 = {
          id: 'sherri_boss_'+Math.random().toString(36).slice(2,6),
          name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
          x: b.x - 80, y: b.y, w: 26, h: 30, color: '#3a1820',
          hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
          aggroOnHit: true, dmg: 5, archetype: 'swarmer', attackCd: 0, showHp: false,
        };
        const sherri2 = { ...sherri1, id: 'sherri_boss_'+Math.random().toString(36).slice(2,6), x: b.x + 80 };
        runtime.npcs.push(sherri1, sherri2);
        broadcastNews("BREAKING: TRE BAG TONY DOWN TO 2 COATS. SOMETHING ELSE IS COMING.");
        feedPost("tony is on coat 2. and somebody else just showed up.", '@the_corner');
      } else if (newPhase === 3) {
        b.archetype = 'charger';
        b.berserk = true;
        b.chargeState = 'idle'; b.chargeT = 0; b.chargeCdT = 0;
        b.speed = 3.0; b.dmg = 16;
        toast("tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up.", 3500);
        // bossRoar loops higher pitch — fake it with a 3-shot quick stack
        audio.bossRoar(); setTimeout(()=>audio.bossRoar(), 200); setTimeout(()=>audio.bossRoar(), 420);
        broadcastNews("BREAKING: TRE BAG TONY BARE-KNUCKLE. CALL TIME OF DEATH ALREADY.");
        feedPost("tony has no coats. tony is lunging now. like a dog.", '@the_corner');
      }
      audio.bossRoar();
      state.shake = 12;
      const coatColors = {2: '#4a2018', 3: '#2a1010'};
      const cc = coatColors[newPhase] || '#5a2020';
      for (let i=0;i<24;i++) {
        particles.push({
          x: b.x+b.w/2, y: b.y+b.h/2,
          vx: (Math.random()-.5)*10, vy: (Math.random()-.7)*8,
          life: 1400, c: cc, sz: 5, gravity: 0.25,
        });
      }
    }
  }

  // v13 wave 5 — Brutus Older phase machine (parallel to boss tony).
  //   p1 (100-50%): charger from the start (already archetype='charger_older').
  //   p2 (50-25%): charger + spawns 1 sherri swarm pair every 8s.
  //   p3 (25-0%): berserk charger + grabber-on-contact (HE STARTS GRABBING).
  if (state.brutusOlderActive && state.brutusOlderNPC && !state.brutusOlderNPC.dead) {
    const bo = state.brutusOlderNPC;
    const pct = bo.hp / bo.maxHp;
    state.brutusOlderPhase = state.brutusOlderPhase || 1;
    let newP = state.brutusOlderPhase;
    if (pct < 0.5 && state.brutusOlderPhase < 2) newP = 2;
    if (pct < 0.25 && state.brutusOlderPhase < 3) newP = 3;
    if (newP !== state.brutusOlderPhase) {
      state.brutusOlderPhase = newP;
      audio.bossRoar();
      state.shake = 12;
      for (let i=0;i<20;i++) particles.push({x:bo.x+bo.w/2,y:bo.y+bo.h/2,vx:(Math.random()-.5)*8,vy:(Math.random()-.7)*6,life:1200,c:'#8a3030',sz:5,gravity:0.2});
      if (newP === 2) {
        bo.addsT = 0;
        toast("he was warming up before.", 3000);
      } else if (newP === 3) {
        bo.berserk = true;
        bo.grabber = true;
        bo.chargeState = 'idle';
        toast("he doesn't bite anymore.\nhe grabs.", 3200);
      }
    }
    // phase 2 adds — spawn a sherri swarm pair every 8s
    if (state.brutusOlderPhase >= 2) {
      bo.addsT = (bo.addsT||0) + dt;
      if (bo.addsT >= 8000) {
        bo.addsT = 0;
        const liveSwarm = runtime.npcs.filter(n => n.archetype === 'swarmer' && !n.dead);
        if (liveSwarm.length < 2) {
          const a = {
            id: 'sherri_brutus_'+Math.random().toString(36).slice(2,6),
            name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
            x: bo.x - 60, y: bo.y + 20, w: 26, h: 30, color: '#3a1820',
            hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
            aggroOnHit: true, dmg: 5, archetype: 'swarmer', attackCd: 0, showHp: false,
          };
          runtime.npcs.push(a);
        }
      }
    }
    // phase 3 grabber-on-contact: apply stun on contact during cooldown (post-lunge)
    if (state.brutusOlderPhase >= 3 && bo.chargeLanded) {
      bo.chargeLanded = false; // consume
      P.stunT = Math.max(P.stunT||0, 500);
    }
  }

  // rank progression
  while (P.rank < RANKS.length-1 && P.cred >= RANKS[P.rank+1].cred) {
    P.rank++;
    audio.rankUp();
    toast('· RANK UP ·\n' + RANKS[P.rank].name.toUpperCase(), 3000);
    feedPost('promoted to ' + RANKS[P.rank].name + '. the corner watches.', '@the_corner');
    broadcastNews(RANKS[P.rank].name.toUpperCase() + ' has been promoted. the streets react with mild interest.');
    if (P.rank >= 5) unlockAchievement('glass_mayor');
    saveGame();
  }
  if (P.rank >= 4) {
    const ab = BUILDINGS.find(b=>b.locked);
    if (ab) ab.locked = false; // unlocked
  }

  // camera
  state.cam.x = clamp(P.x + P.w/2 - W/2, 0, WORLD.w - W);
  state.cam.y = clamp(P.y + P.h/2 - H/2, 0, WORLD.h - H);

  // shake
  if (state.shake > 0) state.shake *= 0.9;
  if (state.flash > 0) state.flash -= dt/1000;
  if (state.flash < 0) state.flash = 0;

  // auto-save every 45s
  state.autoSaveT = (state.autoSaveT||0) + dt;
  if (state.autoSaveT > 45000) { state.autoSaveT = 0; saveGame(); }

  // interact / smoke at block
  // handled via keypress handler

  // update HUD
  updateHUD();
}

export function applyDayNight() {
  const t = state.dayTime;
  const dnEl = document.getElementById('daynight');
  // canvas drawLighting handles the heavy darkening at night.
  // CSS overlay does only the subtle warm/cool tinting.
  let r=0,g=0,b=0,a=0;
  if (t < 0.2) { r=40;g=50;b=100; a = 0.18; }
  else if (t < 0.3) { const k = (t-0.2)/0.1; r=120+k*100; g=80+k*60; b=80-k*40; a = 0.15 - k*0.1; }
  else if (t < 0.7) { r=255;g=240;b=180; a = 0.05; }
  else if (t < 0.8) { const k = (t-0.7)/0.1; r=240-k*80;g=140-k*60;b=80; a = 0.05 + k*0.13; }
  else { r=40;g=50;b=100; a = 0.18; }
  dnEl.style.background = `rgba(${r|0},${g|0},${b|0},${a.toFixed(3)})`;
  const tEl = document.getElementById('timeOfDay');
  const phase = t<0.2?'night':t<0.3?'dawn':t<0.7?'day':t<0.8?'dusk':'night';
  tEl.textContent = `day ${state.day} · ${phase} · ${state.weather}`;
}

export function init_update() {
  // ---------- UPDATE ----------
  last = 0;
  
  
  
  
  
  
  
}
