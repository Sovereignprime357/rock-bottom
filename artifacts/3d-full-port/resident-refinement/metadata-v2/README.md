# Resident metadata-v2: isolated handoff

READY. Root composes only the five paths listed in `DELIVERY.json` from
`candidate/`, after checking each old/new hash and the three final resident
hashes. This packet does not copy source art or tests into production. Root's
separate resident promotion owns those five approved inputs.

The raw approved roster-test input is CRLF
`b97b4bcd4481ee06b798bbb301c0b8e89f42b1b504480ddc428a9b055a63f217`.
Its only approved final-byte conversion is 1052 CRLF to LF, producing
`f85737b38e96d24cc4c0557eb9500f6f728116a99210b0cca6d9e11246119b6c`.
Cast remains LF; FullScene remains CRLF. No attributes are changed here.

Validation completed without engines or Git:

```
RESIDENT METADATA REVISION: PASS (810 checks; exactly3 revised pins;617 complete refusals; no production writes)
ADDITIVE PARITY CONTRACT: PASS (152 checks;5/5 groups;26 ledger counterexamples; --complete still fails)
ADDITIVE PARITY GATE: PASS (1315 checks; metadata only; FULL PORT INCOMPLETE; pins=metadata-v2)
ADDITIVE PARITY MIGRATION: PASS (1315 checks;585 handlers/32 features/30 dispositions/96 narrow refs; all statuses unchanged; pins=metadata-v2)
RESIDENT RUNNER PARSE: PASS (syntax only; runner not executed)
```

The expected complete-gate result is FAIL with exactly 617 `Incomplete` errors.
V1 passes its saved original raw view and rejects exactly the three final paths.
V2 rejects the old view, all seven incomplete old/new combinations, per-file
drift, and the unnormalized CRLF roster candidate. Missing, duplicate, unknown
and path-like revision selectors still refuse. The actual exported CLI
functions are tested through an injected reader; no copied validator logic.

The first draft-only contract attempt had a test-authoring mistake: it searched
for a `%s` print format, while the existing Dave contract uses comma-separated
print arguments. The check now matches that actual output and its four-group
completion guard. No source/validator behavior changed for that correction.

Re-run the isolated Node check:

```
node .build/3d/resident-metadata-v2-draft/test-revision.mjs
```

`prepare.py` is the explicit initial staging recipe, not an automatic rebase
tool. It checks literal old/source hashes and refuses changed inputs; do not
rerun it against a later composition to refresh pins. `originals/` preserves
the exact three old raw source inputs plus tool/runner bases. `validation/`
contains only copied validator dependencies and the two-literal-edit selector.
Only `candidate/` paths listed in `DELIVERY.json` are delivery files.

After root promotion, the usual three Node commands explicitly use v2:

```
node tools/parity-metadata-test.mjs --pins=metadata-v2
node tools/parity-metadata-migrate.mjs --pins=metadata-v2 --check
node tools/parity-metadata-gate.mjs --pins=metadata-v2
node tools/parity-metadata-gate.mjs --pins=metadata-v2 --complete
```

The last command is expected to fail. Root alone runs the updated full engine
runner: 86 engine suites plus 45 source/parity checks, 131 total, with import
checked separately. Actual 131-suite execution is not claimed by this draft.

The rebase record lists exact affected implementation/test links and existing
evidence IDs as dependency information. It never turns historical evidence
into evidence for the new implementation. All 617 statuses, 96 references,
qualifications, false outcomes and remaining obligations remain byte-identical
in `parity_manifest.json` (SHA256
`a24f663ad71cda9dc9879caca7d7df9a9fc89bfc88e998f462d40725902eaa42`).
The separate accepted resident review is hash-attributed and retains its
narrow capture-only Web/no-shutdown/performance boundary. The later sleep
ground diagnostic, eave rendering and indexing experiments are excluded.
