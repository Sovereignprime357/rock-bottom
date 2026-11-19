# Dave support evidence: ready for root copy

This is an allowlist and byte-preserving copier, not a new engine run or a
promotion. Root may run from the repository root:

```powershell
python '.build/3d/dave-support-evidence-draft/package.py' verify
python '.build/3d/dave-support-evidence-draft/package.py' copy --write
```

The second command creates only the fixed, fresh
`artifacts/3d-full-port/dave-sleep-support` directory. It refuses any existing
destination. The first command verifies without writing it. No export runtime,
source archive, project/cache tree or user-data directory is copied. The existing
source archive is hash-verified through the one reference in `allowlist.json`.

The allowlist includes raw evidence from all five requested runs, nine original
PNGs, two browser JPEGs, exact art/successor/promotion/validation specifications
and overlays, the passive ground helper and the root staging/run provenance.
The `packager` directory records this specification, independent audit, copier
and its input pins. The final package receipt lists every copied byte hash.
Historical draft `pending`/`false` fields are retained verbatim; later outcomes
are explained here, not written into those earlier records.

## Independently checked outcomes

| Stage | Retained outcome |
|---|---|
| focused-v1 | Support 2028 checks / 3 groups / 384 samples; roster 2040; pose memo 13458; visibility 2112; original walkthrough contract 103 / 4 |
| native-v1 | Original driver; three 1280x720 PNGs; ordinary E wake, 4.006s upright idle, pigeon menu, 0.286349m resumed movement |
| web-v1 | Failed `certified normal return direction`; three original 960x540 PNGs still retained; no final movement receipt |
| focused-driver-v2 | Successor contract 121 checks / 5 groups; no repeat or relabeling of the earlier art gates |
| web-v2 | Three 960x540 originals; ordinary E wake, 4.025s upright idle, pigeon menu, 0.294327m resumed movement; empty failures/browser errors |

All staged files match the 495 original archive files plus their declared
overlays. All stages use Animator `d35234cd...`. The successor changes only the
test's post-Leave movement selection; no runtime collision, art or resource
change. The exported script hashes are unavailable in the Web report; the
staged inventories and served-export hashes, verified independently here,
provide that provenance. A successful Web export alone is not a browser pass.

All nine PNG hashes, byte counts and dimensions match their report entries.
This agent inspected all nine original images; the pillow is visibly below the
sleeping head and returns to the awake hand-side carry position. Root separately
reported reviewing all three Web-v2 originals and native sleep/awake. Raw machine
reports intentionally retain `visual_acceptance:false`; image review is recorded
as this separate human judgment, never changed inside a raw report.

Sleeping native/Web-v2 samples have roughly 8.9mm body clearance and 8mm pillow
clearance from actual floor rays. The focused actual-triangle test has 384
samples with minimum body clearance 8.692mm and intended soft head/cushion
overlap of 7.648–9.924mm. This is not zero-overlap or continuous-time collision
proof. Awake foot clearance remains the original 75mm; this is no general
grounding correction. The immediate wake changes only Dave's `asleep` field,
with unchanged player state, actor position and RNG. All awake-idle samples are
upright without sleep marks. Actual ordinary input counts and per-frame support
measurements are preserved in `AUDIT.json` and the raw reports.

The awake attachment restoration and image silhouette support the existing
pillow carry. Neither proves finger-pad contact nor improves all hand grips.
Synthetic ordinary keyboard/mouse events are not trusted hardware or pointer-lock
acceptance. There is no new persistence, audio, performance, other-NPC, campaign
or whole-port acceptance. Web-v1 remains failed, and its report does not identify
the particular obstacle responsible for its distant-return route refusal.

Independent peer review also compared all five staged projects with the archive
and reviewed the actual weighted body/rigid head/cushion test, finding no blocker
within these bounds. No engine, browser, export, Git or production edits were
performed by this packaging packet. Root owns final copy, register and commit.
