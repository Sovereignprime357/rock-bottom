# SPEC — source world feedback in first person

2026-11-19. This contract follows the isolated, spec-first pool, source-hook and
integration drafts reviewed after checkpoint `648dc78`. Implementation, focused
native/Web checks and full regression now pass. This does not declare complete
parity or performance.
Original `src/`, its sprite pipeline and its behavior remain unchanged.

## Authority and source scope

One Runtime-owned cosmetic pool handles the source impact, debris, prop, reveal,
aim, radio, taser and phase bursts. Gameplay owners emit detached metadata only at
their accepted source transitions. They keep their existing state writes, RNG,
costs, cooldowns, collision checks, event ordering and rewards. No input handler,
audio inference or polling of actor poses invents a burst. Existing player hand
tremor (`p.shakes`) and source world shake (`s.shake`) remain distinct.

Source sites are `src/systems/combat.js`, `src/core/update.js`,
`src/systems/interactions.js`, `src/systems/npc_ai.js` and the particle compositor in
`src/render/frame.js`. An oracle executes unchanged source emission statements;
recipe-level fixtures do not by themselves prove production trigger wiring.

| Recipe | Particles per accepted receipt |
| --- | ---: |
| essential | 1 |
| melee_sparks / melee_rust / melee_flash | 8 / 3 / 1, in that order |
| bottle_break / bottle_impact / holy_impact | 12 / 10 / 12 |
| tony_coat / older_phase | 24 / 20 |
| dumpster_rats / trash_cash / trash_rats | 10 / 6 / 8 |
| possum_reveal / ally_hit | 6 / 4 |
| ranged_aim / fallen_aim / radio / taser | 1 / 4 / 1 / 10 |

Retain source velocity, size, lifetime, gravity, literal color/alpha, glow, weapon
tint and phase distinctions. The independent cosmetic RNG never consumes gameplay
draws. Walking dust and ambient motes follow the additional contract below. Existing
depth-tested 3D rain supplies the rain adaptation; do not add duplicate rain.

## Ordered receipts and lifecycle

Use an ordered `payload.feedback` array on existing events, with standalone
`world_feedback` receipts only where no source semantic event exists. Each entry
captures recipe, source point, required source rectangle and anchor kind, and only
the needed width, phase or singing-weapon value. Actor body/head receipts capture
a detached `{id,name,sprite,isOmalleyFallen}` descriptor before the relevant source
mutation. Melee origin is before knockback; taser origin is after `_hit`, including
its possible death/arrest relocation. Never recover a birth origin by live actor ID.

At the existing Director → particles → projectiles boundary, scan feedback metadata
without draining the source queue or running domain consequences early. An internal
per-event cursor survives existing queue copies/compaction. Normal event resolution
uses the same consumer and cannot replay a consumed receipt. Admit earlier births,
advance the pool by the accepted world step, then admit projectile/phase births at
their normal resolution seam. Late births retain full life until the next pass.
Immediate commands retain their existing resolution seams.

Fresh/accepted restore bind a new presentation generation. Death and arrest reset
the pool at their exact ordered event position, before any later taser receipt.
Scene clears only passive buffers and does not reset the pool a second time.
Unexpected player/state identity replacement clears and invalidates cosmetics
until explicit rebind; stale queued work cannot adopt the replacement epoch.
Pool, context, cursors and particles are absent from save data.

Companion reveal keeps the exact raw host/player/state/pending/pile identities and
requested point across the spatial capability call. A changed epoch, newer request
or in-place pending mutation rejects the old return without clearing newer work.
Recheck exact pile membership and collection before commit. This is an interface
counterexample guard; the current concrete adapter is synchronous and read-only.
Normal and blocked retries retain source RNG, one reveal and existing receipts.

## Pool and original geometry

Hard capacity is 220 particles, evicting oldest first on insertion. Expose requested,
emitted, evicted, expired, live, peak and cosmetic-draw counts. This deliberately
tightens the source's temporary late-pass overflow beyond its pre-pass trim; no
gameplay event is dropped. No particle has a Node, physics body, light or timer.

Require a current positive epoch, known recipe and finite bounded spatial data
before any RNG/counter/pool mutation. Invalid/stale receipts are refused atomically.
Source coordinates are bounded to absolute 1e7 and world coordinates to 1e6 for
arithmetic safety. Width is 0..100000, coat phase is 2 or 3, singing is Boolean.
Snapshots detach rows. Accepted dt is finite 0 < dt <= 240000ms; source 60Hz drag
`.92` uses its analytic recurrence for fractional time, with real millisecond life.
No paused, loading or hitpause-only frame advances this owner.

Four MultiMesh banks share two original immutable meshes and two materials. At
most 220 visible instances / 880 triangles use five nodes total. The view validates
an entire snapshot before upload, fails closed on malformed data, and owns no RNG
or clock. Materials are depth-tested, unlit, alpha/additive as appropriate, with no
depth writes, shadows, textures or lights. Instance transforms/colors stay private.
Every actual transformed vertex must fit the bank's custom bounds.

Headless Godot's dummy renderer does not retain uploaded MultiMesh transforms or
colors. A sentinel records actual readback capability. Headless checks retain pool,
mesh/resource, finite/unit-normal and mathematical enclosure evidence; they cannot
claim uploaded geometry. The mandatory real-renderer mode refuses a dummy renderer
and checks actual instance transforms, colors and vertex containment. All failed
assertions count, while repeated error printing is bounded.

## Birth geometry

Scene supplies finite horizontal camera right before commands and advancement.
A pure prewarmed table maps detached visual descriptors to authored heights, with
a finite 1.8m fallback. It does not allocate meshes, retain scene nodes or consult
the live roster. Body height is 55% and head height 90%; player torso is 1.0m.
Source offsets map along captured right and vertical UP at .04m/pixel. Ground
anchors are .08m; projectile impacts use the existing 1.0m presentation plane.
Later camera turns, actor deaths or reused IDs cannot move a birth anchor.

## Shake and the existing screen pass

Keep `s.shake` as the sole amplitude, including existing set-versus-max behavior.
At each completed active world tail, after rank/unlock and before utility autosave,
apply `.9^(step_ms/(1000/60))`. Preserve a current step that opens dialogue; do not
insert an extra mode gate halfway through the source step. Hitpause/skipped steps
do not decay. No alternate shake timer or save field is introduced.

Use only the existing district-grade shader's world sample offset, bounded to
±2 physical pixels per axis at 720px framebuffer height and scaled by actual height.
An independent deterministic 60Hz hash supplies direction; sampling does not advance
particle or gameplay RNG. Suppress offset outside playing, during loading or focus
loss. Zero strength gives exact zero. Camera transform/FOV, aim, controller, physics
and HUD are unchanged. The original SCREEN_UV is literal at zero; only nonzero
offsets clamp at image edges. Keep one screen read and the original grade equations.

Use concrete `Window.size` or `SubViewport.size` for framebuffer dimensions.
Unsupported viewport types produce zero offset. Do not use logical Canvas size or
ViewportTexture size, and never read an image in the gameplay frame loop. Native
measurement showed a 960×540 readback alongside an erroneous 720×405 texture-size
value under Canvas scaling; both candidate mistakes are retained as failed evidence.
Clearing or changing grade profiles resets/reapplies the correct private uniform.

## Acceptance boundaries

Retain unchanged-source recipe fixtures and paired baseline/candidate gameplay
witnesses, excluding only approved cosmetic metadata/receipts and shake decay.
Check all 18 triggers, pre-/post-particle timing, immediate commands, iframe/fatal
taser order, stale epochs, repeated drains, detached descriptors and new/dead IDs.
Preserve Runtime/Scene/Combat/Boss/Companion/prop regressions.

Native and actual Web raster checks must observe both 1280×720 and 960×540 images,
exact 3:4 sampled offset scaling, fixed HUD, nearest-sample displacement and zero
offset identity. Native and Web gameplay-context images must separately show the
actual bursts, occlusion, near-camera readability, recovery and steady aim. Staged
visual fixtures are labeled and cannot count as earned campaign progression.
Measure full-scene 60-actor performance with the unchanged 16ms requirement. Neither
color patches nor green model tests establish the completed game.

## Walking dust and ambient motes

This approved extension composes the separately specified and tested dust overlay
with the eighteen bursts. There remains one 220-particle pool, four banks and two
meshes/materials. Existing burst recipes, clocks, random draws and fixtures remain
unchanged. A pure `world_dust.gd` scheduler owns two private clocks and its own
independent cosmetic random stream; it has no gameplay or persistence authority.

After resolved player movement and before state advancement, nonzero source intent
accumulates time. Strictly more than110ms emits once and resets to zero, discarding
excess; idle/stun preserves the clock. Blocked movement still has intent. Five
source-ordered draws retain foot jitter, drift and380–580ms life; size2 and literal
color(180,160,120,.55) remain. Source foot coordinates pass through canonical
`Content.to_world` at height.08m, including the existing source-origin subtraction.

After ambient audio and before quests/actors, subtract the accepted step from the
ambient clock; at zero or below emit once and reset to280+r×350ms. Seven ordered
draws retain interval, position, drift,4500–6000ms life and size1/2. This runs in all
weather/day conditions. Only rain changes its literal color, from
(232,210,160,.32) to(180,200,220,.6). Existing rain remains the sole rain owner.

Ambient screen coordinates adapt to the actual perspective camera's birth frustum
at deterministic ordinal-derived depths2–8m, without another random draw. The
world anchor and horizontal birth-right remain fixed after emission. Later camera
motion cannot drag a particle. Walls/ground depth-test naturally; no placement
query, light, extra particle density or head-locked overlay is introduced.

Both births precede the same source particle advancement. A current active step
that opens dialogue still completes its original seams; skipped, paused, cooking,
loading or hitpause-only time does not advance them. Reset private cosmetic clocks
at the existing single feedback generation boundary. This deliberately differs
from the source's incidental unsaved same-session clock carry and does not alter
save fields. Metadata-only draining preserves ordered death/arrest/taser receipts;
never add an early full-domain resolver.

Only named walking/mote recipes accept detached arrays of exactly five/seven
finite samples in[0,1). Validate before mutation. Only their lifetimes may reach
580/6000ms respectively; the old recipes retain their1400ms validation ceiling.
The oracle's exact integer RNG numerators establish every generated draw without
a floating-point parsing tolerance. Native/Web walking, blocked intent, day/night,
rain, camera-turn, wall-occlusion and expiry views remain mandatory before approval.

## Original impact silhouettes and renderer evidence

The flash is a four-triangle diamond fan: opaque center, zero-alpha rim, with
existing vertex-color and instance-color multiplication. The source color, size
and life-alpha stay unchanged. Fragments use a flattened asymmetric tetrahedron
and one of four birth-static rolls selected by recipe hash and serial. No random
draw, time-based rotation, shader, texture, light or extra surface is introduced.
Both meshes have four triangles, preserving the worst-case880-triangle budget.

Cache each mesh's actual maximum vertex radius. Instance bounds use that radius
times source size plus a documented float32 rounding margin; no physical geometry
changes. Native tests must inspect submitted transforms and every actual vertex.
Compatibility4.5.1 stores MultiMesh colors using its truncating half-float format:
require exact independently predicted stored values, while retaining source-color
deltas diagnostically. Do not replace this with an arbitrary broad tolerance.

Visual probes suspend callbacks only. Disabling an entire scene tree removes its
CollisionObject3D bodies under the default disable mode, invalidating placement
and occlusion claims. Require a real existing-wall overlap and crossing-ray witness
before every fixture. Earlier disabled-tree images remain art references only.
No fake occluder or actor relocation can satisfy the real-wall requirement.

The same visual harness must advance actor poses exactly once per actual admitted
Runtime interval, using `last_advanced_ms / 1000` in normal Scene order. A zero-time
paint never advances poses. Birth captures explicitly precede the next pose step;
active/recovery captures require target-specific Director and rig state, including
actual visible coat layers for Tony. Never add an epsilon tick to make a frozen
pose appear current. Earlier images with frozen poses retain their physical and
effect receipts but do not establish current actor-action or coat presentation.

HUD shake evidence uses actual opaque foreground: the current glyph mask plus
pixels inside the existing opaque meter fill, derived from its Control rectangle
and fill color. Require at least twelve exact unchanged pixels collectively and
report glyph and fill counts separately. Translucent panel backgrounds cannot
satisfy this check. Small anti-aliased text at960 may contribute fewer than twelve
fully opaque glyph pixels; preserve that diagnostic without lowering the combined
minimum or the exact pixel-identity requirement. Camera/FOV and HUD transforms
remain independently checked throughout the frozen image pair.
