/* Generated from frozen rock_bottom_v19.html.
 * Source seams: HUD.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, state } from '../core/runtime_ui.js';
import { RANKS } from '../data/world.js';
import { resolvePresentationLayout } from './layout.js';

export function syncPresentationLayout() {
  const stage=document.getElementById('stage'),hud=document.getElementById('hud');
  if(!stage||!hud)return;
  const mobileChrome=typeof window.matchMedia === 'function' && window.matchMedia('(pointer: coarse)').matches;
  const layout=resolvePresentationLayout(stage.clientWidth,stage.clientHeight,mobileChrome);
  hud.style.left=layout.hud.x+'px';hud.style.right=layout.hud.right+'px';
  hud.style.top=layout.hud.y+'px';hud.style.fontSize=layout.hud.fontSize+'px';hud.style.gap=layout.hud.gap+'px';
  stage.classList.toggle('hud-compact',layout.hud.compact);
  const topbar=document.querySelector('#mobile-ctrls .topbar'),ticker=document.getElementById('ticker');
  if(topbar)topbar.style.width=layout.topbar.w+'px';
  if(ticker)ticker.style.right=layout.ticker.right+'px';
}

export function updateHUD() {
  const hearts = Math.max(0, Math.ceil(P.hp/20));
  document.getElementById('hp').textContent = '♥'.repeat(hearts) + '♡'.repeat(5-hearts);
  document.getElementById('cash').textContent = P.cash;
  // v13 wave 4 — soap rocks look like real rocks in the HUD count. truth is in the smoke.
  document.getElementById('rocks').textContent = (P.rocks||0) + (P.soapRocks||0);
  document.getElementById('copper').textContent = P.copper;
  document.getElementById('supplies').textContent = P.supplies || 0;
  document.getElementById('shakeBar').style.width = P.shakes + '%';
  document.getElementById('brainBar').style.width = P.brain + '%';
  const filed=(P.lifetime&&P.lifetime.routesCompleted)||0;
  document.getElementById('rankName').textContent = RANKS[P.rank].name + (P.rank>=RANKS.length-1?' · term '+(1+Math.floor(filed/5)):'');
  document.getElementById('cred').textContent = P.cred;
  document.getElementById('wanted').textContent = '★'.repeat(P.wanted);
  // hustle micro-indicator in time-of-day line
  const h = state.hustles || [];
  const hdone = h.filter(x=>x.done).length;
  const ht = state.dayTime;
  const phase = ht<0.2?'night':ht<0.3?'dawn':ht<0.7?'day':ht<0.8?'dusk':'night';
  const tEl = document.getElementById('timeOfDay');
  if (tEl) tEl.textContent = `day ${state.day} · ${phase} · ${state.weather} · 🏷 ${hdone}/${h.length}`;
}

export function init_hud() {
  // ---------- HUD ----------
  syncPresentationLayout();
  window.addEventListener('resize',syncPresentationLayout);
  
  
}
