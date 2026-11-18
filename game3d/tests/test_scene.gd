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
	check(not game.world.is_clear_position(Vector3(-37, 0.0, 15.5)), "tire stack has a full-height save-clearance footprint")
	game.world.set_day_time(60.0)
	var daytime: Color = game.world.sky_material.sky_horizon_color
	game.world.set_day_time(180.0)
	var nighttime: Color = game.world.sky_material.sky_horizon_color
	check(nighttime.get_luminance() < daytime.get_luminance() * 0.6, "night sky dims along with the neighborhood")
	game.world.set_day_time(0.0)
	var reachable := _walkable_cells(game.world)
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
		var approach: Vector3 = probe[1]
		check(reachable.has(Vector2i(roundi(approach.x), roundi(approach.z))), "dressed streets retain a clear route to %s" % probe[0])
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
	# Art animation must not relocate root meshes/collision and must freeze in a modal.
	for id: String in game.actors:
		var art: Node3D = game.actors[id].get_node("Art")
		var before_transform: Transform3D = art.transform
		game.Art.animate_character(art, id, 3.7, 0.5, 0.4)
		check(art.transform.is_equal_approx(before_transform), "animation keeps %s's body origin fixed" % id)
	var paused_clock: float = game.clock
	game._physics_process(0.5)
	check(is_equal_approx(game.clock, paused_clock), "new art animation clock pauses with modal gameplay")
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
	var recoil_pose: Vector3 = game.actors.lurch.get_node("Art").position
	await create_timer(0.16).timeout
	check(game.actors.lurch.get_node("Art").position.is_equal_approx(recoil_pose), "Lurch hit reaction freezes while gameplay is paused")
	game.mode = "playing"
	game._physics_process(0.12)
	game.mode = "paused"
	check(is_zero_approx(game.actors.lurch.get_node("Art").position.z), "hit reaction finishes on active simulation time")
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
	await _test_browser_controls(game)
	if failures.is_empty():
		print("3D SCENE GATE: PASS (%d checks; scene boot, physical rays, collision, menus, real loop, persistence, recovery and browser capture/fallback controls)" % checks)
	else:
		print("3D SCENE GATE: FAIL (%d/%d failed)" % [failures.size(), checks])
	game.queue_free()
	await process_frame
	# Let the audio mixer release stopped playback resources before SceneTree shutdown.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)

func _walkable_cells(world: Node3D) -> Dictionary:
	# One-metre cardinal flood fill with capsule clearance. Fixtures remain independent solids.
	var seen: Dictionary = {}
	var clear: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(0, 8)]
	seen[queue[0]] = true
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if seen.has(next): continue
			seen[next] = true
			if not world.is_clear_position(Vector3(next.x, 0.0, next.y), 0.36): continue
			clear[next] = true
			queue.append(next)
	return clear

func _key_press(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func _press_menu(game: Node3D, text: String) -> bool:
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and (child as Button).text == text and not (child as Button).disabled:
			(child as Button).pressed.emit()
			return true
	return false

func _test_browser_controls(game: Node3D) -> void:
	# Observe browser capture states through the real production transition method.
	# Native headless input cannot provide a browser's asynchronous lock events.
	# Manual physics keeps those observations deterministic; the world physics and
	# async save/load still run on the real SceneTree and independent test save file.
	game.set_physics_process(false)
	game.web_controls = true
	game.sim.fresh()
	game._respawn()
	game._restore_enemy()
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.sim.rocks = 1
	check(game.sim.transact("smoke").ok, "browser control regression starts the production high timer")
	var start_clock: float = game.clock
	var start_position: Vector3 = game.player.position
	Input.action_press("forward")
	for frame: int in range(5):
		await physics_frame
		game._physics_process(0.05)
	Input.action_release("forward")
	check(game.mode == "playing" and not game.hud.modal.visible, "pending initial pointer lock never reopens the pause menu")
	check(not game.capture_acquired and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pending capture neither invents success nor retries from physics")
	check(game.player.position.distance_to(start_position) > 0.05, "WASD moves the actual player while browser capture is pending")
	check(is_equal_approx(game.clock - start_clock, 0.25) and is_equal_approx(game.sim.high_remaining, 17.75), "pending capture advances gameplay and the real high timer")
	check(game.hud.look_hint.visible, "uncaptured browser play exposes the drag-look binding")
	# Continuing to observe refusal must remain playable, not wait for a timeout or
	# repeatedly replace the menu. There is intentionally no fake success here.
	for frame: int in range(20): game._physics_process(0.1)
	check(game.mode == "playing" and not game.capture_acquired, "permanently rejected capture stays playable across repeated physics ticks")
	check(is_equal_approx(game.sim.high_remaining, 15.75), "capture refusal cannot freeze or reset the high timer")
	game._sync_mouse_capture(true)
	check(game.capture_acquired and game.mode == "playing", "a delayed successful lock is observed without restarting play")
	check(not game.hud.look_hint.visible, "successful capture removes the fallback binding")
	game._sync_mouse_capture(false)
	check(game.mode == "paused" and game.hud.modal.visible, "losing a previously acquired lock pauses gameplay")
	var pause_heading: Node = game.hud.menu_box.get_child(0)
	var pause_high: float = game.sim.high_remaining
	game._physics_process(0.5)
	game._sync_mouse_capture(false)
	check(game.hud.menu_box.get_child(0) == pause_heading and is_equal_approx(game.sim.high_remaining, pause_high), "repeated unlocked observations neither rebuild pause nor advance timers")
	check(not game.hud.look_hint.visible, "pause hides the fallback binding")
	# Browser unlock can be delivered before the Escape key from that same action.
	game._unhandled_input(_key_press(KEY_ESCAPE))
	check(game.mode == "paused", "lock-loss-before-Escape cannot toggle back into play")
	check(_press_menu(game, "continue."), "pause Continue invokes the production resume callback")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._physics_process(0.1)
	check(game.mode == "playing" and not game.capture_acquired, "Continue resets old capture ownership before another delayed request")
	# Exercise the other event ordering: Escape first, browser unlock second.
	game._sync_mouse_capture(true)
	game._unhandled_input(_key_press(KEY_ESCAPE))
	game._sync_mouse_capture(false)
	game._unhandled_input(_key_press(KEY_ESCAPE))
	check(game.mode == "paused" and not game.capture_acquired, "Escape-before-lock-loss and repeated Escape remain paused")
	# An ordinary conversation releases the lock intentionally, then its actual
	# leave button must resume even if the next lock is refused.
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._interact("tony")
	game._sync_mouse_capture(false)
	var dialogue_high: float = game.sim.high_remaining
	game._physics_process(0.2)
	check(game.mode == "dialogue" and is_equal_approx(game.sim.high_remaining, dialogue_high), "intentional dialogue unlock retains the conversation and freezes gameplay")
	check(_press_menu(game, "leave."), "conversation leave invokes the production resume callback")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._physics_process(0.1)
	check(game.mode == "playing" and not game.hud.modal.visible, "conversation exit survives refused reacquisition")
	game._interact("tony")
	game._unhandled_input(_key_press(KEY_ESCAPE))
	check(game.mode == "paused", "Web Escape converts a conversation to pause instead of resuming")
	# Uncaptured pointer motion must be deliberate: no-button motion is ignored,
	# right-drag changes both look axes, and left-click still reaches real combat.
	game.sim.fresh()
	game._restore_enemy()
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var yaw_before: float = game.player.rotation.y
	var pitch_before: float = game.pitch
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, -20)
	game._unhandled_input(motion)
	check(is_equal_approx(game.player.rotation.y, yaw_before) and is_equal_approx(game.pitch, pitch_before), "free cursor movement cannot rotate an uncaptured view")
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	game._unhandled_input(motion)
	check(not is_equal_approx(game.player.rotation.y, yaw_before) and not is_equal_approx(game.pitch, pitch_before), "right-drag rotates yaw and pitch through production input handling")
	game.player.position = Vector3(25.1, 0.05, 14)
	game.camera.look_at(Vector3(27, 1.2, 14))
	game.attack_cd = 0.0
	await physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	game._unhandled_input(click)
	check(is_equal_approx(game.enemy_hp, 102.0), "uncaptured left-click damages Lurch through the actual melee ray")
	game._unhandled_input(click)
	check(is_equal_approx(game.enemy_hp, 102.0) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "fallback combat keeps cooldown and does not substitute another capture request")
	game._unhandled_input(_key_press(KEY_I))
	check(game.mode == "dialogue", "uncaptured inventory input remains usable")
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.position = Vector3(18, 0.05, -10.4)
	game.player.rotation = Vector3.ZERO
	game.camera.look_at(Vector3(18, 1.2, -13))
	await physics_frame
	game._unhandled_input(_key_press(KEY_E))
	check(game.mode == "dialogue", "uncaptured E reaches the real nearby vendor interaction")
	# Late acquisition must release the cursor while retaining whichever modal is open.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game._sync_mouse_capture(true)
	check(game.mode == "dialogue" and not game.capture_acquired and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "late capture during dialogue is released without closing the conversation")
	game._pause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game._sync_mouse_capture(true)
	check(game.mode == "paused" and not game.capture_acquired and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "late capture during pause is released without resuming")
	# The asynchronous production load takes its Web continuation branch while the
	# storage adapter remains native and points exclusively at scene-test-save.json.
	game._respawn()
	game.sim.cash = 23
	var written: bool = await game.store.write_save(game.sim.snapshot(game.player.position, game.player.rotation.y))
	check(written, "browser continuation fixture writes only the independent native test save")
	game.sim.cash = 1
	await game._load()
	check(game.mode == "paused" and not game.loading and game.sim.cash == 23, "asynchronous Web load restores data and waits for a deliberate Continue")
	check(_press_menu(game, "continue."), "loaded Web save exposes a working Continue callback")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._physics_process(0.1)
	check(game.mode == "playing" and not game.capture_acquired and not game.hud.modal.visible, "post-load Continue survives delayed or denied pointer lock")
	game._focus_lost()
	var focus_clock: float = game.clock
	game._physics_process(0.2)
	check(game.mode == "paused" and is_equal_approx(game.clock, focus_clock), "actual focus loss still pauses uncaptured fallback play")
	game._resume()
	game._sync_mouse_capture(true)
	game._focus_lost()
	game._sync_mouse_capture(false)
	check(game.mode == "paused" and not game.capture_acquired, "actual focus loss also pauses successfully captured play")
	# The platform override is test-only; the shipped native Escape toggle stays intact.
	game.web_controls = false
	game._unhandled_input(_key_press(KEY_ESCAPE))
	check(game.mode == "playing", "native Escape retains its existing resume toggle")
	game._unhandled_input(_key_press(KEY_ESCAPE))
	check(game.mode == "paused", "native Escape still pauses playing")
	game._sync_mouse_capture(false)
	check(not game.hud.look_hint.visible, "native controls never display the Web fallback binding")
	Input.action_release("forward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_physics_process(true)
