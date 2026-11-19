# Certificate pair v2 — explicit observer successor, not measured

The old v1 wrapper remains held. This successor uses the corrected full-phase
snapshot on both variants and runs its five-group regression before export.
It does not repair or relabel old day timelines. See
`../performance-phase-snapshot-draft/AUDIT-LIMITS.md`.

Root first passes the snapshot gate and candidate's focused Adapter/Navigation/
Contact gates. Then use a fresh output name once:

```powershell
& ./.build/3d/positive-certificate-performance-v2-draft/run-paired.ps1 -RunName certificate-pair-v2
```

Outputs are under `.build/full-port/positive-certificate-performance-v2/`:
`certificate-pair-v2-baseline`, `certificate-pair-v2-positive_certificate`, and
`certificate-pair-v2-comparison.json`. Existing paths are refused.

Both start from the same exact495 resident archive. Four common test overlays:
corrected probe, unchanged normal-input driver, unchanged driver contract and
new snapshot regression. Only candidate receives the same three certificate
files; only its Adapter changes production behavior. No indexer/resource pool/
node packing/new instrumentation.120 warmup+1080 measured per phase and every-
frame60 requirement remain. All original16ms failures are retained. The focused
tests are outside measurement; the entire MeasuredScene class is unchanged.

Stage order for baseline: version/import/driver contract/snapshot contract/export/
native. Candidate adds retention contract before export. Source inventories are
checked around import/export/native and all proof/runtime/template/overlay/helper
pins remain explicit. Exactly the snapshot test UID is newly permitted on both
variants. Hidden owned-child900s watchdog and cleanup are unchanged.

Static/offline only:

```powershell
python .build/3d/positive-certificate-performance-v2-draft/static-check.py
python .build/3d/positive-certificate-performance-v2-draft/test-comparison.py
```

`transforms.json` reverses four helpers to held v1 exactly. `pins.json` separately
pins the source candidate and new observer packet. Source proof documents are
not engine acceptance. Candidate and observer fixes require an explicit successor,
never silent repinning. No engine has run here; root owns every validation and
performance decision. A completed diagnostic does not authorize promotion.
