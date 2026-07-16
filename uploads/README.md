# ROCK BOTTOM — The Crackhead's Odyssey

> A top-down Zelda-style action game where you play a crackhead trying to score rocks from a local dealer. Satirical Adult Swim comedy. Single HTML file. Built by VibeKoded.

## What it is

You wake up on the sidewalk. Your mouth tastes like a battery. It is approximately Tuesday. The shakes are climbing. The only person who can help you is Tre Bag Tony at the corner. He charges $10 a rock and does not negotiate, except sometimes he does.

Find cash. Score rocks. Smoke at the block. Climb ranks. Strip copper from the abandoned building. Survive the cops. Defeat Tre Bag Tony. Become CRACK LORD SUPREME.

## What it is NOT

- Not a glorification of addiction.
- Not a "drug education" tool.
- Not mean-spirited. The protagonist is a clown in a comedy. Treat him with the dignity of a clown.
- Not Rick and Morty. There is no "smart" undercurrent. The stupidity IS the show.
- Not Family Guy. No cutaway gags. The world is continuous.

## Current version

**v3** ships:

- Top-down action RPG with WASD movement
- Real-time fist combat (SPACE swings, hitbox in facing direction)
- Pixel-art player sprite, 4 directions × 2 walk frames, gold-tinted palette swap when rocked-up
- Synthesized chiptune SFX via Web Audio
- 7 zones: The Block, Scrap Yard, Pawn Shop, Dealer's Corner, Marketplace, Back Alley, Abandoned Building, Church, Projects
- 15+ named NPCs with full identity (Tre Bag Tony, Yuri, Brutus, Pete, Lurch, Spider-Bite Sherri, Paulie The Face, Chatty Dave, Whole Foods Mom, The Possum, Father O'Malley, The Conductor, Loud Larry, Stripe, The Pigeon King)
- Wanted level system (1-3 stars) with chasing cops and arrest cutscene
- Rocked-up status effect (18s buff, then 8s crash)
- Multi-phase boss fight against Tre Bag Tony (bottles → shoe → bare-knuckle)
- Copper heist mini-game (3 stages, gated at Block Captain rank)
- Persistent save via window.storage
- Title screen, inventory panel, minimap
- Live AI-generated chaos events via Anthropic API (the possum)

## File system

This handoff pack contains:

| File | Role |
|------|------|
| `README.md` | This file. Quick orientation. |
| `VIBE.md` | **THE SOUL.** The tone bible. Read this first, read it twice. |
| `SPEC.md` | Behavioral contract. Systems, resources, invariants, edge cases. |
| `CLAUDE.md` | Operating constraints for the agent picking this up. |
| `DELEGATION.md` | Prioritized backlog. What ships in v4. |
| `rock_bottom_v3.html` | The shipped game. The current spec made real. |

## Read order for a fresh agent

1. README.md (you are here)
2. **VIBE.md** — internalize the voice before doing anything else
3. SPEC.md — understand the systems before changing them
4. Play `rock_bottom_v3.html` end-to-end at least once (smoke a rock, fight a crackhead, get arrested, beat the boss)
5. CLAUDE.md — operating rules
6. DELEGATION.md — pick a task

## Owner

Sovereign Prime — VibeKoded
Architect: Claude (Opus 4.7)
Methodology: SpecMesh

## License

Personal portfolio piece. Not for distribution. The crackhead does not consent to a port.
