# SPEC — Character and street art refinement

Captured 2026-11-18 before generation, on `codex/3d-character-street-polish`, after the
operator requested graphics/textures closer to Schedule I, especially characters/buildings/
streets/NPCs. Extends `SPEC-3D-ART-PASS.md`; all slice gameplay/save/input contracts remain.

## Visual target and scope

Use the reference's readable caricatured humans, simple matte surfaces, layered low-rise
storefronts and coherent streets as direction. Build original art for Rock Bottom's identities
and dirty palette. No reference meshes/textures, stock packs, external runtime dependencies,
photographic surfaces or new NPC identities. The first-person desktop/Web slice stays bounded;
the v22 source, sprite contract and frozen v19 remain untouched.

## Character forms

Replace the assembled primitive appearance with coherent authored head/body/limb cross-sections.
Broad face/skull/cloth shapes may use selective smooth normals; collars, lapels, cuffs and jaw
breaks remain legible. Fit brows, shallow eyes/lids, one connected nose, mouth crease, ears and
hairline to the head; avoid bead-like cheek/beard/nose assemblies. Keep exaggerated proportions
around four to five heads tall, with different shoulder/chest/waist shapes and shaped knees/shoes.
Tony has three clear coat layers and a fixed stare; Pete is wider, short-necked and eats; Yuri
has a broad jaw and fitted beard; Lurch is long, slouched and uneven. Improve fist silhouettes,
cuffs, old Brutus's muzzle/chest and the helmeted possum's snout. Preserve existing rig names,
API, actor roots, collision/reach, and pause-respecting bounded gestures. No mesh regeneration
per frame or blanket smooth shading that erases all planes. Tony never blinks.
Eye-review refinement: retain the larger caricature heads for recognition at interaction range;
the target is readable shaped anatomy rather than a strict five-head proportion for every resident.

## Streets and architecture

Give the existing shops deep window/door reveals, distinct facade bays, trim, transoms, layered
awnings and appropriately scaled mounted signs. Vary parapets and roof fixtures; treat side
walls and backdrop facades. Keep Pete's service aperture and every target/ray approach clear.
Add coherent gutters, inlets, manholes, a properly oriented zebra crossing, worn lane/loading
marks and restrained grouped repairs; replace scattered raised-looking rectangles with wear
that reads as part of a surface. Group small props around occupied curb/building edges and
close the empty horizon with distant built silhouettes. New standing route blockers require
matching collision/clearance footprints. Decoration cannot masquerade as a traversable door.
No new street/territory, transaction, sign tutorial or crowd identities.

## Materials and lighting

Refine original cached 128px mipmapped tiles: smaller masonry courses, coherent low-frequency
plaster/weathering, distinct aggregate/paving and restrained directional wear. Skin/cloth keep
object-space mapping; broad facial shapes take priority over noise. Keep neutral texture
modulation and authored dirty colors; no pure-white/bright-blue/pastel/neon palette additions.
Balanced dirty-cream sunlight and slate ambient/sky should separate skin, brick, plaster and
road instead of collapsing all into mustard. Keep daytime shadows readable and night legible;
night glow still names physical fixtures. Compatibility/WebGL2 and conservative static batching
remain. No expensive full-screen postprocess or unsupported renderer features.
Use 4x MSAA for cleaner thin trim and character silhouettes, and include that quality change
in the measured after sample. The before sample uses the prior 2x setting.

## Acceptance

- Record the same before/after native cameras and rendered performance at 1280x720, including
  the 60-character art/idle stress separately from full AI. Investigate material draw growth;
  report measured conditions without claiming unmeasured browser/60-agent performance.
- Inspect all six identities, first-person fists, storefronts and street surfaces in day/night.
  Fix clipping, detached facial pieces, floating props, noisy repetition and blocked rays.
- Preserve production scene traversal/rays, 18s/8s loop, dialogue, capture/refusal fallback,
  save isolation and deterministic cached materials. Keep 19/19 legacy and 3D gates green;
  add meaningful checks for any new geometry/material contract rather than screenshot hashes.
- Rebuild Windows and Web, boot the package, refresh the local browser and verify entry/menu
  exits still work. Keep versioned Web data packs and the menu fix intact.
- Append BRAIN and decision register, update backlog/README, report touched files and green
  output, commit and push. Art remains subject to operator eye review.
