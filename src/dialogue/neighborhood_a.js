/* Generated from frozen rock_bottom_v19.html.
 * Source seams: neighborhood dialogue, first half.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, applyEquipStats, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { vendorPrice } from '../data/catalogs.js';
import { isNight } from '../data/npc_spawns.js';
import { triggerFallenPriestTransform } from './neighborhood_b.js';
import { startLockpickMini } from '../legacy.js';
import { hasPropane } from '../minigames/heat.js';
import { aggroNpc, playerAttack, questToast, spawnBoss } from '../systems/combat.js';
import { feedPost, spawnPetPossum } from '../systems/communications.js';
import { adjustFaction, applyRep, factionTier } from '../systems/factions.js';

export let LOCAL_POSSUM_PROPHECIES;

export function tonyDialogue(n) {
  const lines = [
    "what.",
    "$10. you know the number.",
    "you again. of course.",
    "three coats. ten dollars. simple math.",
  ];
  // v13 wave 7 — street-liked or street-loved drops the base by $1 (then charisma further shaves).
  const streetTier = factionTier(P.faction ? P.faction.street : 0);
  const tonyBase = (streetTier === 'liked' || streetTier === 'loved') ? 9 : 10;
  const rockPrice = vendorPrice(tonyBase);
  const discount = rockPrice < 10;
  const charismaTag = discount ? "\nhe looks at your hat once. then twice. then not again." : '';
  const txt = `${lines[Math.floor(Math.random()*lines.length)]}\n\ntony does not blink. tony is wearing three coats.${charismaTag}`;
  dialogue('TRE BAG TONY', txt, [
    { label: `buy a rock. $${rockPrice}.`, disabled: P.cash<rockPrice, action: () => {
      P.cash -= rockPrice; P.rocks++; P.tonyOffenses = Math.max(0, P.tonyOffenses-1);
      state.counters.rocksBought++;
      if (state.counters.rocksBought >= 50) unlockAchievement('tonys_worst');
      toast(`- $${rockPrice}\n+ 1 rock${discount?'\n(the crown got you a discount.\nhe is not happy about it.)':''}`);
      audio.coin();
      adjustFaction('street', 1); // v13 wave 7 — tony rock buy = street +1
      if (!state.quests.first_rock.done) { state.quests.first_rock.done = true; questToast('THE FIRST ROCK'); }
      saveGame();
    }},
    { label: P.tonyOffenses > 2 ? 'short him. ($5)' : 'short him. ($5)', disabled: P.cash<5, action: () => {
      P.cash -= 5;
      P.tonyOffenses++;
      if (P.tonyOffenses < 3) {
        toast("tony stares. takes the $5. does not give a rock.\nyou now owe a kind of debt.");
      } else {
        toast("tony's eye twitches. he remembers.\nthe boss fight will come.");
        spawnBoss();
      }
      saveGame();
    }},
    { label: 'try to negotiate.', action: () => {
      toast('tony explains, slowly, that he does not negotiate.\nhe is, in fact, negotiating right now.\n(this changes nothing.)');
    }},
    { label: P.cred >= 100 ? 'challenge for the corner. (boss)' : 'try to take the corner. (need 100 cred)', disabled: P.cred < 100, action: () => {
      toast('tony tears off his coat. then another coat.\nthen a third coat.');
      spawnBoss();
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function yuriDialogue() {
  // v13 wave 7 — scrap liked = $28/copper; loved = $28 (same as liked); else $25
  const scrapTier = factionTier(P.faction ? P.faction.scrap : 0);
  const yuriRate = (scrapTier === 'liked' || scrapTier === 'loved') ? 28 : 25;
  // v13 wave 7 — scrap >= +5 unlocks the back-corner shed hideout (one-time $150).
  const hideoutGate = (P.faction && P.faction.scrap >= 5) && !(state.flags && state.flags.scrapHideoutOwned);
  const opts = [
    { label: `sell 1 PURE COPPER. $${yuriRate}.`, disabled: P.copper<1, action: () => {
      P.copper--; P.cash += yuriRate; toast('- 1 pure copper\n+ $'+yuriRate); audio.coin();
      adjustFaction('scrap', 1); // wave 7 — yuri copper sell = scrap +1
      saveGame();
    }},
    { label: 'sell all pure copper.', disabled: P.copper<1, action: () => {
      const sold = P.copper; const got = sold * yuriRate; P.cash += got;
      toast(`- ${sold} pure copper\n+ $${got}`); P.copper = 0; audio.coin();
      adjustFaction('scrap', Math.min(5, sold)); // cap +5 per bulk sale to avoid runaway
      saveGame();
    }},
    { label: 'ask about brutus.', action: () => {
      toast("yuri does not look up.\n'BRUTUS REMEMBER. you know what you did.'\n(you do not.)");
    }},
    { label: 'ask about the dog.', action: () => {
      const dq = state.quests.scrap_dog;
      if (!dq || dq.state === 'idle' || dq.state === 'left') {
        toast("yuri does not look up.\n'the dog. is the dog.\nthe dog is fine.'");
      } else if (dq.state === 'fed') {
        toast("yuri does not look up.\n'somebody fed the dog.\nthe dog is no different.'\n(yuri pauses. is different.)");
      } else if (dq.state === 'freed') {
        toast("yuri looks up.\n'the dog is gone.'\nhe looks back down.\n'good for the dog.'");
      }
    }},
  ];
  if (hideoutGate) {
    opts.push({ label: P.cash>=150 ? 'rent the back-corner shed. $150.' : 'rent the shed. ($150 — short.)',
      disabled: P.cash<150,
      action: () => {
        P.cash -= 150; state.flags.scrapHideoutOwned = true;
        toast("- $150\nyuri tosses you a bent key.\n'shed. back corner.\ndon't bring problems.'", 3600);
        feedPost("got a key today. it bent in the pocket.", '@crackheadcent');
        adjustFaction('scrap', 2);
        saveGame();
      }
    });
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('YURI', "what you bring, idiot." + (hideoutGate ? "\nthe shed is empty.\nthe shed could be yours." : ''), opts);
}

export function scrapDogDialogue(n) {
  const q = state.quests.scrap_dog;
  if (!q) return;
  // mark quest as encountered
  if (q.state === 'idle') q.available = true;
  // already-resolved branches
  if (q.state === 'fed') {
    dialogue('THE DOG', "the dog. fed. matted but slightly less so.\nhe blinks. once. that's the whole interaction.", [
      { label: 'pet him.', action: () => { toast("the dog accepts. tolerantly.\nthe chain rattles.", 1800); P.cred += 1; saveGame(); }},
      { label: 'leave him.', action: () => {} },
    ]);
    return;
  }
  if (q.state === 'freed') {
    dialogue('THE DOG (gone)', "the post is here.\nthe chain is on the ground.\nthe dog is not here.", [
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }
  if (q.state === 'left') {
    if (n.dead) return;
    dialogue('THE DOG', "the dog. still chained.\nhe blinks at you.\nhe has been waiting.", [
      { label: 'feed him. (-1 food, +1 cred)', disabled: !P.inventory.find(i=>i.id==='food'), action: () => {
        const i = P.inventory.findIndex(x=>x.id==='food'); if (i>=0) P.inventory.splice(i,1);
        P.cred += 1;
        q.state = 'fed'; q.done = true;
        toast("he ate it without looking up.\nhe looks at you once.\nthen back to the food.", 3200);
        feedPost("fed the scrap-yard dog.", '@crackheadcent');
        adjustFaction('scrap', 2); // wave 7
        saveGame();
      }},
      { label: 'free him. (lockpick.)', action: () => freeScrapDog() },
      { label: 'leave.', action: () => {} },
    ]);
    return;
  }
  // first encounter
  dialogue('THE DOG', "the dog. brown. matted.\nchained to a post that looks bored.\nhe blinks at you twice.", [
    { label: P.inventory.find(i=>i.id==='food')
        ? 'feed him. (-1 food, +1 cred)'
        : 'feed him. (you have no food.)',
      disabled: !P.inventory.find(i=>i.id==='food'),
      action: () => {
        const i = P.inventory.findIndex(x=>x.id==='food'); if (i>=0) P.inventory.splice(i,1);
        P.cred += 1;
        q.state = 'fed'; q.done = true;
        toast("he ate it without looking up.\nhe looks at you once.\nthen back to the food.", 3200);
        feedPost("fed the scrap-yard dog.", '@crackheadcent');
        adjustFaction('scrap', 2); // wave 7
        saveGame();
      }
    },
    { label: 'free him. (lockpick.)', action: () => freeScrapDog() },
    { label: 'leave him.', action: () => {
      q.state = 'left'; q.done = true; q.available = false;
      toast("the dog blinks again. you walk away.\nhe is still there.\nhe is still there.", 2600);
      saveGame();
    }},
  ]);
}

export function freeScrapDog() {
  startLockpickMini(
    () => {
      const q = state.quests.scrap_dog; if (!q) return;
      const dog = runtime.npcs.find(n => n.id === 'scrap_dog');
      if (dog) { dog.dead = true; dog.chained = false; }
      q.state = 'freed'; q.done = true; q.available = false;
      state.freedDogT = 60000 + Math.random()*120000; // first reappear 1-3min later
      audio.glassBreak();
      unlockAchievement('liberator');
      toast("CLICK. the lock falls.\nthe dog stands up.\nhe walks past you. he does not look at you.\nhe is gone.", 4400);
      feedPost("freed the dog. the dog did not stay.", '@crackheadcent');
      applyRep({ scrap: 3, spiritual: -1 }); // wave 7 — freeing the dog (technically stealing)
      saveGame();
    },
    () => {
      toast("the lock holds.\nthe dog watches.\nhe is patient. you are not.", 2400);
    }
  );
}

export function spawnFreedDogFollower() {
  // already present?
  if (runtime.npcs.find(n => n.id === 'freed_dog_follower' && !n.dead)) return;
  const offsetX = (Math.random()-.5)*120;
  const offsetY = 80 + Math.random()*40;
  runtime.npcs.push({
    id: 'freed_dog_follower', name: 'THE DOG', sprite: 'scrap_dog',
    x: P.x + offsetX, y: P.y + offsetY, w: 26, h: 20, color: '#684830',
    hp: 40, maxHp: 40, speed: 1.4, hostile: false, archetype: 'passive',
    isPet: true, freedFollower: true, frame: 0,
    interact: (nn) => dialogue('THE DOG', "the dog.\nbrown. less matted.\nhe is here. for now.", [
      { label: 'pet him.', action: () => { P.cred += 1; toast("he accepts.\nhe leans into it.\nthe wandering resumes.", 2400); }},
      { label: 'leave.', action: () => {} },
    ]),
  });
  if (!state.freedDogFirstReturn) {
    state.freedDogFirstReturn = true;
    toast("the dog is back.\nhe is here.\nfor now.", 3200);
    feedPost("the dog came back today. just for a while.", '@crackheadcent');
  }
}

export function peteDialogue() {
  // v13 wave 4 — once player hits rank>=3, pete stocks the propane torch. one and done.
  if (P.rank >= 3 && state.flags && !state.flags.peteTorchStocked) {
    state.flags.peteTorchStocked = true;
  }
  const torchAvail = state.flags && state.flags.peteTorchStocked && !state.flags.peteTorchSold && !hasPropane();
  // v13 wave 7 — scrap-hated: pete refuses to buy. scrap-liked: +$2 on copper. scrap-loved: $50 loan 1×/day.
  const scrapTier = factionTier(P.faction ? P.faction.scrap : 0);
  if (scrapTier === 'hated') {
    dialogue('PAWN SHOP PETE', "pete looks up. pete looks back down.\n'pete is full.\npete does not need your things.'", [
      { label: 'leave.', action: () => {} }
    ]);
    return;
  }
  const peteCopper = (scrapTier === 'liked' || scrapTier === 'loved') ? 17 : 15;
  // v13 wave 6.5 — pete has a daily cash cap. $200/day across all sells to him.
  // sells become "pete is empty. pete is eating." once cap hit. resets at dawn.
  const PETE_CAP = 200;
  const peteCash = state.counters.peteCashToday || 0;
  const peteRoom = Math.max(0, PETE_CAP - peteCash);
  const peteEmpty = peteRoom <= 0;
  const tryPay = (amount) => {
    // returns actual amount pete pays out (clipped to his daily cash) and updates counter.
    const room = Math.max(0, PETE_CAP - (state.counters.peteCashToday||0));
    const pay = Math.min(amount, room);
    if (pay > 0) state.counters.peteCashToday = (state.counters.peteCashToday||0) + pay;
    return pay;
  };
  const peteEmptyLine = "pete is empty. pete is eating.\ncome back tomorrow.";
  const loanAvail = scrapTier === 'loved' && (state.flags.scrapLoanDay || 0) !== state.day;
  const opts = [
    peteEmpty
      ? { label: 'sell 1 PURE COPPER. (pete is empty.)', action: () => { toast(peteEmptyLine, 3000); }}
      : { label: `sell 1 PURE COPPER. $${peteCopper}.`, disabled: P.copper<1, action: () => {
          const pay = tryPay(peteCopper);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.copper--; P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast("pete weighs it for 11 minutes.\n- 1 pure copper\n+ $"+pay+(pay<peteCopper?"\npete is almost empty.":""), 2800);
          adjustFaction('scrap', 1); // wave 7 — pete copper sell = scrap +1
          audio.coin(); saveGame();
        }},
    peteEmpty
      ? { label: 'pawn a sock. (pete is empty.)', action: () => { toast(peteEmptyLine, 3000); }}
      : { label: 'pawn a sock. $1.', action: () => {
          const pay = tryPay(1);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast('+ $'+pay+'\n(it is wet.)'); audio.coin();
        }},
    peteEmpty
      ? { label: 'sell license plate. (pete is empty.)', disabled: !P.inventory.find(i=>i.id==='license'), action: () => { toast(peteEmptyLine, 3000); }}
      : { label: P.inventory.find(i=>i.id==='license') ? 'sell license plate. $20.' : 'ask about plates.', disabled: !P.inventory.find(i=>i.id==='license'), action: () => {
          const pay = tryPay(20);
          if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
          P.inventory = P.inventory.filter(i=>i.id!=='license');
          P.cash += pay; state.counters.peteSold = (state.counters.peteSold||0)+1;
          toast('+ $'+pay+(pay<20?"\npete is almost empty.":"\n(do not ask where it came from.)")); audio.coin();
          adjustFaction('scrap', 1); // wave 7 — pete buy = scrap +1
          saveGame();
        }},
    // v13 wave 6 — pete sells generic food ($3). a junk inventory item with one use (feed the dog).
    // (note: this is pete SELLING TO player, not buying. not gated by pete's daily cash cap.)
    { label: P.cash>=3 ? 'buy food. $3. (canned. unmarked.)' : "food is $3.",
      disabled: P.cash<3,
      action: () => {
        P.cash -= 3;
        P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});
        toast("- $3\n+ a can of food (unmarked).\npete keeps eating his hot pocket.", 2400);
        audio.coin();
        state.counters.peteSold = (state.counters.peteSold||0)+1;
        saveGame();
      }
    },
    // v13 wave 6 — pete buys junk (subject to daily cash cap)
    peteEmpty
      ? { label: 'sell junk. (pete is empty.)', disabled: !P.inventory.find(i=>i.id==='junk'), action: () => { toast(peteEmptyLine, 3000); }}
      : { label: P.inventory.find(i=>i.id==='junk') ? 'sell junk. $1 each.' : 'ask about junk.',
          disabled: !P.inventory.find(i=>i.id==='junk'),
          action: () => {
            const junks = P.inventory.filter(i=>i.id==='junk');
            const want = junks.length * 1;
            const pay = tryPay(want);
            if (pay <= 0) { toast(peteEmptyLine, 3000); return; }
            // only consume the junks pete actually paid for (1:1)
            const taken = Math.min(junks.length, pay);
            let removed = 0;
            P.inventory = P.inventory.filter(i => { if (i.id==='junk' && removed<taken) { removed++; return false; } return true; });
            P.cash += pay;
            state.counters.peteSold = (state.counters.peteSold||0)+1;
            toast("- "+taken+" junk\n+ $"+pay+(pay<want?"\npete is almost empty.":"\npete weighs each piece. it takes a while."), 2800);
            audio.coin(); saveGame();
          }
        },
  ];
  if (torchAvail) {
    opts.push({
      label: P.cash >= 80 ? "buy the propane torch. $80." : "the propane torch is $80. you don't have it.",
      disabled: P.cash < 80,
      action: () => {
        P.cash -= 80;
        P.equip.tool = 'propane_torch';
        applyEquipStats();
        state.flags.peteTorchSold = true;
        audio.coin();
        toast("- $80\n+ a propane torch (dented)\npete does not explain where he got it.\n(equipped.)", 4200);
        feedPost("bought a torch off pete. pete is eating.", '@crackheadcent');
        saveGame();
      }
    });
  } else if (P.rank >= 3 && state.flags && state.flags.peteTorchSold) {
    opts.push({ label: "ask about the torch again.", action: () => {
      toast("'sold the one.\ngo find your own.'\npete is still eating.", 2400);
    }});
  }
  // v13 wave 7 — scrap loved: pete will lend $50, once per day.
  if (loanAvail) {
    opts.push({ label: "ask pete for $50. (he likes you.)", action: () => {
      P.cash += 50; state.flags.scrapLoanDay = state.day;
      P.cred = Math.max(0, P.cred - 1); // implicit cred friction over time
      toast("pete looks at you for 11 minutes.\nthen counts out fifty.\n+ $50\n'pete remembers.'", 3800);
      feedPost("pete handed someone fifty. pete does not hand out money.", '@blocklog');
      saveGame();
    }});
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('PAWN SHOP PETE', "one second. eating.\npete is eating a hot pocket. behind glass.", opts);
}

export function lurchDialogue(n) {
  // v13 wave 6.5 — the dollar exchange is daily-capped (was an infinite cred trickle).
  const gaveToday = (state.counters.lurchDollarDay||0) === state.day;
  dialogue('LURCH', "you got a dollar.\nhe smells like ham.", [
    gaveToday
      ? { label: 'give a dollar. (he has forgotten you specifically.)', action: () => {
          toast("lurch is full. of dollars.\nhe is staring at the wall.\ncome back tomorrow.", 3000);
        }}
      : { label: P.cash>=1 ? 'give a dollar. (+2 cred)' : "you don't have a dollar.", disabled: P.cash<1, action: () => {
          P.cash--; P.cred += 2; state.counters.lurchDollarDay = state.day;
          toast('- $1\n+ 2 cred\nlurch immediately forgets.\ncome back tomorrow.'); saveGame();
        }},
    { label: 'lie. say you have a dollar.', action: () => {
      toast("lurch nods. waits. lurch is still waiting.\n(the lie did not work. he is just waiting.)");
    }},
    { label: 'fight.', action: () => { aggroNpc(n); toast('lurch swings. so do you. it begins.'); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function sherriDialogue(n) {
  // v13 wave 6.5 — spider cred grant is daily-capped.
  const sawToday = (state.counters.sherriSpiderDay||0) === state.day;
  dialogue('SPIDER-BITE SHERRI', "you seen the spider.\nshe is rolling her sleeve back down.", [
    sawToday
      ? { label: 'pretend to see the spider. (she has shown you today.)', action: () => {
          toast("sherri's sleeve is already down.\nthe spider is sleeping.\ncome back tomorrow.", 3000);
        }}
      : { label: 'pretend to see the spider.', action: () => {
          P.cred += 1; state.counters.sherriSpiderDay = state.day;
          toast('sherri respects you. (+1 cred)\ncome back tomorrow.'); saveGame();
        }},
    { label: 'tell her there is no spider.', action: () => {
      aggroNpc(n); toast("the spider is back.\nshe is hostile now.");
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function paulieDialogue(n) {
  // v13 wave 6.5 — the face compliment is daily-capped (was an infinite cred trickle).
  const flatteredToday = (state.counters.paulieFaceDay||0) === state.day;
  dialogue('PAULIE THE FACE', "the face.\nit is. it really is. just the face.", [
    flatteredToday
      ? { label: 'compliment the face. (the face has heard.)', action: () => {
          toast("paulie nods. the face is satisfied.\nthe face has been complimented today.\ncome back tomorrow.", 3000);
        }}
      : { label: 'compliment the face. (+1 cred)', action: () => {
          P.cred++; state.counters.pauliCompliments++;
          state.counters.paulieFaceDay = state.day;
          if (state.counters.pauliCompliments >= 5) unlockAchievement('compliment_the_face');
          toast("paulie does not smile but the face changes.\n+ 1 cred\ncome back tomorrow.");
          saveGame();
        }},
    { label: 'fight.', action: () => { aggroNpc(n); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function daveDialogue(n) {
  // v13 wave 3 — barb's crossword quest: dave has it. demand it back.
  const q = state.quests.barb_crossword;
  const daveHasIt = q && q.available && !q.done && state.flags.daveHasCrossword && !state.flags.hasCrossword;
  const crosswordOption = daveHasIt ? [{
    label: "demand the saturday crossword.",
    action: () => {
      if (P.cred >= 3) {
        state.flags.daveHasCrossword = false;
        state.flags.hasCrossword = true;
        P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
        toast("dave does the math.\nhe hands you a folded newspaper.\n'i thought she wouldn't notice.\nshe did.'\n+ saturday crossword", 4200);
        saveGame();
      } else {
        dialogue('CHATTY DAVE', "dave looks at you up and down.\n'$20 or fight.\nor walk. that is a third thing.'", [
          { label: P.cash>=20 ? "pay $20 ransom." : "you don't have $20.", disabled: P.cash<20, action: () => {
            P.cash -= 20;
            state.flags.daveHasCrossword = false;
            state.flags.hasCrossword = true;
            P.inventory.push({id:'crossword', n:"barb's saturday crossword", q:1});
            toast("- $20\n+ saturday crossword\nhe pockets your cash.\nhe is whistling.");
            saveGame();
          }},
          { label: "fight him.", action: () => {
            n.asleep = false; aggroNpc(n);
            toast("dave is hostile now.\nhe still has the crossword.\nbeat him until it falls out.");
          }},
          { label: "leave.", action: () => {} },
        ]);
      }
    }
  }] : [];

  if (n.asleep) {
    dialogue('CHATTY DAVE', "dave is asleep. his wallet is half out.", [
      ...crosswordOption,
      { label: 'pickpocket. (+$8)', action: () => {
        if (Math.random()<0.7) {
          P.cash += 8; toast('+ $8\ndave keeps sleeping.'); audio.coin();
        } else {
          n.asleep = false; n.hostile = true; n.aggro = true; P.wanted = Math.min(3, P.wanted+1);
          toast('DAVE WAKES UP.\nyou sprint. he chases.');
        }
      }},
      { label: 'wake him up.', action: () => {
        n.asleep = false; toast("dave wakes up. he is talking immediately.");
      }},
      { label: 'leave.', action: () => {} },
    ]);
  } else {
    dialogue('CHATTY DAVE', "dave is explaining a theory about pigeons.\nthe theory has 17 parts.", [
      ...crosswordOption,
      { label: 'listen for a while. (-5 brain)', action: () => {
        P.brain = Math.max(0, P.brain-5); toast('- 5 brain\nyou know more about pigeons now.\nthis was not free.');
      }},
      { label: 'leave.', action: () => {} },
    ]);
  }
}

export function momDialogue() {
  const isDaylight = !isNight();
  if (!isDaylight) {
    dialogue('WHOLE FOODS MOM', "she is not here at night.\nshe is at the wine bar with kelly.", [{label:'leave.',action:()=>{}}]);
    return;
  }
  // v13 wave 6.5 — daily-cap the ask + compliment branches. each branch fires at most once per
  // dayCount. when consumed, the option is replaced with a refusal line so the player sees the gate.
  const askedToday = (state.counters.kombuchaAskDay||0) === state.day;
  const complimentedToday = (state.counters.kombuchaComplimentDay||0) === state.day;
  const opts = [];
  if (!askedToday) {
    opts.push({ label: 'accept $10 and pity. (+$10)', action: () => {
      P.cash += 10; state.counters.kombuchaAskDay = state.day;
      toast("+ $10\nshe will tell ben about you tonight.\nben will not care.\ncome back tomorrow."); audio.coin();
      adjustFaction('spiritual', -1); // wave 7 — asking mom for money disappoints her
      saveGame();
    }});
    opts.push({ label: 'ask for $20.', action: () => {
      state.counters.kombuchaAskDay = state.day;
      if (Math.random()<0.4) { P.cash += 20; toast('+ $20\nshe pauses. she sighs. she gives.\nben will be furious.\ncome back tomorrow.'); audio.coin(); }
      else { toast("she explains capitalism for 4 minutes.\nyou leave with no money and -2 brain.\ncome back tomorrow.");
        P.brain = Math.max(0, P.brain-2); }
      adjustFaction('spiritual', -1); // wave 7 — even asking, regardless of outcome
      saveGame();
    }});
  } else {
    opts.push({ label: 'ask her for money. (she remembers.)', action: () => {
      toast("you've been by. she remembers.\nshe remembers because she has nothing else to do.\ncome back tomorrow.", 3600);
    }});
  }
  if (!complimentedToday) {
    opts.push({ label: 'compliment her kombucha. (+5 cred)', action: () => {
      P.cred += 5; state.counters.kombuchaComplimentDay = state.day;
      toast("she lights up.\nshe tells you it's lavender.\nyou agree it is lavender.\n+ 5 cred\ncome back tomorrow.");
      adjustFaction('spiritual', 1); // wave 7 — compliment = spiritual +1
      saveGame();
    }});
  } else {
    opts.push({ label: 'compliment her kombucha again.', action: () => {
      toast("she has heard about her kombucha today.\nshe is tired of her kombucha.\nshe is tired of you.", 3600);
    }});
  }
  // v13 wave 7 — mom's apartment hideout gate (spiritual >= +10, one-time setup)
  const momHideoutGate = (P.faction && P.faction.spiritual >= 10) && !(state.flags && state.flags.momHideoutOwned);
  if (momHideoutGate) {
    opts.push({ label: P.cash>=30 ? "ask mom if you can stay over. ($30/night.)" : "ask mom if you can stay over. ($30 — short.)",
      disabled: P.cash<30,
      action: () => {
        P.cash -= 30; state.flags.momHideoutOwned = true; state.flags.momRentDay = state.day;
        toast("- $30\n'oh sweetie.\nthe couch is yours.\nben works late.'\n(the spare key is on the hook.)", 4200);
        feedPost("got a couch tonight. ben works late.", '@crackheadcent');
        adjustFaction('spiritual', 2);
        saveGame();
      }
    });
  }
  opts.push({ label: 'leave.', action: () => {} });
  dialogue('WHOLE FOODS MOM', "oh. oh sweetie.\nshe is wearing vibram five-fingers.\nshe is holding kombucha.", opts);
}

export async function possumDialogue() {
  dialogue('THE POSSUM', "a possum wearing a tiny construction helmet looks up.\nhe is calculating something.", [
    { label: 'request a prophecy.', action: async () => {
      toast('the possum is thinking. give him a second.', 1500);
      let line = LOCAL_POSSUM_PROPHECIES[Math.floor(Math.random()*LOCAL_POSSUM_PROPHECIES.length)];
      try {
        if (window.claude && window.claude.complete) {
          const t = await Promise.race([window.claude.complete({
            messages: [{
              role:'user',
              content: `You are the POSSUM in a satirical Adult Swim-style game (Aqua Teen Hunger Force tone). Output ONE flat absurd in-world event, 1-3 sentences, lowercase, present tense, no second person past "you", no quotes, no editorializing. The event must be specific and mundane-with-an-impossible-detail. Example tones: "a possum wearing a tiny construction helmet emerges from a drain. looks you dead in the eye. retreats." or "a dachshund in a blazer hands you a receipt. it is for a haircut you did not get." No real drugs, no real places, no slurs. Output ONLY the event text, nothing else.`
            }]
          }),new Promise(resolve=>setTimeout(()=>resolve(null),1800))]);
          if (t && typeof t === 'string') line = t.trim().toLowerCase().replace(/^["']|["']$/g,'');
        }
      } catch(e) {}
      toast(line, 5500);
      state.counters.possumProphecies++;
      if (state.counters.possumProphecies >= 10) unlockAchievement('i_have_seen_horrors');
      if (state.counters.possumProphecies >= 5 && !P.hasPossum) {
        setTimeout(spawnPetPossum, 2200);
      }
      // small effect
      const eff = Math.floor(Math.random()*4);
      if (eff===0) { P.cash += 2; toast(line + '\n+ $2', 5500); }
      else if (eff===1) { P.brain = Math.max(0, P.brain-3); }
      else if (eff===2) { P.cred++; }
    }},
    { label: 'pet the possum.', action: () => { toast("you do not pet the possum.\nthe possum decides this."); unlockAchievement('the_route'); }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function priestDialogue() {
  // v13 wave 5 — track visit + plate-steal counts so the fallen priest can trigger.
  state.counters.priestVisits = (state.counters.priestVisits||0) + 1;
  // already-fallen branch: if he transformed (anywhere), opening his dialogue does nothing —
  // the entity is no longer the priest. defensive: should never fire (priest_fallen has no interact).
  if (state.flags && state.flags.omalleyFallen && !state.flags.omalleyFallenDead) {
    dialogue("FATHER O'MALLEY",
      "the collar is on the floor.\nthe smile is wrong.\nthe medicine is no longer offered.",
      [{ label: 'leave.', action: () => {} }]);
    return;
  }
  // v13 wave 6.5 — donation cred is daily-capped (was an infinite cred grind via mom/sock farming).
  const donatedToday = (state.counters.priestDonateDay||0) === state.day;
  dialogue("FATHER O'MALLEY", "medicine. open your mouth.\nhe is holding a tic-tac.", [
    // v13 wave 6.5 — tic-tac is a TASTE, not a withdrawal substitute. removed shakes reduction;
    // gives a small +5 brain (sober person buff) and acknowledges that the shakes do not care.
    // the canonical line: the shakes do not care.
    { label: 'accept the blessed tic-tac. (+5 brain)', action: () => {
      P.brain = Math.min(100, P.brain+5);
      toast('the tic tac is gone.\nthe shakes do not care.');
      if (!state.quests.priest_mercy.done) { state.quests.priest_mercy.done = true; questToast("THE PRIEST'S MERCY"); }
      saveGame();
    }},
    donatedToday
      ? { label: "donate $5. (the lord heard already.)", action: () => {
          toast("father o'malley nods.\n'the lord has counted today.\ncome back tomorrow.'", 3000);
        }}
      : { label: P.cash>=5 ? 'donate $5. (+3 cred)' : 'donate $5.', disabled: P.cash<5, action: () => {
          P.cash-=5; P.cred+=3; state.counters.churchDonations += 5;
          state.counters.priestDonateDay = state.day;
          if (state.counters.churchDonations >= 100) unlockAchievement('ecclesiastes');
          toast('- $5\n+ 3 cred\nthe lord notices. then forgets.\ncome back tomorrow.');
          adjustFaction('spiritual', 2); // wave 7 — donate = spiritual +2
          saveGame();
        }},
    { label: 'steal the collection plate.', action: () => {
      state.counters.plateStealAttempts = (state.counters.plateStealAttempts||0) + 1;
      // v13 wave 5 — after 4+ priest visits AND a steal attempt, the priest stops being the priest.
      // v13 wave 7 — spiritual >= +10 (LOVED) overrides the fall trigger; the priest holds.
      const spiritualGate = (P.faction && P.faction.spiritual >= 10);
      if ((state.counters.priestVisits||0) >= 4
          && (state.counters.plateStealAttempts||0) >= 1
          && state.flags && !state.flags.omalleyFallen && !spiritualGate) {
        triggerFallenPriestTransform();
        // counts as a steal attempt for the faction ledger
        applyRep({ street: 1, spiritual: -3 });
        return;
      }
      if (Math.random()<0.55) {
        P.cash += 22; state.counters.plateStolen++;
        if (state.counters.plateStolen >= 1 && state.counters.stripeBetrayed >= 1) unlockAchievement('judas');
        toast('+ $22\n(the lord is busy.)'); audio.pickup();
      } else {
        P.hp -= 12; P.wanted = Math.min(3, P.wanted+1); toast("father o'malley smites you.\n- 12 hp · wanted +1"); audio.hurt();
      }
      applyRep({ street: 1, spiritual: -3 }); // wave 7 — every steal attempt counts
      saveGame();
    }},
    { label: 'leave.', action: () => {} },
  ]);
}

export function init_dialogue_a() {
  // ---------- DIALOGUES ----------
  
  
  
  
  // v13 wave 6 — the chained scrap-yard dog. 3 outcome branches.
  // Feed: -1 food, +1 cred, state='fed', stays chained but creates 200px cop-discomfort radius.
  // Free: triggers lockpick mini. Success: dog disappears, state='freed', LIBERATOR unlocked,
  //       dog can RANDOMLY reappear in any zone as a follower for ~60s.
  // Leave: state='left' (no penalty).
  // Attack-while-chained (player swing connects): becomes hostile, state='left',
  //   THE_PIECE_OF_SHIT + -5 cred (handled at the playerAttack site).
  
  
  
  
  // v13 wave 6 — spawn the wandering freed-dog follower in a random zone close to the player.
  // follows for ~60s, then wanders off the screen.
  
  
  
  
  
  
  
  
  
  
  LOCAL_POSSUM_PROPHECIES = [
    "a parking meter prints a receipt for one cloud. the cloud contests the charge.",
    "a dachshund in a blazer measures the curb. the curb is two inches behind schedule.",
    "three pigeons open a checking account. the fourth pigeon is the branch manager.",
    "the laundromat loses power. one dryer continues on professional courtesy.",
    "a shopping cart returns from the east with a library card. the card is overdue.",
    "the bus shelter files for custody of the bench. the bench does not attend the hearing.",
    "a wet sock is elected treasurer. nobody asks what happened to the previous treasurer.",
    "the storm drain requests exact change. it accepts a button after a short meeting.",
    "a traffic cone receives a promotion. it remains in the same position with more authority.",
    "the pawn shop scale weighs itself. pete writes down twelve pounds and refuses an appeal.",
    "a motel key checks into the motel. the office is closed but the key knows somebody.",
    "the train signal turns green for one second. nothing takes advantage of it.",
    "a folding chair crosses the road under escort. the escort is another folding chair.",
    "the fountain coughs up a nickel. the park forms a committee around the nickel.",
    "a receipt blows past with your name misspelled. the amount is correct.",
    "the possum has reviewed your file. there is no file. this is considered worse.",
  ];
  
  
  
  
  // v13 wave 5 — fallen priest transform. flips the existing priest NPC in-place: same entity,
  // new id ('omalley_fallen'), hostile + aggro, archetype 'priest_fallen', HP doubled.
  // canonical line: "father o'malley does not stand up. he is already standing.\nthe collar comes off.\nthe smile is wrong."
  
}
