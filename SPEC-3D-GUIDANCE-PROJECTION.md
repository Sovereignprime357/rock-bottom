# SPEC — P08c first-person objective projection

Captured before code, 2026-11-18. Subordinate to SPEC-3D-GUIDANCE.md. Root approved
the projection and optional physical visibility seam after the165view/58direction
guidance model passed1125checks. Existing production files stay held during the
central checkpoint runner; new helper/tests may be authored independently.

## Pure geometry and source grammar

`RockBottomGuidanceProjection.project(target, camera_transform, projection,
viewport_size, safe_rect, visual_ms, visibility=-1)` returns detached marker
geometry, or an empty dictionary for nonfinite/degenerate input. It receives no
model, owner, actor, event queue, input, RNG, or save handle. World/source mapping
remains Content.to_world; source target x/y is unchanged. Anchor height0.08m puts
the marker just above the ground. It is an informational waypoint, never an E
affordance, physical placement approval or teleport destination.

Source authority: src/render/actors_weather.js399–410. Preserve visual grammar:
`pulse=(sin(visual_ms/180)+1)/2`, radius11+3*pulse, alpha.62+.3*pulse,2px stroke,
4px gold square above the ring, and the four arrow vertices(10,0),(-7,-6),(-4,0),
(-7,6). Source pixel style scales through the existing viewport UI only; it is
not a world-sized billboard or collidable object. Unchanged-source draw fixtures
record these primitive calls and pulse values independently.

The helper projects a world point through the current camera transform/projection.
Front targets inside the safe rectangle and clip depth receive a circle. A front
target outside it receives the same arrow, clamped to the rectangle and aimed from
viewport center toward the projection. The safe rectangle excludes the top HUD
and bottom meters/map. This replaces source24/36/30px screen margins with the
actual first-person HUD's occupied edges. A target behind the camera cannot use
mirrored perspective coordinates: its arrow uses camera-local x and positive
backward z, with straight-behind at the bottom. A point before the near plane is
treated as directional guidance, never a huge circle. Degenerate camera origin
coincidence returns no marker. No distance/target substitution or route computation.
An exactly centered front point clipped by near/far depth uses the top edge;
straight-behind uses the bottom, so the two directions remain distinguishable.

## HUD binding and visibility

`hud.bind_guidance_camera(camera)` holds the Camera3D weakly. The HUD retains the
last primary objective obtained by the existing120ms guidance refresh. Each frame
may project that detached snapshot and draw it; it never asks a gameplay owner
for another target. Visual time is monotonic presentation time, not a gameplay
timer. Non-playing modes hide the overlay and perform no projection.

`hud.bind_guidance_visibility(callback)` is optional. Root supplies a real layer1
ray through the active physics world with signature `(target_world:Vector3)->bool`.
The HUD calls it at most once per existing120ms refresh, not once per frame.
Its sole result is presentation visibility: true=clear, false=occluded; absent,
invalid or nonboolean=unknown. It cannot grant interaction or change an action's
reach/LOS. Root owns the physical callback and lifecycle.

A clear on-screen target keeps the source full ring and square. An occluded target
keeps its true projected point, uses a muted dashed ring and omits the square.
Unknown visibility uses a hollow ring with no square and makes no LOS claim.
Offscreen/behind arrows retain direction and adopt muted alpha when occluded.
This is a documented3D adaptation; the2D source did not have depth occlusion.

## Verification and completion boundary

New pure tests compare source pulse/primitive samples, projection against a real
Camera3D's unprojection, safe bounds, behind/near/edge cases, yaw/aspect/FOV,
nonfinite/degenerate matrices, occluded/unknown styles and detached results. HUD
tests must prove the120ms owner-query/visibility budget, current heading, weak
camera lifetime and mode hiding after the production-file hold releases.

No engine or browser runs are delegated to this packet. Root runs central gates,
binds the physical callback, checks native/Web readability and performance, and
records the projection/occlusion adaptation. A pure geometry pass is not a claim
that the on-screen guide was inspected or that physical paths are valid.
