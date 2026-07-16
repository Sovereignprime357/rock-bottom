# SPEC — MODULARIZE (the refactor)
## Project: Rock Bottom
## Phase: prerequisite for the autonomous-loop experiment
## Last Updated: 2026-07-15
## Status: ratified by the operator. Retires a declared hard rule — read §INVARIANT RETIRED first.

---

## WHAT

Split `rock_bottom_v19.html` — 12,737 lines, 649KB, one `<script>` block from line 241 to
12,735 — into ES modules. Same game, same behavior, different shape on disk.

**This is a refactor and nothing else.** No features. No fixes. No improvements. No "while I
was in there." The game that comes out plays exactly like the game that went in.

---

## WHY

**The stated reason: agent loops.** The operator intends to point scheduled autonomous
iteration at this game. A model editing a 12,737-line monolith cannot see what it breaks —
every edit is a blind swing at code outside its context window. Modules create physical
boundaries: the loop touches one file, and everything else is literally out of reach.

**An autonomous loop on a monolith doesn't compound work. It compounds errors.** Modules are
the containment that makes the experiment survivable.

**The seams are already drawn.** The script carries **83 top-level section comments**
(`// ---------- combat ----------`, `// ---------- save/load ----------`, and so on). Nobody
has to invent an architecture. The architecture is already written in comments; this SPEC
turns comments into files.

---

## INVARIANT RETIRED (on the record)

**`AGENTS.md` hard rule #3 — "Single HTML file architecture" — is RETIRED, deliberately, by
the operator, on 2026-07-15.**

**Why it existed:** Rock Bottom was born as a Claude artifact. Artifacts must be a single
file. The rule wasn't a game-design decision — it was the host environment written into law.

**Why it dies:** the game is leaving that environment for the operator's own site. The
constraint has outlived the thing that imposed it. Operator's words: *"we can retire the rule,
it no longer serves the experiment, we change the rules."*

**The lesson worth keeping, because it will happen again:** single-file was the *right* call at
500 lines and the *wrong* call at 12,737. Same file, same architecture — **the size changed
underneath it.** Architecture is not right or wrong in the abstract. It is right or wrong *for
a size*. Nobody ever decided to outgrow it; it accreted, one "go wild" at a time.

**Any agent reading `AGENTS.md` must be told rule #3 is dead.** Updating `AGENTS.md` is part of
this SPEC's acceptance criteria, not an afterthought. A retired rule that still reads as
non-negotiable will be obeyed by the next agent and silently undo this work.

---

## INVARIANT KEPT (a correction to the initial read)

**`AGENTS.md` hard rule #4 — "window.storage, NEVER localStorage" — STAYS.**

The initial assumption was that #4 was artifact debt like #3. **It isn't, and the code proves
it.** The shim at the top of the script already reads:

> *"The artifact host injects window.storage. A normal hosted/double-clicked browser does not,
> so keep the exact async API and back it with IndexedDB."*

Somebody already solved this. `window.storage` is a clean single storage abstraction backed by
IndexedDB when the artifact host is absent. It is not debt — it is an abstraction that works
everywhere. **Keep it. Do not scatter `localStorage` calls through the modules.**

---

## INVARIANTS

- **I-BEHAVIOR-IDENTICAL.** ⭐ **The refactored game must play exactly like v19.** Same
  mechanics, same numbers, same dialogue, same bugs. **A refactor that changes behavior is not
  a refactor, it is a bug wearing a refactor's clothes.** This is the invariant an eager model
  will break — it will want to "improve" things while it moves them. **It must not.** If it
  spots something worth fixing, it writes the finding down and *does not touch it*.

- **I-INCREMENTAL.** One module extracted per commit. Test after each. **No big-bang 83-module
  explosion.** If all 83 move at once and the game breaks, nobody can tell which move killed
  it, and the whole exercise produces zero information.

- **I-REFERENCE.** `rock_bottom_v19.html` stays on disk, untouched, as the behavioral
  reference. When something feels off, you play both and compare. It is the only ground truth
  that exists.

- **I-BOUNDARIES-FROM-CODE.** Module boundaries derive from the **83 existing section
  comments**. Do not invent a new architecture. Do not reorganize what the sections mean. The
  code already told us where it wants to be cut — follow it.

- **I-STORAGE.** `window.storage` remains the only storage API. See §INVARIANT KEPT.

- **I-NO-SCOPE-CREEP.** No save work. No account work. No hosting work. No loop work. Those are
  separate SPECs and every one of them is easier once this lands.

---

## PREREQUISITE — GIT. THIS COMES FIRST.

**The repo is abandoned at `a2517ab` — "v13 wave 8.6".**

`rock_bottom_v14` through `rock_bottom_v19` are **untracked**. `SPEC.md`, `BRAIN.md`,
`DELEGATION.md`, `README.md`, `VIBE.md` are all modified and uncommitted. **Six versions of
work exist as loose files with no history.**

Git wasn't skipped — it lapsed, right around when the wheel got handed to a different model.

**Before a single line moves:** commit v14–v19 and every modified doc, as-is, in one honest
"checkpoint before refactor" commit. Not to be tidy — because **a refactor with no rollback is
not an experiment, it is a coin flip.** And the autonomous loop that comes after this is
strictly worse without it.

---

## PROPOSED MODULE SHAPE (first cut — adjust to what the code actually says)

Derived from the existing section comments, roughly:

```
index.html          the shell: <style>, <body>, one <script type="module">
src/
  core/             storage shim, constants, world state, update loop, init, start
  data/             zones, npcs, dialogues, equipment, props, buildings, chatter
  systems/          combat, save/load, quests, factions, wanted+cops, achievements,
                    hustles, heists, hideouts, events, phone/news
  minigames/        heat/cook, rhythm panhandle, lockpick
  render/           render, HUD, tile palettes, building draw, cached sprites
  input/            keyboard, mobile touch, analog joystick
```

**No file over ~1000 lines.** If a module lands bigger than that, it's two modules.

---

## THE BUILD-STEP DECISION (operator's call)

Single-file had one genuine virtue: **double-click it and it runs, anywhere, forever.**
Modularizing costs that, and it's an honest trade:

**Option 1 — plain ES modules, no build step.** `<script type="module">` + `import`/`export`,
native in every modern browser, zero tooling. **Catch:** ES modules are blocked over `file://`
by browser security, so double-clicking the HTML stops working — it needs to be served over
http. **Which is where it's going anyway** (his own site), so the cost may be zero in practice.

**Option 2 — modules + a bundler** (esbuild/vite) that compiles back down to one distributable
file. Agents edit clean modules; the output is still one file you can open anywhere. **Cost:**
npm, a build step, and a thing that can break.

**Recommendation: Option 1.** Start with no build step. The game is being hosted anyway. Add a
bundler later *only if* the double-click property turns out to matter.

---

## EDGE CASES

- **Circular imports.** A monolith has no import graph, so nothing prevents module A needing B
  needing A. Expect it. Fix by extracting shared state into `core/`, not by re-merging modules.
- **Global soup.** Everything in that script currently shares one scope. Extraction will
  surface hidden couplings — things that only worked because everything could see everything.
  **Those discoveries are the point.** Document each one; don't paper over it with a global.
- **Load-order dependencies.** Code that only works because it ran at line 4,200 instead of
  line 900. Modules make order explicit, which will break some assumptions. Good.
- **Something breaks and it's unclear when.** That's what I-INCREMENTAL and the git checkpoint
  exist for. Revert one commit, not one day.
- **The model wants to fix things it finds.** It will. See I-BEHAVIOR-IDENTICAL. Write findings
  to a list; touch nothing.

---

## ACCEPTANCE CRITERIA

- [ ] **Git checkpoint committed first.** v14–v19 and all modified docs are in history before
      any refactor work begins.
- [ ] The game **loads, starts, and plays**. Smoke checklist: new game starts · movement works ·
      an NPC dialogue fires · a save round-trips through `window.storage` · combat resolves ·
      the cook/heat minigame runs · the boss spawns and is beatable · mobile touch controls
      respond.
- [ ] **Behavior matches v19** on that checklist. Where in doubt, play both.
- [ ] **No file over ~1000 lines.**
- [ ] Each module maps to a real section comment from the original.
- [ ] **Git history shows one commit per module**, not one big-bang.
- [ ] `rock_bottom_v19.html` still on disk, untouched.
- [ ] **`AGENTS.md` updated**: rule #3 marked RETIRED with the reasoning, rule #4 explicitly
      reaffirmed. The next agent must not re-impose a dead rule.
- [ ] A findings list exists for everything the refactor noticed and deliberately did not fix.

---

## AFTER THIS LANDS (not now)

1. **Test whether save already works when hosted.** The `window.storage` shim already falls
   back to IndexedDB. Persistence may already exist and just needs verifying — that would make
   the whole "make it save" feature unnecessary. **Check before building.**
2. The per-agent `AGENTS.md` files, one per segment.
3. The loop spec: direction + the gate (game must still load and play, or the pass reverts).
4. Hosting on the site, unlisted, same pattern as `/survey`.
