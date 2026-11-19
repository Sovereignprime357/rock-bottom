extends SceneTree
## Native production composition evidence. No replacement AI, cloned residents or gameplay saves.
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")

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


func _initialize() -> void: call_deferred("_run")


func _fail(message: String) -> void:
	if not failures.has(message): failures.append(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Full actor performance evidence requires a native rendering device.")
		quit(1); return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p04b/actual60")
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--diagnostic": diagnostic = true
		elif argument == "--without-grade": grade_disabled = true
		elif argument == "--without-pose-input-memo": pose_input_disabled = true
		elif argument.begins_with("--frames="): sample_frames = clampi(int(argument.trim_prefix("--frames=")),120,1200)
		elif argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create full actor evidence directory."); quit(1); return
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
	# _ready has yielded before store creation; keep its destination isolated even
	# when the caller omits --qa-full. No source save is read by this probe.
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
	_validate_clearance(spec.id+":initial")
	await _capture(spec.id+"_initial")
	game.observed_events.clear(); game.previous_started = 0
	game.probe_running = true; game.set_process(true)
	# Police use their real source spawn transaction inside Runtime.advance.
	for frame: int in range(warmup_frames):
		if pose_input_disabled:
			for body: Node3D in game.actors.values(): _set_pose_memo(body.get_node("Art"),false)
		_drive()
		await game.frame_sampled
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
	var before_player: Vector2 = game.runtime.state.player_center()
	var physics_start: int = game.physics.query_count
	var navigation_before: Dictionary = game.physics.navigation_metrics()
	var measured_started: int = Time.get_ticks_msec()
	game.previous_started = 0; game.set_process(true)
	for frame: int in range(sample_frames):
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
		player_distance_m += at.distance_to(before_player)*0.04; before_player = at
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
		"player_walked_m":player_distance_m,"completed_laps":completed_laps,"actor_manifest":original,
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
	if route.size() < 2: _release_input(); return
	var at: Vector2 = game.runtime.state.player_center()
	if at.distance_to(route[route_cursor]) < 2.5:
		route_cursor += 1
		if route_cursor >= route.size(): route_cursor = 1; completed_laps += 1
	var direction: Vector2 = route[route_cursor]-at
	game.player.rotation.y = atan2(-direction.x,-direction.y)
	# Input.get_vector removes the default0.5 deadzone; express the desired
	# slow approach above that threshold instead of stalling near a waypoint.
	Input.action_press("forward",0.5+0.5*minf(1.0,direction.length()*0.04/0.4))


func _release_input() -> void:
	for action: String in ["forward","back","left","right","sprint"]:
		if InputMap.has_action(action): Input.action_release(action)


func _actor_manifest() -> Dictionary:
	var result: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs:
		var visual: StringName = Roster.visual_for_actor(actor)
		result[actor.id] = {"name":actor.get("name",""),"sprite":actor.get("sprite",""),"visual":String(visual),
			"source_position_px":[actor.x,actor.y],"size_px":[actor.w,actor.h],"speed":actor.get("speed",0),
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
	for path: String in ["scripts/full_scene.gd","scripts/full_runtime.gd","scripts/world_adapter.gd","scripts/actor_navigation.gd","scripts/actor_director.gd","scripts/combat_system.gd","scripts/character_roster.gd","scripts/cast_profiles.gd","scripts/actor_animation.gd","scripts/full_neighborhood.gd","tests/full_actor_performance_probe.gd"]:
		scripts[path] = FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else ""
		if str(scripts[path]).length() != 64: script_hashes_available = false
	var report: Dictionary = {"schema":1,"acceptance":failures.is_empty() and phases.size() == 2,"diagnostic":diagnostic,
		"scope":"Actual FullScene/Runtime/Combat/ActorDirector, source police spawning and authored rigs/animation/HUD in native Compatibility. This is not a Web result. Viewport GPU timing is reported only when the driver returns nonzero measurements.",
		"frame_intervals_include_probe_bookkeeping":true,"timing_boundary":"scene_cpu_ms wraps the complete unchanged FullScene._process plus event counters; route setup and probe validation are outside it",
		"engine_monitor_semantics":"Frame-weighted samples of TIME_PROCESS's held approximately one-second maximum, not independent engine-frame CPU times. The existing16ms p95 gate is retained conservatively.",
		"render_timing_semantics":"Delayed completed-frame viewport CPU/GPU distributions; not paired to current scene samples. Timestamp instrumentation enabled; zero-only GPU means unavailable. Frame setup excludes scripts.",
		"workload_semantics":"Stage calls include final partial subdivisions; distributions include zero-call frames. Query rate is whole-scene, not actor-only.",
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"processor":OS.get_processor_name(),"platform":OS.get_name(),"resolution":[1280,720],"msaa":4,"fps_cap":60,"vsync":false,
		"source_corpus":Content.load_content().source.corpusSha256,"script_sha256":scripts,"script_hashes_available":script_hashes_available,
		"source_provenance":"Compiled exports may omit raw GDScript; use profile-release.ps1's external archived-source and executable hashes. Empty in-package script hashes are unavailable, not proof of equality.","elapsed_ms":Time.get_ticks_msec()-started,
		"world":game.world.build_metrics if game != null and game.world != null else {},"phases":phases,"failures":failures}
	var file := FileAccess.open(output_dir.path_join("full-actor-performance.json"),FileAccess.WRITE)
	if file == null: _fail("cannot write full actor performance JSON"); return
	file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
