/* Generated from frozen rock_bottom_v19.html.
 * Source seams: keyboard controls | game start and new-game initialization | cache and HUD boot sequence | mobile controls and final startup.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { SAVE_KEY, audio, loadGame, saveGame } from './core/audio_save.js';
import { P, activeDialogue, applyEquipStats, closeDialogue, closePanel, dialogue, renderInventory, renderQuests, runtime, state, toast } from './core/runtime_ui.js';
import { update, updateWorld } from './core/update.js';
import { spawnCashPiles, spawnNpcs } from './data/npc_spawns.js';
import { initInteractiveProps } from './data/props.js';
import { RANKS } from './data/world.js';
import { bailHeatMini, lockHeatMini } from './minigames/heat.js';
import { resolveNpcPose } from './render/actors_weather.js';
import { buildEnvironmentSprites } from './render/canvas_geography.js';
import { drawAll } from './render/frame.js';
import { buildFogSheet, buildLandmarkFacades, buildLightSprites } from './render/landmarks_a.js';
import { PALS, SPRITE_CACHE, buildSprites } from './render/sprites.js';
import { buildGraffiti, buildPosters } from './render/structures.js';
import { currentPrimaryObjective, ensureKingdomState, ensureOfficeState, freshKingdomState, freshOfficeState, maybeUnlockKingdom, maybeUnlockOfficeQuest, syncKingdomForces, syncKingdomQuests, syncOfficeDay, updateOfficeMilestones } from './systems/campaigns.js';
import { playerAttack } from './systems/combat.js';
import { broadcastNews, feedPost, phoneState, renderPhone, rotateNews } from './systems/communications.js';
import { rehydrateDay30Bus, takeTheBus } from './systems/daily_hideouts.js';
import { startIncident, updateActiveIncident } from './systems/incidents.js';
import { endingScreen, tryInteract } from './systems/interactions.js';
import { ROUTE_STOPS, ensureBlockRoute, hustleProgress, rollBlockRoute, rollHustles, routePatchTier, tryStampBlockRoute, validBlockRoute } from './systems/progression_routes.js';
import { updateHUD } from './ui/hud.js';

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
