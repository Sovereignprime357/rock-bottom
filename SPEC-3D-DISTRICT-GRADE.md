# P15 district grade — implementation contract

Captured before generation; approved for FullHUD composition after332be27. No
engine/native/Web/performance acceptance or parity promotion is claimed before the gates.
Root owns later promotion and Scene/HUD composition. Existing original meshes and
physical/source authorities are unchanged.

## Source contract

`src/render/landmarks_a.js:221–243` pointInside/ambientGradeAt/drawAmbientGrade and
`src/data/world.js:18–68` supply the authority. Search the exported ZONES in insertion
order with all four edges inclusive, immediately returning its grade or default when
the first matching ID lacks a grade. Only if no zone matches, search TERRAIN_REGIONS
in insertion order with the same rule. Otherwise use default. A missing first grade
does not fall through to the next rectangle. No nearest-zone or faction substitution,
boundary smoothing, time interpolation, lighting multiplier, or gameplay zone mutation.
NaN/infinite coordinates naturally match no finite rectangle and return default.

The current exported census is23 zones,15 regions,39 grade IDs and6 unique recipes.
An immutable private copy of those data drives lookup; no retained mutable source
dictionary, GameState reference, clock, RNG, physics query, light or save field.

For an opaque backdrop channel b in encoded Canvas/sRGB [0,1], source multiply
color m/255 with alpha a, and overlay color o/255 with alpha t:

    q = (1-a)*b + a*(b*m)
    overlay(q,o) = 2*q*o                    when q <= .5
                   1-2*(1-q)*(1-o)         otherwise
    result = (1-t)*q + t*overlay(q,o)        when t > 0; else q

Use the multiplied q as overlay's backdrop. There is no linear-light conversion,
gamma approximation, inverse pass order, palette substitution or double grading.
The model/GLSL equations are float versions of the standard compositing equations;
Canvas may quantize its intermediate8-bit framebuffer. Native/Web patch comparison
must disclose byte differences rather than claim bit-identical browser rasterization.

## Draft API and bounds

`DistrictGrade.new(world_data)` accepts `{zones,terrainRegions,ambientGrades}` from
the existing content export and compiles detached lookup data and deduplicated recipes.
It rejects malformed data or a catalog above64 rectangles per kind/64 grade IDs;
it never truncates accepted source data. It exposes `ready()`, `at(x,y)` and
`recipes()` (detached results), `inspect()` (counts only), plus pure static
`blend_rgb(encoded_rgb,recipe)` for tests. x/y are scalar64-bit source pixels;
do not quantize boundary checks through Vector2/3 world coordinates. World metres
are not accepted. Recipe output contains multiply/overlay vectors and source alpha.

`DistrictGradeView.new(model)` is one ColorRect with mouse/focus ignored and no
automatic processing. Root attaches it full-rect below every HUD/high/crash/border/
cooking/modal overlay. `sync(source_x,source_y,mode)` selects one prebuilt material
only when the selected recipe changes and hides the rect at title. Paused/dialogue/
ending/cooking world views retain current grading. `clear()` hides and forgets the
last selection. It has one shared immutable Shader and a fixed material bank (six
for the source catalog), initialized once. No per-frame uniform writes, textures,
nodes, materials, mipmaps, blur, SubViewport, depth reads or lighting mutations.
`inspect()` exposes selected ID, bank size and material-change count only.

The shader uses Compatibility CanvasItem `unshaded, blend_disabled`, one
`hint_screen_texture`/nearest/LOD0 read and both blends in that same fragment pass.
It requires the existing opaque SDR canvas (`use_hdr_2d=false`, transparent_bg=false)
and refuses a viewport violating those assumptions. Root keeps it the first/only
screen reader or provides the explicit correct back-buffer boundary; overlapping
screen readers otherwise share an earlier copy. Existing HUD has no screen reader.

## Explicit first-person adaptation

Source frame draws player before lighting; drawLighting applies ambient grade before
emissive cores/glows; weather follows lighting (`actors_weather.js:81–113`,
`frame.js:238–266`). One full-frame3D pass instead grades the final rendered world,
including rain, emissives and first-person hands together. No extra per-object
buffers or changed light energy are introduced to mimic the2D layering. Root must
register this adaptation when activated. It does not alter the palette data or the
original art. HUD, high/crash feedback, border, cooking and modal copy remain above
the pass and retain their original colors. Title turns the pass off.

## Evidence plan

The Node oracle executes unchanged ambientGradeAt/drawAmbientGrade, captures actual
Canvas operations and asserts zero RNG/state mutation. Cover all rectangle centers,
corners and exact/+epsilon/-epsilon edges, source-order overlaps, unknown first IDs,
region/default fallback, NaN/infinity, and all39 recipes. The blend fixture applies
the W3C equations to captured operations; it is a standards reference, not a browser
pixel capture. Focused Godot tests compare lookup/recipes/blends and detached state,
material-bank reuse, title/modal visibility, clear/rebind and invalid SDR assumptions.

After promotion, Root runs a real opaque Canvas color-patch comparison with source
drawAmbientGrade versus native Compatibility and exported Web shader captures. Use
black/white, palette colors, saturated primaries, .5 branch and neighboring byte
values, plus all6 recipes. Capture patch interiors without filtering/MSAA edges;
report max/mean per-channel byte error and any >2-byte mismatch (unaccepted pending
investigation). Include a HUD patch above the pass to prove unchanged colors, title
off, all6 district views and rainy/emissive/high/crash/cooking/modal frames at1280x720
and960x540. Shader compilation and actual browser color space remain unverified here.

Frozen release A/B measurements use identical60+ actors, inputs, weather/camera,
warmup and sample windows. Report entire-frame engine/scene p95 plus grade sync CPU,
draw calls and GPU frame time when available. Screen copy and pass bandwidth must
be included; CPU-only results cannot establish GPU acceptance. If GPU timing is
unavailable, state that explicitly. Existing <16ms full-frame gate is unchanged.

## Official API/math references checked

- [Godot4.5 screen-reading shaders](https://docs.godotengine.org/en/4.5/tutorials/shaders/screen-reading_shaders.html): screen sampler, SCREEN_UV, LOD0, back-buffer copy and overlapping-reader behavior.
- [CanvasItem shader modes](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html): unshaded and blend_disabled.
- [Viewport SDR/HDR behavior](https://docs.godotengine.org/en/4.5/classes/class_viewport.html#class-viewport-property-use-hdr-2d): HDR2D changes the canvas to linear color; this draft stays SDR.
- [Shader uniform color hints](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/shading_language.html#using-source-color): raw numeric Vector3 recipe uniforms intentionally avoid automatic color conversion in the SDR equation.
- [W3C compositing/blending](https://www.w3.org/TR/compositing-1/): multiply, overlay and source-over alpha equations.
