extends SceneTree
## Native production composition evidence. No replacement AI, cloned residents or gameplay saves.
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Driver = preload("sustained_actor_driver.gd")

class MeasuredScene:
	extends "res://scripts/full_scene.gd"
	signal frame_sampled
	var probe_running: bool = false
	var sample_cpu_us: int = 0
	var sample_interval_us: int = 0
	var sample_delta_ms: float = 0.0
	var previous_started: int = 0
	var observed_events: Dictionary = {}
	var scope_us: Dictionary = {}
	var grade_disabled: bool = false
	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		scope_us.clear()
		super._process(delta)
		if grade_disabled and hud != null: hud.district_grade.hide()
		if not probe_running: return
		sample_delta_ms = delta*1000.0
		for key: String in runtime.profile_us: scope_us["runtime_"+key] = runtime.profile_us[key]
		sample_cpu_us = Time.get_ticks_usec()-started
		sample_interval_us = started-previous_started if previous_started != 0 else 0
		previous_started = started
		scope_us["model_input_hud_world"] = sample_cpu_us-int(scope_us.get("models",0))-int(scope_us.get("interaction",0))-int(scope_us.get("events",0))
		frame_sampled.emit()
	func _sync_model_nodes(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._sync_model_nodes(delta)
		scope_us["models"] = int(scope_us.get("models",0))+Time.get_ticks_usec()-started
	func resolve_interaction() -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.resolve_interaction()
		scope_us["interaction"] = int(scope_us.get("interaction",0))+Time.get_ticks_usec()-started
		return result
	func _consume_events() -> void:
		var started: int = Time.get_ticks_usec()
		if runtime != null:
			for event: Dictionary in runtime._outbox:
				observed_events[event.kind] = int(observed_events.get(event.kind,0))+1
			for event: Dictionary in runtime.state.events:
				observed_events[event.kind] = int(observed_events.get(event.kind,0))+1
		super._consume_events()
		scope_us["events"] = int(scope_us.get("events",0))+Time.get_ticks_usec()-started

var game: MeasuredScene
var output_dir: String = ""
var diagnostic: bool = false
var grade_disabled: bool = false
var pose_input_disabled: bool = false
var sample_frames: int = 1080
var warmup_frames: int = 120
var failures: Array[String] = []
var route := PackedVector2Array()
var route_cursor: int = 1
var completed_laps: int = 0
var evasive: RefCounted
var driver_cpu := PackedFloat64Array()
var driver_queries := 0
var driver_decisions: Array[Dictionary] = []
var workload_frames: Array[Dictionary] = []
var lifecycle_timeline: Array[Dictionary] = []
var population_timeline: Array[Dictionary] = []
var prior_population: Dictionary = {}
var previous_events: Dictionary = {}
var driver_result: Dictionary = {}
var phase_part := "warmup"
var measured_driver := false
var driver_last_wall := -1
var driver_input := {"direction":Vector2.ZERO,"sprint":false}
var driver_input_counts := {"motion_frames":0,"sprint_frames":0,"mouse_motion":0,"capture_clicks":0}
var current_phase := ""


func _initialize() -> void: call_deferred("_run")


func _fail(message: String) -> void:
	if not failures.has(message): failures.append(message)


func _run() -> void:
	if "--qa-full" not in OS.get_cmdline_user_args():
		push_error("Sustained60 requires --qa-full before scene creation"); quit(1); return
	if DisplayServer.get_name() == "headless":
		push_error("Full actor performance evidence requires a native rendering device.")
		quit(1); return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/sustained60-draft")
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--diagnostic": diagnostic = true
		elif argument == "--without-grade": grade_disabled = true
		elif argument == "--without-pose-input-memo": pose_input_disabled = true
		elif argument.begins_with("--frames="): push_error("Sustained60 fixes1080 measured frames; no override"); quit(1); return
		elif argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create full actor evidence directory."); quit(1); return
	if FileAccess.file_exists(output_dir.path_join("full-actor-performance.json")):
		push_error("Use a fresh output directory; retained profiles are immutable."); quit(1); return
	if grade_disabled or pose_input_disabled:
		if not diagnostic: push_error("Alternative rendering requires --diagnostic"); quit(1); return
		_fail("diagnostic alternative: production acceptance not eligible")
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_4X
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var started: int = Time.get_ticks_msec()
	game = MeasuredScene.new(); root.add_child(game)
	# Mandatory --qa-full is checked before construction. No production save is read.
	game.qa_mode = true
	for frame: int in range(600):
		await process_frame
		if game.ready_for_play: break
	if not game.ready_for_play:
		_fail("production scene did not reach ready state")
		_write_report([],started); quit(1); return
	game.set_process(false)
	game.grade_disabled = grade_disabled
	game.store.save_path = output_dir.path_join("probe-only-save.json")
	game.store.storage_key = "rockbottom_3d_full_actual60_probe"
	game.sound.muted = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var phases: Array[Dictionary] = []
	var specs: Array[Dictionary] = [
		{"id":"core_day","day_time":0.30,"seed":432484078,"streets":[Vector2(672,1310),Vector2(1432,1310),Vector2(1432,1022),Vector2(672,1022),Vector2(672,1310)]},
		{"id":"trainyard_night","day_time":0.78,"seed":432484079,"streets":[Vector2(756,2648),Vector2(1416,2648),Vector2(1416,3300),Vector2(756,3300),Vector2(756,2648)]}]
	for spec: Dictionary in specs:
		var phase: Dictionary = await _phase(spec)
		phases.append(phase)
		if phase.get("setup_failed",false): break
	_release_input()
	game.set_process(false)
	_write_report(phases,started)
	var accepted: bool = failures.is_empty() and phases.size() == specs.size()
	print("FULL ACTOR NATIVE PROBE: ","PASS" if accepted else ("DIAGNOSTIC (acceptance:false)" if diagnostic else "FAIL")," ",JSON.stringify({"phases":phases.size(),"failures":failures,"output":output_dir}))
	quit(0 if accepted or (diagnostic and phases.size() == specs.size()) else 1)


func _phase(spec: Dictionary) -> Dictionary:
	game.set_process(false); _release_input()
	current_phase = spec.id; measured_driver = false; phase_part = "warmup"
	driver_cpu.clear(); driver_queries = 0; driver_decisions.clear(); workload_frames.clear()
	lifecycle_timeline.clear(); population_timeline.clear(); prior_population.clear(); previous_events.clear()
	driver_input_counts = {"motion_frames":0,"sprint_frames":0,"mouse_motion":0,"capture_clicks":0}
	driver_last_wall = -1
	game._new_game()
	game.runtime.state.rng_seed = int(spec.seed)
	game.runtime.s.dayTime = float(spec.day_time)
	game.runtime.profile_enabled = true
	game.runtime.p.wanted = 4
	game.runtime.p.wantedT = 0.0
	game.sound.muted = true
	var center: Vector2 = spec.streets[0]
	var player_body: Dictionary = game.runtime.combat._geometry(game.runtime.p)
	player_body.x = center.x-player_body.w*0.5; player_body.y = center.y-player_body.h*0.5
	var placement: Variant = game.physics.clear_placement(player_body)
	if not placement is Vector2:
		_fail(spec.id+": initial controller placement blocked")
		return {"id":spec.id,"setup_failed":true}
	game.runtime.p.x = placement.x; game.runtime.p.y = placement.y
	game._reset_presentation(); game._sync_model_nodes(0.0)
	var route_started: int = Time.get_ticks_usec()
	if not _plan_loop(spec.streets):
		_fail(spec.id+": fixed street tour has no physical route")
		return {"id":spec.id,"setup_failed":true}
	var route_setup_us: int = Time.get_ticks_usec()-route_started
	evasive = Driver.new(game.physics,game.runtime.state,route)
	_validate_clearance(spec.id+":initial")
	await _capture(spec.id+"_initial")
	game.observed_events.clear(); game.previous_started = 0
	game.probe_running = true; game.set_process(true)
	# Police use their real source spawn transaction inside Runtime.advance.
	for frame: int in range(warmup_frames):
		if pose_input_disabled:
			for body: Node3D in game.actors.values(): _set_pose_memo(body.get_node("Art"),false)
		var before_point: Vector2 = game.runtime.state.player_center()
		var before_p: Dictionary = game.runtime.p; var before_s: Dictionary = game.runtime.s
		_drive()
		await game.frame_sampled
		_observe_workload(frame,before_point,before_p,before_s)
	game.set_process(false); _release_input()
	var original: Dictionary = _actor_manifest()
	var min_alive: int = 100000
	var min_supported: int = 100000
	var min_rigs: int = 100000
	var movers: Dictionary = {}
	var chargers: Dictionary = {}
	var born: Dictionary = {}
	var removed: Dictionary = {}
	var dead: Dictionary = {}
	var previous: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs: previous[actor.id] = Vector2(actor.x,actor.y)
	var cpu := PackedFloat64Array()
	var scopes: Dictionary = {}
	var active_ms := PackedFloat64Array()
	var supplied_delta_ms := PackedFloat64Array()
	var step_counts: Dictionary = {}
	var process_ms := PackedFloat64Array()
	var render_cpu_ms := PackedFloat64Array()
	var render_gpu_ms := PackedFloat64Array()
	var render_setup_ms := PackedFloat64Array()
	var intervals_ms := PackedFloat64Array()
	var draws := PackedFloat64Array()
	var primitives := PackedFloat64Array()
	var objects := PackedFloat64Array()
	var max_video_bytes: float = 0
	var max_nodes: float = 0
	var projectile_peak: int = 0
	var max_pending_ms: float = 0
	var max_queue: int = 0
	var max_tests: int = 0
	var max_starts: int = 0
	var player_distance_m: float = 0
	var excluded_distance_m: float = 0
	var inclusive_distance_m: float = 0
	var before_player: Vector2 = game.runtime.state.player_center()
	var physics_start: int = game.physics.query_count
	var navigation_before: Dictionary = game.physics.navigation_metrics()
	var measured_started: int = Time.get_ticks_msec()
	game.previous_started = 0; measured_driver = true; phase_part = "measured"; game.set_process(true)
	for frame: int in range(sample_frames):
		var before_p: Dictionary = game.runtime.p; var before_s: Dictionary = game.runtime.s
		_drive()
		await game.frame_sampled
		cpu.append(float(game.sample_cpu_us)/1000.0)
		active_ms.append(game.runtime.last_advanced_ms)
		supplied_delta_ms.append(game.sample_delta_ms)
		_append_frame_series(step_counts,game.runtime.profile_calls,frame)
		_append_frame_series(scopes,game.scope_us,frame,0.001)
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_setup_ms.append(RenderingServer.get_frame_setup_time_cpu())
		if game.sample_interval_us > 0: intervals_ms.append(float(game.sample_interval_us)/1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		max_video_bytes = maxf(max_video_bytes,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		max_nodes = maxf(max_nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		max_tests = maxi(max_tests,game.physics._navigation._frame_tests)
		max_starts = maxi(max_starts,game.physics._navigation._frame_starts)
		max_queue = maxi(max_queue,game.physics._navigation._queue.size())
		var alive: int = 0
		var supported: int = 0
		var rigged: int = 0
		var present: Dictionary = {}
		for actor: Dictionary in game.runtime.state.npcs:
			var id: String = str(actor.id)
			present[id] = true
			var point := Vector2(actor.x,actor.y)
			if not original.has(id): born[id] = true
			if actor.get("dead",false): dead[id] = true
			else:
				alive += 1
				if game.runtime.director.supported(actor): supported += 1
				if game.actors.has(id): rigged += 1
			if previous.has(id) and point.distance_squared_to(previous[id]) > 0.000001: movers[id] = true
			if actor.get("chargeState","") in ["windup","lunge","cooldown"]: chargers[id] = true
			previous[id] = point
		for id: String in previous.keys():
			if not present.has(id): removed[id] = true; previous.erase(id)
		min_alive = mini(min_alive,alive); min_supported = mini(min_supported,supported); min_rigs = mini(min_rigs,rigged)
		projectile_peak = maxi(projectile_peak,game.runtime.state.projectiles.size())
		var at: Vector2 = game.runtime.state.player_center()
		var displacement: Dictionary = _observe_workload(frame,before_player,before_p,before_s)
		player_distance_m += float(displacement.get("walked_m",0))
		excluded_distance_m += float(displacement.get("excluded_m",0))
		inclusive_distance_m += at.distance_to(before_player)*0.04; before_player = at
		if frame % 120 == 0:
			var metric: Dictionary = game.physics.navigation_metrics()
			max_pending_ms = maxf(max_pending_ms,float(metric.oldest_pending_ms))
			print("ACTUAL60 ",spec.id," ",frame+1,"/",sample_frames," alive=",alive," supported=",supported," queue=",metric.queued)
		if game.runtime.s.mode != "playing":
			_fail(spec.id+": live scene left playing mode during measurement")
			break
	game.set_process(false); _release_input()
	var measured_elapsed_ms: int = Time.get_ticks_msec()-measured_started
	var physics_queries: int = game.physics.query_count-physics_start
	_validate_clearance(spec.id+":end")
	await _capture(spec.id+"_end")
	var dependencies: Array = game.runtime.combat._missing.keys()
	for dependency: Variant in dependencies: _fail(spec.id+": unresolved production dependency: "+str(dependency))
	if not game.missing_visuals.is_empty(): _fail(spec.id+": missing authored visuals: "+str(game.missing_visuals))
	if min_alive < 60 or min_supported < 60 or min_rigs < 60: _fail(spec.id+": fewer than60 live supported actors with rigs")
	if max_tests > 192 or max_starts > 4: _fail(spec.id+": navigation hard budget exceeded")
	var cpu_stats: Dictionary = _stats(cpu)
	var process_stats: Dictionary = _stats(process_ms)
	var scope_stats: Dictionary = {}
	for key: String in scopes: scope_stats[key] = _stats(scopes[key])
	var scope_totals: Dictionary = {}
	for key: String in scopes: scope_totals[key] = _sum(scopes[key])
	var call_stats: Dictionary = {}
	var active_total: float = _sum(active_ms)
	for key: String in step_counts:
		var calls: float = _sum(step_counts[key])
		var elapsed: float = float(scope_totals.get("runtime_"+key,0))
		call_stats[key] = {"frames":_stats(step_counts[key],false),"total":calls,"cpu_total_ms":elapsed,"cpu_ms_per_call":elapsed/calls if calls > 0 else 0,"cpu_ms_per_active_second":elapsed*1000.0/active_total if active_total > 0 else 0}
	if cpu_stats.get("p95",INF) >= 16.0 or process_stats.get("p95",INF) >= 16.0: _fail(spec.id+": scene CPU or held engine-process monitor p95 exceeds16ms")
	if player_distance_m < 10.0: _fail(spec.id+": controller tour did not walk10m")
	if cpu.size() != sample_frames: _fail(spec.id+": incomplete measured frame count")
	var source_route: Array = []
	for point: Vector2 in route: source_route.append([point.x,point.y])
	return {"id":spec.id,"seed":spec.seed,"start_day_time":spec.day_time,"end_day_time":game.runtime.s.dayTime,
		"warmup_frames":warmup_frames,"frames":cpu.size(),"elapsed_ms":measured_elapsed_ms,
		"initial_player_top_left_px":[placement.x,placement.y],"source_route_centers_px":source_route,"route_setup_us":route_setup_us,
		"player_walked_m":player_distance_m,"player_displacement_including_relocations_m":inclusive_distance_m,"excluded_lifecycle_displacement_m":excluded_distance_m,"completed_laps":completed_laps,"actor_manifest":original,"final_actor_manifest":_actor_manifest(),
		"driver_cpu_ms":_stats(driver_cpu),"driver_cpu_total_ms":_sum(driver_cpu),"driver_physics_queries":driver_queries,"physics_queries_excluding_driver":physics_queries-driver_queries,
		"driver_input_counts":driver_input_counts,"driver_decisions":driver_decisions,"workload_frames":workload_frames,"lifecycle_timeline":lifecycle_timeline,"population_timeline":population_timeline,
		"driver_work":{"decisions":evasive.decisions,"candidate_sweeps":evasive.candidate_sweeps,"short_sweeps":evasive.short_sweeps,"retained_sweeps":evasive.retained_sweeps},
		"min_live_actors":min_alive,"min_supported_live_actors":min_supported,"min_live_rigs":min_rigs,
		"moving_actor_ids":movers.keys(),"charging_actor_ids":chargers.keys(),"born_ids":born.keys(),"dead_ids":dead.keys(),"removed_ids":removed.keys(),
		"projectile_peak":projectile_peak,"events":game.observed_events.duplicate(),"dependencies":dependencies,
		"scene_cpu_ms":cpu_stats,"engine_process_monitor_window_max_ms":process_stats,"frame_interval_ms":_stats(intervals_ms),
		"viewport_render_cpu_ms":_stats(render_cpu_ms),"viewport_render_gpu_ms":_stats(render_gpu_ms),"render_setup_cpu_ms":_stats(render_setup_ms),
		"gpu_timing_available":_sum(render_gpu_ms) > 0.0,
		"scene_scopes_ms":scope_stats,"scene_scope_totals_ms":scope_totals,
		"supplied_delta_ms":_stats(supplied_delta_ms),"active_ms":{"frames":_stats(active_ms),"total":active_total},"stage_calls":call_stats,
		"physics_queries_per_active_second":physics_queries*1000.0/active_total if active_total > 0 else 0,
		"diagnostic_switches":{"without_grade":grade_disabled,"without_pose_input_memo":pose_input_disabled},
		"draw_calls":_stats(draws,false),"rendered_objects":_stats(objects,false),"rendered_primitives":_stats(primitives,false),
		"max_video_memory_bytes":max_video_bytes,"max_nodes":max_nodes,"physics_queries":physics_queries,
		"navigation_before":navigation_before,"navigation_after":game.physics.navigation_metrics(),
		"navigation_phase_max_tests":max_tests,"navigation_phase_max_starts":max_starts,"navigation_phase_max_queue":max_queue,"sampled_oldest_pending_ms":max_pending_ms}


func _append_frame_series(series: Dictionary,current: Dictionary,frame: int,scale: float = 1.0) -> void:
	for key: String in current:
		if not series.has(key):
			var prior := PackedFloat64Array(); prior.resize(frame); prior.fill(0.0)
			series[key] = prior
	for key: String in series: series[key].append(float(current.get(key,0))*scale)

func _sum(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in values: total += value
	return total

func _set_pose_memo(node: Node3D,enabled: bool) -> void:
	if node.has_meta("roster_rig"):
		var rig: Dictionary = node.get_meta("roster_rig"); rig.pose_input_cache_enabled = enabled
		for companion: Dictionary in rig.companions: _set_pose_memo(companion.node,enabled)

func _plan_loop(streets: Array) -> bool:
	route.clear(); route_cursor = 1; completed_laps = 0
	var at: Vector2 = game.runtime.state.player_center()
	route.append(at)
	for index: int in range(1,streets.size()):
		var target: Vector2 = streets[index]
		var path: PackedVector3Array = game.world.find_route(Content.to_world(at,0.06),Content.to_world(target,0.06),0.48)
		if path.size() < 2: return false
		for point: Vector3 in path:
			var source: Vector2 = Content.to_source(point)
			if route[route.size()-1].distance_squared_to(source) > 0.01: route.append(source)
		at = target
	return route.size() >= 2


func _drive() -> void:
	var began: int = Time.get_ticks_usec()
	var queries_before: int = game.physics.query_count
	_release_input()
	var now_ms: int = Time.get_ticks_msec()
	var dt: float = clampf(float(now_ms-driver_last_wall)/1000.0,0.001,0.1) if driver_last_wall >= 0 else 1.0/60.0
	driver_last_wall = now_ms
	driver_result = evasive.step(now_ms)
	if not driver_result.ok: _fail(current_phase+": input driver: "+str(driver_result.reason))
	if driver_result.get("decision",false):
		if driver_decisions.size() >= 2000: _fail(current_phase+": bounded decision evidence overflow")
		else: driver_decisions.append({"part":phase_part,"decision":evasive.last_decision.duplicate(true)})
	var desired: Vector2 = driver_result.get("direction",Vector2.ZERO)
	driver_input = {"direction":Vector2.ZERO,"sprint":false}
	if driver_result.ok and not desired.is_zero_approx() and game.runtime.s.mode == "playing":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var capture := InputEventMouseButton.new(); capture.button_index = MOUSE_BUTTON_LEFT; capture.pressed = true
			game._unhandled_input(capture); driver_input_counts.capture_clicks += 1
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var forward3: Vector3 = -game.camera.global_basis.z
			var forward := Vector2(forward3.x,forward3.z)
			var yaw: float = clampf(forward.angle_to(desired),-4.5*dt,4.5*dt)
			var mouse := InputEventMouseMotion.new(); mouse.relative = Vector2(yaw/0.0022,0)
			game._unhandled_input(mouse); driver_input_counts.mouse_motion += 1
			var local: Vector3 = game.player.global_basis.inverse()*Vector3(desired.x,0,desired.y)
			var raw: Vector2 = Driver.encode_motion(Vector2(local.x,local.z))
			if absf(raw.x) > 0.000001: Input.action_press("right" if raw.x > 0 else "left",absf(raw.x))
			if absf(raw.y) > 0.000001: Input.action_press("back" if raw.y > 0 else "forward",absf(raw.y))
			if driver_result.get("sprint",false): Input.action_press("sprint")
			driver_input_counts.motion_frames += 1
			if driver_result.get("sprint",false): driver_input_counts.sprint_frames += 1
			var decoded: Vector2 = Input.get_vector("left","right","forward","back")
			var world_input: Vector3 = game.player.global_basis*Vector3(decoded.x,0,decoded.y)
			driver_input = {"direction":Vector2(world_input.x,world_input.z),"decoded":decoded,"sprint":Input.is_action_pressed("sprint")}
	completed_laps = int(driver_result.get("laps",0))
	if measured_driver:
		driver_queries += game.physics.query_count-queries_before
		driver_cpu.append(float(Time.get_ticks_usec()-began)/1000.0)

func _observe_workload(frame: int,before: Vector2,before_p: Dictionary,before_s: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	var events: Dictionary = {}
	for kind: String in game.observed_events:
		var count: int = int(game.observed_events[kind])-int(previous_events.get(kind,0))
		if count <= 0: continue
		events[kind] = count
		if kind in ["arrest","death","placement_reset"]: reasons.append(kind)
		if kind == "player_attack": _fail(current_phase+": evasion driver must not attack")
	previous_events = game.observed_events.duplicate()
	if not is_same(before_p,game.runtime.p) or not is_same(before_s,game.runtime.s): reasons.append("source_epoch")
	var after: Vector2 = game.runtime.state.player_center()
	if not events.is_empty() or not reasons.is_empty():
		if lifecycle_timeline.size() >= 2400: _fail(current_phase+": lifecycle evidence overflow")
		else: lifecycle_timeline.append({"part":phase_part,"frame":frame,"observed_wall_ms":Time.get_ticks_msec(),"source_before":before,"source_after":after,"events":events,"discontinuities":reasons.duplicate()})
	for reason: String in reasons:
		evasive.invalidate_lifecycle(reason)
		_fail(current_phase+": observed source lifecycle invalidates sustained60: "+reason)
	var movement: Dictionary = Driver.sample_displacement(before,after,reasons)
	if not movement.ok: _fail(current_phase+": invalid actual displacement evidence")
	var alive := 0; var supported := 0; var rigged := 0
	var population: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs:
		var id: String = str(actor.id)
		population[id] = not actor.get("dead",false)
		if actor.get("dead",false): continue
		alive += 1
		if game.runtime.director.supported(actor): supported += 1
		if game.actors.has(id): rigged += 1
	if population != prior_population:
		var added: Array[String] = []; var removed: Array[String] = []; var newly_dead: Array[String] = []
		for id: String in population:
			if not prior_population.has(id): added.append(id)
			elif prior_population[id] and not population[id]: newly_dead.append(id)
		for id: String in prior_population:
			if not population.has(id): removed.append(id)
		if population_timeline.size() >= 2400: _fail(current_phase+": population evidence overflow")
		else: population_timeline.append({"part":phase_part,"frame":frame,"observed_wall_ms":Time.get_ticks_msec(),"added":added,"removed":removed,"dead":newly_dead,"live":alive,"supported":supported,"rigged":rigged})
		prior_population = population
	if phase_part == "measured" and (alive < 60 or supported < 60 or rigged < 60): _fail(current_phase+": fewer than60 on at least one measured frame; see full workload_frames")
	if workload_frames.size() >= 2400: _fail(current_phase+": bounded frame evidence overflow")
	else: workload_frames.append({"part":phase_part,"frame":frame,"observed_wall_ms":Time.get_ticks_msec(),"source_position":[game.runtime.p.x,game.runtime.p.y],"hp":game.runtime.p.hp,"shakes":game.runtime.p.shakes,"wanted":game.runtime.p.wanted,"stun":game.runtime.p.stunT,"active_ms":game.runtime.last_advanced_ms,"alive":alive,"supported":supported,"rigged":rigged,"input":driver_input.duplicate(true),"decision_reason":driver_result.get("reason",""),"decision_count":evasive.decisions,"displacement":movement})
	return movement


func _release_input() -> void:
	for action: String in ["forward","back","left","right","sprint"]:
		if InputMap.has_action(action): Input.action_release(action)


func _actor_manifest() -> Dictionary:
	var result: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs:
		var visual: StringName = Roster.visual_for_actor(actor)
		result[actor.id] = {"name":actor.get("name",""),"sprite":actor.get("sprite",""),"visual":String(visual),
			"source_position_px":[actor.x,actor.y],"size_px":[actor.w,actor.h],"speed":actor.get("speed",0),
			"hp":actor.get("hp",0),"max_hp":actor.get("maxHp",actor.get("hpMax",0)),"damage":actor.get("dmg",0),"is_cop":actor.get("isCop",false),"kingdom_guard":actor.get("kingdomGuard",false),"dead":actor.get("dead",false),
			"archetype":actor.get("archetype","default"),"supported":game.runtime.director.supported(actor),"query_height_m":game.physics._height(str(actor.id))}
	return result


func _validate_clearance(label: String) -> void:
	var player: Dictionary = game.runtime.combat._geometry(game.runtime.p)
	if not game.physics._clear(player,Vector2(player.x,player.y)): _fail(label+": player body penetrates world")
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.get("dead",false) or not game.runtime.director.supported(actor): continue
		var body: Dictionary = game.runtime.combat._geometry(actor)
		if not game.physics._clear(body,Vector2(body.x,body.y)): _fail(label+": actor body penetrates world: "+str(actor.id))


func _capture(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(output_dir.path_join(name_text+".png")) != OK:
		_fail("cannot write native frame: "+name_text)


func _stats(samples: PackedFloat64Array,time_metric: bool = true) -> Dictionary:
	if samples.is_empty(): return {}
	var ordered: PackedFloat64Array = samples.duplicate(); ordered.sort()
	var over16: int = 0
	for value: float in samples:
		if value > 16.0: over16 += 1
	var result: Dictionary = {"samples":ordered.size(),"p50":ordered[int(floor((ordered.size()-1)*0.50))],"p95":ordered[int(floor((ordered.size()-1)*0.95))],
		"p99":ordered[int(floor((ordered.size()-1)*0.99))],"max":ordered[ordered.size()-1]}
	if time_metric: result.above16ms = over16
	return result


func _write_report(phases: Array,started: int) -> void:
	var scripts: Dictionary = {}
	var script_hashes_available: bool = true
	for path: String in ["scripts/full_scene.gd","scripts/full_runtime.gd","scripts/world_adapter.gd","scripts/actor_navigation.gd","scripts/actor_director.gd","scripts/combat_system.gd","scripts/character_roster.gd","scripts/cast_profiles.gd","scripts/actor_animation.gd","scripts/full_neighborhood.gd","tests/full_actor_performance_probe.gd","tests/sustained_actor_driver.gd"]:
		scripts[path] = FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else ""
		if str(scripts[path]).length() != 64: script_hashes_available = false
	var report: Dictionary = {"schema":1,"acceptance":failures.is_empty() and phases.size() == 2,"diagnostic":diagnostic,
		"workload_version":"sustained60_normal_input_v2_draft","comparison_requires_identical_driver":true,"fixed_measured_frames":1080,"fixed_warmup_frames":120,
		"driver_timing":"normal-input evasion CPU/queries are outside unchanged MeasuredScene boundary; complete frame intervals include driver and caller evidence bookkeeping",
		"lifecycle_timing":"source event-counter deltas observed at render-frame boundaries, not invented within-step times; labeled arrest/death/epoch/placement deltas excluded from walked metres",
		"scope":"Actual FullScene/Runtime/Combat/ActorDirector, source police spawning and authored rigs/animation/HUD in native Compatibility. This is not a Web result. Viewport GPU timing is reported only when the driver returns nonzero measurements.",
		"frame_intervals_include_probe_bookkeeping":true,"timing_boundary":"scene_cpu_ms wraps the complete unchanged FullScene._process plus event counters; route setup and probe validation are outside it",
		"engine_monitor_semantics":"Frame-weighted samples of TIME_PROCESS's held approximately one-second maximum, not independent engine-frame CPU times. The existing16ms p95 gate is retained conservatively.",
		"render_timing_semantics":"Delayed completed-frame viewport CPU/GPU distributions; not paired to current scene samples. Timestamp instrumentation enabled; zero-only GPU means unavailable. Frame setup excludes scripts.",
		"workload_semantics":"Stage calls include final partial subdivisions; distributions include zero-call frames. Query rate includes driver queries, not actor-only; physics_queries_excluding_driver subtracts only explicitly timed driver calls.",
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"processor":OS.get_processor_name(),"platform":OS.get_name(),"resolution":[1280,720],"msaa":4,"fps_cap":60,"vsync":false,
		"source_corpus":Content.load_content().source.corpusSha256,"script_sha256":scripts,"script_hashes_available":script_hashes_available,
		"source_provenance":"Compiled exports may omit raw GDScript; use profile-release.ps1's external archived-source and executable hashes. Empty in-package script hashes are unavailable, not proof of equality.","elapsed_ms":Time.get_ticks_msec()-started,
		"world":game.world.build_metrics if game != null and game.world != null else {},"phases":phases,"failures":failures}
	var file := FileAccess.open(output_dir.path_join("full-actor-performance.json"),FileAccess.WRITE)
	if file == null: _fail("cannot write full actor performance JSON"); return
	file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
