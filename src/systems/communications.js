/* Generated from frozen rock_bottom_v19.html.
 * Source seams: calls, possum, truck, news, feed, and world events.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { PROPS } from '../data/props.js';
import { P, dialogue, runtime, state, toast, unlockAchievement } from '../legacy.js';

export let PHONE_CALL_LINES, MOM_TIP_CALL, MOM_PROUD_LINES, NEWS_POOL, newsState, phoneState, FEED_HANDLES, WORLD_EVENTS;

export function ringPhone(forced) {
  if (state.mode !== 'playing') return;
  // v13 wave 3 — `forced` lets the intro mom-tip fire even during the suppression window.
  const call = forced || PHONE_CALL_LINES[Math.floor(Math.random()*PHONE_CALL_LINES.length)];
  audio.dialogue();
  toast('📞 incoming call · ' + call.from + '\n\n' + call.text, 5500);
  feedPost('phone call from ' + call.from.toLowerCase() + '.', '@phone_guy');
  if (call.action) call.action();
}

export function fireMomIntroTipOnce() {
  if (!state.flags) return;
  if (state.flags.momIntroFired) return;
  if (state.mode !== 'playing') return;
  state.flags.momIntroFired = true;
  ringPhone(MOM_TIP_CALL);
  saveGame();
}

export function maybeFireMomProudCall() {
  if (!state.flags) return;
  if (state.mode !== 'playing') return;
  if ((state.flags.momProudCallDay || 0) === state.day) return;
  if (!P.faction || P.faction.spiritual < 10) return;
  // silence window guard (day 7 event)
  if (state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  state.flags.momProudCallDay = state.day;
  const txt = MOM_PROUD_LINES[Math.floor(Math.random()*MOM_PROUD_LINES.length)];
  ringPhone({ from: 'YOUR MOM', text: txt + "\n(+5 brain)", action: () => { P.brain = Math.min(100, P.brain + 5); } });
}

export function spawnPetPossum() {
  if (runtime.npcs.find(n=>n.id==='pet_possum')) return;
  runtime.npcs.push({
    id:'pet_possum', name:'YOUR POSSUM', sprite:'possum',
    x: P.x - 30, y: P.y + 12, w:28, h:24, color:'#604030',
    hp:30, maxHp:30, speed:1.6, hostile:false, isPet:true, frame:0,
    interact: () => dialogue('YOUR POSSUM', "he stares.\nhe has been with you for some time now.\nhe has things to say. he will not.", [
      { label: 'release the possum back to the wild.', action: () => {
        const pet = runtime.npcs.find(n=>n.id==='pet_possum'); if (pet) pet.dead = true;
        toast("you set the possum down.\nhe walks the other way without looking back.\nyou understand.");
        P.hasPossum = false;
      }},
      { label: 'leave.', action:()=>{} },
    ]),
  });
  P.hasPossum = true;
  toast("the possum follows you now.\nhe is on his route.\nyou are on his route.", 3500);
  broadcastNews("LOCAL MAN ACQUIRES POSSUM. POSSUM SEEMINGLY UNFAZED.");
  feedPost("the possum follows me now. i don't know what this means.", '@crackheadcent');
  unlockAchievement('the_route');
}

export function garbageTruckRumble() {
  audio.traffic();
  audio.traffic();
  toast("a garbage truck rumbles down the street.\nall dumpsters are reset.\none of them now has a 'TIPS' jar duct-taped to the side.", 4200);
  feedPost("garbage truck went through. fresh dumpsters in the neighborhood.", '@local_eyewitness');
  // reset all dumpsters
  PROPS.filter(p => p.type === 'dumpster').forEach(p => { p.looted = false; });
  // pick one to get a tips jar
  const dumps = PROPS.filter(p => p.type === 'dumpster');
  if (dumps.length) {
    const lucky = dumps[Math.floor(Math.random()*dumps.length)];
    lucky.tipsJar = true;
  }
  broadcastNews("GARBAGE TRUCK COMPLETES ROUTE. DUMPSTERS REOPEN FOR BUSINESS.");
}

export function rotateNews() {
  const tape = document.getElementById('tape');
  if (!tape) return;
  // build a rotating string of 4-6 news items
  const items = [];
  for (let i=0;i<5;i++) items.push(NEWS_POOL[(newsState.idx + i) % NEWS_POOL.length]);
  newsState.idx = (newsState.idx + 1) % NEWS_POOL.length;
  tape.textContent = items.join('   ◆   ');
}

export function broadcastNews(line) {
  // v13 wave 7 — silence window suppresses the ticker. day-event triggers always go through (Date.now check).
  if (state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  const tape = document.getElementById('tape');
  if (!tape) return;
  tape.textContent = '· BREAKING · ' + line + '   ◆   ' + tape.textContent;
}

export function feedPost(text, handle) {
  // v13 wave 7 — silence window suppresses the phone feed (day 7 event).
  if (state.flags && state.flags.silenceUntilT && state.flags.silenceUntilT > Date.now()) return;
  const h = handle || FEED_HANDLES[Math.floor(Math.random()*FEED_HANDLES.length)];
  phoneState.posts.unshift({ h, t: text, day: state.day });
  while (phoneState.posts.length > 8) phoneState.posts.pop();
  renderPhone();
}

export function renderPhone() {
  const box = document.getElementById('phonebox');
  const list = document.getElementById('phPosts');
  const day = document.getElementById('phDay');
  if (!box || !list) return;
  box.classList.toggle('show', phoneState.visible && state.mode==='playing');
  day.textContent = state.day;
  list.innerHTML = phoneState.posts.map(p => `<div class="post"><b>${p.h}</b><br>${p.t}</div>`).join('');
}

export function fireRandomEvent() {
  const ev = WORLD_EVENTS[Math.floor(Math.random()*WORLD_EVENTS.length)];
  toast(ev.text, 5500);
  if (ev.effect) ev.effect();
  if (ev.sfx) audio[ev.sfx]();
  feedPost(ev.text.split('\n')[0].toLowerCase(), '@local_eyewitness');
  if (Math.random() < 0.3) broadcastNews(ev.text.split('\n')[0]);
}

export function init_communications() {
  // ---------- INCOMING PHONE CALLS ----------
  PHONE_CALL_LINES = [
    { from:'TRE BAG TONY', text:"come see me.\ni have rocks.\nyou know how this works.", action:() => {} },
    { from:'YOUR MOM', text:"don't come over for thanksgiving.\nben said you can't.\nben is not your dad.\n(- 5 brain)", action:() => { P.brain = Math.max(0, P.brain - 5); } },
    { from:'A WRONG NUMBER', text:"this is dolores.\nis carl there.\ncarl owes me $40.\n(+$3, the wrong number gave you advice)", action:() => { P.cash += 3; } },
    { from:'STRIPE', text:"yo. i got new product.\nfor sure not soap this time.\nfor sure.", action:() => {} },
    { from:'THE CONDUCTOR', text:"the train.\nit is closer now.\nit will not be here.", action:() => {} },
    { from:'YOUR LANDLORD', text:"you do not have a landlord.\nyou do not have an apartment.\nhe is calling anyway.", action:() => {} },
    { from:'A POSSUM (on a flip phone)', text:"...\n*click*", action:() => { P.brain = Math.min(100, P.brain + 4); } },
    { from:'FATHER O\'MALLEY', text:"come to mass.\nbring shakes.\nthe tic-tacs are blessed today.", action:() => {} },
    { from:'A SCAM', text:"hello sir we are calling about your car's extended warranty.\nyou do not have a car.\nyou do not have an extended warranty.\n(+1 cred for hanging up)", action:() => { P.cred += 1; } },
    { from:'PAULIE', text:"the face is doing a thing.\nyou should come look at it.", action:() => {} },
    { from:'YURI', text:"BRUTUS REMEMBER.\n*click*", action:() => {} },
    { from:'YOUR OWN VOICE', text:"hey.\nit's you.\nyou should drink water.\n(+10 brain)", action:() => { P.brain = Math.min(100, P.brain + 10); } },
  ];
  
  
  // v13 wave 3 — mom's first-day tip. fires ~30s after a new save begins. only fires once per save.
  MOM_TIP_CALL = {
    from: 'YOUR MOM',
    text: "remember tony likes you.\nyou said you'd come see him.\nyou said it twice.",
    action: () => {}
  };
  
  
  // v13 wave 7 — spiritual LIKED+: mom calls with a proud line, +5 brain.
  // fires at most once per day, only when spiritual >= +10 (LIKED).
  MOM_PROUD_LINES = [
    "remember when you were six.\nyou drew a duck.\nthe duck was good.\nthe duck is on the fridge.",
    "kelly's son is fine. he is fine.\nhe is not you. you are also fine.",
    "ben says hi. ben says it the way ben says it.\nyou know what i mean.",
    "i told the women at trader joe's about you.\nthey nodded.\nthey nodded a lot.",
  ];
  
  
  // ---------- PET POSSUM follower ----------
  
  
  // ---------- GARBAGE TRUCK event ----------
  
  
  // ---------- news ticker ----------
  NEWS_POOL = [
    "good evening. tony has not blinked since 1994.",
    "weather: tuesday. with a 40% chance of more tuesday.",
    "local pigeon demands $2. economists call it 'fair'.",
    "the train is coming. the train will never be here. more at 11.",
    "father o'malley refuses comment on whether tic-tacs are medicine.",
    "yuri says: 'BRUTUS remember.' yuri did not elaborate.",
    "an entire family of crackheads moved into the alley. they were already there.",
    "the conductor's pocket watch is set to a year that does not exist yet.",
    "possum spotted wearing tiny construction helmet. osha 'cautiously optimistic'.",
    "marketplace stall #3 sells only umbrellas. weather forecast: lawsuit.",
    "stripe insists rock is real. lab tests inconclusive (it is soap).",
    "the abandoned building is humming. b flat. it has been for 12 years.",
    "pete weighed a single sock for 11 minutes. the sock did not survive.",
    "loud larry remains loud. doctors stunned.",
    "whole foods mom is worried. about you. specifically.",
    "the big guy is, in fact, tall. updates as they happen.",
    "in sports: nothing. the team has not arrived. the team does not exist.",
    "baggie barb is doing the crossword. she will not look up. she has packets.",
    "the crate is, by ordinance, not a kitchen. the crate is, by use, a kitchen.",
    "stripe is buying rocks now. he says 'inventory.' he says it once.",
    "horoscope: avoid copper. embrace copper. you will trade copper.",
    "BREAKING: a dachshund in a blazer was seen entering the church.",
    "the pigeon king has named a successor. the successor is also a pigeon.",
  ];
  newsState = { current: [], idx: 0, t: 0 };
  
  
  
  // ---------- phone feed ----------
  phoneState = { posts: [], visible: false };
  FEED_HANDLES = [
    '@crackheadcent','@tony_observer','@possum_official','@pawn_pete','@the_corner',
    '@father_o','@conductor_eta','@stripe_certified','@whole_foods_mom_irl','@pigeon_news',
    '@yuri_metals','@lurch_thoughts','@brutus_blog','@the_alley_post','@cubscout_mom',
  ];
  
  
  
  // ---------- world events (random absurd spawns) ----------
  WORLD_EVENTS = [
    { id:'forklift_possum', text:"a possum drives a forklift through the marketplace.\nhe has a clipboard. he is doing inventory." },
    { id:'cloud_yell', text:"a man yells at a cloud.\na child watches. respects you immediately. (+2 cred)", effect: () => { P.cred += 2; } },
    { id:'doordash', text:"a doordash driver hands you a bag and runs.\ninside: a single chicken nugget and someone's $400 sushi platter.\n(+$12)", effect: () => { P.cash += 12; } },
    { id:'car_alarm', text:"a car alarm goes off.\nit plays a song that has lyrics. no one acknowledges this.", sfx:'glassBreak' },
    { id:'chimichanga', text:"a chimichanga rolls past you.\nit is talking. it has opinions about a man named greg." },
    { id:'horse_nod', text:"a cop on horseback nods at you. the horse also nods.\ndisturbing levels of agreement." },
    { id:'pothole_say', text:"a pothole says your full legal name.\nyou did not give it your full legal name." },
    { id:'pigeon_road', text:"a pigeon stands in the road.\nthree cars wait. it is the pigeon king's nephew." },
    { id:'forget_year', text:"you forget what year it is for 4 minutes.\nwhen you come back, you are holding a traffic cone.\n(- 3 brain)", effect: () => { P.brain = Math.max(0, P.brain-3); P.inventory.push({id:'cone', n:'a traffic cone', q:1}); } },
    { id:'puddle_wave', text:"you see your reflection in a puddle.\nhe waves. you don't wave back.\nhe waves harder." },
    { id:'pigeon_change', text:"a pigeon shits exactly $4.20 in change directly on your head.\nthe pigeon nods. you nod. the exchange is complete.\n(+$4)", effect: () => { P.cash += 4; } },
    { id:'sushi_wedding', text:"a wedding procession crosses the street.\nthe bride is unaccompanied. the groom is a vending machine." },
    { id:'sandwich_lecture', text:"a sandwich lectures you about logistics for 8 seconds.\nyou nod. you understand none of it. you feel taller.\n(+1 cred)", effect: () => { P.cred += 1; } },
    { id:'siren_distant', text:"sirens. far away. somebody else's problem.", sfx:'copSiren' },
    { id:'tony_blinks', text:"tony blinks.\nyou see it.\nit is the only thing.\n(+5 cred)", effect: () => { P.cred += 5; broadcastNews("EYEWITNESS: TONY BLINKED. UNCONFIRMED."); } },
    { id:'dachshund', text:"a dachshund in a blazer hands you a receipt.\nit is for a haircut you did not get." },
    { id:'guy_running', text:"a man sprints past you yelling 'sorry. sorry. sorry.'\nhe is not sorry.", effect: () => { P.cash += 3; }, },
    { id:'helicopter', text:"a helicopter circles overhead for 4 seconds.\nit was a leaf.", sfx:'traffic' },
    { id:'twin_possums', text:"two possums in matching helmets walk by.\nthey are not twins. they are coworkers." },
    { id:'wedding_guy', text:"a man in a tuxedo sprints past you.\nhe is late for a wedding. or escaping one.\n(+$5)", effect: () => { P.cash += 5; } },
    { id:'pizza_box', text:"a pizza box flies past at head height.\ninside: a single tooth (gold).\n(+ a tooth (gold))", effect: () => { P.inventory.push({id:'gold_tooth', n:'a tooth (gold)', q:1}); } },
    { id:'school_bus', text:"a school bus drives past.\nthe driver is the conductor.\nthe driver is also still at his post in the train yard." },
    { id:'mom_drives_by', text:"a minivan slows down.\nthe driver looks at you.\nthe driver is your mom. she does not stop.\nyou wave. she pretends not to see.\n(-3 brain)", effect: () => { P.brain = Math.max(0, P.brain - 3); } },
    { id:'free_meatball', text:"a meatball rolls toward you.\nit is steaming.\nyou eat it. (+12 hp)", effect: () => { P.hp = Math.min(P.maxHp, P.hp + 12); } },
    { id:'man_with_sign', text:"a man holds a sign that says 'THE END.'\nthe sign is from a furniture store." },
    { id:'singing_streetlight', text:"a streetlight is singing in b flat.\nthe copper agrees." },
    { id:'free_money', text:"$20 lands at your feet.\nthere is no one nearby.\nyou look up. there is no helicopter.\n(+$20)", effect: () => { P.cash += 20; } },
    { id:'philosopher_man', text:"a man in a robe says 'we live in a society.'\nhe is correct.\nhe asks for $5. he is also correct about that.", effect: () => { if (P.cash >= 5) { P.cash -= 5; P.cred += 6; } } },
    { id:'pigeon_gang', text:"seven pigeons walk by in formation.\nthey are coordinating.\nthey nod at you. you are made." },
  ];
  
  
  
}
