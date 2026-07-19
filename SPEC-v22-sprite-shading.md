# SPEC — SPRITE SHADING PASS (v22 Wave 4.3)

status: 2026-07-18 · operator: *"more shading, more definition... just run the sprites."* Pure **art** track — reshades the existing 32px character roster for depth. AI-drafted, operator veto standing. **The acceptance gate is the operator's eye; no gate judges whether art is good** (the Wave 4.2 lesson). Graduates into SPEC.md on green gate + operator sign-off.

---

## WHAT

Rework the character sprite art — `sprite_art_player_32.js`, `sprite_art_npc_32.js`, `sprite_art_special_32.js` (currently **94 bases / 377 keys**) — for **more shading and definition** inside the existing 32×32 ceiling. Same roster, same keys, same screen footprint. **Denser art, not new art.** Wave 4.2 raised the resolution ceiling; this pass fills it in.

## WHY

The operator's own read from playing v21: the sprites landed ("they look fucking awesome") but *"could use more shading, more definition."* The 32×32 ceiling gave the room; most bases don't yet use it fully. This is the pass that makes the roster read as finished pixel art rather than upscaled-then-lightly-detailed.

## WHAT ALREADY EXISTS (grounded)

- **94 bases / 377 keys, true 32-logical** (`sprite-gate` PASS line), integer palette grids (0–7 per palette), no image smoothing.
- **`sprite-gate` freezes** the base sizes (`SPRITE_BASE_SIZES` `Object.freeze`), the no-smoothing raster rule, integer-only palette indices, **and a palette-use hash that is designed to be RE-RATIFIED** (`sprite-gate.mjs:26` — "the new hash is ratified below"). **So a denser palette is a supported, audited change — not a fight with the gate.**

## INVARIANTS

- **I-SAME-STRUCTURE.** ⭐ **94 bases, 377 keys, every direction/frame preserved.** This pass changes the *pixels inside* each grid, not the roster, the key count, or any base's frame set. `sprite-gate`'s structural pins (count, per-base frames, no dropped key) stay green untouched. **Adding or removing a sprite is a different wave.**
- **I-STILL-32-NO-SMOOTH.** ⭐ 32×32 logical, drawn 1:1, **integer palette indices only, `imageSmoothingEnabled = false`.** More shading means more *ramp steps within the palette*, never anti-aliasing, never fractional indices, never a blur. Detail comes from more pixels placed deliberately, not from smoothing.
- **I-PALETTE-VIBE.** ⭐ Shading ramps are built from VIBE's canonical spine (piss yellow, mold green, asphalt, sickly brown, dirty cream, rust, fluorescent purple, copper) and their darker/lighter steps. **The FORBIDDEN list still binds:** no pure white `#fff`, no bright blue outside cops, no pastels-as-new-base, no neon. **The palette-use hash gets re-ratified at its new denser state — that IS this wave's audited decision** (VIBE §Visual/palette). More shading is more *ramp*, not more *hues*.
- **I-SAME-SCREEN.** Each reshaded sprite occupies the **exact same 32×32 screen rect at the same anchor** — no base grows, shifts, or changes hitbox. If a character looks bigger or moved, it's wrong (the Wave 4.2 I-SAME-SCREEN rule holds).
- **I-STILL-A-CRACKHEAD.** ⭐ **Detail is not refinement.** More pixels on a crackhead is a *more detailed crackhead*, not a dignified/heroic/cute one. The shading serves grime, wear, and specificity — not polish. VIBE §Texture: *"the bit still lands flat."* A sprite that reads as *nicer* has failed; one that reads as *more itself* has landed.
- **I-EYE-IS-THE-GATE.** ⭐ **No gate can judge whether the art is better** — `sprite-gate` proves structure and discipline (counts, no-smoothing, palette-legality), never beauty. **Green means the machinery is intact, not that it looks good.** Acceptance is the operator's eye, per base. Report which sprites you think are weak — an agent that calls all 94 uniformly improved has stopped looking (the Wave 4.2 lesson, verbatim).

## EDGE CASES

- **Gear/weapon overlay alignment** — the player composite layers gear (`gear_*`) and weapons over the body. Reshading the body must keep every overlay aligned; reshade the composite as a unit and verify overlays still register (the Wave 4.2 gotcha).
- **The 11 environment sprites** stay 16-logical and are **out of scope** — this is a *character* pass. Don't touch them; `sprite-gate` holds them separately.
- **Palette hash churn** — every reshade changes the palette-use snapshot; re-ratify it **once, at the end**, at the final denser state, not per-commit, so the ratification reflects the shipped art.
- **A base that's already dense enough** — not every sprite needs more; forcing shading onto an already-good sprite can muddy it. Leave the ones that landed; spend the effort where it reads flat.

## ACCEPTANCE CRITERIA

- [ ] Character roster reshaded for shading/definition; **94 bases / 377 keys preserved** exactly.
- [ ] 32-logical, no smoothing, integer indices — `sprite-gate` structural pins green.
- [ ] Palette stays within VIBE's spine + ramps; **no forbidden colors**; palette-use hash **re-ratified once** at the final state; `sprite-gate` green at the new snapshot.
- [ ] Same screen rect / anchor / hitbox per base — no base grows or shifts.
- [ ] Gear/weapon overlays still align on the reshaded player composite.
- [ ] Suite green (**18/18**). Frozen v19 untouched.
- [ ] **A contact sheet / atlas rendered for the operator's eye** — the real acceptance gate. Report the sprites you judge weakest.
- [ ] BRAIN appended; `SPEC-V22-PLAN.md` 4.3 shipped; findings written not fixed.

## THE TRAP

**No gate can catch bad art, so the temptation is to trust the green suite as "done."** It isn't — 18/18 means the machinery survived, not that the roster looks better. **The operator's eye is the only acceptance that counts**, exactly as it was for Wave 4.2. Ship a contact sheet, name your own weak sprites, and let him rule.

Second trap: **"more definition" sliding into "more polish."** This is a game about a crackhead in a stupid world; the art is grimy, flat, and cursed on purpose. **Shading toward realism or cuteness betrays the whole tone.** More pixels means more *specific grime*, not a cleaner image. If a reshade makes a character look like they're having a better day, undo it.
