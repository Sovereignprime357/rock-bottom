class_name RockBottomContent
extends RefCounted
## Immutable, source-generated content shared by native and Web. Runtime never executes JS.
## Call instance_copy() for mutable simulation state; definitions are read-only by convention.

const PATH := "res://data/source_content.json"
const METRES_PER_PIXEL := 0.04
const SOURCE_ORIGIN := Vector2(1050.0, 840.0)
static var _cache: Dictionary = {}
static var last_error: String = ""


static func load_content() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	last_error = ""
	if not FileAccess.file_exists(PATH):
		last_error = "Source content is missing. Run the deterministic content exporter."
		push_error(last_error)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("format") != "rock-bottom-source-content":
		last_error = "Source content has an unsupported format."
		push_error(last_error)
		return {}
	for key: String in ["world", "actors", "catalogs", "initial", "definitions", "source"]:
		if not parsed.get(key) is Dictionary:
			last_error = "Source content is missing its %s record." % key
			push_error(last_error)
			return {}
	var decoded: Variant = decode(parsed)
	if not decoded is Dictionary or not decoded.initial.get("player") is Dictionary or not decoded.initial.get("state") is Dictionary:
		last_error = "Source content has invalid initial state."
		push_error(last_error)
		return {}
	_cache = decoded
	return _cache


static func instance_copy() -> Dictionary:
	return load_content().duplicate(true)


static func definition(module_path: String, export_name: String, fallback: Variant = null) -> Variant:
	var content: Dictionary = load_content()
	var definitions: Dictionary = content.get("definitions", {})
	var module: Dictionary = definitions.get(module_path, {})
	return module.get(export_name, fallback)


static func decode(value: Variant) -> Variant:
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(decode(item))
		return items
	if value is Dictionary:
		if value.get("$type") == "Set" and value.get("values") is Array:
			var members: Array = []
			for item: Variant in value["values"]:
				var member: Variant = decode(item)
				if not members.has(member): members.append(member)
			return members
		if value.get("$type") == "Map" and value.get("entries") is Array:
			var mapped: Dictionary = {}
			for entry: Variant in value["entries"]:
				if entry is Array and entry.size() == 2:
					mapped[decode(entry[0])] = decode(entry[1])
			return mapped
		var record: Dictionary = {}
		for key: Variant in value:
			record[key] = decode(value[key])
		return record
	return value


static func to_world(point: Vector2, height: float = 0.0) -> Vector3:
	var relative: Vector2 = (point - SOURCE_ORIGIN) * METRES_PER_PIXEL
	return Vector3(relative.x, height, relative.y)


static func to_source(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / METRES_PER_PIXEL + SOURCE_ORIGIN


static func body_position(body: Dictionary, height: float = 0.0) -> Vector3:
	return to_world(Vector2(float(body.get("x", 0.0)) + float(body.get("w", 0.0)) * 0.5,
		float(body.get("y", 0.0)) + float(body.get("h", 0.0)) * 0.5), height)


static func speed_metres(source_speed: float) -> float:
	# Source update uses pixels per16ms. No unmeasured mobility boost is applied.
	return source_speed * METRES_PER_PIXEL / 0.016
