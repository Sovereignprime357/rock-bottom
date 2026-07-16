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

The runner supplies `--experimental-vm-modules`, streams every gate in the table below in order, and stops on the first failure. (This sentence once said "four," then "seven," while more ran — it no longer states a count, because prose counts rot and only the table is gated.)

| Gate | Enforces |
|------|----------|
| `corpus-gate` | **The seed.** Blocks staged deletions of the design docs and refuses to run at all if your view of the repo disagrees with `HEAD`. Runs first on purpose — see below. |
| `docs-gate` | **This table.** Asserts the gate list here matches the `GATES` array in `run-gates.mjs`. This README once claimed four gates while seven ran; nothing caught it. |
| `module-gate` | Module linking, source/reference integrity, no file over the size ceiling. |
| `npc-registry-gate` | Every runtime NPC identity is registered in `VIBE.md`. No unnamed strangers. |
| `legibility-gate` | The four measured legibility relationships (buildings, zones, nameplates, graffiti). |
| `presentation-gate` | Save/input/status parity. |
| `recognition-gate` | **The north star.** Diffs every reward field across a full rank climb to prove recognition pays in acknowledgment and nothing else. |
| `concession-gate` | **One loop, many rooms.** Proves exactly one `rockedT = 18000` site exists, that the high is identical at every spot, that royal static stays Block-only, and that BAD IDEA never points at an illegal room. |
| `runtime-smoke` | The game boots, starts, and plays headless. |
| `world-gate` | **The map.** Derives the shakes runway and walk speed at run time, then measures every mandatory leg, day-1 coverage, and the route legality graph against them. |
| `economy-gate` | **Every dollar is named.** A static census of every resource-grant site in `src/`, each classified as a behaviorally-proven trade (guards hold at zero, payouts consume), a register-cited deliberate payout, or a standing violation. Ships red naming F-SOCK on purpose — the sock is the operator's pending taste call. Runs last so its standing red can never mask a regression in the gates above it. |

**Why `corpus-gate` runs first.** Every other gate checks the **game**. That one checks the **corpus** — `VIBE.md`, `SPEC.md`, `AGENTS.md`, the logs — which is the thing every future version gets reproduced from. On 2026-07-16 an agent read this repo through a stale mount and saw 508 deletions that did not exist; `git add -A` would have committed them **clean and green**, because a suite that only checks the game passes fine while the game is fine. **A suite that protects the output but not the seed is protecting the wrong thing.** There was a written note warning of exactly this. The note did not stop it. A note is a prompt, and prompts leak. Only a gate holds.

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

Sovereign Prime — VibeKoded
Architect: Claude (Opus 4.7)
Methodology: SpecMesh

## Release

Free-to-play. No account, gameplay service, asset download, package install, or build step is required; static HTTP hosting is required for native modules.

**MIT licensed** — see `LICENSE`. Take it, fork it, learn from it. The method is the point; the crackhead is public domain as far as we are concerned.
