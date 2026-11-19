# Draft: actual Web hands and cart input evidence

This isolated QA draft is not a shipped feature or accepted Web result. It changes no production
file. Root must review, copy into an isolated project, parse, export, serve and inspect it before
any acceptance claim. Read VIBE.md and retain the real source world and all original actors.

## Authority and input

Use the real FullScene through the existing Boss probe's observation/walking helpers. No initial
resource, equipment, position, HP, source clock, RNG or progress fixture is necessary. Set only a
dedicated QA save namespace before clicking the real `wake up.` button. Do not read another save.
Require the actual Web feature and `--qa-full` before constructing the scene.

Gameplay uses InputMap movement strengths, viewport key press/release, and viewport mouse events.
Space attacks; E mounts/dismounts the source cart. A right-button-masked mouse motion uses the
production Web drag-look fallback. Unlike native, Web left click attacks immediately; it is never
used as a capture request. The only left clicks target real title/Continue buttons. The driver
never calls Runtime attack/collect/Travel transactions or Rig acknowledge/set_context/tick.

Cash is collected by actual walking across the existing strict14px source boundary. Runtime
auto-collect runs before the next input decision, so sending E after that receipt would be a stale
interaction. Stop on the committed original pile's pickup gesture and capture that current pose.
Retain the original pile, all residents, collisions, source timers, dynamic props and source RNG.
No cleared crowds, teleports, frozen hands, injected action signals or manually advanced clocks.

## Bounded sequence

Sixteen sequential phases, exactly once: idle; right attack; right recovery; left attack; left
recovery; original cash pickup; pickup recovery; parked cart approach; real mount at level pitch;
look-down two-hand grip; real rolling movement; stop; mounted attack; regrip; level-look release;
real dismount. Read actual receipts, cooldowns, rig action age/side, grip marker positions, cart
collider layer, presentation clearance, wheel rotation, source position and current resolver.

Attack captures must contain an actual active punch and the expected alternating side. Record
actual age rather than describing a missed peak as impact. Collect a bounded per-frame wrist
trajectory and perform visible mesh vertex/near-plane checks only at capture boundaries. Recovery
must occur by ordinary advancing frames and must not emit another attack or collection. Mounted
right attack releases only that hand; the other remains on the real handle. Both regrip after
recovery. Default forward pitch must release offscreen handle targets into visible relaxed hands.
Rolling uses actual movement input and changes the wheel angle; stopping leaves it unchanged.
Use only certified forward/back corridors: the source cart's wheels use longitudinal velocity.
For dismount, preserve earlier interaction priorities and use real upward drag-look before
checking resolver=cart. Restore level look after the transaction. Compare geometry against the
actual recorded camera.near plane, not a looser hand-specific proxy.

After each phase, await a real post-draw framebuffer, copy its PNG, then send ordinary Escape.
Review uses that explicitly labeled immutable Web frame while the real scene is normally paused.
Next clicks the actual Continue button before its next phase. Browser still-image selection never
replays transactions. It is not a live frozen pose and never counts as pointer-lock evidence.

Budgets:180s cold startup;90s per walking phase and5s per ordinary phase;20min total including
review;32 bridge requests;8192 pose samples;512 observed relevant events;16 PNGs,96MiB bridge
payload. Existing walking helper retains80 graph vertices,32 replans and20s waypoint timeout.
Death/arrest/epoch replacement, unsupported event, missing frame, stale callback or exhaustion
ends with a failed report. Abort releases inputs and uses ordinary pause when possible.

## Browser bridge and evidence limits

Only `next(exact_next_index)` and `abort` are exposed. Report JSON and PNG downloads are bounded;
no arbitrary state getter/setter, direct source callback or arbitrary code evaluator is exposed.
The template shell boots this script through a separate QA export, not a production URL flag.
Actual framebuffer sizes are1280x720 or960x540 selected before boot; CSS size is not evidence.
Keep real scene/hand settings and original meshes. Record engine, renderer, WebGL2, source hashes,
actual size, user agent, pointer-lock status, trusted browser event counts and captured phase.

Synthetic viewport input validates real production routing/rendering, not OS-origin trusted
events, browser pointer-lock acquisition, audio unlock, performance60 or the nine weapon/tool
catalog. Those retain their own native gates and need separately recorded manual Web actions.
Screenshots require human review for relaxed hands, fingers, arm/handle coherence, obstruction and
recovery. A machine pass is deliberately named `input_frame_checks_pass`; visual acceptance stays
false until the external review. Current draft has no engine or browser execution evidence.

## Isolated packaging proposal

Copy game3d into a dedicated QA project without altering source production. Copy this draft's
tests/web_hands_probe.gd and tests/test_web_hands_contract.gd there; retain the tracked Boss probe.
Use web-hands-shell.html as that copy's custom HTML shell. Copy web-hands-bridge.js next to the
exported HTML. Include tests/** and the production data files already required by current exports.
Preserve IndexedDB/window.storage script packaging; do not add localStorage/sessionStorage.
Do not run or export against the live production project for this draft.

Root validation correction: the custom shell must load the unchanged production
storage.js before boot, with its file copied alongside the HTML. Merely including
it in the PCK does not install window.rb3dSave. Retain the initial failed report.
Pickup capture must await actual pose advancement after its committed gesture:
wait until age>=.06s and require a rendered age in[.04,.32), never certify the
age-zero acknowledgement frame as the visible reach. No gameplay clocks are set.

## 960px projection correction

The first actual960x540 idle capture showed both hands, but its validator reported
zero visible vertices. The project uses `canvas_items` stretch with a1280x720
logical viewport; changing the Window size changes the framebuffer, not the
coordinate space returned by `Camera3D.unproject_position`. Test projection
membership against that camera's actual `get_viewport().get_visible_rect()` and
record this logical rectangle separately from the post-draw PNG dimensions.
Do not change production stretch, hand poses, near-plane bounds, or require fewer
visible vertices. Counterexamples must retain lower/right logical coordinates
that scale into a960x540 image, reject truly outside/behind/nonfinite positions,
and support a nonzero viewport origin without a hardcoded1280x720 assumption.
