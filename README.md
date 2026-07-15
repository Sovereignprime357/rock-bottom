# ROCK BOTTOM — The Crackhead's Odyssey

> A top-down satirical action game where you play a crackhead trying to score rocks from a local dealer. Single HTML file. Zero dependencies. Double-click to play. Built by VibeKoded.

## What it is

You wake up on the sidewalk. Your mouth tastes like a battery. It is approximately Tuesday. The shakes are climbing. The only person who can help you is Tre Bag Tony at the corner. He charges $10 a rock and does not negotiate, except sometimes he does.

Find cash. Score rocks. Smoke at the block. Climb ranks. Strip copper from the abandoned building. Cook your own at the crate. Survive the cops. Defeat Tre Bag Tony. Become CRACK LORD SUPREME.

## Technical shape

- **One file.** `rock_bottom_v18.html` — HTML, CSS, JS, sprites, audio, all inline.
- **Zero deps.** No CDN. No npm. No build step. No framework. Vanilla JS, Canvas 2D, Web Audio.
- **How to run:** double-click the file. Or drag it into a browser. That is the install process.
- **Saves:** async `window.storage`; ordinary browsers receive an IndexedDB-backed adapter, with volatile memory only when IndexedDB is unavailable.
- **Browser:** any evergreen Chromium/Firefox/Safari. Desktop and mobile both supported (analog touch controls on mobile).

## Current shipped build

**v18** — the paper-empire / far-east build. The world is now 5800×3800 with WAREHOUSE ROW, THE DRAINAGE CANAL, and THE LOT connected by new roads, terrain, facades, props, lights, route stops, and safe bus arrivals. Filing three block routes exposes THE OFFICE: a condemned former tax office that can be acquired for $40 + 1 pure copper, then visibly burdened with a cot, shared locker, desk, generator, radio, and route board. The desk opens eleven three-stage district claims gated by faction tolerance; the radio opens bounded sign inspections that pay only after returning to file. Ownership means bent signs and paperwork, never people, passive income, or a new currency. The Q ledger, objective marker, minimap, evolving office exterior, two authored clerical NPC sprites, six-per-page bus ledger, and 1/4/8/11 milestones make the long grind legible. v17's endless routes, full activity ledger, cursed-sticker player art, v16 multi-key controls, and the exact 18s high → 8s crash remain intact.

## Version lineage

`rock_bottom_v4.html` through `rock_bottom_v18.html` are all preserved in the repo. v3 was the original public ship; everything since is in-house iteration. Latest = highest number. Older versions are kept for diff archeology, not because they still work — play the latest.

## Design docs (read in this order)

| File | Role |
|------|------|
| `README.md` | This file. Quick orientation. |
| `VIBE.md` | **THE SOUL.** Tone bible. Read it twice. Lowercase NPCs, cursed names, no fourth-wall breaks. |
| `SPEC.md` | Behavioral contract. Resources, zones, invariants, edge cases. |
| `AGENTS.md` | Operating constraints for the agent. Hard rules vs soft rules. |
| `DELEGATION.md` | Prioritized backlog. What ships next. |
| `BRAIN.md` | Append-only session log. What was changed, why, what was tried, what's next. |

## A fresh agent's read order

1. README.md (you are here)
2. **VIBE.md** — internalize the voice before doing anything else
3. SPEC.md — understand the systems before changing them
4. Play the latest `rock_bottom_v{N}.html` end-to-end (smoke a rock, fight a crackhead, get arrested, cook a batch, beat the boss)
5. AGENTS.md — operating rules
6. DELEGATION.md — pick a task off the top
7. BRAIN.md — context for what just happened

## Tone, one line

the game does not editorialize. the possum knows. lowercase only. the bit lands flat.

## Owner

Sovereign Prime (Shayler Phipps) — VibeKoded
Architect: Claude (Opus 4.7)
Methodology: SpecMesh

## Release

Free-to-play release candidate. No account, service, asset download, or build step is required. Source licensing and redistribution terms remain with the operator.
