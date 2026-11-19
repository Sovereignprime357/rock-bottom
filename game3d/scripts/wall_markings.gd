class_name RockBottomWallMarkings
extends RefCounted
## Source layout lifecycle. Only this owner consumes State RNG or replaces saved arrays.
const Content = preload("res://scripts/content_catalog.gd")
const METRICS_PATH := "res://data/courier_canvas_metrics.json"
const CATALOG := "src/data/catalogs.js"
const STRUCTURES := "src/render/structures.js"
var _host: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _widths: Dictionary = {}
var _pools: Dictionary = {}
var _palettes: Dictionary = {}
var _posters: Dictionary = {}
var _buildings: Array = []
var _zones: Array = []
var _prepared: bool = false
var _operation_ok: bool = true
var _revision: int = 0
var _draws: int = 0
var _graffiti_builds: int = 0
var _poster_builds: int = 0
var last_error: String = ""

func _init(owner: RefCounted) -> void:
	_host = weakref(owner) if owner != null else null

func _owner() -> RefCounted:
	return _host.get_ref() if _host != null else null

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _truth(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return float(value) != 0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true

static func _length(value: Variant) -> int:
	if value is Array or value is String: return value.size() if value is Array else value.length()
	if value is Dictionary and _finite(value.get("length")): return int(value.length)
	return 0

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value

func ready() -> bool:
	var owner: RefCounted = _owner()
	if owner == null or not owner.has_method("random_float"):
		last_error = "missing_state_owner"; return false
	if not _widths.is_empty(): return true
	if not FileAccess.file_exists(METRICS_PATH):
		last_error = "missing_canvas_metrics"; return false
	var metrics: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS_PATH))
	if not metrics is Dictionary or metrics.get("format") != "rock-bottom-courier-canvas-metrics" or not metrics.get("entries") is Array:
		last_error = "invalid_canvas_metrics"; return false
	var content: Dictionary = Content.load_content()
	var pools := {"street":Content.definition(CATALOG,"GRAFFITI_LINES",[]),"scrap":Content.definition(CATALOG,"SCRAP_GRAFFITI_LINES",[]),"spiritual":Content.definition(CATALOG,"SPIRITUAL_GRAFFITI_LINES",[])}
	var widths: Dictionary = {}
	for row: Variant in metrics.entries:
		if not row is Dictionary or not row.get("text") is String or not _finite(row.get("size")) or not _finite(row.get("width")) or not _finite(row.get("ceil")):
			last_error = "invalid_canvas_row"; return false
		var size: int = int(row.size)
		if size not in [8,9,10] or float(row.size) != size or row.width < 0 or float(row.ceil) != int(row.ceil) or ceili(float(row.width)) != int(row.ceil):
			last_error = "invalid_canvas_width"; return false
		if not widths.has(row.text): widths[row.text] = {}
		if widths[row.text].has(size): last_error = "duplicate_canvas_row"; return false
		widths[row.text][size] = int(row.ceil)
	var count: int = 0
	for pool: Array in pools.values():
		for line: String in pool:
			for size: int in [8,9,10]:
				if not widths.has(line) or not widths[line].has(size): last_error = "incomplete_canvas_corpus"; return false
				count += 1
	if count != 198 or metrics.entries.size() != count: last_error = "canvas_corpus_drift"; return false
	_widths = widths; _pools = pools
	_palettes = Content.definition(STRUCTURES,"GRAFFITI_PALETTES",{})
	_posters = Content.definition(STRUCTURES,"POSTER_LINES",{})
	_buildings = content.buildings; _zones = content.world.zones
	last_error = ""
	return true

func _bound() -> bool:
	var owner: RefCounted = _owner()
	return _prepared and owner != null and is_same(_player_epoch,owner.p) and is_same(_state_epoch,owner.s)

func _random() -> float:
	if not _operation_ok or not _bound(): _operation_ok = false; last_error = "replaced_epoch"; return 0.0
	var value: Variant = _owner().random_float(); _draws += 1
	if not _bound(): _operation_ok = false; last_error = "replaced_epoch"; return 0.0
	if not _finite(value) or value < 0.0 or value >= 1.0: _operation_ok = false; last_error = "invalid_random_draw"; return 0.0
	return float(value)

func _index(count: int) -> int:
	return int(floor(_random()*count))

static func current_graffiti_layout(tags: Variant) -> bool:
	if not tags is Array or tags.is_empty(): return false
	for tag: Variant in tags:
		if not tag is Dictionary or not _finite(tag.get("layoutV")) or float(tag.layoutV) != 2.0: return false
		if not _finite(tag.get("textW")) or not _finite(tag.get("wallX")) or not _finite(tag.get("wallW")) or not _finite(tag.get("x")): return false
		if tag.textW > tag.wallW or tag.x < tag.wallX-0.001 or tag.x+tag.textW > tag.wallX+tag.wallW+0.001: return false
	return true

func _zone(building: Dictionary) -> Dictionary:
	var x: float = building.x+building.w*0.5; var y: float = building.y+building.h*0.5
	for zone: Dictionary in _zones:
		if x >= zone.x and x < zone.x+zone.w and y >= zone.y and y < zone.y+zone.h: return zone
	return {}

func _graffiti(previous: Variant) -> Variant:
	if current_graffiti_layout(previous): return previous
	_graffiti_builds += 1
	var count: int = 12+_index(7)
	var walls: Array = []
	for building: Dictionary in _buildings:
		if _truth(building.get("locked")): continue
		for kind: String in ["bottom","leftside","rightside"]: walls.append({"building":building,"kind":kind})
	if walls.is_empty(): _operation_ok = false; last_error = "no_source_walls"; return null
	var output: Array = []
	for attempt: int in range(count):
		var wall: Dictionary = walls[_index(walls.size())]; var building: Dictionary = wall.building
		var zone: Dictionary = _zone(building)
		var faction: String = str(zone.get("faction","street")) if _truth(zone.get("faction")) else "street"
		var wall_x: float = building.x+6; var wall_width: float = building.w-12
		var size: int = 8+_index(3); var text: String = ""
		var pool: Array = _pools.get(faction,_pools.street)
		while size >= 8 and text.is_empty():
			var eligible: Array[String] = []
			for line: String in pool:
				if int(_widths[line][size]) <= wall_width: eligible.append(line)
			if not eligible.is_empty(): text = eligible[_index(eligible.size())]
			else: size -= 1
		if text.is_empty(): continue
		var text_width: int = _widths[text][size]
		var palette: Array = _palettes.get(faction,_palettes.street)
		var x: float = wall_x+_random()*maxf(0.0,wall_width-text_width)
		var y: float = building.y+building.h-8-_random()*16 if wall.kind == "bottom" else building.y+24+_random()*(building.h-50)
		var color: String = palette[_index(palette.size())]
		var rotation: float = (_random()-0.5)*0.18
		output.append({"x":x,"y":y,"text":text,"sz":size,"textW":text_width,"wallX":wall_x,"wallW":wall_width,"wallKind":wall.kind,"layoutV":2,"col":color,"rot":rotation})
		if not _operation_ok: return null
	return output

func _poster_layout(previous: Variant) -> Variant:
	if _truth(previous) and _length(previous) > 0: return previous
	_poster_builds += 1
	var output: Array = []; var counts: Dictionary = {}
	for building: Dictionary in _buildings:
		if _truth(building.get("locked")): continue
		var zone: Dictionary = _zone(building)
		if zone.is_empty() or not _truth(zone.get("faction")) or zone.faction == "neutral": continue
		var id: String = zone.id; var faction: String = zone.faction
		if int(counts.get(id,0)) >= 3: continue
		if _random() > 0.55: continue
		counts[id] = int(counts.get(id,0))+1
		var pool: Array = _posters[faction]
		var text: String = pool[_index(pool.size())]
		var wall: int = _index(3)
		var x: float; var y: float
		if wall == 0: x = building.x+12+_random()*(building.w-48); y = building.y+building.h-30
		elif wall == 1: x = building.x+4; y = building.y+30+_random()*(building.h-60)
		else: x = building.x+building.w-20; y = building.y+30+_random()*(building.h-60)
		output.append({"x":x,"y":y,"w":16,"h":24,"faction":faction,"text":text})
		if not _operation_ok: return null
	return output

func prepare_start(reason: String,loaded_state: Dictionary = {}) -> bool:
	if reason not in ["fresh","restore"] or not ready(): return false
	var owner: RefCounted = _owner()
	if reason == "restore" and not owner.has_method("_safe_data"):
		last_error = "missing_save_codec"; return false
	_player_epoch = owner.p; _state_epoch = owner.s; _prepared = true; _operation_ok = true
	# Direct lifecycle callers share State's codec; the pure projection remains independent.
	var graffiti: Variant = owner._safe_data(loaded_state.get("graffiti")) if reason == "restore" else null
	var posters: Variant = owner._safe_data(loaded_state.get("posters")) if reason == "restore" else null
	graffiti = _graffiti(graffiti if _truth(graffiti) else null)
	posters = _poster_layout(posters if _truth(posters) else null)
	if not _operation_ok or not _bound(): return false
	owner.s.graffiti = _copy(graffiti); owner.s.posters = _copy(posters)
	_revision += 1; last_error = ""
	return true

func before_world_draw() -> bool:
	if not ready(): return false
	var owner: RefCounted = _owner()
	if owner.s.get("mode") == "title": return true
	if not _bound(): last_error = "unprepared_epoch"; return false
	_operation_ok = true
	var graffiti: Variant = owner.s.get("graffiti"); var posters: Variant = owner.s.get("posters")
	var make_graffiti: bool = not _truth(graffiti) or _length(graffiti) == 0
	var make_posters: bool = not _truth(posters) or _length(posters) == 0
	if make_graffiti: graffiti = _graffiti(graffiti)
	if make_posters: posters = _poster_layout(posters)
	if not _operation_ok or not _bound(): return false
	if make_graffiti: owner.s.graffiti = graffiti
	if make_posters: owner.s.posters = posters
	if make_graffiti or make_posters: _revision += 1
	last_error = ""; return true

func snapshot() -> Dictionary:
	if not _bound(): return {}
	return {"graffiti":_copy(_owner().s.get("graffiti")),"posters":_copy(_owner().s.get("posters")),"revision":_revision}

func projection_revision() -> int:
	return _revision if _bound() else -1

func inspect() -> Dictionary:
	return {"ready":not _widths.is_empty(),"bound":_bound(),"revision":_revision,"draws":_draws,"graffiti_builds":_graffiti_builds,"poster_builds":_poster_builds,"last_error":last_error}
