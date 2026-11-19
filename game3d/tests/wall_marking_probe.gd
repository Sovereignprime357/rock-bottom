extends SceneTree
## Native visual evidence of original source text on actual production facades.
const View = preload("res://scripts/wall_marking_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var world: World
var view: View
var camera: Camera3D
var surfaces: Array = []
var output_dir: String
var captures: Array[Dictionary] = []
var failure: bool = false

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failure = true; push_error("Wall marking capture: "+label)
	return ok
func _output() -> String:
	var result: String = ProjectSettings.globalize_path("res://../.build/full-port/refined-native/wall-markings")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): result = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): result = args[index+1]
	return ProjectSettings.globalize_path(result) if result.begins_with("res://") or result.begins_with("user://") else result
func _face(row: Dictionary) -> Dictionary:
	for entry: Dictionary in surfaces:
		if entry.building_index == row.building_index: return entry.faces[row.face]
	return {}
func _frame(row: Dictionary,street: bool) -> void:
	var face: Dictionary = _face(row)
	var center: Vector2 = row.bounds.get_center()
	var target: Vector3 = face.transform*Vector3(center.x,center.y,0)
	var distance: float = maxf(2.0,maxf(row.bounds.size.x*0.82,row.bounds.size.y*1.25))
	if street:
		distance = maxf(5.5,distance*1.35)
		camera.position = target+face.transform.basis.z*distance+face.transform.basis.x*distance*0.28
		camera.position.y = 1.69
	else: camera.position = target+face.transform.basis.z*distance
	camera.look_at(target,Vector3.UP)
func _capture(label: String,row: Dictionary,street: bool = false,night: bool = false) -> void:
	if failure: return
	world.set_day_time(180.0 if night else 84.0); _frame(row,street)
	var content_before: Dictionary = Content.load_content().initial.state.duplicate(true)
	await process_frame; await physics_frame; await RenderingServer.frame_post_draw
	_require(Content.load_content().initial.state == content_before,"native draw preserves source data")
	var face: Dictionary = _face(row); var center: Vector2 = row.bounds.get_center()
	var target: Vector3 = face.transform*Vector3(center.x,center.y,0)
	var holder: Node3D = view.get_node_or_null(row.kind+"_"+str(row.index))
	var glyph_bounds_valid: bool = true
	if holder != null:
		var inverse: Transform3D = (face.transform as Transform3D).affine_inverse()
		for child: Node in holder.get_children():
			if not child is GeometryInstance3D: continue
			var bounds: AABB = child.get_aabb()
			glyph_bounds_valid = glyph_bounds_valid and bounds.size.length() > 0.00001
			for corner: int in range(8):
				var at: Vector3 = inverse*child.global_transform*bounds.get_endpoint(corner)
				glyph_bounds_valid = glyph_bounds_valid and at.is_finite() and View._contains(row.bounds.grow(0.0005),Rect2(Vector2(at.x,at.y),Vector2.ZERO))
		_require(glyph_bounds_valid,"actual deferred glyph/paper bounds stay on the clear wall envelope")
	var query := PhysicsRayQueryParameters3D.create(target+face.transform.basis.z*0.22,target-face.transform.basis.z*0.38,1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	_require(not hit.is_empty(),"marking has an actual authored wall directly behind it")
	var wall_outset: float = (target-(hit.position as Vector3)).dot(face.transform.basis.z) if not hit.is_empty() else INF
	if row.face == "bottom":
		_require(wall_outset >= 0.004 and wall_outset <= 0.008,"front anchor is against the flat wall, not hovering beyond piers")
		var bays: int = maxi(1,int(float(face.span.x)/2.8))
		for bay: int in range(bays):
			var pier := Rect2(float(bay)*float(face.span.x)/float(bays)-0.10,0,0.20,float(face.span.y))
			_require(not row.bounds.intersects(pier),"captured complete envelope clears projecting facade pier")
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if not _require(error == OK,"write "+label): return
	var info: Dictionary = view.inspect()
	captures.append({"file":label+".png","source_record":row.source,"kind":row.kind,"face":row.face,"building_index":row.building_index,"bounds":row.bounds,"scale":row.scale,"camera":camera.global_transform,"framing":"street" if street else "close","lighting":"night" if night else "day","wall_hit":not hit.is_empty(),"anchor_wall_outset":wall_outset,"actual_geometry_contained":glyph_bounds_valid,"requested":info.requested,"placed":info.placed,"rejected":info.rejected})
func _pick(kind: String,face: String) -> Dictionary:
	for row: Dictionary in view.inspect().records:
		if row.kind == kind and row.face == face: return row
	return {}
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Wall marking evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); root.add_child(world); world.build(); surfaces = world.wall_marking_surfaces()
	camera = Camera3D.new(); camera.fov = 78; camera.near = 0.06; camera.far = 180; world.add_child(camera); camera.current = true
	view = View.create(); world.add_child(view)
	var initial: Dictionary = Content.load_content().initial.state
	var snapshot := {"graffiti":initial.graffiti.duplicate(true),"posters":initial.posters.duplicate(true),"revision":1}
	_require(view.sync(snapshot,surfaces),"all saved initial records accepted")
	_require(view.inspect().placed == 23 and view.inspect().rejected.is_empty(),"all23 captured source records placed")
	await physics_frame; await physics_frame
	for face: String in ["bottom","leftside","rightside"]:
		var row: Dictionary = _pick("graffiti",face)
		if not _require(not row.is_empty(),"saved graffiti has "+face): continue
		await _capture("saved_graffiti_"+face+"_close",row)
		await _capture("saved_graffiti_"+face+"_street",row,true)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/wall_markings_reference.json"))
	var poster_targets: Dictionary = {}
	for case: Dictionary in fixture.cases:
		if not case.id.begins_with("poster_wall_"): continue
		var state: Dictionary = case.steps[0].expected
		view.sync({"graffiti":[],"posters":state.posters,"revision":2},surfaces)
		var rows: Array = view.inspect().records
		if not _require(not rows.is_empty() and view.inspect().rejected.is_empty(),"source poster wall sample placed"): continue
		var row: Dictionary = rows[0]; poster_targets[row.face] = state.posters.duplicate(true)
		await _capture("source_poster_"+row.face+"_close",row)
		await _capture("source_poster_"+row.face+"_street",row,true)
	_require(poster_targets.size() == 3,"all three source poster wall choices captured")
	view.sync(snapshot,surfaces)
	for faction: String in ["street","scrap","spiritual"]:
		var selected: Dictionary = {}
		for row: Dictionary in view.inspect().records:
			if row.kind == "poster" and row.source.faction == faction: selected = row; break
		if _require(not selected.is_empty(),"saved poster faction "+faction): await _capture("saved_poster_"+faction,selected)
	var graffiti: Dictionary = _pick("graffiti","bottom"); var poster: Dictionary = view.inspect().records[-1]
	await _capture("saved_graffiti_night",graffiti,false,true)
	await _capture("saved_poster_night",poster,false,true)
	var office: Dictionary = Content.load_content().buildings[16]
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/courier_canvas_metrics.json"))
	var longest: Dictionary = {}
	for line: Dictionary in metrics.entries:
		if line.ceil <= office.w-12 and (longest.is_empty() or line.ceil > longest.ceil): longest = line
	var hard_tag := {"x":office.x+6,"y":office.y+office.h-16,"text":longest.text,"sz":longest.size,"textW":longest.ceil,"wallX":office.x+6,"wallW":office.w-12,"wallKind":"bottom","layoutV":2,"col":initial.graffiti[0].col,"rot":0.09}
	view.sync({"graffiti":[hard_tag],"posters":[],"revision":3},surfaces)
	var hard_rows: Array = view.inspect().records
	if _require(hard_rows.size() == 1 and view.inspect().rejected.is_empty(),"longest eligible source sentence fits a narrow facade bay"):
		await _capture("longest_front_pier_clear_close",hard_rows[0])
		await _capture("longest_front_pier_clear_oblique",hard_rows[0],true)
	# Replaced saved fields clear every old node and retain the empty source layout.
	view.sync({"graffiti":[],"posters":[],"revision":3},surfaces)
	_require(view.get_child_count() == 0,"empty source fields leave no stale marks")
	await _capture("cleared_saved_wall",graffiti,true)
	_require(captures.size() == 20,"all20 wall orientations/factions/lighting/clear/pier-counterexample views captured")
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if _require(file != null,"write native manifest"):
		file.store_string(JSON.stringify({"count":captures.size(),"captures":captures,"source_metrics":"res://data/courier_canvas_metrics.json","scope":"Production facade/lighting projection of unchanged source records. Exact RNG/lifecycle is covered by source/model gates; no gameplay or overall performance acceptance claimed."},"\t")); file.close()
	world.free(); await process_frame
	if failure: print("3D WALL MARKING PROBE: FAIL"); quit(1)
	else: print("3D WALL MARKING PROBE: PASS (%d captures; %s)"%[captures.size(),output_dir]); quit(0)
