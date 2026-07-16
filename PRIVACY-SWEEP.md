# PRIVACY SWEEP — pre-public audit

**Repo:** `rock-bottom` · **HEAD:** `ce70ae3` · **Date:** 2026-07-16
**Scope:** every tracked file + all 76 commits across all 4 branches + full blob history.
**Read-only.** Nothing was changed. This document is the only output.

**Trigger:** repo is going public (GitHub Pages + portfolio receipt). One-way door — history persists after deletion.

---

## VERDICT

# SAFE TO PUBLISH

**No blockers. No secrets. No personal material. No history rewrite required.**

The sweep found **zero** hard blockers. Two low-severity items and three housekeeping notes are listed below — all optional, all his call, none of them reasons to delay.

This is a clean result, and it is worth saying plainly rather than dressing up: **BRAIN.md was the stated risk and BRAIN.md is clean.** 1,536 lines read end to end. It is a technical build log from first line to last. There is no venting, no personal life, no employer, no client, no third party, no drift. The document does exactly one thing for 207KB, which is itself the portfolio point.

---

## WHAT WAS CHECKED

| Surface | Method | Result |
|---|---|---|
| `BRAIN.md` (207KB / 1,536 lines) | **Read in full, end to end** | Clean — technical only |
| `DELEGATION.md` (56KB), `DELEGATION-CODEX.md` | Read | Clean |
| `SPEC.md` (133KB), `SPEC-V20-PACKET.md`, `SPEC-refactor-modularize.md` | Read + pattern scan | Clean |
| `AGENTS.md`, `CLAUDE.md`, `VIBE.md`, `README.md` | Read in full | Clean |
| `DRIFT-AUDIT.md`, `LEGIBILITY-AUDIT.md`, `REFACTOR-FINDINGS.md` | Read + scan | Clean (1 note) |
| `.claude/settings.local.json` | Read | No secrets; **gitignored; never committed** (history-verified) |
| `.agents/` | Listed | Empty, untracked |
| Game source (`src/`, `index.html`, `rock_bottom_v4..v19.html`, `tools/`, `qa_v19_temp.js`) | Grep: keys/URLs/endpoints/paths | Clean |
| **Full git history** (all blobs, all 76 commits, all branches) | Secret scan + email scan + deleted-line review | Clean |
| Commit messages + author/committer identities | `git log --all` | Clean |
| 40 PNG screenshots + `.thumbnail` | Viewed + dimension + metadata scan | Clean |
| 2 phone JPGs (`uploads/`) | **Viewed** + EXIF extraction | 1 low-severity flag |

**Grepped for and found nothing:** API keys (`sk-ant-`, `ghp_`, `github_pat_`, AWS `AKIA`, Slack `xox*`, Google `AIza`, private-key blocks, bearer tokens), passwords, credentials, emails, phone numbers, home address, health, therapy, family (`wife`/`daughter`/`kid`/`marriage`/`mom` as a person), money trouble, the paper mill, employer, PIIA, ASE Detect, Asphalt Solutions, Bob, Justin, clients, partnership/term-sheet/equity, real deal dollar figures, masonic/lodge/society/MOW, and named real people.

---

## FINDINGS

### 🟡 FLAG-1 — EXIF device metadata in two committed phone screenshots
**Files:** `uploads/Screenshot_20260522_070900_Brave.jpg`, `uploads/Screenshot_20260522_072821_Brave.jpg` (also present in git history)
**Category:** Device fingerprint metadata. Each JPG's EXIF carries an Android build fingerprint that identifies the **exact phone model, carrier/region variant, and firmware build**, plus a **UTC offset** (coarse timezone) and a per-image UUID.
**Explicitly NOT present:** no GPS, no coordinates, no location tags, no owner name, no device name. Confirmed by direct byte inspection — GPS tags are absent from both files.
**Visible image content is clean:** both are the game in a browser. No notifications, no personal tabs, no names. (Both show a truncated `claude.ai/design/p/...` artifact URL — cut off mid-string and account-private regardless. Not actionable.)
**Severity:** Low. This narrows "what phone he uses" and "roughly which timezone," nothing more.
**Fix:** Optional. Either (a) delete both JPGs — they are stale v3-era artifacts with no current value, or (b) strip EXIF in place. **Do not rewrite history for this.** The metadata is already in past commits, and a device model plus timezone does not justify a rewrite of 76 commits. If it bothers him, deleting the files going forward is proportionate.

### 🟡 FLAG-2 — Local machine path in an audit doc
**File:** `LEGIBILITY-AUDIT.md` line 4
**Category:** Absolute local Windows path exposing the machine's user-directory name.
**Severity:** Very low. It reveals a local account name, nothing linkable.
**Fix:** Optional one-line edit — replace the absolute path with a repo-relative one (`rock_bottom_v19.html`). Cosmetic; also reads more professional in a portfolio piece.

---

## NOTES (not privacy — flagged because the repo is going public)

### 📋 NOTE-1 — No LICENSE file
There is no `LICENSE` in the repo and no license section in the current `README.md`. A public GitHub repo with no license defaults to **all rights reserved** — which technically means nobody may legally reuse it, while everyone can still read it. Notably, an earlier README (still in history) carried the line *"Personal portfolio piece. Not for distribution."*, and a later draft referenced source-licensing terms; both were dropped. **Not a privacy issue.** But if the intent is "here's my receipt, look at it" then all-rights-reserved is probably correct and worth stating on purpose rather than by omission. His call.

### 📋 NOTE-2 — `uploads/` is a stale v3-era duplicate doc pack
`uploads/` holds outdated copies of `CLAUDE.md` (identical), `DELEGATION.md`, `README.md`, `SPEC.md`, `VIBE.md` from the original handoff. They contradict current reality — e.g. they still assert the **"Single HTML file architecture"** hard rule that was deliberately retired 2026-07-15, and describe the game as "Zelda-style." A reader landing there will get a wrong picture of the project. This is the "confusing to a reader" category, not a privacy one. **Fix:** optional — delete `uploads/`, or add a one-line header noting it is a frozen v3 artifact.

### 📋 NOTE-3 — `reports/2026-07-15-the-regular.md` exists in history but not on disk
Deleted from the working tree, still reachable in history. Reviewed in full: it is a purely technical completion report (commits, gate output, files touched). **No action needed.** Noted only so nobody rediscovers it later and wonders.

---

## THINGS I CHECKED THAT ARE *NOT* FINDINGS

Recording these so this ground doesn't get re-swept:

- **Real name.** `README.md` credits him by name as owner. Expected — it's his portfolio. Not a finding, per scope.
- **Author identity.** All 76 commits are authored and committed by `SovereignPrime <vibekoded@gmail.com>` — a single, consistent, **brand** identity. No personal email ever appears in any commit, on any branch. This is the thing that most often burns people going public, and it's clean.
- **Commit messages.** All 76 reviewed. Uniformly technical (`refactor: extract HUD module`, `v13 wave 8.6: playtest bug fixes`). Nothing personal, nothing venting, nothing leaked.
- **Profanity / crude humor / drug references.** Present, in-character, in game content only (4 instances per game HTML; 2 in BRAIN.md, both describing a sound cue and an achievement id). It is a game about a crackhead. Per scope, not a finding — and notably it is **authored content, not venting**. There is no frustration-at-AI-tooling material in this repo at all.
- **Dollar figures.** Every `$` in the repo is the in-game economy (rock prices, Pete's cap, office fees). Zero real money, rates, revenue, or deal terms.
- **"Mom", "boss", "shift", "society", "council", "contract".** All game vocabulary — an NPC, a boss fight, the Shift key, a dialogue joke, pigeons, and behavioral contracts respectively. Checked each; all false positives.
- **`window.claude.complete`.** Present in v10–v19 (the Possum prophecy). It is the artifact-host API — **no key, no endpoint, no credential**; `uploads/SPEC.md` explicitly documents "NO API key passed." It's also on-message for a repo whose whole point is "an AI built this."
- **`.claude/settings.local.json`.** Contains only Bash permission globs — no secrets. Correctly gitignored and **verified never committed** in any branch's history.
- **Real city names** (in the Train Hopper's lore lines). Creative content, not personal data, and not punching down. Out of scope for this sweep — a VIBE question, not a privacy one, and his call if it's even that.

---

## HISTORY VERDICT

**No history rewrite required.**

Full-history checks run:
- Secret-pattern scan across **every blob in every commit** on all branches → zero hits.
- Email scan across **every blob in every commit** → zero hits (not even the brand email appears in file content).
- Every file path that has *ever* existed in history → reviewed; nothing that should have been gitignored was committed.
- All 100 deleted markdown lines in history → reviewed individually; all technical.

Nothing was ever committed and later removed that would survive to embarrass him. The only thing history holds that the working tree doesn't is one technical report (NOTE-3) and the EXIF in two JPGs (FLAG-1) — neither worth rewriting 76 commits over.

---

## BOTTOM LINE

**Ship it.**

The two flags cost about thirty seconds each and neither blocks. The genuine result here is the absence of a result: months of AI-assisted session logging produced 207KB of build log with no leakage into it. The docs stayed on the subject the whole way through.
</content>
