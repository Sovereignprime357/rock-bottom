/* Generated from frozen rock_bottom_v19.html.
 * Source seams: daily systems and hideouts | heist, weapons, rhythm, lockpick, Brutus, and panhandling | keyboard controls | game start and new-game initialization | cache and HUD boot sequence | mobile controls and final startup.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { SAVE_KEY, audio, loadGame, saveGame } from './core/audio_save.js';
import { P, activeDialogue, applyEquipStats, closeDialogue, closePanel, dialogue, renderInventory, renderQuests, rollWeather, runtime, state, toast, unlockAchievement } from './core/runtime_ui.js';
import { last, update, updateWorld } from './core/update.js';
import { VENDOR_INDEX_META } from './data/catalogs.js';
import { clamp, isNight, spawnCashPiles, spawnNpcs } from './data/npc_spawns.js';
import { initInteractiveProps } from './data/props.js';
import { RANKS, WORLD } from './data/world.js';
import { openStripePackage } from './dialogue/neighborhood_b.js';
import { bailHeatMini, cookBatchMenu, lockHeatMini } from './minigames/heat.js';
import { resolveNpcPose } from './render/actors_weather.js';
import { buildEnvironmentSprites } from './render/canvas_geography.js';
import { drawAll } from './render/frame.js';
import { buildFogSheet, buildLandmarkFacades, buildLightSprites } from './render/landmarks_a.js';
import { PALS, SPRITE_CACHE, buildSprites } from './render/sprites.js';
import { buildGraffiti, buildPosters } from './render/structures.js';
import { CLAIM_SITES, CLAIM_SITE_BY_ID, OFFICE_DOOR, OFFICE_UPGRADE_DEFS, activeOfficeContract, cancelDistrictClaim, claimFileCost, claimGateReason, claimedDistrictIds, currentPrimaryObjective, ensureKingdomState, ensureOfficeState, fileDistrictClaim, fileOfficeWork, freshKingdomState, freshOfficeState, maybeUnlockKingdom, maybeUnlockOfficeQuest, officeDailyCap, officeOwned, openKingdomLedger, purchaseOfficeUpgrade, selectDistrictClaim, startOfficeWork, syncKingdomForces, syncKingdomQuests, syncOfficeDay, updateOfficeMilestones } from './systems/campaigns.js';
import { completeIntroSmoke, die, playerAttack, questToast } from './systems/combat.js';
import { broadcastNews, feedPost, phoneState, renderPhone, rotateNews } from './systems/communications.js';
import { adjustFaction, applyRep, factionTier } from './systems/factions.js';
import { startIncident, updateActiveIncident } from './systems/incidents.js';
import { endingScreen, tryInteract } from './systems/interactions.js';
import { ROUTE_STOPS, checkHustles, ensureBlockRoute, hustleProgress, rollBlockRoute, rollHustles, routePatchTier, tryStampBlockRoute, validBlockRoute } from './systems/progression_routes.js';
import { updateHUD } from './ui/hud.js';

export let DAILY_COUNTER_KEYS, HIDEOUT_DOORS;

export function resetDailyCounters() {
  for (const k of DAILY_COUNTER_KEYS) state.counters[k] = 0;
  // v18 office capacity shares the authoritative dawn path used by world and sleep actions.
  if (state.office) syncOfficeDay();
  if(state.kingdom)syncKingdomForces();
}

export function fireDayEvents() {
  if (!state.flags) state.flags = {};
  if (state.day === 3 && !state.flags.day3Fired)   fireDay3Visit();
  if (state.day === 7 && !state.flags.day7Fired)   fireDay7Silence();
  if (state.day === 14 && !state.flags.day14Fired) fireDay14Inheritance();
  if (state.day === 30 && !state.flags.day30Fired) fireDay30Bus();
}

export function rehydrateDay30Bus() {
  if (!state.flags) return;
  if (!state.flags.day30Fired || state.flags.busTaken || state.flags.busRefused) return;
  if (runtime.npcs.find(n => n.id === 'bus_driver')) return;
  // re-run fireDay30Bus without re-firing the broadcast, by temporarily clearing the flag and restoring.
  state.flags.day30Fired = false;
  fireDay30Bus();
}

export function fireDay3Visit() {
  state.flags.day3Fired = true;
  // spawn passive "someone you don't know" near the player. wanders off after the encounter.
  const id = 'day3_visitor_' + Date.now();
  const visitor = {
    id, name: "SOMEONE YOU DON'T KNOW", sprite: 'lurch',
    x: P.x + 80, y: P.y + 30, w: 24, h: 28, color: '#3a3030',
    hp: 30, maxHp: 30, speed: 0.6, hostile: false, archetype: 'passive',
    isDay3Visitor: true, hasFloater: '?',
    interact: (n) => dialogue("SOMEONE YOU DON'T KNOW",
      "someone you don't know.\nthey say:\n\n'i heard about you.'\n\nthat's all they say.",
      [{ label: 'leave.', action: () => { n.wanderOff = true; n.speed = 1.2; n.targetX = WORLD.w + 80; n.targetY = n.y; }}]),
  };
  visitor.x = Math.max(40, Math.min(WORLD.w - 40, visitor.x));
  visitor.y = Math.max(40, Math.min(WORLD.h - 40, visitor.y));
  runtime.npcs.push(visitor);
  toast("someone you don't know is on the block today.\nthey are not moving.\nthey are watching.", 4200);
  feedPost("someone was on the block today. someone was watching.", '@crackheadcent');
  saveGame();
}

export function fireDay7Silence() {
  state.flags.day7Fired = true;
  state.flags.silenceUntilT = Date.now() + 4 * 60 * 1000; // 4 in-game minutes (real-time, since dayTime is real-time)
  toast("the radio is off.\nthe phones are off.\nthe city is listening to something.", 5400);
  // we don't broadcast or post — that's the point.
  saveGame();
}

export function fireDay14Inheritance() {
  state.flags.day14Fired = true;
  // spawn a $500 pile in player's current zone area (near player, jittered, clamped to world)
  const px = P.x + (Math.random()-.5) * 320;
  const py = P.y + (Math.random()-.5) * 320;
  runtime.cashPiles.push({
    id: 'cp_inheritance_' + Date.now(),
    x: Math.max(40, Math.min(WORLD.w-40, px)),
    y: Math.max(40, Math.min(WORLD.h-40, py)),
    amt: 500, isInheritance: true, collected: false,
  });
  toast("something arrived today.\nyou don't know what.\nyou will, when you find it.", 4200);
  saveGame();
}

export function fireDay30Bus() {
  state.flags.day30Fired = true;
  if (state.flags.busTaken || state.flags.busRefused) return; // already resolved
  // bus stop is where pinky stands (per VENDOR_INDEX_META). spawn the driver a few tiles south.
  let bx = 1330, by = 1260;
  const driver = {
    id: 'bus_driver', name: 'THE BUS DRIVER', sprite: 'lurch',
    x: bx, y: by, w: 24, h: 28, color: '#1a2a3a',
    hp: 60, maxHp: 60, speed: 0, hostile: false, archetype: 'passive',
    isBusDriver: true, hasFloater: '?',
    interact: (n) => dialogue('THE BUS DRIVER',
      "the bus is here.\nit hasn't been here in a while.\nthe driver looks at you.\n\nare you getting on?",
      [
        { label: 'yes. get on the bus.', action: () => takeTheBus() },
        { label: 'no. not today.', action: () => {
          state.flags.busRefused = true;
          const idx = runtime.npcs.findIndex(x => x.id === 'bus_driver'); if (idx >= 0) runtime.npcs.splice(idx, 1);
          toast("the bus leaves.\nit doesn't come back.\nthat was your chance.", 5200);
          feedPost("the bus left. someone watched it leave.", '@crackheadcent');
          saveGame();
        }},
      ]),
  };
  runtime.npcs.push(driver);
  toast("a bus is at the stop.\nit hasn't been there in a while.\nthe driver is looking at you.", 5400);
  feedPost("the bus is back. it does not come back often.", '@crackheadcent');
  saveGame();
}

export function takeTheBus() {
  state.flags.busTaken = true;
  const driverIdx=runtime.npcs.findIndex(n=>n.id==='bus_driver');if(driverIdx>=0)runtime.npcs.splice(driverIdx,1);
  unlockAchievement('the_bus');
  state.mode = 'title';
  const t = document.getElementById('title');
  t.classList.remove('hide');
  t.innerHTML = `
    <h1 style="color:#6080a0;font-size:32px">THE BUS</h1>
    <div class="sub">you got on the bus.<br>the bus left.<br>you survived rock bottom.<br>the bus has a destination. it has not told you.</div>
    <div class="sub" style="margin-top:14px;opacity:.6">days: ${state.day} · rocks smoked: ${P.lifetime.rocksSmoked||0} · cred: ${P.cred|0}</div>
    <div class="start">[ SPACE / TAP ] return to the block</div>
    <div class="credit">vibekoded · the possum stayed</div>`;
  state.endingContinue=true;
  state.endingSavePromise=saveGame();
}

export function tryEnterOffice(){
  const d=OFFICE_DOOR,dx=(P.x+P.w/2)-(d.x+d.w/2),dy=(P.y+P.h/2)-(d.y+d.h/2);
  if(dx*dx+dy*dy>=44*44)return false;
  if(officeOwned())openOffice();
  else dialogue('THE OFFICE','the key does not fit.\nthe door has one lock and three opinions.\nthe leasing guy is standing somewhere in the lot.',[
    {label:'look toward the leasing guy.',action:()=>toast('east side of the lot.\nclipboard. key ring. no urgency.',2200)},
    {label:'leave.',action:()=>{}},
  ]);
  return true;
}

export function officeUpgradeCount(){const o=state.office||freshOfficeState();return OFFICE_UPGRADE_DEFS.filter(d=>o.upgrades&&o.upgrades[d.id]).length;}

export function openOffice(){
  const o=ensureOfficeState();syncOfficeDay();updateOfficeMilestones();maybeUnlockKingdom(false,true);syncKingdomQuests();
  const claims=claimedDistrictIds().length,cap=officeDailyCap(),opts=[];
  if(o.claimJob&&o.claimJob.stage==='file'){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
    opts.push({label:can?'file '+d.name.toLowerCase()+'. $'+cost+' + 1 copper.':'filing needs $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openOffice();}});
  }
  if(o.workJob&&o.workJob.stage==='file'){
    const capBlocked=o.workToday>=cap;
    opts.push({label:capBlocked?'daily ledger closed. inspected order waits for morning.':'file work order '+o.workJob.serial+'. collect the net.',disabled:capBlocked,action:()=>{fileOfficeWork();openOffice();}});
  }
  opts.push({label:o.upgrades.desk?(o.claimJob?'open the active claim file.':'open district claims. ('+claims+'/'+CLAIM_SITES.length+')'):'district claims need a desk.',disabled:!o.upgrades.desk,action:()=>openClaimLedger(0)});
  const workLabel=!o.upgrades.radio?'work orders need a radio.'
    :o.workJob?'work order '+o.workJob.serial+' is '+o.workJob.stage+'.'
    :!claims?'work orders need one claimed district.'
    :o.workToday>=cap?'work orders closed today. ('+o.workToday+'/'+cap+')'
    :'take a work order. ('+o.workToday+'/'+cap+' filed today)';
  opts.push({label:workLabel,disabled:!o.upgrades.radio||!!o.workJob||!!o.claimJob||!claims||o.workToday>=cap,action:()=>{startOfficeWork();}});
  if(state.kingdom&&state.kingdom.stage!=='locked'){
    opts.push({label:state.kingdom.stage==='summons'?'open the hostile correspondence.':'open the CURB WAR ledger.',action:()=>openKingdomLedger()});
  }
  opts.push({label:'look at office upgrades. ('+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+')',action:()=>openOfficeUpgrades()});
  opts.push({label:o.upgrades.locker?'open the chained locker.':'locker not installed.',disabled:!o.upgrades.locker,action:()=>openHideoutChest('office')});
  opts.push({label:o.upgrades.cot?'use the cot.':'cot not installed.',disabled:!o.upgrades.cot,action:()=>openOfficeCot()});
  const rerollBlocked=!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract();
  opts.push({label:!o.upgrades.route_board?'route board not installed.':o.rerollDay===state.day?'route board used today.':'replace the current block route. (no payout)',disabled:rerollBlocked,action:()=>rerollBlockRouteAtOffice()});
  opts.push({label:'leave the office.',action:()=>{}});
  dialogue('THE OFFICE','one room. one lock. '+claims+' district'+(claims===1?'':'s')+' entered in pen.\nupgrades: '+officeUpgradeCount()+'/'+OFFICE_UPGRADE_DEFS.length+'. orders filed: '+o.jobsCompleted+'.\nthe smell has seniority.',opts);
}

export function openOfficeUpgrades(){
  const o=ensureOfficeState();
  const opts=OFFICE_UPGRADE_DEFS.map(d=>{
    const owned=o.upgrades[d.id],can=P.cash>=d.cash&&P.copper>=d.copper;
    const price='$'+d.cash+(d.copper?' + '+d.copper+' copper':'');
    return {label:owned?'✓ '+d.name+' installed.':d.name+' · '+price+' · '+d.desc,disabled:owned||!can,action:()=>{purchaseOfficeUpgrade(d.id);openOfficeUpgrades();}};
  });
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('OFFICE IMPROVEMENTS','a legal pad is taped to the wall.\nthe legal pad is not legal advice.\ncash $'+P.cash+' · pure copper '+P.copper+'.',opts);
}

export function openClaimLedger(page=0){
  const o=ensureOfficeState();if(!o.upgrades.desk){openOffice();return;}
  if(o.claimJob){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],stage=o.claimJob.stage;
    const lines=stage==='survey'?d.survey.task:stage==='file'?'survey attached. filing fee pending.':d.sign.task;
    const opts=[];
    if(stage==='file'){
      const cost=claimFileCost(),can=P.cash>=cost&&P.copper>=1;
      opts.push({label:can?'file now. $'+cost+' + 1 copper.':'need $'+cost+' + 1 copper.',disabled:!can,action:()=>{fileDistrictClaim();openClaimLedger(0);}});
    }
    opts.push({label:stage==='install'?'cancel the claim. (no refund)':'cancel the claim.',action:()=>{cancelDistrictClaim();openOffice();}});
    opts.push({label:'back to the office.',action:()=>openOffice()});
    dialogue('ACTIVE CLAIM · '+d.name,'stage: '+stage+'.\n'+lines,opts);return;
  }
  if(o.workJob){dialogue('DISTRICT CLAIMS','the desk is occupied by work order '+o.workJob.serial+'.\nfinish the order before opening another file.',[{label:'back.',action:()=>openOffice()}]);return;}
  const pageSize=7,maxPage=Math.floor((CLAIM_SITES.length-1)/pageSize);page=Math.max(0,Math.min(maxPage,page));
  const slice=CLAIM_SITES.slice(page*pageSize,page*pageSize+pageSize),opts=slice.map(d=>{
    const why=claimGateReason(d),owned=(state.districtClaims||{})[d.id];
    return {label:owned?'✓ '+d.name+' · entered in pen.':why?d.name+' · '+why:d.name+' · open a survey file.',disabled:!!why,action:()=>selectDistrictClaim(d.id)};
  });
  if(page<maxPage)opts.push({label:'next ledger page.',action:()=>openClaimLedger(page+1)});
  if(page>0)opts.push({label:'previous ledger page.',action:()=>openClaimLedger(page-1)});
  opts.push({label:'back to the office.',action:()=>openOffice()});
  dialogue('DISTRICT CLAIMS · PAGE '+(page+1),'the form recognizes signs, curbs, and faction permission.\nstreet '+((P.faction&&P.faction.street)||0)+' · scrap '+((P.faction&&P.faction.scrap)||0)+' · spiritual '+((P.faction&&P.faction.spiritual)||0)+'.',opts);
}

export function openOfficeCot(){
  const o=ensureOfficeState(),powered=!!o.upgrades.generator;
  dialogue('THE COT','the cot is one inch shorter than you.\nthis has been entered as adequate.',[
    {label:'rest 30 minutes. (+'+(powered?18:10)+' hp'+(powered?' · +5 brain':'')+' · -1 wanted)',action:()=>{P.hp=Math.min(P.maxHp,P.hp+(powered?18:10));P.brain=Math.min(100,P.brain+(powered?5:0));P.wanted=Math.max(0,P.wanted-1);toast('the generator clicks.\nthe cot files no complaint.',2400);saveGame();}},
    {label:'sleep until morning. (+55 hp · +25 brain · +15 shakes)',action:()=>sleepAtOffice()},
    {label:'back to the office.',action:()=>openOffice()},
  ]);
}

export function sleepAtOffice(){
  const target=state.dayTime>0.3?1.3:0.3;state.dayTime=target;
  if(state.dayTime>=1){state.dayTime-=1;state.day++;P.lifetime.dayCount=state.day;rollWeather();resetDailyCounters();rollHustles();fireDayEvents();if(state.day>=7)unlockAchievement('tuesday_again');}
  const powered=!!(state.office&&state.office.upgrades.generator);
  P.hp=Math.min(P.maxHp,P.hp+55);P.brain=Math.min(100,P.brain+25+(powered?5:0));P.shakes=Math.min(100,P.shakes+15);P.wanted=Math.max(0,P.wanted-2);
  toast('you slept at the office.\nthe office opened before you did.\nthe day is the next day.',3200);saveGame();
}

export function rerollBlockRouteAtOffice(){
  const o=ensureOfficeState();if(!o.upgrades.route_board||o.rerollDay===state.day||activeOfficeContract())return false;
  o.rerollDay=state.day;const last=validBlockRoute(state.blockRoute)?state.blockRoute.lastStopId:'';rollBlockRoute(false,last);toast('the old sheet goes under the desk.\nit receives no payout.',2200);saveGame();return true;
}

export function hideoutOwned(kind) {
  if (!state.flags) return false;
  return kind === 'scrap' ? !!state.flags.scrapHideoutOwned : !!state.flags.momHideoutOwned;
}

export function tryEnterHideout() {
  for (const kind of ['scrap', 'mom']) {
    if (!hideoutOwned(kind)) continue;
    const d = HIDEOUT_DOORS[kind];
    const ddx = (P.x + P.w/2) - (d.x + d.w/2);
    const ddy = (P.y + P.h/2) - (d.y + d.h/2);
    if (ddx*ddx + ddy*ddy < 40*40) { openHideout(kind); return true; }
  }
  return false;
}

export function openHideout(kind) {
  const isMom = kind === 'mom';
  const title = isMom ? "MOM'S COUCH" : "THE SHED";
  const intro = isMom
    ? "the apartment is warm.\nben is at work.\nthe couch is cleared.\nyou recognize this couch."
    : "the shed smells like dust and old grease.\nthere is a chest in the corner.\nthere is a cot.\nthe door locks from the inside.";
  dialogue(title, intro, [
    { label: "open the chest. (stash survives death.)", action: () => openHideoutChest(kind) },
    { label: isMom ? "rest 30 minutes. (+12 hp · -1 wanted)" : "rest 30 minutes. (+8 hp · -1 wanted)",
      action: () => {
        P.hp = Math.min(P.maxHp, P.hp + (isMom ? 12 : 8));
        P.wanted = Math.max(0, P.wanted - 1);
        toast("you sit down.\nthe walls have nothing to say.\n" + (isMom ? '+ 12 hp · - 1 wanted' : '+ 8 hp · - 1 wanted'), 2800);
        saveGame();
      }
    },
    { label: "sleep until morning. advances a day.", action: () => {
      const target = state.dayTime > 0.3 ? 1.3 : 0.3;
      state.dayTime = target;
      if (state.dayTime >= 1) { state.dayTime -= 1; state.day++; P.lifetime.dayCount = state.day; rollWeather(); resetDailyCounters(); rollHustles(); fireDayEvents(); }
      P.hp = Math.min(P.maxHp, P.hp + (isMom ? 60 : 50));
      P.brain = Math.min(100, P.brain + (isMom ? 30 : 25));
      P.shakes = Math.min(100, P.shakes + 15);
      P.wanted = Math.max(0, P.wanted - 2);
      adjustFaction(isMom ? 'spiritual' : 'scrap', 1);
      toast("you slept.\nyou are still here.\nthe day is the next day.", 3000);
      saveGame();
    }},
    isMom ? { label: "use the apartment phone. (skip the next ambient call.)", action: () => {
      state.phoneT = 90000 + Math.random()*150000;
      toast("the phone goes back on the hook.\nben uses this phone.\nben is at work.", 2400);
    }} : null,
    { label: "leave.", action: () => {} },
  ].filter(Boolean));
}

export function openHideoutChest(kind) {
  // chest is shared across both hideouts (one stash). simpler + matches the "your stuff" mental model.
  if (!state.hideoutStash) state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
  const s = state.hideoutStash;
  dialogue("THE CHEST",
    "metal box. dented. heavy.\nin the chest:\n  rocks: " + s.rocks + "\n  pure copper: " + s.copper + "\n  cash: $" + s.cash + "\n  items: " + (s.items.length||0),
    [
      { label: P.rocks>0 ? "deposit 1 rock. (chest: " + s.rocks + ")" : "deposit a rock. (you have none.)",
        disabled: P.rocks<=0, action: () => { P.rocks--; s.rocks++; toast("- 1 rock · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.rocks>0 ? "withdraw 1 rock. (chest: " + s.rocks + ")" : "withdraw a rock. (chest empty.)",
        disabled: s.rocks<=0, action: () => { s.rocks--; P.rocks++; toast("← chest · + 1 rock", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.copper>0 ? "deposit 1 copper. (chest: " + s.copper + ")" : "deposit copper. (you have none.)",
        disabled: P.copper<=0, action: () => { P.copper--; s.copper++; toast("- 1 copper · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.copper>0 ? "withdraw 1 copper. (chest: " + s.copper + ")" : "withdraw copper. (chest empty.)",
        disabled: s.copper<=0, action: () => { s.copper--; P.copper++; toast("← chest · + 1 copper", 1400); saveGame(); openHideoutChest(kind); }},
      { label: P.cash>=10 ? "deposit $10. (chest: $" + s.cash + ")" : "deposit $10. (short.)",
        disabled: P.cash<10, action: () => { P.cash -= 10; s.cash += 10; toast("- $10 · → chest", 1400); saveGame(); openHideoutChest(kind); }},
      { label: s.cash>=10 ? "withdraw $10. (chest: $" + s.cash + ")" : "withdraw $10. (chest short.)",
        disabled: s.cash<10, action: () => { s.cash -= 10; P.cash += 10; toast("← chest · + $10", 1400); saveGame(); openHideoutChest(kind); }},
      { label: "close the chest.", action: () => kind==='office' ? openOffice() : openHideout(kind) },
    ]);
}

export function init_daily_hideouts() {
  // ---------- v13 wave 6.5 — daily counter reset ----------
  // called from updateWorld when state.day increments. iterates over the accumulating
  // "today" counters and zeros them. the per-day "*Day" counters (kombuchaAskDay etc)
  // self-reset via "=== state.day" comparison, so they don't need explicit reset.
  DAILY_COUNTER_KEYS = [
    'stripeFencedToday', // exploit 3a (stripe fence price ladder)
    'barbPacketsToday',  // exploit 3b (barb supply cap)
    'peteCashToday',     // audit (pete daily $200 cap)
    'heistsToday',       // audit (heist daily cap = 3)
  ];
  
  
  // ---------- v13 wave 7 — day-specific scripted events ----------
  // fire at most once per save, guarded by state.flags.dayNFired booleans.
  
  // re-spawn the bus driver on reload if day 30 fired but resolution didn't.
  
  
  
  
  
  
  
  
  
  
  
  
  // ---------- v13 wave 7 — hideouts ----------
  // scrap-yard hideout: door at (520, 200) — back corner of scrap yard, behind yuri.
  // mom's apartment hideout: door at (1230, 1180) — marketplace area, close to mom (mom is at ~1280,1180).
  // E within 40px while owned = openHideout(kind). interactive dialogue with chest, rest, sleep, leave.
  
  
  
  
  
  
  
  
  
  HIDEOUT_DOORS = {
    scrap: { x: 520, y: 200, w: 24, h: 32 },
    mom:   { x: 1230, y: 1180, w: 24, h: 32 },
  };
  
  
  
  
  
  
}

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
    action: () => {
      if ((P.soapRocks||0) > 0) {
        // soap rock — no rocked-up effect, no shakes relief, no cred. you knew.
        P.soapRocks--;
        P.lifetime.rocksSmoked++;
        audio.hurt(); audio.glassBreak();
        toast("you smoke it. it's soap.\nyou knew. you smoked it anyway.", 3600);
        feedPost("smoked soap. tasted it. did it again.", '@crackheadcent');
        unlockAchievement('soap_tongue');
        // intro chain still completes — the loop is the loop
        completeIntroSmoke();
        saveGame();
        return;
      }
      P.rocks--; P.rockedT = 18000; P.crashT = 0; P.shakes = Math.max(0, P.shakes-50);
      P.brain = Math.max(0, P.brain-4); P.lifetime.rocksSmoked++;
      P.cred += 1;
      let royalStatic=false;
      if(state.kingdom&&state.kingdom.stage==='anoint'){
        state.kingdom.stage='emperor_gate';state.kingdom.marks=0;royalStatic=true;syncKingdomQuests();
      }
      audio.rockUp();
      state.flash = 1; state.flashColor = 'rgba(232,192,64,.5)';
      toast(royalStatic
        ? '· ROYAL STATIC ·\nthe sun moves. the throne ditch answers.\nbrain -4. shakes -50. emperor available.'
        : '· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50.', royalStatic?4300:2500);
      feedPost("smoked a rock at the block. for the bit.", '@crackheadcent');
      if(royalStatic){broadcastNews('ROYAL STATIC RECEIVED. ONE DITCH ACKNOWLEDGES THE SIGNAL.');feedPost('the rock had a crown in the reception. the ditch is calling.','@blocklog');}
      applyRep({ street: 1, spiritual: -1 }); // wave 7 — smoking real rocks ledger
      // v13 wave 3 — completes the intro chain
      completeIntroSmoke();
      saveGame();
    }
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

export let MOVEMENT_KEYS, INPUT_RELEASE_HOOKS, titleLoadPending;

export async function loadFromTitle() {
  if(state.mode!=='title'||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    const ok=await loadGame();
    if(ok)startGame(true);else toast('no save.',1200);
  }finally{titleLoadPending=false;}
}

export async function continueAfterEnding(){
  if(state.mode!=='title'||!state.endingContinue||titleLoadPending)return;
  titleLoadPending=true;
  try{
    audio.init();
    if(state.endingSavePromise)await state.endingSavePromise;
    state.endingContinue=false;state.endingSavePromise=null;
    releaseAllInput();document.getElementById('title').classList.add('hide');state.mode='playing';
    toast('the block is still here.\nthe clipboard has another sheet.',2400);
  }finally{titleLoadPending=false;}
}

export function releaseAllInput() {
  state.keys.clear();
  state.stickX=0; state.stickY=0; state.stickMag=0;
  for(const release of INPUT_RELEASE_HOOKS)release();
  document.querySelectorAll('#mobile-ctrls .active').forEach(el=>el.classList.remove('active'));
}

export function init_keyboard() {
  // ---------- INPUT ----------
  // Physical movement keys are latched by keydown/keyup. Auto-repeat is deliberately not
  // used as a heartbeat: most operating systems repeat only the newest key in a chord.
  MOVEMENT_KEYS = new Set(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright','shift']);
  INPUT_RELEASE_HOOKS=[];
  titleLoadPending=false;
  
  
  window.addEventListener('keydown', async (e) => {
    const k = e.key.toLowerCase();
    // If a modal/focus safety path cleared a still-physical key, browser repeat may not
    // resurrect it. Releasing and pressing again creates the fresh non-repeat keydown.
    if (e.repeat && !state.keys.has(k) && MOVEMENT_KEYS.has(k)) {
      return;
    }
    // title screen
    if (state.mode === 'title') {
      if (k === ' ' || k === 'spacebar') { e.preventDefault(); audio.init(); if(state.endingContinue)await continueAfterEnding();else startGame(false); return; }
      if (k === 'l') { await loadFromTitle(); return; }
      return;
    }
    // global
    if (k === 'm') { audio.muted = !audio.muted; toast(audio.muted?'muted.':'unmuted.', 800); return; }
    if (k === 'escape') {
      if (state.mode === 'dialogue') closeDialogue();
      else if (state.mode === 'inv' || state.mode === 'quest') closePanel();
      else if (state.mode === 'cookmini') { e.preventDefault(); bailHeatMini(); }
      return;
    }
    // v13 wave 4 — heat minigame: SPACE / 1 locks the needle
    if (state.mode === 'cookmini') {
      if (k === ' ' || k === 'spacebar' || k === '1' || k === 'enter') {
        e.preventDefault();
        lockHeatMini();
      }
      return;
    }
    if (state.mode === 'dialogue') {
      // 1-9 select dialogue option
      const n = parseInt(k);
      if (n>=1 && n<=9 && activeDialogue && activeDialogue.opts[n-1]) {
        const o = activeDialogue.opts[n-1];
        if (!o.disabled) { audio.dialogue(); closeDialogue(); o.action && o.action(); }
      }
      return;
    }
    if (k === 'i') {
      if (state.mode==='inv') { closePanel(); }
      else if (state.mode==='quest') { closePanel(); state.mode='inv'; renderInventory(); }
      else { releaseAllInput(); state.mode='inv'; renderInventory(); }
      return;
    }
    if (k === 'q') {
      if (state.mode==='quest') { closePanel(); }
      else if (state.mode==='inv') { closePanel(); state.mode='quest'; renderQuests(); }
      else { releaseAllInput(); state.mode='quest'; renderQuests(); }
      return;
    }
    if (k === 'p') {
      phoneState.visible = !phoneState.visible;
      renderPhone();
      return;
    }
    // play mode keys
    if (state.mode !== 'playing') return;
    if (MOVEMENT_KEYS.has(k)) e.preventDefault();
    state.keys.add(k);
    // v13 wave 5 — stun gates all action inputs (SPACE attack, E interact). Movement is gated
    // in updateWorld; menu/inv/mute keys above still work so the player can pause/leave.
    if (P.stunT > 0) return;
    if (k === ' ' || k === 'spacebar') { e.preventDefault(); playerAttack(); }
    if (k === 'e') tryInteract();
    if (k === 'f') {
      if (state.tweakerCdT > 0 || P.brain <= 0) {
        if (P.brain <= 0) toast('your brain has nothing left to give.', 1500);
      } else if (state.tweakerT === 0) {
        state.tweakerT = 3000; state.tweakerCdT = 6000;
        // small cost on activation
        P.brain = Math.max(0, P.brain - 5);
      }
    }
  });
  window.addEventListener('keyup', (e) => {
    const k = e.key.toLowerCase();
    state.keys.delete(k);
  });
  
  // Focus loss is authoritative release evidence for both keyboard and analog input.
  
  window.addEventListener('blur', releaseAllInput);
  document.addEventListener('visibilitychange', () => { if (document.hidden) releaseAllInput(); });
  
  
}

export function startGame(loaded) {
  releaseAllInput();
  state.endingContinue=false;state.endingSavePromise=null;
  document.getElementById('title').classList.add('hide');
  if (!loaded) {
    // fresh save state
    state.cashPilesCollected = new Set();
    state.achievements = new Set();
    P.lifetime.routesCompleted = 0;
    P.lifetime.officeJobs = 0;
    P.lifetime.territoriesClaimed = 0;
    P.lifetime.pretendersDefeated = 0;
    state.blockRoute = null;
    state.office = freshOfficeState();
    state.districtClaims = Object.create(null);
    state.kingdom = freshKingdomState();
    state.kingdomBattle=null;state.bossActive=false;state.bossKind='';state.bossNPC=null;
    state.loadedNpcDeaths=null;
    state.counters = {
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0, pigeonTrade: 0,
      peteSold: 0, alleyKills: 0, dumpDives: 0, slept: 0,
      tacosEaten: 0, laundryDone: 0, bigPan: 0,
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0, introCashEarned: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      // v13 wave 6.5 — economy gates
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      // v13 wave 8a — philosopher daily spiritual gate
      philosopherRepDay: 0,
      gutterInventoryDay: 0,
    };
    Object.values(state.quests).forEach(q => { q.done = false; if (q.available === true) q.available = q.intro?undefined:false; });
    state.day = 1; state.dayTime = 0.35;
    state.weather = 'clear';
    state.combo = 0;
    P.equip = { shoes:null, hat:null, coat:null };
    P.cartMounted = false;
    P.hasPossum = false;
    state.hustles = null;
    // v13 wave 3 — fresh save state for discoverability + intro chain
    state.metVendors = new Set();
    state.flags = {
      introDone: false, momIntroFired: false, hasStripePackage: false,
      stripeBetrayed: false, daveHasCrossword: false, hasCrossword: false, crownSpotIdx: -1,
      // v13 wave 7 — day events + hideouts
      day3Fired: false, day7Fired: false, day14Fired: false, day30Fired: false,
      day14Collected: false, busTaken: false, busRefused: false,
      silenceUntilT: 0,
      scrapHideoutOwned: false, momHideoutOwned: false,
      momRentDay: 0, scrapLoanDay: 0, momProudCallDay: 0,
      // v13 wave 8a — fresh saves get the first-entry toasts as they discover the new zones.
      trainYardEntered: false, parkEntered: false, skidRowEntered: false, oldSchoolEntered: false,
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      trainHopperTalkedTo: false,
      priceGuyDay: 0, priceGuyVisits: 0,
      parkNightCashDay: 0,
      // v13 wave 8b — loved ambient + bus pass day-stamps
      lovedAmbient_street_day: 0, lovedAmbient_scrap_day: 0, lovedAmbient_spiritual_day: 0,
      busPassUsedDay: 0, momBusPassDay: 0,
      // v15 living-neighborhood incident history
      incidentDay: 0, incidentMask: 0, incidentsToday: 0, lastIncidentId: '',
    };
    // v13 wave 7 — faction reputation + hideout chest
    P.faction = { street: 0, scrap: 0, spiritual: 0 };
    state.hideoutStash = { rocks:0, copper:0, cash:0, items:[] };
    state.dayEventActor = null;
    state.crownPickup = null;
    state.momTipT = 30000; // ~30s into the new save
    // intro chain seeds
    if (state.quests.intro_remember) { state.quests.intro_remember.available = undefined; state.quests.intro_remember.done = false; }
    if (state.quests.intro_tony)     { state.quests.intro_tony.available = false; state.quests.intro_tony.done = false; }
    if (state.quests.intro_smoke)    { state.quests.intro_smoke.available = false; state.quests.intro_smoke.done = false; }
    // v13 wave 6 — fresh save state for map-depth pass
    state.flags.underpassEntered = false;
    state.flags.dumpsterPropaneAwarded = false;
    state.flags.churchLoadedDumpsterX = 0;
    state.flags.churchLoadedDumpsterY = 0;
    if (state.quests.scrap_dog) { state.quests.scrap_dog.state = 'idle'; state.quests.scrap_dog.done = false; state.quests.scrap_dog.available = false; }
    state.graffiti = null; // build a fresh layout
    state.posters = null;  // v13 wave 8b — fresh poster layout on new save
    state.publicPhoneT = 240000 + Math.random()*240000;
    state.phonePropRingT = 0;
    state.publicPhoneAnswered = 0;
    state.freedDogT = 0;
    state.freedDogFollowT = 0;
    state.freedDogFirstReturn = false;
    // new save starts broke. find the ten dollars.
    P.cash = 0;
    P.charisma = 0;
    P.barbAside = false;
    state.barbAside = false;
  }
  spawnNpcs();
  if(state.loadedNpcDeaths instanceof Set){
    for(const n of runtime.npcs)if(state.loadedNpcDeaths.has(n.id))n.dead=true;
    state.loadedNpcDeaths=null;
  }
  spawnCashPiles();
  initInteractiveProps();
  // v13 wave 6 — build (or re-use persisted) graffiti layout
  buildGraffiti();
  // v13 wave 8b — build (or re-use persisted) wall poster layout
  buildPosters();
  applyEquipStats();
  if (!loaded || !Array.isArray(state.hustles)) rollHustles();
  ensureBlockRoute();
  ensureOfficeState();
  syncOfficeDay();
  maybeUnlockOfficeQuest();
  updateOfficeMilestones();
  ensureKingdomState();
  maybeUnlockKingdom(true,false);
  syncKingdomQuests();
  syncKingdomForces();
  // v13 wave 7 — re-spawn bus driver if day 30 fired but bus unresolved
  rehydrateDay30Bus();
  state.mode = 'playing';
  // v13 wave 3 — different first-toast for the intro
  if (!loaded && state.flags && !state.flags.introDone) {
    toast("you wake up on the sidewalk.\nyour mouth tastes like a battery.\nyou do not remember.\n(Q to see what's next.)", 4200);
  } else {
    toast('you wake up on the sidewalk.\nyour mouth tastes like a battery.\n(Q to see today\'s hustles.)', 3500);
  }
  // initial feed posts
  feedPost("woke up.\nstill in the neighborhood.\nfeels like a tuesday.", '@crackheadcent');
  feedPost("good morning. tony has not blinked.", '@tony_observer');
  broadcastNews("good evening. " + RANKS[P.rank].name + " is once again at large.");
}

export function init_start() {
  // ---------- START ----------
  
  
  
}

export function init_boot() {
  // ---------- INIT ----------
  buildSprites();
  buildEnvironmentSprites();
  buildLandmarkFacades();
  buildLightSprites();
  buildFogSheet();
  updateHUD();
  rotateNews();
  setInterval(rotateNews, 50000);
  // CRT power-on auto-dismiss
  setTimeout(() => { const p = document.getElementById('poweron'); if (p) p.classList.add('gone'); }, 800);
  
  
}

export let loadBtnEl, titleLoadTap;

export function setupMobile() {
  // detect touch
  const isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
  if (!isTouch && window.innerWidth > 820) return;
  state.touchMode = true;
  document.getElementById('mobile-ctrls').style.display = 'block';
  const fireKey = (key, down) => {
    const ev = new KeyboardEvent(down ? 'keydown' : 'keyup', { key });
    window.dispatchEvent(ev);
  };
  // D-pad replaced in v11 by analog joystick — see below
  document.querySelectorAll('#mobile-ctrls .ab').forEach(el => {
    const key = el.dataset.key;
    let pressed = false;
    const press = (e) => {
      if (pressed) return;
      pressed = true;
      e.preventDefault();
      el.classList.add('active');
      fireKey(key, true);
      if (e.pointerId !== undefined && el.setPointerCapture) {
        try { el.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const release = (e) => {
      if (!pressed) return;
      pressed = false;
      if (e && e.preventDefault) e.preventDefault();
      el.classList.remove('active');
      fireKey(key, false);
    };
    el.addEventListener('pointerdown', press);
    el.addEventListener('pointerup', release);
    el.addEventListener('pointercancel', release);
    el.addEventListener('lostpointercapture', release);
    el.addEventListener('touchstart', press, {passive:false});
    el.addEventListener('touchend', release, {passive:false});
    el.addEventListener('touchcancel', release, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{pressed=false;el.classList.remove('active');});
  });

  // ---------- ANALOG JOYSTICK ----------
  const stick = document.getElementById('stick');
  const nub = document.getElementById('stickNub');
  if (stick && nub) {
    let activePointer = null;
    let cx = 0, cy = 0; // stick center in screen coords
    const RADIUS = 42;
    const DEAD_ZONE = 0.18;
    const setVector = (dx, dy) => {
      // distance ratio
      const mag = Math.sqrt(dx*dx + dy*dy);
      const norm = Math.min(1, mag / RADIUS);
      const nx = norm > 0.001 ? dx/mag : 0;
      const ny = norm > 0.001 ? dy/mag : 0;
      // store on state for updateWorld to consume
      if (norm < DEAD_ZONE) {
        state.stickX = 0; state.stickY = 0; state.stickMag = 0;
      } else {
        state.stickX = nx;
        state.stickY = ny;
        state.stickMag = norm;
      }
      // visual position of nub
      const clampedMag = Math.min(mag, RADIUS);
      const px = norm > 0.001 ? (dx/mag) * clampedMag : 0;
      const py = norm > 0.001 ? (dy/mag) * clampedMag : 0;
      nub.style.transform = `translate(calc(-50% + ${px}px), calc(-50% + ${py}px))`;
    };
    const onDown = (e) => {
      if (activePointer !== null) return;
      e.preventDefault();
      activePointer = e.pointerId !== undefined ? e.pointerId : 1;
      const rect = stick.getBoundingClientRect();
      cx = rect.left + rect.width/2;
      cy = rect.top + rect.height/2;
      stick.classList.add('dragging');
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
      if (e.pointerId !== undefined && stick.setPointerCapture) {
        try { stick.setPointerCapture(e.pointerId); } catch(_){}
      }
    };
    const onMove = (e) => {
      if (activePointer === null) return;
      // for pointer events, check id; for touch, take first
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      e.preventDefault();
      const x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX);
      const y = (e.clientY !== undefined ? e.clientY : e.touches[0].clientY);
      setVector(x - cx, y - cy);
    };
    const onUp = (e) => {
      if (activePointer === null) return;
      if (e.pointerId !== undefined && e.pointerId !== activePointer) return;
      activePointer = null;
      stick.classList.remove('dragging');
      setVector(0, 0);
    };
    stick.addEventListener('pointerdown', onDown);
    stick.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    stick.addEventListener('pointercancel', onUp);
    // touch fallback
    stick.addEventListener('touchstart', onDown, {passive:false});
    stick.addEventListener('touchmove', onMove, {passive:false});
    stick.addEventListener('touchend', onUp, {passive:false});
    stick.addEventListener('touchcancel', onUp, {passive:false});
    INPUT_RELEASE_HOOKS.push(()=>{
      activePointer=null;
      stick.classList.remove('dragging');
      setVector(0,0);
    });
  }
  // top bar (single tap toggles)
  document.querySelectorAll('#mobile-ctrls .topbar .mb').forEach(el => {
    const key = el.dataset.key;
    const tap = (e) => {
      e.preventDefault();
      el.classList.add('active');
      setTimeout(() => el.classList.remove('active'), 120);
      fireKey(key, true);
      setTimeout(() => fireKey(key, false), 30);
    };
    el.addEventListener('touchstart', tap, {passive:false});
    el.addEventListener('click', tap);
  });
  // title tap = start
  document.getElementById('title').addEventListener('touchstart', (e) => {
    e.preventDefault();
    if (state.mode === 'title') {
      audio.init();
      if(state.endingContinue)continueAfterEnding();else startGame(false);
    }
  }, {passive:false});
  // prevent canvas touch from scrolling
  document.getElementById('game').addEventListener('touchstart', e => e.preventDefault(), {passive:false});
  // v13 wave 4 — tap anywhere on canvas to lock during the heat minigame
  const onCookTap = (e) => {
    if (state.mode !== 'cookmini') return;
    e.preventDefault();
    lockHeatMini();
  };
  document.getElementById('game').addEventListener('pointerdown', onCookTap);
  document.getElementById('game').addEventListener('touchstart', onCookTap, {passive:false});
  // global block double-tap zoom
  document.addEventListener('gesturestart', e => e.preventDefault());
  document.addEventListener('dblclick', e => e.preventDefault());
}

export function init_mobile() {
  // ---------- MOBILE TOUCH CONTROLS ----------
  
  setupMobile();
  
  // The visible load receipt is a real touch/click target, not keyboard-only decoration.
  loadBtnEl=document.getElementById('loadBtn');
  titleLoadTap=(e)=>{
    e.preventDefault();e.stopPropagation();
    loadFromTitle();
  };
  loadBtnEl.addEventListener('pointerdown',titleLoadTap);
  loadBtnEl.addEventListener('touchstart',titleLoadTap,{passive:false});
  loadBtnEl.addEventListener('click',titleLoadTap);
  
  // detect existing save for title screen; storage absence must not break a double-clicked build.
  (async () => {
    try{
      const s = await window.storage.get(SAVE_KEY);
      if (s && s.value) loadBtnEl.style.display = 'block';
    }catch(_){ /* volatile play still works when the host provides no storage adapter */ }
  })();
  
  requestAnimationFrame(update);
  
  // local QA accessor (data/functions remain inside the single-file closure)
  window._rb = {
    P, state,
    get npcs() { return runtime.npcs; },
    get sprites() { return SPRITE_CACHE; },
    get pals() { return PALS; },
    get routeStops() { return ROUTE_STOPS; },
    startGame, updateWorld, drawAll, startIncident, updateActiveIncident,
    validBlockRoute, rollBlockRoute, ensureBlockRoute, tryStampBlockRoute, routePatchTier, hustleProgress,
    currentPrimaryObjective, resolveNpcPose, renderQuests, saveGame, loadGame,
    endingScreen, takeTheBus, continueAfterEnding,
  };
  
}
