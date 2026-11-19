# Tony expanded-surface original-render stage

Isolated successor of the unchanged Tony17 visual draft. The sole prepared
source change is Art9cc532fa→b8b4b58b. Every probe, schedule, camera, late-gait
input, bridge, shell, validator and runner byte is copied unchanged. The exact
input metadata reverse and complete native/Web prepared-source comparison are
checked by `verify-successor.py`. No engine/browser/Git/production work ran here.

Root first accepts the separate six-group geometry gate plus roster and Art.
Then use fresh outputs; old successful captures and their visual defects remain.

```powershell
python -B .build/3d/tony-coat-surfaces-visual-draft/verify-successor.py
python -B .build/3d/tony-coat-surfaces-visual-draft/static-check.py
node .build/3d/tony-coat-surfaces-visual-draft/test-bridge.mjs
```

Preparation only (no engine), once per fresh stage:

```powershell
python -B .build/3d/tony-coat-surfaces-visual-draft/prepare.py stage --mode native --path .build/full-port/tony-coat-surfaces-visual/native-v1 --write
python -B .build/3d/tony-coat-surfaces-visual-draft/prepare.py stage --mode web --path .build/full-port/tony-coat-surfaces-visual/web-v1 --write
```

Root-owned serialized engine commands, only when its queue is free:

```powershell
& .build/3d/tony-coat-surfaces-visual-draft/run-staged.ps1 -RunRoot .build/full-port/tony-coat-surfaces-visual/native-v1
& .build/3d/tony-coat-surfaces-visual-draft/run-staged.ps1 -RunRoot .build/full-port/tony-coat-surfaces-visual/web-v1
```

The runner preserves absolute log paths, hidden children, isolated APPDATA,
finite180/120/180s steps and10s pipe drain/cleanup, source/tool verification before
and after each step, exact completion tails, nonzero/error/leak rejection and
no overwrite. Native must exit0. Web export alone is not browser evidence.

Root serves the fresh Web directory and presses Start once. Retain the original
17PNG bundle and actual browser observations; the180s capture bound,1280x720
decoded dimensions and keepalive exit=null qualification remain unchanged.

```powershell
python -B .build/3d/tony-coat-surfaces-visual-draft/prepare.py bundle --path <absolute-original-bundle.json>
```

Review the rest/peak-strike lapels, shoulder coverage in coats2/1 and late gait,
all coat removals and far silhouette. Do not claim whole-art acceptance from a
machine capture result. Old visual-v1 evidence is never overwritten/reclassified.

`make-local.py` and `seal-local.py` are unchanged historical preparation records
copied for byte provenance; do not execute them in the successor. Likewise,
`create-successor.py` is a one-time authoring record and refuses a sealed packet.
The immutable prepared packet is governed by MANIFEST and SOURCE-SUCCESSION.
