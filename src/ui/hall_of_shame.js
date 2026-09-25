/* Hall of Shame UI — renders the leaderboard panel */
import { hallCache } from '../systems/hall_of_shame.js';
import { getHall, clearHall, hasTokenConfig, getTokenMint } from '../systems/hall_of_shame.js';
import { panelEl, hideGuidance, toast, state, audio } from '../core/runtime_ui.js';
import { releaseAllInput } from '../input/keyboard.js';

let hallPanelOpen = false;

export function renderHallOfShame() {
  hideGuidance();
  releaseAllInput();
  hallPanelOpen = true;

  const hall = getHall();
  const best = [
    { key: 'mostRocksSmoked', label: 'most rocks smoked' },
    { key: 'highestCred', label: 'highest cred' },
    { key: 'longestSurvival', label: 'longest run (day)' },
    { key: 'mostCopperStripped', label: 'most copper stripped' },
    { key: 'mostRoutesFiled', label: 'most routes filed' },
    { key: 'mostBossKills', label: 'bosses killed' },
  ];
  const worst = [
    { key: 'mostDeaths', label: 'most deaths' },
    { key: 'mostArrests', label: 'most arrests' },
    { key: 'mostSoapSmoked', label: 'most soap smoked' },
    { key: 'highestShakesPeak', label: 'highest shakes peak' },
    { key: 'mostMoneyLostToCops', label: 'most $ lost to cops' },
    { key: 'longestCrashStreak', label: 'longest crash streak' },
    { key: 'mostTimesDogPet', label: 'most times dog pet' },
    { key: 'mostCrownAttempts', label: 'most crown attempts' },
    { key: 'mostPotholeArgumentsLost', label: 'most pothole arguments lost' },
  ];

  function row(item, isBest) {
    const v = hall[item.key] || { value: 0, saveId: '', day: 0 };
    const prefix = isBest ? '♦' : '☠';
    const saveInfo = v.saveId ? ` (${v.saveId}, day ${v.day})` : '';
    return `<div class="row"><span>${prefix} ${item.label}</span><span style="color:${isBest ? '#7fa055' : '#a0554a'}">${v.value}${saveInfo}</span></div>`;
  }

  panelEl.innerHTML = `
    <h2>HALL OF SHAME</h2>
    <div class="sec">BEST CRACKHEAD</div>
    ${best.map(b => row(b, true)).join('')}
    <div class="sec" style="margin-top:10px">WORST CRACKHEAD</div>
    ${worst.map(w => row(w, false)).join('')}
    <div class="close" style="margin-top:14px">
      <div class="opt" onclick="window.__HALL_CLEAR__()">clear record.</div>
      <div class="opt" onclick="window.__HALL_CLOSE__()">leave.</div>
    </div>
  `;

  panelEl.classList.add('show');

  // Expose handlers globally for onclick
  window.__HALL_CLEAR__ = () => {
    clearHall();
    panelEl.classList.remove('show');
    hallPanelOpen = false;
    delete window.__HALL_CLEAR__;
    delete window.__HALL_CLOSE__;
  };
  window.__HALL_CLOSE__ = () => {
    panelEl.classList.remove('show');
    hallPanelOpen = false;
    delete window.__HALL_CLEAR__;
    delete window.__HALL_CLOSE__;
  };
}

export function isHallOpen() {
  return hallPanelOpen;
}

export function closeHall() {
  if (hallPanelOpen) {
    panelEl.classList.remove('show');
    hallPanelOpen = false;
    delete window.__HALL_CLEAR__;
    delete window.__HALL_CLOSE__;
  }
}