extends SceneTree
## Isolated native visual evidence for the production camera/rig. No save reads/writes.
var game: Node3D
var output_dir: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Viewmodel evidence requires rendering.")
		quit(1)
		return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p01")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._new_game()
	game.mode = "paused"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.position = Vector3(18.3, 0.05, -10.5)
	game.player.rotation = Vector3.ZERO
	game.camera.look_at(Vector3(18, 1.3, -13))
	game.world.set_day_time(60.0)
	game.hands.reset()
	await _capture("rest")
	for frame: int in range(18): game.hands.tick(1.0 / 60.0, Vector3(0,0,-3.6), false)
	await _capture("walk")
	for frame: int in range(18): game.hands.tick(1.0 / 60.0, Vector3(0,0,-6.12), true)
	await _capture("sprint")
	game.hands.reset()
	game.hands.tick(0.1, Vector3.ZERO, false, false, false, 0.0, Vector2(0.2, -0.15))
	await _capture("look_sway")
	for action: String in ["punch", "interact", "pickup", "receipt", "eat", "smoke", "equip"]:
		game.hands.reset()
		game.hands.acknowledge(action, true, action == "punch")
		game.hands.tick(0.08, Vector3.ZERO, false)
		await _capture(action + "_early")
		game.hands.tick(0.10, Vector3.ZERO, false)
		await _capture(action + "_late")
		game.hands.tick(0.6, Vector3.ZERO, false)
		if action == "punch":
			game.hands.acknowledge("punch", true, false)
			game.hands.tick(0.08, Vector3.ZERO, false)
			await _capture("punch_left_miss")
	game.hands.reset()
	await _capture("reset")
	print("3D VIEWMODEL PROBE: PASS; ", output_dir)
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
	if error != OK:
		push_error("Cannot save viewmodel evidence: " + label)
		quit(1)
