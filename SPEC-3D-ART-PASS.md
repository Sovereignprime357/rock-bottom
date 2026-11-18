# SPEC — 3D neighborhood art and rendering pass

Captured 2026-11-18 before implementation. Operator requested continued improvements to graphics,
textures, assets, characters, buildings, streets and NPCs while away from the PC.

The operator's subsequent closer-to-Schedule-I refinement is specified separately in
`SPEC-3D-CHARACTER-STREET.md`; the original material/batching guarantees below remain binding.

## Intent and boundary

Improve the existing first-person neighborhood as a coherent low-poly place: distinguish road,
sidewalk, masonry, plaster, wood, worn metal, cloth and skin; strengthen character silhouettes and
faces; give storefronts and streets authored details and signs; make residents visibly occupied.
Keep the dirty VIBE palette, flat voice, existing identities and the 18s/8s loop. No new economy,
quests, combat rules, tutorial, generic crowd identities, campaign or save schema in this pass.
The active 2D release, frozen v19 and original gates remain unchanged.

## Materials and geometry

Use original deterministic procedural texture tiles, cached once, as repo-native source. They
must read as restrained wear at player height, not photographic noise or shiny plastic. No
external art packs/CDNs. Use small repeatable textures and mipmaps suitable for Compatibility
and WebGL2. World materials use consistent scale; character textures must not swim in world space.
Light comes from visible fixtures. Keep night, storefront faces and signs readable. New standing
objects that block a route require matching collision; tiny debris and surface wear are decoration.
Keep original interaction anchors/reach and route clearances, including Pete's service opening.

## Rendering and animation

Batch static geometry by compatible material and bounded spatial region after construction.
Preserve collision, labels, light nodes, target references and independent animation pivots.
Never merge moving characters into the world or repeatedly generate meshes/textures per frame.
Use cached materials across mesh parts. Bound any added NPC motion to the established cast;
the possum has a route, Tony does not blink, Pete occupies his counter, and Brutus is old.
Idle/gesture changes pause with gameplay and cannot change interaction bodies or combat reach.
First-person hands should have readable fingers, sleeves and a short punch, without hiding the view.
HUD backing should leave the street visible between compact corner panels, while retaining text
contrast. Compatible kit material tints may be baked into vertex colors with correct color-space
handling; the neutral shader multiplier is not a new visible palette color. Material flags,
emission, texture mapping and animated pivots must survive batching.

## Verification and handoff

- Existing 19-gate suite plus production simulation and scene gates remain green.
- Check material cache reuse, generated texture repeatability, and static batch geometry/transform
  preservation; verify collision and interactions after batching and dressing.
- Inspect native eye-level captures at the Block, Tony, Pete, Yuri and alley in day and night.
- Profile the same camera before/after; record draw calls, geometry counts, hardware and render
  resolution. Use a sustained rendered measurement with a monotonic clock; do not convert a
  hidden/minimized-window anomaly into an FPS claim. The 60-NPC target needs separate stress proof.
- Rebuild Windows and Web exports, boot the packaged desktop build, retain local browser serving.
  Report browser UI verification separately from export/HTTP checks.
  A hidden localhost-only helper may outlive the interactive command session; it must not install
  a service/startup task, expose a public listener or stop an unrelated server on an occupied port.
- Update BRAIN, backlog, decision register and a report with files touched and green gate output;
  commit and push a named branch. Art remains subject to operator eye/play review.
