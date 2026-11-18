extends SceneTree
## Sixty source-shaped movement consumers, not a production Director/Combat/rig benchmark.
const Adapter = preload("res://scripts/world_adapter.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var failures: Array[String] = []


func _initialize() -> void: call_deferred("_run")


func _position(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)
func _center(body: Dictionary) -> Vector2: return _position(body)+Vector2(body.w,body.h)*0.5


func _run() -> void:
	var frames: int = 600
	var output_dir: String = ProjectSettings.globalize_path("res://../.build/full-port/p04b")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="): frames = clampi(int(argument.trim_prefix("--frames=")),60,1200)
		elif argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	Engine.max_fps = 60
	var world := World.new(); root.add_child(world); world.build()
	var index_started: int = Time.get_ticks_usec()
	var adapter := Adapter.new(world)
	var index_us: int = Time.get_ticks_usec()-index_started
	var bodies: Array[Dictionary] = []
	for actor: Dictionary in Content.load_content().actors.day1:
		bodies.append({"id":str(actor.id),"x":actor.x,"y":actor.y,"w":actor.w,"h":actor.h,"source_speed":actor.get("speed",0)})
	# Source spawnCopAtEdge declares28x32; these are explicit deterministic geometry fixtures.
	for index: int in range(4): bodies.append({"id":"cop_probe_%d" % index,"x":30.0,"y":600.0+index*90,"w":28.0,"h":32.0,"source_speed":1.5})
	if bodies.size() != 60: failures.append("expected56 canonical body records plus4 cop-shaped fixtures")
	for body: Dictionary in bodies:
		var marker := Node3D.new(); world.add_child(marker); adapter.register_body(body.id,marker,1.8)
	await physics_frame; await process_frame
	var entries: Dictionary = {}
	for body: Dictionary in bodies:
		var authored: Vector2 = _position(body)
		var clear: Variant = adapter.clear_placement(body)
		if not clear is Vector2:
			failures.append("no physical initial box placement: "+str(body.id)); continue
		body.x = clear.x; body.y = clear.y
		var goal_body: Dictionary = body.duplicate()
		goal_body.x = 1100.0-body.w*0.5; goal_body.y = 940.0-body.h*0.5
		var goal_top: Variant = adapter.clear_placement(goal_body)
		if not goal_top is Vector2:
			failures.append("no physical goal placement: "+str(body.id)); continue
		entries[body.id] = {"authored_top_left":[authored.x,authored.y],"start":_center(body),"goal":goal_top+Vector2(body.w,body.h)*0.5,
			"start_recovered_px":authored.distance_to(clear),"walked_px":0.0,"blocked_steps":0,"arrivals":0,"last_status":"direct"}
	var frame_us := PackedInt64Array()
	var movement_us := PackedInt64Array()
	var total_sweeps: int = 0
	var started: int = Time.get_ticks_msec()
	for frame: int in range(frames):
		await process_frame
		var frame_started: int = Time.get_ticks_usec()
		adapter.begin_navigation_frame(Engine.get_process_frames(),float(frame)*1000.0/60.0)
		var movement_started: int = Time.get_ticks_usec()
		for body: Dictionary in bodies:
			if not entries.has(body.id): continue
			var entry: Dictionary = entries[body.id]
			var goal: Vector2 = entry.goal
			var delta: Vector2 = goal-_center(body)
			if delta.length() <= 2.0:
				entry.arrivals += 1
				entry.goal = entry.start if entry.arrivals % 2 == 1 else Vector2(1100,940)
				continue
			# Uniform2.2px/16ms is intentional obstruction stress, not source AI speed selection.
			var before: Vector2 = _position(body)
			var intended: Vector2 = before+delta.normalized()*minf(2.2*(1000.0/60.0)/16.0,delta.length())
			var result: Dictionary = adapter.move_body(body,intended,goal,false)
			body.x = result.position.x; body.y = result.position.y
			entry.walked_px += before.distance_to(result.position)
			entry.blocked_steps += 1 if result.blocked else 0
			entry.last_status = adapter.navigation_status(body.id).status; total_sweeps += 1
		movement_us.append(Time.get_ticks_usec()-movement_started)
		frame_us.append(Time.get_ticks_usec()-frame_started)
		if adapter.navigation_metrics().frame_tests > 192 or adapter.navigation_metrics().frame_starts > 4:
			failures.append("hard planning cap exceeded on frame"+str(frame)); break
		if (frame+1) % 120 == 0: print("NAVIGATION PROBE FRAME ",frame+1,"/",frames," queue=",adapter.navigation_metrics().queued)
	var actors: Array[Dictionary] = []
	for body: Dictionary in bodies:
		if not entries.has(body.id): continue
		var entry: Dictionary = entries[body.id]
		actors.append({"id":body.id,"logical_dimensions_px":[body.w,body.h],"query_height_m":1.8,"source_speed":body.source_speed,
			"authored_top_left":entry.authored_top_left,"initial_recovery_px":entry.start_recovered_px,"walked_metres":entry.walked_px*0.04,
			"blocked_steps":entry.blocked_steps,"arrivals":entry.arrivals,"remaining_to_goal_m":_center(body).distance_to(entry.goal)*0.04,
			"last_status":entry.last_status,"planner":adapter.navigation_status(body.id).status})
	var report: Dictionary = {"scope":"60 source-shaped scripted movement consumers in full geometry. Uniform1.8m query heights and2.2px/16ms requested speed. No Director decisions, Combat, animation, rigs or rendered60AI performance claim.",
		"engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"source_corpus":Content.load_content().source.corpusSha256,
		"world":world.build_metrics,"body_count":bodies.size(),"frames":frame_us.size(),"elapsed_ms":Time.get_ticks_msec()-started,
		"index_setup_us":index_us,"planning":adapter.navigation_metrics(),"movement_cpu_us":_stats(movement_us),"combined_cpu_us":_stats(frame_us),
		"movement_calls":total_sweeps,"physics_queries":adapter.query_count,"actors":actors,"failures":failures}
	var file := FileAccess.open(output_dir.path_join("navigation-evidence.json"),FileAccess.WRITE)
	if file == null: failures.append("cannot write navigation evidence")
	else: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	print("NAVIGATION MOVEMENT PROBE: ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify({"bodies":bodies.size(),"planning":adapter.navigation_metrics(),"combined_cpu_us":_stats(frame_us),"failures":failures}))
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)


func _stats(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty(): return {}
	var ordered: PackedInt64Array = samples.duplicate(); ordered.sort()
	return {"p50":ordered[int(floor((ordered.size()-1)*0.50))],"p95":ordered[int(floor((ordered.size()-1)*0.95))],"max":ordered[ordered.size()-1]}
