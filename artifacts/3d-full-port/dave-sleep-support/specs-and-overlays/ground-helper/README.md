# Dave passive ground diagnostic v2 — held

The only executable candidate is `tests/posed_ground_diagnostic.gd`. It changes no
poses or production code. Root can overlay that single helper into the existing
Dave walkthrough project; the existing capture call and three-input walkthrough
remain unchanged. Use a new output such as `ground-native-v2`; retain v1 verbatim.

Expected diagnostic differences:

- `rigid_head` identifies the actual head-bone attachment and all descendant meshes;
  `head` combines it with any head-weighted skin. The absent v1 `skinned_head` group
  was not an absent face.
- `minimum_world` still identifies the real lowest vertex, while each group and
  part now includes componentwise min/max bounds and a highest vertex witness.
- Actual layer-1 support rays start above all visible geometry. A below-floor
  pillow point must therefore retain negative clearance from a real floor hit,
  rather than miss because its ray started underground.
- The report records head/pillow bindings and transforms plus actual ray endpoints.

The spec contains a measured, sleep-only correction proposal. No root/neck/pillow
constant has been changed. Its estimate is about 39 mm upward body correction plus
coherent head support from the existing pillow; the corrected actual bounds must
settle the shape/placement before any candidate geometry is generated. Awake feet,
source wake, all hand/skeleton/contact behavior and other NPCs remain outside this
correction. There is no generalized hovering claim and no production ground snap.

Static scans and original-evidence pin verification are recorded in the manifest.
No engine, Git, new native acceptance or production edit occurred in this packet.
