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
| DELEGATION.md | 577 | pending |
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
