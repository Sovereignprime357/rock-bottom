# BRAIN.md — Session continuity log (append-only)

---

## Session 2026-05-26 · v12 → v13 wave 1 · repo live, housekeeping fork

### WHAT
Opened the v13 campaign with a foundation/housekeeping wave. Forked v12 → v13. Stripped a dead rank-gate collision check. Refreshed README to match reality. Locked line endings via `.gitattributes`. GitHub repo went live earlier in the session.

### WHY
The discovery pass before this wave found docs and code had drifted apart — README still claimed v3 was the shipped build (we're on v12 going into v13), DELEGATION.md still listed ~9 of 12 "out-of-scope" items that have actually been shipped, and small bits of stale code lingered after the v12 finisher work. Before any new features land in v13 (sprites, map depth, minigame variety, combat patterns — the actual top weak spots), the foundation needs to match the game. Plus: lineage hygiene. v12 untouched, edits land on v13.

### WHAT CHANGED

1. **Repo live** — `https://github.com/Sovereignprime357/rock-bottom` (private). Initial push earlier in the session covered v4..v12 + the markdown docs. CRLF/LF noise on the initial commit motivated the `.gitattributes` lock-in this wave.
2. **v12 → v13 fork** — `rock_bottom_v13.html` copied from v12. v12 left untouched as lineage.
3. **`<title>` tag** — was still "ROCK BOTTOM v11" in the v12 file (slipped past the v12 ship). Bumped to "ROCK BOTTOM v13".
4. **Dead rank-gate collision check removed** — in `updateWorld`, both collision loops had `if (b.locked && P.rank>=4 && b.x>1500 && b.x<1600) continue;`. With the v12 heist rank-gate removal, `BUILDINGS.find(b=>b.locked)` is auto-unlocked at rank 4 (line ~2799), so the outer abandoned rect drops `locked` before this skip can fire. The skip only ever applied to the interior solid rect, and the interior is content-empty — nothing inside, no shortcut value. Removed cleanly.
5. **README.md** — rewritten to match the v13 reality: single-HTML / vanilla JS / Canvas 2D / Web Audio / zero deps / double-click to play; version lineage v4..v13 preserved; design-doc index; tone line in VIBE voice. v3-era claims gone.
6. **`.gitattributes`** — `* text=auto` + explicit `*.html text eol=lf` and `*.md text eol=lf` to kill the CRLF chatter on commits going forward.

### DECIDED, REASONING

- **Why fork to v13 instead of editing v12 in place**: hard rule from CLAUDE.md — keep the lineage. Every shipped build is a checkpoint. v12 is now frozen.
- **Why remove the rank-gate skip cleanly, not refactor the rest of the rank-4 cosmetic logic**: scope discipline. Wave 1 is housekeeping, not redesign. The residual rank-4 cosmetics (boarded planks visual at line ~3422, awning gating at ~3278, window gating at ~3295, the rank-4 unlock side-effect at ~2798-2800) are visually inconsistent with the heist now being available pre-rank-4 — the building still shows "RANK 4+" boards even though Brutus Jr. is the real gate. Flagging for a later wave instead of band-aiding now.
- **Why a TONE line in the README in VIBE voice**: README is mostly ordinary copy, but a fresh agent should hear the voice once on the way in. One sentence is enough.

### TRIED, ABANDONED

- Considered also unlocking the interior solid rect (line ~285) along with the outer one at rank 4 so post-rank-4 players can walk through the building — abandoned. There's nothing inside. Building-as-impassable-prop is the simplest model. If we add interior content later, fix it then.
- Considered ripping out the rank-4 cosmetic gating (planks, "RANK 4+" label, awning suppression) in this wave — abandoned. Out of scope for wave 1 and the visual gating actually still has utility as a *visual cue* even if the mechanical gate moved to Brutus Jr. The fix is to reframe what that cue means, not delete it. Wave 3+ concern.

### COUNTEREXAMPLE HUNT

- Removing the rank-gate skip: does anything else read `b.locked` that would now fail? Grep shows references in `updateWorld` (the removed lines), `drawBuilding` (cosmetic only), the rank-4 unlock side-effect (still works — the outer rect still gets `b.locked = false` at rank 4), and the heist trigger in `tryInteract` (still works — proximity-based, no rank check). No orphan reads. No band-aid required.
- v12 saves load into v13: forward-compatible. No save schema change this wave.
- v13 title in `<title>` matches the file basename: ✓.
- `.gitattributes` doesn't break the existing committed files: text=auto + explicit eol=lf is standard, applied to new commits going forward.

### DISCOVERY PASS PUNCHLINE (from earlier this session)

The operator already has the full discovery report. Summary for continuity:
- Docs were significantly out of sync with the code. ~9 of 12 items the v3-era SPEC.md listed as "out of scope" have actually shipped (achievements, mobile touch, equipment, weather, day/night, quest log, mini-games, etc.). Updating SPEC.md to reflect this is a separate wave.
- Top weak spots flagged for the v13 campaign: discoverability, NPC sprites (still emoji), map depth (world is small for current content density), minigame variety (cook + heist + lockpick + rhythm — feels good but converges fast), combat patterns (still pure fist + space + knockback).
- These map onto the wave 2+ backlog.

### NEXT (the v13 campaign — 6 waves)

- **Wave 1** (this) — housekeeping, fork, docs, CI hygiene. SHIPPED.
- **Wave 2+** — TBD in operator's plan. The top weak-spot list above is the prioritization.

### GOTCHA

- The v12 file had its `<title>` still saying "ROCK BOTTOM v11" — a v11→v12 ship miss. Watch for this on every fork: bump `<title>` and the `SAVE_KEY` if the save schema changes (it didn't this wave).
- After this wave, there is a visible inconsistency: the abandoned building still draws "RANK 4+" boards before rank 4 even though the heist works at any rank. This is intentional debt — flagged above. A future wave should either (a) drop the cosmetic gate entirely, or (b) change the cue from "rank 4+" to "brutus jr is awake" / "the dog has nightmares" / whatever fits VIBE.
- `.gitattributes` only affects commits going forward. The v4..v12 files already in history keep whatever EOLs they were committed with. That's fine — we don't re-normalize history.

---

## Session 2026-05-23 · v11 → v12 · wire copper, build the finisher

### WHAT
Wired the copper heist into the gameplay loop and added a cooking economy on top of it. Closes the loop: steal → sell → buy supplies → cook → smoke or sell → buy more. The "finisher move."

### WHY
v11 had the copper heist mechanically complete but gated behind rank 4 (100 cred), which meant most players never saw it. v11 also had no internal rock economy — Tony was the only source. The user explicitly asked for: wire copper stealing in, plus a self-cook + buy/sell loop. The cook loop is the late-game grind that pays off all the earlier scaffolding (Barb's packets, the crate at the block, Stripe's fence, the abandoned building).

### WHAT CHANGED

1. **Abandoned-building heist** — removed the `P.rank >= 4` gate in `interact()`. Always accessible. The Brutus Jr. dialogue is the actual gate now.
2. **`P.supplies`** — new player stat. HUD slot 🧪 added. Save schema bumped 8 → 9.
3. **BAGGIE BARB** — new vendor NPC at the laundromat (x:1540, y:1190). Uses launderlady sprite (palette-tinted). Sells $5/packet, $22/5pack. Has crossword dialogue + 14-across joke pool.
4. **`cookBatchMenu()` + `doCook()`** — 4 cook modes wired into `blockMenu`. Brain modulates outcome (`bb` factor), rocked-up subtracts 0.25 from bb (shaky scientist = comedy). 12% soap chance post-roll. Cooking 3+ at once has 35% wanted+1 (smell). All cooking is THE BLOCK only (matches smoke invariant).
5. **Stripe fence** — added "sell 1 rock $6" and "sell all (3+) bulk" options to `stripeDialogue`. Tracks `P.lifetime.rocksFenced`.
6. **Quest**: `finisher` (THE FINISHER — cook a rock).
7. **Hustles**: `cook_2`, `fence_3`.
8. **Achievements**: `chef`, `arson_of_nothing`.
9. **Lore**: news ticker, VIBE.md identity table (Barb), SPEC.md cooking table.

### DECIDED, REASONING

- **Why laundromat for Barb, not a new zone**: extending an existing space preserves the grandma-camouflage joke (she's "just doing laundry"). Less code, more comedy. Soft rule #1: prefer extending existing systems.
- **Why no rank gate on heist**: the operator's intent is "this is the finisher move." A finisher you can't unlock until rank 4 isn't a finisher, it's a treadmill reward. The Brutus Jr. encounter is the real difficulty gate and stays untouched.
- **Why brain modulates cook**: gives the player a reason NOT to smoke before cooking. Self-balancing tradeoff. Also free comedy — being rocked-up makes you a worse cook, which is true.
- **Why Stripe fences at $6 (not Tony)**: Tony does not negotiate. Stripe is the rival hustler — fencing through him is in-character. Also: he can resell at $8 with 40% soap, this fits his MO.
- **Why $5 packets / 0.08-0.55 double-rock**: economy math: avg yield per packet ~1.05-1.6 rocks depending on mode/brain. At $6 fence, that's $6.30-$9.60 revenue vs $5 cost. Always positive EV but skill-dependent. Smoking them straight makes them effectively $5 rocks (vs Tony's $10) — the real value is the rocked-up uptime.
- **Why dialogue-driven cook (not a timing minigame)**: matches the existing heist + lockpick style for consistency. Adding a third UI pattern would fragment the game's feel.

### TRIED, ABANDONED

- Considered a new NPC zone ("The Cookhouse") — overbuilt. The laundromat is funnier.
- Considered making cooking a sliding-needle skill check — would have been a third minigame pattern. Cut for consistency.
- Considered making Tony also buy rocks back at $7 — broke the "tony does not negotiate" rule and his "$10. simple math." voice. Cut.

### COUNTEREXAMPLE HUNT (gates checked)

- Cook with 0 supplies → button disabled.
- Cook with rocked-up active → bb -0.25 makes burn more likely; not broken.
- Fence rocks with 0 rocks → button disabled.
- Load v8 save → forward-compatible; `P.supplies = P.supplies || 0` post-Object.assign.
- Cooking 3+ → smell wanted bump is gated by `Math.random() < 0.35`, doesn't always trigger; doesn't run on 1-packet cooks.
- The rocked-up → crash transition is untouched. Invariant 10 preserved.

### NEXT

- Unique sprite for BAGGIE BARB (currently shares launderlady palette).
- Possible: a 4th cook mode unlocked by an item (a propane torch?) — would need a vendor for it (Pete?). On the v13 backlog as speculative.
- Boss music (still v4 backlog #11).
- Tweaker vision (v4 backlog #3) interacts well with hidden cash piles already in v11; would also work for "spot the unwatched packet" — could be a passive on Barb's cart.
- Watch for cook+smoke loop becoming too dominant in late game. If it does, slightly bump brain decay during a long rocked-up streak so the player has to sleep.

### GOTCHA

- The `state.quests.finisher` field is added to the default quests object now; old v8 saves merging into it works because `Object.assign({}, state.quests, sv.quests || {})` keeps the new default if not in the save.
- `setTimeout` on the smell wanted-bump toast: chosen so the batch toast lands first, then the consequence. Watch in case browser tab loses focus.
- `audio.glassBreak()` reused for cook complete — chiptune-appropriate but if it gets too samey, write a `audio.cook()` synth (sawtooth 200→90hz, brief). v13 polish.
