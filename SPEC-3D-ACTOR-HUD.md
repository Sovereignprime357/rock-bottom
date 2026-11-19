# SPEC — Actor and combat HUD P15b

Captured before code, 2026-11-18. Root approved a pure source view, projection,
isolated Control renderer,64 current sightline checks and8 layout attempts.
Root alone binds FullScene/FullHUD. No AI, target selection, damage, clock, input,
save, actor geometry/material or lighting ownership is added.

## Exact source facts

Authority: render/actors_weather.js159–313, nameplate helper25–35, frame.js168–189
and266–340. `RockBottomActorHudView(state)` has a weak host. `snapshot(visual_ms)`
returns detached actor/combat facts read directly from p/s/npcs. Never call
Director.snapshot (its epoch sync is mutable), normalize gameplay, or write source
actor `_label*` caches. A private128-entry name cache preserves source wrapping
without unbounded numbered-pretender names. Snapshot carries captured p/s identity
only for the renderer's stale-callback check; no returned owner reference is public.

Name predicate: vendor OR hostile OR aggro OR player-center distance²<260².
Vendors/combat names have no extra world-distance cutoff. Split on literal spaces,
greedily wrap once when joined length>17; retain the entire second line. Red
#d04040 for hostile/aggro, else dirty cream#d4c896; dark backing rgba(10,8,5,.76).
Damage bar only showHp&&hp<maxHp, source raw hp/maxHp and strict>.6 / >.3 colors
#a8c030/#e8c040/#d04040. No full-health bar or new attack cooldown countdown.

Preserve independently composable asleep z; aggro!; windup yellow! and red pulse;
cooldown pale panting pulse; aimingThrow yellow*; radioVisualT>0 blue*;
grabFreezeT>0 purple-<; unmet vendor/day floater and source22px bus-driver versus
16px default; chatterT>0 and nonempty chatter. Vendor floater uses exact catalog
IDs or hasFloater, absent metVendors, neither hostile nor aggro. Do not silently
alias source train_hopper versus actor hopper or equate vendor with floater.
Dead/departed actors omitted. Night excludes mom/pete/daytimeOnly with exact
dayTime<.25 or>.75. Every pulse derives supplied visual wall time, not new timers.

Combat facts preserve frame order flash→existing high/crash treatment→stun→slow→
lowHP wash→boss→combo→lowHP vignette→shakes. Existing FullHUD high/crash loop
tints remain its current scoped3D treatment; the new overlay must not double them.
Stun>0 always says GRABBED, regardless of source; slow>0 keeps pale-blue veil;
lowHP is absolute hp<=30 including accepted raw negative HP, not percentage;
shakes>=90. Preserve source colors/pulses, including grandfathered #fff080 and
slow pale-blue. Rendering clamps only output alpha/rectangle extents for valid
Godot drawing; returned semantic raw HP/ratios remain unchanged.

Global boss only bossActive && bossNPC && !bossNPC.dead. No hp>0 or roster-membership
guard. Kingdom uses boss.name; every other kind uses literal TRE BAG TONY. Text
max(0,ceil(hp))/maxHp, raw ratio for facts. Do not invent global bars for Older
Brutus, Old School Brutus or Fallen outside the source global boss contract.
Combo>=2: literal Nx/combo, source font16+combo*2, alpha min(1,comboT/1000).
Only title suppresses global combat facts; menu pauses do not freeze pulse time.

## 3D projection and renderer

`RockBottomActorHudProjection` projects finite real world anchors through the
actual Camera3D, rejecting behind/near/far/offscreen points. Pure layout accepts
screen bounds and occupied HUD rectangles. Four source-style upward attempts are
followed by four left/right head-side attempts, eight total. Side placements use
a thin leader to the projected head. This first-person adaptation addresses the
actual Tony windup/chatter capture where the objective panel occupied every
upward slot; neither camera nor existing HUD is moved to force a pass. No NPC
offscreen arrows, teleport, highlight target or action permission.

`RockBottomActorHudOverlay`, one Control surface, binds weak state/camera plus
Root callbacks `anchor_for_actor(id)->Vector3` (actual rig head/height point) and
`actor_visible_to_camera(id,anchor)->bool` (current layer1 ray). API
`bind_model(state,camera,anchor_callback,visibility_callback)->bool`,
`update_frame(visual_ms,occupied_rects:Array[Rect2])->bool`, `clear()`, `inspect()`.
Root owns the same frame's timestamp and actual HUD rectangles. Missing/invalid
callbacks or epoch replacement clears actor drawings. Global combat facts need
no actor LOS, matching source. Callbacks never grant gameplay authority.

After projection, up to64 current LOS checks/frame: telegraphs, hostile/aggro,
chatter, then distance/source order. Excess/unknown/blocked rows fail closed and
are counted. No stale LOS cache can show a label through a newly placed wall.
Every normal source predicate is retained before this explicit overflow adaptation.
Names use shared cached regular/bold monospace fonts, approximately1.5× source
pixel sizing for first-person readability. No per-NPC Control nodes or new lights.
Courier New is requested through SystemFont with Liberation Mono/monospace and
the engine fallback if unavailable on Web; exact source wrapping is independent
of installed glyph metrics. A single cached radial gradient supplies the low-HP
vignette, proportionally fitted to the first-person viewport (not Canvas pixels).

Source flat rectangular windup/cooldown tints become small head/shoulder cue
plates using the same pulse/color, plus their exact glyphs. This is an explicit
3D adaptation; existing shared meshes/materials stay immutable. Names/chatter/
health/glyphs compose a bounded cluster. Its bounds are the union of actual cached
font ascent/descent/width, backing rectangles, HP frame, chatter tail and floater
shadow; no guessed fixed cue height may under-report the drawn geometry.
Layout respects viewport and Root's
health/objective/feed/minimap/prompt/menu rectangles; if8 upward placements fail,
the cluster is omitted and counted. Long chatter retains exact text, clipped only
to viewport/cluster drawing extent; names retain source two-line wrapping.
World actor labels hide during modal screens/title to keep menus readable; global
combat status remains beneath modal controls. No new fourth-wall instructional copy.

## Evidence

Unchanged-source oracle captures drawNpc commands/name wrap at exact distance,
hp color boundaries, independent marker/floater/chatter predicates, identity/night
cases and frame boss/combo/status expressions. Original draw mutations are recorded
separately from the approved pure view. Source strings/colors/timing remain pinned;
projection/occlusion/caps/cue plate adaptations are tested as3D properties.

Tests require pure repeated snapshots with unchanged p/s/npcs/RNG; no Director
sync; finite actual Camera3D projection, behind/frustum rejection, real occluder
callback integration, stale epoch callbacks,64-ray/8-attempt counters, name cache
bound, safe viewport/HUD layout, no new render resources per frame. Root will run
native-readable captures and measure the full60-actor frame cost after binding;
model tests alone do not satisfy rendering/performance acceptance.
