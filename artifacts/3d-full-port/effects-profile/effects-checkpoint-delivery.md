# Effects checkpoint delivery

Branch: `codex/3d-full-port`

Commit: `2c32cb155567b859be067736ca63bc0c81005576`

Push: `origin/codex/3d-full-port`, confirmed successful:
`2a1f6ca..2c32cb1 codex/3d-full-port -> codex/3d-full-port`.

```
GATE RUNNER: 19/19 PASS
3D GATE RUNNER: 127/127 PASS (import clean; 85 engine suites and 42 source/parity checks; complete-port acceptance remains tracked separately)
3D BUILD: PASS (Full / All; Godot 4.5.1.stable.official.f62fdbde1)
```

Files: `artifacts/3d-full-port/world-feedback/files-touched.txt` (248 paths).
Decision: `REFACTOR-FINDINGS.md`, IMPL-3D-FULL-35.
Original runner, complete 3D runner, native/Web evidence, final export hashes and
manual screenshot: `artifacts/3d-full-port/world-feedback/`.

Play: http://127.0.0.1:8074/
Native: `.build/3d/full/windows/RockBottom.exe`.

Verified manual wake/play, movement, pause/continue and journal/inventory exits.
Known Chromium pointer-capture error and right-mouse fallback remain. This is a
completed effects checkpoint, not a declaration that the full port, complete
campaign acceptance or sustained 60-actor 16ms target is finished.
