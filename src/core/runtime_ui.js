/* Generated from frozen rock_bottom_v19.html.
 * Source seams: world state and status UI.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from './audio_save.js';
import { EQUIPMENT, VENDOR_FLOATER_IDS, VENDOR_INDEX_META, vendorPrice } from '../data/catalogs.js';
import { RANKS } from '../data/world.js';
import { WEAPONS, last, officeUpgradeCount, panhandle, releaseAllInput, resetDailyCounters, startGame } from '../legacy.js';
import { CLAIM_SITES, CLAIM_SITE_BY_ID, OFFICE_UPGRADE_DEFS, bitCount3, claimedDistrictIds, currentPrimaryObjective, freshKingdomState, freshOfficeState, hideGuidance, kingdomStageClan, officeDailyCap } from '../systems/campaigns.js';
import { FACTION_TIER_LABELS, factionTier } from '../systems/factions.js';
import { ACHIEVEMENTS, ROUTE_STOP_BY_ID, hustleProgress, validBlockRoute } from '../systems/progression_routes.js';

export let P, particles, state, toastEl, toastTimer, dialogueEl, activeDialogue, panelEl;

export const runtime = Object.create(null);

export function unlockAchievement(id) {
  if (state.achievements.has(id)) return;
  if (!ACHIEVEMENTS[id]) return;
  state.achievements.add(id);
  toast('· ACHIEVEMENT ·\n'+ACHIEVEMENTS[id].name, 3000);
  audio.rankUp();
  saveGame();
}

export function applyEquipStats() {
  let baseSpeed = 2.2;
  let baseHp = P.cartMounted ? 110 : 100;
  let credBonus = 0;
  let charisma = 0;
  let wantedDecayMult = 1.0;
  for (const slot in P.equip) {
    const id = P.equip[slot];
    if (!id || !EQUIPMENT[id]) continue;
    const e = EQUIPMENT[id];
    baseSpeed += (e.speed||0);
    baseHp += (e.hp||0);
    credBonus += (e.cred||0);
    charisma += (e.charisma||0);
    wantedDecayMult += (e.wantedDecay||0);
  }
  // v13 wave 8b — cart speed cap. Was +0.6 flat (v12 was +1, ~2.0 base). Now caps at base × 1.7
  // so the cart scales with the (now larger) world without breaking equipment stacking.
  if (P.cartMounted) baseSpeed = Math.min(baseSpeed * 1.7, baseSpeed + 1.5);
  P.speed = Math.max(0.8, baseSpeed);
  P.maxHp = baseHp;
  if (P.hp > P.maxHp) P.hp = P.maxHp;
  P.credBonus = credBonus;
  P.charisma = charisma;
  // v13 wave 5 — priest's collar shaves time off the wanted decay clock.
  P.wantedDecayMult = wantedDecayMult;
}

export function rollWeather() {
  const r = Math.random();
  if (r < 0.65) state.weather = 'clear';
  else if (r < 0.88) state.weather = 'rain';
  else state.weather = 'fog';
}

export function toast(msg, ms=2200) {
  toastEl.textContent = msg;
  toastEl.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.remove('show'), ms);
}

export function dialogue(name, text, opts) {
  hideGuidance();
  activeDialogue = { name, text, opts };
  releaseAllInput(); // release keyboard + analog movement when dialogue opens
  dialogueEl.innerHTML = `<div class="name">${name}</div><div class="text">${text}</div><div class="opts"></div>`;
  const optsBox = dialogueEl.querySelector('.opts');
  opts.forEach((o, i) => {
    const div = document.createElement('div');
    div.className = 'opt' + (o.disabled ? ' disabled' : '');
    div.innerHTML = `<b>${i+1}.</b> ${o.label}`;
    div.onclick = () => { if (!o.disabled) { audio.dialogue(); closeDialogue(); o.action && o.action(); } };
    optsBox.appendChild(div);
  });
  dialogueEl.classList.add('show');
  state.mode = 'dialogue';
}

export function closeDialogue() {
  activeDialogue = null;
  dialogueEl.classList.remove('show');
  releaseAllInput(); // and clear on close so no ghost movement
  if (state.mode === 'dialogue') state.mode = 'playing';
}

export function renderInventory() {
  hideGuidance();
  const r = RANKS[P.rank];
  const lt = P.lifetime;
  const eq = P.equip;
  const slotLabel = (slot) => {
    const id = eq[slot];
    if (!id || !EQUIPMENT[id]) return '<span style="color:#665">(none)</span>';
    return EQUIPMENT[id].n;
  };
  const achList = Object.entries(ACHIEVEMENTS).map(([k,a]) => {
    const got = state.achievements.has(k);
    return `<div class="row" style="${got?'':'opacity:.35'}"><span>${got?'✓':'·'} ${a.name}</span><span style="color:#776;font-size:9px">${a.flav}</span></div>`;
  }).join('');
  panelEl.innerHTML = `
    <h2>INVENTORY · ${r.name.toUpperCase()}</h2>
    <div class="row"><span>cash</span><span>$${P.cash}</span></div>
    <div class="row"><span>rocks</span><span>🪨 ${(P.rocks||0) + (P.soapRocks||0)}</span></div>
    <div class="row"><span>pure copper</span><span>🪙 ${P.copper}</span></div>
    <div class="row"><span>raw supplies</span><span>🧪 ${P.supplies||0}${(P.dirtySupplies||0)>0 ? ` (${P.dirtySupplies} house cut)` : ''}</span></div>
    <div class="row"><span>hp</span><span>${Math.round(P.hp)} / ${P.maxHp}</span></div>
    <div class="row"><span>shakes</span><span>${P.shakes.toFixed(0)}</span></div>
    <div class="row"><span>brain</span><span>${P.brain.toFixed(0)}</span></div>
    <div class="row"><span>cred</span><span>${P.cred}${P.credBonus?` (+${P.credBonus})`:''}</span></div>
    <div class="row"><span>wanted</span><span>${'★'.repeat(P.wanted)||'-'}</span></div>
    <div class="row"><span>cart</span><span>${P.cartMounted?'mounted':'-'}</span></div>
    <div class="sec">EQUIPMENT</div>
    <div class="row"><span>weapon</span><span>${WEAPONS[P.weapon||'fists'].n}</span></div>
    <div class="row"><span>hat</span><span>${slotLabel('hat')}</span></div>
    <div class="row"><span>coat</span><span>${slotLabel('coat')}</span></div>
    <div class="row"><span>shoes</span><span>${slotLabel('shoes')}</span></div>
    <div class="row"><span>tool</span><span>${slotLabel('tool')}</span></div>
    <div class="sec">ITEMS</div>
    ${P.inventory.length ? P.inventory.map(i=>`<div class="row"><span>${i.n}</span><span>x${i.q||1}</span></div>`).join('') : '<div class="row"><span>nothing</span><span>(yet)</span></div>'}
    <div class="sec">LIFETIME</div>
    <div class="row"><span>rocks smoked</span><span>${lt.rocksSmoked||0}</span></div>
    <div class="row"><span>rocks cooked</span><span>${lt.rocksCooked||0}</span></div>
    <div class="row"><span>rocks fenced</span><span>${lt.rocksFenced||0}</span></div>
    <div class="row"><span>block routes filed</span><span>${lt.routesCompleted||0}</span></div>
    <div class="row"><span>office orders filed</span><span>${lt.officeJobs||0}</span></div>
    <div class="row"><span>districts entered</span><span>${lt.territoriesClaimed||0}/${CLAIM_SITES.length}</span></div>
    <div class="row"><span>cops killed</span><span>${lt.copsKilled||0}</span></div>
    <div class="row"><span>arrests</span><span>${lt.arrests||0}</span></div>
    <div class="row"><span>day</span><span>${state.day}</span></div>
    <div class="row"><span>weather</span><span>${state.weather}</span></div>
    <div class="sec">CURSED ACCOLADES · ${state.achievements.size}/${Object.keys(ACHIEVEMENTS).length}</div>
    ${achList}
    <div class="close">[ i / esc ] close</div>`;
  panelEl.classList.add('show');
}

export function renderQuests() {
  hideGuidance();
  const qs = Object.values(state.quests);
  // a quest is ACTIVE if (a) not done, AND (b) either no `available` field or available===true,
  // AND (c) not an undone intro that depends on a prior intro step still incomplete.
  const isActive = (q) => !q.done && (q.available === undefined || q.available === true);
  const isAvailableButLatent = (q) => !q.done && q.available === false;
  const introFocused=state.flags&&!state.flags.introDone;
  const visibleDuringIntro=q=>!introFocused||!!q.intro;
  const active   = qs.filter(q=>isActive(q)&&visibleDuringIntro(q));
  const latent   = qs.filter(q=>isAvailableButLatent(q)&&visibleDuringIntro(q));
  const done     = qs.filter(q=>q.done&&visibleDuringIntro(q));
  const hustles  = state.hustles || [];
  // reward preview map — purely cosmetic, mirrors the in-line rewards in the actual handlers.
  const QUEST_REWARDS = {
    intro_remember:  '+1 cred',
    intro_tony:      '+1 cred',
    intro_smoke:     '+2 cred',
    pigeon_crown:    'the crown (cursed hat)',
    stripe_package:  '$40 + 3 cred OR a brick. depends.',
    barb_crossword:  '+ 1 clean packet',
    first_rock:      '—',
    copper_sings:    '—',
    finisher:        '—',
    conductor:       '—',
    priest_mercy:    '—',
    fallen_king:     'the corner',
    office_space:    'one office key',
    paper_empire:    'one bent sign · zoning error entered',
    regional_office: 'a larger administrative problem',
    all_business:    'all eleven forms agree with themselves',
    hostile_correspondence:'one hostile frequency',
    blue_weather:    '$24 + 18 cred · one bent seal',
    cart_appeal:     '$30 + 22 cred · one longer receipt',
    copper_mass:     '$36 + 26 cred · b flat entered',
    royal_static:    'the throne ditch answers',
    one_cracklord:   '$60 + 40 cred · one folding chair',
  };
  const renderQ = (q, key) => {
    const r = QUEST_REWARDS[key] || '—';
    return `<div class="quest ${q.done?'done':''}">
      <div class="qtitle">${q.done?'✓ ':'· '}${q.title}</div>
      <div class="qflav">${q.flav}${q.done?'':`\n<span style="color:#776">reward: ${r}</span>`}</div>
    </div>`;
  };
  // build people-met list (uses the canonical VENDOR_INDEX_META — only met vendors appear)
  const metKeys = Array.from(state.metVendors || []);
  const peopleHtml = metKeys.length === 0
    ? '<div class="quest"><div class="qflav" style="color:#776">no one yet. walk.</div></div>'
    : metKeys
        .filter(k => VENDOR_INDEX_META[k])
        .map(k => {
          const m = VENDOR_INDEX_META[k];
          const nm = (npcs.find(n=>n.id===k)||{}).name || k.toUpperCase();
          return `<div class="quest">
            <div class="qtitle">${nm}</div>
            <div class="qflav">${m.zone}\n<span style="color:#776">${m.tag}</span></div>
          </div>`;
        }).join('');
  // pair quest keys back so renderQ can pick the right reward
  const qPairs = Object.entries(state.quests);
  const activePairs = qPairs.filter(([_,q]) => isActive(q)&&visibleDuringIntro(q));
  const latentPairs = qPairs.filter(([_,q]) => isAvailableButLatent(q)&&visibleDuringIntro(q));
  const donePairs   = qPairs.filter(([_,q]) => q.done&&visibleDuringIntro(q));
  // v13 wave 7 — faction reputation block. tier label + bar (rep ∈ [-50, +50])
  const factionRow = (key) => {
    const v = (P.faction && P.faction[key]) | 0;
    const tier = factionTier(v);
    const pct = Math.max(0, Math.min(100, ((v + 50) / 100) * 100));
    const color = (tier === 'liked' || tier === 'loved') ? '#7fa055'
                : (tier === 'hated') ? '#a0554a'
                : '#776';
    return `<div class="quest" style="padding:6px 10px">
      <div class="qtitle" style="display:flex;justify-content:space-between">
        <span>${key.toUpperCase()}</span>
        <span style="color:${color}">${FACTION_TIER_LABELS[tier]} · ${v>=0?'+':''}${v}</span>
      </div>
      <div style="margin-top:4px;height:5px;background:#1a1a18;border:1px solid #2a2a26;position:relative">
        <div style="position:absolute;left:50%;top:0;bottom:0;width:1px;background:#3a3a34"></div>
        <div style="position:absolute;top:0;bottom:0;left:${v<0?pct:50}%;width:${Math.abs(pct-50)}%;background:${color};opacity:.7"></div>
      </div>
    </div>`;
  };
  const factionHtml = `
    <h2>FACTIONS</h2>
    ${factionRow('street')}
    ${factionRow('scrap')}
    ${factionRow('spiritual')}
    <div style="color:#776;font-size:11px;padding:0 10px 6px 10px">hated · neutral · liked · loved</div>
  `;
  const now=currentPrimaryObjective();
  const route=validBlockRoute(state.blockRoute)?state.blockRoute:null;
  const routeHtml=route?route.stops.map((id,i)=>{const s=ROUTE_STOP_BY_ID[id];return `<div class="quest ${i<route.cursor?'done':''}">
      <div class="qtitle">${i<route.cursor?'✓':'·'} ${i+1}. ${s.task}</div><div class="qflav">${s.zone}${i===route.cursor?' · NOW':''}</div></div>`;}).join('')
    : '<div class="quest"><div class="qflav">finish the first loop. the clipboard is under a brick.</div></div>';
  const office=state.office||freshOfficeState(),claimIds=claimedDistrictIds(),officeUnlocked=office.owned||(state.quests.office_space&&state.quests.office_space.available===true);
  const officeWorkToday=office.workDay===state.day?(office.workToday||0):0;
  const activePaper=office.claimJob
    ? 'claim · '+CLAIM_SITE_BY_ID[office.claimJob.id].name.toLowerCase()+' · '+office.claimJob.stage
    : office.workJob?'order '+office.workJob.serial+' · '+CLAIM_SITE_BY_ID[office.workJob.id].name.toLowerCase()+' · '+office.workJob.stage
    : 'none accepted';
  const officeHtml=office.owned?`<div class="quest">
      <div class="qtitle">OWNED · ${claimIds.length}/${CLAIM_SITES.length} DISTRICTS · ${officeUpgradeCount()}/${OFFICE_UPGRADE_DEFS.length} UPGRADES</div>
      <div class="qflav">active: ${activePaper}\norders: ${officeWorkToday}/${officeDailyCap()} today · ${office.jobsCompleted||0} lifetime</div>
    </div>
    <div class="quest"><div class="qflav">${CLAIM_SITES.map(d=>(state.districtClaims&&state.districtClaims[d.id]?'✓ ':'· ')+d.name.toLowerCase()).join(' · ')}</div></div>`
    :`<div class="quest"><div class="qtitle">${officeUnlocked?'THE LEASING GUY HAS A KEY':'LOCKED · FILE 3 BLOCK ROUTES'}</div>
      <div class="qflav">routes ${(P.lifetime.routesCompleted||0)}/3 · the lot · $40 + 1 pure copper</div></div>`;
  const kingdom=state.kingdom||freshKingdomState(),kingdomClan=kingdomStageClan(kingdom.stage);
  const kingdomSeals=(kingdom.defeats||[]).filter(id=>id!=='curb_emperor').length;
  const kingdomReq=`${state.quests.fallen_king&&state.quests.fallen_king.done?'✓':'·'} fallen king · ${office.owned?'✓':'·'} office · ${claimIds.length>=4?'✓':'·'} claims ${Math.min(4,claimIds.length)}/4`;
  const kingdomHtml=kingdom.stage==='locked'
    ? `<div class="quest"><div class="qtitle">LOCKED · LOCAL THRONE UNSETTLED</div><div class="qflav">${kingdomReq}</div></div>`
    : `<div class="quest"><div class="qtitle">${kingdom.stage==='complete'?'ONE CRACKLORD · CHAIR OCCUPIED':'ACTIVE · '+kingdom.stage.replaceAll('_',' ').toUpperCase()}</div>
       <div class="qflav">seals ${kingdomSeals}/3 · ${kingdomClan?'corrections '+bitCount3(kingdom.marks)+'/3 · ':''}pretenders ${(kingdom.pretendersDefeated||0)}</div></div>
       <div class="quest"><div class="qflav">${state.flags.blueTarpCleared?'✓':'·'} blue tarp court · ${state.flags.cartKeepCleared?'✓':'·'} cart cavalry keep · ${state.flags.copperChoirCleared?'✓':'·'} copper choir yard · ${state.flags.throneDitchCleared?'✓':'·'} throne ditch</div></div>`;
  const activities=[
    ['score · smoke · sleep · cook','dealer corner -> milk crate'],
    ['strip · sell · pawn · equip junk','abandoned building · scrap yard · pawn'],
    ['fight · dodge · cart-roadkill','alleys · projects · old school'],
    ['dumpster dive · kick cans · break bottles','everywhere with poor supervision'],
    ['panhandle · tacos · laundry · karaoke','marketplace · food truck · laundromat'],
    ['phone calls · prophecies · secrets','scrap phone · possum · pigeon'],
    ['faction work · hideouts · bus routes','street · scrap · spiritual'],
    ['benches · night cash · train waiting','park · train yard'],
    ['office upgrades · district claims · work orders','the lot · far east'],
    ['curb corrections · rival courts · daily pretenders','four kingdoms made of municipal leftovers'],
  ];
  const controlRows=state.touchMode
    ? `<div class="row"><span>move</span><span>drag the left stick</span></div>
       <div class="row"><span>hit / bother / squint</span><span>A HIT / B BOTHER / F SQUINT</span></div>
       <div class="row"><span>pockets / bad ideas</span><span>INV / QST</span></div>
       <div class="row"><span>feed / mute</span><span>FEED / MUTE</span></div>`
    : `<div class="row"><span>move / run</span><span>wasd or arrows / shift</span></div>
       <div class="row"><span>hit / bother</span><span>space / e</span></div>
       <div class="row"><span>pockets / bad ideas</span><span>i / q</span></div>
       <div class="row"><span>squint wrong / feed / mute</span><span>f / p / m</span></div>`;
  panelEl.innerHTML = `
    <h2>WHAT TO PRESS</h2>
    ${controlRows}

    <h2 style="margin-top:14px">NOW</h2>
    <div class="quest"><div class="qtitle">${now.text}</div><div class="qflav">the neighborhood has selected one thing.</div></div>

    <h2 style="margin-top:14px">BLOCK ROUTE ${route?'· '+route.serial:''} · FILED ${(P.lifetime&&P.lifetime.routesCompleted)||0}</h2>
    ${routeHtml}

    <h2 style="margin-top:14px">THE OFFICE</h2>
    ${officeHtml}

    <h2 style="margin-top:14px">CURB WAR</h2>
    ${kingdomHtml}

    <h2 style="margin-top:14px">TODAY'S HUSTLES · DAY ${state.day}</h2>
    ${hustles.length ? hustles.map(h => `<div class="quest ${h.done?'done':''}">
      <div class="qtitle">${h.done?'✓ ':'· '}${h.desc} <span style="float:right;color:#776">${hustleProgress(h)}</span></div>
      <div class="qflav">reward: ${Object.entries(h.reward).map(([k,v])=>'+'+v+' '+k).join(' · ')}</div>
    </div>`).join('') : '<div class="quest"><div class="qflav">no hustles today.</div></div>'}

    <h2 style="margin-top:14px">QUESTS · ACTIVE · ${active.length}</h2>
    ${activePairs.length ? activePairs.map(([k,q])=>renderQ(q,k)).join('') : '<div class="quest"><div class="qflav" style="color:#776">none active.</div></div>'}

    ${latentPairs.length ? `<h2 style="margin-top:14px">QUESTS · AVAILABLE · ${latent.length}</h2>
    ${latentPairs.map(([k,q])=>renderQ(q,k)).join('')}` : ''}

    ${donePairs.length ? `<h2 style="margin-top:14px;opacity:.6">QUESTS · DONE · ${done.length}</h2>
    <div style="opacity:.55">${donePairs.map(([k,q])=>renderQ(q,k)).join('')}</div>` : ''}

    <div style="margin-top:18px">${factionHtml}</div>

    <h2 style="margin-top:18px">WAYS TO WASTE TUESDAY</h2>
    ${activities.map(a=>`<div class="row"><span>${a[0]}</span><span style="color:#776">${a[1]}</span></div>`).join('')}

    <h2 style="margin-top:18px">PEOPLE YOU'VE MET · ${metKeys.length}/${VENDOR_FLOATER_IDS.size}</h2>
    ${peopleHtml}

    <div class="close">[ q / esc ] close</div>`;
  panelEl.classList.add('show');
}

export function closePanel() {
  panelEl.classList.remove('show');
  releaseAllInput();
  if (state.mode === 'inv' || state.mode === 'quest') state.mode = 'playing';
}

export function init_runtime_ui() {
  // ---------- world state ----------
  P = {
    x: 1050, y: 840, w: 24, h: 28,
    facing: 'down', frame: 0, frameT: 0,
    vx: 0, vy: 0, speed: 2.2,
    hp: 100, maxHp: 100,
    cash: 25, rocks: 0, copper: 0, supplies: 0, dirtySupplies: 0,
    shakes: 20, cred: 0, brain: 70,
    wanted: 0, wantedT: 0, rank: 0,
    attackCd: 0, attacking: 0, hitFlash: 0, iframes: 0,
    rockedT: 0, crashT: 0,
    inventory: [], lifetime: { rocksSmoked: 0, copsKilled: 0, arrests: 0, dayCount: 0, rocksCooked: 0, rocksFenced: 0, routesCompleted: 0, officeJobs: 0, territoriesClaimed: 0, pretendersDefeated: 0 },
    tonyOffenses: 0,
    cartMounted: false,
    equip: { shoes:null, hat:null, coat:null, tool:null },
    weapon: 'fists',
    brutusDefeated: 0,    // counter for Brutus Older trigger
    stripeLoyalty: 0,     // counter for co-op ending
    // v13 wave 3 — charisma is summed from equipment (see applyEquipStats).
    // 1+ trips the vendor 10% discount via vendorPrice().
    charisma: 0,
    // v13 wave 4 — soap rocks tracked as a parallel FIFO counter to P.rocks.
    // smoked first; produce no rocked-up effect; trigger SOAP_TONGUE.
    soapRocks: 0,
    // v13 wave 5 — combat-pattern status timers.
    // stunT: lurch's grab freezes input for 500ms. slowT: priest holy water = ×0.5 speed for 1500ms.
    stunT: 0, slowT: 0,
    // v13 wave 7 — faction reputation. tiers via factionTier(). default 0 = neutral.
    faction: { street: 0, scrap: 0, spiritual: 0 },
  };
  
  // Grant achievement helper
  
  
  // Equipment stat application — recompute derived stats
  
  
  // Weather selection per day
  
  
  runtime.npcs = [];
  particles = [];
  runtime.cashPiles = [];
  // v13 wave 5 — combat depth: generic projectile primitive. {x,y,vx,vy,dmg,slowMs,kind,from,life,rot,rotVel}
  runtime.projectiles = [];
  state = {
    mode: 'title',                       // title | playing | dialogue | inv | quest | heist | boss | tweakerVision
    bossActive: false, bossPhase: 0, bossKind: '',
    bossNPC: null,
    kingdomBattle: null,
    loadedNpcDeaths: null,
    cam: { x: 0, y: 0 },
    keys: new Set(),
    toastT: 0,
    shake: 0,
    tweakerT: 0, tweakerCdT: 0,
    day: 1, dayTime: 0,
    weather: 'clear',                    // clear | rain | fog
    rainT: 0,
    flash: 0, flashColor: '#fff',
    combo: 0, comboT: 0,
    hitPause: 0,
    carEngineT: 0,
    conductorWaitT: 0,
    // v15 living-neighborhood scenes. Active actors are ephemeral; daily history lives in flags.
    incident: null,
    incidentT: 35000 + Math.random()*20000,
    incidentPaperT: 0,
    incidentWetT: 0,
    blockRoute: null,
    office: freshOfficeState(),
    districtClaims: Object.create(null),
    kingdom: freshKingdomState(),
    primaryObjective: null,
    guidanceT: 0,
    touchMode: false,
    // v13 wave 4 — heat minigame state. heat=null when not active.
    heat: null,
    smokeT: 0,
    quests: {
      // v13 wave 3 — "the day you arrived" intro chain (auto-given on new save, suppresses normal world until done)
      intro_remember:{ title: "I DON'T REMEMBER",        done: false, intro: true, flav: 'find ten dollars somewhere on the block.' },
      intro_tony:    { title: 'THE MAN AT THE CORNER',  done: false, intro: true, available: false, flav: 'the man at the corner has a job for you. go see him.' },
      intro_smoke:   { title: 'YOU SMOKE THE ROCK',     done: false, intro: true, available: false, flav: 'the crate is for sitting. the rock is for smoking.' },
      first_rock:    { title: 'THE FIRST ROCK',         done: false, flav: 'buy a rock from tre bag tony. that is the entire quest.' },
      copper_sings:  { title: 'THE COPPER SINGS',       done: false, flav: 'strip copper from the abandoned building. in b flat.' },
      finisher:      { title: 'THE FINISHER',           done: false, flav: 'cook a rock on the crate. the crate is the kitchen now.' },
      conductor:     { title: "THE CONDUCTOR'S BARGAIN", done: false, flav: 'sell 3 pure copper to the conductor. he is still waiting.' },
      priest_mercy:  { title: "THE PRIEST'S MERCY",     done: false, flav: "accept a blessed tic-tac. let father o'malley help." },
      fallen_king:   { title: 'THE FALLEN KING',        done: false, flav: 'defeat tre bag tony at the corner. take what you can.' },
      // v13 wave 3 — standalone side quests, offered by NPCs after repeat visits.
      pigeon_crown:  { title: "THE PIGEON KING'S LOST CROWN", done: false, available: false, flav: "find the crown. the pigeons grieve." },
      stripe_package:{ title: "STRIPE'S PACKAGE",       done: false, available: false, flav: "take the package to the conductor. don't open it." },
      barb_crossword:{ title: "BARB'S MISSING CROSSWORD",done: false, available: false, flav: "find the saturday crossword. she is unwell without it." },
      // v13 wave 5 — fallen priest. opens via phone call (rank ≥3 + church visits ≥3) OR auto if you steal the plate enough.
      fallen_priest:{ title: "THE FALLEN PRIEST",        done: false, available: false, flav: "the priest has been wrong for a while. someone should say so." },
      // v13 wave 6 — the chained scrap-yard dog. opens on first close approach. branches: fed | freed | left.
      scrap_dog:    { title: "THE SCRAP YARD DOG",       done: false, available: false, state: 'idle', flav: "the dog. brown. matted. he blinks at you twice." },
      // v18 headquarters and paper-authority campaign.
      office_space: { title: "THE OFFICE",                done: false, available: false, flav: "the leasing guy has one unit. the unit has four walls and a smell." },
      paper_empire: { title: "PAPER EMPIRE",              done: false, available: false, flav: "put one bent sign where no one asked. file it in the desk." },
      regional_office:{title:"REGIONAL OFFICE",            done: false, available: false, flav: "enter four districts in pen. pencil has been rejected." },
      all_business: { title: "ALL BUSINESS",              done: false, available: false, flav: "enter every claimable district. the neighborhood will not acknowledge this." },
      // v19 curb-war campaign. Sequential receipts; the neighborhood remains open afterward.
      hostile_correspondence:{title:"HOSTILE CORRESPONDENCE",done:false,available:false,flav:"the office received a kingdom notice. postage is due."},
      blue_weather:{title:"BLUE WEATHER",done:false,available:false,flav:"serve three corrections on blue tarp court. weather is named as counsel."},
      cart_appeal:{title:"CART APPEAL",done:false,available:false,flav:"appeal the cavalry. retain the receipt. retain everything."},
      copper_mass:{title:"COPPER MASS",done:false,available:false,flav:"enter the choir register. the note is b flat. again."},
      royal_static:{title:"ROYAL STATIC",done:false,available:false,flav:"smoke one real rock at the block. the crown has poor reception."},
      one_cracklord:{title:"ONE CRACKLORD",done:false,available:false,flav:"one curb. one ruler. one folding chair."},
    },
    cashPilesCollected: new Set(),
    achievements: new Set(),
    // analog joystick input
    stickX: 0, stickY: 0, stickMag: 0,
    counters: {
      possumProphecies: 0, brutusDeaths: 0, churchDonations: 0,
      rocksBought: 0, copperStripped: 0, pauliCompliments: 0,
      plateStolen: 0, stripeBetrayed: 0,
      pinkyFirstBuy: 0, mathInteractions: 0, brendanFirstKill: 0,
      // v13 wave 3 — dialogue-visit counts to gate side-quest offers
      pigeonVisits: 0, stripeVisits: 0, barbVisits: 0,
      // intro_remember tracks cash earned during day 1
      introCashEarned: 0,
      // v13 wave 5 — fallen-priest side quest tracking
      priestVisits: 0, plateStealAttempts: 0, churchVisits: 0,
      omalleyFallenSurviveT: 0,
      // v13 wave 6.5 — economy gate counters.
      // *Day fields hold the day-stamp of last use (self-reset via === state.day).
      // *Today fields accumulate counts and reset at dawn via resetDailyCounters().
      kombuchaAskDay: 0, kombuchaComplimentDay: 0,
      priestDonateDay: 0, lurchDollarDay: 0, sherriSpiderDay: 0, paulieFaceDay: 0,
      stripeFencedToday: 0, barbPacketsToday: 0, peteCashToday: 0, heistsToday: 0,
      gutterInventoryDay: 0,
    },
    barbAside: false,
    // v13 wave 3 — discoverability + quest-state additions
    metVendors: new Set(),
    flags: {
      introDone: true,            // existing saves default-on; new saves set false in startGame
      momIntroFired: false,
      hasStripePackage: false,
      stripeBetrayed: false,
      daveHasCrossword: false,
      hasCrossword: false,
      crownSpotIdx: -1,
      // v13 wave 4 — propane torch acquisition tracking
      peteTorchStocked: false,    // flipped true once rank>=3 (pete stocks one)
      peteTorchSold: false,       // flipped true on the buy (one and done)
      // v13 wave 5 — fallen priest flags
      omalleyFallen: false,       // priest has transformed (any path)
      omalleyFallenDead: false,   // mini-boss defeated, collar awarded
      fallenPriestCallFired: false, // unknown-number phone call fired (quest hook)
      // v13 wave 6 — map-depth pass
      underpassEntered: false,    // first-entry echo line + feed post fires once per save
      warehouseRowEntered: false, canalEntered: false, theLotEntered: false,
      blueTarpCourtEntered:false, cartKeepEntered:false, copperChoirEntered:false, throneDitchEntered:false,
      blueTarpCleared:false, cartKeepCleared:false, copperChoirCleared:false, throneDitchCleared:false,
      dumpsterPropaneAwarded: false, // dumpster propane rare drop is one-and-done globally
      churchLoadedDumpsterX: 0,   // when the phone "tell pinky" line fires, plant a $50 pile here
      churchLoadedDumpsterY: 0,
      petePropaneTorchOption: false, // (legacy alias — not used; reserved for future)
    },
    crownPickup: null,            // {x, y, collected} — only present while pigeon_crown quest active
    // v13 wave 6 — graffiti tags placed once per save and persisted (replaces ephemeral GRAFFITI cache).
    graffiti: null,
    // v13 wave 6 — public phone ring timer + active-ring window
    publicPhoneT: 240000 + Math.random()*240000, // 4-8min initial
    phonePropRingT: 0,                            // counts up during the 30s answer window
    publicPhoneAnswered: 0,                        // counter for PHONE_BOOTH_PROPHET
    // v13 wave 6 — wandering freed-dog cooldown (state.quests.scrap_dog.state==='freed')
    freedDogT: 0,                                  // ms until next possible reappearance
    freedDogFollowT: 0,                            // ms remaining of current follow window
    freedDogFirstReturn: false,                    // toast-once on first reappear
  };
  
  // ---------- dialogue / toast helpers ----------
  toastEl = document.getElementById('toast');
  toastTimer = null;
  
  
  dialogueEl = document.getElementById('dialogue');
  activeDialogue = null;
  
  
  
  // ---------- panel (inventory + quest) ----------
  panelEl = document.getElementById('panel');
  
  
  
  
  
}
