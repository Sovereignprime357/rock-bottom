# CLAUDE.md — Agent Operating Constraints

> You are picking up a satirical action game in mid-build. Operator is Sovereign Prime (VibeKoded). v3 is shipped. The comedic voice is a HARD spec — read VIBE.md before touching anything.

---

## Hard rules (non-negotiable)

### 1. Read VIBE.md first
Not optional. Not skimmable. The comedy is the product. Mechanics serve the comedy, not the other way around.

### 2. Spec before generate
Adding a new system? Add the SPEC entry first. Spec without code is a draft. Code without spec is slop. Both, in order, is SpecMesh.

### 3. Single HTML file architecture
Everything in one file: HTML, CSS, JS, sprites, audio. No external dependencies. No CDN imports. No build step. The whole game must be openable by double-clicking the file.

### 4. window.storage, NEVER localStorage
Claude.ai artifacts do NOT support localStorage or sessionStorage. They fail silently in a way that corrupts the save illusion. Use `window.storage.set / .get` exclusively. All calls async, all wrapped in try/catch.

### 5. Audio init on first user interaction
Browser autoplay policy. Audio context must be created in a keydown or click handler, never on page load. Track `audioReady` boolean to gate all `beep()` calls.

### 6. Pixel sprite discipline
- 16×16 logical, prerendered to offscreen canvas at init
- Scaled 2x to 32×32 display
- Palette-indexed (numbered string format, see PLAYER_SPRITES)
- Cached in `SPRITE_CACHE` object
- Drawn via `ctx.drawImage` — never `fillRect` per pixel at runtime

### 7. Test the rocked-up + crash loop after any change touching it
The 18s high → 8s crash loop is the comedic core of the gameplay. If you touch any of:
- `updatePlayer` timing
- `rockedUpTimer` / `crashTimer`
- `sfx.rockUp` / `sfx.crash`
- The `smoke a rock` dialogue option

→ play it end-to-end before shipping.

### 8. Boss fight must remain defeatable in <90 seconds
For a competent player. This is a comedy boss, not a tactical RPG boss. If a change makes the fight harder than 90s, the change is wrong.

### 9. Performance: <16ms frame at 60+ NPCs
Profile if adding particle systems, projectiles, or per-frame computation. Use the existing prerender pattern for any new sprites.

### 10. No fourth wall breaks
No "this game," "I, Claude," "the developer." The world is the world.

---

## Soft rules (prefer, but exceptions allowed)

### Prefer extending existing systems over adding new ones
- Adding a status effect? Look at `rockedUpTimer` / `crashTimer` pattern.
- Adding a new NPC behavior? Look at `npc.wander` / `npc.hostile` / `npc.zoneOnly`.
- Adding a new currency? Reconsider. You probably don't need it.

### Prefer Web Audio synthesis over samples
If a new sound is needed, write it as a synth function in the `sfx` object. Match the existing chiptune aesthetic.

### Prefer canvas drawing over DOM elements
The HUD, dialogue, and toast are DOM. Everything else is canvas. New gameplay UI should be canvas to maintain the scanline/CRT effect.

### Prefer emoji NPCs over pixel-art NPCs (for now)
v3 has pixel-art player + emoji NPCs. This is the look. Adding pixel-art NPCs is on the v4 backlog (DELEGATION.md item 1) and is OK, but ALL NPCs should be converted, not just some. Inconsistency would break the aesthetic.

---

## SpecMesh discipline (operator's methodology)

Sovereign uses SpecMesh. You should too while in this project.

### SPEC
Capture before generation. Behavioral contract. Inputs/outputs/invariants/edge cases.

### BRAIN
After every working session, append to BRAIN.md (if it doesn't exist, create it):
- What was changed and why
- What was decided and the reasoning
- What was tried that failed
- What's next

### Quality gates before declaring complete
1. **Counterexample hunt** — what breaks this?
2. **Drift check** — does the implementation match the spec?
3. **Property verification** — are the invariants from SPEC.md still preserved?

### Naming
All sprite IDs, NPC IDs, function names use snake_case in this codebase. Match the existing convention.

---

## When in doubt

### When in doubt about tone
Re-read VIBE.md. Pick the option that is more flat and more specific. Fewer adjectives, more nouns. Less emotion, more accounting.

### When in doubt about mechanics
Check SPEC.md invariants. If your change would violate an invariant, your change is wrong (or the invariant is wrong — and changing an invariant requires updating SPEC.md first).

### When in doubt about scope
Check DELEGATION.md. If your idea isn't on the v4 list, ask the operator before building it. The backlog is prioritized for a reason.

### When in doubt about whether something is funny
It's not. Cut it. Then write something more specific.

---

## What to do at the end of a session

1. Save the updated HTML file as `rock_bottom_v{N+1}.html` (NOT overwriting v3 — keep the lineage)
2. Update SPEC.md with any new systems, invariants, edge cases
3. Update DELEGATION.md — move completed items to "shipped," refine remaining items
4. Create/append BRAIN.md with the session log (what/why/decided/tried/next)
5. If you added new sounds: document them in SPEC.md sound section
6. If you added new NPCs: add to VIBE.md identity table
7. Present the new HTML file via `present_files` for the operator to play

---

## What NOT to do (escalation triggers)

If you do any of these, the operator will be unhappy and the work will be reverted:

1. **Replace the emoji aesthetic with stock asset pixel art** — the emoji are the look
2. **Add a tutorial that explains anything** — discovery is the gameplay
3. **Make the game beatable without smoking a rock** — the entire point is the loop
4. **Add a "story mode" with cutscenes between zones** — there is no story, only consequences
5. **Add a "good ending" where the crackhead gets clean** — the protagonist is a clown, not a moral lesson
6. **Add real-world drug names, real cities, real victim references** — see VIBE.md HARD STOPS
7. **Use localStorage** — see Hard Rule 4
8. **Add Tailwind, React, any framework** — single HTML file, vanilla JS, see Hard Rule 3
9. **Add a credits screen with your name on it** — this is the operator's portfolio piece
10. **Make any NPC speak in proper grammar with capital letters** — see VIBE.md Rule 1

---

## Communication with the operator

Sovereign learns through systems thinking. When explaining a change, use WHAT/WHY/HOW/PATTERN/CONNECT/GOTCHA structure:

- **WHAT** changed
- **WHY** it changed
- **HOW** it works mechanically
- **PATTERN** it follows (or breaks)
- **CONNECT** it to other parts of the system
- **GOTCHA** — what to watch for, what might break

Short questions get short answers. Deep questions get systems-level answers. Don't pad responses with structure.

---

## File system for handoffs

```
/rock_bottom/
├── README.md
├── VIBE.md          ← THE SOUL
├── SPEC.md          ← THE SYSTEMS
├── CLAUDE.md        ← THIS FILE
├── DELEGATION.md    ← THE BACKLOG
├── BRAIN.md         ← session continuity (append-only)
└── rock_bottom_v{N}.html  ← shipped builds, one per version
```

---

## Identity check before shipping

You are not building "a game about a sad addict." You are building "a comedy where the joke is the same crackhead trying the same things in the same neighborhood and the world keeps being weird at him." If you forget this, look at the possum.

The possum knows.
