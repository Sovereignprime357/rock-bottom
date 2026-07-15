# LEGIBILITY AUDIT — rock_bottom_v19.html

**Scope:** text layout and readability only. Read-only audit; nothing was changed.
**Target:** `C:\Users\zenit\projects\Rock Bottom\rock_bottom_v19.html` (12,737 lines; styles 9–166, script 241–12,735).
**Date:** 2026-07-15

---

## VERDICT

The graphics are not the problem. **Measured, the palette is excellent:** cream `#d4c896` on asphalt `#1a1810` is **10.58:1** contrast — WCAG AA needs 4.5:1. The sprites, the muted browns, the chunky art direction are all fine and none of them are why the frame is unreadable.

Three things are burying the writing:

1. **A CSS vignette stacked on top of the entire UI**, which drags that same 10.58:1 text down to **2.4:1** at the frame edges — where the HUD, the ticker, the dialogue box and the minimap all live. This is the single largest legibility cost in the game.
2. **Text drawn with no backing plate and no width measurement**, in a world that grew 11.5× while the label system stayed frozen.
3. **Zero de-confliction** between any two text elements — no overlap detection anywhere in the file.

The hypothesis in the brief is **confirmed for findings F1–F5** and **refuted for F6** (the vignette). Details below, each traced to code.

### The through-line: every correct pattern already exists in this file, applied once

This is the most useful thing in this audit. The fixes are mostly *propagation*, not invention:

| Correct pattern | Where it exists and works | Where it is missing |
|---|---|---|
| `measureText()` for plate width | NPC nameplates, line **11024** | chatter bubbles (**11117**), graffiti (**10093**), building signs (**9977**) |
| Auto-fit font size to available width | landmark facades, line **8935** | everywhere else |
| Clamp to viewport bounds | `drawObjectiveGuide`, line **11234** (`clamp(sx,24,W-24)`) | all `(E)` prompts and all world text |
| Backing plate behind text | nameplates, chatter, facades, styled signs | 21 building names, all zone labels, all graffiti |

The codebase already knows how to do this correctly. It just does it in 1 of N places.

---

## THE GROWTH EVIDENCE (measured across v4 → v19)

Extracted directly from the shipped files in this folder:

| ver | WORLD w×h | zones | buildings | `BUILDING_STYLE` keys | canvas W,H |
|---|---|---|---|---|---|
| v4  | 2200×1900 | 10 | 4  | 0 | 800,600 |
| v10 | 2200×1900 | 11 | 5  | **4** | 800,600 |
| v12 | 2200×1900 | 11 | 5  | **4** | 800,600 |
| v13 | 4400×3400 | 16 | 14 | **4** | 800,600 |
| v17 | 4400×3400 | 16 | 14 | **4** | 800,600 |
| v18 | 5800×3800 | 19 | 17 | **4** | 800,600 |
| v19 | **8600×5600** | **23** | **25** | **4** | **800,600** |

- **World area grew 11.5×** (4.18M px² → 48.16M px²).
- **Buildings grew 6.25×** (4 → 25). NPCs grew 30 → 41 (`spawnNpcs`).
- **`BUILDING_STYLE` has been frozen at 4 keys since v10.**
- **The viewport never moved: `const W = 800, H = 600;` (line 297), unchanged in every version.**

This is the same failure class as the withdrawal-timer bug. At v10, 4 of 5 buildings (80%) had a proper sign. At v19, 3 of 25 (12%) do. Nothing broke — the coverage was simply never re-checked as content was added around it.

---

# FINDINGS

Ordered by severity × checkability. **Every finding marked GATE-READY can be asserted by an automated check that can actually fail.**

---

## F1 — 21 of 24 named buildings draw their name with no backing plate — CRITICAL — GATE-READY

**Symptom.** Building names stamped raw onto wall art and windows. Matches the screenshot evidence of labels sitting directly on storefront windows.

**Mechanism.** `drawBuilding()`, line **9868**:

```js
const style = BUILDING_STYLE[b.name];
```

`BUILDING_STYLE` (lines **9832–9837**) has exactly four keys — `PAWN`, `CORNER`, `CHURCH`, `LAUNDROMAT` — the original v10 buildings. Any building whose `name` is not one of those four falls through to the `else` branch at lines **10000–10004**:

```js
} else if (b.name && b.name !== '') {
    ctx.fillStyle = '#d4c896';
    ctx.font = 'bold 11px Courier New';
    ctx.fillText(b.name, b.x+8, b.y+10);
}
```

No backing plate. No `measureText`. No centering. Just text stamped at a fixed offset inside the building's top-left corner, directly on top of whatever wall/window art `drawBuilding` already painted above it.

The styled path (lines **9975–9998**) does it properly — dark back plate, centered, positioned above the roofline.

**Measured.** I extracted the arrays and ran the check:

```
unplated building names: 21 / 24 named buildings
 -> CHURCH, OLDSCHOOL, SHACK ×8, UNIT 11, RETURNS, THE OFFICE, TARP PERMITS,
    BLUE COURT, CART IMPOUND, THE KEEP, COPPER RETURNS, CHOIR OFFICE,
    DITCH RECORDS, THE THRONE
```

**Bug within the bug — CHURCH.** `CHURCH` *has* a style, but its `sign` is `''` (line 9835). The guard at line **9975** is `if (style && style.sign)` — `''` is falsy — so CHURCH falls through to the unplated branch and draws "CHURCH" raw on its own wall. It has a style and still gets the broken path.

**Why it broke.** Growth. Proven by the version table: `BUILDING_STYLE` frozen at 4 keys since v10 while `BUILDINGS` went 5 → 25. The array's own comments date the additions (`v13 wave 8a`, `v18 far-east solids`, `v19 rival court shells`) — every building added after v10 landed in the fallback branch.

**Severity.** Critical. This is 88% of the building labels in the game.

**GATE:** for every `b` in `BUILDINGS` with a non-empty `name`, assert `BUILDING_STYLE[b.name]` exists and has a non-empty `sign`. Currently fails 21/24. Binary, static, no rendering required.

---

## F2 — Zone labels are painted over by buildings — "THE LAUNDROMAT" renders as "THE LA" — CRITICAL — GATE-READY

**Symptom.** Screenshot: **"THE LA" overlapping a "WASH·DRY" sign.** Fully explained; reproduced exactly from the code with no speculation.

**Mechanism.** Draw order inside `drawAll()`. Zone labels are drawn at lines **9136–9138**:

```js
ctx.fillStyle = z.label;
ctx.font = '11px Courier New';
ctx.fillText(z.name, z.x+8, z.y+18);
```

No plate, no measurement. Then **buildings are drawn afterwards**, lines **9148–9151**, and paint over them. The laundromat's striped awning (lines **9871–9877**) is the specific occluder:

```js
const aw = b.w - 12;  const aH = 12;
for (let s=0; s<Math.floor(aw/8); s++) {
  ctx.fillStyle = (s & 1) ? style.awning : '#fff8d0';
  ctx.fillRect(b.x + 6 + s*8, b.y - aH + 2, 8, aH);
}
```

**Exact reconstruction** (zone `laundromat` line **330**, building `LAUNDROMAT` line **621**, Courier New advance = 0.6em):

```
zone label "THE LAUNDROMAT"  x:1488 -> 1580.4   y:1089.8 -> 1100.2
awning                       x:1526 -> 1750     y:1090   -> 1102
vertical overlap: true
label survives 38px before the awning covers it = 5.76 chars
==> player reads: "THE LA"   (of "THE LAUNDROMAT")

WASH-DRY sign plate          x:1602 -> 1678     y:1076 -> 1090
gap between the truncated label and the sign plate: 76px — side by side on screen.
```

That is the screenshot, character for character, derived from the source.

**Why it broke.** The zone label is anchored to the zone's top-left corner (`z.x+8, z.y+18`) and the building was later placed at `x:1520, y:1100` — 40px inside that same corner. Nothing consults anything. Add a building near a zone's top-left and it silently eats the zone's name.

**Severity.** Critical — it destroys the zone name, which is wayfinding.

**GATE:** assert no zone-label bounding box intersects any building body or awning box. **I ran this: it currently reports exactly 1 violation** (`THE LAUNDROMAT` × `LAUNDROMAT`). One line to fix, and the gate proves it stays fixed.

---

## F3 — NPC nameplates have zero de-confliction; 2 pairs collide before anyone moves — HIGH — GATE-READY

**Symptom.** Overlapping name labels mashing into unreadable text.

**Mechanism.** `drawNpc()`, lines **11012–11035**:

```js
const cx=n.x+n.w/2, top=n.y-8-labelLines.length*10;
for(let i=0;i<labelLines.length;i++){
  const line=labelLines[i], tw=labelWidths[i];
  ctx.fillStyle='rgba(10,8,5,.76)'; ctx.fillRect(Math.round(cx-tw/2-3),top+i*10-8,tw+6,10);
  ctx.fillStyle=(n.hostile||n.aggro)?'#d04040':'#d4c896'; ctx.fillText(line,cx,top+i*10);
}
```

Each plate is positioned purely from that one NPC's own `x`/`y`. **Nothing in this function — or anywhere in the file — consults any other NPC's label box.** There is no de-confliction, no vertical stagger, no priority, no hiding. Two NPCs at similar `y` produce plates at the same screen `y` and simply overprint.

The visibility radius is 260px (line **11015**):

```js
const showName = n.vendor || n.hostile || n.aggro || (pdx*pdx+pdy*pdy)<260*260;
```

**Measured** (exact plate geometry from the code above, applied to spawn coords):

```
NPC nameplate boxes: 43
OVERLAPPING nameplate pairs at spawn position: 2
  "WHOLE FOODS MOM" X "THE PHONE GUY"  overlap 60px
  "LAUNDROMAT LADY" X "KARAOKE MIKE"   overlap 17px

worst case: 6 nameplates lit simultaneously (player standing at BUSKER)
35 NPC pairs spawn within the 260px nameplate radius of each other
```

`WHOLE FOODS MOM` and `THE PHONE GUY` spawn **20px apart**; their plates are ~85px and ~76px wide and overlap by **60px** — roughly 70% mush. `CHATTY DAVE` and `FOOD TRUCK GUY` spawn **28px apart**.

And that is the *static* case. NPCs move; the runtime case is strictly worse.

**Why it broke.** Growth: 30 NPCs (v10) → 41 (v19), placed into a world that grew 11.5× but with clusters getting denser, not sparser. The 260px radius was set when the map was 2200×1900.

**Severity.** High.

**GATE — this is the best one in the audit.** "No two nameplate boxes intersect: yes/no." Runnable two ways: (a) statically against spawn coords, which currently fails with 2 violations; (b) as a per-frame dev assertion during play. Binary, cheap, and it can actually fail — exactly what makes an autonomous loop safe.

---

## F4 — Graffiti: random placement, hardcoded 80px width guess, ~51% of tags overflow their wall — HIGH — GATE-READY

**Symptom.** Screenshot: **"GIE BARB CHEATS ~~ CROSSWORD" rendering on top of "well louder, larry i- -ling"** — two texts colliding into mush.

**Mechanism.** Two separate defects that combine.

*(a) Placement never measures the text.* `buildGraffiti()`, line **10093**:

```js
x = b.x + 6 + Math.random()*(b.w-80);
```

The `-80` is a hardcoded guess that every tag is 80px wide. `GRAFFITI_LINES` (line **939**) holds 36 strings ranging **43px to 335px** at 9px bold Courier. `measureText` is never called. Placement is otherwise pure `Math.random()` over every unlocked building wall (lines 10074–10083), with no awareness of NPCs, other graffiti, posters or signs.

*(b) Rendering has no plate.* `drawGraffiti()`, lines **10111–10129** — rotated, `globalAlpha = 0.65`, drawn straight onto the wall with no backing rect. Its own cull check uses a fixed 170px box (`visibleWorldRect(g.x-80,g.y-18,170,28,16)`, line **10115**) that does not match the actual text width either.

**Measured** (expected value over the actual uniform random range — not worst case):

```
expected P(a random tag overflows its wall) = 50.6%   (24 walls x 36 lines)

worst walls:
  SHACK       w=100px  P(overflow)=94%
  SHACK       w=110px  P(overflow)=92%
  SHACK       w=120px  P(overflow)=88%
  OLDSCHOOL   w=520px  P(overflow)=17%

a 100px SHACK wall can host 4/36 tags without overflowing.
26 of 36 graffiti lines are wider than 120px.
longest: 335px "the train is coming. the train is coming. the train is coming."
```

**The collision with NPC chatter.** `drawGraffiti()` runs at line **9158**; NPCs draw at **9256**. So an NPC's chatter bubble — which *does* have an opaque `rgba(0,0,0,.85)` plate (line 11118) — lands on top of a graffiti string mid-word. A 190px tag ("BAGGIE BARB CHEATS AT THE CROSSWORD", line **942**) with a ~90px opaque bubble parked over its middle leaves both ends sticking out and the centre destroyed. That is the reported "GIE BARB CHEATS ~~ CROSSWORD" over Loud Larry's chatter.

**Why it broke.** *Born broken, not a regression* — and I can date it. The graffiti placer and the 100px SHACKs landed in the **same version**:

```
ver | graffiti lines | narrowest wall | the '-80' guess
v10 | (no placer)    | 160            | -
v13 | 36             | 100            | 80
v19 | 36             | 100            | 80
```

The `-80` was never defensible for a 100px shack. It arrived wrong in v13 and was never revisited.

**Severity.** High — it is ~50% of the game's environmental writing, which is some of the best writing in the game.

**GATE:** assert `measureText(tag).width <= wall.w - margin` for every (wall × tag) pair the placer can produce, and assert no graffiti box intersects any other text box. Currently ~51% expected failure.

---

## F5 — Chatter bubble width is arithmetic, not measured — MEDIUM — GATE-READY

**Mechanism.** `drawNpc()`, line **11117**:

```js
const tw = n.chatter.length * 5.4 + 8;
```

`5.4` is the 9px Courier New advance (0.6 × 9) hardcoded as a magic number. The plate is drawn from it at lines 11118–11122, and **the font is only actually set afterwards** at line 11131 (`ctx.font = '9px Courier New'`). If Courier New is not installed and the browser falls back to a generic monospace with a different advance ratio, the plate mis-sizes and the text overflows its own background.

This is 90 lines below line **11024** in the *same function*, which does it correctly:

```js
n._labelWidths=lines.map(line=>Math.ceil(ctx.measureText(line).width));
```

The nameplate path measures. The chatter path guesses. Same function.

**Note.** The same magic-number pattern appears in the styled building sign, line **9977**: `const sigW = style.sign.length * 8 + 12;` — `8` for an 11px font whose real advance is 6.6. That one over-estimates, so the plate is too wide rather than too narrow (safe, but it means a long sign's plate can hang off the building edge).

**Severity.** Medium — latent; depends on font fallback. Real on Linux/Android where Courier New is frequently absent.

**GATE:** no `fillText` may be backed by a plate whose width came from anything other than `measureText`. Greppable: flag `.length * <number>` near a `fillRect`.

---

## F6 — The vignette is stacked ON TOP of the entire UI — CRITICAL — PARTIALLY GATE-READY

**This is the single largest legibility cost in the game, and it is one CSS declaration.**

**Symptom.** "Overall too dark — a heavy vignette eating the frame; large regions are unreadable brown mud." Also explains **"business q" cut off at the right edge** and **"weather: tuesday. with" cut off** — these are *not* layout overflow. The text is fully laid out and the vignette is painting black over it.

**Mechanism.** Line **82**:

```css
#vignette{position:absolute;inset:0;pointer-events:none;z-index:32;box-shadow:inset 0 0 100px 20px #000}
```

`z-index: 32`. Now every other UI layer:

| element | z-index | under the vignette? |
|---|---|---|
| `#minimap` | 20 | yes |
| `#ticker`, `#phonebox` | 21 | yes |
| `#mobile-ctrls` | 22 | yes |
| `#objective` | 24 | yes |
| `#actionHint` | 25 | yes |
| `#hud`, `#dialogue`, `#toast`, `#panel` | auto | yes |
| `#scanlines` | 30 | (also over the UI) |
| `#title` | 50 | no |
| `#poweron` | 60 | no |

**Only the title screen and the power-on splash escape it.** Every piece of gameplay text in the game — HUD, dialogue, ticker, toasts, objective, action hints, minimap — is painted underneath a black vignette *and* underneath the scanlines (`z-index:30`, `mix-blend-mode:multiply`).

**Quantified.** `inset 0 0 100px 20px #000` = a 20px solid-black spread inset from every edge, then a 100px blur. Modelling the blur as a linear ramp (approximation of the Gaussian; the real curve is close):

```
=== baseline palette (NO vignette) ===
cream #d4c896 on asphalt #1a1810 : 10.58:1   (AA needs 4.5:1)
cream #d4c896 on ticker  #0a0805 : 11.91:1

=== desktop vignette: inset 0 0 100px 20px #000 ===
  #ticker top (d=0..18)                alpha=0.61  contrast=2.47:1   <-- FAILS AA
  #dialogue / #hud side margin (d=8)   alpha=0.62  contrast=2.39:1   <-- FAILS AA
  #hud top row (d=26)                  alpha=0.44  contrast=4.11:1   <-- FAILS AA
  #minimap near corner (d=8)           alpha=0.62  contrast=2.39:1   <-- FAILS AA
  frame centre (d>70)                  alpha=0.00  contrast=11.91:1
```

The palette delivers **10.58:1**. The vignette drags it to **2.4:1** exactly where the text lives. The outer ~70px of the frame is meaningfully darkened; the outer 20px is near-black. And every UI element is deliberately positioned in that band:

- `#hud` — `top:26px; left:8px; right:8px` (line 27) → its top row and both margins sit in the dark band. **The right column is right-aligned to `right:8px`, so the tails of "business q" and "cred" get ~62% black painted over them.** That is the reported clipping.
- `#ticker` — `top:0; height:18px` (line 111) → **the entire ticker is inside the darkest band.** ~2.5:1.
- `#dialogue` — `bottom:8px; left:8px; right:8px` (line 38) → the game's best writing, framed in the darkest ring.
- `#minimap` — `bottom:8px; right:8px` (line 88) → the darkest corner, where two edge shadows compound.

**Why it broke — hypothesis REFUTED.** This is **not** a growth regression, and I want to be precise about that because the brief predicted otherwise. The declaration is **byte-identical from v10 through v19**:

```
v10  box-shadow:inset 0 0 100px 20px #000
v13  box-shadow:inset 0 0 100px 20px #000
v18  box-shadow:inset 0 0 100px 20px #000
v19  box-shadow:inset 0 0 100px 20px #000
```

It never changed and never regressed. It has always been this heavy. What changed is how much text now lives under it. **This is an original sin that got more expensive as content accumulated** — a different failure class from F1–F4, and it should not be attributed to the map expansion.

**The tell.** Line **139**, inside the mobile media query:

```css
#vignette{box-shadow:inset 0 0 40px 0 rgba(0,0,0,.5)}
```

Mobile: 0 spread, 40px blur, capped at 50% alpha. Measured, mobile keeps **8.9:1** where desktop gets **2.5:1** — roughly 4× lighter. Someone hit this problem on a phone, patched the media query, and never back-ported it to desktop. (Both have existed since v10 — so this is long-standing, not recent.) **Desktop is the only place the vignette is still brutal, and desktop is where the file is 800×600 with a fixed HUD.**

**Severity.** Critical. Highest readability-per-byte fix in the file.

**GATE (partial).** The z-order half is trivially assertable and should be: **no UI element may have an effective stacking order below `#vignette` / `#scanlines`.** Static parse of the CSS, binary result. The contrast half needs a render-and-sample harness (rasterise the page, sample text pixels vs local background, compute WCAG ratio) — worth building, but it is a bigger lift than the geometric gates.

---

## F7 — The dialogue box is a DOM overlay with no relationship to the canvas — MEDIUM

**Symptom.** "The dialogue box rendering on top of three NPCs and a storefront sign."

**Mechanism.** Line **38**:

```css
#dialogue{bottom:8px;left:8px;right:8px;background:rgba(0,0,0,.92);border:2px solid var(--piss);...}
```

It is a DOM element layered over `<canvas id="game">`. It occupies the full width and roughly the bottom third of the frame whenever it is shown. There is no z-order *system* between DOM UI and canvas content — the canvas is a single flat layer beneath all `.ui` divs. So the dialogue box **cannot** be occluded by canvas content, and canvas content cannot move out of its way.

Nothing pans the camera, nudges the box, or repositions the speaker when dialogue opens. `dialogue()` (line **4061**) calls `hideGuidance()` and `releaseAllInput()` — it never touches the camera.

**Assessment — honest.** This is largely *by design*: a bottom-anchored dialogue box is a standard, defensible choice, and covering world art while talking is normal for the genre. It is on this list because (a) there is no mitigation at all, and (b) it lands squarely in the vignette's darkest band (F6), which is the part that actually hurts.

**Severity.** Medium. Mostly a symptom of F6.

**GATE:** when dialogue is open, assert the speaking NPC's sprite box does not intersect the dialogue box's screen rect. Checkable, but the fix is a camera/design decision, not a bug fix — lower priority than F1–F4.

---

## F8 — HUD text is fixed-px inside a fluid stage — MEDIUM — GATE-READY

**Symptom.** HUD control hints wrapping/clipping at the right edge.

**Mechanism.** The canvas scales; the HUD does not. Line **23**:

```css
#stage{position:relative;width:min(800px,100vw,calc(100vh * 4 / 3));height:min(600px,100vh,calc(100vw * 3 / 4));...}
```

The stage shrinks below 800×600 whenever the window is small (short windows in particular — `calc(100vh*4/3)`). The canvas follows it (`canvas#game{width:100%;height:100%}`, line 24) because it has a fixed 800×600 backing store that CSS rescales — canvas text therefore scales perfectly.

But the DOM HUD is sized in **fixed CSS pixels** and never scales: `.ui{font-size:11px}` (line 26), `.keyhint{font-size:10px;letter-spacing:1px}` (line 133). There is no `vw` unit, no `transform: scale()`, no container query. The only concession is a **fixed step** at the mobile breakpoint (`#hud{top:24px;font-size:10px}`, line 140) — a step, not a scale.

So as the stage narrows, the HUD's two flex columns (`#hud{display:flex;justify-content:space-between;gap:8px}`, line 27) keep their absolute text width and collide. `.keyhint` — `move wasd · hit space · bother e · business q`, 44 chars at 10px + 1px letter-spacing ≈ **308px** — has **no `white-space:nowrap`**, so it wraps rather than clips, dropping `business q` onto its own right-aligned line. Combined with F6 painting black over that same corner, that is the reported symptom.

**Severity.** Medium — only bites at smaller-than-800px stage widths, but that includes any short desktop window.

**GATE:** render at a matrix of viewport sizes and assert (a) no two HUD column boxes intersect, and (b) every HUD text node's rect is inside the canvas rect. Both are `getBoundingClientRect()` comparisons — cheap and binary.

---

## F9 — Mobile: the touch topbar paints over the news ticker — MEDIUM — GATE-READY

**Mechanism.** Two fixed numbers that disagree.

Line **111**: `#ticker{position:absolute;top:0;left:0;right:80px;height:18px;...;z-index:21}` — reserves **80px** on the right.

Lines **106–107**: `#mobile-ctrls .topbar{position:absolute;top:0;right:0;display:flex;gap:1px;...;z-index:22}` with `.mb{width:42px;height:20px}` × 4 buttons (`INV`, `QST`, `FEED`, `MUTE`, lines 189–192).

Actual topbar width = **4×42 + 3×1 = 171px**. Reserved = 80px. **Overlap = 91px**, at `z-index:22` vs the ticker's `21`, with an opaque `rgba(10,8,5,.92)` background. Topbar height 20px vs ticker height 18px — full vertical overlap.

So on any touch device the rightmost 91px of the ticker is covered by opaque buttons. Ticker text scrolling rightward vanishes under them mid-sentence.

**Severity.** Medium (mobile only). Trivial fix.

**GATE:** assert `#ticker`'s rect does not intersect `#mobile-ctrls .topbar`'s rect when mobile controls are displayed. One `getBoundingClientRect()` comparison.

---

## F10 — The ticker marquee never fully crosses for short lines — MEDIUM — GATE-READY

**Mechanism.** Lines **113–115**:

```css
#ticker .strip{flex:1;overflow:hidden;white-space:nowrap;position:relative;height:14px}
#ticker .tape{position:absolute;white-space:nowrap;color:var(--cream);animation:ticker 60s linear infinite;will-change:transform}
@keyframes ticker{0%{transform:translateX(100%)}100%{transform:translateX(-100%)}}
```

**`translateX(%)` resolves against the element's own width**, not its container's. So the tape travels `2 × tapeWidth`. To fully cross the strip it must travel `stripWidth + tapeWidth`. Therefore it only fully crosses when **`tapeWidth >= stripWidth`**.

For a tape shorter than the strip: at `0%` it sits at x ∈ [tapeW, 2×tapeW] — already partially inside the strip and **clipped at the strip's right edge**, rather than starting cleanly offscreen. Short news lines pop in and out mid-string instead of scrolling through.

Example: `"weather: tuesday. with a 40% chance of more tuesday."` (line **2318**) — 51 chars at 11px + 1px letter-spacing ≈ **383px**, against a desktop strip of roughly **634px**. `383 < 634` → never fully crosses, and is clipped at the right edge at animation start.

Also: the duration is a fixed `60s` regardless of length, so scroll *speed* varies with the string.

**Honest caveat.** I can prove the geometry from the CSS, but I cannot reconstruct the operator's exact screenshot frame from it. The reported `"weather: tuesday. with"` cut-off is more likely explained by F6 (the vignette blacking out the ticker) and F9 (the topbar covering it) than by this. Listing it because the geometry is genuinely wrong and is cheap to assert.

**Severity.** Medium.

**GATE:** assert `tape.scrollWidth >= strip.clientWidth` for every broadcast string, or replace the percentage translate with a pixel-based keyframe.

---

## F11 — World-space `(E)` prompts have no viewport clamping — LOW/MEDIUM

**Symptom.** "An 'E' interaction label clipped at the left edge."

**Mechanism.** Interaction prompts are drawn in **world space**, inside the camera transform, so they clip at the canvas edge like any world object:

- line **10245**: `ctx.fillText('(E)', sx + d.w/2, sy - 5);` (`drawHideoutDoors`)
- line **10273**: `ctx.fillText('(E)',4920,3196);` — hardcoded world coords (`drawOfficeExterior`)
- line **10638**: `ctx.fillText('(E) sit', p.x+p.w/2, p.y-14);`
- line **10864**: `ctx.fillText('(E) kick', p.x, p.y - 22);`

Meanwhile `drawObjectiveGuide()` at line **11234** already implements exactly the right pattern:

```js
const cx=W/2,cy=H/2,ang=Math.atan2(sy-cy,sx-cx),ex=clamp(sx,24,W-24),ey=clamp(sy,42,H-34);
```

It clamps to the viewport and rotates an arrow to point offscreen. **That pattern exists and is simply not applied to interaction prompts.**

**Severity.** Low-medium — a prompt is only clipped when the thing it labels is already at the frame edge, so the player usually walks toward it anyway. Worth fixing because the fix is a one-line reuse of `clamp`.

**GATE:** assert every world-space UI text draw is either clamped or culled — harder to assert statically (requires camera state); best as a runtime dev assertion: "no `fillText` issues with a screen x/y outside `[0,W]×[0,H]` while its target is flagged as active UI."

---

# HONEST NEGATIVES — things I checked that are NOT broken

The brief asked me to prove the absence of de-confliction rather than assume it. It also asked me to say so when I can't point at code. Both apply here.

### The landmark facade auto-fit WORKS — copy this pattern

Line **8935** is the one piece of responsive text sizing in the file:

```js
const fs=Math.max(8,Math.min(12,Math.floor((f.w-18)/Math.max(1,label.length)*1.7)));
g.font=`bold ${fs}px Courier New`; g.textAlign='center';
const tw=Math.min(f.w-18,g.measureText(label).width+14);
g.fillStyle='#12100d'; g.fillRect(x+(f.w-tw)/2,y+7,tw,16);
g.fillStyle='#c8b56f'; g.fillText(label,x+f.w/2,y+19);
```

I checked all 28 facades for text-overflows-its-own-plate: **zero violations.** The `*1.7` is the inverse of Courier's 0.6em advance (true value 1.667 — it overshoots by 2%, harmless), and `measureText` is used properly. The `Math.max(8, ...)` floor *could* overflow for a sufficiently long label on a narrow facade, but **no shipped facade triggers it**. This is the model the rest of the file should follow.

### Static text does not collide with static text

I built bounding boxes for all 75 static label draws (zone labels + building signs + building names + facade signs) using the exact geometry from the draw calls:

```
=== GATE 1: static text box vs text box ===
text boxes checked: 75   intersecting pairs: 0
```

**My "THE LA over WASH·DRY = two texts colliding" hypothesis was wrong.** The zone label is destroyed by *art* (the awning), not by other text, and it sits 76px clear of the sign plate. The real collisions in this game are **text-vs-art** (F1, F2) and **text-vs-dynamic** (F3, F4) — not static-vs-static. Worth knowing before someone builds the wrong gate.

### The billboard text fits its board — I could not find a defect

The reported **"ROOM FOR 1 / ROOM NOT IN"** does not trace to a text-fit bug. `WORLD_DECOR` line **478** defines a 116px-wide billboard with `'ROOM FOR RENT\nROOM NOT INCLUDED'`; the draw at line **8983** centres it:

```js
p.text.split('\n').forEach((line,i)=>ctx.fillText(line,p.x+p.w/2,p.y+22+i*14));
```

`"ROOM NOT INCLUDED"` = 17 chars × 5.4px (9px bold Courier) = **91.8px**, centred in a 116px board → spans 12.1→103.9. **It fits.** The likeliest explanation is F11: the billboard is a world object and was simply half off the right edge of the viewport in that frame.

**I am not going to invent a mechanism for this one.** If it reproduces with the billboard fully on-screen, it is a real finding and I missed it — but the arithmetic says the text fits its board, so I am reporting it as *not confirmed*.

### The palette and the art direction are fine

Measured, not asserted: cream `#d4c896` on asphalt `#1a1810` = **10.58:1**; on the ticker's `#0a0805` = **11.91:1**. Both far above WCAG AA's 4.5:1. **The muted browns are not the readability problem.** Every contrast failure in this audit is caused by an overlay painted on top of that palette (F6), not by the palette itself. The art direction is vindicated by the numbers.

### The day/night tint is deliberately restrained and is not a culprit

`applyDayNight()` (lines **8564–8578**) carries its own explanatory comment and honours it:

```js
// canvas drawLighting handles the heavy darkening at night.
// CSS overlay does only the subtle warm/cool tinting.
```

Daytime alpha is `0.05`; night is `0.18`. `drawLighting()` (line **10891**) returns early when `nightAmount() <= .01`, so in daylight it contributes nothing at all. `drawWeather()` (line **10952**) even *reduces* fog opacity at night specifically to protect legibility (`.72 - nightAmount()*.18`). Someone was thinking carefully about darkness here. The vignette is the outlier, not the lighting system.

---

# RECOMMENDED GATE ORDER (for the autonomous loop)

Ranked by *can this check actually fail today* × *is the fix bounded*. The first four are pure geometry — no rendering, no font metrics beyond a constant, no judgement calls. They are the safe place to start an autonomous loop.

| # | Gate | Assertion | Fails today | Fix size |
|---|---|---|---|---|
| 1 | **Building sign coverage** (F1) | every named building has a `BUILDING_STYLE` entry with a non-empty `sign` | **21/24** | data |
| 2 | **Zone label vs art** (F2) | no zone-label box intersects any building body/awning box | **1** | data/1 line |
| 3 | **Nameplate de-confliction** (F3) | no two NPC nameplate boxes intersect | **2 at spawn** | logic |
| 4 | **Text fits its wall** (F4) | `measureText(tag).width <= wall.w - margin` for all placer outputs | **~51%** | logic |
| 5 | **UI above the vignette** (F6) | no UI element's effective z-index is below `#vignette`/`#scanlines` | **all of them** | **1 line** |
| 6 | **No unmeasured plates** (F5) | no `fillRect` plate width derived from `.length * <magic>` | 2 sites | small |
| 7 | **HUD within bounds** (F8) | at N viewport sizes, HUD rects don't intersect and sit inside the canvas rect | small windows | CSS |
| 8 | **Mobile chrome disjoint** (F9) | `#ticker` rect ∩ `.topbar` rect = ∅ | **91px** | 1 line |
| 9 | **Marquee crosses** (F10) | `tape.scrollWidth >= strip.clientWidth` | short lines | CSS |
| 10 | **Contrast harness** (F6) | render + sample text pixels, assert ≥ 4.5:1 | 2.4:1 at edges | harness |

**Highest readability-per-byte:** gate 5 — one `z-index` line moves every piece of text in the game from **2.4:1 to 10.6:1**.

**Best first autonomous task:** gates 1–3. Each is a pure bounding-box or map-lookup question with a yes/no answer, each currently fails with a known count, and each has a bounded fix whose success is measured by the same gate that found it. A gate that can fail is what makes the loop safe — these can fail today, and I have the failing counts to prove it.

---

## Method note

Findings were verified by extracting the shipped `ZONES`, `BUILDINGS`, `LANDMARK_FACADES`, `GRAFFITI_LINES` and `spawnNpcs` arrays from `rock_bottom_v19.html` and reconstructing each text bounding box from the exact draw call cited. Growth figures were measured across the `rock_bottom_v4…v19.html` files in this folder. Font metrics use Courier New's monospace advance of 0.6em (the file's only text font). Contrast figures use the WCAG 2.x relative-luminance formula. The vignette blur is modelled as a linear ramp — an approximation of the Gaussian; the real curve is close but not identical, so treat the 2.4:1 figure as ±0.3 rather than exact.

Nothing in the game was modified.
