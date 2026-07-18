/* Generated from frozen rock_bottom_v19.html.
 * Source seams: helpers, NPC setup, and cash piles.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio } from '../core/audio_save.js';
import { P, dialogue, runtime, state, toast } from '../core/runtime_ui.js';
import { ZONES } from './world.js';
import { daveDialogue, lurchDialogue, momDialogue, paulieDialogue, peteDialogue, possumDialogue, priestDialogue, scrapDogDialogue, sherriDialogue, tonyDialogue, yuriDialogue } from '../dialogue/neighborhood_a.js';
import { bigguDialogue, conductorDialogue, larryDialogue, pigeonDialogue, stripeDialogue } from '../dialogue/neighborhood_b.js';
import { barbDialogue, hopperDialogue, mathematicianDialogue, philosopherDialogue, pinkyDialogue } from '../dialogue/vendors_places.js';
import { startRhythmMini } from '../minigames/activities.js';
import { gutterGregDialogue, leaseGuyDialogue } from '../systems/campaigns.js';
import { feedPost, phoneState, renderPhone } from '../systems/communications.js';
import { recordRecognition } from '../systems/recognition.js';

export function rectsOverlap(a,b){ return a.x < b.x+b.w && a.x+a.w > b.x && a.y < b.y+b.h && a.y+a.h > b.y; }

export function dist2(a,b){ const dx=a.x-b.x, dy=a.y-b.y; return dx*dx+dy*dy; }

export function clamp(v,lo,hi){ return Math.max(lo, Math.min(hi, v)); }

export function inZone(x,y,id) {
  const z = ZONES.find(z=>z.id===id);
  if (!z) return false;
  return x>=z.x && x<=z.x+z.w && y>=z.y && y<=z.y+z.h;
}

export function currentZone() {
  const cx = P.x + P.w/2, cy = P.y + P.h/2;
  let best = null, bestRank = -1;
  for (const z of ZONES) {
    if (cx<z.x || cx>z.x+z.w || cy<z.y || cy>z.y+z.h) continue;
    const f = z.faction || 'neutral';
    const tierAbs = (f === 'neutral') ? 0 : Math.abs((P.faction && P.faction[f]) || 0);
    if (tierAbs > bestRank) { bestRank = tierAbs; best = z; }
  }
  return best;
}

export function currentZoneFaction() {
  const z = currentZone();
  return z ? (z.faction || 'neutral') : 'neutral';
}

export function isNight() { return state.dayTime < 0.25 || state.dayTime > 0.75; }

export function spawnNpcs() {
  runtime.npcs = [
    { id:'tony', name:'TRE BAG TONY', sprite:'tony', x:1620, y:870, w:28,h:32, color:'#3a1810', legacyStructureIndex:1,
      hp:120, maxHp:120, speed:0, hostile:false, vendor:true,
      interact: tonyDialogue },
    { id:'yuri', name:'YURI', sprite:'yuri', x:300, y:200, w:28,h:32, color:'#4a2818',
      hp:60, maxHp:60, speed:0, hostile:false, vendor:true,
      interact: yuriDialogue },
    { id:'brutus', name:'BRUTUS', sprite:'brutus', x:480, y:280, w:32,h:24, color:'#604020',
      hp:50, maxHp:50, speed:1.4, hostile:false, dmg:7, zoneOnly:{x:100,y:80,w:520,h:360},
      archetype:'charger',
      interact: null },
    // v13 wave 6 — the chained scrap-yard dog. archetype 'passive' (does not aggro by default).
    // chained to leash_post at (570,130). interact handled by scrapDogDialogue.
    // becomes hostile only if attacked while chained.
    { id:'scrap_dog', name:'THE DOG', sprite:'scrap_dog', x:580, y:150, w:26, h:20, color:'#684830',
      hp:40, maxHp:40, speed:0, hostile:false, archetype:'passive', chained: true, tailWag:0,
      interact: scrapDogDialogue },
    { id:'pete', name:'PAWN SHOP PETE', sprite:'pete', x:250, y:700, w:28,h:32, color:'#4a4028', legacyStructureIndex:0,
      hp:80, maxHp:80, speed:0, hostile:false, vendor:true,
      interact: peteDialogue },
    { id:'lurch', name:'LURCH', sprite:'lurch', x:200, y:1400, w:28,h:34, color:'#3a2030',
      hp:55, maxHp:55, speed:1.4, hostile:false, aggroOnHit:true, dmg:6, wander:true,
      archetype:'grabber',
      interact: lurchDialogue },
    { id:'sherri', name:'SPIDER-BITE SHERRI', sprite:'sherri', x:350, y:1480, w:26,h:30, color:'#3a1820',
      hp:45, maxHp:45, speed:2.0, hostile:false, aggroOnHit:true, dmg:5, wander:true,
      archetype:'swarmer',
      interact: sherriDialogue },
    { id:'paulie', name:'PAULIE THE FACE', sprite:'paulie', x:450, y:1560, w:28,h:32, color:'#5a3030',
      hp:60, maxHp:60, speed:1.5, hostile:false, aggroOnHit:true, dmg:7, wander:true,
      archetype:'ranged',
      interact: paulieDialogue },
    { id:'dave', name:'CHATTY DAVE', sprite:'dave', x:900, y:1480, w:28,h:32, color:'#3a2818',
      hp:40, maxHp:40, speed:0, hostile:false, asleep:true,
      interact: daveDialogue },
    { id:'mom', name:'WHOLE FOODS MOM', sprite:'mom', x:1200, y:1480, w:28,h:32, color:'#80a050',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: momDialogue },
    { id:'possum', name:'THE POSSUM', sprite:'possum', x:600, y:1500, w:28,h:24, color:'#604030',
      hp:20, maxHp:20, speed:0, hostile:false,
      interact: possumDialogue },
    { id:'priest', name:"FATHER O'MALLEY", sprite:'priest', x:1800, y:1460, w:28,h:32, color:'#2a2030', legacyStructureIndex:3,
      hp:80, maxHp:80, speed:0, hostile:false,
      interact: priestDialogue },
    // v13 wave 8a — Conductor moved from THE PROJECTS to the TRAIN YARD. his real home turf.
    // dialogue + the 3-copper-for-$90 trade unchanged.
    { id:'conductor', name:'THE CONDUCTOR', sprite:'conductor', x:680, y:2960, w:28,h:32, color:'#604030',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: conductorDialogue },
    { id:'larry', name:'LOUD LARRY', sprite:'larry', x:440, y:1780, w:28,h:32, color:'#8a3030',
      hp:80, maxHp:80, speed:1.3, hostile:false, aggroOnHit:true, dmg:10,
      interact: larryDialogue },
    { id:'stripe', name:'STRIPE', sprite:'stripe', x:620, y:1780, w:28,h:32, color:'#3a3848',
      hp:70, maxHp:70, speed:0, hostile:false, vendor:true,
      interact: stripeDialogue },
    // v13 wave 8a — Pigeon King moved to THE PARK, near the central fountain. wanders inside the park.
    // dialogue / secrets / crown quest unchanged. faction-rep is still neutral on interaction.
    { id:'pigeon', name:'THE PIGEON KING', sprite:'pigeon', x:2700, y:1180, w:24,h:20, color:'#605840',
      hp:10, maxHp:10, speed:0.8, hostile:false, wander:true,
      interact: pigeonDialogue },
    { id:'biggu', name:'THE BIG GUY', sprite:'biggu', x:1200, y:340, w:32,h:38, color:'#604030',
      hp:120, maxHp:120, speed:0, hostile:false,
      interact: bigguDialogue },
    // ambient walking NPCs
    { id:'cubscout', name:'CUBSCOUT', sprite:'cubscout', x:780, y:1500, w:22,h:26, color:'#604020',
      hp:30, maxHp:30, speed:1.2, hostile:false,
      daytimeOnly:true,
      patrol:[{x:760,y:1450},{x:1200,y:1450},{x:1200,y:1580},{x:760,y:1580}],
      interact: (n)=> dialogue('CUBSCOUT', "popcorn?\n$8 a tin.\nhis mom is in the car.", [
        { label: P.cash>=8?'buy popcorn. $8.':"you don't have $8.", disabled: P.cash<8, action: ()=>{
          P.cash -= 8; P.cred += 4;
          toast('- $8\n+ 4 cred\nyou ate a fistful in the parking lot.'); audio.coin();
        }},
        { label: 'ask if his mom knows about this.', action: () => toast("she is on her phone.\nshe has been on her phone for 11 minutes.") },
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'jogger', name:'JOGGER', sprite:'jogger', x:1200, y:600, w:22,h:26, color:'#4a5028',
      hp:40, maxHp:40, speed:2.4, hostile:false,
      patrol:[{x:760,y:600},{x:1500,y:600},{x:1500,y:1100},{x:760,y:1100}],
      interact: (n)=> dialogue('JOGGER', "heart rate 142.\nshe does not stop. she is talking through it.", [
        { label: 'ask for $1.', action: ()=>{
          if (Math.random()<.4) { P.cash++; toast('+ $1\nshe gave you a dollar she did not need.'); }
          else { toast('she ran faster.\nthe ground absorbed your dignity.'); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'dogwalker', name:'DOG WALKER (PAISLEY)', sprite:'dogwalker', x:980, y:1200, w:22,h:26, color:'#604030',
      hp:40, maxHp:40, speed:0.9, hostile:false,
      patrol:[{x:900,y:1180},{x:1400,y:1180},{x:1400,y:1320},{x:900,y:1320}],
      interact: (n)=> dialogue('DOG WALKER', "paisley. no. paisley LEAVE IT.\npaisley is a small dog made of fur.", [
        { label: 'pet paisley.', action: ()=>{
          P.cred++; toast('+ 1 cred\npaisley accepts you. tolerantly.');
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'busker', name:'BUSKER', sprite:'busker', x:1100, y:1500, w:24,h:28, color:'#604020',
      hp:50, maxHp:50, speed:0, hostile:false,
      interact: (n)=> dialogue('BUSKER', "he is playing a song he wrote.\nit has no chorus.\nhe has a guitar case open at his feet.", [
        { label: P.cash>=1?'tip $1.':"you don't have $1.", disabled: P.cash<1, action: ()=>{
          P.cash--; P.cred++; toast('- $1\n+ 1 cred\nhe nods without losing the beat.');
        }},
        { label: 'request a different song.', action: ()=> toast("he plays the same song faster.\nthis is the new song now.") },
        { label: 'leave.', action:()=>{} },
      ]) },
    // — new NPCs in v6 —
    { id:'horsecop', name:'HORSE COP', sprite:'horsecop', x:1320, y:1080, w:36,h:32, color:'#1818a0',
      hp:120, maxHp:120, speed:0, hostile:false,
      patrol:[{x:1200,y:1080},{x:1500,y:1080},{x:1500,y:1240},{x:1200,y:1240}],
      interact: (n)=> dialogue('HORSE COP', "a cop on horseback nods at you.\nthe horse also nods.\ndisturbing levels of agreement.", [
        { label: 'nod back.', action: ()=>{
          P.cred += 2; toast("you nod. the horse nods.\nthe cop nods. you are all nodding.\n+ 2 cred");
        }},
        { label: 'compliment the horse.', action: ()=>{
          P.cred += 3; toast("the horse looks pleased.\nthe cop is jealous.\n+ 3 cred");
          feedPost("complimented the horse cop's horse. the horse was visibly pleased.", '@local_eyewitness');
        }},
        { label: 'try to pet the horse.', action: ()=>{
          if (Math.random()<.4) { P.cred += 4; toast("the horse permits it.\nthe cop says nothing.\n+ 4 cred"); }
          else { P.hp -= 6; P.wanted = Math.min(3, P.wanted+1); toast("the horse rears.\nyou eat curb.\n- 6 hp · wanted +1"); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'vapelord', name:'THE VAPE LORD', sprite:'vapelord', x:840, y:1100, w:28,h:32, color:'#3a1850',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('THE VAPE LORD', "he is exhaling watermelon mist.\nhe trades in juice.\nhe has a small dragon on his back.\nthe dragon is also vaping.", [
        { label: P.cash>=6?'buy a pod. $6. (+10 brain)':"you don't have $6.", disabled: P.cash<6, action: ()=>{
          P.cash -= 6; P.brain = Math.min(100, P.brain+10);
          toast('- $6\n+ 10 brain\nthe flavor is "spectrum".\nyou cannot taste it. that is the flavor.');
        }},
        { label: 'ask for a free hit.', action: ()=>{
          toast("the vape lord says nothing.\nthe dragon stares.\nyou leave.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'pothole', name:'A POTHOLE (TALKING)', sprite:'pothole', x:980, y:920, w:32,h:18, color:'#0a0805',
      hp:9999, maxHp:9999, speed:0, hostile:false,
      interact: (n)=> dialogue('A POTHOLE', "the pothole says your full legal name.\nyou did not give it your full legal name.", [
        { label: 'argue with the pothole.', action: ()=>{
          P.brain = Math.max(0, P.brain-4);
          toast("- 4 brain\nthe pothole has more facts than you do.\nthe pothole is also correct.");
        }},
        { label: 'throw something in it.', action: ()=>{
          if (P.cash>=1) { P.cash--; P.cred++; toast("- $1\n+ 1 cred\nthe pothole accepts.\nthe pothole says 'thank you' in your mother's voice."); }
          else toast("you have nothing to throw.\nthe pothole understands. the pothole is patient.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'mayorscousin', name:"MAYOR'S COUSIN", sprite:'mayorscousin', x:1340, y:1500, w:28,h:32, color:'#604020',
      hp:50, maxHp:50, speed:0, hostile:false,
      interact: (n)=> dialogue("THE MAYOR'S COUSIN", "he knows the mayor.\nhe is wearing a suit jacket.\nhe is not wearing pants.", [
        { label: 'ask about the mayor.', action: ()=>{
          toast("the mayor is, in fact, his cousin.\nthe mayor does not return his calls.\nthis information is true and useless.");
        }},
        { label: 'ask for a favor.', action: ()=>{
          if (Math.random()<.3) { P.wanted = Math.max(0, P.wanted-1); toast("a phone call is made.\nthe heat dies down.\n- 1 wanted"); }
          else toast("he makes a phone call.\nthe phone is a piece of bread.");
        }},
        { label: P.cash>=5?'bribe him. $5.':"you don't have $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; P.cred += 8;
          toast("- $5\n+ 8 cred\nhe whispers 'i'll remember this.'\nhe will not.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'phoneguy', name:'THE PHONE GUY', sprite:'phoneguy', x:1180, y:1480, w:24,h:28, color:'#3a2818',
      hp:30, maxHp:30, speed:0, hostile:false,
      interact: (n)=> {
        if (!phoneState.visible) { phoneState.visible = true; renderPhone(); }
        dialogue('THE PHONE GUY', "he is on his phone.\nhe has been on his phone.\nhe sees you. he tweets about you.", [
          { label: 'ask what he\'s posting.', action: ()=>{
            const posts = [
              "tagged a man at the corner. he didn't notice.",
              "live-posting a possum. 4 likes.",
              "the conductor is trending in zone 2.",
              "father o'malley followed me back.",
              "pawn pete weighed a sock again. 11 min. 2 hearts.",
            ];
            feedPost(posts[Math.floor(Math.random()*posts.length)], '@phone_guy');
            toast("he flips the phone toward you. you see it.\nyou are in the post.\n(press P or tap FEED)");
          }},
          { label: P.cash>=3?'give him content. $3. (+post)':"you don't have $3.", disabled: P.cash<3, action: ()=>{
            P.cash -= 3;
            feedPost("a man paid me $3 to make him famous. he is. for like 30 seconds.", '@phone_guy');
            toast("- $3\nhe posts about you.\nthe post does numbers.\nthe numbers are 3.");
          }},
          { label: 'leave.', action:()=>{} },
        ]);
      } },
    // --- v8 new NPCs ---
    // --- v12 new vendor: the supply ---
    { id:'barb', name:'BAGGIE BARB', sprite:'barb', x:1540, y:1190, w:28,h:32, color:'#8a6080', legacyStructureIndex:4,
      hp:80, maxHp:80, speed:0, hostile:false, vendor:true,
      interact: barbDialogue },
    // v13 wave 2 — rival supply at the bus stop
    { id:'pinky', name:'PINKY POLENTA', sprite:'pinky', x:1330, y:1160, w:26,h:32, color:'#c8b070',
      hp:70, maxHp:70, speed:0, hostile:false, vendor:true,
      interact: pinkyDialogue },
    // v13 wave 2 — the mathematician, under the highway underpass
    { id:'math', name:'THE MATHEMATICIAN', sprite:'math', x:1340, y:380, w:26,h:32, color:'#6a5a4a',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: mathematicianDialogue },
    // v13 wave 8a — THE TRAIN HOPPER, sleeping under the navy freight car in the train yard.
    // lore-only NPC: no resources granted. tells stories about other towns. hidden at night (sleeping inside the car).
    // daytimeOnly reuses the existing render filter (mom/pete pattern) — at night he's "inside the car".
    { id:'train_hopper', name:'THE TRAIN HOPPER', sprite:'train_hopper', x:820, y:2940, w:26,h:32, color:'#5a4030',
      hp:50, maxHp:50, speed:0, hostile:false, daytimeOnly:true,
      interact: hopperDialogue },
    // v13 wave 8a — THE PARK BENCH PHILOSOPHER, feeding pigeons near the fountain.
    // daily question cycle (5-7 questions). +1 spiritual once/day for engaging.
    { id:'philosopher', name:'PARK BENCH PHILOSOPHER', sprite:'philosopher', x:2680, y:1080, w:26,h:32, color:'#604838',
      hp:55, maxHp:55, speed:0, hostile:false,
      interact: philosopherDialogue },
    // v18 far-east clerical fixtures. Essential prevents the only office-sale hook and the
    // canal activity from being killed or punched away from their authored coordinates.
    { id:'lease_guy', name:'THE LEASING GUY', sprite:'lease_guy', x:5400, y:3100, w:28,h:32, color:'#6a5840',
      hp:80, maxHp:80, speed:0, hostile:false, essential:true,
      interact: leaseGuyDialogue },
    { id:'gutter_greg', name:'GUTTER GREG', sprite:'gutter_greg', x:4500, y:2050, w:26,h:32, color:'#496050',
      hp:80, maxHp:80, speed:0, hostile:false, essential:true,
      interact: gutterGregDialogue },
    { id:'laundromat_lady', name:'LAUNDROMAT LADY', sprite:'launderlady', x:1720, y:1180, w:28,h:32, color:'#3a3a44', legacyStructureIndex:4,
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('LAUNDROMAT LADY', "she is folding the same shirt.\nshe has been folding the same shirt.\nthe shirt is hers, you think.", [
        { label: P.cash>=2?'do a load of laundry. $2. (regen +12 hp)':"need $2.", disabled: P.cash<2, action: ()=>{
          P.cash -= 2; P.hp = Math.min(P.maxHp, P.hp + 12);
          state.counters.laundryDone = (state.counters.laundryDone||0) + 1;
          recordRecognition('laundromat','buy','laundry_service');
          toast("- $2\n+ 12 hp\nyou wore wet clothes back outside.\nit smells like a different country in here.");
        }},
        { label: P.cash>=5?"buy detergent. $5. (item)":"detergent is $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; P.inventory.push({id:'detergent', n:'a jug of detergent', q:1});
          recordRecognition('laundromat','buy','detergent');
          toast("- $5\n+ detergent\nyou are not going to use it. you know this. she knows this.");
        }},
        { label: 'ask why she is here.', action: ()=>{
          toast("she does not answer. she folds.\nthe shirt has not been clean since 2009.\n(- 2 brain)");
          P.brain = Math.max(0, P.brain - 2);
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'meter_maid', name:'METER MAID', sprite:'metermaid', x:1380, y:920, w:26,h:30, color:'#a8c030',
      hp:55, maxHp:55, speed:1.6, hostile:false, aggroOnHit:true, dmg:8,
      patrol:[{x:1280,y:920},{x:1440,y:920},{x:1440,y:1020},{x:1280,y:1020}],
      interact: (n)=> dialogue('METER MAID', "she is writing a ticket.\nfor what.\nfor existing in a designated zone.", [
        { label: P.cash>=2?'pay the meter. $2. (-1 wanted)':'meters cost $2.', disabled: P.cash<2, action: ()=>{
          P.cash -= 2; P.wanted = Math.max(0, P.wanted - 1);
          toast("- $2\n- 1 wanted\nthe meter accepts. begrudgingly.");
        }},
        { label: 'try to flirt.', action: ()=>{
          toast("she looks you up and down.\nshe writes another ticket.\nthe ticket is for you. it says 'INSUFFICIENT.'");
          P.wanted = Math.min(3, P.wanted + 1);
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'food_truck', name:'FOOD TRUCK GUY', sprite:'foodtruck', x:920, y:1500, w:30,h:32, color:'#d06030',
      hp:60, maxHp:60, speed:0, hostile:false,
      interact: (n)=> dialogue('FOOD TRUCK GUY', "the truck says 'TACOS' in 4 fonts.\nthe truck has not moved since wednesday.\nit is wednesday.", [
        { label: P.cash>=4?'buy a mystery taco. $4. (+20 hp · ?)':"$4 minimum for hp.", disabled: P.cash<4, action: ()=>{
          P.cash -= 4;
          P.hp = Math.min(P.maxHp, P.hp + 20);
          state.counters.tacosEaten = (state.counters.tacosEaten||0) + 1;
          const r = Math.random();
          if (r < 0.15) { P.shakes = Math.max(0, P.shakes - 20); toast("- $4 · + 20 hp · - 20 shakes\nthe taco had something in it.\nyou should not ask."); }
          else if (r < 0.25) { P.hp -= 30; toast("- $4 · + 20 hp · - 30 hp\nthe taco had something in it.\nyou ARE asking now."); audio.hurt(); }
          else toast("- $4 · + 20 hp\nthe taco was a taco. you are stunned.");
        }},
        { label: P.cash>=8?'buy a horchata. $8. (+30 brain)':"horchata is $8.", disabled: P.cash<8, action: ()=>{
          P.cash -= 8; P.brain = Math.min(100, P.brain + 30);
          toast("- $8 · + 30 brain\nit tastes like a memory you don't have.");
        }},
        { label: P.cash>=15 && P.rocks<3?"buy a 'special' burrito. $15. (+1 rock somehow)":"specials are $15.", disabled: P.cash<15, action: ()=>{
          P.cash -= 15; P.rocks++; P.wanted = Math.min(3, P.wanted+1);
          toast("- $15 · + 1 rock · wanted +1\nthe burrito had a rock in it.\nthe rock is the burrito.");
          feedPost("food truck guy is selling rocks. probably. this is the news.", '@local_eyewitness');
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'priests_son', name:"THE PRIEST'S SON", sprite:'priestson', x:1740, y:1480, w:24,h:28, color:'#2a2030', legacyStructureIndex:3,
      hp:40, maxHp:40, speed:0, hostile:false,
      interact: (n)=> dialogue("THE PRIEST'S SON", "he is wearing a backwards cap.\nhe is the priest's son.\nthe priest does not acknowledge this.", [
        { label: 'ask about the priest.', action: ()=>{
          toast("'he's not my dad.'\n(the eyes are the same.)\n(- 1 brain)");
          P.brain = Math.max(0, P.brain - 1);
        }},
        { label: P.cash>=10?'buy a real tic-tac. $10. (+1 rock — actually??)':"specials run $10.", disabled: P.cash<10, action: ()=>{
          P.cash -= 10;
          if (Math.random() < 0.5) { P.rocks++; toast("- $10 · + 1 rock\nthe priest's son is a businessman."); }
          else { toast("- $10\nit was. it was just a tic-tac.\nthe priest's son walks away whistling."); }
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    { id:'karaoke', name:'KARAOKE MIKE', sprite:'karaoke', x:1660, y:1180, w:24,h:28, color:'#603080', legacyStructureIndex:4,
      hp:40, maxHp:40, speed:0, hostile:false,
      interact: (n)=> dialogue('KARAOKE MIKE', "he holds a karaoke machine.\nit is just a machine. there is no microphone.\nhe sings without one.", [
        { label: P.cash>=5?'sing a song. $5. (rhythm minigame)':"karaoke is $5.", disabled: P.cash<5, action: ()=>{
          P.cash -= 5; startRhythmMini();
          recordRecognition('laundromat','buy','karaoke');
        }},
        { label: 'request a song.', action: ()=>{
          toast("he sings the song you want.\nyou did not request a song.\nyou wanted, in fact, to leave.");
        }},
        { label: 'leave.', action:()=>{} },
      ]) },
    // v13 wave 8a — SKID ROW ambient hostiles. variants of brutus/lurch/sherri,
    // aggro on sight (n.hostile:true). street faction by archetype. high encounter rate.
    { id:'skid_brutus_1', name:'BRUTUS (SKID)', sprite:'brutus', x: 2700, y: 1820, w:32,h:24, color:'#3a2810',
      hp:60, maxHp:60, speed:1.5, hostile:true, aggro:true, dmg:7, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'charger', showHp:true },
    // v22 robbery — robs:true makes THIS grab take a thing (robbery.js). The flag is
    // the zone scope (I-ZONE-SCOPED): only the skid grabber carries it. The back-alley
    // lurch, the kingdom grabbers, the dog — grabbers all, robbers none.
    { id:'skid_lurch',    name:'LURCH (SKID)',  sprite:'lurch',  x: 3020, y: 1940, w:28,h:34, color:'#3a2030',
      hp:55, maxHp:55, speed:1.5, hostile:true, aggro:true, dmg:6, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'grabber', robs:true, showHp:true },
    { id:'skid_sherri',   name:'SHERRI (SKID)', sprite:'sherri', x: 2860, y: 2080, w:26,h:30, color:'#3a1820', legacyStructureIndex:13,
      hp:45, maxHp:45, speed:2.1, hostile:true, aggro:true, dmg:5, zoneOnly:{x:2480,y:1520,w:900,h:720},
      archetype:'swarmer', showHp:true },
  ];
  runtime.npcs.forEach(n => { n.hpMax = n.maxHp; n.attackCd=0; n.targetX=n.x; n.targetY=n.y; n.wanderT=0; n.showHp=n.showHp||false; });
}

export function spawnCashPiles() {
  // 22 piles scattered in non-obvious spots, $3-$10 each
  const spots = [
    {x:140,y:130,a:6},{x:580,y:420,a:5},{x:160,y:760,a:7},{x:380,y:780,a:5},
    {x:1540,y:840,a:8},{x:1760,y:980,a:4},{x:1620,y:160,a:7},{x:1940,y:380,a:8},
    {x:1380,y:1620,a:5},{x:780,y:1620,a:4},{x:110,y:1640,a:7},{x:600,y:1310,a:5},
    {x:1640,y:1320,a:8},{x:1940,y:1600,a:6},{x:120,y:1860,a:4},{x:680,y:1860,a:5},
    {x:1040,y:260,a:5},{x:1380,y:440,a:6},{x:900,y:1080,a:4},{x:1500,y:660,a:5},
    {x:260,y:1700,a:6},{x:1800,y:1180,a:7},
    // v13 wave 8a — SKID ROW hidden cash. 5 piles totaling ~$100. tweaker-vision gated like the rest.
    {x:2620,y:1780,a:18},{x:2980,y:1820,a:22},{x:3200,y:1940,a:14},
    {x:2780,y:2120,a:24},{x:3140,y:2140,a:20},
    // v13 wave 8a — OLD SCHOOL hidden cash. one pile, $30, behind the building.
    {x:3760,y:330,a:30},
  ];
  runtime.cashPiles = spots.map((s,i)=>({ id:'cp_'+i, x:s.x, y:s.y, amt:s.a, collected:state.cashPilesCollected.has('cp_'+i)}));
  // v13 wave 3 — intro_remember plant: guaranteed $10 pile inside THE BLOCK, just outside the crate.
  // crate is at (1050, 880). place pile at (1180, 870) — visible from spawn, not under the crate.
  if (state.flags && !state.flags.introDone) {
    const introId = 'cp_intro_remember';
    if (!state.cashPilesCollected.has(introId)) {
      runtime.cashPiles.push({ id: introId, x: 1180, y: 870, amt: 10, collected: false, intro: true });
    }
  }
}

export function init_helpers_spawns() {
  // ---------- helpers ----------
  
  
  
  
  
  
  // v13 wave 8b — returns the zone object the player currently stands in (or null).
  // when zones overlap, the one with the higher-absolute faction tier wins (so a LOVED
  // street overlap beats neutral spiritual; HATED scrap beats neutral street).
  
  
  
  
  
  // ---------- NPCs setup ----------
  
  
  // hidden cash piles
  
  
  
}
