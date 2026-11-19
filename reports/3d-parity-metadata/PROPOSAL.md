# First-person parity disposition proposal

Draft for root review, not a ratified spec or a manifest change. The selected
targets are Windows first person and keyboard/mouse Web. Existing pixel/mobile
source remains intact. All585 source identities and32 features remain in the
census. Current555 integrated/28 partial/2 planned is implementation bookkeeping,
not a completion percentage; every native/Web evidence array is currently empty.

## Exact source classification

`handler-dispositions.json` records each of the30 identities with source hash,
line, current status, concrete equivalent, evidence requirement and proposed
decision. The following groups summarize those exact rows.

| Source identity group | Count | Proposed obligation |
|---|---:|---|
| `sprite_toolkit.js`: assertSupportedLogicalSize, parseGrid, applyVars, blankSpriteGrid, gridPut, gridBox, gridLine, gridEllipse, mirrorGrid, cloneGrid, anchorGridToBottom, rasterize | 12 | Original authored mesh/material/profile construction replaces raster authoring. Keep palette, finite geometry, grounding, cache and identity acceptance. No invented runtime pixel parser. |
| `sprites.js`: anchorGridToBottom, applyVars, blankSpriteGrid, gridBox, gridLine, gridPut, mirrorGrid, parseGrid, rasterize | 9 | Exact reexports point to their canonical toolkit obligation. Preserve each census row; validate alias identity and dependency. |
| `sprite_art_player_32.js:makeRoutePatch32` | 1 | Chest lies outside the arms-only camera. Preserve route progression and FILED journal/Office unlock. Explicitly accept unseen chest artwork; do not move it onto a wrist. |
| `sprites.js:makeRoutePatch` | 1 | Actual legacy16-grid generator, **not a reexport**. Current buildSprites uses makeRoutePatch32. Record call-site proof and same off-camera decision. |
| `actors_weather.js:drawPlayerContactShadow` | 1 | No rendered first-person body/feet. Explicitly accept no disembodied top-down foot blob; viewmodel shadows remain off, world/NPC shadows remain real. |
| `input/mobile.js:setupMobile` | 1 | Its whole setup is coarse-pointer gated. Touch joystick/buttons/gestures are outside selected targets; desktop equivalent commands remain required. |
| `input/mobile.js:init_mobile` | 1 | **Mixed**: exclude only coarse-touch setup. Retain title load, async save/no-save behavior and startup; SceneTree replaces RAF, isolated QA replaces window._rb tooling. |
| `input/mobile.js:titleLoadTap` | 1 | Actual title-load action. Require single normal Remember transaction, missing/refused-save behavior and callback isolation on native/Web. |
| `ui/layout.js:resolvePresentationLayout` | 1 | Perspective viewport/anchored HUD replaces source4:3 content letterboxing. Keep actual responsive desktop layouts at1280×720/960×540; exclude only touch-topbar allowance. |
| `render/frame.js:init_frame` | 1 | Source body is empty. Hash/AST-backed no-op disposition, not a fabricated action or screenshot. |
| `render/frame.js:drawAll` | 1 | Aggregate union of observable child obligations. Remains incomplete while genuine rendering gaps or required platform coverage remain. |

The source tier is `min(4,floor(routesCompleted/5))`; retaining route progress
does not mean the unseen badge has been rendered. `guidance_view.gd` reads the
real `lifetime.routesCompleted` for FILED and the Office prerequisite. Gear spec
already documents chest/hat/ear presentation boundaries. Whole body shadow
absence should receive its own explicit ratification instead of being inferred
from the separate viewmodel-shadow prohibition.

Source `init_mobile` conditionally reveals its load button after async storage
success; the3D title offers Remember and reports an empty/refused drawer. That is
a concrete UI adaptation to record and test, not a silent exact-copy claim.

## Suggested manifest and validator change — approval required

Keep source census/status and evidence lists. Add orthogonal structured fields;
do not introduce a generic `excluded` terminal status or promote all30 rows.
An example shape, not a patch to the live schema:

```json
{
  "disposition": {
    "kind": "raster_authoring_adaptation",
    "sourceSha256": "…",
    "decisionRef": "SPEC-…#approved-decision",
    "targets": ["windows_first_person", "web_keyboard_mouse"],
    "obligations": ["identity", "palette", "grounding", "cached_geometry"],
    "canonicalId": null,
    "excludedSubbehavior": []
  },
  "evidenceRefs": [
    {
      "path": "artifacts/3d-full-port/…json",
      "sha256": "…",
      "target": "web_keyboard_mouse",
      "scenario": "actual_pickup_cart_input",
      "covers": ["first_person_hand_visibility", "cart_grip_recovery"],
      "qualification": "rendered_synthetic_normal_input",
      "fixtureDisclosure": "none",
      "outcomeField": "input_frame_checks_pass",
      "revisionOrOverlayProvenance": "…",
      "humanVisualReviewRef": "…"
    }
  ]
}
```

Proposed validator rules, stricter than existence-only file references:

1. Keep exactly the585 source IDs and32 features. Source hashes must match.
   Require an explicit approved register/spec decision for every nonliteral
   adaptation, no-op or target exclusion. Missing/changed source invalidates it.
2. Validate exact alias targets, source export provenance, no cycles and no
   cross-target laundering. A reexport inherits covered canonical obligations;
   it is not a second implementation or a second platform test.
3. Decompose mixed handlers. A scoped touch exclusion cannot discharge title
   load, desktop layout or cooking input. Empty-function disposition needs an
   empty-body proof. Aggregate drawAll needs the union of its child coverage,
   including any uncovered direct inline behavior.
4. Evidence has hash, scenario, target, fixture disclosure, inspected outcome,
   provenance and covered-obligation IDs. Verify JSON fields and human-review
   references. A failed run, packaging log, headless test or arbitrary existing
   screenshot cannot satisfy a normal-input or visual acceptance requirement.
5. Distinguish actual rendered synthetic input from trusted hardware/capture/
   audio; distinguish staged rendering from earned transactions. A raw report
   with `visual_acceptance:false` is not overwritten by a geometry PASS: attach
   the separate genuine human review and its exact captured frames.
6. Feature coverage is the explicit union of its required obligations. Narrow
   artifacts may be indexed now without setting `verified`; uncovered branches
   remain visible. Agree finite scenario coverage rather than mechanically
   demanding one new whole tour per helper or every oracle outcome.
7. Keep separate behavior, presentation and target-disposition accounting.
   A future resolved-scope terminal state may discharge only an approved no-op,
   alias or excluded sub-behavior; it cannot satisfy unrelated native/Web rows.
   If introducing such a state, migration tests must prove existing incomplete
   scenarios still fail completion. Until ratification, current `--complete`
   remains unchanged and must fail.
8. Whole-port completion still requires source/model/integration/platform
   coverage, actual sub90s bosses, unchanged<16ms at60+ real active NPCs and
   delivery artifacts. A path-only gate can establish ledger structure, never
   the truth of human visual/audio approval by itself.

Meaningful validator counterexamples: drop one of585 IDs; alias cycle/wrong
symbol; changed nonempty init_frame; classify all init_mobile as touch; bind a
slice screenshot to full-scene gameplay; failed JSON with existing path; native
artifact in a Web slot; fixture equipment pose advertised as earned purchase;
wrong revision/overlay hash; all32 evidence arrays populated by one generic PNG;
unchecked drawAll inline effect; raw synthetic input labeled trusted capture;
passing short profile with fewer than60 active actors; four claims advertised
as all11 or as endless succession. All must stay rejected.

## Actual remaining implementation/disposition work

The inspected current `full_scene.gd` and `full_runtime.gd` contain no production
world-feedback pool/view or source impact-shake consumer. These are isolated
draft integration/art packets under review. Ambient dust/mote presentation is
also still isolated. Their existence and tests under `.build` cannot make the
aggregate renderer complete. Do not confuse these genuine integration gaps
with the21 canonical/alias raster-authoring rows or excluded touch UI.

Source drawPlayer's ghost/chromatic duplicate/aura/iframe sprite treatments also
need their explicit first-person embodiment/disposition recorded at the correct
child obligation, using the existing rig/HUD/district-grade equivalents where
approved. Do not silently use drawAll's aggregate status to claim literal
top-down duplicates, body art or unseen ear/chest equipment.

No additional missing gameplay command is established by this bounded audit.
The evidence index names uncovered behavior, not proof that the existing owner
fails to implement it. Current owners/gates already cover those commands; actual
platform acceptance and a few known presentation integration packets are the
remaining distinction. SourceSpace and globalM have already been corrected and
are not reintroduced as open command gaps. The source minimap is not a full-map
hotkey or fast-travel system.

## Evidence findings and boundaries

`evidence-index.json` covers all32 features; every reference has inspected bytes,
a precise coverage statement and an evidence qualification. The companion
`evidence-features-16-31.json` independently reviewed the second half. No status
or live evidence array was changed. Delivery/commit statements are attributed
to reports; this worker did not run Git to certify tracking/push state.

Strong retained proofs include frozen8bcd Tony (4.211s wall, source-earned pipe,
three coats/adds, shoe, ending and18s/8s), one actual three-route/Office/canal/work/
cot/save tour with disclosed initial$300/6copper fixture, native eight-choice
Karaoke with disclosed$5 fixture, and actual Web16-phase fists/pickup/cart input
at1280/960. Native gear/cast/world galleries are useful visual evidence only.
Actual production browser wake/movement/ledgers/pause/manual save/reload reports
are narrower than whole campaign, audible sound or trusted pointer-lock proof.

Five bounded acceptance priorities remain:

1. Finish and retain the actual minimum-four-claim Kingdom continuation, then
   keep all11 claims and endless succession explicitly separate. Its current
   failed native-v1 and revised cot driver are uncommitted diagnostic work,
   not indexed as accepted delivery. Other local boss variants still need their
   normal-input<90s evidence; Tony alone does not establish all bosses.
2. Use finite normal-input scenarios for currently unobserved economy/supply,
   props, hideouts/bus, heists, cooking, recognition/hitter, companions and
   incidents. Existing owner/oracle gates support them but do not replace live
   rendering, inputs, placement and asynchronous-save evidence.
3. Retain actual Web progression/loop/combat/cooking and later-state durable
   recovery, plus trusted keyboard/mouse capture fallback and audible audio.
   Current synthetic hands/cart tour intentionally does not prove these.
4. Integrate and accept the known feedback/shake/dust packets and remaining
   explicit embodiment decisions; review real populated-combat HUD/layout and
   late journal/minimap at both target sizes. Do not add mobile or a full map.
5. Meet the unchanged full-frame60+NPC target. Sustained frozen8bcd27.484/24.976ms
   and64825.474/22.038ms p95 both fail16ms. Fixed120warmup+1080sample phases with
   real populations remain the meaningful evidence; no reduced census or
   short fixture profile substitutes.

This is one bounded proposal/index. Ratification, any ledger/tool migration,
native/Web execution and delivery remain root-owned. All files are held after
static validation; no production, engine, browser or Git operation was performed.
