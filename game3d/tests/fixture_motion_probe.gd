extends SceneTree
## Native staged fixture evidence; no Runtime, gameplay tick, source mutation or save.
const View = preload("res://scripts/fixture_motion_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Weather = preload("res://scripts/weather_presentation.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
var world: World
var view: View
var weather: Weather
var camera: Camera3D
var pete: Node3D
var food: Node3D
var bindings: Dictionary = {}
var source_pete: Dictionary = {}
var output := ""
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var samples: Array[float] = []
var probe_queries := 0
var checks := 0
var eye_shape: SphereShape3D

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); push_error("Fixture motion probe: "+label)
	return ok
func _output() -> String:
	var result: String = ProjectSettings.globalize_path("res://../.build/full-port/fixture-motion")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): result = arg.trim_prefix("--output=")
	return ProjectSettings.globalize_path(result) if result.begins_with("res://") or result.begins_with("user://") else result
func _snapshot(day: float) -> Dictionary:
	return {"world_visible":true,"dayTime":day,"food_visible":food.is_visible_in_tree(),"food_transform":food.global_transform,"camera_basis":camera.global_basis}
func _eye_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = eye_shape; query.transform = Transform3D(Basis.IDENTITY,camera.global_position)
	query.margin = 0.002; query.collision_mask = 1; probe_queries += 1
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _ray_clear(point: Vector3) -> bool:
	probe_queries += 1
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,point,1)).is_empty()
func _look(eye: Vector3,target: Vector3) -> void:
	camera.global_position = eye; camera.look_at(target,Vector3.UP)
func _bounds(node: Node3D) -> Rect2:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D: meshes.append(node)
	for child: Node in node.find_children("*","MeshInstance3D",true,false): meshes.append(child as MeshInstance3D)
	var result := Rect2(); var started := false
	for mesh: MeshInstance3D in meshes:
		if not mesh.is_visible_in_tree(): continue
		for corner: int in range(8):
			var point: Vector3 = mesh.global_transform*mesh.mesh.get_aabb().get_endpoint(corner)
			if camera.is_position_behind(point): return Rect2(Vector2(-10000,-10000),Vector2.ONE)
			var projected: Vector2 = camera.unproject_position(point)
			if not started: result = Rect2(projected,Vector2.ZERO); started = true
			else: result = result.expand(projected)
	return result
func _receiver_height(point: Vector2) -> float:
	for receiver: Dictionary in bindings.underpass.receivers:
		if receiver.rect.grow(0.00001).has_point(point): return float(receiver.height)
	return NAN
func _capture(id: String,day: float,visual: float,unix: float,required: Array[String],kind: String = "fixture") -> void:
	var snapshot: Dictionary = _snapshot(day); var original: Dictionary = snapshot.duplicate(true)
	_require(weather.sync({"dayTime":day,"weather":"clear","office_generator":false,"geometry_revision":0},visual),"existing light owner "+id)
	_require(view.sync(snapshot,visual,unix),"actual fixture sync "+id)
	await physics_frame; await process_frame; await RenderingServer.frame_post_draw
	_require(_eye_clear(),"actual camera sphere outside world geometry "+id)
	var expected: Dictionary = View.source_sample(visual,unix,day)
	var inspected: Dictionary = view.inspect()
	_require(inspected.sample == expected and inspected.steam_visible == expected.steam_visible,"exact supplied source phases and real visible food "+id)
	var projections: Dictionary = {}
	for path: String in required:
		var node: Node3D = view.get_node(path)
		var rectangle: Rect2 = _bounds(node); projections[path] = rectangle
		_require(node.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-8).encloses(rectangle) and rectangle.size.x >= 6 and rectangle.size.y >= 4,"complete readable fixture geometry "+id+":"+path)
		_require(_ray_clear(node.global_position),"actual unobstructed fixture ray "+id+":"+path)
	if kind == "food":
		var rectangle: Rect2 = _bounds(food); projections.hot_pocket = rectangle
		_require(food.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-8).encloses(rectangle) and rectangle.size.x >= 12 and rectangle.size.y >= 20,"actual physical hot pocket readable in "+id)
		_require(_ray_clear(food.global_position) and camera.global_position.distance_to(food.global_position) > 1.0,"food camera is in front of the actual attachment, not inside Pete "+id)
	elif kind == "shadow":
		if expected.shadow_visible:
			var source: Rect2 = bindings.underpass.source_rect
			var center: Vector3 = Content.to_world(Vector2(source.position.x+float(expected.shadow_phase)*source.size.x*6.0+60.0,source.position.y-6.0))
			center.y = _receiver_height(Vector2(center.x,center.z))+0.002
			_require(center.is_finite() and not camera.is_position_behind(center) and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-12).has_point(camera.unproject_position(center)) and _ray_clear(center),"uncovered center of actual moving strip visible "+id)
		else: _require(not inspected.shadow_visible,"source1600ms strip disappearance")
	elif kind == "covered_tail":
		var at: Vector3 = Content.to_world(Vector2(1580,234))
		var plane: float = _receiver_height(Vector2(at.x,at.z))
		_require(absf(plane-0.017) < 0.00003 and inspected.shadow_visible,"source-covered tail retains abandoned-zone receiver.017m")
		at.y = 0.026
		_require(_ray_clear(at),"actual interior floor remains visible above covered tail")
		projections.covered_floor = camera.unproject_position(at)
	elif kind.begins_with("sodium:"):
		var index: int = int(kind.trim_prefix("sodium:"))
		var patch: Dictionary = bindings.sodium[index]
		var at: Vector3 = Content.to_world(patch.source_center)
		for receiver: Dictionary in patch.receivers:
			if Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),receiver.polygon): at.y = float(receiver.height)+0.002; break
		_require(inspected.sodium_visible and inspected.sodium_surfaces == 1 and _ray_clear(at) and not camera.is_position_behind(at) and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-50).has_point(camera.unproject_position(at)),"actual sodium center visible below original underpass deck "+id)
		projections.sodium_center = camera.unproject_position(at)
		projections.sodium_source = {"center":patch.source_center,"inner_radius_px":4,"middle_radius_px":37,"outer_radius_px":70,"inner_alpha":expected.sodium_alpha,"middle_alpha":0.18,"outer_alpha":0,"blend":"additive3D; displayed color is not Canvas pixel parity"}
	elif kind == "window_steam":
		_require(not food.is_visible_in_tree() and inspected.steam_visible == expected.steam_visible,"staged hidden Pete uses actual counter fallback "+id)
		projections.steam_anchor = bindings.pawn_counter.transform
	var source_pose: Transform3D = food.global_transform
	_require(snapshot == original and source_pose == snapshot.food_transform,"capture does not mutate source snapshot or rig "+id)
	var image: Image = root.get_texture().get_image()
	_require(image.save_png(output.path_join(id+".png")) == OK,"write "+id)
	captures.append({"file":id+".png","kind":kind,"size":[root.size.x,root.size.y],"camera":camera.global_transform,"dayTime":day,"visual_ms":visual,"unix_ms":unix,"snapshot":snapshot,"inspection":inspected,"projected":projections,"scope":"staged actual-world presentation, no earned gameplay/input claim"})
func _tv_camera(oblique: bool) -> void:
	var at: Transform3D = bindings.tv_window.transform
	var screen: Vector3 = at*Vector3(-float(bindings.tv_window.size.x)*0.72*0.04,0.06,0.165)
	_look(screen+Vector3(1.25 if oblique else 0.0,0.12,2.1),screen)
func _washer_camera() -> void:
	var center: Vector3 = (bindings.washers[0].origin+bindings.washers[3].origin)*0.5
	_look(center+Vector3(0,0.95,3.25),center)
func _food_camera() -> void:
	var bite: Vector3 = food.global_transform*Vector3(0.01,0.135,0.015)
	_look(bite+Vector3(0.55,0.17,1.45),bite+Vector3(0,0.04,0))
func _pawn_counter_camera() -> void:
	var at: Transform3D = bindings.pawn_counter.transform
	var top: Vector3 = at*Vector3(0,bindings.pawn_counter.size.y*0.5+0.16,0)
	_look(top+Vector3(0.35,0.04,2.3),top)
func _sodium_camera(index: int,oblique: bool) -> void:
	var at: Vector3 = Content.to_world(bindings.sodium[index].source_center,0.02)
	_look(at+Vector3(1.7 if oblique else 0.0,2.6,4.2),at)
func _shadow_camera(interior: bool = false) -> void:
	if interior:
		_look(Content.to_world(Vector2(1605,280),1.65),Content.to_world(Vector2(1580,234),0.026))
	else:
		var corridor: Rect2 = View._corridor(bindings.underpass.source_rect)
		var at := Vector3(corridor.get_center().x,0.02,corridor.get_center().y)
		_look(at+Vector3(0,14,-8),at)
func _profile() -> Dictionary:
	_food_camera()
	var snapshot: Dictionary = _snapshot(0.9); var original: Dictionary = snapshot.duplicate(true)
	_require(weather.sync({"dayTime":0.9,"weather":"clear","office_generator":false,"geometry_revision":0},713),"profile light setup outside measurement")
	for index: int in range(240):
		var visual: float = 713.0+float(index)*16.6666667
		var unix: float = 1763424000000.0+float(index)*16.6666667
		var started: int = Time.get_ticks_usec()
		var accepted: bool = view.sync(snapshot,visual,unix)
		var elapsed: float = float(Time.get_ticks_usec()-started)/1000.0
		if index >= 60: samples.append(elapsed)
		_require(accepted,"measured supplied-clock sync")
		await process_frame
	_require(snapshot == original and food.global_transform == original.food_transform,"profile owns no snapshot/rig mutation")
	samples.sort()
	var p95: float = samples[int(ceil(float(samples.size())*0.95))-1]
	_require(p95 < 0.2,"isolated presenter sync p95 below.2ms")
	return {"warmup_frames":60,"samples":samples.size(),"sync_p50_ms":samples[int(samples.size()/2)],"sync_p95_ms":p95,"sync_max_ms":samples[-1],"target_ms":0.2,"target_pass":p95 < 0.2,"boundary":"Only fixture view.sync; excludes capture/readback, Weather, pose, world build and rendered frame CPU/GPU. Not full-scene/60-actor/Web acceptance."}
func _inventory() -> Dictionary:
	var census := {"meshes":0,"physics":0,"lights":0,"particles":0,"timers":0}
	for child: Node in view.find_children("*","",true,false):
		if child is MeshInstance3D: census.meshes += 1
		if child is CollisionObject3D or child is CollisionShape3D: census.physics += 1
		if child is Light3D: census.lights += 1
		if child is GPUParticles3D or child is CPUParticles3D: census.particles += 1
		if child is Timer: census.timers += 1
		_require(not child.is_processing() and not child.is_physics_processing(),"presenter child owns no autonomous clock")
	return census
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Fixture motion probe requires native rendering."); quit(1); return
	output = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output) == OK,"output directory"): quit(1); return
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	world = World.new(); world.dynamic_fixture_motion = true; root.add_child(world); world.build()
	bindings = world.fixture_motion_bindings()
	view = View.create(); world.add_child(view)
	if not _require(view.build(bindings),"actual opt-in world attachments"): world.queue_free(); await process_frame; quit(1); return
	for record: Dictionary in Content.load_content().actors.base:
		if record.id == "pete": source_pete = record.duplicate(true); break
	if not _require(not source_pete.is_empty(),"canonical Pete source record"): world.queue_free(); await process_frame; quit(1); return
	pete = Roster.create(&"pete","pete".hash()); world.add_child(pete)
	pete.position = Content.body_position(source_pete,0.06)
	Animator.tick(pete,0.1,{"local_velocity":Vector3.ZERO,"action":&"eat","action_phase":0.4,"ambient_action":true},0)
	food = pete.find_child("hot_pocket",true,false) as Node3D
	if not _require(food != null,"actual weighted Pete hot_pocket attachment"): world.queue_free(); await process_frame; quit(1); return
	camera = Camera3D.new(); camera.fov = 52; camera.near = 0.05; camera.far = 380; world.add_child(camera); camera.current = true
	eye_shape = SphereShape3D.new(); eye_shape.radius = 0.06
	weather = Weather.new(); world.add_child(weather)
	if not _require(weather.build(world,camera),"existing source daylight/fixture-light owner"): world.queue_free(); await process_frame; quit(1); return
	await physics_frame; await physics_frame
	for oblique: bool in [false,true]:
		_tv_camera(oblique)
		await _capture("tv_"+("oblique" if oblique else "close")+"_off",0.5,0,3000,["CornerTelevision/Screen"])
		await _capture("tv_"+("oblique" if oblique else "close")+"_on",0.5,170,3000,["CornerTelevision/Screen"])
	_washer_camera()
	var drums: Array[String] = ["Washer0/TurningPatch","Washer1/TurningPatch","Washer2/TurningPatch","Washer3/TurningPatch"]
	for day: float in [0.5,0.9]:
		await _capture("washers_"+("day" if day == 0.5 else "night")+"_phase0",day,0,3000,drums)
		await _capture("washers_"+("day" if day == 0.5 else "night")+"_phase1",day,PI*150.0,3000,drums)
	_food_camera()
	await _capture("pete_steam_night_phase0",0.9,713,3000,["PocketSteam"],"food")
	await _capture("pete_steam_night_phase1",0.9,1373,3000,["PocketSteam"],"food")
	await _capture("pete_steam_hidden_day",0.5,713,3000,[],"food")
	pete.visible = false; _pawn_counter_camera()
	await _capture("pawn_counter_steam_night_phase0",0.9,713,3000,["PocketSteam"],"window_steam")
	await _capture("pawn_counter_steam_night_phase1",0.9,1373,3000,["PocketSteam"],"window_steam")
	await _capture("pawn_counter_steam_hidden_day",0.5,713,3000,[],"window_steam")
	pete.visible = true
	for index: int in range(3):
		for day: float in [0.5,0.9]:
			_sodium_camera(index,day == 0.9)
			var prefix: String = "sodium_%d_%s_"%[index,"day" if day == 0.5 else "night"]
			await _capture(prefix+"min",day,PI*1050.0,3000,[],"sodium:"+str(index))
			await _capture(prefix+"max",day,PI*350.0,3000,[],"sodium:"+str(index))
	_shadow_camera()
	for unix: float in [0.0,800.0,1599.0,1600.0]:
		await _capture("shadow_%04d"%int(unix),0.5,713,unix,[],"shadow")
	_shadow_camera(true)
	await _capture("shadow_tail_covered_1599",0.5,713,1599,[],"covered_tail")
	_require(captures.size() == 31,"all31 native fixture/steam-fallback/sodium views captured")
	var profile: Dictionary = await _profile()
	var census: Dictionary = _inventory()
	_require(census.physics == 0 and census.lights == 0 and census.particles == 0 and census.timers == 0 and view.inspect().physics_queries == 0,"fixture presenter adds no physics/light/particle/timer owner")
	var world_lights: int = world.find_children("*","Light3D",true,false).size()
	var file := FileAccess.open(output.path_join("fixture-motion.json"),FileAccess.WRITE)
	if _require(file != null,"write native report"):
		file.store_string(JSON.stringify({"schema":1,"format":"rock-bottom-fixture-motion-native","acceptance":failures.is_empty(),"failures":failures,"checks":checks,"captures":captures,"profile":profile,"presenter_inventory":census,"presenter_physics_queries":view.inspect().physics_queries,"probe_validation_physics_queries":probe_queries,"existing_world_lights":world_lights,"bindings":bindings,"pete_source":source_pete,"output_config":{"directory":output,"resolution":[1280,720],"camera_fov":camera.fov,"near":camera.near,"far":camera.far,"max_fps":Engine.max_fps,"msaa_3d":root.msaa_3d},"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"scope":"Actual full-world attachments and Roster Pete, explicitly staged supplied clocks. No Runtime, gameplay input/tick, source RNG, save, earned progression or full-frame performance claim."},"\t")); file.close()
	world.queue_free(); await process_frame
	print("3D FIXTURE MOTION NATIVE: %s (%d captures; sync p95 %.4fms; %s)"%["PASS" if failures.is_empty() else "FAIL",captures.size(),profile.sync_p95_ms,output])
	quit(0 if failures.is_empty() else 1)
