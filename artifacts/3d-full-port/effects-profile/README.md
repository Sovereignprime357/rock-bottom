# Current effects performance: target still missed

The committed effects build is `2c32cb155567b859be067736ca63bc0c81005576` on
`codex/3d-full-port`, pushed to origin. Both runs use the unchanged sustained
workload: 120 warmup and 1,080 measured frames per phase, with at least 60 live
supported actors and rigs throughout. Original 16ms acceptance remains unchanged.

| Run | Day scene CPU p95 | Night scene CPU p95 | Acceptance |
| --- | ---: | ---: | --- |
| Exact committed effects source | 32.919ms | 26.988ms | false |
| Separate pose instrumentation snapshot | 28.626ms | 28.681ms | false, diagnostic only |

Hardware reported by Godot: i9-11900K, RTX 3080, Compatibility renderer,
1280x720, 4x MSAA, VSync off. These are actual rendered native runs. Their
different trajectories, frame intervals, catch-up steps and instrumentation
preclude treating the difference between rows as a causal speed improvement.

The first run uses only the three unchanged test overlays from the previously
reviewed frozen workload. The second uses the independently pinned working
effects snapshot, seven diagnostic/test overlays, and the identical driver and
MeasuredScene boundary. It is not labeled as a Git revision. Its exact source
stripping proofs and nested accounting contract pass; the latter completed 14
checks in three groups. All counters had 1,080-frame denominators and no invalid
stack accounting. Instrumentation overhead remains included.

Measured mean pose costs (day / night):

- Reset plus bone application: 0.327 / 0.225ms.
- Attachment synchronization: 0.635 / 0.419ms.
- Total pose ticks, counting nested rigs once: 3.511 / 2.582ms.

Reset/application is therefore not the dominant observed pose cost; no touched-
bone optimization was implemented from the earlier hypothesis. Contact counters
count dispatch-helper calls, including calls that do not select an IK branch.
Overlapping inclusive scopes and unrelated percentiles must not be added.

The committed build's effects simulation averages 0.027 / 0.025ms per source
update. This is the named simulation scope, not all presentation or GPU work.
The full scene still misses its budget; neither this small scope nor green
correctness tests establishes 60fps.

Each run retains raw reports, log streams, four original PNGs, source/export
provenance and source archive where emitted. Large executable files remain in
their `.build` run directories with exact hashes in provenance. `pose-harness/`
preserves the authoring packet and seven overlays; its `scripts/` and `tests/`
folders correspond to the original draft's `game3d/scripts/` and `game3d/tests/`.
Original absolute execution paths are preserved in the raw records. This package
does not silently repin or rerun a wrapper from its archival location.

`effects-checkpoint-delivery.md` records the preceding completed effects delivery.
The campaign, indexed rendering candidate, and remaining full-port acceptance
continue independently. Decision register: IMPL-3D-FULL-36.
