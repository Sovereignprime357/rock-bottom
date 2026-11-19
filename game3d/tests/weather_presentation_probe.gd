extends SceneTree
## Incremental native presentation evidence, not whole-runtime/60-actor/GPU acceptance.
const World = preload("res://scripts/full_neighborhood.gd")
const Weather = preload("res://scripts/weather_presentation.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
var world: Node3D
var weather: Node3D
var camera: Camera3D
var output := ""
var captures: Array[Dictionary] = []
var profiles: Dictionary = {}
var failures: Array[String] = []
var diagnostic := false
var label: Label
var instance_checks := 0
var display_bounds: Array[AABB] = []
var shelter_witness: Dictionary = {}
func _initialize() -> void: call_deferred("_run")
func _input(kind: String,t: float,generator: bool = false) -> Dictionary:
	return {"dayTime":t,"weather":kind,"office_generator":generator,"geometry_revision":0}
func _camera_view(id: String) -> bool:
	var service: Dictionary = world.service_points[id]
	var target: Vector3 = service.target+Vector3.UP*0.35
	for offset: Vector3 in [Vector3(0,0,3.5),Vector3(0,0,2),Vector3(2,0,2),Vector3(-2,0,2),Vector3.ZERO]:
		var foot: Vector3 = service.approach+offset
		if not world.is_clear_position(foot,0.486): continue
		var eye: Vector3 = foot+Vector3.UP*1.65
		var query := PhysicsRayQueryParameters3D.create(eye,target,1)
		if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		camera.position = eye; camera.look_at(target); return true
	return false
func _covered_view() -> bool:
	for aperture: Dictionary in world.aperture_witnesses:
		var outward: Vector3 = (Vector3(aperture.from)-Vector3(aperture.to)).normalized()
		for depth: float in [0.0,0.45,0.9]:
			var foot: Vector3 = Vector3(aperture.to)-outward*depth; foot.y = 0.06
			if not world.is_clear_position(foot,0.486): continue
			var eye: Vector3 = foot+Vector3.UP*1.65
			var target: Vector3 = eye+outward*6.0
			if not _display_clear(eye,target): continue
			var query := PhysicsRayQueryParameters3D.create(eye,eye+Vector3.UP*20,1)
			if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			query = PhysicsRayQueryParameters3D.create(eye,target,1)
			if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			camera.position = eye; camera.look_at(target)
			shelter_witness = {"owner":aperture.owner,"eye":eye,"outdoor_target":target,"display_bounds_rejected":true}
			return true
	return false
func _display_clear(eye: Vector3,target: Vector3) -> bool:
	for bounds: AABB in display_bounds:
		if bounds.has_point(eye) or bounds.intersects_segment(eye,target) != null: return false
	return true
func _record_display_bounds(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Use authored mesh vertices, not the rig's deliberately oversized animation-culling box.
		var bounds: AABB = node.global_transform*node.mesh.get_aabb()
		display_bounds.append(bounds.grow(0.35))
	for child: Node in node.get_children(): _record_display_bounds(child)
func _capture(place: String,kind: String,t: float,generator: bool = false) -> void:
	var snapshot: Dictionary = _input(kind,t,generator)
	for frame: int in range(5):
		if not weather.sync(snapshot,float(Time.get_ticks_msec())): failures.append("sync failed "+place)
		await process_frame
	label.text = "%s · %s · dayTime %.2f · night %.2f" % [place,kind,t,Weather.night_amount(t)]
	await process_frame; await RenderingServer.frame_post_draw
	if kind == "rain": _validate_native_instances()
	var path: String = output.path_join("%s_%s_%02d%s.png" % [place,kind,int(round(t*100)),"_generator" if generator else ""])
	if root.get_texture().get_image().save_png(path) != OK: failures.append("capture failed "+path)
	captures.append({"file":path,"place":place,"weather":kind,"day_time":t,"generator":generator,"camera":camera.global_position,"presentation":weather.inspect()})
func _validate_native_instances() -> void:
	# Unlike headless's dummy getter, this proves the actual Compatibility
	# renderer interpreted every submitted row/translation/hidden basis.
	var buffer: PackedFloat32Array = weather.rain.multimesh.buffer
	if buffer.size() != 160*12: failures.append("native rain buffer size mismatch"); return
	var columns: Array = weather.inspect().columns
	var vertices: PackedVector3Array = weather.rain.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for index: int in range(160):
		var i: int = index*12
		var submitted := Transform3D(Basis(Vector3(buffer[i],buffer[i+4],buffer[i+8]),Vector3(buffer[i+1],buffer[i+5],buffer[i+9]),Vector3(buffer[i+2],buffer[i+6],buffer[i+10])),Vector3(buffer[i+3],buffer[i+7],buffer[i+11]))
		var actual: Transform3D = weather.rain.multimesh.get_instance_transform(index)
		instance_checks += 1
		if not actual.is_equal_approx(submitted): failures.append("native instance differs from submitted rain transform "+str(index)); continue
		var column: Dictionary = columns[index/10]
		if not column.certified and actual.basis.y.length_squared() != 0: failures.append("native uncertified column is not hidden "+str(index))
		if actual.basis.y.length_squared() == 0: continue
		for vertex: Vector3 in vertices:
			var local: Vector3 = actual*vertex
			if (weather.rain.global_transform*local).y <= float(column.cover)+0.019: failures.append("native visible rain crosses certified roof "+str(index)); break
			if not weather.rain.multimesh.custom_aabb.has_point(local): failures.append("native rain exceeds conservative render bounds "+str(index)); break
func _percentile(values: Array[float],fraction: float) -> float:
	if values.is_empty(): return 0
	var sorted: Array[float] = values.duplicate(); sorted.sort()
	return sorted[mini(sorted.size()-1,int(ceil(sorted.size()*fraction))-1)]
func _profile(kind: String) -> void:
	var samples: Array[float] = []; var engine: Array[float] = []; var draws: Array[float] = []
	var queries := 0; var snapshot: Dictionary = _input(kind,0.65)
	for frame: int in range(240):
		var started: int = Time.get_ticks_usec()
		weather.sync(snapshot,float(Time.get_ticks_msec()))
		var elapsed: float = float(Time.get_ticks_usec()-started)
		if frame >= 60:
			samples.append(elapsed); queries = maxi(queries,int(weather._queries))
		await process_frame
		if frame >= 60:
			engine.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	profiles[kind] = {"samples":samples.size(),"sync_p95_us":_percentile(samples,0.95),"sync_max_us":samples.max(),"query_max":queries,"engine_process_p95_ms":_percentile(engine,0.95),"draw_p95":_percentile(draws,0.95),"scope":"static authored world plus weather and three existing display rigs; no full Runtime/AI/GPU/Web claim"}
	if float(profiles[kind].sync_p95_us) > 500: failures.append(kind+" local Weather.sync p95 exceeds0.5ms")
	if queries > 4: failures.append(kind+" exceeded four rays")
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Weather native probe needs a renderer"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/p14d/native")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--diagnostic": diagnostic = true
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 60
	world = World.new(); root.add_child(world); world.build()
	camera = Camera3D.new(); root.add_child(camera); camera.fov = 76; camera.near = 0.07; camera.far = 500; camera.make_current()
	weather = Weather.new(); root.add_child(weather)
	if not weather.build(world,camera): push_error("Weather binding incomplete"); quit(1); return
	for actor: Dictionary in world.content.actors.day1:
		if actor.id not in ["pete","tony","lease_guy"]: continue
		var rig: Node3D = Roster.create(Roster.visual_for_actor(actor),17)
		if rig != null:
			world.add_child(rig); rig.position = Content.body_position(actor,0.06)
			_record_display_bounds(rig)
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var backing := ColorRect.new(); backing.color = Color("272c27"); backing.position = Vector2(12,12); backing.size = Vector2(800,38); canvas.add_child(backing)
	label = Label.new(); label.position = Vector2(20,17); label.add_theme_color_override("font_color",Color("d4c896")); label.add_theme_font_size_override("font_size",21); canvas.add_child(label)
	await physics_frame; await physics_frame
	for place: String in ["smoke:block","pete","office"]:
		if not _camera_view(place): failures.append("No clear eye-level view "+place); continue
		for kind: String in ["clear","rain","fog"]:
			for t: float in [0.65,0.75,0.9]: await _capture(place.replace(":","_"),kind,t)
	if _camera_view("office"): await _capture("office","clear",0.9,true)
	if _covered_view():
		await _capture("shelter","rain",0.65)
		await _capture("shelter","rain",0.9)
	else: failures.append("No physically clear authored shelter camera")
	if _camera_view("smoke:block"):
		for kind: String in ["clear","rain","fog"]: await _profile(kind)
	if profiles.has("rain") and profiles.has("clear") and float(profiles.rain.draw_p95)-float(profiles.clear.draw_p95) > 1:
		failures.append("rain adds more than one native draw submission")
	var report := {"acceptance":failures.is_empty(),"diagnostic":diagnostic,"captures":captures,"profiles":profiles,"native_instance_checks":instance_checks,"shelter_witness":shelter_witness,"failures":failures,"source_curve":".2/.3/.7/.8 exact; .65day","scope":"incremental original weather presentation; fullscene/native60/Web acceptance separate"}
	var file := FileAccess.open(output.path_join("weather-presentation.json"),FileAccess.WRITE)
	if file == null: failures.append("report output unavailable")
	else: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("3D WEATHER NATIVE PROBE: ","PASS" if failures.is_empty() else "FAIL"," (",captures.size()," captures; ",profiles.size()," bounded profiles)")
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() or diagnostic else 1)
