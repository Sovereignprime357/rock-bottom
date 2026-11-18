extends SceneTree
## Development render evidence. No player-save reads/writes, no shipped UI entry.

var game: Node3D
var output_dir := ""
var samples: Array[Dictionary] = []
var crowd: Array[Node3D] = []
var art_script: Script
var fixed_day := 60.0
var measure := false
var clock := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _process(delta: float) -> bool:
	if game == null: return false
	if measure:
		game.mode = "playing"
		game.sim.day_time = fixed_day
	clock += delta
	if art_script != null and art_script.has_method("animate_character"):
		for actor: Node3D in crowd:
			art_script.call("animate_character", actor, str(actor.get_meta("art_id")), clock, 0.0, 0.0)
	return false

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Render probe requires a real rendering device.")
		quit(1)
		return
	output_dir = ProjectSettings.globalize_path("res://../.build/art-pass/render")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var packed := load("res://main.tscn") as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.store.save_path = output_dir.path_join("probe-only-save.json")
	game._new_game()
	game.mode = "paused"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.world.set_day_time(fixed_day)
	var views := [
		["block", Vector3(0, 0.05, 8), Vector3(1, 1.2, -7)],
		["tony", Vector3(18.3, 0.05, -10.5), Vector3(18, 1.3, -13)],
		["pete", Vector3(-18, 0.05, -7.6), Vector3(-18, 1.3, -12.2)],
		["yuri", Vector3(-25.5, 0.05, 13), Vector3(-28, 1.2, 13)],
		["lurch", Vector3(24, 0.05, 14.5), Vector3(27, 1.4, 14)],
		["street", Vector3(-12, 0.05, -2.1), Vector3(-31, 1.7, -7)],
		["yard", Vector3(-24, 0.05, 17), Vector3(-33, 1.3, 10)]
	]
	for view: Array in views:
		game.player.position = view[1]
		game.player.rotation = Vector3.ZERO
		game.camera.look_at(view[2])
		await process_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		_capture(str(view[0]))
		if str(view[0]) == "tony":
			game.mode = "playing"
			game._interact("tony")
			await process_frame
			await RenderingServer.frame_post_draw
			_capture("conversation")
			game.hud.close_menu()
			game.mode = "paused"
	await _capture_portraits()
	game._title()
	game.player.position = Vector3(0, 0.05, 8)
	game.player.rotation = Vector3.ZERO
	game.camera.rotation = Vector3(-0.04, 0, 0)
	await process_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	_capture("title")
	game.hud.close_menu()
	game.hands.show()
	game.player.position = Vector3(0, 0.05, 8)
	game.camera.rotation = Vector3(-0.04, 0, 0)
	await _measure("block_day", 6, 60.0)
	game.mode = "paused"
	game.world.set_day_time(180.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_capture("block_night")
	await _measure("block_night", 6, 180.0)
	game.mode = "paused"
	for view: Array in views:
		if str(view[0]) == "block": continue
		game.player.position = view[1]
		game.player.rotation = Vector3.ZERO
		game.camera.look_at(view[2])
		await physics_frame
		await RenderingServer.frame_post_draw
		_capture(str(view[0]) + "_night")
	if "--stress" in OS.get_cmdline_user_args():
		_spawn_crowd()
		game.player.position = Vector3(0, 0.05, 8)
		game.camera.rotation = Vector3(-0.04, 0, 0)
		await _measure("render_idle_stress", 60, 60.0)
		game.mode = "paused"
		await RenderingServer.frame_post_draw
		_capture("stress_60")
	var report := {
		"device": RenderingServer.get_video_adapter_name(), "resolution": "1280x720",
		"engine": Engine.get_version_info().string, "vsync": "disabled for probe",
		"msaa_3d": root.msaa_3d,
		"window_focused": DisplayServer.window_is_focused(), "measurements": samples,
		"scope": "native render + six production actors; optional 54 art-only animated duplicates, not 60 full AI agents"
	}
	if "batch_stats" in game.world: report["world_batching"] = game.world.batch_stats
	var file := FileAccess.open(output_dir.path_join("render-metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("3D RENDER PROBE: PASS; evidence ", output_dir)
	game.queue_free()
	game = null
	await process_frame
	await create_timer(0.25).timeout
	quit()

func _capture_portraits() -> void:
	# Eye-level art evidence is deliberately separate from the production cameras
	# and measured workload. Pete's QA camera may cross the service aperture.
	var player_transform: Transform3D = game.player.transform
	var camera_transform: Transform3D = game.camera.transform
	var camera_fov: float = game.camera.fov
	var hud_visible: bool = game.hud.visible
	var hands_visible: bool = game.hands.visible
	game.hud.hide()
	game.hands.hide()
	game.camera.fov = 48.0
	for id: String in ["tony", "pete", "yuri", "lurch", "possum", "brutus"]:
		var actor: Node3D = game.actors[id]
		var head: Node3D = actor.get_node("Art/head")
		var forward: Vector3 = actor.global_basis.z.normalized()
		var up: Vector3 = actor.global_basis.y.normalized()
		var focus: Vector3 = head.global_position + up * 0.04 + forward * 0.14
		var distance: float = 0.8 if id == "possum" else 1.0
		game.player.transform = Transform3D(Basis.IDENTITY, focus + forward * distance - camera_transform.origin)
		game.camera.position = camera_transform.origin
		game.camera.look_at(focus)
		await process_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		_capture("portrait_" + id)
	game.player.transform = player_transform
	game.camera.transform = camera_transform
	game.camera.fov = camera_fov
	game.hud.visible = hud_visible
	game.hands.visible = hands_visible

func _measure(label: String, count: int, day_time: float) -> void:
	fixed_day = day_time
	game.sim.day_time = day_time
	game.world.set_day_time(day_time)
	measure = true
	game.mode = "playing"
	# More than one monitor refresh and shader warmup; screenshots occur outside measurement.
	var warmup := Time.get_ticks_usec()
	while Time.get_ticks_usec() - warmup < 2000000:
		await RenderingServer.frame_post_draw
	var intervals: Array[float] = []
	var draws: Array[float] = []
	var process_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	var started := last
	var first_rendered_frame := Engine.get_frames_drawn()
	while Time.get_ticks_usec() - started < 5000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - last) / 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		last = now
	measure = false
	game.mode = "paused"
	intervals.sort()
	draws.sort()
	process_ms.sort()
	var elapsed := float(last - started) / 1000000.0
	var entry := {
		"view": label, "actors": count, "frames": intervals.size(), "seconds": elapsed,
		"engine_frames_drawn": Engine.get_frames_drawn() - first_rendered_frame,
		"engine_fps_monitor": Engine.get_frames_per_second(),
		"observed_render_hz": intervals.size() / elapsed,
		"mean_interval_ms": elapsed * 1000.0 / intervals.size(),
		"p95_interval_ms": intervals[mini(intervals.size() - 1, int(intervals.size() * 0.95))],
		"median_draw_calls": draws[draws.size() / 2],
		"median_cpu_process_ms": process_ms[process_ms.size() / 2]
	}
	samples.append(entry)
	print("3D PROFILE: ", JSON.stringify(entry))

func _capture(label: String) -> void:
	var error := root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + label)
		quit(1)

func _spawn_crowd() -> void:
	art_script = load("res://scripts/character_art.gd")
	for index in range(54):
		var id: String = ["tony", "pete", "yuri", "lurch"][index % 4]
		var actor: Node3D = art_script.call("create_character", id)
		actor.position = Vector3(-11 + (index % 9) * 2.7, 0.03, -1.3 - int(index / 9) * 2.4)
		game.add_child(actor)
		crowd.append(actor)
