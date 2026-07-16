#!/usr/bin/env node
/**
 * corpus-gate.mjs — the seed gate.
 *
 * WHY THIS EXISTS
 * ---------------
 * Every other gate in this repo checks the GAME. Nothing checked the CORPUS —
 * the tone bible, the spec, the agent rules, the session log. The corpus is the
 * thing every future version is reproduced FROM. It is the seed. A gate that
 * protects the output but not the seed protects the wrong thing.
 *
 * THE INCIDENT (2026-07-16)
 * -------------------------
 * An orchestrating agent read the working tree through a mount that was serving
 * two-day-old file contents. `git status` reported 508 deletions across VIBE.md
 * (-83), BRAIN.md (-196), DELEGATION.md (-125), SPEC.md (-66), AGENTS.md (-32).
 * VIBE.md was 345 lines at HEAD and 263 on the stale view.
 *
 * `git add -A && git commit` — the obvious, reasonable next move — would have
 * deleted two days of work in a well-formed, passing, entirely intentional-looking
 * commit. No error. No test failure. Every existing gate green, because every
 * existing gate checks the game and the game was fine.
 *
 * The agent had a written note warning about exactly this hazard. The note did not
 * stop it. Cross-checking the file against HEAD did.
 *
 * THE LESSON, WHICH IS THE WHOLE POINT OF THIS FILE
 * ------------------------------------------------
 * A note is a prompt. Prompts leak. Only a gate holds.
 *
 * WHAT THIS CATCHES
 * -----------------
 * It does not care WHY your view of the repo is wrong. Stale mount, botched merge,
 * a model "tidying up," a bad rebase, a truncated read — all the same shape:
 * the corpus silently shrinks. This fails on the shape, not the cause.
 *
 * ESCAPE HATCH
 * ------------
 * Deletions are sometimes correct. This gate is bypassable ON PURPOSE — but never
 * by accident, and never silently. See CORPUS_GATE_ALLOW below. A gate that cannot
 * be overridden gets deleted the first time it's inconvenient. A gate that can be
 * overridden silently is decoration.
 */

import { execFileSync } from "node:child_process";

// ---------- config ----------

/**
 * APPEND-ONLY. Any deletion is a failure, full stop. These are logs and registers:
 * the past does not get edited. (The repo already ratified "register append-only
 * discipline" in c44bbfd — this makes that rule mechanical instead of aspirational.)
 */
const APPEND_ONLY = [
  "BRAIN.md",
  "REFACTOR-FINDINGS.md",
  "time_log.md",
  // ORCHESTRATOR-NOTES.md is the field log of how an AI in the orchestrator seat got things
  // wrong, and it argues — at length — that notes do not hold and only gates do. Leaving it
  // guarded by nothing but its own advice would be the joke writing itself. It is append-only
  // for the same reason BRAIN.md is: a lesson someone deleted is a lesson someone repeats.
  "ORCHESTRATOR-NOTES.md",
];

/**
 * PROTECTED. Deletions allowed, but a large one has to be deliberate.
 * VIBE.md is first on purpose. It is the seed of the seed.
 */
const PROTECTED = [
  "VIBE.md",
  "SPEC.md",
  "AGENTS.md",
  "CLAUDE.md",
  "README.md",
  "DELEGATION.md",
];

// Any SPEC-<x>.md, <x>-AUDIT.md, or RESEARCH-<x>.md is protected too, without being listed.
const PROTECTED_PATTERNS = [/^SPEC-.*\.md$/, /^.*-AUDIT\.md$/, /^RESEARCH-.*\.md$/];

/**
 * How many deleted lines in one protected doc counts as "big enough to be a mistake."
 * 12 is deliberately low. A genuine edit that removes more than a dozen lines from the
 * tone bible is a real decision and deserves ten seconds of a human's attention.
 */
const DELETION_THRESHOLD = 12;

/**
 * The frozen behavioral reference. I-REFERENCE says it never changes. Ever.
 * It is the only thing in this repo that can prove what the game used to do.
 */
const FROZEN = ["rock_bottom_v19.html"];

// ---------- helpers ----------

const git = (...args) =>
  execFileSync("git", args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 64 });

const isProtected = (f) =>
  PROTECTED.includes(f) || PROTECTED_PATTERNS.some((re) => re.test(f));

const RED = (s) => `\x1b[31m${s}\x1b[0m`;
const YEL = (s) => `\x1b[33m${s}\x1b[0m`;
const GRN = (s) => `\x1b[32m${s}\x1b[0m`;

// ---------- the checks ----------

const failures = [];
const notes = [];

/**
 * CHECK 1 — the view-vs-HEAD sanity check.
 *
 * This is the one that catches the stale mount specifically, and it is the cheapest
 * check in the repo: if HEAD says VIBE.md is 345 lines and your working tree says
 * 263, one of those is a lie and you must not write until you know which.
 *
 * Deliberately compares line counts, not hashes — a hash mismatch is normal (that's
 * just an edit). A large unexplained SHRINK is the signature of a bad view.
 */
function checkViewSanity() {
  for (const f of [...APPEND_ONLY, ...PROTECTED]) {
    let headLines, diskLines;
    try {
      headLines = git("show", `HEAD:${f}`).split("\n").length;
    } catch {
      continue; // not in HEAD yet — new file, not our problem
    }
    try {
      diskLines = git("show", `:${f}`).split("\n").length; // index view
    } catch {
      continue;
    }
    const shrink = headLines - diskLines;
    if (shrink > DELETION_THRESHOLD) {
      failures.push(
        `${f}: HEAD has ${headLines} lines, your view has ${diskLines} (${shrink} fewer).\n` +
          `    If you did not deliberately cut ${shrink} lines from ${f}, YOUR VIEW OF THIS REPO IS WRONG.\n` +
          `    Do not commit. Verify the file on the host filesystem before touching anything.`
      );
    }
  }
}

/**
 * CHECK 2 — staged deletions against protected + append-only docs.
 * Reads the staged diff, because that is exactly what is about to become history.
 */
function checkStagedDeletions() {
  let numstat;
  try {
    numstat = git("diff", "--cached", "--numstat");
  } catch {
    notes.push("no staged changes to inspect");
    return;
  }
  if (!numstat.trim()) {
    notes.push("nothing staged");
    return;
  }

  for (const line of numstat.trim().split("\n")) {
    const [addStr, delStr, file] = line.split("\t");
    if (!file) continue;
    const dels = Number(delStr);
    const adds = Number(addStr);
    if (!Number.isFinite(dels)) continue; // binary

    if (FROZEN.includes(file)) {
      failures.push(
        `${file} is the FROZEN behavioral reference (I-REFERENCE) and it is staged with ` +
          `${adds} insertion(s) / ${dels} deletion(s).\n` +
          `    It does not change. It is the only proof of what the game used to do.`
      );
      continue;
    }

    if (APPEND_ONLY.includes(file) && dels > 0) {
      failures.push(
        `${file} is APPEND-ONLY and this commit deletes ${dels} line(s).\n` +
          `    Logs and registers do not get edited. The past is not a draft.`
      );
      continue;
    }

    if (isProtected(file) && dels > DELETION_THRESHOLD) {
      failures.push(
        `${file} is part of the CORPUS and this commit deletes ${dels} line(s) ` +
          `(adds ${adds}).\n` +
          `    The corpus is what every future version is reproduced from. Cutting ${dels} ` +
          `lines out of it is a real decision, not a side effect.`
      );
    }
  }
}

// ---------- run ----------

console.log("corpus-gate: the seed must not shrink by accident\n");

checkViewSanity();
checkStagedDeletions();

const allow = process.env.CORPUS_GATE_ALLOW;

if (failures.length === 0) {
  for (const n of notes) console.log(`  · ${n}`);
  console.log(GRN("\nPASS — corpus intact.\n"));
  process.exit(0);
}

console.log(RED(`FAIL — ${failures.length} corpus violation(s):\n`));
for (const f of failures) console.log(RED("  ✗ ") + f + "\n");

if (allow) {
  console.log(
    YEL(
      `OVERRIDDEN via CORPUS_GATE_ALLOW="${allow}"\n` +
        `This is now on the record. If that reason is not in the commit message, put it there.\n`
    )
  );
  process.exit(0);
}

console.log(
  YEL(
    "If every one of these is deliberate, say so out loud and run again:\n" +
      '  CORPUS_GATE_ALLOW="why this deletion is correct" node tools/corpus-gate.mjs\n\n' +
      "If ANY of them surprised you: stop. Your view of this repo does not match the repo.\n" +
      "Check the file on the host before you write anything. That is the whole reason this gate exists.\n"
  )
);
process.exit(1);
