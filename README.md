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

**v22 — the economy waves.** Five waves built a real economy on top of the v21 world. **Copper from multiple locations** (5.1) turned one heist into a parameterized engine across four cursed sites. **Smoke-spot discovery** (5.2) made the concession venues findable — wild crackheads reveal them, but you still earn the room. **The emergency hitter** (5.3) gave copper a second life: craft a bad-trade consumable or find one rare, so every strip is "sell it or keep it to save your life later." **The robbery** (5.4) added the economy's first sink — Skid Row takes your cash, your items, the coat off your sprite, and you don't get it back. **Break-ins** (5.5) generalized the heist engine with `tool`/`cred` doors and a barren-quarter loot table, and made the crowbar and the propane torch fight for the one tool slot: cook or burglar, not both. It follows v21 (the character ceiling, the honest map, the recognition wave). The world remains `8600×5600`, the frozen v19 reference remains untouched, the 18s → 8s loop remains intact, and the suite is **18 gates**.

## Version lineage

`rock_bottom_v4.html` through `rock_bottom_v19.html` are preserved for diff archaeology. v3 was the original public ship; v19 is now the frozen monolithic reference. Play the active modular build through `index.html`.

## Verification

Run these from the repository root with a current Node.js:

```text
node tools/run-gates.mjs
```

The runner supplies `--experimental-vm-modules`, streams all **seventeen** gates in order, and stops on the first failure.

| Gate | Enforces |
|------|----------|
| `corpus-gate` | **The seed.** Blocks staged deletions of the design docs and refuses to run at all if your view of the repo disagrees with `HEAD`. Runs first on purpose — see below. |
| `docs-gate` | **This table.** Asserts the gate list here matches the `GATES` array in `run-gates.mjs`. This README once claimed four gates while seven ran; nothing caught it. |
| `version-gate` | **The label.** The `<title>`, the subtitle, and this README's "Current shipped build" must name the same version. The game said `v19` through the entire v20 wave and Wave 4.1, and sent the operator hard-refreshing a deploy that was already current. |
| `module-gate` | Module linking, source/reference integrity, no file over the size ceiling. |
| `sprite-gate` | **The character ceiling.** Pins 373 exact nonblank keys across 93 explicitly declared 32-logical character bases, keeps eleven explicit 16-logical environment sprites on the same renderer, freezes all 14 character-cache draw destinations and the palettes actually consumed by both caches, and enforces the no-smoothing pixel contract. Green proves structure and rendering discipline—not whether the art is good; that remains an operator visual decision. |
| `npc-registry-gate` | Every runtime NPC identity is registered in `VIBE.md`. No unnamed strangers. |
| `legibility-gate` | The four measured legibility relationships (buildings, zones, nameplates, graffiti). |
| `presentation-gate` | Save/input/status parity. |
| `recognition-gate` | **The north star.** Diffs every reward field across a full rank climb to prove recognition pays in acknowledgment and nothing else. |
| `concession-gate` | **One loop, many rooms.** Proves exactly one `rockedT = 18000` site exists, that the high is identical at every spot, that royal static stays Block-only, and that BAD IDEA never points at an illegal room. |
| `copper-sites-gate` | **One engine, many buildings.** Proves the 3-stage heist flow, the `heistsToday` increment, and the 2-4 yield roll each exist exactly once; that all copper sites share the 3/day cap (so more sites never means more income); that site effects structurally cannot mint cash or copper; that registry anchors match the world's rects; and walks every entry and getaway of every site under both RNG branches to end back at play. |
| `hitter-gate` | **The bad trade.** Proves the emergency hitter is strictly worse than a real rock over the full hit→high→crash cycle by racing both through the live boundary to a 40s horizon (the marathon a spammed hitter must always lose), that it credits nothing (no cred, no rep, no recognition, no intro), that copper crafting is one-directional and the dumpster find stays rare and far-only, that neither path adds a walk, and that the save keys are additive. |
| `discovery-gate` | **The map, not the key.** Proves smoke-spot discovery flips visibility and nothing else: reveals leave the recognition ledger, tier, and reward state byte-identical (through the real teller dialogues), the Block can never enter the discovered set, and a pre-5.2 save loads all-undiscovered. Exists because discovery routes *around* the ledger recognition-gate watches. |
| `robbery-gate` | **The first sink.** Proves the skid robbery only subtracts: every theft category (cash, item, hitter, equipped clothing) runs with a full economy snapshot and nothing ever increases, the taken thing stays gone through live minutes, losability is an allowlist a pocket full of progression keys provably survives, only `skid_lurch` robs (the back-alley grabber's landed grab — same real code path — takes nothing), a stolen coat provably stops being drawn, the cooldown + daily cap hold through the real dawn reset, and the save keys are additive. |
| `breakin-gate` | **The doors are real.** Proves the heist engine's two new gate kinds genuinely refuse: a `tool` door with no crowbar (or the wrong tool) and a `cred` door one point under threshold both bounce clean — stating their refusal, spending nothing — and open at the exact boundary; the both-gates site answers tool before cred by declared order. Proves break-ins ride their own governor (`breakinsToday`, 2/day) by interleaving them with a capped copper day and watching both counters through the real dawn reset, that the take is structurally locked (allowed keys, ≤$40/day worst case, vetted item ids, no site can even name copper or rocks), and walks every entry, take, alt, getaway, and leave back to play. |
| `solidity-gate` | **The honest map.** Requires declared physicality, one collision authority, door/art and legacy-resolver parity, deterministic save ejection, exact actor exemptions, charge impacts, actor/projectile obstruction, and collision-aware traversal of every mandatory leg. Run it with `--full` to print the complete 69-campaign / 252-route before-and-after ledger. |
| `runtime-smoke` | The game boots, starts, and plays headless. |
| `world-gate` | **The map.** Derives the shakes runway and walk speed at run time, then measures every mandatory leg, day-1 coverage, and the route legality graph against them. Runs last on purpose: a standing world reading must never mask a regression in the gates above it. |

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
