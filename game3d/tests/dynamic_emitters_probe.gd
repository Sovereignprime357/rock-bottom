extends SceneTree
## Native evidence and isolated six-light profile. Explicit source snapshots; no Runtime.
const Emitters = preload("res://scripts/dynamic_emitters.gd")
const Rig = preload("res://scripts/first_person_rig.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Cart = preload("res://scripts/cart_view.gd")
const POINT := Vector2(1050,840)
var world: World
var camera: Camera3D
var hands: Rig
var emitters: Emitters
var actors: Array[Node3D] = []
var anchors: Array[Node3D] = []
var game: State
var adapter: Adapter
var travel: Travel
var cart: Cart
var output_dir: String
var captures: Array[Dictionary] = []
var failed: bool = false
var night: bool = true
var high: bool = false
var profile: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failed = true; push_error("Dynamic emitter capture: "+label)
	return ok
func _output() -> String:
	var path: String = ProjectSettings.globalize_path("res://../.build/full-port/p14e")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): path = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): path = args[index+1]
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _snapshot() -> Dictionary:
	var cops: Array = []
	for index: int in range(actors.size()):
		var sprite: String = "horsecop" if index == 2 else ("brendan" if index == 1 else "cop")
		cops.append({"id":"actual_"+str(index),"sprite":sprite,"isCop":index != 2,"dead":false,"hidden":false,"visible":anchors[index].is_visible_in_tree(),"cap_transform":anchors[index].global_transform})
	var mouth: Node3D = hands.emitter_anchor(&"player_ember")
	return {"dayTime":0.9 if night else 0.5,"cops":cops,"player":{"rockedT":1000.0 if high else 0.0,"hitterHigh":false,"visible":mouth.is_visible_in_tree(),"ember_transform":mouth.global_transform}}
func _sync(time: float) -> void: _require(emitters.sync(_snapshot(),time),"accept actual source/fixture snapshot")
func _light(night_value: bool) -> void:
	night = night_value; world.set_day_time(180.0 if night else 84.0)
func _advance(seconds: float,velocity: Vector3 = Vector3.ZERO,sprint: bool = false) -> void:
	var left: float = seconds
	while left > 0.000001:
		var dt: float = minf(left,1.0/120.0); hands.tick(dt,velocity,sprint,high,false,0.0,Vector2.ZERO); left -= dt
func _first_person(tool: StringName = &"",weapon: StringName = &"fists") -> void:
	camera.position = Content.to_world(POINT,1.69); camera.rotation = Vector3.ZERO
	hands.reset(); high = true; hands.set_context({"weapon":weapon,"tool":tool,"high_ember":true,"visible":true,"walk_speed":5.5})
func _group() -> void:
	hands.set_context({"visible":false}); high = false
	var at: Vector3 = Content.to_world(POINT+Vector2(0,-60),1.35)
	camera.position = at+Vector3(4.3,1.3,6.6); camera.look_at(at,Vector3.UP)
func _geometry(node: Node) -> Dictionary:
	var vertices: int = 0; var safe: bool = true
	var low := Vector3(INF,INF,INF); var upper := Vector3(-INF,-INF,-INF)
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if not instance.is_visible_in_tree(): continue
		for surface: int in range(instance.mesh.get_surface_count()):
			for vertex: Vector3 in instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = camera.to_local(instance.global_transform*vertex)
				safe = safe and at.is_finite(); low = low.min(at); upper = upper.max(at); vertices += 1
	return {"vertices":vertices,"finite":safe,"camera_min":[low.x,low.y,low.z] if vertices > 0 else [],"camera_max":[upper.x,upper.y,upper.z] if vertices > 0 else []}
func _capture(label: String,time: float) -> void:
	if failed: return
	_sync(time)
	var fixture_geometry: Dictionary = _geometry(emitters); var mouth_geometry: Dictionary = _geometry(hands.get_node("MouthEmber"))
	_require(fixture_geometry.finite and mouth_geometry.finite,label+" finite actual fixture geometry")
	await process_frame; await RenderingServer.frame_post_draw
	if not _require(root.get_texture().get_image().save_png(output_dir.path_join(label+".png")) == OK,"write "+label): return
	captures.append({"file":label+".png","time_ms":time,"night":night,"lights":emitters.inspect(),"mouth_visible":hands.emitter_anchor(&"player_ember").is_visible_in_tree(),"tool":str(hands.tool),"weapon":str(hands.weapon),"action":str(hands.action),"beacon_geometry":fixture_geometry,"mouth_geometry":mouth_geometry})
func _cart_capture() -> void:
	var record: Dictionary = travel.cart_record(); var approach: Vector3 = adapter.cart_approach(Vector2(record.x,record.y))
	if not _require(approach.is_finite(),"actual cart approach"): return
	var center: Vector2 = Content.to_source(approach); game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
	if not _require(bool(travel.interact_cart().get("ok",false)) and cart.sync(),"actual Travel mount"): return
	game.p.x = POINT.x-float(game.p.w)*0.5; game.p.y = POINT.y-float(game.p.h)*0.5
	_first_person(&"propane_torch",&"pipe"); camera.rotation.x = -0.55
	cart.tick_pose(1.0/120.0,Transform3D(Basis.IDENTITY,Content.to_world(game.player_center())),Vector3.ZERO)
	var grips: Dictionary = cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y))
	if not _require(grips.size() == 2,"actual mounted cart yields both handle grips"): return
	hands.set_context({"cart_grips":grips}); await _capture("mouth_actual_cart_grips",0.0)
	cart.clear_active()
func _percentile(values: Array[float],fraction: float) -> float:
	if values.is_empty(): return 0.0
	var sorted: Array[float] = values.duplicate(); sorted.sort(); return sorted[mini(sorted.size()-1,int(ceil(values.size()*fraction))-1)]
func _profile_six() -> void:
	_first_person(&"propane_torch",&"pipe"); _light(true)
	var source: Dictionary = _snapshot(); _require(source.cops.size() == 5,"profile contains five actual cap fixtures")
	for frame: int in range(30): emitters.sync(source,frame*1000.0/60.0); await process_frame
	var sync_times: Array[float] = []; var frame_times: Array[float] = []; var process_times: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(240):
		var start: int = Time.get_ticks_usec(); emitters.sync(source,frame*1000.0/60.0)
		sync_times.append(float(Time.get_ticks_usec()-start)/1000.0)
		await process_frame
		var current: int = Time.get_ticks_usec(); frame_times.append(float(current-previous)/1000.0); previous = current
		process_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	profile = {"frames":240,"warmup_frames":30,"sync_p95_ms":_percentile(sync_times,0.95),"sync_max_ms":sync_times.max(),"frame_interval_p95_ms":_percentile(frame_times,0.95),"reported_process_p95_ms":_percentile(process_times,0.95),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"lights":emitters.inspect(),"note":"No captures/readbacks in measured interval. Frame interval includes native scheduling/VSync; this is not a full gameplay performance claim."}
	_require(emitters.inspect().active_lights == 6 and emitters.inspect().queries == 0 and emitters.inspect().dynamic_shadows == 0,"all six pooled lights active throughout bounded zero-query profile")
	_require(float(profile.sync_p95_ms) <= 0.2,"incremental presenter sync p95 at most0.2ms")
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Dynamic emitter evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); _light(true)
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	hands = Rig.create() as Rig; camera.add_child(hands)
	emitters = Emitters.create(); world.add_child(emitters)
	game = State.new(); game.s.mode = "playing"; game.npcs.clear(); adapter = Adapter.new(world,game); travel = Travel.new(game,adapter)
	cart = Cart.new(); world.add_child(cart)
	if not _require(cart.bind(world,adapter,travel) and cart.sync(),"bind original cart for grip evidence"): world.free(); quit(1); return
	for index: int in range(5):
		var id: StringName = &"horsecop" if index == 2 else (&"brendan" if index == 1 else &"cop")
		var actor: Node3D = Roster.create(id,index*31); world.add_child(actor)
		actor.position = Content.to_world(POINT+Vector2((index-2)*33,-60),0.02); actors.append(actor)
		Animator.tick(actor,0.1,{"local_velocity":Vector3.ZERO,"action":&"","action_phase":0.0,"dead":false,"hurt":0.0},0)
		anchors.append(actor.get_node("mounted_rider/head/hair_style" if id == &"horsecop" else "head/hair_style"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame; await physics_frame; await physics_frame
	hands.set_context({"visible":false})
	for index: int in range(3):
		for phase: int in range(2):
			var at: Vector3 = anchors[index].global_position+Vector3(0,0.10,0)
			camera.position = at+Vector3(0.60,0.38,1.25); camera.look_at(at,Vector3.UP)
			await _capture(str(actors[index].get_meta("visual_id"))+"_cap_phase_"+str(phase),phase*150.0)
	_group(); _light(false); await _capture("five_beacons_day",0.0)
	_light(true); await _capture("five_beacons_night",150.0)
	_first_person(); await _capture("mouth_fists_night",0.0)
	_first_person(&"propane_torch"); await _capture("mouth_torch_night",150.0)
	_first_person(&"",&"pipe"); await _capture("mouth_weapon_pipe_night",0.0)
	await _cart_capture()
	_first_person(&"propane_torch",&"pipe"); hands.acknowledge(&"smoke",true); _advance(0.20); await _capture("gesture_stows_mouth_and_light",150.0)
	_advance(0.40); await _capture("gesture_recovery_current_high",0.0)
	hands.reset(); high = false; await _capture("reset_no_player_light",150.0)
	_first_person(&"propane_torch",&"pipe"); _light(false); await _capture("all_six_day_receivers",0.0)
	_require(captures.size() == 16,"all16 bounded native emitter views completed")
	if not failed: await _profile_six()
	var manifest := {"count":captures.size(),"captures":captures,"profile":profile,"camera":{"fov":camera.fov,"near":camera.near,"size":[1280,720]},"scope":"Actual original roster caps and first-person tips, production world light, explicit render snapshot. No AI/player simulation or audio/save authority; central reviewer owns visual acceptance."}
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if file == null: _require(false,"write manifest")
	else: file.store_string(JSON.stringify(manifest,"\t")); file.close()
	world.free()
	if failed: print("3D DYNAMIC EMITTER PROBE: FAIL"); quit(1)
	else: print("3D DYNAMIC EMITTER PROBE: PASS (%d frames;sync p95 %.4fms;%s)"%[captures.size(),profile.get("sync_p95_ms",0.0),output_dir]); quit(0)
