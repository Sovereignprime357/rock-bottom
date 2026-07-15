/* Generated from frozen rock_bottom_v19.html.
 * Source seams: bus, vendors, and place encounters.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, applyEquipStats, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { vendorPrice } from '../data/catalogs.js';
import { clamp, currentZone, isNight } from '../data/npc_spawns.js';
import { PROPS } from '../data/props.js';
import { H, W, WORLD, ZONES } from '../data/world.js';
import { drawNpc, questToast, update } from '../legacy.js';
import { hasPropane } from '../minigames/heat.js';
import { broadcastNews, feedPost } from '../systems/communications.js';
import { adjustFaction, applyRep, factionTier } from '../systems/factions.js';

export let BUS_ZONE_TARGETS, HOPPER_LINES, PHILOSOPHER_QUESTIONS, OLD_SCHOOL_DOOR;

export function hasBusPass() { return !!P.inventory.find(i => i.id === 'bus_pass'); }

export function consumeBusPass() {
  const i = P.inventory.findIndex(x => x.id === 'bus_pass');
  if (i >= 0) P.inventory.splice(i, 1);
}

export function giveBusPass(silent) {
  if (hasBusPass()) return false;
  P.inventory.push({ id:'bus_pass', n:'a bus pass', q:1 });
  if (!silent) toast("+ a bus pass\nit smells like a wallet that wasn't yours.", 2600);
  return true;
}

export function combatActive() {
  if (P.wanted > 0) return true;
  const pcx = P.x + P.w/2, pcy = P.y + P.h/2;
  for (const n of runtime.npcs) {
    if (n.dead || n.isPet) continue;
    if (!(n.hostile || n.aggro)) continue;
    const dx = (n.x+n.w/2) - pcx, dy = (n.y+n.h/2) - pcy;
    if (dx*dx + dy*dy < 220*220) return true;
  }
  return false;
}

export function visitedZonesForBus() {
  // a zone is "visited" if its *Entered flag is true, OR if it has no gate flag (always known).
  const out = [];
  for (const t of BUS_ZONE_TARGETS) {
    if (t.flag && !(state.flags && state.flags[t.flag])) continue;
    out.push(t);
  }
  return out;
}

export function openBusPassMenu(page=0) {
  if (!hasBusPass()) {
    dialogue('BUS STOP', "you do not have a bus pass.\nthe bus does not care that you tried.", [{label:'leave.', action:()=>{}}]);
    return;
  }
  if (state.flags && state.flags.busPassUsedDay === state.day) {
    dialogue('BUS STOP', "you already rode today.\nthe bus does not run twice for you.", [{label:'leave.', action:()=>{}}]);
    return;
  }
  const aggro = combatActive();
  const here = currentZone();
  const destinations=visitedZonesForBus(),pageSize=6,maxPage=Math.max(0,Math.ceil(destinations.length/pageSize)-1);
  page=Math.max(0,Math.min(maxPage,Math.floor(Number(page)||0)));
  const opts = [];
  for (const t of destinations.slice(page*pageSize,page*pageSize+pageSize)) {
    const z = ZONES.find(z=>z.id===t.zoneId);
    if (!z) continue;
    const isHere = here && here.id === t.zoneId;
    const disabledHere = isHere;
    const disabledAggro = aggro;
    const lbl = disabledAggro ? `${t.label} — the bus is not your friend right now.`
              : disabledHere  ? `${t.label} — you're already where the bus is.`
              : `take the bus to ${t.label}.`;
    opts.push({ label: lbl, disabled: disabledAggro || disabledHere, action: () => {
      // consume + fade + teleport
      consumeBusPass();
      state.flags.busPassUsedDay = state.day;
       const tx = Number.isFinite(t.x)?t.x:z.x+z.w/2, ty = Number.isFinite(t.y)?t.y:z.y+z.h/2;
      state.flash = 0.5; state.flashColor = '#000';
      setTimeout(() => {
        P.x = Math.max(20, Math.min(WORLD.w - 20 - P.w, tx - P.w/2));
        P.y = Math.max(20, Math.min(WORLD.h - 20 - P.h, ty - P.h/2));
        state.cam.x = clamp(P.x + P.w/2 - W/2, 0, WORLD.w - W);
        state.cam.y = clamp(P.y + P.h/2 - H/2, 0, WORLD.h - H);
        // reset territory bookkeeping since the player just teleported zones
        state.territoryHeat = 0;
        state.territoryGreeted = new Set();
        state.territoryZoneId = null;
        state.flash = 0.5; state.flashColor = '#000';
        toast("the bus took you.\nthe bus does not explain how.", 3000);
        saveGame();
      }, 380);
    }});
  }
  if(page>0)opts.push({label:'previous destinations.',action:()=>openBusPassMenu(page-1)});
  if(page<maxPage)opts.push({label:'more destinations.',action:()=>openBusPassMenu(page+1)});
  opts.push({ label: 'put the pass away.', action: () => {} });
  dialogue('BUS STOP · PAGE '+(page+1)+'/'+(maxPage+1), "you take the pass out of your pocket.\nthe pass smells like a wallet that wasn't yours.\nwhere are you going.", opts);
}

export function barbDialogue() {
  // v13 wave 3 — visit count drives the crossword side-quest offer (+2 visits = offer + start)
  state.counters.barbVisits = (state.counters.barbVisits||0) + 1;
  const flav = [
    "she does not look up. she is doing the crossword.",
    "her cart has three packets and a romance novel.",
    "she hums. it is not a song.",
    "she is, in fact, someone's grandma. somewhere.",
    "the bingo dauber on the table has never been used for bingo.",
  ];
  let aside = '';
  if (state.barbAside) {
    const asides = [
      "\n(she taps the pen.)\n'pinky's salt is salt. just salt.\nmine has more salt.'",
      "\n(she does not look up.)\n'i hear pinky undercuts.\nhe will. eventually. cut himself.'",
      "\n(the dauber moves an inch.)\n'pinky calls it amore. it is not.'",
    ];
    aside = asides[Math.floor(Math.random()*asides.length)];
    state.barbAside = false;
  }
  const singlePrice = vendorPrice(5);
  const bulkPrice = vendorPrice(22);
  // v13 wave 6.5 — barb has a 6-packet/day cap. single counts as 1, bulk counts as 5.
  // if buying would exceed cap, refuse with a vibe line + a "14 across" callback.
  const packetsToday = state.counters.barbPacketsToday || 0;
  const remaining = Math.max(0, 6 - packetsToday);
  const atCap = remaining === 0;
  const opts = [];
  if (atCap) {
    opts.push({ label: 'buy packets. (she is tired.)', action: () => {
      toast("she's tired.\ncome back tomorrow.\nshe has 14 across to think about.", 3600);
    }});
  } else {
    // single packet — available unless at cap
    opts.push({ label: P.cash>=singlePrice ? `buy 1 packet. $${singlePrice}. (unmarked.)` : `a packet is $${singlePrice}.`, disabled: P.cash<singlePrice, action: () => {
      P.cash -= singlePrice; P.supplies = (P.supplies||0) + 1;
      state.counters.barbPacketsToday = (state.counters.barbPacketsToday||0) + 1;
      const left = 6 - state.counters.barbPacketsToday;
      const tail = left <= 0 ? "\nshe stops writing.\nshe's tired.\ncome back tomorrow." : '';
      toast(`- $${singlePrice}\n+ 1 packet (unmarked)\nshe does not look up.${tail}`);
      audio.coin(); saveGame();
    }});
    // bulk — only show if 5 will fit under cap (i.e. remaining >= 5)
    if (remaining >= 5) {
      opts.push({ label: P.cash>=bulkPrice ? `buy 5 packets. $${bulkPrice}. (bulk.)` : `5 packets is $${bulkPrice}.`, disabled: P.cash<bulkPrice, action: () => {
        P.cash -= bulkPrice; P.supplies = (P.supplies||0) + 5;
        state.counters.barbPacketsToday = (state.counters.barbPacketsToday||0) + 5;
        const left = 6 - state.counters.barbPacketsToday;
        const tail = left <= 0 ? "\nshe stops writing.\nshe's tired.\ncome back tomorrow." : '';
        toast(`- $${bulkPrice}\n+ 5 packets\nshe writes '14 across' in pen.${tail}`);
        audio.coin(); saveGame();
      }});
    } else {
      opts.push({ label: 'buy 5 packets bulk. (not today.)', action: () => {
        toast("she taps the pen.\n'i'm not weighing five out tonight.\ncome back tomorrow.'", 3200);
      }});
    }
  }
  opts.push({ label: "ask what's in them.", action: () => {
    toast("she does not look up.\n'salt.'\nyou both know.\nyou both agree to not.");
  }});
  // v13 wave 3 — quest C: barb_crossword
  const q = state.quests.barb_crossword;
  if (q && q.done) {
    // post-completion easter egg branch
    opts.push({ label: "ask what 14 across was.", action: () => {
      dialogue('BAGGIE BARB', "she looks up. her eyes are dry and the lashes are stuck.\n'fourteen across. five letters. begins with a B.\nit was BLAME.\nit's always BLAME.'\nshe looks back down.", [
        { label: 'leave.', action: () => {} },
      ]);
    }});
  } else if (q && q.available && state.flags.hasCrossword) {
    // returning the stolen crossword
    opts.unshift({ label: "give barb her crossword back.", action: () => {
      state.flags.hasCrossword = false;
      P.inventory = P.inventory.filter(i => i.id !== 'crossword');
      P.supplies = (P.supplies||0) + 1; // free clean packet
      q.done = true;
      questToast("BARB'S MISSING CROSSWORD");
      unlockAchievement('seven_across');
      adjustFaction('street', 1); // wave 7 — return crossword = street +1
      audio.coin();
      dialogue('BAGGIE BARB', "she takes it. for the first time in years she looks up.\nher eyes are dry and the lashes are stuck.\n'fourteen across. five letters. begins with a B.\nit was BLAME.\nit's always BLAME.'\nshe looks back down.\n\n+ 1 packet (free.)", [
        { label: 'leave.', action: () => {} },
      ]);
      saveGame();
    }});
  } else if (q && !q.available && state.counters.barbVisits >= 2) {
    // hook: offer the side quest after the second visit
    q.available = true;
    state.flags.daveHasCrossword = true;
    aside += "\n(her hand pauses over the puzzle.)\n'somebody took my saturday.\ni need it back. i am not well without it.'";
    saveGame();
  }
  // standard "14 across" flavor (only if quest not active)
  if (!q || (!q.available && !q.done)) {
    opts.push({ label: "ask what 14 across is.", action: () => {
      const clues = [
        "'a flightless bird.' 3 letters.\nit is EMU. it is always EMU.",
        "'a man with a plan.' 4 letters.\nshe writes BARB.\nyou do not correct her.",
        "'something you regret.' 11 letters.\nshe does not write anything.\nshe looks at you. briefly.",
        "'opposite of clean.' 5 letters.\nshe writes BARB again.",
      ];
      toast(clues[Math.floor(Math.random()*clues.length)], 3800);
    }});
  }
  opts.push({ label: "leave.", action: () => {} });
  dialogue('BAGGIE BARB', "what.\n" + flav[Math.floor(Math.random()*flav.length)] + aside, opts);
}

export function pinkyDialogue() {
  // v13 wave 7 — street-hated: pinky refuses to sell ("you smell like a snitch.")
  const streetTier = factionTier(P.faction ? P.faction.street : 0);
  if (streetTier === 'hated') {
    dialogue('PINKY POLENTA', "pinky steps back.\n'you smell like a snitch.\npinky no sell to a snitch.\nyou go barb. barb sell to snitch.'", [
      { label: 'leave.', action: () => {} }
    ]);
    return;
  }
  const flav = [
    "buongiorno mi crackhead.",
    "the cut is amore.",
    "is fresh. from the house.",
    "i price in lira sometimes. twenty four thousand. is four dollars. same number.",
    "pinky no negotiate. pinky also a little negotiate.",
  ];
  const onBuy = () => {
    if (!state.counters.pinkyFirstBuy) {
      state.counters.pinkyFirstBuy = 1;
      state.barbAside = true;
      unlockAchievement('due_dealer_system');
      broadcastNews("DUE DEALER SYSTEM OBSERVED. THE NEIGHBORHOOD HAS OPTIONS NOW.");
      feedPost("two packet guys. one block. choose your fighter.", '@crackheadcent');
    }
  };
  const oneP = vendorPrice(4);
  const fiveP = vendorPrice(18);
  // v13 wave 8b — bus pass: pinky sells one for $20 if player doesn't already carry one
  const passPrice = 20;
  const showBusPassSell = !hasBusPass();
  const showBusPassUse = hasBusPass();
  const opts = [
    { label: P.cash>=oneP ? `buy 1 house cut packet. $${oneP}.` : `house cut is $${oneP}.`, disabled: P.cash<oneP, action: () => {
      P.cash -= oneP;
      P.supplies = (P.supplies||0) + 1;
      P.dirtySupplies = (P.dirtySupplies||0) + 1;
      onBuy();
      toast(`- $${oneP}\n+ 1 packet (house cut)\nhe winks. with both eyes.`);
      applyRep({ street: 1, spiritual: -1 }); // wave 7
      audio.coin(); saveGame();
    }},
    { label: P.cash>=fiveP ? `buy 5 packets bulk. $${fiveP}.` : `5 packets bulk is $${fiveP}.`, disabled: P.cash<fiveP, action: () => {
      P.cash -= fiveP;
      P.supplies = (P.supplies||0) + 5;
      P.dirtySupplies = (P.dirtySupplies||0) + 5;
      onBuy();
      toast(`- $${fiveP}\n+ 5 packets (house cut)\nhe says 'amore.' he says it three times.`);
      applyRep({ street: 2, spiritual: -2 }); // wave 7 — bulk gets a slightly bigger ledger hit
      audio.coin(); saveGame();
    }},
  ];
  if (showBusPassSell) {
    opts.push({ label: P.cash>=passPrice ? `buy a bus pass. $${passPrice}.` : `a bus pass is $${passPrice}.`, disabled: P.cash<passPrice, action: () => {
      P.cash -= passPrice;
      giveBusPass();
      toast(`- $${passPrice}\n+ a bus pass\npinky shrugs.\n'is paper. is the bus. is paper.'`, 3400);
      audio.coin(); saveGame();
    }});
  }
  if (showBusPassUse) {
    opts.push({ label: 'use the bus pass.', action: () => openBusPassMenu() });
  }
  opts.push({ label: "you no like?", action: () => {
    toast("he is delighted you said it back.\n'you no like? you go barb.'\nhe says it once more under his breath.");
  }});
  opts.push({ label: "ask about the cut.", action: () => {
    toast("'is house. is what house had.'\nhe gestures behind him.\nthere is no house.");
  }});
  opts.push({ label: "leave.", action: () => {} });
  dialogue('PINKY POLENTA', flav[Math.floor(Math.random()*flav.length)] + "\nhe smells of cologne and onion.\nhe is always saying it once.", opts);
}

export function mathematicianDialogue() {
  state.counters.mathInteractions = (state.counters.mathInteractions||0) + 1;
  const count = state.counters.mathInteractions;

  // live EV calc — mirrors doCook's slow-mode math
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  if (P.rockedT > 0) bb -= 0.25;
  const slowDbl = clamp(0.08 + bb*0.15, 0, 0.7);
  const slowBrn = clamp(0.10 - bb*0.08, 0.02, 0.5);
  const evRocks = 1 - slowBrn + slowDbl;
  const evCash = evRocks * 6;       // stripe fences at $6
  const evNet = evCash - 5;          // minus barb's $5/packet
  const pct = Math.round(evRocks * 100);
  const dirty = P.dirtySupplies || 0;

  const stateLines = [
    `${pct} percent of two. you a coin flip with a busted edge.`,
    `brain ${Math.round(P.brain)}. ${P.rockedT>0 ? "rocked up. shaky scientist. minus point two five. don't." : "shaky mode equals minus point one eight. don't."}`,
    `expectation: a buck ${Math.max(0, evNet).toFixed(2).slice(2)}. you smoke it you lose two dollars and a year.`,
    `the math says barb. the math also says you sell. the math is a coward.`,
    `tony charges ten. you cook for five. the gap is moral.`,
  ];
  if (dirty > 0) {
    stateLines.push(`${dirty} dirty in the bag. soap rate twenty five. pinky knows what he did.`);
  }

  let lead = stateLines[Math.floor(Math.random()*stateLines.length)];
  let tip = null;
  if (count % 3 === 0) {
    const tipIdx = Math.floor(count / 3) - 1;
    const tips = [
      "the cook brain factor: brain minus thirty over seventy. minus point two five if you smoked first. they don't print that anywhere.",
      "stripe's coin lands soap two of every five tosses. forty percent. you knew. you kept buying.",
      "tony's patience is three. you short him three times. the corner becomes arena. simple math.",
      "twenty two coins are on the ground. you have stepped on most of them already. hold F. the math is green.",
      "the priest's son is half tic-tac, half rock. exactly half. fifty fifty. flip your coin.",
    ];
    if (tipIdx >= 0 && tipIdx < tips.length) {
      tip = tips[tipIdx];
      adjustFaction('scrap', 1); // wave 7 — math hidden tip received = scrap +1
    }
  }

  dialogue('THE MATHEMATICIAN', "he looks up from a clipboard.\n" + lead + (tip ? "\n\n· the numbers know what you did ·\n" + tip : ""), [
    { label: "ask for another number.", action: () => mathematicianDialogue() },
    { label: "ask what he calculates.", action: () => {
      toast("'expectation.'\nhe taps the clipboard.\n'i do not predict. i only count.'");
    }},
    { label: "leave.", action: () => {} },
  ]);
}

export function hopperDialogue(n) {
  // hidden at night (sleeping inside the car) — drawNpc handles the gating via n.hidden flag.
  if (isNight()) {
    toast("the freight car is dark.\nyou hear breathing inside.\nyou do not wake him.", 2800);
    return;
  }
  if (!state.flags.trainHopperTalkedTo) {
    state.flags.trainHopperTalkedTo = true;
    unlockAchievement('train_hopped');
  }
  const line = HOPPER_LINES[Math.floor(Math.random()*HOPPER_LINES.length)];
  dialogue('THE TRAIN HOPPER',
    "he is wiry. a beard the color of old steel.\nhe does not stand up.\n\n" + line,
    [
      { label: "ask about the trains.", action: () => {
        toast("'they don't stop here anymore.\nthey come through.\nthey come through.'\n(- 2 brain)", 4200);
        P.brain = Math.max(0, P.brain - 2);
      }},
      { label: "ask where he's been.", action: () => hopperDialogue(n) },
      { label: "leave.", action: () => {} },
    ]);
}

export function philosopherDialogue() {
  // pick question by day (deterministic per-day cycle)
  const qIdx = ((state.day - 1) % PHILOSOPHER_QUESTIONS.length + PHILOSOPHER_QUESTIONS.length) % PHILOSOPHER_QUESTIONS.length;
  const q = PHILOSOPHER_QUESTIONS[qIdx];
  const alreadyGavenRep = (state.counters.philosopherRepDay||0) === state.day;
  dialogue('PARK BENCH PHILOSOPHER',
    "an old woman feeding pigeons.\nbrown coat. gray hair.\nshe regards you with the patience of someone who has run out of patience.\n\n'" + q + "'",
    [
      { label: alreadyGavenRep ? "think about it. (you already did today.)" : "think about it. (+1 spiritual)", action: () => {
        if (!alreadyGavenRep) {
          state.counters.philosopherRepDay = state.day;
          adjustFaction('spiritual', 1);
          toast("you stand there.\nshe nods.\nthe pigeon nods.\n+ 1 spiritual", 3200);
        } else {
          toast("she has asked already today.\nshe is patient.\nthe pigeons are not.", 2800);
        }
      }},
      { label: "ask why she's here.", action: () => {
        toast("'i live in the building.\nthe bench is closer.\nthe pigeons remember faces.'", 3600);
      }},
      { label: "leave.", action: () => {} },
    ]);
}

export function tryParkBenchSit() {
  for (const p of PROPS) {
    if (p.type !== 'park_bench') continue;
    const ddx = (P.x+P.w/2) - (p.x+p.w/2), ddy = (P.y+P.h/2) - (p.y+p.h/2);
    if (ddx*ddx + ddy*ddy < 50*50) {
      if (state.sittingOnBench) {
        // already sitting — stand
        const sat = state.benchSitT || 0;
        state.sittingOnBench = false;
        state.benchSitT = 0;
        toast("you stand up.\nthe bench remembers.\n(sat for " + Math.floor(sat/1000) + " seconds.)", 2400);
      } else {
        state.sittingOnBench = true;
        state.benchSitT = 0;
        state.benchSitGainT = 0;
        state.benchSitPasserT = 0;
        toast("you sit.\nthe pigeons consider you furniture.\nE to stand.", 2400);
      }
      return true;
    }
  }
  return false;
}

export function tryEnterOldSchool() {
  const ddx = (P.x+P.w/2) - (OLD_SCHOOL_DOOR.x + OLD_SCHOOL_DOOR.w/2);
  const ddy = (P.y+P.h/2) - (OLD_SCHOOL_DOOR.y + OLD_SCHOOL_DOOR.h/2);
  if (ddx*ddx + ddy*ddy < 44*44) {
    // v13 wave 8.6 — rank-3 gate. before this, the school was an open-air copper print
    // (60% no-risk rip). progression now has a real wall.
    if ((P.rank||0) < 3) {
      dialogue("THE OLD SCHOOL",
        "the door is chained.\nthe chain is rusted.\nyou don't have what it takes to break it yet.\n(rank 3 required.)",
        [{ label: "leave.", action: () => { state.mode = 'playing'; } }]);
      return true;
    }
    openOldSchoolInterior();
    return true;
  }
  return false;
}

export function openOldSchoolInterior() {
  const brutusAlive = runtime.npcs.find(n => n.id === 'os_brutus' && !n.dead);
  const intro = brutusAlive
    ? "inside. dust. broken desks.\nyou hear something in the gym.\nit is breathing.\nit is large."
    : "inside. dust. broken desks.\nthe gym is quiet.\nthe walls smell of pennies.";
  dialogue("THE OLD SCHOOL",
    intro,
    [
      { label: "rip copper from the walls. (40% spawn risk.)", action: () => {
        // v13 wave 8.6 — first rip per save FORCES OS Brutus spawn. no copper this time.
        // after he's killed once (state.flags.osBrutusKilled = true, flipped in death drop
        // at line ~4849), subsequent rips revert to 40% probabilistic spawn (the cousins).
        // existing saves with no flag default to FALSE — first rip post-update forces spawn
        // even if the player already ripped pre-fix. one-time tax. acceptable.
        const firstEverRip = !state.flags.osBrutusKilled && !brutusAlive;
        if (firstEverRip) {
          audio.glassBreak();
          spawnOldSchoolBrutus();
          toast("the copper is here. so is OLD SCHOOL BRUTUS.\nhe was sleeping in the gym. he is no longer sleeping.\nno copper this time.", 4400);
          state.mode = 'playing';
          saveGame();
          return;
        }
        P.copper += 2;
        state.counters.copperStripped = (state.counters.copperStripped||0) + 2;
        if (state.counters.copperStripped >= 10) unlockAchievement('copper_singer');
        audio.glassBreak();
        toast("+ 2 pure copper\nthe pipe groans.\nsomething hears it.", 3000);
        // spawn risk — cousins. only rolls after first kill, when no brutus is currently up.
        if (!brutusAlive && Math.random() < 0.4) {
          spawnOldSchoolBrutus();
          // close the interior — fight happens outside in the schoolyard
          state.mode = 'playing';
          return;
        }
        saveGame();
        openOldSchoolInterior();
      }},
      { label: "leave.", action: () => { state.mode = 'playing'; }},
    ]);
}

export function spawnOldSchoolBrutus() {
  if (runtime.npcs.find(n => n.id === 'os_brutus')) return;
  // spawn just south of the door, in the schoolyard
  const sb = {
    id: 'os_brutus', name: 'OLD SCHOOL BRUTUS', sprite: 'os_brutus',
    x: OLD_SCHOOL_DOOR.x - 30, y: OLD_SCHOOL_DOOR.y + 80, w: 36, h: 28,
    color: '#604030',
    hp: 250, maxHp: 250, speed: 1.5, hostile: true, aggro: true,
    dmg: 35, archetype: 'charger', showHp: true,
    // grab-lunge combined: charger windup → lunge → grabber freeze on hit
    chargeState: 'idle', chargeT: 0, grabFreezeT: 0,
    isOsBrutus: true,
  };
  runtime.npcs.push(sb);
  toast("OLD SCHOOL BRUTUS is loose.\nhe was sleeping in the gym.\nhe is no longer sleeping.", 4200);
  feedPost("@blocklog: old school brutus is up. someone tore copper out of the gym.", '@blocklog');
  audio.glassBreak();
  saveGame();
}

export function maybeSpawnPriceGuy() {
  if (!state.flags) return;
  // already spawned today
  if (state.flags.priceGuyDay === state.day) return;
  // every ~3 days — gated by day number
  if (state.day % 3 !== 0) return;
  // splice out any leftover price_guy from a prior day (walked-off or resolved)
  for (let i = runtime.npcs.length - 1; i >= 0; i--) {
    if (runtime.npcs[i].id === 'price_guy') runtime.npcs.splice(i, 1);
  }
  state.flags.priceGuyDay = state.day;
  // spawn at the skid row center
  const pg = {
    id: 'price_guy', name: 'THE PRICE GUY', sprite: 'price_guy',
    x: 2940, y: 1860, w: 26, h: 32, color: '#1a1818',
    hp: 80, maxHp: 80, speed: 0, hostile: false,
    isPriceGuy: true, hasFloater: '?',
    interact: priceGuyDialogue,
  };
  runtime.npcs.push(pg);
  feedPost("the price guy is back. nobody saw him arrive.", '@crackheadcent');
}

export function priceGuyDialogue(n) {
  // already paid this run-of-spawn? despawn message
  if (n.priceResolved) {
    dialogue("THE PRICE GUY", "he is gone.\nhe was here.", [{ label:'leave.', action:()=>{} }]);
    return;
  }
  dialogue("THE PRICE GUY",
    "the price guy. he has it. you have the price.\n\n'the price is what you have on you.\nall of it. or nothing.'",
    [
      { label: P.cash > 0 ? "pay the price. ($" + P.cash + ")" : "you have nothing to pay.", disabled: P.cash <= 0, action: () => {
        state.flags.priceGuyVisits = (state.flags.priceGuyVisits || 0) + 1;
        n.priceResolved = true;
        const paid = P.cash;
        P.cash = 0;
        unlockAchievement('the_price_paid');
        // RNG outcomes: knife (20%) / $200 (15%) / propane torch (10%, if not owned) / a rock (25%) / nothing (30%)
        const r = Math.random();
        if (r < 0.20) {
          P.weapon = 'knife';
          toast("you paid $" + paid + ".\nhe handed you a knife.\nthe handle is warm.\n(+ knife)", 4200);
          feedPost("the price guy handed someone a knife. the someone walked away with it.", '@crackheadcent');
        } else if (r < 0.35) {
          P.cash += 200;
          toast("you paid $" + paid + ".\nhe handed you $200.\nyou are net positive on this transaction.\nyou are not.\n(+ $200)", 5400);
          feedPost("the price guy gave someone $200. the someone gave him $" + paid + ". the math is moral.", '@crackheadcent');
        } else if (r < 0.45 && !hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          toast("you paid $" + paid + ".\nhe handed you a propane torch.\nit smells like a parking lot.\n(+ propane torch)", 5400);
          feedPost("the price guy gave someone a propane torch. he had one. now they do.", '@crackheadcent');
        } else if (r < 0.70) {
          P.rocks++;
          toast("you paid $" + paid + ".\nhe handed you a rock.\nyou suspect it is real.\n(+ 1 rock)", 4200);
        } else {
          toast("you paid $" + paid + ".\nhe handed you nothing.\nhe nods.\nyou nod. the transaction is complete.", 5400);
        }
        // despawn after a short delay so the player sees him "leave"
        n.priceWalkOff = true;
        n.speed = 1.4;
        n.targetX = -80;
        n.targetY = n.y;
        n.wanderOff = true;
        saveGame();
      }},
      { label: "walk away.", action: () => {
        toast("he watches you leave.\nhe does not move.\nthe price was the price.", 2800);
      }},
    ]);
}

export function init_vendors_places() {
  // ---------- v13 wave 8b — bus pass helpers ----------
  // the bus pass is a single-use consumable. Pinky sells one for $20; mom drops a free one at dawn
  // if spiritual ≥ liked. Using one at Pinky's spot teleports the player to the center of any
  // visited zone. State: P.inventory item id='bus_pass' (q:1, no stacking). Cooldown: once per day
  // via state.flags.busPassUsedDay === state.day.
  
  
  
  // "actively pursued" gate: any non-pet NPC that is hostile/aggro within ~220px,
  // or any cop alive (cops only exist if wanted > 0).
  
  // list of zones the player has visited (re-uses the wave 6/8a "*Entered" flags for parity).
  BUS_ZONE_TARGETS = [
    // {flag, zoneId, label}
    { flag:null,                 zoneId:'block',      label:'the block',             x:1050,y:840 },
    { flag:null,                 zoneId:'market',     label:"mom's neighborhood",   x:1060,y:1510 },
    { flag:null,                 zoneId:'scrap',      label:'the scrap yard',        x:360,y:260 },
    { flag:null,                 zoneId:'alley',      label:'the back alley',        x:370,y:1470 },
    { flag:null,                 zoneId:'church',     label:'the church',            x:1800,y:1592 },
    { flag:null,                 zoneId:'projects',   label:'the projects',          x:400,y:1790 },
    { flag:'underpassEntered',   zoneId:'underpass',  label:'the highway underpass', x:1210,y:350 },
    { flag:'trainYardEntered',   zoneId:'trainyard',  label:'the train yard',        x:810,y:2980 },
    { flag:'parkEntered',        zoneId:'park',       label:'the park',              x:2710,y:1150 },
    { flag:'skidRowEntered',     zoneId:'skidrow',    label:'skid row',              x:3315,y:1940 },
    { flag:'oldSchoolEntered',   zoneId:'oldschool',  label:'the old school',        x:3760,y:760 },
    { flag:'warehouseRowEntered',zoneId:'warehouse_row',label:'warehouse row',       x:4930,y:850 },
    { flag:'canalEntered',       zoneId:'canal',      label:'the drainage canal',   x:5420,y:2070 },
    { flag:'theLotEntered',      zoneId:'the_lot',    label:'the lot',              x:4440,y:3140 },
    { flag:'blueTarpCourtEntered',zoneId:'blue_tarp_court',label:'blue tarp court', x:7010,y:1180 },
    { flag:'cartKeepEntered',    zoneId:'cart_cavalry_keep',label:'cart cavalry keep',x:8120,y:2320 },
    { flag:'copperChoirEntered', zoneId:'copper_choir_yard',label:'copper choir yard',x:6100,y:3780 },
    { flag:'throneDitchEntered', zoneId:'throne_ditch',label:'the throne ditch',    x:8240,y:5240 },
  ];
  
  
  
  // ---------- BAGGIE BARB (the supply) ----------
  
  
  // ---------- PINKY POLENTA (rival supply, house cut) ----------
  
  
  // ---------- THE MATHEMATICIAN (under the underpass) ----------
  
  
  // ---------- v13 wave 8a — TRAIN HOPPER ----------
  // lore-only NPC under the navy freight car. tells stories about other towns.
  // no resources granted (per the anti-grind rule). first-time talk unlocks TRAIN_HOPPED.
  // faction: SPIRITUAL.
  HOPPER_LINES = [
    "a place called bremerton.\nthey pay more for copper.\nthey don't ask where you got it.",
    "i rode through laramie once.\nthe pigeons there don't have a king.\nthey have a council.",
    "memphis. the river is a vendor.\nyou give it a coin. it gives you a different coin.\nthe coin is the same coin.",
    "there is a town called good thunder.\nit is in minnesota.\nit is also a state of mind.\nyou are not in it.",
    "a guy in stockton kept a possum.\nthe possum kept him.\nthat is how it works.",
    "they say the trains stopped in '88.\nnobody told the trains.\nyou hear them.\nyou heard them.",
    "i used to be a person with an address.\nthen i was a person without one.\nnow i am the address.",
  ];
  
  
  // ---------- v13 wave 8a — PARK BENCH PHILOSOPHER ----------
  // asks one philosophical question per day. +1 spiritual once/day. faction: SPIRITUAL.
  PHILOSOPHER_QUESTIONS = [
    "the pigeons came back today.\ndid you?",
    "are you the man in the story\nor the man hearing it?",
    "the bench is wet.\nthat means something.",
    "a pigeon flew at me yesterday.\nit apologized.",
    "if you keep walking the loop,\nyou eventually walk a different loop.\nyou should know.",
    "i was a different person at noon.\nnoon was an hour ago.\nwho is asking.",
    "the fountain has been running since 1994.\nthe water is the same water.\nthat is also you.",
  ];
  
  
  // ---------- v13 wave 8a — PARK BENCH SIT MECHANIC ----------
  // E within range of a park_bench toggles sit. while sitting: +1 brain/2s, shakes unchanged.
  // Long sits (>60s continuous) trigger BENCH_PRESS + may surface a passerby comment.
  
  
  // ---------- v13 wave 8a — OLD SCHOOL interior (modal dialogue) ----------
  // Wave 7 hideout pattern. E on the school door opens a dialogue: extract copper (2/attempt,
  // 40% chance to spawn the OLD SCHOOL BRUTUS boss), or leave.
  OLD_SCHOOL_DOOR = { x: 3760, y: 700, w: 24, h: 28 }; // south face, door gap of the OLDSCHOOL building
  
  
  
  
  // ---------- v13 wave 8a — THE PRICE GUY (random encounter every ~3 days in SKID ROW) ----------
  // One-shot per day. Pays "the price" (all cash) for a single random outcome:
  // knife / $200 / propane torch / a rock / nothing. true gamble.
  
  
  
  
}
