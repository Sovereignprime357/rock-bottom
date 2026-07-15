/* Generated from frozen rock_bottom_v19.html.
 * Source seams: combat primitives, intro, boss, and cops.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, particles, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { CROWN_SPOTS } from '../data/catalogs.js';
import { clamp, isNight, rectsOverlap } from '../data/npc_spawns.js';
import { interactiveProps } from '../data/props.js';
import { WORLD } from '../data/world.js';
import { openOldSchoolInterior } from '../dialogue/vendors_places.js';
import { WEAPONS, endingScreen, pickupWeapon, spawnBrutusOlder } from '../legacy.js';
import { hasPropane } from '../minigames/heat.js';
import { abortKingdomFight, completeKingdomBoss, completeKingdomPretender, maybeUnlockKingdom, syncKingdomQuests } from './campaigns.js';
import { broadcastNews, feedPost } from './communications.js';
import { adjustFaction, applyRep, factionTier } from './factions.js';
import { rollBlockRoute, rollHustles } from './progression_routes.js';

export let COP_HARD_CAP;

export function aggroNpc(n) {
  n.hostile = true; n.aggro = true; n.dmg = n.dmg||8;
  P.wanted = Math.min(3, P.wanted+1);
  // v13 wave 5 — swarmer: aggro'ing sherri calls her cousin if none is nearby.
  if (n.archetype === 'swarmer' && n.id === 'sherri') spawnSwarmerSibling(n);
}

export function spawnSwarmerSibling(parent) {
  const liveSwarmers = runtime.npcs.filter(n => n.archetype === 'swarmer' && !n.dead && (n.id === 'sherri' || n.id.startsWith('sherri_')));
  if (liveSwarmers.length >= 2) return;
  // also require no other live sherri within 400px (preserves the "her cousin shows up" feel
  // — if another sherri is already nearby don't double-spawn)
  for (const s of liveSwarmers) {
    if (s === parent) continue;
    const dx = s.x - parent.x, dy = s.y - parent.y;
    if (dx*dx + dy*dy < 400*400) return;
  }
  const sib = {
    id: 'sherri_'+Math.random().toString(36).slice(2,6),
    name: 'SPIDER-BITE SHERRI', sprite: 'sherri',
    x: parent.x + 60, y: parent.y,
    w: 26, h: 30, color: '#3a1820',
    hp: 45, maxHp: 45, speed: 2.0, hostile: true, aggro: true,
    aggroOnHit: true, dmg: 5, wander: true,
    archetype: 'swarmer', attackCd: 0, showHp: false,
  };
  runtime.npcs.push(sib);
  setTimeout(() => toast("another one shows up.\nit has the same haircut.", 2400), 200);
}

export function spawnProjectile({x, y, tx, ty, speed=320, dmg=15, slowMs=0, kind='bottle', from=null, wobble=0}) {
  let dx = tx - x, dy = ty - y;
  const len = Math.sqrt(dx*dx+dy*dy) || 1;
  // angle wobble (paulie misses often)
  let ang = Math.atan2(dy, dx);
  if (wobble) ang += (Math.random()-0.5) * wobble;
  const vx = Math.cos(ang) * speed, vy = Math.sin(ang) * speed;
  runtime.projectiles.push({
    x, y, vx, vy, dmg, slowMs, kind, from,
    rot: ang, rotVel: kind === 'holy' ? 0.05 : 0.25,
    life: 4000,
  });
}

export function questToast(title) { toast('· QUEST COMPLETE ·\n'+title); audio.rankUp(); }

export function tryCompleteIntroRemember() {
  const q = state.quests.intro_remember;
  if (!q || q.done) return;
  const earned = (state.counters && state.counters.introCashEarned) || 0;
  if (earned >= 10) {
    q.done = true;
    P.cred += 1;
    questToast("I DON'T REMEMBER");
    toast("you arrive somewhere by walking. who knew.", 2600);
    // unlock intro_tony as the next available step
    if (state.quests.intro_tony) state.quests.intro_tony.available = true;
    saveGame();
  }
}

export function completeIntroSmoke() {
  const q = state.quests.intro_smoke;
  if (!q || q.done) return;
  q.done = true;
  P.cred += 2;
  questToast('YOU SMOKE THE ROCK');
  toast("you understand the loop.\nthe loop understands you.\nneither of you is happy about it.", 4200);
  // un-suppress everything
  if (!state.flags) state.flags = {};
  state.flags.introDone = true;
  // roll the first real set of hustles now that the world is open
  rollHustles();
  rollBlockRoute();
  broadcastNews("the neighborhood notices you arrived. the neighborhood does not care.");
  feedPost("smoked one on the crate.\nthe sun moved.\nthe loop greeted me.", '@crackheadcent');
  saveGame();
}

export function pickCrownSpot() {
  // seed from day + character init time fingerprint (already-baked counter)
  if (state.flags && state.flags.crownSpotIdx >= 0 && state.flags.crownSpotIdx < CROWN_SPOTS.length) {
    return CROWN_SPOTS[state.flags.crownSpotIdx];
  }
  const idx = Math.floor(Math.random() * CROWN_SPOTS.length);
  state.flags.crownSpotIdx = idx;
  return CROWN_SPOTS[idx];
}

export function startPigeonCrownQuest() {
  const q = state.quests.pigeon_crown;
  if (!q || q.done) return;
  q.available = true;
  const spot = pickCrownSpot();
  state.crownPickup = { x: spot.x, y: spot.y, collected: false };
  saveGame();
}

export function spawnBoss() {
  if (state.bossActive) return;
  state.bossActive = true;
  state.bossKind = 'tony';
  state.bossPhase = 1;
  const tony = runtime.npcs.find(n=>n.id==='tony');
  if (!tony) return;
  state.bossNPC = tony;
  tony.hostile = true; tony.aggro = true; tony.maxHp = 200; tony.hp = 200; tony.speed = 1.8;
  tony.dmg = 12; tony.color = '#5a2018';
  tony.coatsOff = 1;
  audio.bossRoar();
  toast("tony tears off coat #1. then coat #2.\nthe corner is now arena.", 3500);
  broadcastNews("BREAKING: TRE BAG TONY IS REMOVING COATS. NEIGHBORHOOD WATCHES.");
  feedPost("tony is fighting at the corner. he had three coats. now two.", '@the_corner');
}

export function playerAttack() {
  if (P.attackCd > 0) return;
  const w = WEAPONS[P.weapon||'fists'];
  P.attackCd = w.cd;
  P.attacking = 160;
  audio.hit();
  const reach = 36 + (w.reach||0);
  const hit = { x: P.x, y: P.y, w: reach, h: 4 };
  if (P.facing==='down')  { hit.x = P.x + P.w/2 - 4; hit.y = P.y + P.h; hit.w = 8; hit.h = reach; }
  if (P.facing==='up')    { hit.x = P.x + P.w/2 - 4; hit.y = P.y - reach; hit.w = 8; hit.h = reach; }
  if (P.facing==='left')  { hit.x = P.x - reach; hit.y = P.y + P.h/2 - 4; hit.w = reach; hit.h = 8; }
  if (P.facing==='right') { hit.x = P.x + P.w; hit.y = P.y + P.h/2 - 4; hit.w = reach; hit.h = 8; }
  let connected = false, rewardableConnected = false;
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    if (rectsOverlap(hit, n)) {
      if(n.essential){
        // Bureaucracy wins this collision. Preserve hit feel without HP, wanted, blood,
        // knockback, aggro, or a persisted death that could remove a required transaction.
        n.hitFlash=120;n.showHp=false;state.shake=Math.max(state.shake,2);state.hitPause=20;
        particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*2,vy:-1.2,life:420,c:'#d4c896',sz:4});
        const now=Date.now();if((n.essentialToastAt||0)<=now){n.essentialToastAt=now+2500;toast(n.name+' enters the hit as a clerical error.\nno displacement authorized.',1800);}
        continue;
      }
      const baseDmg = 14 + Math.random()*8;
      // v13 wave 5 — charger cooldown is the vulnerable window. +25% damage on chargers panting.
      const vulnMult = ((n.archetype === 'charger' || n.archetype === 'charger_older') && n.chargeState === 'cooldown') ? 1.25 : 1.0;
      const dmg = Math.floor((baseDmg + w.dmg) * (P.rockedT>0 ? 1.5 : 1) * (P.cartMounted ? 1.3 : 1) * vulnMult);
      n.hp -= dmg; n.showHp = true; n.hitFlash = 200;
      // v13 wave 5 — chunky hit-stun: freeze + tint white + slight knockback for 120ms
      n.hitStun = 120;
      connected = true;
      if(!n.noComboReward)rewardableConnected=true;
      state.shake = Math.max(state.shake, 4);
      state.hitPause = 40; // freeze frame
      // v13 wave 6 — attacking the chained scrap_dog: one-time achievement, -5 cred,
      // dog becomes hostile and the quest closes as 'left' (no LIBERATOR ever).
      if (n.id === 'scrap_dog' && n.chained) {
        const q = state.quests.scrap_dog;
        if (q && q.state !== 'left') {
          q.state = 'left'; q.done = true; q.available = false;
        }
        if (!state.achievements.has('the_piece_of_shit')) {
          P.cred = Math.max(-50, P.cred - 5);
          unlockAchievement('the_piece_of_shit');
          toast("the dog growls. low. wrong.\nyou hit a dog that was tied up.\n- 5 cred", 4000);
          feedPost("there is a piece of shit out there. it is the man on the corner.", '@crackheadcent');
        }
        n.hostile = true; n.aggro = true;
        // make him able to fight — give him speed and snap the chain (lose the leash render)
        n.chained = false;
        n.speed = 1.6; n.dmg = 6;
        audio.hurt();
        saveGame();
      }
      // peaceful NPC hit -> wanted up
      if (!n.hostile && !n.aggroOnHit) { P.wanted = Math.min(3, P.wanted+1); toast(n.name + " did not deserve that.\nwanted +1"); }
      if (n.aggroOnHit && !n.aggro) { n.hostile = true; n.aggro = true; if (n.archetype === 'swarmer' && n.id === 'sherri') spawnSwarmerSibling(n); }
      // particles — sparks + blood drops, weapon-tinted, additive glow
      const sparkC = w.sings ? '#ffaa60' : '#fff080';
      for (let i=0;i<8;i++) particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*5,vy:(Math.random()-.5)*5,life:300,c:sparkC,sz:3,glow:true});
      for (let i=0;i<3;i++) particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:(Math.random()-.5)*3,vy:(Math.random()-.5)*3-1,life:600,c:'#8a3a3a',sz:2,gravity:0.15});
      // big glow ring on hit
      particles.push({x:n.x+n.w/2,y:n.y+n.h/2,vx:0,vy:0,life:200,c:sparkC,sz:14,glow:true});
      // v13 wave 5 — bigger knockback (5-10px, away from player) for hit-stun feel
      const kb = 8;
      if (P.facing==='down') n.y += kb;
      if (P.facing==='up') n.y -= kb;
      if (P.facing==='left') n.x -= kb;
      if (P.facing==='right') n.x += kb;
      if (n.hp <= 0) onNpcDeath(n);
    }
  }
  // v13 wave 6 — breakable bottles in the swing arc shatter; 25% drop a broken_bottle weapon pickup.
  for (const ip of interactiveProps) {
    if (ip.type !== 'b_bottle' || ip.broken) continue;
    const br = { x: ip.x-4, y: ip.y-12, w: 8, h: 16 };
    if (rectsOverlap(hit, br)) {
      ip.broken = true;
      ip.respawnT = 60000 + Math.random()*60000;
      audio.glassBreak();
      // glass shard burst
      for (let i=0;i<12;i++) particles.push({x:ip.x, y:ip.y-4, vx:(Math.random()-.5)*5, vy:-Math.random()*3-0.5, life:600, c:'rgba(180,200,220,.85)', sz:2, glow:true});
      // 25% chance to drop the weapon
      if (Math.random() < 0.25 && P.weapon !== 'broken_bottle') {
        pickupWeapon('broken_bottle');
      }
    }
  }
  if (rewardableConnected) {
    state.combo++;
    state.comboT = 1800;
    if (state.combo >= 3) state.shake = Math.max(state.shake, 6);
    if (state.combo === 5) {
      P.cred += 3; toast('· 5x COMBO ·\n+ 3 cred', 1400); unlockAchievement('not_a_phase');
    } else if (state.combo === 10) {
      P.cred += 10; toast('· 10x COMBO ·\n+ 10 cred', 1600);
    }
  } else if(!connected) {
    state.combo = 0;
  } else {
    // Repeatable kingdom actors provide hit feel but cannot mint combo cred.
    state.combo = 0;state.comboT=0;
  }
}

export function onNpcDeath(n) {
  if(n.essential){n.dead=false;n.hp=n.maxHp;return;}
  if(n.kingdomBoss){n.dead=true;audio.hurt();completeKingdomBoss(n);return;}
  if(n.kingdomPretender){n.dead=true;audio.hurt();completeKingdomPretender(n);return;}
  if(n.kingdomAdd){n.dead=true;audio.hurt();toast(n.name.toLowerCase()+' is removed from the minutes.',1400);return;}
  if(n.kingdomGuard){n.dead=true;audio.hurt();toast(n.name.toLowerCase()+' files an objection from the ground.\nno payment authorized.',1800);return;}
  n.dead = true;
  audio.hurt();
  if (n.id === 'tony' && state.bossActive && state.bossKind === 'tony') {
    state.bossActive = false;
    state.bossKind = '';
    state.bossPhase = 0;
    state.bossNPC = null;
    P.cred += 200;
    state.quests.fallen_king.done = true; questToast('THE FALLEN KING');
    maybeUnlockKingdom(false,false);syncKingdomQuests();
    // tony drops his shoe
    pickupWeapon('shoe');
    const wasCoop = state.coopMode;
    toast(wasCoop
      ? "tony is on the ground.\nstripe nods. 'good. tuesdays and thursdays. as agreed.'"
      : "tony is on the ground.\nthe corner is yours.\nyou get tuesdays and thursdays.", 5500);
    // The delayed receipt is presentation. The paid corner result is durable immediately.
    saveGame();
    setTimeout(() => endingScreen(wasCoop ? 'coop' : 'tony'), 4000);
    return;
  }
  if (n.id === 'brutus_older' && n.isBossB) {
    state.brutusOlderActive = false;
    P.cred += 100; P.maxHp += 5;
    toast("BRUTUS THE OLDER IS DOWN.\nyou get +5 max hp.\n(it is called BRUTUS'S COLLAR.)\nyou are wearing the collar now.", 5500);
    broadcastNews("BRUTUS THE OLDER DEFEATED. NEIGHBORHOOD UNCERTAIN HOW TO FEEL.");
    feedPost("the dog returned. then he didn't. legend.", '@crackheadcent');
    return;
  }
  // v13 wave 8a — OLD SCHOOL BRUTUS death drops: $80 cash pile + 5 copper + guaranteed propane torch
  // (no-dupe gated). street faction +2. SCHOOL_S_OUT achievement.
  if (n.id === 'os_brutus') {
    P.cred += 50;
    adjustFaction('street', 2);
    // cash pile — v13 wave 8b: scaled by current territory cash mult (scrap LIKED/LOVED → bigger)
    runtime.cashPiles.push({
      id: 'cp_os_brutus_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 - 22, y: n.y + n.h/2 + 8,
      amt: Math.round(80 * (state.territoryCashMult || 1.0)), collected: false,
    });
    // copper goes straight to inventory (he was sitting on it)
    P.copper += 5;
    state.counters.copperStripped = (state.counters.copperStripped||0) + 5;
    if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
    // guaranteed propane torch (no-dupe gated)
    if (!hasPropane()) {
      runtime.cashPiles.push({
        id: 'cp_os_torch_'+Math.random().toString(36).slice(2,6),
        x: n.x + n.w/2 + 22, y: n.y + n.h/2 + 8,
        amt: 0, tool: 'propane_torch', collected: false,
      });
    }
    unlockAchievement('school_s_out');
    // v13 wave 8.6 — flip the first-rip gate. subsequent rips revert to 40% probabilistic spawn
    // (the cousins). read in openOldSchoolInterior's rip handler.
    state.flags.osBrutusKilled = true;
    toast("OLD SCHOOL BRUTUS IS DOWN.\n+ $80. + 5 copper. + a torch he had on him.\nthe gym is finally quiet.", 5500);
    broadcastNews("THE OLD SCHOOL IS QUIET. SOMETHING LARGE NO LONGER LIVES IN THE GYM.");
    feedPost("school's out. the old school is empty. the copper is gone.", '@blocklog');
    saveGame();
    return;
  }
  // brutus killed — count toward Older trigger
  if (n.id === 'brutus') {
    P.brutusDefeated = (P.brutusDefeated||0) + 1;
    if (P.brutusDefeated >= 5) {
      setTimeout(spawnBrutusOlder, 1500);
    }
  }
  // v13 wave 5 — fallen priest death: drops $200 cash + the priest's collar pickup.
  // re-uses the cash-pile pickup pattern, with a collar variant tagged via `equip` field.
  if (n.isOmalleyFallen) {
    state.flags.omalleyFallenDead = true;
    adjustFaction('street', 2); // wave 7 — killing fallen priest = street +2
    runtime.cashPiles.push({
      id:'cp_plate_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 - 18, y: n.y + n.h/2 + 8,
      amt: 200, collected: false,
    });
    runtime.cashPiles.push({
      id:'cp_collar_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2 + 18, y: n.y + n.h/2 + 8,
      amt: 0, equip: 'priest_collar', collected: false,
    });
    if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
      state.quests.fallen_priest.done = true;
      state.quests.fallen_priest.available = false;
      questToast("THE FALLEN PRIEST");
    }
    unlockAchievement('fallen');
    toast("the church is quiet again.\nthe pews are still wrong.", 4200);
    broadcastNews("PRIEST 'GONE'. CHURCH 'WEIRD NOW'. WITNESSES VAGUE.");
    feedPost("the priest is on the ground. the collar is on the floor. you have both.", '@crackheadcent');
    saveGame();
    return;
  }

  // v13 wave 4 — propane torch drops 25% on a night-time brutus kill (regular or older).
  // uses the existing cash-pile pickup pattern, with a `tool` field that triggers equip-on-pickup.
  // v13 wave 7 — street loved bumps the drop rate to ~37.5% (+50%).
  const torchDropRate = factionTier(P.faction ? P.faction.street : 0) === 'loved' ? 0.375 : 0.25;
  if ((n.id === 'brutus' || n.id === 'brutus_older') && isNight() && !hasPropane() && Math.random() < torchDropRate) {
    runtime.cashPiles.push({
      id:'cp_torch_'+Math.random().toString(36).slice(2,6),
      x: n.x + n.w/2, y: n.y + n.h/2 + 8,
      amt: 0, tool: 'propane_torch', collected: false,
    });
    toast("something falls off his collar.\nit smells like a parking lot.", 2400);
  }
  if (n.isCop) {
    P.cred += 10; P.wanted = Math.min(3, P.wanted+1); P.lifetime.copsKilled++;
    if (n.isBrendan) {
      // drops a "rookie badge" — uses the existing cash-pile pickup mechanic. $30.
      cashPiles.push({ id:'cp_brendan_'+Math.random().toString(36).slice(2,6), x:n.x+n.w/2, y:n.y+n.h/2+8, amt:30, collected:false });
      unlockAchievement('badge_money');
      if (!state.counters.brendanFirstKill) {
        state.counters.brendanFirstKill = 1;
        feedPost("uncle dean is posting on facebook again.", '@local_eyewitness');
        broadcastNews("LOCAL ROOKIE DOWN. UNCLE DEAN POSTING. FAMILY GROUP CHAT GOES QUIET.");
      } else {
        feedPost("brendan again. the family is going to have words.", '@local_eyewitness');
      }
      toast('+ 10 cred · wanted +1\ncousin brendan is on the ground.\nhis badge fell out. it is yours now.');
    } else {
      toast('+ 10 cred · wanted +1\na cop is on the ground.');
    }
    // v13 wave 7 — killing a cop = street -3, spiritual +1 (mom would have wanted you to fight back)
    applyRep({ street: -3, spiritual: 1 });
  }
  else { P.cred += 3; toast('+ 3 cred\n'+n.name+' is on the ground.'); }
  // alley kill counter for hustles
  if (['lurch','sherri','paulie'].includes(n.id)) {
    state.counters.alleyKills = (state.counters.alleyKills||0) + 1;
  }
  // v13 wave 7 — street-affiliated kills nudge street rep up (the block respects a finisher)
  if (['brutus','brutus_older','lurch','sherri','paulie'].includes(n.id)) {
    adjustFaction('street', 1);
  }
  // v13 wave 3 — dave drops the crossword if he had it
  if (n.id === 'dave' && state.flags && state.flags.daveHasCrossword && !state.flags.hasCrossword) {
    state.flags.daveHasCrossword = false;
    state.flags.hasCrossword = true;
    P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
    toast("a folded newspaper falls out of his coat.\n+ saturday crossword", 3000);
  }
  // mayor_of_4th — all 3 alley NPCs defeated this run
  const alleyDead = ['lurch','sherri','paulie'].every(id => runtime.npcs.find(x=>x.id===id)?.dead);
  if (alleyDead) unlockAchievement('mayor_of_4th');
  // stripe betrayed
  if (n.id === 'stripe') {
    state.counters.stripeBetrayed++;
    if (state.counters.plateStolen >= 1 && state.counters.stripeBetrayed >= 1) unlockAchievement('judas');
  }
  // weapon drops
  if (n.id === 'larry' && !P.weapon || P.weapon === 'fists') { pickupWeapon('pipe'); }
  if (n.id === 'lurch' && Math.random() < 0.5) { pickupWeapon('brick'); }
  if (n.id === 'paulie' && Math.random() < 0.5) { pickupWeapon('baguette'); }
  // drops
  if (n.id !== 'cop' && Math.random()<0.5) { P.cash += 2 + Math.floor(Math.random()*5); toast('+ a few dollars', 1400); }
  saveGame();
}

export function damagePlayer(amount, src) {
  if (P.iframes > 0) return;
  P.hp -= amount;
  P.iframes = 500;
  P.hitFlash = 250;
  audio.hurt();
  state.flash = 1; state.flashColor = 'rgba(160,40,40,.4)';
  state.shake = 8;
  state.combo = 0; // break combo
  if (src) {
    const dx = P.x - src.x, dy = P.y - src.y;
    const len = Math.sqrt(dx*dx+dy*dy)||1;
    P.x += (dx/len)*8; P.y += (dy/len)*8;
  }
  if (P.hp <= 0) {
    if (src && src.id === 'brutus') {
      state.counters.brutusDeaths++;
      if (state.counters.brutusDeaths >= 3) unlockAchievement('brutus_remembers');
    }
    if (src && src.isCop) arrestScene();
    else die();
  }
}

export function die() {
  abortKingdomFight(false);
  audio.death();
  P.hp = 60; P.shakes = 30; P.cred = Math.max(0, P.cred-10); P.wanted = 0;
  P.x = 1050; P.y = 840; P.iframes = 1000;
  // cops vanish
  runtime.npcs = runtime.npcs.filter(n => !n.isCop);
  toast('you wake up at the block.\nyour mouth tastes like a battery.\nit is approximately tuesday.', 3500);
  saveGame();
}

export function arrestScene() {
  abortKingdomFight(false);
  P.lifetime.arrests = (P.lifetime.arrests||0)+1;
  const lostCash = Math.floor(P.cash * 0.7);
  P.cash -= lostCash; P.rocks = 0; P.shakes = 100; P.wanted = 0; P.hp = 40;
  P.x = 1050; P.y = 840;
  runtime.npcs = runtime.npcs.filter(n => !n.isCop);
  toast(`arrested.\n- $${lostCash} · - all rocks\nthey didn't check your sock.`, 4000);
  feedPost("arrested again. they did not check the sock. the sock is safe.", '@crackheadcent');
  saveGame();
}

export function spawnCopAtEdge(reason) {
  if (runtime.npcs.filter(n => n.isCop && !n.dead).length >= COP_HARD_CAP) return null;
  // pick the nearest world edge to the player
  const px = P.x+P.w/2, py = P.y+P.h/2;
  const dl = px, dr = WORLD.w - px, du = py, dd = WORLD.h - py;
  const m = Math.min(dl, dr, du, dd);
  let x, y;
  if (m === dl)      { x = 30;            y = clamp(py + (Math.random()-.5)*300, 40, WORLD.h-40); }
  else if (m === dr) { x = WORLD.w - 30;  y = clamp(py + (Math.random()-.5)*300, 40, WORLD.h-40); }
  else if (m === du) { y = 30;            x = clamp(px + (Math.random()-.5)*300, 40, WORLD.w-40); }
  else               { y = WORLD.h - 30;  x = clamp(px + (Math.random()-.5)*300, 40, WORLD.w-40); }
  const cop = {
    id:'cop_'+Math.random().toString(36).slice(2,6), name:'COP', sprite:'cop',
    x, y, w:28, h:32, color:'#1818a0', hp:60, maxHp:60, speed:1.5, dmg:10,
    hostile:true, aggro:true, isCop:true, attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true,
    archetype:'cop',
  };
  runtime.npcs.push(cop);
  if (reason === 'radio') audio.copSiren();
  return cop;
}

export function manageCops(dt) {
  if (P.wanted > 0) {
    // v13 wave 5 — priest's collar speeds wanted decay (wantedDecayMult > 1.0).
    const decayMult = P.wantedDecayMult || 1.0;
    P.wantedT += dt * decayMult;
    // decay -1 every 18s (faster with collar)
    if (P.wantedT >= 18000) {
      P.wantedT = 0; P.wanted--;
      if (P.wanted === 0) toast('the heat dies down.\nfor now.', 1500);
    }
    const targetCops = P.wanted;
    const liveCops = runtime.npcs.filter(n=>n.isCop && !n.dead).length;
    if (liveCops < targetCops && liveCops < COP_HARD_CAP) {
      audio.copSiren();
      // v13 wave 2 — at wanted ≥ 2, one spawning cop has a 30% chance of being cousin brendan.
      // hard cap at one brendan on the map at a time.
      const liveBrendan = runtime.npcs.find(n => n.isBrendan && !n.dead);
      const spawnBrendan = (P.wanted >= 2) && !liveBrendan && (Math.random() < 0.3);
      const cop = spawnBrendan ? {
        id:'brendan_'+Math.random().toString(36).slice(2,6), name:'COUSIN BRENDAN', sprite:'brendan',
        x: P.x + (Math.random()<.5?-400:400), y: P.y + (Math.random()<.5?-300:300),
        w:26, h:30, color:'#2838c0', hp:55, maxHp:55, speed:2.3, dmg:50,
        hostile:true, aggro:true, isCop:true, isBrendan:true, taserChargeT:0,
        attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true, archetype:'brendan',
      } : {
        id:'cop_'+Math.random().toString(36).slice(2,6), name:'COP', sprite:'cop',
        x: P.x + (Math.random()<.5?-400:400), y: P.y + (Math.random()<.5?-300:300),
        w:28, h:32, color:'#1818a0', hp:60, maxHp:60, speed:1.5, dmg:10,
        hostile:true, aggro:true, isCop:true, attackCd:0, wanderT:0, targetX:0, targetY:0, showHp:true,
        archetype:'cop',
      };
      cop.x = clamp(cop.x, 40, WORLD.w-40);
      cop.y = clamp(cop.y, 40, WORLD.h-40);
      runtime.npcs.push(cop);
      if (spawnBrendan) {
        const lines = [
          "stop! it's me!! it's brendan!!",
          "uncle dean said don't make him come down here!!",
        ];
        setTimeout(() => toast("· COUSIN BRENDAN ARRIVES ·\n" + lines[Math.floor(Math.random()*lines.length)], 3200), 500);
      }
    }
    // v13 wave 5 — radio-for-backup. regular cops (not brendan) at >120px from player
    // roll 25%/sec to radio in another cop. cap at 4 total. brendan does not radio.
    for (const cop of runtime.npcs) {
      if (!cop.isCop || cop.dead || cop.isBrendan) continue;
      const cdx = (P.x+P.w/2) - (cop.x+cop.w/2), cdy = (P.y+P.h/2) - (cop.y+cop.h/2);
      const cdist2 = cdx*cdx + cdy*cdy;
      if (cdist2 < 120*120) { cop.radioT = 0; continue; }
      cop.radioCdT = (cop.radioCdT||0) - dt;
      cop.radioT = (cop.radioT||0) + dt;
      // chance roll once per second window (25% per second)
      if (cop.radioCdT <= 0 && Math.random() < 0.25 * (dt/1000)) {
        cop.radioCdT = 5000; // 5s minimum between radios per cop
        cop.radioVisualT = 800; // hand-to-ear pose
        audio.radio();
        // "*" particle above the cop's head
        particles.push({x: cop.x+cop.w/2, y: cop.y-6, vx:0, vy:-0.4, life:700, c:'#88c0ff', sz:3, glow:true});
        // backup arrives within 5 seconds
        const delay = 800 + Math.random()*4000;
        setTimeout(() => {
          if (cop.dead) return; // canceled if the caller dies
          if (P.wanted <= 0) return;
          spawnCopAtEdge('radio');
          if (runtime.npcs.filter(n=>n.isCop&&!n.dead).length <= COP_HARD_CAP) {
            toast("more flashing lights.\nfrom somewhere.", 1800);
          }
        }, delay);
      }
      if (cop.radioVisualT) cop.radioVisualT = Math.max(0, cop.radioVisualT - dt);
    }
  } else {
    P.wantedT = 0;
  }
}

export function init_combat() {
  
  
  // v13 wave 5 — swarm pair: spawn a clone of sherri 60px to the side.
  // cap: 2 live sherris on the map.
  
  
  // v13 wave 5 — generic projectile spawn used by ranged + fallen-priest patterns.
  
  
  
  // ---------- v13 wave 3: intro chain helpers ----------
  
  
  
  
  // v13 wave 3 — pick a crown spot from the 6 candidates using a per-save seed so the location
  // is deterministic for the playthrough but varies between saves.
  
  
  
  // ---------- SPAWN BOSS ----------
  
  
  // ---------- COMBAT ----------
  
  
  
  
  
  
  
  
  
  
  // ---------- WANTED & COPS ----------
  // v13 wave 5 — global cop cap. existing intent was N=wanted but radio-for-backup
  // can push us past that. hard ceiling at 4 keeps the screen survivable.
  COP_HARD_CAP = 4;
  
  
  
  
}
