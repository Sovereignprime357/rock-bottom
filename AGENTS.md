# AGENTS.md — Agent Operating Constraints

> You are picking up a satirical action game in mid-build. Operator is Sovereign Prime (VibeKoded). ~~v3 is shipped.~~ **[✅ F-AGENTS-4: v21 is shipped — `<title>ROCK BOTTOM v21</title>`. Rule 3 below states the modular reality correctly; this header contradicted its own body.]** The comedic voice is a HARD spec — read VIBE.md before touching anything.

> ## ⚠️ AUDIT CORRECTIONS 2026-07-18 (`CORPUS-AUDIT.md`)
> This file's 2026-07-15 rewrite got the architecture right (modular v21, frozen v19 reference,
> IndexedDB-backed `window.storage`, declared-size sprites, 18s/8s loop all verify). Six lines carry
> **v3-era phantom identifiers that exist in no preserved build** — corrected in place below. The
> audio/timer tripwire names are the dangerous ones: obeying them builds a **duplicate** audio or
> timer system parallel to the real one. Live names: loop = `P.rockedT`/`P.crashT` (`update.js`),
> audio gate = `audio.ready` with `tone()`/`noise()` (`audio_save.js:230`), synths live on the
> **`audio`** object (not `sfx`), player update = `update()`/`updateWorld()`.

---

## Hard rules (non-negotiable)

### 1. Read VIBE.md first
Not optional. Not skimmable. The comedy is the product. Mechanics serve the comedy, not the other way around.

### 2. Spec before generate
Adding a new system? Add the SPEC entry first. Spec without code is a draft. Code without spec is slop. Both, in order, is SpecMesh.

### 3. Plain ES module architecture — single-file rule RETIRED
The former “everything in one HTML file” hard rule was deliberately retired by the operator on 2026-07-15. It existed for the Claude artifact host and no longer serves the hosted autonomous-loop experiment at this size. `rock_bottom_v19.html` is the frozen behavioral reference; active source lives in `index.html` plus section-derived files under `src/`, loaded as native ES modules over HTTP. Keep zero external runtime dependencies, zero CDN imports, zero frameworks, and no build step unless a later ratified SPEC changes that boundary. Do not recombine the source into a monolith merely to restore double-click execution.

### 4. window.storage, NEVER localStorage — REAFFIRMED
The architecture change does not retire the storage abstraction. Use `window.storage.set / .get` exclusively; the browser fallback is IndexedDB. All calls stay async and wrapped in try/catch. Never scatter `localStorage` or `sessionStorage` through modules.

### 5. Audio init on first user interaction
Browser autoplay policy. Audio context must be created in a keydown or click handler, never on page load. ~~Track `audioReady` boolean to gate all `beep()` calls.~~ **[✅ F-AGENTS-2: the gate is `audio.ready` (`src/core/audio_save.js:230`), checked inside every synth (`if (!this.ready || this.muted) return;`); primitives are `tone()`/`noise()`, not `beep()`. Building a new `audioReady`/`beep()` wrapper makes a duplicate audio state that desyncs mute/init.]**

### 6. Pixel sprite discipline
- Every character base explicitly declares `32×32` logical art; selected environment sprites may
  explicitly remain `16×16`. There is no inferred/default size.
- Both logical sizes prerender through the same toolkit to an exact `32×32` cache canvas. Character
  art is 1:1; the explicit environment holdouts scale 2×.
- Palette-indexed grids only. The Wave 4.2 grandfathered palette corpus is hash-pinned; additions
  still obey VIBE's forbidden-color rules.
- Cached in `SPRITE_CACHE` object
- Drawn via `ctx.drawImage` — never `fillRect` per pixel at runtime

### 7. Test the rocked-up + crash loop after any change touching it
The 18s high → 8s crash loop is the comedic core of the gameplay. **[✅ F-AGENTS-1: the loop and timing are LIVE and correct; the tripwire names below drifted to v3 identifiers that exist in no build. An agent greps them, finds nothing, and skips the mandatory playtest — or "restores" a duplicate.]** If you touch any of:
- ~~`updatePlayer` timing~~ → **`update()` / `updateWorld()`** (`src/core/update.js`)
- ~~`rockedUpTimer` / `crashTimer`~~ → **`P.rockedT` / `P.crashT`** (`update.js:127-130`, `concessions.js:286`)
- ~~`sfx.rockUp` / `sfx.crash`~~ → **`audio.rockUp()` / `audio.crash()`** (`audio_save.js:269,272`)
- The `smoke a rock` dialogue option (`concessions.js:250`)

→ play it end-to-end before shipping.

### 8. Boss fight must remain defeatable in <90 seconds
For a competent player. This is a comedy boss, not a tactical RPG boss. If a change makes the fight harder than 90s, the change is wrong.

### 9. Performance: <16ms frame at 60+ NPCs
Profile if adding particle systems, projectiles, or per-frame computation. Use the existing prerender pattern for any new sprites.

### 10. No fourth wall breaks
No "this game," "I, Codex," "the developer." The world is the world.

---

## Soft rules (prefer, but exceptions allowed)

### Prefer extending existing systems over adding new ones
- Adding a status effect? Look at the **`P.rockedT` / `P.crashT`** pattern (`src/core/update.js`). *(F-AGENTS-1: not `rockedUpTimer`/`crashTimer` — those never existed.)*
- Adding a new NPC behavior? Look at `npc.wander` / `npc.hostile` / `npc.zoneOnly`.
- Adding a new currency? Reconsider. You probably don't need it.

### Prefer Web Audio synthesis over samples
If a new sound is needed, write it as a synth function in the ~~`sfx` object~~ **[✅ F-AGENTS-3: there is no `sfx` object. All synths (`rockUp`, `crash`, `copSiren`, `bossRoar`…) live on the `audio` object created in `init_audio_save()` (`src/core/audio_save.js:226`). Add new sounds there so they inherit its `ready`/`muted` gating.]** Match the existing chiptune aesthetic.

### Prefer canvas drawing over DOM elements
The HUD, dialogue, and toast are DOM. Everything else is canvas. New gameplay UI should be canvas to maintain the scanline/CRT effect.

### Prefer the established pixel-sprite system
Actors and world props are hand-authored palette-indexed sprites. Emoji are UI chrome only. Extend
the existing declared-size/cached-grid pipeline; do not introduce a second actor-art system or a
mixed external asset pack.

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
~~All sprite IDs, NPC IDs, function names use snake_case in this codebase.~~ **[✅ F-AGENTS-6: sprite/NPC IDs are snake_case (`scrap_dog`, `os_brutus`) — true — but function names are overwhelmingly camelCase (~396 declarations: `cacheSprite`, `updateWorld`, `smokeRockAt`) vs ~40 snake_case `init_*` entry points.]** Match the existing convention: **snake_case for IDs, camelCase for functions.**

---

## When in doubt

### When in doubt about tone
Re-read VIBE.md. Pick the option that is more flat and more specific. Fewer adjectives, more nouns. Less emotion, more accounting.

### When in doubt about mechanics
Check SPEC.md invariants. If your change would violate an invariant, your change is wrong (or the invariant is wrong — and changing an invariant requires updating SPEC.md first).

### When in doubt about scope
Check DELEGATION.md. ~~If your idea isn't on the v4 list~~ **[✅ F-AGENTS-5: the v4 list is a fully-shipped historical ledger. The live backlog is the v20/v21 waves and `SPEC-V22-PACKET.md`.]** If your idea isn't on the **current v21/v22** backlog, ask the operator before building it. The backlog is prioritized for a reason.

### When in doubt about whether something is funny
It's not. Cut it. Then write something more specific.

---

## What to do at the end of a session

1. Keep `rock_bottom_v19.html` untouched as the behavioral reference. Update modular source in `index.html` and `src/`; create another monolithic lineage file only if the operator explicitly requests one.
2. Update SPEC.md with any new systems, invariants, edge cases
3. Update DELEGATION.md — move completed items to "shipped," refine remaining items
4. Create/append BRAIN.md with the session log (what/why/decided/tried/next)
5. If you added new sounds: document them in SPEC.md sound section
6. If you added new NPCs: add to VIBE.md identity table
7. Present the served modular entry point and any relevant reference file for the operator to play

---

## What NOT to do (escalation triggers)

If you do any of these, the operator will be unhappy and the work will be reverted:

1. **Replace the hand-authored pixel aesthetic with stock/external art or emoji actors** — the local palette-grid sprites are the look
2. **Add a tutorial that explains anything** — discovery is the gameplay
3. **Make the game beatable without smoking a rock** — the entire point is the loop
4. **Add a "story mode" with cutscenes between zones** — there is no story, only consequences
5. **Add a "good ending" where the crackhead gets clean** — the protagonist is a clown, not a moral lesson
6. **Add real-world drug names, real cities, real victim references** — see VIBE.md HARD STOPS
7. **Use localStorage** — see Hard Rule 4
8. **Add Tailwind, React, any framework, CDN runtime, or unratified bundler** — native HTML/CSS/ES modules only, see Hard Rule 3
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
├── index.html       ← hosted modular entry point
├── src/             ← section-derived native ES modules
├── README.md
├── VIBE.md          ← THE SOUL
├── SPEC.md          ← THE SYSTEMS
├── AGENTS.md        ← THIS FILE
├── DELEGATION.md    ← THE BACKLOG
├── BRAIN.md         ← session continuity (append-only)
└── rock_bottom_v19.html   ← frozen behavioral reference
```

---

## Identity check before shipping

You are not building "a game about a sad addict." You are building "a comedy where the joke is the same crackhead trying the same things in the same neighborhood and the world keeps being weird at him." If you forget this, look at the possum.

The possum knows.


## Completion report contract (2026-07-15)

A delegation is DONE only when all five artifacts exist: (1) a commit hash on a named branch, (2) pushed to origin, (3) gate runner output pasted, all green, (4) the files-touched list, (5) a register entry for any decision executed. A dirty worktree or an unpushed commit is mid-flight, not done. A design document is not a completion report. Reports missing artifacts bounce unreviewed.
