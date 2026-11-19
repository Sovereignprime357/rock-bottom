# Resident wake and folded laundry refinement

2026-11-19. Scoped successor for `game3d/` only. The original pixel release and
sprite contract are unchanged. This contract promotes the previously specified
isolated Dave/laundry candidates after their focused central validation.

Dave's authoritative `asleep` flag selects his sleep pose. His static identity
profile has no forced sleep action. Ordinary E input can wake him, remove his
sleep markers, leave him upright through idle and open the existing seventeen-part
pigeon conversation. Wake changes no player resources, HP, RNG or actor origin.
Explicit animation fixtures and existing action precedence remain available.
No new timer, dialogue, state writer or controller is added.

Laundromat Lady's basket contains a shallow folded shirt with sleeve/collar/hem
forms. Its cached mesh uses 56 triangles, one surface and the existing `8c8164`
fabric material, within the former contents bounds. Basket geometry, attachment
transforms, bilateral rim contacts, release/death behavior and all other identities
are unchanged. This adds no physics, lights, random draws or per-frame work.

The production change is limited to `cast_profiles.gd`; regression coverage extends
the existing FullScene and roster suites. The small Dave walkthrough and its pure
contract use a fresh normal spawn, ordinary movement/E/buttons, no grants or
teleports, a 120-second total bound and three original captures. The browser run
uses the same source behavior at 960x540; native uses 1280x720. Both must show the
sleeping pose, upright wake after four active seconds, reopened source dialogue,
Leave and resumed movement. The original profile must fail the wake regression.

Cloth checks inspect actual authored and batched geometry, finite/nondegenerate
faces, normals, bounds, material and shared caching. Native and browser review
cover close rest, walk, gesture, bilateral contact, strike, collapse and distance.
The Web roster capture's keepalive mode accepts capture receipts only; it does
not claim engine shutdown, gameplay progression or performance acceptance.

Source pins advance through an explicit immutable `metadata-v2` revision for
exactly the three changed existing profile/test files. Prior pins and historical
evidence remain raw. All 617 parity statuses and original platform lists remain
unchanged; this is not full-port acceptance. Indexing, court eaves and a separate
sleep-ground pose investigation are outside this promotion.

Evidence is retained under `artifacts/3d-full-port/resident-refinement/`, including
the original isolated specs, counterexample logs, composed source hashes, native
and Web originals and the focused visual review. Broad release gates and exports
are required after integration. Existing sustained 60-actor performance failures
remain open and must not be replaced by these visual results.
