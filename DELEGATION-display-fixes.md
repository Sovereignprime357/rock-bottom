# DELEGATION → Codex — v22 display-shell fixes (full-screen fit + desktop mobile-buttons)

Grounded 2026-07-19 from live desktop play + 3 screenshots (100% / 250% / 400% zoom). Root causes are
confirmed in code, not guessed. Portfolio-quality; ship clean. **Unambiguous where it's certain, and it
tells you exactly where NOT to go without an operator ruling.**

---

## THE TWO BUGS (root causes — proven, with the evidence)

### Bug A — the game does not fill the screen; operator must zoom the browser 250–400%
- **Root:** `index.html:180` is a **static** `<canvas id="game" width="800" height="600">`, and
  `index.html:28` caps the stage at `min(800px, …)` / `min(600px, …)`. On a phone the `100vw`/`100vh`
  terms bind and it fills; on a **desktop the 800×600 px caps bind**, so the game is a tiny 800×600 box
  in a black void. Browser zoom is the only lever to enlarge it.
- **Evidence:** 100%-zoom screenshot = tiny centered box, black filling the whole monitor.

### Bug B — mobile touch controls (joystick + A/B/F) show on desktop
- **Root — corrected, this is NOT a touch-device false positive.** `isTouch` is **false** on this machine
  (250%-zoom screenshot shows keyboard hints, no buttons). The controls appear only at ~400% zoom because
  `window.innerWidth` (CSS px) drops to **≤ 820**, tripping the `innerWidth <= 820` mobile breakpoint in
  `src/input/mobile.js:25` and `src/ui/hud.js:12`. **It is a symptom of Bug A** — the operator only zooms
  because the game is tiny. Fix A and it stops manifesting; we still fix B robustly below.
- **Evidence:** buttons present only in the 400% shot, absent at 100% and 250%.

---

## PHASE 1 — the certain fixes. Build these now.

### Task 1 — remove the desktop stage cap (Bug A core)
- **File:** `index.html` (~line 28)
- **Find This:**
  ```
  #stage{position:relative;width:min(800px,100vw,calc(100vh * 4 / 3));height:min(600px,100vh,calc(100vw * 3 / 4));background:#000;box-shadow:0 0 80px rgba(232,192,64,.08)}
  ```
- **Replace With:**
  ```
  #stage{position:relative;width:min(100vw,calc(100vh * 4 / 3));height:min(100vh,calc(100vw * 3 / 4));background:#000;box-shadow:0 0 80px rgba(232,192,64,.08)}
  ```
- **Why:** drops the 800×600 px ceiling so the stage grows to the viewport (still locked 4:3 by the
  `calc` terms). The 800×600 canvas backing is CSS-upscaled; `image-rendering:pixelated` (`index.html:29`)
  keeps it crisp-blocky. **No render/camera change** — `resolvePresentationLayout` (`src/ui/layout.js`,
  `scale = gameW/800`) already reads the live stage size, so the HUD rescales itself.
- **Test:** at **100% browser zoom** on a ≥1080p desktop the game fills the viewport height with no zoom
  needed; on a phone / narrow window it still fills as before.

### Task 2 — gate mobile chrome on a real coarse pointer, not window width (Bug B)
- **File:** `src/input/mobile.js` (~lines 24–25)
- **Find This:**
  ```
  const isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
  if (!isTouch && window.innerWidth > 820) return;
  ```
- **Replace With:**
  ```
  // v22: gate on a real coarse pointer (phone/tablet), NOT viewport width — a narrow
  // desktop window or high browser zoom is not a touch device (2026-07-19 display fix).
  const isTouch = matchMedia('(pointer: coarse)').matches;
  if (!isTouch) return;
  ```
- **File:** `src/ui/hud.js` (~line 12)
- **Find This:**
  ```
  const mobileChrome=window.innerWidth<=820||navigator.maxTouchPoints>0;
  ```
- **Replace With:**
  ```
  const mobileChrome=matchMedia('(pointer: coarse)').matches;
  ```
- **Why:** `(pointer: coarse)` is true on touchscreens, false on mouse/trackpad desktops — independent of
  zoom, window width, and phantom `maxTouchPoints`. Desktop = fine pointer = no mobile controls ever;
  real touch device = coarse = controls preserved.
- **Test:** on desktop the mobile buttons never appear at **any** zoom (100/250/400%); in DevTools device
  emulation (or on the iPad) the joystick + A/B/F still appear and fire keys.

---

## PHASE 2 — the ONE DECISION. Do NOT build until the operator rules.

After Phase 1, a 4:3 game on a 16:9 monitor fills full height but keeps **modest side bars** (~320px each
on a 2554-wide screen). The operator wants "no black edges." True zero-bars = a **wider view (show more
world horizontally)**, which is **not** a CSS tweak — it touches gameplay:
- `W, H` in `src/data/world.js:11` become viewport-aspect-derived (not fixed 800×600);
- the `#game` canvas backing resolution becomes dynamic (and `devicePixelRatio`-aware for sharpness);
- camera clamps (`src/core/update.js:875-876`), the `LIGHT_MASK` / `FOG_SHEET` sheets
  (`src/render/landmarks_a.js:262-268`, sized `W×H`), the minimap, and HUD proportions all follow;
- `world-gate` re-verified — showing more world doesn't change runway px, but re-confirm coverage;
- **tradeoff: the player sees more of the map** — a mild exploration/balance change + possible
  world-edge pop-in near the borders.

This is its own SPEC-captured wave. **Flag it; build only on the operator's greenlight.** Recommendation
on the record: ship Phase 1 first (large win, near-zero risk), let the operator judge the side bars on the
big screen, then decide Phase 2 — the bars may not even bother him once the game is full-height and crisp.

---

## INVARIANTS (all phases)
- **I-MOBILE-PRESERVED.** Real touch devices (the operator's iPad) keep working mobile controls + chrome.
  Verify the `(pointer: coarse)` path on-device or via emulation before calling it done.
- **I-NO-CAMERA-CHANGE (Phase 1).** The world view stays 800×600; Phase 1 is presentation-only. Do **not**
  touch `W, H` or the camera in Phase 1.
- **I-PIXELATED.** Keep `image-rendering:pixelated`; the upscaled canvas stays crisp, never smoothed.
- **I-V19-FROZEN.** Do not touch `rock_bottom_v19.html` or any `rock_bottom_v*.html`. The corpus/world/
  sprite gates guard the floor.
- **I-GATES-GREEN.** `node tools/run-gates.mjs` stays **18/18**. If `presentation-gate` should pin "stage
  has no fixed-px cap," add the assertion and **red-test it first** (make it fail on the OLD css) before
  trusting green — ORCHESTRATOR-NOTES #3.
- One wave per branch/worktree; commit messages reference this delegation.

## ACCEPTANCE (Phase 1)
- [ ] 100% zoom, ≥1080p desktop: game fills viewport height; no tiny box; no forced browser zoom.
- [ ] Mobile buttons absent on desktop at 100 / 250 / 400% zoom.
- [ ] Real-touch (iPad / coarse-pointer emulation): mobile controls present + functional.
- [ ] Suite 18/18; v19 untouched; commit references this doc.
- [ ] 4:3 side bars on wide screens are ACCEPTED for Phase 1 (Phase 2 is the operator's separate call).

---

## NOT IN THIS DELEGATION
The **cart-freeze on park entry/exit** is a separate gameplay bug (needs a live console read to root-cause,
not a display fix). The mobile buttons were a zoom artifact, so they are unlikely its cause. Hunt it on its
own branch after a live repro.
