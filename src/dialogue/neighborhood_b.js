/* Generated from frozen rock_bottom_v19.html.
 * Source seams: neighborhood dialogue, second half.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, applyEquipStats, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { vendorPrice } from '../data/catalogs.js';
import { blockMenu, pickupWeapon } from '../minigames/activities.js';
import { aggroNpc, pickCrownSpot, questToast, startPigeonCrownQuest } from '../systems/combat.js';
import { broadcastNews, feedPost, ringPhone } from '../systems/communications.js';
import { adjustFaction } from '../systems/factions.js';
import { recordRecognition } from '../systems/recognition.js';

export function triggerFallenPriestTransform() {
  const n = runtime.npcs.find(x => x.id === 'priest');
  if (!n || n.dead) return;
  if (state.flags.omalleyFallen) return;
  state.flags.omalleyFallen = true;
  // make the side quest active if it wasn't already
  if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
    state.quests.fallen_priest.available = true;
  }
  // transform in place
  n.id = 'omalley_fallen';
  n.name = "FATHER O'MALLEY (FALLEN)";
  n.archetype = 'priest_fallen';
  n.hostile = true; n.aggro = true;
  n.maxHp = 160; n.hp = 160;
  n.speed = 1.6;
  n.dmg = 22;
  n.color = '#2a1a2a';
  n.showHp = true;
  n.isOmalleyFallen = true;
  n.attackCd = 0;
  // reset combat scratch
  n.chargeState = 'idle'; n.chargeT = 0; n.chargeCdT = 0;
  audio.bossRoar();
  state.shake = 14;
  state.flash = 1; state.flashColor = 'rgba(120,40,140,.35)';
  toast("father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong.", 5500);
  broadcastNews("PRIEST AT CHURCH 'NOT BEHAVING AS EXPECTED.' WITNESSES UNCLEAR.");
  feedPost("father o'malley turned. the collar is on the floor.", '@crackheadcent');
  saveGame();
}

export function maybeFireFallenPriestCall() {
  if (!state.flags || state.flags.fallenPriestCallFired) return;
  if (state.flags.omalleyFallen) return;
  if (P.rank < 3) return;
  if ((state.counters.churchVisits||0) < 3) return;
  if (state.flags && !state.flags.introDone) return;
  state.flags.fallenPriestCallFired = true;
  if (state.quests.fallen_priest && !state.quests.fallen_priest.done) {
    state.quests.fallen_priest.available = true;
  }
  if (typeof ringPhone === 'function') {
    ringPhone({ from: 'unknown number', text: "father o'malley says the church belongs to whoever has the keys.\nyou don't." });
  } else {
    toast("unknown number:\n'father o'malley says the church belongs to whoever has the keys.\nyou don't.'", 5000);
  }
  saveGame();
}

export function conductorDialogue() {
  dialogue('THE CONDUCTOR', "the train is coming.\nit has always been coming.\nit will never be here.", [
    { label: 'sell 3 PURE COPPER. $90.', disabled: P.copper<3, action: () => {
      P.copper -= 3; P.cash += 90; toast('- 3 pure copper\n+ $90\nthe conductor nods at no one.'); audio.coin();
      if (!state.quests.conductor.done) { state.quests.conductor.done = true; questToast("THE CONDUCTOR'S BARGAIN"); }
      saveGame();
    }},
    { label: 'ask when the train arrives.', action: () => {
      toast("the conductor does not answer.\nthe conductor is the answer.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function larryDialogue(n) {
  dialogue('LOUD LARRY', "WHAT.\nWHAT.\nWHAT WHAT WHAT.", [
    { label: 'match volume. (+1 cred)', action: () => {
      P.cred++; toast("YOU YELL BACK.\nlarry respects this.\n+ 1 cred");
    }},
    { label: 'fight.', action: () => { aggroNpc(n); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function stripeDialogue() {
  // v13 wave 3 — visit-counter feeds package side quest after 3 visits.
  state.counters.stripeVisits = (state.counters.stripeVisits||0) + 1;
  const q = state.quests.stripe_package;

  // betrayed branch — once the player opened the package, stripe knows. fencing is closed.
  if (state.flags.stripeBetrayed) {
    dialogue('STRIPE', "stripe knows.\nstripe has friends.\nstripe is patient.\nthe windbreaker is still.", [
      { label: 'try to apologize.', action: () => {
        toast("stripe does not blink.\n(this is not tony's not-blinking.\nthis is different.)");
      }},
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }

  // package mid-quest: stripe waiting for delivery
  if (state.flags.hasStripePackage) {
    dialogue('STRIPE', "you have it.\nyou have not delivered it.\nthe conductor is in the train yard.\nhe does not move.", [
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }

  const buyP = vendorPrice(8);
  // v13 wave 6.5 — stripe's fence price degrades with daily volume.
  // first 3 rocks: full $6. rocks 4-6: $4. rocks 7-9: $2 floor. 10+: closed for the day.
  // helper returns the $ per rock at index (0-based) and the message for the bracket.
  const fencedToday = state.counters.stripeFencedToday || 0;
  const fencePerRock = (idx) => {
    if (idx < 3) return vendorPrice(6);
    if (idx < 6) return vendorPrice(4);
    return Math.max(1, vendorPrice(2));
  };
  const fenceClosed = fencedToday >= 10;
  // preview the immediate next-rock rate for the label
  const nextSellP = fencePerRock(fencedToday);
  // v13 wave 7 — stripe fence rep ledger. each rock fenced is +1 street, -1 spiritual,
  // with a spiritual cap of -3 per day (tracked on stripeSpiritualDayHits).
  const spiritualHits = (state.counters.stripeSpiritualDayHits || 0);
  const spiritualHitsDay = (state.counters.stripeSpiritualDayHitsDay || 0);
  const todaysHits = (spiritualHitsDay === state.day) ? spiritualHits : 0;
  function fenceRepTick() {
    adjustFaction('street', 1);
    const curDay = (state.counters.stripeSpiritualDayHitsDay === state.day) ? (state.counters.stripeSpiritualDayHits || 0) : 0;
    if (curDay < 3) {
      adjustFaction('spiritual', -1);
      state.counters.stripeSpiritualDayHits = curDay + 1;
      state.counters.stripeSpiritualDayHitsDay = state.day;
    }
  }
  const opts = [
    { label: P.cash>=buyP ? `buy stripe's rock. $${buyP}.` : "you can't afford it.", disabled: P.cash<buyP, action: () => {
      P.cash -= buyP;
      P.stripeLoyalty = (P.stripeLoyalty||0) + 1;
      if (Math.random()<0.4) {
        toast(`- $${buyP}\n(it is soap. you keep it. it is soap.)`);
        P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
        P.tonyOffenses = Math.max(0, P.tonyOffenses-1);
      } else {
        P.rocks++; toast(`- $${buyP}\n+ 1 rock\n(yeah it\'s probably real.)`); audio.coin();
      }
      adjustFaction('street', 1); // wave 7 — buying from stripe also nudges street
      if (P.stripeLoyalty === 5) {
        toast("stripe nods slowly.\nhe sees you.\nhe has a proposal.", 3000);
      }
      saveGame();
    }},
  ];
  if (fenceClosed) {
    opts.push({ label: 'sell rocks to stripe. (closed today.)', action: () => {
      toast("stripe will not buy from you today.\ntomorrow.", 3000);
    }});
  } else {
    opts.push({ label: P.rocks>=1 ? `sell 1 rock to stripe. $${nextSellP}.` : "you have no rocks to sell.", disabled: P.rocks<1, action: () => {
      const px = fencePerRock(state.counters.stripeFencedToday||0);
      P.rocks--; P.cash += px;
      state.counters.stripeFencedToday = (state.counters.stripeFencedToday||0) + 1;
      P.lifetime.rocksFenced = (P.lifetime.rocksFenced||0) + 1;
      fenceRepTick(); // wave 7 — fence rep delta
      const ft = state.counters.stripeFencedToday;
      let tail = '';
      if (ft === 4) tail = "\nstripe is taking less today.\nstripe is taking what stripe takes.";
      else if (ft === 7) tail = "\nstripe is done.\nstripe is done with rocks.\ngo away.";
      else if (ft === 10) tail = "\nstripe will not buy from you today.\ntomorrow.";
      toast(`- 1 rock\n+ $${px}${tail || `\nstripe pockets it.\nit will be $${buyP} by morning.`}`);
      audio.coin(); saveGame();
    }});
    opts.push({ label: P.rocks>=3 ? `sell rocks bulk. ($${nextSellP}/rock, gating.)` : "stripe wants 3+ for a bulk deal.", disabled: P.rocks<3, action: () => {
      let totalCash = 0; let sold = 0; let hitClose = false; let hitDegrade1 = false; let hitDegrade2 = false;
      while (P.rocks > 0 && (state.counters.stripeFencedToday||0) < 10) {
        const before = state.counters.stripeFencedToday||0;
        const px = fencePerRock(before);
        P.rocks--; sold++;
        totalCash += px;
        state.counters.stripeFencedToday = before + 1;
        fenceRepTick(); // wave 7 — fence rep delta per rock
        const after = state.counters.stripeFencedToday;
        if (after === 4) hitDegrade1 = true;
        if (after === 7) hitDegrade2 = true;
        if (after === 10) { hitClose = true; break; }
      }
      P.cash += totalCash;
      P.lifetime.rocksFenced = (P.lifetime.rocksFenced||0) + sold;
      let tail = '';
      if (hitClose) tail = "\nstripe will not buy from you today.\ntomorrow.";
      else if (hitDegrade2) tail = "\nstripe is done.\nstripe is done with rocks.";
      else if (hitDegrade1) tail = "\nstripe is taking less today.\nstripe is taking what stripe takes.";
      toast(`- ${sold} rocks\n+ $${totalCash}\nstripe stacks them with his.\nthe stack is now his stack.${tail}`, 4200);
      audio.coin(); saveGame();
    }});
  }
  // v13 wave 3 — package quest offer on 3rd+ visit
  if (q && !q.done && !q.available && state.counters.stripeVisits >= 3) {
    opts.push({ label: "stripe leans in. listen.", action: () => offerStripePackage() });
  } else if (q && q.available && !q.done && !state.flags.hasStripePackage) {
    opts.push({ label: "ask about the package again.", action: () => offerStripePackage() });
  }
  opts.push({ label: P.stripeLoyalty >= 5 ? "ask stripe about the corner." : "ask stripe about himself.", action: () => {
      if (P.stripeLoyalty >= 5) {
        dialogue('STRIPE', "yo. we should team up.\ntake tony's corner.\nyou get tuesdays and thursdays.\ni get the rest.\nyou ride at my side. on me. with me.", [
          { label: 'agree. ride with stripe.', action: () => { spawnCoopBoss(); }},
          { label: 'decline. (the deal expires.)', action: () => { toast("stripe nods.\nhe will not ask again.\nthe air shifts."); P.stripeLoyalty = -1; }},
        ]);
      } else {
        toast("'stripe is stripe.'\nhe stares.\nthe windbreaker rustles.");
      }
    }});
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('STRIPE', "$8 a rock. stripe got the deal.\nstripe is wearing a faded windbreaker.", opts);
}

export function offerStripePackage() {
  const q = state.quests.stripe_package;
  if (!q) return;
  dialogue('STRIPE', "stripe got a package.\ngoes to the conductor in the train yard.\nstripe's name. stripe's money.\ndon't open it.\ndon't.", [
    { label: 'take it.', action: () => {
      q.available = true;
      state.flags.hasStripePackage = true;
      P.inventory.push({id:'stripe_package', n:"stripe's sealed package", q:1});
      toast("+ stripe's package\nbrown paper. greasy in one corner.\ntake it to the conductor at the train yard.\ndon't.", 4000);
      saveGame();
    }},
    { label: 'pass. (offer holds.)', action: () => {
      toast("'next time.'\nstripe shrugs.\nthe windbreaker stays still.");
    }},
  ]);
}

export function openStripePackage() {
  const r = Math.random();
  state.flags.hasStripePackage = false;
  P.inventory = P.inventory.filter(i => i.id !== 'stripe_package');
  unlockAchievement('what_s_in_the_box');
  if (state.quests.stripe_package && !state.quests.stripe_package.done) {
    state.quests.stripe_package.done = true; // quest closes either way
  }
  state.flags.stripeBetrayed = true;
  if (r < 0.35) {
    // a brick of clean rocks
    P.rocks += 5;
    audio.coin();
    dialogue('THE PACKAGE', "you tear it open.\nfive rocks. wrapped in newsprint.\nthe newsprint is from 2003.\n\n+ 5 rocks\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else if (r < 0.65) {
    // 2 soap
    P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
    P.inventory.push({id:'soap',n:'a small bar of soap',q:1});
    dialogue('THE PACKAGE', "you tear it open.\ntwo bars of soap.\nthey smell like cherries.\n\n+ 2 soaps\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else if (r < 0.90) {
    // a knife (new weapon)
    pickupWeapon('knife');
    dialogue('THE PACKAGE', "you tear it open.\nit is a knife.\nthe handle is wrapped in electrical tape.\n\n+ a knife\nstripe knows. stripe will know.", [
      { label: 'leave.', action: () => {} },
    ]);
  } else {
    // a wire — bait. wanted +2. cops arrive.
    P.wanted = Math.min(3, P.wanted + 2);
    audio.copSiren();
    dialogue('THE PACKAGE', "you tear it open.\nit is a wire.\na small bag of nothing taped to it.\n\nthe package was bait.\nwanted +2.\nstripe knows. stripe will know.", [
      { label: 'sprint.', action: () => {} },
    ]);
  }
  saveGame();
}

export function spawnCoopBoss() {
  if (state.bossActive) return;
  state.bossActive = true;
  state.bossKind = 'tony';
  state.bossPhase = 1;
  state.coopMode = true;
  const tony = runtime.npcs.find(n=>n.id==='tony');
  const stripe = runtime.npcs.find(n=>n.id==='stripe');
  if (!tony) return;
  state.bossNPC = tony;
  tony.hostile = true; tony.aggro = true; tony.maxHp = 200; tony.hp = 200; tony.speed = 1.8;
  tony.dmg = 12; tony.color = '#5a2018';
  tony.coatsOff = 1;
  // stripe becomes ally — teleport near player, hostile to tony only
  if (stripe) {
    stripe.x = P.x + 32; stripe.y = P.y;
    stripe.hp = 100; stripe.maxHp = 100;
    stripe.speed = 1.4;
    stripe.isAlly = true; stripe.allyTarget = 'tony';
    stripe.hostile = false; stripe.aggro = false;
    stripe.interact = () => toast("'this is happening.'\nstripe does not stop walking.");
  }
  audio.bossRoar();
  toast("stripe walks beside you.\nthe corner is ahead.\ntony sees you.\nthen he sees stripe.\nthen he tears off the first coat.", 4000);
  broadcastNews("ALLIANCE OBSERVED. TWO MEN. ONE WINDBREAKER. ONE CORNER.");
  feedPost("teamed up with stripe. heading to tony. wish us anything.", '@crackheadcent');
}

export function pigeonDialogue() {
  // v13 wave 3 — visit count drives the crown side-quest offer (2+ visits)
  state.counters.pigeonVisits = (state.counters.pigeonVisits||0) + 1;
  const q = state.quests.pigeon_crown;
  const opts = [
    { label: P.cash>=2 ? 'pay $2 for a secret.' : "you don't have $2.", disabled: P.cash<2, action: () => {
      P.cash -= 2;
      state.counters.pigeonTrade = (state.counters.pigeonTrade||0) + 2;
      if (state.counters.pigeonTrade >= 20) unlockAchievement('one_foot');
      recordRecognition('park','buy','pigeon_secret');
      const secrets = [
        "the copper sings in b flat.\nyou are not crazy.",
        "yuri is going home to a family.\nthis is information.",
        "pete is on his lunch break. forever.",
        "the possum has a route.\nyou are on it.",
        "tony has, in fact, blinked. once. in 1994.",
        "father o'malley is not real.\nhe is. but also not.",
      ];
      toast(secrets[Math.floor(Math.random()*secrets.length)], 4500);
    }},
  ];
  let headerExtra = '';
  if (q && !q.done && !q.available && state.counters.pigeonVisits >= 2) {
    headerExtra = "\nhe regards you.\nhis crown is missing.\nit has been missing for some time.";
    opts.push({ label: "ask about the crown.", action: () => {
      const spot = pickCrownSpot();
      dialogue('THE PIGEON KING', `the crown fell.\nthe pigeons grieve.\nhe says where it might be.\n\nlast seen: ${spot.where}.`, [
        { label: 'accept the search.', action: () => {
          startPigeonCrownQuest();
          toast("the pigeons watch you leave.\nyou are on a route now.", 3000);
        }},
        { label: 'decline.', action: () => { toast("the pigeons watch you leave.\nthey are not impressed."); }},
      ]);
    }});
  } else if (q && q.available && !q.done) {
    headerExtra = "\nhe has not blinked since you accepted.\nthe crown is still missing.";
  } else if (q && q.done) {
    headerExtra = "\nthe crown is back. the pigeons walk in formation now.";
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('THE PIGEON KING', "one foot.\nunblinking.\nhe wants the bread." + headerExtra, opts);
}

export function bigguDialogue() {
  dialogue('THE BIG GUY', "i am the big guy.\nhe is, in fact, tall.\nhe lives under here.", [
    { label: P.copper>=5 ? 'trade 5 PURE COPPER for the cart.' : "you need 5 pure copper.", disabled: P.copper<5, action: () => {
      P.copper -= 5; P.cartMounted = true;
      // v13 wave 8b — route through applyEquipStats so the cart cap (base × 1.7) takes effect
      applyEquipStats();
      toast("- 5 pure copper\n+ THE BIG GUY'S CART\n+10 max hp. faster.\n(the wheels do not align.)");
      saveGame();
    }},
    { label: 'ask how tall.', action: () => {
      toast("tall.\nthat is the answer he gives. tall.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function init_dialogue_b() {
  
  
  // v13 wave 5 — phone-call quest hook for the fallen priest. fires once when:
  //   rank >= 3, church visits >= 3, !introActive, !already-fallen, !call-already-fired.
  // the player gets a phone toast that opens the quest. completion = killing the fallen priest.
  
  
  
  
  
  
  
  
  // v13 wave 3 — stripe's package side quest
  
  
  // v13 wave 3 — opening stripe's package (from blockMenu when alone)
  
  
  
  
  
  
  
  
  
}
