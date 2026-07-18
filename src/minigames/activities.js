/* Generated from frozen rock_bottom_v19.html.
 * Source seams: heist, weapons, rhythm, lockpick, Brutus, and panhandling.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, rollWeather, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { clamp, isNight } from '../data/npc_spawns.js';
import { BREAKIN_SITES, COPPER_SITES } from '../data/props.js';
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

// v22 wave 5.1 — the heist is ONE engine, many buildings. COPPER_SITES (data/props.js) supplies
// each site's texts, entries, and exits; this flow exists exactly once (I-ONE-ENGINE). All sites
// share the daily cap and the yield — variety is the payout, not income (I-DAILY-CAP-SHARED).
export const HEIST_DAILY_CAP = 3;   // v13 wave 6.5 — closes the conductor-arbitrage grind path.
export const HEIST_YIELD_MIN = 2;   // 3 heists × 2-4 copper × ($90 / 3 copper) caps the
export const HEIST_YIELD_SPAN = 3;  // conductor floor at ~$270 / day. Shared by every site.
// v22 wave 5.5 — break-ins run through THIS engine (I-ONE-ENGINE) but on their own
// governor: breakinsToday, never heistsToday, so copper and break-ins cannot starve
// each other (I-NO-MINT-DRIFT). Worst-case take: 2/day × the two richest sites
// ($14 + $18) = $32/day — noise next to the copper floor, real next to the robbery.
export const BREAKIN_DAILY_CAP = 2;

// Applies one effects object. Order (text -> hp -> glass -> wanted -> brain -> shakes) is
// abandoned-building parity — see SPEC-v22-copper-sites.md I-ABANDONED-VERBATIM.
function applyHeistEffects(fx) {
  if (fx.text) toast(fx.text, fx.dur);
  if (fx.hp) P.hp -= fx.hp;
  if (fx.glass) audio.glassBreak();
  if (fx.wanted) P.wanted = Math.min(3, P.wanted + fx.wanted);
  if (fx.brain) P.brain = Math.max(0, P.brain - fx.brain);
  if (fx.shakes) P.shakes = Math.min(100, P.shakes + fx.shakes);
}

function heistSite(siteId) {
  return COPPER_SITES.find(s => s.id === siteId) || BREAKIN_SITES.find(s => s.id === siteId) || COPPER_SITES[0];
}

// v22 wave 5.5 — the door's gates (I-GATE-REAL). The engine's whole gate vocabulary
// lives in this one function: a `tool` gate is P.equip.tool identity, a `cred` gate
// is P.cred >= n. Gates evaluate in listed order and ALL must pass; the first
// failing gate is returned so its refusal speaks — never a silent no-op.
function failedHeistGate(site) {
  for (const g of (site.gates || [])) {
    if (g.kind === 'tool' && P.equip.tool !== g.tool) return g;
    if (g.kind === 'cred' && P.cred < g.cred) return g;
  }
  return null;
}

export async function startHeist(siteId = 'abandoned') {
  const site = heistSite(siteId);
  // the door is answered before the schedule: a refused gate is a clean bounce
  // that spends nothing — not the day's cap, not an entry cost (I-NO-SOFTLOCK).
  const refusedGate = failedHeistGate(site);
  if (refusedGate) {
    dialogue(site.title, refusedGate.refuse, [
      { label: 'leave.', action: () => { state.mode = 'playing'; }},
    ]);
    return;
  }
  if (site.loot) {
    // break-in governor — separate counter, separate cap (I-NO-MINT-DRIFT).
    if ((state.counters.breakinsToday||0) >= BREAKIN_DAILY_CAP) {
      dialogue(site.title, site.capText, [
        { label: 'come back tomorrow.', action: () => { state.mode = 'playing'; }},
      ]);
      return;
    }
    state.counters.breakinsToday = (state.counters.breakinsToday||0) + 1;
  } else {
    if ((state.counters.heistsToday||0) >= HEIST_DAILY_CAP) {
      dialogue(site.title, site.capText, [
        { label: 'come back tomorrow.', action: () => { state.mode = 'playing'; }},
      ]);
      return;
    }
    state.counters.heistsToday = (state.counters.heistsToday||0) + 1;
  }
  state.mode = 'heist';
  await heistStage(site, 1);
}

export async function heistStage(site, stage) {
  return new Promise(resolve => {
    // an entry resolved: apply the cost, then advance — unless the cost was fatal.
    const advance = () => { if (P.hp<=0) die(); else heistStage(site, 2); resolve(); };
    if (stage === 1) {
      const opts = site.entries.map(entry => {
        if (entry.kind === 'roll') return { label: entry.label, action: () => {
          applyHeistEffects(Math.random() < entry.p ? entry.under : entry.over);
          advance();
        }};
        if (entry.kind === 'lockpick') return { label: entry.label, action: () => {
          startLockpickMini(
            () => { applyHeistEffects(entry.ok); advance(); },
            () => {
              applyHeistEffects(entry.fail);
              if (entry.fail.extra && Math.random() < entry.fail.extraChance) applyHeistEffects(entry.fail.extra);
              advance();
            }
          );
        }};
        if (entry.kind === 'item') {
          const have = P.inventory.find(i => i.id === entry.itemId);
          return { label: have ? entry.haveLabel : entry.lackLabel, disabled: !have, action: () => {
            // 'all' preserves the shipped soap filter; 'one' spends a single can.
            if (entry.consume === 'one') P.inventory.splice(P.inventory.findIndex(i => i.id === entry.itemId), 1);
            else P.inventory = P.inventory.filter(i => i.id !== entry.itemId);
            applyHeistEffects(entry.effect); advance();
          }};
        }
        if (entry.kind === 'cash') return {
          label: P.cash >= entry.cost ? entry.haveLabel : entry.lackLabel, disabled: P.cash < entry.cost,
          action: () => { P.cash -= entry.cost; applyHeistEffects(entry.effect); advance(); },
        };
        // 'wait' and 'sure' both resolve unconditionally; their cost (if any) rides the effect.
        return { label: entry.label, action: () => { applyHeistEffects(entry.effect); advance(); }};
      });
      opts.push({ label: 'leave.', action: () => { state.mode='playing'; resolve(); }});
      dialogue(site.title, site.intro, opts);
    } else if (stage === 2 && site.loot) {
      // v22 wave 5.5 — the take. Fixed, specific, small: the loot IS the building's
      // punchline, and it cannot mint copper or rocks (breakin-gate locks the keys).
      const L = site.loot;
      dialogue(L.title, L.text, [
        { label: L.takeLabel, action: () => {
          P.cash += L.cash || 0;
          for (const it of (L.items || [])) P.inventory.push({ id: it.id, n: it.n, q: 1 });
          audio.pickup();
          toast(L.takeToast, L.takeDur);
          heistStage(site, 3); resolve();
        }},
        { label: L.altLabel, action: () => {
          if (L.alt.brain) P.brain = Math.min(100, P.brain + L.alt.brain);
          toast(L.alt.text, L.alt.dur);
          heistStage(site, 3); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else if (stage === 2) {
      dialogue('THE COPPER PIPES', site.pipes.text, [
        { label: 'strip them.', action: () => {
          const got = HEIST_YIELD_MIN + Math.floor(Math.random()*HEIST_YIELD_SPAN);
          P.copper += got; audio.glassBreak();
          state.counters.copperStripped += got;
          if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
          toast(`+ ${got} pure copper\n` + site.pipes.stripAfter);
          if (!state.quests.copper_sings.done) { state.quests.copper_sings.done = true; questToast('THE COPPER SINGS'); }
          heistStage(site, 3); resolve();
        }},
        { label: 'listen to them sing.', action: () => {
          P.brain = Math.min(100, P.brain+8); toast('+ 8 brain\n' + site.pipes.listenAfter);
          heistStage(site, 3); resolve();
        }},
        { label: 'leave.', action: () => { state.mode='playing'; resolve(); }},
      ]);
    } else {
      dialogue('GETAWAY', site.getawayText, site.exits.map(exit => ({
        label: exit.label, action: () => {
          applyHeistEffects(Math.random() < exit.p ? exit.under : exit.over);
          if (P.hp<=0) die();
          state.mode = 'playing'; saveGame(); resolve();
        },
      })));
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
