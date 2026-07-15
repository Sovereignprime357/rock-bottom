/* Generated from frozen rock_bottom_v19.html.
 * Source seams: cache and HUD boot sequence.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { buildEnvironmentSprites } from '../render/canvas_geography.js';
import { buildFogSheet, buildLandmarkFacades, buildLightSprites } from '../render/landmarks_a.js';
import { buildSprites } from '../render/sprites.js';
import { rotateNews } from '../systems/communications.js';
import { updateHUD } from '../ui/hud.js';

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
