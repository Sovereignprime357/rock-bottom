# CORPUS-AUDIT — false-claim audit of the governing docs

**Run:** 2026-07-17, worktree `corpus-audit` at `c68d9b2`, clean.
**Method:** 6 agents, one per doc, launched simultaneously — peak concurrency 6 (hard cap, by design; the 114-agent run is the counterexample). Findings banked and committed per file as each agent returns, never at the end.
**Scope (priority order):** VIBE.md · AGENTS.md · CLAUDE.md · README.md · DELEGATION.md · SPEC.md
**Rule:** every finding cites a reproduction command run against this worktree. Unproven suspicions live only in the SUSPECTED — UNPROVEN section of each file's report and are not merged into findings. Nothing was fixed; no governing doc was edited.

**Ground truth at c68d9b2 (verified during scout):**
- Current architecture is modular `src/` (36+ JS modules) + `index.html` loader; latest monolithic build is `rock_bottom_v19.html`.
- Sprite system is true-32px art (`src/render/sprite_art_*_32.js`, 93 bases, merged at `dbd960c`).
- VIBE.md's false art section was retracted at `df1476e` (2 days ago); CLAUDE.md has no commits since 2026-05-26.

Sections appear in agent-completion order, not priority order. Status table:

| Doc | Lines | Status |
|---|---|---|
| VIBE.md | 310 | pending |
| AGENTS.md | 129 | pending |
| CLAUDE.md | 120 | pending |
| README.md | 63 | pending |
| DELEGATION.md | 463 | pending |
| SPEC.md | 1409 | pending |

---
