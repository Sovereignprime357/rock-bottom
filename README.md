# ROCK BOTTOM — The Crackhead's Odyssey

> A top-down satirical action game where you play a crackhead trying to score rocks from a local dealer. Native browser modules. Zero runtime dependencies. Built by VibeKoded.

## What it is

You wake up on the sidewalk. Your mouth tastes like a battery. It is approximately Tuesday. The shakes are climbing. The only person who can help you is Tre Bag Tony at the corner. He charges $10 a rock and does not negotiate, except sometimes he does.

Find cash. Score rocks. Smoke at the block. Climb ranks. Strip copper from the abandoned building. Cook your own at the crate. Survive the cops. Defeat Tre Bag Tony. Become CRACK LORD SUPREME.

## Technical shape

- **Active source.** `index.html` plus section-derived native ES modules under `src/`. `rock_bottom_v19.html` is the frozen behavioral reference, not the active source.
- **Zero runtime deps.** No CDN, package install, framework, or build step. Vanilla JS, Canvas 2D, and Web Audio.
- **How to run:** serve this folder over ordinary HTTP and open `index.html`. For example, from the repo root: `python -m http.server 8000`, then open `http://localhost:8000/`. Native modules are intentionally not recombined for `file://` double-click execution.
- **Saves:** async `window.storage`; ordinary browsers receive an IndexedDB-backed adapter, with volatile memory only when IndexedDB is unavailable.
- **Browser:** any evergreen Chromium/Firefox/Safari. Desktop and mobile both supported (analog touch controls on mobile).

## Current shipped build

**v19 post-audit modular build.** The world is `8600×5600`: the paper office now leads into BLUE TARP COURT, CART CAVALRY KEEP, COPPER CHOIR YARD, and THE THRONE DITCH, ending in a folding-chair succession fight before endless routes, work orders, hustles, incidents, and daily pretenders continue. The post-audit pass split the frozen v19 script into 38 linked source modules, repaired building/zone/nameplate/graffiti legibility, restored the complete NPC identity registry, fixed the isolated office encoding damage, and retained the exact multi-key controls plus 18s high → 8s crash loop.

## Version lineage

`rock_bottom_v4.html` through `rock_bottom_v19.html` are preserved for diff archaeology. v3 was the original public ship; v19 is now the frozen monolithic reference. Play the active modular build through `index.html`.

## Verification

Run these from the repository root with a current Node.js:

```text
node tools/run-gates.mjs
```

The runner supplies `--experimental-vm-modules`, streams all four gates in order, and stops on the first failure. Together they enforce source/reference integrity, module linking, save/input/status parity, the four measured legibility relationships, and complete VIBE registration for runtime NPC identities.

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
4. Serve and play `index.html` end-to-end (smoke a rock, fight a crackhead, get arrested, cook a batch, beat the boss)
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

Free-to-play release candidate. No account, gameplay service, asset download, package install, or build step is required; static HTTP hosting is required for native modules. Source licensing and redistribution terms remain with the operator.
