/* Generated from frozen rock_bottom_v19.html.
 * Source seams: factions and territory.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { last } from '../core/update.js';
import { currentZone } from '../data/npc_spawns.js';
import { feedPost } from './communications.js';

export let FACTION_NAMES, FACTION_TIER_LABELS, TIER_TRANSITION_LINES, TERRITORY_GREETINGS, TERRITORY_LOVED_LINES, TERRITORY_HATED_LINES, TERRITORY_NPC_TARGETS;

export function factionTier(v) {
  if (v <= -10) return 'hated';
  if (v >= 25)  return 'loved';
  if (v >= 10)  return 'liked';
  return 'neutral';
}

export function adjustFaction(faction, delta) {
  if (!FACTION_NAMES.includes(faction) || !delta) return;
  if (!P.faction) P.faction = { street: 0, scrap: 0, spiritual: 0 };
  const before = P.faction[faction] | 0;
  const beforeTier = factionTier(before);
  const after = Math.max(-50, Math.min(50, before + delta));
  P.faction[faction] = after;
  const afterTier = factionTier(after);
  if (beforeTier !== afterTier) {
    const lines = TIER_TRANSITION_LINES[faction] && TIER_TRANSITION_LINES[faction][afterTier];
    if (lines) {
      try { feedPost(lines[0].split(': ').slice(1).join(': ') || lines[0], lines[0].split(': ')[0]); } catch(e) {}
      try { toast(lines[1], 2200); } catch(e) {}
    }
    // LOVED milestone achievements
    if (afterTier === 'loved') {
      if (faction === 'street')    try { unlockAchievement('the_block_knows'); } catch(e) {}
      if (faction === 'scrap')     try { unlockAchievement('yuri_counts_you'); } catch(e) {}
      if (faction === 'spiritual') try { unlockAchievement('mom_is_proud'); } catch(e) {}
    }
  }
}

export function applyRep(deltas) {
  if (!deltas) return;
  for (const k of FACTION_NAMES) {
    if (deltas[k]) adjustFaction(k, deltas[k]);
  }
}

export function lovedAmbientKey(faction) { return 'lovedAmbient_'+faction+'_day'; }

export function updateTerritory(dt) {
  if (state.mode !== 'playing') return;
  // additional defensive pauses: any open dialogue / interior modal / hideout / heist / boss / cook
  // (state.mode handles all of these — when a modal opens it flips off 'playing').
  if (!P.faction) P.faction = { street: 0, scrap: 0, spiritual: 0 };

  state.territoryT = (state.territoryT || 0) + dt;
  if (state.territoryT < 2000) return;
  state.territoryT = 0;

  const z = currentZone();
  const faction = z ? (z.faction || 'neutral') : 'neutral';
  // zone-exit / faction-change: reset heat + clear greeting bookkeeping for the prior zone
  if (state.territoryZoneId !== (z ? z.id : null)) {
    state.territoryHeat = 0;
    state.territoryGreeted = new Set();
    state.territoryZoneId = z ? z.id : null;
  }
  if (!z || faction === 'neutral') {
    // outside any faction zone — also bleed any leftover heat
    state.territoryHeat = 0;
    state.territoryCashMult = 1.0;
    return;
  }
  const tier = factionTier(P.faction[faction] || 0);

  if (tier === 'hated') {
    state.territoryHeat = (state.territoryHeat || 0) + 1;
    state.territoryCashMult = 1.0;
    // ambient line every ~15 ticks (~30s)
    if ((state.territoryHeat % 15) === 7) {
      const ln = TERRITORY_HATED_LINES[faction];
      if (ln) { try { feedPost(ln[0].split(': ').slice(1).join(': ') || ln[0], ln[0].split(': ')[0]); } catch(e){} }
    }
    if (state.territoryHeat >= 30) {
      state.territoryHeat = 0;
      if (P.wanted < 3) { P.wanted = Math.min(3, P.wanted + 1); P.wantedT = 0; toast("a phone call was made.\nwanted +1", 2200); }
    }
    return;
  }

  // neutral — no effect, but reset cash mult so old liked-bonus doesn't linger
  if (tier === 'neutral') {
    state.territoryHeat = 0;
    state.territoryCashMult = 1.0;
    return;
  }

  // LIKED or LOVED
  state.territoryCashMult = (tier === 'loved') ? 1.4 : 1.2;

  // LOVED: +1 brain per 5 ticks (~10s)
  if (tier === 'loved') {
    state.territoryBrainTicks = (state.territoryBrainTicks || 0) + 1;
    if (state.territoryBrainTicks >= 5) {
      state.territoryBrainTicks = 0;
      P.brain = Math.min(100, P.brain + 1);
    }
    // once-per-day-per-faction ambient line on the first tick of the zone-entry (this day)
    const key = lovedAmbientKey(faction);
    if (state.flags[key] !== state.day) {
      state.flags[key] = state.day;
      const ln = TERRITORY_LOVED_LINES[faction];
      if (ln) {
        try { feedPost(ln[0].split(': ').slice(1).join(': ') || ln[0], ln[0].split(': ')[0]); } catch(e){}
        try { toast(ln[1], 2400); } catch(e){}
      }
    }
  }

  // greetings — find a known NPC within 80px who hasn't greeted yet this zone-entry (LIKED)
  // or hasn't greeted in the last ~10s (LOVED).
  const pcx = P.x + P.w/2, pcy = P.y + P.h/2;
  const now = (performance && performance.now) ? performance.now() : Date.now();
  state.territoryGreetLast = state.territoryGreetLast || {};
  for (const n of runtime.npcs) {
    if (n.dead) continue;
    if (!TERRITORY_NPC_TARGETS.has(n.id)) continue;
    const ncx = n.x + n.w/2, ncy = n.y + n.h/2;
    const dx = pcx - ncx, dy = pcy - ncy;
    if (dx*dx + dy*dy > 80*80) continue;
    if (tier === 'liked') {
      if (state.territoryGreeted.has(n.id)) continue;
      state.territoryGreeted.add(n.id);
    } else {
      const last = state.territoryGreetLast[n.id] || 0;
      if (now - last < 10000) continue;
      state.territoryGreetLast[n.id] = now;
    }
    const pool = TERRITORY_GREETINGS[faction] || [];
    if (pool.length) {
      const line = pool[Math.floor(Math.random()*pool.length)];
      try { toast(line, 2200); } catch(e){}
    }
    break; // one greeting per tick
  }
}

export function init_factions() {
  // ---------- v13 wave 7 — faction reputation ----------
  // three reputation tracks separate from cred. integer per faction.
  // see SPEC.md FACTIONS for tier thresholds and the rep delta contract.
  FACTION_NAMES = ['street', 'scrap', 'spiritual'];
  FACTION_TIER_LABELS = { hated:'HATED', neutral:'NEUTRAL', liked:'LIKED', loved:'LOVED' };
  
  // tier transition broadcasts. one line per faction × tier crossing.
  TIER_TRANSITION_LINES = {
    street: {
      liked:   ["@hardcandy: someone has been seen with tony. someone keeps being seen.", "tony nodded twice."],
      loved:   ["@hardcandy: tony said your name three times today.", "tony said your name."],
      hated:   ["@blocklog: word travels. word does not return.", "word is out."],
      neutral: ["@blocklog: the block is quiet about you again.", "the block forgets, slowly."],
    },
    scrap: {
      liked:   ["@blocklog: yuri counted three times today. counted right twice.", "yuri counted you in."],
      loved:   ["@blocklog: pete wrote down a number. pete does not write down numbers.", "pete wrote it down."],
      hated:   ["@hardcandy: the yard gate is half closed. half closed is closed.", "the gate is half closed."],
      neutral: ["@blocklog: the yard noticed nothing today.", "the yard is the yard again."],
    },
    spiritual: {
      liked:   ["@blocklog: mom called. mom does not always call.", "mom called."],
      loved:   ["@hardcandy: the possum sat upright today. the possum is not always upright.", "the possum sat upright."],
      hated:   ["@blocklog: mom hasn't called. her phone is on silent.", "mom's phone is silent."],
      neutral: ["@blocklog: the church bell rang on the hour. nothing else.", "the bell rang. nothing else."],
    },
  };
  // single mutator. clamps to [-50, +50], detects tier transitions, broadcasts on crossings.
  
  // convenience: bulk apply a delta object like { street: +1, spiritual: -1 }
  
  
  // ---------- v13 wave 8b — faction territory ----------
  // per-zone-faction NPC greetings. fire when player walks within ~80px of a known NPC inside
  // a LIKED or LOVED district. rate-limited per NPC per zone-entry (LIKED) or once per ~10s
  // per NPC (LOVED).
  TERRITORY_GREETINGS = {
    street: [
      "tony nods from across the street.",
      "pete sees you. pete waves with the bat.",
      "barb glances up from the crossword.\nshe glances back down.",
      "lurch lifts a finger.\nthat's the greeting.",
      "sherri brushes a spider off you. there was no spider.",
      "stripe pretends not to look. stripe looked.",
      "paulie shows you the face.\nyou nod at the face.",
    ],
    scrap: [
      "yuri counts you. counts twice.",
      "pete writes a number down. it is not your number.",
      "biggu raises a copper pipe. like a wave.",
      "the conductor tips his cap.",
      "the dog stops chewing. for a second.",
      "the mathematician glances up.\nthen down.",
      "a wreck creaks as you pass. it was not the wind.",
    ],
    spiritual: [
      "the priest blesses you as you pass.",
      "the philosopher nods like she knew.",
      "mom waves from across the lot.",
      "a pigeon walks beside you for two steps.",
      "the train hopper salutes from the rails.",
      "the possum sits upright.",
      "the fountain coughs in time with you.",
    ],
  };
  TERRITORY_LOVED_LINES = {
    street:    ["@hardcandy: tony's people made room.", "tony's people made room."],
    scrap:     ["@blocklog: the yard knows your boots.", "the yard knows your boots."],
    spiritual: ["@hardcandy: the bench is yours today.", "the bench is yours today."],
  };
  TERRITORY_HATED_LINES = {
    street:    ["@blocklog: you've been spotted on tony's block.", "you've been spotted."],
    scrap:     ["@blocklog: the gate watched you walk in.", "the gate watched you."],
    spiritual: ["@hardcandy: the bench did not move when you sat.", "the bench did not move."],
  };
  TERRITORY_NPC_TARGETS = new Set([
    'tony','yuri','pete','barb','lurch','sherri','paulie','stripe','priest','mom',
    'pinky','conductor','biggu','math','train_hopper','philosopher','larry',
  ]);
  
  
  // ticker — fires every ~2s while player is in a faction-tagged zone and not in an interior mode.
  // hated: accumulate state.territoryHeat (cap at 60). at >=30 → wanted +1, reset, ambient line.
  // liked: greetings, +20% to a multiplier read by future cash-pile spawns (state.territoryCashMult).
  // loved: greetings (ungated), +1 brain / 10s, +40% cash mult, once-per-day-per-faction ambient line.
  
  
  
}
