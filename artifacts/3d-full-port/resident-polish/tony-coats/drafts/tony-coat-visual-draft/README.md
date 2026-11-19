# Tony17 original-render stage

Prepared without engine/browser/Git or production writes. Sole production delta:
the centrally passed23.5mm `character_art.gd` refinement, hash9cc532fa..., on the
exact fac5083 observed499-file archive. Seventeen explicit visual fixtures use
the production Animator and original roster camera/world/capture helpers.
All four removal states are included despite the generic --ids path's omission.
Four late-walk frames use the actual failed-fit velocity1.8/4.75s/0.05s loop.

Root may run these static checks without launching an engine:

```powershell
python -B .build/3d/tony-coat-visual-draft/static-check.py
node .build/3d/tony-coat-visual-draft/test-bridge.mjs
```

Prepare fresh native and Web stages (file writes only):

```powershell
python -B .build/3d/tony-coat-visual-draft/prepare.py stage --mode native --path .build/full-port/tony-coat-visual/native-v1 --write
python -B .build/3d/tony-coat-visual-draft/prepare.py stage --mode web --path .build/full-port/tony-coat-visual/web-v1 --write
```

Root owns the finite serialized engines, after its current queue is free:

```powershell
& .build/3d/tony-coat-visual-draft/run-staged.ps1 -RunRoot .build/full-port/tony-coat-visual/native-v1
& .build/3d/tony-coat-visual-draft/run-staged.ps1 -RunRoot .build/full-port/tony-coat-visual/web-v1
```

Each variant imports, runs the three-group schedule contract and either renders
native originals or exports Web. Exact source/tool checks before/after each step;
180/120/180s limits, hidden owned children,10s output drain/cleanup; all engine,
parse and leak errors refuse. Fresh directories/logs required; no retry/overwrite.
Native must actually exit0. A successful stage is not manual appearance approval.

Serve the Web stage using root's existing local server, open its actual index,
press Start once and wait for17 hashes. Download the original bundle before
closing. No variant choice beyond candidate. Web capture-only keepalive means
exit_code=null; any actual exit/error invalidates. The180s deadline remains.
OriginalPNG resolution1280x720 is checked by actual browser bitmap decode. Do not
use screenshots as substitutes for the seventeen original exported PNGs.

Validate the original downloaded bundle without editing it:

```powershell
python -B .build/3d/tony-coat-visual-draft/prepare.py bundle --path <absolute-original-bundle.json>
```

The validator requires the new Tony format, complete live receipts and cleanup,
null exit, no errors, deadline, exact17 ordered names/records, original hashes,
decoded dimensions and actual coat/rig receipts. No Web rounding policy or pixel
acceptance is inherited. Root reviews front/quarter middle/outer and lapel fit,
all three layers, removals, late gait, windup, peak and far silhouette.

`HISTORICAL-ORIGINALS.json` pins ten matching old resident baseline Tony PNGs plus
their report, read-only. They are older-source comparison aids, not exact fac5083
A/B proof; no matching windup/late-walk originals exist. No unrelated cast render
is requested. Central model evidence stays separate:738/4groups/48poses/71other
identities, inner1.166403mm/outer1.896977mm, roster2040/art196. Those numbers do not
substitute for the new native/Web appearance review.

`make-local.py` and `seal-local.py` are one-time preparation records. Do not run
them after handoff to refresh pins. `prepare.py` only admits their immutable
manifest and input hashes. All previous drafts/evidence remain untouched.
