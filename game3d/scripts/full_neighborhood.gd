extends "res://scripts/neighborhood.gd"
class_name FullNeighborhood
## Full source world. Geometry owns presentation/physical access, never gameplay state.

const Content = preload("res://scripts/content_catalog.gd")
const BodyContact = preload("res://scripts/actor_contact.gd")
const WORLD_RECT := Rect2(-42.0, -33.6, 344.0, 224.0)
const WALK_RADIUS := 0.48
const GRID_STEP := 0.4
const GRID_WIDTH := 860
const GRID_HEIGHT := 560
const MAX_ROUTE_EXPANSIONS := 120000
const SPATIAL_CELL := 8.0
const MAX_VISIBILITY_NODES := 256
const FLAT_PROPS: Array[String] = ["syringe", "bottle", "weeds", "chalk_message", "school_mural", "broken_window"]
const BRICK_COLORS: Array[String] = ["795847", "80604d", "735b4d", "87634d"]
const PLASTER_COLORS: Array[String] = ["a49d87", "999783", "b0a38b", "89958a"]

var content: Dictionary = {}
var source_records: Dictionary = {}
var service_points: Dictionary = {}
var structure_witnesses: Array[Dictionary] = []
var aperture_witnesses: Array[Dictionary] = []
var presentation_adaptations: Array[String] = []
var build_metrics: Dictionary = {}
var last_route_metrics: Dictionary = {}
var _anchors: Dictionary = {}
var _route_points: Dictionary = {}
var _obstacles: Array[Dictionary] = []
var _owner: String = "foundation"
var _record_start: int = 0
var _record_category: String = ""
var _record_id: String = ""
var _blocked := PackedByteArray()
var _grid_clearance: float = -1.0
var _footprint_cells: Dictionary = {}
var site_boards: Dictionary = {}
var dynamic_interactive: bool = false # Production adopts these originals into the live prop view.


func build() -> void:
	if built:
		return
	content = Content.load_content()
	if content.is_empty():
		push_error("Full neighborhood cannot build: " + Content.last_error)
		return
	built = true
	var started: int = Time.get_ticks_msec()
	_lighting()
	_full_ground()
	_full_streets()
	_full_structures()
	_full_props()
	_full_decor()
	_full_wires_and_lights()
	_full_boundaries()
	_register_services()
	_resolve_services()
	_prepare_grid(WALK_RADIUS)
	batch_stats = SliceMeshBatcher.batch_children(self, 32.0)
	_make_site_boards()
	build_metrics = {"milliseconds": Time.get_ticks_msec() - started,
		"obstacles": _obstacles.size(), "footprints": solid_footprints.size(),
		"grid_bytes": _blocked.size(), "batch": batch_stats.duplicate(true)}
	set_day_time(84.0)

func _make_site_boards() -> void:
	var rect: Rect2 = service_points["copper:abandoned"].site_rect
	var holder := Node3D.new(); holder.name = "AbandonedBoards"; add_child(holder)
	# A visual record of the source lock. The real facade remains the collider.
	for index: int in range(3):
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new(); mesh.size = Vector3(1.7,0.19,0.06)
		plank.mesh = mesh; plank.material_override = _mat("796a51",0.94,0.0,"wood")
		holder.add_child(plank)
		plank.position = Vector3(rect.get_center().x,0.65+index*0.51,rect.end.y+0.055)
		plank.rotation.z = -0.13 if index == 1 else 0.11
	site_boards.abandoned = holder

func set_site_available(id: String,available: bool) -> void:
	if site_boards.has(id): site_boards[id].visible = available


func anchors() -> Dictionary:
	return _anchors.duplicate()


func route_points() -> Dictionary:
	return _route_points.duplicate()


func collision_footprints() -> Array[Rect2]:
	return solid_footprints.duplicate()


func obstacle_records() -> Array[Dictionary]:
	return _obstacles.duplicate()


func is_clear_position(point: Vector3, margin: float = WALK_RADIUS) -> bool:
	var horizontal := Vector2(point.x, point.z)
	if not WORLD_RECT.grow(-margin).has_point(horizontal):
		return false
	var minimum := Vector2i(floori((point.x - margin) / SPATIAL_CELL), floori((point.z - margin) / SPATIAL_CELL))
	var maximum := Vector2i(floori((point.x + margin) / SPATIAL_CELL), floori((point.z + margin) / SPATIAL_CELL))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			for index: int in _footprint_cells.get(Vector2i(x, y), []):
				if solid_footprints[index].grow(margin).has_point(horizontal): return false
	return true


func safe_spawn(point: Vector3) -> Vector3:
	if is_clear_position(point):
		return Vector3(point.x, 0.06, point.z)
	var spawn: Vector3 = _anchors.get("spawn", Vector3(0.48, 0, 0.56))
	for radius: float in [0.0, 0.6, 1.0, 1.5, 2.0, 3.0, 4.0]:
		for step: int in range(16):
			var angle: float = float(step) * TAU / 16.0
			var candidate := spawn + Vector3(cos(angle) * radius, 0.06, sin(angle) * radius)
			if is_clear_position(candidate):
				return candidate
	push_error("Full world has no clear recovery placement near the source spawn")
	return Vector3.INF


func _point(record: Dictionary, centered: bool = false, height: float = 0.0) -> Vector3:
	return Content.body_position(record, height) if centered else Content.to_world(Vector2(float(record.get("x", 0)), float(record.get("y", 0))), height)


func _rect(record: Dictionary) -> Rect2:
	var at: Vector3 = _point(record)
	return Rect2(at.x, at.z, float(record.get("w", 0)) * 0.04, float(record.get("h", 0)) * 0.04)


func _begin_record(category: String, id: String, source: Dictionary) -> void:
	if not source_records.has(category):
		source_records[category] = {}
	var record: Dictionary = source.duplicate(true)
	record["owner"] = category + ":" + id
	record["mesh_count"] = 0
	source_records[category][id] = record
	_record_category = category
	_record_id = id
	_owner = category + ":" + id
	_record_start = get_child_count()


func _end_record() -> void:
	var count: int = 0
	for index: int in range(_record_start, get_child_count()):
		if get_child(index) is MeshInstance3D:
			count += 1
	source_records[_record_category][_record_id]["mesh_count"] = count


func _solid(shape: Shape3D, position_at: Vector3, rotation_at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "solid_" + _owner.replace(":", "_")
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position_at
	body.rotation_degrees = rotation_at
	body.set_meta("source_owner", _owner)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var basis := Basis.from_euler(rotation_at * PI / 180.0)
	var extent := Vector3(absf(basis.x.x) * size.x + absf(basis.y.x) * size.y + absf(basis.z.x) * size.z,
		absf(basis.x.y) * size.x + absf(basis.y.y) * size.y + absf(basis.z.y) * size.z,
		absf(basis.x.z) * size.x + absf(basis.y.z) * size.y + absf(basis.z.z) * size.z)
	var bounds := AABB(position_at - extent * 0.5, extent)
	_obstacles.append({"owner": _owner, "bounds": bounds, "body": body})
	if bounds.end.y > 0.08 and bounds.position.y < 1.86:
		var footprint := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
		var index: int = solid_footprints.size()
		solid_footprints.append(footprint)
		for y: int in range(floori(footprint.position.y / SPATIAL_CELL), floori(footprint.end.y / SPATIAL_CELL) + 1):
			for x: int in range(floori(footprint.position.x / SPATIAL_CELL), floori(footprint.end.x / SPATIAL_CELL) + 1):
				var key := Vector2i(x, y)
				if not _footprint_cells.has(key): _footprint_cells[key] = []
				_footprint_cells[key].append(index)


func _flat_rect(label: String, rect: Rect2, y: float, color: String) -> void:
	_box(label, Vector3(rect.size.x, 0.008, rect.size.y), Vector3(rect.get_center().x, y, rect.get_center().y), color)


func _full_ground() -> void:
	_owner = "foundation"
	# Floor is split into physical/render cells rather than one uncullable world mesh.
	for x: int in range(11):
		for z: int in range(7):
			var width: float = minf(32.0, WORLD_RECT.size.x - x * 32.0)
			var depth: float = minf(32.0, WORLD_RECT.size.y - z * 32.0)
			_box("ground_concrete", Vector3(width, 0.2, depth), Vector3(WORLD_RECT.position.x + x * 32.0 + width * 0.5, -0.1,
				WORLD_RECT.position.y + z * 32.0 + depth * 0.5), "676858", true)
	var palettes: Dictionary = {"vacant": "6b6b51", "school_outskirts": "777363", "service": "69695b", "drainage": "5c675b",
		"industrial": "67695e", "scrub": "686c51", "kingdom": "6d6a57"}
	for raw: Variant in content.world.terrainRegions:
		var region: Dictionary = raw
		_begin_record("terrain", str(region.id), region)
		_flat_rect("terrain_concrete", _rect(region), 0.005, str(palettes.get(str(region.get("palette", "")), "6b6d5c")))
		_end_record()
	for raw: Variant in content.world.zones:
		var zone: Dictionary = raw
		_begin_record("zones", str(zone.id), zone)
		var palette: Color = Color(str(zone.color)).lightened(0.23)
		_flat_rect("zone_concrete", _rect(zone), 0.010, palette.to_html(false))
		if str(zone.id) == "underpass":
			var r: Rect2 = _rect(zone)
			# Source cash cp16/cp17 occupies the old outer support positions.
			# These new supports move inward; source cash and actor coordinates do not.
			for x: float in [r.position.x + 3.2, r.end.x - 3.2]:
				for z: float in [r.position.y + 0.7, r.end.y - 0.7]:
					_box("viaduct_concrete_pier", Vector3(0.64, 5.4, 0.64), Vector3(x, 2.7, z), "777b70", true)
			_box("viaduct_concrete_deck", Vector3(r.size.x + 2.0, 0.65, r.size.y), Vector3(r.get_center().x, 5.7, r.get_center().y), "656e64", true)
		elif str(zone.id) == "canal":
			var r: Rect2 = _rect(zone)
			_flat_rect("canal_silt_stain", Rect2(r.position + Vector2(2, 5), r.size - Vector2(4, 10)), 0.016, "4c5c50")
		_end_record()


func _full_streets() -> void:
	for raw: Variant in content.world.roadSegments:
		var road: Dictionary = raw
		_begin_record("roads", str(road.id), road)
		var r: Rect2 = _rect(road)
		_flat_rect("street_asphalt", r, 0.022, "383e3b" if str(road.get("kind", "street")) == "street" else "4b5149")
		var horizontal: bool = str(road.axis) == "h"
		var length: float = r.size.x if horizontal else r.size.y
		for offset: float in [0.0, 1.0]:
			var edge := Vector3(r.get_center().x, 0.033, lerpf(r.position.y, r.end.y, offset)) if horizontal else Vector3(lerpf(r.position.x, r.end.x, offset), 0.033, r.get_center().y)
			_box("flush_concrete_gutter", Vector3(length, 0.025, 0.12) if horizontal else Vector3(0.12, 0.025, length), edge, "868879")
		for index: int in range(int(length / 6.0)):
			var along: float = 2.0 + index * 6.0
			var at := Vector3(r.position.x + along, 0.031, r.get_center().y) if horizontal else Vector3(r.get_center().x, 0.031, r.position.y + along)
			_box("worn_lane_paint", Vector3(1.8, 0.006, 0.075) if horizontal else Vector3(0.075, 0.006, 1.8), at, "a49c70")
			if index % 3 == 1:
				_box("asphalt_repair", Vector3(1.3, 0.007, 0.7), at + Vector3(0.3, 0.002, 0.6), "2e3732")
		_end_record()
	for index: int in range(content.world.crosswalks.size()):
		var crossing: Dictionary = content.world.crosswalks[index]
		_begin_record("crossings", str(index), crossing)
		var at: Vector3 = _point(crossing, false, 0.035)
		var vertical: bool = str(crossing.axis) == "v"
		for stripe: int in range(7):
			_box("crossing_paint", Vector3(1.65, 0.006, 0.29) if vertical else Vector3(0.29, 0.006, 1.65),
				at + (Vector3(0, 0, stripe * 0.57) if vertical else Vector3(stripe * 0.57, 0, 0)), "b0ad94")
		_end_record()
	for raw: Variant in content.world.groundPaths:
		var path_record: Dictionary = raw
		_begin_record("paths", str(path_record.id), path_record)
		var points: Array = path_record.points
		for index: int in range(points.size() - 1):
			var a: Vector3 = Content.to_world(Vector2(float(points[index][0]), float(points[index][1])), 0.019)
			var b: Vector3 = Content.to_world(Vector2(float(points[index + 1][0]), float(points[index + 1][1])), 0.019)
			var strip: MeshInstance3D = _box("worn_concrete_path", Vector3(float(path_record.width) * 0.04, 0.008, a.distance_to(b)), (a + b) * 0.5, "8a8268")
			strip.rotation.y = atan2(b.x - a.x, b.z - a.z)
		_end_record()
	for index: int in range(content.world.railLines.size()):
		var rail: Dictionary = content.world.railLines[index]
		_begin_record("rails", str(index), rail)
		var a: Vector3 = Content.to_world(Vector2(float(rail.x1), float(rail.y1)))
		var b: Vector3 = Content.to_world(Vector2(float(rail.x2), float(rail.y2)))
		var length: float = a.distance_to(b)
		_box("rail_ballast_concrete", Vector3(length, 0.016, 1.9), (a + b) * 0.5 + Vector3(0, 0.018, 0), "5c5c50")
		for step: int in range(int(length / 0.65)):
			_box("rail_wood_sleeper", Vector3(0.18, 0.035, 1.7), a + Vector3(step * 0.65, 0.035, 0), "655844")
		for offset: float in [-0.57, 0.57]:
			_box("rail_metal", Vector3(length, 0.04, 0.055), (a + b) * 0.5 + Vector3(0, 0.049, offset), "8b8d7b")
		_end_record()


func _structure_id(index: int, record: Dictionary) -> String:
	return "building_%02d" % index if index < content.buildings.size() else str(record.id)


func _openings(index: int, record: Dictionary, rect: Rect2) -> Array[Vector2]:
	var centers: Array[float] = []
	if bool(record.get("doorGap", false)):
		centers.append(rect.get_center().x)
	for raw: Variant in content.actors.base:
		var actor: Dictionary = raw
		if int(actor.get("legacyStructureIndex", -1)) == index:
			centers.append(Content.body_position(actor).x)
	# These two source dumpsters lie inside closed source rectangles. Their real
	# south service openings expose existing objects; no actor/pickup is relocated.
	if index == 2:
		centers.append(Content.to_world(Vector2(1638, 292)).x)
		presentation_adaptations.append("building_02: open south service bay to source dumpster prop3; locked front transaction remains a gameplay gate")
	if str(record.get("id", "")) == "checks":
		centers.append(Content.to_world(Vector2(798, 252)).x)
		presentation_adaptations.append("checks: open south refuse bay to source dumpster prop4")
	var intervals: Array[Vector2] = []
	for center: float in centers:
		intervals.append(Vector2(maxf(rect.position.x + 0.28, center - 1.2), minf(rect.end.x - 0.28, center + 1.2)))
	intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for interval: Vector2 in intervals:
		if not merged.is_empty() and interval.x <= merged[-1].y + 0.12:
			merged[-1].y = maxf(merged[-1].y, interval.y)
		else:
			merged.append(interval)
	return merged


func _full_structures() -> void:
	for index: int in range(content.world.structures.size()):
		var record: Dictionary = content.world.structures[index]
		_begin_record("structures", _structure_id(index, record), record)
		var rect: Rect2 = _rect(record)
		var title: String = str(record.get("name", record.get("sign", "")))
		var kind: String = str(record.get("kind", "storefront"))
		if title == "SHACK": kind = "shack"
		if index in [14, 15, 17, 19, 21]: kind = "warehouse"
		var height: float = 3.0 if kind == "shack" else 6.7 if kind == "rowhouse" else 5.6 if kind in ["warehouse", "industrial"] else 4.5
		if title == "CHURCH": height = 7.0
		if title == "OLDSCHOOL": height = 6.3
		var color: String = BRICK_COLORS[index % BRICK_COLORS.size()]
		var finish: String = "brick"
		if kind == "shack":
			finish = "wood"; color = "796a51"
		elif kind == "warehouse":
			finish = "metal"; color = "777f70"
		elif kind == "rowhouse" or index % 3 == 0:
			finish = "plaster"; color = PLASTER_COLORS[index % PLASTER_COLORS.size()]
		var center: Vector2 = rect.get_center()
		var front: float = rect.end.y
		_box("interior_concrete_floor", Vector3(rect.size.x, 0.018, rect.size.y), Vector3(center.x, 0.012, center.y), "858574")
		_box("back_" + finish, Vector3(rect.size.x, height, 0.24), Vector3(center.x, height * 0.5, rect.position.y + 0.12), color, true)
		for side: float in [rect.position.x + 0.12, rect.end.x - 0.12]:
			_box("side_" + finish, Vector3(0.24, height, rect.size.y), Vector3(side, height * 0.5, center.y), color, true)
		var openings: Array[Vector2] = _openings(index, record, rect)
		var cursor: float = rect.position.x
		for gap: Vector2 in openings:
			_front_wall(cursor, gap.x, front, height, finish, color)
			_box("door_" + finish + "_lintel", Vector3(gap.y - gap.x, height - 2.5, 0.24), Vector3((gap.x + gap.y) * 0.5, 2.5 + (height - 2.5) * 0.5, front - 0.12), color, true)
			for x: float in [gap.x - 0.055, gap.y + 0.055]:
				_box("door_metal_jamb", Vector3(0.10, 2.58, 0.32), Vector3(x, 1.29, front - 0.08), "6f776a", true)
			aperture_witnesses.append({"owner": _owner, "from": Vector3((gap.x + gap.y) * 0.5, 1.3, front + 0.55), "to": Vector3((gap.x + gap.y) * 0.5, 1.3, front - 0.55), "width": gap.y - gap.x})
			cursor = gap.y
		_front_wall(cursor, rect.end.x, front, height, finish, color)
		if openings.is_empty():
			_closed_entry(Vector3(center.x, 0, front), minf(1.25, rect.size.x * 0.24), 2.2, "556052")
		_box("roof_metal_eave", Vector3(rect.size.x + 0.3, 0.20, rect.size.y + 0.3), Vector3(center.x, height + 0.1, center.y), "505c52", true)
		if kind in ["shack", "warehouse"] or title == "CHURCH":
			_pitched_roof(Vector3(center.x, height + 0.2, center.y), rect.size.x + 0.45, rect.size.y + 0.45, minf(1.6, rect.size.x * 0.15), "657064")
		else:
			for z: float in [rect.position.y, front]:
				_box("roof_parapet_" + finish, Vector3(rect.size.x + 0.2, 0.50, 0.22), Vector3(center.x, height + 0.38, z), color)
			_box("roof_airbox_metal", Vector3(1.3, 0.65, 0.9), Vector3(center.x + rect.size.x * 0.18, height + 0.55, center.y), "6b7567")
		_facade_bays(rect, height, index, finish, color, openings)
		if not title.is_empty():
			var fascia_y: float = 3.12 if height >= 4.0 else 2.74
			var fascia_width: float = minf(rect.size.x - 0.5, maxf(2.3, title.length() * 0.23))
			_box("shop_fascia_wood", Vector3(fascia_width, 0.58, 0.18), Vector3(center.x, fascia_y, front + 0.09), "35473c")
			_sign(title, Vector3(center.x, fascia_y + 0.01, front + 0.19), 52, minf(0.006, fascia_width / maxf(1.0, title.length() * 30.0)), "c4b692")
		if not openings.is_empty():
			_interior_details(rect, height, index, title)
		structure_witnesses.append({"owner": _owner, "from": Vector3(center.x, 1.3, rect.position.y - 0.6), "to": Vector3(center.x, 1.3, rect.position.y + 0.6), "bounds": rect})
		_end_record()


func _front_wall(left: float, right: float, front: float, height: float, finish: String, color: String) -> void:
	if right - left > 0.02:
		_box("front_" + finish, Vector3(right - left, height, 0.24), Vector3((left + right) * 0.5, height * 0.5, front - 0.12), color, true)


func _facade_bays(rect: Rect2, height: float, index: int, finish: String, color: String, openings: Array[Vector2]) -> void:
	var bays: int = maxi(1, int(rect.size.x / 2.8))
	for bay: int in range(bays):
		var x: float = rect.position.x + (bay + 0.5) * rect.size.x / bays
		var blocked: bool = false
		for gap: Vector2 in openings:
			if x > gap.x - 0.85 and x < gap.y + 0.85: blocked = true
		if not blocked and height > 3.3:
			_framed_window(Vector3(x, 1.65, rect.end.y + 0.01), minf(1.5, rect.size.x / bays - 0.55), 1.35, "a19b83", index + bay)
		if height > 5.8:
			_framed_window(Vector3(x, 4.65, rect.end.y + 0.01), 1.25, 1.35, "929782", index + bay + 1)
		_box("facade_" + finish + "_pier", Vector3(0.20, height, 0.13), Vector3(rect.position.x + bay * rect.size.x / bays, height * 0.5, rect.end.y + 0.03), color)
	for side: int in range(2):
		var yaw: float = -90.0 if side == 0 else 90.0
		var x: float = rect.position.x if side == 0 else rect.end.x
		var windows: int = mini(5, maxi(1, int(rect.size.y / 3.5)))
		for slot: int in range(windows):
			_framed_window(Vector3(x, minf(2.1, height - 1.0), rect.position.y + (slot + 0.5) * rect.size.y / windows), 1.1, 1.2, "8b917d", index + slot, yaw)
		_box("wall_downpipe_metal", Vector3(0.09, height - 0.2, 0.09), Vector3(x, (height - 0.2) * 0.5, rect.position.y + 0.3), "565e50")
	_box("plinth_concrete", Vector3(rect.size.x, 0.12, 0.12), Vector3(rect.get_center().x, 0.10, rect.position.y), "6e7463")


func _interior_details(rect: Rect2, height: float, index: int, title: String) -> void:
	var center: Vector2 = rect.get_center()
	# Fixtures/shelves hug the rear. Source occupants and all south approaches stay clear.
	_fixture(Vector3(center.x, minf(height - 0.2, 3.1), center.y), minf(1.2, rect.size.x * 0.3), "c5bd9d", 0.8, minf(7.0, rect.size.x))
	for shelf: int in range(2):
		var x: float = rect.position.x + 0.85 + shelf * 1.5
		if x > rect.end.x - 0.6: continue
		for tier: int in range(3):
			_box("interior_wood_shelf", Vector3(1.25, 0.10, 0.48), Vector3(x, 0.65 + tier * 0.63, rect.position.y + 0.48), "7c7359", true)
			for item: int in range(3):
				_box("shelf_stock", Vector3(0.27, 0.35, 0.28), Vector3(x - 0.4 + item * 0.4, 0.87 + tier * 0.63, rect.position.y + 0.5), "9a9276")
	if title == "LAUNDROMAT":
		for machine: int in range(4):
			var at := Vector3(rect.position.x + 0.8 + machine * 1.1, 0, rect.position.y + 0.7)
			_box("laundry_metal_machine", Vector3(0.9, 1.1, 0.7), at + Vector3(0, 0.55, 0), "a0a491", true)
			var drum: MeshInstance3D = _cylinder("laundry_window", 0.28, 0.04, at + Vector3(0, 0.55, 0.37), "354a42", false, 12)
			drum.rotation_degrees.x = 90
	if index == 0:
		_sign("AS IS", Vector3(center.x, 2.5, rect.position.y + 0.26), 36, 0.006, "c4b692")
	if title == "CHURCH":
		_box("church_wood_cross", Vector3(0.16, 1.8, 0.15), Vector3(center.x, 3.1, rect.position.y + 0.28), "796b51")
		_box("church_wood_cross", Vector3(0.95, 0.16, 0.15), Vector3(center.x, 3.45, rect.position.y + 0.28), "796b51")


func _full_props() -> void:
	for index: int in range(content.props.size()):
		var prop: Dictionary = content.props[index]
		_begin_record("props", str(index), prop)
		_build_prop(prop, index)
		_end_record()
	for index: int in range(content.interactiveProps.size()):
		var prop: Dictionary = content.interactiveProps[index]
		_begin_record("interactiveProps", str(prop.get("id", index)), prop)
		var at: Vector3 = _point(prop)
		if str(prop.type) == "trashcan":
			_cylinder("kickable_metal_bin", 0.30, 0.76, at + Vector3(0, 0.38, 0), "687c62", not dynamic_interactive, 10)
			_cylinder("kickable_metal_lid", 0.33, 0.08, at + Vector3(0, 0.80, 0), "899378", false, 10)
		else:
			_cylinder("breakable_bottle_glass", 0.065, 0.25, at + Vector3(0, 0.125, 0), "627458", not dynamic_interactive, 6)
			_cylinder("bottle_neck_glass", 0.027, 0.10, at + Vector3(0, 0.30, 0), "627458", false, 6)
		# Stateful props retain individually addressable geometry for later gameplay.
		for child_index: int in range(_record_start, get_child_count()):
			var child: Node = get_child(child_index)
			if child is MeshInstance3D:
				child.set_meta("source_owner", _owner)
				if dynamic_interactive: child.visible = false
		_end_record()


func _build_prop(prop: Dictionary, index: int) -> void:
	var kind: String = str(prop.type)
	var at: Vector3 = _point(prop, prop.has("w") and prop.has("h"))
	var width: float = float(prop.get("w", 24)) * 0.04
	var depth: float = float(prop.get("h", 20)) * 0.04
	var rust: String = Color(str(prop.get("color", "#584937"))).lightened(0.16).to_html(false)
	match kind:
		"dumpster":
			_box("dumpster_metal_body", Vector3(width, 1.05, depth), at + Vector3(0, 0.63, 0), "4c644d", true)
			_box("dumpster_metal_lid", Vector3(width + 0.10, 0.10, depth + 0.10), at + Vector3(0, 1.21, 0), "3b4d3e", true)
			for side: float in [-1, 1]:
				_box("dumpster_metal_rib", Vector3(0.06, 0.78, 0.04), at + Vector3(side * width * 0.30, 0.65, depth * 0.5 + 0.02), "72846a")
			_box("dumpster_weathering", Vector3(width * 0.45, 0.18, 0.015), at + Vector3(0, 0.36, depth * 0.5 + 0.03), "856544")
			_sign("NO ASHES", at + Vector3(0, 0.88, depth * 0.5 + 0.04), 25, 0.004, "b8ad87")
		"cart", "cart_husk":
			_box("cart_metal_frame", Vector3(width, 0.08, depth), at + Vector3(0, 0.28, 0), "7f8879", true)
			for side: float in [-1, 1]:
				_box("cart_metal_basket", Vector3(0.045, 0.52, depth * 0.90), at + Vector3(side * width * 0.47, 0.65, 0), "8c9480")
				for slot: int in range(5):
					_box("cart_metal_wire", Vector3(width, 0.025, 0.025), at + Vector3(0, 0.45 + slot * 0.10, side * depth * 0.47), "8c9480")
				_cylinder("cart_wheel", 0.13, 0.14, at + Vector3(side * width * 0.38, 0.14, depth * 0.32), "303c32", false, 8)
			_box("cart_basket_collision", Vector3(width, 0.55, depth), at + Vector3(0, 0.63, 0), "7b8574", true).visible = false
			_box("cart_rubber_handle", Vector3(width, 0.09, 0.09), at + Vector3(0, 1.02, depth * 0.6), "465547")
			if kind == "cart":
				for child_index: int in range(_record_start, get_child_count()):
					var child: Node = get_child(child_index)
					if child is MeshInstance3D: child.set_meta("source_owner", _owner)
		"lamp":
			_lamp(at, 90.0 if index % 2 == 0 else -90.0)
		"hydrant":
			_cylinder("hydrant_metal", 0.14, 0.68, at + Vector3(0, 0.34, 0), "9a7551", true, 8)
			_cylinder("hydrant_metal_cap", 0.19, 0.15, at + Vector3(0, 0.76, 0), "9e8057", false, 8, 0.09)
			_box("hydrant_metal_spouts", Vector3(0.51, 0.16, 0.16), at + Vector3(0, 0.51, 0), "836e4d", true)
		"mailbox":
			_box("mailbox_metal_post", Vector3(0.10, 0.7, 0.10), at + Vector3(0, 0.35, 0), "64715f", true)
			_box("mailbox_metal", Vector3(0.50, 0.55, 0.38), at + Vector3(0, 0.9, 0), "6f8370", true)
			_box("mailbox_slot", Vector3(0.34, 0.06, 0.02), at + Vector3(0, 0.98, 0.20), "283b30")
		"cone":
			_box("cone_rubber_base", Vector3(0.38, 0.06, 0.38), at + Vector3(0, 0.03, 0), "4a4d3c")
			_cylinder("cone", 0.15, 0.52, at + Vector3(0, 0.30, 0), "a66f39", true, 6, 0.035)
		"trash":
			_cylinder("trash_bag", 0.24, 0.38, at + Vector3(0, 0.19, 0), "3b493b", true, 6, 0.14)
			_box("discarded_paper", Vector3(0.32, 0.008, 0.25), at + Vector3(0.25, 0.018, 0.18), "9a9577", false, Vector3(0, index * 17, 0))
		"crate":
			_box("crate_wood_body", Vector3(0.88, 0.68, 0.66), at + Vector3(0.42, 0.34, 0.28), "8c7956", true)
			for x: float in [0.08, 0.76]:
				_box("crate_wood_brace", Vector3(0.11, 0.73, 0.72), at + Vector3(x, 0.36, 0.28), "6f6048")
		"syringe", "bottle":
			var debris: MeshInstance3D = _cylinder("discarded_glass", 0.035 if kind == "syringe" else 0.065, 0.28, at + Vector3(0, 0.05, 0), "929b83", false, 6)
			debris.rotation_degrees.z = 90
		"tent":
			var tent_at: Vector3 = at + Vector3(0.48, 0, 0.32)
			_pitched_roof(tent_at, 1.15, 1.10, 1.05, rust)
			_box("tent_entry", Vector3(0.44, 0.65, 0.018), tent_at + Vector3(0, 0.32, 0.56), "283c34")
		"cardsign":
			var sign_at: Vector3 = at + Vector3(0.55, 0, 0.22)
			_box("sign_wood_leg", Vector3(0.06, 0.76, 0.06), sign_at + Vector3(0, 0.38, 0), "71654b", true)
			_box("cardboard_sign", Vector3(1.05, 0.76, 0.045), sign_at + Vector3(0, 0.92, 0), "ac9c72", true)
			_sign(str(prop.get("text", "")), sign_at + Vector3(0, 0.92, 0.03), 28, 0.0032, "4c4e38")
		"scrap_pile":
			_box("scrap_metal_base", Vector3(width, 0.36, depth), at + Vector3(0, 0.18, 0), rust, true)
			for bit: int in range(4):
				_box("scrap_metal_piece", Vector3(width * 0.47, 0.09, depth * 0.7), at + Vector3((bit % 2 - 0.5) * width * 0.35, 0.40 + bit * 0.09, 0), "8b8067", false, Vector3(0, bit * 23, bit * 7))
		"car_wreck":
			_wreck(at, width, depth, rust)
		"leash_post":
			_cylinder("leash_wood_post", 0.075, 0.85, at + Vector3(0, 0.425, 0), "8d805d", true, 6)
		"pay_phone":
			_box("phone_metal_stand", Vector3(0.12, 1.2, 0.12), at + Vector3(0, 0.6, 0), "67715e", true)
			_box("phone_metal_back", Vector3(0.55, 0.94, 0.20), at + Vector3(0, 1.35, 0), "879580", true)
			_box("phone_dark_face", Vector3(0.40, 0.70, 0.04), at + Vector3(0, 1.35, 0.13), "344b3e")
			_box("phone_receiver", Vector3(0.07, 0.42, 0.08), at + Vector3(-0.14, 1.4, 0.18), "252f29")
			for key: int in range(9):
				_box("phone_metal_key", Vector3(0.04, 0.04, 0.025), at + Vector3(0.01 + (key % 3) * 0.06, 1.45 - floorf(key / 3.0) * 0.06, 0.17), "acaa8f")
		"freight_car":
			# Derailed boxcar shell with a real cargo opening at ground level. The
			# source hopper/quest points are inside prop54, not outside a solid box.
			_box("freight_metal_back", Vector3(width, 3.0, 0.16), at + Vector3(0, 1.5, -depth * 0.5 + 0.08), rust, true)
			for side: float in [-1, 1]:
				_box("freight_metal_end", Vector3(0.16, 3.0, depth), at + Vector3(side * (width * 0.5 - 0.08), 1.5, 0), rust, true)
				var panel_width: float = (width - 2.5) * 0.5
				_box("freight_metal_front", Vector3(panel_width, 3.0, 0.16), at + Vector3(side * (1.25 + panel_width * 0.5), 1.5, depth * 0.5 - 0.08), rust, true)
			_box("freight_metal_door_lintel", Vector3(2.5, 0.48, 0.16), at + Vector3(0, 2.76, depth * 0.5 - 0.08), rust, true)
			_box("freight_wood_floor", Vector3(width - 0.32, 0.018, depth - 0.16), at + Vector3(0, 0.018, 0), "7c7258")
			_box("freight_metal_roof", Vector3(width + 0.12, 0.12, depth + 0.14), at + Vector3(0, 3.12, 0), "6d7160")
			for rib: int in range(int(width / 0.42)):
				var rib_x: float = -width * 0.48 + rib * 0.42
				if absf(rib_x) > 1.3:
					_box("freight_metal_rib", Vector3(0.055, 2.55, 0.055), at + Vector3(rib_x, 1.45, depth * 0.5 + 0.03), "7f6750")
			_box("freight_metal_sliding_door", Vector3(2.45, 2.38, 0.075), at + Vector3(width * 0.30, 1.27, depth * 0.5 + 0.08), "6b5543")
			if index == 54:
				presentation_adaptations.append("freight_car prop54: open ground-level cargo bay preserves hopper and conductor quest coordinates")
			for x: float in [-width * 0.34, width * 0.34]:
				_cylinder("freight_wheel", 0.38, 0.30, at + Vector3(x, 0.35, 0), "394239", false, 10)
		"chalk_message":
			var chalk: Label3D = _sign(str(prop.text), at + Vector3(0, 0.03, 0), 30, 0.006, "a6aa8e")
			chalk.rotation_degrees.x = -90
			_box("chalk_ground_mark", Vector3(0.55, 0.006, 0.045), at + Vector3(0, 0.021, 0.12), "9c9d83")
		"weeds":
			for blade: int in range(4):
				_box("weeds", Vector3(0.045, 0.17 + blade * 0.025, 0.06), at + Vector3((blade - 1.5) * 0.06, 0.10, 0), "727b4e", false, Vector3(0, blade * 37, blade * 11 - 16))
		"fountain":
			_cylinder("fountain_concrete_basin", 0.86, 0.32, at + Vector3(0, 0.16, 0), "929b84", true, 12)
			_cylinder("fountain_stagnant_water", 0.73, 0.012, at + Vector3(0, 0.327, 0), "526c58", false, 12)
			_cylinder("fountain_concrete_stem", 0.18, 0.82, at + Vector3(0, 0.67, 0), "9ea38c", true, 8)
			_cylinder("fountain_concrete_bowl", 0.44, 0.12, at + Vector3(0, 1.14, 0), "9ca18b", false, 10)
		"park_bench":
			_bench(at, maxf(1.35, width))
		"swing_set":
			var swing := at + Vector3(1.15, 0, 0)
			for side: float in [-1, 1]:
				_box("swing_metal_post", Vector3(0.075, 2.55, 0.075), swing + Vector3(side * 1.2, 1.275, 0), "7a8970", true)
			_box("swing_metal_crossbar", Vector3(2.5, 0.09, 0.09), swing + Vector3(0, 2.55, 0), "7a8970")
			for side: float in [-1, 1]:
				_box("swing_metal_chain", Vector3(0.022, 1.9, 0.022), swing + Vector3(side * 0.22, 1.55, 0), "929b83")
			_box("swing_wood_seat", Vector3(0.56, 0.06, 0.25), swing + Vector3(0, 0.58, 0), "74694d", true)
		"drink_fountain":
			_box("drinking_concrete_pedestal", Vector3(0.35, 0.86, 0.36), at + Vector3(0, 0.43, 0), "89977d", true)
			_cylinder("drinking_metal_bowl", 0.24, 0.10, at + Vector3(0, 0.91, 0), "a1a28b", false, 8)
		"tree":
			_cylinder("tree_wood_trunk", 0.18, 2.4, at + Vector3(0, 1.2, 0), "706448", true, 7, 0.10)
			for crown: int in range(3):
				_cylinder("tree_foliage", 1.0 - crown * 0.15, 1.05, at + Vector3((crown % 2) * 0.35, 2.65 + crown * 0.6, 0), "65784d", false, 7, 0.42)
		"school_mural", "broken_window":
			# Both are explicitly wall paint/overlay in source, not free-standing solids.
			_box("wall_weathering", Vector3(0.9, 0.012, 0.46), at + Vector3(0, 0.026, 0), "858570")
			if kind == "school_mural":
				var mural: Label3D = _sign(str(prop.text), at + Vector3(0, 0.038, 0), 32, 0.009, "a29a77")
				mural.rotation_degrees.x = -90
		"broken_hoop":
			_box("hoop_metal_post", Vector3(0.09, 2.8, 0.09), at + Vector3(0, 1.4, 0), "71816a", true)
			_box("hoop_wood_backboard", Vector3(1.2, 0.76, 0.09), at + Vector3(0, 2.75, -0.08), "aaab8e")
			_box("hoop_metal_bent_rim", Vector3(0.45, 0.06, 0.34), at + Vector3(0.10, 2.46, 0.17), "9a754f", false, Vector3(0, 0, -16))
		"school_fence":
			_box("school_fence_metal", Vector3(width, 1.65, maxf(depth, 0.10)), at + Vector3(0, 0.825, 0), "6b7762", true)
			for post: int in range(int(width / 2.0) + 1):
				_box("school_fence_post", Vector3(0.09, 1.85, 0.12), at + Vector3(-width * 0.5 + post * 2.0, 0.925, 0), "90947a")
		"breakin_shell":
			_breakin_shell(prop, at, width, depth, rust)
		_:
			push_error("Unimplemented full-world prop type: " + kind)


func _wreck(at: Vector3, width: float, depth: float, color: String) -> void:
	_box("car_metal_body", Vector3(width, 0.60, depth), at + Vector3(0, 0.50, 0), color, true)
	_box("car_metal_cabin", Vector3(width * 0.47, 0.51, depth * 0.80), at + Vector3(-width * 0.07, 1.02, 0), "776851", true)
	for side: float in [-1, 1]:
		_box("car_window", Vector3(width * 0.42, 0.32, 0.024), at + Vector3(-width * 0.07, 1.05, side * depth * 0.41), "374c42")
		_box("car_window_metal_pillar", Vector3(0.08, 0.44, 0.035), at + Vector3(0, 1.04, side * depth * 0.42), color)
		for x: float in [-width * 0.31, width * 0.31]:
			var wheel: MeshInstance3D = _cylinder("car_tire", 0.28, 0.13, at + Vector3(x, 0.28, side * depth * 0.45), "303c32", false, 8)
			wheel.rotation_degrees.x = 90
	_box("car_metal_bumper", Vector3(0.09, 0.13, depth), at + Vector3(width * 0.51, 0.35, 0), "94977f")
	_box("car_missing_headlight", Vector3(0.022, 0.18, 0.24), at + Vector3(width * 0.505, 0.60, depth * 0.28), "2d3b31")


func _bench(at: Vector3, width: float) -> void:
	for side: float in [-1, 1]:
		_box("bench_metal_leg", Vector3(0.09, 0.50, 0.38), at + Vector3(side * width * 0.39, 0.25, 0), "576c57", true)
		_box("bench_metal_back", Vector3(0.06, 0.94, 0.06), at + Vector3(side * width * 0.39, 0.47, -0.20), "576c57", true)
	_box("bench_wood_seat", Vector3(width, 0.09, 0.46), at + Vector3(0, 0.51, 0), "978762", true)
	for y: float in [0.75, 0.94]:
		_box("bench_wood_back", Vector3(width, 0.14, 0.06), at + Vector3(0, y, -0.20), "8a7958")


func _breakin_shell(prop: Dictionary, at: Vector3, width: float, depth: float, color: String) -> void:
	var height: float = 3.6
	_box("breakin_plaster_shell", Vector3(width, height, depth), at + Vector3(0, height * 0.5, 0), color, true)
	_pitched_roof(at + Vector3(0, height, 0), width + 0.25, depth + 0.25, 1.2, "686d5c")
	_closed_entry(at + Vector3(0, 0, depth * 0.5), 1.25, 2.2, "62765c")
	for side: float in [-1, 1]:
		_framed_window(at + Vector3(side * width * 0.3, 1.6, depth * 0.5), 1.15, 1.3, "a5a58b", int(absf(at.x)))
	_sign(str(prop.get("sign", "")), at + Vector3(0, 2.94, depth * 0.5 + 0.10), 42, 0.006, "c4b695")


func _full_decor() -> void:
	for index: int in range(content.world.decor.size()):
		var decor: Dictionary = content.world.decor[index]
		_begin_record("decor", str(index), decor)
		var at: Vector3 = _point(decor)
		var kind: String = str(decor.type)
		match kind:
			"bus_shelter":
				var width: float = float(decor.w) * 0.04
				for side: float in [-1, 1]:
					_box("bus_metal_post", Vector3(0.09, 2.35, 0.09), at + Vector3(side * width * 0.5, 1.175, -0.45), "657c68", true)
				_box("bus_metal_roof", Vector3(width + 0.24, 0.13, 1.15), at + Vector3(0, 2.40, 0), "6d836f")
				_box("bus_glass_back", Vector3(width, 1.65, 0.055), at + Vector3(0, 1.28, -0.48), "788c7a", true)
				_bench(at + Vector3(0, 0, -0.12), width * 0.65)
			"billboard", "motel_sign":
				var width: float = float(decor.get("w", 80)) * 0.04
				var panel_height: float = 1.7 if kind == "billboard" else 2.2
				_box("sign_metal_post", Vector3(0.16, 3.5, 0.16), at + Vector3(0, 1.75, 0), "616c58", true)
				_box("billboard_wood_face", Vector3(width, panel_height, 0.16), at + Vector3(0, 3.1, 0), "a29572")
				_sign(str(decor.get("text", "")), at + Vector3(0, 3.1, 0.10), 36, minf(0.007, width / 650.0), "45513d")
			"water_tower":
				for x: float in [-1.0, 1.0]:
					for z: float in [-1.0, 1.0]:
						_box("tower_metal_leg", Vector3(0.12, 5.1, 0.12), at + Vector3(x, 2.55, z), "677561", true)
				_cylinder("tower_metal_tank", 1.45, 2.15, at + Vector3(0, 5.7, 0), "85927a", false, 10)
				_cylinder("tower_metal_cap", 1.5, 0.65, at + Vector3(0, 7.10, 0), "69745e", false, 10, 0.1)
				_sign(str(decor.get("text", "")), at + Vector3(0, 5.75, 1.46), 44, 0.009, "c0b58f")
			"clothesline":
				var other: Vector3 = Content.to_world(Vector2(float(decor.x2), float(decor.y2)))
				for end: Vector3 in [at, other]:
					_cylinder("clothesline_wood_post", 0.05, 2.6, end + Vector3(0, 1.3, 0), "796d4f", true, 6)
				_beam(at + Vector3(0, 2.45, 0), other + Vector3(0, 2.45, 0), 0.018, "717960")
				for piece: int in range(4):
					_box("laundry_fabric", Vector3(0.45, 0.62, 0.015), at.lerp(other, 0.2 + piece * 0.2) + Vector3(0, 2.12, 0), PLASTER_COLORS[piece])
			"crossbuck", "rail_signal":
				_cylinder("rail_signal_metal_post", 0.075, 2.8, at + Vector3(0, 1.4, 0), "72836b", true, 6)
				if kind == "crossbuck":
					for tilt: float in [-34, 34]:
						_box("rail_crossbuck_wood", Vector3(1.05, 0.14, 0.06), at + Vector3(0, 2.55, 0), "bab28c", false, Vector3(0, 0, tilt))
				else:
					_box("signal_metal_case", Vector3(0.30, 0.72, 0.20), at + Vector3(0, 2.35, 0), "3e5141")
					_box("signal_lens", Vector3(0.16, 0.16, 0.018), at + Vector3(0, 2.49, 0.12), "a16843", false, Vector3.ZERO, 0.4)
			"news_box":
				_box("newsbox_metal", Vector3(0.46, 0.87, 0.39), at + Vector3(0, 0.435, 0), "8b8d68", true)
				_box("newsbox_window", Vector3(0.34, 0.27, 0.018), at + Vector3(0, 0.65, 0.21), "364a3e")
				_box("newsbox_paper", Vector3(0.28, 0.22, 0.018), at + Vector3(0, 0.63, 0.23), "b8b08e")
			"road_barrier":
				for x: float in [-0.5, 0.5]:
					_box("barrier_wood_leg", Vector3(0.10, 0.83, 0.36), at + Vector3(x, 0.415, 0), "777357", true)
				_box("barrier_wood_board", Vector3(1.4, 0.25, 0.10), at + Vector3(0, 0.74, 0), "b1a26d", true)
				for stripe: int in range(4):
					_box("barrier_paint", Vector3(0.13, 0.25, 0.012), at + Vector3(-0.48 + stripe * 0.32, 0.74, 0.06), "745a35", false, Vector3(0, 0, -24))
			"storm_drain":
				_gutter_inlet(at)
			"utility_pole":
				_cylinder("utility_pole", 0.13, 6.0, at + Vector3(0, 3.0, 0), "786848", true, 7, 0.09)
				_box("utility_wood_crossarm", Vector3(1.4, 0.12, 0.12), at + Vector3(0, 5.7, 0), "8d7a56")
				for side: float in [-1, 1]:
					_cylinder("pole_insulator", 0.07, 0.18, at + Vector3(side * 0.52, 5.84, 0), "a1a58c", false, 6)
			"burn_barrel":
				_barrel(at, true)
			_:
				push_error("Unimplemented full-world decor: " + kind)
		_end_record()


func _full_wires_and_lights() -> void:
	for index: int in range(content.world.utilityWires.size()):
		var wire: Array = content.world.utilityWires[index]
		_begin_record("wires", str(index), {"points": wire})
		var a: Vector3 = Content.to_world(Vector2(float(wire[0]), float(wire[1])), 5.7)
		var b: Vector3 = Content.to_world(Vector2(float(wire[2]), float(wire[3])), 5.7)
		var previous: Vector3 = a
		for step: int in range(1, 9):
			var fraction: float = step / 8.0
			var next: Vector3 = a.lerp(b, fraction) + Vector3(0, -sin(fraction * PI) * 0.7, 0)
			_beam(previous, next, 0.023, "39483a")
			previous = next
		_end_record()
	for raw: Variant in content.world.lights:
		var source: Dictionary = raw
		_begin_record("lights", str(source.id), source)
		var at: Vector3 = _point(source, false, 3.3)
		var channels: PackedStringArray = str(source.get("rgb", "208,176,112")).split(",")
		var color := Color(float(channels[0]) / 255.0, float(channels[1]) / 255.0, float(channels[2]) / 255.0)
		_box("source_light_metal_casing", Vector3(0.66, 0.14, 0.23), at, "576b57")
		_box("source_light_lens", Vector3(0.54, 0.05, 0.13), at + Vector3(0, -0.09, 0), color.to_html(false), false, Vector3.ZERO, 1.0)
		var lamp := OmniLight3D.new()
		lamp.name = "source_light_" + str(source.id)
		lamp.position = at + Vector3(0, -0.18, 0)
		lamp.light_color = color
		lamp.light_energy = float(source.get("power", 0.5))
		lamp.omni_range = maxf(2.8, float(source.get("radius", 100)) * 0.04)
		lamp.shadow_enabled = false
		add_child(lamp)
		lamps.append(lamp)
		_end_record()


func _full_boundaries() -> void:
	_owner = "boundary"
	for side: float in [WORLD_RECT.position.x - 0.25, WORLD_RECT.end.x + 0.25]:
		_box("boundary_concrete", Vector3(0.5, 3.1, WORLD_RECT.size.y + 1.0), Vector3(side, 1.55, WORLD_RECT.get_center().y), "697567", true)
	for edge: float in [WORLD_RECT.position.y - 0.25, WORLD_RECT.end.y + 0.25]:
		_box("boundary_concrete", Vector3(WORLD_RECT.size.x, 3.1, 0.5), Vector3(WORLD_RECT.get_center().x, 1.55, edge), "697567", true)
	# Disconnected roof silhouettes outside the physical boundary close long vistas.
	for index: int in range(23):
		var x: float = WORLD_RECT.position.x + 6 + index * 15.0
		var height: float = 5.0 + (index % 4) * 1.5
		for edge: float in [WORLD_RECT.position.y - 4.0, WORLD_RECT.end.y + 4.0]:
			_box("distant_brick_building", Vector3(10.0, height, 5.0), Vector3(x, height * 0.5, edge), BRICK_COLORS[index % 4])
			_box("distant_metal_roof", Vector3(10.5, 0.2, 5.4), Vector3(x, height, edge), "536859")


func _service(key: String, point: Vector3, kind: String, owner: String = "", reach: float = 2.3, source_point: Vector2 = Vector2.INF) -> void:
	_anchors[key] = point
	service_points[key] = {"target": Vector3(point.x, 1.25, point.z), "approach": Vector3.INF,
		"source_point": source_point if source_point.is_finite() else Content.to_source(point), "structure_id": owner, "kind": kind, "reach": reach}


func _register_services() -> void:
	_anchors["spawn"] = Content.body_position(content.initial.player)
	for raw: Variant in content.actors.day1:
		var actor: Dictionary = raw
		var owner: String = ""
		var legacy: int = int(actor.get("legacyStructureIndex", -1))
		if legacy >= 0: owner = "structures:" + _structure_id(legacy, content.world.structures[legacy])
		_service(str(actor.id), Content.body_position(actor), "actor", owner, 2.4)
	for raw: Variant in Content.definition("src/systems/progression_routes.js", "ROUTE_STOPS", []):
		var route: Dictionary = raw
		var point: Vector3 = _point(route)
		_route_points[str(route.id)] = point
		_service("route:" + str(route.id), point, "route", "", 2.30)
	for raw: Variant in Content.definition("src/systems/concessions.js", "SMOKE_SPOTS", []):
		var spot: Dictionary = raw
		_service("smoke:" + str(spot.id), _point(spot), "smoke")
		if str(spot.id) == "block": _anchors["block"] = _point(spot)
	for raw: Variant in Content.definition("src/systems/campaigns.js", "CLAIM_SITES", []):
		var site: Dictionary = raw
		for phase: String in ["survey", "sign"]:
			_service("claim:" + str(site.id) + ":" + phase, _point(site[phase]), "claim", "", 2.32)
	var quests: Dictionary = Content.definition("src/systems/campaigns.js", "QUEST_TARGETS", {})
	for id: String in quests:
		var target: Dictionary = quests[id]
		if target.has("x") and target.has("y"): _service("quest:" + id, _point(target), "quest")
	for raw: Variant in Content.definition("src/systems/campaigns.js", "KINGDOM_DOORS", []):
		var door: Dictionary = raw
		_service("kingdom:" + str(door.id), _point(door, true), "door", "", 1.76, Vector2(door.x+door.w*0.5,door.y+door.h*0.5))
	for raw: Variant in Content.definition("src/systems/campaigns.js", "KINGDOM_CLAN_LIST", []):
		var clan: Dictionary = raw
		for index: int in range(clan.marks.size()):
			_service("kingdom_mark:" + str(clan.id) + ":" + str(index), _point(clan.marks[index]), "kingdom", "", 2.32, Vector2(clan.marks[index].x,clan.marks[index].y))
		_service("kingdom_banner:" + str(clan.id), _point(clan.banner), "kingdom", "", 2.88, Vector2(clan.banner.x,clan.banner.y))
		_service("kingdom_boss:" + str(clan.id), _point(clan.boss), "combat")
	var emperor: Dictionary = Content.definition("src/systems/campaigns.js", "KINGDOM_EMPEROR", {})
	_service("kingdom_banner:throne", _point(emperor.banner), "kingdom", "", 2.88, Vector2(emperor.banner.x,emperor.banner.y))
	_service("kingdom_boss:throne", _point(emperor.boss), "combat")
	var office: Dictionary = Content.definition("src/systems/campaigns.js", "OFFICE_DOOR", {})
	_service("office", _point(office, true), "door", "", 1.76)
	# currentOfficeObjective/currentKingdomObjective name the desk10px north of
	# the door center. Both exact source points stay independently addressable.
	_service("office_objective", _point(office, true) + Vector3(0, 0, -0.4), "office", "", 1.76)
	var old_school: Dictionary = Content.definition("src/dialogue/vendors_places.js", "OLD_SCHOOL_DOOR", {})
	_service("oldschool", _point(old_school, true), "door", "", 1.76)
	var hideouts: Dictionary = Content.definition("src/systems/daily_hideouts.js", "HIDEOUT_DOORS", {})
	for id: String in hideouts:
		_service("hideout:" + id, _point(hideouts[id], true), "door", "", 1.6)
	for raw: Variant in Content.definition("src/data/props.js", "COPPER_SITES", []):
		var site: Dictionary = raw
		var rect: Rect2
		var owner: String
		if str(site.id) == "abandoned":
			rect = _rect(content.buildings[2]); owner = "structures:building_02"
		else:
			rect = _rect(site.anchor)
			owner = "structures:" + str(site.anchor.get("facadeId", ""))
			if str(site.id) == "rust_car":
				for index: int in range(content.props.size()):
					var prop: Dictionary = content.props[index]
					if str(prop.type) == "freight_car" and float(prop.x) == float(site.anchor.x): owner = "props:" + str(index)
		_service("copper:" + str(site.id), Vector3(rect.get_center().x, 0, rect.end.y + 0.03), "site", owner, 0.79)
		service_points["copper:"+str(site.id)].site_rect = rect
	for raw: Variant in Content.definition("src/data/props.js", "BREAKIN_SITES", []):
		var site: Dictionary = raw
		var rect: Rect2 = _rect(site.anchor)
		var owner: String = ""
		for index: int in range(content.props.size()):
			if str(content.props[index].get("variant", "")) == str(site.id): owner = "props:" + str(index)
		_service("breakin:" + str(site.id), Vector3(rect.get_center().x, 0, rect.end.y + 0.03), "site", owner, 0.79)
		service_points["breakin:"+str(site.id)].site_rect = rect
	for index: int in range(content.props.size()):
		var prop: Dictionary = content.props[index]
		if str(prop.type) in ["dumpster", "cart", "park_bench", "pay_phone"]:
			var point: Vector3 = _point(prop, prop.has("w") and prop.has("h"))
			var source_center := Vector2(prop.x,prop.y)
			if prop.has("w") and prop.has("h"): source_center += Vector2(prop.w,prop.h)*0.5
			var source_reach: float = {"dumpster":44.0,"park_bench":50.0,"pay_phone":38.0}.get(str(prop.type),47.5)
			_service("prop:" + str(index), point, str(prop.type), "props:" + str(index), source_reach*Content.METRES_PER_PIXEL,source_center)
	for index: int in range(content.interactiveProps.size()):
		var prop: Dictionary = content.interactiveProps[index]
		_service("interactive:" + str(index), _point(prop), str(prop.type), "interactiveProps:" + str(prop.get("id", index)), 1.9)
	for raw: Variant in content.initial.cashPiles:
		var cash: Dictionary = raw
		_service("cash:" + str(cash.id), _point(cash), "cash", "", 0.56)
	# These authored points lie on a visible object surface. The ray must land on
	# that owner, never pass an unrelated wall. Canonical source_point stays fixed.
	var contact_owners: Dictionary = {"route:train_signal": "decor:8", "route:cart_barrier": "props:143",
		"kingdom_mark:cart_cavalry:0": "props:143", "cash:cp_6": "structures:building_02", "cash:cp_25": "structures:building_13"}
	for key: String in contact_owners:
		service_points[key].structure_id = contact_owners[key]


func _resolve_services() -> void:
	for key: String in service_points:
		var service: Dictionary = service_points[key]
		var target: Vector3 = service.target
		var owner: String = str(service.structure_id) if str(service.kind) != "actor" else ""
		var reach: float = float(service.reach)
		var radii: Array[float] = [0.52, 0.64, 0.9, 1.25, 1.65, 2.05, 2.25]
		for radius: float in radii:
			if radius >= reach: continue
			for step: int in range(16):
				var angle: float = PI * 0.5 + step * TAU / 16.0
				var candidate := Vector3(target.x + cos(angle) * radius, 0.06, target.z + sin(angle) * radius)
				if _actor_approach_clear(candidate) and is_clear_position(candidate, WALK_RADIUS + 0.006) and sight_clear(candidate + Vector3(0, 1.45, 0), target, owner):
					service.approach = candidate
					break
			if service.approach != Vector3.INF: break
		if service.approach == Vector3.INF:
			push_warning("Full world service has no clear physical approach: " + key)


func _actor_approach_clear(point: Vector3) -> bool:
	var center: Vector2 = Content.to_source(point)
	var initial: Dictionary = content.initial.player
	var body := {"id":"player","x":center.x-initial.w*0.5,"y":center.y-initial.h*0.5,"w":initial.w,"h":initial.h}
	for actor: Dictionary in content.actors.day1:
		if not actor.get("dead",false) and BodyContact.penetrating(body,Vector2(body.x,body.y),actor): return false
	return true


func sight_clear(from: Vector3, to: Vector3, ignored_owner: String = "") -> bool:
	for obstacle: Dictionary in _obstacles:
		if not ignored_owner.is_empty() and str(obstacle.owner) == ignored_owner: continue
		var bounds: AABB = obstacle.bounds
		var low: float = 0.0
		var high: float = 1.0
		var delta: Vector3 = to - from
		var intersects: bool = true
		for axis: int in range(3):
			if absf(delta[axis]) < 0.000001:
				if from[axis] < bounds.position[axis] or from[axis] > bounds.end[axis]: intersects = false; break
			else:
				var a: float = (bounds.position[axis] - from[axis]) / delta[axis]
				var b: float = (bounds.end[axis] - from[axis]) / delta[axis]
				low = maxf(low, minf(a, b)); high = minf(high, maxf(a, b))
				if low > high: intersects = false; break
		if intersects: return false
	return true


func segment_clear(from: Vector3, to: Vector3, clearance: float = WALK_RADIUS) -> bool:
	if not is_clear_position(from, clearance) or not is_clear_position(to, clearance): return false
	var a := Vector2(from.x, from.z)
	var delta := Vector2(to.x - from.x, to.z - from.z)
	for index: int in _segment_candidates(from, to, clearance):
		var footprint: Rect2 = solid_footprints[index]
		var rect: Rect2 = footprint.grow(clearance)
		var low: float = 0.0
		var high: float = 1.0
		var intersects: bool = true
		for axis: int in range(2):
			if absf(delta[axis]) < 0.000001:
				if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: intersects = false; break
			else:
				var first: float = (rect.position[axis] - a[axis]) / delta[axis]
				var second: float = (rect.end[axis] - a[axis]) / delta[axis]
				low = maxf(low, minf(first, second)); high = minf(high, maxf(first, second))
				if low > high: intersects = false; break
		if intersects: return false
	return true


func _segment_candidates(from: Vector3, to: Vector3, clearance: float) -> Array[int]:
	# Half-cell samples plus neighboring cells cover the entire swept segment.
	# Only the candidate search is approximate; every collision test remains exact.
	var indices: Dictionary = {}
	var cells: Dictionary = {}
	var steps: int = maxi(1, ceili(from.distance_to(to) / (SPATIAL_CELL * 0.5)))
	var radius: int = maxi(1, ceili(clearance / SPATIAL_CELL))
	for step: int in range(steps + 1):
		var point: Vector3 = from.lerp(to, float(step) / steps)
		var center := Vector2i(floori(point.x / SPATIAL_CELL), floori(point.z / SPATIAL_CELL))
		for y: int in range(center.y - radius, center.y + radius + 1):
			for x: int in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if cells.has(cell): continue
				cells[cell] = true
				for index: int in _footprint_cells.get(cell, []): indices[index] = true
	var result: Array[int] = []
	for index: int in indices: result.append(index)
	return result


func _prepare_grid(clearance: float) -> void:
	if is_equal_approx(_grid_clearance, clearance) and not _blocked.is_empty(): return
	_grid_clearance = clearance
	_blocked.resize(GRID_WIDTH * GRID_HEIGHT)
	_blocked.fill(0)
	for footprint: Rect2 in solid_footprints:
		var rect: Rect2 = footprint.grow(clearance + 0.006)
		var minimum := Vector2i(maxi(0, ceili((rect.position.x - WORLD_RECT.position.x) / GRID_STEP - 0.5)), maxi(0, ceili((rect.position.y - WORLD_RECT.position.y) / GRID_STEP - 0.5)))
		var maximum := Vector2i(mini(GRID_WIDTH - 1, floori((rect.end.x - WORLD_RECT.position.x) / GRID_STEP - 0.5)), mini(GRID_HEIGHT - 1, floori((rect.end.y - WORLD_RECT.position.y) / GRID_STEP - 0.5)))
		for y: int in range(minimum.y, maximum.y + 1):
			for x: int in range(minimum.x, maximum.x + 1):
				_blocked[y * GRID_WIDTH + x] = 1
	var edge_cells: int = ceili(clearance / GRID_STEP)
	for y: int in range(GRID_HEIGHT):
		for x: int in range(edge_cells):
			_blocked[y * GRID_WIDTH + x] = 1
			_blocked[y * GRID_WIDTH + GRID_WIDTH - 1 - x] = 1
	for y: int in range(edge_cells):
		for x: int in range(GRID_WIDTH):
			_blocked[y * GRID_WIDTH + x] = 1
			_blocked[(GRID_HEIGHT - 1 - y) * GRID_WIDTH + x] = 1


func _grid_point(index: int) -> Vector3:
	return Vector3(WORLD_RECT.position.x + (index % GRID_WIDTH + 0.5) * GRID_STEP, 0.06,
		WORLD_RECT.position.y + (floori(float(index) / GRID_WIDTH) + 0.5) * GRID_STEP)


func _near_grid(point: Vector3, clearance: float) -> int:
	var center := Vector2i(floori((point.x - WORLD_RECT.position.x) / GRID_STEP), floori((point.z - WORLD_RECT.position.y) / GRID_STEP))
	var best: int = -1
	var distance: float = INF
	for y: int in range(center.y - 3, center.y + 4):
		for x: int in range(center.x - 3, center.x + 4):
			if x < 0 or y < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT: continue
			var index: int = y * GRID_WIDTH + x
			if _blocked[index] != 0: continue
			var candidate: Vector3 = _grid_point(index)
			var squared: float = point.distance_squared_to(candidate)
			if squared < distance and segment_clear(point, candidate, clearance):
				best = index; distance = squared
	return best


func _heap_push(heap: Array[Vector2], item: Vector2) -> void:
	heap.append(item)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = int((index - 1) / 2.0)
		if heap[parent].x <= item.x: break
		heap[index] = heap[parent]
		index = parent
	heap[index] = item


func _heap_pop(heap: Array[Vector2]) -> Vector2:
	var result: Vector2 = heap[0]
	var last: Vector2 = heap.pop_back()
	if heap.is_empty(): return result
	var index: int = 0
	while index * 2 + 1 < heap.size():
		var child: int = index * 2 + 1
		if child + 1 < heap.size() and heap[child + 1].x < heap[child].x: child += 1
		if last.x <= heap[child].x: break
		heap[index] = heap[child]; index = child
	heap[index] = last
	return result


func _heuristic(index: int, target: int) -> float:
	var dx: int = absi(index % GRID_WIDTH - target % GRID_WIDTH)
	var dy: int = absi(floori(float(index) / GRID_WIDTH) - floori(float(target) / GRID_WIDTH))
	return float(maxi(dx, dy)) + 0.41421356 * mini(dx, dy)


func find_route(from: Vector3, to: Vector3, clearance: float = WALK_RADIUS) -> PackedVector3Array:
	var started: int = Time.get_ticks_msec()
	last_route_metrics = {"expanded": 0, "milliseconds": 0, "status": "blocked"}
	if not is_clear_position(from, clearance) or not is_clear_position(to, clearance): return PackedVector3Array()
	if segment_clear(from, to, clearance):
		last_route_metrics.status = "direct"
		return PackedVector3Array([from, to])
	_prepare_grid(clearance)
	var first: int = _near_grid(from, clearance)
	var last: int = _near_grid(to, clearance)
	if first < 0 or last < 0: return PackedVector3Array()
	var costs := PackedFloat32Array()
	var parents := PackedInt32Array()
	var closed := PackedByteArray()
	costs.resize(_blocked.size()); costs.fill(INF)
	parents.resize(_blocked.size()); parents.fill(-1)
	closed.resize(_blocked.size()); closed.fill(0)
	var heap: Array[Vector2] = []
	costs[first] = 0.0
	_heap_push(heap, Vector2(_heuristic(first, last), first))
	var expanded: int = 0
	var found: bool = false
	while not heap.is_empty() and expanded < MAX_ROUTE_EXPANSIONS:
		var current: int = int(_heap_pop(heap).y)
		if closed[current] != 0: continue
		closed[current] = 1
		expanded += 1
		if current == last: found = true; break
		var cx: int = current % GRID_WIDTH
		var cy: int = floori(float(current) / GRID_WIDTH)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if dx == 0 and dy == 0: continue
				var nx: int = cx + dx
				var ny: int = cy + dy
				if nx < 0 or ny < 0 or nx >= GRID_WIDTH or ny >= GRID_HEIGHT: continue
				var next: int = ny * GRID_WIDTH + nx
				if _blocked[next] != 0 or closed[next] != 0: continue
				if dx != 0 and dy != 0 and (_blocked[cy * GRID_WIDTH + nx] != 0 or _blocked[ny * GRID_WIDTH + cx] != 0): continue
				var score: float = costs[current] + (1.41421356 if dx != 0 and dy != 0 else 1.0)
				if score >= costs[next]: continue
				costs[next] = score; parents[next] = current
				_heap_push(heap, Vector2(score + _heuristic(next, last), next))
	last_route_metrics = {"expanded": expanded, "milliseconds": Time.get_ticks_msec() - started, "status": "found" if found else "budget" if expanded >= MAX_ROUTE_EXPANSIONS else "unreachable"}
	if not found: return PackedVector3Array()
	var reverse: Array[int] = []
	var cursor: int = last
	while cursor >= 0:
		reverse.append(cursor)
		if cursor == first: break
		cursor = parents[cursor]
	reverse.reverse()
	var raw := PackedVector3Array([from])
	for index: int in reverse: raw.append(_grid_point(index))
	raw.append(to)
	var route := PackedVector3Array([from])
	var start: int = 0
	while start < raw.size() - 1:
		var furthest: int = start + 1
		for probe: int in range(raw.size() - 1, start + 1, -1):
			if segment_clear(raw[start], raw[probe], clearance): furthest = probe; break
		if not segment_clear(raw[start], raw[furthest], clearance):
			last_route_metrics.status = "clearance_failure"
			return PackedVector3Array()
		route.append(raw[furthest]); start = furthest
	var refined: PackedVector3Array = _visibility_refine(_tighten_route(route, clearance), clearance)
	last_route_metrics.milliseconds = Time.get_ticks_msec() - started
	return refined


func _tighten_route(route: PackedVector3Array, clearance: float) -> PackedVector3Array:
	# Grid steps choose a safe corridor. Move its bends onto nearby physical
	# Minkowski corners so quantization is not charged to a timed walking route.
	for pass_index: int in range(3):
		for index: int in range(1, route.size() - 1):
			var previous: Vector3 = route[index - 1]
			var next: Vector3 = route[index + 1]
			var best: Vector3 = route[index]
			var best_length: float = previous.distance_to(best) + best.distance_to(next)
			for footprint: Rect2 in solid_footprints:
				if not footprint.grow(clearance + 1.4).has_point(Vector2(best.x, best.z)): continue
				var rect: Rect2 = footprint.grow(clearance + 0.012)
				for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
					var candidate := Vector3(corner.x, 0.06, corner.y)
					var length: float = previous.distance_to(candidate) + candidate.distance_to(next)
					if length + 0.0001 < best_length and segment_clear(previous, candidate, clearance) and segment_clear(candidate, next, clearance):
						best = candidate; best_length = length
			route[index] = best
	return route


func _path_length(route: PackedVector3Array) -> float:
	var total: float = 0.0
	for index: int in range(route.size() - 1): total += route[index].distance_to(route[index + 1])
	return total


func _visibility_refine(fallback: PackedVector3Array, clearance: float) -> PackedVector3Array:
	if fallback.size() < 3: return fallback
	var from: Vector3 = fallback[0]
	var to: Vector3 = fallback[-1]
	var upper_bound: float = _path_length(fallback)
	if upper_bound - from.distance_to(to) < 0.05: return fallback
	var candidates: Array[Dictionary] = []
	var unique: Dictionary = {}
	# Any bend in a shorter path must lie inside this distance ellipse. We only
	# consider exposed corners of the actual expanded physical rectangles.
	for footprint: Rect2 in solid_footprints:
		var rect: Rect2 = footprint.grow(clearance + 0.012)
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var point := Vector3(corner.x, 0.06, corner.y)
			var lower_bound: float = from.distance_to(point) + point.distance_to(to)
			if lower_bound >= upper_bound - 0.0001: continue
			var key := Vector2i(roundi(point.x * 1000.0), roundi(point.z * 1000.0))
			if unique.has(key) or not is_clear_position(point, clearance): continue
			unique[key] = true
			candidates.append({"point": point, "bound": lower_bound})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.bound) < float(b.bound))
	var nodes: Array[Vector3] = [from, to]
	for point: Vector3 in fallback:
		if point != from and point != to: nodes.append(point)
	for candidate: Dictionary in candidates:
		if nodes.size() >= MAX_VISIBILITY_NODES: break
		nodes.append(candidate.point)
	var costs := PackedFloat32Array()
	var previous := PackedInt32Array()
	var closed := PackedByteArray()
	costs.resize(nodes.size()); costs.fill(INF); costs[0] = 0.0
	previous.resize(nodes.size()); previous.fill(-1)
	closed.resize(nodes.size()); closed.fill(0)
	var heap: Array[Vector2] = []
	_heap_push(heap, Vector2(from.distance_to(to), 0))
	var visibility_cache: Dictionary = {}
	while not heap.is_empty():
		var current: int = int(_heap_pop(heap).y)
		if closed[current] != 0: continue
		closed[current] = 1
		if current == 1: break
		for next: int in range(1, nodes.size()):
			if closed[next] != 0: continue
			var score: float = costs[current] + nodes[current].distance_to(nodes[next])
			if score >= costs[next] or score + nodes[next].distance_to(to) >= upper_bound: continue
			var key: int = mini(current, next) * MAX_VISIBILITY_NODES + maxi(current, next)
			if not visibility_cache.has(key): visibility_cache[key] = segment_clear(nodes[current], nodes[next], clearance)
			if not bool(visibility_cache[key]): continue
			costs[next] = score; previous[next] = current
			_heap_push(heap, Vector2(score + nodes[next].distance_to(to), next))
	last_route_metrics["visibility_nodes"] = nodes.size()
	last_route_metrics["visibility_tests"] = visibility_cache.size()
	if previous[1] < 0: return fallback
	var reverse := PackedVector3Array()
	var cursor: int = 1
	while cursor >= 0:
		reverse.append(nodes[cursor])
		cursor = previous[cursor]
	reverse.reverse()
	return reverse if _path_length(reverse) < upper_bound else fallback
