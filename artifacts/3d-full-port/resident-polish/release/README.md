# Resident polish release checks

Branch: `codex/3d-full-port`. This folder accompanies the commit that adds the
accepted coat, purchase-hand, doorway and empty-save corrections. See the
checkpoint report in `reports/2026-11-19-3d-resident-polish.md` and decisions45–47.

Actual runner output:

```
GATE RUNNER: 19/19 PASS
3D GATE RUNNER: 135/135 PASS (import clean; 90 engine suites and 45 source/parity checks; complete-port acceptance remains tracked separately)
```

`gates-original.log` and `gates-3d.log` retain the complete outputs. Three build
logs retain clean import and Windows/Web export. `export-hashes.json` records
the six local delivery-file hashes; compiled exports remain outside Git.
The browser uses content-addressed pack42d868a892f384e6d7ca1525842fb2ef952fed73fcda273aadb7cb9acf1bd97b.

Root opened the actual exported localhost8074 page, loaded the existing save,
continued into play, moved, paused, resumed and moved again. The screenshot
retains that final in-world view. `browser-console.json` preserves two embedded
browser pointer-lock WrongDocumentErrors; no clean-capture claim is made.
Right-mouse look remains the supported fallback. The user's save was not reset.

`composition-applied.json` records33 exact delivery files with specs applied
first. Metadata static checks and the separate scoped Tony acceptance closure
are retained in the sibling metadata folder. Staged checkout verification and
the final touched-file list are retained here. The successor checkout passes577
raw-byte checks plus the1315-check metadata gate; checkout-policy/ retains the
original573-file failure and exact two-file self-EOL correction. These artifacts
are checkpoint evidence, not full-port, Web shutdown, audio or16ms acceptance.
