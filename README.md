# ROCK BOTTOM — The Crackhead's Odyssey

> A top-down satirical action game where you play a crackhead trying to score rocks from a local dealer. Single HTML file. Zero dependencies. Double-click to play. Built by VibeKoded.

## What it is

You wake up on the sidewalk. Your mouth tastes like a battery. It is approximately Tuesday. The shakes are climbing. The only person who can help you is Tre Bag Tony at the corner. He charges $10 a rock and does not negotiate, except sometimes he does.

Find cash. Score rocks. Smoke at the block. Climb ranks. Strip copper from the abandoned building. Cook your own at the crate. Survive the cops. Defeat Tre Bag Tony. Become CRACK LORD SUPREME.

## Technical shape

- **One file.** `rock_bottom_v13.html` — HTML, CSS, JS, sprites, audio, all inline.
- **Zero deps.** No CDN. No npm. No build step. No framework. Vanilla JS, Canvas 2D, Web Audio.
- **How to run:** double-click the file. Or drag it into a browser. That is the install process.
- **Saves:** `window.storage` (Claude.ai artifact API). Falls back to in-memory if missing.
- **Browser:** any evergreen Chromium/Firefox/Safari. Desktop and mobile both supported (touch D-pad on mobile).

## Current shipped build

**v13** — wave 1 housekeeping done. v12 → v13 forked, dead rank-gate collision code removed, docs synced. Wave 2+ is queued in `DELEGATION.md`.

## Version lineage

`rock_bottom_v4.html` through `rock_bottom_v13.html` are all preserved in the repo. v3 was the original public ship; everything since is in-house iteration. Latest = highest number. Older versions are kept for diff archeology, not because they still work — play the latest.

## Design docs (read in this order)

| File | Role |
|------|------|
| `README.md` | This file. Quick orientation. |
| `VIBE.md` | **THE SOUL.** Tone bible. Read it twice. Lowercase NPCs, cursed names, no fourth-wall breaks. |
| `SPEC.md` | Behavioral contract. Resources, zones, invariants, edge cases. |
| `CLAUDE.md` | Operating constraints for the agent. Hard rules vs soft rules. |
| `DELEGATION.md` | Prioritized backlog. What ships next. |
| `BRAIN.md` | Append-only session log. What was changed, why, what was tried, what's next. |

## A fresh agent's read order

1. README.md (you are here)
2. **VIBE.md** — internalize the voice before doing anything else
3. SPEC.md — understand the systems before changing them
4. Play the latest `rock_bottom_v{N}.html` end-to-end (smoke a rock, fight a crackhead, get arrested, cook a batch, beat the boss)
5. CLAUDE.md — operating rules
6. DELEGATION.md — pick a task off the top
7. BRAIN.md — context for what just happened

## Tone, one line

the game does not editorialize. the possum knows. lowercase only. the bit lands flat.

## Owner

Sovereign Prime (Shayler Phipps) — VibeKoded
Architect: Claude (Opus 4.7)
Methodology: SpecMesh

## License

Personal portfolio piece. Not for distribution. The crackhead does not consent to a port.
