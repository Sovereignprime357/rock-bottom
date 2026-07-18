/* Generated from frozen rock_bottom_v19.html.
 * Source seams: cook and heat minigame.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, closeDialogue, dialogue, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { clamp } from '../data/npc_spawns.js';
import { H, W } from '../data/world.js';
import { ctx } from '../render/canvas_geography.js';
import { questToast } from '../systems/combat.js';
import { feedPost } from '../systems/communications.js';

export let COOK_MODES;

export function hasPropane() { return P.equip && P.equip.tool === 'propane_torch'; }

// v22 wave 5.5 — ownership vs. carrying. hasPropane() gates USE (the cook mode
// needs the torch in hand); ownsTool() gates ACQUISITION (a tool at pete's glass
// is still yours, so drops and vendors must not issue a duplicate — a second
// torch would overwrite the locker and destroy a tool).
export function ownsTool(id) {
  return (P.equip && P.equip.tool === id) || (state.flags && state.flags.peteToolLocker === id);
}

export function cookBatchMenu() {
  const have = P.supplies || 0;
  const dirty = Math.min(P.dirtySupplies||0, have);
  const dirtyLine = dirty > 0 ? `\n${dirty} of them are pinky's house cut. (dirty first.)` : '';
  // predictor — 1 short flavor line tailored to current brain/rocked/dirty state.
  const brain = P.brain;
  const rocked = P.rockedT > 0;
  const predictor = pickHeatPredictor(brain, rocked, dirty);
  const torch = hasPropane();
  const opts = [
    { label: have>=1 ? "low and slow. (1 packet, safe.)" : "you have no packets.", disabled: have<1, action: () => startHeatMini(1, 'slow') },
    { label: have>=3 ? "fast cook. (3 packets, risky.)" : "fast cook (need 3 packets.)", disabled: have<3, action: () => startHeatMini(3, 'fast') },
    { label: have>=1 && P.shakes >= 60 ? "shaky hands special. (1 packet, all-or-nothing.)" : (P.shakes<60 ? "shakes too steady for the special." : "need a packet."), disabled: have<1 || P.shakes<60, action: () => startHeatMini(1, 'shakes') },
    { label: have>=5 ? `cook all (${have} packets).` : `cook all (need 5+ packets.)`, disabled: have<5, action: () => startHeatMini(have, 'all') },
  ];
  if (torch) {
    opts.push({
      label: have>=1 ? "propane. (1 packet. tight bar. big yield.)" : "propane. (need a packet.)",
      disabled: have<1,
      action: () => startHeatMini(1, 'propane')
    });
  }
  opts.push({ label: "leave.", action: () => {} });
  const torchLine = torch
    ? `\npropane. you bought it. or you found it. it doesn't care.`
    : '';
  dialogue('THE CRATE (KITCHEN)',
    `you have ${have} packet${have===1?'':'s'}.${dirtyLine}\nthe crate is a kitchen now.\nbrain: ${Math.round(P.brain)} · shakes: ${Math.round(P.shakes)}.\n${predictor}${torchLine}`,
    opts);
}

export function pickHeatPredictor(brain, rocked, dirty) {
  // up to 6 contextual flavor lines, never more than one
  if (rocked && dirty > 0)                return "rocked + dirty → good luck.";
  if (rocked)                             return "rocked → hands aren't yours. the bar shrinks.";
  if (brain >= 70 && dirty === 0)         return "sober + clean → wider sweet spot.";
  if (brain >= 70 && dirty > 0)           return "sober. but pinky in the bag. the cut argues with the math.";
  if (brain <= 30 && dirty > 0)           return "zonked + dirty → the smoke writes its own ending.";
  if (brain <= 30)                        return "zonked → narrow window. read the needle.";
  if (dirty > 0)                          return "dirty packets first. soap is louder.";
  return "the heat is the heat. the needle is the needle.";
}

export function startHeatMini(n, mode) {
  // close any active dialogue first (cookBatchMenu opened one)
  closeDialogue();
  const cfg = COOK_MODES[mode] || COOK_MODES.slow;
  // sweet-spot width math: base + brain mod, rocked penalty, floor 0.05 ceil 0.40
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  let width = cfg.baseWidth + bb * 0.10;
  if (P.rockedT > 0) width -= 0.06;
  width = clamp(width, 0.05, 0.40);
  // sweet-spot center: base ± random spread, clamped so it never sits on the edges
  const center = clamp(cfg.sweetCenter + (Math.random()*2 - 1) * cfg.sweetSpread, 0.10, 0.95);
  state.heat = {
    active: true,
    mode, n,
    fillMs: cfg.fillMs,
    burnZone: cfg.burnZone,
    sweetCenter: center,
    sweetHalf: width / 2,
    progress: 0,           // current needle position 0..1
    t: 0,                  // elapsed ms
    phase: 'fill',         // fill -> hold -> resolve
    lockedAt: null,
    outcome: null,
    holdT: 0,              // 600ms reveal hold after lock
    idleAfterFill: 1000,   // 1s grace after bar fully fills, then auto-burn
  };
  state.mode = 'cookmini';
  // brief chiptune cue so the player knows the minigame started
  if (audio && audio.dialogue) audio.dialogue();
}

export function updateHeatMini(dt) {
  const h = state.heat;
  if (!h || !h.active) return;
  if (h.phase === 'fill') {
    h.t += dt;
    h.progress = Math.min(1, h.t / h.fillMs);
    if (h.progress >= 1) {
      h.phase = 'idle';   // bar is full; auto-burn after idleAfterFill ms
    }
  } else if (h.phase === 'idle') {
    h.idleAfterFill -= dt;
    if (h.idleAfterFill <= 0) {
      // no input — auto-burn at the top of the bar
      h.lockedAt = 1.0;
      lockHeatMini();
    }
  } else if (h.phase === 'hold') {
    h.holdT -= dt;
    if (h.holdT <= 0) finalizeHeatMini();
  }
}

export function lockHeatMini() {
  const h = state.heat;
  if (!h || !h.active || (h.phase !== 'fill' && h.phase !== 'idle')) return;
  if (h.lockedAt === null) h.lockedAt = clamp(h.progress, 0, 1);
  h.phase = 'hold';
  h.holdT = 600;
  h.outcome = resolveHeatOutcome(h);
  // ledger cue per outcome — keep them short, no melodies
  if (h.outcome === 'perfect') audio.coin();
  else if (h.outcome === 'ok') audio.pickup();
  else if (h.outcome === 'burn') audio.hurt();
  else audio.glassBreak();
}

export function bailHeatMini() {
  const h = state.heat;
  if (!h || !h.active) return;
  // supplies still consumed — you walked away
  const n = h.n;
  const dirtyUsed = Math.min(n, P.dirtySupplies||0);
  P.supplies = Math.max(0, (P.supplies||0) - n);
  P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
  state.heat = null;
  state.mode = 'playing';
  toast("you walked away.\nthe supplies don't walk back.", 2800);
  feedPost("walked away from a half-cooked batch. the crate is patient.", '@blocklog');
  saveGame();
}

export function resolveHeatOutcome(h) {
  const x = h.lockedAt;
  const center = h.sweetCenter;
  const halfW = h.sweetHalf;
  const d = Math.abs(x - center);
  // pre-emptive lock (under 25%) = undercook regardless of distance
  if (x < 0.25 && d > halfW) return 'undercook';
  // burn-black: top of the bar (mode-dependent)
  if (x >= 1.0 - h.burnZone) return 'burn';
  if (d <= halfW)            return 'perfect';
  if (d <= halfW * 1.8)      return 'ok';
  if (d <= halfW * 3.0)      return 'bad';
  // far miss — too cold = undercook, otherwise small chance of soap-rock, else bad
  if (x < 0.20)              return 'undercook';
  if (Math.random() < 0.15)  return 'soaprock';
  return 'bad';
}

export function finalizeHeatMini() {
  const h = state.heat;
  if (!h) return;
  state.heat = null;
  state.mode = 'playing';
  applyCookOutcome(h.n, h.mode, h.outcome);
}

export function applyCookOutcome(n, mode, outcome) {
  // bb math — preserved from v12/v13.
  let bb = clamp((P.brain - 30) / 70, -0.4, 0.6);
  if (P.rockedT > 0) bb -= 0.25;
  const dirtyUsed = Math.min(n, P.dirtySupplies||0);
  const cleanUsed = n - dirtyUsed;

  // BURN: supplies consumed, 0 rocks, smoke fills the screen, wanted+1, brain -10.
  if (outcome === 'burn') {
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    P.brain = Math.max(0, P.brain - 10);
    P.wanted = Math.min(3, P.wanted + 1);
    state.smokeT = 2000;
    audio.hurt(); audio.glassBreak();
    toast("the smoke is in the floor.\nit is in your hair.\nit will be in your hair on tuesday.", 4200);
    if (Math.random() < 0.5) feedPost("someone burnt the block. it's bad out here.", '@crackheadcent');
    // CONTROLLED_BURN — survive a burn (player is technically still upright)
    unlockAchievement('controlled_burn');
    if (n >= 3) unlockAchievement('arson_of_nothing');
    saveGame();
    return;
  }
  // UNDERCOOK: supplies consumed, 0 rocks. flat.
  if (outcome === 'undercook') {
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    audio.hurt();
    toast("it never set.\nyou waited.\nnothing crystallized.\nyou sit. you don't move.", 4200);
    if (Math.random() < 0.5) feedPost("nothing happened today. it counts.", '@blocklog');
    saveGame();
    return;
  }
  // SOAP-ROCK: supplies consumed, yield = BAD-cook yield * 0.5, but rocks tagged as soap.
  if (outcome === 'soaprock') {
    // base bad math first
    let rocks = 0, burnt = 0;
    for (let i=0;i<n;i++) {
      let dbl, brn;
      if (mode === 'slow')         { dbl = 0.08 + bb*0.15; brn = 0.10 - bb*0.08; }
      else if (mode === 'fast')    { dbl = 0.35 + bb*0.20; brn = 0.30 - bb*0.10; }
      else if (mode === 'shakes')  { dbl = 0.55;           brn = 0.45; }
      else if (mode === 'propane') { dbl = 0.30 + bb*0.20; brn = 0.20 - bb*0.10; }
      else                         { dbl = 0.15 + bb*0.18; brn = 0.18 - bb*0.10; }
      dbl = clamp(dbl, 0, 0.7); brn = clamp(brn, 0.02, 0.5);
      const r = Math.random();
      if (r < brn) burnt++;
      else if (r < brn + dbl) rocks += 2;
      else rocks++;
    }
    rocks = Math.floor(rocks * 0.5);
    P.supplies = Math.max(0, (P.supplies||0) - n);
    P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
    P.soapRocks = (P.soapRocks||0) + rocks;
    P.brain = Math.max(0, P.brain - Math.min(6, 1 + n));
    P.shakes = Math.min(100, P.shakes + 2 * n);
    audio.hurt();
    toast(`· batch ·\n- ${n} packet${n===1?'':'s'}\n+ ${rocks} 'rock${rocks===1?'':'s'}'\nit looks right. it isn't.`, 4200);
    if (Math.random() < 0.5) feedPost("cut is talking.", '@hardcandy');
    saveGame();
    return;
  }

  // PERFECT / OK / BAD — the real cook math, with outcome multipliers.
  const yieldMult  = outcome === 'perfect' ? 1.15 : outcome === 'bad' ? 0.60 : 1.00;
  const soapAdjust = outcome === 'perfect' ? 0.70 : outcome === 'bad' ? 1.50 : 1.00;

  let rocks = 0, burnt = 0, soap = 0;
  for (let i=0;i<n;i++) {
    let dbl, brn;
    if (mode === 'slow')         { dbl = 0.08 + bb*0.15; brn = 0.10 - bb*0.08; }
    else if (mode === 'fast')    { dbl = 0.35 + bb*0.20; brn = 0.30 - bb*0.10; }
    else if (mode === 'shakes')  { dbl = 0.55;           brn = 0.45; }   // ignores brain
    else if (mode === 'propane') { dbl = 0.30 + bb*0.20; brn = 0.20 - bb*0.10; }   // tight, hot
    else                         { dbl = 0.15 + bb*0.18; brn = 0.18 - bb*0.10; }
    dbl = clamp(dbl, 0, 0.7); brn = clamp(brn, 0.02, 0.5);
    const r = Math.random();
    if (r < brn) burnt++;
    else if (r < brn + dbl) rocks += 2;
    else rocks++;
  }

  // apply per-mode yield bonus (propane = 1.30 × base) then per-outcome multiplier
  if (mode === 'propane') rocks = Math.floor(rocks * 1.30);
  rocks = Math.max(0, Math.floor(rocks * yieldMult));

  // soap rate: weighted average, adjusted by outcome
  const baseRate = n > 0 ? (dirtyUsed * 0.25 + cleanUsed * 0.12) / n : 0;
  const soapRate = clamp(baseRate * soapAdjust, 0, 1);
  if (mode !== 'shakes' && rocks > 0 && Math.random() < soapRate) { soap = 1; rocks--; }

  P.supplies = Math.max(0, (P.supplies||0) - n);
  P.dirtySupplies = Math.max(0, (P.dirtySupplies||0) - dirtyUsed);
  P.rocks += rocks;
  if (soap) P.inventory.push({id:'soap', n:'a small bar of soap (oops)', q:1});
  P.brain = Math.max(0, P.brain - Math.min(6, 1 + n));
  P.shakes = Math.min(100, P.shakes + (mode==='shakes' ? 0 : 2 * n));
  P.lifetime.rocksCooked = (P.lifetime.rocksCooked||0) + rocks;

  if (rocks > 0) audio.coin();
  if (burnt > 0) audio.hurt();
  audio.glassBreak();

  if (rocks > 0 && state.quests.finisher && !state.quests.finisher.done) {
    state.quests.finisher.done = true; questToast('THE FINISHER');
  }
  if ((P.lifetime.rocksCooked||0) >= 10) unlockAchievement('chef');
  if (burnt === n && n >= 3) unlockAchievement('arson_of_nothing');
  if (outcome === 'perfect') unlockAchievement('the_heat_held');

  const lines = [`- ${n} packet${n===1?'':'s'}`];
  if (rocks > 0) lines.push(`+ ${rocks} rock${rocks===1?'':'s'}`);
  if (soap > 0)  lines.push(`+ 1 'rock' (it's soap. it happens.)`);
  if (burnt > 0) lines.push(`burnt ${burnt}.\nthe crate has a smell now.`);

  let header;
  if (outcome === 'perfect') header = "the heat held.";
  else if (outcome === 'ok') header = "close enough. the rock is the rock.";
  else                       header = "the smell is wrong. you did this wrong.";

  toast(`· batch ·\n${header}\n${lines.join('\n')}`, 4200);

  // feed broadcasts — gated to ~50% per outcome so they don't spam
  if (Math.random() < 0.5) {
    if (outcome === 'perfect')   feedPost("the chef. quiet today. respect.", '@hardcandy');
    else if (outcome === 'ok')   feedPost(`cooked ${rocks} on the crate. the crate is a kitchen.`, '@crackheadcent');
    else                         feedPost("the smell is wrong on the block.", '@blocklog');
  }

  // smell: cooking in bulk attracts attention — only on OK / PERFECT (bad/burn handle their own bumps)
  if (n >= 3 && (outcome === 'perfect' || outcome === 'ok') && Math.random() < 0.35) {
    P.wanted = Math.min(3, P.wanted + 1);
    setTimeout(()=>toast("a neighbor opens a window.\nthe neighbor closes the window.\nwanted +1.", 2800), 2200);
  }
  saveGame();
}

export function drawHeatMini() {
  const h = state.heat;
  if (!h || !h.active) return;
  // panel — same language as dialogue overlay: dark slab, dirty cream text
  const PW = 480, PH = 240;
  const px = (W - PW) / 2, py = (H - PH) / 2;
  ctx.fillStyle = 'rgba(0,0,0,.78)';
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = '#1a1810';
  ctx.fillRect(px, py, PW, PH);
  ctx.strokeStyle = '#e8c040';
  ctx.lineWidth = 2;
  ctx.strokeRect(px+1, py+1, PW-2, PH-2);

  // title
  ctx.fillStyle = '#e8c040';
  ctx.font = 'bold 16px Courier New';
  ctx.textAlign = 'center';
  ctx.fillText('the heat.', W/2, py + 28);
  // subtitle
  const cleanCount = Math.max(0, h.n - Math.min(h.n, P.dirtySupplies||0));
  const dirtyCount = h.n - cleanCount;
  const modeLabel = ({slow:'low and slow', fast:'fast cook', shakes:'shaky special', all:'cook all', propane:'propane'})[h.mode] || h.mode;
  const subtitle = `${modeLabel} — ${h.n} packet${h.n===1?'':'s'} — clean × ${cleanCount} + dirty × ${dirtyCount}`;
  ctx.fillStyle = '#d4c896';
  ctx.font = '11px Courier New';
  ctx.fillText(subtitle, W/2, py + 48);

  // the bar
  const BW = 400, BH = 28;
  const bx = (W - BW) / 2, by = py + 90;
  // gradient: blue → green → yellow → red → black
  const grad = ctx.createLinearGradient(bx, 0, bx + BW, 0);
  grad.addColorStop(0.00, '#2848a0');
  grad.addColorStop(0.30, '#4a8830');
  grad.addColorStop(0.55, '#d4b820');
  grad.addColorStop(0.82, '#c84020');
  grad.addColorStop(0.96, '#1a0a08');
  grad.addColorStop(1.00, '#000');
  ctx.fillStyle = grad;
  ctx.fillRect(bx, by, BW, BH);
  // burn-zone marker (thin red bracket at top of bar)
  const bzX = bx + BW * (1 - h.burnZone);
  ctx.fillStyle = 'rgba(160,40,40,.4)';
  ctx.fillRect(bzX, by, BW - (bzX - bx), BH);

  // sweet-spot region (raised + white tick above)
  const sx1 = bx + BW * (h.sweetCenter - h.sweetHalf);
  const sx2 = bx + BW * (h.sweetCenter + h.sweetHalf);
  ctx.fillStyle = 'rgba(212,200,150,.18)';
  ctx.fillRect(sx1, by - 4, sx2 - sx1, BH + 8);
  ctx.strokeStyle = '#d4c896';
  ctx.lineWidth = 1;
  ctx.strokeRect(sx1, by - 4, sx2 - sx1, BH + 8);
  // tick mark
  ctx.fillStyle = '#d4c896';
  ctx.fillRect(bx + BW * h.sweetCenter - 1, by - 10, 2, 6);

  // bar border
  ctx.strokeStyle = '#604020';
  ctx.lineWidth = 2;
  ctx.strokeRect(bx, by, BW, BH);

  // needle
  const needleX = bx + BW * h.progress;
  ctx.fillStyle = '#d4c896';
  ctx.fillRect(needleX - 1, by - 6, 2, BH + 12);
  // locked-in indicator
  if (h.lockedAt !== null) {
    const lx = bx + BW * h.lockedAt;
    ctx.fillStyle = '#e8c040';
    ctx.fillRect(lx - 2, by - 8, 4, BH + 16);
  }

  // helper line
  ctx.fillStyle = '#776';
  ctx.font = '10px Courier New';
  ctx.fillText(
    h.phase === 'fill' ? 'space / tap — lock the heat. esc — walk away.' :
    h.phase === 'idle' ? "you're letting it burn. tap to save it." :
    h.outcome ? '· ' + heatOutcomeLabel(h.outcome) + ' ·' : '',
    W/2, by + BH + 28);

  // reveal phase — show outcome label larger
  if (h.phase === 'hold' && h.outcome) {
    ctx.fillStyle = h.outcome === 'perfect' ? '#e8c040'
                   : h.outcome === 'burn'    ? '#8a3a3a'
                   : h.outcome === 'soaprock'? '#d488d4'
                   : '#d4c896';
    ctx.font = 'bold 18px Courier New';
    ctx.fillText(heatOutcomeLabel(h.outcome).toUpperCase(), W/2, by + BH + 56);
  }
  ctx.textAlign = 'left';
}

export function heatOutcomeLabel(o) {
  return ({perfect:'perfect.', ok:'ok.', bad:'bad cook.', burn:'burnt.', undercook:'never set.', soaprock:'soap.'})[o] || o;
}

export function drawSmokeOverlay() {
  if (!state.smokeT || state.smokeT <= 0) return;
  const a = Math.min(1, state.smokeT / 2000);
  // gray haze layered with darker blobs
  ctx.fillStyle = `rgba(180,170,160,${a * 0.85})`;
  ctx.fillRect(0, 0, W, H);
  // a few wandering smudges
  for (let i = 0; i < 6; i++) {
    const t = performance.now() / 600 + i;
    const x = ((Math.sin(t * 1.3 + i) * 0.5 + 0.5) * W);
    const y = ((Math.cos(t * 0.9 + i) * 0.5 + 0.5) * H);
    ctx.fillStyle = `rgba(60,52,44,${a * 0.6})`;
    ctx.beginPath(); ctx.arc(x, y, 90 + (i%3)*20, 0, Math.PI*2); ctx.fill();
  }
  ctx.fillStyle = '#1a1810';
  ctx.font = 'bold 14px Courier New';
  ctx.textAlign = 'center';
  ctx.fillText("the smoke is in the floor.", W/2, H/2);
  ctx.textAlign = 'left';
}

export function init_heat() {
  // ---------- COOK (the finisher) ----------
  // v13 wave 4: cook is now a real-time canvas skill check called THE HEAT.
  // cookBatchMenu picks the mode + packet count, startHeatMini runs the bar,
  // resolveHeatOutcome reads needle vs sweet spot, applyCookOutcome does the math.
  
  // per-mode heat configuration. fillMs = full-bar travel time; sweetCenter = base sweet-spot center
  // (fraction of bar); sweetSpread = ± random jitter; baseWidth = sweet-spot width before brain mod;
  // burnZone = top fraction of bar that auto-burns.
  COOK_MODES = {
    slow:    { fillMs: 4000, sweetCenter: 0.55, sweetSpread: 0.05, baseWidth: 0.22, burnZone: 0.08 },
    fast:    { fillMs: 2400, sweetCenter: 0.70, sweetSpread: 0.05, baseWidth: 0.16, burnZone: 0.08 },
    shakes:  { fillMs: 1800, sweetCenter: 0.78, sweetSpread: 0.07, baseWidth: 0.10, burnZone: 0.08 },
    all:     { fillMs: 3200, sweetCenter: 0.65, sweetSpread: 0.05, baseWidth: 0.13, burnZone: 0.08 },
    propane: { fillMs: 1200, sweetCenter: 0.65, sweetSpread: 0.05, baseWidth: 0.08, burnZone: 0.15 },
  };
  
  
  
  
  
  
  
  // ---------- THE HEAT minigame ----------
  
  
  
  
  
  
  
  
  
  
  
  
  // preserve the doCook math contract — sweet-spot outcome modifies yield and soap rate,
  // but the bb-brain modulation and dirty-packet weighting still apply on top.
  
  
  // ---------- HEAT minigame render ----------
  
  
  
  
  // smoke overlay — 2s after a burn
  
  
  
}
