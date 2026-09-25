/* Hall of Shame — local leaderboard across all saves
 * Tracks best/worst stats in IndexedDB via window.storage
 * Zero backend, zero wallet, pure local.
 */
import { P, state, toast } from '../core/runtime_ui.js';
import { saveGame } from '../core/audio_save.js';
import { TOKEN_CONFIG } from '../config/token.js';

const HALL_KEY = 'rockbottom_hall_of_shame';
const SAVE_ID_KEY = 'rockbottom_save_id_counter';

let hallCache = null;
let saveIdCounter = 0;

// ---------- Default Hall Structure ----------
function freshHall() {
  return {
    // Best (higher = better)
    mostRocksSmoked: { value: 0, saveId: '', day: 0 },
    highestCred: { value: 0, saveId: '', day: 0 },
    longestSurvival: { value: 0, saveId: '', day: 0 },
    mostCopperStripped: { value: 0, saveId: '', day: 0 },
    mostRoutesFiled: { value: 0, saveId: '', day: 0 },
    mostBossKills: { value: 0, saveId: '', day: 0 },

    // Worst (higher = worse)
    mostDeaths: { value: 0, saveId: '', day: 0 },
    mostArrests: { value: 0, saveId: '', day: 0 },
    mostSoapSmoked: { value: 0, saveId: '', day: 0 },
    highestShakesPeak: { value: 0, saveId: '', day: 0 },
    mostMoneyLostToCops: { value: 0, saveId: '', day: 0 },
    longestCrashStreak: { value: 0, saveId: '', day: 0 },
    mostTimesDogPet: { value: 0, saveId: '', day: 0 },
    mostCrownAttempts: { value: 0, saveId: '', day: 0 },
    mostPotholeArgumentsLost: { value: 0, saveId: '', day: 0 },

    // Internal
    _crashStreak: 0, // current consecutive crashes without smoking
  };
}

// ---------- Storage ----------
async function loadHall() {
  try {
    const res = await window.storage.get(HALL_KEY);
    if (res && res.value) {
      hallCache = Object.assign(freshHall(), res.value);
    } else {
      hallCache = freshHall();
    }
  } catch (_) {
    hallCache = freshHall();
  }
}

async function saveHall() {
  if (!hallCache) return;
  try {
    await window.storage.set(HALL_KEY, hallCache);
  } catch (_) {}
}

async function loadSaveIdCounter() {
  try {
    const res = await window.storage.get(SAVE_ID_KEY);
    saveIdCounter = (res && res.value) || 0;
  } catch (_) {
    saveIdCounter = 0;
  }
}

async function saveSaveIdCounter() {
  try {
    await window.storage.set(SAVE_ID_KEY, saveIdCounter);
  } catch (_) {}
}

// ---------- Save ID Management ----------
export async function getOrAssignSaveId(player) {
  if (player.saveId) return player.saveId;

  saveIdCounter++;
  player.saveId = `save_${saveIdCounter}`;
  await saveSaveIdCounter();
  await saveGame(); // persist saveId to player save
  return player.saveId;
}

// ---------- Record Evaluation ----------
function updateRecord(hall, key, value, saveId, day, higherIsBetter = true) {
  const current = hall[key];
  if (!current) return;

  const beats = higherIsBetter ? value > current.value : value < current.value;
  if (beats || (value === current.value && day > current.day)) {
    current.value = value;
    current.saveId = saveId;
    current.day = day;
    return true;
  }
  return false;
}

export function evaluateBestStats(saveId, day) {
  if (!hallCache) return;

  const bossKills = [
    state.flags?.omalleyFallenDead,
    state.flags?.brutusOlderKilled,
    state.quests?.fallen_king?.done,
  ].filter(Boolean).length;

  updateRecord(hallCache, 'mostRocksSmoked', P.lifetime?.rocksSmoked || 0, saveId, day);
  updateRecord(hallCache, 'highestCred', P.cred || 0, saveId, day);
  updateRecord(hallCache, 'longestSurvival', day, saveId, day);
  updateRecord(hallCache, 'mostCopperStripped', state.counters?.copperStripped || 0, saveId, day);
  updateRecord(hallCache, 'mostRoutesFiled', P.lifetime?.routesCompleted || 0, saveId, day);
  updateRecord(hallCache, 'mostBossKills', bossKills, saveId, day);

  saveHall();
}

export function onDeath() {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;

  hallCache.mostDeaths.value++;
  hallCache.mostDeaths.saveId = saveId;
  hallCache.mostDeaths.day = day;

  updateRecord(hallCache, 'highestShakesPeak', P.shakes || 0, saveId, day);
  updateRecord(hallCache, 'longestSurvival', day, saveId, day);

  // Crash streak continues on death (didn't smoke to break it)
  hallCache._crashStreak++;
  updateRecord(hallCache, 'longestCrashStreak', hallCache._crashStreak, saveId, day);

  saveHall();
}

export function onArrest(lostCash) {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;

  hallCache.mostArrests.value++;
  hallCache.mostArrests.saveId = saveId;
  hallCache.mostArrests.day = day;

  hallCache.mostMoneyLostToCops.value += lostCash || 0;
  hallCache.mostMoneyLostToCops.saveId = saveId;
  hallCache.mostMoneyLostToCops.day = day;

  // Arrest resets crash streak (forced withdrawal)
  hallCache._crashStreak = 0;

  saveHall();
}

export function onSmokeRock(isSoap) {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;

  if (isSoap) {
    hallCache.mostSoapSmoked.value++;
    hallCache.mostSoapSmoked.saveId = saveId;
    hallCache.mostSoapSmoked.day = day;
  } else {
    updateRecord(hallCache, 'mostRocksSmoked', P.lifetime?.rocksSmoked || 0, saveId, day);
    // Smoking a real rock breaks crash streak
    hallCache._crashStreak = 0;
  }

  saveHall();
}

export function onCrash() {
  if (!hallCache) return;
  hallCache._crashStreak++;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;
  updateRecord(hallCache, 'longestCrashStreak', hallCache._crashStreak, saveId, day);
  saveHall();
}

export function onDogPet() {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;
  hallCache.mostTimesDogPet.value++;
  hallCache.mostTimesDogPet.saveId = saveId;
  hallCache.mostTimesDogPet.day = day;
  saveHall();
}

export function onCrownAttempt() {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;
  hallCache.mostCrownAttempts.value++;
  hallCache.mostCrownAttempts.saveId = saveId;
  hallCache.mostCrownAttempts.day = day;
  saveHall();
}

export function onPotholeLoss() {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;
  hallCache.mostPotholeArgumentsLost.value++;
  hallCache.mostPotholeArgumentsLost.saveId = saveId;
  hallCache.mostPotholeArgumentsLost.day = day;
  saveHall();
}

export function onShakesUpdate(shakes) {
  if (!hallCache) return;
  const saveId = P.saveId || 'unknown';
  const day = state.day || 0;
  updateRecord(hallCache, 'highestShakesPeak', shakes, saveId, day);
}

// ---------- Clear Hall ----------
export async function clearHall() {
  hallCache = freshHall();
  await saveHall();
  toast('the neighborhood forgets.\\nall records wiped.', 2500);
}

// ---------- Getters ----------
export function getHall() {
  return hallCache ? { ...hallCache } : freshHall();
}

export function hasTokenConfig() {
  return TOKEN_CONFIG.mint && TOKEN_CONFIG.mint.length > 0;
}

export function getTokenMint() {
  return TOKEN_CONFIG.mint;
}

export function getTokenSymbol() {
  return TOKEN_CONFIG.symbol;
}

// ---------- Init ----------
export async function init_hall_of_shame() {
  await loadHall();
  await loadSaveIdCounter();

  // Assign saveId to current player if not set
  if (!P.saveId) {
    await getOrAssignSaveId(P);
  }
}