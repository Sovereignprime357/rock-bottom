class_name SliceSurfaceKit
extends RefCounted
## Original, deterministic tiles. Shared resources are immutable after creation;
## callers needing a different cull mode or other flag must duplicate a material.
## Tiles modulate the authored palette rather than introducing a second palette.

const TILE_SIZE: int = 128
const KINDS: Array[String] = ["plain", "brick", "plaster", "concrete", "asphalt", "wood", "painted_metal", "fabric", "skin", "rubber"]
static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _palette_materials: Dictionary = {}


static func material(kind: String, hex: String, roughness: float = 0.94, emission: float = 0.0) -> StandardMaterial3D:
	var surface: String = kind if KINDS.has(kind) else "plain"
	var tint: Color = Color.from_string(hex if hex.begins_with("#") else "#" + hex, Color("d4c896"))
	var matte: float = clampf(roughness, 0.0, 1.0) if is_finite(roughness) else 0.94
	var glow: float = maxf(emission, 0.0) if is_finite(emission) else 0.0
	var key: String = "%s/%s/%s/%s" % [surface, tint.to_html(), str(matte), str(glow)]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.resource_name = "slice_%s_%s" % [surface, tint.to_html(false)]
	result.albedo_color = tint
	result.roughness = matte
	result.metallic = 0.0
	# Explicit opt-in: arbitrary materials must never be rewritten by the batcher.
	result.set_meta("slice_palette_batch", true)
	if surface != "plain":
		if not _textures.has(surface):
			_textures[surface] = ImageTexture.create_from_image(_tile(surface))
		result.albedo_texture = _textures[surface] as Texture2D
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		result.texture_repeat = true
		result.uv1_triplanar = true
		result.uv1_triplanar_sharpness = 8.0
		# Local triplanar survives rig motion and supports custom meshes without UVs.
		result.uv1_world_triplanar = surface not in ["fabric", "skin", "rubber"]
		var repeats: float = 0.80 # Masonry courses read at ~0.31m wide / ~0.16m high.
		match surface:
			"plaster", "concrete", "asphalt": repeats = 0.75
			"wood": repeats = 0.8
			"painted_metal": repeats = 0.65
			"fabric": repeats = 3.0
			"skin": repeats = 2.0
			"rubber": repeats = 2.0
		result.uv1_scale = Vector3.ONE * repeats
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = tint
		result.emission_energy_multiplier = glow
	_materials[key] = result
	return result


static func palette_material(source: StandardMaterial3D) -> StandardMaterial3D:
	# Only kit surfaces with no UV-dependent effects can discard unused tangent/UV
	# channels. Existing vertex colors are rejected separately by the batcher.
	if source == null or not bool(source.get_meta("slice_palette_batch", false)):
		return null
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.emission_enabled or source.next_pass != null:
		return null
	if source.vertex_color_use_as_albedo or source.normal_enabled or source.heightmap_enabled or source.anisotropy_enabled or source.detail_enabled:
		return null
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return null
	if source.albedo_texture != null and not source.uv1_triplanar:
		return null
	for slot: int in range(BaseMaterial3D.TEXTURE_MAX):
		if slot != BaseMaterial3D.TEXTURE_ALBEDO and source.get_texture(slot) != null:
			return null
	# Compare every stored material property except the palette tint and resource
	# bookkeeping. This retains cull mode, texture, roughness, shading and all other
	# genuine render differences, including properties a caller changed on a copy.
	var signature: String = ""
	for property: Dictionary in source.get_property_list():
		var property_name: String = str(property.name)
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if property_name.begins_with("resource_") or property_name.begins_with("metadata/") or property_name in ["albedo_color", "vertex_color_use_as_albedo", "vertex_color_is_srgb"]:
			continue
		var value: Variant = source.get(property_name)
		signature += property_name + "=" + (str((value as Resource).get_instance_id()) if value is Resource else var_to_str(value)) + ";"
	if _palette_materials.has(signature):
		return _palette_materials[signature] as StandardMaterial3D
	var result: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	result.resource_name = "slice_vertex_palette"
	result.albedo_color = Color.WHITE # Neutral carrier, actual authored tint is per vertex.
	result.vertex_color_use_as_albedo = true
	# Compatibility always interprets vertex colors as sRGB. This flag provides
	# the same interpretation in Forward+/Mobile; do not manually linearize bytes.
	result.vertex_color_is_srgb = true
	_palette_materials[signature] = result
	return result


static func _noise(x: int, y: int, salt: int = 0) -> float:
	# Fixed integer hash, independent of global RNG and creation order. Coordinates
	# wrap at the tile edge; coarse fields repeat with the same period as the tile.
	var value: int = (posmod(x, TILE_SIZE) * 374761393 + posmod(y, TILE_SIZE) * 668265263 + salt * 982451653) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float((value ^ (value >> 16)) & 65535) / 65535.0


static func _field(x: float, y: float, cell: int, salt: int) -> float:
	# Smooth, periodic dirt fields avoid the old visible square noise cells.
	var period: int = TILE_SIZE / cell
	var ix: int = floori(x / cell)
	var iy: int = floori(y / cell)
	var fx: float = smoothstep(0.0, 1.0, fposmod(x, cell) / cell)
	var fy: float = smoothstep(0.0, 1.0, fposmod(y, cell) / cell)
	var a := _noise(posmod(ix, period), posmod(iy, period), salt)
	var b := _noise(posmod(ix + 1, period), posmod(iy, period), salt)
	var c := _noise(posmod(ix, period), posmod(iy + 1, period), salt)
	var d := _noise(posmod(ix + 1, period), posmod(iy + 1, period), salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _tile(kind: String) -> Image:
	var tile: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var grain: float = _noise(x, y, 3)
			var patch: float = _field(x, y, 16, 11)
			var broad: float = _field(x, y, 32, 19)
			var value: float = 0.96
			match kind:
				"brick":
					var row: int = y >> 4
					var bx: int = posmod(x + (row % 2) * 16, TILE_SIZE)
					var face: float = _noise(bx >> 5, row, 7)
					value = 0.89 + face * 0.075 + grain * 0.016 + broad * 0.025
					if y % 16 < 2 or bx % 32 < 2:
						value = 0.67 + grain * 0.07
					elif y % 16 == 2 or bx % 32 == 2:
						value = 0.99
					elif grain < 0.018:
						value -= 0.075
				"plaster":
					value = 0.905 + broad * 0.065 + grain * 0.018
					if patch < 0.28: value -= (0.28 - patch) * 0.19
					if grain < 0.009: value -= 0.09
				"concrete":
					value = 0.90 + grain * 0.045 + broad * 0.045
					if grain < 0.024: value -= 0.11
					if patch < 0.23: value -= 0.018
				"asphalt":
					value = 0.88 + grain * 0.055 + broad * 0.065
					if grain < 0.075: value -= 0.10
					if _noise(x >> 1, y >> 1, 23) > 0.89: value = 0.98
				"wood":
					var stripe: float = _field(x, 8.0 + 6.0 * sin(float(y) * TAU / TILE_SIZE), 8, 37)
					value = 0.905 + grain * 0.018 + stripe * 0.07
					if sin(float(x) * PI * 0.5 + sin(float(y) * TAU / TILE_SIZE) * 0.7) > 0.87: value -= 0.035
					if x % 32 < 1: value = 0.71 + grain * 0.04
				"painted_metal":
					value = 0.935 + broad * 0.04 + grain * 0.012
					if patch < 0.25 and grain < 0.35: value = 0.76 + grain * 0.20
					if x % 29 == 2 and _field(x, y, 32, 47) > 0.64: value = 0.85
				"fabric":
					value = 0.94 + grain * 0.018 + broad * 0.025
					if (x + y) % 4 == 0: value -= 0.04
					if x % 4 == 0 and y % 4 == 0: value = 0.99
				"skin":
					value = 0.955 + broad * 0.025 + grain * 0.012
					if grain < 0.006: value = 0.88
				"rubber":
					value = 0.93 + grain * 0.045
					if y % 32 < 2: value -= 0.06
			value = clampf(value, 0.0, 1.0)
			tile.set_pixel(x, y, Color(value, value, value, 1.0))
	tile.generate_mipmaps()
	return tile
