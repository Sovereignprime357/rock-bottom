import { P, state } from '../core/runtime_ui.js';
import { RANKS } from '../data/world.js';
import { resolvePresentationLayout } from './layout.js';
import { hasTokenConfig, getTokenMint, getTokenSymbol } from '../systems/hall_of_shame.js';

let priceTickerTimer = null;
let lastPriceData = null;

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

async function fetchTokenPrice() {
  if (!hasTokenConfig()) return;
  try {
    const mint = getTokenMint();
    const symbol = getTokenSymbol();
    const res = await fetch(`https://frontend-api.pump.fun/api/coin/${mint}`);
    if (!res.ok) throw new Error('API error');
    const data = await res.json();
    lastPriceData = {
      price: data.price || 0,
      marketCap: data.market_cap || data.usd_market_cap || 0,
      liquidity: data.liquidity || data.virtual_sol_reserves || 0,
      symbol,
    };
    renderPriceTicker();
  } catch (_) {
    // silent fail, keep last data
  }
}

function renderPriceTicker() {
  const el = document.getElementById('priceTicker');
  if (!el) return;
  if (!lastPriceData || !hasTokenConfig()) {
    el.style.display = 'none';
    return;
  }
  el.style.display = 'block';
  const p = lastPriceData.price;
  const mc = lastPriceData.marketCap;
  const liq = lastPriceData.liquidity;
  const sym = lastPriceData.symbol;
  el.textContent = `${sym}  $${p.toFixed(8)}  |  MC $${(mc/1000).toFixed(1)}K  |  LIQ ${liq.toFixed(0)} SOL`;
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
  renderPriceTicker();
}

export function init_hud() {
  // ---------- HUD ----------
  syncPresentationLayout();
  window.addEventListener('resize',syncPresentationLayout);

  // Price ticker poll
  if (hasTokenConfig()) {
    fetchTokenPrice(); // initial
    priceTickerTimer = setInterval(fetchTokenPrice, 30000);
  }
}
