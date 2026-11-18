# SPEC — Source-space to native3D physical adapter

Captured before implementation,2026-11-18, root. `world_adapter.gd` joins GameState to the
generated FullNeighborhood using actual PhysicsServer space queries. No resource/HP/timer
ownership. It implements the exact P07a physics seam and economy's live `can_reach_target(id)`.

`new(world_node,game_state)` keeps weak references. Source positions remain top-left pixels;
physics maps body centers through Content's .04 scale. `register_body(id,node,height)` supplies
optional actual actor eye/target heights; queries work without art. Height is separate from
source horizontal footprint. Player uses .48m capsule/1.8m height; NPCs use their exact source
rectangle as an axis-aligned box1.8m tall unless registered otherwise. Actors do not block one
another in the model, matching original structure-only motion. Floor/ceiling are real3D solids.

- `move_body(body,intended,goal=null,stop_on_block=false)` sweeps the complete horizontal body
  shape against world layer1, returns source top-left and blocked. At most two slide iterations,
  no tunneling/teleport or resource mutation. Charging stops on first hit. A goal does not permit
  a path through a wall; global certified route search is not called per movement tick.
- `clear_placement(body)` tests actual overlap, then bounded concentric candidate placements
  around the requested location, returns finite top-left or null. It never silently relocates
  a cop into the Block; player recovery uses the explicit world-spawn policy separately.
- `can_hit(from,to,source_id,target_id)` uses current body heights and actual static raycast;
  never caches a visibility answer across geometry changes. Actor bodies are excluded from
  static obstruction; Combat independently chooses the overlapping target corridor.
- `sweep_projectile(start,end,radius)` sphere-sweeps at the common combat plane1.0m against
  world layer1; returns earliest fraction/point, clamps no through-wall endpoint. Registered
  source-specific projectile heights are a later adapter extension if needed by named attacks.
- `can_reach_target` obtains current moving actor/pile coordinates or declared world service
  target/reach, checks strict horizontal distance and actual eye-level ray. Only a service's
  declared visible contact owner may terminate that ray; unrelated walls always refuse.
  Invalid IDs/missing/dead targets and nonfinite input fail closed. Cash retains14px radius.
  Source zone menus become authored3D service points, an explicit reticle/reach adaptation.

Acceptance uses real generated geometry plus small controlled walls: high-speed motion cannot
tunnel; slide/charge differ; invalid vectors do not move; live wall addition/removal affects LOS;
projectiles stop before first wall; all base actor placements are audited for real clearance;
vendor and pickup interactions run through Runtime with physical approach points. Performance
measures actual queries; certified global navigation runs only when explicitly requested.
# Composed-world acceptance

The generated full neighborhood must pass the adapter's real query from each authored service
approach, including low cash pickups and actual actor heights. A capsule route into Tony's reach,
the canonical intro purchase and physical Block smoke must run through Runtime. Geometry-only
route proofs do not replace this consumer test. Clamp source bounds before all body casts,
including AI movement; never move a committed body through a wall by post-cast correction.
