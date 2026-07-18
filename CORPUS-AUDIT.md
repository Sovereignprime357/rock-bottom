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
| VIBE.md | 400 | pending |
| AGENTS.md | 184 | done — 23 checked, 6 false (3 MEDIUM, 3 LOW) |
| CLAUDE.md | 172 | done — 26 checked, 14 false in 8 findings (4 HIGH) |
| README.md | 90 | done — 29 checked, 0 false (clean) |
| DELEGATION.md | 577 | done — 43 checked, 8 false (2 HIGH) |
| SPEC.md | 1,913 | pending |

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
