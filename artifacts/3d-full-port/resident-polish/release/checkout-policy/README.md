# Two-file checkout policy successor - root applies

The actual v1 failure is retained. Root applies these candidate bytes in order:

1. `candidate/SPEC-3D-PARITY-METADATA-V4.md` (append-only decision).
2. `candidate/.gitattributes` (append-only self LF rule).

`OVERRIDES.json` records both exact before/final hashes. The original 33-file
delivery and all 247 referenced hashes remain untouched. Only these two unpinned
delivery paths receive explicit verifier overrides; no source or evidence EOL
conversion is tolerated. Stage the two files through root's normal Git process.

Then root runs:

```powershell
python .build/3d/resident-polish-checkout-eol-successor-draft/verify-checkout.py --preflight
python .build/3d/resident-polish-checkout-eol-successor-draft/verify-checkout.py
```

New outputs are `resident-polish-checkout-v2`,
`resident-polish-checkout-v2-result.json` and
`resident-polish-checkout-v2-gate.log` under `.build/3d/`. Existing outputs refuse.
The failed v1 result is hash-pinned. No stage/reset/repin/cleanup command exists.
All raw artifacts must be finished and staged before the actual invocation.

Static preparation passed Python parsing, exact four-splice reversal to the
reviewed v1 checker, all 33 delivery plus two override hashes and 247 source pins.
No actual v2 checkout, Node gate, engine, Git or production edit was run here.
