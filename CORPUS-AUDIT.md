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
| AGENTS.md | 184 | pending |
| CLAUDE.md | 172 | pending |
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
