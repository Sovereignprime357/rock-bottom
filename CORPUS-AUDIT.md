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
| README.md | 90 | pending |
| DELEGATION.md | 577 | pending |
| SPEC.md | 1,913 | pending |

---
