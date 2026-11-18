extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		quit(1)
		return
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.mode = "paused"
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/scene-test-save.json")
	check(game.actors.size() == 6, "six authored actor identities")
	game.sim.cash = 17
	game.loading = true
	game._new_game()
	check(game.sim.cash == 17, "new game cannot race an asynchronous load")
	game.loading = false
	game.store.busy = true
	game._new_game()
	check(game.sim.cash == 17, "new game cannot race a pending save")
	game.store.busy = false
	check(game.targets.size() == 9, "nine physical interaction anchors")
	var probes := [
		["block", Vector3(0, 0.05, 6.4), Vector3(0, 0.8, 4)],
		["tony", Vector3(18, 0.05, -10.4), Vector3(18, 1.2, -13)],
		["pete", Vector3(-18, 0.05, -7.6), Vector3(-18, 1.3, -10.0)],
		["yuri", Vector3(-25.5, 0.05, 13), Vector3(-28, 1.2, 13)],
		["lurch", Vector3(24.6, 0.05, 14), Vector3(27, 1.2, 14)],
		["dumpster_1", Vector3(10, 0.05, 2), Vector3(10, 1.12, -0.33)],
		["dumpster_2", Vector3(-11, 0.05, 22), Vector3(-11, 1.12, 19.67)],
		["dumpster_3", Vector3(30, 0.05, -22), Vector3(30, 1.12, -24.33)],
		["cash_1", Vector3(5, 0.05, -3), Vector3(5, 0.22, -5)],
		["copper_1", Vector3(-29, 0.05, 19), Vector3(-31, 0.22, 19)],
	]
	for probe: Array in probes:
		game.player.position = probe[1]
		game.player.rotation = Vector3.ZERO
		game.camera.look_at(probe[2])
		await physics_frame
		var hit: Dictionary = game._ray(3.2)
		var actual := str(hit.collider.get_meta("interaction_id", "")) if not hit.is_empty() else "nothing"
		check(actual == probe[0], "reachable eye-level target %s (hit %s)" % [probe[0], actual])
	# The opaque flank must stop both the interaction ray and a moving capsule.
	game.player.position = Vector3(-22, 0.05, -8.5)
	game.camera.look_at(Vector3(-22, 1.5, -17))
	await physics_frame
	var wall: Dictionary = game._ray(9.0)
	check(not wall.is_empty() and str(wall.collider.get_meta("interaction_id", "")).is_empty(), "wall occludes interaction")
	for frame in range(45):
		game.player.velocity = Vector3(0, -1, -3.6)
		game.player.move_and_slide()
		await physics_frame
	check(game.player.position.z > -10.0, "visible pawn flank stops the player capsule")
	# Exercise production menus and transaction callback paths, with independent persistence.
	game.sim.fresh()
	game._new_game()
	game.mode = "paused"
	for id in ["cash_1", "cash_2", "cash_3"]:
		game.sim.transact("collect_cash", id)
	game.mode = "playing"
	game._interact("tony")
	check(game.mode == "dialogue", "Tony opens a pausing dialogue")
	await process_frame
	await process_frame
	var menu_rect: Rect2 = game.hud.modal.get_global_rect()
	var viewport_size: Vector2 = game.hud.root.size
	check(menu_rect.position.y >= 0 and menu_rect.end.y <= viewport_size.y, "conversation panel stays entirely inside viewport: %s in %s" % [menu_rect, viewport_size])
	game._act("buy_rock", "")
	check(game.sim.cash == 2 and game.sim.rocks == 1, "production purchase spends ten once")
	game.player.position = Vector3(0, 0.05, 6.4)
	game._interact("block")
	game._act("smoke", "")
	check(is_equal_approx(game.sim.high_remaining, 18.0) and game.sim.rocks == 0, "production crate ignites real high")
	game._interact("possum")
	var before: float = game.sim.high_remaining
	for frame in range(8): await physics_frame
	check(is_equal_approx(game.sim.high_remaining, before), "dialogue truly pauses the simulation")
	game._resume()
	game._physics_process(18.0)
	check(is_equal_approx(game.sim.crash_remaining, 8.0), "production update reaches crash boundary")
	game._physics_process(8.0)
	check(is_zero_approx(game.sim.crash_remaining), "production update completes crash")
	game.mode = "paused"
	var saved: Dictionary = game.sim.snapshot(game.player.position, game.player.rotation.y)
	var written: bool = await game.store.write_save(saved)
	check(written, "native save adapter writes successfully")
	var restored: Dictionary = await game.store.read_save()
	check(restored.get("cash", -1) == 2 and restored.get("schema", 0) == 1, "native save adapter roundtrip")
	game.player.position = Vector3(25.1, 0.05, 14)
	game.camera.look_at(Vector3(27, 1.2, 14))
	game.attack_cd = 0
	await physics_frame
	game._punch()
	check(is_equal_approx(game.enemy_hp, 102.0), "production melee ray deals one sober punch")
	game._punch()
	check(is_equal_approx(game.enemy_hp, 102.0), "held/repeated attack cannot skip cooldown")
	for swing in range(6):
		game.attack_cd = 0
		game._punch()
	check(game.enemy_hp == 0 and game.sim.defeated.has("lurch"), "production encounter ends and records its daily reward")
	check(game.actors.lurch.collision_layer == 0, "defeated Lurch no longer blocks the alley")
	var earned: int = game.sim.cred
	game.attack_cd = 0
	game._punch()
	check(game.sim.cred == earned, "corpse cannot pay twice")
	# A lethal hit uses production recovery and cannot create a reward loop.
	game.sim.cred = 20
	check(game.sim.hurt(1000), "lethal damage reports death")
	game._death()
	check(game.player.position.distance_to(Vector3(0, 0.02, 8)) < 0.01 and game.sim.cred == 10, "death relocates to the Block with expected penalty")
	if failures.is_empty():
		print("3D SCENE GATE: PASS (%d checks; scene boot, physical rays, collision, menus, real loop, persistence and recovery)" % checks)
	else:
		print("3D SCENE GATE: FAIL (%d/%d failed)" % [failures.size(), checks])
	game.queue_free()
	await process_frame
	# Let the audio mixer release stopped playback resources before SceneTree shutdown.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
