# DELEGATION — Codex / GPT

**Read `DRIFT-AUDIT.md` and `LEGIBILITY-AUDIT.md` before you touch anything. Every task below
traces to a specific finding in one of them. If a task and an audit disagree, the audit wins —
it has line numbers and measurements. This document has opinions.**

Work the waves in order. **Each wave lands, gets verified, gets committed, and only then does
the next one start.** Do not batch. Do not run ahead.

---

## WAVE 0 — GIT. BEFORE ANYTHING ELSE.

The repo is abandoned at `a2517ab` ("v13 wave 8.6"). `rock_bottom_v14` through `v19` are
**untracked**. `SPEC.md`, `BRAIN.md`, `DELEGATION.md`, `README.md`, `VIBE.md` are all modified
and uncommitted. **Six versions of work exist as loose files with no history.**

1. Commit everything as-is. One commit. Message: `checkpoint: v14-v19 + docs before refactor`.
2. Do **not** clean up, reformat, or "improve" anything in this commit. It is a snapshot of
   reality, warts included.
3. Confirm `git log` shows it and `git status` is clean.

**Why this is Wave 0 and not a footnote:** everything after this point is either a refactor or
an autonomous loop hammering the file. **Work with no rollback is not an experiment, it's a coin
flip.** Nothing else starts until this is done.

---

## WAVE 1 — THE VIGNETTE. ONE LINE. DO IT FIRST.

**Finding:** `#vignette { z-index: 32 }` sits above **every** UI element — HUD, dialogue,
ticker, minimap. It drags the palette's real **10.58:1** contrast down to **2.4:1 exactly where
the text lives.**

The operator's reported bug *"business q cut off at the right edge"* **is not overflow.** It's
the vignette painting black over it.

**Mobile already has a 4× lighter override (8.9:1) that was never back-ported to desktop.**

**Task:** re-layer the vignette so it sits **under** the UI, or apply the existing mobile
override to desktop. **One `z-index` line moves every piece of text from 2.4:1 to 10.6:1.**

**Verify:** screenshot before, screenshot after. Look at them. The whole HUD should visibly
lift out of the mud.

**Why first:** highest ratio of impact to risk in the entire codebase. One line, no
architecture, instantly visible. Commit it alone so the before/after is a clean diff.

---

## WAVE 2 — THE MODULARIZE REFACTOR

**Read `SPEC-refactor-modularize.md`. It's the contract for this wave.**

Highlights, but read the SPEC:

- **`AGENTS.md` hard rule #3 "Single HTML file architecture" is RETIRED**, deliberately, by the
  operator, 2026-07-15. It existed because the game was born as a Claude artifact. That
  environment is gone. **Update `AGENTS.md` to say so, with the reasoning** — a retired rule that
  still reads as non-negotiable will be obeyed by the next agent and silently undo this work.
- **`AGENTS.md` hard rule #4 "window.storage, NEVER localStorage" STAYS.** It is *not* artifact
  debt. The shim already backs onto IndexedDB for hosted browsers. It's a clean abstraction.
  Keep it. Do not scatter `localStorage` through the modules.
- **83 top-level section comments already exist** in the script. **The architecture is already
  written — it's just written in comments instead of files.** Derive the module boundaries from
  those cuts. Do not invent a new architecture.
- **I-BEHAVIOR-IDENTICAL is the invariant you will be tempted to break.** The game must play
  exactly like v19 when this lands. No features. No fixes. No improvements. **No "while I was in
  there."** You will find things worth fixing. **Write them to a findings list and touch
  nothing.** A refactor that changes behavior is a bug wearing a refactor's clothes.
- **One module per commit.** Test after each. If all 83 move at once and it breaks, nobody can
  tell which move killed it and the whole exercise produces zero information.
- `rock_bottom_v19.html` stays on disk, untouched, as the behavioral reference.

**Operator's call on the build step:** plain ES modules, no bundler. It costs the
double-click-to-run property (ES modules need http), and the game is being hosted anyway.

---

## WAVE 3 — THE LEGIBILITY GATES

**These are the first four automated invariants. The audit already wrote them and already ran
them — each one has a real failing count today.** Do not re-derive. Do not re-measure. Read the
audit.

| Gate | Failing now |
|---|---|
| Building sign fits its sign plate | **21 of 24** |
| Zone label vs art collision | **1** (`THE LAUNDROMAT` → renders `"THE LA"`) |
| Nameplate de-confliction | **2 at spawn** (`WHOLE FOODS MOM` × `THE PHONE GUY`, 60px overlap, 20px apart, *before anyone moves*) |
| Graffiti fits its wall | **~51%** (hardcoded `-80` guess; tags run 43–335px) |

**⚠️ Do NOT build a text-vs-text collision gate.** The audit built one and found **0
intersections across 75 boxes.** **The collisions are text-vs-ART, not text-vs-text.** That's a
refuted hypothesis, already tested — don't waste a wave rebuilding it.

**The most important line in either audit:**

> **"Every correct pattern already exists in this codebase, applied once."**

`measureText` lives in nameplates but not chatter. Viewport `clamp` lives in the objective guide
but not the `(E)` prompts. **Auto-fit works in the facades (line ~8935, 0 violations across 28
facades) and nowhere else.**

**The fixes are propagation, not invention. Copy the pattern that already works. Do not write a
new one.**

Each gate ships **with its failing count going to zero**, and the gate stays in the repo as a
permanent check.

---

## WAVE 4 — THE ROOT CAUSE (spec the relationship, not the symptom)

The audit measured it. This is not a theory:

| | v10 | v19 | growth |
|---|---|---|---|
| World | 2200×1900 | **8600×5600** | **11.5×** |
| Buildings | 5 | **25** | 6.25× |
| `BUILDING_STYLE` keys | 4 | **4** | **frozen since v10** |
| Canvas | `W=800, H=600` | `W=800, H=600` | **never moved** |
| Sign coverage | 80% | **12%** | — |

**Same failure class as the crack-spot bug:** the map tripled but the withdrawal timer didn't,
so the player can now die crossing his own map.

**One root cause, two symptoms: the world grew and nothing that depends on world size grew with
it. Nobody specced the relationship.**

**Task:** find every constant that should scale with world size and doesn't. Document each one in
the findings list **with the relationship that was never written down.** Do not fix them yet —
**this wave is about making the invisible dependency visible.** Fixing comes after the operator
sees the list, because some of these are design decisions, not bugs.

**Honest note from the audit, and respect it:** the vignette is **NOT** a growth bug.
`inset 0 0 100px 20px #000` is byte-identical v10→v19. It never regressed — it's an original sin
that got more expensive as text accumulated. **Don't let it ride the growth thesis. The auditor
flagged this specifically rather than letting a clean story swallow a fact that didn't fit.**

---

## WAVE 5 — THE NPC REGISTRY GATE

**Finding:** all nine v19 NPCs are absent from VIBE's registry table, plus ~17 older ones.
**Over half the cast is off-book.**

**Traceable cause, and this is the lesson:** `SPEC.md` §v18 required *"registered in VIBE before
ship."* **§v19 dropped the clause.** The gate was removed and nobody noticed.

**And the four names that fail VIBE's cursed-name test are exactly the four that never had to
take it:** `TARP KNIGHT`, `CART LANCER`, `WIRE DEACON`, `CURB HOLDOUT`. That last one is
literally VIBE's own ❌ example — "Bandit" with a prop stapled on.

**The registry's four columns aren't bookkeeping. They ARE the test.** A name must answer: what
they're missing / what they sell / what they pretend / what was done to them.

**Task:** restore the registration requirement as a **mechanical gate** — a new NPC cannot ship
without a registry row. Backfill the ~26 missing entries. **Flag the four failing names for the
operator. Do not rename them yourself — that's taste, and taste is his seat.**

---

## NOT YOUR CALL — bring these to the operator

- **The four failing NPC names.** Flag, don't rename.
- **The one-joke problem.** ~54 authored beats in the endless loop all run one construction, while
  VIBE's four named patterns survive **only** in v4-era random events. Nobody chose this — *the
  clerical pattern is generative and the others aren't, so "make it bigger" promotes it by
  default.* **This is a design decision, not a bug.**
- **The medieval register.** The auditor argued *against the rule* here — `"the throne remains a
  folding chair"` only works *because* there's a throne. It recommends amending VIBE HARD YES #6
  rather than the game. **The operator decides whether a rule bends.**
- **The real structural finding:** *"The game didn't drift from VIBE. VIBE stopped being big
  enough to cover the game."* It governs **the sentence** and is **silent on scope, campaign
  shape, and pattern rotation** — and **silence is what "make it bigger" fills.** Extending VIBE
  is the operator's job. It's the tone bible; he's the tone.

---

## ONE SMALL BUG (fix it in whatever wave it fits)

**11 mojibake sequences**, one corrupting a shipped toast: `'Â· NEW BAD IDEA Â·'`, line 1621.
Encoding damage from some earlier pass. Also `// ---------- v18 â€” THE OFFICE ...`.

---

## STANDING RULES

1. **The audits outrank this document.** They have line numbers and measured contrast ratios.
   This has opinions.
2. **Behavior identical through Wave 2.** No improvements during a refactor.
3. **One thing per commit.** The whole value of this sequence is being able to answer "which
   change did that."
4. **When you find something worth fixing that isn't in your wave: write it down, don't touch
   it.** The findings list is the deliverable.
5. **Don't manufacture work.** Both auditors reported things they *couldn't* confirm rather than
   inventing findings — the `"ROOM FOR 1"` billboard **fits** (91.8px in 116px), and the
   text-vs-text gate found **zero** violations. **That honesty is the standard. Match it.**
