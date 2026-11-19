extends SceneTree
## Native visual evidence only. Real production lighting; no collection or gameplay ticks.
const View = preload("res://scripts/find_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const State = preload("res://scripts/game_state.gd")
const Utilities = preload("res://scripts/neighborhood_utilities.gd")
const Content = preload("res://scripts/content_catalog.gd")
const POINT := Vector2(1050,840)
var world: World
var game: State
var utilities: Utilities
var camera: Camera3D
var cash: View
var crown: View
var row_views: Array[View] = []
var output_dir: String
var captures: Array[Dictionary] = []
var failure: bool = false
var vertex_cache: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failure = true; push_error("Find capture: "+label)
	return ok
func _output() -> String:
	var result: String = ProjectSettings.globalize_path("res://../.build/full-port/p05d")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): result = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): result = args[index+1]
	return ProjectSettings.globalize_path(result) if result.begins_with("res://") or result.begins_with("user://") else result
func _record(kind: String,point: Vector2 = POINT) -> Dictionary:
	var result := {"id":"find_probe","x":point.x,"y":point.y,"amt":10,"collected":false}
	if kind == "propane_torch": result.tool = kind; result.amt = 0
	elif kind == "priest_collar": result.equip = kind; result.amt = 0
	return result
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if vertex_cache.has(mesh.get_instance_id()): return vertex_cache[mesh.get_instance_id()]
	var result := PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
	vertex_cache[mesh.get_instance_id()] = result; return result
func _stats(view: View) -> Dictionary:
	var result := {"source_id":view.source_id,"kind":view.presentation_kind,"visible":view.is_visible_in_tree(),"source_point":Content.to_source(view.global_position),"origin":view.global_position,"meshes":0,"surfaces":0,"triangles":0,"vertices":0,"bounds":AABB(),"resources":[]}
	var started: bool = false; var bounds := AABB()
	for node: Node in view.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null: continue
		result.meshes += 1; result.resources.append(mesh.mesh.get_instance_id())
		for point: Vector3 in _vertices(mesh.mesh):
			var at: Vector3 = mesh.global_transform*point
			bounds = bounds.expand(at) if started else AABB(at,Vector3.ZERO); started = true
			result.vertices += 1
		for surface: int in range(mesh.mesh.get_surface_count()):
			result.surfaces += 1
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty(): count = arrays[Mesh.ARRAY_INDEX].size()
			result.triangles += count/3
	result.bounds = bounds; return result
func _look(point: Vector2,framing: String) -> void:
	var at: Vector3 = Content.to_world(point)
	match framing:
		"close": camera.position = at+Vector3(0.55,0.56,0.62)
		"standing_2m": camera.position = at+Vector3(0,1.69,2.0)
		"far_5m": camera.position = at+Vector3(0,1.69,5.0)
		"row": camera.position = at+Vector3(0,1.69,2.7)
	camera.look_at(at+Vector3(0,0.12,0),Vector3.UP)
	var center: Vector2 = Content.to_source(camera.position)
	game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
func _project(kind: String,framing: String,night: bool = false) -> Dictionary:
	_look(POINT,framing); world.set_day_time(180.0 if night else 84.0)
	game.s.tweakerT = 1000.0 if framing == "far_5m" else 0.0
	var record: Dictionary = _record(kind)
	if kind == "crown":
		cash.project_cash(_record("money"),false)
		_require(crown.project_crown(record) and crown.visible,"project separate crown")
	else:
		crown.project_crown({"x":POINT.x,"y":POINT.y,"collected":true})
		var shown: bool = utilities.cash_visible(record)
		_require(cash.project_cash(record,shown) and cash.visible,"project visible "+kind+" at "+framing)
	return {"record":record,"framing":framing,"source_vision_ms":game.s.tweakerT,"lighting":"night" if night else "day"}
func _capture(label: String,context: Dictionary) -> void:
	if failure: return
	var before := {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"rng":game.rng_seed,"events":game.events.duplicate(true)}
	await process_frame; await physics_frame; await RenderingServer.frame_post_draw
	_require({"p":game.p,"s":game.s,"rng":game.rng_seed,"events":game.events} == before,"render frame owns no gameplay clock/RNG/events")
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if not _require(error == OK,"write "+label): return
	var entries: Array[Dictionary] = [_stats(cash),_stats(crown)]
	for view: View in row_views: entries.append(_stats(view))
	captures.append({"file":label+".png","camera":camera.global_transform,"fov":camera.fov,"near":camera.near,"context":context.duplicate(true),"views":entries})
func _mixed_row() -> void:
	cash.project_cash(_record("money"),false); crown.project_crown({"x":POINT.x,"y":POINT.y,"collected":true})
	world.set_day_time(84.0); _look(POINT,"row"); game.s.tweakerT = 1000.0
	var records: Array[Dictionary] = []
	var kinds: Array[String] = ["money","propane_torch","priest_collar","crown"]
	for index: int in range(kinds.size()):
		var kind: String = kinds[index]; var point: Vector2 = POINT+Vector2((float(index)-1.5)*15.0,0)
		var view: View = View.create_crown() if kind == "crown" else View.create_cash(); world.add_child(view); row_views.append(view)
		var record: Dictionary = _record(kind,point); record.id = "find_row_%d"%index; records.append(record)
		_require(view.project_crown(record) if kind == "crown" else view.project_cash(record,utilities.cash_visible(record)),"mixed row projection")
	await _capture("mixed_source_row",{"records":records,"source_vision_ms":game.s.tweakerT,"framing":"row","lighting":"day"})
	for index: int in range(row_views.size()):
		if kinds[index] == "crown": row_views[index].project_crown({"x":records[index].x,"y":records[index].y})
		else: row_views[index].project_cash(records[index],false)
	_require(row_views.all(func(view: View): return not view.visible),"supplied-hidden cash and default-collected crown show no stale art")
	await _capture("hidden_source_row",{"records":records,"supplied_cash_visibility":false,"crown_collected_omitted":true,"framing":"row","lighting":"day"})
	for index: int in range(row_views.size()):
		records[index].collected = true
		if kinds[index] == "crown": row_views[index].project_crown(records[index])
		else: row_views[index].project_cash(records[index],true)
	_require(row_views.all(func(view: View): return not view.visible),"collected records dominate caller visibility")
	await _capture("collected_source_row",{"records":records,"supplied_cash_visibility":true,"framing":"row","lighting":"day"})
	for view: View in row_views: view.free()
	row_views.clear()
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Find evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); root.add_child(world); world.build(); world.set_day_time(84.0)
	game = State.new(); game.npcs.clear(); utilities = Utilities.new(game,null)
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	cash = View.create_cash(); crown = View.create_crown(); world.add_child(cash); world.add_child(crown)
	await physics_frame; await physics_frame
	for kind: String in ["money","propane_torch","priest_collar","crown"]:
		for framing: String in ["close","standing_2m","far_5m"]:
			var context: Dictionary = _project(kind,framing)
			await _capture(kind+"_"+framing,context)
	await _mixed_row()
	var context: Dictionary = _project("money","standing_2m")
	var changed: Dictionary = _record("propane_torch"); var old_id: String = cash.source_id
	_require(cash.project_cash(changed,utilities.cash_visible(changed)) and cash.source_id == old_id and cash.presentation_kind == "propane_torch","same-ID source tag change replaces old money art")
	context.record = changed; context.previous_kind = "money"; context.same_source_id = old_id
	await _capture("same_id_money_to_torch",context)
	context = _project("propane_torch","standing_2m",true); await _capture("night_torch",context)
	context = _project("crown","standing_2m",true); await _capture("night_crown",context)
	_require(captures.size() == 18,"all18 original pickup views captured")
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if _require(file != null,"write capture manifest"):
		file.store_string(JSON.stringify({"count":captures.size(),"camera":{"fov":78,"near":0.06,"size":[1280,720]},"captures":captures,"scope":"Original cached pickup presentation in production world light. Far money uses explicit source vision. No collection, Runtime performance or audible/gameplay acceptance is claimed."},"\t")); file.close()
	world.free(); utilities = null; game = null
	if failure: print("3D FIND VIEW PROBE: FAIL"); quit(1)
	else: print("3D FIND VIEW PROBE: PASS (%d captures; %s)"%[captures.size(),output_dir]); quit(0)
