/* Generated from frozen rock_bottom_v19.html.
 * Source seams: daily systems and hideouts.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { saveGame } from '../core/audio_save.js';
import { P, dialogue, rollWeather, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { last, updateWorld } from '../core/update.js';
import { VENDOR_INDEX_META } from '../data/catalogs.js';
import { WORLD } from '../data/world.js';
import { CLAIM_SITES, CLAIM_SITE_BY_ID, OFFICE_DOOR, OFFICE_UPGRADE_DEFS, activeOfficeContract, cancelDistrictClaim, claimFileCost, claimGateReason, claimedDistrictIds, ensureOfficeState, fileDistrictClaim, fileOfficeWork, freshOfficeState, maybeUnlockKingdom, officeDailyCap, officeOwned, openKingdomLedger, purchaseOfficeUpgrade, selectDistrictClaim, startOfficeWork, syncKingdomForces, syncKingdomQuests, syncOfficeDay, updateOfficeMilestones } from './campaigns.js';
import { feedPost } from './communications.js';
import { adjustFaction } from './factions.js';
import { rollBlockRoute, rollHustles, validBlockRoute } from './progression_routes.js';

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
