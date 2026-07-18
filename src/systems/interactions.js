/* Generated from frozen rock_bottom_v19.html.
 * Source seams: ending, interaction, and dumpster systems.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, applyEquipStats, dialogue, particles, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { EQUIPMENT, PUBLIC_PHONE_LINES, VENDOR_FLOATER_IDS } from '../data/catalogs.js';
import { inZone } from '../data/npc_spawns.js';
import { PROPS, copperSiteAt, interactiveProps, rideableCart } from '../data/props.js';
import { W } from '../data/world.js';
import { possumDialogue } from '../dialogue/neighborhood_a.js';
import { tryEnterOldSchool, tryParkBenchSit } from '../dialogue/vendors_places.js';
import { blockMenu, panhandle, pickupWeapon, startHeist } from '../minigames/activities.js';
import { hasPropane } from '../minigames/heat.js';
import { tryKingdomDoor, tryUseKingdomTarget, tryUseOfficeFieldTarget } from './campaigns.js';
import { questToast } from './combat.js';
import { feedPost } from './communications.js';
import { concessionMenu, concessionUnlocked } from './concessions.js';
import { hideoutOwned, tryEnterHideout, tryEnterOffice } from './daily_hideouts.js';
import { tryStampBlockRoute } from './progression_routes.js';
import { recordNpcBother, recognitionVenueAt } from './recognition.js';

export function endingScreen(kind) {
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  const titleText = kind === 'kingdom' ? 'ONE CRACKLORD' : kind === 'coop' ? 'TUESDAYS AND THURSDAYS' : 'CRACK LORD SUPREME';
  const subText = kind === 'kingdom'
    ? 'the kingdom is four curbs and a ditch · the throne is a folding chair'
    : kind === 'coop'
      ? 'you and stripe split the corner · you get the slow days'
      : 'the corner is yours · you get tuesdays and thursdays';
  t.innerHTML = `
    <h1 style="color:#d06030;font-size:36px">${titleText}</h1>
    <div class="sub">${subText}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum still knows</div>`;
  // An ending is a receipt, not a save eraser. The route ledger survives the punchline.
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryInteract() {
  if(state.bossKind==='kingdom')return;
  // v18 headquarters is a separate door type; it never enters hideoutOwned(kind).
  if (tryEnterOffice()) return;
  // v13 wave 7 — hideout doors (E within 40px while owned). doors win over everything.
  if (tryEnterHideout()) return;
  // v13 wave 8a — old school door (E within 44px). modal interior dialogue (hideout pattern).
  // wave 8.6: now rank-gated (P.rank >= 3) inside tryEnterOldSchool.
  if (tryEnterOldSchool()) return;
  if (tryKingdomDoor()) return;
  if (tryUseKingdomTarget()) return;
  if (tryUseOfficeFieldTarget()) return;
  // v17 block-route stamps are authored away from NPC anchors. They sit after doors and
  // before the general scan so the prompt and the actual E action always agree.
  if (tryStampBlockRoute()) return;

  // v13 wave 8.6 — NPCs win over interactive props. closest-NPC-within-60px first.
  // before this lift, kickable trash / pay phone / dumpster / cart / bench all fired ahead
  // of the NPC scan, which routed E to a trash can when standing next to a vendor.
  // chain (post-doors): NPCs > heist trigger > interactive props (bench, trash, phone, cart,
  // dumpster) > zone-only verbs (smoke at block, panhandle at market).
  let bestNpc = null, bestNpcD = 60*60;
  for (const n of runtime.npcs) {
    if (n.dead || !n.interact) continue;
    const dx = (P.x+P.w/2) - (n.x+n.w/2), dy = (P.y+P.h/2) - (n.y+n.h/2);
    const d2 = dx*dx+dy*dy;
    if (d2 < bestNpcD) { bestNpcD = d2; bestNpc = n; }
  }
  if (bestNpc) {
    if (bestNpc.id === 'pete' && bestNpc.shopClosed) {
      toast("pete is sleeping inside.\n'we open at 6.'", 1800); return;
    }
    // v13 wave 3 — first-time interaction with a tracked vendor lifts the "?" floater
    // and adds them to the people-met index.
    if (VENDOR_FLOATER_IDS.has(bestNpc.id)) {
      const first = !state.metVendors.has(bestNpc.id);
      state.metVendors.add(bestNpc.id);
      if (first) saveGame();
      // intro_tony auto-completes the moment the player opens tony's dialogue
      if (bestNpc.id === 'tony' && state.quests.intro_tony && state.quests.intro_tony.available && !state.quests.intro_tony.done) {
        state.quests.intro_tony.done = true;
        P.cred += 1;
        questToast('THE MAN AT THE CORNER');
        toast("he charges ten dollars. that is the price.\nhe does not negotiate. sometimes he does.", 3400);
        if (state.quests.intro_smoke) state.quests.intro_smoke.available = true;
      }
    }
    recordNpcBother(bestNpc.id);
    bestNpc.interact(bestNpc);
    return;
  }

  // copper-site heist trigger — proximity to any registered site (v22 wave 5.1; the abandoned
  // building resolves through the same registry). NPCs already missed; this stays the
  // highest-priority non-NPC interaction because it's the canonical late-game gate.
  const heistSite = copperSiteAt(P.x+P.w/2, P.y+P.h/2);
  if (heistSite) { startHeist(heistSite.id); return; }
  // v13 wave 8a — park bench sit toggle (E within 50px of any park_bench).
  if (tryParkBenchSit()) return;
  // v13 wave 6 — kickable trash cans (E within 50px). 50% cash / 20% junk / 30% rats.
  for (const ip of interactiveProps) {
    if (ip.type !== 'trashcan') continue;
    const ddx = (P.x+P.w/2) - ip.x, ddy = (P.y+P.h/2) - ip.y;
    if (ddx*ddx + ddy*ddy < 50*50) {
      if (ip.cdT > 0) { toast("the can is empty.\nyou kick it anyway.\nit barely moves.", 1500); return; }
      kickTrashCan(ip);
      return;
    }
  }
  // v13 wave 6 — pay phone answer (E within 30px while ringing)
  const phone = PROPS.find(p => p.type === 'pay_phone');
  if (phone) {
    const ddx = (P.x+P.w/2) - phone.x, ddy = (P.y+P.h/2) - phone.y;
    if (ddx*ddx + ddy*ddy < 38*38 && state.phonePropRingT > 0) {
      answerPublicPhone();
      return;
    }
  }
  // shopping cart mount/dismount
  const cart = rideableCart();
  if (cart) {
    if (P.cartMounted) {
      // dismount near player
      P.cartMounted = false;
      cart.x = P.x + 4; cart.y = P.y + 8;
      applyEquipStats();
      toast('you abandon the cart.\nit rolls slightly. accuses you.', 1800);
      return;
    } else {
      const dx = (P.x+P.w/2) - cart.x, dy = (P.y+P.h/2) - cart.y;
      if (dx*dx + dy*dy < 36*36) {
        P.cartMounted = true;
        applyEquipStats();
        unlockAchievement('cart_baron');
        toast('+ shopping cart\n+1 speed. you can hit people now.', 2200);
        return;
      }
    }
  }
  // dumpster dive
  for (const p of PROPS) {
    if (p.type !== 'dumpster') continue;
    const dx = (P.x+P.w/2) - (p.x+p.w/2), dy = (P.y+P.h/2) - (p.y+p.h/2);
    if (dx*dx + dy*dy < 44*44) {
      if (p.looted) { toast('the dumpster is empty.\nyou look anyway.', 1500); return; }
      // tips jar bonus
      if (p.tipsJar) {
        p.tipsJar = false;
        P.cash += 8 + Math.floor(Math.random()*7);
        audio.coin();
        toast("there's a 'TIPS' jar duct-taped to the dumpster.\nit has cash in it.\n+ $"+ (8 + Math.floor(Math.random()*7))+"\n(then there's the rest of the dumpster.)", 3000);
      }
      startDumpsterDive(p);
      return;
    }
  }
  // smoke at block — open menu (zone verb, fires only when no NPC / prop took the E)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'block')) {
    blockMenu();
    return;
  }
  // panhandling at marketplace — easy money (zone verb, NPC scan already missed)
  if (inZone(P.x+P.w/2, P.y+P.h/2, 'market')) {
    panhandle();
    return;
  }
  // v20 landing 3 — a conceded venue answers the E the way the block does.
  // zone verb, lowest priority: NPCs, doors, props, and the bench all take the key first.
  const concessionVenue = recognitionVenueAt(P.x+P.w/2, P.y+P.h/2);
  if (concessionVenue && concessionUnlocked(concessionVenue)) {
    concessionMenu(concessionVenue);
    return;
  }
}

export function startDumpsterDive(dumpster) {
  state.mode = 'dialogue';
  const items = [];
  const trashPool = [
    {n:'half a chimichanga', q:'eat', heal:12},
    {n:'a wet sock', q:'sell', val:2},
    {n:'a license plate', q:'item', id:'license'},
    {n:'a hot pocket sleeve', q:'sell', val:3},
    {n:'a tooth (gold)', q:'sell', val:18},
    {n:'a strange shoe', q:'equip', id:'crocs'},
    {n:'a parka in august', q:'equip', id:'parka'},
    {n:'a single airpod', q:'equip', id:'airpods'},
    {n:'a mesh hat', q:'equip', id:'mesh_cap'},
    {n:'a cowboy hat', q:'equip', id:'cowboy'},
    {n:'a hotel bathrobe', q:'equip', id:'bathrobe'},
    {n:'a windbreaker', q:'equip', id:'windbreaker'},
    {n:'a ski mask in june', q:'equip', id:'ski_mask'},
    {n:'a tiny construction helmet', q:'equip', id:'helmet'},
    {n:'a trench coat (one of three)', q:'equip', id:'trench'},
    {n:'a flashlight (dead)', q:'item'},
    {n:'a receipt', q:'item'},
    {n:'a lottery ticket (unscratched)', q:'item', id:'lottery'},
    {n:"someone's wallet ($15)", q:'cash', val:15},
    {n:"a stack of singles ($8)", q:'cash', val:8},
    {n:'a possum (alive)', q:'event', what:'possum'},
    {n:"someone's wedding ring", q:'sell', val:22},
  ];
  // v13 wave 6 — bias by distance from THE BLOCK center (1050, 840).
  // close dumpsters lean toward nothing; far dumpsters carry the loot table.
  const blockCx = 1050, blockCy = 840;
  const dDist = Math.sqrt((dumpster.x-blockCx)**2 + (dumpster.y-blockCy)**2);
  const farFactor = Math.min(1, dDist / 900); // 0 = next to block, 1 = max distance
  // table: 30% nothing, 30% $1-4, 20% junk, 10% clean packet, 8% broken bottle, 2% propane (one-and-done)
  // bias: closer dumpsters get higher nothing chance.
  const r = Math.random();
  const noNothingBoost = farFactor * 0.6; // far dumpsters have less "nothing"
  const noneCut = 0.30 + (1 - farFactor) * 0.20; // close = 50% nothing, far = 30%
  let lootPicked = null;
  if (r < noneCut) {
    lootPicked = {n:'nothing. dumpsters know.', q:'rats'};
  } else if (r < noneCut + 0.30) {
    lootPicked = {n:"$"+(1+Math.floor(Math.random()*4))+' in loose bills', q:'cash', val: 1+Math.floor(Math.random()*4)};
  } else if (r < noneCut + 0.50) {
    lootPicked = {n:'a piece of junk (sells $1)', q:'junkdrop'};
  } else if (r < noneCut + 0.60) {
    lootPicked = {n:'a clean packet of supply', q:'clean_packet'};
  } else if (r < noneCut + 0.68) {
    lootPicked = {n:'a broken bottle (weapon)', q:'bb_weapon'};
  } else {
    // remaining slice (~32% buffer) — propane only if far enough AND not already awarded
    if (farFactor > 0.6 && !hasPropane() && !state.flags.dumpsterPropaneAwarded && Math.random() < 0.07) {
      lootPicked = {n:'a propane torch (dented)', q:'torch_drop'};
    } else {
      // fall back to a random standard item from the trashPool
      lootPicked = trashPool[Math.floor(Math.random()*trashPool.length)];
    }
  }
  // 2 random fillers + the loot-table pick
  for (let i=0;i<2;i++) items.push(trashPool[Math.floor(Math.random()*trashPool.length)]);
  items.push(lootPicked);
  dialogue('THE DUMPSTER', "you are inside a dumpster.\nyou find three things.\nyou can take one.", items.map((it,idx) => ({
    label: it.n + (it.q==='sell'?' (sell)':it.q==='eat'?' (eat)':it.q==='cash'?' (take)':it.q==='equip'?' (wear)':''),
    action: () => {
      if (it.q === 'eat') { P.hp = Math.min(P.maxHp, P.hp + (it.heal||5)); toast('+ '+it.heal+' hp\n(it tastes like the dumpster.)'); }
      else if (it.q === 'sell') { const v = it.val || (3 + Math.floor(Math.random()*4)); P.cash += v; toast('+ $'+v+'\n('+it.n+'.)'); audio.coin(); }
      else if (it.q === 'cash') { P.cash += it.val; audio.coin(); toast('+ $'+it.val+'\n('+it.n+'.)'); }
      else if (it.q === 'item') { P.inventory.push({id: it.id||it.n.replace(/\W/g,''), n: it.n, q: 1}); toast('+ '+it.n); }
      else if (it.q === 'equip' && it.id && EQUIPMENT[it.id]) {
        const slot = EQUIPMENT[it.id].slot;
        P.equip[slot] = it.id; applyEquipStats();
        toast('+ EQUIPPED · '+EQUIPMENT[it.id].n);
      }
      else if (it.q === 'event' && it.what === 'possum') {
        toast("a possum.\nhe is annoyed.\nhe leaves through the lid.");
        possumDialogue();
      }
      // v13 wave 6 — new loot-table outcomes
      else if (it.q === 'rats') {
        toast("the rats are upset.\nthey have lives.", 2000);
        for (let i=0;i<10;i++) particles.push({x:dumpster.x+Math.random()*dumpster.w, y:dumpster.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-0.5, life:600, c:'#181010', sz:2});
      }
      else if (it.q === 'junkdrop') {
        P.inventory.push({id:'junk', n:'a piece of junk', q:1});
        toast("+ a piece of junk.\n(pete will take it. for one dollar.)", 2200);
      }
      else if (it.q === 'clean_packet') {
        P.supplies = (P.supplies||0) + 1;
        toast("+ a clean packet.\n(unmarked. you take it. you don't ask.)", 2400); audio.coin();
      }
      else if (it.q === 'bb_weapon') {
        pickupWeapon('broken_bottle');
        toast("+ a broken bottle.\nit cuts. you understand this.\n(weapon equipped.)", 2600);
      }
      else if (it.q === 'torch_drop') {
        if (!hasPropane()) {
          P.equip.tool = 'propane_torch';
          applyEquipStats();
          state.flags.dumpsterPropaneAwarded = true;
          toast("+ a propane torch (dented).\nsomebody buried this.\n(equipped.)", 4400);
          feedPost("found a torch in a dumpster. the dumpster knew.", '@crackheadcent');
        } else {
          toast("a torch. you already have one.\nyou close the lid.", 2000);
        }
      }
      dumpster.looted = true;
      dumpster.diveCdT = 90000; // v13 wave 6 — 90s cooldown per dumpster after a dig
      state.counters.dumpDives = (state.counters.dumpDives||0) + 1;
      saveGame();
    }
  })).concat([{label:'climb out.', action:()=>{ dumpster.looted = true; toast('you climb out.\nno one saw.\n(some saw.)'); }}]));
}

export function kickTrashCan(can) {
  can.cdT = 60000;
  can.tipT = 200;
  can.rotPulse = 200;
  audio.kick ? audio.kick() : audio.hit();
  state.shake = Math.max(state.shake, 3);
  const r = Math.random();
  if (r < 0.5) {
    // cash $2-5
    const amt = 2 + Math.floor(Math.random()*4);
    P.cash += amt;
    audio.coin();
    toast("- nothing\n+ $"+amt+"\nthe can falls. coins spill.", 2200);
    // particles for cash poof
    for (let i=0;i<6;i++) particles.push({x:can.x, y:can.y, vx:(Math.random()-.5)*3, vy:-Math.random()*2-1, life:600, c:'#e8c040', sz:3, glow:true});
  } else if (r < 0.7) {
    // junk
    P.inventory.push({id:'junk', n:'a piece of junk', q:1});
    toast("+ a piece of junk.\npete will take it. for one dollar.", 2400);
  } else if (r < 0.8) {
    // food (10% bonus drop)
    P.inventory.push({id:'food', n:'a can of food (unmarked)', q:1});
    toast("+ a can of food (unmarked).\nthe label is in a language.\nthe language is not yours.", 2600);
  } else {
    // rats
    toast("the rats are upset. they have lives.", 2000);
    for (let i=0;i<8;i++) particles.push({x:can.x+(Math.random()-.5)*16, y:can.y, vx:(Math.random()-.5)*4, vy:-Math.random()*2-0.5, life:700, c:'#181010', sz:2});
  }
  saveGame();
}

export function answerPublicPhone() {
  state.phonePropRingT = 0;
  state.publicPhoneAnswered = (state.publicPhoneAnswered||0) + 1;
  audio.dialogue();
  const line = PUBLIC_PHONE_LINES[Math.floor(Math.random()*PUBLIC_PHONE_LINES.length)];
  toast("📞 PUBLIC PHONE\n\n"+line.text, 6000);
  if (line.action) line.action();
  if (state.publicPhoneAnswered >= 5) unlockAchievement('phone_booth_prophet');
  saveGame();
}

export function init_ending_interactions() {
  // ---------- ENDING ----------
  
  
  // ---------- INTERACT ----------
  
  
  // ---------- DUMPSTER DIVE ----------
  // v13 wave 6 — distance-from-block biases the loot. far dumpsters can drop a propane torch (rare).
  
  
  // v13 wave 6 — kickable trash. RNG outcome + 60s cooldown + tip-over anim.
  
  
  // v13 wave 6 — answer the public pay phone. randomly picks a PUBLIC_PHONE_LINE.
  
  
  
}
