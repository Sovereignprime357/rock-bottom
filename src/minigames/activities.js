/* Generated from frozen rock_bottom_v19.html.
 * Source seams: heist, weapons, rhythm, lockpick, Brutus, and panhandling.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, rollWeather, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { clamp, isNight } from '../data/npc_spawns.js';
import { WORLD } from '../data/world.js';
import { openStripePackage } from '../dialogue/neighborhood_b.js';
import { cookBatchMenu } from './heat.js';
import { die, questToast } from '../systems/combat.js';
import { broadcastNews, feedPost } from '../systems/communications.js';
import { smokeRockAt } from '../systems/concessions.js';
import { fireDayEvents, resetDailyCounters } from '../systems/daily_hideouts.js';
import { factionTier } from '../systems/factions.js';
import { checkHustles, rollHustles } from '../systems/progression_routes.js';

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
    // v20 landing 3 — the transaction lives in concessions.js now (I-ONE-LOOP).
    action: () => smokeRockAt('block')
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
