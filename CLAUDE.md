# CLAUDE.md — Agent Operating Constraints

> ## ⚠️ AUDIT CORRECTION 2026-07-18 — READ THIS BEFORE ANYTHING BELOW
> **This file was written 2026-05-26 and never revised. It describes the v3-era game. The shipped
> build is now v21.** A full corpus audit (`CORPUS-AUDIT.md`, cap-6, every finding backed by a
> reproduction command) found **8 findings here, 4 of them HIGH — active orders that would destroy
> shipped work.** The stale factual claims below are corrected in place with `✅ CORRECTED` blocks
> citing the finding ID; the original wrong text is struck through, never deleted, so the drift is
> auditable. **The discipline rules — SpecMesh, `window.storage`, audio-on-interaction, the tone
> rules, no fourth wall — are all still TRUE and unchanged.**
>
> **`AGENTS.md` is the current, authoritative agent-instruction file** (rewritten 2026-07-15).
> `README.md` points fresh agents there, not here. Where this file and `AGENTS.md` disagree,
> `AGENTS.md` and the `SPEC-*.md` packets win. This file is kept for continuity, not command.
>
> **Ground truth:** `index.html` + ~37 ES-module chunks under `src/`; `rock_bottom_v19.html` is the
> frozen hash-pinned behavioral reference (not the active build); characters are true-32px pixel art
> (93 bases / 373 keys); the suite is **13 gates**, `node tools/run-gates.mjs`.

> You are picking up a satirical action game in mid-build. Operator is Sovereign Prime (VibeKoded). ~~v3 is shipped.~~ **[✅ v21 is shipped — F-CLAUDE-5]** The comedic voice is a HARD spec — read VIBE.md before touching anything.

---

## Hard rules (non-negotiable)

### 1. Read VIBE.md first
Not optional. Not skimmable. The comedy is the product. Mechanics serve the comedy, not the other way around.

### 2. Spec before generate
Adding a new system? Add the SPEC entry first. Spec without code is a draft. Code without spec is slop. Both, in order, is SpecMesh.

### 3. ~~Single HTML file architecture~~ → **MODULAR — RETIRED, F-CLAUDE-1 (HIGH)**
~~Everything in one file: HTML, CSS, JS, sprites, audio. No external dependencies. No CDN imports. No build step. The whole game must be openable by double-clicking the file.~~

✅ **CORRECTED:** The single-file rule was **deliberately retired** at the modularize refactor. The
active build is `index.html` + ~37 native ES-module chunks under `src/` (`src/module-manifest.json`).
`rock_bottom_v19.html` is kept **only** as the frozen, hash-pinned behavioral reference. Native ES
modules do **not** load over `file://`, so the double-click property is gone by design — the game is
served over HTTP. **Still true:** no framework, no CDN, no build step, vanilla JS. **An agent obeying
the struck-through text would re-inline 37 modules and destroy the refactor, `module-gate`, and every
`tools/*.mjs` gate that reads `src/`.**

### 4. window.storage, NEVER localStorage
Claude.ai artifacts do NOT support localStorage or sessionStorage. They fail silently in a way that corrupts the save illusion. Use `window.storage.set / .get` exclusively. All calls async, all wrapped in try/catch.

### 5. Audio init on first user interaction
Browser autoplay policy. Audio context must be created in a keydown or click handler, never on page load. ~~Track `audioReady` boolean to gate all `beep()` calls.~~ **[✅ F-CLAUDE-7: the rule is real; the identifiers drifted. The gate is `audio.ready` (`src/core/audio_save.js:230`), checked inside every synth method; the primitives are `tone()` and `noise()`, not `beep()`. There is no `audioReady` global and no `beep()`.]**

### 6. Pixel sprite discipline — **CEILING RAISED, F-CLAUDE-3 (HIGH)**
- ~~16×16 logical, prerendered to offscreen canvas at init~~ ✅ **Characters are true `32×32` logical** integer palette grids (`src/render/sprite_art_player_32.js`, `sprite_art_npc_32.js`, `sprite_art_special_32.js`); `sprite_toolkit.js` accepts exactly `{16, 32}` and only **eleven environment sprites** remain 16-logical. (Wave 4.2, merged `dbd960c`.)
- ~~Scaled 2x to 32×32 display~~ ✅ Drawn 1:1 at `32×32` — the source **is** 32 now; the old 2× upscale is gone.
- ~~Palette-indexed (numbered string format, see PLAYER_SPRITES)~~ ✅ Palette-indexed **integer grids** (0–7). `PLAYER_SPRITES` and the "numbered string format" no longer exist. `sprite-gate` red-verifies the 93-base / 373-key contract.
- Cached in `SPRITE_CACHE` object — **still true.**
- Drawn via `ctx.drawImage` — never `fillRect` per pixel at runtime — **still true.**

> **An agent obeying the struck-through lines would author new sprites as 16×16 numbered strings — the exact format `sprite-gate` fails against — reverting the v21 character ceiling and the 13/13 suite.**

### 7. Test the rocked-up + crash loop after any change touching it
The 18s high → 8s crash loop is the comedic core of the gameplay. **[✅ F-CLAUDE-7: the loop and this rule are LIVE and correct — `P.rockedT = 18000` / `P.crashT = 8000`. Only the identifier names below drifted.]** If you touch any of:
- ~~`updatePlayer` timing~~ → **`update()` / `updateWorld()`** in `src/core/update.js`
- ~~`rockedUpTimer` / `crashTimer`~~ → **`P.rockedT` / `P.crashT`** (`update.js:127-130`, `concessions.js:286`)
- ~~`sfx.rockUp` / `sfx.crash`~~ → **`audio.rockUp()` / `audio.crash()`** (`src/core/audio_save.js:269,272`)
- The `smoke a rock` dialogue option (`concessions.js:250`) — **still accurate**

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

### ~~Prefer emoji NPCs over pixel-art NPCs (for now)~~ → **DEAD, F-CLAUDE-2 (HIGH)**
~~v3 has pixel-art player + emoji NPCs. This is the look. Adding pixel-art NPCs is on the v4 backlog (DELEGATION.md item 1) and is OK, but ALL NPCs should be converted, not just some. Inconsistency would break the aesthetic.~~

✅ **CORRECTED — this is the single most dangerous line in the file.** Emoji NPCs were eliminated by
**v13** and every character is now hand-authored 32px pixel art (93 bases, merged `dbd960c`). Emoji
survive **only in UI chrome** (HUD/phone/feed) and one world use (the `🔒` on locked buildings, per
`VIBE.md`). **An agent obeying the struck-through text would add new NPCs as emoji "to match the
look" — breaking the unified pixel roster and failing `sprite-gate` + `npc-registry-gate` — or treat
the shipped pixel migration as a revert-worthy violation.** New NPC art follows the 32px pixel bases.

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
~~All sprite IDs, NPC IDs, function names use snake_case in this codebase.~~ **[✅ F-CLAUDE-8: sprite/NPC IDs are snake_case (`scrap_dog`, `os_brutus`) — true — but function names are overwhelmingly camelCase (`cacheSprite`, `updateWorld`, `smokeRockAt`, `rollBlockRoute`); ~396 camelCase declarations vs ~40 snake_case `init_*` entry points.]** Match the existing convention: **snake_case for IDs, camelCase for functions.**

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

1. ~~Save the updated HTML file as `rock_bottom_v{N+1}.html` (NOT overwriting v3 — keep the lineage)~~ **[✅ F-CLAUDE-4 (HIGH): there is no v3 and nothing past v19. v20/v21 ship as COMMITS to `index.html` + `src/`; the displayed version is enforced by `tools/version-gate.mjs`. An agent obeying this flattens the modular build into a new monolith no gate covers. DO NOT create `rock_bottom_v22.html`.]** Commit your change to `src/` with a message referencing the SPEC section; run `node tools/run-gates.mjs` and confirm 13/13 before you call it done.
2. Update SPEC.md with any new systems, invariants, edge cases
3. Update DELEGATION.md — move completed items to "shipped," refine remaining items
4. Create/append BRAIN.md with the session log (what/why/decided/tried/next)
5. If you added new sounds: document them in SPEC.md sound section
6. If you added new NPCs: add to VIBE.md identity table
7. ~~Present the new HTML file via `present_files`~~ **[✅ superseded by F-CLAUDE-4: the game is served over HTTP / GitHub Pages, not handed off as a file.]** Push for the operator to play the live build.

---

## What NOT to do (escalation triggers)

If you do any of these, the operator will be unhappy and the work will be reverted:

1. ~~**Replace the emoji aesthetic with stock asset pixel art** — the emoji are the look~~ **[✅ F-CLAUDE-2 (HIGH): DEAD. The emoji-NPC aesthetic was retired at v13; hand-authored 32px pixel art IS the look now. The still-valid version of this trigger: don't replace the hand-authored pixel roster with stock/asset-pack art. The pixels are authored, not imported.]**
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

**[✅ F-CLAUDE-6: the map below omitted the entire active source, the gate suite, and the current instruction file. Corrected:]**

```
/rock_bottom/
├── README.md
├── AGENTS.md        ← THE CURRENT AGENT INSTRUCTIONS (authoritative, 2026-07-15)
├── VIBE.md          ← THE SOUL
├── SPEC.md          ← THE SYSTEMS   (+ SPEC-*.md packets: v20, v21 waves, v22)
├── CLAUDE.md        ← THIS FILE (v3-era, superseded by AGENTS.md)
├── DELEGATION.md    ← THE BACKLOG
├── BRAIN.md         ← session continuity (append-only)
├── ORCHESTRATOR-NOTES.md ← how AIs in this seat got it wrong (append-only)
├── CORPUS-AUDIT.md  ← the 2026-07-18 false-claim audit these corrections come from
├── index.html       ← the active build (HTTP entry; loads src/main.js)
├── src/             ← ~37 ES-module chunks (the real game source)
├── tools/           ← the 13-gate suite; run `node tools/run-gates.mjs`
└── rock_bottom_v4..v19.html  ← frozen monolith lineage; v19 is the hash-pinned reference
```

---

## Identity check before shipping

You are not building "a game about a sad addict." You are building "a comedy where the joke is the same crackhead trying the same things in the same neighborhood and the world keeps being weird at him." If you forget this, look at the possum.

The possum knows.
