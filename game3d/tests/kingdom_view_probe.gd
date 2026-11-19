extends SceneTree
## Staged visual fixtures in the actual full world; no earned seal/fight claim.
const View = preload("res://scripts/kingdom_world_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Weather = preload("res://scripts/weather_presentation.gd")
var world: World
var view: View
var weather: Weather
var camera: Camera3D
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var snapshot: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failures.append(label); push_error("Kingdom view probe: "+label)
	return ok

func _output() -> String:
	var result: String = ProjectSettings.globalize_path("res://../.build/full-port/kingdom-view")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): result = arg.trim_prefix("--output=")
	return ProjectSettings.globalize_path(result) if result.begins_with("res://") else result

func _clear_ray(from: Vector3,to: Vector3) -> bool:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty()

func _points(group: Node3D,banner: bool) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if banner:
		for x: float in [-0.55,0.0,0.55]:
			for y: float in [1.01,1.34,1.67]: points.append(group.global_transform*Vector3(x,y,0.05))
	else:
		points.append(group.global_transform*Vector3(0,0,0.007))
		for x: float in [-0.38,0.38]:
			for y: float in [-0.38,0.38]: points.append(group.global_transform*Vector3(x,y,0.007))
	return points

func _place(group_id: String) -> bool:
	var group: Node3D = view._groups[group_id]
	var banner: bool = group_id.begins_with("banner_")
	var fence: bool = group_id.begins_with("mark_cart_cavalry_0_")
	var angles: Array[float] = []
	angles.assign([PI,PI-0.3,PI+0.3] if fence else [0.0,-0.35,0.35,-0.7,0.7,PI,PI-0.35,PI+0.35])
	var at: Vector3 = group.global_position
	var target: Vector3 = at+Vector3.UP*1.05 if banner else at
	var radii: Array[float] = []
	radii.assign([3.2,2.8,3.6] if banner else [2.0,2.4,1.6])
	for radius: float in radii:
		for angle: float in angles:
			var eye := Vector3(at.x+sin(angle)*radius,1.65,at.z+cos(angle)*radius)
			if not world.is_clear_position(eye,0.25): continue
			var clear: bool = true
			for point: Vector3 in _points(group,banner): clear = clear and _clear_ray(eye,point)
			if not clear: continue
			camera.position = eye; camera.look_at(target); return true
	return false

func _screen_bounds(group: Node3D) -> Rect2:
	var result := Rect2(); var started: bool = false
	for child: Node in group.find_children("*","GeometryInstance3D",true,false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if not geometry.is_visible_in_tree(): continue
		for index: int in range(8):
			var point: Vector3 = geometry.global_transform*geometry.get_aabb().get_endpoint(index)
			if camera.is_position_behind(point): return Rect2(Vector2(-10000,-10000),Vector2.ONE)
			var screen: Vector2 = camera.unproject_position(point)
			if not started: result = Rect2(screen,Vector2.ZERO); started = true
			else: result = result.expand(screen)
	return result

func _capture(id: String,required: String,night: bool = false) -> void:
	var before: Dictionary = snapshot.duplicate(true)
	view.sync(snapshot)
	if not _require(_place(required),"actual clear approach "+id): return
	weather.sync({"dayTime":0.05 if night else 0.5,"weather":"clear","office_generator":false,"geometry_revision":0},float(Time.get_ticks_msec()))
	await physics_frame; await process_frame; await RenderingServer.frame_post_draw
	var report: Dictionary = view.inspect()
	var group: Node3D = view._groups[required]
	var projected: Rect2 = _screen_bounds(group)
	_require(report.visible.has(required),"actual visible variant "+id)
	_require(Rect2(Vector2.ZERO,Vector2(root.size)).grow(-8).encloses(projected) and projected.size.x > 8 and projected.size.y > 8,"complete readable geometry in viewport "+id)
	_require(world.is_clear_position(camera.position,0.25),"camera placement "+id)
	for point: Vector3 in _points(group,required.begins_with("banner_")):
		_require(_clear_ray(camera.position,point),"actual layer1 frame/caption ray "+id)
	_require(snapshot == before,"snapshot untouched "+id)
	if required.begins_with("mark_"):
		var label: Label3D = group.get_node("mark_text") as Label3D
		_require(not label.text.is_empty() and label.visible and not label.no_depth_test,"real fixed mark label "+id)
	var image: Image = root.get_texture().get_image()
	_require(image.save_png(output.path_join(id+".png")) == OK,"save "+id)
	captures.append({"file":id+".png","size":[root.size.x,root.size.y],"camera":camera.global_transform,"lighting":"night" if night else "day","snapshot":snapshot.duplicate(true),"facts":report.facts,"visible":report.visible,"required":required,"projected":projected,"scope":"staged source presentation; no earned seals/campaign claim"})

func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Kingdom view probe requires native rendering."); quit(1); return
	output = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output) == OK,"output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); root.add_child(world); world.build()
	camera = Camera3D.new(); camera.fov = 70; camera.near = 0.06; camera.far = 380; world.add_child(camera); camera.current = true
	view = View.new(); world.add_child(view)
	if not _require(not view.build(world).is_empty(),"actual view bank"): world.free(); quit(1); return
	weather = Weather.new(); world.add_child(weather)
	if not _require(weather.build(world,camera),"actual source light owner"): world.free(); quit(1); return
	await physics_frame; await physics_frame
	for index: int in range(View.IDS.size()):
		var id: String = View.IDS[index]
		for faded: bool in [false,true]:
			snapshot = {"kingdom":{"stage":"locked","marks":0},"flags":{View.FLAGS[index]:faded}}
			await _capture("banner_"+id+("_faded" if faded else "_full"),"banner_"+id+("_faded" if faded else "_full"))
	var definitions: Array[Dictionary] = View._definitions()
	for index: int in range(3):
		var id: String = View.IDS[index]; var stage: String = definitions[index].marksStage
		for mark_index: int in range(3):
			for done: bool in [false,true]:
				snapshot = {"kingdom":{"stage":stage,"marks":(1 << mark_index) if done else 0},"flags":{}}
				var required: String = "mark_"+id+"_"+str(mark_index)+("_done" if done else "_open")
				await _capture(required,required)
	root.size = Vector2i(960,540)
	snapshot = {"kingdom":{"stage":"wire_marks","marks":1},"flags":{"copperChoirCleared":true}}
	await _capture("wire_mark_small_night","mark_copper_choir_0_done",true)
	snapshot = {"kingdom":{"stage":"cart_marks","marks":0},"flags":{}}
	await _capture("cart_fence_small_night","mark_cart_cavalry_0_open",true)
	snapshot = {"kingdom":{"stage":"complete","marks":7},"flags":{"throneDitchCleared":true}}
	await _capture("emperor_complete_small_night","banner_emperor_faded",true)
	snapshot = {"kingdom":{"stage":"tarp_marks","marks":7},"flags":{}}
	view.sync(snapshot)
	_require(view.inspect().visible.has("mark_blue_tarp_0_done"),"pre-boss complete mark exists")
	snapshot.kingdom.stage = "tarp_boss"
	await _capture("boss_marks_hidden_small","banner_blue_tarp_full")
	_require(view.inspect().visible.size() == 4,"boss stage hides all marks without hiding banners")
	var writes: int = view.inspect().writes; var samples: Array[float] = []
	for frame: int in range(120):
		var started: int = Time.get_ticks_usec(); view.sync(snapshot)
		samples.append((Time.get_ticks_usec()-started)/1000.0); await process_frame
	samples.sort(); var p95: float = samples[int(floor((samples.size()-1)*0.95))]
	_require(view.inspect().writes == writes,"unchanged native sync no property writes")
	_require(captures.size() == 30,"all30 actual-world staged captures completed")
	var file := FileAccess.open(output.path_join("kingdom-view.json"),FileAccess.WRITE)
	if _require(file != null,"write report"):
		file.store_string(JSON.stringify({"pass":failures.is_empty(),"failures":failures,"captures":captures,"sync_p95_ms":p95,"sync_target_ms":0.05,"sync_target_pass":p95 < 0.05,"msaa_3d":root.msaa_3d,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"scope":"Staged banner/mark presentation; no seal earning, boss timing, campaign completion or whole-frame performance claim."},"\t")); file.close()
	world.free()
	print("3D KINGDOM VIEW NATIVE: %s (%d captures; sync p95 %.4fms; %s)"%["PASS" if failures.is_empty() else "FAIL",captures.size(),p95,output])
	quit(0 if failures.is_empty() else 1)
