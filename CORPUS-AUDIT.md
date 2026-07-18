# CORPUS-AUDIT — false-claim audit of the governing docs

**Run:** 2026-07-17, worktree `corpus-audit` at `c68d9b2`, clean.
**Method:** auditor agents, one per doc (or group of small docs), peak concurrency capped at 6 — hard cap, by design; the 114-agent run is the counterexample. Findings banked and committed per file as each agent returns, never at the end.
**Scope (priority order):** VIBE.md (400) · AGENTS.md (184) · CLAUDE.md (172) · README.md (90) · DELEGATION.md (577) · SPEC.md (1,913) — 3,336 lines of agent-facing instruction. Remaining 17 corpus files follow if budget allows.
**Rule:** every finding cites a reproduction command run against this worktree. Unproven suspicions live only in the SUSPECTED — UNPROVEN section of each file's report and are not merged into findings. Nothing was fixed; no governing doc was edited.

**Ground truth at c68d9b2 (verified during scout):**
- Current build is **v21**: `index.html` loader + `src/` ES modules (37 chunks per `src/module-manifest.json`). Latest monolith is `rock_bottom_v19.html`; v20/v21 work happened in the modular tree.
- Sprite system is true-32px art (`src/render/sprite_art_player_32.js`, `sprite_art_npc_32.js`, `sprite_art_special_32.js`; 93 bases, merged at `dbd960c`).
- VIBE.md's false art section was retracted at `df1476e`; four false SPEC invariants retired at `9208dd3`; CLAUDE.md has no commits since 2026-05-26 (`9fab80a`).

**Damage triage per finding:** *would an agent obeying this line damage the game?* HIGH = builds or deletes the wrong thing. MEDIUM = wastes a session / points work the wrong way. LOW = stale noise nobody acts on. Findings within each file sort by damage, not by count.

Sections appear in agent-completion order, not priority order. Status table:

| Doc | Lines | Status |
|---|---|---|
| VIBE.md | 400 | done — ~125 checked, 9 false (2 MEDIUM, 7 LOW) |
| AGENTS.md | 184 | done — 23 checked, 6 false (3 MEDIUM, 3 LOW) |
| CLAUDE.md | 172 | done — 26 checked, 14 false in 8 findings (4 HIGH) |
| README.md | 90 | done — 29 checked, 0 false (clean) |
| DELEGATION.md | 577 | done — 43 checked, 8 false (2 HIGH) |
| SPEC.md | 1,913 | done — 94 checked, 12 false (2 HIGH, 7 MEDIUM, 3 LOW) |

---

## README.md — 29 claims checked · 0 false · verdict: clean — every disprovable claim verified against code, filesystem, and live gate runs; the README is mechanically self-policing (docs-gate and version-gate both executed and PASS), so no findings section.

Claims verified (each by an actually-run command):

- **L13 active source / frozen reference:** `node -e "..."` on `src/module-manifest.json` → `totalChunks 37, chunks.length 37, ref rock_bottom_v19.html`. `index.html` + `src/` (core, data, dialogue, input, main.js, minigames, render, systems, ui) exist.
- **L14 / L3 zero runtime deps:** `ls package.json node_modules` → both "No such file or directory".
- **L16 saves:** `grep -rniE "indexeddb" src` → `src/core/storage.js:15-16` opens `window.indexedDB` behind the async `window.storage` API, with a null fallback when unavailable.
- **L17 mobile analog touch:** `src/input/mobile.js:24,32` — touch detection and "D-pad replaced in v11 by analog joystick".
- **L19-21 "Current shipped build" v21:** `grep -n "<title>" index.html` → line 10 `ROCK BOTTOM v21`; `node tools/version-gate.mjs` → `PASS (title, subtitle, and README all say v21)`. The paragraph's numeric load-bearing claims all check: 93 bases + 373 keys (`tools/sprite-gate.mjs:76`), eleven 16-logical environment sprites coexisting (`sprite-gate.mjs:294-296`), 28 facades and 53-structure single collision authority (solidity-gate run → `PASS (53 declared structures, 28 solid facades/0 flat, ... one collision source ...)`), world `8600×5600` (`src/data/world.js:15`), 18s/8s loop (`src/systems/concessions.js:286` `rockedT = 18000`; `src/core/update.js:130` `crashT = 8000`).
- **L25 lineage:** `ls` → `rock_bottom_v4.html` … `rock_bottom_v19.html` all present.
- **L32-35 runner:** `tools/run-gates.mjs` exists, spawns with `--experimental-vm-modules` (line 44), `GATES` array has exactly 13 entries (lines 12-37), loop breaks on first nonzero exit (lines 65-67) — "thirteen gates ... stops on the first failure" is accurate.
- **L37-51 gate table:** all 13 named gate files exist in `tools/` (`ls tools/`), and `node tools/docs-gate.mjs` → `DOCS GATE: PASS (13 gates in the runner, 13 documented, all present on disk, both lists agree)`. Per-gate detail claims spot-checked: sprite-gate "14 frozen draw sites" (`sprite-gate.mjs:404` PASS string), legibility-gate "four measured relationships" (`grep -oE "Gate [0-9]"` → Gates 1-4 covering buildings/zones/nameplates/graffiti), solidity-gate `--full` flag and 69/252 ledger (`solidity-gate.mjs:24,790,836`; full gate run → `PASS (... 69 campaign legs, 252 assignable route pairs, 0 new budget crossings)`).
- **L55-64 design-doc inventory:** `ls` → `VIBE.md`, `SPEC.md`, `AGENTS.md`, `DELEGATION.md`, `BRAIN.md` all present; the "read order" pointer chain (README → VIBE.md) resolves to a real file.
- **L88-90 release:** `head -5 LICENSE` → "MIT License / Copyright (c) 2026 Sovereign Prime (VibeKoded)". "static HTTP hosting is required for native modules" is consistent with the ES-module `index.html` loader (no recombined `file://` build exists in the repo).

Notes on non-findings: L15's how-to-run (`python -m http.server`) is a generic instruction consistent with the module architecture; L51's world-gate description does not claim the gate is green (and `run-gates.mjs:32-36` documents it may read red by design, which the README's "stops on the first failure" wording does not contradict). The one file-inventory divergence in this repo — `CLAUDE.md` exists but describes an obsolete single-HTML layout — is a defect of CLAUDE.md, not of README.md, which correctly points at `AGENTS.md` and never mentions CLAUDE.md.

### SUSPECTED — UNPROVEN
- The historical anecdotes (L40 "README once claimed four gates while seven ran", L41 the v19-label evening, L53 the 2026-07-16 stale-mount / 508-deletion incident) are corroborated by identical comments in `tools/run-gates.mjs:14-21` but the underlying events are not independently verifiable from git history by command; no evidence they are false, so not findings.
- L83 "Architect: Claude (Opus 4.7)" — an attribution, not disprovable by any repo command.

---

## DELEGATION.md — 43 claims checked · 8 false · verdict: historical sections (v3–v19) are accurate down to the SHA-256, but the two "live" sections at the top are stale — every v20/v21 branch is already merged into HEAD, and two items still listed as pending/backlog are fully shipped in src

### F-DELEG-1 · DAMAGE: HIGH
- **Where:** DELEGATION.md:21
- **Claim:** "- [ ] **Landing 2 — THE REGULAR.** Implement the four-venue recognition ledger, additive persistence, tier acknowledgments, visit de-duplication, full-high boundary credit, Q ledger, pattern cap, and dedicated recognition gate."
- **Disproof:** `git log --oneline HEAD | grep -i regular` → `ccdbf75 merge: THE REGULAR recognition system (SPEC-V20-PACKET #1) - 6/6 gates green` (ancestor of HEAD); `grep -n "REGULAR_TIERS\|REGULAR_VENUES" src/systems/recognition.js` → `REGULAR_TIERS = ['stranger','counted','furniture','conceded']` with per-venue ledger and thresholds; `ls tools/` → `recognition-gate.mjs` exists.
- **Actually:** Landing 2 is built, gated, and merged into the current build (`src/systems/recognition.js` + `tools/recognition-gate.mjs`, merged from `v20-regular` at ccdbf75).
- **If obeyed:** An agent picking top-down would rebuild the entire recognition system from scratch — a second ledger, colliding save keys, a duplicate gate — on top of the one already live and depended on by the merged Landing 3 concessions (`conceded` tier gates the four smoke rooms).

### F-DELEG-2 · DAMAGE: HIGH
- **Where:** DELEGATION.md:446
- **Claim:** "### 9. Co-op Ending with Stripe / **Status:** Backlog"
- **Disproof:** `grep -rn "spawnCoopBoss\|coopMode" src` → `src/dialogue/neighborhood_b.js:277:export function spawnCoopBoss()`, `src/systems/npc_ai.js:86: // ally AI (stripe in coop)`, `src/systems/interactions.js:31: 'you and stripe split the corner · you get the slow days'`.
- **Actually:** The co-op ending is fully implemented in the current build — Stripe's team-up dialogue, `state.coopMode`, ally AI, and a dedicated "TUESDAYS AND THURSDAYS" ending screen. DELEGATION.md line 74 (v17) even references "Tony/co-op/bus ending receipts" as shipped.
- **If obeyed:** An agent working the MEDIUM-priority list would build a duplicate co-op ending path — a second Stripe trigger and a conflicting Tony fight variant — regressing the boss fight (Hard Rule 7/8 territory) and duplicating an ending that already persists in saves.

### F-DELEG-3 · DAMAGE: MEDIUM
- **Where:** DELEGATION.md:16-18
- **Claim:** "## v20 recognition wave — IN PROGRESS (July 15, 2026) … Active implementation branch: `codex/v20-recognition`."
- **Disproof:** `git branch --merged HEAD` → `codex/v20-recognition` listed (fully merged); its tip `e37faf2 v20: deconflict HUD and unify unique cart` is Landing 1 work, already in HEAD.
- **Actually:** All five v20 landings are merged into the current branch's history (ccdbf75, ad96cbe, cd5d716); `codex/v20-recognition` is a stale, fully-merged branch. Nothing in the v20 wave is in progress.
- **If obeyed:** An agent would check out a stale branch behind main and implement v20 work against a pre-recognition, pre-concessions codebase, producing a divergent lineage that conflicts on merge.

### F-DELEG-4 · DAMAGE: MEDIUM
- **Where:** DELEGATION.md:9 (and header line 7)
- **Claim:** "Branch: `v21-sprite-ceiling`, isolated worktree; push without merge."
- **Disproof:** `git merge-base --is-ancestor v21-sprite-ceiling HEAD && echo MERGED` → `MERGED`; `git log --oneline HEAD` → `dbd960c merge: v21 Wave 4.2 — the character ceiling is gone (93 bases at true 32px) — 13/13 green`.
- **Actually:** Wave 4.2 was merged at dbd960c; the branch is an ancestor of HEAD. The "push without merge" instruction and the isolated-worktree framing describe a state that ended two commits before the operator's v22 packet.
- **If obeyed:** An agent doing sprite follow-up would work in the dead worktree branch and deliberately withhold the merge, forking the 93-base sprite art away from the live build.

### F-DELEG-5 · DAMAGE: MEDIUM
- **Where:** DELEGATION.md:30
- **Claim:** "Branch: `v21-honest-map`, isolated worktree; push without merge. OD-11 is the signed physicality and traversal ruling."
- **Disproof:** `git merge-base --is-ancestor v21-honest-map HEAD && echo MERGED` → `MERGED`; HEAD log contains `52a6c1a merge: v21 Wave 4.1 — the honest map (OD-11) — 11/11 green`.
- **Actually:** Wave 4.1 merged at 52a6c1a; the section header's "PENDING OPERATOR REVIEW" and the push-without-merge instruction are stale.
- **If obeyed:** Same failure as F-DELEG-4 — collision/solidity follow-up work would land on a stale unmerged branch instead of the live merged source.

### F-DELEG-6 · DAMAGE: MEDIUM
- **Where:** DELEGATION.md:22, 23, 24
- **Claim:** "(Built on `v20-concessions`, 2026-07-16 — pending operator review/merge.)" — repeated verbatim ("`v20-world`") on Landings 4 and 5.
- **Disproof:** `git log --oneline HEAD | grep merge` → `ad96cbe merge: smoke concessions (SPEC-V20-PACKET section 2 / OD-5) - 8/8 gates green` and `cd5d716 merge: world relationships + route budget (SPEC-V20-PACKET section 3 / OD-9, OD-10) - 9/9 green`, both ancestors of HEAD.
- **Actually:** Landings 3, 4, and 5 are all merged into the current build; `src/systems/concessions.js` and `tools/world-gate.mjs` are live on HEAD. Nothing is pending merge.
- **If obeyed:** An agent would treat the live concessions/world-gate code as unreviewed branch work — re-merging, re-reviewing, or basing changes on the branches instead of HEAD.

### SUSPECTED — UNPROVEN
- DELEGATION.md:12 — "[ ] Operator eye gate" (Wave 4.2 visual review) is unchecked, yet the operator merged Wave 4.2 at dbd960c and then banked a v22 ideas packet (c68d9b2), which suggests the review happened. Human review cannot be disproven by command, so it stays unproven.
- DELEGATION.md:32 — "Permanent suite: 11 gates" was true at merge 52a6c1a but the current suite is 13 (dbd960c "13/13 green"). Read as historical narration of that wave it is accurate; flagging only that a fresh agent skimming this section could expect an 11-gate runner.

Notes on what checked out TRUE (no findings): the frozen v19 reference hash at line 38 matches exactly (`Get-FileHash rock_bottom_v19.html` → `C25DB5E1…4A25C8B`); `REFACTOR-FINDINGS.md` and `SPEC-V20-PACKET.md` exist as referenced; the four items genuinely still marked Backlog that were disprove-hunted (boss music, per-zone ambient audio, New Game+) have zero matching symbols in `src/` — those statuses are honest; all "Shipped in v13 / before v14" backlog corrections (graffiti, tweaker vision, equipment, cart, heat minigame, day/night) have live symbols in `src/`.

---

## CLAUDE.md — 26 claims checked · 14 false (grouped into 8 findings) · verdict: the file's discipline rules (SpecMesh, storage, audio-on-interaction, the 18s→8s loop, tone rules) still hold, but its entire picture of the build — version, architecture, sprite format, NPC aesthetic, identifiers, ship procedure — is one full generation stale and four of its lines are active orders to destroy shipped v21 work.

### F-CLAUDE-1 · DAMAGE: HIGH
- **Where:** CLAUDE.md:15-16 (restated at CLAUDE.md:132)
- **Claim:** "Everything in one file: HTML, CSS, JS, sprites, audio. No external dependencies. No CDN imports. No build step. The whole game must be openable by double-clicking the file."
- **Disproof:** `grep -n "module" index.html` → `251:<script type="module" src="./src/main.js"></script>`; `node -e "const m=require('./src/module-manifest.json'); ..."` → `{"reference":"rock_bottom_v19.html",...,"extractedCount":37,"totalChunks":37,...}`
- **Actually:** The active build is `index.html` + 37 extracted ES-module chunks under `src/` (frozen v19 monolith kept only as the hash-pinned behavioral reference). Native ES modules do not load over `file://`, so the double-click requirement is dead too; DELEGATION.md records the monolith rule as deliberately retired ("index.html as the zero-dependency HTTP entry").
- **If obeyed:** An agent would re-inline 38 modules into a single HTML file, destroying the modular refactor, its `module-gate` parity proof, and every `tools/*.mjs` gate that reads `src/`.

### F-CLAUDE-2 · DAMAGE: HIGH
- **Where:** CLAUDE.md:64-65 (and the premise repeated at CLAUDE.md:125)
- **Claim:** "v3 has pixel-art player + emoji NPCs. This is the look. Adding pixel-art NPCs is on the v4 backlog (DELEGATION.md item 1)"
- **Disproof:** `grep -rln "emoji" src/` → only hit is a historical comment `src/render/sprites.js:781: // v13 wave 2 — converting the last four emoji-era styles...`; `ls src/render/` → `sprite_art_npc_32.js` exists; `head -60 DELEGATION.md` → item 1 is "v21 character ceiling — BUILT... All 93 character bases... true 32-logical palette grids"
- **Actually:** Emoji NPCs were eliminated by v13 and every character is now hand-authored 32px pixel art (93 bases, merged at dbd960c). DELEGATION.md item 1 is the completed v21 sprite-ceiling wave, not an NPC-conversion backlog item. Escalation trigger #1's premise "the emoji are the look" (line 125) is equally dead.
- **If obeyed:** An agent would add new NPCs as emoji "to match the look" — breaking the unified 93-base pixel roster and failing `sprite-gate`/`npc-registry-gate` — or treat the shipped pixel-art migration as the revert-worthy violation described in line 125.

### F-CLAUDE-3 · DAMAGE: HIGH
- **Where:** CLAUDE.md:24-27
- **Claim:** "16×16 logical, prerendered to offscreen canvas at init / Scaled 2x to 32×32 display / Palette-indexed (numbered string format, see PLAYER_SPRITES)"
- **Disproof:** `head -30 src/render/sprite_art_player_32.js` → `const SIZE = 32;` with a validator throwing unless grids are "an explicit 32x32 grid" of integers 0-7; `grep -rn "PLAYER_SPRITES" src/ index.html` → no matches
- **Actually:** Character sprites are true 32-logical integer palette grids (only eleven environment sprites remain 16-logical per DELEGATION.md, and `sprite_toolkit.js` accepts exactly {16, 32}). `PLAYER_SPRITES` and the "numbered string format" no longer exist; art lives in `src/render/sprite_art_player_32.js` / `sprite_art_npc_32.js` / `sprite_art_special_32.js`. (`SPRITE_CACHE` and the `ctx.drawImage` rule at lines 28-29 are still true.)
- **If obeyed:** An agent would author any new character sprite as a 16×16 numbered string — the exact format `sprite-gate` red-verifies against — regressing the v21 character ceiling and failing the 13/13 suite.

### F-CLAUDE-4 · DAMAGE: HIGH
- **Where:** CLAUDE.md:111 (and 117)
- **Claim:** "Save the updated HTML file as `rock_bottom_v{N+1}.html` (NOT overwriting v3 — keep the lineage)"
- **Disproof:** `ls rock_bottom_v*.html | sort -V` → `rock_bottom_v4.html` … `rock_bottom_v19.html` (no v3, and nothing past v19); `head -15 tools/version-gate.mjs` → "version-gate.mjs — the game must not lie about which game it is"
- **Actually:** v4-v19 monoliths are frozen history; v20/v21 shipped as commits to `index.html` + `src/` with the displayed version enforced by `tools/version-gate.mjs`. There is no v3 to avoid overwriting and no "updated HTML file" to save.
- **If obeyed:** An agent would flatten the modular build into a new `rock_bottom_v22.html` monolith at session end, forking the codebase away from the gated `src/` tree and shipping an artifact no gate covers.

### F-CLAUDE-5 · DAMAGE: MEDIUM
- **Where:** CLAUDE.md:3
- **Claim:** "You are picking up a satirical action game in mid-build. Operator is Sovereign Prime (VibeKoded). v3 is shipped."
- **Disproof:** `grep -n "<title>" index.html` → `10:<title>ROCK BOTTOM v21</title>`
- **Actually:** Current shipped build is v21 (Wave 4.2 merged at dbd960c); v3 predates even the oldest monolith in the repo (v4).
- **If obeyed:** An agent calibrates every decision to a ~18-version-old game state — expecting a small single-file project with a v4 backlog, and misreading 17 gate scripts and 38 modules as someone else's scope creep.

### F-CLAUDE-6 · DAMAGE: MEDIUM
- **Where:** CLAUDE.md:153-164
- **Claim:** "```/rock_bottom/ ├── README.md ├── VIBE.md ├── SPEC.md ├── CLAUDE.md ├── DELEGATION.md ├── BRAIN.md └── rock_bottom_v{N}.html```" (presented as the complete file system for handoffs)
- **Disproof:** `ls -la` → repo also contains `index.html`, `src/` (10 module dirs), `tools/` (17 scripts incl. `run-gates.mjs`), `AGENTS.md`, 8 `SPEC-*.md` packet files, `DELEGATION-CODEX.md`, `reports/`, `screenshots/`, `uploads/`, plus five audit docs
- **Actually:** The listed six docs exist, but the map omits the entire active game source (`src/`), the mandatory verification suite (`tools/`), and the second agent-instruction file (`AGENTS.md`).
- **If obeyed:** A handoff agent trusting this map never discovers `tools/run-gates.mjs` or the SPEC packets, and ships changes without running the 13-gate suite the project actually requires.

### F-CLAUDE-7 · DAMAGE: LOW
- **Where:** CLAUDE.md:33-35 (also 54, 59, 22)
- **Claim:** "`updatePlayer` timing / `rockedUpTimer` / `crashTimer` / `sfx.rockUp` / `sfx.crash`" (and line 22's "Track `audioReady` boolean to gate all `beep()` calls", line 59's "synth function in the `sfx` object")
- **Disproof:** `grep -rn "rockedUpTimer\|crashTimer\|updatePlayer\|audioReady\|sfx\.rockUp" src/` → no matches; `grep -rn "rockedT\|crashT" src/core/update.js | head -3` → `78: if (P.rockedT>0) spd *= 1.8;` and `130: P.rockedT = 0; P.crashT = 8000;`; `sed -n 225,260p src/core/audio_save.js` → `audio = { ctx: null, ready: false, ... tone(freq,...)`
- **Actually:** The mechanics the rule protects are intact — 18s high → 8s crash is live (`P.rockedT = 18000` at src/systems/concessions.js:286, `P.crashT = 8000`, `smoke a rock` option at concessions.js:250, `audio.init()` called from keydown/click in src/input/keyboard.js) — but every named identifier drifted: `P.rockedT`/`P.crashT`, `audio.rockUp()`/`audio.crash()`, `update()`/`updateWorld()`, `audio.ready` gating `tone()`/`noise()`.
- **If obeyed:** Mostly wasted time — an agent greps for the named symbols, finds nothing, and may wrongly conclude the rocked-up loop or audio gating was removed and "restore" a duplicate system.

### F-CLAUDE-8 · DAMAGE: LOW
- **Where:** CLAUDE.md:89
- **Claim:** "All sprite IDs, NPC IDs, function names use snake_case in this codebase. Match the existing convention."
- **Disproof:** `grep -rn "export function smokeRockAt\|function rollBlockRoute" src/` → `src/systems/concessions.js:270:export function smokeRockAt(spotId)` and `src/systems/progression_routes.js:127:function rollBlockRoute(...)`
- **Actually:** Function names are predominantly camelCase throughout `src/` (sprite cache keys and NPC ids do use snake_case; the "function names" third of the claim is false).
- **If obeyed:** New code written in snake_case functions clashes with the real convention, or worse, an agent "fixes" existing camelCase exports and breaks cross-module imports.

### SUSPECTED — UNPROVEN
- Hard Rule 8 ("boss fight defeatable in <90 seconds"): boss code exists in `src/core/update.js`/`src/data/world.js`, but no command can measure a competent player's clear time; neither provable nor disprovable here.
- CLAUDE.md:117 "Present the new HTML file via `present_files`": `present_files` is a claude.ai artifact-environment tool whose availability in the current Claude Code environment cannot be tested by a repo command; its premise (a single new HTML file per session) is already disproven in F-CLAUDE-4.
- Hard Rule 4's rationale ("Claude.ai artifacts do NOT support localStorage") is unverifiable from the repo, but the rule itself is TRUE in practice: code uses `window.storage` exclusively with an IndexedDB-backed shim (`src/core/storage.js`), and `module-gate` checks forbidden storage APIs. Likewise TRUE and worth recording: Hard Rules 1/2/5 (in substance), the 18s→8s loop, `SPRITE_CACHE`, `npc.wander`/`hostile`/`zoneOnly`, DOM HUD/dialogue/toast, and the existence of BRAIN.md and VIBE.md's identity table (VIBE.md:280).

---

## AGENTS.md — 23 claims checked · 6 false · verdict: the 2026-07-15 rewrite got the big things right (modular v21 architecture, v19 frozen reference, IndexedDB-backed window.storage, declared-size sprite pipeline, hash-pinned palettes, 18s/8s loop timing all verify), but the file still carries v3-era phantom identifiers that exist in no preserved build, plus stale status/backlog/naming lines.

### F-AGENTS-1 · DAMAGE: MEDIUM
- **Where:** AGENTS.md:34-41 (also referenced at line 57)
- **Claim:** "If you touch any of: `updatePlayer` timing / `rockedUpTimer` / `crashTimer` / `sfx.rockUp` / `sfx.crash` … play it end-to-end before shipping."
- **Disproof:** `rg -n "rockedUpTimer|crashTimer|updatePlayer|sfx\." src/` → no matches; `Select-String rock_bottom_v19.html, rock_bottom_v4.html -Pattern 'rockedUpTimer|sfx\.rockUp|updatePlayer'` → 0 hits in both monoliths
- **Actually:** The loop lives in `P.rockedT` / `P.crashT` (src/core/update.js:127-130, src/systems/concessions.js:286) and `audio.rockUp` / `audio.crash` (src/core/audio_save.js:269,272); the player update is `update()`/`updateWorld()` in src/core/update.js. None of the five named identifiers exist in any preserved build (v4 through v19 or src/). The 18s→8s timing itself is TRUE (`P.rockedT = 18000`, `P.crashT = 8000`).
- **If obeyed:** An agent greps the listed tripwire names, finds nothing, and concludes the mandatory end-to-end playtest doesn't apply — then edits the real `rockedT`/`crashT` decay in update.js without testing the comedic core loop the rule exists to protect.

### F-AGENTS-2 · DAMAGE: MEDIUM
- **Where:** AGENTS.md:22
- **Claim:** "Track `audioReady` boolean to gate all `beep()` calls."
- **Disproof:** `rg -n "audioReady|beep\(" src/ rock_bottom_v19.html` → no matches anywhere
- **Actually:** The gate is `audio.ready` (src/core/audio_save.js:230), checked inside every synth method (`if (!this.ready || this.muted) return;`); the primitives are `tone()` and `noise()`, not `beep()`. The underlying rule (init audio in a user-interaction handler) is real and honored.
- **If obeyed:** An agent adding a sound introduces a new global `audioReady` boolean and `beep()` wrapper parallel to the existing `audio.ready` gating — duplicate audio state that can desync mute/init behavior.

### F-AGENTS-3 · DAMAGE: MEDIUM
- **Where:** AGENTS.md:62
- **Claim:** "write it as a synth function in the `sfx` object"
- **Disproof:** `rg -n "const sfx|sfx\s*=|sfx\." src/` → no matches; `rg -n "audio = \{" src/core/audio_save.js` → line 228 `audio = {`
- **Actually:** There is no `sfx` object in src/ or in rock_bottom_v19.html. All synth functions (`rockUp`, `crash`, `copSiren`, `bossRoar`, etc.) live on the `audio` object created in `init_audio_save()` (src/core/audio_save.js:226-284).
- **If obeyed:** An agent literally creates a new `sfx` object for new sounds — a second audio system alongside `audio`, unwired to its `ready`/`muted` gating and to first-interaction init.

### F-AGENTS-4 · DAMAGE: LOW
- **Where:** AGENTS.md:3
- **Claim:** "v3 is shipped."
- **Disproof:** `rg -n "<title>" index.html` → `<title>ROCK BOTTOM v21</title>` (and README.md:25: "v3 was the original public ship; v19 is now the frozen monolithic reference")
- **Actually:** Current shipped build is v21 (index.html loader + 37 src/ chunks per src/module-manifest.json); v3 isn't even in the repo — preserved monoliths start at rock_bottom_v4.html. Rule 3 in the same file states the v19/modular reality correctly, so the header contradicts its own body.
- **If obeyed:** A fresh agent misdates the project by ~18 versions, may hunt for a nonexistent rock_bottom_v3.html as the shipped baseline, and misreads how much of the surrounding guidance is v3-era.

### F-AGENTS-5 · DAMAGE: LOW
- **Where:** AGENTS.md:107
- **Claim:** "Check DELEGATION.md. If your idea isn't on the v4 list, ask the operator before building it."
- **Disproof:** `rg -n "^## v4|^## v2[01]" DELEGATION.md` → v20/v21 sections at lines 7-30 are the active items; the "## v4 — HIGH PRIORITY" list at line 332 has every item marked shipped (line 335: "**Status:** Shipped in v13")
- **Actually:** The v4 list is a fully-shipped historical ledger; the live prioritized backlog is the v20/v21 waves and SPEC-V22-PACKET.md.
- **If obeyed:** An agent gates scope against a dead list — either treats long-shipped v4 items as sanctioned pending work, or needlessly escalates every item actually on the live v21/v22 backlog as "not on the v4 list."

### F-AGENTS-6 · DAMAGE: LOW
- **Where:** AGENTS.md:94
- **Claim:** "All sprite IDs, NPC IDs, function names use snake_case in this codebase."
- **Disproof:** `rg -c "^(export )?function [a-z]+[A-Z]" src/` → 396 camelCase function declarations across 41 files (vs 40 snake_case, which are almost entirely the per-module `init_*` entry points)
- **Actually:** Sprite/NPC IDs are snake_case (`scrap_dog`, `os_brutus`, `dave_sleep`) — that part is true — but function names are overwhelmingly camelCase (`cacheSprite`, `makeNpc32`, `updateWorld`, `blankSpriteGrid`).
- **If obeyed:** An agent writes new functions in snake_case, diverging from the dominant convention the same sentence tells it to match.

### SUSPECTED — UNPROVEN
- Lines 43-47 (boss defeatable <90s; <16ms frame at 60+ NPCs): performance/playability targets not verifiable by static command; no evidence for or against.
- Line 65 ("The HUD, dialogue, and toast are DOM. Everything else is canvas."): spot checks were consistent but the auditor did not exhaustively enumerate DOM gameplay UI; no disproof found.

---

## BRAIN.md — 18 claims checked · 2 false · verdict: overwhelmingly accurate; both findings are stale-against-code lines superseded later in the file itself, and historical session narration (the bulk of the 1,943 lines) was out of scope

### F-BRAIN-1 · DAMAGE: LOW
- **Where:** BRAIN.md:1808 (same claim at 1790 and 1822)
- **Claim:** "Next: operator reviews and merges v20-world (landings 4+5 together, per instruction — not merged here)."
- **Disproof:** `git log main --oneline | Select-String world` → `cd5d716 merge: world relationships + route budget (SPEC-V20-PACKET section 3 / OD-9, OD-10) - 9/9 green`
- **Actually:** v20-world (Landings 4+5, world-gate + route budget + OD-10 invariants) was merged to main at cd5d716; the current runner streams world-gate and reports 13/13 PASS. BRAIN never records the merge — the last three explicit statements about it all say "pushed, not merged" / "pending," and DELEGATION.md:23-24 corroborates the stale "pending operator review/merge" status.
- **If obeyed:** An agent would attempt to review/merge an already-merged branch (git no-ops with "Already up to date") or, worse, report to the operator that landings 4+5 are still absent from main and try to re-land or cherry-pick them, risking duplicate gate wiring.

### F-BRAIN-2 · DAMAGE: LOW
- **Where:** BRAIN.md:1142
- **Claim:** "`LANDMARK_FACADES` are visual-only by design. Do not silently add them to `BUILDINGS`; NPCs need shared collision first."
- **Disproof:** `Select-String -Path src/data/world.js -Pattern "solid:true" | Measure-Object` → 28 (every facade declares `solid:true`); and src/systems/physicality.js:22 reads `STRUCTURES=Object.freeze([...BUILDINGS,...LANDMARK_FACADES]);`
- **Actually:** Wave 4.1 (v21 honest map, merged 52a6c1a) made all 28 facades solid via the shared `STRUCTURES` authority, with player, projectile, NPC, and cop collision — the "NPCs need shared collision first" precondition was satisfied and the design reversed. The GOTCHA is written as a standing design rule and is corrected only by the Wave 4.1 entry 700 lines later.
- **If obeyed:** An agent would treat facades as walk-through scenery — authoring props/actors/paths inside them or "restoring" non-solid behavior — reintroducing the exact ghost-building defect Wave 4.1 retired; tools/solidity-gate.mjs would go red, tempting a gate "fix" instead of a content fix.

### SUSPECTED — UNPROVEN
- BRAIN.md:1756 "Game is live at sovereignprime357.github.io/rock-bottom (index 200, src/main.js 200)" — network claim, not verified from this audit (read-only, no fetch); could have gone stale since 2026-07-16.
- BRAIN.md:1632/1722 "Live visual/audio QA is still pending" — the Wave 4.2 entry later mentions the live modular build rendering with screenshots preserved, so the "still pending" status may be partially superseded, but no command can prove whether the operator's feel pass ever happened.

Notes on verification coverage (all confirmed TRUE, not findings): frozen v19 SHA-256 matches `C25DB5E1…` exactly (Get-FileHash); full suite runs 13/13 PASS today with corpus-gate first and world-gate last as claimed; runner had exactly 11 gates at the Wave 4.1 merge and 13 at the Wave 4.2 merge, matching both entries' "11/11" and "13/13"; `WORLD = { w: 8600, h: 5600 }` at src/data/world.js:15, `baseSpeed = 2.2` at src/core/runtime_ui.js:33, and the 0.0008 withdrawal rate all match the OD-9 premise check; `SAVE_KEY = 'rockbottom_save_v8'` at src/core/audio_save.js:303; the v13-era internal citations spot-checked clean (`WORLD = { w: 4400, h: 3400 }` at rock_bottom_v13.html line 253; "the door is chained" refusal copy present); SPEC-v20-route-budget.md exists on main; no src module exceeds 1,000 lines; and the "38 native ES-module files" claim was true at the PR #1 merge (`git ls-tree -r bac3a24 -- src` → 38 JS files). The 16×16-logical sprite statements at BRAIN.md:1608 were true when written and are explicitly superseded by the Wave 4.2 entry in the same file, so they were not counted as findings.

---

## SPEC.md — 94 claims checked · 12 false · verdict: the v20/v21 contracts, gate descriptions, kingdom/office/concession/recognition constants, and Wave 4.2 sprite contract all verify accurate against src/ and tools/ (checked exhaustively); the falsehoods concentrate in the unversioned mid-file "current state" sections (WHAT, COMBAT, STATUS EFFECTS, SAVE/LOAD, RESOURCES, PERFORMANCE BUDGETS, API DEPENDENCIES) that still describe the v13-era monolith and were never updated; v13–v18 wave sections were spot-checked as historical narration only.

### F-SPEC-1 · DAMAGE: HIGH
- **Where:** SPEC.md:843
- **Claim:** "Top-down action RPG built as a single HTML file. … Sixteen-zone, 4400×3400 walkable neighborhood with camera following the player on an 800×600 viewport."
- **Disproof:** `rg -n "WORLD = " src/data/world.js` → `15:  WORLD = { w: 8600, h: 5600 };`; `rg -c "id: '" src/data/world.js` → `23`; `rg -n "script type" index.html` → `251:<script type="module" src="./src/main.js">`
- **Actually:** Current build is a 17KB index.html loader plus ES modules in src/ (37 chunks); 23 zones; world is 8600×5600 (grown v18→v19).
- **If obeyed:** An agent would treat the seven post-v17 districts and the kingdom campaign area as out-of-spec, clamp world constants back to 4400×3400 (stranding every v19 coordinate), or try to re-inline the modular build into one file.

### F-SPEC-2 · DAMAGE: HIGH
- **Where:** SPEC.md:1113
- **Claim:** "version: 3," (save shape: `{ version: 3, player, npcsKilled, bossActive }`)
- **Disproof:** `sed -n 21,23p src/core/audio_save.js` → `version: 10,` followed by a ~40-field payload; no `bossActive` field exists.
- **Actually:** Save version is 10 (also confirmed by SPEC's own landing-3 text "save key and version 10 unchanged"); payload includes kingdom, office, districtClaims, recognition-era fields; `bossActive` is not serialized.
- **If obeyed:** An agent "normalizing" saves to the documented shape would write version 3 and drop dozens of fields, corrupting every real save; a validator would reject all correct version-10 saves.

### F-SPEC-3 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1097 (also 886)
- **Claim:** "Decay: -1 every 30 seconds (paused while wanted = 0)"
- **Disproof:** `sed -n 485,487p src/systems/combat.js` → `// decay -1 every 18s (faster with collar)` / `if (P.wantedT >= 18000) { P.wantedT = 0; P.wanted--; }`
- **Actually:** Wanted decays -1 every 18,000ms (modulated by the priest-collar multiplier).
- **If obeyed:** An agent would "fix" the timer to 30s, lengthening cop pressure ~67% and silently rebalancing arrest/boss-window difficulty.

### F-SPEC-4 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1099
- **Claim:** "Cops have 80 HP, 1.8 speed, 18 damage, 500px vision range"
- **Disproof:** `sed -n 505,508p src/systems/combat.js` → cop spawn record: `hp:60, maxHp:60, speed:1.5, dmg:10, hostile:true, aggro:true`
- **Actually:** Cops spawn with 60 HP, 1.5 speed, 10 damage, and are aggro from spawn (no vision-range check found).
- **If obeyed:** An agent would buff cops 33–80% across three stats, breaking wanted-level balance and the sub-90s boss margins during any fight with heat active.

### F-SPEC-5 · DAMAGE: MEDIUM
- **Where:** SPEC.md:883
- **Claim:** "Climbs +0.0025/ms passively, +0.05/ms sprinting" (Shakes)
- **Disproof:** `rg -n "shakes \+=" src/core/update.js` → `111:  P.shakes += 0.0008 * dt;` / `112:  if (sprinting && (vx||vy)) P.shakes += 0.012 * dt;`
- **Actually:** Passive rate is 0.0008/ms (0.8/s) and sprint adds 0.012/ms — exactly the 0.8 shakes/s the landing-4 world-gate measures and bakes into its 100s/13,750px runway derivation (SPEC.md:1868 agrees with the code; line 883 contradicts both).
- **If obeyed:** An agent would triple withdrawal speed, shrinking the fresh-save runway from 100s to 32s and putting the entire measured route/coverage budget system (world-gate) into contradiction.

### F-SPEC-6 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1376–1379
- **Claim:** "Model: `claude-sonnet-4-20250514`" / "Max tokens: 400" / "Failure mode: silent fallback (\"the possum is busy. try again later.\")"
- **Disproof:** `rg -in "claude-sonnet|max_tokens|the possum is busy" src/` → no matches; `sed -n 529,537p src/dialogue/neighborhood_a.js` → `window.claude.complete({ messages: [...] })` raced against a 1800ms timeout, fallback preloaded from `LOCAL_POSSUM_PROPHECIES`.
- **Actually:** The Possum call passes no model and no max_tokens, and the failure mode is a random authored local prophecy (the v17 standalone contract), never a "possum is busy" dead-air line.
- **If obeyed:** An agent would add a model/max_tokens parameter the artifact runtime does not accept, or "restore" the dead-air fallback line, violating the v17 rule that a failed completion never produces dead content.

### F-SPEC-7 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1738–1739
- **Claim:** "`node tools/run-gates.mjs` launches, in order, `module-gate.mjs`, `npc-registry-gate.mjs`, `legibility-gate.mjs`, `presentation-gate.mjs`, and `runtime-smoke.mjs` … Five successful children produce a 5/5 PASS summary."
- **Disproof:** `rg -n "'.*\.mjs'" tools/run-gates.mjs` → 13-entry GATES array: corpus, docs, version, module, sprite, npc-registry, legibility, presentation, recognition, concession, solidity, runtime-smoke, world.
- **Actually:** The launcher runs 13 gates (13/13 PASS), beginning with corpus/docs/version gates and ending with world-gate — consistent with merge commit dbd960c "13/13 green".
- **If obeyed:** An agent reconciling the launcher to this contract would delete eight gates — including the sprite, concession, solidity, and world gates that enforce the newest invariants — gutting the verification suite while it still prints PASS.

### F-SPEC-8 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1323
- **Claim:** "**The Block is the canonical smoke spot** — rocks cannot be smoked elsewhere"
- **Disproof:** `rg -n "SMOKE_SPOTS = " src/systems/concessions.js -A6` → five frozen spots (`block`, `park`, `choir_office`, `underpass`, `laundromat`); `rg -n "rockedT = 18000" src/` → concessions.js:286 fires at any legal spot.
- **Actually:** Since v20 landing 3, four earned conditional concession spots legally smoke rocks; the OD-5 amendment (SPEC.md:1828) supersedes this line but the line itself — inside a list headed "These properties MUST hold across all builds" — was never edited.
- **If obeyed:** An invariant-checking agent scanning this list would flag the entire shipped concession system (and its gate) as a spec violation and could rip out correct, operator-ratified code.

### F-SPEC-9 · DAMAGE: MEDIUM
- **Where:** SPEC.md:1362 (also 1363, 1367)
- **Claim:** "Character/player `SPRITE_CACHE` | ≤ 360 prerendered 16×16-derived canvases" (and "≤ 48" env canvases, "File size (total HTML) | ≤ 185KB gzip")
- **Disproof:** `rg -n "373" tools/sprite-gate.mjs` → `76:if(EXPECTED_BASES.length!==93||EXPECTED_KEYS.length!==373)` (gate PASS line: "373 exact nonblank keys, 93 declared 32-logical character bases"); `cat index.html src/**/*.js | gzip -9 | wc -c` → 236,259 bytes.
- **Actually:** The enforced contract is exactly 373 character keys from 93 true-32px bases (v19 raised ceilings to 400/64; Wave 4.2 retired 16×16-derived), and the shipped sources gzip to ~231KB under the v19-revised 225KB-era budget, not 185KB. This unversioned table reads as current but froze at v18.
- **If obeyed:** An agent would cut 13 sprites or revert the 32px art to fit "≤360 16×16-derived," directly undoing the just-merged Wave 4.2 migration, or fail builds against a dead 185KB budget.

### F-SPEC-10 · DAMAGE: LOW
- **Where:** SPEC.md:1052 (also 1053)
- **Claim:** "Knockback applied to target proportional to direction vector × 6" (and "6 hit particles spawned at target center")
- **Disproof:** `sed -n 197,206p src/systems/combat.js` → `const kb = 8;` and 8 spark + 3 blood particles per hit.
- **Actually:** Knockback is 8 (bumped 6→8 in v13 wave 5, which SPEC.md:1443 itself records) and 11 particles spawn; the unversioned COMBAT section was never updated.
- **If obeyed:** An agent would "restore" ×6 knockback, reverting a deliberate feel change that the wave-5 section of the same file documents as intentional.

### F-SPEC-11 · DAMAGE: LOW
- **Where:** SPEC.md:978 (WORLD MAP table, also rows 979–982, 986)
- **Claim:** "THE BLOCK | center (900-1200, 740-960)"
- **Disproof:** `rg -n "id: 'block'" src/data/world.js` → `x: 880, y: 720, w: 340, h: 240` (i.e. 880–1220, 720–960); dealer is 1460–1780/780–1030 vs claimed "(1450-1770, 780-1020)", market 700–1420 vs "(700-1400)".
- **Actually:** Several legacy zone rects in this "canonical positions" table drift 10–20px from the shipped data (block, scrap, pawn, dealer, market); the wave-8a-era rows (trainyard, park, skidrow, oldschool, church, underpass, busstop) are exact.
- **If obeyed:** An agent placing props, claim points, or collision checks from this table would author coordinates just outside/inside real zone bounds, producing off-by-a-tile zone-verb and territory bugs.

### F-SPEC-12 · DAMAGE: LOW
- **Where:** SPEC.md:1868
- **Claim:** "the withdrawal rate by standing still for one second (`update.js:124`)"
- **Disproof:** `sed -n 120,124p src/core/update.js` → line 124 is `syncRecognitionVisit();`; the withdrawal accrual is at update.js:111 (`P.shakes += 0.0008 * dt;`).
- **Actually:** Wave 4.1's insertions shifted update.js line numbers; the cited measurement anchors for withdrawal/cap now point at unrelated statements (the values themselves — 0.8/s, 2.2 speed, shakes 20 — all still verify correct; runtime_ui.js:33 still holds).
- **If obeyed:** An agent auditing the world-gate's "measured-not-vibed" chain would inspect the wrong lines, conclude the derivation is unanchored, and either distrust a correct gate or "re-anchor" it against the wrong code.

### SUSPECTED — UNPROVEN
- "500px vision range" for cops (SPEC.md:1099): cops spawn `aggro:true`, and no vision-range constant was found, suggesting no such mechanic exists at all — but npc_ai.js was not exhaustively ruled out, so only the three disproven stats appear in F-SPEC-4.
- All "<90 seconds by a competent player" boss claims and the 16ms/60-NPC frame budget: behavioral, not disprovable by static command; the combat/perf harnesses exist but were not run to timing completion.
- SPEC.md:1885 "every stop in the shipped table keeps ≥21 within-budget partners": not independently re-derived; trusted to world-gate.
- SPEC.md:1106 "Auto-save: every 45 seconds (`setInterval`)": the 45s cadence is real (update.js:871 accumulator) but no save `setInterval` exists — mechanism-only drift, judged too trivial to list as a finding.

---

## VIBE.md — ~125 claims checked · 9 false · verdict: mostly true — the 58-row identity registry, palette, SFX recipes, and Wave-4.2 art corrections check out almost perfectly; the 9 falsehoods are small-caliber (two mechanic misstatements in the registry, one emoji residue in the corrected art text, six spec-drift details), nothing on the scale of the retracted art section.

### F-VIBE-1 · DAMAGE: MEDIUM
- **Where:** VIBE.md:297
- **Claim:** "FATHER O'MALLEY | priest, calls tic-tacs medicine | the church | dispenses "blessed tic-tacs" for shakes"
- **Disproof:** `sed -n 560,600p src/dialogue/neighborhood_a.js` → comment "v13 wave 6.5 — tic-tac is a TASTE, not a withdrawal substitute. removed shakes reduction"; the option gives `P.brain+5` and toasts "the tic tac is gone.\nthe shakes do not care."
- **Actually:** Tic-tacs give +5 brain only and explicitly do NOT relieve shakes — the shakes reduction was deliberately removed in v13 wave 6.5 (commit 27222ac, economy exploit pass); "the shakes do not care" is now the canonical line.
- **If obeyed:** An agent extending church/shakes content from the registry would reintroduce tic-tacs as a shakes remedy, reopening an exploit the operator deliberately closed and contradicting the shipped canonical joke.

### F-VIBE-2 · DAMAGE: MEDIUM
- **Where:** VIBE.md:153-154 (and the retraction's "8 emoji lines … every one of them UI chrome" at VIBE.md:160-161)
- **Claim:** "Emoji appear only in UI chrome (HUD, phone/feed, status), never as an actor or a world object."
- **Disproof:** `grep -rn "🔒" src index.html` → `src/render/structures.js:210: ctx.fillText('🔒', b.x+b.w/2-8, b.y+b.h/2+6);`
- **Actually:** One of the 8 emoji lines in src/ is drawn on the world canvas onto locked buildings — a world-object usage that VIBE.md:204 itself mandates ("boarded planks drawn as 4px lines + 🔒 emoji", which matches the code). The corrected art text and line 204 give contradictory orders, and the retraction's "every one of them UI chrome" is wrong about that line.
- **If obeyed:** An agent enforcing line 153-154 would strip the 🔒 from locked buildings that line 204 and the shipped renderer require — or would trust the "all UI chrome" audit claim as complete when it isn't.

### F-VIBE-3 · DAMAGE: LOW
- **Where:** VIBE.md:295
- **Claim:** "WHOLE FOODS MOM | vibram five-fingers, kombucha | marketplace | gives you $5 and pity"
- **Disproof:** `sed -n 455,500p src/dialogue/neighborhood_a.js` → option label `'accept $10 and pity. (+$10)'` with `P.cash += 10` (plus a separate 40%-odds "ask for $20" branch).
- **Actually:** She gives $10 and pity (daily-capped), with an optional $20 gamble. $5 is not an amount anywhere in her dialogue.
- **If obeyed:** Economy or content work balanced against a $5/day income source that actually pays $10-$20, and a registry row that propagates the wrong number into new writing.

### F-VIBE-4 · DAMAGE: LOW
- **Where:** VIBE.md:261
- **Claim:** "The chimichanga is talking. The cat hisses in cursive. The copper sings in B flat."
- **Disproof:** `grep -l -i "hiss\|cursive" rock_bottom_v*.html index.html` and `grep -rn -i "hiss\|cursive" src --include="*.js"` → zero output (no build v4-v19, src/, or index.html contains either word; no cat NPC exists).
- **Actually:** The chimichanga (src/minigames/activities.js:62) and B-flat copper lore (src/core/update.js:352-353 and others) are real, shipped, repeatable lore. The cursive-hissing cat has never existed in any version of the game — it is a fabricated lore anchor presented alongside two real ones.
- **If obeyed:** An agent told to "maintain" and "build on" location texture would treat the cat as existing canon to extend or would waste time hunting for it; new content could cite lore with no referent.

### F-VIBE-5 · DAMAGE: LOW
- **Where:** VIBE.md:147
- **Claim:** "CRT scanlines always on (3px repeating gradient overlay, 12% opacity)"
- **Disproof:** `grep -n "scanlines" index.html` → line 89: `repeating-linear-gradient(... rgba(0,0,0,.18) 2px, rgba(0,0,0,.18) 3px)` — 18% opacity (2.5px period on small screens, line 165).
- **Actually:** The shipped scanline lines are 18% black, not 12%; only the 3px period is correct.
- **If obeyed:** New overlay/CRT work authored to 12% would render visibly lighter than every shipped frame.

### F-VIBE-6 · DAMAGE: LOW
- **Where:** VIBE.md:224
- **Claim:** "Sounds are SHORT (50-300ms) except death (1.5s descending)"
- **Disproof:** `sed -n 265,282p src/core/audio_save.js` → `crash() { this.tone(440,.6,...) }` (600ms), `bossRoar()` 450ms, `windup()` 450ms; `node -e "console.log(3*220+320)"` → 980 (death totals ~0.98s, not 1.5s).
- **Actually:** Multiple shipped sfx exceed 300ms (crash 600ms, bossRoar/windup 450ms, traffic 350ms), and death runs ~1.0s, not 1.5s.
- **If obeyed:** An agent would clamp new sounds to a 300ms ceiling the shipped soundscape doesn't obey, or write a 1.5s "death-length" sound that overshoots the real one by 50%.

### F-VIBE-7 · DAMAGE: LOW
- **Where:** VIBE.md:231
- **Claim:** "coin: major third up (B → E, the only "happy" sound)"
- **Disproof:** `node -e "console.log((659/494).toFixed(3))"` → 1.334 (perfect fourth = 1.333; major third = 1.250); code at src/core/audio_save.js:268 is `tone(494,...)` then `tone(659,...)`.
- **Actually:** The notes B4 → E5 match the code, but that interval is a perfect fourth, not a major third.
- **If obeyed:** An agent writing "another happy major third like coin" would produce an interval that doesn't match the existing sound it's told to echo.

### F-VIBE-8 · DAMAGE: LOW
- **Where:** VIBE.md:211
- **Claim:** "10px monospace name above, wrapped/deconflicted by the nameplate system"
- **Disproof:** `grep -n "Courier" src/render/actors_weather.js` → line 155: `ctx.font='9px Courier New';` (the nameplate draw path; the only 10px font nearby is the asleep-"z" marker at line 145).
- **Actually:** NPC nameplates render at 9px Courier New; the wrap/deconflict system part of the claim is true.
- **If obeyed:** New name rendering authored at 10px would mismatch every existing nameplate and the wrap-width metrics (17-char line break) tuned for 9px.

### F-VIBE-9 · DAMAGE: LOW
- **Where:** VIBE.md:205
- **Claim:** "Every building gets a labelColor (specific to its vibe)"
- **Disproof:** `grep -rn "labelColor" src` → no matches; `grep -c "labelColor" rock_bottom_v4.html rock_bottom_v10.html rock_bottom_v19.html` → 0, 0, 0 (the identifier has never existed in any build).
- **Actually:** Zones carry a `label:` color (src/data/world.js:33+); named buildings get per-building `signColor` via `BUILDING_STYLE[b.name]` (src/render/structures.js:48,167); the 28 `LANDMARK_FACADES` get kind-generic cached signage. There is no `labelColor` property and no universal per-building color field.
- **If obeyed:** An agent adding a building would search for `labelColor`, find nothing, and either stall or invent a new parallel field instead of extending `BUILDING_STYLE` / zone `label`.

### SUSPECTED — UNPROVEN
- VIBE.md:118 "The existing 54 permanent-loop beats are grandfathered" — the 54 (23 route stops + 22 claim beats + 9 kingdom marks) is consistent across REFACTOR-FINDINGS.md:114, SPEC.md:1731, and BRAIN.md, but REFACTOR-FINDINGS itself hedges "approximately 54" and the beats were not independently re-counted in code.
- VIBE.md:381 "The 'leave' option is mandatory" — every dialogue opened (Tony, Stripe, Barb, Pinky, O'Malley, mom, possum, Vape Lord, Leasing Guy, Price Guy, etc.) has a leave/exit option, but not every dialogue() call site was exhaustively scanned for a counterexample.
- VIBE.md:236 "bossRoar: detuned bass + noise burst" — the code is a single 80Hz sawtooth sliding to 40Hz plus noise (audio_save.js:281), not a detuned oscillator pair; "detuned" is loose enough that it was not counted as disproven.

---
