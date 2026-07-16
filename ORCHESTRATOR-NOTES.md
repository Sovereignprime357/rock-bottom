# ORCHESTRATOR-NOTES.md

> Flat notes. Things that went wrong while an AI held the orchestrator seat, and what I'd do to
> stop each one. Not architecture. Append at the bottom, don't reorganize.
>
> **Why this lives in the repo and not in a memory file:** the corpus reproduces. Whatever is in
> here propagates into every version that gets seeded from this tree. A lesson in my memory dies
> with my context. A lesson in the corpus is inherited.

---

## THE FLOOR (read this before worrying about any of the below)

**`rock_bottom_v19.html` is the rollback floor and it is frozen, hash-pinned, and tracked.**

v20 → v30 → v40 can be broken freely. If the iterations wander somewhere bad but we learned
enough along the way to run the automation, **the move is not repair — it's roll back to v19 and
set it loose again with what we learned.** The corpus reproduces its own kind and likeness.

That reframes drift. **A branch going somewhere strange isn't damage, it's pattern completion** —
the seed doing what a seed does. The only unrecoverable move is **losing the seed**, which is why
`corpus-gate.mjs` exists and why it runs before everything else. Break the game all day. Do not
break VIBE.md.

**Consequence for anyone in this seat:** be aggressive with the game, paranoid with the corpus.
Those are not the same posture and treating them the same is the mistake in both directions —
timid builds, careless docs.

---

## 2026-07-16 — first day in the seat

### 1. I trusted a lying filesystem and nearly deleted two days of work

**What happened:** read the repo through a sandbox mount that served two-day-old file contents.
`git status` showed **508 deletions that did not exist** (VIBE −83, BRAIN −196, DELEGATION −125,
SPEC −66, AGENTS −32). `git add -A && git commit` would have committed all of it **clean and
green** — every gate passes, because every gate checked the *game*, and the game was fine.

**Prevention: `tools/corpus-gate.mjs`, wired first in `run-gates.mjs`.** Compares your view of
each protected doc against `HEAD` and refuses to run if they disagree; blocks staged deletions
over a threshold. `CORPUS_GATE_ALLOW="reason"` bypasses **loudly and on the record.**

**The part that actually matters:** there was already a written note in memory warning about this
exact mount, in these exact words. **It did not stop me.** I read it, and then did the thing
anyway. **A note is a prompt. Prompts leak. Only a gate holds.** If a lesson here is important,
it needs a mechanical enforcer or it's decoration.

### 2. I fabricated a crisis and got it ratified into a SPEC

**What happened:** same stale mount, same night. Saw a `git log` ending 10h back and concluded the
repo was abandoned. Wrote into `SPEC-refactor-modularize.md`, as a **hard blocking prerequisite**:
*"the repo is abandoned at a2517ab, v14–v19 untracked, six versions of work exist as loose files
with no history."* **The operator ratified it.** All false: `a2517ab` is 77 commits back, all six
versions tracked, tree clean, nothing ever lost. Retracted in place, not deleted — see the file.

**Why it got through:** the *reasoning* was true. *"A refactor with no rollback is a coin flip"* is
a good sentence. It was defending a repo that was never in danger. **Sound reasoning on a
fabricated premise is the most ratifiable thing an AI produces** — reviewers check the logic, and
the logic is fine.

**Prevention: none available. This one cannot be gated.** It was false prose, not a bad diff. Same
root cause as #1, and only one of the two symptoms is mechanically catchable. What's left is a
habit: **verify state, don't narrate it.** One `git ls-files` would have killed it before it was
written. It wasn't run because the story was coherent, and **coherent is not checked.**

**⭐ This is the autonomous loop's real exposure.** Not an agent that breaks the game — the gates
catch that, loudly, every time. **An agent that hallucinates a problem, solves it convincingly, and
gets the fabrication ratified into the corpus.** It cost nothing this time *only* because the
phantom fix was a no-op on a clean tree. **Assume the next one isn't.** If a loop pass proposes a
new hard prerequisite or a new invariant, the premise gets checked by hand before it lands. Full
stop.

### 3. Three false-positive tests in a row before the gate was trustworthy

**What happened:** tried to prove `corpus-gate` actually fires by gutting VIBE.md and staging it.
Attempt 1: `Get-Content X | Set-Content X` is a same-file pipeline — silently did nothing, gate
"passed." Attempt 2: truncation worked, but a stale `.git/index.lock` (left by my own earlier
`git add -A`) was failing every `git add` with **exit 128** — I misread "nothing staged" as "the
mount caught up." Attempt 3: never checked `$LASTEXITCODE`. **Only attempt 4 genuinely fired.**

**Prevention:** *a test that cannot fail is not a test.* **Before trusting any green, make it go
red on purpose.** If you can't produce the failure, you haven't tested anything — you've watched a
no-op succeed. Same family as the synthetic-touchmove false positive from an earlier wave. This
keeps happening and it will keep happening.

**Corollary: check `$LASTEXITCODE`.** A silent command is not a successful command.

### 4. I defaulted to the broken tool while a working one sat right there

**What happened:** spent an hour reasoning about being blocked by the sandbox — wrote the operator
an explanation of the limitation — while having PowerShell and `gh` CLI on the real machine the
entire time. He had to tell me. **The fix was not new access. It was noticing what I already had.**

**Prevention:** when a tool produces a weird result twice, **stop debugging it and ask what else
can answer the same question.** Reaching for a second instrument is cheaper than theorizing about
the first. And the second instrument is *outside the first one's fishbowl*, which is the only
place a real check can come from.

### 5. I documented a bug and committed it one command later

**What happened:** found that PowerShell's `Get-Content X | Measure-Object -Line` **doesn't count
blank lines** and undercounts every file. Wrote it into BRAIN.md. **Next command**, reported
BRAIN.md went "1357 → 1756 lines" for a 14-line append and nearly let it stand. Two different
rulers on two different files. `git diff --numstat` said **+14/−0**, correct all along.

**Prevention:** `(Get-Content X).Count`, or just `git diff --numstat`, which measures the only
thing that matters. But the real note is the one in #1, proven on myself inside five minutes:
**knowing the failure did not prevent the failure.** What caught it was the number looking wrong —
**verification from outside beat my own fresh note.**

### 6. Docs drift silently, and nothing was watching

**What happened:** `README.md` said the runner *"streams all four gates"* — it streams seven.
`uploads/README.md` still said **"Not for distribution"** inside a now-public MIT repo: **two
conflicting licenses in one tree**, which is a real problem for anyone forking. Neither was caught
by anything, because gates check code.

**Prevention:** partial. Gate counts are now a table in the README, which makes the drift visible
but not blocked. **Honest status: this class is still unguarded.** A doc gate that asserts
"README's gate list == `GATES` array in `run-gates.mjs`" is a real candidate and hasn't been built.
Adding it here so the gap is on the record instead of in someone's head.

---

## STANDING RULES FOR WHOEVER HOLDS THIS SEAT

1. **Aggressive with the game, paranoid with the corpus.** v19 is the floor; the seed is not.
2. **Verify state, don't narrate it.** One command beats a coherent story. Coherent ≠ checked.
3. **Make every green go red once before you trust it.**
4. **If a lesson matters, gate it.** Otherwise you're writing decoration. Notes leak; this file
   included — it is a prompt, and it will not save you. `corpus-gate.mjs` will.
5. **When a premise is load-bearing, check the premise, not the reasoning.** The reasoning will
   almost always be fine. That's the trap.
6. **Delegate with the traps named.** Both agents that built v20 landings held the contract from a
   document, not a model — the method travels in writing. Tell them what they're about to want to
   do wrong; they'll watch for it.
7. **The gate is the floor, the taste is the ceiling.** Gates make bad work impossible. They do not
   make good work happen. Operator calls (OD-6 and its kind) stay operator calls.
