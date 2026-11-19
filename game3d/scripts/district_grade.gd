extends RefCounted
## Draft: exact visual geography and opaque Canvas-RGB blend, without live state.
const MAX_RECORDS: int = 64
var _zones: Array[Dictionary] = []
var _regions: Array[Dictionary] = []
var _recipes: Array[Dictionary] = []
var _default: int = -1
var _grade_count: int = 0

func _init(world_data: Dictionary = {}) -> void:
	var catalog: Variant = world_data.get("ambientGrades")
	if not catalog is Dictionary or not catalog.has("default") or catalog.size() > MAX_RECORDS: return
	var recipes: Array[Dictionary] = []
	var indices: Dictionary = {}
	for id: Variant in catalog:
		if not id is String: return
		var recipe: Dictionary = _compile_recipe(catalog[id])
		if recipe.is_empty(): return
		var index: int = recipes.find(recipe)
		if index < 0: index = recipes.size(); recipes.append(recipe)
		indices[id] = index
	var zones: Variant = _compile_rectangles(world_data.get("zones"),indices)
	var regions: Variant = _compile_rectangles(world_data.get("terrainRegions"),indices)
	if zones == null or regions == null: return
	_zones.assign(zones); _regions.assign(regions); _recipes = recipes
	_default = indices.default; _grade_count = catalog.size()

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _rgb(value: Variant) -> Vector3:
	if not value is String: return Vector3.INF
	var channels: PackedStringArray = value.split(",",false)
	if channels.size() != 3: return Vector3.INF
	var result := Vector3.ZERO
	for index: int in range(3):
		if not channels[index].is_valid_int(): return Vector3.INF
		var channel: int = int(channels[index])
		if channel < 0 or channel > 255: return Vector3.INF
		result[index] = float(channel)/255.0
	return result

static func _compile_recipe(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var multiply: Vector3 = _rgb(value.get("multiply"))
	var overlay: Vector3 = _rgb(value.get("overlay"))
	if not multiply.is_finite() or not overlay.is_finite(): return {}
	for key: String in ["multiplyAlpha","overlayAlpha"]:
		if not _number(value.get(key)) or value[key] < 0 or value[key] > 1: return {}
	return {"multiply":multiply,"multiplyAlpha":float(value.multiplyAlpha),"overlay":overlay,"overlayAlpha":float(value.overlayAlpha)}

static func _compile_rectangles(value: Variant,indices: Dictionary) -> Variant:
	if not value is Array or value.size() > MAX_RECORDS: return null
	var result: Array[Dictionary] = []
	for row: Variant in value:
		if not row is Dictionary or not row.get("id") is String: return null
		for key: String in ["x","y","w","h"]:
			if not _number(row.get(key)): return null
		if row.w < 0 or row.h < 0 or not is_finite(float(row.x)+float(row.w)) or not is_finite(float(row.y)+float(row.h)): return null
		result.append({"x":float(row.x),"y":float(row.y),"w":float(row.w),"h":float(row.h),"index":indices.get(row.id,indices.default)})
	return result

func ready() -> bool: return _default >= 0

func at(x: float,y: float) -> Dictionary:
	if not ready(): return {}
	for rows: Array[Dictionary] in [_zones,_regions]:
		for row: Dictionary in rows:
			if x >= row.x and x <= row.x+row.w and y >= row.y and y <= row.y+row.h:
				return _result(int(row.index))
	return _result(_default)

func _result(index: int) -> Dictionary:
	var result: Dictionary = _recipes[index].duplicate(true)
	result.index = index
	return result

func recipes() -> Array[Dictionary]: return _recipes.duplicate(true)

func inspect() -> Dictionary:
	return {"ready":ready(),"zones":_zones.size(),"regions":_regions.size(),"grades":_grade_count,"recipes":_recipes.size()}

static func blend_rgb(background: Vector3,recipe: Dictionary) -> Vector3:
	if not background.is_finite(): return Vector3.INF
	for channel: int in range(3):
		if background[channel] < 0 or background[channel] > 1: return Vector3.INF
	for key: String in ["multiply","overlay"]:
		if not recipe.get(key) is Vector3 or not recipe[key].is_finite(): return Vector3.INF
		for channel: int in range(3):
			if recipe[key][channel] < 0 or recipe[key][channel] > 1: return Vector3.INF
	for key: String in ["multiplyAlpha","overlayAlpha"]:
		if not _number(recipe.get(key)) or recipe[key] < 0 or recipe[key] > 1: return Vector3.INF
	var result := Vector3.ZERO
	for channel: int in range(3):
		var b: float = background[channel]
		var q: float = (1.0-recipe.multiplyAlpha)*b+recipe.multiplyAlpha*b*recipe.multiply[channel]
		var overlay: float = 2.0*q*recipe.overlay[channel] if q <= 0.5 else 1.0-2.0*(1.0-q)*(1.0-recipe.overlay[channel])
		result[channel] = (1.0-recipe.overlayAlpha)*q+recipe.overlayAlpha*overlay if recipe.overlayAlpha > 0 else q
	return result
