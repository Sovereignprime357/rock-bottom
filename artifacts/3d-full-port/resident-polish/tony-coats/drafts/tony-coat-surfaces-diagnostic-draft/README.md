# Tony surface diagnostic-only successor

This preserves the failed v4 gate and Artb8b4. Only six diagnostic splices alter
the focused test: channel readback summaries, generating-triangle/barycentric
provenance, skipped-self-ray count and first8 detailed failures. Every original
`_check(...)` call is byte-identical and the full test reverses exactly to dcdc.

The fresh source-only stage is `.build/3d/tony-coat-central-v5-diagnostic`.
Its final source differs from failedv4 only at the focused test. No engine run
occurred during preparation; no old logs/stages/evidence were changed.

```powershell
python -B .build/3d/tony-coat-surfaces-diagnostic-draft/prepare.py verify-stage
& '.build/3d/tony-coat-surfaces-diagnostic-draft/run-validation.ps1'
```

The second command is ROOT-OWNED and deliberately expected to fail after the
focused test, leaving actual diagnostics under the fresh stage's validation-v1.
It preserves the same finite hidden-child runner/import/source/error checks.
It must not run native/Web or claim a passing test. Root uses the readback to
authorize a separately documented correction, never an arbitrary threshold drop.
